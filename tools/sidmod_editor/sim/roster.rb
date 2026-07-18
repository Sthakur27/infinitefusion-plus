# Shared roster: the 10-team field (as specs) + per-team plans. Used by the parallel
# worker, run_iteration, and evolve so they all agree on teams/plans.
require_relative 'teams'
require_relative 'my_team'
require_relative 'spec_extract'
require_relative 'editor'
require_relative 'claude_client'

module Roster
  PLANS = {
    "Sun"     => "SUN. Ninetales sets Drought. Wincons: Chlorophyll Venusaur (needs sun) + Regigigas/Gliscor (Poison Heal Facade, weather-INDEPENDENT = your safety valve). If enemy overwrites weather (Kyogre/Sand), STOP forcing sun sweeps; pivot to Regigigas + Blissey Sticky Web and grind. Spore-lock a threat early. Blaziken is 4x Rock - keep it off hazards.",
    "Rain"    => "RAIN. Politoed sets Drizzle. Wincons: Swift Swim sweepers (Ludicolo/Kabutops/Kingdra - DOUBLE speed in rain) + Togekiss Calm Mind (rain-independent backup). Kabutops Aqua Jet = priority revenge. If rain is overwritten, use Togekiss/priority, don't flounder. Don't loop Politoed's status - pivot with U-turn or attack.",
    "Sand"    => "SAND. Tyranitar sets Sand Stream. Physical DD sweepers, but ALL use Earthquake - a Ground-immune Flyer (Groudon/Gliscor) walls you; break it with Volcarona/Nidoking Ice Beam (4x) or Azumarill Waterfall. Azumarill has Aqua Jet priority - don't DD-loop in mirrors. Metagross holds Lum (eats one Spore).",
    "Squads"  => "LEGENDARY BALANCE. Kyogre sets Drizzle + Spore-locks. Core: Sylveon Pixilate ExtremeSpeed (priority nuke), Aegislash Spectral Thief/Whirlwind (phazes setup, steals boosts), Groudon/Gliscor (Poison Heal EQ wall). Ninetales also has Drought - do NOT activate it while your own Drizzle is up (they cancel).",
    "Box15A"  => "FAST LEGENDARY OFFENSE. Dragonite/Arceus (Multiscale DD + ExtremeSpeed) is the main wincon; Deoxys/Latios (Lum, fast) revenges; Reshiram/Clefable (Magic Guard LO) breaks walls freely. Dialga/Espeon Magic-Bounces Spore/hazards - lead it vs status. Kyogre/Toxapex Ice Beam 4x's Gliscor walls. Marowak/Arceus ExtremeSpeed is Ghost-IMMUNE - use Earthquake vs Ghosts.",
    "Box15B"  => "LEGENDARY BALANCE. Kyogre Drizzle + Spore-lock is the engine. Giratina Spectral Thief, Groudon Poison-Heal wall, Kyurem/Dialga (Scarf Moxie revenge, Icicle Crash 4x's Gliscor). Ninetales has Drought - don't overwrite your own Drizzle. Groudon is 4x Ice - keep it off Ice attacks. Dialga/Espeon Magic-Bounces status.",
    "Box15C"  => "SLOW TRICK ROOM. Reuniclus/Slowbro set Trick Room FIRST so your slow nukes (Marowak/Rhyperior Thick Club, Chandelure, Slaking) outspeed. Quagsire Water-Absorbs Kyogre's rain. No sleep answer - if slept, STAY IN and wait it out, never switch-loop. Weak to fast/weather; win by getting TR up and clicking your huge slow attackers.",
    "Momentum"=> "VOLTTURN MOMENTUM. Magnezone/Gardevoir + Weavile pivot with Volt Switch/U-turn to chip. Gengar/Rotom (Levitate) walls Ground teams - keep it healthy, Nasty Plot when safe. Weavile Scarf = revenge/speed control, save for cleanup; Icicle Crash 4x's Gliscor. Lucario/Scizor Bullet Punch answers Fairies (Sylveon).",
    "Overload"=> "HYPER-OFFENSE. Pick the SUPER move, punch holes, revenge with Scarf Electivire + priority (Bullet Punch/Ice Shard). Geninja (Protean) Taunts sleep/setup leads. Do NOT set up into Aegislash (Whirlwind/Spectral Thief) - just attack/revenge. No bulk - trade efficiently, don't get chip-worn.",
    "Bunker"  => "BULKY OFFENSE. Walls (Ferrothorn hazards, Blissey special wall) + wincons Suicune/Togekiss (Calm Mind, Ground-immune) & Dragonite/Scizor (Dragon Dance, Ice-neutral). Set hazards, wear them down, then sweep with a boosted wincon. Bisharp Sucker Punch/Knock Off priority. Preserve your wincon vs fast special + Spore.",
    "UbersOff" => "GEN5 UBERS HYPER-OFFENSE (vanilla control). Scarf Kyogre (Drizzle) = revenge + rain WaterSpout nuke; DD Rayquaza + Extreme Killer Arceus (Swords Dance -> ExtremeSpeed priority) sweep; Darkrai uses Dark Void to sleep a wall then Nasty Plot sweeps; Specs Dialga wallbreaks; Ferrothorn sets Rocks/Spikes. Lead hazards or Dark Void, clean with priority.",
    "UbersBal" => "GEN5 UBERS BALANCE (vanilla control). Groudon (Drought) + Kyogre (Drizzle) for weather + Stealth Rock; Dragon Tail phazes setup; Giratina walls (Will-O-Wisp / Rest-Sleep Talk); Choice Band Scizor Bullet Punch priority + Pursuit-traps; Calm Mind Latias & Nasty Plot Mewtwo are your late-game wincons. Set rocks, phaze, wear down, then sweep with a boosted CM/NP mon.",
    "Degen"    => "MAX-BROKEN FUSION. Kyogre/Arceus (Drizzle) Specs rain nuke; Marowak/Arceus @Thick Club = doubled Atk STAB ExtremeSpeed priority; Regigigas/Gliscor (Poison Heal bypasses Slow Start) SD sweeper; Mewtwo/Arceus fast Nasty Plot special; Giratina/Arceus Dragon Dance + ExtremeSpeed + Spectral Thief (steals boosts); Reshiram/Clefable (Magic Guard + Life Orb, no recoil) Calm Mind. Overwhelm with near-max-stat mons + priority + broken abilities.",
    "OU"       => "GEN5 OU BALANCE (vanilla control). Scarf Tyranitar (Sand Stream) revenge + Pursuit-trap; Ferrothorn hazards (SR/Spikes/Leech Seed); Gliscor (Poison Heal) EQ/Toxic/Roost stall; Life Orb Latios (Draco/Psyshock) breaker; Choice Band Scizor Bullet Punch/U-turn/Pursuit; Serene Grace Jirachi (Iron Head flinch + Wish). Set hazards, pivot, wear down, revenge with Scarf/priority.",
    "OUBalance"=> "OU BALANCE (fusion). Ferrothorn/Skarmory sets hazards (SR/Spikes) + Whirlwind phazes setup; Slowbro/Tangrowth (Regenerator) & Gliscor/Milotic (Poison Heal) wall + pivot; Rotom/Gyarados (Levitate) VoltTurns + burns; Starmie/Tentacruel Rapid-Spins hazards away. Win-con: Dragonite/Scizor (Multiscale Dragon Dance, Ice-neutral). Wear them down, phaze their sweepers, then DD sweep late.",
    "OURain"   => "OU RAIN (fusion). Politoed/Whimsicott sets Drizzle + U-turn/Encore. Three Swift Swim abusers DOUBLE speed in rain: Kingdra/Empoleon (special), Kabutops/Kingler (physical + Aqua Jet priority), Ludicolo/Sceptile (special, resists Water/Electric). Ferrothorn/Skarmory hazards + backbone. Dragonite/Scizor = rain-independent Dragon Dance wincon. Keep rain up, sweep with Swift Swimmers.",
    "OUSun"    => "OU SUN (fusion). Ninetales/Whimsicott sets Drought + Spore-locks a threat. Chlorophyll sweepers DOUBLE speed in sun: Venusaur/Chandelure (special, instant SolarBeam) + Leafeon/Arcanine (physical Leaf Blade/Flare Blitz). Charizard/Hydreigon (Solar Power, +Draco Meteor) breaks. Regigigas/Gliscor (Poison Heal Facade) = weather-INDEPENDENT wincon when sun is overwritten; Blissey/Shuckle walls + Sticky Web.",
    "OUSand"   => "OU BULKY SAND (fusion). Tyranitar/Aerodactyl sets Sand Stream + rocks (sand gives Rock types +50% SpD). Garchomp/Donphan = Sword Dance physical sweeper; Cradily/Ferrothorn special wall (Storm Drain absorbs Water) thrives in sand; Ferrothorn/Skarmory hazards + phaze; Gliscor/Milotic Poison-Heal stall. Dragonite/Scizor wincon. Grind with sand chip + bulk, sweep late.",
    "Ubers1"   => "UBERS BALANCE (fusion). Aegislash/Lugia (Multiscale) Spectral-Thief steals boosts + Whirlwind phazes; Kyogre/Mew (Drizzle) Spore + Water Spout; Groudon/Gliscor (Poison Heal) EQ wall+sweeper; Blissey/Lugia special wall + Thunder Wave; Slaking/Dragonite (Multiscale, NO Truant) ExtremeSpeed priority wincon; Dialga/Espeon (Magic Bounce) rocks + Calm Mind. Wall, phaze, then sweep with the Multiscale priority mon.",
    "Ubers2"   => "UBERS RAIN OFFENSE (fusion). Kyogre/Celebi (Drizzle) Specs Water Spout (SpA 401); Kingdra/Zekrom (Swift Swim) Bolt Strike + Dragon Dance (Atk 397, doubled speed in rain); Palkia/Flygon (Dry Skin heals in rain) Calm Mind. Groudon/Gliscor (Poison Heal) + Aegislash/Lugia (phaze) + Ferrothorn/Skarmory (hazards) are the spine so you aren't pure glass. Overwhelm in rain, fall back on the spine.",
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
