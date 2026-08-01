# Set-vs-set A/B: hold a team fixed, swap ONE member's entire build (ability / item / moves /
# nature), and play the same frozen field both sides. Answers "setup sweeper or immediate
# wallbreaker?" — which ab_item_test.rb cannot, because varying only the item leaves a Nasty
# Plot on the set and unfairly handicaps Choice items.
#
#   ruby ab_set_test.rb <ladder_tag> <mon_name> <variants.json> [seeds]
#
# `item` may be "" or null to test holding NO item (matters for Acrobatics, Unburden, ...).
# More seeds = tighter error bars; 198 games gives about +/-7 points, which cannot resolve a
# 3-point difference.
#
# variants.json: [ { "label":"NP + Life Orb", "ability":"ADAPTABILITY", "item":"LIFEORB",
#                    "nature":"MODEST", "moves":["NASTYPLOT","BOOMBURST",...] }, ... ]
# head/body and EVs are inherited from the pool mon unless overridden.
require_relative 'nstore'
require_relative 'nbattle'
require_relative 'build_team'
require 'json'

TAG   = ARGV[0] || 'ladder_pure'
MON   = ARGV[1] or abort 'usage: ab_set_test.rb <ladder_tag> <mon_name> <variants.json>'
VPATH = ARGV[2] or abort 'need variants.json'
SEEDS = (ARGV[3] || 1).to_i
DIR   = File.join(__dir__, 'nreports', TAG)

variants = JSON.parse(File.read(VPATH))
ENV['NSIM_SAVE'] = File.join(DIR, 'save_snapshot.rxdata')
NativeSim.boot!
$DEBUG = false
st   = NStore::PARSE.call(File.binread(File.join(DIR, 'ladder.json')))
pool = NStore::PARSE.call(File.binread(File.join(DIR, 'pool.json')))

entry = NativeSim.all_pool.find { |e| e[:name] == MON } or abort "#{MON} not in pool"
key   = entry[:key]
teams = st['teams'].sort_by { |t| -t['elo'] }
home  = teams.find { |t| t['keys'].include?(key) } or abort "no team runs #{MON}"
idx   = home['keys'].index(key)
field = teams.reject { |t| t.equal?(home) }
bases = (entry[:bases] || []).map { |b| b.to_s.upcase.to_sym }
evs   = (entry[:ref].ev.to_hash rescue nil) ||
        { HP: 4, SPECIAL_ATTACK: 252, SPEED: 252 }

puts "SET A/B: #{MON} (#{bases.join('/')}) on team Elo #{home['elo'].round}"
puts "field: #{field.size} teams x both sides = #{field.size * 2} games per variant"

results = {}
variants.each do |v|
  spec = { head: bases[0], body: bases[1], level: 100,
           ability: v['ability'].to_sym,
           item: (v['item'].to_s.empty? ? nil : v['item'].to_sym),
           nature: (v['nature'] || 'MODEST').to_sym,
           moves: v['moves'].map(&:to_sym), evs: (v['evs'] || evs) }
  built = (BuildTeam.mon(spec) rescue nil)
  if built.nil?
    puts "  #{v['label']}: BUILD FAILED (illegal move/ability/item?) — skipped"
    next
  end
  pts = 0.0; n = 0; crash = 0
  field.each do |o|
    SEEDS.times do |si|
      seed = 500 + si * 101 + o['id'].hash.abs % 50_000
      party = NativeSim.party(home['keys'])
      party[idx] = Marshal.load(Marshal.dump(built)); party[idx].heal
      r1 = NativeSim.run_mons(party, NativeSim.party(o['keys']), seed: seed); crash += 1 if NativeSim.last_error
      party2 = NativeSim.party(home['keys'])
      party2[idx] = Marshal.load(Marshal.dump(built)); party2[idx].heal
      r2 = NativeSim.run_mons(NativeSim.party(o['keys']), party2, seed: seed); crash += 1 if NativeSim.last_error
      pts += (r1 == :a ? 1.0 : r1 == :b ? 0.0 : 0.5)
      pts += (r2 == :b ? 1.0 : r2 == :a ? 0.0 : 0.5)
      n += 2
    end
  end
  wr = pts / n
  ci = 1.96 * Math.sqrt(wr * (1 - wr) / n) * 100
  results[v['label']] = [wr, ci, n]
  puts format('  %-26s %.1f%% +/-%.1f  (%d games, %d crash-draws)', v['label'], wr * 100, ci, n, crash)
end

puts "\n=== RANKING (95% CI) ==="
sorted = results.sort_by { |_l, (w, _c, _n)| -w }
sorted.each_with_index { |(l, (w, c, _n)), i| puts format('  %d. %-26s %.1f%% +/-%.1f', i + 1, l, w * 100, c) }
if sorted.length > 1
  wa, ca, = sorted[0][1]
  wb, cb, = sorted[1][1]
  gap = (wa - wb) * 100
  puts format("\ngap #1 vs #2: %.1f points — %s", gap,
              gap > Math.sqrt(ca**2 + cb**2) ? 'SIGNIFICANT' : 'NOT significant (within noise)')
end
