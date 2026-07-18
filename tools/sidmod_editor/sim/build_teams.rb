# Draft the 6 deliverable teams (OU: balance/rain/sun/sand; Ubers x2). Build + validate every
# fusion (species in-dex, typing, stats, ability). Writes reports/final/field_specs.json
require 'json'; require 'fileutils'
# Parse controls BEFORE boot (engine breaks JSON.parse afterward)
CTRL_ARENA = (JSON.parse(File.read(File.join(__dir__, 'reports', 'arena', 'field_specs.json'))) rescue {})
CTRL_HF    = (JSON.parse(File.read(File.join(__dir__, 'reports', 'hf', 'field_specs.json'))) rescue {})
require_relative 'build_team'
require_relative 'editor'
SimEngine.boot
$DEBUG = false
OUT = File.join(__dir__, 'reports', 'final'); FileUtils.mkdir_p(OUT)

def m(head, body, ability, item, nature, moves, evs)
  { "head"=>head, "body"=>body, "ability"=>ability, "item"=>item, "nature"=>nature,
    "moves"=>moves, "evs"=>evs, "level"=>100 }
end
PHYS = {"ATTACK"=>252,"SPEED"=>252,"HP"=>4}; SPEC = {"SPECIAL_ATTACK"=>252,"SPEED"=>252,"HP"=>4}
PDEF = {"HP"=>252,"DEFENSE"=>252,"SPECIAL_DEFENSE"=>4}; SDEF = {"HP"=>252,"SPECIAL_DEFENSE"=>252,"DEFENSE"=>4}

teams = {}
# ---------- OU BALANCE ----------
teams["OUBalance"] = [
  m("FERROTHORN","SKARMORY","IRONBARBS","LEFTOVERS","IMPISH",%w[STEALTHROCK SPIKES LEECHSEED WHIRLWIND],PDEF),
  m("SLOWBRO","TANGROWTH","REGENERATOR","LEFTOVERS","BOLD",%w[SCALD GIGADRAIN SLACKOFF TOXIC],PDEF),
  m("GLISCOR","MILOTIC","POISONHEAL","TOXICORB","IMPISH",%w[EARTHQUAKE TOXIC ROOST PROTECT],PDEF),
  m("ROTOM","GYARADOS","LEVITATE","LEFTOVERS","BOLD",%w[VOLTSWITCH HYDROPUMP WILLOWISP THUNDERBOLT],SPEC),
  m("DRAGONITE","SCIZOR","MULTISCALE","LEFTOVERS","ADAMANT",%w[DRAGONDANCE DRAGONCLAW EARTHQUAKE ROOST],PHYS),
  m("STARMIE","TENTACRUEL","NATURALCURE","LEFTOVERS","TIMID",%w[RAPIDSPIN SCALD RECOVER ICEBEAM],SPEC),
]
# ---------- OU RAIN ----------
teams["OURain"] = [
  m("POLITOED","WHIMSICOTT","DRIZZLE","LEFTOVERS","TIMID",%w[UTURN ENCORE SCALD ICEBEAM],SPEC),
  m("KINGDRA","EMPOLEON","SWIFTSWIM","LIFEORB","MODEST",%w[HYDROPUMP DRACOMETEOR ICEBEAM FLASHCANNON],SPEC),
  m("POLIWRATH","KABUTOPS","SWIFTSWIM","LIFEORB","ADAMANT",%w[WATERFALL CLOSECOMBAT STONEEDGE MACHPUNCH],PHYS),
  m("LUDICOLO","SCEPTILE","SWIFTSWIM","LIFEORB","MODEST",%w[SURF GIGADRAIN ICEBEAM FOCUSBLAST],SPEC),
  m("FERROTHORN","SKARMORY","IRONBARBS","LEFTOVERS","IMPISH",%w[STEALTHROCK SPIKES LEECHSEED WHIRLWIND],PDEF),
  m("DRAGONITE","SCIZOR","MULTISCALE","LEFTOVERS","ADAMANT",%w[DRAGONDANCE DRAGONCLAW EARTHQUAKE ROOST],PHYS),
]
# ---------- OU SUN ----------
teams["OUSun"] = [
  m("NINETALES","WHIMSICOTT","DROUGHT","LEFTOVERS","TIMID",%w[SPORE UTURN ENCORE FLAMETHROWER],SPEC),
  m("VENUSAUR","CHANDELURE","CHLOROPHYLL","LIFEORB","MODEST",%w[SOLARBEAM FLAMETHROWER GIGADRAIN SLUDGEBOMB],SPEC),
  m("CHARIZARD","HYDREIGON","SOLARPOWER","CHOICESPECS","MODEST",%w[FLAMETHROWER FIREBLAST DRACOMETEOR FOCUSBLAST],SPEC),
  m("REGIGIGAS","GLISCOR","POISONHEAL","TOXICORB","ADAMANT",%w[SWORDSDANCE FACADE EARTHQUAKE KNOCKOFF],PHYS),
  m("BLISSEY","SHUCKLE","NATURALCURE","LEFTOVERS","BOLD",%w[STICKYWEB SEISMICTOSS TOXIC SOFTBOILED],PDEF),
  m("LEAFEON","ARCANINE","CHLOROPHYLL","LIFEORB","JOLLY",%w[SWORDSDANCE LEAFBLADE FLAREBLITZ EARTHQUAKE],PHYS),
]
# ---------- OU SAND (bulky sand) ----------
teams["OUSand"] = [
  m("TYRANITAR","AERODACTYL","SANDSTREAM","LEFTOVERS","IMPISH",%w[STEALTHROCK STONEEDGE EARTHQUAKE PURSUIT],PDEF),
  m("GARCHOMP","HAXORUS","MOLDBREAKER","CHOICESCARF","JOLLY",%w[EARTHQUAKE OUTRAGE STONEEDGE IRONHEAD],PHYS),
  m("FERROTHORN","SKARMORY","IRONBARBS","LEFTOVERS","IMPISH",%w[STEALTHROCK SPIKES LEECHSEED WHIRLWIND],PDEF),
  m("RHYPERIOR","SALAMENCE","ROCKHEAD","CHOICEBAND","ADAMANT",%w[EARTHQUAKE STONEEDGE MEGAHORN ICEPUNCH],PHYS),
  m("GLISCOR","MILOTIC","POISONHEAL","TOXICORB","IMPISH",%w[EARTHQUAKE TOXIC ROOST PROTECT],PDEF),
  m("DRAGONITE","SCIZOR","MULTISCALE","LEFTOVERS","ADAMANT",%w[DRAGONDANCE DRAGONCLAW EARTHQUAKE ROOST],PHYS),
]
# ---------- UBERS 1 (BALANCE) ----------
teams["Ubers1"] = [
  m("DARKRAI","HYDREIGON","LEVITATE","LIFEORB","TIMID",%w[NASTYPLOT DARKPULSE DRACOMETEOR FOCUSBLAST],SPEC),
  m("KYOGRE","MEW","DRIZZLE","LEFTOVERS","TIMID",%w[WATERSPOUT SPORE QUIVERDANCE ICEBEAM],SPEC),
  m("GROUDON","GLISCOR","POISONHEAL","TOXICORB","ADAMANT",%w[SWORDSDANCE EARTHQUAKE KNOCKOFF THUNDERPUNCH],PHYS),
  m("KYUREM","METAGROSS","CLEARBODY","CHOICESCARF","JOLLY",%w[ICICLECRASH DRAGONCLAW EARTHQUAKE IRONHEAD],PHYS),
  m("SLAKING","DRAGONITE","MULTISCALE","LIFEORB","ADAMANT",%w[EXTREMESPEED EARTHQUAKE SWORDSDANCE STONEEDGE],PHYS),
  m("DIALGA","ESPEON","MAGICBOUNCE","LEFTOVERS","MODEST",%w[STEALTHROCK CALMMIND FLASHCANNON AURASPHERE],SPEC),
]
# ---------- UBERS 2 (RAIN OFFENSE + spine) ----------
teams["Ubers2"] = [
  m("KYOGRE","CELEBI","DRIZZLE","CHOICESPECS","MODEST",%w[WATERSPOUT SURF ICEBEAM GIGADRAIN],SPEC),
  m("KINGDRA","ZEKROM","SWIFTSWIM","LIFEORB","ADAMANT",%w[DRAGONDANCE WATERFALL BOLTSTRIKE OUTRAGE],PHYS),
  m("PALKIA","FLYGON","DRYSKIN","LIFEORB","MODEST",%w[CALMMIND SURF DRACOMETEOR FLAMETHROWER],SPEC),
  m("GROUDON","GLISCOR","POISONHEAL","TOXICORB","ADAMANT",%w[SWORDSDANCE EARTHQUAKE KNOCKOFF THUNDERPUNCH],PHYS),
  m("AEGISLASH","LUGIA","MULTISCALE","LEFTOVERS","IMPISH",%w[SPECTRALTHIEF KINGSSHIELD WHIRLWIND TOXIC],PDEF),
  m("FERROTHORN","SKARMORY","IRONBARBS","LEFTOVERS","IMPISH",%w[STEALTHROCK SPIKES LEECHSEED WHIRLWIND],PDEF),
]

