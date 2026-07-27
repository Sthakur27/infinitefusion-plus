# LEAD SELECTION. Which of a team's six should be in slot 0 (the engine sends
# party[0] out first). Combines rule-based archetype logic with a measured signal.
#
#   Lead.choose(keys, meta, lead_stats) -> [ordered_keys, reason]
#
# Rule order and why each rule exists:
#  1. WEATHER SETTER, if the team actually abuses weather. Weather abilities resolve
#     on entry and the SLOWEST setter's ability lands LAST, so leading your setter
#     wins the weather war even against a faster opposing setter.
#  2. HAZARD SETTER. Stealth Rock on turn 1 taxes every switch for the rest of the
#     battle; earlier is strictly better.
#  3. FREE-SETUP SWEEPER. A setup move plus something that guarantees a free turn
#     (Disguise blocks a hit outright, Multiscale halves it, Focus Sash survives it,
#     Speed Boost/Contrary turn the turn into profit) — the "surprise sweeper" lead.
#  4. PIVOT. U-turn/Volt Switch leads scout and hand momentum to a better matchup.
#  5. Fall back to the measured lead winrate (a mon's winrate in slot 0 versus its
#     winrate elsewhere, computed from the sweep where slot order was random), then
#     Speed as the tiebreak.
#
# `meta[key]` needs: :moves :ability :item :types :stats(6) :roles.
# `lead_stats[key]` is optional: { lead_wr:, other_wr:, lead_games: }.
module Lead
  module_function

  WEATHER_ABILITY = { 'Drizzle' => :rain, 'Drought' => :sun, 'Sand Stream' => :sand,
                      'Snow Warning' => :hail, 'Primordial Sea' => :rain,
                      'Desolate Land' => :sun }
  # abilities that only pay off under a specific weather
  ABUSER = { rain: %w[Swift\ Swim Rain\ Dish Dry\ Skin Hydration],
             sun: %w[Chlorophyll Solar\ Power Leaf\ Guard Flower\ Gift Harvest],
             sand: %w[Sand\ Rush Sand\ Force Sand\ Veil],
             hail: %w[Slush\ Rush Snow\ Cloak Ice\ Body] }
  HAZARD  = ['Stealth Rock', 'Spikes', 'Toxic Spikes', 'Sticky Web']
  SETUP   = ['Swords Dance', 'Dragon Dance', 'Nasty Plot', 'Calm Mind', 'Quiver Dance',
             'Shell Smash', 'Bulk Up', 'Work Up', 'Agility', 'Rock Polish', 'Coil',
             'Hone Claws', 'Belly Drum', 'Tail Glow', 'Growth', 'Shift Gear', 'No Retreat']
  FREE_TURN_ABILITY = ['Disguise', 'Multiscale', 'Speed Boost', 'Contrary', 'Magic Bounce']
  FREE_TURN_ITEM    = ['Focus Sash', 'Focus Band']
  PIVOT   = ['U-turn', 'Volt Switch', 'Flip Turn', 'Parting Shot', 'Teleport', 'Baton Pass']
  # a lead that immediately threatens is better than a passive one
  SUICIDE_OK = ['Taunt', 'Explosion', 'Memento', 'Destiny Bond']

  def has?(m, list); (m[:moves] || []).any? { |x| list.include?(x) }; end
  def speed(m); (m[:stats] || [])[5].to_i; end
  def bulk(m); s = m[:stats] || []; s[0].to_i + s[2].to_i + s[4].to_i; end

  def weather_plan(keys, meta)
    setters = keys.select { |k| WEATHER_ABILITY.key?(meta[k][:ability].to_s) }
    return nil if setters.empty?
    setters.each do |k|
      w = WEATHER_ABILITY[meta[k][:ability].to_s]
      abusers = keys.count { |o| o != k && ABUSER[w].to_a.include?(meta[o][:ability].to_s) }
      return [k, w, abusers] if abusers > 0
    end
    # a setter with no abuser is still worth leading if it is the only weather source
    k = setters.max_by { |x| bulk(meta[x]) }
    [k, WEATHER_ABILITY[meta[k][:ability].to_s], 0]
  end

  def choose(keys, meta, lead_stats = {})
    keys = keys.dup
    pick = nil; reason = nil

    if (wp = weather_plan(keys, meta))
      k, w, n = wp
      pick = k
      reason = n > 0 ? "weather lead: sets #{w} for #{n} abuser#{n == 1 ? '' : 's'} (entry ability, " \
                       "and the slowest setter's weather is the one that sticks)"
                     : "weather lead: only #{w} source on the team"
    end

    if !pick
      haz = keys.select { |k| has?(meta[k], HAZARD) }
      if haz.any?
        # prefer a hazard setter that also threatens or survives: fast, or bulky, or has Taunt
        pick = haz.max_by { |k| [has?(meta[k], SUICIDE_OK) ? 1 : 0, speed(meta[k]) + bulk(meta[k]) / 3] }
        which = (meta[pick][:moves] & HAZARD).first
        reason = "hazard lead: #{which} on turn 1 taxes every switch after it"
      end
    end

    if !pick
      free = keys.select { |k|
        has?(meta[k], SETUP) &&
          (FREE_TURN_ABILITY.include?(meta[k][:ability].to_s) ||
           FREE_TURN_ITEM.include?(meta[k][:item].to_s)) }
      if free.any?
        pick = free.max_by { |k| speed(meta[k]) }
        reason = "setup lead: #{meta[pick][:ability]}#{FREE_TURN_ITEM.include?(meta[pick][:item].to_s) ? "/#{meta[pick][:item]}" : ''} " \
                 "buys a free turn to use #{(meta[pick][:moves] & SETUP).first}"
      end
    end

    if !pick
      piv = keys.select { |k| has?(meta[k], PIVOT) }
      if piv.any?
        pick = piv.max_by { |k| speed(meta[k]) }
        reason = "pivot lead: #{(meta[pick][:moves] & PIVOT).first} scouts then hands off the matchup"
      end
    end

    if !pick
      scored = keys.map { |k|
        st = lead_stats[k]
        edge = st && st[:lead_games].to_i >= 30 ? (st[:lead_wr] - st[:other_wr]) : 0.0
        [k, edge, speed(meta[k])] }
      best = scored.max_by { |(_k, e, sp)| [e, sp / 1000.0] }
      pick = best[0]
      reason = best[1].abs > 0.001 ?
        "measured lead edge %+.3f winrate in slot 0 versus elsewhere" % best[1] :
        "no rule matched; fastest mon leads (Speed #{speed(meta[pick])})"
    end

    ordered = [pick] + keys.reject { |k| k == pick }
    [ordered, reason]
  end

  # Measured lead value per mon, from any games.tsv: slot 0 is the lead, and in the
  # random-team sweep slot order was itself random, so comparing slot 0 against the
  # other slots isolates lead value rather than mon quality.
  def stats_from_games(paths)
    lead = Hash.new { |h, k| h[k] = [0.0, 0] }
    other = Hash.new { |h, k| h[k] = [0.0, 0] }
    paths.each do |p|
      next unless File.exist?(p)
      File.foreach(p) do |line|
        f = line.split("\t")
        next if f.length < 5
        a = f[1].split(','); b = f[2].split(','); w = f[4]
        pa = w == 'a' ? 1.0 : (w == 'b' ? 0.0 : 0.5)
        a.each_with_index { |k, i| (i.zero? ? lead[k] : other[k])[0] += pa; (i.zero? ? lead[k] : other[k])[1] += 1 }
        b.each_with_index { |k, i| (i.zero? ? lead[k] : other[k])[0] += (1 - pa); (i.zero? ? lead[k] : other[k])[1] += 1 }
      end
    end
    keys = (lead.keys + other.keys).uniq
    keys.each_with_object({}) do |k, h|
      lw = lead[k][1] > 0 ? lead[k][0] / lead[k][1] : 0.5
      ow = other[k][1] > 0 ? other[k][0] / other[k][1] : 0.5
      h[k] = { lead_wr: lw, other_wr: ow, lead_games: lead[k][1] }
    end
  end
end
