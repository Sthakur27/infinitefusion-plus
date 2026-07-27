# READ-ONLY: STAB Aqua Jet benchmark for "Tidehammer" (Azumarill/Marowak,
# Huge Power + Thick Club) as a PRIORITY revenge-kill tool vs common
# offensive OU/Uber threats (standard frail 0 HP / 0 Def spreads).
require_relative 'build_team'
SimEngine.boot
$DEBUG = false

class PokeBattle_Move
  def pbIsCritical?(user, target); false; end
end
$ROLL = 15

ATTACKER = {
  head: :AZUMARILL, body: :MAROWAK,
  ability: :HUGEPOWER, nature: :ADAMANT, item: :THICKCLUB,
  moves: [:SWORDSDANCE, :AQUAJET, :EARTHQUAKE, :KNOCKOFF],
  evs: { HP: 4, ATTACK: 252, SPEED: 252 }
}

# Common offensive threats: max Speed, no bulk investment (revenge-kill targets).
THREATS = [
  { tier: "OU",   species: :GARCHOMP,  ability: :ROUGHSKIN,   nature: :JOLLY },
  { tier: "OU",   species: :DRAGONITE, ability: :MULTISCALE,  nature: :ADAMANT },
  { tier: "OU",   species: :VOLCARONA, ability: :FLAMEBODY,   nature: :TIMID },
  { tier: "OU",   species: :WEAVILE,   ability: :PRESSURE,    nature: :JOLLY },
  { tier: "OU",   species: :BISHARP,   ability: :DEFIANT,     nature: :JOLLY },
  { tier: "OU",   species: :TYRANITAR, ability: :SANDSTREAM,  nature: :JOLLY },
  { tier: "OU",   species: :HEATRAN,   ability: :FLASHFIRE,   nature: :TIMID },
  { tier: "OU",   species: :SCIZOR,    ability: :TECHNICIAN,  nature: :ADAMANT },
  { tier: "OU",   species: :SALAMENCE, ability: :INTIMIDATE,  nature: :JOLLY },
  { tier: "OU",   species: :GENGAR,    ability: :CURSEDBODY,  nature: :TIMID },
  { tier: "OU",   species: :STARMIE,   ability: :ANALYTIC,    nature: :TIMID },
  { tier: "OU",   species: :INFERNAPE, ability: :BLAZE,       nature: :JOLLY },
  { tier: "Uber", species: :MEWTWO,    ability: :PRESSURE,    nature: :TIMID },
  { tier: "Uber", species: :RAYQUAZA,  ability: :AIRLOCK,     nature: :JOLLY },
  { tier: "Uber", species: :DARKRAI,   ability: :BADDREAMS,   nature: :TIMID },
  { tier: "Uber", species: :BLAZIKEN,  ability: :SPEEDBOOST,  nature: :ADAMANT },
  { tier: "Uber", species: :GROUDON,   ability: :DROUGHT,     nature: :ADAMANT },
  { tier: "Uber", species: :KYOGRE,    ability: :DRIZZLE,     nature: :TIMID },
  { tier: "Uber", species: :RESHIRAM,  ability: :TURBOBLAZE,  nature: :TIMID },
  { tier: "Uber", species: :ZEKROM,    ability: :TERAVOLT,    nature: :ADAMANT },
]

def valid_species?(sym)
  begin
    GameData::Species.get(sym).id == sym
  rescue
    false
  end
end

def calc(att_pk, def_pk, move_id, roll:, atk_stage: 0, weather: nil, hp_frac: 1.0)
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
  target.hp = [(target.totalhp * hp_frac).round, 1].max
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
puts "Tidehammer STAB AQUA JET (40 BP, priority +1, STAB, eff.Atk #{att.attack * 4})"
puts "Speed: #{att.speed} (for reference vs each threat below)"
puts

def verdict(lo_pct, hi_pct)
  if lo_pct >= 100 then "guaranteed OHKO"
  elsif hi_pct >= 100 then "#{'%.0f' % (100.0 * (hi_pct - 100) / (hi_pct - lo_pct))}% chance OHKO"
  elsif lo_pct >= 50 then "guaranteed 2HKO"
  elsif hi_pct >= 50 then "possible 2HKO"
  elsif lo_pct >= 100.0/3 then "guaranteed 3HKO"
  else "#{(100.0 / hi_pct).ceil}HKO at best" end
end

THREATS.each do |d|
  unless valid_species?(d[:species])
    puts "-- #{d[:species]}: NOT IN THIS DEX (skipped)"
    next
  end
  spec = d.merge(evs: { HP: 0, ATTACK: 4, SPEED: 252 })
  def_pk = BuildTeam.mon(spec)
  rows = {}
  { "+0      " => [0, nil], "+2 (SD) " => [2, nil], "+0 rain " => [0, :Rain], "+2 rain " => [2, :Rain] }.each do |label, (st, w)|
    lo, = calc(att, def_pk, :AQUAJET, roll: 0, atk_stage: st, weather: w)
    hi, hi_pct, eff = calc(att, def_pk, :AQUAJET, roll: 15, atk_stage: st, weather: w)
    lo_pct = 100.0 * lo / def_pk.totalhp
    rows[label] = [lo, hi, lo_pct, hi_pct, eff]
  end
  eff = rows["+0      "][4]
  spe_note = def_pk.speed > att.speed ? "outspeeds you (#{def_pk.speed})" : "slower (#{def_pk.speed})"
  puts "== [#{d[:tier]}] #{d[:species]}  #{def_pk.types.map(&:to_s).join('/')}  HP #{def_pk.totalhp}  #{spe_note}  [#{eff}]"
  rows.each do |label, (lo, hi, lo_pct, hi_pct, _)|
    puts "   #{label} #{lo}-#{hi}  (#{'%.1f' % lo_pct}%-#{'%.1f' % hi_pct}%)   #{verdict(lo_pct, hi_pct)}"
  end
  puts
end
