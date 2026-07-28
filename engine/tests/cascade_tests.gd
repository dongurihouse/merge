extends "res://engine/tests/test_base.gd"
## Headless tests for cascade-combo pathfinding: ordered chain runs, ready
## ladder outlines, and drag-placement guide candidates.

const G = preload("res://engine/scripts/core/content.gd")
const BoardModel = preload("res://engine/scripts/core/board_model.gd")
const BoardLogic = preload("res://engine/scripts/core/board_logic.gd")
const Improvements = preload("res://engine/scripts/core/improvements.gd")

func _initialize() -> void:
	_test_chain_path()
	_test_chain_reward_codes()
	_test_growing_soil_is_excluded_from_chain_search()
	_test_ready_ladders()
	_test_runways()
	_test_chain_placements()
	_test_chain_placements_equivalence()
	_test_chain_placements_no_mutation()
	_test_chain_placements_perf()
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

func _put(b: BoardModel, cell: Vector2i, code: int) -> void:
	b.place(cell, code)

func _put_growing(b: BoardModel, cell: Vector2i, code: int) -> void:
	b.build_improvement(cell, Improvements.KIND_SOIL)
	b.place(cell, code)
	var row: Dictionary = b.improvement_at(cell)
	row["code"] = code
	row["ends_at"] = Time.get_unix_time_from_system() + 3600.0
	b.improvements[cell] = row

func _cells_equal(got: Array, want: Array) -> bool:
	if got.size() != want.size():
		return false
	for i in got.size():
		if Vector2i(got[i]) != Vector2i(want[i]):
			return false
	return true

func _entry_for_cell(entries: Array, cell: Vector2i) -> Dictionary:
	for e in entries:
		if e is Dictionary and Vector2i((e as Dictionary).get("top_cell", Vector2i(-9, -9))) == cell:
			return e
	return {}

func _runway_for_need(entries: Array, code: int) -> Dictionary:
	for e in entries:
		if e is Dictionary and int((e as Dictionary).get("needs_code", 0)) == code:
			return e
	return {}

func _has_candidate(entries: Array, cell: Vector2i, n: int) -> bool:
	for e in entries:
		if e is Dictionary and Vector2i((e as Dictionary).get("cell", Vector2i(-9, -9))) == cell and int((e as Dictionary).get("n", 0)) == n:
			return true
	return false

func _candidate_cells(entries: Array) -> Array:
	var out := []
	for e in entries:
		if e is Dictionary:
			out.append(Vector2i((e as Dictionary).get("cell", Vector2i(-9, -9))))
	return out

