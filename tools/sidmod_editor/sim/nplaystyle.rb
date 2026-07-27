# DIAGNOSTIC: how does the SmartTrainerAI actually play, and is it capable of
# piloting a defensive team at all? Answers the "it only understands hyper-offense"
# concern with measurements instead of opinion.
#
#   ruby tools/sidmod_editor/sim/nplaystyle.rb <rating_tag> <out_tag> [seeds] [workers]
#
# Builds three archetypes from the SAME pool (offense / stall / balance), plays them
# against each other with logging on, then counts what the AI actually did:
#   - move-category mix (damage / setup / recovery / status / hazard / pivot / protect)
#   - wasted turns ("But it failed!", "doesn't affect", re-applying an existing status)
#   - switch frequency, battle length, and who wins
# A wall that never clicks Recover, or a Toxic team whose Toxic never lands, means the
# rating is measuring AI incompetence rather than the mon's strength.
require_relative 'nstore'
require_relative 'nbattle'
require 'fileutils'

RTAG  = ARGV[0] || 'ou3'
OTAG  = ARGV[1] || 'playstyle'
SEEDS = (ARGV[2] || 6).to_i

snap = File.join(NStore.dir(RTAG), 'save_snapshot.rxdata')
ENV['NSIM_SAVE'] = snap if File.exist?(snap)
NativeSim.boot!
FileUtils.mkdir_p(NStore.dir(OTAG))
POOL = NStore.read_json(RTAG, 'pool.json')
rat  = File.readlines(File.join(NStore.dir(RTAG), 'ratings.csv'))
HDR  = rat[0].chomp.split(',')
MONS = rat[1..].map { |l| HDR.zip(l.chomp.split(',')).to_h }
BY   = MONS.map { |m| [m['key'], m] }.to_h

# ---- move classification from real move data --------------------------------
SETUP   = %w[SWORDSDANCE DRAGONDANCE NASTYPLOT CALMMIND QUIVERDANCE SHELLSMASH BULKUP WORKUP
             ROCKPOLISH AGILITY AUTOTOMIZE SHIFTGEAR COIL GEOMANCY BELLYDRUM TAILGLOW GROWTH
             HONECLAWS NORETREAT CLANGOROUSSOUL VICTORYDANCE TAKEHEART]
HAZARD  = %w[STEALTHROCK SPIKES TOXICSPIKES STICKYWEB]
PIVOT   = %w[UTURN VOLTSWITCH FLIPTURN PARTINGSHOT TELEPORT BATONPASS]
RECOVER = %w[RECOVER ROOST SOFTBOILED MILKDRINK SLACKOFF MORNINGSUN MOONLIGHT SYNTHESIS WISH
             REST SHOREUP STRENGTHSAP PAINSPLIT]
PHAZE   = %w[WHIRLWIND ROAR DRAGONTAIL CIRCLETHROW HAZE CLEARSMOG]
PROTECT = %w[PROTECT DETECT KINGSSHIELD SPIKYSHIELD BANEFULBUNKER]
STATUS  = %w[TOXIC WILLOWISP THUNDERWAVE GLARE SLEEPPOWDER HYPNOSIS YAWN LEECHSEED
             CONFUSERAY SWAGGER POISONPOWDER STUNSPORE DARKVOID GRASSWHISTLE SING]

MOVE_BY_NAME = {}
GameData::Move.each { |mv| MOVE_BY_NAME[mv.name.to_s.downcase] = mv }

def classify_move(name)
  mv = MOVE_BY_NAME[name.to_s.downcase.strip]
  return :unknown if !mv
  id = mv.id.to_s
  return :setup   if SETUP.include?(id)
  return :hazard  if HAZARD.include?(id)
  return :pivot   if PIVOT.include?(id)
  return :recover if RECOVER.include?(id)
  return :phaze   if PHAZE.include?(id)
  return :protect if PROTECT.include?(id)
  return :status  if STATUS.include?(id)
  (mv.base_damage.to_i > 0) ? :damage : :other_status
