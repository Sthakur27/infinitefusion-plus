# A/B TEST: OU Sand with AZUMARILL/MAROWAK (Huge Power + Thick Club, x4 priority nuke)
# swapped IN over METAGROSS/GARCHOMP (the Scarf revenge slot). Same focused pool:
# OU Rain + OU Sun + Blue Remix. Best-of-3. Does NOT touch the committed field_specs.json.
require_relative 'build_team'; require_relative 'agent_battle'; require_relative 'editor'; require_relative 'roster'
require 'fileutils'
SimEngine.boot; $DEBUG = false
V2    = ClaudeClient::PARSE.call(File.read(File.join(__dir__, 'reports', 'final_v2', 'field_specs.json')))
GAUNT = ClaudeClient::PARSE.call(File.read(File.join(__dir__, 'reports', 'gauntlet', 'field_specs.json')))

# Build the A/B OUSand: copy committed OUSand, replace slot 2 (Metagross/Garchomp) with Azumarill/Marowak.
AZUMARO = {"head"=>"AZUMARILL","body"=>"MAROWAK","ability"=>"HUGEPOWER","item"=>"THICKCLUB","nature"=>"ADAMANT",
           "moves"=>["SWORDSDANCE","AQUAJET","EARTHQUAKE","KNOCKOFF"],"evs"=>{"HP"=>4,"ATTACK"=>252,"SPEED"=>252},"level"=>100}
ab = V2['OUSand'].map(&:dup)
raise "slot2 not Metagross/Garchomp" unless ab[1]['head']=='METAGROSS' && ab[1]['body']=='GARCHOMP'
ab[1] = AZUMARO
OUSAND_AB = ab.map { |m| Editor.normalize(m) }

# Pilot plan for the A/B team: same as OUSand but note the priority nuke instead of Scarf.
PLAN_AB = Roster.plan('OUSand').sub(
  "Metagross/Garchomp = Choice Scarf revenge killer (Steel/Ground RESISTS Ice, EQ/Iron Head/Outrage/Stone Edge).",
  "Azumarill/Marowak (Huge Power + Thick Club = QUADRUPLED Attack) = PRIORITY NUKE: AQUA JET (STAB priority) revenge-kills almost anything regardless of speed; Earthquake/Knock Off coverage; Swords Dance to end games. Water/Ground = immune Electric, only Grass-weak. It is SLOW - lean on Aqua Jet priority, don't expect to outspeed.")

mk = ->(f, t) { BuildTeam.team(f[t].map { |m| Editor.normalize(m) }) }
BASELINE = V2['OUSand'].map { |m| Editor.normalize(m) }   # committed team (Metagross/Garchomp)
DIR = File.join(__dir__, 'reports', 'sand_azumaro'); FileUtils.mkdir_p(DIR)

def run_one(tag, build_a, plan_a, name, fld, games)
  _d, log, t = SimAgent.series(build_a, -> { BuildTeam.team(fld[name].map { |m| Editor.normalize(m) }) },
    SimAgent.claude_policy(plan_a, model: 'claude-sonnet-5'),
    SimAgent.claude_policy(Roster.plan(name), model: 'claude-sonnet-5'), games: games, cap: 60)
  res = t[:a] > t[:b] ? 'W' : (t[:b] > t[:a] ? 'L' : 'D')
  File.write(File.join(DIR, "#{tag}_vs_#{name}.txt"), "#{tag} vs #{name} bo#{games} #{t[:a]}-#{t[:b]}-#{t[:draw]}\n\n" + log.join("\n"))
  puts "RESULT>> #{tag.ljust(16)} vs #{name.ljust(11)}: #{t[:a]}-#{t[:b]}-#{t[:draw]}  (#{res})  [bo#{games}]"
end

# 1) CONTROLLED rain de-noise at bo5: committed team vs Azumaro variant, same opponent.
run_one("BASELINE",  -> { BuildTeam.team(BASELINE) },   Roster.plan('OUSand'), "OURain", V2, 5)
run_one("AZUMARO",   -> { BuildTeam.team(OUSAND_AB) },   PLAN_AB,               "OURain", V2, 5)
# 2) Azumaro variant vs the other two (bo3, apples-to-apples with the baseline focus run).
run_one("AZUMARO",   -> { BuildTeam.team(OUSAND_AB) },   PLAN_AB,               "OUSun",    V2,    3)
run_one("AZUMARO",   -> { BuildTeam.team(OUSAND_AB) },   PLAN_AB,               "BlueRemix", GAUNT, 3)
puts "DONE"
