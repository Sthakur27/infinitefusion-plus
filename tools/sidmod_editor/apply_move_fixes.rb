require_relative 'stub_loader'
require 'fileutils'

IN_PATH = ARGV[0] || File.join(ENV['APPDATA'], 'infinitefusion', 'File A.rxdata')
OUT_PATH = ARGV[1] || IN_PATH

save = StubLoader.load_file(IN_PATH)
storage = save[:storage_system]

def ivg(o, n) o.instance_variable_get(n) end

REPLACEMENTS = [
  [[4,26], :NASTYPLOT, :CALMMIND],
  [[5,21], :BODYSLAM, :RETURN],
  [[6,23], :EXTREMESPEED, :SHADOWSNEAK],
  [[12,1], :NASTYPLOT, :CALMMIND],
  [[17,6], :MACHPUNCH, :SUPERPOWER],
  [[17,9], :THUNDER, :BUGBUZZ],
  [[17,10], :CALMMIND, :NASTYPLOT],
  [[18,7], :ICEPUNCH, :IRONHEAD],
  [[18,11], :UTURN, :EARTHQUAKE],
  [[18,22], :EARTHQUAKE, :KNOCKOFF],
  [[19,1], :RECOVER, :WISH],
  [[19,3], :UTURN, :SUCKERPUNCH],
  [[19,5], :THUNDERBOLT, :FLAMETHROWER],
  [[19,6], :DRAINPUNCH, :CLOSECOMBAT],
  [[19,8], :UTURN, :CRUNCH],
  [[19,28], :WATERFALL, :AQUATAIL],
  [[20,8], :NASTYPLOT, :CALMMIND],
  [[20,14], :AURASPHERE, :FOCUSBLAST],
  [[20,27], :NASTYPLOT, :CALMMIND],
  [[21,2], :LIGHTSCREEN, :WILLOWISP],
  [[21,2], :REFLECT, :FOULPLAY],
  [[21,3], :ICEBEAM, :SLUDGEBOMB],
  [[21,18], :LIQUIDATION, :WATERFALL],
  [[22,2], :ICICLECRASH, :ICEPUNCH],
  [[22,4], :ICICLECRASH, :OUTRAGE],
  [[22,12], :THUNDER, :DAZZLINGGLEAM],
  [[22,26], :AURASPHERE, :FOCUSBLAST],
  [[23,14], :BLIZZARD, :DRACOMETEOR],
  [[23,15], :FAKEOUT, :DRAGONPULSE],
  [[23,20], :QUIVERDANCE, :THUNDERBOLT],
  [[24,8], :STEALTHROCK, :TOXIC],
  [[24,17], :ICICLECRASH, :ICEPUNCH],
  [[24,17], :UTURN, :LOWKICK],
  [[24,18], :SLUDGEWAVE, :SLUDGEBOMB],
  [[24,22], :UTURN, :VOLTSWITCH],
  [[24,26], :SEISMICTOSS, :FLAMETHROWER],
  [[25,13], :LEECHSEED, :TOXIC],
  [[26,19], :DRAGONPULSE, :SUPERPOWER],
  [[26,24], :DRAINPUNCH, :SUPERPOWER],
  [[26,26], :SWORDSDANCE, :SHELLSMASH],
  [[27,6], :SCALD, :SURF],
  [[29,9], :NIGHTSLASH, :KNOCKOFF],
  [[29,9], :DRAGONCLAW, :OUTRAGE],
  [[30,5], :SEISMICTOSS, :FLAMETHROWER],
  [[31,5], :EXTREMESPEED, :SIGNALBEAM],
  [[31,11], :SUCKERPUNCH, :KNOCKOFF],
  [[33,9], :HAMMERARM, :DRAINPUNCH],
  [[33,9], :CRUNCH, :KNOCKOFF],
  [[33,9], :BODYSLAM, :RETURN],
  [[33,11], :NASTYPLOT, :CALMMIND],
  [[33,25], :DRILLPECK, :ACROBATICS],
  [[34,0], :FLAMETHROWER, :ICEBEAM],
  [[34,9], :FIREBLAST, :FLAMETHROWER],
  [[34,24], :DRAGONDANCE, :SWORDSDANCE],
  [[35,7], :CALMMIND, :THUNDERBOLT],
  [[35,8], :THUNDER, :ICEBEAM],
  [[37,0], :CALMMIND, :ICEBEAM],
  [[38,16], :ICEBEAM, :DAZZLINGGLEAM],
  [[39,2], :BATONPASS, :FLAMETHROWER],
  [[39,2], :QUIVERDANCE, :CALMMIND],
  [[39,5], :BULKUP, :BELLYDRUM],
  [[39,7], :CRUNCH, :SHADOWCLAW],
]

applied = 0
errors = []

REPLACEMENTS.each do |(box, slot), old_id, new_id|
  boxes = ivg(storage, :@boxes)
  b = boxes[box]
  unless b
    errors << "Box#{box+1}: box not found"
    next
  end
  pokes = ivg(b, :@pokemon)
  pk = pokes[slot]
  unless pk
    errors << "Box#{box+1} s#{slot+1}: no pokemon"
    next
  end
  name = (ivg(pk, :@name) || ivg(pk, :@species) || '?').to_s

  moves = ivg(pk, :@moves)
  idx = moves.index { |m| m && ivg(m, :@id) == old_id }
  unless idx
    errors << "#{name} Box#{box+1} s#{slot+1}: #{old_id} not in moveset #{moves.map{|m| ivg(m,:@id)}.inspect}"
    next
  end

  old_move = moves[idx]
  ivg(old_move, :@id).tap {} # just verify it exists
  # Reuse the existing move object structure — just swap the id and reset pp
  new_move = Marshal.load(Marshal.dump(old_move))
  new_move.instance_variable_set(:@id, new_id)
  # PP will be wrong but the game recalculates on load
  moves[idx] = new_move
  applied += 1
  puts "OK  #{name} [Box#{box+1} s#{slot+1}]: #{old_id} -> #{new_id}"
end

puts "\n#{applied}/#{REPLACEMENTS.size} applied"
if errors.any?
  puts "#{errors.size} errors:"
  errors.each { |e| puts "  ERR: #{e}" }
end

if applied == REPLACEMENTS.size
  backup_dir = File.join(ENV['APPDATA'], 'infinitefusion', 'sidmod_manual_backups')
  FileUtils.mkdir_p(backup_dir)
  backup = File.join(backup_dir, "pre_move_fix_#{Time.now.strftime('%Y%m%d_%H%M%S')}.rxdata")
  FileUtils.cp(IN_PATH, backup)
  puts "\nBackup: #{backup}"

  Marshal.dump(save, File.open(OUT_PATH, 'wb')).close rescue File.binwrite(OUT_PATH, Marshal.dump(save))
  puts "Save written: #{OUT_PATH}"
else
  puts "\nNot all replacements applied — save NOT written"
end
