extends "res://games/grove/tests/grove_test_base.gd"
## grove · residents habitat — guards engine/scripts/core/habitat.gd (the payback-half model)
## and a headless smoke test of the Residents screen. Active suite (in GROVE_TESTS).

const Habitat = preload("res://engine/scripts/core/habitat.gd")
const Game = preload("res://engine/scripts/core/game.gd")   # for WATER_CAP

func _initialize() -> void:
	begin("grove · residents habitat")
	_test_hand()
	_test_home_map_rules()
	await _test_hand_drop_merge_targets_slot()
	_test_place()
	_test_place_merge()
	_test_production()
	_test_rewards()
	await _test_residents_dock()
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

func _resident_kind_for_map(z: int) -> String:
	var lines: Array = G.resident_lines(z)
	return String(lines[0].id) if not lines.is_empty() else ""

# Override the reset to also open the HOME map (map 0) — most habitat mechanic tests place there. Tests
# that touch other maps (move, parked-reward) open those explicitly; map 1 stays closed for the button test.
func fresh(name: String) -> void:
	super.fresh(name)
	_open_spots(0)

func _test_home_map_rules() -> void:
	fresh("resident_home_map_rules")
	ok(G.resident_home_map("ember") == 0, "ember belongs to the Farm")
	ok(G.resident_home_map_id("sprout") == String(G.MAPS[1].id), "sprout belongs to the second map")
	ok(G.resident_home_map("not_a_resident") == -1, "unknown resident kinds have no home map")
	ok(G.resident_home_map_id("not_a_resident") == "", "unknown resident kinds have no home map id")

	fresh("habitat_home_map_place")
	_open_spots(1)
	var farm_id := String(G.MAPS[0].id)
	var barn_id := String(G.MAPS[1].id)
	Habitat.hand_add("ember", 1)
	ok(Habitat.can_place_on(farm_id, Habitat.hand()[0]), "a resident can be placed on its home map")
	ok(not Habitat.can_place_on(barn_id, Habitat.hand()[0]), "a resident cannot be placed on a non-home map")
	ok(Habitat.place(farm_id, 0), "home-map placement succeeds")
	Habitat.hand_add("ember", 1)
	ok(not Habitat.place(barn_id, 0), "wrong-map placement is refused")
	ok(Habitat.hand().size() == 1 and Habitat.placed(barn_id).is_empty(), "a refused wrong-map resident stays in hand")

	fresh("habitat_home_map_merge_move")
	_open_spots(1)
	Habitat.hand_add("ember", 2)
	ok(Habitat.place(farm_id, 0), "setup places ember on Farm")
	Habitat.hand_add("ember", 2)
	ok(Habitat.place_merge(farm_id, 0, 0), "home-map place-merge still succeeds")
	ok(not Habitat.move(farm_id, 0, barn_id), "moving a resident away from its home map is refused")
	ok(Habitat.placed(farm_id).size() == 1 and Habitat.placed(barn_id).is_empty(), "wrong-map move leaves the resident in place")

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

	fresh("habitat_hand_in_place")
	Habitat.hand_add("ember", 1)
	Habitat.hand_add("sprout", 1)
	Habitat.hand_add("ember", 1)
	Habitat.hand_add("dewdrop", 1)
	ok(Habitat.hand_merge("ember", 1), "two same-tier residents merge in a mixed hand")
	var merged := Habitat.hand()
	ok(merged.size() == 3 \
		and String(merged[0].kind) == "ember" and int(merged[0].tier) == 2 \
		and String(merged[1].kind) == "sprout" \
		and String(merged[2].kind) == "dewdrop", \
		"an in-hand merge replaces the first merged slot instead of appending")

func _test_hand_drop_merge_targets_slot() -> void:
	fresh("residents_hand_merge_drop_target")
	var z := 0
	var g := Save.grove()
	var unl := {}
	for sp in G.MAPS[z].spots:
		unl[String(sp.id)] = true
	g["unlocks"] = unl ; g["gates"] = [z] ; Save.grove_write()
	for zz in range(G.MAPS.size()):
		G.claim_unlock_reward(zz)
	Habitat.hand_add("ember", 1)
	Habitat.hand_add("sprout", 1)
	Habitat.hand_add("ember", 1)
	Habitat.hand_add("dewdrop", 1)

	var hx = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(hx)
	hx._login_shown_launch = true
	await create_timer(0.1).timeout
	hx.unlocks = unl
	hx._open_map(z)
	hx._open_select()
	await create_timer(0.08).timeout
	var source := _hand_orb_at_index(hx, 0)
	var target := _hand_orb_at_index(hx, 2)
	ok(source != null and target != null, "the hand merge target test has source and target cells")
	if source != null and target != null:
		_drag_select(hx, _hit_center(source), _hit_center(target))
		await create_timer(0.06).timeout
		var h := Habitat.hand()
		ok(h.size() == 3 \
			and String(h[0].kind) == "sprout" \
			and String(h[1].kind) == "ember" and int(h[1].tier) == 2 \
			and String(h[2].kind) == "dewdrop", \
			"dragging onto a hand match upgrades the drop slot instead of appending to the end")
	hx.queue_free()

