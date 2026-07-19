extends SceneTree
## Dev tool (run via engine/tools/quiet_godot.sh): screenshot the MERGED-LINE TIERS dialog — the
## recipe header (two tappable ingredient items) above the merged line's own tier grid — plus the
## base tier screen and the Producing (gen lines) dialog that share the same face, for side-by-side
## review against games/grove/assets/_concepts/dialogs/merged_line_tiers_1080x1920.png.
##   quiet_godot.sh --path . -s res://games/grove/tools/merged_line_tiers_shot.gd -- <out_dir>
## Parallel-safe (own temp save dir).

const Save = preload("res://engine/scripts/core/save.gd")

func _initialize() -> void:
	if not FileAccess.file_exists("res://override.cfg"):
		print("REFUSED: real-renderer tools must run via engine/tools/quiet_godot.sh (born-minimized")
		print("window; in-script flags are too late and flash/steal focus). See ~/.claude/CLAUDE.md")
		quit(2)
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true, 0)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	# pin the capture to the mock's canvas (1080x1920) — a minimized window otherwise takes whatever
	# height macOS last gave it, so captures would not be comparable run to run.
	DisplayServer.window_set_size(Vector2i(1080, 1920))
	var args := OS.get_cmdline_user_args()
	var out_dir: String = (args[0] if args.size() >= 1 else "/tmp/tu_merged_line_tiers_out").trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(out_dir)

	var dir := "/tmp/tu_merged_line_tiers_shot/"
	if DirAccess.dir_exists_absolute(dir):
		for fn in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir + fn)
	else:
		DirAccess.make_dir_recursive_absolute(dir)
	Save.configure_for_test(dir)

	var b = load("res://engine/scenes/Board.tscn").instantiate()
	root.add_child(b)
	current_scene = b
	await create_timer(0.6).timeout

	# seed discovery so the merged line's low tiers read as SEEN (the mock shows 5 discovered of 12)
	var g := Save.grove()
	var seen: Dictionary = g.get("seen", {})
	for line in [2, 3, 5]:
		for t in range(1, 6):
			seen[str(line * 100 + t)] = true
	g["seen"] = seen
	Save.grove_write()

	# --- the MERGED-LINE tier screen: line 5 = the [2,3] recipe -------------------------------------
	b._open_ladder(5, 5)
	await create_timer(0.7).timeout
	RenderingServer.force_draw()
	var e0 := root.get_texture().get_image().save_png(out_dir + "merged_line_tiers.png")

	# --- the BASE tier screen (same face, generator header) -----------------------------------------
	b._open_ladder(2, 3)
	await create_timer(0.6).timeout
	RenderingServer.force_draw()
	var e1 := root.get_texture().get_image().save_png(out_dir + "base_tiers.png")
	for c in b.get_children():
		if c is Control and String(c.name).begins_with("LadderOverlay"):
			c.queue_free()
	await create_timer(0.3).timeout

	print("SHOT merged=%d base=%d -> %s" % [e0, e1, out_dir])
	quit()
