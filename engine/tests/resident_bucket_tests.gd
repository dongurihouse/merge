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

func _initialize() -> void:
	print("== resident bucket (pure module) ==")
	_test_hand_ops()
	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)
