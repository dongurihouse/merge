@tool
extends Control
## Animated water overlay for the acorn vase asset.

const VASE_PATH := "res://games/grove/assets/ui/vase/vase_acorn.png"
const MASK_PATH := "res://games/grove/assets/ui/vase/vase_acorn_mask.png"
const LOOP_SECONDS := 4.8
const IDLE_ENERGY := 1.6
const IMPACT_ENERGY := 12.0
const IMPACT_TIME := 2.05
const IMPACT_X := 0.50

const _SAMPLES := 28
const _DROP_SCALE := 3.0
const _DROP_START := 0.45
const _DROP_GROWN := 1.18
const _IMPACT_TAIL := 1.5
const _WATERLINE_EMPTY := 0.68
const _WATERLINE_FULL := 0.36
const _MASK_THRESHOLD := 0.38
const _VASE_ALPHA_THRESHOLD := 0.05
const _WATER := Color("#3CBCE9")
const _SURFACE := Color("#BDF5FF")

var _time := 0.0
var _energy := IDLE_ENERGY
var _impact_age := 999.0
var _progress := 0.5
var _target_progress := 0.5
var _ready_fx := false
var _tex: Texture2D
var _vase_content_bounds := Rect2i()
var _mask_tex: Texture2D
var _mask_img: Image
var _mask_bounds := Rect2i()
var _mask_row_spans: Array[Vector2i] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_tex = load(VASE_PATH) as Texture2D
	_prepare_vase_cache()
	_mask_tex = load(MASK_PATH) as Texture2D
	_prepare_mask_cache()
	set_process(true)


func _process(delta: float) -> void:
	_advance(delta, true)


func set_time_for_test(value: float) -> void:
	_time = fposmod(value, LOOP_SECONDS)
	var age := _time - IMPACT_TIME
	if age >= 0.0 and age <= _IMPACT_TAIL:
		_impact_age = age
		_energy = IDLE_ENERGY + (IMPACT_ENERGY - IDLE_ENERGY) * exp(-age * 2.0)
	else:
		_impact_age = 999.0
		_energy = IDLE_ENERGY
	queue_redraw()


func trigger_impact_for_test() -> void:
	_trigger_impact()


func set_progress_for_test(value: float) -> void:
	set_progress(value)


func animate_progress_for_test(value: float) -> void:
	animate_progress_to(value)


func progress_for_test() -> float:
	return _progress


func waterline_y_for_test() -> float:
	return _waterline_y(_vase_rect())


func energy_for_test() -> float:
	return _energy


func water_surface_for_test() -> PackedVector2Array:
	return _surface_points(_vase_rect())


func get_texture_for_test() -> Texture2D:
	if _tex == null:
		_tex = load(VASE_PATH) as Texture2D
		_prepare_vase_cache()
	return _tex

func visible_vase_rect_for_test() -> Rect2:
	return _visible_vase_rect(_vase_rect())

func get_mask_texture_for_test() -> Texture2D:
	if _mask_tex == null:
		_mask_tex = load(MASK_PATH) as Texture2D
		_prepare_mask_cache()
	return _mask_tex

func ready_glow_style_for_test() -> Dictionary:
	return {"tone": "gold", "soft_layers": 5, "hard_rings": 0}

func drop_state_for_test() -> Dictionary:
	return _drop_state(_vase_rect())

func drop_shape_points_for_test() -> PackedVector2Array:
	return _drop_shape_points(_drop_state(_vase_rect()))


func set_progress(value: float) -> void:
	_progress = clampf(value, 0.0, 1.0)
	_target_progress = _progress
	queue_redraw()


func animate_progress_to(value: float) -> void:
	var next_progress := clampf(value, 0.0, 1.0)
	if next_progress > _progress + 0.01:
		_energy = maxf(_energy, IDLE_ENERGY + (next_progress - _progress) * 15.0)
		_impact_age = 0.0
	_target_progress = next_progress
	queue_redraw()


func set_ready(value: bool) -> void:
	_ready_fx = value
	queue_redraw()


func _advance(delta: float, auto_trigger: bool) -> void:
	var previous_time := _time
	_time = fposmod(_time + delta, LOOP_SECONDS)
	if _time < previous_time:
		_impact_age = 999.0
		_energy = IDLE_ENERGY

	if auto_trigger and previous_time < IMPACT_TIME and _time >= IMPACT_TIME:
		_trigger_impact()
	elif _impact_age < 100.0:
		_impact_age += delta
		_energy = lerpf(_energy, IDLE_ENERGY, clampf(delta * 1.45, 0.0, 1.0))
	else:
		_energy = lerpf(_energy, IDLE_ENERGY, clampf(delta * 0.8, 0.0, 1.0))
	if not is_equal_approx(_progress, _target_progress):
		var old_progress := _progress
		_progress = move_toward(_progress, _target_progress, delta * 1.35)
		if _progress > old_progress:
			_energy = maxf(_energy, IDLE_ENERGY + (_progress - old_progress) * 28.0)
	queue_redraw()


