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
		{"id": "g0a", "map": 0, "line": 1, "cell": Vector2i(4, 3)},
		{"id": "g0b", "map": 0, "line": 2, "cell": Vector2i(2, 1)},
		{"id": "g1a", "map": 1, "line": 5, "cell": Vector2i(4, 3)},
		{"id": "g1b", "map": 1, "line": 6, "cell": Vector2i(2, 1)},
		{"id": "g1c", "map": 1, "line": 7, "cell": Vector2i(6, 5)},
	]

func _initialize() -> void:
	var r := _fixture()

	# --- per-map roster derivation (replaces appears_at accumulation) ---
	ok(G.generators_for_map(r, 0).size() == 2, "map 0 has 2 generators")
	ok(G.generators_for_map(r, 1).size() == 3, "map 1 has 3 generators")
	ok(G.lines_for_map(r, 1) == [5, 6, 7], "map 1's live lines are its 3 per-line generators' 3 lines")
	ok(G.retired_lines(r, 1) == [], "at map 1 nothing has retired yet — the 3-map rolling window still covers map 0")
	ok(G.lines_for_map(r, 0) == [1, 2], "map 0's live lines are its own 2")
	ok(G.retired_lines(r, 0) == [], "nothing is retired while in map 0")
	# retirement kicks in once a map falls OUTSIDE the rolling window: on the REAL roster, Wildflower(1) retires by map 3
	ok(G.retired_lines(G.GENERATORS, 3).has(1) and not G.askable_lines(G.GENERATORS, 3).has(1), "Wildflower(1) has RETIRED by map 3 (outside the 3-map window)")

	# (gens_to_grant + the carrier-quest delivery are RETIRED — generators now arrive when a generator tap
	#  produces a DUE tool; see G.due_generators, covered in quest_tests.gd against the real maps.)

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
	# sits on the board (at open_cell) while a granted next-map generator (gen_21) waits in the bag.
	bm.bag_add("gen_21")                         # a granted-but-unplaced generator, stashed in the bag
	var blob := bm.to_dict()
	var bm2 := BoardModel.new()
	bm2.from_dict(blob)
	ok(bm2.gen_id_at(open_cell) == "gen_1" and str(bm2.gen_bag) == str(bm.gen_bag) and bm2.gen_bag.has("gen_21"), "the generator map + gen_bag round-trip through to_dict/from_dict")

	# #8 generator merge ladder + tier persistence
	var bm3 := BoardModel.new()
	bm3.seed_gens(0)                                    # gen_1 at the anchor cell (4,3)
	var c1: Vector2i = bm3.empty_ground_cells()[0]
	bm3.place_gen("gen_1", c1)                          # a duplicate gen_1 (the merge fuel)
	ok(bm3.gen_tier_at(Vector2i(4, 3)) == 1 and bm3.gen_tier_at(c1) == 1, "new generators start at tier 1")
	ok(bm3.merge_gens(c1, Vector2i(4, 3)) and bm3.gen_tier_at(Vector2i(4, 3)) == 2 and not bm3.gens.has(c1), "two same-line generators merge 2:1 into a stronger tier, freeing the source")
	ok(not bm3.merge_gens(Vector2i(4, 3), Vector2i(4, 3)), "a generator can't merge with itself")
	var bm4 := BoardModel.new()
	bm4.from_dict(bm3.to_dict())
	ok(bm4.gen_tier_at(Vector2i(4, 3)) == 2, "a generator's tier survives a save round-trip")

	# #8 (cont.) the tier must travel THROUGH the gen_bag — storing then re-placing a merged generator
	# must NOT reset it to tier 1, and store must not leave stale tier data on the vacated cell.
	ok(bm3.store_gen(Vector2i(4, 3)) and bm3.gen_bag.has("gen_1"), "a tier-2 generator stores into the gen_bag")
	ok(bm3.gen_tier_at(Vector2i(4, 3)) == 1, "store_gen clears the vacated cell's tier (no stale tier-2 left behind)")
	var gb_back: Vector2i = bm3.empty_ground_cells()[0]
	ok(bm3.place_gen_from_bag("gen_1", gb_back) and bm3.gen_tier_at(gb_back) == 2, "place_gen_from_bag restores the stored tier (not reset to tier 1)")
	# the bagged tier must also survive a save round-trip — gen_bag tiers serialize, not just board tiers.
	bm3.store_gen(gb_back)                               # a tier-2 gen_1 waits in the bag across the save
	var bm5 := BoardModel.new()
	bm5.from_dict(bm3.to_dict())
	var gb_back2: Vector2i = bm5.empty_ground_cells()[0]
	ok(bm5.place_gen_from_bag("gen_1", gb_back2) and bm5.gen_tier_at(gb_back2) == 2, "a bagged generator's tier survives to_dict/from_dict")

	# --- burst-pop (§6, T58): a tap pops a BURST of items, each 1 energy. WITHOUT a boost a tap almost
	# always pops a SINGLE item (BURST_ODDS); a live BOOST swaps in BURST_ODDS_BOOST so multiples become
	# the norm — the boost RAISES THE CHANCE of multiples, it does not add a flat count. Both tables top
	# out at BURST_MAX, and there is no per-map scale-up (the map arg is ignored). ---
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
		var u := G.burst_count(0, 0, brng)              # no boost
		var b := G.burst_count(0, G.BOOST_BONUS, brng)  # boost live (any positive arg = boosted)
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
	var deep_max := 0
	for _i in N:
		deep_max = maxi(deep_max, G.burst_count(9, 0, brng))
	ok(deep_max <= int(G.BURST_MAX), "a deep map does not burst beyond BURST_MAX (no per-map scale-up)")
	# the boost coin sink: a flat cost, the same every activation (no ladder — T57)
	ok(G.boost_cost() > 0, "the boost has a positive coin cost")

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

	# --- §6.B special drop items — the shared pseudo-line foundation (chest/key/water/acorn/exp) ---
	var chest_t1 := 10 * 100 + 1            # chest tier 1
	var flower_t1 := 1 * 100 + 1           # a content line item
	var coin_t1 := G.COIN_LINE * 100 + 1   # a coin
	ok(G.is_special(chest_t1) and not G.is_special(flower_t1) and not G.is_special(coin_t1),
		"is_special gates only the special pseudo-lines (not content, not coins)")
	ok(G.special_kind(chest_t1) == "chest" and G.special_kind(11 * 100 + 1) == "key",
		"special_kind selects the per-item behaviour")
	ok(G.merge_top(chest_t1) == G.SPECIAL_TOP and G.merge_top(flower_t1) == G.TOP_TIER and G.merge_top(coin_t1) == G.COIN_TOP,
		"merge_top caps special items low, content high, coins at the coin top")
	ok(G.merge_top(coin_t1) == 12, "coins now merge through tier 12")
	ok(G.coin_value(G.COIN_LINE * 100 + 12) == 50000, "coin t12 collects for the tuned high-tier value")
	var sbm := BoardModel.new()
	sbm.place(Vector2i(3, 2), 10 * 100 + 2)
	sbm.place(Vector2i(3, 4), 10 * 100 + 2)
	ok(sbm.can_merge(Vector2i(3, 2), Vector2i(3, 4)), "two chest-t2 merge (below the special ceiling)")
	sbm.place(Vector2i(5, 2), 10 * 100 + 3)
	sbm.place(Vector2i(5, 4), 10 * 100 + 3)
	ok(not sbm.can_merge(Vector2i(5, 2), Vector2i(5, 4)), "two chest-t3 do NOT merge (at the special ceiling)")
	ok(G.item_tex_path(chest_t1).ends_with("items/chest/chest_1.png"), "a special item resolves its wired art path")
	ok(G.merge_top(13 * 100 + 1) == 12, "acorn drops now merge through tier 12")
	ok(G.item_tex_path(13 * 100 + 12).ends_with("items/acorn/acorn_12.png"), "acorn t12 resolves its wired art path")
	ok(ResourceLoader.exists("res://games/grove/assets/items/coin/coin_12.png"), "coin t12 art is imported")
	ok(ResourceLoader.exists(G.item_tex_path(13 * 100 + 12)), "acorn t12 art is imported")
	ok(not G.LINES.has(10), "a special pseudo-line is not a content LINE (never popped/asked/sold as content)")

	# --- §6.B special-drop reward math (drop roll, tap-collect, chest open) ---
	var srng := RandomNumberGenerator.new(); srng.seed = 7
	var picked := {}
	for i in 400:
		picked[int(G.pick_special_drop(srng) / 100.0)] = true
	ok(picked.size() >= 4 and G.special_kind(G.pick_special_drop(srng)) != "",
		"pick_special_drop yields t1 codes spread across the special kinds")
	# tap-collect grants the resource by tier; chest/key are NOT tap-collected (opened instead)
	ok(G.special_collect(12 * 100 + 2) == {"kind": "water", "amount": 20}, "water t2 tap-collects its tier amount")
	ok(G.special_collect(13 * 100 + 3) == {"kind": "acorn", "amount": 5}, "acorn t3 tap-collects acorns")
	ok(G.special_collect(13 * 100 + 12) == {"kind": "acorn", "amount": 5000}, "acorn t12 tap-collects its tuned premium amount")
	ok(G.special_collect(14 * 100 + 1) == {"kind": "exp", "amount": 5}, "exp (spark) t1 tap-collects exp")
	ok(G.special_collect(10 * 100 + 1).is_empty(), "a chest is NOT tap-collected (it is opened by a key)")
	# the open pairing: chest + key (either order), not chest+chest or key+water
	ok(G.can_open_chest(10 * 100 + 1, 11 * 100 + 1) and G.can_open_chest(11 * 100 + 2, 10 * 100 + 3),
		"a chest and a key open (in either order)")
	ok(not G.can_open_chest(10 * 100 + 1, 10 * 100 + 1) and not G.can_open_chest(10 * 100 + 1, 12 * 100 + 1),
		"chest+chest and chest+water do NOT open")
	# the open reward scales by chest tier and key-tier multiplier (t3 key = ×2)
	var r1 := G.chest_open_reward(10 * 100 + 1, 11 * 100 + 1)   # chest t1 · key t1 → 40 coins, 0 acorns
	var r3 := G.chest_open_reward(10 * 100 + 3, 11 * 100 + 3)   # chest t3 · key t3 → 320×2 coins, 3×2 acorns
	ok(int(r1.coins) == 40 and int(r1.acorns) == 0, "chest t1 + key t1 opens for the base coins")
	ok(int(r3.coins) == 640 and int(r3.acorns) == 6, "a higher chest + key tier multiplies the open payout")

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

	# --- §6 zone progression (gen redesign 2026-06-28; additive — board wiring flips later) ---
	ok(G.ZONE_BASE_LINES.size() == 17 and G.ZONE_SPECIAL_LINES.size() == 8 and G.ZONE_COUNT == 25, "25 zones = 17 base + 8 special (= the 25 live spots)")
	ok(not G.zone_is_special(0) and not G.zone_is_special(1) and G.zone_is_special(2), "every 3rd zone (z%3==2) is special")
	ok(G.zone_line(0) == 1 and G.zone_line(1) == 2 and G.zone_line(3) == 3 and G.zone_line(6) == 5 and G.zone_line(24) == 51, "base zones introduce the base lines in order (zone 24 = the 17th base, line 51)")
	ok(G.zone_line(2) == 71 and G.zone_line(5) == 72 and G.zone_line(23) == 78, "special zones introduce the special lines (zone 23 = the 8th special, line 78)")
	# §14 (25-zone): all 8 specials are authored + craftable now — 76/77/78 reuse spare mill/gate art
	ok(G.LINES.has(76) and G.LINES.has(77) and G.LINES.has(78), "the 3 late-game specials (76/77/78) now have LINES defs")
	ok(G.special_for_pair(32, 33) == 76 and G.special_for_pair(36, 37) == 78, "76 crafts from 32+33; 78 from 36+37 (recipes live)")
	ok(G.zone_recipe(2) == [1, 2] and G.zone_recipe(5) == [3, 4] and G.zone_recipe(23) == [36, 37], "a special is crafted from the two preceding base lines")
	ok(G.special_for_pair(1, 2) == 71 and G.special_for_pair(2, 1) == 71, "merging base lines 1+2 crafts special 71 (order-independent)")
	ok(G.special_for_pair(3, 4) == 72 and G.special_for_pair(1, 3) == 0, "3+4 craft special 72; a non-recipe pair crafts nothing")
	# §7 quest-side generator cap (#16, re-scoped): the quest pool's distinct-generator footprint is capped
	ok(G.cap_quest_lines([1, 2, 3, 4, 5, 21, 22, 23], 6).size() == 6, "a base-line quest pool trims to QUEST_GEN_CAP distinct generators")
	ok(G.cap_quest_lines([1, 2, 3], 6) == [1, 2, 3], "a small pool is left untouched (footprint under the cap)")
	# §14/§16 wire special quests into the askable pool: a special is asked only once REACHED with both ingredients live
	ok(G.active_special_lines([1, 2], 2) == [71], "special 71 is asked once zone 2 is reached with ingredients [1,2] live")
	ok(G.active_special_lines([1, 2], 1) == [], "a special is NOT asked before its zone is reached")
	ok(G.active_special_lines([2, 3], 2) == [], "a special drops out once an ingredient line (1) has retired")
	# no-strand invariant: every special the pool can ask has BOTH its ingredients producible in the base pool
	var _bp := G.askable_lines(G.GENERATORS, 2, G.APPEAR_ALL)
	var _all_producible := true
	for s in G.active_special_lines(_bp, 8):
		var _rr := G.zone_recipe(G.zone_of_line(int(s)))
		if not (_bp.has(int(_rr[0])) and _bp.has(int(_rr[1]))):
			_all_producible = false
	ok(_all_producible, "every asked special has both ingredients in the base pool (producible -> no-strand)")
	# §12 (simplified): the quest base pool is a rolling window of the LAST QUEST_GEN_CAP base lines reached
	ok(G.quest_base_lines(6) == [1, 2, 3, 4, 5], "by zone 6 only 5 base lines are reached -> the window holds all of them")
	ok(G.quest_base_lines(13) == [5, 21, 22, 23, 24, 31], "the window holds the LAST 6 base lines; lines 1-4 have rolled off")
	ok(G.gen_for_line(2) == "gen_2" and G.gen_for_line(71) == "", "base lines have a generator id; specials have none")
	# per-line generator roster (additive — replaces the 5 multi-line GENERATORS at the board flip)
	# zone -> map is derived live from the MAPS spot counts ([6,4,7,4,4] today): each map's first spot starts a
	# new map index. Pins the boundaries so it tracks the vine layout instead of a hardcoded split.
	ok(G.zone_map(0) == 0 and G.zone_map(5) == 0 and G.zone_map(6) == 1 and G.zone_map(9) == 1 and G.zone_map(10) == 2 and G.zone_map(16) == 2 and G.zone_map(17) == 3 and G.zone_map(20) == 3 and G.zone_map(21) == 4, "zone -> map tracks the live MAPS spot distribution")
	ok(G.zone_of_line(1) == 0 and G.zone_of_line(5) == 6 and G.zone_of_line(71) == 2, "zone_of_line inverts zone_line")
	ok(G.base_generators().size() == 17, "the per-line roster has one generator per base line")
	var bgen := G.base_generator(2)
	ok(bgen.id == "gen_2" and bgen.line == 2 and bgen.zone == 1 and bgen.map == 0, "a base generator carries its id/line/zone/map")
	var bgen51 := G.base_generator(51)
	ok(bgen51.id == "gen_51" and bgen51.line == 51 and bgen51.zone == 24 and bgen51.map == 4, "the 17th base line (51) lands at zone 24 in map 5")
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
	var _farm_lines: Array = G.lines_for_map(G.GENERATORS, 0)
	var _starters_produceable := true
	for _code in G.STARTER_ITEMS.values():
		if not _farm_lines.has(int(_code) / 100):
			_starters_produceable = false
	ok(_starters_produceable, "every STARTER_ITEMS line is produceable by a map-0 generator (no orphan starters)")
	ok(G.base_generator(71).is_empty(), "a special line has no generator")
	# active-window + birth-on-tap (tasks 5/7 logic; additive — board wiring flips later)
	ok(G.active_base_lines(0) == [1], "zone 0 -> 1 active base line")
	ok(G.active_base_lines(1) == [1, 2], "zone 1 -> 2 active base lines")
	ok(G.active_base_lines(7) == [4, 5, 21], "the active window holds the last 3 base lines (specials skipped)")
	ok(G.due_line_gen(7, ["gen_4", "gen_5"]) == "gen_21", "birth-on-tap returns the newest active line lacking a generator")
	ok(G.due_line_gen(7, ["gen_4", "gen_5", "gen_21"]) == "", "nothing due when all active lines have generators")
	# generator merge ladder (task 8 logic; additive — board wiring flips later)
	ok(G.gen_merge_tier(1) == 2 and G.gen_merge_tier(2) == 3 and G.gen_merge_tier(3) == 3, "generators merge up to tier 3, then cap")
	ok(G.gen_burst_odds(1) == [0.80, 0.15, 0.05] and float(G.gen_burst_odds(3)[2]) > float(G.gen_burst_odds(1)[2]), "higher generator tier pops more multiples")
	var sdup_rng := RandomNumberGenerator.new()
	sdup_rng.seed = 11
	var sdups := 0
	for i in 10000:
		if G.rolls_gen_self_dup(sdup_rng):
			sdups += 1
	ok(sdups > 15 and sdups < 130, "self-dup fires near the 0.5% rate over 10k taps")

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
	ok(G.sell_reward(71 * 100 + 5).x == int(round(5 * G.TREAT_SELL_BAND))
		and not G.is_treat_line(1 * 100 + 5),
		"a treasure line sells at the premium treat band; a normal line does not")
	# id ↔ line roundtrip + the is_treat_gen gate (a real gen id is not a treat)
	ok(G.is_treat_gen(G.treat_gen_id(63)) and G.treat_line_of(G.treat_gen_id(63)) == 63,
		"treat_gen_id ↔ treat_line_of roundtrips")
	ok(not G.is_treat_gen("gen_1") and not G.is_treat_gen("acc_water"),
		"a normal generator / accumulator is NOT a treat generator")
	ok(G.gen_tex(G.treat_gen_id(61)).begins_with("items/generator/gen_"), "a treat gen resolves a wired icon")

	# --- §6.B wildcard ---
	var wild_t3 := 15 * 100 + 3
	var flower_t3 := 1 * 100 + 3
	ok(G.is_wildcard(wild_t3) and not G.is_wildcard(flower_t3), "is_wildcard gates only the wildcard")
	ok(G.merge_top(wild_t3) == G.TOP_TIER and G.merge_top(10 * 100 + 1) == G.SPECIAL_TOP,
		"a wildcard self-merges the full 12 tiers; other special items still cap at SPECIAL_TOP")
	# wildcard advances a same-tier item one tier (consuming the wildcard)
	ok(G.wildcard_advance_code(wild_t3, flower_t3) == 1 * 100 + 4, "a wildcard advances a same-tier item one tier")
	ok(G.wildcard_advance_code(wild_t3, 1 * 100 + 5) == 0, "a wildcard does NOT apply to a different-tier item")
	ok(G.wildcard_advance_code(wild_t3, 15 * 100 + 3) == 0, "two wildcards do NOT 'advance' (they merge normally)")
	# two wildcards CAN self-merge
	var wbm := BoardModel.new()
	wbm.place(Vector2i(5, 2), 15 * 100 + 1); wbm.place(Vector2i(5, 4), 15 * 100 + 1)
	ok(wbm.can_merge(Vector2i(5, 2), Vector2i(5, 4)), "two wildcards self-merge")

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
