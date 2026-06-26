extends "res://games/grove/tests/grove_test_base.gd"
## grove · residents habitat — guards engine/scripts/core/habitat.gd (the payback-half model)
## and a headless smoke test of the Residents screen. Active suite (in GROVE_TESTS).

const Habitat = preload("res://engine/scripts/core/habitat.gd")

func _initialize() -> void:
	begin("grove · residents habitat")
	_test_hand()
	_test_place()
	_test_production()
	_test_screen_actions()
	await _test_screen()
	await _test_screen_drag_actions()
	finish()

func _test_hand() -> void:
	fresh("habitat_hand")
	ok(Habitat.hand().is_empty(), "a fresh save has an empty hand")
	Habitat.hand_add("moss")
	Habitat.hand_add("moss")
	ok(Habitat.hand().size() == 2, "two acquires land two spirits in the hand")
	ok(int(Habitat.hand()[0].tier) == 1, "an acquired spirit enters at tier 1")

	# two of a kind at the same tier MERGE in hand into one a tier up (explicit, not auto)
	ok(Habitat.hand_merge("moss", 1), "two moss t1 merge in hand")
	ok(Habitat.hand().size() == 1 and int(Habitat.hand()[0].tier) == 2, "the pair becomes one moss t2")
	ok(not Habitat.hand_merge("moss", 2), "a lone t2 cannot merge")
	Habitat.hand_add("acorn")
	ok(not Habitat.hand_merge("moss", 2), "different kinds do not merge")

func _test_place() -> void:
	fresh("habitat_place")
	var mid := String(G.MAPS[0].id)
	ok(Habitat.cap(mid) == Habitat.DEFAULT_CAP, "a map starts with DEFAULT_CAP slots")
	ok(Habitat.placed(mid).is_empty(), "a fresh map has no placed spirits")
	Habitat.hand_add("moss")
	ok(Habitat.place(mid, 0), "placing a hand spirit onto a map with room succeeds")
	ok(Habitat.placed(mid).size() == 1, "the spirit lands on the map")
	ok(Habitat.hand().is_empty(), "and leaves the hand")

	# capacity is the brake: fill the map, then placement is refused
	fresh("habitat_capacity")
	var m2 := String(G.MAPS[0].id)
	for _i in Habitat.DEFAULT_CAP:
		Habitat.hand_add("acorn")
		Habitat.place(m2, 0)
	ok(Habitat.placed(m2).size() == Habitat.DEFAULT_CAP, "the map fills to capacity")
	ok(Habitat.is_full(m2), "is_full reports a full map")
	Habitat.hand_add("acorn")
	ok(not Habitat.place(m2, 0), "placing onto a full map is refused")
	ok(Habitat.hand().size() == 1, "the refused spirit stays in the hand")

	# selling frees a slot and returns coins by tier
	fresh("habitat_sell")
	var m3 := String(G.MAPS[0].id)
	Habitat.hand_add("moss", 2)
	Habitat.place(m3, 0)
	var coins_b := Save.coins()
	var got := Habitat.sell(m3, 0)
	ok(got == Habitat.SELL_PER_TIER * 2, "selling a t2 returns SELL_PER_TIER * 2 coins")
	ok(Save.coins() == coins_b + got, "the coins are credited")
	ok(Habitat.placed(m3).is_empty(), "the slot is freed")

	# moving relocates a placed spirit to another map (frees the source slot)
	fresh("habitat_move")
	var a := String(G.MAPS[0].id)
	var b := String(G.MAPS[1].id)
	Habitat.hand_add("lantern", 3)
	Habitat.place(a, 0)
	ok(Habitat.move(a, 0, b), "moving a placed spirit between maps succeeds")
	ok(Habitat.placed(a).is_empty() and Habitat.placed(b).size() == 1, "it leaves a, lands on b")
	ok(int(Habitat.placed(b)[0].tier) == 3, "the moved instance keeps its tier")

