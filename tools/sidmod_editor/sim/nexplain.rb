# AGENT-WRITTEN rationale for the report. For each top team and each top mon this
# plays 1-2 REAL battles with logging on, then hands the actual battle log plus the
# measured statistics to Claude and asks why the thing performs as it does.
#
#   ruby tools/sidmod_editor/sim/nexplain.rb <rating_tag> <tourney_tag> [top_n] [model]
#
# Writes <tourney_tag>/explanations.json consumed by nreport2.rb, and keeps every
# log it showed the agent under <tourney_tag>/explain_logs/ so any claim can be
# checked against the battle it came from.
#
# The agent sees ONLY real data: full rosters/sets, the measured record, and a
# turn-by-turn log including the SmartAI's own decision lines. It is told to say
# so when the log does not support a conclusion.
require_relative 'nstore'
require_relative 'nbattle'
require_relative 'claude_client'
require 'fileutils'

RTAG  = ARGV[0] || 'ou3'
TTAG  = ARGV[1] || 'ou3clean'
TOPN  = (ARGV[2] || 15).to_i
MODEL = ARGV[3] || 'claude-sonnet-5'

ENV['NSIM_SAVE'] = File.join(NStore.dir(RTAG), 'save_snapshot.rxdata') if
  File.exist?(File.join(NStore.dir(RTAG), 'save_snapshot.rxdata'))
NativeSim.boot!

POOL = NStore.read_json(RTAG, 'pool.json')
rat  = File.readlines(File.join(NStore.dir(RTAG), 'ratings.csv'))
HDR  = rat[0].chomp.split(',')
MONS = rat[1..].map { |l| HDR.zip(l.chomp.split(',')).to_h }
LB   = NStore.read_json(TTAG, 'leaderboard.json')
TEAMS = NStore.read_teams(TTAG)
LOGDIR = File.join(NStore.dir(TTAG), 'explain_logs'); FileUtils.mkdir_p(LOGDIR)

def sp_name(sym); (GameData::Species.get(sym.to_s.to_sym).name rescue sym.to_s.capitalize); end

def fusion_of(key)
  p = POOL[key] or return key.to_s
  b = p['bases'] || []
  return p['species'] if b.length < 2
  b.length == 2 ? "#{p['species']} (head #{sp_name(b[0])} / body #{sp_name(b[1])})"
                : "#{p['species']} (triple #{b.map { |x| sp_name(x) }.join('+')})"
end

def set_line(key)
  p = POOL[key] or return key.to_s
  "#{p['name']} = #{fusion_of(key)} | #{p['types']} | #{p['ability']} | #{p['item']} | " \
    "#{p['moves'].join(', ')} | EVs #{p['evs']} | stats HP#{p['stats'][0]} Atk#{p['stats'][1]} " \
    "Def#{p['stats'][2]} SpA#{p['stats'][3]} SpD#{p['stats'][4]} Spe#{p['stats'][5]}"
end

# Unusual conditions stated as flat assertions. An earlier run had the agent claim a
# 1-HP Shedinja fusion "keeps its normal HP" — it misread the stats line — so the
# facts that are easy to get wrong are spelled out instead of left to inference.
def hard_facts(key)
  p = POOL[key] or return ''
  f = []
  hp = p['stats'][0].to_i
  f << "MAX HP IS #{hp} — literally #{hp} hit point#{hp == 1 ? '' : 's'}. ANY damage kills it, " \
       "including Stealth Rock, sandstorm/hail, poison, burn and recoil. It is not bulky." if hp <= 5
  f << "Ability is Wonder Guard: only super-effective moves damage it (but see the HP note, and " \
       "residual damage from weather/hazards/status ignores Wonder Guard)." if p['ability'].to_s =~ /Wonder Guard/i
  f << "Holds a Choice item, so it is locked into one move after attacking." if p['item'].to_s =~ /Choice/
  f << "Its Speed stat is #{p['stats'][5]} — low for this pool, so it usually moves second." if p['stats'][5].to_i < 200
  f.empty? ? '' : "HARD FACTS about #{p['name']} (these are measured from the game data and " \
                  "override any assumption):\n" + f.map { |x| "  - #{x}" }.join("\n")
end

