extends "res://games/grove/tests/grove_test_base.gd"
## Grove scene coverage for Soil/Magnet cell improvements.
##   godot --headless --path . -s res://games/grove/tests/grove_improvements_tests.gd

const Improvements = preload("res://engine/scripts/core/improvements.gd")

func _initialize() -> void:
	begin("grove · cell improvements")
	await process_frame
	await _test_seed_info_bar_places_bags_and_sells()
	await _test_unsocket_info_bar_returns_ranked_seed()
	await _test_growing_piece_info_row_surfaces_actions()
	await _test_growing_piece_keeps_ordinary_actions()
	await _test_normal_drag_to_bag_stashes_without_soil_confirm()
	await _test_second_tap_board_delivery_falls_through_without_soil_confirm()
	await _test_t7_move_requires_soil_reset_confirm()
	await _test_cascade_auto_step_skips_t7_growing_partner()
	await _test_giver_delivery_requires_t7_soil_reset_confirm()
	await _test_scissors_split_requires_soil_reset_confirm()
	await _test_magnet_bramble_open_preserves_rng_state()
	await _test_mark_seen_catches_up_intermediate_tiers()
	await _test_completed_top_soil_refreshes_selected_info()
	await _test_soil_tick_does_not_free_active_drag_node()
	await _test_soil_completion_wakes_magnet_and_opens_bramble()
	await _test_soil_ftue_grants_seed_once()
	await _test_soil_ftue_waits_when_seed_has_no_destination()
	await _test_improvements_flag_blocks_seed_drops()
	await _test_bagged_soil_seed_survives_the_round_trip()
	await _test_bagged_soil_rank_survives_save_and_load()
	await _test_bag_removal_keeps_every_slot_with_its_own_rank()
	await _test_rank_one_and_magnet_seeds_store_nothing()
	await _test_scissors_bag_fallback_keeps_arrays_aligned()
	await _test_growing_countdown_chip_stays_inside_its_cell()
	finish()

func _clear_board_model(b: BoardModel) -> void:
	b.gens = {}
	b.gen_tiers = {}
	b.gen_boost = {}
	b.collect_rewards = {}
	b.improvements = {}
	b.seed_ranks = {}
	for i in b.items.size():
		b.terrain[i] = 0
		b.items[i] = 0

func _open_board() -> Node:
	var scn = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(scn)
	if scn.board == null:
		scn._ready()
	return scn

func _settle() -> void:
	await process_frame
	await process_frame

func _cell_center(scn: Node, cell: Vector2i) -> Vector2:
	return scn._cell_pos(cell) + Vector2(scn.csz, scn.csz) * 0.5

func _mark_cell_growing(scn: Node, cell: Vector2i, code: int, seconds_left: float = 3600.0) -> void:
	ok(scn.board.build_improvement(cell, Improvements.KIND_SOIL), "fixture installs Soil under %s" % cell)
	scn.board.place(cell, code)
	var row: Dictionary = scn.board.improvement_at(cell)
	row["code"] = code
	row["ends_at"] = Time.get_unix_time_from_system() + seconds_left
	scn.board.improvements[cell] = row

func _board_tap(scn: Node, cell: Vector2i) -> void:
	var pos := _cell_center(scn, cell)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = pos
	scn._on_board_input(down)
	var up := down.duplicate()
	up.pressed = false
	scn._on_board_input(up)

func _drag_board_item_to_bag(scn: Node, cell: Vector2i) -> void:
	var start := _cell_center(scn, cell)
	var bag_global: Vector2 = scn.bag_btn.get_global_rect().get_center()
	var bag_local: Vector2 = scn.board_area.get_global_transform().affine_inverse() * bag_global
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = start
	scn._on_board_input(down)
	var move := InputEventMouseMotion.new()
	move.position = bag_local
	scn._on_board_input(move)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = bag_global
	scn._input(up)

func _nodes_with_meta(root: Node, key: String) -> Array:
	var out: Array = []
	if root.has_meta(key):
		out.append(root)
	for c in root.get_children():
		out.append_array(_nodes_with_meta(c, key))
	return out

