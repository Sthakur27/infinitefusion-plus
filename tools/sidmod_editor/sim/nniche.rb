# NICHE CLASSIFICATION — the anti-monoculture backbone.
#
# A team's niche is derived from what it actually CONTAINS, never from the label of
# the generator that produced it. That distinction matters: mutation and crossover
# happily strip the Drizzle setter off a "rain" team, leaving a team that is still
# tagged rain while playing generic offense. Classifying from composition means a
# team that stops executing its plan also stops occupying that plan's protected slot.
#
#   Niche.classify(keys, meta) -> "rain" | "sand" | ... | "generic"
#   Niche.core(keys, meta)     -> indices that DEFINE the niche (protect during mutation)
module Niche
  # order matters: the most identity-defining plans are tested first
  LIST = %w[rain sun sand hail trickroom stall hazardstack scarf bulkysetup balance
            priority hyperoffense generic].freeze

  SETTER = { 'Drizzle' => 'rain', 'Primordial Sea' => 'rain',
             'Drought' => 'sun',  'Desolate Land' => 'sun',
             'Sand Stream' => 'sand', 'Snow Warning' => 'hail' }
  ABUSER = { 'rain' => %w[Swift\ Swim Rain\ Dish Dry\ Skin Hydration],
             'sun'  => %w[Chlorophyll Solar\ Power Leaf\ Guard Flower\ Gift Harvest],
             'sand' => %w[Sand\ Rush Sand\ Force Sand\ Veil],
             'hail' => %w[Slush\ Rush Snow\ Cloak Ice\ Body] }
  HAZARD  = ['Stealth Rock', 'Spikes', 'Toxic Spikes', 'Sticky Web']
  RECOVER = ['Recover', 'Roost', 'Soft-Boiled', 'Slack Off', 'Synthesis', 'Moonlight',
             'Morning Sun', 'Rest', 'Wish', 'Shore Up', 'Strength Sap', 'Leech Seed']
  SETUP   = ['Swords Dance', 'Dragon Dance', 'Nasty Plot', 'Calm Mind', 'Quiver Dance',
             'Shell Smash', 'Bulk Up', 'Work Up', 'Agility', 'Rock Polish', 'Coil',
             'Hone Claws', 'Belly Drum', 'Tail Glow', 'Growth', 'Shift Gear', 'No Retreat']
  PHAZE   = ['Whirlwind', 'Roar', 'Dragon Tail', 'Circle Throw', 'Haze', 'Clear Smog']
  PRIORITY = ['Extreme Speed', 'Aqua Jet', 'Bullet Punch', 'Ice Shard', 'Shadow Sneak',
              'Sucker Punch', 'Mach Punch', 'Vacuum Wave', 'Accelerock', 'Jet Punch',
              'First Impression', 'Quick Attack', 'Fake Out']

  module_function

  def mv(meta, k); (meta[k] && meta[k][:moves]) || []; end
  def ab(meta, k); (meta[k] && meta[k][:ability]).to_s; end
  def it(meta, k); (meta[k] && meta[k][:item]).to_s; end
  def st(meta, k); (meta[k] && meta[k][:stats]) || [0, 0, 0, 0, 0, 0]; end
  def bulky?(meta, k); s = st(meta, k); s[0].to_i >= 330 && (s[2].to_i >= 240 || s[4].to_i >= 240); end
  def slow?(meta, k); st(meta, k)[5].to_i <= 190; end

  # returns [weather, setter_key, abuser_count] or nil
  def weather_of(keys, meta)
    best = nil
    keys.each do |k|
      w = SETTER[ab(meta, k)] or next
      n = keys.count { |o| o != k && ABUSER[w].include?(ab(meta, o)) }
      cand = [w, k, n]
      best = cand if best.nil? || n > best[2]
    end
    best
  end

  def classify(keys, meta)
    if (w = weather_of(keys, meta))
      # a lone setter with no payoff mon is not a weather TEAM; it is incidental
      return w[0] if w[2] >= 1
    end
    tr = keys.select { |k| mv(meta, k).include?('Trick Room') }
    return 'trickroom' if tr.any? && keys.count { |k| slow?(meta, k) } >= 3

    # a wall is bulk plus a way to undo damage OR reset the opponent's progress;
    # recovery-only was narrower than every builder's notion of defensive
    defensive = keys.count { |k| bulky?(meta, k) && ((mv(meta, k) & RECOVER).any? ||
                                                    (mv(meta, k) & PHAZE).any?) }
    offense   = keys.count { |k| (mv(meta, k) & SETUP).any? || it(meta, k) =~ /Life Orb|Choice/ }
    # hazard-stack and stall both run bulky hazard setters; what separates them is
    # whether anything on the team is trying to WIN with the chip damage. Checked
    # before stall, or a 3-hazard pressure team is filed as stall and the niche never
    # populates.
    hazards = keys.count { |k| (mv(meta, k) & HAZARD).any? }
    return 'hazardstack' if hazards >= 3 && offense >= 2
    return 'stall' if defensive >= 3 && offense <= 2

    # ORDER AND THRESHOLDS MATTER. "priority" used to sit here with a >=3 threshold and
    # swallowed almost everything — this pool is saturated with Extreme Speed / Aqua Jet
    # / Bullet Punch, so 71 of 100 teams on the first ladder classified as priority and
    # the niches carried no information. Specific, hard-to-satisfy plans are tested
    # first; priority now needs FOUR users to count as the team's identity.
    return 'hazardstack' if hazards >= 3
    return 'scarf'       if keys.count { |k| it(meta, k) == 'Choice Scarf' } >= 3
    return 'bulkysetup'  if keys.count { |k| (mv(meta, k) & SETUP).any? &&
                                            (bulky?(meta, k) || (mv(meta, k) & RECOVER).any?) } >= 3
    return 'balance'     if defensive >= 2 && offense >= 2
    return 'priority'    if keys.count { |k| (mv(meta, k) & PRIORITY).any? } >= 4
    return 'hyperoffense' if keys.count { |k| (mv(meta, k) & SETUP).any? } >= 4 ||
                            keys.count { |k| it(meta, k) =~ /Life Orb|Choice Band|Choice Specs/ } >= 4
    'generic'
  end

  # Slots that make the team ITS niche. Mutation must not touch these, or a rain team
  # quietly becomes a generic offense team while still holding a rain-reserved slot.
  def core(keys, meta)
    n = classify(keys, meta)
    idx = []
    case n
    when 'rain', 'sun', 'sand', 'hail'
      w = weather_of(keys, meta)
      if w
        idx << keys.index(w[1])                                    # the setter
        ab_i = keys.each_index.select { |i| ABUSER[n].include?(ab(meta, keys[i])) }
        idx << ab_i.first if ab_i.any?                             # one payoff mon
      end
    when 'trickroom'
      idx << keys.index { |k| mv(meta, k).include?('Trick Room') }
    when 'stall'
      idx.concat(keys.each_index.select { |i| bulky?(meta, keys[i]) &&
                 ((mv(meta, keys[i]) & RECOVER).any? || (mv(meta, keys[i]) & PHAZE).any?) }.first(2))
    when 'hazardstack'
      idx.concat(keys.each_index.select { |i| (mv(meta, keys[i]) & HAZARD).any? }.first(2))
    when 'priority'
      idx.concat(keys.each_index.select { |i| (mv(meta, keys[i]) & PRIORITY).any? }.first(2))
    when 'scarf'
      idx.concat(keys.each_index.select { |i| it(meta, keys[i]) == 'Choice Scarf' }.first(2))
    when 'bulkysetup'
      idx.concat(keys.each_index.select { |i| (mv(meta, keys[i]) & SETUP).any? &&
                 (bulky?(meta, keys[i]) || (mv(meta, keys[i]) & RECOVER).any?) }.first(2))
    when 'balance'
      idx.concat(keys.each_index.select { |i| bulky?(meta, keys[i]) &&
                 ((mv(meta, keys[i]) & RECOVER).any? || (mv(meta, keys[i]) & PHAZE).any?) }.first(1))
    end
    idx.compact.uniq
  end
end
