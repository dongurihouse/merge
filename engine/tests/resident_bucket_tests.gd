extends SceneTree

const Bucket = preload("res://engine/scripts/core/resident_bucket.gd")

var _pass := 0
var _fail := 0

func ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _test_hand_ops() -> void:
	var s := Bucket.make_state()
	ok(s.cells == 0 and s.hand.is_empty() and s.placed.is_empty(), "fresh state: 0 cells, empty hand + placed")
	ok(Bucket.hand_add(s, "coin") == 1, "hand_add appends and returns new size")
	ok(Bucket.hand_add(s, "coin", 99) == 2 and s.hand[1].tier == Bucket.MAX_TIER, "hand_add clamps tier to MAX_TIER")
	ok(Bucket.hand_add(s, "acorn") == 2, "hand_add rejects an unknown line")
	ok(not Bucket.hand_merge(s, 0, 1), "hand_merge refuses mismatched tiers")
	Bucket.hand_add(s, "coin")            # hand: t1 coin, t12 coin, t1 coin
	ok(Bucket.hand_merge(s, 0, 2), "hand_merge consumes a same line+tier pair")
	ok(s.hand.size() == 2 and s.hand[0].tier == 2, "merge result climbs one tier in place")
	Bucket.hand_add(s, "water", Bucket.MAX_TIER)
	Bucket.hand_add(s, "water", Bucket.MAX_TIER)
	ok(not Bucket.hand_merge(s, 2, 3), "hand_merge is a no-op at MAX_TIER")
	var t := Bucket.make_state()
	Bucket.hand_add(t, "coin")
	Bucket.hand_add(t, "water")
	ok(not Bucket.hand_merge(t, 0, 1), "hand_merge refuses cross-line pairs")
	ok(not Bucket.hand_merge(t, 0, 0), "hand_merge refuses i == j")
	ok(not Bucket.hand_merge(t, 0, 7), "hand_merge refuses an out-of-range index")

func _test_cells_and_placement() -> void:
	var s := Bucket.make_state()
	Bucket.hand_add(s, "coin")
	ok(not Bucket.place(s, 0, 0.0), "place refuses with 0 cells")
	ok(Bucket.grant_cells(s, 2) == 2, "grant_cells raises the total")
	ok(Bucket.grant_cells(s, 0) == 2 and Bucket.grant_cells(s, -3) == 2, "grant_cells ignores n <= 0")
	ok(Bucket.place(s, 0, 0.0), "place moves hand -> cell")
	ok(s.hand.is_empty() and s.placed.size() == 1, "place consumed the hand entry")
	Bucket.hand_add(s, "coin")
	Bucket.hand_add(s, "water")
	ok(Bucket.place(s, 1, 0.0), "duplicate lines may fill multiple cells")
	Bucket.hand_add(s, "boost")
	ok(not Bucket.place(s, 1, 0.0), "place refuses when the bucket is full")
	ok(not Bucket.place(s, 9, 0.0), "place refuses a bad hand index")
	# place_merge: hand t1 coin onto placed t1 coin -> t2, no cell consumed
	ok(Bucket.place_merge(s, 0, 0, 0.0), "place_merge climbs the placed spirit")
	ok(s.placed[0].tier == 2 and s.placed.size() == 2 and s.hand.size() == 1, "place_merge freed no cell and ate the hand spirit")
	ok(not Bucket.place_merge(s, 0, 1, 0.0), "place_merge refuses cross-line pairs")
	# unplace: back to hand, frees the cell
	ok(Bucket.unplace(s, 1, 0.0), "unplace returns a placed spirit to hand")
	ok(s.placed.size() == 1 and s.hand.size() == 2, "unplace freed the cell")
	ok(not Bucket.unplace(s, 5, 0.0), "unplace refuses a bad index")

func _test_sell() -> void:
	var s := Bucket.make_state()
	Bucket.grant_cells(s, 1)
	Bucket.hand_add(s, "coin", 3)
	Bucket.hand_add(s, "water", 1)
	ok(Bucket.sell_hand(s, 0) == 3 * Bucket.SELL_PER_TIER, "sell_hand pays SELL_PER_TIER x tier")
	ok(s.hand.size() == 1, "sell_hand removed the spirit")
	ok(Bucket.sell_hand(s, 9) == 0, "sell_hand pays 0 on a bad index")
	Bucket.place(s, 0, 0.0)
	ok(Bucket.sell_placed(s, 0, 0.0) == Bucket.SELL_PER_TIER, "sell_placed pays the same rate")
	ok(s.placed.is_empty(), "sell_placed freed the cell")

const HOUR := 3600.0

func _cfg(rate_h: float, base: float, per: float, day_cap: int = 0) -> Dictionary:
	# a pinned single-dial override so tests never depend on provisional DEFAULTS
	var lines := {}
	for l in Bucket.LINES:
		lines[l] = {"rate_per_tier_h": rate_h, "bank_base": base, "bank_per_tier": per, "day_cap": day_cap, "weight": 1}
	return {"lines": lines, "tier_weights": [1]}

