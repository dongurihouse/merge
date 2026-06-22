extends "res://games/grove/tests/grove_test_base.gd"
## grove · vine — VineMaps registry + spot derivation + VineMapView headless instantiation.

const VineMaps = preload("res://games/grove/vine/vine_maps.gd")
const VineMapView = preload("res://games/grove/vine/vine_map_view.gd")

func _initialize() -> void:
	begin("grove · vine")
	_test_registry()
	_test_spot_derivation()
	_test_region_cost_field()
	_test_button_pos()
	_test_maps_overlay()
	_test_view_headless()
	_test_empty_regions()
	_test_lock_overlay()
	_test_region_map_membership()
	_test_cover_offset_bleed()
	await _test_map_integration()
	await _test_overlay_fills_view()
	_test_multimap()
	finish()

# The purple "locked region" cover: a per-region tint layer on top of the vines, gated by the same
# region_enabled toggle. Locked regions show the purple; owned regions clear it.
func _test_lock_overlay() -> void:
	var e0: Dictionary = VineMaps.entries()[0]
	var view: Control = VineMapView.new()
	get_root().add_child(view)
	view.load_map(e0, VineMaps.regions_for(e0))
	var entry: Dictionary = view.region_overlays[0]
	var lock = entry.get("lock")
	ok(lock is TextureRect, "region 0 has a 'lock' tint overlay")
	if lock is TextureRect:
		var mat := (lock as TextureRect).material as ShaderMaterial
		ok(mat != null, "the lock overlay carries a ShaderMaterial")
		var tc = mat.get_shader_parameter("tint_color")
		ok(tc is Color and absf(tc.r - 0.6863) < 0.02 and absf(tc.g - 0.6627) < 0.02 \
			and absf(tc.b - 0.9255) < 0.02 and absf(tc.a - 0.34) < 0.02, \
			"the tint is #AFA9EC at 34%% (got %s)" % [tc])
		view.set_region_enabled(0, true)
		ok((lock as TextureRect).visible, "a locked region shows the purple cover")
		ok(absf(float(mat.get_shader_parameter("region_enabled")) - 1.0) < 0.001, "locked -> region_enabled 1 on the lock layer")
		view.set_region_enabled(0, false)
		ok(not (lock as TextureRect).visible, "an owned region clears the purple cover")
		ok(absf(float(mat.get_shader_parameter("region_enabled"))) < 0.001, "owned -> region_enabled 0 on the lock layer")
	view.queue_free()

# The purple cover lives in its OWN full-view container (not the mask-offset-translated overlay
# group) and bleeds to the screen edges via a mask_offset_uv shift, so shifting the mask never
# exposes background on the leading edge.
func _test_cover_offset_bleed() -> void:
	var e0: Dictionary = VineMaps.entries()[0]
	var view: Control = VineMapView.new()
	get_root().add_child(view)
	view.load_map(e0, VineMaps.regions_for(e0))
	var covers: Control = view.get_node_or_null("RegionCovers")
	ok(covers != null, "the view has a full-view RegionCovers container")
	var lock := view.region_overlays[0].get("lock") as TextureRect
	ok(lock != null and lock.get_parent() == covers, "lock rects live under RegionCovers, not the offset group")
	# in the tool the view is sized to the image (941x1672) so cover-fit scale is 1.
	view.set_mask_offset(Vector2(0.0, 100.0))
	var uv = (lock.material as ShaderMaterial).get_shader_parameter("mask_offset_uv")
	ok(uv is Vector2 and absf(uv.x) < 0.001 and absf(uv.y - 100.0 / float(view.image_size.y)) < 0.001, \
		"mask_offset_uv = mask_offset / displayed_size (got %s, want y=%.4f)" % [uv, 100.0 / float(view.image_size.y)])
	# the offset group must NOT carry the lock layer (vines stay there, cover does not).
	var group: Control = view.get_node_or_null("RegionOverlays")
	ok(group != null and group.get_node_or_null("Region1Lock") == null, "the offset group holds no lock rect")
	view.queue_free()

