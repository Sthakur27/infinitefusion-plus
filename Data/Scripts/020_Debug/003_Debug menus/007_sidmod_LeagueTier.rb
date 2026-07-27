# sidmod: Elite Four league rematch tier setter (debug menu)
# Lives under Debug -> Player options... -> "Set Elite 4 Rematch Tier".
#
# The Elite Four rematch has 5 tiers with escalating levels (see
# 054_PIF_Kanto/EliteFourRematches/EliteFourRematches.rb):
#   Tier 1 ~L50-60, Tier 2 ~L60-70, Tier 3 ~L70-80, Tier 4 ~L80-90, Tier 5 all L100.
# Which tiers you can pick at the league is stored in SWITCH_LEAGUE_TIER_1..5;
# VAR_LEAGUE_REMATCH_TIER is the progression counter that unlock_new_league_tiers
# uses to hand out the NEXT tier each time you re-beat the league.
#
# Normally tiers unlock one at a time and are gated on SWITCH_BEAT_MT_SILVER (tier 3)
# and VAR_NB_GYM_REMATCHES >= 16 (tier 4). This command just sets the counter and
# flips the tier switches directly so you can jump to any tier.

# Resolved at call-time (a def body doesn't run at load), so it's safe even though
# SWITCH_LEAGUE_TIER_* are defined in folder 052 which loads AFTER this folder (020).
def sidmod_league_tier_switch(t)
  case t
  when 1 then SWITCH_LEAGUE_TIER_1
  when 2 then SWITCH_LEAGUE_TIER_2
  when 3 then SWITCH_LEAGUE_TIER_3
  when 4 then SWITCH_LEAGUE_TIER_4
  when 5 then SWITCH_LEAGUE_TIER_5
  end
end

def sidmod_set_league_tier(target)
  # Unlock tiers 1..target (make them selectable), lock the rest.
  (1..5).each { |t| $game_switches[sidmod_league_tier_switch(t)] = (t <= target) }
  # Set the progression counter so future league wins continue naturally from here.
  pbSet(VAR_LEAGUE_REMATCH_TIER, target)
  pbMessage(_INTL("Elite 4 rematch tiers 1-{1} unlocked (counter set to {1}).", target))
  pbMessage(_INTL("Talk to the league to pick a tier. Higher tier = higher levels (Tier 5 = all L100)."))
end

DebugMenuCommands.register("sidmodleaguetier", {
  "parent"      => "playermenu",
  "name"        => _INTL("Set Elite 4 Rematch Tier"),
  "description" => _INTL("sidmod: unlock/set the Elite Four league rematch tier (1-5). Higher = higher levels."),
  "effect"      => proc {
    loop do
      cur = pbGet(VAR_LEAGUE_REMATCH_TIER)
      unlocked = (1..5).select { |t| $game_switches[sidmod_league_tier_switch(t)] }
      header = _INTL("Progress counter (var 350): {1}\nUnlocked tiers: {2}",
                     cur, unlocked.empty? ? _INTL("none") : unlocked.join(", "))
      cmds = [
        _INTL("Tier 1 (~L50-60)"),
        _INTL("Tier 2 (~L60-70)"),
        _INTL("Tier 3 (~L70-80)"),
        _INTL("Tier 4 (~L80-90)"),
        _INTL("Tier 5 (all L100)"),
        _INTL("Close")
      ]
      close_index = cmds.length - 1
      cmd = pbMessage(header, cmds, close_index)
      break if cmd < 0 || cmd == close_index
      sidmod_set_league_tier(cmd + 1)
    end
  }
})
