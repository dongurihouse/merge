extends SceneTree
## Dev tool (real renderer, NOT --headless): screenshot Jobs.tscn in a given save state.
##   godot --path . -s res://tools/map_shot.gd -- <mode> <out.png>
## modes: fresh | mid | lump | far

const Save = preload("res://engine/scripts/save.gd")
const Districts = preload("res://engine/scripts/districts.gd")

func _initialize() -> void:
	if not FileAccess.file_exists("res://override.cfg"):
		print("REFUSED: real-renderer tools must run via tools/quiet_godot.sh (born-minimized")
		print("window; in-script flags are too late and flash/steal focus). See ~/.claude/CLAUDE.md")
		quit(2)
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true, 0)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	var args := OS.get_cmdline_user_args()
	var mode: String = args[0] if args.size() >= 1 else "fresh"
	var out: String = args[1] if args.size() >= 2 else "/tmp/map_%s.png" % mode

	var dir := "/tmp/tu_mapshot_%s/" % mode
	if DirAccess.dir_exists_absolute(dir):
		for fn in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir + fn)
	else:
		DirAccess.make_dir_recursive_absolute(dir)
	Save.configure_for_test(dir)

	match mode:
		"mid":                                   # 2 of Wren's jobs done, on the 3rd
			Save.record_job("tidy_01", 3, 4)
			Save.record_job("tidy_02", 2, 9)
			Save.add_coins(95)
		"lump":                                  # Wren's whole run just finished → lump beat fires
			for id in ["tidy_01", "tidy_02", "tidy_03", "tidy_04"]:
				Save.record_job(id, 3, 6)
			Save.add_coins(120)
		"far":                                   # both doors open, deep progress
			for id in ["tidy_01", "tidy_02", "tidy_03", "tidy_04", "tidy_06", "tidy_05"]:
				Save.record_job(id, 2, 8)
			Save.collect_client_lump("wren", 150)

	var scn: Node = load("res://engine/scenes/Jobs.tscn").instantiate()
	root.add_child(scn)
	await create_timer(0.7 if mode == "lump" else 0.45).timeout

	# minimized windows occasionally serve a STALE frame - force a fresh draw
	RenderingServer.force_draw()
	var img := root.get_texture().get_image()
	var err := img.save_png(out)
	print("SHOT saved=%s err=%d coins=%d" % [out, err, Save.coins()])
	quit()
