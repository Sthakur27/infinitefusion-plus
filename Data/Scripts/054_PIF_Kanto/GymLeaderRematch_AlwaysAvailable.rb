# sidmod: gym leader rematches always available - bypass the time-of-day gate.
#
# Vanilla: each of the 16 rematchable Gym Leaders only shows up at the rematch
# spot at a specific time of day (Brock during the day, Koga in the evening,
# Sabrina at night, etc). That gating is done in map-event conditional branches
# that flip a per-leader "has come to the rematch place" switch on/off based on
# the clock -- there's no script-level timer to disable.
#
# This hook force-enables all 16 leader switches on every map change, so every
# leader is always present at the rematch location regardless of time of day.
# Switch list is the same set read by Kernel.gymLeaderRematchHint (see
# "025-Randomizer/randomizer gym leader edit.rb") and matches the 16 used by the
# VAR_NB_GYM_REMATCHES >= 16 tier-4 league unlock.
#
# To revert: delete this file.

GYM_LEADER_REMATCH_SWITCHES = [
  426, # Brock        430, # Koga
  427, # Misty        431, # Sabrina
  428, # Lt. Surge    432, # Blaine
  429, # Erika        433, # Giovanni
  434, # Whitney      436, # Falkner
  435, # Kurt         437, # Clair
  508, # Morty        510, # Chuck
  509, # Pryce        511, # Jasmine
]

Events.onMapChange += proc { |_sender, _e|
  next unless $game_switches
  GYM_LEADER_REMATCH_SWITCHES.each { |sw| $game_switches[sw] = true }
}
