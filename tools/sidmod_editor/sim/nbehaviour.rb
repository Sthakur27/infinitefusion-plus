# BEHAVIOUR COMPARISON: stock vanilla AI vs current SmartAI, same teams and seeds.
#   ruby tools/sidmod_editor/sim/nbehaviour.rb <rating_tag> [matchups] [seeds]
#
# The two are equal in WINRATE (0.500 over 1440 games), so the ship decision rests
# entirely on how they BEHAVE. This counts what each actually clicks and how many turns
# each throws away. Claiming "vanilla wastes turns" without measuring it would be
# exactly the mistake that let a 37-Elo regression ship.
require_relative 'nstore'
require_relative 'nbattle'

RTAG  = ARGV[0] || 'ou3'
MU    = (ARGV[1] || 10).to_i
SEEDS = (ARGV[2] || 6).to_i
snap = File.join(NStore.dir(RTAG), 'save_snapshot.rxdata')
ENV['NSIM_SAVE'] = snap if File.exist?(snap)
NativeSim.boot!
POOL = NStore.read_json(RTAG, 'pool.json')
rat = File.readlines(File.join(NStore.dir(RTAG), 'ratings.csv'))
HDR = rat[0].chomp.split(',')
MONS = rat[1..].map { |l| HDR.zip(l.chomp.split(',')).to_h }
BY = MONS.map { |m| [m['key'], m] }.to_h
keys = MONS.map { |m| m['key'] }.select { |k| POOL[k] }

HAZ = %w[Stealth\ Rock Spikes Toxic\ Spikes Sticky\ Web]
REC = %w[Recover Roost Soft-Boiled Milk\ Drink Slack\ Off Morning\ Sun Moonlight Synthesis Wish Rest Shore\ Up Pain\ Split]
STA = %w[Toxic Will-O-Wisp Thunder\ Wave Glare Yawn Leech\ Seed Confuse\ Ray Sleep\ Powder Stun\ Spore Hypnosis]

def bases_of(k); (POOL[k] && POOL[k]['bases']) || []; end
def stats_of(k); (POOL[k] && POOL[k]['stats']) || [0] * 6; end
def moves_of(k); (POOL[k] && POOL[k]['moves']) || []; end
def pick6(c)
  o = []; u = []
  c.each { |k| next if (bases_of(k) & u).any?; o << k; u.concat(bases_of(k)); break if o.length == 6 }
  o
end
bulk = ->(k) { s = stats_of(k); s[0].to_i + s[2].to_i + s[4].to_i }
# Teams deliberately chosen to CONTAIN hazard, recovery and status moves, so a
# difference in usage is about the AI and not about the movesets available to it.
haz_users = keys.select { |k| (moves_of(k) & HAZ).any? }
rec_users = keys.select { |k| (moves_of(k) & REC).any? && bulk.(k) >= 750 }
teams = []
teams << pick6(haz_users + rec_users)                              # utility team
teams << pick6(rec_users.sort_by { |k| -bulk.(k) })                 # defensive team
teams << pick6(keys.sort_by { |k| -BY[k]['kos_per_game'].to_f })    # offence team
(MU - 3).times { |i| teams << pick6((haz_users + keys).shuffle(random: Random.new(3300 + i))) }
teams = teams.select { |t| t.length == 6 }
puts "teams: #{teams.length} (first has #{(moves_of(teams[0][0]) & HAZ).length > 0 ? 'hazards' : 'no hazards'})"
puts "hazard-capable mons in pool: #{haz_users.length}, recovery-capable: #{rec_users.length}\n"

def tally(log)
  c = Hash.new(0)
  log.each do |raw|
    l = raw.to_s.dup.force_encoding('UTF-8').scrub('?')
    if (m = l.match(/\A(The opposing )?(.+?) used (.+?)!/))
      mv = m[3]
      c[:moves] += 1
      c[:haz] += 1 if HAZ.include?(mv)
      c[:rec] += 1 if REC.include?(mv)
      c[:sta] += 1 if STA.include?(mv)
    end
    c[:fail] += 1 if l.include?('But it failed') || l.include?('But nothing happened')
    c[:noeff] += 1 if l.include?("doesn't affect") || l.include?('had no effect')
    c[:fullhp] += 1 if l.include?('HP is full')
    c[:turns] += 1 if l.include?('***Round')
  end
  c
end

rows = {}
{ 'vanilla' => { smart: false }, 'current' => {} }.each do |label, cfg|
  agg = Hash.new(0); games = 0
  teams.each_with_index do |ta, i|
    tb = teams[(i + 1) % teams.length]
    next if ta == tb
    SEEDS.times do |s|
      $SIDMOD_AI_FEATURES = { 0 => cfg, 1 => cfg }
      r = NativeSim.run(ta, tb, seed: 120 + s, log: true)
      tally(r[:log]).each { |k, v| agg[k] += v }
      games += 1
    end
  end
  $SIDMOD_AI_FEATURES = nil
  rows[label] = [agg, games]
end

puts "=== per battle (same teams, same seeds, #{rows['vanilla'][1]} battles each) ==="
puts "  %-9s %-8s %-9s %-9s %-9s %-9s %-9s %s" %
     %w[AI moves hazards recovery status FAILED no-effect full-HP-heals]
rows.each do |label, (a, g)|
  puts "  %-9s %-8.1f %-9.2f %-9.2f %-9.2f %-9.2f %-9.2f %.2f" %
       [label, a[:moves].to_f / g, a[:haz].to_f / g, a[:rec].to_f / g, a[:sta].to_f / g,
        a[:fail].to_f / g, a[:noeff].to_f / g, a[:fullhp].to_f / g]
end
v, c = rows['vanilla'][0], rows['current'][0]
puts "\nwasted turns per battle: vanilla %.2f vs current %.2f" %
     [(v[:fail] + v[:noeff]).to_f / rows['vanilla'][1], (c[:fail] + c[:noeff]).to_f / rows['current'][1]]
