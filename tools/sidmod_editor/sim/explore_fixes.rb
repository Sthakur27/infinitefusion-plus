# Explore verified replacement fusions for the 4 flagged bad picks. Prints type/ability/
# stats vs the mono-parent baseline so we choose bodies that ACTUALLY improve the mon.
require_relative 'build_team'
require_relative 'editor'
SimEngine.boot
$DEBUG = false

def show(label, spec)
  s = Editor.normalize(spec)
  [s[:head], s[:body], s[:species]].compact.each do |sp|
    return puts("  #{label.ljust(24)} !! #{sp} NOT in-dex (fallback)") unless Editor.valid_species?(sp)
  end
  pk = BuildTeam.mon(s)
  types = (pk.types rescue [pk.type1, pk.type2]).compact.map(&:to_s).join('/')
  puts "  #{label.ljust(24)} #{types.ljust(14)} [#{pk.ability&.id}]  Atk#{pk.attack} Def#{pk.defense} SpA#{pk.spatk} SpD#{pk.spdef} Spe#{pk.speed} HP#{pk.totalhp}"
end

puts "== MOMENTUM slot: want fast bulky physical Dragon/Ground breaker (beat mono Garchomp Atk296/Spe240) =="
show("BASELINE mono Garchomp", {species: :GARCHOMP})
%i[SALAMENCE DRAGONITE TYRANITAR FLYGON HAXORUS SCEPTILE].each { |b| show("Garchomp/#{b}", {head: :GARCHOMP, body: b, ability: :ROUGHSKIN}) }

puts "\n== OVERLOAD slot: want special Dark/Dragon NP (keep Draco STAB), Levitate, SpA/Spe >= Hydreigon =="
show("BASELINE mono Hydreigon", {species: :HYDREIGON, ability: :LEVITATE})
%i[HAXORUS KINGDRA DRUDDIGON GOODRA FLYGON GARCHOMP LATIOS].each { |b| show("Hydreigon/#{b}", {head: :HYDREIGON, body: b, ability: :LEVITATE}) }

puts "\n== BUNKER slot: want bulky DD Roost wincon, better def typing (Dragon/Steel?), >= mono Dragonite =="
show("BASELINE mono Dragonite", {species: :DRAGONITE, ability: :MULTISCALE})
%i[SKARMORY AGGRON FERROTHORN BRONZONG STEELIX SCIZOR].each { |b| show("Dragonite/#{b}", {head: :DRAGONITE, body: b, ability: :MULTISCALE}) }

puts "\n== BOX15A slot: want a Steel pivot to patch Fairy/Ice/Dragon weakness (non-redundant) =="
%i[SCIZOR AGGRON METAGROSS BRONZONG SKARMORY FERROTHORN].each { |b| show("Aggron/#{b} & Scizor variants", {head: :AGGRON, body: b}) }
%w[SCIZOR/AGGRON METAGROSS/SCIZOR JIRACHI/AGGRON DIALGA/SKARMORY].each do |combo|
  h, bd = combo.split('/'); show("#{h}/#{bd}", {head: h.to_sym, body: bd.to_sym})
end