func _trigger_impact() -> void:
	_time = IMPACT_TIME
	_energy = IMPACT_ENERGY
	_impact_age = 0.0
	queue_redraw()


func _draw() -> void:
	var tex := get_texture_for_test()
	if tex == null:
		return
	var vase := _vase_rect()
	_draw_vase_shadow(vase)
	if _ready_fx:
		_draw_ready_glow(vase)
	draw_texture_rect(tex, vase, false)
	_draw_water_overlay(vase)
	_draw_drop(vase)
	if _ready_fx:
		_draw_ready_sparkles(vase)


func _draw_water_overlay(vase: Rect2) -> void:
	var surface := _surface_points(vase)
	var body := PackedVector2Array()
	var top_y := _waterline_y(vase)
	var top_span := _span_at(vase, top_y)
	body.append(Vector2(top_span.x, top_y))
	body.append(Vector2(top_span.y, top_y))
	var bottom_y := _water_bottom_y(vase)
	for i in range(1, 6):
		var t := float(i) / 5.0
		var y := lerpf(top_y, bottom_y, t)
		var span := _span_at(vase, y)
		body.append(Vector2(span.y, y))
	for i in range(5, 0, -1):
		var t := float(i) / 5.0
		var y := lerpf(top_y, bottom_y, t)
		var span := _span_at(vase, y)
		body.append(Vector2(span.x, y))

	var water := _WATER
	water.a = 0.34
	draw_colored_polygon(body, water)
	var deep := Color("#1679A5")
	deep.a = 0.15
	draw_colored_polygon(body, deep)
	draw_polyline(surface, _SURFACE, 2.6, true)
	draw_polyline(surface, Color(1, 1, 1, 0.30), 1.0, true)

	if _impact_age <= _IMPACT_TAIL:
		var hit := Vector2(_center_x(vase), _waterline_y(vase))
		var ring_alpha := _impact_envelope() * 0.25
		draw_arc(hit, vase.size.x * (0.10 + _impact_age * 0.10),
			0.06 * PI, 0.94 * PI, 24, Color(0.78, 0.96, 1.0, ring_alpha), 1.8)


func _draw_vase_shadow(vase: Rect2) -> void:
	var center := vase.position + Vector2(vase.size.x * 0.50, vase.size.y * 0.91)
	draw_set_transform(center, 0.0, Vector2(1.25, 0.32))
	draw_circle(Vector2.ZERO, vase.size.x * 0.37, Color(0.05, 0.025, 0.01, 0.28))
	draw_circle(Vector2.ZERO, vase.size.x * 0.27, Color(0.0, 0.0, 0.0, 0.18))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_drop(vase: Rect2) -> void:
	var st := _drop_state(vase)
	if not bool(st.visible):
		return
	var center := Vector2(float(st.x), float(st.y))
	var radius := float(st.radius)
	var alpha := float(st.alpha)
	var col := _WATER
	col.a = 0.78 * alpha
	var outline := _drop_shape_points(st)
	if outline.size() >= 3:
		draw_colored_polygon(outline, col)
	else:
		draw_circle(center, radius, col)
	draw_circle(center + Vector2(-radius * 0.23, -radius * 0.36), radius * 0.20,
		Color(1, 1, 1, 0.42 * alpha))


func _draw_ready_glow(vase: Rect2) -> void:
	var pulse := 0.5 + 0.5 * sin(_time * TAU / 2.4)
	var center := vase.position + vase.size * 0.5
	draw_set_transform(center, 0.0, Vector2(0.92, 1.05))
	for i in range(4, -1, -1):
		var layer := float(i) / 4.0
		var radius := vase.size.x * (0.38 + layer * 0.18 + pulse * 0.028)
		var alpha := lerpf(0.15, 0.035, layer) + pulse * lerpf(0.050, 0.012, layer)
		draw_circle(Vector2.ZERO, radius, Color(1.0, 0.74, 0.22, alpha))
	draw_circle(Vector2.ZERO, vase.size.x * (0.34 + pulse * 0.020),
		Color(1.0, 0.92, 0.48, 0.10 + pulse * 0.055))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_ready_sparkles(vase: Rect2) -> void:
	for i in range(7):
		var seed := float(i) * 1.618
		var phase := fposmod(_time * 0.55 + seed, 1.0)
		var side := -1.0 if i % 2 == 0 else 1.0
		var x := _center_x(vase) + side * vase.size.x * (0.26 + 0.08 * sin(seed))
		var y := vase.position.y + vase.size.y * (0.18 + phase * 0.55)
		var a := sin(phase * PI)
		var r := vase.size.x * (0.010 + 0.010 * a)
		var c := Color(1.0, 0.94, 0.42, 0.60 * a)
		draw_line(Vector2(x - r, y), Vector2(x + r, y), c, 1.5)
		draw_line(Vector2(x, y - r), Vector2(x, y + r), c, 1.5)


