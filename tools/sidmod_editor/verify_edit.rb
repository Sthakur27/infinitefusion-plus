# Confirms OUT == IN except for newly-added mons, and shows the new mons in full.
# Uses DEEP STRUCTURAL EQUALITY (by value), not byte-compare: re-dumping a graph
# can reorder Marshal object/symbol links without changing the data, so a byte diff
# is a false positive. Deep-equality is the correct collateral gate.
#   ruby verify_edit.rb <in> <out> [species_table.json]
require_relative 'stub_loader'
require 'json'
require 'set'
IN, OUT = ARGV[0], ARGV[1]
TABLE = JSON.parse(File.read(File.join(__dir__, 'species_table.json')))
# Optional spec (ARGV[2]): slots that replace/edit is ALLOWED to change.
ALLOWED = Set.new
ALLOWED_BOX = Set.new   # boxes whose @name a rename_box entry may change
if ARGV[2] && File.exist?(ARGV[2])
  sp = JSON.parse(File.read(ARGV[2])) rescue {}
  (sp['pokemon'] || []).each do |e|
    if e['mode'] == 'move'
      ALLOWED << "#{e['from_box'].to_i}:#{e['from_slot'].to_i}"   # source becomes nil
      ALLOWED << "#{e['box'].to_i}:#{e['slot'].to_i}"             # dest gains the mon
    elsif e['mode'] == 'rename_box'
      ALLOWED_BOX << e['box'].to_i                                # intended box-name change
    elsif %w[replace edit delete].include?(e['mode'])
      ALLOWED << "#{e['box'].to_i}:#{e['slot'].to_i}"
    end
  end
end
def ivg(o,n) o.instance_variable_get(n) end

a = StubLoader.load_file(IN)
b = StubLoader.load_file(OUT)
problems = []

# deep value-equality with cycle guard
def deep_eq?(x, y, seen = {})
  return true if x.equal?(y)
  return false if x.class != y.class
  case x
  when Symbol, Integer, Float, TrueClass, FalseClass, NilClass
    return x == y
  when String
    return x == y && x.encoding == y.encoding
  end
  k = x.object_id
  return true if seen[k]      # assume equal if already comparing (cycle)
  seen[k] = true
  case x
  when Array
    return false if x.length != y.length
    x.each_index { |i| return false unless deep_eq?(x[i], y[i], seen) }
    true
  when Hash
    return false if x.size != y.size
    x.each { |kk, vv| return false unless y.key?(kk) && deep_eq?(vv, y[kk], seen) }
    true
  else
    xv = x.instance_variables.sort; yv = y.instance_variables.sort
    return false if xv != yv
    xv.all? { |iv| deep_eq?(x.instance_variable_get(iv), y.instance_variable_get(iv), seen) }
  end
end

# 1) every top-level key except storage must be deep-equal
(a.keys | b.keys).each do |k|
  next if k == :storage_system
  problems << "top-level key #{k.inspect} changed" unless deep_eq?(a[k], b[k])
end

# 2) storage: box-by-box, slot-by-slot. differences allowed only where IN slot was nil.
abx = ivg(a[:storage_system], :@boxes); bbx = ivg(b[:storage_system], :@boxes)
problems << "box count changed" if abx.length != bbx.length
added = []
abx.each_index do |bi|
  as = ivg(abx[bi], :@pokemon); bs = ivg(bbx[bi], :@pokemon)
  problems << "box #{bi+1} name changed" unless deep_eq?(ivg(abx[bi], :@name), ivg(bbx[bi], :@name)) || ALLOWED_BOX.include?(bi)
  as.each_index do |si|
    am, bm = as[si], bs[si]
    next if am.nil? && bm.nil?
    if am.nil? && bm
      added << [bi, si, bm]
    elsif am && bm.nil?
      problems << "box #{bi+1} slot #{si+1}: existing mon DELETED" unless ALLOWED.include?("#{bi}:#{si}")
    elsif !deep_eq?(am, bm)
      if ALLOWED.include?("#{bi}:#{si}")
        added << [bi, si, bm]   # intentional replace/edit — report as a change, not a problem
      else
        problems << "box #{bi+1} slot #{si+1}: existing mon MODIFIED"
      end
    end
  end
end

def species_name(pk, table)
  s = ivg(pk, :@species)
  if s.is_a?(Symbol) && s.to_s =~ /\AB(\d+)H(\d+)\z/
    "#{table[$2]&.dig('name')}/#{table[$1]&.dig('name')}"
  else
    (table.values.find { |r| r['id'] == s.to_s } || {})['name'] || s.to_s
  end
end

puts "collateral problems: #{problems.empty? ? 'NONE' : problems.length}"
problems.each { |p| puts "  !! #{p}" }
puts "\nADDED MONS (#{added.length}):"
added.each do |bi, si, pk|
  puts "  Box #{bi+1} slot #{si+1}: #{species_name(pk, TABLE)}  " \
       "#{ivg(pk,:@name) ? "\"#{ivg(pk,:@name)}\" " : ''}L#{ivg(pk,:@level)} " \
       "#{ivg(pk,:@shiny) ? '*shiny* ' : ''}#{ivg(pk,:@nature)} #{ivg(pk,:@ability)} @#{ivg(pk,:@item)}"
  puts "     gender=#{ivg(pk,:@gender)} ball=#{ivg(pk,:@poke_ball)} exp=#{ivg(pk,:@exp)} pid=#{ivg(pk,:@personalID)}"
  puts "     HP=#{ivg(pk,:@totalhp)} Atk=#{ivg(pk,:@attack)} Def=#{ivg(pk,:@defense)} SpA=#{ivg(pk,:@spatk)} SpD=#{ivg(pk,:@spdef)} Spe=#{ivg(pk,:@speed)}"
  puts "     EV=#{ivg(pk,:@ev)}"
  puts "     moves=#{(ivg(pk,:@moves)||[]).map{|m| "#{ivg(m,:@id)}(#{ivg(m,:@pp)})"}.join(', ')}"
  puts "     owner=#{ivg(ivg(pk,:@owner),:@name)} id=#{ivg(ivg(pk,:@owner),:@id)}"
end
