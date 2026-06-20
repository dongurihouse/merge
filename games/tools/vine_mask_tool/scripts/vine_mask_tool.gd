extends Control

const RegionEditorOverlay := preload("res://games/tools/vine_mask_tool/scripts/region_editor_overlay.gd")
const ShadowShader := preload("res://games/tools/vine_mask_tool/shaders/vine_shadow.gdshader")
const EmberShader := preload("res://games/tools/vine_mask_tool/shaders/vine_embers.gdshader")
const MAPS_PATH := "res://games/tools/vine_mask_tool/maps/maps.json"
const DEFAULT_MAP_ID := "map1_farm"
const COMPONENT_THRESHOLD := 0.25
const MIN_COMPONENT_PIXELS := 420
const DEFAULT_REGION_COUNT := 8
const HULL_PADDING := 10.0

@onready var artwork_frame: Control = $Workspace/ArtworkFrame
@onready var base_rect: TextureRect = $Workspace/ArtworkFrame/Base
@onready var glow_template: TextureRect = $Workspace/ArtworkFrame/PurpleGlow
@onready var vines_template: TextureRect = $Workspace/ArtworkFrame/LivingVines

var maps: Array[Dictionary] = []
var current_map_index := 0
var current_map: Dictionary = {}
var current_map_id := ""
var image_size := Vector2i(941, 1672)
var regions_path := ""
var mask_image: Image
var mask_texture: Texture2D
var regions: Array = []
var region_count := 1
var region_overlays: Array[Dictionary] = []
var controls: Array[Dictionary] = []
var sliders: Dictionary = {}
var value_labels: Dictionary = {}
var region_map_texture: ImageTexture
var shadow_template_material: ShaderMaterial
var ember_template_material: ShaderMaterial
var selected_region := 0
var updating_ui := false
var region_editor: Control
var map_select: OptionButton
var region_select: OptionButton
var enable_region: CheckBox
var edit_regions_toggle: CheckButton

func _ready() -> void:
	custom_minimum_size = Vector2(1380.0, 1672.0)
	_load_maps()
	if maps.is_empty():
		push_error("Vine mask tool has no maps in %s" % MAPS_PATH)
		return
	current_map_index = _default_map_index()
	_apply_current_map()
	_build_panel()
	_create_region_editor()
	_select_region(0)

func get_map_count() -> int:
	return maps.size()

func get_current_map_id() -> String:
	return current_map_id

func get_region_count() -> int:
	return region_count

func get_region_point_count(region_index: int) -> int:
	if region_index < 0 or region_index >= regions.size():
		return 0
	var region: Dictionary = regions[region_index]
	var points: Array = region.get("points", [])
	return points.size()

func get_shared_point_count() -> int:
	if region_editor != null and region_editor.has_method("get_shared_merge_count"):
		return int(region_editor.call("get_shared_merge_count"))
	return 0

func set_region_point(region_index: int, point_index: int, position: Vector2) -> void:
	if region_editor != null and region_editor.has_method("set_region_point"):
		region_editor.call("set_region_point", region_index, point_index, position)
		return

	if region_index < 0 or region_index >= regions.size():
		return
	var region: Dictionary = regions[region_index]
	var points: Array = region.get("points", [])
	if point_index < 0 or point_index >= points.size():
		return
	points[point_index] = _clamp_to_image(position)
	region["points"] = points
	regions[region_index] = region
	_on_regions_changed(regions)

func auto_detect_regions() -> void:
	regions = _detect_regions_from_mask()
	_refresh_regions_from_polygons()
	if region_editor != null:
		region_editor.call("set_regions", regions)

