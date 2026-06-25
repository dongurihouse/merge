@tool
extends Control
## Code-drawn half-filled water box with a looping droplet impact.

const LOOP_SECONDS := 4.8
const IDLE_ENERGY := 2.2
const IMPACT_ENERGY := 18.0
const IMPACT_TIME := 2.05
const IMPACT_X := 0.52

const _DROP_START := 0.45
const _DROP_GROWN := 1.18
const _SURFACE_SAMPLES := 56
const _IMPACT_TAIL := 1.7
const _WATER := Color("#42B9E6")
const _WATER_DEEP := Color("#1878AE")
const _WATER_LINE := Color("#BAF2FF")
const _GLASS := Color(0.82, 0.95, 1.0, 0.46)
const _GLASS_HI := Color(1.0, 1.0, 1.0, 0.38)
const _GLASS_DIM := Color(0.25, 0.56, 0.70, 0.32)
const _SHADOW := Color(0.02, 0.05, 0.08, 0.30)
const _SPLASH_BITS := [
	{"x": -0.18, "vx": -48.0, "vy": -66.0, "r": 3.4},
	{"x": -0.08, "vx": -24.0, "vy": -86.0, "r": 2.7},
	{"x": 0.04, "vx": 18.0, "vy": -78.0, "r": 3.1},
	{"x": 0.14, "vx": 43.0, "vy": -58.0, "r": 2.5},
]

var _time := 0.0
var _energy := IDLE_ENERGY
var _impact_age := 999.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


func _process(delta: float) -> void:
	_advance(delta, true)


func advance_for_test(delta: float) -> void:
	_advance(delta, false)


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


func wave_height_for_test(unit_x: float) -> float:
	return _wave_height(clampf(unit_x, 0.0, 1.0))


func drop_state_for_test() -> Dictionary:
	return _drop_state()


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
		_energy = lerpf(_energy, IDLE_ENERGY, clampf(delta * 1.35, 0.0, 1.0))
	else:
		_energy = lerpf(_energy, IDLE_ENERGY, clampf(delta * 0.8, 0.0, 1.0))

	queue_redraw()


func _trigger_impact() -> void:
	_time = IMPACT_TIME
	_energy = IMPACT_ENERGY
	_impact_age = 0.0
	queue_redraw()


func _draw() -> void:
	var tank := _tank_rect()
	var surface_y := _surface_y(tank)
	var surface := _surface_points(tank, surface_y)

	var shadow_rect := tank.grow(12.0)
	shadow_rect.position += Vector2(0, 12)
	draw_rect(shadow_rect, _SHADOW, true)
	draw_rect(tank, Color(0.86, 0.98, 1.0, 0.06), true)
	_draw_water(tank, surface)
	_draw_impact_fx(tank, surface_y)
	_draw_drop()
	_draw_tank(tank)


func _draw_tank(tank: Rect2) -> void:
	draw_rect(tank, _GLASS, false, 5.0)
	draw_rect(tank.grow(-8.0), _GLASS_DIM, false, 1.5)
	draw_line(tank.position + Vector2(18, 18),
		tank.position + Vector2(18, tank.size.y - 24), _GLASS_HI, 3.0)
	draw_line(tank.position + Vector2(30, 16),
		tank.position + Vector2(tank.size.x - 30, 16), Color(1, 1, 1, 0.18), 2.0)
	draw_line(tank.position + Vector2(tank.size.x - 10, 28),
		tank.position + tank.size - Vector2(10, 28), Color(0.08, 0.18, 0.24, 0.22), 3.0)


func _draw_water(tank: Rect2, surface: PackedVector2Array) -> void:
	var water := PackedVector2Array(surface)
	water.append(tank.position + tank.size - Vector2(0, 5))
	water.append(tank.position + Vector2(0, tank.size.y - 5))
	var fill_col := _WATER
	fill_col.a = 0.66
	draw_colored_polygon(water, fill_col)

	var lower := Rect2(tank.position + Vector2(6, tank.size.y * 0.61), Vector2(tank.size.x - 12, tank.size.y * 0.33))
	var deep_col := _WATER_DEEP
	deep_col.a = 0.30
	draw_rect(lower, deep_col, true)
	draw_polyline(surface, _WATER_LINE, 4.0, true)
	draw_polyline(surface, Color(1, 1, 1, 0.36), 1.3, true)


