require_relative 'engine'
SimEngine.boot
$stdout.sync = true
def p2(l); print "#{l}: "; puts(yield.inspect[0,120]); rescue => e; puts "FAIL #{e.class}: #{e.message.lines.first.to_s.strip[0,90]}"; end
p2("TrainerType defined?") { defined?(GameData::TrainerType) }
p2("TrainerType count via each") { n=0; GameData::TrainerType.each { n+=1 }; n }
p2("first TT via each block") { GameData::TrainerType.each { |t| break t.id } }
p2("TrainerType::DATA size") { GameData::TrainerType::DATA.size }
p2("DATA first key") { GameData::TrainerType::DATA.keys.first }
p2("PokeBattle_DebugSceneNoLogging?") { defined?(PokeBattle_DebugSceneNoLogging) }
p2("NPCTrainer?") { defined?(NPCTrainer) }
