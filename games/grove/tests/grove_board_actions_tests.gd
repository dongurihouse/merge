extends "res://games/grove/tests/grove_test_base.gd"
## grove · board actions — the PURE player-action layer (no scene). Proves a board action
## (deliver a quest) applies its whole state transition — consume the tile, drop the quest,
## advance exp, pay coins — as a headless call on BoardModel + Save, with NO Control / Tween /
## Board scene. This is the "change the rule, assert without UI validation" gate.

const BoardActions = preload("res://engine/scripts/core/board_actions.gd")
const BoardLogic = preload("res://engine/scripts/core/board_logic.gd")
const Mastery = preload("res://engine/scripts/core/mastery.gd")
const Improvements = preload("res://engine/scripts/core/improvements.gd")

func _initialize() -> void:
	begin("grove · board actions")
	_test_deliver_quest()
	_test_deliver_empty_quest_skips_recent()
	_test_per_generator_boost()
	_test_collect_coin()
	_test_collect_special()
	_test_produce_due_generators()
	_test_apply_recipe()
	_test_split_piece()
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
	Save.grove()["mastery"] = {"1": 19}
	Save.grove_write()

	var out: Dictionary = BoardActions.deliver_quest(board, quests, recent, 0, cell)

	ok(board.item_at(cell) == 0, "delivery consumed the asked tile")
	ok(quests.is_empty(), "delivery dropped the quest from the fence")
	ok(recent == [code], "delivery remembered the asked item (anti-monotony window)")
	ok(Save.coins() == coins_b + 3, "delivery paid the quest's coin reward")
	ok(Save.coins_earned_lifetime() == earned_b + 3, "delivery advanced the coin clock (organic earn)")
	ok(int(out.get("coins", -1)) == 3, "the outcome reports the coins for the render layer")
	ok(int(out.get("code", -1)) == code and Vector2i(out.get("cell", Vector2i(-1, -1))) == cell, "the outcome reports the consumed code + cell")
	ok(out.has("levels_up"), "the outcome reports levels gained (drives the Level dialog)")
	ok(Mastery.meter(1) == 20 and int((out.get("rank_ups", {}) as Dictionary).get(1, 0)) == 1,
		"delivery credits mastery and reports rank-ups to the render layer")

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
# move-carries / remove-clears / bag round-trip). Gated HERE (active suite) because the fuller
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
	b.place_gen(b.gen_id_at(a), c)
	b.arm_gen_boost(c, 5)
	ok(b.is_gen_boosted(a) and b.is_gen_boosted(c), "boost: two generators are boosted at once (stackable)")
	# move carries the taps; remove clears them
	var d: Vector2i = b.empty_ground_cells()[0]
	ok(b.move_gen(a, d) and b.gen_boost_at(d) == G.BOOST_TAPS - 1 and b.gen_boost_at(a) == 0, "boost: move carries the taps to the new cell")
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
	# 4. a returning line restores the kept boost saved by the farewell sweep, then consumes the keepsake.
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
	ok(returning.gen_id_at(rc) == "gen_4" and returning.gen_boost_at(rc) == 6,
		"the returning generator restores its kept boost from the legacy [tier, boost] keepsake")
	ok(not (Save.grove().get("gen_kept", {}) as Dictionary).has("gen_4"),
		"the keepsake is consumed after the generator returns")

# Recipe crafting is a composite board action: consume the source ingredient, replace the target with
# the authored special code at the shared tier, and credit mastery for the two base ingredients.
func _test_apply_recipe() -> void:
	fresh("apply_recipe")
	var b := BoardModel.new()
	for r in G.ROWS:
		for c in G.COLS:
			var cell := Vector2i(r, c)
			b.terrain[BoardModel.idx(cell)] = 0
			b.take(cell)
	var from := Vector2i(2, 2)
	var target := Vector2i(2, 3)
	b.place(from, 2 * 100 + 2)
	b.place(target, 3 * 100 + 2)
	Save.grove()["mastery"] = {"2": 19}
	Save.grove_write()
	var out: Dictionary = BoardActions.apply_recipe(b, from, target)
	ok(int(out.get("code", 0)) == 5 * 100 + 2, "apply_recipe produces the authored special at the shared tier")
	ok(b.item_at(from) == 0 and b.item_at(target) == 5 * 100 + 2, "apply_recipe consumes source and replaces target")
	ok(Mastery.meter(2) == 21 and Mastery.meter(3) == G.tier_clicks(2),
		"apply_recipe credits each base ingredient by the shared tier-click cost")
	ok(int((out.get("rank_ups", {}) as Dictionary).get(2, 0)) == 1,
		"apply_recipe reports rank-ups for the crafted ingredients")
	var refused := BoardActions.apply_recipe(b, target, Vector2i(1, 1))
	ok(refused.is_empty(), "apply_recipe refuses non-recipe pairs without mutating")

