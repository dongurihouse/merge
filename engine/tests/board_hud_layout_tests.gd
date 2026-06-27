extends SceneTree
## Headless guards for the board's workbench-driven HUD layout geometry.
##   godot --headless --path . -s res://engine/tests/board_hud_layout_tests.gd
##
## The board + quest are WIDTH-governed: the 7×9 grid fills the screen width (capped to the
## vertical budget so it never collides with the quest/bottom rows), and the quest band height
## tracks the screen WIDTH too (its cards are 4-across the full width, so a height that ignored
## width would distort them). Both heights therefore "follow" the screen width.

const Save = preload("res://engine/scripts/core/save.gd")
const Kit = preload("res://games/grove/tools/ui_workbench_kit.gd")
const SceneWarm = preload("res://engine/scripts/core/scene_warm.gd")

const BOARD_MARGIN := 6.0   # mirrors board.gd: breathing room each side when width binds

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
	# Headless quirk: the first window resize snaps to a square default; re-apply until it sticks.
	for _i in 8:
		get_root().size = view_size
		await process_frame
		if get_root().size == view_size:
			break
	var board = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(board)
	await process_frame
	await process_frame
	return board

func _free_board(board: Control) -> void:
	get_root().remove_child(board)
	board.free()
	SceneWarm._clear()

# Build the board at a given viewport, snapshot its layout geometry, free it.
func _metrics(view_size: Vector2i) -> Dictionary:
	var board: Control = await _build_board_at(view_size)
	var view: Vector2 = board.get_viewport_rect().size
	var rows: Array = board.giver_bar.find_children("*", "HBoxContainer", true, false)
	var m := {
		"view": view,
		"csz": board.csz,
		"board_total_w": board._board_w() + board.FRAME_OUT * 2.0,
		"quest_h": board.giver_bar.custom_minimum_size.y,
		"row_centered": not rows.is_empty() and (rows[0] as HBoxContainer).alignment == BoxContainer.ALIGNMENT_CENTER,
		# vertical fit: the board frame's bottom must stay above the floating bottom bar's top.
		"center_bottom": board._board_center.get_global_rect().end.y,
		"bar_top": board.bottom_bar.get_global_rect().position.y,
	}
	_free_board(board)
	await process_frame
	return m

