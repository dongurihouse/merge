extends Control

signal regions_changed(regions: Array)
signal selection_changed(region_index: int)

const HANDLE_RADIUS := 8.0
const HIT_RADIUS := 16.0
const SNAP_RADIUS := 18.0

var image_size := Vector2(941.0, 1672.0)
var regions: Array = []
var edit_enabled := false
var selected_region := 0
var dragging_region := -1
var dragging_point := -1
var shared_merge_count := 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = image_size
	size = image_size

func set_image_size(value: Vector2) -> void:
	image_size = value
	custom_minimum_size = image_size
	size = image_size
	queue_redraw()

func set_mask_offset(value: Vector2) -> void:
	position = value
	queue_redraw()

func set_regions(value: Array) -> void:
	regions = _clone_regions(value)
	if selected_region >= regions.size():
		selected_region = maxi(regions.size() - 1, 0)
	queue_redraw()

func set_edit_enabled(value: bool) -> void:
	edit_enabled = value
	mouse_filter = Control.MOUSE_FILTER_STOP if edit_enabled else Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func set_selected_region(value: int) -> void:
	selected_region = clampi(value, 0, maxi(regions.size() - 1, 0))
	queue_redraw()

func get_shared_merge_count() -> int:
	return shared_merge_count

func set_region_point(region_index: int, point_index: int, position: Vector2) -> void:
	if region_index < 0 or region_index >= regions.size():
		return
	var region: Dictionary = regions[region_index]
	var points: Array = region.get("points", [])
	if point_index < 0 or point_index >= points.size():
		return

	var old_position: Vector2 = points[point_index]
	var next_position := _snap_or_clamp(region_index, point_index, position)
	_move_shared_points(old_position, next_position)
	regions_changed.emit(_clone_regions(regions))
	queue_redraw()

func _draw() -> void:
	if not edit_enabled:
		return

	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.08), true)
	for region_index in regions.size():
		var region: Dictionary = regions[region_index]
		var points: Array = region.get("points", [])
		if points.size() < 2:
			continue

		var packed := _points_to_packed(points)
		var line_color := Color(1.0, 0.25, 1.0, 0.8)
		var fill_color := Color(0.55, 0.05, 1.0, 0.05)
		var width := 2.0
		if region_index == selected_region:
			line_color = Color(0.35, 0.95, 1.0, 1.0)
			fill_color = Color(0.2, 0.9, 1.0, 0.08)
			width = 4.0

		if packed.size() >= 3:
			draw_colored_polygon(packed, fill_color)
		draw_polyline(packed, line_color, width, true)
		draw_line(points[points.size() - 1], points[0], line_color, width, true)

		for point in points:
			_draw_handle(point, Color(0.75, 1.0, 1.0, 1.0) if region_index == selected_region else Color(1.0, 0.92, 1.0, 1.0))

func _draw_handle(point: Vector2, color: Color) -> void:
	draw_circle(point, HANDLE_RADIUS, Color(0.0, 0.0, 0.0, 0.72))
	draw_circle(point, HANDLE_RADIUS - 2.0, color)

func _gui_input(event: InputEvent) -> void:
	if not edit_enabled:
		return

	if event is InputEventMouseButton:
		var button_event := event as InputEventMouseButton
		if button_event.button_index != MOUSE_BUTTON_LEFT:
			return

		if button_event.pressed:
			var hit := _find_handle(button_event.position)
			if int(hit["region"]) >= 0:
				dragging_region = int(hit["region"])
				dragging_point = int(hit["point"])
				set_selected_region(dragging_region)
				selection_changed.emit(selected_region)
				accept_event()
				return

		dragging_region = -1
		dragging_point = -1
		accept_event()
		return

	if event is InputEventMouseMotion and dragging_region >= 0 and dragging_point >= 0:
		var motion_event := event as InputEventMouseMotion
		set_region_point(dragging_region, dragging_point, motion_event.position)
		accept_event()

func _find_handle(position: Vector2) -> Dictionary:
	var best := {"region": -1, "point": -1, "distance": INF}
	for region_index in regions.size():
		var region: Dictionary = regions[region_index]
		var points: Array = region.get("points", [])
		for point_index in points.size():
			var point: Vector2 = points[point_index]
			var distance := point.distance_to(position)
			if distance <= HIT_RADIUS and distance < float(best["distance"]):
				best = {"region": region_index, "point": point_index, "distance": distance}
	return best

func _snap_or_clamp(region_index: int, point_index: int, position: Vector2) -> Vector2:
	var clamped := _clamp_to_image(position)
	for other_region_index in regions.size():
		var region: Dictionary = regions[other_region_index]
		var points: Array = region.get("points", [])
		for other_point_index in points.size():
			if other_region_index == region_index and other_point_index == point_index:
				continue
			var other_point: Vector2 = points[other_point_index]
			if clamped.distance_to(other_point) <= SNAP_RADIUS:
				shared_merge_count += 1
				return other_point
	return clamped

func _move_shared_points(old_position: Vector2, next_position: Vector2) -> void:
	for region_index in regions.size():
		var region: Dictionary = regions[region_index]
		var points: Array = region.get("points", [])
		for point_index in points.size():
			var point: Vector2 = points[point_index]
			if point.distance_to(old_position) <= 0.1:
				points[point_index] = next_position
		region["points"] = points
		regions[region_index] = region

func _clamp_to_image(position: Vector2) -> Vector2:
	return Vector2(clampf(position.x, 0.0, image_size.x - 1.0), clampf(position.y, 0.0, image_size.y - 1.0))

func _points_to_packed(points: Array) -> PackedVector2Array:
	var packed := PackedVector2Array()
	for point in points:
		packed.append(point)
	return packed

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
