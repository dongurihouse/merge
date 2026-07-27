extends "res://engine/tests/test_base.gd"
## Cell improvements: pure rule, BoardModel, and board-action coverage for Soil + Magnet.
##   godot --headless --path . -s res://engine/tests/improvements_tests.gd

const G = preload("res://engine/scripts/core/content.gd")
const BoardModel = preload("res://engine/scripts/core/board_model.gd")
const BoardLogic = preload("res://engine/scripts/core/board_logic.gd")
const BoardActions = preload("res://engine/scripts/core/board_actions.gd")
const Improvements = preload("res://engine/scripts/core/improvements.gd")
const Quests = preload("res://engine/scripts/core/quests.gd")
const Save = preload("res://engine/scripts/core/save.gd")

func save_prefix() -> String:
	return "tu_improvements_"

func _clear_board(board: BoardModel) -> void:
	board.gens = {}
	board.gen_tiers = {}
	board.gen_boost = {}
	board.collect_rewards = {}
	board.improvements = {}
	for i in board.items.size():
		board.terrain[i] = 0
		board.items[i] = 0

func _cells(n: int) -> Array:
	var out: Array = []
	for r in G.ROWS:
		for c in G.COLS:
			out.append(Vector2i(r, c))
			if out.size() >= n:
				return out
	return out

func _initialize() -> void:
	_test_core_prices_curve_and_eligibility()
	_test_board_model_persists_improvements()
	_test_soil_reconcile_water_and_completion()
	_test_build_move_demolish_and_generator_skip()
	_test_range_pairs_and_magnet_guards()
	finish()

func _test_core_prices_curve_and_eligibility() -> void:
	ok(Improvements.soil_build_price(0) == 0 and Improvements.soil_build_price(2) == 0, "soil builds 1-3 are free")
	ok(Improvements.soil_build_price(3) == 500 and Improvements.soil_build_price(8) == 16000, "soil paid ladder is keyed by current count")
	ok(Improvements.soil_build_price(9) < 0, "soil price refuses the cap slot")
	ok(Improvements.magnet_build_price(0) == 25 and Improvements.magnet_build_price(2) == 100, "magnet build ladder is acorn-priced")
	ok(Improvements.magnet_build_price(3) < 0, "magnet price refuses the cap slot")
	ok(Improvements.soil_rank_price(1) == 600 and Improvements.soil_rank_price(2) == 1500 and Improvements.soil_rank_price(3) < 0, "soil rank prices cover r2/r3 only")
	ok(Improvements.soil_step_seconds(101, 1) == 10.0, "soil tier-1 step takes 10 seconds")
	ok(Improvements.soil_step_seconds(107, 2) == 10080.0, "rank-2 soil applies the 30 percent time discount")
	ok(Improvements.finish_cost(1.0) == 1 and Improvements.finish_cost(3600.0) == 2 and Improvements.finish_cost(172800.0) == 96, "finish cost is one acorn per started 30 minutes")
	ok(Improvements.is_soil_eligible(101), "ordinary tiered content below merge_top can grow on soil")
	ok(not Improvements.is_soil_eligible(100 + G.TOP_TIER), "top-tier content does not grow")
	ok(not Improvements.is_soil_eligible(G.COIN_LINE * 100 + 1), "coins do not grow on soil")
	ok(not Improvements.is_soil_eligible(13 * 100 + 1), "collectable special drops do not grow on soil")

func _test_board_model_persists_improvements() -> void:
	var b := BoardModel.new()
	_clear_board(b)
	var cell := Vector2i(3, 3)
	ok(b.build_improvement(cell, Improvements.KIND_SOIL), "soil builds on open empty ground")
	var row := b.improvement_at(cell)
	row["rank"] = 2
	row["code"] = 104
	row["ends_at"] = 1234.0
	row["watered"] = true
	b.improvements[cell] = row
	var b2 := BoardModel.new()
	b2.from_dict(b.to_dict())
	var got := b2.improvement_at(cell)
	ok(String(got.kind) == Improvements.KIND_SOIL and int(got.rank) == 2 and int(got.code) == 104 and bool(got.watered), "improvement rows round-trip through board dict")
	var blob := b.to_dict()
	blob["improvements"] = [[99, 99, Improvements.KIND_SOIL, 1, 101, 10.0, false], [1, 1, "bogus", 1, 101, 10.0, false]]
	var changed := b2.from_dict(blob)
	ok(changed and b2.improvements.is_empty(), "from_dict drops invalid improvement rows and reports a repair")

