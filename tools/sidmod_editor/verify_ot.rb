# Collateral gate for set_all_ot.rb: confirms OUT == IN everywhere EXCEPT that every
# mon's @owner now equals the player's identity, and NOTHING else on any mon changed.
#   ruby verify_ot.rb <in> <out>
require_relative 'stub_loader'
require 'set'
IN, OUT = ARGV[0], ARGV[1]
def ivg(o, n) o.instance_variable_get(n) end

a = StubLoader.load_file(IN)
b = StubLoader.load_file(OUT)
problems = []

def deep_eq?(x, y, seen = {})
  return true if x.equal?(y)
  return false if x.class != y.class
  case x
  when Symbol, Integer, Float, TrueClass, FalseClass, NilClass then return x == y
  when String then return x == y && x.encoding == y.encoding
  end
  k = x.object_id
  return true if seen[k]
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

# mon equal on EVERY ivar except @owner
def mon_eq_except_owner?(x, y)
  xv = x.instance_variables.sort - [:@owner]
  yv = y.instance_variables.sort - [:@owner]
  return false if xv != yv
  xv.all? { |iv| deep_eq?(x.instance_variable_get(iv), y.instance_variable_get(iv)) }
end

pl = b[:player]
PID = ivg(pl, :@id); PNAME = ivg(pl, :@name); PLANG = ivg(pl, :@language) || 2
# expected gender = whatever OUT actually wrote (mode of player-owned) - read it back from any mon
genders = []
def owner_of(pk) pk.instance_variable_get(:@owner) end

def each_mon(save)
  (ivg(save[:player], :@party) || []).each { |pk| yield pk if pk }
  (ivg(save[:storage_system], :@boxes) || []).each { |bx| next unless bx; (ivg(bx, :@pokemon) || []).each { |pk| yield pk if pk } }
end
each_mon(b) { |pk| o = owner_of(pk); genders << ivg(o, :@gender) if o }
PGENDER = genders.empty? ? nil : genders.group_by { |g| g }.max_by { |_k, v| v.length }[0]

# 1) top-level keys except player + storage must be identical
(a.keys | b.keys).each do |kk|
  next if kk == :player || kk == :storage_system
  problems << "top-level key #{kk.inspect} changed" unless deep_eq?(a[kk], b[kk])
end

# 2) player ivars except @party must be identical
(a[:player].instance_variables | b[:player].instance_variables).uniq.each do |iv|
  next if iv == :@party
  problems << "player #{iv} changed" unless deep_eq?(a[:player].instance_variable_get(iv), b[:player].instance_variable_get(iv))
end

owners_set = 0; owners_wrong = 0; mons_body_changed = 0; total = 0
check = lambda do |am, bm, where|
  if am.nil? && bm.nil?
    return
  elsif am.nil? || bm.nil?
    problems << "#{where}: slot presence changed"; return
  end
  total += 1
  mons_body_changed += 1 unless mon_eq_except_owner?(am, bm)
  o = owner_of(bm)
  if o && ivg(o, :@id) == PID && ivg(o, :@name) == PNAME && ivg(o, :@gender) == PGENDER && ivg(o, :@language) == PLANG
    owners_set += 1
  else
    owners_wrong += 1
  end
end

# 3) party lockstep
ap = ivg(a[:player], :@party) || []; bp = ivg(b[:player], :@party) || []
problems << 'party length changed' if ap.length != bp.length
[ap.length, bp.length].min.times { |i| check.call(ap[i], bp[i], "party slot #{i + 1}") }

# 4) boxes lockstep
abx = ivg(a[:storage_system], :@boxes); bbx = ivg(b[:storage_system], :@boxes)
problems << 'box count changed' if abx.length != bbx.length
abx.each_index do |bi|
  problems << "box #{bi + 1} name changed" unless deep_eq?(ivg(abx[bi], :@name), ivg(bbx[bi], :@name))
  as = ivg(abx[bi], :@pokemon) || []; bs = ivg(bbx[bi], :@pokemon) || []
  problems << "box #{bi + 1} slot count changed" if as.length != bs.length
  [as.length, bs.length].min.times { |si| check.call(as[si], bs[si], "box #{bi + 1} slot #{si + 1}") }
end

problems << "#{mons_body_changed} mon(s) had NON-owner fields change" if mons_body_changed > 0
problems << "#{owners_wrong} mon(s) do NOT have the player's OT" if owners_wrong > 0

puts "player OT: id=#{PID} name=#{PNAME.inspect} gender=#{PGENDER} language=#{PLANG}"
puts "mons checked: #{total}   owner set correctly: #{owners_set}   non-owner changes: #{mons_body_changed}"
puts "collateral problems: #{problems.empty? ? 'NONE' : problems.length}"
problems.each { |p| puts "  !! #{p}" }
