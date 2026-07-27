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
	await _test_giver_delivery_requires_t7_soil_reset_confirm()
	await _test_magnet_bramble_open_preserves_rng_state()
	await _test_mark_seen_catches_up_intermediate_tiers()
	await _test_completed_top_soil_refreshes_selected_info()
	await _test_soil_tick_does_not_free_active_drag_node()
	await _test_soil_completion_wakes_magnet_and_opens_bramble()
	await _test_soil_ftue_grants_seed_once()
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
