require_relative 'build_team'
require_relative 'editor'
SimEngine.boot
$DEBUG = false
def show(label, spec)
  s = Editor.normalize(spec)
  [s[:head], s[:body], s[:species]].compact.each do |sp|
    return puts("  #{label.ljust(24)} !! #{sp} NOT in-dex") unless Editor.valid_species?(sp)
  end
  pk = BuildTeam.mon(s)
  types = (pk.types rescue [pk.type1, pk.type2]).compact.map(&:to_s).join('/')
  puts "  #{label.ljust(24)} #{types.ljust(14)} [#{pk.ability&.id}]  Atk#{pk.attack}(x2 club=#{pk.attack*2}) Spe#{pk.speed} SpA#{pk.spatk} HP#{pk.totalhp} Def#{pk.defense}"
end
puts "== Your idea: Marowak/Arceus (Thick Club doubles Atk; ExtremeSpeed = STAB priority) =="
show("Marowak/Arceus", {head: :MAROWAK, body: :ARCEUS, ability: :ROCKHEAD})
show("Arceus/Marowak (swap)", {head: :ARCEUS, body: :MAROWAK, ability: :ROCKHEAD})
puts "\n== Rain: Ludicolo body to KEEP Water/Grass (resists Water/Electric/Ground) + SwiftSwim =="
show("Ludicolo/Politoed (current)", {head: :LUDICOLO, body: :POLITOED, ability: :SWIFTSWIM})
%i[TANGROWTH SCEPTILE WHIMSICOTT VENUSAUR LUDICOLO].each { |b| show("Ludicolo/#{b}", {head: :LUDICOLO, body: b, ability: :SWIFTSWIM}) }
