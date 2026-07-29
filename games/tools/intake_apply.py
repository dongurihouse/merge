#!/usr/bin/env python3
"""Apply asset-intake plan.json files: dispatch to godot image tools, archive raws.

Deterministic runner for the asset-intake process (docs/design/art-style-guide.md §9).
All judgment lives in the plan; this script only executes it.

  python3 games/tools/intake_apply.py [--godot godot] [--plan FILE] [--no-import]

Run from the repo root (paths in a plan are relative to games/grove/assets/).
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

ASSET_ROOT = Path("games/grove/assets")
DROP = ASSET_ROOT / "_new"                  # raw-drop inbox (gdignored; not imported)
PROCESSED = DROP / "_processed"
SCRATCH = Path(".godot") / "intake_scratch"

TOOLS = {
    "icon":  "res://games/tools/process_icon.gd",
    "decor": "res://games/tools/process_decor.gd",
    "grid":  "res://games/tools/slice_grid.gd",
    "sheet": "res://games/tools/slice_islands.gd",
    "matte": "res://games/tools/cutout_bg.gd",
}
CHROMA_TOOL = "res://games/tools/chroma_key.gd"   # matte keyer for saturated backgrounds
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
    if params.get("anchor") == "bottom":
        a.append("--bottom")     # process_icon anchors the trimmed art to the canvas bottom
    if params.get("despill"):
        a.append("--despill")    # …and re-applies the §8 magenta despill after the resize
    return a


def decor_args(src_abs: str, out_abs: str, params: dict) -> list[str]:
    a = [src_abs, out_abs]
    w, h = params.get("w"), params.get("h")
    if w is not None and h is not None:
        a += [str(w), str(h)]
    if params.get("opaque"):
        a.append("--opaque")
    if params.get("cover"):
        a.append("--cover")
    return a


def slice_args(eff: str, src_abs: str, prefix: str, params: dict) -> list[str]:
    if eff == "grid":
        return [src_abs, prefix]
    # sheet: <in> <prefix> [val_min sat_max min_area pad] — defaults match slice_islands.gd
    return [src_abs, prefix,
            str(params.get("val_min", 0.9)), str(params.get("sat_max", 0.1)),
            str(params.get("min_area", 600)), str(params.get("pad", 3))]


def matte_tool_and_args(keyed_abs: str, params: dict) -> tuple[str, list[str]]:
    """Pick the matte keyer for a scratch copy: chroma_key when a `key` colour is given
    (saturated backgrounds), else cutout_bg (bright/white backgrounds).

    `"hue": true` selects chroma_key's magenta-excess mode — required when the art casts a
    DROP SHADOW onto the key, since that shadow is darkened key colour that no distance
    tolerance can remove without also eating mauve/purple subject pixels."""
    if params.get("hue"):
        return CHROMA_TOOL, [keyed_abs, "hue=1",
                             f"soft={params.get('soft', 55)}", f"hard={params.get('hard', 100)}"]
    key = params.get("key")
    if key:
        return CHROMA_TOOL, [keyed_abs, f"key={key}", f"tol={params.get('tol', 0.18)}"]
    return TOOLS["matte"], [keyed_abs, f"min={params.get('min_area', 600)}"]


def matte_passes(keyed_abs: str, params: dict) -> list[tuple[str, list[str]]]:
    """The keyer passes to run over the scratch copy, in order.

    Usually one. A sheet that has BOTH walled-in key pockets AND a contaminated anti-aliased
    edge band needs two, because neither pass alone clears the guide's §8 gate:
      • the DISTANCE pass (`key`/`tol`) is per-pixel, so it reaches a pocket enclosed by the
        art — the "leftover pockets" count — but it cuts on a hard threshold, which leaves the
        anti-aliased boundary tinted;
      • the HUE pass (`hue`) ramps and despills that boundary — the "key fringe" count — but it
        only touches pixels a flood from the border can reach, so an enclosed pocket survives it.
    Asking for `key` AND `hue` in one plan runs the distance pass first, then the hue pass.
    """
    passes = []
    if params.get("hue") and params.get("key"):
        passes.append((CHROMA_TOOL, [keyed_abs, f"key={params['key']}",
                                     f"tol={params.get('tol', 0.18)}"]))
    passes.append(matte_tool_and_args(keyed_abs, params))
    return passes


def parse_post(post: str | None) -> dict | None:
    """Parse an output post-op into params for icon_args.

    'icon:512'        -> {'size': 512}                       (square 512, centered)
    'icon:300x400'    -> {'size': [300, 400]}                (fit into 300x400, centered)
    'icon:512:bottom' -> {'size': 512, 'anchor': 'bottom'}   (square 512, bottom-anchored)
    'icon::bottom'    -> {'anchor': 'bottom'}                (default size, bottom-anchored)
    'icon:512:despill'-> {'size': 512, 'despill': True}      (square 512, §8 despill after resize)
    'icon' / 'icon:'  -> {}                                  (clean to default size, centered)
    None / ''         -> None                                (no post-op; copy the slice as-is)

    The tokens after the size are an unordered flag SET, so 'icon:512:bottom:despill' is legal.
    """
    if not post:
        return None
    name, _, arg = post.partition(":")
    if name != "icon":
        raise PlanError(
            f"unknown post op: {post!r} (only 'icon:<size>[:bottom][:despill]' is supported)")
    parts = arg.split(":") if arg else []
    size_part = parts[0] if parts else ""
    out: dict = {}
    for flag in parts[1:]:
        if flag == "bottom":
            out["anchor"] = "bottom"
        elif flag == "despill":
            out["despill"] = True
        elif flag:
            raise PlanError(f"unknown flag {flag!r} in {post!r} (only 'bottom' / 'despill')")
    if size_part:
        out["size"] = [int(w) for w in size_part.split("x")] if "x" in size_part \
            else int(size_part)
    return out


def abspath(rel_under_asset_root: str, root: Path = ASSET_ROOT) -> str:
    return str((root / rel_under_asset_root).resolve())


def archive_raw(source_rel: str, archive_rel: str, root: Path = ASSET_ROOT) -> None:
    dst = root / archive_rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.move(str(root / source_rel), str(dst))


def log_plan(plan_path: Path, processed: Path = PROCESSED) -> None:
    processed.mkdir(parents=True, exist_ok=True)
    shutil.move(str(plan_path), str(processed / Path(plan_path).name))


def run_tool(godot: str, tool_res: str, args: list[str]) -> str:
    cmd = [godot, "--headless", "--path", ".", "-s", tool_res, "--", *args]
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        raise PlanError(f"tool failed: {tool_res}\n{r.stdout}\n{r.stderr}")
    return r.stdout


def reimport(godot: str) -> None:
    r = subprocess.run([godot, "--headless", "--path", ".", "--import"], check=False)
    if r.returncode != 0:
        print(f"  WARN godot --import returned {r.returncode}; "
              f"new files may not be picked up — run `make import` manually.")


def process_plan(plan_path: Path, godot: str) -> None:
    plan = load_plan(plan_path)
    validate_plan(plan)
    cat = plan["category"]
    src_rel = plan["source"]

    if cat == "scene":
        print(f"  SCENE {src_rel} — handed off to the scene pipeline "
              f"(docs/design/art-style-guide.md §11); not processed by make intake.")
        return

    src_abs = abspath(src_rel)
    params = plan.get("params", {})
    eff = cat

    # matte: key out the bright background in place on a scratch copy, then re-dispatch.
    # params is shared with the inner category; the inner arg-builders ignore the
    # matte-only key (min_area), so a single params block carries both.
    if cat == "matte":
        eff = plan["inner"]
        SCRATCH.mkdir(parents=True, exist_ok=True)
        keyed = SCRATCH / ("matte_" + Path(src_rel).name)
        shutil.copy(src_abs, keyed)
        for tool_res, margs in matte_passes(str(keyed.resolve()), params):
            run_tool(godot, tool_res, margs)
        src_abs = str(keyed.resolve())

    if eff in SINGLE:
        out = plan["outputs"][0]
        out_abs = abspath(out["path"])
        Path(out_abs).parent.mkdir(parents=True, exist_ok=True)
        args = icon_args(src_abs, out_abs, params) if eff == "icon" \
            else decor_args(src_abs, out_abs, params)
        run_tool(godot, TOOLS[eff], args)
    elif eff in SLICED:
        SCRATCH.mkdir(parents=True, exist_ok=True)
        prefix = str((SCRATCH / "slice_").resolve())
        run_tool(godot, TOOLS[eff], slice_args(eff, src_abs, prefix, params))
        for o in plan["outputs"]:
            idx = o.get("island", o.get("tile"))
            cell = Path(f"{prefix}{idx}.png")
            if not cell.exists():
                raise PlanError(f"slice index {idx} not produced ({cell})")
            out_abs = abspath(o["path"])
            Path(out_abs).parent.mkdir(parents=True, exist_ok=True)
            post = parse_post(o.get("post"))
            if post is not None:
                run_tool(godot, TOOLS["icon"], icon_args(str(cell), out_abs, post))
            else:
                shutil.copy(str(cell), out_abs)

    # Only after every output succeeded: archive the raw and log the plan.
    archive_raw(src_rel, plan["archive"])
    log_plan(plan_path)
    print(f"  OK {src_rel} -> {len(plan['outputs'])} output(s); "
          f"raw archived to {plan['archive']}")


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="Apply asset-intake plan.json files.")
    ap.add_argument("--godot", default=os.environ.get("GODOT", "godot"))
    ap.add_argument("--plan", default=None, help="process only this plan file")
    ap.add_argument("--no-import", action="store_true",
                    help="skip the final godot --import")
    a = ap.parse_args(argv)

    plans = [Path(a.plan)] if a.plan else sorted(DROP.glob("*.plan.json"))
    if not plans:
        print(f"no *.plan.json in {DROP}")
        return 0

    failures = 0
    for p in plans:
        try:
            process_plan(p, a.godot)
        except PlanError as e:
            failures += 1
            print(f"  SKIP {p.name}: {e}")  # raw NOT archived — left in new/ for retry
    if not a.no_import and failures < len(plans):
        reimport(a.godot)
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
