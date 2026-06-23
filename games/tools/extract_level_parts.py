#!/usr/bin/env python3
"""Re-extract the layered level-badge parts PROPORTIONALLY.

Each part's 6 stages share ONE scale (the largest fills the box; smaller stages keep their relative
size), so a small wreath's individual leaves don't balloon to fill the canvas. Supersedes the per-tile
`icon:512:bottom` intake for ui/lvl_parts (which scaled every stage to fill, flattening the growth).

  python3 games/tools/extract_level_parts.py [--godot godot]

Run from the repo root. Slices the archived source sheets, then group-normalizes each part via
games/tools/process_group.gd, and reimports.
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

# (sheet, {part: [tile indices for stages 1..6, row-major in the sliced sheet]})
SHEETS = [
    ("lvls_asset.png", {
        "circle": [0, 5, 10, 15, 20, 25],   # col 0
        "flower": [2, 7, 12, 17, 22, 27],   # col 2  (col 1 = discarded sprout)
        "acorn":  [3, 8, 13, 18, 23, 28],   # col 3
        "gem":    [4, 9, 14, 19, 24, 29],   # col 4
    }),
    ("lvls_leafs.png", {
        "leaf": [0, 1, 2, 3, 4, 5],         # 2x3 wreaths, row-major = stages 1..6
    }),
]


def run(godot: str, tool: str, args: list[str]) -> str:
    r = subprocess.run([godot, "--headless", "--path", ".", "-s", tool, "--", *args],
                       capture_output=True, text=True)
    if r.returncode != 0:
        print(r.stdout)
        print(r.stderr)
        raise SystemExit(f"tool failed: {tool}")
    return r.stdout


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="Re-extract level-badge parts proportionally.")
    ap.add_argument("--godot", default=os.environ.get("GODOT", "godot"))
    a = ap.parse_args(argv)
    SCRATCH.mkdir(parents=True, exist_ok=True)
    for sheet, parts in SHEETS:
        src = str((ORIG / sheet).resolve())
        prefix = str((SCRATCH / sheet.replace(".png", "_")).resolve())
        run(a.godot, "res://games/tools/slice_grid.gd", [src, prefix])
        for part, idxs in parts.items():
            pairs: list[str] = []
            for stage, idx in enumerate(idxs, start=1):
                tile = f"{prefix}{idx}.png"
                if not Path(tile).exists():
                    raise SystemExit(f"missing tile {tile} for {part} stage {stage}")
                pairs += [f"{OUT}/{part}_{stage}.png", tile]
            run(a.godot, "res://games/tools/process_group.gd", [str(SIZE), *pairs])
            print(f"  OK {part}: {len(idxs)} stages (proportional)")
    subprocess.run([a.godot, "--headless", "--path", ".", "--import"], check=False)
    print("done -> ui/lvl_parts")
    return 0


if __name__ == "__main__":
    sys.exit(main())
