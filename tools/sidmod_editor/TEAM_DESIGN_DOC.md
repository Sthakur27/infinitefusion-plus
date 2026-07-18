# Infinite Fusion — Team Design & Scouting Doc

Working doc for the 10-team sim stable. Grounded in the headless AI-vs-AI battle sim
(best-of-3, all teams L100, real IF engine). Win rates are from the current hand-tuned
field. **Leave feedback inline** — I'll fold it into the next pass.

**Legend of ownership**
- 🟦 **Yours** (extracted from File A): Sun, Rain, Sand, Squads
- 🟨 **AI-built box teams** (from Box 15, not designed by either of us): Box15A, Box15B, Box15C
- 🟩 **Mine** (Claude-built, rule-legal — no reuse-heavy legendaries): Momentum, Overload, Bunker

**Hand-touched this session:** Box15A, Box15C, Bunker, Rain. Everything else is as-battled.

Live location: **Box 24** = Sun / Rain / Sand / Squads / Box15A. **Box 25** = Box15B / Box15C / Momentum / Overload / Bunker. (Originals untouched; Box 16 never touched.)

---

## The meta — 4 mechanics decide almost every game

1. **Weather war.** Permanent Drizzle (Kyogre/Mew) and Sand Stream overwrite Drought *on entry*. Whoever sets weather last usually wins. Two teams run Kyogre/Mew Drizzle (Box15B, Squads) — they own this axis.
2. **Spore / sleep-lock.** Kyogre/Mew, both Ninetales fusions, and Politoed/Whimsicott carry Spore. The sim AI switch-loops sleeping mons and bleeds out. No sleep answer = you get 0–3'd.
3. **Poison-Heal Ground/Flying walls** — Groudon/Gliscor & Regigigas/Gliscor. EQ-immune, self-healing, Knock-Off/Facade. Only Ice (4×) or strong special coverage breaks them.
4. **Priority + phazing** — Sylveon Pixilate ExtremeSpeed, Aegislash Spectral Thief/Whirlwind — hard-punish frail setup offense.

## Current standings (hand-tuned field, bo3)

| Rank | Team | Win% | Own |
|---|---|---|---|
| 1 | Box15B | 89% | 🟨 |
| 1 | Squads | 89% | 🟦 |
| 3 | Box15A | 56% | 🟨 (fixed) |
| 3 | Overload | 56% | 🟩 |
| 5 | Sun | 44% | 🟦 |
| 5 | Momentum | 44% | 🟩 |
| 7 | Box15C | 33% | 🟨 (fixed) |
| 7 | Rain | 33% | 🟦 (fixed) |
| 9 | Sand | 22% | 🟦 |
| 9 | Bunker | 22% | 🟩 (fixed) |

---

# BOX 24 — Sun / Rain / Sand / Squads / Box15A

