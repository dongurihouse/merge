#!/usr/bin/env python3
"""Composite a rank-number badge onto a generator sprite — REVIEW MOCK ONLY.

The shipped badge is built in code (board.gd `_make_boost_badge`): rounded box, cream
border, cream numeral, box shadow, hung off a corner of the generator. This mirrors that
construction so the ramp strips show what the rank badge would look like, in mastery gold
(STRAW #D6A94C) rather than the boost badge's green, and on the BOTTOM-right so the two
badges can never collide.

At runtime the number must be drawn like the boost badge, NOT baked into the sprite: the
rank is data, and 64 sprites with baked numerals cannot restyle or localise.
"""
import sys, pathlib
from PIL import Image, ImageDraw, ImageFont

FONT = "/System/Library/Fonts/Supplemental/Arial Rounded Bold.ttf"
STRAW = (214, 169, 76, 255)
CREAM = (246, 235, 221, 255)
INK = (36, 59, 75, 255)
SHADOW = (41, 70, 84, 90)


STYLES = {
    "gold":  (STRAW, CREAM, CREAM),   # fill, border, text
    "cream": (CREAM, INK,   INK),
    "ink":   (INK,   CREAM, CREAM),
}


def badge(sprite: Image.Image, text: str, corner: str = "br", style: str = "gold") -> Image.Image:
    im = sprite.convert("RGBA").copy()
    S = im.size[0]
    d = ImageDraw.Draw(im)
    fs = int(S * 0.155)
    try:
        font = ImageFont.truetype(FONT, fs)
    except OSError:
        font = ImageFont.load_default()
    tb = d.textbbox((0, 0), text, font=font)
    tw, th = tb[2] - tb[0], tb[3] - tb[1]
    pad_x, pad_y = int(S * 0.055), int(S * 0.035)
    bw, bh = tw + pad_x * 2, th + pad_y * 2
    bw = max(bw, bh)  # keep it at least round
    x = S - bw - int(S * 0.04) if corner.endswith("r") else int(S * 0.04)
    y = S - bh - int(S * 0.05) if corner.startswith("b") else int(S * 0.02)
    r = int(bh * 0.5)

    d.rounded_rectangle([x + 3, y + 5, x + bw + 3, y + bh + 5], radius=r, fill=SHADOW)
    fill, border, txt = STYLES[style]
    d.rounded_rectangle([x, y, x + bw, y + bh], radius=r, fill=fill,
                        outline=border, width=max(2, int(S * 0.012)))
    d.text((x + bw / 2 - tw / 2 - tb[0], y + bh / 2 - th / 2 - tb[1]), text,
           font=font, fill=txt)
    return im


def main() -> None:
    ramp_dir, stem, out = pathlib.Path(sys.argv[1]), sys.argv[2], pathlib.Path(sys.argv[3])
    corner = sys.argv[4] if len(sys.argv) > 4 else "br"
    style = sys.argv[5] if len(sys.argv) > 5 else "gold"
    tiles = []
    for i in range(1, 9):
        s = Image.open(ramp_dir / f"{stem}_r{i}.png").convert("RGBA")
        tiles.append(badge(s, str(i), corner, style))
    tw, pad = 256, 12
    strip = Image.new("RGBA", (8 * tw + 9 * pad, tw + 2 * pad + 34), (236, 223, 194, 255))
    d = ImageDraw.Draw(strip)
    for i, t in enumerate(tiles):
        x = pad + i * (tw + pad)
        strip.alpha_composite(t.resize((tw, tw), Image.LANCZOS), (x, pad))
        d.text((x + tw // 2 - 22, pad + tw + 8), f"rank {i + 1}", fill=INK[:3])
    out.parent.mkdir(parents=True, exist_ok=True)
    strip.save(out)
    print("wrote", out)


if __name__ == "__main__":
    main()
