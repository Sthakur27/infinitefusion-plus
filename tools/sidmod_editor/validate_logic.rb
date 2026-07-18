# Validate PokeMath (exp->level, fused base stats, stat formulas, nature, growth-rate
# selection) against every real Pokemon in the save. If this passes broadly, the
# writer's math is trustworthy.
require_relative 'stub_loader'
require_relative 'pokemath'
require 'json'

save  = StubLoader.load_file(ARGV[0])
TABLE = JSON.parse(File.read(ARGV[1] || File.join(__dir__, 'species_table.json')))
NB = 501
BY_ID = {}                     # species symbol string -> dex record
TABLE.each { |dex, r| BY_ID[r['id']] = r.merge('dex' => dex.to_i) }

def iv(o, n) o.instance_variable_get(n) end

def resolve(pk)
  # returns [base_stats(hash str), growth_rate(str)] or nil if unresolvable
  s = iv(pk, :@species)
  body = head = nil
  if s.is_a?(Symbol) && s.to_s =~ /\AB(\d+)H(\d+)\z/ then body = $1.to_i; head = $2.to_i
  elsif s.is_a?(Integer) && s > NB then body = s / NB; head = s % NB
  end
  t = ->(dex) { $TABLE[dex.to_s] }
  if body && head
    hb = t.(head); bb = t.(body)
    return nil unless hb && bb
    [PokeMath.fused_base_stats(hb['base_stats'], bb['base_stats']),
     PokeMath.fusion_growth_rate(hb['growth_rate'], bb['growth_rate'])]
  else
    rec = $BY_ID[s.to_s]
    return nil unless rec
    [rec['base_stats'], rec['growth_rate']]
  end
end

$TABLE = TABLE
$BY_ID = BY_ID

mons = []
(iv(save[:player], :@party) || []).each { |pk| mons << pk if pk }
(iv(save[:storage_system], :@boxes) || []).each do |b|
  next unless b
  (iv(b, :@pokemon) || []).each { |pk| mons << pk if pk }
end

total = mons.length
resolved = lvl_ok = stat_ok = 0
skipped = 0
$explains = Hash.new(0)
lvl_bad = []
stat_bad = []

mons.each do |pk|
  r = resolve(pk)
  if r.nil? then skipped += 1; next end
  base_stats, growth = r
  resolved += 1
  exp = iv(pk, :@exp); lvl = iv(pk, :@level)

  # level check
  computed_lvl = PokeMath.level_from_exp(growth, exp)
  if lvl.nil? || computed_lvl == lvl then lvl_ok += 1
  else
    # Which curve DOES explain the stored level? (legacy pre-fusion exp?)
    explained = PokeMath::GROWTH.keys.select { |g| PokeMath.level_from_exp(g, exp) == lvl }
    $explains[explained.empty? ? "NONE" : explained.sort.join("|")] += 1
    lvl_bad << "#{iv(pk,:@species)} L#{lvl} exp#{exp} fusion=#{growth}->L#{computed_lvl}; explained_by=#{explained.inspect}" if lvl_bad.length < 12
  end

  # stat check (skip if nature not explicit or nature_for_stats override)
  nat = iv(pk, :@nature)
  next if nat.nil? || iv(pk, :@nature_for_stats)
  use_lvl = lvl || computed_lvl
  cs = PokeMath.all_stats(base_stats, use_lvl, iv(pk, :@iv), iv(pk, :@ev), nat)
  got = { "HP"=>iv(pk,:@totalhp), "ATTACK"=>iv(pk,:@attack), "DEFENSE"=>iv(pk,:@defense),
          "SPECIAL_ATTACK"=>iv(pk,:@spatk), "SPECIAL_DEFENSE"=>iv(pk,:@spdef), "SPEED"=>iv(pk,:@speed) }
  if PokeMath::STATS.all? { |s| cs[s.to_s] == got[s.to_s] }
    stat_ok += 1
  elsif stat_bad.length < 12
    diff = PokeMath::STATS.map { |s| k=s.to_s; cs[k]==got[k] ? nil : "#{k}:calc#{cs[k]}!=save#{got[k]}" }.compact.join(" ")
    stat_bad << "#{iv(pk,:@species)} L#{use_lvl} #{nat}: #{diff}"
  end
end

puts "TOTAL mons: #{total}"
puts "resolved:   #{resolved}   (skipped/unresolvable: #{skipped})"
puts "LEVEL  ok:  #{lvl_ok}/#{resolved}"
puts "STAT   ok:  #{stat_ok}   (of resolved w/ explicit nature)"
puts "\nlevel-mismatch explained-by-curve tally: #{$explains.sort_by{|k,v|-v}.to_h}"
puts "level mismatches (#{lvl_bad.length} shown):"; lvl_bad.each { |x| puts "  #{x}" }
puts "\nstat mismatches (#{stat_bad.length} shown):"; stat_bad.each { |x| puts "  #{x}" }
