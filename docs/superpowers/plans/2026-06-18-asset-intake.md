# Asset Intake Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a manifest-driven asset-intake process: an agent classifies each raw image dropped in `_new/` and authors a `plan.json`; a deterministic Python runner (`make intake`) applies the plan — dispatching to the existing godot image tools and archiving the raw.

**Architecture:** A pure-stdlib Python orchestrator (`games/tools/intake_apply.py`) reads each `*.plan.json`, dispatches by `category` to an existing godot tool via subprocess (`process_icon`, `process_decor`, `slice_grid`, `slice_islands`, `cutout_bg`), writes the named outputs, then **moves** the raw to its archive and the plan to a `_processed/` log. The runner holds zero judgment — classification, naming, and params all live in the plan, authored by the agent. The orchestration logic (validation, arg-building, file moves) is pure and unit-tested with stdlib `unittest`; the godot subprocess calls are exercised by an end-to-end smoke task.

**Tech Stack:** Python 3 (stdlib only — `json`, `pathlib`, `shutil`, `subprocess`, `argparse`, `unittest`), Godot 4 headless (the existing `games/tools/*.gd` image tools), Make.

---

## Reference — facts the engineer needs

**Asset root:** `games/grove/assets/` (this is `ART_ROOT`, `game.gd:7`). Every plan path (`source`, `archive`, each `outputs[].path`) is relative to this root.

**Drop folder:** `games/grove/assets/_new/` (exists; currently holds `bag.png`, `bag_asset.png`, `shop.png`, `shop_asset.png`).

