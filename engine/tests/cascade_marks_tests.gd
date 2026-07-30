extends "res://engine/tests/test_base.gd"
## The cascade guide's display rules, with no scene and no renderer: what marks a board
## produces at rest, while a piece is held, and while a chain runs.

const BoardModel = preload("res://engine/scripts/core/board_model.gd")
const CascadeMarks = preload("res://engine/scripts/core/cascade_marks.gd")
const CascadeOutline = preload("res://engine/scripts/ui/cascade_outline.gd")

func _initialize() -> void:
	print("== cascade guide marks ==")
	_test_rest_ranks_longest_first_and_caps()
	_test_drag_keeps_only_the_longest_chain_loud()
	_test_drag_winner_is_the_longest_not_the_first_that_qualifies()
	_test_drag_without_a_chain_hides_every_chain_mark()
	_test_run_emits_one_mark_covering_the_whole_remaining_run()
	_test_renderer_takes_the_mark_list_and_reads_its_weight()
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

# The rule is LONGEST, and the test above cannot see it: only one of its targets clears CHAIN_MIN_N,
# so "the longest" and "the first that qualifies" pick the same cell there. Proved vacuous by
# mutation — replacing the length comparison with "first eligible wins" left all 24 asserts green.
# Here BOTH targets cascade and the row-major FIRST one is the SHORTER, so the two rules disagree.
func _test_drag_winner_is_the_longest_not_the_first_that_qualifies() -> void:
	var b := _blank_board()
	b.place(Vector2i(0, 0), 101)          # the held piece
	b.place(Vector2i(0, 2), 101)          # idx 2 — merges, then one t2 partner   -> n = 2
	b.place(Vector2i(1, 2), 102)
	b.place(Vector2i(3, 4), 101)          # a later idx — climbs two rungs        -> n = 3
	b.place(Vector2i(4, 4), 102)
	b.place(Vector2i(5, 4), 103)
	var targets := CascadeMarks._merge_targets(b, Vector2i(0, 0), _occupied_cells(b))
	var lengths: Array = []
	for raw in targets:
		lengths.append([Vector2i((raw as Dictionary).get("cell", Vector2i(-1, -1))), int((raw as Dictionary).get("n", 0))])
	# the premise: two qualifying targets, the earlier one shorter. Without this the test is vacuous
	# again the moment a fixture edit collapses the two rules onto one answer.
	ok(lengths == [[Vector2i(0, 2), 2], [Vector2i(3, 4), 3]],
		"the fixture offers two cascading targets, shortest first in row-major order (got %s)" % str(lengths))
	var marks := CascadeMarks.build(b, _drag_ctx(b, Vector2i(0, 0)))
	var loud_targets: Array = []
	for raw in _loud(marks):
		var m: Dictionary = raw
		if String(m.get("role", "")) == "target":
			loud_targets.append([Vector2i(m.get("cell", Vector2i(-1, -1))), int(m.get("n", 0))])
	ok(loud_targets == [[Vector2i(3, 4), 3]],
		"the LONGER chain wins even though the shorter one qualifies first (got %s)" % str(loud_targets))
	var dim_cells: Array = []
	for raw in marks:
		var m: Dictionary = raw
		if String(m.get("role", "")) == "target" \
				and is_equal_approx(float(m.get("weight", 0.0)), CascadeMarks.DRAG_DIM):
			dim_cells.append(Vector2i(m.get("cell", Vector2i(-1, -1))))
	ok(dim_cells == [Vector2i(0, 2)],
		"the losing cascade target is dimmed, not hidden (got %s)" % str(dim_cells))

func _test_drag_without_a_chain_hides_every_chain_mark() -> void:
	var b := _blank_board()
	b.place(Vector2i(0, 0), 101)
	b.place(Vector2i(0, 2), 101)          # a plain pair: merging is possible, nothing cascades
	# A lone one-tier-up kin, far from everything: its empty neighbours are the staging pads. A
	# same-CODE kin could not be used here — any board where dropping the held code would cascade
	# also gives the held code a cascading merge target, so a winner would exist and the staging
	# pads would (correctly) be suppressed.
	b.place(Vector2i(5, 0), 102)
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
	var stage_cells: Array = []
	for raw in marks:
		var m: Dictionary = raw
		if String(m.get("role", "")) == "stage":
			stage_cells.append(Vector2i(m.get("cell", Vector2i(-1, -1))))
	ok(stage_cells == [Vector2i(4, 0), Vector2i(5, 1), Vector2i(6, 0)],
		"the pads ring the lone kin, row-major (got %s)" % str(stage_cells))
	for raw in marks:
		var m: Dictionary = raw
		if String(m.get("role", "")) == "target":
			ok(is_equal_approx(float(m.get("weight", 0.0)), CascadeMarks.MERGE_WEIGHT),
				"a plain merge target keeps today's merge weight")

