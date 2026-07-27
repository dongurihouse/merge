@tool
extends "res://engine/scripts/ui/gen_sparkle.gd"
## The DAILY-CARD tuning of the shared code-drawn sparkle. Add it full-rect over a card (mouse-ignore)
## to mark the daily "today" (claimable) rung. No assets, no particles, no FX system — the base draws +
## animates itself in _draw/_process, so this runs in the workbench AND the game.
##
## Everything visual is the base's (engine/scripts/ui/gen_sparkle.gd): the twinkle curve, the 4-point
## star geometry, the animation loop. Only the spread differs — a wider spot table, a slower phase
## march and bigger stars than the single-board-cell tuning the base ships. The base's `size_mult`
## stays at its 1.0 default here; the card sizes its stars through the ramp below.

# Fixed spots biased to the UPPER card (around the reward), clear of the bottom CTA. Deterministic — a
# laid-out spread reads better than random clumping, and avoids per-frame randomness.
const _CARD_BASE := [
	Vector2(0.20, 0.24), Vector2(0.80, 0.20), Vector2(0.50, 0.12), Vector2(0.14, 0.52),
	Vector2(0.86, 0.50), Vector2(0.34, 0.66), Vector2(0.68, 0.66), Vector2(0.50, 0.40), Vector2(0.30, 0.40),
]

func _init() -> void:
	tint = Color("#FFF6CC")   # warm sparkle colour
	count = 9                 # how many twinkles
	speed = 0.85              # twinkle cycles per second

func _seed() -> void:
	_spots.clear()
	for i in mini(count, _CARD_BASE.size()):
		_spots.append({"p": _CARD_BASE[i], "phase": float(i) * 0.37, "size": 6.0 + float(i % 3) * 3.5})
