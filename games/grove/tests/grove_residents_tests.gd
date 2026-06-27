extends "res://games/grove/tests/grove_test_base.gd"
## grove · residents habitat — guards engine/scripts/core/habitat.gd (the payback-half model)
## and a headless smoke test of the Residents screen. Active suite (in GROVE_TESTS).

const Habitat = preload("res://engine/scripts/core/habitat.gd")
const Game = preload("res://engine/scripts/core/game.gd")   # for WATER_CAP

func _initialize() -> void:
	begin("grove · residents habitat")
	_test_hand()
	_test_place()
	_test_production()
	_test_rewards()
	_test_residents_button()
	finish()

# §1 the roster CAP now RAMPS with restored spots (Habitat.cap → Content.resident_capacity), so a habitat
# placement test needs an OPEN map. Restore one map's spots so its cap reaches DEFAULT_CAP.
func _open_spots(z: int) -> void:
	var g := Save.grove()
	if not g.has("unlocks"):
		g["unlocks"] = {}
	for sp in G.MAPS[z].spots:
		g["unlocks"][String(sp.id)] = true
	Save.grove_write()

# Override the reset to also open the HOME map (map 0) — most habitat mechanic tests place there. Tests
# that touch other maps (move, parked-reward) open those explicitly; map 1 stays closed for the button test.
func fresh(name: String) -> void:
	super.fresh(name)
	_open_spots(0)

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
	ok(Habitat.cap(mid) == Habitat.DEFAULT_CAP, "a fully-restored map reaches DEFAULT_CAP slots")
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
	_open_spots(1)                       # open the move TARGET map so it has room
	Habitat.hand_add("lantern", 3)
	Habitat.place(a, 0)
	ok(Habitat.move(a, 0, b), "moving a placed spirit between maps succeeds")
	ok(Habitat.placed(a).is_empty() and Habitat.placed(b).size() == 1, "it leaves a, lands on b")
	ok(int(Habitat.placed(b)[0].tier) == 3, "the moved instance keeps its tier")

	# bringing a placed spirit back OUT returns it to the hand (frees the slot, keeps its tier)
	fresh("habitat_unplace")
	var u := String(G.MAPS[0].id)
	Habitat.hand_add("fern", 2)
	Habitat.place(u, 0)
	ok(Habitat.placed(u).size() == 1 and Habitat.hand().is_empty(), "the spirit is placed, hand empty")
	ok(Habitat.unplace(u, 0), "bringing a placed spirit out succeeds")
	ok(Habitat.placed(u).is_empty(), "the slot is freed on the map")
	ok(Habitat.hand().size() == 1 and int(Habitat.hand()[0].tier) == 2, "it returns to the hand keeping its tier")
	ok(not Habitat.unplace(u, 0), "bringing out a bad index is refused")

