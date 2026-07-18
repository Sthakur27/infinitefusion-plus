require_relative 'engine'
SimEngine.boot(verbose: true)

def probe(label)
  print "  #{label}: "
  puts yield.inspect[0, 100]
rescue Exception => e
  puts "FAIL #{e.class}: #{e.message.lines.first.to_s.strip[0,90]}"
  puts "      #{e.backtrace.find { |b| b !~ /engine\.rb|test_pokemon/ }}"
end

puts "== Pokemon construction =="
probe("Pokemon.new(:PIKACHU,50)") { Pokemon.new(:PIKACHU, 50).name }
probe("build a fusion (Blissey/Gliscor)") do
  fused = getFusionSpecies(:GLISCOR, :BLISSEY)   # (body, head)
  pk = Pokemon.new(fused, 100)
  "#{pk.speciesName} L#{pk.level} HP#{pk.totalhp}"
end
probe("real damage calc (Pikachu Thunderbolt vs Gyarados)") do
  atk = Pokemon.new(:PIKACHU, 50); atk.learn_move(:THUNDERBOLT)
  df  = Pokemon.new(:GYARADOS, 50)
  "constructed atk=#{atk.speciesName} def=#{df.speciesName} move=#{atk.moves.first.id}"
end