func _test_production() -> void:
	# rate = sum of placed tiers
	fresh("habitat_rate")
	var mid := String(G.MAPS[0].id)
	for spec in [["moss", 1], ["acorn", 2], ["lantern", 3]]:
		Habitat.hand_add(String(spec[0]), int(spec[1]))
		Habitat.place(mid, 0)
	ok(Habitat.rate(mid) == 6, "rate is the sum of placed tiers (1+2+3)")

	# accrual: one tier-1 spirit, one hour elapsed -> YIELD_PER_HOUR units pending
	fresh("habitat_accrual")
	var m := String(G.MAPS[0].id)
	Habitat.hand_add("moss", 1)
	var t0 := 1_000_000.0
	Habitat.place(m, 0)
	# re-stamp last to t0 deterministically, then read one hour later
	Habitat._settle(m, t0)
	var p1h := Habitat.pending(m, t0 + 3600.0)
	ok(abs(p1h - Habitat.YIELD_PER_HOUR) < 0.001, "a t1 spirit accrues YIELD_PER_HOUR units in one hour")

	# the accrual is CAPPED at ACCRUAL_HOURS of output
	var pbig := Habitat.pending(m, t0 + 3600.0 * 100.0)
	ok(abs(pbig - Habitat.YIELD_PER_HOUR * Habitat.ACCRUAL_HOURS) < 0.001, "accrual clamps to the ACCRUAL_HOURS ceiling")

	# collect grants floor(pending) coins, keeps the remainder, resets the clock
	fresh("habitat_collect")
	var mc := String(G.MAPS[0].id)
	Habitat.hand_add("moss", 1)
	Habitat.place(mc, 0)
	Habitat._settle(mc, t0)
	var coins_b := Save.coins()
	var r := Habitat.collect(mc, t0 + 3600.0)
	ok(String(r.currency) == "coins" and int(r.amount) == int(Habitat.YIELD_PER_HOUR), "collect pays floor(pending) coins on the coin map")
	ok(Save.coins() == coins_b + int(Habitat.YIELD_PER_HOUR), "the coins are credited")
	ok(abs(Habitat.pending(mc, t0 + 3600.0) - 0.0) < 0.001, "pending resets to ~0 right after collect")

	# a PARKED map (not farmhouse) accrues but pays nothing yet
	fresh("habitat_parked_reward")
	var mp := String(G.MAPS[2].id)
	Habitat.hand_add("moss", 1)
	Habitat.place(mp, 0)
	Habitat._settle(mp, t0)
	var parked_coins_b := Save.coins()
	var diamonds_b := Save.diamonds()
	var rp := Habitat.collect(mp, t0 + 3600.0 * 100.0)
	ok(String(rp.currency) == "" and int(rp.amount) == 0, "a parked map pays nothing (reward content not shipped)")
	ok(Save.diamonds() == diamonds_b and Save.coins() == parked_coins_b, "no currency leaks from a parked map")

	# selling does NOT erase already-banked production (settle banks before the rate drops)
	fresh("habitat_settle_keeps_acc")
	var ms := String(G.MAPS[0].id)
	Habitat.hand_add("moss", 1)
	Habitat.place(ms, 0)
	Habitat._settle(ms, t0)
	Habitat.sell(ms, 0, t0 + 3600.0)
	var pr := Habitat._prod(ms)
	ok(abs(float(pr.get("acc", 0.0)) - Habitat.YIELD_PER_HOUR) < 0.001, "sell banks accrued production before the rate drops")

	# the roster survives a cold reload
	fresh("habitat_persist")
	var mr := String(G.MAPS[0].id)
	Habitat.hand_add("acorn", 2)
	Habitat.place(mr, 0)
	Save._loaded = false
	ok(Habitat.placed(mr).size() == 1 and int(Habitat.placed(mr)[0].tier) == 2, "placed spirits persist across a reload")

func _test_screen_actions() -> void:
	fresh("residents_actions")
	var z := 0
	var g := Save.grove()
	var unl := {}
	for sp in G.MAPS[z].spots:
		unl[String(sp.id)] = true
	g["unlocks"] = unl
	g["gates"] = [z]
	Save.grove_write()
	var mid := String(G.MAPS[z].id)

	# acquire stub fills the hand from the core set
	Habitat.hand_add(String(G.RESIDENT_CORE[0].id))
	Habitat.hand_add(String(G.RESIDENT_CORE[0].id))
	ok(Habitat.hand().size() == 2, "two acquires (the stub) fill the hand")
	# merge in hand
	ok(Habitat.hand_merge(String(G.RESIDENT_CORE[0].id), 1), "the two merge to a t2 in hand")
	# place onto the completed map
	ok(Habitat.place(mid, 0), "the t2 places onto the completed map")
	ok(Habitat.rate(mid) == 2, "the placed t2 sets the map's rate to 2")

