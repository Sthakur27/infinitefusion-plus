# REVOLVING LADDER / king-of-the-hill team search.
#
#   ruby tools/sidmod_editor/sim/nladder.rb init  <rating_tag> <ladder_tag> [size] [seed_opps] [workers]
#   ruby tools/sidmod_editor/sim/nladder.rb run   <ladder_tag> <batches> [per_batch] [workers]
#   ruby tools/sidmod_editor/sim/nladder.rb show  <ladder_tag> [n]
#   (TIER=ou|ubers, set at init and remembered in the ladder state)
#
# HOW IT WORKS
#   * The ladder holds a FIXED number of teams (default 100), each with an Elo.
#   * A challenger plays a random subset of the ladder in stages with EARLY EXIT:
#     8 games, then 24, then 52 against a top-biased sample. Cheap culls happen fast.
#   * It is judged on PERFORMANCE RATING (score adjusted for the Elo of the opponents
#     it actually drew), so sampling a subset is statistically sound, not a shortcut.
#   * Promotion requires clearing the BAR = the ladder's median Elo. A promotion evicts
#     the weakest team, so the median — and therefore the bar — rises on its own.
#   * Challengers come from: pure random, archetype builders, mutation of a ladder
#     winner, or crossover of two winners. Every generated team gets its lead chosen
#     by the Lead heuristic before it plays.
#   * Challengers are evaluated in parallel batches (the ladder is one batch stale;
#     that costs a little precision and buys ~14x throughput).
require_relative 'nstore'
require_relative 'nrun'
require_relative 'nbattle'
require_relative 'nlead'
require_relative 'narchetype'
require_relative 'nniche'
require_relative 'tiers'
require 'fileutils'
require 'etc'

CMD = ARGV[0]

def dir_for(tag); NStore.dir(tag); end
def state_path(tag); File.join(dir_for(tag), 'ladder.json'); end
def load_state(tag); NStore::PARSE.call(File.binread(state_path(tag))); end
def save_state(tag, st); File.binwrite(state_path(tag), NStore::GEN.call(st)); end

def meta_for(keys_list)
  keys_list.each_with_object({}) do |e, h|
    d = NativeSim.describe(e[:key])
    h[e[:key]] = { moves: d[:moves], ability: d[:ability], item: d[:item], types: d[:types],
                   stats: d[:stats], roles: d[:roles].split(','), bases: e[:bases].map(&:to_s),
                   name: d[:name], species: d[:species] }
  end
end

def ratings_for(rtag)
  path = File.join(NStore.dir(rtag), 'ratings.csv')
  return {} unless File.exist?(path)
  File.readlines(path)[1..].each_with_object({}) do |l, h|
    f = l.chomp.split(',')
    h[f[0]] = { wr: f[9].to_f, kos: f[10].to_f, games: f[8].to_i, coef: f[13].to_f }
  end
end

# A team's rating should move fast while it is provisional and slowly once it has a
# real sample, otherwise a lucky entrant squats at an inflated Elo forever (observed:
# the "median" team measured weaker than the "worst" team in an independent test).
def k_for(t); t['games'].to_i < 90 ? 16.0 : 6.0; end

def elo_update!(teams_by_id, rows, k: nil)
  rows.each do |cid, opp_id, score|
    a = teams_by_id[cid]; b = teams_by_id[opp_id]
    next if !a || !b
    exp = 1.0 / (1.0 + 10**((b['elo'] - a['elo']) / 400.0))
    ka = k || k_for(a); kb = k || k_for(b)
    a['elo'] += ka * (score - exp)
    b['elo'] -= kb * (score - exp)
    a['games'] = a['games'].to_i + 1
    b['games'] = b['games'].to_i + 1
  end
end

# DIVERSITY PRESSURE. Unchecked, king-of-the-hill plus genetic operators collapses
# into a monoculture: after 560 challengers nearly every surviving team carried the
# same three mons. A ladder of near-identical teams stops being a real gauntlet, and
# the search can no longer discover anything that beats a DIFFERENT plan.
#   * USAGE CAP — no mon may appear on more than `cap` fraction of the ladder.
#   * CROWDING EVICTION — a promotion evicts the most SIMILAR weak team rather than
#     the globally weakest, so distinct archetypes survive even when mid-rated.
def usage_of(st)
  u = Hash.new(0)
  st['teams'].each { |t| t['keys'].each { |k| u[k] += 1 } }
  u
end