func _load_maps() -> void:
	maps.clear()
	var file := FileAccess.open(MAPS_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var data: Dictionary = parsed
	var entries: Array = data.get("maps", [])
	for entry in entries:
		if entry is Dictionary and String(entry.get("id", "")) != "":
			maps.append(entry)

func _default_map_index() -> int:
	for index in range(maps.size()):
		if String(maps[index].get("id", "")) == DEFAULT_MAP_ID:
			return index
	return 0

func _apply_current_map() -> void:
	current_map = maps[clampi(current_map_index, 0, maps.size() - 1)]
	current_map_id = String(current_map.get("id", "map_%d" % [current_map_index + 1]))
	regions_path = String(current_map.get("regions_path", "res://games/tools/vine_mask_tool/maps/%s_regions.json" % current_map_id))
	_load_art_for_current_map()
	_create_effect_template_materials()
	_load_saved_regions_or_detect()
	_rebuild_region_map()
	_create_region_overlays(true)

func _load_art_for_current_map() -> void:
	var base_path := String(current_map.get("base", ""))
	var base_texture := load(base_path) as Texture2D
	if base_texture != null:
		base_rect.texture = base_texture
		image_size = Vector2i(int(base_texture.get_size().x), int(base_texture.get_size().y))

	mask_image = _build_mask_image(current_map)
	if mask_image == null or mask_image.is_empty():
		mask_image = _fallback_mask_image()
	mask_image.convert(Image.FORMAT_RGBA8)
	image_size = Vector2i(mask_image.get_width(), mask_image.get_height())
	mask_texture = ImageTexture.create_from_image(mask_image)

	artwork_frame.custom_minimum_size = Vector2(image_size)
	artwork_frame.size = Vector2(image_size)
	glow_template.texture = mask_texture
	vines_template.texture = mask_texture
	_update_template_shader_masks()

func _build_mask_image(map_data: Dictionary) -> Image:
	if String(map_data.get("mask", "")) != "":
		return _load_image(String(map_data["mask"]))

	if String(map_data.get("mask_mode", "")) == "purple_difference":
		return _build_purple_difference_mask(map_data)

	var mask_paths: Array = map_data.get("masks", [])
	if not mask_paths.is_empty():
		return _combine_mask_images(mask_paths)

	return null

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

func _create_effect_template_materials() -> void:
	_update_template_shader_masks()

	shadow_template_material = ShaderMaterial.new()
	shadow_template_material.shader = ShadowShader
	shadow_template_material.set_shader_parameter("mask_texture", mask_texture)
	shadow_template_material.set_shader_parameter("mask_pixel_size", _mask_pixel_size())

	ember_template_material = ShaderMaterial.new()
	ember_template_material.shader = EmberShader
	ember_template_material.set_shader_parameter("mask_texture", mask_texture)

func _update_template_shader_masks() -> void:
	for template in [glow_template, vines_template]:
		if template == null:
			continue
		var material := template.material as ShaderMaterial
		if material == null:
			continue
		material.set_shader_parameter("mask_texture", mask_texture)
		material.set_shader_parameter("mask_pixel_size", _mask_pixel_size())

func _mask_pixel_size() -> Vector2:
	return Vector2(1.0 / float(maxi(image_size.x, 1)), 1.0 / float(maxi(image_size.y, 1)))

func _load_saved_regions_or_detect() -> void:
	regions = _load_saved_regions()
	if regions.is_empty():
		regions = _detect_regions_from_mask()

func _load_saved_regions() -> Array:
	if regions_path == "" or not FileAccess.file_exists(regions_path):
		return []

	var file := FileAccess.open(regions_path, FileAccess.READ)
	if file == null:
		return []

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return []

	var data: Dictionary = parsed
	if not data.has("regions") or not (data["regions"] is Array):
		return []

	var loaded: Array = []
	for region_data in data["regions"]:
		if not (region_data is Dictionary) or not region_data.has("points"):
			continue
		var points: Array = []
		for point_value in region_data["points"]:
			if point_value is Array and point_value.size() >= 2:
				points.append(_clamp_to_image(Vector2(float(point_value[0]), float(point_value[1]))))
		if points.size() >= 3:
			loaded.append({
				"name": str(region_data.get("name", "Region %d" % [loaded.size() + 1])),
				"points": points,
				"enabled": bool(region_data.get("enabled", true))
			})
	return loaded if loaded.size() == _target_region_count() else []

func _detect_regions_from_mask() -> Array:
	if mask_image == null or mask_image.is_empty():
		return _fallback_regions()

	mask_image.convert(Image.FORMAT_RGBA8)
	var width := mask_image.get_width()
	var height := mask_image.get_height()
	var total := width * height
	var visited := PackedByteArray()
	visited.resize(total)
	visited.fill(0)
	var detected: Array = []

	for start in range(total):
		if visited[start] != 0:
			continue
		var sx := start % width
		var sy := int(start / width)
		if not _is_mask_pixel(mask_image, sx, sy):
			visited[start] = 1
			continue

		var bounds := _collect_component(mask_image, visited, sx, sy, width, height)
		if int(bounds["count"]) < MIN_COMPONENT_PIXELS:
			continue
		detected.append(_bounds_to_region(bounds, detected.size()))

	detected.sort_custom(_sort_regions_by_size)
	var target := _target_region_count()
	if detected.size() > target:
		detected = detected.slice(0, target)
	detected.sort_custom(_sort_regions_by_position)
	for index in range(detected.size()):
		var region: Dictionary = detected[index]
		region["name"] = "Region %d" % [index + 1]
		detected[index] = region

	return detected if detected.size() == target else _fallback_regions()

func _target_region_count() -> int:
	return int(current_map.get("region_count", DEFAULT_REGION_COUNT))

func _collect_component(source_mask: Image, visited: PackedByteArray, sx: int, sy: int, width: int, height: int) -> Dictionary:
	var stack: Array[int] = [sy * width + sx]
	visited[sy * width + sx] = 1
	var min_x := sx
	var max_x := sx
	var min_y := sy
	var max_y := sy
	var count := 0

	while not stack.is_empty():
		var current: int = int(stack.pop_back())
		var x := current % width
		var y := int(current / width)
		count += 1
		min_x = mini(min_x, x)
		max_x = maxi(max_x, x)
		min_y = mini(min_y, y)
		max_y = maxi(max_y, y)

		_try_add_component_neighbor(source_mask, visited, stack, x - 1, y, width, height)
		_try_add_component_neighbor(source_mask, visited, stack, x + 1, y, width, height)
		_try_add_component_neighbor(source_mask, visited, stack, x, y - 1, width, height)
		_try_add_component_neighbor(source_mask, visited, stack, x, y + 1, width, height)

	return {"min_x": min_x, "max_x": max_x, "min_y": min_y, "max_y": max_y, "count": count}

func _try_add_component_neighbor(source_mask: Image, visited: PackedByteArray, stack: Array[int], x: int, y: int, width: int, height: int) -> void:
	if x < 0 or x >= width or y < 0 or y >= height:
		return
	var index := y * width + x
	if visited[index] != 0:
		return
	visited[index] = 1
	if _is_mask_pixel(source_mask, x, y):
		stack.append(index)

func _is_mask_pixel(source_mask: Image, x: int, y: int) -> bool:
	var color := source_mask.get_pixel(x, y)
	return color.a > COMPONENT_THRESHOLD or maxf(color.r, maxf(color.g, color.b)) > COMPONENT_THRESHOLD

func _bounds_to_region(bounds: Dictionary, index: int) -> Dictionary:
	var min_x := clampf(float(bounds["min_x"]) - HULL_PADDING, 0.0, float(image_size.x - 1))
	var max_x := clampf(float(bounds["max_x"]) + HULL_PADDING, 0.0, float(image_size.x - 1))
	var min_y := clampf(float(bounds["min_y"]) - HULL_PADDING, 0.0, float(image_size.y - 1))
	var max_y := clampf(float(bounds["max_y"]) + HULL_PADDING, 0.0, float(image_size.y - 1))
	return {
		"name": "Region %d" % [index + 1],
		"pixels": int(bounds["count"]),
		"points": _box_points_8(min_x, min_y, max_x, max_y),
		"enabled": true
	}

func _fallback_regions() -> Array:
	var fallback: Array = []
	var box_width := float(image_size.x - 1) / float(_target_region_count())
	for index in range(_target_region_count()):
		var min_x := box_width * float(index)
		var max_x := box_width * float(index + 1)
		fallback.append({
			"name": "Region %d" % [index + 1],
			"points": _box_points_8(min_x, 0.0, max_x, float(image_size.y - 1)),
			"enabled": true
		})
	return fallback

func _box_points_8(min_x: float, min_y: float, max_x: float, max_y: float) -> Array:
	var mid_x := (min_x + max_x) * 0.5
	var mid_y := (min_y + max_y) * 0.5
	return [
		Vector2(min_x, min_y),
		Vector2(mid_x, min_y),
		Vector2(max_x, min_y),
		Vector2(max_x, mid_y),
		Vector2(max_x, max_y),
		Vector2(mid_x, max_y),
		Vector2(min_x, max_y),
		Vector2(min_x, mid_y)
	]

func _sort_regions_by_position(a: Dictionary, b: Dictionary) -> bool:
	var ap: Array = a["points"]
	var bp: Array = b["points"]
	return (ap[0] as Vector2).y < (bp[0] as Vector2).y if absf((ap[0] as Vector2).y - (bp[0] as Vector2).y) > 16.0 else (ap[0] as Vector2).x < (bp[0] as Vector2).x

func _sort_regions_by_size(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("pixels", 0)) > int(b.get("pixels", 0))

func _refresh_regions_from_polygons() -> void:
	_rebuild_region_map()
	_create_region_overlays(true)
	_refresh_region_select_items()
	_select_region(mini(selected_region, region_count - 1))

func _rebuild_region_map() -> void:
	region_count = maxi(regions.size(), 1)
	var image := Image.create(image_size.x, image_size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 1.0))
	var denominator := float(maxi(region_count - 1, 1))

	for region_index in range(regions.size()):
		var region: Dictionary = regions[region_index]
		var points: Array = region.get("points", [])
		if points.size() < 3:
			continue
		var bounds := _polygon_bounds(points)
		var encoded := float(region_index) / denominator
		var color := Color(encoded, 0.0, 0.0, 1.0)
		var packed := _points_to_packed(points)
		for y in range(int(bounds.position.y), int(bounds.end.y) + 1):
			for x in range(int(bounds.position.x), int(bounds.end.x) + 1):
				if Geometry2D.is_point_in_polygon(Vector2(float(x) + 0.5, float(y) + 0.5), packed):
					image.set_pixel(x, y, color)

	region_map_texture = ImageTexture.create_from_image(image)
	_apply_region_map_to_materials()

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

