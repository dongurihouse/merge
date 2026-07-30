extends Control
## A cut-paper PANEL drawn entirely in code — no fixed-size backdrop PNG. A rounded rectangle with a
## torn / deckled edge, filled with a small TILING paper-fibre texture, a warm cut-edge rim, and a soft
## downward drop shadow. It sizes to ANY dimensions with no stretch: the deckle is regenerated for the
## current size and the paper fibre tiles at its native scale, so the edge and grain stay crisp whether
## the panel is a tiny cell or a full dialog sheet.
##
## Usage: add as a background Control (full-rect) behind a dialog's content, set `paper_tex`, and it
## repaints on resize. `content_inset()` reports how far in from the deckled edge content should sit.

const Game = preload("res://engine/scripts/core/game.gd")
const Pal = Game.PALETTE
const Look = preload("res://engine/scripts/ui/skin.gd")

# The torn edge: perimeter points displaced outward by fractal noise. amp = bump height (px), the noise
# frequency sets how often the deckle wobbles along the edge. Small values read as hand-torn cardstock.
@export_enum("rect", "poly", "blob", "tab") var shape: String = "rect"
@export var sides: int = 5          # for shape == "poly" (pentagon, hexagon, …)
@export var corner: float = 30.0    # rect corner radius
@export var deckle_amp: float = 5.0
@export var deckle_freq: float = 0.05
@export var seed: int = 1
@export var paper_color: Color = Pal.CREAM
@export var rim_color: Color = Color("#E7D6BC")   # warm cut edge
@export var rim_width: float = 2.0
@export var draw_shadow: bool = true
# soft drop shadow: a DENSE stack of dark deckled copies dropped down 1px at a time, each at low alpha.
# Densely spaced (1px steps) so the copies OVERLAP and accumulate into one smooth gradient — nearer rows
# sit under more copies and read darker, the far fringe fades out. A sparse few-copy stack (3/7/11px)
# instead shows as discrete stepped bands on small elements (a button), so keep the step ≈ 1px — the step
# count is derived from `shadow_reach` so it stays ~1px at any reach. Both are TUNABLE via the shared
# cut-paper edge knobs (shadow_reach · shadow_strength), so each component dials its own shadow.
@export var shadow_reach: float = 10.0   # how far the softest fringe reaches below the sheet (px)
@export var shadow_alpha: float = 0.05   # per-copy alpha; dense overlap accumulates into the gradient
# blur LOW-PASSES the shadow silhouette so it no longer mirrors the torn edge tooth-for-tooth (which dropped
# straight down reads as a row of hard stripes). It rounds the sharp teeth into gentle low-frequency curves
# for the shadow only — 0 = the exact edge, 100(%) = broad soft curves — while the paper keeps its full tear.
@export var shadow_blur: float = 55.0    # 0..100 %: how much the shadow tear profile is smoothed into curves
# AMBIENT EDGE HALO — the shadow a raised sheet casts on EVERY side, not only below it. `shadow_reach`
# drops its copies straight DOWN, so a sheet bled off the bottom of the screen (a nav tab) shows none of
# it and meets the art behind on a hard cut; this one dilates the silhouette OUTWARD along its own edge
# normals, so the darkening lands on the sides and the TOP too. `halo_strength` is the TOTAL alpha the
# halo reaches at the sheet's edge (the per-copy alpha is derived from it, so the contact darkness is the
# same however many copies the reach asks for). 0 reach = off, which is the default everywhere.
@export var halo_reach: float = 0.0     # how far the halo reaches out from EVERY edge (px)
@export var halo_alpha: float = 0.30     # the halo's alpha where it touches the sheet
# …and HOW the halo dies across that reach. 0 (the default) is the plain LINEAR ramp — full alpha at the
# contact edge falling evenly to nothing at the fringe — which is what a stack of evenly-spaced copies at
# one alpha draws by itself. A linear ramp is not what a raised sheet actually casts: measured off the mock
# (games/grove/assets/_concepts/screens/palette_a_meadow_sky_board.png, the Shop tile's right edge), the
# darkening beside a tile falls 0.30 → 0.12 → 0.06 → 0 over 1 → 6 → 10 → 15 px, i.e. an EXPONENTIAL decay
# with a ~5.5px constant, not a straight line. A linear ramp long enough to reach the same fringe carries
# roughly twice the alpha through the middle of its run and reads as a broad smudge rather than a contact
# shadow. > 0 selects that decay: the value is the number of e-folds spent across the whole reach, so the
# curve is the same shape whatever the reach is (see `halo_profile`).
@export var halo_falloff: float = 0.0
# …and WHERE THE LIGHT IS. Zero (the default everywhere) is a symmetric ring: the same darkening on the
# left of a sheet as on its right. Nothing in the world casts that, and neither does the mock — measured
# on `_concepts/screens/palette_a_meadow_sky_board.png` with a rig that puts our tab and its tab on ONE
# flat sky at ONE scale (`make shot-mock`; docs/design/verifying-against-a-mock.md), the darkening beside
# the LEFTMOST tab runs 0.168 at 1px and is gone by 9px, while beside the RIGHTMOST it runs 0.388 and
# still reads 0.010 at 16px.
# The info card above the row splits the same way (0.23 left, 0.36 right), so it is the scene's light —
# upper left — and not one tile's quirk. No symmetric reach can be both: tuned to the right side the left
# is four times too heavy, tuned to the left the right disappears.
# This slides each dilated ring by `halo_offset` before it is drawn, which is the ordinary offset drop
# shadow: on the lit side the inner rings land back UNDER the sheet and never show, so that side loses
# both contact and reach; on the shadow side every ring clears the edge, so the first `|offset|` px sit at
# the full contact alpha and the decay starts beyond them. Analytically the accumulation becomes
# `halo_alpha · halo_profile((x ± offset) / halo_reach)` — the same curve, its ORIGIN moved — so the two
# sides come out with reaches of `halo_reach - offset` and `halo_reach + offset`.
@export var halo_offset: Vector2 = Vector2.ZERO
# PAPER THICKNESS — the lit cut edge. A dense stack of INSET outlines hugging the sheet's own perimeter:
# the edges facing the light (up) pick up a pale highlight off the paper colour, the sides take half of
# it, only the foot darkens with the shared shadow tint, and the band fades out reading inward. Keep the
# depth to a HAIRLINE (1-2px): that reads as the cut edge of a card. Reaching many px in turns the same
# band into an inward gradient, which no longer reads as an edge at all but as an inflated, domed face.
# 0 depth = off (the default everywhere).
@export var bevel_px: float = 0.0          # how far the bevel band reaches in from the edge (px)
@export var bevel_strength: float = 0.0    # peak alpha of the bevel's light + dark bands
# TAB FLARE — the sheet's top edge is narrower than its bottom by this FRACTION (0.07 = the bottom reads
# 7% wider than the top), a symmetric trapezoid about the vertical centreline. The BOTTOM keeps the full
# box width, so a row of flared tabs never widens into its neighbour's gap — the tops sit further apart
# instead. > 0 selects the "tab" base shape; 0 (the default) leaves every surface a plain rounded rect.
@export var flare: float = 0.0
# EDGE FEATHER — ANTIALIASING for the drawn silhouette. `draw_colored_polygon` rasterizes with no
# antialiasing at all: a pixel is either wholly inside the outline or wholly outside it, so a smooth
# arc comes out as a hard, stair-stepped binary edge. The torn deckle HIDES that (the tear is louder
# than the stairs), which is why it never showed until a surface asked for a smooth edge — on a nav
# tab, whose `deckle_amp` is 0, the aliasing IS the silhouette, and a card's defining quality is a
# clean cut edge. When this is > 0 the face is drawn as an opaque CORE inset past the edge plus a quad
# strip that ramps the paper's alpha 1 → 0 across `edge_feather` px CENTRED on the true outline —
# which is the coverage term the rasterizer skipped. The 50% point lands exactly on the outline, so
# the silhouette does not move or grow; the rim, bevel and halo still key off the same `pts`.
# 0 = off (the default everywhere): every torn surface draws the single flat polygon it always drew.
@export var edge_feather: float = 0.0
# HOW FINELY A CORNER ARC IS SAMPLED — the chord length in px between two points ON the arc.
#
# 0 keeps the legacy count (`_rect_base`), which is what every surface in the game renders at today and
# is therefore the default. That formula spends `r * 0.7 / STEP` points on a quarter-arc where the same
# STEP on a straight edge buys `len / STEP` — i.e. 0.7/(π/2) = 0.45x the density, at every radius. It is
# invisible while a corner radius is small or a torn deckle is drawn over it (cut_paper's own note above
# says the tear HIDES the arc's staircase), and it becomes the silhouette itself on the one shape whose
# corner radius IS half its height: a capsule. Measured on the mock rig at the unlock bar's 21.6px fill
# radius, the legacy formula spends the floor of 3.78 → THREE segments per quadrant, so the capsule's cap
# is a six-sided fan with 11px chords and a 0.74px sagitta, and the rim polyline traces those flats in a
# dark line. It photographs as an octagon beside the mock's semicircle.
#
# A surface that cares asks for a chord instead. Below the edge feather's own width the facet cannot
# survive the ramp, which is what engine/scripts/ui/paper_progress.gd asks for.
@export var arc_step: float = 0.0
var paper_tex: Texture2D = null

