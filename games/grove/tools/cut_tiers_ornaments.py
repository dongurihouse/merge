#!/usr/bin/env python3
"""Cut the TIERS dialog CREST (the twig-and-coin sprig above the line name) out of its approved
concept mock into a keyed kit ornament.

    python3 games/grove/tools/cut_tiers_crest.py

Deterministic: every pixel op lives here; the JUDGMENT (which mock, which rect, which key
thresholds) is the constant block below, per docs/design/art-style-guide.md §8/§9.

The crest sits on the mock card's FLAT warm cream, so the key is a distance-from-cream ramp with
colour un-mixing (p = a*C + (1-a)*bg  ->  C = (p - (1-a)*bg) / a), which removes the cream halo the
naive "keep RGB" key leaves behind. Output is trimmed to its used rect.
"""
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
SRC = ROOT / "games/grove/assets/_concepts/dialogs/tiers_1080x1920.png"
DST = ROOT / "games/grove/assets/ui/kit/tiers_crest.png"

LOCK_DST = ROOT / "games/grove/assets/ui/kit/tiers_lock.png"

# (crop, background under it, key lo/hi) per ornament. The lock's KEYHOLE is the cell blue showing
# through the silhouette, so the same key correctly punches it out as transparency.
CUTS = [
    (DST, (300, 92, 780, 198), (245.0, 228.0, 204.0), 26.0, 72.0),        # the twig-and-coin crest
    (LOCK_DST, (162, 1250, 288, 1400), (145.0, 160.0, 179.0), 22.0, 60.0),  # the locked-tier padlock
]


def cut(dst: Path, crop, bg, key_lo: float, key_hi: float) -> None:
    src = Image.open(SRC).convert("RGB").crop(crop)
    p = np.asarray(src).astype(np.float64)
    bg = np.array(bg)
    dist = np.abs(p - bg).sum(axis=2)
    a = np.clip((dist - key_lo) / (key_hi - key_lo), 0.0, 1.0)
    a3 = a[:, :, None]
    # un-mix the background out of the partially covered edge pixels
    with np.errstate(invalid="ignore", divide="ignore"):
        c = np.where(a3 > 0.0, (p - (1.0 - a3) * bg) / np.maximum(a3, 1e-6), p)
    c = np.clip(c, 0.0, 255.0)
    out = Image.fromarray(np.dstack([c, a * 255.0]).astype(np.uint8), "RGBA")
    bbox = out.getbbox()
    if bbox:
        out = out.crop(bbox)
    dst.parent.mkdir(parents=True, exist_ok=True)
    out.save(dst)
    print(f"{dst.name} -> {dst}  {out.size[0]}x{out.size[1]}")


def main() -> None:
    for spec in CUTS:
        cut(spec[0], spec[1], spec[2], spec[3], spec[4])


if __name__ == "__main__":
    main()
