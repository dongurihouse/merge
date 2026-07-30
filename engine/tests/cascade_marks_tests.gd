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