# Scissors consume one tool and split one eligible content piece into two one-tier-lower twins.
func _test_split_piece() -> void:
	fresh("split_piece")
	var b := BoardModel.new()
	for r in G.ROWS:
		for c in G.COLS:
			var cell := Vector2i(r, c)
			b.terrain[BoardModel.idx(cell)] = 0
			b.take(cell)
	var scissors := Vector2i(0, 0)
	var target := Vector2i(2, 2)
	b.place(scissors, G.SCISSORS_LINE * 100 + 1)
	b.place(target, 1 * 100 + 3)
	var out: Dictionary = BoardActions.split_piece(b, scissors, target)
	ok(Vector2i(out.get("twin_cell", Vector2i(-1, -1))) == Vector2i(1, 2),
		"split_piece chooses the nearest empty ground cell, tie-broken by board scan order")
	ok(b.item_at(scissors) == 0 and b.item_at(target) == 1 * 100 + 2
		and b.item_at(Vector2i(1, 2)) == 1 * 100 + 2,
		"split_piece consumes the scissors and leaves two one-tier-lower twins")
	ok(Mastery.meter(1) == 0, "splitting grants no mastery credit")

	var tier1 := BoardModel.new()
	for r in G.ROWS:
		for c in G.COLS:
			tier1.terrain[BoardModel.idx(Vector2i(r, c))] = 0
	tier1.place(scissors, G.SCISSORS_LINE * 100 + 1)
	tier1.place(target, 101)
	ok(BoardActions.split_piece(tier1, scissors, target).is_empty()
		and tier1.item_at(scissors) == G.SCISSORS_LINE * 100 + 1 and tier1.item_at(target) == 101,
		"split_piece refuses tier-1 targets with no loss")

	# A COMPLETELY FULL board still splits: consuming the scissors frees exactly the one cell the twin
	# needs, so the scissors' own cell is an eligible landing cell and the twin lands there.
	var full := BoardModel.new()
	for i in full.items.size():
		full.terrain[i] = 0
		full.items[i] = 101
	full.place(scissors, G.SCISSORS_LINE * 100 + 1)
	full.place(target, 104)
	var full_out: Dictionary = BoardActions.split_piece(full, scissors, target)
	ok(Vector2i(full_out.get("twin_cell", Vector2i(-1, -1))) == scissors
		and full.item_at(scissors) == 103 and full.item_at(target) == 103,
		"a full board splits into the cell the scissors itself frees (twin lands on the source cell)")

	# The freed cell is a LAST RESORT, never part of the nearest search: with even one far corner open,
	# the twin lands there and the cell the player dragged from still empties, exactly as before.
	var near := BoardModel.new()
	for i in near.items.size():
		near.terrain[i] = 0
		near.items[i] = 101
	var adjacent := Vector2i(2, 1)                       # the scissors sits NEXT TO the target
	near.place(adjacent, G.SCISSORS_LINE * 100 + 1)
	near.place(target, 104)
	var far := Vector2i(G.ROWS - 1, G.COLS - 1)
	near.take(far)                                       # one far corner left open
	var near_out: Dictionary = BoardActions.split_piece(near, adjacent, target)
	ok(Vector2i(near_out.get("twin_cell", Vector2i(-1, -1))) == far
		and near.item_at(far) == 103 and near.item_at(adjacent) == 0,
		"any other free cell still wins — the freed source cell is only the last-resort landing cell")

	# ...but a full board that frees NO cell still refuses with no loss: a scissors on a SEALED cell
	# leaves no open ground behind, so the twin has nowhere to land.
	var sealed := BoardModel.new()
	for i in sealed.items.size():
		sealed.terrain[i] = 0
		sealed.items[i] = 101
	sealed.place(scissors, G.SCISSORS_LINE * 100 + 1)
	sealed.place(target, 104)
	sealed.terrain[BoardModel.idx(scissors)] = 1         # the source cell is not open ground
	ok(BoardActions.split_piece(sealed, scissors, target).is_empty()
		and sealed.item_at(scissors) == G.SCISSORS_LINE * 100 + 1 and sealed.item_at(target) == 104,
		"a full board whose source cell frees no open ground still refuses before consuming anything")

	# A full board with no scissors in the drag frees nothing either — the plain drag still refuses.
	var full_plain := BoardModel.new()
	for i in full_plain.items.size():
		full_plain.terrain[i] = 0
		full_plain.items[i] = 101
	full_plain.place(scissors, 102)
	full_plain.place(target, 104)
	ok(BoardActions.split_piece(full_plain, scissors, target).is_empty()
		and full_plain.item_at(scissors) == 102 and full_plain.item_at(target) == 104,
		"a full board refuses a non-scissors drag — only the scissors frees its own cell")

	var growing := BoardModel.new()
	for i in growing.items.size():
		growing.terrain[i] = 0
		growing.items[i] = 0
	growing.place(scissors, G.SCISSORS_LINE * 100 + 1)
	ok(growing.build_improvement(target, Improvements.KIND_SOIL), "fixture installs Soil under the split target")
	growing.place(target, 107)
	var grow_row: Dictionary = growing.improvement_at(target)
	grow_row["code"] = 107
	grow_row["ends_at"] = Time.get_unix_time_from_system() + 3600.0
	growing.improvements[target] = grow_row
	ok(growing.is_growing(target), "fixture starts the target as a t7+ growing piece")
	var growing_out: Dictionary = BoardActions.split_piece(growing, scissors, target)
	ok(Vector2i(growing_out.get("target", Vector2i(-1, -1))) == target
		and growing.item_at(target) == 106 and not growing.is_growing(target)
		and int(growing.improvement_at(target).get("code", -1)) == 0,
		"split_piece resets the consumed target's stale Soil grow row after a confirmed split")

	# Every other refusal still holds on a FULL board, where the freed cell now exists: tier-1 targets,
	# coins, treat lines and from == target all refuse with no loss (the scissors survives every one).
	var full_t1 := BoardModel.new()
	for i in full_t1.items.size():
		full_t1.terrain[i] = 0
		full_t1.items[i] = 101
	full_t1.place(scissors, G.SCISSORS_LINE * 100 + 1)
	ok(BoardActions.split_piece(full_t1, scissors, target).is_empty()
		and full_t1.item_at(scissors) == G.SCISSORS_LINE * 100 + 1 and full_t1.item_at(target) == 101,
		"a full board still refuses a tier-1 target with no loss")
	full_t1.place(target, G.COIN_LINE * 100 + 2)
	ok(BoardActions.split_piece(full_t1, scissors, target).is_empty()
		and full_t1.item_at(scissors) == G.SCISSORS_LINE * 100 + 1,
		"a full board still refuses coins with no loss")
	full_t1.place(target, 71 * 100 + 2)
	ok(BoardActions.split_piece(full_t1, scissors, target).is_empty()
		and full_t1.item_at(scissors) == G.SCISSORS_LINE * 100 + 1,
		"a full board still refuses treat lines with no loss")
	ok(BoardActions.split_piece(full_t1, scissors, scissors).is_empty()
		and full_t1.item_at(scissors) == G.SCISSORS_LINE * 100 + 1,
		"a full board still refuses from == target with no loss")

	var invalid := BoardModel.new()
	for r in G.ROWS:
		for c in G.COLS:
			invalid.terrain[BoardModel.idx(Vector2i(r, c))] = 0
			invalid.take(Vector2i(r, c))
	invalid.place(scissors, G.SCISSORS_LINE * 100 + 1)
	invalid.place(target, G.COIN_LINE * 100 + 2)
	ok(BoardActions.split_piece(invalid, scissors, target).is_empty(), "split_piece refuses coins")
	invalid.place(target, 71 * 100 + 2)
	ok(BoardActions.split_piece(invalid, scissors, target).is_empty(), "split_piece refuses treat lines")
	invalid.take(target)
	invalid.place_gen("gen_1", target)
	ok(BoardActions.split_piece(invalid, scissors, target).is_empty(), "split_piece refuses generators")

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
	b.place_gen("gen_2", cells[0])
	b.arm_gen_boost(cells[0], 5)
	b.place_gen("gen_4", cells[1])
	b.place(cells[2], 2 * 100 + 2)
	b.place(cells[3], 4 * 100 + 3)
	b.place(cells[4], 8 * 100 + 1)
	b.place(cells[5], 16 * 100 + 2)             # currently needed at L65 — must survive
	b.gen_bag = ["gen_2", "gen_4"]
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
		and b.gen_bag_boost == [9, 0],
		"sweep touches board generators but leaves the generator bag untouched")
	var kept: Dictionary = Save.grove().get("gen_kept", {})
	ok(kept.get("gen_2", []) == [5], "a swept boosted board generator writes gen_kept [boost]")
	fresh("farewell_kept_merge_max")
	var weaker := BoardModel.new()
	for i in weaker.items.size():
		weaker.terrain[i] = 0
		weaker.items[i] = 0
	weaker.place_gen("gen_2", Vector2i(0, 0))
	weaker.arm_gen_boost(Vector2i(0, 0), 9)
	Save.grove()["gen_kept"] = {"gen_2": [3, 1]}
	Save.grove_write()
	BoardActions.sweep_line(weaker, 2)
	ok((Save.grove().get("gen_kept", {}) as Dictionary).get("gen_2", []) == [9],
		"a second farewell upgrades an old [tier, boost] keepsake to the strongest boost")
	var equal := BoardModel.new()
	for i in equal.items.size():
		equal.terrain[i] = 0
		equal.items[i] = 0
	equal.place_gen("gen_2", Vector2i(0, 0))
	equal.arm_gen_boost(Vector2i(0, 0), 9)
	Save.grove()["gen_kept"] = {"gen_2": [1]}
	Save.grove_write()
	BoardActions.sweep_line(equal, 2)
	ok((Save.grove().get("gen_kept", {}) as Dictionary).get("gen_2", []) == [9],
		"a farewell keeps the stronger boost taps in the banked generator keepsake")
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

