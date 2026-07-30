@tool
extends Control
## Code-drawn generator mastery ring. The board owns the meter; this view only
## paints a warm track plus the current-rank progress arc.

@export var progress := 0.0: set = _set_progress
@export var ring_color := Color.WHITE: set = _set_ring_color
@export var track_color := Color("#FBF3EA", 0.32): set = _set_track_color
@export var stroke_frac := 0.05: set = _set_stroke_frac
@export var pad_frac := 0.08: set = _set_pad_frac

func _set_progress(v: float) -> void:
	progress = clampf(v, 0.0, 1.0)
	queue_redraw()

func _set_ring_color(v: Color) -> void:
	ring_color = v
	queue_redraw()

func _set_track_color(v: Color) -> void:
	track_color = v
	queue_redraw()

func _set_stroke_frac(v: float) -> void:
	stroke_frac = clampf(v, 0.01, 0.18)
	queue_redraw()

func _set_pad_frac(v: float) -> void:
	pad_frac = clampf(v, 0.0, 0.30)
	queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

## The REVEAL sweep: fill from empty up to the meter's banked value. Used once, on the first
## generator tap after the mastery gate arms — the ring has been filling invisibly since L1, and
## this is the beat that says so.
func sweep_to(frac: float, secs: float) -> void:
	progress = 0.0
	queue_redraw()
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void:
		progress = v
		queue_redraw(), 0.0, clampf(frac, 0.0, 1.0), secs)

func _draw() -> void:
	var s := minf(size.x, size.y)
	if s <= 0.0:
		return
	var thick := maxf(2.0, s * stroke_frac)
	var pad := s * pad_frac + thick * 0.5
	var center := Vector2(size.x, size.y) * 0.5
	var radius := maxf(1.0, s * 0.5 - pad)
	draw_arc(center, radius, -PI * 0.5, PI * 1.5, 96, track_color, thick, true)
	if progress <= 0.0:
		return
	draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * progress, 96, ring_color, thick, true)
