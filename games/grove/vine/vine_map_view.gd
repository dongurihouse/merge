extends Control
class_name VineMapView
## Shared vine renderer: clean base + animated vine overlay (per-region shadow/glow/vines/embers),
## driven by a maps.json entry + its regions array. Used by BOTH the game (engine/scripts/scenes/map.gd)
## and the authoring tool (vine_mask_tool.gd). No editing UI, no save IO — pure rendering.

const VINE_SHADER := "res://games/tools/vine_mask_tool/shaders/ominous_vines.gdshader"
const SHADOW_SHADER := "res://games/tools/vine_mask_tool/shaders/vine_shadow.gdshader"
const EMBER_SHADER := "res://games/tools/vine_mask_tool/shaders/vine_embers.gdshader"
const LOCK_SHADER := "res://games/tools/vine_mask_tool/shaders/region_lock_tint.gdshader"
# The "locked region" cover: a light, see-through purple veil over every still-locked region,
# layered on top of the vines and cleared (with them) when the region's spot is bought.
const LOCK_TINT := Color(0.6863, 0.6627, 0.9255, 0.34)  # #AFA9EC at 34%
const VineMaps = preload("res://games/grove/vine/vine_maps.gd")

const COMPONENT_THRESHOLD := 0.25

# Per-region shader knobs. CANONICAL source: this is the authoritative shader-knob → param
# mapping. The authoring tool (vine_mask_tool.gd) mirrors it, adding slider-only fields
# (label/min/max/step). Both copies must be kept in sync whenever entries are added or changed.
const CONTROLS := [
	{"name": "GlowOpacity", "label": "Glow opacity", "target": "glow", "param": "opacity", "min": 0.0, "max": 1.0, "step": 0.01, "decimals": 2},
	{"name": "GlowPower", "label": "Glow power", "target": "glow", "param": "glow_strength", "min": 0.0, "max": 3.0, "step": 0.01, "decimals": 2},
	{"name": "GlowSize", "label": "Glow size", "target": "glow", "param": "glow_radius", "min": 0.0, "max": 0.03, "step": 0.001, "decimals": 3},
	{"name": "VineOpacity", "label": "Vine opacity", "target": "vines", "param": "opacity", "min": 0.0, "max": 1.2, "step": 0.01, "decimals": 2},
	{"name": "VinePower", "label": "Vine power", "target": "vines", "param": "glow_strength", "min": 0.0, "max": 2.0, "step": 0.01, "decimals": 2},
	{"name": "Sharpness", "label": "Sharpness", "target": "vines", "param": "edge_power", "min": 0.5, "max": 6.0, "step": 0.05, "decimals": 2},
	{"name": "PulseSpeed", "label": "Pulse speed", "target": "both", "param": "pulse_speed", "min": 0.0, "max": 5.0, "step": 0.05, "decimals": 2},
	{"name": "FlowSpeed", "label": "Flow speed", "target": "both", "param": "flow_speed", "min": 0.0, "max": 4.0, "step": 0.05, "decimals": 2},
	{"name": "Breathing", "label": "Breathing", "target": "vines", "param": "breath_strength", "min": 0.0, "max": 1.5, "step": 0.01, "decimals": 2},
	{"name": "Heartbeat", "label": "Heartbeat", "target": "vines", "param": "heartbeat_strength", "min": 0.0, "max": 1.5, "step": 0.01, "decimals": 2},
	{"name": "Lightning", "label": "Lightning", "target": "vines", "param": "lightning_strength", "min": 0.0, "max": 2.5, "step": 0.01, "decimals": 2},
	{"name": "Shimmer", "label": "Shimmer", "target": "vines", "param": "shimmer_strength", "min": 0.0, "max": 0.015, "step": 0.001, "decimals": 3},
	{"name": "EnergyCrawl", "label": "Energy crawl", "target": "vines", "param": "energy_crawl_strength", "min": 0.0, "max": 2.0, "step": 0.01, "decimals": 2},
	{"name": "Shadow", "label": "Shadow", "target": "shadow", "param": "shadow_opacity", "min": 0.0, "max": 0.65, "step": 0.01, "decimals": 2},
	{"name": "Embers", "label": "Embers", "target": "embers", "param": "ember_opacity", "min": 0.0, "max": 1.5, "step": 0.01, "decimals": 2},
]

