#!/usr/bin/env python3
"""Create the clean Fairy Hollow v3 workbench palette from accepted v2 art.

The v2 directory is an archive and includes rejected, raw, and review artifacts.
This script has an explicit source allow-list so rerunning it can only publish the
accepted source art into the self-contained v3 palette.
"""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageChops, ImageStat


SCRIPT_PATH = Path(__file__).resolve()
V3_ROOT = SCRIPT_PATH.parents[1]
SCENES_ROOT = SCRIPT_PATH.parents[2]
V2_ROOT = SCENES_ROOT / "fairy_hollow_elements_v2"
REPO_ROOT = SCENES_ROOT.parents[5]

SOURCE_CANVAS = (941, 1672)
DELIVERY_CANVAS = (1320, 2346)
TREE_HOUSE_SIZE = (730, 1291)
RESAMPLE = Image.Resampling.LANCZOS
EXACT_HOT_MAGENTA = (255, 0, 255)


def repo_relative(path: Path) -> str:
    return path.relative_to(REPO_ROOT).as_posix()


def exact_hot_magenta_mask(image: Image.Image) -> Image.Image:
    red, green, blue, _alpha = image.convert("RGBA").split()
    key_red, key_green, key_blue = EXACT_HOT_MAGENTA
    red_is_key = red.point(lambda value: 255 if value == key_red else 0)
    green_is_key = green.point(lambda value: 255 if value == key_green else 0)
    blue_is_key = blue.point(lambda value: 255 if value == key_blue else 0)
    return ImageChops.multiply(ImageChops.multiply(red_is_key, green_is_key), blue_is_key)


def dekey_exact_hot_magenta(image: Image.Image) -> Image.Image:
    """Remove only the exact #FF00FF matte, retaining every other violet tone."""
    output = image.convert("RGBA")
    key_mask = exact_hot_magenta_mask(output)
    if key_mask.getbbox() is None:
        return output
    output.paste((0, 0, 0, 0), mask=key_mask)
    return output


