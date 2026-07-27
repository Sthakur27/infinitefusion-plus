# WHY DO SEARCHED TEAMS CARRY NO HAZARDS / REMOVAL / RECOVERY?
# Two competing explanations, separated by measurement rather than opinion:
#   H1 (AI)     the tools exist in the pool but the AI cannot convert them, so the
#               search correctly learns they are worth less than a fifth attacker.
#   H2 (SUPPLY) the pool barely contains them, so teams cannot include them.
#
# Three tests:
#   1. SUPPLY CENSUS  — how many OU-legal mons carry each tool, and how they rate.
#   2. USAGE AUDIT    — hand the AI teams that DO carry them and count, from real
#                       battle logs, whether it ever clicks them. A tool that is
#                       available and never used is H1; unavailable is H2.
#   3. MARGINAL TEST  — force a hazard setter / remover / wall into a top offense
#                       team and measure the winrate change on a fixed field.
#
#   ruby tools/sidmod_editor/sim/nsupply.rb <ladder_tag> [rating_tag] [workers]
require_relative 'nstore'
require_relative 'nrun'
require_relative 'nbattle'
require_relative 'nniche'

LTAG = ARGV[0] || 'ladder_ou3'
RTAG = ARGV[1] || 'ou3'
NW   = (ARGV[2] || NRun.workers).to_i
ENV['NSIM_SAVE'] = File.join(NStore.dir(LTAG), 'save_snapshot.rxdata')
NativeSim.boot!

st = NStore::PARSE.call(File.binread(File.join(NStore.dir(LTAG), 'ladder.json')))
meta = NativeSim.all_pool.each_with_object({}) { |e, h|
  d = NativeSim.describe(e[:key])
  h[e[:key]] = { moves: d[:moves], ability: d[:ability], item: d[:item], types: d[:types],
                 stats: d[:stats], bases: e[:bases].map(&:to_s), name: d[:name], species: d[:species] }
}
rat = File.readlines(File.join(NStore.dir(RTAG), 'ratings.csv'))[1..].each_with_object({}) { |l, h|
  f = l.chomp.split(','); h[f[0]] = { wr: f[9].to_f, kos: f[10].to_f, games: f[8].to_i, coef: f[13].to_f }
}
OU = NativeSim.pool(tier: :ou).map { |e| e[:key] }

HAZ = ['Stealth Rock', 'Spikes', 'Toxic Spikes', 'Sticky Web']
REM = ['Rapid Spin', 'Defog', 'Court Change', 'Mortal Spin', 'Tidy Up']
REC = ['Recover', 'Roost', 'Soft-Boiled', 'Slack Off', 'Synthesis', 'Moonlight', 'Morning Sun',
       'Rest', 'Wish', 'Shore Up', 'Strength Sap']
PHZ = Niche::PHAZE
STA = ['Toxic', 'Will-O-Wisp', 'Thunder Wave', 'Yawn', 'Leech Seed']

def has(meta, k, list); (meta[k][:moves] & list).any?; end

puts "=" * 92
puts "TEST 1 — SUPPLY CENSUS (#{OU.length} OU-legal battle-ready mons)"
puts "=" * 92
puts "  %-16s %-6s %-7s %s" % %w[tool count share mean_coef(rating)]
{ 'hazards' => HAZ, 'removal' => REM, 'recovery' => REC, 'phazing' => PHZ, 'status' => STA }.each do |nm, list|
  ks = OU.select { |k| has(meta, k, list) }
  mc = ks.empty? ? 0 : ks.sum { |k| (rat[k] || {})[:coef].to_f } / ks.length
  puts "  %-16s %-6d %-7s %+.3f" % [nm, ks.length, "#{(100.0 * ks.length / OU.length).round}%", mc]
end
allc = OU.sum { |k| (rat[k] || {})[:coef].to_f } / OU.length
puts "  %-16s %-6d %-7s %+.3f" % ['(whole pool)', OU.length, '100%', allc]
puts "\n  best-rated mons per tool (rating coef, from #{RTAG} — measured under the OLD AI):"
{ 'hazards' => HAZ, 'removal' => REM, 'recovery' => REC }.each do |nm, list|
  ks = OU.select { |k| has(meta, k, list) }.sort_by { |k| -(rat[k] || {})[:coef].to_f }
  puts "    #{nm}:"
  ks.first(5).each { |k|
    puts "      %-13s %-26s coef %+.3f  ko/g %.2f  (%s)" %
         [meta[k][:name], meta[k][:species][0, 26], (rat[k] || {})[:coef].to_f,
          (rat[k] || {})[:kos].to_f, (meta[k][:moves] & list).join('+')] }
  puts "      (none)" if ks.empty?
end

# ---------------------------------------------------------------- TEST 2 ------
puts "\n" + "=" * 92
puts "TEST 2 — USAGE AUDIT: does the AI click these when it HAS them?"
puts "=" * 92
# use ladder teams that actually carry the tools; count opportunities vs uses
teams = st['teams'].sort_by { |t| -t['elo'] }
carriers = { haz: [], rem: [], rec: [] }
teams.each do |t|
  carriers[:haz] << t if t['keys'].any? { |k| has(meta, k, HAZ) }
  carriers[:rem] << t if t['keys'].any? { |k| has(meta, k, REM) }
  carriers[:rec] << t if t['keys'].any? { |k| has(meta, k, REC) }
