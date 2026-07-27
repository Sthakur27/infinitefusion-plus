# PHASE 3: population search for the best OU team + per-slot mon value in a STRONG
# team (as opposed to phase 1's value in a random team).
#
#   ruby tools/sidmod_editor/sim/nsearch2.rb <rating_tag> <out_tag> [gens] [seeds] [workers]
#
# Fixes what the first hill-climb got wrong:
#   * FIELD is 18 stratified opponents (smart-builder / chaos across the whole
#     quality range / hand-built / rating-constructed), split TRAIN 9 + TEST 9 by
#     alternating within each stratum, so both halves have the same mix and TEST
#     is never optimised against.
#   * POPULATION + elitism + crossover instead of one greedy chain, so the search
#     can't walk itself into a single field-specific cheese pick.
#   * every survivor is re-verified on fresh seeds against TRAIN and TEST.
# Then LEAVE-ONE-OUT: each slot of the winner is swapped against the top-N rated
# alternatives to measure each mon's marginal value in a strong team.
require_relative 'nstore'
require_relative 'nrun'
require_relative 'nbattle'
require 'fileutils'
require 'set'

RTAG  = ARGV[0] || 'ou1'
OTAG  = ARGV[1] || 'ou2'
GENS  = (ARGV[2] || 6).to_i
SEEDS = (ARGV[3] || 6).to_i
NW    = (ARGV[4] || NRun.workers).to_i
# ARGV[5]: comma-separated pool keys to ban from candidate teams (e.g. the 1-HP
# Wonder Guard mon, which beats the AI by exploiting a planner blind spot rather
# than by being strong). Banned mons still appear in the opponent FIELD.
BAN   = (ARGV[5] || '').split(',').reject(&:empty?)
TIER  = (ENV['TIER'] || 'ou').to_sym
POP   = 24
ELITE = 8

NativeSim.snapshot_save!(NStore.dir(OTAG)) if !File.exist?(File.join(NStore.dir(RTAG), 'save_snapshot.rxdata'))
ENV['NSIM_SAVE'] = File.join(NStore.dir(RTAG), 'save_snapshot.rxdata') if File.exist?(File.join(NStore.dir(RTAG), 'save_snapshot.rxdata'))
NativeSim.boot!
RAT = File.readlines(File.join(NStore.dir(RTAG), 'ratings.csv'))[1..].map { |l|
  f = l.chomp.split(','); { key: f[0], name: f[1], species: f[2], types: f[3], item: f[4],
                            roles: f[5].to_s.split(';'), games: f[8].to_i, wr: f[9].to_f,
                            kos: f[10].to_f, faint: f[11].to_f, coef: f[13].to_f } }
BY    = RAT.map { |r| [r[:key], r] }.to_h
OU    = NativeSim.pool(tier: TIER)
BASES = OU.map { |e| [e[:key], e[:bases]] }.to_h
ROLES = OU.map { |e| [e[:key], e[:roles].map(&:to_s)] }.to_h
TYPES = OU.map { |e| [e[:key], e[:types]] }.to_h
FileUtils.mkdir_p(NStore.dir(OTAG))
LOG = File.open(File.join(NStore.dir(OTAG), 'search.log'), 'wb')
def say(s); puts s; LOG.puts s; LOG.flush; end
def nm(k); k.map { |x| BY[x] ? BY[x][:name] : x }.join(', '); end
def legal?(t)
  b = t.flat_map { |k| BASES[k] || [] }
  t.uniq.length == 6 && b.uniq.length == b.length && t.all? { |k| BASES.key?(k) }
end

# ---------------------------------------------------------------- field ------
def smart_team(seed)
  refs = SidmodRandomOpp.build_team(:smart, TIER, seed)
  refs.map { |pk| NativeSim.all_pool.find { |e| e[:ref].equal?(pk) }[:key] }
end

chaos_rec = Hash.new { |h, k| h[k] = [0.0, 0] }
NStore.read_games(File.join(NStore.dir(RTAG), 'games.tsv')).each do |g|
  pa = g[:winner] == :a ? 1.0 : (g[:winner] == :b ? 0.0 : 0.5)
  chaos_rec[g[:team_a]][0] += pa;       chaos_rec[g[:team_a]][1] += 1
  chaos_rec[g[:team_b]][0] += (1 - pa); chaos_rec[g[:team_b]][1] += 1
end
ranked_chaos = chaos_rec.select { |_k, v| v[1] >= 12 }.sort_by { |_k, v| -v[0] / v[1] }.map(&:first)

