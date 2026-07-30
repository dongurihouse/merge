extends Control
## Self-drawing Weather Hours lane wash. It sits in board_area after the slots and
## before pieces, so tree order keeps the wash under every tile without a positive z.
##
## Everything the patch paints is CLIPPED to the board panel's rounded silhouette (`clip_rect` +
## `clip_corner`, handed in by board.gd from the mat's own geometry and its stamped
## Look.SHADOW_CORNER_META). An edge lane's square corner used to stick ~13 px past the panel's
## rounded corner and read as a chip of wash floating on the scene background. One rule, no
## per-shape exceptions: `wash_shapes()` intersects every fill and every decorative line with the
## silhouette, and `_draw()` paints exactly what that accessor returns.

const G = preload("res://engine/scripts/core/content.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const Pal = Game.PALETTE

## Segments per 90° corner of the clip silhouette. The polygon is INSCRIBED in the true arc, so it
## errs INWARD by at most the sagitta r·(1 − cos(45°/SEGMENTS)); at 12 that is 0.0021·r — 0.065 px
## at the largest corner the board config can produce (30), far under one pixel, so the arc reads
## smooth on the translucent wash and the clip can never spill outside the real panel.
const CORNER_SEGMENTS := 12

var sky_state: Dictionary = {}
var cell_size := 80.0
var gap := 7.0
var landscape := false
## The board panel's silhouette in this Control's own coordinates. An EMPTY rect means "no
## silhouette was handed in" and the patch degrades to the unclipped square wash.
var clip_rect := Rect2()
var clip_corner := 0.0
var _breath: Tween

## `silhouette` is board.gd's `_board_mat_silhouette()`: {"rect": Rect2, "corner": float}. Absent or
## empty ⇒ unclipped.
func setup(state: Dictionary, csz: float, cell_gap: float, is_landscape: bool, silhouette: Dictionary = {}) -> void:
	name = "SkyPatch"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky_state = state.duplicate(true)
	cell_size = csz
	gap = cell_gap
	landscape = is_landscape
	clip_rect = silhouette.get("rect", Rect2())
	clip_corner = float(silhouette.get("corner", 0.0))
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
	for shape in wash_shapes():
		var pts: PackedVector2Array = shape["points"]
		if String(shape["kind"]) == "fill":
			if pts.size() >= 3:
				draw_colored_polygon(pts, shape["color"])
		elif pts.size() >= 2:
			draw_polyline(pts, shape["color"], float(shape["width"]))

## Everything the patch paints, already clipped to the board panel — the SINGLE source `_draw()`
## consumes, so a headless guard can read the real painted geometry instead of re-deriving it.
## Each entry is {"kind": "fill"|"line", "points": PackedVector2Array, "color": Color, "width": float}.
func wash_shapes() -> Array:
	var shapes: Array = []
	var sky := String(sky_state.get("sky", ""))
	# Calm projects no lane (lane == -1), so there is nothing to wash — board.gd never mounts a patch
	# for it, and this guard keeps a mis-set state from painting a stripe off the edge of the mat.
	if sky == "" or sky == "calm" or int(sky_state.get("lane", -1)) < 0:
		return shapes
	var r := _lane_rect().grow(cell_size * 0.08)
	var samples := lane_alpha_samples(sky)
	var center := _patch_color(sky, float(samples.center))
	var edge := _edge_color(sky, float(samples.edge))
	var clip := clip_polygon()
	_add_rect(shapes, clip, r, center)
	for er in _edge_rects(r):
		_add_rect(shapes, clip, er, edge)
	match sky:
		"rain":
			_add_rain_ticks(shapes, clip, r)
		"starfall":
			_add_star_glints(shapes, clip, r)
		_:
			_add_sun_edges(shapes, clip, r)
	return shapes

## The board panel's rounded silhouette as a polygon, in this Control's coordinates. Empty when no
## silhouette was handed in — every clip helper then passes its shape through untouched.
func clip_polygon() -> PackedVector2Array:
	if clip_rect.size.x <= 0.0 or clip_rect.size.y <= 0.0:
		return PackedVector2Array()
	return rounded_rect_polygon(clip_rect, clip_corner, CORNER_SEGMENTS)

## A rounded rect as an INSCRIBED polygon, wound counter-clockwise (Geometry2D reads a clockwise
## ring as a HOLE, so every polygon this file hands to it is normalised the same way).
static func rounded_rect_polygon(rect: Rect2, corner: float, segments: int) -> PackedVector2Array:
	var r := clampf(corner, 0.0, minf(rect.size.x, rect.size.y) * 0.5)
	if r <= 0.0 or segments < 1:
		return _ccw(PackedVector2Array([
			rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]))
	# arc centres in draw order: top-right, bottom-right, bottom-left, top-left; each sweeps 90°
	# starting at -90° + i·90°, so consecutive arcs are joined by the panel's straight edges.
	var centers := [
		Vector2(rect.end.x - r, rect.position.y + r),
		Vector2(rect.end.x - r, rect.end.y - r),
		Vector2(rect.position.x + r, rect.end.y - r),
		Vector2(rect.position.x + r, rect.position.y + r),
	]
	var pts := PackedVector2Array()
	for i in centers.size():
		var start := -PI / 2.0 + float(i) * PI / 2.0
		for s in segments + 1:
			var a := start + (PI / 2.0) * float(s) / float(segments)
			pts.append(centers[i] + Vector2(cos(a), sin(a)) * r)
	return _ccw(pts)

static func _ccw(poly: PackedVector2Array) -> PackedVector2Array:
	if Geometry2D.is_polygon_clockwise(poly):
		poly.reverse()
	return poly

func _add_rect(shapes: Array, clip: PackedVector2Array, r: Rect2, color: Color) -> void:
	var poly := _ccw(PackedVector2Array([
		r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]))
	if clip.is_empty():
		shapes.append({"kind": "fill", "points": poly, "color": color, "width": 0.0})
		return
	for piece in Geometry2D.intersect_polygons(poly, clip):
		shapes.append({"kind": "fill", "points": piece, "color": color, "width": 0.0})

func _add_line(shapes: Array, clip: PackedVector2Array, a: Vector2, b: Vector2, color: Color, width: float) -> void:
	var seg := PackedVector2Array([a, b])
	if clip.is_empty():
		shapes.append({"kind": "line", "points": seg, "color": color, "width": width})
		return
	for piece in Geometry2D.intersect_polyline_with_polygon(seg, clip):
		shapes.append({"kind": "line", "points": piece, "color": color, "width": width})

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

func _add_rain_ticks(shapes: Array, clip: PackedVector2Array, r: Rect2) -> void:
	var tick := Color(Pal.SKY, 0.26)
	for i in 9:
		var x := r.position.x + r.size.x * (float(i) + 0.5) / 9.0
		var y := r.position.y + r.size.y * (0.18 + 0.64 * float((i * 37) % 100) / 100.0)
		_add_line(shapes, clip, Vector2(x, y), Vector2(x + cell_size * 0.08, y + cell_size * 0.16), tick, 2.0)

func _add_star_glints(shapes: Array, clip: PackedVector2Array, r: Rect2) -> void:
	var gold := Color(Pal.STRAW, 0.46)
	for i in 6:
		var x := r.position.x + r.size.x * (float((i * 29) % 100) / 100.0)
		var y := r.position.y + r.size.y * (float((i * 47 + 15) % 100) / 100.0)
		var p := Vector2(x, y)
		_add_line(shapes, clip, p + Vector2(-5, 0), p + Vector2(5, 0), gold, 1.5)
		_add_line(shapes, clip, p + Vector2(0, -5), p + Vector2(0, 5), gold, 1.5)

func _add_sun_edges(shapes: Array, clip: PackedVector2Array, r: Rect2) -> void:
	var edge := Color(Pal.STRAW, 0.30)
	_add_rect(shapes, clip, Rect2(r.position, Vector2(4, r.size.y)), edge)
	_add_rect(shapes, clip, Rect2(Vector2(r.end.x - 4, r.position.y), Vector2(4, r.size.y)), edge)
