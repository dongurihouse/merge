extends "res://games/grove/tests/grove_test_base.gd"
## grove · explore — guards engine/scripts/core/explore.gd (the acquire model: loadout costs/cfg,
## Rush scoring, grid helpers, the box/unlocked-pool seam, and cross-scene run state). Pure-model
## coverage; the real-time Rush *feel* needs an interactive run. Active suite (in GROVE_TESTS).

const Explore = preload("res://engine/scripts/core/explore.gd")
const Habitat = preload("res://engine/scripts/core/habitat.gd")

func _initialize() -> void:
	begin("grove · explore acquire")
	_test_loadout()
	_test_scoring()
	_test_grid()
	_test_pool_and_box()
	_test_run_state()
	_test_screens()
	finish()

# a rows×cols grid of empty cells (the Rush tile grid: null or {kind,tier})
func _grid(rows: int, cols: int) -> Array:
	var g := []
	for _r in rows:
		var row := []
		for _c in cols:
			row.append(null)
		g.append(row)
	return g

# --- loadout: coin cost + the Rush cfg the boosts resolve to ----------------------
func _test_loadout() -> void:
	fresh("explore_loadout")
	ok(Explore.loadout_cost({}) == 0, "an empty loadout costs nothing")
	ok(Explore.loadout_cost({"time": true, "drops": true}) == 120 + 100, "loadout cost sums the equipped boosts")

	# §1 an expedition has a DEFAULT MINIMUM cost (MIN_COST) — the acquisition coin sink — and boosts add on top.
	ok(Explore.start_cost({}) == Explore.MIN_COST, "an empty expedition still costs the default MIN_COST")
	ok(Explore.start_cost({"drops": true}) == Explore.MIN_COST + 100, "boosts add ON TOP of the base minimum")
	Save.spend(Save.coins())               # zero the wallet, then set a known balance
	Save.add_coins(300)
	ok(Explore.can_start({}), "can set off with the base minimum covered (300 ≥ 150)")
	ok(Explore.can_start({"drops": true}), "can set off when coins (300) cover base+boost (250)")
	ok(not Explore.can_start({"focus": true}), "cannot set off when base+boost (350) exceeds coins (300)")

	var base: Dictionary = Explore.rush_cfg({})
	ok(base.time == Explore.BASE_TIME, "no-boost run length is BASE_TIME")
	ok(base.spawn_mul == 1.0 and base.calm_mul == 1.0 and base.t2 == 0.0, "no-boost cfg is the neutral baseline")
	ok((base.lines as Array).size() == Explore.RUSH_LINES.size(), "all lines are in play without the focus boost")
	var full: Dictionary = Explore.rush_cfg({"time": true, "drops": true, "calm": true, "lucky": true, "focus": true})
	ok(full.time == Explore.BASE_TIME + 15.0, "the time boost adds 15s")
	ok(full.spawn_mul < 1.0, "the drops boost shortens the spawn interval")
	ok(full.calm_mul > 1.0, "the calm boost rarefies treefalls")
	ok(full.t2 > 0.0, "the lucky boost enables tier-2 drops")
	ok((full.lines as Array).size() == 2, "the focus boost restricts play to 2 lines")

