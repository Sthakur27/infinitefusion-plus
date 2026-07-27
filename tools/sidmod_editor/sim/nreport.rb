# Consolidated deliverable: mon-by-mon AND team-by-team, best AND worst, in one file.
#   ruby tools/sidmod_editor/sim/nreport.rb <rating_tag> <tourney_tag> [out_tag]
# Writes <out_tag>/SUMMARY.md (defaults to the tourney tag) and prints the highlights.
require_relative 'nstore'

RTAG = ARGV[0] || 'ou3'
TTAG = ARGV[1] || 'ou3final'
OTAG = ARGV[2] || TTAG

rat = File.readlines(File.join(NStore.dir(RTAG), 'ratings.csv'))
hdr = rat[0].chomp.split(',')
mons = rat[1..].map { |l| hdr.zip(l.chomp.split(',')).to_h }
man  = NStore.read_json(RTAG, 'manifest.json')
lb   = NStore.read_json(TTAG, 'leaderboard.json') rescue []
champs = Dir[File.join(File.dirname(NStore.dir('x')), '*', 'champion.json')].sort.map { |f|
  [File.basename(File.dirname(f)), NStore::PARSE.call(File.binread(f))] }

pool = NStore.read_json(RTAG, 'pool.json')
def setline(p)
  return '' if !p
  "#{p['species']} (#{p['types']}) · #{p['ability']} · #{p['item']} · #{p['moves'].join('/')} · #{p['evs']}"
end

L = []
L << "# OU search — deterministic native-AI results (#{RTAG} / #{TTAG})"
L << ""
L << "**Method.** The in-game SmartTrainerAI plays *both* sides — no LLM anywhere, every game seeded"
L << "and reproducible. Level 100 throughout. Candidate pool = every PC mon at Lv100 holding an item,"
L << "under the same clauses the in-game Random Battle uses (Species / Spore / OU-legal-legend):"
L << "**#{man['pool_ou']} OU-legal of #{man['pool_total']} battle-ready**."
L << ""
L << "**Scale.** Phase 1: #{man['games']} games over #{man['teams']} random Species-Clause teams"
L << "(~#{(man['games'].to_i * 12 / [mons.length, 1].max)} appearances per mon), at ~100 games/sec on #{man['workers']} workers."
L << ""
L << "**Harness fairness** (verified before trusting any number): side 0 wins 48.3% of 240 varied games;"
L << "identical-team self-mirrors 48.7%; draws <1%. Two engine asymmetries had to be patched in the sim"
L << "first — the SmartAI gate exempts player-owned battlers, and post-faint replacements for side 0 went"
L << "through the debug scene's *random* party picker (cost: same team 0/20 as side 0 vs 11/20 as side 1)."
L << ""
L << "**Noise floor.** 28% of matchups flip winner across 3 seeds → every figure below is many games"
L << "with both side assignments, and team searches keep a held-out field."
L << ""

L << "## Team-by-team"
L << ""
if lb.is_a?(Array) && !lb.empty?
  L << "| rank | team | winrate | elo | games |"
  L << "|---|---|---|---|---|"
  lb.each_with_index { |r, i|
    L << "| #{i + 1} | `#{r['team']}` | #{'%.3f' % r['winrate']} | #{'%+.0f' % r['elo']} | #{r['games']} |" }
  L << ""
  L << "Entrant classes: `named:` hand-built teams in your PC · `smart:` the in-game **Smart-OU builder**"
  L << "(what Random Battle actually throws at you) · `chaos:` top random teams · `chaosWORST:` bottom"
  L << "random teams (floor reference) · `built:` greedy from phase-1 ratings · `champ:` population-search winners."
  L << ""
  L << "**Best:** `#{lb.first['team']}` — #{lb.first['names'].join(', ')}"
  L << ""
  L << "**Worst:** `#{lb.last['team']}` — #{lb.last['names'].join(', ')}"
  L << ""
end

champs.each do |tag, c|
  L << "### Champion — `#{tag}` (TRAIN #{'%.3f' % c['train_wr']} / held-out TEST #{'%.3f' % c['test_wr']})"
  L << ""
  c['keys'].each_with_index { |k, i| L << "#{i + 1}. **#{c['names'][i]}** — #{setline(pool[k])}" }
  L << ""
end

L << "## Mon-by-mon"
L << ""
L << "`coef` = ridge-logistic contribution to win probability, fit over every game with the mon's"
L << "teammates controlled for (so it is not just \"had good teammates\"). `wr` = raw team winrate when present."
L << ""
L << "### Top 25"
L << ""
L << "| # | mon | fusion | types | item | games | wr | KOs/g | faint | coef |"
L << "|---|---|---|---|---|---|---|---|---|---|"
mons.first(25).each_with_index { |m, i|
  L << "| #{i + 1} | #{m['name']} | #{m['species']} | #{m['types']} | #{m['item']} | #{m['games']} | " \
       "#{m['winrate']} | #{m['kos_per_game']} | #{m['faint_rate']} | #{m['coef']} |" }
L << ""
L << "### Bottom 25 (this is your upgrade worklist)"
L << ""
L << "| # | mon | fusion | types | item | games | wr | KOs/g | coef | Box/slot |"
L << "|---|---|---|---|---|---|---|---|---|---|"
mons.last(25).reverse.each_with_index { |m, i|
  L << "| #{i + 1} | #{m['name']} | #{m['species']} | #{m['types']} | #{m['item']} | #{m['games']} | " \
       "#{m['winrate']} | #{m['kos_per_game']} | #{m['coef']} | Box#{m['box']} slot#{m['slot']} |" }
L << ""
L << "## Caveats that change how you should read this"
L << ""
L << "1. **Ratings are \"value in SmartAI's hands.\"** The AI plays offense well and stall/setup badly, so"
L << "   passive walls sit at the bottom with ~0 KOs/game. Correct for choosing *opponent* teams; a floor,"
L << "   not a verdict, for a team you pilot yourself."
L << "2. **The search finds AI blind spots if allowed.** A 1-HP Wonder Guard fusion dominated a small"
L << "   training field (97.9%) — real vs this AI, fragile vs a human or any chip damage. Hence the paired"
L << "   `champ:*nowg` run with it banned."
L << "3. **All-offense bias.** Champions converge on six sweepers because that is what wins AI-vs-AI."
L << "4. **Pool quality is mixed.** Coached mons (252/252 spreads, real items) sit alongside untouched ones"
L << "   (85 EVs in every stat). The bottom table is exactly the mass-upgrade worklist."
L << ""
L << "_Artifacts: `sim/nreports/#{RTAG}/` (ratings.csv, games.tsv, pool.json, save_snapshot.rxdata)"
L << "and `sim/nreports/#{TTAG}/` (leaderboard.json, report.md). Every game is replayable from jobs.tsv._"

out = File.join(NStore.dir(OTAG), 'SUMMARY.md')
File.binwrite(out, L.join("\n") + "\n")
puts "SUMMARY -> #{out}"
puts
puts L.select { |x| x.start_with?('**Best:**', '**Worst:**', '### Champion') }.join("\n")
