# Tier ASSIGNMENTS for the closed PC pool. Reads tiers.json and answers "is this fusion legal
# in tier T?".
#   ruby tiers.rb <snapshot_tag> [tier]
#
# MODEL (standard Smogon nesting): every fusion has one home tier; a tier's legal pool is its
# own members plus everything below it. ubers > ou > uu.
#   legal in ubers = everything
#   legal in ou    = home tier ou or uu   (ubers members excluded)
#   legal in uu    = home tier uu only    (ubers and ou members excluded)
# Unlisted fusions take `default_tier` (uu), so they are legal everywhere.
#
# Assignments are JUDGMENT calls, not derived from any ability/item/species rule — see the
# _readme in tiers.json for why (a rule mis-tiered Volcachu to Ubers while it finished last).
#
# IDENTITY: the engine's canonical fusion id, species symbol B<body>H<head>. Nicknames are
# rejected — they mutate on rebuild and are not unique (four fusions here are all "Overload").
require_relative 'nstore'
require 'set'

module Tiers
  module_function

  PATH  = File.join(__dir__, 'tiers.json')
  # ascending power; index = how high the mon sits. `ag` (Anything Goes) is the escape hatch
  # above Ubers: assigning a fusion to `ag` bans it from Ubers as well, which is what makes
  # Ubers an actual tier with a banlist rather than "everything".
  ORDER = %w[uu ou ubers ag].freeze

  def config
    @config ||= NStore::PARSE.call(File.binread(PATH))
  end

  def tier_names
    ORDER.reverse                          # ag, ubers, ou, uu
  end

  def default_tier
    config['default_tier'] || 'uu'
  end

  # "MAROWAK/MIMIKYU" or "B373H105" -> canonical species symbol, or nil if unresolvable.
  def canon(entry)
    s = entry.to_s.strip
    return s.upcase.to_sym if s =~ /\AB\d+H\d+\z/i
    parts = s.upcase.split('/').map(&:strip)
    return nil unless parts.length == 2
    head = (GameData::Species.get(parts[0].to_sym) rescue nil)
    body = (GameData::Species.get(parts[1].to_sym) rescue nil)
    return nil unless head && body
    (getFusedPokemonIdFromDexNum(body.id_number, head.id_number) rescue nil)
  end

  # canonical id => home tier, for every explicitly assigned fusion.
  def assignments
    @assignments ||= begin
      h = {}
      ORDER.each do |t|
        (config['tiers'][t]['members'] || []).each do |e|
          c = canon(e)
          h[c] = t if c
        end
      end
      h
    end
  end

  def validate
    bad = []
    ORDER.each do |t|
      (config['tiers'][t]['members'] || []).each do |e|
        c = canon(e)
        if c.nil?
          bad << "#{t}: cannot resolve #{e.inspect} (want HEAD/BODY, or B<body>H<head>)"
        elsif (GameData::Species.get(c) rescue nil).nil?
          bad << "#{t}: #{e.inspect} -> #{c} is not a real fusion"
        end
      end
    end
    # a fusion listed in two tiers is ambiguous
    seen = {}
    ORDER.each do |t|
      (config['tiers'][t]['members'] || []).each do |e|
        c = canon(e) or next
        bad << "#{c} listed in both #{seen[c]} and #{t}" if seen[c]
        seen[c] = t
      end
    end
    bad
  end

  def home_tier_of(entry)
    c = (entry[:ref].species rescue nil)
    (c && assignments[c]) || default_tier
  end

  # Is this pool entry legal in `tier`? (home tier must not sit above the tier being played)
  def legal?(entry, tier)
    ORDER.index(home_tier_of(entry)) <= ORDER.index(tier.to_s)
  end

  # Pool keys NOT legal in `tier` => the home tier that excluded them.
  def excluded_keys(tier, pool)
    pool.each_with_object({}) do |e, out|
      out[e[:key]] = home_tier_of(e) unless legal?(e, tier)
    end
  end

  # Assigned entries that match nothing in this pool (fusion not built, or stale entry).
  def unmatched(pool)
    have = pool.map { |e| (e[:ref].species rescue nil) }.compact.to_set
    assignments.reject { |c, _t| have.include?(c) }.keys
  end
end

if __FILE__ == $PROGRAM_NAME
  require_relative 'nbattle'
  tag  = ARGV[0] || 'tsnap'
  only = ARGV[1]
  ENV['NSIM_SAVE'] = File.join(__dir__, 'nreports', tag, 'save_snapshot.rxdata')
  NativeSim.boot!
  $DEBUG = false

  bad = Tiers.validate
  puts bad.empty? ? 'assignment validation: OK' : "assignment validation FAILED:\n  #{bad.join("\n  ")}"
  un = Tiers.unmatched(NativeSim.all_pool)
  puts "note: #{un.size} assigned fusion(s) not present in this pool: #{un.join(', ')}" unless un.empty?
  puts

  (only ? [only] : Tiers.tier_names).each do |t|
    # ubers plays the whole pool; ou/uu use the OU-legal (non-legendary) subset
    # ag/ubers play the whole pool (legendaries included); ou/uu use the OU-legal subset
    pool = %w[ag ubers].include?(t) ? NativeSim.all_pool : NativeSim.pool(tier: :ou)
    ex = Tiers.excluded_keys(t, pool)
    by = ex.values.tally.sort_by { |k, _v| -Tiers::ORDER.index(k) }.map { |k, v| "#{k} #{v}" }.join(', ')
    puts "== #{t.upcase} =="
    puts "   #{Tiers.config['tiers'][t]['desc']}"
    puts "   pool #{pool.size} - excluded #{ex.size}#{ex.empty? ? '' : " (#{by})"} = #{pool.size - ex.size} legal"
    puts
  end
end