# SPECIATION. A rain team that must out-rate the globally best team dies before its
# plan is ever refined, which is why archetypes vanished. Instead every niche gets
# RESERVED CAPACITY and competes internally: a rain challenger takes a rain slot from
# the weakest rain team. Under-filled niches may enter below the global bar (down to
# NICHE_HANDICAP) so a plan gets room to develop; over-filled niches must fight
# themselves, which caps any single plan's share of the ladder.
NICHE_HANDICAP = 130.0

def niche_of(t, meta)
  t['niche'] ||= Niche.classify(t['keys'], meta)
end

def niche_counts(st, meta)
  c = Hash.new(0)
  st['teams'].each { |t| c[niche_of(t, meta)] += 1 }
  c
end

def niche_reserve(st)
  # every niche that the pool can actually support gets a floor; the rest is open
  [(st['size'].to_i * 0.06).floor, 4].max
end

def niche_bar(st, meta, n, global_bar)
  peers = st['teams'].select { |t| niche_of(t, meta) == n }
  return global_bar - NICHE_HANDICAP if peers.length < niche_reserve(st)
  med = peers.map { |t| t['elo'] }.sort[peers.length / 2]
  [med, global_bar - NICHE_HANDICAP].max
end

# Which team should make way for `keys` (already classified as niche `n`)?
def choose_eviction_niched(st, keys, n, meta, cap_n)
  counts = niche_counts(st, meta)
  reserve = niche_reserve(st)
  peers = st['teams'].select { |t| niche_of(t, meta) == n }
  if counts[n] >= reserve
    # the niche is at or above its floor -> it competes with ITSELF
    victim = peers.min_by { |t| t['elo'] }
  else
    # under-represented plan: take a slot from the most over-subscribed niche
    fattest = counts.select { |k, v| v > reserve && k != n }.max_by { |_k, v| v }
    pool = fattest ? st['teams'].select { |t| niche_of(t, meta) == fattest[0] } : st['teams']
    victim = pool.min_by { |t| t['elo'] }
  end
  return nil if !victim
  # usage cap still applies on top of niching (simulated, see below)
  usage = usage_of(st)
  post = usage.dup
  victim['keys'].each { |k| post[k] = post[k].to_i - 1 }
  keys.each { |k| post[k] = post[k].to_i + 1 }
  if keys.any? { |k| post[k] > cap_n }
    over = keys.select { |k| usage[k] + 1 > cap_n }
    alt = (peers + st['teams']).select { |t| (t['keys'] & over).any? }
                               .min_by { |t| t['elo'] }
    return nil if !alt
    post2 = usage.dup
    alt['keys'].each { |k| post2[k] = post2[k].to_i - 1 }
    keys.each { |k| post2[k] = post2[k].to_i + 1 }
    return nil if keys.any? { |k| post2[k] > cap_n }
    return alt
  end
  victim
end

def choose_eviction(st, keys, cap_n)
  usage = usage_of(st)
  # `usage[k] + 1` because the challenger itself is about to add one. Evicting a
  # holder frees a slot the challenger immediately refills, so the swap must be
  # SIMULATED and verified — checking pre-state usage let counts creep past the cap
  # (observed: max use 41 against a cap of 30).
  over = keys.select { |k| usage[k] + 1 > cap_n }
  cands = if over.any?
            st['teams'].select { |t| (t['keys'] & over).any? }
          else
            st['teams'].sort_by { |t| t['elo'] }.first([st['teams'].length / 4, 1].max)
          end
  return nil if cands.empty?
  # prefer the eviction that relieves the most cap pressure, then the most similar
  # (crowding), then the weakest
  best = cands.max_by { |t| [(t['keys'] & over).length, (t['keys'] & keys).length, -t['elo']] }
  post = usage.dup
  best['keys'].each { |k| post[k] = post[k].to_i - 1 }
  keys.each { |k| post[k] = post[k].to_i + 1 }
  return nil if keys.any? { |k| post[k] > cap_n }    # infeasible -> reject the promotion
  best
end

def diversity_line(st)
  u = usage_of(st).sort_by { |_k, v| -v }
  distinct = u.length
  top = u.first(3).map { |k, v| "#{k}:#{v}" }.join(' ')
  [distinct, u.first ? u.first[1] : 0, top]
end

def bar_of(st)
  elos = st['teams'].map { |t| t['elo'] }.sort
  pct = st['bar_percentile'] || 50
  elos[[(elos.length * pct / 100.0).floor, elos.length - 1].min]
end

