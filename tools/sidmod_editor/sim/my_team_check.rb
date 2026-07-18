# Validate my team constructs correctly (types/stats/moves) - no API calls.
require_relative 'my_team'
SimEngine.boot
$DEBUG = false

def types(pk)
  t = pk.types rescue [pk.type1, pk.type2].compact
  t.uniq.map(&:to_s).join("/")
end

team = BuildTeam.team(MY_TEAM_SPEC)
team.each do |pk|
  st = "H#{pk.totalhp} A#{pk.attack} B#{pk.defense} C#{pk.spatk} D#{pk.spdef} S#{pk.speed}"
  ab = (pk.ability && pk.ability.id) rescue pk.ability
  puts "#{pk.speciesName.ljust(16)} [#{types(pk)}]  #{ab} @#{pk.item_id}"
  puts "   #{st}   #{pk.moves.map { |m| m.id }.join(', ')}"
end
