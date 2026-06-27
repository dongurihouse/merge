extends SceneTree
## Dev tool (real renderer; run via engine/tools/quiet_godot.sh): screenshot the Explore Rush
## with the rush-start teaching popup ("Tap to Merge!") + the always-on bottom hint.
##   quiet_godot.sh --path . -s res://games/grove/tools/rush_shot.gd -- <mode> <out.png> [WxH]
## modes: intro (default — popup mid-HOLD + bottom hint) | retired (4th rush: bottom hint only, no popup)

const Save = preload("res://engine/scripts/core/save.gd")
const Explore = preload("res://engine/scripts/core/explore.gd")

func _initialize() -> void:
	if not FileAccess.file_exists("res://override.cfg"):
		print("REFUSED: real-renderer tools must run via engine/tools/quiet_godot.sh (born-minimized window).")
		quit(2)
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true, 0)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	var args := OS.get_cmdline_user_args()
	var mode: String = args[0] if args.size() >= 1 else "intro"
	var out: String = args[1] if args.size() >= 2 else "/tmp/rush_%s.png" % mode
	if args.size() >= 3 and "x" in args[2]:
		await create_timer(0.2).timeout
		var wh := args[2].split("x")
		DisplayServer.window_set_size(Vector2i(int(wh[0]), int(wh[1])))
		await create_timer(0.2).timeout

	var dir := "/tmp/tu_rushshot_%s/" % mode
	if DirAccess.dir_exists_absolute(dir):
		for fn in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir + fn)
	else:
		DirAccess.make_dir_recursive_absolute(dir)
	Save.configure_for_test(dir)
	if mode == "retired":
		for _i in Explore.RUSH_INTRO_SHOWS:        # spend the popup gate → only the bottom hint should remain
			Save.mark_rush_intro_seen()
	Explore.begin_run({})

	var scn = load("res://engine/scenes/ExploreRush.tscn").instantiate()
	root.add_child(scn)
	current_scene = scn
	await create_timer(0.12).timeout               # let _ready build the board + kick off the popup tween
	for _i in 6:                                    # seed a few tiles so the board reads as a live rush
		scn._spawn()
	await create_timer(0.4).timeout                 # tiles settle; the popup sits in its ~0.9s HOLD window

	RenderingServer.force_draw()
	var img := root.get_texture().get_image()
	var err := img.save_png(out)
	var popup: Node = scn.find_child("RushTapHint", true, false)
	print("SHOT saved=%s err=%d mode=%s intro_seen=%d popup_present=%s" % \
		[out, err, mode, Save.rush_intro_seen(), popup != null])
	quit()
