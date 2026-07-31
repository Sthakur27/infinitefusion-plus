#===============================================================================
# sidmod: Random Opponent (PC pool)
#
# Debug battle command that assembles an opposing team of 6 drawn from your
# "battle-ready" PC Pokemon (Level 100 AND holding an item), then fights you
# with the SmartTrainerAI. Three selection modes:
#   - CHAOS: pure random 6 (Species Clause: no repeated base species).
#   - SMART: deterministic role/type-balanced comp - fills a hazard-setter, a
#     wall, and a pivot first, then rounds out with offensive variety and fresh
#     typing (still Species-Clause legal). Seeded, so every fight differs.
#   - SMART v2: builds a team around ONE named PLAN (rain/sand/trick room/stall/
#     hazard stack/...) picked from a second menu, or a random plan. Ported from
#     the offline ladder's archetype generator (tools/sidmod_editor/sim/
#     narchetype.rb) - see the SMART v2 section below for what changed and why.
#     Also picks the lead, which SMART does not.
# Plus one FIXED-ROSTER mode:
#   - OU APEX: fight the best teams the offline king-of-the-hill ladder ever
#     produced, picked from a menu by rank/Elo. These are shipped as frozen
#     Pokemon in Data/sidmod/ou_apex.rxdata and do NOT come from the PC pool -
#     see the OU APEX section below for why box/slot references can't be used.
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
    [_INTL("Chaos - OU"), _INTL("Smart - OU"), _INTL("Smart v2 - OU"),
     _INTL("Chaos - Ubers"), _INTL("Smart - Ubers"), _INTL("Smart v2 - Ubers"),
     _INTL("OU Apex")]
  rescue
    ["Chaos - OU", "Smart - OU", "Smart v2 - OU",
     "Chaos - Ubers", "Smart - Ubers", "Smart v2 - Ubers", "OU Apex"]
  end
  MODE_SEL = %i[chaos smart smart2 chaos smart smart2 apex]

  # sidmod: RESEARCH BAN SETS - an optional filter layered on top of the tier/mode,
  # mirroring the offline ladder's ban conditions (tools/sidmod_editor/sim/nladder.rb)
  # that showed banning the dominant "multiplier" fusions (Marowak/Azumarill/Pikachu)
  # is what actually diversifies the metagame. Applied to the candidate pool in
  # build_team_named. Spore is ALWAYS excluded (BANNED_MOVES); these add the standard
  # competitive clauses + the two dominant-group species bans. Wonder Guard is
  # deliberately NOT clause-banned in-game (per Sid's earlier call to leave it playable).
  CLAUSE_ABILITIES = %i[MOODY SHADOWTAG ARENATRAP]
  CLAUSE_MOVES     = %i[BATONPASS SWAGGER FISSURE SHEERCOLD HORNDRILL GUILLOTINE]
  GROUP_A_SPECIES  = %i[MAROWAK AZUMARILL PIKACHU]
  GROUP_B_SPECIES  = %i[DRAGONITE SLAKING REGIGIGAS]
  BAN_SETS = {
    none:     { species: [],                                clauses: false },
    clauses:  { species: [],                                clauses: true  },
    ban_a:    { species: GROUP_A_SPECIES,                   clauses: true  },
    ban_b:    { species: GROUP_B_SPECIES,                   clauses: true  },
    ban_both: { species: GROUP_A_SPECIES + GROUP_B_SPECIES, clauses: true  },
  }
  BAN_SET_LABELS = begin
    [_INTL("No clauses"), _INTL("Standard clauses"),
     _INTL("Ban multipliers (Marowak/Azu/Pika)"),
     _INTL("Ban setup+stat (Dnite/Slaking/Regi)"),
     _INTL("Ban both groups")]
  rescue
    ["No clauses", "Standard clauses", "Ban multipliers (Marowak/Azu/Pika)",
     "Ban setup+stat (Dnite/Slaking/Regi)", "Ban both groups"]
  end
  BAN_SET_SEL = %i[none clauses ban_a ban_b ban_both]

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

  # =============================================================================
  # SMART v2 - archetype ("plan") team builders
  #
  # Ported from tools/sidmod_editor/sim/narchetype.rb (Gen#archetype), the generator
  # the offline king-of-the-hill ladder uses to explore plans a greedy build never
  # finds. Same plans, same fill order. TWO deliberate differences, both forced by
  # what a live PC pool has that the sim does not:
  #   1. NO RATINGS. Offline `best()` sorts candidates by their measured rating coef
  #      (from mass native-AI sims, ratings.csv). Nothing in-game has that, so `best`
  #      here sorts by raw Lv100 stat total - a much weaker signal, hence the jitter
  #      is kept and the tail slots fall back to TYPE FRESHNESS (the SMART heuristic)
  #      rather than to a rating shortlist.
  #   2. Offline predicates match ability/move DISPLAY NAMES ('Sand Stream'); in the
  #      engine these are SYMBOLS (:SANDSTREAM). All the tag lists below are the
  #      symbol equivalents.
  # The existing SETUP / HAZARD / PIVOT / RECOVER / PHAZE lists above are reused as-is.
  # =============================================================================

  ARCHETYPES = %i[rain sun sand hyperoffense balance hazardstack trickroom priority
                  scarf bulkysetup stall]
  ARCH_LABELS = { rain: "Rain", sun: "Sun", sand: "Sand", hyperoffense: "Hyper Offense",
                  balance: "Balance", hazardstack: "Hazard Stack", trickroom: "Trick Room",
                  priority: "Priority", scarf: "Choice Scarf", bulkysetup: "Bulky Setup",
                  stall: "Stall" }
  # Shown under the highlighted entry in the picker, so the plans are self-explanatory
  # instead of being jargon you have to already know.
  ARCH_HELP = {
    rain:         "A Drizzle setter leading, then Swift Swim and Dry Skin mons that only pay off in rain.",
    sun:          "A Drought setter leading, feeding Chlorophyll sweepers and Solar Power attackers.",
    sand:         "A Sand Stream setter leading, with Sand Rush and Sand Force mons behind it.",
    hyperoffense: "No walls at all - setup sweepers and the hardest hitters available.",
    balance:      "Two bulky mons with recovery or phazing, a pivot, then offensive threats.",
    hazardstack:  "Three hazard setters plus a phazer, to tax every switch the other side makes.",
    trickroom:    "Trick Room first, then slow heavy hitters that suddenly move first under it.",
    priority:     "Stacked priority moves - picks off anything weakened, ignores Speed.",
    scarf:        "Three Choice Scarf users for permanent speed control.",
    bulkysetup:   "Setup sweepers bulky enough to set up more than once.",
    stall:        "Walls with recovery, hazards and phazing. Wins on attrition, not damage."
  }

  WEATHER_ABILITY = { DRIZZLE: :rain, PRIMORDIALSEA: :rain, DROUGHT: :sun,
                      DESOLATELAND: :sun, SANDSTREAM: :sand, SNOWWARNING: :hail }
  # abilities that only pay off under a specific weather
  ABUSER = { rain: %i[SWIFTSWIM RAINDISH DRYSKIN HYDRATION],
             sun:  %i[CHLOROPHYLL SOLARPOWER LEAFGUARD FLOWERGIFT HARVEST],
             sand: %i[SANDRUSH SANDFORCE SANDVEIL],
             hail: %i[SLUSHRUSH SNOWCLOAK ICEBODY] }
  PRIORITY = %i[EXTREMESPEED AQUAJET BULLETPUNCH ICESHARD SHADOWSNEAK SUCKERPUNCH
                MACHPUNCH VACUUMWAVE ACCELEROCK JETPUNCH FIRSTIMPRESSION QUICKATTACK FAKEOUT]
  # things that buy a setup sweeper a guaranteed free turn on the lead
  FREE_TURN_ABILITY = %i[DISGUISE MULTISCALE SPEEDBOOST CONTRARY MAGICBOUNCE]
  FREE_TURN_ITEM    = %i[FOCUSSASH FOCUSBAND]
  # a hazard lead that also threatens is better than a passive one
  SUICIDE_OK = %i[TAUNT EXPLOSION MEMENTO DESTINYBOND]

  # ---- predicates over a candidate hash ---------------------------------------
  # stats are the mon's real Lv100 stats [HP, Atk, Def, SpA, SpD, Spe], so the
  # offline thresholds (the pool is Lv100-only) carry over unchanged.
  def mvs(c);  c[:moves] || []; end
  def abil(c); c[:ability]; end
  def st(c, i); (c[:stats] || [])[i].to_i; end
  def bulk(c); st(c, 0) + st(c, 2) + st(c, 4); end
  def bulky?(c); st(c, 0) >= 330 && (st(c, 2) >= 250 || st(c, 4) >= 250); end
  def slow?(c);  s = st(c, 5); s > 0 && s <= 180; end
  def setter?(c, w); WEATHER_ABILITY[abil(c)] == w; end
  def abuser?(c, w); ABUSER[w].to_a.include?(abil(c)); end
  def hazard?(c);    (mvs(c) & HAZARD).any?; end
  def setup?(c);     (mvs(c) & SETUP).any?; end
  def pivot?(c);     (mvs(c) & PIVOT).any?; end
  def recovery?(c);  (mvs(c) & RECOVER).any?; end
  def phaze?(c);     (mvs(c) & PHAZE).any?; end
  def priority?(c);  (mvs(c) & PRIORITY).any?; end
  def trickroom?(c); mvs(c).include?(:TRICKROOM); end
  def scarf?(c);     c[:item] == :CHOICESCARF; end
  def offensive?(c); ((c[:roles] || classify(c)) & %i[sweeper breaker scarfer attacker]).any?; end

  # Stand-in for the offline rating: total Lv100 stats, scaled so the jitter values
  # inherited from narchetype.rb (0.15-0.4) still shuffle near-equal candidates.
  def power(c); ((c[:stats] || []).sum) / 2000.0; end
  def best(cands, rng, jitter = 0.15, &pred)
    cands.select { |c| pred.call(c) }
         .sort_by { |c| -(power(c) + (rng.rand - 0.5) * jitter) }
  end

  # ---- Species-Clause-safe fills ----------------------------------------------
  # Candidates are compared by IDENTITY (equal?), not ==: two different PC mons can
  # produce equal candidate hashes, and == would silently treat them as one slot.
  def team_bases(team); team.flat_map { |c| c[:bases] || [] }; end
  # Add UP TO n candidates that pass Species Clause. (narchetype.rb note: handing
  # `fill` exactly n candidates is wrong - one clause conflict then yields n-1 and a
  # 3-hazard build lands with 2.)
  def fill_upto(team, cands, n)
    used = team_bases(team)
    added = 0
    cands.each do |c|
      break if added >= n || team.length >= 6
      next if team.any? { |x| x.equal?(c) }
      bs = c[:bases] || []
      next if bs.any? { |b| used.include?(b) }
      team << c; used.concat(bs); added += 1
    end
    team
  end
  def fill(team, cands); fill_upto(team, cands, 6); end

  # Tail slots: no ratings to fall back on, so reuse SMART's signal - freshest typing,
  # offence preferred. Recomputes the type census each pass so the 5th pick reacts to
  # the 4th.
  def fill_fresh(team, cands, rng)
    until team.length >= 6
      tc = Hash.new(0)
      team.each { |c| (c[:types] || []).each { |t| tc[t] += 1 } }
      used = team_bases(team)
      pool = cands.reject { |c|
        team.any? { |x| x.equal?(c) } || (c[:bases] || []).any? { |b| used.include?(b) } }
      break if pool.empty?
      team << pool.shuffle(random: rng).min_by { |c|
        (c[:types] || []).sum { |t| tc[t] } + (offensive?(c) ? -1 : 0) }
    end
    team
  end

  # ---- the plans ---------------------------------------------------------------
  # Returns nil when the pool cannot support the plan (e.g. no Drizzle mon at Lv100
  # holding an item). Offline the ladder just skips those; here the caller either
  # tries another archetype (Random) or tells the player which one is missing.
  def select_archetype(cands, name, rng)
    cands = cands.map { |c| c.merge(roles: classify(c)) }
    pool  = cands   # what the tail fill may draw from; weather plans narrow it
    team =
      case name
      when :rain, :sun, :sand
        w = name
        set = best(cands, rng) { |c| setter?(c, w) }.first
        return nil if !set
        # A SECOND weather ability on the team overwrites the plan's own weather on
        # entry, so no other setter may be drafted - including by the tail fill.
        pool = cands.reject { |c| WEATHER_ABILITY.key?(abil(c)) && !setter?(c, w) }
        t = [set]
        fill(t, best(pool, rng) { |c| abuser?(c, w) })              # the payoff mons
        fill(t, best(pool, rng) { |c| hazard?(c) || pivot?(c) })    # support
        t
      when :hyperoffense
        t = fill([], best(cands, rng, 0.4) { |c| setup?(c) || offensive?(c) })
        t
      when :balance
        t = fill_upto([], best(cands, rng) { |c| bulky?(c) && (recovery?(c) || phaze?(c)) }, 2)
        fill_upto(t, best(cands, rng) { |c| pivot?(c) }, 1)
        fill(t, best(cands, rng) { |c| setup?(c) })
        t
      when :hazardstack
        t = fill_upto([], best(cands, rng) { |c| hazard?(c) }, 3)
        fill_upto(t, best(cands, rng) { |c| phaze?(c) }, 1)
        fill_upto(t, best(cands, rng) { |c| priority?(c) || scarf?(c) }, 1)
        t
      when :trickroom
        tr = best(cands, rng) { |c| trickroom?(c) }.first
        return nil if !tr
        t = [tr]
        fill(t, best(cands, rng) { |c| slow?(c) && offensive?(c) })
        fill(t, best(cands, rng) { |c| slow?(c) })
        t
      when :priority
        fill([], best(cands, rng, 0.3) { |c| priority?(c) })
      when :scarf
        t = fill_upto([], best(cands, rng, 0.3) { |c| scarf?(c) }, 3)
        fill(t, best(cands, rng) { |c| setup?(c) })
        t
      when :stall
        t = fill_upto([], best(cands, rng, 0.3) { |c| bulky?(c) && recovery?(c) }, 3)
        fill_upto(t, best(cands, rng) { |c| hazard?(c) }, 1)
        fill_upto(t, best(cands, rng) { |c| phaze?(c) }, 1)
        fill(t, best(cands, rng) { |c| bulky?(c) })
        t
      when :bulkysetup
        t = fill_upto([], best(cands, rng, 0.3) { |c| setup?(c) && (bulky?(c) || recovery?(c)) }, 3)
        fill_upto(t, best(cands, rng) { |c| hazard?(c) }, 1)
        t
      else
        return nil
      end
    fill_fresh(team, pool, rng)   # top up whatever the plan left short
    return nil if team.length != 6
    b = team_bases(team)
    return nil if b.length != b.uniq.length
    team
  end

  # A plan needs a MINIMUM of its own pieces to be worth calling by that name; below
  # that the pool just doesn't have the parts and Random should move on to another
  # plan instead of shipping a generic team labelled "Sand".
  def plan_intact?(team, name)
    case name
    when :rain, :sun, :sand then team.count { |c| abuser?(c, name) } >= 1
    when :trickroom         then team.count { |c| slow?(c) } >= 3
    when :hazardstack       then team.count { |c| hazard?(c) } >= 2
    when :stall             then team.count { |c| bulky?(c) && recovery?(c) } >= 2
    when :scarf             then team.count { |c| scarf?(c) } >= 2
    when :priority          then team.count { |c| priority?(c) } >= 3
    when :bulkysetup        then team.count { |c| setup?(c) && (bulky?(c) || recovery?(c)) } >= 2
    else true
    end
  end

  # ---- lead selection (SMART v2 only) ------------------------------------------
  # Ported from sim/nlead.rb. The engine sends party[0] out first, and SMART never
  # chose a lead at all - it just battled in fill order, which for a weather or Trick
  # Room team throws away the whole plan on turn 1.
  # `arch` matters: a weather setter that nothing on the team abuses is still the
  # right lead ON A WEATHER PLAN, but on a Trick Room or stall team it is just an
  # incidental ability, and leading it throws the actual plan away. (Observed before
  # this guard: Trick Room and stall teams both led a Sand Stream mon.)
  def lead_order(team, arch = nil)
    pick = nil
    weather_plan = %i[rain sun sand].include?(arch)
    # 1) Trick Room has to be up before the slow mons can cash in on it.
    if arch == :trickroom
      pick = team.select { |c| trickroom?(c) }.max_by { |c| bulk(c) }
    end
    # 2) Weather setter. The ability resolves on entry and the SLOWEST setter's
    #    weather is the one that sticks, so leading it wins the weather war.
    if !pick
      setters = team.select { |c| WEATHER_ABILITY.key?(abil(c)) }
      setters.each do |c|
        w = WEATHER_ABILITY[abil(c)]
        next unless team.any? { |o| !o.equal?(c) && abuser?(o, w) }
        pick = c
        break
      end
      # only-weather-source fallback: on a weather plan only, never as a hijack
      pick ||= setters.max_by { |c| bulk(c) } if weather_plan && setters.any?
    end
    # 2b) Trick Room on a team that wasn't built around it but can still use it.
    if !pick && team.count { |c| slow?(c) } >= 3
      pick = team.select { |c| trickroom?(c) }.max_by { |c| bulk(c) }
    end
    # 3) Hazards on turn 1 tax every switch after it; prefer a setter that also
    #    threatens (Taunt/Explosion/...) or is fast/bulky enough to get them down.
    if !pick
      haz = team.select { |c| hazard?(c) }
      pick = haz.max_by { |c| [(mvs(c) & SUICIDE_OK).any? ? 1 : 0, st(c, 5) + bulk(c) / 3] } if haz.any?
    end
    # 4) A setup sweeper with a guaranteed free turn.
    if !pick
      free = team.select { |c|
        setup?(c) && (FREE_TURN_ABILITY.include?(abil(c)) || FREE_TURN_ITEM.include?(c[:item])) }
      pick = free.max_by { |c| st(c, 5) } if free.any?
    end
    # 5) A pivot scouts, then hands the matchup off.
    if !pick
      piv = team.select { |c| pivot?(c) }
      pick = piv.max_by { |c| st(c, 5) } if piv.any?
    end
    pick ||= team.max_by { |c| st(c, 5) }
    [pick] + team.reject { |c| c.equal?(pick) }
  end

  # `arch` is an ARCHETYPES symbol, or :random / nil to try every plan in a shuffled
  # order and take the first one the pool actually supports.
  # -> [team, archetype_used] | nil
  # `avoid` is the plan the OTHER side already got. A random roll tries every other
  # plan first and only falls back to a mirror if nothing else the pool supports is
  # left - "surprise me" should mean a different fight, not rain vs rain.
  def select_smart2(cands, arch, rng, avoid = nil)
    names =
      if arch.nil? || arch == :random
        rest = ARCHETYPES.reject { |a| a == avoid }.shuffle(random: rng)
        avoid ? rest + [avoid] : rest
      else
        [arch]
      end
    fallback = nil
    names.each do |n|
      t = select_archetype(cands, n, rng)
      next if !t
      return [lead_order(t, n), n] if plan_intact?(t, n)
      fallback ||= [lead_order(t, n), n]   # legal, just thin on plan pieces
    end
    fallback
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
  # sidmod: :ability and :stats are used only by SMART v2 (weather/Trick Room/bulk
  # predicates). Purely additive - CHAOS, SMART and the offline sim harness that
  # reuses candidate() (tools/sidmod_editor/sim/nbattle.rb) ignore them.
  def ability_sym(pk); (pk.ability_id rescue nil) || (pk.ability&.id rescue nil); end
  # Real Lv100 stats [HP, Atk, Def, SpA, SpD, Spe] - the pool is Lv100-only, so these
  # are directly comparable against the offline thresholds.
  def stat_array(pk)
    [pk.totalhp, pk.attack, pk.defense, pk.spatk, pk.spdef, pk.speed].map(&:to_i)
  rescue
    []
  end
  def candidate(pk)
    { types: type_syms(pk), bases: bases(pk), moves: move_syms(pk),
      evs: ev_hash(pk), item: item_sym(pk), ability: ability_sym(pk),
      stats: stat_array(pk), ref: pk }
  end

  # Battle-ready pool: every Lv100 mon holding an item, in the PC *or the party*.
  # sidmod: the ACTIVE PARTY used to be excluded, which made the pool quietly
  # unrepresentative - your party is usually your six best-built mons, and they were
  # the only ones that could never be drawn. They're eligible like any other mon now,
  # so a generated team can field (a copy of) something you're currently using.
  # @lending guards the one case where $Trainer.party is NOT yours: during a lent-team
  # battle the party holds borrowed copies, which must never re-enter the pool.
  def battle_pool
    ready = []
    if !@lending
      ($Trainer.party rescue []).each do |pk|
        next if pk.nil? || (pk.egg? rescue false)
        next unless pk.level == 100 && (pk.hasItem? rescue item_sym(pk))
        ready << pk
      end
    end
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

  # -> [[pokemon x6], archetype_used_or_nil] | nil
  # sidmod: apply a research ban set (standard clauses + dominant-group species bans)
  # to the candidate pool. :none is a no-op (Spore/OU filters still apply upstream).
  def apply_ban_set(cands, bans)
    set = BAN_SETS[bans] || BAN_SETS[:none]
    if set[:clauses]
      cands = cands.reject do |c|
        CLAUSE_ABILITIES.include?(c[:ability]) || ((c[:moves] || []) & CLAUSE_MOVES).any?
      end
    end
    species = set[:species]
    cands = cands.reject { |c| ((c[:bases] || []) & species).any? } unless species.empty?
    cands
  end

  def build_team_named(sel, tier, seed, arch = nil, avoid = nil, bans = :none)
    rng   = Random.new(seed)
    cands = battle_pool.map { |pk| candidate(pk) }
    cands = cands.reject { |c| ((c[:moves] || []) & BANNED_MOVES).any? }   # Spore clause (all modes)
    cands = cands.select { |c| ou_legal?(c) } if tier == :ou
    cands = apply_ban_set(cands, bans)                                     # sidmod research bans
    return nil if cands.length < 6
    chosen = nil
    used   = nil
    case sel
    when :smart2
      r = select_smart2(cands, arch, rng, avoid)
      chosen, used = r if r
    when :smart then chosen = select_smart(cands, rng)
    else             chosen = select_chaos(cands, rng)
    end
    return nil if !chosen || chosen.length < 6
    [chosen.map { |c| c[:ref] }, used]
  end

  # Kept for the offline sim harness, which calls build_team(:smart|:chaos, tier, seed).
  def build_team(sel, tier, seed, arch = nil)
    r = build_team_named(sel, tier, seed, arch)
    r && r[0]
  end

  def trainer_type
    %i[COOLTRAINER_M ACETRAINER_M CHAMPION ELITEFOUR RIVAL2 YOUNGSTER BUGCATCHER].each do |t|
      return t if (GameData::TrainerType.exists?(t) rescue false)
    end
    (GameData::TrainerType.keys.first rescue :YOUNGSTER)
  end

  # =============================================================================
  # SIDES - who plays which team (stage 1 of the menu)
  #
  #   [who_plays_your_side, is_the_AI_driving_it]
  #   :real = your actual party        :gen = a generated team, lent to you
  # =============================================================================
  SIDES = [[:real, false], [:gen, false], [:real, true], [:gen, true]]
  SIDE_LABELS = ["You vs AI", "Mirror - you get a team too",
                 "Watch - AI plays your team", "Watch - AI vs AI"]

  # ---- borrowing a team for the player's side ---------------------------------
  # pbTrainerBattleCore reads `playerParty = $Trainer.party` directly, so the only
  # way to lend the player a team is to swap the live party for the battle.
  # THIS IS THE ONE PLACE THIS FILE TOUCHES THE PLAYER'S OWN PARTY, so:
  #   - the real party is written to disk FIRST (survives a hard crash / kill, which
  #     `ensure` does not), and
  #   - the restore is in an `ensure`, so any raise inside the battle still puts the
  #     real party back before this returns.
  # The lent mons are deep copies, so nothing the battle does can reach a PC mon.
  PARTY_BACKUP = "sidmod_manual_backups/party_before_random_battle.rxdata"

  def backup_party(party)
    root = File.join(ENV['APPDATA'].to_s, "infinitefusion")
    path = File.join(root, PARTY_BACKUP)
    dir  = File.dirname(path)
    Dir.mkdir(dir) if !Dir.exist?(dir)
    File.binwrite(path, Marshal.dump(party))
    path
  rescue
    nil   # a failed backup must not block the battle; the ensure below still covers it
  end

  # Runs the block with `mons` as the player's party (or untouched if mons is nil).
  def with_player_team(mons)
    return yield if mons.nil?
    saved = $Trainer.party
    backup_party(saved)
    begin
      @lending = true   # keeps the borrowed party out of battle_pool
      $Trainer.party = mons.map { |pk| c = Marshal.load(Marshal.dump(pk)); c.heal; c }
      yield
    ensure
      $Trainer.party = saved
      @lending = false
    end
  end

  # Set while a "Watch" battle is running; read by the pbPrepareBattle hook at the
  # bottom of this file, which is what actually turns on battle.controlPlayer.
  def spectating?; @spectate ? true : false; end

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

  def cant_build(sel, tier, arch, side)
    if sel == :smart2 && arch && arch != :random
      pbMessage(_INTL("Your battle-ready {1}pool can't build a {2} team for {3} - it's missing the " \
                      "pieces (a weather setter, enough walls, etc.). Try another plan.",
                      tier == :ou ? "OU-legal " : "", ARCH_LABELS[arch], side))
    else
      pbMessage(_INTL("Need 6+ battle-ready {1}Pokemon at Lv100 holding an item (party or PC). " \
                      "Upgrade more mons first.", tier == :ou ? "OU-legal " : ""))
    end
  end

  # `my_arch` is the plan for the player's lent team; `arch` is the opponent's. YOUR
  # side is built FIRST so the opponent's random roll knows which plan to avoid.
  def start_battle(sel, tier, arch = nil, who = :real, spectate = false, my_arch = nil, bans = :none)
    mine = nil
    mine_used = nil
    if who == :gen
      r2 = build_team_named(sel, tier, rand(1_000_000), my_arch, nil, bans)
      unless r2
        cant_build(sel, tier, my_arch, _INTL("your side"))
        return
      end
      mine, mine_used = r2
    end
    result = build_team_named(sel, tier, rand(1_000_000), arch, mine_used, bans)
    unless result
      cant_build(sel, tier, arch, _INTL("the opponent"))
      return
    end
    refs, arch_used = result
    if mine
      pbMessage(_INTL("You're lent a {1} team:\n{2}!",
                      mine_used ? ARCH_LABELS[mine_used] : (sel == :smart ? "balanced" : "random"),
                      mine.map { |pk| pk.name || pk.speciesName }.join(", ")))
    end
    style = if sel == :smart2 then ARCH_LABELS[arch_used] || "planned"
            elsif sel == :smart then "balanced"
            else "random"
            end
    names = refs.map { |pk| pk.name || pk.speciesName }.join(", ")
    fight(refs, _INTL("Random Challenger"),
          _INTL("A {1} {2} challenger appears with:\n{3}!",
                style, tier == :ou ? "OU" : "Ubers", names),
          mine, spectate)
  end

  # Shared battle runner for every mode. `mons` are TEMPLATES - each is deep-copied,
  # so neither a stored PC mon nor a pack entry is ever mutated by a battle.
  #   my_mons  - a team to LEND the player for this battle (nil = use the real party)
  #   spectate - let the AI drive the player's side too (a "Watch" battle)
  def fight(mons, trainer_name, announce, my_mons = nil, spectate = false)
    trainer = NPCTrainer.new(trainer_name, trainer_type)
    mons.each do |pk|
      c = Marshal.load(Marshal.dump(pk))
      c.heal
      trainer.party.push(c)
    end
    pbMessage(announce)
    with_player_team(my_mons) do
      run_core(trainer, spectate, spectate || !my_mons.nil?)
    end
  end

  # The battle itself, with the item/bag net around it.
  #   spectate - hand the player's side to the AI (sets battle.controlPlayer)
  #   inert    - suppress exp, so a battle you didn't pilot, or fought with a lent
  #              team, can't train your real party
  def run_core(trainer, spectate, inert)
    # sidmod: nothing this battle consumes should survive it - see the item safety
    # net above. Covers both sides: the player's held items, and the bag stock that
    # BOTH teams' consumptions get charged to.
    party_snap = item_snapshot($Trainer.party)
    bag_snap   = bag_snapshot(party_snap.map { |_pk, it| it } +
                             trainer.party.map { |pk| (pk.item_id rescue nil) })
    # sidmod: a practice battle must not punish you for losing. Without these, losing
    # a Random Battle runs the full defeat path: Events.onEndBattle -> pbStartOver
    # (black out + warp to a Pokemon Center, and handle_no_reviving_defeat if the
    # no-reviving option is on), plus pbLoseMoney paying the winner out of your wallet
    # (003_Battle_StartAndEnd.rb ~495, which runs BEFORE the canLose check, so canLose
    # alone doesn't stop it). Same intent as the item/bag refund above.
    #   canLose -> no pbStartOver, party healed after the loss
    #   nomoney -> moneyGain = false, so pbLoseMoney early-returns
    # pbTrainerBattleCore calls $PokemonTemp.clearBattleRules after applying them, so
    # neither rule leaks into the next real battle.
    setBattleRule("canLose")
    setBattleRule("nomoney")
    # A battle the AI played for you, or one you fought with a lent team, shouldn't
    # feed your real party exp/EVs. Piloting your own team still trains it.
    setBattleRule("noexp") if inert
    $Trainer.heal_party
    begin
      @spectate = spectate
      pbTrainerBattleCore(trainer)
    ensure
      @spectate = false   # never leave controlPlayer armed for a real battle
    end
    restore_items(party_snap)
    restore_bag(bag_snap)
    $Trainer.heal_party
  end

  # =============================================================================
  # OU APEX - fight the best teams the offline ladder ever produced
  #
  # The pack (Data/sidmod/ou_apex.rxdata, built by sim/nexport_apex.rb) holds the
  # top N teams from a king-of-the-hill ladder run, WITH THE ACTUAL POKEMON FROZEN
  # IN, not box/slot references. That matters: a ladder team is recorded as pool
  # keys into that run's save snapshot, and those keys rot - measured on ladder_ou4,
  # 6 of the 38 mons the top 15 depend on had already been replaced in the live save
  # (one slot went from a Lv100 Blisclops wall to a Lv50 Klefmime). Resolving keys
  # against the live PC would quietly field the wrong teams. So the pack is
  # self-contained: these teams do not need to exist in the player's boxes at all,
  # and reorganising the PC can never change them.
  # Slot 0 of each team is the LEAD the ladder chose for it (nlead.rb).
  # =============================================================================
  APEX_PATH = "Data/sidmod/ou_apex.rxdata"

  # Loaded once per session and cached. @apex_pack stays false until a load is
  # attempted so a missing pack isn't re-read on every menu open.
  def apex_pack
    return @apex_pack unless @apex_pack.nil?
    @apex_pack =
      begin
        File.exist?(APEX_PATH) ? Marshal.load(File.binread(APEX_PATH)) : false
      rescue
        false   # corrupt or built by an incompatible engine - treat as absent
      end
  end

  def apex_teams; (apex_pack && apex_pack["teams"]) || []; end

  def apex_label(t)
    niche = ARCH_LABELS[t["niche"].to_s.to_sym] || t["niche"].to_s
    format("#%d  %d Elo  %s", t["rank"], t["elo"].to_i, niche)
  end

  def run_apex(who = :real, spectate = false)
    teams = apex_teams
    if teams.empty?
      pbMessage(_INTL("No OU Apex pack installed. Build one from a ladder run:\n" \
                      "ruby tools/sidmod_editor/sim/nexport_apex.rb ladder_ou4 15"))
      return
    end
    i = pbShowCommands(nil, teams.map { |t| apex_label(t) }, -1)
    return if i < 0
    t = teams[i]
    # Lending an apex team: pick a DIFFERENT one, so it's never a self-mirror (which
    # with fixed rosters would just be a coin flip decided by turn order).
    mine = nil
    if who == :gen
      others = teams.reject { |x| x.equal?(t) }
      m = others.empty? ? t : others[rand(others.length)]
      mine = m["mons"]
      pbMessage(_INTL("You're lent ladder team {1} ({2} Elo, {3}):\n{4}!",
                      m["rank"], m["elo"].to_i,
                      ARCH_LABELS[m["niche"].to_s.to_sym] || m["niche"],
                      m["names"].join(", ")))
    end
    fight(t["mons"], _INTL("Apex {1}", t["rank"]),
          _INTL("Ladder team {1} ({2} Elo, {3}) accepts your challenge:\n{4}!",
                t["rank"], t["elo"].to_i,
                ARCH_LABELS[t["niche"].to_s.to_sym] || t["niche"],
                t["names"].join(", ")),
          mine, spectate)
  end

  # SMART v2's plan picker. `whose` prefixes every help line ("YOUR TEAM" /
  # "OPPONENT"), so when both sides are being chosen you can always see which one
  # you're on without spending an extra dialog box on a title.
  # Returns an ARCHETYPES symbol, :random, or nil if the player backed out.
  def pick_archetype(whose = nil)
    labels = [_INTL("Random archetype")] + ARCHETYPES.map { |a| ARCH_LABELS[a] }
    tag    = whose ? "#{whose}\n" : ""
    help   = [tag + _INTL("Roll a plan at random.")] +
             ARCHETYPES.map { |a| tag + ARCH_HELP[a].to_s }
    i = pbShowCommandsWithHelp(nil, labels, help, -1)
    return nil if i < 0
    i.zero? ? :random : ARCHETYPES[i - 1]
  end

  # Both plans for a lent-team battle. Yours first (it's the one you care about),
  # then theirs - whose default entry is "Random archetype", so the common case
  # ("give me rain, surprise me with the rest") is one extra keypress.
  # -> [my_arch, foe_arch] or nil if backed out
  def pick_archetypes(lending)
    if !lending
      a = pick_archetype(_INTL("OPPONENT'S PLAN"))
      return a && [nil, a]
    end
    mine = pick_archetype(_INTL("YOUR PLAN"))
    return nil if mine.nil?
    foe = pick_archetype(_INTL("OPPONENT'S PLAN"))
    return nil if foe.nil?
    [mine, foe]
  end

  # Two stages: WHO plays which side, then WHICH team generator. B backs out at
  # every step.
  def run
    s = pbShowCommands(nil, SIDE_LABELS, -1)
    return if s < 0
    who, spectate = SIDES[s]
    idx = pbShowCommands(nil, MODES, -1)
    return if idx < 0
    sel = MODE_SEL[idx]
    return run_apex(who, spectate) if sel == :apex   # fixed rosters - no tier step
    tier = (idx <= 2) ? :ou : :ubers
    bidx = pbShowCommands(nil, BAN_SET_LABELS, -1)   # sidmod: research ban-set step
    return if bidx < 0
    bans = BAN_SET_SEL[bidx]
    arch = nil
    my_arch = nil
    if sel == :smart2
      picked = pick_archetypes(who == :gen)
      return if picked.nil?
      my_arch, arch = picked
    end
    start_battle(sel, tier, arch, who, spectate, my_arch, bans)
  end
