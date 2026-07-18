from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

from games.grove.tools.extract_meadow_ui_v2 import SOURCE_ROOT, extract_sheet, run


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

        alpha_masks = []
        for name in ("badge_a", "badge_b"):
            result = Image.open(output / f"{name}.png").convert("RGBA")
            self.assertEqual(result.size, (256, 256))
            self.assertEqual(result.getbbox(), (20, 20, 236, 236))
            alpha_masks.append(np.asarray(result)[:, :, 3])
        np.testing.assert_array_equal(alpha_masks[0], alpha_masks[1])

    def test_retained_alpha_edges_are_decontaminated(self):
        image = Image.new("RGB", (48, 48), MAGENTA)
        draw = ImageDraw.Draw(image)
        # Generated sheets can contain a connected pale/magenta fringe around
        # an otherwise valid opaque silhouette. It must not survive as a halo.
        draw.ellipse((9, 9, 38, 38), fill=(235, 232, 234))
        draw.ellipse((11, 11, 36, 36), fill=(225, 205, 220))
        draw.ellipse((13, 13, 34, 34), fill=(63, 109, 125))

        output, _ = self._extract(
            image, 1, 1, [{"name": "slate_icon", "policy": "icon"}]
        )
        rgba = np.asarray(Image.open(output / "slate_icon.png").convert("RGBA"))
        visible = rgba[:, :, 3] > 0
        retained = rgba[:, :, :3][visible].astype(np.int16)

        self.assertFalse(np.any(np.all(retained > 228, axis=1)))
        magenta = (retained[:, 0] > 175) & (retained[:, 2] > 165) & (retained[:, 1] + 15 < np.minimum(retained[:, 0], retained[:, 2]))
        self.assertFalse(np.any(magenta))

    def test_fully_opaque_offwhite_tight_crop_is_preserved(self):
        image = Image.new("RGB", (16, 16), MAGENTA)
        ImageDraw.Draw(image).rectangle((4, 4, 11, 11), fill=(235, 232, 234))

        output, _ = self._extract(
            image, 1, 1, [{"name": "offwhite_surface", "policy": "surface"}]
        )
        rgba = np.asarray(Image.open(output / "offwhite_surface.png").convert("RGBA"))

        self.assertEqual(rgba.shape, (8, 8, 4))
        self.assertTrue(np.all(rgba[:, :, 3] == 255))
        self.assertTrue(np.all(rgba[:, :, :3] == np.array([235, 232, 234])))

    def test_named_control_removes_separable_lower_right_glyph_shadow(self):
        image = Image.new("RGB", (64, 64), MAGENTA)
        draw = ImageDraw.Draw(image)
        draw.ellipse((8, 8, 55, 55), fill=(95, 155, 109))
        # Opaque generated contact shadow offset down/right from the plus.
        draw.rounded_rectangle((29, 20, 39, 48), radius=3, fill=(28, 58, 42))
        draw.rounded_rectangle((20, 29, 48, 39), radius=3, fill=(28, 58, 42))
        draw.rounded_rectangle((25, 16, 35, 44), radius=3, fill=(235, 232, 234))
        draw.rounded_rectangle((16, 25, 44, 35), radius=3, fill=(235, 232, 234))

        output, _ = self._extract(
            image, 1, 1, [{"name": "button_plus", "policy": "icon"}]
        )
        rgba = np.asarray(Image.open(output / "button_plus.png").convert("RGBA"))
        rgb = rgba[:, :, :3].astype(np.int16)
        shadow_distance = np.sqrt(np.sum((rgb - np.array([28, 58, 42])) ** 2, axis=2))

        self.assertFalse(np.any((rgba[:, :, 3] > 0) & (shadow_distance < 18)))
        self.assertEqual(int(rgba[128, 128, 3]), 255)

    def test_semantic_texture_mean_matches_role_and_fiber_is_bounded(self):
        image = Image.new("RGB", (48, 48), MAGENTA)
        pixels = np.zeros((36, 36, 3), dtype=np.uint8)
        yy, xx = np.indices((36, 36))
        variation = ((xx * 7 + yy * 11) % 31) - 15
        pixels[:, :, 0] = np.clip(80 + variation, 0, 255)
        pixels[:, :, 1] = np.clip(145 + variation, 0, 255)
        pixels[:, :, 2] = np.clip(190 + variation, 0, 255)
        image.paste(Image.fromarray(pixels, "RGB"), (6, 6))

        output, _ = self._extract(
            image, 1, 1, [{"name": "texture_sky", "policy": "tile"}]
        )
        rgb = np.asarray(Image.open(output / "texture_sky.png").convert("RGB"), dtype=np.float64)
        target = np.array([0x6F, 0xA9, 0xC0], dtype=np.float64)
        np.testing.assert_allclose(rgb.mean(axis=(0, 1)), target, atol=1.0)
        relative = rgb / target - 1.0
        self.assertLessEqual(float(np.max(np.abs(relative))), 0.041)
        luminance = rgb @ np.array([0.2126, 0.7152, 0.0722])
        self.assertGreater(float(luminance.std() / luminance.mean()), 0.01)

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

    def test_regeneration_removes_stale_named_outputs_and_qc(self):
        scratch = tempfile.TemporaryDirectory()
        self.addCleanup(scratch.cleanup)
        output = Path(scratch.name) / "meadow_v2"
        qc = output / "qc"
        qc.mkdir(parents=True)
        (output / "retired_asset.png").write_bytes(b"stale")
        (qc / "retired_qc.png").write_bytes(b"stale")

        manifest = run(SOURCE_ROOT, output)

        self.assertEqual(manifest["badge_registration"]["visible_bounds"], [20, 20, 236, 236])
        self.assertEqual(manifest["texture_base_rgb"]["texture_sky"], [111, 169, 192])
        self.assertFalse((output / "retired_asset.png").exists())
        self.assertFalse((qc / "retired_qc.png").exists())
        expected_assets = {record["path"] for record in manifest["assets"]}
        actual_assets = {path.name for path in output.glob("*.png")}
        self.assertEqual(actual_assets, expected_assets)
        expected_qc = {
            f"{Path(sheet['source']).stem}_contact.png" for sheet in manifest["sheets"]
        } | {
            f"{record['name']}_3x3_offset.png" for record in manifest["assets"] if record["policy"] == "tile"
        }
        self.assertEqual({path.name for path in qc.glob("*.png")}, expected_qc)

        inspected = ("button_info", "icon_settings", "level_badge_17", "level_badge_18", "level_badge_19", "level_badge_20")
        badge_alpha = None
        for name in inspected:
            rgba = np.asarray(Image.open(output / f"{name}.png").convert("RGBA"))
            alpha = rgba[:, :, 3]
            _, component_count = ndimage.label(alpha > 0)
            self.assertEqual(component_count, 1, name)
            edge = (alpha > 0) & (alpha < 255)
            key_distance = np.sqrt(np.sum((rgba[:, :, :3].astype(np.float64) - np.array(MAGENTA)) ** 2, axis=2))
            self.assertGreater(float(key_distance[edge].min()), 150.0, name)
            if name.startswith("level_badge_"):
                if badge_alpha is None:
                    badge_alpha = alpha
                else:
                    np.testing.assert_array_equal(alpha, badge_alpha, err_msg=name)

        for name in ("button_plus", "button_info", "button_close", "button_confirm"):
            rgba = np.asarray(Image.open(output / f"{name}.png").convert("RGBA"))
            rgb = rgba[:, :, :3].astype(np.float64)
            alpha = rgba[:, :, 3]
            glyph = (rgb[:, :, 0] > 210) & (rgb[:, :, 1] > 185) & (rgb[:, :, 2] > 145) & (alpha > 0)
            body_rgb = np.median(rgb[(alpha > 240) & ~glyph], axis=0)
            lower_right = np.zeros_like(glyph)
            for offset in range(3, 13):
                lower_right[offset:, offset:] |= glyph[:-offset, :-offset]
            body_distance = np.sqrt(np.sum((rgb - body_rgb) ** 2, axis=2))
            broad_shadow = lower_right & ~glyph & (alpha > 0) & (body_distance > 35)
            # A one-pixel crisp cut edge is intentional; the old broad soft
            # lower-right shadow produced 443-652 pixels in this same zone.
            self.assertLess(int(np.count_nonzero(broad_shadow)), 200, name)

        all_badge_alpha = [
            np.asarray(Image.open(output / f"level_badge_{index:02d}.png").convert("RGBA"))[:, :, 3]
            for index in range(1, 26)
        ]
        for index, alpha in enumerate(all_badge_alpha[1:], start=2):
            np.testing.assert_array_equal(alpha, all_badge_alpha[0], err_msg=f"level_badge_{index:02d}")

    def test_failed_regeneration_preserves_last_good_output(self):
        scratch = tempfile.TemporaryDirectory()
        self.addCleanup(scratch.cleanup)
        root = Path(scratch.name)
        source = root / "missing_sources"
        output = root / "meadow_v2"
        output.mkdir()
        marker = output / "last_good.txt"
        marker.write_text("keep", encoding="utf-8")

        with self.assertRaises(FileNotFoundError):
            run(source, output)

        self.assertEqual(marker.read_text(encoding="utf-8"), "keep")

    def test_regeneration_rejects_overlapping_source_and_output_roots(self):
        scratch = tempfile.TemporaryDirectory()
        self.addCleanup(scratch.cleanup)
        source = Path(scratch.name) / "source"
        source.mkdir()

        with self.assertRaisesRegex(ValueError, "must not overlap"):
            run(source, source / "derived")


if __name__ == "__main__":
    unittest.main()
