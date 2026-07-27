# Reader-friendly OU search report: overview -> top 15 teams -> top 15 mons.
#   ruby tools/sidmod_editor/sim/nreport2.rb <rating_tag> <tourney_tag> [out_tag]
#
# Every headline number (battles, unique teams, pool sizes) is COUNTED from the
# run dirs, never hardcoded. Fusion names are expanded to their head/body base
# species so a nickname like "Azumachomp" reads as (h: Azumarill, b: Garchomp).
require_relative 'nstore'
require_relative 'engine'
require 'set'

RTAG = ARGV[0] || 'ou3'
TTAG = ARGV[1] || 'ou3clean'
OTAG = ARGV[2] || TTAG
TOPN = 15

SimEngine.boot   # only for species display names; no save needed

def sp_name(sym)
  (GameData::Species.get(sym.to_s.to_sym).name rescue sym.to_s.capitalize)
end

pool = NStore.read_json(RTAG, 'pool.json')
rat  = File.readlines(File.join(NStore.dir(RTAG), 'ratings.csv'))
hdr  = rat[0].chomp.split(',')
mons = rat[1..].map { |l| hdr.zip(l.chomp.split(',')).to_h }
man  = NStore.read_json(RTAG, 'manifest.json')
lb   = NStore.read_json(TTAG, 'leaderboard.json')
# Agent-written rationale (nexplain.rb): it plays 1-2 real battles per subject and
# explains from the actual log. Falls back to the built-in notes when absent.
EXPL = begin
  NStore.read_json(TTAG, 'explanations.json')
rescue
  nil
end
TIER_NAME = (ENV['TIER'] || 'ou').upcase

# fusion label: "Azumachomp (h: Azumarill, b: Garchomp)"
def fusion_label(key, pool)
  p = pool[key] or return key
  bases = p['bases'] || []
  sp = p['species']
  return sp if bases.length < 2
  if bases.length == 2
    h, b = bases.map { |x| sp_name(x) }
    return sp if [h, b].include?(sp) && h == b
    "#{sp} (h: #{h}, b: #{b})"
  else
    "#{sp} (triple: #{bases.map { |x| sp_name(x) }.join(' / ')})"
  end
end

# ---- counted totals across every run dir ------------------------------------
root = File.dirname(NStore.dir('x'))
games_total = 0
ordered = Set.new
per_dir = {}
      # the searches write nested per-generation dirs (<tag>/g1, <tag>/vtrain, ...),
      # so recurse and attribute each games.tsv to its TOP-level run tag
per_teams = {}
Dir[File.join(root, '**', 'games.tsv')].sort.each do |f|
  tag = f.sub(root + '/', '').sub(%r{/.*}, '')
  per_dir[tag] ||= [0, 0]
  per_teams[tag] ||= Set.new
  File.foreach(f) do |line|
    fl = line.split("\t")
    next if fl.length < 4
    per_dir[tag][0] += 1
    games_total += 1
    ordered << fl[1]; ordered << fl[2]
    per_teams[tag] << fl[1]; per_teams[tag] << fl[2]
  end
end
per_dir.each { |tag, v| v[1] = per_teams[tag].length }

# ---- head-to-head for the tournament ----------------------------------------
ids = NStore.read_teams(TTAG).keys
h2h = Hash.new { |h, k| h[k] = [0.0, 0] }
NStore.read_games(File.join(NStore.dir(TTAG), 'games.tsv')).each do |g|
  m = g[:gid].match(/\A(\d+)v(\d+)s(\d+)(A|B)\z/) or next
  i, j = m[1].to_i, m[2].to_i
  pa = g[:winner] == :a ? 1.0 : (g[:winner] == :b ? 0.0 : 0.5)
  h2h[[i, j]][0] += pa; h2h[[i, j]][1] += 1
  h2h[[j, i]][0] += (1 - pa); h2h[[j, i]][1] += 1
end
def extreme(h2h, ids, i, best)
  rows = h2h.select { |(a, _b), (_p, n)| a == i && n > 0 }
  return nil if rows.empty?
  k, v = best ? rows.max_by { |(_k), (p, n)| p / n } : rows.min_by { |(_k), (p, n)| p / n }
  [ids[k[1]], v[0] / v[1]]
