# CLEAN comparison: fixed nature, no EVs, so stats are comparable (no random-nature noise).
require_relative 'build_team'
require_relative 'editor'
SimEngine.boot
$DEBUG = false
def show(label, spec, stat)
  s = Editor.normalize(spec)
  [s[:head], s[:body], s[:species]].compact.each { |sp| return puts("  #{label.ljust(26)} !! #{sp} NOT in-dex") unless Editor.valid_species?(sp) }
  pk = BuildTeam.mon(s)
  types = (pk.types rescue [pk.type1, pk.type2]).compact.map(&:to_s).join('/')
  val = pk.send(stat)
  puts "  #{label.ljust(26)} #{types.ljust(13)} #{stat}=#{val}  Spe=#{pk.speed}"
end
puts "== Hydreigon options (ALL Modest, no EVs) - is Kingdra really higher SpA? =="
show("mono Hydreigon", {species: :HYDREIGON, ability: :LEVITATE, nature: :MODEST}, :spatk)
%i[KINGDRA FLYGON GOODRA HAXORUS].each { |b| show("Hydreigon/#{b}", {head: :HYDREIGON, body: b, ability: :LEVITATE, nature: :MODEST}, :spatk) }
puts "\n== Momentum: physical (ALL Jolly, no EVs) - does Garchomp/Haxorus really beat mono Garchomp? =="
show("mono Garchomp", {species: :GARCHOMP, nature: :JOLLY}, :attack)
%i[HAXORUS SALAMENCE DRAGONITE TYRANITAR].each { |b| show("Garchomp/#{b}", {head: :GARCHOMP, body: b, ability: :ROUGHSKIN, nature: :JOLLY}, :attack) }
puts "\n== Bunker: physical (ALL Adamant, no EVs) - Dragonite/Scizor vs mono Dragonite =="
show("mono Dragonite", {species: :DRAGONITE, ability: :MULTISCALE, nature: :ADAMANT}, :attack)
show("Dragonite/Scizor", {head: :DRAGONITE, body: :SCIZOR, ability: :MULTISCALE, nature: :ADAMANT}, :attack)
