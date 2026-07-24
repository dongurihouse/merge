extends SceneTree
## Dev tool (run via engine/tools/quiet_godot.sh): screenshot the REAL "Update Available" prompt
## (ui/update_prompt.gd::open) over the dimmed home — the App Store version-upgrade dialog. It renders
## the SHIPPED view (shared dialog_frame: parchment card · title · ✕, message, cream "Not now" + green
## "Update"), so the capture is the actual UI, not a rebuilt mock. Detection (core/update_check.gd) is
## iOS-only and not exercised here — open() is called directly with a sample version + url.
##   quiet_godot.sh --path . -s res://games/grove/tools/update_dialog_shot.gd -- <out_dir>
## Mirrors residents_dialog_shot.gd's quiet-capture header + light home seed.

const Save = preload("res://engine/scripts/core/save.gd")
const Home = preload("res://engine/scripts/core/home.gd")
const HB = preload("res://engine/scripts/core/home_build.gd")
const MapScene = preload("res://engine/scripts/scenes/map.gd")

func _initialize() -> void:
	if not FileAccess.file_exists("res://override.cfg"):
		print("REFUSED: real-renderer tools must run via engine/tools/quiet_godot.sh (born-minimized")
		print("window; in-script flags are too late and flash/steal focus). See ~/.claude/CLAUDE.md")
		quit(2)
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true, 0)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	var args := OS.get_cmdline_user_args()
	var out_dir: String = (args[0] if args.size() >= 1 else "/tmp/tu_update_dialog_out").trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(out_dir)

	var dir := "/tmp/tu_update_dialog_shot/"
	if DirAccess.dir_exists_absolute(dir):
		for fn in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir + fn)
	else:
		DirAccess.make_dir_recursive_absolute(dir)
	Save.configure_for_test(dir)

	# a believable home behind the dimmed veil: some progress + every building bought.
	var g := Save.grove()
	g["exp"] = 60
	Save.grove_write()
	Save.add_coins(300)
	var st := Home.state()
	for d in Home.defs():
		while HB.buy_step(st, d):
			pass
	Save.grove_write()

	MapScene._login_shown_launch = true
	var scn = load("res://engine/scenes/Map.tscn").instantiate()
	root.add_child(scn)
	current_scene = scn
	await create_timer(0.8).timeout

	RenderingServer.force_draw()
	root.get_texture().get_image().save_png(out_dir + "home.png")

	# open the REAL shipped prompt with a sample newer version + store url.
	var UpdatePrompt = load("res://engine/scripts/ui/update_prompt.gd")
	UpdatePrompt.open(scn, "1.2.0", "https://apps.apple.com/app/id0000000000")
	await create_timer(0.6).timeout

	RenderingServer.force_draw()
	var e1 := root.get_texture().get_image().save_png(out_dir + "update_dialog.png")

	print("SHOT update_dialog=%d -> %s" % [e1, out_dir])
	quit()
