# Core Rework — Phase 1 Implementation Plan (drag-any-to-any + Locked Drawer)

> **For agentic workers:** execute task-by-task, TDD where the plan gives tests; judge *feel* by the screenshot steps. Steps use `- [ ]`.

**Goal:** Replace the adjacency+sliding core with **drag any two matching items (anywhere) → merge**, on a **bigger, juicy, multi-family board**, plus the **Locked Drawer** friction (a drawer pops open when a merge completes orthogonally adjacent to it). Produce a playable feel-check.

**Architecture:** `board.gd`'s `apply_merge(src,dst)` already merges any two same-code cells with no adjacency check — so the new core is mostly *deleting* the slide/swipe/reachable/reposition code in `main.gd` and changing the drop rule to "dropped on a matching piece → merge, else snap back." Drawers are a new cell code `DRAWER = -2` with contents held in a `drawers` map on the level; `is_cleared` now also blocks on a closed drawer. The verified `board.gd` sliding methods (`reachable_empties`/`merge_targets`/`apply_reposition`/`successors`/`is_solvable`) are left in place but unused (don't break `run_tests.gd`).

**Tech Stack:** Godot 4.6.2 GDScript. Headless tests via `godot --headless -s res://tests/<f>.gd`. Feel-check via `tools/screenshot.gd`.

**Binary:** `/opt/homebrew/bin/godot`

**Design knobs (owner direction):** lots of juice; bigger grid; all 3 families/colors on the board; adjacent-merge drawer trigger; board-clear is the only win.

---

### Task 1: board.gd — Locked Drawer cell support

**Files:** Modify `scripts/board.gd`; Test `tests/save_tests.gd` is unrelated — add a new `tests/core_tests.gd`.

- [ ] **Step 1: Write `tests/core_tests.gd` (failing)**

```gdscript
extends SceneTree
## Headless tests for the drag-any-to-any core + drawers.
##   godot --headless -s res://tests/core_tests.gd
const Board = preload("res://scripts/board.gd")
var _pass := 0
var _fail := 0
func ok(c: bool, l: String) -> void:
	if c: _pass += 1; print("  PASS  ", l)
	else: _fail += 1; print("  FAIL  ", l)

func _initialize() -> void:
	print("== core tests ==")
	# drawer (-2) is not a piece, and blocks is_cleared until popped
	var b := Board.new(1, 3, [101, 0, Board.DRAWER], 3)
	ok(not Board.is_piece(Board.DRAWER), "DRAWER is not a piece")
	ok(not b.is_cleared(), "closed drawer keeps board not-cleared")
	b.grid = [0, 0, 0]
	ok(b.is_cleared(), "empty board is cleared")
	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
```

- [ ] **Step 2: Run → FAIL** (`Board.DRAWER` undefined). `/opt/homebrew/bin/godot --headless -s res://tests/core_tests.gd`

- [ ] **Step 3: Implement in `scripts/board.gd`**

Add the constant beside `EMPTY`/`WALL`:

```gdscript
const DRAWER := -2        # a locked drawer/box: not a piece; pops to its contents on an adjacent merge
```

Change `is_cleared()` to also block on a closed drawer:

```gdscript
func is_cleared() -> bool:
	for v in grid:
		if v > 0 or v == DRAWER:
			return false
	return true
```

Update the file header comment's first lines to describe drag-any-to-any (cosmetic): replace the "slides rook-style" sentence with `## Items merge when two of the SAME code (family+tier) are brought together (drag-any-to-any).`

- [ ] **Step 4: Run → `== 3 passed, 0 failed ==`**

- [ ] **Step 5: Commit** `git add -A && git commit -m "feat(board): Locked Drawer cell (DRAWER=-2) + is_cleared blocks on it"`

---

### Task 2: main.gd — drag-any-to-any merge (delete sliding)

**Files:** Modify `scripts/main.gd`.

- [ ] **Step 1: Rework `_on_release`** — replace the merge-target/reachable/swipe branches with the any-match rule:

```gdscript
func _on_release(p: Vector2) -> void:
	if not _dragging:
		return
	_dragging = false
	var node := _drag_node
	_drag_node = null
	var src := _drag_from
	var rel := _pos_to_cell(p)
	if rel != src and board.in_bounds(rel.x, rel.y) \
			and board.at(rel.x, rel.y) == board.at(src.x, src.y) \
			and Board.is_piece(board.at(src.x, src.y)):
		_commit(src, rel)            # dropped on a MATCHING item → merge
	else:
		_snap_back(node, src)        # anywhere else → return it home
```

