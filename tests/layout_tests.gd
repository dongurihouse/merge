extends SceneTree
## Headless tests for the placement-override layer (scripts/layout.gd).
##   godot --headless --path . -s res://tests/layout_tests.gd
## Proves: absent overrides → pure grove_content defaults; overrides apply by
## stable id (not index); values clamp; and the on-disk JSON round-trips.

const G = preload("res://engine/scripts/content.gd")
const Layout = preload("res://engine/scripts/layout.gd")

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

	# 1. empty overrides → every accessor returns the grove_content default
	Layout._ingest({"zones": {}, "spots": {}})
	var all_default := true
	for z in G.ZONES.size():
		if not _v2_near(Layout.zone_map_pos(z), Vector2(G.ZONES[z].map_pos)):
			all_default = false
		for k in G.ZONES[z].spots.size():
			if not _v2_near(Layout.spot_pos(z, k), Vector2(G.ZONES[z].spots[k].pos)):
				all_default = false
			var dflt_fs := float(G.ZONES[z].spots[k].get("fsize", 240.0))
			if absf(Layout.spot_fsize(z, k) - dflt_fs) > 0.01:
				all_default = false
	ok(all_default, "no overrides → all accessors fall through to grove_content")
	ok(not Layout.zone_overridden(1), "zone_overridden false when absent")
	ok(not Layout.spot_overridden(0, 0), "spot_overridden false when absent")

	# 2. an override applies by ID and leaves the rest at default
	#    (barn is index 1; key by its id so reordering ZONES never desyncs)
	var barn_z := -1
	for z in G.ZONES.size():
		if String(G.ZONES[z].id) == "barn":
			barn_z = z
	ok(barn_z >= 0, "found barn zone")
	Layout._ingest({"zones": {"barn": {"map_pos": [0.5, 0.42]}}, "spots": {}})
	ok(_v2_near(Layout.zone_map_pos(barn_z), Vector2(0.5, 0.42)), "barn map_pos overridden by id")
	ok(Layout.zone_overridden(barn_z), "zone_overridden true after override")
	ok(_v2_near(Layout.zone_map_pos(0), Vector2(G.ZONES[0].map_pos)), "other zones still default")

	# 3. spot pos + fsize override by id
	Layout._ingest({"zones": {}, "spots": {"fh_chest": {"pos": [0.11, 0.22], "fsize": 333}}})
	ok(_v2_near(Layout.spot_pos(0, 0), Vector2(0.11, 0.22)), "fh_chest pos overridden")
	ok(absf(Layout.spot_fsize(0, 0) - 333.0) < 0.01, "fh_chest fsize overridden")
	ok(absf(Layout.spot_fsize(0, 1) - float(G.ZONES[0].spots[1].get("fsize", 240.0))) < 0.01, "sibling spot fsize still default")

	# 4. setters clamp to sane ranges
	Layout.reset_all()
	Layout.set_zone_map_pos(barn_z, Vector2(1.8, -0.3))
	ok(_v2_near(Layout.zone_map_pos(barn_z), Vector2(1.0, 0.0)), "map_pos clamps to [0,1]")
	Layout.set_spot_fsize(0, 0, 5000.0)
	ok(Layout.spot_fsize(0, 0) <= 700.0, "fsize clamps to <= 700")
	Layout.set_spot_fsize(0, 0, 1.0)
	ok(Layout.spot_fsize(0, 0) >= 40.0, "fsize clamps to >= 40")

	# 5. on-disk round-trip: set → save_to(temp) → re-parse → re-ingest → match
	Layout.reset_all()
	Layout.set_zone_map_pos(barn_z, Vector2(0.7, 0.66))
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
	ok(_v2_near(Layout.zone_map_pos(barn_z), Vector2(0.7, 0.66)), "round-trip: zone map_pos survives")
	ok(_v2_near(Layout.spot_pos(0, 2), Vector2(0.4, 0.4)), "round-trip: spot pos survives")
	ok(absf(Layout.spot_fsize(0, 2) - 280.0) < 0.01, "round-trip: spot fsize survives")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))

	# 6. reset clears one override but not the rest
	Layout._ingest({"zones": {"barn": {"map_pos": [0.5, 0.5]}}, "spots": {"fh_chest": {"pos": [0.1, 0.1]}}})
	Layout.reset_spot(0, 0)
	ok(not Layout.spot_overridden(0, 0), "reset_spot clears that spot")
	ok(Layout.zone_overridden(barn_z), "reset_spot leaves zone override intact")

	# leave the cache clean for any later in-process use
	Layout.reset_all()

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)
