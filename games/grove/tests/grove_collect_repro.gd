extends "res://games/grove/tests/grove_test_base.gd"
## TEMP high-fidelity reproduction — real coin-drop path + realistic two-tap timing. Delete after.

func _initialize() -> void:
	begin("grove · collect repro (live)")
	fresh("collect_repro_live")
	var ws = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(ws)
	await process_frame
	if ws.board == null:
		ws._ready()
	await create_timer(0.05).timeout

	# Drop a coin via the REAL path (the same _drop_coin_near generator pops use), then settle its
	# fly-in tween — so the coin under test is byte-identical to a live dropped coin.
	ws.debug_drop_coin()
	await create_timer(0.4).timeout   # let the 0.25s fly-in tween finish
	var cell := Vector2i(-1, -1)
	for r in G.ROWS:
		for cc in G.COLS:
			var k: int = ws.board.item_at(Vector2i(r, cc))
			if k > 0 and G.is_coin(k):
				cell = Vector2i(r, cc)
	ok(cell.x >= 0, "a coin landed on the board via the real drop path (cell %s)" % str(cell))
	if cell.x < 0:
		finish()
		return
	ok(ws.piece_nodes.has(cell) and is_instance_valid(ws.piece_nodes[cell]), "the dropped coin has a tracked piece node")

	var half := Vector2(ws.csz, ws.csz) / 2.0
	var gat: Vector2 = ws.board_area.get_global_transform() * (ws._cell_pos(cell) + half)
	var coins0 := Save.coins()
	print("  DBG pre: animating=%s drag=%s selected=%s coins=%d" % [str(ws.animating), str(ws._drag_node), str(ws._selected_cell), coins0])

	# TAP 1 → focus
	_push_tap(gat)
	await create_timer(0.05).timeout
	print("  DBG after tap1: selected=%s ring_vis=%s item=%d" % [str(ws._selected_cell), str(ws._focus_ring != null and ws._focus_ring.visible), ws.board.item_at(cell)])
	ok(ws._selected_cell == cell, "tap 1 focuses the coin")

	# WAIT through the idle-hint window (IDLE_HINT_SECS = 4.5) with frames processing — does anything
	# clear the selection over time the way the live app would?
	await create_timer(5.0).timeout
	print("  DBG after 5s idle: selected=%s ring_vis=%s animating=%s" % [str(ws._selected_cell), str(ws._focus_ring != null and ws._focus_ring.visible), str(ws.animating)])
	ok(ws._selected_cell == cell, "the focus SURVIVES the idle-hint window (still selected after 5s)")

	# TAP 2 → collect
	_push_tap(gat)
	await create_timer(0.1).timeout
	print("  DBG after tap2: selected=%s item=%d coins=%d (was %d)" % [str(ws._selected_cell), ws.board.item_at(cell), Save.coins(), coins0])
	ok(ws.board.item_at(cell) == 0, "tap 2 of the focused coin COLLECTS it (cell empty)")
	ok(Save.coins() > coins0, "collecting credited coins (%d → %d)" % [coins0, Save.coins()])

	finish()

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
