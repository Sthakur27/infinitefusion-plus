# UPDATES

Running log of project steps — mons built, tooling added, research run, tier changes.
Newest last. One entry per meaningful step: **what** changed, **why**, and how to
**reproduce or revert** it.

Scope split:
- **`UPDATES.md`** (this file) — collection + offline toolchain + research steps.
- **`sidmod.txt`** — engine/gameplay patches (source of truth for in-game mods, with revert steps).
- **`README.md`** — one-line changelog of user-visible milestones, pointing here.

---

## 2026-07-29 · Move legality audit — 62 illegal moves fixed

Audited all 456 L100 mons in the PC against the game's own `pbGetLegalMoves` (level-up ∪
tutor/TM ∪ baby-species egg moves; for fusions, the union of both parents' pools).

- 104 flags → 42 confirmed legit (signature / Move-Expert / Smeargle-via-Sketch), **62 illegal**.
- Replacements chosen to respect each mon's physical/special orientation, then applied.
- Root cause of a long-standing false-positive problem: `get_baby_species` is `private` in
  `008_Species.rb`; RGSS (Ruby 1.8) allowed private calls with an explicit receiver, Ruby 3.1
  does not. Fixed in the harness with `GameData::Species.send(:public, :get_baby_species)`.
  Baby-egg-move resolution alone cut 163 flags → 104.
- 0 EV violations found.

**Tooling:** `sim/move_legality_audit.rb`, `sim/move_suggest2.rb` (orientation-aware
replacement picker), `apply_move_fixes.rb` (offline patcher — uses `StubLoader` only, because
booting the engine breaks re-serialization with `Color#marshal_dump`).

---

## 2026-07-29 · Build batch — No Guard, Light Ball, Simple

- **Zapchamp** (Zapdos/Machamp) & **Zaplurk** (Zapdos/Golurk) — No Guard: 100%-accurate
  **Zap Cannon** (guaranteed paralysis) + **Dynamic Punch** (guaranteed confusion).
- **Volcabarel** (Volcarona/Bibarel) — **Simple** doubles Quiver Dance (+2 per use).
- **Volcachu** (Volcarona/Pikachu) — Light Ball special sweeper.

Spec: `spec_noguard_zap.json`, `spec_volca_pair.json`.

---

## 2026-07-29 · Mimikyu / Disguise crew

Free-turn setup abusers. **Mimibat** ×2 (Mimikyu/Crobat — support pivot and SD sweeper),
**Mimigar** (Mimikyu/Gengar, **Spectral Thief** — confirmed legal via wiki),
**Mimirona** (Mimikyu/Volcarona, Quiver Dance), **Dragokyu** (Dragonite/Mimikyu, DD).
Plus **Togecune** (Togekiss/Suicune) — the Fairy/Water inverse of Aqualift, +10 SpA/+6 Def
and a better defensive typing for this meta.

Spec: `spec_mimibat.json`, `spec_mimi_trio.json`, `spec_togecune.json`.

---

## 2026-07-29 · Rock Head recoil crew

Recoil-free Head Smash / Wood Hammer / Double-Edge / Brave Bird.
**Toron** (Torterra/Aggron, Head Smash tank), **Tordactyl** (Torterra/Aerodactyl, fast),
**Aggbat** (Aggron/Crobat, Steel/Flying pivot — note Swords Dance is *not* legal on it),
**Marobat** (Marowak/Crobat — Thick Club **and** SD, recoil-free Brave Bird).

Spec: `spec_rockhead.json`, `spec_crobat_rockhead.json`.

---

## 2026-07-30 · Serene Grace / No Guard batch + Absol trio

- **Togetei** (Togekiss/Entei) & **Blistei** (Blissey/Entei) — Serene Grace makes Sacred Fire a
  **100% burn**. Both fusion orders were flipped from the original request after the stat check
  (Entei/Blissey gives Atk 44; Blissey/Entei gives HP 208 / SpD 115).
- **Aerochamp** (Aerodactyl/Machamp), **Mabat** (Machamp/Crobat) — No Guard Dynamic Punch.
- **Crodactyl** (Crobat/Aerodactyl) — Rock Head Brave Bird, Spe 129.
- **Absol trio**: **Mimisol** (Mimikyu/Absol — Disguise, dual-STAB priority),
  **Abnite** (Absol/Dragonite — Multiscale, Atk 132), **Abking** (Absol/Slaking — Super Luck
  sidesteps Truant, **Atk 149**).

Spec: `spec_batch_serenegrace_noguard.json`, `spec_absol_trio.json`.

---

## 2026-07-30 · Metagame research program

Six ladders over a frozen snapshot, 100 teams each, 20 batches × 28 challengers.
Full write-up: **`sim/META_RESEARCH_REPORT.md`** (findings) and
**`sim/META_FORMATS_DETAIL.md`** (top-3 teams + top-10 mons per format, with full sets).

Headline findings:
1. **The multiplier group is the degeneracy.** Banning Marowak/Azumarill/Pikachu breaks the
   offense monoculture (hyperoffense 27→12 teams, niche evenness 0.883→0.899, six co-viable
   archetypes). Banning the setup/stat group *alone* **reduces** variety — it just crowns rain.
