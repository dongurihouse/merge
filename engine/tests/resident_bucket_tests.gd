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

func _initialize() -> void:
	print("== resident bucket (pure module) ==")
	_test_hand_ops()
	_test_cells_and_placement()
	_test_sell()
	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)
