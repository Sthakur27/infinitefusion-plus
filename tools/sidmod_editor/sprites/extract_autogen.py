#!/usr/bin/env python3
"""Extract the game's autogen sprite for a head.body fusion.

Mirrors AutogenExtracter.rb: sheet = spritesheets_autogen/<head>.png, 96px cells,
10 columns, cell index = body_id (row = id // 10, col = id % 10).

This is both the baseline any generated sprite has to beat and the conditioning
image for an images.edit pass.

  python extract_autogen.py 347.349 [more...] --out autogen/
  python extract_autogen.py --all-missing --out autogen/     # the 13 from missing.json
"""
import argparse, json, os, sys
from PIL import Image

SHEET_DIR = "Graphics/Battlers/spritesheets_autogen"
CELL, COLS = 96, 10


def extract(head, body):
    sheet_path = os.path.join(SHEET_DIR, f"{head}.png")
    if not os.path.exists(sheet_path):
        return None, f"no sheet {sheet_path}"
    sheet = Image.open(sheet_path).convert("RGBA")
    row, col = body // COLS, body % COLS
    x, y = col * CELL, row * CELL
    if x + CELL > sheet.width or y + CELL > sheet.height:
        return None, f"cell ({col},{row}) outside {sheet.width}x{sheet.height}"
    cell = sheet.crop((x, y, x + CELL, y + CELL))
    if not cell.getbbox():
        return None, "cell is empty"
    return cell, None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("pairs", nargs="*", help="head.body, e.g. 347.349")
    ap.add_argument("--all-missing", action="store_true", help="use missing.json")
    ap.add_argument("--out", default="autogen")
    ap.add_argument("--scale", type=int, default=3, help="upscale factor for viewing (nearest)")
    a = ap.parse_args()

    pairs = list(a.pairs)
    if a.all_missing:
        here = os.path.dirname(os.path.abspath(__file__))
        for r in json.load(open(os.path.join(here, "missing.json"))):
            pairs.append(f"{r['head']}.{r['body']}")

    if not pairs:
        sys.exit("nothing to extract (pass head.body pairs or --all-missing)")

    os.makedirs(a.out, exist_ok=True)
    ok = 0
    for p in pairs:
        head, body = (int(v) for v in p.split("."))
        cell, err = extract(head, body)
        if cell is None:
            print(f"  {p:<9} SKIP  {err}")
            continue
        bb = cell.getbbox()
        cell.save(os.path.join(a.out, f"{p}.png"))
        if a.scale > 1:
            big = cell.resize((CELL * a.scale, CELL * a.scale), Image.NEAREST)
            big.save(os.path.join(a.out, f"{p}@{a.scale}x.png"))
        colors = len({px for px in cell.getdata() if px[3]})
        print(f"  {p:<9} ok    bbox={bb} {bb[2]-bb[0]}x{bb[3]-bb[1]}  colors={colors}")
        ok += 1
    print(f"\n{ok}/{len(pairs)} extracted -> {a.out}/")


if __name__ == "__main__":
    main()