# --- Rush scoring: non-linear value, combo, multiplier, spawn cadence -------------
func _test_scoring() -> void:
	ok(Explore.merge_base(1) == 10, "a t1 merge is worth 10 base")
	ok(Explore.merge_base(2) == 20 and Explore.merge_base(3) == 40, "base value doubles per tier (non-linear)")
	ok(Explore.merge_points(3, 2.0) == Explore.merge_base(3) * 2, "points scale by the live multiplier")

	ok(Explore.combo_after(2, 0.5) == 3, "a merge within the window climbs the combo")
	ok(Explore.combo_after(5, 2.0) == 1, "a merge after the window restarts the combo at 1")

	ok(absf(Explore.mult_after_merge(1.0, 1) - 1.12) < 0.001, "each merge nudges the multiplier up")
	ok(Explore.mult_after_merge(1.0, 4) > Explore.mult_after_merge(1.0, 1), "building a high tier bumps it more")
	ok(Explore.mult_after_merge(Explore.MULT_CAP, 4) == Explore.MULT_CAP, "the multiplier is capped at MULT_CAP")
	ok(Explore.mult_decay(2.0, 0.1, 0.0) == 2.0, "the multiplier holds steady inside the post-merge grace window")
	ok(Explore.mult_decay(2.0, 0.1, Explore.MULT_GRACE + 0.5) < 2.0, "the multiplier bleeds once the grace window passes")
	ok(absf(Explore.mult_decay(2.0, 1.0, 5.0) - (2.0 - Explore.MULT_DECAY)) < 0.001, "past the grace window it bleeds at MULT_DECAY per second")
	ok(Explore.mult_decay(1.0, 5.0, 9.0) == 1.0, "the multiplier never decays below 1")
	ok(Explore.clean_dodge_mult(1.0) > 1.0, "a clean dodge bumps the multiplier")

	ok(Explore.spawn_interval(0.0, 1.0) > Explore.spawn_interval(1.0, 1.0), "drops accelerate as the run progresses")
	ok(Explore.spawn_interval(0.0, 0.72) < Explore.spawn_interval(0.0, 1.0), "the drops boost shortens the interval")

# --- grid helpers: match, gravity, fill, fling, timber, full ---------------------
func _test_grid() -> void:
	var g := _grid(3, 3)
	g[2][0] = {"kind": "leaf", "tier": 1}
	g[2][1] = {"kind": "leaf", "tier": 1}
	ok(Explore.neighbor_match(g, 2, 0) == Vector2i(2, 1), "neighbor_match finds an adjacent same kind+tier")
	g[2][1] = {"kind": "petal", "tier": 1}
	ok(Explore.neighbor_match(g, 2, 0) == Vector2i(-1, -1), "no match when the neighbour's kind differs")
	g[2][1] = {"kind": "leaf", "tier": 2}
	ok(Explore.neighbor_match(g, 2, 0) == Vector2i(-1, -1), "no match when the neighbour's tier differs")
	# the Rush uses INTEGER line indices as kinds (RUSH_LINES = [1,2,3]); neighbor_match must handle them
	# (str(), not String() — String(int) has no constructor and crashed every tap-merge in the Rush)
	var gi := _grid(3, 3)
	gi[2][0] = {"kind": 1, "tier": 1}
	gi[2][1] = {"kind": 1, "tier": 1}
	ok(Explore.neighbor_match(gi, 2, 0) == Vector2i(2, 1), "neighbor_match matches integer (line-index) kinds")
	gi[2][1] = {"kind": 2, "tier": 1}
	ok(Explore.neighbor_match(gi, 2, 0) == Vector2i(-1, -1), "no match when integer kinds differ")

	var g2 := _grid(3, 3)
	g2[0][1] = {"kind": "leaf", "tier": 1}
	Explore.gravity(g2)
	ok(g2[2][1] != null and g2[0][1] == null, "gravity drops a floating tile to the bottom")
	ok(Explore.column_fill(g2, 1) == 1, "column_fill counts a column's tiles")

	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var g3 := _grid(2, 3)
	g3[1][0] = {"kind": "leaf", "tier": 1}
	ok(Explore.fling_target(g3, 0, 1, rng) == 2, "fling_target avoids the source and the danger column")

	var g4 := _grid(3, 2)
	g4[2][0] = {"kind": "leaf", "tier": 1}
	g4[1][0] = {"kind": "leaf", "tier": 2}
	ok(Explore.timber_hits(g4, 0) == 2 and Explore.timber_hits(g4, 1) == 0, "timber_hits counts a column (0 = a clean dodge)")

	var g5 := _grid(1, 2)
	ok(not Explore.board_full(g5), "a board with an empty cell is not full")
	g5[0][0] = {"kind": "leaf", "tier": 1}
	g5[0][1] = {"kind": "leaf", "tier": 1}
	ok(Explore.board_full(g5), "board_full is true when every cell is occupied")

