extends RefCounted
## Sprite-based currency pill (cut-paper concept, built from scratch alongside the legacy
## Kit.gold_currency_pill). ONE flat pill PNG — icon + green "+" baked in at the left, an empty
## cream body to the right — plus a dark-ink number Label over that body. The whole pill is a Button
## that opens its stall (the baked "+" is a decorative affordance, matching the old wallet).
##
## Kept SEPARATE from Kit.gold_currency_pill: the UI Workbench still tunes/renders the drawn pill;
## the live HUD wallet uses THIS one. The node NAMES mirror the old pill's contract so the shop
## (fly-home / tick / need-more), the board (water FX anchor), and their tests keep resolving:
##   GoldCurrencyPill (Button) · GoldCurrencyAmount (Label) · GoldCurrencyIcon · GoldCurrencyPlusButton
##
##   var pill := CurrencyPillSprite.build({"tex": tex, "count": 100, "height": 96.0})
##   pill.find_child("GoldCurrencyAmount", true, false)   # the number, ticked by the HUD refresh

const UiFont = preload("res://engine/scripts/ui/ui_font.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const FX = preload("res://engine/scripts/ui/fx.gd")
const Look = preload("res://engine/scripts/ui/skin.gd")
const Pal = Game.PALETTE

# Soft downward paper shadow: a few dark copies of the pill's own silhouette, each nudged down and fading
# out, so the cut-paper pill lifts off the scene along its REAL outline (the mock's compact drop shadow).
# {dy = fraction of pill height it drops, a = shadow-tint alpha}. Reuses the shared Look.shadow_color tint.
const SHADOW := [
	{"dy": 0.035, "a": 0.16},
	{"dy": 0.075, "a": 0.12},
	{"dy": 0.115, "a": 0.08},
]

# Empty-body horizontal band (fraction of pill width) the number is laid into. The icon + "+" own
# the left ~38%; the number gets the rest, left-aligned so a growing count fills the reserved space.
const BODY_L := 0.40
const BODY_R := 0.95
# Number font as a fraction of pill height when `num_size` is not supplied.
const NUM_FRAC := 0.44
# Baked icon / "+" centres as a fraction of the sprite, for the (mouse-ignoring) FX-anchor markers.
const ICON_C := Vector2(0.16, 0.45)
const ICON_SZ := Vector2(0.22, 0.52)
const PLUS_C := Vector2(0.30, 0.72)
const PLUS_SZ := Vector2(0.17, 0.36)

static func build(opts: Dictionary) -> Button:
	var tex: Texture2D = opts.get("tex")
	var count := int(opts.get("count", 0))
	var height := float(opts.get("height", 96.0))
	var format := bool(opts.get("format", true))
	var num_size := int(opts.get("num_size", int(round(height * NUM_FRAC))))
	var plus_action: Variant = opts.get("plus_action", null)

	var aspect := 1.0
	if tex != null and tex.get_height() > 0:
		aspect = float(tex.get_width()) / float(tex.get_height())
	var w := roundf(height * aspect)

	var panel := Button.new()
	panel.name = "GoldCurrencyPill"
	panel.flat = true   # the pill art is child TextureRects; the button draws no chrome of its own
	panel.focus_mode = Control.FOCUS_NONE
	panel.custom_minimum_size = Vector2(w, height)   # natural size for a free-standing pill; the HUD slot-sizes width
	for st in ["normal", "hover", "pressed", "focus"]:
		panel.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	if plus_action is Callable and (plus_action as Callable).is_valid():
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.pressed.connect(plus_action as Callable)
	else:
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Shadow FIRST (behind), then the pill sprite. Both are full-rect TextureRects stretched to the panel
	# (STRETCH_SCALE), so the baked icon/"+"/body map to fixed panel fractions at any slot width, and the
	# shadow tracks the pill's outline. A child TextureRect can't drive the pill width to native px here:
	# the panel is a Button (children don't feed its min) and the HUD slot-sizes it via EXPAND_FILL.
	for layer in SHADOW:
		panel.add_child(_sprite_layer(tex, Look.shadow_color(float(layer["a"])), height * float(layer["dy"])))
	panel.add_child(_sprite_layer(tex, Color.WHITE, 0.0))

	# Icon + "+" FX-anchor markers over the baked art (mouse-ignoring; the board flies water to the
	# icon marker, the shop flies buys to the plus marker). Anchored, so they follow the panel size.
	panel.add_child(_marker("GoldCurrencyIcon", ICON_C, ICON_SZ))
	panel.add_child(_marker("GoldCurrencyPlusButton", PLUS_C, PLUS_SZ))

	var num := Label.new()
	num.name = "GoldCurrencyAmount"
	num.text = FX.format_amount(count) if format else str(count)
	num.theme = UiFont.make()
	num.add_theme_font_size_override("font_size", num_size)
	num.add_theme_color_override("font_color", Pal.INK)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	num.anchor_left = BODY_L
	num.anchor_right = BODY_R
	num.anchor_top = 0.0
	num.anchor_bottom = 1.0
	num.offset_left = 0.0
	num.offset_right = 0.0
	num.offset_top = 0.0
	num.offset_bottom = 0.0
	# Opt the number into the shared wallet abbreviation + shrink-to-fit (FX.format_amount / fit_amount /
	# tick). We set amount_max_w + amount_base_font but NOT amount_right_x, so fit_amount only rescales
	# the font — it never re-anchors the box, keeping the number LEFT-aligned against the icon.
	if format:
		num.set_meta("amount_max_w", w * (BODY_R - BODY_L))
		num.set_meta("amount_base_font", num_size)
	num.set_meta("amount_value", count)
	panel.add_child(num)
	return panel

## One full-pill TextureRect stretched to the panel, tinted by `mod` and dropped `dy` px down. The pill
## art passes Color.WHITE / dy 0; the shadow copies pass a slate-tint alpha and a small downward drop.
static func _sprite_layer(tex: Texture2D, mod: Color, dy: float) -> TextureRect:
	var tr := TextureRect.new()
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE   # BEFORE anchors, so the texture's native px never drives min size
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.texture = tex
	tr.modulate = mod
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.offset_top += dy
	tr.offset_bottom += dy
	tr.custom_minimum_size = Vector2.ZERO
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr

static func _marker(node_name: String, c: Vector2, sz: Vector2) -> Control:
	var m := Control.new()
	m.name = node_name
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.anchor_left = c.x - sz.x * 0.5
	m.anchor_right = c.x + sz.x * 0.5
	m.anchor_top = c.y - sz.y * 0.5
	m.anchor_bottom = c.y + sz.y * 0.5
	m.offset_left = 0.0
	m.offset_right = 0.0
	m.offset_top = 0.0
	m.offset_bottom = 0.0
	return m
