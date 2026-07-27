# Quick smoke test: series() + forced-turn short-circuit compile and run.
require_relative 'build_team'
require_relative 'agent_battle'
require_relative 'roster'
SimEngine.boot
$DEBUG = false
field = Roster.field(File.join(__dir__, 'reports', 'hf'))
a, b = 'Sand', 'Squads'
dec, log, tally = SimAgent.series(-> { BuildTeam.team(field[a]) }, -> { BuildTeam.team(field[b]) },
                                  SimAgent.claude_policy(Roster.plan(a), model: 'claude-haiku-4-5-20251001'),
                                  SimAgent.claude_policy(Roster.plan(b), model: 'claude-haiku-4-5-20251001'),
                                  games: 1, cap: 45)
forced = log.count { |l| l.include?('(forced)') }
fallbacks = log.count { |l| l.include?('fallback') }
puts "dec=#{dec} tally=#{tally.inspect} decisions=#{log.count { |l| l =~ /^\s+side/ }} forced_skips=#{forced} fallbacks=#{fallbacks}"
