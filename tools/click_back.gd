extends SceneTree
## Dev tool (run via tools/quiet_godot.sh): the REAL ways back OUT of an interior —
## click the farmhouse (room opens), click the round ◀ (room closes), walk back in,
## click the dark surround (room closes again). Exists because handler-level tests
## stay green while real input is dead (input-swallow bug class).

const Save = preload("res://scripts/save.gd")
const G = preload("res://scripts/grove_content.gd")

func _initialize() -> void:
	if not FileAccess.file_exists("res://override.cfg"):
		print("REFUSED: run via tools/quiet_godot.sh")
		quit(2)
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true, 0)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	var dir := "/tmp/tu_clickback/"
	if DirAccess.dir_exists_absolute(dir):
		for fn in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir + fn)
	else:
		DirAccess.make_dir_recursive_absolute(dir)
	Save.configure_for_test(dir)

	var scn = load("res://scenes/Home.tscn").instantiate()
	root.add_child(scn)
	current_scene = scn
	await create_timer(0.6).timeout

	# stage 1: click the farmhouse — walk inside
	var zone_center: Vector2 = scn.zone_nodes[0].get_global_rect().get_center()
	_click(zone_center)
	await create_timer(0.6).timeout
	if not is_instance_valid(scn) or scn.interior == null:
		print("STAGE1 FAIL: zone click at %s did not open the interior" % zone_center)
		quit(1)
		return
	print("STAGE1 PASS: clicked zone at %s -> inside" % zone_center)

	# stage 2: click the round back button — should land back on the map
	var back_center: Vector2 = scn._back_hit.get_center()
	_click(back_center)
	await create_timer(0.6).timeout
	var out: bool = scn.interior == null
	print("STAGE2 %s: clicked back at %s -> interior_closed=%s" % \
		["PASS" if out else "FAIL", back_center, out])
	if not out:
		quit(1)
		return

	# stage 3: walk in again, then tap the dark surround below the room art
	_click(scn.zone_nodes[0].get_global_rect().get_center())
	await create_timer(0.6).timeout
	if scn.interior == null:
		print("STAGE3 FAIL: could not re-enter the room")
		quit(1)
		return
	var dark := Vector2(8, scn.get_viewport_rect().size.y - 8.0)
	_click(dark)
	await create_timer(0.6).timeout
	var out2: bool = scn.interior == null
	print("STAGE3 %s: clicked dark surround at %s -> interior_closed=%s" % \
		["PASS" if out2 else "FAIL", dark, out2])
	quit(0 if out2 else 1)

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
