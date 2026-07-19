#!/usr/bin/env python3
"""Recover scene-workbench bundles from the game's page manifests.

When a mocks root loses a scene's bundle (2026-07-18: the codex mocks worktree was deleted with
the desert/snowy placements still untracked), the game side still carries EVERYTHING the workbench
needs: assets/map/pages/zone_<scene>.json (positions, sizes, z, clusters, shadow tags) plus every
copied element PNG. This DETERMINISTIC script synthesizes `<scene>_elements_v1/metadata/
placements.json` in the repo mocks root from that data — image paths point at the surviving
copied art, so nothing is duplicated.

Only scenes WITHOUT an openable bundle are recovered (an in-flight intake owns the rest); an
existing recovered bundle is refreshed in place. Lost in recovery (they lived only in the deleted
worktree): per-entry category/layer labels, the 00-05 element source dirs, and most root mocks.

    python3 games/grove/tools/recover_scene_bundles.py
"""
import json, os

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
ROOT = os.path.join(REPO, "games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1")
PAGES = os.path.join(REPO, "games/grove/assets/map/pages")

SCENES = ["fairy_hollow", "snowy_village", "desert_oasis", "coral_reef", "cherry_blossom_garden"]


def openable(scene):
    if not os.path.isdir(ROOT):
        return False
    for sub in os.listdir(ROOT):
        if sub.startswith(scene + "_elements_v") and not sub.endswith("_recovered") \
                and os.path.exists(os.path.join(ROOT, sub, "metadata/placements.json")):
            return True
    return False


def recover(scene):
    zone_path = os.path.join(PAGES, f"zone_{scene}.json")
    if not os.path.exists(zone_path):
        print(f"  ! {scene}: no page manifest to recover from")
        return
    with open(zone_path) as f:
        zone = json.load(f)
    placements = []
    for b in zone.get("buildings", []):
        tex = str(b.get("states", {}).get("built", "")).replace("res://", "")
        e = {
            "id": str(b["id"]),
            "image": tex,
            "x": int(b["position"][0]), "y": int(b["position"][1]),
            "w": int(b["display_size"][0]), "h": int(b["display_size"][1]),
            "z": int(b.get("sort_y", 0)),
        }
        if str(b.get("cluster", "")):
            e["cluster"] = str(b["cluster"])
        if b.get("shadow"):
            e["shadow"] = True
        placements.append(e)
    doc = {
        "schemaVersion": 2,
        "scene": f"{scene}_recovered",
        "recoveredFrom": f"games/grove/assets/map/pages/zone_{scene}.json (2026-07-18 — the codex mocks worktree was deleted with these placements untracked)",
        "canvas": {
            "width": int(zone.get("canvas", {}).get("width", 1320)),
            "height": int(zone.get("canvas", {}).get("height", 2346)),
            "anchorConvention": "center-bottom",
        },
        "base": {"id": "foundation",
                 "image": str(zone.get("background", "")).replace("res://", ""), "opaque": True, "z": 0},
        "placements": placements,
    }
    out_dir = os.path.join(ROOT, f"{scene}_elements_v1", "metadata")
    os.makedirs(out_dir, exist_ok=True)
    with open(os.path.join(out_dir, "placements.json"), "w") as f:
        json.dump(doc, f, indent=1)
        f.write("\n")
    print(f"  recovered {scene}_elements_v1 ({len(placements)} placements)")


def main():
    for scene in SCENES:
        if openable(scene):
            print(f"  ~ {scene}: an openable bundle exists — left to its owner")
        else:
            recover(scene)


if __name__ == "__main__":
    main()
