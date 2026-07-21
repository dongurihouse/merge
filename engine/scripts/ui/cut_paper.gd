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
@export_enum("rect", "poly", "blob") var shape: String = "rect"
@export var sides: int = 5          # for shape == "poly" (pentagon, hexagon, …)
@export var corner: float = 30.0    # rect corner radius
@export var deckle_amp: float = 5.0
@export var deckle_freq: float = 0.05
@export var seed: int = 1
@export var paper_color: Color = Pal.CREAM
@export var rim_color: Color = Color("#E7D6BC")   # warm cut edge
@export var rim_width: float = 2.0
@export var draw_shadow: bool = true
var paper_tex: Texture2D = null

# soft drop shadow: a few dark deckled copies dropped down and fading (fakes a blur)
const SHADOW := [{"dy": 3.0, "a": 0.14}, {"dy": 7.0, "a": 0.10}, {"dy": 11.0, "a": 0.06}]

func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED   # so the paper UVs (> 1) tile instead of clamp
	resized.connect(queue_redraw)

func set_paper(tex: Texture2D) -> void:
	paper_tex = tex
	queue_redraw()

## How far content should stay inside the panel edge (the deckle amplitude + a little breathing room).
func content_inset() -> float:
	return corner * 0.5 + deckle_amp

func _draw() -> void:
	var pts := _deckle_polygon(size, corner)
	if draw_shadow:
		for s in SHADOW:
			var off := PackedVector2Array()
			for p in pts:
				off.append(p + Vector2(0.0, float(s["dy"])))
			draw_colored_polygon(off, Look.shadow_color(float(s["a"])))
	if paper_tex != null:
		var tp := paper_tex.get_size()
		var uvs := PackedVector2Array()
		for p in pts:
			uvs.append(Vector2(p.x / maxf(tp.x, 1.0), p.y / maxf(tp.y, 1.0)))
		draw_colored_polygon(pts, paper_color, uvs, paper_tex)
	else:
		draw_colored_polygon(pts, paper_color)
	# the warm cut-edge rim, closed around the deckle
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, rim_color, rim_width, true)

## The torn-edge polygon: take the base OUTLINE for the chosen shape (any convex/organic polygon), then
## push every sampled point OUT along its own edge-normal by fractal noise on the arc length. Because the
## deckle only needs a base outline + a normal, it works for a rect, a regular N-gon, or an organic blob —
## the shape itself is just `_base_perimeter`.
func _deckle_polygon(sz: Vector2, r: float) -> PackedVector2Array:
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
	var out := PackedVector2Array()
	var arc := 0.0
	for i in n:
		var p := base[i]
		var prev := base[(i - 1 + n) % n]
		var nxt := base[(i + 1) % n]
		var tan := nxt - prev
		if tan.length() < 0.001:
			tan = p - centroid
		tan = tan.normalized()
		var nrm := Vector2(tan.y, -tan.x)            # perpendicular to the local edge
		if nrm.dot(p - centroid) < 0.0:
			nrm = -nrm                                # face outward
		arc += p.distance_to(prev)
		out.append(p + nrm * noise.get_noise_1d(arc) * deckle_amp)
	return out

## The un-torn base outline (dense, evenly sampled) for the current `shape`.
func _base_perimeter(sz: Vector2, r: float) -> PackedVector2Array:
	match shape:
		"poly":
			return _poly_base(sz)
		"blob":
			return _blob_base(sz)
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
			var steps := maxi(3, int(r * 0.7 / STEP))
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
