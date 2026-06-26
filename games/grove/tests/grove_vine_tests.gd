extends "res://games/grove/tests/grove_test_base.gd"
## grove · vine — VineMaps registry + spot derivation + VineMapView headless instantiation.

const VineMaps = preload("res://games/grove/vine/vine_maps.gd")
const VineMapView = preload("res://games/grove/vine/vine_map_view.gd")
const Kit = preload("res://games/grove/tools/ui_workbench_kit.gd")

func _initialize() -> void:
	begin("grove · vine")
	_test_registry()
	_test_spot_derivation()
	_test_zone_unlocks_floor_to_required_level()
	_test_button_pos()
	_test_maps_overlay()
	_test_view_headless()
	_test_empty_regions()
	_test_lock_overlay()
	_test_region_map_membership()
	_test_vine_image_loader_is_export_safe()
	_test_mask_loader_survives_export_strip()
	_test_vine_debug_layer_modes()
	_test_vine_diagnostic_summary()
	_test_vine_device_debug_wiring()
	_test_region_map_prebaked()
	_test_cover_offset_bleed()
	await _test_boot_does_zero_live_work()
	await _test_map_integration()
	await _test_locked_zone_level_badges()
	await _test_map_card_zone_progress()
	await _test_unlock_badge_follows_map()
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
		"mask_offset_uv = mask_offset / source image size (got %s, want y=%.4f)" % [uv, 100.0 / float(view.image_size.y)])
	view.size = Vector2(view.image_size) * 2.0
	view.set_mask_offset(Vector2(0.0, 100.0))
	var scaled_uv = (lock.material as ShaderMaterial).get_shader_parameter("mask_offset_uv")
	ok(scaled_uv is Vector2 and absf(scaled_uv.y - 100.0 / float(view.image_size.y)) < 0.001,
		"mask_offset_uv stays in source-image space when the view is scaled")
	var scaled_group: Control = view.get_node_or_null("RegionOverlays")
	ok(scaled_group != null and absf(scaled_group.offset_top - 200.0) < 1.0,
		"the translated overlay group scales the source-pixel mask offset to display pixels")
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

func _test_vine_image_loader_is_export_safe() -> void:
	var src := FileAccess.get_file_as_string("res://games/grove/vine/vine_map_view.gd")
	ok(src.find("ProjectSettings.globalize_path") == -1,
		"VineMapView loads res:// mask/bake images through the virtual filesystem, not exported-unsafe globalized paths")
	ok(src.find("_load_image_from_resource") != -1,
		"the image loader keeps a resource-system fallback (raw FileAccess fails for imported textures in an export)")

# REGRESSION (phone-only "purple wash" bug): an exported iOS/Android build ships imported textures
# only as the .ctex remap and STRIPS the raw PNG source, so the loader's FileAccess /
# Image.load_from_file reads return empty on device. Before the fix that fell through to
# _fallback_mask_image() — a full-WHITE mask — which makes every pixel read as in-mask and floods the
# whole map with the additive vine/ember/veil overlays (fine in the editor, wrong on the phone).
# Desktop can't reproduce the stripped-bytes condition (the raw file is present), so we exercise the
# device-recovery path directly: the resource-system fallback must hand back the REAL mask, not white.
func _test_mask_loader_survives_export_strip() -> void:
	var view: Control = VineMapView.new()
	var mask_path := String(VineMaps.entries()[0].get("mask", ""))
	ok(mask_path != "", "home map declares a mask path")
	var img: Image = view._load_image_from_resource(mask_path)
	ok(img != null and not img.is_empty(),
		"the resource fallback recovers the home mask when raw bytes are export-stripped")
	if img != null and not img.is_empty():
		img.convert(Image.FORMAT_RGBA8)
		var nonwhite := false
		for i in range(256):
			var c := img.get_pixel((i * 9973) % img.get_width(), (i * 7919) % img.get_height())
			if maxf(c.r, maxf(c.g, c.b)) < 0.98:
				nonwhite = true
				break
		ok(nonwhite, "the recovered mask carries real coverage, not the full-white flood fallback")
	view.free()

