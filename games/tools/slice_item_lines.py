#!/usr/bin/env python3
"""Slice the item-LINE sheets into clean, correctly-cut 512x512 sprites.

Each merge line ships as a 12-tier sheet under assets/_originals/items/<family>.png.
This tool turns one sheet into <family>_1.png .. <family>_12.png (row-major, tier
order) in assets/items/<family>/.

ROOT CAUSE this tool fixes
--------------------------
The previous slicers (proc_line.gd fixed-grid, slice_grid.gd band-detect) cut a
sheet into uniform grid CELLS, then cropped each cell to its content bounding box.
But the artist did not draw every subject perfectly inside its uniform cell, so a
thin SLIVER of a neighbouring item — cut off by the grid line — landed inside a
cell. The content bbox then spanned subject+sliver, so the subject came out
shrunk, pushed off-centre, with a stray fragment stuck at the cell edge
(honey_5's floating disc, mushroom_7's stray cap, ...).

WORKAROUND
----------
Segment by CONNECTED COMPONENTS on the whole de-backgrounded sheet — objects are
never cut by a grid line, so each physical item is exactly one component (plus any
genuinely-detached parts). Assign each component to its grid cell by CENTROID; a
cell is the union of the components whose centroid lands in it. Slivers cannot
exist because nothing is cut at a boundary.

Background removal
------------------
Flood-fill the background colour (sampled from the four corners) inward from the
image borders. Because the fill only follows bg-coloured pixels CONNECTED to the
edge, pale item interiors walled off by the item's dark outline survive even when
they match the bg colour. For SATURATED backgrounds (the cyan/pink sheets) also
punch enclosed bg-coloured pockets — the gaps between thin mushroom stems — but
skip that for a pale/cream background, where it would hole pale items.

Usage
-----
  python3 games/tools/slice_item_lines.py [--family NAME ...] [--montage] [--dry-run]

  --family   process only the named line(s); default = all
  --montage  also write a magenta review montage per sheet to tmp/itemcut/
  --dry-run  write sprites to tmp/itemcut/<family>/ instead of the shipped folder
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

REPO = Path(__file__).resolve().parents[2]
SRC_DIR = REPO / "games/grove/assets/_originals/items"
OUT_DIR = REPO / "games/grove/assets/items"
SCRATCH = REPO / "tmp/itemcut"

# Per-sheet judgement: grid rows x cols (= tier count, row-major in ascending tier).
SHEETS = {
    "honey":    (4, 3),
    "mushroom": (4, 3),
    "flower":   (4, 3),
    "feather":  (3, 4),
    "tools":    (4, 3),
    # §6.D special "treasure" line sheets (#3) — 1086x1448 = 4 rows × 3 cols, white matte.
    "special_pumpkin":  (4, 3),
    "special_banana":   (4, 3),
    "special_avacado":  (4, 3),
    "special_cherry":   (4, 3),
}

SIZE = 512          # output canvas (square)
FILL = 0.92         # largest dimension fills this fraction of the canvas
MIN_AREA = 200      # ignore foreground specks below this when bucketing
TOL_FLOOD = 60      # bg colour distance (0-255 RGB euclidean) for the border flood
POCKET_MIN = 60     # an enclosed bg pocket must be at least this big to punch
TOL_POCKET = 45     # ... and its mean colour this close to bg (saturated sheets only)


def clean(rgba: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Return (foreground bool mask, sampled bg colour)."""
    h, w, _ = rgba.shape
    rgb = rgba[:, :, :3].astype(np.int32)
    alpha = rgba[:, :, 3]
    corners = np.concatenate([
        rgb[0:8, 0:8].reshape(-1, 3), rgb[0:8, w - 8:w].reshape(-1, 3),
        rgb[h - 8:h, 0:8].reshape(-1, 3), rgb[h - 8:h, w - 8:w].reshape(-1, 3)])
    bg = np.median(corners, axis=0)
    dist = np.sqrt(((rgb - bg) ** 2).sum(axis=2))
    near_bg = (dist < TOL_FLOOD) | (alpha < 8)

    # Background = near-bg regions reachable from the border.
    lbl, _ = ndimage.label(near_bg)
    border = set(np.unique(np.concatenate([lbl[0], lbl[-1], lbl[:, 0], lbl[:, -1]])))
    border.discard(0)
    bg_mask = np.isin(lbl, list(border))

    # Saturated bg: also punch enclosed bg-coloured pockets (gaps between thin stems).
    punched = np.zeros_like(bg_mask)
    bg_sat = 0.0 if bg.max() <= 0 else (bg.max() - bg.min()) / bg.max()
    if bg_sat > 0.5:
        enclosed = near_bg & ~bg_mask & (alpha >= 8)
        elbl, en = ndimage.label(enclosed)
        for li in range(1, en + 1):
            m = elbl == li
            if int(m.sum()) >= POCKET_MIN and dist[m].mean() < TOL_POCKET:
                punched |= m

    fg = ~bg_mask & ~punched & (alpha >= 8)
    return fg, bg


