require_relative 'nstore'
require_relative 'nbattle'
NativeSim.boot!
ARGV[0].split(',').map(&:to_i).each do |b|
  mons = (0...$PokemonStorage.maxPokemon(b)).map { |i| [i, $PokemonStorage[b, i]] }.reject { |_i, p| p.nil? }
  nm = ($PokemonStorage.boxes[b].name rescue "Box #{b+1}")
  puts "=== idx #{b} (in-game Box #{b + 1}) \"#{nm}\" — #{mons.length} mons"
  mons.each do |i, pk|
    evt = %i[HP ATTACK DEFENSE SPECIAL_ATTACK SPECIAL_DEFENSE SPEED].sum { |s| (pk.ev[s] rescue 0) }
    ivmin = %i[HP ATTACK DEFENSE SPECIAL_ATTACK SPECIAL_DEFENSE SPEED].map { |s| (pk.iv[s] rescue 0) }.min
    puts "  slot %-3d %-12s %-24s L%-4d item=%-14s nat=%-10s EVtot=%-4d IVmin=%-3d %s" % [
      i + 1, (pk.name || pk.speciesName).to_s, (pk.speciesName rescue '?'), pk.level,
      (pk.item&.name rescue 'NONE'), (pk.nature&.name rescue '?'), evt, ivmin,
      (pk.moves.map { |m| m.name } rescue []).join('/')]
  end
end
