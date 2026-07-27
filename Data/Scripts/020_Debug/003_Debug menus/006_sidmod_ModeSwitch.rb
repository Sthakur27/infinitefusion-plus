# sidmod: mid-save game mode / difficulty switcher (debug menu)
# Lets an existing save flip between Classic / Remix / Legendary and
# Easy / Normal / Hard. Lives under Debug -> Player options...
#
# Notes on why each mode is handled the way it is:
# - Classic/Remix: trainer + wild data is chosen LIVE per battle by
#   getTrainersDataMode (reads SWITCH_MODERN_MODE), so just flipping the
#   switch is enough for future battles. We also clear the randomizer/
#   legendary switches so a save coming FROM Legendary returns to base data.
# - Legendary: this mode stores fused teams in $PokemonGlobal.randomTrainersHash
#   (built by pbShuffleTrainers, which detects SWITCH_LEGENDARY_MODE and
#   converts each mon to a legendary fusion). It also drops a legendary egg of
#   every legendary into the PC. So enabling it = initializeLegendaryMode +
#   pbShuffleTrainers. It's a new-game-oriented mode, hence the confirm prompt.

def sidmod_set_game_mode(target)
  case target
  when :CLASSIC, :REMIX
    # Clear any randomizer/legendary/expert state so base trainer data is used.
    $game_switches[SWITCH_LEGENDARY_MODE]           = false
    $game_switches[SWITCH_RANDOM_TRAINERS]          = false
    $game_switches[SWITCH_RANDOMIZED_AT_LEAST_ONCE] = false
    $game_switches[SWITCH_RANDOM_WILD_TO_FUSION]    = false
    $game_switches[SWITCH_EXPERT_MODE]              = false
    is_remix = (target == :REMIX)
    $game_switches[SWITCH_MODERN_MODE] = is_remix
    $Trainer.game_mode = is_remix ? 2 : 0 if $Trainer.respond_to?(:game_mode=)
    name = is_remix ? "Remix" : "Classic"
    pbMessage(_INTL("Game mode set to {1}.", name))
    pbMessage(_INTL("Future trainer battles and wild encounters will now use {1} data.", name))
  when :LEGENDARY
    return unless pbConfirmMessage(_INTL("Switch this save to Legendary Mode?\nEvery trainer's team is re-rolled into legendary fusions. It's built for new games - use with care."))
    # Inlined initializeLegendaryMode WITHOUT addLegendaryEggsToPC (sidmod: no egg dump).
    $game_variables[VAR_CURRENT_GYM_TYPE]           = -1
    $game_switches[SWITCH_RANDOM_TRAINERS]          = true
    $game_switches[SWITCH_RANDOMIZE_GYMS_SEPARATELY] = true
    $game_switches[SWITCH_GYM_RANDOM_EACH_BATTLE]   = false
    $game_switches[SWITCH_RANDOM_GYM_PERSIST_TEAMS] = true
    $game_switches[SWITCH_LEGENDARY_MODE]           = true
    $game_switches[SWITCH_RANDOMIZED_AT_LEAST_ONCE] = true
    $PokemonSystem.hide_custom_eggs = true
    $PokemonSystem.type_icons = true
    pbMessage(_INTL("Re-rolling trainers into legendary fusions..."))
    Kernel.pbShuffleTrainers
    $Trainer.game_mode = 3 if $Trainer.respond_to?(:game_mode=)
    pbMessage(_INTL("Legendary Mode enabled."))
  end
end

def sidmod_current_mode_text
  case getCurrentGameModeSymbol
  when :CLASSIC       then _INTL("Classic")
  when :REMIX         then _INTL("Remix")
  when :LEGENDARY     then _INTL("Legendary")
  when :EXPERT        then _INTL("Expert")
  when :RANDOMIZED    then _INTL("Randomized")
  when :SINGLE_SPECIES then _INTL("Single Species")
  else _INTL("Debug")
  end
end

# sidmod: "1.5" rather than "1.5000000000000002" in menu text.
def sidmod_multiplier_text(value)
  return format("%g", value.round(3))
