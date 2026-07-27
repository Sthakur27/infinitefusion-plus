# TEAM-BY-TEAM ranking: full round-robin between every entrant team, both orders,
# N seeds, native SmartAI on both sides. Produces best/worst teams, each team's
# best and worst matchups, and an Elo table.
#
#   ruby tools/sidmod_editor/sim/ntourney.rb <rating_tag> <tourney_tag> [seeds] [chaos_k] [workers]
#
# Entrants
#   named:<X>     hand-built teams identified by shared nickname in the PC
#   smart:<n>     the in-game "Smart - OU" builder at n different seeds (what Random
#                 Battle actually throws at you)
#   chaos:<id>    top-rated random teams from the phase-1 sweep
#   built:<X>     teams constructed from phase-1 mon ratings (greedy / balanced /
#                 no-cheese variants)
# Flags
#   NO_WONDERGUARD=1  drop Wonder Guard mons from constructed teams + report both
require_relative 'nstore'
require_relative 'nrun'
require_relative 'nbattle'
require 'fileutils'
require 'set'

RTAG  = ARGV[0] || 'ou1'
TTAG  = ARGV[1] || 'outourney'
SEEDS = (ARGV[2] || 8).to_i
CHAOS_K = (ARGV[3] || 6).to_i
NW    = (ARGV[4] || NRun.workers).to_i
TIER  = (ENV['TIER'] || 'ou').to_sym

ENV['NSIM_SAVE'] = File.join(NStore.dir(RTAG), 'save_snapshot.rxdata') if File.exist?(File.join(NStore.dir(RTAG), 'save_snapshot.rxdata'))
NativeSim.boot!
POOL = NStore.read_json(RTAG, 'pool.json')
RAT  = File.readlines(File.join(NStore.dir(RTAG), 'ratings.csv'))[1..].map { |l|
  f = l.chomp.split(','); { key: f[0], name: f[1], species: f[2], types: f[3], item: f[4],
                            roles: f[5].to_s.split(';'), games: f[8].to_i, wr: f[9].to_f,
                            kos: f[10].to_f, coef: f[13].to_f } }
BY = RAT.map { |r| [r[:key], r] }.to_h
OU = NativeSim.pool(tier: TIER)
BASES = OU.map { |e| [e[:key], e[:bases]] }.to_h
ROLES = OU.map { |e| [e[:key], e[:roles].map(&:to_s)] }.to_h
TYPES = OU.map { |e| [e[:key], e[:types]] }.to_h
WG    = OU.select { |e| (e[:ref].ability&.id rescue nil) == :WONDERGUARD }.map { |e| e[:key] }.to_set rescue []
FileUtils.mkdir_p(NStore.dir(TTAG))

def nm(keys); keys.map { |k| (BY[k] && BY[k][:name]) || k }.join(', '); end
def legal?(keys)
  b = keys.flat_map { |k| BASES[k] || [] }
  keys.uniq.length == keys.length && b.uniq.length == b.length
end

# ---- entrants ---------------------------------------------------------------
entrants = {}

# hand-built teams: >=6 OU-legal mons sharing a nickname
groups = {}
OU.each { |e| (groups[e[:name]] ||= []) << e }
groups.each do |name, es|
  next if es.length < 6 || name.to_s.strip.length < 2 || name == '.'
  keys = es.sort_by { |e| [e[:box], e[:slot]] }.first(6).map { |e| e[:key] }
  entrants["named:#{name}"] = keys if legal?(keys)
end

# in-game Smart-OU builder
8.times do |i|
  refs = SidmodRandomOpp.build_team(:smart, TIER, 3000 + i * 91)
  entrants["smart:#{i}"] = refs.map { |pk| NativeSim.all_pool.find { |e| e[:ref].equal?(pk) }[:key] }
end

# top chaos teams from the sweep (needs enough games to mean anything)
teams1 = NStore.read_teams(RTAG)
rec = Hash.new { |h, k| h[k] = [0.0, 0] }
NStore.read_games(File.join(NStore.dir(RTAG), 'games.tsv')).each do |g|
  pa = g[:winner] == :a ? 1.0 : (g[:winner] == :b ? 0.0 : 0.5)
  rec[g[:team_a]][0] += pa;       rec[g[:team_a]][1] += 1
  rec[g[:team_b]][0] += (1 - pa); rec[g[:team_b]][1] += 1
