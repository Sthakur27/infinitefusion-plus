#!/usr/bin/env python3
"""spritefit — snap an arbitrary generated image to Infinite Fusion battler spec.

Spec measured from Graphics/CustomBattlers/customBaseSprites (2755 real sprites):
  * art authored on a 96x96 grid, stored as a 3x nearest-neighbour upscale -> 288x288
  * PNG8, indexed palette (colortype 3), index 0 transparent via tRNS
  * palette actually used: 12-16 colors (median 14)
  * content horizontally centred (cx~48), baseline ~y=75, typical 56w x 52h

Usage:
  python spritefit.py in.png out.png [--colors 15] [--bg auto|none|#RRGGBB] [--tol 32]
  python spritefit.py --selftest            # round-trip a real sprite, report drift
"""
import sys, argparse
from collections import deque
from PIL import Image

GRID, SCALE = 96, 3
BASELINE, CENTER = 75, 48
MAX_W, MAX_H = 92, 84


def strip_bg(im, mode, tol):
    """Flood-fill transparency inward from the border. Generated images almost never
    ship clean alpha; this is what makes them croppable at all."""
    if mode == "none":
        return im
    px = im.load()
    w, h = im.size
    if mode == "auto":
        corners = [px[0, 0], px[w - 1, 0], px[0, h - 1], px[w - 1, h - 1]]
        opaque = [c for c in corners if c[3] > 0]
        if not opaque:
            return im
        key = max(set(opaque), key=opaque.count)
    else:
        key = tuple(int(mode.lstrip("#")[i:i + 2], 16) for i in (0, 2, 4)) + (255,)

    def near(c):
        return sum(abs(a - b) for a, b in zip(c[:3], key[:3])) <= tol * 3

    seen = bytearray(w * h)
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            q.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            q.append((x, y))
    while q:
        x, y = q.popleft()
        if not (0 <= x < w and 0 <= y < h):   # bounds first — i is invalid otherwise
            continue
        i = y * w + x
        if seen[i]:
            continue
        seen[i] = 1
        if px[x, y][3] == 0 or near(px[x, y]):
            px[x, y] = (0, 0, 0, 0)
            q.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))
    return im


