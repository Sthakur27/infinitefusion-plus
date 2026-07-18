# Hand-fix the bottom-3 teams (Box15A, Box15C, Bunker) from round3, write hf/field_specs.json,
# then boot the engine and BUILD each fixed team to validate + print stats/types.
#   ruby hand_fix.rb
require 'json'
IN  = File.join(__dir__, 'reports', 'round3', 'field_specs.json')
OUT_DIR = File.join(__dir__, 'reports', 'hf')
require 'fileutils'; FileUtils.mkdir_p(OUT_DIR)
field = JSON.parse(File.read(IN))

def idx(team, head, body)
  i = team.index { |m| m['head'] == head && m['body'] == body }
  abort "MATCH FAIL: #{head}/#{body} not found" unless i
  i
end
def edit_moves(team, head, body, moves)
  team.find { |m| m['head'] == head && m['body'] == body }['moves'] = moves
end

DIALGA_ESPEON = { "head"=>"DIALGA","body"=>"ESPEON","ability"=>"MAGICBOUNCE","item"=>"LEFTOVERS","nature"=>"MODEST",
  "moves"=>["STEALTHROCK","CALMMIND","FLASHCANNON","AURASPHERE"], "evs"=>{"HP"=>252,"SPECIAL_ATTACK"=>252,"DEFENSE"=>4}, "level"=>100 }
# Water Absorb wall (Quagsire is verified in-dex): hard-walls Kyogre's rain Water Spout. Slow special piece.
QUAG_SLOW = { "head"=>"QUAGSIRE","body"=>"SLOWBRO","ability"=>"WATERABSORB","item"=>"LEFTOVERS","nature"=>"SASSY",
  "moves"=>["STEALTHROCK","RECOVER","SCALD","ICEBEAM"], "evs"=>{"HP"=>252,"SPECIAL_DEFENSE"=>252,"DEFENSE"=>4}, "level"=>100 }
DRAGO_GYARA = { "head"=>"DRAGONITE","body"=>"GYARADOS","ability"=>"MULTISCALE","item"=>"LEFTOVERS","nature"=>"ADAMANT",
  "moves"=>["DRAGONDANCE","DRAGONCLAW","EARTHQUAKE","ROOST"], "evs"=>{"HP"=>4,"ATTACK"=>252,"SPEED"=>252}, "level"=>100 }
SUICUNE_TOGE = { "head"=>"SUICUNE","body"=>"TOGEKISS","ability"=>"SERENEGRACE","item"=>"LEFTOVERS","nature"=>"BOLD",
  "moves"=>["CALMMIND","SCALD","AIRSLASH","ROOST"], "evs"=>{"HP"=>252,"DEFENSE"=>252,"SPECIAL_DEFENSE"=>4}, "level"=>100 }
# --- Rain: commit to actual rain sweeping (Swift Swim), cut off-theme DD sweepers ---
KABUTOPS_KINGLER = { "head"=>"KABUTOPS","body"=>"KINGLER","ability"=>"SWIFTSWIM","item"=>"LIFEORB","nature"=>"ADAMANT",
  "moves"=>["SWORDSDANCE","WATERFALL","STONEEDGE","AQUAJET"], "evs"=>{"ATTACK"=>252,"SPEED"=>252,"HP"=>4}, "level"=>100 }
LUDICOLO_SCEPTILE = { "head"=>"LUDICOLO","body"=>"SCEPTILE","ability"=>"SWIFTSWIM","item"=>"LIFEORB","nature"=>"MODEST",
  "moves"=>["SURF","GIGADRAIN","ICEBEAM","FOCUSBLAST"], "evs"=>{"SPECIAL_ATTACK"=>252,"SPEED"=>252,"HP"=>4}, "level"=>100 }
# --- fusion redesigns (bodies that actually contribute) ---
MAROWAK_ARCEUS = { "head"=>"MAROWAK","body"=>"ARCEUS","ability"=>"ROCKHEAD","item"=>"THICKCLUB","nature"=>"ADAMANT",
  "moves"=>["SWORDSDANCE","EXTREMESPEED","EARTHQUAKE","STONEEDGE"], "evs"=>{"ATTACK"=>252,"SPEED"=>252,"HP"=>4}, "level"=>100 }
