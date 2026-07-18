#!/usr/bin/env python3
"""Deterministically extract the approved Meadow Sky v2 fixed-grid atlases.

The generated sheets are not trusted as exact integer grids: 1254 does not
divide evenly by five or six.  Cell edges therefore use ``round(i * n / count)``
and connected foreground components are assigned by centroid.  The source art
is archived separately; this tool writes derived named production PNGs and
their metadata manifest under ``assets/ui`` while review montages go under the
export-excluded ``assets/_review`` tree.
"""
from __future__ import annotations

import argparse
import bisect
import json
import shutil
import uuid
from pathlib import Path
from typing import Iterable, Sequence

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage


REPO = Path(__file__).resolve().parents[3]
SOURCE_ROOT = REPO / "games/grove/assets/_originals/ui/meadow_sky_v2"
OUTPUT_ROOT = REPO / "games/grove/assets/ui/meadow_v2"
REVIEW_ROOT = REPO / "games/grove/assets/_review/ui/meadow_v2"
CANVAS = 256
ICON_FILL = 0.84
FLOOD_TOLERANCE = 110.0
BADGE_VISIBLE_SIZE = 216

MEADOW_SKY_TEXTURE_COLORS: dict[str, tuple[int, int, int]] = {
    "texture_cream": (0xF6, 0xEB, 0xDD),
    "texture_sky": (0x6F, 0xA9, 0xC0),
    "texture_meadow": (0xA8, 0xD3, 0xB9),
    "texture_receding_blue": (0x82, 0x96, 0xAF),
    "texture_structural_slate": (0x3F, 0x6D, 0x7D),
    "texture_action_green": (0x5F, 0x9B, 0x6D),
    "texture_coral": (0xD8, 0x78, 0x65),
    "texture_reward_gold": (0xD6, 0xA9, 0x4C),
    "texture_supporting_purple": (0x86, 0x77, 0xA3),
    "texture_ink": (0x24, 0x3B, 0x4B),
    "texture_warm_kraft": (0xDC, 0xC3, 0x9A),
}

LIGHT_GLYPH_CONTROLS = {"button_plus", "button_info", "button_close", "button_confirm"}
DARK_GLYPH_CONTROLS = {"button_back"}
CLEAN_SILHOUETTE_ASSETS = LIGHT_GLYPH_CONTROLS | DARK_GLYPH_CONTROLS | {"icon_settings"}
BADGE_PERIMETER_REPAIR = {f"level_badge_{index:02d}" for index in range(17, 21)}


def _entries(names: Sequence[str], policy: str) -> list[dict[str, str]]:
    return [{"name": name, "policy": policy} for name in names]


ELEMENT_ENTRIES = (
    _entries(("water_drop", "coin", "acorn", "level_badge_base", "reward_token"), "icon")
    + _entries(("nav_home", "nav_board", "nav_maps", "nav_bag", "nav_shop"), "icon")
    + _entries(("button_plus", "button_info", "button_back", "button_close", "button_confirm"), "icon")
    + _entries(("resource_pill", "nav_tab_selected", "board_cell_open", "board_cell_locked", "dialog_panel"), "surface")
    + _entries(("texture_cream", "texture_sky", "texture_meadow", "texture_receding_blue", "texture_structural_slate"), "tile")
)

COMPONENT_ENTRIES = (
    _entries(("title_banner", "nav_tab_inactive", "button_primary", "button_secondary", "button_danger", "card_generic"), "surface")
    + _entries(("board_frame", "board_cell_unlockable"), "surface")
    + _entries(("icon_padlock",), "icon")
    + _entries(("cost_pill", "progress_track", "progress_fill", "notification_pill"), "surface")
    + _entries(("icon_settings", "icon_mail", "icon_vault", "icon_daily", "icon_expedition", "icon_hourglass", "icon_multiplier_crown", "icon_treefall", "danger_chevron"), "icon")
    + _entries(("maps_card_open", "maps_card_locked", "maps_status_pill"), "surface")
    + _entries(("maps_lock_flower", "cell_capacity_reward", "icon_gift", "icon_news"), "icon")
    + _entries(("vault_jar_shell", "vault_acorn_fill", "vault_plate", "shop_product_card"), "surface")
    + _entries(("acorn_pouch",), "icon")
    + _entries(("shop_promo_ribbon",), "surface")
    + _entries(("leaf_sprig",), "icon")
)

BADGE_ENTRIES = _entries(tuple(f"level_badge_{index:02d}" for index in range(1, 26)), "badge")
TEXTURE_ENTRIES = _entries(
    ("texture_action_green", "texture_coral", "texture_reward_gold", "texture_supporting_purple", "texture_ink", "texture_warm_kraft"),
    "tile",
)