**Existing godot tools and their exact CLI (verified by reading each tool's header):**

| Tool (`res://games/tools/…`) | CLI (`-- …`) | Behavior |
|---|---|---|
| `process_icon.gd` | `<in.png> <out_abs> [size]` or `<in.png> <out_abs> [w h]` | trim + center + square transparent PNG (default 512, `PAD=14`) |
| `process_decor.gd` | `<in.png> <out_abs> [W H] [--opaque] [--cover]` | fit onto fixed canvas (default 1024×1280), position preserved |
| `slice_grid.gd` | `<in.png> <out_prefix>` | band-detect cells → writes `<out_prefix>0.png`, `<out_prefix>1.png`, … row-major |
| `slice_islands.gd` | `<in.png> <out_prefix> [val_min=0.90] [sat_max=0.10] [min_area=600] [pad=3]` | flood-fill bright bg → 8-conn islands → writes `<out_prefix>0.png`, … and **prints** `n -> x,y wxh (px=count)` sorted top→bottom, left→right |
| `cutout_bg.gd` | `<png> [png …] [min=600]` | clears bright+achromatic regions ≥ min area **in place** (edits the file given) |

A godot tool is run as: `godot --headless --path . -s <res_tool> -- <args…>`. The `GODOT` binary may be overridden (Makefile already uses `GODOT ?= godot`).

**Manifest schema** (from the spec, `docs/superpowers/specs/2026-06-18-asset-intake-design.md`):

```json
{
  "source": "_new/bag_asset.png",
  "category": "sheet",
  "inner": "icon",
  "params": { "min_area": 400 },
  "outputs": [
    { "island": 3, "name": "nav_bag",   "path": "ui/kit/nav_bag.png", "post": "icon:512" },
    { "island": 0, "name": "panel_bag", "path": "ui/kit/panel_bag.png" }
  ],
  "archive": "_originals/ui/bag_asset.png"
}
```

- `category` ∈ `icon | decor | grid | sheet | scene | matte`.
- `inner` required **only** when `category == "matte"` (the category to re-dispatch to after keying).
- `outputs` is one entry for `icon`/`decor`; one entry per kept slice for `grid`/`sheet` (keyed by `tile`/`island` integer index); absent/ignored for `scene`.
- `outputs[].post` optional follow-up, currently only `"icon:<size>"` or `"icon:<w>x<h>"`.
- `scene` plans need only `source` + `category` — the runner hands them off, does not pixel-process.

---

## Task 1: Runner scaffold — plan load + validation

**Files:**
- Create: `games/tools/intake_apply.py`
- Create: `games/tools/test_intake_apply.py`

- [ ] **Step 1: Write the failing tests**

Create `games/tools/test_intake_apply.py`:

```python
#!/usr/bin/env python3
"""Unit tests for the asset-intake runner (pure-stdlib, no godot needed)."""
import sys, unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import intake_apply as ia


class ValidateTests(unittest.TestCase):
    def _ok(self, plan):
        ia.validate_plan(plan)  # raises on bad

    def test_minimal_icon_ok(self):
        self._ok({"source": "_new/a.png", "category": "icon",
                  "outputs": [{"path": "ui/a.png"}], "archive": "_originals/ui/a.png"})

    def test_scene_needs_only_source_and_category(self):
        self._ok({"source": "_new/m.png", "category": "scene"})

    def test_missing_source_rejected(self):
        with self.assertRaises(ia.PlanError):
            self._ok({"category": "icon", "outputs": [{"path": "x"}],
                      "archive": "_originals/x.png"})

    def test_unknown_category_rejected(self):
        with self.assertRaises(ia.PlanError):
            self._ok({"source": "s", "category": "audio",
                      "outputs": [{"path": "x"}], "archive": "a"})

    def test_matte_requires_inner(self):
        with self.assertRaises(ia.PlanError):
            self._ok({"source": "s", "category": "matte",
                      "outputs": [{"path": "x"}], "archive": "a"})

    def test_sheet_output_needs_index(self):
        with self.assertRaises(ia.PlanError):
            self._ok({"source": "s", "category": "sheet",
                      "outputs": [{"path": "x"}], "archive": "a"})

    def test_sheet_output_with_index_ok(self):
        self._ok({"source": "s", "category": "sheet",
                  "outputs": [{"island": 0, "path": "x"}], "archive": "a"})


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 games/tools/test_intake_apply.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'intake_apply'` (the module doesn't exist yet).

- [ ] **Step 3: Write the minimal module**

Create `games/tools/intake_apply.py`:

```python
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
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python3 games/tools/test_intake_apply.py -v`
Expected: PASS — all 7 `ValidateTests` pass.

- [ ] **Step 5: Commit**

```bash
git add games/tools/intake_apply.py games/tools/test_intake_apply.py
git commit -m "feat(intake): runner scaffold — plan load + validation"
```

---

## Task 2: Argument builders + post-op parsing

**Files:**
- Modify: `games/tools/intake_apply.py` (append functions)
- Modify: `games/tools/test_intake_apply.py` (append a test class)

- [ ] **Step 1: Write the failing tests**

Append to `games/tools/test_intake_apply.py` (before the `if __name__` line):

```python
class ArgTests(unittest.TestCase):
    def test_icon_args_default_size(self):
        self.assertEqual(ia.icon_args("/in.png", "/out.png", {}),
                         ["/in.png", "/out.png"])

    def test_icon_args_square_size(self):
        self.assertEqual(ia.icon_args("/in.png", "/out.png", {"size": 256}),
                         ["/in.png", "/out.png", "256"])

    def test_icon_args_wh_size(self):
        self.assertEqual(ia.icon_args("/in.png", "/out.png", {"size": [300, 400]}),
                         ["/in.png", "/out.png", "300", "400"])

    def test_decor_args_opaque_canvas(self):
        self.assertEqual(
            ia.decor_args("/in.png", "/out.png", {"w": 1024, "h": 1280, "opaque": True}),
            ["/in.png", "/out.png", "1024", "1280", "--opaque"])

    def test_decor_args_bare(self):
        self.assertEqual(ia.decor_args("/in.png", "/out.png", {}),
                         ["/in.png", "/out.png"])

    def test_grid_slice_args(self):
        self.assertEqual(ia.slice_args("grid", "/in.png", "/scratch/s_", {}),
                         ["/in.png", "/scratch/s_"])

    def test_sheet_slice_args_uses_params(self):
        self.assertEqual(
            ia.slice_args("sheet", "/in.png", "/scratch/s_", {"min_area": 400, "pad": 5}),
            ["/in.png", "/scratch/s_", "0.9", "0.1", "400", "5"])

    def test_parse_post_none(self):
        self.assertIsNone(ia.parse_post(None))

    def test_parse_post_icon_size(self):
        self.assertEqual(ia.parse_post("icon:512"), {"size": 512})

    def test_parse_post_icon_wh(self):
        self.assertEqual(ia.parse_post("icon:300x400"), {"size": [300, 400]})

    def test_parse_post_unknown_rejected(self):
        with self.assertRaises(ia.PlanError):
            ia.parse_post("blur:3")
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 games/tools/test_intake_apply.py -v`
Expected: FAIL — `AttributeError: module 'intake_apply' has no attribute 'icon_args'`.

- [ ] **Step 3: Write the minimal implementation**

Append to `games/tools/intake_apply.py`:

```python
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
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python3 games/tools/test_intake_apply.py -v`
Expected: PASS — `ValidateTests` + `ArgTests` all pass.

- [ ] **Step 5: Commit**

```bash
git add games/tools/intake_apply.py games/tools/test_intake_apply.py
git commit -m "feat(intake): per-category argument builders + post-op parsing"
```

---

## Task 3: File-move helpers — archive raw + log plan

**Files:**
- Modify: `games/tools/intake_apply.py` (append functions)
- Modify: `games/tools/test_intake_apply.py` (append a test class)

- [ ] **Step 1: Write the failing tests**

Append to `games/tools/test_intake_apply.py` (before the `if __name__` line):

```python
import tempfile


class FileMoveTests(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())

    def test_archive_raw_moves_and_makes_parent(self):
        root = self.tmp
        (root / "_originals" / "new").mkdir(parents=True)
        src = root / "_originals" / "new" / "a.png"
        src.write_bytes(b"PNG")
        ia.archive_raw("_new/a.png", "_originals/ui/a.png", root=root)
        self.assertFalse(src.exists())
        self.assertEqual((root / "_originals" / "ui" / "a.png").read_bytes(), b"PNG")

    def test_log_plan_moves_into_processed(self):
        plan = self.tmp / "a.plan.json"
        plan.write_text("{}")
        processed = self.tmp / "_processed"
        ia.log_plan(plan, processed=processed)
        self.assertFalse(plan.exists())
        self.assertTrue((processed / "a.plan.json").exists())
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 games/tools/test_intake_apply.py -v`
Expected: FAIL — `AttributeError: module 'intake_apply' has no attribute 'archive_raw'`.

- [ ] **Step 3: Write the minimal implementation**

Append to `games/tools/intake_apply.py`:

```python
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
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python3 games/tools/test_intake_apply.py -v`
Expected: PASS — `ValidateTests` + `ArgTests` + `FileMoveTests` all pass.

- [ ] **Step 5: Commit**

```bash
git add games/tools/intake_apply.py games/tools/test_intake_apply.py
git commit -m "feat(intake): archive-raw + log-plan file-move helpers"
```

---

## Task 4: Orchestration — process_plan, matte prep, reimport, CLI

This task wires the pieces into the end-to-end runner. It is exercised by the smoke task (Task 8), not by a unit test (it spawns godot).

**Files:**
- Modify: `games/tools/intake_apply.py` (append functions + `main`)

- [ ] **Step 1: Append the subprocess + orchestration code**

Append to `games/tools/intake_apply.py`:

```python
import argparse
import os
import subprocess
import sys


def run_tool(godot: str, tool_res: str, args: list[str]) -> str:
    cmd = [godot, "--headless", "--path", ".", "-s", tool_res, "--", *args]
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        raise PlanError(f"tool failed: {tool_res}\n{r.stdout}\n{r.stderr}")
    return r.stdout


def reimport(godot: str) -> None:
    subprocess.run([godot, "--headless", "--path", ".", "--import"], check=False)


def process_plan(plan_path: Path, godot: str) -> None:
    plan = load_plan(plan_path)
    validate_plan(plan)
    cat = plan["category"]
    src_rel = plan["source"]

    if cat == "scene":
        print(f"  SCENE {src_rel} — handed off to the §16 map flow "
              f"(docs/design/grove_art_pipeline.md); not processed by make intake.")
        return

    src_abs = abspath(src_rel)
    params = plan.get("params", {})
    eff = cat

    # matte: key out the bright background in place on a scratch copy, then re-dispatch.
    if cat == "matte":
        eff = plan["inner"]
        SCRATCH.mkdir(parents=True, exist_ok=True)
        keyed = SCRATCH / ("matte_" + Path(src_rel).name)
        shutil.copy(src_abs, keyed)
        run_tool(godot, TOOLS["matte"],
                 [str(keyed.resolve()), f"min={params.get('min_area', 600)}"])
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
```

- [ ] **Step 2: Verify the module still imports and unit tests stay green**

Run: `python3 games/tools/test_intake_apply.py -v`
Expected: PASS — all three test classes still pass (the appended code adds no behavior the unit tests touch, and the new imports load cleanly).

- [ ] **Step 3: Verify the CLI parses and handles an empty drop**

Run: `python3 games/tools/intake_apply.py --plan /nonexistent.plan.json --no-import`
Expected: prints `  SKIP /nonexistent.plan.json: cannot read plan …` and exits non-zero (no traceback).

- [ ] **Step 4: Commit**

```bash
git add games/tools/intake_apply.py
git commit -m "feat(intake): end-to-end orchestration — dispatch, matte prep, archive, CLI"
```

---

## Task 5: Makefile targets

**Files:**
- Modify: `Makefile`

- [ ] **Step 1: Add the targets**

In `Makefile`, the `.PHONY` declaration spans three backslash-continued lines ending with `decor icon ios clean clean-cache`. Append ` intake intake-test` to that last continuation line, so it reads `decor icon ios clean clean-cache intake intake-test`.

Then, under the `## --- assets ---` section (right after the `import:` target block), insert:

```make
intake: ## apply intake plans in _new/ (agent authors plan.json first): make intake [PLAN=path]
	python3 games/tools/intake_apply.py --godot $(GODOT) $(if $(PLAN),--plan $(PLAN),)

intake-test: ## unit-test the intake runner (pure stdlib, no godot)
	python3 games/tools/test_intake_apply.py
```

- [ ] **Step 2: Verify `make intake-test` runs the suite green**

Run: `make intake-test`
Expected: PASS — `unittest` reports `OK` for all tests.

- [ ] **Step 3: Verify `make help` lists the new targets**

Run: `make help`
Expected: output includes `intake` and `intake-test` rows with their descriptions.

- [ ] **Step 4: Verify `make intake` no-ops cleanly when no plans exist**

Run: `make intake`
Expected: prints `no *.plan.json in games/grove/assets/_new` (the `bag*`/`shop*` raws have no plan yet, so nothing is processed) and exits 0.

- [ ] **Step 5: Commit**

```bash
git add Makefile
git commit -m "feat(intake): make intake + make intake-test targets"
```

---

## Task 6: The agent runbook

**Files:**
- Create: `docs/design/asset-intake.md`

- [ ] **Step 1: Write the runbook**

Create `docs/design/asset-intake.md`:

```markdown
# Asset intake — runbook

How to take a raw image from "dropped in a folder" to "processed, renamed, filed." Design +
rationale: `docs/superpowers/specs/2026-06-18-asset-intake-design.md`.

**The split:** *you* (the agent) make every judgment — classify, name, pick params. The scripts do
every pixel op and every file move. Same plan + same source → identical result.

## When to run

Raw art lands in `games/grove/assets/_new/` whenever the artist drops it. Nothing watches
the folder. When the Dev says "pick up the new art" (or similar), run this loop.

## The loop

1. **List the drop.** `ls games/grove/assets/_new/`. Artists often deliver a pair:
   `X.png` (composed reference, usually not shipped) + `X_asset.png` (a sheet of the pieces). Treat
   `*_asset.png` as the sliceable source.

2. **Open each image and classify it** into one `category`. Paths below are relative to
   `games/grove/assets/`.

   | Look | `category` | Tool | Default folder |
   |---|---|---|---|
   | one subject, want a clean square icon | `icon` | `process_icon.gd` | `ui/` |
   | a background / layer, keep its position | `decor` | `process_decor.gd` | `rooms/` |
   | an even sheet of items (a line's tiers) | `grid` | `slice_grid.gd` → `process_icon` | `items/` |
   | an irregular sheet of UI pieces | `sheet` | `slice_islands.gd` | `ui/kit/` |
   | a map locale | `scene` | **hand off** to the §16 flow (`grove_art_pipeline.md`) | `map/` |
   | any of the above but on a baked white/bright background | `matte` (+ `inner`) | `cutout_bg.gd` then the inner tool | (inner) |

   If it fits none of these, **park it back to the Dev** — do not force a category.

3. **For `sheet`/`grid`: slice once to scratch and read the indices** before naming. The runner
   uses the same indices, so this is how you map index → name:

   ```
   godot --headless --path . -s res://games/tools/slice_islands.gd -- \
     games/grove/assets/_new/bag_asset.png /tmp/peek/cell_
   ```

   `slice_islands` prints `n -> x,y wxh (px=count)` top→bottom, left→right. Open the `/tmp/peek/cell_<n>.png`
   files, decide which islands to keep and what to call each.

4. **Write the plan** as `<name>.plan.json` next to the raw in `_new/`. Schema:

   ```json
   {
     "source": "_new/bag_asset.png",
     "category": "sheet",
     "params": { "min_area": 400 },
     "outputs": [
       { "island": 3, "name": "nav_bag",   "path": "ui/kit/nav_bag.png", "post": "icon:512" },
       { "island": 0, "name": "panel_bag", "path": "ui/kit/panel_bag.png" }
     ],
     "archive": "_originals/ui/bag_asset.png"
   }
   ```

   - `icon`/`decor`: one `outputs` entry (`{ "path": "..." }`); put size/canvas in `params`
     (`{"size": 512}` or `{"w":1024,"h":1280,"opaque":true}`).
   - `grid`/`sheet`: one entry per kept slice, keyed by `tile`/`island` index; add `"post": "icon:512"`
     to clean each slice into a square icon.
   - `matte`: add `"inner": "<category>"`; `params.min_area` controls the keyer.
   - `scene`: just `{ "source": "...", "category": "scene" }` — the runner prints a hand-off.
   - `archive` is where the raw moves after success (under `_originals/<kind>/`).

5. **Apply it.** `make intake` (all pending plans) or `make intake PLAN=<file>` (one). The runner
   writes the outputs, **moves** the raw to `archive`, moves the plan to `_new/_processed/`, and
   reimports. On any tool failure it **skips** that plan and leaves the raw in place for a retry.

6. **Verify.** Confirm the outputs landed (`ls` the target folder), the raw is gone from `new/`, and
   the plan is in `_new/_processed/`. For in-engine checks use `make shot-grove` / `make shot-map`.
   Keep `make test` green.

## Principles

- Scripts never guess. If you find yourself wanting the runner to "figure out" a name or a category,
  that belongs in the plan — author it there.
- Raws are archived, never deleted.
- Map scenes stay with the §16 pipeline; don't try to automate the share-gate.
```

- [ ] **Step 2: Sanity-check the doc renders and links resolve**

Run: `ls docs/design/asset-intake.md docs/design/grove_art_pipeline.md docs/superpowers/specs/2026-06-18-asset-intake-design.md`
Expected: all three paths exist (the runbook's cross-references are valid).

- [ ] **Step 3: Commit**

```bash
git add docs/design/asset-intake.md
git commit -m "docs(intake): agent runbook — classify, plan, make intake, verify"
```

---

## Task 7: Project-root CLAUDE.md trigger

**Files:**
- Create: `CLAUDE.md`

- [ ] **Step 1: Check no project-root CLAUDE.md already exists**

Run: `ls CLAUDE.md 2>&1`
Expected: `ls: CLAUDE.md: No such file or directory` (confirms we are creating, not clobbering). If it *does* exist, append the Asset-intake section instead of overwriting.

- [ ] **Step 2: Write the trigger**

Create `CLAUDE.md`:

```markdown
# Tidy Up (Donguri Merge) — project notes

## Asset intake

Raw art lands in `games/grove/assets/_new/`. When asked to process intake or "pick up the
new art," follow `docs/design/asset-intake.md`: open and **classify** each drop, author a
`plan.json`, run `make intake`, verify, archive.

The split is load-bearing: **scripts are deterministic** (every pixel op + every file move);
**all judgment — classification, naming, params — goes in the plan**, authored by the agent. Scripts
never guess. Raws are archived, never deleted. Map scenes are handed off to the §16 flow in
`docs/design/grove_art_pipeline.md`, not auto-processed.
```

- [ ] **Step 3: Verify it is valid and discoverable**

Run: `cat CLAUDE.md | head -3`
Expected: prints the title and the start of the Asset-intake section.

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md
git commit -m "docs(intake): project-root CLAUDE.md trigger pointing at the runbook"
```

---

## Task 8: End-to-end smoke (real godot, deterministic fixture)

Proves the whole pipe — plan → godot tool → output written → raw archived → plan logged — using an
existing repo PNG as a throwaway `icon` fixture (no naming judgment, fully reproducible). All
fixture artifacts live under a `_intaketest/` folder that is deleted at the end.

**Files:** none committed (this task creates and removes a temporary fixture).

- [ ] **Step 1: Stage a fixture raw + plan**

```bash
mkdir -p games/grove/assets/_new
FIX=$(ls games/grove/assets/ui/*.png | head -1)
cp "$FIX" games/grove/assets/_new/_intaketest.png
cat > games/grove/assets/_new/_intaketest.plan.json <<'JSON'
{
  "source": "_new/_intaketest.png",
  "category": "icon",
  "params": { "size": 64 },
  "outputs": [ { "path": "_originals/_intaketest/out.png" } ],
  "archive": "_originals/_intaketest/raw.png"
}
JSON
```

- [ ] **Step 2: Run the runner on just that plan**

Run: `make intake PLAN=games/grove/assets/_new/_intaketest.plan.json`
(process_icon on a small PNG finishes in seconds; it does not open a window.)
Expected: prints `  OK _new/_intaketest.png -> 1 output(s); raw archived to _originals/_intaketest/raw.png`.

- [ ] **Step 3: Assert the outputs are correct**

```bash
ls games/grove/assets/_originals/_intaketest/out.png \
   games/grove/assets/_originals/_intaketest/raw.png \
   games/grove/assets/_new/_processed/_intaketest.plan.json
test ! -e games/grove/assets/_new/_intaketest.png && echo "RAW REMOVED FROM DROP: ok"
```
Expected: all three listed files exist, and `RAW REMOVED FROM DROP: ok` prints (the raw moved out of `new/`).

- [ ] **Step 4: Confirm the failure path leaves the raw in place**

```bash
cp "$(ls games/grove/assets/ui/*.png | head -1)" games/grove/assets/_new/_intakebad.png
cat > games/grove/assets/_new/_intakebad.plan.json <<'JSON'
{ "source": "_new/_intakebad.png", "category": "icon",
  "outputs": [ { "path": "_originals/_intaketest/bad.png" } ] }
JSON
make intake PLAN=games/grove/assets/_new/_intakebad.plan.json ; echo "exit=$?"
test -e games/grove/assets/_new/_intakebad.png && echo "RAW KEPT ON FAILURE: ok"
```
Expected: prints `  SKIP _intakebad.plan.json: missing required field: archive`, `exit=1`, and `RAW KEPT ON FAILURE: ok` (a bad plan never deletes the raw).

- [ ] **Step 5: Clean up every fixture artifact**

```bash
rm -rf games/grove/assets/_originals/_intaketest
rm -f  games/grove/assets/_new/_intakebad.png \
       games/grove/assets/_new/_intakebad.plan.json \
       games/grove/assets/_new/_processed/_intaketest.plan.json
rmdir  games/grove/assets/_new/_processed 2>/dev/null || true
git status --short games/grove/assets/_new
```
Expected: `git status --short` shows no leftover `_intaketest`/`_intakebad` files (only the pre-existing untracked `bag*`/`shop*` raws, if any, remain). Nothing to commit for this task.

---

## Task 9: Dogfood — process the real `bag_asset.png` drop

The live acceptance run: the actual agent loop on the real art already sitting in `new/`. This one
involves judgment (naming the sliced islands) — that is the design working as intended, not a gap.

**Files:**
- Create: `games/grove/assets/_new/bag.plan.json` (then logged to `_processed/` by the run)
- Result: new PNGs under `games/grove/assets/ui/kit/` + the raw moved to `_originals/ui/`

- [ ] **Step 1: Inspect the sheet's islands**

```bash
mkdir -p /tmp/bagpeek
godot --headless --path . -s res://games/tools/slice_islands.gd -- \
  games/grove/assets/_new/bag_asset.png /tmp/bagpeek/cell_
ls /tmp/bagpeek
```
Expected: prints one `n -> x,y wxh (px=...)` line per island and writes `/tmp/bagpeek/cell_<n>.png`.

- [ ] **Step 2: Decide the keep-list and names (agent judgment)**

Open the `/tmp/bagpeek/cell_<n>.png` tiles. For each island you want to ship, decide its kit name and
target path under `ui/kit/`. Cross-check existing kit names with `ls games/grove/assets/ui/kit/` so
you reuse the established vocabulary (e.g. `nav_bag.png`, `panel_*.png`). Drop specks/duplicates.

- [ ] **Step 3: Author the plan**

Create `games/grove/assets/_new/bag.plan.json`, filling `outputs` from Step 2 — one entry
per kept island, `island` set to its printed index, `path` to its `ui/kit/<name>.png`, and
`post: "icon:512"` on any piece that should be trimmed to a square icon (omit `post` for pieces whose
exact placement/size matters, e.g. a panel). Example shape (replace indices/names with your Step-2
mapping):

```json
{
  "source": "_new/bag_asset.png",
  "category": "sheet",
  "params": { "min_area": 600 },
  "outputs": [
    { "island": 0, "name": "<name>", "path": "ui/kit/<name>.png", "post": "icon:512" }
  ],
  "archive": "_originals/ui/bag_asset.png"
}
```

- [ ] **Step 4: Apply it**

Run: `make intake PLAN=games/grove/assets/_new/bag.plan.json`
Expected: `  OK _new/bag_asset.png -> N output(s); raw archived to _originals/ui/bag_asset.png`.

- [ ] **Step 5: Verify**

```bash
ls games/grove/assets/ui/kit/                # new kit PNGs present
ls games/grove/assets/_originals/ui/bag_asset.png   # raw archived
ls games/grove/assets/_new/_processed/bag.plan.json  # plan logged
make test                                    # regression: still green
```
Expected: the kit PNGs you named exist, the raw is archived, the plan is logged, and `make test` passes (intake only added files; no engine code changed).

- [ ] **Step 6: Commit**

```bash
git add games/grove/assets/ui/kit games/grove/assets/_originals/ui/bag_asset.png \
        games/grove/assets/_new/_processed/bag.plan.json
git commit -m "assets(intake): process bag_asset sheet into ui/kit via make intake"
```

(Leave `bag.png`, `shop.png`, `shop_asset.png` for a later intake pass — out of scope here.)

---

## Self-review notes

- **Spec coverage:** drop convention (Tasks 6/7 doc it; Task 8/9 use it) · manifest schema (Task 1 validates, Tasks 6/9 document/use) · taxonomy (Task 1 `VALID`/`SINGLE`/`SLICED`, Task 6 table) · runner dispatch + archive + log + reimport (Task 4) · failure-before-archive (Task 4, asserted Task 8 Step 4) · matte prefix→inner (Tasks 1/4) · scene hand-off (Tasks 1/4/6) · instructions location (Tasks 6/7) · `make intake` (Task 5) · verification reuse (Tasks 8/9). All spec sections map to a task.
- **Type/name consistency:** `icon_args`/`decor_args`/`slice_args`/`parse_post`/`archive_raw`/`log_plan`/`abspath`/`run_tool`/`reimport`/`process_plan`/`main` are defined once (Tasks 1–4) and referenced with the same signatures throughout. `parse_post` returns the `params`-shaped dict that `icon_args` consumes (`{"size": …}`), matching Task 4's `icon_args(str(cell), out_abs, post)` call.
- **No placeholders:** every code step shows complete code; the only deliberate human-judgment points are Task 9 Steps 2–3 (naming islands), which is the design's intended agent decision, not an unfilled blank.
```
