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

	# collectables (coins): a coin is collectable; FIRST tap only focuses it into the info bar,
	# a SECOND tap (while focused) collects it; a DRAG never collects. (board.gd _on_release)
	var coins0 := Save.coins()
	s2._drop_coin_near(Vector2i(4, 3))
	await create_timer(0.3).timeout
	var coin_cell := Vector2i(-1, -1)
	for i in s2.board.items.size():
		if s2.board.items[i] > 0 and G.is_coin(s2.board.items[i]):
			coin_cell = BoardModel.cell_of(i)
			break
	ok(coin_cell != Vector2i(-1, -1), "a coin dropped onto the board")
	ok(G.is_collectable(s2.board.item_at(coin_cell)), "a coin counts as a collectable")
	var chalf: Vector2 = Vector2(s2.csz, s2.csz) / 2.0
	var cpos: Vector2 = s2._cell_pos(coin_cell) + chalf
	# first tap: brings up the info bar only — no collection
	s2._on_press(cpos)
	s2._on_release(cpos)
	ok(Save.coins() == coins0, "first tap on a coin does not collect it")
	ok(s2.board.item_at(coin_cell) != 0, "first tap leaves the coin on the board")
	ok(s2._selected_cell == coin_cell, "first tap focuses the coin in the info bar")
	# second tap, now that it is focused: it collects
	s2._on_press(cpos)
	s2._on_release(cpos)
	ok(Save.coins() == coins0 + 1, "tapping a focused coin pockets its value")
	ok(s2.board.item_at(coin_cell) == 0, "the collected coin left the board")

	# a DRAG never collects — even on a focused coin
	s2._drop_coin_near(Vector2i(4, 3))
	await create_timer(0.3).timeout
	var coin_cell2 := Vector2i(-1, -1)
	for i in s2.board.items.size():
		if s2.board.items[i] > 0 and G.is_coin(s2.board.items[i]):
			coin_cell2 = BoardModel.cell_of(i)
			break
	ok(coin_cell2 != Vector2i(-1, -1), "a second coin dropped onto the board")
	var cpos2: Vector2 = s2._cell_pos(coin_cell2) + chalf
	var coins_before_drag := Save.coins()
	s2._on_press(cpos2)
	s2._on_release(cpos2)                                  # focus it first
	s2._on_press(cpos2)
	s2._on_release(cpos2 + Vector2(s2.csz, 0.0))           # then drag it away (>18px)
	ok(Save.coins() == coins_before_drag, "dragging a coin does not collect it")

	# coin merge rules (model): c1+c1 merges, c3 is capped
	var bc: BoardModel = BoardModel.new()
	bc.place(Vector2i(3, 2), 901)
	bc.place(Vector2i(3, 4), 901)
	ok(bc.can_merge(Vector2i(3, 2), Vector2i(3, 4)), "coins merge with coins")
	bc.place(Vector2i(5, 2), 903)
	bc.place(Vector2i(5, 4), 903)
	ok(not bc.can_merge(Vector2i(5, 2), Vector2i(5, 4)), "top coin (25) never merges")
	ok(bc.top_tier_cells().is_empty(), "coins are never merchant goods")

	# 11b. BURST-POP (§6) + the temporary BOOST — both engine-side; the grove only sets the odds/
	# scale/cost dials. One tap throws a burst that scales with the map; while a boost is ACTIVE every
	# tap drops BOOST_BONUS extra items for BOOST_TAPS taps, then it expires. Activating spends coins,
	# arms the taps, and refuses a second buy while one is already running (no double spend).
	fresh("burst")
	var sbp = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(sbp)
	if sbp.board == null:
		sbp._ready()
	Save.grove()["pops"] = 50                 # well past the FTUE — the energy meter is on
	ok(not G.boost_active(), "no boost is active on a fresh save")
	ok(sbp._gen_boost_bonus() == 0, "with no boost a generator gets no bonus items")
	Save.add_coins(10000)
	var bu_c0 := Save.coins()
	ok(sbp._activate_gen_boost(), "the boost activates with coins")
	ok(Save.coins() == bu_c0 - G.BOOST_COST, "activating spends the boost cost (the coin sink)")
	ok(G.boost_active() and G.boost_taps_left() == G.BOOST_TAPS, "the boost arms BOOST_TAPS taps")
	ok(sbp._gen_boost_bonus() == G.BOOST_BONUS, "while active a generator gets +BOOST_BONUS items")
	# a second activation while one is running is refused — no extra taps, no double spend
	var bu_c1 := Save.coins()
	ok(not sbp._activate_gen_boost(), "a second boost while one is running is refused")
	ok(G.boost_taps_left() == G.BOOST_TAPS and Save.coins() == bu_c1, "...no extra taps, no double spend")
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
	ok(burst_got >= 1 + G.BOOST_BONUS, "with the boost a single tap throws a burst of ≥1+BOOST_BONUS items (map 1)")
	ok(sbp.water == bw0 - burst_got * G.POP_COST, "each burst item costs one energy")
	ok(G.boost_taps_left() == G.BOOST_TAPS - 1, "a charged tap spends one boost tap")
	# the boost expires when its taps run out — back to no bonus
	while G.boost_active():
		G.consume_boost_tap()
	ok(sbp._gen_boost_bonus() == 0, "an expired boost gives no bonus")
	# the boost taps ride the save across scenes
	ok(G.try_activate_boost(), "re-arm a boost for the persistence check")
	var saved_taps: int = G.boost_taps_left()
	var sbp2 = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(sbp2)
	if sbp2.board == null:
		sbp2._ready()
	ok(sbp2._gen_boost_bonus() == G.BOOST_BONUS and G.boost_taps_left() == saved_taps, "the boost taps persist across scenes")
	sbp.queue_free()
	sbp2.queue_free()

	# 11c. The boost refuses cleanly when broke — no taps armed, no coin debt.
	fresh("burst_broke")
	var sbc = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(sbc)
	if sbc.board == null:
		sbc._ready()
	ok(not G.boost_active() and Save.coins() == 0, "fresh: no boost, no coins")
	ok(not sbc._activate_gen_boost(), "broke: the boost refuses — returns false")
	ok(not G.boost_active() and Save.coins() == 0, "broke refusal arms no taps and leaves no coin debt")
	sbc.queue_free()

	# 11d. The SHARED boost seam G.try_activate_boost() + G.consume_boost_tap() — the single arm/decay
	# path the info-bar chip drives. Spends the cost, arms BOOST_TAPS, refuses a second arm while live
	# and when broke, decays one tap at a time to expiry, and never underflows. No scene needed.
	fresh("burst_seam")
	ok(not G.boost_active() and G.boost_taps_left() == 0, "seam: fresh save has no boost")
	ok(not G.try_activate_boost(), "seam: broke → refuses (no coins)")
	ok(not G.boost_active() and Save.coins() == 0, "seam: broke refusal arms nothing, no debt")
	Save.add_coins(10000)
	var seam_c0 := Save.coins()
	ok(G.try_activate_boost(), "seam: arms with coins")
	ok(Save.coins() == seam_c0 - G.BOOST_COST, "seam: spends the boost cost")
	ok(G.boost_active() and G.boost_taps_left() == G.BOOST_TAPS, "seam: arms BOOST_TAPS taps (persisted)")
	var live_coins := Save.coins()
	ok(not G.try_activate_boost(), "seam: a second arm while live is refused")
	ok(G.boost_taps_left() == G.BOOST_TAPS and Save.coins() == live_coins, "seam: no extra taps, no double spend")
	for _i in G.BOOST_TAPS:
		G.consume_boost_tap()
	ok(not G.boost_active() and G.boost_taps_left() == 0, "seam: decays to expiry over BOOST_TAPS taps")
	G.consume_boost_tap()
	ok(G.boost_taps_left() == 0, "seam: consuming past expiry never underflows")

	# 11e. The INFO-BAR boost chip (T54→boost): a generator tap selects it into the bar and shows the
	# chip in the slot the sell button leaves empty; tapping it arms the boost; broke refuses; while the
	# boost is LIVE the chip stays visible but faded + inert (no re-buy) and the label carries the boost
	# detail; a plain item hides the chip. (Here, not grove_ui — that disabled suite crashes earlier on a
	# pre-existing map error before reaching this.)
	fresh("burst_chip")
	var sbu = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(sbu)
	if sbu.board == null:
		sbu._ready()
	await create_timer(0.02).timeout
	ok(not sbu.board.gens.is_empty(), "the fresh board has a generator")
	var bgcell: Vector2i = sbu.board.gens.keys()[0]
	Save.spend(Save.coins())                                   # drain to broke
	# the REAL user path: a still-tap on the generator pops it AND surfaces the chip in the info bar.
	Save.grove()["pops"] = 30                                  # past the FTUE so the tap is a normal pop
	var ghalf: Vector2 = Vector2(sbu.csz, sbu.csz) / 2.0
	sbu._on_press(sbu._cell_pos(bgcell) + ghalf)
	sbu._on_release(sbu._cell_pos(bgcell) + ghalf)
	await create_timer(0.05).timeout
	ok(sbu._selected_cell == bgcell and sbu._info_burst.visible, "a still-tap on the generator surfaces the boost chip")
	sbu._select_generator(bgcell)
	ok(sbu._selected_cell == bgcell, "selecting a generator fills the info bar")
	ok(sbu._info_burst.visible, "the boost chip shows for a generator")
	ok(not sbu._info_trash.visible, "the sell button is hidden for a generator")
	sbu._on_burst_chip()
	ok(not G.boost_active() and Save.coins() == 0, "broke: tapping the chip arms nothing, no debt")
	Save.add_coins(10000)
	var bc0 := Save.coins()
	sbu._select_generator(bgcell)                              # re-read affordability with coins
	sbu._on_burst_chip()
	ok(G.boost_active(), "afford: tapping the boost chip arms the boost")
	ok(Save.coins() == bc0 - G.BOOST_COST, "...and spends the boost cost")
	# while the boost is LIVE: the chip stays visible but faded + inert; the label carries the detail
	sbu._select_generator(bgcell)
	ok(sbu._info_burst.visible, "the boost chip stays visible while a boost is live")
	ok(sbu._info_burst.modulate.a < 1.0, "the live boost chip is faded (like can't-afford) — no re-buy")
	ok(sbu._info_label.text.contains("+%d" % G.BOOST_BONUS) and sbu._info_label.text.contains(str(G.boost_taps_left())), "the info label shows the boost bonus and taps left")
	var live_c := Save.coins()
	sbu._on_burst_chip()
	ok(G.boost_taps_left() == G.BOOST_TAPS and Save.coins() == live_c, "tapping the live chip re-buys nothing, no double spend")
	var bicell := Vector2i(-1, -1)
	for bcc in sbu.board.empty_ground_cells():
		bicell = bcc
		break
	if bicell.x >= 0:
		sbu.board.place(bicell, 101)
		sbu._select_item(bicell)
		ok(not sbu._info_burst.visible, "selecting a plain item hides the boost chip")
	sbu.queue_free()

	# 11f. The INFO-BAR BUY chip (T55): selecting a sellable item shows a buy chip beside sell; tapping it
	# spends G.buy_price and drops a COPY on the board; a generator has no buy chip; broke refuses cleanly.
	fresh("buy_chip")
	var sbb = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(sbb)
	if sbb.board == null:
		sbb._ready()
	await create_timer(0.02).timeout
	# place a known sellable item (map-1 t3 → buys for coins) and select it
	var icell2 := Vector2i(-1, -1)
	for c2 in sbb.board.empty_ground_cells():
		if not sbb.board.is_gen(c2):
			icell2 = c2
			break
	sbb.board.place(icell2, 103)
	sbb._rebuild_pieces()
	await create_timer(0.05).timeout
	Save.spend(Save.coins())                                   # broke first
	sbb._select_item(icell2)
	ok(sbb._info_buy.visible and sbb._info_trash.visible, "a sellable item shows BOTH the buy chip and the sell button")
	var price103: Vector2i = G.buy_price(103)
	var items_b := 0
	for v in sbb.board.items:
		if v > 0:
			items_b += 1
	sbb._on_buy_pressed()
	var items_broke := 0
	for v in sbb.board.items:
		if v > 0:
			items_broke += 1
	ok(items_broke == items_b and Save.coins() == 0, "broke: tapping buy adds no item and spends nothing")
	Save.add_coins(10000)
	var coins_b := Save.coins()
	sbb._select_item(icell2)                                   # re-read affordability with coins
	sbb._on_buy_pressed()
	await create_timer(0.05).timeout
	var items_after := 0
	for v in sbb.board.items:
		if v > 0:
			items_after += 1
	ok(items_after == items_b + 1, "afford: buying drops one COPY onto the board")
	ok(Save.coins() == coins_b - price103.x, "afford: buying spends ceil(sell×markup) coins")
	# board FULL → the bought copy lands in the bag instead (no loss)
	for c3 in sbb.board.empty_ground_cells():
		if not sbb.board.is_gen(c3):
			sbb.board.place(c3, 102)
	sbb._rebuild_pieces()
	Save.add_coins(10000)
	sbb._select_item(icell2)
	var bag_b: int = sbb.bag.size()
	sbb._on_buy_pressed()
	ok(sbb.bag.size() == bag_b + 1, "board full → the bought copy lands in the bag")
	# board AND bag full → buy refuses cleanly (no item anywhere, no spend)
	while sbb.bag.size() < sbb._bag_capacity():
		sbb.bag.append(101)
	var coins_full := Save.coins()
	var bag_cap: int = sbb.bag.size()
	sbb._on_buy_pressed()
	ok(sbb.bag.size() == bag_cap and Save.coins() == coins_full, "board AND bag full → buy refuses, no spend")
	# a generator has no buy chip (its action is burst, not a copy)
	sbb._select_generator(sbb.board.gens.keys()[0])
	ok(not sbb._info_buy.visible, "a generator shows no buy chip")
	sbb.queue_free()

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
	var s3_left: int = G.map_finish_exp(s3._quest_map(), Save.grove().get("unlocks", {}))
	ok(s3.giver_chips.size() == G.active_giver_count(Save.exp_total(), s3_left), "§7: the fence seats exactly the metered giver count (%d shown)" % s3.giver_chips.size())
	ok(s3.giver_chips.size() <= int(G.MAX_GIVERS), "§7: the fence never exceeds MAX_GIVERS stands")

	# 13. P3 — maps/spots content sanity (unique spot ids per map)
	var maps_ok := true
	for z in G.MAPS.size():
		var seen_ids := {}
		for s in G.MAPS[z].spots:
			seen_ids[String(s.id)] = true
		if seen_ids.size() != G.MAPS[z].spots.size():
			maps_ok = false
	ok(maps_ok, "every map's spots have unique ids")
	# 13d. exp level math — a FRONT-LOADED arithmetic curve (cost(n)=BASE+(n-1)*STEP), uncapped.
	ok(G.exp_at_level(1) == 0, "level 1 starts at 0 cumulative exp")
	ok(G.level_for_exp(G.exp_at_level(2)) == 2 and G.level_for_exp(G.exp_at_level(2) - 1) == 1, \
		"level_for_exp inverts exp_at_level at the L2 boundary")
	ok(G.exp_at_level(2) > G.exp_at_level(1) and G.exp_at_level(3) > G.exp_at_level(2), \
		"exp_at_level is strictly increasing")
	ok(G.level_for_exp(1000000) > 50, "the level clock is UNCAPPED — the arithmetic curve continues past the arc")
	ok((G.exp_at_level(12) - G.exp_at_level(11)) >= (G.exp_at_level(3) - G.exp_at_level(2)), \
		"per-level cost is non-decreasing (front-loaded or flat, never back-loaded)")
	# the per-spot unlock ladder: ONE region per consecutive level across the GLOBAL spot order, the first
	# at L2 (a quick earned first beat — not free, not endgame-priced). Each level-up grants exactly one region.
	ok(G.spot_unlock_level(0, 0) == 2, "the first region overall unlocks at level 2")
	ok(G.spot_unlock_exp(0, 0) == G.exp_at_level(2) and G.spot_unlock_exp(0, 0) > 0, \
		"the first region's threshold is the L2 floor (earned, never free)")
	var ladder_ok := true       # each region sits on its own next level …
	var collide_ok := true      # … so no two regions ever share a level (no finale collapse)
	var inc_ok := true          # … and exp thresholds strictly increase in global order
	var seen_levels := {}
	var expect_level := 2
	var prev := -1
	for z in G.MAPS.size():
		for k in G.MAPS[z].spots.size():
			var lv := G.spot_unlock_level(z, k)
			if lv != expect_level:
				ladder_ok = false
			if seen_levels.has(lv):
				collide_ok = false
			seen_levels[lv] = true
			if G.spot_unlock_exp(z, k) != G.exp_at_level(lv):
				ladder_ok = false
			var e := G.spot_unlock_exp(z, k)
			if e <= prev:
				inc_ok = false
			prev = e
			expect_level += 1
	ok(ladder_ok, "each region in global order unlocks at the NEXT level (one region per level-up), floored to that level")
	ok(collide_ok, "no two regions share an unlock level (the finale no longer collapses several onto one level)")
	ok(inc_ok, "spot_unlock_exp is strictly increasing across the global spot order")
	# next-unlock picks the lowest-threshold unclaimed spot (now the L2 floor, not free)
	var nu := G.map_next_unlock(0, {})
	ok(int(nu.k) == 0 and int(nu.exp) == G.spot_unlock_exp(0, 0), "map_next_unlock targets the lowest-threshold unclaimed spot")
	var owned0 := {String(G.MAPS[0].spots[0].id): true}
	ok(int(G.map_next_unlock(0, owned0).k) == 1, "claiming spot 0 advances the next-unlock to spot 1")
	# earn_exp bumps the single exp total; the level-up gift is DEFERRED to the dialog's Collect
	# (level_gift + grant_level_gift), so earn_exp itself grants nothing.
	fresh("earn")
	Save.spend_diamonds(Save.diamonds())       # drain the small new-save seed → the gift below is exact
	var ge := Save.grove()
	ge["exp"] = G.exp_at_level(2) - 1          # one exp short of L2
	ge["water"] = 10
	var gained := G.earn_exp(2)                # crosses the L2 boundary → one level gained
	ok(gained == 1, "earn_exp returns the number of levels gained")
	ok(Save.exp_total() == G.exp_at_level(2) + 1, "earn_exp accrues the single exp total")
	ok(int(Save.grove()["water"]) == 10 and Save.diamonds() == 0, \
		"earn_exp does NOT grant the level-up gift (deferred to the dialog's Collect)")
	var gift := G.level_gift(gained)
	ok(int(gift.get("water", 0)) == G.LEVEL_WATER_GIFT and int(gift.get("gems", 0)) == G.LEVEL_DIAMONDS, \
		"level_gift returns water + diamonds per level gained")
	G.grant_level_gift(gift)
	ok(int(Save.grove()["water"]) == 10 + G.LEVEL_WATER_GIFT and Save.diamonds() == G.LEVEL_DIAMONDS, \
		"grant_level_gift applies the water + diamonds (what Collect does)")
	ok(G.earn_exp(1) == 0, "earning within a level gains no level (no extra gift)")

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

	# a spot CLAIM (tap-to-claim at an exp threshold): a spot becomes claimable once exp reaches its
	# threshold (the first spot at the L2 floor); claiming restores it WITHOUT spending exp (total
	# unchanged). Below the threshold the claim is a no-op. Exp only ever rises — no spendable balance.
	Save.grove()["exp"] = G.spot_unlock_exp(0, 0)     # exp at the first spot's threshold (the L2 floor)
	var exp0 := Save.exp_total()
	var hearth_id: String = G.MAPS[0].spots[0].id
	var buy_node: Control = h.spot_hits[0].node
	h._on_spot_tap(0, 0, buy_node, _hit_center(buy_node))
	ok(h.spot_owned(hearth_id), "claiming the first spot at its threshold records the unlock")
	ok(Save.exp_total() == exp0, "claiming a spot does NOT spend exp (the total is unchanged)")
	ok(h._view == "map", "the view stays a map across a claim (no takeover)")
	# spot 1 sits at a higher threshold — below it the claim is refused, then allowed once exp reaches it
	var spot1_id: String = G.MAPS[0].spots[1].id
	h._on_spot_tap(0, 1, h.spot_hits[1].node, _hit_center(h.spot_hits[1].node))
	ok(not h.spot_owned(spot1_id), "a spot below its exp threshold is not claimable (no-op)")
	Save.grove()["exp"] = G.spot_unlock_exp(0, 1)
	h._on_spot_tap(0, 1, h.spot_hits[1].node, _hit_center(h.spot_hits[1].node))
	ok(h.spot_owned(spot1_id), "at/above its threshold the spot becomes claimable")
	# an already-restored spot is INERT — tapping it does nothing.
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

	# the completion chain: restoring the LAST spot of map 0 auto-unlocks map 1 (the completion
	# record sets the moment the map's spots are done). Raise exp past map 0's highest spot
	# threshold so every spot is claimable; the final claim appends z=0 to `gates` itself.
	Save.grove()["exp"] = G.spot_unlock_exp(0, G.MAPS[0].spots.size() - 1)   # clears every map-0 threshold
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
	gw2["exp"] = G.spot_unlock_exp(3, 0)     # exp at map-3's first spot threshold → it's claimable
	gw2["gates"] = [0, 1, 2]                  # §7: maps 1-3 gated through → map 4 spots are claimable
	h._on_spot_tap(3, 0, Button.new(), Vector2(300, 300))
	ok(int(Save.grove().get("water", 0)) == 50, "§7: a claim grants no per-spot water (water is level-ups only)")

	# 14c. the next unlock per map is its lowest-threshold spot (spot 0), claimed in order via the
	# single button — no level exclusion.
	for zc in G.MAPS.size():
		ok(int(G.map_next_unlock(zc, {}).k) == 0 and int(G.map_next_unlock(zc, {}).exp) == G.spot_unlock_exp(zc, 0), \
			"map %d's next unlock is its first spot at spot_unlock_exp(zc, 0)" % zc)

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
	ok(G.sell_reward(108).x == 8 and G.sell_reward(201).x == 1, "sell value scales with tier")

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
	# map resolution: code → line → generator → its map. One line per map: line N → map N-1.
	ok(G.map_for_line(1) == 0, "T39: the map-1 line (Wildflower) resolves to map 0")
	ok(G.map_for_line(2) == 1, "T39: the map-2 line (Feather) resolves to map 1")
	ok(G.map_for_line(3) == 2, "T39: the map-3 line (Garden tools) resolves to map 2")
	ok(G.map_for_line(4) == 3 and G.map_for_line(5) == 4, "T39: map-4/5 lines (Honey/Mushroom) resolve to maps 3/4")
	ok(G.map_for_code(305) == 2, "T39: map_for_code derives the line then the map (Garden tools t5 → map 2)")
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
	ok(G.sell_reward(505) == Vector2i(int(round(5 * float(band[4]))), 0), \
		"T39: a map-5 t5 (band %.1f) sells for %d🪙 (later map → more coins)" % [float(band[4]), int(round(5 * float(band[4])))])

	# T55: BUY price (info-bar buy a copy) = ceil(sell × BUY_MARKUP), same currency split as selling, and
	# STRICTLY above the sell value for every tier on every map (the anti-arbitrage invariant — no loop).
	var buy_arb_ok := true
	var buy_split_ok := true
	for line in [1, 3, 5]:
		for tier in range(1, G.PREMIUM_TIER + 1):
			var code: int = int(line) * 100 + tier
			var sell: Vector2i = G.sell_reward(code)
			var buy: Vector2i = G.buy_price(code)
			if buy != Vector2i(int(ceil(sell.x * G.BUY_MARKUP)), int(ceil(sell.y * G.BUY_MARKUP))):
				buy_split_ok = false
			# strictly dearer in whichever currency the item uses (coins for sub-top, 💎 for the pinnacle)
			if sell.x > 0 and not (buy.x > sell.x):
				buy_arb_ok = false
			if sell.y > 0 and not (buy.y > sell.y):
				buy_arb_ok = false
			# exactly one currency, mirroring sell
			if (buy.x > 0) == (buy.y > 0):
				buy_arb_ok = false
	ok(buy_split_ok, "T55: buy_price == ceil(sell × BUY_MARKUP) in the same currency split, every tier")
	ok(buy_arb_ok, "T55: buying ALWAYS costs strictly more than selling returns (anti-arbitrage, one currency)")
	ok(G.buy_price(103) == Vector2i(int(ceil(3 * G.BUY_MARKUP)), 0), "T55: a map-1 t3 buys for ceil(3×markup)🪙")
	var top_buy: Vector2i = G.buy_price(100 + int(G.PREMIUM_TIER))   # line 1, the pinnacle tier
	ok(top_buy.x == 0 and top_buy.y == int(ceil(G.BUY_MARKUP)), "T55: the top tier buys in 💎 = ceil(markup) (mirrors the 1💎 sell pinnacle)")

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
	Save.grove()["exp"] = G.exp_at_level(2) - 1                # one exp short of L2
	var lvg := G.earn_exp(1)                                   # crosses into L2 (no grant yet)
	G.grant_level_gift(G.level_gift(lvg))                      # Collect grants the gift + skims
	ok(Save.diamonds() == d0 + G.LEVEL_DIAMONDS, "a level-up pays diamonds on Collect")
	# T44 SKIM-SITE wiring (content.grant_level_gift): the piggy bank skimmed a slice of the
	# level-up premium — the banked-units pool advanced by exactly LEVEL_DIAMONDS × num.
	var vault1 := Vault.balance() * Vault.skim_den() + Save.vault_carry()
	ok(vault1 - vault0 == G.LEVEL_DIAMONDS * Vault.skim_num(), "granting the gift SKIMS its premium into the piggy bank (§10)")

	# 16. the discovery log + the upgrade-path card (tap an item → its ladder;
	# unseen tiers stay "?")
	finish()
