#!/usr/bin/env python3
"""Extract the standalone house / bag / coin-sack icons from the baked board nav buttons.

The board's nav_home / nav_bag / nav_merchant sprites are a cream-gold DISC with the icon
baked on its face — there is no standalone icon. To put these on the SHARED home-button shell
(ui/shared/disc_round.png) like the map's shop/gear/map icons, we lift just the icon off each
disc: clear the outer ring annulus, then flood-fill the cream face inward from the border (so
the icon — and any enclosed light interior, e.g. the house walls — survives), and trim.

  python3 games/grove/tools/extract_nav_icons.py

Deterministic: same source nav buttons -> identical icons. Re-run after the nav art changes.
"""
from __future__ import annotations
from collections import deque
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path("games/grove/assets/ui")
# (source nav button, output icon, ring-clear radius as a fraction of the disc radius)
JOBS = [
    ("nav/nav_home.png",     "shared/icon_house.png", 0.62),   # small central house — tight clear
    ("nav/nav_bag.png",      "shared/icon_bag.png",   0.76),   # clear the WHOLE ring so the face floods out
    ("nav/nav_merchant.png", "shared/icon_sack.png",  0.74),   # (a ring remnant would block the flood -> halo)
]


def extract(src: Path, ring_r: float) -> Image.Image:
    a = np.array(Image.open(src).convert("RGBA")).astype(np.float32) / 255.0
    h, w = a.shape[:2]
    al = a[..., 3]
    ys, xs = np.where(al > 0.4)
    cy, cx = ys.mean(), xs.mean()
    rr = np.sqrt((np.arange(h)[:, None] - cy) ** 2 + (np.arange(w)[None, :] - cx) ** 2)
    radius = rr[al > 0.4].max()
    v = a[..., :3].max(-1)
    mn = a[..., :3].min(-1)
    sat = np.where(v > 0, (v - mn) / np.maximum(v, 1e-6), 0)
    a2 = a.copy()
    a2[..., 3] = np.where(rr > ring_r * radius, 0.0, a2[..., 3])     # drop the outer gold/tan ring
    al2 = a2[..., 3]
    # background = the cream face (bright OR shadowed: low-saturation, mid-to-high value) + transparent.
    # The saturated icon (red roof, tan leather, gold coins, green bushes) survives; an ENCLOSED light
    # interior (the house walls) survives too — the border flood never reaches it.
    bgish = ((al2 > 0.3) & (v > 0.62) & (sat < 0.25)) | (al2 < 0.25)
    bg = np.zeros((h, w), bool)
    q: deque = deque()
    for x in range(w):
        for y in (0, h - 1):
            if bgish[y, x] and not bg[y, x]:
                bg[y, x] = True; q.append((y, x))
    for y in range(h):
        for x in (0, w - 1):
            if bgish[y, x] and not bg[y, x]:
                bg[y, x] = True; q.append((y, x))
    while q:
        y, x = q.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and bgish[ny, nx] and not bg[ny, nx]:
                bg[ny, nx] = True; q.append((ny, nx))
    a2[..., 3] = np.where(bg, 0.0, a2[..., 3])
    # premultiplied supersample to anti-alias the new alpha edge with no cream/checker fringe
    pm = a2.copy()
    for c in range(3):
        pm[..., c] = a2[..., c] * a2[..., 3]
    pim = Image.fromarray((np.clip(pm, 0, 1) * 255).astype(np.uint8), "RGBA")
    big = pim.resize((w * 3, h * 3), Image.LANCZOS).resize((w, h), Image.LANCZOS)
    s = np.array(big).astype(np.float32) / 255.0
    na = s[..., 3]
    out = np.zeros((h, w, 4), np.float32)
    nz = na > 1e-3
    for c in range(3):
        out[..., c] = np.where(nz, np.clip(s[..., c] / np.maximum(na, 1e-6), 0, 1), 0)
    out[..., 3] = na
    img = Image.fromarray((out * 255).astype(np.uint8), "RGBA")
    ys2, xs2 = np.where(out[..., 3] > 0.1)
    return img.crop((xs2.min(), ys2.min(), xs2.max() + 1, ys2.max() + 1))


def main() -> None:
    for src_rel, out_rel, ring_r in JOBS:
        icon = extract(ROOT / src_rel, ring_r)
        (ROOT / out_rel).parent.mkdir(parents=True, exist_ok=True)
        icon.save(ROOT / out_rel)
        print(f"  {src_rel} -> {out_rel}  {icon.size}")


if __name__ == "__main__":
    main()
