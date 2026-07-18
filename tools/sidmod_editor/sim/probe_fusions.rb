# Build specific fusions + their single parents to show what the BODY actually contributes.
require_relative 'build_team'
require_relative 'editor'
SimEngine.boot
$DEBUG = false

def line(label, spec)
  pk = BuildTeam.mon(Editor.normalize(spec))
  types = (pk.types rescue [pk.type1, pk.type2]).compact.map(&:to_s).join('/')
  puts "  #{label.ljust(22)} #{types.ljust(15)} [#{pk.ability&.id}]  HP#{pk.totalhp} Atk#{pk.attack} Def#{pk.defense} SpA#{pk.spatk} SpD#{pk.spdef} Spe#{pk.speed}"
end

puts "== Box15B: Kyurem/Salamence (Scarf physical) vs parents =="
line("Kyurem/Salamence", {head: :KYUREM, body: :SALAMENCE, ability: :MOXIE, level: 100})
line("(mono Kyurem)",    {species: :KYUREM, level: 100})
line("(mono Salamence)", {species: :SALAMENCE, ability: :MOXIE, level: 100})

puts "\n== Momentum: Rhyperior/Garchomp (SD physical) vs parents =="
line("Rhyperior/Garchomp", {head: :RHYPERIOR, body: :GARCHOMP, ability: :ROUGHSKIN, level: 100})
line("(mono Rhyperior)",   {species: :RHYPERIOR, level: 100})
line("(mono Garchomp)",    {species: :GARCHOMP, level: 100})

puts "\n== Overload: Hydreigon/Salamence (NP special) vs parents =="
line("Hydreigon/Salamence", {head: :HYDREIGON, body: :SALAMENCE, ability: :LEVITATE, level: 100})
line("(mono Hydreigon)",    {species: :HYDREIGON, ability: :LEVITATE, level: 100})

puts "\n== Overload: Lucario/Infernape (SD priority) vs parents =="
line("Lucario/Infernape", {head: :LUCARIO, body: :INFERNAPE, ability: :IRONFIST, level: 100})
line("(mono Lucario)",    {species: :LUCARIO, level: 100})
line("(mono Infernape)",  {species: :INFERNAPE, ability: :IRONFIST, level: 100})

puts "\n== Bunker: Dragonite/Gyarados (DD bulky) vs parents =="
line("Dragonite/Gyarados", {head: :DRAGONITE, body: :GYARADOS, ability: :MULTISCALE, level: 100})
line("(mono Dragonite)",   {species: :DRAGONITE, ability: :MULTISCALE, level: 100})
line("(mono Gyarados)",    {species: :GYARADOS, level: 100})
