# sidmod: PC Export
# Read-only dump of the party + all storage boxes to Data/sidmod/pc_dump.json so
# Claude can see what's in the PC (occupancy, existing mons) without parsing the
# marshalled save. Companion to the Fusion Injector (007). See sidmod.txt.

module SidmodPCExport
  DUMP_PATH = "Data/sidmod/pc_dump.json"

  module_function

  def safe(default = nil)
    yield
  rescue
    default
  end

  def gender_str(pkmn)
    { 0 => "male", 1 => "female", 2 => "genderless" }[safe { pkmn.gender }] || "?"
  end

  def mon_hash(pkmn)
    return nil if pkmn.nil?
    h = {}
    h["name"]    = safe { pkmn.name }
    h["species"] = safe { pkmn.speciesName }
    h["dex"]     = safe { pkmn.species_data.id_number }
    h["level"]   = safe { pkmn.level }
    h["fusion"]  = safe(false) { pkmn.isFusion? }
    if h["fusion"]
      hd = safe { GameData::Species.get(get_head_number_from_symbol(pkmn.species)).name }
      bd = safe { GameData::Species.get(get_body_number_from_symbol(pkmn.species)).name }
      h["head"] = hd
      h["body"] = bd
    end
    h["shiny"]   = safe(false) { pkmn.shiny? }
    h["gender"]  = gender_str(pkmn)
    h["ability"] = safe { pkmn.ability&.id }
    h["nature"]  = safe { pkmn.nature&.id }
    h["item"]    = safe { pkmn.item_id }
    h["moves"]   = safe([]) { pkmn.moves.map { |m| m.id } }
    h["ivs"]     = safe({}) { pkmn.iv.to_h }
    h["evs"]     = safe({}) { pkmn.ev.to_h }
    h
  end

  def run
    data = { "party" => [], "boxes" => [] }

    safe { $Trainer.party }&.each { |pk| data["party"].push(mon_hash(pk)) }

    (0...$PokemonStorage.maxBoxes).each do |b|
      box = $PokemonStorage[b]
      next if box.nil?
      slots = []
      filled = 0
      (0...$PokemonStorage.maxPokemon(b)).each do |i|
        mon = mon_hash($PokemonStorage[b, i])
        filled += 1 if mon
        slots.push(mon)   # nil = empty slot, so slot indices stay meaningful
      end
      data["boxes"].push({
        "index"    => b,           # 0-based
        "display"  => b + 1,       # what the UI shows
        "name"     => safe("") { box.name },
        "capacity" => slots.length,
        "filled"   => filled,
        "pokemon"  => slots
      })
    end

    begin
      File.write(DUMP_PATH, JSON.generate(data))
      total = data["boxes"].sum { |bx| bx["filled"] }
      pbMessage(_INTL("Exported party ({1}) + {2} boxes ({3} mons) to\n{4}.",
                      data["party"].compact.length, data["boxes"].length, total, DUMP_PATH))
    rescue => e
      pbMessage(_INTL("PC export failed:\n{1}", e.to_s))
    end
  end
end

DebugMenuCommands.register("sidmodexportpc", {
  "parent"      => "main",
  "name"        => _INTL("Export PC to file (sidmod)"),
  "description" => _INTL("Dumps your party + all boxes to Data/sidmod/pc_dump.json so Claude can read them."),
  "effect"      => proc {
    SidmodPCExport.run
  }
})
