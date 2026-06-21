extends Control

const RegionEditorOverlay := preload("res://games/tools/vine_mask_tool/scripts/region_editor_overlay.gd")
const VineMapView := preload("res://games/grove/vine/vine_map_view.gd")
const MAPS_PATH := "res://games/tools/vine_mask_tool/maps/maps.json"
const DEFAULT_MAP_ID := "map1_farm"
const COMPONENT_THRESHOLD := 0.25
const MIN_COMPONENT_PIXELS := 420
const DEFAULT_REGION_COUNT := 8
const HULL_PADDING := 10.0
const OVERLAP_PASSES := 6           # repeats of pairwise separation until boxes stop moving
const MIN_REGION_SIZE := 12.0       # a separated box is never carved thinner than this
const VERTEX_WELD_RADIUS := 24.0    # corners closer than this across zones snap to a shared point

# Per-region shader knobs. The table is the source of truth for both the slider panel
# and the saved-tuning round-trip, so it lives here (not inside _build_panel) — it must
# be readable before the panel exists. It mirrors VineMapView.CONTROLS (the renderer drives
# the same params); the tool keeps its own copy because the panel reads label/min/max/step too.
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

@onready var artwork_frame: Control = $Workspace/ArtworkFrame
@onready var base_rect: TextureRect = $Workspace/ArtworkFrame/Base

var maps: Array[Dictionary] = []
var current_map_index := 0
var current_map: Dictionary = {}
var current_map_id := ""
var image_size := Vector2i(941, 1672)
var regions_path := ""
var mask_image: Image
var regions: Array = []
var region_count := 1
var controls: Array[Dictionary] = []
var sliders: Dictionary = {}
var value_labels: Dictionary = {}
var view: VineMapView                # the shared renderer — the tool owns one, edits push to it
var selected_region := 0
var updating_ui := false
var region_editor: Control
var map_select: OptionButton
var region_select: OptionButton
var enable_region: CheckBox
var edit_regions_toggle: CheckButton
var save_status_label: Label
var _pending_initial_save := false
# Whole-mask nudge: shifts every overlay + the region editor over the fixed base, so a mask
# that doesn't line up with the art can be aligned. Region points stay in mask-local space;
# this offset is persisted alongside them.
var mask_offset := Vector2.ZERO
var mask_offset_sliders: Dictionary = {}

func _ready() -> void:
	custom_minimum_size = Vector2(1380.0, 1672.0)
	controls.assign(CONTROLS.duplicate(true))
	_load_maps()
	if maps.is_empty():
		push_error("Vine mask tool has no maps in %s" % MAPS_PATH)
		return
	current_map_index = _default_map_index()
	_apply_current_map()
	_build_panel()
	_create_region_editor()
	_select_region(0)
	_flush_pending_initial_save()

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
	_load_base_art()
	# The mask used for region DETECTION is built tool-side (the detector reads it pixel-by-pixel);
	# the renderer (VineMapView) builds its own copy from the same map entry. Both read identical
	# inputs, so the detector's mask and the rendered mask agree.
	mask_image = _build_mask_image(current_map)
	if mask_image == null or mask_image.is_empty():
		mask_image = _fallback_mask_image()
	mask_image.convert(Image.FORMAT_RGBA8)
	image_size = Vector2i(mask_image.get_width(), mask_image.get_height())

	var had_regions_file := regions_path != "" and FileAccess.file_exists(regions_path)
	mask_offset = _load_saved_mask_offset()
	_load_saved_regions_or_detect()
	region_count = maxi(regions.size(), 1)

	# Hand the whole render off to the shared view: it builds the mask, region-index map, the
	# per-region shadow/glow/vines/embers overlays, and applies each region's saved tuning.
	_ensure_view()
	view.mask_offset = mask_offset
	view.load_map(current_map, regions)

	# First visit to a map (no saved file): seed it by saving the auto-detected regions.
	if not had_regions_file:
		_pending_initial_save = true

func _ensure_view() -> void:
	if view != null and is_instance_valid(view):
		return
	view = VineMapView.new()
	view.name = "VineView"
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Sits at the frame origin; the view itself anchors its overlay group at mask_offset.
	view.position = Vector2.ZERO
	artwork_frame.add_child(view)
	# Keep the view behind the region editor (added later) but above Base/Vignette.
	artwork_frame.move_child(view, artwork_frame.get_child_count() - 1)

func _load_base_art() -> void:
	var base_path := String(current_map.get("base", ""))
	var base_texture := load(base_path) as Texture2D
	if base_texture != null:
		base_rect.texture = base_texture
		image_size = Vector2i(int(base_texture.get_size().x), int(base_texture.get_size().y))
	artwork_frame.custom_minimum_size = Vector2(image_size)
	artwork_frame.size = Vector2(image_size)

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

