from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

from games.grove.tools.extract_meadow_ui_v2 import extract_sheet


MAGENTA = (255, 0, 255)


class MeadowUiV2ExtractorTests(unittest.TestCase):
    def _extract(self, image: Image.Image, rows: int, cols: int, entries: list[dict]):
        scratch = tempfile.TemporaryDirectory()
        self.addCleanup(scratch.cleanup)
        source = Path(scratch.name) / "source.png"
        output = Path(scratch.name) / "out"
        image.save(source)
        records = extract_sheet(source, rows, cols, entries, output)
        return output, records

    def test_fractional_grid_boundaries_use_rounded_cell_edges(self):
        image = Image.new("RGB", (11, 7), MAGENTA)
        draw = ImageDraw.Draw(image)
        # round(i * 11 / 3) -> [0, 4, 7, 11]. These one-pixel marks sit
        # at the first x coordinate of each fractional-width cell.
        for x, color in [(1, (240, 30, 30)), (4, (30, 240, 30)), (7, (30, 30, 240))]:
            draw.point((x, 3), fill=color)

        output, records = self._extract(
            image,
            1,
            3,
            [{"name": name, "policy": "surface"} for name in ("left", "middle", "right")],
        )

        self.assertEqual([record["cell_bounds"] for record in records], [[0, 0, 4, 7], [4, 0, 7, 7], [7, 0, 11, 7]])
        self.assertEqual(Image.open(output / "middle.png").getbbox(), (0, 0, 1, 1))

    def test_noisy_magenta_is_removed_by_corner_sampled_flood(self):
        rng = np.random.default_rng(7)
        pixels = np.zeros((48, 48, 3), dtype=np.uint8)
        pixels[:, :, 0] = rng.integers(228, 256, size=(48, 48), dtype=np.uint8)
        pixels[:, :, 1] = rng.integers(0, 32, size=(48, 48), dtype=np.uint8)
        pixels[:, :, 2] = rng.integers(220, 256, size=(48, 48), dtype=np.uint8)
        pixels[17:31, 18:30] = (95, 155, 109)

        output, _ = self._extract(
            Image.fromarray(pixels, "RGB"), 1, 1, [{"name": "leaf", "policy": "surface"}]
        )
        result = np.asarray(Image.open(output / "leaf.png").convert("RGBA"))

        self.assertGreater(np.count_nonzero(result[:, :, 3]), 100)
        self.assertTrue(np.all(result[result[:, :, 3] == 0, :3] == 0))

    def test_row_major_names_preserve_source_identity(self):
        image = Image.new("RGB", (40, 40), MAGENTA)
        draw = ImageDraw.Draw(image)
        colors = [(214, 169, 76), (111, 169, 192), (168, 211, 185), (216, 120, 101)]
        for index, color in enumerate(colors):
            row, col = divmod(index, 2)
            draw.rectangle((col * 20 + 6, row * 20 + 6, col * 20 + 13, row * 20 + 13), fill=color)

        names = ["gold", "sky", "meadow", "coral"]
        output, records = self._extract(
            image, 2, 2, [{"name": name, "policy": "surface"} for name in names]
        )

        self.assertEqual([record["name"] for record in records], names)
        for name, color in zip(names, colors):
            rgba = np.asarray(Image.open(output / f"{name}.png").convert("RGBA"))
            opaque = rgba[rgba[:, :, 3] == 255, :3]
            self.assertTrue(np.any(np.all(opaque == color, axis=1)), name)

    def test_badges_share_canvas_and_center_registration(self):
        image = Image.new("RGB", (80, 40), MAGENTA)
        draw = ImageDraw.Draw(image)
        draw.rectangle((9, 8, 29, 32), fill=(214, 169, 76))
        draw.rectangle((52, 12, 66, 28), fill=(214, 169, 76))

        output, _ = self._extract(
            image,
            1,
            2,
            [{"name": "badge_a", "policy": "badge"}, {"name": "badge_b", "policy": "badge"}],
        )

        for name in ("badge_a", "badge_b"):
            result = Image.open(output / f"{name}.png").convert("RGBA")
            self.assertEqual(result.size, (256, 256))
            alpha = np.asarray(result)[:, :, 3]
            ys, xs = np.where(alpha > 0)
            self.assertLessEqual(abs((xs.min() + xs.max()) / 2 - 127.5), 0.5)
            self.assertLessEqual(abs((ys.min() + ys.max()) / 2 - 127.5), 0.5)

    def test_transparent_pixels_contain_no_baked_shadow_color(self):
        image = Image.new("RGB", (32, 32), MAGENTA)
        ImageDraw.Draw(image).ellipse((8, 7, 23, 24), fill=(63, 109, 125))

        output, _ = self._extract(
            image, 1, 1, [{"name": "icon", "policy": "icon"}]
        )
        rgba = np.asarray(Image.open(output / "icon.png").convert("RGBA"))

        self.assertTrue(np.all(rgba[rgba[:, :, 3] == 0] == 0))

    def test_periodic_tile_has_exact_first_last_edges(self):
        image = Image.new("RGB", (36, 36), MAGENTA)
        # Generated key backgrounds sometimes have a high-green fringe whose
        # Euclidean distance from the sampled corner exceeds the flood cutoff.
        # It is still unmistakably magenta chroma and must not enter the tile.
        ImageDraw.Draw(image).rectangle((5, 5, 30, 30), fill=(245, 130, 245))
        tile = np.zeros((24, 24, 3), dtype=np.uint8)
        yy, xx = np.indices((24, 24))
        tile[:, :, 0] = 80 + xx * 2
        tile[:, :, 1] = 120 + yy * 2
        tile[:, :, 2] = 90 + ((xx + yy) % 7)
        image.paste(Image.fromarray(tile, "RGB"), (6, 6))

        output, _ = self._extract(
            image, 1, 1, [{"name": "paper", "policy": "tile"}]
        )
        pixels = np.asarray(Image.open(output / "paper.png").convert("RGBA"))

        self.assertEqual((256, 256, 4), pixels.shape)
        self.assertTrue(np.all(pixels[:, :, 3] == 255))
        np.testing.assert_array_equal(pixels[0, :, :], pixels[-1, :, :])
        np.testing.assert_array_equal(pixels[:, 0, :], pixels[:, -1, :])
        magenta_fringe = (pixels[:, :, 0] > 200) & (pixels[:, :, 2] > 200) & (pixels[:, :, 1] < 160)
        self.assertFalse(np.any(magenta_fringe))


if __name__ == "__main__":
    unittest.main()
