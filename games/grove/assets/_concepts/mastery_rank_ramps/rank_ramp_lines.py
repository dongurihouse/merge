#!/usr/bin/env python3
"""Generator rank ramps v6 — muted at rank 1, jewel-vivid at rank 8.

v2 was too timid for two reasons, both fixed here:
  * saturation was only multiplied, so anything already saturated clamped at 1.0 and the
    top ranks converged -> ADDITIVE vibrance is applied on every line, strongest where
    saturation is LOW (the classic "vibrance" curve), so pale masses gain real colour.
  * high ranks were DARKENED, which reads as duller, not richer -> value now LIFTS with
    rank, and bright areas gain extra pop for luminous cut paper.
Plus hue spread: hues fan out from the sprite's dominant hue as rank rises, so a rank-8
generator reads as multi-coloured, not one flat saturated mass.

Alpha and every shape stay untouched: all 8 ranks remain provably the same object.
"""
import sys, colorsys, math, pathlib
from PIL import Image, ImageDraw

N = 8

# stem -> (sat_mult_hi, vibrance_hi, val_hi, hue_spread_hi)
# rank 1 anchors are shared and deliberately muted so the arc is dramatic.
SAT_MULT_LO, VIB_LO, VAL_LO, SPREAD_LO = 0.55, 0.00, 1.02, 1.00
LINES = {
    "glowshroom":   (2.30, 0.50, 1.15, 1.00),
    "wildberries":  (2.30, 0.50, 1.14, 1.00),
    "desertfruits": (2.25, 0.48, 1.14, 1.00),
    "koi":          (2.20, 0.46, 1.16, 1.00),
    "snowice":      (2.90, 0.62, 1.13, 1.00),
    "woolens":      (2.60, 0.58, 1.15, 1.00),
    "sand":         (2.50, 0.55, 1.14, 1.00),
    "shells":       (2.60, 0.58, 1.14, 1.00),
}


def lerp(a, b, t):
    return a + (b - a) * t


def dominant_hue(im):
    """Saturation-weighted circular mean hue — the axis hues fan out from."""
    px = im.load()
    w, h = im.size
    x_acc = y_acc = 0.0
    for y in range(0, h, 3):
        for x in range(0, w, 3):
            r, g, b, a = px[x, y]
            if a < 24:
                continue
            hh, ss, vv = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            if ss < 0.10:
                continue
            ang = hh * 2 * math.pi
            x_acc += math.cos(ang) * ss
            y_acc += math.sin(ang) * ss
    if x_acc == 0 and y_acc == 0:
        return 0.0
    return (math.atan2(y_acc, x_acc) / (2 * math.pi)) % 1.0


def recolor(im, sat_x, vib, val_x, spread, dom):
    im = im.convert("RGBA")
    px = im.load()
    w, h = im.size
    out = Image.new("RGBA", (w, h))
    op = out.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                op[x, y] = (0, 0, 0, 0)
                continue
            hh, ss, vv = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            if ss > 0.04:
                # vibrance weighted by the chroma ALREADY there: near-white paper keeps its
                # white (a faint off-hue must not be amplified into the wrong colour), while
                # genuinely coloured masses surge. w ramps 0->1 across s in [0.08, 0.33].
                vw = min(1.0, max(0.0, (ss - 0.08) / 0.25))
                ss = min(1.0, ss * sat_x + vib * vw * (1.0 - ss))
                # fan hues out from the dominant axis
                d = ((hh - dom + 0.5) % 1.0) - 0.5
                hh = (dom + d * spread) % 1.0
            vv = min(1.0, vv * val_x + 0.06 * (val_x - 1.0) * vv)
            nr, ng, nb = colorsys.hsv_to_rgb(hh, ss, vv)
            op[x, y] = (round(nr * 255), round(ng * 255), round(nb * 255), a)
    return out


def main():
    src, outdir, stem = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]), sys.argv[3]
    sm_hi, vib_hi, val_hi, sp_hi = LINES[stem]
    base = Image.open(src).convert("RGBA")
    dom = dominant_hue(base)
    outdir.mkdir(parents=True, exist_ok=True)
    tiles = []
    for i in range(N):
        t = (i / (N - 1)) ** 0.92
        img = recolor(base, lerp(SAT_MULT_LO, sm_hi, t), lerp(VIB_LO, vib_hi, t),
                      lerp(VAL_LO, val_hi, t), lerp(SPREAD_LO, sp_hi, t), dom)
        img.save(outdir / f"{stem}_r{i + 1}.png")
        tiles.append(img)
    tw, pad = 256, 12
    strip = Image.new("RGBA", (N * tw + (N + 1) * pad, tw + 2 * pad + 34), (236, 223, 194, 255))
    d = ImageDraw.Draw(strip)
    for i, t in enumerate(tiles):
        x = pad + i * (tw + pad)
        strip.alpha_composite(t.resize((tw, tw), Image.LANCZOS), (x, pad))
        d.text((x + tw // 2 - 22, pad + tw + 8), f"rank {i + 1}", fill=(36, 59, 75, 255))
    strip.save(outdir / f"{stem}_ramp_strip.png")
    print("wrote", outdir / f"{stem}_ramp_strip.png")


if __name__ == "__main__":
    main()
