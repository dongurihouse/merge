# Cascade Visual Guide Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the cascade guide's four independently-written mark channels with ONE ordered mark
list built by a pure function, so a resting recomputation can no longer erase a running cascade's
glow, the drag shows only the longest chain the held piece forms, and the stack order holds in every
state.

**Architecture:** A new static, board-only builder (`engine/scripts/core/cascade_marks.gd`) owns
every display rule and returns an ordered array of marks. `cascade_outline.gd` gains one
`set_marks()` and dispatches on each mark's `role`, reading loudness only from the mark's `weight`
and `reach`. `board.gd` gets one writer, `_publish_guide()`, which derives the mode from state that
already exists (`chain_running()` / a held piece / neither) and can therefore never publish the
wrong mode.

**Tech Stack:** Godot 4.6.2 GDScript, headless SceneTree suites via `engine/tools/run_suites.py`.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-07-30-cascade-guide-design.md`. Read it before Task 1.
- All work happens in the worktree `/Users/xup/dh/wt-cascade-guide` on branch
  `investigate/cascade-guide`. Never edit `/Users/xup/dh/merge` directly — a PreToolUse hook blocks it.
- Never run `git stash` — the stash is shared across worktrees and would eat a peer branch's work.
- Run every test and capture in the FOREGROUND. Backgrounding them hangs the run.
- `make test-fast` after every change; `make test` before handing off.
- A new `*_tests.gd` under `engine/tests/` MUST be added to `ENGINE_TESTS` in the `Makefile` or
  `engine/tests/suite_registry_tests.gd` fails. Engine suites are NOT named in README.md/CLAUDE.md —
  only the grove list is, and this plan adds no grove suite.
- New `.gd` files get no `.uid` from headless runs. Run `make import` before the final commit or the
  untracked `.uid` blocks the merge to main.
- Knob values are moved, never re-tuned: `RUNWAY_WEIGHT := 0.50`, `RUNWAY_REACH := 0.78`,
  `MERGE_WEIGHT := 0.55` are today's `strength`/`reach` literals. `REST_MAX := 3`,
  `DRAG_DIM := 0.35` are new.
- `games/grove/tests/grove_cascade_tests.gd` is being edited by a peer worktree
  (`.claude/worktrees/fervent-volhard-a1e65a`). Task 5 rebases on their commit before touching it.

## File Structure

| File | Responsibility |
|---|---|
| `engine/scripts/core/cascade_marks.gd` | **new.** Every display rule: mode dispatch, ranking, the cap, the drag winner, dimming, the pad generators. Pure and static — takes a `BoardModel` and a context dictionary, returns an ordered `Array` of mark dictionaries. No nodes, no `board.gd`. |
| `engine/tests/cascade_marks_tests.gd` | **new.** The builder's rules, headless, no scene. |
| `engine/scripts/ui/cascade_outline.gd` | Renders a mark list. Keeps the solved `RAILS` profile, contour walk, geometry cache and wave. Loses the four channels, the precedence tests and the dead width/alpha code. |
| `engine/scripts/scenes/board.gd` | One writer (`_publish_guide`), one stack rule (`_guide_stack_index`). Supplies `ctx.targets` from `piece_nodes` — the only node dependency. |
| `games/grove/tests/grove_cascade_tests.gd` | Ported to the single channel; gains the three-mode stack invariant and the run-survives-every-step guard. |
| `Makefile` | `ENGINE_TESTS` gains `engine/tests/cascade_marks_tests`. |

---

### Task 1: The builder, and the REST rules

**Files:**
- Create: `engine/scripts/core/cascade_marks.gd`
- Create: `engine/tests/cascade_marks_tests.gd`
- Modify: `Makefile:12` (`ENGINE_TESTS`)

**Interfaces:**
- Consumes: `BoardLogic.ready_ladders(board) -> Array` (entries carry `cells`, `run`, `line`, `n`,
  `top_cell`), `BoardLogic.runways(board, min_n) -> Array` (entries carry `cells`, `run`, `line`,
  `needs_code`, `would_be_n`, `ignite_cells`), `BoardModel.idx(cell) -> int`,
  `BoardModel.line_of(code) -> int`, `BoardModel.tier_of(code) -> int`.
- Produces: `CascadeMarks.build(board, ctx) -> Array`, the constants `MODE_REST`, `MODE_DRAG`,
  `MODE_RUN`, `REST_MAX`, `DRAG_DIM`, `RUNWAY_WEIGHT`, `RUNWAY_REACH`, `MERGE_WEIGHT`, and the mark
  dictionary shape used by Tasks 2–5.

- [ ] **Step 1: Write the failing test**

Create `engine/tests/cascade_marks_tests.gd`:

```gdscript
extends "res://engine/tests/test_base.gd"
## The cascade guide's display rules, with no scene and no renderer: what marks a board
## produces at rest, while a piece is held, and while a chain runs.

const BoardModel = preload("res://engine/scripts/core/board_model.gd")
const CascadeMarks = preload("res://engine/scripts/core/cascade_marks.gd")

func _initialize() -> void:
	print("== cascade guide marks ==")
	_test_rest_ranks_longest_first_and_caps()
	finish()

func _blank_board() -> BoardModel:
	var b := BoardModel.new()
	for i in b.items.size():
		b.terrain[i] = 0
		b.items[i] = 0
	b.gens = {}
	b.gen_boost = {}
	b.collect_rewards = {}
	b.improvements = {}
	b.seed_ranks = {}
	return b

# A tier ladder in one column: two equal tips at the bottom, then one of each tier above.
# length 3 => cells (0,col) (1,col) at t1, (2,col) t2, (3,col) t3  =>  a run of 3.
func _put_ladder(b: BoardModel, col: int, line: int, length: int) -> void:
	b.place(Vector2i(0, col), line * 100 + 1)
	b.place(Vector2i(1, col), line * 100 + 1)
	for step in range(2, length + 1):
		b.place(Vector2i(step, col), line * 100 + step)

func _roles(marks: Array) -> Array:
	var out: Array = []
	for m in marks:
		out.append(String((m as Dictionary).get("role", "")))
	return out

