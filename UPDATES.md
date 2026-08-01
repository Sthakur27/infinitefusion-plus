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

---

## 2026-07-30 · OU tier benchmark + UU banlist derived

Ran the OU tier (mechanic bans) over a fresh snapshot including all 28 new fusions:
`ladder_tou`, 100 teams, 20 batches. 94 mons banned (74 mechanic + 20 clause).

**The tier design worked — the meta inverted.** Under the OU banlist the #1 team is **stall**
(Tidepod / Voltrazor / Spectracle / Thornwing / Venomtide / Fistking) running Stealth Rock,
Spikes, Leech Seed, Toxic and Will-O-Wisp, while **hyperoffense collapsed to 7 teams with the
worst mean Elo of any niche (1565)**. Niches are far more even than baseline
(balance 22, rain 21, sand 20, priority 10). Hazards — conspicuously absent from every team in
the original C0 research and the loudest sign of AI-shaped degeneracy — now appear on the best
team. Bar 1729, top 1861.

**How the 28 new fusions did (honestly): poorly.** 9 were *banned, not beaten* (they use
Disguise / Multiscale / Thick Club / Light Ball, so they are Ubers by our own definition:
Mimibat ×2, Mimigar, Mimirona, Mimisol, Dragokyu, Abnite, Marobat, Volcachu). Of the 19
eligible, only 4 made the ladder at all, all near the bottom: **Genark #92**, **Alagar #93**,
**Blisgar #97** (2 teams), **Toron #100**. The two *rebuilds* both placing is mild validation
that fixing their junk movesets helped; everything else lost outright to the established cast.

**UU defined** from this run's usage: ban every fusion used on **≥15% of OU teams** (10 mons) —
Voltrazor (Raichu/Scizor, 30%), Phantomguard (Blissey/Dusknoir, 26%), Cragwing
(Tyranitar/Articuno, 22%), Aqualift (Suicune/Togekiss, 21%), Nimbus (Volcarona/Politoed, 21%),
Glissey (Blissey/Gliscor, 20%), Monsoon (Ludicolo/Sceptile, 19%), Igniflora (Lurantis/Entei,
18%), Thaladon (Vaporeon/Slaking, 17%), Sandking (Slaking/Sandslash, 16%).
That removes the best pivot, both premier walls, **both weather setters**, the best rain
sweeper and the Contrary breaker → 297 legal. Caveat: the ladder's usage cap is 30%, so the top
entry is saturated and would rank higher uncapped.

**Name-brittleness confirmed the hard way.** Among mons *actually used on this ladder* there are
**four distinct fusions all named "Overload"** (Electivire/Aerodactyl, Lucario/Infernape,
Weavile/Mamoswine, Scizor/Lucario) and two named "Riptide". A nickname-keyed banlist would have
banned four mons where one was intended — the canonical-id approach (`B<body>H<head>`) is not
optional.

---

## 2026-07-30 · Tiers reworked to ASSIGNMENT (not rule-derived) + nickname dedupe

**Tier model replaced.** The previous OU banlist was seeded *from* a mechanic rule (Huge Power /
Thick Club / Light Ball / Disguise / Multiscale), so it was rule-derivation wearing a banlist
costume — and it mis-tiered badly: **Volcarona/Pikachu (Volcachu) was exiled to Ubers for holding
a Light Ball while finishing dead last, #100/100, on a measured ladder.** Holding a strong toy is
not the same as being strong.

Now every fusion has one **home tier assigned by judgment**, and a tier's legal pool is its own
members plus everything below (standard Smogon nesting): `ubers` = everything, `ou` = ou + uu
members, `uu` = uu members only. Unlisted fusions default to `uu`, so they are legal everywhere.
Listing under `ubers` bans from OU and UU; listing under `ou` bans from UU only.

Assignments are evidence-backed from the ladders, and deliberately small:
- **Ubers (10)** — proven top-usage/top-team anchors: Azumarill/Garchomp, Azumarill/Absol,
  Azumarill/Marowak, Azumarill/Arceus, Marowak/Mimikyu, Dragonite/Regigigas, Dragonite/Slaking,
  Slaking/Dragonite, Dragonite/Scizor, Lucario/Pikachu.
