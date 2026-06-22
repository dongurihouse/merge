extends SceneTree
## Headless tests for the generator MECHANIC (§6): per-map roster derivation,
## the generator-grant hand-in op, line retirement, movable generators.
##   godot --headless --path . -s res://engine/tests/mechanics_tests.gd

const G = preload("res://engine/scripts/core/content.gd")
const BoardModel = preload("res://engine/scripts/core/board_model.gd")
const BoardLogic = preload("res://engine/scripts/core/board_logic.gd")

var _pass := 0
var _fail := 0

func ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

## A fixture roster (independent of the live grove data): map 0 has 2 generators, map 1 has 3.
## Generators PERSIST (no hand-in), so each carries its own `cell`. (`grant_from` is inert legacy
## data on the live roster; the fixture omits it.)
func _fixture() -> Array:
	return [
		{"id": "g0a", "map": 0, "lines": [1, 2], "cell": Vector2i(4, 3)},
		{"id": "g0b", "map": 0, "lines": [3, 4], "cell": Vector2i(2, 1)},
		{"id": "g1a", "map": 1, "lines": [5, 6], "cell": Vector2i(4, 3)},
		{"id": "g1b", "map": 1, "lines": [7, 8], "cell": Vector2i(2, 1)},
		{"id": "g1c", "map": 1, "lines": [10, 11], "cell": Vector2i(6, 5)},
	]