func _create_region_overlays(force: bool) -> void:
	if not force and region_overlays.size() == region_count:
		_apply_region_map_to_materials()
		return

	glow_template.visible = false
	vines_template.visible = false

	var existing := artwork_frame.get_node_or_null("RegionOverlays")
	if existing != null:
		artwork_frame.remove_child(existing)
		existing.free()

	var parent := Control.new()
	parent.name = "RegionOverlays"
	parent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	artwork_frame.add_child(parent)

	region_overlays.clear()
	for region_index in range(region_count):
		var shadow := _create_effect_texture_rect("Region%dShadow" % [region_index + 1], shadow_template_material, region_index)
		var glow := _create_region_texture_rect("Region%dGlow" % [region_index + 1], glow_template, region_index)
		var vines := _create_region_texture_rect("Region%dVines" % [region_index + 1], vines_template, region_index)
		var embers := _create_effect_texture_rect("Region%dEmbers" % [region_index + 1], ember_template_material, region_index)
		parent.add_child(shadow)
		parent.add_child(glow)
		parent.add_child(vines)
		parent.add_child(embers)
		region_overlays.append({"shadow": shadow, "glow": glow, "vines": vines, "embers": embers, "enabled": bool((regions[region_index] as Dictionary).get("enabled", true))})
		_set_region_enabled(region_index, bool((regions[region_index] as Dictionary).get("enabled", true)))

