# CHAOS vs SMART, at OU and at Ubers — a fair test of the four in-game Random Battle
# modes against each other.
#
#   ruby tools/sidmod_editor/sim/nmodes.rb <snapshot_tag> <out_tag> [teams_per_mode] [seeds] [workers]
#
# Design notes that make this a fair comparison, unlike the earlier tournaments:
#   * Teams come from the GAME'S OWN generator (SidmodRandomOpp.build_team) for all
#     four modes — Chaos/Smart x OU/Ubers — so this measures the shipped feature, not
#     a reimplementation.
#   * Seeds are drawn blind and NO team is selected for being good or bad. The earlier
#     `chaos:` entrants were picked as top/bottom performers, which inflates or
#     deflates chaos and cannot answer "which mode is stronger".
#   * All four modes share ONE save snapshot, so the OU pool is a strict subset of the
#     Ubers pool and cross-tier results are meaningful.
#   * Full round robin, both side assignments, N seeds per pairing.
# Reports per-mode winrate, the mode-vs-mode matrix, and within-mode spread (chaos
# should be higher-variance by construction).
require_relative 'nstore'
require_relative 'nrun'
require_relative 'nbattle'
require 'fileutils'

STAG  = ARGV[0] || 'ub1'          # run dir whose save_snapshot.rxdata we reuse
OTAG  = ARGV[1] || 'modes'
PER   = (ARGV[2] || 20).to_i
SEEDS = (ARGV[3] || 3).to_i
NW    = (ARGV[4] || NRun.workers).to_i

snap = File.join(NStore.dir(STAG), 'save_snapshot.rxdata')
ENV['NSIM_SAVE'] = snap if File.exist?(snap)
NativeSim.boot!
FileUtils.mkdir_p(NStore.dir(OTAG))
puts "snapshot: #{ENV['NSIM_SAVE'] || '(live save)'}"
puts "pool: #{NativeSim.all_pool.length} battle-ready, #{NativeSim.pool(tier: :ou).length} OU-legal"

MODES = [[:chaos, :ou], [:smart, :ou], [:chaos, :ubers], [:smart, :ubers]]
def mode_name(sel, tier); "#{sel.to_s.capitalize}-#{tier == :ou ? 'OU' : 'Ubers'}"; end

# build PER teams per mode with blind seeds
key_of = NativeSim.all_pool.each_with_object({}) { |e, h| h[e[:ref].object_id] = e[:key] }
teams = {}          # id => keys
mode_of = {}        # id => "Chaos-OU"
MODES.each_with_index do |(sel, tier), mi|
  made = 0
  seed = 500_000 + mi * 10_000
  while made < PER
    seed += 1
    refs = SidmodRandomOpp.build_team(sel, tier, seed)
    next if !refs
    keys = refs.map { |pk| key_of[pk.object_id] }.compact
    next if keys.length != 6
    id = "#{mode_name(sel, tier)}##{made}"
    next if teams.value?(keys)
    teams[id] = keys; mode_of[id] = mode_name(sel, tier)
    made += 1
  end
  puts "  built #{PER} #{mode_name(sel, tier)} teams"
end

NStore.write_teams(OTAG, teams.map { |id, k| [id, { source: mode_of[id], keys: k }] }.to_h)
ids = teams.keys
jobs = []
ids.combination(2) do |x, y|
  ix = ids.index(x); iy = ids.index(y)
  SEEDS.times do |s|
    jobs << ["#{ix}v#{iy}s#{s + 1}A", teams[x], teams[y], s + 1]
    jobs << ["#{iy}v#{ix}s#{s + 1}B", teams[y], teams[x], s + 1]
  end
end
puts "\n#{ids.length} teams -> #{jobs.length} games"
path = NRun.execute(OTAG, jobs, NW)

