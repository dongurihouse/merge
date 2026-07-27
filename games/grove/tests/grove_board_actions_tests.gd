extends "res://games/grove/tests/grove_test_base.gd"
## grove · board actions — the PURE player-action layer (no scene). Proves a board action
## (deliver a quest) applies its whole state transition — consume the tile, drop the quest,
## advance exp, pay coins — as a headless call on BoardModel + Save, with NO Control / Tween /
## Board scene. This is the "change the rule, assert without UI validation" gate.

const BoardActions = preload("res://engine/scripts/core/board_actions.gd")
const BoardLogic = preload("res://engine/scripts/core/board_logic.gd")

func _initialize() -> void:
	begin("grove · board actions")
	_test_deliver_quest()
	_test_deliver_empty_quest_skips_recent()
	_test_per_generator_boost()
	_test_collect_coin()
	_test_collect_special()
	_test_produce_due_generators()
	_test_gen_redundancy()
	_test_self_dup_at_top()
	_test_sell_generator()
	_test_line_farewell_predicates()
	_test_farewell_sweep()
	_test_pick_drop_cell()
	_test_generator_swaps()
	finish()

# Delivering a quest is the ONE place exp advances. The action consumes the asked tile, drops the
# quest from the live fence, remembers the asked item (anti-monotony window), earns exp (and reports
# the levels gained so the scene can fire the Level dialog), and pays the coin reward — all pure.
func _test_deliver_quest() -> void:
	fresh("deliver_quest")
	var board := BoardModel.new()
	var cell := Vector2i(4, 3)
	var code := 101                                  # line 1, tier 1
	board.place(cell, code)
	ok(board.item_at(cell) == code, "the asked tile sits on the board pre-delivery")

	var quests: Array = [{"line": 1, "tier": 1, "reward": {"coins": 3}}]
	var recent: Array = []
	var earned_b := Save.coins_earned_lifetime()
	var coins_b := Save.coins()

	var out: Dictionary = BoardActions.deliver_quest(board, quests, recent, 0, cell)

	ok(board.item_at(cell) == 0, "delivery consumed the asked tile")
	ok(quests.is_empty(), "delivery dropped the quest from the fence")
	ok(recent == [code], "delivery remembered the asked item (anti-monotony window)")
	ok(Save.coins() == coins_b + 3, "delivery paid the quest's coin reward")
	ok(Save.coins_earned_lifetime() == earned_b + 3, "delivery advanced the coin clock (organic earn)")
	ok(int(out.get("coins", -1)) == 3, "the outcome reports the coins for the render layer")
	ok(int(out.get("code", -1)) == code and Vector2i(out.get("cell", Vector2i(-1, -1))) == cell, "the outcome reports the consumed code + cell")
	ok(out.has("levels_up"), "the outcome reports levels gained (drives the Level dialog)")

# A quest with NO item (a stale/empty ask) still pays out, but does NOT push onto the recent-item
# window — there is no asked code to steer future quests away from.
func _test_deliver_empty_quest_skips_recent() -> void:
	fresh("deliver_empty")
	var board := BoardModel.new()
	var quests: Array = [{"reward": {"coins": 2}}]   # no line/tier → quest_item is empty
	var recent: Array = []
	var earned_b := Save.coins_earned_lifetime()
	var out: Dictionary = BoardActions.deliver_quest(board, quests, recent, 0, Vector2i(0, 0))
	ok(quests.is_empty(), "an empty-item quest still leaves the fence")
	ok(recent.is_empty(), "an empty-item quest does NOT touch the recent-item window")
	ok(Save.coins_earned_lifetime() == earned_b + 2, "an empty-item quest still pays its coins into the clock")
	ok(int(out.get("coins", -1)) == 2, "the outcome reports the paid coins")