end

# sidmod: set hard mode's level multiplier for THIS save (see hardModeLevelModifier
# in 052_InfiniteFusion/System/GameModes/GameDifficulty.rb). Asked for in percent
# because pbMessageChooseNumber only does integers.
def sidmod_set_hard_mode_multiplier
  default_pct = (Settings::HARD_MODE_LEVEL_MODIFIER * 100).round
  params = ChooseNumberParams.new
  params.setRange(100, 500)
  params.setDefaultValue((hardModeLevelModifier * 100).round)
  params.setCancelValue(-1)   # must come after setDefaultValue, which nils the cancel value
  pct = pbMessageChooseNumber(
    _INTL("Hard mode level multiplier, in percent.\n100 = no scaling, {1} = the default {2}x.",
          default_pct, sidmod_multiplier_text(Settings::HARD_MODE_LEVEL_MODIFIER)), params)
  return if !pct.is_a?(Numeric) || pct < 100
  if pct == default_pct
    # Back to the default -> drop the override so the save follows Settings again.
    $PokemonGlobal.sidmodHardModeLevelModifier = nil
  else
    $PokemonGlobal.sidmodHardModeLevelModifier = pct / 100.0
  end
  pbMessage(_INTL("Hard mode level multiplier is now {1}x.",
                  sidmod_multiplier_text(hardModeLevelModifier)))
  pbMessage(_INTL("Applies to trainer teams built from now on, and to your own level cap while on Hard."))
end

# sidmod: extracted so both the debug menu and the pause-menu shortcut can call it.
def sidmod_mode_difficulty_menu
    loop do
      header = _INTL("Current mode: {1}\nCurrent difficulty: {2} (Hard multiplier {3}x)",
                     sidmod_current_mode_text, getDisplayDifficulty,
                     sidmod_multiplier_text(hardModeLevelModifier))
      cmds = [
        _INTL("Mode: Classic"),
        _INTL("Mode: Remix"),
        _INTL("Mode: Legendary"),
        _INTL("Difficulty: Easy"),
        _INTL("Difficulty: Normal"),
        _INTL("Difficulty: Hard"),
        _INTL("Hard multiplier: {1}x", sidmod_multiplier_text(hardModeLevelModifier)),
        _INTL("Close")
      ]
      close_index = cmds.length - 1
      # sidmod bugfix: pbShowCommands' cmdIfCancel is ONE-BASED (it returns
      # cmdIfCancel - 1 on B). Passing close_index made B pick the entry *above*
      # Close - i.e. "Difficulty: Hard" - instead of closing. Pass close_index + 1.
      cmd = pbMessage(header, cmds, close_index + 1)
      break if cmd < 0 || cmd == close_index
      case cmd
      when 0 then sidmod_set_game_mode(:CLASSIC)
      when 1 then sidmod_set_game_mode(:REMIX)
      when 2 then sidmod_set_game_mode(:LEGENDARY)
      when 3, 4, 5
        idx = cmd - 3   # 0 Easy / 1 Normal / 2 Hard
        setDifficulty(idx)
        # Debug override: lowest_difficulty normally floors the display/rewards
        # to the easiest run ever played. Pin it to the chosen value so the
        # picked difficulty actually shows and applies with no residual gating.
        $Trainer.lowest_difficulty = idx if $Trainer.respond_to?(:lowest_difficulty=)
        pbMessage(_INTL("Difficulty set to {1}.", getDisplayDifficultyFromIndex(idx)))
      when 6
        sidmod_set_hard_mode_multiplier
      end
    end
end

DebugMenuCommands.register("sidmodmodeswitch", {
  "parent"      => "playermenu",
  "name"        => _INTL("Set Game Mode / Difficulty"),
  "description" => _INTL("sidmod: switch this save between Classic/Remix/Legendary and Easy/Normal/Hard, and set Hard's level multiplier."),
  "effect"      => proc {
    sidmod_mode_difficulty_menu
  }
})