var image_size := Vector2i(1, 1)
var mask_offset := Vector2.ZERO
var mask_image: Image
var mask_texture: ImageTexture
var region_map_texture: ImageTexture
var regions: Array = []
var _region_count := 1
var region_overlays: Array[Dictionary] = []
var controls: Array[Dictionary] = []
var glow_template_material: ShaderMaterial
var vines_template_material: ShaderMaterial
var shadow_template_material: ShaderMaterial
var ember_template_material: ShaderMaterial
var lock_template_material: ShaderMaterial
var _calm := false

func _init() -> void:
	controls.assign(CONTROLS.duplicate(true))

# ── Public API ───────────────────────────────────────────────────────────────

# Process-lifetime cache of the per-map raster artifacts (mask image/texture + region-index map).
# These are pure functions of (entry, regions) and that art never changes at runtime, yet _build_mask_image
# / _rebuild_region_map recompute them with per-pixel loops (~270ms) on EVERY map (re)build — the home-map
# unlock/resize freeze. Keyed on CONTENT so the authoring tool, which mutates geometry, naturally misses and
# recomputes; the game reopens the same map and hits.
static var _art_cache := {}

func load_map(entry: Dictionary, region_list: Array) -> void:
	regions = region_list.duplicate(true)
	_region_count = maxi(regions.size(), 1)   # depends only on regions; set it on the cache-hit path too
	var key := hash([entry, region_list])
	var cached: Dictionary = _art_cache.get(key, {})
	if not cached.is_empty():
		mask_image = cached["mask_image"]
		image_size = cached["image_size"]
		mask_texture = cached["mask_texture"]
		region_map_texture = cached["region_map"]
		custom_minimum_size = Vector2(image_size)
		size = Vector2(image_size)
		_build_templates()
	else:
		_load_art(entry)
		_build_templates()
		_rebuild_region_map()
		_art_cache[key] = {"mask_image": mask_image, "image_size": image_size,
			"mask_texture": mask_texture, "region_map": region_map_texture}
	_create_region_overlays(true)
	_apply_all_region_tuning()

func region_count() -> int:
	return _region_count

func set_region_enabled(index: int, on: bool) -> void:
	_set_region_enabled(index, on)

# Rebuild the region-index map + per-region overlays + re-apply tuning after the authoring tool
# changed geometry, the region set, or the mask_offset. The templates and mask image are reused
# (only load_map rebuilds those), so this is the cheap "the regions moved" refresh — it is NOT a
# full reload. Set mask_offset first; the overlay group is re-anchored to it here.
func refresh(region_list: Array) -> void:
	regions = region_list.duplicate(true)
	_rebuild_region_map()
	_create_region_overlays(true)
	_apply_all_region_tuning()

# ── Live tuning (one knob, one region) — public so the authoring tool's sliders write/read
# through the view without rebuilding overlays on every tick. ──────────────────────────────────

func write_shader_value(target: String, param: String, value: float, region_index: int) -> void:
	if region_overlays.is_empty():
		return
	_write_shader_value(target, param, value, region_index)

func read_shader_value(target: String, param: String, region_index: int) -> float:
	if region_overlays.is_empty():
		return 0.0
	var material := _material_for_target(target, region_index)
	var value: Variant = material.get_shader_parameter(param)
	if value == null:
		return 0.0
	return float(value)

# The pristine template value for a knob — what the tool's "Reset Region" restores and seeds its
# sliders from. Read from the never-mutated template materials so saved tuning never contaminates it.
func template_default(target: String, param: String) -> float:
	var material: ShaderMaterial
	match target:
		"glow":
			material = glow_template_material
		"shadow":
			material = shadow_template_material
		"embers":
			material = ember_template_material
		_:
			material = vines_template_material  # vines + "both" (matches _material_for_target fallback)
	if material == null:
		return 0.0
	var value: Variant = material.get_shader_parameter(param)
	return float(value) if value != null else 0.0

