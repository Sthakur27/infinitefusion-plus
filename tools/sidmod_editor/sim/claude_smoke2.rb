# Reproduce the battle-call 400 with full error text.
require_relative 'claude_client'
system = "You are an elite competitive Pokemon battler. This is Pokemon Infinite Fusion: fusions combine both parents' stats, movepools and abilities. Weather set by an ability is PERMANENT until another weather ability overwrites it. Win by exploiting types, weather wars, setup moves, priority, and predicting switches. Respond ONLY with the requested JSON."
user = <<~U
  WEATHER: Sun
  YOU: Draflosion HP 100% status=NONE ability=SOLARPOWER item=CHOICESPECS
  YOUR MOVES:
    [0] FLAMETHROWER Fire/Special pow95 pp15
    [1] FIREBLAST Fire/Special pow110 pp5
    [2] OVERHEAT Fire/Special pow130 pp5
    [3] UTURN Bug/Physical pow70 pp20
  OPPONENT: the opposing Sharcrunch HP 100% status=NONE types=WATER/GROUND
  PLAN: Sun team. Keep sun up; nuke with Solar Power specs.
  Pick the single best action. Respond ONLY with JSON: {"reason":"<=12 words","action":"move"|"switch","idx":<int>}
U
begin
  puts ClaudeClient.complete(system: system, user: user, max_tokens: 400)
rescue => e
  puts "FULL ERROR: #{e.message}"
end
