# For each illegal move, find the best legal replacement from the mon's actual pool.
require_relative 'nbattle'

save = ARGV[0] || NativeSim.save_path_in_use
NativeSim.boot!(save)
$DEBUG = false
GameData::Species.send(:public, :get_baby_species)

ILLEGAL = {
  [4,26] => ["Nasty Plot"],           # Giratwo Giratina/Mewtwo
  [5,21] => ["Body Slam"],            # Jimory Jirachi/Skarmory
  [6,23] => ["Extreme Speed"],        # Giratei Giratina/Entei
  [12,1] => ["Nasty Plot"],           # Diantwo Diancie/Mewtwo
  [17,6] => ["Mach Punch"],           # Swampwrath Poliwrath/Swampert
  [17,9] => ["Thunder"],              # Volcatoise Volcarona/Blastoise
  [17,10] => ["Calm Mind"],           # Dragokiss Togekiss/Dragonite
  [18,7] => ["Ice Punch"],            # Rampageon Garchomp/Rampardos
  [18,11] => ["U-turn"],              # Terradrake Tyranitar/Salamence
  [18,22] => ["Earthquake"],          # Voltrazor Raichu/Scizor
  [19,1] => ["Recover"],              # Aquasteel Vaporeon/Registeel
  [19,3] => ["U-turn"],               # Tidepod Tyranitar/Golisopod
  [19,5] => ["Thunderbolt"],          # Wraithninja Chandelure/Greninja
  [19,6] => ["Drain Punch"],          # Bugiken Golisopod/Blaziken
  [19,8] => ["U-turn"],               # Graniteaf Tyranitar/Leafeon
  [19,28] => ["Waterfall"],           # Crushkyl Hitmonlee/Aerodactyl
  [20,8] => ["Nasty Plot"],           # Voltstorm Raikou/Zapdos
  [20,14] => ["Aura Sphere"],         # Latiode Deoxys/Latios
  [20,27] => ["Nasty Plot"],          # Wraithbone Chandelure/Marowak
  [21,2] => ["Light Screen","Reflect"], # Umbraglyph Spiritomb/Sableye
  [21,3] => ["Ice Beam"],             # Voltghast Gengar/Pikachu
  [21,18] => ["Liquidation"],         # Lagoonking Greninja/Slaking
  [21,25] => ["Ice Shard"],           # Mudswine Azumarill/Mamoswine
  [22,2] => ["Icicle Crash"],         # Froschomp Garchomp/Weavile
  [22,4] => ["Icicle Crash"],         # Kyurence Kyurem/Salamence
  [22,12] => ["Thunder"],             # Downpour Politoed/Alakazam
  [22,26] => ["Aura Sphere"],         # Deoxios Deoxys/Latios
  [23,14] => ["Blizzard"],            # Infernogon Hydreigon/Magmortar
  [23,15] => ["Fake Out"],            # Amphrafty Ampharos/Scrafty
  [23,20] => ["Quiver Dance"],        # Deinonychus Charizard/Nidoking
  [24,8] => ["Stealth Rock"],         # Quagbro Quagsire/Slowbro
  [24,17] => ["Icicle Crash","U-turn"], # Momentum Weavile/Aerodactyl
  [24,18] => ["Sludge Wave"],         # Overload Gengar/Greninja
  [24,22] => ["U-turn"],              # Overload Electivire/Aerodactyl
  [24,26] => ["Seismic Toss"],        # Aerolight Blissey/Skarmory
  [25,13] => ["Leech Seed"],          # Emberbloom Roserade/Typhlosion
  [26,19] => ["Dragon Pulse"],        # Floralash Lurantis/Typhlosion
  [26,24] => ["Drain Punch"],         # Metaragon Metagross/Tyrantrum
  [26,26] => ["Swords Dance"],        # Omnigigas Omastar/Regigigas
  [27,6] => ["Scald"],                # Laprorus Aurorus/Lapras
  [29,9] => ["Night Slash","Dragon Claw"], # Spectragore Banette/Hydreigon
  [30,5] => ["Seismic Toss"],         # Airoona Blissey/Dragonite
  [31,5] => ["Extreme Speed"],        # Voltgeist Pikachu/Deoxys
  [31,11] => ["Sucker Punch"],        # Geoform Marowak/Deoxys
  [33,9] => ["Hammer Arm","Crunch","Body Slam"], # Vrok Shuckle/Regigigas
  [33,11] => ["Nasty Plot"],          # Steelmuse Meloetta/Genesect
  [33,25] => ["Drill Peck"],          # Lucharaid Hawlucha/Gyarados
  [34,0] => ["Flamethrower"],         # Sorrow Darkrai/Lugia
  [34,9] => ["Fire Blast"],           # Chantivy Sylveon/Noivern
  [34,24] => ["Dragon Dance"],        # Spectrark Giratina/Arceus
  [35,7] => ["Calm Mind"],            # Nebryss Palkia/Flygon
  [35,8] => ["Thunder"],              # Nimbus Volcarona/Politoed
  [37,0] => ["Calm Mind"],            # Milophyre Milotic/Typhlosion
  [38,16] => ["Ice Beam"],            # Zapkazam Alakazam/Pikachu
  [39,2] => ["Baton Pass","Quiver Dance"], # Eos Arceus/Espeon
  [39,5] => ["Bulk Up"],              # Gigamarill Azumarill/Regigigas
  [39,7] => ["Crunch"],               # Sylvaeon Sylveon/Arceus
}

