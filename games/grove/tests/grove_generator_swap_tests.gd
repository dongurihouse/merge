extends "res://games/grove/tests/grove_test_base.gd"
## grove · generator swap — focused scene coverage for board drag routes involving generators.

func _initialize() -> void:
	begin("grove · generator swap")
	fresh("generator_swap_ui")
	var old_drag_swap := bool(Feat.FLAGS.get("drag_swap", true))
	Feat.FLAGS["drag_swap"] = true
	var sp = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(sp)
	await process_frame
	if sp.board == null:
		sp._ready()
	var half: Vector2 = Vector2(sp.csz, sp.csz) / 2.0
	var empty_cells: Array = sp.board.empty_ground_cells()
	var item_cell := Vector2i(empty_cells[0])
	var other_gen_cell := Vector2i(empty_cells[1])
	var anchor_cell := Vector2i(G.GEN_CELL)

	sp.board.place(item_cell, 101)
	sp._rebuild_pieces()
	sp._on_press(sp._cell_pos(item_cell) + half)
	sp._on_release(sp._cell_pos(anchor_cell) + half)
	ok(sp.board.item_at(anchor_cell) == 101 and sp.board.is_gen(item_cell) and not sp.board.is_gen(anchor_cell), \
		"item dropped on a generator swaps their cells")

	sp._on_press(sp._cell_pos(item_cell) + half)
	sp._on_release(sp._cell_pos(anchor_cell) + half)
	ok(sp.board.item_at(item_cell) == 101 and sp.board.is_gen(anchor_cell) and not sp.board.is_gen(item_cell), \
		"generator dropped on an item swaps their cells")

	sp.board.place_gen("gen_2", other_gen_cell)
	sp._rebuild_all()
	sp._on_press(sp._cell_pos(anchor_cell) + half)
	sp._on_release(sp._cell_pos(other_gen_cell) + half)
	ok(sp.board.gen_id_at(other_gen_cell) == "gen_1" and sp.board.gen_id_at(anchor_cell) == "gen_2", \
		"generator dropped on a different generator swaps generator cells")

	Feat.FLAGS["drag_swap"] = old_drag_swap
	get_root().remove_child(sp)
	sp.free()
	await process_frame
	finish()
