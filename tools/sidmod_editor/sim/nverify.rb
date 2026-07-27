# Verification pass: BEFORE any mass run, prove that
#   (1) the teams the sampler builds are sane, real, fully-kitted L100 mons,
#   (2) the SmartTrainerAI (not vanilla, not random) is choosing for BOTH sides,
#   (3) post-faint replacements are AI-chosen on both sides (fairness fix), and
#   (4) there is no residual side bias (mirrored 20-seed blocks).
#   ruby tools/sidmod_editor/sim/nverify.rb
require_relative 'nbattle'
require 'fileutils'

NativeSim.boot!
OUT = File.join(__dir__, 'nreports', 'verify'); FileUtils.mkdir_p(OUT)
ou  = NativeSim.pool
puts "pool: #{NativeSim.all_pool.length} battle-ready (post-Spore), #{ou.length} OU-legal\n"

# ---- two teams: one Smart-builder team, one pure-random (chaos) team ---------
smart_keys = SidmodRandomOpp.build_team(:smart, :ou, 1234).map { |pk|
  NativeSim.all_pool.find { |e| e[:ref].equal?(pk) }[:key] }
chaos = []; used = []
ou.shuffle(random: Random.new(99)).each do |e|
  next if (e[:bases] & used).any?
  chaos << e[:key]; used.concat(e[:bases]); break if chaos.length == 6
end

puts NativeSim.show_team(smart_keys, "TEAM A  (Smart builder, seed 1234)")
puts
puts NativeSim.show_team(chaos, "TEAM B  (Chaos random, seed 99)")

# ---- 2 logged fights ---------------------------------------------------------
[11, 12].each do |seed|
  r = NativeSim.run(smart_keys, chaos, seed: seed, log: true)
  f = File.join(OUT, "fight_seed#{seed}.log")
  File.binwrite(f, r[:log].join("\n"))   # engine strings are ASCII-8BIT (Pokémon é)
  smart_lines = r[:log].count { |l| l.include?('[SmartAI]') }
  side0 = r[:log].count { |l| l =~ /\[SmartAI\].*\(0\)/ }
  side1 = r[:log].count { |l| l =~ /\[SmartAI\].*\(1\)/ }
  vanilla = r[:log].count { |l| l.include?('[AI]') && !l.include?('[SmartAI]') }
  repl = r[:log].count { |l| l.include?('replacement pick') }
  puts "\n=== fight seed #{seed}: winner=#{r[:winner]} turns=#{r[:turns]} " \
       "(A #{r[:a_alive]} alive vs B #{r[:b_alive]} alive)"
  puts "  log lines #{r[:log].length} | [SmartAI] #{smart_lines} (side0 #{side0}, side1 #{side1}) " \
       "| vanilla [AI] #{vanilla} | AI replacement picks #{repl}"
  puts "  full log -> #{f}"
  # condensed: turn markers, move uses, faints, and the planner's pick lines
  shown = r[:log].select { |l|
    l =~ /^\[SmartAI\].*will (use|switch)/ || l.include?('replacement pick') ||
    l =~ /used |fainted|Turn |sent out|withdrew/ }
  puts shown.first(34).map { |l| "    " + l.gsub("\n", ' ') }.join("\n")
end

# ---- side-bias / mirrored blocks --------------------------------------------
blk = lambda do |a, b, seeds|
  h = { a: 0, b: 0, draw: 0 }
  seeds.each { |s| h[NativeSim.run(a, b, seed: s)[:winner]] += 1 }
  h
end
seeds = (1..20).to_a
f1 = blk.(smart_keys, chaos, seeds)
f2 = blk.(chaos, smart_keys, seeds)
puts "\n=== mirrored blocks (fairness check) ==="
puts "  A as side0: A #{f1[:a]} / B #{f1[:b]} / draw #{f1[:draw]}"
puts "  A as side1: A #{f2[:b]} / B #{f2[:a]} / draw #{f2[:draw]}"
puts "  A overall #{f1[:a] + f2[:b]}/40, B overall #{f1[:b] + f2[:a]}/40"

# same-team mirror match: a team against ITSELF must sit near 50/50 if sides are fair
m = blk.(smart_keys, smart_keys, (1..40).to_a)
puts "  self-mirror (A vs A, 40 seeds): side0 #{m[:a]} / side1 #{m[:b]} / draw #{m[:draw]}  <- should be ~50/50"