func _create_region_texture_rect(node_name: String, template: TextureRect, region_index: int) -> TextureRect:
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
	rect.stretch_mode = template.stretch_mode

	var material := (template.material as ShaderMaterial).duplicate() as ShaderMaterial
	material.set_shader_parameter("mask_texture", mask_texture)
	material.set_shader_parameter("mask_pixel_size", _mask_pixel_size())
	material.set_shader_parameter("region_index", float(region_index))
	material.set_shader_parameter("region_count", float(region_count))
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
	rect.stretch_mode = glow_template.stretch_mode

	var material := template_material.duplicate() as ShaderMaterial
	material.set_shader_parameter("mask_texture", mask_texture)
	material.set_shader_parameter("region_index", float(region_index))
	material.set_shader_parameter("region_count", float(region_count))
	material.set_shader_parameter("region_enabled", 1.0)
	material.set_shader_parameter("region_map_texture", region_map_texture)
	rect.material = material
	return rect

func _apply_region_map_to_materials() -> void:
	if region_map_texture == null:
		return
	for region_index in range(region_overlays.size()):
		var entry: Dictionary = region_overlays[region_index]
		for key in ["shadow", "glow", "vines", "embers"]:
			var rect := entry[key] as TextureRect
			if rect == null:
				continue
			var material := rect.material as ShaderMaterial
			material.set_shader_parameter("mask_texture", mask_texture)
			material.set_shader_parameter("region_map_texture", region_map_texture)
			material.set_shader_parameter("region_index", float(region_index))
			material.set_shader_parameter("region_count", float(region_count))

