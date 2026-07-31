# RQ1 (reframed): does the crowned metagame depend on WHICH AI judges it?
# Take a fixed set of teams (top-K of a completed ladder) and rank them under BOTH the
# native SmartAI and the one-turn lookahead via the SAME round-robin, then compare:
#   - Spearman rank correlation of the two rankings (low = meta is AI-dependent)
#   - head-to-head agreement (fraction of games where both AIs pick the same winner)
#   - archetype mix of each AI's top teams
#   ruby rq1_ai_compare.rb [ladder_tag] [K] [seeds]
require_relative 'nlookahead'   # pulls agent_battle + nbattle
require_relative 'nstore'
require 'json'

TAG   = ARGV[0] || 'ladder_c0'
K     = (ARGV[1] || 30).to_i
SEEDS = (ARGV[2] || 1).to_i
DIR   = File.join(__dir__, 'nreports', TAG)

data = NStore::PARSE.call(File.binread(File.join(DIR, 'ladder.json')))
pool = NStore::PARSE.call(File.binread(File.join(DIR, 'pool.json')))
ENV['NSIM_SAVE'] = File.join(DIR, 'save_snapshot.rxdata')
NativeSim.boot!
$DEBUG = false
LA = NLookahead.policy

teams = data['teams'].sort_by { |t| -t['elo'] }.first(K)
n = teams.length
puts "RQ1 AI comparison on #{TAG}: top #{n} teams, round-robin, #{SEEDS} seed(s)/pairing"

# native winner for a pairing (keys), :a/:b/:draw
def native_win(a, b, seed)
  r = NativeSim.run(a, b, seed: seed)
  r[:winner]
end
# lookahead-on-both-sides winner for a pairing (parties), 1/2/5
def la_win(pa, pb, seed)
  $SIM_NATIVE_SIDES = []
  dec, _ = SimAgent.run(pa, pb, LA, LA, seed: seed, cap: 300)
  dec
end

wins = { native: Hash.new(0.0), la: Hash.new(0.0) }
games = Hash.new(0)
agree = 0; total = 0
teams.each_with_index do |ta, ia|
  teams.each_with_index do |tb, ib|
    next if ib <= ia
    SEEDS.times do |s|
      seed = 1 + s
      nw = native_win(ta['keys'], tb['keys'], seed)                 # :a/:b/:draw
      pa = NativeSim.party(ta['keys']); pb = NativeSim.party(tb['keys'])
      lw = la_win(pa, pb, seed)                                     # 1/2/5
      # tally
      wins[:native][ta['id']] += (nw == :a ? 1.0 : nw == :b ? 0.0 : 0.5)
      wins[:native][tb['id']] += (nw == :b ? 1.0 : nw == :a ? 0.0 : 0.5)
      wins[:la][ta['id']]     += (lw == 1 ? 1.0 : lw == 2 ? 0.0 : 0.5)
      wins[:la][tb['id']]     += (lw == 2 ? 1.0 : lw == 1 ? 0.0 : 0.5)
      games[ta['id']] += 1; games[tb['id']] += 1
      # agreement (ignore draws)
      n_win = nw == :a ? ta['id'] : nw == :b ? tb['id'] : nil
      l_win = lw == 1 ? ta['id'] : lw == 2 ? tb['id'] : nil
      if n_win && l_win; total += 1; agree += 1 if n_win == l_win; end
    end
  end
end

def rank_of(scores)   # id => winrate, returns id => rank (1 = best)
  ord = scores.sort_by { |_id, wr| -wr }.map { |id, _| id }
  ord.each_with_index.to_h { |id, i| [id, i + 1] }
end
wr_native = teams.to_h { |t| [t['id'], wins[:native][t['id']] / [games[t['id']], 1].max] }
wr_la     = teams.to_h { |t| [t['id'], wins[:la][t['id']]     / [games[t['id']], 1].max] }
rn = rank_of(wr_native); rl = rank_of(wr_la)

# Spearman rho
d2 = teams.sum { |t| (rn[t['id']] - rl[t['id']])**2 }
rho = 1.0 - (6.0 * d2) / (n * (n * n - 1))

nm = ->(id) { t = teams.find { |x| x['id'] == id }; t['keys'].map { |k| (pool[k] || {})['name'] || k }.first(3).join('/') }
niche = ->(id) { (teams.find { |x| x['id'] == id } || {})['niche'] || 'generic' }

puts "\n=== RESULT ==="
puts "Spearman rank correlation (native vs lookahead ranking): %.3f" % rho
puts "  (1.0 = identical meta;  ~0 = the AI fully determines who's best)"
puts "head-to-head agreement: %.1f%% (%d/%d decisive games same winner)" % [100.0 * agree / [total, 1].max, agree, total]
puts "\nTOP 8 under NATIVE:      " + rn.sort_by { |_i, r| r }.first(8).map { |id, _| "#{nm.(id)}" }.join(" | ")
puts "TOP 8 under LOOKAHEAD:   " + rl.sort_by { |_i, r| r }.first(8).map { |id, _| "#{nm.(id)}" }.join(" | ")
puts "\nniche mix, native top-12:    " + rn.sort_by { |_i, r| r }.first(12).map { |id, _| niche.(id) }.tally.sort_by { |_k, v| -v }.map { |k, v| "#{k} #{v}" }.join(", ")
puts "niche mix, lookahead top-12: " + rl.sort_by { |_i, r| r }.first(12).map { |id, _| niche.(id) }.tally.sort_by { |_k, v| -v }.map { |k, v| "#{k} #{v}" }.join(", ")
