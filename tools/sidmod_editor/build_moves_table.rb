# Data/moves.dat -> moves_table.json (move symbol -> {pp,name,type,category}).
require_relative 'stub_loader'
require 'json'
MOVES = ARGV[0] || File.join(__dir__, '..', '..', 'Data', 'moves.dat')
OUT   = ARGV[1] || File.join(__dir__, 'moves_table.json')
d = StubLoader.load_file(MOVES)
t = {}
d.each do |k, r|
  next unless k.is_a?(Symbol)
  t[k.to_s] = {
    "pp"       => r.instance_variable_get(:@total_pp),
    "name"     => r.instance_variable_get(:@real_name),
    "type"     => r.instance_variable_get(:@type).to_s,
    "category" => r.instance_variable_get(:@category).to_s,
  }
end
File.write(OUT, JSON.generate(t))
warn "wrote #{t.size} moves; sample EARTHQUAKE pp=#{t['EARTHQUAKE']&.dig('pp')} TOXIC pp=#{t['TOXIC']&.dig('pp')}"
