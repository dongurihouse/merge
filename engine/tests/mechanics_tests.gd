extends "res://engine/tests/test_base.gd"
## Headless tests for the generator MECHANIC (§6): per-map roster derivation,
## the generator-grant hand-in op, line retirement, movable generators.
##   godot --headless --path . -s res://engine/tests/mechanics_tests.gd

const G = preload("res://engine/scripts/core/content.gd")
const BoardModel = preload("res://engine/scripts/core/board_model.gd")
const BoardLogic = preload("res://engine/scripts/core/board_logic.gd")
const Mastery = preload("res://engine/scripts/core/mastery.gd")
const Features = preload("res://engine/scripts/core/features.gd")
const Strings = preload("res://engine/scripts/core/strings.gd")
const Save = preload("res://engine/scripts/core/save.gd")
const Design = preload("res://engine/scripts/core/design.gd")   # the shipped canvas — read it, never re-type it

## The shipped rank-0 tier stream, CAPTURED FROM THE PRE-MASTERY IMPLEMENTATION at seed 12345
## (40 consecutive BoardLogic.roll_tier draws, one randf each against G.TIER_ODDS). It pins the
## live generator curve to bytes the players already got, so any change to TIER_ODDS, to the
## cumulative walk, or to the number of draws per roll shows up as a FAILURE here.
## NEVER REGENERATE THIS ARRAY TO MAKE A FAILING TEST PASS — regenerating it is exactly the
## edit the guard exists to catch, and it would leave the suite green over a silent re-tune.
const GOLDEN_TIER_STREAM_12345 := [
	1, 2, 1, 2, 2, 3, 1, 2, 3, 2, 1, 1, 1, 1, 1, 2, 1, 3, 2, 1,
	1, 1, 3, 1, 1, 1, 1, 2, 1, 1, 2, 3, 1, 1, 2, 3, 2, 2, 1, 2,
]

## A fixture roster (independent of the live grove data): map 0 has 2 generators, map 1 has 3.
## Generators PERSIST (no hand-in), so each carries its own `cell`. (`grant_from` is inert legacy
## data on the live roster; the fixture omits it.)
func _fixture() -> Array:
	return [
		{"id": "g0a", "map": 0, "line": 1, "cell": Vector2i(4, 3)},
		{"id": "g0b", "map": 0, "line": 2, "cell": Vector2i(2, 1)},
		{"id": "g1a", "map": 1, "line": 5, "cell": Vector2i(4, 3)},
		{"id": "g1b", "map": 1, "line": 6, "cell": Vector2i(2, 1)},
		{"id": "g1c", "map": 1, "line": 7, "cell": Vector2i(6, 5)},
	]

# This suite's own user:// save-dir tree — kept distinct so the parallel
# runner can never let two suites clobber each other's saves.
func save_prefix() -> String:
	return "tu_mechanics_"

func _adjacent_drop_fixture(board) -> Array:
	var cells := [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)]
	for cell in cells:
		board.terrain[BoardModel.idx(cell)] = 0
		board.place(cell, 0)
		board.remove_gen(cell)
	return cells

func _has_stale_test_item(list: Array) -> bool:
	for v in list:
		if int(v) == 99901 or int(v) == 100 + int(G.TOP_TIER) + 1 or int(v) == G.COIN_LINE * 100 + 99:
			return true
	return false

func _has_stale_test_quest_item(list: Array) -> bool:
	for q in list:
		if not (q is Dictionary):
			continue
		var it := G.quest_item(q)
		if not it.is_empty() and (int(it.line) == 999 or int(it.tier) == int(G.TOP_TIER) + 1):
			return true
	return false

# --- §6.B chest-open roll helpers -----------------------------------------------------------
# The reward tables are [lo, hi] RANGES rolled low-biased (CHEST_ROLL_SKEW 2 → the roll's
# expectation sits at 1/3 of the span). The FLAT_* rows below are the retired fixed payouts —
# the baseline the ranges are tuned against, kept here as the guard's reference, never re-read
# from the live tables.
const FLAT_CHEST_COINS := {1: 40, 2: 120, 3: 320, 4: 800, 5: 2000}
const FLAT_CHEST_ACORNS := {1: 0, 2: 1, 3: 3, 4: 6, 5: 12}
const CHEST_TIERS := 5

func _chest_bounds(tier: int, cur: String) -> Array:
	return G.chest_open_range(G.CHEST_LINE * 100 + tier)[cur] as Array

func _chest_lo(tier: int, cur: String) -> int:
	return int(_chest_bounds(tier, cur)[0])

func _chest_hi(tier: int, cur: String) -> int:
	return int(_chest_bounds(tier, cur)[1])

# The skew-2 expectation of a roll in [lo, hi].
func _chest_mean(tier: int, cur: String) -> float:
	var lo := float(_chest_lo(tier, cur))
	var hi := float(_chest_hi(tier, cur))
	return lo + (hi - lo) / 3.0

# Shape of the tables: ordered pairs, a defensive miss, and both bounds climbing with the tier.
func _test_chest_ranges() -> void:
	ok(float(G.CHEST_ROLL_SKEW) > 1.0, "the chest roll is skewed toward the LOW end of its range")
	ok(int((G.SPECIAL_ITEMS[G.CHEST_LINE] as Dictionary).get("top", 0)) == CHEST_TIERS,
		"the chest line still merges through %d tiers (this guard covers all of them)" % CHEST_TIERS)
	var r1 := G.chest_open_range(G.CHEST_LINE * 100 + 1)
	ok(r1.has("coins") and r1.has("acorns") and (r1.coins as Array).size() == 2 and (r1.acorns as Array).size() == 2,
		"chest_open_range returns a [lo, hi] pair per currency")
	ok(G.chest_open_range(G.CHEST_LINE * 100 + 99) == {"coins": [0, 0], "acorns": [0, 0]},
		"an unknown chest tier ranges to nothing")
	for tier in range(1, CHEST_TIERS + 1):
		for cur in ["coins", "acorns"]:
			var c := String(cur)
			ok(_chest_lo(tier, c) <= _chest_hi(tier, c),
				"chest t%d %s range is ordered (%d..%d)" % [tier, c, _chest_lo(tier, c), _chest_hi(tier, c)])
	for tier in range(1, CHEST_TIERS):
		ok(_chest_lo(tier + 1, "coins") > _chest_lo(tier, "coins"), "chest t%d→t%d: the coin FLOOR climbs" % [tier, tier + 1])
		ok(_chest_hi(tier + 1, "coins") > _chest_hi(tier, "coins"), "chest t%d→t%d: the coin CEILING climbs" % [tier, tier + 1])
		# the acorn floor is flat at 0 across the bottom tiers, so it may only hold — never fall
		ok(_chest_lo(tier + 1, "acorns") >= _chest_lo(tier, "acorns"), "chest t%d→t%d: the acorn floor never falls" % [tier, tier + 1])
		ok(_chest_hi(tier + 1, "acorns") > _chest_hi(tier, "acorns"), "chest t%d→t%d: the acorn CEILING climbs" % [tier, tier + 1])
	# vs the retired FLAT payout: each tier pays LESS on average but MORE at its ceiling — the
	# jackpot read. (t1 acorns were 0 flat and stay 0: a range cannot sit under zero.)
	var mean_sum := 0.0
	var flat_sum := 0.0
	for tier in range(1, CHEST_TIERS + 1):
		var fc := int(FLAT_CHEST_COINS[tier])
		mean_sum += _chest_mean(tier, "coins")
		flat_sum += float(fc)
		ok(_chest_mean(tier, "coins") < float(fc) and _chest_hi(tier, "coins") > fc,
			"chest t%d coins: mean %.1f < the old flat %d < ceiling %d" % [tier, _chest_mean(tier, "coins"), fc, _chest_hi(tier, "coins")])
		var fa := int(FLAT_CHEST_ACORNS[tier])
		if fa > 0:
			ok(_chest_mean(tier, "acorns") < float(fa) and _chest_hi(tier, "acorns") > fa,
				"chest t%d acorns: mean %.2f < the old flat %d < ceiling %d" % [tier, _chest_mean(tier, "acorns"), fa, _chest_hi(tier, "acorns")])
		else:
			ok(_chest_hi(tier, "acorns") == 0, "chest t%d paid no acorns flat and still pays none" % tier)
	var drop := 1.0 - mean_sum / flat_sum
	ok(drop > 0.25 and drop < 0.35, "expected chest COINS fall ~30%% against the flat payout (measured %.1f%%)" % (drop * 100.0))

# THE MERGE INVARIANT: merging two tier-N chests into one tier-N+1 must BEAT opening both —
# so N+1's ceiling AND its expectation each more than DOUBLE N's, for both currencies.
func _test_chest_merge_invariant() -> void:
	for tier in range(1, CHEST_TIERS):
		for cur in ["coins", "acorns"]:
			var c := String(cur)
			ok(_chest_hi(tier + 1, c) > 2 * _chest_hi(tier, c),
				"chest t%d→t%d %s: the ceiling more than doubles (%d → %d)" % [tier, tier + 1, c, _chest_hi(tier, c), _chest_hi(tier + 1, c)])
			ok(_chest_mean(tier + 1, c) > 2.0 * _chest_mean(tier, c),
				"chest t%d→t%d %s: the mean more than doubles (%.2f → %.2f)" % [tier, tier + 1, c, _chest_mean(tier, c), _chest_mean(tier + 1, c)])

