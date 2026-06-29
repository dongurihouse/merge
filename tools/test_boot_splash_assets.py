#!/usr/bin/env python3
"""Regression checks for the mobile launch splash handoff."""
import re
import struct
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
LAUNCH_RES = "res://games/grove/assets/ui/boot/splash_launch.png"
LAUNCH_FILE = ROOT / LAUNCH_RES.removeprefix("res://")
CREAM = "Color(0.956, 0.933, 0.874, 1)"


def _setting(path, key):
    text = (ROOT / path).read_text()
    m = re.search(r"^%s=(.*)$" % re.escape(key), text, re.MULTILINE)
    if m is None:
        raise AssertionError("%s missing %s" % (path, key))
    return m.group(1).strip()


def _png_header(path):
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise AssertionError("%s is not a PNG" % path)
    return {
        "width": struct.unpack(">I", data[16:20])[0],
        "height": struct.unpack(">I", data[20:24])[0],
        "bit_depth": data[24],
        "color_type": data[25],
    }


class BootSplashAssetTests(unittest.TestCase):
    def test_native_splash_uses_the_composed_boot_scene_frame(self):
        self.assertEqual(_setting("project.godot", "boot_splash/image"), '"%s"' % LAUNCH_RES)
        self.assertEqual(
            _setting("export_presets.cfg", "storyboard/custom_image@2x"),
            '"%s"' % LAUNCH_RES,
        )
        self.assertEqual(
            _setting("export_presets.cfg", "storyboard/custom_image@3x"),
            '"%s"' % LAUNCH_RES,
        )

    def test_launch_storyboard_background_matches_engine_fallback(self):
        self.assertEqual(_setting("project.godot", "boot_splash/bg_color"), CREAM)
        self.assertEqual(_setting("export_presets.cfg", "storyboard/use_custom_bg_color"), "true")
        self.assertEqual(_setting("export_presets.cfg", "storyboard/custom_bg_color"), CREAM)

    def test_composed_launch_image_matches_design_viewport(self):
        self.assertTrue(LAUNCH_FILE.exists(), "%s should exist" % LAUNCH_FILE)
        header = _png_header(LAUNCH_FILE)
        self.assertEqual((header["width"], header["height"]), (1080, 1920))
        self.assertEqual(header["bit_depth"], 8)
        self.assertIn(header["color_type"], (2, 6))


if __name__ == "__main__":
    unittest.main()
