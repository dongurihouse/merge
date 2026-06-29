extends "res://games/grove/tests/grove_test_base.gd"
## grove · info bar — focused tests for player-facing selected-item copy.

const Kit = preload("res://games/grove/tools/ui_workbench_kit.gd")
const FX = preload("res://engine/scripts/ui/fx.gd")

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
	ok(info_button != null and info_button.visible and not info_button.disabled, \
		"the empty info bar shows an enabled tutorial info button")
	var info_bar := board_scene.find_child("ActionBarInfoBar", true, false) as Control
	ok(info_bar != null, "the board exposes the live action-bar info bar")
	var empty_info_center_delta := absf(info_button.get_global_rect().get_center().y - info_bar.get_global_rect().get_center().y) if info_button != null and info_bar != null else 999.0
	ok(empty_info_center_delta <= 1.0, \
		"the empty info button is vertically centered in the workbench-tuned info bar")
	ok(board_scene.get_node_or_null("BoardTutorialOverlay") != null, \
		"a fresh board opens the how-to-play tutorial on first run")
	ok(bool(Save.grove().get("board_tutorial_seen", false)), \
		"opening the first-run board tutorial marks it seen")
	var board_intro: Control = board_scene.get_node_or_null("BoardTutorialOverlay") as Control
	var intro_art := board_intro.find_child("TutorialImageArt", true, false) as TextureRect if board_intro != null else null
	var intro_vp: Vector2 = board_scene.get_viewport_rect().size
	ok(board_intro != null and board_intro.find_child("TutorialCloseButton", true, false) == null, \
		"the tutorial image has no separate close button")
	ok(board_intro != null and board_intro.find_child("TutorialImageFrame", true, false) == null, \
		"the tutorial image is not wrapped in a card frame")
	ok(intro_art != null and intro_art.get_global_rect().size.distance_to(intro_vp) < 2.0, \
		"the tutorial image fills the full screen")
	if board_intro != null:
		_push_tap(intro_art.get_global_rect().get_center() if intro_art != null else board_intro.get_global_rect().get_center())
		await process_frame
	ok(board_scene.get_node_or_null("BoardTutorialOverlay") == null, \
		"tapping anywhere on the tutorial image closes it")
	board_scene._on_info_pressed()
	await process_frame
	ok(board_scene.get_node_or_null("BoardTutorialOverlay") != null, \
		"the empty info button reopens the board how-to-play tutorial")
	var reopened_intro: Node = board_scene.get_node_or_null("BoardTutorialOverlay")
	if reopened_intro != null:
		reopened_intro.queue_free()
		await process_frame
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
		ok(info_button.visible and not info_button.disabled, "clearing focus restores the tutorial info button")
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
			var gl := int(gen.get("line", 0))   # gen redesign: one line per generator (the lines[] array is retired)
			if gl > 0 and not all_game_lines.has(gl):
				all_game_lines.append(gl)
		var entry_lines: Array = []
		var all_valid := true
		var has_other_map := false
		for e in entries:
			entry_lines.append(int(e.line))
			if not G.LINES.has(int(e.line)):
				all_valid = false
			if int(e.line) == 37:                 # Small critters — the LAST map's (map 4) line, far from the anchor
				has_other_map = true
		ok(all_valid, "every Producing entry is a real game line")
		var all_present := true
		for gl in all_game_lines:
			if not entry_lines.has(int(gl)):
				all_present = false
		ok(all_present and entries.size() == all_game_lines.size(), "every base line in the game gets a cell (show-all roadmap)")
		ok(has_other_map, "lines from later maps appear too (not just the tapped generator's own roster)")
		# in_pool must match the SELECTED generator's own pop line. The global quest context may span
		# several wanted lines, but a per-line generator still only produces its own line.
		var gen_line := int(G.gen_def(G.GENERATORS, gid).get("line", 0))
		var hot_lines: Array = []
		for e in entries:
			if bool(e.in_pool):
				hot_lines.append(int(e.line))
		ok(hot_lines == [gen_line], "Producing highlights only the selected generator's own line")
		var saved_quests: Array = board_scene.quests.duplicate(true)
		board_scene.quests = [
			{"line": gen_line, "tier": 4, "reward": {"exp": 1, "coins": 0}},
			{"line": 2, "tier": 4, "reward": {"exp": 1, "coins": 0}},
			{"line": 3, "tier": 4, "reward": {"exp": 1, "coins": 0}},
		]
		var global_pool: Array = board_scene._pop_pool_ctx()["pool"]
		ok(global_pool.size() > 1, "test setup: the global quest pool spans multiple lines")
		var mixed_hot: Array = []
		for e in board_scene._gen_line_entries(gid):
			if bool(e.in_pool):
				mixed_hot.append(int(e.line))
		ok(mixed_hot == [gen_line], "Producing stays selected-generator-only when quests want several lines")
		board_scene.quests = saved_quests
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

		board_scene.board.gens.erase(acc_cell)
		board_scene.board.place_gen("acc_coins", acc_cell)
		Save.grove()["bonus_clicks"] = 3
		var bonus_drop_cell := _first_empty_cell(board_scene, [acc_cell])
		if bonus_drop_cell.x < 0:
			for i in board_scene.board.items.size():
				var c := BoardModel.cell_of(i)
				if c != acc_cell and board_scene.board.is_open(c) and not board_scene.board.is_gen(c):
					board_scene.board.take(c)
					bonus_drop_cell = c
					break
		ok(bonus_drop_cell.x >= 0, "the bonus generator item-pop test found room for a board item")
		board_scene._rebuild_all()
		var coins0 := Save.coins()
		var coin_items0 := 0
		for v in board_scene.board.items:
			if G.is_coin(v):
				coin_items0 += 1
		_tap_emulated(board_scene, acc_at)
		await create_timer(0.05).timeout
		var coin_items1 := 0
		for v in board_scene.board.items:
			if G.is_coin(v):
				coin_items1 += 1
		ok(Save.coins() == coins0, "tapping a bonus coin generator does not pay the coin pill directly")
		ok(coin_items1 > coin_items0, "tapping a bonus coin generator pops coin items onto the board")
		ok(int(Save.grove().get("bonus_clicks", 0)) == 2, "tapping a bonus generator spends one of its own taps")
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
	ok(hidden_board._info_btn != null and hidden_board._info_btn.visible and not hidden_board._info_btn.disabled, \
		"the empty info bar keeps the tutorial info button visible even when selected-item info is hidden")
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

	# Bundle A (tactile) board drag: the merge-target TELEGRAPH and the held-tile LEAN.
	_test_drag_feel()

	# PER-LINE PRODUCTION (gen redesign #4): a generator pops ONLY its own line through the real _pop_seed
	# tap path, even when several active quests want OTHER lines. roll_spawn leans ~ASK_WEIGHT toward the
	# quest-wanted set, so feeding it the un-narrowed `wanted` makes a line-1 generator also spew the other
	# quests' lines (the "both generators produce both lines" bug). Tap the anchor with two lines wanted and
	# assert nothing foreign ever lands. (The sibling _gen_line_entries highlight is asserted above.)
	fresh("per_line_pop")
	var spl = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(spl)
	if spl.board == null:
		spl._ready()
	await process_frame
	spl.rng.seed = 424242                               # deterministic spawn stream
	Save.grove()["pops"] = 99                           # past the FTUE free pops → charged bursts
	spl.water = 9_999_999
	spl.quests = [
		{"line": 1, "tier": 4, "reward": {"exp": 1, "coins": 0}},
		{"line": 2, "tier": 4, "reward": {"exp": 1, "coins": 0}},
	]
	spl.giver_chips = [{"chip": null, "qi": 0}, {"chip": null, "qi": 1}]
	ok(spl._pop_pool_ctx()["wanted"].size() >= 2, "per-line: test setup — active quests want more than one line")
	var pl_cell: Vector2i = spl.board.gens.keys()[0]
	ok(int(G.gen_def(G.GENERATORS, spl.board.gen_id_at(pl_cell)).get("line", 0)) == 1, "per-line: the anchor generator is line 1")
	var pl_own := 0
	var pl_foreign := 0
	for _i in 30:
		for ci in spl.board.items.size():              # clear non-gen items so each tap pops onto open ground
			if spl.board.items[ci] > 0 and not spl.board.gens.has(BoardModel.cell_of(ci)):
				spl.board.items[ci] = 0
		spl._pop_seed(pl_cell)
		for v in spl.board.items:
			if v > 0:
				var ln := BoardModel.line_of(v)
				if ln == 1:
					pl_own += 1
				elif ln != 0:
					pl_foreign += 1
	ok(pl_own > 0, "per-line: the line-1 generator pops its own line")
	ok(pl_foreign == 0, "per-line: a line-1 generator never pops another quest's line (got %d foreign)" % pl_foreign)
	spl.queue_free()

	board_scene.queue_free()
	board_scene = null
	content = null
	await process_frame
	await process_frame
	finish()

