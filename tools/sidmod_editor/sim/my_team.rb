# Claude's 3 teams, built to my principles. Rules: 12 distinct base species per team,
# no legendary >=600 BST (Suicune 580 is allowed; no Regigigas used).
require_relative 'build_team'

MY_TEAMS = {
  # ---- MOMENTUM: balance, VoltTurn + speed control, weather-independent ----
  "Momentum" => [
    { head: :MAGNEZONE, body: :GARDEVOIR, ability: :ANALYTIC, item: :CHOICESPECS, nature: :MODEST,
      moves: [:VOLTSWITCH, :MOONBLAST, :FLASHCANNON, :THUNDERBOLT], evs: { SPECIAL_ATTACK: 252, SPEED: 252, HP: 6 } },
    { head: :RHYPERIOR, body: :GARCHOMP, ability: :ROUGHSKIN, item: :LIFEORB, nature: :JOLLY,
      moves: [:SWORDSDANCE, :EARTHQUAKE, :OUTRAGE, :IRONHEAD], evs: { ATTACK: 252, SPEED: 252, HP: 6 } },
    { head: :GENGAR, body: :ROTOM, ability: :LEVITATE, item: :LIFEORB, nature: :TIMID,
      moves: [:NASTYPLOT, :SHADOWBALL, :THUNDERBOLT, :SLUDGEBOMB], evs: { SPECIAL_ATTACK: 252, SPEED: 252, HP: 6 } },
    { head: :LUCARIO, body: :SCIZOR, ability: :TECHNICIAN, item: :LIFEORB, nature: :ADAMANT,
      moves: [:SWORDSDANCE, :BULLETPUNCH, :CLOSECOMBAT, :BUGBITE], evs: { ATTACK: 252, SPEED: 252, HP: 6 } },
    { head: :COFAGRIGUS, body: :SKARMORY, ability: :STURDY, item: :LEFTOVERS, nature: :IMPISH,
      moves: [:STEALTHROCK, :ROOST, :WILLOWISP, :WHIRLWIND], evs: { HP: 252, DEFENSE: 252, SPECIAL_DEFENSE: 6 } },
    { head: :WEAVILE, body: :AERODACTYL, ability: :TOUGHCLAWS, item: :CHOICESCARF, nature: :JOLLY,
      moves: [:KNOCKOFF, :ICICLECRASH, :STONEEDGE, :UTURN], evs: { ATTACK: 252, SPEED: 252, HP: 6 } },
  ],

  # ---- OVERLOAD: hyper-offense, fast mixed/special breakers, coverage no wall survives ----
  "Overload" => [
    { head: :GENGAR, body: :GRENINJA, ability: :PROTEAN, item: :LIFEORB, nature: :TIMID,
      moves: [:NASTYPLOT, :SHADOWBALL, :ICEBEAM, :SLUDGEWAVE], evs: { SPECIAL_ATTACK: 252, SPEED: 252, HP: 6 } },
    { head: :LUCARIO, body: :INFERNAPE, ability: :IRONFIST, item: :LIFEORB, nature: :JOLLY,
      moves: [:SWORDSDANCE, :CLOSECOMBAT, :FLAREBLITZ, :BULLETPUNCH], evs: { ATTACK: 252, SPEED: 252, HP: 6 } },
    { head: :HYDREIGON, body: :SALAMENCE, ability: :LEVITATE, item: :LIFEORB, nature: :TIMID,
      moves: [:NASTYPLOT, :DRACOMETEOR, :DARKPULSE, :FLAMETHROWER], evs: { SPECIAL_ATTACK: 252, SPEED: 252, HP: 6 } },
    { head: :ALAKAZAM, body: :SCEPTILE, ability: :MAGICGUARD, item: :LIFEORB, nature: :TIMID,
      moves: [:CALMMIND, :PSYCHIC, :ENERGYBALL, :FOCUSBLAST], evs: { SPECIAL_ATTACK: 252, SPEED: 252, HP: 6 } },
    { head: :ELECTIVIRE, body: :AERODACTYL, ability: :MOTORDRIVE, item: :CHOICESCARF, nature: :JOLLY,
      moves: [:WILDCHARGE, :EARTHQUAKE, :ICEPUNCH, :UTURN], evs: { ATTACK: 252, SPEED: 252, HP: 6 } },
    { head: :WEAVILE, body: :MAMOSWINE, ability: :THICKFAT, item: :LIFEORB, nature: :JOLLY,
      moves: [:SWORDSDANCE, :ICICLECRASH, :EARTHQUAKE, :ICESHARD], evs: { ATTACK: 252, SPEED: 252, HP: 6 } },
  ],

  # ---- BUNKER: fat balance, hazards + Regenerator pivots + priority + a CM wincon ----
  "Bunker" => [
    { head: :FERROTHORN, body: :COFAGRIGUS, ability: :IRONBARBS, item: :LEFTOVERS, nature: :IMPISH,
      moves: [:SPIKES, :LEECHSEED, :POWERWHIP, :WILLOWISP], evs: { HP: 252, DEFENSE: 252, SPECIAL_DEFENSE: 6 } },
    { head: :SLOWBRO, body: :TANGROWTH, ability: :REGENERATOR, item: :LEFTOVERS, nature: :BOLD,
      moves: [:SCALD, :GIGADRAIN, :SLACKOFF, :TOXIC], evs: { HP: 252, DEFENSE: 252, SPECIAL_DEFENSE: 6 } },
    { head: :BLISSEY, body: :SKARMORY, ability: :NATURALCURE, item: :LEFTOVERS, nature: :CALM,
      moves: [:SOFTBOILED, :SEISMICTOSS, :TOXIC, :ROOST], evs: { HP: 252, SPECIAL_DEFENSE: 252, DEFENSE: 6 } },
    { head: :LUCARIO, body: :SCIZOR, ability: :TECHNICIAN, item: :LIFEORB, nature: :ADAMANT,
      moves: [:SWORDSDANCE, :BULLETPUNCH, :CLOSECOMBAT, :BUGBITE], evs: { ATTACK: 252, SPEED: 252, HP: 6 } },
    { head: :STARMIE, body: :TENTACRUEL, ability: :NATURALCURE, item: :LEFTOVERS, nature: :TIMID,
      moves: [:RAPIDSPIN, :SCALD, :RECOVER, :ICEBEAM], evs: { HP: 252, SPEED: 252, DEFENSE: 6 } },
    { head: :SUICUNE, body: :EMPOLEON, ability: :PRESSURE, item: :LEFTOVERS, nature: :BOLD,
      moves: [:CALMMIND, :SCALD, :FLASHCANNON, :REST], evs: { HP: 252, DEFENSE: 252, SPEED: 6 } },
  ],
}

MY_TEAM_SPEC = MY_TEAMS["Momentum"]   # back-compat for existing gauntlet
