require_relative 'nstore'
require_relative 'nbattle'
NativeSim.boot!   # live save
free = []
$PokemonStorage.maxBoxes.times do |b|
  cap = $PokemonStorage.maxPokemon(b)
  used = (0...cap).count { |i| !$PokemonStorage[b, i].nil? }
  nm = ($PokemonStorage.boxes[b].name rescue "Box #{b + 1}")
  free << [b, nm, used, cap]
end
puts "boxes with >= 12 free slots (0-indexed | in-game number):"
free.select { |b, _n, u, c| (c - u) >= 12 }.each { |b, n, u, c|
  puts "  idx %-3d (in-game Box %-3d) %-22s %d/%d used, %d free" % [b, b + 1, n, u, c, c - u] }
puts "\nfully EMPTY boxes: " + free.select { |_b, _n, u, _c| u.zero? }.map { |b, n, _u, _c| "idx#{b}(Box#{b+1}:#{n})" }.join(' ')
