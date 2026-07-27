extends "res://games/grove/tests/grove_test_base.gd"
## Grove scene coverage for Soil/Magnet cell improvements.
##   godot --headless --path . -s res://games/grove/tests/grove_improvements_tests.gd

const Improvements = preload("res://engine/scripts/core/improvements.gd")

func _initialize() -> void:
	begin("grove · cell improvements")
	await process_frame
	await _test_scene_builds_first_soil_free()
	await _test_build_mode_pads_only_empty_unsealed_cells()
	await _test_growing_piece_info_row_surfaces_actions()
	await _test_t7_move_requires_soil_reset_confirm()
	await _test_soil_completion_wakes_magnet_and_opens_bramble()
	await _test_soil_ftue_opens_build_mode_once()
	finish()

func _clear_board_model(b: BoardModel) -> void:
	b.gens = {}
	b.gen_tiers = {}
	b.gen_boost = {}
	b.collect_rewards = {}
	b.improvements = {}
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

func _nodes_with_meta(root: Node, key: String) -> Array:
	var out: Array = []
	if root.has_meta(key):
		out.append(root)
	for c in root.get_children():
		out.append_array(_nodes_with_meta(c, key))
	return out

func _test_scene_builds_first_soil_free() -> void:
	fresh("improve_scene_build")
	Save.mark_board_tutorial_seen()
	var scn := _open_board()
	await _settle()
	_clear_board_model(scn.board)
	scn._rebuild_all()
	var cell := Vector2i(3, 3)
	var coins_b := Save.coins()
	ok(scn._build_improvement(cell, Improvements.KIND_SOIL), "scene builds a soil improvement")
	ok(String(scn.board.improvement_at(cell).kind) == Improvements.KIND_SOIL, "the built soil is stored on the board model")
	ok(Save.coins() == coins_b, "the first soil build is free")
	ok(scn.board_area.find_child("ImprovementArt_%d_%d" % [cell.x, cell.y], true, false) != null, "the board renders improvement art after a build")
	scn.queue_free()

func _test_build_mode_pads_only_empty_unsealed_cells() -> void:
	fresh("improve_build_pads")
	Save.mark_board_tutorial_seen()
	var scn := _open_board()
	await _settle()
	_clear_board_model(scn.board)
	var occupied := Vector2i(3, 3)
	var sealed := Vector2i(3, 4)
	scn.board.place(occupied, 101)
	scn.board.terrain[BoardModel.idx(sealed)] = 1
	scn._rebuild_all()
	scn._start_build_mode()
	var pads := _nodes_with_meta(scn.board_area, "improvement_pad")
	var expected := 0
	for r in G.ROWS:
		for c in G.COLS:
			if scn.board.can_build_improvement(Vector2i(r, c)):
				expected += 1
	ok(pads.size() == expected, "build mode creates pads only for empty, unsealed cells")
	for p in pads:
		ok(p.get_meta("cell") != occupied and p.get_meta("cell") != sealed and not scn.board.is_gen(p.get_meta("cell")), "pad is not rendered on an occupied, generator, or sealed cell")
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

func _test_soil_ftue_opens_build_mode_once() -> void:
	fresh("improve_ftue")
	Save.mark_board_tutorial_seen()
	Save.grove()["coins_earned"] = G.coins_at_level(6)
	Save.grove_write()
	var scn := _open_board()
	await _settle()
	ok(Save.ftue_seen("soil"), "level-6 soil FTUE marks its once-only ledger")
	ok(scn._build_mode, "soil FTUE opens build mode")
	ok(scn.build_btn != null and scn.build_btn.visible, "the build button is visible once the soil FTUE has fired")
	scn._exit_build_mode()
	scn._maybe_soil_ftue()
	await _settle()
	ok(not scn._build_mode, "soil FTUE does not re-open once seen")
	scn.queue_free()