# --- capacity-gated placement, sell, move ----------------------------------------
func _test_place() -> void:
	fresh("habitat_place")
	var mid := String(G.MAPS[0].id)   # "farmhouse"
	var farm_kind := _resident_kind_for_map(0)
	ok(Habitat.cap(mid) == Habitat.DEFAULT_CAP, "a fully-restored map reaches DEFAULT_CAP slots")
	ok(Habitat.placed(mid).is_empty(), "a fresh map has no placed spirits")
	Habitat.hand_add(farm_kind)
	ok(Habitat.place(mid, 0), "placing a hand spirit onto a map with room succeeds")
	ok(Habitat.placed(mid).size() == 1, "the spirit lands on the map")
	ok(Habitat.hand().is_empty(), "and leaves the hand")

	# capacity is the brake: fill the map, then placement is refused
	fresh("habitat_capacity")
	var m2 := String(G.MAPS[0].id)
	for _i in Habitat.DEFAULT_CAP:
		Habitat.hand_add(farm_kind)
		Habitat.place(m2, 0)
	ok(Habitat.placed(m2).size() == Habitat.DEFAULT_CAP, "the map fills to capacity")
	ok(Habitat.is_full(m2), "is_full reports a full map")
	Habitat.hand_add(farm_kind)
	ok(not Habitat.place(m2, 0), "placing onto a full map is refused")
	ok(Habitat.hand().size() == 1, "the refused spirit stays in the hand")

	# selling frees a slot and returns coins by tier
	fresh("habitat_sell")
	var m3 := String(G.MAPS[0].id)
	Habitat.hand_add(farm_kind, 2)
	Habitat.place(m3, 0)
	var coins_b := Save.coins()
	var got := Habitat.sell(m3, 0)
	ok(got == Habitat.SELL_PER_TIER * 2, "selling a t2 returns SELL_PER_TIER * 2 coins")
	ok(Save.coins() == coins_b + got, "the coins are credited")
	ok(Habitat.placed(m3).is_empty(), "the slot is freed")

	# an IN-HAND spirit sells too (same per-tier value), dropping it from the hand
	Habitat.hand_add(farm_kind, 3)
	Habitat.hand_add(farm_kind, 1)
	var hcoins_b := Save.coins()
	var hgot := Habitat.sell_hand(0)
	ok(hgot == Habitat.SELL_PER_TIER * 3, "selling an in-hand t3 returns SELL_PER_TIER * 3 coins")
	ok(Save.coins() == hcoins_b + hgot, "the hand-sell coins are credited")
	ok(Habitat.hand().size() == 1 and String(Habitat.hand()[0].kind) == farm_kind, "the sold spirit leaves the hand")
	ok(Habitat.sell_hand(9) == 0, "selling a bad hand index is refused")

	# moving across maps is refused when the target is not the resident's home map.
	fresh("habitat_move")
	var a := String(G.MAPS[0].id)
	var b := String(G.MAPS[1].id)
	_open_spots(1)                       # open the move TARGET map so it has room
	Habitat.hand_add(farm_kind, 3)
	Habitat.place(a, 0)
	ok(not Habitat.move(a, 0, b), "moving a placed spirit to a non-home map is refused")
	ok(Habitat.placed(a).size() == 1 and Habitat.placed(b).is_empty(), "it stays on the home map")
	ok(int(Habitat.placed(a)[0].tier) == 3, "the refused move keeps its tier")

	# bringing a placed spirit back OUT returns it to the hand (frees the slot, keeps its tier)
	fresh("habitat_unplace")
	var u := String(G.MAPS[0].id)
	Habitat.hand_add(farm_kind, 2)
	Habitat.place(u, 0)
	ok(Habitat.placed(u).size() == 1 and Habitat.hand().is_empty(), "the spirit is placed, hand empty")
	ok(Habitat.unplace(u, 0), "bringing a placed spirit out succeeds")
	ok(Habitat.placed(u).is_empty(), "the slot is freed on the map")
	ok(Habitat.hand().size() == 1 and int(Habitat.hand()[0].tier) == 2, "it returns to the hand keeping its tier")
	ok(not Habitat.unplace(u, 0), "bringing out a bad index is refused")

