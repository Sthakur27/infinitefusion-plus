require_relative 'nstore'
require_relative 'nbattle'
NativeSim.boot!   # live save after write
[14, 16].each do |b|
  puts "=== in-game Box #{b + 1} (idx #{b}) ==="
  (0...30).each do |i|
    pk = $PokemonStorage[b, i]
    next if pk.nil?
    nm = (pk.name || pk.speciesName).to_s
    puts "  slot %-3d %-9s %-24s L%-4d %-13s %s" % [i + 1, nm, (pk.speciesName rescue '?'), pk.level,
      (pk.item&.name rescue '-'), (pk.moves.map { |m| m.name } rescue []).join('/')]
  end
end
