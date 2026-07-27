require_relative 'build_team'; require_relative 'agent_battle'; require_relative 'editor'; require_relative 'roster'
require 'fileutils'
SimEngine.boot; $DEBUG=false
OURS  = ClaudeClient::PARSE.call(File.read(File.join(__dir__,'reports','final_v2','field_specs.json')))
GAUNT = ClaudeClient::PARSE.call(File.read(File.join(__dir__,'reports','gauntlet','field_specs.json')))
build = ->(f,t){ BuildTeam.team(f[t].map{|m| Editor.normalize(m)}) }
DIR = File.join(__dir__,'reports','blue_refine'); FileUtils.mkdir_p(DIR)
%w[OUBalance OUSand].each do |mine|
  _d,log,t = SimAgent.series(->{build.(OURS,mine)}, ->{build.(GAUNT,'BlueExpert')},
    SimAgent.claude_policy(Roster.plan(mine),model:'claude-sonnet-5'),
    SimAgent.claude_policy(Roster.plan('BlueExpert'),model:'claude-sonnet-5'), games:5, cap:55)
  File.write(File.join(DIR,"#{mine}_vs_BlueExpert_bo5.txt"),"#{mine} vs BlueExpert best-of-5: #{mine}=#{t[:a]} Blue=#{t[:b]} draw=#{t[:draw]}\n\n"+log.join("\n"))
  puts "#{mine} vs BlueExpert (bo5): #{t[:a]}-#{t[:b]}-#{t[:draw]}"
end