# --- drag-merge in hand INTO a placed spirit (the on-map merge: drop a hand orb onto a match) ------
func _test_place_merge() -> void:
	fresh("habitat_place_merge")
	var mid := String(G.MAPS[0].id)
	var farm_kind := _resident_kind_for_map(0)
	var barn_kind := _resident_kind_for_map(1)
	Habitat.hand_add(farm_kind, 2)       # the one we'll place
	Habitat.place(mid, 0)
	Habitat.hand_add(farm_kind, 2)       # the in-hand match dragged onto it
	ok(Habitat.placed(mid).size() == 1 and Habitat.hand().size() == 1, "one resident t2 placed, one matching in hand")
	ok(Habitat.place_merge(mid, 0, 0), "a same-kind+tier hand spirit merges INTO the placed one")
	ok(Habitat.hand().is_empty(), "the dragged hand spirit is consumed by the on-map merge")
	ok(Habitat.placed(mid).size() == 1 and int(Habitat.placed(mid)[0].tier) == 3, "the placed spirit goes one tier up (t3)")

	# a mismatch never merges (kind or tier), and the hand spirit is kept
	Habitat.hand_add(barn_kind, 3)
	ok(not Habitat.place_merge(mid, 0, 0), "a different KIND does not merge onto the placed spirit")
	Habitat.hand_add(farm_kind, 1)
	ok(not Habitat.place_merge(mid, 1, 0), "a different TIER does not merge onto the placed spirit")
	ok(Habitat.hand().size() == 2, "both mismatched spirits stay in the hand")
	ok(not Habitat.place_merge(mid, 9, 0) and not Habitat.place_merge(mid, 0, 9), "bad indices are refused")

	# a MAX_TIER placed spirit cannot climb higher
	fresh("habitat_place_merge_max")
	Habitat.hand_add(farm_kind, Habitat.MAX_TIER)
	Habitat.place(mid, 0)
	Habitat.hand_add(farm_kind, Habitat.MAX_TIER)
	ok(not Habitat.place_merge(mid, 0, 0), "a max-tier placed spirit refuses an on-map merge")
	ok(Habitat.hand().size() == 1, "the would-be merge spirit stays in hand at max tier")