func _test_seed_info_bar_places_bags_and_sells() -> void:
	fresh("improve_scene_seed_actions")
	Save.mark_board_tutorial_seen()
	Save.add_coins(2000)
	var scn := _open_board()
	await _settle()
	_clear_board_model(scn.board)
	var soil := Vector2i(3, 3)
	scn.board.place(soil, Improvements.seed_code_for_kind(Improvements.KIND_SOIL))
	scn.board.set_seed_rank(soil, 2)
	scn._rebuild_all()
	var coins_b := Save.coins()
	scn._select_item(soil)
	ok(scn._info_seed_place != null and scn._info_seed_place.visible, "a selected seed shows the Place chip")
	ok(scn._info_seed_bag != null and scn._info_seed_bag.visible, "a selected seed shows the Bag chip")
	ok(scn._info_trash != null and scn._info_trash.visible, "a selected seed remains sellable")
	ok(scn._info_buy == null or not scn._info_buy.visible, "a seed is not buyable as a copy")
	ok(scn._place_seed(soil), "scene Place action installs the seed as a cell improvement")
	ok(Save.coins() == coins_b, "placing a seed is free")
	ok(scn.board.item_at(soil) == 0 and String(scn.board.improvement_at(soil).kind) == Improvements.KIND_SOIL and int(scn.board.improvement_at(soil).rank) == 2, "placed seed consumes the item and carries Soil rank")
	ok(scn.board_area.find_child("ImprovementArt_%d_%d" % [soil.x, soil.y], true, false) != null, "the board renders improvement art after seed placement")

	var bag_cell := Vector2i(3, 4)
	scn.board.place(bag_cell, Improvements.seed_code_for_kind(Improvements.KIND_SOIL))
	scn.board.set_seed_rank(bag_cell, 3)
	scn._rebuild_all()
	scn._select_item(bag_cell)
	scn._on_seed_bag()
	ok(scn.bag.size() == 1 and int(scn.bag[0]) == Improvements.seed_code_for_kind(Improvements.KIND_SOIL), "the seed Bag chip stashes the seed")
	ok(scn.bag_seed_ranks.size() == 1 and int(scn.bag_seed_ranks[0]) == 3, "bagged Soil seed keeps its rank metadata")
	ok(scn.board.item_at(bag_cell) == 0, "bagging a seed removes it from the board")

	var sell_cell := Vector2i(3, 5)
	scn.board.place(sell_cell, Improvements.seed_code_for_kind(Improvements.KIND_MAGNET))
	scn._rebuild_all()
	scn._select_item(sell_cell)
	var coins_before_sell := Save.coins()
	scn._on_trash_pressed()
	ok(Save.coins() == coins_before_sell + 1000 and scn.board.item_at(sell_cell) == 0, "selling a magnet seed pays its seed sell value")
	scn.queue_free()

func _test_unsocket_info_bar_returns_ranked_seed() -> void:
	fresh("improve_unsocket")
	Save.mark_board_tutorial_seen()
	Save.add_coins(500)
	var scn := _open_board()
	await _settle()
	_clear_board_model(scn.board)
	var cell := Vector2i(3, 3)
	ok(scn.board.build_improvement(cell, Improvements.KIND_SOIL, 3), "test setup installs ranked soil")
	scn._rebuild_all()
	_board_tap(scn, cell)
	ok(scn._info_unsocket != null and scn._info_unsocket.visible, "empty improved cell selection shows Unsocket")
	ok(scn._info_soil_rank != null and scn._info_soil_rank.visible, "empty Soil cell selection shows the Rank chip")
	var coins_b := Save.coins()
	scn._on_unsocket_improvement()
	ok(Save.coins() == coins_b - 100, "unsocketing Soil charges the unsocket coin cost")
	ok(not scn.board.has_improvement(cell) and scn.board.item_at(cell) == Improvements.seed_code_for_kind(Improvements.KIND_SOIL), "Unsocket returns a seed to the same cell")
	ok(scn.board.seed_rank_at(cell) == 3, "Unsocket keeps the Soil rank on the returned seed")
	scn.queue_free()

func _test_growing_piece_info_row_surfaces_actions() -> void:
	fresh("improve_info_row")
	Save.mark_board_tutorial_seen()
	Save.add_diamonds(20)
	var scn := _open_board()
	await _settle()
	_clear_board_model(scn.board)
	var cell := Vector2i(2, 2)
	scn.board.build_improvement(cell, Improvements.KIND_SOIL)
	scn.board.place(cell, 107)
	scn.board.reconcile_improvements(1000.0)
	scn._rebuild_all()
	scn._select_item(cell)
	ok(scn._info_label.text.begins_with("Growing to t8"), "selecting a growing piece names the next tier in the info tray")
	ok(scn._info_soil_water != null and scn._info_soil_water.visible, "the water chip is visible for a growing piece")
	ok(scn._info_soil_finish != null and scn._info_soil_finish.visible, "the acorn finish chip is visible for a growing piece")
	scn.queue_free()