func _draw_drop() -> void:
	var st := _drop_state()
	if not bool(st.visible):
		return
	var center := Vector2(float(st.x), float(st.y))
	var radius := float(st.radius)
	var alpha := float(st.alpha)
	var col := _WATER
	col.a = 0.84 * alpha
	draw_circle(center, radius, col)
	draw_circle(center + Vector2(-radius * 0.28, -radius * 0.34), radius * 0.28,
		Color(1, 1, 1, 0.42 * alpha))
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(0, -radius * 1.55),
		center + Vector2(radius * 0.62, -radius * 0.18),
		center + Vector2(-radius * 0.62, -radius * 0.18),
	]), col)


func _draw_impact_fx(tank: Rect2, surface_y: float) -> void:
	if _impact_age > _IMPACT_TAIL:
		return
	var env := _impact_envelope()
	var hit := Vector2(tank.position.x + tank.size.x * IMPACT_X, surface_y)
	for i in 2:
		var ring_age := clampf(_impact_age - float(i) * 0.18, 0.0, 1.0)
		if ring_age <= 0.0:
			continue
		var col := _WATER_LINE
		col.a = (1.0 - ring_age) * 0.38
		draw_arc(hit, 18.0 + ring_age * (64.0 + float(i) * 18.0),
			0.15 * PI, 0.85 * PI, 28, col, 2.0)

	for bit in _SPLASH_BITS:
		var age := clampf(_impact_age, 0.0, 0.86)
		var fade := maxf(0.0, 1.0 - age / 0.86) * env
		var p := hit + Vector2(float(bit.x) * tank.size.x + float(bit.vx) * age,
			float(bit.vy) * age + 118.0 * age * age)
		draw_circle(p, float(bit.r) * (0.65 + fade * 0.45), Color(0.74, 0.94, 1.0, 0.78 * fade))


func _tank_rect() -> Rect2:
	var view := Vector2(maxf(size.x, 1.0), maxf(size.y, 1.0))
	var w := minf(view.x * 0.70, 440.0)
	var h := minf(view.y * 0.72, 410.0)
	var pos := (view - Vector2(w, h)) * 0.5 + Vector2(0, 26)
	return Rect2(pos, Vector2(w, h))


func _surface_y(tank: Rect2) -> float:
	return tank.position.y + tank.size.y * 0.50


func _surface_points(tank: Rect2, surface_y: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(_SURFACE_SAMPLES + 1):
		var u := float(i) / float(_SURFACE_SAMPLES)
		var x := tank.position.x + tank.size.x * u
		var y := surface_y + _wave_height(u)
		y = clampf(y, tank.position.y + 16.0, tank.position.y + tank.size.y - 16.0)
		pts.append(Vector2(x, y))
	return pts


func _wave_height(unit_x: float) -> float:
	var base := sin(unit_x * TAU * 1.25 + _time * 2.0) * _energy
	base += sin(unit_x * TAU * 2.4 - _time * 3.1) * _energy * 0.35
	var dist := absf(unit_x - IMPACT_X)
	var impact := exp(-dist * dist * 58.0) * cos(_impact_age * 13.0) * _impact_envelope() * 12.0
	return base + impact


func _impact_envelope() -> float:
	if _impact_age > _IMPACT_TAIL:
		return 0.0
	return exp(-_impact_age * 2.35)


func _drop_state() -> Dictionary:
	var tank := _tank_rect()
	var top_y := tank.position.y - 74.0
	var hit_y := _surface_y(tank) - 4.0
	var x := tank.position.x + tank.size.x * IMPACT_X
	if _time < _DROP_START or _time > IMPACT_TIME:
		return {"visible": false, "x": x, "y": hit_y, "radius": 0.0, "alpha": 0.0}

	var radius := 5.0
	var y := top_y
	if _time <= _DROP_GROWN:
		var t := smoothstep(_DROP_START, _DROP_GROWN, _time)
		radius = lerpf(4.0, 11.0, t)
		y = top_y - 5.0 * sin(t * PI)
	else:
		var t := smoothstep(_DROP_GROWN, IMPACT_TIME, _time)
		radius = lerpf(11.0, 8.0, t)
		y = lerpf(top_y, hit_y, t * t)

	return {"visible": true, "x": x, "y": y, "radius": radius, "alpha": 1.0}