func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED   # so the paper UVs (> 1) tile instead of clamp
	resized.connect(queue_redraw)

func content_inset() -> float:
	return corner * 0.5 + deckle_amp

## Configure this panel from a NORMALIZED cut-paper opts dict — the shared edge knob set (corner ·
## deckle_amp · deckle_freq · rim_width · edge_shadow) produced by Kit.cut_paper_opts_from_config. This
## is the ONE place those opts become panel state: the dialog frame, the paper buttons, the settings rows
## AND the toggle switch all funnel through here, so the deckled edge behaves identically everywhere and a
## new knob is consumed in a single spot. `fill`/`rim`/`tile` are per-caller (colours + fibre differ per
## component); `amp_scale` shrinks the tear for small parts (e.g. a switch knob). Absent keys keep the
## panel's current value, so a caller may set (e.g.) a capsule `corner` before or after this call.
func configure(o: Dictionary, fill: Color, rim: Variant = null, tile: Texture2D = null, amp_scale: float = 1.0) -> void:
	# the trapezoid tab is one knob, not a second thing to remember: asking for a flare IS asking for the
	# "tab" base outline. Absent (or 0) the panel is the plain rounded rect every surface has always been.
	flare = maxf(0.0, float(o.get("flare", 0.0)))
	shape = "tab" if flare > 0.0 else "rect"
	corner = float(o.get("corner", corner))
	deckle_amp = float(o.get("deckle_amp", deckle_amp)) * amp_scale
	deckle_freq = float(o.get("deckle_freq", deckle_freq))
	rim_width = float(o.get("rim_width", rim_width))
	draw_shadow = bool(o.get("edge_shadow", draw_shadow))
	shadow_reach = float(o.get("shadow_reach", shadow_reach))
	shadow_blur = float(o.get("shadow_blur", shadow_blur))
	# shadow_strength is a 0..N percent knob → per-copy alpha (kept in the same normalized opts dict)
	if o.has("shadow_strength"):
		shadow_alpha = float(o["shadow_strength"]) / 100.0
	halo_reach = maxf(0.0, float(o.get("halo_reach", halo_reach)))
	if o.has("halo_strength"):
		halo_alpha = clampf(float(o["halo_strength"]) / 100.0, 0.0, 1.0)
	halo_falloff = maxf(0.0, float(o.get("halo_falloff", halo_falloff)))
	if o.has("halo_offset"):
		halo_offset = o["halo_offset"]
	bevel_px = maxf(0.0, float(o.get("bevel_px", bevel_px)))
	if o.has("bevel_strength"):
		bevel_strength = clampf(float(o["bevel_strength"]) / 100.0, 0.0, 1.0)
	edge_feather = maxf(0.0, float(o.get("edge_feather", edge_feather)))
	arc_step = maxf(0.0, float(o.get("arc_step", arc_step)))
	paper_color = fill
	# rim precedence: an explicit `rim` arg (a per-caller computed edge, e.g. the mail card's tinted rim)
	# wins; otherwise the shared `rim_color` edge knob in the opts dict applies, so the workbench picker
	# flows to every button that doesn't compute its own rim. Absent both → keep the current rim.
	if rim != null:
		rim_color = rim
	elif o.has("rim_color"):
		rim_color = o["rim_color"]
	if tile != null:
		paper_tex = tile
	queue_redraw()

