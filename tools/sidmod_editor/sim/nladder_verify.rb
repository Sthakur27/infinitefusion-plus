# Did the ladder actually get stronger, or is the rising bar just Elo inflation?
# Promotions enter at a performance rating measured against a SUBSET, so a lucky
# challenger can enter overrated. This plays the ladder's top teams against the
# previous champions and against its own mid/bottom on a clean, large sample.
#
#   ruby tools/sidmod_editor/sim/nladder_verify.rb <ladder_tag> <out_tag> [seeds] [workers]
require 'set'
require_relative 'nstore'
require_relative 'nrun'
require_relative 'nbattle'

LTAG  = ARGV[0] || 'ladder_ou'
OTAG  = ARGV[1] || (LTAG + '_verify')
SEEDS = (ARGV[2] || 10).to_i
NW    = (ARGV[3] || NRun.workers).to_i

ENV['NSIM_SAVE'] = File.join(NStore.dir(LTAG), 'save_snapshot.rxdata')
NativeSim.boot!
st = NStore::PARSE.call(File.binread(File.join(NStore.dir(LTAG), 'ladder.json')))
pool = NStore.read_json(LTAG, 'pool.json')
nm = ->(keys) { keys.map { |k| (pool[k] && pool[k]['name']) || k }.join(', ') }

ranked = st['teams'].sort_by { |t| -t['elo'] }
entrants = {}
ranked.first(5).each_with_index { |t, i| entrants["ladderTop#{i + 1}"] = t['keys'] }
mid = ranked[ranked.length / 2]; entrants['ladderMedian'] = mid['keys']
low = ranked.last;               entrants['ladderWorst']  = low['keys']

# the pre-ladder champions and rating-greedy builds, tier-filtered
legal = NativeSim.pool(tier: st['tier'].to_sym).map { |e| e[:key] }.to_set rescue
        NativeSim.pool(tier: st['tier'].to_sym).map { |e| e[:key] }
Dir[File.join(File.dirname(NStore.dir('x')), '*', 'champion.json')].sort.each do |f|
  c = NStore::PARSE.call(File.binread(f))
  keys = c['keys']
  next unless keys.is_a?(Array) && keys.length == 6 && keys.all? { |k| legal.include?(k) }
  entrants["champ:#{File.basename(File.dirname(f))}"] = keys
end

ids = entrants.keys
puts "=== ladder verification: #{ids.length} teams, #{SEEDS} seeds, both orders ==="
entrants.each { |k, v| puts "  %-18s %s" % [k, nm.(v)] }

jobs = []
ids.combination(2) do |x, y|
  ix = ids.index(x); iy = ids.index(y)
  SEEDS.times do |s|
    jobs << ["#{ix}v#{iy}s#{s + 1}A", entrants[x], entrants[y], s + 1]
    jobs << ["#{iy}v#{ix}s#{s + 1}B", entrants[y], entrants[x], s + 1]
  end
end
puts "\n#{jobs.length} games"
path = NRun.execute(OTAG, jobs, NW)

pts = Hash.new(0.0); n = Hash.new(0); h2h = Hash.new { |h, k| h[k] = [0.0, 0] }
NStore.read_games(path).each do |g|
  m = g[:gid].match(/\A(\d+)v(\d+)s(\d+)(A|B)\z/) or next
  i, j = m[1].to_i, m[2].to_i
  pa = g[:winner] == :a ? 1.0 : (g[:winner] == :b ? 0.0 : 0.5)
  pts[i] += pa; n[i] += 1; pts[j] += (1 - pa); n[j] += 1
  h2h[[i, j]][0] += pa; h2h[[i, j]][1] += 1
  h2h[[j, i]][0] += (1 - pa); h2h[[j, i]][1] += 1
end

puts "\n=== OVERALL ==="
ids.each_with_index.sort_by { |id, i| -(n[i] > 0 ? pts[i] / n[i] : 0) }.each do |id, i|
  puts "  %-18s %.3f over %d games" % [id, pts[i] / n[i], n[i]]
end

puts "\n=== ladder top vs each champion (ladder team's winrate) ==="
champs = ids.select { |x| x.start_with?('champ:') }
ids.select { |x| x.start_with?('ladder') }.each do |lt|
  li = ids.index(lt)
  row = champs.map { |c| p_, g_ = h2h[[li, ids.index(c)]]; "#{c.sub('champ:', '')} %.2f" % (g_ > 0 ? p_ / g_ : 0) }
  puts "  %-18s %s" % [lt, row.join('  ')]
end
