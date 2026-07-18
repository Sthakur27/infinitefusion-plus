# Evolution phase 2/3: VALIDATE (one parallel worker). Runs its shard of the
# candidate-vs-field battles proposed by evolve_propose.rb. Skips battles already
# written (resumable / collision-free).  READ-ONLY on the save.
#   ruby val_worker.rb <out_tag> <model> <cap> <shardIndex> <numShards>
require_relative 'build_team'
require_relative 'agent_battle'
require_relative 'editor'
require_relative 'claude_client'
require_relative 'roster'
require 'fileutils'
SimEngine.boot
$DEBUG = false

OUT_TAG, MODEL, CAP, SHARD, NSHARDS = ARGV[0], ARGV[1], ARGV[2].to_i, ARGV[3].to_i, ARGV[4].to_i
GAMES = (ARGV[5] || 1).to_i     # best-of-N per validation pairing (majority) to cut noise
OUT_DIR = File.join(__dir__, 'reports', OUT_TAG)
VAL_DIR = File.join(OUT_DIR, 'val')
FileUtils.mkdir_p(VAL_DIR)

norm = ->(t) { t.map { |m| Editor.normalize(m) } }
field = ClaudeClient::PARSE.call(File.read(File.join(OUT_DIR, 'field_in.json'))).transform_values { |t| norm.(t) }
cands = ClaudeClient::PARSE.call(File.read(File.join(OUT_DIR, 'candidates.json')))

# job list: each CHANGED candidate vs every OTHER field team (candidate is side0)
jobs = []
cands.each { |name, c| next unless c["changed"]; (field.keys - [name]).each { |opp| jobs << [name, opp] } }
jobs.sort!
mine = jobs.each_with_index.select { |_, i| i % NSHARDS == SHARD }.map(&:first)

mine.each do |name, opp|
  path = File.join(VAL_DIR, "#{name}_vs_#{opp}.txt")
  next if File.exist?(path)
  cand = norm.(cands[name]["cand"])
  dec, log, tally = SimAgent.series(-> { BuildTeam.team(cand) }, -> { BuildTeam.team(field[opp]) },
                                    SimAgent.claude_policy(Roster.plan(name), model: MODEL),
                                    SimAgent.claude_policy(Roster.plan(opp),  model: MODEL),
                                    games: GAMES, cap: CAP)
  winner = dec == 1 ? name : dec == 2 ? opp : "draw"
  File.write(path, "#{name} (v2, side0) vs #{opp} (side1)  best-of-#{GAMES} #{name}:#{tally[:a]} #{opp}:#{tally[:b]} draw:#{tally[:draw]}\n\n" + log.join("\n") + "\n\nWINNER: #{winner}\n")
  warn "[v#{SHARD}] #{name} vs #{opp}: #{winner} (#{tally[:a]}-#{tally[:b]})"
end
warn "[v#{SHARD}] done (#{mine.length} battles in shard)"
