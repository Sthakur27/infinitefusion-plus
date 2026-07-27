# Sanity/soundness check for the native-AI harness before running thousands of games.
#   ruby tools/sidmod_editor/sim/nsanity.rb
require_relative 'nbattle'

t0 = Time.now
NativeSim.boot!
puts "boot %.2fs | pool %d total, %d OU-legal" % [Time.now - t0, NativeSim.all_pool.length, NativeSim.pool.length]

ou = NativeSim.pool
rng = Random.new(42)
# two fixed random Species-Clause-legal teams
pick = lambda do |r|
  chosen = []; used = []
  ou.shuffle(random: r).each do |e|
    next if (e[:bases] & used).any?
    chosen << e; used.concat(e[:bases])
    break if chosen.length == 6
  end
  chosen.map { |e| e[:key] }
end
A = pick.(Random.new(7)); B = pick.(Random.new(8))
nm = ->(keys) { keys.map { |k| NativeSim.entry(k)[:name] }.join(', ') }
puts "A: #{nm.(A)}"
puts "B: #{nm.(B)}"

def block(a, b, seeds)
  res = { a: 0, b: 0, draw: 0 }; turns = []; alive = []
  seeds.each do |s|
    r = NativeSim.run(a, b, seed: s)
    res[r[:winner]] += 1; turns << r[:turns]; alive << [r[:a_alive], r[:b_alive]]
  end
  [res, turns, alive]
end

t = Time.now
res, turns, alive = block(A, B, (1..20).to_a)
dt = Time.now - t
puts "\nA(side0) vs B(side1), 20 seeds: A #{res[:a]} / B #{res[:b]} / draw #{res[:draw]}"
puts "  turns: min #{turns.min} med #{turns.sort[10]} max #{turns.max} | %.3fs per battle" % (dt / 20)
puts "  survivors (A,B): #{alive.first(8).inspect}"

res2, turns2, = block(B, A, (1..20).to_a)   # swap sides: detects positional bias
puts "B(side0) vs A(side1), 20 seeds: B #{res2[:a]} / A #{res2[:b]} / draw #{res2[:draw]}"
puts "  A total across both orders: #{res[:a] + res2[:b]}/40   B: #{res[:b] + res2[:a]}/40"

# KO attribution sample
r = NativeSim.run(A, B, seed: 3)
puts "\nsample game (seed 3) winner=#{r[:winner]} turns=#{r[:turns]}"
(r[:a] + r[:b]).each do |m|
  puts "  side#{m[:side]} #{NativeSim.entry(m[:key])[:name].ljust(14)} kos=#{m[:kos]} fainted=#{m[:fainted]} hp=%.2f" % m[:hp]
end
tot_kos = (r[:a] + r[:b]).sum { |m| m[:kos] }
tot_faints = (r[:a] + r[:b]).count { |m| m[:fainted] }
puts "  KOs credited #{tot_kos} / faints #{tot_faints} (gap = chip/hazard/status deaths)"
puts "last engine error: #{NativeSim.last_error.inspect}"
