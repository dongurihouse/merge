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
@export var thickness_frac := 0.035: set = _set_thickness
@export var fill_pct := 5.0: set = _set_fill_pct
@export var jitter_frac := 0.012: set = _set_jitter

var ladders: Array = []
var runways: Array = []
var drag_ladders: Array = []
var ghost_pads: Array = []
var cell_size := 86.0
var cell_pos_fn: Callable

func _set_inset(v: float) -> void: inset_frac = v; queue_redraw()
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

func set_drag_ladders(data: Array) -> void:
	drag_ladders = data.duplicate(true)
	_rebuild_tags()
	queue_redraw()

func set_ghost_pads(data: Array) -> void:
	ghost_pads = data.duplicate(true)
	_rebuild_tags()
	queue_redraw()

func clear_guides() -> void:
	if ghost_pads.is_empty() and drag_ladders.is_empty():
		return
	ghost_pads = []
	drag_ladders = []
	_rebuild_tags()
	queue_redraw()

func _draw() -> void:
	if cell_size <= 0.0 or not cell_pos_fn.is_valid():
		return
	if drag_ladders.is_empty():
		for entry in runways:
			if entry is Dictionary:
				_draw_runway(entry as Dictionary)
	for entry in _active_ladders():
		if entry is Dictionary:
			_draw_ladder(entry as Dictionary)
	for entry in ghost_pads:
		if entry is Dictionary:
			_draw_ghost_pad(entry as Dictionary)

func _active_ladders() -> Array:
	return drag_ladders if not drag_ladders.is_empty() else ladders

func _draw_ladder(entry: Dictionary) -> void:
	_draw_ribbon(_ribbon_cells(entry), G.line_color(int(entry.get("line", 0))),
		cell_size * RIBBON_WIDTH_FRAC, 1.0, not Array(entry.get("run", [])).is_empty())

func _draw_runway(entry: Dictionary) -> void:
	# A runway is the same ribbon, quieter: it is not going to fire until its piece arrives.
	_draw_ribbon(_ribbon_cells(entry), G.line_color(int(entry.get("line", 0))),
		cell_size * RIBBON_WIDTH_FRAC * 0.78, 0.5, not Array(entry.get("run", [])).is_empty())

# The ribbon follows `run` — the cells the cascade walks — not `cells`, which is a same-LINE
# flood fill with no tier condition. A t4 touching a t6 lands in one component while neither can
# ever feed the other's chain; a ribbon over that draws a connection that does not exist.
func _ribbon_cells(entry: Dictionary) -> Array:
	var run := Array(entry.get("run", []))
	return run if not run.is_empty() else Array(entry.get("cells", []))

# The chain drawn as one continuous strip of cut paper. Real run paths link only consecutive
# cells, so a snaking ladder cannot sprout false rungs when non-consecutive cells touch. Fallback
# component marks still link shared edges for T/ring shapes. Endpoints come from _cell_pos, never
# from model deltas: _cell_pos owns the landscape transpose, and hardcoding portrait here is what
# once drew rungs instead of a border on a wide screen.
func _draw_ribbon(raw_cells: Array, base: Color, width: float, strength: float, ordered_path := true) -> void:
	if raw_cells.is_empty() or width <= 0.5:
		return
	var links := _ribbon_links(raw_cells, ordered_path)
	if links.is_empty():
		return
	# Pull the line colour toward cream first. Full-saturation line colour reads as a new game
	# object competing with the pieces; the group mark has to stay quieter than the drop target
	# it sits under, so this is tape laid on the board, not a painted stripe.
	var tape := base.lerp(Color(0.98, 0.95, 0.88), 0.42)
	var lift := maxf(1.5, cell_size * 0.035)
	# Cut-paper stack, bottom to top: contact shadow, the warm cut edge the fill sits inside,
	# the grained face, then a light top plane along the upper side.
	_ribbon_pass(links, width * 1.02, Color(Pal.INK, 0.20 * strength), Vector2(0.0, lift), null)
	_ribbon_pass(links, width * 1.14, Color(tape.darkened(0.26), 0.80 * strength), Vector2.ZERO, null)
	_ribbon_pass(links, width, Color(tape, 0.88 * strength), Vector2.ZERO, paper_grain())
	_ribbon_pass(links, width * 0.42, Color(tape.lightened(0.30), 0.40 * strength),
		Vector2(0.0, -width * 0.24), null)