func _test_growing_piece_keeps_ordinary_actions() -> void:
	fresh("improve_growing_actions")
	Save.mark_board_tutorial_seen()
	Save.add_coins(100000)
	Save.add_diamonds(100)
	var scn := _open_board()
	await _settle()
	_clear_board_model(scn.board)
	var cell := Vector2i(2, 2)
	scn.board.build_improvement(cell, Improvements.KIND_SOIL)
	scn.board.place(cell, 107)
	var row: Dictionary = scn.board.improvement_at(cell)
	row["code"] = 107
	row["ends_at"] = Time.get_unix_time_from_system() + 3600.0
	scn.board.improvements[cell] = row
	scn._rebuild_all()
	scn._select_item(cell)
	ok(scn._info_soil_water != null and scn._info_soil_water.visible, "growing piece still shows the soil water action")
	ok(scn._info_soil_finish != null and scn._info_soil_finish.visible, "growing piece still shows the soil finish action")
	ok(scn._info_trash != null and scn._info_trash.visible, "growing piece remains sellable through the info bar")
	ok(scn._info_buy != null and scn._info_buy.visible, "growing piece remains buyable through the info bar")
	scn.queue_free()

func _test_normal_drag_to_bag_stashes_without_soil_confirm() -> void:
	fresh("improve_stash_fallthrough")
	Save.mark_board_tutorial_seen()
	var scn := _open_board()
	await _settle()
	_clear_board_model(scn.board)
	var cell := Vector2i(2, 2)
	scn.board.place(cell, 101)
	scn._rebuild_all()
	_drag_board_item_to_bag(scn, cell)
	ok(scn.bag.size() == 1 and int(scn.bag[0]) == 101, "dragging a normal item onto the bag stashes it when no Soil confirmation is needed")
	ok(scn.board.item_at(cell) == 0, "drag-to-bag removes the stashed item from the board")
	scn.queue_free()

func _test_second_tap_board_delivery_falls_through_without_soil_confirm() -> void:
	fresh("improve_second_tap_delivery")
	Save.mark_board_tutorial_seen()
	var scn := _open_board()
	await _settle()
	_clear_board_model(scn.board)
	var cell := Vector2i(2, 2)
	var chip := Control.new()
	scn.add_child(chip)
	scn.board.place(cell, 104)
	scn.quests = [{"line": 1, "tier": 4, "reward": {"coins": 7}}]
	scn.giver_chips = [{"qi": 0, "chip": chip}]
	scn._rebuild_all()
	scn.giver_chips = [{"qi": 0, "chip": chip}]
	var coins_before := Save.coins()
	_board_tap(scn, cell)
	_board_tap(scn, cell)
	ok(scn.board.item_at(cell) == 0, "second-tapping a focused asked board item delivers it when no Soil confirmation is needed")
	ok(Save.coins() == coins_before + 7, "second-tap board delivery pays the quest reward")
	scn.queue_free()

func _test_t7_move_requires_soil_reset_confirm() -> void:
	fresh("improve_t7_confirm")
	Save.mark_board_tutorial_seen()
	var scn := _open_board()
	await _settle()
	_clear_board_model(scn.board)
	var src := Vector2i(2, 2)
	var dst := Vector2i(2, 3)
	scn.board.build_improvement(src, Improvements.KIND_SOIL)
	scn.board.place(src, 107)
	var row: Dictionary = scn.board.improvement_at(src)
	row["code"] = 107
	row["ends_at"] = Time.get_unix_time_from_system() + 3600.0
	scn.board.improvements[src] = row
	scn._rebuild_all()
	scn._commit_move(src, dst, scn.piece_nodes[src])
	ok(scn.board.item_at(src) == 107 and scn.board.item_at(dst) == 0, "moving a t7+ growing piece waits for confirmation")
	ok(scn.get_node_or_null("SoilResetConfirm") != null, "t7+ reset warning is shown before the move")
	scn.queue_free()

func _test_cascade_auto_step_skips_t7_growing_partner() -> void:
	fresh("improve_cascade_t7_guard")
	Save.mark_board_tutorial_seen()
	var scn := _open_board()
	await _settle()
	_clear_board_model(scn.board)
	var a := Vector2i(2, 1)
	var b := Vector2i(2, 2)
	var growing_partner := Vector2i(2, 3)
	scn.board.place(a, 106)
	scn.board.place(b, 106)
	_mark_cell_growing(scn, growing_partner, 107, 8.0 * 3600.0)
	scn._rebuild_all()
	var half := Vector2(scn.csz, scn.csz) / 2.0
	scn._on_press(scn._cell_pos(a) + half)
	scn._on_release(scn._cell_pos(b) + half)
	await create_timer(0.7).timeout
	ok(scn.board.item_at(b) == 107 and scn.board.item_at(growing_partner) == 107,
		"a cascade auto-step does not consume a t7+ growing partner")
	ok(scn.board.is_growing(growing_partner), "the skipped t7 partner keeps its Soil growth progress")
	ok(scn.get_node_or_null("SoilResetConfirm") == null, "auto-cascade does not pop a destructive Soil confirm mid-run")
	scn.queue_free()

