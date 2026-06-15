extends SceneTree
## Dev tool (real renderer; run via tools/quiet_godot.sh): screenshot the Grove
## in a given state.   quiet_godot.sh --path . -s res://tools/grove_shot.gd -- <mode> <out.png>
## modes: fresh | played | gate | compost | ladder | hive

const Save = preload("res://engine/scripts/core/save.gd")
const G = preload("res://engine/scripts/core/content.gd")

func _initialize() -> void:
	if not FileAccess.file_exists("res://override.cfg"):
		print("REFUSED: real-renderer tools must run via tools/quiet_godot.sh (born-minimized")
		print("window; in-script flags are too late and flash/steal focus). See ~/.claude/CLAUDE.md")
		quit(2)
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true, 0)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	var args := OS.get_cmdline_user_args()
	for wa in args:
		if String(wa).begins_with("weather="):
			load("res://engine/scripts/ui/ambient.gd").forced_weather = String(wa).split("=")[1]
	var mode: String = args[0] if args.size() >= 1 else "fresh"
	var out: String = args[1] if args.size() >= 2 else "/tmp/grove_%s.png" % mode
	if args.size() >= 3 and "x" in args[2]:
		# the engine re-applies the project size on the first frames — set ours after
		await create_timer(0.2).timeout
		var wh := args[2].split("x")
		DisplayServer.window_set_size(Vector2i(int(wh[0]), int(wh[1])))
		await create_timer(0.2).timeout

	var dir := "/tmp/tu_groveshot_%s/" % mode
	if DirAccess.dir_exists_absolute(dir):
		for fn in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir + fn)
	else:
		DirAccess.make_dir_recursive_absolute(dir)
	Save.configure_for_test(dir)

	var scn = load("res://engine/scenes/Board.tscn").instantiate()
	root.add_child(scn)
	current_scene = scn
	await create_timer(0.5).timeout
	scn.rng.seed = 7

	match mode:
		"played":
			var half: Vector2 = Vector2(scn.csz, scn.csz) / 2.0
			scn._on_press(scn._cell_pos(Vector2i(3, 2)) + half)   # merge the flowers
			scn._on_release(scn._cell_pos(Vector2i(3, 4)) + half)
			await create_timer(0.4).timeout
			for i in 5:                                            # pop a few seeds
				scn._pop_seed()
				await create_timer(0.3).timeout
			scn._on_press(scn._cell_pos(Vector2i(5, 2)) + half)   # merge the berries too
			scn._on_release(scn._cell_pos(Vector2i(5, 4)) + half)
			await create_timer(0.5).timeout
		"gate":
			Save.add_stars(5)
			scn._rebuild_givers()
			scn._update_hud()
			await create_timer(0.6).timeout
		"genpreview":
			# V1: open a path out to a line-3 (mushroom/compost) edge bramble so the
			# locked compost generator shows its greyed "after N spots" silhouette
			for cc in [Vector2i(1, 3), Vector2i(2, 3), Vector2i(2, 2), Vector2i(2, 1)]:
				scn.board.terrain[load("res://engine/scripts/core/board_model.gd").idx(cc)] = 0
			scn._rebuild_all()
			await create_timer(0.4).timeout
		"hud":
			# mid-game: FTUE long done (water shown) + leveled (Lv chip shows a real
			# value) — proves water sits in the top-right cluster next to ★🪙💎
			var gh := Save.grove()
			gh["pops"] = 30
			gh["stars_earned"] = 24
			gh["water"] = 42
			Save.grove_write()
			Save.add_stars(8)
			scn.water = 42
			scn._update_hud()
			scn._update_water_hud()
			scn._rebuild_givers()
			await create_timer(0.5).timeout
		"swap":
			# P3 proof: place two distinct items, drag one onto the other → they
			# trade places (the displaced one glides back). Captured mid-rearrange.
			var es: Array = scn.board.empty_ground_cells()
			var sc1 := Vector2i(es[0])
			var sc2 := Vector2i(es[1])
			scn.board.place(sc1, 101)         # a sapling
			scn.board.place(sc2, 401)         # a honey drop (clearly different)
			scn._rebuild_pieces()
			await create_timer(0.3).timeout
			var sh: Vector2 = Vector2(scn.csz, scn.csz) / 2.0
			scn._on_press(scn._cell_pos(sc1) + sh)
			scn._on_release(scn._cell_pos(sc2) + sh)
			await create_timer(0.25).timeout   # catch the displaced glide mid-flight
		"ladder":
			var half2: Vector2 = Vector2(scn.csz, scn.csz) / 2.0
			scn._on_press(scn._cell_pos(Vector2i(3, 2)) + half2)   # merge once: t2 seen
			scn._on_release(scn._cell_pos(Vector2i(3, 4)) + half2)
			await create_timer(0.5).timeout
			scn._open_ladder(1, 2)
			await create_timer(0.4).timeout
		"compost", "hive":
			var g := Save.grove()
			var ul := {}
			for z in (2 if mode == "compost" else 3):   # 16 → compost · +2 spots → 26 hive
				for sp in G.ZONES[z].spots:
					ul[String(sp.id)] = true
			if mode == "hive":
				ul[String(G.ZONES[3].spots[0].id)] = true
				ul[String(G.ZONES[3].spots[1].id)] = true
			g["unlocks"] = ul
			Save.grove_write()
			scn.board.set_active_gens(scn._chapter_idx())
			for r in G.ROWS:                     # clear starters so the whole ladder fits
				for c in G.COLS:
					var cl := Vector2i(r, c)
					if scn.board.is_open(cl) and scn.board.item_at(cl) > 0:
						scn.board.take(cl)
			var empties: Array = scn.board.empty_ground_cells()
			empties.sort()
			var lbase := 300 if mode == "compost" else 400   # mushroom / honey ladder
			for t in range(1, 9):
				if empties.is_empty():
					break
				scn.board.place(empties.pop_front(), lbase + t)
			scn._rebuild_all()
			await create_timer(0.6).timeout

	# minimized windows occasionally serve a STALE frame - force a fresh draw
	RenderingServer.force_draw()
	var img := root.get_texture().get_image()
	img = _maybe_crop(img, args)
	var err := img.save_png(out)
	print("SHOT saved=%s err=%d stars=%d coins=%d brambles=%d" % \
		[out, err, Save.stars(), Save.coins(), scn.board.bramble_count()])
	quit()

# R3 --crop: `crop=x,y,w,h` saves a ZOOMED (3×, nearest) cutout of one element
# so eng can LOOK at the exact pixels before writing DONE (eng rule 14).
func _maybe_crop(img: Image, args: Array) -> Image:
	for wa in args:
		if String(wa).begins_with("crop="):
			var r := String(wa).substr(5).split(",")
			var cr := img.get_region(Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3])))
			cr.resize(int(r[2]) * 3, int(r[3]) * 3, Image.INTERPOLATE_NEAREST)
			return cr
	return img
