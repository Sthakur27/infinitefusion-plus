require_relative "build_team"; require_relative "editor"; SimEngine.boot; $DEBUG=false
[%w[LEAFEON ARCANINE],%w[LEAFEON NINETALES],%w[SHIFTRY NINETALES],%w[VENUSAUR ARCANINE],%w[SHIFTRY BLAZIKEN],%w[LEAFEON BLAZIKEN]].each do |h,b|
  next unless (Editor.valid_species?(h.to_sym) && Editor.valid_species?(b.to_sym))
  pk = BuildTeam.mon(Editor.normalize({head: h.to_sym, body: b.to_sym, ability: :CHLOROPHYLL, nature: :JOLLY}))
  puts "#{h}/#{b}: #{(pk.types rescue []).map(&:to_s).join('/').ljust(14)} Atk#{pk.attack} Spe#{pk.speed} SpA#{pk.spatk}"
end
