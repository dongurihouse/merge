#!/usr/bin/env python3
"""Apply asset-intake plan.json files: dispatch to godot image tools, archive raws.

Deterministic runner for the asset-intake process (docs/design/asset-intake.md).
All judgment lives in the plan; this script only executes it.

  python3 games/tools/intake_apply.py [--godot godot] [--plan FILE] [--no-import]

Run from the repo root (paths in a plan are relative to games/grove/assets/).
"""
from __future__ import annotations

import json
from pathlib import Path

ASSET_ROOT = Path("games/grove/assets")
DROP = ASSET_ROOT / "_originals" / "new"
PROCESSED = DROP / "_processed"
SCRATCH = Path(".godot") / "intake_scratch"

TOOLS = {
    "icon":  "res://games/tools/process_icon.gd",
    "decor": "res://games/tools/process_decor.gd",
    "grid":  "res://games/tools/slice_grid.gd",
    "sheet": "res://games/tools/slice_islands.gd",
    "matte": "res://games/tools/cutout_bg.gd",
}
SINGLE = {"icon", "decor"}      # one source -> one output
SLICED = {"grid", "sheet"}      # one source -> many indexed slices
VALID = set(TOOLS) | {"scene"}


class PlanError(Exception):
    """A plan is malformed or a tool failed; the raw is left in new/ for retry."""


def load_plan(path: Path) -> dict:
    try:
        return json.loads(Path(path).read_text())
    except (OSError, ValueError) as e:
        raise PlanError(f"cannot read plan {path}: {e}")


def validate_plan(plan: dict) -> None:
    for key in ("source", "category"):
        if key not in plan:
            raise PlanError(f"missing required field: {key}")
    cat = plan["category"]
    if cat not in VALID:
        raise PlanError(f"unknown category: {cat} (valid: {sorted(VALID)})")
    if cat == "scene":
        return  # handed off; nothing else required
    for key in ("outputs", "archive"):
        if key not in plan:
            raise PlanError(f"missing required field: {key}")
    eff = cat
    if cat == "matte":
        eff = plan.get("inner")
        if eff not in (SINGLE | SLICED):
            raise PlanError(
                f"matte needs an inner category in {sorted(SINGLE | SLICED)}, got {eff!r}")
    outs = plan["outputs"]
    if not isinstance(outs, list) or not outs:
        raise PlanError("outputs must be a non-empty list")
    for o in outs:
        if "path" not in o:
            raise PlanError(f"each output needs a path: {o}")
    if eff in SLICED:
        for o in outs:
            idx = o.get("island", o.get("tile"))
            if not isinstance(idx, int):
                raise PlanError(f"sliced output needs an integer island/tile index: {o}")
