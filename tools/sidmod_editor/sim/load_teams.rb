# M2 bridge test: load the 5 real teams from File A (read-only) into the engine
# as real battle-ready Pokemon, print them, and run one cross-team battle.
require_relative 'battle'
SimEngine.boot
$DEBUG = false

SAVE = File.join(ENV['APPDATA'], 'infinitefusion', 'File A.rxdata')
# StubLoader keeps real classes real (Pokemon etc.) and only stubs undefined ones
# (e.g. RPG::AudioFile) + passes userdef types through. Read-only.
save = StubLoader.load_file(SAVE)
party   = save[:player].party.compact
storage = save[:storage_system]
box31   = (0...24).map { |i| storage[30, i] }.compact   # box index 30 = display Box 31

TEAMS = {
  "Sun (party)" => party[0, 6],
  "Rain"        => box31[0, 6],
  "Sand"        => box31[6, 6],
  "Blissey"     => box31[12, 6],
  "Offense"     => box31[18, 6],
}

TEAMS.each do |name, t|
  puts "#{name}: " + t.map { |p| p.name == p.speciesName ? p.speciesName : "#{p.name}(#{p.speciesName})" }.join(", ")
end

def clone_team(t); t.map { |p| Marshal.load(Marshal.dump(p)) }; end

puts "\nSample battles:"
[["Sun (party)", "Rain"], ["Sand", "Blissey"], ["Rain", "Offense"]].each do |a, b|
  dec = SimBattle.run(clone_team(TEAMS[a]), clone_team(TEAMS[b]), seed: 7)
  winner = dec == 1 ? a : dec == 2 ? b : SimBattle::DECISION[dec]
  puts "  #{a} vs #{b}: #{winner}"
end
