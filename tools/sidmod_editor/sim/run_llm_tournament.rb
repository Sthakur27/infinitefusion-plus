# Full LLM-agent tournament + refinement. Round-robins the roster with Claude
# agents on both sides, writes every battle log + a summary + coach recommendations
# to sim/reports/. READ-ONLY on the save; writes only under reports/.
#   ruby run_llm_tournament.rb [N_per_pairing=1] [teamsCSV] [cap=80]
require_relative 'teams'
require_relative 'agent_battle'
require_relative 'coach'
SimEngine.boot
$DEBUG = false

REPORTS = File.join(__dir__, 'reports')
Dir.mkdir(REPORTS) unless Dir.exist?(REPORTS)

PLANS = {
  "Sun"     => "Sun team. Keep Drought sun up; Solar Power Draflosion & Chlorophyll Volferia sweep; Noida has Spore/Taunt/U-turn; Bastion sets Sticky Web. Deny enemy weather.",
  "Rain"    => "Rain team. Keep Drizzle rain (Swift Swim + 100% Thunder/Hurricane); Draking resists Grass+Electric; multiple setup sweepers. Overwrite enemy weather.",
  "Sand"    => "Sand team. Keep Sand Stream up (+SpD to Rock allies); physical Dragon Dance sweepers; Krookodile/Salamence answers Fighting.",
  "Squads"  => "Legendary squad. Strong individual threats; play to type/coverage advantages.",
  "Squads2" => "Legendary squad. Strong individual threats; play to type/coverage advantages.",
  "Squads3" => "Legendary squad. Strong individual threats; play to type/coverage advantages.",
}

N     = (ARGV[0] || 1).to_i
sel   = (ARGV[1] && !ARGV[1].empty? && ARGV[1].downcase != "all") ? ARGV[1].split(",") : nil
cap   = (ARGV[2] || 80).to_i
MODEL = ARGV[3] || "claude-haiku-4-5-20251001"   # ruby run_llm_tournament.rb [N] [teamsCSV|all] [cap] [model]

teams = SimTeams.load
teams = teams.select { |k, _| sel.include?(k) } if sel
names = teams.keys
puts "Roster: #{names.join(', ')}  |  #{N} battle(s)/pairing  |  cap #{cap} decisions"

results = []
t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
names.combination(2).each do |a, b|
  N.times do |k|
    dec, log = SimAgent.run(
      SimTeams.clone(teams[a]), SimTeams.clone(teams[b]),
      SimAgent.claude_policy(PLANS[a] || "", model: MODEL), SimAgent.claude_policy(PLANS[b] || "", model: MODEL),
      seed: k + 1, cap: cap
    )
    winner = dec == 1 ? a : dec == 2 ? b : "draw"
    header = "#{a} (side0) vs #{b} (side1)  battle #{k + 1}\n" \
             "team #{a}: #{teams[a].map(&:speciesName).join(', ')}\n" \
             "team #{b}: #{teams[b].map(&:speciesName).join(', ')}\n\n"
    File.write(File.join(REPORTS, "#{a}_vs_#{b}_#{k + 1}.txt"), header + log.join("\n") + "\n\nWINNER: #{winner}\n")
    results << [a, b, winner]
    puts "  #{a} vs #{b} ##{k + 1}: #{winner}"
  end
end
dt = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0

wins = Hash.new(0); games = Hash.new(0)
results.each { |a, b, w| games[a] += 1; games[b] += 1; wins[w] += 1 if [a, b].include?(w) }
matrix  = results.map { |a, b, w| "#{a} vs #{b}: #{w}" }.join("\n")
ranking = names.sort_by { |n| -(wins[n].to_f / [games[n], 1].max) }
                .map { |n| "#{n.ljust(9)} #{(100.0 * wins[n] / [games[n], 1].max).round}%  (#{wins[n]}/#{games[n]})" }.join("\n")
summary = "RESULTS\n#{matrix}\n\nWIN RATES\n#{ranking}\n\n#{results.length} battles in #{dt.round(1)}s"
File.write(File.join(REPORTS, "summary.txt"), summary)
puts "\n#{summary}"

# --- refinement: coach reads results + a few logs, writes recommendations ---
sample = results.first(4).map do |a, b, _|
  fn = File.join(REPORTS, "#{a}_vs_#{b}_1.txt")
  File.exist?(fn) ? "=== #{a} vs #{b} ===\n#{File.read(fn)}" : nil
end.compact.join("\n\n")
puts "\nAsking coach for recommendations..."
rec = SimCoach.recommend("#{matrix}\n\n#{ranking}", sample)
File.write(File.join(REPORTS, "recommendations.txt"), rec)
puts "\nreports/ written: per-battle logs, summary.txt, recommendations.txt"
