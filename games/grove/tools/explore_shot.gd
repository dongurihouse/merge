extends SceneTree
## Dev tool (run via engine/tools/quiet_godot.sh): screenshot an Explore screen.
##   quiet_godot.sh --path . -s res://games/grove/tools/explore_shot.gd -- <loadout|rush|trade> <out.png>
##   quiet_godot.sh --path . -s res://games/grove/tools/explore_shot.gd -- trade <out.png> revealed=12
## Seeds a completed map (so the spirit pool is non-empty), coins, and a run; for `rush` it lets the board
## fill for a couple of seconds before capturing. Mirrors residents_screen_shot.gd's quiet header
## (REFUSES unless override.cfg exists — the born-minimized window must come from quiet_godot.sh).
## Parallel-safe (own temp save).

const Save = preload("res://engine/scripts/core/save.gd")
const G = preload("res://engine/scripts/core/content.gd")
const Explore = preload("res://engine/scripts/core/explore.gd")

func _initialize() -> void:
	if not FileAccess.file_exists("res://override.cfg"):
		print("REFUSED: real-renderer tools must run via engine/tools/quiet_godot.sh")
		quit(2)
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true, 0)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	var args := OS.get_cmdline_user_args()
	var which: String = args[0] if args.size() >= 1 else "rush"   # rush | trade (Load out is now a map dialog)
	var out: String = args[1] if args.size() >= 2 else "/tmp/explore_%s.png" % which
	var revealed := 0
	for a in args:
		if String(a).begins_with("revealed="):
			revealed = int(String(a).split("=")[1])

	var dir := "/tmp/tu_exploreshot_%s/" % which
	if DirAccess.dir_exists_absolute(dir):
		for fn in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir + fn)
	else:
		DirAccess.make_dir_recursive_absolute(dir)
	Save.configure_for_test(dir)

	# a completed hub map → a non-empty spirit pool, plus a fat wallet for the loadout
	var z := G.hub_map()
	var g := Save.grove()
	var unl := {}
	for sp in G.MAPS[z].spots:
		unl[String(sp.id)] = true
	g["unlocks"] = unl
	g["gates"] = [z]
	Save.grove_write()
	Save.add_coins(2000)

	var path := "res://engine/scenes/ExploreRush.tscn"
	match which:
		"trade":
			Explore.begin_run({})
			# the Rewards screen converts score → spirits on open; this sets how many reels reveal
			Explore.add_score((revealed if revealed > 0 else 7) * Explore.TRADE_RATE)
			path = "res://engine/scenes/ExploreTrade.tscn"
		_:
			Explore.begin_run({"time": true, "drops": true})
			path = "res://engine/scenes/ExploreRush.tscn"

	var scn = load(path).instantiate()
	root.add_child(scn)
	current_scene = scn
	# midfall=1: clear the board, force-spawn one tile, capture it part-way through its drop (a guaranteed
	# mid-fall frame, since random sequence captures keep landing on settled tiles).
	if which == "rush":
		for a in args:
			if String(a) == "midfall=1":
				await create_timer(0.4).timeout
				scn.set_process(false)
				for r in G.ROWS:
					for c in G.COLS:
						if scn._grid[r][c] != null:
							(scn._grid[r][c].node as Node).queue_free()
							scn._grid[r][c] = null
				scn._spawn()
				await create_timer(0.12).timeout   # let the fall tween run part-way
				RenderingServer.force_draw()
				var mf := root.get_texture().get_image()
				var em := mf.save_png(out)
				print("SHOT explore/rush midfall=%s (err %d)" % [out, em])
				quit()
				return
			if String(a) == "fling=1":
				# clear the board, drop a lone tile at column 0, tap it (no match -> fling), capture mid-arc
				await create_timer(0.4).timeout
				scn.set_process(false)
				for r in G.ROWS:
					for c in G.COLS:
						if scn._grid[r][c] != null:
							(scn._grid[r][c].node as Node).queue_free()
							scn._grid[r][c] = null
				var ft = scn._make_tile(1, 1, G.ROWS - 1, 0)
				scn._grid[G.ROWS - 1][0] = {"kind": 1, "tier": 1, "node": ft}
				await create_timer(0.45).timeout   # let the spawn-fall finish
				scn._on_tile(ft)                   # fling
				await create_timer(0.18).timeout   # catch it mid-arc
				RenderingServer.force_draw()
				var ff := root.get_texture().get_image()
				var ef := ff.save_png(out)
				print("SHOT explore/rush fling=%s (err %d)" % [out, ef])
				quit()
				return
	# seq=N: dump N frames at ~0.12s intervals (catches tiles mid-fall to show the drop). Else one frame.
	var seq := 0
	for a in args:
		if String(a).begins_with("seq="):
			seq = int(String(a).split("=")[1])
	if seq > 0:
		var base := out.trim_suffix(".png")
		await create_timer(0.6).timeout                 # let a couple of tiles spawn first
		for i in seq:
			RenderingServer.force_draw()
			var fr := root.get_texture().get_image()
			fr.save_png("%s_%02d.png" % [base, i])
			await create_timer(0.12).timeout
		print("SHOT explore/%s seq=%d base=%s" % [which, seq, base])
		quit()
		return
	# rush needs a few seconds of frames to drop tiles; the others just need a layout pass
	var wait := 2.4 if which == "rush" else 0.7
	await create_timer(wait).timeout
	RenderingServer.force_draw()
	var img := root.get_texture().get_image()
	var e := img.save_png(out)
	print("SHOT explore/%s=%s (err %d)" % [which, out, e])
	quit()