func _build_panel() -> void:
	controls = [
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
	for control in controls:
		control["default"] = _read_shader_value(control["target"], control["param"], selected_region)

	var panel := PanelContainer.new()
	panel.name = "LiveTuningPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.offset_left = float(image_size.x + 24)
	panel.offset_top = 16.0
	panel.offset_right = float(image_size.x + 424)
	panel.offset_bottom = 0.0

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.018, 0.04, 0.82)
	style.border_color = Color(0.7, 0.25, 1.0, 0.42)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_top = 10
	style.content_margin_right = 12
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	panel.add_child(stack)

	_add_map_controls(stack)

	var title := Label.new()
	title.text = "Vine Region Tuning"
	title.add_theme_font_size_override("font_size", 16)
	stack.add_child(title)

	_add_region_controls(stack)
	for control in controls:
		_add_slider(stack, control)

	var reset := Button.new()
	reset.text = "Reset Region"
	reset.pressed.connect(_reset_selected_region)
	stack.add_child(reset)
	add_child(panel)

func _add_map_controls(stack: VBoxContainer) -> void:
	var map_row := HBoxContainer.new()
	map_row.add_theme_constant_override("separation", 8)
	stack.add_child(map_row)

	var map_label := Label.new()
	map_label.text = "Map"
	map_label.custom_minimum_size = Vector2(104.0, 0.0)
	map_row.add_child(map_label)

	map_select = OptionButton.new()
	map_select.name = "MapSelect"
	map_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for index in range(maps.size()):
		map_select.add_item(String(maps[index].get("name", maps[index].get("id", "Map %d" % [index + 1]))), index)
	map_select.select(current_map_index)
	map_select.item_selected.connect(_on_map_selected)
	map_row.add_child(map_select)

