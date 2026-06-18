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


def icon_args(src_abs: str, out_abs: str, params: dict) -> list[str]:
    a = [src_abs, out_abs]
    size = params.get("size")
    if isinstance(size, (list, tuple)):
        a += [str(size[0]), str(size[1])]
    elif size is not None:
        a += [str(size)]
    return a


def decor_args(src_abs: str, out_abs: str, params: dict) -> list[str]:
    a = [src_abs, out_abs]
    w, h = params.get("w"), params.get("h")
    if w and h:
        a += [str(w), str(h)]
    if params.get("opaque"):
        a.append("--opaque")
    if params.get("cover"):
        a.append("--cover")
    return a


def slice_args(eff: str, src_abs: str, prefix: str, params: dict) -> list[str]:
    if eff == "grid":
        return [src_abs, prefix]
    # sheet: <in> <prefix> [val_min sat_max min_area pad]
    return [src_abs, prefix,
            str(params.get("val_min", 0.9)), str(params.get("sat_max", 0.1)),
            str(params.get("min_area", 600)), str(params.get("pad", 3))]


def parse_post(post: str | None) -> dict | None:
    """'icon:512' -> {'size': 512}; 'icon:300x400' -> {'size': [300,400]}; None -> None."""
    if not post:
        return None
    name, _, arg = post.partition(":")
    if name != "icon":
        raise PlanError(f"unknown post op: {post!r} (only 'icon:<size>' is supported)")
    if not arg:
        return {}
    if "x" in arg:
        w, h = arg.split("x")
        return {"size": [int(w), int(h)]}
    return {"size": int(arg)}


import shutil


def abspath(rel_under_asset_root: str, root: Path = ASSET_ROOT) -> str:
    return str((root / rel_under_asset_root).resolve())


def archive_raw(source_rel: str, archive_rel: str, root: Path = ASSET_ROOT) -> None:
    dst = root / archive_rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.move(str(root / source_rel), str(dst))


def log_plan(plan_path: Path, processed: Path = PROCESSED) -> None:
    processed.mkdir(parents=True, exist_ok=True)
    shutil.move(str(plan_path), str(processed / Path(plan_path).name))
