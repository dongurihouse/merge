extends SceneTree
## Dev tool (run via engine/tools/quiet_godot.sh): the REAL purchase flow, end to end —
## click the farmhouse (its lid opens), then click the ✿3★ row inside, and
## assert the stars were spent. Exists because handler-level tests stay green
## while real input is dead (input-swallow bug class ×3).

const Save = preload("res://engine/scripts/core/save.gd")
const G = preload("res://engine/scripts/core/content.gd")

func _initialize() -> void:
	if not FileAccess.file_exists("res://override.cfg"):
		print("REFUSED: run via engine/tools/quiet_godot.sh")
		quit(2)
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true, 0)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	var dir := "/tmp/tu_clickspot/"
	if DirAccess.dir_exists_absolute(dir):
		for fn in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir + fn)
	else:
		DirAccess.make_dir_recursive_absolute(dir)
	Save.configure_for_test(dir)
	Save.add_stars(10)

	var scn = load("res://engine/scenes/Map.tscn").instantiate()
	root.add_child(scn)
	current_scene = scn
	await create_timer(0.6).timeout

	# stage 1: click the farmhouse — the chest's lid should open
	var zone_center: Vector2 = scn.zone_nodes[0].get_global_rect().get_center()
	_click(zone_center)
	await create_timer(0.6).timeout
	var lid_open: bool = not scn.spot_hits.is_empty()
	print("STAGE1 %s: clicked zone at %s -> lid_open=%s (%d rows)" % \
		["PASS" if lid_open else "FAIL", zone_center, lid_open, scn.spot_hits.size()])
	if not lid_open:
		quit(1)
		return

	# stage 2: click the (0,0) row inside — fh_chest (Q v2 spot 0) costs 3★
	var row: Control = null
	for hit in scn.spot_hits:
		if int(hit.z) == 0 and int(hit.k) == 0:
			row = hit.node
			break
	_click(row.get_global_rect().get_center())
	await create_timer(0.6).timeout
	var bought: bool = scn.spot_owned("fh_chest") and Save.stars() == 7
	print("STAGE2 %s: clicked row -> owned=%s stars=%d (want true/7)" % \
		["PASS" if bought else "FAIL", scn.spot_owned("fh_chest"), Save.stars()])
	quit(0 if bought else 1)

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
