# sidmod: register 3 "vanilla control" benchmark teams (Gen5 OU + Ubers Off/Bal) as
# debug-only trainer opponents, rebattlable from Debug -> Battle options (they also
# get pinned in the battle list, after the Elite Four, before the gym leaders).
#
# These are the standard Smogon teams that were used as controls during team testing.
# They're registered LAZILY (first time the debug battle list is built) into the BASE
# GameData::Trainer / GameData::TrainerType tables. pbLoadTrainer falls back to the base
# Trainer table when the mode-specific table lacks an entry, so these battle in
# Classic / Remix / Expert alike. All mons L100, 31 IVs, real competitive EV spreads +
# natures, best-tier AI (skill 100). No trainer sprite (the battle scene tolerates a
# missing front sprite - see pbCreateTrainerFrontSprite `return if !trainer.bitmap`).

# Custom trainer-type names have no message-table entry (that table is keyed by
# id_number). Make TrainerType#name fall back to real_name; harmless for real types,
# whose message entry is always present so this branch never triggers for them.
class GameData::TrainerType
  unless method_defined?(:sidmod_orig_name)
    alias_method :sidmod_orig_name, :name
    def name
      n = sidmod_orig_name
      (n.nil? || n.empty?) ? @real_name : n
    end
  end
end

# spec tuple: [species, ability, item, nature, [moves], {ev overrides}]
SIDMOD_VANILLA_TEAMS = {
  :SIDMOD_OU => ["Vanilla", "OU", [
    [:TYRANITAR, :SANDSTREAM, :CHOICESCARF, :JOLLY, [:CRUNCH, :STONEEDGE, :PURSUIT, :FIREBLAST], {:ATTACK=>252,:SPEED=>252,:HP=>4}],
    [:FERROTHORN, :IRONBARBS, :LEFTOVERS, :RELAXED, [:STEALTHROCK, :SPIKES, :LEECHSEED, :POWERWHIP], {:HP=>252,:DEFENSE=>252,:SPECIAL_DEFENSE=>4}],
    [:GLISCOR, :POISONHEAL, :TOXICORB, :IMPISH, [:EARTHQUAKE, :TOXIC, :ROOST, :PROTECT], {:HP=>252,:DEFENSE=>252,:SPEED=>4}],
    [:LATIOS, :LEVITATE, :LIFEORB, :TIMID, [:DRACOMETEOR, :PSYSHOCK, :SURF, :ROOST], {:SPECIAL_ATTACK=>252,:SPEED=>252,:HP=>4}],
    [:SCIZOR, :TECHNICIAN, :CHOICEBAND, :ADAMANT, [:BULLETPUNCH, :UTURN, :SUPERPOWER, :PURSUIT], {:ATTACK=>252,:HP=>252,:SPEED=>4}],
    [:JIRACHI, :SERENEGRACE, :LEFTOVERS, :JOLLY, [:IRONHEAD, :BODYSLAM, :FIREPUNCH, :WISH], {:HP=>252,:SPEED=>252,:ATTACK=>4}],
  ]],
  :SIDMOD_UBERSOFF => ["Vanilla", "Ubers (Off)", [
    [:KYOGRE, :DRIZZLE, :CHOICESCARF, :MODEST, [:WATERSPOUT, :THUNDER, :ICEBEAM, :SURF], {:SPECIAL_ATTACK=>252,:SPEED=>252,:HP=>4}],
    [:RAYQUAZA, :AIRLOCK, :LIFEORB, :JOLLY, [:DRAGONDANCE, :EXTREMESPEED, :EARTHQUAKE, :OUTRAGE], {:ATTACK=>252,:SPEED=>252,:HP=>4}],
    [:ARCEUS, :MULTITYPE, :LIFEORB, :JOLLY, [:SWORDSDANCE, :EXTREMESPEED, :EARTHQUAKE, :SHADOWCLAW], {:ATTACK=>252,:SPEED=>252,:HP=>4}],
    [:DARKRAI, :BADDREAMS, :LIFEORB, :TIMID, [:DARKVOID, :NASTYPLOT, :DARKPULSE, :FOCUSBLAST], {:SPECIAL_ATTACK=>252,:SPEED=>252,:HP=>4}],
    [:DIALGA, :PRESSURE, :CHOICESPECS, :MODEST, [:DRACOMETEOR, :FIREBLAST, :THUNDER, :FLASHCANNON], {:SPECIAL_ATTACK=>252,:SPEED=>252,:HP=>4}],
    [:FERROTHORN, :IRONBARBS, :LEFTOVERS, :RELAXED, [:STEALTHROCK, :SPIKES, :LEECHSEED, :POWERWHIP], {:HP=>252,:DEFENSE=>252,:SPECIAL_DEFENSE=>4}],
  ]],
  :SIDMOD_UBERSBAL => ["Vanilla", "Ubers (Bal)", [
    [:GROUDON, :DROUGHT, :LEFTOVERS, :IMPISH, [:STEALTHROCK, :EARTHQUAKE, :DRAGONTAIL, :FIREPUNCH], {:HP=>252,:DEFENSE=>252,:ATTACK=>4}],
    [:KYOGRE, :DRIZZLE, :CHOICESPECS, :MODEST, [:WATERSPOUT, :SURF, :THUNDER, :ICEBEAM], {:SPECIAL_ATTACK=>252,:SPEED=>252,:HP=>4}],
    [:GIRATINA, :PRESSURE, :LEFTOVERS, :IMPISH, [:DRAGONTAIL, :WILLOWISP, :REST, :SLEEPTALK], {:HP=>252,:DEFENSE=>252,:SPECIAL_DEFENSE=>4}],
    [:SCIZOR, :TECHNICIAN, :CHOICEBAND, :ADAMANT, [:BULLETPUNCH, :UTURN, :SUPERPOWER, :PURSUIT], {:ATTACK=>252,:HP=>252,:SPEED=>4}],
    [:LATIAS, :LEVITATE, :LEFTOVERS, :TIMID, [:CALMMIND, :DRAGONPULSE, :PSYSHOCK, :ROOST], {:SPECIAL_ATTACK=>252,:SPEED=>252,:HP=>4}],
    [:MEWTWO, :PRESSURE, :LIFEORB, :TIMID, [:NASTYPLOT, :AURASPHERE, :ICEBEAM, :FIREBLAST], {:SPECIAL_ATTACK=>252,:SPEED=>252,:HP=>4}],
  ]],
}
# insertion order in the pinned battle list (after E4, before gym leaders)
SIDMOD_VANILLA_ORDER = [:SIDMOD_OU, :SIDMOD_UBERSOFF, :SIDMOD_UBERSBAL]

