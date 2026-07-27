#===============================================================================
# sidmod: Random Opponent (PC pool)
#
# Debug battle command that assembles an opposing team of 6 drawn from your
# "battle-ready" PC Pokemon (Level 100 AND holding an item), then fights you
# with the SmartTrainerAI. Two modes:
#   - CHAOS: pure random 6 (Species Clause: no repeated base species).
#   - SMART: deterministic role/type-balanced comp - fills a hazard-setter, a
#     wall, and a pivot first, then rounds out with offensive variety and fresh
#     typing (still Species-Clause legal). Seeded, so every fight differs.
#
# The classification + selection algorithm is PURE (operates on plain data), so
# it is unit-testable outside the engine. The `if defined?(DebugMenuCommands)`
# guard lets the file be required head-less without touching the debug menu.
#
# To revert: delete this file.
#===============================================================================

module SidmodRandomOpp
  module_function

  MODES = begin
    [_INTL("Chaos - OU"), _INTL("Smart - OU"), _INTL("Chaos - Ubers"), _INTL("Smart - Ubers")]
  rescue
    ["Chaos - OU", "Smart - OU", "Chaos - Ubers", "Smart - Ubers"]
  end

  # TIER FILTER. OU excludes any fusion whose head OR body is a legendary that ISN'T one of these
  # sub-600 "OU-legal" legendaries (the birds/beasts/golems + Regigigas special-case). Ubers = no filter.
  # The legendary set itself is the game's own LEGENDARIES_LIST (randomizer.rb) at runtime; the fallback
  # mirror keeps the OU filter working head-less for unit tests.
  OU_LEGAL_LEGENDS = %i[ARTICUNO ZAPDOS MOLTRES SUICUNE ENTEI RAIKOU REGICE REGIROCK REGISTEEL REGIGIGAS]
  LEGENDS_FALLBACK = %i[ARTICUNO ZAPDOS MOLTRES MEWTWO MEW ENTEI RAIKOU SUICUNE HOOH LUGIA CELEBI
                        GROUDON KYOGRE RAYQUAZA DEOXYS JIRACHI LATIAS LATIOS REGIROCK REGICE REGISTEEL
                        REGIGIGAS DIALGA PALKIA GIRATINA DARKRAI CRESSELIA ARCEUS GENESECT RESHIRAM
                        ZEKROM KYUREM MELOETTA_A MELOETTA_P NECROZMA U_NECROZMA DIANCIE]
  def legends; defined?(LEGENDARIES_LIST) ? LEGENDARIES_LIST : LEGENDS_FALLBACK; end

  # A candidate is OU-legal if none of its base species is a banned (non-allowlisted) legendary.
  def ou_legal?(c)
    lg = legends
    (c[:bases] || []).none? { |b| lg.include?(b) && !OU_LEGAL_LEGENDS.include?(b) }
  end

  # ---- move tags for role classification --------------------------------------
  SETUP   = %i[SWORDSDANCE DRAGONDANCE NASTYPLOT CALMMIND QUIVERDANCE SHELLSMASH BULKUP WORKUP
               ROCKPOLISH AGILITY AUTOTOMIZE SHIFTGEAR COIL GEOMANCY VICTORYDANCE NORETREAT
               CLANGOROUSSOUL BELLYDRUM TAILGLOW GROWTH HONECLAWS TAKEHEART]
  HAZARD  = %i[STEALTHROCK SPIKES TOXICSPIKES STICKYWEB]
  PIVOT   = %i[UTURN VOLTSWITCH FLIPTURN PARTINGSHOT TELEPORT BATONPASS]
  RECOVER = %i[RECOVER ROOST SOFTBOILED MILKDRINK SLACKOFF MORNINGSUN MOONLIGHT SYNTHESIS WISH
               REST SHOREUP STRENGTHSAP PAINSPLIT]
  PHAZE   = %i[WHIRLWIND ROAR DRAGONTAIL CIRCLETHROW HAZE CLEARSMOG]

  # SPORE CLAUSE: any mon whose MOVESET contains one of these is excluded from every mode
  # (100%-accuracy sleep is un-fun to face at random). Extend the list for a broader sleep ban.
  BANNED_MOVES = %i[SPORE]

  # candidate = {types:[sym,sym], bases:[int...], moves:[sym...], evs:{SYM=>int}, item:sym, ref:obj}
  def classify(c)
    mv = c[:moves] || []; ev = c[:evs] || {}; item = c[:item]
    off   = (ev[:ATTACK].to_i >= 200 || ev[:SPECIAL_ATTACK].to_i >= 200)
    bulky = (ev[:HP].to_i >= 180 && (ev[:DEFENSE].to_i >= 100 || ev[:SPECIAL_DEFENSE].to_i >= 100)) ||
            ev[:DEFENSE].to_i >= 208 || ev[:SPECIAL_DEFENSE].to_i >= 208
    r = []
    r << :hazard   if (mv & HAZARD).any?
    r << :pivot    if (mv & PIVOT).any?
    r << :sweeper  if (mv & SETUP).any? && off
    r << :scarfer  if item == :CHOICESCARF
    r << :breaker  if [:CHOICEBAND, :CHOICESPECS].include?(item) || (item == :LIFEORB && off && (mv & SETUP).empty?)
    r << :wall     if bulky && ((mv & RECOVER).any? || (mv & PHAZE).any? || (mv & HAZARD).any?)
    r << :attacker if off && (r & %i[sweeper scarfer breaker]).empty?
    r << :misc     if r.empty?
    r
  end

  # ---- SMART: greedy, seeded, role + type balanced ----------------------------
  def select_smart(cands, rng, n = 6)
    cands  = cands.map { |c| c.merge(roles: classify(c)) }
    chosen = []; used_bases = []; type_count = Hash.new(0)
    addable = ->(c) { (c[:bases] & used_bases).empty? && !chosen.include?(c) }
    add     = ->(c) { chosen << c; used_bases.concat(c[:bases]); (c[:types] || []).each { |t| type_count[t] += 1 } }
    freshness = ->(c) { (c[:types] || []).sum { |t| type_count[t] } }   # lower = fresher typing

    # 1) fill key defensive/utility niches first, each with the freshest typing available
    %i[hazard wall pivot].each do |role|
      break if chosen.length >= n
      pick = cands.select { |c| addable.(c) && c[:roles].include?(role) }.shuffle(random: rng).min_by(&freshness)
      add.(pick) if pick
    end
    # 2) round out with offensive variety + fresh typing
    until chosen.length >= n
      pool2 = cands.select(&addable)
      break if pool2.empty?
      pick = pool2.shuffle(random: rng).min_by { |c|
        off_bonus = (c[:roles] & %i[sweeper breaker scarfer attacker]).any? ? -1 : 0
        freshness.(c) + off_bonus
      }
      add.(pick)
    end
    chosen
  end

  # ---- CHAOS: pure random, Species-Clause legal -------------------------------
  def select_chaos(cands, rng, n = 6)
    chosen = []; used = []
    cands.shuffle(random: rng).each do |c|
      next if (c[:bases] & used).any?
      chosen << c; used.concat(c[:bases])
      break if chosen.length >= n
    end
    chosen
  end

  # ---- game-facing extraction (live Pokemon -> plain candidate) ---------------
  def item_sym(pk); it = (pk.item rescue nil); it && (it.respond_to?(:id) ? it.id : it); end
  def move_syms(pk); (pk.moves rescue []).map { |m| m.respond_to?(:id) ? m.id : m }.compact; end
  def ev_hash(pk); e = (pk.ev rescue {}); e.is_a?(Hash) ? e : {}; end
  def type_syms(pk); (pk.types rescue []).map { |t| t.respond_to?(:id) ? t.id : t }.uniq; end
  def base_sym(x); x.is_a?(Integer) ? (GameData::Species.get(x).id rescue x) : x; end
  # Base component species (SYMBOLS) for Species-Clause + tier filtering. Handles all 3 cases:
  # TRIPLE fusions (isFusion? is FALSE for these!) decode via the game's component table so their
  # third component can't smuggle a banned legendary past the OU filter; normal fusions use head+body.
  def bases(pk)
    if (pk.isTripleFusion? rescue false)
      comps = (get_triple_fusion_components(pk.species) rescue nil)
      comps ? comps.map { |dex| base_sym(dex) } : [(pk.species rescue nil)].compact
    elsif (pk.isFusion? rescue false)
      [base_sym(pk.head_id), base_sym(pk.body_id)]
    else
      [(pk.species rescue pk.dexNum)]
    end
  end
  def candidate(pk)
    { types: type_syms(pk), bases: bases(pk), moves: move_syms(pk),
      evs: ev_hash(pk), item: item_sym(pk), ref: pk }
  end

  # Battle-ready pool: every PC mon at Lv100 holding an item.
  def battle_pool
    ready = []
    $PokemonStorage.maxBoxes.times do |b|
      $PokemonStorage.maxPokemon(b).times do |i|
        pk = $PokemonStorage[b, i]
        next if pk.nil? || (pk.egg? rescue false)
        next unless pk.level == 100 && (pk.hasItem? rescue item_sym(pk))
        ready << pk
      end
    end
    ready
  end

  def build_team(sel, tier, seed)
    rng   = Random.new(seed)
    cands = battle_pool.map { |pk| candidate(pk) }
    cands = cands.reject { |c| ((c[:moves] || []) & BANNED_MOVES).any? }   # Spore clause (all modes)
    cands = cands.select { |c| ou_legal?(c) } if tier == :ou
    return nil if cands.length < 6
    chosen = (sel == :smart) ? select_smart(cands, rng) : select_chaos(cands, rng)
    chosen.length >= 6 ? chosen.map { |c| c[:ref] } : nil
  end

  def trainer_type
    %i[COOLTRAINER_M ACETRAINER_M CHAMPION ELITEFOUR RIVAL2 YOUNGSTER BUGCATCHER].each do |t|
      return t if (GameData::TrainerType.exists?(t) rescue false)
    end
    (GameData::TrainerType.keys.first rescue :YOUNGSTER)
  end

  # ---- item safety net --------------------------------------------------------
  # How the engine really handles a permanently-consumed held item (berry, White
  # Herb, Focus Sash, Air Balloon...): Battler#pbRemoveItem
  # (011_Battle/001_Battler/006_Battler_AbilityAndItem.rb ~line 141) deletes one of
  # that item from THE PLAYER'S BAG so pbEndOfBattle can put it back on the mon -
  # and if the bag has none, it calls setInitialItem(nil) and the held item is gone
  # for good. That code runs for BOTH sides off the same $PokemonBag, so a random
  # battle (6 opposing mons, all holding items, plus your own team) drains your bag
  # stock and then starts permanently stripping items once the stock hits 0 -
  # exactly what you don't want from a practice battle. So: snapshot everything
  # involved and put it back afterwards. Restores only; never takes anything away.

  # [[pokemon, item_id], ...] keyed by OBJECT, so it cannot misalign if the party
  # order changes during the battle.
  def item_snapshot(party)
    (party || []).compact.map { |pk| [pk, (pk.item_id rescue nil)] }
  end

  def restore_items(snapshot)
    snapshot.each do |pk, it|
      next if it.nil?   # held nothing before - don't wipe a Pickup gain
      next if (pk.item_id rescue it) == it
      (pk.item = it) rescue nil
    end
  end

  def bag_snapshot(item_ids)
    snap = {}
    item_ids.compact.uniq.each { |it| snap[it] = ($PokemonBag.pbQuantity(it) rescue 0) }
    snap
  end

  def restore_bag(snap)
    snap.each do |it, qty|
      now = ($PokemonBag.pbQuantity(it) rescue qty)
      next if now >= qty   # never remove what the player picked up in the battle
      ($PokemonBag.pbStoreItem(it, qty - now) rescue nil)
    end
  end

  def start_battle(sel, tier)
    refs = build_team(sel, tier, rand(1_000_000))
    unless refs
      pbMessage(_INTL("Need 6+ battle-ready {1}PC Pokemon (Lv100 + held item). Upgrade more mons first.",
                      tier == :ou ? "OU-legal " : ""))
      return
    end
    trainer = NPCTrainer.new(_INTL("Random Challenger"), trainer_type)
    refs.each do |pk|
      c = Marshal.load(Marshal.dump(pk))   # deep copy so the stored mon is never mutated
      c.heal
      trainer.party.push(c)
    end
    names = refs.map { |pk| pk.name || pk.speciesName }.join(", ")
    pbMessage(_INTL("A {1} {2} challenger appears with:\n{3}!",
                    sel == :smart ? "balanced" : "random", tier == :ou ? "OU" : "Ubers", names))
    # sidmod: nothing this battle consumes should survive it - see the item safety
    # net above. Covers both sides: the player's held items, and the bag stock that
    # BOTH teams' consumptions get charged to.
    party_snap = item_snapshot($Trainer.party)
    bag_snap   = bag_snapshot(party_snap.map { |_pk, it| it } +
                             trainer.party.map { |pk| (pk.item_id rescue nil) })
    $Trainer.heal_party
    pbTrainerBattleCore(trainer)
    restore_items(party_snap)
    restore_bag(bag_snap)
    $Trainer.heal_party
  end

  def run
    idx = pbShowCommands(nil, MODES, -1)
    return if idx < 0
    sel  = (idx == 1 || idx == 3) ? :smart : :chaos
    tier = (idx <= 1) ? :ou : :ubers
    start_battle(sel, tier)
  end
end

# Entry point is the main pause menu ("Random Battle") - see 016_UI/001_UI_PauseMenu.rb.
# (Previously also registered under the Debug > Battle menu; moved to the pause menu.)
