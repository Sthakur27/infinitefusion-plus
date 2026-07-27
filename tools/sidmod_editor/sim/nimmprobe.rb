# Does sidmod_immune? actually catch Water Absorb, and what happens when EVERY move
# a mon has is a no-op? (Suspicion: all moves score 0 -> choices.empty? -> the planner
# falls back to vanilla AI, which happily clicks the immune move anyway.)
require_relative 'nbattle'
NativeSim.boot!

# find the Water Absorb wall and a Scald user from the pool
pool = NativeSim.all_pool
absorber = pool.find { |e| (e[:ref].ability&.id rescue nil) == :WATERABSORB && e[:moves].include?(:SCALD) } ||
           pool.find { |e| (e[:ref].ability&.id rescue nil) == :WATERABSORB }
scalder  = pool.find { |e| e[:moves].include?(:SCALD) && e[:key] != absorber[:key] }
puts "absorber: #{absorber[:name]} #{absorber[:species]} ability=#{absorber[:ref].ability&.name} moves=#{absorber[:moves].join(',')}"
puts "scalder : #{scalder[:name]} #{scalder[:species]} moves=#{scalder[:moves].join(',')}"

pa = NativeSim.party([scalder[:key]] + pool.first(2).map { |e| e[:key] }.reject { |k| k == scalder[:key] || k == absorber[:key] })
pb = NativeSim.party([absorber[:key]])
t1 = SimBattle.make_trainer('A', pa); t2 = SimBattle.make_trainer('B', pb)
battle = PokeBattle_Battle.new(PokeBattle_DebugSceneNoLogging.new, t1.party, t2.party, t1, t2)
battle.debug = true; battle.controlPlayer = true; battle.internalBattle = false
battle.pbCreateBattler(0, pa[0], 0)
battle.pbCreateBattler(1, pb[0], 0)
ai = PokeBattle_AI.new(battle)
u = battle.battlers[0]; t = battle.battlers[1]
puts "\nuser=#{u.pbThis} target=#{t.pbThis} (ability #{t.ability&.name}, types #{t.pbTypes(true).inspect})"

u.eachMoveWithIndex do |m, i|
  imm  = ai.sidmod_immune?(u, t, m)
  fail = ai.sidmod_will_fail?(u, t, m)
  puts "  %-16s damaging=%-5s immune?=%-5s will_fail?=%-5s" % [m.name, m.damagingMove?, imm, fail]
end

# Now the real question: what does the planner DO when everything is a no-op?
ctx = ai.sidmod_race_context(u, t, 100)
vanilla = []
u.eachMoveWithIndex { |_m, i| ai.pbRegisterMoveTrainer(u, i, vanilla, 100) if battle.pbCanChooseMove?(0, i, false) }
puts "\nvanilla scores: " + vanilla.map { |c| "#{u.moves[c[0]].name}=#{c[1]}" }.join(', ')
repriced = vanilla.map { |c| [u.moves[c[0]].name, ai.sidmod_reprice_move(u, t, u.moves[c[0]], c[1].to_f, ctx, 100).to_i] }
puts "repriced      : " + repriced.map { |n, s| "#{n}=#{s}" }.join(', ')
puts "SURVIVORS (score>0): #{repriced.count { |_n, s| s > 0 }} of #{repriced.length}"
puts "\n=> if 0 survive and no switch is available, sidmod_choose_action falls back to"
puts "   vanilla AI, which re-picks the immune move. That is the leak."
