extends SceneTree
## Dev tool (run via engine/tools/quiet_godot.sh): screenshot the Map scene (home map) in a state.
##   quiet_godot.sh --path . -s res://games/grove/tools/map_shot.gd -- <mode> <out.png>
## modes: fresh | select | closeup | progress | owned | shop | settings | spirits | vault

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
		"select":
			# the place-picker capture needs no special save setup — unless `owned=1` is passed,
			# which restores EVERY map's spots so completed maps render as the habitat card.
			for wa in args:
				if String(wa) == "owned=1":
					var gsel := Save.grove()
					var ulsel := {}
					var gates := []
					var claimed := {}
					for z in G.MAPS.size():
						for sp in G.MAPS[z].spots:
							ulsel[String(sp.id)] = true
						gates.append(z)               # record each map's gate so it reads as COMPLETE (habitat card)
						claimed[String(G.MAPS[z].id)] = true   # pre-claim unlock rewards so no popup covers the picker
					gsel["unlocks"] = ulsel
					gsel["gates"] = gates
					gsel["task_reward"] = claimed
					gsel["exp"] = 400
					Save.grove_write()
		"hub":
			# the bare hub chrome for UI review — wallet + bottom nav + side rail + level badge,
			# no overlays. Unlock the hub spots, seed the reference wallet (★256 🪙132 💧87) and a
			# mid level, and mark today claimed so the daily-login popup never covers the screen.
			var gh := Save.grove()
			var fh := {}
			for sp in G.MAPS[G.hub_map()].spots:
				fh[String(sp.id)] = true
			gh["unlocks"] = fh
			gh["exp"] = 200
			Save.grove_write()
			Save.add_exp(256)
			Save.add_coins(132)
			Save.add_diamonds(87)
			load("res://engine/scripts/core/login.gd").claim_today()
			# 3 unread letters so the Inbox count badge reads "3" (home.png).
			var Inbox = load("res://engine/scripts/core/inbox.gd")
			for _i in 3:
				Inbox.add({"title": "Gift", "body": "A little something.", "icon": "coin", "reward": {"coins": 50}, "read": false})
		"spirits":
			var gs := Save.grove()
			var ful := {}
			for sp in G.MAPS[0].spots:
				ful[String(sp.id)] = true
			gs["unlocks"] = ful
			Save.grove_write()
		"vault2x":
			# T45: the hub with the piggy-VAULT button (pip lit); the jar fills past claimable (the pip).
			# (The old hub-collect 2x doubler is gone — it now lives on the board quest reward.)
			var gv := Save.grove()
			var fv := {}
			for sp in G.MAPS[G.hub_map()].spots:
				fv[String(sp.id)] = true
			gv["unlocks"] = fv
			gv["exp"] = 20
			Save.grove_write()
			load("res://engine/scripts/core/vault.gd").skim(load("res://games/grove/grove_data.gd").VAULT_CLAIM_MIN * 4 * load("res://games/grove/grove_data.gd").VAULT_SKIM_DEN)
		"login":
			# T45: the daily-login calendar AUTO-POPUP on a fresh day. One hub spot owned (past the
			# cold FTUE) + today unclaimed (the default) → the _ready-driven popup fires.
			var gl := Save.grove()
			gl["unlocks"] = {String(G.MAPS[G.hub_map()].spots[0].id): true}
			gl["exp"] = 6
			Save.grove_write()
		"closeup", "progress":
			Save.add_exp(20)
			var g := Save.grove()
			# Seed by the hub's REAL spot ids — content.gd remaps the hub to a vine map (farmhouse_r0..r6),
			# so the retired fh_* ids matched nothing and the home rendered fully overgrown. Mark the first N
			# owned (3 for progress, 1 for closeup) and set exp to the NEXT spot's unlock threshold, so the
			# bottom restore badge reads a representative ready state over a partially-restored home.
			var hub := G.hub_map()
			var n_owned: int = mini(3 if mode == "progress" else 1, G.MAPS[hub].spots.size())
			var seeded := {}
			for k in n_owned:
				seeded[String(G.MAPS[hub].spots[k].id)] = true
			g["unlocks"] = seeded
			g["exp"] = G.spot_unlock_exp(hub, n_owned)   # the next unclaimed spot's threshold
			Save.grove_write()
		"owned":                                  # Q4/AD: a fully-restored room (any pmap)
			var go := Save.grove()
			var ul := {}
			var ogates := []
			var oclaimed := {}
			for z in G.MAPS.size():
				for sp in G.MAPS[z].spots:
					ul[String(sp.id)] = true
				ogates.append(z)                          # record gates so completed maps are POPULATABLE (spirits dock shows)
				oclaimed[String(G.MAPS[z].id)] = true     # pre-claim unlock rewards so no popup covers the map
			go["unlocks"] = ul
			go["gates"] = ogates
			go["task_reward"] = oclaimed
			go["exp"] = 40
			Save.grove_write()
			# seed in-hand + placed spirits so the residents dialog renders fully (for UI capture): a
			# mergeable pair left in hand + a few placed on the hub.
			var Habitat = load("res://engine/scripts/core/habitat.gd")
			var hub_id := String(G.MAPS[G.hub_map()].id)
			Habitat.hand_add("ember", 1) ; Habitat.hand_add("ember", 1) ; Habitat.hand_add("ember", 1)
			Habitat.hand_add("sprout", 2) ; Habitat.hand_add("sprout", 2)
			Habitat.place(hub_id, 0) ; Habitat.place(hub_id, 0) ; Habitat.place(hub_id, 0)   # 3 Ember placed; 2 Sprout left in hand

	# noftue=1: suppress the daily-login calendar auto-popup so a map-view capture shows the bare map,
	# not a popup. Must run after Save.configure_for_test (above).
	for wa in args:
		if String(wa) == "noftue=1":
			load("res://engine/scripts/core/login.gd").claim_today()

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
		for wa in args:
			if String(wa) == "residents=1":   # residents management now lives in the place-picker (housed strip + in-hand column)
				scn._open_select()
				await create_timer(0.4).timeout
	elif mode == "watershop":
		# the WATER stall opened from the HUB by pressing the real water-pill "+". Water is Save-backed,
		# so the stall is host-agnostic — the same free refill + 💎 fill show here as on the board.
		Save.add_diamonds(40)
		var cluster: Control = scn._hud_panels[0]               # hud.wallet — the Water·Coin·Gem cluster
		var water_pill_panel: Control = cluster.get_child(0)    # water is first
		var water_button := water_pill_panel as Button
		if water_button == null:
			water_button = water_pill_panel.find_child("GoldCurrencyPill", true, false) as Button
		print("MAP WATERSHOP probe: button=%s" % water_button)
		water_button.pressed.emit()
		await create_timer(0.6).timeout
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
	elif mode == "vault":
		load("res://engine/scripts/core/vault.gd").skim(100000)   # seed a claimable jar for a representative capture
		scn._open_vault()
		await create_timer(0.5).timeout

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
	print("SHOT saved=%s err=%d exp=%d" % [out, err, Save.exp_total()])
	quit()
