extends "res://games/grove/tests/grove_test_base.gd"
## grove · info bar — focused tests for player-facing selected-item copy.

const Kit = preload("res://games/grove/tools/ui_workbench_kit.gd")

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
		for special_line in G.SPECIAL_ITEMS:
			var special_code := int(special_line) * 100 + 1
			ok(content.call("item_display_name", special_code) != "Item", "special item line %d has player-facing copy" % int(special_line))
			ok(String(content.call("item_description", special_code)) != "", "special item line %d has info-bar detail" % int(special_line))
		for treat_line in G.TREAT_LINES:
			var treat_code := int(treat_line) * 100 + G.TREAT_POP_TIER
			ok(content.call("item_display_name", treat_code) != "Item", "treat item line %d has player-facing copy" % int(treat_line))
			ok(String(content.call("item_description", treat_code)) != "", "treat item line %d has info-bar detail" % int(treat_line))
	var has_generator_copy_helpers := content.has_method("generator_display_name") and content.has_method("generator_description")
	ok(has_generator_copy_helpers, "content exposes canonical generator display-name and description helpers")
	if has_generator_copy_helpers:
		ok(content.call("generator_display_name", "acc_water") == "Rain barrel", "accumulators have real generator names")
		ok(String(content.call("generator_description", "acc_water")).contains("water"), "accumulators describe their banked reward")
		ok(String(content.call("generator_display_name", G.treat_gen_id(71))).contains("Prize pumpkin"), "treat generators name their treasure line")
		ok(String(content.call("generator_description", G.treat_gen_id(71))).contains("Prize pumpkin"), "treat generators describe their premium output")

	fresh("info_bar_copy")
	var board_scene = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(board_scene)
	await process_frame
	if board_scene.board == null:
		board_scene._ready()
	await create_timer(0.05).timeout
	var info_button := board_scene.get("_info_btn") as Button
	var live_hides_info := bool(Kit.info_bar_opts_from_config(Kit.load_config(Kit.CONFIG_PATH)).get("hide_info_button", false))
	ok(info_button != null, "the info bar exposes its info button")
	ok(info_button != null and not info_button.visible, "the empty info bar hides the info button")
	var desc_label: Label = board_scene.get("_info_desc_label") as Label
	ok(desc_label != null and desc_label.visible and desc_label.text.contains("Drag an item to the bag"), \
		"the empty info bar mentions dragging an item to the bag for space")

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
		ok(info_button.visible == (not live_hides_info) and info_button.disabled == live_hides_info, \
			"selecting an item applies the configured info button visibility")
		ok(board_scene._info_label.text == "Water drop", "the info bar title is the item name without tier suffix")
		ok(desc_label != null and desc_label.visible and desc_label.text.begins_with("Tier 1"), \
			"the info bar subtitle starts with the selected item's tier")
		ok(desc_label != null and desc_label.visible and desc_label.text.contains("8 water"), \
			"the info bar subtitle keeps the selected item's useful hint")
		ok(board_scene._info_label.autowrap_mode != TextServer.AUTOWRAP_OFF and not board_scene._info_label.clip_text, \
			"the info bar title wraps instead of ellipsizing when it overflows")
		ok(desc_label != null and desc_label.autowrap_mode != TextServer.AUTOWRAP_OFF and not desc_label.clip_text, \
			"the info bar subtitle wraps instead of ellipsizing when it overflows")
		var selected_icon_slot := board_scene.get("_info_icon") as Control
		var selected_art := selected_icon_slot.get_child(0) as Control if selected_icon_slot != null and selected_icon_slot.get_child_count() > 0 else null
		var expected_icon_px_raw = board_scene.get("_info_item_px")
		var expected_icon_px := float(expected_icon_px_raw) if expected_icon_px_raw != null else -1.0
		ok(expected_icon_px > float(board_scene.get("_info_inner_px")), \
			"the live info bar item artwork size is based on bar height, not the info button slot")
		ok(selected_art != null and is_equal_approx(selected_art.custom_minimum_size.x, expected_icon_px), \
			"the live info bar selected item uses the height-based artwork size")
		var selected_art_sprite := selected_art.get_node_or_null(NodePath("ItemArt")) as Control if selected_art != null else null
		ok(selected_art_sprite != null \
			and is_equal_approx(selected_art_sprite.offset_left, 0.0) \
			and is_equal_approx(selected_art_sprite.offset_top, 0.0), \
			"the live info bar selected item uses the full artwork box without board-cell inset")
		board_scene._on_info_pressed()
		await process_frame
		ok(board_scene.get_node_or_null("LadderOverlay") != null, "the selected special item opens its tier info")
		var special_ladder: Array = board_scene._ladder_entries(12)
		ok(special_ladder.size() == G.merge_top(1201), "special item ladders stop at their merge ceiling")
		var special_overlay: Node = board_scene.get_node_or_null("LadderOverlay")
		if special_overlay != null:
			special_overlay.queue_free()
			await process_frame
		board_scene._clear_selection()
		ok(not info_button.visible and info_button.disabled, "clearing focus hides and disables the info button")
		ok(desc_label != null and desc_label.visible and desc_label.text.contains("Drag an item to the bag"), \
			"clearing focus restores the empty info bar bag-space hint")

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

	# Regression (the live bug): emulate_touch_from_mouse=true delivers a mouse AND a synthesized touch
	# event per physical tap, so _on_board_input sees each press/release TWICE. Without dedup the 2nd press
	# clears the focus the 1st captured, so the second tap reads _press_was_selected=false and merely
	# RE-FOCUSES the coin instead of collecting. Drive a coin with the DOUBLE-event tap and confirm collect.
	var dbl_cell := coin_cell   # reuse the now-empty cell from the first collect (fresh board has few open cells)
	if dbl_cell.x >= 0 and board_scene.board.item_at(dbl_cell) == 0:
		board_scene.board.place(dbl_cell, 902)
		board_scene._rebuild_pieces()
		var dhalf := Vector2(board_scene.csz, board_scene.csz) / 2.0
		var dat: Vector2 = board_scene._cell_pos(dbl_cell) + dhalf   # board_area-local (gui_input space)
		var dcoins0 := Save.coins()
		_tap_emulated(board_scene, dat)   # tap 1 → focus
		await create_timer(0.05).timeout
		ok(board_scene._selected_cell == dbl_cell, "double-event tap 1 focuses the coin")
		_tap_emulated(board_scene, dat)   # tap 2 → must COLLECT, not just re-focus
		await create_timer(0.05).timeout
		ok(board_scene.board.item_at(dbl_cell) == 0, "double-event tap 2 COLLECTS (emulate_touch_from_mouse dedup)")
		ok(Save.coins() == dcoins0 + G.coin_value(902), "double-event collect credits the coin value")

	# Producing dialog (tap generator → ⓘ): the lines a generator currently makes, drilling into each line's
	# tier ladder. Logic (_gen_line_entries / _pop_pool_ctx) + the info-button wiring.
	var gens: Dictionary = board_scene.board.gens
	ok(not gens.is_empty(), "the fresh board has its anchor generator")
	if not gens.is_empty():
		var gcell: Vector2i = gens.keys()[0]
		var gid: String = board_scene.board.gen_id_at(gcell)
		var entries: Array = board_scene._gen_line_entries(gid)
		ok(not entries.is_empty(), "the generator reports its lines")
		# SHOW ALL: every line in the WHOLE game (every generator / every map) gets a cell — the full roadmap.
		var all_game_lines: Array = []
		for gen in G.GENERATORS:
			for l in gen.get("lines", []):
				if not all_game_lines.has(int(l)):
					all_game_lines.append(int(l))
		var entry_lines: Array = []
		var all_valid := true
		var gated_present := false
		var gated_unseen := false
		var has_other_map := false
		for e in entries:
			entry_lines.append(int(e.line))
			if not G.LINES.has(int(e.line)):
				all_valid = false
			if int(e.line) == 66:                 # Flower boxes — min_level 6, NOT yet grown in at the fresh level
				gated_present = true
				gated_unseen = not bool(e.seen)
			if int(e.line) == 5:                  # Mushroom — a LATER map's (Meadow) line, far from the farm anchor
				has_other_map = true
		ok(all_valid, "every Producing entry is a real game line")
		var all_present := true
		for gl in all_game_lines:
			if not entry_lines.has(int(gl)):
				all_present = false
		ok(all_present and entries.size() == all_game_lines.size(), "every line in the game gets a cell (show-all roadmap)")
		ok(has_other_map, "lines from later maps appear too (not just the tapped generator's own roster)")
		ok(gated_present, "a not-yet-grown-in line (min_level-gated) still appears as a cell, not hidden")
		ok(gated_unseen, "the not-yet-grown-in line shows as an unseen placeholder until the player reaches it")
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
		ok(board_scene._info_btn.disabled == live_hides_info, "selecting a generator applies the configured info button visibility")
		board_scene._on_info_pressed()
		await process_frame
		ok(board_scene.get_node_or_null("GenLinesOverlay") != null, "the info button opens the Producing dialog overlay")
		var ov: Node = board_scene.get_node_or_null("GenLinesOverlay")
		if ov != null:
			ov.queue_free()
		board_scene._clear_selection()

	# Special generators: accumulators and temporary treat generators are board generators too. A still
	# tap must leave them focused with useful copy, even though their tap action is collect/pop instead of
	# the normal seed burst.
	var acc_cell := _first_empty_cell(board_scene, [])
	ok(acc_cell.x >= 0, "the accumulator focus test found an empty cell")
	if acc_cell.x >= 0:
		board_scene.board.place_gen("acc_water", acc_cell)
		board_scene._rebuild_all()
		var acc_at: Vector2 = board_scene._cell_pos(acc_cell) + Vector2(board_scene.csz, board_scene.csz) / 2.0
		_tap_emulated(board_scene, acc_at)
		await create_timer(0.05).timeout
		ok(board_scene._selected_cell == acc_cell, "tapping an accumulator generator focuses its cell")
		ok(board_scene._info_label.text.contains("Rain barrel"), "focused accumulator shows its real name")
		var acc_desc: Label = board_scene.get("_info_desc_label") as Label
		ok(acc_desc != null and acc_desc.visible and acc_desc.text.contains("water"), "focused accumulator shows useful info text")
		ok(board_scene._info_btn.disabled, "accumulators disable the producing-ladder button because they bank currency")
		board_scene._clear_selection()

	var treat_cell := acc_cell if acc_cell.x >= 0 else _first_empty_cell(board_scene, [])
	var treat_id := G.treat_gen_id(71)
	ok(treat_cell.x >= 0, "the treat generator focus test found an empty cell")
	if treat_cell.x >= 0:
		board_scene.board.gens.erase(treat_cell)
		board_scene.board.place_gen(treat_id, treat_cell)
		Save.grove()["treat_clicks"] = 2
		board_scene._rebuild_all()
		var treat_entries: Array = board_scene._gen_line_entries(treat_id)
		ok(treat_entries.size() == 1 and int(treat_entries[0].line) == 71, "a treat generator reports only its treasure line")
		var treat_at: Vector2 = board_scene._cell_pos(treat_cell) + Vector2(board_scene.csz, board_scene.csz) / 2.0
		_tap_emulated(board_scene, treat_at)
		await create_timer(0.05).timeout
		ok(board_scene._selected_cell == treat_cell, "tapping a live treat generator focuses its cell")
		ok(board_scene._info_label.text.contains("Prize pumpkin"), "focused treat generator names its treasure")
		var treat_desc: Label = board_scene.get("_info_desc_label") as Label
		ok(treat_desc != null and treat_desc.visible and treat_desc.text.contains("Prize pumpkin"), "focused treat generator explains its output")
		ok(board_scene._info_btn.disabled == live_hides_info, "treat generators apply the configured info button visibility")
		board_scene._on_info_pressed()
		await process_frame
		ok(board_scene.get_node_or_null("GenLinesOverlay") != null, "the treat generator info button opens its producing overlay")
		var tov: Node = board_scene.get_node_or_null("GenLinesOverlay")
		if tov != null:
			tov.queue_free()
		board_scene._clear_selection()

	# Workbench parity: when the saved info-bar config hides the info button, the live board hides the
	# actual tappable icon too, even after an item is selected into the bar.
	var hidden_cfg: Dictionary = Kit.load_config(Kit.CONFIG_PATH).duplicate(true)
	var hidden_info: Dictionary = (hidden_cfg.get("info_bar", {}) as Dictionary).duplicate(true)
	hidden_info["hide_info_button"] = true
	hidden_cfg["info_bar"] = hidden_info
	Kit._config_cache[Kit.CONFIG_PATH] = hidden_cfg
	var hidden_board = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(hidden_board)
	await process_frame
	if hidden_board.board == null:
		hidden_board._ready()
	await create_timer(0.05).timeout
	ok(hidden_board._info_btn != null and not hidden_board._info_btn.visible, \
		"the live board reads the workbench config and hides the info button")
	var hidden_cell := Vector2i(-1, -1)
	for c in hidden_board.board.empty_ground_cells():
		if not hidden_board.board.is_gen(c):
			hidden_cell = c
			break
	if hidden_cell.x >= 0:
		hidden_board.board.place(hidden_cell, 1201)
		hidden_board._rebuild_pieces()
		hidden_board._select_item(hidden_cell)
		ok(not hidden_board._info_btn.visible, \
			"selecting an item keeps the hidden info button out of the live info bar")
		var hidden_icon_slot := hidden_board.get("_info_icon") as Control
		ok(hidden_icon_slot != null and hidden_icon_slot.visible, \
			"selecting an item keeps the selected item icon visible when the info button is hidden")
		if hidden_icon_slot != null:
			_push_tap(hidden_icon_slot.get_global_rect().get_center())
			await process_frame
			ok(hidden_board.get_node_or_null("LadderOverlay") != null, \
				"tapping the selected item icon opens the item info dialog when the info button is hidden")
			var hidden_ladder: Node = hidden_board.get_node_or_null("LadderOverlay")
			if hidden_ladder != null:
				hidden_ladder.queue_free()
				await process_frame
	hidden_board.queue_free()
	hidden_board = null
	Kit.clear_config_cache(Kit.CONFIG_PATH)

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

# A physical tap under emulate_touch_from_mouse=true: the engine delivers BOTH a mouse-button event AND a
# synthesized screen-touch event, so the board input handler sees the press/release TWICE per tap. Drives
# _on_board_input directly with board_area-local positions (its gui_input space).
func _tap_emulated(board, at: Vector2) -> void:
	var md := InputEventMouseButton.new(); md.button_index = MOUSE_BUTTON_LEFT; md.pressed = true; md.position = at
	var td := InputEventScreenTouch.new(); td.pressed = true; td.position = at
	board._on_board_input(md)
	board._on_board_input(td)
	var mu := InputEventMouseButton.new(); mu.button_index = MOUSE_BUTTON_LEFT; mu.pressed = false; mu.position = at
	var tu := InputEventScreenTouch.new(); tu.pressed = false; tu.position = at
	board._on_board_input(mu)
	board._on_board_input(tu)

func _first_empty_cell(board, skip: Array) -> Vector2i:
	for c in board.board.empty_ground_cells():
		if not board.board.is_gen(c) and not skip.has(c):
			return c
	return Vector2i(-1, -1)
