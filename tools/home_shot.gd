extends SceneTree
## Dev tool (run via tools/quiet_godot.sh): screenshot the Home scene in a state.
##   quiet_godot.sh --path . -s res://tools/home_shot.gd -- <mode> <out.png>
## modes: fresh | interior (alias closeup) | progress | shop | confirm

const Save = preload("res://engine/scripts/save.gd")
const G = preload("res://engine/scripts/content.gd")

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
			load("res://engine/scripts/ambient.gd").forced_weather = String(wa).split("=")[1]
		if String(wa) == "place=1":
			load("res://engine/scripts/debug.gd").force = true   # show the debug placement editor chrome
	var mode: String = args[0] if args.size() >= 1 else "fresh"
	var out: String = args[1] if args.size() >= 2 else "/tmp/home_%s.png" % mode
	if args.size() >= 3 and "x" in args[2]:
		# the engine re-applies the project size on the first frames — set ours after
		await create_timer(0.2).timeout
		var wh := args[2].split("x")
		DisplayServer.window_set_size(Vector2i(int(wh[0]), int(wh[1])))
		await create_timer(0.2).timeout

	var dir := "/tmp/tu_homeshot_%s/" % mode
	if DirAccess.dir_exists_absolute(dir):
		for fn in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir + fn)
	else:
		DirAccess.make_dir_recursive_absolute(dir)
	Save.configure_for_test(dir)

	match mode:
		"spirits":
			var gs := Save.grove()
			var ful := {}
			for sp in G.ZONES[0].spots:
				ful[String(sp.id)] = true
			gs["unlocks"] = ful
			Save.grove_write()
		"calmbreeze":
			Save.set_setting("calm", true)
			var gc := Save.grove()
			gc["winback_until"] = Time.get_unix_time_from_system() + 60.0
			Save.grove_write()
		"closeup", "progress":
			Save.add_stars(20)
			var g := Save.grove()
			if mode == "progress":
				g["unlocks"] = {"fh_chest": true, "fh_bed": true, "fh_table": true}
				g["custom"] = {"fh_bed": "gem", "fh_table": "coin"}
				g["exp"] = 90
			else:
				g["unlocks"] = {"fh_chest": true}    # owned → its customize list opens
				g["exp"] = 30
			Save.grove_write()
		"owned":                                  # Q4/AD: a fully-restored room (any pzone)
			var go := Save.grove()
			var ul := {}
			for z in G.ZONES.size():
				for sp in G.ZONES[z].spots:
					ul[String(sp.id)] = true
			go["unlocks"] = ul
			go["exp"] = 400
			Save.grove_write()

	var scn = load("res://engine/scenes/Home.tscn").instantiate()
	root.add_child(scn)
	current_scene = scn
	await create_timer(0.5).timeout
	if mode == "fullmap":
		# M acceptance: the WHOLE 2160×2880 vista at 0.5 in one 1080×1440 frame —
		# all five zones on their painted clearings at a glance
		scn.vista.scale = Vector2(0.5, 0.5)
		scn.vista.position = Vector2.ZERO
		await create_timer(0.3).timeout
	var pzone := 0                        # which zone's room to open (debug: any, even locked)
	for wa in args:
		if String(wa).begins_with("pzone="):
			pzone = int(String(wa).split("=")[1])
	if mode == "interior" or mode == "closeup" or mode == "progress" or mode == "owned":
		scn._open_interior(pzone)         # walk inside (order K)
		await create_timer(0.6).timeout
		if mode == "progress":            # + the inline customize strip, open
			scn._customize_spot = "fh_chest"
			scn._build_interior()
			await create_timer(0.3).timeout
	elif mode == "shop" or mode == "confirm":
		Save.add_diamonds(40)
		load("res://engine/scripts/shop.gd").open(scn, {"refresh": func() -> void: pass})
		await create_timer(0.4).timeout
		if mode == "confirm":
			# press the first cash pack card → its confirm popup
			var overlay: Control = scn.get_child(scn.get_child_count() - 1)
			for b in overlay.find_children("*", "Button", true, false):
				if b.has_meta("shop_cash"):
					(b as Button).pressed.emit()
					break
			await create_timer(0.4).timeout
	elif mode == "settings":
		scn._open_settings()
		await create_timer(0.4).timeout

	# minimized windows occasionally serve a STALE frame (the capture then shows
	# the previous screen) — force a fresh draw right before reading the texture
	RenderingServer.force_draw()
	var img := root.get_texture().get_image()
	# R3 --crop: `crop=x,y,w,h` saves a ZOOMED (3×, nearest) cutout of one element
	# so eng can LOOK at the exact pixels before writing DONE (eng rule 14).
	for wa in args:
		if String(wa).begins_with("crop="):
			var r := String(wa).substr(5).split(",")
			var cr := img.get_region(Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3])))
			cr.resize(int(r[2]) * 3, int(r[3]) * 3, Image.INTERPOLATE_NEAREST)
			img = cr
	var err := img.save_png(out)
	print("SHOT saved=%s err=%d stars=%d exp=%d" % [out, err, Save.stars(), scn.exp_points])
	quit()