# The seeded roll: always inside the range, reaching both ends, and averaging in the LOWER half.
func _test_chest_roll() -> void:
	var rolls := 4000
	for tier in range(1, CHEST_TIERS + 1):
		var code := G.CHEST_LINE * 100 + tier
		var rng2 := RandomNumberGenerator.new()
		rng2.seed = 20260727 + tier
		var lo_c := _chest_lo(tier, "coins")
		var hi_c := _chest_hi(tier, "coins")
		var lo_a := _chest_lo(tier, "acorns")
		var hi_a := _chest_hi(tier, "acorns")
		var inside := true
		var min_c := hi_c
		var max_c := lo_c
		var sum_c := 0.0
		var sum_a := 0.0
		for _i in rolls:
			var got := G.chest_open_reward(code, rng2)
			var c := int(got.coins)
			var a := int(got.acorns)
			if c < lo_c or c > hi_c or a < lo_a or a > hi_a:
				inside = false
			min_c = mini(min_c, c)
			max_c = maxi(max_c, c)
			sum_c += float(c)
			sum_a += float(a)
		ok(inside, "chest t%d: every roll lands inside its range (coins %d..%d, acorns %d..%d)" % [tier, lo_c, hi_c, lo_a, hi_a])
		var span := float(hi_c - lo_c)
		ok(float(min_c) <= float(lo_c) + span * 0.02, "chest t%d: the coin roll reaches its floor (min %d)" % [tier, min_c])
		ok(float(max_c) >= float(hi_c) - span * 0.05, "chest t%d: the coin roll approaches its ceiling (max %d)" % [tier, max_c])
		var mean_c := sum_c / float(rolls)
		var mean_a := sum_a / float(rolls)
		ok(mean_c < float(lo_c) + span * 0.5,
			"chest t%d: the coin roll averages in the LOWER half of its span (mean %.1f of %d..%d)" % [tier, mean_c, lo_c, hi_c])
		ok(absf(mean_c - _chest_mean(tier, "coins")) < span * 0.05,
			"chest t%d: the sampled coin mean %.1f tracks the skew-2 expectation %.1f" % [tier, mean_c, _chest_mean(tier, "coins")])
		ok(absf(mean_a - _chest_mean(tier, "acorns")) <= 0.6,
			"chest t%d: the sampled acorn mean %.2f tracks its low-biased expectation %.2f" % [tier, mean_a, _chest_mean(tier, "acorns")])

