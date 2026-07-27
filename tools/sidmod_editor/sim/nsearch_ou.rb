# PHASE 1 of the OU search: rate every OU-legal pool mon by playing thousands of
# random Species-Clause-legal teams against each other with the deterministic
# SmartTrainerAI on BOTH sides (no LLMs anywhere).
#
#   ruby tools/sidmod_editor/sim/nsearch_ou.rb sample <tag> [teams] [opp_per_team] [workers]
#   ruby tools/sidmod_editor/sim/nsearch_ou.rb rate   <tag>
#
# Why random teams: every mon gets a large number of appearances alongside random
# teammates, so a ridge-logistic fit on team composition (+1 side A, -1 side B)
# recovers each mon's own contribution instead of crediting its teammates.
require_relative 'nstore'      # captures stdlib JSON before the engine patches it
require_relative 'nrun'
require_relative 'nbattle'

CMD = ARGV[0]
TAG = ARGV[1] || 'ou1'
# TIER=ou (default) or TIER=ubers. Mirrors the in-game Random Battle tiers exactly:
# OU filters out non-allowlisted legendaries, Ubers applies no tier filter at all.
TIER = (ENV['TIER'] || 'ou').to_sym

def rand_team(ou, rng)
  chosen = []; used = []
  ou.shuffle(random: rng).each do |e|
    next if (e[:bases] & used).any?          # Species Clause (fusions: both bases)
    chosen << e[:key]; used.concat(e[:bases])
    break if chosen.length == 6
  end
  chosen
end

# ---------------------------------------------------------------- sample -----
def sample!(tag, n_teams, opp_per, nw)
  NativeSim.snapshot_save!(NStore.init(tag))   # freeze the save for the whole run
  NativeSim.boot!
  ou = NativeSim.pool(tier: TIER)
  NStore.init(tag)
  NStore.write_pool(tag, NativeSim.all_pool)

  teams = {}
  n_teams.times { |i| teams["t#{i}"] = { source: 'chaos', keys: rand_team(ou, Random.new(90_000 + i)) } }
  NStore.write_teams(tag, teams)

  ids = teams.keys
  rng = Random.new(4242)
  jobs = []
  ids.each_with_index do |id, i|
    opp_per.times do |k|
      j = ids[rng.rand(ids.length)]
      next if j == id
      seed = 1 + ((i * 31 + k * 7) % 97)
      jobs << ["#{id}v#{j}s#{seed}", teams[id][:keys], teams[j][:keys], seed]        # id on side 0
      jobs << ["#{j}v#{id}s#{seed}", teams[j][:keys], teams[id][:keys], seed]        # mirrored
    end
  end
  jobs.uniq! { |g| g[0] }
  NStore.write_jobs(tag, jobs)
  NStore.write_json(tag, 'manifest.json',
                    'tag' => tag, 'phase' => 'sample', 'tier' => TIER.to_s,
                    'clauses' => ['species', 'spore'] + (TIER == :ou ? ['ou_legal_legends'] : []),
                    'pool_total' => NativeSim.all_pool.length, 'pool_tier' => ou.length, 'tier_name' => TIER.to_s,
                    'teams' => n_teams, 'opp_per_team' => opp_per, 'games' => jobs.length,
                    'ai' => 'SmartTrainerAI (both sides, skill 100)', 'llm' => false,
                    'level' => 100, 'started' => Time.now.to_s, 'workers' => nw)
  puts "#{n_teams} teams, #{jobs.length} games (mirrored pairs), #{nw} workers"
  NRun.execute(tag, jobs, nw)
  rate!(tag)
end

