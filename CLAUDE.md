# Infinite Fusion — sid mod

Pokémon Infinite Fusion (RPG Maker XP / mkxp-z, Ruby 3.1, Pokémon Essentials + Reborn battle
engine) with a personal mod layered on top. Game root `C:\Games\InfiniteFusion`, work branch
`sidmod`. Game scripts live in `Data/Scripts/` (numbered folders, later folders win on load
order); the offline toolchain lives in `tools/sidmod_editor/`.

## Save safety (hard rule)

Saves are `%APPDATA%\infinitefusion\File A.rxdata` … `H`. **The active playthrough is File A.**
There is no undo — a corrupted or overwritten save is a lost playthrough.

- **Back up before anything that can write a save**, and say in your report which backup you took
  and where.
- **Offline edits go through `tools\sidmod_editor\apply.ps1`.** It refuses to run while the game
  is open, backs File A up to `%APPDATA%\infinitefusion\sidmod_manual_backups\<stamp>\`, and
  rejects the write unless `verify_edit.rb` reports "collateral problems: NONE". Don't hand-write
  a save around that gate. Dry-run first (`-DryRun`).
- **In-game writes have no safety net.** The debug menus, the fusion injector, the PC team-swap,
  and any "just load it and try" test all commit to the live save the next time the game saves,
  with no backup and no verify step. Copy the slot yourself first:
  `cp "$APPDATA/infinitefusion/File A.rxdata" <dest>/`
- **Mass or destructive edits** (many slots, a whole box, anything that deletes or overwrites in
  bulk): copy all 8 slots for a hard rollback, not just the per-write backup.
- Prefer a scratch box / spare slot for the first run of any new save-touching feature.

## Verify before reporting done

- Ruby changes: `ruby -c <file>` at minimum. Nothing in `Data/Scripts/` is loaded until the game
  boots, so a syntax error ships silently — check every file you touched.
- Logic worth testing can usually be run head-less: stub the engine objects and `load` the real
  file (see `tools/sidmod_editor/` and the `sim/` harness). Say plainly what you tested and what
  you didn't — "syntax-checked, not exercised in-game" is a useful thing to report.

## Gotcha: IF overrides stock methods

Infinite Fusion frequently redefines an Essentials method in its own `052_InfiniteFusion/` copy,
which wins on load order. The classic case is `pbBoxCommands`, defined in **both**
`016_UI/PokemonStorage/PokemonStorageScreen.rb` and
`052_InfiniteFusion/Menus/PC/Multiselect/MultiSelect_PokemonStorageScreen.rb` — patch both. If a
change appears to do nothing, grep for a second definition before assuming the edit was wrong.

## Mod work

For any gameplay/QoL/debug mod: load the **`sidmod` skill** and read **`sidmod.txt`** (repo root)
first. `sidmod.txt` is the source of truth for what has been modded, why, and how to revert it;
every change gets a block appended there. The skill carries the patch conventions (smallest
reversible edit, `# sidmod:` tags, hotkeys on `Input::ACTION`, changelog format).

`tools/sidmod_editor/RUNBOOK.md` is the equivalent for the offline toolchain (save editing,
fusion inspection, headless battle sim).
