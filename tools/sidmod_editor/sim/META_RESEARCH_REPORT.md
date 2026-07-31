# Infinite Fusion Metagame Research Report
### Banning dominant fusions, tier structure, and AI-dependence of the crowned meta
*Generated 2026-07-30 · offline king-of-the-hill ladder over Sid's PC pool (save "File A")*

---

## TL;DR

1. **The metagame is degenerate in a specific, measurable way: it's dominated by fusions carrying a flat attack multiplier** (Huge Power / Thick Club / Light Ball). Banning that group (Marowak / Azumarill / Pikachu) is what actually *diversifies* the meta — hyperoffense collapses from 27→12 of the ladder's teams and five other archetypes become co-viable.
2. **Banning the setup/stat group alone (Dragonite / Slaking / Regigigas) does not add variety** — it just hands the meta to rain.
3. **The OU multiplier stars are the apex of the *entire game*.** In unbanned Ubers, the **top 10 teams are 100% OU-legal**; legendaries barely appear, because a legendary's high BST gets *averaged down* in a fusion while a 2× multiplier *compounds*.
4. **Which teams are "best" depends heavily on which AI judges them** (rank correlation ≈ 0.14, head-to-head agreement ≈ 50%), and a greedier AI crowns *more* offense.
5. **Priority is not the wallbreaker; the +2 boosted main move is.** Priority's role is speed-control/cleanup.

---

## 1. Methodology

### 1.1 Simulator
- **Engine:** the actual Infinite Fusion battle engine (Pokémon Essentials + Reborn AI), driven head-less by the offline harness in `tools/sidmod_editor/sim/`.
- **AI:** the game's own **SmartTrainerAI** (a mature, well-tuned 1-ply heuristic), patched to play *both* sides so games are AI-vs-AI. Battles are deterministic per seed.
- **Pool:** every Level-100, item-holding fusion in the save's PC + party (the "battle-ready" pool), decomposed to base species for the Species Clause and tier filter. ~343 OU-legal fusions.

### 1.2 The ladder (`nladder.rb`)
A revolving **king-of-the-hill team search**: a fixed 100-team ladder, each with an Elo. Challengers (random / archetype-built / mutations / crossovers of winners) play a staged, early-exit gauntlet and are promoted on **performance rating** if they clear the median. Two pressures keep it from collapsing into a monoculture:
- **Usage cap** — no single mon on more than 30% of teams.
- **Niche reservation** — every archetype (rain, sand, stall, …) gets reserved capacity, so plans that need development aren't killed before they mature.

Each condition: **100 teams, 12 seeding opponents, 20 batches of 28 challengers**, identical across conditions from a single frozen snapshot (`rsnap`) so only the ban set varies.

### 1.3 Ban conditions
Standard competitive **clauses** apply to every condition (Spore, Moody, Shadow Tag, Arena Trap, Baton Pass, Swagger, OHKO moves; Wonder Guard excluded in-game but banned in-sim). On top of that:

| Cond | Extra ban | Legal OU pool |
|---|---|---|
| **C0** | clauses only | 326 |
| **C1** | + Group A (Marowak, Azumarill, Pikachu) | 293 |
| **C2** | + Group B (Dragonite, Slaking, Regigigas) | 277 |
| **C3** | + both groups | 250 |
| **U0** | Ubers, clauses only | full pool |
| **U3** | Ubers, + both groups | — |

Bans are by **base species** (any fusion containing the species is removed).

### 1.4 Metrics (`ladder_metrics.rb`)
- **Diversity:** niche evenness (normalized Shannon entropy over archetypes; 1.0 = perfectly even), distinct mons on the ladder, usage Gini (lower = more spread), archetype Elo spread (lower = archetypes closer in strength).
- **Degeneracy:** game length (median/mean turns) sampled from a round-robin of the top-40 teams. *Note: turn count includes post-decision mop-up, so it under-measures "effective" decisiveness.*

