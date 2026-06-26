extends "res://games/grove/tests/grove_test_base.gd"
## grove · residents habitat — guards engine/scripts/core/habitat.gd (the payback-half model)
## and a headless smoke test of the Residents screen. Active suite (in GROVE_TESTS).

const Habitat = preload("res://engine/scripts/core/habitat.gd")

func _initialize() -> void:
	begin("grove · residents habitat")
	_test_hand()
	_test_place()
	_test_production()
	_test_screen()
	_test_screen_actions()
	_test_map_dock()
	finish()

# --- the in-hand holding area + in-hand merge ------------------------------------
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

# --- capacity-gated placement, sell, move ----------------------------------------
func _test_place() -> void:
	fresh("habitat_place")
	var mid := String(G.MAPS[0].id)   # "farmhouse"
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

# --- idle production: rate, accrual, collect -------------------------------------
func _test_production() -> void:
	var t0 := 1_000_000.0

	# rate = sum of placed tiers
	fresh("habitat_rate")
	var mid := String(G.MAPS[0].id)   # farmhouse pays COINS
	for spec in [["moss", 1], ["acorn", 2], ["lantern", 3]]:
		Habitat.hand_add(String(spec[0]), int(spec[1]))
		Habitat.place(mid, 0)
	ok(Habitat.rate(mid) == 6, "rate is the sum of placed tiers (1+2+3)")

	# accrual: one tier-1 spirit, one hour elapsed -> YIELD_PER_HOUR units pending
	fresh("habitat_accrual")
	var m := String(G.MAPS[0].id)
	Habitat.hand_add("moss", 1)
	Habitat.place(m, 0, t0)                              # settle stamps last = t0
	var p1h := Habitat.pending(m, t0 + 3600.0)
	ok(abs(p1h - Habitat.YIELD_PER_HOUR) < 0.001, "a t1 spirit accrues YIELD_PER_HOUR units in one hour")
	# the accrual is CAPPED at ACCRUAL_HOURS of output
	var pbig := Habitat.pending(m, t0 + 3600.0 * 100.0)
	ok(abs(pbig - Habitat.YIELD_PER_HOUR * Habitat.ACCRUAL_HOURS) < 0.001, "accrual clamps to the ACCRUAL_HOURS ceiling")

	# collect grants floor(pending) coins, keeps the remainder, resets the clock
	fresh("habitat_collect")
	var mc := String(G.MAPS[0].id)
	Habitat.hand_add("moss", 1)
	Habitat.place(mc, 0, t0)
	var coins_b := Save.coins()
	var r := Habitat.collect(mc, t0 + 3600.0)            # YIELD_PER_HOUR = 6.0 -> 6 coins
	ok(String(r.currency) == "coins" and int(r.amount) == int(Habitat.YIELD_PER_HOUR), "collect pays floor(pending) coins on the coin map")
	ok(Save.coins() == coins_b + int(Habitat.YIELD_PER_HOUR), "the coins are credited")
	ok(abs(Habitat.pending(mc, t0 + 3600.0) - 0.0) < 0.001, "pending resets to ~0 right after collect")

	# a PARKED map (not farmhouse) accrues but pays nothing yet
	fresh("habitat_parked_reward")
	var mp := String(G.MAPS[2].id)   # pond — parked reward
	Habitat.hand_add("moss", 1)
	Habitat.place(mp, 0, t0)
	var diamonds_b := Save.diamonds()
	var coins_p := Save.coins()
	var pend_before := Habitat.pending(mp, t0 + 3600.0 * 100.0)
	var rp := Habitat.collect(mp, t0 + 3600.0 * 100.0)
	ok(String(rp.currency) == "" and int(rp.amount) == 0, "a parked map pays nothing (reward content not shipped)")
	ok(Save.diamonds() == diamonds_b and Save.coins() == coins_p, "no currency leaks from a parked map")
	# data-loss guard: collecting a parked map must NOT erase the units it already accrued
	ok(abs(Habitat.pending(mp, t0 + 3600.0 * 100.0) - pend_before) < 0.001, "a parked collect keeps accrued production (no data-loss trap)")

	# selling does NOT erase already-banked production (settle banks before the rate drops)
	fresh("habitat_settle_keeps_acc")
	var ms := String(G.MAPS[0].id)
	Habitat.hand_add("moss", 1)
	Habitat.place(ms, 0, t0)
	Habitat.sell(ms, 0, t0 + 3600.0)                    # one hour banked, then the only spirit sold
	ok(abs(Habitat.pending(ms, t0 + 3600.0) - Habitat.YIELD_PER_HOUR) < 0.001, "an hour of production survives selling the producer")

	# the roster survives a cold reload
	fresh("habitat_persist")
	var mr := String(G.MAPS[0].id)
	Habitat.hand_add("acorn", 2)
	Habitat.place(mr, 0)
	Save._loaded = false                                 # force a reload from disk
	ok(Habitat.placed(mr).size() == 1 and int(Habitat.placed(mr)[0].tier) == 2, "placed spirits persist across a reload")

