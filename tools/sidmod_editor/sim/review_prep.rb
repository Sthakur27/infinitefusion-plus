# Print each team's roster + its W/L/D record (with battle filenames) for a tag.
#   ruby review_prep.rb <tag>
require_relative 'build_team'
require_relative 'roster'
SimEngine.boot
$DEBUG = false
TAG = ARGV[0] || 'round3'
DIR = File.join(__dir__, 'reports', TAG)

field = Roster.field(DIR)
mon = ->(m) do
  nm = m[:head] && m[:body] ? "#{m[:head]}/#{m[:body]}" : (m[:species] || m[:head]).to_s
  "#{nm} @#{m[:item] || '-'} [#{m[:ability]}] {#{(m[:moves] || []).join('/')}}"
end

# results
res = {}
Dir[File.join(DIR, '*_vs_*.txt')].sort.each do |f|
  a, b = File.basename(f, '.txt').split('_vs_')
  w = File.read(f)[/WINNER:\s*(\S+)/, 1]
  res[[a, b]] = [w, File.basename(f)]
end

field.keys.sort.each do |name|
  puts "\n========== #{name} =========="
  field[name].each { |m| puts "  #{mon.(m)}" }
  wins = []; losses = []; draws = []
  res.each do |(a, b), (w, file)|
    next unless [a, b].include?(name)
    opp = a == name ? b : a
    if w == name then wins << [opp, file]
    elsif w == 'draw' then draws << [opp, file]
    else losses << [opp, file] end
  end
  puts "  RECORD: #{wins.length}W-#{losses.length}L-#{draws.length}D"
  puts "  WINS:   " + wins.map { |o, f| "#{o}(#{f})" }.join(', ')
  puts "  LOSSES: " + losses.map { |o, f| "#{o}(#{f})" }.join(', ')
  puts "  DRAWS:  " + draws.map { |o, f| "#{o}(#{f})" }.join(', ') unless draws.empty?
end
