# Cell Improvements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add flagged Soil and Magnet board-cell improvements for Grove's home board.

**Architecture:** Keep persistent improvement state in `BoardModel`, stateless timing/pricing/pair-selection rules in `engine/scripts/core/improvements.gd` and `board_logic.gd`, and render/input coordination in `engine/scripts/scenes/board.gd`. The board scene remains the transaction coordinator and calls `_after_board_change()` after mutations.

**Tech Stack:** Godot 4 GDScript, existing Grove `Save`/`Features`/`ActionBar`/`Overlay`/`HandHint` seams, `make test-fast`, `make test`, and `games/grove/tools/grove_sim.gd`.

## Global Constraints

- Feature flag id is `improvements`, default ON in `engine/scripts/core/features.gd`, documented in `docs/FEATURES.md`.
- Home board only; Rush gets no flag or behavior.
- `BoardModel.improvements` stores `cell -> {kind, rank, code, ends_at, watered}` and serializes rows inside `g["board"]`; no `_persist()` key or schema bump.
- Improved cells are ordinary ground for manual piece drops, spawns, and board occupancy; automatic generator placement skips improved cells.
- Soil max 9, Magnet max 3. Soil builds 1-3 free then `500, 1000, 2000, 4000, 8000, 16000` coins. Magnets cost `25, 50, 100` acorns. Move costs 100 coins. Soil ranks cost `600, 1500` coins. Water cost is 10.
- No randomness in Soil or Magnet. Magnet auto-merges must not roll coin/special drops or bump combo/RNG state.
- No improvement path calls `G.earn_coins` or `Save.earn_coins`; paid coin paths use `Save.spend(n, "improvement")`.

---

### Task 1: Core Rules And Wiring

**Files:**
- Create: `engine/scripts/core/improvements.gd`
- Modify: `engine/scripts/core/content.gd`
- Modify: `games/grove/grove_data.gd`
- Modify: `engine/scripts/core/features.gd`
- Modify: `docs/FEATURES.md`
- Test: `engine/tests/improvements_tests.gd`
- Modify: `Makefile`
- Modify: `CLAUDE.md`

**Interfaces:**
- Produces: `Improvements.KIND_SOIL`, `Improvements.KIND_MAGNET`, `soil_build_price(count)`, `magnet_build_price(count)`, `soil_rank_price(rank)`, `soil_step_seconds(code, rank)`, `is_soil_eligible(code)`, `apply_water(activity, now)`, `finish_cost(remaining_secs)`, `normalize_activity(raw)`.
- Produces: `G.SOIL_BUILD_PRICES`, `G.MAGNET_BUILD_PRICES`, `G.IMPROVEMENT_MOVE_COST`, `G.SOIL_RANK_PRICES`, `G.SOIL_WATER_COST`, and wrapper functions.

- [ ] **Step 1: Write failing tests**

```gdscript
const Improvements = preload("res://engine/scripts/core/improvements.gd")

func _test_soil_prices_and_curve() -> void:
	ok(Improvements.soil_build_price(0) == 0, "soil builds 1-3 are free")
	ok(Improvements.soil_build_price(3) == 500, "the fourth soil costs 500 coins")
	ok(Improvements.soil_step_seconds(101, 1) == 10.0, "tier-1 soil step is 10 seconds")
	ok(Improvements.soil_step_seconds(107, 2) == 10080.0, "rank-2 tier-7 step is 30 percent faster")
```

- [ ] **Step 2: Run red**

Run: `make test-one SUITE=engine/tests/improvements_tests`
Expected: FAIL because `engine/scripts/core/improvements.gd` is not present.

- [ ] **Step 3: Implement minimal core**

Add constants and wrappers exactly at the data/content seam, keep all methods stateless, and avoid `Save` or scene imports in `core/improvements.gd`.

- [ ] **Step 4: Run green**

Run: `make test-one SUITE=engine/tests/improvements_tests`
Expected: PASS for core rule cases.

### Task 2: BoardModel Persistence And Soil State

**Files:**
- Modify: `engine/scripts/core/board_model.gd`
- Modify: `engine/tests/improvements_tests.gd`

**Interfaces:**
- Produces: `BoardModel.improvements: Dictionary`.
- Produces: `BoardModel.can_build_improvement(cell)`, `build_improvement(cell, kind, rank)`, `move_improvement(from, to)`, `demolish_improvement(cell)`, `improvement_count(kind)`, `improvement_at(cell)`, `is_growing(cell)`, `apply_water_to_soil(cell, now)`, `finish_soil_now(cell, now)`, `reconcile_improvements(now)`.
- Produces: `BoardModel.empty_auto_gen_cells()` for automatic generator placement only.

- [ ] **Step 1: Write failing tests**

```gdscript
func _test_improvement_rows_round_trip() -> void:
	var b := BoardModel.new()
	var cell := Vector2i(3, 3)
	ok(b.build_improvement(cell, Improvements.KIND_SOIL), "soil builds on open empty ground")
	var row := b.improvement_at(cell)
	row["rank"] = 2
	row["code"] = 104
	row["ends_at"] = 1234.0
	row["watered"] = true
	b.improvements[cell] = row
	var b2 := BoardModel.new()
	b2.from_dict(b.to_dict())
	ok(b2.improvement_at(cell).rank == 2 and b2.improvement_at(cell).code == 104, "improvements round-trip in board dict")
```

- [ ] **Step 2: Run red**

Run: `make test-one SUITE=engine/tests/improvements_tests`
Expected: FAIL because `BoardModel` has no improvement state.

