"""Guard for the shop screen's hit-region registry — the file that says WHERE each purchase is.

The shop screen is the approved concept art itself (owner, 2026-07-30: "use the whole image from the
mock"). Nothing on it is drawn by the game, so the only thing standing between a player's finger and
the right purchase is a table of rectangles measured off that picture:

    games/grove/assets/ui/dialogs/shop/storefront_market_stall.regions.json

Every one of those rectangles fails SILENTLY. A picture re-exported at a different size, re-cropped,
or regenerated with the goods a few px over slides every hit box off its art and the screen still
renders perfectly — it just sells the $9.99 pack to a tap on the $19.99 basket. This suite re-measures
the picture on every `make test-config` and checks the registry against it, so that failure is a red
build instead of a support ticket about a charge nobody meant to make.

It checks four different things, because they fail in four different ways:

  1. THE PICTURE IS THE MOCK. The shipped copy is asserted byte-identical to the approved concept
     file. The whole design is "the mock IS the screen"; a shipped copy that has quietly diverged
     from the mock makes every other claim in the registry a claim about a different image.
  2. THE ANCHORS ARE STILL THERE. Each offer's `measured.button` / `measured.tag` must equal what
     measure_shop_screen.py finds today, and the posts, shelf planks, signboard, section plaque and
     column gutters must equal the recorded furniture.
  3. THE RECTS ARE HONEST ABOUT THE ART. Each cell must contain its own tag and its own button;
     each price rect must contain the drawn button and stay inside its own column; and no cell may
     reach across the measured empty gutter into its neighbour's goods.
  4. THE CELLS TILE. No two cells overlap, and the price rects that DO cross a cell seam (the first
     ladder shelf's two buttons hang 24px below their own plank) are exactly the ones the registry
     says do — the game draws those last, on top, which is what keeps them resolving to their own
     offer.

    PYTHONPATH=. python3 games/grove/tools/tests/test_shop_screen_regions.py
"""

from __future__ import annotations

import json
import unittest
from pathlib import Path

import numpy as np

from games.grove.tools.measure_shop_screen import (
    amount_tags, boxes, gutters, load, planks, posts, price_buttons)

ROOT = Path(__file__).resolve().parents[4]
REGISTRY = ROOT / "games/grove/assets/ui/dialogs/shop/storefront_market_stall.regions.json"
SHIPPED = ROOT / "games/grove/assets/ui/dialogs/shop/storefront_market_stall.png"
MOCK = ROOT / ("games/grove/assets/_concepts/dialogs/shop_screen_variations_v1/"
               "shop_screen_a_market_stall.png")

# The four shelf bays, as the y windows the gutter scan runs in. Not a measurement — a window wide
# enough to hold one bay's goods and narrow enough to exclude the next one's, which is what makes the
# gutter INSIDE it the thing being measured.
BAYS = [(370, 846), (955, 1257), (1262, 1571), (1590, 1885)]


def rect(r):
    x, y, w, h = r
    return x, y, x + w, y + h


def contains(outer, inner) -> bool:
    ox0, oy0, ox1, oy1 = rect(outer)
    ix0, iy0, ix1, iy1 = rect(inner)
    return ox0 <= ix0 and oy0 <= iy0 and ox1 >= ix1 and oy1 >= iy1


def overlap(a, b) -> bool:
    ax0, ay0, ax1, ay1 = rect(a)
    bx0, by0, bx1, by1 = rect(b)
    return ax0 < bx1 and bx0 < ax1 and ay0 < by1 and by0 < ay1