end

# ---- archetype construction --------------------------------------------------
def stats_of(k); (POOL[k] && POOL[k]['stats']) || [0, 0, 0, 0, 0, 0]; end
def bases_of(k); (POOL[k] && POOL[k]['bases']) || []; end
def moves_of(k); (POOL[k] && POOL[k]['moves']) || []; end
def legal?(t); b = t.flat_map { |k| bases_of(k) }; t.uniq.length == 6 && b.uniq.length == b.length; end

def pick6(cands)
  out = []; used = []
  cands.each do |k|
    next if (bases_of(k) & used).any?
    out << k; used.concat(bases_of(k))
    break if out.length == 6
  end
  out
end

keys = MONS.map { |m| m['key'] }.select { |k| POOL[k] }
# OFFENSE: highest KO rate
offense = pick6(keys.sort_by { |k| -BY[k]['kos_per_game'].to_f })
# STALL: bulk (HP + Def + SpD) AND a recovery/status/hazard tool, lowest KO rate first
defensive_tools = ->(k) {
  ms = moves_of(k).map { |n| classify_move(n) }
  (ms & %i[recover status hazard phaze protect]).any?
}
bulk = ->(k) { s = stats_of(k); s[0].to_i + s[2].to_i + s[4].to_i }
# A competitive stall team needs RELIABLE RECOVERY, not just raw bulk. Picking the
# bulkiest mons regardless of healing produced a "stall" team where only 1 of 6 could
# heal - that tests nothing about defensive play. Require recovery first, then bulk,
# and top up with bulky status/hazard mons if there aren't 6.
has_recovery = ->(k) { moves_of(k).any? { |n| classify_move(n) == :recover } }
stall = pick6(keys.select { |k| has_recovery.(k) && bulk.(k) >= 800 }
                  .sort_by { |k| -bulk.(k) })
if stall.length < 6
  stall = pick6(stall + keys.select { |k| defensive_tools.(k) && bulk.(k) >= 800 }
                              .sort_by { |k| -bulk.(k) })
end
# BALANCE: 3 of each
balance = pick6(stall.first(3) + offense.first(6))

ARCH = { 'OFFENSE' => offense, 'STALL' => stall, 'BALANCE' => balance }
ARCH.each do |n, t|
  puts "#{n} (#{t.length} mons, legal=#{legal?(t)}):"
  t.each { |k|
    p = POOL[k]
    puts "  %-13s %-22s %-13s %-14s bulk=%-4d ko/g=%.2f  %s" %
         [p['name'], p['species'], p['types'], p['item'], bulk.(k),
          BY[k]['kos_per_game'].to_f, p['moves'].join('/')]
  }
end

# ---- log analysis ------------------------------------------------------------
def analyse(log)
  c = Hash.new(0)
  statused = {}
  log.each do |raw|
    l = raw.to_s.dup.force_encoding('UTF-8').scrub('?')
    if (m = l.match(/\A(The opposing )?(.+?) used (.+?)!/))
      side = m[1] ? 'B' : 'A'
      cat = classify_move(m[3])
      c["#{side}_#{cat}"] += 1
      c["#{side}_moves"] += 1
    end
    c[:fail] += 1 if l.include?('But it failed') || l.include?('But nothing happened')
    c[:no_effect] += 1 if l.include?("doesn't affect") || l.include?('had no effect')
    c[:switch] += 1 if l =~ /\[SmartAI\].*will switch/
    c[:repl] += 1 if l.include?('replacement pick')
    c[:recover_msg] += 1 if l =~ /regained health|restored its HP|had its HP restored/
    c[:poisoned] += 1 if l =~ /was badly poisoned|was poisoned/
    c[:burned] += 1 if l =~ /was burned/
    c[:para] += 1 if l =~ /is paralyz/
    c[:asleep] += 1 if l =~ /fell asleep/
    c[:leech] += 1 if l.include?('was seeded')
    c[:faint] += 1 if l.include?('fainted')
  end
  c