# The region-index map marks region membership in the GREEN channel so the full polygon can be
# filled with purple. Region 0 encodes to red 0.0 (same as the background fill), so green is what
# distinguishes a region-0 pixel from a non-region pixel.
func _test_region_map_membership() -> void:
	var view: Control = VineMapView.new()
	view.image_size = Vector2i(10, 10)
	view.regions = [{"points": [[2, 2], [6, 2], [6, 6], [2, 6]]}, {"points": [[7, 7], [9, 7], [9, 9], [7, 9]]}]
	view._rebuild_region_map()
	var img: Image = view.region_map_texture.get_image()
	var inside0 := img.get_pixel(4, 4)
	var inside1 := img.get_pixel(8, 8)
	var outside := img.get_pixel(0, 0)
	ok(inside0.g > 0.5, "a region-0 interior pixel is marked as member (green=1)")
	ok(inside0.r < 0.25, "a region-0 interior pixel decodes to index 0 (red~0)")
	ok(inside1.g > 0.5, "a region-1 interior pixel is marked as member (green=1)")
	ok(outside.g < 0.5, "an off-polygon pixel is unmarked (green=0) so region 0 != background")
	view.free()

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

# Manual-only authoring can clear every polygon, handing the view an EMPTY region set. The view floors
# its overlay count at 1 (a fallback overlay), so the enable-sync must tolerate an index past the end
# of the empty `regions` array instead of crashing (regression: VineMapView._set_region_enabled).
func _test_empty_regions() -> void:
	var e0: Dictionary = VineMaps.entries()[0]
	var view: Control = VineMapView.new()
	get_root().add_child(view)
	view.load_map(e0, [])                 # open with no regions — must not crash
	ok(view.get_node_or_null("RegionOverlays") != null, "the view builds overlays even with zero regions")
	view.refresh([])                      # clearing to empty — must not crash
	view.set_region_enabled(0, false)     # toggling the fallback overlay — must not crash
	ok(true, "empty-region load / refresh / set_region_enabled do not crash")
	view.queue_free()

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
	# map1_farm is hand-authored in the tool now, so its region count is whatever the artist saved —
	# assert structure, not a fixed count (the count-specific coverage uses dedicated fixtures).
	ok(regions.size() >= 1, "map1_farm regions JSON is non-empty")
	ok(regions[0].has("points") and regions[0].has("tuning"), "a region carries points + tuning")

func _test_maps_overlay() -> void:
	# slot 0 keeps its id/name but is now vine-driven with region-derived spots
	ok(String(G.MAPS[0].id) == "farmhouse", "slot 0 keeps id 'farmhouse'")
	ok(G.MAPS[0].has("vine"), "slot 0 is vine-driven (carries the maps.json entry)")
	ok(G.MAPS[0].spots.size() == VineMaps.regions_for(VineMaps.entries()[0]).size(), "slot 0 has one spot per region")
	ok(G.MAPS[0].spots.size() >= 1 and String(G.MAPS[0].spots[0].id) == "farmhouse_r0", "slot 0 spot ids are farmhouse_r*")
	ok(bool(G.MAPS[0].get("hub", false)), "slot 0 stays the hub")
	# all five maps are registered + imported now, so every slot is vine-driven
	var all_vine := true
	for z in G.MAPS.size():
		if not G.MAPS[z].has("vine"):
			all_vine = false
	ok(all_vine, "every game slot is vine-driven (all 5 maps registered)")

# All five game slots are driven by the five registered vine maps (mapN -> slot N). A map whose regions
# aren't authored yet overlays its slot with an EMPTY spot list (clean base art shown) and is NOT counted
# "done" — the carve-out that keeps a region-less map from auto-unlocking the next map or inviting residents.
func _test_multimap() -> void:
	ok(VineMaps.count() == G.MAPS.size(), "maps.json holds one vine entry per game slot (%d)" % G.MAPS.size())
	for z in G.MAPS.size():
		ok(G.MAPS[z].has("vine"), "slot %d is vine-driven from tool entry %d" % [z, z])
		ok(G.MAPS[z].spots.size() == VineMaps.regions_for(VineMaps.entries()[z]).size(), "slot %d spot count == its regions" % z)
	# slot 1 (Orchard art) ships no authored regions yet: vine-driven, zero spots, never "done"
	ok(G.MAPS[1].has("vine") and G.MAPS[1].spots.is_empty(), "a region-less slot is vine-driven with no spots (clean base art)")
	ok(not G.map_spots_done(1, {}), "a region-less (spot-less) map is NOT 'done' (no auto-unlock / no residents)")
	# a slot WITH authored regions derives its spot ids from the slot id
	ok(String(G.MAPS[0].spots[0].id) == "%s_r0" % String(G.MAPS[0].id), "an authored slot's spot ids use the slot id")