func _test_vine_debug_layer_modes() -> void:
	var e0: Dictionary = VineMaps.entries()[0]
	var view: Control = VineMapView.new()
	get_root().add_child(view)
	view.load_map(e0, VineMaps.regions_for(e0))
	view.set_debug_layer_mode("lock_only")
	var entry: Dictionary = view.region_overlays[0]
	ok(not (entry.get("vines") as TextureRect).visible, "lock_only hides vine strokes")
	ok((entry.get("lock") as TextureRect).visible, "lock_only keeps the lock veil visible")
	view.set_debug_layer_mode("no_lock")
	ok((entry.get("vines") as TextureRect).visible, "no_lock keeps vine strokes visible")
	ok(not (entry.get("lock") as TextureRect).visible, "no_lock hides the lock veil")
	view.set_debug_layer_mode("off")
	ok(not (entry.get("glow") as TextureRect).visible and not (entry.get("lock") as TextureRect).visible,
		"off hides every vine overlay layer")
	view.set_debug_layer_mode("bogus")
	ok(view.debug_layer_mode() == "all", "unknown debug layer modes fall back to all")
	view.queue_free()

func _test_vine_diagnostic_summary() -> void:
	var e0: Dictionary = VineMaps.entries()[0]
	var view: Control = VineMapView.new()
	get_root().add_child(view)
	view.load_map(e0, VineMaps.regions_for(e0))
	view.set_debug_layer_mode("vines_only")
	var diag: Dictionary = view.diagnostic_summary()
	ok(String(diag.get("debug_layer_mode", "")) == "vines_only", "diagnostic summary reports the active debug layer mode")
	ok((diag.get("image_size", []) as Array).size() == 2, "diagnostic summary includes image size")
	ok(int(diag.get("region_count", 0)) == view.region_count(), "diagnostic summary includes region count")
	ok((diag.get("overlays", []) as Array).size() == view.region_count(), "diagnostic summary includes per-region overlays")
	view.queue_free()

func _test_vine_device_debug_wiring() -> void:
	var map_src := FileAccess.get_file_as_string("res://engine/scripts/scenes/map.gd")
	ok(map_src.find("VINE_DIAG") != -1 and map_src.find("debug_cycle_vine_fx") != -1,
		"Map scene prints VINE_DIAG and exposes a vine layer-cycle debug action")
	var debug_src := FileAccess.get_file_as_string("res://engine/scripts/ui/debug.gd")
	ok(debug_src.find("debug_cycle_vine_fx") != -1 and debug_src.find("debug_vine_diag") != -1,
		"Debug panel wires vine layer-cycle and diagnostic actions when the host supports them")

# Every shipped vine map ships a pre-baked region-index map at the content-addressed path load_map()
# computes, so the game's first home render LOADS the warped raster (skipping the ~1.1s per-pixel noise +
# polygon pass) instead of building it live. A geometry edit moves the path; if the bake was not re-run
# (`make bake-vine`), the file is missing and this FAILS loudly. The first map also byte-checks that the
# committed PNG reproduces the live raster exactly (no data-channel corruption across the PNG round-trip).
func _test_region_map_prebaked() -> void:
	var entries := VineMaps.entries()
	ok(entries.size() >= 1, "maps.json ships at least one vine map to bake")
	var checked_fidelity := false
	for entry in entries:
		var regions: Array = VineMaps.regions_for(entry)
		if regions.is_empty():
			continue
		var view := VineMapView.new()
		view._load_art(entry)
		var isize: Vector2i = view.image_size
		view.free()
		var path := VineMapView.baked_region_map_path(isize, regions)
		var baked := VineMapView.new()._load_image(path)
		ok(baked != null and not baked.is_empty(),
			"map '%s' ships a baked region map (%s) — run `make bake-vine` after editing regions" % [String(entry.get("id", "?")), path.get_file()])
		if baked == null or checked_fidelity:
			continue
		baked.convert(Image.FORMAT_RGBA8)
		var live := VineMapView.render_region_map_image(isize, regions)
		live.convert(Image.FORMAT_RGBA8)
		ok(baked.get_size() == live.get_size() and baked.get_data() == live.get_data(),
			"map '%s' baked region map is byte-identical to the live raster" % String(entry.get("id", "?")))
		checked_fidelity = true

# REGRESSION (map-2 "no restore badge" bug): the merged Play/Restore CTA is PER-MAP, and _open_map
# must refresh it from the newly-opened map's next-unlock state.
func _test_unlock_badge_follows_map() -> void:
	fresh("vine_unlock_badge")
	var hx = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(hx)
	await create_timer(0.01).timeout
	if hx.content == null:
		hx._ready()
	await create_timer(0.05).timeout
	# complete the hub (every spot restored) + bank exp, then refresh chrome for the hub so Restore is
	# inactive. This is the "start on a finished hub" boot state.
	for sp in G.MAPS[G.hub_map()].spots:
		hx.unlocks[String(sp.id)] = true
	Save.grove()["unlocks"] = hx.unlocks
	Save.grove()["exp"] = 9999
	Save.grove_write()
	hx._map_idx = G.hub_map()
	hx._update_hud()
	await create_timer(0.05).timeout
	ok(not hx._unlock_ready(), "precondition: a fully-restored hub leaves Restore inactive")
	# now open the NEXT (in-progress) map — Restore MUST become active for its claimable spots
	var nz: int = G.hub_map() + 1
	ok(int(G.map_next_unlock(nz, hx.unlocks).k) >= 0, "precondition: the next map has a claimable spot")
	hx._open_map(nz)
	await create_timer(0.05).timeout
	ok(hx._unlock_ready(), "opening an in-progress map refreshes Restore readiness")
	hx.queue_free()

func _test_overlay_fills_view() -> void:
	fresh("vine_overlay_fit")
	var hx = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(hx)
	await create_timer(0.01).timeout
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

# The whole-class boot perf guard: building the REAL home (chrome + HUD + the vine hub) must do ZERO live
# per-pixel work — every bakeable sprite loads its baked mirror, and the warped region map loads its baked
# PNG. This is what catches "someone added boot art but forgot to bake it" WITHOUT any hand-maintained
# manifest: it drives the actual map.gd builders (not a replica) and asserts the live-fallback logs stayed
# empty. A failure names the offending asset(s) + the fix (`make bake-textures` / `make bake-vine`).
func _test_boot_does_zero_live_work() -> void:
	fresh("boot_zero_live")
	# Clear the bake-aware caches so this build re-runs the lookups (a warm cache would hide a live miss),
	# and the logs so we measure only THIS build.
	Kit.clear_clean_cache()
	Kit._live_polish_log.clear()
	VineMapView._art_cache.clear()
	VineMapView._live_region_raster_log.clear()
	var hx = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(hx)
	await create_timer(0.01).timeout
	if hx.content == null:
		hx._ready()
	await create_timer(0.05).timeout
	hx._open_map(G.hub_map())
	await create_timer(0.1).timeout
	if not Kit._live_polish_log.is_empty():
		print("        LIVE-POLISHED on boot (run `make bake-textures`): ", ", ".join(Kit._live_polish_log))
	ok(Kit._live_polish_log.is_empty(), "boot polishes zero bakeable sprites live (%d live)" % Kit._live_polish_log.size())
	if not VineMapView._live_region_raster_log.is_empty():
		print("        LIVE-RASTERED region maps on boot (run `make bake-vine`): ", VineMapView._live_region_raster_log)
	ok(VineMapView._live_region_raster_log.is_empty(), "boot rasterizes zero vine region maps live (%d live)" % VineMapView._live_region_raster_log.size())
	hx.queue_free()