func set_mask_offset(value: Vector2) -> void:
	mask_offset = value
	var overlays := get_node_or_null("RegionOverlays") as Control
	if overlays != null:
		# Keep the group full-rect (tracking the view's size) and re-apply the offset via the four
		# offset_* fields, so its size keeps following the view while its position stays == mask_offset.
		overlays.set_anchors_preset(Control.PRESET_FULL_RECT)
		overlays.offset_left = mask_offset.x
		overlays.offset_top = mask_offset.y
		overlays.offset_right = mask_offset.x
		overlays.offset_bottom = mask_offset.y
	# The cover container stays full-view (offset 0); the shift is baked into the cover shader's UV so
	# the purple bleeds out to the edges instead of leaving an uncovered strip on the leading edge.
	var offset_uv := _mask_offset_uv()
	for entry in region_overlays:
		var lock := entry.get("lock") as TextureRect
		if lock != null:
			(lock.material as ShaderMaterial).set_shader_parameter("mask_offset_uv", offset_uv)

func set_calm(on: bool) -> void:
	# reduced-motion: damp the time-driven shader terms (pulse/flow) toward 0 across all overlays.
	_calm = on
	if not on:
		_apply_all_region_tuning()   # restore per-region pulse/flow that the calm-damp zeroed
		return
	for entry in region_overlays:
		for key in ["shadow", "glow", "vines", "embers"]:
			var rect := entry.get(key) as TextureRect
			if rect == null:
				continue
			var m := rect.material as ShaderMaterial
			m.set_shader_parameter("pulse_speed", 0.0)
			m.set_shader_parameter("flow_speed", 0.0)

# ── Art + mask load ──────────────────────────────────────────────────────────

func _load_art(entry: Dictionary) -> void:
	# region geometry + mask come from the mask image (CPU-loaded via Image.load_from_file, no import
	# needed); the BASE texture is the caller's concern (the game seats map1.png as a separate base layer
	# behind this view), so the view itself does not need the base imported.
	mask_image = _build_mask_image(entry)
	if mask_image == null or mask_image.is_empty():
		var s := _image_size_for(entry)
		image_size = Vector2i(int(s.x), int(s.y))
		mask_image = _fallback_mask_image()
	mask_image.convert(Image.FORMAT_RGBA8)
	image_size = Vector2i(mask_image.get_width(), mask_image.get_height())
	mask_texture = ImageTexture.create_from_image(mask_image)
	custom_minimum_size = Vector2(image_size)
	size = Vector2(image_size)

func _image_size_for(entry: Dictionary) -> Vector2:
	return VineMaps.image_size_for(entry)

func _build_mask_image(map_data: Dictionary) -> Image:
	var mode := String(map_data.get("mask_mode", ""))
	if mode == "purple_difference":
		return _build_purple_difference_mask(map_data)

	if String(map_data.get("mask", "")) != "":
		var image := _load_image(String(map_data["mask"]))
		if mode == "luminance":
			image = _bake_alpha_from_luminance(image)
		return image

	var mask_paths: Array = map_data.get("masks", [])
	if not mask_paths.is_empty():
		return _combine_mask_images(mask_paths)

	return null

# A white-on-black mask carries its coverage in RGB luminance but is fully opaque, so every
# pixel would read as "mask" (the detector and shaders gate on alpha). Bake alpha from the
# brightest channel; the shaders still sample the unchanged red channel for intensity.
func _bake_alpha_from_luminance(image: Image) -> Image:
	if image == null:
		return null
	image.convert(Image.FORMAT_RGBA8)
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var color := image.get_pixel(x, y)
			color.a = maxf(color.r, maxf(color.g, color.b))
			image.set_pixel(x, y, color)
	return image