- **OU (10)** — ≥15% usage in the `ladder_tou` OU benchmark: Raichu/Scizor, Blissey/Dusknoir,
  Tyranitar/Articuno, Suicune/Togekiss, Volcarona/Politoed, Blissey/Gliscor, Ludicolo/Sceptile,
  Lurantis/Entei, Vaporeon/Slaking, Slaking/Sandslash.
- **UU** — everything else (the long tail, plus mons that hold a "broken" toy but never converted
  it: Volcarona/Pikachu, Marowak/Arceus, the defensive Disguise builds).

Pools: **Ubers 478 / OU 351 / UU 341** legal. `nladder.rb` uses `TIER_DEF=ou|uu|ubers`.
Tooling: `sim/tiers.json` (assignments), `sim/tiers.rb` (validate + print pool sizes).

**Nickname dedupe — 37 renames, 0 collisions remain.** 14 nicknames were shared by 36 distinct
fusions; `Overload` and `Momentum` were each **six different mons**. This was actively corrupting
analysis — "Cragwing" was reported as a top ladder mon when two fusions had that name
(Tyranitar/Articuno and Tyranitar/Zapdos), and it is the concrete reason nicknames are rejected as
tier identity. New names include Tyranitar/Articuno → **Frostcrag**, Tyranitar/Zapdos →
**Stormcrag**, Vaporeon/Dragonite → **Mistwing**, Milotic/Dragonite → **Tidegrace**,
Gengar/Greninja → **Hexblade**, Electivire/Aerodactyl → **Stormtalon**.

