# READ-ONLY: can Tidehammer (Azumarill/Marowak 4 HP/252 Atk/252 Spe) take a hit
# and fire off Swords Dance? Standard offensive threats attack IT.
require_relative 'build_team'
SimEngine.boot
$DEBUG = false
class PokeBattle_Move
  def pbIsCritical?(user, target); false; end
end
$ROLL = 15

TIDE = { head: :AZUMARILL, body: :MAROWAK, ability: :HUGEPOWER, nature: :ADAMANT,
         item: :THICKCLUB, moves: [:AQUAJET, :EARTHQUAKE, :KNOCKOFF, :SWORDSDANCE],
         evs: { HP: 4, ATTACK: 252, SPEED: 252 } }

# attacker spec, move(s), label. Standard competitive sets/items.
HITS = [
  [{ species: :GARCHOMP,  ability: :ROUGHSKIN,  nature: :JOLLY,   item: :LIFEORB,    evs: { ATTACK: 252, SPEED: 252 } }, [:EARTHQUAKE, :OUTRAGE]],
  [{ species: :SCIZOR,    ability: :TECHNICIAN, nature: :ADAMANT, item: :CHOICEBAND, evs: { ATTACK: 252, HP: 252 } },    [:BULLETPUNCH, :UTURN]],
  [{ species: :WEAVILE,   ability: :PRESSURE,   nature: :JOLLY,   item: :LIFEORB,    evs: { ATTACK: 252, SPEED: 252 } }, [:KNOCKOFF, :ICICLECRASH]],
  [{ species: :TYRANITAR, ability: :SANDSTREAM, nature: :JOLLY,   item: :CHOICEBAND, evs: { ATTACK: 252, SPEED: 252 } }, [:STONEEDGE, :CRUNCH]],
  [{ species: :BISHARP,   ability: :DEFIANT,    nature: :JOLLY,   item: :LIFEORB,    evs: { ATTACK: 252, SPEED: 252 } }, [:IRONHEAD, :KNOCKOFF]],
  [{ species: :FERROTHORN,ability: :IRONBARBS,  nature: :RELAXED, item: :LEFTOVERS,  evs: { HP: 252, DEFENSE: 252 } },   [:POWERWHIP, :GYROBALL]],
  [{ species: :TANGROWTH, ability: :REGENERATOR,nature: :RELAXED, item: :LEFTOVERS,  evs: { HP: 252, DEFENSE: 252 } },   [:GIGADRAIN, :POWERWHIP]],
  [{ species: :MEWTWO,    ability: :PRESSURE,   nature: :TIMID,   item: :LIFEORB,    evs: { SPECIAL_ATTACK: 252, SPEED: 252 } }, [:PSYCHIC, :AURASPHERE, :GRASSKNOT]],
  [{ species: :KYOGRE,    ability: :DRIZZLE,    nature: :TIMID,   item: :CHOICESPECS,evs: { SPECIAL_ATTACK: 252, SPEED: 252 } }, [:WATERSPOUT, :ICEBEAM]],
  [{ species: :VOLCARONA, ability: :FLAMEBODY,  nature: :TIMID,   item: :LEFTOVERS,  evs: { SPECIAL_ATTACK: 252, SPEED: 252 } }, [:FIREBLAST, :GIGADRAIN, :BUGBUZZ]],
  [{ species: :GENGAR,    ability: :CURSEDBODY, nature: :TIMID,   item: :LIFEORB,    evs: { SPECIAL_ATTACK: 252, SPEED: 252 } }, [:SHADOWBALL, :SLUDGEWAVE]],
  [{ species: :STARMIE,   ability: :ANALYTIC,   nature: :TIMID,   item: :LIFEORB,    evs: { SPECIAL_ATTACK: 252, SPEED: 252 } }, [:HYDROPUMP, :ICEBEAM, :GRASSKNOT]],
  [{ species: :RAYQUAZA,  ability: :AIRLOCK,    nature: :JOLLY,   item: :LIFEORB,    evs: { ATTACK: 252, SPEED: 252 } }, [:OUTRAGE, :EARTHQUAKE]],
  [{ species: :ZEKROM,    ability: :TERAVOLT,   nature: :ADAMANT, item: :CHOICEBAND, evs: { ATTACK: 252, SPEED: 252 } }, [:BOLTSTRIKE, :OUTRAGE]],
  [{ species: :DARKRAI,   ability: :BADDREAMS,  nature: :TIMID,   item: :LIFEORB,    evs: { SPECIAL_ATTACK: 252, SPEED: 252 } }, [:DARKPULSE, :FOCUSBLAST]],
]

def valid_species?(sym)
  begin
    GameData::Species.get(sym).id == sym
  rescue
    false
  end
end

def valid_move?(sym)
  begin
    GameData::Move.get(sym); true
  rescue
    false
  end
end

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
  return [0, 0.0, "immune"] if Effectiveness.ineffective?(tmod)
  move.pbCalcDamage(user, target)
  dmg = target.damageState.calcDamage
  eff = if Effectiveness.super_effective?(tmod)
          tmod >= Effectiveness::NORMAL_EFFECTIVE * 4 ? "4x" : "SE"
        elsif Effectiveness.not_very_effective?(tmod) then "resist"
        else "neutral" end
  [dmg, 100.0 * dmg / target.totalhp, eff]
end

tide = BuildTeam.mon(TIDE)
puts "DEFENDER: Tidehammer  HP #{tide.totalhp}  Def #{tide.defense}  SpD #{tide.spdef}  (WATER/GROUND)"
puts "Verdict key: % of Tidehammer's 314 HP. <50% = can eat two / SD safely once."
puts

HITS.each do |spec, moves|
  unless valid_species?(spec[:species])
    puts "-- #{spec[:species]}: NOT IN DEX (skipped)"
    next
  end
  att = BuildTeam.mon(spec)
  moves.each do |mv|
    unless valid_move?(mv)
      puts "  #{spec[:species].to_s.ljust(11)} #{mv}: move not in this build (skipped)"
      next
    end
    lo, = calc(att, tide, mv, roll: 0)
    hi, hi_pct, eff = calc(att, tide, mv, roll: 15)
    lo_pct = 100.0 * lo / tide.totalhp
    label = "#{spec[:species].to_s.ljust(11)} #{mv.to_s.ljust(12)} [#{spec[:item].to_s.ljust(11)}]"
    if eff == "immune"
      puts "  #{label} IMMUNE"
    else
      v = if lo_pct >= 100 then "OHKOs you"
          elsif hi_pct >= 100 then "may OHKO (#{'%.0f' % (100.0 * (hi_pct - 100) / (hi_pct - lo_pct))}%)"
          elsif hi_pct >= 50 then "2HKOs you"
          else "you SD freely" end
      puts "  #{label} #{lo}-#{hi}  (#{'%.1f' % lo_pct}%-#{'%.1f' % hi_pct}%)  [#{eff}]  #{v}"
    end
  end
end
