# M2: round-robin all teams, N battles per pairing (sides alternated for fairness),
# print per-matchup records + overall win rates.  ruby tournament.rb [N]
require_relative 'teams'
SimEngine.boot
$DEBUG = false

teams = SimTeams.load
names = teams.keys
N = (ARGV[0] || 20).to_i

wins = Hash.new(0); games = Hash.new(0)
puts "Round-robin: #{names.length} teams, #{N} battles/pairing\n\n"
t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)

names.combination(2).each do |a, b|
  aw = bw = dr = 0
  N.times do |i|
    # alternate which team is on side 1 to cancel any turn-order edge
    if i.even?
      dec = SimBattle.run(SimTeams.clone(teams[a]), SimTeams.clone(teams[b]), seed: i + 1)
      (dec == 1 ? aw += 1 : dec == 2 ? bw += 1 : dr += 1)
    else
      dec = SimBattle.run(SimTeams.clone(teams[b]), SimTeams.clone(teams[a]), seed: i + 1)
      (dec == 1 ? bw += 1 : dec == 2 ? aw += 1 : dr += 1)
    end
  end
  wins[a] += aw; wins[b] += bw; games[a] += N; games[b] += N
  puts "  #{a.ljust(8)} #{aw.to_s.rjust(2)} - #{bw.to_s.rjust(2)}  #{b}" + (dr > 0 ? "   (#{dr} draw)" : "")
end

dt = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0
puts "\nOverall win rate:"
names.sort_by { |n| -wins[n].to_f / games[n] }.each do |n|
  pct = (100.0 * wins[n] / games[n]).round
  puts "  #{n.ljust(8)} #{pct}%  (#{wins[n]}/#{games[n]})"
end
puts "\n#{names.length * (names.length - 1) / 2 * N} battles in #{dt.round(1)}s"