- [ ] **Step 3: Implement minimal model**

Parse tolerant rows from `to_dict()` and `from_dict()`. Reconcile Soil by comparing `board.items[cell]` against the row's activity code and store unix `ends_at` stamps, never remaining seconds.

- [ ] **Step 4: Run green**

Run: `make test-one SUITE=engine/tests/improvements_tests`
Expected: PASS for persistence, placement, clock, water, finish, and automatic-generator-skip cases.

### Task 3: Board Actions And Magnet Pairing

**Files:**
- Modify: `engine/scripts/core/board_logic.gd`
- Modify: `engine/scripts/core/board_actions.gd`
- Modify: `engine/scripts/core/quests.gd`
- Modify: `engine/tests/improvements_tests.gd`

**Interfaces:**
- Produces: `BoardLogic.range_pairs(board, cells) -> Array` returning `[cell_a, cell_b]` pairs sorted by tier then board index.
- Produces: `Quests.asked_codes(quests) -> Dictionary`.
- Produces: `BoardActions.build_improvement(board, cell, kind)`, `move_improvement(board, from, to)`, `rank_soil(board, cell)`, `demolish_improvement(board, cell)`, `water_soil(board, cell, now)`, `finish_soil(board, cell, now)`, `magnet_merge_once(board, magnet_cell, asked_codes, growing_cells, chain_cell)`.

- [ ] **Step 1: Write failing tests**

```gdscript
func _test_range_pairs_known_positive_negative() -> void:
	var b := BoardModel.new()
	var a := Vector2i(3, 3)
	var m := Vector2i(4, 4)
	var c := Vector2i(5, 5)
	b.place(a, 101)
	b.place(c, 101)
	ok(BoardLogic.range_pairs(b, Improvements.range_cells(b, m)) == [[a, c]], "a 3x3 range reports one mergeable pair")
	ok(BoardLogic.range_pairs(b, [a]).is_empty(), "one matching piece alone reports no pair")
```

- [ ] **Step 2: Run red**

Run: `make test-one SUITE=engine/tests/improvements_tests`
Expected: FAIL because the action and range APIs do not exist.

- [ ] **Step 3: Implement minimal actions**

Spend through `Save.spend` and `Save.spend_diamonds`, preserve Soil rank on moves, clear Soil clock on moves/demolish/consuming actions, and make Magnet merges model-committed without RNG side effects.

- [ ] **Step 4: Run green**

Run: `make test-one SUITE=engine/tests/improvements_tests`
Expected: PASS for build spend/caps/count math, move, demolish, rank, water, finish, range-pair, and magnet guard cases.

### Task 4: Board Scene Runtime And UI

**Files:**
- Modify: `engine/scripts/scenes/board.gd`
- Modify: `engine/scripts/ui/ui_kit.gd`
- Test: `games/grove/tests/grove_improvements_tests.gd`
- Modify: `Makefile`
- Modify: `CLAUDE.md`

**Interfaces:**
- Produces board-scene methods `_start_build_mode()`, `_exit_build_mode()`, `_open_improvement_sheet(cell)`, `_open_improvement_cell(cell)`, `_build_improvement(cell, kind)`, `_move_improvement_from(cell)`, `_finish_improvement_move(dst)`, `_demolish_improvement(cell)`, `_rank_soil(cell)`, `_water_soil(cell)`, `_finish_soil(cell)`, `_scan_magnets()`.
- Produces rendered metadata for tests: `build_btn`, `improvement_pad`, `improvement_kind`, `soil_progress`, `magnet_range`.

- [ ] **Step 1: Write failing Grove suite**

```gdscript
func _test_scene_builds_first_soil_free() -> void:
	fresh("improve_scene_build")
	var scn = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(scn)
	if scn.board == null:
		scn._ready()
	var cell := scn.board.empty_ground_cells()[0]
	var coins_b := Save.coins()
	ok(scn._build_improvement(cell, Improvements.KIND_SOIL), "scene builds a soil improvement")
	ok(Save.coins() == coins_b, "first soil is free")
	scn.queue_free()
```

- [ ] **Step 2: Run red**

Run: `make test-one SUITE=games/grove/tests/grove_improvements_tests`
Expected: FAIL because scene methods are not implemented.

- [ ] **Step 3: Implement minimal scene runtime**

Reconcile Soil in `_after_board_change()` and `_load_state`, resolve completions on the 1 Hz timer, scan magnets after board mutations, add build mode with pads/sheet/cell view, render art overlays/rings/time chips, and add t7+ warnings for reset paths.

- [ ] **Step 4: Run green**

Run: `make test-one SUITE=games/grove/tests/grove_improvements_tests`
Expected: PASS for scene build, pads, Soil info row, Magnet merge, warning, and FTUE one-shot cases.

### Task 5: Sim Hook And Full Verification

**Files:**
- Modify: `games/grove/tools/grove_sim.gd`
- Verify: `make test-fast`
- Verify: `make test`
- Verify: `godot --headless --path . -s res://games/grove/tools/grove_sim.gd -- 30 1`

**Interfaces:**
- Produces sim counters `improve_spend` and diamond spending for Magnets.

- [ ] **Step 1: Add sim purchases**

Fold paid Soil, rank, move coin spend into `improve_spend`, include it in `coin_sink`, and debit Magnet acorns in the diamond ledger.

- [ ] **Step 2: Run full verification**

Run: `make test-fast`, then `make test`, then `godot --headless --path . -s res://games/grove/tools/grove_sim.gd -- 30 1`.
Expected: all test suites pass and sim completes without invariant failure.
