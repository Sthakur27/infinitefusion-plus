# Measure the 10 CONSTRUCTED utility mons before writing them to the save: build each
# in memory, drop it into the weakest slot of strong ladder teams, and compare winrate
# against the ladder field. If they do not earn their slot, do not write them.
require_relative 'nstore'
require_relative 'nbattle'
require_relative 'build_team'
require_relative 'editor'
ENV['NSIM_SAVE'] = File.join(NStore.dir('ladder_ou3'), 'save_snapshot.rxdata')
NativeSim.boot!
st  = NStore::PARSE.call(File.binread(File.join(NStore.dir('ladder_ou3'), 'ladder.json')))
rat = File.readlines(File.join(NStore.dir('ou3'), 'ratings.csv'))[1..].each_with_object({}) { |l,h|
  f = l.chomp.split(','); h[f[0]] = f[13].to_f }
adds = NStore::PARSE.call(File.binread(File.join(NStore.dir('ou3'), 'utility_adds_spec.json')))['pokemon']

teams = st['teams'].sort_by { |t| -t['elo'] }
# hosts: 3 strong teams of different niches; field: 10 spread across the ladder
hosts = ['hyperoffense','priority','rain'].map { |n| teams.find { |t| t['niche'] == n } }.compact
field = teams.each_slice([teams.length/10,1].max).map(&:first).first(10)
SEEDS = (1..8).to_a

built = adds.map { |a|
  spec = { head: a['head'].to_sym, body: a['body'].to_sym, ability: a['ability'].to_sym,
           item: a['item'].to_sym, nature: a['nature'].to_sym,
           moves: a['moves'].map(&:to_sym), evs: a['evs'].transform_keys(&:to_sym) }
  [a['nickname'], BuildTeam.mon(spec)] }

def score(pa, field, seeds)
  pts = 0.0; n = 0
  field.each do |f|
    fb = NativeSim.party(f['keys'])
    seeds.each do |s|
      w1 = NativeSim.run_mons(pa, fb, seed: s); pts += (w1 == :a ? 1 : (w1 == :b ? 0 : 0.5)); n += 1
      w2 = NativeSim.run_mons(fb, pa, seed: s); pts += (w2 == :b ? 1 : (w2 == :a ? 0 : 0.5)); n += 1
    end
  end
  [pts / n, n]
end

puts "%-11s %-14s %-8s %-8s %s" % %w[mon host base with delta]
totals = Hash.new(0.0)
hosts.each do |h|
  keys = h['keys']
  weak = (0...6).min_by { |i| rat[keys[i]].to_f }
  base_party = NativeSim.party(keys)
  bwr, = score(base_party, field, SEEDS)
  built.each do |nick, pk|
    party = NativeSim.party(keys)
    party[weak] = pk
    wr, n = score(party, field, SEEDS)
    totals[nick] += (wr - bwr)
    puts "%-11s %-14s %.3f    %.3f    %+.3f  (n=%d, replaced slot %d)" % [nick, h['niche'], bwr, wr, wr - bwr, n, weak+1]
  end
end
puts "\nMEAN DELTA ACROSS #{hosts.length} HOSTS (positive = earns its slot):"
totals.sort_by { |_k,v| -v }.each { |k,v| puts "  %-11s %+.3f" % [k, v / hosts.length] }