func _test_chain_path() -> void:
	var b := _blank_board()
	_put(b, Vector2i(3, 1), 101)
	_put(b, Vector2i(3, 2), 101)
	ok(_cells_equal(BoardLogic.chain_path(b, Vector2i(3, 1), Vector2i(3, 2)), []), \
		"chain_path: no adjacent upgraded partner returns empty")

	b = _blank_board()
	_put(b, Vector2i(3, 1), 101)
	_put(b, Vector2i(3, 2), 101)
	_put(b, Vector2i(3, 3), 102)
	_put(b, Vector2i(3, 4), 103)
	ok(_cells_equal(BoardLogic.chain_path(b, Vector2i(3, 1), Vector2i(3, 2)), [Vector2i(3, 3), Vector2i(3, 4)]), \
		"chain_path: straight ladder returns the full ordered partner path")

	b = _blank_board()
	_put(b, Vector2i(2, 2), 101)
	_put(b, Vector2i(2, 3), 101)
	_put(b, Vector2i(2, 4), 102)
	ok(_cells_equal(BoardLogic.chain_path(b, Vector2i(2, 2), Vector2i(2, 3)), [Vector2i(2, 4)]), \
		"chain_path: direction A onto B can run")
	ok(_cells_equal(BoardLogic.chain_path(b, Vector2i(2, 3), Vector2i(2, 2)), []), \
		"chain_path: direction B onto A does not borrow non-adjacent partners")

	b = _blank_board()
	_put(b, Vector2i(3, 2), 101)
	_put(b, Vector2i(3, 3), 101)
	_put(b, Vector2i(2, 3), 102)
	_put(b, Vector2i(3, 4), 102)
	_put(b, Vector2i(3, 5), 103)
	ok(_cells_equal(BoardLogic.chain_path(b, Vector2i(3, 2), Vector2i(3, 3)), [Vector2i(3, 4), Vector2i(3, 5)]), \
		"chain_path: longest branch beats the row-major short branch")

	b = _blank_board()
	_put(b, Vector2i(3, 2), 101)
	_put(b, Vector2i(3, 3), 101)
	_put(b, Vector2i(2, 3), 102)
	_put(b, Vector2i(3, 2), 101)
	_put(b, Vector2i(4, 3), 102)
	ok(_cells_equal(BoardLogic.chain_path(b, Vector2i(3, 2), Vector2i(3, 3)), [Vector2i(2, 3)]), \
		"chain_path: equal-length ties break row-major")

	b = _blank_board()
	_put(b, Vector2i(1, 1), 1004)
	_put(b, Vector2i(1, 2), 1004)
	_put(b, Vector2i(1, 3), 1005)
	ok(_cells_equal(BoardLogic.chain_path(b, Vector2i(1, 1), Vector2i(1, 2)), []), \
		"chain_path: merge_top stops at chest tier 5")

	b = _blank_board()
	_put(b, Vector2i(4, 1), 101)
	_put(b, Vector2i(4, 2), 201)
	_put(b, Vector2i(4, 3), 102)
	ok(_cells_equal(BoardLogic.chain_path(b, Vector2i(4, 1), Vector2i(4, 2)), []), \
		"chain_path: recipes and other-code pairs never auto-chain")

func _test_chain_reward_codes() -> void:
	ok(BoardLogic.chain_reward_code(1) == 0, "chain_reward_code: x1 has no reward")
	ok(BoardLogic.chain_reward_code(2) == 0, "chain_reward_code: x2 has no cascade reward")
	ok(BoardLogic.chain_reward_code(3) == G.CHEST_LINE * 100 + 1, "chain_reward_code: x3 starts the cascade chest")
	ok(BoardLogic.chain_reward_code(6) == G.CHEST_LINE * 100 + 4, "chain_reward_code: x6 reaches chest tier 4")
	ok(BoardLogic.chain_reward_code(9) == G.CHEST_LINE * 100 + 5, "chain_reward_code: x7+ caps at the top chest")

func _test_growing_soil_is_excluded_from_chain_search() -> void:
	var b := _blank_board()
	_put(b, Vector2i(2, 1), 106)
	_put(b, Vector2i(2, 2), 106)
	_put_growing(b, Vector2i(2, 3), 107)
	ok(_cells_equal(BoardLogic.chain_path(b, Vector2i(2, 1), Vector2i(2, 2)), []),
		"chain_path: a t7+ growing partner is not an automatic cascade rung")

	b = _blank_board()
	var from := Vector2i(6, 6)
	_put(b, from, 106)
	_put(b, Vector2i(2, 1), 106)
	_put_growing(b, Vector2i(2, 3), 107)
	ok(not _has_candidate(BoardLogic.chain_placements(b, from, 106), Vector2i(2, 2), 2),
		"chain_placements: fast drag guides do not route through a t7+ growing partner")

