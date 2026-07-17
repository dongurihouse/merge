extends SceneTree
## Headless guard for the layered HOME zone renderer (ui/home_zone_view.gd): it builds the
## foundation + one painter-sorted prop per building from a manifest + injected state resolvers,
## and a build badge over every unbuilt plot. Also checks the shipped zone_farmhouse.json manifest.
##   godot --headless --path . -s res://engine/tests/home_zone_view_tests.gd

const HZV = preload("res://engine/scripts/ui/home_zone_view.gd")

var _pass := 0
var _fail := 0

func ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _manifest() -> Dictionary:
	return {
		"canvas": {"width": 941, "height": 1672},
		"background": "res://games/grove/assets/map/home_layered_cutpaper/home_base.png",
		"buildings": [
			{"id": "a", "position": [200, 800], "display_size": [100, 100], "sort_y": 800,
				"states": {"built": "res://games/grove/assets/map/home_layered_cutpaper/props/fh_hearth.png",
					"site": "res://games/grove/assets/map/home_layered_cutpaper/props/fh_hearth.png"}},
			{"id": "b", "position": [400, 1200], "display_size": [100, 100], "sort_y": 1200,
				"states": {"built": "res://games/grove/assets/map/home_layered_cutpaper/props/fh_well.png"}},
		],
	}

func _initialize() -> void:
	print("== Home zone view tests ==")
	var m := _manifest()

	# state stubs: `a` is mid-build (site, still has a next step), `b` is empty (a plot, next step at L1)
	var states := {"a": "site", "b": "empty"}
	var steps := {
		"a": {"cost": 25, "min_level": 2, "shows": "built"},
		"b": {"cost": 10, "min_level": 1, "shows": "site"},
	}
	var state_of := func(id): return String(states.get(id, "empty"))
	var next_of := func(id): return steps.get(id, {})

	var parent := Control.new()
	get_root().add_child(parent)
	var out := HZV.build(parent, m, state_of, next_of)

	ok(out.base != null and out.base.texture != null, "the foundation base loads its background texture")
	ok(out.canvas == Vector2(941, 1672), "the stage sizes to the manifest canvas")

	# `a` has a site prop; `b` is empty so it has NO prop, only a badge.
	ok(out.props.has("a") and not out.props.has("b"), "a mid-build plot renders its prop; an empty plot renders none")
	var pa: TextureRect = out.props["a"]
	ok(pa.z_index == 800, "the prop's z-index is its sort_y (painter order)")
	ok(is_equal_approx(pa.position.x, 200 - 50) and is_equal_approx(pa.position.y, 800 - 100), \
		"the prop is center-bottom anchored (x-half-width, y-full-height)")
	ok(pa.modulate.a < 1.0, "a SITE prop renders dimmer than a finished building")

	# both unbuilt buildings carry a build badge with the step's cost + level
	ok(out.badges.has("a") and out.badges.has("b"), "every unbuilt building gets a build badge")
	var ba: Control = out.badges["b"]
	ok(int(ba.get_meta("cost")) == 10 and int(ba.get_meta("min_level")) == 1, "the badge carries the next step's cost + level")
	ok(String(ba.get_meta("building_id")) == "b", "the badge remembers its building id (for the tap→buy flow)")

	# a BUILT building: no next step → no badge, and the built prop renders full-opacity
	var states2 := {"a": "built"}
	var steps2 := {"a": {}}
	var out2 := HZV.build(parent, m, \
		func(id): return String(states2.get(id, "built")), \
		func(id): return steps2.get(id, {}))
	ok(out2.props.has("a") and not out2.badges.has("a"), "a built building shows its prop with no badge")
	ok(is_equal_approx((out2.props["a"] as TextureRect).modulate.a, 1.0), "a built prop renders full opacity")

	# the SHIPPED farmhouse manifest parses and carries the 7 buildings at the cut-paper anchors
	var shipped := HZV.load_manifest("res://games/grove/assets/map/home/zone_farmhouse.json")
	ok(not shipped.is_empty(), "the shipped zone_farmhouse.json manifest parses")
	ok((shipped.get("buildings", []) as Array).size() == 7, "the shipped manifest carries the 7 farmhouse buildings")
	ok(int(shipped.canvas.width) == 941 and int(shipped.canvas.height) == 1672, "the shipped manifest matches the cut-paper canvas")

	parent.queue_free()
	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
