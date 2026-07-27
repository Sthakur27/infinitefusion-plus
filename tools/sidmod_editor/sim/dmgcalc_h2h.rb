# READ-ONLY: head-to-head — Tidehammer (Azumarill/Marowak) vs Sylveon/Dragonite.
require_relative 'build_team'
SimEngine.boot
$DEBUG = false
class PokeBattle_Move
  def pbIsCritical?(user, target); false; end
end
$ROLL = 15

TIDE = { head: :AZUMARILL, body: :MAROWAK, ability: :HUGEPOWER, nature: :ADAMANT,
         item: :THICKCLUB, moves: [:AQUAJET, :EARTHQUAKE, :KNOCKOFF],
         evs: { HP: 4, ATTACK: 252, SPEED: 252 } }
SYLV = { head: :SYLVEON, body: :DRAGONITE, ability: :PIXILATE, nature: :ADAMANT,
         item: :CHOICEBAND, moves: [:EXTREMESPEED],
         evs: { HP: 4, ATTACK: 252, SPEED: 252 } }

def calc(att_pk, def_pk, move_id, roll:)
  $ROLL = roll
  t1 = SimBattle.make_trainer("P1", [att_pk]); t2 = SimBattle.make_trainer("P2", [def_pk])
  battle = PokeBattle_Battle.new(PokeBattle_DebugSceneNoLogging.new, t1.party, t2.party, t1, t2)
  battle.debug = true; battle.controlPlayer = true; battle.internalBattle = false
  def battle.pbRandom(x); $ROLL < x ? $ROLL : x - 1; end
  battle.pbCreateBattler(0, att_pk, 0); battle.pbCreateBattler(1, def_pk, 0)
  user = battle.battlers[0]; target = battle.battlers[1]
  move = PokeBattle_Move.from_pokemon_move(battle, Pokemon::Move.new(move_id))
  target.damageState.reset
  ctype = move.pbCalcType(user)
  move.instance_variable_set(:@calcType, ctype)
  tmod = move.pbCalcTypeMod(ctype, user, target)
  target.damageState.typeMod = tmod
  return [0, 0.0] if Effectiveness.ineffective?(tmod)
  move.pbCalcDamage(user, target)
  [target.damageState.calcDamage, 100.0 * target.damageState.calcDamage / target.totalhp]
end

tide = BuildTeam.mon(TIDE); sylv = BuildTeam.mon(SYLV)
puts "Tidehammer  HP #{tide.totalhp}  vs  Sylveon/Dragonite  HP #{sylv.totalhp}"
[[:AQUAJET, tide, sylv, "Tidehammer AQUAJET -> Sylv/Dnite"],
 [:EARTHQUAKE, tide, sylv, "Tidehammer EARTHQUAKE -> Sylv/Dnite"],
 [:KNOCKOFF, tide, sylv, "Tidehammer KNOCKOFF -> Sylv/Dnite"],
 [:EXTREMESPEED, sylv, tide, "Sylv/Dnite CB ESPEED -> Tidehammer"]].each do |mv, a, d, label|
  lo, lo_pct = calc(a, d, mv, roll: 0)
  hi, hi_pct = calc(a, d, mv, roll: 15)
  puts "  #{label.ljust(36)} #{lo}-#{hi}  (#{'%.1f' % lo_pct}%-#{'%.1f' % hi_pct}%)"
end