# §6 per-generator boost: pure BoardModel state that rides with the generator (arm / consume / stackable /
# move-carries / merge-sums / sell-clears / bag round-trip). Gated HERE (active suite) because the fuller
# grove_model_tests / grove_economy_tests boost coverage currently sits in *_DISABLED.
func _test_per_generator_boost() -> void:
	fresh("pergen_boost")
	var b := BoardModel.new(); b.seed_gens(0)
	var a: Vector2i = b.gens.keys()[0]
	ok(b.gen_boost_at(a) == 0 and not b.is_gen_boosted(a), "boost: a fresh generator is unboosted")
	b.arm_gen_boost(a, G.BOOST_TAPS)
	ok(b.is_gen_boosted(a) and b.gen_boost_at(a) == G.BOOST_TAPS, "boost: arm sets the cell's taps")
	b.consume_gen_boost(a)
	ok(b.gen_boost_at(a) == G.BOOST_TAPS - 1, "boost: a tap consumes one of that cell's taps")
	# a second generator is independently boostable (stackable) and unaffected by the first
	var c: Vector2i = b.empty_ground_cells()[0]
	b.place_gen(b.gen_id_at(a), c, b.gen_tier_at(a))
	b.arm_gen_boost(c, 5)
	ok(b.is_gen_boosted(a) and b.is_gen_boosted(c), "boost: two generators are boosted at once (stackable)")
	# move carries the taps; merge sums them; sell clears
	var d: Vector2i = b.empty_ground_cells()[0]
	ok(b.move_gen(a, d) and b.gen_boost_at(d) == G.BOOST_TAPS - 1 and b.gen_boost_at(a) == 0, "boost: move carries the taps to the new cell")
	ok(b.merge_gens(d, c) and b.gen_boost_at(c) == (G.BOOST_TAPS - 1) + 5, "boost: merge sums the survivor's and source's taps")
	ok(b.remove_gen(c) and b.gen_boost_at(c) == 0, "boost: sell/remove clears the boost")
	# the bag carries the boost in, and it survives a save round-trip back onto the board
	var e := BoardModel.new(); e.seed_gens(0)
	var ec: Vector2i = e.gens.keys()[0]
	var eid := e.gen_id_at(ec)
	e.arm_gen_boost(ec, 6)
	ok(e.store_gen(ec) and e.gen_bag_boost.size() == e.gen_bag.size(), "boost: storing carries the boost into the bag (arrays aligned)")
	var e2 := BoardModel.new(); e2.from_dict(e.to_dict())
	var eopen: Vector2i = e2.empty_ground_cells()[0]
	ok(e2.place_gen_from_bag(eid, eopen) and e2.gen_boost_at(eopen) == 6, "boost: re-placing from a saved bag restores the carried taps")

# §6.B collect a board coin → the tile leaves the board and its value credits the coin wallet. Pure
# transition: model take + Save.add_coins, returning the credited amount for the scene's fly-to-HUD.
func _test_collect_coin() -> void:
	fresh("collect_coin")
	var board := BoardModel.new()
	var cell := Vector2i(2, 2)
	var code := G.COIN_LINE * 100 + 1
	board.place(cell, code)
	var coins_b := Save.coins()
	var out: Dictionary = BoardActions.collect_coin(board, cell)
	ok(board.item_at(cell) == 0, "collecting removed the coin from the board")
	ok(int(out.get("got", -1)) == G.coin_value(code), "collect_coin reports the coin value")
	ok(Save.coins() == coins_b + G.coin_value(code), "collect_coin credited the coin value to the wallet")

