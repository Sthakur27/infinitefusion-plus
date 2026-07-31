# RQ2 metrics for a completed ladder: DIVERSITY (is the meta more varied?) and
# DEGENERACY (are games decided in 1-2 turns?).
#   ruby ladder_metrics.rb <ladder_tag> [turn_sample_games]
# Diversity is read from ladder.json; game-length is sampled by replaying games among
# the ladder's own teams on its frozen snapshot (turnCount is deterministic per seed).
# Appends a comparable one-row summary to nreports/metrics_summary.tsv.
require_relative 'nstore'
require_relative 'nbattle'

TAG   = ARGV[0] || 'ladder_c0'
NGAME = (ARGV[1] || 240).to_i
DIR   = File.join(__dir__, 'nreports', TAG)
st    = NStore::PARSE.call(File.binread(File.join(DIR, 'ladder.json')))
pool  = NStore::PARSE.call(File.binread(File.join(DIR, 'pool.json')))
teams = st['teams'].sort_by { |t| -t['elo'] }
n = teams.length

# ---- DIVERSITY ----
def shannon_even(counts)
  tot = counts.sum.to_f
  return 0.0 if tot <= 0 || counts.length <= 1
  h = -counts.reject { |c| c <= 0 }.sum { |c| p = c / tot; p * Math.log2(p) }
  h / Math.log2(counts.length)          # normalized evenness [0,1]
end
def gini(vals)
  return 0.0 if vals.empty?
  s = vals.sort; nn = s.length; cum = 0; s.each_with_index { |v, i| cum += (i + 1) * v }
  tot = s.sum.to_f
  return 0.0 if tot <= 0
  (2.0 * cum) / (nn * tot) - (nn + 1.0) / nn
end

niches = teams.map { |t| t['niche'] || 'generic' }
niche_counts = niches.tally
usage = Hash.new(0); teams.each { |t| t['keys'].each { |k| usage[k] += 1 } }
distinct_mons = usage.length
top_share = usage.values.max.to_f / n
niche_even = shannon_even(niche_counts.values)
usage_gini = gini(usage.values)
# archetype Elo compression: spread of per-niche mean Elo (lower = more archetypes viable)
niche_means = niches.uniq.map { |nm| els = teams.select { |t| (t['niche'] || 'generic') == nm }.map { |t| t['elo'] }; els.sum / els.length }
arch_spread = niche_means.max - niche_means.min
elos = teams.map { |t| t['elo'] }
top_bar_gap = elos.max - elos.sort[n / 2]

# ---- DEGENERACY: game-length sample among the meta-defining teams ----
ENV['NSIM_SAVE'] = File.join(DIR, 'save_snapshot.rxdata')
NativeSim.boot!
$DEBUG = false
top = teams.first([40, n].min)
rng = Random.new(20260730)
turns = []; crashes = 0
NGAME.times do |i|
  a = top[rng.rand(top.length)]; b = top[rng.rand(top.length)]
  next if a['id'] == b['id']
  r = NativeSim.run(a['keys'], b['keys'], seed: 1 + i)
  crashes += 1 if NativeSim.last_error
  turns << r[:turns] if r[:turns] && r[:turns] > 0
end
turns.sort!
med = turns.empty? ? 0 : turns[turns.length / 2]
mean = turns.empty? ? 0 : (turns.sum.to_f / turns.length)
pct_le3 = turns.empty? ? 0 : 100.0 * turns.count { |t| t <= 3 } / turns.length
pct_le5 = turns.empty? ? 0 : 100.0 * turns.count { |t| t <= 5 } / turns.length

puts "=== #{TAG} — #{n} teams, batch #{st['batch']} ==="
bm = st['ban_meta'] || {}
puts "bans: species=#{bm['ban_species'] || '-'}  clauses=#{bm['clauses'] != false}  (#{(st['banned_keys'] || []).length} keys removed)"
puts "DIVERSITY:"
puts "  niche evenness (Shannon)   #{'%.3f' % niche_even}   (1.0 = perfectly even across archetypes)"
puts "  distinct mons on ladder    #{distinct_mons}"
puts "  top-mon usage share        #{'%.1f%%' % (top_share * 100)}   usage Gini #{'%.3f' % usage_gini}   (lower = more variety)"
puts "  archetype Elo spread       #{arch_spread.round}   top-vs-bar gap #{top_bar_gap.round}"
puts "  niches: #{niche_counts.sort_by { |_k, v| -v }.map { |k, v| "#{k} #{v}" }.join(', ')}"
puts "DEGENERACY (#{turns.length} sampled games, #{crashes} crashes):"
puts "  game length  median #{med}  mean #{'%.1f' % mean}  turns"
puts "  short games  #{'%.0f%%' % pct_le3} <=3 turns   #{'%.0f%%' % pct_le5} <=5 turns   (higher = more degenerate)"

row = [TAG, bm['ban_species'] || '-', n, '%.3f' % niche_even, distinct_mons,
       '%.1f' % (top_share * 100), '%.3f' % usage_gini, arch_spread.round, top_bar_gap.round,
       med, '%.1f' % mean, '%.0f' % pct_le3, '%.0f' % pct_le5].join("\t")
sumf = File.join(__dir__, 'nreports', 'metrics_summary.tsv')
hdr = %w[tag ban_species teams niche_even distinct top_share% usage_gini arch_spread top_bar_gap med_turns mean_turns pct<=3 pct<=5].join("\t")
File.write(sumf, hdr + "\n") unless File.exist?(sumf)
File.open(sumf, 'a') { |f| f.puts row }
puts "\nappended to #{sumf}"
