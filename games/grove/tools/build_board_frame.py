#!/usr/bin/env python3
"""Bespoke board-art builds that island-slicing can't deliver cleanly.

The board_asset.png sheet ships the board FRAME as separate kit parts (4 corners +
4 planks, gapped) and the quest CARD with a baked "+25" reward mockup. This script:

  1. FRAME  — composite the parts into one continuous wood-ring NINE-PATCH
              (corners fixed in the patch margins, planks stretch between them),
              transparent center → ui/board/panel_grid.png. Margin = 108.
  2. CARD   — crop the card template (island 8), erase the baked "🌸+25" from its
              reward pill (the engine draws the reward), → ui/quest/card_quest.png.

Reads the still-in-_new raw sheet (run BEFORE `make intake` archives it). Deterministic.
Island coords are from `slice_islands.gd` at val_min=0.90 sat_max=0.10 min_area=1200 pad=4.

  python3 games/grove/tools/build_board_frame.py [--preview]   # --preview writes /tmp only
"""
import sys
from PIL import Image

ASSET = "games/grove/assets"
SHEET = f"{ASSET}/_new/board_asset.png"
PREVIEW = "--preview" in sys.argv

# island bboxes (x, y, w, h) from the slice peek
ISL = {
    21: (28, 153, None, None),  # placeholder; real coords below via slice peek table
}

# --- frame parts: crop straight from the sheet by island bbox (x0,y0,x1,y1) ----------
SHEET_IM = Image.open(SHEET).convert("RGBA")


def knockout(im):
    """Drop bright-achromatic background crumbs (the baked near-white matte) to alpha 0."""
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            mx, mn = max(r, g, b), min(r, g, b)
            sat = 0 if mx == 0 else (mx - mn) / mx
            if mx > 230 and sat < 0.10:
                px[x, y] = (r, g, b, 0)
    return im


def part(x0, y0, w, h):
    return knockout(SHEET_IM.crop((x0, y0, x0 + w, y0 + h)).copy())


# frame kit parts (from the peek table)
TL = part(27, 542, 91, 94)
TR = part(542, 552, 87, 84)
BL = part(21, 768, 97, 99)
BR = part(542, 769, 87, 98)
TOP = part(143, 554, 376, 56)
BOT = part(135, 807, 388, 59)
LEFT = part(29, 642, 40, 118)
RIGHT = part(585, 642, 38, 119)

M, MID = 108, 90
W = H = M * 2 + MID  # 306
EXT = 60
frame = Image.new("RGBA", (W, H), (0, 0, 0, 0))


def rz(im, w, h):
    return im.resize((max(1, w), max(1, h)), Image.LANCZOS)


# planks span deep under the corners; corners drawn on top hide the junctions
frame.alpha_composite(rz(TOP, W - 2 * EXT, TOP.height), (EXT, 6))
frame.alpha_composite(rz(BOT, W - 2 * EXT, BOT.height), (EXT, H - BOT.height - 6))
frame.alpha_composite(rz(LEFT, LEFT.width, H - 2 * EXT), (7, EXT))
frame.alpha_composite(rz(RIGHT, RIGHT.width, H - 2 * EXT), (W - RIGHT.width - 7, EXT))
for im, xy in [(TL, (0, 0)), (TR, (W - TR.width, 0)),
               (BL, (0, H - BL.height)), (BR, (W - BR.width, H - BR.height))]:
    frame.alpha_composite(im, xy)
knockout(frame)

frame_out = "/tmp/panel_grid_build.png" if PREVIEW else f"{ASSET}/ui/board/panel_grid.png"
frame.save(frame_out)
print(f"FRAME -> {frame_out}  {W}x{H}  (nine-patch margin = {M})")

# --- card: crop island 8, erase the baked reward glyphs, keep the empty pill ----------
CARD_BOX = (436, 152, 790, 437)          # island 8 bbox + small pad
card = knockout(SHEET_IM.crop(CARD_BOX).copy())
cw, ch = card.size
# reward pill interior (proportional, inside its tan border) — fill flat cream to erase
px0, py0, px1, py1 = int(cw * 0.51), int(ch * 0.70), int(cw * 0.92), int(ch * 0.88)
cream = card.getpixel((px0 + 4, py0 + 3))           # sample a clean interior corner
cream = (cream[0], cream[1], cream[2], 255)
for y in range(py0, py1):
    for x in range(px0, px1):
        card.putpixel((x, y), cream)
card_out = "/tmp/card_build.png" if PREVIEW else f"{ASSET}/ui/quest/card_quest.png"
card.save(card_out)
print(f"CARD  -> {card_out}  {cw}x{ch}  pill cream={cream[:3]}")