func _test_ready_ladders() -> void:
	var b := _blank_board()
	_put(b, Vector2i(3, 1), 101)
	_put(b, Vector2i(3, 2), 101)
	_put(b, Vector2i(3, 3), 102)
	var ladders: Array = BoardLogic.ready_ladders(b)
	var e := _entry_for_cell(ladders, Vector2i(3, 3))
	ok(ladders.size() == 1 and int(e.get("n", 0)) == 2 and int(e.get("line", 0)) == 1, \
		"ready_ladders: minimal t-t-t+1 component reports n 2")

	_put(b, Vector2i(3, 4), 103)
	ladders = BoardLogic.ready_ladders(b)
	e = _entry_for_cell(ladders, Vector2i(3, 4))
	ok(ladders.size() == 1 and int(e.get("n", 0)) == 3, \
		"ready_ladders: adding t+2 extends the tag to n 3")

	b = _blank_board()
	_put(b, Vector2i(1, 1), 101)
	_put(b, Vector2i(1, 2), 101)
	_put(b, Vector2i(1, 4), 102)
	ok(BoardLogic.ready_ladders(b).is_empty(), \
		"ready_ladders: a gap prevents a ready component")

	b = _blank_board()
	_put(b, Vector2i(2, 1), 101)
	_put(b, Vector2i(2, 2), 101)
	_put(b, Vector2i(2, 3), 102)
	_put(b, Vector2i(2, 4), 102)
	ladders = BoardLogic.ready_ladders(b)
	e = _entry_for_cell(ladders, Vector2i(2, 3))
	ok(ladders.size() == 1 and int(e.get("n", 0)) == 2, \
		"ready_ladders: a duplicate rung does not count as another chain step")

	b = _blank_board()
	_put(b, Vector2i(3, 1), 101)
	_put(b, Vector2i(3, 2), 101)
	_put(b, Vector2i(3, 3), 102)
	_put(b, Vector2i(6, 6), 101)
	ladders = BoardLogic.ready_ladders(b)
	ok(ladders.size() == 1, "ready_ladders: a stray singleton does not disqualify the ready ladder")

	b = _blank_board()
	_put(b, Vector2i(4, 3), 101)
	_put(b, Vector2i(4, 4), 101)
	_put(b, Vector2i(4, 5), 102)
	ladders = BoardLogic.ready_ladders(b)
	e = _entry_for_cell(ladders, Vector2i(4, 5))
	ok(ladders.size() == 1 and int(e.get("n", 0)) == 2, \
		"ready_ladders: best n is direction-aware")

	b = _blank_board()
	_put(b, Vector2i(1, 1), 101)
	_put(b, Vector2i(1, 2), 101)
	_put(b, Vector2i(1, 3), 102)
	_put(b, Vector2i(5, 1), 201)
	_put(b, Vector2i(5, 2), 201)
	_put(b, Vector2i(5, 3), 202)
	ok(BoardLogic.ready_ladders(b).size() == 2, "ready_ladders: two ready components produce two entries")

func _test_runways() -> void:
	var b := _blank_board()
	_put(b, Vector2i(3, 1), 102)
	_put(b, Vector2i(3, 2), 103)
	_put(b, Vector2i(3, 3), 104)
	var runways: Array = BoardLogic.runways(b, 3)
	var e := _runway_for_need(runways, 102)
	ok(runways.size() == 1 and int(e.get("line", 0)) == 1 and int(e.get("would_be_n", 0)) == 3,
		"runways: a t2-t3-t4 staircase is one t2 away from a x3 cascade")
	ok(_cells_equal(Array(e.get("ignite_cells", [])), [Vector2i(2, 1), Vector2i(3, 0), Vector2i(4, 1)]),
		"runways: ignite_cells are the t2 placements that would fire the runway")

	b = _blank_board()
	_put(b, Vector2i(3, 1), 102)
	_put(b, Vector2i(3, 2), 103)
	_put(b, Vector2i(3, 3), 104)
	ok(BoardLogic.runways(b, 4).is_empty(),
		"runways: min_n is a caller-owned floor")
	_put(b, Vector2i(3, 4), 105)
	runways = BoardLogic.runways(b, 4)
	e = _runway_for_need(runways, 102)
	ok(runways.size() == 1 and int(e.get("would_be_n", 0)) == 4,
		"runways: a longer staircase can satisfy a higher min_n with the same duplicate")

	b = _blank_board()
	_put(b, Vector2i(3, 1), 102)
	_put(b, Vector2i(3, 2), 102)
	_put(b, Vector2i(3, 3), 103)
	_put(b, Vector2i(3, 4), 104)
	ok(BoardLogic.runways(b, 3).is_empty(),
		"runways: an equal pair is an armed ladder, not an inert runway")

