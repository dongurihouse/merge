#!/usr/bin/env python3
"""Build the game's picture-book PAGE manifests from the scene-workbench bundles.

For each of the five scenes this DETERMINISTIC script (art-guide rule: scripts move pixels/files,
judgment lives in the invocation) reads the bundle's metadata/placements.json (the file `make sw`
edits), copies the referenced element PNGs into the repo at games/grove/assets/map/pages/<scene>/,
and emits a zone manifest games/grove/assets/map/pages/zone_<scene>.json in the exact schema
home_zone_view.gd renders (canvas + background + center-bottom props; sort_y carries the scene's
explicit z so paint order survives the y-sorted renderer).

A scene with no placements yet (snowy_village; fairy_hollow's are empty) falls back to the bundle
root's full-scene mock PNG as a single background. --carry-home appends zone_farmhouse.json's
buildings to the FIRST page so the interim build loop (badges -> coins -> the zone's bucket cell)
stays reachable until the pages build system lands.

Re-run after fine-tuning in `make sw`, then `make import`:
    python3 games/grove/tools/build_page_manifests.py [--root <scenes root>] [--no-carry-home]
"""
import argparse, json, os, shutil, struct, sys

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
DEFAULT_ROOT = "/Users/xup/dh/merge/.worktrees/codex-ui-redesign-rush-maps-mocks/games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1"
OUT_DIR = os.path.join(REPO, "games/grove/assets/map/pages")
FARMHOUSE_MANIFEST = os.path.join(REPO, "games/grove/assets/map/home/zone_farmhouse.json")

PAGES = [  # play order (picturebook_lines_recipes.md)
    ("fairy_hollow", "Fairy Hollow"),
    ("snowy_village", "Snowy Village"),
    ("desert_oasis", "Desert Oasis"),
    ("coral_reef", "Coral Reef"),
    ("cherry_blossom_garden", "Cherry-Blossom Garden"),
]


def png_size(path):
    with open(path, "rb") as f:
        head = f.read(24)
    if len(head) < 24 or head[12:16] != b"IHDR":
        raise SystemExit(f"not a PNG: {path}")
    w, h = struct.unpack(">II", head[16:24])
    return int(w), int(h)


def bundle_for(root, scene):
    best, best_v = None, -1
    for sub in sorted(os.listdir(root)):
        if not sub.startswith(scene + "_elements_v"):
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
    shutil.copyfile(src, dst)
    return "res://" + os.path.relpath(dst, REPO)


def build_page(root, scene, label, carry_home):
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

    if carry_home:  # interim: the farmhouse build items ride the first page (coins -> the zone cell)
        with open(FARMHOUSE_MANIFEST) as f:
            farm = json.load(f)
        fw = int(farm.get("canvas", {}).get("width", 941))
        fh = int(farm.get("canvas", {}).get("height", 1672))
        sx, sy = cw / fw, ch / fh
        for b in farm.get("buildings", []):
            nb = json.loads(json.dumps(b))             # deep copy; keep states/res paths verbatim
            nb["position"] = [int(round(b["position"][0] * sx)), int(round(b["position"][1] * sy))]
            nb["display_size"] = [int(round(b["display_size"][0] * sx)), int(round(b["display_size"][1] * sy))]
            nb["sort_y"] = 1000 + int(b.get("sort_y", 0))   # the build layer rides above the scenery
            buildings.append(nb)
        print(f"  + {scene}: carried the {len(farm.get('buildings', []))} farmhouse build items (interim build surface)")

    manifest = {"version": 1, "id": scene, "label": label,
                "canvas": {"width": cw, "height": ch},
                "background": background, "buildings": buildings}
    out = os.path.join(OUT_DIR, f"zone_{scene}.json")
    os.makedirs(OUT_DIR, exist_ok=True)
    with open(out, "w") as f:
        json.dump(manifest, f, indent=1)
        f.write("\n")
    print(f"  wrote {os.path.relpath(out, REPO)}  ({len(buildings)} props, canvas {cw}x{ch})")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default=DEFAULT_ROOT)
    ap.add_argument("--no-carry-home", action="store_true")
    args = ap.parse_args()
    if not os.path.isdir(args.root):
        raise SystemExit(f"scenes root not found: {args.root}")
    for i, (scene, label) in enumerate(PAGES):
        build_page(args.root, scene, label, carry_home=(i == 0 and not args.no_carry_home))


if __name__ == "__main__":
    main()
