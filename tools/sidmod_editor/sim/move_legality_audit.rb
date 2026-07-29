# MOVE LEGALITY AUDIT — checks every L100 PC/party mon for illegal moves.
#
# Uses the game's own pbGetLegalMoves (020_Debug/001_Editor_Utilities.rb) which
# covers level-up + tutor/TM + baby-species egg moves. For fusions, unions both
# parents' pools. Also checks EVs (<=510 total, <=252 each).
#
#   ruby tools/sidmod_editor/sim/move_legality_audit.rb [save_path]
#
require_relative 'nbattle'

save = ARGV[0] || NativeSim.save_path_in_use
NativeSim.boot!(save)
$DEBUG = false

# RGSS (Ruby 1.8) allowed private methods with explicit receivers; Ruby 3.x does not.
# get_baby_species is private in 008_Species.rb but pbGetLegalMoves calls it with an
# explicit receiver. Make it public so the game's own function works in our sim.
GameData::Species.send(:public, :get_baby_species)

def legal_pool(pk)
  sp = pk.species
  if (pk.isFusion? rescue false)
    head_dex = getBasePokemonID(sp, false) rescue nil
    body_dex = getBasePokemonID(sp) rescue nil
    pool = []
    pool.concat(pbGetLegalMoves(head_dex)) if head_dex
    pool.concat(pbGetLegalMoves(body_dex)) if body_dex
    pool.uniq
  else
    pbGetLegalMoves(sp)
  end
end

EV_STATS = %i[HP ATTACK DEFENSE SPECIAL_ATTACK SPECIAL_DEFENSE SPEED]
EV_SHORT = { HP: 'HP', ATTACK: 'Atk', DEFENSE: 'Def', SPECIAL_ATTACK: 'SpA',
             SPECIAL_DEFENSE: 'SpD', SPEED: 'Spe' }

move_flags = []
ev_flags   = []
checked    = 0

$PokemonStorage.maxBoxes.times do |b|
  $PokemonStorage.maxPokemon(b).times do |i|
    pk = $PokemonStorage[b, i]
    next if pk.nil? || (pk.egg? rescue false)
    next unless pk.level == 100

    checked += 1
    loc = "Box#{b + 1} slot#{i + 1}"
    name = (pk.name || pk.speciesName).to_s
    species_name = (pk.speciesName rescue pk.species.to_s)

    # --- move check ---
    legal = legal_pool(pk)
    pk.moves.each do |mv|
      next unless mv && mv.id && mv.id != :NONE
      unless legal.include?(mv.id)
        move_name = (GameData::Move.get(mv.id).name rescue mv.id.to_s)
        if (pk.isFusion? rescue false)
          head_dex = getBasePokemonID(pk.species, false) rescue nil
          body_dex = getBasePokemonID(pk.species) rescue nil
          head_s = (GameData::Species.get(head_dex).name rescue '?')
          body_s = (GameData::Species.get(body_dex).name rescue '?')
          base_label = "#{head_s}/#{body_s}"
        else
          base_label = species_name
        end
        move_flags << { loc: loc, name: name, species: species_name,
                        bases: base_label, move: move_name, move_id: mv.id }
      end
    end

    # --- EV check ---
    evs = EV_STATS.map { |s| [s, (pk.ev[s] rescue 0)] }
    total = evs.sum { |_, v| v }
    bad = evs.select { |_, v| v > 252 }
    if total > 510 || bad.any?
      ev_str = evs.map { |s, v| "#{EV_SHORT[s]}#{v}" }.join('/')
      reason = []
      reason << "total=#{total}>510" if total > 510
      bad.each { |s, v| reason << "#{EV_SHORT[s]}=#{v}>252" }
      ev_flags << { loc: loc, name: name, species: species_name, evs: ev_str, reason: reason.join(', ') }
    end
  end
end

puts "=== MOVE LEGALITY AUDIT ==="
puts "Checked #{checked} L100 mons\n\n"

if move_flags.empty?
  puts "NO ILLEGAL MOVES FOUND"
else
  puts "#{move_flags.length} ILLEGAL MOVE(S):\n\n"
  move_flags.each do |f|
    puts "  #{f[:loc]}  #{f[:name]} (#{f[:bases]})  ->  #{f[:move]}"
  end
end

puts ""
if ev_flags.empty?
  puts "NO EV VIOLATIONS"
else
  puts "#{ev_flags.length} EV VIOLATION(S):\n\n"
  ev_flags.each do |f|
    puts "  #{f[:loc]}  #{f[:name]} (#{f[:species]})  #{f[:evs]}  [#{f[:reason]}]"
  end
end
