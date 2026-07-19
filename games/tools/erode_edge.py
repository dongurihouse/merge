#!/usr/bin/env python3
"""Erode a transparent sprite's alpha edge, in place — kills baked-in chroma fringe.

An upscaled or pre-keyed drop can carry an OPAQUE halo ring (art blended with the old
chroma background) that no distance keyer can clear without eating same-hue art (e.g.
#FF00FF fringe vs the palette's rare purple). The ring lives in the outermost pixels, so
a small alpha EROSION removes it colour-blind: shrink alpha by `radius` px (min filter),
then soften the new edge with a 1 px blur. Colours are untouched; only alpha changes.

  python3 games/tools/erode_edge.py <png> [png ...] [--radius 2]

Deterministic: same input + radius -> same output. Part of the intake toolset
(docs/design/art-style-guide.md §8); run --import / make import after.
"""
import argparse
import sys

from PIL import Image, ImageFilter


def erode_edge(path: str, radius: int) -> None:
    im = Image.open(path).convert("RGBA")
    r, g, b, a = im.split()
    # MinFilter kernel size must be odd: 2*radius+1 erodes by `radius` px
    a = a.filter(ImageFilter.MinFilter(2 * radius + 1))
    a = a.filter(ImageFilter.GaussianBlur(1))
    Image.merge("RGBA", (r, g, b, a)).save(path)
    print(f"erode_edge {path} — alpha eroded {radius}px + 1px soften")


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("paths", nargs="+")
    ap.add_argument("--radius", type=int, default=2)
    args = ap.parse_args(argv)
    for p in args.paths:
        erode_edge(p, args.radius)
    return 0


if __name__ == "__main__":
    sys.exit(main())