func _vase_rect() -> Rect2:
	var view := Vector2(maxf(size.x, 1.0), maxf(size.y, 1.0))
	var tex := get_texture_for_test()
	var tex_size := Vector2(383, 444)
	if tex != null:
		tex_size = Vector2(tex.get_width(), tex.get_height())
	if _has_vase_content_bounds():
		var content_size := Vector2(float(_vase_content_bounds.size.x), float(_vase_content_bounds.size.y))
		var scale := minf(view.x / content_size.x, view.y / content_size.y)
		var rect_size := tex_size * scale
		var visible_size := content_size * scale
		var content_offset := Vector2(float(_vase_content_bounds.position.x), float(_vase_content_bounds.position.y)) * scale
		return Rect2((view - visible_size) * 0.5 - content_offset, rect_size)
	var scale := minf(view.x / tex_size.x, view.y / tex_size.y)
	var rect_size := tex_size * scale
	return Rect2((view - rect_size) * 0.5, rect_size)


func _surface_points(vase: Rect2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var y := _waterline_y(vase)
	var span := _span_at(vase, y)
	for i in range(_SAMPLES + 1):
		var u := float(i) / float(_SAMPLES)
		var x := lerpf(span.x, span.y, u)
		pts.append(Vector2(x, y + _wave_height(u)))
	return pts


func _wave_height(unit_x: float) -> float:
	var base := sin(unit_x * TAU * 1.35 + _time * 2.2) * _energy
	base += sin(unit_x * TAU * 2.7 - _time * 3.0) * _energy * 0.32
	var dist := absf(unit_x - IMPACT_X)
	var impact := exp(-dist * dist * 46.0) * cos(_impact_age * 13.0) * _impact_envelope() * 9.0
	return base + impact


func _impact_envelope() -> float:
	if _impact_age > _IMPACT_TAIL:
		return 0.0
	return exp(-_impact_age * 2.5)


func _drop_state(vase: Rect2) -> Dictionary:
	var top_y := vase.position.y + vase.size.y * 0.12
	var hit_y := _waterline_y(vase) - vase.size.y * 0.015
	var x := _center_x(vase)
	if _time < _DROP_START or _time > IMPACT_TIME:
		return {"visible": false, "x": x, "y": hit_y, "radius": 0.0, "alpha": 0.0}
	var radius := vase.size.x * 0.018 * _DROP_SCALE
	var y := top_y
	if _time <= _DROP_GROWN:
		var grow_t := smoothstep(_DROP_START, _DROP_GROWN, _time)
		radius = lerpf(vase.size.x * 0.014, vase.size.x * 0.032, grow_t) * _DROP_SCALE
		y = top_y - vase.size.y * 0.015 * sin(grow_t * PI)
		var width_scale := lerpf(1.08, 0.92, grow_t)
		var height_scale := lerpf(0.82, 1.22, grow_t)
		var wobble := sin(grow_t * PI * 1.5) * 0.08
		return {
			"visible": true, "shape": "teardrop", "x": x, "y": y, "radius": radius, "alpha": 1.0,
			"width_scale": width_scale, "height_scale": height_scale, "wobble": wobble,
		}
	else:
		var fall_t := smoothstep(_DROP_GROWN, IMPACT_TIME, _time)
		radius = lerpf(vase.size.x * 0.032, vase.size.x * 0.022, fall_t) * _DROP_SCALE
		y = lerpf(top_y, hit_y, fall_t * fall_t)
		var width_scale := 0.86 + sin(fall_t * TAU * 1.15) * 0.08
		var height_scale := 1.28 + sin(fall_t * PI) * 0.16
		var wobble := sin(fall_t * TAU * 1.8) * 0.10
		return {
			"visible": true, "shape": "teardrop", "x": x, "y": y, "radius": radius, "alpha": 1.0,
			"width_scale": width_scale, "height_scale": height_scale, "wobble": wobble,
		}


func _drop_shape_points(st: Dictionary) -> PackedVector2Array:
	var pts := PackedVector2Array()
	if not bool(st.get("visible", false)):
		return pts
	var center := Vector2(float(st.get("x", 0.0)), float(st.get("y", 0.0)))
	var radius := float(st.get("radius", 0.0))
	var width_scale := float(st.get("width_scale", 1.0))
	var height_scale := float(st.get("height_scale", 1.0))
	var wobble := float(st.get("wobble", 0.0))
	var w := radius * width_scale
	var h := radius * height_scale
	pts.append(center + Vector2(w * 0.00 + w * wobble * 0.30, -h * 1.36))
	pts.append(center + Vector2(w * 0.34 + w * wobble * 0.18, -h * 0.92))
	pts.append(center + Vector2(w * 0.68 + w * wobble * 0.08, -h * 0.34))
	pts.append(center + Vector2(w * 0.80, h * 0.20))
	pts.append(center + Vector2(w * 0.48 - w * wobble * 0.08, h * 0.76))
	pts.append(center + Vector2(w * 0.00 - w * wobble * 0.16, h * 0.96))
	pts.append(center + Vector2(-w * 0.48 - w * wobble * 0.08, h * 0.76))
	pts.append(center + Vector2(-w * 0.80, h * 0.20))
	pts.append(center + Vector2(-w * 0.68 + w * wobble * 0.08, -h * 0.34))
	pts.append(center + Vector2(-w * 0.34 + w * wobble * 0.18, -h * 0.92))
	return pts


func _waterline_y(vase: Rect2) -> float:
	if _has_mask_bounds():
		var bounds := _mask_bounds_rect(vase)
		var empty_y := bounds.position.y + bounds.size.y * 0.92
		var full_y := bounds.position.y + bounds.size.y * 0.10
		return lerpf(empty_y, full_y, _progress)
	return vase.position.y + vase.size.y * lerpf(_WATERLINE_EMPTY, _WATERLINE_FULL, _progress)


func _water_bottom_y(vase: Rect2) -> float:
	if _has_mask_bounds():
		var bounds := _mask_bounds_rect(vase)
		return bounds.position.y + bounds.size.y * 0.96
	return vase.position.y + vase.size.y * 0.84


func _center_x(vase: Rect2) -> float:
	return vase.position.x + vase.size.x * 0.50


func _span_at(vase: Rect2, y: float) -> Vector2:
	if not _has_mask_bounds():
		var half := _legacy_half_width_at(vase, y)
		return Vector2(_center_x(vase) - half, _center_x(vase) + half)

	var mask_rect := _mask_rect(vase)
	var img_h := _mask_img.get_height()
	var img_w := _mask_img.get_width()
	if img_h <= 1 or img_w <= 1:
		var half := _legacy_half_width_at(vase, y)
		return Vector2(_center_x(vase) - half, _center_x(vase) + half)

	var unit_y := clampf((y - mask_rect.position.y) / maxf(mask_rect.size.y, 1.0), 0.0, 1.0)
	var row := clampi(int(round(unit_y * float(img_h - 1))), 0, img_h - 1)
	var span := _row_span(row)
	if span.x < 0:
		var half := _legacy_half_width_at(vase, y)
		return Vector2(_center_x(vase) - half, _center_x(vase) + half)

	var left := mask_rect.position.x + (float(span.x) / float(img_w - 1)) * mask_rect.size.x
	var right := mask_rect.position.x + (float(span.y) / float(img_w - 1)) * mask_rect.size.x
	return Vector2(left, right)


func _legacy_half_width_at(vase: Rect2, y: float) -> float:
	var v := clampf((y - vase.position.y) / vase.size.y, 0.0, 1.0)
	var top_half := vase.size.x * 0.44
	var belly_half := vase.size.x * 0.47
	var bottom_half := vase.size.x * 0.36
	if v < 0.62:
		return lerpf(top_half, belly_half, smoothstep(0.38, 0.62, v))
	return lerpf(belly_half, bottom_half, smoothstep(0.62, 0.86, v))


func _prepare_vase_cache() -> void:
	_vase_content_bounds = Rect2i()
	if _tex == null:
		return
	var img := _tex.get_image()
	if img == null:
		return
	var w := img.get_width()
	var h := img.get_height()
	if w <= 0 or h <= 0:
		return

	var min_x := w
	var min_y := h
	var max_x := -1
	var max_y := -1
	for y in range(h):
		for x in range(w):
			if img.get_pixel(x, y).a >= _VASE_ALPHA_THRESHOLD:
				min_x = mini(min_x, x)
				min_y = mini(min_y, y)
				max_x = maxi(max_x, x)
				max_y = maxi(max_y, y)
	if max_x >= min_x and max_y >= min_y:
		_vase_content_bounds = Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


func _has_vase_content_bounds() -> bool:
	return _vase_content_bounds.size.x > 0 and _vase_content_bounds.size.y > 0


func _visible_vase_rect(vase: Rect2) -> Rect2:
	if not _has_vase_content_bounds():
		return vase
	var tex := get_texture_for_test()
	if tex == null:
		return vase
	var tex_size := Vector2(float(tex.get_width()), float(tex.get_height()))
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return vase
	var pos := vase.position + Vector2(float(_vase_content_bounds.position.x), float(_vase_content_bounds.position.y)) * vase.size / tex_size
	var content_size := Vector2(float(_vase_content_bounds.size.x), float(_vase_content_bounds.size.y)) * vase.size / tex_size
	return Rect2(pos, content_size)


func _prepare_mask_cache() -> void:
	_mask_img = null
	_mask_bounds = Rect2i()
	_mask_row_spans.clear()
	if _mask_tex == null:
		return
	_mask_img = _mask_tex.get_image()
	if _mask_img == null:
		return

	var w := _mask_img.get_width()
	var h := _mask_img.get_height()
	if w <= 0 or h <= 0:
		return

	var use_alpha := _mask_has_alpha_cutout()
	_mask_row_spans.resize(h)
	var min_x := w
	var min_y := h
	var max_x := -1
	var max_y := -1
	for y in range(h):
		var row_min := w
		var row_max := -1
		for x in range(w):
			var c := _mask_img.get_pixel(x, y)
			var amount := c.a if use_alpha else maxf(c.r, maxf(c.g, c.b))
			if amount >= _MASK_THRESHOLD:
				row_min = mini(row_min, x)
				row_max = maxi(row_max, x)
		if row_max >= row_min:
			_mask_row_spans[y] = Vector2i(row_min, row_max)
			min_x = mini(min_x, row_min)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, row_max)
			max_y = maxi(max_y, y)
		else:
			_mask_row_spans[y] = Vector2i(-1, -1)

	if max_x >= min_x and max_y >= min_y:
		_mask_bounds = Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


