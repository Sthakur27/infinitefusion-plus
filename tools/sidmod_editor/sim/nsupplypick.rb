require_relative 'nstore'
require_relative 'nbattle'
NativeSim.boot!
rat = File.readlines(File.join(NStore.dir('ou3'), 'ratings.csv'))[1..].each_with_object({}) { |l, h|
  f = l.chomp.split(','); h[f[0]] = { coef: f[13].to_f, kos: f[10].to_f, games: f[8].to_i } }
REMOVAL = %i[RAPIDSPIN DEFOG]; HAZARD = %i[STEALTHROCK SPIKES TOXICSPIKES]
RECOVER = %i[RECOVER ROOST SOFTBOILED SLACKOFF SYNTHESIS MOONLIGHT MORNINGSUN REST SHOREUP STRENGTHSAP WISH]
def movepool(bases)
  s = []
  bases.each { |b|
    sp = (GameData::Species.get(b.to_s.to_sym) rescue nil) or next
    (sp.moves rescue []).each { |m| s << (m.is_a?(Array) ? m[1] : m) }
    (sp.tutor_moves rescue []).each { |m| s << m }
    (sp.egg_moves rescue []).each { |m| s << m } }
  s.compact.map { |m| m.to_s.to_sym }.uniq
end
puts "DEFENSIVE mons (bulk>=900) that could add removal, WITH recovery, ranked by rating:"
puts "%-13s %-24s %-13s %-5s %-6s %-7s %s" % %w[name species types bulk coef Box/slot set]
NativeSim.pool(tier: :ou).each do |e|
  d = NativeSim.describe(e[:key]); s = d[:stats]
  bulk = s[0] + s[2] + s[4]
  next if bulk < 900
  cur = e[:moves].map { |m| m.to_s.to_sym }
  next if (cur & REMOVAL).any?
  mp = movepool(e[:bases])
  next if ((mp & REMOVAL) - cur).empty?
  next if (cur & RECOVER).empty?
  c = (rat[e[:key]] || {})[:coef].to_f
  next if c < -0.35
  puts "%-13s %-24s %-13s %-5d %+.3f B%-2d/s%-3d %s  [could add: %s]" % [
    d[:name], d[:species][0,24], d[:types], bulk, c, d[:box], d[:slot],
    d[:moves].join('/'), ((mp & REMOVAL) - cur).map { |m| GameData::Move.get(m).name rescue m }.join(',')]
end
