extends SceneTree
## Screenshot the place_test sandbox (run via tools/quiet_godot.sh).
##   quiet_godot.sh --path . -s res://tools/place_shot.gd -- <out.png> [frame_1based]

func _initialize() -> void:
	if not FileAccess.file_exists("res://override.cfg"):
		print("REFUSED: real-renderer tools must run via tools/quiet_godot.sh")
		quit(2); return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true, 0)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() >= 1 else "/tmp/place_test.png"
	var which: int = int(args[1]) if args.size() >= 2 else 1
	var scn = load("res://scenes/place_test.tscn").instantiate()
	root.add_child(scn)
	current_scene = scn
	await create_timer(0.5).timeout
	if which >= 1 and which <= scn.frames.size():
		scn.frames[scn.active].visible = false
		scn.active = which - 1
		scn.frames[scn.active].visible = true
		scn._refresh()
		await create_timer(0.2).timeout
	RenderingServer.force_draw()
	var img := root.get_texture().get_image()
	img.save_png(out)
	print("SHOT saved=%s frame=%d" % [out, which])
	quit()