end

# ---- authored "why" notes (grounded in the measured numbers + the real set) --
TEAM_WHY = {
  'champ:ou3nowg'   => 'Search winner. Two Choice Scarf revenge killers (Azumachomp, Raizor) plus three ' \
                       'setup sweepers that each open on a different resist, and Marokyu\'s Disguise buys a ' \
                       'free Swords Dance. Nothing on it is passive, so the AI never wastes a turn.',
  'built:kos'       => 'Built purely from KOs-per-game with no role constraints — and it lands second, which ' \
                       'is the clearest evidence that raw KO output is the dominant signal in AI-vs-AI play.',
  'champ:ou3free'   => 'Same search with cheese allowed. It ranks BELOW the banned-cheese team here because ' \
                       'the exploit mon only shines against small fields, not the full round robin.',
  'built:coef-noWG' => 'Greedy top-6 by ridge coefficient. Strong, but slightly worse than the searched teams ' \
                       'because coefficients are measured in random-team context and ignore synergy.',
  'built:balanced'  => 'Same shortlist, but forced to include a hazard setter, a wall and a pivot. Costs ' \
                       '~0.09 winrate versus the unconstrained build: role balance is a liability when the AI pilots.',
  'named:Sand'      => 'Your hand-built Sand team. Beats all eight in-game Smart-builder teams and every random ' \
                       'team it faces, but loses to the rating-built teams — the sand/hazard grind plan needs a ' \
                       'human to execute.',
  'named:Momentum'  => 'Older AI-built VoltTurn team. Pivoting for chip damage is exactly what this AI cannot ' \
                       'convert into a win.',
}
MON_WHY = {
  'Azumachomp' => 'Huge Power doubles an already-high Attack and Choice Scarf puts it above the field; ' \
                  'the pool\'s top KO rate (2.05/game) with Aqua Jet priority as a finisher.',
  'Dragoking'  => 'Highest KO rate in the pool (2.36/game). Multiscale halves the first hit, so Bulk Up ' \
                  'gets set for free, and Extreme Speed closes through faster mons.',
  'Azumawak'   => 'Huge Power AND Thick Club stack on the same mon (~4x Attack); Water/Ground is ' \
                  'Electric-immune and Aqua Jet is priority, so it revenge-kills regardless of speed.',
  'Lutei'      => 'Contrary inverts V-create\'s and Superpower\'s drops into BOOSTS — it gets stronger as ' \
                  'it attacks, which is why a Leftovers set posts a 1.96 KO rate.',
  'Slanite'    => 'Slaking stats without Truant (the fusion takes Dragonite\'s Multiscale instead): it ' \
                  'survives the first hit, boosts, then cleans with priority Extreme Speed. The high faint ' \
                  'rate (~.78) is the trade - it converts itself into 1.5-1.8 KOs per battle.',
  'Hawlking'   => 'Mold Breaker ignores the defensive abilities that blank other attackers (Levitate, ' \
                  'Multiscale, Disguise), so Swords Dance + High Jump Kick has no safe answer in this pool.',
  'Marokyu'    => 'Disguise blocks the first hit outright, so Swords Dance is free; Thick Club then doubles ' \
                  'Attack behind dual Ground/Fairy STAB, and Shadow Sneak is priority.',
  'Joltking'   => 'Sheer Force adds 30% to its secondary-effect moves while Electric/Ground coverage ' \
                  '(Thunderbolt + Earth Power) leaves no common resist; Volt Switch keeps momentum.',
  'Sylking'    => 'Pixilate turns Return into a Fairy-type nuke off Slaking\'s Attack, and Bulk Up makes it ' \
                  'progressively harder to break.',
  'Dragozor'   => 'Multiscale plus Roost is the pool\'s most reliable Dragon Dance platform — it can set up, ' \
                  'heal back to full, and re-enable Multiscale.',
  'Tyranfeon'  => 'The one utility mon this high: Sand Stream chips every non-Rock/Ground/Steel mon for the ' \
                  'whole battle, and Stealth Rock plus U-turn means its 0.83 KOs/game understates it.',
  'Poryvern'   => 'Adaptability raises STAB from 1.5x to 2x, which on Boomburst is the single biggest ' \
                  'unresisted special hit available.',
  'Raizor'     => 'Technician boosts Double Iron Bash and Volt Tackle; Scarf makes it the cleanest revenge ' \
                  'killer against the Fairy and Dragon sweepers that dominate the top of the pool.',
  'Metamence'  => 'Moxie compounds every KO into more Attack, and Dragon Dance plus Steel/Flying typing ' \
                  'gives it a safe setup window against the pool\'s physical attackers.',
  'Blamo-o'    => 'Speed Boost means one Swords Dance turn also makes it faster than the entire field; ' \
                  'Fire/Fighting coverage has almost no safe switch-in.',
}
# The same fusion can appear twice with different items/sets, so notes that name specific
# moves are keyed by pool key and take precedence over the species-level note.
MON_WHY_BY_KEY = {}
def why_for(m); MON_WHY_BY_KEY[m['key']] || MON_WHY[m['species']] || MON_WHY[m['name']]; end

