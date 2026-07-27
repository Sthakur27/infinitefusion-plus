require_relative "build_team"; require_relative "editor"; SimEngine.boot; $DEBUG=false
def show(l,s); pk=BuildTeam.mon(Editor.normalize(s)); t=(pk.types rescue []).map(&:to_s).join("/"); puts "#{l.ljust(22)} #{t.ljust(14)} [#{pk.ability&.id}] Atk#{pk.attack} SpA#{pk.spatk} Spe#{pk.speed} HP#{pk.totalhp}"; end
puts "POLIWRATH in-dex: #{Editor.valid_species?(:POLIWRATH)}; KOMMOO: #{Editor.valid_species?(:KOMMOO)}; BRELOOM: #{Editor.valid_species?(:BRELOOM)}"
show("Darkrai/Groudon", {head: :DARKRAI, body: :GROUDON, ability: :BADDREAMS, nature: :TIMID})
show("Poliwrath/Kabutops", {head: :POLIWRATH, body: :KABUTOPS, ability: :SWIFTSWIM, nature: :ADAMANT})
show("Kommo-o/Kabutops", {head: :KOMMOO, body: :KABUTOPS, ability: :SWIFTSWIM, nature: :ADAMANT})
show("Tyranitar/Dragonite", {head: :TYRANITAR, body: :DRAGONITE, ability: :SANDSTREAM, nature: :ADAMANT})
show("Kyurem/Dialga", {head: :KYUREM, body: :DIALGA, ability: :MOXIE, nature: :JOLLY})
