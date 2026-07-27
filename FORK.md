# This is a fork — how it relates to upstream

This repo is a fork of **[infinitefusion/infinitefusion-e18](https://github.com/infinitefusion/infinitefusion-e18)**
(Pokémon Infinite Fusion) carrying the **sidmod** layer on top: gameplay/QoL/debug mods under
`Data/Scripts/055_sidmod/` plus patches to stock scripts, an offline toolchain in
`tools/sidmod_editor/`, and a showcase save in `saves/`.

- `sidmod` — the working branch. All mod work lives here.
- `main` — kept in sync with upstream so diffs stay readable.

Read `sidmod.txt` for what has been modded and why, `CLAUDE.md` for the project rules, and
`tools/sidmod_editor/RUNBOOK.md` for the save-editing / battle-sim toolchain.

## Remotes

| Remote | Points at | Use |
|---|---|---|
| `origin` | your fork | push your work |
| `upstream` | `infinitefusion/infinitefusion-e18` | pull new game releases |

One-time setup on a fresh clone of the fork:

```bash
git remote add upstream https://github.com/infinitefusion/infinitefusion-e18.git
git fetch upstream
```

## Pulling a new upstream release

**Upstream's live release line is `releases`, not `main`.** `main` has not moved since
April 2024, while `releases` carries 6.7.x and later. Always merge from `releases`:

```bash
git fetch upstream
git log --oneline sidmod..upstream/releases      # see what's new first
git switch sidmod
git merge upstream/releases                      # or: git rebase upstream/releases
```

Conflicts land almost entirely in the stock scripts sidmod patches. When one appears, check
`sidmod.txt` for what that patch was for — the `# sidmod:` tags in the source mark the edits, so
take upstream's version of the surrounding code and re-apply the tagged lines.

Because Infinite Fusion frequently redefines an Essentials method in its own `052_InfiniteFusion/`
copy (which wins on load order), a merged-clean patch can still do nothing. If a mod stops working
after an upstream merge, grep for a second definition of the method before assuming the merge ate
your change — see the gotcha in `CLAUDE.md`.

After any merge, syntax-check everything you touched; nothing in `Data/Scripts/` is parsed until the
game boots, so a syntax error ships silently:

```bash
ruby -c "path/to/file.rb"
```

## Six files that must never be committed

These are tracked upstream but rewritten constantly by simply *playing* the game — sprite
downloads and the boot-time dex regeneration. `.gitignore` cannot help (gitignore does not apply to
already-tracked files), so **stage explicit paths and never `git add -A`**:

```
Data/pokedex/dex.json                    (+264k lines of churn, 18MB)
Data/sprites/Sprite_Credits.csv          (+236k lines of churn)
Data/sprites/CUSTOM_SPRITES
Data/sprites/BASE_SPRITES
Data/sprites/updated_spritesheets_cache
Data/sprites/sprites_rate_limit.log
```

Check before every commit:

```bash
git status --porcelain -- Data/pokedex Data/sprites
```

Everything else generated *is* gitignored: downloaded sprite packs
(`Graphics/Battlers/<numeric>/`, 7-digit `FusionIcons`), `Animations/`, the installer payload, the
sim's `nreports/`/`reports/` output (~190MB, and it contains save snapshots of a live playthrough),
`*.apikey`, and `errorlog.txt`.

## Save safety

The offline toolchain writes to real save files. `tools/sidmod_editor/apply.ps1` refuses to run
while the game is open, backs up the target slot, and rejects any write whose verification is not
"collateral problems: NONE". Don't hand-write a save around that gate — and note that **in-game**
writes (debug menus, the fusion injector, the PC team-swap) have no such net. Full rules in
`CLAUDE.md`.

`saves/install_save.ps1` / `.sh` install the shipped save without clobbering an existing slot; see
`saves/README.md`.