# --- idle production: TIER speeds the cadence, COUNT raises the cap, AMOUNT is fixed --------------
func _test_production() -> void:
	var t0 := 1_000_000.0
	var far := t0 + 3600.0 * 100000.0   # long enough to saturate any cap

	# speed = sum of placed tiers
	fresh("habitat_rate")
	var mid := String(G.MAPS[0].id)   # farmhouse pays COINS
	for spec in [["moss", 1], ["acorn", 2], ["lantern", 3]]:
		Habitat.hand_add(String(spec[0]), int(spec[1]))
		Habitat.place(mid, 0)
	ok(Habitat.rate(mid) == 6, "speed is the sum of placed tiers (1+2+3)")

	# accrual: one tier-1 spirit, one hour -> rate × UNITS_PER_HOUR_PER_TIER units pending
	fresh("habitat_accrual")
	var m := String(G.MAPS[0].id)
	Habitat.hand_add("moss", 1)
	Habitat.place(m, 0, t0)                              # settle stamps last = t0
	var u1 := Habitat.UNITS_PER_HOUR_PER_TIER            # one tier × one hour
	ok(abs(Habitat.pending(m, t0 + 3600.0) - u1) < 1e-6, "a t1 spirit accrues UNITS_PER_HOUR_PER_TIER units in one hour")

	# TIER speeds the cadence (not the amount): a t2 accrues twice the units of a t1 in the same hour
	fresh("habitat_tier_speed")
	var mt := String(G.MAPS[0].id)
	Habitat.hand_add("moss", 2)
	Habitat.place(mt, 0, t0)
	ok(abs(Habitat.pending(mt, t0 + 3600.0) - 2.0 * u1) < 1e-6, "a t2 accrues 2× the units of a t1 (tier = faster cadence)")

	# COUNT is the cap lever: one spirit caps at BASE_CAP_UNITS, each extra adds CAP_UNITS_PER_SPIRIT
	fresh("habitat_count_cap")
	var mca := String(G.MAPS[0].id)
	Habitat.hand_add("moss", 1)
	Habitat.place(mca, 0, t0)
	ok(abs(Habitat.accrual_cap(mca) - Habitat.BASE_CAP_UNITS) < 1e-6, "one spirit caps at BASE_CAP_UNITS")
	Habitat.hand_add("moss", 1)
	Habitat.place(mca, 0, t0)
	ok(abs(Habitat.accrual_cap(mca) - (Habitat.BASE_CAP_UNITS + Habitat.CAP_UNITS_PER_SPIRIT)) < 1e-6, "a second spirit raises the cap by CAP_UNITS_PER_SPIRIT")
	ok(abs(Habitat.pending(mca, far) - Habitat.accrual_cap(mca)) < 1e-6, "accrual clamps to the count-scaled cap")

	# GATING: an empty map has no speed, no cap, no production (the ≥1-spirit gate)
	fresh("habitat_gating")
	var mg := String(G.MAPS[0].id)
	ok(Habitat.rate(mg) == 0 and Habitat.accrual_cap(mg) == 0.0, "an empty map has no speed and no cap")
	ok(Habitat.pending(mg, far) == 0.0, "an empty map accrues nothing")

	# FIXED amount: collect on the coin map pays floor(units) × per_unit (NOT scaled by tier)
	fresh("habitat_collect_coins")
	var mc := String(G.MAPS[0].id)
	Habitat.hand_add("moss", 1)
	Habitat.place(mc, 0, t0)
	var per := Habitat.reward_per_unit("farmhouse")
	var coins_b := Save.coins()
	var units := int(floor(Habitat.pending(mc, far)))
	var r := Habitat.collect(mc, far)
	ok(units > 0, "the coin map accrues whole units to collect")
	ok(String(r.currency) == "coins" and int(r.amount) == units * per, "collect pays floor(units) × per_unit coins")
	ok(Save.coins() == coins_b + units * per, "the coins are credited")
	ok(Habitat.pending(mc, far) < 1.0, "pending drops below one unit right after collect")

	# selling does NOT erase already-banked production (settle banks before the speed drops)
	fresh("habitat_settle_keeps_acc")
	var ms := String(G.MAPS[0].id)
	Habitat.hand_add("moss", 1)
	Habitat.place(ms, 0, t0)
	var banked := Habitat.pending(ms, t0 + 3600.0)
	Habitat.sell(ms, 0, t0 + 3600.0)                    # one hour banked, then the only spirit sold
	ok(abs(Habitat.pending(ms, t0 + 3600.0) - banked) < 1e-6, "an hour of production survives selling the producer")

	# the roster survives a cold reload
	fresh("habitat_persist")
	var mr := String(G.MAPS[0].id)
	Habitat.hand_add("acorn", 2)
	Habitat.place(mr, 0)
	Save._loaded = false                                 # force a reload from disk
	ok(Habitat.placed(mr).size() == 1 and int(Habitat.placed(mr)[0].tier) == 2, "placed spirits persist across a reload")

