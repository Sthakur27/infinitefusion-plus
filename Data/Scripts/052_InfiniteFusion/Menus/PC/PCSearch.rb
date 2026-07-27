#===============================================================================
# sidmod: PC search/filter
#   Triggered from PokemonStorageScene via Input::AUX2 (RB).
#   Returns [box_idx, slot_idx] of the chosen mon, or nil if cancelled / no match.
#===============================================================================
module PCSearch
  module_function

  # sidmod: was 60 (a pbMessage choice list that long is unusable) - the result
  # list scrolls and filters now, so the cap only exists to bound the work of
  # building the rows.
  MAX_RESULTS = 300

  def open(storage)
    cmd = pbMessage(_INTL("Filter by:"), [
      _INTL("Type"),
      _INTL("Level range"),
      _INTL("Name (contains)"),
      _INTL("Dex # range"),
      _INTL("Cancel")
    ], -1)
    case cmd
    when 0 then filter_by_type(storage)
    when 1 then filter_by_level(storage)
    when 2 then filter_by_name(storage)
    when 3 then filter_by_dex(storage)
    else nil
    end
  end

  # sidmod: both type prompts are live-filter lists now (same UX as the debug
  # menu's "Teach move" picker) instead of two long pbMessage choice lists.
  def filter_by_type(storage)
    # primary type
    chosen1 = choose_searchable(type_entries, _INTL("type"))
    return nil if chosen1.nil?
    name1 = GameData::Type.get(chosen1).name
    # secondary type (optional - the "(Any / single-type)" row is :any)
    entries2 = [[_INTL("(Any / single-type)"), "any single", :any]] + type_entries
    chosen2 = choose_searchable(entries2, _INTL("2nd type"))
    return nil if chosen2.nil?
    if chosen2 == :any
      matches = collect_matches(storage) { |p| pkmn_types(p).include?(chosen1) }
      pick_match(matches, _INTL("{1}-type", name1))
    else
      name2 = GameData::Type.get(chosen2).name
      matches = collect_matches(storage) { |p|
        ts = pkmn_types(p)
        ts.include?(chosen1) && ts.include?(chosen2)
      }
      pick_match(matches, _INTL("{1}/{2}", name1, name2))
    end
  end

  # [row text, search text, type id] for every real type, alphabetical, with a
  # Cancel row last (ESC works too - the row is just discoverable).
  def type_entries
    entries = []
    GameData::Type.each do |t|
      next if t.pseudo_type
      entries.push([t.name, t.name.downcase + " " + t.id.to_s.downcase, t.id])
    end
    entries.sort! { |a, b| a[0].downcase <=> b[0].downcase }
    entries.push([_INTL("Cancel"), "cancel", nil])
    entries
  end

  def filter_by_level(storage)
    min_l = ask_number(_INTL("Minimum level?"), 1, Settings::MAXIMUM_LEVEL, 1)
    return nil if min_l.nil?
    max_l = ask_number(_INTL("Maximum level?"), min_l, Settings::MAXIMUM_LEVEL, Settings::MAXIMUM_LEVEL)
    return nil if max_l.nil?
    matches = collect_matches(storage) { |p| p.level >= min_l && p.level <= max_l }
    pick_match(matches, _INTL("L{1}-{2}", min_l, max_l))
  end

  def filter_by_name(storage)
    needle = pbEnterText(_INTL("Name contains?"), 1, 20)
    return nil if needle.nil? || needle.empty?
    needle = needle.downcase
    matches = collect_matches(storage) { |p|
      nickname = (p.name || "").downcase
      species_names = pkmn_species_names(p).map(&:downcase)
      nickname.include?(needle) || species_names.any? { |n| n.include?(needle) }
    }
    pick_match(matches, _INTL("name~'{1}'", needle))
  end

  def filter_by_dex(storage)
    max_dex = highest_dex_number
    min_d = ask_number(_INTL("Minimum Dex #?"), 1, max_dex, 1)
    return nil if min_d.nil?
    max_d = ask_number(_INTL("Maximum Dex #?"), min_d, max_dex, max_dex)
    return nil if max_d.nil?
    matches = collect_matches(storage) { |p|
      n = p.species_data.id_number
      n >= min_d && n <= max_d
    }
    pick_match(matches, _INTL("Dex {1}-{2}", min_d, max_d))
  end

  # ---- helpers ----

  def ask_number(prompt, min, max, default)
    params = ChooseNumberParams.new
    params.setRange(min, max)
    params.setDefaultValue(default)
    params.setCancelValue(-1)
    n = pbMessageChooseNumber(prompt, params)
    return nil if n < min
    n
  end

  def pkmn_types(pkmn)
    return pkmn.types if pkmn.respond_to?(:types)
    [pkmn.type1, pkmn.type2].compact.uniq
  end

  # Returns species name(s) for the mon. Fusions return [head, body] names so
  # searching by either component matches.
  def pkmn_species_names(pkmn)
    names = []
    sd = pkmn.species_data rescue nil
    if sd
      if sd.respond_to?(:get_head_species_symbol) && sd.respond_to?(:get_body_species_symbol)
        head = sd.get_head_species_symbol rescue nil
        body = sd.get_body_species_symbol rescue nil
        names.push(GameData::Species.get(head).name) if head
        names.push(GameData::Species.get(body).name) if body
      end
      names.push(sd.name) if sd.respond_to?(:name)
    end
    names.push(pkmn.speciesName) if pkmn.respond_to?(:speciesName)
    names.compact.uniq
  end

  # Short label like "Fire/Water" or "Electric" for the result list.
  def types_label(pkmn)
    ts = pkmn_types(pkmn)
    return "" if ts.nil? || ts.empty?
    ts.map { |t| GameData::Type.get(t).name }.join("/")
  end

  def highest_dex_number
    n = 0
    GameData::Species.each { |s| n = s.id_number if s.id_number > n }
    n > 0 ? n : 1500
  end

  def collect_matches(storage)
    out = []
    storage.boxes.each_with_index do |box, b_idx|
      next if box.nil?
      box.pokemon.each_with_index do |p, s_idx|
        next if p.nil?
        out.push([b_idx, s_idx, p]) if yield(p)
      end
    end
    out
  end

  # sidmod: results are a live-filter list too - type to narrow by nickname,
  # species or fusion half, UP/DOWN to move, ENTER to jump there.
  def pick_match(matches, label = "")
    if matches.nil? || matches.empty?
      pbMessage(_INTL("No Pokémon match{1}.", label.empty? ? "" : " (#{label})"))
      return nil
    end
    truncated = matches.length > MAX_RESULTS
    shown = truncated ? matches[0, MAX_RESULTS] : matches
    if truncated
      pbMessage(_INTL("{1} matches - showing the first {2}.", matches.length, MAX_RESULTS))
    end
    entries = shown.map { |b, s, p|
      [match_row(b, s, p), match_search_text(b, s, p), [b, s], match_detail(p)]
    }
    entries.push([_INTL("Cancel"), "cancel", nil, label])
    choose_searchable(entries, _INTL("results"), true)
  end

  # One row: "B18.3 L100 h:Gyarados b:Scizor" - always spells out the fusion's
  # head and body, because a nickname alone says nothing about what the mon is.
  def match_row(box, slot, pkmn)
    _INTL("B{1}.{2} L{3} {4}", box + 1, slot + 1, pkmn.level, parts_label(pkmn))
  end

  # "h:Head b:Body" for a fusion, the species name otherwise, plus the nickname
  # in quotes when it has one.
  def parts_label(pkmn)
    head, body = fusion_part_names(pkmn)
    base = (head && body) ? _INTL("h:{1} b:{2}", head, body) : species_display_name(pkmn)
    nick = (pkmn.nicknamed? rescue false) ? pkmn.name : nil
    nick ? "#{base} \"#{nick}\"" : base
  end

  # Head/body species names of a fusion, or [nil, nil] for anything else
  # (isFusion? is already false for triple fusions, which have no two halves).
  def fusion_part_names(pkmn)
    return [nil, nil] if !(pkmn.isFusion? rescue false)
    sd = pkmn.species_data rescue nil
    return [nil, nil] if sd.nil?
    return [nil, nil] if !sd.respond_to?(:get_head_species_symbol) ||
                         !sd.respond_to?(:get_body_species_symbol)
    head = sd.get_head_species_symbol rescue nil
    body = sd.get_body_species_symbol rescue nil
    return [nil, nil] if head.nil? || body.nil?
    [(GameData::Species.get(head).name rescue nil),
     (GameData::Species.get(body).name rescue nil)]
  end

  def species_display_name(pkmn)
    n = (pkmn.species_data.name rescue nil)
    n ||= (pkmn.speciesName rescue nil)
    n || "?"
  end

  # Detail line shown next to the search box for the highlighted row.
  def match_detail(pkmn)
    tlabel = types_label(pkmn)
    tlabel.empty? ? species_display_name(pkmn) : _INTL("{1} - {2}", pkmn.name, tlabel)
  end

  def match_search_text(box, slot, pkmn)
    ([_INTL("B{1}.{2}", box + 1, slot + 1), pkmn.name] +
     pkmn_species_names(pkmn) + [types_label(pkmn)]).join(" ").downcase
  end

  #-----------------------------------------------------------------------------
  # sidmod: live-filter list picker, same UX as the debug menu's "Teach move"
  # list (pbChooseListSearchable in 020_Debug/001_Editor_Utilities.rb): type to
  # filter, UP/DOWN to move (HOME/END for the ends), ENTER to choose, ESC to
  # cancel. Kept local to PCSearch because these lists carry their own row text
  # and preserve their given order (results must stay in box order), where
  # pbChooseListSearchable re-sorts alphabetically and formats rows itself.
  #   entries - [row text, search text, value, detail text (optional)]
  #             a nil value is a Cancel row
  #   wide    - true: full-width rows + detail box top right (result lists)
  #             false: half-width rows + key hints bottom right (type lists)
  # Returns the chosen value, or nil if cancelled. Keyboard only, for the same
  # reason as pbChooseListSearchable: with text input on, the letter keys bound
  # to USE/BACK would fire while typing.
  #-----------------------------------------------------------------------------
  def choose_searchable(entries, what, wide = false)
    return nil if entries.nil? || entries.empty?
    searchwin = Window_TextEntry_Keyboard.new("", 0, 0, Graphics.width / 2, 96,
                                              _INTL("Search {1}:", what), true)
    searchwin.maxlength = 20
    searchwin.z = 99999
    searchwin.active = true
    if wide
      helpwin = Window_UnformattedTextPokemon.newWithSize("", Graphics.width / 2, 0,
                                                          Graphics.width / 2, 96)
      pbSetSmallFont(helpwin.contents)
    else
      helpwin = Window_UnformattedTextPokemon.newWithSize("", Graphics.width / 2,
                                                          Graphics.height - 192,
                                                          Graphics.width / 2, 192)
    end
    helpwin.letterbyletter = false
    helpwin.z = 99999
    cmdwin = Window_CommandPokemon.newWithSize([], 0, 96,
                                              wide ? Graphics.width : Graphics.width / 2,
                                              Graphics.height - 96)
    cmdwin.ignore_input = true   # navigated below; LEFT/RIGHT belong to the search box
    cmdwin.rowHeight = 24
    pbSetSmallFont(cmdwin.contents)
    cmdwin.z = 99999
    cmdwin.active = true
    filtered = []
    oldtext  = nil
    oldhelp  = nil
    ret = nil
    Input.text_input = true
    loop do
      if oldtext != searchwin.text   # Rebuild the filtered list
        oldtext = searchwin.text
        query = oldtext.downcase.strip
        filtered = entries.select { |e| query == "" || e[1].include?(query) }
        cmdwin.commands = filtered.map { |e| e[0] }
        cmdwin.index = 0
      end
      newhelp = search_help_text(filtered, cmdwin.index, wide)
      if newhelp != oldhelp
        oldhelp = newhelp
        helpwin.text = newhelp
      end
      Graphics.update
      Input.update
      searchwin.update
      cmdwin.update
      if filtered.length > 0   # Move the selection (the list ignores input itself)
        oldindex = cmdwin.index
        if Input.triggerex?(:DOWN) || Input.repeatex?(:DOWN)
          cmdwin.index = (cmdwin.index + 1) % filtered.length
        elsif Input.triggerex?(:UP) || Input.repeatex?(:UP)
          cmdwin.index = (cmdwin.index - 1 + filtered.length) % filtered.length
        elsif Input.triggerex?(:HOME)
          cmdwin.index = 0
        elsif Input.triggerex?(:END)
          cmdwin.index = filtered.length - 1
        end
        pbPlayCursorSE if cmdwin.index != oldindex
      end
      if Input.triggerex?(:RETURN)
        chosen = filtered[cmdwin.index]
        if chosen
          ret = chosen[2]   # nil = the Cancel row
          break
        end
      elsif Input.triggerex?(:ESCAPE)
        break
      end
    end
    Input.text_input = false
    searchwin.dispose
    cmdwin.dispose
    helpwin.dispose
    Input.update
    return ret
  end

  def search_help_text(filtered, index, wide)
    count = _INTL("{1} match(es)", filtered.length)
    if wide
      detail = filtered.empty? ? "" : (filtered[index] ? filtered[index][3].to_s : "")
      return detail.empty? ? count : "#{detail}\n#{count}"
    end
    _INTL("Type to search.\nUP/DOWN: move (HOME/END: ends)\nENTER: choose, ESC: cancel\n{1}", count)
  end
end
