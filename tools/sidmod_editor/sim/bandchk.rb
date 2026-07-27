require_relative "build_team"; require_relative "editor"; SimEngine.boot; $DEBUG=false
def show(l,s); pk=BuildTeam.mon(Editor.normalize(s)); t=(pk.types rescue []).map(&:to_s).join("/"); puts "#{l.ljust(24)} #{t.ljust(14)} [#{pk.ability&.id}] Atk#{pk.attack} Spe#{pk.speed} Def#{pk.defense} HP#{pk.totalhp}"; end
# OUSand band breaker options (avoid TTar/Aero/Ferro/Skarm/Gliscor/Milotic/Dragonite/Scizor/Garchomp/Haxorus)
show("Rhyperior/Salamence", {head: :RHYPERIOR, body: :SALAMENCE, ability: :ROCKHEAD, nature: :ADAMANT})
show("Kommo-o/Rhyperior", {head: :KOMMOO, body: :RHYPERIOR, ability: :SOLIDROCK, nature: :ADAMANT})
show("Lucario/Aggron", {head: :LUCARIO, body: :AGGRON, ability: :TECHNICIAN, nature: :ADAMANT})
