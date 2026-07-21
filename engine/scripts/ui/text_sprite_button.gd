extends RefCounted
## A cut-paper button whose BACKGROUND is a baked sprite (green / cream torn-paper pill) with the label
## drawn on TOP as live text — so the button art is reusable and the label stays localizable (unlike the
## whole-sprite SpriteButton). The bg stretches to `size` over the shared soft drop shadow.
##
##   var b := TextSpriteButton.build(load(bg), "Claim", Vector2(w, h), on_tap,
##       {"font": 34, "color": Color("#F6EBDD")})

const UiFont = preload("res://engine/scripts/ui/ui_font.gd")
const Look = preload("res://engine/scripts/ui/skin.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const Pal = Game.PALETTE

const SHADOW := [
	{"dy": 0.05, "a": 0.16},
	{"dy": 0.10, "a": 0.11},
]

static func build(bg_tex: Texture2D, text: String, size: Vector2, action: Callable, opts: Dictionary = {}) -> Button:
	var b := Button.new()
	b.name = String(opts.get("name", "TextSpriteButton"))
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = size
	b.size = size
	# Button.text carries the label for find-by-text lookups, but it draws BEHIND the bg sprites (children
	# draw on top), so it's invisible — the visible text is the Label added last. Zero its font colour too.
	b.text = text
	b.add_theme_color_override("font_color", Color(0, 0, 0, 0))
	b.tooltip_text = text
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	if action.is_valid():
		b.mouse_filter = Control.MOUSE_FILTER_STOP
		b.pressed.connect(action)
	else:
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# shadow copies of the bg FIRST (behind), then the bg, then the label
	for layer in SHADOW:
		b.add_child(_bg(bg_tex, Look.shadow_color(float(layer["a"])), size.y * float(layer["dy"])))
	b.add_child(_bg(bg_tex, Color.WHITE, 0.0))

	var lbl := Label.new()
	lbl.name = "Label"
	lbl.text = text
	lbl.theme = UiFont.make()
	lbl.add_theme_font_size_override("font_size", int(opts.get("font", int(round(size.y * 0.42)))))
	lbl.add_theme_color_override("font_color", opts.get("color", Pal.INK))
	lbl.add_theme_constant_override("outline_size", 0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b.add_child(lbl)
	Look.add_press_juice(b)
	return b

static func _bg(tex: Texture2D, mod: Color, dy: float) -> TextureRect:
	var tr := TextureRect.new()
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.texture = tex
	tr.modulate = mod
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.offset_top += dy
	tr.offset_bottom += dy
	tr.custom_minimum_size = Vector2.ZERO
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr
