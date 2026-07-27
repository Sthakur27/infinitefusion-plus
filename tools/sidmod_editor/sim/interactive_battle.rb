# HUMAN-IN-THE-LOOP battle: side 0 decisions come from a file REPL (Claude main-loop or a fork
# agent pilots hands-on), side 1 is the normal Sonnet policy OR the native max-skill AI. The engine
# blocks each turn until an action file with the matching decision counter appears. FAINT
# REPLACEMENTS are routed to the pilot too (via $SIM_REPLACE).
#   ruby interactive_battle.rb <comm_dir> <opponent_key> [seed] [teamA_specs.json]
# Protocol:
#   engine -> <comm_dir>/ib_state.txt   "DECISION <n>\n<state prompt>"          (move turn)
#   engine -> <comm_dir>/ib_state.txt   "DECISION <n> REPLACE\n<party listing>" (pick replacement)
#   pilot  -> <comm_dir>/ib_action.txt  "DECISION <n> move <idx> | <reason>"    (or "switch <idx>")
#   end    -> ib_state.txt starts with "GAME OVER", full log in ib_result.txt
#
# SAVE / REWIND (deterministic replay, not snapshots): every pilot decision is journaled. To rewind,
# the pilot writes "DECISION <n> rewind <k>" - the battle is thrown out and re-run on the SAME seed,
# auto-replaying journaled decisions 1..k-1 (identical because deterministic), then hands control
# back live at decision k. New decisions from k onward overwrite the journal tail -> you can branch.
require_relative 'build_team'; require_relative 'agent_battle'; require_relative 'editor'; require_relative 'roster'
SimEngine.boot; $DEBUG = false
$SIM_DEBUG_REPLACE = true   # capture evidence if the early-end bug fires (ccna diagnostics -> stderr)
COMM  = ARGV[0]
OPP   = ARGV[1] || 'GoldKaizo'
SEED  = (ARGV[2] || 42).to_i
TEAMF = ARGV[3]

V2 = ClaudeClient::PARSE.call(File.read(File.join(__dir__, 'reports', 'final_v2', 'field_specs.json')))
G  = ClaudeClient::PARSE.call(File.read(File.join(__dir__, 'reports', 'blue_gauntlet', 'field_specs.json')))
FIELD = V2.merge(G)
mk = ->(specs) { BuildTeam.team(specs.map { |m| Editor.normalize(m) }) }
team_a_specs = TEAMF ? ClaudeClient::PARSE.call(File.read(TEAMF)) : V2['OUSand']
PLAN = Roster.plan(ENV['IB_PLAN'] || 'OUSand')

COMM_DIR   = COMM
STATE_F    = File.join(COMM, 'ib_state.txt')
ACTION_F   = File.join(COMM, 'ib_action.txt')
JOURNAL_F  = File.join(COMM, 'ib_journal.tsv')

def await_action(counter)
  loop do
    if File.exist?(ACTION_F)
      txt = (File.read(ACTION_F).strip rescue "")
      return txt.sub("DECISION #{counter} ", "").strip if txt.start_with?("DECISION #{counter} ")
    end
    sleep 0.4
  end
end

# Shared, mutated across re-runs (closures capture by reference; the loop resets `counter`).
counter      = 0
journal      = {}     # counter => raw action string ("move 2 | reason")
replay_until = 0      # decisions with counter < replay_until are auto-replayed from the journal
persist = lambda { File.write(JOURNAL_F, journal.keys.sort.map { |k| "#{k}\t#{journal[k]}" }.join("\n")) rescue nil }
rewind_of = lambda { |act| act =~ /\Arewind\s+(\d+)/i ? $1.to_i : nil }

