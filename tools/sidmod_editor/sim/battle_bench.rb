# Stability + throughput check: run N battles of the same matchup with varied seeds.
require_relative 'battle'
SimEngine.boot
$DEBUG = false

def team_a; [Pokemon.new(:PIKACHU, 50), Pokemon.new(:GYARADOS, 50), Pokemon.new(:VENUSAUR, 50)]; end
def team_b; [Pokemon.new(:CHARIZARD, 50), Pokemon.new(:BLASTOISE, 50), Pokemon.new(:SNORLAX, 50)]; end

N = (ARGV[0] || 20).to_i
tally = Hash.new(0)
t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
N.times do |i|
  dec = SimBattle.run(team_a, team_b, seed: i + 1)   # fresh mons each battle (combat mutates them)
  tally[dec] += 1
end
dt = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0
labeled = tally.map { |k, v| "#{SimBattle::DECISION[k] || k}=#{v}" }.join("  ")
puts "results over #{N} battles: #{labeled}"
puts "time: #{dt.round(2)}s total, #{(dt / N * 1000).round}ms/battle  (~#{(N / dt).round}/sec)"
