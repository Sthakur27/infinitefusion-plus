# One-turn LOOKAHEAD policy (RQ1 "beam" AI) for the SimAgent hook.
#
# The current SmartAI scores each move by immediate effect (1-ply). This policy looks a
# full turn ahead: for each candidate action it predicts the post-turn board — respecting
# MOVE ORDER (does my KO land before the foe retaliates?) and whether I survive to act —
# then scores the resulting position with a static eval and picks the argmax. The opponent
# is modeled adversarially as "uses its hardest-hitting move on me" (a minimax proxy).
#
# Reuses SimAgent's engine-consistent est_damage/eff so the lookahead's damage model
# matches what the battles actually use.
#   ruby nlookahead.rb            # self-test: lookahead vs native SmartAI, win rate
require_relative 'agent_battle'
require_relative 'nbattle'

module NLookahead
  module_function

  KO = 300.0            # value of scoring / cost of conceding a KO
  AVG = 0.9             # max-roll est_damage -> ~average damage

  SETUP = %i[SWORDSDANCE DRAGONDANCE NASTYPLOT CALMMIND QUIVERDANCE SHELLSMASH BULKUP WORKUP
             ROCKPOLISH AGILITY AUTOTOMIZE COIL HONECLAWS BELLYDRUM TAILGLOW GROWTH SHIFTGEAR VICTORYDANCE]
  RECOVER = %i[RECOVER ROOST SOFTBOILED MILKDRINK SLACKOFF MORNINGSUN MOONLIGHT SYNTHESIS WISH
               SHOREUP STRENGTHSAP]
  HAZARD  = %i[STEALTHROCK SPIKES TOXICSPIKES STICKYWEB]
  PIVOT   = %i[UTURN VOLTSWITCH FLIPTURN PARTINGSHOT]

  # Board value from side i's view given predicted post-turn HP fractions + KO flags.
  def board(my_frac, foe_frac, my_ko, foe_ko, extra = 0.0)
    v = 100.0 * my_frac - 100.0 * foe_frac
    v += KO if foe_ko
    v -= KO if my_ko
    v + extra
  end

  # Value of a damaging move, predicting the turn given move order.
  def dmg_value(exp_d, faster, my_hp, my_max, foe_hp, foe_max, exp_in)
    if faster
      foe_after = foe_hp - exp_d
      return board(my_hp / my_max, 0.0, false, true) if foe_after <= 0   # KO before retaliation
      my_after = my_hp - exp_in
      board([my_after, 0].max / my_max, foe_after / foe_max, my_after <= 0, false)
    else
      my_after = my_hp - exp_in
      return board(0.0, foe_hp / foe_max, true, false) if my_after <= 0  # KO'd before acting -> deal nothing
      foe_after = foe_hp - exp_d
      board(my_after / my_max, [foe_after, 0].max / foe_max, false, foe_after <= 0)
    end
  end

  # Value of a status/non-damaging move: reward setup only when safe, recovery when hurt,
  # hazards when not already set, pivots modestly. `st` carries the WILL-FAIL no-op flag.
  def status_value(mid, faster, my_hp, my_max, exp_in, will_fail, foe_frac)
    return -50.0 if will_fail                       # no-op turn is actively bad
    frac = my_hp / my_max
    survives_two = exp_in <= my_hp * 0.55           # foe needs 3+ hits -> safe to invest
    if SETUP.include?(mid)
      return survives_two ? 60.0 - 40.0 * foe_frac : -20.0   # setup value decays as foe weakens (just attack)
    elsif RECOVER.include?(mid)
      heal = [my_max - my_hp, my_max * 0.5].min
      return (exp_in >= my_hp ? -30.0 : 20.0 * (heal / my_max) * 100.0 / 100.0 * 2.0)
    elsif HAZARD.include?(mid)
      return 35.0                                   # chip that compounds; will_fail already filtered
    elsif PIVOT.include?(mid)
      return 15.0
    else
      return 8.0                                    # misc status (WoW/Twave/Toxic/screens/Teleport): mild default
    end
  end

  SWITCH_COST = 45.0    # a switch gives the foe a free turn; only worth it for a real swing

  UNRANKED = -9_999.0   # finite sentinel: never let an Infinity into the score comparison,
                        # because best_v.round raises FloatDomainError on +/-Infinity

  # Matchup quality of a bench mon vs the current foe (before the switch cost).
  def switch_value(bench_entry)
    return UNRANKED unless bench_entry
    off  = bench_entry["off"].to_f     # its best move eff vs foe (0..4)
    take = bench_entry["take"].to_f    # how it takes foe STAB (0..4)
    (off >= 2 && take <= 1) ? 40.0 - 25.0 * take : (off - 1) * 12.0 - take * 25.0
  end

  def policy
    lambda do |battle, i, st|
      me  = battle.battlers[i]
      foe = (battle.battlers[i ^ 1] rescue nil) || battle.battlers.find { |b| b && b.index != i }
      return SimAgent.random_policy(battle, i, st) unless me && foe
      faster = (st["speed"] == "FASTER")
      my_hp = me.hp.to_f; my_max = [me.totalhp, 1].max
      foe_hp = foe.hp.to_f; foe_max = [foe.totalhp, 1].max
      foe_frac = foe_hp / foe_max
      # opponent model: their hardest hit on me
      exp_in = AVG * (foe.moves.map { |fm|
        (fm && fm.id && fm.id != :NONE) ? (SimAgent.est_damage(battle, foe, me, fm) rescue 0) : 0
      }.compact.max || 0)

      best = nil; best_v = UNRANKED; best_lbl = nil; best_dmg_v = UNRANKED
      SimAgent.legal_moves(battle, i).each do |mi|
        m = me.moves[mi]
        info = (st["moves"].find { |x| x["idx"] == mi } || {})
        v = if m.category == 2
              will_fail = info["eff"].to_s.include?("WILL-FAIL")
              status_value(m.id, faster, my_hp, my_max, exp_in, will_fail, foe_frac)
            else
              d = (SimAgent.est_damage(battle, me, foe, m) rescue nil).to_i
              if d <= 0
                -60.0   # immune / does nothing this turn -> wasted attacking turn
              else
                dv = dmg_value(AVG * d, faster, my_hp, my_max, foe_hp, foe_max, exp_in)
                best_dmg_v = dv if dv > best_dmg_v
                dv
              end
            end
        if v > best_v; best_v = v; best = [:move, mi]; best_lbl = m.id.to_s; end
      end

      # switch only when the ACTIVE mon is in real trouble (likely KO'd or can't threaten) and
      # the incoming mon is a genuinely better matchup. Costs a turn (SWITCH_COST).
      in_trouble = (exp_in >= my_hp * 0.85) || (best_dmg_v < 15.0)
      if in_trouble
        (st["switches"] || []).each do |sw|
          be = (st["bench"] || []).find { |x| x["name"] == sw["name"] }
          v = switch_value(be) - SWITCH_COST
          if v > best_v; best_v = v; best = [:switch, sw["idx"]]; best_lbl = "switch->#{sw['name']}"; end
        end
      end

      # `best` stays nil only when nothing scored (no usable move, no viable switch) -> defer to
      # the fallback policy. Format defensively: .round raises FloatDomainError on Inf/NaN.
      shown = (best_v.finite? ? best_v.round : 'n/a')
      $SIM_LAST_REASON = best ? "LA #{best_lbl} v=#{shown}" : '(LA: no scored action)'
      best || SimAgent.random_policy(battle, i, st)
    end
  end
