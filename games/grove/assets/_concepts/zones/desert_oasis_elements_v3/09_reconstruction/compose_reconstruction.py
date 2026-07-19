#!/usr/bin/env python3
"""Render the Desert Oasis v3 Scene Workbench placement document for visual QA."""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image


BUNDLE = Path("games/grove/assets/_concepts/zones/desert_oasis_elements_v3")


def project_root(start: Path) -> Path:
    for candidate in (start, *start.parents):
        if (candidate / "games" / "grove").is_dir():
            return candidate
    raise SystemExit("Could not find the project root")


def main() -> None:
    root = project_root(Path(__file__).resolve())
    bundle = root / BUNDLE
    document = json.loads((bundle / "metadata" / "placements.json").read_text())
    canvas_data = document["canvas"]
    canvas_size = (round(canvas_data["width"]), round(canvas_data["height"]))

    def asset(path: str) -> Path:
        candidate = (root / path).resolve()
        if not candidate.is_file() or not candidate.is_relative_to(root):
            raise SystemExit(f"Missing or unsafe asset: {path}")
        return candidate

    base = Image.open(asset(document["base"]["image"])).convert("RGBA")
    if base.size != canvas_size:
        base = base.resize(canvas_size, Image.Resampling.LANCZOS)
    result = base.copy()

    indexed = enumerate(document["placements"])
    for _, item in sorted(indexed, key=lambda pair: (pair[1]["z"], pair[0])):
        width, height = round(item["w"]), round(item["h"])
        if width <= 0 or height <= 0:
            raise SystemExit(f"Invalid size for {item['id']}")
        image = Image.open(asset(item["image"])).convert("RGBA")
        image = image.resize((width, height), Image.Resampling.LANCZOS)
        left = round(item["x"] - width / 2)
        top = round(item["y"] - height)
        result.alpha_composite(image, (left, top))

    output_dir = bundle / "09_reconstruction"
    full = output_dir / "desert_oasis_reconstruction_v3.png"
    review = output_dir / "desert_oasis_reconstruction_v3_review_941x1672.png"
    result.save(full)
    result.resize((round(canvas_data["reviewWidth"]), round(canvas_data["reviewHeight"])), Image.Resampling.LANCZOS).save(review)
    print(f"saved {full}")
    print(f"saved {review}")


if __name__ == "__main__":
    main()
