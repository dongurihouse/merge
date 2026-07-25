#!/usr/bin/env python3
"""Build the game's picture-book PAGE manifests from the consolidated scene folders.

For each of the five scenes this DETERMINISTIC script (art-guide rule: scripts move pixels/files,
judgment lives in the invocation) reads map/<scene>/placements.json (the file `make sw` edits) and
emits a zone manifest map/<scene>/page.json in the exact schema home_page_view.gd renders (canvas +
background + center-bottom props; sort_y carries the scene's explicit z so paint order survives the
y-sorted renderer). The element art already lives at map/<scene>/<layer>/, so the manifest just points
res:// straight at it — NO copying, ONE canonical copy per element (the old per-placement duplication
into map/pages/ is retired along with that folder).

Re-run after fine-tuning in `make sw`, then `make import`:
    python3 games/grove/tools/build_page_manifests.py [--only <scene>]
"""
import argparse, json, os, struct

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
MAP_ROOT = os.path.join(REPO, "games/grove/assets/map")

PAGES = [  # play order (picturebook_lines_recipes.md); page id -> label
    ("hollow", "Hollow"),
    ("snowy_village", "Snowy Village"),
    ("desert_oasis", "Desert Oasis"),
    ("coral_reef", "Coral Reef"),
    ("sakura", "Cherry-Blossom Garden"),
]

# picture-book page id -> the scene-folder name under map/ (the scene workbench names scenes after the
# hero structure, not the page id). Identity when absent (hollow, sakura).
SCENE_FOLDER = {
    "snowy_village": "winter",
    "desert_oasis": "oasis",
    "coral_reef": "coral",
}

# Coverup region-id prefixes the scene workbench uses to link a coverup piece to its unlock cluster —
# longest-match first so "unlock_region_" is tried before its "unlock_" substring-prefix.
COVERUP_PREFIXES = ["unlock_region_", "unlock_", "lock_"]


def strip_coverup_prefix(region):
    for p in COVERUP_PREFIXES:
        if region.startswith(p):
            return region[len(p):]
    return region


def png_size(path):
    with open(path, "rb") as f:
        head = f.read(24)
    if len(head) < 24 or head[12:16] != b"IHDR":
        raise SystemExit(f"not a PNG: {path}")
    w, h = struct.unpack(">II", head[16:24])
    return int(w), int(h)


def res_path(repo_rel):
    """A placements image path is repo-relative (games/grove/assets/map/...); make it a res:// URL,
    checking the file exists first."""
    if not os.path.exists(os.path.join(REPO, repo_rel)):
        return None
    return "res://" + repo_rel


def build_page(scene_id, label):
    folder = SCENE_FOLDER.get(scene_id, scene_id)
    pj = os.path.join(MAP_ROOT, folder, "placements.json")
    if not os.path.exists(pj):
        raise SystemExit(f"{scene_id}: no placements at {pj}")
    with open(pj) as f:
        doc = json.load(f)
    placements = doc.get("placements", [])

    base_rel = str(doc.get("base", {}).get("image", ""))
    background = res_path(base_rel)
    if background is None:
        raise SystemExit(f"{scene_id}: base image missing: {base_rel}")
    canvas = doc.get("canvas", {})
    cw, ch = int(canvas.get("width", 1320)), int(canvas.get("height", 2346))

    def crop_fields(e):
        # Carry the sw tool's per-placement source crop (+ bottom feather) into the manifest, so the
        # runtime shows the SAME cropped region the workbench previews. Without it a full-canvas plate
        # placed at a small sub-rect smears across the scene (winter's edge foliage rendered over the
        # sky). See home_page_view._placed_texture, the runtime twin of scene_workbench_view.
        out = {}
        sc = e.get("sourceCrop")
        if isinstance(sc, list) and len(sc) == 4:
            out["sourceCrop"] = [int(round(float(v))) for v in sc]
        fb = e.get("sourceCropFeatherBottom")
        if isinstance(fb, (int, float)) and fb > 0:
            out["sourceCropFeatherBottom"] = int(round(float(fb)))
        return out

    def rot_field(e):
        # Carry the sw tool's per-placement ROTATION, for the same reason as the crop above: the
        # tool rotates every placement about its FOOT (scene_workbench_view._make_layer sets
        # pivot_offset to bottom-centre, then rotation_degrees). A manifest without `rot` renders
        # every leaning prop and canopy bolt-upright in game — 492 of the 549 authored placements
        # carry a non-zero rot. See home_page_view.build / _mount_coverups, the runtime twins.
        r = e.get("rot")
        if isinstance(r, (int, float)) and abs(float(r)) > 1e-9:
            return {"rot": round(float(r), 4)}
        return {}

    buildings, coverups = [], []
    for e in placements:
        tex = res_path(str(e.get("image", "")))
        if tex is None:
            print(f"  ! {scene_id}: skipping {e.get('id')} — missing {e.get('image')}")
            continue
        if str(e.get("layer", "")) == "coverup" or str(e.get("category", "")) == "unlock_cover":
            # RESPECT THE SW TOOL: anything on the frontmost "coverup" layer is a cover-up piece
            # (the tool tags by layer; moving an element there does NOT rewrite its category — so key
            # on the layer). The runtime mounts these frontmost per cluster and reveals them on unlock.
            coverups.append({
                "id": str(e["id"]), "cluster": strip_coverup_prefix(str(e.get("cluster", ""))),
                "position": [int(e["x"]), int(e["y"])],
                "display_size": [int(e["w"]), int(e["h"])],
                "sort_y": int(e.get("z", 0)),
                "image": tex,
                **crop_fields(e),
                **rot_field(e),
            })
            continue
        entry = {
            "id": str(e["id"]), "label": str(e["id"]).replace("_", " "),
            "position": [int(e["x"]), int(e["y"])],
            "display_size": [int(e["w"]), int(e["h"])],
            "sort_y": int(e.get("z", 0)),              # explicit scene z IS the paint order
            "cluster": str(e.get("cluster", "")),
            "states": {"built": tex},
        }
        if e.get("shadow"):                            # dynamic silhouette shadow (prop_shadow.gd)
            entry["shadow"] = True
        entry.update(crop_fields(e))                   # optional sourceCrop / feather (parity with the sw)
        entry.update(rot_field(e))                     # optional foot-pivot rotation (parity with the sw)
        buildings.append(entry)

    manifest = {"version": 1, "id": scene_id, "label": label,
                "canvas": {"width": cw, "height": ch},
                "background": background, "buildings": buildings, "coverups": coverups}
    out = os.path.join(MAP_ROOT, folder, "page.json")
    with open(out, "w") as f:
        json.dump(manifest, f, indent=1)
        f.write("\n")
    print(f"  wrote {os.path.relpath(out, REPO)}  ({len(buildings)} props, {len(coverups)} coverups, canvas {cw}x{ch})")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="", help="generate just this page id")
    args = ap.parse_args()
    if args.only:
        build_page(args.only, dict(PAGES).get(args.only, args.only.replace("_", " ").title()))
        return
    for scene_id, label in PAGES:
        build_page(scene_id, label)


if __name__ == "__main__":
    main()
