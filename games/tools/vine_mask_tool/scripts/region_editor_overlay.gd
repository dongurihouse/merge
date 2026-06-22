extends Control

signal regions_changed(regions: Array)
signal selection_changed(region_index: int)
signal region_drawn(points: Array)

const HANDLE_RADIUS := 8.0
const HIT_RADIUS := 16.0
const SNAP_RADIUS := 18.0
const CLOSE_RADIUS := 20.0   # a draw click this close to the first vertex closes the polygon

var image_size := Vector2(941.0, 1672.0)
var regions: Array = []
var edit_enabled := false
var selected_region := 0
var dragging_region := -1
var dragging_point := -1
var shared_merge_count := 0

# Draw mode: clicks drop vertices of a NEW polygon; a click near the first vertex (or a double-click)
# closes it and emits region_drawn. The mask auto-detector is gone — this is how regions are authored.
var draw_mode := false
var draw_points: Array = []
var draw_cursor := Vector2.ZERO

func _ready() -> void:
	# Honour edit_enabled here: set_edit_enabled() runs before this node enters the tree, so a
	# blanket MOUSE_FILTER_IGNORE would clobber edit-on-by-default and swallow the first edits.
	mouse_filter = Control.MOUSE_FILTER_STOP if edit_enabled else Control.MOUSE_FILTER_IGNORE
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
	if not edit_enabled:
		_cancel_draw()
	mouse_filter = Control.MOUSE_FILTER_STOP if edit_enabled else Control.MOUSE_FILTER_IGNORE
	queue_redraw()

# Enter/leave polygon-draw mode. Drawing needs input, so it forces edit-enabled while active.
func set_draw_mode(on: bool) -> void:
	draw_mode = on
	draw_points = []
	if on:
		edit_enabled = true
		mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()

func is_drawing() -> bool:
	return draw_mode

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

	if draw_mode:
		_draw_in_progress()

# The polygon being drawn: a yellow rubber-band from the placed points to the cursor, a highlighted
# first vertex (the close target), and a handle on every placed point.
func _draw_in_progress() -> void:
	var color := Color(1.0, 0.85, 0.2, 1.0)
	if draw_points.size() >= 1:
		var chain := _points_to_packed(draw_points)
		if chain.size() >= 2:
			draw_polyline(chain, color, 3.0, true)
		draw_line(draw_points[draw_points.size() - 1], draw_cursor, Color(color.r, color.g, color.b, 0.6), 2.0, true)
		# the first vertex glows as the close target once a triangle is possible
		var first: Vector2 = draw_points[0]
		draw_circle(first, CLOSE_RADIUS, Color(1.0, 0.85, 0.2, 0.18))
		for point in draw_points:
			_draw_handle(point, color)

func _draw_handle(point: Vector2, color: Color) -> void:
	draw_circle(point, HANDLE_RADIUS, Color(0.0, 0.0, 0.0, 0.72))
	draw_circle(point, HANDLE_RADIUS - 2.0, color)

func _gui_input(event: InputEvent) -> void:
	if not edit_enabled:
		return

	if draw_mode:
		_draw_input(event)
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

# Draw-mode input: left-click drops a vertex (or closes near the first one / on a double-click),
# right-click cancels the in-progress polygon. Motion just updates the rubber-band cursor.
func _draw_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		draw_cursor = (event as InputEventMouseMotion).position
		queue_redraw()
		return

	if not (event is InputEventMouseButton):
		return
	var button_event := event as InputEventMouseButton
	if not button_event.pressed:
		return

	if button_event.button_index == MOUSE_BUTTON_RIGHT:
		_cancel_draw()
		accept_event()
		return
	if button_event.button_index != MOUSE_BUTTON_LEFT:
		return

	var pos := _clamp_to_image(button_event.position)
	var can_close := draw_points.size() >= 3
	if can_close and (pos.distance_to(draw_points[0]) <= CLOSE_RADIUS or button_event.double_click):
		_finish_draw()
	else:
		draw_points.append(pos)
	draw_cursor = pos
	queue_redraw()
	accept_event()

func _finish_draw() -> void:
	var pts := draw_points.duplicate()
	draw_points = []
	draw_mode = false
	queue_redraw()
	region_drawn.emit(pts)

func _cancel_draw() -> void:
	if not draw_mode and draw_points.is_empty():
		return
	draw_points = []
	draw_mode = false
	queue_redraw()

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
