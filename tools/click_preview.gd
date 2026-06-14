extends SceneTree
## V3 proof (run via tools/quiet_godot.sh): the locked-generator preview is REAL
## input, not just a drawn silhouette. Open a path to a line-3 (compost) edge
## bramble so the compost preview shows, then drive a REAL tap (Input.parse_input_event)
## on the silhouette cell and assert the "<gen> — after N spots" floater appears.
## Exists because handler-level tests stay green while real board input is dead
## (the input-swallow bug class). Captures the proof shot too.

const Save = preload("res://engine/scripts/save.gd")
const G = preload("res://engine/scripts/content.gd")
const GB = preload("res://engine/scripts/grove_board.gd")

func _initialize() -> void:
	if not FileAccess.file_exists("res://override.cfg"):
		print("REFUSED: run via tools/quiet_godot.sh")
		quit(2)
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true, 0)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	var dir := "/tmp/tu_clickpreview/"
	if DirAccess.dir_exists_absolute(dir):
		for fn in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir + fn)
	else:
		DirAccess.make_dir_recursive_absolute(dir)
	Save.configure_for_test(dir)

	var scn = load("res://engine/scenes/Grove.tscn").instantiate()
	root.add_child(scn)
	current_scene = scn
	await create_timer(0.5).timeout

	# genpreview setup (mirrors grove_shot): open a path to a line-3 compost edge
	for cc in [Vector2i(1, 3), Vector2i(2, 3), Vector2i(2, 2), Vector2i(2, 1)]:
		scn.board.terrain[GB.idx(cc)] = 0
	scn._rebuild_all()
	await create_timer(0.4).timeout

	if scn.gen_preview_cells.is_empty():
		print("FAIL: no gen-preview cell — the compost silhouette is not shown")
		quit(1)
		return
	var cell: Vector2i = scn.gen_preview_cells.keys()[0]
	var gi: int = scn.gen_preview_cells[cell]
	var glabel := String(G.GENERATORS[gi].label)
	print("preview cell %s -> gen %d (%s), chapter %d, arrives %d" % \
		[cell, gi, glabel, scn._chapter_idx(), int(G.GENERATORS[gi].appears_at)])

	# a REAL tap on the silhouette cell, through the live input surface
	var half := Vector2(scn.csz, scn.csz) / 2.0
	var local: Vector2 = scn._cell_pos(cell) + half
	var gpos: Vector2 = scn.board_area.get_global_transform() * local
	_click(gpos)
	await create_timer(0.35).timeout

	# proof: a floater Label naming the locked generator + its arrival appeared
	var found := ""
	for l in scn.find_children("*", "Label", true, false):
		var t := String((l as Label).text).to_lower()
		if "after" in t and glabel.to_lower() in t:
			found = String((l as Label).text)
			break
	var ok := found != ""
	print("%s: real tap on the silhouette -> floater = %s" % ["PASS" if ok else "FAIL", found if ok else "<none>"])
	quit(0 if ok else 1)

func _click(at: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = at
	down.global_position = at
	Input.parse_input_event(down)
	var up := down.duplicate()
	up.pressed = false
	Input.parse_input_event(up)
