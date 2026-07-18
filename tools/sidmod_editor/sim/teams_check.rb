require_relative 'teams'
SimEngine.boot
$DEBUG = false
SimTeams.load.each do |name, t|
  puts "#{name.ljust(9)} (#{t.length}): #{t.map(&:speciesName).join(', ')}"
end