# --- idle production: TIER speeds the cadence, COUNT raises the cap, AMOUNT is fixed --------------
func _test_production() -> void:
	var t0 := 1_000_000.0
	var far := t0 + 3600.0 * 100000.0   # long enough to saturate any cap

	# speed = sum of placed tiers (the driver — unchanged)
	fresh("habitat_rate")
	var mid := String(G.MAPS[0].id)   # farmhouse pays COINS
	var farm_kind := _resident_kind_for_map(0)
	for spec in [[farm_kind, 1], [farm_kind, 2], [farm_kind, 3]]:
		Habitat.hand_add(String(spec[0]), int(spec[1]))
		Habitat.place(mid, 0)
	ok(Habitat.rate(mid) == 6, "speed is the sum of placed tiers (1+2+3)")

	# accrual scales with Σtier AND the per-map multiplier: a t1 on farmhouse (×5) banks
	# 0.25 × Σtier(1) × 5 = 1.25 coins in one hour
	fresh("habitat_accrual")
	var m := String(G.MAPS[0].id)
	var mf := Habitat.reward_mult("farmhouse")
	Habitat.hand_add(farm_kind, 1)
	Habitat.place(m, 0, t0)                              # settle stamps last = t0
	ok(abs(Habitat.pending(m, t0 + 3600.0) - Habitat.UNITS_PER_HOUR_PER_TIER * 1.0 * mf) < 1e-6, \
		"a t1 banks 0.25 × Σtier × MULT currency in one hour")

	# TIER raises the rate: a t2 accrues twice a t1 in the same hour (Σtier doubles)
	fresh("habitat_tier_speed")
	var mt := String(G.MAPS[0].id)
	Habitat.hand_add(farm_kind, 2)
	Habitat.place(mt, 0, t0)
	ok(abs(Habitat.pending(mt, t0 + 3600.0) - Habitat.UNITS_PER_HOUR_PER_TIER * 2.0 * mf) < 1e-6, \
		"a t2 accrues 2× a t1 — tier raises the rate")

	# Σtier is the driver — COUNT raises the rate the same way: two t1 (Σ2) == one t2 (Σ2)
	fresh("habitat_count_speed")
	var mcs := String(G.MAPS[0].id)
	Habitat.hand_add(farm_kind, 1) ; Habitat.place(mcs, 0, t0)
	Habitat.hand_add(farm_kind, 1) ; Habitat.place(mcs, 0, t0)
	ok(abs(Habitat.pending(mcs, t0 + 3600.0) - Habitat.UNITS_PER_HOUR_PER_TIER * 2.0 * mf) < 1e-6, \
		"two t1 (Σ2) accrue the same as one t2 — Σtier is the driver")

	# CAP = (3 + Σtier) × MULT — BOTH tier and count raise it (via Σtier)
	fresh("habitat_cap_count")
	var mca := String(G.MAPS[0].id)
	Habitat.hand_add(farm_kind, 1)
	Habitat.place(mca, 0, t0)
	ok(abs(Habitat.accrual_cap(mca) - (3.0 + 1.0) * mf) < 1e-6, "one t1 caps at (3 + Σtier) × MULT")
	Habitat.hand_add(farm_kind, 1)
	Habitat.place(mca, 0, t0)
	ok(abs(Habitat.accrual_cap(mca) - (3.0 + 2.0) * mf) < 1e-6, "a second spirit raises the cap (Σtier 1→2)")
	# tier raises the cap too (NEW — the old cap was count-only)
	fresh("habitat_cap_tier")
	var mct := String(G.MAPS[0].id)
	Habitat.hand_add(farm_kind, 3)
	Habitat.place(mct, 0, t0)
	ok(abs(Habitat.accrual_cap(mct) - (3.0 + 3.0) * mf) < 1e-6, "one t3 caps higher than one t1 — tier raises the cap")
	ok(abs(Habitat.pending(mct, far) - Habitat.accrual_cap(mct)) < 1e-6, "accrual clamps to the Σtier-scaled cap")

	# GATING: an empty map has no speed, no cap, no production (the ≥1-spirit gate)
	fresh("habitat_gating")
	var mg := String(G.MAPS[0].id)
	ok(Habitat.rate(mg) == 0 and Habitat.accrual_cap(mg) == 0.0, "an empty map has no speed and no cap")
	ok(Habitat.pending(mg, far) == 0.0, "an empty map accrues nothing")

	# COLLECT pays floor(pending) of the map's currency directly (MULT baked into pending)
	fresh("habitat_collect_coins")
	var mc := String(G.MAPS[0].id)
	Habitat.hand_add(farm_kind, 1)
	Habitat.place(mc, 0, t0)
	var coins_b := Save.coins()
	var amt := int(floor(Habitat.pending(mc, far)))
	var r := Habitat.collect(mc, far)
	ok(amt > 0, "the coin map accrues whole coins to collect")
	ok(String(r.currency) == "coins" and int(r.amount) == amt, "collect pays floor(pending) coins")
	ok(Save.coins() == coins_b + amt, "the coins are credited")
	ok(Habitat.pending(mc, far) < 1.0, "pending drops below one unit right after collect")

	# SUB-THRESHOLD: a premium ×0.2 map whose whole cap is < 1 currency yields nothing
	# meadow (×0.2) with a single t1: cap = 4 × 0.2 = 0.8 < 1 → 0
	fresh("habitat_subthreshold")
	_open_spots(4)
	var msub := String(G.MAPS[4].id)
	Habitat.hand_add(_resident_kind_for_map(4), 1)
	Habitat.place(msub, 0, t0)
	ok(Habitat.accrual_cap(msub) < 1.0, "a lone t1 on a ×0.2 map caps below one whole unit")
	var rsub := Habitat.collect(msub, far)
	ok(int(rsub.amount) == 0, "a sub-one-unit cap yields nothing on collect")

	# selling does NOT erase already-banked production (settle banks before the speed drops)
	fresh("habitat_settle_keeps_acc")
	var ms := String(G.MAPS[0].id)
	Habitat.hand_add(farm_kind, 1)
	Habitat.place(ms, 0, t0)
	var banked := Habitat.pending(ms, t0 + 3600.0)
	Habitat.sell(ms, 0, t0 + 3600.0)                    # one hour banked, then the only spirit sold
	ok(abs(Habitat.pending(ms, t0 + 3600.0) - banked) < 1e-6, "an hour of production survives selling the producer")

	# the roster survives a cold reload
	fresh("habitat_persist")
	var mr := String(G.MAPS[0].id)
	Habitat.hand_add(farm_kind, 2)
	Habitat.place(mr, 0)
	Save._loaded = false                                 # force a reload from disk
	ok(Habitat.placed(mr).size() == 1 and int(Habitat.placed(mr)[0].tier) == 2, "placed spirits persist across a reload")

