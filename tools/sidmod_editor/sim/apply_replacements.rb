require_relative 'nbattle'
require_relative '../stub_loader'
require 'fileutils'

save_path = ARGV[0] || NativeSim.save_path_in_use
NativeSim.boot!(save_path)
$DEBUG = false

REPLACEMENTS = [
  [[4,26], "Nasty Plot", "CALMMIND"],
  [[5,21], "Body Slam", "RETURN"],
  [[6,23], "Extreme Speed", "SHADOWSNEAK"],
  [[12,1], "Nasty Plot", "CALMMIND"],
  [[17,6], "Mach Punch", "SUPERPOWER"],
  [[17,9], "Thunder", "BUGBUZZ"],
  [[17,10], "Calm Mind", "NASTYPLOT"],
  [[18,7], "Ice Punch", "IRONHEAD"],
  [[18,11], "U-turn", "EARTHQUAKE"],
  [[18,22], "Earthquake", "KNOCKOFF"],
  [[19,1], "Recover", "WISH"],
  [[19,3], "U-turn", "SUCKERPUNCH"],
  [[19,5], "Thunderbolt", "FLAMETHROWER"],
  [[19,6], "Drain Punch", "CLOSECOMBAT"],
  [[19,8], "U-turn", "CRUNCH"],
  [[19,28], "Waterfall", "AQUATAIL"],
  [[20,8], "Nasty Plot", "CALMMIND"],
  [[20,14], "Aura Sphere", "FOCUSBLAST"],
  [[20,27], "Nasty Plot", "CALMMIND"],
  [[21,2], "Light Screen", "WILLOWISP"],
  [[21,2], "Reflect", "FOULPLAY"],
  [[21,3], "Ice Beam", "SLUDGEBOMB"],
  [[21,18], "Liquidation", "WATERFALL"],
  [[22,2], "Icicle Crash", "ICEPUNCH"],
  [[22,4], "Icicle Crash", "OUTRAGE"],
  [[22,12], "Thunder", "DAZZLINGGLEAM"],
  [[22,26], "Aura Sphere", "FOCUSBLAST"],
  [[23,14], "Blizzard", "DRACOMETEOR"],
  [[23,15], "Fake Out", "DRAGONPULSE"],
  [[23,20], "Quiver Dance", "THUNDERBOLT"],
  [[24,8], "Stealth Rock", "TOXIC"],
  [[24,17], "Icicle Crash", "ICEPUNCH"],
  [[24,17], "U-turn", "LOWKICK"],
  [[24,18], "Sludge Wave", "SLUDGEBOMB"],
  [[24,22], "U-turn", "VOLTSWITCH"],
  [[24,26], "Seismic Toss", "FLAMETHROWER"],
  [[25,13], "Leech Seed", "TOXIC"],
  [[26,19], "Dragon Pulse", "SUPERPOWER"],
  [[26,24], "Drain Punch", "SUPERPOWER"],
  [[26,26], "Swords Dance", "SHELLSMASH"],
  [[27,6], "Scald", "SURF"],
  [[29,9], "Night Slash", "KNOCKOFF"],
  [[29,9], "Dragon Claw", "OUTRAGE"],
  [[30,5], "Seismic Toss", "FLAMETHROWER"],
  [[31,5], "Extreme Speed", "SIGNALBEAM"],
  [[31,11], "Sucker Punch", "KNOCKOFF"],
  [[33,9], "Hammer Arm", "DRAINPUNCH"],
  [[33,9], "Crunch", "KNOCKOFF"],
  [[33,9], "Body Slam", "RETURN"],
  [[33,11], "Nasty Plot", "CALMMIND"],
  [[33,25], "Drill Peck", "ACROBATICS"],
  [[34,0], "Flamethrower", "ICEBEAM"],
  [[34,9], "Fire Blast", "FLAMETHROWER"],
  [[34,24], "Dragon Dance", "SWORDSDANCE"],
  [[35,7], "Calm Mind", "THUNDERBOLT"],
  [[35,8], "Thunder", "ICEBEAM"],
  [[37,0], "Calm Mind", "ICEBEAM"],
  [[38,16], "Ice Beam", "DAZZLINGGLEAM"],
  [[39,2], "Baton Pass", "FLAMETHROWER"],
  [[39,2], "Quiver Dance", "CALMMIND"],
  [[39,5], "Bulk Up", "BELLYDRUM"],
  [[39,7], "Crunch", "SHADOWCLAW"],
]

def move_name_to_id(name)
  GameData::Move.each { |m| return m.id if m.name == name }
  nil
end

applied = 0
errors = []

REPLACEMENTS.each do |(box, slot), old_name, new_sym|
  pk = $PokemonStorage[box, slot]
  unless pk
    errors << "Box#{box+1} s#{slot+1}: no pokemon found"
    next
  end
  name = (pk.name || pk.speciesName).to_s
  old_id = move_name_to_id(old_name)
  new_id = new_sym.to_sym

  new_data = GameData::Move.get(new_id) rescue nil
  unless new_data
    errors << "#{name}: replacement move #{new_sym} not found in data"
    next
  end

  idx = pk.moves.index { |m| m && m.id == old_id }
  unless idx
    errors << "#{name} Box#{box+1} s#{slot+1}: move #{old_name} not found in moveset"
    next
  end

  pk.moves[idx] = Pokemon::Move.new(new_id)
  applied += 1
  puts "OK  #{name} [Box#{box+1} s#{slot+1}]: #{old_name} -> #{new_data.name}"
end

puts "\n#{applied}/#{REPLACEMENTS.size} applied"
puts "#{errors.size} errors:" if errors.any?
errors.each { |e| puts "  ERR: #{e}" }

# Save — reload full save, swap in the modified storage, dump
backup_dir = File.join(ENV['APPDATA'], 'infinitefusion', 'sidmod_manual_backups')
FileUtils.mkdir_p(backup_dir)
backup = File.join(backup_dir, "pre_move_fix_#{Time.now.strftime('%Y%m%d_%H%M%S')}.rxdata")
FileUtils.cp(save_path, backup)
puts "\nBackup: #{backup}"

full_save = StubLoader.load_file(save_path)
full_save[:storage_system] = $PokemonStorage
File.binwrite(save_path, Marshal.dump(full_save))
puts "Save written: #{save_path}"
