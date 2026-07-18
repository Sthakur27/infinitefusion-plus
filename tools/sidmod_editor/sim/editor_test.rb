require_relative 'spec_extract'
require_relative 'editor'
require_relative 'my_team'
SimEngine.boot
$DEBUG = false

spec = MY_TEAMS["Momentum"]
rec  = "Momentum lost to Sun [TEAM FLAW]: a fast Chlorophyll Grass/Fire sweeper (Volferia) outsped and Solar-Beamed the team; no solid check or fast revenge to it. Losses to Sand were [BLUNDER] (misplays), don't touch those. Fix: add a Grass resist / a faster Scarf revenge to reliably answer Chlorophyll sweepers."

new_spec, log = Editor.evolve("Momentum", spec, rec)
puts "=== CHANGELOG ==="
log.each { |l| puts "  #{l}" }
puts "\n=== REBUILT EVOLVED TEAM ==="
BuildTeam.team(new_spec).each do |pk|
  puts "  #{pk.speciesName.ljust(14)} #{(pk.ability&.id rescue '?')} @#{pk.item_id} #{pk.nature&.id}  #{pk.moves.map { |m| m.id }.join('/')}"
end
