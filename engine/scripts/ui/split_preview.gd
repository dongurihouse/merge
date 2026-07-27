@tool
extends Control
## Drag-hover preview for scissors: two translucent lower-tier twins plus a
## cream dashed target outline and center seam. The board supplies the piece art.

const PieceView = preload("res://engine/scripts/ui/piece_view.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const Pal = Game.PALETTE

var code := 0

func setup(next_code: int, cell_size: float) -> void:
	code = int(next_code)
	custom_minimum_size = Vector2(cell_size, cell_size)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_twins(cell_size)
	queue_redraw()

func _build_twins(cell_size: float) -> void:
	for c in get_children():
		c.queue_free()
	if code <= 0:
		return
	var ghost_size := cell_size * 0.62
	var left := PieceView.make_piece(code, ghost_size, 0.0)
	var right := PieceView.make_piece(code, ghost_size, 0.0)
	left.modulate.a = 0.50
	right.modulate.a = 0.50
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.position = Vector2(cell_size * 0.08, cell_size * 0.20)
	right.position = Vector2(cell_size * 0.30, cell_size * 0.20)
	add_child(left)
	add_child(right)

func _draw() -> void:
	var s := minf(size.x, size.y)
	if s <= 0.0:
		return
	var cream := Color(Pal.CREAM, 0.78)
	var edge := Rect2(Vector2(s * 0.08, s * 0.08), Vector2(s * 0.84, s * 0.84))
	_dashed_rect(edge, cream, maxf(2.0, s * 0.035), s * 0.11, s * 0.06)
	draw_line(Vector2(s * 0.50, s * 0.16), Vector2(s * 0.50, s * 0.84), cream, maxf(2.0, s * 0.025), true)

func _dashed_rect(rect: Rect2, col: Color, width: float, dash: float, gap: float) -> void:
	var pts := [
		rect.position,
		rect.position + Vector2(rect.size.x, 0.0),
		rect.position + rect.size,
		rect.position + Vector2(0.0, rect.size.y),
		rect.position,
	]
	for i in range(4):
		_dashed_line(pts[i], pts[i + 1], col, width, dash, gap)

func _dashed_line(a: Vector2, b: Vector2, col: Color, width: float, dash: float, gap: float) -> void:
	var v := b - a
	var length := v.length()
	if length <= 0.0:
		return
	var dir := v / length
	var cursor := 0.0
	while cursor < length:
		var next := minf(length, cursor + dash)
		draw_line(a + dir * cursor, a + dir * next, col, width, true)
		cursor = next + gap