# pull in the 3 vanilla controls for the test round-robin (parsed before boot)
teams['OU'] = CTRL_ARENA['OU'] if CTRL_ARENA['OU']
teams['UbersOff'] = CTRL_HF['UbersOff'] if CTRL_HF['UbersOff']
teams['UbersBal'] = CTRL_HF['UbersBal'] if CTRL_HF['UbersBal']

File.write(File.join(OUT, 'field_specs.json'), JSON.generate(teams))
bad = []
teams.each do |name, team|
  puts "\n===== #{name} ====="
  team.each do |mon|
    s = Editor.normalize(mon)
    inv = [s[:head], s[:body], s[:species]].compact.reject { |sp| Editor.valid_species?(sp) }
    bad.concat(inv.map { |sp| "#{name}:#{sp}" })
    begin
      pk = BuildTeam.mon(s)
      types = (pk.types rescue []).map(&:to_s).join('/')
      badmv = (s[:moves] || []).reject { |mv| GameData::Move.exists?(mv) }
      bad.concat(badmv.map { |mv| "#{name}:move #{mv}" })
      puts "  #{s[:head]}/#{s[:body]}".ljust(26) + " #{types.ljust(14)} [#{pk.ability&.id}] Atk#{pk.attack} SpA#{pk.spatk} Spe#{pk.speed} Def#{pk.defense} SpD#{pk.spdef} HP#{pk.totalhp}#{badmv.empty? ? '' : "  BADMOVES=#{badmv.join(',')}"}"
    rescue => e
      bad << "#{name}: BUILD FAIL #{s[:head]}/#{s[:body]} #{e.class}"
    end
  end
end
puts "\n" + (bad.empty? ? "ALL VALID" : "ISSUES:\n  " + bad.uniq.join("\n  "))
