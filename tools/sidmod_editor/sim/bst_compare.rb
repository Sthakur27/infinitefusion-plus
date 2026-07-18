require_relative 'build_team'
require_relative 'editor'
SimEngine.boot
$DEBUG = false
def total(spec)
  pk = BuildTeam.mon(Editor.normalize(spec))
  [pk.totalhp, pk.attack, pk.defense, pk.spatk, pk.spdef, pk.speed].sum
end
def row(label, spec); puts "  #{label.ljust(24)} total stats @L100(neutral,0 EV) = #{total(spec)}"; end
puts "== A legendary FUSION vs its mono parents vs a full-power mono uber =="
row("Giratina/Arceus (fusion)", {head: :GIRATINA, body: :ARCEUS, ability: :PRESSURE, nature: :HARDY})
row("  mono Giratina", {species: :GIRATINA, nature: :HARDY})
row("  mono Arceus", {species: :ARCEUS, nature: :HARDY})
puts ""
row("Kyogre/Mew (fusion)", {head: :KYOGRE, body: :MEW, ability: :DRIZZLE, nature: :HARDY})
row("  mono Kyogre", {species: :KYOGRE, nature: :HARDY})
puts ""
row("Groudon/Gliscor (fusion)", {head: :GROUDON, body: :GLISCOR, ability: :POISONHEAL, nature: :HARDY})
row("  mono Groudon", {species: :GROUDON, nature: :HARDY})
puts ""
puts "  (reference full-power ubers the control runs undiluted:)"
row("  mono Rayquaza", {species: :RAYQUAZA, nature: :HARDY})
row("  mono Mewtwo", {species: :MEWTWO, nature: :HARDY})
row("  mono Dialga", {species: :DIALGA, nature: :HARDY})