func _test_production() -> void:
	var cfg := _cfg(1.0, 2.0, 1.0)   # 1 unit/h per Σtier; bank = 2 + Σtier
	var s := Bucket.make_state(0.0)
	Bucket.grant_cells(s, 3)
	Bucket.hand_add(s, "coin", 2)
	Bucket.hand_add(s, "coin", 3)
	Bucket.place(s, 0, 0.0, cfg)
	Bucket.place(s, 0, 0.0, cfg)
	ok(Bucket.line_stier(s, "coin") == 5, "line_stier sums placed tiers of the line")
	ok(Bucket.line_stier(s, "water") == 0, "line_stier is 0 for an unplaced line")
	ok(is_equal_approx(Bucket.rate(s, "coin", cfg), 5.0), "rate = rate_per_tier_h x Stier")
	ok(is_equal_approx(Bucket.bank_cap(s, "coin", cfg), 7.0), "bank_cap = base + per_tier x Stier")
	ok(is_equal_approx(Bucket.pending(s, "coin", HOUR * 0.5, cfg), 2.5), "pending accrues rate x elapsed")
	ok(is_equal_approx(Bucket.pending(s, "coin", HOUR * 100.0, cfg), 7.0), "pending clamps at the bank cap")
	ok(is_equal_approx(Bucket.pending(s, "coin", -5.0, cfg), 0.0), "pending ignores time running backwards")
	ok(is_equal_approx(Bucket.pending(s, "water", HOUR, cfg), 0.0), "an unplaced line accrues nothing")
	# settling mid-way then raising Stier accounts the old rate up to the settle point
	Bucket.hand_add(s, "coin", 5)
	Bucket.place(s, 0, HOUR, cfg)              # settles at t=1h: bank 5.0; Stier now 10
	ok(is_equal_approx(s.banks["coin"], 5.0), "Stier-changing calls settle at the old rate first")
	ok(is_equal_approx(Bucket.pending(s, "coin", HOUR + HOUR * 0.1, cfg), 6.0), "post-change accrual uses the new rate")
	# selling below an already-banked amount never destroys the bank
	var over := Bucket.make_state(0.0)
	Bucket.grant_cells(over, 2)
	Bucket.hand_add(over, "coin", 10)
	Bucket.place(over, 0, 0.0, cfg)
	Bucket.sell_placed(over, 0, HOUR, cfg)      # banked 10.0 with cap 12 -> then Stier 0, cap 2
	ok(is_equal_approx(over.banks["coin"], 10.0), "an over-cap bank survives (no accrual, no destruction)")
	ok(is_equal_approx(Bucket.pending(over, "coin", HOUR * 9.0, cfg), 10.0), "over-cap bank stops accruing")

func _test_merge_always_pays() -> void:
	# the spec's hard invariant: every +1 Stier strictly raises rate AND bank cap on every line
	for line in Bucket.LINES:
		var all_pay := true
		for stier in range(1, Bucket.MAX_TIER * 8):
			var lo := _stier_state(line, stier)
			var hi := _stier_state(line, stier + 1)
			if Bucket.rate(hi, line) <= Bucket.rate(lo, line):
				all_pay = false
			if Bucket.bank_cap(hi, line) <= Bucket.bank_cap(lo, line):
				all_pay = false
		ok(all_pay, "merge always pays on '%s' (rate + bank strictly rise per Stier step, DEFAULTS)" % line)

func _stier_state(line: String, stier: int) -> Dictionary:
	var s := Bucket.make_state(0.0)
	Bucket.grant_cells(s, 8)
	var left := stier
	while left > 0:
		var t: int = mini(left, Bucket.MAX_TIER)
		Bucket.hand_add(s, line, t)
		Bucket.place(s, 0, 0.0)
		left -= t
	return s

const DAY := 86400.0

func _test_collect_and_day_cap() -> void:
	var cfg := _cfg(1.0, 50.0, 1.0, 2)   # every line: 1 unit/h per Stier, deep bank, day_cap 2
	var s := Bucket.make_state(0.0)
	Bucket.grant_cells(s, 2)
	Bucket.hand_add(s, "coin", 1)
	Bucket.hand_add(s, "diamond", 1)
	Bucket.place(s, 0, 0.0, cfg)
	Bucket.place(s, 0, 0.0, cfg)
	var got := Bucket.collect(s, HOUR * 3.5, cfg)
	ok(int(got.get("coin", 0)) == 2, "collect grants floor(bank) whole units (day-capped at 2 here)")
	ok(is_equal_approx(s.banks["coin"], 1.5), "the fraction AND the over-allowance stay banked")
	ok(int(got.get("diamond", 0)) == 2, "a day-capped line grants at most day_cap")
	ok(Bucket.collect(s, HOUR * 3.5, cfg).is_empty(), "same-day recollect grants nothing further")
	got = Bucket.collect(s, DAY + HOUR, cfg)
	ok(int(got.get("diamond", 0)) == 2, "the allowance resets on the next day and banked surplus pays out")
	# an uncapped line pays the whole banked amount
	var free_cfg := _cfg(1.0, 50.0, 1.0, 0)
	var u := Bucket.make_state(0.0)
	Bucket.grant_cells(u, 1)
	Bucket.hand_add(u, "coin", 2)
	Bucket.place(u, 0, 0.0, free_cfg)
	ok(int(Bucket.collect(u, HOUR * 5.0, free_cfg).get("coin", 0)) == 10, "day_cap 0 = unbounded collect")
	ok(Bucket.collect(u, HOUR * 5.0, free_cfg).is_empty(), "an empty bank returns an empty grant")

func _initialize() -> void:
	print("== resident bucket (pure module) ==")
	_test_hand_ops()
	_test_cells_and_placement()
	_test_sell()
	_test_production()
	_test_merge_always_pays()
	_test_collect_and_day_cap()
	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)
