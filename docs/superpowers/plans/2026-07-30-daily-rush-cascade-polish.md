# Daily, Rush Loadout, and Cascade Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove Daily dialog image-processing stalls, enlarge the Rush loadout sheet, and prevent overlapping Cascade guide chains.

**Architecture:** Extend the existing kit bake pipeline with deterministic shape-shadow mirrors used by Daily. Keep Rush within the shared dialog-frame contract by deriving its width from the global frame setting. Filter Cascade resting candidates after their existing longest-first sort by reserving each accepted run's cells.

**Tech Stack:** Godot 4.6, GDScript, existing headless engine/Grove test harness, committed PNG bake mirrors.

## Global Constraints

- Daily visuals, rewards, timing, and layout remain unchanged.
- Rush boost behavior, costs, affordability behavior, and expedition transition remain unchanged.
- Cascade execution, rewards, scoring, and guide threshold remain unchanged.
- Production changes follow red-green-refactor and player-facing tests use real scene trees or real pointer taps.
- Work remains on `codex/daily-rush-cascade-polish` until full verification passes.

---

### Task 1: Prebake Daily shape shadows

**Files:**
- Modify: `games/grove/ui_kit.gd`
- Modify: `engine/scripts/ui/login.gd`
- Modify: `games/tools/bake_targets.gd`
- Modify: `games/tools/bake_textures.gd`
- Modify: `engine/tests/kit_bake_freshness_tests.gd`
- Modify: `games/grove/tests/grove_ui_workbench_tests.gd`
- Create: derived PNGs under `games/grove/assets/baked/`

**Interfaces:**
- Produces: `Kit.shadowed_baked_path(path: String, clean_cap: int, opts: Dictionary) -> String`
- Produces: `Kit.shadowed_tex_path(path: String, clean_cap: int, opts: Dictionary) -> Texture2D`
- Produces: `LoginUI.bake_shadow_specs() -> Array[Dictionary]`
- Consumes: existing `Kit._clean_image`, `Kit.add_drop_shadow`, and `LoginUI._rebuild`

- [ ] **Step 1: Write failing bake/runtime tests**

Add a freshness-loop over `LoginUI.bake_shadow_specs()` in `kit_bake_freshness_tests.gd`. For each `{path, clean_cap, opts}`, compare the committed mirror to:

```gdscript
var source := (load(path) as Texture2D).get_image()
var base := Kit._clean_image(source, clean_cap) if clean_cap > 0 else source
var bytes := Kit.add_drop_shadow(base, opts).save_png_to_buffer()
```

Also clear `Kit._live_shadow_log`, build the real Daily preview twice in `grove_ui_workbench_tests.gd`, and assert the log stays empty.

- [ ] **Step 2: Verify RED**

Run:

```bash
python3 engine/tools/run_suites.py engine/tests/kit_bake_freshness_tests games/grove/tests/grove_ui_workbench_tests
```

Expected: failure because the shadow-bake API/mirrors do not exist and Daily still calls `add_drop_shadow` during each build.

- [ ] **Step 3: Implement deterministic shadow mirrors**

In `ui_kit.gd`, add:

```gdscript
static var _live_shadow_log: Array = []

static func shadowed_baked_path(path: String, clean_cap: int, opts: Dictionary) -> String:
	var alpha := int(round(clampf(float(opts.get("shadow_alpha", 0.5)), 0.0, 1.0) * 100.0))
	var cap_tag := "native" if clean_cap <= 0 else str(clean_cap)
	var base := baked_path(path, maxi(1, clean_cap)).trim_suffix(".png")
	return "%s-shadow-%s-a%02d.png" % [base, cap_tag, alpha]

static func shadowed_tex_path(path: String, clean_cap: int, opts: Dictionary) -> Texture2D:
	var baked := shadowed_baked_path(path, clean_cap, opts)
	if ResourceLoader.exists(baked):
		return load(baked) as Texture2D
	_live_shadow_log.append(path)
	var raw := (load(path) as Texture2D).get_image()
	var base := _clean_image(raw, clean_cap) if clean_cap > 0 else raw
	return ImageTexture.create_from_image(add_drop_shadow(base, opts))
```

Declare the exact Daily sources in `LoginUI.bake_shadow_specs()`, route chest and reward icons through `shadowed_tex_path`, and remove the runtime `_shadowed` image-processing path. Have both the bake tool and freshness guard iterate the same specs. Generate/import the mirrors:

```bash
make bake-textures
make import
```

- [ ] **Step 4: Verify GREEN**

Run the focused command from Step 2 and confirm both suites pass with no live-shadow entries.

- [ ] **Step 5: Commit**

```bash
git add games/grove/ui_kit.gd engine/scripts/ui/login.gd games/tools/bake_targets.gd games/tools/bake_textures.gd engine/tests/kit_bake_freshness_tests.gd games/grove/tests/grove_ui_workbench_tests.gd games/grove/assets/baked
git commit -m "perf: prebake daily reward shadows"
```

### Task 2: Enlarge the Rush loadout dialog

**Files:**
- Modify: `engine/scripts/scenes/map.gd`
- Modify: `games/grove/tests/grove_explore_tests.gd`

**Interfaces:**
- Consumes: `Kit.frame_width_pct(cfg: Dictionary) -> float`
- Preserves: `Map._open_expedition(z: int = -1) -> void`