### 1.5 AI-dependence test (`rq1_ai_compare.rb`)
A one-turn **lookahead** policy (`nlookahead.rb`) was built as a distinct decision procedure: for each action it predicts the post-turn board using the engine's own damage estimator — respecting move order and whether a KO lands *before* retaliation — and picks the argmax (opponent modeled as "hits hardest"). RQ1 ranks a fixed team set under **both** AIs via identical round-robin and compares rankings.

---

## 2. Baseline metagame (C0 — clauses only)

**Character:** an offense monoculture. Archetype tally: hyperoffense 27, balance 23, priority 12, rain 9, then a long tail.

**Top teams:**
| # | Elo | Roster |
|---|---|---|
| 1 | 1863 | Draking, Geyserchomp, Igniflora, Illuzam, Cryptocode, Joltkiss |
| 2 | 1840 | Bonecloak, Phantomguard, Aqualift, Voltrazor, Geyserchomp, Fistking |
| 3 | 1826 | Dragotitan, Spinosaurus, Abyssmarill, Fistking, Sparkarona, Cryptocode |

**Most-used mons:** Geyserchomp (Azumarill/Garchomp, Huge Power) ×30, Abyssmarill (Azumarill/Absol, Huge Power) ×30, Phantomguard (Blissey/Dusknoir wall) ×28, **Bonecloak (Marowak/Mimikyu, Disguise + Thick Club) ×28**, Voltrazor (Raichu/Scizor, Technician Scarf) ×27, Igniflora (Lurantis/Entei, Contrary V-create) ×27, Dragotitan (Dragonite/Regigigas, Multiscale DD) ×20.

The single most-used mon in the game is **Bonecloak — a Marowak fusion**, i.e. one of the most unassuming base Pokémon in the franchise, carrying a Thick Club that doubles its already-doubled-by-Disguise-setup Attack.

---

## 3. RQ2 — Does removing the dominators add flavor? (OU)

### 3.1 The numbers
| | C0 | C1 (−GroupA) | C2 (−GroupB) | C3 (−both) |
|---|---|---|---|---|
| niche evenness | 0.883 | **0.899** | 0.793 | 0.869 |
| distinct mons | 142 | 125 | 111 | 122 |
| usage Gini | 0.588 | **0.568** | 0.617 | 0.580 |
| archetype Elo spread | 171 | 243 | 199 | **153** |
| median game length | 17 | 19 | 22 | **24** |

### 3.2 Archetype shift
- **C0:** hyperoffense 27, balance 23, priority 12, rain 9 — *monoculture*.
- **C1 (−multipliers):** bulkysetup 15, sand 14, balance 14, rain 13, priority 13, hyperoffense 12 — *six co-viable archetypes*.
- **C2 (−setup/stat):** rain 29, balance 27, hyperoffense 16 — *rain takes over*.
- **C3 (−both):** rain 21, sand 19, hyperoffense 16, balance 13 — *weather-led, flattest*.

### 3.3 Top mons per condition
- **C1:** Dragotitan ×30, Voltrazor ×29, Igniflora ×28, **Cragwing (Tyranitar/Articuno, Sand Stream) ×24**, **Glissey (Blissey/Gliscor, Poison Heal) ×23** — sand & stall rise into the vacuum.
- **C2:** **Nimbus (Volcarona/Politoed, Drizzle) ×30**, Bonecloak ×30, Phantomguard ×30, Aqualift ×29, then Swift-Swim abusers Monsoon & Ombralure — the rain package.
- **C3:** Voltrazor ×30, **Cragwing ×30**, Igniflora ×27, Glissey ×26, Nimbus ×22 — sand + rain + a Blissey/Gliscor stall core.

### 3.4 Finding
**Banning the multiplier group (A) is the real diversifier** (evenness ↑, Gini ↓, offense monoculture broken into six archetypes). **Banning the setup/stat group (B) alone reduces variety** — it simply crowns rain. C3 (both) yields the **most *balanced*** ladder (archetype Elo spread 153, smallest top-to-bar gap) and the **longest games** (median 24 vs 17), but it's weather-led rather than truly diverse. "Balanced" and "varied" are different axes, and the experiment separates them.

---

## 4. Ubers — do OU mons hold up? (They dominate.)

