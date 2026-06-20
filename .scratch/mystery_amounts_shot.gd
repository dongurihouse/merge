extends SceneTree
## quiet_godot.sh --path . -s res://.scratch/mystery_amounts_shot.gd -- <spin|spin4> <out.png>
const Save := preload("res://engine/scripts/core/save.gd")
const Login := preload("res://engine/scripts/core/login.gd")
const LoginMystery := preload("res://engine/scripts/ui/login_mystery.gd")
const UiFont := preload("res://engine/scripts/ui/ui_font.gd")

func _initialize() -> void:
	if FileAccess.file_exists("res://override.cfg"):
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true, 0)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	UiFont.apply()
	var args := OS.get_cmdline_user_args()
	var mode: String = args[0] if args.size() >= 1 else "spin"
	var out: String = args[1] if args.size() >= 2 else "/tmp/mystery_%s.png" % mode
	await create_timer(0.2).timeout
	DisplayServer.window_set_size(Vector2i(720, 1280))
	await create_timer(0.2).timeout
	var dir := "user://tu_mysshot_%s/" % mode
	if DirAccess.dir_exists_absolute(dir):
		for fn in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir + fn)
	else:
		DirAccess.make_dir_recursive_absolute(dir)
	Save.configure_for_test(dir)
	var bg := ColorRect.new(); bg.color = Color(0.13, 0.32, 0.18)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT); root.add_child(bg)
	var host := Control.new(); host.set_anchors_preset(Control.PRESET_FULL_RECT); root.add_child(host)
	await create_timer(0.2).timeout
	var today := int(Time.get_unix_time_from_system() / 86400.0)
	var day := 7 if mode == "spin" else 4
	var streak := 6 if mode == "spin" else 3
	Save.data["daily"] = {"day": today, "jobs": 0, "merges": 0, "coins": 0, "claimed": false, "streak": streak}
	Save.save_now(); Save._loaded = false
	LoginMystery.open(host, day, {})
	await create_timer(0.7).timeout
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png(out)
	print("SHOT saved=%s mode=%s" % [out, mode])
	quit()