func _build_purple_difference_mask(map_data: Dictionary) -> Image:
	var base := _load_image(String(map_data.get("base", "")))
	var clean := _load_image(String(map_data.get("clean", "")))
	if base == null or clean == null:
		return null
	base.convert(Image.FORMAT_RGBA8)
	clean.convert(Image.FORMAT_RGBA8)
	var width := mini(base.get_width(), clean.get_width())
	var height := mini(base.get_height(), clean.get_height())
	var threshold := float(map_data.get("difference_threshold", 0.16))
	var mask := Image.create(width, height, false, Image.FORMAT_RGBA8)
	mask.fill(Color(0.0, 0.0, 0.0, 0.0))
	for y in range(height):
		for x in range(width):
			var b := base.get_pixel(x, y)
			var c := clean.get_pixel(x, y)
			var diff := absf(b.r - c.r) + absf(b.g - c.g) + absf(b.b - c.b)
			var purple := b.b > b.g * 1.08 and b.r > b.g * 0.72 and b.b > 0.18
			if purple and diff > threshold:
				var strength := clampf((diff - threshold) * 2.7, 0.0, 1.0)
				mask.set_pixel(x, y, Color(strength, strength, strength, strength))
	return mask

func _combine_mask_images(mask_entries: Array) -> Image:
	var combined: Image
	for entry in mask_entries:
		var path := String(entry.get("path", "")) if entry is Dictionary else String(entry)
		var image := _load_image(path)
		if image == null:
			continue
		image.convert(Image.FORMAT_RGBA8)
		if combined == null:
			combined = Image.create(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8)
			combined.fill(Color(0.0, 0.0, 0.0, 0.0))
		for y in range(mini(combined.get_height(), image.get_height())):
			for x in range(mini(combined.get_width(), image.get_width())):
				var color := image.get_pixel(x, y)
				if color.a > 0.01 or maxf(color.r, maxf(color.g, color.b)) > COMPONENT_THRESHOLD:
					combined.set_pixel(x, y, Color(1.0, 1.0, 1.0, 1.0))
	return combined

func _load_image(path: String) -> Image:
	if path == "":
		return null
	return Image.load_from_file(ProjectSettings.globalize_path(path))

func _fallback_mask_image() -> Image:
	var image := Image.create(image_size.x, image_size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(1.0, 1.0, 1.0, 1.0))
	return image

func _mask_pixel_size() -> Vector2:
	return Vector2(1.0 / float(maxi(image_size.x, 1)), 1.0 / float(maxi(image_size.y, 1)))

# The mask image's on-screen size after STRETCH_KEEP_ASPECT_COVERED — used to convert the pixel
# mask_offset into a UV shift for the cover layer (which is full-view, not translated like the vines).
func _displayed_size() -> Vector2:
	var view_size := size
	if view_size.x <= 0.0 or view_size.y <= 0.0:
		view_size = Vector2(image_size)
	var s := maxf(view_size.x / float(maxi(image_size.x, 1)), view_size.y / float(maxi(image_size.y, 1)))
	return Vector2(image_size) * maxf(s, 0.0001)

func _mask_offset_uv() -> Vector2:
	var disp := _displayed_size()
	return Vector2(mask_offset.x / maxf(disp.x, 1.0), mask_offset.y / maxf(disp.y, 1.0))

# ── Template materials (built in code, mirroring the .tscn defaults) ──────────

func _build_templates() -> void:
	# ShaderMaterial_glow values from VineMaskTool.tscn.
	glow_template_material = _make_vine_material({
		"vine_color": Color(0.44, 0.02, 0.95, 1.0),
		"core_color": Color(0.88, 0.42, 1.0, 1.0),
		"opacity": 0.28,
		"glow_radius": 0.012,
		"glow_strength": 1.15,
		"pulse_speed": 1.35,
		"flow_speed": 0.65,
		"edge_power": 1.15,
		"breath_strength": 0.25,
		"heartbeat_strength": 0.25,
		"lightning_strength": 0.28,
		"shimmer_strength": 0.003,
		"energy_crawl_strength": 0.45,
	})
	# ShaderMaterial_vines values from VineMaskTool.tscn.
	vines_template_material = _make_vine_material({
		"vine_color": Color(0.58, 0.04, 1.0, 1.0),
		"core_color": Color(1.0, 0.76, 1.0, 1.0),
		"opacity": 0.48,
		"glow_radius": 0.004,
		"glow_strength": 0.42,
		"pulse_speed": 2.4,
		"flow_speed": 1.35,
		"edge_power": 2.8,
		"breath_strength": 0.35,
		"heartbeat_strength": 0.45,
		"lightning_strength": 0.65,
		"shimmer_strength": 0.004,
		"energy_crawl_strength": 0.75,
	})
	_create_effect_template_materials()

