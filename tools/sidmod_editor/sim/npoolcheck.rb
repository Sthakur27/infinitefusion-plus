require_relative 'nstore'
require_relative 'nbattle'
NativeSim.boot!   # live save, now updated
HAZ = ['Stealth Rock','Spikes','Toxic Spikes','Sticky Web']
REM = ['Rapid Spin','Defog']
REC = ['Recover','Roost','Soft-Boiled','Slack Off','Synthesis','Moonlight','Morning Sun','Rest','Wish','Shore Up','Strength Sap']
ou = NativeSim.pool(tier: :ou)
h = ->(k,l){ (NativeSim.entry(k)[:moves].map{|m| GameData::Move.get(m).name rescue m.to_s} & l).any? }
puts "OU-legal pool now: #{ou.length} (was 264)"
puts "  hazards : #{ou.count { |e| h.(e[:key], HAZ) }}  (was 31)"
puts "  removal : #{ou.count { |e| h.(e[:key], REM) }}  (was 6)"
puts "  recovery: #{ou.count { |e| h.(e[:key], REC) }}  (was 44)"
newm = ou.select { |e| e[:box] == 21 }
puts "\nnew Box 22 mons in pool: #{newm.length}"
newm.each { |e| d = NativeSim.describe(e[:key]); puts "  %-11s %-24s %-13s %s" % [d[:name], d[:species], d[:types], d[:moves].join('/')] }