func _test_giver_delivery_requires_t7_soil_reset_confirm() -> void:
	fresh("improve_giver_t7_confirm")
	Save.mark_board_tutorial_seen()
	var scn := _open_board()
	await _settle()
	_clear_board_model(scn.board)
	var cell := Vector2i(2, 2)
	scn.board.build_improvement(cell, Improvements.KIND_SOIL)
	scn.board.place(cell, 107)
	var row: Dictionary = scn.board.improvement_at(cell)
	row["code"] = 107
	row["ends_at"] = Time.get_unix_time_from_system() + 8.0 * 3600.0
	scn.board.improvements[cell] = row
	scn.quests = [{"line": 1, "tier": 7, "reward": {"coins": 0}}]
	var chip := Control.new()
	scn.add_child(chip)
	scn._on_giver_tap(0, chip)
	ok(scn.board.item_at(cell) == 107, "giver-tap delivery waits before consuming a t7+ growing piece")
	ok(scn.get_node_or_null("SoilResetConfirm") != null, "giver-tap delivery shows the t7+ Soil reset warning")
	scn.queue_free()

func _test_scissors_split_requires_soil_reset_confirm() -> void:
	fresh("improve_scissors_t7_confirm")
	Save.mark_board_tutorial_seen()
	var scn := _open_board()
	await _settle()
	_clear_board_model(scn.board)
	var scissors := Vector2i(1, 1)
	var target := Vector2i(2, 2)
	scn.board.place(scissors, G.SCISSORS_LINE * 100 + 1)
	_mark_cell_growing(scn, target, 107, 8.0 * 3600.0)
	scn._rebuild_all()
	scn._split_piece(scissors, target, scn.piece_nodes[scissors])
	ok(scn.board.item_at(scissors) == G.SCISSORS_LINE * 100 + 1 and scn.board.item_at(target) == 107,
		"scissors waits for confirmation before splitting a t7+ growing piece")
	ok(scn.board.is_growing(target), "the refused scissors split keeps the target's Soil growth progress")
	ok(scn.get_node_or_null("SoilResetConfirm") != null, "scissors split shows the t7+ Soil reset warning")
	scn.queue_free()

func _test_magnet_bramble_open_preserves_rng_state() -> void:
	fresh("improve_magnet_rng")
	Save.mark_board_tutorial_seen()
	Save.grove()["coins_earned"] = G.coins_at_level(20)
	Save.grove_write()
	var scn := _open_board()
	await _settle()
	_clear_board_model(scn.board)
	var magnet := Vector2i(4, 4)
	var src := Vector2i(3, 3)
	var dst := Vector2i(3, 4)
	var bramble := Vector2i(3, 5)
	scn.board.build_improvement(magnet, Improvements.KIND_MAGNET)
	scn.board.place(src, 101)
	scn.board.place(dst, 101)
	scn.board.terrain[BoardModel.idx(bramble)] = 1
	scn.quests = [{"line": 1, "tier": 9, "reward": {"coins": 1}}]
	scn.rng.state = 2874604287823932276
	var before: int = scn.rng.state
	ok(scn._scan_magnets(true), "magnet scan performs the auto-merge that opens a bramble")
	ok(scn.board.is_open(bramble), "magnet auto-merge opens the eligible neighbouring bramble")
	ok(scn.rng.state == before, "magnet-triggered bramble opening preserves rng.state byte-identity")
	scn.queue_free()

func _test_mark_seen_catches_up_intermediate_tiers() -> void:
	fresh("improve_seen_catchup")
	Save.mark_board_tutorial_seen()
	var scn := _open_board()
	await _settle()
	scn._mark_seen(104)
	var seen: Dictionary = Save.grove().get("seen", {})
	ok(seen.has("101") and seen.has("102") and seen.has("103") and seen.has("104"), "marking a higher discovered tier catches up every intermediate tier")
	scn.queue_free()

func _test_completed_top_soil_refreshes_selected_info() -> void:
	fresh("improve_top_info_refresh")
	Save.mark_board_tutorial_seen()
	var scn := _open_board()
	await _settle()
	_clear_board_model(scn.board)
	var cell := Vector2i(2, 2)
	var top := int(G.merge_top(101))
	var code := 100 + top - 1
	scn.board.build_improvement(cell, Improvements.KIND_SOIL)
	scn.board.place(cell, code)
	var row: Dictionary = scn.board.improvement_at(cell)
	row["code"] = code
	row["ends_at"] = Time.get_unix_time_from_system() + 10.0
	scn.board.improvements[cell] = row
	scn._rebuild_all()
	scn._select_item(cell)
	ok(scn._info_label.text.begins_with("Growing to t%d" % top), "test setup selects a growing top-step item")
	row = scn.board.improvement_at(cell)
	row["ends_at"] = Time.get_unix_time_from_system() - 1.0
	scn.board.improvements[cell] = row
	scn._tick_water()
	ok(scn.board.item_at(cell) == 100 + top, "soil tick completes the selected item to merge_top")
	ok(not scn._info_label.text.begins_with("Growing"), "selected info refreshes when Soil completes at merge_top")
	ok(scn._info_soil_water == null or not scn._info_soil_water.visible, "soil water chip hides after the selected item stops growing")
	scn.queue_free()

