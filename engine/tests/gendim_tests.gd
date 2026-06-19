extends SceneTree
## Headless tests for the §6 full-board generator DIM cue: when the board has NO free
## cell, every live generator node modulates to the standing GEN_DIM (popping stays free
## while dimmed); the instant a cell frees, it restores to GEN_LIT (full modulate). Drives
## the live Board scene to both states deterministically and asserts after the refresh.
##   godot --headless --path . -s res://engine/tests/gendim_tests.gd

const G = preload("res://engine/scripts/core/content.gd")
const BoardModel = preload("res://engine/scripts/core/board_model.gd")
const Save = preload("res://engine/scripts/core/save.gd")
const Board = preload("res://engine/scripts/scenes/board.gd")

var _pass := 0
var _fail := 0

func ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func fresh(name: String) -> void:
	var dir := "user://tu_test_gendim_" + name + "/"
	if DirAccess.dir_exists_absolute(dir):
		for fn in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir + fn)
	else:
		DirAccess.make_dir_recursive_absolute(dir)
	Save.configure_for_test(dir)

# Fill every open ground cell with a plain (non-coin) item so the board has NO free cell.
# Returns one of the cells it filled (a deterministic cell to later free).
func _fill_board(b: BoardModel) -> Vector2i:
	var first := Vector2i(-1, -1)
	for cell in b.empty_ground_cells():
		b.place(cell, 101)            # line 1, tier 1 — a plain filler, never a coin
		if first.x < 0:
			first = cell
	return first

# True when EVERY live generator node (gen_nodes + the primary gen_node) has modulate `m`.
func _all_gens_modulate(scn, m: Color) -> bool:
	var nodes: Array = []
	for gn in scn.gen_nodes.values():
		nodes.append(gn)
	if scn.gen_node != null:
		nodes.append(scn.gen_node)
	if nodes.is_empty():
		return false
	for gn in nodes:
		if gn == null or not is_instance_valid(gn):
			return false
		if not gn.modulate.is_equal_approx(m):
			return false
	return true

func _initialize() -> void:
	print("== Generator-dim (§6) tests ==")

	fresh("scene")
	var scn = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(scn)
	if scn.board == null:
		scn._ready()

	ok(scn.board != null, "the board scene stands up")
	ok(not scn.gen_nodes.is_empty(), "at least one live generator node exists")
	ok(scn.gen_node != null, "the primary generator node is set")

	# Sanity: the dim constants are a genuine STANDING dim (alpha < 1) vs full (alpha 1).
	ok(Board.GEN_DIM.a < 1.0, "GEN_DIM is a real dim (alpha < 1) — got %.2f" % Board.GEN_DIM.a)
	ok(Board.GEN_LIT.a == 1.0, "GEN_LIT is full modulate (alpha == 1)")

	# --- FULL board → every generator dims -------------------------------------
	var freed_cell := _fill_board(scn.board)
	ok(scn.board.empty_ground_cells().is_empty(), "fixture: the board is FULL (no free cell)")
	scn._refresh_generator_dim()
	ok(_all_gens_modulate(scn, Board.GEN_DIM), "FULL board → every generator (and the primary) modulates to GEN_DIM")

	# --- a cell frees → every generator restores to full -----------------------
	scn.board.take(freed_cell)
	ok(not scn.board.empty_ground_cells().is_empty(), "fixture: one cell is now free")
	scn._refresh_generator_dim()
	ok(_all_gens_modulate(scn, Board.GEN_LIT), "free cell → every generator restores to GEN_LIT (full modulate)")

	# --- it is a STANDING state: re-fill dims again (not a one-shot flash) ------
	_fill_board(scn.board)
	scn._refresh_generator_dim()
	ok(_all_gens_modulate(scn, Board.GEN_DIM), "re-filling the board dims again — the cue is a standing state, not one-shot")

	# --- _rebuild_all carries the state: a full board rebuilds DIMMED ----------
	# (covers refill/grant/gate/move, which un-dim via the rebuild seam, not a partial update)
	scn._rebuild_all()
	ok(_all_gens_modulate(scn, Board.GEN_DIM), "_rebuild_all on a FULL board rebuilds the generators already dimmed")
	# free every non-coin item, rebuild → the generators come back lit
	for i in scn.board.items.size():
		var c := BoardModel.cell_of(i)
		if scn.board.item_at(c) > 0 and not G.is_coin(scn.board.item_at(c)):
			scn.board.items[i] = 0
	scn._rebuild_all()
	ok(_all_gens_modulate(scn, Board.GEN_LIT), "_rebuild_all with free cells rebuilds the generators lit")

	scn.queue_free()

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
