require_relative 'nbattle'

save = ARGV[0] || NativeSim.save_path_in_use
NativeSim.boot!(save)
$DEBUG = false
GameData::Species.send(:public, :get_baby_species)

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

def move_info(id)
  md = GameData::Move.get(id) rescue nil
  return nil unless md
  { id: md.id, name: md.name, type: md.type, cat: md.category, power: md.base_damage }
end

def atk_orientation(pk)
  atk = pk.attack rescue 0
  spa = pk.spatk rescue 0
  if atk > spa * 1.3 then :physical
  elsif spa > atk * 1.3 then :special
  else :mixed
  end
end

ILLEGAL_LIST = [
  [[4,26], "Nasty Plot"],[[5,21], "Body Slam"],[[6,23], "Extreme Speed"],
  [[12,1], "Nasty Plot"],[[17,6], "Mach Punch"],[[17,9], "Thunder"],
  [[17,10], "Calm Mind"],[[18,7], "Ice Punch"],[[18,11], "U-turn"],
  [[18,22], "Earthquake"],[[19,1], "Recover"],[[19,3], "U-turn"],
  [[19,5], "Thunderbolt"],[[19,6], "Drain Punch"],[[19,8], "U-turn"],
  [[19,28], "Waterfall"],[[20,8], "Nasty Plot"],[[20,14], "Aura Sphere"],
  [[20,27], "Nasty Plot"],[[21,2], "Light Screen"],[[21,2], "Reflect"],
  [[21,3], "Ice Beam"],[[21,18], "Liquidation"],[[21,25], "Ice Shard"],
  [[22,2], "Icicle Crash"],[[22,4], "Icicle Crash"],[[22,12], "Thunder"],
  [[22,26], "Aura Sphere"],[[23,14], "Blizzard"],[[23,15], "Fake Out"],
  [[23,20], "Quiver Dance"],[[24,8], "Stealth Rock"],
  [[24,17], "Icicle Crash"],[[24,17], "U-turn"],
  [[24,18], "Sludge Wave"],[[24,22], "U-turn"],[[24,26], "Seismic Toss"],
  [[25,13], "Leech Seed"],[[26,19], "Dragon Pulse"],[[26,24], "Drain Punch"],
  [[26,26], "Swords Dance"],[[27,6], "Scald"],
  [[29,9], "Night Slash"],[[29,9], "Dragon Claw"],
  [[30,5], "Seismic Toss"],[[31,5], "Extreme Speed"],[[31,11], "Sucker Punch"],
  [[33,9], "Hammer Arm"],[[33,9], "Crunch"],[[33,9], "Body Slam"],
  [[33,11], "Nasty Plot"],[[33,25], "Drill Peck"],
  [[34,0], "Flamethrower"],[[34,9], "Fire Blast"],
  [[34,24], "Dragon Dance"],[[35,7], "Calm Mind"],[[35,8], "Thunder"],
  [[37,0], "Calm Mind"],[[38,16], "Ice Beam"],
  [[39,2], "Baton Pass"],[[39,2], "Quiver Dance"],
  [[39,5], "Bulk Up"],[[39,7], "Crunch"],
]

