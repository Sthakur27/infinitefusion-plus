# EXPORT the ladder's best teams into a data pack the GAME can fight ("OU Apex").
#
#   ruby tools/sidmod_editor/sim/nexport_apex.rb <ladder_tag> [count] [out_path]
#   ruby tools/sidmod_editor/sim/nexport_apex.rb ladder_ou4 15
#
# WHY THIS SHIPS THE ACTUAL POKEMON INSTEAD OF box/slot KEYS
# A ladder team is stored as pool keys (b<box>s<slot>) into THAT RUN'S
# save_snapshot.rxdata. Those keys do NOT survive into the live save - measured on
# ladder_ou4, 6 of the 38 mons the top 15 rely on had been replaced by something
# else by the time this was written, including a slot that went from a Lv100
# Blisclops wall to a Lv50 Klefmime. Resolving keys against the live PC would
# therefore field silently WRONG teams. A recorded champion is a historical
# artifact, so we freeze the real Pokemon objects out of the run's snapshot; the
# pack then fights identically no matter how the PC is reorganised later.
#
# Output: Data/sidmod/ou_apex.rxdata - a Marshal dump of
#   { 'version', 'tag', 'tier', 'created', 'teams' => [ {rank, elo, games, niche,
#     source, lead_reason, names, mons: [Pokemon x6 - SLOT 0 IS THE RECORDED LEAD] } ] }
# Read in-game by 055_sidmod/RandomOpponent.rb (SidmodRandomOpp.apex_pack).
require 'json'
require 'fileutils'

TAG   = ARGV[0] || 'ladder_ou4'
COUNT = (ARGV[1] || 15).to_i
OUT   = ARGV[2] || 'Data/sidmod/ou_apex.rxdata'
DIR   = File.join(File.dirname(File.expand_path(__FILE__)), 'nreports', TAG)

# Parse the ladder BEFORE booting: SimEngine.boot swaps the stdlib JSON for the
# game's, after which JSON.parse returns nil for these keys (see RUNBOOK).
ladder = JSON.parse(File.read(File.join(DIR, 'ladder.json')))
top    = ladder['teams'].sort_by { |t| -t['elo'] }.first(COUNT)
tier   = ladder['tier']
stamp  = Time.now.strftime('%Y-%m-%d')

$LOAD_PATH.unshift(File.dirname(File.expand_path(__FILE__)))
require 'engine'
SimEngine.boot
$DEBUG = false

snap = StubLoader.load_file(File.join(DIR, 'save_snapshot.rxdata'))[:storage_system]

def at(storage, key)
  b, s = key.scan(/b(\d+)s(\d+)/).first.map(&:to_i)
  storage[b, s]
end

teams = []
top.each_with_index do |t, i|
  mons = t['keys'].map { |k| at(snap, k) }
  if mons.any?(&:nil?)
    warn "SKIP rank #{i + 1} (elo #{t['elo'].round}): #{t['keys'].select { |k| at(snap, k).nil? }.inspect} empty in snapshot"
    next
  end
  mons = mons.map do |pk|
    c = Marshal.load(Marshal.dump(pk))
    c.heal rescue nil
    c
  end
  teams << {
    'rank' => teams.length + 1, 'elo' => t['elo'].round(1), 'games' => t['games'],
    'niche' => t['niche'].to_s, 'source' => t['source'].to_s,
    'lead_reason' => t['lead_reason'].to_s,
    'names' => mons.map { |pk| (pk.name || pk.speciesName).to_s },
    'mons' => mons
  }
end

pack = { 'version' => 1, 'tag' => TAG, 'tier' => tier.to_s,
         'created' => stamp, 'teams' => teams }

FileUtils.mkdir_p(File.dirname(OUT))
File.binwrite(OUT, Marshal.dump(pack))

puts "wrote #{OUT}  (#{(File.size(OUT) / 1024.0).round(1)} KB)"
puts "#{teams.length} teams from #{TAG} (tier #{tier}), recorded #{stamp}"
teams.each do |t|
  puts format("  #%-2d elo %-7.1f %-4d games  %-13s %s", t['rank'], t['elo'], t['games'],
              t['niche'], t['names'].join(', '))
end

# Round-trip check: the pack is useless if it can't be read back.
back = Marshal.load(File.binread(OUT))
ok = back['teams'].length == teams.length &&
     back['teams'].all? { |t| t['mons'].length == 6 && t['mons'].all? { |m| m.respond_to?(:speciesName) } }
puts ok ? "round-trip OK (#{back['teams'].length} teams x 6 mons)" : "ROUND-TRIP FAILED"
exit(ok ? 0 : 1)
