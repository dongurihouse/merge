#!/usr/bin/env python3
"""Regenerate the hub-home reveal masks so each one covers the vines/overgrowth that
the OVERGROWN base (farm_brokenv2.png) paints on its building — not just the clean
building body. See engine/scripts/scenes/map.gd:_build_home (the §16 mask-reveal home):
each restored building reveals the CLEAN farm.png through its mask via
`COLOR.a *= texture(mask, UV).a`. The shipped masks were cut tight to the building, so
the vine fringe at each base kept showing the overgrown base after restore.

Deterministic. The only judgment dials are the constants below. Because farm.png is
clean EVERYWHERE, growing a mask can only ever reveal more clean farm — it cannot
introduce an error; the worst case is revealing a little clean ground early.

Approach (per mask):
  1. overgrowth = |broken - clean| over a threshold  (the painted vines/debris).
  2. keep only overgrowth clusters that TOUCH this building's (slightly dilated) mask,
     so detached ground overgrowth is left for its own building — partial reveals stay
     local to the restored building + the vines actually growing on it.
  3. a cluster touching two buildings is split per-pixel to the NEAREST mask.
  4. new mask = old mask ∪ assigned overgrowth, holes filled, edge feathered a few px.

Usage:
  python3 games/grove/tools/regen_home_masks.py <out_dir>   # writes mask_fh_*.png there
  (pass the asset dir itself to overwrite in place)
"""
import sys, os, glob
import numpy as np
from PIL import Image
import scipy.ndimage as ndi

FARM = os.path.join(os.path.dirname(__file__), "..", "assets", "farm")
FARM = os.path.normpath(FARM)

OVERGROWTH_THRESH = 45     # min summed-RGB diff (broken vs clean) to count as overgrowth
BRIDGE_DILATE     = 8      # px the mask is grown before testing which clusters touch it
CLUSTER_DILATE    = 2      # px the overgrowth is dilated before clustering (joins near-touching vine bits)
FEATHER_PX        = 2.0    # gaussian sigma for the soft reveal edge


def load_rgba(path):
    return np.asarray(Image.open(path).convert("RGBA"))


def main(out_dir):
    os.makedirs(out_dir, exist_ok=True)
    broken = load_rgba(os.path.join(FARM, "farm_brokenv2.png")).astype(int)
    clean_im = Image.open(os.path.join(FARM, "farm.png")).convert("RGBA")
    H, W = broken.shape[:2]
    if clean_im.size != (W, H):
        clean_im = clean_im.resize((W, H))
    clean = np.asarray(clean_im).astype(int)

    overgrowth = np.abs(broken[:, :, :3] - clean[:, :, :3]).sum(2) > OVERGROWTH_THRESH
    if CLUSTER_DILATE > 0:
        og_d = ndi.binary_dilation(overgrowth, iterations=CLUSTER_DILATE)
    else:
        og_d = overgrowth
    labels, nlab = ndi.label(og_d)   # connected overgrowth clusters

    mask_paths = sorted(glob.glob(os.path.join(FARM, "mask_fh_*.png")))
    regions = {os.path.basename(p): (load_rgba(p)[:, :, 3] > 40) for p in mask_paths}

    # nearest-mask label for every pixel (for splitting clusters shared by two buildings)
    names = list(regions.keys())
    owner = np.zeros((H, W), np.int32)          # 1..N = nearest mask index, by EDT
    union = np.zeros((H, W), bool)
    seed = np.zeros((H, W), np.int32)
    for i, n in enumerate(names, start=1):
        seed[regions[n]] = i
        union |= regions[n]
    # distance_transform_edt on the inverse, carrying the nearest seed's coordinates
    _, (iy, ix) = ndi.distance_transform_edt(~union, return_indices=True)
    owner = seed[iy, ix]

    summary = []
    for i, n in enumerate(names, start=1):
        reg = regions[n]
        reg_dil = ndi.binary_dilation(reg, iterations=BRIDGE_DILATE)
        touch_labels = set(np.unique(labels[reg_dil & og_d])) - {0}
        attached = np.isin(labels, list(touch_labels)) & overgrowth
        assigned = attached & (owner == i)       # split shared clusters to nearest mask
        grown = reg | assigned
        grown = ndi.binary_fill_holes(grown)
        alpha = (grown * 255).astype(np.float32)
        if FEATHER_PX > 0:
            alpha = ndi.gaussian_filter(alpha, FEATHER_PX)
        alpha = np.clip(alpha, 0, 255).astype(np.uint8)
        out = np.zeros((H, W, 4), np.uint8)
        out[:, :, 0] = out[:, :, 1] = out[:, :, 2] = 255   # white where shown (RGB unused by shader)
        out[:, :, 3] = alpha
        Image.fromarray(out, "RGBA").save(os.path.join(out_dir, n))
        summary.append((n, int(reg.sum()), int(grown.sum()), int(assigned.sum())))

    print("mask                     old_px   new_px   +overgrowth")
    for n, old, new, add in summary:
        print("  %-22s %7d  %7d  %+d" % (n, old, new, add))
    print("wrote %d masks to %s" % (len(summary), out_dir))


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "/tmp/newmasks")
