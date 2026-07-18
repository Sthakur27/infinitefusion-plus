# One full Claude-vs-Claude showcase battle with reasoning, on the real engine.
#   ruby agent_showcase.rb [TEAM_A] [TEAM_B]
require_relative 'teams'
require_relative 'agent_battle'
SimEngine.boot
$DEBUG = false

teams = SimTeams.load
PLANS = {
  "Sun"     => "Sun team. Keep Drought sun up; sweep with Solar Power Draflosion & Chlorophyll Volferia; Noida has Spore/Taunt/U-turn; Bastion sets Sticky Web. Beware opposing weather overwriting your sun.",
  "Rain"    => "Rain team. Keep Drizzle rain up (Swift Swim + 100% Thunder/Hurricane); Draking resists Grass+Electric; several setup sweepers. Overwrite enemy weather.",
  "Sand"    => "Sand team. Keep Sand Stream up (Rock allies get +SpD); physical DD sweepers; Krookodile/Salamence answers Fighting.",
  "Blissey" => "Blissey bulk team; Serene Grace + huge HP; set up Calm Mind/Bulk Up; Magic Bounce blocks hazards/status.",
  "Offense" => "Offense: individually strong sweepers (Adaptability Boombox, Speed Boost Golisopod/Blaziken, Nasty Plot Hydreigon/Gengar).",
}
A = ARGV[0] || "Sun"
B = ARGV[1] || "Rain"
MODEL = ARGV[2] || "claude-haiku-4-5-20251001"   # ruby agent_showcase.rb Sun Rain [model]

dec, log = SimAgent.run(
  SimTeams.clone(teams[A]), SimTeams.clone(teams[B]),
  SimAgent.claude_policy(PLANS[A] || "", model: MODEL), SimAgent.claude_policy(PLANS[B] || "", model: MODEL),
  seed: 5
)
puts "#{A} (side0) vs #{B} (side1) — Claude vs Claude\n\n"
puts log
puts "\nRESULT: #{dec == 1 ? A : dec == 2 ? B : SimBattle::DECISION[dec]} wins"
