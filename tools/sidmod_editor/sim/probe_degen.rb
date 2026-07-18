require_relative 'build_team'
require_relative 'editor'
SimEngine.boot
$DEBUG = false
def line(label, spec)
  s = Editor.normalize(spec)
  [s[:head], s[:body], s[:species]].compact.each { |sp| return puts("  #{label.ljust(22)} !! #{sp} NOT in-dex") unless Editor.valid_species?(sp) }
  pk = BuildTeam.mon(s)
  t = (pk.types rescue [pk.type1, pk.type2]).compact.map(&:to_s).join('/')
  tot = [pk.totalhp, pk.attack, pk.defense, pk.spatk, pk.spdef, pk.speed].sum
  puts "  #{label.ljust(22)} #{t.ljust(14)} TOTAL #{tot}  Atk#{pk.attack} SpA#{pk.spatk} Spe#{pk.speed} Def#{pk.defense} HP#{pk.totalhp}"
end
puts "== HYPOTHESIS: two-uber fusions keep high stats + gain typing? (mono Groudon=1661, Arceus=1761) =="
%w[GROUDON/RAYQUAZA GROUDON/LUGIA GROUDON/GIRATINA KYOGRE/GROUDON KYOGRE/ARCEUS ARCEUS/RAYQUAZA
   RAYQUAZA/GROUDON ARCEUS/GROUDON DIALGA/GIRATINA MEWTWO/ARCEUS].each do |c|
  h, b = c.split('/'); line(c, {head: h.to_sym, body: b.to_sym, nature: :HARDY})
end
puts "\n== broken-multiplier candidates =="
line("Marowak/Groudon @Club", {head: :MAROWAK, body: :GROUDON, ability: :ROCKHEAD, nature: :ADAMANT})
line("Azumarill/Groudon HP", {head: :AZUMARILL, body: :GROUDON, ability: :HUGEPOWER, nature: :ADAMANT})
line("Slaking/Snorlax noTruant", {head: :SLAKING, body: :SNORLAX, ability: :THICKFAT, nature: :ADAMANT})
puts "\n== Gen5 OU control: verify species in-dex =="
%w[POLITOED TYRANITAR GLISCOR LATIOS SCIZOR JIRACHI FERROTHORN KELDEO TERRAKION DRAGONITE
   BRELOOM CONKELDURR VOLCARONA STARMIE SKARMORY ROTOM GENGAR AMOONGUSS REUNICLUS].each do |n|
  r = (GameData::Species.get(n.to_sym) rescue nil); ok = r && r.id == n.to_sym
  puts "  #{ok ? 'OK ' : 'BAD'} #{n.ljust(11)} #{ok ? (r.types rescue []).join('/') : "-> #{r ? r.id : 'nil'}"}"
end
puts "== OU moves =="
%w[SCALD PROTECT WISH BODYSLAM IRONHEAD CRUNCH GYROBALL DRAINPUNCH MACHPUNCH STONEEDGE ROOST TOXIC HYDROPUMP SECRETSWORD].each { |m| puts "  #{GameData::Move.exists?(m) ? 'OK ' : 'BAD'} #{m}" }
