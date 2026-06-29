extends "res://games/grove/tests/grove_test_base.gd"
## grove · board actions — the PURE player-action layer (no scene). Proves a board action
## (deliver a quest) applies its whole state transition — consume the tile, drop the quest,
## advance exp, pay coins — as a headless call on BoardModel + Save, with NO Control / Tween /
## Board scene. This is the "change the rule, assert without UI validation" gate.

const BoardActions = preload("res://engine/scripts/core/board_actions.gd")

func _initialize() -> void:
	begin("grove · board actions")
	_test_deliver_quest()
	_test_deliver_empty_quest_skips_recent()
	_test_per_generator_boost()
	_test_collect_coin()
	_test_collect_special()
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

	var quests: Array = [{"line": 1, "tier": 1, "reward": {"exp": 7, "coins": 3}}]
	var recent: Array = []
	var exp_b := Save.exp_total()
	var coins_b := Save.coins()

	var out: Dictionary = BoardActions.deliver_quest(board, quests, recent, 0, cell)

	ok(board.item_at(cell) == 0, "delivery consumed the asked tile")
	ok(quests.is_empty(), "delivery dropped the quest from the fence")
	ok(recent == [code], "delivery remembered the asked item (anti-monotony window)")
	ok(Save.exp_total() == exp_b + 7, "delivery advanced exp by the quest's exp")
	ok(Save.coins() == coins_b + 3, "delivery paid the quest's coin reward")
	ok(int(out.get("exp", -1)) == 7 and int(out.get("coins", -1)) == 3, "the outcome reports exp + coins for the render layer")
	ok(int(out.get("code", -1)) == code and Vector2i(out.get("cell", Vector2i(-1, -1))) == cell, "the outcome reports the consumed code + cell")
	ok(out.has("levels_up"), "the outcome reports levels gained (drives the Level dialog)")

# A quest with NO item (a stale/empty ask) still pays out, but does NOT push onto the recent-item
# window — there is no asked code to steer future quests away from.
func _test_deliver_empty_quest_skips_recent() -> void:
	fresh("deliver_empty")
	var board := BoardModel.new()
	var quests: Array = [{"reward": {"exp": 2, "coins": 0}}]   # no line/tier → quest_item is empty
	var recent: Array = []
	var exp_b := Save.exp_total()
	var out: Dictionary = BoardActions.deliver_quest(board, quests, recent, 0, Vector2i(0, 0))
	ok(quests.is_empty(), "an empty-item quest still leaves the fence")
	ok(recent.is_empty(), "an empty-item quest does NOT touch the recent-item window")
	ok(Save.exp_total() == exp_b + 2, "an empty-item quest still pays its exp")
	ok(int(out.get("coins", -1)) == 0, "a zero-coin quest reports 0 coins")

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

# §6.B collect a special drop (water / acorn / exp). exp+acorn write Save directly; water is RETURNED
# for the caller to fold into its live water mirror (a scene field, not Save). The tile always leaves.
func _test_collect_special() -> void:
	fresh("collect_special")
	var board := BoardModel.new()
	var special := 13 * 100 + 1
	# exp special → Save.add_exp
	var c1 := Vector2i(1, 1)
	board.place(c1, special)
	board.set_collect_reward(c1, "exp", 5)
	var exp_b := Save.exp_total()
	var o1: Dictionary = BoardActions.collect_special(board, c1)
	ok(board.item_at(c1) == 0, "collecting a special removes it from the board")
	ok(String(o1.get("kind", "")) == "exp" and int(o1.get("amount", -1)) == 5, "collect_special reports kind + amount")
	ok(Save.exp_total() == exp_b + 5, "an exp special credits exp")
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
