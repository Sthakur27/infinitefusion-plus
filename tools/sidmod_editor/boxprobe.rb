require_relative 'stub_loader'
def ivg(o, n) o.instance_variable_get(n) end
save = StubLoader.load_file(ARGV[0])
boxes = ivg(save[:storage_system], :@boxes)
[23, 24].each do |i|
  b = boxes[i]
  pk = ivg(b, :@pokemon)
  puts "index #{i} name=#{ivg(b, :@name).inspect} pokemon.class=#{pk.class} length=#{pk.respond_to?(:length) ? pk.length : 'n/a'} nils=#{pk.respond_to?(:count) ? pk.count(&:nil?) : '?'}"
end
puts "box[23] ivars: #{boxes[23].instance_variables.inspect}"
# a FULL box for reference
full = boxes.each_index.find { |i| (ivg(boxes[i], :@pokemon) || []).compact.length == 30 }
puts "a full box index #{full}: pokemon.length=#{ivg(boxes[full], :@pokemon).length}" if full
