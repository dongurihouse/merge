# Resting Chain FX Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show the existing chain FX at rest for every legal merge that would produce a cascade of three or more.

**Architecture:** Keep `CascadeOutline` and the mark schema unchanged. Extend `CascadeMarks` REST selection to enumerate every occupied source against the existing `_merge_targets()` calculation, deduplicate identical visual routes, sort deterministically, and feed every qualifying route through the existing `chain_stack()`.

**Tech Stack:** Godot 4.6, GDScript, the repo's headless test harness, deterministic `grove_shot` captures.

## Global Constraints

- `GUIDE_MIN_N` remains `3`.
- REST displays every qualifying chain; there is no count cap.
- DRAG and RUN behavior remain unchanged.
- Existing chain contours, target blooms, `×n` tags, weights, and renderer remain unchanged.
- Equivalent source directions that produce the same target and run render once.

---

### Task 1: Select actionable chains while the board rests

**Files:**
- Modify: `engine/tests/cascade_marks_tests.gd`
- Modify: `games/grove/tests/grove_cascade_tests.gd`
- Modify: `engine/scripts/core/cascade_marks.gd`

**Interfaces:**
- Consumes: `_merge_targets(board, from: Vector2i, candidates: Array) -> Array`
- Produces: `_rest_entries(board) -> Array` entries with `from`, `cell`, `path`, `line`, and `n`

- [ ] **Step 1: Write the failing pure and scene regressions**

Add `_test_rest_finds_remote_actionable_chains()` and
`_test_rest_keeps_every_qualifying_chain()` to `cascade_marks_tests.gd`, plus
`_test_resting_remote_chain_shows_before_drag()` to `grove_cascade_tests.gd`.

The first fixture is:

```gdscript
var b := _blank_board()
b.place(Vector2i(8, 0), 101) # remote source
b.place(Vector2i(3, 1), 101) # target
b.place(Vector2i(3, 2), 102)
b.place(Vector2i(3, 3), 103)
var marks := CascadeMarks.build(b, {"mode": CascadeMarks.MODE_REST})
ok(_roles(marks) == ["chain", "target"], "REST shows the remote actionable ×3")
ok(Array((marks[0] as Dictionary).run) == [
	Vector2i(3, 1), Vector2i(3, 2), Vector2i(3, 3),
], "REST follows the same target-first route as DRAG")
```

The second fixture creates four independent line-specific ×3 moves and asserts four `chain`
marks and four `target` marks. The literal expectation is eight marks, proving the former cap of
three is gone.

The scene fixture uses the same remote source and target staircase through `_blank_fixture()` and
asserts `_outline_ladder_count(b) == 1` plus a `×3` tag at the target before any input.

- [ ] **Step 2: Run both suites and verify RED**

Run:

```bash
engine/tools/quiet_godot.sh --path . -s res://engine/tests/cascade_marks_tests.gd
engine/tools/quiet_godot.sh --path . -s res://games/grove/tests/grove_cascade_tests.gd
```

Expected: the pure remote-actionable test reports no REST marks, the four-chain test reports fewer
than eight marks, and the Grove scene reports zero ladder marks.

- [ ] **Step 3: Implement the minimal REST selector**

In `cascade_marks.gd`:

