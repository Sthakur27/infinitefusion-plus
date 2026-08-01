# Robust "best team": pool the finalists from SEVERAL independent PURE searches and settle it
# by head-to-head.
#
# Why: PURE mode is a greedy hill-climb with no diversity pressure, so a single run converges to
# a LOCAL optimum and is path-dependent (observed: Bonecloak 32% usage in one run, 0% in
# another). Running several seeds and cross-validating the winners turns a path-dependent search
# into an answer that holds up.
#
#   ruby best_team_multi.rb <K_per_run> <seeds> <tag1> <tag2> ...
#
# Takes top-K teams from each ladder, dedupes identical rosters, round-robins ALL of them
# against each other on N seeds x both side assignments, ranks by win rate.
require_relative 'nstore'
require_relative 'nbattle'
require 'set'

KPER  = (ARGV[0] || 4).to_i
SEEDS = (ARGV[1] || 3).to_i
TAGS  = ARGV[2..] or abort 'usage: best_team_multi.rb <K_per_run> <seeds> <tag...>'
abort 'need at least one ladder tag' if TAGS.empty?

# every ladder must share a snapshot for keys to mean the same thing
ENV['NSIM_SAVE'] = File.join(__dir__, 'nreports', TAGS[0], 'save_snapshot.rxdata')
NativeSim.boot!
$DEBUG = false

cap = ->(s) { s.to_s.split(/[_ ]/).map(&:capitalize).join(' ') }
pool = NStore::PARSE.call(File.binread(File.join(__dir__, 'nreports', TAGS[0], 'pool.json')))
label = lambda do |k|
  v = pool[k] || {}
  bs = v['bases'] || []
  "#{cap.(bs[0])}/#{cap.(bs[1])}"
end

cands = []
seen  = Set.new
TAGS.each do |tag|
  f = File.join(__dir__, 'nreports', tag, 'ladder.json')
  next warn("skip #{tag}: no ladder.json") unless File.exist?(f)
  st = NStore::PARSE.call(File.binread(f))
  st['teams'].sort_by { |t| -t['elo'] }.first(KPER).each do |t|
    sig = t['keys'].sort.join(',')
    next if seen.include?(sig)
    seen << sig
    cands << { tag: tag, elo: t['elo'], keys: t['keys'], id: "#{tag}:#{t['id']}" }
  end
end

n = cands.length
puts "CROSS-RUN HEAD-TO-HEAD: #{n} distinct finalists from #{TAGS.length} run(s)"
puts "  #{n * (n - 1) * SEEDS} games (#{SEEDS} seed(s) x both sides per pairing)"
TAGS.each { |t| puts "    #{t}: #{cands.count { |c| c[:tag] == t }} unique finalists" }

pts = Hash.new(0.0); played = Hash.new(0); crash = 0
cands.each_with_index do |a, i|
  cands.each_with_index do |b, j|
    next if j <= i
    SEEDS.times do |s|
      seed = 7000 + s * 13
      r1 = NativeSim.run(a[:keys], b[:keys], seed: seed); crash += 1 if NativeSim.last_error
      sc = r1[:winner] == :a ? 1.0 : (r1[:winner] == :b ? 0.0 : 0.5)
      r2 = NativeSim.run(b[:keys], a[:keys], seed: seed); crash += 1 if NativeSim.last_error
      sc2 = r2[:winner] == :b ? 1.0 : (r2[:winner] == :a ? 0.0 : 0.5)
      pts[a[:id]] += sc + sc2;  pts[b[:id]] += (1.0 - sc) + (1.0 - sc2)
      played[a[:id]] += 2;      played[b[:id]] += 2
    end
  end
end

ranked = cands.sort_by { |c| -(pts[c[:id]] / [played[c[:id]], 1].max) }
puts "\n#{'=' * 78}"
puts "RESULT (#{crash} engine-crash draws).  +/- is the 95% CI on each win rate."
ranked.each_with_index do |c, i|
  g = [played[c[:id]], 1].max
  wr = pts[c[:id]] / g
  ci = 1.96 * Math.sqrt(wr * (1 - wr) / g) * 100
  puts format("\n#%-2d %.1f%% +/-%.1f   [%s, ladder Elo %d]", i + 1, wr * 100, ci, c[:tag], c[:elo].round)
  c[:keys].each { |k| puts "      #{label.(k)}" }
end

best = ranked.first
g = [played[best[:id]], 1].max
wr = pts[best[:id]] / g
ci = 1.96 * Math.sqrt(wr * (1 - wr) / g) * 100
runner = ranked[1]
rwr = runner ? pts[runner[:id]] / [played[runner[:id]], 1].max : 0
puts "\n#{'=' * 78}"
puts format('BEST: %.1f%% +/-%.1f over %d games', wr * 100, ci, g)
puts format('gap to #2: %.1f points — %s', (wr - rwr) * 100,
            (wr - rwr) * 100 > 2 * ci ? 'SIGNIFICANT' : 'NOT significant (within noise)')
best[:keys].each do |k|
  v = pool[k] || {}
  puts "  #{label.(k).ljust(28)} #{(v['name'] || '').ljust(13)} #{v['ability']} · #{v['item']}"
  puts "      #{(v['moves'] || []).join(' / ')}"
end