func _initialize() -> void:
	var r := _fixture()

	# --- per-map roster derivation (replaces appears_at accumulation) ---
	ok(G.generators_for_map(r, 0).size() == 2, "map 0 has 2 generators")
	ok(G.generators_for_map(r, 1).size() == 3, "map 1 has 3 generators")
	ok(G.lines_for_map(r, 1) == [5, 6, 7, 8, 10, 11], "map 1's live lines are its 3 generators' 6 lines")
	ok(G.retired_lines(r, 1) == [1, 2, 3, 4], "map 0's 4 lines retire once map 1 is live")
	ok(G.lines_for_map(r, 0) == [1, 2, 3, 4], "map 0's live lines are its own 4")
	ok(G.retired_lines(r, 0) == [], "nothing is retired while in map 0")

	# (gens_to_grant + the carrier-quest delivery are RETIRED — generators now arrive when a generator tap
	#  produces a DUE tool; see G.due_generators, covered in quest_tests.gd against the real maps.)

	# --- the §6 invariant: every generator emits exactly 2 lines ---
	var two_each := true
	for g in r:
		if int((g.lines as Array).size()) != 2:
			two_each = false
	ok(two_each, "every generator emits exactly 2 lines")

	# --- live lines off a board state (the union of the generators present) ---
	var center := Vector2i(4, 3)
	var other := Vector2i(2, 1)
	var st := {center: "g0a", other: "g0b"}            # map-0 live set: g0a + g0b
	ok(G.gen_live_lines(st, r) == [1, 2, 3, 4], "map-0 state: all 4 starter lines live")

	# --- cell resolution + the live set per map (each generator at its own authored cell) ---
	ok(G.gen_cell_of(r, "g0a") == Vector2i(4, 3), "a generator sits at its own cell")
	ok(G.gen_cell_of(r, "g1a") == Vector2i(4, 3), "g1a sits at its own authored cell")
	ok(G.gen_cell_of(r, "g1c") == Vector2i(6, 5), "g1c sits at its own cell")
	var s0 := G.live_gen_state(r, 0)
	ok(s0.size() == 2 and s0[Vector2i(4, 3)] == "g0a" and s0[Vector2i(2, 1)] == "g0b", "map 0 live set: the 2 starters at their cells")
	var s1 := G.live_gen_state(r, 1)
	ok(s1.size() == 3 and s1[Vector2i(4, 3)] == "g1a" and s1[Vector2i(2, 1)] == "g1b" and s1[Vector2i(6, 5)] == "g1c", "map 1 live set: 3 generators at their own cells")

	# --- the board model's STATEFUL, persisted generator map (movable #1 · store/place #2 · save #3) ---
	# Uses the LIVE grove roster (G.GENERATORS): map 0 ships ONE generator, the anchor seed_satchel.
	var bm := BoardModel.new()
	bm.seed_gens(0)
	ok(bm.is_gen(Vector2i(4, 3)) and bm.gens.size() == 1, "seed_gens(0): the map-0 anchor satchel is live")
	ok(bm.gen_id_at(Vector2i(4, 3)) == "seed_satchel", "the center cell holds the satchel")
	ok(bm.gen_id_at(Vector2i(0, 0)) == "", "a non-generator cell has no generator id")
	# #1 movable: a generator relocates to an empty open cell, refuses an occupied/gen cell
	var dest := Vector2i(4, 4)
	bm.items[BoardModel.idx(dest)] = 0            # clear the starter item there
	ok(bm.move_gen(Vector2i(4, 3), dest), "a generator moves to an empty open cell")
	ok(bm.is_gen(dest) and not bm.is_gen(Vector2i(4, 3)), "moved: generator at the destination, gone from the origin")
	ok(not bm.move_gen(dest, Vector2i(2, 1)), "a generator can't move onto another generator")
	bm.move_gen(dest, Vector2i(4, 3))             # put it back
	# #2 store/place: a generator persists into the gen_bag and back onto the board (no hand-in consumption)
	ok(bm.store_gen(Vector2i(4, 3)) and bm.gen_bag.has("seed_satchel") and not bm.gens.has(Vector2i(4, 3)), "store_gen moves the satchel board→gen_bag (frees the cell)")
	var open_cell: Vector2i = bm.empty_ground_cells()[0]
	ok(bm.place_gen_from_bag("seed_satchel", open_cell) and bm.gens.values().has("seed_satchel") and not bm.gen_bag.has("seed_satchel"), "place_gen_from_bag moves it gen_bag→board (persists, never consumed)")
	# #3 persistence: gens + gen_bag survive a save round-trip. Realistic state: the map-0 satchel
	# sits on the board (at open_cell) while a granted next-map generator (hen_coop) waits in the bag.
	bm.gen_bag.append("hen_coop")                  # a granted-but-unplaced generator, stashed in the bag
	var blob := bm.to_dict()
	var bm2 := BoardModel.new()
	bm2.from_dict(blob)
	ok(bm2.gen_id_at(open_cell) == "seed_satchel" and str(bm2.gen_bag) == str(bm.gen_bag) and bm2.gen_bag.has("hen_coop"), "the generator map + gen_bag round-trip through to_dict/from_dict")

	# --- burst-pop (§6): a tap pops a BURST — a FREE portion (base BURST_ODDS + per-map scale-up,
	# capped on its own at BURST_FREE_MAX) PLUS the paid burst-upgrade added on top (decoupled, T25),
	# clamped to BURST_MAX. Each item still costs 1 energy. ---
	var brng := RandomNumberGenerator.new()
	brng.seed = 7
	var bmin := 99
	var bmax := 0
	for _i in 400:
		var b := G.burst_count(0, 0, brng)        # map 1, no upgrade → base only
		bmin = mini(bmin, b)
		bmax = maxi(bmax, b)
	ok(bmin == 1 and bmax == 3, "map-1 base burst rolls 1–3 items")
	var later := 0
	for _i in 200:
		later = maxi(later, G.burst_count(4, 0, brng))
	ok(later > 3, "a later map's generator pops a bigger burst (free per-map scale-up)")
	var upgraded := 0
	for _i in 200:
		upgraded = maxi(upgraded, G.burst_count(0, 2, brng))
	ok(upgraded > 3, "a burst-upgrade raises the burst")
	var capped := true
	var floored := true
	for _i in 200:
		var bc := G.burst_count(4, 9, brng)
		if bc > int(G.BURST_MAX):
			capped = false
		if G.burst_count(0, 0, brng) < 1:
			floored = false
	ok(capped, "burst never exceeds BURST_MAX")
	ok(floored, "burst is always at least 1")
	# the burst-upgrade coin-sink cost ladder (escalating, then maxed)
	ok(G.burst_upgrade_cost(0) > 0 and G.burst_upgrade_cost(1) > G.burst_upgrade_cost(0), "the burst-upgrade coin cost escalates")
	ok(G.burst_upgrade_cost(G.burst_upgrade_max()) == -1, "burst-upgrade caps — cost -1 past the max level")
	# T25 DECOUPLE: at a deep map the FREE portion is capped (BURST_FREE_MAX), and each PAID level adds
	# +1 ON TOP — regression guard for the old combined cap that clipped upper paid levels (burst_count(4,3)
	# was stuck at 6). The MAX burst at the deepest level should walk BURST_FREE_MAX → BURST_MAX, one per level.
	var deep_max := {}
	for L in range(0, int(G.BURST_UPGRADE_COSTS.size()) + 1):
		var m := 0
		for _i in 400:
			m = maxi(m, G.burst_count(4, L, brng))
		deep_max[L] = m
	ok(deep_max[0] == int(G.BURST_FREE_MAX), "deep-map FREE burst caps at BURST_FREE_MAX")
	var decoupled := true
	for L in range(1, int(G.BURST_UPGRADE_COSTS.size()) + 1):
		if deep_max[L] != mini(int(G.BURST_FREE_MAX) + L, int(G.BURST_MAX)):
			decoupled = false
	ok(decoupled, "each paid burst level adds +1 on top of the free cap (decoupled — no wasted levels)")
	ok(deep_max[int(G.BURST_UPGRADE_COSTS.size())] == int(G.BURST_MAX), "the top paid level reaches BURST_MAX (free cap + all paid)")

	# --- §6 spawn TIER-bias: a pop's line AND tier lean toward what givers want (ASK_WEIGHT), but
	# --- only among POPPABLE tiers (≤ TIER_ODDS range) so a generator never pops a high tier
	# --- directly — you still must merge up, and the §9 sell economy / 128-energy-per-t8 holds. ---
	var pop_max: int = G.TIER_ODDS.size()
	var qs := [{"asks": [{"line": 1, "tier": 3, "count": 1}, {"line": 1, "tier": pop_max + 3, "count": 1}, {"line": 9, "tier": 2, "count": 1}]}]
	var wts := BoardLogic.wanted_tiers([1, 2], qs)
	ok(wts.get(1, []).has(3), "wanted_tiers keeps a poppable asked tier (line 1 @ t3)")
	ok(not wts.get(1, []).has(pop_max + 3), "wanted_tiers EXCLUDES an above-poppable asked tier (never pop a high tier)")
	ok(not wts.has(9), "wanted_tiers ignores asks for lines the generator can't emit")
	# empty wanted_tiers is a NO-OP — byte-identical to omitting it (the load-bearing rng order is preserved).
	var ra := RandomNumberGenerator.new(); ra.seed = 31
	var rb := RandomNumberGenerator.new(); rb.seed = 31
	ok(BoardLogic.roll_spawn([Vector2i(4, 4)], Vector2i(4, 3), [1, 2], [1], ra) \
		== BoardLogic.roll_spawn([Vector2i(4, 4)], Vector2i(4, 3), [1, 2], [1], rb, {}), \
		"roll_spawn with empty wanted_tiers is identical to omitting it (no extra rng draws)")
	# the dial ships OFF: with no tier_weight (default 0) even a named wanted tier is a no-op (byte-identical).
	ok(G.ASK_TIER_WEIGHT == 0.0, "the spawn tier-bias ships OFF by default (ASK_TIER_WEIGHT dial = 0)")
	var rf := RandomNumberGenerator.new(); rf.seed = 17
	var rg := RandomNumberGenerator.new(); rg.seed = 17
	ok(BoardLogic.roll_spawn([Vector2i(4, 4)], Vector2i(4, 3), [1], [1], rf, {1: [3]}) \
		== BoardLogic.roll_spawn([Vector2i(4, 4)], Vector2i(4, 3), [1], [1], rg, {}), \
		"default weight (0) makes a wanted tier a no-op — no rng draw, off until the owner ramps the dial")
	# at a non-zero weight, with line 1 forced (pool=[1]) and t3 wanted, t3 pops far above its baseline.
	var biased := 0
	var unbiased := 0
	var rc := RandomNumberGenerator.new(); rc.seed = 5
	var rd := RandomNumberGenerator.new(); rd.seed = 5
	for _i in 2000:
		if BoardModel.tier_of(int(BoardLogic.roll_spawn([Vector2i(4, 4)], Vector2i(4, 3), [1], [1], rc, {1: [3]}, 0.6).code)) == 3:
			biased += 1
		if BoardModel.tier_of(int(BoardLogic.roll_spawn([Vector2i(4, 4)], Vector2i(4, 3), [1], [1], rd, {}, 0.6).code)) == 3:
			unbiased += 1
	ok(biased > unbiased * 2, "at weight 0.6 the spawn tier leans toward the asked tier (%d vs %d t3 of 2000)" % [biased, unbiased])
	# even a high-tier ask never makes a generator pop above its poppable range (economy guard).
	var safe := true
	var re := RandomNumberGenerator.new(); re.seed = 8
	for _i in 1000:
		if BoardModel.tier_of(int(BoardLogic.roll_spawn([Vector2i(4, 4)], Vector2i(4, 3), [1], [1], re, {1: [pop_max + 4]}, 0.6).code)) > pop_max:
			safe = false
	ok(safe, "a high-tier ask never makes the generator pop above its TIER_ODDS range (economy guard)")

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