func _load_saved_regions_or_detect() -> void:
	regions = _load_saved_regions()
	if regions.is_empty():
		regions = _detect_regions_from_mask()

func _load_saved_mask_offset() -> Vector2:
	if regions_path == "" or not FileAccess.file_exists(regions_path):
		return Vector2.ZERO
	var file := FileAccess.open(regions_path, FileAccess.READ)
	if file == null:
		return Vector2.ZERO
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return Vector2.ZERO
	var offset: Variant = (parsed as Dictionary).get("mask_offset", null)
	if offset is Array and offset.size() >= 2:
		return Vector2(float(offset[0]), float(offset[1]))
	return Vector2.ZERO

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
			var tuning_value: Variant = region_data.get("tuning", {})
			loaded.append({
				"name": str(region_data.get("name", "Region %d" % [loaded.size() + 1])),
				"points": points,
				"enabled": bool(region_data.get("enabled", true)),
				"tuning": tuning_value if tuning_value is Dictionary else {}
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

	if detected.size() != target:
		return _fallback_regions()
	_resolve_region_overlaps(detected)
	return detected

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

# Auto-detected boxes (padded component bounds) routinely overlap — a small component sitting
# inside a larger one, or neighbours whose padding collides. Separate every overlapping pair
# along its thinner seam to a shared midline so the zones tile instead of overlap, then weld
# near-coincident corners so touching edges share exact vertices. Mutates `target_regions`.
func _resolve_region_overlaps(target_regions: Array) -> void:
	if target_regions.size() < 2:
		return
	var boxes: Array = []
	for region in target_regions:
		boxes.append(_box_from_points(region.get("points", [])))

	for _pass in range(OVERLAP_PASSES):
		var changed := false
		for i in range(boxes.size()):
			for j in range(i + 1, boxes.size()):
				if _separate_box_pair(boxes[i], boxes[j]):
					changed = true
		if not changed:
			break

	for index in range(target_regions.size()):
		var box: Dictionary = boxes[index]
		var region: Dictionary = target_regions[index]
		region["points"] = _box_points_8(box["min_x"], box["min_y"], box["max_x"], box["max_y"])
		target_regions[index] = region

	_weld_region_vertices(target_regions)

func _box_from_points(points: Array) -> Dictionary:
	var min_x := INF
	var min_y := INF
	var max_x := -INF
	var max_y := -INF
	for point in points:
		var p: Vector2 = point
		min_x = minf(min_x, p.x)
		min_y = minf(min_y, p.y)
		max_x = maxf(max_x, p.x)
		max_y = maxf(max_y, p.y)
	return {"min_x": min_x, "min_y": min_y, "max_x": max_x, "max_y": max_y}

# Push one overlapping box pair apart along the axis where they overlap least (the seam),
# setting the shared edge to the midline. Dictionaries are references, so this edits in place.
func _separate_box_pair(a: Dictionary, b: Dictionary) -> bool:
	var ox1 := maxf(a["min_x"], b["min_x"])
	var ox2 := minf(a["max_x"], b["max_x"])
	var oy1 := maxf(a["min_y"], b["min_y"])
	var oy2 := minf(a["max_y"], b["max_y"])
	if ox2 <= ox1 or oy2 <= oy1:
		return false
	if ox2 - ox1 <= oy2 - oy1:
		var mid_x := (ox1 + ox2) * 0.5
		if (a["min_x"] + a["max_x"]) <= (b["min_x"] + b["max_x"]):
			a["max_x"] = maxf(mid_x, a["min_x"] + MIN_REGION_SIZE)
			b["min_x"] = minf(mid_x, b["max_x"] - MIN_REGION_SIZE)
		else:
			b["max_x"] = maxf(mid_x, b["min_x"] + MIN_REGION_SIZE)
			a["min_x"] = minf(mid_x, a["max_x"] - MIN_REGION_SIZE)
	else:
		var mid_y := (oy1 + oy2) * 0.5
		if (a["min_y"] + a["max_y"]) <= (b["min_y"] + b["max_y"]):
			a["max_y"] = maxf(mid_y, a["min_y"] + MIN_REGION_SIZE)
			b["min_y"] = minf(mid_y, b["max_y"] - MIN_REGION_SIZE)
		else:
			b["max_y"] = maxf(mid_y, b["min_y"] + MIN_REGION_SIZE)
			a["min_y"] = minf(mid_y, a["max_y"] - MIN_REGION_SIZE)
	return true

# Snap corner vertices from different zones that sit within VERTEX_WELD_RADIUS onto a shared
# midpoint, so a touched seam shares exact vertices (and the editor moves them together).
func _weld_region_vertices(target_regions: Array) -> void:
	for i in range(target_regions.size()):
		var a_points: Array = target_regions[i].get("points", [])
		for ai in range(a_points.size()):
			var ap: Vector2 = a_points[ai]
			for j in range(i + 1, target_regions.size()):
				var b_points: Array = target_regions[j].get("points", [])
				for bi in range(b_points.size()):
					var bp: Vector2 = b_points[bi]
					if ap.distance_to(bp) <= VERTEX_WELD_RADIUS:
						ap = (ap + bp) * 0.5
						a_points[ai] = ap
						b_points[bi] = ap

func _sort_regions_by_position(a: Dictionary, b: Dictionary) -> bool:
	var ap: Array = a["points"]
	var bp: Array = b["points"]
	return (ap[0] as Vector2).y < (bp[0] as Vector2).y if absf((ap[0] as Vector2).y - (bp[0] as Vector2).y) > 16.0 else (ap[0] as Vector2).x < (bp[0] as Vector2).x

func _sort_regions_by_size(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("pixels", 0)) > int(b.get("pixels", 0))

func _refresh_regions_from_polygons() -> void:
	region_count = maxi(regions.size(), 1)
	# Geometry / region-set changed: push it to the renderer (rebuilds region map + overlays +
	# re-applies tuning). The view re-anchors its overlay group to mask_offset.
	if view != null and is_instance_valid(view):
		view.mask_offset = mask_offset
		view.refresh(regions)
	_refresh_region_select_items()
	_select_region(mini(selected_region, region_count - 1))

func _store_region_tuning(region_index: int, control_name: String, value: float) -> void:
	if region_index < 0 or region_index >= regions.size():
		return
	var region: Dictionary = regions[region_index]
	var tuning: Dictionary = region.get("tuning", {})
	tuning[control_name] = value
	region["tuning"] = tuning
	regions[region_index] = region

# A full snapshot of one region's live shader values, used when serializing — so the
# saved file carries every knob, not just the ones the user happened to touch.
func _current_region_tuning(region_index: int) -> Dictionary:
	var tuning: Dictionary = {}
	if view == null or not is_instance_valid(view):
		return tuning
	for control in controls:
		tuning[String(control["name"])] = _read_shader_value(control["target"], control["param"], region_index)
	return tuning

# The pristine template value for a knob — what "Reset Region" restores. Delegates to the view's
# never-mutated template materials so saved tuning can never contaminate the reset target.
func _template_default(target: String, param: String) -> float:
	if view == null or not is_instance_valid(view):
		return 0.0
	return view.template_default(target, param)

func _edit_regions_default() -> bool:
	return edit_regions_toggle.button_pressed if edit_regions_toggle != null else true

func _flush_pending_initial_save() -> void:
	if not _pending_initial_save:
		return
	_pending_initial_save = false
	_save_regions_to_file()

func _show_save_status(message: String, ok: bool) -> void:
	if save_status_label == null:
		return
	save_status_label.text = message
	save_status_label.add_theme_color_override("font_color", Color(0.55, 1.0, 0.6) if ok else Color(1.0, 0.45, 0.45))

func _build_panel() -> void:
	for control in controls:
		control["default"] = _template_default(control["target"], control["param"])

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

	mask_offset_sliders.clear()
	_add_mask_offset_slider(stack, "Mask offset X", "x")
	_add_mask_offset_slider(stack, "Mask offset Y", "y")

func _add_mask_offset_slider(stack: VBoxContainer, label_text: String, axis: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	stack.add_child(row)

	var name_label := Label.new()
	name_label.text = label_text
	name_label.custom_minimum_size = Vector2(104.0, 0.0)
	row.add_child(name_label)

	var slider := HSlider.new()
	slider.name = "MaskOffset" + axis.to_upper()
	slider.min_value = -float(image_size.x if axis == "x" else image_size.y)
	slider.max_value = float(image_size.x if axis == "x" else image_size.y)
	slider.step = 1.0
	slider.value = mask_offset.x if axis == "x" else mask_offset.y
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	mask_offset_sliders[axis] = slider

	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(48.0, 0.0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.text = "%d" % int(slider.value)
	row.add_child(value_label)

	slider.value_changed.connect(_on_mask_offset_changed.bind(axis, value_label))

func _on_mask_offset_changed(value: float, axis: String, value_label: Label) -> void:
	if axis == "x":
		mask_offset.x = value
	else:
		mask_offset.y = value
	value_label.text = "%d" % int(value)
	_apply_mask_offset()

func _apply_mask_offset() -> void:
	if view != null and is_instance_valid(view):
		view.set_mask_offset(mask_offset)
	if region_editor != null:
		region_editor.call("set_mask_offset", mask_offset)

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
	# On by default: open the tool ready to drag region handles. The editor itself is built
	# after this panel, so it reads this state in _create_region_editor (the toggle handler
	# is a no-op while region_editor is still null).
	edit_regions_toggle.button_pressed = true
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

	save_status_label = Label.new()
	save_status_label.name = "SaveStatus"
	save_status_label.add_theme_font_size_override("font_size", 12)
	save_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(save_status_label)

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
	slider.value_changed.connect(_on_slider_changed.bind(config["name"], config["target"], config["param"], value_label, config["decimals"]))

func _create_region_editor() -> void:
	if region_editor != null:
		region_editor.queue_free()
	region_editor = RegionEditorOverlay.new()
	region_editor.name = "RegionEditor"
	region_editor.call("set_image_size", Vector2(image_size))
	region_editor.call("set_mask_offset", mask_offset)
	region_editor.call("set_regions", regions)
	region_editor.call("set_selected_region", selected_region)
	region_editor.call("set_edit_enabled", _edit_regions_default())
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
	_flush_pending_initial_save()

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

# Push an enable toggle to the renderer and keep the tool's own `regions` source of truth in sync.
func _set_region_enabled(region_index: int, enabled: bool) -> void:
	if region_index < 0 or region_index >= regions.size():
		return
	var region: Dictionary = regions[region_index]
	region["enabled"] = enabled
	regions[region_index] = region
	if view != null and is_instance_valid(view):
		view.set_region_enabled(region_index, enabled)

func _region_is_enabled(region_index: int) -> bool:
	if region_index < 0 or region_index >= regions.size():
		return false
	var region: Dictionary = regions[region_index]
	return bool(region.get("enabled", true))

func _on_slider_changed(value: float, control_name: String, target: String, param: String, value_label: Label, decimals: int) -> void:
	if updating_ui:
		return
	_write_shader_value(target, param, value, selected_region)
	_store_region_tuning(selected_region, control_name, value)
	_update_value_label(value_label, value, decimals)

# Live read/write of one shader knob — delegates to the view so the tool and the game share ONE
# renderer. Kept as named methods because the functional verifier calls them by name.
func _read_shader_value(target: String, param: String, region_index: int) -> float:
	if view == null or not is_instance_valid(view):
		return 0.0
	return view.read_shader_value(target, param, region_index)

func _write_shader_value(target: String, param: String, value: float, region_index: int) -> void:
	if view == null or not is_instance_valid(view):
		return
	view.write_shader_value(target, param, value, region_index)

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
	# Drop stored deltas so a later overlay rebuild keeps the template look, not the old tuning.
	if selected_region >= 0 and selected_region < regions.size():
		var region: Dictionary = regions[selected_region]
		region["tuning"] = {}
		regions[selected_region] = region

func _on_regions_changed(next_regions: Array) -> void:
	# The editor only owns geometry; merge its points/name/enabled back by index so each
	# region's tuning (which the editor doesn't carry) is preserved across an edit.
	for index in range(mini(regions.size(), next_regions.size())):
		var existing: Dictionary = regions[index]
		var incoming: Dictionary = next_regions[index]
		existing["points"] = incoming.get("points", existing.get("points", []))
		existing["name"] = incoming.get("name", existing.get("name", "Region %d" % [index + 1]))
		existing["enabled"] = bool(incoming.get("enabled", existing.get("enabled", true)))
		regions[index] = existing
	_refresh_regions_from_polygons()

func _save_regions_to_file() -> void:
	var data := {
		"map_id": current_map_id,
		"image_size": [image_size.x, image_size.y],
		"mask_offset": [roundi(mask_offset.x), roundi(mask_offset.y)],
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
			"points": serialized_points,
			"tuning": _current_region_tuning(index)
		})

	if regions_path == "":
		_show_save_status("Save failed: this map has no regions_path", false)
		push_error("[vine_mask_tool] cannot save — current map has no regions_path")
		return

	var path := ProjectSettings.globalize_path(regions_path)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "  "))
		file.close()
		_show_save_status("Saved ✓  %d regions → %s" % [regions.size(), regions_path.get_file()], true)
		print("[vine_mask_tool] saved %d regions to %s" % [regions.size(), regions_path])
	else:
		_show_save_status("Save failed: could not write %s" % regions_path.get_file(), false)
		push_error("[vine_mask_tool] could not write %s (error %d)" % [path, FileAccess.get_open_error()])

func _clamp_to_image(position: Vector2) -> Vector2:
	return Vector2(clampf(position.x, 0.0, float(image_size.x - 1)), clampf(position.y, 0.0, float(image_size.y - 1)))
