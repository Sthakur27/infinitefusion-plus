# Prices real lookahead search before we commit to building it.
#   ruby tools/sidmod_editor/sim/nlookahead_cost.rb
# Measures: per-decision cost of the current 1-ply heuristic planner, and the cost
# of the thing a true search needs - cloning the battle state so a candidate action
# can be applied and undone. Branching is ~9 actions/side (4 moves + up to 5
# switches), so a joint 1-turn expansion is ~81 nodes and 2 turns is ~6.5k.
require_relative 'nbattle'
require 'benchmark'

NativeSim.boot!
ou = NativeSim.pool
pick = lambda do |seed|
  chosen = []; used = []
  ou.shuffle(random: Random.new(seed)).each do |e|
    next if (e[:bases] & used).any?
    chosen << e[:key]; used.concat(e[:bases]); break if chosen.length == 6
  end
  chosen
end
A = pick.(11); B = pick.(12)

# ---- 1. current cost per battle and per decision -----------------------------
n = 20
t0 = Time.now
decisions = 0
n.times do |i|
  r = NativeSim.run(A, B, seed: 200 + i, log: true)
  decisions += r[:log].count { |l| l.to_s.include?('[SmartAI]') && l.to_s.include?('will ') }
end
dt = Time.now - t0
puts "current planner: %.3fs/battle, %d decisions over %d battles = %.2f ms/decision" %
     [dt / n, decisions, n, (dt / decisions) * 1000]

# ---- 2. what a real search would cost ----------------------------------------
# Build a live battle and time a deep copy of the state a search must snapshot.
pa = NativeSim.party(A); pb = NativeSim.party(B)
t1 = SimBattle.make_trainer('A', pa); t2 = SimBattle.make_trainer('B', pb)
scene = PokeBattle_DebugSceneNoLogging.new
battle = PokeBattle_Battle.new(scene, t1.party, t2.party, t1, t2)
battle.debug = true; battle.controlPlayer = true; battle.internalBattle = false

# A search cannot Marshal the whole battle (it holds the scene + procs), so price
# the realistic unit: deep-copying the battlers + field that an action mutates.
reps = 200
tb = Benchmark.realtime do
  reps.times { Marshal.load(Marshal.dump([pa, pb])) }
end
per_clone_ms = (tb / reps) * 1000
puts "party deep-copy (what one search node must snapshot): %.3f ms" % per_clone_ms

# damage calc cost (the cheap analytic primitive an eval can use instead)
ai = PokeBattle_AI.new(battle)
puts "\nbranching: 4 moves + up to 5 switches = ~9 actions per side"
[["1-ply, our actions only (9)", 9],
 ["1-ply joint (9 x 9)", 81],
 ["2-ply joint (81 x 81)", 6561]].each do |label, nodes|
  est_ms = nodes * per_clone_ms
  puts "  %-28s %5d nodes -> %8.1f ms/decision (%.1fx current)" %
       [label, nodes, est_ms, est_ms / ((dt / decisions) * 1000)]
end
puts "\nA battle averages ~#{(decisions / n.to_f).round} decisions, so multiply again for battle cost."
puts "Harness throughput today: ~107 battles/sec across 14 workers."
