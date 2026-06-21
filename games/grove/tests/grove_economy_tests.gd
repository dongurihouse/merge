extends "res://games/grove/tests/grove_test_base.gd"
## grove · economy — split from the grove_tests monolith; shares grove_test_base.gd.

func _initialize() -> void:
	begin("grove · economy")
	fresh("p2")
	var s2 = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(s2)
	if s2.board == null:
		s2._ready()
	ok(s2.water == G.WATER_CAP, "fresh grove starts at the water cap")
	Save.grove()["pops"] = 10                 # past the FTUE free pops (tested in P5)
	var w0: int = s2.water
	var pop_items_b := 0
	for v in s2.board.items:
		if v > 0:
			pop_items_b += 1
	s2._pop_seed()
	await create_timer(0.3).timeout
	var pop_burst := -pop_items_b
	for v in s2.board.items:
		if v > 0:
			pop_burst += 1
	ok(pop_burst >= 1, "a tap pops a burst of at least one item")
	ok(s2.water == w0 - pop_burst * G.POP_COST, "each item in the burst costs one energy")

	s2.water = 0
	var pieces_before := 0
	for v in s2.board.items:
		if v > 0:
			pieces_before += 1
	s2._pop_seed()
	await create_timer(0.25).timeout
	var pieces_after := 0
	for v in s2.board.items:
		if v > 0:
			pieces_after += 1
	ok(pieces_after == pieces_before, "no water → the satchel pops nothing")
	s2._update_water_hud()
	ok(s2.refill_btn.visible, "the free-refill offer appears on empty")
	s2._on_refill()
	ok(s2.water == G.WATER_CAP and s2.refills_used == 1, "free refill fills to cap, once counted")

	# regen: 10 simulated minutes → +5
	s2.water = 50
	s2._regen_ts = Time.get_unix_time_from_system() - 600.0
	s2._tick_water()
	ok(s2.water == 55, "regen pays +1 per 2 minutes (offline math)")

	# the per-spot water gift now pays on the HOME spot purchase (tested in 14b)

	# the burst pops above may have filled the virgin board — clear the playfield so the coin lands
	for ci in s2.board.items.size():
		if s2.board.items[ci] > 0 and not G.is_coin(s2.board.items[ci]):
			s2.board.items[ci] = 0
	s2._rebuild_pieces()

	# coins: drop → tap-collect → wallet
	var coins0 := Save.coins()
	s2._drop_coin_near(Vector2i(4, 3))
	await create_timer(0.3).timeout
	var coin_cell := Vector2i(-1, -1)
	for i in s2.board.items.size():
		if s2.board.items[i] > 0 and G.is_coin(s2.board.items[i]):
			coin_cell = BoardModel.cell_of(i)
			break
	ok(coin_cell != Vector2i(-1, -1), "a coin dropped onto the board")
	var chalf: Vector2 = Vector2(s2.csz, s2.csz) / 2.0
	s2._on_press(s2._cell_pos(coin_cell) + chalf)
	s2._on_release(s2._cell_pos(coin_cell) + chalf)
	ok(Save.coins() == coins0 + 1, "tapping a coin pockets its value")
	ok(s2.board.item_at(coin_cell) == 0, "the collected coin left the board")

	# coin merge rules (model): c1+c1 merges, c3 is capped
	var bc: BoardModel = BoardModel.new()
	bc.place(Vector2i(3, 2), 901)
	bc.place(Vector2i(3, 4), 901)
	ok(bc.can_merge(Vector2i(3, 2), Vector2i(3, 4)), "coins merge with coins")
	bc.place(Vector2i(5, 2), 903)
	bc.place(Vector2i(5, 4), 903)
	ok(not bc.can_merge(Vector2i(5, 2), Vector2i(5, 4)), "top coin (25) never merges")
	ok(bc.top_tier_cells().is_empty(), "coins are never merchant goods")

	# 11b. BURST-POP (§6) + the burst-upgrade COIN SINK — both engine-side; the grove only sets the
	# odds/scale/cost dials. One tap throws a burst that scales with the map + the paid upgrade, each
	# item costing one energy. The upgrade spends coins, raises the burst, persists, and caps.
	fresh("burst")
	var sbp = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(sbp)
	if sbp.board == null:
		sbp._ready()
	Save.grove()["pops"] = 50                 # well past the FTUE — the energy meter is on
	ok(sbp._gen_burst_level() == 0, "the burst-upgrade starts at level 0")
	Save.add_coins(10000)
	var bu_c0 := Save.coins()
	ok(sbp._upgrade_gen_burst(), "the burst-upgrade buys with coins")
	ok(Save.coins() == bu_c0 - G.burst_upgrade_cost(0), "the burst-upgrade spends coins (the sink)")
	ok(sbp._gen_burst_level() == 1, "the burst-upgrade raises the burst level")
	ok(sbp._upgrade_gen_burst() and sbp._gen_burst_level() == 2, "a second burst-upgrade stacks")
	# clear a wide-open area so the burst is bounded only by its own size (not by board space)
	for ci in sbp.board.items.size():
		if sbp.board.items[ci] > 0 and not G.is_coin(sbp.board.items[ci]):
			sbp.board.items[ci] = 0
	sbp._rebuild_pieces()
	sbp.water = G.WATER_CAP
	var bw0: int = sbp.water
	var bb := 0
	for v in sbp.board.items:
		if v > 0:
			bb += 1
	sbp._pop_seed()
	await create_timer(0.3).timeout
	var burst_got := -bb
	for v in sbp.board.items:
		if v > 0:
			burst_got += 1
	ok(burst_got >= 3, "with the upgrade a single tap throws a burst of ≥3 items (map 1, level 2)")
	ok(sbp.water == bw0 - burst_got * G.POP_COST, "each burst item costs one energy")
	# the sink caps: drive to the max level, then the upgrade refuses
	while sbp._gen_burst_level() < G.burst_upgrade_max():
		sbp._upgrade_gen_burst()
	ok(not sbp._upgrade_gen_burst(), "the burst-upgrade caps — no buy past the max level")
	# the burst level rides the save
	var saved_lvl: int = sbp._gen_burst_level()
	var sbp2 = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(sbp2)
	if sbp2.board == null:
		sbp2._ready()
	ok(sbp2._gen_burst_level() == saved_lvl, "the burst-upgrade level persists across scenes")
	sbp.queue_free()
	sbp2.queue_free()

	# 11c. The burst-upgrade coin sink refuses cleanly when broke — no level gain, no coin debt.
	# (The on-board buy PILL that used to drive this was the dark stat_chip pill — retired T48
	# ahead of the UI redesign; the sink logic above + this broke-refusal is the lasting coverage,
	# and the redesign re-surfaces a buy affordance over the same `_upgrade_gen_burst`.)
	fresh("burst_broke")
	var sbc = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(sbc)
	if sbc.board == null:
		sbc._ready()
	ok(sbc._gen_burst_level() == 0 and Save.coins() == 0, "fresh: burst level 0, no coins")
	ok(not sbc._upgrade_gen_burst(), "broke: the burst-upgrade refuses — returns false")
	ok(sbc._gen_burst_level() == 0 and Save.coins() == 0, "broke refusal leaves no level and no coin debt")
	sbc.queue_free()

	# 12. win-back: away 3 days with low water → full cap on return
	fresh("winback")
	var gw := Save.grove()
	gw["board"] = BoardModel.new().to_dict()
	gw["water"] = 10
	gw["regen_ts"] = Time.get_unix_time_from_system() - 3 * 86400.0
	gw["last_seen"] = Time.get_unix_time_from_system() - 3 * 86400.0
	Save.grove_write()
	var s3 = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(s3)
	if s3.board == null:
		s3._ready()
	ok(s3.water == G.WATER_CAP, "returning after days away finds full water")

	# 12b. a cold load mid-game draws EVERY live generator of the CURRENT map (§6) — completing
	# maps 1+2 puts the player in map 3/Pond, which ships ONE generator (the reed bed; the roster
	# is one generator per map). The anchor satchel's cold-load persistence is BACKLOG.
	fresh("twogens")
	var gtg := Save.grove()
	var ul16 := {}
	for z in 2:
		for sp in G.MAPS[z].spots:
			ul16[String(sp.id)] = true
	gtg["unlocks"] = ul16
	Save.grove_write()
	var s4 = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(s4)
	if s4.board == null:
		s4._ready()
	ok(s4.gen_nodes.size() == 1, "a cold load in map 3/Pond draws the map's generator (reed bed)")
	ok(s4.gen_node != null and s4.gen_nodes.values().has(s4.gen_node), "gen_node points at a live generator (not the stale index-0 satchel)")

	# 12c. generators are MOVABLE (#1) and PERSIST into the bag's generator section (#2 store/place,
	# never consumed) on the live board, and the scene re-renders each step. Map 0 ships ONE
	# generator (the anchor satchel at (4,3)) — drive the whole move→store→place loop on it.
	fresh("genmech")
	var s4c = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(s4c)
	if s4c.board == null:
		s4c._ready()
	ok(s4c.board.gen_id_at(Vector2i(4, 3)) == "seed_satchel" and s4c.board.gens.size() == 1, \
		"12c: a fresh board seeds the one anchor satchel at its cell")
	s4c.board.items[BoardModel.idx(Vector2i(4, 4))] = 0       # clear the destination
	ok(s4c.board.move_gen(Vector2i(4, 3), Vector2i(4, 4)), "12c: the satchel moves to an empty cell (#1)")
	s4c._rebuild_all()
	ok(s4c.gen_nodes.has(Vector2i(4, 4)) and not s4c.gen_nodes.has(Vector2i(4, 3)), "12c: the moved generator re-renders at its new cell")
	ok(s4c.board.store_gen(Vector2i(4, 4)) and s4c.board.gen_bag.has("seed_satchel") and not s4c.board.is_gen(Vector2i(4, 4)), "12c: the satchel STORES into the gen_bag, freeing its cell (#2 — persists, never consumed)")
	s4c._rebuild_all()
	ok(not s4c.gen_nodes.has(Vector2i(4, 4)), "12c: the stored generator leaves the board render")
	var back_cell: Vector2i = s4c.board.empty_ground_cells()[0]
	ok(s4c.board.place_gen_from_bag("seed_satchel", back_cell) and s4c.board.gen_id_at(back_cell) == "seed_satchel" and not s4c.board.gen_bag.has("seed_satchel"), "12c: placing it back from the bag restores it to the board (#2)")
	s4c._rebuild_all()
	ok(s4c.board.gen_id_at(back_cell) == "seed_satchel" and s4c.gen_nodes.has(back_cell), "12c: the re-render reflects the restored generator")
	s4c.queue_free()

	# 12b2. a runtime-opened cell's ground tile sits ABOVE the mat (owner's
	# "no border" bug: move_child(slot, 0) hid the tile behind the moss)
	fresh("opentile")
	var s4b = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(s4b)
	if s4b.board == null:
		s4b._ready()
	var mat_ref: Node = s4b.board_area.get_child(0)
	var slots_before: int = _panel_count(s4b.board_area)
	s4b._open_bramble(Vector2i(2, 3))          # the first frontier
	ok(s4b.board_area.get_child(0) == mat_ref, "the mat stays child 0 after a runtime open")
	var new_slot: Control = s4b.slot_nodes[Vector2i(2, 3)]
	ok(new_slot.get_index() >= 1, "the freed cell's tile sits ABOVE the mat (index >= 1)")
	ok(_panel_count(s4b.board_area) == slots_before + 1, "exactly one new ground tile")
	var live_slots: int = _panel_count(s4b.board_area)
	s4b._rebuild_all()
	await create_timer(0.1).timeout            # let the rebuild's queue_frees flush
	ok(_panel_count(s4b.board_area) == live_slots, \
		"runtime tiles match a fresh rebuild of the same board (parity)")

	# 12c. the idle wiggle hint finds a real mergeable pair (starters pair up)
	var hint: Array = s3._hint_pair()
	ok(hint.size() == 2 and s3.board.item_at(hint[0]) == s3.board.item_at(hint[1]) \
		and s3.board.can_merge(hint[0], hint[1]), "the idle hint wiggles a true mergeable pair")

	# 12d. §7: the fence is METERED to the WHOLE map's remaining stars — it seats exactly
	# active_giver_count stands (capped at MAX_GIVERS, tapering only in the map's final stretch),
	# not a fixed pool.
	var s3_left: int = G.map_stars_left(s3._quest_map(), Save.grove().get("unlocks", {}))
	ok(s3.giver_chips.size() == G.active_giver_count(Save.stars(), s3_left), "§7: the fence seats exactly the metered giver count (%d shown)" % s3.giver_chips.size())
	ok(s3.giver_chips.size() <= int(G.MAX_GIVERS), "§7: the fence never exceeds MAX_GIVERS stands")

	# 13. P3 — maps/spots content sanity + level math
	var maps_ok := true
	for z in G.MAPS.size():
		var n: int = G.MAPS[z].spots.size()
		if n < 7 or n > 10:
			maps_ok = false
		var seen_ids := {}
		for s in G.MAPS[z].spots:
			if int(s.cost) < 3 or int(s.cost) > 5:
				maps_ok = false
			seen_ids[String(s.id)] = true
		if seen_ids.size() != n:
			maps_ok = false
	ok(maps_ok, "every map has 7-10 unique spots costing 3-5 stars (owner pacing)")
	# 13c. the stars-driven level clock (one uncapped Level, driven by stars EARNED)
	ok(G.level_for_stars(0) == 1 and G.level_for_stars(5) == 1 and G.level_for_stars(6) == 2, \
		"level_for_stars maps cumulative-earned thresholds")
	ok(G.level_for_stars(126) == 10, "L10 lands at 126 earned stars (= the old L10 exp/10)")
	ok(G.level_for_stars(126 + G.LEVEL_STARS_TAIL) == 11 and G.level_for_stars(100000) > 50, \
		"the level clock is UNCAPPED — a flat tail past the table")
	ok(G.stars_at_level(1) == 0 and G.stars_at_level(2) == 6 and G.stars_at_level(10) == 126 \
		and G.stars_at_level(11) == 126 + G.LEVEL_STARS_TAIL, "stars_at_level inverts the curve")
	# earn_stars bumps the spendable balance AND the earned clock; the level-up gift is DEFERRED to the
	# dialog's Collect (level_gift + grant_level_gift), so earn_stars itself grants nothing.
	fresh("earn")
	Save.spend_diamonds(Save.diamonds())       # drain the small new-save seed → the gift below is exact
	var ge := Save.grove()
	ge["stars_earned"] = 5
	ge["water"] = 10
	var gained := G.earn_stars(2)              # 5 -> 7 crosses the L2 line (6)
	ok(gained == 1, "earn_stars returns the number of levels gained")
	ok(int(Save.grove()["stars_earned"]) == 7 and Save.stars() == 2, \
		"earn_stars accrues BOTH the earned clock and the spendable balance")
	ok(int(Save.grove()["water"]) == 10 and Save.diamonds() == 0, \
		"earn_stars does NOT grant the level-up gift (deferred to the dialog's Collect)")
	var gift := G.level_gift(gained)
	ok(int(gift.get("water", 0)) == G.LEVEL_WATER_GIFT and int(gift.get("gems", 0)) == G.LEVEL_DIAMONDS, \
		"level_gift returns water + diamonds per level gained")
	G.grant_level_gift(gift)
	ok(int(Save.grove()["water"]) == 10 + G.LEVEL_WATER_GIFT and Save.diamonds() == G.LEVEL_DIAMONDS, \
		"grant_level_gift applies the water + diamonds (what Collect does)")
	ok(G.earn_stars(1) == 0, "earning within a level gains no level (no extra gift)")

	# 14. P3 — the HOME scene (NEW map model): a map IS one image with restoration
	# SPOTS placed on it; discrete maps via the map-select. boot → buy → gate → resume.
	fresh("home")
	var h = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(h)
	if h.content == null:
		h._ready()
	await create_timer(0.05).timeout
	# boot lands ON a map: the frontier (fresh save → the hub, map 0), every spot live
	ok(h._view == "map" and h._map_idx == G.hub_map(), "boot opens the frontier map (fresh → the hub)")
	ok(h.content != null, "the single input surface exists")
	ok(h.spot_hits.size() == G.MAPS[h._map_idx].spots.size(), "the open map seats every spot as a hit")
	# the single-input-surface rule (3rd input-swallow bug): EVERY descendant of
	# content IGNOREs the mouse — only content's gui_input resolves taps
	ok(_all_ignore(h.content), "every content descendant IGNOREs mouse (single input surface)")
	ok(h.map_unlocked(0) and not h.map_unlocked(1), "farmhouse open, barn locked, on a fresh save")

	# item-1 (unified renderer): a NON-hub map (no §16 home art) renders through the SAME path as the
	# hub — every spot seated as a hit via the cutout renderer, single-input-surface intact. Open barn
	# directly (nav doesn't gate _open_map), then restore the hub for the buy assertions below.
	h._open_map(1)
	ok(h.spot_hits.size() == G.MAPS[1].spots.size(), "a non-hub map seats every spot as a hit (unified render)")
	ok(_all_ignore(h.content), "a non-hub map keeps the single-input-surface rule (unified render)")
	h._open_map(G.hub_map())

	# a spot BUY, driven through the REAL spot node: give stars, tap an affordable
	# spot (k=0 fh_hearth, 3★) → owned, stars debited, the view stays a map (no
	# takeover/scene change). Stars are the ONLY unlock gate now — no level gate.
	Save.add_stars(100)
	var stars0 := Save.stars()
	var hearth_id: String = G.MAPS[0].spots[0].id
	var buy_node: Control = h.spot_hits[0].node
	h._on_spot_tap(0, 0, buy_node, _hit_center(buy_node))
	ok(h.spot_owned(hearth_id), "buying a spot records the unlock")
	ok(Save.stars() == stars0 - int(G.MAPS[0].spots[0].cost), "the spot's stars were spent")
	ok(G.level_for_stars(int(Save.grove().get("stars_earned", 0))) == 1, \
		"buying a spot does NOT raise Level (Level rides stars EARNED, not spent)")
	ok(h._view == "map", "the view stays a map across a purchase (no takeover)")
	# an already-restored spot is now INERT — tapping it does nothing (customization removed).
	h._on_spot_tap(0, 0, buy_node, _hit_center(buy_node))
	ok(h._view == "map", "tapping an owned spot is a no-op (no customization surface)")

	# the MAP-SELECT view: every map is a card. an UNLOCKED card opens that map; a
	# LOCKED card stays put (wobble). drive taps through the real input surface.
	h._open_select()
	ok(h._view == "select", "the atlas button opens the map-select view")
	ok(h.select_hits.size() == G.MAPS.size(), "the select view seats one card per map")
	ok(_all_ignore(h.content), "every select descendant IGNOREs mouse (single input surface)")
	await create_timer(0.05).timeout
	# tapping the LOCKED barn card (z=1) does nothing — still in select
	var locked_card: Control = null
	for hit in h.select_hits:
		if int(hit.z) == 1:
			locked_card = hit.node
	_map_tap_at(h, _hit_center(locked_card))
	ok(h._view == "select", "tapping a LOCKED map card stays in the select view")
	# tapping the UNLOCKED farmhouse card (z=0) opens that map
	var open_card: Control = null
	for hit in h.select_hits:
		if int(hit.z) == 0:
			open_card = hit.node
	_map_tap_at(h, _hit_center(open_card))
	ok(h._view == "map" and h._map_idx == 0, "tapping an UNLOCKED map card opens that map")

	# the completion chain: restoring the LAST spot of map 0 auto-unlocks map 1 (the gate quest
	# type is retired — the completion record now sets the moment the map's spots are done). Buy
	# all of map 0 (earn past its L-gates); the final purchase appends z=0 to `gates` itself.
	Save.grove()["stars_earned"] = G.stars_at_level(3)   # clear the farmhouse's L-gates
	# buy all but the last spot, then check the next map is STILL locked (spots not yet done)
	for i in G.MAPS[0].spots.size() - 1:
		var sid: String = G.MAPS[0].spots[i].id
		if not h.spot_owned(sid):
			h._on_spot_tap(0, i, h.spot_hits[i].node, _hit_center(h.spot_hits[i].node))
	ok(not h.map_spots_done(0), "before the last spot, map 0 is not yet complete")
	ok(not h.map_unlocked(1), "§7: a partially-restored map does NOT open the next")
	# restore the LAST spot → spots done → z=0 auto-appended to `gates` → map 1 unlocks
	var last_i: int = G.MAPS[0].spots.size() - 1
	h._on_spot_tap(0, last_i, h.spot_hits[last_i].node, _hit_center(h.spot_hits[last_i].node))
	ok(h.map_spots_done(0), "all farmhouse spots restored")
	ok(Save.grove().get("gates", []).has(0), "§7: restoring the last spot auto-records map 0 in `gates` (no gate quest)")
	ok(h.map_unlocked(1), "§7: completing a map's spots opens the next (the completion chain)")
	h._persist()

	# 14a3. Q save migration: a pre-Q save (old spot ids) renames in place on the
	# shared grove() accessor — ownership survives, counts intact.
	# Old ids are sourced from the rename map itself (no stale literals in tests).
	fresh("qmig")
	var ren: Dictionary = Save._SPOT_ID_RENAMES
	var first_old: String = ren.keys()[0]
	var gm := Save.grove()
	var u_seed := {}
	for old in ren:
		u_seed[old] = true
	gm["unlocks"] = u_seed
	Save.grove()                              # the accessor migrates on read
	var um: Dictionary = Save.grove().get("unlocks", {})
	var all_renamed := true
	for old in ren:
		if um.has(old) or not um.has(String(ren[old])):
			all_renamed = false
	ok(all_renamed, "Q migration renames ALL unlock ids old→new (ownership survives)")
	ok(um.size() == ren.size(), "migration preserves the unlock COUNT (spots/stars intact)")
	Save.grove()                              # idempotent: a second pass changes nothing
	ok(Save.grove().get("unlocks", {}).size() == ren.size() and not Save.grove().get("unlocks", {}).has(first_old), \
		"Q migration is idempotent")

	# 14b. §7: buying a spot grants NO per-spot water — the old per-spot gift is retired
	# (water comes from level-ups only), so the purchase leaves water unchanged.
	var gw2 := Save.grove()
	var ul24 := {}
	for z4 in 3:                             # maps 1-3 (maps 0-2) fully spot-restored
		for sp in G.MAPS[z4].spots:
			ul24[String(sp.id)] = true
	gw2["unlocks"] = ul24
	h.unlocks = ul24
	gw2["water"] = 50
	gw2["stars_earned"] = 200                # Level rides earned stars (no longer gates spots)
	gw2["gates"] = [0, 1, 2]                  # §7: maps 1-3 gated through → map 4 spots are buyable
	Save.add_stars(10)
	h._on_spot_tap(3, 0, Button.new(), Vector2(300, 300))
	ok(int(Save.grove().get("water", 0)) == 50, "§7: a home purchase grants no per-spot water (water is level-ups only)")

	# 14c. unlocks are gated by STARS ALONE (no level gate): map_cheapest_spot returns the
	# literal cheapest unowned spot — never a level-locked sentinel — so a stocked bank can
	# clear any open map's spots in any order, on cost alone.
	for zc in G.MAPS.size():
		var min_cost := 99
		for sp in G.MAPS[zc].spots:
			min_cost = mini(min_cost, int(sp.cost))
		ok(G.map_cheapest_spot(zc, {}) == min_cost, \
			"map %d's next unlock is its literal cheapest spot, no level exclusion" % zc)

	# a fresh Home resumes the same progress
	var h2 = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(h2)
	if h2.content == null:
		h2._ready()
	ok(h2.map_spots_done(0), "home progress persists across scenes")

	# 15. P5 — sell anything, diamonds, FTUE staging
	fresh("p5")
	var s5 = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(s5)
	if s5.board == null:
		s5._ready()
	# Pops charge energy from the FIRST tap — the FTUE free-pop intro was retired (water now costs
	# from the start). A tap throws a BURST (1-3 items); the charge tracks the burst size — each
	# popped item is one energy. Clear a few cells for the burst to fill.
	for cc in [Vector2i(3, 2), Vector2i(3, 4), Vector2i(3, 3), Vector2i(4, 2), Vector2i(2, 2)]:
		s5.board.take(cc)
	s5._rebuild_pieces()
	Save.grove()["pops"] = 0
	s5.water = G.WATER_CAP
	var ftue_b := 0
	for v in s5.board.items:
		if v > 0:
			ftue_b += 1
	s5._pop_seed()
	await create_timer(0.25).timeout
	var ftue_n := -ftue_b
	for v in s5.board.items:
		if v > 0:
			ftue_n += 1
	ok(ftue_n >= 1 and s5.water == G.WATER_CAP - ftue_n * G.POP_COST, "a pop charges one energy per burst item from the first tap (no free intro)")
	ok(s5.merchant_chip == null, "the merchant waits for the first spot")

	# sell anything: a t3 flower pays 3 coins and leaves the board
	Save.grove()["unlocks"] = {String(G.MAPS[0].spots[0].id): true}
	Save.grove_write()
	s5._rebuild_givers()
	ok(s5.merchant_btn != null and is_instance_valid(s5.merchant_btn), "the merchant sell-well rides the bottom nav")
	s5.board.place(Vector2i(3, 3), 103)
	s5._rebuild_pieces()
	var c0 := Save.coins()
	s5._sell_item(Vector2i(3, 3), s5.piece_nodes.get(Vector2i(3, 3)))
	ok(Save.coins() == c0 + 3 and s5.board.item_at(Vector2i(3, 3)) == 0, \
		"selling a t3 pays 3 coins and clears the cell")
	ok(G.sell_value(108) == 8 and G.sell_value(201) == 1, "sell value scales with tier")

	# T39: per-map sell COIN band (§6/§9) — later maps sell t1..(PREMIUM_TIER-1) for more coins;
	# PREMIUM_TIER (t8) is the flat-1💎 pinnacle on every map; t9..TOP_TIER sell for coins again.
	# Only the t1..(PREMIUM_TIER-1) coin reward scales with the map band.
	# The band is a grove number (owner/sim-tuned), keyed by the item's map (0-indexed maps 1–5).
	var band := G.SELL_MAP_BAND
	ok(band.size() == G.MAPS.size(), "T39: the sell band has one entry per map (%d)" % G.MAPS.size())
	var band_mono := true
	for bi in range(1, band.size()):
		if float(band[bi]) <= float(band[bi - 1]):
			band_mono = false
	ok(band_mono and float(band[0]) >= 1.0, "T39: the per-map band rises monotonically across maps 1–5 (≥1.0 at map 1)")
	# map resolution: code → line → generator → its map. Sample lines spanning maps 0..4.
	ok(G.map_for_line(1) == 0 and G.map_for_line(2) == 0, "T39: map-1 lines (Wildflower/Berry) resolve to map 0")
	ok(G.map_for_line(6) == 1, "T39: the map-2 line (Feather) resolves to map 1")
	ok(G.map_for_line(10) == 2, "T39: a map-3 line (Reed) resolves to map 2")
	ok(G.map_for_line(14) == 3 and G.map_for_line(20) == 4, "T39: map-4/5 lines (Apple/Glowcap) resolve to maps 3/4")
	ok(G.map_for_code(1005) == 2, "T39: map_for_code derives the line then the map (Reed t5 → map 2)")
	# t1..(PREMIUM_TIER-1) reward == round(tier_coins × band[map]); checked across every line, every sub-pinnacle tier.
	var band_ok := true
	var t8_flat := true
	for line in G.LINES:
		var lm: int = G.map_for_line(int(line))
		var lb: float = float(band[lm])
		for tier in range(1, G.PREMIUM_TIER):
			var code: int = int(line) * 100 + tier
			var want_coins: int = int(round(maxi(1, tier) * lb))
			var rw: Vector2i = G.sell_reward(code)
			if rw != Vector2i(want_coins, 0):
				band_ok = false
		var top_rw: Vector2i = G.sell_reward(int(line) * 100 + G.PREMIUM_TIER)
		if top_rw != Vector2i(0, 1):
			t8_flat = false
	ok(band_ok, "T39: every t1–(PREMIUM_TIER-1) reward == round(tier coins × the line's map band)")
	ok(t8_flat, "T39: a t8 (PREMIUM_TIER) sells for EXACTLY 1💎 (no coins) on every line/map — the flat pinnacle (32× proof)")
	# concrete worked examples (map 0 band == 1.0 keeps the FTUE-era proofs exact)
	ok(G.sell_reward(103) == Vector2i(3, 0), "T39: a map-1 t3 (band 1.0) still sells for exactly 3🪙")
	ok(G.sell_reward(105) == Vector2i(5, 0), "T39: a map-1 t5 (band 1.0) still sells for exactly 5🪙")
	ok(G.sell_reward(2005) == Vector2i(int(round(5 * float(band[4]))), 0), \
		"T39: a map-5 t5 (band %.1f) sells for %d🪙 (later map → more coins)" % [float(band[4]), int(round(5 * float(band[4])))])

	# diamonds: accessors + paid rain once the freebies are spent. A fresh save SEEDS a small
	# starting balance (so the premium slot never reads a dead 0); drain it to a known 0 first.
	ok(Save.diamonds() == Save.NEW_SAVE_GEMS, "diamonds default = the small new-save seed")
	Save.spend_diamonds(Save.diamonds())
	Save.add_diamonds(30)
	s5.refills_used = G.FREE_REFILLS
	s5.water = 0
	s5._update_water_hud()
	ok(s5.refill_btn.visible, "paid rain offered when diamonds suffice")
	s5._on_refill()
	ok(s5.water == G.WATER_CAP and Save.diamonds() == 30 - G.REFILL_DIAMOND_COST, \
		"paid rain fills the cap and spends diamonds")

	# §5 bag: 6 owned slots at start, +1 per 💎 buy up to 18. The bar renders one button per owned
	# slot PLUS a trailing "+slot" buy affordance while below the cap (so owned 6 → 7 buttons).
	ok(s5._bag_capacity() == 6, "the bag starts at six owned slots")
	ok(s5.bag_btn != null and is_instance_valid(s5.bag_btn), "the bag is a single bottom-nav well (no always-on row)")
	var slots0 := Save.bag_slots()
	var price := G.next_bag_slot_price(slots0)
	Save.add_diamonds(price)
	var dia0 := Save.diamonds()
	s5._buy_bag_slot()
	ok(Save.bag_slots() == slots0 + 1 and Save.diamonds() == dia0 - price, \
		"buying the 7th slot grows the owned count and spends its 💎 price")
	ok(s5._bag_capacity() == 7, "the bought slot shows up in the bag capacity (7 owned)")
	# a broke buy is refused — no slot, no charge
	Save.spend_diamonds(Save.diamonds())      # drain the wallet
	var slots1 := Save.bag_slots()
	s5._buy_bag_slot()
	ok(Save.bag_slots() == slots1, "a broke slot-buy is refused (premium is convenience, never a wall)")

	# at the 18 cap the +slot affordance is gone: 18 buttons, no trailing buy slot.
	Save.set_bag_slots(18)
	s5._build_bag_bar()
	ok(s5._bag_capacity() == 18 and not s5._bag_has_buy_slot(), \
		"at the 18-slot cap the capacity is 18 and the +slot buy affordance is gone")
	Save.set_bag_slots(6)                      # restore for the drag-back check below
	s5._build_bag_bar()

	# §5 drag-back retrieve: a bagged item returns to the board by being dropped on a cell.
	s5.bag = [104]                            # one t4 flower waiting in the bag
	s5._rebuild_bag()
	var dest := Vector2i(3, 3)
	s5.board.take(dest)                       # make sure the target cell is empty ground
	s5._rebuild_pieces()
	s5._retrieve_from_bag(0, dest)
	ok(s5.board.item_at(dest) == 104 and s5.bag.is_empty(), \
		"dragging a bagged item onto an empty cell places it and empties that bag slot")

	# home grants: a level-up pays diamonds too
	var h5 = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(h5)
	if h5.content == null:
		h5._ready()
	var d0 := Save.diamonds()
	var vault0 := Vault.balance() * Vault.skim_den() + Save.vault_carry()   # total skimmed-units before
	Save.grove()["stars_earned"] = G.stars_at_level(2) - 1     # one star short of L2
	var lvg := G.earn_stars(1)                                 # crosses into L2 (no grant yet)
	G.grant_level_gift(G.level_gift(lvg))                      # Collect grants the gift + skims
	ok(Save.diamonds() == d0 + G.LEVEL_DIAMONDS, "a level-up pays diamonds on Collect")
	# T44 SKIM-SITE wiring (content.grant_level_gift): the piggy bank skimmed a slice of the
	# level-up premium — the banked-units pool advanced by exactly LEVEL_DIAMONDS × num.
	var vault1 := Vault.balance() * Vault.skim_den() + Save.vault_carry()
	ok(vault1 - vault0 == G.LEVEL_DIAMONDS * Vault.skim_num(), "granting the gift SKIMS its premium into the piggy bank (§10)")

	# 16. the discovery log + the upgrade-path card (tap an item → its ladder;
	# unseen tiers stay "?")
	finish()
