# Shared stub-class Marshal loader (proven byte-faithful via deep_eq.rb).
# Dynamically defines any class in the stream; captures userdef/usermarshal
# objects (RGSS Color/Tone/Table) raw so they re-dump verbatim.
module StubLoader
  module_function

  def ensure_class(name)
    obj = Object
    name.split("::").each do |p|
      obj = obj.const_defined?(p, false) ? obj.const_get(p) : obj.const_set(p, Class.new)
    end
    obj
  end

  def add_userdef(k)
    c = ensure_class(k)
    c.define_singleton_method(:_load) { |s| o = allocate; o.instance_variable_set(:@__raw, s); o }
    c.send(:define_method, :_dump) { |_d| instance_variable_get(:@__raw) }
  end

  def add_usermarshal(k)
    c = ensure_class(k)
    c.send(:define_method, :marshal_load) { |d| instance_variable_set(:@__m, d) }
    c.send(:define_method, :marshal_dump) { instance_variable_get(:@__m) }
  end

  def load_file(path)
    data = File.binread(path)
    loop do
      begin
        return Marshal.load(data)
      rescue ArgumentError, TypeError => e
        m = e.message
        if m =~ /undefined class\/module (.+?)\s*\z/ then ensure_class($1)
        elsif m =~ /_load'/ then add_userdef(m[/class (\S+)/, 1] || m[/(\S+) needs/, 1])
        elsif m =~ /marshal_load/ then add_usermarshal(m[/(\S+) needs/, 1])
        else raise
        end
      end
    end
  end
end