def fit(im, colors, box=None, n_accents=3, contrast=1.35, outline=True):
    """box = (w, h) target footprint on the 96 grid. A generated image has no inherent
    scale, so the intended size has to be supplied — it comes from the description step.
    Defaults to the measured median footprint (56x52)."""
    bb = im.getbbox()
    if not bb:
        raise SystemExit("image is fully transparent after background removal")
    art = im.crop(bb)
    w, h = art.size
    tw, th = box or (56, 52)
    tw, th = min(tw, MAX_W), min(th, MAX_H)
    s = min(tw / w, th / h)
    nw, nh = max(1, round(w * s)), max(1, round(h * s))
    # Pick accents from the FULL-RES art, before downsampling. A 3px red collar is
    # still vivid red here; after downsampling it has blended into mud and is
    # unrecoverable. This is the difference between keeping an eye/collar and losing it.
    full_accents = pick_accents_rgba(art, n_accents)

    # Downsample by MAJORITY COLOUR, not by averaging. Averaging (LANCZOS/BOX) blends
    # across block boundaries, which rounds off every hard edge and dissolves the black
    # outline — the result reads as a blurry shrunk illustration next to real sprites.
    # Taking the most common colour in each source cell keeps flat areas flat and edges
    # hard, and never invents an intermediate colour that wasn't in the art.
    art = mode_downsample(art, nw, nh, prequant=32)

    canvas = Image.new("RGBA", (GRID, GRID), (0, 0, 0, 0))
    canvas.paste(art, (CENTER - nw // 2, BASELINE - nh), art)

    # binary alpha — the format has one transparent index, there is no partial alpha
    a = canvas.getchannel("A").point(lambda v: 255 if v >= 128 else 0)
    canvas.putalpha(a)

    # Every real IF sprite reads because of two things the generated art lacks at this
    # size: punchy colour and a continuous dark outline. The model draws its outline as
    # thin 1024px linework, which loses the per-cell majority vote and survives only as
    # scattered dots. Rebuild both here rather than hoping the prompt lands them.
    if contrast != 1.0:
        canvas = boost(canvas, contrast)
        canvas.putalpha(a)
    if outline:
        canvas = draw_outline(canvas, a)

    # quantise the opaque pixels only, so no palette slot is wasted on background
    rgb = canvas.convert("RGB")
    ap = a.load()

    # Reserve slots for accent colours. Median-cut allocates by pixel count, so a
    # 3px red collar or a 2px eye gets merged into the nearest bulk colour and the
    # sprite loses exactly the details that make it readable. Pick the most
    # saturated colours present and pin them into the palette by hand.
    accents = full_accents
    q = rgb.quantize(colors=max(1, colors - len(accents)),
                     method=Image.MEDIANCUT, dither=Image.NONE)

    base = q.getpalette()[: (colors - len(accents)) * 3]
    pal = [255, 0, 255] + base + [c for rgbv in accents for c in rgbv]
    out = Image.new("P", (GRID, GRID))
    out.putpalette(pal + [0] * (768 - len(pal)))
    qp, rp, op = q.load(), rgb.load(), out.load()
    accent_base = 1 + (colors - len(accents))
    base_rgb = [tuple(base[i * 3:i * 3 + 3]) for i in range(len(base) // 3)]
    for y in range(GRID):
        for x in range(GRID):
            if ap[x, y] == 0:
                op[x, y] = 0
                continue
            src = rp[x, y]
            qi = qp[x, y]
            d_base = sum((s - t) ** 2 for s, t in zip(src, base_rgb[qi])) if qi < len(base_rgb) else 1 << 30
            best, bd = None, 1 << 30
            for i, acc in enumerate(accents):
                d = sum((s - t) ** 2 for s, t in zip(src, acc))
                if d < bd:
                    best, bd = i, d
            # take the accent only when it genuinely fits better than the bulk colour
            op[x, y] = accent_base + best if best is not None and bd < d_base else qi + 1
    out.info["transparency"] = 0
    return out.resize((GRID * SCALE, GRID * SCALE), Image.NEAREST)


def boost(im, factor):
    """Push saturation and contrast. Downsampled renders sit in a narrow mid-tone
    band; real sprites use the full range, which is most of why they read at 96px."""
    from PIL import ImageEnhance
    rgb = im.convert("RGB")
    rgb = ImageEnhance.Color(rgb).enhance(factor)
    rgb = ImageEnhance.Contrast(rgb).enhance(1.0 + (factor - 1.0) * 0.8)
    out = rgb.convert("RGBA")
    return out


def draw_outline(im, alpha):
    """Darken the one-pixel rim of the silhouette into an outline. Derived from each
    edge pixel's own colour rather than flat black, so it reads as shading rather than
    a sticker cut-out — which is what the hand-drawn sprites do."""
    px, ap = im.load(), alpha.load()
    edge = []
    for y in range(GRID):
        for x in range(GRID):
            if not ap[x, y]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if not (0 <= nx < GRID and 0 <= ny < GRID) or not ap[nx, ny]:
                    edge.append((x, y))
                    break
    for x, y in edge:
        r, g, b, _ = px[x, y]
        px[x, y] = (int(r * 0.30), int(g * 0.30), int(b * 0.32), 255)
    return im


def mode_downsample(art, nw, nh, prequant=32):
    """Shrink RGBA `art` to nw x nh by taking the most common colour in each source
    cell. Pre-quantising first makes the mode meaningful — with 27k distinct colours
    almost every pixel is unique and the mode degenerates to an arbitrary pick."""
    art = art.convert("RGBA")
    w, h = art.size
    rgb = art.convert("RGB").quantize(colors=prequant, method=Image.MEDIANCUT,
                                      dither=Image.NONE).convert("RGB")
    src, alpha = rgb.load(), art.getchannel("A").load()
    out = Image.new("RGBA", (nw, nh), (0, 0, 0, 0))
    dst = out.load()
    for ty in range(nh):
        y0, y1 = ty * h // nh, max(ty * h // nh + 1, (ty + 1) * h // nh)
        for tx in range(nw):
            x0, x1 = tx * w // nw, max(tx * w // nw + 1, (tx + 1) * w // nw)
            counts, opaque, total = {}, 0, 0
            for y in range(y0, y1):
                for x in range(x0, x1):
                    total += 1
                    if alpha[x, y] < 128:
                        continue
                    opaque += 1
                    c = src[x, y]
                    counts[c] = counts.get(c, 0) + 1
            # a cell is solid only if it is mostly opaque — keeps the silhouette tight
            if not counts or opaque * 2 < total:
                continue
            dst[tx, ty] = max(counts.items(), key=lambda kv: kv[1])[0] + (255,)
    return out


def pick_accents_rgba(art, n):
    """Most saturated distinct colours in a full-res RGBA crop, de-duplicated.
    Run before downsampling — that is the whole point."""
    if n <= 0:
        return []
    import colorsys
    counts = {}
    for px in art.convert("RGBA").getdata():
        if px[3] > 128:
            counts[px[:3]] = counts.get(px[:3], 0) + 1
    total = sum(counts.values()) or 1
    scored = []
    for c, n_px in counts.items():
        _, s, v = colorsys.rgb_to_hsv(*[k / 255 for k in c])
        frac = n_px / total
        # want vivid, but present in more than a stray speckle and less than the body
        if s < 0.45 or v < 0.25 or frac < 0.0004 or frac > 0.30:
            continue
        scored.append((s * v * (frac ** 0.25), c))
    scored.sort(reverse=True)
    picked = []
    for _, c in scored:
        if all(sum((a - b) ** 2 for a, b in zip(c, q)) > 5000 for q in picked):
            picked.append(c)
        if len(picked) == n:
            break
    return picked


def used_colors(p):
    return len({v for v in p.convert("RGBA").getdata() if v[3]})


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src", nargs="?")
    ap.add_argument("dst", nargs="?")
    ap.add_argument("--colors", type=int, default=15, help="palette size excl. transparent (real sprites: 12-16)")
    ap.add_argument("--bg", default="auto", help="auto | none | #RRGGBB")
    ap.add_argument("--tol", type=int, default=32)
    ap.add_argument("--contrast", type=float, default=1.35, help="saturation/contrast boost; 1.0 = off")
    ap.add_argument("--no-outline", action="store_true", help="skip the rebuilt silhouette outline")
    ap.add_argument("--accents", type=int, default=3, help="palette slots reserved for saturated accent colours")
    ap.add_argument("--box", default="56x52", help="target art footprint on the 96 grid (median real sprite = 56x52)")
    ap.add_argument("--selftest", action="store_true")
    a = ap.parse_args()
    box = tuple(int(v) for v in a.box.lower().split("x"))

    if a.selftest:
        import glob, random
        random.seed(1)
        fs = random.sample(sorted(glob.glob("Graphics/CustomBattlers/customBaseSprites/*.png")), 6)
        print("round-tripping real sprites (target box = each sprite's own footprint; expect near-identity):")
        worst = 0
        for f in fs:
            src = Image.open(f).convert("RGBA")
            sa = src.resize((GRID, GRID), Image.NEAREST).getbbox()
            own = (sa[2] - sa[0], sa[3] - sa[1])
            out = fit(strip_bg(src.copy(), "auto", 32), a.colors, own, a.accents, a.contrast, not a.no_outline)
            oa = out.resize((GRID, GRID), Image.NEAREST).getbbox()
            d = max(abs(oa[2] - oa[0] - own[0]), abs(oa[3] - oa[1] - own[1]))
            worst = max(worst, d)
            print(f"  {f.split(chr(92))[-1]:>12}  in {own[0]}x{own[1]} colors={used_colors(src):>2}"
                  f"  -> out {oa[2]-oa[0]}x{oa[3]-oa[1]} colors={used_colors(out):>2}"
                  f"  baseline={oa[3]} cx={(oa[0]+oa[2])//2}  drift={d}px")
        print(f"\nworst footprint drift: {worst}px on the 96 grid; baseline should read 75, cx 48")
        return

    if not (a.src and a.dst):
        ap.error("need src and dst (or --selftest)")
    im = Image.open(a.src).convert("RGBA")
    out = fit(strip_bg(im, a.bg, a.tol), a.colors, box, a.accents, a.contrast, not a.no_outline)
    out.save(a.dst, optimize=True, transparency=0)
    print(f"{a.src} -> {a.dst}  {out.size}  mode={out.mode}  colors_used={used_colors(out)}")


if __name__ == "__main__":
    main()