### 4.1 OU-mon dominance in unbanned Ubers (U0)
- **OU-legal mons = 93% of all 600 ladder slots.**
- **The entire top 10 is 6/6 OU-legal — zero legendary-fusion slots.**
- Base-species presence across 100 teams: **Azumarill 70, Dragonite 49, Marowak 46, Pikachu 16.**

**Top teams (all 6/6 OU):**
| # | Elo | Roster |
|---|---|---|
| 1 | 1875 | Dragotitan, Geyserchomp, Bonecloak, Spectracle, Infermane, Moxitalon |
| 2 | 1875 | Tidepod, Abyssmarill, Dragotitan, Bonecloak, Infermane, Mysticune |
| 3 | 1863 | Floraflame, Dragotitan, Geyserchomp, Bonecloak, Lagoonking, Phantoclaw |

**Why:** a legendary's huge base-stat total is *averaged down* by the fusion formula (⅔ body + ⅓ head per stat), whereas a flat 2× multiplier (Huge Power / Thick Club) *compounds* with setup. So a Huge-Power Azumarill fusion out-muscles a Mewtwo/Kyogre/Rayquaza fusion. **The OU multiplier abusers are the apex predators of the whole game.**

**The decisive test — even fusing the abuser *with* a legendary doesn't help.** Both Arceus-multiplier fusions exist in the pool and *underperform their OU-partner versions*:

