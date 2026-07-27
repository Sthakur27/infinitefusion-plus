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
rng = Random.new(5)
puts "=== does each archetype BUILDER produce the niche it intends? ==="
Gen::ARCHETYPES.each do |a|
  got = []
  6.times { t = gen.archetype(a, rng); got << (t ? Niche.classify(t, meta) : 'nil') }
  puts "  %-14s -> %s" % [a, got.tally.map { |k, v| "#{k}x#{v}" }.join(' ')]
end
puts "\n=== core-slot protection (what mutation may not touch) ==="
%w[rain sand trickroom hazardstack].each do |a|
  t = gen.archetype(a, rng)
  next if !t
  n = Niche.classify(t, meta)
  core = Niche.core(t, meta)
  puts "  %-12s niche=%-12s core slots %s = %s" % [a, n, core.inspect, core.map { |i| meta[t[i]][:name] }.join('+')]
  m = gen.mutate_protecting(t, core, rng)
  puts "    after protected mutation -> niche=#{m ? Niche.classify(m, meta) : 'nil'} (must stay #{n})"
end
puts "\n=== the OLD monoculture ladder, classified ==="
st = NStore::PARSE.call(File.binread(File.join(NStore.dir('ladder_ou'), 'ladder.json')))
puts "  " + st['teams'].map { |t| Niche.classify(t['keys'], meta) }.tally.sort_by { |_k, v| -v }.map { |k, v| "#{k} #{v}" }.join(', ')