func _test_soil_reconcile_water_and_completion() -> void:
	var b := BoardModel.new()
	_clear_board(b)
	var cell := Vector2i(2, 2)
	b.build_improvement(cell, Improvements.KIND_SOIL)
	b.place(cell, 101)
	b.reconcile_improvements(1000.0)
	var a := b.improvement_at(cell)
	ok(int(a.code) == 101 and float(a.ends_at) == 1010.0 and not bool(a.watered), "arriving on soil starts a fresh tier clock")
	b.reconcile_improvements(1003.0)
	ok(float(b.improvement_at(cell).ends_at) == 1010.0, "same occupant keeps the existing clock")
	ok(b.apply_water_to_soil(cell, 1004.0), "watering applies once to a running soil step")
	var watered := b.improvement_at(cell)
	ok(bool(watered.watered) and float(watered.ends_at) == 1007.0, "watering halves the remaining time once")
	ok(not b.apply_water_to_soil(cell, 1005.0), "a soil step cannot be watered twice")
	fresh("finish_noop")
	Save.add_diamonds(5)
	var diamonds_before := Save.diamonds()
	ok(not BoardActions.finish_soil(b, Vector2i(0, 0), 1005.0).finished and Save.diamonds() == diamonds_before, "finishing a non-growing soil cell never spends acorns")
	b.reconcile_improvements(1008.0)
	var done := b.improvement_at(cell)
	ok(b.item_at(cell) == 102 and int(done.code) == 102 and float(done.ends_at) > 1008.0 and not bool(done.watered), "completion grows the piece and starts the next step")
	b.place(cell, 103)
	b.reconcile_improvements(2000.0)
	var replaced := b.improvement_at(cell)
	ok(int(replaced.code) == 103 and not bool(replaced.watered) and float(replaced.ends_at) == 2180.0, "replacing the occupant restarts the clock and clears watered")
	b.take(cell)
	b.reconcile_improvements(2200.0)
	var empty := b.improvement_at(cell)
	ok(int(empty.code) == 0 and float(empty.ends_at) == 0.0 and not bool(empty.watered), "empty soil clears activity")

	var r3 := Vector2i(2, 3)
	b.build_improvement(r3, Improvements.KIND_SOIL)
	var r3row := b.improvement_at(r3)
	r3row["rank"] = 3
	r3row["code"] = 106
	r3row["ends_at"] = 3000.0
	b.improvements[r3] = r3row
	b.place(r3, 106)
	b.reconcile_improvements(3001.0)
	ok(b.item_at(r3) == 108, "rank-3 soil grows two tiers per completion")