# §6.B collect a special drop (water / acorn). acorn writes Save directly; water is RETURNED
# for the caller to fold into its live water mirror (a scene field, not Save). The tile always leaves.
func _test_collect_special() -> void:
	fresh("collect_special")
	var board := BoardModel.new()
	var special := 13 * 100 + 1
	# a stashed reward overrides the face value; the report carries kind + amount
	var c1 := Vector2i(1, 1)
	board.place(c1, special)
	board.set_collect_reward(c1, "acorn", 5)
	var dia_stash := Save.diamonds()
	var o1: Dictionary = BoardActions.collect_special(board, c1)
	ok(board.item_at(c1) == 0, "collecting a special removes it from the board")
	ok(String(o1.get("kind", "")) == "acorn" and int(o1.get("amount", -1)) == 5, "collect_special reports kind + amount")
	ok(Save.diamonds() == dia_stash + 5, "a stashed acorn reward overrides the face value")
	# acorn special → Save.add_diamonds
	var c2 := Vector2i(2, 2)
	board.place(c2, special)
	board.set_collect_reward(c2, "acorn", 3)
	var dia_b := Save.diamonds()
	BoardActions.collect_special(board, c2)
	ok(Save.diamonds() == dia_b + 3, "an acorn special credits diamonds")
	# water special → NOT written to Save; returned so the caller folds it into its live water mirror
	var c3 := Vector2i(3, 3)
	board.place(c3, special)
	board.set_collect_reward(c3, "water", 4)
	var dia_b2 := Save.diamonds()
	var o3: Dictionary = BoardActions.collect_special(board, c3)
	ok(String(o3.get("kind", "")) == "water" and int(o3.get("amount", -1)) == 4, "a water special is reported for the caller's water mirror")
	ok(board.item_at(c3) == 0 and Save.diamonds() == dia_b2, "the water special is consumed but writes no Save currency")

# Birth-on-tap: the generator the board owes (the anchor self-heals first, then any quest-required gen the
# player lacks) lands on a free cell, or falls into the bag when the board is full. Pure model placement.
func _test_produce_due_generators() -> void:
	var anchor := G.anchor_gen()
	# 1. a fresh board owes the anchor → it lands on one free cell
	var board := BoardModel.new()
	var out: Dictionary = BoardActions.produce_due_generators(board, [])
	ok(bool(out.get("due", false)) and out.get("landed", []).size() == 1, "a fresh board is due to produce the anchor onto one cell")
	var cell: Vector2i = out.landed[0]
	ok(board.is_gen(cell) and board.gen_id_at(cell) == anchor, "the landed cell holds the anchor generator")
	# 2. idempotent: with the anchor now owned, nothing further is due
	ok(not bool(BoardActions.produce_due_generators(board, []).get("due", false)), "with the anchor owned, nothing more is due")
	# 3. board full → the owed tool falls into the bag instead of a cell
	var full := BoardModel.new()
	for i in full.items.size():
		full.items[i] = 101                       # occupy every cell → no empty ground remains
	var outf: Dictionary = BoardActions.produce_due_generators(full, [])
	ok(bool(outf.due) and outf.landed.is_empty() and outf.bagged == [anchor], "a full board bags the owed anchor instead of placing it")
	ok(full.gen_bag.has(anchor), "the bagged anchor is held in the gen bag")
	# 4. a returning line restores the kept tier/boost saved by the farewell sweep, then consumes the keepsake.
	fresh("produce_due_generators_kept")
	var kept := Save.grove()
	kept["gen_kept"] = {"gen_4": [3, 6]}
	Save.grove_write()
	var returning := BoardModel.new()
	var own_cell: Vector2i = returning.empty_ground_cells()[0]
	returning.place_gen("gen_2", own_cell)
	var due: Array = [{"line": 8, "tier": 1}]       # spices needs wild berries + woolens
	var outk: Dictionary = BoardActions.produce_due_generators(returning, due)
	ok(bool(outk.due) and outk.landed.size() == 1, "a future special ask births the missing kept generator")
	var rc: Vector2i = outk.landed[0]
	ok(returning.gen_id_at(rc) == "gen_4" and returning.gen_tier_at(rc) == 3 and returning.gen_boost_at(rc) == 6,
		"the returning generator restores its kept tier and boost exactly")
	ok(not (Save.grove().get("gen_kept", {}) as Dictionary).has("gen_4"),
		"the keepsake is consumed after the generator returns")