def visible_exact_hot_magenta_pixels(image: Image.Image) -> int:
    rgba = image.convert("RGBA")
    visible_alpha = rgba.getchannel("A").point(lambda value: 255 if value else 0)
    visible_key = ImageChops.multiply(exact_hot_magenta_mask(rgba), visible_alpha)
    return int(ImageStat.Stat(visible_key).sum[0] // 255)


def read_rgba(relative_source: str) -> Image.Image:
    path = V2_ROOT / relative_source
    if not path.is_file():
        raise FileNotFoundError(f"Accepted v2 source is missing: {path}")
    return dekey_exact_hot_magenta(Image.open(path))


def save_rgb(source: str, destination: str) -> tuple[int, int]:
    image = read_rgba(source).convert("RGB")
    if image.size != DELIVERY_CANVAS:
        image = image.resize(DELIVERY_CANVAS, RESAMPLE)
    output = V3_ROOT / destination
    output.parent.mkdir(parents=True, exist_ok=True)
    image.save(output)
    return image.size


def save_full_canvas(source: str, destination: str) -> tuple[int, int]:
    image = read_rgba(source)
    if image.size not in (SOURCE_CANVAS, (941, 1671)):
        raise ValueError(f"Expected source canvas for {source}, got {image.size}")
    normalized = Image.new("RGBA", SOURCE_CANVAS)
    normalized.paste(image, (0, 0))
    output = dekey_exact_hot_magenta(normalized.resize(DELIVERY_CANVAS, RESAMPLE))
    path = V3_ROOT / destination
    path.parent.mkdir(parents=True, exist_ok=True)
    output.save(path)
    return output.size


def alpha_crop(image: Image.Image, label: str) -> Image.Image:
    bbox = image.getchannel("A").getbbox()
    if bbox is None:
        raise ValueError(f"Accepted v2 source has no visible pixels: {label}")
    return image.crop(bbox)


def save_registered_crop(source: str, destination: str) -> tuple[int, int]:
    image = read_rgba(source)
    if image.size != DELIVERY_CANVAS:
        raise ValueError(
            f"Expected registered delivery plate for {source}: "
            f"{DELIVERY_CANVAS}, got {image.size}"
        )
    cropped = dekey_exact_hot_magenta(alpha_crop(image, source))
    path = V3_ROOT / destination
    path.parent.mkdir(parents=True, exist_ok=True)
    cropped.save(path)
    return cropped.size


def save_tree_house(source: str, destination: str) -> tuple[int, int]:
    image = read_rgba(source)
    if image.getchannel("A").getbbox() != (0, 0, *image.size):
        raise ValueError("Tree house must remain the complete, tight host-tree asset")
    output = dekey_exact_hot_magenta(image.resize(TREE_HOUSE_SIZE, RESAMPLE))
    path = V3_ROOT / destination
    path.parent.mkdir(parents=True, exist_ok=True)
    output.save(path)
    return output.size


def save_swing_parts(source: str, support_destination: str, seat_destination: str) -> tuple[tuple[int, int], tuple[int, int]]:
    image = read_rgba(source)
    if image.size != SOURCE_CANVAS:
        raise ValueError(f"Expected registered 941 x 1672 swing, got {image.size}")

    support = image.copy()
    support.putalpha(image.getchannel("A"))
    support_alpha = support.getchannel("A")
    support_alpha.paste(0, (0, 250, image.width, image.height))
    support.putalpha(support_alpha)

    seat = image.copy()
    seat_alpha = seat.getchannel("A")
    seat_alpha.paste(0, (0, 0, image.width, 240))
    seat.putalpha(seat_alpha)

    support = dekey_exact_hot_magenta(alpha_crop(support.resize(DELIVERY_CANVAS, RESAMPLE), "moon swing support"))
    seat = dekey_exact_hot_magenta(alpha_crop(seat.resize(DELIVERY_CANVAS, RESAMPLE), "moon swing seat"))
    support_path = V3_ROOT / support_destination
    seat_path = V3_ROOT / seat_destination
    support_path.parent.mkdir(parents=True, exist_ok=True)
    seat_path.parent.mkdir(parents=True, exist_ok=True)
    support.save(support_path)
    seat.save(seat_path)
    return support.size, seat.size


def asset_record(
    asset_id: str,
    category: str,
    final: str,
    source: str,
    source_prompt: str,
    transparent: bool,
    required_size: tuple[int, int],
) -> dict[str, object]:
    return {
        "id": asset_id,
        "category": category,
        "final": repo_relative(V3_ROOT / final),
        "source": repo_relative(V2_ROOT / source),
        "sourcePrompt": repo_relative(V2_ROOT / source_prompt),
        "transparent": transparent,
        "requiredSize": list(required_size),
    }


def assert_clean_transparent_records(records: list[dict[str, object]]) -> None:
    for record in records:
        if not record["transparent"]:
            continue
        final_path = REPO_ROOT / str(record["final"])
        count = visible_exact_hot_magenta_pixels(Image.open(final_path))
        if count:
            raise ValueError(
                f"Visible exact #FF00FF pixels remain in {record['id']}: {count}"
            )


def main() -> None:
    records: list[dict[str, object]] = []

    foundation_final = "01_backdrop/foundation/fairy_hollow_foundation_v3.png"
    size = save_rgb("01_backdrop/fairy_hollow_floor_only_1320x2346.png", foundation_final)
    records.append(asset_record("foundation", "environment", foundation_final, "01_backdrop/fairy_hollow_floor_only_1320x2346.png", "01_backdrop/fairy_hollow_floor_only.prompt.txt", False, size))

    for asset_id, final, source, prompt in (
        ("background_trees", "01_environment/background_trees/fairy_hollow_background_trees_v3.png", "02_layers/background_trees/background_trees_v2_alpha.png", "02_layers/background_trees/background_trees_v2.prompt.txt"),
        ("midground_foliage", "01_environment/midground_foliage/fairy_hollow_midground_foliage_v3.png", "02_layers/midground_foliage/midground_foliage_alpha.png", "02_layers/midground_foliage/midground_foliage.prompt.txt"),
        ("foreground_roots", "05_dressing/foreground_roots/fairy_hollow_foreground_roots_v3.png", "02_layers/foreground_roots/foreground_roots_alpha.png", "02_layers/foreground_roots/foreground_roots.prompt.txt"),
    ):
        size = save_full_canvas(source, final)
        records.append(asset_record(asset_id, "environment" if asset_id != "foreground_roots" else "dressing", final, source, prompt, True, size))

    for asset_id, final, source, prompt, category in (
        ("toadstool_cottage", "03_structures/toadstool_cottage/fairy_hollow_toadstool_cottage_v3.png", "02_layers/toadstool_cottage/toadstool_cottage_registered_1320x2346.png", "02_layers/toadstool_cottage/toadstool_cottage.prompt.txt", "structure"),
        ("wishing_well", "04_garden_items/wishing_well/fairy_hollow_wishing_well_v3.png", "02_layers/wishing_well/wishing_well_registered_1320x2346.png", "02_layers/wishing_well/wishing_well.prompt.txt", "garden_item"),
        ("glowing_mushrooms", "04_garden_items/glowing_mushrooms/fairy_hollow_glowing_mushrooms_v3.png", "02_layers/glowing_mushrooms/glowing_mushrooms_registered_1320x2346.png", "02_layers/glowing_mushrooms/glowing_mushrooms.prompt.txt", "garden_item"),
        ("firefly_lanterns", "04_garden_items/firefly_lanterns/fairy_hollow_firefly_lanterns_v3.png", "02_layers/firefly_lanterns/firefly_lanterns_registered_1320x2346.png", "02_layers/firefly_lanterns/firefly_lanterns.prompt.txt", "garden_item"),
        ("lantern_vines", "05_dressing/lantern_vines/fairy_hollow_lantern_vines_v3.png", "02_layers/lantern_vines/lantern_vines_registered_1320x2346.png", "02_layers/lantern_vines/lantern_vines.prompt.txt", "dressing"),
    ):
        size = save_registered_crop(source, final)
        records.append(asset_record(asset_id, category, final, source, prompt, True, size))

    tree_house_final = "03_structures/tree_house/fairy_hollow_tree_house_v3.png"
    size = save_tree_house("02_layers/tree_house/tree_house_tight_alpha.png", tree_house_final)
    records.append(asset_record("tree_house", "structure", tree_house_final, "02_layers/tree_house/tree_house_tight_alpha.png", "02_layers/tree_house/tree_house.prompt.txt", True, size))

    swing_source = "02_layers/moon_swing/moon_swing_registered_941x1672.png"
    swing_prompt = "02_layers/moon_swing/moon_swing.prompt.txt"
    support_final = "04_garden_items/moon_swing/fairy_hollow_moon_swing_support_v3.png"
    seat_final = "04_garden_items/moon_swing/fairy_hollow_moon_swing_seat_v3.png"
    support_size, seat_size = save_swing_parts(swing_source, support_final, seat_final)
    records.extend((
        asset_record("moon_swing_support", "garden_item", support_final, swing_source, swing_prompt, True, support_size),
        asset_record("moon_swing_seat", "garden_item", seat_final, swing_source, swing_prompt, True, seat_size),
    ))

    for asset_id, final, source in (
        ("ground_tuft_01", "05_dressing/vegetation_pack/ground_tuft_01/fairy_hollow_ground_tuft_01_v3.png", "02_layers/contact_foliage/contact_well_left_registered_1320x2346.png"),
        ("ground_tuft_02", "05_dressing/vegetation_pack/ground_tuft_02/fairy_hollow_ground_tuft_02_v3.png", "02_layers/contact_foliage/contact_lantern_left_registered_1320x2346.png"),
        ("ground_tuft_03", "05_dressing/vegetation_pack/ground_tuft_03/fairy_hollow_ground_tuft_03_v3.png", "02_layers/contact_foliage/contact_well_right_registered_1320x2346.png"),
        ("ground_tuft_04", "05_dressing/vegetation_pack/ground_tuft_04/fairy_hollow_ground_tuft_04_v3.png", "02_layers/contact_foliage/contact_mushrooms_left_registered_1320x2346.png"),
    ):
        size = save_registered_crop(source, final)
        records.append(asset_record(asset_id, "vegetation", final, source, "02_layers/contact_foliage/contact_foliage_prompt.txt", True, size))

    manifest = {
        "schemaVersion": 1,
        "scene": "fairy_hollow_v3",
        "visualAssetSource": "existing_assets",
        "accepted": records,
    }
    manifest_path = V3_ROOT / "metadata/asset_manifest.json"
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
    assert_clean_transparent_records(records)

    print(f"Fairy Hollow v3 intake: {len(records)} accepted assets")
    print("- exact #FF00FF key QC: 0 visible pixels in every transparent accepted asset")
    for record in records:
        print(f"- {record['id']}: {record['requiredSize']}")


if __name__ == "__main__":
    main()
