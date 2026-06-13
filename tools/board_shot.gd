extends SceneTree
## Dev tool (real renderer, NOT --headless): screenshot the board on a specific level.
##   godot --path . -s res://tools/board_shot.gd -- <level_id> <out.png> [WxH]
## Optional WxH resizes the window first (e.g. 900x1200 = iPad 3:4) to check other
## aspect ratios under the project's stretch settings.
## Runs MINIMIZED + no-focus: frames still render to the layer, so captures are real
## but no window ever appears or steals focus from whatever the owner is doing.

const Session = preload("res://scripts/session.gd")
const Districts = preload("res://scripts/districts.gd")

func _initialize() -> void:
	if not FileAccess.file_exists("res://override.cfg"):
		print("REFUSED: real-renderer tools must run via tools/quiet_godot.sh (born-minimized")
		print("window; in-script flags are too late and flash/steal focus). See ~/.claude/CLAUDE.md")
		quit(2)
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true, 0)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	var args := OS.get_cmdline_user_args()
	var id: String = args[0] if args.size() >= 1 else "tidy_01"
	var out: String = args[1] if args.size() >= 2 else "/tmp/board_%s.png" % id
	if args.size() >= 3 and "x" in args[2]:
		# the engine re-applies the project size on the first frames — set ours after
		await create_timer(0.2).timeout
		var wh := args[2].split("x")
		DisplayServer.window_set_size(Vector2i(int(wh[0]), int(wh[1])))
		await create_timer(0.2).timeout
	var idx := Districts.level_index(id)
	if idx < 0:
		print("FAIL: unknown level id ", id)
		quit(1); return
	Session.next_level = idx
	var scn: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scn)
	await create_timer(0.5).timeout
	# minimized windows occasionally serve a STALE frame - force a fresh draw
	RenderingServer.force_draw()
	var img := root.get_texture().get_image()
	var err := img.save_png(out)
	print("SHOT saved=%s err=%d level=%s district=%d" % [out, err, id, Districts.district_of_level(idx)])
	quit()
