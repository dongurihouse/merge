@tool
extends Control
## Stitched cascade readiness and drag-guide marks. The board owns the data and
## geometry; this node only renders it and never handles input.

const G = preload("res://engine/scripts/core/content.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const Pal = Game.PALETTE
const TAG_Z_INDEX := 20
const RUNWAY_WIDTH_SCALE := 0.62
const EXTENSION_WIDTH_SCALE := 0.72

@export var inset_frac := 0.10: set = _set_inset
@export var dash_frac := 0.16: set = _set_dash
@export var gap_frac := 0.10: set = _set_dash_gap
@export var thickness_frac := 0.035: set = _set_thickness
@export var fill_pct := 5.0: set = _set_fill_pct
@export var jitter_frac := 0.012: set = _set_jitter

var ladders: Array = []
var runways: Array = []
var ghost_pads: Array = []
var cell_size := 86.0
var cell_pos_fn: Callable

func _set_inset(v: float) -> void: inset_frac = v; queue_redraw()
func _set_dash(v: float) -> void: dash_frac = v; queue_redraw()
func _set_dash_gap(v: float) -> void: gap_frac = v; queue_redraw()
func _set_thickness(v: float) -> void: thickness_frac = v; queue_redraw()
func _set_fill_pct(v: float) -> void: fill_pct = v; queue_redraw()
func _set_jitter(v: float) -> void: jitter_frac = v; queue_redraw()

func _ready() -> void:
	name = "CascadeOutline"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func configure(board_size: Vector2, csz: float, cell_pos: Callable) -> void:
	size = board_size
	cell_size = csz
	cell_pos_fn = cell_pos
	_rebuild_tags()
	queue_redraw()

func set_ladders(data: Array) -> void:
	ladders = data.duplicate(true)
	_rebuild_tags()
	queue_redraw()

func set_runways(data: Array) -> void:
	runways = data.duplicate(true)
	_rebuild_tags()
	queue_redraw()

func set_ghost_pads(data: Array) -> void:
	ghost_pads = data.duplicate(true)
	_rebuild_tags()
	queue_redraw()

func clear_guides() -> void:
	if ghost_pads.is_empty():
		return
	ghost_pads = []
	_rebuild_tags()
	queue_redraw()

func _draw() -> void:
	if cell_size <= 0.0 or not cell_pos_fn.is_valid():
		return
	for entry in runways:
		if entry is Dictionary:
			_draw_runway(entry as Dictionary)
	for entry in ladders:
		if entry is Dictionary:
			_draw_ladder(entry as Dictionary)
	for entry in ghost_pads:
		if entry is Dictionary:
			_draw_ghost_pad(entry as Dictionary)

func _draw_ladder(entry: Dictionary) -> void:
	var cells: Array = Array(entry.get("cells", []))
	if cells.is_empty():
		return
	var n := int(entry.get("n", 2))
	var color := G.line_color(int(entry.get("line", 0)))
	var wash := Color(color, clampf(fill_pct / 100.0, 0.0, 0.12))
	var edge := Color(color.lightened(0.18), _alpha_for_n(n))
	var shadow := Color(Pal.INK, 0.18)
	var width := _mark_thickness({"kind": "armed", "n": n})
	var set := {}
	for raw in cells:
		set[Vector2i(raw)] = true
	for raw in cells:
		var cell := Vector2i(raw)
		var rect := Rect2(_cell_pos(cell) + Vector2.ONE * (cell_size * inset_frac), Vector2.ONE * cell_size * (1.0 - inset_frac * 2.0))
		draw_rect(rect, wash, true)
		_draw_perimeter_edges(cell, set, shadow, edge, width)

func _draw_runway(entry: Dictionary) -> void:
	var cells: Array = Array(entry.get("cells", []))
	if cells.is_empty():
		return
	var color := G.line_color(int(entry.get("line", 0)))
	var wash := Color(color, clampf(fill_pct / 100.0 * 0.45, 0.0, 0.06))
	var edge := Color(color.lightened(0.10), 0.26)
	var shadow := Color(Pal.INK, 0.10)
	var width := _mark_thickness({"kind": "runway", "would_be_n": int(entry.get("would_be_n", 3))})
	var set := {}
	for raw in cells:
		set[Vector2i(raw)] = true
	for raw in cells:
		var cell := Vector2i(raw)
		var rect := Rect2(_cell_pos(cell) + Vector2.ONE * (cell_size * inset_frac), Vector2.ONE * cell_size * (1.0 - inset_frac * 2.0))
		draw_rect(rect, wash, true)
		_draw_perimeter_edges(cell, set, shadow, edge, width)

func _draw_ghost_pad(entry: Dictionary) -> void:
	var cell := Vector2i(entry.get("cell", Vector2i(-1, -1)))
	if cell.x < 0:
		return
	var n := int(entry.get("n", 2))
	var line := int(entry.get("line", 0))
	var kind := String(entry.get("kind", "ignition"))
	var color := G.line_color(line)
	var rect := Rect2(_cell_pos(cell) + Vector2.ONE * (cell_size * 0.12), Vector2.ONE * cell_size * 0.76)
	var tint_alpha := 0.08 if kind == "ignition" else 0.035
	draw_rect(rect, Color(color, tint_alpha), true)
	var alpha := _alpha_for_n(n) + 0.08 if kind == "ignition" else 0.28
	var edge := Color(color.lightened(0.25 if kind == "ignition" else 0.12), alpha)
	_draw_dashed_rect(rect, edge, _mark_thickness(entry))

func _draw_perimeter_edges(cell: Vector2i, cell_set: Dictionary, shadow: Color, edge: Color, width: float) -> void:
	for raw_d in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
		var d := Vector2i(raw_d)
		if cell_set.has(cell + d):
			continue
		var seg := _perimeter_edge_segment(cell, d)
		var a := Vector2(seg[0])
		var b := Vector2(seg[1])
		var key := _edge_key(cell, d)
		_draw_dashed_line(a + Vector2(0.0, 1.5), b + Vector2(0.0, 1.5), shadow, width + 1.5, key)
		_draw_dashed_line(a, b, edge, width, key)

func _perimeter_edge_segment(cell: Vector2i, neighbour_delta: Vector2i) -> Array:
	var p := _cell_pos(cell) + Vector2.ONE * (cell_size * inset_frac)
	var s := cell_size * (1.0 - inset_frac * 2.0)
	var delta := _cell_pos(cell + neighbour_delta) - _cell_pos(cell)
	if absf(delta.x) > absf(delta.y):
		if delta.x < 0.0:
			return [p, p + Vector2(0.0, s)]
		return [p + Vector2(s, 0.0), p + Vector2(s, s)]
	if delta.y < 0.0:
		return [p, p + Vector2(s, 0.0)]
	return [p + Vector2(0.0, s), p + Vector2(s, s)]

func _draw_dashed_rect(rect: Rect2, color: Color, width: float) -> void:
	_draw_dashed_line(rect.position, Vector2(rect.end.x, rect.position.y), color, width, 11)
	_draw_dashed_line(Vector2(rect.end.x, rect.position.y), rect.end, color, width, 23)
	_draw_dashed_line(rect.end, Vector2(rect.position.x, rect.end.y), color, width, 37)
	_draw_dashed_line(Vector2(rect.position.x, rect.end.y), rect.position, color, width, 41)

func _draw_dashed_line(a: Vector2, b: Vector2, color: Color, width: float, jitter_key := 0) -> void:
	var length := a.distance_to(b)
	if length <= 0.1:
		return
	var dir := (b - a).normalized()
	var normal := Vector2(-dir.y, dir.x)
	var dash := maxf(4.0, cell_size * dash_frac)
	var gap := maxf(3.0, cell_size * gap_frac)
	var t := 0.0
	var stitch := 0
	while t < length:
		var end_t := minf(t + dash, length)
		var j := normal * _stitch_jitter(jitter_key, stitch)
		var start := a + dir * t + j
		var finish := a + dir * end_t + j
		draw_line(start, finish, color, width, true)
		draw_circle(start, width * 0.5, color)
		draw_circle(finish, width * 0.5, color)
		t += dash + gap
		stitch += 1

func _rebuild_tags() -> void:
	for child in get_children():
		child.queue_free()
	if not cell_pos_fn.is_valid():
		return
	for entry in ladders:
		if not (entry is Dictionary):
			continue
		var top_cell := Vector2i((entry as Dictionary).get("top_cell", Vector2i(-1, -1)))
		if top_cell.x < 0:
			continue
		var n := int((entry as Dictionary).get("n", 2))
		_add_tag(top_cell, "×%d" % n, n, false)
	for entry in runways:
		if not (entry is Dictionary):
			continue
		var cells: Array = Array((entry as Dictionary).get("cells", []))
		if cells.is_empty():
			continue
		var need := int((entry as Dictionary).get("needs_code", 0))
		if need <= 0:
			continue
		_add_tag(Vector2i(cells[0]), "t%d" % (need % 100), int((entry as Dictionary).get("would_be_n", 3)), true)
	for entry in ghost_pads:
		if not (entry is Dictionary) or String((entry as Dictionary).get("kind", "ignition")) != "ignition":
			continue
		var cell := Vector2i((entry as Dictionary).get("cell", Vector2i(-1, -1)))
		if cell.x < 0:
			continue
		var n := int((entry as Dictionary).get("n", 2))
		_add_tag(cell, "×%d" % n, n, false)

func _add_tag(cell: Vector2i, text: String, n: int, weak: bool) -> void:
	var chip := Label.new()
	chip.name = "CascadeTag"
	chip.text = text
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.z_as_relative = false
	chip.z_index = TAG_Z_INDEX
	chip.theme = load("res://engine/scripts/ui/ui_font.gd").make()
	chip.add_theme_font_size_override("font_size", _tag_font_size(n, weak))
	chip.add_theme_color_override("font_color", Color(Pal.CREAM, 0.82 if weak else 1.0))
	chip.add_theme_color_override("font_outline_color", Color(Pal.INK, 0.78 if weak else 1.0))
	chip.add_theme_constant_override("outline_size", maxi(1 if weak else 2, int(roundf(cell_size * (0.018 if weak else 0.025)))))
	chip.position = _cell_pos(cell) + Vector2(cell_size * (0.55 if weak else 0.58), -cell_size * (0.03 if weak else 0.08))
	chip.custom_minimum_size = Vector2(cell_size * (0.28 if weak else (0.34 + 0.035 * float(mini(n, 7) - 2))), cell_size * 0.22)
	add_child(chip)

func _cell_pos(cell: Vector2i) -> Vector2:
	return Vector2(cell_pos_fn.call(cell))

func _alpha_for_n(n: int) -> float:
	return clampf(0.42 + float(mini(n, 4) - 2) * 0.12, 0.42, 0.72)

func _thickness_for_n(n: int) -> float:
	return maxf(2.0, cell_size * thickness_frac + float(mini(n, 4) - 2) * 0.8)

func _mark_thickness(entry: Dictionary) -> float:
	var kind := String(entry.get("kind", "armed"))
	var n := int(entry.get("n", entry.get("would_be_n", 3)))
	var scale := RUNWAY_WIDTH_SCALE if kind == "runway" else (EXTENSION_WIDTH_SCALE if kind == "extension" else 1.0)
	return maxf(1.4, _thickness_for_n(n) * scale)

func _tag_font_size(n: int, weak := false) -> int:
	var scale := 0.78 if weak else 1.0
	return maxi(12 if weak else 14, int(roundf(cell_size * (0.22 + 0.018 * float(mini(n, 7) - 2)) * scale)))

func _edge_key(cell: Vector2i, d: Vector2i) -> int:
	return cell.x * 1009 + cell.y * 917 + (d.x + 2) * 37 + (d.y + 2) * 53

func _stitch_jitter(key: int, stitch: int) -> float:
	var span := cell_size * jitter_frac
	if span <= 0.0:
		return 0.0
	var h := absi(key * 1103515245 + stitch * 12345 + 6789) % 1000
	return (float(h) / 999.0 - 0.5) * 2.0 * span
