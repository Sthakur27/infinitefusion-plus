# Feasibility probe for the NATIVE-AI (deterministic, no-LLM) mass battle search.
# Boots the engine once, loads the PC pool from File A (read-only), builds two
# Smart-OU teams, and times a few full battles. Also verifies the SmartTrainerAI
# drives BOTH sides (stock gate exempts player-owned battlers).
#   ruby tools/sidmod_editor/sim/nprobe.rb        (run from game root)
require_relative 'engine'
require_relative 'battle'

t0 = Time.now
SimEngine.boot
$DEBUG = false
puts "boot: %.1fs (%d scripts skipped)" % [Time.now - t0, SimEngine.skipped.length]

SAVE = File.join(ENV['APPDATA'], 'infinitefusion', 'File A.rxdata')
save = StubLoader.load_file(SAVE)
$PokemonStorage = save[:storage_system]
puts "storage: #{$PokemonStorage.class} maxBoxes=#{$PokemonStorage.maxBoxes}"

pool = SidmodRandomOpp.battle_pool
cands = pool.map { |pk| SidmodRandomOpp.candidate(pk) }
nospore = cands.reject { |c| (c[:moves] & SidmodRandomOpp::BANNED_MOVES).any? }
ou = nospore.select { |c| SidmodRandomOpp.ou_legal?(c) }
puts "pool: #{pool.length} ready / #{nospore.length} after spore clause / #{ou.length} OU-legal"

# --- BOTH sides Smart: drop the player-owned exemption + count invocations ----
$SMART = Hash.new(0)
class PokeBattle_AI
  def sidmod_smart_ai?(idxBattler)
    r = SmartAI::ENABLED && !@battle.wildBattle? && @battle.trainerBattle? &&
        @battle.pbSideSize(0) == 1 && @battle.pbSideSize(1) == 1
    $SMART[[idxBattler, !!r]] += 1
    r
  end
end

mk = lambda do |seed|
  refs = SidmodRandomOpp.build_team(:smart, :ou, seed)
  refs.map { |pk| c = Marshal.load(Marshal.dump(pk)); c.heal; c }
end

a = mk.(1); b = mk.(2)
puts "\nA: " + a.map { |p| "#{p.name}" }.join(', ')
puts "B: " + b.map { |p| "#{p.name}" }.join(', ')

puts "\nbattles (native SmartAI both sides, seeded):"
3.times do |i|
  t = Time.now
  dec = SimBattle.run(mk.(1), mk.(2), seed: 100 + i)
  puts "  seed=#{100 + i} -> #{SimBattle::DECISION[dec]}  (%.2fs)" % (Time.now - t)
end

# determinism check: same seed twice must give the same result
d1 = SimBattle.run(mk.(1), mk.(2), seed: 777)
d2 = SimBattle.run(mk.(1), mk.(2), seed: 777)
puts "determinism: seed 777 -> #{d1} then #{d2}  #{d1 == d2 ? 'OK' : 'MISMATCH'}"
puts "smart-ai gate calls (battler,smart?) => #{$SMART.inspect}"