# ------------------------------------------------------------------ rate -----
def rate!(tag)
  games = NStore.read_games(File.join(NStore.dir(tag), 'games.tsv'))
  pool  = NStore.read_json(tag, 'pool.json')
  puts "#{games.length} games loaded"

  st = Hash.new { |h, k| h[k] = { app: 0, pts: 0.0, kos: 0, faints: 0, hp: 0.0, wins: 0, losses: 0, draws: 0 } }
  games.each do |g|
    a = g[:team_a].split(','); b = g[:team_b].split(',')
    pa = g[:winner] == :a ? 1.0 : (g[:winner] == :b ? 0.0 : 0.5)
    a.each_with_index do |k, i|
      s = st[k]; s[:app] += 1; s[:pts] += pa; s[:kos] += g[:a_kos][i].to_i
      s[:faints] += g[:a_faint][i].to_i; s[:hp] += g[:a_hp][i].to_f
      pa == 1.0 ? s[:wins] += 1 : (pa == 0.0 ? s[:losses] += 1 : s[:draws] += 1)
    end
    b.each_with_index do |k, i|
      s = st[k]; s[:app] += 1; s[:pts] += (1.0 - pa); s[:kos] += g[:b_kos][i].to_i
      s[:faints] += g[:b_faint][i].to_i; s[:hp] += g[:b_hp][i].to_f
      pa == 0.0 ? s[:wins] += 1 : (pa == 1.0 ? s[:losses] += 1 : s[:draws] += 1)
    end
  end

  # ---- ridge logistic fit: P(A wins) = sigma( sum_A w - sum_B w ) -----------
  keys = st.keys.sort
  idx  = keys.each_with_index.to_h
  rows = games.map { |g|
    [g[:team_a].split(',').map { |k| idx[k] }, g[:team_b].split(',').map { |k| idx[k] },
     g[:winner] == :a ? 1.0 : (g[:winner] == :b ? 0.0 : 0.5)]
  }
  w = Array.new(keys.length, 0.0)
  lam = 1.0 / rows.length
  lr = 0.35
  400.times do |it|
    grad = Array.new(keys.length, 0.0)
    rows.each do |av, bv, y|
      z = 0.0
      av.each { |i| z += w[i] }; bv.each { |i| z -= w[i] }
      p = 1.0 / (1.0 + Math.exp(-z))
      d = (p - y)
      av.each { |i| grad[i] += d }; bv.each { |i| grad[i] -= d }
    end
    n = rows.length.to_f
    keys.length.times { |i| w[i] -= lr * (grad[i] / n + lam * w[i] * rows.length / n) }
    if it % 100 == 99
      ll = 0.0
      rows.each do |av, bv, y|
        z = 0.0; av.each { |i| z += w[i] }; bv.each { |i| z -= w[i] }
        p = 1.0 / (1.0 + Math.exp(-z))
        ll += y * Math.log([p, 1e-12].max) + (1 - y) * Math.log([1 - p, 1e-12].max)
      end
      puts "  iter #{it + 1}: mean log-lik %.4f" % (ll / rows.length)
    end
  end

  out = keys.map { |k|
    s = st[k]; p = pool[k] || {}
    { key: k, name: p['name'], species: p['species'], types: p['types'], item: p['item'],
      roles: p['roles'], box: p['box'], slot: p['slot'],
      app: s[:app], winrate: s[:pts] / s[:app], kos: s[:kos].to_f / s[:app],
      faint: s[:faints].to_f / s[:app], hp: s[:hp] / s[:app], coef: w[idx[k]] }
  }.sort_by { |r| -r[:coef] }

  csv = ["key,name,species,types,item,roles,box,slot,games,winrate,kos_per_game,faint_rate,end_hp,coef"]
  out.each { |r|
    csv << [r[:key], r[:name], r[:species], r[:types], r[:item], r[:roles].to_s.tr(',', ';'),
            r[:box], r[:slot], r[:app], '%.4f' % r[:winrate], '%.3f' % r[:kos],
            '%.3f' % r[:faint], '%.3f' % r[:hp], '%.4f' % r[:coef]].join(',')
  }
  File.binwrite(File.join(NStore.dir(tag), 'ratings.csv'), csv.join("\n"))

  fmt = ->(r) { "  %-8s %-14s %-24s %-13s %-14s g=%-4d wr=%.3f ko=%.2f fnt=%.2f coef=%+.3f" %
    [r[:key], r[:name].to_s[0, 14], r[:species].to_s[0, 24], r[:types].to_s[0, 13],
     r[:item].to_s[0, 14], r[:app], r[:winrate], r[:kos], r[:faint], r[:coef]] }
  puts "\n=== TOP 30 by ridge-logistic coefficient ==="
  out.first(30).each { |r| puts fmt.(r) }
  puts "\n=== BOTTOM 10 ==="
  out.last(10).each { |r| puts fmt.(r) }
  puts "\nratings -> #{File.join(NStore.dir(tag), 'ratings.csv')}"
end

case CMD
when 'sample' then sample!(TAG, (ARGV[2] || 1500).to_i, (ARGV[3] || 5).to_i, (ARGV[4] || NRun.workers).to_i)
when 'rate'   then rate!(TAG)
else puts "usage: nsearch_ou.rb sample <tag> [teams] [opp_per_team] [workers] | rate <tag>"
end
