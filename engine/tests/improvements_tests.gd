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
	board.gen_boost = {}
	board.collect_rewards = {}
	board.improvements = {}
	board.seed_ranks = {}
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
	_test_seed_rules_drop_filter_and_eligibility()
	_test_board_model_persists_improvements()
	_test_soil_reconcile_water_and_completion()
	_test_place_seed_unsocket_and_generator_skip()
	_test_range_pairs_and_magnet_guards()
	finish()

func _test_seed_rules_drop_filter_and_eligibility() -> void:
	ok(Improvements.seed_code_for_kind(Improvements.KIND_SOIL) == 2901, "soil seed is line 29 tier 1")
	ok(Improvements.seed_code_for_kind(Improvements.KIND_MAGNET) == 3001, "magnet seed is line 30 tier 1")
	ok(Improvements.kind_for_seed(2901) == Improvements.KIND_SOIL and Improvements.kind_for_seed(3001) == Improvements.KIND_MAGNET, "seed codes map back to improvement kinds")
	ok(Improvements.seed_sell_reward(Improvements.KIND_SOIL) == Vector2i(250, 0), "soil seed sells for 250 coins")
	ok(Improvements.seed_sell_reward(Improvements.KIND_MAGNET) == Vector2i(1000, 0), "magnet seed sells for 1000 coins")
	ok(Improvements.unsocket_price(Improvements.KIND_SOIL) == Vector2i(100, 0), "soil unsocket costs 100 coins")
	ok(Improvements.unsocket_price(Improvements.KIND_MAGNET) == Vector2i(0, 10), "magnet unsocket keeps the 10-acorn cost")
	ok(Improvements.soil_rank_price(1) == 600 and Improvements.soil_rank_price(2) == 1500 and Improvements.soil_rank_price(3) < 0, "soil rank prices cover r2/r3 only")
	ok(Improvements.soil_step_seconds(101, 1) == 10.0, "soil tier-1 step takes 10 seconds")
	ok(Improvements.soil_step_seconds(107, 2) == 10080.0, "rank-2 soil applies the 30 percent time discount")
	ok(Improvements.is_soil_eligible(101), "ordinary tiered content below merge_top can grow on soil")
	ok(not Improvements.is_soil_eligible(100 + G.TOP_TIER), "top-tier content does not grow")
	ok(not Improvements.is_soil_eligible(G.COIN_LINE * 100 + 1), "coins do not grow on soil")
	ok(not Improvements.is_soil_eligible(13 * 100 + 1), "collectable special drops do not grow on soil")
	ok(not Improvements.is_soil_eligible(Improvements.seed_code_for_kind(Improvements.KIND_SOIL)), "improvement seeds do not grow on soil")
	var b := BoardModel.new()
	_clear_board(b)
	b.place(Vector2i(2, 2), Improvements.seed_code_for_kind(Improvements.KIND_SOIL))
	for cell in _cells(G.MAGNET_MAX):
		b.build_improvement(cell, Improvements.KIND_MAGNET)
	var blocked := Improvements.blocked_seed_drop_lines(b, [Improvements.seed_code_for_kind(Improvements.KIND_SOIL)])
	ok(blocked.has(int(G.SOIL_SEED_LINE)) and blocked.has(int(G.MAGNET_SEED_LINE)), "drop filter blocks a kind that is already unplaced or at placed cap")
	var rng_a := RandomNumberGenerator.new()
	var rng_b := RandomNumberGenerator.new()
	rng_a.seed = 77
	rng_b.seed = 77
	var drop := G.pick_special_drop(rng_a, blocked)
	var fallback := G.pick_special_drop(rng_b, [int(G.SOIL_SEED_LINE), int(G.MAGNET_SEED_LINE)])
	ok(drop == fallback and rng_a.state == rng_b.state, "filtered special-drop pick still makes exactly one random draw")

