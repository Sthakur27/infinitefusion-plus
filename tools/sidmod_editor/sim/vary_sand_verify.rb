# VERIFY with the IMPROVED pilot (general competitive prompting + weather-war blocks):
#  (1) does proper weather-war / momentum play close the OU Sand vs OU Rain gap (old pilot: 1-4 bo5)?
#  (2) TTAR SPEED A/B: FAST TTar/Crobat (current, Spe 342, loses opening weather) vs
#      SLOW TTar/Crobat (Adamant 252HP/252Atk, 0 Spe ~227, WINS the opening weather war).
# Both sides use the improved pilot. Adopt SLOW only if NET POSITIVE across the whole suite.
require_relative 'build_team'; require_relative 'agent_battle'; require_relative 'editor'; require_relative 'roster'
require 'fileutils'
SimEngine.boot; $DEBUG = false
V2    = ClaudeClient::PARSE.call(File.read(File.join(__dir__, 'reports', 'final_v2', 'field_specs.json')))
GAUNT = ClaudeClient::PARSE.call(File.read(File.join(__dir__, 'reports', 'gauntlet', 'field_specs.json')))

SLOW_TTAR = {"head"=>"TYRANITAR","body"=>"CROBAT","ability"=>"SANDSTREAM","item"=>"LEFTOVERS","nature"=>"ADAMANT",
             "moves"=>["STEALTHROCK","UTURN","STONEEDGE","CRUNCH"],"evs"=>{"HP"=>252,"ATTACK"=>252,"DEFENSE"=>4},"level"=>100}
FAST = V2['OUSand'].map { |m| Editor.normalize(m) }
slow = V2['OUSand'].map(&:dup)
raise "slot1 not TTar/Crobat" unless slow[0]['head']=='TYRANITAR' && slow[0]['body']=='CROBAT'
slow[0] = SLOW_TTAR
SLOW = slow.map { |m| Editor.normalize(m) }

# Rain-with-Azumarill/Marowak confirmation (improved pilot) — earned 3-0 vs OUSand on the OLD pilot.
AZUMARO = {"head"=>"AZUMARILL","body"=>"MAROWAK","ability"=>"HUGEPOWER","item"=>"THICKCLUB","nature"=>"ADAMANT",
           "moves"=>["SWORDSDANCE","AQUAJET","EARTHQUAKE","KNOCKOFF"],"evs"=>{"HP"=>4,"ATTACK"=>252,"SPEED"=>252},"level"=>100}
rain_ab = V2['OURain'].map(&:dup); rain_ab[2] = AZUMARO
RAIN_AB = rain_ab.map { |m| Editor.normalize(m) }
PLAN_RAIN_AB = Roster.plan('OURain').sub(
  "Poliwrath/Swampert (physical, Waterfall/EQ/Mach Punch, Electric-IMMUNE)",
  "Azumarill/Marowak (Huge Power + Thick Club = x4 Atk, Water/Ground Electric-IMMUNE PRIORITY NUKE - rain boosts its Aqua Jet x1.5 on top; revenge/clean with priority regardless of speed)")

DIR = File.join(__dir__, 'reports', 'sand_verify'); FileUtils.mkdir_p(DIR)
def run_one(tag, build_a, plan_a, name, fld, games)
  _d, log, t = SimAgent.series(build_a, -> { BuildTeam.team(fld[name].map { |m| Editor.normalize(m) }) },
    SimAgent.claude_policy(plan_a, model: 'claude-sonnet-5'),
    SimAgent.claude_policy(Roster.plan(name), model: 'claude-sonnet-5'), games: games, cap: 60)
  res = t[:a] > t[:b] ? 'W' : (t[:b] > t[:a] ? 'L' : 'D')
  File.write(File.join(DIR, "#{tag}_vs_#{name}.txt"), "#{tag} vs #{name} bo#{games} #{t[:a]}-#{t[:b]}-#{t[:draw]}\n\n" + log.join("\n"))
  puts "RESULT>> #{tag.ljust(12)} vs #{name.ljust(11)}: #{t[:a]}-#{t[:b]}-#{t[:draw]}  (#{res})  [bo#{games}]"
end

# (1) SAND: pilot-fix verify + TTar speed A/B
[["FASTTTAR", -> { BuildTeam.team(FAST) }], ["SLOWTTAR", -> { BuildTeam.team(SLOW) }]].each do |tag, build|
  run_one(tag, build, Roster.plan('OUSand'), "OURain",   V2,    5)
  run_one(tag, build, Roster.plan('OUSand'), "OUSun",    V2,    3)
  run_one(tag, build, Roster.plan('OUSand'), "BlueRemix", GAUNT, 3)
end
# (2) RAIN: confirm Azumarill/Marowak swap holds on the improved pilot
run_one("RAINAZUMARO", -> { BuildTeam.team(RAIN_AB) }, PLAN_RAIN_AB, "OUSand", V2, 5)
puts "DONE"
