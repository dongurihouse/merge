@tool
extends Control
## Stitched cascade readiness and drag-guide marks. The board owns the data and
## geometry; this node only renders it and never handles input.

const G = preload("res://engine/scripts/core/content.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const Pal = Game.PALETTE
const Contour = preload("res://engine/scripts/ui/cell_contour.gd")
const TAG_Z_INDEX := 20
const RUNWAY_WIDTH_SCALE := 0.62
const MERGE_WIDTH_SCALE := 0.82
const STAGE_WIDTH_SCALE := 0.72
const PAPER_TEX_PX := 64
const PAPER_SEED := 20260727         # fixed: `make shot` compares captures byte for byte
const JOINT_SIDES := 12

# --- the contour glow -------------------------------------------------------------------------
# MEASURED off the baked slot-tile face (games/grove/assets/ui/board/cell_paper_open.png, 512²):
# the cream face sits ~3.4 % of the cell inside its cell rect and its corner radius is ~16 % of the
# cell. The glow is built from those two numbers and the pitch (read back off `_cell_pos`), so the
# hot line lands ON the tile edge and the contour's corners match the tiles' corners at any cell size.
const TILE_INSET_FRAC := 0.034
const TILE_RADIUS_FRAC := 0.16
const REFLEX_R := 0.0                # inner corners stay SHARP: rounding them cuts a notch out of
                                     # the shape that reads as damage, and a sharp corner is exactly
                                     # where the mitre offset clips instead of self-intersecting.
const ARC_STEPS := 6
const STEP_FRAC := 0.125             # contour resample step, as a share of the pitch
const INNER_CAP := 0.92              # inner rails stop this short of the corner radius; past it the
                                     # inner rail turns inside out around the arc centre.
const GEOM_CACHE_MAX := 24           # built contours held across mark changes (see _after_marks_changed)

# The travelling light. ONE wave train chases the whole contour — the owner rejected both a livelier
# comet sweep and a per-cell pulse, so this stays a low-contrast swell, never fully dark.
const WAVE_CYCLES := 2.0             # crests around the loop; integer so the wrap at u=1 is seamless
const RIPPLE_MULT := 4.0
const RIPPLE_RATE := 2.2
const PHASE_RATE := 0.625            # phase units per second (the approved loop: 1 phase / 1.6 s)
const FLOW_BASE := 0.40
const FLOW_WAVE := 0.46
const FLOW_RIPPLE := 0.16
const MOTTLE_DEPTH := 0.13           # a static unevenness along the contour, so the band is not a tube

# Which length a rail's offset is measured in.
const ANCHOR_PITCH := 0              # cell pitch — the outer haze is a board-scale wash
const ANCHOR_GAP := 1                # contour → tile edge — the band + hot line ride the tray gutter
const ANCHOR_CORNER := 2             # the hull corner radius — the inward spill is capped by it

## THE EDGE PROFILE, outward-positive. Solved off the reference renderer's own composite over TWO
## backgrounds (tray and tile face), which recovers the (colour, alpha) an alpha-blended strip needs
## to reproduce it — so this table IS the approved profile, not an impression of it. `wave` is how
## much of a rail's alpha the travelling light owns (0 = static haze, 1 = all wave).
## [anchor, multiplier, colour, alpha at full flow, wave share]
const RAILS := [
	[ANCHOR_PITCH,   0.480, Color(0.992, 0.698, 0.290), 0.000, 0.00],
	[ANCHOR_PITCH,   0.340, Color(0.992, 0.698, 0.290), 0.100, 0.00],
	[ANCHOR_PITCH,   0.230, Color(0.992, 0.698, 0.290), 0.205, 0.00],
	[ANCHOR_PITCH,   0.155, Color(0.992, 0.699, 0.291), 0.300, 0.01],
	[ANCHOR_GAP,     1.490, Color(0.994, 0.713, 0.302), 0.462, 0.15],
	[ANCHOR_GAP,     0.667, Color(0.997, 0.737, 0.321), 0.726, 0.35],
	[ANCHOR_GAP,     0.140, Color(1.000, 0.834, 0.362), 0.917, 0.45],
	[ANCHOR_GAP,    -0.386, Color(1.000, 0.883, 0.394), 0.933, 0.42],
	[ANCHOR_GAP,    -0.702, Color(1.000, 0.924, 0.456), 0.908, 0.25],
	[ANCHOR_GAP,    -1.000, Color(1.000, 0.989, 0.536), 0.723, 0.74],   # THE TILE EDGE — the hot line
	[ANCHOR_GAP,    -1.298, Color(1.000, 0.881, 0.434), 0.638, 0.94],
	[ANCHOR_GAP,    -1.754, Color(1.000, 0.769, 0.349), 0.379, 1.00],
	[ANCHOR_CORNER, -0.758, Color(1.000, 0.757, 0.337), 0.160, 1.00],
	[ANCHOR_CORNER, -0.920, Color(1.000, 0.757, 0.337), 0.000, 1.00],
]

## …and the profile as it is DRAWN. The solved table reproduces the reference's own composite, but
## the reference is not this tray: in the game the band's amber (253,178,74) lands on a tray of
## (213,163,35), so more opacity only converges on a colour barely separated from the ground.
## Three knobs shape it, applied ONCE to the solved table above:
##   ALPHA_LIFT   every rail's alpha, clamped — the band goes opaque where the profile peaked. It
##                multiplies the table, never the flow, so the travelling wave still modulates it.
##                NOT an intensity knob any more: at 1.6 SIX consecutive band rails already clamp to
##                a = 1.0 and the band's R composites at 252/255 over the tray, so more opacity buys
##                three levels of red and nothing else (measured: 1.6 → 2.4 moves the peak
##                band-minus-tray delta by 0.0, it only clamps a seventh rail).
##   CREAM_PULL   the gap rails OUTSIDE the tile edge — the ones riding the tray gutter — pulled
##                toward cream, so the mark separates from the tray by hue and value and not by
##                opacity alone. The hot line AT the tile edge (offset -1.000) is already near-cream
##                and it is the tile's own cut edge, so its colour is left exactly as solved; the two
##                rails inside it sit on the lit tile face, not on the tray, and are left too. The
##                interior gutters take the same pull (see CRACK_COLOR) — they ride tray as well, and
##                ONE constant driving both is what keeps their warmth in agreement.
##   BAND_WIDTH   how far those same rails REACH outward. The band is the only bright part of the
##                mark and at 1.00 it is 8.1 px on a 130 px cell — 6 % of a cell — which is the real
##                reason it reads faint in play. Widening it adds warm light without whitening
##                anything, so it is the knob that carries most of a step up.
const ALPHA_LIFT := 1.6
const CREAM_PULL := 0.46
const BAND_WIDTH := 1.45

## The three intensities the owner chose between, as [cream pull, band width]. Switching the shipped
## look is the two constants above; `glow=<name>` (engine/tools/shot_base.gd) pins one for a capture,
## so ONE batched launch can shoot all three side by side. Peak band-minus-tray channel delta over
## the game's own tray (213,163,35), and the band's outward reach:
##   dim +117.9 / 8.1 px  ·  stronger +129.5 / 11.7 px  ·  strongest +139.9 / 15.3 px
const LEVELS := {
	"dim": [0.35, 1.00],             # what shipped before 2026-07-29 — the owner called it too dim twice
	"stronger": [0.46, 1.45],
	"strongest": [0.56, 1.90],       # the ceiling: past ~2.0 the band's outermost rail crosses the
	                                 # innermost pitch-anchored haze rail and the strip self-crosses
}

## Pins the intensity for a capture, the way `forced_phase` pins the wave. Empty = the shipped pair.
static var forced_level := ""

static func cream_pull() -> float:
	return float(Array(LEVELS[forced_level])[0]) if LEVELS.has(forced_level) else CREAM_PULL

static func band_width() -> float:
	return float(Array(LEVELS[forced_level])[1]) if LEVELS.has(forced_level) else BAND_WIDTH

static var _lit_rails: Array = []
static var _lit_pull := -1.0

static func lit_rails() -> Array:
	var pull := cream_pull()
	if not _lit_rails.is_empty() and is_equal_approx(pull, _lit_pull):
		return _lit_rails
	var out: Array = []
	for raw in RAILS:
		var rail: Array = raw
		var colour: Color = rail[2]
		if int(rail[0]) == ANCHOR_GAP and float(rail[1]) > -1.0:
			colour = colour.lerp(Pal.CREAM, pull)
		out.append([rail[0], rail[1], colour, minf(float(rail[3]) * ALPHA_LIFT, 1.0), rail[4]])
	_lit_rails = out
	_lit_pull = pull
	return _lit_rails

# The chain's own tiles, lit from underneath: a warm wash that is brightest at the tile edge and
# fades to the middle. Per CELL on purpose — the tiles ARE per-cell rounded squares, so this is the
# board's own geometry, not a second outline (the contour above is the only outline).
const FACE_COLOR := Color(1.000, 0.855, 0.541)
const FACE_EDGE_A := 0.78
const FACE_MID_A := 0.50
const FACE_CORE_A := 0.19
# The tray gutters BETWEEN two chain cells, which read as light coming up from under the blob. Held
# steady on purpose: arc length along the contour is discontinuous across the shape's medial axis,
# so driving the interior with it stamps a hard seam down the middle. Solved on the same tray as the
# band and drawn with the same CREAM_PULL — an unpulled interior reads as amber bars crossing a cream
# ring (measured on the top gutter: 149.0 against the band's 104.3).
const CRACK_COLOR := Color(1.000, 0.757, 0.337)
const CRACK_A := 0.88
## The hue every rail colour above is written against; `_tint` carries the profile's colour across
## to the live line as a shift from it, so a green line glows green without losing the hot core.
const GOLD := Color(1.000, 0.757, 0.337)
const GOLD_PULL := 0.86              # how far a line colour is pulled toward it (see _draw_chain_glow)

## Pins the travelling wave for a capture. `make shot` compares PNGs byte for byte and a running
## animation lands on a different phase in a warm batch process than in a fresh one, so
## engine/tools/shot_base.gd sets this before any board is built. Negative = run live.
static var forced_phase := -1.0

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

var _t := 0.0
var _geom := {}          # cells key -> the built contour loops; the walk never runs per frame

func _set_inset(v: float) -> void: inset_frac = v; queue_redraw()
func _set_thickness(v: float) -> void: thickness_frac = v; queue_redraw()
func _set_fill_pct(v: float) -> void: fill_pct = v; queue_redraw()
func _set_jitter(v: float) -> void: jitter_frac = v; queue_redraw()

func _ready() -> void:
	name = "CascadeOutline"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED   # the grain tiles in board space
	_sync_process()
	queue_redraw()

func configure(board_size: Vector2, csz: float, cell_pos: Callable) -> void:
	size = board_size
	cell_size = csz
	cell_pos_fn = cell_pos
	_geom.clear()
	_rebuild_tags()
	_sync_process()
	queue_redraw()

func set_ladders(data: Array) -> void:
	ladders = data.duplicate(true)
	_after_marks_changed()

func set_runways(data: Array) -> void:
	runways = data.duplicate(true)
	_after_marks_changed()

func set_drag_ladders(data: Array) -> void:
	drag_ladders = data.duplicate(true)
	_after_marks_changed()

func set_ghost_pads(data: Array) -> void:
	ghost_pads = data.duplicate(true)
	_after_marks_changed()

func clear_guides() -> void:
	if ghost_pads.is_empty() and drag_ladders.is_empty():
		return
	ghost_pads = []
	drag_ladders = []
	_after_marks_changed()

func _after_marks_changed() -> void:
	# The cache is keyed by the cells and the cell size, so it SURVIVES a mark change on purpose: a
	# drag re-pushes its ladder every move, and rebuilding the contour inside the gesture is exactly
	# the work that makes a drag feel heavy (measured: ~0.5 ms a rebuild). Only `configure` — a new
	# cell size or a new orientation — invalidates it; the cap keeps a long drag from growing it.
	if _geom.size() > GEOM_CACHE_MAX:
		_geom.clear()
	_rebuild_tags()
	_sync_process()
	queue_redraw()

# The wave only runs while there is a chain to run it around, and never while a capture has pinned
# the phase — gen_sparkle.gd's idiom, with the extra "nothing to draw ⇒ no process" guard.
func _sync_process() -> void:
	set_process(forced_phase < 0.0 and (not _active_ladders().is_empty() \
		or (drag_ladders.is_empty() and not runways.is_empty())))

func _process(delta: float) -> void:
	_t += delta * PHASE_RATE
	queue_redraw()

func _phase() -> float:
	return forced_phase if forced_phase >= 0.0 else _t

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
	_draw_chain_glow(_chain_cells(entry), G.line_color(int(entry.get("line", 0))), 1.0, 1.0)

func _draw_runway(entry: Dictionary) -> void:
	# A runway is the same light, quieter and with a tighter halo: it is not going to fire until
	# its piece arrives, so it must never read as loud as an armed ladder.
	_draw_chain_glow(_chain_cells(entry), G.line_color(int(entry.get("line", 0))), 0.5, 0.78)

# The glow follows `run` — the cells the cascade walks — not `cells`, which is a same-LINE flood
# fill with no tier condition. A t4 touching a t6 lands in one component while neither can ever feed
# the other's chain; outlining that draws a connection that does not exist.
func _chain_cells(entry: Dictionary) -> Array:
	var run := Array(entry.get("run", []))
	return run if not run.is_empty() else Array(entry.get("cells", []))

# --- the contour glow --------------------------------------------------------------------------
# The chain's cells are unioned into ONE shape and its outline extracted as closed contours. The
# contour carries a layered light profile (RAILS) and a subtle wave travels around it; the tray gaps
# INSIDE the shape glow steadily, as if lit from underneath. There is exactly ONE outline definition
# — the interior marks are the board's own per-cell tiles and gutters, never a second contour that
# would have to be kept in agreement with this one.
func _draw_chain_glow(raw_cells: Array, base: Color, strength: float, reach: float) -> void:
	if raw_cells.is_empty() or strength <= 0.0:
		return
	var geom := _chain_geometry(raw_cells)
	if Array(geom["loops"]).is_empty():
		return
	# Pull the line colour hard toward warm gold. The light pools over a whole chain and shows THROUGH
	# a piece's transparent margins, so a saturated hue tints the art itself — MEASURED at a 0.68 pull
	# the pink of line 1 washed its mushrooms salmon, the same bruise `_draw_target_bloom` warns about.
	# The line still leans the hue; gold is what a line looks like as light on this tray.
	var glow := base.lerp(GOLD, GOLD_PULL)
	var m: Dictionary = geom["metrics"]
	var offs := _rail_offsets(m, reach)
	var phase := _phase()
	for raw_loop in geom["loops"]:
		_draw_contour_strip(raw_loop as Dictionary, offs, glow, strength, phase)
	for raw_face in geom["faces"]:
		_draw_tile_lift(raw_face as Dictionary, glow, strength)
	var crack := _tint(glow, CRACK_COLOR.lerp(Pal.CREAM, cream_pull()), CRACK_A * strength)
	for raw_quad in geom["gutters"]:
		_poly(raw_quad as Array, crack, null)

## Where each rail sits, in px, outward positive. A runway passes `reach` < 1 and gets a tighter
## halo; the gap- and corner-anchored rails do not scale with it, so the hot line stays ON the tile
## edge and the inward spill stays inside the corner radius whatever the mark's strength. BAND_WIDTH
## is the separate, mark-independent knob: it widens the tray-riding rails only — everything from the
## tile edge inward keeps its solved offset, so a wider band never moves the hot line.
func _rail_offsets(m: Dictionary, reach: float) -> PackedFloat32Array:
	var offs := PackedFloat32Array()
	var width := _band_width_for(m, reach)
	for raw in lit_rails():
		var rail: Array = raw
		var anchor := int(rail[0])
		var unit: float = float(m["pitch"]) * reach if anchor == ANCHOR_PITCH \
			else (float(m["gap"]) if anchor == ANCHOR_GAP else float(m["corner"]))
		var mult := float(rail[1])
		# OUTWARD only. The rails between the contour and the tile edge (offset -1..0) sit in a gutter
		# whose width is the board's, not this knob's — scaling them just walks them toward the tile
		# edge and, past width ~1.4, THROUGH it: -0.702 x 1.45 = -1.018 lands inside the hot line and
		# the strip folds. So the band grows out over the neighbouring tile, which is what light
		# pooling from under the chain does anyway.
		if anchor == ANCHOR_GAP and mult > 0.0:
			mult *= width
		offs.append(mult * unit)
	return offs

## BAND_WIDTH, capped by the geometry it is drawn into. The rails are the ROWS of one triangle strip,
## so they have to stay strictly outward-to-inward: let the widened band's outermost rail climb past
## the innermost pitch-anchored haze rail and the strip folds through itself. Two things make that
## reachable — a board whose gutter is a big share of its pitch (the workbench's 40 px cells), and a
## runway, whose `reach` shrinks the haze while the gap-anchored band deliberately does not scale.
## Scaling the whole band down together keeps the profile's shape and the ordering. The cap never
## bites at BAND_WIDTH = 1.0: it can only take back width this knob added, never narrow the solved
## profile, so a board that drew correctly before draws identically now.
func _band_width_for(m: Dictionary, reach: float) -> float:
	var base := _band_span() * float(m["gap"])
	if base <= 0.0:
		return band_width()
	var lid := _haze_floor() * float(m["pitch"]) * reach * BAND_LID
	var cap := maxf(base, lid)
	var want := base * band_width()
	return band_width() if want <= cap else cap / base

const BAND_LID := 0.92               # clearance kept under the innermost haze rail

## The two multipliers the cap is measured between, read off RAILS so re-solving the profile carries
## them along: how far the tray-riding band reaches, and how close the haze comes to it.
static func _band_span() -> float:
	var out := 0.0
	for raw in RAILS:
		if int(raw[0]) == ANCHOR_GAP and float(raw[1]) > 0.0:
			out = maxf(out, float(raw[1]))
	return out

static func _haze_floor() -> float:
	var out := INF
	for raw in RAILS:
		if int(raw[0]) == ANCHOR_PITCH:
			out = minf(out, float(raw[1]))
	return 0.0 if out == INF else out

## A rail's colour on THIS line: the profile's own colour carried across as a shift from the
## reference gold, so the hot core stays paler than the band and the haze deeper, while the line
## colour still decides the hue.
func _tint(glow: Color, rail: Color, alpha: float) -> Color:
	return Color(clampf(glow.r + rail.r - GOLD.r, 0.0, 1.0),
		clampf(glow.g + rail.g - GOLD.g, 0.0, 1.0),
		clampf(glow.b + rail.b - GOLD.b, 0.0, 1.0),
		clampf(alpha, 0.0, 1.0))

# The strip: one triangle mesh per contour, submitted in a single call. The rails' colours ride the
# vertices, so the profile across and the wave along are both Gouraud-interpolated by the rasteriser
# and the per-frame cost is one colour array. Points and mitre offsets are built once per chain.
func _draw_contour_strip(loop: Dictionary, offs: PackedFloat32Array, glow: Color, strength: float, phase: float) -> void:
	var pts: PackedVector2Array = loop["pts"]
	var norm: PackedVector2Array = loop["off"]
	var mottle: PackedFloat32Array = loop["mottle"]
	var table := lit_rails()
	var n := pts.size()
	var rails := table.size()
	if n < 3:
		return
	var points := PackedVector2Array()
	var colours := PackedColorArray()
	points.resize(n * rails)
	colours.resize(n * rails)
	for i in n:
		var u := float(i) / float(n)
		var flow := FLOW_BASE \
			+ FLOW_WAVE * (0.5 + 0.5 * sin(TAU * (u * WAVE_CYCLES - phase))) \
			+ FLOW_RIPPLE * (0.5 + 0.5 * sin(TAU * (u * WAVE_CYCLES * RIPPLE_MULT - phase * RIPPLE_RATE)))
		flow *= 1.0 + MOTTLE_DEPTH * mottle[i]
		for k in rails:
			var rail: Array = table[k]
			var wave := float(rail[4])
			points[i * rails + k] = pts[i] + norm[i] * offs[k]
			colours[i * rails + k] = _tint(glow, rail[2],
				float(rail[3]) * strength * (1.0 - wave + wave * flow))
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), loop["idx"], points, colours)

