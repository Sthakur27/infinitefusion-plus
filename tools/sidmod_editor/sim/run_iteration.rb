# Full iteration: 7-team round-robin (Sid's Sun/Rain/Sand/Squads + Claude's
# Momentum/Overload/Bunker), Claude agents on both sides, misplay-aware coach.
# READ-ONLY on the save; output under reports/<tag>/.  ruby run_iteration.rb [tag] [model] [cap]
require_relative 'teams'
require_relative 'my_team'
require_relative 'agent_battle'
require_relative 'coach'
SimEngine.boot
$DEBUG = false

# ruby run_iteration.rb [tag] [model] [cap] [teamsCSV|all]
TAG   = ARGV[0] || "iter1"
MODEL = ARGV[1] || "claude-haiku-4-5-20251001"   # Haiku for players (Sonnet's thinking breaks small per-move calls)
CAP   = (ARGV[2] || 70).to_i
SEL   = (ARGV[3] && !ARGV[3].empty? && ARGV[3].downcase != "all") ? ARGV[3].split(",") : nil
DIR = File.join(__dir__, 'reports', TAG)
require 'fileutils'; FileUtils.mkdir_p(DIR)

their = SimTeams.load
ROSTER = {
  "Sun"      => -> { SimTeams.clone(their["Sun"]) },
  "Rain"     => -> { SimTeams.clone(their["Rain"]) },
  "Sand"     => -> { SimTeams.clone(their["Sand"]) },
  "Squads"   => -> { SimTeams.clone(their["Squads"]) },     # all-star (Astraleon etc.)
  "Momentum" => -> { BuildTeam.team(MY_TEAMS["Momentum"]) },
  "Overload" => -> { BuildTeam.team(MY_TEAMS["Overload"]) },
  "Bunker"   => -> { BuildTeam.team(MY_TEAMS["Bunker"]) },
  "Box15A"   => -> { SimTeams.clone(their["Box15A"]) },
  "Box15B"   => -> { SimTeams.clone(their["Box15B"]) },
  "Box15C"   => -> { SimTeams.clone(their["Box15C"]) },
}
PLANS = {
  "Sun"      => "Sun team: Drought; Solar Power/Chlorophyll fire sweepers; Noida Spore/Taunt/U-turn; Bastion Sticky Web.",
  "Rain"     => "Rain team: Drizzle; Swift Swim + 100% Thunder/Hurricane; Draking resists Grass+Electric; setup sweepers.",
  "Sand"     => "Sand team: Sand Stream (+SpD Rock allies); physical Dragon Dance sweepers; Krookodile/Salamence answers Fighting.",
  "Squads"   => "Legendary all-star: Astraleon (Pixilate Extreme Speed priority), strong coverage; clean up with priority.",
  "Momentum" => "Balance, weather-independent: VoltTurn momentum (Magnevoir/Weavdactyl), win-cons Rhychomp/Gentom/Lucazor, Cofamory wall+hazards (immune Normal/Fighting/Ground), Scarf+Bullet Punch speed control.",
  "Overload" => "Hyper-offense: fast mixed breakers with coverage no wall survives; pick the SUPER-effective move, click Nasty Plot/Swords Dance when safe, Electidactyl Scarf + Weavswine Ice Shard revenge.",
  "Bunker"   => "Fat balance: set Spikes/hazards, Regenerator pivots (Slowgrowth), Blismory special wall, Rapid Spin (Starcruel), Lucazor Bullet Punch priority, Suileon Calm Mind wincon. Outlast and grind.",
  "Box15A"   => "AI-made legendary offense (Kyogre/Deoxys/Latios/Reshiram/Rayquaza/Arceus fusions); exploit coverage + type advantages.",
  "Box15B"   => "AI-made legendary team (Kyogre/Mew, Dialga, Giratina, Groudon, Kyurem, Ninetales/Celebi); strong coverage.",
  "Box15C"   => "AI-made non-legendary bulky team (Reuniclus/Slowbro/Rhyperior/Chandelure/Aggron/Slaking fusions); grind with bulk + coverage.",
}

names = ROSTER.keys
names = names.select { |n| SEL.include?(n) } if SEL
puts "Iteration '#{TAG}': #{names.length} teams, model #{MODEL}, cap #{CAP} (#{names.combination(2).count} battles)"

results = []
t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
names.combination(2).each do |a, b|
  dec, log = SimAgent.run(ROSTER[a].call, ROSTER[b].call,
                          SimAgent.claude_policy(PLANS[a], model: MODEL),
                          SimAgent.claude_policy(PLANS[b], model: MODEL),
                          seed: 1, cap: CAP)
  winner = dec == 1 ? a : dec == 2 ? b : "draw"
  File.write(File.join(DIR, "#{a}_vs_#{b}.txt"), "#{a} (side0) vs #{b} (side1)\n\n" + log.join("\n") + "\n\nWINNER: #{winner}\n")
  results << [a, b, winner]
  puts "  #{a} vs #{b}: #{winner}"
end
dt = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0

wins = Hash.new(0); games = Hash.new(0)
results.each { |a, b, w| games[a] += 1; games[b] += 1; wins[w] += 1 if [a, b].include?(w) }
matrix  = results.map { |a, b, w| "#{a} vs #{b}: #{w}" }.join("\n")
ranking = names.sort_by { |n| -(wins[n].to_f / [games[n], 1].max) }
                .map { |n| "#{n.ljust(9)} #{(100.0 * wins[n] / [games[n], 1].max).round}%  (#{wins[n]}/#{games[n]})" }.join("\n")
summary = "RESULTS\n#{matrix}\n\nWIN RATES\n#{ranking}\n\n#{results.length} battles in #{dt.round(0)}s"
File.write(File.join(DIR, "summary.txt"), summary)
puts "\n#{summary}"

logs = Dir[File.join(DIR, '*_vs_*.txt')].sort.map { |f| "=== #{File.basename(f, '.txt')} ===\n#{File.read(f)}" }.join("\n\n")
puts "\nCoach analyzing (misplay-aware)..."
rec = SimCoach.recommend(matrix + "\n\n" + ranking, logs)
File.write(File.join(DIR, "recommendations.txt"), rec)
puts "written to reports/#{TAG}/ (battles, summary.txt, recommendations.txt)"
