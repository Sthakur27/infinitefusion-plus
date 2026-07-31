# Pokémon Infinite Fusion — sidmod

A personal fork of [Pokémon Infinite Fusion](https://github.com/infinitefusion/infinitefusion-e18)
built around one idea: **make the game a competitive sandbox.** Fusions get built to a spec instead
of grinded for, opponents actually try, and everything is measurable offline before it touches a
save file.

Three layers sit on top of vanilla:

1. **Gameplay & QoL** — smarter enemy AI, a Random Battle mode drawn from your own PC, and a long
   tail of friction removal (turbo on by default, straight to the save select, no item cheese).
2. **Creator tooling in-game** — searchable pickers everywhere, a fusion injector, a PC exporter,
   difficulty switchable mid-save.
3. **An offline toolchain** (`tools/sidmod_editor/`) — edit saves behind a verification gate, query
   the real engine for ground-truth fusion stats, and run headless battles at ~100 games/sec to
   rate teams.

Built on upstream **6.8.2**. Tracks upstream's `releases` branch — see [FORK.md](FORK.md).

> Everything here is documented change-by-change in [`sidmod.txt`](sidmod.txt) — 50+ entries with
> what changed, why, and how to revert it. That file is the source of truth; this README is a tour.

---

## Feature showcase
<img width="1782" height="1498" alt="image" src="https://github.com/user-attachments/assets/d3932004-c911-48ac-84b3-840f3379dfab" />
<img width="1080" height="852" alt="image" src="https://github.com/user-attachments/assets/672d452b-8f0c-4e49-a71c-0eb45515101c" />
<img width="2686" height="1539" alt="image" src="https://github.com/user-attachments/assets/4e96490a-978b-4d98-88f4-b91eb1c5540a" />

### Battle

| Feature | What it does |
|---|---|
| **Random Battle** | Pause menu → fight a 6-mon team assembled from your own **Lv100 + held-item** Pokémon, party and PC alike. Two-stage menu. **Stage 1 — who plays what:** bring your own party, take a lent team for a mirror match, hand your party to the AI and watch, or sit out entirely and watch AI vs AI. **Stage 2 — the generator:** `{Chaos, Smart, Smart v2} × {OU, Ubers}`, or OU Apex. Chaos is Species-Clause-legal random; Smart greedily seeds a hazard-setter, a wall and a pivot, then fills for offensive and typing variety. OU filters legendaries except the sub-600 birds/beasts/golems. |
| **Watch modes** | The AI drives your side too, so you can spectate a real match between two generated teams. Under the hood it flips `battle.controlPlayer`, routes post-faint switch-ins to the AI instead of stopping to ask you, and — importantly — opens the Smart AI gate for player-owned battlers, so it's genuinely Smart-vs-Smart rather than vanilla AI getting bullied. Spectated and lent-team battles don't give exp; piloting your own team still trains it. |
| **Smart v2 — archetype teams** | Picking a `Smart v2` row opens a plan menu — each entry describes itself as you scroll, so you don't need to already know what "bulky setup" means. When you're being lent a team you choose **both** plans: yours, then theirs (defaulting to random). Ask for rain and leave the rest random and you'll get a rain team against something that is deliberately *not* rain. Options: **Random archetype**, or one of eleven named plans — rain, sun, sand, hyper offense, balance, hazard stack, trick room, priority, choice scarf, bulky setup, stall. Each is built to *execute that plan* (a rain team leads its Drizzle setter and stacks Swift Swim payoff mons), not merely to look balanced. Ported from the offline ladder's team generator; it also **chooses the lead**, which the other modes don't. If your PC can't supply the parts for a plan, it says so instead of shipping a generic team with the wrong label. |
| **OU Apex** | A seventh mode: fight the strongest teams the offline Elo ladder ever produced, chosen from a menu by rank and rating (currently 15 teams, 1687–1890 Elo, against a ladder floor of 1251). The teams are **shipped frozen** in `Data/sidmod/ou_apex.rxdata` rather than referenced by box/slot, so they don't need to exist in your PC and reorganising your boxes can never change them — each one is exactly the roster that earned its rating, lead included. Rank is *not* a difficulty order: #1 beats #15 six-nil but loses to #8 six-nil. |
| **Losing costs you nothing** | A practice battle shouldn't cost you a Life Orb, a warp home, or your wallet. Consumed held items and bag stock are restored afterwards (both sides), and losing or drawing a Random Battle skips the whole defeat path — no black-out, no teleport to a Pokémon Center, no payout to the winner. Winning still gives exp. |
| **Smart Trainer AI** | A plan-based enemy AI (`055_sidmod/SmartTrainerAI.rb`) that compares attacking, setup, status, healing, phazing and switching as competing plans, with a beam search over an abstract state and an expected-damage model. |
| **No item cheese** | Enemy trainers never use Full Restore / potions / X items mid-battle. |
| **Hard mode, retuned** | Enemy level scaling is a single flat multiplier with no curve (`Settings::HARD_MODE_LEVEL_MODIFIER`), applied consistently to enemy levels, your level cap and the over-levelled exp penalty — and **adjustable per save from the debug menu** (*Player options → Set Game Mode / Difficulty → Hard multiplier*, 100–500%) instead of only by editing Settings. Hard mode also **shows you the incoming Pokémon** on a switch. |
| **Exp dampener** | A single global **×0.9** on exp gained. Earlier, larger exp experiments (always-on exp share, steeper over-level penalties) were all reverted to vanilla — only the dampener survives. |
| **Catch anything** | The "Trainer blocked your Poké Ball" guard is off, so trainer Pokémon can be caught. |

**On the AI, honestly:** it is measured as *exactly as strong as* the stock Essentials AI it
replaces — 0.500 over 1440 games on identical teams and seeds. The v2/v3 work fixed a real
regression (the original suppression multipliers were ~37–41 ELO *worse* than vanilla) and no more.
Deeper search, switch prediction and team-level planning were all implemented, measured, and
reverted. `sidmod.txt` records what was tried so it isn't redone blindly. It plays *visibly* better
(it heals, statuses and phazes instead of mashing attacks) without being stronger on the scoreboard.

**On Smart v2, honestly:** the eleven plans are *not* balanced against each other. Measured against
the old Smart builder over 880 mirrored games, they ranged from **0.41** (trick room) to **0.88**
(rain) — so "Random archetype" is partly a difficulty lottery, and picking rain is close to picking
hard mode. The overall edge over Smart v1 is 0.599, which is real; the per-plan spread is only 80
games each and shouldn't be read as a ranking beyond "rain strong, trick room weak *in this PC pool*".
Because the plans are drawn from **your** boxes, the numbers are a property of your collection, not
of the archetypes in general.

### PC & storage

**Bulk select & carry.** Grab a whole group of Pokémon and move them as one block, with the rough
edges fixed:

- **Out of bounds is refused, not improvised.** Pasting a 6-wide row starting at column 2 buzzes and you keep holding the group. Previously it fell through to a spiral "find any free slot" fallback that scattered mons into unrelated parts of the box.
- **Occupied targets swap.** Whatever was in those exact slots comes up into your cursor with its shape preserved — like `Shift` for a single mon. Only the slots you pointed at are ever touched.
- You can change box while still carrying a group.

**Team swap** — exchange your entire party with a box row in one commit. A box row is exactly six
slots, so it's exactly one team: sand team out, rain team in. This can't be done with multi-select at
all, because the stock code refuses to lift your last able Pokémon — swapping both sides in a single
commit means the party is never empty mid-move. It refuses on an empty row, a row with no able
Pokémon, or a party mon holding mail, and uneven counts are fine (a party of 3 into a row of 6 just
takes what's there).

**PC search** — open the PC, press **Up** to highlight the box name, press **A**, choose *Search*.

| Filter | Behaviour |
|---|---|
| Type | Pick a primary type, then optionally a secondary. Order-independent, so it works on fusions and dual-types alike. |
| Name | Matches nickname *or* species — and for a fusion it matches **either half**, so "char" finds both `Char/X` and `X/Char`. |
| Level | Range. |
| Dex # | Range. |

Results read `[B#.#] Nickname L## [Type1/Type2]` with explicit `h:` / `b:` rows so you can see what
the fusion actually *is*, and picking one jumps straight to that box and slot. The picker is a
live-filter list (type to narrow, `UP`/`DOWN` to move, `HOME`/`END` for the ends, `ENTER` to choose)
— keyboard-only by design, because with text input on, the letter keys bound to `USE`/`BACK` would
fire while you type.

**Live wallpaper preview** — the box behind the list redraws as you scroll the wallpaper picker, and
backing out restores the one you started on. **Wallpaper lottery is free** — no Quest Point cost.

### Quality of life

| | |
|---|---|
| **Boot doesn't stall on a 19 MB download** | Vanilla re-fetches the custom Pokédex (`dex.json`, ~19 MB) synchronously on the main thread *every* launch, before the load screen can draw — `download_file` sends no conditional headers, so the whole file comes down each time. It's now skipped while the local copy is under `Settings::DEX_REFRESH_INTERVAL_HOURS` old (24h; `0` restores stock). The freshness check fails *closed*, so the worst case is the old behaviour, never a missing dex. Relatedly, a failed download can no longer kill startup: `download_file` rescued only `ENOENT`, letting an `EINVAL` from an interrupted write escape into a boot with no load screen to catch it — it now rescues `SystemCallError`. |
| **New Game+ keeps your Pokémon intact** | Transferred Pokémon keep their **level**, their **evolved form** (no de-evolving back to babies), their **moves** and their **stats**. Vanilla resets all four. Ownership, OT and Pokédex registration still update normally. |
| **Turbo by default** | Speed-up starts at **2×** and cycles 2 → 3 → 1, instead of starting at 1×. |
| **Straight into your save** | Title screen, intro cinematic and the startup announcement popups are all skipped — you land on the save-select / continue menu. |
| **Windowed on launch** | No forced fullscreen. |
| **Fly / teleport anywhere** | The badge requirement, follower check and outdoor-map check on Fly are removed. |
| **Noclip** | Hold Xbox **X** (`Input::ACTION`) while moving, in debug builds. |
| **Instant capture** | Hold Xbox **X** while throwing a ball for a guaranteed catch. |
| **Refight any trainer** | Hold Xbox **X** and talk to a beaten trainer to rematch them. Works for standard trainers; story trainers (gym leaders, rivals, Rocket grunts) use custom scripts and fall through to normal dialogue. |
| **Gym leader rematches always up** | All 16 rematchable leaders are present regardless of time of day — vanilla gates each one to a specific time via map events with no script-level switch. |
| **Traded Pokémon behave** | Traded fusions can be unfused, and foreign Pokémon never disobey. |
| **Type-expert challenges** | Accept any Pokémon from your party instead of only ones matching the specialist's type. |
| **Difficulty & mode, mid-save** | Switch Classic / Remix / Legendary and Easy / Normal / Hard on an existing save. Legendary re-rolls all trainer teams into legendary fusions (behind a confirm prompt) and deliberately **skips** vanilla's dump of legendary eggs into your PC. |

### Creator & debug tools

Building a competitive mon by hand meant a lot of menu-walking. Most of that is gone.

**EV / IV presets** — `Level/stats… → EV/IV/pID… → Set EVs` gains three one-click spreads next to
the randomise entries:

| Preset | Spread |
|---|---|
| Max Attack Speed | 252 Atk / 252 Spe / 6 HP |
| Max Sp. Attack Speed | 252 SpA / 252 Spe / 6 HP |
| Max Defenses | 252 Def / 252 SpD / 6 HP |

`Set IVs` gains **Max all** (31 across the board), and `Moves…` gains **Max PP all moves**, which
sets PP Up to 3 and refills every move at once instead of walking into each move individually.
Moves taught through the debug menu also arrive at full PP with 3 PP Ups automatically — but only
when the learn actually succeeded, so cancelling a forget-a-move prompt changes nothing.

**Searchable pickers** — everything that used to be an internal-ID-ordered wall of entries is now
type-to-filter:

- **Items** — ~800 entries listed by ID number, effectively unusable. Now alphabetical with a live search box, still showing the ID.
- **Species** — `Set species` and `Set fusion species` take a substring (`sala` → Salamence) with ranked matches (exact, then prefix, then contains). The fusion flow prompts for head, then body. Blank input falls back to the old dex-number picker.
- **Moves** — `Teach move` / `Teach legit move` ask up front whether to *search by name* or *browse the full list*. "Legit" restricts the pool to genuinely learnable moves in either mode.
- **Switches & variables** — press **Z** to filter 1000+ entries by name. Rows keep their real IDs while filtered.
- **Trainers** — press **Z** in the Test Trainer Battle list to search by name.

**Other debug additions**

- **Gender lock bypass** — set male / female / genderless even on single-gendered or genderless species. Cosmetic only; breeding and evolution logic may still read the species' gender ratio.
- **Fusion injector** — describe a fusion in chat, get a JSON spec written to `Data/sidmod/injections.json`, then drop it into a box from a debug command with a per-mon confirm. The spec is archived after a run so it can't be injected twice.
- **PC export** — read-only JSON dump of your party and every box, so an assistant can actually see your PC. Empty slots stay `nil` so slot indices remain meaningful.
- **Test battle from the pause menu** — with the party full-healed before *and* after, so test fights don't leave chip damage, and key rematch trainers pinned to the top of the selector.
- **Benchmark opponents** — vanilla Gen-5 OU and Ubers teams available as debug battle opponents.

### Offline toolchain (`tools/sidmod_editor/`)

| Tool | Purpose |
|---|---|
| `apply.ps1` → `edit_save.rb` → `verify_edit.rb` | Build or edit Pokémon in a save file. Refuses to run while the game is open, backs the slot up, and **rejects any write that doesn't verify as "collateral problems: NONE"** — only the slots you targeted may differ. |
| `sim/fusion_inspector.rb` | The ground-truth oracle. Builds a candidate in the real engine and reports actual typing, stats vs both parents, 4×/2×/immune matchups, resolved ability, and auto-flags (stat tax, new 4× weakness, dead ability). |
| `sim/prun.rb` | Parallel LLM-piloted battles for A/B testing team changes. |
| `sim/nbattle.rb` + `nsearch2` / `ntourney` / `nladder` | The deterministic SmartAI plays both sides — no API calls, ~100 games/sec. Rates every mon in your PC, hill-climbs teams against a held-out field, and runs Elo ladders. |
| `sim/narchetype.rb` + `nlead.rb` | The ladder's plan-based team generator (eleven archetypes) and lead picker. Both are now **mirrored in-game** as Random Battle's Smart v2 — the offline copy is rating-driven, the in-game copy substitutes stats and typing since live PC mons carry no ratings. |
| `sim/nexport_apex.rb` | Freezes the top N teams of a ladder run into `Data/sidmod/ou_apex.rxdata` for the in-game **OU Apex** mode. Ships the real Pokémon rather than box/slot keys, because those keys rot against a live save — on `ladder_ou4`, 6 of the 38 mons the top 15 relied on had already been replaced, one by a Lv50 mon in a wall's slot. |
| `sim/interactive_battle.rb` | Drive a battle turn-by-turn yourself against the AI, with a computed turn card (real damage ranges, ability-aware effectiveness, bench answers) and deterministic rewind. |
| `sprites/` | **Generative sprite pipeline** for fusions with no custom art: find them in a save, extract the game's autogen sprite as a baseline, write a palette-budgeted description (real sprites use 12–16 colours), generate, fit to the 96px grid, and install with a backup. |

`tools/sidmod_editor/RUNBOOK.md` documents all of it, including the known-open harness bugs — worth
reading before trusting a benchmark.

---

## Running the game

**Windows** — use `Game.exe` (or `InfiniteFusion.exe`). If loading is slow, try
`InfiniteFusion-performance.exe`.

**macOS / Linux** — not native; runs under Wine/Whiskey
([Wine guide](https://hackmd.io/@PIF-Tech/MacWineGuide) ·
[Whiskey guide](https://hackmd.io/@PIF-Tech/MacWhiskeyGuide)), then launch `Game.exe` through it.
(Upstream's `launch-wine.sh` helper was removed in 6.8.)

**Android** — via [JoiPlay](https://joiplay.net/) ([setup guide](https://hackmd.io/@PIF-Tech/AndroidGuide)).

---

## Administering the save file

Saves live in **`%APPDATA%\infinitefusion\`** as `File A.rxdata` … `File H.rxdata`
(macOS: `~/Library/Application Support/infinitefusion`, Linux: `${XDG_CONFIG_HOME:-~/.config}/infinitefusion`).

### Install the save shipped with this repo

`saves/File A.rxdata` is a real playthrough: a Lv100 party plus competitive benchmark boxes.

```powershell
powershell -ExecutionPolicy Bypass -File saves\install_save.ps1 -List    # inspect your slots first
powershell -ExecutionPolicy Bypass -File saves\install_save.ps1          # install to first FREE slot
powershell -ExecutionPolicy Bypass -File saves\install_save.ps1 -Slot C  # or a specific slot
```

```bash
./saves/install_save.sh --list          # Linux / macOS
./saves/install_save.sh
```

**It cannot silently eat your playthrough.** With no slot given it only ever writes to an *empty*
slot; overwriting an occupied one requires `-Force` / `--force` and backs the existing file up to
`sidmod_save_backups/<timestamp>/` first; it refuses to run while the game is open; and it verifies
the copy by SHA256 before reporting success. Details and box contents: [`saves/README.md`](saves/README.md).

### The save-safety rules

There is no undo on a save file. A corrupted or overwritten save is a lost playthrough.

1. **Back up before anything that can write a save.** The blunt version:
   ```bash
   cp "$APPDATA/infinitefusion/File A.rxdata" ~/somewhere-safe/
   ```
   For mass or destructive edits, copy all 8 slots so you have a hard rollback.
2. **Offline edits go through `apply.ps1`** — never hand-write a save around that gate.
   ```powershell
   powershell -File tools\sidmod_editor\apply.ps1 -Spec spec.json -Slot A -DryRun   # preview + verify
   powershell -File tools\sidmod_editor\apply.ps1 -Spec spec.json -Slot A           # apply
   ```
   It refuses while the game is running, backs up to `sidmod_manual_backups/<stamp>/`, edits a
   *copy*, and only replaces the live file if verification reports no collateral change.
3. **Close the game before any offline write.** An open game overwrites save files on its next save.
4. **In-game writes have no safety net.** The debug menus, the fusion injector and the PC team-swap
   all commit to the live save with no backup and no verification. Copy the slot yourself first, and
   prefer a spare slot or a scratch box the first time you use a save-touching feature.

### Read-only inspection

None of these can modify a save:

```bash
RB=/c/Ruby31-x64/bin/ruby.exe
$RB tools/sidmod_editor/survey_boxes.rb  "$APPDATA/infinitefusion/File A.rxdata"      # all boxes at a glance
$RB tools/sidmod_editor/analyze_team.rb  "$APPDATA/infinitefusion/File A.rxdata" 19   # party + one box, full detail
$RB tools/sidmod_editor/export_box.rb    "$APPDATA/infinitefusion/File A.rxdata" 19 out.txt
```

---

## Repo layout

```
Data/Scripts/055_sidmod/        Smart AI + Random Battle (new code, later folders win on load order)
Data/Scripts/*/                 patches to stock scripts, tagged "# sidmod:"
Data/sidmod/                    fusion injector specs + state
saves/                          the shipped save + its installers
tools/sidmod_editor/            offline save editor, fusion oracle, battle sims, sprite pipeline
sidmod.txt                      the changelog — what changed, why, how to revert
FORK.md                         how this fork tracks upstream
CLAUDE.md                       project rules (save safety, verification, load-order gotchas)
```

Generated and downloaded content is deliberately not committed: custom sprite packs, battle
animations, the installer payload, and the sim's benchmark output. See `.gitignore`.

## Changelog

Every step — mons built, tooling added, research run, tier change — is logged in
**[`UPDATES.md`](UPDATES.md)** with the reasoning and how to reproduce or revert it.
Engine/gameplay patches additionally live in [`sidmod.txt`](sidmod.txt). Recent milestones:

| Date | Step |
|---|---|
| 2026-07-29 | **Move legality audit** — all 456 L100 mons checked against `pbGetLegalMoves`; 62 illegal moves replaced (orientation-aware) |
| 2026-07-29 | Build batches — No Guard Zap Cannon / Dynamic Punch, Simple Quiver Dance, Mimikyu Disguise crew, Rock Head recoil crew |
| 2026-07-30 | Serene Grace Sacred Fire (100% burn) batch + Absol Swords Dance trio |
| 2026-07-30 | **Metagame research** — 6 ladders across ban conditions & tiers → [`META_RESEARCH_REPORT.md`](tools/sidmod_editor/sim/META_RESEARCH_REPORT.md), [`META_FORMATS_DETAIL.md`](tools/sidmod_editor/sim/META_FORMATS_DETAIL.md) |
| 2026-07-30 | In-game **ban-set modes** in Random Battle (play the research conditions) |
| 2026-07-30 | Rebuilds (Alagar, Genark) + Polichomp, Milokazam, Blissey UU trio |
| 2026-07-30 | **Tier system** — explicit per-fusion banlists keyed on the canonical fusion id (`sim/tiers.json`) |

## Contributing

This is a personal fork; changes here are not intended to go upstream. If you want to contribute to
Infinite Fusion itself, work against
[infinitefusion/infinitefusion-e18](https://github.com/infinitefusion/infinitefusion-e18) and read
their contribution rules — upstream only accepts PRs against `develop`, one feature per PR, and
rejects anything touching RPG Maker files outside `Data/Scripts`.

## Links

[Wiki](https://infinitefusion.fandom.com/) · [Discord](https://discord.gg/infinitefusion) ·
[Reddit](https://www.reddit.com/r/PokemonInfiniteFusion/) ·
[Fusion calculator](https://www.fusiondex.org/) · [Showdown](http://play.pokeathlon.com)

---

This is a free-to-play Pokémon fan game. If you paid any amount of money to play it, you have been
scammed. Not affiliated with Nintendo, Game Freak or Creatures Inc. All credit for the base game
goes to the Infinite Fusion team.