GARCHOMP_HAXORUS = { "head"=>"GARCHOMP","body"=>"HAXORUS","ability"=>"MOLDBREAKER","item"=>"LIFEORB","nature"=>"JOLLY",
  "moves"=>["SWORDSDANCE","EARTHQUAKE","OUTRAGE","IRONHEAD"], "evs"=>{"ATTACK"=>252,"SPEED"=>252,"HP"=>4}, "level"=>100 }
# mono Hydreigon: no fusion beats its SpA/typing/Levitate for this slot (body would only dilute it)
MONO_HYDREIGON = { "species"=>"HYDREIGON","ability"=>"LEVITATE","item"=>"LIFEORB","nature"=>"MODEST",
  "moves"=>["NASTYPLOT","DRACOMETEOR","DARKPULSE","FLAMETHROWER"], "evs"=>{"SPECIAL_ATTACK"=>252,"SPEED"=>252,"HP"=>4}, "level"=>100 }
# Box15B: Kyurem/Salamence was a stat-stick 2nd 4x-Ice Flyer next to Groudon. Dialga body =
# Dragon/Steel = Ice-NEUTRAL, de-stacks the quad-Ice seam; keeps Moxie Scarf + Icicle Crash.
KYUREM_DIALGA = { "head"=>"KYUREM","body"=>"DIALGA","ability"=>"MOXIE","item"=>"CHOICESCARF","nature"=>"JOLLY",
  "moves"=>["DRAGONCLAW","ICICLECRASH","IRONHEAD","EARTHQUAKE"], "evs"=>{"ATTACK"=>252,"SPEED"=>252,"HP"=>4}, "level"=>100 }
DRAGONITE_SCIZOR = { "head"=>"DRAGONITE","body"=>"SCIZOR","ability"=>"MULTISCALE","item"=>"LEFTOVERS","nature"=>"ADAMANT",
  "moves"=>["DRAGONDANCE","DRAGONCLAW","EARTHQUAKE","ROOST"], "evs"=>{"ATTACK"=>252,"SPEED"=>252,"HP"=>4}, "level"=>100 }

# --- Box15A ---
a = field['Box15A']
a[idx(a,'ESPEON','METAGROSS')] = DIALGA_ESPEON
a[idx(a,'RAYQUAZA','GARCHOMP')] = MAROWAK_ARCEUS         # cut redundant DD dragon -> Thick Club priority nuke
edit_moves(a,'KYOGRE','TOXAPEX',["SCALD","ICEBEAM","RECOVER","HAZE"])

# --- Box15C ---
c = field['Box15C']
c[idx(c,'RHYPERIOR','STEELIX')] = QUAG_SLOW
edit_moves(c,'REUNICLUS','DUSKNOIR',["TRICKROOM","PSYCHIC","SHADOWBALL","FOCUSBLAST"])
c.find { |m| m['head'] == 'MAROWAK' && m['body'] == 'RHYPERIOR' }['item'] = 'THICKCLUB'  # 2x Atk (isFusionOf Marowak)

# --- Bunker ---
b = field['Bunker']
b[idx(b,'SLOWBRO','TANGROWTH')] = DRAGONITE_SCIZOR       # was Dragonite/Gyarados (= worse Dragonite)
b[idx(b,'SUICUNE','EMPOLEON')]  = SUICUNE_TOGE

# --- Rain ---
r = field['Rain']
r[idx(r,'DRAGONITE','SLAKING')]  = KABUTOPS_KINGLER
r[idx(r,'AZUMARILL','GARCHOMP')] = LUDICOLO_SCEPTILE     # was Ludicolo/Politoed (came out pure Water)
r.find { |m| m['head'] == 'KINGDRA' && m['body'] == 'EMPOLEON' }['item'] = 'LIFEORB'  # de-Choice-lock

# --- Momentum: Rhyperior/Garchomp was weaker+slower than mono-Garchomp ---
m = field['Momentum']
m[idx(m,'RHYPERIOR','GARCHOMP')] = GARCHOMP_HAXORUS

# --- Overload: Hydreigon/Salamence lost Draco STAB + bulk ---
o = field['Overload']
o[idx(o,'HYDREIGON','SALAMENCE')] = MONO_HYDREIGON

