#!/usr/bin/env python3
"""Assemble the approved Mail icon masters into keyed and transparent atlases."""

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parent
FRAMES = ROOT / "frames"
NAMES = [
    "mail_envelope_leaf",
    "reward_star_coin",
    "garden_delivery_crate",
    "water_drop",
    "acorn",
    "ribbon_gift_chest",
    "claim_all_envelope",
    "close_x",
    "unread_dot",
]
CELL = 512


def load_frames() -> list[Image.Image]:
    images: list[Image.Image] = []
    for name in NAMES:
        image = Image.open(FRAMES / f"{name}_512.png").convert("RGBA")
        if image.size != (CELL, CELL):
            raise ValueError(f"{name} is {image.size}, expected {(CELL, CELL)}")
        if image.getbbox() is None:
            raise ValueError(f"{name} is empty")
        images.append(image)
    return images


def compose(images: list[Image.Image], background: tuple[int, int, int, int]) -> Image.Image:
    atlas = Image.new("RGBA", (CELL * 3, CELL * 3), background)
    for index, image in enumerate(images):
        x = (index % 3) * CELL
        y = (index // 3) * CELL
        atlas.alpha_composite(image, (x, y))
    return atlas


def main() -> None:
    images = load_frames()
    transparent = compose(images, (0, 0, 0, 0))
    transparent.save(ROOT / "mail_icons_3x3_transparent.png")

    keyed = compose(images, (255, 0, 255, 255)).convert("RGB")
    keyed.save(ROOT / "mail_icons_3x3_raw.png")

    previews = ROOT / "previews"
    previews.mkdir(exist_ok=True)
    for name, color in {
        "dark": (36, 59, 75, 255),
        "light": (255, 255, 255, 255),
        "warm_cream": (246, 235, 221, 255),
    }.items():
        compose(images, color).convert("RGB").save(previews / f"mail_icons_{name}.png")


if __name__ == "__main__":
    main()
