# Battle-test the NEW OU Sand (TTar/Crobat pivot lead + Aegislash/Toxapex wall) vs a FOCUSED pool:
# OU Rain + OU Sun + Blue Remix ONLY (weather-war matchups + a champion). Best-of-3.
require_relative 'build_team'; require_relative 'agent_battle'; require_relative 'editor'; require_relative 'roster'
require 'fileutils'
SimEngine.boot; $DEBUG = false
V2    = ClaudeClient::PARSE.call(File.read(File.join(__dir__, 'reports', 'final_v2', 'field_specs.json')))
GAUNT = ClaudeClient::PARSE.call(File.read(File.join(__dir__, 'reports', 'gauntlet', 'field_specs.json')))
mk = ->(f, t) { BuildTeam.team(f[t].map { |m| Editor.normalize(m) }) }
DIR = File.join(__dir__, 'reports', 'sand_focus'); FileUtils.mkdir_p(DIR)
# [label, field] — OU Rain + OU Sun + Blue Remix only
OPP = [["OURain", V2], ["OUSun", V2], ["BlueRemix", GAUNT]]
OPP.each do |name, fld|
  _d, log, t = SimAgent.series(-> { mk.(V2, 'OUSand') }, -> { mk.(fld, name) },
    SimAgent.claude_policy(Roster.plan('OUSand'), model: 'claude-sonnet-5'),
    SimAgent.claude_policy(Roster.plan(name), model: 'claude-sonnet-5'), games: 3, cap: 60)
  res = t[:a] > t[:b] ? 'W' : (t[:b] > t[:a] ? 'L' : 'D')
  File.write(File.join(DIR, "OUSand_vs_#{name}.txt"), "OUSand vs #{name} bo3 #{t[:a]}-#{t[:b]}-#{t[:draw]}\n\n" + log.join("\n"))
  puts "RESULT>> OUSand vs #{name.ljust(11)}: #{t[:a]}-#{t[:b]}-#{t[:draw]}  (#{res})"
end
puts "DONE"
