# Deep-diff one top-level save key between two saves. Prints the paths that differ.
#   ruby diff_key.rb <a.rxdata> <b.rxdata> <key>
require_relative 'stub_loader'
KEY = ARGV[2].to_sym
a = StubLoader.load_file(ARGV[0])[KEY]
b = StubLoader.load_file(ARGV[1])[KEY]

$diffs = []
$seen = {}
def de(a, b, path)
  return if $diffs.length > 40
  if a.class != b.class
    $diffs << "#{path}: CLASS #{a.class} != #{b.class}"; return
  end
  case a
  when Symbol, Integer, Float, TrueClass, FalseClass, NilClass, String
    $diffs << "#{path}: #{a.inspect} != #{b.inspect}" unless a == b
    return
  end
  k = a.object_id
  return if $seen[k]; $seen[k] = true
  case a
  when Array
    ($diffs << "#{path}: LEN #{a.length} != #{b.length}") if a.length != b.length
    [a.length, b.length].min.times { |i| de(a[i], b[i], "#{path}[#{i}]") }
  when Hash
    (a.keys | b.keys).each { |kk| de(a[kk], b[kk], "#{path}{#{kk.inspect}}") }
  else
    (a.instance_variables | b.instance_variables).each do |iv|
      de(a.instance_variable_get(iv), b.instance_variable_get(iv), "#{path}.#{iv}")
    end
  end
end
de(a, b, KEY.to_s)
if $diffs.empty?
  puts "#{KEY}: DEEP EQUAL (verify's byte-diff was a Marshal-linking artifact)"
else
  puts "#{KEY}: #{$diffs.length} difference(s):"
  $diffs.each { |d| puts "  #{d}" }
end
