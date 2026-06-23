#!/usr/bin/env python3
"""Unit tests for the asset-intake runner (pure-stdlib, no godot needed)."""
import shutil
import sys
import tempfile
import unittest
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

    def test_icon_args_bottom_anchor_flag(self):
        self.assertEqual(
            ia.icon_args("/in.png", "/out.png", {"size": 512, "anchor": "bottom"}),
            ["/in.png", "/out.png", "512", "--bottom"])

    def test_icon_args_wh_bottom_anchor_flag(self):
        self.assertEqual(
            ia.icon_args("/in.png", "/out.png", {"size": [300, 400], "anchor": "bottom"}),
            ["/in.png", "/out.png", "300", "400", "--bottom"])

    def test_icon_args_center_anchor_omits_flag(self):
        self.assertEqual(
            ia.icon_args("/in.png", "/out.png", {"size": 512, "anchor": "center"}),
            ["/in.png", "/out.png", "512"])

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

    def test_parse_post_icon_no_size_cleans_to_default(self):
        # 'icon' / 'icon:' = clean to a square icon at process_icon's default size.
        self.assertEqual(ia.parse_post("icon"), {})
        self.assertEqual(ia.parse_post("icon:"), {})

    def test_parse_post_unknown_rejected(self):
        with self.assertRaises(ia.PlanError):
            ia.parse_post("blur:3")

    def test_parse_post_icon_size_bottom(self):
        self.assertEqual(ia.parse_post("icon:512:bottom"),
                         {"size": 512, "anchor": "bottom"})

    def test_parse_post_icon_wh_bottom(self):
        self.assertEqual(ia.parse_post("icon:300x400:bottom"),
                         {"size": [300, 400], "anchor": "bottom"})

    def test_parse_post_icon_bottom_no_size(self):
        # 'icon::bottom' = clean to default size, bottom-anchored.
        self.assertEqual(ia.parse_post("icon::bottom"), {"anchor": "bottom"})

    def test_parse_post_unknown_anchor_rejected(self):
        with self.assertRaises(ia.PlanError):
            ia.parse_post("icon:512:top")

    def test_matte_bright_uses_cutout_bg(self):
        tool, args = ia.matte_tool_and_args("/k.png", {"min_area": 800})
        self.assertEqual(tool, ia.TOOLS["matte"])
        self.assertEqual(args, ["/k.png", "min=800"])

    def test_matte_chroma_uses_chroma_key(self):
        tool, args = ia.matte_tool_and_args("/k.png", {"key": "#41C7F2", "tol": 0.2})
        self.assertEqual(tool, ia.CHROMA_TOOL)
        self.assertEqual(args, ["/k.png", "key=#41C7F2", "tol=0.2"])

    def test_matte_chroma_default_tol(self):
        tool, args = ia.matte_tool_and_args("/k.png", {"key": "#41C7F2"})
        self.assertEqual(tool, ia.CHROMA_TOOL)
        self.assertEqual(args, ["/k.png", "key=#41C7F2", "tol=0.18"])


class FileMoveTests(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def test_archive_raw_moves_and_makes_parent(self):
        root = self.tmp
        (root / "_originals" / "new").mkdir(parents=True)
        src = root / "_originals" / "new" / "a.png"
        src.write_bytes(b"PNG")
        ia.archive_raw("_originals/new/a.png", "_originals/ui/a.png", root=root)
        self.assertFalse(src.exists())
        self.assertEqual((root / "_originals" / "ui" / "a.png").read_bytes(), b"PNG")

    def test_log_plan_moves_into_processed(self):
        plan = self.tmp / "a.plan.json"
        plan.write_text("{}")
        processed = self.tmp / "_processed"
        ia.log_plan(plan, processed=processed)
        self.assertFalse(plan.exists())
        self.assertTrue((processed / "a.plan.json").exists())


if __name__ == "__main__":
    unittest.main()
