# ABLATION: measure what each AI improvement is actually worth, by playing the full
# AI against the same AI with ONE feature switched off. Same teams, same seeds, both
# side assignments - so the only difference is the feature.
#
#   ruby tools/sidmod_editor/sim/nablate.rb <rating_tag> <out_tag> [matchups] [seeds]
#
# A feature whose removal makes the AI BETTER is harmful and should be reverted or
# retuned. This exists because 6-seed archetype records move around by 1-2 games and
# cannot tell an improvement from noise.
require_relative 'nstore'
require_relative 'nbattle'
require 'fileutils'

RTAG = ARGV[0] || 'ou3'
OTAG = ARGV[1] || 'ablate'
MU   = (ARGV[2] || 12).to_i     # distinct team matchups
SEEDS = (ARGV[3] || 6).to_i
ONLY = (ARGV[4] || '').split(',').map(&:to_sym)   # optional: only these features

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
  out = []; used = []
  c.each { |k| next if (bases_of(k) & used).any?; out << k; used.concat(bases_of(k)); break if out.length == 6 }
  out
end

# A DIVERSE field: random teams plus the offense and stall archetypes, so features that
# only matter in defensive games still get exercised.
bulk = ->(k) { s = stats_of(k); s[0].to_i + s[2].to_i + s[4].to_i }
RECOV = %w[Recover Roost Soft-Boiled Milk\ Drink Slack\ Off Morning\ Sun Moonlight Synthesis Wish Rest Shore\ Up]
offense = pick6(keys.sort_by { |k| -BY[k]['kos_per_game'].to_f })
stall   = pick6(keys.select { |k| (moves_of(k) & RECOV).any? && bulk.(k) >= 800 }.sort_by { |k| -bulk.(k) })
balance = pick6(stall.first(3) + offense)
teams = [offense, stall, balance]
(MU - 3).times { |i| teams << pick6(keys.shuffle(random: Random.new(700 + i))) }
teams = teams.select { |t| t.length == 6 }

ALL_NEW = { heal: false, residual: false, chip: false, noop: false, preview: false,
            setup_convert: false, phaze: false, repl_safe: false, beam: false,
            dmg_weight: false }
FEATURES = {
  ALL:           'EVERY v2+v3 addition at once (i.e. current AI vs the pre-session AI)',
  smart:         'the whole SmartAI planner (i.e. current AI vs stock Essentials AI)',
  heal:          'recovery-move model (heal scored against incoming damage)',
  residual:      'chip damage folded into both TTK clocks',
  chip:          'status a foe we are not out-racing',
  noop:          'never spend a turn on a move that cannot do anything',
  preview:       'analytic 1-step preview (suicide veto)',
  setup_convert: 'only boost if the boost converts to a kill',
  phaze:         'Haze / force-out answer to a boosting foe',
  repl_safe:     'do not send a replacement into a free OHKO',
  beam:          'beam search over the abstract state',
  dmg_weight:    'prefer the harder-hitting move when no KO is available',
  team:          'team-level planning: preserve scarce answers and healthy win conditions',
}

puts "=== ABLATION: full AI vs full-AI-minus-one-feature ==="
puts "#{teams.length} teams, #{SEEDS} seeds, both side assignments -> #{teams.length * SEEDS * 2} games per feature\n"
puts "  %-15s %-8s %-8s %-7s %s" % %w[feature-off fullAI ablated draws verdict]

results = {}
FEATURES.select { |f, _| ONLY.empty? || ONLY.include?(f) }.each do |f, _desc|
  full = 0; abl = 0; draws = 0
  teams.each_with_index do |ta, i|
    tb = teams[(i + 1) % teams.length]
    next if ta == tb
    SEEDS.times do |s|
      seed = 30 + s
      # full AI on side 0, ablated on side 1
      off = (f == :ALL) ? ALL_NEW : { f => false }
      $SIDMOD_AI_FEATURES = { 0 => {}, 1 => off }
      r = NativeSim.run(ta, tb, seed: seed)
      r[:winner] == :a ? full += 1 : (r[:winner] == :b ? abl += 1 : draws += 1)
      # mirrored: ablated on side 0
      $SIDMOD_AI_FEATURES = { 0 => off, 1 => {} }
      r = NativeSim.run(ta, tb, seed: seed)
      r[:winner] == :b ? full += 1 : (r[:winner] == :a ? abl += 1 : draws += 1)
    end
  end
  $SIDMOD_AI_FEATURES = nil
  n = full + abl
  wr = n > 0 ? full.to_f / n : 0.5
  se = n > 0 ? Math.sqrt(0.25 / n) : 1.0
  verdict = if wr - 0.5 > 1.96 * se then 'HELPS (significant)'
            elsif 0.5 - wr > 1.96 * se then 'HURTS - retune/revert'
            else 'no measurable effect'
            end
  results[f] = { 'full' => full, 'ablated' => abl, 'draws' => draws, 'winrate' => wr, 'se' => se, 'verdict' => verdict }
  puts "  %-15s %-8d %-8d %-7d %.3f +/- %.3f  %s" % [f, full, abl, draws, wr, se, verdict]
end

NStore.write_json(OTAG, 'ablation.json',
                  'features' => FEATURES.map { |k, v| [k.to_s, v] }.to_h,
                  'results' => results.map { |k, v| [k.to_s, v] }.to_h,
                  'teams' => teams.length, 'seeds' => SEEDS)
puts "\n(winrate = the FULL AI's share of decided games against the version missing that feature;"
puts " 0.500 means the feature changes nothing measurable at this sample size)"
puts "-> #{File.join(NStore.dir(OTAG), 'ablation.json')}"