# A chain TILE, lit from under the board: brightest at the tile edge, fading to the middle. Built as
# a fan onto the tile's own centre, so the innermost ring cannot turn inside out however small the
# cell gets — and the iso-lines follow the tile's own rounded-square shape, which is what a light
# under that tile would do.
func _draw_tile_lift(face: Dictionary, glow: Color, strength: float) -> void:
	var pts: PackedVector2Array = face["pts"]
	var norm: PackedVector2Array = face["off"]
	var centre: Vector2 = face["centre"]
	var inner: float = face["inner"]
	var edge := _tint(glow, FACE_COLOR, FACE_EDGE_A * strength)
	var mid := _tint(glow, FACE_COLOR, FACE_MID_A * strength)
	var core := _tint(glow, FACE_COLOR, FACE_CORE_A * strength)
	var n := pts.size()
	var points := PackedVector2Array()
	var colours := PackedColorArray()
	points.resize(n * 3)
	colours.resize(n * 3)
	for i in n:
		points[i * 3] = pts[i]
		points[i * 3 + 1] = pts[i] + norm[i] * inner
		points[i * 3 + 2] = centre
		colours[i * 3] = edge
		colours[i * 3 + 1] = mid
		colours[i * 3 + 2] = core
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), face["idx"], points, colours)

