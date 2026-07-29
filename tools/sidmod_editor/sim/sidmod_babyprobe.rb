require_relative 'nbattle'
NativeSim.boot!(ARGV[0])
$DEBUG = false
%i[DRAGONITE DRAGONAIR DRATINI TYRANITAR PUPITAR LARVITAR MILOTIC].each do |s|
  sd = GameData::Species.get(s) rescue nil
  next unless sd
  gb = begin; sd.get_baby_species; rescue => e; "ERR:#{e.class}"; end
  puts "#{s}: get_baby_species=#{gb.inspect}"
  puts "   evolutions.raw=#{(sd.evolutions.inspect rescue 'ERR')[0,120]}"
end
# If get_baby_species chains, this baby's egg moves should have the goods:
[:DRAGONITE, :TYRANITAR].each do |s|
  sd = GameData::Species.get(s)
  baby = (sd.get_baby_species rescue nil)
  bd = (GameData::Species.get(baby) rescue nil)
  puts "BABY(#{s})=#{baby.inspect} egg.size=#{(bd.egg_moves.size rescue '?')} ES=#{(bd.egg_moves.include?(:EXTREMESPEED) rescue '?')} DD=#{(bd.egg_moves.include?(:DRAGONDANCE) rescue '?')}"
end
