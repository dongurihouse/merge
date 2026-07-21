extends RefCounted
## A tappable cut-paper SPRITE button: the flat art (icon + label baked into one PNG) laid over its own
## soft downward silhouette shadow, on a flat Button. Shared by the bottom-nav tiles and the CONTINUE
## button — anything whose whole look is a single baked cut-paper sprite. The sprite STRETCHES to `size`
## (callers that want the native aspect pass a matching size). Matches CurrencyPillSprite's shadow.
##
##   var b := SpriteButton.build(load(path), Vector2(w, w), on_tap, {"name": "MapTile"})

const Look = preload("res://engine/scripts/ui/skin.gd")

# Soft downward paper shadow: dark copies of the sprite's own silhouette, each nudged down and fading out.
# {dy = fraction of button height it drops, a = shadow-tint alpha}. Same feel as the wallet pills.
const SHADOW := [
	{"dy": 0.03, "a": 0.16},
	{"dy": 0.06, "a": 0.12},
	{"dy": 0.09, "a": 0.08},
]

static func build(tex: Texture2D, size: Vector2, action: Callable, opts: Dictionary = {}) -> Button:
	var b := Button.new()
	b.name = String(opts.get("name", "SpriteButton"))
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = size
	b.size = size
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	if String(opts.get("tooltip", "")) != "":
		b.tooltip_text = String(opts["tooltip"])
	if action.is_valid():
		b.mouse_filter = Control.MOUSE_FILTER_STOP
		b.pressed.connect(action)
	else:
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# shadow copies FIRST (behind), then the sprite on top
	for layer in SHADOW:
		b.add_child(_layer(tex, Look.shadow_color(float(layer["a"])), size.y * float(layer["dy"])))
	b.add_child(_layer(tex, Color.WHITE, 0.0))
	Look.add_press_juice(b)
	return b

static func _layer(tex: Texture2D, mod: Color, dy: float) -> TextureRect:
	var tr := TextureRect.new()
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE   # BEFORE anchors, so native px never drives min size
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.texture = tex
	tr.modulate = mod
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.offset_top += dy
	tr.offset_bottom += dy
	tr.custom_minimum_size = Vector2.ZERO
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr
