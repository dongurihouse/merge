#!/usr/bin/env python3
"""Focused regression checks for Fairy Hollow crop compositing."""

import importlib.util
import unittest
from pathlib import Path

from PIL import Image


MODULE = Path(__file__).with_name("compose_reconstruction.py")
SPEC = importlib.util.spec_from_file_location("fairy_hollow_compositor", MODULE)
assert SPEC and SPEC.loader
COMPOSITOR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(COMPOSITOR)


class BottomCropFeatherTests(unittest.TestCase):
    def test_feather_releases_the_crop_bottom_without_dimming_its_upper_edge(self):
        plate = Image.new("RGBA", (3, 8), (30, 60, 90, 255))

        feathered = COMPOSITOR.apply_bottom_crop_feather(plate, 4)

        alpha = feathered.getchannel("A")
        self.assertEqual(alpha.getpixel((1, 3)), 255)
        self.assertGreater(alpha.getpixel((1, 4)), alpha.getpixel((1, 6)))
        self.assertEqual(alpha.getpixel((1, 7)), 0)


if __name__ == "__main__":
    unittest.main()
