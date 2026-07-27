#===============================================================================
# sidmod: Smart Trainer AI (plan-based)
#
# Replaces the enemy trainer's per-turn decision with a planner that compares
# ALL candidate actions on one utility scale:
#   - every usable move (attack / setup / status), scored by the vanilla
#     effect-score library (005_AI_Move_EffectScores) as the tactical signal,
#     then repriced by a strategic damage-race model (turns-to-KO both ways,
#     speed order, priority, KO windows)
#   - every legal switch, scored by the same race model applied to the benched
#     Pokemon (including the free hit given up on the switch and entry hazards)
# Vanilla behaviour is fully preserved behind aliases and used as fallback for
# wild battles, doubles, and when SmartAI::ENABLED is false.
# AI item use stays disabled (see "no AI item usage" in sidmod.txt).
#
# To revert: delete this file (folder 055_sidmod).
#===============================================================================

module SmartAI
  ENABLED = true

  # --- strategic layer tunables ---------------------------------------------
  KO_FIRST_BONUS    = 260   # we can KO and we act first (scaled by accuracy)
  KO_SLOW_BONUS     = 140   # we can KO but foe acts first
  OVERKILL_PENALTY  = 25    # max penalty for overkill KOs (prefer weakest sufficient KO)
  PRIORITY_SAVE     = 130   # foe would KO us first; move has priority
  PIVOT_LOSING      = 60    # U-turn/Volt Switch bonus when losing the race
  DOOMED_MULT       = 0.55  # foe KOs us before we move: our action may not happen
  STATUS_KILL_MULT  = 0.20  # target dies to our attack this turn: don't status
  STATUS_TIGHT_MULT = 0.35  # race is tight/lost: no time for status moves
  SETUP_SAFE_MULT   = 1.60  # safe to set up (foe needs 4+ turns to kill us)
  SETUP_HP_FRACTION = 0.6   # ...and only while healthy enough to use the boosts
  LOW_ROLL          = 0.85  # damage low roll used for "guaranteed KO" checks
  SWITCH_BASE       = 110   # base utility of a clearly-better switch
  SWITCH_EDGE_SCALE = 35    # utility per point of race-edge improvement
  SWITCH_MIN_GAIN   = 1.0   # candidate must beat current matchup by this edge
  SWITCH_CAP        = 300   # never value a switch above a likely KO
  BOOST_STAGES_STAY = 2     # never switch away this many positive stat stages (was 4: the
                            # planner was banking Bulk Ups and then pivoting out of them)
  BAD_MOVES_SCORE   = 40    # best move below this = emergency (encore/taunt/no PP)
  THRESHOLD_FACTOR  = 0.95  # v21-style discard: only moves within 5% of best survive,
                            # picked weighted by how far above the cutoff they are
  TTK_CAP           = 8

  # --- defensive play (sidmod v2) -------------------------------------------
  # Measured problem this fixes: over 36 logged battles the AI had 119 chances to
  # use a recovery move and took 1 (0.8%). A heal was scored as a generic status
  # move, so STATUS_TIGHT_MULT (0.35) suppressed it in exactly the spot where
  # healing matters most - while losing the damage race. And residual (chip)
  # damage was absent from the TTK model, so a stall win condition was invisible:
  # healing never shortened our clock and poison never shortened theirs.
  HEAL_OUTPACE_BONUS = 240  # heal restores more per turn than the foe deals -> we win by attrition
  HEAL_SURVIVE_BONUS = 120  # heal buys at least one more turn
  HEAL_MIN_MISSING   = 0.30 # need this fraction of max HP missing before healing is worth a turn
  HEAL_FULL_MULT     = 0.15 # topping off a healthy mon wastes the turn
  HEAL_DOOMED_MULT   = 0.10 # we die before the heal matters
  REST_MULT          = 0.55 # Rest also sleeps us for 2 turns
  CHIP_STATUS_BONUS  = 200  # inflict status on a foe we are not out-racing -> puts it on a clock
  CHIP_SETUP_BONUS   = 80   # ...and it is boosting, so it only gets worse: status it now
  PROTECT_CHIP_BONUS = 90   # foe is already losing HP per turn: Protect banks it for free
  PROTECT_SPAM_MULT  = 0.40 # consecutive Protects mostly fail
  ATTRITION_BONUS    = 120  # we out-sustain AND they are on a clock: the stall plan is winning

  # --- analytic 1-step preview (sidmod v2) -----------------------------------
  # Real tree search was priced and rejected: a search node needs a state snapshot
  # (party deep-copy = 2.6 ms), so a joint 1-ply expansion is 81 nodes = 212 ms per
  # decision (45x the current 4.67 ms) and 2-ply is 17 SECONDS. Instead each
  # candidate is projected forward ONE step with arithmetic on damage numbers we
  # already have - no cloning, no measurable cost - so the planner can see the
  # state its action leads to.
  SUICIDE_MULT      = 0.45  # we die, they live, and the action left nothing behind
  SETUP_CONVERT_MIN = 2     # a boost must bring the foe within this many turns of dying
  SETUP_NOCONVERT   = 0.35  # ...otherwise the boost turn is wasted

  # Moves that put a foe on a residual clock (the thing that makes stall work).
  CHIP_MOVES   = %i[TOXIC WILLOWISP THUNDERWAVE GLARE YAWN LEECHSEED CONFUSERAY
                    POISONPOWDER STUNSPORE SLEEPPOWDER HYPNOSIS GRASSWHISTLE SING
                    NUZZLE TOXICTHREAD]
  PROTECT_MOVES = %i[PROTECT DETECT KINGSSHIELD SPIKYSHIELD BANEFULBUNKER OBSTRUCT]

  # Answering a foe that is setting up. Measured failure: a wall holding HAZE watched a
  # Bulk Up sweeper climb to +2/+2 unopposed and clicked Toxic instead.
  PHAZE_BOOST_BONUS = 90    # per positive stat stage on the foe, for reset/force-out moves
  PHAZE_BOOST_CAP   = 320   # ...capped so it never outbids an available KO
  PHAZE_MOVES  = %i[HAZE CLEARSMOG]                      # wipe stat changes outright
  FORCEOUT_MOVES = %i[WHIRLWIND ROAR DRAGONTAIL CIRCLETHROW]  # remove the boosted mon
  REPL_OHKO_PENALTY = 3.0   # replacement that the active foe outspeeds and OHKOs

  # Ability immunities, mapped explicitly: the engine's pbImmunityByAbility DISPLAYS
  # the ability splash, so it must never be called from a scoring pass.
  ABILITY_IMMUNE_TYPE = {
    WATERABSORB: :WATER, STORMDRAIN: :WATER, DRYSKIN: :WATER,
    VOLTABSORB: :ELECTRIC, LIGHTNINGROD: :ELECTRIC, MOTORDRIVE: :ELECTRIC,
    FLASHFIRE: :FIRE, WELLBAKEDBODY: :FIRE,
    SAPSIPPER: :GRASS, LEVITATE: :GROUND, EARTHEATER: :GROUND
  }
  ABSORB_ABILITIES = %i[WATERABSORB VOLTABSORB DRYSKIN STORMDRAIN LIGHTNINGROD
                        SAPSIPPER MOTORDRIVE FLASHFIRE EARTHEATER WELLBAKEDBODY]
  GROUNDED_ANYWAY  = %i[THOUSANDARROWS SMACKDOWN]   # hit Levitate/Flying anyway

  # --- BEAM SEARCH (sidmod v3) -----------------------------------------------
  # Cloning the engine state per node costs 2.6 ms, which is what made real search
  # impossible (joint 1-ply = 212 ms, 2-ply = 17 s per decision). So the beam runs
  # over an ABSTRACT state instead - HP both sides, an offensive/defensive
  # multiplier standing in for stat stages, status, and per-turn residual - with the
  # damage numbers computed ONCE per decision and then reused as pure arithmetic.
  # A node is microseconds, so a 2-turn beam is affordable.
  # This exists because the log audit's recurring complaint was that the planner is
  # purely reactive: it optimises the current turn and cannot see a boost snowball,
  # a chip clock paying off, or a heal out-sustaining an attacker.
  BEAM_DEPTH  = 3     # full turns looked ahead (2 vs 3 measured over 919 games: depth 3 wins
                      # 0.534 +/- 0.017, z=2.1; depth 4 showed no further gain)
  BEAM_WIDTH  = 4     # our candidate actions kept per ply
  BEAM_WEIGHT = 130   # how much the beam's verdict moves a move's score
  BEAM_BOOST_STEP = 1.5   # per positive stage, applied multiplicatively
  BEAM_BOOST_CAP  = 4.0

  # Expected-damage term. The vanilla effect-score library rewards secondary effects,
  # so it ranked a RESISTED Waterfall (230) above a neutral STAB Earthquake (214) on a
  # Huge Power attacker - and the beam's correct preference for Earthquake was too
  # small a spread to overturn it. When no KO is on the table, the planner now prefers
  # the move that actually removes the most HP.
  DMG_WEIGHT = 130          # points per full-HP-worth of expected damage dealt

  # --- opponent switch prediction: TRIED AND REVERTED (2026-07-26) -----------
  # Built twice on top of the beam - once blending a full "they pivot now" scenario by
  # switch probability, once as a narrow veto on moves the likely switch-in is immune
  # to. Both worked mechanically (the veto cut pivot-blanked hits 15 -> 10 per 112
  # battles) but NEITHER improved play: winrate 0.492 and 0.491 +/- 0.020 over ~1200
  # ablation games, and TOTAL wasted turns were unchanged (42 vs 43) because dodging
  # the pivot just moves the wasted turn onto the mon actually in front of you. The
  # hedge costs about what it saves, so it was removed rather than shipped. Do not
  # re-attempt without a better opponent model than "their best matchup by race edge".

  # --- TEAM-LEVEL PLANNING (sidmod v5) ---------------------------------------
  # Both this planner AND the stock Essentials AI evaluate only the CURRENT 1v1. That
  # is the categorical gap: measured over 1440 games the whole plan-based layer is dead
  # even with stock (0.500 +/- 0.013), because tuning a 1v1 scorer cannot express
  # "this mon is the only thing on my team that answers their sweeper, so do not trade
  # it" or "my win condition is healthy, do not throw it away".
  #   ANSWER_MULT      how much of the foe's team a mon must be the sole answer to
  #   PRESERVE_*       protecting a scarce answer / a healthy win condition
  TEAM_ANSWER_MIN   = 2     # a "threat" is a foe mon that beats >=2 of ours in the race
  PRESERVE_ANSWER   = 170   # bonus to switching OUT a scarce answer that is about to die
  PRESERVE_SACK_MULT = 0.55 # penalty for trading a scarce answer for nothing
  WINCON_STAGES     = 2     # a boosted mon at this many stages is a live win condition
  WINCON_PRESERVE   = 140   # ...protect it when it is about to be revenge-killed

  # --- feature gate (SIM ONLY) -----------------------------------------------
  # In game $SIDMOD_AI_FEATURES is nil and every feature is on. The offline harness
  # sets it per side so one AI version can be played against another and each
  # feature's real contribution measured instead of guessed from small samples.
  #   $SIDMOD_AI_FEATURES = { 0 => {}, 1 => { heal: false } }
  def self.feature?(side, f)
    return true if !defined?($SIDMOD_AI_FEATURES) || $SIDMOD_AI_FEATURES.nil?
    h = $SIDMOD_AI_FEATURES[side]
    return true if !h
    h.fetch(f, true)
  end

  # Numeric tunable with a per-side override, so the harness can play tuning
  # variants against each other instead of guessing at values.
  def self.tune(side, key, default)
    return default if !defined?($SIDMOD_AI_FEATURES) || $SIDMOD_AI_FEATURES.nil?
    h = $SIDMOD_AI_FEATURES[side]
    return default if !h
    h.fetch(key, default)
  end
