# Ladder worker: evaluates a batch of challengers with STAGED EARLY EXIT, one process,
# engine booted once.
#   ruby nladder_worker.rb <job.json> <out_prefix>
#
# job.json = { "ladder": [{"id","keys","elo"}...], "challengers": [{"cid","keys"}...],
#              "stages": [{"opps":4,"seeds":1,"cull":0.25,"top_bias":0.0}, ...],
#              "bar": <elo>, "rng": <int> }
#
# Writes  <out_prefix>.res   cid \t verdict \t games \t points \t perf_elo \t stage
#         <out_prefix>.games cid \t opp_id \t seed \t side \t score
#
# Each stage draws fresh opponents (top_bias pulls the sample toward the strongest
# part of the ladder, so the final stage judges a challenger against real resistance)
# and both side assignments are always played, so no result is a side-order artifact.
require_relative 'nstore'
require_relative 'nbattle'

job = NStore::PARSE.call(File.binread(ARGV[0]))
OUT = ARGV[1]
NativeSim.boot!

LADDER = job['ladder']
STAGES = job['stages']
BAR    = job['bar'].to_f
SORTED = LADDER.sort_by { |t| -t['elo'].to_f }     # strongest first

def sample_opps(rng, n, top_bias, exclude_ids)
  pool = SORTED.reject { |t| exclude_ids.include?(t['id']) }
  return [] if pool.empty?
  n = [n, pool.length].min
  if top_bias > 0
    # take from the strongest `frac` of the ladder with probability top_bias
    strong = pool.first([(pool.length * 0.35).ceil, 1].max)
    picks = []
    while picks.length < n
      src = (rng.rand < top_bias ? strong : pool)
      c = src[rng.rand(src.length)]
      picks << c unless picks.include?(c)
      break if picks.length >= pool.length
    end
    picks
  else
    pool.shuffle(random: rng).first(n)
  end
end

def perf_elo(points, games, opp_elos, bar)
  return bar - 400 if games.zero?
  p = points / games.to_f
  p = 0.02 if p < 0.02
  p = 0.98 if p > 0.98
  mean_opp = opp_elos.sum / opp_elos.length.to_f
  mean_opp + 400 * Math.log10(p / (1 - p))
end

res = File.open("#{OUT}.res", 'wb')
gam = File.open("#{OUT}.games", 'wb')

job['challengers'].each do |ch|
  cid = ch['cid']; keys = ch['keys']
  rng = Random.new(job['rng'].to_i + cid.hash.abs % 100_000)
  pts = 0.0; n = 0; opp_elos = []; used = []
  verdict = 'promote'; stage_reached = 0

  STAGES.each_with_index do |st, si|
    stage_reached = si + 1
    opps = sample_opps(rng, st['opps'].to_i, st['top_bias'].to_f, used)
    break if opps.empty?
    used.concat(opps.map { |o| o['id'] })
    opps.each do |o|
      st['seeds'].to_i.times do |s|
        seed = 1 + s + si * 7
        # both side assignments
        r1 = NativeSim.run(keys, o['keys'], seed: seed)
        sc1 = r1[:winner] == :a ? 1.0 : (r1[:winner] == :b ? 0.0 : 0.5)
        r2 = NativeSim.run(o['keys'], keys, seed: seed)
        sc2 = r2[:winner] == :b ? 1.0 : (r2[:winner] == :a ? 0.0 : 0.5)
        [[sc1, 'A'], [sc2, 'B']].each do |sc, side|
          pts += sc; n += 1; opp_elos << o['elo'].to_f
          gam.write("#{cid}\t#{o['id']}\t#{seed}\t#{side}\t#{sc}\n")
        end
      end
    end
    cull = st['cull']
    if cull && n > 0 && (pts / n) < cull.to_f
      verdict = 'cull'
      break
    end
  end

  pe = perf_elo(pts, n, opp_elos, BAR)
  verdict = 'cull' if verdict == 'promote' && pe < BAR
  res.write("#{cid}\t#{verdict}\t#{n}\t#{'%.2f' % pts}\t#{'%.1f' % pe}\t#{stage_reached}\n")
  res.flush; gam.flush
end
res.close; gam.close
