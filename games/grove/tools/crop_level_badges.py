#!/usr/bin/env python3
"""Tight-crop the evolving level-badge art (kit/badges/badge_NN.png) so the medal FILLS
its canvas. The badges were sliced from lvls.png with ~50% transparent padding around each
medal (plus a little slice-bleed from the neighbouring tier at the very bottom / right
edge). The HUD draws them with STRETCH_KEEP_ASPECT_CENTERED, so that padding shrank the
visible badge to ~46% of the frame — reading small with a thin-looking ring.

This crops every badge to ONE shared square window, centered on the canvas centre (the
medal disc is canvas-centred on every tier, so the number — drawn centred in the HUD — stays
aligned). The window keeps all real medal content (measured center ±124px: x[90-321],
y[87-330] across all tiers) and excludes the bottom-bleed blobs (y>=359) and the 4px right
sliver. Corners stay transparent, so hud.gd's _tex_has_transparent_corner check still holds.

Deterministic. Re-run after re-slicing lvls.png. Dial CROP below if the slice padding changes.
"""
import sys, os, glob
from PIL import Image

BADGES = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "assets", "ui", "kit", "badges"))
CANVAS = 412
CENTER = CANVAS // 2          # 206 — medal disc is centred here on every tier
HALF   = 125                  # keeps all real content (max reach from centre is 124px)
# centred square window: [81 .. 331] = 250px
X0, Y0 = CENTER - HALF + 1, CENTER - HALF + 1
SIZE   = HALF * 2


def main(out_dir):
    os.makedirs(out_dir, exist_ok=True)
    n = 0
    for p in sorted(glob.glob(os.path.join(BADGES, "badge_*.png"))):
        im = Image.open(p).convert("RGBA")
        if im.size != (CANVAS, CANVAS):
            print("  skip %s (unexpected %dx%d)" % (os.path.basename(p), *im.size))
            continue
        im.crop((X0, Y0, X0 + SIZE, Y0 + SIZE)).save(os.path.join(out_dir, os.path.basename(p)))
        n += 1
    print("cropped %d badges to %dx%d (window x0=%d y0=%d) -> %s" % (n, SIZE, SIZE, X0, Y0, out_dir))


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "/tmp/badges_cropped")
