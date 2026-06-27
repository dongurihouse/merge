extends "res://games/grove/tests/grove_test_base.gd"
## grove · info bar — focused tests for player-facing selected-item copy.

func _initialize() -> void:
	begin("grove · info bar")

	var content := G.new()
	var has_copy_helpers := content.has_method("item_display_name") and content.has_method("item_description")
	ok(has_copy_helpers, "content exposes canonical item display-name and description helpers")
	if has_copy_helpers:
		ok(content.call("item_display_name", 6101) == "Hearth embers", "regular lines keep their authored display names")
		ok(String(content.call("item_description", 6101)).contains("early quests"), "regular lines carry a player-useful hint")
		ok(content.call("item_display_name", 1201) == "Water drop", "special drops have real display names")
		ok(String(content.call("item_description", 1202)).contains("20 water"), "collectable special drops describe their tier reward")
		ok(content.call("item_display_name", 1501) == "Wildcard", "wildcards have a real display name")
		ok(String(content.call("item_description", 1501)).contains("same-tier"), "wildcards explain their drag rule")
		ok(content.call("item_display_name", 902) == "Coin", "coin items have a real display name")
		ok(String(content.call("item_description", 902)).contains("5 coins"), "coin items explain their collect value")

	fresh("info_bar_copy")
	var board_scene = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(board_scene)
	await process_frame
	if board_scene.board == null:
		board_scene._ready()
	await create_timer(0.05).timeout

	var cell := Vector2i(-1, -1)
	for c in board_scene.board.empty_ground_cells():
		if not board_scene.board.is_gen(c):
			cell = c
			break
	ok(cell.x >= 0, "the focused info-bar test found an empty board cell")
	if cell.x >= 0:
		board_scene.board.place(cell, 1201)
		board_scene._rebuild_pieces()
		board_scene._select_item(cell)
		ok(board_scene._info_label.text == "Water drop · Tier 1", "the info bar names special drops instead of falling back to Item")
		var desc_label: Label = board_scene.get("_info_desc_label") as Label
		ok(desc_label != null and desc_label.visible and desc_label.text.contains("8 water"), "the info bar shows the selected item's useful hint")

	# Focus + two-tap collect (real click routing): tapping a coin FOCUSES its cell (a corner-bracket
	# frame appears) and a SECOND tap of the now-focused cell COLLECTS it. The frame is the on-board
	# cue that makes the two-tap discoverable — without it players read the collect as broken.
	var coin_cell := Vector2i(-1, -1)
	for c in board_scene.board.empty_ground_cells():
		if not board_scene.board.is_gen(c) and c != cell:
			coin_cell = c
			break
	ok(coin_cell.x >= 0, "the collect test found a second empty cell")
	if coin_cell.x >= 0:
		board_scene.board.place(coin_cell, 902)   # a tier-2 coin worth 5
		board_scene._rebuild_pieces()
		var half := Vector2(board_scene.csz, board_scene.csz) / 2.0
		var gat: Vector2 = board_scene.board_area.get_global_transform() * (board_scene._cell_pos(coin_cell) + half)
		var coins0 := Save.coins()
		_push_tap(gat)                                   # tap 1 → focus
		await create_timer(0.05).timeout
		ok(board_scene._selected_cell == coin_cell, "tap 1 focuses the coin cell")
		ok(board_scene._focus_ring != null and is_instance_valid(board_scene._focus_ring) and board_scene._focus_ring.visible, \
			"tap 1 shows the corner-bracket focus frame")
		ok(board_scene._focus_ring.position == board_scene._cell_pos(coin_cell), "the focus frame sits on the focused cell")
		ok(board_scene.board.item_at(coin_cell) == 902, "tap 1 does NOT collect the coin")
		_push_tap(gat)                                   # tap 2 → collect
		await create_timer(0.05).timeout
		ok(board_scene.board.item_at(coin_cell) == 0, "tap 2 of the focused coin collects it")
		ok(Save.coins() == coins0 + G.coin_value(902), "collecting credits the coin value (+%d)" % G.coin_value(902))
		ok(not board_scene._focus_ring.visible, "collecting clears the focus frame")

	# Producing dialog (tap generator → ⓘ): the lines a generator currently makes, drilling into each line's
	# tier ladder. Logic (_gen_line_entries / _pop_pool_ctx) + the info-button wiring.
	var gens: Dictionary = board_scene.board.gens
	ok(not gens.is_empty(), "the fresh board has its anchor generator")
	if not gens.is_empty():
		var gcell: Vector2i = gens.keys()[0]
		var gid: String = board_scene.board.gen_id_at(gcell)
		var entries: Array = board_scene._gen_line_entries(gid)
		ok(not entries.is_empty(), "the generator reports at least one currently-live line")
		var roster_lines: Array = G.gen_def(G.GENERATORS, gid).get("lines", [])
		var level: int = board_scene._quest_level()
		var all_rostered := true
		var all_live := true
		var hides_gated := true
		for e in entries:
			if not roster_lines.has(int(e.line)):
				all_rostered = false
			if int(G.LINES.get(int(e.line), {}).get("min_level", 0)) > level:
				all_live = false
			if int(e.line) == 66:                 # Flower boxes — min_level 6, gated out at the fresh low level
				hides_gated = false
		ok(all_rostered, "every Producing entry is one of the generator's roster lines")
		ok(all_live, "every Producing entry is currently live (no future min_level-gated teasers)")
		ok(hides_gated, "a future min_level-gated line stays hidden until the player reaches it")
		# in_pool must match the live pop pool exactly — the dialog highlight is what a tap would spawn now.
		var pool: Array = board_scene._pop_pool_ctx()["pool"]
		var pool_match := true
		for e in entries:
			if bool(e.in_pool) != pool.has(int(e.line)):
				pool_match = false
		ok(pool_match, "Producing in_pool flags match the live pop pool exactly")
		# seen/code: a wholly-unseen line carries no piece (code 0); marking its tier-1 lights it with that code.
		var probe := int(entries[0].line)
		var g := Save.grove()
		g["seen"] = {}
		ok(int(board_scene._gen_line_entries(gid)[0].code) == 0, "an unseen line carries no representative piece (code 0)")
		g["seen"][str(probe * 100 + 1)] = true
		var lit: Array = board_scene._gen_line_entries(gid)
		ok(bool(lit[0].seen) and int(lit[0].code) == probe * 100 + 1, "a seen line shows its lowest-seen tier piece")
		# wiring: selecting the generator enables ⓘ, and ⓘ opens the Producing overlay (feature is on).
		board_scene._select_generator(gcell)
		ok(not board_scene._info_btn.disabled, "selecting a generator enables the info button")
		board_scene._on_info_pressed()
		await process_frame
		ok(board_scene.get_node_or_null("GenLinesOverlay") != null, "the info button opens the Producing dialog overlay")
		var ov: Node = board_scene.get_node_or_null("GenLinesOverlay")
		if ov != null:
			ov.queue_free()
		board_scene._clear_selection()

	# Watchdog: a stuck `animating` gate must self-heal so board taps can never soft-lock. Force the
	# gate true and confirm it clears within the watchdog window; a brief gate (a normal merge) must NOT.
	board_scene.animating = true
	board_scene._anim_t = 0.0
	await create_timer(0.25).timeout
	ok(board_scene.animating, "a brief animating gate (a normal merge) is NOT force-cleared early")
	await create_timer(0.6).timeout
	ok(not board_scene.animating, "a STUCK animating gate self-heals (watchdog re-enables board input)")

	board_scene.queue_free()
	board_scene = null
	content = null
	await process_frame
	await process_frame
	finish()

# A real still-tap routed through the viewport's GUI hit-testing (honours mouse_filter, z-order,
# overlays) at a GLOBAL screen point — the closest headless analog to a live finger tap.
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
