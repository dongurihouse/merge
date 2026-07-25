@tool
extends Control
## A code-GENERATED sparkling overlay — twinkling 4-point stars on a loop. No assets, no particles, no
## FX system: it draws + animates itself in _draw/_process. Add it full-rect over a card (mouse-ignore)
## to mark the daily "today" (claimable) rung. Self-contained so it runs in the workbench AND the game.

@export var tint := Color("#FFF6CC")   # warm sparkle colour
@export var count := 9                  # how many twinkles
@export var speed := 0.85               # twinkle cycles per second

var _t := 0.0
var _spots: Array = []   # [{p: Vector2 (0..1 of the rect), phase, size}]

# Fixed spots biased to the UPPER card (around the reward), clear of the bottom CTA. Deterministic — a
# laid-out spread reads better than random clumping, and avoids per-frame randomness.
const _BASE := [
	Vector2(0.20, 0.24), Vector2(0.80, 0.20), Vector2(0.50, 0.12), Vector2(0.14, 0.52),
	Vector2(0.86, 0.50), Vector2(0.34, 0.66), Vector2(0.68, 0.66), Vector2(0.50, 0.40), Vector2(0.30, 0.40),
]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_seed()
	set_process(true)

func _seed() -> void:
	_spots.clear()
	for i in mini(count, _BASE.size()):
		_spots.append({"p": _BASE[i], "phase": float(i) * 0.37, "size": 6.0 + float(i % 3) * 3.5})

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
		_spark(c, float(s.size) * (0.4 + 0.6 * tw), a)

# A 4-point sparkle = two crossed thin diamonds (convex, so they triangulate cleanly) + a bright core.
func _spark(c: Vector2, r: float, a: float) -> void:
	var col := tint; col.a = a
	var w := r * 0.16
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(0, -r), c + Vector2(w, 0), c + Vector2(0, r), c + Vector2(-w, 0)]), col)
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-r, 0), c + Vector2(0, w), c + Vector2(r, 0), c + Vector2(0, -w)]), col)
	draw_circle(c, w * 1.5, Color(1, 1, 1, a * 0.95))