func _initialize() -> void:
	print("== Board HUD layout tests ==")
	fresh("screen-width")
	var prior_cfg: Dictionary = Kit.load_config(Kit.CONFIG_PATH)
	var prior_size: Vector2i = get_root().size
	# No bottom_row_h_pct: use the fallback bottom bar (matching the live config), so the vertical
	# budget doesn't eat the board on portrait screens and the WIDTH is what binds.
	Kit._config_cache[Kit.CONFIG_PATH] = {"hud_layout": {
		"button_w_pct": 15, "info_bar_w_pct": 70, "quest_bar_h_pct": 11}}
	var cfg: Dictionary = Kit._config_cache[Kit.CONFIG_PATH]

	# The design aspect (project portrait base). The quest knob is a %-of-height at this aspect.
	var design := Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width", 1080)),
		float(ProjectSettings.get_setting("display/window/size/viewport_height", 1920)))
	var aspect := design.y / design.x

	# Live board instances. NOTE: the headless window can't shrink BELOW the project width, so a
	# genuinely narrow live board isn't testable here — width-scaling is covered by the pure helper
	# below. These use sizes the harness honours: the design width, a wider screen, and a TALLER one
	# (the aspect that overflowed before the fix).
	var m1080: Dictionary = await _metrics(Vector2i(1080, 1920))
	var m1320: Dictionary = await _metrics(Vector2i(1320, 1920))
	var mwide: Dictionary = await _metrics(Vector2i(1600, 1920))
	var mtall: Dictionary = await _metrics(Vector2i(1080, 2400))

	# The original bug: cells were sized from screen HEIGHT only, so the board overflowed the width
	# on taller/narrower aspects. It must now fit the width at every aspect.
	ok(m1080.board_total_w <= m1080.view.x + 1.0 \
		and m1320.board_total_w <= m1320.view.x + 1.0 \
		and mtall.board_total_w <= mtall.view.x + 1.0, \
		"board fits within the screen width at every aspect (no horizontal overflow)")

	# The wide-screen bug: when height binds, the board must fit the space BETWEEN the quest fence
	# and the bottom bar — its frame bottom can't run under the bottom bar (the reported clipping).
	ok(mwide.center_bottom <= mwide.bar_top + 1.0, \
		"board fits vertically above the bottom bar on a wide screen (height-bound, no bottom clip)")
	ok(m1320.center_bottom <= m1320.bar_top + 1.0 and mtall.center_bottom <= mtall.bar_top + 1.0, \
		"board fits vertically above the bottom bar at every aspect")

	# Width binds on portrait screens: the board fills the screen width (minus the side margin),
	# instead of being pinned to a fixed % of screen height.
	ok(absf(m1080.board_total_w - (m1080.view.x - 2.0 * BOARD_MARGIN)) < 3.0 \
		and absf(mtall.board_total_w - (mtall.view.x - 2.0 * BOARD_MARGIN)) < 3.0, \
		"board fills the screen width on portrait screens (width-governed, not a fixed % of height)")

	# Quest band height tracks WIDTH (its 4-across cards scale with width, so the band must too).
	ok(m1320.quest_h > m1080.quest_h + 1.0, "quest band height grows with screen width")
	ok(absf(mtall.quest_h - m1080.quest_h) < 2.0, \
		"quest band height tracks width, not height (unchanged on a taller screen of equal width)")
	ok(absf(m1080.quest_h - 1080.0 * 0.11 * aspect) < 3.0, \
		"quest band height matches the saved percent at the design aspect")

	ok(m1080.row_centered, "quest row centers active cards")

	# The workbench board-frame helper is a pure function — verify width-scaling at any width here,
	# including a genuinely narrow one the live window can't produce.
	var f720: Vector2 = Kit.live_board_frame_size(Vector2(720, 1920), cfg)
	var f1080: Vector2 = Kit.live_board_frame_size(Vector2(1080, 1920), cfg)
	var f1320: Vector2 = Kit.live_board_frame_size(Vector2(1320, 1920), cfg)
	ok(f720.x <= 721.0 and f1080.x <= 1081.0 and f1320.x <= 1321.0, \
		"workbench board helper fits the screen width at every width (no overflow)")
	ok(f720.x < f1080.x and f1080.x <= f1320.x + 0.5, \
		"workbench board helper grows the board with screen width")
	ok(absf(f720.x - (720.0 - 2.0 * BOARD_MARGIN)) < 3.0 and absf(f1080.x - (1080.0 - 2.0 * BOARD_MARGIN)) < 3.0, \
		"workbench board helper fills the width on portrait screens")

	# A live window resize must reflow the board (recompute cell size + quest band), not clip it.
	# Reference: a board built fresh at the target size. Then build at the design size and resize live
	# to the same target — the reflowed geometry must match the fresh build.
	var target := Vector2i(1600, 1920)
	var ref: Dictionary = await _metrics(target)
	var board: Control = await _build_board_at(Vector2i(1080, 1920))
	var csz_before: float = board.csz
	for _i in 8:
		get_root().size = target
		await process_frame
		if get_root().size == target:
			break
	# let the deferred reflow coalesce + run
	await process_frame
	await process_frame
	await process_frame
	ok(absf(board.csz - csz_before) > 1.0, "board cell size changes when the window is resized")
	ok(absf(board.csz - float(ref.csz)) < 2.0, "resized board cell size matches a fresh build at the new size")
	ok(absf(board.giver_bar.custom_minimum_size.y - float(ref.quest_h)) < 2.0, \
		"resized quest band height matches a fresh build at the new size")
	ok((board._board_w() + board.FRAME_OUT * 2.0) <= board.get_viewport_rect().size.x + 1.0, \
		"reflowed board still fits within the screen width")
	_free_board(board)
	await process_frame

	get_root().size = prior_size
	Kit._config_cache[Kit.CONFIG_PATH] = prior_cfg
	SceneWarm._clear()
	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