func _draw() -> void:
	var pts := _deckle_polygon(size, corner)
	_draw_edge_halo()               # the all-sides ambient shadow (off unless `halo_reach` > 0)
	if draw_shadow and shadow_reach > 0.0 and shadow_alpha > 0.0:
		# The shadow must NOT mirror the torn edge tooth-for-tooth — dropped straight down, each SHARP tooth
		# casts its own hard vertical streak and the shadow reads as a row of stripes. `shadow_blur` (0..100%)
		# LOW-PASSES the tear PROFILE for the shadow only: the sharp high-frequency teeth are rounded off into
		# gentle low-frequency undulation, so the shadow stays organic + curvy (not a dead-flat rounded rect)
		# but has no stripes. The paper itself keeps its full crisp tear; only its shadow is smoothed.
		var smooth := clampf(shadow_blur / 100.0, 0.0, 1.0)
		# window radius in perimeter samples — grows with blur; kills the ~few-sample-wide teeth first.
		var blur_r := int(round(smooth * 16.0))
		var shadow_pts := pts if blur_r <= 0 else _deckle_polygon(size, corner, -1.0, blur_r)
		# farthest copy first, nearest last — overlap darkens the top, fringe fades at the bottom. The step
		# count tracks `shadow_reach` so the copies stay ~1px apart (dense = smooth) at any reach.
		var steps := maxi(4, int(round(shadow_reach)))
		var step := shadow_reach / float(steps)
		var sh := Look.shadow_color(shadow_alpha)
		for i in range(steps, 0, -1):
			var dy := step * float(i)
			var off := PackedVector2Array()
			for p in shadow_pts:
				off.append(p + Vector2(0.0, dy))
			draw_colored_polygon(off, sh)
	if _feather_px() > 0.0:
		_draw_feathered_face(pts)   # the antialiased silhouette (off unless `edge_feather` > 0)
	else:
		_draw_face(pts)
	_draw_bevel(pts)                # the paper's thickness (off unless `bevel_px` > 0)
	# the warm cut-edge rim, closed around the deckle. 0 width = NO border at all — the paper edge just
	# ends (a plain nav tab; only the active one is outlined). Guarded because draw_polyline treats a
	# non-positive width as "use the thin GL line", which would still draw a hairline.
	if rim_width > 0.0:
		var closed := pts.duplicate()
		closed.append(pts[0])
		draw_polyline(closed, rim_color, rim_width, true)

