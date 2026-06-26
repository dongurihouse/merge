extends SceneTree
## Dev tool (run via engine/tools/quiet_godot.sh): screenshot the Residents habitat screen.
##   quiet_godot.sh --path . -s res://games/grove/tools/residents_screen_shot.gd -- <out.png>
## Seeds a completed Farmhouse, a few placed residents, and a couple in hand, then captures the
## management screen. Parallel-safe (own temp save).

const Save = preload("res://engine/scripts/core/save.gd")
const G = preload("res://engine/scripts/core/content.gd")
const Habitat = preload("res://engine/scripts/core/habitat.gd")

func _initialize() -> void:
	if not FileAccess.file_exists("res://override.cfg"):
		print("REFUSED: real-renderer tools must run via engine/tools/quiet_godot.sh (born-minimized")
		print("window; in-script flags are too late and flash/steal focus).")
		quit(2)
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true, 0)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() >= 1 else "/tmp/residents_screen.png"

	var dir := "/tmp/tu_residents_screen_shot/"
	if DirAccess.dir_exists_absolute(dir):
		for fn in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir + fn)
	else:
		DirAccess.make_dir_recursive_absolute(dir)
	Save.configure_for_test(dir)

	var z := 0
	var g := Save.grove()
	var unl := {}
	for sp in G.MAPS[z].spots:
		unl[String(sp.id)] = true
	g["unlocks"] = unl
	g["gates"] = [z]
	g["exp"] = 80
	Save.grove_write()
	Save.add_coins(120)

	var mid := String(G.MAPS[z].id)
	for spec in [["moss", 1], ["acorn", 2], ["lantern", 3]]:
		Habitat.hand_add(String(spec[0]), int(spec[1]))
		Habitat.place(mid, 0)
	Habitat._settle(mid, 1_000_000.0)
	Habitat.hand_add("moss", 1)
	Habitat.hand_add("acorn", 1)

	var scn = load("res://engine/scenes/Residents.tscn").instantiate()
	root.add_child(scn)
	current_scene = scn
	await create_timer(0.7).timeout

	RenderingServer.force_draw()
	var img := root.get_texture().get_image()
	var err := img.save_png(out)
	print("SHOT saved=%s err=%d hand=%d placed=%d" % [out, err, Habitat.hand().size(), Habitat.placed(mid).size()])
	quit()
