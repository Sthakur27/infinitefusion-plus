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

`sha256: 69066bd6eec2918bf4bd0f0df9c2a34c40538423f4a11a5eb6f468d31a941d9c`

## What's in it

**Party** (all Lv100):

| Fusion | Typing | Set |
|---|---|---|
| Registeel/Blaziken "Steelzerker" | Steel/Fighting | Speed Boost @Wide Lens · SD / Hi Jump Kick / Protect / Baton Pass |
| Azumarill/Garchomp "Sharcrunch" | Water/Ground | Huge Power @Leftovers · EQ / Waterfall / Ice Punch / Aqua Jet |
| Porygon-Z/Noivern "Boombox" | Normal/Dragon | Adaptability @Choice Specs · Boomburst / Nasty Plot / Dragon Pulse / Flamethrower |
| Dragonite/Regigigas "Dragotitan" | Dragon/Normal | Multiscale @Leftovers · Dragon Dance / Extreme Speed / EQ / Ice Punch |
| Jolteon/Nidoking "09balanc" | Electric/Ground | Sheer Force @Life Orb · Earth Power / Thunderbolt / Flamethrower / Volt Switch |
| Blissey/Gliscor "Toxtest" | Normal/Flying | Poison Heal @Toxic Orb · Softboiled / Toxic / Stealth Rock / Knock Off |

**Boxes** — box 18 onward are the competitive/benchmark boxes: `Rain`, `Sand`, `Bench`, `OU`,
`Ubers`, `Sun`, hazard-control and utility sets, plus the `Squads` boxes and vanilla `UU`/`OU`/`Ubers`
reference teams. Boxes 1–17 are the ordinary collection from the playthrough. Nearly every mon in
the competitive boxes is Lv100 with a held item, which is also what enrolls it in the sidmod
**Random Battle** pool.

The save carries its own trainer name and ID, and a lot of hours of progress — treat it as a
showcase/benchmark save rather than a starting point for a fresh run.