## The paper FACE as one flat polygon — the fibre tile mapped at its native scale (so the grain never
## stretches), or the bare fill when no tile is set. This is exactly what `_draw` always drew; the
## feathered path below reuses it for its opaque core.
func _draw_face(pts: PackedVector2Array) -> void:
	if paper_tex != null:
		var tp := paper_tex.get_size()
		var uvs := PackedVector2Array()
		for p in pts:
			uvs.append(Vector2(p.x / maxf(tp.x, 1.0), p.y / maxf(tp.y, 1.0)))
		draw_colored_polygon(pts, paper_color, uvs, paper_tex)
	else:
		draw_colored_polygon(pts, paper_color)

## The torn-edge polygon: take the base OUTLINE for the chosen shape (any convex/organic polygon), then
## push every sampled point OUT along its own edge-normal by fractal noise on the arc length. Because the
## deckle only needs a base outline + a normal, it works for a rect, a regular N-gon, or an organic blob —
## the shape itself is just `_base_perimeter`.
## `amp` overrides the tear height (px); < 0 uses the panel's own `deckle_amp`. `blur_r` low-passes the tear
## PROFILE with a box window of that many perimeter samples (0 = the raw crisp tear) — the shadow passes a
## non-zero radius so its outline keeps the SAME base shape + noise phase (registered to the sheet) but the
## sharp teeth round off into gentle curves.
func _deckle_polygon(sz: Vector2, r: float, amp: float = -1.0, blur_r: int = 0) -> PackedVector2Array:
	var tear := deckle_amp if amp < 0.0 else amp
	var raw := _base_perimeter(sz, r)
	# drop consecutive duplicate points (the rect builder shares a vertex where an edge meets a corner
	# arc); a duplicate makes the deckled outline spike/self-intersect and the fill triangulation fails.
	var base := PackedVector2Array()
	for p in raw:
		if base.is_empty() or base[base.size() - 1].distance_to(p) > 0.5:
			base.append(p)
	if base.size() >= 2 and base[0].distance_to(base[base.size() - 1]) < 0.5:
		base.remove_at(base.size() - 1)
	var n := base.size()
	if n < 3:
		return base
	var centroid := Vector2.ZERO
	for p in base:
		centroid += p
	centroid /= float(n)
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.seed = seed
	noise.frequency = deckle_freq
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 3
	# per-point outward normal + the raw displacement value; low-pass the displacement (not the positions,
	# so the base rect shape never shrinks) to round the teeth into curves for the shadow.
	var nrm := PackedVector2Array()
	var disp := PackedFloat32Array()
	nrm.resize(n)
	disp.resize(n)
	var arc := 0.0
	for i in n:
		var p := base[i]
		var prev := base[(i - 1 + n) % n]
		var nxt := base[(i + 1) % n]
		var tan := nxt - prev
		if tan.length() < 0.001:
			tan = p - centroid
		tan = tan.normalized()
		var nv := Vector2(tan.y, -tan.x)            # perpendicular to the local edge
		if nv.dot(p - centroid) < 0.0:
			nv = -nv                                # face outward
		nrm[i] = nv
		arc += p.distance_to(prev)
		disp[i] = noise.get_noise_1d(arc)
	if blur_r > 0:
		disp = _box_smooth_loop(disp, blur_r)
	var out := PackedVector2Array()
	for i in n:
		out.append(base[i] + nrm[i] * disp[i] * tear)
	return out

