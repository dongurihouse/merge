#!/usr/bin/env python3
"""Un-blend plate rows against their flat blue bg, cut plates, compose a 4x4 sheet.

Opaque cream-plate pixels are kept as-is (alpha 255). Shadow pixels (a mix of the
flat bg and the tinted shadow color) are un-blended: C = a*S + (1-a)*B  ->  a is
recovered per pixel and the color set to the shadow tint S. Result: one sprite per
plate with its soft baked shadow as real alpha.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

SHADOW = np.array([0x29, 0x46, 0x54], dtype=np.float64)  # tinted shadow #294654
BG_TOL = 8.0          # max-channel distance treated as pure background
SHADOW_HUE_TOL = 26.0  # distance from the B->S mix line to still count as shadow


def estimate_bg(rgb: np.ndarray) -> np.ndarray:
    corners = np.concatenate([
        rgb[:12, :12].reshape(-1, 3), rgb[:12, -12:].reshape(-1, 3),
        rgb[-12:, :12].reshape(-1, 3), rgb[-12:, -12:].reshape(-1, 3)])
    return np.median(corners, axis=0)


def unblend(path: Path) -> Image.Image:
    im = Image.open(path).convert("RGB")
    rgb = np.asarray(im, dtype=np.float64)
    bg = estimate_bg(rgb)
    print(f"{path.name}: bg={bg.astype(int).tolist()}")

    d_bg = np.abs(rgb - bg).max(axis=2)
    # alpha if the pixel is a bg/shadow mix (per-channel, then median)
    denom = bg - SHADOW
    a_ch = (bg - rgb) / denom  # per channel
    a = np.clip(np.median(a_ch, axis=2), 0.0, 1.0)
    # residual: how far the pixel is from the B->S mix line at that alpha
    pred = a[..., None] * SHADOW + (1.0 - a[..., None]) * bg
    resid = np.abs(rgb - pred).max(axis=2)

    is_bg = d_bg <= BG_TOL
    is_shadow = (~is_bg) & (resid <= SHADOW_HUE_TOL)
    is_plate = (~is_bg) & (~is_shadow)

    out = np.zeros(rgb.shape[:2] + (4,), dtype=np.uint8)
    out[is_plate, :3] = rgb[is_plate].astype(np.uint8)
    out[is_plate, 3] = 255
    out[is_shadow, :3] = SHADOW.astype(np.uint8)
    out[is_shadow, 3] = (a[is_shadow] * 255).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def cut_components(rgba: Image.Image, expect: int):
    arr = np.asarray(rgba)
    mask = arr[..., 3] > 10
    lab, n = ndimage.label(mask, structure=np.ones((3, 3)))
    sizes = ndimage.sum(mask, lab, range(1, n + 1))
    order = np.argsort(sizes)[::-1][:expect]
    boxes = []
    for idx in order:
        ys, xs = np.where(lab == idx + 1)
        boxes.append((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
    boxes.sort(key=lambda b: b[0])  # left-to-right
    if len(boxes) != expect:
        print(f"  WARNING: found {len(boxes)} components, expected {expect}")
    return [rgba.crop(b) for b in boxes]


def main():
    scratch = Path(sys.argv[1])
    rows_dir = sys.argv[2] if len(sys.argv) > 2 else "rows"
    suffix = "_" + rows_dir.split("_")[-1] if "_" in rows_dir else "_v1"
    rows = sorted((scratch / rows_dir).glob("plates_row_*.png"))
    if len(rows) != 4:
        sys.exit(f"expected 4 row images, found {len(rows)}: {[r.name for r in rows]}")
    tiles = []
    for row in rows:
        rgba = unblend(row)
        cuts = cut_components(rgba, 4)
        print(f"  {row.name}: {[c.size for c in cuts]}")
        tiles.append(cuts)

    cell = max(max(max(c.size) for c in row) for row in tiles)
    cell += 8  # breathing room
    sheet = Image.new("RGBA", (cell * 4, cell * 4), (0, 0, 0, 0))
    for r, row in enumerate(tiles):
        for c, tile in enumerate(row):
            ox = c * cell + (cell - tile.width) // 2
            oy = r * cell + (cell - tile.height) // 2
            sheet.alpha_composite(tile, (ox, oy))
    out = scratch / f"quest_plates_4x4{suffix}.png"
    sheet.save(out)
    print(f"sheet: {out} {sheet.size} cell={cell}")

    preview = Image.new("RGBA", sheet.size, (0x6F, 0xA9, 0xC0, 255))
    preview.alpha_composite(sheet)
    pv = scratch / f"quest_plates_4x4{suffix}_preview.png"
    preview.convert("RGB").save(pv)
    print(f"preview: {pv}")


if __name__ == "__main__":
    main()