func _ribbon_pass(links: Dictionary, width: float, colour: Color, offset: Vector2, tex: Texture2D) -> void:
	var half := width * 0.5
	for raw_cell in links:
		var cell := Vector2i(raw_cell)
		var centre := _cell_pos(cell) + Vector2.ONE * (cell_size * 0.5) + offset
		var ends := _ribbon_ends(cell, links)
		for end_pt in ends:
			var b := Vector2(end_pt) + offset
			var dir := (b - centre)
			if dir.length() <= 0.01:
				continue
			var nrm := Vector2(-dir.y, dir.x).normalized() * half
			_poly([centre + nrm, b + nrm, b - nrm, centre - nrm], colour, tex)
		_disc(centre, half, colour, tex)          # rounds the joint AND caps a lone end

func _ribbon_links(raw_cells: Array, ordered_path := true) -> Dictionary:
	var links := {}
	var ordered: Array = []
	for raw in raw_cells:
		var c := Vector2i(raw)
		if links.has(c):
			continue
		links[c] = []
		ordered.append(c)
	if not ordered_path:
		for raw_cell in ordered:
			var cell := Vector2i(raw_cell)
			for raw_d in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
				var nb := cell + Vector2i(raw_d)
				if links.has(nb):
					_link_ribbon_cells(links, cell, nb)
		return links
	for i in maxi(0, ordered.size() - 1):
		var a := Vector2i(ordered[i])
		var b := Vector2i(ordered[i + 1])
		if absi(a.x - b.x) + absi(a.y - b.y) == 1:
			_link_ribbon_cells(links, a, b)
	return links

func _link_ribbon_cells(links: Dictionary, a: Vector2i, b: Vector2i) -> void:
	var a_links := Array(links.get(a, []))
	if not a_links.has(b):
		a_links.append(b)
		links[a] = a_links
	var b_links := Array(links.get(b, []))
	if not b_links.has(a):
		b_links.append(a)
		links[b] = b_links

# Screen-space endpoints of the strip inside `cell`: the midpoint of each linked edge.
func _ribbon_ends(cell: Vector2i, links: Dictionary) -> Array:
	var out: Array = []
	var centre := _cell_pos(cell) + Vector2.ONE * (cell_size * 0.5)
	for raw_nb in Array(links.get(cell, [])):
		var nb := Vector2i(raw_nb)
		out.append(centre + (_cell_pos(nb) - _cell_pos(cell)) * 0.5)
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
	var colour := G.line_color(int(entry.get("line", 0)))
	# Three strengths, one meaning each, and they are different MATERIALS rather than three weights
	# of the same dash: `stage` is an empty cell, cut away so a piece can drop in; `merge` and
	# `cascade` are occupied targets, lit from behind. Only `cascade` is numbered (_rebuild_tags).
	match String(entry.get("kind", "stage")):
		"stage":
			_draw_stage_well(cell, colour)
		"cascade":
			_draw_target_bloom(cell, colour, 1.0)
		_:
			_draw_target_bloom(cell, colour, 0.55)

# An empty cell you are building into: the cardstock is cut away, leaving a shallow well with the
# warm inner edge the cut exposes. Reads as "something goes here" without a stroke.
func _draw_stage_well(cell: Vector2i, colour: Color) -> void:
	var origin := _cell_pos(cell)
	var inset := cell_size * 0.13
	var side := cell_size - inset * 2.0
	var r := cell_size * 0.20
	var well := Rect2(origin + Vector2.ONE * inset, Vector2.ONE * side)
	# the cut edge, then the floor sitting a touch lower-right so the well reads as recessed
	_poly(_round_rect(well, r), Color(colour.darkened(0.34), 0.34), null)
	var floor_rect := Rect2(well.position + Vector2.ONE * (cell_size * 0.022), well.size - Vector2.ONE * (cell_size * 0.030))
	_poly(_round_rect(floor_rect, r * 0.9), Color(colour.lightened(0.62), 0.30), paper_grain())

