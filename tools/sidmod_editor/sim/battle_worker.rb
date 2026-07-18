# One parallel worker: runs its shard of the round-robin battles for a tag.
# Skips battles already written (so workers don't collide / can resume).
#   ruby battle_worker.rb <tag> <model> <cap> <shardIndex> <numShards>
require_relative 'roster'
require_relative 'build_team'
require_relative 'agent_battle'
require 'fileutils'
SimEngine.boot
$DEBUG = false

TAG, MODEL, CAP, SHARD, NSHARDS = ARGV[0], ARGV[1], ARGV[2].to_i, ARGV[3].to_i, ARGV[4].to_i
GAMES = (ARGV[5] || 1).to_i     # best-of-N per pairing (majority wins) to cut noise
DIR = File.join(__dir__, 'reports', TAG)
FileUtils.mkdir_p(DIR)

field = Roster.field(DIR)
names = field.keys.sort
pairs = names.combination(2).to_a
mine  = pairs.each_with_index.select { |_, i| i % NSHARDS == SHARD }.map(&:first)

mine.each do |a, b|
  path = File.join(DIR, "#{a}_vs_#{b}.txt")
  next if File.exist?(path)                       # already done by a prior run/worker
  dec, log, tally = SimAgent.series(-> { BuildTeam.team(field[a]) }, -> { BuildTeam.team(field[b]) },
                                    SimAgent.claude_policy(Roster.plan(a), model: MODEL),
                                    SimAgent.claude_policy(Roster.plan(b), model: MODEL),
                                    games: GAMES, cap: CAP)
  winner = dec == 1 ? a : dec == 2 ? b : "draw"
  File.write(path, "#{a} (side0) vs #{b} (side1)  best-of-#{GAMES} #{a}:#{tally[:a]} #{b}:#{tally[:b]} draw:#{tally[:draw]}\n\n" + log.join("\n") + "\n\nWINNER: #{winner}\n")
  warn "[w#{SHARD}] #{a} vs #{b}: #{winner} (#{tally[:a]}-#{tally[:b]})"
end
warn "[w#{SHARD}] done (#{mine.length} pairings in shard)"
