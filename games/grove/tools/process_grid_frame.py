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

Deterministic. The pre-process slice is archived next to it as panel_grid.raw.png (kept, not
deleted) so a re-slice can be re-run through here. Prints the per-side decoration extents so the
nine-patch margins in board.gd (_make_board_mat) can be matched to the art.
"""
import os, sys
from PIL import Image

HERE = os.path.dirname(__file__)
SRC  = os.path.normpath(os.path.join(HERE, "..", "assets", "ui", "board", "panel_grid.png"))
RAW  = os.path.normpath(os.path.join(HERE, "..", "assets", "ui", "board", "panel_grid.raw.png"))


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
    im = Image.open(SRC).convert("RGBA")
    W, H = im.size
    px = im.load()

    if not os.path.exists(RAW):          # archive the pre-process slice once
        im.save(RAW)
        print("archived raw ->", os.path.basename(RAW))

    out = im.copy(); opx = out.load()
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
    out.save(SRC)
    print("cleared interior pixels:", cleared)

    # measure how far opaque content reaches in from each side WITHIN the corner bands,
    # so the nine-patch corner margins can hold the leaf clusters.
    BAND = 150
    npx = out.load()
    def op(x, y): return npx[x, y][3] > 25
    left = top = right = bottom = 0
    for y in list(range(BAND)) + list(range(H - BAND, H)):
        for x in range(BAND):
            if op(x, y): left = max(left, x + 1)
        for x in range(W - 1, W - BAND - 1, -1):
            if op(x, y): right = max(right, W - x)
    for x in list(range(BAND)) + list(range(W - BAND, W)):
        for y in range(BAND):
            if op(x, y): top = max(top, y + 1)
        for y in range(H - 1, H - BAND - 1, -1):
            if op(x, y): bottom = max(bottom, H - y)
    print("decoration extent (px) from edge:  left=%d top=%d right=%d bottom=%d" %
          (left, top, right, bottom))
    print("=> suggested patch margins (board.gd _make_board_mat)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
