# A/B item test: hold the #1 ladder team fixed, vary ONE mon's item, play the same
# frozen field both sides, compare win rate + performance Elo.
#   ruby ab_item_test.rb <ladder_tag> <mon_name> <item1,item2,...>
require_relative 'nstore'
require_relative 'nbattle'
require 'json'

TAG   = ARGV[0] || 'ladder_ou6'
MON   = ARGV[1] || 'Glimmerwing'
ITEMS = (ARGV[2] || 'LEFTOVERS,LIFEORB,HEAVYDUTYBOOTS').split(',')

ENV['NSIM_SAVE'] = File.join(__dir__, 'nreports', TAG, 'save_snapshot.rxdata')
NativeSim.boot!
$DEBUG = false

st = NStore::PARSE.call(File.binread(File.join(__dir__, 'nreports', TAG, 'ladder.json')))
teams = st['teams'].sort_by { |t| -t['elo'] }

# locate the mon's pool key + the top team that runs it
mon_key = NativeSim.all_pool.find { |e| e[:name] == MON }&.dig(:key)
abort "mon #{MON} not in pool" unless mon_key
top = teams.find { |t| t['keys'].include?(mon_key) }
abort "no team runs #{MON}" unless top
puts "Testing #{MON} (#{mon_key}) on team ##{teams.index(top)+1} (Elo #{top['elo'].round})"
puts "Team: #{top['keys'].map { |k| NativeSim.entry(k)[:name] }.join(', ')}"

# validate items exist
valid = ITEMS.select do |i|
  ok = (GameData::Item.get(i.to_sym) rescue nil)
  puts "  item #{i}: #{ok ? 'OK' : 'NOT FOUND — skipping'}"
  ok
end

# field = all other teams (exclude the exact team under test to avoid a self-mirror)
field = teams.reject { |t| t.equal?(top) }

def perf_elo(points, games, opp_elos)
  return 0 if games.zero?
  p = points / games.to_f
  p = 0.02 if p < 0.02
  p = 0.98 if p > 0.98
  mean_opp = opp_elos.sum / opp_elos.length.to_f
  mean_opp + 400 * Math.log10(p / (1 - p))
end

results = {}
valid.each do |item|
  base = NativeSim.party(top['keys'])
  # override the item on the target mon (match by the built party index == key index)
  idx = top['keys'].index(mon_key)
  base[idx].item = item.to_sym
  pts = 0.0; n = 0; opp_elos = []; crashes = 0
  field.each do |o|
    opp = NativeSim.party(o['keys'])
    # seed fixed per opponent so every variant faces identical RNG
    seed = 1000 + o['id'].hash.abs % 100_000
    # run_mons returns a bare symbol :a/:b/:draw (not a hash)
    r1 = NativeSim.run_mons(base, opp, seed: seed)
    crashes += 1 if NativeSim.last_error
    sc1 = r1 == :a ? 1.0 : (r1 == :b ? 0.0 : 0.5)
    r2 = NativeSim.run_mons(opp, base, seed: seed)
    crashes += 1 if NativeSim.last_error
    sc2 = r2 == :b ? 1.0 : (r2 == :a ? 0.0 : 0.5)
    pts += sc1 + sc2; n += 2; opp_elos << o['elo'].to_f; opp_elos << o['elo'].to_f
  end
  wr = pts / n
  pe = perf_elo(pts, n, opp_elos)
  results[item] = { wr: wr, pe: pe, n: n }
  puts "  #{item.ljust(15)} winrate #{'%.1f%%' % (wr*100)}  perf-Elo #{pe.round}  (#{n} games, #{crashes} engine-crash draws)"
end

puts "\n=== RESULT (#{MON} item A/B) ==="
results.sort_by { |_i, r| -r[:pe] }.each_with_index do |(i, r), rank|
  puts "  #{rank+1}. #{i.ljust(15)} #{'%.1f%%' % (r[:wr]*100)} winrate, perf-Elo #{r[:pe].round}"
end
best = results.max_by { |_i, r| r[:pe] }
puts "\nBEST: #{best[0]} (perf-Elo #{best[1][:pe].round})"
