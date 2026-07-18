# Convert any team (real save Pokemon OR my built ones) into a uniform editable
# spec: [{head/body|species, ability, item, nature, moves[], evs{}, level}]. This
# is what the editor agent mutates and BuildTeam rebuilds, so all 10 teams evolve
# through the same pipeline.
require_relative 'build_team'

module SpecExtract
  module_function

  def mon(pk)
    s = pk.species
    spec = {}
    if s.is_a?(Symbol) && s.to_s =~ /\AB(\d+)H(\d+)\z/
      spec[:head] = (GameData::Species.get($2.to_i).id rescue $2.to_i)
      spec[:body] = (GameData::Species.get($1.to_i).id rescue $1.to_i)
    else
      spec[:species] = s
    end
    spec[:ability] = (pk.ability&.id rescue (pk.ability rescue nil))
    spec[:item]    = (pk.item_id rescue (pk.item&.id rescue nil))
    spec[:nature]  = (pk.nature&.id rescue (pk.nature rescue nil))
    spec[:moves]   = (pk.moves.map { |m| m.id } rescue [])
    spec[:level]   = 100          # normalize every team to L100 (no level bias)
    evs = {}
    (GameData::Stat.each_main { |st| v = (pk.ev[st.id] rescue 0); evs[st.id] = v if v && v > 0 } rescue nil)
    spec[:evs] = evs
    spec.reject { |_, v| v.nil? }
  end

  def team(pokemon_array)
    pokemon_array.compact.map { |pk| mon(pk) }
  end

  # All 10 teams as specs (their save teams extracted, mine already specs).
  def all
    require_relative 'teams'
    require_relative 'my_team'
    save = SimTeams.load
    out = {}
    %w[Sun Rain Sand Squads Box15A Box15B Box15C].each { |n| out[n] = team(save[n]) }
    %w[Momentum Overload Bunker].each { |n| out[n] = MY_TEAMS[n] }
    out
  end
end