func _test_chain_placements() -> void:
	var b := _blank_board()
	var from := Vector2i(6, 6)
	_put(b, from, 101)
	_put(b, Vector2i(2, 1), 101)
	_put(b, Vector2i(2, 3), 102)
	ok(_has_candidate(BoardLogic.chain_placements(b, from, 101), Vector2i(2, 2), 2), \
		"chain_placements: placing the held tile completes a ladder")

	b = _blank_board()
	from = Vector2i(6, 6)
	_put(b, from, 103)
	_put(b, Vector2i(3, 1), 101)
	_put(b, Vector2i(3, 2), 101)
	_put(b, Vector2i(3, 3), 102)
	ok(_has_candidate(BoardLogic.chain_placements(b, from, 103), Vector2i(3, 4), 3), \
		"chain_placements: placing the held tile can lengthen a ready ladder")

	b = _blank_board()
	from = Vector2i(6, 6)
	_put(b, from, 101)
	_put(b, Vector2i(3, 1), 101)
	_put(b, Vector2i(3, 2), 101)
	_put(b, Vector2i(3, 3), 102)
	ok(not _has_candidate(BoardLogic.chain_placements(b, from, 101), Vector2i(2, 2), 2), \
		"chain_placements: a spare beside an equally ready ladder is not a candidate")

	b = _blank_board()
	from = Vector2i(6, 6)
	_put(b, from, 101)
	_put(b, Vector2i(1, 1), 101)
	_put(b, Vector2i(1, 3), 102)
	_put(b, Vector2i(1, 4), 103)
	ok(_has_candidate(BoardLogic.chain_placements(b, from, 101), Vector2i(1, 2), 3), \
		"chain_placements: a placement can bridge two clusters into a longer chain")

	b = _blank_board()
	from = Vector2i(2, 2)
	_put(b, Vector2i(2, 1), 101)
	_put(b, Vector2i(2, 3), 102)
	ok(not _has_candidate(BoardLogic.chain_placements(b, from, 101), from, 2), \
		"chain_placements: the source cell is excluded even if it is empty in tests")

	b = _blank_board()
	from = Vector2i(6, 6)
	_put(b, from, 101)
	_put(b, Vector2i(1, 1), 201)
	ok(BoardLogic.chain_placements(b, from, 101).is_empty(), \
		"chain_placements: no adjacent kin returns no guide pads")

# --- chain_placements: the optimised search must match the original, cell for cell ------------
#
# chain_placements runs inside the drag gesture, so it is written flat (one int snapshot, memoised
# per-component cascade lengths). _ref_chain_placements below is the ORIGINAL copy-per-candidate
# algorithm, pasted whole; these tests are the gate that the fast path never drifts from it.

