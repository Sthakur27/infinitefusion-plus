# "What is the best team in the PC?" — decide it by DIRECT head-to-head, not by ladder Elo.
#
# A converged ladder is full of near-identical teams trading wins, so the #1 Elo slot can be
# noise. This takes the top-K finishers and plays a full round-robin, every pairing on N seeds
# and BOTH side assignments (so no result is a side-order artifact), then ranks by win rate.
#
#   ruby best_team.rb [ladder_tag] [K] [seeds]
require_relative 'nstore'
require_relative 'nbattle'

TAG   = ARGV[0] || 'ladder_pure'
K     = (ARGV[1] || 12).to_i
SEEDS = (ARGV[2] || 3).to_i
DIR   = File.join(__dir__, 'nreports', TAG)

st   = NStore::PARSE.call(File.binread(File.join(DIR, 'ladder.json')))
pool = NStore::PARSE.call(File.binread(File.join(DIR, 'pool.json')))
ENV['NSIM_SAVE'] = File.join(DIR, 'save_snapshot.rxdata')
NativeSim.boot!
$DEBUG = false

cap = ->(s) { s.to_s.split(/[_ ]/).map(&:capitalize).join(' ') }
label = lambda do |k|
  v = pool[k] || {}
  bs = v['bases'] || []
  "#{cap.(bs[0])}/#{cap.(bs[1])}"
end

teams = st['teams'].sort_by { |t| -t['elo'] }.first(K)
n = teams.length
puts "HEAD-TO-HEAD: top #{n} teams of #{TAG}, #{SEEDS} seed(s) x both sides per pairing"
puts "total games: #{n * (n - 1) * SEEDS}"

pts    = Hash.new(0.0)
played = Hash.new(0)
crash  = 0
teams.each_with_index do |ta, i|
  teams.each_with_index do |tb, j|
    next if j <= i
    SEEDS.times do |s|
      seed = 1000 + s
      # A on side 0
      r1 = NativeSim.run(ta['keys'], tb['keys'], seed: seed)
      crash += 1 if NativeSim.last_error
      sc = r1[:winner] == :a ? 1.0 : (r1[:winner] == :b ? 0.0 : 0.5)
      pts[ta['id']] += sc;       pts[tb['id']] += (1.0 - sc)
      # A on side 1 (same seed) — cancels any first-move/side advantage
      r2 = NativeSim.run(tb['keys'], ta['keys'], seed: seed)
      crash += 1 if NativeSim.last_error
      sc2 = r2[:winner] == :b ? 1.0 : (r2[:winner] == :a ? 0.0 : 0.5)
      pts[ta['id']] += sc2;      pts[tb['id']] += (1.0 - sc2)
      played[ta['id']] += 2;     played[tb['id']] += 2
    end
  end
end

ranked = teams.sort_by { |t| -(pts[t['id']] / [played[t['id']], 1].max) }
puts "\n#{'=' * 78}"
puts "RESULT — ranked by head-to-head win rate (#{crash} engine-crash draws)"
ranked.each_with_index do |t, i|
  wr = pts[t['id']] / [played[t['id']], 1].max
  puts format("\n#%-2d  %.1f%% winrate  (ladder Elo %d, ladder rank #%d)",
              i + 1, wr * 100, t['elo'].round, teams.index(t) + 1)
  t['keys'].each do |k|
    v = pool[k] || {}
    puts "      #{label.(k).ljust(28)} #{(v['name'] || '').ljust(13)} #{v['types']}  #{v['ability']} · #{v['item']}"
  end
end

best = ranked.first
puts "\n#{'=' * 78}"
puts "BEST TEAM (#{(pts[best['id']] / [played[best['id']], 1].max * 100).round(1)}% head-to-head):"
best['keys'].each do |k|
  v = pool[k] || {}
  puts "  #{label.(k).ljust(28)} #{(v['name'] || '').ljust(13)} #{v['ability']} · #{v['item']}"
  puts "      #{(v['moves'] || []).join(' / ')}"
end
