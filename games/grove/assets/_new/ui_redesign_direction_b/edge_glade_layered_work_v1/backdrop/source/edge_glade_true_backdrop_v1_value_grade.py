#!/usr/bin/env python3
"""Conform and apply the approved broad meadow value progression."""

from pathlib import Path

import numpy as np
from PIL import Image, ImageOps


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "source" / "edge_glade_true_backdrop_v1_raw.png"
OUTPUT = ROOT / "final" / "edge_glade_true_backdrop_v1.png"
SIZE = (1320, 2868)

# Normalized y and grade strength. Cubic interpolation between knots prevents
# hard bands. The sky and bottom quiet zone remain unchanged.
KNOTS = (
    (0.00, 0.0),
    (0.36, 0.0),
    (0.40, 18.0),
    (0.44, 55.0),
    (0.50, 72.0),
    (0.63, 90.0),
    (0.68, 75.0),
    (0.75, 40.0),
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


def main() -> None:
    with Image.open(SOURCE) as source:
        conformed = ImageOps.fit(
            source.convert("RGB"),
            SIZE,
            method=Image.Resampling.LANCZOS,
            centering=(0.5, 0.5),
        )

    pixels = np.asarray(conformed, dtype=np.float32).copy()
    strength = grade_curve(SIZE[1])[:, None]

    # Add more red/green than blue so the brighter center remains yellow-green;
    # the same weights make the upper meadow slightly darker and cooler.
    pixels[:, :, 0] += strength * 1.00
    pixels[:, :, 1] += strength * 0.65
    pixels[:, :, 2] += strength * 0.10

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(np.clip(pixels, 0, 255).astype(np.uint8), "RGB").save(
        OUTPUT, format="PNG"
    )


if __name__ == "__main__":
    main()
