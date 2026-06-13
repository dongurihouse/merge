extends SceneTree
## One-off (real renderer, NOT --headless): screenshot Room.tscn in a given save state.
##   godot --path . -s res://tools/_room_shot.gd -- <mode> <out.png>
## modes: empty | rich | mid | poor | reveal

const Save = preload("res://scripts/save.gd")

func _initialize() -> void:
	if not FileAccess.file_exists("res://override.cfg"):
		print("REFUSED: real-renderer tools must run via tools/quiet_godot.sh (born-minimized")
		print("window; in-script flags are too late and flash/steal focus). See ~/.claude/CLAUDE.md")
		quit(2)
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true, 0)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	var args := OS.get_cmdline_user_args()
	var mode: String = args[0] if args.size() >= 1 else "empty"
	var out: String = args[1] if args.size() >= 2 else "/tmp/room_%s.png" % mode

	var dir := "/tmp/tu_roomshot_%s/" % mode
	if DirAccess.dir_exists_absolute(dir):
		for fn in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir + fn)
	else:
		DirAccess.make_dir_recursive_absolute(dir)
	Save.configure_for_test(dir)

	match mode:
		"rich", "reveal":
			Save.add_coins(900)
		"mid":
			Save.add_coins(400)
			Save.buy_decor("bedroom", "rug", 120)
			Save.buy_decor("bedroom", "bed", 146)   # leaves 134 — lamp(179) unaffordable
		"done":
			Save.add_coins(700)
			for id in ["rug", "bed", "lamp", "shelf"]:
				Save.buy_decor("bedroom", id, 100)   # owned BEFORE entry → reveal must NOT replay
		"poor", "empty":
			pass

	var scn: Node = load("res://scenes/Room.tscn").instantiate()
	root.add_child(scn)
	await create_timer(0.6).timeout

	match mode:
		"poor":
			scn.call("_on_pin", 0)               # tap the rug pin with 0 coins
			await create_timer(0.35).timeout
		"reveal":
			for i in 4:                          # buy all four required slots live
				scn.call("_on_pin", i)
				await create_timer(0.55).timeout
			await create_timer(1.0).timeout      # mid-reveal: glow swell + shout

	# minimized windows occasionally serve a STALE frame - force a fresh draw
	RenderingServer.force_draw()
	var img := root.get_texture().get_image()
	var err := img.save_png(out)
	print("SHOT saved=%s err=%d coins_left=%d decor=%d" % [out, err, Save.coins(), Save.decor_count("bedroom")])
	quit()
