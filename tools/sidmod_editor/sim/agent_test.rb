# Prove the external-decision hook works (random policy, no API). If the battle
# completes using OUR injected choices and logs them, the LLM swap is trivial.
require_relative 'teams'
require_relative 'agent_battle'
SimEngine.boot
$DEBUG = false

teams = SimTeams.load
dec, actions = SimAgent.run(SimTeams.clone(teams["Sun"]), SimTeams.clone(teams["Rain"]), seed: 3)

puts "decisions injected: #{actions.length}"
puts actions.first(24)
puts "..."
puts "RESULT: #{dec} -> #{dec == 1 ? 'Sun' : dec == 2 ? 'Rain' : SimBattle::DECISION[dec]}"
