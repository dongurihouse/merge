extends "res://games/grove/tests/grove_test_base.gd"
## TEMP reproduction — two-tap coin collect. Delete after diagnosis.

func _initialize() -> void:
	begin("grove · collect repro")
	fresh("collect_repro")
	var ws = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(ws)
	if ws.board == null:
		ws._ready()
	await create_timer(0.05).timeout

	# place a tier-2 coin (902) on a clean open ground cell
	var es: Array = ws.board.empty_ground_cells()
	var cell := Vector2i(es[0])
	ws.board.place(cell, 902)
	ws._rebuild_pieces()
	ok(ws.board.item_at(cell) == 902, "setup: coin 902 sits on the board")
	ok(G.is_coin(902) and G.is_collectable(902), "setup: 902 is a collectable coin")
	ok(ws.piece_nodes.has(cell) and is_instance_valid(ws.piece_nodes[cell]), "setup: coin has a tracked piece node")

	var half := Vector2(ws.csz, ws.csz) / 2.0
	# GLOBAL position of the coin centre — exercises the REAL GUI hit-test + mouse_filter routing.
	var gat: Vector2 = ws.board_area.get_global_transform() * (ws._cell_pos(cell) + half)
	print("  DBG board_area.mouse_filter=%d gat=%s coin_holder.mouse_filter=%d" % [ws.board_area.mouse_filter, str(gat), ws.piece_nodes[cell].mouse_filter])

	var coins0 := Save.coins()

	# TAP 1 via the viewport — should FOCUS (select) the coin, not collect it
	_push_tap(gat)
	await create_timer(0.05).timeout
	ok(ws._selected_cell == cell, "tap 1 (real routing) focuses the coin cell (got %s)" % str(ws._selected_cell))
	ok(ws.board.item_at(cell) == 902, "tap 1 does NOT collect (coin still present)")
	print("  DBG after tap1: selected=%s press_was_selected=%s item=%d coins=%d" % [str(ws._selected_cell), str(ws._press_was_selected), ws.board.item_at(cell), Save.coins()])

	# TAP 2 via the viewport — should COLLECT the now-focused coin
	_push_tap(gat)
	await create_timer(0.05).timeout
	print("  DBG after tap2: selected=%s press_was_selected=%s item=%d coins=%d (was %d)" % [str(ws._selected_cell), str(ws._press_was_selected), ws.board.item_at(cell), Save.coins(), coins0])
	ok(ws.board.item_at(cell) == 0, "tap 2 (real routing) collects the coin (cell now empty)")
	ok(Save.coins() == coins0 + G.coin_value(902), "tap 2 credits the coin value (+%d)" % G.coin_value(902))

	finish()

# A real still-tap routed through the viewport's GUI hit-testing (honours mouse_filter,
# z-order, overlays) at a GLOBAL screen point — the closest headless analog to a live click.
func _push_tap(gpos: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = gpos
	down.global_position = gpos
	get_root().push_input(down, true)
	var up := down.duplicate()
	up.pressed = false
	get_root().push_input(up, true)
