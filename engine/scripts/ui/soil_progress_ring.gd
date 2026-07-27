extends Control
## Lightweight radial progress indicator for a running Soil cell.

var progress := 0.0
var line_width := 4.0
var track_color := Color(1, 1, 1, 0.22)
var fill_color := Color(1, 1, 1, 0.85)
## How far the track shows THROUGH on each side of the fill arc. The ring is read against a mid-tone
## brown earth patch AND against the growing piece's own art, and a single tinted arc washed out
## against both (measured on a capture: 1.22:1 vs its own backdrop, under 1.5:1 over ~80% of the arc
## — invisible at phone size). Drawing the dark full-circle track first and laying a slightly THINNER
## fill inside it makes the track double as an outline around the fill, so both halves stay legible
## whatever they sit on. 0 restores a flat single-width ring.
var outline_width := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var diameter := minf(size.x, size.y)
	if diameter <= 0.0:
		return
	var center := size * 0.5
	var radius := maxf(1.0, diameter * 0.5 - line_width * 0.5)
	var start := -PI * 0.5
	var end := start + PI * 2.0
	draw_arc(center, radius, start, end, 96, track_color, line_width, true)
	var p := clampf(progress, 0.0, 1.0)
	if p > 0.0:
		var fill_w := maxf(1.0, line_width - outline_width * 2.0)
		draw_arc(center, radius, start, start + PI * 2.0 * p, 96, fill_color, fill_w, true)
