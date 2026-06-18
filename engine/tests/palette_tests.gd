extends SceneTree
## Headless guard for the UI-redesign palette role tiers.
##   godot --headless --path . -s res://engine/tests/palette_tests.gd
## Proves grove_palette.gd carries the semantic role tokens and that the
## figure/ground relationships hold: the surface is a desaturated stage,
## locked recedes below it, and green is reclaimed as an accent (no longer
## the play surface). See docs/superpowers/specs/2026-06-17-ui-language-redesign-design.md.

const PAL := preload("res://games/grove/grove_palette.gd")

var _pass := 0
var _fail := 0

func ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _dist(a: Color, b: Color) -> float:
	return sqrt(pow(a.r - b.r, 2.0) + pow(a.g - b.g, 2.0) + pow(a.b - b.b, 2.0))

func _initialize() -> void:
	print("== Palette role-tier guard ==")
	var c := (PAL as GDScript).get_script_constant_map()
	var roles := ["SCREEN_BG", "SURFACE", "SURFACE_FRAME", "CELL_EMPTY", "LOCKED",
		"LOCKED_GLYPH", "NEAR_UNLOCK", "NEAR_HINT", "CARD_PEDESTAL", "INK", "INK_MUTED",
		"ACCENT_CTA", "ACCENT_REWARD", "ACCENT_ALERT", "ACCENT_INFO"]
	for r in roles:
		ok(c.has(r), "role token present: %s" % r)
	var surface: Color = c.get("SURFACE", Color.BLACK)
	var locked: Color = c.get("LOCKED", Color.BLACK)
	var cta: Color = c.get("ACCENT_CTA", Color.BLACK)
	# Surface is a desaturated neutral stage, not a saturated green.
	ok(surface.s < 0.20, "SURFACE is desaturated (s=%.3f < 0.20)" % surface.s)
	ok(surface.v > 0.70, "SURFACE is mid-high value (v=%.3f > 0.70)" % surface.v)
	# Locked recedes BELOW the surface by value, while staying desaturated.
	ok(locked.v < surface.v, "LOCKED recedes by value (%.3f < %.3f)" % [locked.v, surface.v])
	ok(locked.s < 0.25, "LOCKED stays desaturated (s=%.3f < 0.25)" % locked.s)
	# Green is reclaimed as an accent — far from the surface...
	ok(_dist(cta, surface) > 0.30, "ACCENT_CTA distinct from SURFACE (d=%.3f)" % _dist(cta, surface))
	# ...and the old GROUND~BTN_PRIMARY olive collision is gone.
	ok(_dist(c.get("GROUND", Color.BLACK), c.get("BTN_PRIMARY", Color.BLACK)) > 0.30,
		"GROUND vs BTN_PRIMARY collision resolved")
	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)
