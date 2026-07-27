# One matchup -> one result file. Invoked by prun.rb (must run from game root for engine boot).
#   ruby matchup_worker.rb <job.json>
# job keys: teamA[specs], teamB[specs], planA, planB, model, games, cap, label, out, random(bool)
require_relative 'build_team'; require_relative 'agent_battle'; require_relative 'editor'; require_relative 'roster'
require 'json'
SimEngine.boot; $DEBUG = false
# NOTE: SimEngine.boot (Essentials) patches JSON.parse to symbolize keys, so stringify the
# top-level job keys for consistent access (inner mon-spec keys stay symbols; Editor.normalize
# handles both).
job = JSON.parse(File.read(ARGV[0])).transform_keys(&:to_s)
mk  = ->(specs) { BuildTeam.team(specs.map { |m| Editor.normalize(m) }) }
model = job['model'] || 'claude-sonnet-5'
planA = job['planA'] || (job['planA_name'] && Roster.plan(job['planA_name'])) || ''
planB = job['planB'] || (job['planB_name'] && Roster.plan(job['planB_name'])) || ''
polA = job['random'] ? SimAgent.method(:random_policy) : SimAgent.claude_policy(planA, model: model)
polB = job['random'] ? SimAgent.method(:random_policy) : SimAgent.claude_policy(planB, model: model)
# Output: bulletproof TSV summary (label\ta\tb\tdraw) + plain-text log. NOT JSON — SimEngine.boot
# patches JSON.generate and it fails to escape quote chars in pilot reason strings.
if job['seed']   # SINGLE-GAME mode (prun shards bo-N into N seeded games for full parallelism)
  dec, log = SimAgent.run(mk.(job['teamA']), mk.(job['teamB']), polA, polB,
                          seed: job['seed'].to_i, cap: (job['cap'] || 60))
  a = dec == 1 ? 1 : 0; b = dec == 2 ? 1 : 0; dr = (a + b == 0) ? 1 : 0
  File.write(job['out'], "#{job['label']}\t#{a}\t#{b}\t#{dr}")
  File.write(job['out'].to_s + '.log', "#{job['label']} [seed #{job['seed']}] winner=#{a == 1 ? 'a' : b == 1 ? 'b' : 'draw'}\n\n" + log.join("\n"))
else             # SERIES mode (direct calls / backward compat)
  _d, log, t = SimAgent.series(-> { mk.(job['teamA']) }, -> { mk.(job['teamB']) }, polA, polB,
                               games: (job['games'] || 3), cap: (job['cap'] || 60))
  File.write(job['out'], "#{job['label']}\t#{t[:a]}\t#{t[:b]}\t#{t[:draw]}")
  File.write(job['out'].to_s + '.log', "#{job['label']} #{t[:a]}-#{t[:b]}-#{t[:draw]}\n\n" + log.join("\n"))
end
