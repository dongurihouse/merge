extends "res://engine/tests/test_base.gd"
## Headless tests for generator mastery: the save-backed meter, rank window math,
## credit whitelist, and scissors economy guard.

const G = preload("res://engine/scripts/core/content.gd")
const Save = preload("res://engine/scripts/core/save.gd")
const Mastery = preload("res://engine/scripts/core/mastery.gd")

func save_prefix() -> String:
	return "tu_mastery_"

func _initialize() -> void:
	print("== Mastery tests ==")
	_test_thresholds_and_windows()
	_test_ask_band_and_sliding()
	_test_pop_cost()
	_test_credit_math()
	_test_scissors_price_floor()
	finish()

func _set_meter(line: int, amount: int) -> void:
	var g := Save.grove()
	if not g.has("mastery"):
		g["mastery"] = {}
	g["mastery"][str(line)] = amount
	Save.grove_write()

func _sum(arr: Array) -> float:
	var total := 0.0
	for v in arr:
		total += float(v)
	return total

func _test_thresholds_and_windows() -> void:
	fresh("thresholds")
	ok(G.MASTERY_THRESHOLDS == [20, 60, 150, 350, 800, 1700, 3400, 6500],
		"mastery thresholds match the step-2 ladder")
	var monotone := true
	var prev := -1
	for threshold in G.MASTERY_THRESHOLDS:
		monotone = monotone and int(threshold) > prev
		prev = int(threshold)
	ok(monotone, "mastery thresholds are strictly increasing")
	ok(absf(_sum(G.MASTERY_TIER_ODDS_5) - 1.0) < 0.0001,
		"the rank-odd five-tier odds sum to 1")
	ok(float(G.MASTERY_TIER_ODDS_5[0]) > float(G.MASTERY_TIER_ODDS_5[1])
		and float(G.MASTERY_TIER_ODDS_5[1]) > float(G.MASTERY_TIER_ODDS_5[2])
		and float(G.MASTERY_TIER_ODDS_5[2]) >= float(G.MASTERY_TIER_ODDS_5[3])
		and float(G.MASTERY_TIER_ODDS_5[3]) > float(G.MASTERY_TIER_ODDS_5[4]),
		"the five-tier odds decay toward the high end")
	var expected := [
		Vector2i(1, 4), Vector2i(1, 5), Vector2i(2, 5),
		Vector2i(2, 6), Vector2i(3, 6), Vector2i(3, 7),
		Vector2i(4, 7), Vector2i(4, 8), Vector2i(5, 8),
	]
	var windows_ok := true
	for r in expected.size():
		windows_ok = windows_ok and Mastery.tier_window_for_rank(r) == expected[r]
	ok(windows_ok, "closed-form mastery windows reproduce the design table")
	ok(Mastery.rank_for_meter(0) == 0 and Mastery.rank_for_meter(19) == 0
		and Mastery.rank_for_meter(20) == 1 and Mastery.rank_for_meter(6500) == 8
		and Mastery.rank_for_meter(999999) == 8,
		"rank derives from the meter and caps at the last threshold")

func _test_ask_band_and_sliding() -> void:
	fresh("ask_band")
	var quests: Array = [
		{"line": 1, "tier": 6, "reward": {"coins": 1}},
		{"line": 5, "tier": 8, "reward": {"coins": 1}},
		{"asks": [{"line": 1, "tier": 4, "count": 1}], "reward": {"coins": 1}},
		{"line": 2, "tier": 7, "reward": {"coins": 1}},
	]
	ok(Mastery.ask_band(1, quests) == 6, "ask_band reads only the line's own live asks")
	ok(Mastery.ask_band(2, quests) == 7, "ask_band keeps a separate band per base line")
	ok(Mastery.ask_band(3, [{"line": 5, "tier": 9}]) == 0,
		"ask_band does not treat a special ask as an ingredient ask")
	_set_meter(1, 350)                         # rank 4: natural window t3-t6
	ok(Mastery.window(1, [{"line": 1, "tier": 2}]) == Vector2i(1, 4),
		"a low own ask slides the shape down without changing width")
	ok(Mastery.window(1, []) == Vector2i(3, 6),
		"without own asks the ranked line keeps its unclamped window")
	_set_meter(1, 6500)                        # rank 8: t5-t8
	ok(Mastery.window(1, [{"line": 1, "tier": 8}]) == Vector2i(5, 8),
		"high reach asks never clamp a rank's natural window down")

