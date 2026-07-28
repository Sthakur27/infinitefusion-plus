#!/usr/bin/env python3
"""Install generated sprites where the game looks for hand-added ones.

Target (Settings::CUSTOM_BATTLERS_FOLDER_INDEXED, BattleSpriteLoader#check_for_local_sprite):
    Graphics/CustomBattlers/local_sprites/indexed/<head>/<head>.<body>.png

check_for_local_sprite runs before the spritesheet and autogen extractors, so a file
here wins. Purely additive: nothing existing is overwritten without a backup, and
deleting an installed file restores the old autogen behaviour exactly.

  python install.py --dry-run
  python install.py
  python install.py --uninstall
"""
import argparse, json, os, shutil, sys, time
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
DEST = os.path.join(ROOT, "Graphics", "CustomBattlers", "local_sprites", "indexed")
OUT = os.path.join(HERE, "out")
MODEL = "gpt-image-2"


def candidates():
    pairs = [f"{r['head']}.{r['body']}" for r in json.load(open(os.path.join(HERE, "missing.json")))]
    found = []
    for p in pairs:
        src = os.path.join(OUT, f"{p}_edit_{MODEL}_0_fit.png")
        if not os.path.exists(src):   # fall back to any fitted variant
            alts = [f for f in os.listdir(OUT) if f.startswith(p + "_") and f.endswith("_fit.png")]
            src = os.path.join(OUT, sorted(alts)[0]) if alts else None
        found.append((p, src))
    return found


def verify(path):
    """Must match what the engine expects of a custom battler."""
    im = Image.open(path)
    problems = []
    if im.size != (288, 288):
        problems.append(f"size {im.size} != (288,288)")
    if im.mode != "P":
        problems.append(f"mode {im.mode} != P (indexed)")
    if "transparency" not in im.info:
        problems.append("no tRNS transparency")
    n = len({p for p in im.convert("RGBA").getdata() if p[3]})
    if not (4 <= n <= 40):
        problems.append(f"{n} colours outside sane range")
    if not im.convert("RGBA").getbbox():
        problems.append("fully transparent")
    return problems, n


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--uninstall", action="store_true",
                    help="remove installed sprites; pass pairs to remove only those")
    ap.add_argument("pairs", nargs="*", help="head.body pairs to act on (default: all)")
    a = ap.parse_args()

    if a.uninstall:
        removed = 0
        targets = [(p, s) for p, s in candidates() if not a.pairs or p in a.pairs]
        for p, _ in targets:
            head, body = p.split(".")
            f = os.path.join(DEST, head, f"{head}.{body}.png")
            if os.path.exists(f):
                os.remove(f)
                removed += 1
                print(f"  removed {f}")
        print(f"\n{removed} removed — game reverts to autogen for those fusions.")
        return

    stamp = time.strftime("%Y%m%d_%H%M%S")
    backup = os.path.join(HERE, "backup", stamp)
    installed = skipped = 0
    for p, src in candidates():
        head, body = p.split(".")
        dst = os.path.join(DEST, head, f"{head}.{body}.png")
        if src is None:
            print(f"  {p:<9} SKIP   no generated sprite yet")
            skipped += 1
            continue
        problems, n = verify(src)
        if problems:
            print(f"  {p:<9} SKIP   fails spec: {'; '.join(problems)}")
            skipped += 1
            continue
        if a.dry_run:
            print(f"  {p:<9} would install ({n} colours) -> {os.path.relpath(dst, ROOT)}")
            installed += 1
            continue
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        if os.path.exists(dst):                       # never clobber silently
            os.makedirs(os.path.join(backup, head), exist_ok=True)
            shutil.copy2(dst, os.path.join(backup, head, os.path.basename(dst)))
            print(f"  {p:<9} (backed up existing -> backup/{stamp}/)")
        shutil.copy2(src, dst)
        print(f"  {p:<9} installed ({n} colours) -> {os.path.relpath(dst, ROOT)}")
        installed += 1

    verb = "would install" if a.dry_run else "installed"
    print(f"\n{verb} {installed}, skipped {skipped}")
    if not a.dry_run and installed:
        print("Restart the game to pick them up (scripts/graphics are read at boot).")


if __name__ == "__main__":
    main()