end
puts "  ladder teams carrying: hazards #{carriers[:haz].length}/#{teams.length}, " \
     "removal #{carriers[:rem].length}/#{teams.length}, recovery #{carriers[:rec].length}/#{teams.length}"

sample = carriers[:haz].first(6)
opp    = teams.first(6)
counts = Hash.new(0)
battles = 0
sample.each_with_index do |t, i|
  o = opp.find { |x| x['id'] != t['id'] }
  3.times do |s|
    r = NativeSim.run(t['keys'], o['keys'], seed: 40 + s, log: true)
    battles += 1
    log = r[:log].map { |l| l.to_s.dup.force_encoding('UTF-8').scrub('?') }
    counts[:turns] += r[:turns]
    HAZ.each { |h| counts[:haz_used] += log.count { |l| l.include?("used #{h}") } }
    REM.each { |h| counts[:rem_used] += log.count { |l| l.include?("used #{h}") } }
    REC.each { |h| counts[:rec_used] += log.count { |l| l.include?("used #{h}") } }
    counts[:haz_dmg] += log.count { |l| l =~ /hurt by|Stealth Rock|Spikes/ && l =~ /hurt|damaged/ }
    counts[:battles_with_haz_set] += 1 if HAZ.any? { |h| log.any? { |l| l.include?("used #{h}") } }
    counts[:switches] += log.count { |l| l.include?('sent out') }
  end
end
puts "  #{battles} battles from hazard-carrying ladder teams (#{counts[:turns]} turns total):"
puts "    hazard moves used     #{counts[:haz_used]}   (battles where any hazard was set: #{counts[:battles_with_haz_set]}/#{battles})"
puts "    removal moves used    #{counts[:rem_used]}"
puts "    recovery moves used   #{counts[:rec_used]}"
puts "    switch-ins (hazard damage opportunities) #{counts[:switches]}"

# ---------------------------------------------------------------- TEST 3 ------
puts "\n" + "=" * 92
puts "TEST 3 — MARGINAL VALUE: force a tool into a top offense team"
puts "=" * 92
base_t = teams.find { |t| (t['niche'] == 'hyperoffense' || t['niche'] == 'priority') &&
                          t['keys'].none? { |k| has(meta, k, HAZ + REM + REC) } } || teams.first
base = base_t['keys']
puts "  base (#{base_t['id']}, #{base_t['niche']}, Elo #{'%.0f' % base_t['elo']}): " \
     "#{base.map { |k| meta[k][:name] }.join(', ')}"

legal = lambda do |t|
  b = t.flat_map { |k| meta[k][:bases] }
  t.uniq.length == 6 && b.uniq.length == b.length
end
pick_best = lambda do |list|
  OU.select { |k| has(meta, k, list) && !base.include?(k) }
    .sort_by { |k| -(rat[k] || {})[:coef].to_f }
end

variants = { 'base' => base }
{ 'hazard' => HAZ, 'removal' => REM, 'recovery' => REC }.each do |nm, list|
  cands = pick_best.(list)
  # swap into the WEAKEST-rated slot so the comparison is fair
  slot = (0...6).min_by { |i| (rat[base[i]] || {})[:coef].to_f }
  got = nil
  cands.each do |c|
    t = base.dup; t[slot] = c
    next unless legal.(t)
    got = [t, c]; break
  end
  next if !got
  variants["+#{nm}"] = got[0]
  puts "  +#{nm}: #{meta[got[1]][:name]} (#{(meta[got[1]][:moves] & list).join('+')}) " \
       "replaces #{meta[base[slot]][:name]}"
end

field = teams.each_slice([teams.length / 10, 1].max).map(&:first).first(10)
seeds = (1..22).to_a
jobs = []
vk = variants.keys
vk.each_with_index do |name, ci|
  field.each_with_index do |f, fi|
    next if f['keys'] == variants[name]
    seeds.each do |s|
      jobs << ["c#{ci}_f#{fi}_s#{s}_A", variants[name], f['keys'], s]
      jobs << ["c#{ci}_f#{fi}_s#{s}_B", f['keys'], variants[name], s]
    end
  end
end
puts "\n  #{jobs.length} games (#{vk.length} variants x #{field.length} field x #{seeds.length} seeds x 2 orders)"
path = NRun.execute("#{LTAG}_supply", jobs, NW, quiet: true)
res = Hash.new { |h, k| h[k] = [0.0, 0] }
NStore.read_games(path).each do |g|
  m = g[:gid].match(/\Ac(\d+)_f(\d+)_s(\d+)_(A|B)\z/) or next
  ci = m[1].to_i; side = m[4]
  sc = side == 'A' ? (g[:winner] == :a ? 1.0 : (g[:winner] == :b ? 0.0 : 0.5))
                   : (g[:winner] == :b ? 1.0 : (g[:winner] == :a ? 0.0 : 0.5))
  res[vk[ci]][0] += sc; res[vk[ci]][1] += 1
end
b = res['base'][1] > 0 ? res['base'][0] / res['base'][1] : 0
puts "\n  %-12s %-8s %-8s %s" % %w[variant winrate delta n]
vk.each do |name|
  p_, n_ = res[name]
  next if n_.zero?
  wr = p_ / n_
  puts "  %-12s %.3f    %+.3f   %d" % [name, wr, wr - b, n_]
end
se = Math.sqrt(0.5 / [res['base'][1], 1].max) * 1.96
puts "  (95%% CI on a single winrate is about +/-%.3f, so treat deltas under that as noise)" % se
