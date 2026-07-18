require_relative 'build_team'
require_relative 'editor'
SimEngine.boot
$DEBUG = false
def show(label, spec)
  s = Editor.normalize(spec)
  [s[:head], s[:body], s[:species]].compact.each { |sp| return puts("  #{label.ljust(22)} !! #{sp} NOT in-dex") unless Editor.valid_species?(sp) }
  pk = BuildTeam.mon(s)
  t = (pk.types rescue [pk.type1, pk.type2]).compact.map(&:to_s)
  # crude Ice multiplier note
  ice = t.map { |x| %w[DRAGON FLYING GROUND ROCK GRASS].include?(x) ? 2 : (%w[ICE STEEL FIRE WATER].include?(x) ? 0.5 : 1) }.reduce(1, :*)
  puts "  #{label.ljust(22)} #{t.join('/').ljust(14)} [#{pk.ability&.id}] Atk#{pk.attack} Spe#{pk.speed} | Ice x#{ice}"
end
puts "== Box15B slot: fast physical Scarf revenge-killer, keep Ice coverage, want Ice <= x2 (not x4 like Groudon) =="
show("CURRENT Kyurem/Salamence", {head: :KYUREM, body: :SALAMENCE, ability: :MOXIE, nature: :JOLLY})
%i[HAXORUS TYRANITAR METAGROSS DIALGA GARCHOMP SCRAFTY KROOKODILE GYARADOS].each do |b|
  show("Kyurem/#{b}", {head: :KYUREM, body: b, ability: :MOXIE, nature: :JOLLY})
end