func _test_soil_tick_does_not_free_active_drag_node() -> void:
	fresh("improve_tick_drag_safe")
	Save.mark_board_tutorial_seen()
	var scn := _open_board()
	await _settle()
	_clear_board_model(scn.board)
	var drag_cell := Vector2i(2, 2)
	var soil_cell := Vector2i(3, 3)
	scn.board.place(drag_cell, 101)
	scn.board.build_improvement(soil_cell, Improvements.KIND_SOIL)
	scn.board.place(soil_cell, 101)
	var row: Dictionary = scn.board.improvement_at(soil_cell)
	row["code"] = 101
	row["ends_at"] = Time.get_unix_time_from_system() - 1.0
	scn.board.improvements[soil_cell] = row
	scn._rebuild_all()
	var start := _cell_center(scn, drag_cell)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = start
	scn._on_board_input(down)
	var move := InputEventMouseMotion.new()
	move.position = start + Vector2(scn._drag_slop_px() + 8.0, 0.0)
	scn._on_board_input(move)
	ok(scn._drag_node != null, "test setup has an active drag node")
	scn._tick_water()
	ok(scn._drag_node != null and is_instance_valid(scn._drag_node) and not scn._drag_node.is_queued_for_deletion(), "soil tick does not queue-free the held tile mid-drag")
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = scn.board_area.get_global_transform() * move.position
	scn._input(up)
	scn.queue_free()

func _test_soil_completion_wakes_magnet_and_opens_bramble() -> void:
	fresh("improve_soil_magnet_tick")
	Save.mark_board_tutorial_seen()
	Save.grove()["coins_earned"] = G.coins_at_level(20)
	Save.grove_write()
	var scn := _open_board()
	await _settle()
	_clear_board_model(scn.board)
	var magnet := Vector2i(4, 4)
	var soil := Vector2i(1, 1)
	var pair_a := Vector2i(3, 3)
	var mate := Vector2i(3, 4)
	var bramble := Vector2i(3, 5)
	scn.board.build_improvement(magnet, Improvements.KIND_MAGNET)
	scn.board.build_improvement(soil, Improvements.KIND_SOIL)
	scn.board.place(soil, 101)
	scn.board.place(pair_a, 101)
	scn.board.place(mate, 101)
	scn.board.terrain[BoardModel.idx(bramble)] = 1
	var row: Dictionary = scn.board.improvement_at(soil)
	row["code"] = 101
	row["ends_at"] = Time.get_unix_time_from_system() - 1.0
	scn.board.improvements[soil] = row
	scn._rebuild_all()
	scn._tick_water()
	ok(scn.board.item_at(mate) == 102 and scn.board.item_at(pair_a) == 0, "soil completion wakes pending magnet auto-merge on the same tick")
	ok(scn.board.is_open(bramble), "magnet auto-merge still opens eligible neighbouring brambles")
	scn.queue_free()

func _test_soil_ftue_grants_seed_once() -> void:
	fresh("improve_ftue")
	Save.mark_board_tutorial_seen()
	Save.grove()["coins_earned"] = G.coins_at_level(6)
	Save.grove_write()
	var scn := _open_board()
	await _settle()
	ok(Save.ftue_seen("soil"), "level-6 soil FTUE marks its once-only ledger")
	var seed_cell: Vector2i = scn.board.first_item_of(Improvements.seed_code_for_kind(Improvements.KIND_SOIL))
	ok(seed_cell.x >= 0, "soil FTUE grants a deterministic Soil seed on the board")
	ok(_nodes_with_meta(scn, "improvement_build_button").is_empty(), "soil FTUE does not show a build-mode button")
	ok(_nodes_with_meta(scn.board_area, "improvement_pad").is_empty(), "soil FTUE does not render build pads")
	ok(scn._hand_hint != null and is_instance_valid(scn._hand_hint), "soil FTUE points the hand hint at the seed")
	scn._maybe_soil_ftue()
	await _settle()
	ok(scn.board.count_of(Improvements.seed_code_for_kind(Improvements.KIND_SOIL)) == 1, "soil FTUE does not grant a second seed once seen")
	scn.queue_free()

