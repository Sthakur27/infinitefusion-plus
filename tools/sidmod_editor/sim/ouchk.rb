require_relative "build_team"; require_relative "editor"; SimEngine.boot; $DEBUG=false
%w[MILOTIC SANDSLASH STOUTLAND HIPPOWDON SAWSBUCK LILLIGANT LEAFEON SHIFTRY KOMMOO CELEBI
   ROTOM VENUSAUR NINETALES POLITOED TYRANITAR HERACROSS DONPHAN GARCHOMP LANDORUS
   VOLCARONA MAGNEZONE GENGAR STARMIE CRADILY LUNATONE ARMALDO GLISCOR SKARMORY].each do |n|
  r = (GameData::Species.get(n.to_sym) rescue nil); ok = r && r.id == n.to_sym
  ab = ok ? (r.abilities rescue []).flatten.compact.map(&:to_s).join(",") : ""
  puts "#{ok ? 'OK ' : 'BAD'} #{n.ljust(11)} #{ok ? (r.types rescue []).join('/').ljust(14)+ab : "-> "+(r ? r.id.to_s : 'nil')}"
end