| Fusion | Ability | Teams | Best rank |
|---|---|---|---|
| Azumarill/**Garchomp** (Geyserchomp) | Huge Power | 30 | top tier |
| Azumarill/**Arceus** (Aquamyth) | Huge Power | 16 | #20 |
| Marowak/**Mimikyu** (Bonecloak) | Disguise | 30 | top tier |
| Marowak/**Arceus** (Terraeus) | Battle Armor | 3 | #47 |

The multiplier already doubles Attack *regardless of the partner's stats*, so Arceus's balanced 120s are **win-more**. What actually decides these mons is what the multiplier doesn't give: a **free-setup ability** (Bonecloak's edge is Mimikyu's **Disguise**, not stats — Marowak/Arceus has no free-turn ability, so it never reaches +2) and **offensive typing/speed** (Azumarill/Garchomp is Water/Ground with a Scarf revenge role; Azumarill/Arceus is Water/Normal). So the refined thesis is **"multiplier + free-setup + good typing wins"** — and bolting a legendary onto the abuser *strips* the free-setup that makes it broken. Legendaries aren't merely a sideshow; they actively make the abusers *worse*.

### 4.2 Ban effect in Ubers
| | U0 (unbanned) | U3 (−both groups) |
|---|---|---|
| niche evenness | 0.880 | 0.840 |
| archetype Elo spread | 159 | **99** (flattest measured) |
| median game length | **15** | 22 |
| top niches | HO 25, priority 18, balance 16, rain 16 | balance 20, rain 15, sand 15, hazardstack 11 |

Two notes: **Ubers games are *faster* than OU** (median 15 vs 17 turns — more raw firepower), and banning the OU groups rebalances Ubers exactly as it does OU (power hierarchy collapses, weather/hazard/balance rise, games lengthen +7 turns). **The OU groups are the problem in both tiers.** U3's top is sand-led (Cragwing/Infernersh) with a Togecune rain team at #2.

---

## 5. RQ1 — Does the crowned meta depend on the AI?

Comparing the native SmartAI and the one-turn lookahead as two distinct competent agents, ranking C0's top-30 teams under both via identical round-robin:

| Metric | Value |
|---|---|
| Spearman rank correlation (native vs lookahead) | **0.14** |
| Head-to-head agreement (same winner, same matchup) | **50.2%** |
| Native top-12 niches | balance 4, HO 4, priority 3, rain 1 |
| Lookahead top-12 niches | **HO 6**, balance 2, generic 2, priority 1, rain 1 |

**Finding:** the ranking is **near-uncorrelated** between AIs and they agree on a matchup's winner only ~half the time — so **team strength is AI-relative, not intrinsic.** Directionally, the greedier lookahead tilts *harder* into hyperoffense (6/12 vs 4/12), consistent with "less positional sophistication → more raw offense wins."

**Caveat:** the lookahead is *weaker* than native (~38% win rate; native beats a random policy 100%) and crashed on 19/≈870 games (`-Infinity` eval bug → forced draws). A weaker/noisier agent inflates disagreement, so the *magnitude* of AI-dependence is soft; the **direction** (AI choice reshuffles the top; greedier ⇒ more offense) is the robust takeaway.

---

## 6. Supporting analyses

### 6.1 Priority is cleanup, not wallbreaking (damage calc)
Firing the real meta priority moves at the tankiest walls, **at +2**:
- Bonecloak Thick-Club **Shadow Sneak**: IMMUNE to all Normal-type walls; **4–5HKO** (≈30%) on Water/Steel walls.
- Abyssmarill Huge-Power **Aqua Jet**: 3–5HKO on every wall.
- Glimmerwing Pixilate **Extreme Speed** (the strongest): at most a 2HKO at +2.

The wallbreaking is the **+2 boosted main move**: Bonecloak **Bonemerang 214%** on a Steel/Dragon wall, **Play Rough** OHKO-range across the board. Priority provides speed-control and cleanup; setup + main move does the breaking. The setup is enabled *for free* by Disguise / Multiscale.

### 6.2 Item A/B (controlled, same team, 198 games/side)
Glimmerwing (Sylveon/Dragonite): **Leftovers 61.9% win / 1839 perf-Elo** > Life Orb 58.6% / 1815. The pool build was correct; the sim overturned the armchair "4 attacks ⇒ Life Orb" intuition, because the mon's value is *staying alive to spam Pixilate priority*, not one harder hit.

### 6.3 Species Clause shapes teambuilding
No team may run two fusions sharing a base species. So when a team wants Azumarill on Absol (priority) or Marowak (Thick Club), its Garchomp slot can't *also* be Azumarill → it becomes **Feraligatr/Garchomp** (Spinosaurus, Sheer Force). The clause routes each base species to its best partner rather than forcing a downgrade.

---

## 7. Conclusions

1. **The degeneracy is the multiplier mechanic**, not "priority" or "setup" in the abstract. Fusion divorces a 2× attack multiplier from the fragile chassis that balances it in standard play, and the multiplier *compounds* with free-turn setup.
2. **Banning the multiplier group is the single most effective diversity lever.** Banning the setup/stat group alone just crowns weather.
3. **The OU multiplier stars dominate Ubers too** — tier labels are nearly meaningless here; the whole game has one apex tier.
4. **The crowned meta is strongly AI-dependent**, and greedier pilots amplify offense — a caution against reading any single AI's tier list as ground truth.
5. **For a healthier format**, species-ban Marowak/Azumarill/Pikachu (and optionally item/ability-ban Huge Power / Thick Club / Light Ball). This is now playable in-game via the Random Battle **ban-set menu**.

---

## 8. Limitations

- **AI ceiling:** all rankings are under a 1-ply heuristic (or a weaker lookahead). A genuinely stronger AI (true 2-turn minimax, ~1,900× cost/decision) was priced but not built; it might value hazards/positioning enough to shift the verdicts.
- **Turn-count degeneracy metric** counts mop-up turns, so it under-measures "effective" decisiveness; 0% of AI-vs-AI games ended ≤3 turns, whereas human-vs-AI blowouts do (a matchup, not average, phenomenon).
- **Pool = built mons only.** The ladder searches over fusions that exist in the save, so a species ban removes even the non-abusive fusions of that species.
- **Niche reservation** props up weak archetypes (stall/sun) with reserved slots, so raw archetype *counts* are part-merit, part-mechanic; evenness/Gini/Elo-spread are the more honest signals.
- **RQ1 magnitude is soft** (weaker, buggy lookahead); direction is trustworthy.

---

## 9. Reproducibility

```bash
# from the game root
# ladder for a condition (species ban via env; clauses on by default)
BAN_SPECIES=MAROWAK,AZUMARILL,PIKACHU ruby tools/sidmod_editor/sim/nladder.rb init rsnap ladder_c1 100 12 14
ruby tools/sidmod_editor/sim/nladder.rb run ladder_c1 20 28 14
# metrics (diversity + game length)
ruby tools/sidmod_editor/sim/ladder_metrics.rb ladder_c1 240
# AI-dependence
ruby tools/sidmod_editor/sim/rq1_ai_compare.rb ladder_c0 30 1
# lookahead self-test vs native
ruby tools/sidmod_editor/sim/nlookahead.rb 60
```

Tooling: `nladder.rb` (search + bans), `ladder_metrics.rb` (RQ2 metrics), `nlookahead.rb` (lookahead policy), `rq1_ai_compare.rb` (AI comparison), `dmgcalc_priority.rb` / `dmgcalc_boosted.rb` (damage), `ab_item_test.rb` (item A/B). In-game: the Random Battle **ban-set menu** in `Data/Scripts/055_sidmod/RandomOpponent.rb`.

---

## Appendix A — Mon Dossier

Every fusion nickname used anywhere in this report, decoded. Fusion order is **Head / Body** (the head supplies HP/SpA/SpD and the primary type; the body supplies Atk/Def/Spe and the secondary type). Sourced directly from the pool snapshot.

| Name | Fusion (Head / Body) | Type | Ability · Item | Moveset |
|---|---|---|---|---|
| **Abyssmarill** | Azumarill / Absol | WATER/DARK | Huge Power · Life Orb | Swords Dance, Aqua Jet, Sucker Punch, Play Rough |
| **Aerohelm** | Tyrantrum / Aerodactyl | ROCK/FLYING | Rock Head · Leftovers | Hone Claws, Head Smash, Sky Drop, Earthquake |
| **Aqualift** | Suicune / Togekiss | WATER/FLYING | Serene Grace · Leftovers | Calm Mind, Scald, Air Slash, Roost |
| **Aquamyth** | Azumarill / Arceus | WATER/NORMAL | Huge Power · Life Orb | Swords Dance, Extreme Speed, Aqua Jet, Play Rough |
| **Aquaura** | Kyogre / Gardevoir | WATER/FAIRY | Drizzle · Leftovers | Surf, Moonblast, Thunder, Calm Mind |
| **Blazeking** | Slaking / Blaziken | NORMAL/FIGHTING | Speed Boost · Life Orb | Swords Dance, Protect, Hammer Arm, Flare Blitz |
| **Bonecloak** | Marowak / Mimikyu | GROUND/FAIRY | Disguise · Thick Club | Swords Dance, Bonemerang, Play Rough, Shadow Sneak |
| **Boombox** | Porygonz / Noivern | NORMAL/DRAGON | Adaptability · Silk Scarf | Boomburst, Nasty Plot, Dragon Pulse, Flamethrower |
| **Chantivy** | Sylveon / Noivern | FAIRY/DRAGON | Pixilate · Choice Specs | Boomburst, Draco Meteor, Flamethrower, U-turn |
| **Charhydra** | Charizard / Hydreigon | FIRE/DRAGON | Solar Power · Choice Specs | Flamethrower, Fire Blast, Draco Meteor, U-turn |
| **Chawlomp** | Hawlucha / Garchomp | FIGHTING/GROUND | Unburden · Focus Sash | Dragon Dance, Earthquake, Outrage, Superpower |
| **Cragwing** | Tyranitar / Zapdos | ROCK/FLYING | Sand Stream · Leftovers | Stealth Rock, Stone Edge, U-turn, Flamethrower |
| **Cryptocode** | Porygonz / Greninja | NORMAL/DARK | Protean · Life Orb | Nasty Plot, Dark Pulse, Ice Beam, Thunderbolt |
| **Dragotitan** | Dragonite / Regigigas | DRAGON/NORMAL | Multiscale · Leftovers | Ice Punch, Extreme Speed, Dragon Dance, Earthquake |
| **Draking** | Dragonite / Slaking | DRAGON/NORMAL | Multiscale · Life Orb | Dragon Dance, Dragon Claw, Earthquake, Return |
| **Electide** | Starmie / Electivire | WATER/ELECTRIC | Motor Drive · Choice Specs | Hydro Pump, Thunderbolt, Ice Beam, Volt Switch |
| **Feralak** | Feraligatr / Slaking | WATER/NORMAL | Sheer Force · Life Orb | Dragon Dance, Liquidation, Ice Punch, Crunch |
| **Fistking** | Hawlucha / Slaking | FIGHTING/NORMAL | Mold Breaker · Life Orb | Swords Dance, High Jump Kick, Return, Shadow Claw |
| **Floraflame** | Roserade / Ninetales | GRASS/FIRE | Drought · Leftovers | Flamethrower, Giga Drain, Nasty Plot, Solar Beam |
| **Gallagross** | Gallade / Metagross | PSYCHIC/STEEL | Clear Body · Life Orb | Swords Dance, Meteor Mash, Close Combat, Bullet Punch |
| **Gargoyle** | Salamence / Entei | DRAGON/FIRE | Moxie · Leftovers | Sacred Fire, Dragon Dance, Dragon Claw, V-create |
| **Gensekyu** | Genesect / Mimikyu | BUG/FAIRY | Disguise · Leftovers | U-turn, Simple Beam, Play Rough, Infestation |
| **Geyserchomp** | Azumarill / Garchomp | WATER/GROUND | Huge Power · Choice Scarf | Earthquake, Waterfall, Dragon Dance, Aqua Jet |
| **Glimmerwing** | Sylveon / Dragonite | FAIRY/FLYING | Pixilate · Leftovers | Extreme Speed, Earthquake, Fire Punch, Dragon Claw |
| **Glissey** | Blissey / Gliscor | NORMAL/FLYING | Poison Heal · Toxic Orb | Soft-Boiled, Toxic, Stealth Rock, Knock Off |
| **Golisokyu** | Golisopod / Mimikyu | BUG/FAIRY | Disguise · Rocky Helmet | First Impression, Pain Split, Protect, Play Rough |
| **Graniteaf** | Tyranitar / Leafeon | ROCK/GRASS | Sand Stream · Leftovers | Stealth Rock, Crunch, Stone Edge, Leaf Blade |
| **Igniflora** | Lurantis / Entei | GRASS/FIRE | Contrary · Leftovers | V-create, Superpower, Rest, Leech Life |
| **Illuzam** | Zoroark / Alakazam | DARK/PSYCHIC | Magic Guard · Life Orb | Nasty Plot, Dark Pulse, Psychic, Focus Blast |
| **Infermane** | Entei / Arcanine | FIRE | Intimidate · Life Orb | Sacred Fire, Extreme Speed, Wild Charge, Crunch |
| **Infernamo** | Blaziken / Kommoo | FIRE/FIGHTING | Speed Boost · Life Orb | Swords Dance, Close Combat, Flare Blitz, Earthquake |
| **Infernersh** | Sandslash / Infernape | GROUND/FIGHTING | Sand Rush · Life Orb | Rapid Spin, Flare Blitz, Close Combat, Earthquake |
| **Infervine** | Sceptile / Infernape | GRASS/FIGHTING | Iron Fist · Leftovers | Drain Punch, Fire Punch, Leaf Blade, Dragon Dance |
| **Ironbriar** | Registeel / Ferrothorn | STEEL/GRASS | Iron Barbs · Leftovers | Stealth Rock, Spikes, Leech Seed, Power Whip |
| **Ironchomp** | Metagross / Garchomp | STEEL/GROUND | Clear Body · Choice Scarf | Earthquake, Iron Head, Outrage, Stone Edge |
| **Ironcrypt** | Ferrothorn / Cofagrigus | STEEL/GHOST | Iron Barbs · Leftovers | Spikes, Leech Seed, Power Whip, Will-O-Wisp |
| **Joltkiss** | Togekiss / Jolteon | FAIRY/ELECTRIC | Serene Grace · Life Orb | Moonblast, Thunderbolt, Air Slash, Nasty Plot |
| **Kingwyrm** | Slaking / Dragonite | NORMAL/FLYING | Multiscale · Life Orb | Extreme Speed, Earthquake, Bulk Up, Stone Edge |
| **Krabust** | Kabutops / Kingler | ROCK/WATER | Swift Swim · Life Orb | Swords Dance, Waterfall, Stone Edge, Aqua Jet |
| **Krasus** | Gengar / Omastar | GHOST/WATER | Levitate · Life Orb | Shell Smash, Shadow Ball, Hydro Pump, Ice Beam |
| **Lagoonking** | Greninja / Slaking | WATER/NORMAL | Protean · Life Orb | Sucker Punch, Earthquake, Waterfall, Ice Punch |
| **Maromence** | Marowak / Salamence | GROUND/FLYING | Moxie · Thick Club | Dragon Dance, Earthquake, Brick Break, Crunch |
| **Mecharon** | Registeel / Hydreigon | STEEL/DRAGON | Levitate · Leftovers | Flamethrower, Thunderbolt, Thunder Wave, U-turn |
| **Metarax** | Metagross / Haxorus | STEEL/DRAGON | Mold Breaker · Lum Berry | Dragon Claw, Dragon Dance, Iron Head, Earthquake |
| **Momentum** | Weavile / Aerodactyl | DARK/FLYING | Rock Head · Choice Scarf | Knock Off, Ice Punch, Stone Edge, Low Kick |
| **Monsoon** | Ludicolo / Sceptile | WATER/GRASS | Swift Swim · Life Orb | Surf, Giga Drain, Ice Beam, Focus Blast |
| **Moxitalon** | Skarmory / Salamence | STEEL/FLYING | Moxie · Life Orb | Dragon Dance, Brave Bird, Earthquake, Roost |
| **Mysticore** | Goodra / Espeon | DRAGON/PSYCHIC | Magic Bounce · Leftovers | Calm Mind, Dragon Pulse, Psyshock, Flamethrower |
| **Mysticune** | Suicune / Milotic | WATER | Pressure · Leftovers | Calm Mind, Scald, Ice Beam, Recover |
| **Nightmaw** | Darkrai / Hydreigon | DARK/DRAGON | Levitate · Life Orb | Nasty Plot, Dark Pulse, Draco Meteor, Focus Blast |
| **Nimbus** | Volcarona / Politoed | BUG/WATER | Drizzle · Leftovers | Surf, Hurricane, Quiver Dance, Ice Beam |
| **Noida** | Ninetales / Whimsicott | FIRE/FAIRY | Drought · Life Orb | Nasty Plot, Fire Blast, Moonblast, Solar Beam |
| **Ombralure** | Chandelure / Omastar | GHOST/WATER | Swift Swim · Life Orb | Shadow Ball, Calm Mind, Hydro Pump, Energy Ball |
| **Overload** | Weavile / Mamoswine | DARK/GROUND | Thick Fat · Life Orb | Swords Dance, Icicle Crash, Earthquake, Ice Shard |
| **Persitto** | Ditto / Persian | NORMAL | Imposter · Choice Scarf | Fake Out, Transform |
| **Phantoclaw** | Dusknoir / Scizor | GHOST/STEEL | Technician · Leftovers | Swords Dance, Bullet Punch, Shadow Sneak, Roost |
| **Phantoglide** | Gliscor / Dusknoir | GROUND/GHOST | Poison Heal · Toxic Orb | Swords Dance, Earthquake, Knock Off, Roost |
| **Phantomguard** | Blissey / Dusknoir | NORMAL/GHOST | Natural Cure · Leftovers | Soft-Boiled, Will-O-Wisp, Toxic, Shadow Ball |
| **Pinkreef** | Blissey / Toxapex | NORMAL/WATER | Regenerator · Leftovers | Scald, Soft-Boiled, Toxic, Haze |
| **Ravager** | Rhyperior / Salamence | GROUND/FLYING | Moxie · Choice Band | Earthquake, Stone Edge, Megahorn, Ice Punch |
| **Riptide** | Gyarados / Garchomp | WATER/GROUND | Moxie · Life Orb | Dragon Dance, Waterfall, Earthquake, Ice Fang |
| **Salagon** | Flygon / Salamence | GROUND/FLYING | Moxie · Life Orb | Dragon Dance, Earthquake, Dragon Claw, Fire Punch |
| **Shadowshroud** | Chandelure / Greninja | GHOST/DARK | Protean · Life Orb | Hydro Pump, Fire Blast, Shadow Ball, Ice Beam |
| **Sparkarona** | Volcarona / Magnezone | BUG/ELECTRIC | Flame Body · Leftovers | Quiver Dance, Heat Wave, Parabolic Charge, Bug Buzz |
| **Spectracle** | Blissey / Dusclops | NORMAL/GHOST | Natural Cure · Eviolite | Soft-Boiled, Night Shade, Heal Bell, Will-O-Wisp |
| **Spinosaurus** | Feraligatr / Garchomp | WATER/GROUND | Sheer Force · Life Orb | Waterfall, Crunch, Dragon Dance, Earthquake |
| **Steelwyrm** | Dragonite / Scizor | DRAGON/STEEL | Multiscale · Leftovers | Dragon Dance, Dragon Claw, Earthquake, Roost |
| **Stormwing** | Raichu / Aerodactyl | ELECTRIC/FLYING | Rock Head · Life Orb | Earthquake, Volt Tackle, Stealth Rock, Volt Switch |
| **Swampwrath** | Poliwrath / Swampert | WATER/GROUND | Swift Swim · Life Orb | Waterfall, Earthquake, Superpower, Ice Punch |
| **Terraeus** | Marowak / Arceus | GROUND/NORMAL | Battle Armor · Thick Club | Swords Dance, Extreme Speed, Earthquake, Stone Edge |
| **Tidehammer** | Azumarill / Marowak | WATER/GROUND | Huge Power · Thick Club | Swords Dance, Aqua Jet, Earthquake, Knock Off |
| **Tidepod** | Tyranitar / Golisopod | ROCK/WATER | Sand Stream · Leftovers | Stealth Rock, Sucker Punch, Stone Edge, Liquidation |
| **Togecune** | Togekiss / Suicune | FAIRY/WATER | Serene Grace · Leftovers | Calm Mind, Moonblast, Scald, Roost |
| **Umbragen** | Mewtwo / Greninja | PSYCHIC/DARK | Protean · Life Orb | Psychic, Ice Beam, Aura Sphere, Thunderbolt |
| **Venomtide** | Gliscor / Suicune | GROUND/WATER | Poison Heal · Toxic Orb | Earthquake, Toxic, Roost, Knock Off |
| **Venupod** | Venusaur / Golisopod | GRASS/WATER | Overgrow · Life Orb | First Impression, Liquidation, Power Whip, Swords Dance |
| **Vireef** | Goodra / Toxapex | DRAGON/WATER | Hydration · Leftovers | Scald, Dragon Tail, Toxic Spikes, Rest |
| **Voltaqua** | Volcarona / Greninja | BUG/DARK | Protean · Life Orb | Fiery Dance, Ice Beam, Quiver Dance, Dark Pulse |
| **Voltario** | Lucario / Pikachu | FIGHTING/ELECTRIC | Justified · Light Ball | Extreme Speed, Vacuum Wave, Thunderbolt, Aura Sphere |
| **Voltfist** | Electivire / Infernape | ELECTRIC/FIGHTING | Iron Fist · Life Orb | Thunder Punch, Fire Punch, Mach Punch, Ice Punch |
| **Voltflare** | Talonflame / Luxray | FIRE/ELECTRIC | Intimidate · Life Orb | Brave Bird, Wild Charge, Flare Blitz, Roost |
| **Voltking** | Jolteon / Nidoking | ELECTRIC/GROUND | Sheer Force · Life Orb | Earth Power, Thunderbolt, Flamethrower, Volt Switch |
| **Voltotic** | Milotic / Jolteon | WATER/ELECTRIC | Volt Absorb · Leftovers | Scald, Thunderbolt, Ice Beam, Recover |
| **Voltrazor** | Raichu / Scizor | ELECTRIC/STEEL | Technician · Choice Scarf | Knock Off, Double Iron Bash, Volt Switch, Volt Tackle |
| **Voltwing** | Zapdos / Skarmory | ELECTRIC/FLYING | Pressure · Leftovers | Defog, Roost, Volt Switch, Thunderbolt |
