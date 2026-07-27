require_relative 'nstore'
require_relative 'nbattle'
NativeSim.boot!                      # LIVE save
live = NativeSim.all_pool.each_with_object({}) { |e, h|
  d = NativeSim.describe(e[:key]); h[e[:key]] = "#{d[:name]}|#{d[:species]}" }
snap = NStore.read_json('ou3', 'pool.json')
snapk = snap.each_with_object({}) { |(k, v), h| h[k] = "#{v['name']}|#{v['species']}" }
same = (live.keys & snapk.keys).count { |k| live[k] == snapk[k] }
moved = (live.keys & snapk.keys).count { |k| live[k] != snapk[k] }
puts "live pool #{live.length} | snapshot pool #{snapk.length}"
puts "keys present in both: #{(live.keys & snapk.keys).length}"
puts "  SAME mon at that box/slot : #{same}"
puts "  DIFFERENT mon there now   : #{moved}   <-- rating lookups by key are wrong for these"
puts "keys only in snapshot (mon gone/moved): #{(snapk.keys - live.keys).length}"
puts "keys only live (new/moved in):         #{(live.keys - snapk.keys).length}"
ex = (live.keys & snapk.keys).select { |k| live[k] != snapk[k] }.first(8)
ex.each { |k| puts "    #{k}: snapshot='#{snapk[k]}'  live='#{live[k]}'" }
