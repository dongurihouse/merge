extends SceneTree
## TEMP dev tool (deleted before commit): screenshot the Purchase-wait sheet.
##   quiet_godot.sh --path . -s res://games/grove/tools/_tmp_wait_shot.gd -- <out.png>

const Save = preload("res://engine/scripts/core/save.gd")
const Wait = preload("res://engine/scripts/ui/purchase_wait.gd")
const MapScene = preload("res://engine/scripts/scenes/map.gd")

func _initialize() -> void:
	if not FileAccess.file_exists("res://override.cfg"):
		print("REFUSED: run via engine/tools/quiet_godot.sh")
		quit(2)
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true, 0)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	DisplayServer.window_set_size(Vector2i(1080, 1920))
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() >= 1 else "/tmp/tu_wait.png"

	var dir := "/tmp/tu_wait_shot/"
	if DirAccess.dir_exists_absolute(dir):
		for fn in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir + fn)
	else:
		DirAccess.make_dir_recursive_absolute(dir)
	Save.configure_for_test(dir)

	MapScene._login_shown_launch = true
	var scn = load("res://engine/scenes/Map.tscn").instantiate()
	root.add_child(scn)
	current_scene = scn
	await create_timer(0.8).timeout

	Wait.show(scn, "One moment", "Opening the App Store…")
	await create_timer(0.6).timeout
	RenderingServer.force_draw()
	var e := root.get_texture().get_image().save_png(out)
	print("SHOT wait=%d -> %s" % [e, out])
	quit()
