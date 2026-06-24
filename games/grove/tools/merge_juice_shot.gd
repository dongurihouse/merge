extends SceneTree
## Dev tool (real renderer; run via engine/tools/quiet_godot.sh): capture a CONTROLLED
## before/after of a single merge — both passes in ONE process on the SAME placed tiles, so
## the only difference is the juice (the board seeds its starters randomly before a script can
## fix the seed, so two separate processes never match — hence one process, two passes).
##   engine/tools/quiet_godot.sh --path . -s res://games/grove/tools/merge_juice_shot.gd -- <out_dir>
## Writes <out_dir>/after/f00..17.png (juice on) and <out_dir>/before/f00..17.png (juice off).

const Save = preload("res://engine/scripts/core/save.gd")
const Feat = preload("res://engine/scripts/core/features.gd")

const PAIR_CODE := 102      # two tier-2 saplings → tier-3 (a representative mid-merge: squash+flash+hitstop, no shake)
const FRAMES := 18
const DT := 0.035           # wall-clock seconds between samples

func _initialize() -> void:
	if not FileAccess.file_exists("res://override.cfg"):
		print("REFUSED: real-renderer tools must run via engine/tools/quiet_godot.sh")
		quit(2); return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true, 0)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() >= 1 else "/tmp/merge_juice/"
	if not out_dir.ends_with("/"):
		out_dir += "/"

	# silence ambient motion so the two passes differ ONLY by the merge juice
	Feat.FLAGS["ambient_weather"] = false
	Feat.FLAGS["ambient_characters"] = false

	var test_dir := "/tmp/tu_mergejuice_save/"
	if DirAccess.dir_exists_absolute(test_dir):
		for fn in DirAccess.get_files_at(test_dir):
			DirAccess.remove_absolute(test_dir + fn)
	else:
		DirAccess.make_dir_recursive_absolute(test_dir)
	Save.configure_for_test(test_dir)

	var scn = load("res://engine/scenes/Board.tscn").instantiate()
	root.add_child(scn)
	current_scene = scn
	await create_timer(0.5).timeout

	# two empty ground cells to stage the merge on (same two cells reused for both passes)
	var empties: Array = scn.board.empty_ground_cells()
	var a: Vector2i = empties[0]
	var b: Vector2i = empties[1]

	var ctr: Vector2 = scn._cell_pos(b) + Vector2(scn.csz, scn.csz) / 2.0   # the merge cell, board-local
	var origin: Vector2 = scn.board_area.global_position
	print("MERGECELL px=%d,%d csz=%d origin=%d,%d" % [ctr.x + origin.x, ctr.y + origin.y, scn.csz, origin.x, origin.y])
	await _capture_pass(scn, a, b, true,  out_dir + "after/")    # juice ON
	await _capture_pass(scn, a, b, false, out_dir + "before/")   # juice OFF
	print("DONE: before/after strips under %s" % out_dir)
	quit()

# Place a fresh mergeable pair at a/b, flip the juice flags, drive the merge, sample frames.
func _capture_pass(scn, a: Vector2i, b: Vector2i, juice: bool, dir: String) -> void:
	for flag in ["merge_impact", "merge_hitstop", "big_moment_shake", "gen_anticipation", "merge_combo"]:
		Feat.FLAGS[flag] = juice
	# clear the staging cells, then place the identical pair
	for c in [a, b]:
		if scn.board.item_at(c) > 0:
			scn.board.take(c)
	scn.board.place(a, PAIR_CODE)
	scn.board.place(b, PAIR_CODE)
	scn._rebuild_pieces()
	await create_timer(0.3).timeout

	if DirAccess.dir_exists_absolute(dir):
		for fn in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir + fn)
	else:
		DirAccess.make_dir_recursive_absolute(dir)

	# drag a onto b → merge
	var half: Vector2 = Vector2(scn.csz, scn.csz) / 2.0
	scn._on_press(scn._cell_pos(a) + half)
	scn._on_release(scn._cell_pos(b) + half)
	for i in FRAMES:
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png(dir + "f%02d.png" % i)
		await create_timer(DT, true, false, true).timeout   # ignore_time_scale → samples through a hitstop freeze
	await create_timer(0.4).timeout   # let the merge fully settle before the next pass