func _test_chain_placements_equivalence() -> void:
	_same_placements(_dense_board(), Vector2i(0, 0), 101, "dense worst case (1 line, 6 tiers, ~87% full)")
	_same_placements(_one_line_board(11, 5, 6), Vector2i(0, 0), 101, "1 line, ~90% full")
	_same_placements(_mixed_board(), Vector2i(0, 0), 101, "mixed 4 lines, ~60% full")
	_same_placements(_blank_board(), Vector2i(3, 3), 101, "empty board")
	# Boards packed enough to be interesting but loose enough that pads actually light — a board
	# whose answer is [] proves far less than one with a dozen candidates.
	_same_placements(_one_line_board(3, 1, 3), Vector2i(0, 0), 101, "1 line, 3 tiers, ~67% full")
	_same_placements(_one_line_board(4, 1, 2), Vector2i(0, 0), 101, "1 line, 2 tiers, ~75% full")
	_same_placements(_one_line_board(3, 1, 4), Vector2i(5, 5), 104, "1 line, 4 tiers, dragging a t4")

	var kinless := _blank_board()
	_put(kinless, Vector2i(6, 6), 101)
	_put(kinless, Vector2i(1, 1), 201)
	_put(kinless, Vector2i(1, 2), 201)
	_put(kinless, Vector2i(1, 3), 202)
	_same_placements(kinless, Vector2i(6, 6), 101, "dragged code has no same-line kin")

	# The dragged code is NOT the code sitting on `from` — the source cell stays occupied.
	var held := _dense_board()
	_same_placements(held, Vector2i(0, 0), 103, "source cell holds a different code")

	# Collect rewards block merges; brambles and generators block placement. A reward parked on an
	# EMPTY cell is the interesting one: place() clears it under the dropped piece.
	var blocked := _one_line_board(3, 1, 3)
	blocked.set_collect_reward(Vector2i(2, 2), "coins", 5)
	blocked.set_collect_reward(Vector2i(4, 3), "coins", 5)
	blocked.collect_rewards[BoardModel.idx(Vector2i(0, 5))] = {"kind": "coins", "amount": 5}   # empty cell
	blocked.terrain[BoardModel.idx(Vector2i(3, 5))] = 1
	blocked.gens[Vector2i(5, 5)] = "acorn_tree"
	_same_placements(blocked, Vector2i(0, 0), 101, "rewards, a bramble and a generator in the way")

	# Merge ceilings: chests top out at 5, coins at 3 — the cascade must stop there.
	var capped := _blank_board()
	for i in capped.items.size():
		capped.items[i] = 1000 + (1 + (i % 5))
	capped.items[BoardModel.idx(Vector2i(4, 4))] = 0
	_same_placements(capped, Vector2i(0, 0), 1001, "chest line at its merge ceiling")

	# 120 boards keeps the suite quick. The knobs are there because this was soaked much
	# harder before the optimisation landed — 12 seeds × 300 boards at fill 0.2–0.9, 3600
	# boards, 0 mismatches; re-run that spread after any change to the search.
	var fuzz := _fuzz_report(120)
	ok(int(fuzz.get("mismatches", -1)) == 0 and int(fuzz.get("with_candidates", 0)) >= 20, \
		"chain_placements equivalence: %d random boards, %d with candidates, %d cells guided, %d mismatches" \
		% [int(fuzz.get("boards", 0)), int(fuzz.get("with_candidates", 0)), int(fuzz.get("cells", 0)), int(fuzz.get("mismatches", -1))])

func _test_chain_placements_no_mutation() -> void:
	var loose := _one_line_board(3, 1, 3)
	loose.set_collect_reward(Vector2i(2, 2), "coins", 5)
	loose.terrain[BoardModel.idx(Vector2i(3, 5))] = 1
	loose.items[BoardModel.idx(Vector2i(3, 5))] = 0
	loose.gens[Vector2i(5, 5)] = "acorn_tree"
	loose.items[BoardModel.idx(Vector2i(5, 5))] = 0
	_untouched(loose, Vector2i(0, 0), 101, "rewards, a bramble and a generator, pads lit", true)
	_untouched(_dense_board(), Vector2i(0, 0), 101, "the dense worst case", false)

func _untouched(b: BoardModel, from: Vector2i, code: int, label: String, want_pads: bool) -> void:
	var items_before := b.items.duplicate()
	var terrain_before := b.terrain.duplicate()
	var rewards_before := str(b.collect_rewards)
	var gens_before := str(b.gens)
	var got: Array = BoardLogic.chain_placements(b, from, code)
	var clean := _packed_equal(b.items, items_before) and _packed_equal(b.terrain, terrain_before) \
		and str(b.collect_rewards) == rewards_before and str(b.gens) == gens_before
	ok(clean and (got.size() > 0 or not want_pads), \
		"chain_placements leaves the caller's board untouched: %s (%d guide pads)" % [label, got.size()])

func _test_chain_placements_perf() -> void:
	var dense := _dense_board()
	var wide := _one_line_board(11, 5, 6)
	var mixed := _mixed_board()
	var d_new := _time_ms(dense, false)
	var d_ref := _time_ms(dense, true)
	var w_new := _time_ms(wide, false)
	var w_ref := _time_ms(wide, true)
	var m_new := _time_ms(mixed, false)
	var m_ref := _time_ms(mixed, true)
	ok(d_new < 8.0, \
		"chain_placements perf: dense %.2f ms < 8.0 bound (was %.2f) · 1-line/90%% %.2f ms (was %.2f) · mixed %.2f ms (was %.2f), best of 3" \
		% [d_new, d_ref, w_new, w_ref, m_new, m_ref])
	_test_drag_gesture_perf(dense)

