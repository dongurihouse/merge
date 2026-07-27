extends Control
## Lightweight radial progress indicator for a running Soil cell.

var progress := 0.0
var line_width := 4.0
var track_color := Color(1, 1, 1, 0.22)
var fill_color := Color(1, 1, 1, 0.85)

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
		draw_arc(center, radius, start, start + PI * 2.0 * p, 96, fill_color, line_width, true)
