# Gauntlet: Claude's "Momentum" team vs Sid's 3 weather teams (Claude agents both
# sides). Logs to reports/gauntlet/. READ-ONLY on the save.
require_relative 'teams'
require_relative 'my_team'
require_relative 'agent_battle'
SimEngine.boot
$DEBUG = false

GDIR = File.join(__dir__, 'reports', 'gauntlet')
require 'fileutils'; FileUtils.mkdir_p(GDIR)

MY_PLAN = "Balance team, NO weather dependence (so weather wars don't hurt you). " \
  "Win-cons: Rhychomp (Swords Dance Ground/Dragon), Gentom (Nasty Plot Ghost/Electric, Levitate=Ground-immune), " \
  "Lucazor (Swords Dance + Technician Bullet Punch PRIORITY). Magnevoir (Steel/Fairy Choice Specs breaker, Volt Switch for momentum). " \
  "Cofamory (Ghost/Flying wall: Stealth Rock/Roost/Will-O-Wisp/Whirlwind, immune to Normal/Fighting/Ground - your pivot & phazer). " \
  "Weavdactyl (Choice Scarf revenge-killer + U-turn). Plan: set Stealth Rock, pivot with Volt Switch/U-turn to bring win-cons in safely, " \
  "burn/phaze setup sweepers with Cofamory, revenge with Scarf or Bullet Punch, then sweep once a check is removed."

OPP_PLANS = {
  "Sun"  => "Sun team. Drought sun; Solar Power/Chlorophyll fire sweepers; Noida Spore/Taunt/U-turn; Bastion Sticky Web.",
  "Rain" => "Rain team. Drizzle rain; Swift Swim + 100% Thunder/Hurricane; Draking resists Grass+Electric; setup sweepers.",
  "Sand" => "Sand team. Sand Stream (+SpD Rock allies); physical Dragon Dance sweepers; Krookodile/Salamence answers Fighting.",
}

results = []
%w[Sun Rain Sand].each do |opp|
  mine   = BuildTeam.team(MY_TEAM_SPEC)              # fresh each battle (combat mutates)
  theirs = SimTeams.clone(SimTeams.load[opp])
  dec, log = SimAgent.run(mine, theirs,
                          SimAgent.claude_policy(MY_PLAN), SimAgent.claude_policy(OPP_PLANS[opp]),
                          seed: 1, cap: 70)
  winner = dec == 1 ? "Momentum" : dec == 2 ? opp : "draw"
  File.write(File.join(GDIR, "Momentum_vs_#{opp}.txt"),
             "Momentum (Claude's team) vs #{opp}\n\n" + log.join("\n") + "\n\nWINNER: #{winner}\n")
  results << [opp, winner]
  puts "Momentum vs #{opp}: #{winner}"
end
puts "\n=== GAUNTLET ==="
results.each { |o, w| puts "  vs #{o}: #{w}" }
wins = results.count { |_, w| w == "Momentum" }
puts "Momentum record: #{wins}/#{results.length}"