# ===== Tier-1 audit fixes (safe set/move/item; no identity or fusion change) =====
# Rain: Thunder is immune-blanked by every Ground wall -> Flamethrower nukes the Steel/Grass walls; give Policott a real move
edit_moves(r, 'TOGEKISS', 'DRAGONITE', %w[FLAMETHROWER HURRICANE MOONBLAST CALMMIND])
edit_moves(r, 'POLITOED', 'WHIMSICOTT', %w[UTURN TAUNT SPORE ENCORE])
# Overload: Geninja Ice Beam is redundant (3 other Ice users) -> Taunt blanks the Spore/phaze lead
edit_moves(o, 'GENGAR', 'GRENINJA', %w[NASTYPLOT SHADOWBALL TAUNT SLUDGEWAVE])
# Box15A: Deoxys off Choice Scarf -> Lum Berry (sleep insurance + no lock); Trick is dead with Lum -> Roost
dx = a.find { |m| m['head'] == 'DEOXYS' && m['body'] == 'LATIOS' }
dx['item'] = 'LUMBERRY'; dx['moves'] = %w[PSYCHIC DRACOMETEOR AURASPHERE ROOST]
# Momentum: Gengar/Rotom needs a Dark/Normal-wall answer -> Focus Blast over Sludge Bomb
edit_moves(m, 'GENGAR', 'ROTOM', %w[NASTYPLOT SHADOWBALL THUNDERBOLT FOCUSBLAST])
# Sand: break the DD-mirror loop + priority; Lum on the lead so it can't be Spore-locked
s = field['Sand']
edit_moves(s, 'AZUMARILL', 'GARCHOMP', %w[EARTHQUAKE WATERFALL DRAGONDANCE AQUAJET])
s.find { |x| x['head'] == 'METAGROSS' && x['body'] == 'HAXORUS' }['item'] = 'LUMBERRY'
# Sun: Charizard/Hydreigon is all-Fire (walled) -> Draco Meteor = weather-independent breaker
su = field['Sun']
edit_moves(su, 'CHARIZARD', 'HYDREIGON', %w[FLAMETHROWER FIREBLAST DRACOMETEOR UTURN])
# Box15B: de-stack the quad-Ice (Kyurem/Salamence -> Kyurem/Dialga, Ice-neutral)
bb = field['Box15B']
bb[idx(bb, 'KYUREM', 'SALAMENCE')] = KYUREM_DIALGA

