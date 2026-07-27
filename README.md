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

### Battle

| Feature | What it does |
|---|---|
| **Random Battle** | Pause menu → fight a 6-mon team assembled from your own **Lv100 + held-item** PC pool. Four modes: `{Chaos, Smart} × {OU, Ubers}`. Chaos is Species-Clause-legal random; Smart greedily seeds a hazard-setter, a wall and a pivot, then fills for offensive and typing variety. OU filters legendaries except the sub-600 birds/beasts/golems. |
| **Items are refunded** | A practice battle shouldn't cost you a Life Orb. Consumed held items and bag stock are restored afterwards — for both sides. |
| **Smart Trainer AI** | A plan-based enemy AI (`055_sidmod/SmartTrainerAI.rb`) that compares attacking, setup, status, healing, phazing and switching as competing plans, with a beam search over an abstract state and an expected-damage model. |
| **No item cheese** | Enemy trainers never use Full Restore / potions / X items mid-battle. |
| **Hard mode, retuned** | Level scaling is a flat multiplier instead of vanilla's 1.6×, and hard mode shows you the incoming Pokémon. |
| **More max PP** | Higher PP ceiling, and moves taught via debug arrive at full PP. |

**On the AI, honestly:** it is measured as *exactly as strong as* the stock Essentials AI it
replaces — 0.500 over 1440 games on identical teams and seeds. The v2/v3 work fixed a real
regression (the original suppression multipliers were ~37–41 ELO *worse* than vanilla) and no more.
Deeper search, switch prediction and team-level planning were all implemented, measured, and
reverted. `sidmod.txt` records what was tried so it isn't redone blindly. It plays *visibly* better
(it heals, statuses and phazes instead of mashing attacks) without being stronger on the scoreboard.

### PC & storage

- **PC search** — live-filter picker; type in a name or use `h:` / `b:` to search by fusion head or body, and jump straight to the slot.
- **Team swap** — exchange your whole party with a box row in one action. Sand team out, rain team in.
- **Live wallpaper preview** — the box redraws as you scroll the wallpaper list; backing out restores the one you started with.
- **Free wallpaper lottery** — no Quest Point cost.
- **Multi-select fixes** — bulk carries respect bounds, dropping onto an occupied slot swaps, and you can change box while holding.

### Quality of life

Turbo on by default · straight to save-select (no title screen or startup popups) · windowed start ·
teleport/Fly anywhere · noclip and instant capture (hold `Input::ACTION`, Xbox **X**) ·
hold-`ACTION`-to-refight any beaten trainer · gym leader rematches always available · traded fusions
can be unfused · foreign Pokémon always obey · New Game+ keeps your levels instead of reverting to
Lv5 babies · type-expert challenges accept any Pokémon · difficulty and game mode switchable
**mid-save**.

### Creator & debug tools

- **Fusion injector** — describe a fusion in chat, get a JSON spec, drop it into the PC from a debug command.
- **PC export** — read-only dump of party + every box, so an assistant can actually see your PC.
- **Searchable everything** — species, moves, items, switches/variables and trainers were all flat lists ordered by internal ID. All are now searchable by name.
- **Benchmark opponents** — vanilla Gen-5 OU and Ubers teams as debug battle opponents, with the party full-healed before and after each test fight.

### Offline toolchain (`tools/sidmod_editor/`)

| Tool | Purpose |
|---|---|
| `apply.ps1` → `edit_save.rb` → `verify_edit.rb` | Build or edit Pokémon in a save file. Refuses to run while the game is open, backs the slot up, and **rejects any write that doesn't verify as "collateral problems: NONE"** — only the slots you targeted may differ. |
| `sim/fusion_inspector.rb` | The ground-truth oracle. Builds a candidate in the real engine and reports actual typing, stats vs both parents, 4×/2×/immune matchups, resolved ability, and auto-flags (stat tax, new 4× weakness, dead ability). |
| `sim/prun.rb` | Parallel LLM-piloted battles for A/B testing team changes. |
| `sim/nbattle.rb` + `nsearch2` / `ntourney` / `nladder` | The deterministic SmartAI plays both sides — no API calls, ~100 games/sec. Rates every mon in your PC, hill-climbs teams against a held-out field, and runs Elo ladders. |
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
