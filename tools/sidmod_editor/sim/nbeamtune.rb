# Tune the beam by playing configurations against each other: same teams, same seeds,
# both side assignments, only the tunables differ.
#   ruby tools/sidmod_editor/sim/nbeamtune.rb <rating_tag> <out_tag> [matchups] [seeds]
# Baseline is whatever the file's constants say; each challenger overrides one value.
require_relative 'nstore'
require_relative 'nbattle'
require 'fileutils'

RTAG = ARGV[0] || 'ou3'
OTAG = ARGV[1] || 'beamtune'
MU   = (ARGV[2] || 16).to_i
SEEDS = (ARGV[3] || 10).to_i

snap = File.join(NStore.dir(RTAG), 'save_snapshot.rxdata')
ENV['NSIM_SAVE'] = snap if File.exist?(snap)
NativeSim.boot!
FileUtils.mkdir_p(NStore.dir(OTAG))
POOL = NStore.read_json(RTAG, 'pool.json')
rat = File.readlines(File.join(NStore.dir(RTAG), 'ratings.csv'))
HDR = rat[0].chomp.split(',')
MONS = rat[1..].map { |l| HDR.zip(l.chomp.split(',')).to_h }
BY = MONS.map { |m| [m['key'], m] }.to_h
keys = MONS.map { |m| m['key'] }.select { |k| POOL[k] }
def bases_of(k); (POOL[k] && POOL[k]['bases']) || []; end
def stats_of(k); (POOL[k] && POOL[k]['stats']) || [0] * 6; end
def moves_of(k); (POOL[k] && POOL[k]['moves']) || []; end
def pick6(c)
  o = []; u = []
  c.each { |k| next if (bases_of(k) & u).any?; o << k; u.concat(bases_of(k)); break if o.length == 6 }
  o
end
bulk = ->(k) { s = stats_of(k); s[0].to_i + s[2].to_i + s[4].to_i }
RECOV = %w[Recover Roost Soft-Boiled Slack\ Off Moonlight Synthesis Wish Rest Shore\ Up Milk\ Drink Morning\ Sun]
teams = [pick6(keys.sort_by { |k| -BY[k]['kos_per_game'].to_f }),
         pick6(keys.select { |k| (moves_of(k) & RECOV).any? && bulk.(k) >= 800 }.sort_by { |k| -bulk.(k) })]
(MU - 2).times { |i| teams << pick6(keys.shuffle(random: Random.new(880 + i))) }
teams = teams.select { |t| t.length == 6 }

VARIANTS = {
  'depth 3'      => { beam_depth: 3 },
  'depth 1'      => { beam_depth: 1 },
  'width 8'      => { beam_width: 8 },
  'width 2'      => { beam_width: 2 },
  'weight 220'   => { beam_weight: 220 },
  'weight 70'    => { beam_weight: 70 },
  'depth 4'      => { beam_depth: 4 },
}
ONLY = (ARGV[4] || '').split('|')

puts "=== BEAM TUNING: baseline (depth #{SmartAI::BEAM_DEPTH}, width #{SmartAI::BEAM_WIDTH}, " \
     "weight #{SmartAI::BEAM_WEIGHT}) vs variants ==="
puts "#{teams.length} teams x #{SEEDS} seeds x 2 orders = #{teams.length * SEEDS * 2} games per variant\n"
puts "  %-14s %-9s %-9s %-7s %s" % %w[variant baseline variant draws verdict]
res = {}
VARIANTS.select { |l, _| ONLY.empty? || ONLY.include?(l) }.each do |label, cfg|
  base = 0; var = 0; dr = 0
  teams.each_with_index do |ta, i|
    tb = teams[(i + 1) % teams.length]
    next if ta == tb
    SEEDS.times do |s|
      seed = 40 + s
      $SIDMOD_AI_FEATURES = { 0 => {}, 1 => cfg }
      r = NativeSim.run(ta, tb, seed: seed)
      r[:winner] == :a ? base += 1 : (r[:winner] == :b ? var += 1 : dr += 1)
      $SIDMOD_AI_FEATURES = { 0 => cfg, 1 => {} }
      r = NativeSim.run(ta, tb, seed: seed)
      r[:winner] == :b ? base += 1 : (r[:winner] == :a ? var += 1 : dr += 1)
    end
  end
  $SIDMOD_AI_FEATURES = nil
  n = base + var
  wr = n > 0 ? var.to_f / n : 0.5      # the VARIANT's winrate
  se = n > 0 ? Math.sqrt(0.25 / n) : 1
  verdict = if wr - 0.5 > 1.96 * se then 'VARIANT BETTER -> adopt'
            elsif 0.5 - wr > 1.96 * se then 'variant worse -> keep baseline'
            else 'no difference'
            end
  res[label] = { 'baseline_wins' => base, 'variant_wins' => var, 'draws' => dr,
                 'variant_winrate' => wr, 'se' => se, 'verdict' => verdict, 'cfg' => cfg.to_s }
  puts "  %-14s %-9d %-9d %-7d %.3f +/- %.3f  %s" % [label, base, var, dr, wr, se, verdict]
end
NStore.write_json(OTAG, 'beamtune.json', res)
puts "\n(variant winrate > 0.5 means the variant beat the current constants)"
