extends Control
## Self-drawing Weather Hours lane wash. It sits in board_area after the slots and
## before pieces, so tree order keeps the wash under every tile without a positive z.

const G = preload("res://engine/scripts/core/content.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const Pal = Game.PALETTE

var sky_state: Dictionary = {}
var cell_size := 80.0
var gap := 7.0
var landscape := false
var _breath: Tween

func setup(state: Dictionary, csz: float, cell_gap: float, is_landscape: bool) -> void:
	name = "SkyPatch"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky_state = state.duplicate(true)
	cell_size = csz
	gap = cell_gap
	landscape = is_landscape
	custom_minimum_size = Vector2(_board_w(), _board_h())
	size = custom_minimum_size
	queue_redraw()

func _ready() -> void:
	_start_breathe()

func _start_breathe() -> void:
	if _breath != null:
		_breath.kill()
	modulate = Color(1, 1, 1, 0.9)
	_breath = create_tween()
	_breath.set_loops()
	_breath.tween_property(self, "modulate:a", 1.0, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_breath.tween_property(self, "modulate:a", 0.82, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _draw() -> void:
	var sky := String(sky_state.get("sky", ""))
	# Calm projects no lane (lane == -1), so there is nothing to wash — board.gd never mounts a patch
	# for it, and this guard keeps a mis-set state from painting a stripe off the edge of the mat.
	if sky == "" or sky == "calm" or int(sky_state.get("lane", -1)) < 0:
		return
	var r := _lane_rect().grow(cell_size * 0.08)
	var samples := lane_alpha_samples(sky)
	var center := _patch_color(sky, float(samples.center))
	var edge := _edge_color(sky, float(samples.edge))
	draw_rect(r, center, true)
	for er in _edge_rects(r):
		draw_rect(er, edge, true)
	match sky:
		"rain":
			_draw_rain_ticks(r)
		"starfall":
			_draw_star_glints(r)
		_:
			_draw_sun_edges(r)

func lane_alpha_samples(sky: String) -> Dictionary:
	var base := float(G.PATCH_ALPHA.get(sky, 0.13))
	match sky:
		"sunbeam":
			return {"center": base * 0.56, "edge": minf(0.58, base * 1.42)}
		"starfall":
			return {"center": maxf(0.085, base * 0.72), "edge": minf(0.38, maxf(0.30, base * 2.55))}
		"rain":
			return {"center": base * 0.82, "edge": minf(0.26, base * 1.26)}
		_:
			return {"center": base * 0.72, "edge": minf(0.30, base * 1.2)}

func _lane_rect() -> Rect2:
	var axis := String(sky_state.get("lane_axis", "column"))
	var lane := int(sky_state.get("lane", 0))
	var first := Vector2i(lane, 0) if axis == "row" else Vector2i(0, lane)
	var last := Vector2i(lane, G.COLS - 1) if axis == "row" else Vector2i(G.ROWS - 1, lane)
	var a := _cell_pos(first)
	var b := _cell_pos(last)
	var pos := Vector2(minf(a.x, b.x), minf(a.y, b.y))
	var end := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2(cell_size, cell_size)
	return Rect2(pos, end - pos)

func _cell_pos(cell: Vector2i) -> Vector2:
	var step := cell_size + gap
	if landscape:
		return Vector2(cell.x * step, cell.y * step)
	return Vector2(cell.y * step, cell.x * step)

func _board_w() -> float:
	var cols := G.ROWS if landscape else G.COLS
	return cols * cell_size + (cols - 1) * gap

func _board_h() -> float:
	var rows := G.COLS if landscape else G.ROWS
	return rows * cell_size + (rows - 1) * gap

func _patch_color(sky: String, alpha: float) -> Color:
	match sky:
		"rain":
			return Color(Pal.SKY, alpha)
		"starfall":
			return Color(Pal.CREAM, alpha)
		_:
			return Color(Pal.STRAW, alpha)

func _edge_color(sky: String, alpha: float) -> Color:
	match sky:
		"rain":
			return Color(Pal.SKY, alpha)
		"starfall":
			return Color(Pal.STRAW, alpha)
		_:
			return Color(Pal.STRAW, alpha)

func _edge_rects(r: Rect2) -> Array:
	var band := maxf(5.0, cell_size * 0.14)
	if String(sky_state.get("lane_axis", "column")) == "row":
		return [
			Rect2(r.position, Vector2(r.size.x, band)),
			Rect2(Vector2(r.position.x, r.end.y - band), Vector2(r.size.x, band)),
		]
	return [
		Rect2(r.position, Vector2(band, r.size.y)),
		Rect2(Vector2(r.end.x - band, r.position.y), Vector2(band, r.size.y)),
	]

func _draw_rain_ticks(r: Rect2) -> void:
	var tick := Color(Pal.SKY, 0.26)
	for i in 9:
		var x := r.position.x + r.size.x * (float(i) + 0.5) / 9.0
		var y := r.position.y + r.size.y * (0.18 + 0.64 * float((i * 37) % 100) / 100.0)
		draw_line(Vector2(x, y), Vector2(x + cell_size * 0.08, y + cell_size * 0.16), tick, 2.0)

func _draw_star_glints(r: Rect2) -> void:
	var gold := Color(Pal.STRAW, 0.46)
	for i in 6:
		var x := r.position.x + r.size.x * (float((i * 29) % 100) / 100.0)
		var y := r.position.y + r.size.y * (float((i * 47 + 15) % 100) / 100.0)
		var p := Vector2(x, y)
		draw_line(p + Vector2(-5, 0), p + Vector2(5, 0), gold, 1.5)
		draw_line(p + Vector2(0, -5), p + Vector2(0, 5), gold, 1.5)

func _draw_sun_edges(r: Rect2) -> void:
	var edge := Color(Pal.STRAW, 0.30)
	draw_rect(Rect2(r.position, Vector2(4, r.size.y)), edge, true)
	draw_rect(Rect2(Vector2(r.end.x - 4, r.position.y), Vector2(4, r.size.y)), edge, true)
