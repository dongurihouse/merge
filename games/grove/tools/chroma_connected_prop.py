#!/usr/bin/env python3
"""Extract one connected prop from a textured magenta generation plate.

The normal soft chroma matte treats raspberry and violet art as spill. This
extractor instead finds the largest connected non-magenta silhouette, keeps its
interior colors fully opaque, and only feathers a narrow exterior edge.
"""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage


KEY_RGB = np.array([255.0, 0.0, 255.0], dtype=np.float32)


def extract(input_path: Path, output_path: Path, padding: int) -> tuple[int, int]:
    source = Image.open(input_path).convert("RGB")
    rgb = np.asarray(source).copy()
    distance = np.linalg.norm(rgb.astype(np.float32) - KEY_RGB, axis=2)

    strong_foreground = distance >= 125.0
    labels, label_count = ndimage.label(
        strong_foreground, structure=np.ones((3, 3), dtype=np.uint8)
    )
    if label_count == 0:
        raise ValueError(f"No connected foreground found in {input_path}")

    areas = np.bincount(labels.ravel())
    areas[0] = 0
    selected = labels == int(areas.argmax())
    # Contract away the generated plate's purple/magenta fringe, then rebuild a
    # narrow antialiased edge from nearby non-key pixels. Do not fill holes:
    # openings such as the lantern hook and gate must remain transparent.
    core = ndimage.binary_erosion(selected, iterations=2)
    if not np.any(core):
        raise ValueError(f"Foreground vanished during edge cleanup for {input_path}")

    edge_band = ndimage.binary_dilation(core, iterations=4) & ~core
    edge_band &= distance > 12.0

    alpha = np.zeros(distance.shape, dtype=np.uint8)
    alpha[core] = 255
    edge_alpha = np.clip((distance - 12.0) / (125.0 - 12.0), 0.0, 1.0)
    alpha[edge_band] = np.rint(edge_alpha[edge_band] * 255.0).astype(np.uint8)

    if np.any(edge_band):
        nearest_core = ndimage.distance_transform_edt(
            ~core, return_distances=False, return_indices=True
        )
        rgb[edge_band] = rgb[
            nearest_core[0][edge_band], nearest_core[1][edge_band]
        ]

    rgba = np.dstack((rgb, alpha))
    result = Image.fromarray(rgba, "RGBA")
    bounds = result.getchannel("A").getbbox()
    if bounds is None:
        raise ValueError(f"Empty alpha result for {input_path}")

    left, top, right, bottom = bounds
    crop = (
        max(0, left - padding),
        max(0, top - padding),
        min(result.width, right + padding),
        min(result.height, bottom + padding),
    )
    result = result.crop(crop)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    result.save(output_path)
    return result.size


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--padding", type=int, default=24)
    args = parser.parse_args()

    size = extract(args.input, args.output, args.padding)
    print(f"{args.output}: {size[0]}x{size[1]}")


if __name__ == "__main__":
    main()
