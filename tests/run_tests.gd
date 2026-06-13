extends SceneTree
##
## Headless rules-engine tests. Run:
##   godot --headless -s res://tests/run_tests.gd
##
## Validates Board against the exhaustively-verified §2.11 cases (Python oracle):
##   - START is solvable; the greedy successor is STRANDED  -> non-confluence
##   - the documented 6-drag order actually clears (and every step is a legal move)

const Board = preload("res://scripts/board.gd")
const Levels = preload("res://scripts/levels.gd")

var _pass := 0
var _fail := 0

func _initialize() -> void:
	print("== Reach Zero rules tests ==")

	# L3 / §2.11 verified board (fam1, top tier 3).
	var start := [
		101, 103, 103,
		0,    -1, 101,
		101, 101, 103,
	]

	# The documented correct 6-drag solve clears the board AND every step is a legal
	# move per the engine. A constructive clear is itself proof that START is solvable
	# (fast — no full BFS needed).
	var s := Board.new(3, 3, start, 3)
	var ok := true
	ok = ok and _do_merge(s, 0, 1, 0, 2)   # 1 showcase T3+T3
	ok = ok and _do_merge(s, 2, 0, 2, 1)   # 2 merge  T1+T1 -> T2
	ok = ok and _do_slide(s, 1, 2, 0, 2)   # 3 reposition T1 (the routing slide)
	ok = ok and _do_merge(s, 0, 2, 0, 0)   # 4 merge  T1+T1 -> T2
	ok = ok and _do_merge(s, 0, 0, 2, 1)   # 5 merge  T2+T2 -> T3
	ok = ok and _do_merge(s, 2, 1, 2, 2)   # 6 showcase T3+T3
	_check("all 6 documented drags were legal", ok)
	_check("6-drag order reaches ZERO (so START is solvable)", s.is_cleared())

	# Greedy first move (§2.11 Order B): slide T1(2,0) up onto T1(0,0) -> T2(0,0),
	# which produces the documented STRANDED grid (exhaustively unsolvable). This is
	# the non-confluence proof: a solvable board has a legal move to an unsolvable one.
	var greedy := Board.new(3, 3, start, 3)
	_check("greedy target is a legal merge", Vector2i(0, 0) in greedy.merge_targets(2, 0))
	greedy.apply_merge(2, 0, 0, 0)
	var strand_expected := [
		102, 103, 103,
		0,    -1, 101,
		0,   101, 103,
	]
	_check("greedy produces the documented strand grid", greedy.grid == strand_expected)
	_check("strand state is UNSOLVABLE (proves non-confluence)", not greedy.is_solvable())
	_check("strand reachable-state count == 448 (matches Python oracle)", greedy.reachable_state_count() == 448)

	# (The old per-level sliding-solvability checks are gone: the core is now drag-any-to-any,
	#  where any board with even counts per family always clears — no solver needed. These tests
	#  still validate board.gd's dormant sliding engine in isolation via the §2.11 cases above.)

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)

func _do_merge(b: Board, r: int, c: int, br: int, bc: int) -> bool:
	if not (Vector2i(br, bc) in b.merge_targets(r, c)):
		return false
	b.apply_merge(r, c, br, bc)
	return true

func _do_slide(b: Board, r: int, c: int, sr: int, sc: int) -> bool:
	if not (Vector2i(sr, sc) in b.reachable_empties(r, c)):
		return false
	b.apply_reposition(r, c, sr, sc)
	return true

func _check(label: String, cond: bool) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)