func _test_soil_ftue_waits_when_seed_has_no_destination() -> void:
	fresh("improve_ftue_no_destination")
	Save.mark_board_tutorial_seen()
	Save.grove()["coins_earned"] = G.coins_at_level(6)
	Save.grove_write()
	var scn := _open_board()
	_clear_board_model(scn.board)
	for i in scn.board.items.size():
		scn.board.items[i] = 101
	scn.bag = []
	scn.bag_seed_ranks = []
	for _i in scn._bag_capacity():
		scn._bag_append(101)
	scn._rebuild_all()
	await _settle()
	var soil_seed := Improvements.seed_code_for_kind(Improvements.KIND_SOIL)
	ok(not Save.ftue_seen("soil"), "soil FTUE stays retryable when the board and bag have no seed destination")
	ok(scn.board.first_item_of(soil_seed).x < 0 and not scn.bag.has(soil_seed), "soil FTUE does not fake a seed grant when there is no room")
	scn._bag_remove_at(scn.bag.size() - 1)
	scn._maybe_soil_ftue()
	await _settle()
	ok(Save.ftue_seen("soil") and scn.bag.has(soil_seed), "soil FTUE marks seen once a later retry can grant the seed")
	scn.queue_free()

func _test_improvements_flag_blocks_seed_drops() -> void:
	var original := bool(Feat.FLAGS.get("improvements", true))
	Feat.FLAGS["improvements"] = false
	fresh("improve_flag_drop_gate")
	var scn := _open_board()
	await _settle()
	var blocked: Array = scn._blocked_seed_drop_lines()
	ok(blocked.has(Improvements.seed_line_for_kind(Improvements.KIND_SOIL)) \
		and blocked.has(Improvements.seed_line_for_kind(Improvements.KIND_MAGNET)), \
		"improvements flag OFF blocks both improvement seed pseudo-lines")
	var saw_seed := false
	var rng := RandomNumberGenerator.new()
	for seed in range(1, 80):
		rng.seed = seed
		if Improvements.is_seed(G.pick_special_drop(rng, blocked)):
			saw_seed = true
			break
	ok(not saw_seed, "improvements flag OFF keeps special-drop rolls from producing seed items")
	scn.queue_free()
	Feat.FLAGS["improvements"] = original

# --- the bag carries Soil rank ---------------------------------------------------
# bag_seed_ranks is PARALLEL to bag (invariant: equal sizes), the same shape gen_bag_tiers /
# gen_bag_boost use for generators. These four cover the invariant end to end: the live round
# trip, the save/load round trip, per-slot identity across a removal, and the sparse default.

# The bag's parallel-array invariant. An off-by-one here hands a seed the WRONG rank, so every
# bag test asserts it rather than only the value it cares about.
func _bag_arrays_aligned(scn: Node) -> bool:
	return scn.bag.size() == scn.bag_seed_ranks.size()

func _test_bagged_soil_seed_survives_the_round_trip() -> void:
	fresh("improve_bag_rank_round_trip")
	Save.mark_board_tutorial_seen()
	Save.add_coins(500)
	var scn := _open_board()
	await _settle()
	_clear_board_model(scn.board)
	var cell := Vector2i(3, 3)
	ok(scn.board.build_improvement(cell, Improvements.KIND_SOIL, 3), "test setup installs rank-3 soil")
	scn._rebuild_all()
	_board_tap(scn, cell)
	scn._on_unsocket_improvement()
	scn._rebuild_all()
	ok(scn.board.seed_rank_at(cell) == 3, "unsocket leaves a rank-3 seed on the cell")
	scn._select_item(cell)
	scn._on_seed_bag()
	ok(_bag_arrays_aligned(scn), "stashing a seed keeps bag_seed_ranks the same size as bag")
	ok(scn.bag.size() == 1 and int(scn.bag_seed_ranks[0]) == 3, "the bagged seed carries rank 3")
	var back := Vector2i(4, 4)
	ok(scn._retrieve_from_bag(0, back), "the bagged seed pulls back onto an empty cell")
	ok(_bag_arrays_aligned(scn), "pulling a seed back keeps bag_seed_ranks the same size as bag")
	ok(scn.board.seed_rank_at(back) == 3, "the pulled-back seed still reports rank 3")
	ok(scn._place_seed(back), "the pulled-back seed places as a cell improvement")
	ok(int(scn.board.improvement_at(back).rank) == 3, "unsocket → bag → pull back → Place keeps Soil rank 3")
	scn.queue_free()

