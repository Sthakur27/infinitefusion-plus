# Positional-bias + noise measurement. Every matchup is played in BOTH orders on
# the SAME seeds, so any net side-0 win surplus across many distinct teams is
# positional bias (not team strength). Also reports draw rate and how often the
# same matchup flips between seeds (the noise floor that sets bo-N sizing).
#   ruby tools/sidmod_editor/sim/nsymmetry.rb [matchups] [seeds]
require_relative 'nbattle'
NativeSim.boot!
MU    = (ARGV[0] || 40).to_i
SEEDS = (ARGV[1] || 3).to_i
ou = NativeSim.pool

def rand_team(ou, rng)
  chosen = []; used = []
  ou.shuffle(random: rng).each do |e|
    next if (e[:bases] & used).any?
    chosen << e[:key]; used.concat(e[:bases])
    break if chosen.length == 6
  end
  chosen
end

side0 = 0; side1 = 0; draws = 0; games = 0
flips = 0; decided_pairs = 0; selfm = [0, 0, 0]
t0 = Time.now
MU.times do |m|
  a = rand_team(ou, Random.new(1000 + m * 2))
  b = rand_team(ou, Random.new(1001 + m * 2))
  results = []
  SEEDS.times do |s|
    seed = 1 + s
    r1 = NativeSim.run(a, b, seed: seed)   # a on side 0
    r2 = NativeSim.run(b, a, seed: seed)   # b on side 0
    [r1, r2].each do |r|
      games += 1
      case r[:winner]
      when :a then side0 += 1
      when :b then side1 += 1
      else draws += 1
      end
    end
    # team-level result of this seed, order-averaged: did A win as side0 and as side1?
    results << [r1[:winner] == :a ? 1 : (r1[:winner] == :b ? 0 : 0.5),
                r2[:winner] == :b ? 1 : (r2[:winner] == :a ? 0 : 0.5)]
  end
  # noise: across seeds, does the same matchup change winner?
  per_seed = results.map { |x| (x[0] + x[1]) / 2.0 }
  if per_seed.max > 0.5 && per_seed.min < 0.5
    flips += 1
  end
  decided_pairs += 1
  print '.'; $stdout.flush
end
dt = Time.now - t0

puts "\n\n=== #{games} games in %.1fs (%.3fs/game single process) ===" % [dt, dt / games]
dec = side0 + side1
puts "side0 wins #{side0}  side1 wins #{side1}  draws #{draws} (%.1f%%)" % (100.0 * draws / games)
puts "side0 share of decided games: %.1f%%" % (100.0 * side0 / dec)
# binomial 95% CI half-width for the side share
se = Math.sqrt(0.25 / dec)
puts "  fair = 50%% +/- %.1f%% (95%% CI at n=#{dec})" % (196 * se)
puts "matchups whose winner FLIPPED across the #{SEEDS} seeds: #{flips}/#{decided_pairs} (%.0f%%)" %
     (100.0 * flips / decided_pairs)

# same-team mirror pool: pure positional test, 8 teams x 10 seeds
puts "\n=== self-mirror (identical teams, both sides) ==="
tot = [0, 0, 0]
8.times do |m|
  a = rand_team(ou, Random.new(5000 + m))
  w = [0, 0, 0]
  10.times { |s| r = NativeSim.run(a, a, seed: 300 + s); w[r[:winner] == :a ? 0 : (r[:winner] == :b ? 1 : 2)] += 1 }
  tot[0] += w[0]; tot[1] += w[1]; tot[2] += w[2]
  puts "  team#{m}: side0 #{w[0]} / side1 #{w[1]} / draw #{w[2]}"
end
puts "  TOTAL side0 #{tot[0]} / side1 #{tot[1]} / draw #{tot[2]}  (side0 share %.1f%% of decided)" %
     (100.0 * tot[0] / (tot[0] + tot[1]))
