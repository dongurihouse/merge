extends SceneTree
## Dev tool (run via tools/quiet_godot.sh): order T end-to-end with REAL input —
## board → Decorate (gate) → Home arrives INSIDE last_zone's interior (no map) →
## the interior's "Tend the garden ▶" CTA → back on the board. Exists because
## handler-level tests stay green while real input is dead (input-swallow class).

const Save = preload("res://scripts/save.gd")

func _initialize() -> void:
	if not FileAccess.file_exists("res://override.cfg"):
		print("REFUSED: run via tools/quiet_godot.sh")
		quit(2)
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true, 0)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	var dir := "/tmp/tu_clickdecorate/"
	if DirAccess.dir_exists_absolute(dir):
		for fn in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir + fn)
	else:
		DirAccess.make_dir_recursive_absolute(dir)
	Save.configure_for_test(dir)
	# a player mid-game: decorated the farmhouse before (last_zone), gate ready
	var g := Save.grove()
	g["unlocks"] = {"fh_chest": true}
	g["exp"] = 30
	g["last_zone"] = "farmhouse"
	Save.grove_write()
	Save.add_stars(5)

	var scn = load("res://scenes/Grove.tscn").instantiate()
	root.add_child(scn)
	current_scene = scn
	await create_timer(0.8).timeout

	# stage 1: click Decorate (the gate)
	if scn.gate_btn == null or not scn.gate_btn.visible:
		print("STAGE1 FAIL: the Decorate gate is not up")
		quit(1)
		return
	_click(scn.gate_btn.get_global_rect().get_center())
	await create_timer(0.8).timeout
	var home = current_scene
	if home == null or not String(home.scene_file_path).contains("Home"):
		print("STAGE1 FAIL: Decorate did not land on Home (scene=%s)" % \
			(home.scene_file_path if home != null else "null"))
		quit(1)
		return
	print("STAGE1 PASS: Decorate -> Home")

	# stage 2: we must ARRIVE inside the farmhouse interior — no map stop
	var inside: bool = home.interior != null and home._interior_zone == 0
	print("STAGE2 %s: arrived inside last_zone's interior=%s zone=%d" % \
		["PASS" if inside else "FAIL", home.interior != null, home._interior_zone])
	if not inside:
		quit(1)
		return

	# stage 3: the interior CTA walks straight back to the board
	_click(home._int_cta.get_global_rect().get_center())
	await create_timer(0.8).timeout
	var back = current_scene
	var on_board: bool = back != null and String(back.scene_file_path).contains("Grove")
	print("STAGE3 %s: interior CTA -> %s" % \
		["PASS" if on_board else "FAIL", back.scene_file_path if back != null else "null"])
	quit(0 if on_board else 1)

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