def build(list, balanced:, type_cap: 2, exclude: [], rng: nil, jitter: 0)
  chosen = []; used = []; tc = Hash.new(0)
  sl = list.reject { |r| exclude.include?(r[:key]) }
  sl = sl.sort_by { |r| -(r[:coef] + (rng ? (rng.rand - 0.5) * jitter : 0)) } if jitter > 0
  (balanced ? %w[hazard wall pivot] : []).each do |role|
    c = sl.find { |r| !chosen.include?(r[:key]) && (BASES[r[:key]] & used).empty? &&
                      ROLES[r[:key]].to_a.include?(role) }
    next if !c
    chosen << c[:key]; used.concat(BASES[c[:key]]); TYPES[c[:key]].each { |t| tc[t] += 1 }
  end
  sl.each do |r|
    break if chosen.length == 6
    next if chosen.include?(r[:key]) || (BASES[r[:key]] & used).any?
    next if balanced && TYPES[r[:key]].any? { |t| tc[t] >= type_cap }
    chosen << r[:key]; used.concat(BASES[r[:key]]); TYPES[r[:key]].each { |t| tc[t] += 1 }
  end
  chosen.length == 6 ? chosen : nil
end

# the literal token WONDERGUARD expands to every Wonder Guard mon in the pool, so
# the ban survives box/slot changes instead of hard-coding a key
if BAN.delete('WONDERGUARD')
  BAN.concat(OU.select { |e| (e[:ref].ability&.id rescue nil) == :WONDERGUARD }.map { |e| e[:key] })
end

SL = RAT.select { |r| BASES.key?(r[:key]) && r[:games] >= 100 && !BAN.include?(r[:key]) }
        .sort_by { |r| -r[:coef] }
SL_KO = RAT.select { |r| BASES.key?(r[:key]) && r[:games] >= 100 && !BAN.include?(r[:key]) }
          .sort_by { |r| -r[:kos] }
say "BAN: #{BAN.empty? ? '(none)' : BAN.map { |k| BY[k] ? BY[k][:name] : k }.join(', ')}" if defined?(say)

strata = { 'smart' => (0...6).map { |i| smart_team(7000 + i * 53) },
           'chaosTop' => ranked_chaos.first(3).map { |k| k.split(',') },
           'chaosMid' => ranked_chaos[(ranked_chaos.length / 2), 3].map { |k| k.split(',') },
           'chaosLow' => ranked_chaos.last(3).map { |k| k.split(',') },
           'built' => [build(SL, balanced: false), build(SL, balanced: true), build(SL_KO, balanced: false)] }
named = {}
OU.group_by { |e| e[:name] }.each do |name, es|
  next if es.length < 6 || name.to_s.strip.length < 2 || name == '.'
  keys = es.sort_by { |e| [e[:box], e[:slot]] }.first(6).map { |e| e[:key] }
  named[name] = keys if legal?(keys)
end
strata['named'] = named.values.first(2)

TRAIN = []; TEST = []
strata.each do |sname, teams|
  teams.compact.each_with_index do |t, i|
    (i.even? ? TRAIN : TEST) << { name: "#{sname}#{i}", keys: t }
  end
end
say "FIELD: TRAIN #{TRAIN.length} / TEST #{TEST.length} (stratified: #{strata.map { |k, v| "#{k} #{v.compact.length}" }.join(', ')})"
TRAIN.each { |f| say "  TRAIN #{f[:name].ljust(10)} #{nm(f[:keys])}" }
TEST.each  { |f| say "  TEST  #{f[:name].ljust(10)} #{nm(f[:keys])}" }

# ------------------------------------------------------------ evaluation -----
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
  res = cands.map { { pts: 0.0, n: 0, per_field: Hash.new { |h, k| h[k] = [0.0, 0] } } }
  NStore.read_games(path).each do |g|
    m = g[:gid].match(/\Ac(\d+)_f(\d+)_s(\d+)_(A|B)\z/) or next
    ci, fi, side = m[1].to_i, m[2].to_i, m[4]
    sc = side == 'A' ? (g[:winner] == :a ? 1.0 : (g[:winner] == :b ? 0.0 : 0.5))
                     : (g[:winner] == :b ? 1.0 : (g[:winner] == :a ? 0.0 : 0.5))
    r = res[ci]; r[:pts] += sc; r[:n] += 1
    r[:per_field][fi][0] += sc; r[:per_field][fi][1] += 1
  end
  res.each { |r| r[:wr] = r[:n] > 0 ? r[:pts] / r[:n] : 0.0 }
  res
end

# ------------------------------------------------------------- population ----
rng = Random.new(20260725)
pop = []
pop << build(SL, balanced: false)
pop << build(SL, balanced: true)
pop << build(SL_KO, balanced: false)
pop << build(SL_KO, balanced: true)
pop << build(SL, balanced: true, type_cap: 1)
pop += ranked_chaos.first(3).map { |k| k.split(',') }
pop += named.values.first(2)
pop = pop.compact.uniq.reject { |t| (t & BAN).any? }    # banned mons never enter a candidate
while pop.length < POP
  t = build(SL.first(60), balanced: rng.rand < 0.5, rng: rng, jitter: 0.9)
  pop << t if t && (t & BAN).empty? && !pop.include?(t)
