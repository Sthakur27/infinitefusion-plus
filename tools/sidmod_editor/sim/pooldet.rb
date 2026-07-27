require_relative "nbattle"
NativeSim.boot!
pk = $PokemonStorage[14, 14] rescue nil
puts "pool=#{NativeSim.all_pool.length} ou=#{NativeSim.pool.length} " \
     "b14s14 present_in_storage=#{!pk.nil?} " \
     "lvl=#{pk && pk.level} hasItem=#{pk && ((pk.hasItem? rescue 'RAISED'))} " \
     "item=#{pk && (pk.item&.id rescue 'ERR')} " \
     "in_pool=#{!NativeSim.entry('b14s14').nil?}"