# --- the five reward streams: each map pays its own fixed-unit reward (provisional, hard-capped) --
func _test_rewards() -> void:
	var t0 := 1_000_000.0
	var far := t0 + 3600.0 * 100000.0

	# reward_currency wires all five maps (no more parked "" maps)
	ok(Habitat.reward_currency("farmhouse") == "coins", "map 1 pays coins")
	ok(Habitat.reward_currency("barn") == "water", "map 2 pays water")
	ok(Habitat.reward_currency("pond") == "boost", "map 3 pays a generator-boost charge")
	ok(Habitat.reward_currency("orchard") == "diamonds", "map 4 pays diamonds")
	ok(Habitat.reward_currency("meadow") == "residents", "map 5 pays residents (a chest)")

	# WATER (map 2) — collect tops up water, clamped to WATER_CAP (I2-safe: a fixed amount, never tier-scaled)
	fresh("reward_water")
	_open_spots(1)
	var bw := String(G.MAPS[1].id)   # barn
	Save.set_water(0)
	Habitat.hand_add("moss", 1)
	Habitat.place(bw, 0, t0)
	var rw := Habitat.collect(bw, far)
	ok(String(rw.currency) == "water" and int(rw.amount) > 0, "collecting map 2 grants water")
	ok(Save.water() == int(rw.amount), "the water is credited")
	# the clamp: collecting near the cap never exceeds WATER_CAP
	Save.set_water(int(Game.DATA.WATER_CAP) - 1)
	Habitat._settle(bw, t0)                               # re-bank a full cap of water units
	Habitat.collect(bw, far)
	ok(Save.water() == int(Game.DATA.WATER_CAP), "water clamps to WATER_CAP on collect")

	# BOOST (map 3) — collect stockpiles generator-boost CHARGES (capped); a charge arms the boost for free
	fresh("reward_boost")
	_open_spots(2)
	var bp := String(G.MAPS[2].id)   # pond
	Habitat.hand_add("moss", 1)
	Habitat.place(bp, 0, t0)
	var cb := Habitat.boost_charges()
	var rb := Habitat.collect(bp, far)
	ok(String(rb.currency) == "boost" and int(rb.amount) > 0, "collecting map 3 grants boost charges")
	ok(Habitat.boost_charges() == cb + int(rb.amount), "the charges are stockpiled")
	ok(Habitat.boost_charges() <= Habitat.BOOST_CHARGE_CAP, "the stock never exceeds BOOST_CHARGE_CAP")
	var ch := Habitat.boost_charges()
	ok(Habitat.use_boost_charge(), "a stockpiled charge can be used")
	ok(Habitat.boost_charges() == ch - 1, "using a charge decrements the stock")
	ok(G.boost_active(), "using a charge arms the generator boost (free activation)")
	ok(not Habitat.use_boost_charge(), "a second charge is refused while a boost is already live")

	# DIAMONDS (map 4) — collect pays diamonds, HARD-CAPPED per calendar day (the IAP guard)
	fresh("reward_diamonds")
	_open_spots(3)
	var bo := String(G.MAPS[3].id)   # orchard
	for _i in 6:                          # enough placed that a full accrual would exceed the daily cap
		Habitat.hand_add("moss", 1)
		Habitat.place(bo, 0, t0)
	var day0 := 3600.0 * 24.0 * 100.0    # a fixed calendar day
	var db := Save.diamonds()
	var r1 := Habitat.collect(bo, day0)
	ok(int(r1.amount) == Habitat.DIAMOND_DAILY_CAP, "the first collect of a saturated diamond map grants exactly the daily cap")
	Habitat._settle(bo, day0 - 3600.0 * 100.0)           # re-saturate within the same day
	var r2 := Habitat.collect(bo, day0 + 600.0)
	ok(int(r2.amount) == 0, "a second collect the same day grants nothing (daily cap spent)")
	Habitat._settle(bo, day0 + 86400.0 - 3600.0 * 100.0) # re-saturate for the next day
	var r3 := Habitat.collect(bo, day0 + 86400.0 + 600.0)
	ok(int(r3.amount) == Habitat.DIAMOND_DAILY_CAP, "a new day reopens the daily diamond allowance")
	ok(Save.diamonds() == db + 2 * Habitat.DIAMOND_DAILY_CAP, "total diamonds = the daily cap per distinct day")

	# MEADOW (map 5) — collect drops a CHEST of residents into the hand; chest size set by placed COUNT
	fresh("reward_chest")
	_open_spots(4)
	var bm := String(G.MAPS[4].id)   # meadow
	Habitat.hand_add("moss", 1)
	Habitat.place(bm, 0, t0)
	ok(Habitat.chest_size(bm) == 1, "one placed spirit yields a 1-chest")
	var hand_b := Habitat.hand().size()
	var rc := Habitat.collect(bm, far)
	ok(String(rc.currency) == "residents" and int(rc.chest) == 1, "collecting map 5 yields a 1-resident chest")
	ok(int(rc.amount) == 1 and Habitat.hand().size() == hand_b + 1, "the chest resident lands in the hand")
	var chest_tier := int(Habitat.hand()[Habitat.hand().size() - 1].tier)
	ok(chest_tier >= 1 and chest_tier <= 4, "a chest spirit rolls a generator tier (1–4), not a fixed tier")

	# the chest scales with COUNT: 4 placed -> a 4-chest, 8 placed -> an 8-chest
	fresh("reward_chest_scale")
	_open_spots(4)
	var bm2 := String(G.MAPS[4].id)
	for _i in 4:
		Habitat.hand_add("moss", 1)
		Habitat.place(bm2, 0, t0)
	ok(Habitat.chest_size(bm2) == 4, "four placed spirits yield a 4-chest")
	for _i in 4:
		Habitat.hand_add("moss", 1)
		Habitat.place(bm2, 0, t0)
	ok(Habitat.chest_size(bm2) == 8, "eight placed spirits yield an 8-chest")
	var hand_b2 := Habitat.hand().size()
	var rc2 := Habitat.collect(bm2, far)
	ok(int(rc2.chest) == 8 and int(rc2.amount) == 8, "an 8-chest drops eight residents")
	ok(Habitat.hand().size() == hand_b2 + 8, "all eight chest residents land in the hand")
	var all_in_range := true
	for inst in Habitat.hand().slice(hand_b2):
		if int(inst.tier) < 1 or int(inst.tier) > 4:
			all_in_range = false
	ok(all_in_range, "every chest spirit rolls a tier in 1–4 (the generator curve)")