# --- the five reward streams: each map pays its own currency = floor(pending) × nothing (MULT is in pending) --
func _test_rewards() -> void:
	var t0 := 1_000_000.0
	var far := t0 + 3600.0 * 100000.0

	# reward_currency wires all five maps (no more parked "" maps)
	ok(Habitat.reward_currency("farmhouse") == "coins", "map 1 pays coins")
	ok(Habitat.reward_currency("barn") == "water", "map 2 pays water")
	ok(Habitat.reward_currency("pond") == "boost", "map 3 pays a generator-boost charge")
	ok(Habitat.reward_currency("orchard") == "diamonds", "map 4 pays diamonds")
	ok(Habitat.reward_currency("meadow") == "residents", "map 5 pays residents")

	# the per-map multiplier ladder [5, 1, 0.2, 0.1, 0.2]
	ok(abs(Habitat.reward_mult("farmhouse") - 5.0) < 1e-6, "farmhouse ×5")
	ok(abs(Habitat.reward_mult("barn") - 1.0) < 1e-6, "barn ×1")
	ok(abs(Habitat.reward_mult("pond") - 0.2) < 1e-6, "pond ×0.2")
	ok(abs(Habitat.reward_mult("orchard") - 0.1) < 1e-6, "orchard ×0.1")
	ok(abs(Habitat.reward_mult("meadow") - 0.2) < 1e-6, "meadow ×0.2")

	fresh("reward_pool_source_weight")
	for z in G.MAPS.size():
		_open_spots(z)
	var source_id := String(G.MAPS[0].id)
	var pool := Habitat.resident_reward_pool(source_id)
	var weights := {}
	for entry in pool:
		weights[String(entry.get("kind", ""))] = int(entry.get("weight", 0))
	ok(weights.get("ember", 0) == 3, "source map resident has 3x expedition reward weight")
	ok(weights.get("sprout", 0) == 1 and weights.get("dewdrop", 0) == 1 \
		and weights.get("breeze", 0) == 1 and weights.get("starlight", 0) == 1, \
		"other unlocked resident lines remain in the reward pool at 1x")
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var rolled := Habitat.roll_reward_kind(source_id, rng)
	ok(weights.has(rolled), "weighted rolling returns a kind from the weighted pool")

	# WATER (map 2, ×1) — collect tops up water, still clamped to WATER_CAP inside Save.add_water
	fresh("reward_water")
	_open_spots(1)
	var bw := String(G.MAPS[1].id)   # barn
	Save.set_water(0)
	Habitat.hand_add(_resident_kind_for_map(1), 1)
	Habitat.place(bw, 0, t0)
	var rw := Habitat.collect(bw, far)
	ok(String(rw.currency) == "water" and int(rw.amount) > 0, "collecting map 2 grants water")
	ok(Save.water() == int(rw.amount), "the water is credited")
	# the inherent clamp: collecting near the cap never exceeds WATER_CAP
	Save.set_water(int(Game.DATA.WATER_CAP) - 1)
	Habitat._settle(bw, t0)                               # re-bank a full cap of water
	Habitat.collect(bw, far)
	ok(Save.water() == int(Game.DATA.WATER_CAP), "water clamps to WATER_CAP on collect")

	# BOOST (map 3, ×0.2) — collect stockpiles generator-boost CHARGES; NO stock cap now
	fresh("reward_boost")
	_open_spots(2)
	var bp := String(G.MAPS[2].id)   # pond
	for _i in 8:                          # Σtier 8 → cap (3+8)×0.2 = 2.2 → ≥1 charge
		Habitat.hand_add(_resident_kind_for_map(2), 1)
		Habitat.place(bp, 0, t0)
	var cb := Habitat.boost_charges()
	var rb := Habitat.collect(bp, far)
	ok(String(rb.currency) == "boost" and int(rb.amount) > 0, "collecting map 3 grants boost charges")
	ok(Habitat.boost_charges() == cb + int(rb.amount), "the charges are stockpiled")
	var ch := Habitat.boost_charges()
	ok(Habitat.use_boost_charge(), "a stockpiled charge can be used")
	ok(Habitat.boost_charges() == ch - 1, "using a charge decrements the stock")
	ok(G.boost_active(), "using a charge arms the generator boost (free activation)")
	ok(not Habitat.use_boost_charge(), "a second charge is refused while a boost is already live")

	# DIAMONDS (map 4, ×0.1) — collect pays floor(pending) diamonds, NO daily cap
	fresh("reward_diamonds")
	_open_spots(3)
	var bo := String(G.MAPS[3].id)   # orchard
	for _i in 8:                          # 8 × t6 → Σ48 → cap (3+48)×0.1 = 5.1 → 5 diamonds in ONE collect
		Habitat.hand_add(_resident_kind_for_map(3), 6)
		Habitat.place(bo, 0, t0)
	var db := Save.diamonds()
	var rd := Habitat.collect(bo, far)
	ok(String(rd.currency) == "diamonds" and int(rd.amount) == 5, "a saturated orchard pays 5 diamonds in ONE collect — 5 > the old 3/day cap, which is gone")
	ok(Save.diamonds() == db + int(rd.amount), "the diamonds are credited")

	# MEADOW (map 5, ×0.2) — collect grants floor(pending) residents via the SHARED rush grant_chest
	fresh("reward_meadow")
	_open_spots(4)
	var bm := String(G.MAPS[4].id)   # meadow
	for _i in 8:                          # Σ8 → cap (3+8)×0.2 = 2.2 → 2 residents
		Habitat.hand_add(_resident_kind_for_map(4), 1)
		Habitat.place(bm, 0, t0)
	var hand_b := Habitat.hand().size()
	var rc := Habitat.collect(bm, far)
	ok(String(rc.currency) == "residents" and int(rc.amount) == 2, "collecting map 5 grants floor(pending) residents")
	ok(Habitat.hand().size() == hand_b + int(rc.amount), "the residents land in the hand")
	# tiers roll the generator curve (1–4), same as the rush result — not the placed tier
	var all_in_range := true
	for inst in Habitat.hand().slice(hand_b):
		if int(inst.tier) < 1 or int(inst.tier) > 4:
			all_in_range = false
	ok(all_in_range, "meadow residents roll a generator tier (1–4) — the same code as the rush result")


