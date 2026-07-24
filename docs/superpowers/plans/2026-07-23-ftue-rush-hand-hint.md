# FTUE Rush Hand Hints — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Teach a brand-new player the two Rush verbs with a pointing hand — tap a mergeable tile (first merge), and tap the bottom tile of a telegraphed column to dodge a treefall — each once, then never again.

**Architecture:** Reuse the existing `engine/scripts/ui/hand_hint.gd` overlay unchanged (its `tap` gesture) and the existing `Save.ftue_seen` ledger. Add three pure eligibility functions to `engine/scripts/core/explore.gd`, and wire them into `engine/scripts/scenes/explore_rush.gd` (mirroring `board.gd`'s hand-hint block) behind a new `ftue_rush_hint` flag. Rush hint rects come from **cell geometry**, so they are stable across fall/fling tweens and need no layout `await`.

**Tech Stack:** Godot 4.6, GDScript. Headless SceneTree test suites run via `engine/tools/run_suites.py` (`make test-fast` / `make test`).

## Global Constraints

- Board dimensions: `G.ROWS = 9`, `G.COLS = 7` (from `games/grove/grove_data.gd`).
- `Explore.MAX_TIER = 7` — a tile at MAX_TIER cannot merge (a tap flings it instead).
- Rush cell dictionaries are `{"kind", "tier", "node"}`; `kind` is an **integer** line index (1/2/3), so kind comparisons use `str()`, never `String()` (`String(int)` has no constructor and crashes). Pure functions only read `.tier` and delegate kind matching to `neighbor_match`.
- Feature flags live in `engine/scripts/core/features.gd` as a `static var FLAGS` dict; tests flip via `Features.FLAGS["id"] = false` and restore the original after. Rule N4: every new FTUE feature ships behind a flag.
- Overlay API (do not change): `HandHint.present(host, gesture_id, source_rect, target_rect) -> Control`, `.retarget(src, dst)`, `.dismiss()`. `gesture_id` for both Rush teaches is `HandHint.GESTURE_TAP` (uses `target_rect` only). `present` returns `null` when its own `ftue_hand_hint` flag is off.
- Run `make test-fast` after every change; `make test` green before handoff.

---

### Task 1: Pure Rush hand-hint eligibility in `explore.gd`

**Files:**
- Modify: `engine/scripts/core/explore.gd` (add three static functions after `board_full`, ~line 217)
- Test: `games/grove/tests/grove_explore_tests.gd` (add a `_test_hand_hint_logic()` subtest, call it from `_initialize`)

**Interfaces:**
- Consumes: existing `Explore.neighbor_match(grid, r, c) -> Vector2i`, `Explore._cols(grid) -> int`, `Explore.MAX_TIER`.
- Produces (later tasks rely on these exact signatures):
  - `Explore.first_mergeable(grid: Array) -> Vector2i` — row-major first mergeable cell, else `(-1,-1)`.
  - `Explore.bottom_filled(grid: Array, col: int) -> int` — lowest filled row in `col`, else `-1`.
  - `Explore.rush_hint_id(merge_seen: bool, treefall_seen: bool, tele_active: bool, has_pair: bool, has_doomed_tile: bool) -> String` — `"rush_treefall"` / `"rush_merge"` / `""`.

- [ ] **Step 1: Write the failing test**

Add this subtest to `games/grove/tests/grove_explore_tests.gd`, and add the line `_test_hand_hint_logic()` to `_initialize()` right after the existing `_test_grid()` call:

```gdscript
func _test_hand_hint_logic() -> void:
	# first_mergeable: finds the first row-major mergeable cell
	var g := _grid(3, 3)
	g[2][0] = {"kind": 1, "tier": 1}
	g[2][1] = {"kind": 1, "tier": 1}
	ok(Explore.first_mergeable(g) == Vector2i(2, 0), "first_mergeable returns the first cell of a mergeable pair")
	# no pair -> (-1,-1)
	g[2][1] = {"kind": 2, "tier": 1}
	ok(Explore.first_mergeable(g) == Vector2i(-1, -1), "first_mergeable is (-1,-1) with no mergeable pair")
	# MAX_TIER cells cannot merge, so a maxed matching pair is not mergeable
	var gm := _grid(3, 3)
	gm[2][0] = {"kind": 1, "tier": Explore.MAX_TIER}
	gm[2][1] = {"kind": 1, "tier": Explore.MAX_TIER}
	ok(Explore.first_mergeable(gm) == Vector2i(-1, -1), "first_mergeable skips a MAX_TIER pair (cannot merge)")

	# bottom_filled: lowest filled row in the column, -1 when empty
	var gb := _grid(3, 2)
	gb[1][0] = {"kind": 1, "tier": 1}
	gb[2][0] = {"kind": 1, "tier": 1}
	ok(Explore.bottom_filled(gb, 0) == 2, "bottom_filled returns the lowest filled row")
	ok(Explore.bottom_filled(gb, 1) == -1, "bottom_filled is -1 for an empty column")

	# rush_hint_id ordering
	ok(Explore.rush_hint_id(false, false, true, true, true) == "rush_treefall",
		"treefall wins during a telegraph, even with an unseen merge and a live pair")
	ok(Explore.rush_hint_id(false, false, false, true, false) == "rush_merge",
		"merge shows when no telegraph is active")
	ok(Explore.rush_hint_id(false, false, true, true, false) == "rush_merge",
		"a telegraph with no doomed tile falls through to the merge teach")
	ok(Explore.rush_hint_id(false, true, true, true, true) == "rush_merge",
		"a seen treefall during a telegraph falls through to the merge teach")
	ok(Explore.rush_hint_id(true, false, false, true, false) == "",
		"nothing when merge is seen and no telegraph")
	ok(Explore.rush_hint_id(false, false, false, false, false) == "",
		"nothing when there is no mergeable pair and no telegraph")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `make test-one SUITE=games/grove/tests/grove_explore_tests`
Expected: FAIL — the run aborts with a parse/runtime error on the unknown `Explore.first_mergeable` / `bottom_filled` / `rush_hint_id`.

- [ ] **Step 3: Write the implementation**

Add to `engine/scripts/core/explore.gd` immediately after the `board_full` function (which ends ~line 217):

```gdscript
# --- FTUE hand-hint eligibility (pure) -------------------------------------------
# Which Rush teach should be live, and where it points. Pure (no scene state) so the teach order +
# targeting are asserted headlessly. Spec: docs/superpowers/specs/2026-07-23-ftue-rush-hand-hint-design.md

## First cell (row-major) that can merge — below MAX_TIER and with a same-kind/same-tier orthogonal
## neighbour — or (-1,-1) when the board holds no mergeable pair.
static func first_mergeable(grid: Array) -> Vector2i:
	var cols := _cols(grid)
	for r in grid.size():
		for c in cols:
			var cell = grid[r][c]
			if cell == null or int(cell.tier) >= MAX_TIER:
				continue
			if neighbor_match(grid, r, c) != Vector2i(-1, -1):
				return Vector2i(r, c)
	return Vector2i(-1, -1)

## The lowest filled row in column `col` (the bottom tile the treefall teach points at), or -1 when
## the column is empty. Gravity packs columns to the bottom, so this is normally the last filled row.
static func bottom_filled(grid: Array, col: int) -> int:
	if col < 0 or col >= _cols(grid):
		return -1
	for r in range(grid.size() - 1, -1, -1):
		if grid[r][col] != null:
			return r
	return -1

## WHICH Rush teach should be live right now. "" = none. Treefall wins during a telegraph (it is
## time-critical and self-expiring); the merge teach shows otherwise.
static func rush_hint_id(merge_seen: bool, treefall_seen: bool, tele_active: bool,
		has_pair: bool, has_doomed_tile: bool) -> String:
	if tele_active and not treefall_seen and has_doomed_tile:
		return "rush_treefall"
	if not merge_seen and has_pair:
		return "rush_merge"
	return ""
```

- [ ] **Step 4: Run test to verify it passes**

Run: `make test-one SUITE=games/grove/tests/grove_explore_tests`
Expected: PASS — all new `ok(...)` lines pass, suite ends `== N passed, 0 failed ==`.

- [ ] **Step 5: Commit**

```bash
cd /Users/xup/dh/wt-ftue-rush-hand-hint
git add engine/scripts/core/explore.gd games/grove/tests/grove_explore_tests.gd
git commit -m "explore: pure Rush hand-hint eligibility (first_mergeable / bottom_filled / rush_hint_id)"
```

---

### Task 2: Wire the Rush hand hints into `explore_rush.gd`

**Files:**
- Modify: `engine/scripts/core/features.gd` (add the `ftue_rush_hint` flag)
- Modify: `engine/scripts/scenes/explore_rush.gd` (imports, members, methods, call sites)
- Create: `games/grove/tests/grove_rush_ftue_tests.gd` (scene-wiring suite)
- Modify: `Makefile` (register the new suite in `GROVE_TESTS`)

**Interfaces:**
- Consumes: `Explore.first_mergeable`, `Explore.bottom_filled`, `Explore.rush_hint_id` (Task 1); `HandHint.present/retarget/dismiss`, `HandHint.GESTURE_TAP`; `Save.ftue_seen`, `Save.mark_ftue_seen`; `Features.on`.
- Produces (the test suite relies on these scene members/methods): `explore_rush.gd` gains `_hand_hint: Control`, `_hand_hint_id: String`, `_refresh_hand_hint()`, `_hand_hint_cell_rect(r, c) -> Rect2`, `_dismiss_hand_hint()`, `_end_hand_hint(id: String)`.

- [ ] **Step 1: Write the failing test**

Create `games/grove/tests/grove_rush_ftue_tests.gd`:

```gdscript
extends "res://games/grove/tests/grove_test_base.gd"
## grove · Rush FTUE hand hints — the scene wiring in engine/scripts/scenes/explore_rush.gd
## (_refresh_hand_hint / _hand_hint_cell_rect / _dismiss_hand_hint / _end_hand_hint) driving the reused
## overlay (engine/scripts/ui/hand_hint.gd) on a real, in-tree ExploreRush.tscn.
## Spec: docs/superpowers/specs/2026-07-23-ftue-rush-hand-hint-design.md

const Feat = preload("res://engine/scripts/core/features.gd")
const Explore = preload("res://engine/scripts/core/explore.gd")
const HandHint = preload("res://engine/scripts/ui/hand_hint.gd")
const G = preload("res://engine/scripts/core/content.gd")

func _initialize() -> void:
	begin("grove · rush ftue hand hint")
	await process_frame   # prime is_inside_tree() before the manual ExploreRush _ready() calls
	await _test_flag_off_presents_nothing()
	await _test_merge_pair_presents_merge_hint()
	await _test_telegraph_presents_treefall_over_merge()
	finish()

# A live, frozen ExploreRush on a known-EMPTY board. _ready()->_start() builds an all-null grid and
# leaves _running = true; freezing _process stops tiles spawning / the treefall clock advancing under us.
func _rush() -> Node:
	Explore.begin_run({})
	Save.mark_rush_intro_seen()   # spend the first-run how-to popup so it can't cover the hint
	var s = load("res://engine/scenes/ExploreRush.tscn").instantiate()
	get_root().add_child(s)
	if s.get_child_count() == 0:
		s._ready()
	s.set_process(false)          # freeze the frame loop; we drive state by hand
	return s

func _live_hand_hint(s: Node) -> Control:
	for c in s.get_children():
		if c is Control and (c as Control).get_script() == HandHint and not bool(c.get("dismissed")):
			return c as Control
	return null

func _test_flag_off_presents_nothing() -> void:
	fresh("rush_ftue_flag_off")
	var orig := bool(Feat.FLAGS.get("ftue_rush_hint", true))
	Feat.FLAGS["ftue_rush_hint"] = false
	var s := _rush()
	s._grid[8][0] = {"kind": 1, "tier": 1, "node": null}
	s._grid[8][1] = {"kind": 1, "tier": 1, "node": null}
	s._refresh_hand_hint()
	ok(_live_hand_hint(s) == null, "flag off: a mergeable pair presents no hint")
	Feat.FLAGS["ftue_rush_hint"] = orig
	s.queue_free()
	await process_frame

func _test_merge_pair_presents_merge_hint() -> void:
	fresh("rush_ftue_merge")
	var s := _rush()
	# a mergeable pair on the bottom row
	s._grid[8][0] = {"kind": 1, "tier": 1, "node": null}
	s._grid[8][1] = {"kind": 1, "tier": 1, "node": null}
	s._refresh_hand_hint()
	var hint := _live_hand_hint(s)
	ok(hint != null, "a mergeable pair presents a live hand hint")
	ok(hint != null and hint.gesture == HandHint.GESTURE_TAP, "...as the tap gesture")
	ok(s._hand_hint_id == "rush_merge", "...and the scene tracks the rush_merge id")
	# the taught cell rect lines up with the real board cell geometry
	var want := Rect2(s._board.position + s._cell_rest(8, 0), Vector2(s._tile_px(), s._tile_px()))
	ok(s._hand_hint_cell_rect(8, 0).is_equal_approx(want), "the rect matches the board cell geometry")
	# performing the merge banks it and clears the hint; a second refresh does not re-present
	s._end_hand_hint("rush_merge")
	ok(Save.ftue_seen("rush_merge"), "the merge teach is marked seen")
	ok(_live_hand_hint(s) == null, "...and the hint is dismissed")
	s._refresh_hand_hint()
	ok(_live_hand_hint(s) == null, "a seen merge teach never re-presents")
	s.queue_free()
	await process_frame

func _test_telegraph_presents_treefall_over_merge() -> void:
	fresh("rush_ftue_treefall")
	var s := _rush()
	# a mergeable pair (merge unseen) AND a telegraph over a filled column 3
	s._grid[8][0] = {"kind": 1, "tier": 1, "node": null}
	s._grid[8][1] = {"kind": 1, "tier": 1, "node": null}
	s._grid[8][3] = {"kind": 2, "tier": 1, "node": null}
	s._tf = {"ph": "tele", "t": 0.0, "col": 3, "next": 9.0}
	s._refresh_hand_hint()
	var hint := _live_hand_hint(s)
	ok(hint != null and s._hand_hint_id == "rush_treefall", "a telegraph beats an unseen merge teach")
	var want := Rect2(s._board.position + s._cell_rest(8, 3), Vector2(s._tile_px(), s._tile_px()))
	ok(s._hand_hint_cell_rect(8, 3).is_equal_approx(want), "the treefall hint points at the bottom tile of the doomed column")
	# dodging (a fling out of the danger column) banks it; the telegraph then yields to the merge teach
	s._end_hand_hint("rush_treefall")
	ok(Save.ftue_seen("rush_treefall"), "the dodge teach is marked seen")
	ok(s._hand_hint_id == "rush_merge", "with the treefall seen, the merge teach follows during the same telegraph")
	s.queue_free()
	await process_frame
```

- [ ] **Step 2: Run test to verify it fails**

Run: `make test-one SUITE=games/grove/tests/grove_rush_ftue_tests`
Expected: FAIL — runtime error on the unknown `s._refresh_hand_hint` / `s._hand_hint_id` / `_hand_hint_cell_rect` / `_end_hand_hint`.

- [ ] **Step 3a: Add the feature flag**

In `engine/scripts/core/features.gd`, in the `# ftue` block, immediately after the `"ftue_hand_hint": true,` line, add:

```gdscript
	"ftue_rush_hint": true,       # the two Rush-panel teaches: tap-to-merge, then dodge a treefall (spec 2026-07-23-rush)
```

- [ ] **Step 3b: Add imports to `explore_rush.gd`**

In `engine/scripts/scenes/explore_rush.gd`, after the existing `const FS = ...` preload block near the top (~line 32), add:

```gdscript
const Features = preload("res://engine/scripts/core/features.gd")   # FTUE: gates the Rush hand teaches
const HandHint = preload("res://engine/scripts/ui/hand_hint.gd")     # FTUE: the reused merge/dodge teach overlay
```

- [ ] **Step 3c: Add the members**

In `explore_rush.gd`, next to the other layout-chrome members (after `var _band: Dictionary = {}` / `var _board_fit: Dictionary = {}`, ~line 108), add:

```gdscript
	# FTUE hand hints (spec 2026-07-23-rush): at most one live overlay + which teach it is
var _hand_hint: Control = null      # the live Rush teach overlay, or null
var _hand_hint_id := ""             # "rush_merge" / "rush_treefall"
```

- [ ] **Step 3d: Add the methods**

In `explore_rush.gd`, add this block just before the `# --- end ---` section (before `func _end()`, ~line 920):

```gdscript
# --- FTUE hand hints -------------------------------------------------------------
# A hand bobs on a mergeable tile (rush_merge) until the first Rush merge, and on the bottom tile of a
# telegraphed column (rush_treefall) until the player flings a tile out of it. Reuses the board FTUE's
# overlay (engine/scripts/ui/hand_hint.gd, tap gesture) + the ftue_seen ledger. Rects come from CELL
# geometry (stable across fall/fling tweens), so no await/layout pass is needed — unlike board.gd, which
# reads live node rects. Spec: docs/superpowers/specs/2026-07-23-ftue-rush-hand-hint-design.md

func _refresh_hand_hint() -> void:
	if not Features.on("ftue_rush_hint"):
		_dismiss_hand_hint()   # the flag can flip off mid-run — tear down, don't strand a live hint
		return
	if not _running:
		_dismiss_hand_hint()   # no teach on a frozen / ended board
		return
	var tele := String(_tf.get("ph", "idle")) == "tele"
	var pair := Explore.first_mergeable(_grid)
	var doomed_row := Explore.bottom_filled(_grid, int(_tf.get("col", 0))) if tele else -1
	var want := Explore.rush_hint_id(
		Save.ftue_seen("rush_merge"), Save.ftue_seen("rush_treefall"),
		tele, pair.x >= 0, doomed_row >= 0)
	if want == "":
		_dismiss_hand_hint()
		return
	var rect: Rect2
	if want == "rush_merge":
		rect = _hand_hint_cell_rect(pair.x, pair.y)
	else:
		rect = _hand_hint_cell_rect(doomed_row, int(_tf.get("col", 0)))
	if _hand_hint != null and is_instance_valid(_hand_hint) and _hand_hint_id == want:
		_hand_hint.retarget(rect, rect)   # same teach, moved board — keep the loop running
		return
	_dismiss_hand_hint()
	_hand_hint = HandHint.present(self, HandHint.GESTURE_TAP, rect, rect)
	_hand_hint_id = want if _hand_hint != null else ""

# The taught cell in THIS scene's coordinate space, from stable layout math (no node lookup): the board
# is a direct child at _board.position, and _cell_rest(r,c) is the tile's rest inside the board.
func _hand_hint_cell_rect(r: int, c: int) -> Rect2:
	return Rect2(_board.position + _cell_rest(r, c), Vector2(_tile_px(), _tile_px()))

func _dismiss_hand_hint() -> void:
	if _hand_hint != null and is_instance_valid(_hand_hint):
		_hand_hint.dismiss()
	_hand_hint = null
	_hand_hint_id = ""

# The taught action HAPPENED — bank it and hand off to the next teach. Mirrors board.gd::_end_hand_hint.
func _end_hand_hint(id: String) -> void:
	if not Features.on("ftue_rush_hint"):
		_dismiss_hand_hint()   # flag off: tear down ANY live hint, no ledger write
		return
	if _hand_hint_id == id:
		_dismiss_hand_hint()   # clear the live hint even if `id` is already seen (the check below returns early)
	if Save.ftue_seen(id):
		return
	Save.mark_ftue_seen(id)
	_refresh_hand_hint()
```

- [ ] **Step 3e: Add the call sites**

Six one-line insertions. In `engine/scripts/scenes/explore_rush.gd`:

1. End of `_layout()` — after the last line `_last_view = get_viewport_rect().size` (~line 164):
```gdscript
	_refresh_hand_hint()                       # FTUE: the teach follows the relaid-out board
```

2. End of `_spawn()` — the function currently ends with `if Explore.board_full(_grid): _end()`. Add a line after that `if` block:
```gdscript
	_refresh_hand_hint()                       # FTUE: a new tile may have created the first mergeable pair
```

3. End of `_merge()` — after the last line `_refresh_readouts()` (~line 739):
```gdscript
	_end_hand_hint("rush_merge")               # FTUE: the first merge banks the merge teach
	_refresh_hand_hint()                       # ...and re-evaluate (a live treefall teach may need retargeting)
```

4. End of `_fling()` — after the last line `Audio.play("button_tap", -5.0, 1.2)` (~line 759). `danger` and `rc` are already in scope (`danger` is computed at the top of `_fling`; `rc.y` is the tile's source column):
```gdscript
	if rc.y == danger:
		_end_hand_hint("rush_treefall")        # FTUE: a fling OUT of the doomed column is the taught dodge
	_refresh_hand_hint()
```

5. End of `_start_timber()` — after the last line `_apply_treefall_visual()` (~line 766):
```gdscript
	_refresh_hand_hint()                       # FTUE: a telegraph began — the treefall teach may now win
```

6. End of `_drop_timber()` — after the last line `_refresh_readouts()` (~line 796):
```gdscript
	_refresh_hand_hint()                       # FTUE: the telegraph ended — back to the merge teach
```

- [ ] **Step 3f: Register the new suite in the Makefile**

In `Makefile`, append the new suite to the `GROVE_TESTS :=` list (line 15), after `games/grove/tests/grove_ftue_tests`:

```
games/grove/tests/grove_rush_ftue_tests
```

(It is one space-separated entry on the same `GROVE_TESTS :=` line.)

- [ ] **Step 4: Run the tests**

Run: `make test-one SUITE=games/grove/tests/grove_rush_ftue_tests`
Expected: PASS — all `ok(...)` lines pass, suite ends `== N passed, 0 failed ==`.

Then confirm no regression in the touched suites:

Run: `make test-one SUITE=games/grove/tests/grove_explore_tests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/xup/dh/wt-ftue-rush-hand-hint
git add engine/scripts/core/features.gd engine/scripts/scenes/explore_rush.gd games/grove/tests/grove_rush_ftue_tests.gd Makefile
git commit -m "rush: FTUE hand hints — tap-to-merge + treefall dodge (flag ftue_rush_hint)"
```

---

### Task 3: Full sweep + visual verification

**Files:**
- Modify: `games/grove/tools/rush_shot.gd` (force the hand hint on for the capture modes)

**Interfaces:**
- Consumes: `explore_rush.gd::_refresh_hand_hint` and `_grid` (Task 2).
- Produces: two screenshots for human review (no test assertion).

- [ ] **Step 1: Extend the shot tool to force a hand hint**

In `games/grove/tools/rush_shot.gd`, the tool already seeds tiles and (in `treefall` mode) telegraphs a treefall. Add, right before the `RenderingServer.force_draw()` line, a block that seeds a deterministic mergeable pair for the merge shot and refreshes the hint for both:

```gdscript
	if mode == "merge_hint":
		# a guaranteed mergeable pair on the bottom row so the merge teach has a target
		var land0 := scn._bottom_empty(0)
		var land1 := scn._bottom_empty(1)
		if land0 >= 0:
			scn._grid[land0][0] = {"kind": 1, "tier": 1, "node": scn._make_tile(1, 1, land0, 0)}
		if land1 >= 0:
			scn._grid[land1][1] = {"kind": 1, "tier": 1, "node": scn._make_tile(1, 1, land1, 1)}
		await create_timer(0.3).timeout
	if mode == "merge_hint" or mode == "treefall":
		scn._refresh_hand_hint()                 # FTUE: force the teach so the shot captures the hand
		await create_timer(0.2).timeout
```

Also add `merge_hint` to the mode doc comment at the top of the file (the `## modes:` line).

- [ ] **Step 2: Capture the two hint shots**

Run (foreground; `make shot` uses the real renderer via `engine/tools/quiet_godot.sh`, which drops the born-minimized `override.cfg` the tool requires — never a visible/focused window):

```bash
cd /Users/xup/dh/wt-ftue-rush-hand-hint
make shot TOOL=games/grove/tools/rush_shot ARGS="merge_hint /tmp/rush_merge_hint.png 1080x1920"
make shot TOOL=games/grove/tools/rush_shot ARGS="treefall /tmp/rush_treefall_hint.png 1080x1920"
```

Expected: each prints `SHOT saved=... err=0 ...` and writes the PNG.

- [ ] **Step 3: Look at the shots (blocking gate — do not skip)**

Read both PNGs and confirm: on `rush_merge_hint`, the hand sits on one tile of the matching bottom-row pair; on `rush_treefall_hint`, the hand sits on the bottom tile of the red telegraphed column (col 3). If the hand is absent or mis-placed, diagnose against `_refresh_hand_hint` / `_hand_hint_cell_rect` before proceeding — a wrong shot means the wiring is wrong, not the shot.

- [ ] **Step 4: Full test sweep**

Run: `make test`
Expected: the per-suite table prints and ends with every suite PASS (0 failed), including `grove_explore_tests` and `grove_rush_ftue_tests`.

- [ ] **Step 5: Commit**

```bash
cd /Users/xup/dh/wt-ftue-rush-hand-hint
git add games/grove/tools/rush_shot.gd
git commit -m "rush_shot: merge_hint mode + force the FTUE hand hint for capture"
```

---

## Self-Review

**Spec coverage:**
- Two teaches (rush_merge, rush_treefall), tap gesture, reuse overlay unchanged → Task 2 methods + Task 1 logic. ✓
- Once-ever per hint via `ftue_seen` → `_end_hand_hint` uses `Save.mark_ftue_seen`; tests assert. ✓
- Treefall completion only on a real dodge (fling out of the danger column) → Task 2 call site 4 (`if rc.y == danger`). ✓
- Priority: treefall wins during a telegraph → `Explore.rush_hint_id` + Task 1 test. ✓
- New `ftue_rush_hint` flag, default ON, independent of `ftue_hand_hint` → Task 2 step 3a; flag-off test. ✓
- Rects from cell geometry, no await → `_hand_hint_cell_rect`; test asserts rect equality. ✓
- Non-blocking / z-order → inherited from the unchanged overlay (`MOUSE_FILTER_IGNORE`, z 500 < MODAL_Z); no new code, so no new test. ✓
- Verification: pure headless (Task 1), scene wiring (Task 2), visual + full sweep (Task 3). ✓

**Placeholder scan:** none — every code step shows complete code; every run step shows the exact command and expected result.

**Type consistency:** `first_mergeable`/`bottom_filled`/`rush_hint_id` signatures identical across Task 1 (definition + tests) and Task 2 (`_refresh_hand_hint` call). `_hand_hint_cell_rect(r, c) -> Rect2`, `_end_hand_hint(id)`, `_refresh_hand_hint()`, `_hand_hint_id`, `_hand_hint` used identically in the scene and the test suite. Ids `"rush_merge"` / `"rush_treefall"` spelled consistently everywhere.
