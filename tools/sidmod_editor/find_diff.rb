# Characterize the byte difference between original and a stub round-trip.
require 'json'

SRC = ARGV[0]

def ensure_class(name)
  obj = Object
  name.split("::").each do |p|
    obj = obj.const_defined?(p, false) ? obj.const_get(p) : obj.const_set(p, Class.new)
  end
  obj
end
def add_userdef(k); c=ensure_class(k); c.define_singleton_method(:_load){|s| o=allocate;o.instance_variable_set(:@__raw,s);o}; c.send(:define_method,:_dump){|_d| instance_variable_get(:@__raw)}; end
def add_usermarshal(k); c=ensure_class(k); c.send(:define_method,:marshal_load){|d| instance_variable_set(:@__m,d)}; c.send(:define_method,:marshal_dump){ instance_variable_get(:@__m)}; end

data = File.binread(SRC)
loop do
  begin
    $obj = Marshal.load(data); break
  rescue ArgumentError, TypeError => e
    m = e.message
    if m =~ /undefined class\/module (.+?)\s*\z/ then ensure_class($1)
    elsif m =~ /_load'/ then add_userdef(m[/class (\S+)/,1] || m[/(\S+) needs/,1])
    elsif m =~ /marshal_load/ then add_usermarshal(m[/(\S+) needs/,1])
    else raise end
  end
end

redump = Marshal.dump($obj)
puts "orig=#{data.bytesize} redump=#{redump.bytesize}"

# count diffs + first few diff offsets
n = [data.bytesize, redump.bytesize].min
diffs = []
i = 0
while i < n
  if data.getbyte(i) != redump.getbyte(i)
    diffs << i
    break if diffs.length >= 5
  end
  i += 1
end
puts "total_len_equal=#{data.bytesize == redump.bytesize}"
puts "first_diff_offsets=#{diffs.inspect}"
diffs.each do |off|
  lo = [off-24,0].max; hi = off+24
  a = data.byteslice(lo..hi).bytes.map{|b| "%02X"%b}.join(" ")
  b = redump.byteslice(lo..hi).bytes.map{|b| "%02X"%b}.join(" ")
  ac = data.byteslice(lo..hi).bytes.map{|b| (b>=32&&b<127) ? b.chr : "."}.join
  bc = redump.byteslice(lo..hi).bytes.map{|b| (b>=32&&b<127) ? b.chr : "."}.join
  puts "--- offset #{off} ---"
  puts "orig  : #{a}  |#{ac}|"
  puts "redump: #{b}  |#{bc}|"
end

# Deep semantic check on the two subtrees we will edit
def summarize(o)
  { party: (o[:player].instance_variable_get(:@party) rescue nil)&.length,
    boxes: (o[:storage_system].instance_variable_get(:@boxes) rescue nil)&.length }
end
o2 = Marshal.load(redump)
puts "orig summary  : #{summarize($obj)}"
puts "reload summary: #{summarize(o2)}"