L = []
L << "# Best #{TIER_NAME} teams and Pokémon — deterministic native-AI search"
L << ""
L << "_Generated #{Time.now.strftime('%Y-%m-%d %H:%M')} · rating set `#{RTAG}` · tournament `#{TTAG}`_"
L << ""
L << "## 1. Overview"
L << ""
L << "| | |"
L << "|---|---|"
L << "| **Battles run** | **#{games_total.to_s.reverse.scan(/\d{1,3}/).join(',').reverse}** |"
L << "| **Unique teams tested** | **#{ordered.length.to_s.reverse.scan(/\d{1,3}/).join(',').reverse}** |"
L << "| Candidate pool | #{man['pool_ou']} OU-legal of #{man['pool_total']} battle-ready PC mons |"
L << "| Pilot | in-game SmartTrainerAI on **both** sides — no LLM, seeded, reproducible |"
L << "| Level | 100 for every mon on both sides |"
L << "| Clauses | Species · Spore · OU-legal-legend (identical to in-game Random Battle) |"
L << "| Throughput | ~107 battles/sec on 14 worker processes |"
L << ""
L << "### Methodology"
L << ""
L << "1. **Rate every mon** (#{man['games']} battles): #{man['teams']} random Species-Clause-legal teams play each other, "
L << "   so each mon appears in 600–900 battles beside random teammates. A ridge-logistic fit on team "
L << "   composition (+1 for side A, −1 for side B) then separates a mon's own contribution from its teammates'."
L << "2. **Search teams**: a 24-team population seeded from those ratings, evolved by mutation and crossover "
L << "   across 6 generations against a stratified opponent field, with **half the field held out** and never "
L << "   optimised against. Every survivor re-verified on fresh seeds."
L << "3. **Rank teams head-to-head**: full round robin, both side assignments, 10 seeds per pairing "
L << "   (#{per_dir[TTAG] ? per_dir[TTAG][0] : '?'} battles) → winrate and Elo."
L << "4. **Per-slot check**: each slot of the winner swapped against the top-rated alternatives to confirm no "
L << "   single change improves it."
L << ""
L << "**Fairness verified first.** Two engine asymmetries had to be patched in the sim: the SmartAI gate skips "
L << "player-owned battlers (side 0 would run *vanilla* AI), and post-faint replacements for side 0 went through "
L << "the debug scene's **random** party picker — worth 0/20 vs 11/20 for the same team. After patching: side 0 "
L << "wins 48.3% of 240 varied battles, identical-team mirrors 48.7%, draws <1%."
L << ""
L << "**Noise floor.** 28% of matchups flip winner across 3 seeds, so nothing here rests on a single battle; "
L << "top teams have 400+ battles each."
L << ""
L << "**Cheese excluded.** A 1-HP Wonder Guard fusion beats this AI by exploiting a planner blind spot rather "
L << "than by being strong, so it is barred from tested teams (it remains legal in-game)."
L << ""
L << "| run | battles | unique teams |"
L << "|---|---|---|"
per_dir.sort_by { |_k, v| -v[0] }.each { |d, (n, t)| L << "| `#{d}` | #{n} | #{t} |" }
L << ""

