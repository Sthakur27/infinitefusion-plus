# Offline Fusion Save Editor — Design Doc

**Status:** planning → build
**Author:** Sid + Claude
**Date:** 2026-07-17
**Goal:** A fully offline pipeline. Claude reads Sid's save directly, Sid describes
Pokémon/fusions in chat, Claude builds them and writes them back into the save —
no in-game export/import round-trips. Sid just launches the game and sees the results.

---

## 1. What we're replacing

The first version (already built, kept as fallback) works *inside* the game:
- `020_Debug/003_Debug menus/007_sidmod_FusionInjector.rb` — reads `injections.json`, drops mons in the PC.
- `020_Debug/003_Debug menus/008_sidmod_PCExport.rb` — dumps party+boxes to `pc_dump.json`.

That flow forces Sid to: launch → export → tell Claude → Claude edits → import in-game.
Cumbersome. **This doc designs the offline replacement.** The in-game tools stay as a
belt-and-suspenders fallback but aren't part of the normal loop.

---

## 2. The core problem & the solution

The save (`%AppData%/Roaming/infinitefusion/File B.rxdata`) is a Ruby **`Marshal.dump`**
of a `Hash{Symbol => Object}` (verified: header `04 08 7B` = Marshal 4.8, top-level Hash).
Only Ruby round-trips that format faithfully — a third-party Python parser (`rubymarshal`)
was tested and **fails** on shared object-links. So:

**Decision: use real Ruby (3.1, matching the game's bundled `ruby310.dll`) for all
read/write of the save.** Installed via `winget install RubyInstallerTeam.Ruby.3.1`.

We do **not** load the game engine (too many RGSS/graphics deps). Instead we use the
classic save-editor technique: **stub classes**. `Marshal.load` populates instance
variables without calling `initialize`, so an empty `class Pokemon; end` is enough to
read/mutate ivars, and `Marshal.dump` re-emits a stream the real game loads correctly
(matched by class name; ivars set directly, no `initialize`).

---

## 3. Verified engine internals (the facts this design relies on)

Sources are real files under `Data/Scripts/`.

### 3.1 Save layout
`002_Save data/004_Game_SaveValues.rb` — `SaveData.register` keys. The two that matter:
- `:player` → a `Player` object; **the party is `Player#@party`** (a `Pokemon[]`). No separate party key.
- `:storage_system` → a `PokemonStorage`; boxes are `@boxes` (Array of `PokemonBox`, each `@pokemon` is a 30-slot Array with `nil` gaps). 40 boxes × 30 slots.
- `ensure_class` is validated on **load** (`002_SaveData_Value.rb`): the object under `:player` must marshal back as `Player`, `:storage_system` as `PokemonStorage`. Stub classes preserve the class name, so this passes.

### 3.2 Stats are NOT recomputed on load (critical)
Load path (`SaveData.read_from_file` → `load_all_values` → `Value#load` → `$Trainer = value` / `$PokemonStorage = value`) does **no** `calc_stats`. `onLoadExistingGame` (`052.../MultiSaves.rb`) doesn't touch party/boxes either.
→ **We must compute derived stats ourselves** so the party/PC screens show correct
numbers. (The engine only recomputes on entering battle, level-up, evolution, item use, etc.)

Formulas (`014_Pokemon/001_Pokemon.rb`):
```
HP    = floor((2*base + iv + floor(ev/4)) * level/100) + level + 10     (base==1 → 1, Shedinja)
stat  = floor( (floor((2*base + iv + floor(ev/4)) * level/100) + 5) * nature/100 )
```
`nature` mult = 110 / 100 / 90 per the nature's up/down stat.

### 3.3 `@species` is authoritative; `@species_data` is re-fetched
`Pokemon#species_data` always re-fetches `GameData::Species.get(@species)` at runtime.
→ For a fusion we only need `@species = :"B{bodyDex}H{headDex}"` correct. `@species_data`
can be left as the cloned template's value or nil (ignored at runtime). *(verify: exact
memoization in `species_data` — set to nil to force clean re-fetch if unsure.)*

