# READ-ONLY: Sylveon/Dragonite (Pixilate, Choice Band) EXTREME SPEED benchmark
# vs the same offensive threat list as dmgcalc_aquajet.rb, for direct comparison.
require_relative 'build_team'
SimEngine.boot
$DEBUG = false

class PokeBattle_Move
  def pbIsCritical?(user, target); false; end
end
$ROLL = 15

ATTACKER = {
  head: :SYLVEON, body: :DRAGONITE,
  ability: :PIXILATE, nature: :ADAMANT, item: :CHOICEBAND,
  moves: [:EXTREMESPEED],
  evs: { HP: 4, ATTACK: 252, SPEED: 252 }
}

THREATS = [
  { tier: "OU",   species: :GARCHOMP,  ability: :ROUGHSKIN,   nature: :JOLLY },
  { tier: "OU",   species: :DRAGONITE, ability: :MULTISCALE,  nature: :ADAMANT },
  { tier: "OU",   species: :VOLCARONA, ability: :FLAMEBODY,   nature: :TIMID },
  { tier: "OU",   species: :WEAVILE,   ability: :PRESSURE,    nature: :JOLLY },
  { tier: "OU",   species: :BISHARP,   ability: :DEFIANT,     nature: :JOLLY },
  { tier: "OU",   species: :TYRANITAR, ability: :SANDSTREAM,  nature: :JOLLY },
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

def calc(att_pk, def_pk, move_id, roll:)
  $ROLL = roll
  t1 = SimBattle.make_trainer("P1", [att_pk])
  t2 = SimBattle.make_trainer("P2", [def_pk])
  scene  = PokeBattle_DebugSceneNoLogging.new
  battle = PokeBattle_Battle.new(scene, t1.party, t2.party, t1, t2)
  battle.debug = true; battle.controlPlayer = true; battle.internalBattle = false
  def battle.pbRandom(x); $ROLL < x ? $ROLL : x - 1; end
  battle.pbCreateBattler(0, att_pk, 0)
  battle.pbCreateBattler(1, def_pk, 0)
  user   = battle.battlers[0]
  target = battle.battlers[1]
  move = PokeBattle_Move.from_pokemon_move(battle, Pokemon::Move.new(move_id))
  target.damageState.reset
  ctype = move.pbCalcType(user)
  move.instance_variable_set(:@calcType, ctype)
  tmod = move.pbCalcTypeMod(ctype, user, target)
  target.damageState.typeMod = tmod
  return [0, 0.0, "immune", ctype] if Effectiveness.ineffective?(tmod)
  move.pbCalcDamage(user, target)
  dmg = target.damageState.calcDamage
  eff = if Effectiveness.super_effective?(tmod) then "SE"
        elsif Effectiveness.not_very_effective?(tmod) then "resist"
        else "neutral" end
  [dmg, 100.0 * dmg / target.totalhp, eff, ctype]
end

def verdict(lo_pct, hi_pct)
  if lo_pct >= 100 then "guaranteed OHKO"
  elsif hi_pct >= 100 then "#{'%.0f' % (100.0 * (hi_pct - 100) / (hi_pct - lo_pct))}% chance OHKO"
  elsif lo_pct >= 50 then "guaranteed 2HKO"
  elsif hi_pct >= 50 then "possible 2HKO"
  elsif lo_pct >= 100.0/3 then "guaranteed 3HKO"
  else "#{(100.0 / hi_pct).ceil}HKO at best" end
end

att = BuildTeam.mon(ATTACKER)
puts "ATTACKER: Sylveon/Dragonite  L#{att.level}"
puts "  types: #{att.types.map(&:to_s).join('/')}  ability: #{att.ability&.id}  item: #{att.item&.id}"
puts "  nature: #{att.nature.id}  Atk #{att.attack}  Spe #{att.speed}  HP #{att.totalhp}"
puts "  Choice Band x1.5 => effective Atk #{(att.attack * 1.5).to_i}"
puts

THREATS.each do |d|
  unless valid_species?(d[:species])
    puts "-- #{d[:species]}: NOT IN THIS DEX (skipped)"
    next
  end
  spec = d.merge(evs: { HP: 0, ATTACK: 4, SPEED: 252 })
  def_pk = BuildTeam.mon(spec)
  lo, _, _, = calc(att, def_pk, :EXTREMESPEED, roll: 0)
  hi, hi_pct, eff, ctype = calc(att, def_pk, :EXTREMESPEED, roll: 15)
  lo_pct = 100.0 * lo / def_pk.totalhp
  spe_note = def_pk.speed > att.speed ? "outspeeds (#{def_pk.speed})" : "slower (#{def_pk.speed})"
  if eff == "immune"
    puts "[#{d[:tier]}] #{d[:species].to_s.ljust(10)} #{def_pk.types.map(&:to_s).join('/').ljust(16)} IMMUNE (as #{ctype})"
  else
    puts "[#{d[:tier]}] #{d[:species].to_s.ljust(10)} #{def_pk.types.map(&:to_s).join('/').ljust(16)} HP #{def_pk.totalhp}  #{spe_note.ljust(16)} as #{ctype} [#{eff}]  #{lo}-#{hi} (#{'%.1f' % lo_pct}%-#{'%.1f' % hi_pct}%)  #{verdict(lo_pct, hi_pct)}"
  end
end