class ShopScreenRegions(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.reg = json.loads(REGISTRY.read_text())
        cls.a, cls.m = load(SHIPPED)
        cls.buttons = [list(b) for b in price_buttons(cls.m)]
        cls.tags = [list(t) for t in amount_tags(cls.m)]

    # 1 — the picture is the mock -----------------------------------------------------------------

    def test_the_shipped_picture_is_the_approved_mock_byte_for_byte(self):
        self.assertTrue(MOCK.is_file(), "the approved concept file is gone: %s" % MOCK)
        self.assertEqual(SHIPPED.read_bytes(), MOCK.read_bytes(),
                         "the shipped storefront has diverged from the mock it is supposed to BE — "
                         "re-copy it, or the whole 'use the whole image' design is no longer true")

    def test_the_registry_declares_the_picture_it_measures(self):
        self.assertEqual(self.reg["size"], [self.a.shape[1], self.a.shape[0]],
                         "the registry's declared size is not the picture's — every fraction the game "
                         "derives from it is off by that ratio")
        self.assertEqual(len(self.reg["offers"]), 8, "the picture draws eight offers")

    # 2 — the anchors are still there --------------------------------------------------------------

    def test_every_offer_anchor_is_where_the_registry_says(self):
        self.assertEqual(len(self.buttons), 8, "found %d green price plates, not 8" % len(self.buttons))
        for offer, btn, tag in zip(self.reg["offers"], self.buttons, self.tags):
            self.assertEqual(offer["measured"]["button"], btn,
                             "%s: the green price plate moved" % offer["id"])
            self.assertEqual(offer["measured"]["tag"], tag,
                             "%s: the cream amount tag moved" % offer["id"])

    def test_the_furniture_the_cells_were_derived_from_is_still_there(self):
        f = self.reg["furniture"]
        self.assertEqual([list(p) for p in posts(self.m)], f["posts"], "the stall posts moved")
        gt = gutters(self.m, BAYS)
        self.assertEqual([list(p) for p in planks(self.m, [g["split"] for g in gt])],
                         f["plank_bands"], "the shelf planks moved")
        # the signboard is the biggest slate mass above the first shelf; the section plaque the
        # widest cream sheet between the counter and the first ladder shelf.
        head = self.m["slate"].copy()
        head[400:, :] = False
        self.assertEqual(list(boxes(head, 20000)[0]), f["signboard"], "the hung signboard moved")
        band = self.m["cream"].copy()
        band[:851, :] = False
        band[952:, :] = False
        self.assertEqual(list(boxes(band, 6000)[0]), f["section_plaque"],
                         "the ACORN POUCHES plaque moved")

    def test_the_column_gutters_are_where_the_splits_were_taken_from(self):
        got = gutters(self.m, BAYS)
        want = self.reg["gutters"]
        self.assertEqual(len(got), len(want))
        for g, w in zip(got, want):
            self.assertEqual(g["empty_columns"], w["empty_columns"],
                             "%s: the empty column run between the two offers moved" % w["row"])
            self.assertEqual(g["split"], w["split"], "%s: the split moved" % w["row"])

    # 3 — the rects are honest about the art -------------------------------------------------------

    def test_each_cell_holds_its_own_amount_tag_and_price_button(self):
        for offer, btn, tag in zip(self.reg["offers"], self.buttons, self.tags):
            self.assertTrue(contains(offer["cell"], tag),
                            "%s: the cell does not cover its own amount tag" % offer["id"])
            self.assertTrue(contains(offer["price"], btn),
                            "%s: the price rect does not cover the drawn button" % offer["id"])
            # a price rect may hang below its own cell (see the module note) but never sideways out
            # of its own column, or it would take taps from the offer beside it.
            cx0, _, cx1, _ = rect(offer["cell"])
            px0, _, px1, _ = rect(offer["price"])
            self.assertTrue(cx0 <= px0 and px1 <= cx1,
                            "%s: the price rect leaves its own column" % offer["id"])

    def test_no_cell_reaches_across_its_shelf_gutter(self):
        """A cell must stop inside the measured empty run, not out the other side of it.

        This is the assertion that would have caught a midline split: the bottom shelf's gutter is
        496..509 because the treasure chest starts at 510, so a cell ending at 540 fails here.
        """
        checked = 0
        for i, g in enumerate(self.reg["gutters"]):
            lo, hi = g["empty_columns"]
            # the registry lists the offers in reading order, two to a shelf — which the anchor check
            # above already pinned against the picture's own row grouping.
            pair = self.reg["offers"][i * 2:i * 2 + 2]
            self.assertEqual(len(pair), 2, "%s: expected two offers on this shelf" % g["row"])
            left, right = sorted(pair, key=lambda o: o["cell"][0])
            self.assertTrue(lo <= left["cell"][0] + left["cell"][2] <= hi,
                            "%s: the left cell ends at %d, outside the empty run %s"
                            % (g["row"], left["cell"][0] + left["cell"][2], [lo, hi]))
            self.assertTrue(lo <= right["cell"][0] <= hi,
                            "%s: the right cell starts at %d, outside the empty run %s"
                            % (g["row"], right["cell"][0], [lo, hi]))
            checked += 1
        self.assertEqual(checked, 4, "the gutter check ran on %d shelves, not 4" % checked)

    def test_the_split_check_finds_a_known_positive(self):
        """A checker that has never failed is not a checker.

        The picture's own midline (540) is the split a careless pass would have taken. On the bottom
        shelf it lands outside the measured empty run, which must read as a failure.
        """
        lo, hi = self.reg["gutters"][3]["empty_columns"]
        self.assertFalse(lo <= 540 <= hi,
                         "the bottom shelf's gutter now contains the midline — the guard that "
                         "catches a midline split can no longer fail")

    # 4 — the cells tile ---------------------------------------------------------------------------

    def test_no_two_cells_overlap(self):
        cells = [(o["id"], o["cell"]) for o in self.reg["offers"]]
        for i, (aid, ar) in enumerate(cells):
            for bid, br in cells[i + 1:]:
                self.assertFalse(overlap(ar, br), "the %s and %s cells overlap" % (aid, bid))

    def test_the_close_button_clears_every_offer_and_a_fingertip(self):
        close = self.reg["close"]
        for o in self.reg["offers"]:
            self.assertFalse(overlap(close["rect"], o["cell"]),
                             "the close rect overlaps the %s cell" % o["id"])
            self.assertFalse(overlap(close["rect"], o["price"]),
                             "the close rect overlaps the %s price rect" % o["id"])
        self.assertTrue(contains(close["rect"], close["drawn"]),
                        "the close hit rect does not cover the X the picture draws")
        # 44 CSS px on a 390pt-wide phone is 11.3% of the width; the picture is 1080 wide.
        floor = round(1080 * 44.0 / 390.0)
        self.assertGreaterEqual(close["rect"][2], floor,
                                "the close target is under a fingertip (%d < %d px)"
                                % (close["rect"][2], floor))
        self.assertLess(close["drawn"][2], floor,
                        "the drawn X now clears the fingertip floor on its own — the note explaining "
                        "why the hit rect is opened past the art is stale")

    def test_only_the_first_ladder_shelf_hangs_a_price_over_a_seam(self):
        """The price rects that cross into another offer's cell are exactly the recorded ones.

        They are legal only because the game adds every price rect AFTER every cell, so the picker
        gives them priority. A NEW one appearing means some other button now depends on that
        ordering without anyone having decided it should.
        """
        crossing = []
        for o in self.reg["offers"]:
            for other in self.reg["offers"]:
                if other["id"] != o["id"] and overlap(o["price"], other["cell"]):
                    crossing.append((o["id"], other["id"]))
        self.assertEqual(sorted(crossing),
                         [("cash_0", "cash_2"), ("cash_1", "cash_3"),
                          ("cash_2", "cash_4"), ("cash_3", "cash_5")],
                         "the set of price rects overhanging a neighbouring cell changed: %s"
                         % sorted(crossing))


if __name__ == "__main__":
    unittest.main()