### 3.4 Level ← exp
`@level` is a cache; `@exp` is authoritative. Set `@exp = minimum_exp_for_level(level)`
and either set `@level` to match or nil (lazily re-derived). Growth-rate curve comes from
the species (for a fusion, priority pick over head/body growth rates).

### 3.5 Fusion derivation (`052.../Fusion/FusedSpecies.rb`)
- Fused dex/symbol: `bodyDex * NB_POKEMON(501) + headDex`; symbol `:B{body}H{head}`.
- Base stats, `calculate_fused_stats(dominant, other) = (2*dominant)/3 + floor(other/3)`:
  - **Head-dominant:** HP, SPECIAL_ATTACK, SPECIAL_DEFENSE
  - **Body-dominant:** ATTACK, DEFENSE, SPEED
- Type1 = head.type1 (Normal/Flying → Flying); Type2 = body.type2 (dedup vs type1).
- Abilities (normal) = `[body.ability0, head.ability0]`.
- growth_rate = priority `[:Fast,:Medium,:Parabolic,:Fluctuating,:Erratic,:Slow]`.

### 3.6 Object shapes
- `Pokemon::Move`: `@id` (Symbol), `@pp` (Int), `@ppup` (Int 0–3). `pp = max_pp + max_pp*ppup/5`.
- `Pokemon::Owner`: `@id` (Int, 32-bit), `@name` (String), `@gender` (Int 0/1/2), `@language` (Int). All type-validated by setters — must be right types.
- Full `Pokemon` ivar inventory captured (species, form, exp/level, iv, ev, ability(_index), nature, item, moves, personalID, owner, poke_ball, obtain_*, timeReceived, happiness, shiny, gender, hp, totalhp, attack/defense/spatk/spdef/speed, size_category, sprite_scale, fusion exp fields, …).

### 3.7 Base data source (offline)
Base-species stats/types/abilities/growth-rate live in **`Data/species.dat`** (compiled
Marshal; 466 KB). Read it with the same stub-class technique → build a `dex → {base_stats,
types, abilities, growth_rate, name, gender_ratio}` table. No PBS `pokemon.txt` exists;
no in-game export needed. Move/ability/item **name→symbol** validation uses `PBS/moves.txt`,
`PBS/abilities.txt`, `PBS/items.txt` (plain text) or the corresponding `.dat`.

---

## 4. Architecture

```
chat (Sid describes mons)
      │
      ▼
Claude builds spec JSON  ──►  tools/sidmod_editor/spec.json
      │
      ▼                         (all Ruby, offline, on a COPY of the save)
ruby edit_save.rb  ──►  loads species.dat table + save copy
      │                 clones a template Pokemon, mutates fields,
      │                 computes derived stats, inserts into party/box,
      │                 runs validations, Marshal.dumps → save.new
      ▼
validate + backup  ──►  timestamped backup of File B, then atomic replace
      │
      ▼
Sid launches game → sees the new mons. (game MUST be closed during write)
```

### Components (proposed, under `C:\Games\InfiniteFusion\tools\sidmod_editor\`)
1. **`stubs.rb`** — empty stub classes/modules: `Player`, `PokemonStorage`, `PokemonBox`,
   `Pokemon`, `Pokemon::Move`, `Pokemon::Owner`, `GameData`, `GameData::Species`, etc.
   Loaded by both read and write scripts.
2. **`build_species_table.rb`** — one-time: Marshal.load `Data/species.dat` → emit
   `species_table.json` (dex → base stats/types/abilities/growth/name). Re-run if the game updates.
3. **`read_save.rb <savefile> > dump.json`** — Marshal.load a **copy**, walk party + boxes,
   emit structured JSON (species, fused head/body, level, nature, ability, item, moves, IVs,
   EVs, shiny, gender, per-box occupancy). Claude reads this to "see" the PC. **Read-only.**
4. **`edit_save.rb <savefile> <spec.json> <outfile>`** — the writer (see §5).
5. **`apply.ps1`** — orchestration: verify game not running, backup File B, run edit, run a
   post-write re-read validation, atomic-replace File B (or write to a chosen slot).

Claude drives 3–5 directly (no in-game steps). Sid only launches the game afterward.

---

## 5. The writer (`edit_save.rb`) algorithm