func _add_region_controls(stack: VBoxContainer) -> void:
	var region_row := HBoxContainer.new()
	region_row.add_theme_constant_override("separation", 8)
	stack.add_child(region_row)

	var region_label := Label.new()
	region_label.text = "Region"
	region_label.custom_minimum_size = Vector2(104.0, 0.0)
	region_row.add_child(region_label)

	region_select = OptionButton.new()
	region_select.name = "RegionSelect"
	region_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	region_select.item_selected.connect(_select_region)
	region_row.add_child(region_select)

	enable_region = CheckBox.new()
	enable_region.name = "EnableRegion"
	enable_region.text = "On"
	enable_region.button_pressed = true
	enable_region.toggled.connect(_set_selected_region_enabled)
	region_row.add_child(enable_region)

	var edit_row := HBoxContainer.new()
	edit_row.add_theme_constant_override("separation", 8)
	stack.add_child(edit_row)

	edit_regions_toggle = CheckButton.new()
	edit_regions_toggle.name = "EditRegionsToggle"
	edit_regions_toggle.text = "Edit Regions"
	edit_regions_toggle.toggled.connect(_set_edit_regions_enabled)
	edit_row.add_child(edit_regions_toggle)

	var auto := Button.new()
	auto.name = "AutoDetectRegions"
	auto.text = "Auto Detect"
	auto.pressed.connect(auto_detect_regions)
	edit_row.add_child(auto)

	var save := Button.new()
	save.name = "SaveRegions"
	save.text = "Save Regions"
	save.pressed.connect(_save_regions_to_file)
	edit_row.add_child(save)

	_refresh_region_select_items()