func _make_vine_material(params: Dictionary) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load(VINE_SHADER)
	for key in params:
		material.set_shader_parameter(key, params[key])
	material.set_shader_parameter("mask_texture", mask_texture)
	material.set_shader_parameter("mask_pixel_size", _mask_pixel_size())
	return material

func _create_effect_template_materials() -> void:
	shadow_template_material = ShaderMaterial.new()
	shadow_template_material.shader = load(SHADOW_SHADER)
	shadow_template_material.set_shader_parameter("mask_texture", mask_texture)
	shadow_template_material.set_shader_parameter("mask_pixel_size", _mask_pixel_size())

	ember_template_material = ShaderMaterial.new()
	ember_template_material.shader = load(EMBER_SHADER)
	ember_template_material.set_shader_parameter("mask_texture", mask_texture)

	lock_template_material = ShaderMaterial.new()
	lock_template_material.shader = load(LOCK_SHADER)
	lock_template_material.set_shader_parameter("tint_color", LOCK_TINT)

# ── Region-index map ──────────────────────────────────────────────────────────

func _rebuild_region_map() -> void:
	_region_count = maxi(regions.size(), 1)
	var image := Image.create(image_size.x, image_size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 1.0))
	var denominator := float(maxi(_region_count - 1, 1))

	for region_index in range(regions.size()):
		var region: Dictionary = regions[region_index]
		var points: Array = _region_points(region)
		if points.size() < 3:
			continue
		var bounds := _polygon_bounds(points)
		var encoded := float(region_index) / denominator
		# red = region index (vine shaders); green = membership flag, so the lock-tint shader can
		# fill the WHOLE polygon and tell region 0 (red 0.0) apart from the background (also 0.0).
		var color := Color(encoded, 1.0, 0.0, 1.0)
		var packed := _points_to_packed(points)
		for y in range(int(bounds.position.y), int(bounds.end.y) + 1):
			for x in range(int(bounds.position.x), int(bounds.end.x) + 1):
				if Geometry2D.is_point_in_polygon(Vector2(float(x) + 0.5, float(y) + 0.5), packed):
					image.set_pixel(x, y, color)

	region_map_texture = ImageTexture.create_from_image(image)
	_apply_region_map_to_materials()

# A region's points come either as Vector2 (tool, in-memory) or as [x, y] arrays (parsed JSON,
# the path the game takes). Normalize to Vector2 so the polygon math is source-agnostic.
func _region_points(region: Dictionary) -> Array:
	var raw: Array = region.get("points", [])
	var out: Array = []
	for p in raw:
		if p is Vector2:
			out.append(p)
		elif p is Array and (p as Array).size() >= 2:
			out.append(Vector2(float(p[0]), float(p[1])))
	return out

func _polygon_bounds(points: Array) -> Rect2:
	var min_x := float(image_size.x - 1)
	var min_y := float(image_size.y - 1)
	var max_x := 0.0
	var max_y := 0.0
	for point in points:
		var p: Vector2 = point
		min_x = minf(min_x, p.x)
		min_y = minf(min_y, p.y)
		max_x = maxf(max_x, p.x)
		max_y = maxf(max_y, p.y)
	var position := Vector2(clampf(floorf(min_x), 0.0, float(image_size.x - 1)), clampf(floorf(min_y), 0.0, float(image_size.y - 1)))
	var end := Vector2(clampf(ceilf(max_x), 0.0, float(image_size.x - 1)), clampf(ceilf(max_y), 0.0, float(image_size.y - 1)))
	return Rect2(position, end - position)

