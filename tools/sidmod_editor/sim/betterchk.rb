require_relative "build_team"; require_relative "editor"; SimEngine.boot; $DEBUG=false
def show(l,s); pk=BuildTeam.mon(Editor.normalize(s)); t=(pk.types rescue []).map(&:to_s).join("/"); tot=[pk.totalhp,pk.attack,pk.defense,pk.spatk,pk.spdef,pk.speed].sum; puts "#{l.ljust(24)} #{t.ljust(14)} [#{pk.ability&.id}] Atk#{pk.attack} SpA#{pk.spatk} Spe#{pk.speed} Def#{pk.defense} HP#{pk.totalhp} TOT#{tot}"; end
puts "-- Ubers1: stronger legal replacements (Nidoking 505 / Salamence 4xIce were too weak) --"
show("Darkrai/Hydreigon", {head: :DARKRAI, body: :HYDREIGON, ability: :LEVITATE, nature: :TIMID})
show("Kyurem/Metagross @Scarf", {head: :KYUREM, body: :METAGROSS, ability: :CLEARBODY, nature: :JOLLY})
show("Kyurem/Scizor @Scarf", {head: :KYUREM, body: :SCIZOR, ability: :TECHNICIAN, nature: :JOLLY})
puts "-- OUSand: stronger legal replacements --"
show("Garchomp/Haxorus @Scarf", {head: :GARCHOMP, body: :HAXORUS, ability: :MOLDBREAKER, nature: :JOLLY})
show("Rhyperior/Steelix @Band", {head: :RHYPERIOR, body: :STEELIX, ability: :SOLIDROCK, nature: :ADAMANT})
show("Metagross/Aggron @Band", {head: :METAGROSS, body: :AGGRON, ability: :CLEARBODY, nature: :ADAMANT})
