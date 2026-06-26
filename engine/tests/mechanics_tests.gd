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
		upgraded = maxi(upgraded, G.burst_count(0, G.BOOST_BONUS, brng))
	ok(upgraded > 3, "a live boost raises the burst")
	var capped := true
	var floored := true
	for _i in 200:
		var bc := G.burst_count(4, G.BOOST_BONUS, brng)
		if bc > int(G.BURST_MAX):
			capped = false
		if G.burst_count(0, 0, brng) < 1:
			floored = false
	ok(capped, "burst never exceeds BURST_MAX")
	ok(floored, "burst is always at least 1")
	# the boost coin sink: a flat cost, the same every activation (no ladder — T57)
	ok(G.boost_cost() > 0, "the boost has a positive coin cost")
	ok(G.boost_bonus() > 0, "the boost adds a positive per-tap bonus")
	# T25/T57 DECOUPLE: at a deep map the FREE portion is capped (BURST_FREE_MAX), and a live BOOST adds
	# exactly BOOST_BONUS more ON TOP (clamped — a larger addend can't over-stack). Regression guard for
	# the old combined cap that clipped the bonus (burst_count(4, bonus) was stuck at the free cap).
	var deep_free := 0
	var deep_boost := 0
	var deep_over := 0
	for _i in 400:
		deep_free = maxi(deep_free, G.burst_count(4, 0, brng))                  # no boost
		deep_boost = maxi(deep_boost, G.burst_count(4, G.BOOST_BONUS, brng))    # a live boost
		deep_over = maxi(deep_over, G.burst_count(4, G.BOOST_BONUS + 5, brng))  # an over-large addend → clamped
	ok(deep_free == int(G.BURST_FREE_MAX), "deep-map FREE burst caps at BURST_FREE_MAX")
	ok(deep_boost == mini(int(G.BURST_FREE_MAX) + int(G.BOOST_BONUS), int(G.BURST_MAX)), "a live boost adds BOOST_BONUS on top of the free cap")
	ok(deep_boost == int(G.BURST_MAX), "the boosted deep-map burst reaches BURST_MAX (free cap + the boost bonus)")
	ok(deep_over == deep_boost, "the boost addend is clamped — a larger value can't over-stack the burst")

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
	var sbm := BoardModel.new()
	sbm.place(Vector2i(3, 2), 10 * 100 + 2)
	sbm.place(Vector2i(3, 4), 10 * 100 + 2)
	ok(sbm.can_merge(Vector2i(3, 2), Vector2i(3, 4)), "two chest-t2 merge (below the special ceiling)")
	sbm.place(Vector2i(5, 2), 10 * 100 + 3)
	sbm.place(Vector2i(5, 4), 10 * 100 + 3)
	ok(not sbm.can_merge(Vector2i(5, 2), Vector2i(5, 4)), "two chest-t3 do NOT merge (at the special ceiling)")
	ok(G.item_tex_path(chest_t1).ends_with("items/chest/chest_1.png"), "a special item resolves its wired art path")
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
	ok(G.accumulator_banked("water", 1000.0, 1000.0 + secs * 3.0) == 3, "banks +1 per interval since last collect")
	ok(G.accumulator_banked("water", 1000.0, 1000.0 + secs * 1000.0) == capn, "banking is capped at the small cap")
	ok(G.accumulator_full("water", 1000.0, 1000.0 + secs * 1000.0), "accumulator_full flags the at-cap state")
	# collect reward = banked × per-unit value
	ok(G.accumulator_reward("water", 3) == {"kind": "water", "amount": 3 * int(G.ACCUMULATORS["water"]["value"])},
		"the collect reward is banked × the per-unit value")

	# --- §6.D temporary treat generators (spawn / line / clicks / id mapping) ---
	var trng := RandomNumberGenerator.new(); trng.seed = 5
	var tlines := {}
	var clicks_ok := true
	for i in 200:
		var ln := G.pick_treat_line(trng)
		tlines[ln] = true
		if not G.TREAT_LINES.has(ln):
			clicks_ok = false
		var c := G.pick_treat_clicks(trng)
		if c < int(G.TREAT_CLICKS[0]) or c > int(G.TREAT_CLICKS[1]):
			clicks_ok = false
	ok(clicks_ok and tlines.size() >= 4, "pick_treat_line/clicks stay in range and spread across the treat lines")
	# id ↔ line roundtrip + the is_treat_gen gate (a real gen id is not a treat)
	ok(G.is_treat_gen(G.treat_gen_id(63)) and G.treat_line_of(G.treat_gen_id(63)) == 63,
		"treat_gen_id ↔ treat_line_of roundtrips")
	ok(not G.is_treat_gen("seed_satchel") and not G.is_treat_gen("acc_water"),
		"a normal generator / accumulator is NOT a treat generator")
	ok(G.gen_tex(G.treat_gen_id(61)).begins_with("items/generator/gen_"), "a treat gen resolves a wired icon")

	# --- §6.B wildcard ---
	var wild_t3 := 15 * 100 + 3
	var flower_t3 := 1 * 100 + 3
	ok(G.is_wildcard(wild_t3) and not G.is_wildcard(flower_t3), "is_wildcard gates only the wildcard")
	ok(G.merge_top(wild_t3) == G.SPECIAL_TOP, "a wildcard self-merges up to the special ceiling")
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