func _test_map_integration() -> void:
	fresh("vine_map")
	var hx = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(hx)
	await create_timer(0.01).timeout
	if hx.content == null:
		hx._ready()
	await create_timer(0.05).timeout
	hx._open_map(G.hub_map())
	await create_timer(0.1).timeout
	# the hub renders through a VineMapView
	var vv: Control = hx.content.find_child("VineMapView", true, false)
	ok(vv != null, "the vine hub renders through a VineMapView")
	ok(vv != null and vv.mask_offset == VineMaps.mask_offset_for(G.MAPS[G.hub_map()].vine),
		"the runtime VineMapView uses the authored mask offset")
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

func _test_locked_zone_level_badges() -> void:
	fresh("zone_level_badges")
	var hx = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(hx)
	await create_timer(0.01).timeout
	if hx.content == null:
		hx._ready()
	await create_timer(0.05).timeout
	var z := G.hub_map()
	var k := 5
	var required_level := G.level_for_exp(_raw_zone_unlock_exp(z, k))
	Save.grove()["exp"] = G.exp_at_level(required_level) - 1
	hx._open_map(z)
	await create_timer(0.05).timeout
	ok(_has_zone_level_badge(hx.spot_hits[k].node, required_level),
		"a locked zone shows the shared level badge for its required level")
	Save.grove()["exp"] = G.exp_at_level(required_level)
	hx._open_map(z)
	await create_timer(0.05).timeout
	ok(not _has_zone_level_badge(hx.spot_hits[k].node, required_level),
		"the level badge hides once the player reaches the required level")
	hx.queue_free()

func _test_map_card_zone_progress() -> void:
	fresh("map_card_zone_progress")
	var hx = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(hx)
	await create_timer(0.01).timeout
	if hx.content == null:
		hx._ready()
	await create_timer(0.05).timeout
	var opts := Kit.map_card_opts_from_config({"map_card": {}, "gold_badge": {}})
	var card: Control = hx._make_card(G.hub_map(), 460.0, 160.0, opts)
	get_root().add_child(card)
	await create_timer(0.05).timeout
	ok(_has_label_text(card, "0/6"), "fresh map card shows unlocked zone progress as 0/6")
	ok(not _any_label_contains(card, "exp"), "fresh map card progress pill no longer shows total exp")
	card.queue_free()
	hx.queue_free()

# read the VineMapView's per-region enabled state (vines ON == enabled). set_region_enabled keeps
# region_overlays[i].enabled in sync (confirmed in vine_map_view.gd), so read that directly.
func _region_on(vv: Control, i: int) -> bool:
	return bool(vv.region_overlays[i].get("enabled", true))

func _has_label_text(node: Control, text: String) -> bool:
	for l in node.find_children("*", "Label", true, false):
		if String((l as Label).text) == text:
			return true
	return false

func _has_zone_level_badge(node: Control, level: int) -> bool:
	var wrap := node.find_child("ZoneLevelBadge", true, false) as Control
	if wrap == null:
		return false
	var badge := wrap.find_child("LevelBadge", true, false) as Control
	if badge == null:
		return false
	var num := badge.find_child("lv_num", true, false) as Label
	return num != null and num.text == str(level)

func _any_label_contains(node: Control, text: String) -> bool:
	for l in node.find_children("*", "Label", true, false):
		if String((l as Label).text).find(text) != -1:
			return true
	return false

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
	ok(VineMaps.mask_offset_for(e0) == Vector2(0, 100), "map1_farm exposes its authored mask offset")

# The authoring ladder still decides which LEVEL a region belongs to, but the live threshold floors
# to the start of that level. Example: Farm 6/7 maps into L7, so it opens at exp_at_level(7).
func _test_zone_unlocks_floor_to_required_level() -> void:
	var farm_6_raw := _raw_zone_unlock_exp(0, 5)
	var farm_6_level := G.level_for_exp(farm_6_raw)
	ok(farm_6_level == 7, "Farm 6/7 maps to required level 7")
	ok(G.spot_unlock_exp(0, 5) == G.exp_at_level(farm_6_level), "Farm 6/7 unlocks at the L7 floor")
	for z in G.MAPS.size():
		for k in G.MAPS[z].spots.size():
			var raw := _raw_zone_unlock_exp(z, k)
			var required_level := G.level_for_exp(raw)
			ok(G.spot_unlock_exp(z, k) == G.exp_at_level(required_level),
				"zone %d/%d unlocks at the floor of L%d" % [z, k, required_level])

