extends "res://engine/tests/test_base.gd"
## Headless tests for cascade-combo pathfinding: ordered chain runs, ready
## ladder outlines, and drag-placement guide candidates.

const G = preload("res://engine/scripts/core/content.gd")
const BoardModel = preload("res://engine/scripts/core/board_model.gd")
const BoardLogic = preload("res://engine/scripts/core/board_logic.gd")

func _initialize() -> void:
	_test_chain_path()
	_test_ready_ladders()
	_test_chain_placements()
	finish()

func _blank_board() -> BoardModel:
	var b := BoardModel.new()
	for i in b.items.size():
		b.terrain[i] = 0
		b.items[i] = 0
	b.gens = {}
	b.gen_tiers = {}
	b.gen_boost = {}
	b.collect_rewards = {}
	return b

func _put(b: BoardModel, cell: Vector2i, code: int) -> void:
	b.place(cell, code)

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

func _has_candidate(entries: Array, cell: Vector2i, n: int) -> bool:
	for e in entries:
		if e is Dictionary and Vector2i((e as Dictionary).get("cell", Vector2i(-9, -9))) == cell and int((e as Dictionary).get("n", 0)) == n:
			return true
	return false

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

func _test_ready_ladders() -> void:
	var b := _blank_board()
	_put(b, Vector2i(3, 1), 101)
	_put(b, Vector2i(3, 2), 101)
	_put(b, Vector2i(3, 3), 102)
	var ladders := BoardLogic.ready_ladders(b)
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
