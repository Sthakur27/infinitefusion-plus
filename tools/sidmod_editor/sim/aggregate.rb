# Aggregate a tag's battle files -> summary.txt + coach recommendations.txt.
# No engine boot (just reads files + one coach API call).  ruby aggregate.rb <tag>
require_relative 'coach'
TAG = ARGV[0] or abort "usage: aggregate.rb <tag>"
DIR = File.join(__dir__, 'reports', TAG)

files = Dir[File.join(DIR, '*_vs_*.txt')].sort
results = files.map do |f|
  a, b = File.basename(f, '.txt').split('_vs_')
  w = (File.read(f)[/WINNER:\s*(\S+)/, 1] rescue nil)
  [a, b, w]
end.reject { |_, _, w| w.nil? }

names = results.flat_map { |a, b, _| [a, b] }.uniq.sort
wins = Hash.new(0); games = Hash.new(0)
results.each { |a, b, w| games[a] += 1; games[b] += 1; wins[w] += 1 if [a, b].include?(w) }
matrix  = results.map { |a, b, w| "#{a} vs #{b}: #{w}" }.join("\n")
ranking = names.sort_by { |n| -(wins[n].to_f / [games[n], 1].max) }
                .map { |n| "#{n.ljust(9)} #{(100.0 * wins[n] / [games[n], 1].max).round}%  (#{wins[n]}/#{games[n]})" }.join("\n")
summary = "RESULTS\n#{matrix}\n\nWIN RATES\n#{ranking}\n\n#{results.length} battles"
File.write(File.join(DIR, 'summary.txt'), summary)
puts summary
puts "\nwrote summary.txt. Run: ruby coach_run.rb #{TAG} claude-opus-4-8  (roster-aware Opus recommendations)"