ILLEGAL_LIST.each do |(box, slot), ill_name|
  pk = $PokemonStorage[box, slot]
  next unless pk
  name = (pk.name || pk.speciesName).to_s
  orient = atk_orientation(pk)
  atk = pk.attack rescue 0; spa = pk.spatk rescue 0; spe = pk.speed rescue 0
  pool = legal_pool(pk)
  cur = pk.moves.map { |m| m&.id }.compact.reject { |m| m == :NONE }
  cur_names = cur.map { |m| (GameData::Move.get(m).name rescue m.to_s) }
  available = (pool - cur)

  ill_info = GameData::Move.each { |m| break m if m.name == ill_name }
  ill_cat = ill_info&.category rescue nil
  ill_type = ill_info&.type rescue nil
  ill_power = ill_info&.base_damage rescue 0

  # Build categorized suggestions
  suggestions = available.map { |m| move_info(m) }.compact

  # Filter by orientation match
  if ill_cat == 0 # physical
    pref = suggestions.select { |m| m[:cat] == 0 }
  elsif ill_cat == 1 # special
    pref = suggestions.select { |m| m[:cat] == 1 }
  else # status
    pref = suggestions.select { |m| m[:cat] == 2 }
  end

  # Same type preference
  same_type = pref.select { |m| m[:type] == ill_type }
  # Similar power
  similar = same_type.sort_by { |m| -(m[:power] || 0) }.first(3)
  # Different type but same category, high power
  diff_type = (pref - same_type).sort_by { |m| -(m[:power] || 0) }.first(3)
  # Status replacements for status moves
  if ill_cat == 2
    similar = pref.first(5)
    diff_type = []
  end

  # For special cases
  role_alts = case ill_name
  when "Nasty Plot" then suggestions.select { |m| [:CALMMIND,:WORKUP,:CHARGEBEAM,:SHELLSMASH].include?(m[:id]) }
  when "Calm Mind" then suggestions.select { |m| [:NASTYPLOT,:WORKUP,:CHARGEBEAM].include?(m[:id]) }
  when "Quiver Dance" then suggestions.select { |m| [:CALMMIND,:NASTYPLOT,:WORKUP].include?(m[:id]) }
  when "Dragon Dance" then suggestions.select { |m| [:SWORDSDANCE,:WORKUP,:BULKUP,:COIL].include?(m[:id]) }
  when "Swords Dance" then suggestions.select { |m| [:DRAGONDANCE,:BULKUP,:WORKUP,:SHELLSMASH,:BELLYDRUM].include?(m[:id]) }
  when "Bulk Up" then suggestions.select { |m| [:SWORDSDANCE,:DRAGONDANCE,:WORKUP,:BELLYDRUM].include?(m[:id]) }
  when "U-turn" then suggestions.select { |m| [:VOLTSWITCH,:FLIPTURN,:PARTINGSHOT,:TELEPORT,:BATONPASS].include?(m[:id]) }
  when "Extreme Speed","Mach Punch","Ice Shard","Sucker Punch"
    suggestions.select { |m| [:EXTREMESPEED,:MACHPUNCH,:ICESHARD,:SUCKERPUNCH,:AQUAJET,:BULLETPUNCH,:QUICKATTACK,:SHADOWSNEAK,:VACUUMWAVE,:FAKEOUT].include?(m[:id]) }
  when "Recover" then suggestions.select { |m| [:WISH,:ROOST,:SOFTBOILED,:SLACKOFF,:SYNTHESIS,:MOONLIGHT,:MORNINGSUN,:SHOREUP,:STRENGTHSAP].include?(m[:id]) }
  when "Seismic Toss" then suggestions.select { |m| [:NIGHTSHADE].include?(m[:id]) }
  when "Stealth Rock" then suggestions.select { |m| [:SPIKES,:TOXICSPIKES,:STICKYWEB].include?(m[:id]) }
  when "Leech Seed" then suggestions.select { |m| [:TOXIC,:WILLOWISP].include?(m[:id]) }
  when "Light Screen","Reflect" then suggestions.select { |m| [:REFLECT,:LIGHTSCREEN,:AURORAVEIL,:WILLOWISP,:TOXIC].include?(m[:id]) }
  when "Baton Pass" then suggestions.select { |m| [:TELEPORT,:UTURN,:VOLTSWITCH].include?(m[:id]) }
  else []
  end

  head_dex = (getBasePokemonID(pk.species, false) rescue nil)
  body_dex = (getBasePokemonID(pk.species) rescue nil)
  head_s = (GameData::Species.get(head_dex).name rescue '?')
  body_s = (GameData::Species.get(body_dex).name rescue '?')

  top = (role_alts.map{|m|m[:name]} + similar.map{|m|m[:name]} + diff_type.map{|m|m[:name]}).uniq.first(5)

  puts "#{name}|#{head_s}/#{body_s}|Box#{box+1} s#{slot+1}|#{orient}|Atk#{atk} SpA#{spa} Spe#{spe}|#{cur_names.join(', ')}|#{ill_name}|#{top.join(', ')}"
end
