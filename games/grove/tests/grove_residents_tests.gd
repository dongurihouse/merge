extends "res://games/grove/tests/grove_test_base.gd"
## grove · residents habitat — guards engine/scripts/core/habitat.gd (the payback-half model)
## and a headless smoke test of the Residents screen. Active suite (in GROVE_TESTS).

const Habitat = preload("res://engine/scripts/core/habitat.gd")

func _initialize() -> void:
	begin("grove · residents habitat")
	_test_hand()
	finish()

func _test_hand() -> void:
	fresh("habitat_hand")
	ok(Habitat.hand().is_empty(), "a fresh save has an empty hand")
	Habitat.hand_add("moss")
	Habitat.hand_add("moss")
	ok(Habitat.hand().size() == 2, "two acquires land two spirits in the hand")
	ok(int(Habitat.hand()[0].tier) == 1, "an acquired spirit enters at tier 1")

	# two of a kind at the same tier MERGE in hand into one a tier up (explicit, not auto)
	ok(Habitat.hand_merge("moss", 1), "two moss t1 merge in hand")
	ok(Habitat.hand().size() == 1 and int(Habitat.hand()[0].tier) == 2, "the pair becomes one moss t2")
	ok(not Habitat.hand_merge("moss", 2), "a lone t2 cannot merge")
	Habitat.hand_add("acorn")
	ok(not Habitat.hand_merge("moss", 2), "different kinds do not merge")