## Box low-pass over a CLOSED loop of scalars: each output is the mean of the 2·radius+1 neighbours (wrapping
## around the seam). Averaging a zero-mean wiggle keeps the long undulations and cancels the sharp teeth, so
## the deckle profile reads curvy rather than serrated — and the amplitude eases down as the window widens.
func _box_smooth_loop(vals: PackedFloat32Array, radius: int) -> PackedFloat32Array:
	var n := vals.size()
	if n == 0 or radius <= 0:
		return vals
	var out := PackedFloat32Array()
	out.resize(n)
	var win := 2 * radius + 1
	for i in n:
		var s := 0.0
		for k in range(-radius, radius + 1):
			s += vals[((i + k) % n + n) % n]
		out[i] = s / float(win)
	return out

## The un-torn base outline (dense, evenly sampled) for the current `shape`.
func _base_perimeter(sz: Vector2, r: float) -> PackedVector2Array:
	match shape:
		"poly":
			return _poly_base(sz)
		"blob":
			return _blob_base(sz)
		"tab":
			return _tab_base(sz, r)
		_:
			return _rect_base(sz, r)

const STEP := 4.0

func _rect_base(sz: Vector2, r: float) -> PackedVector2Array:
	r = clampf(r, 0.0, minf(sz.x, sz.y) * 0.5)
	var pts := PackedVector2Array()
	var edges := [
		{"a": Vector2(r, 0), "b": Vector2(sz.x - r, 0)},
		{"arc": true, "c": Vector2(sz.x - r, r), "s": -PI * 0.5},
		{"a": Vector2(sz.x, r), "b": Vector2(sz.x, sz.y - r)},
		{"arc": true, "c": Vector2(sz.x - r, sz.y - r), "s": 0.0},
		{"a": Vector2(sz.x - r, sz.y), "b": Vector2(r, sz.y)},
		{"arc": true, "c": Vector2(r, sz.y - r), "s": PI * 0.5},
		{"a": Vector2(0, sz.y - r), "b": Vector2(0, r)},
		{"arc": true, "c": Vector2(r, r), "s": PI},
	]
	for e in edges:
		if e.has("arc"):
			var c: Vector2 = e["c"]; var s: float = e["s"]
			# `arc_step` is a CHORD length, so the count comes off the arc's own length; 0 keeps the
			# legacy figure (see the knob's note — it is 0.45x the straight edges' density).
			var steps := maxi(3, int(r * 0.7 / STEP)) if arc_step <= 0.0 \
				else maxi(3, int(ceil(PI * 0.5 * r / arc_step)))
			for i in range(steps + 1):
				var ang := s + PI * 0.5 * (float(i) / float(steps))
				pts.append(c + Vector2(cos(ang), sin(ang)) * r)
		else:
			var a: Vector2 = e["a"]; var b: Vector2 = e["b"]
			var steps := maxi(1, int(a.distance_to(b) / STEP))
			for i in range(steps + 1):
				pts.append(a.lerp(b, float(i) / float(steps)))
	return pts

## A regular N-gon inscribed in the box (point up), edges densely sampled.
func _poly_base(sz: Vector2) -> PackedVector2Array:
	var c := sz * 0.5
	var rad := c - Vector2.ONE * (deckle_amp + 2.0)
	var verts := PackedVector2Array()
	for k in sides:
		var a := -PI * 0.5 + TAU * float(k) / float(sides)
		verts.append(c + Vector2(cos(a) * rad.x, sin(a) * rad.y))
	var pts := PackedVector2Array()
	for k in sides:
		var A := verts[k]; var B := verts[(k + 1) % sides]
		var steps := maxi(1, int(A.distance_to(B) / STEP))
		for i in range(steps):
			pts.append(A.lerp(B, float(i) / float(steps)))
	return pts

## An organic BLOB: a circle whose radius is wobbled by low-frequency noise (seamless around the loop).
func _blob_base(sz: Vector2) -> PackedVector2Array:
	var c := sz * 0.5
	var rad := c - Vector2.ONE * (deckle_amp + 6.0)
	var bn := FastNoiseLite.new()
	bn.seed = seed + 7
	bn.frequency = 1.0
	var pts := PackedVector2Array()
	var steps := 160
	for i in steps:
		var a := TAU * float(i) / float(steps)
		var wob := 1.0 + 0.16 * bn.get_noise_2d(cos(a), sin(a))   # radial wobble, continuous around the loop
		pts.append(c + Vector2(cos(a) * rad.x * wob, sin(a) * rad.y * wob))
	return pts

## ── TAB SHAPE · EDGE HALO · PAPER THICKNESS ──────────────────────────────────────────────────────
## Additive extras, all inert at their defaults: `flare` picks the trapezoid base, `halo_reach` the
## all-sides ambient shadow, `bevel_px` the slab bevel. A surface that sets none of them draws exactly
## what it always drew.