func _test_rest_ranks_longest_first_and_caps() -> void:
	var b := _blank_board()
	_put_ladder(b, 0, 1, 2)     # n = 2
	_put_ladder(b, 2, 2, 4)     # n = 4
	_put_ladder(b, 4, 3, 3)     # n = 3
	var marks := CascadeMarks.build(b, {"mode": CascadeMarks.MODE_REST, "chain_min_n": 2, "runway_min_n": 3})
	var ns: Array = []
	for m in marks:
		ns.append(int((m as Dictionary).get("n", 0)))
	ok(ns == [4, 3, 2], "rest ranks chains longest first (got %s)" % str(ns))
	ok(_roles(marks) == ["chain", "chain", "chain"], "rest emits chain marks (got %s)" % str(_roles(marks)))
	var first: Dictionary = marks[0]
	ok(is_equal_approx(float(first.get("weight", 0.0)), 1.0) and bool(first.get("tag", false)),
		"a rest chain is full weight and carries its tag")
	ok(Vector2i(first.get("tag_cell", Vector2i(-1, -1))).x >= 0, "a rest chain names the cell its tag sits on")
	_put_ladder(b, 6, 4, 5)     # a fourth chain, over the cap
	var capped := CascadeMarks.build(b, {"mode": CascadeMarks.MODE_REST, "chain_min_n": 2, "runway_min_n": 3})
	ok(capped.size() == CascadeMarks.REST_MAX, "rest truncates at REST_MAX (got %d)" % capped.size())
	var top := int((capped[0] as Dictionary).get("n", 0))
	ok(top == 5, "the cap keeps the LONGEST chains, not the first found (got %d)" % top)
