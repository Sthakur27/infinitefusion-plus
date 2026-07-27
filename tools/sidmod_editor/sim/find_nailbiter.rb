# Rank battle logs by how CLOSE the finish was: the winning side's HP on its last
# recorded turn (low = the winner barely survived). Filters out fast wipes and stalls.
require 'json'
DIR = File.join(__dir__, 'reports')
rows = []
Dir.glob(File.join(DIR, '**', '*.txt')).each do |f|
  next if f =~ /summary|recommendations|changelog/
  t = File.read(f)
  hdr = t[/^(\S.*?) \(side0\) vs (.*?) \(side1\)/, 0]
  next unless hdr
  s0 = t[/^(\S.*?) \(side0\)/, 1]; s1 = t[/\(side0\) vs (.*?) \(side1\)/, 1]
  win = (t[/WINNER:\s*(.+)\s*$/, 1] || '').strip
  next if win.empty?
  win_side = (win == s0) ? '0' : (win == s1) ? '1' : nil
  next unless win_side
  hp = { '0' => [], '1' => [] }
  turns = 0
  t.each_line do |ln|
    if ln =~ /^\s*side(\d).*\((\d+)%\)\s*->/
      hp[$1] << $2.to_i; turns += 1
    end
  end
  next if hp[win_side].empty? || turns < 24     # skip fast wipes
  last_win = hp[win_side].last
  loser_side = win_side == '0' ? '1' : '0'
  last_lose = hp[loser_side].last
  rows << { f: f.sub(DIR + File::SEPARATOR, ''), win: win, turns: turns,
            win_last_hp: last_win, lose_last_hp: last_lose }
end
rows.sort_by! { |r| [r[:win_last_hp], -r[:turns]] }
puts "Closest finishes (winner's HP on its last turn):"
rows.first(14).each do |r|
  puts sprintf("  win_hp %3d%%  lose_hp %3d%%  turns %3d  winner=%-9s  %s",
               r[:win_last_hp], r[:lose_last_hp], r[:turns], r[:win], r[:f])
end
