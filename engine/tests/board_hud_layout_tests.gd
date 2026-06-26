extends SceneTree
## Headless guards for the board's workbench-driven HUD layout geometry.
##   godot --headless --path . -s res://engine/tests/board_hud_layout_tests.gd

const Save = preload("res://engine/scripts/core/save.gd")
const Kit = preload("res://games/grove/tools/ui_workbench_kit.gd")
const SceneWarm = preload("res://engine/scripts/core/scene_warm.gd")

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
	var dir := "user://tu_board_hud_layout_" + name + "/"
	if DirAccess.dir_exists_absolute(dir):
		for fn in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir + fn)
	else:
		DirAccess.make_dir_recursive_absolute(dir)
	Save.configure_for_test(dir)

func _build_board_at(view_size: Vector2i) -> Control:
	get_root().size = view_size
	await process_frame
	var board = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(board)
	await process_frame
	await process_frame
	return board

func _free_board(board: Control) -> void:
	get_root().remove_child(board)
	board.free()
	SceneWarm._clear()

func _initialize() -> void:
	print("== Board HUD layout tests ==")
	fresh("screen-height")
	var prior_cfg: Dictionary = Kit.load_config(Kit.CONFIG_PATH)
	var prior_size: Vector2i = get_root().size
	Kit._config_cache[Kit.CONFIG_PATH] = {"hud_layout": {
		"board_h_pct": 48,
		"button_w_pct": 15, "info_bar_w_pct": 70,
		"bottom_row_h_pct": 18, "quest_bar_h_pct": 13}}
	var wide_frame := Kit.live_board_frame_size(Vector2(1080, 1920), Kit._config_cache[Kit.CONFIG_PATH])
	var narrow_frame := Kit.live_board_frame_size(Vector2(720, 1920), Kit._config_cache[Kit.CONFIG_PATH])
	ok(absf(wide_frame.y - 1920.0 * 0.48) < 3.0 and absf(narrow_frame.y - 1920.0 * 0.48) < 3.0, \
		"workbench live board-frame helper keeps board height tied to screen-height percent across widths")

	var board: Control = await _build_board_at(Vector2i(1080, 1920))

	var view: Vector2 = board.get_viewport_rect().size
	ok(absf(board._board_center.custom_minimum_size.y - view.y * 0.48) < 3.0, \
		"board outer height follows hud_layout percent of screen height")
	ok(absf(board.bottom_bar.get_global_rect().size.y - view.y * 0.18) < 3.0, \
		"board bottom row height follows hud_layout percent of screen height")
	ok(absf(board.giver_bar.custom_minimum_size.y - view.y * 0.13) < 3.0, \
		"quest row height follows hud_layout percent of screen height")
	var rows: Array = board.giver_bar.find_children("*", "HBoxContainer", true, false)
	ok(not rows.is_empty() and (rows[0] as HBoxContainer).alignment == BoxContainer.ALIGNMENT_CENTER, \
		"quest row centers active cards")

	_free_board(board)
	await process_frame

	var narrow_board: Control = await _build_board_at(Vector2i(720, 1920))
	var narrow_view: Vector2 = narrow_board.get_viewport_rect().size
	ok(absf(narrow_board._board_center.custom_minimum_size.y - narrow_view.y * 0.48) < 3.0, \
		"board outer height stays screen-height-percent based on a narrower screen")
	ok(absf(narrow_board.giver_bar.custom_minimum_size.y - narrow_view.y * 0.13) < 3.0, \
		"quest row height stays screen-height-percent based on a narrower screen")
	_free_board(narrow_board)
	await process_frame

	get_root().size = prior_size
	Kit._config_cache[Kit.CONFIG_PATH] = prior_cfg
	SceneWarm._clear()
	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
