extends SceneTree
## TEMP probe (real renderer; run via engine/tools/quiet_godot.sh): boot the board, drop a coin,
## perform two REAL taps on it, and print the full decision state at each step. Delete after diagnosis.

const Save = preload("res://engine/scripts/core/save.gd")
const G = preload("res://engine/scripts/core/content.gd")

func _initialize() -> void:
	if not FileAccess.file_exists("res://override.cfg"):
		print("REFUSED: run via engine/tools/quiet_godot.sh")
		quit(2)
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true, 0)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	var dir := "/tmp/tu_tapprobe/"
	if DirAccess.dir_exists_absolute(dir):
		for fn in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir + fn)
	else:
		DirAccess.make_dir_recursive_absolute(dir)
	Save.configure_for_test(dir)

	var scn = load("res://engine/scenes/Board.tscn").instantiate()
	root.add_child(scn)
	current_scene = scn
	await create_timer(0.5).timeout
	scn.rng.seed = 7

	scn.debug_drop_coin()
	await create_timer(0.4).timeout
	var cell := Vector2i(-1, -1)
	for r in G.ROWS:
		for cc in G.COLS:
			var k: int = scn.board.item_at(Vector2i(r, cc))
			if k > 0 and G.is_coin(k):
				cell = Vector2i(r, cc)
	if cell.x < 0:
		print("PROBE: no coin dropped"); quit(); return
	var half := Vector2(scn.csz, scn.csz) / 2.0
	var gat: Vector2 = scn.board_area.get_global_transform() * (scn._cell_pos(cell) + half)
	print("PROBE coin=%s gat=%s csz=%.1f window=%s vp_size=%s stretch_xform=%s" % [
		str(cell), str(gat), scn.csz, str(DisplayServer.window_get_size()),
		str(scn.get_viewport().get_visible_rect().size), str(scn.get_viewport().get_screen_transform())])
	var coins0 := Save.coins()

	print("--- TAP 1 ---")
	_tap(gat)
	await create_timer(0.2).timeout
	print("  after1: selected=%s ring=%s item=%d animating=%s drag=%s" % [
		str(scn._selected_cell), str(scn._focus_ring != null and scn._focus_ring.visible),
		scn.board.item_at(cell), str(scn.animating), str(scn._drag_node)])

	print("--- TAP 2 ---")
	_tap(gat)
	await create_timer(0.2).timeout
	print("  after2: selected=%s ring=%s item=%d coins=%d (was %d) animating=%s" % [
		str(scn._selected_cell), str(scn._focus_ring != null and scn._focus_ring.visible),
		scn.board.item_at(cell), Save.coins(), coins0, str(scn.animating)])
	print("RESULT: %s" % ("COLLECTED" if scn.board.item_at(cell) == 0 and Save.coins() > coins0 else "FAILED TO COLLECT"))
	quit()

func _tap(gpos: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = gpos
	down.global_position = gpos
	root.push_input(down, true)
	var up := down.duplicate()
	up.pressed = false
	root.push_input(up, true)