## The TRAPEZOID base outline (shape "tab"): the rounded rect, squeezed horizontally about its own
## centreline by an amount that eases from nothing at the BOTTOM edge to `flare` at the TOP. The bottom
## keeps the full box width on purpose — the sheet only ever narrows inside its box, so a row of tabs
## laid out on a fixed pitch cannot collide however hard it flares; the tops simply sit further apart.
func _tab_base(sz: Vector2, r: float) -> PackedVector2Array:
	var base := _rect_base(sz, r)
	if flare <= 0.0 or sz.y <= 0.0 or sz.x <= 0.0:
		return base
	var cx := sz.x * 0.5
	var squeeze := flare / (1.0 + flare)      # width removed at the TOP, as a fraction of the box width
	var out := PackedVector2Array()
	for p in base:
		var t := clampf(p.y / sz.y, 0.0, 1.0)  # 0 at the top edge → 1 at the bottom
		var s := 1.0 - squeeze * (1.0 - t)
		out.append(Vector2(cx + (p.x - cx) * s, p.y))
	return out

## Per-point OUTWARD unit normals of a closed loop — the perpendicular of the local tangent, flipped to
## face away from the centroid (the same construction the deckle uses). Shared by the halo (dilate) and
## the bevel (inset), so both follow the real silhouette — corners, flare and tear — rather than a
## centre-scaled approximation, which fattens a wide sheet more than a tall one.
func _outward_normals(pts: PackedVector2Array) -> PackedVector2Array:
	var n := pts.size()
	var out := PackedVector2Array()
	out.resize(n)
	if n < 3:
		return out
	var c := Vector2.ZERO
	for p in pts:
		c += p
	c /= float(n)
	for i in n:
		var p := pts[i]
		var tan := pts[(i + 1) % n] - pts[(i - 1 + n) % n]
		if tan.length() < 0.001:
			tan = p - c
		tan = tan.normalized()
		var nv := Vector2(tan.y, -tan.x)
		if nv.dot(p - c) < 0.0:
			nv = -nv
		out[i] = nv
	return out

## `pts` moved `d` px along its own outward normals (negative = inward).
func _offset_loop(pts: PackedVector2Array, d: float) -> PackedVector2Array:
	if pts.size() < 3 or absf(d) < 0.001:
		return pts
	return _offset_by(pts, _outward_normals(pts), d)

