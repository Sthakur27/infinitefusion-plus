# PHASE 2 of the OU search: turn the phase-1 mon ratings into an actual best team.
#
#   ruby tools/sidmod_editor/sim/nbuild_ou.rb <rating_tag> <build_tag> [rounds] [seeds] [workers]
#
# Method
#   FIELD   8 opponents: 4 from the in-game "Smart - OU" builder (the generator Sid
#           actually plays against) + 4 top-performing chaos teams from phase 1.
#           Split TRAIN (hill-climb against) / TEST (held out, never optimised on)
#           so a team that only beats its training field is exposed as overfit.
#   SEEDS   every candidate plays every field team in BOTH orders on the SAME seeds
#           as its rivals -> paired comparison, so opponent identity cancels out.
#   CLIMB   each round: mutate one slot of the incumbent using the rating shortlist
#           (Species Clause enforced), batch-evaluate all mutations in parallel,
#           adopt the best only if it clears the incumbent by a real margin.
#   VERIFY  the winner is re-run on a big fresh seed block vs TRAIN *and* TEST.
require_relative 'nstore'
require_relative 'nrun'
require_relative 'nbattle'
require 'fileutils'

RTAG   = ARGV[0] || 'ou1'
BTAG   = ARGV[1] || 'oubuild'
ROUNDS = (ARGV[2] || 8).to_i
SEEDS  = (ARGV[3] || 6).to_i
NW     = (ARGV[4] || NRun.workers).to_i

NativeSim.boot!
POOL    = NStore.read_json(RTAG, 'pool.json')
RATINGS = File.readlines(File.join(NStore.dir(RTAG), 'ratings.csv'))[1..].map { |l|
  f = l.chomp.split(','); { key: f[0], name: f[1], species: f[2], types: f[3], item: f[4],
                            roles: f[5].to_s.split(';'), games: f[8].to_i, wr: f[9].to_f,
                            kos: f[10].to_f, faint: f[11].to_f, coef: f[13].to_f } }
BY_KEY = RATINGS.map { |r| [r[:key], r] }.to_h
OU     = NativeSim.pool(tier: :ou)
BASES  = OU.map { |e| [e[:key], e[:bases]] }.to_h
ROLES  = OU.map { |e| [e[:key], e[:roles]] }.to_h
TYPES  = OU.map { |e| [e[:key], e[:types]] }.to_h
FileUtils.mkdir_p(NStore.dir(BTAG))
LOG = File.open(File.join(NStore.dir(BTAG), 'changelog.txt'), 'wb')
def say(s); puts s; LOG.puts(s); LOG.flush; end

def legal?(keys)
  b = keys.flat_map { |k| BASES[k] || [] }
  keys.uniq.length == keys.length && b.uniq.length == b.length
end

def nm(keys); keys.map { |k| (BY_KEY[k] && BY_KEY[k][:name]) || k }.join(', '); end

# ------------------------------------------------------------------ field ----
def rand_team(rng)
  chosen = []; used = []
  OU.shuffle(random: rng).each do |e|
    next if (e[:bases] & used).any?
    chosen << e[:key]; used.concat(e[:bases]); break if chosen.length == 6
  end
  chosen
end

def smart_team(seed)
  refs = SidmodRandomOpp.build_team(:smart, :ou, seed)
  refs.map { |pk| NativeSim.all_pool.find { |e| e[:ref].equal?(pk) }[:key] }
end

def top_chaos_teams(rtag, n)
  teams = NStore.read_teams(rtag)
  rec = Hash.new { |h, k| h[k] = [0.0, 0] }
  NStore.read_games(File.join(NStore.dir(rtag), 'games.tsv')).each do |g|
    ta = g[:team_a]; tb = g[:team_b]
    pa = g[:winner] == :a ? 1.0 : (g[:winner] == :b ? 0.0 : 0.5)
    rec[ta][0] += pa; rec[ta][1] += 1
    rec[tb][0] += (1 - pa); rec[tb][1] += 1
  end
  byteam = {}
  teams.each { |id, t| byteam[t[:keys].join(',')] = id }
  rec.select { |_k, v| v[1] >= 8 }.sort_by { |k, v| -v[0] / v[1] }.first(n).map { |k, v|
    { name: "chaos:#{byteam[k] || '?'} (#{'%.2f' % (v[0] / v[1])} over #{v[1]})", keys: k.split(',') } }
