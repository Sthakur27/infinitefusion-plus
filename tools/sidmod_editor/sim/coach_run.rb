# Run the coach on an EXISTING tag's battle results (no new battles). Loads each team's
# roster so the coach can give identity-aware, diverse fixes. Writes recommendations to a
# model-labeled file so different coach models can be compared.  READ-ONLY on the save.
#   ruby coach_run.rb <tag> [model]     e.g. ruby coach_run.rb round1 claude-opus-4-8
require_relative 'build_team'      # boots engine chain (needed for SpecExtract roster resolution)
require_relative 'roster'
require_relative 'coach'
SimEngine.boot
$DEBUG = false

TAG   = ARGV[0] or abort "usage: coach_run.rb <tag> [model]"
MODEL = ARGV[1] || "claude-opus-4-8"
DIR   = File.join(__dir__, 'reports', TAG)

# ---- rebuild summary matrix + rankings from the battle files ----
files = Dir[File.join(DIR, '*_vs_*.txt')].sort
results = files.map do |f|
  a, b = File.basename(f, '.txt').split('_vs_')
  [a, b, (File.read(f)[/WINNER:\s*(\S+)/, 1] rescue nil)]
end.reject { |_, _, w| w.nil? }
names = results.flat_map { |a, b, _| [a, b] }.uniq.sort
wins = Hash.new(0); games = Hash.new(0)
results.each { |a, b, w| games[a] += 1; games[b] += 1; wins[w] += 1 if [a, b].include?(w) }
matrix  = results.map { |a, b, w| "#{a} vs #{b}: #{w}" }.join("\n")
ranking = names.sort_by { |n| -(wins[n].to_f / [games[n], 1].max) }
                .map { |n| "#{n.ljust(9)} #{(100.0 * wins[n] / [games[n], 1].max).round}%  (#{wins[n]}/#{games[n]})" }.join("\n")

# ---- rosters (identity) so the coach tailors fixes per team ----
field = Roster.field(DIR)
mon = ->(m) do
  name = m[:head] && m[:body] ? "#{m[:head]}/#{m[:body]}" : (m[:species] || m[:head]).to_s
  "#{name} @#{m[:item] || '-'} [#{m[:ability] || '-'}/#{m[:nature] || '-'}] {#{(m[:moves] || []).join(', ')}}"
end
rosters = field.map { |name, team| "#{name} (plan: #{Roster.plan(name)})\n" + team.map { |m| "  - #{mon.(m)}" }.join("\n") }.join("\n\n")

# ---- truncated logs (decisive turns only) ----
logs = files.map do |f|
  c = File.read(f)
  "=== #{File.basename(f, '.txt')} ===\n#{c.length > 1600 ? "...\n#{c[-1600..-1]}" : c}"
end.join("\n\n")

label = MODEL.split('-')[1] || MODEL         # opus / sonnet / haiku
out = File.join(DIR, "recommendations_#{label}.txt")
puts "coach analyzing #{TAG} with #{MODEL} (identity-aware, diverse fixes)..."
rec = SimCoach.recommend(matrix + "\n\n" + ranking, logs, rosters: rosters, model: MODEL)
File.write(out, rec)
File.write(File.join(DIR, 'recommendations.txt'), rec)   # canonical file the evolver reads
puts "wrote #{out} + recommendations.txt  (#{rec.length} chars)"