# --- the Residents screen (headless smoke + action wiring) -----------------------
func _test_screen() -> void:
	fresh("residents_screen")
	# seed a COMPLETED map 0 so the screen has a habitat to show
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
	if s._root == null:        # headless -s defers _ready to a frame; build it now (mirror grove_ui_tests)
		s._ready()
	ok(s.get_child_count() > 0, "the Residents screen builds a non-empty tree")

	# placing a spirit then rebuilding shows it on the map row
	Habitat.hand_add("moss", 1)
	Habitat.place(String(G.MAPS[0].id), 0)
	s._rebuild()
	var labels := _label_texts(s)
	ok(labels.has(String(G.MAPS[0].name)), "the screen shows the completed map's name")
	var has_cap := false
	for t in labels:
		if String(t).contains("/%d" % Habitat.DEFAULT_CAP):
			has_cap = true
	ok(has_cap, "the map row shows a capacity readout (n/%d)" % Habitat.DEFAULT_CAP)
	s.queue_free()

func _test_screen_actions() -> void:
	fresh("residents_actions")
	var z := 0
	var g := Save.grove()
	var unl := {}
	for sp in G.MAPS[z].spots:
		unl[String(sp.id)] = true
	g["unlocks"] = unl ; g["gates"] = [z] ; Save.grove_write()
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

# --- the spirits DOCK on the map (the folded-in residents management) -------------
func _test_map_dock() -> void:
	fresh("map_dock")
	var z := 0
	var g := Save.grove()
	var unl := {}
	for sp in G.MAPS[z].spots:
		unl[String(sp.id)] = true
	g["unlocks"] = unl ; g["gates"] = [z] ; Save.grove_write()
	var mid := String(G.MAPS[z].id)
	Habitat.hand_add("moss", 1)          # one to place via the dock
	Habitat.hand_add("acorn", 2)         # one placed up front so the "On map" row renders
	Habitat.place(mid, 1)                # place the acorn (index 1)

	var hx = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(hx)
	if hx.content == null:
		hx._ready()
	hx.unlocks = unl
	hx._open_map(z)
	ok(hx._spirits_dock != null and hx._spirits_dock.visible, "the spirits dock shows on a completed map")
	var labels := _label_texts(hx._spirits_dock)
	var has_cap := false
	for t in labels:
		if String(t).contains("/%d" % Habitat.DEFAULT_CAP):
			has_cap = true
	ok(has_cap, "the dock shows the open map's capacity (n/%d)" % Habitat.DEFAULT_CAP)

	# place the remaining hand spirit through the dock (select then place)
	var before := Habitat.placed(mid).size()
	hx._on_dock_hand(0)
	hx._on_dock_place(mid)
	ok(Habitat.placed(mid).size() == before + 1, "placing through the dock seats a hand spirit on the open map")

	# the dock hides on an INCOMPLETE map
	hx._open_map(1)                       # map 1 is not completed in this save
	ok(not hx._spirits_dock.visible, "the dock hides on a map that can't be populated")
	hx.queue_free()