# ---- bans / clauses --------------------------------------------------------
# Unified ban computation for research runs. Standard competitive clauses (uncompetitive
# abilities + moves) apply unless CLAUSES=off; experimental bans layer on via env:
#   BAN_SPECIES=MAROWAK,AZUMARILL   ban any fusion containing these base species
#   BAN_ABILITY=HUGEPOWER,...        ban mons whose (built) ability is listed
#   BAN_ITEM=THICKCLUB,...           ban mons holding these items
#   BAN=b12s3,...                    ban explicit pool keys
# Applied ONLY in the ladder (not the shared RandomOpponent pool), so in-game random
# battles are unaffected. Returns { key => reason }.
CLAUSE_ABILITIES = %i[WONDERGUARD MOODY SHADOWTAG ARENATRAP]
CLAUSE_MOVES     = %i[SPORE BATONPASS SWAGGER FISSURE SHEERCOLD HORNDRILL GUILLOTINE]
def compute_bans
  clauses     = (ENV['CLAUSES'] != 'off')
  # TIER_DEF=ou|uu|ubers pulls an EXPLICIT banlist from tiers.json (canonical fusion ids).
  # Preferred over the rule-based env bans below for a closed, enumerable pool.
  tier_def    = ENV['TIER_DEF']
  ban_species = (ENV['BAN_SPECIES'] || '').split(',').map { |s| s.strip.upcase.to_sym }.reject { |s| s.empty? }
  ban_ability = (ENV['BAN_ABILITY'] || '').split(',').map { |s| s.strip.upcase.to_sym }.reject { |s| s.empty? }
  ban_item    = (ENV['BAN_ITEM'] || '').split(',').map { |s| s.strip.upcase.to_sym }.reject { |s| s.empty? }
  ban_keys    = (ENV['BAN'] || '').split(',').map(&:strip).reject(&:empty?)
  abilities   = ban_ability + (clauses ? CLAUSE_ABILITIES : [])
  moves       = clauses ? CLAUSE_MOVES : []
  reasons = {}
  if tier_def
    bad = Tiers.validate
    raise "tiers.json invalid:\n  #{bad.join("\n  ")}" unless bad.empty?
    # ag/ubers play the whole pool (legendaries included); ou/uu use the OU-legal subset
    tpool = %w[ag ubers].include?(tier_def) ? NativeSim.all_pool : NativeSim.pool(tier: :ou)
    # exclude anything whose HOME tier sits above the tier being played
    Tiers.excluded_keys(tier_def, tpool).each { |k, home| reasons[k] = "tier:#{home}" }
  end
  NativeSim.all_pool.each do |e|
    ab = (e[:ref].ability&.id rescue nil)
    bases = (e[:bases] || []).map { |b| b.to_s.upcase.to_sym }
    r = nil
    r ||= 'key'                   if ban_keys.include?(e[:key])
    r ||= 'species'               if (bases & ban_species).any?
    r ||= "ability:#{ab}"         if abilities.include?(ab)
    r ||= "item:#{e[:item]}"      if ban_item.include?(e[:item])
    r ||= 'move-clause'           if ((e[:moves] || []) & moves).any?
    reasons[e[:key]] = r if r
  end
  reasons
end

