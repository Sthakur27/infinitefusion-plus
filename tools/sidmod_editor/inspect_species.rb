require_relative 'stub_loader'
require 'json'
data = StubLoader.load_file(ARGV[0])
puts "top class: #{data.class}"
if data.is_a?(Hash)
  puts "size: #{data.size}"
  sample_keys = data.keys.first(5)
  puts "sample keys: #{sample_keys.inspect}"
  rec = data[data.keys.first]
  puts "record class: #{rec.class}"
  puts "record ivars: #{rec.instance_variables.sort.inspect}"
  rec.instance_variables.sort.each do |iv|
    v = rec.instance_variable_get(iv)
    disp = v.is_a?(Hash) || v.is_a?(Array) ? "#{v.class}(#{v.size}) #{v.inspect[0,120]}" : v.inspect[0,120]
    puts "   #{iv} = #{disp}"
  end
elsif data.is_a?(Array)
  puts "size: #{data.size}; first class: #{data[0].class}"
  puts "first ivars: #{data[0].instance_variables.sort.inspect}" if data[0]
end
