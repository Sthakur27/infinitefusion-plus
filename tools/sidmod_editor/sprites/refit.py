#!/usr/bin/env python3
"""Re-run spritefit over every already-generated raw image.

The expensive part is the API call; fitting is local and free. Use this to iterate
on downsampling/palette settings across all 13 sprites without spending anything.

  python refit.py                 # re-fit all, default settings
  python refit.py --colors 18 --accents 4
"""
import argparse, json, os, subprocess, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_sprite import load_description

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
MODEL = "gpt-image-2"

ap = argparse.ArgumentParser()
ap.add_argument("--colors", type=int, default=18)
ap.add_argument("--accents", type=int, default=4)
ap.add_argument("--model", default=MODEL)
a = ap.parse_args()

pairs = [f"{r['head']}.{r['body']}" for r in
         json.load(open(os.path.join(HERE, "missing.json")))]

ok = 0
for p in pairs:
    raw = os.path.join(OUT, f"{p}_edit_{a.model}_0_raw.png")
    if not os.path.exists(raw):
        print(f"  {p:<9} no raw — skipped")
        continue
    _, _, _, box = load_description(p)
    fit = raw.replace("_raw.png", "_fit.png")
    r = subprocess.run([sys.executable, os.path.join(HERE, "spritefit.py"), raw, fit,
                        "--box", box, "--colors", str(a.colors),
                        "--accents", str(a.accents), "--bg", "auto"],
                       capture_output=True, text=True)
    if r.returncode != 0:
        print(f"  {p:<9} FAILED: {(r.stderr or '').strip().splitlines()[-1:]}")
        continue
    tail = (r.stdout or "").strip().split("colors_used=")[-1]
    print(f"  {p:<9} refit box={box:<6} colors_used={tail}")
    ok += 1

print(f"\n{ok}/{len(pairs)} refitted (colors={a.colors}, accents={a.accents})")
