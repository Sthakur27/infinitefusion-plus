# Diagnose HOW our OU teams lose to Champion Blue (Expert). Best-of-3 each, full logs saved so we
# can read the failure mode (which Blue mon sweeps, what we fail to answer) before proposing a fix.
require_relative 'build_team'; require_relative 'agent_battle'; require_relative 'editor'; require_relative 'roster'
require 'fileutils'
SimEngine.boot; $DEBUG = false
OURS  = ClaudeClient::PARSE.call(File.read(File.join(__dir__, 'reports', 'final_v2', 'field_specs.json')))
GAUNT = ClaudeClient::PARSE.call(File.read(File.join(__dir__, 'reports', 'gauntlet', 'field_specs.json')))
build = ->(f, t) { BuildTeam.team(f[t].map { |m| Editor.normalize(m) }) }
DIR = File.join(__dir__, 'reports', 'blue_refine'); FileUtils.mkdir_p(DIR)
TEAMS = %w[OUBalance OURain OUSand]

TEAMS.each do |mine|
  _dec, log, tally = SimAgent.series(-> { build.(OURS, mine) }, -> { build.(GAUNT, 'BlueExpert') },
    SimAgent.claude_policy(Roster.plan(mine), model: 'claude-sonnet-5'),
    SimAgent.claude_policy(Roster.plan('BlueExpert'), model: 'claude-sonnet-5'), games: 3, cap: 55)
  File.write(File.join(DIR, "#{mine}_vs_BlueExpert.txt"), "#{mine} vs BlueExpert best-of-3: #{mine}=#{tally[:a]} Blue=#{tally[:b]} draw=#{tally[:draw]}\n\n" + log.join("\n"))
  puts "#{mine} vs BlueExpert: #{tally[:a]}-#{tally[:b]}-#{tally[:draw]}"
end
puts "logs -> reports/blue_refine/"