# ===== Control: 2 vanilla (non-fusion) Gen 5 Ubers teams — benchmark, sim-only, NOT materialized =====
field['UbersOff'] = [
  { "species"=>"KYOGRE","ability"=>"DRIZZLE","item"=>"CHOICESCARF","nature"=>"MODEST","moves"=>%w[WATERSPOUT THUNDER ICEBEAM SURF],"evs"=>{"SPECIAL_ATTACK"=>252,"SPEED"=>252,"HP"=>4},"level"=>100 },
  { "species"=>"RAYQUAZA","ability"=>"AIRLOCK","item"=>"LIFEORB","nature"=>"JOLLY","moves"=>%w[DRAGONDANCE EXTREMESPEED EARTHQUAKE OUTRAGE],"evs"=>{"ATTACK"=>252,"SPEED"=>252,"HP"=>4},"level"=>100 },
  { "species"=>"ARCEUS","ability"=>"MULTITYPE","item"=>"LIFEORB","nature"=>"JOLLY","moves"=>%w[SWORDSDANCE EXTREMESPEED EARTHQUAKE SHADOWCLAW],"evs"=>{"ATTACK"=>252,"SPEED"=>252,"HP"=>4},"level"=>100 },
  { "species"=>"DARKRAI","ability"=>"BADDREAMS","item"=>"LIFEORB","nature"=>"TIMID","moves"=>%w[DARKVOID NASTYPLOT DARKPULSE FOCUSBLAST],"evs"=>{"SPECIAL_ATTACK"=>252,"SPEED"=>252,"HP"=>4},"level"=>100 },
  { "species"=>"DIALGA","ability"=>"PRESSURE","item"=>"CHOICESPECS","nature"=>"MODEST","moves"=>%w[DRACOMETEOR FIREBLAST THUNDER FLASHCANNON],"evs"=>{"SPECIAL_ATTACK"=>252,"SPEED"=>252,"HP"=>4},"level"=>100 },
  { "species"=>"FERROTHORN","ability"=>"IRONBARBS","item"=>"LEFTOVERS","nature"=>"RELAXED","moves"=>%w[STEALTHROCK SPIKES LEECHSEED POWERWHIP],"evs"=>{"HP"=>252,"DEFENSE"=>252,"SPECIAL_DEFENSE"=>4},"level"=>100 },
]
field['UbersBal'] = [
  { "species"=>"GROUDON","ability"=>"DROUGHT","item"=>"LEFTOVERS","nature"=>"IMPISH","moves"=>%w[STEALTHROCK EARTHQUAKE DRAGONTAIL FIREPUNCH],"evs"=>{"HP"=>252,"DEFENSE"=>252,"ATTACK"=>4},"level"=>100 },
  { "species"=>"KYOGRE","ability"=>"DRIZZLE","item"=>"CHOICESPECS","nature"=>"MODEST","moves"=>%w[WATERSPOUT SURF THUNDER ICEBEAM],"evs"=>{"SPECIAL_ATTACK"=>252,"SPEED"=>252,"HP"=>4},"level"=>100 },
  { "species"=>"GIRATINA","ability"=>"PRESSURE","item"=>"LEFTOVERS","nature"=>"IMPISH","moves"=>%w[DRAGONTAIL WILLOWISP REST SLEEPTALK],"evs"=>{"HP"=>252,"DEFENSE"=>252,"SPECIAL_DEFENSE"=>4},"level"=>100 },
  { "species"=>"SCIZOR","ability"=>"TECHNICIAN","item"=>"CHOICEBAND","nature"=>"ADAMANT","moves"=>%w[BULLETPUNCH UTURN SUPERPOWER PURSUIT],"evs"=>{"ATTACK"=>252,"HP"=>252,"SPEED"=>4},"level"=>100 },
  { "species"=>"LATIAS","ability"=>"LEVITATE","item"=>"LEFTOVERS","nature"=>"TIMID","moves"=>%w[CALMMIND DRAGONPULSE PSYSHOCK ROOST],"evs"=>{"SPECIAL_ATTACK"=>252,"SPEED"=>252,"HP"=>4},"level"=>100 },
  { "species"=>"MEWTWO","ability"=>"PRESSURE","item"=>"LIFEORB","nature"=>"TIMID","moves"=>%w[NASTYPLOT AURASPHERE ICEBEAM FIREBLAST],"evs"=>{"SPECIAL_ATTACK"=>252,"SPEED"=>252,"HP"=>4},"level"=>100 },
]

File.write(File.join(OUT_DIR, 'field_specs.json'), JSON.generate(field))
puts "wrote hf/field_specs.json"

# --- validate by building in the engine ---
require_relative 'build_team'
require_relative 'editor'
SimEngine.boot
$DEBUG = false
bad_species = []
%w[Box15A Box15C Bunker Rain Momentum Overload Sand Sun Box15B UbersOff UbersBal].each do |name|
  puts "\n===== #{name} ====="
  team = field[name].map { |m| Editor.normalize(m) }
  team.each do |s|
    # GUARD: catch silent fallbacks (e.g. GASTRODON->PIKACHU) - species must resolve to itself
    [s[:head], s[:body], s[:species]].compact.each do |sp|
      unless Editor.valid_species?(sp)
        bad_species << "#{name}: #{sp} is NOT in-dex (silent fallback!)"
      end
    end
    begin
      pk = BuildTeam.mon(s)
      types = (pk.types rescue [pk.type1, pk.type2]).compact.map(&:to_s).join('/')
      st = "HP#{pk.totalhp} Atk#{pk.attack} Def#{pk.defense} SpA#{pk.spatk} SpD#{pk.spdef} Spe#{pk.speed}"
      puts "  OK #{s[:head]}/#{s[:body]} [#{pk.ability&.id}] #{types}  #{st}  {#{pk.moves.map { |mv| mv.id }.join('/')}}"
    rescue => e
      puts "  !! FAIL #{s[:head]}/#{s[:body]}: #{e.class} #{e.message[0,80]}"
    end
  end
end
unless bad_species.empty?
  puts "\n!!!! INVALID SPECIES DETECTED - DO NOT TRUST RESULTS:"
  bad_species.uniq.each { |b| puts "  #{b}" }
end