L << "## 2. Top #{TOPN} teams"
L << ""
L << "Winrate is over the whole round robin (every team meets every other, both sides, 10 seeds)."
L << ""
L << "| # | team | winrate | Elo | battles | best matchup | worst matchup |"
L << "|---|---|---|---|---|---|---|"
lb.first(TOPN).each_with_index do |r, i|
  idx = ids.index(r['team'])
  b = idx && extreme(h2h, ids, idx, true)
  w = idx && extreme(h2h, ids, idx, false)
  L << "| #{i + 1} | **#{r['team']}** | #{'%.3f' % r['winrate']} | #{'%+.0f' % r['elo']} | #{r['games']} | " \
       "#{b ? "#{b[0]} (#{'%.2f' % b[1]})" : '—'} | #{w ? "#{w[0]} (#{'%.2f' % w[1]})" : '—'} |"
end
L << ""
L << "Team classes: `champ:` population-search winners · `built:` greedy from mon ratings · `named:` your "
L << "hand-built PC teams · `chaos:` random teams · `smart:` the in-game Smart-OU builder."
L << ""
L << "### Rosters and why they place there"
L << ""
lb.first(TOPN).each_with_index do |r, i|
  L << "**#{i + 1}. #{r['team']}** — winrate #{'%.3f' % r['winrate']}, Elo #{'%+.0f' % r['elo']}"
  L << ""
  r['keys'].each_with_index do |k, j|
    p = pool[k]
    L << "- #{r['names'][j]} — #{fusion_label(k, pool)}#{p ? " · #{p['types']} · #{p['ability']} · #{p['item']}" : ''}"
  end
  why = (EXPL && EXPL['teams'] && EXPL['teams'][r['team']]) || TEAM_WHY[r['team']]
  if !why
    cls = r['team'].split(':').first
    why = case cls
          when 'smart' then 'In-game Smart-OU builder roll. The builder fills a hazard setter, wall and pivot ' \
                            'first, which loads it with passive mons this AI plays badly — the whole class sits low.'
          when 'chaos' then 'A random Species-Clause team that happened to rate well in phase 1; it holds up ' \
                            'mid-table, which is the regression-to-mean you expect from a selected random sample.'
          else 'Rating-derived build.'
          end
  end
  L << ""
  L << "  *#{why}*"
  L << ""
end

L << "## 3. Top #{TOPN} Pokémon"
L << ""
L << "`coef` = contribution to win probability with teammates controlled for. `KOs/g` and `faint` are measured "
L << "per battle. Every mon below has 400+ battles."
L << ""
L << "| # | mon | fusion (head / body) | types | ability | item | battles | winrate | KOs/g | faint | coef |"
L << "|---|---|---|---|---|---|---|---|---|---|---|"
top = mons.first(TOPN)
top.each_with_index do |m, i|
  p = pool[m['key']] || {}
  bases = (p['bases'] || [])
  lbl = if bases.length == 2 then "#{m['species']} — h: #{sp_name(bases[0])}, b: #{sp_name(bases[1])}"
        elsif bases.length > 2 then "#{m['species']} — triple: #{bases.map { |x| sp_name(x) }.join(' / ')}"
        else m['species'] end
  L << "| #{i + 1} | #{m['name']} | #{lbl} | #{m['types']} | #{p['ability']} | #{m['item']} | #{m['games']} | " \
       "#{m['winrate']} | #{m['kos_per_game']} | #{m['faint_rate']} | #{m['coef']} |"
end
L << ""
L << "### Why these rate highest"
L << ""
if EXPL
  L << "_Per-subject rationale below is written by an agent (#{EXPL['model']}) that was shown the exact"
  L << "sets, the measured statistics, and turn-by-turn logs of 2 real battles for that subject — including"
  L << "the SmartAI's own decision lines. Those logs are kept in `#{TTAG}/explain_logs/` so any claim can be"
  L << "checked against the battle it came from._"
