# AI QUALITY AUDIT. Plays real battles, then has an agent read the full turn-by-turn
# log (including the planner's own score lines) and list concrete misplays with a
# competitive-play rating. This is the "inspect battles" half of the iterate loop:
# it finds blunders I would not think to grep for.
#
#   ruby tools/sidmod_editor/sim/naudit.rb <rating_tag> <out_tag> [model]
#
# The agent is given both teams' exact sets and told the AI plays BOTH sides, so it
# judges the play, not the matchup.
require_relative 'nstore'
require_relative 'nbattle'
require_relative 'claude_client'
require 'fileutils'

RTAG  = ARGV[0] || 'ou3'
OTAG  = ARGV[1] || 'audit'
MODEL = ARGV[2] || 'claude-sonnet-5'

snap = File.join(NStore.dir(RTAG), 'save_snapshot.rxdata')
ENV['NSIM_SAVE'] = snap if File.exist?(snap)
NativeSim.boot!
FileUtils.mkdir_p(NStore.dir(OTAG))
POOL = NStore.read_json(RTAG, 'pool.json')
rat  = File.readlines(File.join(NStore.dir(RTAG), 'ratings.csv'))
HDR  = rat[0].chomp.split(',')
MONS = rat[1..].map { |l| HDR.zip(l.chomp.split(',')).to_h }
BY   = MONS.map { |m| [m['key'], m] }.to_h

def stats_of(k); (POOL[k] && POOL[k]['stats']) || [0] * 6; end
def bases_of(k); (POOL[k] && POOL[k]['bases']) || []; end
def moves_of(k); (POOL[k] && POOL[k]['moves']) || []; end
def pick6(c)
  out = []; used = []
  c.each { |k| next if (bases_of(k) & used).any?; out << k; used.concat(bases_of(k)); break if out.length == 6 }
  out
end
def set_line(k)
  p = POOL[k]
  "#{p['name']} (#{p['species']}) | #{p['types']} | #{p['ability']} | #{p['item']} | " \
    "#{p['moves'].join(', ')} | HP#{p['stats'][0]} Atk#{p['stats'][1]} Def#{p['stats'][2]} " \
    "SpA#{p['stats'][3]} SpD#{p['stats'][4]} Spe#{p['stats'][5]}"
end

keys = MONS.map { |m| m['key'] }.select { |k| POOL[k] }
bulk = ->(k) { s = stats_of(k); s[0].to_i + s[2].to_i + s[4].to_i }
RECOVER = %w[Recover Roost Soft-Boiled Milk\ Drink Slack\ Off Morning\ Sun Moonlight Synthesis Wish Rest Shore\ Up]
offense = pick6(keys.sort_by { |k| -BY[k]['kos_per_game'].to_f })
stall   = pick6(keys.select { |k| (moves_of(k) & RECOVER).any? && bulk.(k) >= 800 }.sort_by { |k| -bulk.(k) })

SYS = <<~TXT
  You are a competitive Pokemon player reviewing a battle played by a game AI. The SAME AI plays
  BOTH sides, so judge the QUALITY OF PLAY, not which team was better.

  The log includes the AI's own internal decision lines: "[SmartAI] <mon> (idx) [myTTK=n theirTTK=n
  first=bool]: Move=score, Move=score, SWITCH:Mon=score" followed by what it chose. myTTK = turns it
  needs to KO the foe, theirTTK = turns the foe needs to KO it. Index (0) is side A, (1) is side B.

  Identify CONCRETE MISPLAYS. For each: quote the moment, say what it did, what it should have done,
  and why. Prioritise these classes:
    - wasted turns (a move that could not accomplish anything)
    - clicking into an immunity or a resist when a better option existed
    - failing to heal / healing at the wrong time
    - failing to status or set up when it was safe, or setting up when it was not
    - switching into damage repeatedly, or thrashing between two mons
    - throwing away a win condition, or preserving a dead one
    - ignoring residual damage (poison/burn/Leech Seed/weather) clocks
  Then give: RATING: n/10 for competitive play quality, and the single highest-value fix.
  If the play is genuinely sound, say so - do not invent faults. Be specific and brief; no preamble.
TXT

def condense(log)
  log.map { |l| l.to_s.dup.force_encoding('UTF-8').scrub('?') }
     .select { |l|
       l =~ /\[SmartAI\]/ || l =~ /used |fainted|sent out|It's super effective|not very effective|had no effect|doesn't affect|But it failed|regained|restored|poison|burn|paralyz|asleep|seeded|Stealth Rock|Spikes|rose|fell|flinch|critical/
     }.map { |l| l.gsub(/\s+/, ' ').strip }
end

out = { 'model' => MODEL, 'audits' => {} }
[['OFFENSE_vs_STALL', offense, stall, 61],
 ['OFFENSE_mirror',   offense, offense, 62],
 ['STALL_vs_OFFENSE', stall, offense, 63]].each do |label, a, b, seed|
  r = NativeSim.run(a, b, seed: seed, log: true)
  lines = condense(r[:log])
  File.binwrite(File.join(NStore.dir(OTAG), "#{label}_s#{seed}.log"), lines.join("\n"))
  user = <<~U
    BATTLE: #{label} (seed #{seed}). Result: side #{r[:winner].to_s.upcase} won in #{r[:turns]} turns
    (side A had #{r[:a_alive]} mons left, side B #{r[:b_alive]}).

    SIDE A TEAM:
    #{a.map { |k| '  ' + set_line(k) }.join("\n")}

    SIDE B TEAM:
    #{b.map { |k| '  ' + set_line(k) }.join("\n")}

    FULL LOG (#{lines.length} lines):
    #{lines.first(320).join("\n")}

    Review the play quality of BOTH sides. List the misplays, then RATING: n/10 and the top fix.
  U
  txt = ClaudeClient.complete(system: SYS, user: user, model: MODEL, max_tokens: 1400, cache: true).strip
  out['audits'][label] = txt
  puts "\n#{'=' * 78}\n#{label} (seed #{seed}) — winner #{r[:winner]}, #{r[:turns]} turns\n#{'=' * 78}"
  puts txt
end
NStore.write_json(OTAG, 'audit.json', out)
puts "\nlogs + audit -> #{NStore.dir(OTAG)}"
