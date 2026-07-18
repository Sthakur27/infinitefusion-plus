# List every PC box: index, name, and how many slots are filled.  READ-ONLY.
#   ruby box_occupancy.rb <save.rxdata>
require_relative 'stub_loader'
SAVE = ARGV[0] or abort "usage: box_occupancy.rb <save>"
def ivg(o, s) o.instance_variable_get(s) end
save  = StubLoader.load_file(SAVE)
boxes = ivg(save[:storage_system], :@boxes) || []
boxes.each_with_index do |b, i|
  next unless b
  name = ivg(b, :@name)
  mons = (ivg(b, :@pokemon) || []).compact
  filled = mons.length
  tag = filled == 0 ? "EMPTY" : "#{filled} mons"
  puts "box #{i.to_s.rjust(2)}  \"#{name}\"  #{tag}"
end