end

# ---- self-test: lookahead (side 0) vs native SmartAI (side 1) ----
if __FILE__ == $PROGRAM_NAME
  NativeSim.boot!
  $DEBUG = false
  ou = NativeSim.pool(tier: :ou)
  pick = lambda do |seed|
    chosen = []; used = []
    ou.shuffle(random: Random.new(seed)).each do |e|
      next if (e[:bases] & used).any?
      chosen << e[:key]; used.concat(e[:bases]); break if chosen.length == 6
    end
    chosen
  end
  games = (ARGV[0] || 40).to_i
  la = NLookahead.policy
  wins = { la: 0, native: 0, draw: 0 }
  $SIM_NATIVE_SIDES = [1]   # side 1 = native SmartAI; side 0 = lookahead policy
  noop = ->(battle, i, st) { SimAgent.random_policy(battle, i, st) }   # side 1 is native; unused
  games.times do |g|
    a = NativeSim.party(pick.(100 + g)); b = NativeSim.party(pick.(500 + g))
    dec, _log = SimAgent.run(a, b, la, noop, seed: g + 1, cap: 300) rescue [5, []]
    wins[dec == 1 ? :la : dec == 2 ? :native : :draw] += 1
  end
  tot = wins[:la] + wins[:native]
  puts "LOOKAHEAD vs NATIVE SmartAI over #{games} games:"
  puts "  lookahead #{wins[:la]}  native #{wins[:native]}  draw #{wins[:draw]}"
  puts "  lookahead win rate (decisive): #{tot > 0 ? '%.1f%%' % (100.0 * wins[:la] / tot) : 'n/a'}"
end