## Sun 🟦 — 44%
Roster: Ninetales/Whimsicott (Drought, Spore/U-turn/Taunt) · Charizard/Hydreigon @Specs (SolarPower) · Venusaur/Chandelure (Chlorophyll, CM) · Blaziken/Aerodactyl (SD, FlareBlitz/BraveBird/EQ) · Regigigas/Gliscor @ToxicOrb (PoisonHeal, SD/Facade/KnockOff/EQ) · Blissey/Shuckle @RedCard (StickyWeb/FinalGambit).
- **Engine:** Regigigas/Gliscor Poison-Heal Facade wall is the real MVP (unbreakable, carries games); Ninetales Spore + Chlorophyll sweepers do the rest.
- **Flaw:** lives and dies by Drought — loses the weather war to Drizzle **and** Sand, and the Fire/Flying core is Rock Slide 4× fodder.
- **Not touched.** ⚠ **OPEN Q:** worth adding one weather-independent breaker (so it doesn't fold the moment Drought is overwritten)? Or leave as a dedicated sun team?

## Rain 🟦 — 33% *(rebuilt this session)*
Roster: **Ludicolo/Politoed @LO (SwiftSwim, Surf/GigaDrain/IceBeam/FocusBlast)** · Volcarona/Blastoise (RainDish, QD) · **Kabutops/Kingler @LO (SwiftSwim, SD/Waterfall/StoneEdge/AquaJet)** · Kingdra/Empoleon **@LO** (SwiftSwim) · Politoed/Whimsicott (Drizzle, Spore/U-turn) · Togekiss/Dragonite (rain Thunder, CM).
- **My changes:** cut the two off-theme Dragon-Dance sweepers (Azumarill/Garchomp, Dragonite/Slaking) → two Swift Swim abusers; Kingdra Choice Specs → **Life Orb** (it kept Choice-locking into resisted moves).
- **Result:** coherent now — beats Sand (couldn't before), draws Sun.
- **Ceiling:** hard-capped ~33% because Box15B **and** Squads run a *bigger* Kyogre — no rain team beats a bigger rain team in the mirror. This is a meta cap, not a build flaw.
- ⚠ **SOFT SPOTS I flagged / OPEN Qs:**
  - **Ludicolo's body = Politoed** was under-thought — the fusion came out **pure Water** (lost the Water/Grass Electric/Ground resist I wanted). Better body?
  - **Aqua Jet on Kabutops** = priority insurance for when rain is overwritten (Swift Swim off → slow). Defensible, but weak (40 BP, no Huge Power). Swap for coverage (Low Kick / Rapid Spin) instead?

## Sand 🟦 — 22%
Roster: Metagross/Haxorus (MoldBreaker DD) · Tyranitar/Regigigas (SandStream DD) · Azumarill/Garchomp (HugePower DD) · Blissey/Shuckle @RedCard (StickyWeb/FinalGambit) · Tyrantrum/Aerodactyl (RockHead, HeadSmash) · Volcarona/Nidoking @LO (SheerForce, special).
- **Engine:** Sand Stream + a stack of physical Dragon-Dance sweepers; Rock Slide/Head Smash punish Fire/Flying.
- **Flaws (two, both real):** (1) **all-EQ offense** → a single Ground-immune Flyer (Groudon/Gliscor) walls the whole team; (2) **no sleep answer** → Spore 0–3s it. Also runs **three** DD sweepers that overlap.
- **Not touched.** ⚠ **OPEN Q:** this is the next-most-fixable of your teams — it wants ONE non-Ground special breaker (to beat the Gliscor walls) and arguably fewer redundant DD mons. Want a pass?

## Squads 🟦 — 89% (co-#1)
Roster: Kyogre/Mew (Drizzle, WaterSpout/Spore/QD) · Dialga/Espeon (MagicBounce, CM) · Aegislash/Lugia (Multiscale, SpectralThief/Whirlwind/KingsShield) · Groudon/Gliscor @ToxicOrb (PoisonHeal) · Sylveon/Arceus (Pixilate ExtremeSpeed) · Ninetales/Celebi (Drought, QD).
- **The best shell in the field.** Kyogre Drizzle+Spore denies weather & disrupts; Sylveon priority nuke + Aegislash phazer + Groudon PH wall cover everything.
- **Only losses:** the Box15B mirror, and (in the old field) pure stall (no wallbreaker to break a Rest/CM staller).
- **Not touched — don't.** ⚠ **Minor OPEN Q:** it runs **both** Kyogre Drizzle *and* Ninetales Drought — two weather setters that overwrite each other. Slight incoherence; could swap the Ninetales for something that doesn't fight your own Drizzle. Cosmetic at 89%.

## Box15A 🟨 — 56% *(fixed this session)*
Roster: **Dialga/Espeon (MagicBounce, SR/CM)** · **Kyogre/Toxapex (Regen, Scald/IceBeam/Recover/Haze)** · Deoxys/Latios @Scarf (Levitate, Psychic/Draco/AuraSphere/Trick) · Reshiram/Clefable @LO (MagicGuard, CM) · Rayquaza/Garchomp @LO (AirLock, DD) · Dragonite/Arceus (Multiscale, DD/IronHead).
- **My changes (2 slots):** Espeon/Metagross → **Dialga/Espeon** (bulky Steel Magic-Bounce: reflects Spore/hazards, tanks Knock Off); Kyogre/Toxapex Toxic → **Ice Beam** (4× the Poison-Heal Gliscor walls it couldn't break).
- **Result:** 22→56% — now beats Sun and Overload 3–0.
- **Inherited highlights (not my picks, but good):** Reshiram/Clefable runs **Magic Guard + Life Orb** = full Life-Orb power with *zero* recoil/hazard/burn chip (elite combo). Deoxys/Latios @Scarf = clean fast revenge-killer + Trick.
- ⚠ **SOFT SPOT / OPEN Q:** **Rayquaza/Garchomp is redundant** with Dragonite/Arceus — both DD + ExtremeSpeed + EQ, both 4× Ice. Dragonite does it better (Multiscale, Iron Head for Fairies). First thing I'd cut on a 3rd edit — replace with a non-Ice-weak answer (Steel/Fairy, or a special breaker). Agree?

---

# BOX 25 — Box15B / Box15C / Momentum / Overload / Bunker
*(You said you want to give feedback on this box — extra notes + open questions below.)*

## Box15B 🟨 — 89% (co-#1)
Roster: Kyogre/Mew (Drizzle, WaterSpout/Spore/QD) · Dialga/Espeon (MagicBounce) · Giratina/Arceus @LO (DD/ExtremeSpeed/SpectralThief) · Groudon/Gliscor @ToxicOrb (PoisonHeal) · Kyurem/Salamence @Scarf (Moxie, DragonClaw/IcicleCrash) · Ninetales/Celebi (Drought, QD).
- **Best team in the field.** Same Kyogre Spore+weather shell as Squads, plus Giratina Spectral-Thief cleaner and a **Scarf Moxie Kyurem** revenge-killer.
- **Only loss:** Overload — its Groudon **and** Kyurem are *both* 4× Ice, and Scarf Electivire Ice Punch revenges them.
- **Not touched.** ⚠ **OPEN Q:** the quad-Ice Flying core (Groudon + Kyurem) is the one seam. Worth one non-Ice-weak member, or leave the 89%?  Also shares the Drizzle+Drought double-setter quirk with Squads.

## Box15C 🟨 — 33% *(fixed this session)*
Roster: Reuniclus/Dusknoir @LO (MagicGuard, **TR/Psychic/ShadowBall/FocusBlast**) · Slowbro/Cofagrigus (Regen, TR) · **Quagsire/Slowbro (WaterAbsorb, SR/Recover/Scald/IceBeam)** · Chandelure/Marowak @LO (FlashFire, NP) · Marowak/Rhyperior @LO (SolidRock) · Slaking/Snorlax (ThickFat, BulkUp).
- **My changes:** Reuniclus CalmMind → **Focus Blast** (TR-synergistic coverage); Rhyperior/Steelix → **Quagsire/Slowbro [Water Absorb]** (hard-walls Kyogre's rain Water Spout). *(First attempt was "Gastrodon" — that species isn't in this dex and silently became a Pikachu; caught and fixed.)*
- **Result:** 22→44% in the test — flipped Rain 0–3 → 2–1, beats the mid teams. (Now 33% after the Rain rebuild took a game back.)
- **Ceiling:** still 0–3 vs the top weather/Spore teams — it's slow Trick Room with no sleep answer, an archetype cap.
- ⚠ **OPEN Q:** it's a muddle of TR setters + a BulkUp Slaking + slow nukes. Commit *fully* to Trick Room (drop BulkUp Slaking for a pure TR nuke + a Lum/sleep answer), or leave it? It's an AI box team, so low priority unless you like it.

## Momentum 🟩 — 44% *(mine, not touched)*
Roster: Magnezone/Gardevoir @Specs (Analytic, VoltSwitch) · Rhyperior/Garchomp @LO (SD) · Gengar/Rotom @LO (**Levitate**, NP) · Lucario/Scizor @LO (Technician, BulletPunch) · Cofagrigus/Skarmory (Sturdy, SR/Whirlwind/WoW) · Weavile/Aerodactyl @Scarf (ToughClaws, U-turn).
- **Identity:** VoltTurn momentum + speed control. Gengar/Rotom's **Levitate** is the MVP — Ground-immune, walls the EQ-spam teams (Sand, Rain).
- **Flaws:** frail Life-Orb core swept by fast special coverage (Greninja); no Spore answer; Rhyperior/Garchomp is 4× Ice-weak.
- ⚠ **OPEN Q:** solid at 44%. Only obvious tighten is the 4×-Ice Rhyperior/Garchomp — but it's the physical wincon. Leave it?

## Overload 🟩 — 56% *(mine — the auto-loop's one real win)*
Roster: Gengar/Greninja @LO (Protean, NP) · Lucario/Infernape @LO (IronFist, SD) · Hydreigon/Salamence @LO (Levitate, NP) · **Scizor/Lucario @LO (Technician, SD/BulletPunch)** · Electivire/Aerodactyl @Scarf (MotorDrive, IcePunch/U-turn) · Weavile/Mamoswine @LO (ThickFat, SD/IceShard).
- **Identity:** all-out hyper-offense — fast mixed breakers + Scarf + priority. **Beats Box15B** (races it; Scarf Electivire Ice Punch 4× revenges its Ice-weak core).
- **The Scizor/Lucario Bullet Punch was the evolution loop's single durable gain** (took Overload 22→78% in an earlier field; still carries).
- **Flaw:** zero defensive backbone — Life-Orb frailty punished by priority (Sylveon) + phazing (Aegislash) + Spore (Sun). Inherent to HO; accept it.
- ⚠ **OPEN Q:** happy leaving it a glass-cannon, or want a Taunt lead / one bulkier pivot to survive Spore + priority?

## Bunker 🟩 — 22% *(mine, fixed this session)*
Roster: Ferrothorn/Cofagrigus (IronBarbs, Spikes/LeechSeed/WoW) · **Dragonite/Gyarados (Multiscale, DD/DragonClaw/EQ/Roost)** · Blissey/Skarmory (SoftBoiled/SeismicToss/Toxic) · Bisharp/Scizor @LO (Defiant, SD/KnockOff/SuckerPunch) · Starmie/Tentacruel (RapidSpin) · **Suicune/Togekiss (SereneGrace, CM/Scald/AirSlash/Roost)**.
- **My changes:** gave dead stall a *win condition* — Slowbro/Tangrowth → **Dragonite/Gyarados** (Multiscale DD + Roost bulky sweeper); Suicune/Empoleon → **Suicune/Togekiss** (Water/**Flying** CM wincon, immune to the EQ that swept the old one).
- **Result:** 11→22%, and it now **beats Overload** instead of passively losing.
- **Trade-off:** lost its niche win over Squads (it's no longer *pure* stall, so it can't Toxic-grind the Fairy team the old way).
- ⚠ **OPEN Q:** this is the honest archetype question — is a stall/bulky team even worth keeping in a meta this fast + Spore-heavy? Either lean it further toward bulky-offense (more wincons) or retire the concept. Your call.

---

## Consolidated open questions for your feedback

1. **Rain** — better body for the Ludicolo SwiftSwim mon (keep Grass?), and drop Aqua Jet for coverage?
2. **Box15A** — cut the redundant Rayquaza/Garchomp for a non-Ice-weak answer?
3. **Sand** — do a real pass? (needs 1 non-Ground special breaker + fewer redundant DD sweepers)
4. **Box15C** — commit fully to Trick Room + add a sleep answer, or leave it?
5. **Bunker** — push toward bulky-offense, or retire pure stall?
6. **Squads / Box15B** — resolve the Drizzle+Drought double-weather quirk? (cosmetic at 89%)
7. **Overload** — add a Taunt lead / one pivot for Spore + priority insurance?

---

## Autopilot progress log (Sid resting — running unattended)

**Principle established:** a fusion is only worth it if the **body contributes** a move, ability, typing, or stat the head lacks. If the head is already a complete package, **mono is better** (caught via the Hydreigon case: every Dark/Dragon fusion *dilutes* its SpA 314; mono wins). This is now a core audit lens.

**Fusion redesigns applied this session (all stat-verified with fixed natures):**
- Box15A: Rayquaza/Garchomp (redundant, 4× Ice) → **Marowak/Arceus @Thick Club** — 684 effective Atk, STAB priority ExtremeSpeed (Sid's idea). Fusion is *essential* (Marowak = Thick Club eligibility, Arceus = stats + Normal typing).
- Box15C: Marowak/Rhyperior → **Thick Club** (2× Atk, verified via `isFusionOf(:MAROWAK)` in engine).
- Momentum: Rhyperior/Garchomp (weaker+slower than mono-Garchomp) → **Garchomp/Haxorus** [Mold Breaker] — Atk 318 vs 296, pure Dragon (2× Ice not 4×).
- Overload: Hydreigon/Salamence (lost Draco STAB) → **mono Hydreigon** (fusion only dilutes it — SpA 314 mono is best).
- Bunker: Dragonite/Gyarados (strictly worse Dragonite) → **Dragonite/Scizor** [Multiscale] — Dragon/Steel, Ice-neutral (tradeoff: −9 Atk for the typing).
- Rain: Ludicolo/Politoed (pure Water) → **Ludicolo/Sceptile** — Water/Grass + Spe 305.

**Correction logged:** my first `explore_fixes` probe didn't fix natures → random-nature noise gave a false "Kingdra boosts SpA" claim. Always fix nature when comparing fusion stats. Guard: `probe3.rb` uses fixed natures.

**Standings after all fusion fixes (bo3):** Box15B 89 · **Box15A 78** (was 22 — Marowak/Arceus) · Overload 67 · Momentum 56 · Sun 56 · Squads 56 (was 89 — field caught up) · Rain 44 · Sand 22 · Bunker 22 · **Box15C 11** (new bottom). Buffing everyone compressed the ladder (win% is zero-sum); absolute build quality rose but relative standings reshuffled.

**Next:** per-team audit (agent per team, mon-by-mon, two-question lens) → final assessment → resolve → materialize.

---

## Per-team audit findings (agent per team, mon-by-mon)

### Box15C (1-8, dead last) — ARCHETYPE problem, not a fusion problem
- Fusions mostly fine (Reuninoir, Slowgrigus, Chandelwak, Maroperior @ThickClub Atk370, Slalax = no-Truant Snorlax fusion all pass the body-contributes test).
- **Trick Room is unviable in this meta** — it never lands a single logged game (opponents open with Spore / 4× Knock Off / faster weather). Half the team (Spe 106/127/133) isn't even slow enough to *need* TR, so 2 setter slots buy nothing.
- Stacked Water 4× weaknesses (Maroperior/Chandelwak/Quagbro) get bulldozed by Rain; zero sleep answer → 20-turn sleep-switch death spirals.
- **Quagbro (Quagsire/Slowbro) = MONO-BETTER** → mono Quagsire (Water/Ground, **Unaware**) directly fixes "everyone sets up on us."
- Verdict: **ground-up rebuild** — drop TR, cut a passive setter (Slowgrigus), keep Slalax/Maroperior/Chandelwak as bulky-offense, add a sleep/weather answer. (AI box team, low priority — flagged for Sid.)

### Box15A (7-2, #2) — sound fusions, two structural holes
- **5/6 fusions beat both monos** (Dialga/Espeon, Kyogre/Toxapex, Deoxys/Latios, Reshiram/Clefable = best mon, Dragonite/Arceus). No mono-better calls.
- Holes: (a) **sleep** — only Dialga/Espeon's Magic Bounce answers Spore; once pivoted out, rest get locked (lost Box15B). (b) **Ghost/Electric special attackers** blow past the physical walls (lost Momentum to Gengar/Rotom + Magnezone).
- **Marowak/Arceus (Sid's idea) = weakest slot**: 684 Atk but ExtremeSpeed (Normal) is IMMUNE vs the Ghost meta (Gengar/Giratina/Aegislash/Reuniclus), and it's **redundant with Dragonite/Arceus** (2nd Arceus ES/EQ physical). Audit says RE-FUSE into an anti-Ghost/sleep answer. *[JUDGMENT CALL — it's Sid's idea + team is 78%; flag, don't auto-revert.]*
- Clear refinements: **Deoxys/Latios: Choice Scarf → Life Orb/Lum** (Choice-lock = Spore magnet); add a **Lum Berry** somewhere for sleep insurance.

### Box15B (8-1, #1) — dominant, but 2 seams
- 5/6 fusions clearly beat both monos. **Kyurem/Salamence = stat-stick** (Dragon/Flying = mono Salamence, discards Kyurem's Ice identity, stacks a 2nd 4×-Ice Flyer next to Groudon) → RE-FUSE. Dialga/Espeon adjust set (recovery/CM over passive SR/Toxic).
- Seams: 3 mons Dark-weak (Kyogre/Giratina/Dialga-Espeon, none resists Dark) + 2 mons 4× Ice (Groudon+Kyurem). Overload hits both at once = its only loss.

### Momentum (5-4, mine) — well-built VoltTurn
- 6/6 fusions justified; **Garchomp/Haxorus re-fuse ENDORSED** (pure Dragon 2× Ice vs old 4×). Cofagrigus/Skarmory (Ghost/Flying, 223 SpD) folds to special spam → try mono Skarmory (resists Ice + Spikes). No sleep answer. Gentom wants Dark/Normal coverage (Focus Blast).

### Overload (6-3, mine) — 6/6 KEEP, best-built team
- Every fusion beats both parents; **mono-Hydreigon endorsed.** Losses are structural (no sleep, no weather, phazing), not roster. Top fix: **Geninja Ice Beam → Taunt** (blanks the Spore/phaze lead — "likely flips Sun"); Ice Beam is redundant with 3 other Ice users.

### Bunker (2-7, mine) — pure stall not viable
- **Bisharp/Scizor = stat-stick** (all Bisharp's kit, Scizor only stats) → RE-FUSE/drop, redundant with Dragonite/Scizor. Ferrothorn/Cofagrigus lost Grass = lost Spore immunity. Blismory/Suikiss both wear an Electric weakness the monos wouldn't. **Suicune/Togekiss = MVP.** Pivot to bulky-offense around it.

### Sand (2-7, yours) — 4 DD sweepers funnel into EQ
- **Tyrantrum/Aerodactyl = stat-stick** (Rock/Flying = mono Aerodactyl) → RE-FUSE into a Grass sleep-answer that also hits Ground-immune Flyers. Azumarill/Garchomp: Dragon Claw → **Aqua Jet** (breaks DD-mirror loop + priority). Add Lum Berry. One Ground-immune Flyer (Groudon) blanks the whole team; 2 mons share 4× Fighting.

### Rain (4-5, yours) — coherent rain core now
- 6/6 fusions justified (Ludicolo/Sceptile +80 SpA/+129 Spe over mono). Set fixes: **Togekiss/Dragonite Thunder → Flamethrower** (Thunder is immune-blanked by every Ground wall; Fire nukes the Steel/Grass walls that hard-wall it). **Politoed/Whimsicott WorrySeed → Encore/Scald** (its self-stall loops caused all three 0-3 losses). Add Lum/Chesto.

### Squads (5-4, was #1) — double-weather self-sabotage
- 4/6 fusions elite (Kyogre/Mew, Aegislash/Lugia, Groudon/Gliscor, Sylveon/Arceus). **Ninetales/Celebi = the culprit**: its Drought overwrites Kyoew's own Drizzle, and it's a 3rd Fire-weak body (with Dialga/Espeon + Aegislash/Lugia) → RE-FUSE into a rain-abuser that resists Fire. Dialga/Espeon passive (most cuttable). 89→56 is ~60% field-catching-up, ~40% the double-weather + Fire weakness.

### Sun (5-4, yours) — glass-cannon, weather-dependent
- All 6 fusions justified; **Regigigas/Gliscor (Poison Heal bypasses Slow Start) = MVP, weather-independent.** Set fixes: **Charizard/Hydreigon: Overheat → Draco Meteor** (it's all-Fire and gets walled — Draco is a weather-independent Specs breaker off 357 SpA). **Blaziken/Aerodactyl is the lone 4× Rock body** → consider mono Blaziken (Speed Boost, Rock-neutral). All 4 losses = Drought overwritten by Drizzle/Sand.

## CROSS-TEAM SYNTHESIS
1. **SLEEP is the meta-defining hole** — 7 of 8 teams get Spore-locked with no answer. Highest-leverage fix everywhere: Lum/Chesto on a sweeper, or a powder-immune Grass / Insomnia / Sap Sipper mon. (Caveat: partly the sim AI switch-looping under sleep — a pilot flaw inflating it.)
2. **Fusions are mostly sound** — the body-contributes principle holds across ~52/60 mons. The failures are the "stat-stick" pattern (Kyurem/Salamence, Bisharp/Scizor, Tyrantrum/Aerodactyl) — same mistake class as the ones already fixed.
3. **Zero-sum ladder** — buffing everyone just reshuffles ranks; absolute quality is what improved.

## RESOLUTION PLAN
**Tier 1 — auto-apply (low-risk set/move/item, identity-preserving, all audit-endorsed):** Rain Thunder→Flamethrower + WorrySeed→Encore; Overload Geninja Ice Beam→Taunt; Box15A Deoxys Scarf→Life Orb; Sand Azumachomp Dragon Claw→Aqua Jet; Momentum Gentom SludgeBomb→Focus Blast; Lum Berry on a key sweeper for the most sleep-exposed teams. Re-test + materialize.
**Tier 2 — FLAG for Sid (judgment / identity / rebuild, NOT auto-done):** Box15C TR rebuild (archetype dead); Bunker stall→bulky-offense + re-fuse Bisharp/Scizor; Box15A Marowak/Arceus re-fuse (it's YOUR idea + team's at 78% — your call); Box15B Kyurem/Salamence re-fuse (top team, careful); Squads Ninetales/Celebi re-fuse (kills the double-weather); Sand Tyrantrum/Aerodactyl→Grass sleep-answer; Sun Blaziken/Aerodactyl 4× Rock.

**STATUS:** Tier 1 applied + re-tested + **materialized to Box 24/25** (backup 20260718_030834, collateral NONE). Tier 2 awaits Sid.

## FINAL ASSESSMENT (autopilot run)

**What's now live in Box 24/25** — the fully hand-tuned, audited field with all fusion redesigns + Tier-1 set fixes, all L100, all species verified in-dex, originals + Box 16 untouched.

**Standings, final (bo3):** Box15B 78 · Box15A 78 · Squads 67 · Overload 56 · Momentum 56 · Sun 56 · Rain 33 · Box15C 22 · Sand 22 · Bunker 22.

**The honest headline: two kinds of change, two kinds of result.**
- **Fusion redesigns = real, validated wins.** Box15A 22→78 (Marowak/Arceus + Ice Beam + Dialga/Espeon), and the whole field is better-built — the audit confirmed ~52/60 fusions now "earn themselves" vs their monos. These moved the needle and are the reason to materialize.
- **Tier-1 set/move tweaks = competitively sound but sim-neutral.** Win rates barely moved (some ±11 up/down, netting flat). Situational moves (Taunt, Encore) and coverage swaps depend on pilot skill the Haiku sim-agents don't have; the sim under-rewards them. They help *your* in-game play, but don't expect the sim to show it. **If you'd rather, revert Overload's Geninja Ice Beam→Taunt** (its one clear regression, 67→56 — Ice Beam is more generally useful when the pilot won't time Taunt).

**Biggest unsolved lever (needs your call):** SLEEP. Every team gets Spore-locked and the sim AI switch-loops under sleep — but that's *half pilot flaw*. The highest-value single project isn't more team edits; it's **fixing the sim's sleep-handling (attack through sleep instead of switch-looping)**, then re-reading whether the mid-tier teams are actually fine. I did NOT change the pilot autonomously (it affects all results).

**Tier-2 decisions waiting for you** (all with concrete recs above): Box15C (retire/rebuild Trick Room), Bunker (stall→bulky-offense), the 3 stat-stick re-fuses (Box15B Kyurem/Salamence, Bunker Bisharp/Scizor, Sand Tyrantrum/Aerodactyl), Squads double-weather (Ninetales/Celebi), and **whether to keep your Marowak/Arceus** (I kept it — huge Atk, but redundant with Dragonite/Arceus and its ExtremeSpeed is Ghost-blanked).

## Pilot upgrade + Ubers control (Sid's ideas)
- **Sleep handling added to the pilot system prompt** (`agent_battle.rb`): if asleep, STAY IN (don't switch-loop — the #1 pilot flaw the audits found); a statused mon still attacks; only switch for a real reason. Fixes the sleep losses at the source across ALL teams instead of patching each with Lum Berries.
- **Real per-team game plans** (`roster.rb PLANS`): each team now gets a 2-3 sentence strategy (wincon, sequencing, weather-war handling, key threats) piped into every turn, replacing the terse one-liners.
- **2 vanilla Gen-5 Ubers control teams** added (sim-only, not materialized): **UbersOff** (Scarf Kyogre / DD Rayquaza / Extreme-Killer Arceus / Darkrai Dark Void / Specs Dialga / Ferrothorn) and **UbersBal** (Groudon+Kyogre weather / Giratina / Band Scizor / CM Latias / NP Mewtwo). Benchmark: can the fusion teams beat real competitive teams? Also — Kyurem/Salamence re-fused to **Kyurem/Dialga** (Dragon/Steel, Ice-neutral, de-stacks Box15B's quad-Ice).
- **Threat-scouting added to the pilot:** (a) TEAM PREVIEW — the opponent's 6 mons (decoded to Head/Body) are now shown every turn; (b) a THREAT GLOSSARY in the system prompt so the pilot recognizes and pre-positions for known threats (Whimsicott/Ninetales/Politoed → Spore; Arceus → ExtremeSpeed priority; Gliscor → Poison-Heal EQ/Electric-immune wall, break with Ice; Aegislash → Spectral Thief/Whirlwind, don't set up; Kyurem/Weavile → 4× Ice; Kyogre → Drizzle). This mirrors how a real player reads a team.
- **KEY EXPERIMENT (running):** 12-team round-robin under the FULLY threat-aware pilot. Two reads: (1) do the sleep-crippled teams (Sand/Box15C/Bunker) recover — proving those were *pilot* flaws, not team flaws; (2) where do the vanilla Gen-5 Ubers control teams land vs the fusions.

## RESULT: threat-aware pilot + Ubers control (12 teams, 66 bo3 battles)
Standings: UbersBal 82 · **Squads 82** · Box15A 73 · UbersOff 73 · Box15B 64 · Sand 55 · Rain/Overload/Sun 45 · Momentum 18 · Box15C/Bunker 9.

**Three findings:**
1. **Top fusion teams match real competitive teams.** Squads (82%) ties the UbersBal control (and beats UbersOff h2h); Box15A ties UbersOff; Sun even beat UbersBal. The Ubers controls are strong but don't dominate — validates that the good fusion builds are competitive-grade, not just fusion-vs-fusion good.
2. **Smarter pilot is a NON-uniform rising tide.** Sand 22→55 (its flaws were partly PILOT — proper sleep/weather play recovered it). But Momentum 56→18, Box15C/Bunker →9 DROPPED — their old win-rates came partly from opponents misplaying; competent play on both sides exposes their real weaknesses (frailty / dead-slow TR / passive stall). They lose to the Ubers control badly.
3. **Trustworthy numbers** — 0 fallbacks, coherent standings. This is the cleanest read we've had, and it's the one to believe.

**Confirmed tiering:** Ubers-competitive = Squads, Box15A. Solid mid = Box15B, Sand, Rain, Overload, Sun. Genuinely weak (rebuild/retire, a good pilot can't save them) = Momentum, Box15C, Bunker.

## "Can fusions actually be broken?" experiment (Degen + OU + Ubers arena)
**Why fusions don't auto-dominate:** the stat formula is a WEIGHTED AVERAGE `(2*dom+other)/3`, not a sum. Fusing dilutes toward the mean, so a fusion is often WEAKER than the stronger mono parent (Groudon/Gliscor total 1505 vs mono Groudon 1661; Giratina/Arceus 1739 < mono Arceus 1761). Fusions trade RAW STATS for VERSATILITY (custom typing/ability/movepool/immunities).
**How to weaponize it (beat the dilution):**
- Fuse TWO ~equal ubers (both already max → minimal dilution): Kyogre/Arceus 1745, Arceus/Groudon 1739, Mewtwo/Arceus 1723 — near-max stats + custom typing/ability. (But orientation matters: Groudon/Rayquaza 1633 < mono Groudon — head/body governs which stats.)
- Stack MULTIPLIERS that bypass the average: Thick Club / Huge Power (x2 Atk), Poison Heal (bypass Regigigas Slow Start), Magic Guard + Life Orb (free 1.3x).
- Multiscale + Dragon Dance bulky sweeper (Sid's insight): **Lugia/Groudon** (Psychic/Ground, Multiscale, Atk325/Def308/SpD300) — sacrifices ~20 Atk vs mono Groudon for Multiscale + mixed bulk + setup; also takes Stealth Rock x1 (vs Ground/Flying x2), preserving Multiscale. A resilient win-con.
**Arena (running):** Degen (max-broken: Kyogre/Arceus, Thick-Club Marowak/Arceus, Poison-Heal Regigigas/Gliscor, Mewtwo/Arceus, Multiscale-DD Lugia/Groudon, Magic-Guard Reshiram) vs UbersOff, UbersBal, OU control, and our best 2 (Squads, Box15A). Answers: do WEAPONIZED fusions cleanly beat Ubers (=> earlier teams were just under-optimized, not the mechanic)? Where does OU land?

## Known engine caveats (so results are read correctly)
- **Dex is limited** — unknown species silently become Pikachu. Always validate (`Editor.valid_species?`). Confirmed *absent*: Gastrodon, Seismitoad, Barraskewda, Floatzel, Samurott, Beartic.
- **Fusion typing is unpredictable** — always build-check the actual type (Ferrothorn/Rhyperior came out Steel/Rock, Ludicolo/Politoed pure Water, Gastrodon/Quagsire Electric/Ground = the Pikachu fallback).
- **Some losses are pilot error, not team flaws** — the sim AI switch-loops under sleep and occasionally over-sets-up. Read "Spore losses" with that grain of salt.
- **Field is interconnected** — buffing bottom teams moved the top (Squads 78→89 once Bunker stopped countering it). Can't tune one team in isolation.