end

pairs = [%w[OFFENSE STALL], %w[STALL OFFENSE], %w[OFFENSE OFFENSE],
         %w[STALL STALL], %w[BALANCE OFFENSE], %w[BALANCE STALL]]
LOGDIR = File.join(NStore.dir(OTAG), 'logs'); FileUtils.mkdir_p(LOGDIR)
rows = []
pairs.each do |a, b|
  agg = Hash.new(0); wins = { a: 0, b: 0, draw: 0 }; turns = []
  SEEDS.times do |s|
    r = NativeSim.run(ARCH[a], ARCH[b], seed: 60 + s, log: true)
    wins[r[:winner]] += 1
    turns << r[:turns]
    analyse(r[:log]).each { |k, v| agg[k] += v }
    # engine messages are ASCII-8BIT, the planner's own lines are UTF-8 -> scrub before join
    if s < 2
      File.binwrite(File.join(LOGDIR, "#{a}_vs_#{b}_s#{60 + s}.log"),
                    r[:log].map { |x| x.to_s.dup.force_encoding('UTF-8').scrub('?') }.join("\n"))
    end
  end
  rows << [a, b, wins, turns, agg]
end

puts "\n=== RESULTS (#{SEEDS} seeds per pairing) ==="
puts "  %-9s %-9s %-11s %-7s %s" % %w[sideA sideB record avgTurns notes]
rows.each { |a, b, w, t, _agg|
  puts "  %-9s %-9s %-11s %-7.1f" % [a, b, "#{w[:a]}-#{w[:b]}-#{w[:draw]}", t.sum.to_f / t.length] }

puts "\n=== WHAT THE AI ACTUALLY CLICKED (per battle averages) ==="
puts "  %-20s %-7s %-7s %-8s %-8s %-7s %-8s %-7s" %
     %w[pairing/side damage setup recover status hazard protect pivot]
rows.each do |a, b, _w, _t, agg|
  [['A', a], ['B', b]].each do |sd, nm|
    n = SEEDS.to_f
    puts "  %-20s %-7.1f %-7.1f %-8.1f %-8.1f %-7.1f %-8.1f %-7.1f" %
         ["#{a}v#{b} #{sd}=#{nm}", agg["#{sd}_damage"] / n, agg["#{sd}_setup"] / n,
          agg["#{sd}_recover"] / n, (agg["#{sd}_status"] + agg["#{sd}_other_status"]) / n,
          agg["#{sd}_hazard"] / n, agg["#{sd}_protect"] / n, agg["#{sd}_pivot"] / n]
  end
end

puts "\n=== WASTED TURNS AND STATUS LANDING (totals over #{SEEDS} battles) ==="
puts "  %-20s %-7s %-10s %-8s %-9s %-8s %-7s %s" %
     ['pairing', 'failed', 'no-effect', 'switches', 'recovered', 'poisons', 'burns', 'seeds']
rows.each { |a, b, _w, _t, agg|
  puts "  %-20s %-7d %-10d %-8d %-9d %-8d %-7d %d" %
       ["#{a} vs #{b}", agg[:fail], agg[:no_effect], agg[:switch], agg[:recover_msg],
        agg[:poisoned], agg[:burned], agg[:leech]] }

NStore.write_json(OTAG, 'playstyle.json',
                  'archetypes' => ARCH.map { |n, t| [n, t.map { |k| POOL[k]['name'] }] }.to_h,
                  'pairs' => rows.map { |a, b, w, t, agg|
                    { 'a' => a, 'b' => b, 'wins_a' => w[:a], 'wins_b' => w[:b], 'draws' => w[:draw],
                      'avg_turns' => t.sum.to_f / t.length, 'counts' => agg.transform_keys(&:to_s) } },
                  'seeds' => SEEDS)
puts "\nlogs -> #{LOGDIR}"
