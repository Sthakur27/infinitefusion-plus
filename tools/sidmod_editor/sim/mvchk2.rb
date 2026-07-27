require_relative "build_team"; require_relative "editor"; SimEngine.boot; $DEBUG=false
%w[SHADOWCLAW REST SUPERPOWER DRAGONPULSE PSYSHOCK FLASHCANNON OUTRAGE SHADOWBALL CLOSECOMBAT PSYCHIC RECOVER AURASPHERE FIREPUNCH DRAGONTAIL].each { |m| puts "#{GameData::Move.exists?(m) ? "OK " : "BAD"} #{m}" }
