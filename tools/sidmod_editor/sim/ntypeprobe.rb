# Why did Earthquake score 126 against a Water/FLYING target? Test type immunity
# through sidmod_immune? directly.
require_relative 'nbattle'
NativeSim.boot!
pool = NativeSim.all_pool

flyer = pool.find { |e| e[:types].include?(:FLYING) && !e[:types].include?(:GROUND) }
ghost = pool.find { |e| e[:types].include?(:GHOST) }
eq    = pool.find { |e| e[:moves].include?(:EARTHQUAKE) }
fight = pool.find { |e| e[:moves].any? { |m| %i[SUPERPOWER CLOSECOMBAT BRICKBREAK].include?(m) } }

[[eq, flyer, :EARTHQUAKE, 'Ground -> Flying'],
 [fight, ghost, nil, 'Fighting -> Ghost']].each do |atk, def_, mid, label|
  pa = NativeSim.party([atk[:key]]); pb = NativeSim.party([def_[:key]])
  t1 = SimBattle.make_trainer('A', pa); t2 = SimBattle.make_trainer('B', pb)
  b = PokeBattle_Battle.new(PokeBattle_DebugSceneNoLogging.new, t1.party, t2.party, t1, t2)
  b.debug = true; b.controlPlayer = true; b.internalBattle = false
  b.pbCreateBattler(0, pa[0], 0); b.pbCreateBattler(1, pb[0], 0)
  ai = PokeBattle_AI.new(b)
  u = b.battlers[0]; t = b.battlers[1]
  puts "\n=== #{label}: #{atk[:name]} vs #{def_[:name]} (types #{t.pbTypes(true).inspect}) ==="
  u.eachMoveWithIndex do |m, i|
    next if mid && m.id != mid
    next if !mid && !%i[SUPERPOWER CLOSECOMBAT BRICKBREAK].include?(m.id)
    ct = (m.pbCalcType(u) rescue 'RAISED')
    old = m.instance_variable_get(:@calcType)
    m.instance_variable_set(:@calcType, ct)
    mod = (m.pbCalcTypeMod(ct, u, t) rescue 'RAISED')
    m.instance_variable_set(:@calcType, old)
    puts "  #{m.name}: calcType=#{ct.inspect} typeMod=#{mod.inspect} " \
         "immune?=#{ai.sidmod_immune?(u, t, m)} will_fail?=#{ai.sidmod_will_fail?(u, t, m)}"
    raw, exp, acc = ai.sidmod_move_damage(m, u, t, 100)
    puts "    sidmod_move_damage -> raw=#{raw} expected=#{exp.round(1)} acc=#{acc}"
  end
end
puts "\nNOTE: Effectiveness::INEFFECTIVE is 0; a typeMod of 0 must make sidmod_immune? true."
