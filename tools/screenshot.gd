extends SceneTree
## Dev tool: render a scene with the REAL renderer and save a PNG so changes can be
## eyeballed without a device. Usage (NOT --headless):
##   godot --path . -s res://tools/screenshot.gd -- <scene> <out.png> [press] [WxH]
## Defaults: scenes/Main.tscn -> /tmp/rz_shot.png
## Runs MINIMIZED + no-focus: frames still render, no window appears or steals focus.

func _initialize() -> void:
	if not FileAccess.file_exists("res://override.cfg"):
		print("REFUSED: real-renderer tools must run via tools/quiet_godot.sh (born-minimized")
		print("window; in-script flags are too late and flash/steal focus). See ~/.claude/CLAUDE.md")
		quit(2)
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true, 0)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	var scene_path := "res://scenes/Main.tscn"
	var out := "/tmp/rz_shot.png"
	var args := OS.get_cmdline_user_args()
	if args.size() >= 1:
		scene_path = args[0]
	if args.size() >= 2:
		out = args[1]
	var press := ""
	if args.size() >= 3:
		press = args[2]   # "x,y" board-local px → simulate holding a piece (to see highlights)
	if args.size() >= 4 and "x" in args[3]:   # "WxH" window size (test other aspect ratios)
		await create_timer(0.2).timeout        # engine re-applies project size on first frames
		var wh := args[3].split("x")
		DisplayServer.window_set_size(Vector2i(int(wh[0]), int(wh[1])))
		await create_timer(0.2).timeout
	var scn: Node = load(scene_path).instantiate()
	root.add_child(scn)
	await create_timer(0.4).timeout   # lay out + render
	if press != "":
		var xy := press.split(",")
		if xy.size() == 2:
			scn.call("_on_press", Vector2(float(xy[0]), float(xy[1])))
		await create_timer(0.4).timeout
	# minimized windows occasionally serve a STALE frame - force a fresh draw
	RenderingServer.force_draw()
	var img := root.get_texture().get_image()
	var err := img.save_png(out)
	print("SHOT saved=%s err=%d size=%dx%d" % [out, err, img.get_width(), img.get_height()])
	quit()