```gdscript
static func _rest_entries(board) -> Array:
	var occupied: Array = []
	for i in board.items.size():
		if int(board.items[i]) > 0:
			occupied.append(BoardModel.cell_of(i))
	var chains: Array = []
	for raw_from in occupied:
		var from := Vector2i(raw_from)
		var line := BoardModel.line_of(board.item_at(from))
		for raw_target in _merge_targets(board, from, occupied):
			var target: Dictionary = raw_target
			var n := int(target.get("n", 0))
			if n < GUIDE_MIN_N:
				continue
			var run: Array = [Vector2i(target.get("cell", NO_CELL))]
			for raw_cell in Array(target.get("path", [])):
				run.append(Vector2i(raw_cell))
			var duplicate := false
			for raw_existing in chains:
				var existing: Dictionary = raw_existing
				if Vector2i(existing.get("cell", NO_CELL)) == run[0] \
						and _same_cells(Array(existing.get("run", [])), run):
					duplicate = true
					break
			if not duplicate:
				chains.append({
					"from": from,
					"cell": run[0],
					"path": Array(target.get("path", [])).duplicate(),
					"run": run,
					"line": line,
					"n": n,
				})
	chains.sort_custom(func(a, b) -> bool:
		var na := int((a as Dictionary).get("n", 0))
		var nb := int((b as Dictionary).get("n", 0))
		if na != nb:
			return na > nb
		var ac := BoardModel.idx(Vector2i((a as Dictionary).get("cell", Vector2i.ZERO)))
		var bc := BoardModel.idx(Vector2i((b as Dictionary).get("cell", Vector2i.ZERO)))
		if ac != bc:
			return ac < bc
		return BoardModel.idx(Vector2i((a as Dictionary).get("from", Vector2i.ZERO))) \
			< BoardModel.idx(Vector2i((b as Dictionary).get("from", Vector2i.ZERO)))
	)
	return chains
```

Remove `REST_MAX`; `_rest_marks()` and `_rest_entry_marks()` continue feeding every entry into the
existing `chain_stack()`.

- [ ] **Step 4: Run both suites and verify GREEN**

Run both:

```bash
engine/tools/quiet_godot.sh --path . -s res://engine/tests/cascade_marks_tests.gd
engine/tools/quiet_godot.sh --path . -s res://games/grove/tests/grove_cascade_tests.gd
```

Expected: both suites pass with no failures.

- [ ] **Step 5: Commit the resting behavior**

```bash
git add engine/scripts/core/cascade_marks.gd engine/tests/cascade_marks_tests.gd games/grove/tests/grove_cascade_tests.gd
git commit -m "fix: show actionable chains at rest"
```

### Task 2: Prove the real resting-board path and visible result

**Files:**
- Modify: `games/grove/tools/grove_shot.gd`

**Interfaces:**
- Consumes: `board.gd::_publish_guide()` and `CascadeOutline.marks`
- Produces: `phase=restmove`, a deterministic capture of a remote actionable chain before pickup

- [ ] **Step 1: Add the deterministic resting capture fixture**

In `grove_shot.gd`, add `phase=restmove` beside `tagtarget` with the same target staircase and remote
duplicate, but do not synthesize a press or drag. Let the existing final wait capture REST.

- [ ] **Step 2: Verify the scene and capture**

Run:

```bash
engine/tools/quiet_godot.sh --path . -s res://games/grove/tests/grove_cascade_tests.gd
make shot TOOL=games/grove/tools/grove_shot ARGS="cascade /tmp/chain_rest_fixed.png phase=restmove cascade_phase=0.2"
```

Expected: the Grove suite passes and `/tmp/chain_rest_fixed.png` visibly contains the full chain
contour, target bloom, and `×3` before pickup.

- [ ] **Step 3: Commit the visible proof**

```bash
git add games/grove/tools/grove_shot.gd
git commit -m "test: prove chain FX appears before drag"
```

### Task 3: Verify and integrate

**Files:**
- Verify all changed files from Tasks 1-2.

**Interfaces:**
- Consumes: the committed REST selector and scene proof
- Produces: a verified merge into `main`

- [ ] **Step 1: Run focused and broad verification**

```bash
engine/tools/quiet_godot.sh --path . -s res://engine/tests/cascade_marks_tests.gd
engine/tools/quiet_godot.sh --path . -s res://games/grove/tests/grove_cascade_tests.gd
make test-fast
make test
git diff --check main...HEAD
```

- [ ] **Step 2: Inspect the final diff and capture**

Confirm only the REST selector, its tests, the capture fixture, and the two planning documents
changed. Inspect `/tmp/chain_rest_fixed.png` at original resolution.

- [ ] **Step 3: Merge and verify on `main`**

Merge `codex/chain-fx-rest` into `main`, run the focused pure and Grove suites on the merged tree,
then remove `.worktrees/chain-fx-rest` and delete the merged branch.
