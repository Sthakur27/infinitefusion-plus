# Does switch prediction actually reduce the blunder it targets?
# Counts "our move did nothing because the foe pivoted into an immunity" with the
# feature ON vs OFF, over the same teams and seeds. Win-rate ablation can't see this
# (both sides make the same error), so measure the error itself.
#   ruby tools/sidmod_editor/sim/nswitchcheck.rb <rating_tag> [matchups] [seeds]
require_relative 'nstore'
require_relative 'nbattle'

RTAG = ARGV[0] || 'ou3'
MU   = (ARGV[1] || 12).to_i
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
def bases_of(k); (POOL[k] && POOL[k]['bases']) || []; end
def pick6(c)
  o = []; u = []
  c.each { |k| next if (bases_of(k) & u).any?; o << k; u.concat(bases_of(k)); break if o.length == 6 }
  o
end
teams = []
MU.times { |i| teams << pick6(keys.shuffle(random: Random.new(1300 + i))) }
teams = teams.select { |t| t.length == 6 }

# an event: an "It doesn't affect / had no effect" line whose attacker chose its move
# BEFORE the current defender came in (i.e. a switch happened in the last few lines)
def count_blunders(log)
  lines = log.map { |l| l.to_s.dup.force_encoding('UTF-8').scrub('?') }
  after_switch = 0; same_target = 0
  lines.each_with_index do |l, i|
    next if !(l.include?("doesn't affect") || l.include?('had no effect'))
    win = lines[[0, i - 6].max...i]
    if win.any? { |w| w.include?('sent out') || w.include?('will switch') }
      after_switch += 1
    else
      same_target += 1
    end
  end
  [after_switch, same_target]
end

puts "=== switch-prediction blunder check: #{teams.length} teams x #{SEEDS} seeds ==="
%w[ON OFF].each do |mode|
  aftr = 0; same = 0; games = 0; wins_a = 0
  teams.each_with_index do |ta, i|
    tb = teams[(i + 1) % teams.length]
    next if ta == tb
    SEEDS.times do |s|
      $SIDMOD_AI_FEATURES = (mode == 'OFF') ? { 0 => { foe_switch: false }, 1 => { foe_switch: false } } : nil
      r = NativeSim.run(ta, tb, seed: 70 + s, log: true)
      a, b = count_blunders(r[:log])
      aftr += a; same += b; games += 1
      wins_a += 1 if r[:winner] == :a
    end
  end
  $SIDMOD_AI_FEATURES = nil
  puts "  prediction #{mode.ljust(3)}: #{aftr} pivot-blanked hits, #{same} same-target no-effects, " \
       "over #{games} battles (#{'%.2f' % (aftr.to_f / games)} per battle)"
end
puts "\n(a 'pivot-blanked hit' is the exact failure switch prediction is meant to prevent)"