# --------------------------------------------------------------------- init ---
def init!(rtag, tag, size, seed_opps, nw)
  tier = (ENV['TIER'] || 'ou').to_sym
  d = NStore.init(tag)
  # freeze the save for the whole ladder's life: keys must stay valid across batches
  snap_src = File.join(NStore.dir(rtag), 'save_snapshot.rxdata')
  if File.exist?(snap_src)
    FileUtils.cp(snap_src, File.join(d, 'save_snapshot.rxdata')) unless
      File.exist?(File.join(d, 'save_snapshot.rxdata'))
    ENV['NSIM_SAVE'] = File.join(d, 'save_snapshot.rxdata')
  else
    NativeSim.snapshot_save!(d)
  end
  NativeSim.boot!
  pool = NativeSim.pool(tier: tier)
  meta = meta_for(NativeSim.all_pool)
  rat  = ratings_for(rtag)
  NStore.write_pool(tag, NativeSim.all_pool)
  lead_stats = Lead.stats_from_games(Dir[File.join(File.dirname(dir_for(tag)), '**', 'games.tsv')])
  legal_keys = pool.map { |e| e[:key] }
  ban_reasons = compute_bans
  banned = ban_reasons.keys
  legal_keys -= banned
  unless banned.empty?
    by_reason = ban_reasons.values.tally.sort_by { |_r, n| -n }.map { |r, n| "#{r}:#{n}" }.join(' ')
    puts "  banned #{banned.size} from ladder — #{by_reason}"
    st_bans = { 'clauses' => (ENV['CLAUSES'] != 'off'), 'ban_species' => ENV['BAN_SPECIES'],
                'ban_ability' => ENV['BAN_ABILITY'], 'ban_item' => ENV['BAN_ITEM'], 'count' => banned.size }
    @ban_meta = st_bans
  end
  gen = Gen.new(meta, rat, legal_keys)
  rng = Random.new(777)

  teams = []
  ok = ->(keys) { keys.is_a?(Array) && keys.length == 6 && keys.all? { |k| legal_keys.include?(k) } }
  add = lambda do |keys, source|
    return if !ok.(keys)          # wrong tier (e.g. an Ubers champion in an OU ladder) or banned
    ordered, reason = Lead.choose(keys, meta, lead_stats)
    return if teams.any? { |t| t['keys'].sort == ordered.sort }
    teams << { 'id' => "L#{teams.length}", 'keys' => ordered, 'source' => source,
               'lead_reason' => reason, 'elo' => 1500.0, 'games' => 0, 'born' => 0 }
  end

  # a deliberately mixed starting field: the generators, every archetype, prior
  # champions, and the rating-greedy builds
  8.times { |i| add.(NativeSim.all_pool.then { SidmodRandomOpp.build_team(:smart, tier, 90_000 + i) }
                       &.map { |pk| NativeSim.all_pool.find { |e| e[:ref].equal?(pk) }[:key] }, 'smart') }
  Gen::ARCHETYPES.each { |a| 3.times { add.(gen.archetype(a, rng), "arch:#{a}") } }
  Dir[File.join(File.dirname(dir_for(tag)), '*', 'champion.json')].sort.each do |f|
    c = NStore::PARSE.call(File.binread(f))
    add.(c['keys'], "champ:#{File.basename(File.dirname(f))}")   # `ok` rejects wrong-tier imports
  end
  add.(gen.shortlist.first(12).then { |sl| gen.fill([], sl) }, 'built:coef')
  while teams.length < size
    add.(gen.random(rng), 'random')
  end
  teams = teams.first(size)

  st = { 'tag' => tag, 'rating_tag' => rtag, 'tier' => tier.to_s, 'size' => size,
         'bar_percentile' => 50, 'batch' => 0, 'tested' => 0, 'promoted' => 0,
         'teams' => teams, 'history' => [], 'created' => Time.now.to_s,
         'banned_keys' => banned, 'ban_meta' => @ban_meta }
  save_state(tag, st)
  puts "ladder #{tag}: #{teams.length} seed teams (tier #{tier})"
  puts "  sources: " + teams.group_by { |t| t['source'].split(':').first }.map { |k, v| "#{k} #{v.length}" }.join(', ')

  # seeding games so the initial Elo means something: each team plays `seed_opps`
  # random opponents, both side assignments
  jobs = []
  ids = teams.map { |t| t['id'] }
  by_id = teams.each_with_object({}) { |t, h| h[t['id']] = t }
  rng2 = Random.new(31337)
  teams.each do |t|
    others = ids.reject { |x| x == t['id'] }.shuffle(random: rng2).first(seed_opps)
    others.each do |o|
      jobs << ["#{t['id']}v#{o}s1A", t['keys'], by_id[o]['keys'], 1]
      jobs << ["#{o}v#{t['id']}s1B", by_id[o]['keys'], t['keys'], 1]
    end
  end
  puts "seeding: #{jobs.length} games"
  path = NRun.execute(tag, jobs, nw)
  rows = []
  NStore.read_games(path).each do |g|
    m = g[:gid].match(/\A(L\d+)v(L\d+)s(\d+)(A|B)\z/) or next
    sc = g[:winner] == :a ? 1.0 : (g[:winner] == :b ? 0.0 : 0.5)
    rows << [m[1], m[2], sc]
    by_id[m[1]]['games'] += 1 if by_id[m[1]]
    by_id[m[2]]['games'] += 1 if by_id[m[2]]
  end
  4.times { elo_update!(by_id, rows, k: 12.0) }   # a few passes to converge initial Elo
  st['teams'] = teams
  save_state(tag, st)
  show(tag, 12)
  puts "\nbar (median Elo) = %.0f" % bar_of(st)
end