func _add_slider(stack: VBoxContainer, config: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	stack.add_child(row)

	var name_label := Label.new()
	name_label.text = config["label"]
	name_label.custom_minimum_size = Vector2(104.0, 0.0)
	row.add_child(name_label)

	var slider := HSlider.new()
	slider.name = config["name"]
	slider.min_value = config["min"]
	slider.max_value = config["max"]
	slider.step = config["step"]
	slider.value = _read_shader_value(config["target"], config["param"], selected_region)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	sliders[config["name"]] = slider

	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(48.0, 0.0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)
	value_labels[config["name"]] = value_label

	_update_value_label(value_label, slider.value, config["decimals"])
	slider.value_changed.connect(_on_slider_changed.bind(config["target"], config["param"], value_label, config["decimals"]))

func _create_region_editor() -> void:
	if region_editor != null:
		region_editor.queue_free()
	region_editor = RegionEditorOverlay.new()
	region_editor.name = "RegionEditor"
	region_editor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	region_editor.call("set_image_size", Vector2(image_size))
	region_editor.call("set_regions", regions)
	region_editor.call("set_selected_region", selected_region)
	region_editor.call("set_edit_enabled", false)
	region_editor.regions_changed.connect(_on_regions_changed)
	region_editor.selection_changed.connect(_select_region)
	artwork_frame.add_child(region_editor)

func _on_map_selected(index: int) -> void:
	if index == current_map_index:
		return
	current_map_index = clampi(index, 0, maps.size() - 1)
	_remove_live_controls()
	selected_region = 0
	sliders.clear()
	value_labels.clear()
	_apply_current_map()
	_build_panel()
	_create_region_editor()
	_select_region(0)

func _remove_live_controls() -> void:
	var panel := get_node_or_null("LiveTuningPanel")
	if panel != null:
		remove_child(panel)
		panel.queue_free()
	var existing_editor := artwork_frame.get_node_or_null("RegionEditor")
	if existing_editor != null:
		artwork_frame.remove_child(existing_editor)
		existing_editor.queue_free()
	region_editor = null

func _refresh_region_select_items() -> void:
	if region_select == null:
		return
	region_select.clear()
	for index in range(region_count):
		var region: Dictionary = regions[index]
		region_select.add_item(str(region.get("name", "Region %d" % [index + 1])), index)
	region_select.select(clampi(selected_region, 0, region_count - 1))

func _select_region(index: int) -> void:
	selected_region = clampi(index, 0, max(region_count - 1, 0))
	updating_ui = true
	if region_select != null:
		region_select.select(selected_region)
	if region_editor != null:
		region_editor.call("set_selected_region", selected_region)

	var enabled := _region_is_enabled(selected_region)
	if enable_region != null:
		enable_region.button_pressed = enabled

	for control in controls:
		var slider := sliders.get(control["name"]) as HSlider
		var label := value_labels.get(control["name"]) as Label
		if slider != null:
			slider.value = _read_shader_value(control["target"], control["param"], selected_region)
		if label != null and slider != null:
			_update_value_label(label, slider.value, control["decimals"])
	updating_ui = false

func _set_edit_regions_enabled(enabled: bool) -> void:
	if region_editor != null:
		region_editor.call("set_edit_enabled", enabled)

func _set_selected_region_enabled(enabled: bool) -> void:
	if updating_ui:
		return
	_set_region_enabled(selected_region, enabled)

func _set_region_enabled(region_index: int, enabled: bool) -> void:
	if region_index < 0 or region_index >= region_overlays.size():
		return
	var region: Dictionary = regions[region_index]
	region["enabled"] = enabled
	regions[region_index] = region

	var entry: Dictionary = region_overlays[region_index]
	entry["enabled"] = enabled
	for key in ["shadow", "glow", "vines", "embers"]:
		var rect := entry[key] as TextureRect
		var material := rect.material as ShaderMaterial
		material.set_shader_parameter("region_enabled", 1.0 if enabled else 0.0)
		rect.visible = enabled
	region_overlays[region_index] = entry

func _region_is_enabled(region_index: int) -> bool:
	if region_index < 0 or region_index >= regions.size():
		return false
	var region: Dictionary = regions[region_index]
	return bool(region.get("enabled", true))

func _on_slider_changed(value: float, target: String, param: String, value_label: Label, decimals: int) -> void:
	if updating_ui:
		return
	_write_shader_value(target, param, value, selected_region)
	_update_value_label(value_label, value, decimals)

func _read_shader_value(target: String, param: String, region_index: int) -> float:
	if region_overlays.is_empty():
		return 0.0
	var material := _material_for_target(target, region_index)
	var value: Variant = material.get_shader_parameter(param)
	if value == null:
		return 0.0
	return float(value)

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

func _update_value_label(label: Label, value: float, decimals: int) -> void:
	if decimals == 3:
		label.text = "%.3f" % value
	elif decimals == 2:
		label.text = "%.2f" % value
	else:
		label.text = "%.1f" % value

func _reset_selected_region() -> void:
	for control in controls:
		var value := float(control["default"])
		_write_shader_value(control["target"], control["param"], value, selected_region)
		var slider := sliders.get(control["name"]) as HSlider
		if slider != null:
			slider.value = value

func _on_regions_changed(next_regions: Array) -> void:
	regions = _clone_regions(next_regions)
	_refresh_regions_from_polygons()

func _save_regions_to_file() -> void:
	var data := {
		"map_id": current_map_id,
		"image_size": [image_size.x, image_size.y],
		"mode": "auto_detected_mask_regions",
		"regions": []
	}
	for index in range(regions.size()):
		var region: Dictionary = regions[index]
		var serialized_points: Array = []
		for point in region.get("points", []):
			serialized_points.append([roundi(point.x), roundi(point.y)])
		data["regions"].append({
			"name": str(region.get("name", "Region %d" % [index + 1])),
			"enabled": bool(region.get("enabled", true)),
			"points": serialized_points
		})

	var path := ProjectSettings.globalize_path(regions_path)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "  "))

func _points_to_packed(points: Array) -> PackedVector2Array:
	var packed := PackedVector2Array()
	for point in points:
		packed.append(point)
	return packed

func _clamp_to_image(position: Vector2) -> Vector2:
	return Vector2(clampf(position.x, 0.0, float(image_size.x - 1)), clampf(position.y, 0.0, float(image_size.y - 1)))

func _clone_regions(source: Array) -> Array:
	var clone: Array = []
	for region_value in source:
		var region: Dictionary = region_value
		var points: Array = []
		for point in region.get("points", []):
			points.append(point)
		clone.append({
			"name": region.get("name", "Region"),
			"points": points,
			"enabled": bool(region.get("enabled", true))
		})
	return clone