```

- [ ] **Step 2: Register the suite and run it to verify it fails**

In `Makefile:12`, append ` engine/tests/cascade_marks_tests` to the end of `ENGINE_TESTS`.

Run: `make test-grove GROVE_TESTS=engine/tests/cascade_marks_tests`

Expected: FAIL — the runner reports a crash, because `res://engine/scripts/core/cascade_marks.gd`
does not exist yet. (`GROVE_TESTS=` is just the runner's suite-list variable; it runs any suite path.)

- [ ] **Step 3: Write the builder with REST only**

Create `engine/scripts/core/cascade_marks.gd`:

```gdscript
## Every cascade-guide display rule, in ONE pure place. board.gd hands over the board, the mode and
## the mode's context; this returns the ORDERED mark list the renderer draws, first mark furthest
## back. Nothing here touches a node, so the whole rule set is testable with no scene.
##
## The mode is DERIVED by the caller from state it already holds, never stored: that is what makes
## "a resting recomputation erases the running cascade's glow" unrepresentable — REST and RUN can no
## longer both be true, and there is only one field to write.

const BoardModel = preload("res://engine/scripts/core/board_model.gd")
const BoardLogic = preload("res://engine/scripts/core/board_logic.gd")

const MODE_REST := 0
const MODE_DRAG := 1
const MODE_RUN := 2

const NO_CELL := Vector2i(-1, -1)

## Owner-facing knobs. REST_MAX and DRAG_DIM are new; the other three are today's `strength` and
## `reach` literals moved here unchanged, so this refactor re-tunes nothing.
const REST_MAX := 3                  # resting marks drawn at once, chains before runways
const DRAG_DIM := 0.35               # weight of every non-winning mark while a piece is held
const RUNWAY_WEIGHT := 0.50
const RUNWAY_REACH := 0.78
const MERGE_WEIGHT := 0.55

## One constructor, so every mark carries every key and no reader needs a default.
static func mark(role: String, run: Array, cell: Vector2i, line: int, n: int,
		weight: float, reach: float, tag: bool, tag_cell: Vector2i) -> Dictionary:
	return {
		"role": role, "run": run, "cell": cell, "line": line, "n": n,
		"weight": weight, "reach": reach, "tag": tag, "tag_cell": tag_cell,
	}

static func build(board, ctx: Dictionary) -> Array:
	if board == null:
		return []
	match int(ctx.get("mode", MODE_REST)):
		MODE_RUN:
			return _run_marks(board, ctx)
		MODE_DRAG:
			return _drag_marks(board, ctx)
		_:
			return _rest_marks(board, ctx)

# --- REST -------------------------------------------------------------------------------------
# Every armed chain, longest first, then every runway, truncated to REST_MAX. The cap is over the
# combined list on purpose: it is a budget for how much the resting board may say at once.
static func _rest_marks(board, ctx: Dictionary) -> Array:
	var out: Array = []
	for entry in _rest_chains(board, int(ctx.get("chain_min_n", 2))):
		var e: Dictionary = entry
		var top := Vector2i(e.get("top_cell", NO_CELL))
		out.append(mark("chain", _run_of(e), NO_CELL, int(e.get("line", 0)), int(e.get("n", 0)),
			1.0, 1.0, true, top))
	for raw in BoardLogic.runways(board, int(ctx.get("runway_min_n", 3))):
		if raw is Dictionary:
			var e: Dictionary = raw
			out.append(mark("runway", _run_of(e), NO_CELL, int(e.get("line", 0)), 0,
				RUNWAY_WEIGHT, RUNWAY_REACH, false, NO_CELL))
	return out.slice(0, REST_MAX)

## The armed chains, longest first. The comparator carries its own row-major tie-break because
## sort_custom is NOT stable in Godot — relying on ready_ladders' own ordering to survive the sort
## would make the tie-break depend on the sort's internals.
static func _rest_chains(board, min_n: int) -> Array:
	var chains: Array = []
	for raw in BoardLogic.ready_ladders(board):
		if raw is Dictionary and int((raw as Dictionary).get("n", 0)) >= min_n:
			chains.append((raw as Dictionary).duplicate(true))
	chains.sort_custom(func(a, b) -> bool:
		var na := int((a as Dictionary).get("n", 0))
		var nb := int((b as Dictionary).get("n", 0))
		if na != nb:
			return na > nb
		return BoardModel.idx(Vector2i((a as Dictionary).get("top_cell", Vector2i.ZERO))) \
			< BoardModel.idx(Vector2i((b as Dictionary).get("top_cell", Vector2i.ZERO)))
	)
	return chains

## The cells the light follows: the cascade's own run, never the same-line flood fill in `cells`.
static func _run_of(entry: Dictionary) -> Array:
	var run := Array(entry.get("run", []))
	return run.duplicate() if not run.is_empty() else Array(entry.get("cells", [])).duplicate()
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `make test-grove GROVE_TESTS=engine/tests/cascade_marks_tests`

Expected: `== 6 passed, 0 failed ==`, exit 0, no `SCRIPT ERROR`.

- [ ] **Step 5: Run the fast sweep and commit**

Run: `make test-fast`
Expected: every suite passes, including `suite_registry_tests` (it now sees the new suite in
`ENGINE_TESTS`).

```bash
git add engine/scripts/core/cascade_marks.gd engine/tests/cascade_marks_tests.gd Makefile
git commit -m "feat(cascade): the guide's REST rules become one pure ranked mark list"
```

---

### Task 2: The DRAG rules — one winner, everything else dimmed

**Files:**
- Modify: `engine/scripts/core/cascade_marks.gd`
- Modify: `engine/tests/cascade_marks_tests.gd`
- Read for reference: `engine/scripts/scenes/board.gd:2660-2748` (the two pad generators being moved)

**Interfaces:**
- Consumes: Task 1's `mark()`, `_rest_chains()`, `_run_of()`, `MODE_DRAG`, `DRAG_DIM`,
  `MERGE_WEIGHT`; `BoardLogic.chain_path(board, from, to) -> Array`,
  `BoardLogic.chain_placements(board, from, code) -> Array` (entries carry `cell`, `n`),
  `BoardLogic.ORTHO_DIRS`, `board.can_merge(from, to) -> bool`,
  `board.is_empty_ground(cell) -> bool`, `board.in_bounds(cell) -> bool`, `board.gens: Dictionary`.
- Produces: DRAG-mode marks; `ctx` keys `from: Vector2i`, `code: int`, `targets: Array[Vector2i]`
  consumed by Task 5.

- [ ] **Step 1: Write the failing tests**

Add to `engine/tests/cascade_marks_tests.gd` — register both in `_initialize()` after the REST test:

```gdscript
	_test_drag_keeps_only_the_longest_chain_loud()
	_test_drag_without_a_chain_hides_every_chain_mark()
```

```gdscript
func _occupied_cells(b: BoardModel) -> Array:
	var out: Array = []
	for i in b.items.size():
		if int(b.items[i]) > 0:
			out.append(BoardModel.cell_of(i))
	return out

func _drag_ctx(b: BoardModel, from: Vector2i) -> Dictionary:
	return {
		"mode": CascadeMarks.MODE_DRAG, "chain_min_n": 2, "runway_min_n": 3,
		"from": from, "code": b.item_at(from), "targets": _occupied_cells(b),
	}

func _loud(marks: Array) -> Array:
	var out: Array = []
	for raw in marks:
		var m: Dictionary = raw
		if float(m.get("weight", 0.0)) > CascadeMarks.DRAG_DIM + 0.001:
			out.append(m)
	return out

func _test_drag_keeps_only_the_longest_chain_loud() -> void:
	var b := _blank_board()
	# Held piece: a t1 at (0,0). Two targets for it, of different chain length.
	b.place(Vector2i(0, 0), 101)
	b.place(Vector2i(0, 2), 101)          # merging here produces t2 with nothing above  -> n = 1
	b.place(Vector2i(3, 4), 101)          # merging here climbs the ladder below         -> n = 3
	b.place(Vector2i(4, 4), 102)
	b.place(Vector2i(5, 4), 103)
	var marks := CascadeMarks.build(b, _drag_ctx(b, Vector2i(0, 0)))
	var loud := _loud(marks)
	var loud_targets: Array = []
	for raw in loud:
		var m: Dictionary = raw
		if String(m.get("role", "")) == "target":
			loud_targets.append(Vector2i(m.get("cell", Vector2i(-1, -1))))
	ok(loud_targets == [Vector2i(3, 4)],
		"the drag lights exactly the longest chain's drop cell (got %s)" % str(loud_targets))
	var tagged: Array = []
	for raw in marks:
		var m: Dictionary = raw
		if bool(m.get("tag", false)):
			tagged.append([Vector2i(m.get("tag_cell", Vector2i(-1, -1))), int(m.get("n", 0))])
	ok(tagged == [[Vector2i(3, 4), 3]], "the x n chip sits on the winning drop cell (got %s)" % str(tagged))
	var dimmed := 0
	for raw in marks:
		if is_equal_approx(float((raw as Dictionary).get("weight", 0.0)), CascadeMarks.DRAG_DIM):
			dimmed += 1
	ok(dimmed >= 1, "the losing target is dimmed rather than dropped (got %d dimmed)" % dimmed)
	ok(String((marks[marks.size() - 1] as Dictionary).get("role", "")) == "target",
		"the winning target is emitted last, so it draws on top")

func _test_drag_without_a_chain_hides_every_chain_mark() -> void:
	var b := _blank_board()
	b.place(Vector2i(0, 0), 101)
	b.place(Vector2i(0, 2), 101)          # a plain pair: merging is possible, nothing cascades
	var marks := CascadeMarks.build(b, _drag_ctx(b, Vector2i(0, 0)))
	for raw in marks:
		var role := String((raw as Dictionary).get("role", ""))
		ok(role != "chain" and role != "runway",
			"a drag that forms no chain draws no chain or runway mark (saw %s)" % role)
	var targets := 0
	var stages := 0
	for raw in marks:
		match String((raw as Dictionary).get("role", "")):
			"target": targets += 1
			"stage": stages += 1
	ok(targets == 1, "the plain merge target still shows (got %d)" % targets)
	ok(stages > 0, "the staging pads still show (got %d)" % stages)
	for raw in marks:
		var m: Dictionary = raw
		if String(m.get("role", "")) == "target":
			ok(is_equal_approx(float(m.get("weight", 0.0)), CascadeMarks.MERGE_WEIGHT),
				"a plain merge target keeps today's merge weight")
```

- [ ] **Step 2: Run to verify it fails**

Run: `make test-grove GROVE_TESTS=engine/tests/cascade_marks_tests`
Expected: FAIL — `_drag_marks` does not exist, so the suite crashes or the DRAG asserts fail.

- [ ] **Step 3: Implement the DRAG rules**

Append to `engine/scripts/core/cascade_marks.gd`:

```gdscript
# --- DRAG -------------------------------------------------------------------------------------
# ONE place for the eye. Of everything the held piece could do, the LONGEST chain it would form is
# the answer, so that target alone is loud and carries the x n; every other chain, runway and merge
# target is dimmed to DRAG_DIM. A held piece that forms no chain at all draws no chain light —
# only its plain merge targets and the staging pads.
#
# These marks depend on the HELD PIECE, never on the pointer, so board.gd builds them once at
# pickup. Nothing here re-runs inside the gesture.
static func _drag_marks(board, ctx: Dictionary) -> Array:
	var from := Vector2i(ctx.get("from", NO_CELL))
	var code := int(ctx.get("code", 0))
	if from.x < 0 or code <= 0:
		return []
	var min_n := int(ctx.get("chain_min_n", 2))
	var line := BoardModel.line_of(code)
	var targets := _merge_targets(board, from, Array(ctx.get("targets", [])))
	var win := _winner_index(targets, min_n)
	var out: Array = []
	if win < 0:
		for raw in targets:
			var t: Dictionary = raw
			out.append(mark("target", [], Vector2i(t.get("cell", NO_CELL)), line,
				int(t.get("n", 1)), MERGE_WEIGHT, 1.0, false, NO_CELL))
		out.append_array(_stage_marks(board, from, code, _occupied_of(targets), min_n))
		return out
	var winner: Dictionary = targets[win]
	var win_cell := Vector2i(winner.get("cell", NO_CELL))
	var win_run: Array = [win_cell]
	for raw in Array(winner.get("path", [])):
		win_run.append(Vector2i(raw))
	# background first: the resting marks this drag is NOT about
	for raw in _rest_marks(board, ctx):
		var m: Dictionary = (raw as Dictionary).duplicate(true)
		if _same_cells(Array(m.get("run", [])), win_run):
			continue
		m["weight"] = DRAG_DIM
		m["tag"] = false
		m["tag_cell"] = NO_CELL
		out.append(m)
	out.append(mark("chain", win_run, NO_CELL, line, int(winner.get("n", min_n)), 1.0, 1.0, false, NO_CELL))
	for i in targets.size():
		if i == win:
			continue
		var t: Dictionary = targets[i]
		out.append(mark("target", [], Vector2i(t.get("cell", NO_CELL)), line,
			int(t.get("n", 1)), DRAG_DIM, 1.0, false, NO_CELL))
	out.append(mark("target", [], win_cell, line, int(winner.get("n", min_n)), 1.0, 1.0, true, win_cell))
	return out

## Every occupied cell the held piece can merge onto, row-major, with the chain length that merge
## would run. `candidates` is the caller's list because it comes from the rendered pieces.
static func _merge_targets(board, from: Vector2i, candidates: Array) -> Array:
	var out: Array = []
	for raw in candidates:
		var t := Vector2i(raw)
		if t == from or not board.can_merge(from, t):
			continue
		var path := BoardLogic.chain_path(board, from, t)
		out.append({"cell": t, "n": 1 + path.size(), "path": path})
	out.sort_custom(func(a, b) -> bool:
		return BoardModel.idx(Vector2i((a as Dictionary).get("cell", Vector2i.ZERO))) \
			< BoardModel.idx(Vector2i((b as Dictionary).get("cell", Vector2i.ZERO)))
	)
	return out

## The longest chain, ties going to the row-major first — `>` and a row-major-sorted input, so the
## tie-break is the input's order and not the comparison's.
static func _winner_index(targets: Array, min_n: int) -> int:
	var win := -1
	for i in targets.size():
		var n := int((targets[i] as Dictionary).get("n", 0))
		if n < min_n:
			continue
		if win < 0 or n > int((targets[win] as Dictionary).get("n", 0)):
			win = i
	return win

static func _occupied_of(targets: Array) -> Dictionary:
	var out := {}
	for raw in targets:
		out[Vector2i((raw as Dictionary).get("cell", NO_CELL))] = true
	return out

static func _same_cells(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	var seen := {}
	for raw in a:
		seen[Vector2i(raw)] = true
	for raw in b:
		if not seen.has(Vector2i(raw)):
			return false
	return true
```

- [ ] **Step 4: Move the three staging-pad generators in, unchanged**

Copy `_cascade_extension_pads` (rename to `_extension_pads`), `_single_neighbor_seed_pads`,
`_extension_pads_for_component` and `_can_show_extension_pad` from
`engine/scripts/scenes/board.gd:2660-2748` into `cascade_marks.gd` as `static` functions, taking
`board` as their first parameter and using `_run_of` in place of `_guide_run_cells` (which is
`_run_of` under another name — do not copy it twice). `_extension_pads` keeps its existing signature
`(board, from, code, occupied) -> Array` and its trailing row-major sort. Behaviour must not change:
the same cells, the same order. Wrap them in one emitter:

```gdscript
## The empty-cell staging marks: "put it here and the ladder grows". Three generators, exactly as
## they behaved before this refactor — the placements the held code improves, the pads that extend
## an existing component, and the seeds beside a lone one-tier-off neighbour. They are emitted ONLY
## when no chain target won, which is today's `if not fires` rule.
static func _stage_marks(board, from: Vector2i, code: int, occupied: Dictionary, ctx_min_n: int) -> Array:
	var out: Array = []
	var line := BoardModel.line_of(code)
	var seen := occupied.duplicate()
	var min_n := int(ctx_min_n)
	for raw in BoardLogic.chain_placements(board, from, code):
		if not (raw is Dictionary):
			continue
		# today's board.gd:2602 filter: a staging pad below the threshold advertises nothing
		if int((raw as Dictionary).get("n", 0)) < min_n:
			continue
		var cell := Vector2i((raw as Dictionary).get("cell", NO_CELL))
		if cell.x < 0 or seen.has(cell):
			continue
		seen[cell] = true
		out.append(mark("stage", [], cell, line, 0, 1.0, 1.0, false, NO_CELL))
	for raw in _extension_pads(board, from, code, seen):
		var cell := Vector2i((raw as Dictionary).get("cell", NO_CELL))
		if cell.x < 0 or seen.has(cell):
			continue
		seen[cell] = true
		out.append(mark("stage", [], cell, line, 0, 1.0, 1.0, false, NO_CELL))
	return out
```

`_extension_pads` is the moved `_cascade_extension_pads`, which already folds in the
single-neighbour seeds and dedupes row-major.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `make test-grove GROVE_TESTS=engine/tests/cascade_marks_tests`
Expected: every assert passes, `0 failed`.

- [ ] **Step 6: Run the fast sweep and commit**

Run: `make test-fast`
Expected: all green. `board.gd` still owns its own copies of the pad generators at this point — that
is fine, Task 5 deletes them.

```bash
git add engine/scripts/core/cascade_marks.gd engine/tests/cascade_marks_tests.gd
git commit -m "feat(cascade): a drag lights the longest chain and dims the rest"
```

---

### Task 3: The RUN rules — the glow the cascade cannot lose

**Files:**
- Modify: `engine/scripts/core/cascade_marks.gd`
- Modify: `engine/tests/cascade_marks_tests.gd`

**Interfaces:**
- Consumes: Task 1's `mark()`, `MODE_RUN`.
- Produces: RUN-mode marks; `ctx` keys `head: Vector2i`, `run: Array[Vector2i]`, `n: int` consumed
  by Task 5.

- [ ] **Step 1: Write the failing test**

Register `_test_run_emits_one_mark_covering_the_whole_remaining_run()` in `_initialize()` and add:

```gdscript
func _test_run_emits_one_mark_covering_the_whole_remaining_run() -> void:
	var b := _blank_board()
	b.place(Vector2i(3, 2), 102)
	b.place(Vector2i(4, 2), 103)
	b.place(Vector2i(5, 2), 104)
	var marks := CascadeMarks.build(b, {
		"mode": CascadeMarks.MODE_RUN, "chain_min_n": 2,
		"head": Vector2i(3, 2), "run": [Vector2i(4, 2), Vector2i(5, 2)], "n": 3,
	})
	ok(marks.size() == 1, "a running chain draws exactly one mark (got %d)" % marks.size())
	var m: Dictionary = marks[0]
	ok(String(m.get("role", "")) == "chain", "and it is a chain mark")
	ok(_cells_match(Array(m.get("run", [])), [Vector2i(3, 2), Vector2i(4, 2), Vector2i(5, 2)]),
		"covering the head plus every remaining cell (got %s)" % str(m.get("run", [])))
	ok(is_equal_approx(float(m.get("weight", 0.0)), 1.0) and bool(m.get("tag", false))
		and Vector2i(m.get("tag_cell", Vector2i(-1, -1))) == Vector2i(5, 2),
		"at full weight, tagged at the run's far end")
	# A mid-run board has no ready ladder of its own — the old code recomputed REST here and blanked
	# the glow. RUN must not consult the board's resting state at all.
	var last := CascadeMarks.build(b, {
		"mode": CascadeMarks.MODE_RUN, "chain_min_n": 2,
		"head": Vector2i(5, 2), "run": [], "n": 3,
	})
	ok(last.is_empty(), "a run with nothing left to walk emits nothing")

func _cells_match(got: Array, want: Array) -> bool:
	if got.size() != want.size():
		return false
	for i in want.size():
		if Vector2i(got[i]) != Vector2i(want[i]):
			return false
	return true
```

- [ ] **Step 2: Run to verify it fails**

Run: `make test-grove GROVE_TESTS=engine/tests/cascade_marks_tests`
Expected: FAIL — `_run_marks` is missing.

- [ ] **Step 3: Implement**

```gdscript
# --- RUN --------------------------------------------------------------------------------------
# While a cascade is walking, the run OWNS the display: one mark, the head plus everything still to
# come, for the whole run. It reads only the caller's context — never ready_ladders — because a
# mid-chain board has no armed ladder of its own, and consulting it is exactly what used to erase
# this glow one beat after the first automatic step.
static func _run_marks(board, ctx: Dictionary) -> Array:
	var head := Vector2i(ctx.get("head", NO_CELL))
	var remaining := Array(ctx.get("run", []))
	if head.x < 0 or remaining.is_empty():
		return []
	var cells: Array = [head]
	for raw in remaining:
		cells.append(Vector2i(raw))
	var n := int(ctx.get("n", cells.size()))
	return [mark("chain", cells, NO_CELL, BoardModel.line_of(board.item_at(head)), n,
		1.0, 1.0, true, Vector2i(cells[cells.size() - 1]))]
```

- [ ] **Step 4: Run to verify it passes**

Run: `make test-grove GROVE_TESTS=engine/tests/cascade_marks_tests`
Expected: `0 failed`.

- [ ] **Step 5: Commit**

Run: `make test-fast` (expected: all green)

```bash
git add engine/scripts/core/cascade_marks.gd engine/tests/cascade_marks_tests.gd
git commit -m "feat(cascade): a running chain owns the guide for its whole run"
```

---

### Task 4: The renderer takes one list, and loses its dead half

**Files:**
- Modify: `engine/scripts/ui/cascade_outline.gd`
- Modify: `engine/tests/cascade_marks_tests.gd`

**Interfaces:**
- Consumes: the mark shape from Tasks 1–3.
- Produces: `set_marks(marks: Array) -> void`, and `marks` as the node's only mark state. The four
  old setters remain until Task 5 flips `board.gd`.

- [ ] **Step 1: Write the failing test**

Register `_test_renderer_reads_only_weight_and_reach()` and add — this instantiates the renderer
headlessly, which needs no scene:

```gdscript
const CascadeOutline = preload("res://engine/scripts/ui/cascade_outline.gd")

func _test_renderer_reads_only_weight_and_reach() -> void:
	var o: Control = CascadeOutline.new()
	o.configure(Vector2(400, 400), 40.0, func(cell: Vector2i) -> Vector2:
		return Vector2(cell.y * 44.0, cell.x * 44.0))
	var run := [Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3)]
	o.set_marks([CascadeMarks.mark("chain", run, Vector2i(-1, -1), 1, 3, 1.0, 1.0, true, Vector2i(1, 3))])
	ok(Array(o.get("marks")).size() == 1, "set_marks is the renderer's only mark channel")
	ok(o.is_processing(), "a mark with weight drives the travelling wave")
	var tags := 0
	for child in o.get_children():
		if (child as Node).name == "CascadeTag":
			tags += 1
	ok(tags == 1, "one tagged mark makes one chip (got %d)" % tags)
	o.set_marks([])
	ok(not o.is_processing(), "an empty list stops the wave")
	# the weakened runway is a WEIGHT the drawing reads, not a dead width helper
	ok(CascadeMarks.RUNWAY_WEIGHT < 1.0 and not o.has_method("_mark_thickness"),
		"runway weakness lives in the mark's weight, and the dead width helper is gone")
	o.free()
```

- [ ] **Step 2: Run to verify it fails**

Run: `make test-grove GROVE_TESTS=engine/tests/cascade_marks_tests`
Expected: FAIL — `set_marks` does not exist and `_mark_thickness` still does.

- [ ] **Step 3: Add the single channel**

In `engine/scripts/ui/cascade_outline.gd`:

1. Add `var marks: Array = []` beside the existing arrays.
2. Add:

```gdscript
## The renderer's ONE mark channel. The list arrives in draw order — first mark furthest back — and
## carries its own loudness in `weight` and `reach`, so nothing here re-derives strength from a role.
func set_marks(data: Array) -> void:
	marks = data.duplicate(true)
	_after_marks_changed()
```

3. Rewrite `_draw` to dispatch on role, and keep the legacy channels working until Task 5:

```gdscript
func _draw() -> void:
	if cell_size <= 0.0 or not cell_pos_fn.is_valid():
		return
	if not marks.is_empty():
		for raw in marks:
			if raw is Dictionary:
				_draw_mark(raw as Dictionary)
		return
	_draw_legacy()

func _draw_mark(m: Dictionary) -> void:
	var weight := float(m.get("weight", 1.0))
	if weight <= 0.0:
		return
	var colour := G.line_color(int(m.get("line", 0)))
	match String(m.get("role", "")):
		"chain", "runway":
			_draw_chain_glow(Array(m.get("run", [])), colour, weight, float(m.get("reach", 1.0)))
		"target":
			_draw_target_bloom(Vector2i(m.get("cell", Vector2i(-1, -1))), colour, weight)
		"stage":
			_draw_stage_well(Vector2i(m.get("cell", Vector2i(-1, -1))), colour)
```

Move today's `_draw` body into `_draw_legacy()` verbatim.

4. `_sync_process`: add `or _has_live_mark()` where

```gdscript
func _has_live_mark() -> bool:
	for raw in marks:
		if raw is Dictionary and float((raw as Dictionary).get("weight", 0.0)) > 0.0:
			return true
	return false
```

5. `_rebuild_tags`: when `marks` is non-empty, replace the three loops with one:

```gdscript
	if not marks.is_empty():
		var taken := {}
		for raw in marks:
			var m: Dictionary = raw
			if not bool(m.get("tag", false)):
				continue
			var cell := Vector2i(m.get("tag_cell", Vector2i(-1, -1)))
			if cell.x < 0 or taken.has(cell):
				continue
			taken[cell] = true
			var pn := maxi(2, int(m.get("n", 2)))
			_add_tag(cell, "×%d" % pn, pn, false)
		return
```

- [ ] **Step 4: Delete the dead renderer code**

Remove from `cascade_outline.gd`: `_mark_thickness`, `_thickness_for_n`, `_alpha_for_n`,
`_edge_key`, the constants `RUNWAY_WIDTH_SCALE`, `MERGE_WIDTH_SCALE`, `STAGE_WIDTH_SCALE`, and the
four `@export` vars `inset_frac` / `thickness_frac` / `fill_pct` / `jitter_frac` with their four
setters `_set_inset` / `_set_thickness` / `_set_fill_pct` / `_set_jitter`.

Then fix the guard that tested them. In `games/grove/tests/grove_cascade_tests.gd`, the two
`_mark_thickness` calls at lines ~797-798 and the assert
`"runway resting mark is visibly weaker than an armed ladder"` read a function the renderer never
called. Replace with an assert on the weight the drawing uses:

```gdscript
	var o := _outline(b)
	var runway_weight := 0.0
	for raw in Array(o.get("marks")):
		var m: Dictionary = raw
		if String(m.get("role", "")) == "runway":
			runway_weight = float(m.get("weight", 0.0))
	ok(runway_weight > 0.0 and runway_weight < 1.0,
		"runway resting mark is visibly weaker than an armed ladder (weight %.2f)" % runway_weight)
```

That reads the weight the drawing actually consumes. Add
`const CascadeMarks = preload("res://engine/scripts/core/cascade_marks.gd")` to that suite's
preloads. Note this assert only becomes meaningful once Task 5 makes `board.gd` publish marks; until
then it reads an empty list. Land it in Task 5's Step 8 instead if it cannot pass here — do not
leave a green assert that reads nothing.

- [ ] **Step 5: Run to verify it passes**

Run: `make test-grove GROVE_TESTS=engine/tests/cascade_marks_tests`
Expected: `0 failed`.

Run: `make test-grove`
Expected: all grove suites green — the legacy path still serves `board.gd`.

- [ ] **Step 6: Commit**

Run: `make test-fast` (expected: all green)

```bash
git add engine/scripts/ui/cascade_outline.gd engine/tests/cascade_marks_tests.gd games/grove/tests/grove_cascade_tests.gd
git commit -m "refactor(cascade): the renderer takes one mark list and loses its dead width code"
```

---

### Task 5: The flip — one writer in board.gd, and the guards that pin it

**Files:**
- Modify: `engine/scripts/scenes/board.gd` (delete `2563-2617`, `2660-2752`; rewrite
  `2534-2561`; edit call sites `1859`, `2896`, `5144`, `5188`, `5531`, `5556-5572`, `5610`)
- Modify: `engine/scripts/ui/cascade_outline.gd` (delete the legacy path)
- Modify: `games/grove/tests/grove_cascade_tests.gd`

**Interfaces:**
- Consumes: `CascadeMarks.build(board, ctx)`, `outline.set_marks(marks)`.
- Produces: `_publish_guide()` as the guide's only writer; `_guide_stack_index() -> int`.

- [ ] **Step 1: Rebase on the peer worktree's test change first**

```bash
git -C /Users/xup/dh/merge log --oneline -3
git fetch . 2>/dev/null; git rebase main
```

If `.claude/worktrees/fervent-volhard-a1e65a` has not landed its `grove_cascade_tests.gd` change to
`main` yet, STOP and report — do not race it.

- [ ] **Step 2: Write the two failing guards**

In `games/grove/tests/grove_cascade_tests.gd`, register and add:

```gdscript
# The run's own glow must survive the whole cascade. It did not: the pre-roll wrote the run into the
# same field _after_board_change recomputes from ready_ladders, and a mid-chain board has no ready
# ladder — so the telegraph was erased one beat after the first automatic step. Measured at
# e3aeab9e: `ladders` went 1 -> 0 while chain_running() was still true.
func _test_run_glow_survives_every_step() -> void:
	var b := _open_board("run-glow")
	await process_frame
	_blank_fixture(b, _ladder_fixture(4, 2))
	await process_frame
	_drag_merge(b, Vector2i(3, 1), Vector2i(3, 2))
	var blank_frames := 0
	var frames := 0
	while (b.chain_running() or bool(b.animating)) and frames < 240:
		if _outline_lit_run(b).is_empty():
			blank_frames += 1
		frames += 1
		await process_frame
	ok(frames > 0 and blank_frames == 0,
		"the running chain keeps its glow on every frame (%d blank of %d)" % [blank_frames, frames])
	b.queue_free()
	await process_frame

# the cells any lit mark covers right now
func _outline_lit_run(b: Node) -> Array:
	var o := _outline(b)
	if o == null:
		return []
	var out: Array = []
	for raw in Array(o.get("marks")):
		var m: Dictionary = raw
		if float(m.get("weight", 0.0)) > 0.0:
			out.append_array(Array(m.get("run", [])))
	return out

# The stack invariant held at rest and failed in every state the suite never checked: measured at
# e3aeab9e the outline sat at index 65 with the first item at 64 on every drag frame, so the guide
# painted OVER piece art. _position_cascade_outline moved the node to the first item's index without
# accounting for its own lower index.
func _test_stack_invariant_holds_at_rest_on_drag_and_mid_run() -> void:
	var b := _open_board("stack-modes")
	await process_frame
	_blank_fixture(b, _ladder_fixture(4, 2))
	await process_frame
	ok(_outline_stack_is_visible_between_board_and_items(b), "stack invariant holds at rest")
	_input_begin_drag(b, Vector2i(3, 1))
	await process_frame
	ok(_outline_stack_is_visible_between_board_and_items(b), "stack invariant holds during a drag")
	_input_release(b, Vector2i(3, 2))
	var checked := 0
	var bad := 0
	while (b.chain_running() or bool(b.animating)) and checked < 240:
		if not _outline_stack_is_visible_between_board_and_items(b):
			bad += 1
		checked += 1
		await process_frame
	ok(checked > 0 and bad == 0, "stack invariant holds mid-run (%d bad of %d)" % [bad, checked])
	b.queue_free()
	await process_frame
```

- [ ] **Step 3: Prove both guards fail on the parent commit**

Commit the guards alone, then run them against the UNCHANGED production files. A new test that
passes before the fix guards nothing.

```bash
git commit -am "test(cascade): guards for the run glow and the stack order in every mode"
make test-grove GROVE_TESTS=games/grove/tests/grove_cascade_tests
```

Expected: FAIL on both new asserts — `_test_run_glow_survives_every_step` reports a non-zero blank
count, `_test_stack_invariant_holds_at_rest_on_drag_and_mid_run` reports the drag check false.
Record both numbers; Step 11 reports them against the fixed numbers. If either PASSES here, the
guard is vacuous — stop and fix the test before writing any production code.

(No `git checkout` of production files is needed: this task has not modified them yet. Never
`git stash` in this repo — the stash is shared across worktrees.)

- [ ] **Step 4: Replace the guide's board-side plumbing**

Delete `_refresh_cascade_outline`, `_show_cascade_drag_guides`, `_clear_cascade_drag_guides`,
`_armed_cascade_marks`, `_merge_target_pads`, `_merge_target_guides`, `_cascade_extension_pads`,
`_guide_run_cells`, `_single_neighbor_seed_pads`, `_extension_pads_for_component` and
`_can_show_extension_pad` (`board.gd:2563-2617` and `2660-2752`). Add:

```gdscript
## The guide's ONE writer. The mode is derived here from state the board already holds, so no call
## site can publish the wrong one — a resting refresh arriving mid-cascade now yields to the run
## instead of overwriting it.
func _publish_guide() -> void:
	if board == null or board_area == null or not is_instance_valid(board_area):
		return
	var outline := _ensure_cascade_outline()
	if outline == null:
		return
	var mode := CascadeMarks.MODE_REST
	var ctx := {"chain_min_n": CHAIN_MIN_N, "runway_min_n": RUNWAY_MIN_N}
	if chain_running() and not _chain_run.is_empty():
		mode = CascadeMarks.MODE_RUN
		ctx["head"] = _chain_head
		ctx["run"] = _chain_run.duplicate()
		ctx["n"] = _chain_n + _chain_run.size()
	elif _drag_node != null and not _drag_is_gen and _drag_from.x >= 0 and board.item_at(_drag_from) > 0:
		mode = CascadeMarks.MODE_DRAG
		ctx["from"] = _drag_from
		ctx["code"] = board.item_at(_drag_from)
		ctx["targets"] = piece_nodes.keys()
	ctx["mode"] = mode
	if mode != CascadeMarks.MODE_RUN:
		_kill_guide_pulse(outline)
	outline.set_marks(CascadeMarks.build(board, ctx) if Features.on("cascade") else [])

func _kill_guide_pulse(outline: Control) -> void:
	outline.modulate = Color(1, 1, 1, 1)
```

**The head is a NEW field, not `_chain_origin_cell`.** `_chain_origin_cell` is the cascade counter's
anchor (`board.gd:5671`) and `_test_chain_counter_anchors_at_run_origin` pins it to the run's ORIGIN
for the whole run — reusing it for the moving head would break that test and move the counter.

Add `var _chain_head := Vector2i(-1, -1)` beside `var _chain_origin_cell`, and:

- `_prepare_chain`: `_chain_head = b` next to `_chain_origin_cell = b`; reset it to
  `Vector2i(-1, -1)` in the same two places `_chain_origin_cell` is reset (`5519`, `5606`).
- `_run_chain_step`: after `var partner := Vector2i(_chain_run.pop_front())` and the merge, set
  `_chain_head = partner`, then call `_publish_guide()` at the end of the function.

Rewrite `_ensure_cascade_outline` to stop calling `configure()` on every publish — it clears the
geometry cache. Call `configure()` only when the node is created or `csz` changed:

```gdscript
func _ensure_cascade_outline() -> Control:
	if not Features.on("cascade") or board_area == null or not is_instance_valid(board_area):
		if _cascade_outline != null and is_instance_valid(_cascade_outline):
			_cascade_outline.queue_free()
		_cascade_outline = null
		_guide_cell_size = -1.0
		return null
	if _cascade_outline == null or not is_instance_valid(_cascade_outline) \
			or _cascade_outline.is_queued_for_deletion() or _cascade_outline.get_parent() != board_area:
		if _cascade_outline != null and is_instance_valid(_cascade_outline):
			if _cascade_outline.get_parent() != null:
				_cascade_outline.get_parent().remove_child(_cascade_outline)
			_cascade_outline.queue_free()
		_cascade_outline = CascadeOutline.new()
		board_area.add_child(_cascade_outline)
		_guide_cell_size = -1.0
	if not is_equal_approx(_guide_cell_size, csz):
		_cascade_outline.configure(Vector2(_board_w(), _board_h()), csz, Callable(self, "_cell_pos"))
		_guide_cell_size = csz
	_position_cascade_outline()
	return _cascade_outline
```

Add `var _guide_cell_size := -1.0` beside `var _cascade_outline`.

- [ ] **Step 5: Fix the stack index**

Replace `_position_cascade_outline`'s body:

```gdscript
func _position_cascade_outline() -> void:
	if _cascade_outline == null or not is_instance_valid(_cascade_outline) \
			or _cascade_outline.get_parent() != board_area:
		return
	board_area.move_child(_cascade_outline, _guide_stack_index())

## The guide belongs ABOVE the slots and BELOW every piece and generator — it is light under the
## board, not over the art. move_child's target index is measured AFTER the node is pulled out, so
## moving down one place from below the first item needs that one subtracted; without it the guide
## landed one place too high and painted over a piece on every drag frame.
func _guide_stack_index() -> int:
	var item_min := board_area.get_child_count()
	for raw_node in gen_nodes.values() + piece_nodes.values():
		var n := raw_node as Node
		if n != null and is_instance_valid(n) and not n.is_queued_for_deletion() \
				and n.get_parent() == board_area:
			item_min = mini(item_min, n.get_index())
	var want := item_min
	if _cascade_outline.get_index() < item_min:
		want = item_min - 1
	return clampi(want, 0, maxi(0, board_area.get_child_count() - 1))
```

- [ ] **Step 6: Repoint every call site**

Replace with `_publish_guide()`: `board.gd:1859` (`_after_board_change`), `2896` (`_rebuild_all`),
`5144` (`_clear_drag_feel`), `5188` (`_begin_drag`), `5531` (`_prepare_chain`), `5610`
(`_finish_chain`). In `_show_chain_preroll` (`5553-5572`) delete the `set_ladders` block and keep
only the pulse tween plus a `_publish_guide()` call before it.

- [ ] **Step 7: Delete the renderer's legacy path**

From `cascade_outline.gd` remove `ladders`, `runways`, `drag_ladders`, `ghost_pads`, `set_ladders`,
`set_runways`, `set_drag_ladders`, `set_ghost_pads`, `clear_guides`, `_active_ladders`,
`_draw_ladder`, `_draw_runway`, `_draw_ghost_pad`, `_chain_cells`, `_draw_legacy`, and the
`drag_ladders.is_empty()` tests in `_sync_process` and `_rebuild_tags`. `_draw` becomes the
mark loop alone; `_sync_process` becomes `set_process(forced_phase < 0.0 and _has_live_mark())`.

- [ ] **Step 8: Port the grove suite's read helpers**

`_outline_ladder_count`, `_outline_runway_count`, `_outline_drag_ladder_count`,
`_outline_drag_ladder_run`, `_outline_ready_ladder_run`, `_outline_pad_count`,
`_outline_pad_count_by_kind`, `_outline_pad_cells_by_kind`, `_outline_has_pad_kind_at` all read the
deleted arrays. Reimplement each over `marks`, mapping the old vocabulary onto roles: `ladder` →
`role == "chain"`, `runway` → `role == "runway"`, `pad kind stage` → `role == "stage"`, `pad kind
cascade` → `role == "target" and tag`, `pad kind merge` → `role == "target" and not tag`.

Expected behaviour changes to update in the asserts, each traceable to the spec:
- at most `REST_MAX` resting marks;
- a drag emits exactly one loud target, others at `DRAG_DIM`;
- a drag that forms no chain emits no chain or runway mark.

- [ ] **Step 9: Run everything**

```bash
make test-grove GROVE_TESTS=games/grove/tests/grove_cascade_tests
make test
```

Expected: `0 failed` in every suite, and the two new guards from Step 2 now PASS.

- [ ] **Step 10: Look at it — one batched capture**

```bash
printf '%s\n' 'grove played /tmp/guide_rest.png' 'grove hud /tmp/guide_hud.png' > /tmp/guide_plan.txt
make shot-batch PLAN=/tmp/guide_plan.txt
```

Read both PNGs. The resting board must show at most three chain marks; nothing may paint over piece
art. If a state the batch tools cannot reach matters (mid-run, drag), say so explicitly rather than
claiming it was verified.

- [ ] **Step 11: Import, commit, hand off**

```bash
make import
git status --short          # no untracked .uid may remain
git add -A
git commit -m "refactor(cascade): one derived mark list owns the whole visual guide"
make test
```

Report: the blank-frame and bad-stack counts measured on the parent in Step 3, the same counts now,
the net line change across the three files, and what the capture showed.
