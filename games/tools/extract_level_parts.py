#!/usr/bin/env python3
"""Re-extract the layered level-badge parts (ui/lvl_parts).

Two extraction modes, by what the part IS:
- FILL (circle, flower, acorn, gem): each stage is scaled to fill the canvas, bottom-anchored
  (process_icon `icon:512:bottom`). These are SINGLE elements, so filling just makes them bigger —
  fine, and it keeps them prominent at every stage.
- PROPORTIONAL (leaf): the wreath is a CLUSTER of repeated leaves. Filling each stage would balloon
  a few-leaf stage's leaves to the size of the full wreath's. process_group.gd instead scales all 6
  stages by ONE factor (largest fills, smaller keep their relative size) so each leaf stays a
  consistent size and the wreath genuinely grows.

  python3 games/tools/extract_level_parts.py [--godot godot]

Run from the repo root. Slices the archived source sheets, then processes each part, and reimports.
"""
from __future__ import annotations

import argparse
import os
import subprocess
import sys
from pathlib import Path

ASSET = Path("games/grove/assets")
ORIG = ASSET / "_originals/ui"
OUT = "res://games/grove/assets/ui/lvl_parts"
SCRATCH = Path(".godot/lvl_parts_scratch")
SIZE = 512

# sheet -> {part: [tile indices for stages 1..6, row-major in the sliced sheet]}
# FILL parts (single elements) — scaled to fill via process_icon.
FILL = ("lvls_asset.png", {
    "circle": [0, 5, 10, 15, 20, 25],   # col 0
    "flower": [2, 7, 12, 17, 22, 27],   # col 2  (col 1 = discarded sprout)
    "acorn":  [3, 8, 13, 18, 23, 28],   # col 3
    "gem":    [4, 9, 14, 19, 24, 29],   # col 4
})
# PROPORTIONAL parts (clusters) — group-normalized via process_group so per-element size is consistent.
GROUP = ("lvls_leafs.png", {
    "leaf": [0, 1, 2, 3, 4, 5],         # 2x3 wreaths, row-major = stages 1..6
})


def run(godot: str, tool: str, args: list[str]) -> str:
    r = subprocess.run([godot, "--headless", "--path", ".", "-s", tool, "--", *args],
                       capture_output=True, text=True)
    if r.returncode != 0:
        print(r.stdout)
        print(r.stderr)
        raise SystemExit(f"tool failed: {tool}")
    return r.stdout


def _slice(godot: str, sheet: str) -> str:
    src = str((ORIG / sheet).resolve())
    prefix = str((SCRATCH / sheet.replace(".png", "_")).resolve())
    run(godot, "res://games/tools/slice_grid.gd", [src, prefix])
    return prefix


def _tile(prefix: str, idx: int, part: str, stage: int) -> str:
    t = f"{prefix}{idx}.png"
    if not Path(t).exists():
        raise SystemExit(f"missing tile {t} for {part} stage {stage}")
    return t


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="Re-extract level-badge parts (fill + proportional).")
    ap.add_argument("--godot", default=os.environ.get("GODOT", "godot"))
    a = ap.parse_args(argv)
    SCRATCH.mkdir(parents=True, exist_ok=True)

    # FILL: each stage scaled to fill, bottom-anchored (process_icon icon:512:bottom)
    sheet, parts = FILL
    prefix = _slice(a.godot, sheet)
    for part, idxs in parts.items():
        for stage, idx in enumerate(idxs, start=1):
            tile = _tile(prefix, idx, part, stage)
            run(a.godot, "res://games/tools/process_icon.gd",
                [tile, f"{OUT}/{part}_{stage}.png", str(SIZE), "--bottom"])
        print(f"  OK {part}: {len(idxs)} stages (fill)")

    # PROPORTIONAL: all stages share one scale (process_group)
    sheet, parts = GROUP
    prefix = _slice(a.godot, sheet)
    for part, idxs in parts.items():
        pairs: list[str] = []
        for stage, idx in enumerate(idxs, start=1):
            pairs += [f"{OUT}/{part}_{stage}.png", _tile(prefix, idx, part, stage)]
        run(a.godot, "res://games/tools/process_group.gd", [str(SIZE), *pairs])
        print(f"  OK {part}: {len(idxs)} stages (proportional)")

    subprocess.run([a.godot, "--headless", "--path", ".", "--import"], check=False)
    print("done -> ui/lvl_parts")
    return 0


if __name__ == "__main__":
    sys.exit(main())