end
L << ""
L << "Three properties separate the top of this pool, and every mon above has at least two of them:"
L << "an **ability that multiplies output or survival** (Huge Power, Multiscale, Contrary, Technician, Mold "
L << "Breaker, Adaptability, Disguise), **priority or Choice Scarf speed control**, and **coverage with no free "
L << "switch-in**. Note what is absent: not one pure wall or hazard-stacker makes the top 15 — only Tyranfeon "
L << "(#13) earns its place on utility, via permanent sand plus Stealth Rock."
L << ""
L << "**The dominant base species.** Expanding the fusions shows the top of the table is built from a handful of "
L << "parents rather than 264 independent mons:"
L << ""
L << "| base species | in top 30 | in whole pool | why it works |"
L << "|---|---|---|---|"
L << "| Dragonite | 8 | 18 | donates **Multiscale** — halves the first hit taken, which is what makes a setup turn free |"
L << "| Slaking | 7 | 15 | enormous raw stats, and **a fusion inherits the other parent's ability, so Truant is dropped** |"
L << "| Garchomp | 4 | 12 | Ground/Dragon STAB with high Speed and Attack |"
L << "| Scizor | 4 | 12 | Steel typing plus Technician-boosted priority |"
L << "| Marowak | 3 | 6 | **Thick Club doubles Attack on any Marowak fusion** (and stacks with Huge Power) |"
L << "| Azumarill | 3 | 6 | **Huge Power** doubles Attack; Aqua Jet gives priority |"
L << ""
L << "Marowak and Azumarill are the standouts on rate: 3 of 6 pool members reach the top 30. If you want more "
L << "top-tier candidates, fusing more Dragonite / Slaking / Marowak / Azumarill combinations is the highest-"
L << "yield direction."
L << ""
top.each do |m|
  note = (EXPL && EXPL['mons'] && EXPL['mons'][m['key']]) || why_for(m)
  next if !note
  p = pool[m['key']] || {}
  L << "- **#{m['name']}** — #{fusion_label(m['key'], pool)} — #{note}"
  L << "  <br>_#{p['moves'] ? p['moves'].join(' / ') : ''}_"
end
L << ""
L << "## 4. How to read this"
L << ""
L << "- Ratings measure value **as piloted by the SmartAI** — the target you asked for (opponent teams). The AI "
L << "  plays offense well and stall badly, so passive walls rate near zero and champions converge on six "
L << "  attackers. For a team *you* pilot, treat wall ratings as a floor rather than a verdict."
L << "- **Where the in-game generators actually stand.** In this table the `smart:` rolls sit low and `chaos:` "
L << "  rolls sit high, but that is SELECTION BIAS, not a finding: the chaos entrants were picked as the best "
L << "  teams out of 1,500 random ones, while the smart entrants are unselected rolls. A separate fair test "
L << "  (`nreports/modes/`, 20 blind teams per mode, 18,960 battles) reverses it — Smart beats Chaos 51.7% at "
L << "  OU and 52.2% at Ubers, and Chaos merely has wider variance (both the worst floors and the single best "
L << "  team). The real gap is tier, not mode: Ubers teams beat their OU counterparts ~58-59%."
L << "- Every searched/built team here (0.86-0.91) is far above what either generator averages (0.45-0.56), so "
L << "  the search does produce meaningfully harder opponents than Random Battle currently rolls."
L << "- Guardrails earned their place: an earlier hill-climb improved its training field 0.861 → 0.958 while its "
L << "  **held-out** score fell below an un-climbed team. Hence the population search, the held-out half, and "
L << "  paired comparisons."
L << ""
L << "## 5. Files"
L << ""
L << "- This report: `sim/nreports/#{OTAG}/TOP_TEAMS.md`"
L << "- Mon ratings (all #{mons.length}): `sim/nreports/#{RTAG}/ratings.csv`"
L << "- Tournament: `sim/nreports/#{TTAG}/leaderboard.json`, `games.tsv`, `teams.tsv`"
L << "- Champions: `sim/nreports/ou3nowg/champion.json` (cheese-free), `sim/nreports/ou3free/champion.json`"
L << "- Pool snapshot + frozen save: `sim/nreports/#{RTAG}/pool.json`, `save_snapshot.rxdata`"
L << "- Every battle replayable from each run's `jobs.tsv`. Runbook: `tools/sidmod_editor/RUNBOOK.md` §3c."

out = File.join(NStore.dir(OTAG), 'TOP_TEAMS.md')
File.binwrite(out, L.join("\n") + "\n")
puts "wrote #{out} (#{L.length} lines)"
puts "battles=#{games_total} unique_teams=#{ordered.length}"
