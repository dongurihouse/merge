"""Scan the shop storefront painting and print every anchor its hit regions were derived from.

The shop screen IS the approved concept art (owner, 2026-07-30: "use the whole image from the mock").
Nothing on it is re-drawn, so the only thing the game has to know about it is WHERE each offer is —
and that is a measurement, never an eyeball. This script is the deterministic half: it finds the
anchors and prints them. The judgement — which anchor belongs to which offer, where the seam between
two offers goes, how far a region may be opened past the art it covers — lives in the registry beside
the picture (storefront_market_stall.regions.json), authored by a human from this output.

    PYTHONPATH=. python3 games/grove/tools/measure_shop_screen.py
    PYTHONPATH=. python3 games/grove/tools/measure_shop_screen.py --check   # + diff against the registry

WHAT IT FINDS, and how (every threshold is a colour rule over the painting's own palette):

  green buttons   the eight action-green price plates. G clearly over both R and B.
  cream tags      the eight amount tags, the two counter caption plaques and the ACORN POUCHES
                  plaque. Warm near-white; the awning's cream bays are excluded by y.
  posts / planks  the slate stall frame. B over R. The planks are read in the COLUMN GUTTER between
                  each shelf's two offers, which is the only strip of a shelf nothing stands on.
  gutters         that gutter itself: the widest run of columns in the middle of a bay where nothing
                  but wall and plank is painted. This is what splits a shelf into two offers, and it
                  is NOT the picture's midline — the bottom shelf's chest pushes its split to 502.
  close disc      the coral X, whose drawn diameter (93px) is under the platform's fingertip floor.

`content` below is the mask everything else is measured against: NOT the pale-meadow wall and NOT
the slate furniture, i.e. exactly the goods, tags, buttons, plaques and flags. The wall carries a
broad vignette (it darkens from 219,212,161 at the centre to 162,155,104 in the corners) so it is
matched by its SHAPE in colour space — R and G within 20 of each other, B trailing R by 40..80 —
rather than by a range around one sampled colour, which is what a flat-field detector would do and
what fails on this picture (see the shop_market_stall note in games/grove/tools/mock_targets.json).
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
REGISTRY = ROOT / "games/grove/assets/ui/dialogs/shop/storefront_market_stall.regions.json"

# The picture's own palette, as rules rather than samples (see the module note on the vignette).
def masks(a: np.ndarray) -> dict:
    r, g, b = a[:, :, 0], a[:, :, 1], a[:, :, 2]
    wall = (np.abs(r - g) < 20) & ((r - b) > 40) & ((r - b) < 80) & (r > 130) & (r < 240)
    slate = (b > r + 15) & (b > 85) & (b < 210) & (r < 175)
    green = (g > r + 18) & (g > b + 18) & (g > 70) & (g < 190)
    cream = (r > 225) & (g > 205) & (b > 150) & (b < 215) & (r >= g) & (g > b)
    coral = (r > 170) & (g < 140) & (b < 130) & (r > g + 60) & (r > b + 70)
    return {"wall": wall, "slate": slate, "green": green, "cream": cream, "coral": coral,
            "content": (~wall) & (~slate)}


def boxes(mask: np.ndarray, min_size: int) -> list[tuple[int, int, int, int]]:
    """Bounding boxes of the mask's connected components, biggest first, as [x, y, w, h].

    Flood fill by hand rather than through scipy: the repo's python guards are numpy + Pillow only,
    and adding a dependency to find eight rectangles is not a trade worth making.
    """
    h, w = mask.shape
    seen = np.zeros_like(mask, dtype=bool)
    out: list[tuple[int, tuple[int, int, int, int]]] = []
    ys, xs = np.nonzero(mask)
    for sy, sx in zip(ys, xs):
        if seen[sy, sx]:
            continue
        stack = [(sy, sx)]
        seen[sy, sx] = True
        y0 = y1 = sy
        x0 = x1 = sx
        n = 0
        while stack:
            cy, cx = stack.pop()
            n += 1
            y0, y1 = min(y0, cy), max(y1, cy)
            x0, x1 = min(x0, cx), max(x1, cx)
            for ny, nx in ((cy - 1, cx), (cy + 1, cx), (cy, cx - 1), (cy, cx + 1)):
                if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True
                    stack.append((ny, nx))
        if n >= min_size:
            out.append((n, (x0, y0, x1 - x0 + 1, y1 - y0 + 1)))
    out.sort(key=lambda t: -t[0])
    return [b for _, b in out]


def price_buttons(m: dict) -> list[tuple[int, int, int, int]]:
    """The eight green price plates, in reading order (top row first, left before right)."""
    found = boxes(m["green"], 4000)
    found.sort(key=lambda b: (b[1] // 200, b[0]))
    return found


def amount_tags(m: dict) -> list[tuple[int, int, int, int]]:
    """The eight cream amount tags — the cream sheets that sit directly above a price button.

    The same cream cuts the two counter caption plaques and the ACORN POUCHES plaque, so membership
    is decided by the button below rather than by size: a tag is the cream box whose x-range overlaps
    a button's and whose bottom is within 60px of that button's top.
    """
    cream = [b for b in boxes(m["cream"], 6000) if b[1] > 200]     # drop the awning's cream bays
    out = []
    for bx, by, bw, bh in price_buttons(m):
        best = None
        for cx, cy, cw, ch in cream:
            if cx + cw <= bx or cx >= bx + bw:
                continue
            gap = by - (cy + ch)
            if -bh < gap < 60 and (best is None or gap > best[0]):
                best = (gap, (cx, cy, cw, ch))
        out.append(best[1] if best else None)
    return out


def posts(m: dict) -> list[tuple[int, int, int, int]]:
    """The two slate stall posts, as the column runs that are slate down most of the picture."""
    frac = m["slate"][400:1900, :].mean(axis=0)
    runs, start = [], None
    for x, f in enumerate(frac):
        if f > 0.5 and start is None:
            start = x
        elif f <= 0.5 and start is not None:
            runs.append((start, x))
            start = None
    if start is not None:
        runs.append((start, len(frac)))
    out = []
    for x0, x1 in runs:
        if x1 - x0 < 10:
            continue
        col = m["slate"][:, x0:x1].mean(axis=1)
        ys = np.nonzero(col > 0.5)[0]
        out.append((x0, int(ys.min()), x1 - x0, int(ys.max() - ys.min() + 1)))
    return out


def gutters(m: dict, bays: list[tuple[int, int]]) -> list[dict]:
    """Per shelf bay, the empty column run between its two offers, and the split it implies.

    The bay is scanned for the column with the least painted content between x=400 and x=720, then
    opened out while the coverage stays within 0.06 of that minimum. The wall's paper fibre keeps the
    floor off zero (it reads 0.04-0.07), which is why the window is relative and not absolute.
    """
    out = []
    for y0, y1 in bays:
        band = m["content"][y0:y1].copy()
        band[:, :34] = False
        band[:, 1046:] = False
        cols = band.mean(axis=0)
        seg = cols[400:720]
        lo = float(seg.min())
        xm = 400 + int(seg.argmin())
        thr = lo + 0.06
        left = xm
        while left > 380 and cols[left - 1] <= thr:
            left -= 1
        right = xm
        while right < 740 and cols[right + 1] <= thr:
            right += 1
        out.append({"bay": [y0, y1], "empty_columns": [left, right],
                    "split": (left + right) // 2, "floor": round(lo, 3)})
    return out


def planks(m: dict, gutter_x: list[int]) -> list[tuple[int, int]]:
    """The four shelf planks, as slate runs read in the column gutters nothing stands on."""
    seen: list[tuple[int, int]] = []
    for gx in gutter_x:
        col = m["slate"][:, gx - 20:gx + 20].mean(axis=1)
        runs, start = [], None
        for y in range(300, col.shape[0]):
            if col[y] > 0.8 and start is None:
                start = y
            elif col[y] <= 0.8 and start is not None:
                runs.append((start, y))
                start = None
        for s, e in runs:
            if e - s >= 60 and (s, e) not in seen:
                seen.append((s, e))
    seen.sort()
    return seen


def load(path: Path) -> tuple[np.ndarray, dict]:
    img = Image.open(path).convert("RGB")
    a = np.asarray(img).astype(int)
    return a, masks(a)


def main(argv: list[str]) -> int:
    reg = json.loads(REGISTRY.read_text())
    png = ROOT / "games/grove/assets" / reg["art"].split("assets/")[-1] if "assets/" in reg["art"] \
        else ROOT / "games/grove/assets" / reg["art"]
    a, m = load(png)
    print("art        %s  %dx%d" % (png.relative_to(ROOT), a.shape[1], a.shape[0]))
    print("posts     ", posts(m))
    bays = [(370, 846), (955, 1257), (1262, 1571), (1590, 1885)]
    gt = gutters(m, bays)
    for g in gt:
        print("gutter    ", g)
    print("planks    ", planks(m, [g["split"] for g in gt]))
    print("close disc", boxes(m["coral"][100:400, 800:1080], 3000))
    tags = amount_tags(m)
    for i, (btn, tag) in enumerate(zip(price_buttons(m), tags)):
        print("offer %d    button=%s  tag=%s" % (i, list(btn), list(tag) if tag else None))

    if "--check" in argv:
        bad = 0
        for offer, btn, tag in zip(reg["offers"], price_buttons(m), tags):
            for key, got in (("button", list(btn)), ("tag", list(tag))):
                want = offer["measured"][key]
                if want != got:
                    print("MISMATCH %s.%s registry=%s measured=%s" % (offer["id"], key, want, got))
                    bad += 1
        print("check: %d mismatches" % bad)
        return 1 if bad else 0
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