def sidmod_vanilla_mon(spec)
  species, ability, item, nature, moves, evs = spec
  ivs = {}; ev = {}
  GameData::Stat.each_main { |s| ivs[s.id] = 31; ev[s.id] = 0 }
  evs.each { |k, v| ev[k] = v }
  { :species => species, :level => 100, :item => item, :ability => ability,
    :nature => nature, :moves => moves, :iv => ivs, :ev => ev }
end

# Idempotent: registers the 3 vanilla trainer types + trainers into the base tables.
def sidmod_register_vanilla_trainers
  return if GameData::Trainer.exists?(:SIDMOD_OU, "OU", 0)
  idnum = 9001
  SIDMOD_VANILLA_ORDER.each do |id|
    ttype_name, tr_name, specs = SIDMOD_VANILLA_TEAMS[id]
    GameData::TrainerType.register({
      :id => id, :id_number => idnum, :name => ttype_name,
      :base_money => 100, :skill_level => 100, :gender => 2
    })
    GameData::Trainer.register({
      :id => [id, tr_name, 0], :id_number => idnum,
      :trainer_type => id, :name => tr_name, :version => 0, :lose_text => "...",
      :pokemon => specs.map { |sp| sidmod_vanilla_mon(sp) }
    })
    idnum += 1
  end
end

# sidmod: quick "test trainer battle" usable from the debug menu OR the pause-menu
# shortcut. Heals before + after (matches the debug Battle options behaviour).
def sidmod_quick_trainer_battle
  trainerdata = pbListScreen(_INTL("SINGLE TRAINER"), TrainerBattleLister.new(0, false))
  if trainerdata
    $Trainer.heal_party   # sidmod: heal before debug fight
    pbTrainerBattle(trainerdata[0], trainerdata[1], nil, false, trainerdata[2], true)
    $Trainer.heal_party   # sidmod: heal after debug fight
  end
end
