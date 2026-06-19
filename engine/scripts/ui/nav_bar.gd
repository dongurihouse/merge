extends RefCounted
## THE shared bottom navigation row (owner: one module reused on the board + the map).
## A full-width, slab-less HBox of BIG painted round buttons sitting on the scene, with
## expanding spacers between them so they spread evenly edge to edge. Generalizes the board's
## old per-scene nav builder (_make_nav_button + _nav_spacer + the inline row) so both the
## board and the home/map screen build their bottom row through ONE component.
## Usage:
##   var nav := NavBar.build(self, [
##       {"icon": "nav_home.png", "action": Callable, "px": 150.0},
##       {"icon": "nav_shop.png", "action": Callable},
##       ...
##   ])
##   nav.row        — the HBoxContainer (anchored bottom; the spotlight/refs target it)
##   nav.buttons    — [Control] in spec order (round icons + the primary pill; spacers NOT included)
## Each spec is a Dictionary. A spec is one of three shapes:
##   - a round ICON button (the default): set `icon`.
##   - a PRIMARY TEXT pill (the wide green CTA the map centers): set `text` (and usually `primary`:true).
##     It uses Look.button(text, action, primary) — the same solid grove pill the old "Tend the garden ▶"
##     CTA used — so it reads as the prominent centre action flanked by the round icons. The even-spacing
##     layout is unchanged (expanding spacers between every entry), so the wider pill sits centred.
##   - a CUSTOM control: set `make` (a Callable returning a Control) for full control over the button.
## Fields:
##   icon     (String)   kit png name, e.g. "nav_shop.png" — Look.kit(icon); falls back to a glyph icon
##   text     (String)   primary-pill label, e.g. "Enter Garden ▶" — routes to Look.button (text mode)
##   primary  (bool)     text pills only: green primary CTA look (default true when `text` is set)
##   make     (Callable) returns the Control to use as this entry (overrides icon/text)
##   action   (Callable)  pressed handler (optional)
##   px       (float)     button box size (optional; defaults to opts.px / DEFAULT_PX) — icon buttons only
##   enabled  (bool)      false → disabled (optional, default true)
##   visible  (bool)      false → hidden (optional, default true)
##   label    (String)    accessible/tooltip text (optional)
## opts (Dictionary, all optional):
##   px        (float)  default button box size for specs that omit px (default DEFAULT_PX)
##   side      (float)  left/right inset of the row (default SIDE_INSET)
##   bottom    (float)  extra px above the safe-bottom (default BOTTOM_MARGIN)
## Look/feel mirrors the board's painted-button look (btn_round.png + Look.add_press_juice). Lives in
## ui/ so scenes/ may import it; it must NOT reach up into scenes/ (the layering guard enforces this).

const Look = preload("res://engine/scripts/ui/skin.gd")

const DEFAULT_PX := 150.0
const SIDE_INSET := 32.0
const BOTTOM_MARGIN := 16.0

# Build the row, parent it to `host` (anchored bottom, full width), and return {row, buttons}.
static func build(host: Control, specs: Array, opts: Dictionary = {}) -> Dictionary:
	var def_px: float = float(opts.get("px", DEFAULT_PX))
	var side: float = float(opts.get("side", SIDE_INSET))
	var bottom: float = float(opts.get("bottom", BOTTOM_MARGIN))
	var sb_inset := Look.safe_bottom(host)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.anchor_left = 0.0
	row.anchor_right = 1.0
	row.anchor_top = 1.0
	row.anchor_bottom = 1.0
	row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	row.offset_left = side
	row.offset_right = -side
	row.offset_top = -bottom - sb_inset
	row.offset_bottom = -bottom - sb_inset
	var buttons: Array = []
	for i in specs.size():
		var spec: Dictionary = specs[i]
		# Three shapes: a custom `make` Callable, a PRIMARY TEXT pill (`text`), or the default round icon.
		var b: Control
		if spec.has("make") and (spec.make as Callable).is_valid():
			b = (spec.make as Callable).call()
		elif spec.has("text"):
			# the wide green CTA — the same solid grove primary pill the old "Tend the garden ▶" used.
			b = Look.button(String(spec.text), spec.get("action", Callable()), bool(spec.get("primary", true)))
		else:
			var px: float = float(spec.get("px", def_px))
			b = _make_nav_button(String(spec.get("icon", "")), px, spec.get("action", Callable()))
		if spec.has("label"):
			b.tooltip_text = String(spec.label)
		if b is Button:
			(b as Button).disabled = not bool(spec.get("enabled", true))
		b.visible = bool(spec.get("visible", true))
		if i > 0:
			row.add_child(_spacer())
		row.add_child(b)
		buttons.append(b)
	host.add_child(row)
	return {"row": row, "buttons": buttons}

# An expanding gap between two nav buttons — the full-width row distributes its leftover space
# equally across these so the buttons spread evenly edge to edge.
static func _spacer() -> Control:
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return sp

# One BIG painted nav button: the kit art (Look.kit("nav/" + kit_name)) centered full-rect, or a glyph icon
# fallback when the kit png is missing. Carries the press juice. The icon IGNOREs the mouse so the
# Button is the only hit surface (single-input-surface rule).
static func _make_nav_button(kit_name: String, px: float, cb: Callable) -> Button:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(px, px)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var p := Look.kit("nav/" + kit_name)
	var mark: Control
	if ResourceLoader.exists(p):
		var t := TextureRect.new()
		t.texture = load(p)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		mark = t
	else:
		mark = Look.icon(kit_name.trim_prefix("nav_").trim_suffix(".png"), px * 0.62)
	mark.set_anchors_preset(Control.PRESET_FULL_RECT)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(mark)
	Look.add_press_juice(b)
	if cb.is_valid():
		b.pressed.connect(cb)
	return b