ROLE_MAP = {
  "Nasty Plot" => :sp_setup, "Calm Mind" => :sp_setup, "Quiver Dance" => :sp_setup, "Tail Glow" => :sp_setup,
  "Dragon Dance" => :ph_setup, "Swords Dance" => :ph_setup, "Bulk Up" => :ph_setup,
  "U-turn" => :pivot, "Volt Switch" => :pivot, "Flip Turn" => :pivot,
  "Extreme Speed" => :priority, "Mach Punch" => :priority, "Ice Shard" => :priority,
  "Sucker Punch" => :priority, "Aqua Jet" => :priority, "Bullet Punch" => :priority,
  "Recover" => :recovery, "Roost" => :recovery, "Soft-Boiled" => :recovery,
  "Seismic Toss" => :fixed_dmg,
  "Stealth Rock" => :hazard, "Spikes" => :hazard,
  "Light Screen" => :screen, "Reflect" => :screen,
  "Leech Seed" => :residual,
  "Baton Pass" => :baton,
}

SP_SETUP = %i[CALMMIND NASTYPLOT QUIVERDANCE TAILGLOW SHELLSMASH GROWTH WORKUP CHARGEBEAM]
PH_SETUP = %i[DRAGONDANCE SWORDSDANCE BULKUP HOWL WORKUP BELLYDRUM COIL SHELLSMASH]
PRIORITY = %i[EXTREMESPEED MACHPUNCH ICESHARD SUCKERPUNCH AQUAJET BULLETPUNCH QUICKATTACK SHADOWSNEAK VACUUMWAVE FAKEOUT]
PIVOT = %i[UTURN VOLTSWITCH FLIPTURN BATONPASS PARTINGSHOT TELEPORT]
RECOVERY = %i[RECOVER ROOST SOFTBOILED SLACKOFF MILKDRINK WISH SYNTHESIS MOONLIGHT MORNINGSUN SHOREUP STRENGTHSAP LEECHSEED]
FIXED = %i[SEISMICTOSS NIGHTSHADE]
HAZARD = %i[STEALTHROCK SPIKES TOXICSPIKES STICKYWEB]
SCREEN = %i[LIGHTSCREEN REFLECT AURORAVEIL]
ICE_MOVES = %i[ICEBEAM BLIZZARD ICICLECRASH ICEPUNCH ICESHARD FREEZEDRY ICYWIND AVALANCHE]
FIRE_MOVES = %i[FLAMETHROWER FIREBLAST HEATWAVE FLAREBLITZ FIREPUNCH OVERHEAT LAVAPLUME SACREDFIRE]
WATER_MOVES = %i[SURF SCALD HYDROPUMP WATERFALL LIQUIDATION AQUATAIL WATERPULSE WAVECRASH AQUAJET FLIPTURN]
ELEC_MOVES = %i[THUNDERBOLT THUNDER DISCHARGE VOLTSWITCH WILDCHARGE THUNDERPUNCH]
FIGHT_MOVES = %i[CLOSECOMBAT FOCUSBLAST AURASPHERE DRAINPUNCH SUPERPOWER BRICKBREAK MACHPUNCH HIGHJUMPKICK HAMMERARM]
DARK_MOVES = %i[DARKPULSE CRUNCH KNOCKOFF SUCKERPUNCH NIGHTSLASH FOULPLAY PURSUIT]
DRAGON_MOVES = %i[DRACOMETEOR DRAGONPULSE DRAGONCLAW OUTRAGE DRAGONBREATH]
GROUND_MOVES = %i[EARTHQUAKE EARTHPOWER BULLDOZE BONEMERANG MUDSHOT HIGHHORSEPOWER STOMPINGTANTRUM]

