# Auto-stubbing Marshal round-trip prover (Phase 1 go/no-go).
# Loads a save copy with dynamically-created stub classes, byte-compares a re-dump,
# and reloads it. Userdef ('u') / usermarshal ('U') objects (RGSS Table/Color/etc.)
# are captured raw and re-emitted verbatim so the round-trip stays byte-faithful
# even for classes we don't understand.
require 'json'

SRC = ARGV[0]

def ensure_class(name)
  obj = Object
  name.split("::").each do |p|
    if obj.const_defined?(p, false)
      obj = obj.const_get(p)
    else
      c = Class.new
      obj.const_set(p, c)
      obj = c
    end
  end
  obj
end

def add_userdef(klass)
  c = ensure_class(klass)
  c.define_singleton_method(:_load) { |s| o = allocate; o.instance_variable_set(:@__raw, s); o }
  c.send(:define_method, :_dump) { |_d| instance_variable_get(:@__raw) }
end

def add_usermarshal(klass)
  c = ensure_class(klass)
  c.send(:define_method, :marshal_load) { |d| instance_variable_set(:@__m, d) }
  c.send(:define_method, :marshal_dump) { instance_variable_get(:@__m) }
end

data = File.binread(SRC)
stubbed = []
userdef = []
usermarshal = []

result = nil
loop do
  begin
    result = Marshal.load(data)
    break
  rescue ArgumentError, TypeError => e
    m = e.message
    if m =~ /undefined class\/module (.+?)\s*\z/
      name = $1
      ensure_class(name)
      stubbed << name unless stubbed.include?(name)
    elsif m =~ /class (\S+) needs to have (?:instance )?method `_load'/ || m =~ /needs to have method `_load'/
      k = (m[/class (\S+)/, 1] || m[/`?(\w[\w:]*)'? needs/, 1])
      userdef << k unless userdef.include?(k)
      add_userdef(k)
    elsif m =~ /(\S+) needs to have method `marshal_load'/ || m =~ /marshal_load/
      k = m[/(\S+) needs/, 1]
      usermarshal << k unless usermarshal.include?(k)
      add_usermarshal(k)
    else
      warn "UNHANDLED: #{e.class}: #{m}"
      raise
    end
  end
end

# Re-dump and compare
redump = Marshal.dump(result)
identical = (redump == data)

# Prove the re-dump reloads under the same stubs
reload_ok = false
begin
  Marshal.load(redump)
  reload_ok = true
rescue => e
  reload_ok = "RELOAD FAILED: #{e.class}: #{e.message}"
end

report = {
  "src_bytes"       => data.bytesize,
  "redump_bytes"    => redump.bytesize,
  "byte_identical"  => identical,
  "reload_ok"       => reload_ok,
  "stub_classes"    => stubbed.length,
  "userdef_classes" => userdef,
  "usermarshal_classes" => usermarshal,
  "top_level_keys"  => (result.is_a?(Hash) ? result.keys.map(&:to_s) : "NOT A HASH"),
  "player_class"    => (result[:player].class.name rescue nil),
  "storage_class"   => (result[:storage_system].class.name rescue nil),
}
puts JSON.pretty_generate(report)
# also dump the raw stub list for reuse
File.write(File.join(__dir__, "stub_classes.json"),
           JSON.pretty_generate({"stubbed" => stubbed.sort, "userdef" => userdef, "usermarshal" => usermarshal}))