# --- the spirits DOCK on the map (the folded-in residents management) -------------
func _test_residents_button() -> void:
	fresh("residents_button")
	var z := 0
	var g := Save.grove()
	var unl := {}
	for sp in G.MAPS[z].spots:
		unl[String(sp.id)] = true
	g["unlocks"] = unl ; g["gates"] = [z] ; Save.grove_write()
	var mid := String(G.MAPS[z].id)
	Habitat.hand_add("moss", 1)          # one to place via the dialog
	Habitat.hand_add("acorn", 2)         # one placed up front so the "On map" row renders
	Habitat.place(mid, 1)                # place the acorn (index 1)

	var hx = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(hx)
	if hx.content == null:
		hx._ready()
	hx.unlocks = unl
	hx._open_map(z)
	# the Residents nav badge shows on a completed map, captioned with the placed/cap count
	ok(hx._residents_count_btn != null and hx._residents_count_btn.visible, "the Residents badge shows on a completed map")
	ok(hx._residents_count_label != null and String(hx._residents_count_label.text) == "1/%d" % Habitat.DEFAULT_CAP,
		"the badge caption reads the placed/cap count (1/%d)" % Habitat.DEFAULT_CAP)

	# tapping the badge opens the management dialog; it carries the open map's capacity
	hx._open_residents_dialog()
	ok(hx._residents_overlay != null and is_instance_valid(hx._residents_overlay), "tapping the badge opens the management dialog")
	var texts := _label_texts(hx._residents_overlay)
	texts.append_array(_button_texts(hx._residents_overlay))
	var has_cap := false
	for t in texts:
		if String(t).contains("/%d" % Habitat.DEFAULT_CAP):
			has_cap = true
	ok(has_cap, "the dialog shows the open map's capacity (n/%d)" % Habitat.DEFAULT_CAP)

	# place the remaining hand spirit through the dialog (select then place); the badge count updates
	var before := Habitat.placed(mid).size()
	hx._on_dock_hand(0)
	hx._on_dock_place(mid)
	ok(Habitat.placed(mid).size() == before + 1, "placing through the dialog seats a hand spirit on the open map")
	ok(String(hx._residents_count_label.text) == "%d/%d" % [before + 1, Habitat.DEFAULT_CAP], "the badge count updates after placing")

	# bring a placed spirit back OUT into the hand (select → bring out)
	var placed_n := Habitat.placed(mid).size()
	var hand_n := Habitat.hand().size()
	hx._on_placed_select(0)
	hx._on_unplace(mid, 0)
	ok(Habitat.placed(mid).size() == placed_n - 1, "bringing out frees a map slot")
	ok(Habitat.hand().size() == hand_n + 1, "the brought-out spirit returns to the hand")

	# the badge hides on an INCOMPLETE map
	hx._close_residents_dialog()
	hx._open_map(1)                       # map 1 is not completed in this save
	ok(not hx._residents_count_btn.visible, "the Residents badge hides on a map that can't be populated")
	hx.queue_free()