# ---- aggregate --------------------------------------------------------------
pts = Hash.new(0.0); ngm = Hash.new(0)
cross = Hash.new { |h, k| h[k] = [0.0, 0] }    # [modeA, modeB] => [points for A, games]
NStore.read_games(path).each do |g|
  m = g[:gid].match(/\A(\d+)v(\d+)s(\d+)(A|B)\z/) or next
  i, j = m[1].to_i, m[2].to_i
  pa = g[:winner] == :a ? 1.0 : (g[:winner] == :b ? 0.0 : 0.5)
  pts[i] += pa; ngm[i] += 1; pts[j] += (1 - pa); ngm[j] += 1
  mi = mode_of[ids[i]]; mj = mode_of[ids[j]]
  cross[[mi, mj]][0] += pa;       cross[[mi, mj]][1] += 1
  cross[[mj, mi]][0] += (1 - pa); cross[[mj, mi]][1] += 1
end

names = MODES.map { |s, t| mode_name(s, t) }
per_mode = names.map { |n|
  tids = ids.select { |id| mode_of[id] == n }
  wrs  = tids.map { |id| i = ids.index(id); ngm[i] > 0 ? pts[i] / ngm[i] : 0.0 }
  tot_p = tids.sum { |id| pts[ids.index(id)] }
  tot_n = tids.sum { |id| ngm[ids.index(id)] }
  mean = tot_p / tot_n
  sd = Math.sqrt(wrs.map { |w| (w - wrs.sum / wrs.length)**2 }.sum / [wrs.length - 1, 1].max)
  [n, mean, sd, wrs.min, wrs.max, tot_n, tids]
}

puts "\n=== PER-MODE OVERALL WINRATE (vs the whole field of all four modes) ==="
puts "  %-12s %-8s %-8s %-8s %-8s %s" % %w[mode winrate sd worst best games]
per_mode.sort_by { |x| -x[1] }.each { |n, mean, sd, mn, mx, tn, _|
  puts "  %-12s %.3f    %.3f    %.3f    %.3f    %d" % [n, mean, sd, mn, mx, tn] }

puts "\n=== MODE vs MODE (row's winrate against column) ==="
print "  %-12s" % ''; names.each { |n| print "%-12s" % n }; puts
names.each do |a|
  print "  %-12s" % a
  names.each do |b|
    p_, n_ = cross[[a, b]]
    print "%-12s" % (n_ > 0 ? ('%.3f (%d)' % [p_ / n_, n_]) : '-')
  end
  puts
end

puts "\n=== HEADLINE COMPARISONS ==="
sh = ->(a, b) { p_, n_ = cross[[a, b]]; n_ > 0 ? "%.3f over %d games" % [p_ / n_, n_] : 'n/a' }
puts "  Chaos-OU    vs Smart-OU    : #{sh.('Chaos-OU', 'Smart-OU')}   (Chaos' winrate)"
puts "  Chaos-Ubers vs Smart-Ubers : #{sh.('Chaos-Ubers', 'Smart-Ubers')}   (Chaos' winrate)"
puts "  Ubers pair  vs OU pair     : Chaos-Ubers vs Chaos-OU #{sh.('Chaos-Ubers', 'Chaos-OU')}, " \
     "Smart-Ubers vs Smart-OU #{sh.('Smart-Ubers', 'Smart-OU')}"

# best/worst individual team per mode, for the report
detail = per_mode.map { |n, mean, sd, mn, mx, tn, tids|
  ranked = tids.sort_by { |id| i = ids.index(id); -(ngm[i] > 0 ? pts[i] / ngm[i] : 0) }
  { 'mode' => n, 'winrate' => mean, 'sd' => sd, 'min' => mn, 'max' => mx, 'games' => tn,
    'best_team' => ranked.first, 'best_keys' => teams[ranked.first],
    'worst_team' => ranked.last, 'worst_keys' => teams[ranked.last] }
}
NStore.write_json(OTAG, 'modes.json',
                  'per_mode' => detail, 'teams_per_mode' => PER, 'seeds' => SEEDS,
                  'games' => jobs.length, 'snapshot_from' => STAG,
                  'cross' => cross.map { |(a, b), (p_, n_)| ["#{a}|#{b}", { 'wr' => (n_ > 0 ? p_ / n_ : nil), 'games' => n_ }] }.to_h)

puts "\nper-mode best / worst individual team:"
detail.each { |d|
  puts "  #{d['mode']}: best #{d['best_team']} (%.3f) / worst #{d['worst_team']} (%.3f)" % [d['max'], d['min']]
}
puts "\nartifacts -> #{NStore.dir(OTAG)}"