func _test_spot_derivation() -> void:
	var e0: Dictionary = VineMaps.entries()[0]
	var regions := VineMaps.regions_for(e0)
	var n := regions.size()
	var spots := VineMaps.spots_for("farmhouse", e0)
	ok(n >= 1 and spots.size() == n, "one derived spot per region")
	ok(String(spots[0].id) == "farmhouse_r0" and String(spots[n - 1].id) == "farmhouse_r%d" % (n - 1), "spot ids are <slot>_r<index>")
	# map1 is hand-authored now: each spot's stars mirror the region's own cost (the ladder-fallback
	# path is covered by _test_region_cost_field with a dedicated fixture).
	var cost_ok := true
	for i in range(n):
		var r: Dictionary = regions[i]
		if int(spots[i].cost) < 1 or (r.has("cost") and int(spots[i].cost) != int(r["cost"])):
			cost_ok = false
	ok(cost_ok, "each spot's cost is valid and mirrors the region's authored cost")
	var p0: Vector2 = spots[0].pos
	ok(p0.x > 0.0 and p0.x < 1.0 and p0.y > 0.0 and p0.y < 1.0, "centroid pos is normalized into (0,1)")
	# override file wins when present
	var ov := VineMaps.spots_for("ovtest", {"id": "ovtest", "regions_path": "res://games/grove/tests/fixtures/ov_regions.json"}, "res://games/grove/tests/fixtures/ov_spots.json")
	ok(ov.size() == 2 and String(ov[0].name) == "Cottage" and int(ov[0].cost) == 9, "override file sets name + cost")

# A region that carries its own `cost` (authored in the vine tool) drives the spot's stars directly:
# it wins over the COST_LADDER default AND over a _spots.json override (the tool is the source of truth
# for stars). A region with no cost still falls back to the ladder, so existing maps are unchanged.
# A region's optional `button` [x,y] sets the unlock-disc position (normalized), overriding the polygon
# centroid the game otherwise computes. A region with no `button` still falls back to the centroid.
func _test_button_pos() -> void:
	var entry := {"id": "btntest", "regions_path": "res://games/grove/tests/fixtures/button_regions.json"}
	var spots := VineMaps.spots_for("btntest", entry)
	ok(spots.size() == 2, "button fixture yields 2 spots")
	var p0: Vector2 = spots[0].pos
	ok(absf(p0.x - 0.2) < 0.001 and absf(p0.y - 0.8) < 0.001, "a region's button [20,80] -> pos (0.2,0.8), not the centroid (0.5,0.5)")
	var p1: Vector2 = spots[1].pos
	ok(absf(p1.x - 0.2) < 0.001 and absf(p1.y - 0.2) < 0.001, "a region with no button falls back to the centroid (0.2,0.2)")

func _test_region_cost_field() -> void:
	var entry := {"id": "costtest", "regions_path": "res://games/grove/tests/fixtures/cost_regions.json"}
	var spots := VineMaps.spots_for("costtest", entry)
	ok(int(spots[0].cost) == 7, "a region's own cost (7) wins over the cost ladder")
	ok(int(spots[1].cost) == 3, "a region with no cost falls back to the ladder (index 1 -> 3)")
	var spots2 := VineMaps.spots_for("costtest", entry, "res://games/grove/tests/fixtures/cost_override.json")
	ok(int(spots2[0].cost) == 7, "a region's own cost wins over a _spots.json override too")
