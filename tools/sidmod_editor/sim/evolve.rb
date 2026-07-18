# Evolution step with hill-climbing on GENERALITY.
#   ruby evolve.rb <in_tag> [out_tag] [model] [cap]
# Reads reports/<in_tag>/ (summary.txt win rates + recommendations.txt), evolves each
# team via the editor, then VALIDATES each changed candidate vs the WHOLE current field
# and only ADOPTS it if its aggregate win rate >= the team's baseline (else revert).
# Writes reports/<out_tag>/field_specs.json + changelog.txt. READ-ONLY on the save.
require_relative 'teams'
require_relative 'my_team'
require_relative 'spec_extract'
require_relative 'build_team'
require_relative 'agent_battle'
require_relative 'editor'
require_relative 'claude_client'
require 'fileutils'
SimEngine.boot
$DEBUG = false

IN_TAG  = ARGV[0] or abort "usage: evolve.rb <in_tag> [out_tag] [model] [cap]"
OUT_TAG = ARGV[1] || "#{IN_TAG}_v2"
MODEL   = ARGV[2] || "claude-haiku-4-5-20251001"
CAP     = (ARGV[3] || 55).to_i
IN_DIR  = File.join(__dir__, 'reports', IN_TAG)
OUT_DIR = File.join(__dir__, 'reports', OUT_TAG)
FileUtils.mkdir_p(OUT_DIR)

PLANS = {
  "Sun"=>"Sun: Drought; Solar Power/Chlorophyll fire sweepers; Spore/Taunt/U-turn; Sticky Web.",
  "Rain"=>"Rain: Drizzle; Swift Swim + 100% Thunder/Hurricane; setup sweepers.",
  "Sand"=>"Sand: Sand Stream; physical Dragon Dance sweepers.",
  "Squads"=>"Legendary all-star; Pixilate Extreme Speed priority; strong coverage.",
  "Box15A"=>"AI legendary offense (Kyogre/Deoxys/Latios/Reshiram/Rayquaza/Arceus); exploit coverage.",
  "Box15B"=>"AI legendary team (Kyogre/Dialga/Giratina/Groudon/Kyurem); strong coverage.",
  "Box15C"=>"AI non-legendary bulky team (Reuniclus/Slowbro/Rhyperior/Chandelure/Aggron/Slaking); grind.",
  "Momentum"=>"Balance, weather-independent; VoltTurn momentum; win-cons + Scarf/priority speed control.",
  "Overload"=>"Hyper-offense; fast mixed breakers; pick SUPER moves; setup when safe.",
  "Bunker"=>"Fat balance; hazards, Regenerator pivots, priority, Calm Mind wincon; outlast.",
}
def plan(n) PLANS[n] || "Play type advantages, set up when safe, revenge with priority/scarf." end

# ---- load current field ----
field_file = File.join(IN_DIR, 'field_specs.json')
field = if File.exist?(field_file)
          ClaudeClient::PARSE.call(File.read(field_file)).transform_values { |t| t.map { |m| Editor.normalize(m) } }
        else
          SpecExtract.all                       # round 0
        end
names = field.keys

# ---- baseline win rates from summary.txt ----
baseline = {}
sfile = File.join(IN_DIR, 'summary.txt')
# summary line: "Box15A    22%  (2/9)"  -> baseline = wins/games (fraction 0..1)
File.read(sfile).each_line { |ln| baseline[$1] = $3.to_f / [$4.to_i, 1].max if ln =~ /^\s*(\w+)\s+(\d+)%\s+\((\d+)\/(\d+)\)/ } if File.exist?(sfile)

coach_text = File.exist?(File.join(IN_DIR, 'recommendations.txt')) ? File.read(File.join(IN_DIR, 'recommendations.txt')) : ""

sig = ->(t) { t.map { |m| [m[:head], m[:body], m[:species], m[:ability], m[:item], (m[:moves] || []).sort] } }

new_field = {}
report = []
names.each do |name|
  cand, log = Editor.evolve(name, field[name], coach_text, model: MODEL)
  if sig.(cand) == sig.(field[name])
    new_field[name] = field[name]
    report << "#{name}: no change (no structural flaw)"
    puts report.last
    next
  end
  # validate candidate vs the WHOLE current field (fixed opponents)
  w = 0; g = 0
  (names - [name]).each do |opp|
    dec = SimAgent.run(BuildTeam.team(cand), BuildTeam.team(field[opp]),
                       SimAgent.claude_policy(plan(name), model: MODEL),
                       SimAgent.claude_policy(plan(opp), model: MODEL), seed: 1, cap: CAP)
    g += 1; w += 1 if dec == 1
  end
  cwr = g > 0 ? w.to_f / g : 0.0
  bwr = baseline[name] || 0.5
  if cwr >= bwr
    new_field[name] = cand
    report << "#{name}: ADOPTED  v2 #{(cwr*100).round}% >= baseline #{(bwr*100).round}%\n    " + log.join("\n    ")
  else
    new_field[name] = field[name]
    report << "#{name}: REVERTED  v2 #{(cwr*100).round}% < baseline #{(bwr*100).round}% (edit didn't generalize)\n    tried: " + log.join(" | ")
  end
  puts report.last
end

File.write(File.join(OUT_DIR, 'field_specs.json'), ClaudeClient::GEN.call(new_field))
File.write(File.join(OUT_DIR, 'changelog.txt'), report.join("\n\n"))
puts "\n=== written reports/#{OUT_TAG}/field_specs.json + changelog.txt ==="