func _test_board_model_persists_improvements() -> void:
	var b := BoardModel.new()
	_clear_board(b)
	var cell := Vector2i(3, 3)
	ok(b.build_improvement(cell, Improvements.KIND_SOIL), "test setup can still install a soil row directly")
	var row := b.improvement_at(cell)
	row["rank"] = 2
	row["code"] = 104
	row["ends_at"] = 1234.0
	row["watered"] = true
	b.improvements[cell] = row
	var seed_cell := Vector2i(4, 4)
	b.place(seed_cell, Improvements.seed_code_for_kind(Improvements.KIND_SOIL))
	b.set_seed_rank(seed_cell, 3)
	var b2 := BoardModel.new()
	b2.from_dict(b.to_dict())
	var got := b2.improvement_at(cell)
	ok(String(got.kind) == Improvements.KIND_SOIL and int(got.rank) == 2 and int(got.code) == 104 and bool(got.watered), "improvement rows round-trip through board dict")
	ok(b2.item_at(seed_cell) == Improvements.seed_code_for_kind(Improvements.KIND_SOIL) and b2.seed_rank_at(seed_cell) == 3, "ranked seed metadata round-trips with the board item")
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
	fresh("soil_actions_free_of_acorns")
	Save.add_diamonds(5)
	var diamonds_before := Save.diamonds()
	ok(not BoardActions.water_soil(b, Vector2i(0, 0), 1005.0).watered and Save.diamonds() == diamonds_before, "a soil action on a non-growing cell is inert, and no soil action spends acorns")
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

func _test_place_seed_unsocket_and_generator_skip() -> void:
	fresh("seed_actions")
	Save.add_coins(10000)
	Save.add_diamonds(500)
	var b := BoardModel.new()
	_clear_board(b)
	var cell := Vector2i(3, 3)
	b.place(cell, Improvements.seed_code_for_kind(Improvements.KIND_SOIL))
	b.set_seed_rank(cell, 3)
	var coins_b := Save.coins()
	ok(BoardActions.place_seed(b, cell).placed, "placing a soil seed consumes the seed in its own cell")
	var placed := b.improvement_at(cell)
	ok(b.item_at(cell) == 0 and String(placed.kind) == Improvements.KIND_SOIL and int(placed.rank) == 3 and Save.coins() == coins_b, "seed placement is free and carries Soil rank metadata")
	b.place(cell, 101)
	ok(not BoardActions.unsocket_improvement(b, cell).unsocketed, "unsocket refuses an occupied improved cell")
	b.take(cell)
	var before_unsocket := Save.coins()
	var unsocket := BoardActions.unsocket_improvement(b, cell)
	ok(unsocket.unsocketed and Save.coins() == before_unsocket - 100, "unsocketing soil charges coins")
	ok(not b.has_improvement(cell) and b.item_at(cell) == Improvements.seed_code_for_kind(Improvements.KIND_SOIL) and b.seed_rank_at(cell) == 3, "unsocket leaves a ranked seed in the same cell")
	ok(BoardActions.place_seed(b, cell).placed and int(b.improvement_at(cell).rank) == 3, "a returned Soil seed places again at the carried rank")

	var magnet := Vector2i(3, 4)
	b.place(magnet, Improvements.seed_code_for_kind(Improvements.KIND_MAGNET))
	ok(BoardActions.place_seed(b, magnet).placed, "placing a magnet seed consumes the seed")
	var diamonds_b := Save.diamonds()
	ok(BoardActions.unsocket_improvement(b, magnet).unsocketed and Save.diamonds() == diamonds_b - 10, "unsocketing magnet charges acorns")
	ok(b.item_at(magnet) == Improvements.seed_code_for_kind(Improvements.KIND_MAGNET), "magnet unsocket leaves a magnet seed")

	var sealed := Vector2i(0, 0)
	b.terrain[BoardModel.idx(sealed)] = 1
	b.place(sealed, Improvements.seed_code_for_kind(Improvements.KIND_SOIL))
	ok(not BoardActions.place_seed(b, sealed).placed and b.item_at(sealed) == Improvements.seed_code_for_kind(Improvements.KIND_SOIL), "placing refuses a sealed cell and keeps the seed")

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
