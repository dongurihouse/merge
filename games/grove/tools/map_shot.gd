extends SceneTree
## Dev tool (run via engine/tools/quiet_godot.sh): screenshot the Map scene (home map) in a state.
##   quiet_godot.sh --path . -s res://games/grove/tools/map_shot.gd -- <mode> <out.png>
## modes: fresh | select | closeup | progress | owned | shop | settings | spirits

const Save = preload("res://engine/scripts/core/save.gd")
const G = preload("res://engine/scripts/core/content.gd")

func _initialize() -> void:
	if not FileAccess.file_exists("res://override.cfg"):
		print("REFUSED: real-renderer tools must run via engine/tools/quiet_godot.sh (born-minimized")
		print("window; in-script flags are too late and flash/steal focus). See ~/.claude/CLAUDE.md")
		quit(2)
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true, 0)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	var args := OS.get_cmdline_user_args()
	for wa in args:
		if String(wa).begins_with("weather="):
			load("res://engine/scripts/ui/ambient.gd").forced_weather = String(wa).split("=")[1]
		if String(wa) == "place=1":
			load("res://engine/scripts/ui/debug.gd").force = true   # show the debug placement editor chrome
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
			for sp in G.MAPS[0].spots:
				ful[String(sp.id)] = true
			gs["unlocks"] = ful
			Save.grove_write()
		"vault2x":
			# T45: the hub with the piggy-VAULT button (pip lit) + a 2×-collect DOUBLER offer.
			# Restore every hub yield building to L1, back-date the collect clock so the open
			# sweeps a real yield (→ the offer fires), and fill the jar past claimable (→ the pip).
			var gv := Save.grove()
			var fv := {}
			for sp in G.MAPS[G.hub_map()].spots:
				fv[String(sp.id)] = true
				Save.set_spot_level(String(sp.id), 1)
			gv["unlocks"] = fv
			gv["stars_earned"] = 20
			Save.grove_write()
			Save.set_hub_collected_at(0.0)                # long-ago → the open collects a real N (→ the 2× offer)
			Save.mark_spotlight_seen("shop")             # don't let the FTUE shop spotlight dim this composite
			load("res://engine/scripts/core/vault.gd").skim(load("res://games/grove/grove_data.gd").VAULT_CLAIM_MIN * 4 * load("res://games/grove/grove_data.gd").VAULT_SKIM_DEN)
		"login":
			# T45: the daily-login calendar AUTO-POPUP on a fresh day. One hub spot owned (past the
			# cold FTUE) + the shop spotlight pre-seen (so it doesn't claim the overlay slot) + today
			# unclaimed (the default) → the _ready-driven popup fires.
			var gl := Save.grove()
			gl["unlocks"] = {String(G.MAPS[G.hub_map()].spots[0].id): true}
			gl["stars_earned"] = 6
			Save.grove_write()
			Save.mark_spotlight_seen("shop")
		"calmbreeze":
			Save.set_setting("calm", true)
			var gc := Save.grove()
			gc["winback_until"] = Time.get_unix_time_from_system() + 60.0
			Save.grove_write()
		"closeup", "progress":
			Save.add_stars(20)
			var g := Save.grove()
			if mode == "progress":
				g["unlocks"] = {"fh_hearth": true, "fh_kitchen": true, "fh_well": true}
				g["custom"] = {"fh_kitchen": "gem", "fh_well": "coin"}
				g["stars_earned"] = 9
			else:
				g["unlocks"] = {"fh_hearth": true}   # owned → its customize strip opens
				g["stars_earned"] = 3
			Save.grove_write()
		"owned":                                  # Q4/AD: a fully-restored room (any pmap)
			var go := Save.grove()
			var ul := {}
			for z in G.MAPS.size():
				for sp in G.MAPS[z].spots:
					ul[String(sp.id)] = true
			go["unlocks"] = ul
			go["stars_earned"] = 40
			Save.grove_write()

	var scn = load("res://engine/scenes/Map.tscn").instantiate()
	root.add_child(scn)
	current_scene = scn
	await create_timer(0.5).timeout
	var pmap := 0                         # which map to open (debug: any, even locked)
	for wa in args:
		if String(wa).begins_with("pmap="):
			pmap = int(String(wa).split("=")[1])
	if mode == "select":
		scn._open_select()                # the discrete map-select screen
		await create_timer(0.4).timeout
	elif mode == "vault2x":
		# _ready already opened the frontier (the HUB while its gate is pending) and auto-collected,
		# arming the deferred 2× offer — just let the collect-FX + the offer card finish building.
		# (Re-opening the hub here would reset the clock to a 0-yield collect and drop the offer.)
		await create_timer(0.5).timeout
	elif mode == "login":
		await create_timer(0.6).timeout   # the calendar popup is deferred two frames from _ready
	elif mode == "closeup" or mode == "progress" or mode == "owned":
		scn._open_map(pmap)               # the one-image map view (spots on the image)
		await create_timer(0.5).timeout
		if mode == "progress":            # + the inline customize strip, open
			scn._customize_spot = "fh_hearth"
			scn._build_map()
			await create_timer(0.3).timeout
	elif mode == "shop" or mode == "confirm":
		Save.add_diamonds(40)
		Save.add_coins(1200)            # T40: so the coin-priced featured offers read un-dimmed
		load("res://engine/scripts/ui/shop.gd").open(scn, {"refresh": func() -> void: pass})
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
	print("SHOT saved=%s err=%d stars=%d earned=%d" % [out, err, Save.stars(), int(Save.grove().get("stars_earned", 0))])
	quit()
