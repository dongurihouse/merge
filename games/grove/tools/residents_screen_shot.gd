extends SceneTree
## Dev tool (run via engine/tools/quiet_godot.sh): screenshot the Residents HUB screen
## (engine/scenes/Residents.tscn) — the habitat management surface of the residents expansion.
##   quiet_godot.sh --path . -s res://games/grove/tools/residents_screen_shot.gd -- <out.png>
## Seeds map 0 (hub Farm) COMPLETE, places a couple of spirits + leaves a couple in hand, then
## captures the screen. Mirrors residents_shot.gd's quiet-capture header (REFUSES unless override.cfg
## exists — the born-minimized window must come from quiet_godot.sh, not in-script flags).
## Parallel-safe (own temp save).

const Save = preload("res://engine/scripts/core/save.gd")
const G = preload("res://engine/scripts/core/content.gd")
const Habitat = preload("res://engine/scripts/core/habitat.gd")

func _initialize() -> void:
	if not FileAccess.file_exists("res://override.cfg"):
		print("REFUSED: real-renderer tools must run via engine/tools/quiet_godot.sh")
		quit(2)
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true, 0)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() >= 1 else "/tmp/residents_screen.png"

	var dir := "/tmp/tu_residentsscreenshot/"
	if DirAccess.dir_exists_absolute(dir):
		for fn in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir + fn)
	else:
		DirAccess.make_dir_recursive_absolute(dir)
	Save.configure_for_test(dir)

	# stand map 0 (hub) up as COMPLETE so its habitat shows, and seed a populated state.
	var z := G.hub_map()
	var g := Save.grove()
	var unl := {}
	for sp in G.MAPS[z].spots:
		unl[String(sp.id)] = true
	g["unlocks"] = unl
	g["gates"] = [z]
	Save.grove_write()
	Save.add_coins(800)
	var mid := String(G.MAPS[z].id)
	# place a few spirits on the hub map, and leave a couple in hand to show both surfaces.
	for spec in [["moss", 1], ["acorn", 2], ["lantern", 1]]:
		Habitat.hand_add(String(spec[0]), int(spec[1]))
		Habitat.place(mid, 0)
	Habitat.hand_add("moss", 1)
	Habitat.hand_add("moss", 1)
	Habitat.hand_add("acorn", 1)

	var scn = load("res://engine/scenes/Residents.tscn").instantiate()
	root.add_child(scn)
	current_scene = scn
	await create_timer(0.7).timeout
	RenderingServer.force_draw()                # minimized windows can serve a stale frame — force a fresh draw
	var img := root.get_texture().get_image()
	var e := img.save_png(out)
	print("SHOT residents=%s (err %d) placed=%d hand=%d" % [out, e, Habitat.placed(mid).size(), Habitat.hand().size()])
	quit()
