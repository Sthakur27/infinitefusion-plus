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

**Next:** per-team audit (agent per team, mon-by-mon, two-question lens) → final assessment → resolve → materialize.

---

## Known engine caveats (so results are read correctly)
- **Dex is limited** — unknown species silently become Pikachu. Always validate (`Editor.valid_species?`). Confirmed *absent*: Gastrodon, Seismitoad, Barraskewda, Floatzel, Samurott, Beartic.
- **Fusion typing is unpredictable** — always build-check the actual type (Ferrothorn/Rhyperior came out Steel/Rock, Ludicolo/Politoed pure Water, Gastrodon/Quagsire Electric/Ground = the Pikachu fallback).
- **Some losses are pilot error, not team flaws** — the sim AI switch-loops under sleep and occasionally over-sets-up. Read "Spore losses" with that grain of salt.
- **Field is interconnected** — buffing bottom teams moved the top (Squads 78→89 once Bunker stopped countering it). Can't tune one team in isolation.
