#!/usr/bin/env python3
"""Remove the two stray laurel-leaf fragments that bled into level_ring.png at the bottom-left
and bottom-right corners when the ring was sliced off lvls.png (slice-bleed from the neighbouring
wreath art, same failure mode as crop_level_badges.py's bottom blobs). The medallion already draws
its own laurel wreath BEHIND the ring (Kit.level_medallion), so these fragments are pure noise that
read as "dangly leaves" poking out under the gold ring.

Deterministic: keeps ONLY the largest connected alpha component (the gold ring disc) and clears every
other island to fully transparent. Idempotent — re-running on the cleaned file is a no-op. Re-run if
level_ring.png is ever re-sliced. Pure PIL (no scipy), 8-connected to match the kit's defringe kernel.
"""
import os
import sys
from collections import deque
from PIL import Image

RING = os.path.normpath(os.path.join(
    os.path.dirname(__file__), "..", "assets", "ui", "kit", "level_ring.png"))
ALPHA_MIN = 30  # a pixel counts as "content" at/above this alpha (matches the CC scan used to find the leaves)


def _largest_component(alpha, w, h):
    """Return a set of pixel indices belonging to the largest 8-connected island of alpha >= ALPHA_MIN."""
    seen = bytearray(w * h)
    best = []
    for start in range(w * h):
        if seen[start] or alpha[start] < ALPHA_MIN:
            continue
        comp = []
        q = deque([start])
        seen[start] = 1
        while q:
            p = q.popleft()
            comp.append(p)
            px, py = p % w, p // w
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    if dx == 0 and dy == 0:
                        continue
                    nx, ny = px + dx, py + dy
                    if 0 <= nx < w and 0 <= ny < h:
                        n = ny * w + nx
                        if not seen[n] and alpha[n] >= ALPHA_MIN:
                            seen[n] = 1
                            q.append(n)
        if len(comp) > len(best):
            best = comp
    return set(best)


def main(path=RING):
    im = Image.open(path).convert("RGBA")
    w, h = im.size
    px = im.load()
    alpha = im.getchannel("A").tobytes()
    keep = _largest_component(alpha, w, h)
    cleared = 0
    for i in range(w * h):
        if alpha[i] >= ALPHA_MIN and i not in keep:
            px[i % w, i // w] = (0, 0, 0, 0)
            cleared += 1
    im.save(path)
    print("cleaned %s — kept %d-px ring, cleared %d stray-leaf px" % (
        os.path.basename(path), len(keep), cleared))


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else RING)
