require_relative 'nbattle'
NativeSim.boot!
pool = NativeSim.all_pool
find = ->(n) { pool.find { |e| e[:name].to_s == n } }
atk = find.('Pinkreef'); tgt = find.('Vaporsteel')
puts "atk=#{atk[:name]}/#{atk[:species]} moves=#{atk[:moves].join(',')}"
puts "tgt=#{tgt[:name]}/#{tgt[:species]} ability=#{tgt[:ref].ability&.name} types=#{tgt[:types].inspect}"
pa = NativeSim.party([atk[:key]]); pb = NativeSim.party([tgt[:key]])
t1 = SimBattle.make_trainer('A', pa); t2 = SimBattle.make_trainer('B', pb)
b = PokeBattle_Battle.new(PokeBattle_DebugSceneNoLogging.new, t1.party, t2.party, t1, t2)
b.debug = true; b.controlPlayer = true; b.internalBattle = false
b.pbCreateBattler(0, pa[0], 0); b.pbCreateBattler(1, pb[0], 0)
ai = PokeBattle_AI.new(b); u = b.battlers[0]; t = b.battlers[1]
puts "battle.moldBreaker=#{b.moldBreaker.inspect}  target.abilityActive?=#{t.abilityActive?}"
u.eachMoveWithIndex { |m, i|
  puts "  %-12s immune?=%-5s will_fail?=%-5s" % [m.name, ai.sidmod_immune?(u, t, m), ai.sidmod_will_fail?(u, t, m)]
}
