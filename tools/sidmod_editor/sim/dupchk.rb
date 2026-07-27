require_relative "build_team"; require_relative "editor"; SimEngine.boot; $DEBUG=false
%w[AGGRON FLYGON SALAMENCE RHYPERIOR NIDOKING KOMMOO].each { |n| puts "#{Editor.valid_species?(n.to_sym) ? 'OK ' : 'BAD'} #{n}" }
def show(l,s); pk=BuildTeam.mon(Editor.normalize(s)); t=(pk.types rescue []).map(&:to_s).join("/"); puts "#{l.ljust(24)} #{t.ljust(14)} [#{pk.ability&.id}] Atk#{pk.attack} SpA#{pk.spatk} Spe#{pk.speed} HP#{pk.totalhp}"; end
puts "-- OUSand replacements (Garchomp/Donphan + Tyranitar/Dragonite) --"
show("Garchomp/Salamence @Scarf", {head: :GARCHOMP, body: :SALAMENCE, ability: :MOXIE, nature: :JOLLY})
show("Rhyperior/Aggron @Band", {head: :RHYPERIOR, body: :AGGRON, ability: :SOLIDROCK, nature: :ADAMANT})
puts "-- Ubers1 replacements (Darkrai/Groudon + Kyurem/Dialga) --"
show("Darkrai/Flygon", {head: :DARKRAI, body: :FLYGON, ability: :LEVITATE, nature: :TIMID})
show("Darkrai/Nidoking", {head: :DARKRAI, body: :NIDOKING, ability: :SHEERFORCE, nature: :TIMID})
show("Kyurem/Salamence @Scarf", {head: :KYUREM, body: :SALAMENCE, ability: :MOXIE, nature: :JOLLY})
show("Kyurem/Haxorus @Scarf", {head: :KYUREM, body: :HAXORUS, ability: :MOLDBREAKER, nature: :JOLLY})