## The §3 tier-scaled pop cost. Two properties carry the economy: rank 0 pays exactly POP_COST
## (unmastered play unchanged, and the sim's I2 baseline with it), and no rank ever pays MORE water
## than the tier-1 clicks its window floor is worth (that would make mastery a punishment).
func _test_pop_cost() -> void:
	fresh("pop_cost")
	ok(int(G.POP_COST_BY_TIER_LOW[0]) == G.POP_COST and G.pop_cost(1) == G.POP_COST,
		"a rank-0 window low costs exactly POP_COST")
	var monotone := true
	var never_above_value := true
	for i in G.POP_COST_BY_TIER_LOW.size():
		var lo := i + 1
		var cost := G.pop_cost(lo)
		monotone = monotone and cost >= G.pop_cost(maxi(1, lo - 1))
		never_above_value = never_above_value and cost <= G.tier_clicks(lo)
	ok(monotone, "the pop-cost curve never falls as the window low rises")
	ok(never_above_value,
		"no window low is charged more water than the tier-1 clicks it is worth")
	ok(G.pop_cost(0) == G.pop_cost(1) and G.pop_cost(-3) == G.pop_cost(1),
		"a low below the table clamps to the rank-0 cost")
	var top := G.POP_COST_BY_TIER_LOW.size()
	ok(G.pop_cost(top + 5) == G.pop_cost(top),
		"a low above the table clamps to the last entry instead of falling off the end")
	# the whole ladder must stay poppable from a full can: the dearest window still fits in WATER_CAP.
	var dearest := G.pop_cost(Mastery.tier_window_for_rank(G.MASTERY_THRESHOLDS.size()).x)
	ok(dearest <= G.WATER_CAP,
		"a full can affords a pop at the top rank (%d💧 of %d)" % [dearest, G.WATER_CAP])
	# the window low the cost is read from is the EFFECTIVE one — an ask-band slide makes the pop
	# cheaper again, so a line dragged back down to t1 asks pays the tier-1 price.
	_set_meter(1, int(G.MASTERY_THRESHOLDS[3]))          # rank 4: natural window t3-t6
	ok(G.pop_cost(Mastery.window(1, []).x) == G.pop_cost(3),
		"an unclamped rank-4 line pays its raised window's price")
	ok(G.pop_cost(Mastery.window(1, [{"line": 1, "tier": 2}]).x) == G.POP_COST,
		"a slide back down to the t1 window charges the tier-1 price again")

func _test_credit_math() -> void:
	fresh("credit")
	ok(Mastery.meter(1) == 0 and Mastery.rank(1) == 0,
		"an old save with no mastery key reads as zero")
	var delivery := Mastery.credit_delivery(103)
	ok(Mastery.meter(1) == G.tier_clicks(3) and delivery.is_empty(),
		"delivering an own-line t3 piece credits its tier-click cost without a rank-up")
	_set_meter(1, 19)
	var rank_up := Mastery.credit_delivery(101)
	ok(Mastery.meter(1) == 20 and int(rank_up.get(1, 0)) == 1,
		"delivery reports ranks gained when a threshold is crossed")
	ok(Mastery.seen_rank(1) == 0, "mastery_seen defaults to zero for a newly-ranked line")
	Mastery.mark_seen_rank(1, 1)
	Mastery.mark_seen_rank(1, 0)
	ok(Mastery.seen_rank(1) == 1,
		"mastery_seen records the highest celebrated rank and never rolls backward")
	var craft := Mastery.credit_craft(202, 302)
	ok(Mastery.meter(2) == G.tier_clicks(2)
		and Mastery.meter(3) == G.tier_clicks(2)
		and craft.is_empty(),
		"crafting credits each base ingredient at the shared tier")
	var before_2 := Mastery.meter(2)
	var before_8 := Mastery.meter(8)
	Mastery.credit_craft(803, 203)             # tea cups: spices (special) + wild berries
	ok(Mastery.meter(8) == before_8 and Mastery.meter(2) == before_2 + G.tier_clicks(3),
		"a nested special ingredient is not credited again; the base ingredient is")
	var coin_before := Mastery.meter(1)
	ok(Mastery.credit_delivery(G.COIN_LINE * 100 + 1).is_empty() and Mastery.meter(1) == coin_before,
		"coins and other non-mastery lines credit nothing")

func _test_scissors_price_floor() -> void:
	fresh("scissors_floor")
	ok(G.SCISSORS_LINE == 14 and G.SCISSORS_COST == 40, "scissors use the designed pseudo-line and price")
	ok(G.is_valid_item_code(G.SCISSORS_LINE * 100 + 1), "the scissors code survives save-load pruning")
	ok(G.special_kind(G.SCISSORS_LINE * 100 + 1) == "scissors", "the scissors item is registered as a tool")
	var max_gain := -999999
	for raw_line in G.LINES.keys():
		var line := int(raw_line)
		if G.TREAT_LINES.has(line):
			continue
		for tier in range(2, G.TOP_TIER + 1):
			var gain := 2 * int(G.sell_reward(line * 100 + tier - 1).x) - int(G.sell_reward(line * 100 + tier).x)
			max_gain = maxi(max_gain, gain)
	ok(G.SCISSORS_COST > max_gain,
		"scissors cost beats the best split-and-sell gain (%d > %d)" % [G.SCISSORS_COST, max_gain])