def legal_pool(pk)
  sp = pk.species
  if (pk.isFusion? rescue false)
    head_dex = getBasePokemonID(sp, false) rescue nil
    body_dex = getBasePokemonID(sp) rescue nil
    pool = []
    pool.concat(pbGetLegalMoves(head_dex)) if head_dex
    pool.concat(pbGetLegalMoves(body_dex)) if body_dex
    pool.uniq
  else
    pbGetLegalMoves(sp)
  end
end

def current_moves(pk)
  pk.moves.map { |m| m&.id }.compact.reject { |m| m == :NONE }
end

def move_name(id)
  (GameData::Move.get(id).name rescue id.to_s)
end

def suggest(pool, current, illegal_move)
  available = pool - current
  # categorize the illegal move
  cat = case illegal_move
  when "Nasty Plot","Calm Mind","Quiver Dance","Tail Glow" then :sp_setup
  when "Dragon Dance","Swords Dance","Bulk Up" then :ph_setup
  when "Extreme Speed","Mach Punch","Ice Shard","Sucker Punch" then :priority
  when "U-turn" then :pivot
  when "Recover","Roost" then :recovery
  when "Seismic Toss" then :fixed_dmg
  when "Stealth Rock" then :hazard
  when "Light Screen","Reflect" then :screen
  when "Leech Seed" then :residual
  when "Baton Pass" then :baton
  when "Ice Beam","Icicle Crash","Ice Punch","Blizzard" then :ice
  when "Thunder","Thunderbolt" then :electric
  when "Flamethrower","Fire Blast" then :fire
  when "Waterfall","Liquidation","Scald" then :water
  when "Aura Sphere","Drain Punch","Fake Out" then :fighting
  when "Night Slash","Crunch" then :dark
  when "Dragon Pulse","Dragon Claw" then :dragon
  when "Earthquake" then :ground
  when "Sludge Wave" then :poison
  when "Body Slam","Hammer Arm" then :normal_phys
  when "Drill Peck" then :flying
  else :coverage
  end

  candidates = case cat
  when :sp_setup then SP_SETUP
  when :ph_setup then PH_SETUP
  when :priority then PRIORITY
  when :pivot then PIVOT
  when :recovery then RECOVERY
  when :fixed_dmg then FIXED
  when :hazard then HAZARD
  when :screen then SCREEN
  when :residual then [:LEECHSEED, :TOXIC, :WILLOWISP]
  when :baton then [:BATONPASS, :TELEPORT, :UTURN, :VOLTSWITCH]
  when :ice then ICE_MOVES
  when :electric then ELEC_MOVES
  when :fire then FIRE_MOVES
  when :water then WATER_MOVES
  when :fighting then FIGHT_MOVES
  when :dark then DARK_MOVES
  when :dragon then DRAGON_MOVES
  when :ground then GROUND_MOVES
  when :poison then [:SLUDGEBOMB, :SLUDGEWAVE, :POISONJAB, :GUNKSHOT, :TOXIC]
  when :normal_phys then [:BODYSLAM, :RETURN, :DOUBLEEDGE, :FACADE, :HAMMERARM, :SUPERPOWER]
  when :flying then [:BRAVEBIRD, :DRILLPECK, :AERIALACE, :ACROBATICS, :AIRSLASH, :HURRICANE, :FLY]
  else []
  end

  same_role = (candidates & available).first(3)
  # also grab some general good coverage from pool
  good_general = available.select { |m|
    md = GameData::Move.get(m) rescue nil
    next false unless md
    md.base_damage >= 60
  }.first(5)

  { same_role: same_role, general: good_general }
end

ILLEGAL.each do |(box, slot), moves|
  pk = $PokemonStorage[box, slot]
  next unless pk
  name = (pk.name || pk.speciesName).to_s
  species = (pk.speciesName rescue pk.species.to_s)
  pool = legal_pool(pk)
  cur = current_moves(pk)

  head_dex = (getBasePokemonID(pk.species, false) rescue nil)
  body_dex = (getBasePokemonID(pk.species) rescue nil)
  head_s = (GameData::Species.get(head_dex).name rescue '?')
  body_s = (GameData::Species.get(body_dex).name rescue '?')

  puts "#{name} (#{head_s}/#{body_s}) [Box#{box+1} slot#{slot+1}]"
  puts "  current: #{cur.map{|m| move_name(m)}.join(', ')}"
  puts "  pool size: #{pool.size}"
  moves.each do |ill|
    s = suggest(pool, cur, ill)
    role_names = s[:same_role].map{|m| move_name(m)}
    puts "  #{ill} -> same role: #{role_names.empty? ? 'NONE' : role_names.join(', ')}"
  end
  puts
end
