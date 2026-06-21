extends "res://games/grove/tests/grove_test_base.gd"
## grove · vine — VineMaps registry + spot derivation + VineMapView headless instantiation.

const VineMaps = preload("res://games/grove/vine/vine_maps.gd")

func _initialize() -> void:
	begin("grove · vine")
	_test_registry()
	_test_spot_derivation()
	_test_maps_overlay()
	finish()

func _test_registry() -> void:
	var entries := VineMaps.entries()
	ok(entries.size() >= 1, "maps.json yields at least one vine map entry")
	var e0: Dictionary = entries[0]
	ok(String(e0.get("id", "")) == "map1_farm", "first vine entry is map1_farm")
	var regions := VineMaps.regions_for(e0)
	ok(regions.size() == 8, "map1_farm regions JSON has 8 regions (matches region_count)")
	ok(regions[0].has("points") and regions[0].has("tuning"), "a region carries points + tuning")

func _test_maps_overlay() -> void:
	# slot 0 keeps its id/name but is now vine-driven with region-derived spots
	ok(String(G.MAPS[0].id) == "farmhouse", "slot 0 keeps id 'farmhouse'")
	ok(G.MAPS[0].has("vine"), "slot 0 is vine-driven (carries the maps.json entry)")
	ok(G.MAPS[0].spots.size() == 8, "slot 0 has 8 region spots")
	ok(String(G.MAPS[0].spots[0].id) == "farmhouse_r0", "slot 0 spot ids are farmhouse_r*")
	ok(bool(G.MAPS[0].get("hub", false)), "slot 0 stays the hub")
	# legacy slots without a vine entry are untouched
	ok(not G.MAPS[G.MAPS.size() - 1].has("vine"), "the last legacy slot is not vine-driven")

func _test_spot_derivation() -> void:
	var e0: Dictionary = VineMaps.entries()[0]
	var spots := VineMaps.spots_for("farmhouse", e0)
	ok(spots.size() == 8, "8 regions -> 8 derived spots")
	ok(String(spots[0].id) == "farmhouse_r0" and String(spots[7].id) == "farmhouse_r7", "spot ids are <slot>_r<index>")
	ok(int(spots[0].cost) == 3 and int(spots[3].cost) == 4 and int(spots[7].cost) == 5, "cost ladder 3,3,3,4,4,4,5,5")
	var p0: Vector2 = spots[0].pos
	ok(p0.x > 0.0 and p0.x < 1.0 and p0.y > 0.0 and p0.y < 1.0, "centroid pos is normalized into (0,1)")
	# override file wins when present
	var ov := VineMaps.spots_for("ovtest", {"id": "ovtest", "regions_path": "res://games/grove/tests/fixtures/ov_regions.json"}, "res://games/grove/tests/fixtures/ov_spots.json")
	ok(ov.size() == 2 and String(ov[0].name) == "Cottage" and int(ov[0].cost) == 9, "override file sets name + cost")
