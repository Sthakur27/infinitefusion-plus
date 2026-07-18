require_relative 'spec_extract'
SimEngine.boot
$DEBUG = false
SpecExtract.all.each do |name, spec|
  begin
    rebuilt = BuildTeam.team(spec)
    puts "#{name.ljust(9)} (#{rebuilt.length}): #{rebuilt.map(&:speciesName).join(', ')}"
  rescue => e
    puts "#{name.ljust(9)} BUILD FAIL: #{e.class}: #{e.message[0,70]}"
  end
end
