extends SceneTree
## Dev tool (run via engine/tools/quiet_godot.sh): screenshot the maps 2–5 reward streams on the habitat
## surfaces. Stands up ALL FIVE home maps as fully restored, places spirits on each, saturates idle
## production (so every Collect reads a real amount), and stocks generator-boost charges (map 3). Captures
## (1) the map-select CAROUSEL (the five habitat cards, each with its own reward label + Collect), and
## (2) the pond (map 3) management dialog showing the "Use boost" affordance.
##   quiet_godot.sh --path . -s res://games/grove/tools/reward_streams_shot.gd -- <out_dir>
## Mirrors residents_shot.gd's quiet-capture header (REFUSES unless override.cfg exists). Parallel-safe.

const Save = preload("res://engine/scripts/core/save.gd")
const G = preload("res://engine/scripts/core/content.gd")
const Habitat = preload("res://engine/scripts/core/habitat.gd")
const MapScene = preload("res://engine/scripts/scenes/map.gd")

func _initialize() -> void:
	if not FileAccess.file_exists("res://override.cfg"):
		print("REFUSED: real-renderer tools must run via engine/tools/quiet_godot.sh")
		quit(2)
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true, 0)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	var args := OS.get_cmdline_user_args()
	var out_dir: String = (args[0] if args.size() >= 1 else "/tmp/tu_reward_out").trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(out_dir)

	var dir := "/tmp/tu_rewardshot/"
	if DirAccess.dir_exists_absolute(dir):
		for fn in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir + fn)
	else:
		DirAccess.make_dir_recursive_absolute(dir)
	Save.configure_for_test(dir)

	# stand up ALL five home maps as complete: every spot restored + every gate delivered.
	var g := Save.grove()
	var unl := {}
	var gates := []
	for z in G.MAPS.size():
		for sp in G.MAPS[z].spots:
			unl[String(sp.id)] = true
		gates.append(z)
	g["unlocks"] = unl
	g["gates"] = gates
	g["last_map"] = String(G.MAPS[0].id)
	g["exp"] = 60
	g["boost_charges"] = 3                                    # map 3 stock so "Use boost" shows
	var claimed := {}                                        # mark every unlock gift claimed → no celebration dialog over the shot
	for z in G.MAPS.size():
		claimed[String(G.MAPS[z].id)] = true
	g["task_reward"] = claimed
	Save.grove_write()
	Save.add_coins(800)
	Save.add_diamonds(20)

	# place spirits on every map (count drives map-5 chest size; tiers drive cadence) + a couple in hand.
	var counts := [2, 2, 2, 6, 4]                            # farmhouse, barn, pond, orchard, meadow
	var now := Time.get_unix_time_from_system()
	var hab_prod := {}
	for z in G.MAPS.size():
		var mid := String(G.MAPS[z].id)
		for i in int(counts[z]):
			Habitat.hand_add("moss", 1 + (i % 3))
			Habitat.place(mid, 0)
		hab_prod[mid] = {"acc": 0.0, "last": now - 1_000_000.0}   # saturate every map's pending
	Save.grove()["hab_prod"] = hab_prod
	Habitat.hand_add("acorn", 2)
	Habitat.hand_add("lantern", 2)
	Save.grove_write()

	# ground-truth print: placed count, reward, and the amount a collect would bank, per map
	for z in G.MAPS.size():
		var mid := String(G.MAPS[z].id)
		print("  map %d %s: placed=%d reward=%s pending=%.2f" % [
			z, mid, Habitat.placed(mid).size(), Habitat.reward_currency(mid), Habitat.pending(mid)])

	MapScene._login_shown_launch = true
	var scn = load("res://engine/scenes/Map.tscn").instantiate()
	root.add_child(scn)
	current_scene = scn
	await create_timer(0.7).timeout

	# (1) the map-select carousel — all five habitat cards with their per-map reward + Collect
	scn._open_select()
	await create_timer(0.7).timeout
	RenderingServer.force_draw()
	var e1 := root.get_texture().get_image().save_png(out_dir + "reward_carousel.png")

	# (2) the pond (map 3) dialog — the "Use boost" affordance + a boost Collect
	scn._open_map(2)
	await create_timer(0.4).timeout
	scn._open_residents_dialog()
	await create_timer(0.6).timeout
	RenderingServer.force_draw()
	var e2 := root.get_texture().get_image().save_png(out_dir + "reward_pond_dialog.png")

	# (3) the meadow (map 5) dialog — the resident-chest Collect
	scn._close_residents_dialog()
	scn._open_map(4)
	await create_timer(0.4).timeout
	scn._open_residents_dialog()
	await create_timer(0.6).timeout
	RenderingServer.force_draw()
	var e3 := root.get_texture().get_image().save_png(out_dir + "reward_meadow_dialog.png")

	print("SHOT carousel=%s(%d) pond=%s(%d) meadow=%s(%d)" % [
		out_dir + "reward_carousel.png", e1,
		out_dir + "reward_pond_dialog.png", e2,
		out_dir + "reward_meadow_dialog.png", e3])
	quit()