func _points_to_packed(points: Array) -> PackedVector2Array:
	var packed := PackedVector2Array()
	for point in points:
		packed.append(point)
	return packed

func _apply_region_map_to_materials() -> void:
	if region_map_texture == null:
		return
	for region_index in range(region_overlays.size()):
		var entry: Dictionary = region_overlays[region_index]
		for key in ["shadow", "glow", "vines", "embers", "lock"]:
			var rect := entry.get(key) as TextureRect
			if rect == null:
				continue
			var material := rect.material as ShaderMaterial
			material.set_shader_parameter("mask_texture", mask_texture)
			material.set_shader_parameter("region_map_texture", region_map_texture)
			material.set_shader_parameter("region_index", float(region_index))
			material.set_shader_parameter("region_count", float(_region_count))

# ── Overlays ──────────────────────────────────────────────────────────────────

func _create_region_overlays(force: bool) -> void:
	if not force and region_overlays.size() == _region_count:
		_apply_region_map_to_materials()
		return

	for node_name in ["RegionOverlays", "RegionCovers"]:
		var stale := get_node_or_null(node_name)
		if stale != null:
			remove_child(stale)
			stale.free()

	# Full-rect anchored to the view (so the group + its cover-fit children fill the SAME rect the
	# game's base layer cover-fits into), with mask_offset applied as a uniform offset shift — NOT a
	# fixed image-sized rect. In the game the view is seated full-rect over the clip frame, so the
	# overlays fill the frame and align with the base; in the tool the view is sized to image_size, so
	# full-rect == image_size shifted by mask_offset, giving position == mask_offset (the verifier's check).
	var parent := Control.new()
	parent.name = "RegionOverlays"
	parent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.offset_left = mask_offset.x
	parent.offset_top = mask_offset.y
	parent.offset_right = mask_offset.x
	parent.offset_bottom = mask_offset.y
	add_child(parent)

	# The purple cover lives in its OWN full-view container (NOT translated by mask_offset), added
	# after the offset group so it draws on top of the vines. Its shader bakes the offset into UV +
	# clamp-to-edge, so the cover always reaches the screen edges even when the mask is shifted.
	var covers := Control.new()
	covers.name = "RegionCovers"
	covers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	covers.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(covers)
	var offset_uv := _mask_offset_uv()

	region_overlays.clear()
	for region_index in range(_region_count):
		var shadow := _create_effect_texture_rect("Region%dShadow" % [region_index + 1], shadow_template_material, region_index)
		var glow := _create_region_texture_rect("Region%dGlow" % [region_index + 1], glow_template_material, region_index)
		var vines := _create_region_texture_rect("Region%dVines" % [region_index + 1], vines_template_material, region_index)
		var embers := _create_effect_texture_rect("Region%dEmbers" % [region_index + 1], ember_template_material, region_index)
		var lock := _create_effect_texture_rect("Region%dLock" % [region_index + 1], lock_template_material, region_index)
		(lock.material as ShaderMaterial).set_shader_parameter("mask_offset_uv", offset_uv)
		parent.add_child(shadow)
		parent.add_child(glow)
		parent.add_child(vines)
		parent.add_child(embers)
		covers.add_child(lock)
		var enabled := true
		if region_index < regions.size() and regions[region_index] is Dictionary:
			enabled = bool((regions[region_index] as Dictionary).get("enabled", true))
		region_overlays.append({"shadow": shadow, "glow": glow, "vines": vines, "embers": embers, "lock": lock, "enabled": enabled})
		_set_region_enabled(region_index, enabled)