# --- the box seam: unlocked pool + roll ------------------------------------------
func _test_pool_and_box() -> void:
	fresh("explore_pool")
	ok(Explore.unlocked_pool({}, []).is_empty(), "the box pool is empty with no completed map")

	var z := 0
	var unl := {}
	for sp in G.MAPS[z].spots:
		unl[String(sp.id)] = true
	ok(G.can_populate(z, unl, [z]), "map 0 complete (the pool precondition)")
	var pool: Array = Explore.unlocked_pool(unl, [z])
	ok(not pool.is_empty(), "a completed map fills the box pool")
	var want := {}
	for ln in G.resident_lines(z):
		want[String(ln.id)] = true
	var all_in := true
	for k in pool:
		if not want.has(k):
			all_in = false
	ok(all_in and pool.size() == want.size(), "the pool is exactly the completed map's offered kinds")

	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	ok(pool.has(Explore.roll_kind(pool, rng)), "roll_kind returns a kind from the pool")
	ok(Explore.roll_kind([], rng) == "", "rolling an empty pool yields the empty string")

# --- run state: carried across the three scenes, score spent on boxes ------------
func _test_run_state() -> void:
	Explore.begin_run({"drops": true})
	ok(Explore.score() == 0, "a fresh run starts at score 0")
	ok(bool(Explore.run().equip.get("drops", false)), "the run carries the chosen loadout")
	Explore.add_score(250)
	ok(Explore.score() == 250, "add_score accrues the run score")
	ok(not Explore.buy_box(300), "a box the run can't afford is refused")
	ok(Explore.score() == 250, "a refused box leaves the score intact")
	ok(Explore.buy_box(250), "an affordable box is bought")
	ok(Explore.score() == 0, "buying a box debits its cost from the score")

# --- the Rush/Trade screens: build smoke + the Trade→hand seam -------------------
func _test_screens() -> void:
	fresh("explore_screens")
	# (Load out is now an overlay dialog on the map — map.gd::_open_expedition — not a scene.)
	for path in ["res://engine/scenes/ExploreRush.tscn", "res://engine/scenes/ExploreTrade.tscn"]:
		var s = load(path).instantiate()
		get_root().add_child(s)
		if s.get_child_count() == 0:        # headless -s defers _ready a frame; build it now
			s._ready()
		ok(s.get_child_count() > 0, "%s builds a non-empty tree" % String(path).get_file())
		s.queue_free()

	# the seam: buying a box on the Trade screen lands a pool kind in the habitat hand
	fresh("explore_trade_seam")
	var z := 0
	var g := Save.grove()
	var unl := {}
	for sp in G.MAPS[z].spots:
		unl[String(sp.id)] = true
	g["unlocks"] = unl
	g["gates"] = [z]
	Save.grove_write()
	Explore.begin_run({})
	Explore.add_score(400)
	var pool: Array = Explore.unlocked_pool(unl, [z])
	var hand_before := Habitat.hand().size()
	var t = load("res://engine/scenes/ExploreTrade.tscn").instantiate()
	get_root().add_child(t)
	if t.get_child_count() == 0:
		t._ready()
	t._on_buy(int(Explore.BOXES[0].cost))
	ok(Habitat.hand().size() == hand_before + 1, "opening a box on the Trade screen adds a spirit to the hand")
	ok(pool.has(String(Habitat.hand()[Habitat.hand().size() - 1].kind)), "the box-spirit's kind comes from the unlocked pool")
	ok(int(Habitat.hand()[Habitat.hand().size() - 1].tier) == 1, "the box-spirit enters the hand at tier 1")
	var piglet_reveal: Control = t._spirit_widget("piglet", 72.0)
	ok(piglet_reveal.find_child("SpiritEye0", true, false) != null and piglet_reveal.find_child("SpiritEye1", true, false) != null,
		"an unarted box-spirit reveal shows placeholder face details instead of a blank disc")
	t.queue_free()
