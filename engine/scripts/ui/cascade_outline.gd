@tool
extends Control
## Stitched cascade readiness and drag-guide marks. The board owns the data and
## geometry; this node only renders it and never handles input.

const G = preload("res://engine/scripts/core/content.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const Pal = Game.PALETTE
const TAG_Z_INDEX := 20
const RUNWAY_WIDTH_SCALE := 0.62
const MERGE_WIDTH_SCALE := 0.82
const STAGE_WIDTH_SCALE := 0.72
const RIBBON_WIDTH_FRAC := 0.26      # ribbon width as a share of the cell
const PAPER_TEX_PX := 64
const PAPER_SEED := 20260727         # fixed: `make shot` compares captures byte for byte
const JOINT_SIDES := 12

static var _paper: ImageTexture = null

# Matte paper grain, built once. Seeded on purpose — a random grain would break the
# byte-deterministic shot captures the tools rely on.
static func paper_grain() -> ImageTexture:
	if _paper != null:
		return _paper
	var img := Image.create(PAPER_TEX_PX, PAPER_TEX_PX, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = PAPER_SEED
	for y in PAPER_TEX_PX:
		for x in PAPER_TEX_PX:
			var v := 0.93 + rng.randf() * 0.07
			img.set_pixel(x, y, Color(v, v, v))
	_paper = ImageTexture.create_from_image(img)
	return _paper

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
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED   # the grain tiles in board space
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
	_draw_ribbon(Array(entry.get("cells", [])), G.line_color(int(entry.get("line", 0))),
		cell_size * RIBBON_WIDTH_FRAC, 1.0)

func _draw_runway(entry: Dictionary) -> void:
	# A runway is the same ribbon, quieter: it is not going to fire until its piece arrives.
	_draw_ribbon(Array(entry.get("cells", [])), G.line_color(int(entry.get("line", 0))),
		cell_size * RIBBON_WIDTH_FRAC * 0.78, 0.5)

# The chain drawn as one continuous strip of cut paper: from each marked cell's centre out to the
# midpoint of every edge it shares with another marked cell, joints rounded, ends capped. That one
# rule covers every shape a run or a component can take — straight, bend, zigzag, T, cross, even a
# closed ring round a 2x2 block — and the strip meets itself exactly at the cell edges, so nothing
# can misalign. Neighbour directions come from _cell_pos, never from the model delta: _cell_pos
# owns the landscape transpose, and hardcoding portrait here is what once drew rungs instead of a
# border on a wide screen.
func _draw_ribbon(raw_cells: Array, base: Color, width: float, strength: float) -> void:
	if raw_cells.is_empty() or width <= 0.5:
		return
	var cells := {}
	for raw in raw_cells:
		cells[Vector2i(raw)] = true
	# Pull the line colour toward cream first. Full-saturation line colour reads as a new game
	# object competing with the pieces; the group mark has to stay quieter than the drop target
	# it sits under, so this is tape laid on the board, not a painted stripe.
	var tape := base.lerp(Color(0.98, 0.95, 0.88), 0.42)
	var lift := maxf(1.5, cell_size * 0.035)
	# Cut-paper stack, bottom to top: contact shadow, the warm cut edge the fill sits inside,
	# the grained face, then a light top plane along the upper side.
	_ribbon_pass(cells, width * 1.02, Color(Pal.INK, 0.20 * strength), Vector2(0.0, lift), null)
	_ribbon_pass(cells, width * 1.14, Color(tape.darkened(0.26), 0.80 * strength), Vector2.ZERO, null)
	_ribbon_pass(cells, width, Color(tape, 0.88 * strength), Vector2.ZERO, paper_grain())
	_ribbon_pass(cells, width * 0.42, Color(tape.lightened(0.30), 0.40 * strength),
		Vector2(0.0, -width * 0.24), null)

func _ribbon_pass(cells: Dictionary, width: float, colour: Color, offset: Vector2, tex: Texture2D) -> void:
	var half := width * 0.5
	for raw_cell in cells:
		var cell := Vector2i(raw_cell)
		var centre := _cell_pos(cell) + Vector2.ONE * (cell_size * 0.5) + offset
		var ends := _ribbon_ends(cell, cells)
		for end_pt in ends:
			var b := Vector2(end_pt) + offset
			var dir := (b - centre)
			if dir.length() <= 0.01:
				continue
			var nrm := Vector2(-dir.y, dir.x).normalized() * half
			_poly([centre + nrm, b + nrm, b - nrm, centre - nrm], colour, tex)
		_disc(centre, half, colour, tex)          # rounds the joint AND caps a lone end

# Screen-space endpoints of the strip inside `cell`: the midpoint of each shared edge.
func _ribbon_ends(cell: Vector2i, cells: Dictionary) -> Array:
	var out: Array = []
	var centre := _cell_pos(cell) + Vector2.ONE * (cell_size * 0.5)
	for raw_d in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
		var d := Vector2i(raw_d)
		if not cells.has(cell + d):
			continue
		out.append(centre + (_cell_pos(cell + d) - _cell_pos(cell)) * 0.5)
	return out

func _poly(pts: Array, colour: Color, tex: Texture2D) -> void:
	var pv := PackedVector2Array(pts)
	if tex == null:
		draw_colored_polygon(pv, colour)
		return
	var uvs := PackedVector2Array()
	for p in pv:
		uvs.append(p / float(PAPER_TEX_PX))    # board-space UVs: the grain runs unbroken
	draw_colored_polygon(pv, colour, uvs, tex)

func _disc(at: Vector2, r: float, colour: Color, tex: Texture2D) -> void:
	var pts: Array = []
	for i in JOINT_SIDES:
		var a := TAU * float(i) / float(JOINT_SIDES)
		pts.append(at + Vector2(cos(a), sin(a)) * r)
	_poly(pts, colour, tex)

func _draw_ghost_pad(entry: Dictionary) -> void:
	var cell := Vector2i(entry.get("cell", Vector2i(-1, -1)))
	if cell.x < 0:
		return
	var n := int(entry.get("n", 2))
	var line := int(entry.get("line", 0))
	# Three strengths, one meaning each: `cascade` is the drop that goes off (and the only mark
	# _rebuild_tags will number), `merge` is an ordinary same-code target, `stage` is an empty
	# cell you are building into.
	var kind := String(entry.get("kind", "stage"))
	var color := G.line_color(line)
	var rect := Rect2(_cell_pos(cell) + Vector2.ONE * (cell_size * 0.12), Vector2.ONE * cell_size * 0.76)
	var tint_alpha := 0.08 if kind == "cascade" else (0.055 if kind == "merge" else 0.035)
	draw_rect(rect, Color(color, tint_alpha), true)
	var alpha := _alpha_for_n(n) + 0.08 if kind == "cascade" else (0.42 if kind == "merge" else 0.28)
	var light := 0.25 if kind == "cascade" else (0.34 if kind == "merge" else 0.12)
	var edge := Color(color.lightened(light), alpha)
	_draw_dashed_rect(rect, edge, _mark_thickness(entry))

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
		if not (entry is Dictionary) or String((entry as Dictionary).get("kind", "stage")) != "cascade":
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
	# Full width is reserved for the two marks that mean "this fires": an armed ladder at rest and
	# a `cascade` drop target. Everything else is deliberately thinner.
	var scale := RUNWAY_WIDTH_SCALE if kind == "runway" else (MERGE_WIDTH_SCALE if kind == "merge" else (STAGE_WIDTH_SCALE if kind == "stage" else 1.0))
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