end
id_of = teams1.map { |id, t| [t[:keys].join(','), id] }.to_h
rec.select { |_k, v| v[1] >= 12 }.sort_by { |_k, v| -v[0] / v[1] }.first(CHAOS_K).each do |k, _v|
  entrants["chaos:#{id_of[k] || k[0, 6]}"] = k.split(',')
end
# and the WORST chaos teams, as a floor reference
rec.select { |_k, v| v[1] >= 12 }.sort_by { |_k, v| v[0] / v[1] }.first(2).each do |k, _v|
  entrants["chaosWORST:#{id_of[k] || k[0, 6]}"] = k.split(',')
end

# constructed from mon ratings
def build(shortlist, balanced:, exclude: [])
  chosen = []; used = []; tc = Hash.new(0)
  sl = shortlist.reject { |r| exclude.include?(r[:key]) }
  (balanced ? %w[hazard wall pivot] : []).each do |role|
    c = sl.find { |r| !chosen.include?(r[:key]) && (BASES[r[:key]] & used).empty? &&
                      ROLES[r[:key]].to_a.include?(role) }
    next if !c
    chosen << c[:key]; used.concat(BASES[c[:key]]); TYPES[c[:key]].each { |t| tc[t] += 1 }
  end
  sl.each do |r|
    break if chosen.length == 6
    next if chosen.include?(r[:key]) || (BASES[r[:key]] & used).any?
    next if balanced && TYPES[r[:key]].any? { |t| tc[t] >= 2 }
    chosen << r[:key]; used.concat(BASES[r[:key]]); TYPES[r[:key]].each { |t| tc[t] += 1 }
  end
  chosen
end
SL = RAT.select { |r| BASES.key?(r[:key]) && r[:games] >= 100 }.sort_by { |r| -r[:coef] }
entrants['built:coef']        = build(SL, balanced: false)
entrants['built:balanced']    = build(SL, balanced: true)
entrants['built:coef-noWG']   = build(SL, balanced: false, exclude: WG.to_a)
entrants['built:bal-noWG']    = build(SL, balanced: true,  exclude: WG.to_a)
# KO-rate build (offense-only signal) and winrate build, for method comparison
entrants['built:kos'] = build(RAT.select { |r| BASES.key?(r[:key]) && r[:games] >= 100 }
                                 .sort_by { |r| -r[:kos] }, balanced: false)

# champions produced by nsearch2.rb (any run dir holding a champion.json)
Dir[File.join(File.dirname(NStore.dir('x')), '*', 'champion.json')].sort.each do |f|
  c = NStore::PARSE.call(File.binread(f))
  tag = File.basename(File.dirname(f))
  entrants["champ:#{tag}"] = c['keys'] if c['keys'].is_a?(Array) && c['keys'].length == 6
end

# ARGV[5]: pool keys (or the token WONDERGUARD) to EXCLUDE from testing. Sid's call:
# cheese that only beats the AI is dropped during testing rather than banned in-game.
ban = (ARGV[5] || '').split(',').reject(&:empty?)
ban.concat(WG.to_a) if ban.delete('WONDERGUARD')
unless ban.empty?
  dropped = entrants.select { |_k, v| (v & ban).any? }.keys
  entrants = entrants.reject { |_k, v| (v & ban).any? }
  puts "EXCLUDED (contain banned mons #{ban.map { |k| BY[k] ? BY[k][:name] : k }.join(',')}): " \
       "#{dropped.empty? ? 'none' : dropped.join(', ')}"
end

entrants = entrants.reject { |_k, v| v.length != 6 || !legal?(v) }
ids = entrants.keys
puts "=== ROUND ROBIN: #{ids.length} teams, #{SEEDS} seeds, both orders ==="
entrants.each { |id, k| puts "  %-24s %s" % [id, nm(k)] }
NStore.write_teams(TTAG, entrants.map { |id, k| [id, { source: id.split(':').first, keys: k }] }.to_h)

