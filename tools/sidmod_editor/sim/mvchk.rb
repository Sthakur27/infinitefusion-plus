require_relative "build_team"; require_relative "editor"; SimEngine.boot; $DEBUG=false
%w[AQUAJET ENCORE TAUNT FOCUSBLAST DRACOMETEOR FLAMETHROWER ROOST].each { |mv| puts "#{mv}: #{GameData::Move.exists?(mv)}" }
puts "LUMBERRY item exists: #{GameData::Item.exists?(:LUMBERRY) rescue 'n/a'}"
