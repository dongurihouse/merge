#!/usr/bin/env python3
"""Per-line generator rank ramps: 8 recolors of ONE sprite, muted -> vivid.

Alpha and every shape are preserved exactly, so all 8 ranks are provably the same object.
Per line we author a curve, because a single global curve leaves pale lines (Snow & Ice,
Woolens, Shells, Sand) nearly unchanged: multiplying the saturation of a near-white pixel
is a no-op. Pale lines therefore get an ADDITIVE chroma lift plus a value fall, so they
deepen into their own hue instead of just "staying pale".

Per line: sat_mult lo->hi, sat_add lo->hi (additive chroma, the pale-line lever),
val lo->hi. Rank 1 sits slightly below the shipped art, rank 8 is the vivid top.
"""
import sys, colorsys, pathlib
from PIL import Image, ImageDraw

N = 8

# stem -> (sat_mult_lo, sat_mult_hi, sat_add_lo, sat_add_hi, val_lo, val_hi)
LINES = {
    # already-saturated lines: multiplicative is enough
    "glowshroom":   (0.78, 1.98, 0.00, 0.00, 1.05, 0.96),
    "wildberries":  (0.78, 1.92, 0.00, 0.02, 1.05, 0.95),
    "desertfruits": (0.78, 1.90, 0.00, 0.02, 1.05, 0.96),
    "koi":          (0.80, 1.70, 0.00, 0.00, 1.06, 0.94),
    # pale lines: need additive chroma + a value fall to read across 8 steps
    "snowice":      (0.85, 2.40, 0.00, 0.30, 1.05, 0.88),
    "woolens":      (0.82, 2.10, 0.00, 0.17, 1.05, 0.92),
    "sand":         (0.85, 2.00, 0.00, 0.13, 1.05, 0.93),
    "shells":       (0.82, 2.10, 0.00, 0.15, 1.05, 0.92),
}


def lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def recolor(im: Image.Image, sat_x: float, sat_add: float, val_x: float) -> Image.Image:
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
            # additive lift scales with how much colour is already there, so pure
            # white/black stay neutral and only tinted paper deepens
            ss = min(1.0, ss * sat_x + sat_add * (1.0 if ss > 0.06 else 0.0))
            vv = min(1.0, vv * val_x)
            nr, ng, nb = colorsys.hsv_to_rgb(hh, ss, vv)
            op[x, y] = (round(nr * 255), round(ng * 255), round(nb * 255), a)
    return out


def ramp_for(stem: str, src: pathlib.Path, outdir: pathlib.Path) -> list:
    sml, smh, sal, sah, vl, vh = LINES[stem]
    base = Image.open(src).convert("RGBA")
    outdir.mkdir(parents=True, exist_ok=True)
    tiles = []
    for i in range(N):
        t = i / (N - 1)
        img = recolor(base, lerp(sml, smh, t), lerp(sal, sah, t), lerp(vl, vh, t))
        img.save(outdir / f"{stem}_r{i + 1}.png")
        tiles.append(img)
    return tiles


def main() -> None:
    src, outdir, stem = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]), sys.argv[3]
    tiles = ramp_for(stem, src, outdir)
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
