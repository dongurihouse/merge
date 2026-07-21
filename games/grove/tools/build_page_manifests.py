#!/usr/bin/env python3
"""Build the game's picture-book PAGE manifests from the scene-workbench bundles.

For each of the five scenes this DETERMINISTIC script (art-guide rule: scripts move pixels/files,
judgment lives in the invocation) reads the bundle's metadata/placements.json (the file `make sw`
edits), copies the referenced element PNGs into the repo at games/grove/assets/map/pages/<scene>/,
and emits a zone manifest games/grove/assets/map/pages/zone_<scene>.json in the exact schema
home_zone_view.gd renders (canvas + background + center-bottom props; sort_y carries the scene's
explicit z so paint order survives the y-sorted renderer).

A scene with no placements yet (snowy_village; fairy_hollow's are empty) falls back to the bundle
root's full-scene mock PNG as a single background. Pages are STRICTLY the scene-workbench scenes
(decision 2026-07-18): the old --carry-home pass that appended zone_farmhouse.json's buildings to
the first page is retired — unlockables arrive via the zoning tool + coverings instead.

Re-run after fine-tuning in `make sw`, then `make import`:
    python3 games/grove/tools/build_page_manifests.py [--root <scenes root>]
"""
import argparse, json, os, shutil, struct, sys

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
# the repo mocks root (the codex mocks worktree that once held the bundles was deleted 2026-07-18)
DEFAULT_ROOT = os.path.join(REPO, "games/grove/assets/_concepts/zones")
OUT_DIR = os.path.join(REPO, "games/grove/assets/map/pages")

PAGES = [  # play order (picturebook_lines_recipes.md)
    ("hollow", "Hollow"),
    ("snowy_village", "Snowy Village"),
    ("desert_oasis", "Desert Oasis"),
    ("coral_reef", "Coral Reef"),
    ("sakura", "Cherry-Blossom Garden"),
]

# Scene → bundle-prefix map (2026-07-20, scenes 2-5 wiring): each scene's authored elements bundle
# lives under a DIFFERENT prefix than the scene id (the scene-workbench names bundles after the
# scene's hero structure, not the picture-book page id). The `hollow` page (renamed from the old
# `fairy_hollow_market`, 2026-07-21) resolves against the `fairy_hollow_market_elements_v*` bundle.
SCENE_BUNDLES = {
    "hollow": "fairy_hollow_market",
    "snowy_village": "winter",
    "desert_oasis": "oasis",
    "coral_reef": "coral",
    # `sakura` needs no entry — its bundle prefix equals its scene id (sakura_elements_v*).
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


def bundle_for(root, scene):
    prefix = SCENE_BUNDLES.get(scene, scene)
    best, best_v = None, -1
    for sub in sorted(os.listdir(root)):
        if not sub.startswith(prefix + "_elements_v"):
            continue
        try:
            v = int(sub.rsplit("_v", 1)[1])
        except ValueError:
            continue
        if v > best_v and os.path.exists(os.path.join(root, sub, "metadata/placements.json")):
            best, best_v = os.path.join(root, sub), v
    return best


def copy_asset(src, scene, name):
    dst_dir = os.path.join(OUT_DIR, scene)
    os.makedirs(dst_dir, exist_ok=True)
    dst = os.path.join(dst_dir, name + ".png")
    if os.path.abspath(src) != os.path.abspath(dst):   # recovered bundles already point AT the pages art
        shutil.copyfile(src, dst)
    return "res://" + os.path.relpath(dst, REPO)


def build_page(root, scene, label):
    bundle = bundle_for(root, scene)
    doc = {}
    if bundle:
        with open(os.path.join(bundle, "metadata/placements.json")) as f:
            doc = json.load(f)
    placements = doc.get("placements", [])
    bundle_repo_root = root
    for _ in range(0, 7):  # the bundle's image paths are repo-relative — walk up to the dir holding games/
        if os.path.isdir(os.path.join(bundle_repo_root, "games")):
            break
        bundle_repo_root = os.path.dirname(bundle_repo_root)

    buildings = []
    coverups = []
    if placements:
        base_rel = str(doc.get("base", {}).get("image", ""))
        base_src = os.path.join(bundle_repo_root, base_rel)
        if not os.path.exists(base_src):
            raise SystemExit(f"{scene}: base image missing: {base_src}")
        background = copy_asset(base_src, scene, "foundation")
        canvas = doc.get("canvas", {})
        cw, ch = int(canvas.get("width", 1320)), int(canvas.get("height", 2346))
        for e in placements:
            src = os.path.join(bundle_repo_root, str(e.get("image", "")))
            if not os.path.exists(src):
                print(f"  ! {scene}: skipping {e.get('id')} — missing {src}")
                continue
            tex = copy_asset(src, scene, str(e["id"]))
            if str(e.get("layer", "")) == "coverup" or str(e.get("category", "")) == "unlock_cover":
                # RESPECT THE SW TOOL: anything the Scene Workbench places on its frontmost "coverup"
                # LAYER is a cover-up piece (the tool tags by layer, and moving an element there does
                # NOT rewrite its category — so key on the layer, not the category). Carried through as
                # coverups (NOT page props); the runtime mounts them frontmost per cluster and reveals
                # them away on unlock. The cluster links to the unlock unit as `unlock_region_<clusterId>`.
                region = str(e.get("cluster", ""))
                cluster = strip_coverup_prefix(region)
                coverups.append({
                    "id": str(e["id"]), "cluster": cluster,
                    "position": [int(e["x"]), int(e["y"])],
                    "display_size": [int(e["w"]), int(e["h"])],
                    "sort_y": int(e.get("z", 0)),
                    "image": tex,
                })
                continue
            entry = {
                "id": str(e["id"]), "label": str(e["id"]).replace("_", " "),
                "position": [int(e["x"]), int(e["y"])],
                "display_size": [int(e["w"]), int(e["h"])],
                "sort_y": int(e.get("z", 0)),          # explicit scene z IS the paint order
                "cluster": str(e.get("cluster", "")),
                "states": {"built": tex},
            }
            if e.get("shadow"):                        # dynamic silhouette shadow (prop_shadow.gd)
                entry["shadow"] = True
            buildings.append(entry)
    else:
        mock = os.path.join(root, scene + ".png")
        if not os.path.exists(mock):
            raise SystemExit(f"{scene}: no placements and no mock at {mock}")
        background = copy_asset(mock, scene, "foundation")
        cw, ch = png_size(mock)
        print(f"  ~ {scene}: no placements yet — the full-scene mock ships as the page")

    manifest = {"version": 1, "id": scene, "label": label,
                "canvas": {"width": cw, "height": ch},
                "background": background, "buildings": buildings, "coverups": coverups}
    out = os.path.join(OUT_DIR, f"zone_{scene}.json")
    os.makedirs(OUT_DIR, exist_ok=True)
    with open(out, "w") as f:
        json.dump(manifest, f, indent=1)
        f.write("\n")
    print(f"  wrote {os.path.relpath(out, REPO)}  ({len(buildings)} props, {len(coverups)} coverups, canvas {cw}x{ch})")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default=DEFAULT_ROOT)
    ap.add_argument("--only", default="", help="generate just this scene id (label defaults to a title-cased id)")
    args = ap.parse_args()
    if not os.path.isdir(args.root):
        raise SystemExit(f"scenes root not found: {args.root}")
    if args.only:
        label = dict(PAGES).get(args.only, args.only.replace("_", " ").title())
        build_page(args.root, args.only, label)
        return
    for scene, label in PAGES:
        build_page(args.root, scene, label)


if __name__ == "__main__":
    main()