# An occupied cell you can drop onto. The outline sits under the pieces, so warm light pooled here
# reads as the piece being lit from behind. Concentric layers, not a blur: cheap, and it keeps the
# matte look. Never a modulate brighten — that clamps to nothing on art this bright.
func _draw_target_bloom(cell: Vector2i, colour: Color, strength: float) -> void:
	var centre := _cell_pos(cell) + Vector2.ONE * (cell_size * 0.5)
	# Warm, not the raw line colour. The pool shows THROUGH the piece's own transparent margins,
	# so a saturated hue tints the art itself — pink light under a blue mushroom read as a bruise.
	# Pulling it to warm gold keeps it reading as light rather than as a second colour.
	var glow := colour.lerp(Color(1.0, 0.92, 0.66), 0.62)
	var rings := 5
	for i in rings:
		var t := float(i) / float(rings - 1)             # 0 = widest, 1 = tightest
		_disc(centre, cell_size * lerpf(0.44, 0.21, t),
			Color(glow, lerpf(0.06, 0.34, t) * strength), null)

func _round_rect(rect: Rect2, radius: float) -> Array:
	var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var pts: Array = []
	var corners := [
		[rect.position + Vector2(r, r), PI, 1.5 * PI],
		[Vector2(rect.end.x - r, rect.position.y + r), 1.5 * PI, TAU],
		[rect.end - Vector2(r, r), 0.0, 0.5 * PI],
		[Vector2(rect.position.x + r, rect.end.y - r), 0.5 * PI, PI],
	]
	for raw in corners:
		var c: Vector2 = raw[0]
		var a0: float = raw[1]
		var a1: float = raw[2]
		for i in 5:
			var ang := lerpf(a0, a1, float(i) / 4.0)
			pts.append(c + Vector2(cos(ang), sin(ang)) * r)
	return pts

func _rebuild_tags() -> void:
	for child in get_children():
		child.queue_free()
	if not cell_pos_fn.is_valid():
		return
	# ONE tag per cell, loudest wins. These three sources overlap in the ordinary case — a runway
	# anchors its needed-tier chip on the very cell that becomes the drop target once you pick that
	# tier up — and two Labels at one position just overprint into gibberish ("t×3").
	# Order is the order of authority: what you can do NOW, then what is armed, then what is merely
	# wanted. The runway's "needs a t2" is redundant anyway while you are holding the t2.
	var taken := {}
	if drag_ladders.is_empty():
		for entry in ghost_pads:
			if not (entry is Dictionary) or String((entry as Dictionary).get("kind", "stage")) != "cascade":
				continue
			var cell := Vector2i((entry as Dictionary).get("cell", Vector2i(-1, -1)))
			if cell.x < 0 or taken.has(cell):
				continue
			taken[cell] = true
			var pn := int((entry as Dictionary).get("n", 2))
			_add_tag(cell, "×%d" % pn, pn, false)
	else:
		for entry in drag_ladders:
			if not (entry is Dictionary):
				continue
			var cell := Vector2i((entry as Dictionary).get("top_cell", Vector2i(-1, -1)))
			if cell.x < 0 or taken.has(cell):
				continue
			taken[cell] = true
			var pn := int((entry as Dictionary).get("n", 2))
			_add_tag(cell, "×%d" % pn, pn, false)
	if drag_ladders.is_empty():
		for entry in ladders:
			if not (entry is Dictionary):
				continue
			var top_cell := Vector2i((entry as Dictionary).get("top_cell", Vector2i(-1, -1)))
			if top_cell.x < 0 or taken.has(top_cell):
				continue
			taken[top_cell] = true
			var n := int((entry as Dictionary).get("n", 2))
			_add_tag(top_cell, "×%d" % n, n, false)
		for entry in runways:
			if not (entry is Dictionary):
				continue
			var need := int((entry as Dictionary).get("needs_code", 0))
			if need <= 0:
				continue
			# Anchor on the ribbon's own first cell, not the component's: cells[0] is row-major over the
			# whole same-line blob, which can be a stray the ribbon deliberately does not cover — the tag
			# then floats on a cell with no mark under it.
			var anchor: Array = Array((entry as Dictionary).get("run", []))
			if anchor.is_empty():
				anchor = Array((entry as Dictionary).get("cells", []))
			if anchor.is_empty():
				continue
			var at := Vector2i(anchor[0])
			if taken.has(at):
				continue
			taken[at] = true
			_add_tag(at, "t%d" % (need % 100), int((entry as Dictionary).get("would_be_n", 3)), true)

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