1. Load `species_table.json` + stub classes. `Marshal.load` the save copy → `save` Hash.
2. Pick a **template** Pokémon: the first real mon in `save[:player].@party` (guaranteed
   game-valid ivar graph). Deep-copy it via `Marshal.load(Marshal.dump(template))` per new mon.
3. For each entry in the spec, mutate the clone:
   - `@species = :"B{bodyDex}H{headDex}"` (or a base species symbol for non-fusions); `@species_data = nil`.
   - `@exp = minimum_exp_for_level(level)` (growth curve from table); `@level = level`.
   - `@iv = {…}`, `@ev = {…}` (defaults filled by Claude), `@ivMaxed = {}`.
   - `@nature` (Symbol), `@ability` (Symbol, forced), `@ability_index` as needed.
   - `@item` (Symbol/nil), `@poke_ball` (Symbol).
   - `@moves = [Move(@id,@pp,@ppup) …]` (≤4); `@first_moves` set for relearner.
   - `@name` (nickname or nil), `@shiny` (bool), `@gender` (0/1/2), fresh `@personalID`.
   - `@owner = Owner(trainer.id, name, gender, language)` from `save[:player]`.
   - `@obtain_method/@obtain_level/@timeReceived/@happiness` sane values.
   - **Compute derived stats** from fused base stats (2:1 formula) + level/IV/EV/nature →
     set `@hp,@totalhp,@attack,@defense,@spatk,@spdef,@speed`. `@hp = @totalhp` (full).
4. Insert: into `save[:storage_system].@boxes[boxIdx].@pokemon` first free slot (or party).
5. **Validate** (see §6). If any check fails → abort, write nothing.
6. `Marshal.dump(save, out)`.

---

## 6. Validation & safety ("check and place so values are correct")

**Before write:**
- Every species/move/ability/item/nature/ball token resolves to a known symbol (else abort with a clear error Claude reads).
- IVs 0–31, EVs 0–252 & sum ≤ 510, level 1–100, ≤4 moves.
- Target box index in range and slot free (no overwrite).

**After write (self-check):** re-run `read_save.rb` on the *output* and assert:
- Top-level `:player` is `Player`, `:storage_system` is `PokemonStorage` (class names intact).
- Party/box counts = expected (old + inserted).
- Each new mon: `@totalhp > 0`, all stats > 0, `@species` resolves, level matches exp.
- File size sane (not truncated/zero).
Only if all pass does `apply.ps1` replace File B.

**Backups:**
- Never edit File B in place — operate on a copy, atomic-replace at the end.
- Timestamped backup before every replace (dir already seeded:
  `%AppData%/infinitefusion/sidmod_manual_backups/`). The game's own `backups/File B/` also exists.
- **Refuse to write if the game is running** (check process) — it would overwrite on next save.
- Sid tests on **File B** only.

---

## 7. Risks & open items to verify during build

| Risk | Mitigation |
|---|---|
| Stub-class Marshal round-trip drops an ivar or mis-handles a nested `GameData::*` / `Symbol` link | Round-trip test: read File B copy → dump → diff bytes / re-read; confirm identical before any edit |
| `species_data` memoization keeps stale data | Set `@species_data = nil`; verify `species_data` method re-fetches (Pokemon.rb:208) |
| Derived-stat mismatch vs engine | Unit-check our `calcHP/calcStat` against a known existing mon read from the save |
| Fusion has extra ivars we don't set | Template-clone inherits them; prefer cloning an existing **fusion** as template when available |
| `species.dat` records need more stub structure than expected | Inspect one record's ivars after load; adjust stubs |
| Nature stat-mult / growth-curve edge cases | Pull nature table from `PBS/natures*.txt` or hardcode the 25 standard natures + 6 growth curves |
| Save-format version drift after a game update | `build_species_table.rb` re-runnable; version key `:essentials_version` checked on read |

**Go/no-go gate (Phase 1):** the byte-identical round-trip test. If a plain read→dump of a
File B copy doesn't reload cleanly in-game, we stop and reassess before writing anything real.

---

## 8. Build phases

