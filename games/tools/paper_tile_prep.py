#!/usr/bin/env python3
"""Deterministic prep for a generated paper-fibre tile: wrap the edges, match the reference colour.

A generated fibre swatch is neither seamless nor colour-matched. The surfaces that draw it
(`CutPaperPanel`, `Kit.cut_paper_tile`) sample it with `TEXTURE_REPEAT_ENABLED` at NATIVE 1:1
scale and MULTIPLY it by the caller's fill, so two things have to be true before it ships:

1. **It wraps.** The right edge must continue into the left edge and the bottom into the top.
2. **Its mean is the reference tile's mean.** The fill colour is authored against the shipping
   fibre; a candidate that is a shade warmer or brighter silently re-tints every surface that
   wears it, and the comparison stops being about the FIBRE.

Both steps are pixel-deterministic — same input + same args produce the same bytes.

    python3 games/tools/paper_tile_prep.py <in.png> <out.png> [--ref <tile.png>] [--band 48]

`--band` is the wrap crossfade width in px (default 48). The band is a smoothstep blend between
the trailing edge strip and the MIRRORED leading strip, so the last column lands exactly on the
first column's value: local grain amplitude is preserved everywhere outside the band, and the
band itself is a few percent of the tile at the two edges the UI never shows.

`--ref` (default the shipping soft-cream tile) supplies the target per-channel mean. The match is
ADDITIVE, so the fibre's contrast (its sigma) is carried through unchanged — only the base tone moves.
"""
from __future__ import annotations

import argparse
import sys

import numpy as np
from PIL import Image

DEFAULT_REF = "games/grove/assets/ui/dialogs/paper_tile_soft_cream.png"


def _smoothstep(n: int) -> np.ndarray:
    t = np.linspace(0.0, 1.0, n)
    return t * t * (3.0 - 2.0 * t)


def wrap_edges(a: np.ndarray, band: int) -> np.ndarray:
    """Blend each trailing edge strip into the mirrored leading strip so the tile wraps."""
    out = a.astype(np.float64).copy()
    for axis in (1, 0):                      # columns first, then rows
        n = out.shape[axis]
        b = min(band, n // 4)
        if b < 2:
            continue
        w = _smoothstep(b)
        w = w.reshape((1, b, 1) if axis == 1 else (b, 1, 1))
        if axis == 1:
            lead_mirrored = out[:, b - 1::-1]       # columns b-1 … 0
            out[:, n - b:] = out[:, n - b:] * (1.0 - w) + lead_mirrored * w
        else:
            lead_mirrored = out[b - 1::-1, :]
            out[n - b:, :] = out[n - b:, :] * (1.0 - w) + lead_mirrored * w
    return out


def match_mean(a: np.ndarray, target: np.ndarray) -> np.ndarray:
    """Shift each channel so its mean equals `target` (additive: sigma is untouched)."""
    return a + (target - a.reshape(-1, a.shape[2]).mean(0))


def seam_report(a: np.ndarray) -> str:
    """Mean |step| across the wrap boundary vs. the interior — a seam shows as a ratio >> 1."""
    y = a.mean(2)
    hx = float(np.abs(y[:, 0] - y[:, -1]).mean())
    hy = float(np.abs(y[0, :] - y[-1, :]).mean())
    ix = float(np.abs(np.diff(y, axis=1)).mean())
    iy = float(np.abs(np.diff(y, axis=0)).mean())
    return (f"wrap step: x={hx:.2f} (interior {ix:.2f}, ratio {hx / ix:.2f})  "
            f"y={hy:.2f} (interior {iy:.2f}, ratio {hy / iy:.2f})")


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("src")
    ap.add_argument("dst")
    ap.add_argument("--ref", default=DEFAULT_REF)
    ap.add_argument("--band", type=int, default=48)
    args = ap.parse_args(argv)

    a = np.asarray(Image.open(args.src).convert("RGB")).astype(np.float64)
    target = np.asarray(Image.open(args.ref).convert("RGB")).astype(np.float64)
    target = target.reshape(-1, 3).mean(0)

    out = match_mean(wrap_edges(a, args.band), target)
    out = np.clip(np.rint(out), 0, 255).astype(np.uint8)
    Image.fromarray(out, "RGB").save(args.dst)
    print(f"{args.dst}  {out.shape[1]}x{out.shape[0]}  "
          f"mean={out.reshape(-1, 3).mean(0).round(1)}  {seam_report(out.astype(float))}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