# The DRAG GESTURE total, not chain_placements alone. board.gd _begin_drag pays for the whole
# telegraph, and pinning one of its three walks is how the cost crept back once already: the runway
# pass added ready_ladders + runways inside the gesture and ready_ladders outweighed the
# chain_placements the earlier perf pass had flattened, taking one lift from 1.18 ms to 2.87 ms.
# These statics are what that gesture is built from, so
# bound their sum here where the engine suite can see it. A memo keyed on board state was tried
# and rejected: measured at the drag call site it hit 2 lifts in 10, so it bought almost nothing
# for a fingerprint on every gesture. The gesture pays all three walks today — this bound is what
# says so out loud.
func _test_drag_gesture_perf(dense: BoardModel) -> void:
	var from := BoardModel.cell_of(0)
	var code := dense.item_at(from)
	var best := 1.0e9
	for _round in 3:
		var t0 := Time.get_ticks_usec()
		BoardLogic.chain_placements(dense, from, code)
		BoardLogic.ready_ladders(dense)
		BoardLogic.runways(dense, 3)
		best = minf(best, float(Time.get_ticks_usec() - t0) / 1000.0)
	ok(best < 12.0, \
		"drag-gesture walks (chain_placements + ready_ladders + runways): %.2f ms < 12.0 bound, best of 3" % best)

# Best of 3 — the suites run 4-up, so a single sample can catch a scheduling gap.
func _time_ms(b: BoardModel, use_reference: bool) -> float:
	var from := Vector2i(0, 0)
	var code := b.item_at(from)
	var best := 1e9
	for _run in 3:
		var t0 := Time.get_ticks_usec()
		if use_reference:
			_ref_chain_placements(b, from, code)
		else:
			BoardLogic.chain_placements(b, from, code)
		best = minf(best, (Time.get_ticks_usec() - t0) / 1000.0)
	return best

func _same_placements(b: BoardModel, from: Vector2i, code: int, label: String) -> void:
	var want: Array = _ref_chain_placements(b, from, code)
	var got: Array = BoardLogic.chain_placements(b, from, code)
	ok(_placements_equal(got, want), "chain_placements equivalence: %s → %d guide pads" % [label, want.size()])

func _placements_equal(got: Array, want: Array) -> bool:
	if got.size() != want.size():
		return false
	for i in got.size():
		var a: Dictionary = got[i]
		var b: Dictionary = want[i]
		if Vector2i(a.get("cell", Vector2i(-9, -9))) != Vector2i(b.get("cell", Vector2i(-8, -8))):
			return false
		if int(a.get("n", -1)) != int(b.get("n", -2)):
			return false
	return true

