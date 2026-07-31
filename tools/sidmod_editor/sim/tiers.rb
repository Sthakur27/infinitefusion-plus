# Explicit tier banlists for the closed PC pool. Reads tiers.json, resolves a tier to the
# set of banned pool keys.
#   ruby tiers.rb <snapshot_tag> [tier]
#
# IDENTITY: matching is done on the ENGINE'S OWN canonical fusion id - the species symbol
# :B<body_dex>H<head_dex> (e.g. Marowak/Mimikyu == :B373H105, dexNum body*NB_POKEMON+head).
# That symbol is stored on every Pokemon, is produced by the game's
# getFusedPokemonIdFromDexNum, and is immutable and exactly unique per fusion.
#
# Banlist entries may be written either way:
#   "MAROWAK/MIMIKYU"  - human readable HEAD/BODY, resolved to the canonical id at load
#   "B373H105"         - the canonical id directly
# Nicknames are NOT accepted: they are auto-generated, change when a fusion is rebuilt,
# are user-editable, and are not unique.
#
# Granularity is per-fusion: banning MAROWAK/REGIGIGAS bans every build of that fusion,
# which is how real tiering works (you ban the Pokemon, not one set).
# Entries are validated at load, so a typo or a nonexistent fusion fails loudly.
require_relative 'nstore'
require 'set'

module Tiers
  module_function

  PATH = File.join(__dir__, 'tiers.json')

  def config
    @config ||= NStore::PARSE.call(File.binread(PATH))
  end

  def tier_names
    config['tiers'].keys
  end

  def banlist(tier)
    t = config['tiers'][tier.to_s] or raise "unknown tier #{tier} (have: #{tier_names.join(', ')})"
    parent = t['inherits'] ? banlist(t['inherits']) : []
    (parent + (t['bans'] || [])).uniq
  end

  # "MAROWAK/MIMIKYU" or "B373H105" -> canonical species symbol (:B373H105), or nil.
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

  # Complaints about entries that don't resolve to a real fusion (empty = clean).
  def validate
    bad = []
    tier_names.each do |t|
      (config['tiers'][t]['bans'] || []).each do |e|
        c = canon(e)
        if c.nil?
          bad << "#{t}: cannot resolve #{e.inspect} (want HEAD/BODY species names, or B<body>H<head>)"
        elsif (GameData::Species.get(c) rescue nil).nil?
          bad << "#{t}: #{e.inspect} -> #{c} is not a real fusion"
        end
      end
    end
    bad
  end

  # Canonical id of a pool entry (the species symbol the engine stores).
  def canon_of(entry)
    (entry[:ref].species rescue nil)
  end

  # Resolve a tier to { pool_key => canonical id that matched }.
  def banned_keys(tier, pool)
    wanted = banlist(tier).map { |e| canon(e) }.compact.to_set
    pool.each_with_object({}) do |e, out|
      c = canon_of(e)
      out[e[:key]] = c.to_s if c && wanted.include?(c)
    end
  end

  # Entries that match nothing in this pool (fusion not built, or stale entry).
  def unmatched(tier, pool)
    have = pool.map { |e| canon_of(e) }.compact
    banlist(tier).reject { |e| (c = canon(e)) && have.include?(c) }
  end
end

if __FILE__ == $PROGRAM_NAME
  require 'set'
  require_relative 'nbattle'
  tag  = ARGV[0] || 'tsnap'
  only = ARGV[1]
  ENV['NSIM_SAVE'] = File.join(__dir__, 'nreports', tag, 'save_snapshot.rxdata')
  NativeSim.boot!
  $DEBUG = false

  bad = Tiers.validate
  if bad.empty?
    puts 'banlist validation: OK (every entry resolves to a real fusion)'
  else
    puts 'banlist validation FAILED:'
    bad.each { |b| puts "  #{b}" }
  end
  puts

  (only ? [only] : Tiers.tier_names).each do |t|
    pool = (t == 'ubers') ? NativeSim.all_pool : NativeSim.pool(tier: :ou)
    bk = Tiers.banned_keys(t, pool)
    un = Tiers.unmatched(t, pool)
    puts "== #{t.upcase} =="
    puts "   #{Tiers.config['tiers'][t]['desc']}"
    puts "   pool #{pool.size} - banned #{bk.size} = #{pool.size - bk.size} legal"
    unless un.empty?
      puts "   note: #{un.size} banlist entr#{un.size == 1 ? 'y' : 'ies'} match nothing in this pool"
      puts "         (#{un.join(', ')})"
    end
    puts
  end
end
