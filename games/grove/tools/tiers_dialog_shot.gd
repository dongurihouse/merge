extends SceneTree
## Dev tool (run via engine/tools/quiet_godot.sh): screenshot the TIERS (discovery ladder) modal
## over the Board — the base-line tier screen (ui/ladder.gd) against its mock
## games/grove/assets/_concepts/dialogs/tiers_1080x1920.png.
##   quiet_godot.sh --path . -s res://games/grove/tools/tiers_dialog_shot.gd -- <out_dir>
## Seeds a save where a line's lower tiers are DISCOVERED and the upper ones are not, so the shot
## shows both cell states. Parallel-safe (own temp save). Mirrors residents_dialog_shot.gd's header.

const Save = preload("res://engine/scripts/core/save.gd")

func _initialize() -> void:
	if not FileAccess.file_exists("res://override.cfg"):
		print("REFUSED: real-renderer tools must run via engine/tools/quiet_godot.sh (born-minimized")
		print("window; in-script flags are too late and flash/steal focus). See ~/.claude/CLAUDE.md")
		quit(2)
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true, 0)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	DisplayServer.window_set_size(Vector2i(1080, 1920))
	var args := OS.get_cmdline_user_args()
	var out_dir: String = (args[0] if args.size() >= 1 else "/tmp/tu_tiers_out").trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(out_dir)

	var dir := "/tmp/tu_tiers_shot/"
	if DirAccess.dir_exists_absolute(dir):
		for fn in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir + fn)
	else:
		DirAccess.make_dir_recursive_absolute(dir)
	Save.configure_for_test(dir)

	var g := Save.grove()
	g["exp"] = 60
	Save.grove_write()

	var scn = load("res://engine/scenes/Board.tscn").instantiate()
	root.add_child(scn)
	current_scene = scn
	await create_timer(0.8).timeout

	# mark the first tiers of line 1 as SEEN so the grid shows discovered + locked cells.
	var gg := Save.grove()
	var seen: Dictionary = gg.get("seen", {})
	for t in range(1, 7):
		seen[str(1 * 100 + t)] = true
	gg["seen"] = seen
	Save.grove_write()

	scn._open_ladder(1, 3)
	await create_timer(0.8).timeout
	RenderingServer.force_draw()
	var img := root.get_texture().get_image()
	var e := img.save_png(out_dir + "tiers_dialog.png")

	# the MERGED-line variant of the same screen (the two-ingredient recipe over its own ladder)
	scn._open_ladder(5, 3)
	await create_timer(0.8).timeout
	RenderingServer.force_draw()
	var e2 := root.get_texture().get_image().save_png(out_dir + "tiers_recipe.png")
	print("SHOT tiers=%d recipe=%d -> %s" % [e, e2, out_dir])
	quit()