def premult_resize(arr: np.ndarray, nw: int, nh: int) -> Image.Image:
    """LANCZOS resize through premultiplied alpha — no dark or bg-colour halo."""
    a = arr[:, :, 3:4].astype(np.float64) / 255.0
    rgb = arr[:, :, :3].astype(np.float64)
    pm = np.concatenate([rgb * a, arr[:, :, 3:4].astype(np.float64)], axis=2)
    img = Image.fromarray(np.clip(pm, 0, 255).astype(np.uint8), "RGBA").resize(
        (nw, nh), Image.LANCZOS)
    out = np.asarray(img).astype(np.float64)
    a2 = out[:, :, 3:4] / 255.0
    with np.errstate(divide="ignore", invalid="ignore"):
        rgb2 = np.where(a2 > 0, out[:, :, :3] / a2, 0)
    res = np.concatenate([np.clip(rgb2, 0, 255), out[:, :, 3:4]], axis=2)
    return Image.fromarray(res.astype(np.uint8), "RGBA")


def slice_sheet(family: str, rows: int, cols: int, out_dir: Path,
                montage: bool) -> None:
    src = SRC_DIR / f"{family}.png"
    if not src.exists():
        raise SystemExit(f"FAIL: missing source {src}")
    rgba = np.array(Image.open(src).convert("RGBA"))
    h, w, _ = rgba.shape
    fg, bg = clean(rgba)
    lbl, n = ndimage.label(fg)
    areas = ndimage.sum(np.ones_like(lbl), lbl, range(1, n + 1))
    coms = ndimage.center_of_mass(np.ones_like(lbl), lbl, range(1, n + 1))

    cells: dict[tuple[int, int], list[int]] = {}
    for li in range(1, n + 1):
        if areas[li - 1] < MIN_AREA:
            continue
        cy, cx = coms[li - 1]
        r = min(rows - 1, int(cy * rows / h))
        c = min(cols - 1, int(cx * cols / w))
        cells.setdefault((r, c), []).append(li)

    missing = [(r, c) for r in range(rows) for c in range(cols) if (r, c) not in cells]
    if missing:
        raise SystemExit(
            f"FAIL {family}: {len(missing)} empty cell(s) {missing} — "
            f"segmentation did not find an object for every tier; "
            f"check grid {rows}x{cols} or tune TOL/MIN_AREA.")

    out_dir.mkdir(parents=True, exist_ok=True)
    tiles = []
    for r in range(rows):
        for c in range(cols):
            tier = r * cols + c + 1
            mask = np.isin(lbl, cells[(r, c)])
            ys, xs = np.where(mask)
            y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
            sub = rgba[y0:y1, x0:x1].copy()
            sub[:, :, 3] = np.where(mask[y0:y1, x0:x1], sub[:, :, 3], 0)
            bw, bh = x1 - x0, y1 - y0
            sc = SIZE * FILL / max(bw, bh)
            nw, nh = max(1, round(bw * sc)), max(1, round(bh * sc))
            obj = premult_resize(sub, nw, nh)
            frame = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
            frame.alpha_composite(obj, ((SIZE - nw) // 2, (SIZE - nh) // 2))
            frame.save(out_dir / f"{family}_{tier}.png")
            tiles.append(frame)

    print(f"  {family}: {rows * cols} sprites -> {out_dir}  "
          f"(bg~{bg.astype(int).tolist()}, comps={n})")

    if montage:
        SCRATCH.mkdir(parents=True, exist_ok=True)
        gap = 8
        canvas = Image.new("RGBA",
                           (cols * SIZE + (cols + 1) * gap, rows * SIZE + (rows + 1) * gap),
                           (255, 0, 255, 255))
        for r in range(rows):
            for c in range(cols):
                canvas.alpha_composite(tiles[r * cols + c],
                                      (gap + c * (SIZE + gap), gap + r * (SIZE + gap)))
        mpath = SCRATCH / f"{family}_montage.png"
        canvas.save(mpath)
        print(f"    montage -> {mpath}")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--family", action="append", choices=sorted(SHEETS),
                    help="process only this line (repeatable); default = all")
    ap.add_argument("--montage", action="store_true",
                    help="write a review montage per sheet to tmp/itemcut/")
    ap.add_argument("--dry-run", action="store_true",
                    help="write to tmp/itemcut/<family>/ instead of the shipped folder")
    args = ap.parse_args()

    fams = args.family or sorted(SHEETS)
    print(f"slice_item_lines: {', '.join(fams)}"
          f"{'  [dry-run]' if args.dry_run else ''}")
    for fam in fams:
        rows, cols = SHEETS[fam]
        out_dir = (SCRATCH / fam) if args.dry_run else (OUT_DIR / fam)
        slice_sheet(fam, rows, cols, out_dir, args.montage)
    print("done.")


if __name__ == "__main__":
    main()