# ---------------------------------------------------------------------- run ---
def run!(tag, batches, per_batch, nw)
  st = load_state(tag)
  ENV['NSIM_SAVE'] = File.join(dir_for(tag), 'save_snapshot.rxdata')
  NativeSim.boot!
  tier = st['tier'].to_sym
  meta = meta_for(NativeSim.all_pool)
  rat  = ratings_for(st['rating_tag'])
  pool = NativeSim.pool(tier: tier).map { |e| e[:key] }
  # use the ladder's init-time ban set (snapshot-stable keys) so run bans == init bans
  banned = st['banned_keys'] || compute_bans.keys
  pool -= banned
  gen  = Gen.new(meta, rat, pool)
  lead_stats = Lead.stats_from_games(Dir[File.join(File.dirname(dir_for(tag)), '**', 'games.tsv')])
  rng  = Random.new(4242 + st['batch'].to_i * 17)
  logf = File.open(File.join(dir_for(tag), 'ladder_log.txt'), 'ab')
  promf = File.join(dir_for(tag), 'promotions.tsv')

  shrink = 0.55        # fraction of (perf - bar) an entrant keeps
  cap_n  = ((ENV['USAGE_CAP'] || 0.30).to_f * st['teams'].length).ceil   # max teams per mon
  maint  = (ENV['MAINT'] || 90).to_i   # incumbent re-test games per batch
  stages = [{ 'opps' => 4,  'seeds' => 1, 'cull' => 0.25, 'top_bias' => 0.0 },
            { 'opps' => 8,  'seeds' => 1, 'cull' => 0.40, 'top_bias' => 0.3 },
            { 'opps' => 14, 'seeds' => 1, 'cull' => nil,  'top_bias' => 0.7 }]

  batches.times do |bi|
    st['batch'] = st['batch'].to_i + 1
    bar = bar_of(st)
    ranked = st['teams'].sort_by { |t| -t['elo'] }
    # ---- build this batch of challengers
    chs = []
    seen = st['teams'].map { |t| t['keys'].sort }
    tries = 0
    while chs.length < per_batch && tries < per_batch * 25
      tries += 1
      # Bias generation toward niches that are SHORT of their reserve, so the search
      # actively develops rain/sand/trickroom/stall instead of only refining whatever
      # plan currently happens to be winning.
      counts = niche_counts(st, meta)
      reserve = niche_reserve(st)
      hungry = (Niche::LIST - ['generic']).select { |x| counts[x] < reserve }
      roll = rng.rand
      keys, src =
        if hungry.any? && roll < 0.45
          want = hungry[rng.rand(hungry.length)]
          builder = { 'rain' => 'rain', 'sun' => 'sun', 'sand' => 'sand', 'hail' => 'sand',
                      'trickroom' => 'trickroom', 'stall' => 'balance', 'hazardstack' => 'hazardstack',
                      'priority' => 'priority', 'scarf' => 'scarf', 'balance' => 'balance',
                      'hyperoffense' => 'hyperoffense' }[want] || 'balance'
          [gen.archetype(builder, rng), "arch:#{builder}->#{want}"]
        elsif roll < 0.60
          [gen.random(rng), 'random']
        elsif roll < 0.70
          a = Gen::ARCHETYPES[rng.rand(Gen::ARCHETYPES.length)]
          [gen.archetype(a, rng), "arch:#{a}"]
        elsif roll < 0.92
          # mutate WITHIN the parent's niche: the slots that define its plan are protected
          parent = ranked[rng.rand([ranked.length / 3, 1].max)]
          prot = Niche.core(parent['keys'], meta)
          [gen.mutate_protecting(parent['keys'], prot, rng), "mut:#{parent['id']}"]
        else
          # crossover prefers same-niche parents so the child inherits a coherent plan
          a = ranked[rng.rand([ranked.length / 3, 1].max)]
          an = niche_of(a, meta)
          same = st['teams'].select { |t| niche_of(t, meta) == an && t['id'] != a['id'] }
          b = same.any? ? same[rng.rand(same.length)] : ranked[rng.rand([ranked.length / 2, 1].max)]
          [gen.crossover_protecting(a['keys'], b['keys'], Niche.core(a['keys'], meta), rng),
           "cross:#{a['id']}x#{b['id']}"]
        end
      next if !keys || (keys & banned).any? || keys.any? { |k| !pool.include?(k) }
      ordered, reason = Lead.choose(keys, meta, lead_stats)
      next if seen.include?(ordered.sort) || chs.any? { |c| c[:keys].sort == ordered.sort }
      chs << { cid: "C#{st['batch']}_#{chs.length}", keys: ordered, source: src, lead_reason: reason }
    end
    break if chs.empty?

    # ---- fan out: each worker gets a slice of challengers, boots once
    wdir = File.join(dir_for(tag), 'wl'); FileUtils.mkdir_p(wdir)
    nwork = [[nw, chs.length].min, 1].max
    slices = Array.new(nwork) { [] }
    chs.each_with_index { |c, i| slices[i % nwork] << c }
    pids = {}
    slices.each_with_index do |slice, wi|
      next if slice.empty?
      jf = File.join(wdir, "job_#{st['batch']}_#{wi}.json")
      op = File.join(wdir, "out_#{st['batch']}_#{wi}")
      File.binwrite(jf, NStore::GEN.call(
        'ladder' => st['teams'].map { |t| { 'id' => t['id'], 'keys' => t['keys'], 'elo' => t['elo'] } },
        'challengers' => slice.map { |c| { 'cid' => c[:cid], 'keys' => c[:keys] } },
        'stages' => stages, 'bar' => bar, 'rng' => 1000 + wi))
      lf = File.join(wdir, "w_#{st['batch']}_#{wi}.log")
      pids[Process.spawn(NRun::RB, File.join(__dir__, 'nladder_worker.rb'), jf, op,
                         chdir: NRun::GAMEROOT, %i[out err] => lf)] = [op, lf]
    end
    outs = []
    until pids.empty?
      pid, _stt = Process.wait2
      op, lf = pids.delete(pid)
      outs << [op, lf]
    end

    # ---- collect verdicts
    verdicts = {}
    game_rows = []
    outs.each do |op, lf|
      if !File.exist?("#{op}.res")
        puts "  worker failed -> #{lf}"
        next
      end
      File.foreach("#{op}.res") do |line|
        cid, verdict, n, pts, pe, stage = line.chomp.split("\t")
        verdicts[cid] = { verdict: verdict, games: n.to_i, pts: pts.to_f, perf: pe.to_f, stage: stage.to_i }
      end
      File.foreach("#{op}.games") do |line|
        cid, opp, _seed, _side, sc = line.chomp.split("\t")
        game_rows << [cid, opp, sc.to_f]
      end if File.exist?("#{op}.games")
    end

    # ---- apply: promotions (best first), each evicting the weakest team
    by_id = st['teams'].each_with_object({}) { |t, h| h[t['id']] = t }
    promoted = []
    chs.sort_by { |c| -(verdicts[c[:cid]] ? verdicts[c[:cid]][:perf] : -9999) }.each do |c|
      v = verdicts[c[:cid]] or next
      st['tested'] = st['tested'].to_i + 1
      next if v[:verdict] != 'promote'
      weakest = choose_eviction(st, c[:keys], cap_n)
      next if !weakest                                # usage cap blocks this promotion
      next if v[:perf] <= weakest['elo']              # cannot be worse than who it replaces
      st['teams'].delete(weakest)
      nid = "P#{st['batch']}_#{promoted.length}"
      # WINNER'S CURSE: a challenger is promoted *because* its sample looked good, so
      # its raw performance rating is biased upward. Shrink it toward the bar; the
      # maintenance games below then move it to where it really belongs.
      entry = bar + shrink * (v[:perf] - bar)
      st['teams'] << { 'id' => nid, 'keys' => c[:keys], 'source' => c[:source],
                       'lead_reason' => c[:lead_reason], 'elo' => entry,
                       'perf_raw' => v[:perf], 'games' => v[:games], 'born' => st['batch'] }
      promoted << [nid, c, v, weakest]
      st['promoted'] = st['promoted'].to_i + 1
      File.open(promf, 'ab') { |f|
        f.write("#{st['batch']}\t#{nid}\t#{c[:source]}\t#{'%.1f' % v[:perf]}\t#{v[:games]}\t" \
                "#{'%.3f' % (v[:pts] / [v[:games], 1].max)}\t#{weakest['id']}\t#{'%.1f' % weakest['elo']}\t" \
                "#{c[:keys].map { |k| meta[k][:name] }.join(' ')}\t#{c[:lead_reason]}\n") }
    end
    # ladder members' Elo moves from the games they actually played
    by_id = st['teams'].each_with_object({}) { |t, h| h[t['id']] = t }
    promoted.each { |nid, c, _v, _w| by_id[nid] ||= st['teams'].find { |t| t['id'] == nid } }
    cid_to_new = promoted.each_with_object({}) { |(nid, c, _v, _w), h| h[c[:cid]] = nid }
    elo_update!(by_id, game_rows.map { |cid, opp, sc| [cid_to_new[cid] || cid, opp, sc] }, k: 6.0)

    # ---- maintenance: re-test incumbents so nobody squats on a stale rating.
    # Pairs are drawn preferring the least-played teams and neighbours in the table
    # (neighbour games are the informative ones for ordering).
    if maint > 0 && st['teams'].length > 3
      order = st['teams'].sort_by { |t| -t['elo'] }
      stale = st['teams'].sort_by { |t| t['games'].to_i }
      mjobs = []
      (maint / 2).times do |i|
        a = stale[i % [stale.length, 12].min]
        ai = order.index(a)
        span = 6
        lo = [ai - span, 0].max; hi = [ai + span, order.length - 1].min
        b = order[lo + rng.rand(hi - lo + 1)]
        next if !a || !b || a['id'] == b['id']
        mjobs << ["#{a['id']}v#{b['id']}s#{i}A", a['keys'], b['keys'], 1 + i % 5]
        mjobs << ["#{b['id']}v#{a['id']}s#{i}B", b['keys'], a['keys'], 1 + i % 5]
      end
      unless mjobs.empty?
        mpath = NRun.execute("#{tag}/maint#{st['batch']}", mjobs, nw, quiet: true)
        mrows = []
        NStore.read_games(mpath).each do |g|
          m = g[:gid].match(/\A(\w+)v(\w+)s(\d+)(A|B)\z/) or next
          sc = g[:winner] == :a ? 1.0 : (g[:winner] == :b ? 0.0 : 0.5)
          mrows << [m[1], m[2], sc]
        end
        by_id2 = st['teams'].each_with_object({}) { |t, h| h[t['id']] = t }
        elo_update!(by_id2, mrows)
      end
    end

    culled = verdicts.count { |_k, v| v[:verdict] != 'promote' }
    fast = verdicts.count { |_k, v| v[:stage] == 1 }
    avg_games = verdicts.empty? ? 0 : verdicts.values.sum { |v| v[:games] } / verdicts.length.to_f
    newbar = bar_of(st)
    dist, maxuse, topuse = diversity_line(st)
    nc = niche_counts(st, meta).sort_by { |_k, v| -v }
    niche_str = nc.reject { |_k, v| v.zero? }.map { |k, v| "#{k} #{v}" }.join(', ')
    line = "batch %d: %d challengers, %d promoted, %d culled (%d at stage 1) | avg %.1f games | "            "bar %.0f -> %.0f | top %.0f | diversity: %d distinct mons, max use %d/%d (%s)" %
           [st['batch'], chs.length, promoted.length, culled, fast, avg_games, bar, newbar,
            st['teams'].map { |t| t['elo'] }.max, dist, maxuse, cap_n, topuse]
    puts line; logf.puts line
    nline = "    niches: #{niche_str}"
    puts nline; logf.puts nline; logf.flush
    promoted.first(4).each { |nid, c, v, w|
      l = "    + %-10s %-14s perf %.0f (%.3f over %d) evicted %s | %s | lead: %s" %
          [nid, c[:source], v[:perf], v[:pts] / [v[:games], 1].max, v[:games], w['id'],
           c[:keys].map { |k| meta[k][:name] }.join(', '), c[:lead_reason]]
      puts l; logf.puts l }
    st['history'] << { 'batch' => st['batch'], 'bar' => newbar, 'tested' => st['tested'],
                       'promoted' => st['promoted'],
                       'top' => st['teams'].map { |t| t['elo'] }.max,
                       'median' => newbar }
    save_state(tag, st)
  end
  logf.close
  show(tag, 15)