# Generators are movable board pieces: besides empty-ground moves, they can trade cells with a regular item
# or another generator without dropping boost state.
func _test_generator_swaps() -> void:
	fresh("generator_swaps")
	var b := BoardModel.new(); b.seed_gens(0)
	var gen_cell: Vector2i = b.gens.keys()[0]
	var gen_id := b.gen_id_at(gen_cell)
	b.arm_gen_boost(gen_cell, 3)
	var item_cell: Vector2i = b.empty_ground_cells()[0]
	b.place(item_cell, 101)
	b.set_collect_reward(item_cell, "exp", 4)
	ok(b.has_method("swap_gen_with_item"), "generator swap: model exposes a generator-item swap")
	if b.has_method("swap_gen_with_item"):
		ok(b.swap_gen_with_item(gen_cell, item_cell), "generator swap: generator trades places with an occupied item cell")
		ok(b.is_gen(item_cell) and b.gen_id_at(item_cell) == gen_id, "generator swap: generator lands on the item's old cell")
		ok(b.item_at(gen_cell) == 101 and not b.collect_reward_at(gen_cell).is_empty(), "generator swap: item and reward land on the generator's old cell")
		ok(b.gen_boost_at(item_cell) == 3, "generator swap: boost travels with the generator")

	var live_gen_cell := item_cell if b.is_gen(item_cell) else gen_cell
	var other_cell: Vector2i = b.empty_ground_cells()[0]
	b.place_gen("gen_2", other_cell)
	b.arm_gen_boost(other_cell, 5)
	ok(b.has_method("swap_gens"), "generator swap: model exposes a generator-generator swap")
	if b.has_method("swap_gens"):
		ok(b.swap_gens(live_gen_cell, other_cell), "generator swap: two non-matching generators trade cells")
		ok(b.gen_id_at(other_cell) == gen_id and b.gen_boost_at(other_cell) == 3, "generator swap: dragged generator state lands on the target cell")
		ok(b.gen_id_at(live_gen_cell) == "gen_2" and b.gen_boost_at(live_gen_cell) == 5, "generator swap: target generator state lands on the source cell")
