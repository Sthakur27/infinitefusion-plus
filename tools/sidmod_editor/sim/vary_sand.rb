# Battle-test the CURRENT OU Sand (with Slaking/Sandslash) vs a VARIED opponent pool. Best-of-3.
require_relative 'build_team'; require_relative 'agent_battle'; require_relative 'editor'; require_relative 'roster'
require 'fileutils'
SimEngine.boot; $DEBUG = false
V2    = ClaudeClient::PARSE.call(File.read(File.join(__dir__, 'reports', 'final_v2', 'field_specs.json')))
GAUNT = ClaudeClient::PARSE.call(File.read(File.join(__dir__, 'reports', 'gauntlet', 'field_specs.json')))
mk = ->(f, t) { BuildTeam.team(f[t].map { |m| Editor.normalize(m) }) }
DIR = File.join(__dir__, 'reports', 'sand_vary'); FileUtils.mkdir_p(DIR)
# [label, field, team]
OPP = [["BlueRemix", GAUNT], ["BlueExpert", GAUNT], ["UbersOff", V2], ["UbersBal", V2], ["OU", V2]]
OPP.each do |name, fld|
  _d, log, t = SimAgent.series(-> { mk.(V2, 'OUSand') }, -> { mk.(fld, name) },
    SimAgent.claude_policy(Roster.plan('OUSand'), model: 'claude-sonnet-5'),
    SimAgent.claude_policy(Roster.plan(name), model: 'claude-sonnet-5'), games: 3, cap: 55)
  res = t[:a] > t[:b] ? 'W' : (t[:b] > t[:a] ? 'L' : 'D')
  File.write(File.join(DIR, "OUSand_vs_#{name}.txt"), "OUSand vs #{name} bo3 #{t[:a]}-#{t[:b]}-#{t[:draw]}\n\n" + log.join("\n"))
  puts "RESULT>> OUSand vs #{name.ljust(11)}: #{t[:a]}-#{t[:b]}-#{t[:draw]}  (#{res})"
end