func _initialize() -> void:
	var r := _fixture()

	# --- per-map roster derivation (replaces appears_at accumulation) ---
	ok(G.generators_for_map(r, 0).size() == 2, "map 0 has 2 generators")
	ok(G.generators_for_map(r, 1).size() == 3, "map 1 has 3 generators")
	# (the rolling map/line window — lines_for_map / askable_lines / retired_lines — is RETIRED; quests now ask
	#  from the level-reached quest_base_lines window. gens_to_grant + the carrier-quest delivery are RETIRED
	#  too — generators arrive when a generator tap produces a DUE tool; see Quests.due_gen, covered in
	#  quest_tests.gd against the real maps.)

	# --- gen redesign invariant: every generator emits exactly ONE line ---
	var one_each := true
	for g in r:
		if not g.has("line"):
			one_each = false
	ok(one_each, "every generator emits exactly one line")

	# --- live lines off a board state (the union of the generators present) ---
	var center := Vector2i(4, 3)
	var other := Vector2i(2, 1)
	var st := {center: "g0a", other: "g0b"}            # map-0 live set: g0a + g0b
	ok(G.gen_live_lines(st, r) == [1, 2], "map-0 state: both starter lines live")

	# --- cell resolution + the live set per map (each generator at its own authored cell) ---
	ok(G.gen_cell_of(r, "g0a") == Vector2i(4, 3), "a generator sits at its own cell")
	ok(G.gen_cell_of(r, "g1a") == Vector2i(4, 3), "g1a sits at its own authored cell")
	ok(G.gen_cell_of(r, "g1c") == Vector2i(6, 5), "g1c sits at its own cell")
	var s0 := G.live_gen_state(r, 0)
	ok(s0.size() == 2 and s0[Vector2i(4, 3)] == "g0a" and s0[Vector2i(2, 1)] == "g0b", "map 0 live set: the 2 starters at their cells")
	var s1 := G.live_gen_state(r, 1)
	ok(s1.size() == 3 and s1[Vector2i(4, 3)] == "g1a" and s1[Vector2i(2, 1)] == "g1b" and s1[Vector2i(6, 5)] == "g1c", "map 1 live set: 3 generators at their own cells")

	# --- the board model's STATEFUL, persisted generator map (movable #1 · store/place #2 · save #3) ---
	# Uses the LIVE grove roster (G.GENERATORS): map 0 ships ONE generator, the anchor gen_1.
	var bm := BoardModel.new()
	bm.seed_gens(0)
	ok(bm.is_gen(Vector2i(4, 3)) and bm.gens.size() == 1, "seed_gens(0): the map-0 anchor satchel is live")
	ok(bm.gen_id_at(Vector2i(4, 3)) == "gen_1", "the center cell holds the satchel")
	ok(bm.gen_id_at(Vector2i(0, 0)) == "", "a non-generator cell has no generator id")
	var expected_gen_tex := {
		"gen_1": "items/generator/gen_fairy_hollow_glowshroom.png",
		"gen_2": "items/generator/gen_fairy_hollow_wild_berries.png",
		"gen_3": "items/generator/gen_snowy_village_snow_ice.png",
		"gen_4": "items/generator/gen_snowy_village_woolens.png",
		"gen_6": "items/generator/gen_oasis_desert_fruits.png",
		"gen_7": "items/generator/gen_oasis_sand_sculptures.png",
		"gen_16": "items/generator/gen_coral_reef_shells.png",
		"gen_18": "items/generator/gen_cherry_blossom_koi.png",
	}
	for gid in expected_gen_tex:
		var tex := G.gen_tex(String(gid))
		ok(tex == String(expected_gen_tex[gid]) and ResourceLoader.exists("res://games/grove/assets/" + tex), \
			"%s resolves to its imported cut-paper picture-book generator icon" % gid)
	ok(G.gen_for_line(5) == "" and G.gen_for_line(8) == "" and G.gen_for_line(17) == "" and G.gen_for_line(19) == "", \
		"crafted/special lines keep no board generator")
	var retired_source_icons := [
		"items/generator/gen_snowy_village_winter_berries.png",
		"items/generator/gen_oasis_spices.png",
		"items/generator/gen_coral_reef_corals.png",
		"items/generator/gen_cherry_blossom_tea_cups.png",
	]
	for tex in retired_source_icons:
		ok(not ResourceLoader.exists("res://games/grove/assets/" + tex), \
			"%s is not shipped as a board generator icon" % tex)
	# #1 movable: a generator relocates to an empty open cell, refuses an occupied/gen cell
	var dest := Vector2i(4, 4)
	bm.items[BoardModel.idx(dest)] = 0            # clear the starter item there
	ok(bm.move_gen(Vector2i(4, 3), dest), "a generator moves to an empty open cell")
	ok(bm.is_gen(dest) and not bm.is_gen(Vector2i(4, 3)), "moved: generator at the destination, gone from the origin")
	ok(not bm.move_gen(dest, Vector2i(2, 1)), "a generator can't move onto another generator")
	bm.move_gen(dest, Vector2i(4, 3))             # put it back
	# #2 store/place: a generator persists into the gen_bag and back onto the board (no hand-in consumption)
	ok(bm.store_gen(Vector2i(4, 3)) and bm.gen_bag.has("gen_1") and not bm.gens.has(Vector2i(4, 3)), "store_gen moves the satchel board→gen_bag (frees the cell)")
	var open_cell: Vector2i = bm.empty_ground_cells()[0]
	ok(bm.place_gen_from_bag("gen_1", open_cell) and bm.gens.values().has("gen_1") and not bm.gen_bag.has("gen_1"), "place_gen_from_bag moves it gen_bag→board (persists, never consumed)")
	# #3 persistence: gens + gen_bag survive a save round-trip. Realistic state: the map-0 satchel
	# sits on the board (at open_cell) while a granted next-page generator (gen_3) waits in the bag.
	bm.bag_add("gen_3")                          # a granted-but-unplaced generator, stashed in the bag
	var blob := bm.to_dict()
	var bm2 := BoardModel.new()
	bm2.from_dict(blob)
	ok(bm2.gen_id_at(open_cell) == "gen_1" and str(bm2.gen_bag) == str(bm.gen_bag) and bm2.gen_bag.has("gen_3"), "the generator map + gen_bag round-trip through to_dict/from_dict")

	# #3b stale-save hygiene: unknown/deprecated item codes and generator ids are dropped while
	# loading saved board state, rather than surviving into gameplay.
	var stale_blob := bm.to_dict()
	var stale_items: Array = stale_blob["items"]
	stale_items[0] = 101
	stale_items[1] = 99901
	stale_items[2] = 100 + int(G.TOP_TIER) + 1
	stale_blob["items"] = stale_items
	stale_blob["gens"] = [[4, 3, "gen_1", 3, 7], [4, 4, "old_generator", 2]]
	stale_blob["gen_bag"] = ["gen_3", "old_generator", "acc_water", G.treat_gen_id(int(G.TREAT_LINES[0])), "treat_999"]
	stale_blob["gen_bag_tiers"] = [1, 2, 3, 4, 5]
	stale_blob["gen_bag_boost"] = [4, 0, 8, 0, 0]
	var cleaned := BoardModel.new()
	cleaned.from_dict(stale_blob)
	ok(cleaned.item_at(BoardModel.cell_of(1)) == 0 and cleaned.item_at(BoardModel.cell_of(2)) == 0, \
		"from_dict drops unknown/deprecated item codes from board cells")
	ok(cleaned.gens.values().has("gen_1") and not cleaned.gens.values().has("old_generator"), \
		"from_dict drops unknown/deprecated generator ids from board cells")
	ok(cleaned.gen_boost_at(Vector2i(4, 3)) == 7, \
		"from_dict keeps the generator boost from the fifth save slot")
	ok(not cleaned.to_dict().has("gen_bag_tiers"), \
		"to_dict stops writing retired generator bag tier metadata")
	ok(cleaned.gen_bag.has("gen_3") and cleaned.gen_bag.has("acc_water") \
		and cleaned.gen_bag.has(G.treat_gen_id(int(G.TREAT_LINES[0]))) \
		and not cleaned.gen_bag.has("old_generator") and not cleaned.gen_bag.has("treat_999"), \
		"from_dict drops unknown/deprecated generator ids from gen_bag and keeps valid bonus/treat generators")
	ok(cleaned.gen_bag_boost.size() == cleaned.gen_bag.size() and int(cleaned.gen_bag_boost[cleaned.gen_bag.find("gen_3")]) == 4, \
		"from_dict keeps generator bag boosts while ignoring retired bag tiers")

	# #3d retired-line hygiene: a line kept in LINES only for its art but DROPPED from the live content
	# model (no generator AND not a craftable special) is NOT a valid item code — its saved pieces +
	# discovery prune on load. DERIVED from the model (generator roster + recipes), so it scales to any
	# future retired line with no per-line list.
	ok(G.is_valid_item_code(101) and G.is_valid_item_code(1601), "a live BASE line's items stay valid (it has a generator)")
	ok(G.is_valid_item_code(501) and G.is_valid_item_code(1901), "a live SPECIAL line's items stay valid (craftable from its recipe)")
	ok(G.is_valid_item_code(7101) and G.is_valid_item_code(7501), "a §6.D TREAT line's items stay valid (the treat generator produces them)")
	ok(not G.is_valid_item_code(6101) and not G.is_valid_item_code(2101), "a RETIRED line's items are invalid (old rosters 61/21: dropped from the model)")
	ok(not G.is_valid_item_code(3801) and not G.is_valid_item_code(5201), "every dropped line prunes (old 38, 52) — derived, not a hardcoded list")

	# #3c game load hygiene: stale item pointers in the grove save are removed from persisted board,
	# bag, quest, and seen state on load.
	fresh("stale_save_items")
	var sg := Save.grove()
	sg["board"] = stale_blob
	sg["bag"] = [101, 99901, G.COIN_LINE * 100 + 1, G.COIN_LINE * 100 + 99]
	sg["quests"] = [
		{"line": 1, "tier": 4, "reward": {"exp": 1, "coins": 1}},
		{"line": 999, "tier": 1, "reward": {"exp": 1, "coins": 1}},
		{"line": 1, "tier": int(G.TOP_TIER) + 1, "reward": {"exp": 1, "coins": 1}},
	]
	sg["quests_map"] = 0
	sg["seen"] = {"101": true, "7101": true, "6101": true, "99901": true, str(100 + int(G.TOP_TIER) + 1): true, "not-an-item": true}
	Save.grove_write()
	Save._loaded = false
	var stale_scene = load("res://engine/scenes/Board.tscn").instantiate()
	stale_scene._load_state()
	var after := Save.grove()
	ok(not _has_stale_test_item(Array(after["board"].get("items", []))) and not _has_stale_test_item(Array(after.get("bag", []))), \
		"loading the board removes unknown/deprecated item codes from persisted board and bag state")
	ok(not _has_stale_test_quest_item(Array(after.get("quests", []))), \
		"loading the board removes quests that ask for unknown/deprecated items")
	var seen: Dictionary = after.get("seen", {})
	ok(not seen.has("99901") and not seen.has(str(100 + int(G.TOP_TIER) + 1)) and not seen.has("not-an-item"), \
		"loading the board removes unknown/deprecated item codes from the seen ledger")
	ok(not seen.has("6101") and seen.has("101") and seen.has("7101"), \
		"loading prunes a RETIRED line's discovery (ember 6101) end-to-end, keeping live base (101) + special (7101)")
	stale_scene.free()

	# Retired generator-tier save compatibility: the saved slot remains [row, col, id, tier, boost],
	# but the tier is ignored so the fifth-slot boost stays aligned for live saves.
	var bm3 := BoardModel.new()
	bm3.seed_gens(0)                                    # gen_1 at the anchor cell (4,3)
	var c1: Vector2i = bm3.empty_ground_cells()[0]
	bm3.place_gen("gen_1", c1)
	bm3.arm_gen_boost(c1, 6)
	var gen_blob := bm3.to_dict()
	ok((gen_blob["gens"][0] as Array).size() == 5, "generator saves keep the five-slot compatibility layout")
	var bm4 := BoardModel.new()
	bm4.from_dict({"terrain": gen_blob["terrain"], "items": gen_blob["items"], "gens": [[c1.x, c1.y, "gen_1", 3, 6]], "gen_bag": ["gen_3"], "gen_bag_tiers": [3], "gen_bag_boost": [5]})
	ok(bm4.gen_boost_at(c1) == 6, "from_dict reads generator boost from save slot 5 after ignoring retired tier slot 4")

	# Stored generator boosts still travel THROUGH the gen_bag; retired bag tiers do not.
	ok(bm3.store_gen(c1) and bm3.gen_bag.has("gen_1"), "a boosted generator stores into the gen_bag")
	ok(bm3.gen_boost_at(c1) == 0, "store_gen clears the vacated cell's boost")
	var gb_back: Vector2i = bm3.empty_ground_cells()[0]
	ok(bm3.place_gen_from_bag("gen_1", gb_back) and bm3.gen_boost_at(gb_back) == 6, "place_gen_from_bag restores the stored boost")
	# the bagged boost must also survive a save round-trip.
	bm3.store_gen(gb_back)                               # a tier-2 gen_1 waits in the bag across the save
	var bm5 := BoardModel.new()
	bm5.from_dict(bm3.to_dict())
	var gb_back2: Vector2i = bm5.empty_ground_cells()[0]
	ok(bm5.place_gen_from_bag("gen_1", gb_back2) and bm5.gen_boost_at(gb_back2) == 6, "a bagged generator's boost survives to_dict/from_dict")

	# A generator that VANISHES in place (a spent bonus/treat gen) must clear its boost too.
	var bm6 := BoardModel.new()
	bm6.seed_gens(0)
	bm6.arm_gen_boost(Vector2i(4, 3), 3)
	ok(bm6.remove_gen(Vector2i(4, 3)) and not bm6.gens.has(Vector2i(4, 3)), "remove_gen deletes the generator")
	ok(bm6.gen_boost_at(Vector2i(4, 3)) == 0, "remove_gen clears the vacated cell's boost")
	ok(not bm6.remove_gen(Vector2i(4, 3)), "remove_gen on a cell with no generator is a no-op (false)")

	# Mastery scene chrome: a ranked generator wears the progress ring, carries its MASTERY tier as a
	# "· Tier N" badge in the title, shows the meter/next mastery row in the subtitle, and rank-up
	# cards mark mastery_seen once opened.
	fresh("scene_mastery_chrome")
	Save.mark_board_tutorial_seen()
	Save.grove()["mastery"] = {"1": 60}
	Save.grove()["mastery_seen"] = {}
	Save.grove_write()
	var smastery = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(smastery)
	await process_frame
	if smastery.board == null:
		smastery._ready()
	smastery._rebuild_all()
	var mcell := Vector2i(4, 3)
	var mgen: Control = smastery.gen_nodes.get(mcell)
	var ring: Control = mgen.get_node_or_null("MasteryRing") as Control
	ok(ring != null and mgen.get_children().find(ring) > 0,
		"a mastered generator wears a non-bottom-child mastery ring")
	ok(ring != null and is_equal_approx(float(ring.get("progress")), Mastery.rank_progress(1)),
		"the mastery ring uses progress within the current rank")
	smastery._select_generator(mcell)
	# The title reads "<name> · Tier N" at the line's MASTERY tier. Asserted as the WHOLE string (and
	# with N derived from Mastery, never a typed threshold) so a stray tier number from any other
	# scale — the retired generator tier included — fails here rather than reading plausibly.
	var mgid: String = smastery.board.gen_id_at(mcell)
	var mbadge: String = Strings.t("mastery.info.badge") % Mastery.rank(1)
	ok(String(smastery._info_label.text) == "%s · %s" % [G.generator_display_name(mgid), mbadge],
		"the generator info title reads '<name> · Tier N' at the line's mastery tier (%s)" % smastery._info_label.text)
	var mastery_row: Control = smastery._info_mastery_row
	ok(mastery_row != null and mastery_row.visible
		and is_equal_approx(float(smastery._info_mastery_progress.value), Mastery.rank_progress(1))
		and String(smastery._info_mastery_next_label.text).contains("next: reach"),
		"the generator info subtitle becomes the progress/next mastery row")
	var mrow_kids: Array = []
	for mk in mastery_row.get_children():
		mrow_kids.append(String(mk.name))
	ok(mrow_kids == ["MasteryProgress", "MasteryNext"],
		"the mastery row is just the meter and the next label — the pips are gone (%s)" % str(mrow_kids))

	# The badge is gated exactly like the row: a generator OFF the base lines (a treat gen carries no
	# meter) keeps its bare name…
	var tgid: String = G.treat_gen_id(int(G.TREAT_LINES[0]))
	var tcell := Vector2i(smastery.board.empty_ground_cells()[0])
	smastery.board.place_gen(tgid, tcell)
	smastery._rebuild_all()
	smastery._select_generator(tcell)
	ok(String(smastery._info_label.text) == G.generator_display_name(tgid),
		"a non-mastery-line generator's title carries no Tier badge (%s)" % smastery._info_label.text)
	# …and so does a mastery-line generator while the feature flag is off.
	Features.FLAGS["mastery"] = false
	smastery._select_generator(mcell)
	ok(String(smastery._info_label.text) == G.generator_display_name(mgid),
		"with the mastery flag off the generator title drops the Tier badge (%s)" % smastery._info_label.text)
	Features.FLAGS["mastery"] = true
	smastery._select_generator(mcell)

	smastery._queue_mastery_rankups({1: 1})
	smastery._schedule_mastery_rankup(0.25)
	await create_timer(0.05).timeout
	ok(smastery.get_node_or_null("MasteryRankupOverlay") == null,
		"a queued mastery rank-up waits for the action FX delay")
	await create_timer(0.25).timeout
	ok(smastery.get_node_or_null("MasteryRankupOverlay") != null and Mastery.seen_rank(1) == 2,
		"a queued mastery rank-up opens after the FX delay and marks the highest current rank as seen")
	var mov: Node = smastery.get_node_or_null("MasteryRankupOverlay")
	if mov != null:
		mov.queue_free()
	await process_frame
	smastery._queue_mastery_rankups({1: 1})
	smastery._show_next_mastery_rankup()
	await process_frame
	ok(smastery.get_node_or_null("MasteryRankupOverlay") == null,
		"the same seen mastery rank does not fire a second card")
	smastery.queue_free()
	await process_frame

	# The mastery row's "next" label must READ, not ellipsise. The row is width-pinned by the info
	# bar, so this measures the REAL laid-out label against EVERY string _mastery_next_text can
	# produce (ranks 0..8) — a widened string or a meter that reclaims the split trims it back to
	# "next: po…" and fails here. Mounted in a Design-sized SubViewport because the headless root
	# viewport is wider than the shipped canvas, which would make the assert vacuous.
	fresh("scene_mastery_row_fits")
	Save.mark_board_tutorial_seen()
	Save.grove()["mastery"] = {"1": 1150}
	Save.grove()["mastery_seen"] = {}
	Save.grove_write()
	var mvp := SubViewport.new()
	mvp.size = Vector2i(Design.size())
	get_root().add_child(mvp)
	var sfit = load("res://engine/scenes/Board.tscn").instantiate()
	mvp.add_child(sfit)
	await process_frame
	if sfit.board == null:
		sfit._ready()
	sfit._rebuild_all()
	sfit._select_generator(Vector2i(4, 3))
	for _f in 3:
		await process_frame
	var nlbl: Label = sfit._info_mastery_next_label
	var nfont: Font = nlbl.get_theme_font("font")
	var nsize: int = nlbl.get_theme_font_size("font_size")
	var widest := 0.0
	var widest_text := ""
	for nrank in range(0, G.MASTERY_THRESHOLDS.size() + 1):
		var ntext: String = sfit._mastery_next_text(nrank)
		var nw: float = nfont.get_string_size(ntext, HORIZONTAL_ALIGNMENT_LEFT, -1, nsize).x
		if nw > widest:
			widest = nw
			widest_text = ntext
	ok(widest <= nlbl.size.x,
		"the mastery next label fits its widest string untrimmed (%.0fpx '%s' in %.0fpx)" % [widest, widest_text, nlbl.size.x])
	# The other half of the split: the meter must keep a visible width beside the label AND take a real
	# share of the row rather than sitting pinned at its floor (the pips used to eat that width). Both
	# read off the REAL laid-out row, so a size_flags/ratio change that starves either half fails here.
	ok(sfit._info_mastery_progress.size.x >= 60.0
		and sfit._info_mastery_progress.size.x > sfit._info_mastery_progress.custom_minimum_size.x,
		"the mastery meter keeps a visible width and takes a share of the freed row (%.0fpx meter over a %.0fpx floor, %.0fpx label)"
			% [sfit._info_mastery_progress.size.x, sfit._info_mastery_progress.custom_minimum_size.x, nlbl.size.x])
	ok(is_equal_approx(sfit._info_mastery_row.size.y, sfit._info_mastery_row.get_combined_minimum_size().y)
		and sfit._info_mastery_row.size.y <= 40.0,
		"the mastery row stays one line tall (%.0fpx)" % sfit._info_mastery_row.size.y)
	sfit.queue_free()
	await process_frame
	mvp.queue_free()
	await process_frame

	# MERGE-PRIORITY DROP AREA: releasing just inside a competing neighbour still chooses the nearby
	# compatible merge. The real press/release path covers normal items, recipes, and generators.
	fresh("scene_merge_priority_drop_area")
	Save.mark_board_tutorial_seen()
	var sdrop = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(sdrop)
	await process_frame
	if sdrop.board == null:
		sdrop._ready()
	var drop_cells := _adjacent_drop_fixture(sdrop.board)
	ok(drop_cells.size() == 3, "merge-priority fixture finds adjacent open target and decoy cells")
	if drop_cells.size() == 3:
		var drop_source: Vector2i = drop_cells[0]
		var drop_target: Vector2i = drop_cells[1]
		var drop_decoy: Vector2i = drop_cells[2]
		var half: Vector2 = Vector2(sdrop.csz, sdrop.csz) / 2.0
		var toward_target: Vector2 = (sdrop._cell_pos(drop_target) - sdrop._cell_pos(drop_decoy)).normalized()
		var competing_release: Vector2 = sdrop._cell_pos(drop_decoy) + half + toward_target * (sdrop.csz * 0.45)
		ok(sdrop._pos_to_cell(competing_release) == drop_decoy,
			"merge-priority fixture release still resolves to the competing exact cell")

		sdrop.board.place(drop_source, 101)
		sdrop.board.place(drop_target, 101)
		sdrop.board.place(drop_decoy, 201)
		sdrop._rebuild_pieces()
		sdrop._on_press(sdrop._cell_pos(drop_source) + half)
		sdrop._on_release(competing_release)
		ok(sdrop.board.item_at(drop_target) == 102 and sdrop.board.item_at(drop_source) == 0
			and sdrop.board.item_at(drop_decoy) == 201,
			"nearby matching items merge instead of swapping with the competing exact cell")
		await create_timer(0.3).timeout

		for c in drop_cells:
			sdrop.board.items[BoardModel.idx(Vector2i(c))] = 0
			sdrop.board.collect_rewards.erase(BoardModel.idx(Vector2i(c)))
			sdrop.board.place(Vector2i(c), 0)
			sdrop.board.remove_gen(Vector2i(c))
		sdrop.animating = false
		sdrop.board.place(drop_source, 201)
		sdrop.board.place(drop_target, 301)
		sdrop.board.place(drop_decoy, 101)
		sdrop._rebuild_pieces()
		sdrop._on_press(sdrop._cell_pos(drop_source) + half)
		sdrop._on_release(competing_release)
		ok(sdrop.board.item_at(drop_target) == 501 and sdrop.board.item_at(drop_source) == 0
			and sdrop.board.item_at(drop_decoy) == 101,
			"nearby recipe ingredients craft instead of swapping with the competing exact cell")
		await create_timer(0.3).timeout

		for c in drop_cells:
			sdrop.board.items[BoardModel.idx(Vector2i(c))] = 0
			sdrop.board.collect_rewards.erase(BoardModel.idx(Vector2i(c)))
			sdrop.board.place(Vector2i(c), 0)
			sdrop.board.remove_gen(Vector2i(c))
		sdrop.animating = false
		sdrop.board.place(drop_source, G.SCISSORS_LINE * 100 + 1)
		sdrop.board.place(drop_target, 103)
		sdrop.board.place(drop_decoy, 101)
		var before_split_lower: int = sdrop.board.count_of(102)
		sdrop._rebuild_pieces()
		sdrop._on_press(sdrop._cell_pos(drop_source) + half)
		sdrop._begin_drag()
		sdrop._drag_follow(sdrop._cell_pos(drop_target) + half)
		ok(sdrop._split_preview != null and is_instance_valid(sdrop._split_preview),
			"hovering scissors over an eligible item shows the split preview")
		sdrop._on_release(sdrop._cell_pos(drop_target) + half)
		ok(sdrop.board.item_at(drop_source) == 0 and sdrop.board.item_at(drop_target) == 102
			and sdrop.board.count_of(102) == before_split_lower + 2,
			"dragging scissors onto an eligible item splits it through the real release path")

	await drop(sdrop)

	# Generator tiers are retired: even duplicate same-line generators do not surface the old redundant
	# sell affordance, and the trash handler leaves them alone.
	fresh("scene_duplicate_generator_no_sell")
	Save.mark_board_tutorial_seen()
	var ssell = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(ssell)
	await process_frame
	if ssell.board == null:
		ssell._ready()
	var anchor_cell := Vector2i(4, 3)
	var gid2: String = ssell.board.gen_id_at(anchor_cell)
	var dupe_cell: Vector2i = ssell.board.empty_ground_cells()[0]
	ssell.board.place_gen(gid2, dupe_cell)
	ssell._rebuild_all()
	ssell._select_generator(anchor_cell)
	ok(not ssell._info_trash.visible, "selecting a duplicate generator hides the retired generator sell button")
	var coins_before := Save.coins()
	ssell._on_trash_pressed()
	ok(ssell.board.gens.has(anchor_cell) and ssell.board.gens.has(dupe_cell),
		"trash does not remove generators now that redundant generator selling is retired")
	ok(Save.coins() == coins_before, "trash on a generator does not credit old generator sell coins")
	await drop(ssell, 3)

	# --- burst-pop, the ONE flat burst_count seam (§6, T58) — line generators, special generators
	# (boosted accumulator collect, treat pop), and the sim all call G.burst_count(rng, boosted).
	# WITHOUT a boost a tap almost always pops a SINGLE item (BURST_ODDS); a live BOOST swaps in
	# BURST_ODDS_BOOST so multiples become the norm — the boost RAISES THE CHANCE of multiples, it does
	# not add a flat count. Both tables top out at BURST_MAX; there is no per-map scale-up. ---
	var brng := RandomNumberGenerator.new()
	brng.seed = 7
	var N := 4000
	var un_mult := 0                                    # unboosted taps that popped >1 item
	var bo_mult := 0                                    # boosted taps that popped >1 item
	var un_sum := 0
	var bo_sum := 0
	var un_max := 0
	var bo_min := 99
	var floored := true
	for _i in N:
		var u := G.burst_count(brng)                    # no boost (the default)
		var b := G.burst_count(brng, true)              # boost live
		un_sum += u
		bo_sum += b
		un_max = maxi(un_max, u)
		bo_min = mini(bo_min, b)
		if u > 1:
			un_mult += 1
		if b > 1:
			bo_mult += 1
		if u < 1 or b < 1:
			floored = false
	ok(floored, "a burst is always at least 1 item")
	ok(un_max <= int(G.BURST_MAX) and bo_min >= 1, "every burst stays within [1, BURST_MAX]")
	var un_rate := float(un_mult) / N
	var bo_rate := float(bo_mult) / N
	ok(un_rate < 0.35, "without a boost a tap is usually a single item (multiple-rate %.2f < 0.35)" % un_rate)
	ok(bo_rate > 0.60, "with a boost multiples become the norm (multiple-rate %.2f > 0.60)" % bo_rate)
	ok(bo_rate > un_rate + 0.30, "the boost markedly RAISES the chance of multiples (%.2f vs %.2f)" % [bo_rate, un_rate])
	ok(bo_sum > un_sum, "the boost raises the average items per tap")
	# the BURST_MAX clamp is the board-flood safety net; it is inert only while the dial matches the
	# tables' length, so pin that here (a longer odds row must raise the dial deliberately).
	ok(int(G.BURST_MAX) == G.BURST_ODDS.size() and int(G.BURST_MAX) == G.BURST_ODDS_BOOST.size(),
		"BURST_MAX matches both flat tables' length (the clamp is the flood net, not a silent cap)")
	# the boost coin sink: a flat cost, the same every activation (no ladder — T57)
	ok(G.boost_cost() > 0, "the boost has a positive coin cost")

	ok(G.burst_odds() == G.BURST_ODDS and G.burst_odds(true) == G.BURST_ODDS_BOOST,
		"burst odds select the flat unboosted/boosted rows — one table pair for every generator tap")

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
	# roll_tier IS the generator tier curve factored out of roll_spawn (one randf vs cumulative
	# TIER_ODDS) so a generator pop AND a freshly-opened cell draw the tier from one definition.
	var rt := RandomNumberGenerator.new(); rt.seed = 99
	var rt_seen := {}
	var rt_range_ok := true
	for _i in 500:
		var t := BoardLogic.roll_tier(rt)
		rt_seen[t] = true
		if t < 1 or t > G.TIER_ODDS.size():
			rt_range_ok = false
	ok(rt_range_ok and rt_seen.has(1) and rt_seen.has(2), \
		"roll_tier stays within the pop curve (1..%d) and spreads across low tiers" % G.TIER_ODDS.size())
	# roll_item_tier is roll_tier CLAMPED to an item's merge ceiling — so treat/special-item generators
	# pop a SPREAD of tiers (like a normal generator) while never exceeding what that item can merge to
	# (water/exp top out at SPECIAL_TOP). One randf, same fallback as roll_tier.
	var ri := RandomNumberGenerator.new(); ri.seed = 99
	var ri_high_seen := {}
	var ri_cap_seen := {}
	var ri_high_ok := true
	var ri_cap_ok := true
	for _i in 500:
		var t_high := BoardLogic.roll_item_tier(ri, 12)   # high ceiling: behaves exactly like roll_tier (1..pop curve)
		ri_high_seen[t_high] = true
		if t_high < 1 or t_high > G.TIER_ODDS.size():
			ri_high_ok = false
		var t_cap := BoardLogic.roll_item_tier(ri, 3)     # low ceiling (water/exp): a rolled t4 folds into t3
		ri_cap_seen[t_cap] = true
		if t_cap < 1 or t_cap > 3:
			ri_cap_ok = false
	ok(ri_high_ok and ri_high_seen.has(1) and ri_high_seen.has(2), \
		"roll_item_tier spreads across the pop curve (1..%d) under a high merge ceiling" % G.TIER_ODDS.size())
	ok(ri_cap_ok and ri_cap_seen.size() >= 2, \
		"roll_item_tier clamps to a low merge ceiling (≤3) yet still spreads across tiers")
	ok(BoardLogic.roll_item_tier(ri, 1) == 1, "roll_item_tier with a ceiling of 1 always pops tier 1")
	# The rank-0 window must still deal the SHIPPED stream — asserted against a golden literal, not
	# against roll_tier (roll_tier now delegates to roll_tier_window, so comparing the two is a
	# tautology that passes even with the odds corrupted).
	var win_new := RandomNumberGenerator.new(); win_new.seed = 12345
	var window_stream: Array = []
	for _i in GOLDEN_TIER_STREAM_12345.size():
		window_stream.append(BoardLogic.roll_tier_window(win_new, 1, 4))
	ok(window_stream == GOLDEN_TIER_STREAM_12345, \
		"rank-0 roll_tier_window(1,4) reproduces the shipped tier stream (golden seed 12345)")
	var win_old := RandomNumberGenerator.new(); win_old.seed = 12345
	var tier_stream: Array = []
	for _i in GOLDEN_TIER_STREAM_12345.size():
		tier_stream.append(BoardLogic.roll_tier(win_old))
	ok(tier_stream == GOLDEN_TIER_STREAM_12345, \
		"roll_tier still deals the shipped tier stream (the rank-0 delegation stays honest)")
	var one_draw := true
	for rank_i in range(0, 9):
		var w := Mastery.tier_window_for_rank(rank_i)
		var a := RandomNumberGenerator.new(); a.seed = 700 + rank_i
		var b := RandomNumberGenerator.new(); b.seed = 700 + rank_i
		BoardLogic.roll_tier_window(a, w.x, w.y - w.x + 1)
		b.randf()
		one_draw = one_draw and is_equal_approx(a.randf(), b.randf())
	ok(one_draw, "every mastery tier window consumes exactly one rng draw")
	var windowed := true
	var wrng := RandomNumberGenerator.new(); wrng.seed = 606
	for _i in 400:
		var codew := int(BoardLogic.roll_spawn([Vector2i(4, 4)], Vector2i(4, 3), [1], [1], wrng, {}, 0.0, 3, 6).code)
		var tw := BoardModel.tier_of(codew)
		if tw < 3 or tw > 6:
			windowed = false
	ok(windowed, "roll_spawn can map one tier draw into an explicit mastery window")
	# §4 bramble_seed: a freshly-opened cell mimics ONE generator pop biased to a RANDOM open-quest
	# line — line ∈ open_lines, tier off the same curve. (The scene gathers open_lines from quests.)
	var bs := RandomNumberGenerator.new(); bs.seed = 20240601
	var bs_lines := {}
	var bs_tier_ok := true
	for _i in 400:
		var code := BoardLogic.bramble_seed([6, 11], bs)
		bs_lines[BoardModel.line_of(code)] = true
		var bt := BoardModel.tier_of(code)
		if bt < 1 or bt > G.TIER_ODDS.size():
			bs_tier_ok = false
	ok(bs_lines.size() == 2 and bs_lines.has(6) and bs_lines.has(11), \
		"bramble_seed picks a RANDOM line among the open quests (both [6,11] appear across draws)")
	ok(bs_tier_ok, "the cell-open seed tier always sits within the generator pop curve (1..%d)" % G.TIER_ODDS.size())
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

	# --- combo_step: cozy successive-merge streak (pure cadence) ---------------------
	ok(BoardLogic.combo_step(0, 0.0, 2.5) == 1, "combo: first merge (prev 0) starts the streak at 1")
	ok(BoardLogic.combo_step(1, 1.0, 2.5) == 2, "combo: a merge within the window bumps the streak")
	ok(BoardLogic.combo_step(3, 0.5, 2.5) == 4, "combo: streak keeps climbing while quick")
	ok(BoardLogic.combo_step(2, 2.5, 2.5) == 3, "combo: the window is inclusive at the boundary")
	ok(BoardLogic.combo_step(4, 3.0, 2.5) == 1, "combo: a gap past the window restarts at 1")
	ok(BoardLogic.combo_step(2, 2.51, 2.5) == 1, "combo: just past the window restarts at 1")

	# --- §6.B special drop items — the shared pseudo-line foundation (chest/water/acorn/seeds) ---
	var chest_t1 := 10 * 100 + 1            # chest tier 1
	var soil_seed_t1 := G.SOIL_SEED_LINE * 100 + 1
	var flower_t1 := 1 * 100 + 1           # a content line item
	var coin_t1 := G.COIN_LINE * 100 + 1   # a coin
	ok(G.is_special(chest_t1) and G.is_special(soil_seed_t1) and not G.is_special(flower_t1) and not G.is_special(coin_t1),
		"is_special gates only the special pseudo-lines (not content, not coins)")
	ok(G.special_kind(chest_t1) == "chest" and G.special_kind(11 * 100 + 1) == "",
		"the chest reads its kind; the retired key line (11) is no longer special")
	ok(G.merge_top(chest_t1) == 5 and G.merge_top(flower_t1) == G.TOP_TIER and G.merge_top(coin_t1) == G.COIN_TOP,
		"merge_top lets chests override to tier 5, content high, coins at the coin top")
	ok(G.merge_top(coin_t1) == 8, "coins merge through tier 8")
	ok(G.is_valid_item_code(G.COIN_LINE * 100 + 8) and not G.is_valid_item_code(G.COIN_LINE * 100 + 9),
		"the coin value table is the validity gate for the eight-tier ladder")
	var expected_coin_values := {1: 2, 2: 4, 3: 10, 4: 21, 5: 47, 6: 103, 7: 227, 8: 499}
	for tier in expected_coin_values:
		ok(G.coin_value(G.COIN_LINE * 100 + int(tier)) == int(expected_coin_values[tier]), \
			"coin t%d follows the tuned 2.2x ladder (%d)" % [int(tier), int(expected_coin_values[tier])])
	var sbm := BoardModel.new()
	sbm.place(Vector2i(3, 2), 10 * 100 + 2)
	sbm.place(Vector2i(3, 4), 10 * 100 + 2)
	ok(sbm.can_merge(Vector2i(3, 2), Vector2i(3, 4)), "two chest-t2 merge (below the special ceiling)")
	sbm.place(Vector2i(5, 2), 10 * 100 + 4)
	sbm.place(Vector2i(5, 4), 10 * 100 + 4)
	ok(sbm.can_merge(Vector2i(5, 2), Vector2i(5, 4)), "two chest-t4 merge into the top chest")
	sbm.place(Vector2i(6, 2), 10 * 100 + 5)
	sbm.place(Vector2i(6, 4), 10 * 100 + 5)
	ok(not sbm.can_merge(Vector2i(6, 2), Vector2i(6, 4)), "two chest-t5 do NOT merge (at the chest ceiling)")
	ok(G.item_tex_path(chest_t1).ends_with("items/chest/chest_1.png"), "a special item resolves its wired art path")
	ok(G.item_tex_path(10 * 100 + 5).ends_with("items/chest/chest_5.png"), "chest t5 resolves its wired art path")
	ok(G.merge_top(13 * 100 + 1) == G.SPECIAL_TOP, "acorn drops merge through tier 3 (the 12-tier ladder is retired)")
	ok(G.merge_top(soil_seed_t1) == 1 and not G.is_collectable(soil_seed_t1), "improvement seeds are top-1 ordinary occupants, not tap-collect resources")
	ok(G.item_tex_path(soil_seed_t1).ends_with("ui/kit/seed_soil.png"), "soil seed resolves through the kit seed-art seam")
	ok(G.item_tex_path(13 * 100 + 3).ends_with("items/acorn/acorn_6.png"), "acorn t3 resolves its PICKED art (t3 wears acorn_6)")
	ok(ResourceLoader.exists("res://games/grove/assets/items/coin/coin_12.png"), "coin t12 art is imported")
	ok(ResourceLoader.exists(G.item_tex_path(13 * 100 + 3)), "acorn t3 art is imported")
	ok(not G.LINES.has(10), "a special pseudo-line is not a content LINE (never popped/asked/sold as content)")

	# --- §6.B special-drop reward math (drop roll, tap-collect, chest open) ---
	var srng := RandomNumberGenerator.new(); srng.seed = 7
	var picked := {}
	for i in 400:
		picked[int(G.pick_special_drop(srng) / 100.0)] = true
	ok(picked.size() == 5 and G.special_kind(G.pick_special_drop(srng)) != "",
		"pick_special_drop yields t1 codes spread across the 5 special kinds (chest/water/acorn/seeds)")
	# tap-collect grants the resource by tier; a chest tap-OPENS instead (no wallet credit here)
	ok(G.special_collect(12 * 100 + 2) == {"kind": "water", "amount": 20}, "water t2 tap-collects its tier amount")
	var expected_acorn_values := {1: 1, 2: 2, 3: 5}
	for tier in expected_acorn_values:
		ok(G.special_collect(13 * 100 + int(tier)) == {"kind": "acorn", "amount": int(expected_acorn_values[tier])}, \
			"acorn t%d follows the 2.2x ladder (%d)" % [int(tier), int(expected_acorn_values[tier])])
	ok(G.special_collect(10 * 100 + 1).is_empty(), "a chest has no tap-collect credit (it OPENS via the board path)")
	ok(G.is_chest(10 * 100 + 1) and G.is_collectable(10 * 100 + 1), "a chest is collectable — the second tap opens it (no key needed)")
	# --- the chest open ROLL (§6.B): a per-tier RANGE rolled low-biased, not a fixed payout ---
	_test_chest_ranges()
	_test_chest_merge_invariant()
	_test_chest_roll()

	# --- §6.C utility accumulators (bank-to-cap, unlocked by map-1 spots) ---
	var acc_spot: String = String(G.MAPS[0].spots[0].id)   # the water accumulator's unlock spot
	ok(not G.accumulator_unlocked("water", {}) and G.accumulator_unlocked("water", {acc_spot: true}),
		"an accumulator unlocks when its map-1 spot is claimed")
	ok(G.unlocked_accumulators({acc_spot: true}) == ["water"], "unlocked_accumulators lists only the revealed kinds")
	# banking: +1 per `secs`, capped; never-started banks 0
	var secs: float = float(G.ACCUMULATORS["water"]["secs"])
	var capn: int = int(G.ACCUMULATORS["water"]["cap"])
	ok(G.accumulator_banked("water", 0.0, 9999.0) == 0, "an un-started accumulator banks nothing")
	ok(G.accumulator_banked("water", 1000.0, 1000.0 + secs * 3.0) == mini(3, capn), "banks +1 per interval since last collect (capped)")
	ok(G.accumulator_banked("water", 1000.0, 1000.0 + secs * 1000.0) == capn, "banking is capped at the small cap")
	ok(G.accumulator_full("water", 1000.0, 1000.0 + secs * 1000.0), "accumulator_full flags the at-cap state")
	# collect reward = banked × per-unit value
	ok(G.accumulator_reward("water", 3) == {"kind": "water", "amount": 3 * int(G.ACCUMULATORS["water"]["value"])},
		"the collect reward is banked × the per-unit value")

	# --- §6.C bonus generators (limited-use side-spawn; gen redesign 2026-06-28) ---
	var bonus_rng := RandomNumberGenerator.new()
	bonus_rng.seed = 7
	var bonus_clicks_n := G.pick_bonus_clicks(bonus_rng)
	ok(bonus_clicks_n >= int(G.BONUS_CLICKS[0]) and bonus_clicks_n <= int(G.BONUS_CLICKS[1]), "a bonus generator lasts a BONUS_CLICKS-sized tap budget")
	ok(G.bonus_value("water") == int(G.ACCUMULATORS["water"]["value"]), "a bonus collect grants the kind's per-tap value")
	ok(G.ACCUMULATORS.keys().has(G.pick_bonus_kind(bonus_rng)), "pick_bonus_kind returns a real accumulator kind")
	# the "exp" Crystal font is retired (its exp special line no longer exists, so its taps did nothing):
	# no new side-spawns, and a stale acc_exp on an old save fails validation → pruned by from_dict.
	ok(not G.ACCUMULATORS.has("exp") and not G.is_valid_generator_id("acc_exp"),
		"the retired Crystal font neither spawns nor survives a save load")

	# --- §6 zone progression (picture-book roster; data-driven ZONES table) ---
	ok(G.ZONE_BASE_LINES.size() == 8 and G.ZONE_SPECIAL_LINES.size() == 4 and G.ZONE_COUNT == 12, "12 zones = 8 base + 4 special (the picture-book roster)")
	ok(not G.zone_is_special(0) and not G.zone_is_special(1) and G.zone_is_special(4) and G.zone_is_special(11), "a zone is special iff its ZONES row carries a recipe (the every-3rd formula is retired)")
	ok(G.zone_line(0) == 1 and G.zone_line(1) == 2 and G.zone_line(2) == 3 and G.zone_line(5) == 6 and G.zone_line(10) == 18, "base zones introduce the base lines in order (zone 10 = the 8th base, koi 18)")
	ok(G.zone_line(4) == 5 and G.zone_line(7) == 8 and G.zone_line(11) == 19, "special zones introduce the special lines (winter berries 5 · spices 8 · tea cups 19)")
	ok(G.LINES.has(5) and G.LINES.has(8) and G.LINES.has(17) and G.LINES.has(19), "all 4 specials have LINES defs")
	ok(G.zone_recipe(4) == [2, 3] and G.zone_recipe(7) == [2, 4] and G.zone_recipe(9) == [7, 3] and G.zone_recipe(11) == [8, 2], "specials carry their AUTHORED recipes (arbitrary pairs, not the two preceding zones)")
	# the tier screen / recipe view needs a LINE-keyed recipe (zone_recipe is zone-keyed).
	ok(G.recipe_lines(5) == [2, 3] and G.recipe_lines(8) == [2, 4] and G.recipe_lines(19) == [8, 2], "recipe_lines(special) → its two ingredient lines")
	ok(G.recipe_lines(1) == [] and G.recipe_lines(2) == [] and G.recipe_lines(18) == [], "recipe_lines(base) is empty — a base line has no recipe")
	ok(G.special_for_pair(2, 3) == 5 and G.special_for_pair(3, 2) == 5, "merging lines 2+3 crafts winter berries (order-independent)")
	ok(G.special_for_pair(2, 4) == 8 and G.special_for_pair(8, 2) == 19 and G.special_for_pair(1, 3) == 0, "2+4 craft spices; spices+berries craft tea cups; a non-recipe pair crafts nothing")
	# §6.G RECIPE-line membership (is_special_line) — a code whose line is one of the 4 special lines.
	# Distinct from is_special() above (the §6.B special-DROP pseudo-lines chest/key/water/...). Used to give a
	# recipe-line merge the intensified big-moment feel at EVERY tier (T63 → board.gd _after_merge → MergeFx).
	ok(G.is_special_line(5 * 100 + 1) and G.is_special_line(19 * 100 + 6), "is_special_line gates the recipe lines (5/8/17/19) at any tier")
	ok(not G.is_special_line(1 * 100 + 1) and not G.is_special_line(18 * 100 + 4), "a base content line (1, 18) is not a recipe line")
	ok(not G.is_special_line(G.COIN_LINE * 100 + 1) and not G.is_special_line(10 * 100 + 1), "coins and §6.B special-DROP items are not recipe lines")
	# §7 quest-side generator cap (#16, re-scoped): the quest pool's distinct-generator footprint is capped
	ok(G.cap_quest_lines([1, 2, 3, 4, 6, 7, 16, 18], 6).size() == 6, "a base-line quest pool trims to QUEST_GEN_CAP distinct generators")
	ok(G.cap_quest_lines([1, 2, 3], 6) == [1, 2, 3], "a small pool is left untouched (footprint under the cap)")
	# --- "needed for a quest" RECURSES to the base lines (2026-07-25 guard) ------------------------------
	# quest_needed_lines is the ONE expansion behind every "this item matters" read — board item grey,
	# generator fade, bag breathe, and the sim's clutter/sell rule. It expanded only ONE level, so with a
	# tea-cups ask up (19 <- spices 8 <- wild berries 2 + woolens 4) the game marked WOOLENS as junk: the
	# board greyed out, and the merchant bought, the exact items needed to craft the ingredient. It must stay
	# in step with gens_for_quest_line, which recurses the same tree.
	var _need19 := G.quest_needed_lines([19])
	ok(_need19.has(19) and _need19.has(8) and _need19.has(2), "tea cups needs itself, spices and wild berries")
	ok(_need19.has(4), "tea cups ALSO needs WOOLENS — the second-level ingredient of spices (the one-level bug)")
	ok(G.quest_needed_lines([5]) .has(3) and G.quest_needed_lines([5]).has(2), "a one-level special still expands to both its ingredients")
	ok(G.quest_needed_lines([18]) == {18: true}, "a base line needs only itself")
	# the two reads must agree: every generator a quest requires belongs to a line it declares as needed
	for _al in G.ZONE_SPECIAL_LINES + G.ZONE_BASE_LINES:
		var _nl := G.quest_needed_lines([int(_al)])
		for _g in G.gens_for_quest_line(int(_al)):
			var _gl := int(String(_g).trim_prefix("gen_"))
			ok(_nl.has(_gl), "line %d declares line %d needed — the generator it requires (%s) has somewhere to come from" % [int(_al), _gl, _g])

	# --- §7 THE ACTIVE-LINE WINDOW (2026-07-25) — ACTIVE_LINE_WINDOW lines at a time, base or special alike.
	# The arc window slides over ZONES rows, so it advances on EVERY zone (a special takes a slot of its own).
	ok(G.zone_window_lines(0) == [1] and G.zone_window_lines(1) == [1, 2], "the window fills from the first zones (FTUE: 1 line, then 2)")
	ok(G.zone_window_lines(2) == [1, 2, 3] and G.zone_window_lines(3) == [2, 3, 4], "at full width the window holds 3 lines and slides one per zone")
	ok(G.zone_window_lines(4) == [3, 4, 5], "a SPECIAL zone takes a window slot of its own (winter berries 5 at z4)")
	ok(G.zone_window_lines(G.ZONE_COUNT - 1) == [17, 18, 19], "the last zone's window carries tea cups (19) — the capstone is askable at its own zone")
	ok(G.zone_window_lines(G.ZONE_COUNT + 5) == [17, 18, 19], "a zone past the roster clamps to the last window")
	for _z in G.ZONE_COUNT:
		ok(G.zone_window_lines(_z).size() == mini(_z + 1, int(G.ACTIVE_LINE_WINDOW)), "zone %d windows exactly ACTIVE_LINE_WINDOW lines (or all reached)" % _z)
	# a special no longer needs its ingredient LINES live — its ingredient GENERATORS arrive by birth-on-tap,
	# so the whole arc stays inside the QUEST_GEN_CAP footprint with no line-level dependency.
	var _peak := 0
	for _z2 in G.ZONE_COUNT:
		var _gens := {}
		for _l in G.zone_window_lines(_z2):
			for _g in G.gens_for_quest_line(int(_l)):
				_gens[_g] = true
		_peak = maxi(_peak, _gens.size())
	ok(_peak <= int(G.QUEST_GEN_CAP), "the arc's peak generator footprint (%d) stays inside QUEST_GEN_CAP" % _peak)
	ok(G.cap_quest_lines(G.zone_window_lines(G.ZONE_COUNT - 1)) == [17, 18, 19], "the footprint cap never trims a full arc window")
	# PAST THE LAST ZONE the window simply STOPS — it holds the final ACTIVE_LINE_WINDOW lines forever, with
	# no separate endgame mode. (The per-level-up random re-roll that shipped here first is removed, owner
	# call 2026-07-25: the world grows by adding zones, so the top of the ladder keeps moving and a distinct
	# endgame would be behaviour built to be thrown away.)
	var _top_lv := G.zone_unlock_level(G.ZONE_COUNT - 1)
	var _final := G.zone_window_lines(G.ZONE_COUNT - 1)
	ok(G.active_lines(_top_lv) == _final, "the last zone's own level carries the final window %s" % str(_final))
	for _over in [1, 2, 7, 40, 500]:
		ok(G.active_lines(_top_lv + _over) == _final, "L%d (past the arc) still holds the final window — no re-roll, no random lines" % (_top_lv + _over))
	var _fg := {}
	for _l2 in _final:
		for _g2 in G.gens_for_quest_line(int(_l2)):
			_fg[_g2] = true
	ok(_fg.size() <= int(G.QUEST_GEN_CAP), "the final window's generator footprint (%d) stays inside QUEST_GEN_CAP" % _fg.size())
	# THE SHIPPED ARC TABLE (the owner-facing view of the cadence × the window). One row per zone: the
	# LEVEL RANGE that zone owns, and the 3 lines the fence asks from across it. Re-tuning SCENE_END_LEVEL
	# or ZONE_BAND SHOULD break this — update it here so the arc stays reviewable in one place.
	var _arc := [
		[ 1, 14, [1]],            # z0  Fairy Hollow
		[15, 28, [1, 2]],         # z1
		[29, 32, [1, 2, 3]],      # z2  Snowy Village opens
		[33, 37, [2, 3, 4]],      # z3
		[38, 41, [3, 4, 5]],      # z4  winter berries (special)
		[42, 45, [4, 5, 6]],      # z5  Desert Oasis opens
		[46, 50, [5, 6, 7]],      # z6
		[51, 54, [6, 7, 8]],      # z7  spices (special)
		[55, 59, [7, 8, 16]],     # z8  Coral Reef opens
		[60, 64, [8, 16, 17]],    # z9  corals (special)
		[65, 68, [16, 17, 18]],   # z10 Cherry Blossom opens
		[69, 85, [17, 18, 19]],   # z11 tea cups (special) - the final window, held forever
	]
	var _arc_ok := true
	var _arc_bad := ""
	for _row in _arc:
		for _lv in range(int(_row[0]), int(_row[1]) + 1):
			if G.active_lines(int(_lv)) != _row[2]:
				_arc_ok = false
				if _arc_bad == "":
					_arc_bad = "L%d asks %s, expected %s" % [_lv, str(G.active_lines(int(_lv))), str(_row[2])]
	ok(_arc_ok, "the arc table holds at every level L1-L85 (%s)" % ("ok" if _arc_ok else _arc_bad))
	ok(int(_arc[0][0]) == 1 and G.active_lines(0) == [1], "a below-first-threshold level clamps to the anchor line")
	ok(G.gen_for_line(2) == "gen_2" and G.gen_for_line(5) == "", "base lines have a generator id; specials have none")
	# per-line generator roster (one generator per base line)
	# zone -> band is derived from the FROZEN ZONE_BAND counts ([6,4,7,4,4]) — the retired 5-map layout kept
	# purely for the per-band coin/sell curves (coin-clock redesign: the content arc gates on level, not spots).
	ok(G.zone_map(0) == 0 and G.zone_map(1) == 0 and G.zone_map(2) == 1 and G.zone_map(4) == 1 and G.zone_map(5) == 2 and G.zone_map(7) == 2 and G.zone_map(8) == 3 and G.zone_map(9) == 3 and G.zone_map(10) == 4 and G.zone_map(11) == 4, "zone -> band tracks the ZONE_BAND page distribution")
	# THE ZONE CADENCE IS DERIVED (re-spined 2026-07-26): each scene's LEVEL WINDOW is the owner-authored
	# SCENE_END_LEVEL band, and ZONE_BAND spreads that scene's zones evenly inside its own window. Scene
	# alignment is arithmetic now, not a hand-maintained invariant — these assertions are what hold it.
	var _cad := G.zone_unlock_levels()
	ok(_cad.size() == G.ZONE_COUNT, "the cadence has one level per zone")
	ok(_cad == [1, 15, 29, 33, 38, 42, 46, 51, 55, 60, 65, 69], "the derived cadence at the shipped SCENE_END_LEVEL band (got %s)" % str(_cad))
	ok(G.zone_unlock_level(0) == int(_cad[0]) and G.zone_unlock_level(G.ZONE_COUNT - 1) == int(_cad[G.ZONE_COUNT - 1]), "zone_unlock_level reads the derived cadence")
	var _cad_ok := true
	for _z in range(1, G.ZONE_COUNT):
		if int(_cad[_z]) <= int(_cad[_z - 1]):
			_cad_ok = false
	ok(_cad_ok, "the cadence is strictly increasing (each zone unlocks after the last)")
	# SCENE ALIGNMENT: zone z's line must arrive while its OWN scene is the one being unlocked. ZONE_BAND
	# says how many zones belong to each scene; every one of them must land inside that scene's window.
	var _zi := 0
	var _aligned := true
	for _p in G.ZONE_BAND.size():
		var _win := G.scene_level_window(int(_p))
		for _j in int(G.ZONE_BAND[_p]):
			var _lv := int(_cad[_zi])
			# zone 0 is the anchor: pinned to L1, which is scene 0's window start anyway
			if _lv < int(_win.x) or _lv > int(_win.y):
				_aligned = false
			_zi += 1
	ok(_zi == G.ZONE_COUNT, "ZONE_BAND accounts for every zone")
	ok(_aligned, "every zone unlocks inside its OWN scene's level window (scene alignment)")
	ok(G.zone_threshold(0) == G.coins_at_level(int(_cad[0])), "zone 0's threshold is its unlock-level coin threshold")
	ok(G.arc_finish_threshold() == G.zone_threshold(G.ZONE_COUNT - 1), "the arc finishes at the last zone's threshold")
	# scene-aligned cadence: quest_zone_for_level inverts the array (highest zone reached), so each base
	# generator's line becomes askable inside its own scene's cluster window (FH L1-28 · SV L29-41 · DO L42-54
	# · CR L55-64 · CB L65-71). Anchor at L1; content now spans the whole arc, out to L71.
	ok(G.quest_zone_for_level(1) == 0, "L1 → zone 0 (glow-mushrooms anchor)")
	ok(G.quest_zone_for_level(99) == G.ZONE_COUNT - 1, "past the arc clamps at the top zone")
	# DERIVED from the cadence, not hardcoded (there is no hand-authored table any more — see
	# _build_cadence): every zone must be reached exactly at its own unlock level and not one level sooner.
	for _z in G.ZONE_COUNT:
		var _ul := G.zone_unlock_level(int(_z))
		ok(G.quest_zone_for_level(_ul) == _z, "L%d reaches zone %d (line %d)" % [_ul, _z, G.zone_line(_z)])
		ok(_z == 0 or G.quest_zone_for_level(_ul - 1) < _z, "zone %d is NOT reached one level early (L%d)" % [_z, _ul - 1])
	# line_gated_out (save-migration predicate): a zone line is gated out below its zone's unlock level and
	# available at/after it; non-zone lines (coins/treats/special drops) are never gated.
	for _z2 in G.ZONE_COUNT:
		var _ul2 := G.zone_unlock_level(int(_z2))
		var _ln := G.zone_line(_z2)
		ok(_ul2 <= 1 or G.line_gated_out(_ln, _ul2 - 1), "line %d (zone %d) is gated out below L%d" % [_ln, _z2, _ul2])
		ok(not G.line_gated_out(_ln, _ul2), "line %d (zone %d) is available at L%d" % [_ln, _z2, _ul2])
	ok(not G.line_gated_out(1, 1), "the anchor line (zone 0, L1) is never gated out")
	ok(not G.line_gated_out(9, 1) and not G.line_gated_out(71, 1), "non-zone lines (coin line 9, treat line 71) are never gated out")
	var _band_sum := 0
	for _b in G.ZONE_BAND:
		_band_sum += int(_b)
	ok(_band_sum == G.ZONE_COUNT, "ZONE_BAND sums to ZONE_COUNT (every zone lands in exactly one band)")
	ok(G.zone_of_line(1) == 0 and G.zone_of_line(6) == 5 and G.zone_of_line(5) == 4, "zone_of_line inverts zone_line (base + special)")
	ok(G.base_generators().size() == 8, "the per-line roster has one generator per base line")
	var bgen := G.base_generator(2)
	ok(bgen.id == "gen_2" and bgen.line == 2 and bgen.zone == 1 and bgen.map == 0, "a base generator carries its id/line/zone/map")
	var bgen18 := G.base_generator(18)
	ok(bgen18.id == "gen_18" and bgen18.line == 18 and bgen18.zone == 10 and bgen18.map == 4, "the 8th base line (koi, 18) lands at zone 10 in page 5")
	# the data-driven recipes (arbitrary pairs, unlike the retired every-3rd-zone formula)
	ok(str(G.zone_recipe(4)) == str([2, 3]) and str(G.zone_recipe(11)) == str([8, 2]), "specials carry their authored recipes (winter berries 2+3; tea cups 8+2)")
	ok(G.special_for_pair(3, 2) == 5 and G.special_for_pair(8, 2) == 19 and G.special_for_pair(1, 2) == 0, "special_for_pair resolves authored pairs order-independently")
	ok(str(G.gens_for_quest_line(19)) == str(["gen_2", "gen_4"]), "a special-of-a-special resolves recursively to its BASE generators")
	# drift guard: each hardcoded GENERATORS.map must equal the live-derived zone_map(zone), so the sell band can't drift
	var _gen_maps_ok := true
	for _g in G.GENERATORS:
		if int(_g.map) != G.zone_map(int(_g.zone)):
			_gen_maps_ok = false
	ok(_gen_maps_ok, "every GENERATORS map matches the live zone_map(zone) — no hardcoded sell-band drift")
	# drift guard: every line SEEDED on the fresh map-0 board (STARTER_ITEMS) must be PRODUCEABLE there — some
	# map-0 generator pops it. A starter whose line has no generator is an orphan: nothing replenishes it and no
	# quest asks it, so it sits dead on every fresh board. (Regressed when staged Farm lines 61-66 were shelved
	# but STARTER_ITEMS still seeded Hearth embers 6101 — 3 dead items per new save.)
	var _farm_lines: Array = []
	for _g in G.generators_for_map(G.GENERATORS, 0):
		_farm_lines.append(int(_g.line))
	var _starters_produceable := true
	for _code in G.STARTER_ITEMS.values():
		if not _farm_lines.has(int(_code) / 100):
			_starters_produceable = false
	ok(_starters_produceable, "every STARTER_ITEMS line is produceable by a map-0 generator (no orphan starters)")
	ok(G.base_generator(5).is_empty(), "a special line has no generator")
	# owner art picks (2026-07-27): the 8-tier coin ladder wears chosen art off the 12-tier sheet
	ok(G.art_tier_for("coin", 1) == 1 and G.art_tier_for("coin", 2) == 4 and G.art_tier_for("coin", 3) == 5 \
		and G.art_tier_for("coin", 4) == 6 and G.art_tier_for("coin", 5) == 7 and G.art_tier_for("coin", 6) == 8 \
		and G.art_tier_for("coin", 7) == 10 and G.art_tier_for("coin", 8) == 12,
		"coin tiers wear the picked 8-step art spread (1/4/5/6/7/8/10/12)")
	ok(G.art_tier_for("acorn", 2) == 5 and G.art_tier_for("acorn", 3) == 6, "acorn tiers wear the picked art (3/5/6)")
	ok(G.art_tier_for("water", 2) == 2 and G.art_tier_for("fairy_hollow_glowshroom", 7) == 7, "unmapped bases pass tiers through unchanged")
	ok(G.item_tex_path(13 * 100 + 1).ends_with("acorn_3.png"), "the acorn drop's t1 sprite resolves through the pick map")
	# T55 buy-a-copy SPLIT ladder (owner decision 2026-07-18): t1-3 coins at 10× sell; t4+ Fibonacci acorns
	ok(G.buy_price(101) == Vector2i(G.sell_reward(101).x * 10, 0) and G.buy_price(103) == Vector2i(G.sell_reward(103).x * 10, 0), 		"t1-t3 copies buy for COINS at 10× the (band-scaled) sell value")
	ok(G.buy_price(1803).x == G.sell_reward(1803).x * 10, "a later-band t3 copy pays the same 10× rule on ITS band's sell value")
	ok(G.buy_price(104) == Vector2i(0, 1) and G.buy_price(105) == Vector2i(0, 2) and G.buy_price(106) == Vector2i(0, 3), 		"t4/t5/t6 copies buy for 1/2/3 acorns (the Fibonacci ramp starts)")
	ok(G.buy_price(107) == Vector2i(0, 5) and G.buy_price(108) == Vector2i(0, 8) and G.buy_price(112) == Vector2i(0, 55), 		"t7 → 5, t8 → 8 … t12 → 55 acorns (Fibonacci)")
	# (the active-lines window + due_line_gen are RETIRED; quest-driven birth-on-tap is covered by
	#  Quests.due_gen in quest_tests.gd.)
	ok(G.burst_odds() == [0.80, 0.15, 0.05] and G.burst_odds(true) == [0.20, 0.45, 0.35],
		"generator burst odds are flat after retiring generator merge tiers")

	# --- §9 THE SELL LADDER (docs/design/sell-economy-rework.md) — the SHAPE, so a re-tune of the three
	# grove_data dials is checked instead of restated. Coin values double from t4; t10+ pay flat acorns. ---
	ok(G.SELL_TIER_COINS.size() == int(G.TOP_TIER), "the authored coin ladder has one entry per tier")
	var split_ok := true
	for t in range(1, int(G.TOP_TIER) + 1):
		var pays_acorns := t >= int(G.SELL_ACORN_TIER)
		if pays_acorns != (int(G.sell_acorns(t)) > 0) or pays_acorns != (int(G.sell_tier_coins(t)) == 0):
			split_ok = false
	ok(split_ok, "every tier pays coins XOR acorns, split exactly at SELL_ACORN_TIER")
	# value of a tier in COIN-EQUIVALENTS (1 acorn = COINS_PER_ACORN), on the band-1.0 anchor line
	var tier_value := func(t: int) -> int:
		var rw: Vector2i = G.sell_reward(100 + t)
		return int(rw.x) + int(rw.y) * int(G.COINS_PER_ACORN)
	var merge_keeps_value := true
	var worst_split := 0
	for t in range(2, int(G.TOP_TIER) + 1):
		var gain := 2 * int(tier_value.call(t - 1)) - int(tier_value.call(t))
		worst_split = maxi(worst_split, gain)
		if t >= 5 and gain > 0:
			merge_keeps_value = false
	# t1-t4 keep the old linear 1·2·3·4, so a merge INTO t3/t4 still loses a coin or two (bounded by S2);
	# from t5 — the first doubled tier — value never falls.
	ok(merge_keeps_value, "S1: no merge into t5 or deeper destroys value — v(t) >= 2 x v(t-1) in coin-equivalents")
	ok(worst_split < int(G.SCISSORS_COST),
		"S2: the best split-and-sell gain (%d) stays under the scissors price (%d)" % [worst_split, int(G.SCISSORS_COST)])
	var acorn_water_ok := true
	var sells_under_buy := true
	for raw_tier in G.SELL_ACORNS.keys():
		var at := int(raw_tier)
		var paid := maxi(1, int(G.SELL_ACORNS[raw_tier]))
		if int(G.tier_clicks(at) / float(paid)) < 10 * int(G.water_a_diamond_buys()):
			acorn_water_ok = false
		if paid >= int(G.buy_price(100 + at).y):
			sells_under_buy = false
	ok(acorn_water_ok and int(G.water_to_earn_diamond()) >= 10 * int(G.water_a_diamond_buys()),
		"S3: earning an acorn by selling costs %d💧 — at least 10x the %d💧 an acorn buys" % [int(G.water_to_earn_diamond()), int(G.water_a_diamond_buys())])
	ok(sells_under_buy, "S4: an acorn-tier sale always pays less than buying that tier costs")

	# --- §6.D temporary treat generators (per-map line / clicks / id mapping) ---
	# Each map pops its OWN treasure line (deterministic, idea 4.1), and its icon matches.
	var per_map_ok := true
	for m in G.MAP_TREAT_LINE.size():
		var ln := G.pick_treat_line(m)
		if ln != int(G.MAP_TREAT_LINE[m]) or not G.TREAT_LINES.has(ln):
			per_map_ok = false
		# the themed icon for this map's treat gen resolves to the map-aligned art
		if G.gen_tex(G.treat_gen_id(ln)) != String(G.TREAT_GEN_TEX[m]):
			per_map_ok = false
	ok(per_map_ok, "each map pops its own treasure line with a map-aligned icon")
	# clicks budget stays in range
	var trng := RandomNumberGenerator.new(); trng.seed = 5
	var clicks_ok := true
	for i in 50:
		var c := G.pick_treat_clicks(trng)
		if c < int(G.TREAT_CLICKS[0]) or c > int(G.TREAT_CLICKS[1]):
			clicks_ok = false
	ok(clicks_ok, "pick_treat_clicks stays within the configured budget")
	# §6.D premium sell band — a treasure line sells above the top map band; a normal line does not
	ok(G.sell_reward(71 * 100 + 5).x == int(round(G.sell_tier_coins(5) * G.TREAT_SELL_BAND))
		and not G.is_treat_line(1 * 100 + 5),
		"a treasure line sells at the premium treat band; a normal line does not")
	# id ↔ line roundtrip + the is_treat_gen gate (a real gen id is not a treat)
	ok(G.is_treat_gen(G.treat_gen_id(63)) and G.treat_line_of(G.treat_gen_id(63)) == 63,
		"treat_gen_id ↔ treat_line_of roundtrips")
	ok(not G.is_treat_gen("gen_1") and not G.is_treat_gen("acc_water"),
		"a normal generator / accumulator is NOT a treat generator")
	ok(G.gen_tex(G.treat_gen_id(61)).begins_with("items/generator/gen_"), "a treat gen resolves a wired icon")

	finish()
