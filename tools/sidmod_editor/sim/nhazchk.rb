require_relative 'nstore'
require_relative 'nbattle'
require_relative 'nlead'
require_relative 'narchetype'
require_relative 'nniche'
ENV['NSIM_SAVE'] = File.join(NStore.dir('ou3'), 'save_snapshot.rxdata')
NativeSim.boot!
meta = NativeSim.all_pool.each_with_object({}) { |e, h|
  d = NativeSim.describe(e[:key])
  h[e[:key]] = { moves: d[:moves], ability: d[:ability], item: d[:item], types: d[:types],
                 stats: d[:stats], roles: d[:roles].split(','), bases: e[:bases].map(&:to_s), name: d[:name] } }
rat = File.readlines(File.join(NStore.dir('ou3'), 'ratings.csv'))[1..].each_with_object({}) { |l, h|
  f = l.chomp.split(','); h[f[0]] = { wr: f[9].to_f, kos: f[10].to_f, games: f[8].to_i, coef: f[13].to_f } }
pool = NativeSim.pool(tier: :ou).map { |e| e[:key] }
gen = Gen.new(meta, rat, pool)
sl = gen.shortlist
puts "shortlist size #{sl.length} / pool #{pool.length}"
puts "  hazard mons in shortlist: #{sl.count { |k| gen.hazard?(k) }}"
puts "  bulky+recovery:           #{sl.count { |k| gen.bulky?(k) && gen.recovery?(k) }}"
puts "  bulky+(rec|phaze|hazard): #{sl.count { |k| gen.bulky?(k) && (gen.recovery?(k) || gen.phaze?(k) || gen.hazard?(k)) }}"
t = gen.archetype('hazardstack', Random.new(3))
puts "\nhazardstack build: #{t.map { |k| meta[k][:name] }.join(', ')}"
puts "  hazard count in built team: #{t.count { |k| gen.hazard?(k) }}  -> niche #{Niche.classify(t, meta)}"
t.each { |k| puts "    %-12s hazard=%-5s moves=%s" % [meta[k][:name], gen.hazard?(k), meta[k][:moves].join('/')] }
b = gen.archetype('balance', Random.new(3))
puts "\nbalance build: #{b.map { |k| meta[k][:name] }.join(', ')} -> #{Niche.classify(b, meta)}"
b.each { |k| puts "    %-12s bulky=%-5s rec=%-5s phaze=%-5s haz=%s" % [meta[k][:name], gen.bulky?(k), gen.recovery?(k), gen.phaze?(k), gen.hazard?(k)] }