func _test_bagged_soil_rank_survives_save_and_load() -> void:
	fresh("improve_bag_rank_save_load")
	Save.mark_board_tutorial_seen()
	var scn := _open_board()
	await _settle()
	_clear_board_model(scn.board)
	var cell := Vector2i(2, 2)
	scn.board.place(cell, Improvements.seed_code_for_kind(Improvements.KIND_SOIL))
	scn.board.set_seed_rank(cell, 3)
	scn._rebuild_all()
	scn._select_item(cell)
	scn._on_seed_bag()
	ok(scn.bag.size() == 1 and int(scn.bag_seed_ranks[0]) == 3, "test setup parks a rank-3 seed in the bag")
	scn._persist()
	Save.save_now()
	scn.queue_free()
	await _settle()

	Save.load_now()                            # a real restart: re-parsed from the JSON on disk
	var scn2 := _open_board()
	await _settle()
	ok(_bag_arrays_aligned(scn2), "a loaded bag keeps bag_seed_ranks the same size as bag")
	ok(scn2.bag.size() == 1 and int(scn2.bag_seed_ranks[0]) == 3, "the bagged seed's rank survives save + load")
	var back := Vector2i(4, 2)
	ok(scn2._retrieve_from_bag(0, back), "the reloaded bagged seed pulls back onto an empty cell")
	ok(scn2.board.seed_rank_at(back) == 3, "the reloaded seed still reports rank 3")
	ok(scn2._place_seed(back), "the reloaded seed places as a cell improvement")
	ok(int(scn2.board.improvement_at(back).rank) == 3, "bag → save → load → pull back → Place keeps Soil rank 3")
	scn2.queue_free()

	# An OLD save (a bag, no bag_seed_ranks key at all) must load as rank 1, never crash.
	var g := Save.grove()
	g["bag"] = [Improvements.seed_code_for_kind(Improvements.KIND_SOIL), 101]
	g.erase("bag_seed_ranks")
	Save.grove_write()
	var scn3 := _open_board()
	await _settle()
	ok(_bag_arrays_aligned(scn3), "a pre-rank save loads with the parallel arrays aligned")
	ok(scn3.bag.size() == 2 and int(scn3.bag_seed_ranks[0]) == 1, "a bagged seed from a pre-rank save defaults to rank 1")
	scn3.queue_free()

func _test_bag_removal_keeps_every_slot_with_its_own_rank() -> void:
	fresh("improve_bag_slot_integrity")
	Save.mark_board_tutorial_seen()
	var scn := _open_board()
	await _settle()
	_clear_board_model(scn.board)
	var soil_code := Improvements.seed_code_for_kind(Improvements.KIND_SOIL)
	var a := Vector2i(1, 1)
	var b := Vector2i(1, 2)
	var c := Vector2i(1, 3)
	scn.board.place(a, soil_code)
	scn.board.set_seed_rank(a, 3)
	scn.board.place(b, 101)                    # a plain item between the two ranked seeds
	scn.board.place(c, soil_code)
	scn.board.set_seed_rank(c, 2)
	scn._rebuild_all()
	for cell in [a, b, c]:
		scn._select_item(cell)
		scn._on_seed_bag()
	ok(scn.bag.size() == 3 and _bag_arrays_aligned(scn), "test setup bags [rank-3 seed, plain item, rank-2 seed]")
	ok(scn._bag_seed_rank_at(0) == 3 and scn._bag_seed_rank_at(2) == 2, "each bagged seed starts on its own rank")

	var mid := Vector2i(5, 5)
	ok(scn._retrieve_from_bag(1, mid), "the middle bag entry pulls back out")
	ok(_bag_arrays_aligned(scn), "removing a middle bag entry keeps the parallel arrays aligned")
	ok(scn.bag.size() == 2 and int(scn.bag[0]) == soil_code and int(scn.bag[1]) == soil_code, "the two seeds are what is left in the bag")
	ok(scn._bag_seed_rank_at(0) == 3, "the first seed keeps ITS rank after the middle entry is removed")
	ok(scn._bag_seed_rank_at(1) == 2, "the second seed keeps ITS rank after the middle entry is removed")
	var back := Vector2i(5, 6)
	ok(scn._retrieve_from_bag(1, back) and scn.board.seed_rank_at(back) == 2, "the shifted seed pulls back on rank 2, not its neighbour's rank")
	scn.queue_free()

