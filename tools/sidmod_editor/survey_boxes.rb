require_relative 'stub_loader'
require 'json'
SAVE = ARGV[0]
TABLE = JSON.parse(File.read(File.join(__dir__, 'species_table.json')))
def ivg(o,n) o.instance_variable_get(n) end
def sname(pk)
  s = ivg(pk, :@species)
  if s.is_a?(Symbol) && s.to_s =~ /\AB(\d+)H(\d+)\z/
    "#{TABLE[$2]&.dig('name')}/#{TABLE[$1]&.dig('name')}"
  else
    (TABLE.values.find { |r| r['id'].to_s == s.to_s } || {})['name'] || s.to_s
  end
end
save = StubLoader.load_file(SAVE)
boxes = ivg(save[:storage_system], :@boxes)
puts "TOTAL BOXES: #{boxes.length}"
boxes.each_with_index do |bx, i|
  next unless bx
  mons = (ivg(bx, :@pokemon) || []).compact
  name = ivg(bx, :@name)
  # sample of distinct nicknames + species
  nicks = (ivg(bx, :@pokemon) || []).compact.map { |pk| ivg(pk, :@name) }.compact.uniq
  sp = mons.first(4).map { |pk| sname(pk) }
  tag = nicks.empty? ? "" : "  nicks={#{nicks.first(4).join(',')}}"
  puts sprintf("idx %2d  \"%-14s\"  %2d/30  %s%s", i, name.to_s, mons.length, sp.join(', '), tag)
end
