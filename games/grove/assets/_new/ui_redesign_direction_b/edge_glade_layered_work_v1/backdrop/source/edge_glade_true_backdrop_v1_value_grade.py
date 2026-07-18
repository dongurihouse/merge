#!/usr/bin/env python3
"""Conform and apply the approved broad meadow value progression."""

from pathlib import Path

import numpy as np
from PIL import Image, ImageOps


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "source" / "edge_glade_true_backdrop_v1_raw.png"
OUTPUT = ROOT / "final" / "edge_glade_true_backdrop_v1.png"
SIZE = (1320, 2868)

# Normalized y and grade strength. Negative values cool/darken the upper meadow;
# positive values provide a modest central lift. Cubic interpolation prevents
# hard bands, and the bottom quiet zone remains unchanged.
KNOTS = (
    (0.00, 0.0),
    (0.17, 0.0),
    (0.24, -18.0),
    (0.34, -18.0),
    (0.36, -15.0),
    (0.40, -5.0),
    (0.44, 45.0),
    (0.50, 60.0),
    (0.56, 75.0),
    (0.63, 85.0),
    (0.68, 70.0),
    (0.75, 30.0),
    (0.86, 0.0),
    (1.00, 0.0),
)


def smoothstep(value: np.ndarray) -> np.ndarray:
    return value * value * (3.0 - 2.0 * value)


def grade_curve(height: int) -> np.ndarray:
    y = np.linspace(0.0, 1.0, height, dtype=np.float32)
    result = np.zeros(height, dtype=np.float32)
    for (start_y, start_v), (end_y, end_v) in zip(KNOTS, KNOTS[1:]):
        mask = (y >= start_y) & (y <= end_y)
        t = smoothstep((y[mask] - start_y) / (end_y - start_y))
        result[mask] = start_v + (end_v - start_v) * t
    return result


def meadow_mask(pixels: np.ndarray) -> np.ndarray:
    """Select green meadow pixels while leaving the blue sky untouched."""
    green_over_blue = pixels[:, :, 1] - pixels[:, :, 2]
    return smoothstep(np.clip(green_over_blue / 40.0, 0.0, 1.0))


def compress_to_headroom(pixels: np.ndarray, delta: np.ndarray) -> np.ndarray:
    """Compress only out-of-gamut shifts; never clip a channel to 0 or 255."""
    positive_room = np.divide(
        254.5 - pixels,
        delta,
        out=np.full_like(delta, np.inf),
        where=delta > 0,
    )
    negative_room = np.divide(
        0.5 - pixels,
        delta,
        out=np.full_like(delta, np.inf),
        where=delta < 0,
    )
    scale = np.minimum(1.0, np.min(np.minimum(positive_room, negative_room), axis=2))
    return delta * np.clip(scale, 0.0, 1.0)[:, :, None]


def main() -> None:
    with Image.open(SOURCE) as source:
        conformed = ImageOps.fit(
            source.convert("RGB"),
            SIZE,
            method=Image.Resampling.LANCZOS,
            centering=(0.5, 0.5),
        )

    pixels = np.asarray(conformed, dtype=np.float32).copy()
    curve = grade_curve(SIZE[1])[:, None]
    # A row-uniform, very broad negative plateau avoids adding an artificial
    # edge at the soft horizon. Positive lift remains restricted to meadow.
    semantic_mask = np.where(curve < 0.0, 1.0, meadow_mask(pixels))
    strength = curve * semantic_mask

    # Balanced red/green weights use available gamut headroom efficiently. A
    # small inverse blue shift keeps the center fresh yellow-green and makes
    # negative upper-meadow values subtly cooler.
    delta = np.stack(
        (strength * 0.80, strength * 0.60, strength * -0.05), axis=2
    )
    pixels += compress_to_headroom(pixels, delta)

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(np.clip(pixels, 0, 255).astype(np.uint8), "RGB").save(
        OUTPUT, format="PNG"
    )


if __name__ == "__main__":
    main()