2. **The OU multiplier stars are the apex of the whole game.** In unbanned Ubers the **top 10
   teams are 100% OU-legal**; a legendary's BST is *averaged down* by fusion while a 2×
   multiplier *compounds*. Even Arceus pairings underperform (Azumarill/Arceus #20,
   Marowak/Arceus #47) because Arceus supplies no free-setup ability.
3. **Games lengthen monotonically** as dominators are removed (median 17→24 turns).
4. **The crowned meta is AI-dependent** — native heuristic vs a one-turn lookahead rank teams
   at ρ≈0.14 with ~50% head-to-head agreement; the greedier AI crowns *more* offense.
5. **Priority is cleanup, not wallbreaking** — the +2 boosted main move does the breaking
   (Bonemerang 214% on a Steel/Dragon wall); priority is 4–5HKO on walls.

**Tooling:** `sim/nladder.rb` (+ `BAN_SPECIES`/`BAN_ABILITY`/`BAN_ITEM` + standard clauses,
resolved bans persisted in ladder state), `sim/ladder_metrics.rb` (niche entropy, usage Gini,
archetype Elo spread, sampled game length), `sim/nlookahead.rb` (one-turn lookahead policy,
~38% vs native), `sim/rq1_ai_compare.rb` (Spearman + agreement between AIs),
`sim/dmgcalc_priority.rb`, `sim/dmgcalc_boosted.rb`, `sim/ab_item_test.rb`.

**Known issue:** `nlookahead.rb` has an `-Infinity` eval path that forced ~19 draws in the RQ1
run, so the RQ1 *magnitude* is soft (direction is sound).

---

## 2026-07-30 · In-game ban-set modes (Random Battle)

Added a ban-set step to the Random Battle menu so the research conditions are playable in-game:
**No clauses / Standard clauses / Ban multipliers / Ban setup+stat / Ban both**. Layers on any
mode and tier. Wonder Guard is deliberately left playable in-game (unlike the sim).
Logged in `sidmod.txt`; revert steps there. Not yet verified on a real screen.

---

## 2026-07-30 · Rebuilds + new specialists

Two mons were sitting on wasted stat lines and got rebuilt in place:
- **Alagar** (Alakazam/Gengar) — was Teleport/Confusion/Disable/Psybeam; now **Magic Guard ·
  Life Orb** Nasty Plot / Psychic / Shadow Ball / Focus Blast (SpA 365, Spe 357). Magic Guard +
  Life Orb = 1.3× with **zero recoil**.
- **Genark** (Gengar/Zoroark) — was ability Illusion with no setup move; now **Levitate** Nasty
  Plot (Ghost/Dark, immune Normal/Fighting/Psychic/Ground).

New:
- **Polichomp** (Poliwrath/Garchomp) — was never in the pool. Strictly better than the
  incumbent Swampwrath for a rain sweeper: BST 558 vs 515, **Spe 91 vs 63**, gains SD/DD.
- **Milokazam** (Milotic/Alakazam) — Magic Guard rain wallbreaker. Confirmed in engine code that
  Magic Guard blocks **sandstorm/hail** too (`takesSandstormDamage?` → `takesIndirectDamage?`),
  so it ignores sand, hazards, Toxic *and* its own Life Orb.
- **Blissey trio for UU**: **Bliskazam** (Magic Guard CM), **Blisgar** (Blissey/Gengar —
  Normal/Poison + **Levitate**, immune to Ghost/Ground/Toxic, effectively **one weakness**),
  **Blisvern** (Blissey/Noivern — Normal/Dragon, **STAB Boomburst**, BST 601).
  Calc caveat: Blissey needs a *high-Def* partner to tank (Dusknoir 135 Def → Phantomguard 223;
  Alakazam 45 Def → Bliskazam 102), so these are special-side specialists, not all-purpose walls.

Spec: `spec_rebuild_specials.json`, `spec_milokazam.json`, `spec_blissey_trio.json`.

---

## 2026-07-30 · Tier system — explicit per-fusion banlists

The PC pool is a closed, enumerable set (~360 OU-legal fusions), so tiers are defined by
**explicit banlists** (`sim/tiers.json`) rather than rules — every call can be a judgment call.

**Identity is the engine's own canonical fusion id**: the species symbol `B<body>H<head>`
(Marowak/Mimikyu == `B373H105`, dexNum = `body*NB_POKEMON + head`), stored on every Pokémon and
produced by `getFusedPokemonIdFromDexNum` — immutable and exactly unique. Entries are written
`"MAROWAK/MIMIKYU"` or `"B373H105"` and validated at load, so typos fail loudly.
**Nicknames are rejected**: they are auto-generated, change when a fusion is rebuilt
(Hexamind→Alagar this session), user-editable, and not unique.

| Tier | Definition | Legal |
|---|---|---|
| **Ubers** | everything (standard clauses only) | 478 |
| **OU** | − the 54 Huge Power / Thick Club / Light Ball / Disguise / Multiscale fusions | 307 |
| **UU** | − OU's own top performers (usage-based) | *pending benchmark* |

Granularity is per-fusion, not per-build (banning `MAROWAK/REGIGIGAS` catches both builds).
`nladder.rb` gains `TIER_DEF=ou|uu|ubers`. Rationale for banning mechanics over species: it
spares 9 honest builds (Glimmerwing/Pixilate, Tyradrake/Sand Stream, Dragokiss/Serene Grace…)
and makes tier a *build* property — re-spec a mon's ability and it changes tier.

**Tooling:** `sim/tiers.json`, `sim/tiers.rb` (`ruby sim/tiers.rb <snapshot_tag>` validates and
prints per-tier pool sizes).
