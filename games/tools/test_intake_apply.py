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


if __name__ == "__main__":
    unittest.main()