# top_gen_tier = the line's highest owned tier across board + bag; is_redundant_gen flags any generator
# that has a strictly-higher same-line sibling (so it can never merge up to the top → safe to sell).
func _test_gen_redundancy() -> void:
	fresh("gen_redundancy")
	var b := BoardModel.new()
	var gid := G.anchor_gen()                          # gen_1, line 1
	var line := int(G.gen_def(G.GENERATORS, gid).get("line", 0))
	ok(b.top_gen_tier(line) == 0, "no generators of a line → top tier 0")
	var t1: Vector2i = b.empty_ground_cells()[0]
	b.place_gen(gid, t1, 1)
	ok(b.top_gen_tier(line) == 1 and not b.is_redundant_gen(t1), "a lone tier-1 is the top, not redundant")
	var t3: Vector2i = b.empty_ground_cells()[0]
	b.place_gen(gid, t3, 3)
	ok(b.top_gen_tier(line) == 3, "top_gen_tier reports the highest owned tier")
	ok(b.is_redundant_gen(t1) and not b.is_redundant_gen(t3), "the tier-1 is redundant under the tier-3; the tier-3 is not")
	# a bagged higher tier still makes a board leftover redundant (top is bag-aware)
	var b2 := BoardModel.new()
	var lc: Vector2i = b2.empty_ground_cells()[0]
	b2.place_gen(gid, lc, 1)
	b2.bag_add(gid, 3)
	ok(b2.top_gen_tier(line) == 3 and b2.is_redundant_gen(lc), "a bagged tier-3 makes the board tier-1 redundant")
	ok(not b2.is_redundant_gen(Vector2i(0, 0)), "an empty cell is not a redundant generator")

# Self-dup feeds the line's TOP lineage: the duplicate spawns at top_gen_tier (not the tapped generator's
# tier), so tapping a sub-top leftover never breeds more low tiers, and a maxed line breeds nothing at all.
func _test_self_dup_at_top() -> void:
	fresh("self_dup_at_top")
	var gid := G.anchor_gen()
	# tapping a tier-1 leftover while a tier-2 top exists spawns the duplicate at the TOP (tier 2)
	var b := BoardModel.new()
	var low: Vector2i = b.empty_ground_cells()[0]
	b.place_gen(gid, low, 1)
	var top: Vector2i = b.empty_ground_cells()[0]
	b.place_gen(gid, top, 2)
	var out: Dictionary = BoardActions.self_dup_generator(b, low)
	ok(out.landed.size() == 1, "self-dup placed one duplicate")
	ok(b.gen_tier_at(out.landed[0]) == 2, "the duplicate spawns at the line top (tier 2), not the tapped tier 1")
	# a maxed line (top == GEN_TOP_TIER) breeds nothing — no new strand
	var bm := BoardModel.new()
	var mx: Vector2i = bm.empty_ground_cells()[0]
	bm.place_gen(gid, mx, G.GEN_TOP_TIER)
	var leftover: Vector2i = bm.empty_ground_cells()[0]
	bm.place_gen(gid, leftover, 1)
	var outm: Dictionary = BoardActions.self_dup_generator(bm, leftover)
	ok(outm.landed.is_empty() and outm.bagged.is_empty(), "a maxed line breeds no duplicate")
	# board full → the duplicate falls into the bag at the line-top tier
	var bf := BoardModel.new()
	for i in bf.items.size():
		bf.items[i] = 101
	bf.place_gen(gid, Vector2i(4, 3), 1)               # place_gen clears this cell's item; the board is else full
	var outf: Dictionary = BoardActions.self_dup_generator(bf, Vector2i(4, 3))
	ok(outf.landed.is_empty() and outf.bagged == [gid], "a full board bags the duplicate")
	ok(bf._bag_tier_at(0) == 1, "the bagged duplicate carries the line-top tier")

