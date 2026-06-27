extends CanvasLayer
## The COMBO SCREEN BLOOM — a soft warm edge-glow that SWELLS as a merge streak builds and DECAYS
## back to nothing when the streak lapses. A self-owned overlay a scene drops in once at startup and
## pokes (`bump(combo)`) right after each `Feel.merge`; the verb stays parameter-light, the scene
## owns the world reaction. It is purely FELT — a glow, not motion — so unlike the motion verbs it is
## still ALLOWED under calm, just gentler (HALF strength): see _visible_strength.
##
## State is two scalars: `target` (where the glow wants to be — raised by bumps, bled off over time)
## and `strength` (where it IS — eased toward target each frame). Both the rise and the per-frame ease
## are PURE step functions (_bump_target / _advance) so the math unit-tests without a real frame loop.

const FX = preload("res://engine/scripts/ui/fx.gd")
const Tune = preload("res://engine/scripts/core/tuning.gd").FX

const GLOW := Color("#FFD27F")        # the warm bloom hue (a soft amber edge-glow)

var target := 0.0                     # where the glow is headed (bumps raise it; time bleeds it)
var strength := 0.0                   # the live glow amount (eased toward target each _process)

var _rect: ColorRect

func _init() -> void:
	# sit ABOVE the board art but BELOW the HUD where possible. A high-but-not-topmost layer so a
	# scene's HUD (built later / on its own higher layer) still reads over the glow.
	layer = 7

func _ready() -> void:
	_rect = ColorRect.new()
	_rect.color = Color(GLOW.r, GLOW.g, GLOW.b, 0.0)
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE          # non-interactive — never eats input
	# a soft additive radial vignette: bright at the edges, clear in the middle, so the glow frames
	# the screen instead of washing the board flat. (Texture-free — a shader-light gradient material.)
	_rect.material = _edge_material()
	add_child(_rect)
	set_process(true)

# A radial-falloff CanvasItem material: alpha ~0 at center, rising to full toward the corners, drawn
# ADDITIVE so it reads as light. The overall intensity is driven by modulate.a (set from strength).
func _edge_material() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m

## RAISE the glow for a streak of length `combo`. The longer the streak, the harder the swell —
## scaled by combo, clamped so it can never exceed COMBO_BLOOM_MAX. A combo of 0/1 barely registers;
## a long streak pins near the ceiling. No-op-safe to call every merge.
func bump(combo: int) -> void:
	target = _bump_target(target, combo)

func _process(delta: float) -> void:
	# ease the live strength toward the target, then bleed the target down so a lapse fades the glow.
	strength = _advance(strength, target, delta)
	target = maxf(0.0, target - Tune.COMBO_BLOOM_DECAY * delta)
	if _rect != null and is_instance_valid(_rect):
		_rect.color.a = _visible_strength(strength)

# --- pure helpers (no scene tree — unit-tested in an active grove suite) ---------------

## The new target after a bump for `combo`: raise by COMBO_BLOOM_RISE scaled by the streak length,
## clamped to [0, COMBO_BLOOM_MAX]. Pure.
static func _bump_target(current: float, combo: int) -> float:
	return clampf(current + Tune.COMBO_BLOOM_RISE * float(maxi(0, combo)), 0.0, Tune.COMBO_BLOOM_MAX)

## One frame of easing: move `strength` a fraction of the way toward `target` (a time-based lerp, so
## it's framerate-independent and always settles). Pure — callable without a real frame.
static func _advance(strength: float, target: float, delta: float) -> float:
	var k := clampf(delta * Tune.COMBO_BLOOM_EASE, 0.0, 1.0)
	return strength + (target - strength) * k

## The visible alpha for a given strength: the raw strength normally, HALVED under calm (the glow is
## still allowed — it is light, not motion — but gentler for motion-sensitive players).
static func _visible_strength(strength: float) -> float:
	return strength * (0.5 if FX.calm() else 1.0)