# Keep the log readable and cheap: the decision lines + what actually happened.
# Engine strings are ASCII-8BIT (they carry the é in "Pokémon"), so re-tag them as
# UTF-8 and scrub before they meet any UTF-8 literal.
def condense(log, focus: nil)
  log = log.map { |l| l.to_s.dup.force_encoding('UTF-8').scrub('?') }
  keep = log.select { |l|
    l =~ /\[SmartAI\].*will (use|switch)/ || l.include?('replacement pick') ||
    l =~ /used |fainted|sent out|withdrew|It's super effective|not very effective|had no effect|critical hit|Sandstorm|rain|sunlight|hail|Stealth Rock|Spikes|boosted|fell|rose|paralyz|burn|poison|asleep|flinch/
  }
  keep = keep.select { |l| l.include?(focus) } + keep.first(6) if focus && keep.length > 90
  keep.map { |l| l.gsub(/\s+/, ' ').strip }.first(110).join("\n")
end

SYS = <<~TXT
  You are analysing battle results from a Pokemon Infinite Fusion battle simulator. Both sides are
  played by the same deterministic in-game AI (no humans, no LLMs), every mon is level 100, and the
  results come from hundreds of seeded battles per subject.

  You will be given: the exact sets involved, the measured statistics, and a turn-by-turn log of one
  or two real battles (including the AI's own internal "[SmartAI] ... will use/switch" decision lines).

  Write 2-3 sentences explaining WHY the subject performs the way the statistics show. Rules:
  - Ground every claim in the sets, the numbers, or something visible in the log. Cite a concrete
    mechanic (ability, item, priority, typing, stat) rather than generic praise.
  - Fusions inherit an ability from ONE parent, so a fusion can carry a parent's ability without its
    drawback (e.g. a Slaking fusion that does not have Truant). Note this when relevant.
  - If the log contradicts or fails to support the statistics, say that plainly instead of inventing
    a story. It is fine to say the log shows something different from what the numbers suggest.
  - READ THE STAT LINE LITERALLY. Stats are given as HP/Atk/Def/SpA/SpD/Spe in that order. Never
    restate a number you were not given, and never assume a stat is "normal" when the data says
    otherwise. Any "HARD FACTS" block is measured ground truth and overrides your priors.
  - No preamble, no bullet points, no headings. Plain prose only. Never exceed 3 sentences.
TXT

out = { 'model' => MODEL, 'generated' => Time.now.to_s, 'teams' => {}, 'mons' => {} }
ids = TEAMS.keys

puts "=== agent rationale: #{TOPN} teams + #{TOPN} mons via #{MODEL} ==="

# ---------------------------------------------------------------- teams ------
LB.first(TOPN).each_with_index do |row, rank|
  tid  = row['team']
  keys = row['keys']
  # Opponent = a MID-TABLE team, not the next rank up: adjacent top teams share most
  # of their roster, so those logs are near-mirrors and show atypical play. Then scan
  # seeds and show the agent one WIN and one LOSS where possible, so it sees both how
  # the team converts and how it gets beaten instead of a single unrepresentative game.
  opp_row = LB[[LB.length / 2, 1].max]
  opp_row = LB[rank + 1] || LB[rank - 1] if opp_row['team'] == tid
  opp = opp_row['keys']; opp_id = opp_row['team']
  wins = []; losses = []
  (1..10).each do |seed|
    break if wins.any? && losses.any?
    r = NativeSim.run(keys, opp, seed: seed, log: true)
    (r[:winner] == :a ? wins : losses) << [seed, r] if r[:winner] != :draw
  end
  picked = [wins.first, losses.first].compact
  picked = wins.first(2) if picked.length < 2 && wins.length >= 2
  picked = losses.first(2) if picked.empty? && losses.length >= 2
  logs = picked.map do |seed, r|
    File.binwrite(File.join(LOGDIR, "team_#{tid.gsub(/\W/, '_')}_s#{seed}.log"), r[:log].join("\n"))
    "BATTLE (seed #{seed}) — result: #{r[:winner] == :a ? tid + ' WON' : (r[:winner] == :b ? opp_id + ' won' : 'draw')} " \
      "in #{r[:turns]} turns, survivors #{r[:a_alive]} vs #{r[:b_alive]}\n" + condense(r[:log])
  end
  logs << "(no #{wins.empty? ? 'win' : 'loss'} occurred in 10 seeds against this opponent)" if picked.length < 2
  user = <<~U
    SUBJECT: team `#{tid}` — ranked #{rank + 1} of #{LB.length} in a full round robin.
    MEASURED: winrate #{'%.3f' % row['winrate']} over #{row['games']} battles, Elo #{'%+.0f' % row['elo']}.

    ITS SIX SETS:
    #{keys.map { |k| '  ' + set_line(k) }.join("\n")}
    #{keys.map { |k| hard_facts(k) }.reject(&:empty?).join("\n")}

    OPPONENT IN THE LOGS BELOW (`#{opp_id}`, winrate #{'%.3f' % opp_row['winrate']}):
    #{opp.map { |k| '  ' + set_line(k) }.join("\n")}

    #{logs.join("\n\n")}

    Why does `#{tid}` perform at this level? Several other top-ranked teams share some of these
    mons, so where the evidence allows, say what distinguishes THIS roster rather than describing a
    mon both teams have. 2-3 sentences.
  U
  txt = ClaudeClient.complete(system: SYS, user: user, model: MODEL, max_tokens: 400, cache: true).strip
  out['teams'][tid] = txt
  puts "  [team #{rank + 1}/#{TOPN}] #{tid}: #{txt[0, 90]}..."
end

# ----------------------------------------------------------------- mons ------
# A mon's rating was measured on RANDOM teams, so the log it is explained from uses
# random teammates too — otherwise the agent would be explaining a number that came
# from one context using evidence from another. Opponent is a mid-table field team,
# and we show one battle where the mon performed and one where it did not.
pool_keys = MONS.map { |x| x['key'] }.select { |k| POOL[k] }
MONS.first(TOPN).each_with_index do |m, rank|
  key = m['key']
  rng = Random.new(4000 + rank)
  bases = {}
  ((POOL[key] && POOL[key]['bases']) || []).each { |b| bases[b] = true }
  host = [key]
  pool_keys.shuffle(random: rng).each do |k|
    break if host.length == 6
    next if host.include?(k)
    bs = POOL[k]['bases'] || []
    next if bs.any? { |b| bases[b] }
    bs.each { |b| bases[b] = true }
    host << k
  end
  opp = LB[[LB.length / 2, 1].max]['keys']
  good = []; bad = []
  (21..30).each do |seed|
    break if good.any? && bad.any?
    r = NativeSim.run(host, opp, seed: seed, log: true)
    st = r[:a][host.index(key)]
    (st[:kos] >= 1 ? good : bad) << [seed, r, st]
  end
  picked = [good.first, bad.first].compact
  picked = good.first(2) if picked.length < 2 && good.length >= 2
  picked = bad.first(2)  if picked.empty? && bad.length >= 2
  logs = picked.map do |seed, r, stat|
    File.binwrite(File.join(LOGDIR, "mon_#{key}_s#{seed}.log"), r[:log].join("\n"))
    "BATTLE (seed #{seed}) — #{POOL[key]['name']} scored #{stat[:kos]} KOs, " \
      "#{stat[:fainted] ? 'fainted' : "survived at #{(stat[:hp] * 100).round}% HP"}; " \
      "its team #{r[:winner] == :a ? 'won' : (r[:winner] == :b ? 'lost' : 'drew')} in #{r[:turns]} turns\n" +
      condense(r[:log], focus: POOL[key]['name'].to_s)
  end
  user = <<~U
    SUBJECT: #{POOL[key]['name']} = #{fusion_of(key)} — rated ##{rank + 1} of #{MONS.length} in the pool.
    MEASURED over #{m['games']} battles on random teams: team winrate #{m['winrate']},
    #{m['kos_per_game']} KOs per battle, faints in #{m['faint_rate']} of battles,
    contribution coefficient #{m['coef']} (teammates controlled for).

    ITS SET: #{set_line(key)}
    #{hard_facts(key)}

    TEAMMATES IN THE LOGS (randomly assembled, matching how the rating was measured): #{host.reject { |k| k == key }.map { |k| POOL[k]['name'] }.join(', ')}
    OPPOSING TEAM: #{opp.map { |k| '  ' + set_line(k) }.join("\n")}

    #{logs.join("\n\n")}

    Why is this mon rated this highly? 2-3 sentences.
  U
  txt = ClaudeClient.complete(system: SYS, user: user, model: MODEL, max_tokens: 400, cache: true).strip
  out['mons'][key] = txt
  puts "  [mon #{rank + 1}/#{TOPN}] #{POOL[key]['name']}: #{txt[0, 90]}..."
end

File.binwrite(File.join(NStore.dir(TTAG), 'explanations.json'), NStore::GEN.call(out))
puts "\nwrote #{File.join(NStore.dir(TTAG), 'explanations.json')}"
puts "logs shown to the agent -> #{LOGDIR}"
