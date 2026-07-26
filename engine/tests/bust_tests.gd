extends "res://engine/tests/test_base.gd"
## Headless tests for ui/bust.gd giver-pool selection — the map-themed portrait lookup.
## Pure path logic (Bust.giver_path): map 0 keeps characters/giver_<n>.png; maps ≥1 use their own
## characters/giver_m<map>_<n>.png cast, falling back to the map-0 face when a per-map tile is absent.
##   godot --headless --path . -s res://engine/tests/bust_tests.gd

const Bust = preload("res://engine/scripts/ui/bust.gd")

func _initialize() -> void:
	ok(Bust.GIVER_COUNT == 5, "the cut-paper quest-giver cast has 5 portraits per scene")
	# map 0 is the first scene cast — no prefix
	ok(Bust.giver_path(3, 0).ends_with("characters/giver_3.png"), "map 0 uses the original giver_<n> pool")
	# the selector folds into the 5-face scene pool
	ok(Bust.giver_path(7, 0).ends_with("characters/giver_2.png"), "the face index wraps mod the 5-face scene pool")
	ok(ResourceLoader.exists("res://games/grove/assets/characters/giver_4.png"), "map 0 ships the fifth cut-paper giver")
	ok(not ResourceLoader.exists("res://games/grove/assets/characters/giver_5.png"), "map 0 no longer ships retired extra giver faces")
	# maps 1..4 use their own themed 5-face row from the cut-paper sheet
	for m in [1, 2, 3, 4]:
		ok(Bust.giver_path(4, m).ends_with("characters/giver_m%d_4.png" % m),
			"map %d uses its own giver_m%d_<n> pool" % [m, m])
		ok(not ResourceLoader.exists("res://games/grove/assets/characters/giver_m%d_5.png" % m),
			"map %d no longer ships retired extra giver faces" % m)
	# a map with no per-map art falls back to the map-0 face (the fence never blanks)
	ok(Bust.giver_path(2, 99).ends_with("characters/giver_2.png"), "an unmapped map falls back to the map-0 pool")
	# make() builds a portrait Control for a map-specific pick
	var face := Bust.make(0, 80.0, 2)
	ok(face != null and face.get_child_count() > 0, "make() renders a map-specific portrait")

	print("")
	finish()
