"""Guard for games/grove/tools/mock_targets.json — the JUDGEMENT half of the mock-compare rig.

The rig's whole claim is that every number it prints came off real concept art (see
docs/design/verifying-against-a-mock.md). That claim rests entirely on this JSON being true about the
mock: the face rect really is the element, the `clean` window really is empty ground, the `field`
patches really are flat sky. Every one of those is a human's measurement, and each fails SILENTLY:

  * a `clean` window opened too wide lets a NEIGHBOUR's shadow into the profile, which reads as this
    element's shadow turning back upward (measured — the acorn pill's left side, at 8px)
  * a `field` patch overlapping an element averages the element into the background colour every
    darkening on the sheet is then divided by
  * a mock that is re-exported at a different size silently shifts every rect by a few px

So the rects are checked against the actual PNG on every `make test-config`, not against a memory of
what they were when they were measured.

  PYTHONPATH=. python3 games/grove/tools/tests/test_mock_targets.py
"""

from __future__ import annotations

import json
import unittest
from pathlib import Path

from PIL import Image

from games.grove.tools.mock_profile import FLAT_LIMIT, flat_range

ROOT = Path(__file__).resolve().parents[4]
TARGETS = ROOT / "games/grove/tools/mock_targets.json"
ELEMENTS = ROOT / "games/grove/tools/mock_elements.gd"

# How far a `field` patch must stay clear of EVERY element's face rect on the same mock. Deliberately
# small: a mock rarely GIVES more (there are 24px of sky beside the leftmost nav tab in total), which is
# the whole of rule 7. This catches a patch laid ON an element; the flatness check below is what catches
# one merely close enough for its shadow to bleed in.
FIELD_CLEARANCE = 6


def rect(r):
    x, y, w, h = r
    return x, y, x + w, y + h


def contains(outer, inner):
    ox0, oy0, ox1, oy1 = rect(outer)
    ix0, iy0, ix1, iy1 = rect(inner)
    return ox0 <= ix0 and oy0 <= iy0 and ix1 <= ox1 and iy1 <= oy1


def overlaps(a, b, grow=0):
    ax0, ay0, ax1, ay1 = rect(a)
    bx0, by0, bx1, by1 = rect(b)
    return (ax0 - grow < bx1 and bx0 < ax1 + grow
            and ay0 - grow < by1 and by0 < ay1 + grow)


class MockTargetsTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.reg = json.loads(TARGETS.read_text())
        cls.images = {}

    def image(self, mock_name):
        if mock_name not in self.images:
            png = self.reg["mocks"][mock_name]["png"].replace("res://", "")
            self.images[mock_name] = Image.open(ROOT / png).convert("RGB")
        return self.images[mock_name]

    # Anti-Potemkin: every assertion below is a loop, and an empty registry would pass all of them
    # while reporting a clean rig.
    def test_registry_is_not_empty(self):
        self.assertGreaterEqual(len(self.reg["mocks"]), 1)
        self.assertGreaterEqual(len(self.reg["regions"]), 2)

    def test_every_mock_png_exists_at_its_declared_size(self):
        for name, mock in self.reg["mocks"].items():
            with self.subTest(mock=name):
                self.assertEqual(list(self.image(name).size), list(mock["size"]),
                                 "%s was re-exported at a different size — every rect measured off it "
                                 "has moved" % name)

    def test_every_region_names_a_known_mock_and_element(self):
        names = ELEMENTS.read_text().split("const NAMES := ")[1].split("]")[0]
        known = [t.strip().strip('"') for t in names.strip("[ ").split(",")]
        self.assertGreaterEqual(len(known), 1, "could not parse NAMES out of mock_elements.gd")
        for name, region in self.reg["regions"].items():
            with self.subTest(region=name):
                self.assertIn(region["mock"], self.reg["mocks"])
                self.assertIn(region["element"], known,
                              "no adapter named %r — the run would refuse" % region["element"])

    def test_face_sits_inside_clean_sits_inside_the_canvas(self):
        for name, region in self.reg["regions"].items():
            with self.subTest(region=name):
                canvas = [0, 0] + list(self.image(region["mock"]).size)
                self.assertTrue(contains(region["clean"], region["face"]),
                                "%s: the face rect escapes its own clean window" % name)
                self.assertTrue(contains(canvas, region["clean"]),
                                "%s: the clean window runs off the mock" % name)

    def test_every_encloses_claim_is_true(self):
        """`encloses` buys an exemption from the two guards below, so it has to be earned.

        A region may only claim to enclose a region on the SAME mock whose face is genuinely inside its
        own — i.e. something the mock DREW on this sheet. Without this, `encloses` would be a way to
        wave away a real neighbour standing beside the element, which is the exact failure rule 7 is
        about.
        """
        for name, region in self.reg["regions"].items():
            for inner in region.get("encloses", []):
                with self.subTest(region=name, encloses=inner):
                    self.assertIn(inner, self.reg["regions"], "%s encloses no such region" % name)
                    other = self.reg["regions"][inner]
                    self.assertEqual(other["mock"], region["mock"],
                                     "%s and %s are not even on the same mock" % (name, inner))
                    self.assertTrue(contains(region["face"], other["face"]),
                                    "%s does not actually contain %s — this is a NEIGHBOUR, and the "
                                    "guards it would skip are exactly the ones it needs" % (name, inner))

    def _encloses(self, a, b):
        """Does region `a` draw region `b` on its own sheet (or the other way round)?"""
        return (b in self.reg["regions"][a].get("encloses", [])
                or a in self.reg["regions"][b].get("encloses", []))

    def test_a_clean_window_never_reaches_another_regions_element(self):
        """`clean` is what the crop may take. Reaching a neighbour puts ITS shadow in this profile."""
        for name, region in self.reg["regions"].items():
            for other_name, other in self.reg["regions"].items():
                if other_name == name or other["mock"] != region["mock"]:
                    continue
                if self._encloses(name, other_name):
                    continue    # contents, not a neighbour: a profile stepping OUT never crosses them
                with self.subTest(region=name, neighbour=other_name):
                    self.assertFalse(overlaps(region["clean"], other["face"]),
                                     "%s's clean window reaches %s's face" % (name, other_name))

    def test_field_patches_are_clear_of_every_element_on_that_mock(self):
        for name, region in self.reg["regions"].items():
            faces = [(n, r["face"]) for n, r in self.reg["regions"].items()
                     if r["mock"] == region["mock"]]
            canvas = [0, 0] + list(self.image(region["mock"]).size)
            for i, patch in enumerate(region.get("field", [])):
                with self.subTest(region=name, patch=i):
                    self.assertTrue(contains(canvas, patch), "patch %d runs off the mock" % i)
                    for face_name, face in faces:
                        # an ENCLOSED element's field genuinely is the enclosing sheet's own paper (the
                        # mock's bag well is drawn on its info bar), so that one pair is exempt — and
                        # only in that direction: a patch of the CONTAINER must still stay off its
                        # contents, or it would average an icon into the background.
                        if name in self.reg["regions"][face_name].get("encloses", []):
                            continue
                        self.assertFalse(overlaps(patch, face, FIELD_CLEARANCE),
                                         "patch %d sits within %dpx of %s — it would average that "
                                         "element into the flat field" % (i, FIELD_CLEARANCE, face_name))

    def test_field_patches_are_actually_flat(self):
        """The rule-9 diagnostic, run on the patches themselves: blur, then max-min.

        A patch that reads above FLAT_LIMIT is not field. Its mean becomes the sheet's background AND
        its sigma becomes the noise floor every 'we are done' verdict is measured against.
        """
        for name, region in self.reg["regions"].items():
            img = self.image(region["mock"])
            for i, patch in enumerate(region.get("field", [])):
                with self.subTest(region=name, patch=i):
                    x0, y0, x1, y1 = rect(patch)
                    got = flat_range(img, (x0, y0, x1, y1))
                    self.assertIsNotNone(got, "patch %d is too small to check (needs 7px each way)" % i)
                    self.assertLessEqual(got, FLAT_LIMIT,
                                         "patch %d has a low-frequency range of %.1f — it spans "
                                         "structure, not field" % (i, got))

    def test_the_flatness_check_finds_a_known_positive(self):
        """A checker that has never failed is not a checker (rule 3).

        The nav regions' own field patches pass above; a patch deliberately slid ONTO the leftmost nav
        tab must not.
        """
        img = self.image("meadow_board")
        self.assertGreater(flat_range(img, (24, 1560, 24 + 60, 1560 + 100)), FLAT_LIMIT,
                           "a patch laid over a nav tab read as flat field — the diagnostic is broken")


if __name__ == "__main__":
    unittest.main()
