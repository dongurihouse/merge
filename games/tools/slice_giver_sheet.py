#!/usr/bin/env python3
"""Slice the 5x5 quest-giver character sheet into 25 clean 256x256 bust sprites.

Source: assets/_originals/characters/quest_givers_5x5_cutpaper_v2_green_raw.png
Output: assets/characters/giver_<n>.png (row 0) and giver_m<row>_<n>.png (rows 1..4)
        — one themed 5-face cast per map, the pool Bust.giver_path() reads.

ROOT CAUSE this tool fixes
--------------------------
The shipped busts were flat-bottomed: every character's authored rounded paper base
was gone, so the cut-paper cutout ended in a hard horizontal line and read as
"clipped at the bottom" on the quest card. The generator DID draw the bases (they
are plainly there on the raw sheet) — they were lost downstream by a fixed-grid cut
whose cell pitch did not match the drawn layout, so each cell's bottom band fell
into the next row and was thrown away.

Segmenting by CONNECTED COMPONENTS on the de-keyed sheet and bucketing components
into cells by CENTROID makes that class of bug impossible: nothing is ever cut at a
cell boundary, so a subject is either wholly present or loudly missing.

Sizing
------
The pool must read with CONSISTENT VISUAL WEIGHT (§5, character bust contract), so a
SINGLE scale derived from the largest subject on the sheet is applied to all 25 —
never a per-sprite fill, which would blow up the small characters. Each bust is
centred horizontally and sits on a COMMON BASELINE, so the paper bases line up
across the cast when the cards sit side by side.

Usage
-----
  python3 games/tools/slice_giver_sheet.py [--montage] [--dry-run]
"""
from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

REPO = Path(__file__).resolve().parents[2]
SRC = REPO / "games/grove/assets/_originals/characters/quest_givers_5x5_cutpaper_v2_green_raw.png"
OUT_DIR = REPO / "games/grove/assets/characters"
SCRATCH = REPO / "tmp/givercut"

ROWS, COLS = 5, 5
SIZE = 256          # output canvas (square) — the §5 character-bust master
FILL = 0.94         # the LARGEST subject fills this fraction of the canvas
BOTTOM_PAD = 0.03   # baseline gap under the paper base, as a fraction of SIZE
MIN_AREA = 400      # ignore foreground specks below this when bucketing
TOL_FLOOD = 70      # key distance (0-255 RGB euclidean) for the border flood
POCKET_MIN = 120    # an enclosed key pocket must be at least this big to punch
RAMP_LO, RAMP_HI = 30, 110   # green-excess band mapped opaque -> transparent
DESPILL_D = 15      # in a visible pixel, clamp G <= max(R,B) + DESPILL_D


def green_excess(rgb: np.ndarray) -> np.ndarray:
    """How much greener than the subject's own red/blue a pixel is."""
    return rgb[:, :, 1].astype(np.int32) - np.maximum(rgb[:, :, 0], rgb[:, :, 2]).astype(np.int32)