# Triangle indices for a CLOSED `rows`×`cols` vertex grid (the last row wraps onto the first). It
# depends only on the two counts, so it is built with the geometry and reused every frame — rebuilding
# it inside `_draw` costs ~11k array appends a frame on a long chain, for a value that never changes.
static func _grid_indices(rows: int, cols: int) -> PackedInt32Array:
	var idx := PackedInt32Array()
	for i in rows:
		var i0 := i * cols
		var i1 := ((i + 1) % rows) * cols
		for k in cols - 1:
			idx.append(i0 + k)
			idx.append(i0 + k + 1)
			idx.append(i1 + k + 1)
			idx.append(i0 + k)
			idx.append(i1 + k + 1)
			idx.append(i1 + k)
	return idx

## Everything the glow needs that does NOT change frame to frame: the chain's rounded contours, its
## per-tile faces and its interior gutter quads, all in SCREEN space. Built once per chain and
## cached, so the lattice walk and the resampling never run inside a frame.
##   loops   [{pts, off (per-vertex mitre offsets), mottle, idx}]  — the ONE outline definition
##   faces   [{pts, off, centre, inner, idx}]                       — the board's own tiles
##   gutters [[Vector2 × 4]]                                        — the tray between two cells
func _chain_geometry(raw_cells: Array) -> Dictionary:
	var key := "%s|%.3f" % [str(raw_cells), cell_size]
	if _geom.has(key):
		return _geom[key]
	var m := _metrics()
	var cells := Contour.cell_set(raw_cells)
	var r_conv := float(m["corner"])
	var step := maxf(2.0, float(m["pitch"]) * STEP_FRAC)
	var shift := Vector2.ONE * ((float(m["pitch"]) - cell_size) * 0.5)
	var loops: Array = []
	for raw_loop in Contour.boundary_loops(raw_cells):
		var sharp := PackedVector2Array()
		var radii := PackedFloat32Array()
		for raw_v in raw_loop as Array:
			var v := Vector2i(raw_v)
			# lattice corner → screen: the cell rect's corner pulled back to the middle of the gap.
			sharp.append(_cell_pos(v) - shift)
			radii.append(REFLEX_R if Contour.is_reflex(cells, v) else r_conv)
		var pts := Contour.resample_closed(Contour.round_loop(sharp, radii, ARC_STEPS), step)
		if pts.size() < 3:
			continue
		var mottle := PackedFloat32Array()
		for i in pts.size():
			var u := float(i) / float(pts.size())
			# static, phase-free and seamless at the wrap: the band is uneven but never crawls.
			mottle.append(sin(TAU * u * 7.0) * sin(TAU * u * 3.0 + 1.1))
		loops.append({
			"pts": pts,
			"off": Contour.mitre_offsets(pts, _lattice_side()),
			"mottle": mottle,
			"idx": _grid_indices(pts.size(), lit_rails().size()),
		})
	var inset := cell_size * TILE_INSET_FRAC
	var faces: Array = []
	var gutters: Array = []
	for raw in cells:
		var a := Vector2i(raw)
		var rect := Rect2(_cell_pos(a) + Vector2.ONE * inset, Vector2.ONE * (cell_size - inset * 2.0))
		var face := PackedVector2Array(_round_rect(rect, cell_size * TILE_RADIUS_FRAC))
		faces.append({
			"pts": face,
			"off": Contour.mitre_offsets(face),
			"centre": _cell_pos(a) + Vector2.ONE * (cell_size * 0.5),
			"inner": -INNER_CAP * cell_size * TILE_RADIUS_FRAC,
			"idx": _grid_indices(face.size(), 3),
		})
		for raw_d in [Vector2i(1, 0), Vector2i(0, 1)]:
			var d := Vector2i(raw_d)
			if not cells.has(a + d):
				continue
			# Both axes come from _cell_pos, which owns the landscape transpose — a model delta with
			# hardcoded portrait axes here is what once drew rungs instead of a border.
			var along := (_cell_pos(a + d) - _cell_pos(a)).normalized()
			var across := Vector2(-along.y, along.x)
			var edge := _cell_pos(a) + Vector2.ONE * (cell_size * 0.5) \
				+ along * (cell_size * 0.5 + (float(m["pitch"]) - cell_size) * 0.5)
			# face-to-face across the gutter, a full pitch along it, so both ends meet the contour
			# band with no seam.
			var w := along * float(m["gap"])
			var h := across * (float(m["pitch"]) * 0.5)
			gutters.append([edge - w - h, edge + w - h, edge + w + h, edge - w + h])
	var out := {"loops": loops, "faces": faces, "gutters": gutters, "metrics": m}
	_geom[key] = out
	return out

