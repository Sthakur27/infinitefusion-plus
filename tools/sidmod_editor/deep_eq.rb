# Deep structural equality between original-loaded and redump-reloaded graphs.
# Proves the stub round-trip preserves ALL data even though byte layout differs
# (symbol def vs symlink). Handles cycles via a visited-pair set.
require 'set'
SRC = ARGV[0]

def ensure_class(name)
  obj = Object
  name.split("::").each { |p| obj = obj.const_defined?(p, false) ? obj.const_get(p) : obj.const_set(p, Class.new) }
  obj
end
def add_userdef(k); c=ensure_class(k); c.define_singleton_method(:_load){|s| o=allocate;o.instance_variable_set(:@__raw,s);o}; c.send(:define_method,:_dump){|_d| instance_variable_get(:@__raw)}; end
def add_usermarshal(k); c=ensure_class(k); c.send(:define_method,:marshal_load){|d| instance_variable_set(:@__m,d)}; c.send(:define_method,:marshal_dump){ instance_variable_get(:@__m)}; end

def load_with_stubs(data)
  loop do
    begin
      return Marshal.load(data)
    rescue ArgumentError, TypeError => e
      m = e.message
      if m =~ /undefined class\/module (.+?)\s*\z/ then ensure_class($1)
      elsif m =~ /_load'/ then add_userdef(m[/class (\S+)/,1] || m[/(\S+) needs/,1])
      elsif m =~ /marshal_load/ then add_usermarshal(m[/(\S+) needs/,1])
      else raise end
    end
  end
end

$diffs = []
$seen = {}
def deep_eq(a, b, path)
  return true if $diffs.length > 20
  if a.class != b.class
    $diffs << "#{path}: class #{a.class} != #{b.class}"; return false
  end
  case a
  when Symbol, Integer, Float, TrueClass, FalseClass, NilClass
    ($diffs << "#{path}: #{a.inspect} != #{b.inspect}"; return false) unless a == b
    return true
  when String
    ($diffs << "#{path}: str #{a.inspect} != #{b.inspect}") unless a == b && a.encoding == b.encoding
    return a == a
  end
  key = a.object_id
  return true if $seen[key] == b.object_id   # cycle / already compared
  $seen[key] = b.object_id
  case a
  when Array
    ($diffs << "#{path}: array len #{a.length} != #{b.length}"; return false) if a.length != b.length
    a.each_index { |i| deep_eq(a[i], b[i], "#{path}[#{i}]") }
  when Hash
    ($diffs << "#{path}: hash size #{a.size} != #{b.size}"; return false) if a.size != b.size
    a.each { |k, v| deep_eq(v, b[k], "#{path}{#{k.inspect}}") }
  else
    av = a.instance_variables.sort; bv = b.instance_variables.sort
    ($diffs << "#{path}: ivars #{av} != #{bv}") if av != bv
    av.each { |iv| deep_eq(a.instance_variable_get(iv), b.instance_variable_get(iv), "#{path}.#{iv}") }
  end
  true
end

data = File.binread(SRC)
orig = load_with_stubs(data)
redump = Marshal.dump(orig)
reloaded = load_with_stubs(redump)

deep_eq(orig, reloaded, "root")
puts "redump stable (dump==dump2): #{redump == Marshal.dump(reloaded)}"
if $diffs.empty?
  puts "DEEP EQUAL: PASS — every value/ivar identical across the round-trip."
else
  puts "DEEP DIFFERENCES (#{$diffs.length} shown):"
  $diffs.each { |d| puts "  #{d}" }
end