# Selling a redundant generator removes it + credits GEN_SELL_COINS; the guard refuses a non-redundant
# (last/highest) generator, so a line always keeps its top producer (quests stay satisfiable).
func _test_sell_generator() -> void:
	fresh("sell_generator")
	var gid := G.anchor_gen()
	var b := BoardModel.new()
	var low: Vector2i = b.empty_ground_cells()[0]
	b.place_gen(gid, low, 1)
	var top: Vector2i = b.empty_ground_cells()[0]
	b.place_gen(gid, top, 3)
	var coins_b := Save.coins()
	var clock_b := Save.coins_earned_lifetime()
	var out: Dictionary = BoardActions.sell_generator(b, low)
	ok(bool(out.sold) and int(out.coins) == G.gen_sell_coins(1), "selling a redundant tier-1 reports sold + its coin value")
	ok(not b.gens.has(low) and b.gens.has(top), "the redundant generator is removed; the top survives")
	ok(Save.coins() == coins_b + G.gen_sell_coins(1), "the sale credits GEN_SELL_COINS to the wallet")
	# THE CLOCK IS QUESTS ONLY (owner call 2026-07-25) — a sale is cleanup: its coins spend, but they must
	# never buy progression, or retiring stock pays for its own retirement (grove_sim measured that loop at
	# 8x the quest faucet). The guard belongs here so a future sell path can't quietly re-open it.
	ok(Save.coins_earned_lifetime() == clock_b, "SELLING NEVER ADVANCES THE CLOCK — the sale is spendable-only")
	var out2: Dictionary = BoardActions.sell_generator(b, top)
	ok(not bool(out2.sold) and b.gens.has(top), "a non-redundant (top) generator cannot be sold")
	ok(G.gen_sell_coins(1) >= 0 and G.gen_sell_coins(2) >= 0, "gen_sell_coins is defined for the sellable tiers 1..2")

# The farewell predicates read the active window's recursive closure, not just the three visible asks.
# This catches the bug where Woolens/Snow/Wild Berries leave the current window but must come back later as
# special-line ingredients. Levels are derived from the zone cadence so tuning moves the assertions with it.
func _test_line_farewell_predicates() -> void:
	fresh("line_farewell_predicates")
	var l33 := G.zone_unlock_level(3)
	var l46 := G.zone_unlock_level(6)
	var l51 := G.zone_unlock_level(7)
	var l60 := G.zone_unlock_level(9)
	var l65 := G.zone_unlock_level(10)
	var l69 := G.zone_unlock_level(11)
	ok(G.line_needed_at_zone(1, 2) and not G.line_needed_at_zone(1, 3),
		"glow-mushrooms are needed through zone 2, then complete when zone 3 opens at L%d" % l33)
	var wool_back: Dictionary = G.next_need(4, l46)
	ok(not G.line_needed_at_zone(4, 6) and int(wool_back.level) == l51 and int(wool_back.for_line) == 8,
		"woolens are away at L%d and return at L%d for spices" % [l46, l51])
	var snow_back: Dictionary = G.next_need(3, l51)
	ok(not G.line_needed_at_zone(3, 7) and int(snow_back.level) == l60 and int(snow_back.for_line) == 17,
		"snow & ice are away at L%d and return at L%d for corals" % [l51, l60])
	var wild_back: Dictionary = G.next_need(2, l65)
	ok(not G.line_needed_at_zone(2, 10) and int(wild_back.level) == l69 and int(wild_back.for_line) == 19,
		"wild berries are away at L%d and return at L%d for tea cups" % [l65, l69])
	ok(G.next_need(1, l33).is_empty(), "a complete line has no future next_need")
	var final_gens: Dictionary = G.needed_gens(l69)
	ok(final_gens.has("gen_2") and final_gens.has("gen_4") and final_gens.has("gen_18"),
		"due_gen can reach every base generator needed by the future Tea Cups window")