func _raw_zone_unlock_exp(z: int, k: int) -> int:
	var cz: float = G.unlock_content_zone_exp()
	var last: int = G.MAPS.size() - 1
	var n: int = maxi(1, G.MAPS[z].spots.size())
	if z < last:
		return int(round(z * cz + (k + 1) * (cz / float(n))))
	var cap := G.GATE_CAP_FRACTION * cz
	return int(round(last * cz + (k + 1) * (cap / float(n))))

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

# All five game slots are driven by the five registered vine maps (mapN -> slot N), each with one spot
# per authored region. The region-less carve-out (a map registered before its regions are authored
# overlays with an EMPTY spot list — clean base art shown — and is NOT counted "done", so it never
# auto-unlocks the next map or invites residents) still holds; since every shipping map now has
# authored regions, it is exercised below on a SYNTHETIC region-less entry rather than a real slot.
func _test_multimap() -> void:
	ok(VineMaps.count() == G.MAPS.size(), "maps.json holds one vine entry per game slot (%d)" % G.MAPS.size())
	for z in G.MAPS.size():
		ok(G.MAPS[z].has("vine"), "slot %d is vine-driven from tool entry %d" % [z, z])
		ok(G.MAPS[z].spots.size() == VineMaps.regions_for(VineMaps.entries()[z]).size(), "slot %d spot count == its regions" % z)
		ok(not G.MAPS[z].spots.is_empty(), "slot %d ships authored regions (no longer region-less)" % z)
	# the carve-out, synthetically: a region-less entry derives ZERO spots, and a spot-less map is NOT "done"
	ok(VineMaps.spots_for("ghost", {"regions_path": ""}).is_empty(), "a region-less entry derives zero spots (clean base art)")
	G.MAPS.append({"id": "ghost_unauthored", "name": "Ghost", "spots": [], "vine": {}})
	ok(not G.map_spots_done(G.MAPS.size() - 1, {}), "a spot-less map is NOT 'done' (no auto-unlock / no residents)")
	G.MAPS.pop_back()
	# a slot WITH authored regions derives its spot ids from the slot id
	ok(String(G.MAPS[0].spots[0].id) == "%s_r0" % String(G.MAPS[0].id), "an authored slot's spot ids use the slot id")

func _test_spot_derivation() -> void:
	var e0: Dictionary = VineMaps.entries()[0]
	var regions := VineMaps.regions_for(e0)
	var n := regions.size()
	var spots := VineMaps.spots_for("farmhouse", e0)
	ok(n >= 1 and spots.size() == n, "one derived spot per region")
	ok(String(spots[0].id) == "farmhouse_r0" and String(spots[n - 1].id) == "farmhouse_r%d" % (n - 1), "spot ids are <slot>_r<index>")
	# a spot is id · name · pos — no per-spot cost (the unlock threshold is computed centrally by
	# G.spot_unlock_exp from the global spot order).
	ok(not spots[0].has("cost"), "a derived spot carries no cost field (cost ladder retired)")
	var p0: Vector2 = spots[0].pos
	ok(p0.x > 0.0 and p0.x < 1.0 and p0.y > 0.0 and p0.y < 1.0, "centroid pos is normalized into (0,1)")
	# override file wins when present (name)
	var ov := VineMaps.spots_for("ovtest", {"id": "ovtest", "regions_path": "res://games/grove/tests/fixtures/ov_regions.json"}, "res://games/grove/tests/fixtures/ov_spots.json")
	ok(ov.size() == 2 and String(ov[0].name) == "Cottage", "override file sets the spot name")

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
