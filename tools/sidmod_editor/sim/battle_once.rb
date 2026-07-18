# Milestone 1: one complete headless AI-vs-AI battle -> printed winner.
require_relative 'battle'
SimEngine.boot(verbose: true)
$DEBUG = false   # some loaded script flips this on; it spams "Exception at" traces
warn "trainer_type = #{SimEngine.trainer_type.inspect}"

team1 = [Pokemon.new(:PIKACHU, 50), Pokemon.new(:GYARADOS, 50), Pokemon.new(:VENUSAUR, 50)]
team2 = [Pokemon.new(:CHARIZARD, 50), Pokemon.new(:BLASTOISE, 50), Pokemon.new(:SNORLAX, 50)]

warn "team1: #{team1.map(&:speciesName).join(', ')}"
warn "team2: #{team2.map(&:speciesName).join(', ')}"
warn "starting battle..."

begin
  dec = SimBattle.run(team1, team2, seed: 12345)
  puts "\nDECISION: #{dec} -> #{SimBattle::DECISION[dec] || 'unknown'}"
rescue Exception => e
  puts "\nBATTLE ERROR: #{e.class}: #{e.message.lines.first.to_s.strip}"
  puts e.backtrace.reject { |b| b =~ /internal:ast/ }.first(10)
end
