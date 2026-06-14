extends SceneTree
## Dev tool (run via tools/quiet_godot.sh): reproduce the "Decorate does nothing"
## report — stage a gate-ready grove at chapter >= 1, CLICK the button for real,
## and print which scene we land on.

const Save = preload("res://engine/scripts/save.gd")
const G = preload("res://engine/scripts/grove_content.gd")

func _initialize() -> void:
	if not FileAccess.file_exists("res://override.cfg"):
		print("REFUSED: run via tools/quiet_godot.sh")
		quit(2)
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true, 0)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	var dir := "/tmp/tu_clickgate/"
	if DirAccess.dir_exists_absolute(dir):
		for fn in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir + fn)
	else:
		DirAccess.make_dir_recursive_absolute(dir)
	Save.configure_for_test(dir)

	# chapter 1 (merchant on the fence) + enough stars for the gate
	var g := Save.grove()
	g["unlocks"] = {"fh_chest": true}
	g["exp"] = 30
	Save.grove_write()
	Save.add_stars(10)

	var scn = load("res://engine/scenes/Grove.tscn").instantiate()
	root.add_child(scn)
	current_scene = scn
	await create_timer(0.6).timeout
	print("gate visible=%s disabled=%s rect=%s chapter=%d" % \
		[scn.gate_btn.visible, scn.gate_btn.disabled, scn.gate_btn.get_global_rect(), scn._chapter_idx()])
	var center: Vector2 = scn.gate_btn.get_global_rect().get_center()
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = center
	down.global_position = center
	Input.parse_input_event(down)
	var up := down.duplicate()
	up.pressed = false
	Input.parse_input_event(up)
	await create_timer(0.8).timeout
	var landed := "Grove"
	if current_scene != null and current_scene.get_scene_file_path() != "":
		landed = current_scene.get_scene_file_path()
	print("CLICKED gate at %s -> scene now: %s" % [center, landed])
	quit()
