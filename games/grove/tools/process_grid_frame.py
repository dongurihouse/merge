#!/usr/bin/env python3
"""Turn the sliced grid-panel art (ui/board/panel_grid.png) into a clean NINE-PATCH FRAME.

The raw slice keeps the painted parchment interior + faint cell grid-lines inside the bamboo
ring (and a leaf cluster at each corner). board.gd draws it as a NinePatchRect, but with the
interior still filled the corner margins can't grow past it without dragging painted parchment
into the stretched edges — so the leaf clusters spill outside a small margin and SMEAR when the
landscape art is fit to the portrait board.

This clears everything INSIDE the bamboo ring to transparent (keeping the ring + the leaves that
grow off it), so the corner margins can be set large enough to hold the leaf clusters while only
the plain bamboo poles stretch. Implements the spec's `process_grid_frame` step
(docs/superpowers/specs/2026-06-17-board-art-reskin-design.md).

Deterministic. The pre-process slice is archived to _originals/board/panel_grid.raw.png (kept,
not deleted) so a re-slice can be re-run through here. Prints the per-side decoration extents so
the nine-patch margins in board.gd (_make_board_mat) can be matched to the art.
"""
import os, sys
from PIL import Image

HERE = os.path.dirname(__file__)
SRC  = os.path.normpath(os.path.join(HERE, "..", "assets", "ui", "board", "panel_grid.png"))
RAW  = os.path.normpath(os.path.join(HERE, "..", "assets", "_originals", "board", "panel_grid.raw.png"))


def kind(p):
    a = p[3]
    if a < 25:
        return "T"                       # transparent
    r, g, b = p[:3]
    l = 0.3 * r + 0.59 * g + 0.11 * b
    if l > 188 and r > 205 and b > 140:
        return "C"                       # cream parchment (interior + gutters)
    return "F"                           # frame: bamboo pole or green leaf


def inner_edge(seq, lo, hi, step):
    """Walk from `lo` toward `hi`; skip the transparent margin, then the first frame run
    (the bamboo border + any leaf growing off it), and return the index where the cream
    interior begins. None if this line is all border (no interior — e.g. a pure-frame row)."""
    n = len(seq); i = lo
    while 0 <= i < n and seq[i] == "T":
        i += step
    gap = 0
    while 0 <= i < n:
        if seq[i] == "C":
            gap += 1
            if gap >= 4:                 # 4 cream in a row => we are past the ring
                return i - step * 3
        else:
            gap = 0
        i += step
    return None


def main():
    if not os.path.exists(SRC):
        print("missing", SRC); return 1

    # Reprocess from the archived raw slice when present so this is idempotent (re-running never
    # processes an already-processed image); archive on the first run.
    if os.path.exists(RAW):
        im = Image.open(RAW).convert("RGBA")
    else:
        im = Image.open(SRC).convert("RGBA")
        im.save(RAW)
        print("archived raw ->", os.path.basename(RAW))
    W, H = im.size
    px = im.load()

    out = im.copy(); opx = out.load()

    # (a) clear the painted parchment interior to transparent — keep only the bamboo ring + leaves.
    cleared = 0
    for y in range(H):
        seq = [kind(px[x, y]) for x in range(W)]
        li = inner_edge(seq, 0, W, 1)
        ri = inner_edge(seq, W - 1, -1, -1)
        if li is None or ri is None or ri <= li:
            continue
        for x in range(li + 1, ri):
            if opx[x, y][3]:
                opx[x, y] = (0, 0, 0, 0); cleared += 1
    print("cleared interior pixels:", cleared)

    # (b) tone down the bamboo's bright OUTER rim. The art paints a near-white highlight a few px in
    # from the outer edge; against the backdrop it reads as an ugly white border. Find pixels within
    # RIM px of the OUTSIDE (transparent region connected to the image border) and pull the brightest
    # ones down toward a normal bamboo tone. Interior-facing edges (against the cream field) are left
    # alone — only the outward rim is toned.
    import collections
    RIM, BRIGHT, SCALE = 5, 198, 0.74
    dist = [[-1] * W for _ in range(H)]          # BFS distance from outside, capped at RIM
    q = collections.deque()
    for x in range(W):
        for yy in (0, H - 1):
            if opx[x, yy][3] <= 25 and dist[yy][x] < 0:
                dist[yy][x] = 0; q.append((x, yy))
    for y in range(H):
        for xx in (0, W - 1):
            if opx[xx, y][3] <= 25 and dist[y][xx] < 0:
                dist[y][xx] = 0; q.append((xx, y))
    toned = 0
    while q:
        x, y = q.popleft(); d = dist[y][x]
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if not (0 <= nx < W and 0 <= ny < H) or dist[ny][nx] >= 0:
                continue
            p = opx[nx, ny]
            if p[3] <= 25:                       # keep flooding through outside transparency
                dist[ny][nx] = 0; q.append((nx, ny))
            elif d < RIM:                        # an opaque pixel within RIM of the outside = rim
                dist[ny][nx] = d + 1; q.append((nx, ny))
                lum = 0.3 * p[0] + 0.59 * p[1] + 0.11 * p[2]
                if lum > BRIGHT:
                    opx[nx, ny] = (int(p[0] * SCALE), int(p[1] * SCALE), int(p[2] * SCALE), p[3])
                    toned += 1
    print("toned bright rim pixels:", toned)

    out.save(SRC)
    return 0


if __name__ == "__main__":
    sys.exit(main())