## The three lengths the whole effect is built from, all derived — never re-typed.
##   pitch   read back off `_cell_pos`, so the landscape transpose and a workbench gap change come
##           along for free
##   gap     contour → tile edge: the contour runs down the middle of the tray gutter and the tile
##           face sits a little inside its cell rect, so the hot line lands on the tile's cut edge
##   corner  the hull's convex corner radius: the tile's own corner opened out to that contour, so
##           the glow turns the same corner the tiles do
func _metrics() -> Dictionary:
	var pitch := cell_size
	if cell_pos_fn.is_valid():
		pitch = maxf(cell_size, (_cell_pos(Vector2i(1, 0)) - _cell_pos(Vector2i(0, 0))).length())
	var gap := (pitch - cell_size) * 0.5 + cell_size * TILE_INSET_FRAC
	return {"pitch": pitch, "gap": gap, "corner": cell_size * TILE_RADIUS_FRAC + gap}

# Which hand the cell lattice comes out on once _cell_pos has mapped it to the screen. The landscape
# transpose is a REFLECTION, so this flips — and it is what points a contour's light away from the
# chain, out of a silhouette and into a hole alike.
func _lattice_side() -> float:
	if not cell_pos_fn.is_valid():
		return 1.0
	var ei := _cell_pos(Vector2i(1, 0)) - _cell_pos(Vector2i(0, 0))
	var ej := _cell_pos(Vector2i(0, 1)) - _cell_pos(Vector2i(0, 0))
	return 1.0 if ei.cross(ej) > 0.0 else -1.0

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
	# ONE tag per cell, loudest wins. Drag tags name the exact occupied drop target; resting armed
	# tags name the chain end. Empty staging pads and inert runways stay unnumbered.
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
			var cell := Vector2i((entry as Dictionary).get("tag_cell", (entry as Dictionary).get("top_cell", Vector2i(-1, -1))))
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