end

# ------------------------------------------------------------- evaluation ----
# Returns per-candidate { wr:, n:, cells: {[fi,seed,side] => score} } for paired stats.
def eval_batch(tag, cands, field, seeds, nw)
  jobs = []
  cands.each_with_index do |keys, ci|
    field.each_with_index do |f, fi|
      seeds.each do |s|
        jobs << ["c#{ci}_f#{fi}_s#{s}_A", keys, f[:keys], s]
        jobs << ["c#{ci}_f#{fi}_s#{s}_B", f[:keys], keys, s]
      end
    end
  end
  path = NRun.execute(tag, jobs, nw, quiet: true)
  res = cands.map { { pts: 0.0, n: 0, cells: {} } }
  NStore.read_games(path).each do |g|
    m = g[:gid].match(/\Ac(\d+)_f(\d+)_s(\d+)_(A|B)\z/) or next
    ci, fi, s, side = m[1].to_i, m[2].to_i, m[3].to_i, m[4]
    score = if side == 'A'
              g[:winner] == :a ? 1.0 : (g[:winner] == :b ? 0.0 : 0.5)
            else
              g[:winner] == :b ? 1.0 : (g[:winner] == :a ? 0.0 : 0.5)
            end
    r = res[ci]; r[:pts] += score; r[:n] += 1; r[:cells][[fi, s, side]] = score
  end
  res.each { |r| r[:wr] = r[:n] > 0 ? r[:pts] / r[:n] : 0.0 }
  res
end

# paired difference (challenger - incumbent) over shared cells, with SE
def paired(inc, chal)
  cells = inc[:cells].keys & chal[:cells].keys
  return [0.0, 1.0, 0] if cells.empty?
  d = cells.map { |c| chal[:cells][c] - inc[:cells][c] }
  mean = d.sum / d.length
  var  = d.length > 1 ? d.map { |x| (x - mean)**2 }.sum / (d.length - 1) : 1.0
  [mean, Math.sqrt(var / d.length), d.length]
end

# ------------------------------------------------------ candidate seeding ----
SHORTLIST = RATINGS.select { |r| BASES.key?(r[:key]) && r[:games] >= 20 }.sort_by { |r| -r[:coef] }

def greedy_team(shortlist, role_balanced: true)
  chosen = []; used = []; tcount = Hash.new(0)
  need = role_balanced ? %w[hazard wall pivot] : []
  need.each do |role|
    c = shortlist.find { |r| !chosen.include?(r[:key]) && (BASES[r[:key]] & used).empty? &&
                             ROLES[r[:key]].map(&:to_s).include?(role) }
    next if !c
    chosen << c[:key]; used.concat(BASES[c[:key]]); TYPES[c[:key]].each { |t| tcount[t] += 1 }
  end
  shortlist.each do |r|
    break if chosen.length == 6
    next if chosen.include?(r[:key]) || (BASES[r[:key]] & used).any?
    next if role_balanced && TYPES[r[:key]].any? { |t| tcount[t] >= 2 }   # type spread
    chosen << r[:key]; used.concat(BASES[r[:key]]); TYPES[r[:key]].each { |t| tcount[t] += 1 }
  end
  chosen
end

def mutations(team, shortlist, per_slot: 3)
  out = []
  team.each_index do |i|
    cands = shortlist.reject { |r| team.include?(r[:key]) }
    picked = 0
    cands.each do |r|
      t = team.dup; t[i] = r[:key]
      next if !legal?(t)
      out << t; picked += 1
      break if picked >= per_slot
    end
  end
  out.uniq
end

# ------------------------------------------------------------------- run -----
say "=== OU team search (native SmartAI both sides, no LLM) ==="
say "ratings: #{RTAG}  shortlist #{SHORTLIST.length} mons (>=20 games)"

field_all = []
4.times { |i| field_all << { name: "smart#{i}", keys: smart_team(2000 + i * 37) } }
field_all += top_chaos_teams(RTAG, 4)
TRAIN = field_all.each_with_index.select { |_f, i| i.even? }.map(&:first)
TEST  = field_all.each_with_index.select { |_f, i| i.odd?  }.map(&:first)
say "\nFIELD (#{field_all.length}):"
field_all.each_with_index { |f, i| say "  [#{i.even? ? 'TRAIN' : 'TEST '}] #{f[:name].ljust(26)} #{nm(f[:keys])}" }

