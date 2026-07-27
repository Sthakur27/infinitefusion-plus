# READ-ONLY damage-calc benchmark: "Tidehammer" Azumarill/Marowak
# (Huge Power + Thick Club) vs common vanilla OU/Uber physical tanks.
# Boots the real engine headless and calls the game's own pbCalcDamage.
# Never touches the save (save_data is neutered in shim.rb).
require_relative 'build_team'   # pulls in battle.rb -> engine.rb
SimEngine.boot
$DEBUG = false

# --- deterministic rolls: no crits, controlled 85%/100% variance ------------
class PokeBattle_Move
  def pbIsCritical?(user, target); false; end
end
$ROLL = 15   # pbRandom(16) -> 15 = 100% (max roll); 0 = 85% (min roll)

ATTACKER = {
  head: :AZUMARILL, body: :MAROWAK,
  ability: :HUGEPOWER, nature: :ADAMANT, item: :THICKCLUB,
  moves: [:SWORDSDANCE, :AQUAJET, :EARTHQUAKE, :KNOCKOFF],
  evs: { HP: 4, ATTACK: 252, SPEED: 252 }
}

# Standard physically-defensive vanilla builds (Smogon-style spreads).
DEFENDERS = [
  { tier: "OU",   species: :TOXAPEX,   ability: :REGENERATOR, nature: :BOLD,    item: :LEFTOVERS,   evs: { HP: 252, DEFENSE: 252, SPECIAL_DEFENSE: 4 } },
  { tier: "OU",   species: :FERROTHORN,ability: :IRONBARBS,   nature: :RELAXED, item: :LEFTOVERS,   evs: { HP: 252, DEFENSE: 252, SPECIAL_DEFENSE: 4 } },
  { tier: "OU",   species: :SKARMORY,  ability: :STURDY,      nature: :IMPISH,  item: :ROCKYHELMET, evs: { HP: 252, DEFENSE: 252, SPEED: 4 } },
  { tier: "OU",   species: :HIPPOWDON, ability: :SANDSTREAM,  nature: :IMPISH,  item: :LEFTOVERS,   evs: { HP: 252, DEFENSE: 252, SPECIAL_DEFENSE: 4 } },
  { tier: "OU",   species: :SLOWBRO,   ability: :REGENERATOR, nature: :BOLD,    item: :LEFTOVERS,   evs: { HP: 252, DEFENSE: 252, SPECIAL_DEFENSE: 4 } },
  { tier: "OU",   species: :CLEFABLE,  ability: :UNAWARE,     nature: :BOLD,    item: :LEFTOVERS,   evs: { HP: 252, DEFENSE: 252, SPECIAL_DEFENSE: 4 } },
  { tier: "OU",   species: :QUAGSIRE,  ability: :UNAWARE,     nature: :IMPISH,  item: :LEFTOVERS,   evs: { HP: 252, DEFENSE: 252, SPECIAL_DEFENSE: 4 } },
  { tier: "OU",   species: :TANGROWTH, ability: :REGENERATOR, nature: :RELAXED, item: :LEFTOVERS,   evs: { HP: 252, DEFENSE: 252, SPECIAL_DEFENSE: 4 } },
  { tier: "Uber", species: :LUGIA,     ability: :MULTISCALE,  nature: :BOLD,    item: :LEFTOVERS,   evs: { HP: 252, DEFENSE: 252, SPECIAL_DEFENSE: 4 } },
  { tier: "Uber", species: :HOOH,      ability: :REGENERATOR, nature: :IMPISH,  item: :LEFTOVERS,   evs: { HP: 252, DEFENSE: 252, SPECIAL_DEFENSE: 4 } },
  { tier: "Uber", species: :GIRATINA,  ability: :PRESSURE,    nature: :IMPISH,  item: :LEFTOVERS,   evs: { HP: 252, DEFENSE: 252, SPECIAL_DEFENSE: 4 } },
  { tier: "Uber", species: :GROUDON,   ability: :DROUGHT,     nature: :IMPISH,  item: :LEFTOVERS,   evs: { HP: 252, DEFENSE: 252, SPECIAL_DEFENSE: 4 } },
  { tier: "Uber", species: :ARCEUS,    ability: :MULTITYPE,   nature: :IMPISH,  item: :LEFTOVERS,   evs: { HP: 252, DEFENSE: 252, SPECIAL_DEFENSE: 4 } },
  { tier: "Uber", species: :DIALGA,    ability: :PRESSURE,    nature: :RELAXED, item: :LEFTOVERS,   evs: { HP: 252, DEFENSE: 252, SPECIAL_DEFENSE: 4 } },
  { tier: "Uber", species: :KYOGRE,    ability: :DRIZZLE,     nature: :BOLD,    item: :LEFTOVERS,   evs: { HP: 252, DEFENSE: 252, SPECIAL_DEFENSE: 4 } },
]

