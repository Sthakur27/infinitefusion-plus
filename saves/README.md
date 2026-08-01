# sidmod showcase save

`File A.rxdata` is a real playthrough save for **Pokémon Infinite Fusion + sidmod**, shipped so
anyone cloning this repo can load the same party, the same benchmark boxes, and the competitive
fusion teams the offline toolchain was built against.

## Install

**Windows**

```powershell
powershell -ExecutionPolicy Bypass -File saves\install_save.ps1          # -> first FREE slot
powershell -ExecutionPolicy Bypass -File saves\install_save.ps1 -List    # show your slots first
powershell -ExecutionPolicy Bypass -File saves\install_save.ps1 -Slot C  # a specific slot
```

**Linux / macOS (mkxp-z)**

```bash
./saves/install_save.sh            # -> first FREE slot
./saves/install_save.sh --list
./saves/install_save.sh --slot C
```

Then launch the game and pick that slot.

## It will not eat your playthrough

Both scripts follow the same rules:

| Guard | Behaviour |
|---|---|
| Game open | Refuses to run (exit 2) — an open game overwrites save files on its next save |
| No slot given | Only ever writes to an **empty** slot; if all 8 are full it refuses (exit 3) |
| Slot occupied | Needs `-Force` / `--force` (exit 4 without it) |
| Overwriting | Backs the existing file up to `<savedir>/sidmod_save_backups/<timestamp>/` first |
| After copying | Verifies SHA256 and refuses to report success on a mismatch (exit 5) |

Save folder is `%APPDATA%\infinitefusion` on Windows,
`~/Library/Application Support/infinitefusion` on macOS, else
`${XDG_CONFIG_HOME:-~/.config}/infinitefusion`. Override with `SAVE_DIR=/path` on the shell script.

`sha256: 337ef13569050820802ff1e3aacfe7483a5812fd69b4e9e07b9aba7c7ae8a4fb`

## What's in it

**Party** (all Lv100):

| # | Fusion | Typing | Set |
|---|---|---|---|
| 1 | Registeel/Ninjask | Steel/Flying | Speed Boost @Focus Sash · Swords Dance / Iron Head / Protect / Baton Pass |
| 2 | Porygon-Z/Noivern "Boombox" | Normal/Dragon | Adaptability @Choice Specs · Boomburst / Nasty Plot / Dragon Pulse / Flamethrower |
| 3 | Dragonite/Regigigas "Dragotitan" | Dragon/Normal | Multiscale @Leftovers · Dragon Dance / Extreme Speed / EQ / Ice Punch |
| 4 | Politoed/Alakazam "Downpour" | Water/Psychic | Drizzle @Life Orb · Surf / Thunder / Ice Beam / Psychic |
| 5 | Blissey/Gliscor "Toxtest" | Normal/Flying | Poison Heal @Toxic Orb · Softboiled / Toxic / Stealth Rock / Knock Off |
| 6 | Azumarill/Garchomp "Sharcrunch" | Water/Ground | Huge Power @Leftovers · EQ / Waterfall / Ice Punch / Aqua Jet |

A Baton Pass lead into a rain sweeper and two physical win conditions: Registeel/Ninjask sets up
behind Protect + Focus Sash and passes the boosts, Downpour turns on rain for Thunder, and
Dragotitan / Sharcrunch clean up. Toxtest is the Stealth Rock setter and special sponge.

**Boxes** — 40 boxes. Box 18 onward are the competitive/benchmark boxes: `Rain`, `Sand`, `Bench`,
`OU`, `Sandbox`, `Ubers`, `Sun`, hazard-control and utility sets, plus the `Squads` boxes, a
`Triples` box, a `Laboratory` box and vanilla `UU`/`OU`/`Ubers` reference teams. Boxes 1–17 are the
ordinary collection from the playthrough. Nearly every mon in the competitive boxes is Lv100 with a
held item, which is also what enrolls it in the sidmod **Random Battle** pool.

The save carries its own trainer name and ID, and a lot of hours of progress — treat it as a
showcase/benchmark save rather than a starting point for a fresh run.

## Latest competitive expansion (2026-08-01)

This snapshot adds **30 new Lv100 competitive fusions** and upgrades **2 existing collection
fusions** to complete competitive sets. Highlights include:

- Four Drizzle Water/Flying crosses: Politoed/Kyogre heads with Rayquaza/Lugia bodies.
- Light Ball Pikachu builds, Speed Boost Blaziken builds, and mono-Dragon Haxorus-body sweepers.
- Fire/Dragon Levitate setup attackers, including Latios/Volcarona with Quiver Dance.
- Fast Pixilate Hyper Voice and Serene Grace flinch/status attackers.
- Poison Heal Giratina/Gliscor, Sheer Force Ho-Oh/Feraligatr, and Iron Fist Metagross/Infernape.
- Charizard/Haxorus and Ho-Oh/Flygon promoted from ordinary collection levels to Lv100 builds.

The full generated roster diff, including locations and sets, is in the 2026-08-01 entry of
[`../UPDATES.md`](../UPDATES.md). Future snapshots can be previewed or applied with
`tools/sidmod_editor/sync_showcase_save.ps1`; PC relocations and moveset/item-only tweaks are
deliberately excluded from its generated update report.
