#!/usr/bin/env python3
"""Bake a full-scene composite reference for every picture-book scene.

The original AI-generated scene mocks died with the codex mocks worktree (2026-07-18, never
committed). This DETERMINISTIC script rebuilds a faithful stand-in per scene: the bundle's
placements composited base + layers in z order (the same math the renderers use — center-bottom
anchors), downscaled to review size, saved into the mocks root as `<scene>_baked_composite.png`
so the workbench's reference column picks it up (`M.reference_images` matches `<scene>*.png`).

Re-run after big composition changes to refresh the references:
    python3 games/grove/tools/bake_scene_composites.py
"""
import json, os
from PIL import Image, ImageChops

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
ROOT = os.path.join(REPO, "games/grove/assets/_concepts/zones")
SCENES = ["fairy_hollow", "snowy_village", "oasis", "coral_reef", "sakura"]
REVIEW_W = 941                     # the classic review size (941x1672 for the 1320x2346 canvas)


def bundle_for(scene):
    best, best_v = None, -1
    for sub in sorted(os.listdir(ROOT)):
        if not sub.startswith(scene + "_elements_v"):
            continue
        try:
            v = int(sub.rsplit("_v", 1)[1])
        except ValueError:
            continue
        if v > best_v and os.path.exists(os.path.join(ROOT, sub, "metadata/placements.json")):
            best, best_v = os.path.join(ROOT, sub), v
    return best


def placement_image(source, entry):
    """Resolve the source crop/feather declared by a placed scene element."""
    image = source.convert("RGBA")
    crop = entry.get("sourceCrop")
    if isinstance(crop, list) and len(crop) == 4:
        left, top, width, height = (int(v) for v in crop)
        if (
            left >= 0 and top >= 0 and width > 0 and height > 0
            and left + width <= image.width and top + height <= image.height
        ):
            image = image.crop((left, top, left + width, top + height))
    feather = entry.get("sourceCropFeatherBottom")
    if isinstance(feather, int) and 0 < feather <= image.height:
        fade = Image.new("L", image.size, 255)
        start = image.height - feather
        pixels = fade.load()
        for y in range(start, image.height):
            opacity = round(255 * (image.height - 1 - y) / max(1, feather - 1))
            for x in range(image.width):
                pixels[x, y] = opacity
        image.putalpha(ImageChops.multiply(image.getchannel("A"), fade))
    return image


def bake(scene):
    bundle = bundle_for(scene)
    if bundle is None:
        print(f"  ! {scene}: no openable bundle")
        return
    with open(os.path.join(bundle, "metadata/placements.json")) as f:
        doc = json.load(f)
    cw = int(doc.get("canvas", {}).get("width", 1320))
    ch = int(doc.get("canvas", {}).get("height", 2346))
    out = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
    base_rel = str(doc.get("base", {}).get("image", ""))
    base_path = os.path.join(REPO, base_rel)
    if os.path.exists(base_path):
        base = Image.open(base_path).convert("RGBA").resize((cw, ch), Image.LANCZOS)
        out.alpha_composite(base)
    entries = sorted(enumerate(doc.get("placements", [])), key=lambda p: (int(p[1].get("z", 0)), p[0]))
    skipped = 0
    for _, e in entries:
        p = os.path.join(REPO, str(e.get("image", "")))
        w, h = int(e.get("w", 0)), int(e.get("h", 0))
        if not os.path.exists(p) or w <= 0 or h <= 0:
            skipped += 1
            continue
        img = placement_image(Image.open(p), e).resize((w, h), Image.LANCZOS)
        out.alpha_composite(img, (int(e["x"]) - w // 2, int(e["y"]) - h))   # center-bottom anchor
    out = out.resize((REVIEW_W, int(ch * REVIEW_W / cw)), Image.LANCZOS)
    dst = os.path.join(ROOT, f"{scene}_baked_composite.png")
    out.convert("RGB").save(dst, optimize=True)
    # second reference: PROPS ONLY — the placed things (z >= 100, past the environment band) over
    # flat paper, so the prop layout reads clean without the backdrop pulling the eye.
    props = Image.new("RGBA", (cw, ch), (238, 228, 208, 255))
    for _, e in entries:
        p = os.path.join(REPO, str(e.get("image", "")))
        w, h = int(e.get("w", 0)), int(e.get("h", 0))
        if int(e.get("z", 0)) < 100 or not os.path.exists(p) or w <= 0 or h <= 0:
            continue
        img = placement_image(Image.open(p), e).resize((w, h), Image.LANCZOS)
        props.alpha_composite(img, (int(e["x"]) - w // 2, int(e["y"]) - h))
    props = props.resize((REVIEW_W, int(ch * REVIEW_W / cw)), Image.LANCZOS)
    props.convert("RGB").save(os.path.join(ROOT, f"{scene}_baked_props_only.png"), optimize=True)
    note = f" ({skipped} art-less entries skipped)" if skipped else ""
    print(f"  baked {os.path.basename(dst)} + props-only from {os.path.basename(bundle)}{note}")


def main():
    for scene in SCENES:
        bake(scene)


if __name__ == "__main__":
    main()
