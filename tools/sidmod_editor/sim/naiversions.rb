# FIXED LADDER OF AI VERSIONS: play AI versions against each other on identical teams
# and seeds.  (Team-vs-team king-of-the-hill lives in nladder.rb - different thing.)
#   ruby tools/sidmod_editor/sim/naiversions.rb <rating_tag> <out_tag> [matchups] [seeds]
#
# Self-play ablation only gives a feature's MARGINAL contribution and is blind to fixes
# both sides benefit from equally. Absolute rungs answer what actually matters: is this
# version better than the previous one, and is it better than the stock engine AI at all?
#
# Rungs:
#   vanilla    - stock Essentials effect-score AI (whole SmartAI planner off)
#   presession - the SmartAI planner WITHOUT any of the v2/v3 work
#   current    - everything on
require_relative 'nstore'
require_relative 'nbattle'
require 'fileutils'

RTAG = ARGV[0] || 'ou3'
OTAG = ARGV[1] || 'aiversions'
MU   = (ARGV[2] || 20).to_i
SEEDS = (ARGV[3] || 12).to_i

snap = File.join(NStore.dir(RTAG), 'save_snapshot.rxdata')
ENV['NSIM_SAVE'] = snap if File.exist?(snap)
NativeSim.boot!
FileUtils.mkdir_p(NStore.dir(OTAG))
POOL = NStore.read_json(RTAG, 'pool.json')
rat = File.readlines(File.join(NStore.dir(RTAG), 'ratings.csv'))
HDR = rat[0].chomp.split(',')
MONS = rat[1..].map { |l| HDR.zip(l.chomp.split(',')).to_h }
BY = MONS.map { |m| [m['key'], m] }.to_h
keys = MONS.map { |m| m['key'] }.select { |k| POOL[k] }
def bases_of(k); (POOL[k] && POOL[k]['bases']) || []; end
def stats_of(k); (POOL[k] && POOL[k]['stats']) || [0] * 6; end
def moves_of(k); (POOL[k] && POOL[k]['moves']) || []; end
def pick6(c)
  o = []; u = []
  c.each { |k| next if (bases_of(k) & u).any?; o << k; u.concat(bases_of(k)); break if o.length == 6 }
  o
end
bulk = ->(k) { s = stats_of(k); s[0].to_i + s[2].to_i + s[4].to_i }
RECOV = %w[Recover Roost Soft-Boiled Slack\ Off Moonlight Synthesis Wish Rest Shore\ Up Milk\ Drink Morning\ Sun]
# an offence team AND a defensive team are always included, so a version that only
# handles one archetype cannot look good by accident
teams = [pick6(keys.sort_by { |k| -BY[k]['kos_per_game'].to_f }),
         pick6(keys.select { |k| (moves_of(k) & RECOV).any? && bulk.(k) >= 800 }.sort_by { |k| -bulk.(k) })]
(MU - 2).times { |i| teams << pick6(keys.shuffle(random: Random.new(2100 + i))) }
teams = teams.select { |t| t.length == 6 }

ALL_OFF = { heal: false, residual: false, chip: false, noop: false, preview: false,
            setup_convert: false, phaze: false, repl_safe: false, beam: false,
            dmg_weight: false }
ALL_RUNGS = { 'vanilla' => { smart: false }, 'presession' => ALL_OFF, 'current' => {},
              'additive' => { suppress: false } }  # every score-suppressing multiplier off
sel = (ARGV[4] || '').split(',')
RUNGS = sel.empty? ? ALL_RUNGS : ALL_RUNGS.select { |k, _| sel.include?(k) }

puts "=== AI VERSION LADDER: #{teams.length} teams x #{SEEDS} seeds x 2 orders per pairing ==="
h2h = Hash.new { |h, k| h[k] = [0.0, 0] }
RUNGS.keys.combination(2) do |a, b|
  teams.each_with_index do |ta, i|
    tb = teams[(i + 1) % teams.length]
    next if ta == tb
    SEEDS.times do |s|
      seed = 90 + s
      $SIDMOD_AI_FEATURES = { 0 => RUNGS[a], 1 => RUNGS[b] }
      r = NativeSim.run(ta, tb, seed: seed)
      h2h[[a, b]][0] += (r[:winner] == :a ? 1.0 : (r[:winner] == :b ? 0.0 : 0.5))
      h2h[[a, b]][1] += 1
      $SIDMOD_AI_FEATURES = { 0 => RUNGS[b], 1 => RUNGS[a] }
      r = NativeSim.run(ta, tb, seed: seed)
      h2h[[a, b]][0] += (r[:winner] == :b ? 1.0 : (r[:winner] == :a ? 0.0 : 0.5))
      h2h[[a, b]][1] += 1
    end
  end
  $SIDMOD_AI_FEATURES = nil
  p_, n_ = h2h[[a, b]]
  wr = p_ / n_
  se = Math.sqrt(0.25 / n_)
  sig = (wr - 0.5).abs > 1.96 * se ? '' : '  (not significant)'
  puts "  %-11s vs %-11s : %.3f +/- %.3f over %d games%s" % [a, b, wr, se, n_, sig]
end

elo = Hash.new(0.0)
200.times do
  RUNGS.keys.each do |x|
    grad = 0.0; tot = 0
    RUNGS.keys.each do |y|
      next if x == y
      p_, n_ = h2h[[x, y]]
      if n_ == 0
        p_, n_ = h2h[[y, x]]
        next if n_ == 0
        p_ = n_ - p_
      end
      exp = n_ / (1.0 + 10**((elo[y] - elo[x]) / 400.0))
      grad += (p_ - exp); tot += n_
    end
    elo[x] += 4.0 * grad / [tot, 1].max
  end
end
base = elo['vanilla']
puts "\n=== ELO (stock Essentials AI = 0) ==="
RUNGS.keys.sort_by { |k| -elo[k] }.each { |k| puts "  %-11s %+6.0f" % [k, elo[k] - base] }
File.binwrite(File.join(NStore.dir(OTAG), 'aiversions.txt'),
  h2h.map { |(a, b), (p_, n_)| "%s	vs	%s	%.4f	%d" % [a, b, p_ / n_, n_] }.join("
") +
  "

" + RUNGS.keys.map { |k| "ELO	%s	%+.0f" % [k, elo[k] - base] }.join("
") + "
")
