# LEAD SHOOTOUT: swap each candidate into OU Sand's lead slot, run the SAME broad field
# (OU Rain / OU Sun / Blue Remix), improved pilot, judge on AGGREGATE. Keep fast Crobat unless
# something clearly beats it across the field (NOT just rain). In-sim only, no save writes.
require_relative 'build_team'; require_relative 'agent_battle'; require_relative 'editor'; require_relative 'roster'
require 'fileutils'
SimEngine.boot; $DEBUG = false
V2    = ClaudeClient::PARSE.call(File.read(File.join(__dir__, 'reports', 'final_v2', 'field_specs.json')))
GAUNT = ClaudeClient::PARSE.call(File.read(File.join(__dir__, 'reports', 'gauntlet', 'field_specs.json')))

LEADS = {
  "Crobat"    => {"head"=>"TYRANITAR","body"=>"CROBAT","nature"=>"JOLLY","moves"=>%w[STEALTHROCK UTURN STONEEDGE CRUNCH],   "evs"=>{"HP"=>4,"ATTACK"=>252,"SPEED"=>252}},
  "Salamence" => {"head"=>"TYRANITAR","body"=>"SALAMENCE","nature"=>"ADAMANT","moves"=>%w[STEALTHROCK UTURN STONEEDGE CRUNCH],"evs"=>{"HP"=>4,"ATTACK"=>252,"SPEED"=>252}},
  "Leafeon"   => {"head"=>"TYRANITAR","body"=>"LEAFEON","nature"=>"ADAMANT","moves"=>%w[STEALTHROCK UTURN STONEEDGE LEAFBLADE],"evs"=>{"HP"=>4,"ATTACK"=>252,"SPEED"=>252}},
  "Articuno"  => {"head"=>"TYRANITAR","body"=>"ARTICUNO","nature"=>"ADAMANT","moves"=>%w[STEALTHROCK UTURN STONEEDGE CRUNCH], "evs"=>{"HP"=>252,"DEFENSE"=>4,"ATTACK"=>252}},
}
OPP = [["OURain", V2], ["OUSun", V2], ["BlueRemix", GAUNT]]
DIR = File.join(__dir__, 'reports', 'lead_shootout'); FileUtils.mkdir_p(DIR)

def sand_with(lead)
  base = V2['OUSand'].map(&:dup)
  base[0] = lead.merge("ability"=>"SANDSTREAM","item"=>"LEFTOVERS","level"=>100)
  base.map { |m| Editor.normalize(m) }
end

totals = {}
LEADS.each do |name, lead|
  team = sand_with(lead)
  agg = [0,0]
  OPP.each do |opp, fld|
    _d, log, t = SimAgent.series(-> { BuildTeam.team(team) }, -> { BuildTeam.team(fld[opp].map { |m| Editor.normalize(m) }) },
      SimAgent.claude_policy(Roster.plan('OUSand'), model: 'claude-sonnet-5'),
      SimAgent.claude_policy(Roster.plan(opp), model: 'claude-sonnet-5'), games: 3, cap: 60)
    agg[0] += t[:a]; agg[1] += t[:b]
    File.write(File.join(DIR, "#{name}_vs_#{opp}.txt"), "#{name} lead vs #{opp} bo3 #{t[:a]}-#{t[:b]}-#{t[:draw]}\n\n" + log.join("\n"))
    puts "RESULT>> #{name.ljust(10)} vs #{opp.ljust(11)}: #{t[:a]}-#{t[:b]}-#{t[:draw]}"
  end
  totals[name] = agg
  puts "AGGREGATE>> #{name.ljust(10)}: #{agg[0]}-#{agg[1]} games"
end
puts "\n=== LEAD SHOOTOUT AGGREGATE (games won-lost across Rain+Sun+BlueRemix bo3) ==="
totals.sort_by { |_, a| -a[0] }.each { |n, a| puts "  #{n.ljust(10)}: #{a[0]}-#{a[1]}" }
puts "DONE"
