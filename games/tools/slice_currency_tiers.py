#!/usr/bin/env python3
"""Slice the combined 3x6 currency tier sheet into shipped item sprites.

The source sheet is row-major:
  cells 1-9   -> coin_4.png .. coin_12.png
  cells 10-18 -> acorn_4.png .. acorn_12.png

Usage:
  python3 games/tools/slice_currency_tiers.py [--source PATH] [--montage] [--dry-run]
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

REPO = Path(__file__).resolve().parents[2]
DEFAULT_SOURCE = REPO / "games/grove/assets/_new/currency_tiers_v1/currency_tiers_3x6_raw.png"
OUT_ROOT = REPO / "games/grove/assets/items"
META_PATH = REPO / "games/grove/assets/_new/currency_tiers_v1/pipeline-meta.json"
SCRATCH = REPO / "tmp/currency_tiers"

ROWS = 6
COLS = 3
SIZE = 512
FILL = 0.90
MIN_AREA = 80
TOL_FLOOD = 70
TOL_POCKET = 42
POCKET_MIN = 40


def load_rgba(path: Path) -> np.ndarray:
    return np.array(Image.open(path).convert("RGBA"))


def foreground_mask(rgba: np.ndarray) -> tuple[np.ndarray, list[int]]:
    h, w, _ = rgba.shape
    rgb = rgba[:, :, :3].astype(np.int32)
    alpha = rgba[:, :, 3]
    corners = np.concatenate([
        rgb[0:8, 0:8].reshape(-1, 3),
        rgb[0:8, w - 8:w].reshape(-1, 3),
        rgb[h - 8:h, 0:8].reshape(-1, 3),
        rgb[h - 8:h, w - 8:w].reshape(-1, 3),
    ])
    bg = np.median(corners, axis=0)
    dist = np.sqrt(((rgb - bg) ** 2).sum(axis=2))
    near_bg = (dist < TOL_FLOOD) | (alpha < 8)

    lbl, _ = ndimage.label(near_bg)
    border = set(np.unique(np.concatenate([lbl[0], lbl[-1], lbl[:, 0], lbl[:, -1]])))
    border.discard(0)
    bg_mask = np.isin(lbl, list(border))

    punched = np.zeros_like(bg_mask)
    bg_sat = 0.0 if bg.max() <= 0 else float((bg.max() - bg.min()) / bg.max())
    if bg_sat > 0.5:
        enclosed = near_bg & ~bg_mask & (alpha >= 8)
        elbl, en = ndimage.label(enclosed)
        for li in range(1, en + 1):
            m = elbl == li
            if int(m.sum()) >= POCKET_MIN and float(dist[m].mean()) < TOL_POCKET:
                punched |= m

    return (~bg_mask & ~punched & (alpha >= 8)), [int(v) for v in bg]


def premult_resize(arr: np.ndarray, nw: int, nh: int) -> Image.Image:
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


def target_for(index: int) -> tuple[str, int]:
    if index < 9:
        return "coin", index + 4
    return "acorn", index - 9 + 4


def slice_sheet(source: Path, dry_run: bool, montage: bool) -> None:
    rgba = load_rgba(source)
    h, w, _ = rgba.shape
    fg, bg = foreground_mask(rgba)
    lbl, n = ndimage.label(fg)
    areas = ndimage.sum(np.ones_like(lbl), lbl, range(1, n + 1))
    coms = ndimage.center_of_mass(np.ones_like(lbl), lbl, range(1, n + 1))

    cells: dict[tuple[int, int], list[int]] = {}
    for li in range(1, n + 1):
        if float(areas[li - 1]) < MIN_AREA:
            continue
        cy, cx = coms[li - 1]
        r = min(ROWS - 1, int(cy * ROWS / h))
        c = min(COLS - 1, int(cx * COLS / w))
        cells.setdefault((r, c), []).append(li)

    missing = [(r, c) for r in range(ROWS) for c in range(COLS) if (r, c) not in cells]
    if missing:
        raise SystemExit(f"FAIL: empty currency sheet cells: {missing}")

    out_root = SCRATCH / "dry-run" if dry_run else OUT_ROOT
    meta = {
        "source": str(source.relative_to(REPO)),
        "rows": ROWS,
        "cols": COLS,
        "output_size": SIZE,
        "background_rgb": bg,
        "items": [],
    }
    tiles: list[Image.Image] = []

    for r in range(ROWS):
        for c in range(COLS):
            index = r * COLS + c
            base, tier = target_for(index)
            mask = np.isin(lbl, cells[(r, c)])
            ys, xs = np.where(mask)
            y0, y1, x0, x1 = int(ys.min()), int(ys.max() + 1), int(xs.min()), int(xs.max() + 1)
            sub = rgba[y0:y1, x0:x1].copy()
            sub[:, :, 3] = np.where(mask[y0:y1, x0:x1], sub[:, :, 3], 0)
            bw, bh = x1 - x0, y1 - y0
            scale = SIZE * FILL / max(bw, bh)
            nw, nh = max(1, round(bw * scale)), max(1, round(bh * scale))
            obj = premult_resize(sub, nw, nh)
            frame = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
            frame.alpha_composite(obj, ((SIZE - nw) // 2, (SIZE - nh) // 2))

            out_dir = out_root / base
            out_dir.mkdir(parents=True, exist_ok=True)
            out_path = out_dir / f"{base}_{tier}.png"
            frame.save(out_path)
            tiles.append(frame)

            meta["items"].append({
                "index": index + 1,
                "row": r + 1,
                "col": c + 1,
                "base": base,
                "tier": tier,
                "target": str(out_path.relative_to(REPO)),
                "source_bbox": [x0, y0, x1, y1],
                "components": len(cells[(r, c)]),
            })

    if not dry_run:
        META_PATH.parent.mkdir(parents=True, exist_ok=True)
        META_PATH.write_text(json.dumps(meta, indent=2) + "\n", encoding="utf-8")

    if montage:
        SCRATCH.mkdir(parents=True, exist_ok=True)
        gap = 8
        canvas = Image.new(
            "RGBA",
            (COLS * SIZE + (COLS + 1) * gap, ROWS * SIZE + (ROWS + 1) * gap),
            (255, 0, 255, 255),
        )
        for r in range(ROWS):
            for c in range(COLS):
                canvas.alpha_composite(tiles[r * COLS + c], (gap + c * (SIZE + gap), gap + r * (SIZE + gap)))
        canvas.save(SCRATCH / "currency_tiers_montage.png")

    mode = "dry-run" if dry_run else "shipped"
    print(f"slice_currency_tiers: wrote 18 {mode} sprites from {source}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--montage", action="store_true")
    args = parser.parse_args()

    if not args.source.exists():
        raise SystemExit(f"FAIL: missing source {args.source}")
    slice_sheet(args.source, args.dry_run, args.montage)


if __name__ == "__main__":
    main()
