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
@export var corner: float = 30.0
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

## Build the torn-edge polygon: walk the rounded-rect perimeter at a fine step, and push each point OUT
## along its normal by fractal noise sampled on the cumulative arc length (so the wobble is continuous).
func _deckle_polygon(sz: Vector2, r: float) -> PackedVector2Array:
	r = clampf(r, 0.0, minf(sz.x, sz.y) * 0.5)
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.seed = seed
	noise.frequency = deckle_freq
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 3
	var step := 4.0
	var pts := PackedVector2Array()
	var arc := 0.0
	# straight edges as (start, dir, normal, length); corner arcs interleaved
	var edges := [
		{"a": Vector2(r, 0), "b": Vector2(sz.x - r, 0), "n": Vector2(0, -1)},                 # top
		{"arc": true, "c": Vector2(sz.x - r, r), "n0": Vector2(0, -1)},                        # TR corner
		{"a": Vector2(sz.x, r), "b": Vector2(sz.x, sz.y - r), "n": Vector2(1, 0)},             # right
		{"arc": true, "c": Vector2(sz.x - r, sz.y - r), "n0": Vector2(1, 0)},                  # BR
		{"a": Vector2(sz.x - r, sz.y), "b": Vector2(r, sz.y), "n": Vector2(0, 1)},             # bottom
		{"arc": true, "c": Vector2(r, sz.y - r), "n0": Vector2(0, 1)},                         # BL
		{"a": Vector2(0, sz.y - r), "b": Vector2(0, r), "n": Vector2(-1, 0)},                  # left
		{"arc": true, "c": Vector2(r, r), "n0": Vector2(-1, 0)},                               # TL
	]
	for e in edges:
		if e.has("arc"):
			var c: Vector2 = e["c"]
			var start_ang := (e["n0"] as Vector2).angle()
			var n := maxi(3, int(r * 0.7 / step))
			for i in range(n + 1):
				var ang := start_ang + PI * 0.5 * (float(i) / float(n))
				var nrm := Vector2(cos(ang), sin(ang))
				var base := c + nrm * r
				arc += step
				pts.append(base + nrm * noise.get_noise_1d(arc) * deckle_amp)
		else:
			var a: Vector2 = e["a"]; var b: Vector2 = e["b"]; var nrm: Vector2 = e["n"]
			var len := a.distance_to(b)
			var n := maxi(1, int(len / step))
			for i in range(n + 1):
				var base := a.lerp(b, float(i) / float(n))
				arc += step
				pts.append(base + nrm * noise.get_noise_1d(arc) * deckle_amp)
	return pts
