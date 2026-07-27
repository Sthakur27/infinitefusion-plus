require_relative "build_team"; require_relative "agent_battle"; require_relative "roster"; SimEngine.boot; $DEBUG=false
field = Roster.field(File.join(__dir__,"reports","hf"))
BuildTeam.team(field["Squads"]).each { |pk| puts "  " + SimAgent.species_label(pk) }
