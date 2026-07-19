#!/usr/bin/env python3
"""Compose and validate the Fairy Hollow v3 Scene Workbench document."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
from collections import Counter
from pathlib import Path
from typing import Any

from PIL import Image, ImageChops, ImageStat


BUNDLE_REL = Path(
    "games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/"
    "fairy_hollow_elements_v3"
)
CANVAS_SIZE = (1320, 2346)
REVIEW_SIZE = (941, 1672)
EXACT_KEY = (255, 0, 255)
EXPECTED_PIPELINE = {
    "mapMode": "scene_mode",
    "visualModel": "layered_raster",
    "runtimeObjectModel": ["separate_props", "foreground_occluders"],
    "collisionModel": "none",
    "visualAssetSource": "existing_assets",
    "engineTarget": "project-native",
}


def find_project_root(start: Path) -> Path:
    for candidate in (start, *start.parents):
        if (candidate / "games/grove").is_dir():
            return candidate
    raise SystemExit("Could not locate project root containing games/grove")


def read_json(path: Path) -> dict[str, Any]:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise SystemExit(f"Could not parse {path}: {error}") from error


def write_json(path: Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def resolve(project_root: Path, value: str) -> Path:
    relative = Path(value)
    if relative.is_absolute():
        raise ValueError(f"repo-relative path must not be absolute: {value}")
    if ".." in relative.parts:
        raise ValueError(f"repo-relative path must not contain parent traversal: {value}")
    root = project_root.resolve()
    resolved = (root / relative).resolve()
    if not resolved.is_relative_to(root):
        raise ValueError(f"repo-relative path resolves outside project root: {value}")
    return resolved


def visible_key_pixels(image: Image.Image) -> int:
    rgba = image.convert("RGBA")
    red, green, blue, alpha = rgba.split()
    red_key = red.point(lambda value: 255 if value == EXACT_KEY[0] else 0)
    green_key = green.point(lambda value: 255 if value == EXACT_KEY[1] else 0)
    blue_key = blue.point(lambda value: 255 if value == EXACT_KEY[2] else 0)
    color_key = ImageChops.multiply(ImageChops.multiply(red_key, green_key), blue_key)
    visible = alpha.point(lambda value: 255 if value else 0)
    mask = ImageChops.multiply(color_key, visible)
    return int(ImageStat.Stat(mask).sum[0] // 255)


def corner_alpha(image: Image.Image) -> list[int]:
    alpha = image.convert("RGBA").getchannel("A")
    return [
        alpha.getpixel((0, 0)),
        alpha.getpixel((alpha.width - 1, 0)),
        alpha.getpixel((0, alpha.height - 1)),
        alpha.getpixel((alpha.width - 1, alpha.height - 1)),
    ]


def sorted_placements(document: dict[str, Any]) -> list[tuple[int, dict[str, Any]]]:
    indexed = list(enumerate(document["placements"]))
    return sorted(indexed, key=lambda pair: (int(pair[1]["z"]), pair[0]))


def authored_render_size(item: dict[str, Any]) -> tuple[int, int]:
    return (
        max(1, round(float(item["w"]))),
        max(1, round(float(item["h"]))),
    )


def manifest_by_final(accepted: list[dict[str, Any]]) -> dict[str, list[dict[str, Any]]]:
    result: dict[str, list[dict[str, Any]]] = {}
    for asset in accepted:
        result.setdefault(str(asset.get("final", "")), []).append(asset)
    return result


def placement_asset(
    item: dict[str, Any],
    assets_by_final: dict[str, list[dict[str, Any]]],
) -> dict[str, Any]:
    image = str(item.get("image", ""))
    candidates = assets_by_final.get(image, [])
    if len(candidates) != 1:
        raise ValueError(
            f"{item.get('id')}: image maps to {len(candidates)} accepted manifest assets: {image}"
        )
    asset = candidates[0]
    declared = item.get("assetId")
    if declared not in (None, "") and str(declared) != str(asset.get("id")):
        raise ValueError(
            f"{item.get('id')}: assetId {declared} does not match derived {asset.get('id')}"
        )
    return asset


def workbench_png_inventory(project_root: Path, bundle_root: Path) -> set[str]:
    inventory: set[str] = set()
    for path in bundle_root.rglob("*.png"):
        relative_to_bundle = path.relative_to(bundle_root)
        top_level = relative_to_bundle.parts[0]
        if top_level.startswith(("00_", "09_")) or top_level == "metadata":
            continue
        if "references" in relative_to_bundle.parts[:-1]:
            continue
        filename = path.name
        if any(token in filename for token in ("_review", "_raw", "montage", "contact")):
            continue
        inventory.add(path.resolve().relative_to(project_root.resolve()).as_posix())
    return inventory


def composition_metrics(document: dict[str, Any]) -> dict[str, Any]:
    placements = document.get("placements", [])
    clusters = sorted({str(item["cluster"]) for item in placements if item.get("cluster")})
    contacts = sorted(
        str(item["id"]) for item in placements if item.get("contact") is True
    )
    full_canvas = sorted(
        str(item["id"])
        for item in placements
        if authored_render_size(item) == CANVAS_SIZE
    )
    return {
        "placementCount": len(placements),
        "clusterCount": len(clusters),
        "contactPlacementCount": len(contacts),
        "clusters": clusters,
        "contactPlacements": contacts,
        "fullCanvasPlacements": full_canvas,
    }


def checkpoint_comparison(document: dict[str, Any]) -> dict[str, bool]:
    checkpoint = document.get("initialCheckpoint", {})
    current = composition_metrics(document)
    return {
        key: current.get(key) == checkpoint.get(key)
        for key in (
            "placementCount",
            "clusterCount",
            "contactPlacementCount",
            "clusters",
            "contactPlacements",
            "fullCanvasPlacements",
        )
    }


def preflight_inputs(
    project_root: Path,
    document: dict[str, Any],
    manifest: dict[str, Any],
) -> list[str]:
    failures: list[str] = []
    for field in (
        "scene",
        "pipeline",
        "canvas",
        "base",
        "initialCheckpoint",
        "structuralRules",
        "placements",
    ):
        if field not in document:
            failures.append(f"placements document is missing {field}")
    if document.get("pipeline") != EXPECTED_PIPELINE:
        failures.append("placements pipeline does not match the required project-native contract")

    def checked_path(label: str, value: str) -> Path | None:
        try:
            path = resolve(project_root, value)
        except ValueError as error:
            failures.append(f"{label}: {error}")
            return None
        if not path.is_file():
            failures.append(f"{label}: missing {value}")
            return None
        return path

    for field in ("id", "image", "z"):
        if field not in document.get("base", {}):
            failures.append(f"placements base is missing {field}")
    base_image = str(document.get("base", {}).get("image", ""))
    if base_image:
        checked_path("placements base image", base_image)
    for field in ("width", "height", "reviewWidth", "reviewHeight"):
        if field not in document.get("canvas", {}):
            failures.append(f"placements canvas is missing {field}")
    for index, item in enumerate(document.get("placements", [])):
        for field in ("id", "category", "image", "x", "y", "w", "h", "z"):
            if field not in item:
                failures.append(f"placement {index} is missing {field}")
        image_value = str(item.get("image", ""))
        if image_value:
            checked_path(f"placement {index} image", image_value)

        try:
            x = float(item["x"])
            y = float(item["y"])
            width = float(item["w"])
            height = float(item["h"])
            int(item["z"])
        except (KeyError, TypeError, ValueError):
            failures.append(f"placement {index} has invalid numeric geometry")
        else:
            if not all(math.isfinite(value) for value in (x, y, width, height)):
                failures.append(f"placement {index} geometry is not finite")
            if width <= 0 or height <= 0:
                failures.append(f"placement {index} has non-positive grabbable geometry")

    for field in ("schemaVersion", "scene", "visualAssetSource", "accepted"):
        if field not in manifest:
            failures.append(f"asset manifest is missing {field}")
    if manifest.get("schemaVersion") != 1:
        failures.append("asset manifest schemaVersion is not 1")
    if manifest.get("scene") != document.get("scene"):
        failures.append("asset manifest scene does not match placements")
    if manifest.get("visualAssetSource") != "existing_assets":
        failures.append("asset manifest visualAssetSource is not existing_assets")
    accepted = manifest.get("accepted")
    if not isinstance(accepted, list):
        failures.append("asset manifest accepted is not a list")
        accepted = []
    checked_images: set[str] = set()
    bundle_root = (project_root / BUNDLE_REL).resolve()
    for index, asset in enumerate(accepted):
        for field in (
            "id",
            "category",
            "final",
            "source",
            "sourcePrompt",
            "transparent",
            "requiredSize",
        ):
            if field not in asset:
                failures.append(f"manifest asset {index} is missing {field}")
        if not isinstance(asset.get("id"), str) or not asset.get("id"):
            failures.append(f"manifest asset {index} has invalid id")
        if not isinstance(asset.get("category"), str) or not asset.get("category"):
            failures.append(f"manifest asset {index} has invalid category")
        if not isinstance(asset.get("transparent"), bool):
            failures.append(f"manifest asset {index} has invalid transparent flag")
        required_size = asset.get("requiredSize")
        if not (
            isinstance(required_size, list)
            and len(required_size) == 2
            and all(isinstance(value, int) and value > 0 for value in required_size)
        ):
            failures.append(f"manifest asset {index} has invalid requiredSize")
        for field in ("final", "source", "sourcePrompt"):
            value = str(asset.get(field, ""))
            if not value:
                failures.append(f"manifest asset {index} has missing {field}: {value}")
            else:
                checked_path(f"manifest asset {index} {field}", value)
        final = str(asset.get("final", ""))
        try:
            final_path = resolve(project_root, final) if final else None
        except ValueError:
            final_path = None
        if final_path and not final_path.is_relative_to(bundle_root):
            failures.append(f"manifest asset {index} final is outside the v3 bundle: {final}")
        if final and final not in checked_images and final_path and final_path.is_file():
            checked_images.add(final)
            try:
                with Image.open(final_path) as image:
                    image.load()
                    if (
                        asset.get("transparent") is True
                        and image.convert("RGBA").getchannel("A").getextrema()[1] == 0
                    ):
                        failures.append(
                            f"manifest asset {index} final is fully transparent: {final}"
                        )
            except OSError as error:
                failures.append(f"manifest asset {index} has unreadable final {final}: {error}")

    assets_by_final = manifest_by_final(accepted)
    for final, records in assets_by_final.items():
        if final and len(records) != 1:
            failures.append(f"manifest final is not unique: {final}")
    for item in document.get("placements", []):
        try:
            placement_asset(item, assets_by_final)
        except ValueError as error:
            failures.append(str(error))

    accepted_finals = {str(asset.get("final", "")) for asset in accepted if asset.get("final")}
    try:
        inventory = workbench_png_inventory(project_root, bundle_root)
    except ValueError as error:
        failures.append(f"Workbench PNG inventory escapes the project root: {error}")
    else:
        extras = sorted(inventory - accepted_finals)
        missing = sorted(accepted_finals - inventory)
        if extras:
            failures.append(f"Workbench PNG inventory has unmanifested files: {extras}")
        if missing:
            failures.append(f"asset manifest finals missing from Workbench inventory: {missing}")
    return failures


def write_preflight_failure(
    validation_path: Path,
    scene: str | None,
    failures: list[str],
) -> None:
    write_json(
        validation_path,
        {
            "schemaVersion": 1,
            "scene": scene,
            "status": "fail",
            "phase": "input_preflight",
            "failures": failures,
        },
    )


def compose(
    project_root: Path,
    document: dict[str, Any],
    manifest: dict[str, Any],
    output_path: Path,
    review_path: Path,
    report_path: Path,
) -> dict[str, Any]:
    canvas = document["canvas"]
    canvas_size = (int(canvas["width"]), int(canvas["height"]))
    review_size = (int(canvas["reviewWidth"]), int(canvas["reviewHeight"]))
    base_path = resolve(project_root, document["base"]["image"])

    with Image.open(base_path) as foundation:
        result = foundation.convert("RGBA")
    if result.size != canvas_size:
        raise ValueError(f"Foundation is {result.size}; expected {canvas_size}")

    render_log: list[dict[str, Any]] = []
    assets_by_final = manifest_by_final(manifest["accepted"])
    for list_index, item in sorted_placements(document):
        asset = placement_asset(item, assets_by_final)
        image_path = resolve(project_root, item["image"])
        with Image.open(image_path) as opened:
            source = opened.convert("RGBA")
        render_size = authored_render_size(item)
        rendered = source
        if source.size != render_size:
            rendered = source.resize(render_size, Image.Resampling.LANCZOS)

        left = round(float(item["x"]) - render_size[0] / 2)
        top = round(float(item["y"]) - render_size[1])
        result.alpha_composite(rendered, dest=(left, top))
        render_log.append(
            {
                "id": item["id"],
                "assetId": asset["id"],
                "category": item["category"],
                "cluster": item.get("cluster"),
                "contact": bool(item.get("contact", False)),
                "z": int(item["z"]),
                "listIndex": list_index,
                "source": item["image"],
                "sourceSha256": sha256(image_path),
                "sourceSize": list(source.size),
                "renderSize": list(render_size),
                "bounds": [left, top, left + render_size[0], top + render_size[1]],
            }
        )

    full = result.convert("RGB")
    review = full.resize(review_size, Image.Resampling.LANCZOS)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    full.save(output_path, format="PNG", compress_level=9)
    review.save(review_path, format="PNG", compress_level=9)

    clusters = sorted({item["cluster"] for item in document["placements"] if item.get("cluster")})
    report = {
        "schemaVersion": 1,
        "scene": document["scene"],
        "status": "rendered",
        "placementAuthority": str(
            (project_root / BUNDLE_REL / "metadata/placements.json").relative_to(project_root)
        ),
        "placementAuthoritySha256": sha256(
            project_root / BUNDLE_REL / "metadata/placements.json"
        ),
        "manifest": str(
            (project_root / BUNDLE_REL / "metadata/asset_manifest.json").relative_to(
                project_root
            )
        ),
        "manifestSha256": sha256(
            project_root / BUNDLE_REL / "metadata/asset_manifest.json"
        ),
        "canvas": list(canvas_size),
        "reviewSize": list(review_size),
        "foundation": {
            "source": document["base"]["image"],
            "sourceSha256": sha256(base_path),
            "z": int(document["base"]["z"]),
        },
        "sortOrder": ["z", "listIndex"],
        "placementCount": len(render_log),
        "clusterCount": len(clusters),
        "clusters": clusters,
        "contactPlacementCount": sum(item["contact"] for item in render_log),
        "categoryCounts": dict(sorted(Counter(item["category"] for item in render_log).items())),
        "initialCheckpoint": document.get("initialCheckpoint", {}),
        "initialCheckpointMatch": checkpoint_comparison(document),
        "placements": render_log,
        "outputs": {
            "full": str(output_path.relative_to(project_root)),
            "fullSha256": sha256(output_path),
            "review": str(review_path.relative_to(project_root)),
            "reviewSha256": sha256(review_path),
        },
    }
    write_json(report_path, report)
    return report


def validate(
    project_root: Path,
    document: dict[str, Any],
    manifest: dict[str, Any],
    output_path: Path,
    review_path: Path,
    reconstruction_report_path: Path,
    validation_path: Path,
) -> dict[str, Any]:
    failures: list[str] = []
    missing_paths: set[str] = set()
    canvas = document.get("canvas", {})
    canvas_size = (int(canvas.get("width", 0)), int(canvas.get("height", 0)))
    review_size = (int(canvas.get("reviewWidth", 0)), int(canvas.get("reviewHeight", 0)))

    if document.get("schemaVersion") != 2.0:
        failures.append(f"placements schemaVersion is {document.get('schemaVersion')}, expected 2.0")
    pipeline = document.get("pipeline")
    pipeline_valid = pipeline == EXPECTED_PIPELINE
    if not pipeline_valid:
        failures.append("placements pipeline does not match the required project-native contract")
    if canvas_size != CANVAS_SIZE or review_size != REVIEW_SIZE:
        failures.append(
            f"canvas/review dimensions are {canvas_size}/{review_size}, "
            f"expected {CANVAS_SIZE}/{REVIEW_SIZE}"
        )
    if canvas.get("anchorConvention") != "center-bottom":
        failures.append("canvas anchorConvention is not center-bottom")
    if canvas.get("coordinateOrigin") != "top-left":
        failures.append("canvas coordinateOrigin is not top-left")

    accepted = manifest.get("accepted", [])
    manifest_ids = [item.get("id") for item in accepted]
    if len(manifest_ids) != len(set(manifest_ids)):
        failures.append("asset manifest ids are not unique")
    manifest_by_id = {str(item["id"]): item for item in accepted if item.get("id")}
    assets_by_final = manifest_by_final(accepted)
    bundle_root = (project_root / BUNDLE_REL).resolve()
    accepted_finals = {str(item["final"]) for item in accepted}
    inventory = workbench_png_inventory(project_root, bundle_root)
    inventory_extras = sorted(inventory - accepted_finals)
    inventory_missing = sorted(accepted_finals - inventory)
    if inventory_extras:
        failures.append(f"Workbench PNG inventory has unmanifested files: {inventory_extras}")
    if inventory_missing:
        failures.append(f"asset manifest finals missing from Workbench inventory: {inventory_missing}")

    asset_checks: list[dict[str, Any]] = []
    asset_key_pixels = 0
    for asset in accepted:
        path_checks: dict[str, bool] = {}
        for field in ("final", "source", "sourcePrompt"):
            value = str(asset.get(field, ""))
            exists = bool(value) and resolve(project_root, value).is_file()
            path_checks[field] = exists
            if not exists:
                missing_paths.add(value or f"{asset.get('id')}:{field}")
                failures.append(f"{asset.get('id')}: missing manifest {field} {value}")

        result: dict[str, Any] = {
            "id": asset.get("id"),
            "paths": path_checks,
            "transparent": bool(asset.get("transparent", False)),
        }
        final_value = str(asset.get("final", ""))
        final_path = resolve(project_root, final_value)
        if final_path.is_file():
            with Image.open(final_path) as image:
                mode = image.mode
                size = image.size
                corners = corner_alpha(image)
                key_pixels = visible_key_pixels(image)
                alpha_extrema = image.convert("RGBA").getchannel("A").getextrema()
            result.update(
                {
                    "mode": mode,
                    "size": list(size),
                    "sha256": sha256(final_path),
                    "cornerAlpha": corners,
                    "allCornersTransparent": corners == [0, 0, 0, 0],
                    "alphaExtrema": list(alpha_extrema),
                    "visibleKeyPixels": key_pixels,
                }
            )
            asset_key_pixels += key_pixels
            expected_mode = "RGBA" if asset.get("transparent") else "RGB"
            if mode != expected_mode:
                failures.append(f"{asset['id']}: mode {mode}, expected {expected_mode}")
            if list(size) != asset.get("requiredSize"):
                failures.append(
                    f"{asset['id']}: size {size}, expected {tuple(asset.get('requiredSize', []))}"
                )
            if key_pixels:
                failures.append(f"{asset['id']}: {key_pixels} visible exact #FF00FF pixels")
            if asset.get("transparent") and alpha_extrema[0] != 0:
                failures.append(f"{asset['id']}: transparent asset has no transparent pixels")
            if asset.get("transparent") and alpha_extrema[1] == 0:
                failures.append(f"{asset['id']}: transparent asset is fully transparent")
            if asset.get("transparent") and size != CANVAS_SIZE and corners != [0, 0, 0, 0]:
                failures.append(f"{asset['id']}: tight asset corners are not transparent")
        asset_checks.append(result)

    base = document.get("base", {})
    base_path_value = str(base.get("image", ""))
    base_path = resolve(project_root, base_path_value)
    foundation_manifest = manifest_by_id.get(str(base.get("id", "")))
    if int(base.get("z", -1)) != 0:
        failures.append("foundation z is not 0")
    if not foundation_manifest or foundation_manifest.get("final") != base_path_value:
        failures.append("foundation path does not match its asset manifest record")
    if not base_path.is_file():
        missing_paths.add(base_path_value)
        failures.append(f"missing foundation {base_path_value}")

    placement_items = document.get("placements", [])
    initial_checkpoint = document.get("initialCheckpoint", {})
    structural_rules = document.get("structuralRules", {})
    placement_ids = [str(item.get("id", "")) for item in placement_items]
    z_values = [int(base.get("z", -1)), *(int(item.get("z", -1)) for item in placement_items)]
    if len(placement_ids) != len(set(placement_ids)):
        failures.append("placement ids are not unique")
    if len(z_values) != len(set(z_values)):
        failures.append("base and placement z values are not unique")

    clusters = {str(item["cluster"]) for item in placement_items if item.get("cluster")}
    contacts = {str(item["id"]) for item in placement_items if item.get("contact") is True}

    full_canvas_ids: set[str] = set()
    placement_checks: list[dict[str, Any]] = []
    for item in placement_items:
        try:
            asset = placement_asset(item, assets_by_final)
        except ValueError as error:
            asset = None
            failures.append(str(error))
        image_value = str(item.get("image", ""))
        image_path = resolve(project_root, image_value)
        render_size = authored_render_size(item)
        center_bottom = (float(item.get("x", 0)), float(item.get("y", 0)))
        render_left = round(center_bottom[0] - render_size[0] / 2)
        render_top = round(center_bottom[1] - render_size[1])
        result = {
            "id": item.get("id"),
            "assetId": asset.get("id") if asset else None,
            "declaredAssetId": item.get("assetId"),
            "exists": image_path.is_file(),
            "renderSize": list(render_size),
            "centerBottom": list(center_bottom),
            "renderBounds": [
                render_left,
                render_top,
                render_left + render_size[0],
                render_top + render_size[1],
            ],
            "grabbableGeometry": render_size[0] > 0 and render_size[1] > 0,
        }
        if not image_path.is_file():
            missing_paths.add(image_value)
            failures.append(f"{item.get('id')}: missing placement image {image_value}")
        else:
            with Image.open(image_path) as image:
                source_size = image.size
            result["sourceSize"] = list(source_size)
        if render_size == CANVAS_SIZE:
            full_canvas_ids.add(str(item.get("id")))
        for bounds_key in ("sourceBounds", "deliveryBounds"):
            if bounds_key not in item:
                continue
            result.setdefault("intakeProvenance", {})[bounds_key] = item[bounds_key]
        placement_checks.append(result)

    tree = next((item for item in placement_items if item.get("id") == "tree_house"), None)
    tree_metadata = structural_rules.get("treeHouse", {})
    tree_check: dict[str, Any] = {"exists": tree is not None, "document": tree_metadata}
    if tree is None:
        failures.append("missing tree_house placement")
    else:
        tree_geometry = (
            float(tree.get("x", -1)),
            float(tree.get("y", -1)),
            int(tree.get("w", 0)),
            int(tree.get("h", 0)),
        )
        tree_right = tree_geometry[0] + tree_geometry[2] / 2
        tree_check.update({"geometry": list(tree_geometry), "rightEdge": tree_right})
        try:
            tree_asset = placement_asset(tree, assets_by_final)
        except ValueError as error:
            tree_asset = None
            failures.append(str(error))
        tree_check["assetId"] = tree_asset.get("id") if tree_asset else None
        if not tree_asset or tree_asset.get("id") != "tree_house":
            failures.append("tree_house placement does not use the complete host-tree asset")
        if tree.get("structuralUnit") != "complete_host_tree_and_carved_dwelling":
            failures.append("tree_house structuralUnit metadata is missing or invalid")
        if tree.get("completeHostTreeAvailable") is not True:
            failures.append("tree_house does not declare completeHostTreeAvailable")
        if tree_metadata.get("placementId") != "tree_house":
            failures.append("structuralRules.treeHouse placementId is invalid")
        if tree_metadata.get("completeHostTreeAvailable") is not True:
            failures.append("structuralRules.treeHouse does not preserve the complete host tree")
        if tree_metadata.get("structuralRule") != "host tree and carved dwelling remain one inseparable asset":
            failures.append("structuralRules.treeHouse structuralRule is invalid")

    output_checks: dict[str, Any] = {}
    output_key_pixels = 0
    for name, path, expected_size in (
        ("full", output_path, CANVAS_SIZE),
        ("review", review_path, REVIEW_SIZE),
    ):
        result: dict[str, Any] = {"exists": path.is_file()}
        if not path.is_file():
            missing_paths.add(str(path.relative_to(project_root)))
            failures.append(f"missing {name} output {path.relative_to(project_root)}")
        else:
            with Image.open(path) as image:
                mode = image.mode
                size = image.size
                key_pixels = visible_key_pixels(image)
            result.update(
                {
                    "mode": mode,
                    "size": list(size),
                    "sha256": sha256(path),
                    "visibleKeyPixels": key_pixels,
                }
            )
            output_key_pixels += key_pixels
            if mode != "RGB":
                failures.append(f"{name} output mode is {mode}, expected RGB")
            if size != expected_size:
                failures.append(f"{name} output size is {size}, expected {expected_size}")
            if key_pixels:
                failures.append(f"{name} output has {key_pixels} visible exact #FF00FF pixels")
        output_checks[name] = result

    reconstruction_check: dict[str, Any] = {"exists": reconstruction_report_path.is_file()}
    if not reconstruction_report_path.is_file():
        missing_paths.add(str(reconstruction_report_path.relative_to(project_root)))
        failures.append("missing reconstruction_report.json")
    else:
        try:
            reconstruction = read_json(reconstruction_report_path)
        except SystemExit as error:
            reconstruction = {}
            reconstruction_check["parseError"] = str(error)
            failures.append(str(error))
        reconstruction_check.update(
            {
                "scene": reconstruction.get("scene"),
                "placementAuthoritySha256": reconstruction.get(
                    "placementAuthoritySha256"
                ),
                "manifestSha256": reconstruction.get("manifestSha256"),
                "placementCount": reconstruction.get("placementCount"),
                "clusterCount": reconstruction.get("clusterCount"),
                "contactPlacementCount": reconstruction.get("contactPlacementCount"),
            }
        )
        if reconstruction.get("scene") != document.get("scene"):
            failures.append("reconstruction report scene does not match placements")
        if reconstruction.get("placementCount") != len(placement_items):
            failures.append("reconstruction report placement count is stale")
        placements_path = project_root / BUNDLE_REL / "metadata/placements.json"
        if reconstruction.get("placementAuthoritySha256") != sha256(placements_path):
            failures.append("reconstruction report placements hash is stale")
        manifest_path = project_root / BUNDLE_REL / "metadata/asset_manifest.json"
        manifest_fresh = reconstruction.get("manifestSha256") == sha256(manifest_path)
        reconstruction_check["manifestFresh"] = manifest_fresh
        if not manifest_fresh:
            failures.append("reconstruction report asset manifest hash is stale")

        reported_foundation = reconstruction.get("foundation", {})
        foundation_fresh = (
            reported_foundation.get("source") == base_path_value
            and base_path.is_file()
            and reported_foundation.get("sourceSha256") == sha256(base_path)
        )
        reconstruction_check["foundationFresh"] = foundation_fresh
        if not foundation_fresh:
            failures.append("reconstruction report foundation source hash is stale")

        current_sources = [
            {
                "id": item["id"],
                "source": item["image"],
                "sourceSha256": sha256(resolve(project_root, item["image"])),
            }
            for _, item in sorted_placements(document)
        ]
        reported_sources = [
            {
                "id": item.get("id"),
                "source": item.get("source"),
                "sourceSha256": item.get("sourceSha256"),
            }
            for item in reconstruction.get("placements", [])
        ]
        sources_fresh = reported_sources == current_sources
        reconstruction_check["orderedPlacementSourcesFresh"] = sources_fresh
        if not sources_fresh:
            failures.append("reconstruction report ordered placement source hashes are stale")
        for output_name, output_path_value in (("full", output_path), ("review", review_path)):
            hash_key = f"{output_name}Sha256"
            reported_hash = reconstruction.get("outputs", {}).get(hash_key)
            if output_path_value.is_file() and reported_hash != sha256(output_path_value):
                failures.append(f"reconstruction report {output_name} hash is stale")

    report = {
        "schemaVersion": 1,
        "scene": document.get("scene"),
        "status": "pass" if not failures else "fail",
        "placementAuthority": str(
            (project_root / BUNDLE_REL / "metadata/placements.json").relative_to(project_root)
        ),
        "placementAuthoritySha256": sha256(
            project_root / BUNDLE_REL / "metadata/placements.json"
        ),
        "manifest": str(
            (project_root / BUNDLE_REL / "metadata/asset_manifest.json").relative_to(project_root)
        ),
        "manifestSha256": sha256(
            project_root / BUNDLE_REL / "metadata/asset_manifest.json"
        ),
        "canvas": list(canvas_size),
        "reviewSize": list(review_size),
        "pipeline": pipeline,
        "pipelineValid": pipeline_valid,
        "acceptedAssetCount": len(accepted),
        "workbenchPngInventory": {
            "count": len(inventory),
            "acceptedFinalCount": len(accepted_finals),
            "extras": inventory_extras,
            "missing": inventory_missing,
            "status": "pass" if not inventory_extras and not inventory_missing else "fail",
        },
        "placementCount": len(placement_items),
        "clusterCount": len(clusters),
        "clusters": sorted(clusters),
        "contactPlacementCount": len(contacts),
        "contactPlacements": sorted(contacts),
        "missingAssetCount": len(missing_paths),
        "missingAssets": sorted(missing_paths),
        "uniqueIds": len(placement_ids) == len(set(placement_ids)),
        "uniqueZValues": len(z_values) == len(set(z_values)),
        "fullCanvasPlacementCount": len(full_canvas_ids),
        "fullCanvasPlacements": sorted(full_canvas_ids),
        "initialCheckpoint": initial_checkpoint,
        "initialCheckpointMatch": checkpoint_comparison(document),
        "visibleKeyPixels": asset_key_pixels + output_key_pixels,
        "assetVisibleKeyPixels": asset_key_pixels,
        "outputVisibleKeyPixels": output_key_pixels,
        "transparentCornerPolicy": (
            "All transparent tight assets must have four zero-alpha corners; "
            "full-canvas transparent layers record corners but may intentionally touch canvas edges."
        ),
        "assetChecks": asset_checks,
        "placementChecks": placement_checks,
        "treeHouseCheck": tree_check,
        "outputChecks": output_checks,
        "reconstructionReportCheck": reconstruction_check,
        "failures": failures,
        "manualVisualChecks": [
            "split moon swing support sits behind the environment while its moon seat remains in front",
            "complete host tree and carved dwelling remain available as one inseparable asset",
            "cottage, well, mushrooms, and lantern clusters preserve readable silhouettes",
            "contact dressing grounds its associated props",
            "foreground roots finish the depth stack without obscuring the hero composition",
            "scene contains no visible hot-magenta chroma key, UI, text, or border",
        ],
    }
    write_json(validation_path, report)
    return report


def main() -> None:
    script_path = Path(__file__).resolve()
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project-root", type=Path)
    parser.add_argument("--validate-only", action="store_true")
    args = parser.parse_args()

    project_root = (args.project_root or find_project_root(script_path.parent)).resolve()
    bundle_root = project_root / BUNDLE_REL
    placements_path = bundle_root / "metadata/placements.json"
    manifest_path = bundle_root / "metadata/asset_manifest.json"
    output_path = bundle_root / "09_reconstruction/fairy_hollow_reconstruction_v3_1320x2346.png"
    review_path = bundle_root / "09_reconstruction/fairy_hollow_reconstruction_v3_review_941x1672.png"
    reconstruction_report_path = bundle_root / "09_reconstruction/reconstruction_report.json"
    validation_path = bundle_root / "metadata/validation_report.json"

    try:
        document = read_json(placements_path)
        manifest = read_json(manifest_path)
    except SystemExit as error:
        failures = [str(error)]
        write_preflight_failure(validation_path, None, failures)
        print(json.dumps({"status": "fail", "failures": failures}, indent=2))
        raise SystemExit(1) from error

    preflight_failures = preflight_inputs(project_root, document, manifest)
    if preflight_failures:
        write_preflight_failure(
            validation_path,
            document.get("scene"),
            preflight_failures,
        )
        print(
            json.dumps(
                {"status": "fail", "failures": preflight_failures},
                indent=2,
            )
        )
        raise SystemExit(1)

    if not args.validate_only:
        try:
            compose(
                project_root,
                document,
                manifest,
                output_path,
                review_path,
                reconstruction_report_path,
            )
        except (KeyError, OSError, TypeError, ValueError) as error:
            failures = [f"composition failed: {error}"]
            write_preflight_failure(validation_path, document.get("scene"), failures)
            print(json.dumps({"status": "fail", "failures": failures}, indent=2))
            raise SystemExit(1) from error

    report = validate(
        project_root,
        document,
        manifest,
        output_path,
        review_path,
        reconstruction_report_path,
        validation_path,
    )
    print(
        json.dumps(
            {
                "status": report["status"],
                "placements": report["placementCount"],
                "clusters": report["clusterCount"],
                "contacts": report["contactPlacementCount"],
                "missingAssets": report["missingAssetCount"],
                "visibleKeyPixels": report["visibleKeyPixels"],
                "fullSize": report["outputChecks"]["full"].get("size"),
                "reviewSize": report["outputChecks"]["review"].get("size"),
                "failures": report["failures"],
            },
            indent=2,
        )
    )
    if report["failures"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
