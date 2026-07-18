# Headless AI-vs-AI battle runner using the REAL engine.
# SimBattle.run(team1, team2) -> decision (1=team1 won, 2=team2 won, 5=draw, 0=aborted)
# team1/team2 are Arrays of Pokemon. Mirrors ChallengeGenerator_BattleSim.
require_relative 'engine'

module SimBattle
  module_function

  def make_trainer(name, party)
    t = NPCTrainer.new(name, SimEngine.trainer_type)
    party.each { |p| t.party.push(p) }
    t
  end

  # Runs one battle silently. Returns the decision integer.
  def run(team1, team2, seed: nil)
    srand(seed) if seed
    t1 = make_trainer("P1", team1)
    t2 = make_trainer("P2", team2)
    scene  = PokeBattle_DebugSceneNoLogging.new
    battle = PokeBattle_Battle.new(scene, t1.party, t2.party, t1, t2)
    battle.debug          = true    # 100-round timeout -> pbDecisionOnTime (never hangs)
    battle.controlPlayer  = true    # AI drives BOTH sides
    battle.internalBattle = false   # no $Trainer party/money/blackout side effects
    battle.canRun = false           # no fleeing in a sim
    # silence any stray engine stdout during the battle
    orig = $stdout; $stdout = File.open(File::NULL, "w")
    begin
      battle.pbStartBattle
    rescue Exception => e
      # Engine edge case (e.g. >3 Spikes layers -> nil division). Don't let one bad
      # battle kill a whole multi-battle run; score it a draw and move on.
      orig.puts "  [SimBattle] battle errored (#{e.class}: #{e.message.lines.first.to_s.strip[0, 70]}) -> draw"
      5
    ensure
      $stdout.close; $stdout = orig
    end
  end

  DECISION = { 1 => "team1 won", 2 => "team2 won", 3 => "ran", 5 => "draw", 0 => "aborted" }
end