## `pts` moved `d` px along ALREADY-COMPUTED normals — for callers that offset the same loop several
## times (the feather builds three), so the O(n) normal pass runs once.
static func _offset_by(pts: PackedVector2Array, nrm: PackedVector2Array, d: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in pts.size():
		out.append(pts[i] + nrm[i] * d)
	return out

## The halo's ACCUMULATED darkening at `t` of the way out from the sheet's edge (0 = the contact edge,
## 1 = the fringe), as a fraction of `halo_alpha`. `k` = 0 is the plain linear ramp a stack of evenly
## spaced same-alpha copies draws on its own; k > 0 is an exponential decay spending `k` e-folds across
## the reach, rebased so the fringe still lands on exactly 0 (an unrebased exponential ends on a visible
## step). Pulled out as a static so the curve can be ASSERTED headlessly — a shadow profile is only
## measurable off a real-renderer capture, and `get_image()` is null under --headless.
static func halo_profile(k: float, t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	if k <= 0.0:
		return 1.0 - t
	var e := exp(-k)
	return (exp(-k * t) - e) / (1.0 - e)

## THE ALL-SIDES AMBIENT SHADOW. Same dense-stack idiom as the drop shadow — copies ~1px apart, each at a
## low alpha, overlapping into one smooth gradient — but the copies are DILATED instead of dropped, so the
## darkening rings the sheet (top and sides included) rather than pooling under it. The silhouette is the
## same low-passed tear the drop shadow uses, so the halo stays curvy and never draws the teeth as spikes.
## `halo_alpha` is the TOTAL alpha at the sheet's own edge and `halo_falloff` the SHAPE of its decay; each
## ring's own alpha is solved from the pair, so the accumulation lands on `halo_profile` whatever the reach
## (and hence the ring count) turns out to be. `halo_offset` then slides the whole stack toward the side
## the light is NOT on, which is what makes the two sides differ; at its default of zero this is the
## symmetric ring it has always been.
func _draw_edge_halo() -> void:
	if not draw_shadow or halo_reach <= 0.0 or halo_alpha <= 0.0:
		return
	var blur_r := int(round(clampf(shadow_blur / 100.0, 0.0, 1.0) * 16.0))
	var base := _deckle_polygon(size, corner, -1.0, blur_r)
	if base.size() < 3:
		return
	# ~1px between rings on the side the offset REACHES FURTHEST, not on the mean of the two — a sparse
	# stack shows as stepped bands, and the shadow side is where the stack is stretched thinnest.
	var steps := maxi(4, int(round(halo_reach + maxf(absf(halo_offset.x), absf(halo_offset.y)))))
	var peak := clampf(halo_alpha, 0.0, 1.0)
	# Outermost ring FIRST, so `keep` is the transmittance the rings already laid down leave behind: a ring
	# drawn at `per` takes the band it bounds from `keep` to the profile's target, which is exactly the
	# per-ring alpha that solves 1 - Π(1-a) = the wanted accumulation.
	var keep := 1.0
	for i in range(steps, 0, -1):
		# the band this ring bounds runs from (i-1)/steps to i/steps of the reach — sample its MIDPOINT,
		# which is the best a piecewise-constant stack can do against a continuous curve.
		var want := peak * halo_profile(halo_falloff, (float(i) - 0.5) / float(steps))
		var target := 1.0 - want
		var per := clampf(1.0 - target / maxf(keep, 0.0001), 0.0, 1.0)
		keep = target
		if per <= 0.0:
			continue
		var ring := _offset_loop(base, halo_reach * float(i) / float(steps))
		if halo_offset != Vector2.ZERO:
			ring = _translated(ring, halo_offset)
		draw_colored_polygon(ring, Look.shadow_color(per))

## `pts` slid bodily by `d` — the halo's light direction (see `halo_offset`). A translation, NOT another
## normal offset: sliding is what makes the ring asymmetric about the sheet, dilating it never can.
static func _translated(pts: PackedVector2Array, d: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p + d)
	return out

## ── THE ANTIALIASED SILHOUETTE ───────────────────────────────────────────────────────────────────
## How far the opaque CORE is inset PAST the feather's inner lip. The core is itself an un-antialiased
## polygon, so its own stair-stepped boundary has to land where the strip is already FULLY opaque —
## otherwise those stairs reappear as a 1px seam of background inside the feather. One pixel covers
## the rasterizer's worst-case half-pixel snap on either side of the nominal inset.
const FEATHER_GUARD := 1.0

## The feather actually applied: the request, clamped so the opaque core can never invert on a sheet
## smaller than the band (a tiny switch knob asking for a 1.5px feather on a 6px sheet).
func _feather_px() -> float:
	if edge_feather <= 0.0:
		return 0.0
	return minf(edge_feather, maxf(0.0, minf(size.x, size.y) / 3.0 - FEATHER_GUARD * 2.0))

## The face's alpha at a signed distance `d` px from the outline (negative = inside the sheet) for a
## band of width `feather`. This is the coverage term `draw_colored_polygon` does not compute: 1 inside
## the inner lip, 0 outside the outer one, LINEAR across the band, and exactly 0.5 ON the outline — so
## the silhouette keeps its position and only its hardness changes. A 0 feather is the binary step the
## unantialiased rasterizer produces, which is what every torn surface still draws.
static func feather_coverage(feather: float, d: float) -> float:
	if feather <= 0.0:
		return 1.0 if d <= 0.0 else 0.0
	return clampf(0.5 - d / feather, 0.0, 1.0)

## The face's DRAW PLAN for a band of `f` px: `core` is how far the opaque polygon is inset from the
## outline, `rings` the quad strips ringing it — {d_in, d_out, a_in, a_out}, signed px along the outward
## normal with alphas taken from `feather_coverage`. It is pulled out of the drawing so the ramp can be
## ASSERTED headlessly (engine/tests/action_button_tests.gd): a real-renderer capture is the only way to
## LOOK at an edge and `get_image()` is null under --headless, so the geometry is what a suite can hold.
static func feather_plan(f: float) -> Dictionary:
	var half := f * 0.5
	return {
		"core": -(half + FEATHER_GUARD),
		"rings": [
			# the guard band: fully opaque, so the core polygon's own un-antialiased boundary is buried
			{"d_in": -(half + FEATHER_GUARD), "d_out": -half, "a_in": 1.0, "a_out": 1.0},
			# …and the coverage ramp itself, centred on the outline
			{"d_in": -half, "d_out": half,
			 "a_in": feather_coverage(f, -half), "a_out": feather_coverage(f, half)},
		],
	}

## THE FACE, ANTIALIASED. An opaque core polygon (inset past the band, so its own hard edge is buried)
## plus two textured quad strips ringing the outline: the inner one holds full opacity across the guard
## band, the outer one carries the 1 → 0 coverage ramp. Both are built from the sheet's OWN outline, so
## a flared, cornered or torn silhouette feathers along whatever shape it actually is.
func _draw_feathered_face(pts: PackedVector2Array) -> void:
	var plan := feather_plan(_feather_px())
	var nrm := _outward_normals(pts)
	_draw_face(_offset_by(pts, nrm, float(plan["core"])))
	for r in plan["rings"]:
		_draw_feather_ring(pts, nrm, float(r["d_in"]), float(r["d_out"]), float(r["a_in"]), float(r["a_out"]))

## One closed strip of textured quads between the outline offset `d_in` (alpha `a_in`) and `d_out`
## (alpha `a_out`), the fibre tile sampled at the same native scale the face uses so the grain runs
## straight through the band. Godot's 2D API has no annulus primitive — `draw_colored_polygon` would
## have to triangulate a ring, which fails — so the strip goes to the server as one triangle array.
func _draw_feather_ring(pts: PackedVector2Array, nrm: PackedVector2Array, d_in: float, d_out: float, a_in: float, a_out: float) -> void:
	var n := pts.size()
	if n < 3:
		return
	var inner := _offset_by(pts, nrm, d_in)
	var outer := _offset_by(pts, nrm, d_out)
	var tp := paper_tex.get_size() if paper_tex != null else Vector2.ONE
	var verts := PackedVector2Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	for i in n:
		verts.append(inner[i])
		verts.append(outer[i])
		cols.append(Color(paper_color.r, paper_color.g, paper_color.b, paper_color.a * a_in))
		cols.append(Color(paper_color.r, paper_color.g, paper_color.b, paper_color.a * a_out))
		if paper_tex != null:
			uvs.append(Vector2(inner[i].x / maxf(tp.x, 1.0), inner[i].y / maxf(tp.y, 1.0)))
			uvs.append(Vector2(outer[i].x / maxf(tp.x, 1.0), outer[i].y / maxf(tp.y, 1.0)))
	var idx := PackedInt32Array()
	for i in n:
		var j := (i + 1) % n
		idx.append_array([i * 2, i * 2 + 1, j * 2 + 1, i * 2, j * 2 + 1, j * 2])
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), idx, verts, cols, uvs,
		PackedInt32Array(), PackedFloat32Array(),
		paper_tex.get_rid() if paper_tex != null else RID())