func _test_screen() -> void:
	fresh("residents_screen")
	# seed a COMPLETED map 0 so the screen has a habitat to show (same recipe the residents tests use)
	var z := 0
	var g := Save.grove()
	var unl := {}
	for sp in G.MAPS[z].spots:
		unl[String(sp.id)] = true
	g["unlocks"] = unl
	g["gates"] = [z]
	Save.grove_write()
	ok(G.can_populate(z, unl, [z]), "map 0 is complete (screen precondition)")

	var s = load("res://engine/scenes/Residents.tscn").instantiate()
	get_root().add_child(s)
	if not s.is_node_ready():
		s._ready()
	await create_timer(0.05).timeout
	ok(s.get_child_count() > 0, "the Residents screen builds a non-empty tree")
	ok(s._root.find_child("ResidentsShell", true, false) != null, "the Residents screen uses a Grove-style parchment shell")
	ok(s._root.find_child("ResidentsBanner", true, false) != null, "the Residents screen has a Grove-style title banner")
	ok(s._root.find_child("HandTray", true, false) != null, "the hand is presented as a native tray")
	ok(s._root.find_child("ResidentsFooterBar", true, false) != null, "the screen actions sit in a native footer bar")
	# placing a spirit then rebuilding shows it on the map row
	Habitat.hand_add("moss", 1)
	Habitat.place(String(G.MAPS[0].id), 0)
	s._rebuild()
	await create_timer(0.05).timeout
	var labels := _label_texts(s)
	ok(labels.has(String(G.MAPS[0].name)), "the screen shows the completed map's name")
	var has_cap := false
	for t in labels:
		if String(t).contains("/%d" % Habitat.DEFAULT_CAP):
			has_cap = true
	ok(has_cap, "the map row shows a capacity readout (n/%d)" % Habitat.DEFAULT_CAP)
	ok(s._root.find_child("ResidentCard_*", true, false) != null, "residents render inside finished card frames")
	s.queue_free()
	await process_frame

func _test_screen_drag_actions() -> void:
	fresh("residents_drag")
	var z := 0
	var g := Save.grove()
	var unl := {}
	for sp in G.MAPS[z].spots:
		unl[String(sp.id)] = true
	g["unlocks"] = unl
	g["gates"] = [z]
	Save.grove_write()
	var mid := String(G.MAPS[z].id)

	Habitat.hand_add("moss")
	Habitat.hand_add("moss")
	var s = load("res://engine/scenes/Residents.tscn").instantiate()
	get_root().add_child(s)
	if not s.is_node_ready():
		s._ready()
	await create_timer(0.05).timeout

	var h0 := s._root.find_child("HandSpirit_0", true, false) as Control
	var h1 := s._root.find_child("HandSpirit_1", true, false) as Control
	s._begin_hand_drag(0, h0.get_global_rect().get_center())
	s._end_hand_drag(h1.get_global_rect().get_center())
	await create_timer(0.05).timeout
	ok(Habitat.hand().size() == 1 and int(Habitat.hand()[0].tier) == 2, "dragging matching hand spirits merges them")

	Habitat.hand_add("acorn")
	s._rebuild()
	await create_timer(0.05).timeout
	var h_acorn := s._root.find_child("HandSpirit_1", true, false) as Control
	var row := s._root.find_child("MapRow_%s" % mid, true, false) as Control
	s._begin_hand_drag(1, h_acorn.get_global_rect().get_center())
	s._end_hand_drag(row.get_global_rect().get_center())
	await create_timer(0.05).timeout
	ok(Habitat.placed(mid).size() == 1 and String(Habitat.placed(mid)[0].kind) == "acorn", "dragging a hand spirit onto a map places it")

	s.queue_free()
	await process_frame
