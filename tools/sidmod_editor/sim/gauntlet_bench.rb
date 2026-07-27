# Benchmark our 6 competitive teams vs the L100 Gauntlet (hardest E4 + Champions) — a REAL,
# non-self-referential meta. Each of our teams battles each gauntlet opponent. Best-of-1 sweep
# (records are directional; the point is a tougher, less-skewed opponent pool). Both sides piloted
# by Sonnet with their plans. Writes reports/gauntlet/results.txt.
require_relative 'build_team'; require_relative 'agent_battle'; require_relative 'editor'; require_relative 'roster'
require 'fileutils'
SimEngine.boot; $DEBUG = false
OURS  = ClaudeClient::PARSE.call(File.read(File.join(__dir__, 'reports', 'final_v2', 'field_specs.json')))
GAUNT = ClaudeClient::PARSE.call(File.read(File.join(__dir__, 'reports', 'gauntlet', 'field_specs.json')))
MYTEAMS = %w[OUBalance OURain OUSun OUSand Ubers1 Ubers2]
OPP     = %w[Lorelei Bruno Agatha Lance BlueExpert BlueRemix]
GAMES   = (ARGV[0] || 1).to_i
build = ->(f, t) { BuildTeam.team(f[t].map { |m| Editor.normalize(m) }) }

DIR = File.join(__dir__, 'reports', 'gauntlet'); FileUtils.mkdir_p(DIR)
rows = []
MYTEAMS.each do |mine|
  line = { team: mine, cells: {}, w: 0, l: 0, d: 0 }
  OPP.each do |opp|
    _dec, log, tally = SimAgent.series(-> { build.(OURS, mine) }, -> { build.(GAUNT, opp) },
      SimAgent.claude_policy(Roster.plan(mine), model: 'claude-sonnet-5'),
      SimAgent.claude_policy(Roster.plan(opp),  model: 'claude-sonnet-5'), games: GAMES, cap: 55)
    res = tally[:a] > tally[:b] ? 'W' : (tally[:b] > tally[:a] ? 'L' : 'D')
    line[:cells][opp] = "#{tally[:a]}-#{tally[:b]}"
    line[res == 'W' ? :w : res == 'L' ? :l : :d] += 1
    File.write(File.join(DIR, "#{mine}_vs_#{opp}.txt"), "#{mine} vs #{opp} best-of-#{GAMES} #{tally[:a]}-#{tally[:b]}-#{tally[:draw]}\n\n" + log.join("\n"))
    warn "  #{mine} vs #{opp}: #{res} (#{tally[:a]}-#{tally[:b]})"
  end
  rows << line
end

hdr = "TEAM".ljust(11) + OPP.map { |o| o[0, 9].ljust(10) }.join + "RECORD"
out = ["=== OUR TEAMS vs GAUNTLET (best-of-#{GAMES}) ===", hdr]
rows.each do |r|
  out << r[:team].ljust(11) + OPP.map { |o| (r[:cells][o] || '-').ljust(10) }.join + "#{r[:w]}W-#{r[:l]}L-#{r[:d]}D"
end
File.write(File.join(DIR, 'results.txt'), out.join("\n") + "\n")
puts "\n" + out.join("\n")
puts "\nwrote reports/gauntlet/results.txt"