# Farewell sweep is board-presence based: board stock sells into the spendable wallet, board generators
# disappear, upgraded generators leave a gen_kept keepsake, and item/gen bags remain a true hoard path.
func _test_farewell_sweep() -> void:
	fresh("farewell_sweep")
	var b := BoardModel.new()
	for r in G.ROWS:
		for c in G.COLS:
			b.terrain[BoardModel.idx(Vector2i(r, c))] = 0
			b.take(Vector2i(r, c))
	var cells := b.empty_ground_cells()
	ok(cells.size() >= 8, "fixture: opened board has room for the farewell sweep")
	var l65 := G.zone_unlock_level(10)
	b.place_gen("gen_2", cells[0], 3)
	b.arm_gen_boost(cells[0], 5)
	b.place_gen("gen_4", cells[1], 2)
	b.place(cells[2], 2 * 100 + 2)
	b.place(cells[3], 4 * 100 + 3)
	b.place(cells[4], 8 * 100 + 1)
	b.place(cells[5], 16 * 100 + 2)             # currently needed at L65 — must survive
	b.gen_bag = ["gen_2", "gen_4"]
	b.gen_bag_tiers = [4, 1]
	b.gen_bag_boost = [9, 0]
	var due: Array = BoardActions.farewells_due(b, l65)
	ok(due.map(func(e): return int(e.line)) == [2, 4, 8],
		"L65 farewells are Wild Berries, Woolens, and Spices when each has board presence")
	for e in due:
		ok(int((e.next_need as Dictionary).level) == G.zone_unlock_level(11) and int((e.next_need as Dictionary).for_line) == 19,
			"each L65 farewell points at Tea Cups as its return")
	var wallet_b := Save.coins()
	var clock_b := Save.coins_earned_lifetime()
	var expect := int(G.sell_reward(202).x)
	var actions := BoardActions.new()
	var has_preview := false
	for method in actions.get_method_list():
		if String(method.get("name", "")) == "farewell_preview":
			has_preview = true
	ok(has_preview, "farewell payout exposes one shared preview for the card and sweep")
	var preview: Dictionary = actions.call("farewell_preview", b, 2) if has_preview else {}
	ok(int(preview.get("pieces", -1)) == 1 and int(preview.get("coins", -1)) == expect and int(preview.get("gens", -1)) == 1,
		"farewell_preview reports the exact pieces, spendable coins, and board generators before mutation")
	ok(b.item_at(cells[2]) == 2 * 100 + 2 and b.gens.has(cells[0]),
		"farewell_preview is read-only: the card can display it before the sweep mutates the board")
	var out: Dictionary = BoardActions.sweep_line(b, 2)
	ok(int(out.pieces) == int(preview.get("pieces", -1)) and int(out.coins) == int(preview.get("coins", -1)) and int(out.gens) == int(preview.get("gens", -1)),
		"sweep_line returns the same payout facts the farewell card preview displayed")
	ok(int(out.pieces) == 1 and int(out.coins) == expect and int(out.gens) == 1,
		"sweep_line reports board pieces, spendable coins, and removed board generators")
	ok(Save.coins() == wallet_b + expect, "sweep_line credits board-stock coins to the wallet")
	ok(Save.coins_earned_lifetime() == clock_b, "SWEEP NEVER ADVANCES THE CLOCK")
	ok(not b.gens.values().has("gen_2") and b.gen_bag == ["gen_2", "gen_4"]
		and b.gen_bag_tiers == [4, 1] and b.gen_bag_boost == [9, 0],
		"sweep touches board generators but leaves the generator bag untouched")
	var kept: Dictionary = Save.grove().get("gen_kept", {})
	ok(kept.get("gen_2", []) == [3, 5], "an upgraded swept board generator writes gen_kept [tier, boost]")
	ok(BoardActions.farewells_due(b, l65).map(func(e): return int(e.line)) == [4, 8],
		"presence-based evaluation is idempotent: the swept line does not re-fire")
	var live_piece_survived := false
	for v in b.items:
		if int(v) == 16 * 100 + 2:
			live_piece_survived = true
	ok(live_piece_survived, "a currently needed line's board piece is untouched")

