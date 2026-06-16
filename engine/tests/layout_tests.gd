extends SceneTree
## Headless tests for the placement-override layer (scripts/core/layout.gd).
##   godot --headless --path . -s res://engine/tests/layout_tests.gd
## Proves: absent overrides → pure grove_content defaults; overrides apply by
## stable spot id (not index); values clamp; and the on-disk JSON round-trips.
## (The NEW map model has no overworld map placement — a map IS one image with
## spots ON it — so the per-map placement layer is gone; only spot pos/fsize remain.)

const G = preload("res://engine/scripts/core/content.gd")
const Layout = preload("res://engine/scripts/core/layout.gd")

var _pass := 0
var _fail := 0

func ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _v2_near(a: Vector2, b: Vector2, tol := 0.001) -> bool:
	return a.distance_to(b) <= tol

func _initialize() -> void:
	print("== Layout (placement overrides) tests ==")

	# 1. empty overrides → every spot accessor returns the grove_content default
	Layout._ingest({"spots": {}})
	var all_default := true
	for z in G.MAPS.size():
		for k in G.MAPS[z].spots.size():
			if not _v2_near(Layout.spot_pos(z, k), Vector2(G.MAPS[z].spots[k].pos)):
				all_default = false
			var dflt_fs := float(G.MAPS[z].spots[k].get("fsize", 240.0))
			if absf(Layout.spot_fsize(z, k) - dflt_fs) > 0.01:
				all_default = false
	ok(all_default, "no overrides → all spot accessors fall through to grove_content")
	ok(not Layout.spot_overridden(0, 0), "spot_overridden false when absent")

	# 2. a spot pos + fsize override applies by ID and leaves the rest at default
	#    (key by the stable spot id so reordering MAPS never desyncs)
	Layout._ingest({"spots": {"fh_hearth": {"pos": [0.11, 0.22], "fsize": 333}}})
	ok(_v2_near(Layout.spot_pos(0, 0), Vector2(0.11, 0.22)), "fh_hearth pos overridden by id")
	ok(absf(Layout.spot_fsize(0, 0) - 333.0) < 0.01, "fh_hearth fsize overridden")
	ok(Layout.spot_overridden(0, 0), "spot_overridden true after override")
	ok(absf(Layout.spot_fsize(0, 1) - float(G.MAPS[0].spots[1].get("fsize", 240.0))) < 0.01, "sibling spot fsize still default")
	ok(_v2_near(Layout.spot_pos(0, 1), Vector2(G.MAPS[0].spots[1].pos)), "sibling spot pos still default")

	# 3. setters clamp to sane ranges
	Layout.reset_all()
	Layout.set_spot_pos(0, 0, Vector2(1.8, -0.3))
	ok(_v2_near(Layout.spot_pos(0, 0), Vector2(1.0, 0.0)), "spot pos clamps to [0,1]")
	Layout.set_spot_fsize(0, 0, 5000.0)
	ok(Layout.spot_fsize(0, 0) <= 700.0, "fsize clamps to <= 700")
	Layout.set_spot_fsize(0, 0, 1.0)
	ok(Layout.spot_fsize(0, 0) >= 40.0, "fsize clamps to >= 40")

	# 4. on-disk round-trip: set → save_to(temp) → re-parse → re-ingest → match
	Layout.reset_all()
	Layout.set_spot_pos(0, 2, Vector2(0.4, 0.4))
	Layout.set_spot_fsize(0, 2, 280.0)
	var tmp := "user://tu_layout_test.json"
	ok(Layout.save_to(tmp), "save_to(temp) succeeds")
	var f := FileAccess.open(tmp, FileAccess.READ)
	ok(f != null, "temp file readable")
	var txt := f.get_as_text() if f != null else ""
	if f != null:
		f.close()
	var parsed: Variant = JSON.parse_string(txt)
	ok(parsed is Dictionary, "saved JSON parses to a Dictionary")
	Layout._ingest(parsed if parsed is Dictionary else {})
	ok(_v2_near(Layout.spot_pos(0, 2), Vector2(0.4, 0.4)), "round-trip: spot pos survives")
	ok(absf(Layout.spot_fsize(0, 2) - 280.0) < 0.01, "round-trip: spot fsize survives")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))

	# 5. reset clears one override but not the rest
	Layout._ingest({"spots": {"fh_hearth": {"pos": [0.1, 0.1]}, "fh_kitchen": {"pos": [0.2, 0.2]}}})
	Layout.reset_spot(0, 0)
	ok(not Layout.spot_overridden(0, 0), "reset_spot clears that spot")
	ok(Layout.spot_overridden(0, 1), "reset_spot leaves the sibling override intact")

	# leave the cache clean for any later in-process use
	Layout.reset_all()

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)