- **Phase 0 — Ruby install.** `winget install RubyInstallerTeam.Ruby.3.1`. *(in progress)*
- **Phase 1 — Read + round-trip proof.** `stubs.rb`, `read_save.rb`, `build_species_table.rb`.
  Prove: read File B copy → structured JSON (Claude can see party/boxes) **and** read→dump→reload
  is faithful. **Go/no-go.**
- **Phase 2 — Writer.** `edit_save.rb` + spec schema + stat computation. Test: inject one simple
  non-fusion into an empty box on a File B copy, load in-game, confirm correct.
- **Phase 3 — Fusions + full spec.** head/body, forced ability, moves, EV/IV/nature, item, shiny,
  nickname, box targeting, current-working-box memory.
- **Phase 4 — Orchestration + polish.** `apply.ps1` (game-running check, backup, validate, replace),
  batch injection, clear chat UX ("here's your PC / done, launch and check box 5").

---

## 9. Spec schema (chat → JSON), unchanged from the in-game tool

```json
{
  "default_box": 5,
  "pokemon": [{
    "head": "BLISSEY", "body": "GLISCOR", "level": 100, "nickname": "Tox",
    "ability": "POISONHEAL", "nature": "CAREFUL", "item": "TOXICORB",
    "moves": ["EARTHQUAKE","TOXIC","PROTECT","SOFTBOILED"],
    "evs": {"HP":252,"SPECIAL_DEFENSE":252,"DEFENSE":6},
    "ivs": {"HP":31,"ATTACK":31,"DEFENSE":31,"SPECIAL_ATTACK":31,"SPECIAL_DEFENSE":31,"SPEED":31},
    "shiny": false, "gender": "male", "ball": "ULTRABALL", "box": 5
  }]
}
```
Convention (locked): `"A B"` in chat → **head A, body B**. IDs have no underscores
(`:POISONHEAL`, `:TOXICORB`); stats keep underscores (`:SPECIAL_ATTACK`).

---

## 10. STATUS: BUILT & OFFLINE-VALIDATED (2026-07-17)

All phases built under `C:\Games\InfiniteFusion\tools\sidmod_editor\` (Ruby 3.1.7 at
`C:\Ruby31-x64\bin\ruby.exe`). Proven on a live File B copy:
- Round-trip: `deep_eq.rb` = every value/ivar identical; re-dump is a stable fixed point.
- Math: `validate_logic.rb` = **stats 697/701 exact** (4 misses = Wonder-Guard HP=1, now
  replicated); all level "mismatches" are legacy save inconsistencies (each explained by a
  component growth curve, none unexplained).
- Writer: `edit_save.rb` created a fusion + a non-fusion; `verify_edit.rb` = **collateral
  problems: NONE** (only the new slots changed); hand-checked Garchomp stats exact.
- Orchestration: `apply.ps1` dry-run = clean (backup, edit, verify gate, dry stop).

### Files
- `stub_loader.rb` - faithful stub-class Marshal load (userdef raw-passthrough).
- `build_species_table.rb` -> `species_table.json` (base stats/types/abilities/growth).
- `build_moves_table.rb` -> `moves_table.json` (move -> PP).
- `pokemath.rb` - growth tables, fusion stat/type/growth, natures, calcHP/calcStat.
- `read_save.rb` - party+boxes dump (stdout summary + `pc_dump.json`).
- `edit_save.rb` - the writer (spec -> save).
- `verify_edit.rb` - collateral-damage check + added-mon dump.
- `apply.ps1` - orchestration (game-guard, backup, edit, verify, atomic replace).
- `editor_state.json` - persistent current working box.

### Usage (Claude-driven, fully offline)
1. Read PC:  `ruby read_save.rb "<AppData>\infinitefusion\File B.rxdata"`
2. Write a spec JSON (schema in section 9) from Sid's chat description.
3. Dry run:  `powershell apply.ps1 -Spec spec.json -Slot B -DryRun`
4. Apply:    `powershell apply.ps1 -Spec spec.json -Slot B`   (game MUST be closed)
5. Sid launches the game and sees the mons.

### Only-remaining check
In-game load of an edited save (stats/sprites/no-crash) - the one thing not testable offline.
