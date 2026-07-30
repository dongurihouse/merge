extends SceneTree
## Dev tool (run via engine/tools/quiet_godot.sh): screenshot the Map scene (home map) in a state.
##   quiet_godot.sh --path . -s res://games/grove/tools/map_shot.gd -- <mode> <out.png>
## modes: fresh | select | maps | closeup | progress | owned | shop | settings | spirits | vault | mail
## extra args: `maps nodaily=1` (no login popup over the cards) · `select owned=1` · `closeup residents=1`
## BATCH IT: several captures in one launch is `make shot-batch PLAN=<file>` (this tool is batch-safe).

const Base = preload("res://engine/tools/shot_base.gd")
const Save = preload("res://engine/scripts/core/save.gd")
const G = preload("res://engine/scripts/core/content.gd")

func _initialize() -> void:
	var ctx := await Base.begin(self, {
		"tool": "home",
		"default_mode": "fresh",
		"default_out": "/tmp/home_%s.png",
		"save_dir": "/tmp/tu_homeshot_%s/",
	})
	if ctx.is_empty():
		return                        # refused: begin() printed why and quit(2)
	var args: Array = ctx["args"]
	var mode: String = ctx["mode"]
	var out: String = ctx["out"]
	if Base.flag(args, "place"):
		load("res://engine/scripts/ui/debug.gd").force = true   # show the debug placement editor chrome

	match mode:
		"select":
			# the place-picker capture needs no special save setup — unless `owned=1` is passed,
			# which restores EVERY map's spots so the bucket dock opens at full capacity.
			for wa in args:
				if String(wa) == "owned=1":
					var gsel := Save.grove()
					var ulsel := {}
					var gates := []
					var claimed := {}
					for z in G.MAPS.size():
						for sp in G.MAPS[z].spots:
							ulsel[String(sp.id)] = true
						for c in G.clusters(z):
							ulsel[String((c as Dictionary).id)] = true   # full cluster unlock -> all bucket cells
						gates.append(z)               # record each map's gate so it reads as COMPLETE
						claimed[String(G.MAPS[z].id)] = true   # pre-claim unlock rewards so no popup covers the picker
					gsel["unlocks"] = ulsel
					gsel["gates"] = gates
					gsel["task_reward"] = claimed
					Save.grove_write()
		"maps":
			# the MAPS gallery page in a representative mid-game state: a few Fairy Hollow clusters
			# unlocked so the featured card reads in-progress (n/m).
			Save.earn_coins(2000)
			var gm := Save.grove()
			var ulm: Dictionary = gm.get("unlocks", {})
			var clm: Array = G.clusters(0)
			for i in mini(2, clm.size()):
				ulm[String((clm[i] as Dictionary).id)] = true
			gm["unlocks"] = ulm
			Save.grove_write()
			# By DEFAULT this capture keeps the daily-login popup that auto-pops over the gallery — it is a
			# real state, and one sheet of dialog paper in front of a page of card paper is the single most
			# useful frame for reviewing the shared paper edge. `nodaily=1` marks today claimed instead (the
			# same thing `hub` does) so the CARDS can be read unobstructed. Seeding the unlocks above is
			# what arms the popup at all, so both halves live here.
			for wa in args:
				if String(wa) == "nodaily=1":
					load("res://engine/scripts/core/login.gd").claim_today()
		"hub":
			# the bare hub chrome for UI review — wallet + bottom nav + side rail + level badge,
			# no overlays. Unlock the hub spots, seed the reference wallet (🪙132 💎87) and a mid
			# level, and mark today claimed so the daily-login popup never covers the screen.
			# The level badge reads the COIN clock (content.level ← Save.coins_earned_lifetime), so the
			# mid level is seeded there; the retired grove["exp"] left this capture stuck at Level 1.
			var gh := Save.grove()
			var fh := {}
			for sp in G.MAPS[G.hub_map()].spots:
				fh[String(sp.id)] = true
			gh["unlocks"] = fh
			gh["coins_earned"] = G.coins_at_level(12)   # a mid level for the badge (the hub's own clusters span L1-28)
			Save.grove_write()
			Save.add_coins(132)
			Save.add_diamonds(87)
			load("res://engine/scripts/core/login.gd").claim_today()
			# 3 unread letters so the Inbox count badge reads "3" (home.png).
			var Inbox = load("res://engine/scripts/core/inbox.gd")
			for _i in 3:
				Inbox.add({"title": "Gift", "body": "A little something.", "icon": "coin", "reward": {"coins": 50}, "read": false})
		"built":
			# the home part-way through the cover-up sequence: several regions revealed, the next
			# cluster's lock badge lit; wallet + clock funded so that next region reads unlockable.
			Save.earn_coins(2000)                 # organic -> coins + a high level
			var gb := Save.grove()
			var ulb: Dictionary = gb.get("unlocks", {})
			var clb: Array = G.clusters(0)
			for i in mini(4, clb.size()):
				ulb[String((clb[i] as Dictionary).id)] = true
			gb["unlocks"] = ulb
			Save.grove_write()
		"spirits":
			# open the resident bucket by completing the first two scenes (cells come from completed
			# scenes), then seed a few placed + in-hand spirits so the centered dock renders fully.
			Save.earn_coins(2000)
			var gsp := Save.grove()
			var ulsp: Dictionary = gsp.get("unlocks", {})
			for zc in [0, 1]:
				for c in G.clusters(zc):
					ulsp[String((c as Dictionary).id)] = true
			gsp["unlocks"] = ulsp
			Save.grove_write()
			var Bkt := load("res://engine/scripts/core/bucket.gd")
			Bkt.hand_add("coin", 2) ; Bkt.hand_add("coin", 2)
			Bkt.hand_add("water", 1)
			Bkt.place(0) ; Bkt.place(0)
		"vault2x":
			# T45: the hub with the piggy-VAULT button (pip lit); the jar fills past claimable (the pip).
			# (The old hub-collect 2x doubler is gone — it now lives on the board quest reward.)
			var gv := Save.grove()
			var fv := {}
			for sp in G.MAPS[G.hub_map()].spots:
				fv[String(sp.id)] = true
			gv["unlocks"] = fv
			Save.grove_write()
			load("res://engine/scripts/core/vault.gd").skim(load("res://games/grove/grove_data.gd").VAULT_CLAIM_MIN * 4 * load("res://games/grove/grove_data.gd").VAULT_SKIM_DEN)
		"login":
			# T45: the daily-login calendar AUTO-POPUP on a fresh day. One hub spot owned (past the
			# cold FTUE) + today unclaimed (the default) → the _ready-driven popup fires.
			var gl := Save.grove()
			gl["unlocks"] = {String(G.MAPS[G.hub_map()].spots[0].id): true}
			Save.grove_write()
		"closeup", "progress":
			# Mark the first N hub spots owned (3 for progress, 1 for closeup) by the hub's REAL spot ids.
			# Readiness is seeded on the COIN clock: the per-spot EXP ladder this used to set
			# (G.spot_unlock_exp / map_next_unlock) is DEAD — it has no live caller, and a region now opens
			# on its cluster's level floor + coin price (G.cluster_ready ← map._on_cluster_tap). Banking past
			# both makes the bottom restore badge read a representative ready state.
			var g := Save.grove()
			var hub := G.hub_map()
			var n_owned: int = mini(3 if mode == "progress" else 1, G.MAPS[hub].spots.size())
			var seeded := {}
			for k in n_owned:
				seeded[String(G.MAPS[hub].spots[k].id)] = true
			g["unlocks"] = seeded
			Save.grove_write()
			Save.earn_coins(G.coins_at_level(6))   # L6 · 25🪙 — past the first hollow clusters' floors + costs
		"owned":                                  # Q4/AD: a fully-restored room (any pmap)
			var go := Save.grove()
			var ul := {}
			var ogates := []
			var oclaimed := {}
			for z in G.MAPS.size():
				for sp in G.MAPS[z].spots:
					ul[String(sp.id)] = true
				# the coverup pages key off CLUSTER ids now — seed those too or the scene stays overgrown
				for c in G.MAPS[z].get("clusters", []):
					ul[String((c as Dictionary).id)] = true
				ogates.append(z)                          # record gates so completed maps are POPULATABLE (spirits dock shows)
				oclaimed[String(G.MAPS[z].id)] = true     # pre-claim unlock rewards so no popup covers the map
			go["unlocks"] = ul
			go["gates"] = ogates
			go["task_reward"] = oclaimed
			Save.grove_write()
			# seed in-hand + placed spirits so the residents dialog renders fully (for UI capture): a
			# mergeable pair left in hand + a few placed on the hub.
			var Bucket = load("res://engine/scripts/core/bucket.gd")
			var hub_id := String(G.MAPS[G.hub_map()].id)
			Bucket.hand_add("boost", 1) ; Bucket.hand_add("boost", 1) ; Bucket.hand_add("boost", 1)
			Bucket.hand_add("coin", 2) ; Bucket.hand_add("coin", 2)
			Bucket.place(0) ; Bucket.place(0) ; Bucket.place(0)   # 3 boost-kin placed; 2 coin-kin left in hand

	# noftue=1: suppress the daily-login calendar auto-popup so a map-view capture shows the bare map,
	# not a popup. Must run after Save.configure_for_test (above).
	# page=<map id>: boot on that picture-book page (writes last_map; the page must be unlocked).
	for wa in args:
		if String(wa) == "noftue=1":
			load("res://engine/scripts/core/login.gd").claim_today()
		elif String(wa).begins_with("unlock="):
			# seed a PARTIAL cluster unlock (comma-separated cluster ids) to review the reveal state
			var gu := Save.grove()
			var ulu: Dictionary = gu.get("unlocks", {})
			for cid in String(wa).substr(7).split(","):
				if String(cid) != "":
					ulu[String(cid)] = true
			gu["unlocks"] = ulu
			Save.grove_write()
		elif String(wa).begins_with("page="):
			# boot on that picture-book page: the decorate-jump static is the boot-map lever
			load("res://engine/scripts/scenes/map.gd").decorate_map = String(wa).get_slice("=", 1)

	var scn = load("res://engine/scenes/Map.tscn").instantiate()
	root.add_child(scn)
	current_scene = scn
	await create_timer(0.5).timeout
	var pmap := 0                         # which map to open (debug: any, even locked)
	for wa in args:
		if String(wa).begins_with("pmap="):
			pmap = int(String(wa).split("=")[1])
	if mode == "maps":
		scn._open_maps()                  # the cards-only MAPS gallery
		await create_timer(0.4).timeout
	elif mode == "select" or mode == "spirits":
		scn._open_select()                # the centered resident dock (the map-select column retired)
		await create_timer(0.4).timeout
	elif mode == "vault2x":
		# _ready already opened the frontier (the HUB while its gate is pending) and auto-collected,
		# arming the deferred 2× offer — just let the collect-FX + the offer card finish building.
		# (Re-opening the hub here would reset the clock to a 0-yield collect and drop the offer.)
		await create_timer(0.5).timeout
	elif mode == "login":
		await create_timer(0.6).timeout   # the calendar popup is deferred two frames from _ready
	elif mode == "midslide":
		# a FROZEN mid-swipe frame: open a middle scene, let the idle pump pre-build both neighbours,
		# then offset the pager track partway toward the NEXT scene so the seam is on-screen. Proves the
		# per-slot clip (no cover-fill overflow bleeding across scenes). `frac=` sets how far (default 0.45).
		scn._open_map(pmap)
		await create_timer(0.9).timeout   # idle _process warms {pmap-1, pmap, pmap+1}
		var frac := 0.45
		for wa in args:
			if String(wa).begins_with("frac="):
				frac = float(String(wa).split("=")[1])
		var vw: float = scn.get_viewport_rect().size.x
		scn._track.position.x = scn._track_rest_x() - vw * frac
		await create_timer(0.15).timeout
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
	elif mode == "mail":
		# seed enough letters that the list overflows the card and scrolls, so the clip-below-title
		# behaviour is visible (rows must stop below the "MAIL" band, not ride up behind it).
		var Inbox = load("res://engine/scripts/core/inbox.gd")
		for i in 6:
			Inbox.add({"title": "Letter %d" % (i + 1), "body": "A little note for you.", "icon": "coin", "reward": {"coins": 50}, "read": false})
		load("res://engine/scripts/ui/inbox.gd").open(scn, {"refresh": func() -> void: pass})
		await create_timer(0.4).timeout
		# scroll the list part-way so rows are mid-title-band, exposing any behind-the-title bleed
		var ov: Control = scn.get_child(scn.get_child_count() - 1)
		for sc in ov.find_children("*", "ScrollContainer", true, false):
			sc.scroll_vertical = 160
			break
		await create_timer(0.3).timeout
	elif mode == "settings":
		scn._open_settings()
		await create_timer(0.4).timeout
	elif mode == "vault":
		load("res://engine/scripts/core/vault.gd").skim(100000)   # seed a claimable jar for a representative capture
		scn._open_vault()
		await create_timer(0.5).timeout

	var err := Base.capture(self, out, args)
	# Report the LIVE clock (level + the lifetime organic coins it derives from), not the retired
	# grove["exp"] — a capture that seeded the wrong clock used to print a plausible line and a Level-1 PNG.
	print("SHOT saved=%s err=%d level=%d coins_earned=%d" % [out, err, G.level(), Save.coins_earned_lifetime()])
	Base.finish(self)