- [ ] **Step 2: Simplify `_on_press`** — allow picking up any piece that has at least one matching partner; otherwise a soft shake. Replace the `_has_moves(c)` check body of `_has_moves`:

```gdscript
func _has_moves(cell: Vector2i) -> bool:
	# a piece is pickable if another item of the SAME code exists on the board
	var code := board.at(cell.x, cell.y)
	if not Board.is_piece(code):
		return false
	for r in board.rows:
		for c in board.cols:
			if (r != cell.x or c != cell.y) and board.at(r, c) == code:
				return true
	return false
```

(`_on_press` itself is unchanged — it already calls `_has_moves` then pops the piece out and follows the pointer.)

- [ ] **Step 3: Rework `_commit`** to merge-only (drop the `is_merge`/reposition param) and hook drawer-pop. Replace `_commit` (and make `_after_move` merge-only) so it: records history, reads `showcase = board.is_showcase_merge(src)`, calls `board.apply_merge(src,dst)`, animates the dragged node to `dst` then plays the merge pop/particles, then calls `_pop_drawers_adjacent(dst)`, refreshes, and plays the clear screen if `board.is_cleared()`. Keep all existing juice/SFX calls. Remove the `apply_reposition` path entirely. (Exact edits are mechanical against the current `_commit`/`_after_move`; preserve every `Audio.play`, `_pop`, `_burst`, `_flash` call.)

- [ ] **Step 4: Delete now-dead code** — remove `_swipe`, `_dir_of`, `SWIPE_MIN`, and any `reachable_empties`/`merge_targets`/`apply_reposition` calls. Grep to confirm none remain: `grep -nE "_swipe|_dir_of|reachable_empties|merge_targets|apply_reposition|SWIPE_MIN" scripts/main.gd` → only the `_has_moves` rewrite (no matches expected).

- [ ] **Step 5: Run smoke** (expect the OLD swipe/drag asserts to FAIL — they test sliding; we rewrite them in Task 6). `/opt/homebrew/bin/godot --headless -s res://tests/smoke.gd` — confirm it at least *loads* without parse errors.

- [ ] **Step 6: Commit** `git commit -am "feat(core): drag-any-to-any merge; delete sliding/swipe/reposition"`

---

### Task 3: main.gd — highlight all matching items while holding one

**Files:** Modify `scripts/main.gd` (`_refresh_highlights`).

- [ ] **Step 1: Replace `_refresh_highlights`** — when a piece is held, ring every OTHER cell with the same code (the merge targets), in green; drop the blue reachable-empties rings:

```gdscript
func _refresh_highlights() -> void:
	_clear_highlights()
	if selected == NONE or not Board.is_piece(board.at(selected.x, selected.y)):
		return
	var code := board.at(selected.x, selected.y)
	for r in board.rows:
		for c in board.cols:
			if (r != selected.x or c != selected.y) and board.at(r, c) == code:
				_add_ring(Vector2i(r, c), Palette.GOOD)   # green: drop here to merge
```

- [ ] **Step 2: Screenshot feel-check** — `/opt/homebrew/bin/godot --path . -s res://tools/screenshot.gd -- res://scenes/Main.tscn /tmp/cr_hl.png "266,266"` then Read `/tmp/cr_hl.png`. Expected: holding a piece glows its matches green; no blue rings. Confirm no errors.

- [ ] **Step 3: Commit** `git commit -am "feat(core): hold an item -> highlight all matching items"`

---

### Task 4: main.gd — render drawers + pop on adjacent merge

**Files:** Modify `scripts/main.gd` (drawer state, render in `_build_slots`/`_rebuild_pieces`, `_pop_drawers_adjacent`, parse in `_load_level`).

- [ ] **Step 1:** Add drawer state + load. In `_load_level`, after building `board`, populate a drawer-contents map from the level:

```gdscript
drawer_contents.clear()
for k in lv.get("drawers", {}):
	drawer_contents[k] = int(lv["drawers"][k])   # k = flat cell index, value = contained code
```

Add `var drawer_contents := {}` to the state vars.

- [ ] **Step 2: Render a closed drawer** where `board.at(r,c) == Board.DRAWER`. In `_rebuild_pieces` (or `_build_slots`), for drawer cells add a placeholder "locked" visual (a `Panel` with a distinct dark StyleBox + a "✦" or lock `Label`), stored in `piece_nodes`-parallel `drawer_nodes := {}`. (Placeholder art for the feel-check; real drawer art comes later via ICON_PROMPTS.)