seeds = (1..SEEDS).to_a
seeds_v = (101..(100 + SEEDS * 3)).to_a     # fresh seeds for verification

seedsets = { 'greedy-coef' => greedy_team(SHORTLIST, role_balanced: false),
             'greedy-balanced' => greedy_team(SHORTLIST, role_balanced: true),
             'smart-builder' => smart_team(777),
             'top-chaos' => top_chaos_teams(RTAG, 1).first[:keys] }
say "\nSEED CANDIDATES:"
seedsets.each { |k, v| say "  #{k.ljust(16)} #{nm(v)}" }

r0 = eval_batch("#{BTAG}/seed", seedsets.values, TRAIN, seeds, NW)
seedsets.keys.each_with_index { |k, i| say "  %-16s TRAIN wr=%.3f (n=%d)" % [k, r0[i][:wr], r0[i][:n]] }
best_i = (0...r0.length).max_by { |i| r0[i][:wr] }
incumbent = seedsets.values[best_i]
inc_res = r0[best_i]
say "\nincumbent: #{seedsets.keys[best_i]} wr=%.3f" % inc_res[:wr]

history = []
ROUNDS.times do |rd|
  muts = mutations(incumbent, SHORTLIST.first(60))
  break if muts.empty?
  say "\n--- round #{rd + 1}: #{muts.length} mutations x #{TRAIN.length} field x #{SEEDS} seeds x 2 orders"
  rs = eval_batch("#{BTAG}/r#{rd + 1}", [incumbent] + muts, TRAIN, seeds, NW)
  base = rs[0]
  ranked = (1...rs.length).map { |i|
    d, se, n = paired(base, rs[i]); [i, rs[i][:wr], d, se, n] }.sort_by { |x| -x[2] }
  ranked.first(4).each { |i, wr, d, se, _n|
    changed = muts[i - 1].zip(incumbent).find { |a, b| a != b }
    say "    wr=%.3f  d=%+.3f +/- %.3f   %s -> %s" %
        [wr, d, se, BY_KEY[changed[1]] ? BY_KEY[changed[1]][:name] : changed[1],
         BY_KEY[changed[0]] ? BY_KEY[changed[0]][:name] : changed[0]]
  }
  i, wr, d, se, = ranked.first
  if d > se && d > 0.02
    changed = muts[i - 1].zip(incumbent).find { |a, b| a != b }
    say "  ADOPT: #{BY_KEY[changed[1]][:name]} -> #{BY_KEY[changed[0]][:name]} (base wr %.3f -> %.3f, paired %+.3f)" %
        [base[:wr], wr, d]
    history << { round: rd + 1, out: changed[1], in: changed[0], wr: wr, d: d }
    incumbent = muts[i - 1]
    inc_res = rs[i]
  else
    say "  no mutation clears the noise margin (best d=%+.3f +/- %.3f) -> converged" % [d, se]
    break
  end
end

say "\n=== VERIFY (fresh seeds, TRAIN + held-out TEST) ==="
final = eval_batch("#{BTAG}/verify", [incumbent] + seedsets.values, TRAIN, seeds_v, NW)
finalt = eval_batch("#{BTAG}/verify_test", [incumbent] + seedsets.values, TEST, seeds_v, NW)
labels = ['BEST'] + seedsets.keys
labels.each_with_index { |l, i|
  say "  %-16s TRAIN wr=%.3f (n=%d)   TEST wr=%.3f (n=%d)" %
      [l, final[i][:wr], final[i][:n], finalt[i][:wr], finalt[i][:n]] }

say "\n=== BEST TEAM ==="
say NativeSim.show_team(incumbent)
say "\nswaps adopted: " + (history.empty? ? '(none — seed team was already best)' :
    history.map { |h| "r#{h[:round]} #{BY_KEY[h[:out]][:name]}->#{BY_KEY[h[:in]][:name]}" }.join(', '))
NStore.write_json(BTAG, 'best_team.json',
                  'keys' => incumbent, 'names' => incumbent.map { |k| BY_KEY[k][:name] },
                  'train_wr' => final[0][:wr], 'test_wr' => finalt[0][:wr],
                  'field' => field_all.map { |f| f[:name] }, 'rounds' => history.length,
                  'seeds_per_matchup' => SEEDS, 'rating_tag' => RTAG)
LOG.close
