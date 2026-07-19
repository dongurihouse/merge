#!/usr/bin/env python3
"""Regression coverage for the Workbench reference-composite placement contract."""

import importlib.util
import unittest
from pathlib import Path

from PIL import Image


MODULE = Path(__file__).parents[1] / "tools" / "bake_scene_composites.py"
SPEC = importlib.util.spec_from_file_location("scene_composite_baker", MODULE)
assert SPEC and SPEC.loader
BAKER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(BAKER)


class PlacementImageTests(unittest.TestCase):
    def test_crop_and_bottom_feather_match_a_scene_placement(self):
        source = Image.new("RGBA", (8, 8), (30, 60, 90, 255))

        placed = BAKER.placement_image(
            source,
            {"sourceCrop": [1, 1, 4, 4], "sourceCropFeatherBottom": 2},
        )

        self.assertEqual(placed.size, (4, 4))
        self.assertEqual(placed.getpixel((1, 2))[3], 255)
        self.assertEqual(placed.getpixel((1, 3))[3], 0)


if __name__ == "__main__":
    unittest.main()