The generator validates before writing: it confirms each target slot holds the expected
head/body fusion and that no new name collides with a mon not being renamed. It refused the first
run over a species-id typo (`HO_OH` vs the engine's `HOOH`).
Spec: `spec_dedupe_names.json`.

**Convention:** in conversation, mons are now referred to by their fusion parents (e.g.
"Raichu/Scizor (Voltrazor)"), not nickname alone — nicknames aren't memorable enough to identify
a mon from.

---

## 2026-07-30 · UU ladder + first iterative tier pass (Smogon methodology)

**`TIER_DEF` validated end-to-end** — `ladder_uu` init reported
`banned 40 — tier:ubers:10 tier:ou:10 move-clause:9 ability:SHADOWTAG:9 ability:WONDERGUARD:2`.

**The UU meta is healthy.** Top team is hazard stack — Raichu/Aerodactyl (Stormwing) +
Tentacruel/Forretress (Toxispin) + Skarmory/Ferrothorn (Thornwing) + Blissey/Toxapex (Pinkreef).
Niches spread rain 30 / balance 20 / hyperoffense 19 / priority 17 / hazardstack 6. Bar 1725.
UU's defining mons by usage: Politoed/Forretress (Toedsteel, Drizzle) 30%, Blissey/Dusclops
(Spectracle, Eviolite) 27%, Goodra/Toxapex (Vireef) 24%, Zoroark/Alakazam (Illuzam) 23%.

**Gap found — and it is the iterative half of tiering I had skipped.** Because Ubers was assigned
only from *measured* dominance (10 fusions), ~15 other fusions carrying the same doubling
mechanics were UU-legal. They had never been measured because the earlier *rule* banned them; the
moment they were legal they went straight to the top:

| Fusion | Mechanic | UU usage | Best team |
|---|---|---|---|
| Azumarill/Electivire (Aquavolt) | Huge Power | 20% | **#1** |
| Marowak/Dragonite (Maronite) | Multiscale **+** Thick Club | 15% | #5 |
| Azumarill/Weavile (Frostarill) | Huge Power | 7% | #5 |
| Azumarill/Haxorus (Dracotide) | Huge Power | 7% | #6 |
| Azumarill/Bisharp (Aquametal) | Huge Power | 4% | #7 |

**Promoted those 5 to OU — not Ubers.** Smogon-style, a mon rises **one tier at a time**: breaking
UU makes it an OU mon; Ubers requires breaking *OU*, which has not been tested. Pools are now
Ubers 478 / OU 351 / **UU 336**.

Deliberately **left in UU**, because owning a strong toy is not a tiering offence — only
demonstrated dominance is: Volcarona/Pikachu (Light Ball, finished #100/100),
Marowak/Arceus (Thick Club, #47), and Golisopod/Mimikyu (Golisokyu — Disguise, but a defensive
Rocky Helmet / Pain Split pivot rather than a setup abuser; 3 teams).

**Session builds in UU: 8 placed** (vs 4 in OU). Best by a wide margin is **Gengar/Zoroark
(Genark) at #57 on 4 teams** — the rebuild is genuinely performing. Then Marowak/Crobat (Marobat)
#91, Mimikyu/Volcarona (Mimirona) and Milotic/Alakazam (Milokazam) #94, Mimikyu/Absol (Mimisol)
#95, Crobat/Aerodactyl (Crodactyl) #98, Volcarona/Bibarel (Volcabarel) #99. The whole Blissey trio
failed to place, consistent with the earlier damage calc: ~100 physical Def is fatal in any tier.

Follow-up running: `ladder_ou2` (does the promoted Huge Power crowd break OU → Ubers case?) and
`ladder_uu2` (did the promotions stabilise UU?).

---

## 2026-07-30 · Four-tier sweep + tiers playable in-game

**Full sweep run** (`ladder_v_ag/ubers/ou/uu`, 100 teams × 20 batches each) with correct
cascading exclusions (AG 2 → Ubers +8 → OU +15).

| Tier | Cap-saturated (30/100) | Niche spread | Top Elo |
|---|---|---|---|
| AG | Blissey/Dusknoir, Azumarill/Garchomp | rain 27, balance 26, priority 18, HO 13 | 1888 |
| Ubers | Azumarill/Marowak, Azumarill/Absol | **HO 31**, balance 20, priority 15 | 1855 |
| OU | Suicune/Togekiss, Tyranitar/Golisopod | **balance 28, priority 21, rain 16, HO 10** | 1902 |
| UU | Politoed/Forretress | **rain 31**, balance 26, hazardstack 14 | 1828 |

**Methodological finding — cap-saturation is a bad ban criterion.** Every tier has ~2 mons
pinned at exactly 30/100 *because the ladder's usage cap is 30%*. Something will always sit
there; banning it just promotes the next mon into the same slot, so per-mon "ban what capped"
is **unbounded by construction**. The AG banlist was built on that signal and should be treated
as provisional. **Niche spread is the better health signal**, and by it **OU is the healthiest
tier we have built** — no archetype monoculture. Recommendation: stop adding bans.

One promotion validated: **Marowak/Dragonite**, promoted UU→OU last pass, landed **#4 in OU
(26 uses)** — strong but not dominant, i.e. correctly tiered.

**Session builds finally placed:** Suicune/Gliscor **#21 in OU** (best of any build this
session — the Poison Heal Water/Flying wall is genuinely OU-caliber), Gengar/Zoroark **#17 in
Ubers** (the rebuild works), Blissey/Gengar #46 OU, Alakazam/Gengar #39 UU, Mimikyu/Crobat #51
OU, Machamp/Crobat #65 UU.

**Tiers are now playable in-game.** Random Battle's menu is restructured: the generator
(Chaos / Smart / Smart v2 / OU Apex) and the **competitive tier (AG / Ubers / OU / UU)** are
separate steps, so any generator can be played in any tier. `Data/sidmod/tiers.json` is a copy
of the sim's `tiers.json`, so game and ladder share one source of truth — **re-copy it after
any tier change**. Full detail and revert steps in `sidmod.txt`.

Bug worth remembering: the engine's lightweight RGSS JSON parser returns **symbol** keys while
Ruby's stdlib JSON returns **string** keys on the same file. `cfg["tiers"]` silently read nil
in-game, so zero assignments loaded and every tier was unfiltered. Fixed with a key-agnostic
`jget`; verified 25 assignments load and all four tier boundaries behave.