## How much LIGHT (x) and how much SHADOW (y) a stretch of edge takes, from the vertical component of its
## outward normal (-1 = facing straight up, 0 = a side, +1 = the foot). Light comes from above: the top
## edge takes the full highlight, a side takes half of it, and only the foot darkens. A side that SHADES
## instead of lighting is what turns a flat card into an inflated slab, so this split is asserted
## (engine/tests/action_button_tests.gd).
static func bevel_weights(ny: float) -> Vector2:
	return Vector2(clampf(0.5 - 0.5 * ny, 0.0, 1.0), clampf(ny, 0.0, 1.0))

## THE LIT CUT EDGE — the sheet's thickness. Dense inset outlines of the sheet's own perimeter, coloured
## by which way each stretch of edge faces (see bevel_weights). A sheet of paper lying on the art is LIT
## at its cut edge, not shaded into a slab. Alpha fades reading inward over `bevel_px`, so at a hairline
## depth the band reads as the mock's 1px lit rim rather than an inward gradient — a dark ramp reaching
## several px in is what inflates a flat card into a button. The light and dark passes are drawn
## separately — one polyline never blends cream into shadow.
func _draw_bevel(pts: PackedVector2Array) -> void:
	if bevel_px <= 0.0 or bevel_strength <= 0.0 or pts.size() < 3:
		return
	var n := pts.size()
	var nrm := _outward_normals(pts)
	var steps := maxi(3, int(round(bevel_px)))
	var hi := paper_color.lightened(0.5)
	var lo := Look.shadow_color(1.0)
	for k in steps:
		var t := float(k) / float(steps)               # 0 at the very edge → 1 at the reach
		var fade: float = bevel_strength * pow(1.0 - t, 1.6)
		if fade <= 0.004:
			continue
		var loop := PackedVector2Array()
		var lit := PackedColorArray()
		var shade := PackedColorArray()
		for i in n:
			loop.append(pts[i] - nrm[i] * (bevel_px * t + 0.75))
			var wgt := bevel_weights(nrm[i].y)
			lit.append(Color(hi.r, hi.g, hi.b, fade * wgt.x))
			shade.append(Color(lo.r, lo.g, lo.b, fade * wgt.y))
		loop.append(loop[0])
		lit.append(lit[0])
		shade.append(shade[0])
		draw_polyline_colors(loop, shade, 1.8, true)
		draw_polyline_colors(loop, lit, 1.8, true)
