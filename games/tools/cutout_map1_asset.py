#!/usr/bin/env python3
"""Cut the dark matte background out of map1 prop renders."""

from __future__ import annotations

import argparse
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image


def border_pixels(rgb: np.ndarray, width: int) -> np.ndarray:
    top = rgb[:width, :, :].reshape(-1, 3)
    bottom = rgb[-width:, :, :].reshape(-1, 3)
    left = rgb[:, :width, :].reshape(-1, 3)
    right = rgb[:, -width:, :].reshape(-1, 3)
    return np.concatenate([top, bottom, left, right], axis=0)


def flood_from_edges(candidate: np.ndarray) -> np.ndarray:
    h, w = candidate.shape
    seen = np.zeros((h, w), dtype=bool)
    queue: deque[tuple[int, int]] = deque()

    for x in range(w):
        if candidate[0, x]:
            seen[0, x] = True
            queue.append((0, x))
        if candidate[h - 1, x] and not seen[h - 1, x]:
            seen[h - 1, x] = True
            queue.append((h - 1, x))

    for y in range(h):
        if candidate[y, 0] and not seen[y, 0]:
            seen[y, 0] = True
            queue.append((y, 0))
        if candidate[y, w - 1] and not seen[y, w - 1]:
            seen[y, w - 1] = True
            queue.append((y, w - 1))

    while queue:
        y, x = queue.popleft()
        for yy, xx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
            if 0 <= yy < h and 0 <= xx < w and candidate[yy, xx] and not seen[yy, xx]:
                seen[yy, xx] = True
                queue.append((yy, xx))

    return seen


def dilate(mask: np.ndarray, iterations: int) -> np.ndarray:
    out = mask
    for _ in range(iterations):
        padded = np.pad(out, 1, mode="constant", constant_values=False)
        out = (
            padded[:-2, 1:-1]
            | padded[2:, 1:-1]
            | padded[1:-1, :-2]
            | padded[1:-1, 2:]
            | padded[:-2, :-2]
            | padded[:-2, 2:]
            | padded[2:, :-2]
            | padded[2:, 2:]
            | padded[1:-1, 1:-1]
        )
    return out


def cutout(
    src: Path,
    dst: Path,
    *,
    matte_threshold: float = 30.0,
    feather: float = 18.0,
    interior_threshold: float = 24.0,
    edge_width: int = 24,
) -> dict[str, float]:
    image = Image.open(src).convert("RGB")
    rgb_u8 = np.array(image)
    rgb = rgb_u8.astype(np.float32)

    matte = np.median(border_pixels(rgb, edge_width), axis=0)
    dist = np.linalg.norm(rgb - matte, axis=2)

    matte_candidate = dist <= matte_threshold
    outer = flood_from_edges(matte_candidate)
    inner = dist <= interior_threshold
    transparent = outer | inner

    alpha = np.full(dist.shape, 255, dtype=np.float32)
    alpha[transparent] = 0

    soft_zone = dilate(outer, 2) & ~transparent
    alpha[soft_zone] = np.minimum(
        alpha[soft_zone],
        np.clip((dist[soft_zone] - matte_threshold) / feather, 0, 1) * 255,
    )

    rgba = np.dstack([rgb_u8, alpha.astype(np.uint8)])
    dst.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(rgba, "RGBA").save(dst)

    return {
        "width": float(image.width),
        "height": float(image.height),
        "matte_r": float(matte[0]),
        "matte_g": float(matte[1]),
        "matte_b": float(matte[2]),
        "transparent_pixels": float(np.count_nonzero(alpha == 0)),
        "semi_pixels": float(np.count_nonzero((alpha > 0) & (alpha < 255))),
        "opaque_pixels": float(np.count_nonzero(alpha == 255)),
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("inputs", nargs="+", type=Path)
    parser.add_argument("--out-dir", type=Path, default=Path("assets/map1/cutouts"))
    parser.add_argument("--matte-threshold", type=float, default=30.0)
    parser.add_argument("--interior-threshold", type=float, default=24.0)
    parser.add_argument("--feather", type=float, default=18.0)
    args = parser.parse_args()

    for src in args.inputs:
        dst = args.out_dir / src.name
        meta = cutout(
            src,
            dst,
            matte_threshold=args.matte_threshold,
            interior_threshold=args.interior_threshold,
            feather=args.feather,
        )
        print(
            f"{src} -> {dst} "
            f"transparent={int(meta['transparent_pixels'])} "
            f"semi={int(meta['semi_pixels'])} "
            f"matte=({meta['matte_r']:.1f},{meta['matte_g']:.1f},{meta['matte_b']:.1f})"
        )


if __name__ == "__main__":
    main()
