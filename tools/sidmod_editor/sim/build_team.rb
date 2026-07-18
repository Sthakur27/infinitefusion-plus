# Build a team of real engine Pokemon from specs (for the sim / gauntlet).
# spec keys: head+body (symbols) or species; ability, nature, item, moves[], evs{}
require_relative 'battle'

module BuildTeam
  module_function
  STATS = [:HP, :ATTACK, :DEFENSE, :SPECIAL_ATTACK, :SPECIAL_DEFENSE, :SPEED]

  def mon(spec)
    lvl = 100                     # ALWAYS level 100 - no level bias between teams
    species = if spec[:head] || spec[:body]
                getFusionSpecies(spec[:body], spec[:head])   # (body, head)
              else
                GameData::Species.get(spec[:species])
              end
    pk = Pokemon.new(species, lvl)
    pk.ability = spec[:ability] if spec[:ability]
    pk.nature  = spec[:nature]  if spec[:nature]
    pk.item    = spec[:item]    if spec[:item]
    if spec[:moves]
      pk.moves.clear
      spec[:moves].first(4).each { |m| pk.moves.push(Pokemon::Move.new(m)) }
    end
    STATS.each { |s| pk.iv[s] = 31 }
    if spec[:evs]
      STATS.each { |s| pk.ev[s] = 0 }
      spec[:evs].each { |s, v| pk.ev[s] = v }
    end
    pk.calc_stats
    pk.heal
    pk
  end

  def team(specs); specs.map { |s| mon(s) }; end
end
