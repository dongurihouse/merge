extends "res://games/grove/tests/grove_test_base.gd"
## grove · vine — VineMaps registry + spot derivation + VineMapView headless instantiation.

const VineMaps = preload("res://games/grove/vine/vine_maps.gd")
const VineMapView = preload("res://games/grove/vine/vine_map_view.gd")

func _initialize() -> void:
	begin("grove · vine")
	_test_registry()
	_test_spot_derivation()
	_test_maps_overlay()
	_test_view_headless()
	await _test_map_integration()
	await _test_overlay_fills_view()
	_test_multimap()
	finish()

func _test_overlay_fills_view() -> void:
	fresh("vine_overlay_fit")
	var hx = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(hx)
	if hx.content == null:
		hx._ready()
	await create_timer(0.05).timeout
	hx._open_map(G.hub_map())
	await create_timer(0.1).timeout
	var vv: Control = hx.content.find_child("VineMapView", true, false)
	ok(vv != null, "hub has a VineMapView")
	var overlays: Control = vv.get_node_or_null("RegionOverlays")
	ok(overlays != null, "VineMapView has a RegionOverlays group")
	var vsz: Vector2 = vv.get_global_rect().size
	var osz: Vector2 = overlays.get_global_rect().size
	# the overlay group must fill the view (so its mask cover-fits the SAME rect as the base layer),
	# not the smaller source-image rect — this is the C1 alignment regression guard.
	ok(absf(vsz.x - osz.x) <= 2.0 and absf(vsz.y - osz.y) <= 2.0, \
		"RegionOverlays fills the view rect (%.0fx%.0f) not the image rect (got %.0fx%.0f)" % [vsz.x, vsz.y, osz.x, osz.y])
	hx.queue_free()

func _test_map_integration() -> void:
	fresh("vine_map")
	var hx = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(hx)
	if hx.content == null:
		hx._ready()
	await create_timer(0.05).timeout
	hx._open_map(G.hub_map())
	await create_timer(0.1).timeout
	# the hub renders through a VineMapView
	var vv: Control = hx.content.find_child("VineMapView", true, false)
	ok(vv != null, "the vine hub renders through a VineMapView")
	# one tap-hit seated per region
	ok(hx.spot_hits.size() == vv.region_count(), "the hub seats one spot per region")
	# region 0 starts overgrown (unowned) ...
	ok(_region_on(vv, 0), "region 0 vines are ON before it is restored")
	# ... buying region 0 turns its vines off on rebuild
	var sid := "%s_r0" % String(G.MAPS[G.hub_map()].id)
	hx.unlocks[sid] = true
	hx._build_map()
	await create_timer(0.05).timeout
	var vv2: Control = hx.content.find_child("VineMapView", true, false)
	ok(vv2 != null and not _region_on(vv2, 0), "restoring region 0 turns its vines off")
	hx.queue_free()

# read the VineMapView's per-region enabled state (vines ON == enabled). set_region_enabled keeps
# region_overlays[i].enabled in sync (confirmed in vine_map_view.gd), so read that directly.
func _region_on(vv: Control, i: int) -> bool:
	return bool(vv.region_overlays[i].get("enabled", true))

func _test_view_headless() -> void:
	var e0: Dictionary = VineMaps.entries()[0]
	var view: Control = VineMapView.new()
	get_root().add_child(view)
	view.load_map(e0, VineMaps.regions_for(e0))
	ok(view.region_count() == VineMaps.regions_for(e0).size(), "VineMapView.region_count() matches the regions JSON")
	view.set_region_enabled(0, false)   # must not error headless
	view.set_region_enabled(0, true)
	ok(view.get_node_or_null("RegionOverlays") != null, "VineMapView builds the per-region overlay tree")
	view.queue_free()

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

func _test_multimap() -> void:
	ok(VineMaps.count() >= 2, "maps.json holds at least 2 vine maps (map1 + placeholder)")
	ok(G.MAPS[1].has("vine"), "slot 1 is vine-driven from the 2nd tool entry")
	ok(G.MAPS[1].spots.size() == VineMaps.regions_for(VineMaps.entries()[1]).size(), "slot 1 spot count == its regions")
	ok(String(G.MAPS[1].spots[0].id) == "%s_r0" % String(G.MAPS[1].id), "slot 1 spot ids use slot 1's id")

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
