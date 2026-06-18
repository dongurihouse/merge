#!/usr/bin/env python3
"""Unit tests for the asset-intake runner (pure-stdlib, no godot needed)."""
import sys, unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import intake_apply as ia


class ValidateTests(unittest.TestCase):
    def _ok(self, plan):
        ia.validate_plan(plan)  # raises on bad

    def test_minimal_icon_ok(self):
        self._ok({"source": "_originals/new/a.png", "category": "icon",
                  "outputs": [{"path": "ui/a.png"}], "archive": "_originals/ui/a.png"})

    def test_scene_needs_only_source_and_category(self):
        self._ok({"source": "_originals/new/m.png", "category": "scene"})

    def test_missing_source_rejected(self):
        with self.assertRaises(ia.PlanError):
            self._ok({"category": "icon", "outputs": [{"path": "x"}],
                      "archive": "_originals/x.png"})

    def test_unknown_category_rejected(self):
        with self.assertRaises(ia.PlanError):
            self._ok({"source": "s", "category": "audio",
                      "outputs": [{"path": "x"}], "archive": "a"})

    def test_matte_requires_inner(self):
        with self.assertRaises(ia.PlanError):
            self._ok({"source": "s", "category": "matte",
                      "outputs": [{"path": "x"}], "archive": "a"})

    def test_sheet_output_needs_index(self):
        with self.assertRaises(ia.PlanError):
            self._ok({"source": "s", "category": "sheet",
                      "outputs": [{"path": "x"}], "archive": "a"})

    def test_sheet_output_with_index_ok(self):
        self._ok({"source": "s", "category": "sheet",
                  "outputs": [{"island": 0, "path": "x"}], "archive": "a"})


class ArgTests(unittest.TestCase):
    def test_icon_args_default_size(self):
        self.assertEqual(ia.icon_args("/in.png", "/out.png", {}),
                         ["/in.png", "/out.png"])

    def test_icon_args_square_size(self):
        self.assertEqual(ia.icon_args("/in.png", "/out.png", {"size": 256}),
                         ["/in.png", "/out.png", "256"])

    def test_icon_args_wh_size(self):
        self.assertEqual(ia.icon_args("/in.png", "/out.png", {"size": [300, 400]}),
                         ["/in.png", "/out.png", "300", "400"])

    def test_decor_args_opaque_canvas(self):
        self.assertEqual(
            ia.decor_args("/in.png", "/out.png", {"w": 1024, "h": 1280, "opaque": True}),
            ["/in.png", "/out.png", "1024", "1280", "--opaque"])

    def test_decor_args_bare(self):
        self.assertEqual(ia.decor_args("/in.png", "/out.png", {}),
                         ["/in.png", "/out.png"])

    def test_grid_slice_args(self):
        self.assertEqual(ia.slice_args("grid", "/in.png", "/scratch/s_", {}),
                         ["/in.png", "/scratch/s_"])

    def test_sheet_slice_args_uses_params(self):
        self.assertEqual(
            ia.slice_args("sheet", "/in.png", "/scratch/s_", {"min_area": 400, "pad": 5}),
            ["/in.png", "/scratch/s_", "0.9", "0.1", "400", "5"])

    def test_parse_post_none(self):
        self.assertIsNone(ia.parse_post(None))

    def test_parse_post_icon_size(self):
        self.assertEqual(ia.parse_post("icon:512"), {"size": 512})

    def test_parse_post_icon_wh(self):
        self.assertEqual(ia.parse_post("icon:300x400"), {"size": [300, 400]})

    def test_parse_post_unknown_rejected(self):
        with self.assertRaises(ia.PlanError):
            ia.parse_post("blur:3")


if __name__ == "__main__":
    unittest.main()