func _test_run_emits_one_mark_covering_the_whole_remaining_run() -> void:
	var b := _blank_board()
	b.place(Vector2i(3, 2), 102)
	b.place(Vector2i(4, 2), 103)
	b.place(Vector2i(5, 2), 104)
	# One rung PAST the run's far end, so the resting mark over this same component covers four cells
	# where the run covers three: an assert on the run's cells cannot be satisfied by the resting one.
	b.place(Vector2i(6, 2), 105)
	# A SECOND resting mark of another line, so "exactly one mark" cannot be satisfied by the board's
	# own resting state: this board reads as two runways at rest, and RUN must emit neither.
	b.place(Vector2i(3, 5), 202)
	b.place(Vector2i(4, 5), 203)
	b.place(Vector2i(5, 5), 204)
	ok(CascadeMarks.build(b, {"mode": CascadeMarks.MODE_REST, "chain_min_n": 2, "runway_min_n": 3}).size() == 2,
		"the fixture really does have resting marks of its own")
	var marks := CascadeMarks.build(b, {
		"mode": CascadeMarks.MODE_RUN, "chain_min_n": 2, "runway_min_n": 3,
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
	# the glow. RUN must not consult the board's resting state at all, and that holds on the LAST step
	# too, where nothing is left to walk: this same fixture reads as two runways at rest, and the run's
	# final beat must still be its own single mark on the cell the merge is landing in. (Spec: the mark
	# is republished at every step until `_finish_chain`, and its run is head + whatever remains.)
	var last := CascadeMarks.build(b, {
		"mode": CascadeMarks.MODE_RUN, "chain_min_n": 2, "runway_min_n": 3,
		"head": Vector2i(5, 2), "run": [], "n": 3,
	})
	ok(last.size() == 1 and _cells_match(Array((last[0] as Dictionary).get("run", [])), [Vector2i(5, 2)])
		and float((last[0] as Dictionary).get("weight", 0.0)) > 0.0,
		"a run with nothing left to walk still lights its head (got %s)" % str(last))
	# …and a run with no head at all is nothing, which is what a bailed-out chain publishes.
	ok(CascadeMarks.build(b, {"mode": CascadeMarks.MODE_RUN, "chain_min_n": 2, "head": Vector2i(-1, -1), "run": []}).is_empty(),
		"a run with no head emits nothing")

# The renderer, with no scene, no window and no board: one Control and one mark list. A frame never
# runs here, so what is asserted is the NODE'S OWN state — and that is what pins the wiring. The list
# is the renderer's channel, a mark that carries weight starts the travelling wave, a tagged mark
# makes exactly one chip, and a mark with no weight starts nothing whatever its role. The strengths
# are the mark's own: nothing below asks what the mark IS in order to decide how loud it is.
func _test_renderer_takes_the_mark_list_and_reads_its_weight() -> void:
	var o: Control = CascadeOutline.new()
	o.configure(Vector2(400, 400), 40.0, func(cell: Vector2i) -> Vector2:
		return Vector2(cell.y * 44.0, cell.x * 44.0))
	var run := [Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3)]
	o.set_marks([CascadeMarks.mark("chain", run, CascadeMarks.NO_CELL, 1, 3, 1.0, 1.0, true, Vector2i(1, 3))])
	ok(Array(o.get("marks")).size() == 1,
		"set_marks is a mark channel of the renderer's own (got %d)" % Array(o.get("marks")).size())
	ok(o.is_processing(), "a mark with weight drives the travelling wave")
	ok(_tag_count(o) == 1, "one tagged mark makes one chip (got %d)" % _tag_count(o))
	# The SAME chain mark, only weightless: loudness is read off the mark, never off its role.
	o.set_marks([CascadeMarks.mark("chain", run, CascadeMarks.NO_CELL, 1, 3, 0.0, 1.0, false, CascadeMarks.NO_CELL)])
	ok(not o.is_processing(), "a mark with no weight drives nothing, whatever its role")
	o.set_marks([])
	ok(not o.is_processing(), "an empty list stops the wave")
	ok(not o.has_method("_mark_thickness"),
		"the width helper the drawing never called is gone — a runway's weakness is its weight")
	o.free()

func _tag_count(o: Control) -> int:
	var n := 0
	for child in o.get_children():
		if String((child as Node).name).begins_with("CascadeTag"):
			n += 1
	return n

func _cells_match(got: Array, want: Array) -> bool:
	if got.size() != want.size():
		return false
	for i in want.size():
		if Vector2i(got[i]) != Vector2i(want[i]):
			return false
	return true
