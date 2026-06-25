@tool
extends Control
## Animated water overlay for the prototype vase/jar asset.

const VASE_PATH := "res://games/grove/assets/ui/vase/vase_front.png"
const LOOP_SECONDS := 4.8
const IDLE_ENERGY := 1.2
const IMPACT_ENERGY := 7.5
const IMPACT_TIME := 2.05
const IMPACT_X := 0.50

const _SAMPLES := 28
const _DROP_START := 0.45
const _DROP_GROWN := 1.18
const _IMPACT_TAIL := 1.5
const _WATER := Color("#3CBCE9")
const _SURFACE := Color("#BDF5FF")

var _time := 0.0
var _energy := IDLE_ENERGY
var _impact_age := 999.0
var _tex: Texture2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tex = load(VASE_PATH) as Texture2D
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


func energy_for_test() -> float:
	return _energy


func water_surface_for_test() -> PackedVector2Array:
	return _surface_points(_vase_rect())


func get_texture_for_test() -> Texture2D:
	if _tex == null:
		_tex = load(VASE_PATH) as Texture2D
	return _tex


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
	draw_texture_rect(tex, vase, false)
	_draw_water_overlay(vase)
	_draw_drop(vase)


func _draw_water_overlay(vase: Rect2) -> void:
	var surface := _surface_points(vase)
	var body := PackedVector2Array(surface)
	for i in range(6):
		var t := float(i) / 5.0
		var y := lerpf(_waterline_y(vase), vase.position.y + vase.size.y * 0.84, t)
		var half := _half_width_at(vase, y)
		body.append(Vector2(_center_x(vase) + half, y))
	for i in range(5, -1, -1):
		var t := float(i) / 5.0
		var y := lerpf(_waterline_y(vase), vase.position.y + vase.size.y * 0.84, t)
		var half := _half_width_at(vase, y)
		body.append(Vector2(_center_x(vase) - half, y))

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


func _draw_drop(vase: Rect2) -> void:
	var st := _drop_state(vase)
	if not bool(st.visible):
		return
	var center := Vector2(float(st.x), float(st.y))
	var radius := float(st.radius)
	var alpha := float(st.alpha)
	var col := _WATER
	col.a = 0.78 * alpha
	draw_circle(center, radius, col)
	draw_circle(center + Vector2(-radius * 0.25, -radius * 0.35), radius * 0.24,
		Color(1, 1, 1, 0.42 * alpha))


func _vase_rect() -> Rect2:
	var view := Vector2(maxf(size.x, 1.0), maxf(size.y, 1.0))
	var tex := get_texture_for_test()
	var tex_size := Vector2(383, 444)
	if tex != null:
		tex_size = Vector2(tex.get_width(), tex.get_height())
	var scale := minf(view.x / tex_size.x, view.y / tex_size.y)
	var rect_size := tex_size * scale
	return Rect2((view - rect_size) * 0.5, rect_size)


func _surface_points(vase: Rect2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var y := _waterline_y(vase)
	var cx := _center_x(vase)
	var half := _half_width_at(vase, y)
	for i in range(_SAMPLES + 1):
		var u := float(i) / float(_SAMPLES)
		var x := lerpf(cx - half, cx + half, u)
		pts.append(Vector2(x, y + _wave_height(u)))
	return pts


func _wave_height(unit_x: float) -> float:
	var base := sin(unit_x * TAU * 1.35 + _time * 2.2) * _energy
	base += sin(unit_x * TAU * 2.7 - _time * 3.0) * _energy * 0.32
	var dist := absf(unit_x - IMPACT_X)
	var impact := exp(-dist * dist * 46.0) * cos(_impact_age * 13.0) * _impact_envelope() * 5.5
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
	var radius := vase.size.x * 0.018
	var y := top_y
	if _time <= _DROP_GROWN:
		var grow_t := smoothstep(_DROP_START, _DROP_GROWN, _time)
		radius = lerpf(vase.size.x * 0.014, vase.size.x * 0.032, grow_t)
		y = top_y - vase.size.y * 0.015 * sin(grow_t * PI)
	else:
		var fall_t := smoothstep(_DROP_GROWN, IMPACT_TIME, _time)
		radius = lerpf(vase.size.x * 0.032, vase.size.x * 0.022, fall_t)
		y = lerpf(top_y, hit_y, fall_t * fall_t)
	return {"visible": true, "x": x, "y": y, "radius": radius, "alpha": 1.0}


func _waterline_y(vase: Rect2) -> float:
	return vase.position.y + vase.size.y * 0.415


func _center_x(vase: Rect2) -> float:
	return vase.position.x + vase.size.x * 0.50


func _half_width_at(vase: Rect2, y: float) -> float:
	var v := clampf((y - vase.position.y) / vase.size.y, 0.0, 1.0)
	var top_half := vase.size.x * 0.44
	var belly_half := vase.size.x * 0.47
	var bottom_half := vase.size.x * 0.36
	if v < 0.62:
		return lerpf(top_half, belly_half, smoothstep(0.38, 0.62, v))
	return lerpf(belly_half, bottom_half, smoothstep(0.62, 0.86, v))
