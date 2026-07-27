# TEAM GENERATORS for the ladder: archetype-focused, pure random, and the genetic
# operators (mutate / crossover) applied to ladder winners.
#
#   Gen.new(pool_meta, ratings, tier_keys)
#     .random(rng)                       -> pure random, Species-Clause legal
#     .archetype(name, rng)              -> a team built to execute one plan
#     .mutate(keys, rng, n: 1)           -> swap 1-2 slots for rating-shortlist mons
#     .crossover(a, b, rng)              -> 3 from each parent, repaired to be legal
#
# Archetypes exist so the search explores plans the rating-greedy build never would
# (weather, hazard stack, trick room). Pure random keeps the search from collapsing
# into one basin. Both feed the same ladder.
require_relative 'nlead'

class Gen
  ARCHETYPES = %w[rain sun sand hyperoffense balance hazardstack trickroom priority scarf bulkysetup stall].freeze

  def initialize(meta, ratings, keys)
    @meta = meta            # key => {moves:, ability:, item:, types:, stats:, roles:, bases:}
    @rat  = ratings         # key => {coef:, kos:, wr:, games:}
    @keys = keys            # eligible pool keys for this tier
    @shortlist = keys.select { |k| (@rat[k] || {})[:games].to_i >= 60 }
                     .sort_by { |k| -(@rat[k] || {})[:coef].to_f }
  end

  attr_reader :meta, :shortlist

  def bases(k); @meta[k][:bases] || []; end

  def legal?(t)
    return false if t.length != 6 || t.uniq.length != 6
    b = t.flat_map { |k| bases(k) }
    b.uniq.length == b.length
  end

  # Add UP TO `n` candidates that pass Species Clause. `.first(n)` was wrong: handing
  # fill exactly n candidates meant a single clause conflict silently produced n-1
  # members, so a 3-hazard build landed with 2 and classified as generic.
  def fill_upto(team, candidates, n)
    used = team.flat_map { |k| bases(k) }
    added = 0
    candidates.each do |k|
      break if added >= n || team.length >= 6
      next if team.include?(k)
      bs = bases(k)
      next if bs.any? { |b| used.include?(b) }
      team << k; used.concat(bs); added += 1
    end
    team
  end

  # add candidates to a partial team while keeping Species Clause
  def fill(team, candidates)
    used = team.flat_map { |k| bases(k) }
    candidates.each do |k|
      break if team.length >= 6
      next if team.include?(k)
      bs = bases(k)
      next if bs.any? { |b| used.include?(b) }
      team << k; used.concat(bs)
    end
    team
  end

  def random(rng)
    t = fill([], @keys.shuffle(random: rng))
    legal?(t) ? t : nil
  end

  # --- predicates over a mon --------------------------------------------------
  def mv(k); @meta[k][:moves] || []; end
  def ab(k); @meta[k][:ability].to_s; end
  def it(k); @meta[k][:item].to_s; end
  def spd(k); (@meta[k][:stats] || [])[5].to_i; end
  def bulky?(k); s = @meta[k][:stats] || []; s[0].to_i >= 330 && (s[2].to_i >= 250 || s[4].to_i >= 250); end
  def setter?(k, w)
    { rain: 'Drizzle', sun: 'Drought', sand: 'Sand Stream', hail: 'Snow Warning' }[w] == ab(k)
  end
  def abuser?(k, w); Lead::ABUSER[w].to_a.include?(ab(k)); end
  def hazard?(k); (mv(k) & Lead::HAZARD).any?; end
  def setup?(k);  (mv(k) & Lead::SETUP).any?; end
  def pivot?(k);  (mv(k) & Lead::PIVOT).any?; end
  def recovery?(k); (mv(k) & ['Recover', 'Roost', 'Soft-Boiled', 'Slack Off', 'Synthesis', 'Moonlight',
                              'Morning Sun', 'Rest', 'Wish', 'Shore Up', 'Strength Sap']).any?; end
  def phaze?(k); (mv(k) & ['Whirlwind', 'Roar', 'Dragon Tail', 'Circle Throw', 'Haze', 'Clear Smog']).any?; end
  def priority?(k)
    (mv(k) & ['Extreme Speed', 'Aqua Jet', 'Bullet Punch', 'Ice Shard', 'Shadow Sneak', 'Sucker Punch',
              'Mach Punch', 'Vacuum Wave', 'Accelerock', 'Jet Punch', 'First Impression',
              'Quick Attack', 'Fake Out']).any?
  end
  def trickroom?(k); mv(k).include?('Trick Room'); end
  def slow?(k); spd(k) <= 180; end
  def scarf?(k); it(k) == 'Choice Scarf'; end

  # by-rating order, restricted to a predicate
  def best(pred, rng, jitter: 0.15)
    @shortlist.select { |k| pred.call(k) }
              .sort_by { |k| -((@rat[k] || {})[:coef].to_f + (rng.rand - 0.5) * jitter) }
  end

  # --- archetypes -------------------------------------------------------------
  # Each returns nil if the pool cannot support the plan (e.g. no Drizzle mon), which
  # the ladder treats as "skip", never as a failure.
  def archetype(name, rng)
    t =
      case name
      when 'rain', 'sun', 'sand'
        w = { 'rain' => :rain, 'sun' => :sun, 'sand' => :sand }[name]
        set = best(->(k) { setter?(k, w) }, rng).first
        return nil if !set
        team = [set]
        fill(team, best(->(k) { abuser?(k, w) }, rng).first(6))          # the payoff mons
        fill(team, best(->(k) { hazard?(k) || pivot?(k) }, rng))         # support
        fill(team, @shortlist)                                           # best available
        team
      when 'hyperoffense'
        team = fill([], best(->(k) { setup?(k) || (@rat[k] || {})[:kos].to_f >= 1.2 }, rng, jitter: 0.4))
        fill(team, @shortlist)
      when 'balance'
        team = fill_upto([], best(->(k) { bulky?(k) && (recovery?(k) || phaze?(k)) }, rng), 2)
        fill_upto(team, best(->(k) { pivot?(k) }, rng), 1)
        fill(team, best(->(k) { setup?(k) }, rng))
        fill(team, @shortlist)
      when 'hazardstack'
        team = fill_upto([], best(->(k) { hazard?(k) }, rng), 3)
        fill_upto(team, best(->(k) { phaze?(k) }, rng), 1)
        fill_upto(team, best(->(k) { priority?(k) || scarf?(k) }, rng), 1)
        fill(team, @shortlist)
      when 'trickroom'
        tr = best(->(k) { trickroom?(k) }, rng).first
        return nil if !tr
        team = [tr]
        fill(team, best(->(k) { slow?(k) && (@rat[k] || {})[:kos].to_f >= 0.8 }, rng))
        fill(team, @shortlist.select { |k| slow?(k) })
        fill(team, @shortlist)
      when 'priority'
        team = fill([], best(->(k) { priority?(k) }, rng, jitter: 0.3))
        fill(team, @shortlist)
      when 'scarf'
        team = fill_upto([], best(->(k) { scarf?(k) }, rng, jitter: 0.3), 3)
        fill(team, best(->(k) { setup?(k) }, rng))
        fill(team, @shortlist)
      when 'stall'
        team = fill_upto([], best(->(k) { bulky?(k) && recovery?(k) }, rng, jitter: 0.3), 3)
        fill_upto(team, best(->(k) { hazard?(k) }, rng), 1)
        fill_upto(team, best(->(k) { phaze?(k) }, rng), 1)
        fill(team, @shortlist.select { |k| bulky?(k) })
        fill(team, @shortlist)
      when 'bulkysetup'
        team = fill_upto([], best(->(k) { setup?(k) && (bulky?(k) || recovery?(k)) }, rng, jitter: 0.3), 3)
        fill_upto(team, best(->(k) { hazard?(k) }, rng), 1)
        fill(team, @shortlist)
      else
        return nil
      end
    (t && t.length == 6 && legal?(t)) ? t : nil
  end

  # --- genetic ---------------------------------------------------------------
  # Mutation that CANNOT break the plan: `protect` holds the slots that define the
  # team's niche (weather setter, Trick Room user, the walls of a stall team...).
  # Without this, mutation drifts every archetype toward generic offense, which is
  # exactly how the first ladder collapsed into one roster.
  def mutate_protecting(keys, protect, rng, n: nil)
    free = (0...6).to_a - protect
    return nil if free.empty?
    n ||= (rng.rand < 0.3 ? 2 : 1)
    out = keys.dup
    changed = 0
    pool = @shortlist.first([@shortlist.length / 2, 12].max)
    # retry: most single swaps violate Species Clause, and giving up after one attempt
    # made protected mutation return nil for whole archetypes (rain never mutated)
    24.times do
      break if changed >= n
      i = free[rng.rand(free.length)]
      cand = pool[rng.rand(pool.length)]
      next if out.include?(cand)
      nt = out.dup; nt[i] = cand
      next unless legal?(nt)
      out = nt; changed += 1
    end
    changed.zero? ? nil : out
  end

  # Same-niche crossover: keep the protected core of `a`, fill the rest from `b`.
  def crossover_protecting(a, b, protect_a, rng)
    kept = protect_a.map { |i| a[i] }
    t = fill(kept.dup, (b + a).shuffle(random: rng))
    t = fill(t, @shortlist)
    (t.length == 6 && legal?(t) && t != a && t != b) ? t : nil
  end

  def mutate(keys, rng, n: nil)
    n ||= (rng.rand < 0.3 ? 2 : 1)
    out = keys.dup
    n.times do
      i = rng.rand(6)
      # draw the replacement from the rating shortlist, weighted to the top half
      pool = @shortlist.first([@shortlist.length / 2, 12].max)
      cand = pool[rng.rand(pool.length)]
      nt = out.dup; nt[i] = cand
      out = nt if legal?(nt)
    end
    out == keys ? nil : out
  end

  def crossover(a, b, rng)
    cut = 2 + rng.rand(3)
    t = fill(a.first(cut).dup, b.shuffle(random: rng))
    t = fill(t, @shortlist)
    (t.length == 6 && legal?(t) && t != a && t != b) ? t : nil
  end
end