jobs = []
ids.combination(2) do |x, y|
  SEEDS.times do |s|
    seed = 1 + s
    jobs << ["#{ids.index(x)}v#{ids.index(y)}s#{seed}A", entrants[x], entrants[y], seed]
    jobs << ["#{ids.index(y)}v#{ids.index(x)}s#{seed}B", entrants[y], entrants[x], seed]
  end
end
puts "\n#{jobs.length} games"
path = NRun.execute(TTAG, jobs, NW)

# ---- aggregate --------------------------------------------------------------
pts = Hash.new(0.0); ngm = Hash.new(0)
h2h = Hash.new { |hh, k| hh[k] = [0.0, 0] }   # [i,j] => [points for i, games]
NStore.read_games(path).each do |g|
  m = g[:gid].match(/\A(\d+)v(\d+)s(\d+)(A|B)\z/) or next
  i, j, _s, side = m[1].to_i, m[2].to_i, m[3].to_i, m[4]
  # gid is "<sideA-team>v<sideB-team>"; winner :a is the first index
  pa = g[:winner] == :a ? 1.0 : (g[:winner] == :b ? 0.0 : 0.5)
  pts[i] += pa; ngm[i] += 1; pts[j] += (1 - pa); ngm[j] += 1
  h2h[[i, j]][0] += pa; h2h[[i, j]][1] += 1
  h2h[[j, i]][0] += (1 - pa); h2h[[j, i]][1] += 1
end

# Elo (logistic, iterative) on the pairwise record
elo = Hash.new(0.0)
60.times do
  grad = Hash.new(0.0)
  h2h.each do |(i, j), (p, n)|
    next if n == 0
    exp = 1.0 / (1.0 + 10**((elo[j] - elo[i]) / 400.0))
    grad[i] += (p - exp * n)
  end
  grad.each { |i, gv| elo[i] += 4.0 * gv / [ngm[i], 1].max }
end

rows = ids.each_with_index.map { |id, i|
  { id: id, wr: ngm[i] > 0 ? pts[i] / ngm[i] : 0, n: ngm[i], elo: elo[i], keys: entrants[id] }
}.sort_by { |r| -r[:wr] }

puts "\n=== TEAM LEADERBOARD (#{SEEDS * 2} games per pairing) ==="
puts "  %-24s %-6s %-6s %-5s %s" % %w[team winrate elo games record]
rows.each { |r|
  i = ids.index(r[:id])
  best = h2h.select { |(a, _b), (_p, n)| a == i && n > 0 }.max_by { |(_k), (p, n)| p / n }
  wrst = h2h.select { |(a, _b), (_p, n)| a == i && n > 0 }.min_by { |(_k), (p, n)| p / n }
  bi = best && ids[best[0][1]]; wi = wrst && ids[wrst[0][1]]
  puts "  %-24s %.3f  %+6.0f %-5d best vs %s (%.2f)  worst vs %s (%.2f)" %
       [r[:id], r[:wr], r[:elo], r[:n], bi.to_s[0, 18], best[1][0] / best[1][1],
        wi.to_s[0, 18], wrst[1][0] / wrst[1][1]]
}

lines = ["# OU team tournament (#{TTAG})", "",
         "SmartTrainerAI both sides, level 100, Species+Spore+OU-legend clauses, #{SEEDS} seeds x 2 orders per pairing.",
         "#{jobs.length} games total.", "", "| rank | team | winrate | elo | games |", "|---|---|---|---|---|"]
rows.each_with_index { |r, i| lines << "| #{i + 1} | #{r[:id]} | #{'%.3f' % r[:wr]} | #{'%+.0f' % r[:elo]} | #{r[:n]} |" }
lines << "" << "## Rosters" << ""
rows.each { |r| lines << "**#{r[:id]}** (wr #{'%.3f' % r[:wr]}) — #{nm(r[:keys])}" << "" }
File.binwrite(File.join(NStore.dir(TTAG), 'report.md'), lines.join("\n"))
NStore.write_json(TTAG, 'leaderboard.json',
                  rows.map { |r| { 'team' => r[:id], 'winrate' => r[:wr], 'elo' => r[:elo],
                                   'games' => r[:n], 'keys' => r[:keys],
                                   'names' => r[:keys].map { |k| BY[k] ? BY[k][:name] : k } } })
puts "\nreport -> #{File.join(NStore.dir(TTAG), 'report.md')}"
