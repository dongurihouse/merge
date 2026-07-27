#!/usr/bin/env python3
"""Regression checks for the mobile launch splash handoff."""
import re
import struct
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
LAUNCH_RES = "res://games/grove/assets/ui/boot/splash_launch.png"
LAUNCH_FILE = ROOT / LAUNCH_RES.removeprefix("res://")


def _setting(path, key):
    text = (ROOT / path).read_text()
    m = re.search(r"^%s=(.*)$" % re.escape(key), text, re.MULTILINE)
    if m is None:
        raise AssertionError("%s missing %s" % (path, key))
    return m.group(1).strip()


def _has_setting(path, key):
    text = (ROOT / path).read_text()
    return re.search(r"^%s=" % re.escape(key), text, re.MULTILINE) is not None


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
        # The colour is READ from project.godot (the engine fallback the iOS storyboard has
        # to match) and asserted equal on the export preset — never re-typed here as a third
        # copy, which would just go stale on the next retune. Same lesson as
        # tools/test_stamp_build_info.sh, which reads the version out of export_presets.cfg.
        cream = _setting("project.godot", "boot_splash/bg_color")
        self.assertRegex(cream, r"^Color\([\d.]+, [\d.]+, [\d.]+, [\d.]+\)$")
        self.assertEqual(_setting("export_presets.cfg", "storyboard/use_custom_bg_color"), "true")
        self.assertEqual(_setting("export_presets.cfg", "storyboard/custom_bg_color"), cream)

    def test_engine_splash_uses_cover_scale_like_ios_storyboard(self):
        # The engine boot-splash stretch_mode enum is
        # Disabled,Keep,Keep Width,Keep Height,Cover,Ignore  -> Cover == 4.
        # (NOT TextureRect.StretchMode, where Keep Aspect Covered == 6; an out-of-range
        # 6 here silently falls back to Keep, which renders the splash at native size,
        # centered -> the letterboxed "screen shrank with a cream border" launch flash.)
        self.assertEqual(_setting("project.godot", "boot_splash/stretch_mode"), "4")
        # iOS storyboard enum: Same as Logo,Center,Scale to Fit,Scale to Fill,Scale -> Scale to Fill == 3.
        self.assertEqual(_setting("export_presets.cfg", "storyboard/image_scale_mode"), "3")

    def test_no_deprecated_fullsize_overrides_stretch_mode(self):
        # The deprecated boot_splash/fullsize boolean wins over stretch_mode via the
        # engine's back-compat migration: while it is present the explicit stretch_mode
        # is ignored (fullsize=true -> Keep, fullsize=false -> Disabled) -- neither is
        # Cover. It must stay absent so stretch_mode=4 (Cover) is actually honored.
        self.assertFalse(
            _has_setting("project.godot", "boot_splash/fullsize"),
            "boot_splash/fullsize must be removed; its presence forces the splash to "
            "Keep and reintroduces the letterboxed launch flash.",
        )

    def test_composed_launch_image_matches_design_viewport(self):
        self.assertTrue(LAUNCH_FILE.exists(), "%s should exist" % LAUNCH_FILE)
        header = _png_header(LAUNCH_FILE)
        self.assertEqual((header["width"], header["height"]), (1080, 1920))
        self.assertEqual(header["bit_depth"], 8)
        self.assertIn(header["color_type"], (2, 6))

    def test_boot_scene_uses_the_same_composed_launch_frame(self):
        boot = (ROOT / "engine/scripts/scenes/boot.gd").read_text()
        self.assertIn('const LAUNCH_PATH := "%s"' % LAUNCH_RES, boot)
        self.assertNotIn("splash_background.png", boot)
        self.assertNotIn("splash_icon.png", boot)

    def test_engine_splash_is_held_until_boot_scene_can_paint(self):
        self.assertGreaterEqual(
            int(_setting("project.godot", "boot_splash/minimum_display_time")),
            500,
        )


if __name__ == "__main__":
    unittest.main()
