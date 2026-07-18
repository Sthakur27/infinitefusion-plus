# Shared roster: the 10-team field (as specs) + per-team plans. Used by the parallel
# worker, run_iteration, and evolve so they all agree on teams/plans.
require_relative 'teams'
require_relative 'my_team'
require_relative 'spec_extract'
require_relative 'editor'
require_relative 'claude_client'

module Roster
  PLANS = {
    "Sun"     => "Sun: Drought; Solar Power/Chlorophyll fire sweepers; Spore/Taunt/U-turn; Sticky Web.",
    "Rain"    => "Rain: Drizzle; Swift Swim + 100% Thunder/Hurricane; setup sweepers.",
    "Sand"    => "Sand: Sand Stream; physical Dragon Dance sweepers.",
    "Squads"  => "Legendary all-star; Pixilate Extreme Speed priority; strong coverage.",
    "Box15A"  => "AI legendary offense (Kyogre/Deoxys/Latios/Reshiram/Rayquaza/Arceus); exploit coverage.",
    "Box15B"  => "AI legendary team (Kyogre/Dialga/Giratina/Groudon/Kyurem); strong coverage.",
    "Box15C"  => "AI non-legendary bulky team (Reuniclus/Slowbro/Rhyperior/Chandelure/Aggron/Slaking); grind.",
    "Momentum"=> "Balance, weather-independent; VoltTurn momentum; win-cons + Scarf/priority speed control.",
    "Overload"=> "Hyper-offense; fast mixed breakers; pick SUPER moves; setup when safe.",
    "Bunker"  => "Fat balance; hazards, Regenerator pivots, priority, Calm Mind wincon; outlast.",
  }

  module_function

  def plan(n); PLANS[n] || "Play type advantages, set up when safe, revenge with priority/scarf."; end

  # Field as {name => spec}. From reports/<tag>/field_specs.json if present, else the
  # base 10 (extracted from the save + my specs).
  def field(tag_dir = nil)
    f = tag_dir && File.join(tag_dir, 'field_specs.json')
    if f && File.exist?(f)
      ClaudeClient::PARSE.call(File.read(f)).transform_values { |t| t.map { |m| Editor.normalize(m) } }
    else
      SpecExtract.all
    end
  end
end