def key_mask(rgba: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Return (foreground bool mask, sampled key colour)."""
    h, w, _ = rgba.shape
    rgb = rgba[:, :, :3].astype(np.int32)
    corners = np.concatenate([
        rgb[0:8, 0:8].reshape(-1, 3), rgb[0:8, w - 8:w].reshape(-1, 3),
        rgb[h - 8:h, 0:8].reshape(-1, 3), rgb[h - 8:h, w - 8:w].reshape(-1, 3)])
    key = np.median(corners, axis=0)
    dist = np.sqrt(((rgb - key) ** 2).sum(axis=2))
    near_key = (dist < TOL_FLOOD) | (green_excess(rgb) > RAMP_HI)

    # Background = near-key regions reachable from the border. The flood only follows
    # key-coloured pixels, so the characters' own green foliage (walled off by their
    # cut edge, and far from pure #09F80D) survives.
    lbl, _ = ndimage.label(near_key)
    border = set(np.unique(np.concatenate([lbl[0], lbl[-1], lbl[:, 0], lbl[:, -1]])))
    border.discard(0)
    bg = np.isin(lbl, list(border))

    # Enclosed key pockets a border flood can't reach (a lantern handle's eye, the gap
    # under an arm). Only punch a pocket that is genuinely the key colour.
    enclosed = near_key & ~bg
    elbl, en = ndimage.label(enclosed)
    for li in range(1, en + 1):
        m = elbl == li
        if int(m.sum()) >= POCKET_MIN and dist[m].mean() < TOL_FLOOD:
            bg |= m
    return ~bg, key


def despill(arr: np.ndarray) -> np.ndarray:
    """Clamp residual key tint in every visible pixel; zero RGB outside alpha.

    Run on the full-res cut AND again after the resize: unpremultiplying a LANCZOS
    result divides an 8-bit premultiplied colour by a small alpha, and the rounding
    error is amplified per channel — which resurrects a green edge band out of an
    already-clean cut. Re-clamping after the resample is what actually holds the gate.
    """
    rgb = arr[:, :, :3].astype(np.float64)
    vis = arr[:, :, 3] > 16
    cap = np.maximum(rgb[:, :, 0], rgb[:, :, 2]) + DESPILL_D
    rgb[:, :, 1] = np.where(vis, np.minimum(rgb[:, :, 1], cap), rgb[:, :, 1])
    rgb[~vis] = 0.0
    return np.concatenate([np.clip(rgb, 0, 255), arr[:, :, 3:4]], axis=2).astype(np.uint8)


def cut_rgba(rgba: np.ndarray, fg: np.ndarray) -> np.ndarray:
    """Soft alpha ramp over key distance + despill, per §8 edge treatment."""
    ge = green_excess(rgba[:, :, :3])
    ramp = np.clip((RAMP_HI - ge) / float(RAMP_HI - RAMP_LO), 0.0, 1.0)
    alpha = np.where(fg, ramp * 255.0, 0.0)
    return despill(np.concatenate(
        [rgba[:, :, :3].astype(np.float64), alpha[:, :, None]], axis=2).astype(np.uint8))


def premult_resize(arr: np.ndarray, nw: int, nh: int) -> Image.Image:
    """LANCZOS resize through premultiplied alpha — no dark or key-colour halo."""
    a = arr[:, :, 3:4].astype(np.float64) / 255.0
    pm = np.concatenate([arr[:, :, :3].astype(np.float64) * a,
                         arr[:, :, 3:4].astype(np.float64)], axis=2)
    img = Image.fromarray(np.clip(pm, 0, 255).astype(np.uint8), "RGBA").resize(
        (nw, nh), Image.LANCZOS)
    out = np.asarray(img).astype(np.float64)
    a2 = out[:, :, 3:4] / 255.0
    with np.errstate(divide="ignore", invalid="ignore"):
        rgb2 = np.where(a2 > 0, out[:, :, :3] / a2, 0)
    return Image.fromarray(
        np.concatenate([np.clip(rgb2, 0, 255), out[:, :, 3:4]], axis=2).astype(np.uint8), "RGBA")


def name_for(r: int, c: int) -> str:
    return f"giver_{c}.png" if r == 0 else f"giver_m{r}_{c}.png"


def gate(name: str, frame: Image.Image) -> list[str]:
    """The §8 acceptance gate — measured, not eyeballed. Returns failure strings."""
    a = np.asarray(frame).astype(np.int32)
    vis = a[:, :, 3] > 16
    fails = []
    fringe = int((vis & (green_excess(a[:, :, :3].astype(np.uint8)) > 40)).sum())
    if fringe:
        fails.append(f"{name}: {fringe} key-fringe px")
    edge = int(vis[0].sum() + vis[-1].sum() + vis[:, 0].sum() + vis[:, -1].sum())
    if edge:
        fails.append(f"{name}: {edge} opaque px on a canvas edge (clipped)")
    # A flat-bottomed bust is the defect this tool exists to kill: a genuine cut-paper
    # base tapers, so its last few rows narrow. A silhouette whose bottom row is as wide
    # as the widest row below the waist was truncated, not drawn.
    ys = np.where(vis.any(axis=1))[0]
    if len(ys):
        widths = vis[ys.min():ys.max() + 1].sum(axis=1)
        low = widths[len(widths) // 2:]
        if len(low) and widths[-1] >= low.max() * 0.9:
            fails.append(f"{name}: flat bottom — last row {int(widths[-1])} px vs "
                         f"max lower-half {int(low.max())} px")
    return fails


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--montage", action="store_true", help="write a review montage to tmp/givercut/")
    ap.add_argument("--dry-run", action="store_true", help="write to tmp/givercut/ instead of assets/characters/")
    args = ap.parse_args()

    if not SRC.exists():
        raise SystemExit(f"FAIL: missing source {SRC}")
    rgba = np.array(Image.open(SRC).convert("RGBA"))
    h, w, _ = rgba.shape
    fg, key = key_mask(rgba)
    cut = cut_rgba(rgba, fg)

    lbl, n = ndimage.label(fg)
    areas = ndimage.sum(np.ones_like(lbl), lbl, range(1, n + 1))
    coms = ndimage.center_of_mass(np.ones_like(lbl), lbl, range(1, n + 1))
    cells: dict[tuple[int, int], list[int]] = {}
    for li in range(1, n + 1):
        if areas[li - 1] < MIN_AREA:
            continue
        cy, cx = coms[li - 1]
        cells.setdefault((min(ROWS - 1, int(cy * ROWS / h)),
                          min(COLS - 1, int(cx * COLS / w))), []).append(li)

    missing = [(r, c) for r in range(ROWS) for c in range(COLS) if (r, c) not in cells]
    if missing:
        raise SystemExit(f"FAIL: {len(missing)} empty cell(s) {missing} — "
                         f"segmentation found no subject there; check the sheet or MIN_AREA.")

    # bboxes first — one shared scale keeps the cast's visual weight consistent.
    boxes = {}
    for rc, comps in cells.items():
        ys, xs = np.where(np.isin(lbl, comps))
        boxes[rc] = (ys.min(), ys.max() + 1, xs.min(), xs.max() + 1)
    biggest = max(max(y1 - y0, x1 - x0) for y0, y1, x0, x1 in boxes.values())
    scale = SIZE * FILL / biggest
    base_y = SIZE - int(round(SIZE * BOTTOM_PAD))

    out_dir = SCRATCH if (args.dry_run or args.montage and args.dry_run) else OUT_DIR
    if args.dry_run:
        out_dir = SCRATCH
    out_dir.mkdir(parents=True, exist_ok=True)

    tiles, fails = [], []
    for r in range(ROWS):
        for c in range(COLS):
            y0, y1, x0, x1 = boxes[(r, c)]
            mask = np.isin(lbl, cells[(r, c)])[y0:y1, x0:x1]
            sub = cut[y0:y1, x0:x1].copy()
            sub[:, :, 3] = np.where(mask, sub[:, :, 3], 0)
            nw = max(1, round((x1 - x0) * scale))
            nh = max(1, round((y1 - y0) * scale))
            frame = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
            obj = Image.fromarray(despill(np.asarray(premult_resize(sub, nw, nh))), "RGBA")
            frame.alpha_composite(obj, ((SIZE - nw) // 2, base_y - nh))
            name = name_for(r, c)
            fails += gate(name, frame)
            frame.save(out_dir / name)
            tiles.append(frame)

    if fails:
        raise SystemExit("FAIL acceptance gate:\n  " + "\n  ".join(fails))
    print(f"slice_giver_sheet: {ROWS * COLS} busts -> {out_dir}  "
          f"(key={key.astype(int).tolist()}, comps={n}, scale={scale:.3f})")

    if args.montage:
        SCRATCH.mkdir(parents=True, exist_ok=True)
        for tag, bgc in (("cream", (236, 223, 194, 255)), ("dark", (36, 59, 75, 255))):
            canvas = Image.new("RGBA", (COLS * SIZE, ROWS * SIZE), bgc)
            for i, t in enumerate(tiles):
                canvas.alpha_composite(t, ((i % COLS) * SIZE, (i // COLS) * SIZE))
            p = SCRATCH / f"givers_montage_{tag}.png"
            canvas.convert("RGB").save(p)
            print(f"    montage -> {p}")


if __name__ == "__main__":
    main()
