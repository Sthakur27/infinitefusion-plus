# sidmod: Fusion Injector
# Reads Data/sidmod/injections.json (written by Claude from a chat description)
# and drops the described Pokémon / fusions into the PC, one per-mon Y/N confirm.
# Tracks a persistent "current working box" in Data/sidmod/injector_state.json so
# mons land in a known box instead of scattering. See sidmod.txt for full notes.

module SidmodInjector
  SPEC_PATH  = "Data/sidmod/injections.json"
  STATE_PATH = "Data/sidmod/injector_state.json"

  module_function

  def load_state
    return { "current_box" => 0 } unless File.exist?(STATE_PATH)
    JSON.parse(File.read(STATE_PATH)) rescue { "current_box" => 0 }
  end

  def save_state(state)
    File.write(STATE_PATH, JSON.generate(state))
  rescue => e
    echoln("SidmodInjector: could not save state: #{e}")
  end

  # Resolve a base-species token (name string, symbol, or dex #) to a species symbol.
  def resolve_base(token)
    return nil if token.nil?
    if token.is_a?(Integer) || token.to_s =~ /\A\d+\z/
      data = GameData::Species.try_get(token.to_i)
      return data ? data.species : nil
    end
    sym = token.to_s.upcase.gsub(/[^A-Z0-9]/, "").to_sym
    GameData::Species.exists?(sym) ? GameData::Species.get(sym).species : nil
  end

  def resolve_id(klass, token)
    return nil if token.nil? || token.to_s.empty?
    sym = token.to_s.upcase.gsub(/[^A-Z0-9]/, "").to_sym
    klass.exists?(sym) ? sym : nil
  end

  # Stats keep underscores (:SPECIAL_ATTACK) and accept common short aliases.
  STAT_ALIASES = {
    "HP" => :HP,
    "ATK" => :ATTACK, "ATTACK" => :ATTACK,
    "DEF" => :DEFENSE, "DEFENSE" => :DEFENSE,
    "SPA" => :SPECIAL_ATTACK, "SPATK" => :SPECIAL_ATTACK, "SPECIALATTACK" => :SPECIAL_ATTACK,
    "SPD" => :SPECIAL_DEFENSE, "SPDEF" => :SPECIAL_DEFENSE, "SPECIALDEFENSE" => :SPECIAL_DEFENSE,
    "SPE" => :SPEED, "SPEED" => :SPEED, "SPD_SPEED" => :SPEED
  }

  def resolve_stat(token)
    return nil if token.nil?
    key = token.to_s.upcase.gsub(/[^A-Z0-9]/, "")
    sym = STAT_ALIASES[key]
    return sym if sym && GameData::Stat.exists?(sym)
    nil
  end

  # Build one Pokemon from a spec hash. Returns [pkmn, label] or raises with a message.
  def build_pokemon(entry)
    level = (entry["level"] || 50).to_i.clamp(1, Settings::MAXIMUM_LEVEL)

    if entry["head"] || entry["body"]
      head = resolve_base(entry["head"])
      body = resolve_base(entry["body"])
      raise "unknown head species '#{entry["head"]}'" if head.nil?
      raise "unknown body species '#{entry["body"]}'" if body.nil?
      # getFusionSpecies(body, head) -> fused GameData::Species
      species = getFusionSpecies(body, head)
      label   = "#{GameData::Species.get(head).name}/#{GameData::Species.get(body).name}"
    else
      species = resolve_base(entry["species"])
      raise "unknown species '#{entry["species"]}'" if species.nil?
      label   = GameData::Species.get(species).name
    end

    pkmn = Pokemon.new(species, level, $Trainer)

    # Ability (forced by symbol) or ability index
    if entry["ability"]
      ab = resolve_id(GameData::Ability, entry["ability"])
      pkmn.ability = ab if ab
    elsif entry["ability_index"]
      pkmn.ability_index = entry["ability_index"].to_i
    end

    # Nature
    if entry["nature"]
      nat = resolve_id(GameData::Nature, entry["nature"])
      pkmn.nature = nat if nat
    end

    # Held item
    if entry["item"]
      it = resolve_id(GameData::Item, entry["item"])
      pkmn.item = it if it
    end

    # Moves (explicit set of up to 4)
    if entry["moves"].is_a?(Array) && !entry["moves"].empty?
      pkmn.forget_all_moves
      entry["moves"].first(Pokemon::MAX_MOVES).each do |mv|
        mid = resolve_id(GameData::Move, mv)
        pkmn.learn_move(mid) if mid
      end
    end

    # EVs / IVs
    if entry["ivs"].is_a?(Hash)
      entry["ivs"].each do |stat, val|
        sid = resolve_stat(stat)
        pkmn.iv[sid] = val.to_i.clamp(0, Pokemon::IV_STAT_LIMIT) if sid
      end
    end
    if entry["evs"].is_a?(Hash)
      GameData::Stat.each_main { |s| pkmn.ev[s.id] = 0 }
      entry["evs"].each do |stat, val|
        sid = resolve_stat(stat)
        pkmn.ev[sid] = val.to_i.clamp(0, Pokemon::EV_STAT_LIMIT) if sid
      end
    end

    # Gender (bypass single-gender lock like the debug menu does)
    if entry["gender"]
      g = { "male" => 0, "female" => 1, "genderless" => 2 }[entry["gender"].to_s.downcase]
      pkmn.instance_variable_set(:@gender, g) if g
    end

    # Poké Ball
    if entry["ball"]
      ball = resolve_id(GameData::Item, entry["ball"])
      pkmn.poke_ball = ball if ball
    end

    # Shiny
    pkmn.shiny = true if entry["shiny"]

    # Nickname
    pkmn.name = entry["nickname"] if entry["nickname"] && !entry["nickname"].to_s.empty?

    pkmn.calc_stats
    pkmn.heal
    [pkmn, label]
  end

  def run
    unless File.exist?(SPEC_PATH)
      pbMessage(_INTL("No spec found at {1}.\nAsk Claude to write some fusions there first.", SPEC_PATH))
      return
    end

    begin
      spec = JSON.parse(File.read(SPEC_PATH))
    rescue => e
      pbMessage(_INTL("Couldn't parse {1}:\n{2}", SPEC_PATH, e.to_s))
      return
    end

    state = load_state
    # A default_box in the spec updates the persistent current working box.
    if spec["default_box"]
      state["current_box"] = spec["default_box"].to_i
    end
    entries = spec["pokemon"] || spec["pokemons"] || []
    if !entries.is_a?(Array) || entries.empty?
      pbMessage(_INTL("Spec has no \"pokemon\" list to inject."))
      return
    end

    injected = 0
    skipped  = 0
    errors   = []

    entries.each_with_index do |entry, i|
      begin
        pkmn, label = build_pokemon(entry)
      rescue => e
        errors.push("##{i + 1}: #{e}")
        next
      end

      box = (entry["box"] || state["current_box"]).to_i
      box = box.clamp(0, $PokemonStorage.maxBoxes - 1)
      boxname = $PokemonStorage[box].name
      free = $PokemonStorage.pbFirstFreePos(box)

      nick = pkmn.name && pkmn.name != pkmn.speciesName ? " \"#{pkmn.name}\"" : ""
      shiny = pkmn.shiny? ? " [shiny]" : ""
      if free < 0
        pbMessage(_INTL("Box {1} \"{2}\" is FULL - skipping {3}{4}.", box + 1, boxname, label, nick))
        skipped += 1
        next
      end

      msg = _INTL("Inject {1}{2}{3}\nLv.{4}  ({5}/{6} moves)\ninto Box {7} \"{8}\"?",
                  label, nick, shiny, pkmn.level, pkmn.moves.length, Pokemon::MAX_MOVES,
                  box + 1, boxname)
      unless pbConfirmMessage(msg)
        skipped += 1
        next
      end

      if $PokemonStorage.pbMoveCaughtToBox(pkmn, box)
        pkmn.record_first_moves
        $Trainer.pokedex.register(pkmn)
        $Trainer.pokedex.set_owned(pkmn.species)
        injected += 1
      else
        errors.push("##{i + 1}: could not store #{label} in box #{box + 1}")
      end
    end

    save_state(state)

    # Archive the spec so it isn't injected twice (File.rename fails on Windows
    # if the destination exists, so clear it first).
    begin
      applied = "Data/sidmod/injections.applied.json"
      File.delete(applied) if File.exist?(applied)
      File.rename(SPEC_PATH, applied)
    rescue => e
      echoln("SidmodInjector: could not archive spec: #{e}")
    end

    summary = _INTL("Done. Injected {1}, skipped {2}.\nCurrent working box: {3}.",
                    injected, skipped, state["current_box"].to_i + 1)
    summary += "\n\nErrors:\n" + errors.join("\n") unless errors.empty?
    pbMessage(summary)
  end
end

DebugMenuCommands.register("sidmodinjectfusions", {
  "parent"      => "main",
  "name"        => _INTL("Inject Fusions from file (sidmod)"),
  "description" => _INTL("Reads Data/sidmod/injections.json and drops the described Pokémon into your PC (per-mon confirm)."),
  "effect"      => proc {
    SidmodInjector.run
  }
})