func _test_build_move_demolish_and_generator_skip() -> void:
	fresh("build_actions")
	Save.add_coins(10000)
	Save.add_diamonds(500)
	var b := BoardModel.new()
	_clear_board(b)
	var cs := _cells(16)
	var coins_b := Save.coins()
	ok(BoardActions.build_improvement(b, cs[0], Improvements.KIND_SOIL).built, "first soil build succeeds")
	ok(BoardActions.build_improvement(b, cs[1], Improvements.KIND_SOIL).built, "second soil build succeeds")
	ok(BoardActions.build_improvement(b, cs[2], Improvements.KIND_SOIL).built, "third soil build succeeds")
	ok(Save.coins() == coins_b, "the first three soil builds are free")
	ok(BoardActions.build_improvement(b, cs[3], Improvements.KIND_SOIL).built and Save.coins() == coins_b - 500, "the fourth soil charges the first coin price")
	var dia_b := Save.diamonds()
	ok(BoardActions.build_improvement(b, cs[4], Improvements.KIND_MAGNET).built and Save.diamonds() == dia_b - 25, "magnet build spends acorns")
	Save.add_coins(100000)
	for i in range(5, 13):
		BoardActions.build_improvement(b, cs[i], Improvements.KIND_SOIL)
	ok(not BoardActions.build_improvement(b, cs[13], Improvements.KIND_SOIL).built, "soil refuses builds above the cap")
	var src: Vector2i = cs[0]
	var dst: Vector2i = cs[14]
	var moving := b.improvement_at(src)
	moving["rank"] = 3
	moving["code"] = 107
	moving["ends_at"] = 9999.0
	b.improvements[src] = moving
	var before_move := Save.coins()
	ok(BoardActions.move_improvement(b, src, dst).moved and Save.coins() == before_move - G.IMPROVEMENT_MOVE_COST, "moving an improvement charges the flat coin fee")
	var moved := b.improvement_at(dst)
	ok(not b.improvements.has(src) and int(moved.rank) == 3 and int(moved.code) == 0 and float(moved.ends_at) == 0.0, "move carries soil rank but clears the running clock")
	var before_demo := Save.coins()
	ok(BoardActions.demolish_improvement(b, dst).demolished and Save.coins() == before_demo, "demolish is free and gives no refund")
	Save.add_coins(50000)
	var before_rebuild := Save.coins()
	ok(BoardActions.build_improvement(b, dst, Improvements.KIND_SOIL).built and Save.coins() == before_rebuild - 16000, "rebuilding after demolish pays the current count slot again")

	var auto := BoardModel.new()
	_clear_board(auto)
	for i in auto.items.size():
		auto.items[i] = 101
	var only := Vector2i(4, 4)
	auto.items[BoardModel.idx(only)] = 0
	auto.build_improvement(only, Improvements.KIND_SOIL)
	var due := BoardActions.produce_due_generators(auto, [])
	ok(due.bagged.size() == 1 and due.landed.is_empty(), "automatic due-generator placement skips the only improved empty cell")

func _test_range_pairs_and_magnet_guards() -> void:
	var b := BoardModel.new()
	_clear_board(b)
	var magnet := Vector2i(4, 4)
	var a := Vector2i(3, 3)
	var c := Vector2i(4, 5)
	b.build_improvement(magnet, Improvements.KIND_MAGNET)
	b.place(a, 101)
	b.place(c, 101)
	ok(BoardLogic.range_pairs(b, Improvements.range_cells(b, magnet)) == [[a, c]], "range_pairs returns a known-positive 3x3 pair")
	ok(BoardLogic.range_pairs(b, [a]).is_empty(), "range_pairs returns no pair when the range has only one matching piece")
	var o1 := Vector2i(3, 4)
	var o2 := Vector2i(4, 3)
	b.place(o1, 102)
	b.place(o2, 102)
	ok(BoardLogic.range_pairs(b, Improvements.range_cells(b, magnet))[0] == [a, c], "range_pairs orders lower tiers before higher tiers")
	var asked := Quests.asked_codes([{"line": 1, "tier": 1, "reward": {"coins": 1}}, {"line": 1, "tier": 2, "reward": {"coins": 1}}])
	ok(not BoardActions.magnet_merge_once(b, magnet, asked, [], Vector2i(-1, -1)).merged, "magnet refuses quest-asked codes")
	ok(not BoardActions.magnet_merge_once(b, magnet, {}, [], a).merged, "magnet holds fire while a chain is armed")
	b.build_improvement(a, Improvements.KIND_SOIL)
	var row := b.improvement_at(a)
	row["code"] = 101
	row["ends_at"] = 9999.0
	b.improvements[a] = row
	ok(not BoardActions.magnet_merge_once(b, magnet, {}, [a, o1, o2], Vector2i(-1, -1)).merged, "magnet refuses a piece that is growing on soil")
	b.improvements.erase(a)
	var out := BoardActions.magnet_merge_once(b, magnet, {}, [], Vector2i(-1, -1))
	ok(out.merged and b.item_at(c) == 102 and b.item_at(a) == 0, "magnet merges to the pair cell nearer the magnet")
