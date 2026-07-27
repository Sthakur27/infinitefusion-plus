# CONTROLLED A/B: does AZUMARILL/MAROWAK belong on OU RAIN?
# Rain boosts Water (x1.5) AND its Aqua Jet is priority x4 Atk (HugePower x ThickClub) STAB.
# Swap it IN over slot 3 POLIWRATH/SWAMPERT (same Water/Ground Electric-immune PHYSICAL slot:
# trade rain-dependent Swift Swim speed for a rain-loving x4 priority nuke).
# Baseline OURain vs Azumaro-OURain, head-to-head on OUSand (weather war) + BlueRemix (hyper-offense).
require_relative 'build_team'; require_relative 'agent_battle'; require_relative 'editor'; require_relative 'roster'
require 'fileutils'
SimEngine.boot; $DEBUG = false
V2    = ClaudeClient::PARSE.call(File.read(File.join(__dir__, 'reports', 'final_v2', 'field_specs.json')))
GAUNT = ClaudeClient::PARSE.call(File.read(File.join(__dir__, 'reports', 'gauntlet', 'field_specs.json')))

AZUMARO = {"head"=>"AZUMARILL","body"=>"MAROWAK","ability"=>"HUGEPOWER","item"=>"THICKCLUB","nature"=>"ADAMANT",
           "moves"=>["SWORDSDANCE","AQUAJET","EARTHQUAKE","KNOCKOFF"],"evs"=>{"HP"=>4,"ATTACK"=>252,"SPEED"=>252},"level"=>100}
rain_ab = V2['OURain'].map(&:dup)
raise "slot3 not Poliwrath/Swampert" unless rain_ab[2]['head']=='POLIWRATH' && rain_ab[2]['body']=='SWAMPERT'
rain_ab[2] = AZUMARO
RAIN_AB = rain_ab.map { |m| Editor.normalize(m) }
RAIN_BASE = V2['OURain'].map { |m| Editor.normalize(m) }

PLAN_RAIN_AB = Roster.plan('OURain').sub(
  "Poliwrath/Swampert = Water/Ground, ELECTRIC-IMMUNE, Mach Punch priority + EQ (your Electric answer).",
  "Azumarill/Marowak (Huge Power + Thick Club = QUADRUPLED Atk, Water/Ground ELECTRIC-IMMUNE) = PRIORITY NUKE that LOVES rain: AQUA JET is priority Water STAB, boosted by rain x1.5 on top of x4 Atk - it revenge-kills / cleans almost anything regardless of speed. Earthquake + Knock Off coverage, Swords Dance to end games. Lead on Aqua Jet priority; it is slow so do NOT rely on outspeeding.")

DIR = File.join(__dir__, 'reports', 'rain_azumaro'); FileUtils.mkdir_p(DIR)
def run_one(tag, build_a, plan_a, name, fld, games)
  _d, log, t = SimAgent.series(build_a, -> { BuildTeam.team(fld[name].map { |m| Editor.normalize(m) }) },
    SimAgent.claude_policy(plan_a, model: 'claude-sonnet-5'),
    SimAgent.claude_policy(Roster.plan(name), model: 'claude-sonnet-5'), games: games, cap: 60)
  res = t[:a] > t[:b] ? 'W' : (t[:b] > t[:a] ? 'L' : 'D')
  File.write(File.join(DIR, "#{tag}_vs_#{name}.txt"), "#{tag} vs #{name} bo#{games} #{t[:a]}-#{t[:b]}-#{t[:draw]}\n\n" + log.join("\n"))
  puts "RESULT>> #{tag.ljust(14)} vs #{name.ljust(11)}: #{t[:a]}-#{t[:b]}-#{t[:draw]}  (#{res})  [bo#{games}]"
end

[["OUSand", V2], ["BlueRemix", GAUNT]].each do |name, fld|
  run_one("RAINBASE", -> { BuildTeam.team(RAIN_BASE) }, Roster.plan('OURain'), name, fld, 3)
  run_one("RAINAZUMARO", -> { BuildTeam.team(RAIN_AB) }, PLAN_RAIN_AB,        name, fld, 3)
end
puts "DONE"
