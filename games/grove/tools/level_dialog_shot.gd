extends SceneTree
## Dev tool (run via engine/tools/quiet_godot.sh): screenshot the Level dialog (ui/level_popup.gd)
## against its mock at games/grove/assets/_concepts/dialogs/level_1080x1920.png.
##   quiet_godot.sh --path . -s res://games/grove/tools/level_dialog_shot.gd -- <out_dir>
## Seeds coins so the bar sits mid-level. Parallel-safe (own temp save).

const Save = preload("res://engine/scripts/core/save.gd")
const G = preload("res://engine/scripts/core/content.gd")
const LevelPopup = preload("res://engine/scripts/ui/level_popup.gd")
const MapScene = preload("res://engine/scripts/scenes/map.gd")

func _initialize() -> void:
	if not FileAccess.file_exists("res://override.cfg"):
		print("REFUSED: real-renderer tools must run via engine/tools/quiet_godot.sh")
		quit(2)
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true, 0)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	DisplayServer.window_set_size(Vector2i(1080, 1920))
	var args := OS.get_cmdline_user_args()
	var out_dir: String = (args[0] if args.size() >= 1 else "/tmp/tu_level_dialog_out").trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(out_dir)

	var dir := "/tmp/tu_level_dialog_shot/"
	if DirAccess.dir_exists_absolute(dir):
		for fn in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir + fn)
	else:
		DirAccess.make_dir_recursive_absolute(dir)
	Save.configure_for_test(dir)

	# park the coin clock partway between two levels so the bar reads as partial
	var lvl := 7
	var base := G.coins_at_level(lvl)
	var nxt := G.coins_at_level(lvl + 1)
	Save.earn_coins(base + int((nxt - base) * 0.72))

	MapScene._login_shown_launch = true
	var scn = load("res://engine/scenes/Map.tscn").instantiate()
	root.add_child(scn)
	current_scene = scn
	await create_timer(0.8).timeout

	LevelPopup.open(scn)
	await create_timer(0.8).timeout
	RenderingServer.force_draw()
	var e0 := root.get_texture().get_image().save_png(out_dir + "level_info.png")

	var ov: Control = scn.get_node_or_null("LevelPopupOverlay")
	if ov != null:
		ov.queue_free()
	await create_timer(0.3).timeout

	LevelPopup.open_levelup(scn, 1)
	await create_timer(0.8).timeout
	RenderingServer.force_draw()
	var e1 := root.get_texture().get_image().save_png(out_dir + "level_levelup.png")

	print("SHOT level=%d levelup=%d lvl=%d earned=%d next=%d -> %s"
		% [e0, e1, G.level(), Save.coins_earned_lifetime(), nxt, out_dir])
	quit()
