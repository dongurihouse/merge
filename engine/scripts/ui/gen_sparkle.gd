@tool
extends Control
## A code-GENERATED twinkle overlay — a few 4-point stars on a slow loop, drawn + animated in
## _draw/_process. NO particles on purpose: CPUParticles2D is a Node2D and does not render when
## parented to a Control (the board item holder is a Control), so a self-drawing Control is the
## reliable path. Add it full-rect over a host, mouse-ignore. The host's FX.breathe carries the larger
## motion.
##
## Its defaults are the GENERATOR tuning (sparser/softer, sized for a single board cell) — the only
## tuning that ships. It is written to be subclassed: a re-tune overrides `_seed()` (its own spot
## table + phase/size ramp) and sets the exports in `_init()`. A game-side subclass is legal
## (games/ → engine/ is the allowed import direction; the layering guard only forbids engine → games);
## there is none right now — the daily-card one was retired with the kit's daily_card mock sparkle.

@export var tint := Color("#FFF4C2")   # warm twinkle colour
@export var count := 5                  # how many twinkles (capped by the fixed spot list)
@export var size_mult := 1.0            # multiplier over the fixed spot radii
@export var speed := 0.7                # twinkle cycles per second

var _t := 0.0
var _spots: Array = []   # [{p: Vector2 (0..1 of the rect), phase, size}]

# Fixed spots ringing the icon (upper + sides, a couple low), clear of the dead centre where the art
# reads. Deterministic — a laid-out spread reads better than random clumping, no per-frame rng.
const _BASE := [
	Vector2(0.22, 0.20), Vector2(0.80, 0.24), Vector2(0.50, 0.11),
	Vector2(0.15, 0.54), Vector2(0.85, 0.52), Vector2(0.34, 0.80), Vector2(0.68, 0.78),
]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_seed()
	set_process(true)

# The GENERATOR spread. Overridden wholesale by a subclass with its own table + ramp (see the header)
# — it is the only member that differs between tunings, so there are no per-knob config flags here.
func _seed() -> void:
	_spots.clear()
	for i in mini(count, _BASE.size()):
		_spots.append({"p": _BASE[i], "phase": float(i) * 0.41, "size": 5.0 + float(i % 3) * 2.5})

func _process(delta: float) -> void:
	_t += delta * speed
	queue_redraw()

func _draw() -> void:
	for s in _spots:
		var tw: float = 0.5 + 0.5 * sin((_t + float(s.phase)) * TAU)   # 0..1
		var a := tw * tw * tw                                          # sharp, mostly-off twinkle
		if a < 0.03:
			continue
		var c := Vector2(float(s.p.x) * size.x, float(s.p.y) * size.y)
		_spark(c, float(s.size) * size_mult * (0.4 + 0.6 * tw), a)

# A 4-point sparkle = two crossed thin diamonds (convex, triangulate cleanly) + a bright core.
func _spark(c: Vector2, r: float, a: float) -> void:
	var col := tint
	col.a = a
	var w := r * 0.16
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(0, -r), c + Vector2(w, 0), c + Vector2(0, r), c + Vector2(-w, 0)]), col)
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-r, 0), c + Vector2(0, w), c + Vector2(r, 0), c + Vector2(0, -w)]), col)
	draw_circle(c, w * 1.5, Color(1, 1, 1, a * 0.95))
