#===============================================================================
# sidmod: swap the whole party with a box row in one action.
#   A box row is BOX_WIDTH (6) slots = exactly one party, so "sand team out,
#   rain team in" becomes one command instead of a dozen carries.
#   The stock multi-select can't express this: pbHoldMulti refuses to lift your
#   last able Pokemon, so the party can never be emptied mid-move. Swapping both
#   sides in a single commit sidesteps that - the party is never empty.
#   Entry point: box name -> "Swap party" (added to BOTH pbBoxCommands).
#===============================================================================
class PokemonStorageScreen
  def boxCommandSwapPartyRow
    box = @storage.currentBox
    if pbHolding?
      pbDisplay(_INTL("You're holding a Pokémon!"))
      return
    end
    if @storage[box].is_a?(StorageTransferBox)
      pbDisplay(_INTL("You can't do that with the Transfer Box."))
      return
    end
    row = pbChooseSwapRow(box)
    return if row.nil?
    base = row * PokemonBox::BOX_WIDTH
    incoming = []
    for i in 0...PokemonBox::BOX_WIDTH
      pkmn = @storage[box, base + i]
      incoming.push(pkmn) if pkmn
    end
    outgoing = @storage.party.compact
    # The incoming half has to leave you with a usable party.
    if incoming.length == 0
      pbDisplay(_INTL("There's nothing in row {1}.", row + 1))
      return
    end
    able = 0
    incoming.each { |pkmn| able += 1 if pbAble?(pkmn) }
    if able == 0
      pbPlayBuzzerSE
      pbDisplay(_INTL("No Pokémon in row {1} is able to battle!", row + 1))
      return
    end
    # Mail can't be stored in a Box (same rule as Store/Release).
    outgoing.each do |pkmn|
      next if !pkmn.mail
      pbDisplay(_INTL("Please remove the mail."))
      return
    end
    return if !pbConfirm(_INTL("Swap your party with row {1}?", row + 1))
    party = @storage.party   # $Trainer.party - mutate in place, others hold this array
    party.clear
    incoming.each { |pkmn| party.push(pkmn) }
    for i in 0...PokemonBox::BOX_WIDTH
      @storage[box, base + i] = outgoing[i]   # nil for the slots that stay empty
    end
    pbSEPlay("GUI party switch")
    @scene.pbHardRefresh
    pbDisplay(_INTL("Took out {1}, put away {2}.", incoming.length, outgoing.length))
  end

  # Lists the non-empty rows of the box as "Row 2: Aegiapex +5". Returns the row
  # index (0-based), or nil if cancelled / nothing to swap with.
  def pbChooseSwapRow(box)
    commands = []
    rows = []
    for row in 0...PokemonBox::BOX_HEIGHT
      base = row * PokemonBox::BOX_WIDTH
      mons = []
      for i in 0...PokemonBox::BOX_WIDTH
        pkmn = @storage[box, base + i]
        mons.push(pkmn) if pkmn
      end
      next if mons.length == 0
      commands.push((mons.length > 1) ?
        _INTL("Row {1}: {2} +{3}", row + 1, mons[0].name, mons.length - 1) :
        _INTL("Row {1}: {2}", row + 1, mons[0].name))
      rows.push(row)
    end
    if rows.length == 0
      pbDisplay(_INTL("There's nothing in this Box to swap with."))
      return nil
    end
    commands.push(_INTL("Cancel"))
    cmd = pbShowCommands(_INTL("Swap your party ({1}) with which row?",
                               @storage.party.compact.length), commands)
    return nil if cmd < 0 || cmd >= rows.length
    return rows[cmd]
  end
end