func _create_region_texture_rect(node_name: String, template_material: ShaderMaterial, region_index: int) -> TextureRect:
	var rect := TextureRect.new()
	rect.name = node_name
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.layout_mode = 1
	rect.anchors_preset = Control.PRESET_FULL_RECT
	rect.anchor_right = 1.0
	rect.anchor_bottom = 1.0
	rect.grow_horizontal = Control.GROW_DIRECTION_BOTH
	rect.grow_vertical = Control.GROW_DIRECTION_BOTH
	rect.texture = mask_texture
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED

	var material := template_material.duplicate() as ShaderMaterial
	material.set_shader_parameter("mask_texture", mask_texture)
	material.set_shader_parameter("mask_pixel_size", _mask_pixel_size())
	material.set_shader_parameter("region_index", float(region_index))
	material.set_shader_parameter("region_count", float(_region_count))
	material.set_shader_parameter("region_enabled", 1.0)
	material.set_shader_parameter("region_map_texture", region_map_texture)
	rect.material = material
	return rect

func _create_effect_texture_rect(node_name: String, template_material: ShaderMaterial, region_index: int) -> TextureRect:
	var rect := TextureRect.new()
	rect.name = node_name
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.layout_mode = 1
	rect.anchors_preset = Control.PRESET_FULL_RECT
	rect.anchor_right = 1.0
	rect.anchor_bottom = 1.0
	rect.grow_horizontal = Control.GROW_DIRECTION_BOTH
	rect.grow_vertical = Control.GROW_DIRECTION_BOTH
	rect.texture = mask_texture
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED

	var material := template_material.duplicate() as ShaderMaterial
	material.set_shader_parameter("mask_texture", mask_texture)
	material.set_shader_parameter("region_index", float(region_index))
	material.set_shader_parameter("region_count", float(_region_count))
	material.set_shader_parameter("region_enabled", 1.0)
	material.set_shader_parameter("region_map_texture", region_map_texture)
	rect.material = material
	return rect

# ── Tuning + toggle ───────────────────────────────────────────────────────────

func _apply_all_region_tuning() -> void:
	for region_index in range(mini(regions.size(), region_overlays.size())):
		_apply_region_tuning(region_index)

func _apply_region_tuning(region_index: int) -> void:
	if region_index < 0 or region_index >= regions.size():
		return
	var region: Dictionary = regions[region_index]
	var tuning: Dictionary = region.get("tuning", {})
	if tuning.is_empty():
		return
	for control in controls:
		var key := String(control["name"])
		if tuning.has(key):
			_write_shader_value(control["target"], control["param"], float(tuning[key]), region_index)

func _write_shader_value(target: String, param: String, value: float, region_index: int) -> void:
	if target == "both":
		_material_for_target("glow", region_index).set_shader_parameter(param, value)
		_material_for_target("vines", region_index).set_shader_parameter(param, value)
		return
	_material_for_target(target, region_index).set_shader_parameter(param, value)

func _material_for_target(target: String, region_index: int) -> ShaderMaterial:
	var entry: Dictionary = region_overlays[clampi(region_index, 0, maxi(region_overlays.size() - 1, 0))]
	var key := target
	if not entry.has(key):
		key = "vines"
	var rect := entry[key] as TextureRect
	return rect.material as ShaderMaterial

func _set_region_enabled(region_index: int, enabled: bool) -> void:
	if region_index < 0 or region_index >= region_overlays.size():
		return
	# With zero regions the view still builds ONE fallback overlay (_region_count floors at 1), so
	# region_index can sit past the end of an empty `regions`. Only sync the backing region's flag
	# when it exists; the overlay materials below update either way. (Manual authoring can clear all
	# polygons — without this guard delete-to-empty / opening an empty map throws out-of-bounds.)
	if region_index < regions.size() and regions[region_index] is Dictionary:
		var region: Dictionary = regions[region_index]
		region["enabled"] = enabled
		regions[region_index] = region

	var entry: Dictionary = region_overlays[region_index]
	entry["enabled"] = enabled
	for key in ["shadow", "glow", "vines", "embers", "lock"]:
		var rect := entry.get(key) as TextureRect
		if rect == null:
			continue
		var material := rect.material as ShaderMaterial
		material.set_shader_parameter("region_enabled", 1.0 if enabled else 0.0)
		rect.visible = enabled
	region_overlays[region_index] = entry