human = lambda do |battle, i, st|
  counter += 1
  lm = st["moves"]; sw = st["switches"]
  if lm.length == 1 && sw.empty?              # forced: deterministic, no journaling / no prompt
    $SIM_LAST_REASON = "(forced)"
    next [:move, lm[0]["idx"]]
  end
  if counter < replay_until && journal[counter]   # replay a prior decision, no IO
    body, reason = journal[counter].split("|", 2).map(&:strip)
    kind, idx = body.split
    $SIM_LAST_REASON = "#{reason || '(replay)'} [replayed]"
    next [kind.to_sym, idx.to_i]
  end
  File.write(STATE_F, "DECISION #{counter}\n#{SimAgent.build_prompt(st, PLAN)}\n" \
    "[REWIND: reply 'DECISION #{counter} rewind <decision#>' to jump back and re-pilot from there]")
  act = await_action(counter)
  if (k = rewind_of.call(act)); throw(:rewind, k); end
  journal[counter] = act; persist.call
  body, reason = act.split("|", 2).map(&:strip)
  kind, idx = body.split
  $SIM_LAST_REASON = reason || "(claude hands-on)"
  [kind.to_sym, idx.to_i]
end

# Pilot chooses faint replacements for side 0; side 1 falls through to the engine AI.
$SIM_REPLACE = lambda do |battle, idxBattler, party|
  next -1 unless (idxBattler % 2) == 0
  counter += 1
  able = (0...party.length).select { |pi| battle.pbCanSwitchLax?(idxBattler, pi) }
  next -1 if able.empty?
  next able[0] if able.length == 1
  if counter < replay_until && journal[counter]
    idx = journal[counter][/\d+/].to_i
    next(able.include?(idx) ? idx : able[0])
  end
  foe = battle.battlers[(idxBattler + 1) % 2]
  foe_desc = (foe && !foe.fainted?) ? "#{foe.pbThis(true)} #{SimAgent.pct(foe)}% types=#{(foe.pbTypes(true).map(&:to_s).join('/') rescue '?')}" : "?"
  lines = ["DECISION #{counter} REPLACE", "Your active fainted. CHOOSE THE REPLACEMENT. Opponent active: #{foe_desc}", "OPTIONS:"]
  able.each { |pi| pk = party[pi]; lines << "  [#{pi}] #{pk.name || pk.speciesName} #{(pk.hp * 100 / [pk.totalhp, 1].max)}%HP" }
  lines << "Respond in ib_action.txt: 'DECISION #{counter} switch <idx> | reason'  (or 'DECISION #{counter} rewind <decision#>')"
  File.write(STATE_F, lines.join("\n"))
  act = await_action(counter)
  if (k = rewind_of.call(act)); throw(:rewind, k); end
  journal[counter] = act; persist.call
  idx = act[/\d+/].to_i
  able.include?(idx) ? idx : able[0]
end

if ENV['IB_NATIVE_OPP']   # side 1 = real upgraded native trainer AI at max skill
  $SIM_NATIVE_SIDES = [1]
  SimEngine.trainer_type.instance_variable_set(:@skill_level, PBTrainerAI.bestSkill) rescue nil
  pol2 = SimAgent.method(:random_policy)  # never called for side 1 (native takes over)
else
  pol2 = SimAgent.claude_policy(Roster.plan(OPP), model: 'claude-sonnet-5')
end

# Re-run loop: a `throw(:rewind, k)` from a decision unwinds the whole battle (bypassing
# SimBattle.run's `rescue Exception`, which would otherwise swallow it as a draw) and we restart.
result = nil
loop do
  counter = 0
  outcome = catch(:rewind) do
    SimAgent.run(mk.(team_a_specs), mk.(FIELD[OPP]), human, pol2, seed: SEED, cap: nil)
  end
  if outcome.is_a?(Integer)           # rewind requested to decision `outcome`
    target = [outcome, 1].max
    replay_until = target
    journal.reject! { |k, _| k >= target }; persist.call
    File.write(STATE_F, "REWOUND to DECISION #{target}. Replaying #{target - 1} prior decisions, then live...")
    next
  end
  result = outcome                    # [dec, log]
  break
end

$SIM_REPLACE = nil; $SIM_NATIVE_SIDES = nil
dec, log = result
who = dec == 1 ? 'ME (pilot)' : dec == 2 ? "OPPONENT (#{OPP})" : 'draw'
File.write(File.join(COMM, 'ib_result.txt'), "winner=#{who}\n\n" + log.join("\n"))
File.write(STATE_F, "GAME OVER winner=#{who}\n")
puts "RESULT winner=#{who}"
