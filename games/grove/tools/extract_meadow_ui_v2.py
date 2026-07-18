#!/usr/bin/env python3
"""Deterministically extract the approved Meadow Sky v2 fixed-grid atlases.

The generated sheets are not trusted as exact integer grids: 1254 does not
divide evenly by five or six.  Cell edges therefore use ``round(i * n / count)``
and connected foreground components are assigned by centroid.  The source art
is archived separately; this tool only writes derived, named production PNGs,
their metadata manifest, and review montages.
"""
from __future__ import annotations

import argparse
import bisect
import json
from pathlib import Path
from typing import Iterable, Sequence

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage


REPO = Path(__file__).resolve().parents[3]
SOURCE_ROOT = REPO / "games/grove/assets/_originals/ui/meadow_sky_v2"
OUTPUT_ROOT = REPO / "games/grove/assets/ui/meadow_v2"
QC_ROOT = OUTPUT_ROOT / "qc"
CANVAS = 256
ICON_FILL = 0.84
BADGE_FILL = 0.86
FLOOD_TOLERANCE = 110.0


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
    return Image.fromarray(cropped, "RGBA")


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
    return Image.fromarray(result, "RGBA")


def _center_on_canvas(image: Image.Image, scale: float) -> Image.Image:
    width, height = image.size
    resized = _premultiplied_resize(image, (max(1, round(width * scale)), max(1, round(height * scale))))
    canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    canvas.alpha_composite(resized, ((CANVAS - resized.width) // 2, (CANVAS - resized.height) // 2))
    return canvas


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
            crops.append(_crop_component(rgba, labels, buckets[(row, col)]))
        except ValueError as error:
            raise ValueError(f"{source.name} cell {index + 1} ({row}, {col}): {error}") from error

    badge_maximum = max((max(image.size) for image, entry in zip(crops, entries) if entry["policy"] == "badge"), default=1)
    records: list[dict] = []
    for index, (entry, crop) in enumerate(zip(entries, crops)):
        row, col = divmod(index, cols)
        policy = entry["policy"]
        if policy == "icon":
            result = _center_on_canvas(crop, CANVAS * ICON_FILL / max(crop.size))
        elif policy == "badge":
            result = _center_on_canvas(crop, CANVAS * BADGE_FILL / badge_maximum)
        elif policy == "surface":
            result = crop
        elif policy == "tile":
            result = _periodic_tile(crop)
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


def run(source_root: Path = SOURCE_ROOT, output_root: Path = OUTPUT_ROOT) -> dict:
    output_root.mkdir(parents=True, exist_ok=True)
    qc_root = output_root / "qc"
    qc_root.mkdir(parents=True, exist_ok=True)
    all_records: list[dict] = []
    sheets_metadata: list[dict] = []
    for filename, rows, cols, entries in SHEETS:
        source = source_root / filename
        if not source.exists():
            raise FileNotFoundError(source)
        records = extract_sheet(source, rows, cols, entries, output_root)
        all_records.extend(records)
        sheets_metadata.append({"source": filename, "rows": rows, "columns": cols, "count": len(records)})
        _contact_sheet(filename, records, output_root, qc_root)
        for record in records:
            if record["policy"] == "tile":
                _tile_montage(record, output_root, qc_root)

    manifest = {
        "version": 2,
        "generator": "games/grove/tools/extract_meadow_ui_v2.py",
        "grid_boundary": "round(index * extent / count)",
        "sheets": sheets_metadata,
        "assets": all_records,
    }
    (output_root / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    return manifest


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-root", type=Path, default=SOURCE_ROOT)
    parser.add_argument("--output-root", type=Path, default=OUTPUT_ROOT)
    args = parser.parse_args()
    manifest = run(args.source_root, args.output_root)
    print(f"extracted {len(manifest['assets'])} assets from {len(manifest['sheets'])} sheets -> {args.output_root}")


if __name__ == "__main__":
    main()
