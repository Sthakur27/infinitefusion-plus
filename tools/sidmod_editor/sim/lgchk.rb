require_relative "build_team"; require_relative "editor"; SimEngine.boot; $DEBUG=false
pk = BuildTeam.mon(Editor.normalize({head: :LUGIA, body: :GROUDON, ability: :MULTISCALE, nature: :ADAMANT}))
t = (pk.types rescue []).map(&:to_s).join("/")
puts "Lugia/Groudon: #{t} [#{pk.ability&.id}] Atk#{pk.attack} Def#{pk.defense} SpD#{pk.spdef} HP#{pk.totalhp} Spe#{pk.speed}"
