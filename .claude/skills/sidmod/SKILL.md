---
name: sidmod
description: >-
  Use when making, planning, reverting, or documenting any gameplay/QoL/debug
  mod to this Pokémon Infinite Fusion install (the "sid mod"). Covers the project's
  modding conventions and the sidmod.txt changelog. Trigger on requests like "add
  X to the mod", "tweak/patch <battle|PC|debug|exp|trainer> behavior", "log this to
  sid mod", "what have we modded", or "revert the <feature> change".
---

# sidmod

This is a personal mod ("sid mod") layered on top of Pokémon Infinite Fusion
(Ruby, Pokémon Essentials + Reborn battle engine). Every change is a small,
surgical patch to the stock scripts, and **every change is logged in
`sidmod.txt`** at the repo root. That file is the source of truth for what has
been modded and why.

## Always do this first

**Read `sidmod.txt` (repo root) before making or discussing any mod.** It lists
every existing patch with file, method/line, and rationale. Use it to:
- avoid re-patching something already done,
- reuse an established pattern (the conventions below come straight from it),
- find the exact spot/old value when reverting.

## Project layout (where things live)

Scripts are under `Data/Scripts/` in numbered folders (load order matters —
later folders/files override earlier ones):
- `001_Settings.rb` — global constants/tunables (e.g. `HARD_MODE_LEVEL_MODIFIER`).
- `003_Game processing/`, `004_Game classes/` — startup, player, save flow.
- `011_Battle/` — battle engine. `001_Battler/`, `003_Battle/`, `004_AI/`.
- `012_Overworld/` — field moves, battle triggering.
- `016_UI/` — stock UI (PC storage, summary, etc.).
- `020_Debug/` — debug menus (`002_Debug_MenuCommands.rb`, `005_Debug_PokemonCommands.rb`).
- `052_InfiniteFusion/` — IF-specific systems (fusions, quests, PC features, menus, items).
- `053_PIF_Hoenn/` — Hoenn region content (trainer rematches, etc.).
- `999_Main/999_Main.rb` — entry point; `$DEBUG = true` is forced on here.

Gotcha: IF often **overrides** stock methods with its own copy, so one behavior
can need two patches — see "IF overrides stock methods" in `CLAUDE.md`.

## Patch style (match the existing code)

- Prefer the **smallest reversible edit**: an early `return`/`return false`, a
  `if false` guard, prepending `false &&` to a condition, or commenting out lines
  (leave the originals commented for easy revert). Examples already in-tree:
  `pbUnfuse` (`if false`), `pbObedienceCheck?` (`false &&`), `pbEnemyShouldUseItem?`
  (`return false`).
- Tag mod edits with a `# sidmod:` comment when the intent isn't obvious.
- Tunables go in `001_Settings.rb` as constants; reference them at call sites.
- **Debug/cheat hotkeys use `Input::ACTION` (= Xbox X button)** held while doing
  the action (noclip, instant capture, guaranteed catch, hold-to-refight). Do NOT
  use `Input::BACK` (overlaps the menu button) or `Input::CTRL`.
- New debug menu commands mirror the `DebugMenuCommands.register(...)` /
  `PokemonDebugMenuCommands.register(...)` blocks (see `setmoney` / `setbp` for the
  currency-setter pattern; no `MAX_QUEST_POINTS` constant exists — use `9_999`).
- A mod that writes to a save (debug commands, PC/party features, injectors) gets
  no automatic backup — follow the save-safety rule in `CLAUDE.md` before any
  in-game test of one.

## Logging to sidmod.txt (do this after every change)

Append a block at the end of `sidmod.txt`, **before** the trailing
`# old commented-out reference impl` appendix. Match the existing format exactly:

```
##############################################
<short title - lowercase, "what it does - why/end goal">
<file path relative from Data/Scripts>
  <Method#name ~line N>: <what changed (old -> new)>
  <extra bullets for related edits>
  <notes: side effects, caveats, how to revert, conditional variants>
```

Conventions seen throughout the file:
- Title line is terse and lowercase; include the "end goal" when relevant.
- Cite the **method name and approximate line** (`~line N`), not just the file.
- State the old value/behavior alongside the new one.
- Always note how to **revert** and any **caveats/side effects**.
- Keep multi-file changes in one block, listing each file + hook.

After writing code + logging, briefly tell the user what changed and offer to
verify in-game (the `/run` or `verify` skills launch the actual game). If the mod
can write to a save, back the slot up before that test and say where the backup
went — loading the game commits the change with no undo.

## Reverting

`sidmod.txt` records the original value and revert steps for each patch. To undo
a mod, find its block, restore the cited old value at the cited method/line, and
remove (or annotate) the block in `sidmod.txt`.