func _test_rank_one_and_magnet_seeds_store_nothing() -> void:
	fresh("improve_bag_sparse_ranks")
	Save.mark_board_tutorial_seen()
	var scn := _open_board()
	await _settle()
	_clear_board_model(scn.board)
	var plain := Vector2i(2, 1)
	var magnet := Vector2i(2, 2)
	scn.board.place(plain, Improvements.seed_code_for_kind(Improvements.KIND_SOIL))
	scn.board.place(magnet, Improvements.seed_code_for_kind(Improvements.KIND_MAGNET))
	scn._rebuild_all()
	for cell in [plain, magnet]:
		scn._select_item(cell)
		scn._on_seed_bag()
	ok(scn.bag.size() == 2 and _bag_arrays_aligned(scn), "a rank-1 seed and a magnet seed both bag cleanly")
	ok(int(scn.bag_seed_ranks[0]) == 1 and int(scn.bag_seed_ranks[1]) == 1, "neither stores a rank above the default")
	var back_a := Vector2i(6, 1)
	var back_b := Vector2i(6, 2)
	ok(scn._retrieve_from_bag(0, back_a) and scn._retrieve_from_bag(0, back_b), "both pull back out of the bag")
	ok(scn.board.seed_rank_at(back_a) == 1 and scn.board.seed_rank_at(back_b) == 1, "both come back on rank 1")
	ok(scn.board.seed_ranks.is_empty(), "rank-1 and non-Soil seeds store NOTHING (the sparse convention)")
	ok(scn.bag.is_empty() and scn.bag_seed_ranks.is_empty(), "emptying the bag empties its parallel rank array")
	scn.queue_free()

# The scissors tool falls back into the bag when the board has no free ground. That append must go
# through _bag_append like every other one — a raw bag.append() leaves bag_seed_ranks one short, and
# then the NEXT stashed seed reads its rank off the end of the array and silently arrives as rank 1.
func _test_scissors_bag_fallback_keeps_arrays_aligned() -> void:
	fresh("improve_bag_scissors_align")
	Save.mark_board_tutorial_seen()
	var scn := _open_board()
	await _settle()
	_clear_board_model(scn.board)
	var seed_cell := Vector2i(0, 0)
	for i in scn.board.items.size():
		scn.board.items[i] = 101               # fill every cell: no empty ground for the tool to land on
	scn.board.place(seed_cell, Improvements.seed_code_for_kind(Improvements.KIND_SOIL))
	scn.board.set_seed_rank(seed_cell, 3)
	scn._rebuild_all()
	ok(scn.board.empty_ground_cells().is_empty(), "test setup leaves the board with no empty ground")
	ok(scn._place_scissors_tool(true), "a full board sends the scissors tool into the bag instead")
	ok(_bag_arrays_aligned(scn), "the scissors bag fallback keeps bag_seed_ranks aligned with bag")
	scn._select_item(seed_cell)
	scn._on_seed_bag()
	ok(scn.bag.size() == 2 and _bag_arrays_aligned(scn), "a ranked seed still bags in behind the scissors tool")
	ok(scn._bag_seed_rank_at(1) == 3, "a seed bagged AFTER the scissors tool keeps its own rank 3")
	scn.queue_free()

# The growing-piece countdown chip used to be hand-placed at (0.56·csz, -0.05·csz), which hung a
# ~72px chip past the cell's right edge and 6px ABOVE its top — it clipped into the neighbouring
# cell above. Measured on the built node, at the WIDEST label the chip ever renders.
func _test_growing_countdown_chip_stays_inside_its_cell() -> void:
	fresh("improve_countdown_chip_bounds")
	Save.mark_board_tutorial_seen()
	var scn := _open_board()
	await _settle()
	_clear_board_model(scn.board)
	var now := Time.get_unix_time_from_system()
	var cases := [
		[Vector2i(3, 1), 106, 1, 2160.0],       # "36m"
		[Vector2i(3, 3), 108, 3, 183600.0],     # a multi-day remaining — the widest label
	]
	for c in cases:
		var cell: Vector2i = c[0]
		scn.board.build_improvement(cell, Improvements.KIND_SOIL, int(c[2]))
		scn.board.place(cell, int(c[1]))
		var row: Dictionary = scn.board.improvement_at(cell)
		row["code"] = int(c[1])
		row["ends_at"] = now + float(c[3])
		scn.board.improvements[cell] = row
	scn._rebuild_all()
	await _settle()
	for c in cases:
		var cell: Vector2i = c[0]
		var ov: Control = scn.board_area.get_node_or_null("SoilProgress_%d_%d" % [cell.x, cell.y])
		ok(ov != null, "cell %s renders its soil progress overlay" % cell)
		if ov == null:
			continue
		var chip: Control = ov.get_node_or_null("SoilTimeChip")
		ok(chip != null, "cell %s renders its countdown chip" % cell)
		if chip == null:
			continue
		var cell_rect := Rect2(scn._cell_pos(cell), Vector2(scn.csz, scn.csz))
		var chip_rect := Rect2(ov.position + chip.position, chip.size)
		ok(cell_rect.encloses(chip_rect), "the \"%s\" countdown chip stays inside its own cell (cell %s, chip %s)" % [(chip.get_child(0) as Label).text, cell_rect, chip_rect])
	scn.queue_free()