# --- the spirits DOCK in the place-picker (the folded-in residents management, drag-driven) -------
# The standalone Residents button + modal dialog are GONE; placement/merge/sell/bring-out happen in the
# place-picker — an in-hand COLUMN on the right + each map's housed STRIP — driven through the single input
# surface (drag a hand orb onto a map to place / onto a match to merge; a housed orb onto the column to
# bring out; a tap on a housed orb focuses it for Sell). This drives the REAL drag path (_on_input).
func _test_residents_dock() -> void:
	fresh("resident_locked_cells_partial")
	var farm_kind_partial := _resident_kind_for_map(0)
	var partial_g := Save.grove()
	var partial_unl := {String(G.MAPS[0].spots[0].id): true}
	partial_g["unlocks"] = partial_unl
	partial_g["gates"] = [0]
	Save.grove_write()
	var partial_mid := String(G.MAPS[0].id)
	Habitat.hand_add(farm_kind_partial, 1)
	Habitat.place(partial_mid, 0)
	var hx_locked = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(hx_locked)
	hx_locked._login_shown_launch = true
	await create_timer(0.1).timeout
	hx_locked.unlocks = partial_unl
	hx_locked._open_select()
	await create_timer(0.08).timeout
	var locked_cells: Array = hx_locked.content.find_children("MapResidentRailLockedCell_*", "Control", true, false)
	ok(locked_cells.size() == G.RESIDENT_SLOTS_MAX - Habitat.cap(partial_mid), "resident rails show grey locked cells above current capacity")
	hx_locked.queue_free()

	fresh("resident_tap_home_hint")
	var hint_g := Save.grove()
	var hint_unl := {}
	for zz in [0, 1]:
		hint_unl[String(G.MAPS[zz].spots[0].id)] = true
	hint_g["unlocks"] = hint_unl
	hint_g["gates"] = [0, 1]
	Save.grove_write()
	Habitat.hand_add("ember", 1)
	var hx_hint = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(hx_hint)
	hx_hint._login_shown_launch = true
	await create_timer(0.1).timeout
	hx_hint.unlocks = hint_unl
	hx_hint._open_select()
	await create_timer(0.08).timeout
	_map_tap_at(hx_hint, _hit_center(_hand_orb_of(hx_hint, "ember", 1)))
	await create_timer(0.06).timeout
	var farm_card := _card_for_map(hx_hint, 0)
	var other_card := _card_for_map(hx_hint, 1)
	ok(farm_card != null and String(farm_card.get_meta("resident_hint_state", "")) == "valid_select", "tap-select softly marks the resident home map")
	ok(other_card != null and String(other_card.get_meta("resident_hint_state", "")) == "invalid_select", "tap-select dims non-home maps")
	hx_hint.queue_free()

	fresh("resident_wrong_map_drag_hint")
	var drag_g := Save.grove()
	var drag_unl := {}
	for zz in [0, 1]:
		for sp in G.MAPS[zz].spots:
			drag_unl[String(sp.id)] = true
	drag_g["unlocks"] = drag_unl
	drag_g["gates"] = [0, 1]
	Save.grove_write()
	Habitat.hand_add("sprout", 1)
	var hx_drag = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(hx_drag)
	hx_drag._login_shown_launch = true
	await create_timer(0.1).timeout
	hx_drag.unlocks = drag_unl
	hx_drag._open_select()
	await create_timer(0.08).timeout
	var sprout := _hand_orb_of(hx_drag, "sprout", 1)
	var farm_drop := _card_for_map(hx_drag, 0)
	var barn_drop := _card_for_map(hx_drag, 1)
	var farm_drop_point := _card_drop_point(farm_drop)
	var barn_drop_point := _card_drop_point(barn_drop)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT ; down.pressed = true ; down.position = _hit_center(sprout)
	hx_drag._on_input(down)
	var mv := InputEventMouseMotion.new()
	mv.position = farm_drop_point
	mv.relative = mv.position - down.position
	mv.button_mask = MOUSE_BUTTON_MASK_LEFT
	hx_drag._on_input(mv)
	ok(String(farm_drop.get_meta("resident_hint_state", "")) == "invalid_drag", "wrong map is strongly marked invalid during drag")
	ok(String(barn_drop.get_meta("resident_hint_state", "")) == "valid_drag", "home map is strongly marked valid during drag")
	var up := down.duplicate()
	up.pressed = false ; up.position = farm_drop_point
	hx_drag._on_input(up)
	ok(Habitat.hand().size() == 1 and Habitat.placed(String(G.MAPS[0].id)).is_empty(), "dropping a resident on the wrong map is refused")
	_drag_select(hx_drag, _hit_center(_hand_orb_of(hx_drag, "sprout", 1)), barn_drop_point)
	ok(Habitat.hand().is_empty() and Habitat.placed(String(G.MAPS[1].id)).size() == 1, "dropping on the home map places the resident")
	hx_drag.queue_free()

	fresh("residents_dock")
	var z := 0
	var g := Save.grove()
	var unl := {}
	for sp in G.MAPS[z].spots:
		unl[String(sp.id)] = true
	g["unlocks"] = unl ; g["gates"] = [z] ; Save.grove_write()
	for zz in range(G.MAPS.size()):
		G.claim_unlock_reward(zz)         # pre-claim every map's one-time gift so _open_map grants no surprise hand spirit
	var mid := String(G.MAPS[z].id)
	var farm_kind := _resident_kind_for_map(z)
	Habitat.hand_add(farm_kind, 2)       # one already housed so the strip renders
	Habitat.place(mid, 0)
	Habitat.hand_add(farm_kind, 2)       # a MATCH to drag onto it (merge)
	Habitat.hand_add(farm_kind, 1)       # a non-match tier to drag onto the map (place)

	var hx = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(hx)
	hx._login_shown_launch = true         # block the day-first login calendar (a _ready-deferred pop-up)
	await create_timer(0.1).timeout       # let the ENGINE _ready it once + flush its deferreds (no manual _ready double-fire)
	hx.unlocks = unl
	# the standalone residents dialog + nav button are removed outright
	ok(not hx.has_method("_open_residents_dialog"), "the standalone residents dialog method is gone")
	ok(not hx.has_method("_make_residents_button"), "the standalone residents nav button is gone")
	hx._open_map(z)
	ok(hx._lv_panel != null and hx._lv_panel.visible, "the player Lv chip rides a map")

	# the place-picker drops the Lv chip and builds the in-hand column + the housed strip
	hx._open_select()
	await create_timer(0.08).timeout      # containers settle (no more _ready to switch the view back)
	ok(hx._view == "select", "the place-picker view stays open")
	ok(not hx._lv_panel.visible, "the place-picker hides the top-left Lv chip")
	ok(hx._hand_panel != null and is_instance_valid(hx._hand_panel), "the place-picker carries the in-hand column")
	# every spirit orb IGNOREs the mouse so the drag hit-test owns input (only the card Collect button — the
	# documented exception — and a focus-gated Sell button intercept; the orbs/strip/hand-column never do).
	var orbs_ignore := true
	for arr in [hx._hand_orbs, hx._placed_orbs]:
		for o in arr:
			if (o.node as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
				orbs_ignore = false
	ok(orbs_ignore, "every spirit orb IGNOREs the mouse — the single-surface drag hit-test owns input")
	ok(hx._hand_orbs.size() == 2, "the two in-hand spirits register as drag sources")
	ok(_placed_for(hx, z) == 1, "the completed map's housed orb registers (drag-out / merge / focus target)")

	var ember_ladder: Array = hx._resident_ladder_entries(farm_kind, 2)
	ok(ember_ladder.size() >= 4 \
		and bool(ember_ladder[0].seen) and bool(ember_ladder[1].seen) \
		and not bool(ember_ladder[2].seen) and not bool(ember_ladder[3].seen), \
		"resident tier ladder hides future tiers until this line has reached them")

	var drag_src := _hand_orb_of(hx, farm_kind, 1)
	var drag_px := drag_src.get_global_rect().size.x if drag_src != null else -1.0
	hx._drag = hx._orb_at(_hit_center(drag_src))
	hx._begin_drag_ghost(_hit_center(drag_src))
	var drag_ghost := hx.get("_drag_ghost") as Control
	var ghost_px := float(drag_ghost.get_meta("ghost_px", 0.0)) if drag_ghost != null else -1.0
	ok(drag_ghost != null \
		and drag_ghost.find_child("MapResidentTierBadge", true, false) == null \
		and absf(ghost_px - drag_px) <= 1.0 \
		and absf(drag_ghost.get_global_rect().size.x - drag_px) <= 1.0, \
		"resident drag preview hides the tier badge and keeps the source slot size")
	hx._end_drag()

	# DRAG the non-matching tier from the hand onto a HOUSED orb (a non-match) → it still PLACES (the strip
	# is the map's drop zone; only a MATCH merges, a non-match falls through to a free slot)
	var before_p := Habitat.placed(mid).size()
	_drag_select(hx, _hit_center(_hand_orb_of(hx, farm_kind, 1)), _hit_center(_placed_orb_of(hx, z, farm_kind, 2)))
	ok(Habitat.placed(mid).size() == before_p + 1, "dragging a non-matching hand spirit onto a housed orb PLACES it (the strip is the drop zone)")
	await create_timer(0.06).timeout

	# DRAG the matching t2 from the hand onto the housed t2 → MERGE (placed climbs to t3)
	var hand_before := Habitat.hand().size()
	_drag_select(hx, _hit_center(_hand_orb_of(hx, farm_kind, 2)), _hit_center(_placed_orb_of(hx, z, farm_kind, 2)))
	var has_t3 := false
	for inst in Habitat.placed(mid):
		if String(inst.kind) == farm_kind and int(inst.tier) == 3:
			has_t3 = true
	ok(has_t3, "dragging a hand spirit onto a MATCHING housed orb merges it one tier up")
	ok(Habitat.hand().size() == hand_before - 1, "the dragged spirit is consumed by the on-map merge")
	await create_timer(0.06).timeout

	# FOCUS a housed orb (a still-tap) → a Sell button appears in the hand column; pressing it sells
	_map_tap_at(hx, _hit_center(hx._placed_orbs[0].node))
	await create_timer(0.06).timeout
	ok(not hx._sel_orb.is_empty(), "a still-tap on a housed orb focuses it")
	var sells := _buttons_with(hx._hand_panel, "Sell")
	ok(sells.size() == 1, "the focused orb surfaces a Sell button in the hand column")
	var before_sell := Habitat.placed(mid).size()
	sells[0].pressed.emit()
	ok(Habitat.placed(mid).size() == before_sell - 1, "pressing Sell sells the focused spirit")
	ok(hx._sel_orb.is_empty(), "selling drops the focus")
	await create_timer(0.06).timeout

	# an IN-HAND spirit ALSO surfaces Sell on a still-tap, and pressing it drops it from the hand
	Habitat.hand_add(farm_kind, 2)
	hx._refresh_picker()
	await create_timer(0.06).timeout
	_map_tap_at(hx, _hit_center(_hand_orb_of(hx, farm_kind, 2)))
	await create_timer(0.06).timeout
	ok(String(hx._sel_orb.get("src", "")) == "hand", "a still-tap on an in-hand spirit selects it")
	var hsells := _buttons_with(hx._hand_panel, "Sell")
	ok(hsells.size() == 1, "an in-hand selection also surfaces a Sell button")
	var hand_n := Habitat.hand().size()
	hsells[0].pressed.emit()
	ok(Habitat.hand().size() == hand_n - 1, "pressing Sell on an in-hand spirit drops it from the hand")
	await create_timer(0.06).timeout

	# DRAG a housed orb back onto the in-hand column → BRING OUT
	var hb := Habitat.hand().size()
	var pb := Habitat.placed(mid).size()
	_drag_select(hx, _hit_center(hx._placed_orbs[0].node), hx._hand_panel.get_global_rect().get_center())
	ok(Habitat.placed(mid).size() == pb - 1, "dragging a housed orb onto the hand column frees the map slot")
	ok(Habitat.hand().size() == hb + 1, "the brought-out spirit returns to the hand")

	# leaving the picker restores the Lv chip
	hx._open_map(z)
	ok(hx._lv_panel.visible, "returning to a map restores the Lv chip")
	hx.queue_free()

# --- place-picker drag test helpers -------------------------------------------------
# A drag through the REAL select input surface: press on `from`, one lift-off motion to `to`, release on `to`.
func _drag_select(hx, from: Vector2, to: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT ; down.pressed = true ; down.position = from
	hx._on_input(down)
	var mv := InputEventMouseMotion.new()
	mv.position = to ; mv.relative = to - from ; mv.button_mask = MOUSE_BUTTON_MASK_LEFT
	hx._on_input(mv)
	var up := down.duplicate()
	up.pressed = false ; up.position = to
	hx._on_input(up)

func _hand_orb_of(hx, kind: String, tier: int) -> Control:
	for o in hx._hand_orbs:
		if String(o.kind) == kind and int(o.tier) == tier:
			return o.node
	return null

func _hand_orb_at_index(hx, index: int) -> Control:
	for o in hx._hand_orbs:
		if int(o.idx) == index:
			return o.node
	return null

func _placed_orb_of(hx, z: int, kind: String, tier: int) -> Control:
	for o in hx._placed_orbs:
		if int(o.z) == z and String(o.kind) == kind and int(o.tier) == tier:
			return o.node
	return null

func _placed_for(hx, z: int) -> int:
	var n := 0
	for o in hx._placed_orbs:
		if int(o.z) == z:
			n += 1
	return n

func _card_for_map(hx, z: int) -> Control:
	for hit in hx.select_hits:
		if int(hit.z) == z:
			return hit.node
	return null

func _card_drop_point(card: Control) -> Vector2:
	var r := card.get_global_rect()
	return r.position + Vector2(r.size.x * 0.80, r.size.y * 0.50)

func _buttons_with(node: Node, frag: String) -> Array:
	var out: Array = []
	for b in node.find_children("*", "Button", true, false):
		if String((b as Button).text).contains(frag):
			out.append(b)
	return out