# Bundle A board-drag feel — the merge-target telegraph (glow + breathe + magnet) and the held-tile lean.
# Drives the real _on_board_input path: press a piece, motion the held tile over a mergeable neighbour
# (telegraph lights), motion onto a non-mergeable cell (telegraph clears), and release (all feel torn down,
# no stuck glow/rotation).
func _test_drag_feel() -> void:
	fresh("drag_feel")
	var b = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(b)
	if b.board == null:
		b._ready()
	# Gather three OPEN, non-generator cells (clearing any item on them), then plant a known MERGEABLE
	# PAIR (two tier-1 starters) and a third non-mergeable item — so a drag from the pair can light then
	# clear the telegraph. (A virgin board is mostly sealed brambles, so empty_ground_cells alone is thin.)
	var empties: Array = []
	for x in range(G.ROWS):
		for y in range(G.COLS):
			var c := Vector2i(x, y)
			if b.board.is_open(c) and not b.board.is_gen(c):
				b.board.take(c)   # clear any seeded item so place() lands cleanly
				empties.append(c)
				if empties.size() >= 3:
					break
		if empties.size() >= 3:
			break
	ok(empties.size() >= 3, "drag-feel test found three open board cells for the pair + a foil")
	if empties.size() < 3:
		b.queue_free()
		return
	var pair_code := 101                       # a tier-1 starter line (tier_of < merge_top → mergeable)
	var foil_code := 201                       # a DIFFERENT line → never merges with the held tile
	var from_cell: Vector2i = empties[0]
	var target_cell: Vector2i = empties[1]
	var foil_cell: Vector2i = empties[2]
	b.board.place(from_cell, pair_code)
	b.board.place(target_cell, pair_code)
	b.board.place(foil_cell, foil_code)
	b._rebuild_pieces()
	ok(b.board.can_merge(from_cell, target_cell), "the planted pair is a valid merge (telegraph precondition)")
	ok(not b.board.can_merge(from_cell, foil_cell), "the foil cell is NOT a valid merge (telegraph must clear over it)")

	var h := Vector2(b.csz, b.csz) / 2.0
	var target_node: Control = b.piece_nodes.get(target_cell)
	var held_node: Control = b.piece_nodes.get(from_cell)
	ok(target_node != null and held_node != null, "the pair rendered piece nodes to telegraph + lean")

	# press the held tile, then motion-follow it over the mergeable TARGET → the telegraph lights.
	_press_emulated(b, b._cell_pos(from_cell) + h)
	ok(b._drag_node == held_node, "pressing the pair tile picks it up for the drag")
	_motion(b, b._cell_pos(target_cell) + h)
	ok(b._telegraph_cell == target_cell, "hovering a mergeable target sets the telegraph cell")
	ok(target_node.modulate.is_equal_approx(FX.Tune.TELEGRAPH_GLOW), "the telegraphed target glows (modulate == TELEGRAPH_GLOW)")
	ok(target_node.has_meta("_fx_breathing"), "the telegraphed target runs a breathe pulse")

	# motion onto the NON-mergeable foil → the telegraph clears (glow + breathe + magnet undone).
	_motion(b, b._cell_pos(foil_cell) + h)
	ok(b._telegraph_cell == Vector2i(-1, -1), "moving onto a non-mergeable cell clears the telegraph cell")
	ok(target_node.modulate.is_equal_approx(Color(1, 1, 1, 1.0)), "the old target's glow is restored on hover-exit")
	ok(target_node.position.is_equal_approx(b._cell_pos(target_cell)), "the old target's magnet offset is undone on hover-exit")

	# horizontal motion tilts the HELD tile (lean), clamped to ±DRAG_LEAN_DEG.
	_motion(b, b._cell_pos(from_cell) + h + Vector2(40, 0))
	_motion(b, b._cell_pos(from_cell) + h + Vector2(120, 0))
	ok(absf(held_node.rotation) > 0.0001, "horizontal drag motion leans the held tile")
	ok(absf(held_node.rotation) <= deg_to_rad(FX.Tune.DRAG_LEAN_DEG) + 0.0001, "the held-tile lean is clamped to DRAG_LEAN_DEG")

	# release on empty ground (a move) → ALL drag feel tears down: telegraph clear, held rotation 0.
	_release_emulated(b, b._cell_pos(foil_cell) + h)   # foil is occupied; release where it began → snap-back
	ok(b._telegraph_cell == Vector2i(-1, -1), "dropping leaves no telegraphed target")
	ok(absf(held_node.rotation) < 0.0001, "dropping resets the held tile's lean to upright")
	ok(target_node.modulate.is_equal_approx(Color(1, 1, 1, 1.0)), "no glow leaks onto the target after the drop")

	b.queue_free()

# --- drag-gesture drivers (emulate_touch_from_mouse: mouse + synth touch per event) ----
func _press_emulated(board, at: Vector2) -> void:
	var md := InputEventMouseButton.new(); md.button_index = MOUSE_BUTTON_LEFT; md.pressed = true; md.position = at
	var td := InputEventScreenTouch.new(); td.pressed = true; td.position = at
	board._on_board_input(md)
	board._on_board_input(td)

func _release_emulated(board, at: Vector2) -> void:
	var mu := InputEventMouseButton.new(); mu.button_index = MOUSE_BUTTON_LEFT; mu.pressed = false; mu.position = at
	var tu := InputEventScreenTouch.new(); tu.pressed = false; tu.position = at
	board._on_board_input(mu)
	board._on_board_input(tu)

func _motion(board, at: Vector2) -> void:
	var mm := InputEventMouseMotion.new(); mm.position = at
	board._on_board_input(mm)

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