SHEETS = (
    ("ui_elements_sprite_sheet_v2.png", 5, 5, ELEMENT_ENTRIES),
    ("level_badge_variations_v2.png", 5, 5, BADGE_ENTRIES),
    ("ui_components_additional_atlas_v2.png", 6, 6, COMPONENT_ENTRIES),
    ("ui_texture_tiles_additional_v2.png", 2, 3, TEXTURE_ENTRIES),
)

DERIVED_SURFACES = (
    ("home_disc_shell", (256, 256)),
    ("home_rect_shell", (291, 298)),
    ("play_disc_shell", (284, 287)),
    ("rush_bottom_hint", (385, 73)),
)


def _grid_edges(extent: int, count: int) -> list[int]:
    return [round(index * extent / count) for index in range(count + 1)]


def _background_and_foreground(rgba: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Return a binary foreground mask and the corner-sampled key color."""
    height, width = rgba.shape[:2]
    sample = max(1, min(16, height // 4, width // 4))
    rgb = rgba[:, :, :3].astype(np.float64)
    corners = np.concatenate(
        (
            rgb[:sample, :sample].reshape(-1, 3),
            rgb[:sample, -sample:].reshape(-1, 3),
            rgb[-sample:, :sample].reshape(-1, 3),
            rgb[-sample:, -sample:].reshape(-1, 3),
        )
    )
    key = np.median(corners, axis=0)
    distance = np.sqrt(np.sum((rgb - key) ** 2, axis=2))
    # Some generated gutters drift mostly in the green channel and can be far
    # from the median in Euclidean RGB while remaining unmistakably magenta.
    # The atlas contract forbids magenta inside assets, so this chroma predicate
    # safely catches those fringes without widening the distance tolerance into
    # the approved purple/blue art colors.
    magenta_chroma = (
        (rgb[:, :, 0] > 160)
        & (rgb[:, :, 2] > 150)
        & ((np.minimum(rgb[:, :, 0], rgb[:, :, 2]) - rgb[:, :, 1]) > 45)
    )
    near_key = (distance <= FLOOD_TOLERANCE) | magenta_chroma | (rgba[:, :, 3] == 0)

    # Identify the key through border-connected flood regions.  Generated atlas
    # openings are also intentionally magenta, so all remaining near-key pockets
    # are removed after the border flood instead of being mistaken for art.
    labels, _ = ndimage.label(near_key)
    border_labels = np.unique(
        np.concatenate((labels[0], labels[-1], labels[:, 0], labels[:, -1]))
    )
    flooded = np.isin(labels, border_labels[border_labels != 0])
    background = flooded | near_key
    foreground = ~background & (rgba[:, :, 3] > 0)
    return foreground, key


def _component_masks(foreground: np.ndarray, rows: int, cols: int) -> tuple[np.ndarray, dict[tuple[int, int], list[int]]]:
    labels, count = ndimage.label(foreground, structure=np.ones((3, 3), dtype=np.uint8))
    height, width = foreground.shape
    y_edges = _grid_edges(height, rows)
    x_edges = _grid_edges(width, cols)
    minimum_area = max(1, foreground.size // 50_000)
    buckets: dict[tuple[int, int], list[int]] = {(row, col): [] for row in range(rows) for col in range(cols)}

    if count:
        areas = ndimage.sum(np.ones_like(labels), labels, range(1, count + 1))
        centers = ndimage.center_of_mass(np.ones_like(labels), labels, range(1, count + 1))
        for label_id, (area, center) in enumerate(zip(areas, centers), start=1):
            if area < minimum_area:
                continue
            center_y, center_x = center
            row = min(rows - 1, max(0, bisect.bisect_right(y_edges, center_y) - 1))
            col = min(cols - 1, max(0, bisect.bisect_right(x_edges, center_x) - 1))
            buckets[(row, col)].append(label_id)
    return labels, buckets


def _crop_component(rgba: np.ndarray, labels: np.ndarray, label_ids: Iterable[int]) -> Image.Image:
    mask = np.isin(labels, list(label_ids))
    ys, xs = np.where(mask)
    if not len(xs):
        raise ValueError("cell contains no foreground component")
    x0, x1 = int(xs.min()), int(xs.max()) + 1
    y0, y1 = int(ys.min()), int(ys.max()) + 1
    cropped = rgba[y0:y1, x0:x1].copy()
    local_mask = mask[y0:y1, x0:x1]
    cropped[:, :, 3] = np.where(local_mask, cropped[:, :, 3], 0)
    # Transparent RGB is always zero.  This prevents discarded key/shadow color
    # from leaking when an engine or image tool samples beyond the alpha edge.
    cropped[~local_mask] = 0
    return _strip_generated_halo(Image.fromarray(cropped, "RGBA"))


def _magenta_spill(rgb: np.ndarray) -> np.ndarray:
    values = rgb.astype(np.int16)
    return (
        (values[:, :, 0] > 175)
        & (values[:, :, 2] > 165)
        & (values[:, :, 1] + 15 < np.minimum(values[:, :, 0], values[:, :, 2]))
    )


def _white_spill(rgb: np.ndarray) -> np.ndarray:
    return np.min(rgb.astype(np.int16), axis=2) > 228


def _contaminated_rgb(rgb: np.ndarray) -> np.ndarray:
    """Identify forbidden chroma-key/white fringe, not warm paper bevels."""
    return _magenta_spill(rgb) | _white_spill(rgb)


def _strip_generated_halo(image: Image.Image) -> Image.Image:
    """Remove generated key/white halo pixels while retaining paper edge color."""
    rgba = np.asarray(image.convert("RGBA")).copy()
    mask = rgba[:, :, 3] > 0
    padded_mask = np.pad(mask, 1, constant_values=False)
    background_labels, _ = ndimage.label(~padded_mask, structure=np.ones((3, 3), dtype=np.uint8))
    border_labels = np.unique(
        np.concatenate((background_labels[0], background_labels[-1], background_labels[:, 0], background_labels[:, -1]))
    )
    exterior = np.isin(background_labels, border_labels[border_labels != 0])[1:-1, 1:-1]
    distance_to_any_background = ndimage.distance_transform_edt(mask)
    distance_to_exterior = ndimage.distance_transform_edt(~exterior)
    magenta_spill = _magenta_spill(rgba[:, :, :3])
    white_spill = _white_spill(rgba[:, :, :3])
    white_has_colored_interior = np.any(mask & ~white_spill)
    contaminated = (magenta_spill & (distance_to_any_background <= 3.0)) & mask
    if white_has_colored_interior:
        contaminated |= (white_spill & (distance_to_exterior <= 3.0)) & mask
    if np.any(contaminated):
        rgba[contaminated] = 0
    alpha = rgba[:, :, 3]
    ys, xs = np.where(alpha > 0)
    if not len(xs):
        return Image.fromarray(rgba, "RGBA")
    return Image.fromarray(rgba[int(ys.min()):int(ys.max()) + 1, int(xs.min()):int(xs.max()) + 1], "RGBA")


def _decontaminate_resampled_edge(image: Image.Image) -> Image.Image:
    """Give antialiased pixels nearest opaque art RGB, preventing color bleed."""
    rgba = np.asarray(image.convert("RGBA")).copy()
    alpha = rgba[:, :, 3]
    visible = alpha > 0
    contaminated = _contaminated_rgb(rgba[:, :, :3]) & visible
    edge = visible & (alpha < 255)
    replace = contaminated | edge
    safe = (alpha == 255) & ~_contaminated_rgb(rgba[:, :, :3])
    if np.any(replace) and np.any(safe):
        nearest = ndimage.distance_transform_edt(~safe, return_distances=False, return_indices=True)
        rgba[replace, :3] = rgba[nearest[0][replace], nearest[1][replace], :3]
    rgba[~visible] = 0
    return Image.fromarray(rgba, "RGBA")


def _largest_component(mask: np.ndarray) -> np.ndarray:
    labels, count = ndimage.label(mask, structure=np.ones((3, 3), dtype=np.uint8))
    if not count:
        return np.zeros_like(mask, dtype=bool)
    areas = np.bincount(labels.ravel())
    areas[0] = 0
    return labels == int(np.argmax(areas))


def _apply_alpha_silhouette(image: Image.Image, alpha: np.ndarray) -> Image.Image:
    """Apply a clean alpha mask and reconstruct its edge from interior RGB."""
    rgba = np.asarray(image.convert("RGBA")).copy()
    visible = alpha > 0
    original_alpha = rgba[:, :, 3]
    key = np.array([255.0, 0.0, 255.0])
    key_distance = np.sqrt(np.sum((rgba[:, :, :3].astype(np.float64) - key) ** 2, axis=2))
    safe = (original_alpha > 240) & visible & (key_distance > 150.0) & ~_contaminated_rgb(rgba[:, :, :3])
    if np.any(visible) and np.any(safe):
        nearest = ndimage.distance_transform_edt(~safe, return_distances=False, return_indices=True)
        replace = visible & ~safe
        rgba[replace, :3] = rgba[nearest[0][replace], nearest[1][replace], :3]
    rgba[:, :, 3] = alpha
    rgba[~visible] = 0
    return Image.fromarray(rgba, "RGBA")


def _clean_named_silhouette(image: Image.Image, name: str) -> Image.Image:
    """Erode generated perimeter bands and rebuild one antialiased component."""
    if name not in CLEAN_SILHOUETTE_ASSETS:
        return image
    rgba = np.asarray(image.convert("RGBA"))
    mask = _largest_component(rgba[:, :, 3] > 128)
    clean = ndimage.binary_erosion(mask, iterations=3)
    clean = _largest_component(clean)
    inside_distance = ndimage.distance_transform_edt(clean)
    alpha = np.where(clean, np.clip(inside_distance / 2.0, 0.0, 1.0) * 255.0, 0.0).astype(np.uint8)
    return _apply_alpha_silhouette(image, alpha)


def _shift_mask(mask: np.ndarray, dy: int, dx: int) -> np.ndarray:
    shifted = np.zeros_like(mask)
    source_y = slice(0, mask.shape[0] - dy) if dy else slice(None)
    source_x = slice(0, mask.shape[1] - dx) if dx else slice(None)
    destination_y = slice(dy, None) if dy else slice(None)
    destination_x = slice(dx, None) if dx else slice(None)
    shifted[destination_y, destination_x] = mask[source_y, source_x]
    return shifted


def _remove_control_glyph_shadow(image: Image.Image, name: str) -> Image.Image:
    """Remove only separable lower-right glyph shadows from named controls."""
    if name not in LIGHT_GLYPH_CONTROLS | DARK_GLYPH_CONTROLS:
        return image
    rgba = np.asarray(image.convert("RGBA")).copy()
    rgb = rgba[:, :, :3].astype(np.int16)
    alpha = rgba[:, :, 3]
    luminance = rgb @ np.array([0.2126, 0.7152, 0.0722])
    if name in LIGHT_GLYPH_CONTROLS:
        glyph = (
            (rgb[:, :, 0] > 210)
            & (rgb[:, :, 1] > 185)
            & (rgb[:, :, 2] > 145)
            & (alpha > 0)
        )
        body_values = luminance[(alpha > 0) & ~glyph]
        if not body_values.size:
            return image
        body_luminance = float(np.median(body_values))
        body_rgb = np.median(rgb[(alpha > 0) & ~glyph], axis=0)
        body_distance = np.sqrt(np.sum((rgb - body_rgb) ** 2, axis=2))
        dark_candidate = (luminance < body_luminance - 8) | (body_distance > 30)
    else:
        blue = (
            (rgb[:, :, 2] > rgb[:, :, 0] + 25)
            & (rgb[:, :, 2] > rgb[:, :, 1] + 8)
            & (alpha > 0)
        )
        blue_values = luminance[blue]
        if not blue_values.size:
            return image
        split = float(np.median(blue_values))
        glyph = blue & (luminance >= split)
        dark_candidate = blue & (luminance < split - 8)

    maximum_offset = max(2, round(min(image.size) * 0.09))
    shadow_zone = np.zeros_like(glyph)
    for dy in range(1, maximum_offset + 1):
        for dx in range(1, maximum_offset + 1):
            shadow_zone |= _shift_mask(glyph, dy, dx)
    shadow = shadow_zone & ~glyph & dark_candidate & (alpha > 0)
    if not np.any(shadow):
        return image

    valid_body = (alpha > 0) & ~glyph & ~shadow & ~dark_candidate
    if not np.any(valid_body):
        return image
    nearest = ndimage.distance_transform_edt(~valid_body, return_distances=False, return_indices=True)
    rgba[shadow, :3] = rgba[nearest[0][shadow], nearest[1][shadow], :3]
    return Image.fromarray(rgba, "RGBA")


def _premultiplied_resize(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    rgba = np.asarray(image.convert("RGBA"), dtype=np.float64)
    alpha = rgba[:, :, 3:4] / 255.0
    premultiplied = np.concatenate((rgba[:, :, :3] * alpha, rgba[:, :, 3:4]), axis=2)
    resized = np.asarray(
        Image.fromarray(np.clip(premultiplied, 0, 255).astype(np.uint8), "RGBA").resize(size, Image.Resampling.LANCZOS),
        dtype=np.float64,
    )
    resized_alpha = resized[:, :, 3:4] / 255.0
    with np.errstate(divide="ignore", invalid="ignore"):
        rgb = np.where(resized_alpha > 0, resized[:, :, :3] / resized_alpha, 0)
    result = np.concatenate((np.clip(rgb, 0, 255), resized[:, :, 3:4]), axis=2).astype(np.uint8)
    result[result[:, :, 3] == 0] = 0
    return _decontaminate_resampled_edge(Image.fromarray(result, "RGBA"))


def _center_on_canvas(image: Image.Image, scale: float) -> Image.Image:
    width, height = image.size
    resized = _premultiplied_resize(image, (max(1, round(width * scale)), max(1, round(height * scale))))
    canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    canvas.alpha_composite(resized, ((CANVAS - resized.width) // 2, (CANVAS - resized.height) // 2))
    return canvas


def _register_badge(image: Image.Image) -> Image.Image:
    """Affine-normalize each tight badge crop to one fixed visible box."""
    registered = _premultiplied_resize(image, (BADGE_VISIBLE_SIZE, BADGE_VISIBLE_SIZE))
    canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    inset = (CANVAS - BADGE_VISIBLE_SIZE) // 2
    canvas.alpha_composite(registered, (inset, inset))
    return canvas


def _canonical_badge_alpha(image: Image.Image) -> np.ndarray:
    """Derive the one shared 216-square star footprint from a clean badge."""
    registered = np.asarray(_register_badge(image).convert("RGBA"))
    mask = _largest_component(registered[:, :, 3] > 128)
    mask = ndimage.binary_erosion(mask, iterations=2)
    ys, xs = np.where(mask)
    if not len(xs):
        raise ValueError("canonical badge contains no clean silhouette")
    tight = Image.fromarray((mask[int(ys.min()):int(ys.max()) + 1, int(xs.min()):int(xs.max()) + 1] * 255).astype(np.uint8), "L")
    normalized = np.asarray(tight.resize((BADGE_VISIBLE_SIZE, BADGE_VISIBLE_SIZE), Image.Resampling.BILINEAR))
    alpha = np.zeros((CANVAS, CANVAS), dtype=np.uint8)
    inset = (CANVAS - BADGE_VISIBLE_SIZE) // 2
    alpha[inset:inset + BADGE_VISIBLE_SIZE, inset:inset + BADGE_VISIBLE_SIZE] = normalized
    return alpha


def _repair_badge_perimeter(image: Image.Image, name: str) -> Image.Image:
    """Replace generator-mottled outer bands with clean neighboring cardstock."""
    if name not in BADGE_PERIMETER_REPAIR:
        return image
    rgba = np.asarray(image.convert("RGBA")).copy()
    mask = rgba[:, :, 3] > 0
    distance = ndimage.distance_transform_edt(mask)
    perimeter = mask & (distance <= 12.0)
    donor_ring = mask & (distance > 12.0) & (distance <= 18.0)
    if not np.any(donor_ring):
        return image
    cardstock = np.rint(np.median(rgba[:, :, :3][donor_ring], axis=0)).astype(np.uint8)
    rgba[perimeter, :3] = cardstock
    rgba[~mask] = 0
    return Image.fromarray(rgba, "RGBA")


def _periodic_tile(image: Image.Image) -> Image.Image:
    # Build one quadrant and mirror it across both axes.  The first and last
    # rows/columns are therefore byte-identical, not merely visually similar.
    # Generated tile bounds carry a narrow antialiased/key-contaminated rim;
    # exclude that non-texture perimeter before it can be mirrored into a seam.
    inset = max(1, round(min(image.size) * 0.04))
    clean = image.crop((inset, inset, image.width - inset, image.height - inset))
    quadrant = clean.convert("RGB").resize((CANVAS // 2, CANVAS // 2), Image.Resampling.LANCZOS)
    top = Image.new("RGB", (CANVAS, CANVAS // 2))
    top.paste(quadrant, (0, 0))
    top.paste(quadrant.transpose(Image.Transpose.FLIP_LEFT_RIGHT), (CANVAS // 2, 0))
    tile = Image.new("RGB", (CANVAS, CANVAS))
    tile.paste(top, (0, 0))
    tile.paste(top.transpose(Image.Transpose.FLIP_TOP_BOTTOM), (0, CANVAS // 2))
    return tile.convert("RGBA")


def _normalize_texture_color(image: Image.Image, target_rgb: tuple[int, int, int]) -> Image.Image:
    """Set the semantic base mean while retaining quiet 2-4% fiber only."""
    rgb = np.asarray(image.convert("RGB"), dtype=np.float64)
    luminance = rgb @ np.array([0.2126, 0.7152, 0.0722])
    centered = luminance - float(luminance.mean())
    scale_reference = float(np.percentile(np.abs(centered), 95))
    if scale_reference > 1e-6:
        fiber = np.clip(centered * (0.03 / scale_reference), -0.04, 0.04)
        fiber -= float(fiber.mean())
        fiber = np.clip(fiber, -0.04, 0.04)
    else:
        fiber = np.zeros_like(luminance)
    target = np.asarray(target_rgb, dtype=np.float64)
    normalized = np.rint(target[None, None, :] * (1.0 + fiber[:, :, None]))
    integer_limit = np.floor(target * 0.04)
    normalized = np.clip(normalized, target - integer_limit, target + integer_limit)
    return Image.fromarray(np.clip(normalized, 0, 255).astype(np.uint8), "RGB").convert("RGBA")


def extract_sheet(
    sheet: str | Path,
    rows: int,
    cols: int,
    entries: Sequence[dict[str, str]],
    output_root: str | Path,
) -> list[dict]:
    """Extract one fixed-grid atlas into named PNGs and return manifest records."""
    if len(entries) != rows * cols:
        raise ValueError(f"expected {rows * cols} entries, got {len(entries)}")
    source = Path(sheet)
    destination = Path(output_root)
    destination.mkdir(parents=True, exist_ok=True)
    rgba = np.asarray(Image.open(source).convert("RGBA"))
    height, width = rgba.shape[:2]
    foreground, key = _background_and_foreground(rgba)
    labels, buckets = _component_masks(foreground, rows, cols)
    x_edges, y_edges = _grid_edges(width, cols), _grid_edges(height, rows)

    crops: list[Image.Image] = []
    for index, entry in enumerate(entries):
        row, col = divmod(index, cols)
        try:
            label_ids = buckets[(row, col)]
            if entry["policy"] == "badge" and label_ids:
                label_ids = [max(label_ids, key=lambda label_id: int(np.count_nonzero(labels == label_id)))]
            crops.append(_crop_component(rgba, labels, label_ids))
        except ValueError as error:
            raise ValueError(f"{source.name} cell {index + 1} ({row}, {col}): {error}") from error

    canonical_badge_alpha = next(
        (_canonical_badge_alpha(image) for image, entry in zip(crops, entries) if entry["policy"] == "badge"),
        None,
    )
    records: list[dict] = []
    for index, (entry, crop) in enumerate(zip(entries, crops)):
        row, col = divmod(index, cols)
        policy = entry["policy"]
        if policy == "icon":
            crop = _remove_control_glyph_shadow(crop, entry["name"])
            result = _center_on_canvas(crop, CANVAS * ICON_FILL / max(crop.size))
            result = _clean_named_silhouette(result, entry["name"])
        elif policy == "badge":
            result = _register_badge(crop)
            if canonical_badge_alpha is not None:
                result = _apply_alpha_silhouette(result, canonical_badge_alpha)
            result = _repair_badge_perimeter(result, entry["name"])
        elif policy == "surface":
            result = crop
        elif policy == "tile":
            result = _periodic_tile(crop)
            target = MEADOW_SKY_TEXTURE_COLORS.get(entry["name"])
            if target is not None:
                result = _normalize_texture_color(result, target)
        else:
            raise ValueError(f"unknown extraction policy: {policy}")

        output = destination / f"{entry['name']}.png"
        result.save(output, optimize=True)
        records.append(
            {
                "name": entry["name"],
                "policy": policy,
                "path": output.name,
                "source_sheet": source.name,
                "source_index": index,
                "row": row,
                "column": col,
                "cell_bounds": [x_edges[col], y_edges[row], x_edges[col + 1], y_edges[row + 1]],
                "width": result.width,
                "height": result.height,
                "key_rgb": [round(value) for value in key],
            }
        )
    return records


def _texture_fill(texture: Image.Image, size: tuple[int, int], mask: Image.Image) -> Image.Image:
    """Repeat an approved periodic paper tile through ``mask`` without gradients."""
    texture = texture.convert("RGBA")
    fill = Image.new("RGBA", size, (0, 0, 0, 0))
    for y in range(0, size[1], texture.height):
        for x in range(0, size[0], texture.width):
            fill.paste(texture, (x, y))
    fill.putalpha(mask)
    return fill


def _shell_mask(size: tuple[int, int], inset: int, shape: str, radius: int = 0) -> Image.Image:
    scale = 4
    mask = Image.new("L", (size[0] * scale, size[1] * scale), 0)
    draw = ImageDraw.Draw(mask)
    box = (
        inset * scale,
        inset * scale,
        (size[0] - 1 - inset) * scale,
        (size[1] - 1 - inset) * scale,
    )
    if shape == "ellipse":
        draw.ellipse(box, fill=255)
    else:
        draw.rounded_rectangle(box, radius=radius * scale, fill=255)
    return mask.resize(size, Image.Resampling.LANCZOS)


def _paper_shell(
    output_root: Path,
    size: tuple[int, int],
    shape: str,
    inner_tile: str,
    radius: int = 0,
) -> Image.Image:
    """Build a shadow-free cut-paper shell from approved periodic Meadow tiles."""
    result = Image.new("RGBA", size, (0, 0, 0, 0))
    layers = (
        (8, "texture_structural_slate.png"),
        (12, "texture_warm_kraft.png"),
        (18, inner_tile),
    )
    for inset, tile_name in layers:
        mask_radius = max(2, radius - inset)
        mask = _shell_mask(size, inset, shape, mask_radius)
        result.alpha_composite(_texture_fill(Image.open(output_root / tile_name), size, mask))
    # Keep transparent RGB zero so the shell can be cut out without a fringe.
    rgba = np.asarray(result).copy()
    rgba[rgba[:, :, 3] == 0] = 0
    return Image.fromarray(rgba, "RGBA")


def _nine_slice_resize(source: Image.Image, size: tuple[int, int], margins: tuple[int, int, int, int]) -> Image.Image:
    """Deterministically resize a surface while preserving authored corner geometry."""
    source = source.convert("RGBA")
    left, top, right, bottom = margins
    target_w, target_h = size
    x_src = (0, left, source.width - right, source.width)
    y_src = (0, top, source.height - bottom, source.height)
    x_dst = (0, left, target_w - right, target_w)
    y_dst = (0, top, target_h - bottom, target_h)
    output = Image.new("RGBA", size, (0, 0, 0, 0))
    for row in range(3):
        for col in range(3):
            crop = source.crop((x_src[col], y_src[row], x_src[col + 1], y_src[row + 1]))
            dst_size = (x_dst[col + 1] - x_dst[col], y_dst[row + 1] - y_dst[row])
            if crop.size != dst_size:
                crop = crop.resize(dst_size, Image.Resampling.LANCZOS)
            output.alpha_composite(crop, (x_dst[col], y_dst[row]))
    rgba = np.asarray(output).copy()
    rgba[rgba[:, :, 3] == 0] = 0
    return Image.fromarray(rgba, "RGBA")


def _derive_consumer_surfaces(output_root: Path) -> list[dict]:
    derived = {
        "home_disc_shell": _paper_shell(output_root, (256, 256), "ellipse", "texture_cream.png"),
        "home_rect_shell": _paper_shell(output_root, (291, 298), "rect", "texture_cream.png", 58),
        "play_disc_shell": _paper_shell(output_root, (284, 287), "ellipse", "texture_action_green.png"),
        "rush_bottom_hint": _nine_slice_resize(
            Image.open(output_root / "button_secondary.png"), (385, 73), (30, 22, 30, 22)
        ),
    }
    records: list[dict] = []
    for name, size in DERIVED_SURFACES:
        image = derived[name]
        if image.size != size:
            raise ValueError(f"derived surface {name} has {image.size}, expected {size}")
        path = output_root / f"{name}.png"
        image.save(path, optimize=True)
        records.append(
            {
                "name": name,
                "policy": "surface",
                "path": path.name,
                "source_sheet": "derived_from_meadow_v2",
                "source_index": -1,
                "row": -1,
                "column": -1,
                "cell_bounds": [0, 0, image.width, image.height],
                "width": image.width,
                "height": image.height,
                "key_rgb": None,
            }
        )
    return records


def _contact_sheet(source_name: str, records: Sequence[dict], output_root: Path, qc_root: Path) -> None:
    columns = 6
    thumb = 112
    label_height = 24
    rows = (len(records) + columns - 1) // columns
    montage = Image.new("RGB", (columns * thumb, rows * (thumb + label_height)), (255, 0, 255))
    draw = ImageDraw.Draw(montage)
    for index, record in enumerate(records):
        row, col = divmod(index, columns)
        image = Image.open(output_root / record["path"]).convert("RGBA")
        image.thumbnail((thumb - 12, thumb - 12), Image.Resampling.LANCZOS)
        x = col * thumb + (thumb - image.width) // 2
        y = row * (thumb + label_height) + (thumb - image.height) // 2
        montage.paste(image, (x, y), image)
        draw.text((col * thumb + 3, row * (thumb + label_height) + thumb + 3), record["name"][:18], fill=(36, 59, 75))
    montage.save(qc_root / f"{Path(source_name).stem}_contact.png", optimize=True)


def _tile_montage(record: dict, output_root: Path, qc_root: Path) -> None:
    tile = Image.open(output_root / record["path"]).convert("RGBA")
    montage = Image.new("RGBA", (tile.width * 3, tile.height * 3))
    for row in range(3):
        for col in range(3):
            montage.paste(tile, (col * tile.width, row * tile.height))
    # Roll by half a tile so both periodic boundaries appear through the center.
    pixels = np.asarray(montage)
    pixels = np.roll(pixels, (tile.height // 2, tile.width // 2), axis=(0, 1))
    Image.fromarray(pixels, "RGBA").save(qc_root / f"{record['name']}_3x3_offset.png", optimize=True)


def run(
    source_root: Path = SOURCE_ROOT,
    output_root: Path = OUTPUT_ROOT,
    review_root: Path = REVIEW_ROOT,
) -> dict:
    source_root = Path(source_root)
    output_root = Path(output_root)
    review_root = Path(review_root)
    source_resolved = source_root.resolve()
    output_resolved = output_root.resolve()
    review_resolved = review_root.resolve()
    roots = (("source", source_resolved), ("output", output_resolved), ("review", review_resolved))
    for first_index, (first_name, first) in enumerate(roots):
        for second_name, second in roots[first_index + 1:]:
            if first == second or first in second.parents or second in first.parents:
                raise ValueError(f"{first_name} and {second_name} roots must not overlap")

    # Validate every archived input before touching the last good derived tree.
    for filename, _, _, _ in SHEETS:
        source = source_root / filename
        if not source.exists():
            raise FileNotFoundError(source)
        with Image.open(source) as image:
            image.verify()

    output_root.parent.mkdir(parents=True, exist_ok=True)
    review_root.parent.mkdir(parents=True, exist_ok=True)
    token = uuid.uuid4().hex
    staging_root = output_root.parent / f".{output_root.name}.tmp-{token}"
    backup_root = output_root.parent / f".{output_root.name}.backup-{token}"
    review_staging = review_root.parent / f".{review_root.name}.tmp-{token}"
    review_backup = review_root.parent / f".{review_root.name}.backup-{token}"
    staging_root.mkdir()
    review_staging.mkdir()
    all_records: list[dict] = []
    sheets_metadata: list[dict] = []
    try:
        for filename, rows, cols, entries in SHEETS:
            source = source_root / filename
            records = extract_sheet(source, rows, cols, entries, staging_root)
            all_records.extend(records)
            sheets_metadata.append({"source": filename, "rows": rows, "columns": cols, "count": len(records)})
            _contact_sheet(filename, records, staging_root, review_staging)
            for record in records:
                if record["policy"] == "tile":
                    _tile_montage(record, staging_root, review_staging)

        all_records.extend(_derive_consumer_surfaces(staging_root))

        manifest = {
            "version": 2,
            "generator": "games/grove/tools/extract_meadow_ui_v2.py",
            "review_output": "games/grove/assets/_review/ui/meadow_v2",
            "grid_boundary": "round(index * extent / count)",
            "badge_registration": {
                "canvas": [CANVAS, CANVAS],
                "visible_bounds": [20, 20, 236, 236],
                "shared_alpha": True,
            },
            "texture_base_rgb": {name: list(rgb) for name, rgb in MEADOW_SKY_TEXTURE_COLORS.items()},
            "sheets": sheets_metadata,
            "assets": all_records,
        }
        (staging_root / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")

        # canonical_mapping.json is hand-authored routing metadata beside the
        # generated manifest. Preserve it across a deterministic asset refresh.
        mapping = output_root / "canonical_mapping.json"
        if mapping.exists():
            shutil.copy2(mapping, staging_root / mapping.name)
        # Godot assigns stable resource UIDs in sidecars. The extractor owns
        # PNG bytes, not those identities, so carry existing sidecars forward
        # for still-present assets rather than forcing a project-wide UID churn.
        if output_root.exists():
            for sidecar in output_root.glob("*.png.import"):
                if (staging_root / sidecar.name.removesuffix(".import")).exists():
                    shutil.copy2(sidecar, staging_root / sidecar.name)
        if review_root.exists():
            for sidecar in review_root.glob("*.png.import"):
                if (review_staging / sidecar.name.removesuffix(".import")).exists():
                    shutil.copy2(sidecar, review_staging / sidecar.name)

        if output_root.exists():
            output_root.rename(backup_root)
        if review_root.exists():
            review_root.rename(review_backup)
        try:
            staging_root.rename(output_root)
            review_staging.rename(review_root)
        except Exception:
            if output_root.exists():
                shutil.rmtree(output_root)
            if review_root.exists():
                shutil.rmtree(review_root)
            if backup_root.exists():
                backup_root.rename(output_root)
            if review_backup.exists():
                review_backup.rename(review_root)
            raise
        if backup_root.exists():
            shutil.rmtree(backup_root)
        if review_backup.exists():
            shutil.rmtree(review_backup)
        return manifest
    finally:
        if staging_root.exists():
            shutil.rmtree(staging_root)
        if review_staging.exists():
            shutil.rmtree(review_staging)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-root", type=Path, default=SOURCE_ROOT)
    parser.add_argument("--output-root", type=Path, default=OUTPUT_ROOT)
    parser.add_argument("--review-root", type=Path, default=REVIEW_ROOT)
    args = parser.parse_args()
    manifest = run(args.source_root, args.output_root, args.review_root)
    print(f"extracted {len(manifest['assets'])} assets from {len(manifest['sheets'])} sheets -> {args.output_root}")


if __name__ == "__main__":
    main()
