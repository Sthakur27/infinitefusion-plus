require_relative "spec_extract"; require_relative "my_team"; require_relative "editor"
SimEngine.boot; $DEBUG=false
spec = MY_TEAMS["Momentum"]
sys = "You MUST modify the team to fix the stated weakness (change at least 1-2 mons/moves/items). Keep the archetype but do not return it unchanged. Output ONLY a JSON array of 6: {\"head\":\"S\",\"body\":\"S\",\"ability\":\"X\",\"item\":\"Y\",\"nature\":\"Z\",\"moves\":[\"A\",\"B\",\"C\",\"D\"],\"evs\":{\"HP\":6}}"
usr = "WEAKNESS: no answer to fast Chlorophyll Grass sweepers (loses to Sun). Add a real check/faster revenge. Keep the VoltTurn balance identity.\nCURRENT TEAM:\n" + ClaudeClient::GEN.call(spec)
t = ClaudeClient.complete(system: sys, user: usr, model: "claude-sonnet-5", max_tokens: 6000)
arr = ClaudeClient.json_parse(t[/\[.*\]/m])
arr.each { |m| puts "#{m["head"]}/#{m["body"]}  @#{m["item"]}  #{(m["moves"]||[]).join("/")}" }