- [ ] **Step 3: Pop on adjacent merge.** Add:

```gdscript
func _pop_drawers_adjacent(cell: Vector2i) -> void:
	for d in [Vector2i(-1,0), Vector2i(1,0), Vector2i(0,-1), Vector2i(0,1)]:
		var n := cell + d
		if board.in_bounds(n.x, n.y) and board.at(n.x, n.y) == Board.DRAWER:
			var idx := board.index(n.x, n.y)
			var code: int = drawer_contents.get(idx, 101)
			board.grid[idx] = code
			drawer_contents.erase(idx)
			_pop_open_drawer(n, code)     # juice: lid pop + spawn the item piece
```

`_pop_open_drawer(cell, code)` frees the drawer node, spawns a piece node for `code` at the cell with a springy pop (reuse `_pop`/`_burst`), plays `tidy_poof`/`item_drop`. Call `_pop_drawers_adjacent(dst)` from `_commit` after the merge resolves.

- [ ] **Step 4: Run core tests + screenshot.** Add a drawer-pop assertion to `tests/core_tests.gd` (simulate a merge adjacent to a drawer via `inst`-style headless, OR a board-level check that popping sets the cell to its contents). Screenshot a level with drawers; confirm they render and pop.

- [ ] **Step 5: Commit** `git commit -am "feat(friction): Locked Drawer renders + pops on adjacent merge"`

---

### Task 5: levels.gd — a bigger, mixed, juicy feel-check level

**Files:** Modify `scripts/levels.gd` (prepend a Phase-1 feel-check level and load it first).

- [ ] **Step 1:** Add a 5×6 level mixing all 3 families with a couple of drawers, as `LEVELS[0]` (so the feel-check loads it). Use even counts per code so it's clearable. Example shape (codes: clothes 101.., books 201.., toys 301.., `-2` = drawer):

```gdscript
{
	"id": "feel_big_01",
	"name": "A proper tidy",
	"rows": 5, "cols": 6, "top": 3,
	"grid": [
		101,101, 201,201,  0,  0,
		301,301,  -2,102,102,  0,
		  0,201,201, 301,301,  0,
		102,102, 101,101, -2,202,
		  0,  0, 202,  0,  0,  0,
	],
	"drawers": { 8: 103, 28: 202 },   # flat indices of the two -2 cells -> contents
	"hint": "Drag any two matching items together to tidy them. Merges next to a drawer pop it open!",
}
```

(Verify the two `-2` cells are at flat indices 8 and 28 for a 6-wide grid, and that every non-drawer code appears an even number of times so the board fully clears; adjust counts as needed.)

- [ ] **Step 2: Screenshot the big board** — render Main, Read it. Confirm a bigger multi-color board with two drawers, no overflow off-screen (the tray/cell sizing may need the grid to scale — if it overflows, reduce CELL for big boards or scroll; note for follow-up).

- [ ] **Step 3: Commit** `git commit -am "feat(levels): bigger mixed feel-check level with drawers"`

---

### Task 6: rewrite tests for the new core + final feel-check

**Files:** Modify `tests/smoke.gd`.

- [ ] **Step 1:** Replace smoke's SWIPE/DRAG assertions (they test `_dir_of`/sliding) with a **drag-any-to-any** assertion: press a piece, release on a same-code piece anywhere, assert the merge happened (target bumped a tier or board changed). Remove `_dir_of` usage.

- [ ] **Step 2: Run everything**: `core_tests` (all pass), `smoke` (all OK), and `run_tests` (still 9/9 — board.gd sliding methods unchanged). Note: `run_tests.gd` now tests dormant code; leave it for now.

- [ ] **Step 3: Final feel-check screenshots** — render Main (resting) and a held-piece state; Read both; judge: does it look juicy and inviting at the bigger scale, with matching-item highlights and drawers reading clearly?

- [ ] **Step 4: Commit** `git commit -am "test(core): drag-any-to-any smoke; core-rework Phase 1 complete"`

---

## Notes / follow-ups (not Phase 1)
- Big-board cell sizing: if 5×6 overflows portrait, add per-level CELL scaling or a fitted board_area; flagged in Task 5.
- Real drawer art (closed drawer + per-family contents peeking) → add to ICON_PROMPTS.
- Job Ticket + Fill the Shelf = Phase 2.
- `board.gd` solver/sliding methods + `run_tests.gd` can be retired in a later cleanup once nothing references them.
