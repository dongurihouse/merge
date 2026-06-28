extends SceneTree
## Headless tests for ui/bust.gd giver-pool selection — the map-themed portrait lookup.
## Pure path logic (Bust.giver_path): map 0 keeps characters/giver_<n>.png; maps ≥1 use their own
## characters/giver_m<map>_<n>.png cast, falling back to the map-0 face when a per-map tile is absent.
##   godot --headless --path . -s res://engine/tests/bust_tests.gd

const Bust = preload("res://engine/scripts/ui/bust.gd")

var _pass := 0
var _fail := 0

func ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _initialize() -> void:
	# map 0 is the original cast — no prefix
	ok(Bust.giver_path(3, 0).ends_with("characters/giver_3.png"), "map 0 uses the original giver_<n> pool")
	# the selector folds into the 16-face pool
	ok(Bust.giver_path(19, 0).ends_with("characters/giver_3.png"), "the face index wraps mod GIVER_COUNT")
	# maps 1..4 use their own themed sheet (these tiles ship in characters/)
	for m in [1, 2, 3, 4]:
		ok(Bust.giver_path(5, m).ends_with("characters/giver_m%d_5.png" % m),
			"map %d uses its own giver_m%d_<n> pool" % [m, m])
	# a map with no per-map art falls back to the map-0 face (the fence never blanks)
	ok(Bust.giver_path(2, 99).ends_with("characters/giver_2.png"), "an unmapped map falls back to the map-0 pool")
	# make() builds a portrait Control for a map-specific pick
	var face := Bust.make(0, 80.0, 2)
	ok(face != null and face.get_child_count() > 0, "make() renders a map-specific portrait")

	print("\n== %d passed, %d failed ==" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)
