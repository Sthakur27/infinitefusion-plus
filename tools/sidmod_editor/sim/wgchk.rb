require_relative "nbattle"
NativeSim.boot!
ou = NativeSim.pool
wg = ou.select { |e| (e[:ref].ability&.id rescue nil) == :WONDERGUARD }
puts "Wonder Guard mons in OU pool: #{wg.length}"
wg.each { |e| d = NativeSim.describe(e[:key]); puts "  #{e[:key]} #{d[:name]} #{d[:species]} HP=#{d[:stats][0]} moves=#{d[:moves].join('/')}" }
low = ou.select { |e| (e[:ref].totalhp rescue 99) <= 5 }
puts "<=5 HP mons: " + low.map { |e| "#{e[:key]}:#{e[:name]}(hp #{e[:ref].totalhp})" }.join(", ")
