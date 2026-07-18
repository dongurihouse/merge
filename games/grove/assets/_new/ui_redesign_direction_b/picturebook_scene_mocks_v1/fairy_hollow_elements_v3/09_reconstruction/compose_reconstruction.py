#!/usr/bin/env python3
"""Compose and validate the Fairy Hollow v3 Scene Workbench document."""

from __future__ import annotations

import argparse
import hashlib
import json
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
    return project_root / Path(value)


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


def preflight_inputs(
    project_root: Path,
    document: dict[str, Any],
    manifest: dict[str, Any],
) -> list[str]:
    failures: list[str] = []
    for field in ("scene", "canvas", "base", "compositionChecks", "placements"):
        if field not in document:
            failures.append(f"placements document is missing {field}")
    for field in ("id", "image", "z"):
        if field not in document.get("base", {}):
            failures.append(f"placements base is missing {field}")
    for field in ("width", "height", "reviewWidth", "reviewHeight"):
        if field not in document.get("canvas", {}):
            failures.append(f"placements canvas is missing {field}")
    for index, item in enumerate(document.get("placements", [])):
        for field in ("id", "assetId", "category", "image", "x", "y", "w", "h", "z"):
            if field not in item:
                failures.append(f"placement {index} is missing {field}")

    accepted = manifest.get("accepted")
    if not isinstance(accepted, list):
        failures.append("asset manifest accepted is not a list")
        accepted = []
    checked_images: set[str] = set()
    for index, asset in enumerate(accepted):
        for field in ("id", "final", "source", "sourcePrompt", "transparent", "requiredSize"):
            if field not in asset:
                failures.append(f"manifest asset {index} is missing {field}")
        for field in ("final", "source", "sourcePrompt"):
            value = str(asset.get(field, ""))
            if not value or not resolve(project_root, value).is_file():
                failures.append(f"manifest asset {index} has missing {field}: {value}")
        final = str(asset.get("final", ""))
        if final and final not in checked_images and resolve(project_root, final).is_file():
            checked_images.add(final)
            try:
                with Image.open(resolve(project_root, final)) as image:
                    image.load()
            except OSError as error:
                failures.append(f"manifest asset {index} has unreadable final {final}: {error}")
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
    for list_index, item in sorted_placements(document):
        image_path = resolve(project_root, item["image"])
        with Image.open(image_path) as opened:
            source = opened.convert("RGBA")
        render_size = (int(item["w"]), int(item["h"]))
        rendered = source
        if source.size != render_size:
            rendered = source.resize(render_size, Image.Resampling.LANCZOS)

        left = round(float(item["x"]) - render_size[0] / 2)
        top = round(float(item["y"]) - render_size[1])
        result.alpha_composite(rendered, dest=(left, top))
        render_log.append(
            {
                "id": item["id"],
                "assetId": item["assetId"],
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
    composition_checks = document.get("compositionChecks", {})
    expected_placement_count = int(composition_checks.get("expectedPlacementCount", -1))
    expected_cluster_count = int(composition_checks.get("expectedClusterCount", -1))
    expected_contact_count = int(
        composition_checks.get("expectedContactPlacementCount", -1)
    )
    expected_clusters = set(composition_checks.get("expectedClusters", []))
    expected_contacts = set(composition_checks.get("expectedContactPlacements", []))
    expected_full_canvas = set(
        composition_checks.get("expectedFullCanvasPlacements", [])
    )
    placement_ids = [str(item.get("id", "")) for item in placement_items]
    z_values = [int(base.get("z", -1)), *(int(item.get("z", -1)) for item in placement_items)]
    if len(placement_ids) != len(set(placement_ids)):
        failures.append("placement ids are not unique")
    if len(z_values) != len(set(z_values)):
        failures.append("base and placement z values are not unique")
    if len(placement_items) != expected_placement_count:
        failures.append(
            f"placement count is {len(placement_items)}, expected {expected_placement_count}"
        )

    clusters = {str(item["cluster"]) for item in placement_items if item.get("cluster")}
    contacts = {str(item["id"]) for item in placement_items if item.get("contact") is True}
    if len(clusters) != expected_cluster_count or clusters != expected_clusters:
        failures.append(f"clusters are {sorted(clusters)}, expected {sorted(expected_clusters)}")
    if len(contacts) != expected_contact_count or contacts != expected_contacts:
        failures.append(
            f"contact placements are {sorted(contacts)}, expected {sorted(expected_contacts)}"
        )

    full_canvas_ids: set[str] = set()
    placement_checks: list[dict[str, Any]] = []
    for item in placement_items:
        asset_id = str(item.get("assetId", ""))
        asset = manifest_by_id.get(asset_id)
        image_value = str(item.get("image", ""))
        image_path = resolve(project_root, image_value)
        render_size = (int(item.get("w", 0)), int(item.get("h", 0)))
        result = {
            "id": item.get("id"),
            "assetId": asset_id,
            "exists": image_path.is_file(),
            "renderSize": list(render_size),
            "centerBottom": [item.get("x"), item.get("y")],
        }
        if not asset:
            failures.append(f"{item.get('id')}: unknown assetId {asset_id}")
        elif asset.get("final") != image_value:
            failures.append(f"{item.get('id')}: placement path does not match assetId {asset_id}")
        if not image_path.is_file():
            missing_paths.add(image_value)
            failures.append(f"{item.get('id')}: missing placement image {image_value}")
        else:
            with Image.open(image_path) as image:
                source_size = image.size
            result["sourceSize"] = list(source_size)
            if source_size != render_size:
                failures.append(
                    f"{item.get('id')}: render size {render_size} is not native {source_size}"
                )
        if render_size == CANVAS_SIZE:
            full_canvas_ids.add(str(item.get("id")))
            if (
                float(item.get("x", -1)) != 660
                or float(item.get("y", -1)) != 2346
                or item.get("cluster") is not None
            ):
                failures.append(f"{item.get('id')}: invalid full-canvas placement metadata")
        for bounds_key in ("sourceBounds", "deliveryBounds"):
            if bounds_key not in item:
                continue
            left, top, right, bottom = (float(value) for value in item[bounds_key])
            expected_x = (left + right) / 2
            if float(item.get("x", -1)) != expected_x or float(item.get("y", -1)) != bottom:
                failures.append(f"{item.get('id')}: center-bottom anchor does not match {bounds_key}")
            result[bounds_key] = item[bounds_key]
        placement_checks.append(result)

    if full_canvas_ids != expected_full_canvas:
        failures.append(
            f"full-canvas placements are {sorted(full_canvas_ids)}, "
            f"expected {sorted(expected_full_canvas)}"
        )

    tree = next((item for item in placement_items if item.get("id") == "tree_house"), None)
    tree_metadata = composition_checks.get("treeHouse", {})
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
        if tree_metadata.get("initialRightEdgeClipping") is True and tree_right <= canvas_size[0]:
            failures.append("tree_house does not retain the approved initial right-edge clipping")
        if tree.get("structuralUnit") != "complete_host_tree_and_carved_dwelling":
            failures.append("tree_house structuralUnit metadata is missing or invalid")
        if tree.get("completeHostTreeAvailable") is not True:
            failures.append("tree_house does not declare completeHostTreeAvailable")
        if tree_metadata.get("placementId") != "tree_house":
            failures.append("compositionChecks.treeHouse placementId is invalid")
        if tree_metadata.get("completeHostTreeAvailable") is not True:
            failures.append("compositionChecks.treeHouse does not preserve the complete host tree")
        if tree_metadata.get("structuralRule") != "host tree and carved dwelling remain one inseparable asset":
            failures.append("compositionChecks.treeHouse structuralRule is invalid")

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
        "manifest": str(
            (project_root / BUNDLE_REL / "metadata/asset_manifest.json").relative_to(project_root)
        ),
        "canvas": list(canvas_size),
        "reviewSize": list(review_size),
        "acceptedAssetCount": len(accepted),
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
            "complete host tree remains available despite intentional initial right-edge clipping",
            "cottage, well, mushrooms, and lantern clusters preserve readable silhouettes",
            "five contact tufts ground their associated props",
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
