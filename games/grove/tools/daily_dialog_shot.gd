extends SceneTree
## TEMP dev tool: screenshot the daily calendar with a seeded streak (2 days claimed → day 3 is
## today), so the done / today / future / mystery / capstone states all render in one frame.
##   quiet_godot.sh --path . -s res://games/grove/tools/daily_dialog_shot.gd -- <out_dir>

const Save = preload("res://engine/scripts/core/save.gd")
const MapScene = preload("res://engine/scripts/scenes/map.gd")

func _initialize() -> void:
	if not FileAccess.file_exists("res://override.cfg"):
		print("REFUSED: run via engine/tools/quiet_godot.sh")
		quit(2)
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true, 0)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	DisplayServer.window_set_size(Vector2i(1080, 1920))   # capture at the mock's canvas
	get_root().size = Vector2i(1080, 1920)
	var args := OS.get_cmdline_user_args()
	var out_dir: String = (args[0] if args.size() >= 1 else "/tmp/tu_daily_out").trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(out_dir)

	var dir := "/tmp/tu_daily_dialog_shot/"
	if DirAccess.dir_exists_absolute(dir):
		for fn in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir + fn)
	else:
		DirAccess.make_dir_recursive_absolute(dir)
	Save.configure_for_test(dir)

	var daily := Save.daily()
	daily["streak"] = 2
	daily["claimed"] = false
	Save.grove_write()

	MapScene._login_shown_launch = true
	var scn = load("res://engine/scenes/Map.tscn").instantiate()
	root.add_child(scn)
	current_scene = scn
	await create_timer(0.8).timeout

	scn._open_daily()
	await create_timer(0.8).timeout
	RenderingServer.force_draw()
	var e := root.get_texture().get_image().save_png(out_dir + "daily_dialog.png")
	print("SHOT daily=%d -> %s" % [e, out_dir])

	# REAL-PATH claim: tap the CLAIM pill through the viewport and read the model back.
	var ov: Control = scn.get_node_or_null("LoginOverlay")
	var btn: Control = ov.find_child("DailyClaimButton", true, false) if ov != null else null
	if btn == null:
		print("CLAIM button MISSING")
	else:
		var at := btn.get_global_rect().get_center()
		for pressed in [true, false]:
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT; ev.pressed = pressed; ev.position = at
			get_root().push_input(ev)
			await create_timer(0.15).timeout
		await create_timer(0.4).timeout
		print("CLAIM streak=%d claimed=%s" % [int(Save.daily().get("streak", -1)),
			str(Save.daily().get("claimed", false))])
	quit()