end
pop = pop.first(POP)

def mutate(t, sl, rng)
  out = t.dup
  (rng.rand < 0.35 ? 2 : 1).times do
    i = rng.rand(6)
    cand = sl[rng.rand(sl.length)][:key]
    nt = out.dup; nt[i] = cand
    out = nt if legal?(nt)
  end
  out
end

def cross(a, b, rng)
  t = a.first(3) + b.last(3)
  return nil if !legal?(t)
  t
end

best = nil; best_wr = -1
GENS.times do |gen|
  seeds = ((gen * 10 + 1)..(gen * 10 + SEEDS)).to_a
  res = eval_batch("#{OTAG}/g#{gen + 1}", pop, TRAIN, seeds, NW)
  ranked = (0...pop.length).sort_by { |i| -res[i][:wr] }
  say "\n--- gen #{gen + 1} (#{pop.length} teams x #{TRAIN.length} field x #{SEEDS} seeds x2 = #{pop.length * TRAIN.length * SEEDS * 2} games)"
  ranked.first(5).each { |i| say "   %.3f  %s" % [res[i][:wr], nm(pop[i])] }
  if res[ranked.first][:wr] > best_wr
    best_wr = res[ranked.first][:wr]; best = pop[ranked.first]
  end
  elites = ranked.first(ELITE).map { |i| pop[i] }
  nxt = elites.dup
  while nxt.length < POP
    if rng.rand < 0.3
      c = cross(elites[rng.rand(ELITE)], elites[rng.rand(ELITE)], rng)
    else
      c = mutate(elites[rng.rand(ELITE)], SL.first(70), rng)
    end
    nxt << c if c && !nxt.include?(c)
  end
  pop = nxt
end

# ---------------------------------------------------------------- verify -----
say "\n=== VERIFY on fresh seeds: TRAIN vs held-out TEST ==="
finalists = ([best] + pop.first(5)).compact.uniq.first(6)
vs = (500..(500 + 11)).to_a
rtr = eval_batch("#{OTAG}/vtrain", finalists, TRAIN, vs, NW)
rte = eval_batch("#{OTAG}/vtest",  finalists, TEST,  vs, NW)
tab = (0...finalists.length).map { |i| [i, rtr[i][:wr], rte[i][:wr], (rtr[i][:wr] + rte[i][:wr]) / 2] }
                            .sort_by { |x| -x[3] }
tab.each { |i, a, b, c| say "  TRAIN %.3f  TEST %.3f  overall %.3f   %s" % [a, b, c, nm(finalists[i])] }
champ = finalists[tab.first[0]]
say "\n=== CHAMPION (best on TRAIN+TEST combined) ==="
say NativeSim.show_team(champ)

# --------------------------------------------------- leave-one-out per slot --
say "\n=== PER-SLOT MARGINAL VALUE (swap each slot vs top rated alternatives) ==="
alts = SL.first(24).map { |r| r[:key] }
loo_jobs = []
variants = []
champ.each_index do |i|
  alts.each do |k|
    next if champ.include?(k)
    t = champ.dup; t[i] = k
    next if !legal?(t)
    variants << { slot: i, key: k, keys: t }
  end
end
say "  #{variants.length} single-slot variants x #{TRAIN.length + TEST.length} field x 4 seeds x2"
allfield = TRAIN + TEST
rv = eval_batch("#{OTAG}/loo", [champ] + variants.map { |v| v[:keys] }, allfield, (900..903).to_a, NW)
base = rv[0][:wr]
say "  champion baseline wr = %.3f" % base
byslot = {}
variants.each_with_index { |v, i| (byslot[v[:slot]] ||= []) << [v[:key], rv[i + 1][:wr]] }
byslot.sort.each do |slot, list|
  cur = champ[slot]
  say "  slot #{slot + 1} (currently #{BY[cur] ? BY[cur][:name] : cur}):"
  list.sort_by { |_k, wr| -wr }.first(3).each { |k, wr|
    say "      %+.3f  %-14s %s" % [wr - base, BY[k][:name], BY[k][:species]] }
  say "      (worst alternative %+.3f)" % (list.min_by { |_k, wr| wr }[1] - base)
end

NStore.write_json(OTAG, 'champion.json',
                  'keys' => champ, 'names' => champ.map { |k| BY[k][:name] },
                  'species' => champ.map { |k| BY[k][:species] },
                  'train_wr' => tab.first[1], 'test_wr' => tab.first[2],
                  'field_train' => TRAIN.map { |f| f[:name] }, 'field_test' => TEST.map { |f| f[:name] },
                  'tier' => TIER.to_s, 'gens' => GENS, 'pop' => POP, 'seeds' => SEEDS, 'rating_tag' => RTAG)
say "\nartifacts -> #{NStore.dir(OTAG)}"
LOG.close
