#!/usr/bin/env python3
"""Generate an Infinite Fusion battler sprite via the OpenAI image API.

Pipeline:  descriptions.md  ->  OpenAI image  ->  spritefit.py  ->  288x288 PNG8

Two modes:
  --mode generate   text-to-image from the description alone
  --mode edit       conditions on the game's autogen sprite (extract_autogen.py),
                    so the silhouette and proportions stay in the IF idiom

Models (see `--model`):
  gpt-image-1   supports background=transparent  (clean alpha, no flood-fill guesswork)
  gpt-image-2   latest / best shapes, but NO transparent background — we fall back
                to spritefit's flood-fill removal

Key is read from tools/sidmod_editor/sim/.openaiapikey and never printed.
Nothing is written into Graphics/ — output lands in --out only.
"""
import argparse, base64, os, re, sys
from io import BytesIO
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
KEY_PATH = os.path.join(HERE, "..", "sim", ".openaiapikey")
DESCRIPTIONS = os.path.join(HERE, "descriptions.md")

# The single most important instruction here is the blocky-pixel one. The model
# renders at illustration detail by default, and downsampling 1024 -> 96 then
# destroys it (thin limbs disappear, colours wash out). Telling it each pixel is a
# ~10x10 block makes the 1024 output *already* 96px art, so the downsample is
# near-lossless and the texture survives.
STYLE = (
    "TRUE PIXEL ART, rendered as if the image were only 96x96 pixels and then "
    "scaled up: every pixel is a large ~10x10 square block of one flat colour, "
    "with hard square edges. No smooth curves, no soft gradients, no blur, no "
    "anti-aliasing, no dithering, no fine detail smaller than one block.\n"
    "Gen-5 Pokemon Black/White battle sprite: front view, single creature, full "
    "body, hard black outline one block thick, cel shading in flat colour bands, "
    "light source upper-left.\n"
    "Bold and readable at small size: thick sturdy limbs, chunky solid forms, "
    "strong contrast between light and shadow, saturated colours. Avoid thin "
    "spindly limbs, wispy edges, and pale washed-out tones — they vanish at this "
    "scale.\n"
    "Fewer than 16 distinct colours total. Plain background, no ground shadow, "
    "no text, no border, no watermark, no signature. Centred, whole creature "
    "visible with a generous margin — do not crop any part of it."
)


def load_key():
    with open(os.path.abspath(KEY_PATH)) as f:
        key = f.read().strip()
    if not key:
        sys.exit("key file is empty")
    return key


def load_description(fusion):
    """Pull one entry's prose + box out of descriptions.md."""
    text = open(DESCRIPTIONS, encoding="utf-8").read()
    blocks = re.split(r"\n## ", text)
    for b in blocks:
        m = re.search(r"`(\d+\.\d+)`", b)
        if not m or m.group(1) != fusion:
            continue
        box = re.search(r"box `(\d+x\d+)`", b)
        title = b.split("\n", 1)[0]
        # prose = everything after the heading, minus the trailing "Ramps:" line
        body = b.split("\n", 1)[1].strip()
        ramps = ""
        if "\nRamps:" in body:
            body, ramps = body.split("\nRamps:", 1)
            ramps = "Palette, use only these ramps: " + ramps.strip()
        return title.strip(), body.strip(), ramps, (box.group(1) if box else "56x52")
    sys.exit(f"no entry for {fusion} in descriptions.md")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("fusion", help="head.body, e.g. 347.349")
    ap.add_argument("--mode", choices=["generate", "edit"], default="edit")
    ap.add_argument("--model", default="gpt-image-1",
                    help="gpt-image-1 (transparent bg) | gpt-image-2 (best shapes, opaque)")
    ap.add_argument("--quality", default="high", choices=["low", "medium", "high", "auto"])
    ap.add_argument("--size", default="1024x1024")
    ap.add_argument("--n", type=int, default=1, help="how many candidates")
    ap.add_argument("--autogen-dir", default=os.path.join(HERE, "autogen"))
    ap.add_argument("--out", default=os.path.join(HERE, "out"))
    ap.add_argument("--colors", type=int, default=16)
    ap.add_argument("--accents", type=int, default=4)
    a = ap.parse_args()

    from openai import OpenAI
    client = OpenAI(api_key=load_key())

    title, prose, ramps, box = load_description(a.fusion)
    prompt = f"{STYLE}\n\n{prose}\n\n{ramps}"
    transparent = a.model == "gpt-image-1"
    if transparent:
        prompt += "\n\nThe background must be fully transparent."

    os.makedirs(a.out, exist_ok=True)
    print(f"{a.fusion}  {title}")
    print(f"  mode={a.mode} model={a.model} quality={a.quality} size={a.size} n={a.n} box={box}")

    kw = dict(model=a.model, prompt=prompt, size=a.size, n=a.n, quality=a.quality)
    if transparent:
        kw["background"] = "transparent"

    if a.mode == "edit":
        ref = os.path.join(a.autogen_dir, f"{a.fusion}.png")
        if not os.path.exists(ref):
            sys.exit(f"missing autogen reference {ref}\n"
                     f"  run: python extract_autogen.py {a.fusion} --out {a.autogen_dir}")
        # upscale the 96px reference so the model can actually see it
        big = Image.open(ref).convert("RGBA").resize((1024, 1024), Image.NEAREST)
        buf = BytesIO()
        big.save(buf, format="PNG")
        buf.name, buf.seek = "reference.png", buf.seek
        buf.seek(0)
        kw["prompt"] = (
            "Redraw the attached sprite as a single polished creature. The attached image "
            "is a crude automatic splice of two Pokemon — keep its overall silhouette, "
            "pose, and proportions, but fix the seam where the head meets the body, "
            "harmonise the two colour schemes into one coherent palette, and clean up the "
            "shading.\n\n" + prompt
        )
        kw["image"] = buf
        resp = client.images.edit(**kw)
    else:
        resp = client.images.generate(**kw)

    from subprocess import run
    for i, item in enumerate(resp.data):
        raw_path = os.path.join(a.out, f"{a.fusion}_{a.mode}_{a.model}_{i}_raw.png")
        Image.open(BytesIO(base64.b64decode(item.b64_json))).save(raw_path)
        fit_path = raw_path.replace("_raw.png", "_fit.png")
        cmd = [sys.executable, os.path.join(HERE, "spritefit.py"), raw_path, fit_path,
               "--box", box, "--colors", str(a.colors), "--accents", str(a.accents),
               "--bg", "none" if transparent else "auto"]
        r = run(cmd, capture_output=True, text=True)
        if r.returncode != 0:
            print(f"  FIT FAILED: {r.stderr.strip().splitlines()[-1] if r.stderr else '?'}")
            continue
        print(f"  ok -> {os.path.basename(fit_path)}")

    if getattr(resp, "usage", None):
        print(f"  usage: {resp.usage}")


if __name__ == "__main__":
    main()