func _mask_has_alpha_cutout() -> bool:
	if _mask_img == null:
		return false
	var w := _mask_img.get_width()
	var h := _mask_img.get_height()
	var stride_x := maxi(1, w / 24)
	var stride_y := maxi(1, h / 24)
	for y in range(0, h, stride_y):
		for x in range(0, w, stride_x):
			if _mask_img.get_pixel(x, y).a < 0.95:
				return true
	return false


func _has_mask_bounds() -> bool:
	return _mask_img != null and _mask_bounds.size.x > 0 and _mask_bounds.size.y > 0


func _mask_rect(vase: Rect2) -> Rect2:
	if _mask_tex == null:
		return vase
	var mask_size := Vector2(_mask_tex.get_width(), _mask_tex.get_height())
	if mask_size.x <= 0.0 or mask_size.y <= 0.0:
		return vase
	var scale := maxf(vase.size.x / mask_size.x, vase.size.y / mask_size.y)
	var rect_size := mask_size * scale
	return Rect2(vase.position + (vase.size - rect_size) * 0.5, rect_size)


func _mask_bounds_rect(vase: Rect2) -> Rect2:
	if not _has_mask_bounds():
		return vase
	var mask_rect := _mask_rect(vase)
	var img_size := Vector2(_mask_img.get_width(), _mask_img.get_height())
	var pos := mask_rect.position + Vector2(_mask_bounds.position.x, _mask_bounds.position.y) * mask_rect.size / img_size
	var bounds_size := Vector2(_mask_bounds.size.x, _mask_bounds.size.y) * mask_rect.size / img_size
	return Rect2(pos, bounds_size)


func _row_span(row: int) -> Vector2i:
	if _mask_row_spans.is_empty():
		return Vector2i(-1, -1)
	var clamped := clampi(row, 0, _mask_row_spans.size() - 1)
	var span: Vector2i = _mask_row_spans[clamped]
	if span.x >= 0:
		return span
	for step in range(1, _mask_row_spans.size()):
		var up := clamped - step
		if up >= 0:
			span = _mask_row_spans[up]
			if span.x >= 0:
				return span
		var down := clamped + step
		if down < _mask_row_spans.size():
			span = _mask_row_spans[down]
			if span.x >= 0:
				return span
	return Vector2i(-1, -1)