def valid_species?(sym)
  begin
    GameData::Species.get(sym).id == sym
  rescue
    false
  end
end

# One damage number from the REAL engine (fresh battle per call: no state bleed).
# Returns [dmg, pct, typemod_str, eff_atk_used]
def calc(att_pk, def_pk, move_id, roll:, atk_stage: 0, weather: nil)
  $ROLL = roll
  t1 = SimBattle.make_trainer("P1", [att_pk])
  t2 = SimBattle.make_trainer("P2", [def_pk])
  scene  = PokeBattle_DebugSceneNoLogging.new
  battle = PokeBattle_Battle.new(scene, t1.party, t2.party, t1, t2)
  battle.debug = true; battle.controlPlayer = true; battle.internalBattle = false
  def battle.pbRandom(x); $ROLL < x ? $ROLL : x - 1; end
  battle.pbCreateBattler(0, att_pk, 0)
  battle.pbCreateBattler(1, def_pk, 0)
  if weather
    battle.field.weather = weather
    battle.field.weatherDuration = -1
  end
  user   = battle.battlers[0]
  target = battle.battlers[1]
  user.stages[:ATTACK] = atk_stage
  move = PokeBattle_Move.from_pokemon_move(battle, Pokemon::Move.new(move_id))
  target.damageState.reset
  ctype = move.pbCalcType(user)
  move.instance_variable_set(:@calcType, ctype)
  tmod = move.pbCalcTypeMod(ctype, user, target)
  target.damageState.typeMod = tmod
  return [0, 0.0, "immune"] if Effectiveness.ineffective?(tmod)
  move.pbCalcDamage(user, target)
  dmg = target.damageState.calcDamage
  eff = if Effectiveness.super_effective?(tmod) then "SE"
        elsif Effectiveness.not_very_effective?(tmod) then "resist"
        else "neutral" end
  [dmg, 100.0 * dmg / target.totalhp, eff]
end

att = BuildTeam.mon(ATTACKER)
puts "ATTACKER: Azumarill/Marowak \"Tidehammer\"  L#{att.level}"
puts "  types: #{att.types.map(&:to_s).join('/')}  ability: #{att.ability&.id}  item: #{att.item&.id}"
puts "  nature: #{att.nature.id}  Atk #{att.attack}  Spe #{att.speed}  HP #{att.totalhp}"
puts "  (Huge Power x2 * Thick Club x2 => effective Atk #{att.attack * 4} on physical moves)"
puts

MOVES = [:AQUAJET, :EARTHQUAKE, :KNOCKOFF]

DEFENDERS.each do |d|
  unless valid_species?(d[:species])
    puts "-- #{d[:species]}: NOT IN THIS DEX (skipped)"
    next
  end
  def_pk = BuildTeam.mon(d)
  puts "== [#{d[:tier]}] #{d[:species]}  #{def_pk.types.map(&:to_s).join('/')}  " \
       "HP #{def_pk.totalhp}  Def #{def_pk.defense}  [#{def_pk.ability&.id}, #{def_pk.item&.id}]"
  MOVES.each do |mv|
    [0, 2].each do |stage|
      lo, = calc(att, def_pk, mv, roll: 0,  atk_stage: stage)
      hi, hp_pct, eff = calc(att, def_pk, mv, roll: 15, atk_stage: stage)
      lo_pct = 100.0 * lo / def_pk.totalhp
      tag = stage == 2 ? "+2 " : "   "
      next if eff == "immune" && stage == 2
      label = "#{tag}#{mv}"
      if eff == "immune"
        puts "   #{label.ljust(18)} IMMUNE"
      else
        puts "   #{label.ljust(18)} #{lo}-#{hi}  (#{'%.1f' % lo_pct}%-#{'%.1f' % hp_pct}%)  [#{eff}]"
      end
    end
  end
  # rain-boosted Aqua Jet (Tidehammer sits on the Rain team)
  lo, = calc(att, def_pk, :AQUAJET, roll: 0, weather: :Rain)
  hi, hp_pct, eff = calc(att, def_pk, :AQUAJET, roll: 15, weather: :Rain)
  unless eff == "immune"
    puts "   rain AQUAJET       #{lo}-#{hi}  (#{'%.1f' % (100.0 * lo / def_pk.totalhp)}%-#{'%.1f' % hp_pct}%)  [#{eff}]"
  end
  puts
end