func _packed_equal(a: PackedInt32Array, b: PackedInt32Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if a[i] != b[i]:
			return false
	return true

# --- the boards ------------------------------------------------------------------------------

# One line, every cell except `i % skip_mod == skip_rem`, tiers cycling 1..tiers. The dense worst
# case is _one_line_board(8, 3, 6) — the recipe the perf brief pins.
func _one_line_board(skip_mod: int, skip_rem: int, tiers: int) -> BoardModel:
	var b := _blank_board()
	var r := 0
	for i in b.items.size():
		if i % skip_mod == skip_rem:
			continue
		b.place(BoardModel.cell_of(i), 100 + (1 + (r % tiers)))
		r += 1
	return b

func _dense_board() -> BoardModel:
	return _one_line_board(8, 3, 6)

func _mixed_board() -> BoardModel:
	var b := _blank_board()
	var r := 0
	for i in b.items.size():
		if i % 5 == 2 or i % 5 == 4:
			continue
		b.place(BoardModel.cell_of(i), (1 + (r % 4)) * 100 + (1 + (r % 6)))
		r += 1
	return b

# Random boards with brambles, generators, rewards and mixed lines — the equivalence net that
# catches what five hand-built boards cannot.
func _fuzz_report(boards: int, sd: int = 20260726, lo: float = 0.25, hi: float = 0.6) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = sd
	var mismatches := 0
	var with_candidates := 0
	var cells := 0
	for _t in boards:
		# Single-line boards at a loose fill are where guide pads actually light; the multi-line
		# mixes bring coins (merge top 3) and chests (top 5) in to exercise the ceilings.
		var lines: Array = [1] if rng.randf() < 0.6 else [1, 2, 9, 10]
		var top_tier: int = 3 if rng.randf() < 0.7 else 6
		var fill: float = rng.randf_range(lo, hi)
		var b := _blank_board()
		for i in b.items.size():
			if rng.randf() < 0.05:
				b.terrain[i] = 1
				continue
			if rng.randf() >= fill:
				if rng.randf() < 0.03:
					b.collect_rewards[i] = {"kind": "coins", "amount": 5}   # stale reward, empty cell
				continue
			b.items[i] = int(lines[rng.randi_range(0, lines.size() - 1)]) * 100 + rng.randi_range(1, top_tier)
			if rng.randf() < 0.06:
				b.collect_rewards[i] = {"kind": "coins", "amount": 5}
		if rng.randf() < 0.5:
			b.gens[BoardModel.cell_of(rng.randi_range(0, b.items.size() - 1))] = "acorn_tree"
		var code := int(lines[rng.randi_range(0, lines.size() - 1)]) * 100 + rng.randi_range(1, top_tier)
		var from := BoardModel.cell_of(rng.randi_range(0, b.items.size() - 1))
		if rng.randf() < 0.4:
			b.items[BoardModel.idx(from)] = code          # a real drag: the source holds the code
		var want: Array = _ref_chain_placements(b, from, code)
		var got: Array = BoardLogic.chain_placements(b, from, code)
		if not _placements_equal(got, want):
			mismatches += 1
		if not want.is_empty():
			with_candidates += 1
		cells += want.size()
	return {"boards": boards, "mismatches": mismatches, "with_candidates": with_candidates, "cells": cells}

# --- the ORIGINAL algorithm, pasted -----------------------------------------------------------
#
# BoardLogic.chain_placements as it stood before the drag-gesture optimisation: a fresh BoardModel
# copy per candidate cell, a fresh component walk per neighbour, full path bookkeeping. Slow on
# purpose — it is the reference the fast path is measured against, so do NOT tidy it up or point
# it back at BoardLogic's private helpers.

const _REF_DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

static func _ref_chain_placements(board: BoardModel, from: Vector2i, code: int) -> Array:
	var out: Array = []
	if board == null or code <= 0:
		return out
	var base := _ref_copy_board(board)
	if base.in_bounds(from) and base.item_at(from) == code:
		base.take(from)
	var line := BoardModel.line_of(code)
	for i in base.items.size():
		var cell := BoardModel.cell_of(i)
		if cell == from or not base.is_empty_ground(cell):
			continue
		if not _ref_has_adjacent_line(base, cell, line):
			continue
		var before_n := _ref_best_adjacent_component_n(base, cell, line)
		var placed := _ref_copy_board(base)
		placed.place(cell, code)
		var after := _ref_best_tip_in_component(placed, _ref_component_from(placed, cell, line))
		var n := int(after.get("n", 0))
		if n >= 2 and n > before_n:
			out.append({"cell": cell, "n": n})
	out.sort_custom(func(a, b): return BoardModel.idx(Vector2i((a as Dictionary).get("cell", Vector2i.ZERO))) < BoardModel.idx(Vector2i((b as Dictionary).get("cell", Vector2i.ZERO))))
	return out

static func _ref_copy_board(board: BoardModel) -> BoardModel:
	var cp := BoardModel.new()
	cp.terrain = board.terrain.duplicate()
	cp.items = board.items.duplicate()
	cp.collect_rewards = board.collect_rewards.duplicate(true)
	cp.gens = board.gens.duplicate(true)
	cp.gen_bag = board.gen_bag.duplicate(true)
	cp.gen_boost = board.gen_boost.duplicate(true)
	cp.gen_bag_boost = board.gen_bag_boost.duplicate(true)
	return cp

static func _ref_has_adjacent_line(board: BoardModel, cell: Vector2i, line: int) -> bool:
	for raw_d in _REF_DIRS:
		var d := Vector2i(raw_d)
		var n := cell + d
		if board.in_bounds(n) and board.item_at(n) > 0 and BoardModel.line_of(board.item_at(n)) == line:
			return true
	return false

static func _ref_best_adjacent_component_n(board: BoardModel, cell: Vector2i, line: int) -> int:
	var seen_components := {}
	var best := 0
	for raw_d in _REF_DIRS:
		var d := Vector2i(raw_d)
		var n := cell + d
		if not board.in_bounds(n) or board.item_at(n) <= 0 or BoardModel.line_of(board.item_at(n)) != line:
			continue
		var comp := _ref_component_from(board, n, line)
		if comp.is_empty():
			continue
		var key := Vector2i(comp[0])
		if seen_components.has(key):
			continue
		seen_components[key] = true
		best = maxi(best, int(_ref_best_tip_in_component(board, comp).get("n", 0)))
	return best

static func _ref_component_from(board: BoardModel, start: Vector2i, line: int) -> Array:
	var seen := {}
	var stack: Array = [start]
	while not stack.is_empty():
		var cell := Vector2i(stack.pop_back())
		if seen.has(cell) or not board.in_bounds(cell):
			continue
		var code := board.item_at(cell)
		if code <= 0 or BoardModel.line_of(code) != line:
			continue
		seen[cell] = true
		for raw_d in _REF_DIRS:
			var d := Vector2i(raw_d)
			stack.append(cell + d)
	return _ref_sorted_cells(seen.keys())

static func _ref_sorted_cells(cells: Array) -> Array:
	var out := cells.duplicate()
	out.sort_custom(func(a, b): return BoardModel.idx(Vector2i(a)) < BoardModel.idx(Vector2i(b)))
	return out

static func _ref_best_tip_in_component(board: BoardModel, cells: Array) -> Dictionary:
	var cell_set := {}
	for c in cells:
		cell_set[Vector2i(c)] = true
	var best := {"n": 0, "top_cell": Vector2i(-1, -1), "from": Vector2i(-1, -1), "to": Vector2i(-1, -1), "path": []}
	for a in cells:
		var from := Vector2i(a)
		for raw_d in _REF_DIRS:
			var d := Vector2i(raw_d)
			var to := from + d
			if not cell_set.has(to) or not board.can_merge(from, to):
				continue
			# The LIVE chain_path on purpose, not a frozen copy: this reference is the gate the fast
			# search is fuzzed against, so it has to track the real chain rules. With a frozen copy
			# both sides could agree while drifting from what a cascade actually runs, and the pads
			# would advertise an n the board never delivers.
			var path: Array = BoardLogic.chain_path(board, from, to)
			var n: int = 1 + path.size()
			if n < 2:
				continue
			var top_cell := Vector2i(path[path.size() - 1])
			var candidate := {"n": n, "top_cell": top_cell, "from": from, "to": to, "path": path}
			if _ref_tip_better(candidate, best):
				best = candidate
	return best

static func _ref_tip_better(candidate: Dictionary, best: Dictionary) -> bool:
	var cn := int(candidate.get("n", 0))
	var bn := int(best.get("n", 0))
	if cn != bn:
		return cn > bn
	var ct := BoardModel.idx(Vector2i(candidate.get("top_cell", Vector2i.ZERO)))
	var bt := BoardModel.idx(Vector2i(best.get("top_cell", Vector2i(G.ROWS, G.COLS))))
	if ct != bt:
		return ct < bt
	if _ref_path_better(Array(candidate.get("path", [])), Array(best.get("path", []))):
		return true
	var cf := BoardModel.idx(Vector2i(candidate.get("from", Vector2i.ZERO)))
	var bf := BoardModel.idx(Vector2i(best.get("from", Vector2i(G.ROWS, G.COLS))))
	if cf != bf:
		return cf < bf
	return BoardModel.idx(Vector2i(candidate.get("to", Vector2i.ZERO))) < BoardModel.idx(Vector2i(best.get("to", Vector2i(G.ROWS, G.COLS))))

static func _ref_path_better(candidate: Array, best: Array) -> bool:
	if candidate.size() != best.size():
		return candidate.size() > best.size()
	for i in candidate.size():
		var ci := BoardModel.idx(Vector2i(candidate[i]))
		var bi := BoardModel.idx(Vector2i(best[i]))
		if ci != bi:
			return ci < bi
	return false