end

#===============================================================================
# sidmod: two engine hooks that make the "Watch" modes possible.
# Both are inert unless a Watch battle is running - nothing in normal play changes.
#===============================================================================

# 1) Turn on battle.controlPlayer for a Watch battle.
# pbTrainerBattleCore builds the battle object locally and never exposes it, but it
# hands it to pbPrepareBattle(battle) right before starting - the one place a mod
# can reach in. (Checked: pbPrepareBattle is defined exactly once, no IF override.)
unless Object.private_method_defined?(:sidmod_orig_pbPrepareBattle)
  alias sidmod_orig_pbPrepareBattle pbPrepareBattle
  def pbPrepareBattle(battle)
    sidmod_orig_pbPrepareBattle(battle)
    battle.controlPlayer = true if defined?(SidmodRandomOpp) && SidmodRandomOpp.spectating?
  end
end

# 2) Let the AI pick the player's replacement after a faint.
# Stock pbSwitchInBetween (011_Battle/003_Battle/006_Battle_Action_Switching.rb ~136)
# routes ANY player-owned battler to pbPartyScreen. In a Watch battle that stops the
# fight and demands input from the person who is supposed to be watching, once per
# faint. Gated on @controlPlayer, so this only fires when the engine is already
# driving that side - normal battles still open the party screen exactly as before.
# (Same fix the offline harness needs: nbattle.rb patch_replacement_symmetry!.)
class PokeBattle_Battle
  unless method_defined?(:sidmod_orig_pbSwitchInBetween)
    alias sidmod_orig_pbSwitchInBetween pbSwitchInBetween
    def pbSwitchInBetween(idxBattler, checkLaxOnly = false, canCancel = false)
      if @controlPlayer && pbOwnedByPlayer?(idxBattler)
        return @battleAI.pbDefaultChooseNewEnemy(idxBattler, pbParty(idxBattler))
      end
      sidmod_orig_pbSwitchInBetween(idxBattler, checkLaxOnly, canCancel)
    end
  end
end

# Entry point is the main pause menu ("Random Battle") - see 016_UI/001_UI_PauseMenu.rb.
# (Previously also registered under the Debug > Battle menu; moved to the pause menu.)