end



class PokeBattle_AI
  #=============================================================================
  # Hook: replace the command chooser, keep vanilla as fallback
  #=============================================================================
  alias sidmod_vanilla_pbDefaultChooseEnemyCommand pbDefaultChooseEnemyCommand
  def pbDefaultChooseEnemyCommand(idxBattler)
    if !sidmod_smart_ai?(idxBattler)
      return sidmod_vanilla_pbDefaultChooseEnemyCommand(idxBattler)
    end
    return if pbEnemyShouldUseItem?(idxBattler)   # sidmod: always false, kept for parity
    return if @battle.pbAutoFightMenu(idxBattler)
    @battle.pbRegisterMegaEvolution(idxBattler) if pbEnemyShouldMegaEvolve?(idxBattler)
    sidmod_choose_action(idxBattler)
  end

  def sidmod_smart_ai?(idxBattler)
    return false if !SmartAI::ENABLED
    # sim-only: lets the harness put the VANILLA AI on one side as a fixed benchmark rung
    return false if !SmartAI.feature?(idxBattler % 2, :smart)
    return false if @battle.wildBattle?
    return false if !@battle.trainerBattle?
    # Strategic layer reasons about a 1v1 race; doubles fall back to vanilla
    return false if @battle.pbSideSize(0) > 1 || @battle.pbSideSize(1) > 1
    return false if @battle.pbOwnedByPlayer?(idxBattler)
    return true
  end

  #=============================================================================
  # The planner
  #=============================================================================
  def sidmod_choose_action(idxBattler)
    user   = @battle.battlers[idxBattler]
    target = user.pbDirectOpposing(true)
    skill  = 100   # smart AI always reasons at best-tier fidelity
    if target.fainted?
      return sidmod_vanilla_pbDefaultChooseEnemyCommand(idxBattler)
    end
    ctx = sidmod_race_context(user, target, skill)
    # ---- candidate actions: moves --------------------------------------------
    choices = []   # [:move, idxMove, idxTarget, score] / [:switch, idxParty, -1, score]
    vanilla = []
    user.eachMoveWithIndex do |_m, i|
      next if !@battle.pbCanChooseMove?(idxBattler, i, false)
      pbRegisterMoveTrainer(user, i, vanilla, skill)
    end
    zeroed = []   # sidmod: no-op moves, kept as a last resort (see below)
    # sidmod: beam search over the abstract state, once per decision. Blended into the
    # existing scores rather than replacing them, so the proven vanilla+repricing
    # signal still leads and the beam only breaks ties / catches multi-turn plans.
    beam = SmartAI.feature?(idxBattler % 2, :beam) ? sidmod_beam_values(user, target, ctx, skill) : {}
    if $INTERNAL && !beam.empty?
      PBDebug.log("[SmartAI] beam(d#{SmartAI::BEAM_DEPTH}): " +
                  beam.map { |i, v| "#{user.moves[i].name}=#{'%+.2f' % v}" }.join(', '))
    end
    beam_mid = beam.empty? ? 0.0 : (beam.values.max + beam.values.min) / 2.0
    vanilla.each do |c|
      idxMove, score, idxTarget = c[0], c[1].to_f, c[2]
      moveTarget = (idxTarget >= 0) ? @battle.battlers[idxTarget] : target
      before = score
      score = sidmod_reprice_move(user, moveTarget, user.moves[idxMove], score, ctx, skill)
      if score > 0
        if beam.key?(idxMove)
          # centre the beam on its own mid-point so it re-ranks rather than inflates
          score += SmartAI.tune(idxBattler % 2, :beam_weight, SmartAI::BEAM_WEIGHT) *
                   (beam[idxMove] - beam_mid)
        end
        score = 1.0 if score < 1.0
        choices.push([:move, idxMove, idxTarget, score.to_i])
      else
        helps_foe = sidmod_helps_foe?(user, moveTarget, user.moves[idxMove])
        zeroed.push([:move, idxMove, idxTarget, 1, before, helps_foe])
      end
    end
    bestMoveScore = choices.map { |c| c[3] }.max || 0
    # ---- candidate actions: switches -----------------------------------------
    sidmod_add_switch_choices(idxBattler, user, target, ctx, choices, bestMoveScore)
    # ---- every option is a no-op ---------------------------------------------
    # sidmod: previously this handed control to the vanilla AI, which cheerfully
    # re-picked the very move we had just ruled out (measured: 13 such hand-offs in a
    # single battle, each one a wasted or immunity-blocked turn). Now the planner
    # keeps the decision and plays the least-bad option itself, preferring whatever
    # the vanilla scorer liked most. Vanilla is only used when there is genuinely
    # nothing to choose from (Struggle).
    if choices.empty?
      if !zeroed.empty?
        # Prefer a move that merely does nothing over one the foe ABSORBS for HP:
        # clicking Scald into Water Absorb was measured as the single most common
        # remaining blunder (58 in one stall-mirror battle).
        best = zeroed.min_by { |c| [c[5] ? 1 : 0, -c[4].to_f] }
        PBDebug.log("[SmartAI] every option is a no-op; least-bad = "                     "#{user.moves[best[1]].name}#{best[5] ? ' (all options feed the foe)' : ''}")
        choices.push([best[0], best[1], best[2], best[3]])
      else
        PBDebug.log("[SmartAI] no scored choices at all; falling back to vanilla")
        return sidmod_vanilla_pbDefaultChooseEnemyCommand(idxBattler)
      end
    end
    # ---- pick: argmax with near-tie randomisation ----------------------------
    if $INTERNAL
      msg = choices.map { |c|
        c[0] == :move ? "#{user.moves[c[1]].name}=#{c[3]}" : "SWITCH:#{@battle.pbParty(idxBattler)[c[1]].name}=#{c[3]}"
      }.join(", ")
      PBDebug.log("[SmartAI] #{user.pbThis} (#{idxBattler}) [myTTK=#{ctx[:my_ttk]} theirTTK=#{ctx[:their_ttk]} first=#{ctx[:user_first]}]: #{msg}")
    end
    # v21-style threshold discard: everything below 95% of the best is dropped;
    # survivors are weighted by their margin above the cutoff.
    maxScore  = choices.map { |c| c[3] }.max
    threshold = maxScore * SmartAI::THRESHOLD_FACTOR
    pool = choices.map { |c| [c, c[3] - threshold] }.select { |_c, w| w > 0 }
    if pool.empty?
      action = choices.max_by { |c| c[3] }
    else
      totalW = pool.inject(0.0) { |s, (_c, w)| s + w }
      roll = pbAIRandom((totalW * 100).to_i + 1) / 100.0
      action = pool[-1][0]
      pool.each do |c, w|
        roll -= w
        if roll <= 0
          action = c
          break
        end
      end
    end
    if action[0] == :switch
      if @battle.pbRegisterSwitch(idxBattler, action[1])
        PBDebug.log("[SmartAI] #{user.pbThis} (#{idxBattler}) will switch to #{@battle.pbParty(idxBattler)[action[1]].name}")
        return
      end
      # switch refused by engine -> best move instead
      moves = choices.select { |c| c[0] == :move }
      return sidmod_vanilla_pbDefaultChooseEnemyCommand(idxBattler) if moves.empty?
      action = moves.max_by { |c| c[3] }
    end
    @battle.pbRegisterMove(idxBattler, action[1], false)
    @battle.pbRegisterTarget(idxBattler, action[2]) if action[2] >= 0
    if @battle.choices[idxBattler][2]
      PBDebug.log("[SmartAI] #{user.pbThis} (#{idxBattler}) will use #{@battle.choices[idxBattler][2].name}")
    end
  end

  #=============================================================================
  # Damage-race model (active battler vs active battler)
  #=============================================================================
  # Expected per-turn damage of one move; also raw (pre-accuracy) damage.
  def sidmod_move_damage(move, user, target, skill)
    return [0, 0, 0] if !move.damagingMove?
    baseDmg = pbMoveBaseDamage(move, user, target, skill)
    raw     = pbRoughDamage(move, user, target, skill, baseDmg)
    acc     = pbRoughAccuracy(move, user, target, skill)
    expected = raw * acc / 100.0
    expected *= 0.5 if move.chargingTurnMove?   # loses a turn charging
    return [raw, expected, acc]
  end

  # Best damage numbers for one battler against another.
  # Returns {dpt:, ko_low:, ko_acc:, ko_prio:} - dpt drives TTK, ko_* flag a
  # likely-lethal single hit (low roll >= target's current HP).
  def sidmod_best_attack(attacker, defender, skill)
    ret = { dpt: 1.0, ko_low: false, ko_acc: 0, ko_prio: false }
    attacker.eachMoveWithIndex do |m, i|
      next if !@battle.pbCanChooseMove?(attacker.index, i, false)
      raw, expected, acc = sidmod_move_damage(m, attacker, defender, skill)
      next if raw <= 0
      ret[:dpt] = expected if expected > ret[:dpt]
      if raw * SmartAI::LOW_ROLL >= defender.hp && acc >= 70
        ret[:ko_low] = true
        ret[:ko_acc] = acc if acc > ret[:ko_acc]
        ret[:ko_prio] = true if m.priority > 0
      end
    end
    return ret
  end

  def sidmod_outspeeds?(aSpeed, bSpeed)
    if @battle.field.effects[PBEffects::TrickRoom] > 0
      return aSpeed < bSpeed
    end
    return aSpeed > bSpeed
  end

  # sidmod: net HP change per turn from residual effects (positive = gains HP).
  # This is what makes an attrition plan visible to the planner: poison/burn/Leech
  # Seed/weather shorten the foe's clock, Leftovers/Poison Heal lengthen ours.
  def sidmod_residual_hp(b)
    return 0.0 if !b || b.fainted?
    tot = b.totalhp.to_f
    net = 0.0
    indirect = (b.takesIndirectDamage? rescue true)
    case b.status
    when :POISON
      if b.hasActiveAbility?(:POISONHEAL)
        net += tot / 8.0
      elsif indirect
        # badly poisoned ramps: Toxic counter / 16 (engine formula), else a flat 1/8
        net -= (b.statusCount == 0) ? tot / 8.0 :
               tot * [b.effects[PBEffects::Toxic], 1].max / 16.0
      end
    when :BURN
      net -= (Settings::MECHANICS_GENERATION >= 7 ? tot / 16.0 : tot / 8.0) if indirect
    end
    net -= tot / 8.0 if indirect && b.effects[PBEffects::LeechSeed] >= 0
    w = (@battle.pbWeather rescue nil)
    if indirect
      if w == :Sandstorm && !(b.pbHasType?(:ROCK) || b.pbHasType?(:GROUND) || b.pbHasType?(:STEEL))
        net -= tot / 16.0
      elsif w == :Hail && !b.pbHasType?(:ICE)
        net -= tot / 16.0
      end
    end
    net += tot / 16.0 if b.hasActiveItem?(:LEFTOVERS)
    net += (b.pbHasType?(:POISON) ? tot / 16.0 : -tot / 8.0) if b.hasActiveItem?(:BLACKSLUDGE)
    net += tot / 16.0 if b.effects[PBEffects::AquaRing]
    net += tot / 16.0 if b.effects[PBEffects::Ingrain]
    net
  rescue StandardError
    0.0
  end

  def sidmod_race_context(user, target, skill)
    mine   = sidmod_best_attack(user, target, skill)
    theirs = sidmod_best_attack(target, user, skill)
    userFirst = sidmod_outspeeds?(user.pbSpeed, target.pbSpeed)
    # sidmod: fold residual damage into both clocks. Chip on the foe speeds our kill;
    # our own Leftovers/Poison Heal slows theirs (and vice versa).
    resid_on   = SmartAI.feature?(user.index % 2, :residual)
    myResid    = resid_on ? sidmod_residual_hp(user)   : 0.0
    theirResid = resid_on ? sidmod_residual_hp(target) : 0.0
    myEff    = [mine[:dpt]   - theirResid, 0.5].max
    theirEff = [theirs[:dpt] - myResid,    0.5].max
    myTTK    = [(target.hp / myEff).ceil,   SmartAI::TTK_CAP].min
    theirTTK = [(user.hp   / theirEff).ceil, SmartAI::TTK_CAP].min
    # Foe KOs us before we get to act (unless we use priority)
    doomed = theirs[:ko_low] && (!userFirst || theirs[:ko_prio])
    edge = theirTTK - myTTK + (userFirst ? 0.5 : -0.5)
    return {
      my_ttk: myTTK, their_ttk: theirTTK, user_first: userFirst,
      my_ko: mine[:ko_low], their_ko: theirs[:ko_low], doomed: doomed,
      edge: edge,
      my_dpt: mine[:dpt], their_dpt: theirs[:dpt],
      my_resid: myResid, their_resid: theirResid
    }
  end

  #=============================================================================
  # sidmod: NO-OP DETECTION. A move that cannot possibly do anything is dropped
  # outright rather than merely discounted. Measured failure this fixes: in one
  # stall-vs-stall battle the AI used Haze 36 times with no stat changes on the
  # field to clear (191 failed moves across 6 battles), which both wasted every
  # turn and pushed the games into 100-turn timeout draws. Wasting turns on
  # guaranteed-nothing moves is the clearest "this is a bot" tell there is.
  #=============================================================================
  # sidmod: is the target flat-out immune to this damaging move? Covers type
  # immunity AND ability immunity via the engine's own handler, so Water Absorb /
  # Volt Absorb / Flash Fire / Levitate / Sap Sipper / Storm Drain are all caught.
  # Measured failure this fixes: the AI repeatedly clicked Scald into a Vaporeon
  # fusion with WATER ABSORB - actively healing the opponent.
  # Ability immunities, mapped explicitly BY DESIGN. The engine's own
  # pbImmunityByAbility cannot be used here: it displays the ability splash and the
  # "It doesn't affect..." message, so calling it from the AI's scoring pass printed
  # phantom battle messages (396 spurious lines in six sim battles - and in game the
  # player would see them while the AI merely thinks).
  def sidmod_ability_immune?(user, target, move_type, type_mod)
    return false if (user.hasMoldBreaker? rescue false)
    ab = (target.ability&.id rescue nil)
    return false if !ab
    return false if !(target.abilityActive? rescue true)
    if ab == :WONDERGUARD
      begin
        return !Effectiveness.super_effective?(type_mod)
      rescue StandardError
        return false
      end
    end
    need = SmartAI::ABILITY_IMMUNE_TYPE[ab]
    return false if !need || need != move_type
    true
  rescue StandardError
    false
  end

  def sidmod_immune?(user, target, move)
    return false if !move.damagingMove?
    t = move.pbCalcType(user)
    return false if !t
    old = move.instance_variable_get(:@calcType)
    move.instance_variable_set(:@calcType, t)
    mod = move.pbCalcTypeMod(t, user, target)
    move.instance_variable_set(:@calcType, old)
    return true if mod == 0
    return false if SmartAI::GROUNDED_ANYWAY.include?(move.id) && t == :GROUND
    sidmod_ability_immune?(user, target, t, mod)
  rescue StandardError
    false
  end

  # sidmod: abilities that turn an immune hit into a BENEFIT for the target. When every
  # option is a no-op, doing nothing is strictly better than healing the opponent.
  ABSORB_ABILITIES = SmartAI::ABSORB_ABILITIES
  def sidmod_helps_foe?(user, target, move)
    return false if !move.damagingMove?
    ab = (target.ability&.id rescue nil)
    return false if !ab || !ABSORB_ABILITIES.include?(ab)
    sidmod_immune?(user, target, move)
  rescue StandardError
    false
  end

  def sidmod_will_fail?(user, target, move)
    id = move.id
    return true if sidmod_immune?(user, target, move)
    # healing at full HP always fails
    return true if move.healingMove? && user.hp >= user.totalhp
    # status infliction that cannot land. Uses the ENGINE's own immunity checks
    # (pbCanPoison?/pbCanBurn?/pbCanParalyze?/pbCanSleep?/pbCanConfuse?) rather than
    # hand-rolled type rules, so abilities, Safeguard, Substitute, typings and
    # existing statuses are all handled exactly as the battle itself would.
    # Measured failure this fixes: 27 "doesn't affect" turns per 6 battles - mostly
    # Toxic clicked into Steel-type walls.
    if SmartAI::CHIP_MOVES.include?(id)
      if id == :LEECHSEED
        return true if target.effects[PBEffects::LeechSeed] >= 0 || target.pbHasType?(:GRASS)
      else
        can = case id
              when :TOXIC, :POISONPOWDER, :TOXICTHREAD then target.pbCanPoison?(user, false, move)
              when :WILLOWISP                          then target.pbCanBurn?(user, false, move)
              when :THUNDERWAVE, :GLARE, :NUZZLE       then target.pbCanParalyze?(user, false, move)
              when :SLEEPPOWDER, :HYPNOSIS, :GRASSWHISTLE, :SING
                target.pbCanSleep?(user, false, move)
              when :CONFUSERAY                         then target.pbCanConfuse?(user, false, move)
              when :YAWN then target.status == :NONE && target.effects[PBEffects::Yawn] == 0
              else target.status == :NONE
              end
        return true if !can
      end
    end
    # Haze / Clear Smog style resets with nothing to reset
    if %i[HAZE].include?(id)
      any = false
      [user, target].each do |b|
        %i[ATTACK DEFENSE SPECIAL_ATTACK SPECIAL_DEFENSE SPEED ACCURACY EVASION].each do |st|
          any = true if (b.stages[st].to_i rescue 0) != 0
        end
      end
      return true if !any
    end
    # entry hazards already at their maximum on the foe's side
    side = target.pbOwnSide
    return true if id == :STEALTHROCK && side.effects[PBEffects::StealthRock]
    return true if id == :STICKYWEB   && side.effects[PBEffects::StickyWeb]
    return true if id == :SPIKES      && side.effects[PBEffects::Spikes] >= 3
    return true if id == :TOXICSPIKES && side.effects[PBEffects::ToxicSpikes] >= 2
    # screens / Substitute / traps / Perish Song already in place
    mine = user.pbOwnSide
    return true if id == :LIGHTSCREEN && mine.effects[PBEffects::LightScreen] > 0
    return true if id == :REFLECT     && mine.effects[PBEffects::Reflect] > 0
    return true if id == :SUBSTITUTE  && user.effects[PBEffects::Substitute] > 0
    return true if id == :PERISHSONG  && target.effects[PBEffects::PerishSong] > 0
    return true if id == :MEANLOOK    && target.effects[PBEffects::MeanLook] >= 0
    return true if id == :AQUARING    && user.effects[PBEffects::AquaRing]
    return true if id == :INGRAIN     && user.effects[PBEffects::Ingrain]
    # Trick Room while it is already up would switch it OFF
    return true if id == :TRICKROOM && @battle.field.effects[PBEffects::TrickRoom] > 0
    false
  rescue StandardError
    false
  end

  #=============================================================================
  # sidmod: BEAM SEARCH over an abstract state.
  #
  # State (plain Array, cheap to copy):
  #   [my_hp, their_hp, my_off, their_off, my_res, their_res, my_statused, their_statused]
  # my_off / their_off fold stat stages into a single damage multiplier; my_res /
  # their_res are HP-per-turn residual deltas (negative = losing HP).
  #
  # Our side branches (beam width); the opponent is modelled greedily as "use the
  # best attack available", which is what it almost always does. Depth is in FULL
  # turns, so BEAM_DEPTH 2 = our move, their reply, our move, their reply.
  #=============================================================================

  # One-time-per-decision table of what each of our moves does, so the search itself
  # never calls the damage code again.
  def sidmod_action_table(user, target, ctx, skill)
    acts = []
    user.eachMoveWithIndex do |m, i|
      next if !@battle.pbCanChooseMove?(user.index, i, false)
      next if sidmod_will_fail?(user, target, m)
      if m.damagingMove?
        _raw, expected, = sidmod_move_damage(m, user, target, skill)
        acts << { idx: i, kind: :attack, dmg: expected.to_f, heal: 0.0, boost: 0,
                  chip: 0.0, burn: false }
      elsif m.healingMove?
        heal = (m.pbHealAmount(user) rescue (user.totalhp / 2.0).round).to_f
        acts << { idx: i, kind: :heal, dmg: 0.0, heal: heal, boost: 0, chip: 0.0, burn: false }
      elsif SmartAI::CHIP_MOVES.include?(m.id)
        # poison/burn/seed put the foe on a clock; burn also halves its physical output
        acts << { idx: i, kind: :chip, dmg: 0.0, heal: 0.0, boost: 0,
                  chip: target.totalhp / 8.0, burn: (m.id == :WILLOWISP) }
      else
        # treat any other status move that the vanilla scorer liked as a 1-stage boost
        stages = 0
        begin
          stages = 1 if m.function && m.statusMove?
        rescue StandardError
          stages = 0
        end
        acts << { idx: i, kind: :other, dmg: 0.0, heal: 0.0, boost: stages,
                  chip: 0.0, burn: false }
      end
    end
    acts
  end

  def sidmod_beam_eval(st, my_max, their_max)
    mine  = [st[0], 0.0].max / my_max
    theirs = [st[1], 0.0].max / their_max
    v = (1.0 - theirs) - (1.0 - mine)
    v += 1.2 if st[1] <= 0            # they are down
    v -= 1.5 if st[0] <= 0            # we are down (worse than killing them is good)
    v += 0.15 * (st[2] - 1.0)         # retained offensive boosts have value
    v += 0.10 if st[7]                # they are statused (clock running)
    v
  end

  # Advance one full turn. Returns the new state.
  def sidmod_beam_step(st, act, their_dpt, user_first, my_max, their_max)
    s = st.dup
    apply_ours = lambda do
      s[1] -= act[:dmg] * s[2] if act[:dmg] > 0
      s[0] = [s[0] + act[:heal], my_max].min if act[:heal] > 0
      if act[:chip] > 0 && !s[7]
        s[7] = true
        s[5] -= act[:chip]
        s[3] *= 0.5 if act[:burn]
      end
      s[2] = [s[2] * (SmartAI::BEAM_BOOST_STEP**act[:boost]), SmartAI::BEAM_BOOST_CAP].min if act[:boost] > 0
    end
    apply_theirs = lambda { s[0] -= their_dpt * s[3] }
    if user_first
      apply_ours.call
      apply_theirs.call if s[1] > 0
    else
      apply_theirs.call
      apply_ours.call if s[0] > 0
    end
    s[0] += s[4]   # residual ticks at end of turn
    s[1] += s[5]
    s[0] = [s[0], my_max].min
    s[1] = [s[1], their_max].min
    s
  end

  # Returns { move_index => beam value in roughly -2.5..+2.5 }
  def sidmod_beam_values(user, target, ctx, skill)
    acts = sidmod_action_table(user, target, ctx, skill)
    return {} if acts.empty?
    my_max    = user.totalhp.to_f
    their_max = target.totalhp.to_f
    root = [user.hp.to_f, target.hp.to_f, 1.0, 1.0,
            ctx[:my_resid].to_f, ctx[:their_resid].to_f, false, target.status != :NONE]
    # sidmod: predicted pivot. Evaluated as a SECOND scenario against the mon they are
    # likely to bring in - our move's damage recomputed against THAT mon, so a move it
    # is immune to shows up as worthless - then blended by probability.
    out = {}
    acts.each do |a|
      st = sidmod_beam_step(root, a, ctx[:their_dpt], ctx[:user_first], my_max, their_max)
      # then continue with a narrow beam of our best follow-ups
      beam = [st]
      (SmartAI.tune(user.index % 2, :beam_depth, SmartAI::BEAM_DEPTH) - 1).times do
        nxt = []
        beam.each do |b|
          next if b[0] <= 0 || b[1] <= 0        # terminal
          acts.each do |a2|
            nxt << sidmod_beam_step(b, a2, ctx[:their_dpt], ctx[:user_first], my_max, their_max)
          end
        end
        break if nxt.empty?
        beam = nxt.sort_by { |x| -sidmod_beam_eval(x, my_max, their_max) }
                  .first(SmartAI.tune(user.index % 2, :beam_width, SmartAI::BEAM_WIDTH))
      end
      best = beam.map { |x| sidmod_beam_eval(x, my_max, their_max) }.max
      best ||= sidmod_beam_eval(st, my_max, their_max)
      out[a[:idx]] = best
    end
    out
  rescue StandardError
    {}
  end

  #=============================================================================
  # sidmod: ANALYTIC 1-STEP PREVIEW - "what does the board look like after this?"
  # Pure arithmetic on numbers already in ctx, so it costs nothing measurable (a
  # cloned search node costs 2.6 ms; this costs microseconds).
  #   they_hp_after / my_hp_after : projected HP after our action and their reply
  #   leaves_nothing              : action has no lasting effect if we die doing it
  #=============================================================================
  def sidmod_preview(user, target, move, ctx, expected_dmg)
    they_after = target.hp - expected_dmg
    heal = 0.0
    if move.healingMove?
      heal = (move.pbHealAmount(user) rescue (user.totalhp / 2.0).round).to_f
      heal = [heal, user.totalhp - user.hp].min
    end
    # their reply lands unless our action kills them first (or we are slower anyway)
    reply = (they_after <= 0 && ctx[:user_first]) ? 0.0 : ctx[:their_dpt]
    my_after = user.hp + heal - reply + ctx[:my_resid]
    # Does the action leave anything behind if we faint doing it? Hazards, status,
    # chip and pivots persist; a plain attack that neither KOs nor breaks a sub does not.
    lasting = move.healingMove? ||
              SmartAI::CHIP_MOVES.include?(move.id) ||
              %i[STEALTHROCK SPIKES TOXICSPIKES STICKYWEB].include?(move.id) ||
              move.function == "0EE" ||                # U-turn / Volt Switch
              (expected_dmg >= target.hp * 0.4)        # a real dent counts
    { they_after: they_after, my_after: my_after,
      they_die: they_after <= 0, we_die: my_after <= 0, leaves_nothing: !lasting }
  end

  # Would a stat boost actually convert into a kill soon? A boost that still does
  # not threaten the foe is a wasted turn; +1 is ~1.5x and +2 ~2x on the attack stat.
  def sidmod_setup_converts?(user, target, ctx, stages)
    return true if ctx[:my_dpt] <= 0
    mult = 1.0 + (0.5 * [stages, 1].max)
    projected = ctx[:my_dpt] * mult
    return true if projected <= 0
    (target.hp / projected).ceil <= SmartAI::SETUP_CONVERT_MIN
  end

  #=============================================================================
  # sidmod: recovery moves get their own model instead of the generic status path
  #=============================================================================
  def sidmod_score_heal(user, move, score, ctx)
    missing = user.totalhp - user.hp
    sup = SmartAI.feature?(user.index % 2, :suppress)
    return (sup ? score * SmartAI::HEAL_DOOMED_MULT : score) if ctx[:doomed]
    if missing < user.totalhp * SmartAI::HEAL_MIN_MISSING
      return sup ? score * SmartAI::HEAL_FULL_MULT : score
    end
    heal = (move.pbHealAmount(user) rescue (user.totalhp / 2.0).round).to_f
    heal = [heal, missing].min
    return score * SmartAI::HEAL_FULL_MULT if heal <= 0
    # HP we actually lose per turn: their attack plus our own residual drain
    incoming = ctx[:their_dpt] - ctx[:my_resid]
    incoming = 0.5 if incoming < 0.5
    if heal > incoming * 1.05
      score += SmartAI::HEAL_OUTPACE_BONUS
      # they are on a clock and we are not: healing IS the win condition
      score += SmartAI::ATTRITION_BONUS if ctx[:their_resid] < 0
    elsif heal >= incoming * 0.6
      score += SmartAI::HEAL_SURVIVE_BONUS
    end
    score *= SmartAI::REST_MULT if move.id == :REST
    score
  end

  #=============================================================================
  # Strategic repricing of a vanilla move score
  #=============================================================================
  def sidmod_reprice_move(user, target, move, score, ctx, skill)
    if SmartAI.feature?(user.index % 2, :noop) && sidmod_will_fail?(user, target, move)
      return 0   # sidmod: never spend a turn on a no-op
    end
    sup = SmartAI.feature?(user.index % 2, :suppress)   # sim: additive-only variant
    if move.damagingMove?
      raw, _expected, acc = sidmod_move_damage(move, user, target, skill)
      lowKill   = (raw * SmartAI::LOW_ROLL >= target.hp)
      firstWith = (move.priority > 0) || ctx[:user_first]
      if lowKill
        score += (firstWith ? SmartAI::KO_FIRST_BONUS : SmartAI::KO_SLOW_BONUS) * acc / 100.0
        # Prefer the weakest move that still KOs (accuracy/PP-friendly, Reborn-style)
        overkill = (raw * SmartAI::LOW_ROLL / target.hp) - 1.0
        score -= [overkill * 20, SmartAI::OVERKILL_PENALTY].min if overkill > 0
      end
      if ctx[:doomed] && move.priority > 0 && !lowKill
        score += SmartAI::PRIORITY_SAVE
      end
      # sidmod: reward raw expected damage as a fraction of what the foe has left, so
      # a resisted move never outranks a harder-hitting neutral one on secondary-effect
      # score alone. Only when no KO is available - a KO already dominates.
      if !lowKill && SmartAI.feature?(user.index % 2, :dmg_weight) && target.hp > 0
        score += SmartAI::DMG_WEIGHT * [_expected.to_f / target.hp, 1.0].min
      end
      # Losing the race: pivot moves (U-turn/Volt Switch) keep momentum
      if move.function == "0EE" && ctx[:edge] < 0
        score += SmartAI::PIVOT_LOSING
      end
      # Our action probably never happens (KOed first, no priority)
      score *= SmartAI::DOOMED_MULT if sup && ctx[:doomed] && move.priority <= 0
      # sidmod: preview the resulting board. Dying to land an attack that neither KOs
      # nor leaves anything behind is the most bot-like thing a planner can do, and
      # DOOMED_MULT only catches the narrower case of being OHKOd before we act.
      if SmartAI.feature?(user.index % 2, :preview)
        pv = sidmod_preview(user, target, move, ctx, _expected)
        score *= SmartAI::SUICIDE_MULT if sup && pv[:we_die] && !pv[:they_die] && pv[:leaves_nothing]
        # sidmod v5: and it is worse still if the mon dying is the only thing we have
        # that answers one of their real threats.
        if sup && SmartAI.feature?(user.index % 2, :team) && pv[:we_die] && !pv[:they_die]
          tv = sidmod_team_view(user.index, user)
          score *= SmartAI::PRESERVE_SACK_MULT if tv[:scarce].key?(user.pokemonIndex)
        end
      end
    elsif move.healingMove? && SmartAI.feature?(user.index % 2, :heal)
      # sidmod: healing is NOT a generic status move. Scored against the clock it
      # actually affects (incoming damage per turn) instead of being suppressed by
      # STATUS_TIGHT_MULT while we are losing - which is precisely when we heal.
      score = sidmod_score_heal(user, move, score, ctx)
    else
      # Status/setup moves, judged by the race clock
      if ctx[:my_ko] && ctx[:user_first]
        score *= SmartAI::STATUS_KILL_MULT if sup      # just take the KO
      elsif ctx[:doomed]
        score *= 0.1 if sup                     # dead mon walking
      elsif ctx[:their_ttk] <= 2 || ctx[:their_ttk] < ctx[:my_ttk]
        score *= SmartAI::STATUS_TIGHT_MULT if sup  # losing/tight race: attack instead
      elsif ctx[:their_ttk] >= 4 || (ctx[:their_ttk] >= 3 && ctx[:user_first])
        # Safe window; vanilla score > 100 means its effect handler liked it.
        # HP gate: don't invest boost turns on a chipped-down mon.
        if score > 100 && user.hp >= user.totalhp * SmartAI::SETUP_HP_FRACTION
          score *= SmartAI::SETUP_SAFE_MULT
          # sidmod: preview whether the boost CONVERTS. Setting up against a foe we
          # still can't threaten afterwards just donates the turn.
          if SmartAI.feature?(user.index % 2, :setup_convert) &&
             !sidmod_setup_converts?(user, target, ctx, 1)
            score *= SmartAI::SETUP_NOCONVERT if sup
          end
        end
      end
      # sidmod: a foe we are not out-racing must be put on a clock, or we just lose to
      # it. Applied AFTER the multipliers above so the tight-race penalty can't erase
      # it. Measured failure this fixes: a bulky mon holding Toxic spammed a 4HKO
      # attack into a Bulk Up sweeper for four turns and died without ever statusing
      # it. The old gate only fired at TTK_CAP (literally unable to damage the foe).
      if SmartAI.feature?(user.index % 2, :chip) &&
         SmartAI::CHIP_MOVES.include?(move.id) && !ctx[:doomed] && !ctx[:my_ko]
        fresh = if move.id == :LEECHSEED
                  target.effects[PBEffects::LeechSeed] < 0 && !target.pbHasType?(:GRASS)
                else
                  target.status == :NONE
                end
        losing   = ctx[:their_ttk] <= ctx[:my_ttk]   # we do not win the straight race
        slow_kill = ctx[:my_ttk] >= 4                # too slow to race even if ahead
        if fresh && (losing || slow_kill)
          score += SmartAI::CHIP_STATUS_BONUS
          # A foe that is setting up gets worse every turn: status it NOW.
          boosts = 0
          begin
            %i[ATTACK SPECIAL_ATTACK SPEED DEFENSE SPECIAL_DEFENSE].each do |st|
              v = target.stages[st].to_i
              boosts += v if v > 0
            end
          rescue StandardError
            boosts = 0
          end
          score += SmartAI::CHIP_SETUP_BONUS if boosts > 0
        end
      end
      # sidmod: a boosting foe is answered by removing the boosts, not by chipping it.
      if SmartAI.feature?(user.index % 2, :phaze) &&
         (SmartAI::PHAZE_MOVES.include?(move.id) || SmartAI::FORCEOUT_MOVES.include?(move.id))
        fboosts = 0
        begin
          %i[ATTACK SPECIAL_ATTACK SPEED DEFENSE SPECIAL_DEFENSE].each do |st|
            v = target.stages[st].to_i
            fboosts += v if v > 0
          end
        rescue StandardError
          fboosts = 0
        end
        if fboosts > 0 && !(ctx[:my_ko] && ctx[:user_first])
          score += [fboosts * SmartAI::PHAZE_BOOST_BONUS, SmartAI::PHAZE_BOOST_CAP].min
        end
      end
      # sidmod: Protect banks residual damage the foe is already taking, but two in
      # a row mostly fail.
      if SmartAI::PROTECT_MOVES.include?(move.id)
        if user.effects[PBEffects::ProtectRate] > 1
          score *= SmartAI::PROTECT_SPAM_MULT if sup
        elsif ctx[:their_resid] < 0 && !ctx[:my_ko]
          score += SmartAI::PROTECT_CHIP_BONUS
        end
      end
    end
    return score
  end

  #=============================================================================
  # Switch plans
  #=============================================================================
  def sidmod_add_switch_choices(idxBattler, user, target, ctx, choices, bestMoveScore)
    return if user.turnCount < 1 && bestMoveScore >= SmartAI::BAD_MOVES_SCORE   # just came in
    return if @battle.pbAbleNonActiveCount(user.idxOwnSide) == 0
    forced  = (user.effects[PBEffects::PerishSong] == 1)
    trouble = (bestMoveScore < SmartAI::BAD_MOVES_SCORE)   # encored/taunted/out of options
    # sidmod v5: team-level reasons to leave, which a 1v1 scorer cannot see
    team_out = 0
    if SmartAI.feature?(idxBattler % 2, :team)
      tv = sidmod_team_view(idxBattler, user)
      # we are the ONLY answer to one of their live threats and we are about to die
      if tv[:scarce].key?(user.pokemonIndex) && (ctx[:their_ttk] <= 1 || ctx[:doomed])
        team_out += SmartAI::PRESERVE_ANSWER
      end
      # we are a boosted win condition about to be revenge-killed: save it
      pos = 0
      user.stages.each_value { |v| pos += v if v > 0 }
      if pos >= SmartAI::WINCON_STAGES && (ctx[:their_ttk] <= 1 || ctx[:doomed]) && !ctx[:my_ko]
        team_out += SmartAI::WINCON_PRESERVE
      end
    end
    # Boost inertia: never voluntarily throw away accumulated setup
    posStages = 0
    user.stages.each_value { |v| posStages += v if v > 0 }
    return if posStages >= SmartAI::BOOST_STAGES_STAY && !forced && !trouble && team_out <= 0
    party = @battle.pbParty(idxBattler)
    party.each_with_index do |pkmn, i|
      next if !pkmn || pkmn.egg? || pkmn.fainted?
      next if i == user.pokemonIndex
      next if !@battle.pbCanSwitch?(idxBattler, i)
      m = sidmod_party_matchup(pkmn, target)
      # Candidate eats a free hit on the way in -> loses one race turn
      candEdge = (m[:their_ttk] - 1) - m[:my_ttk] + (m[:fast] ? 0.5 : -0.5)
      if forced || trouble || team_out > 0
        score = SmartAI::SWITCH_BASE + (candEdge * SmartAI::SWITCH_EDGE_SCALE) + team_out
        score += 500 if forced
        next if !forced && m[:their_ttk] - 1 <= 1 && team_out > 0 && !trouble  # don't just feed it
      else
        next if m[:their_ttk] - 1 <= 1                          # would come in and die
        next if candEdge < ctx[:edge] + SmartAI::SWITCH_MIN_GAIN # must clearly improve
        next if ctx[:my_ko] && ctx[:user_first]                  # we have the KO; take it
        score = SmartAI::SWITCH_BASE + ((candEdge - ctx[:edge]) * SmartAI::SWITCH_EDGE_SCALE)
      end
      score = SmartAI::SWITCH_CAP if score > SmartAI::SWITCH_CAP
      choices.push([:switch, i, -1, score.to_i]) if score > 0
    end
  end

  # sidmod: best expected hit of one PARTY pokemon on another, type-aware, no battler
  # required. Used to work out which of our mons actually answers which of theirs.
  def sidmod_pkmn_vs_pkmn(atk, def_)
    best = 1.0
    dTypes = def_.types
    dAb = (def_.ability_id rescue nil)
    atk.moves.each do |m|
      next if !m || m.category == 2 || m.base_damage <= 0
      mt = m.type
      tm = Effectiveness.calculate(mt, dTypes[0], dTypes[1]).to_f / Effectiveness::NORMAL_EFFECTIVE
      next if tm == 0
      if dAb
        need = SmartAI::ABILITY_IMMUNE_TYPE[dAb]
        next if need && need == mt
        next if dAb == :WONDERGUARD && tm <= 1.0
      end
      power = m.base_damage
      power = 60 if power == 1
      phys = (m.category == 0)
      a = phys ? atk.attack : atk.spatk
      d = phys ? def_.defense : def_.spdef
      stab = atk.hasType?(mt) ? 1.5 : 1.0
      dmg = ((((2.0 * atk.level / 5) + 2) * power * a / [d, 1].max) / 50 + 2) * stab * tm * 0.925
      best = dmg if dmg > best
    end
    best
  rescue StandardError
    1.0
  end

  #=============================================================================
  # sidmod: TEAM-LEVEL VIEW. Computed once per decision and cached, because it walks
  # both parties (ours x theirs) and that is the only expensive part.
  #   threats  = their mons that beat 2+ of ours in a straight race
  #   answers  = for each threat, how many of our mons beat it
  # A mon that is the SOLE answer to a live threat is scarce: do not trade it for
  # nothing, and pull it out rather than let it die pointlessly.
  #=============================================================================
  def sidmod_team_view(idxBattler, user)
    key = [idxBattler, @battle.turnCount]
    @sidmod_tv_cache ||= {}
    return @sidmod_tv_cache[key] if @sidmod_tv_cache.key?(key)
    ours   = @battle.pbParty(idxBattler)
    theirs = @battle.pbParty(user.pbDirectOpposing(true).index)
    foe_active = user.pbDirectOpposing(true)
    # who on their side is a problem for us, and who of ours handles it
    answers_for = {}
    theirs.each_with_index do |tp, ti|
      next if !tp || tp.egg? || tp.fainted?
      beats_us = 0
      answers  = []
      ours.each_with_index do |op, oi|
        next if !op || op.egg? || op.fainted?
        # reuse the active-battler estimator when the foe mon IS the active one
        m = (tp == foe_active.pokemon rescue false) ? sidmod_party_matchup(op, foe_active) : nil
        if m
          we_win = (m[:my_ttk] < m[:their_ttk]) || (m[:my_ttk] == m[:their_ttk] && m[:fast])
        else
          a = sidmod_pkmn_vs_pkmn(op, tp)   # our mon hitting theirs
          b = sidmod_pkmn_vs_pkmn(tp, op)   # theirs hitting ours
          ttk_us   = (tp.hp / [a, 1.0].max).ceil
          ttk_them = (op.hp / [b, 1.0].max).ceil
          we_win = (ttk_us < ttk_them) ||
                   (ttk_us == ttk_them && sidmod_outspeeds?(op.speed, tp.speed))
        end
        we_win ? answers << oi : beats_us += 1
      end
      answers_for[ti] = { beats_us: beats_us, answers: answers }
    end
    threats = answers_for.select { |_ti, v| v[:beats_us] >= SmartAI::TEAM_ANSWER_MIN }
    # our mons that are the ONLY answer to some live threat
    scarce = {}
    threats.each do |ti, v|
      next if v[:answers].length != 1
      scarce[v[:answers].first] = ti
    end
    tv = { threats: threats.keys, scarce: scarce }
    @sidmod_tv_cache = { key => tv }   # single-entry cache: only this turn matters
    tv
  rescue StandardError
    { threats: [], scarce: {} }
  end

  # Race numbers for a benched party Pokemon vs the active foe battler.
  def sidmod_party_matchup(pkmn, foe)
    lvl = pkmn.level
    # --- our best hit on them ---
    bestOff = 1.0
    pkmn.moves.each do |m|
      next if !m || m.category == 2 || m.base_damage <= 0
      power = m.base_damage
      power = 60 if power == 1   # fixed-damage placeholder, same as vanilla
      atk = (m.category == 0) ? pkmn.attack : pkmn.spatk
      df  = (m.category == 0) ? pbRoughStat(foe, :DEFENSE, 100) : pbRoughStat(foe, :SPECIAL_DEFENSE, 100)
      fTypes = foe.pbTypes(true)
      typeMod = Effectiveness.calculate(m.type, fTypes[0], fTypes[1], fTypes[2]).to_f /
                Effectiveness::NORMAL_EFFECTIVE
      stab = pkmn.hasType?(m.type) ? 1.5 : 1.0
      dmg = ((((2.0 * lvl / 5) + 2) * power * atk / [df, 1].max) / 50 + 2) * stab * typeMod * 0.925
      bestOff = dmg if dmg > bestOff
    end
    # --- their best hit on us ---
    bestIn = 1.0
    pTypes = pkmn.types
    foe.eachMove do |m|
      next if !m.damagingMove?
      mType = m.type
      next if mType == :GROUND &&
              (pTypes.include?(:FLYING) || pkmn.ability_id == :LEVITATE)
      typeMod = Effectiveness.calculate(mType, pTypes[0], pTypes[1]).to_f /
                Effectiveness::NORMAL_EFFECTIVE
      next if typeMod == 0
      power = m.baseDamage
      power = 60 if power == 1
      atk = m.physicalMove?(mType) ? pbRoughStat(foe, :ATTACK, 100) : pbRoughStat(foe, :SPECIAL_ATTACK, 100)
      df  = m.physicalMove?(mType) ? pkmn.defense : pkmn.spdef
      stab = foe.pbHasType?(mType) ? 1.5 : 1.0
      dmg = ((((2.0 * foe.level / 5) + 2) * power * atk / [df, 1].max) / 50 + 2) * stab * typeMod * 0.925
      bestIn = dmg if dmg > bestIn
    end
    # --- entry hazards shave effective HP ---
    ehp = pkmn.hp - sidmod_hazard_damage(pkmn, @battle.battlers[foe.index].pbOpposingSide)
    ehp = 1 if ehp < 1
    myTTK    = [(foe.hp / bestOff).ceil, SmartAI::TTK_CAP].min
    theirTTK = [(ehp    / bestIn).ceil,  SmartAI::TTK_CAP].min
    fast = sidmod_outspeeds?(pkmn.speed, foe.pbSpeed)
    return { my_ttk: myTTK, their_ttk: theirTTK, fast: fast }
  end

  def sidmod_hazard_damage(pkmn, side)
    dmg = 0
    if side.effects[PBEffects::StealthRock]
      types = pkmn.types
      typeMod = Effectiveness.calculate(:ROCK, types[0], types[1]).to_f /
                Effectiveness::NORMAL_EFFECTIVE
      dmg += (pkmn.totalhp * typeMod / 8).floor
    end
    spikes = side.effects[PBEffects::Spikes]
    if spikes > 0 && !pkmn.types.include?(:FLYING) && pkmn.ability_id != :LEVITATE
      dmg += (pkmn.totalhp / [8, 6, 4][spikes - 1]).floor
    end
    return dmg
  end

  #=============================================================================
  # Replacement after a faint: pick by race quality, prefer revenge killers
  #=============================================================================
  alias sidmod_vanilla_pbChooseBestNewEnemy pbChooseBestNewEnemy
  def pbChooseBestNewEnemy(idxBattler, party, enemies)
    if !sidmod_smart_ai?(idxBattler)
      return sidmod_vanilla_pbChooseBestNewEnemy(idxBattler, party, enemies)
    end
    return -1 if !enemies || enemies.length == 0
    foe = @battle.battlers[idxBattler].pbDirectOpposing(true)
    if foe.fainted?
      return sidmod_vanilla_pbChooseBestNewEnemy(idxBattler, party, enemies)
    end
    best, bestScore = -1, nil
    enemies.each do |i|
      m = sidmod_party_matchup(party[i], foe)
      score = (m[:their_ttk] - m[:my_ttk]) + (m[:fast] ? 0.5 : -0.5)
      score += 2 if m[:fast] && m[:my_ttk] <= 1   # revenge kill available
      # sidmod: do not send a mon into a free KO. Measured failure: the planner kept
      # picking send-ins that the active foe outspeeds and one-shots, turning every
      # replacement into fodder.
      if SmartAI.feature?(idxBattler % 2, :repl_safe) && !m[:fast] && m[:their_ttk] <= 1
        score -= SmartAI::REPL_OHKO_PENALTY
      end
      if bestScore.nil? || score > bestScore
        best, bestScore = i, score
      end
    end
    PBDebug.log("[SmartAI] replacement pick: #{party[best].name} (score #{bestScore})") if best >= 0
    return (best >= 0) ? best : sidmod_vanilla_pbChooseBestNewEnemy(idxBattler, party, enemies)
  end
end