end

# --------------------------------------------------------------------- show ---
def show(tag, n = 15)
  st = load_state(tag)
  pool = begin NStore.read_json(tag, 'pool.json') rescue {} end
  nm = ->(k) { (pool[k] && pool[k]['name']) || k }
  puts "\n=== LADDER #{tag} (tier #{st['tier']}) — batch #{st['batch']}, " \
       "#{st['tested']} challengers tested, #{st['promoted']} promoted ==="
  puts "bar (P#{st['bar_percentile']} Elo) = %.0f" % bar_of(st)
  puts "  %-4s %-6s %-16s %-5s %s" % %w[# elo source games roster]
  st['teams'].sort_by { |t| -t['elo'] }.first(n).each_with_index do |t, i|
    puts "  %-4d %-6.0f %-16s %-5d %s" % [i + 1, t['elo'], t['source'].to_s[0, 16], t['games'],
                                          t['keys'].map { |k| nm.(k) }.join(', ')[0, 58]]
  end
  if st['teams'].first && st['teams'].first['niche']
    puts "
  BY NICHE (count, mean Elo, best team):"
    st['teams'].group_by { |t| t['niche'] || 'generic' }
               .map { |k, v| [k, v.length, v.sum { |t| t['elo'] } / v.length, v.max_by { |t| t['elo'] }] }
               .sort_by { |x| -x[2] }
               .each { |k, c, e, bestt|
      puts "    %-13s %-3d %-6.0f %s" % [k, c, e, bestt['keys'].map { |x| nm.(x) }.join(', ')[0, 52]] }
  end
  src = st['teams'].group_by { |t| t['source'].split(':').first }
                   .map { |k, v| [k, v.length, v.sum { |t| t['elo'] } / v.length] }
                   .sort_by { |x| -x[2] }
  puts "\n  survivors by origin (count, mean Elo):"
  src.each { |k, c, e| puts "    %-12s %-4d %.0f" % [k, c, e] }
end

# -------------------------------------------------------------------- recal ---
# Re-rate every team on the ladder from scratch. Needed after changing the rating
# rules, or whenever ratings are suspected of drift: the team SET is kept (that is
# the search's real output) while the numbers attached to it are rebuilt from fresh
# games instead of from inherited entry ratings.
def recal!(tag, opps, nw)
  st = load_state(tag)
  ENV['NSIM_SAVE'] = File.join(dir_for(tag), 'save_snapshot.rxdata')
  NativeSim.boot!
  st['teams'].each { |t| t['elo'] = 1500.0; t['games'] = 0 }
  by_id = st['teams'].each_with_object({}) { |t, h| h[t['id']] = t }
  ids = st['teams'].map { |t| t['id'] }
  rng = Random.new(9001)
  jobs = []
  st['teams'].each do |t|
    ids.reject { |x| x == t['id'] }.shuffle(random: rng).first(opps).each do |o|
      jobs << ["#{t['id']}v#{o}s1A", t['keys'], by_id[o]['keys'], 1 + rng.rand(5)]
      jobs << ["#{o}v#{t['id']}s1B", by_id[o]['keys'], t['keys'], 1 + rng.rand(5)]
    end
  end
  puts "recalibrating #{st['teams'].length} teams on #{jobs.length} fresh games"
  path = NRun.execute("#{tag}/recal", jobs, nw)
  rows = []
  NStore.read_games(path).each do |g|
    m = g[:gid].match(/\A(\w+)v(\w+)s(\d+)(A|B)\z/) or next
    sc = g[:winner] == :a ? 1.0 : (g[:winner] == :b ? 0.0 : 0.5)
    rows << [m[1], m[2], sc]
  end
  6.times { |i| elo_update!(by_id, rows.shuffle(random: Random.new(i)), k: i < 3 ? 16.0 : 6.0) }
  st['teams'].each { |t| t['games'] = rows.count { |a, b, _| a == t['id'] || b == t['id'] } }
  save_state(tag, st)
  show(tag, 15)
  puts "\nbar (P#{st['bar_percentile']}) = %.0f" % bar_of(st)
end

case CMD
when 'recal' then recal!(ARGV[1] || 'ladder_ou', (ARGV[2] || 14).to_i, (ARGV[3] || NRun.workers).to_i)
when 'init' then init!(ARGV[1] || 'ou3', ARGV[2] || 'ladder_ou', (ARGV[3] || 100).to_i,
                       (ARGV[4] || 12).to_i, (ARGV[5] || NRun.workers).to_i)
when 'run'  then run!(ARGV[1] || 'ladder_ou', (ARGV[2] || 5).to_i, (ARGV[3] || 28).to_i,
                      (ARGV[4] || NRun.workers).to_i)
when 'show' then show(ARGV[1] || 'ladder_ou', (ARGV[2] || 15).to_i)
else puts "usage: nladder.rb init <rating_tag> <ladder_tag> [size] [seed_opps] [workers]\n" \
          "       nladder.rb run <ladder_tag> <batches> [per_batch] [workers]\n" \
          "       nladder.rb show <ladder_tag> [n]"
end
