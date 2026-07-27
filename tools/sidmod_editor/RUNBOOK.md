# sidmod_editor — Runbook

Offline toolchain for the Infinite Fusion competitive project. Three workflows:
1. **Create/edit Pokémon** in a save (`edit_save.rb` + `apply.ps1`) — inject, swap, move, rename boxes.
2. **Inspect fusions** (`sim/fusion_inspector.rb` + box exporters) — ground-truth typing/stats/weaknesses.
3. **Battle-sim** (`sim/`) — headless real IF engine: parallel A/B benchmarks (Sonnet-piloted) **and** hands-on drive mode (a human/agent pilots turn-by-turn).

**All read-only on saves unless you explicitly `apply.ps1` (non-DryRun).**

## Prerequisites
- **Ruby:** `C:\Ruby31-x64\bin\ruby.exe` (shorthand `RB` below).
- **RUN FROM THE GAME ROOT** `C:\Games\InfiniteFusion` — the engine boots `Data/Scripts.rxdata` via a *relative* path. Anything under `sim/` that calls `SimEngine.boot` dies with "No such file – Data/Scripts.rxdata" if run from elsewhere. (Box exporters / edit_save use `%APPDATA%` paths and don't care.)
- **API key (piloted battles only):** one line in `sim/.apikey` (gitignored, never printed).
- **Saves:** `%APPDATA%\infinitefusion\File A.rxdata` … `H`. Active slot = **File A**. Backups auto-written to `%APPDATA%\infinitefusion\sidmod_manual_backups\<stamp>\` by apply.ps1.
- **Filter boot noise** on any engine run: `2>&1 | grep -vE "cannot get AST|001_RPG|003_Errors|Exception \`|SimEngine|warning:"`

---
## 1. Create / edit Pokémon  (`edit_save.rb` via `apply.ps1`)

**Pipeline:** `apply.ps1` refuses if the game is RUNNING → backs up File A → `edit_save.rb` builds on a copy → `verify_edit.rb` gates on **"collateral problems: NONE"** (deep value-equality; only spec-targeted slots may change) → atomic-replace. **Game must be CLOSED; load AFTER the write.**

```
powershell -File tools\sidmod_editor\apply.ps1 -Spec spec.json -Slot A -DryRun   # preview + gate
powershell -File tools\sidmod_editor\apply.ps1 -Spec spec.json -Slot A           # apply
```

**Spec = `{"pokemon":[ {entry}, … ]}`. `box` and `slot` are 0-INDEXED** (Box 23 = box 22; slot 1 = slot 0). Modes:

| mode | keys | effect |
|--|--|--|
| `add` | head+body OR species, ability, item, nature, nickname, level, moves[], evs{} | build into first free slot of `box` |
| `replace` | + `box`,`slot` | build into that exact slot (overwrites) |
| `edit` | `box`,`slot` + any of item/ability/moves/nickname **and/or** level/evs/ivs/nature | in-place, preserves species+PID+OT; **recomputes stats + maxes happiness** when level/evs/ivs/nature is given (else item/move-only, no recompute — safe for triple fusions) |
| `delete` | `box`,`slot` | set slot = nil |
| `move` | `from_box`,`from_slot` → `box`,`slot` | relocate the EXACT mon (preserves PID/EVs/exp); dest must be empty |
| `rename_box` | `box`,`name` | rename a box |

- **Fusion species:** give `"head"` + `"body"` (head→type1/HP/SpA/SpD, body→type2/Atk/Def/Spe). Forms with underscores (e.g. `LYCANROC_D`) resolve here via the dex table — but the sim inspector's normalizer strips the `_` (see §2).
- **WRITE THE JSON WITH THE `Write` TOOL, not PowerShell heredocs** — PS adds a UTF-8 BOM that makes `JSON.parse` choke (`unexpected token at '﻿{'`).
- `verify_edit.rb` whitelists exactly the spec's replace/edit/delete/move slots (+ `ALLOWED_BOX` for rename_box); any *other* changed slot → "collateral problems" and the write is rejected.

**Read/scan helpers (read-only):**
```
RB tools\sidmod_editor\survey_boxes.rb "%APPDATA%\infinitefusion\File A.rxdata"     # all boxes: idx/name/count/sample
RB tools\sidmod_editor\export_box.rb   "%APPDATA%\infinitefusion\File A.rxdata" <idx0> out.txt   # one box, full detail
RB tools\sidmod_editor\read_save.rb / analyze_team.rb / scan_fusions.rb GROUND FLYING [nolegend]
```

### 1b. Mass upgrade — batch-coach many PC mons to optimal L100 sets
Turn under-built PC mons into competitive **Lv100 + item** mons (which also enrolls them in the pause-menu **Random Battle** pool — §sidmod). One-off pipeline (scripts staged under `sim/`, driven from chat):
1. **Full backup first:** `cp "$APPDATA/infinitefusion/"*.rxdata <rollback>/` (all 8 slots) — a mass edit deserves a hard rollback beyond apply.ps1's per-write backup.
2. **Worklist** — scan target boxes for mons that need work: *not-yet-eligible* (level<100 OR no item) **plus** *already-eligible-but-weak* (EV total <252). Write `sim/upgrade_worklist.json` (box/slot/head/body/level/item/moves).
3. **Engine-enrich** (one boot) — per worklist fusion compute real L100 stats, typing, abilities, and the **legal movepool = union of head+body (level-up ∪ tutor ∪ egg)**; write `sim/upgrade_enriched.json`. **GOTCHA:** after `SimEngine.boot`, `JSON.parse` symbolizes keys → load species_table/worklist with `ClaudeClient::PARSE` (pre-boot stdlib parser) for STRING keys, or every dex/field lookup silently returns nil.
4. **Coach** — fan out ~1 Agent (general-purpose) per ~6 mons; each reads its slice of the enriched file and writes a validated set (nature/EVs/IVs/item/4 moves) to `sim/upgrade_sets/set_<i>.json`. Rules the agents enforce: moves ⊂ movepool, EVs sum ≤508 & ≤252 each, ability ∈ list, **item is a REAL id** (e.g. `HEAVYDUTYBOOTS` does NOT exist in this IF build — validate against `Data/items.dat`; fall back to LIFEORB/LEFTOVERS).
5. **Aggregate + apply** — merge the set files into `{"pokemon":[{"mode":"edit","box","slot","level":100,"nature","ability","item","evs","ivs","moves"}, …]}`, **DRY-RUN** (`edit_save` on a copy + `verify_edit` → "collateral problems: NONE" whitelists exactly the edited slots), then `apply.ps1 -Slot A`. The `edit` mode recomputes stats + maxes happiness.

Reference run (this session): 53 mons coached → **all 309 scope mons** (fusion boxes 18-25 idx17-24, Squads idx33-35, vanilla UU/OU/Uber idx37-39) are now L100+item. Pool the Random Battle feature sees = every L100+item PC mon (was ~396, incl. pre-existing collection boxes).

---
## 2. Inspect fusions  (`sim/fusion_inspector.rb` — the ground-truth ORACLE)

Builds a candidate in the real engine and reports actual typing / stats-vs-both-parents / 4x-2x-immune weaknesses / resolved ability / auto-flags (TYPING-NO-GAIN, STAT-TAX, NEW-4x-WEAK, DEAD-ABILITY, WEATHER-ABILITY, INVALID). **This is the oracle — use it before trusting any typing/stat intuition; my priors have been wrong repeatedly (Ferro/Skarm is Steel/Flying not Grass/Flying; Rock/Water SpD in sand; etc.).**

```ruby
# from a .rb run at GAME ROOT (or standalone: RB tools\sidmod_editor\sim\fusion_inspector.rb)
require_relative 'fusion_inspector'; SimEngine.boot; $DEBUG=false
puts Inspect.render(Inspect.check({"head"=>"AEGISLASH","body"=>"TOXAPEX","ability"=>"REGENERATOR",
  "item"=>"LEFTOVERS","nature"=>"CALM","moves"=>%w[KINGSSHIELD SPECTRALTHIEF SCALD LIGHTSCREEN],
  "evs"=>{"HP"=>252,"SPECIAL_DEFENSE"=>252,"DEFENSE"=>4}}))
```

**Species-table gotchas:**
- **Silent Pikachu fallback:** species not in IF's dex resolve to **dex 25** (Jellicent/Toxicroak/Gastrodon/Seismitoad/Maractus/Excadrill all = Pikachu). `Editor.valid_species?` round-trips the id to catch it; `GameData::Species.exists?` LIES (returns true). Always sanity-check a new species.
- **Forms:** `Editor.normalize` strips non-alphanumerics, so `LYCANROC_D` → `:LYCANROCD` → invalid in the inspector. Workaround: pass the **integer dex** as head/body to `BuildTeam.mon` (`getDexNumberForSpecies` accepts Integers). edit_save (§1) handles the underscore fine.
- fusiondex.com reference: `https://infinitefusiondex.com/details/<headDex>.<bodyDex>`. "Move Expert" moves (fandom List_of_Move_Expert_Moves) exist OUTSIDE normal learnsets (e.g. Sandslash→Thousand Arrows) — never call a move unobtainable from moves/tutor/egg alone.

Verified mechanics worth not re-deriving: **ability-set weather is PERMANENT** (`pbStartWeather` duration −1); **weather abilities fire slowest-LAST so the slower setter wins** a simultaneous clash; **rain ×1.5 Water / ½ Fire, sun ×1.5 Fire / ½ Water**; **Rock types get ×1.5 SpD in sandstorm**; **Huge Power ×2 and Thick Club ×2 STACK** (→ ×4, Marowak/Cubone fusions); **Thousand Arrows / Smack Down hit Flying at 1x** (engine fn 11C).

---
## 3. Battle sim

Boot check: `RB tools\sidmod_editor\sim\boot.rb`. Build a field of opponents at L100 from the real AI trainer data: `build_gauntlet.rb` (E4 + Champions) / `build_bluegauntlet.rb` (Blue Classic/Remix/Expert + Cynthia/Gold kaizo) → `sim/reports/<tag>/field_specs.json`.

### 3a. Battles OFF (automated, Sonnet-piloted) — `prun.rb` is the modern path
`prun.rb` shards every bo-N matchup into **N seeded single-game jobs** and fans them ALL across cores (`matchup_worker.rb`, one process each — the engine uses process globals so threads aren't safe). A 12-matchup bo3 sweep = 36 parallel games, not 12 serial series.

```
RB tools\sidmod_editor\sim\prun.rb  jobs.json  <out_tag>
```
`jobs.json` = array of `{ "teamA":[specs], "teamB":[specs], "planA_name":"OUSand" (or inline "planA"), "planB_name":"OURain", "games":5, "cap":60, "label":"…" }`. Results → `sim/reports/<out_tag>/`, aggregated by label. (Generate jobs with a small `-rjson` ruby script that reads `reports/final_v2/field_specs.json` + a gauntlet field and swaps mons per config — see `vary_sand_verify.rb` / the `absorber_jobs` pattern in memory.)

- **Pilot = Sonnet** (`claude-sonnet-5`), via `SimAgent.claude_policy(plan, model:)`. `PILOT_SYSTEM` in `agent_battle.rb` carries general competitive doctrine (game-plan-first, weather-wars, hazards, anti-loop); per-team `plan` strings live in `roster.rb PLANS`.
- **bo3 is the floor for signal; bo1 is a coin flip.** Weigh battle data WITH static (§2) — never overfit to a small/noisy sample; verify every change vs the whole suite (anti-overfit gate).
- Legacy serial runners still exist (`run_iteration.rb`, `run_llm_tournament.rb`, `validate.rb <tag>`) but `prun` supersedes them for speed.

### 3b. Battles HANDS-ON (a human/agent pilots side 0) — `interactive_battle.rb`
The engine blocks each turn and writes state to a file; the pilot writes back the move. Opponent (side 1) stays Sonnet — apples-to-apples with 3a.
```
RB tools\sidmod_editor\sim\interactive_battle.rb <comm_dir> <opp_key> [seed] [teamA_specs.json]
```
File protocol in `<comm_dir>`:
- engine → `ib_state.txt`: `DECISION <n>\n<TURN CARD>` (move turn) or `DECISION <n> REPLACE\n<party list>` (faint/pivot pick)
- pilot → `ib_action.txt`: `DECISION <n> move <idx> | <reason>`  or  `switch <idx>` (idx must match the counter; move idx is **0-based**)
- end → `ib_state.txt` starts `GAME OVER`; full log in `ib_result.txt`
- env: `IB_PLAN=<planKey>` (team notes shown to pilot); `IB_NATIVE_OPP=1` makes side 1 the **native upgraded AI at max skill** (`PBTrainerAI.bestSkill`) instead of Sonnet — this is what beats Sid in-game (Belly Drum lines etc.).

**TURN CARD (deterministic — trust it over instinct; it exists because manual type/damage math cost two games).** Each move turn `build_prompt` now prints, all computed from the real engine: (1) **foe DEF PROFILE** — full weak/resist/immune with multipliers from the real type chart, ability-adjusted (Levitate/Water Absorb/Flash Fire/Sap Sipper/… fold to 0×; Thousand Arrows/Smack Down ignore Levitate); (2) **your 4 moves** with ability-aware effectiveness (`IMMUNE(ability)`) + **damage as a lo–hi% range** + KO label; (3) **BENCH ANSWERS** — each of your alive bench mons' best-move eff (OFF) and how it takes foe STAB (DEF), with a `<== clean answer` marker for SE+resists; (4) **ENEMY PIVOTS** — their bench mons' take-from-you / hit-on-you; (5) **FLAGS** — `TRIVIAL`(faster+guaranteed OHKO) / `DANGER`(slower, OHKO'd first → don't set up) / `SAFE`(4HKO+ → free setup) / `PHAZE`(foe boosted). `est_damage` now models variable-BP moves (Water Spout/Eruption scale with attacker HP, Gyro/Electro Ball with speed) — this killed the bogus "400% OHKO" Water-Spout alarms — and returns 0 through ability immunities.

**SAVE / REWIND turn-by-turn** (deterministic replay, not snapshots): every pilot decision is journaled to `ib_journal.tsv`. To rewind, reply `DECISION <n> rewind <k>` — the battle is thrown out and re-run on the SAME seed, auto-replaying journaled decisions `1..k-1` (byte-identical because seeded), then hands control back **live at decision k**. New choices from k overwrite the journal tail → you can branch. Implemented with `throw(:rewind,k)`/`catch` (NOT `raise` — `SimBattle.run`'s `rescue Exception` would swallow it as a draw).

Pilot loop (poll with a bash `until head -1 ib_state.txt | grep -qE "DECISION <n+1>|GAME OVER|REPLACE"; do sleep 2; done`). Fork a `subagent_type:"fork"` agent to pilot the control arm of an A/B on the same seed. Faint replacements route to the pilot via `$SIM_REPLACE` (hooks `PokeBattle_Battle#pbSwitchInBetween`) and are journaled/rewindable too.

### Discipline
Launch long runs in the **background**; read one full log after the first game to confirm 0 fallbacks + sane play, then trust it.

### 3c. Battles NATIVE + MASS SCALE (no LLM, ~100 games/sec) — `nbattle.rb` & friends
For scanning thousands of team options: the deterministic **SmartTrainerAI plays BOTH sides**, no API calls, seeded and reproducible. Boot 0.5s, battle ~0.09s, 14 workers ≈ **100 games/s** (15k games ≈ 2.5 min).

```
RB sim\nsearch_ou.rb sample <tag> [teams] [opp/team] [workers]   # phase 1: rate every OU pool mon
RB sim\nsearch2.rb <rating_tag> <out_tag> [gens] [seeds] [workers] [BAN]  # phase 2: population search + per-slot LOO
RB sim\ntourney.rb <rating_tag> <t_tag> [seeds] [chaos_k] [workers]       # team-vs-team round robin + Elo
RB sim\nverify.rb          # proof pass: logged fights + fairness blocks
RB sim\nsymmetry.rb [matchups] [seeds]   # side-bias + noise-floor measurement
```
`BAN` = comma-separated pool keys, or the token `WONDERGUARD` (expands to every Wonder Guard mon — see below).

**Pool** = every PC mon at Lv100 holding an item, with the in-game Random Battle clauses (Species / Spore / OU-legal-legend), keyed `b<box>s<slot>`. Reuses `SidmodRandomOpp` so the sim's OU tier is *exactly* the tier the game generates.

**Shipping a ladder's champions into the game — `sim/nexport_apex.rb`.**

```
RB sim\nexport_apex.rb ladder_ou4 15        # -> Data/sidmod/ou_apex.rxdata (in-game "OU Apex")
RB sim\nexport_apex.rb <tag> [count] [out]
```

Freezes the top `count` teams by Elo into a Marshal pack the game reads. **It exports the real Pokémon objects, not the `b<box>s<slot>` keys** — a team's keys index that run's `save_snapshot.rxdata`, and they rot against the live save: on `ladder_ou4`, 32 of the 38 mons the top 15 depend on still matched but **6 did not**, including a slot that had gone from a Lv100 Blisclops wall to a Lv50 Klefmime. Key-resolution at battle time would have fielded teams that were never the ones rated. The pack is therefore self-contained: the apex teams need not exist in the PC at all. Slot 0 of each team is the lead the ladder chose. Re-run the exporter after any new ladder run; the game picks up the new pack on next launch.

**The archetype generator now exists on BOTH sides.** `sim/narchetype.rb` (`Gen#archetype`, rating-driven, used by the ladder) is mirrored in-game by `055_sidmod/RandomOpponent.rb` "Smart v2", which builds the same 11 plans from the live PC pool — no ratings available there, so it substitutes Lv100 stat total + type freshness, and it also runs a port of `nlead.rb`'s lead picker. Call it head-less with `SidmodRandomOpp.build_team_named(:smart2, tier, seed, :sand)` → `[refs, archetype_used]`; `:random`/`nil` tries all 11 in shuffled order. The old `build_team(sel, tier, seed)` 3-arg form is unchanged, so `nbattle.rb` / `nmodes.rb` / `nladder.rb` / `nbuild_ou.rb` are unaffected.

**Two fairness patches are mandatory and live in `nbattle.rb`** (sim-only, no game files touched):
1. `sidmod_smart_ai?` exempts player-owned battlers → without the patch side 0 runs **vanilla** AI and side 1 runs Smart AI.
2. `pbSwitchInBetween` routes player-owned battlers to `pbPartyScreen`, and the debug scene's version picks a **RANDOM** replacement → side 0 threw random mons in after every faint. Measured cost before the fix: same team **0/20 as side 0, 11/20 as side 1**.
   Post-fix fairness: side 0 wins 48.3% over 240 varied games; identical-team self-mirrors 48.7%. Re-check with `nsymmetry.rb` after touching the AI.

**A third mandatory patch lives in `sim/engine.rb` `patch_runtime` (added 2026-07-27, sim-only).** The sim's `$Trainer` is an `NPCTrainer` stub, but the battle path calls **Player-only** progression APIs on it — `$Trainer.stats&.incr_nb_pokemon_defeated` on every KO (`011_Battle/001_Battler/003_Battler_ChangeSelf.rb` ~57), `&.incr_nb_battles_lost` at battle end (`003_Battle_StartAndEnd.rb` ~476), and `$Trainer.complete_challenge(...)` from the in-battle PokeNav hooks (`053_PIF_Hoenn/PokeNav/Challenges/ChallengeHooks/ChallengeHooks_Battle.rb`). `#stats` and `#complete_challenge` are defined on `Player` only, so these raised `NoMethodError` — the `&.` does **not** help, because the *receiver* is the problem, not the value.

**Why this was invisible:** `nbattle.rb` `run` swallows any in-battle raise into `dec = 5`, which maps to `winner: :draw`. (`run_mons` did the same and recorded *nothing*; it now sets `@last_error` too. Check **`NativeSim.last_error`** after either call — a `:draw` you didn't verify is not a result.) So a broken engine call does not crash — **every battle silently scores 0.5 and every matchup converges on a perfect 0.500**. Measured on the current tree: without the patch, 20/20 plain SMART-vs-SMART games errored (14x `stats`, 6x `complete_challenge`); with it, 19 decisive + 1 real draw. Both call sites arrived in **Update 6.8 (commit `6a6f126a1`, 2026-07-10)**; the `nreports/ou4/ratings.csv` produced 2026-07-26 still shows a healthy 0.33–0.73 winrate spread, so it predates the break becoming active — but **any run whose per-matchup numbers look suspiciously like exactly 0.500 should be re-run**, and a driver is worth teaching to assert on `NativeSim`'s `@last_error` rather than trusting a draw.

**SAVE SNAPSHOT (hard requirement).** Keys are (box, slot) and the live save changes *while Sid plays* — observed mid-run: a mon vanished from box 14, and 5300/5520 games died on `unknown pool key`. Every driver calls `NativeSim.snapshot_save!(<run dir>)`, which copies File A into the run dir and exports `NSIM_SAVE`; workers inherit it. Re-running an old tag reuses its snapshot, so ratings stay comparable.

**Storage** — `sim/nreports/<tag>/`: `manifest.json` (config + clauses + `llm:false`), `pool.json` (mon snapshot), `save_snapshot.rxdata`, `teams.tsv`, `jobs.tsv` (exact replay), `games.tsv` (winner/turns/**per-slot KOs, faints, end-HP**), `ratings.csv`, `champion.json`, `report.md`. TSV not JSON (boot breaks `JSON.generate`); per-worker shards + gid skip = resumable.

**AI QUALITY LOOP (added 2026-07-25/26).** The SmartTrainerAI was measurably offense-only: 1 heal taken
out of 119 chances, 191 no-op moves per 6 battles, chip damage absent from its TTK model. Fixed in
`055_sidmod/SmartTrainerAI.rb` v2+v3 (see sidmod.txt for the full entry). Tools for iterating on it:

```
RB sim
playstyle.rb <rtag> <otag> [seeds]    # archetype behaviour: what the AI actually clicked
RB sim
audit.rb <rtag> <otag> [model]        # agent reads full logs, lists misplays + rating /10
RB sim
ablate.rb <rtag> <otag> [mu] [seeds] [only]   # per-feature ablation (full AI vs AI-minus-one)
RB sim
beamtune.rb <rtag> <otag> [mu] [seeds] [only] # A/B numeric tunables head-to-head
RB sim
lookahead_cost.rb                     # price search before building it
```
`$SIDMOD_AI_FEATURES = {0=>{}, 1=>{heal: false}}` switches features/tunables PER SIDE (nil in game),
which is how one AI version plays another. **METHOD WARNING:** most correctness fixes score ~0.500 in
self-play ablation because both sides make the same mistake symmetrically — judge those on blunder
counts and archetype viability, not winrate. Only chip-status (+0.081) and the beam (+0.044) moved
winrate. Search was priced first and real tree search rejected (node snapshot = ~2 ms → 2-ply = 17 s
per decision); the beam runs on an abstract state instead, so it is microseconds per node.

**RATINGS ARE AI-VERSION-SENSITIVE.** Every `ratings.csv` under `nreports/` was produced by the
pre-v2 AI that could not pilot defence, so its wall/utility ratings are too low. Re-run the sweep
after any AI change before trusting defensive mons.

**Interpretation caveats (important):**
- Ratings measure value **as piloted by SmartAI**. The AI plays aggro well and stall/setup badly, so passive walls are systematically undervalued (bottom of `ratings.csv` is full of Leftovers walls at 0.0 KOs/game). Right signal for choosing *opponent* teams; a floor, not a verdict, for a team Sid pilots himself.
- The search will find **AI blind spots** if you let it: a 1-HP **Wonder Guard** fusion (Abinja) took a small training field to 97.9% and every slot alternative was worse. Run with and without `BAN=WONDERGUARD` and compare.
- Noise floor: **28% of matchups flip winner across 3 seeds**. Single games are meaningless; use ≥6 seeds × 2 orders and paired comparisons, and always keep a **held-out** field (`nsearch2` splits TRAIN/TEST — first hill-climb attempt went TRAIN 0.861→0.958 while TEST *fell* below an un-climbed team).

---
## Gotchas (current)
- **PILOT IS SONNET NOW** (the old "use Haiku, Sonnet thinking eats the budget" advice is DEAD). `ClaudeClient.complete` defaults `thinking:{type:"disabled"}` (fast structured JSON) and takes `cache:true` (prompt-caches the big static `PILOT_SYSTEM` — big cost/latency win). `complete_tools` uses adaptive thinking for the coach.
- **`"(fallback: …)"` in a log = that turn was random** (API/parse fail). A fallback-heavy run is garbage.
- **SimEngine.boot patches JSON:** post-boot `JSON.parse` **symbolizes keys** (stringify top-level job keys in workers) and `JSON.generate` **fails to escape quotes** in pilot reasons (matchup_worker writes TSV + plain-text logs, never JSON). `claude_client.rb` grabbed stdlib JSON before boot for API use.
- **Species → Pikachu fallback** (§2). **Run from game root** (§Prereqs).
- `save_data` is a no-op in the shim — the sim can never write game files (only `apply.ps1` writes saves).

## Known-OPEN harness bugs (found in hands-on play; symmetric across both sides so benchmarks stay comparable)
- **Choice locks not enforced in sims** — `legal_moves` has `rescue true` on `pbCanChooseMove?`, so Choice-locked mons pick freely (inflates Scarf/Band; cost a mon in a hands-on game).
- **SWITCH OPTIONS sometimes truncated** — `legal_switches` `rescue false` swallows engine errors for some party slots.
- **Early-end** — opponent side occasionally "concedes" with an able mon un-sent; reproduced only in piloted games, not random-policy. `pbCanChooseNonActive?` diagnostics (`$SIM_DEBUG_REPLACE`) stayed silent; next step = log `pbJudge`/`@decision` transitions.

## Key source files
`engine.rb` (headless boot) · `shim.rb` (RGSS/save stubs) · `fusion_inspector.rb` (oracle) · `agent_battle.rb` (state extractor + `PILOT_SYSTEM` + `est_damage`/`move_type_eff` + `$SIM_REPLACE`) · `prun.rb`+`matchup_worker.rb` (parallel runner) · `interactive_battle.rb` (drive mode) · `claude_client.rb` (API + caching) · `roster.rb` (plans + field) · `build_team.rb`/`editor.rb` (spec→mon) · `../edit_save.rb`+`../verify_edit.rb`+`apply.ps1` (save writes). Team facts live in memory `v2-competitive-teams-delivered.md`; tooling in `sidmod-sim-tooling.md`.
