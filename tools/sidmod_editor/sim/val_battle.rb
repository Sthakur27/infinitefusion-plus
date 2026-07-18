# Hand-held validation: FULL Momentum vs Sand game on Haiku + effectiveness prompt.
# Prints every decision + the fallback rate (fallbacks = failed API call -> random).
require_relative 'teams'
require_relative 'my_team'
require_relative 'agent_battle'
SimEngine.boot
$DEBUG = false

M = "claude-haiku-4-5-20251001"
mine = BuildTeam.team(MY_TEAMS["Momentum"])
sand = SimTeams.clone(SimTeams.load["Sand"])
mp = "Balance team; VoltTurn momentum; win-cons Rhychomp/Gentom/Lucazor; Cofamory wall; Scarf+priority speed control."
sp = "Sand team; Sand Stream; physical Dragon Dance sweepers; Krookodile/Salamence answers Fighting."

dec, log = SimAgent.run(mine, sand,
                        SimAgent.claude_policy(mp, model: M), SimAgent.claude_policy(sp, model: M),
                        seed: 1, cap: 60)
fb = log.count { |l| l =~ /fallback/ }
puts "RESULT: #{dec == 1 ? 'Momentum' : dec == 2 ? 'Sand' : 'draw'}   #{log.length} decisions, #{fb} fallbacks (#{(100.0*fb/[log.length,1].max).round}%)"
puts log