# The lucky-drop landing cell (shared by the coin shake + the §6.B special shake): one of the ≤3 open
# cells nearest the merge, picked by rng — or the (-1,-1) sentinel when the board has no open ground.
func _test_pick_drop_cell() -> void:
	var board := BoardModel.new()
	var near := Vector2i(3, 3)
	var empties := board.empty_ground_cells()
	ok(not empties.is_empty(), "a fresh board has open cells to drop into")
	empties.sort_custom(func(a, b): return (a - near).length_squared() < (b - near).length_squared())
	var nearest3: Array = empties.slice(0, mini(3, empties.size()))
	var rng := RandomNumberGenerator.new()
	rng.seed = 999
	var all_in := true
	for n in 12:
		if not (BoardLogic.pick_drop_cell(board, near, rng) in nearest3):
			all_in = false
	ok(all_in, "pick_drop_cell always lands within the 3 nearest open cells")
	var full := BoardModel.new()
	for i in full.items.size():
		full.items[i] = 101
	ok(BoardLogic.pick_drop_cell(full, near, rng) == Vector2i(-1, -1), "a board with no open ground yields the (-1,-1) sentinel")

# Generators are movable board pieces: besides empty-ground moves and same-generator merges, they can
# trade cells with a regular item or with a non-mergeable generator without dropping tier/boost state.
func _test_generator_swaps() -> void:
	fresh("generator_swaps")
	var b := BoardModel.new(); b.seed_gens(0)
	var gen_cell: Vector2i = b.gens.keys()[0]
	var gen_id := b.gen_id_at(gen_cell)
	b.gen_tiers[gen_cell] = 2
	b.arm_gen_boost(gen_cell, 3)
	var item_cell: Vector2i = b.empty_ground_cells()[0]
	b.place(item_cell, 101)
	b.set_collect_reward(item_cell, "exp", 4)
	ok(b.has_method("swap_gen_with_item"), "generator swap: model exposes a generator-item swap")
	if b.has_method("swap_gen_with_item"):
		ok(b.swap_gen_with_item(gen_cell, item_cell), "generator swap: generator trades places with an occupied item cell")
		ok(b.is_gen(item_cell) and b.gen_id_at(item_cell) == gen_id, "generator swap: generator lands on the item's old cell")
		ok(b.item_at(gen_cell) == 101 and not b.collect_reward_at(gen_cell).is_empty(), "generator swap: item and reward land on the generator's old cell")
		ok(b.gen_tier_at(item_cell) == 2 and b.gen_boost_at(item_cell) == 3, "generator swap: tier and boost travel with the generator")

	var live_gen_cell := item_cell if b.is_gen(item_cell) else gen_cell
	var other_cell: Vector2i = b.empty_ground_cells()[0]
	b.place_gen("gen_2", other_cell, 3)
	b.arm_gen_boost(other_cell, 5)
	ok(b.has_method("swap_gens"), "generator swap: model exposes a generator-generator swap")
	if b.has_method("swap_gens"):
		ok(b.swap_gens(live_gen_cell, other_cell), "generator swap: two non-matching generators trade cells")
		ok(b.gen_id_at(other_cell) == gen_id and b.gen_tier_at(other_cell) == 2 and b.gen_boost_at(other_cell) == 3, "generator swap: dragged generator state lands on the target cell")
		ok(b.gen_id_at(live_gen_cell) == "gen_2" and b.gen_tier_at(live_gen_cell) == 3 and b.gen_boost_at(live_gen_cell) == 5, "generator swap: target generator state lands on the source cell")
