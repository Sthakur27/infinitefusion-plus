# Agent-driven battles: replace the game AI's per-turn choice with an external
# policy (random now, Claude API next). Proves the injection hook before spending
# any tokens. Policies are procs (battle, idxBattler, state) -> [:move, idx] | [:switch, idx].
require_relative 'battle'
require_relative 'claude_client'

module SimAgent
  module_function

  CAT = { 0 => "Physical", 1 => "Special", 2 => "Status" }

  def build_prompt(st, team_plan)
    me = st["me"]; foe = st["foe"]
    l = []
    l << "WEATHER: #{st['weather']}"
    l << "SPEED: you are #{st['speed']} than the current opponent"
    l << "INCOMING: the foe's hardest hit on you ~ #{st['incoming']} (estimate)"
    l << "HAZARDS: your side: #{st['hazards_me']} | opponent side: #{st['hazards_foe']}"
    l << "YOU: #{me['name']} HP #{me['hp']}% status=#{me['status']} ability=#{me['ability']} item=#{me['item']}#{me['boosts'].to_s.empty? ? '' : " BOOSTS[#{me['boosts']}]"}"
    l << "YOUR MOVES:"
    st["moves"].each { |m| l << "  [#{m['idx']}] #{m['id']} #{m['type']}/#{CAT[m['cat']]} pow#{m['pow']} pp#{m['pp']} -> vs_foe: #{m['eff']}#{m['dmg'].to_s.empty? ? '' : " est_dmg: #{m['dmg']}"}" }
    unless st["switches"].empty?
      l << "SWITCH OPTIONS:"
      st["switches"].each { |s| l << "  [#{s['idx']}] #{s['name']} #{s['hp']}%HP" }
    end
    l << "OPPONENT: #{foe['name']} HP #{foe['hp']}% status=#{foe['status']}#{foe['seeded'] ? ' seeded' : ''} types=#{foe['types'].join('/')}#{foe['boosts'].to_s.empty? ? '' : " BOOSTS[#{foe['boosts']}]"}"
    l << "  DEF PROFILE (authoritative type chart - trust this over instinct): #{foe['defprofile']}" if foe['defprofile'] && !foe['defprofile'].empty?
    unless (st['bench'] || []).empty?
      l << "BENCH ANSWERS vs #{foe['name']} (OFF = your bench mon's best move eff | DEF = how it takes foe STAB):"
      st['bench'].each do |bm|
        star = (bm['off'].to_f >= 2 && bm['take'].to_f <= 1) ? "  <== clean answer (SE + resists)" : ""
        l << "  #{bm['name']}: OFF #{bm['off_id'] || '-'} #{fmt_x(bm['off'])} | DEF takes #{fmt_x(bm['take'])}#{star}"
      end
    end
    unless (st['pivots'] || []).empty?
      l << "ENEMY PIVOTS (their bench - who they can switch in on you):"
      st['pivots'].each do |p|
        wall = p['off'].to_f <= 0.5 ? " (walls you)" : (p['off'].to_f >= 2 ? " SE on you!" : "")
        l << "  #{p['name']}: takes #{fmt_x(p['take'])} from your best | hits you #{fmt_x(p['off'])}#{wall}"
      end
    end
    l << "OPPONENT TEAM (preview): #{st['foe_team'].join(', ')}" if st['foe_team'] && !st['foe_team'].empty?
    unless (st['flags'] || []).empty?
      l << "FLAGS (deterministic - a hint, you still decide):"
      st['flags'].each { |f| l << "  * #{f}" }
    end
    l << "PLAN: #{team_plan}" if team_plan && !team_plan.empty?
    l << 'Pick the single best action. Respond ONLY with JSON: {"reason":"<=12 words","action":"move"|"switch","idx":<int>}'
    l.join("\n")
  end

  PILOT_SYSTEM = <<~SYS.gsub("\n", " ").strip
      You are an elite competitive Pokemon battler playing Pokemon Infinite Fusion (fusions combine
      both parents' stats, movepools and abilities). Weather set by an ability is PERMANENT until
      another weather ability overwrites it. Think one step ahead, then output ONE action.

      GAME PLAN FIRST (this is what separates elite play from clicking the biggest number): your TEAM
      NOTES below describe this team's identity and its WIN CONDITION - the specific mon(s) or board
      state that actually closes the game. Every turn, play toward that plan. The highest-damage or
      most-super-effective move is OFTEN NOT the best move. Pivoting to keep momentum, setting or
      RE-SETTING your weather, laying hazards, preserving your sweeper or your only check to their
      threat, luring and chipping - any of these can be worth far more than immediate damage. Elite
      players SEQUENCE turns toward a win; they do not greedily click damage each turn. Concretely:
      (1) PRESERVE YOUR WIN CONDITION and your defensive answers - never trade your sweeper/setter/wall
      into avoidable chip, and never sit a key piece in front of a move that KOes or cripples it when
      you can pivot or switch. (2) Identify the foe's OUTS - what they can switch to, revenge-kill with,
      or set up on - and play around them; predict the switch. (3) A "worse-looking" move that advances
      the plan (pivot, re-set weather, preserve a piece, force chip) beats a big resisted or
      win-more hit. Ask each turn: "how does THIS team win THIS game, and does this move move me toward
      it?"

      READ THE STATE: each move lists 'vs_foe' effectiveness vs the CURRENT opponent. SPEED tells you
      if you move before or after it. BOOSTS[] shows stat stages already in play. HAZARDS shows entry
      hazards on each side. Use all of it.

      TYPING: NEVER pick an IMMUNE move; strongly prefer SUPER; avoid RESISTED unless setting up or
      pivoting. If Choice-locked into a move now IMMUNE/badly resisted, SWITCH instead of wasting turns.

      SPEED & REVENGE: if you are FASTER and can KO, just attack. If you are SLOWER and the foe likely
      KOes you, don't sit there taking free set-up damage - use priority, switch to a check/resist, or
      pivot. Only set up (Dragon Dance/Swords Dance/etc.) when you survive the hit or outspeed already.

      DAMAGE NUMBERS - use them, they are the core of good play. Each move shows est_dmg (a MAX-roll
      estimate vs the foe's current HP): OHKO = kills even on a low roll (click it if you also move
      first or survive); ~OHKO(roll) = kills only on a high roll (risky); NHKO = needs N hits. Prefer
      the surest KO; never click a resisted move when a clean KO is available. INCOMING = the foe's
      hardest estimated hit on YOU: if it's OHKO/~OHKO you will likely faint first - do NOT set up,
      recover, or use a slow non-KO move; instead out-speed-KO, use priority, or switch to a resist.
      If INCOMING is 3HKO+ it is safe to set up / Roost / set hazards. CAVEAT: these estimates ignore
      the foe's ABILITY (a Ground move still shows damage vs a Levitate/Flying foe, a hit still shows
      vs Focus Sash) - sanity-check against the type line and the opponent preview.

      OPPOSING SET-UP: if the FOE shows BOOSTS (+2 or more), do NOT try to out-boost it. PHAZE it
      (Whirlwind/Roar/Dragon Tail), reset it (Haze/Clear Smog/Spectral Thief which STEALS the boosts),
      revenge with priority/a faster check, or switch to a wall it can't break. Never keep attacking
      into a snowballing sweeper you can't outrace.

      YOUR OWN SET-UP: don't over-boost - after about +2, ATTACK; a sweeper that keeps dancing instead
      of KOing wins nothing. Keep boosting only if clearly safe AND lethal next turn.

      HAZARDS: the hazards you SET (Stealth Rock / Spikes / Toxic Spikes / Sticky Web) land on the
      OPPONENT'S side - check the HAZARDS 'opponent side' entry. Set each hazard ONCE early when safe;
      chip + speed control win games. NEVER re-set a hazard already shown on the opponent side (Stealth
      Rock is already up = it FAILS and wastes the turn - do something else). Spikes/Toxic Spikes stack
      to 3/2 layers then stop. If YOUR side has hazards hurting you and you have Rapid Spin or Defog,
      CLEAR them when it matters (protect a 4x-Rock-weak or fragile teammate).

      ANTI-LOOP - the #1 way pilots throw games is repeating a no-progress move. A move whose vs_foe
      shows WILL-FAIL does literally nothing this turn (hazard already set / foe already seeded) -
      NEVER pick it; choose a damaging move, a pivot, or a switch instead. DO NOT: re-set a
      hazard already down; re-apply Leech Seed to an already-seeded foe (shown as 'seeded'); Toxic/
      burn/paralyze a foe that already has a status (its status is shown - one status per foe);
      re-use a self-lowering move (Draco Meteor / Leaf Storm / Overheat / Close Combat) into the same
      target after your stat is already dropped - switch or click a different move. If you and the foe
      are both walls and neither is making progress (repeated status/recovery/hazard turns), BREAK the
      pattern: phaze, pivot with U-turn/Volt Switch, bring in an attacker, or just click your best
      damaging move. A turn that changes nothing is a wasted turn.

      MOMENTUM: with Volt Switch / U-turn / Flip Turn, pivot to keep initiative and bring a teammate in
      safely, especially into a predicted switch. Every NEEDLESS switch gives the foe a free turn - only
      switch for a real reason (bad matchup, revenge, pivot, avoiding a KO).

      WEATHER WARS (most pilots badly misplay this): if your team has a weather setter (Sand Stream /
      Drizzle / Drought / Snow Warning) it is usually the ENGINE - Swift Swim / Sand Rush / Chlorophyll
      sweepers DOUBLE Speed in their weather, rain boosts Water x1.5 & halves Fire, sun boosts Fire &
      halves Water. CRUCIAL MECHANIC: weather abilities fire on ENTRY in speed order and the SLOWEST one
      fires LAST and WINS - so a FASTER setter LOSES a simultaneous weather clash (the opponent's slower
      setter overwrites yours). To (re)claim the weather, SWITCH YOUR SETTER IN *AFTER* the foe's weather
      is already up: your ability fires on entry and overwrites theirs, and it is then PERMANENT until
      re-overwritten. So KEEP YOUR SETTER ALIVE and cycle it back in to re-flip contested weather -
      U-turn / pivot it out rather than letting it die, ESPECIALLY if it is frail vs their weather-boosted
      STAB (e.g. don't sit a Rock/Flying sand-setter into rain-boosted Scald). Do NOT force
      weather-dependent sweeps while ENEMY weather is up (your Swift Swim/Sand Rush mon is just base
      Speed then) - flip the weather back first, or fall back on a weather-INDEPENDENT wincon.

      STATUS: if YOUR active mon is ASLEEP, do NOT switch it - switching burns the turn for free and the
      incoming mon can be slept too; STAY IN, attack (sleep ends in 1-3 turns) or use Sleep Talk. NEVER
      shuffle a sleeping mon in and out. A burned/paralyzed/poisoned mon still attacks - don't panic-
      switch over status. Don't send a mon you need into an obvious Spore/sleep lead.

      THREAT RECOGNITION - the OPPONENT TEAM preview lists their 6 mons; anticipate BEFORE they act:
      Whimsicott/Ninetales/Politoed/Mew fusions carry SPORE (sleep) - keep a Grass-type or Magic-Bounce
      Espeon in back, don't lead your wincon into them; Arceus/Sylveon fusions have ExtremeSpeed/Pixilate
      priority - Steel/Rock/Ghost blunt it, don't leave frail mons in range; Gliscor fusions
      (Groudon/Gliscor, Regigigas/Gliscor) are Poison-Heal walls IMMUNE to Ground AND Electric - break
      them with ICE (4x!) or special coverage, never Ground/Electric; Aegislash fusions Spectral-Thief
      STEAL your boosts + Whirlwind phaze - NEVER set up into them; Kyurem/Weavile/Mamoswine fusions
      carry Ice that is 4x on Gliscor and Dragons; Kyogre fusions set Drizzle that overwrites your weather.

      Win by exploiting types, weather wars, hazards, setup, priority, speed, and predicting switches.
      Output ONLY the single-line JSON object, no preamble or text around it.
    SYS

  def claude_policy(team_plan = "", model: "claude-sonnet-5")
    system = PILOT_SYSTEM
    lambda do |battle, i, st|
      # Forced turns need no LLM: skip the API call when there is only one legal action.
      lm = st["moves"]; sw = st["switches"]
      if lm.length == 1 && sw.empty?
        $SIM_LAST_REASON = "(forced)"; return [:move, lm[0]["idx"]]
      elsif lm.empty?
        $SIM_LAST_REASON = "(forced)"; return random_policy(battle, i, st)
      end
      begin
        txt = ClaudeClient.complete(system: system, user: build_prompt(st, team_plan), model: model, max_tokens: 200, cache: true)
        m = txt[/\{.*\}/m]
        raise "no JSON in reply" if m.nil? || m.empty?
        j = ClaudeClient.json_parse(m)
        # tolerate key drift: models occasionally emit move/index instead of idx, or {"switch":n}
        idx = (j["idx"] || j["index"] || j["move"] || j["move_index"] || j["slot"] || j["switch"]).to_i
        is_switch = j["action"] == "switch" || (j["action"].nil? && j.key?("switch"))
        act = is_switch ? [:switch, idx] : [:move, idx]
        $SIM_LAST_REASON = j["reason"] || j["why"]
        legal = (act[0] == :move) ? legal_moves(battle, i).include?(idx) : legal_switches(battle, i).include?(idx)
        legal ? act : random_policy(battle, i, st)
      rescue => e
        $SIM_LAST_REASON = "(fallback: #{e.message[0, 40]})"
        random_policy(battle, i, st)
      end
    end
  end

  def install!
    return if @installed
    eval(<<~RUBY, TOPLEVEL_BINDING)
      class PokeBattle_AI
        alias_method :sim_orig_choose, :pbDefaultChooseEnemyCommand unless method_defined?(:sim_orig_choose)
        def pbDefaultChooseEnemyCommand(idxBattler)
          side = (@battle.pbOwnedByPlayer?(idxBattler) ? 0 : 1)
          if $SIM_DECIDE && !(($SIM_NATIVE_SIDES || []).include?(side))
            $SIM_DECIDE.call(@battle, idxBattler)
          else
            sim_orig_choose(idxBattler)   # real (upgraded) native trainer AI
          end
        end
      end
      class PokeBattle_Battle
        # Faint-replacement hook at the choke point BOTH sides route through (player side goes
        # pbSwitchInBetween -> pbPartyScreen scene stub; AI side -> pbDefaultChooseNewEnemy).
        # Hooking here lets a pilot choose its own replacements.
        alias_method :sim_orig_sib, :pbSwitchInBetween unless method_defined?(:sim_orig_sib)
        def pbSwitchInBetween(idxBattler, checkLaxOnly = false, canCancel = false)
          if $SIM_REPLACE
            r = ($SIM_REPLACE.call(self, idxBattler, pbParty(idxBattler)) rescue nil)
            return r if r.is_a?(Integer) && r >= 0 && pbCanSwitchLax?(idxBattler, r)
          end
          sim_orig_sib(idxBattler, checkLaxOnly, canCancel)
        end
        # Diagnostic for the early-end bug (side "concedes" with able mons): log why
        # pbCanChooseNonActive? says no replacement exists.
        alias_method :sim_orig_ccna, :pbCanChooseNonActive? unless method_defined?(:sim_orig_ccna)
        def pbCanChooseNonActive?(idx)
          r = sim_orig_ccna(idx)
          if !r && $SIM_DEBUG_REPLACE
            able = []
            pbParty(idx).each_with_index { |p, i| able << i if p && p.able? }
            lax = able.select { |i| pbCanSwitchLax?(idx, i) }
            warn "[sim-ccna] idx=\#{idx} says NO replacement; able_party_idx=\#{able.inspect} passing_lax=\#{lax.inspect}"
          end
          r
        end
      end
    RUBY
    @installed = true
  end

  # Type effectiveness that models move-specific overrides the raw table misses:
  # function 11C (Thousand Arrows / Smack Down) hits Flying at 1x instead of immune.
  HITS_FLYING = %i[THOUSANDARROWS SMACKDOWN].freeze
  def move_type_eff(move_id, mt, target)
    tts = btypes(target)
    if HITS_FLYING.include?(move_id) && mt == :GROUND
      prod = 1.0
      tts.each do |dt|
        prod *= (dt == :FLYING ? 1.0 : (Effectiveness.calculate_one(mt, dt).to_f / Effectiveness::NORMAL_EFFECTIVE_ONE rescue 1.0))
      end
      return prod
    end
    (Effectiveness.calculate(mt, *tts) / 8.0 rescue 1.0)
  end

  def legal_moves(battle, i)
    b = battle.battlers[i]
    (0...b.moves.length).select do |mi|
      m = b.moves[mi]
      m && m.id && m.id != :NONE && (battle.pbCanChooseMove?(i, mi, false) rescue true)
    end
  end

  def legal_switches(battle, i)
    party = battle.pbParty(i)
    (0...party.length).select { |pi| (battle.pbCanSwitch?(i, pi) rescue false) }
  end

  def pct(b)
    (b && b.totalhp > 0) ? (100.0 * b.hp / b.totalhp).round : 0
  end

  # Compact battle state for side of battler i (also the future LLM prompt payload).
  def eff_label(v)
    return "IMMUNE" if v == 0
    mult = v / 8.0
    return "1x" if mult == 1
    mult < 1 ? "#{mult}x-RESISTED" : "#{mult}x-SUPER"
  end

  # Decode a mon to recognizable "Head/Body" component names (or plain species) for team preview.
  def species_label(pk)
    s = (pk.species rescue nil)
    if s.is_a?(Symbol) && s.to_s =~ /\AB(\d+)H(\d+)\z/
      h = (GameData::Species.get($2.to_i).real_name rescue $2)
      b = (GameData::Species.get($1.to_i).real_name rescue $1)
      "#{h}/#{b}"
    else
      (pk.speciesName rescue s.to_s)
    end
  end

  # Entry hazards on a side, as a short label ("SR, Spikes x2" or "none").
  def hazards_str(side)
    return "?" unless side
    e = side.effects rescue nil
    return "?" unless e
    h = []
    h << "StealthRock"  if (e[PBEffects::StealthRock] rescue false)
    sp = (e[PBEffects::Spikes] rescue 0);      h << "Spikes x#{sp}"       if sp && sp > 0
    ts = (e[PBEffects::ToxicSpikes] rescue 0); h << "ToxicSpikes x#{ts}"  if ts && ts > 0
    h << "StickyWeb"    if (e[PBEffects::StickyWeb] rescue false)
    h.empty? ? "none" : h.join(", ")
  end

  # Nonzero stat boosts of a battler, as "Atk+2 Spe+1" (or "" if none).
  def boosts_str(b)
    return "" unless b
    st = (b.stages rescue nil)
    return "" unless st.is_a?(Hash)
    abbr = { ATTACK: "Atk", DEFENSE: "Def", SPECIAL_ATTACK: "SpA", SPECIAL_DEFENSE: "SpD",
             SPEED: "Spe", ACCURACY: "Acc", EVASION: "Eva" }
    st.map { |k, v| (v && v != 0) ? "#{abbr[k] || k}#{v > 0 ? '+' : ''}#{v}" : nil }.compact.join(" ")
  end

  def stage_mult(b, key)
    s = ((st = (b.stages rescue nil)).is_a?(Hash) ? (st[key] || 0) : 0)
    s >= 0 ? (2.0 + s) / 2 : 2.0 / (2 - s)
  end

  def btypes(b); (b.pbTypes(true) rescue []).map { |t| t.respond_to?(:id) ? t.id : t }; end

  # ---- Deterministic turn-card helpers: offload ALL the mechanics from the pilot ----------------
  # Abilities that fully nullify/absorb a move of the given TYPE (folded into effectiveness so the
  # pilot never sees a fake damage number through a Levitate/Water-Absorb wall).
  ABILITY_TYPE_IMMUNITY = {
    GROUND:   %i[LEVITATE],
    WATER:    %i[WATERABSORB STORMDRAIN DRYSKIN],
    ELECTRIC: %i[VOLTABSORB LIGHTNINGROD MOTORDRIVE],
    FIRE:     %i[FLASHFIRE],
    GRASS:    %i[SAPSIPPER],
  }.freeze
  VAR_BP = %i[WATERSPOUT ERUPTION GYROBALL ELECTROBALL].freeze

  def ability_id(x)
    a = (x.ability rescue nil)
    return a.id if a.respond_to?(:id)
    return a if a.is_a?(Symbol)
    (x.respond_to?(:ability_id) ? x.ability_id : nil) rescue nil
  end

  # True if x's ability nullifies a move of type mt. Thousand Arrows / Smack Down ignore Levitate.
  def ability_negates?(mt, x, move_id = nil)
    return false if move_id && HITS_FLYING.include?(move_id)
    ab = ability_id(x); return false unless ab
    (ABILITY_TYPE_IMMUNITY[mt] || []).include?(ab)
  end

  # Move effectiveness vs target INCLUDING ability immunities (0.0 if walled by ability).
  def eff_mult(move_id, mt, target)
    return 0.0 if ability_negates?(mt, target, move_id)
    move_type_eff(move_id, mt, target)
  end

  # Type symbols of a battler OR a bench Pokemon (battlers honour Roost etc.).
  def anytypes(x)
    ts = (x.pbTypes(true) rescue nil) || (x.types rescue nil) || []
    ts.map { |t| t.respond_to?(:id) ? t.id : t }
  end

  def attacking_types
    @atk_types ||= begin
      list = []
      (GameData::Type.each { |t| list << t.id unless (t.pseudo_type rescue false) } rescue nil)
      list.empty? ? %i[NORMAL FIRE WATER ELECTRIC GRASS ICE FIGHTING POISON GROUND FLYING PSYCHIC BUG ROCK GHOST DRAGON DARK STEEL FAIRY] : list.uniq
    end
  end

  def type_name(sym); s = sym.to_s; s[0].to_s + s[1..-1].to_s.downcase; end
  def fmt_x(m); format('%g', m) + "x"; end

  # Full weak/resist/immune breakdown of x's typing from the REAL type chart, ability-adjusted.
  def defensive_profile(x)
    dts = anytypes(x); return "" if dts.empty?
    ab = ability_id(x)
    buckets = Hash.new { |h, k| h[k] = [] }
    attacking_types.each do |at|
      m = (Effectiveness.calculate(at, *dts).to_f / Effectiveness::NORMAL_EFFECTIVE rescue 1.0)
      m = 0.0 if (ABILITY_TYPE_IMMUNITY[at] || []).include?(ab)
      next if m == 1.0
      buckets[m] << type_name(at)
    end
    weak = buckets.keys.select { |k| k > 1 }.sort.reverse
    res  = buckets.keys.select { |k| k > 0 && k < 1 }.sort.reverse
    imm  = buckets.keys.select { |k| k == 0 }
    parts = []
    parts << "WEAK "   + weak.map { |k| "#{fmt_x(k)} #{buckets[k].join(',')}" }.join("  ") unless weak.empty?
    parts << "RESIST " + res.map  { |k| "#{fmt_x(k)} #{buckets[k].join(',')}" }.join("  ") unless res.empty?
    parts << "IMMUNE " + imm.flat_map { |k| buckets[k] }.join(",") unless imm.empty?
    note = (ab && ABILITY_TYPE_IMMUNITY.values.flatten.include?(ab)) ? " [via #{ab}]" : ""
    parts.join(" | ") + note
  end

  # A mon's best damaging-move effectiveness vs foe (OFF) and how it takes foe's STAB (DEF/take).
  def mon_vs_foe(pk, foe)
    ftps = anytypes(foe)
    best = 0.0; best_id = nil
    (pk.moves || []).each do |mv|
      next unless mv && mv.respond_to?(:id) && mv.id && mv.id != :NONE
      md = (GameData::Move.get(mv.id) rescue nil); next unless md
      next if md.category == 2
      next if md.base_damage.to_i <= 0 && !VAR_BP.include?(mv.id)
      m = eff_mult(mv.id, md.type, foe)
      if m > best; best = m; best_id = mv.id; end
    end
    dtps = anytypes(pk)
    take = (ftps.map { |ft| Effectiveness.calculate(ft, *dtps).to_f / Effectiveness::NORMAL_EFFECTIVE }.max rescue 1.0)
    { "name" => (pk.speciesName rescue "?"), "off" => best, "off_id" => (best_id ? best_id.to_s : nil), "take" => take }
  end

  # Deterministic MAX-roll damage estimate (pre the 0.85-1.0 random roll). Returns raw damage or nil
  # for status/variable-power moves. Captures BP, atk/def (with stages), STAB, type-eff (incl.
  # immunities), item (LO/Band/Specs/Thick Club), burn, and weather. Ability immunities aren't
  # modeled (same limitation as the vs_foe label) - a known gap noted in the prompt.
  def est_damage(battle, user, target, move)
    md = (GameData::Move.get(move.id) rescue nil); return nil unless md
    cat = md.category; return nil if cat == 2
    mt = md.type
    bp = md.base_damage
    # Variable-power moves the flat base_damage gets wrong. Water Spout read as a flat 150 was the
    # cause of the bogus "403% OHKO" incoming alarms that made every Kyogre turn look unwinnable.
    case move.id
    when :WATERSPOUT, :ERUPTION
      bp = [(150 * user.hp / [user.totalhp, 1].max), 1].max
    when :GYROBALL
      us = (user.pbSpeed rescue 1); ts = (target.pbSpeed rescue 1)
      bp = [[(25 * ts / [us, 1].max) + 1, 150].min, 1].max
    when :ELECTROBALL
      us = (user.pbSpeed rescue 1); ts = (target.pbSpeed rescue 1); r = us.to_f / [ts, 1].max
      bp = r >= 4 ? 150 : r >= 3 ? 120 : r >= 2 ? 80 : r >= 1 ? 60 : 40
    end
    return nil if bp.nil? || bp <= 0    # other variable/fixed power - can't estimate
    return 0 if ability_negates?(mt, target, move.id)    # Levitate / Water Absorb / Flash Fire / etc.
    a = (cat == 0 ? user.attack * stage_mult(user, :ATTACK) : user.spatk * stage_mult(user, :SPECIAL_ATTACK))
    d = (cat == 0 ? target.defense * stage_mult(target, :DEFENSE) : target.spdef * stage_mult(target, :SPECIAL_DEFENSE))
    base = ((2.0 * user.level / 5 + 2).floor * bp * a / d / 50).floor + 2
    eff = move_type_eff(move.id, mt, target); return 0 if eff == 0
    stab = btypes(user).include?(mt) ? 1.5 : 1.0
    burn = (cat == 0 && (user.status == :BURN rescue false)) ? 0.5 : 1.0
    it = (user.item&.id rescue nil)
    im = case it
         when :LIFEORB then 1.3
         when :CHOICEBAND then (cat == 0 ? 1.5 : 1.0)
         when :CHOICESPECS then (cat == 1 ? 1.5 : 1.0)
         when :THICKCLUB then ((cat == 0 && (user.isFusionOf(:MAROWAK) rescue false)) ? 2.0 : 1.0)
         else 1.0 end
    w = (battle.field.weather rescue nil); wm = 1.0
    wm = 1.5 if [:Rain, :HeavyRain].include?(w) && mt == :WATER
    wm = 0.5 if w == :Rain && mt == :FIRE
    wm = 1.5 if [:Sun, :HarshSun].include?(w) && mt == :FIRE
    wm = 0.5 if w == :Sun && mt == :WATER
    (base * stab * eff * burn * im * wm).floor
  end

  # Compact KO label: dmg vs target's CURRENT hp. max-roll d; guaranteed if 0.85*d >= hp.
  def ko_label(d, target)
    return "immune" if d == 0
    hp = target.hp
    hi = (d * 100.0 / target.totalhp).round
    lo = (d * 0.85 * 100.0 / target.totalhp).round
    tag = if d * 0.85 >= hp then "OHKO"
          elsif d >= hp then "~OHKO(roll)"
          else n = (hp.to_f / (d * 0.9)).ceil; "#{n}HKO" end
    "#{lo}-#{hi}% #{tag}"
  end

  def state(battle, i)
    me  = battle.battlers[i]
    foe = (battle.battlers[i ^ 1] rescue nil) || battle.battlers.find { |b| b && b.index != i }
    ftypes = (foe.pbTypes(true) rescue [])
    foe_team = (battle.pbParty(foe.index).compact.map { |pk| species_label(pk) } rescue [])
    my_spe   = (me.pbSpeed rescue 0)
    foe_spe  = (foe.pbSpeed rescue 0)
    speed    = my_spe == foe_spe ? "SAME" : (my_spe > foe_spe ? "FASTER" : "SLOWER")
    my_side  = (battle.sides[i % 2] rescue nil)
    foe_side = (battle.sides[(i + 1) % 2] rescue nil)

    # Hazard/seed moves that would FAIL because they're already active on the target - so the pilot
    # never wastes turns re-setting them (the #1 stall-loop cause).
    fe = (foe_side.effects rescue nil) || {}
    maxed = { STEALTHROCK: (fe[PBEffects::StealthRock] rescue false),
              SPIKES: ((fe[PBEffects::Spikes] rescue 0).to_i >= 3),
              TOXICSPIKES: ((fe[PBEffects::ToxicSpikes] rescue 0).to_i >= 2),
              STICKYWEB: (fe[PBEffects::StickyWeb] rescue false) }
    foe_seeded_now = ((foe.effects[PBEffects::LeechSeed] || -1) >= 0 rescue false)
    foe_type_syms  = (foe.pbTypes(true) rescue [])
    foe_statused   = (s = foe.status.to_s; s != "" && s != "NONE" && s != "0")
    # Status moves that FAIL against an immune type, so they aren't wasted (mirrors the hazard no-op).
    status_immune = { TOXIC: %i[STEEL POISON], POISONPOWDER: %i[STEEL POISON], POISONGAS: %i[STEEL POISON],
                      WILLOWISP: %i[FIRE], THUNDERWAVE: %i[GROUND ELECTRIC], LEECHSEED: %i[GRASS],
                      SPORE: %i[GRASS], SLEEPPOWDER: %i[GRASS], STUNSPORE: %i[GRASS], POWDER: %i[GRASS] }
    major_status = %i[TOXIC POISONPOWDER POISONGAS WILLOWISP THUNDERWAVE SPORE SLEEPPOWDER STUNSPORE HYPNOSIS GLARE]

    my_best_d = 0; my_best_name = nil
    moves = legal_moves(battle, i).map do |mi|
      m = me.moves[mi]
      noop = (maxed[m.id] == true) || (m.id == :LEECHSEED && foe_seeded_now)
      noop ||= (status_immune[m.id] && (foe_type_syms & status_immune[m.id]).any?) rescue noop
      noop ||= (major_status.include?(m.id) && foe_statused) rescue noop
      mult = (eff_mult(m.id, m.type, foe) rescue 1.0)
      eff = if noop then "WILL-FAIL(already active)"
            elsif m.category == 2 then "status"
            elsif mult == 0
              ab = ability_id(foe)
              (ab && ability_negates?(m.type, foe, m.id)) ? "IMMUNE(#{ab})" : "IMMUNE"
            else (eff_label((mult * 8).round) rescue "?") end
      d = (est_damage(battle, me, foe, m) rescue nil)
      if d && d > my_best_d && m.category != 2; my_best_d = d; my_best_name = m.id.to_s; end
      { "idx" => mi, "id" => m.id.to_s, "type" => (m.type.to_s rescue ""),
        "cat" => m.category, "pow" => (m.baseDamage rescue 0), "pp" => m.pp, "eff" => eff,
        "dmg" => (d.nil? ? "" : ko_label(d, foe)) }
    end
    # Incoming threat: the foe's hardest-hitting move on ME (drives set-up-vs-switch decisions).
    threat = (foe.moves.map { |fm| (fm && fm.id && fm.id != :NONE) ? (est_damage(battle, foe, me, fm) rescue nil) : nil }.compact.max rescue nil)
    incoming = threat ? ko_label(threat, me) : "?"
    switches = legal_switches(battle, i).map do |pi|
      pk = battle.pbParty(i)[pi]
      { "idx" => pi, "name" => pk.speciesName, "hp" => (pk.hp * 100 / [pk.totalhp, 1].max) }
    end

    # Bench answers (my alive non-active mons) + enemy pivots (their alive non-active mons): who has
    # a super-effective move / who resists / who they can safely pivot to. Pure type mechanics.
    my_pi  = (me.pokemonIndex rescue nil)
    foe_pi = (foe.pokemonIndex rescue nil)
    bench = (battle.pbParty(i).each_with_index.map { |pk, pi|
      (pk.nil? || (pk.egg? rescue false) || pk.hp <= 0 || pi == my_pi) ? nil : mon_vs_foe(pk, foe)
    }.compact rescue [])
    pivots = (battle.pbParty(foe.index).each_with_index.map { |pk, pi|
      (pk.nil? || (pk.egg? rescue false) || pk.hp <= 0 || pi == foe_pi) ? nil : mon_vs_foe(pk, me)
    }.compact rescue [])
    foe_defprofile = (defensive_profile(foe) rescue "")

    # Forced/near-forced move flags: pure mechanics -> a hint; the pilot still makes the call.
    flags = []
    if my_best_d > 0
      kl = ko_label(my_best_d, foe)
      flags << "TRIVIAL: #{my_best_name} is a GUARANTEED OHKO and you move first - just click it." if kl.include?("OHKO") && !kl.include?("~") && speed == "FASTER"
    end
    if incoming.include?("OHKO") && speed == "SLOWER"
      flags << "DANGER: foe likely OHKOs you before you act - switch / pivot / priority; do NOT set up or Roost."
    elsif incoming =~ /(\d+)HKO/ && $1.to_i >= 4
      flags << "SAFE: incoming is #{$1}HKO - free turn to set up / Roost / lay hazards."
    end
    fb0 = boosts_str(foe)
    flags << "PHAZE/RESET: foe is boosted (#{fb0}) - phaze / reset / revenge, don't try to out-boost." if fb0 =~ /\+[2-9]/

    me_name  = (me.pbThis(true) rescue me.pokemon.speciesName)
    foe_name = (foe.pbThis(true) rescue foe.pokemon.speciesName)
    me_abil  = ((me.ability && me.ability.id).to_s rescue "")
    me_item  = ((me.item && me.item.id).to_s rescue "")
    foe_seeded = ((foe.effects[PBEffects::LeechSeed] || -1) >= 0 rescue false)
    foe_types = (foe.pbTypes(true).map(&:to_s) rescue [])
    weather  = (battle.field.weather.to_s rescue (battle.pbWeather.to_s rescue ""))

    {
      "me"  => { "name" => me_name, "hp" => pct(me), "status" => me.status.to_s, "ability" => me_abil,
                 "item" => me_item, "boosts" => boosts_str(me) },
      "foe" => { "name" => foe_name, "hp" => pct(foe), "status" => foe.status.to_s, "types" => foe_types,
                 "boosts" => boosts_str(foe), "seeded" => foe_seeded, "defprofile" => foe_defprofile },
      "weather" => weather, "speed" => speed, "moves" => moves, "switches" => switches, "foe_team" => foe_team,
      "hazards_me" => hazards_str(my_side), "hazards_foe" => hazards_str(foe_side), "incoming" => incoming,
      "bench" => bench, "pivots" => pivots, "flags" => flags
    }
  end

  def apply(battle, i, action)
    kind, idx = action
    if kind == :switch && legal_switches(battle, i).include?(idx)
      battle.pbRegisterSwitch(i, idx)
    elsif kind == :move && legal_moves(battle, i).include?(idx)
      battle.pbRegisterMove(i, idx)
    else
      battle.pbAutoChooseMove(i)
    end
  end

  def random_policy(battle, i, st)
    mv = st["moves"]
    return [:switch, st["switches"].first["idx"]] if mv.empty? && !st["switches"].empty?
    return [:move, mv.sample["idx"]] unless mv.empty?
    [:move, 0]
  end

  # Run a battle with two side-policies. Returns [decision, actions_log].
  def run(team1, team2, policy1 = method(:random_policy), policy2 = method(:random_policy), seed: nil, cap: nil)
    install!
    srand(seed) if seed
    log = []
    count = 0
    $SIM_DECIDE = lambda do |battle, i|
      count += 1
      st = state(battle, i)
      side = (battle.pbOwnedByPlayer?(i) ? 0 : 1)
      $SIM_LAST_REASON = nil
      # cost cap: after N decisions, fall back to the fast local policy to end the game
      pol = (cap && count > cap) ? method(:random_policy) : (side == 0 ? policy1 : policy2)
      action = pol.call(battle, i, st)
      lbl = action[0] == :move ? ((st["moves"].find { |m| m["idx"] == action[1] } || {})["id"] || "?") : "switch->#{action[1]}"
      reason = $SIM_LAST_REASON ? "  \"#{$SIM_LAST_REASON}\"" : ""
      log << "  side#{side} #{st["me"]["name"]} (#{st["me"]["hp"]}%) -> #{lbl}#{reason}"
      apply(battle, i, action)
    end
    dec = SimBattle.run(team1, team2)
    $SIM_DECIDE = nil
    [dec, log]
  end

  # Best-of-N to cut single-game noise. build1/build2 are thunks returning a FRESH team
  # (Pokemon get mutated in battle, so each game needs new objects). Returns
  # [majority_dec (1|2|5), combined_log, tally_hash]. Each game uses a distinct seed.
  def series(build1, build2, policy1, policy2, games: 3, cap: nil)
    tally = { a: 0, b: 0, draw: 0 }
    logs = []
    games.times do |g|
      dec, log = run(build1.call, build2.call, policy1, policy2, seed: g + 1, cap: cap)
      key = dec == 1 ? :a : dec == 2 ? :b : :draw
      tally[key] += 1
      logs << "----- game #{g + 1} (seed #{g + 1}): winner=#{key} -----"
      logs.concat(log)
    end
    winner = tally[:a] > tally[:b] ? 1 : tally[:b] > tally[:a] ? 2 : 5
    [winner, logs, tally]
  end
end