- [ ] **Step 1: Write the failing real-overlay geometry test**

Extend the existing loadout overlay test to derive the expected width:

```gdscript
var expected := map.get_viewport_rect().size.x * Kit.frame_width_pct(Kit.load_config(Kit.CONFIG_PATH)) / 100.0
ok(absf(dialog_before.get_combined_minimum_size().x - expected) < 2.0,
	"the Rush loadout uses the shared full-size dialog width")
ok(dialog_before.get_combined_minimum_size().x > 540.0,
	"the standard portrait loadout is wider than the retired cramped cap")
```

Keep the existing pointer-tap and low-wallet assertions in the same real overlay.

- [ ] **Step 2: Verify RED**

Run:

```bash
python3 engine/tools/run_suites.py games/grove/tests/grove_explore_tests
```

Expected: failure because `Map._open_expedition` still caps the sheet at 540 px.

- [ ] **Step 3: Use the shared frame width**

Replace the hard cap with:

```gdscript
var cfg := Game.kit_config()
var width: float = get_viewport_rect().size.x * Kit.frame_width_pct(cfg) / 100.0
```

Reuse `cfg` for `dialog_opts_from_config`; retain the viewport-relative `list_max_h`.

- [ ] **Step 4: Verify GREEN**

Run the focused Grove Explore suite and confirm all loadout interaction, affordability, and geometry assertions pass.

- [ ] **Step 5: Commit**

```bash
git add engine/scripts/scenes/map.gd games/grove/tests/grove_explore_tests.gd
git commit -m "ui: enlarge rush loadout dialog"
```

### Task 3: Reserve Cascade guide cells longest-first

**Files:**
- Modify: `engine/scripts/core/cascade_marks.gd`
- Modify: `engine/tests/cascade_marks_tests.gd`
- Modify: `games/grove/tests/grove_cascade_tests.gd`

**Interfaces:**
- Preserves: `CascadeMarks.build(board, ctx: Dictionary) -> Array`
- Changes: `_rest_entries(board) -> Array` returns only pairwise-disjoint runs

- [ ] **Step 1: Write failing pure and scene regressions**

Create an overlapping fixture where a ranked ×4 and nested ×3 share cells. Assert:

```gdscript
ok(chain_ns == [4], "the longest overlapping chain owns the shared cells")
ok(no_cell_seen_twice, "resting guide chains are cell-disjoint")
```

Add a same-length overlap fixture and assert the existing row-major-first target wins. Retain the independent ×3 component and assert it remains. Update the Grove real-outline test from three same-line marks to the two disjoint winners, then verify another line adds a third mark.

- [ ] **Step 2: Verify RED**

Run:

```bash
python3 engine/tools/run_suites.py engine/tests/cascade_marks_tests games/grove/tests/grove_cascade_tests
```

Expected: failures showing both nested overlapping routes are currently emitted.

- [ ] **Step 3: Filter ranked candidates**

After `_rest_entries` sorts longest-first, filter:

```gdscript
var kept: Array = []
var reserved := {}
for raw in chains:
	var entry: Dictionary = raw
	var overlaps := false
	for cell in _run_of(entry):
		if reserved.has(Vector2i(cell)):
			overlaps = true
			break
	if overlaps:
		continue
	kept.append(entry)
	for cell in _run_of(entry):
		reserved[Vector2i(cell)] = true
return kept
```

Do not change `_merge_targets`, RUN mode, chain execution, or reward code.

- [ ] **Step 4: Verify GREEN**

Run the focused command from Step 2 and confirm pure marks plus real scene rendering pass.

- [ ] **Step 5: Commit**

```bash
git add engine/scripts/core/cascade_marks.gd engine/tests/cascade_marks_tests.gd games/grove/tests/grove_cascade_tests.gd
git commit -m "fix: keep cascade guide chains disjoint"
```

### Task 4: Integrated verification and visual proof

**Files:**
- Modify only if verification exposes a defect.
- Create temporary captures under `/tmp`; do not commit them.

**Interfaces:**
- Consumes all three prior tasks.
- Produces final verified branch suitable for merge.

- [ ] **Step 1: Run fast and full suites**

```bash
make test-fast
make test
git diff --check
git status --short
```

Expected: all suites pass, no whitespace errors, only intended tracked changes.

- [ ] **Step 2: Capture the two changed visible surfaces in one launch**

Use the existing batchable capture modes, adding deterministic fixture arguments only where needed:

```bash
printf '%s\n' \
  'map loadout /tmp/rush_loadout_large.png' \
  'grove cascade_overlap /tmp/cascade_disjoint.png' > /tmp/daily-rush-cascade-shots.txt
make shot-batch PLAN=/tmp/daily-rush-cascade-shots.txt
```

Inspect both images. Rush must show the wider sheet without clipping; Cascade must show the longest overlap winner plus any disjoint chain.

- [ ] **Step 3: Review task identity and branch**

Confirm the active spec, plan, branch, worktree, diff, and commit list all describe Daily performance, Rush loadout sizing, and Cascade overlap filtering.

- [ ] **Step 4: Finish**

Use `superpowers:verification-before-completion`, `superpowers:requesting-code-review`, and `superpowers:finishing-a-development-branch`. With the user's default workflow, merge the verified branch to `main` and remove the worktree/branch.
