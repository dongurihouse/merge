@tool
extends Control
## UI Workbench — a self-contained tool window.
##
## `make workbench` opens this: the REAL shop buy-button in a preview area, with a panel of
## on-screen sliders that resize it LIVE. No editor needed. (It also still works as a @tool scene
## opened in the editor — there the same knobs appear in the Inspector instead.)
##
## The knobs default to the live Tune.Shop values, so it opens showing exactly what the game ships.
## They are an EXPERIMENT surface — tuning.gd stays the single source of truth. Hit "Copy values →
## tuning.gd" to drop a copy-paste block on the clipboard (and the console); paste it into
## engine/scripts/core/tuning.gd (class Shop) so the GAME picks up the new size.

const Look = preload("res://engine/scripts/ui/skin.gd")
const UiFont = preload("res://engine/scripts/ui/ui_font.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const TuneShop = preload("res://engine/scripts/core/tuning.gd").Shop
const Pal = Game.PALETTE

@export_group("Size")
@export var font_size: int = TuneShop.BUY_SIZE:
	set(v): font_size = v; _refresh_preview()
@export var icon_size: float = TuneShop.PRICE_ICON:
	set(v): icon_size = v; _refresh_preview()
@export var pad_x: float = TuneShop.BUY_PAD_X:
	set(v): pad_x = v; _refresh_preview()
@export var pad_top: float = TuneShop.BUY_PAD_T:
	set(v): pad_top = v; _refresh_preview()
@export var pad_bottom: float = TuneShop.BUY_PAD_B:
	set(v): pad_bottom = v; _refresh_preview()
@export_group("Content")
@export var price_text: String = "250":
	set(v): price_text = v; _refresh_preview()

var _preview_host: Control = null   # only this subtree rebuilds on a knob change; the slider panel persists

func _ready() -> void:
	if Engine.is_editor_hint():
		theme = UiFont.make()      # scope the cozy face to THIS preview — never the global editor theme
	_build()

## Build the static layout ONCE: the dark stage, the slider panel (runtime only), and the preview
## area. Knob changes only refresh the preview, so sliders keep their grab/focus.
func _build() -> void:
	if not is_inside_tree():
		return
	for c in get_children():
		remove_child(c)
		c.free()

	var bg := ColorRect.new()
	bg.color = Pal.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 0)
	add_child(col)

	# In the editor the knobs live in the Inspector, so we skip the on-screen panel there (and just
	# show the centered preview). At runtime (`make workbench`) the slider panel is the whole point.
	if not Engine.is_editor_hint():
		col.add_child(_controls_panel())

	var preview := CenterContainer.new()
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(preview)
	_preview_host = preview
	_refresh_preview()

## Tear down + rebuild ONLY the button from the current knobs.
func _refresh_preview() -> void:
	if _preview_host == null or not is_instance_valid(_preview_host):
		return
	for c in _preview_host.get_children():
		_preview_host.remove_child(c)
		c.free()
	_preview_host.add_child(_buy_button())

## The single shop-style buy button, composed from the REAL kit (kit/shop_buy.png capsule + the
## acorn currency icon + the price text), sized by the current knobs.
func _buy_button() -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.text = price_text
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", Pal.CREAM)
	b.add_theme_color_override("font_pressed_color", Pal.CREAM)
	b.add_theme_color_override("font_hover_color", Pal.CREAM)
	b.add_theme_constant_override("outline_size", 0)
	b.add_theme_constant_override("icon_max_width", int(icon_size))
	b.add_theme_constant_override("h_separation", TuneShop.PRICE_ROW_SEP)

	var ipath := Game.art("ui/currency/icon_gem.png")   # the acorn (premium-currency mark)
	if ResourceLoader.exists(ipath):
		b.icon = load(ipath)

	# the background — the real sliced green capsule; code-drawn fallback keeps it working pre-slice
	var box := Look.kit_box("kit/shop_buy.png", TuneShop.BUY_TEX_MARGIN,
		Vector4(pad_x, pad_top, pad_x, pad_bottom))
	if box != null:
		b.add_theme_stylebox_override("normal", box)
		b.add_theme_stylebox_override("hover", box)
		var bp: StyleBoxTexture = box.duplicate()
		bp.modulate_color = Color(0.92, 0.92, 0.92)     # press darken
		b.add_theme_stylebox_override("pressed", bp)
	else:
		var s := StyleBoxFlat.new()
		s.bg_color = Pal.BTN_PRIMARY
		s.border_color = Pal.BTN_PRIMARY_EDGE
		s.set_corner_radius_all(TuneShop.BUY_RADIUS)
		s.set_border_width_all(2)
		s.content_margin_left = pad_x
		s.content_margin_right = pad_x
		s.content_margin_top = pad_top
		s.content_margin_bottom = pad_bottom
		b.add_theme_stylebox_override("normal", s)
		b.add_theme_stylebox_override("hover", s)

	if not Engine.is_editor_hint():
		b.pressed.connect(func() -> void: print("WORKBENCH: buy pressed"))
	return b

## --- the on-screen control panel (runtime) -------------------------------------------------------

func _controls_panel() -> Control:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.35)
	sb.set_content_margin_all(20)
	sb.set_corner_radius_all(0)
	panel.add_theme_stylebox_override("panel", sb)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)

	var title := Label.new()
	title.text = "UI Workbench · shop buy button"
	title.add_theme_font_size_override("font_size", 30)
	v.add_child(title)

	v.add_child(_slider_row("Font size", font_size, 10, 60, 1, func(x: float) -> void: font_size = int(x)))
	v.add_child(_slider_row("Icon size", icon_size, 10, 60, 1, func(x: float) -> void: icon_size = x))
	v.add_child(_slider_row("Pad X", pad_x, 0, 60, 1, func(x: float) -> void: pad_x = x))
	v.add_child(_slider_row("Pad top", pad_top, 0, 40, 1, func(x: float) -> void: pad_top = x))
	v.add_child(_slider_row("Pad bottom", pad_bottom, 0, 40, 1, func(x: float) -> void: pad_bottom = x))

	var price_row := HBoxContainer.new()
	price_row.add_theme_constant_override("separation", 14)
	var pl := Label.new()
	pl.text = "Price text"
	pl.custom_minimum_size = Vector2(180, 0)
	price_row.add_child(pl)
	var le := LineEdit.new()
	le.text = price_text
	le.custom_minimum_size = Vector2(220, 0)
	le.text_changed.connect(func(t: String) -> void: price_text = t)
	price_row.add_child(le)
	v.add_child(price_row)

	var copy := Button.new()
	copy.text = "Copy values → tuning.gd"
	copy.add_theme_font_size_override("font_size", 24)
	copy.pressed.connect(_copy_values)
	v.add_child(copy)
	return panel

## One labelled slider row: [ label | slider | value ]. Sets the value BEFORE connecting, so building
## the row never fires a refresh; the handler updates the readout and pushes the value into the knob.
func _slider_row(label: String, value: float, lo: float, hi: float, step: float, on_change: Callable) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var lbl := Label.new()
	lbl.text = label
	lbl.custom_minimum_size = Vector2(180, 0)
	row.add_child(lbl)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(360, 30)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(s)
	var val := Label.new()
	val.text = "%d" % value
	val.custom_minimum_size = Vector2(64, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(val)
	s.value_changed.connect(func(x: float) -> void:
		val.text = "%d" % x
		on_change.call(x))
	return row

## Put the current knobs on the clipboard (and the console) as a tuning.gd → class Shop block.
func _copy_values() -> void:
	var block := "# --- ui_workbench: paste into engine/scripts/core/tuning.gd → class Shop ---\n"
	block += "const BUY_SIZE := %d\n" % font_size
	block += "const PRICE_ICON := %s\n" % str(icon_size)
	block += "const BUY_PAD_X := %s\n" % str(pad_x)
	block += "const BUY_PAD_T := %s\n" % str(pad_top)
	block += "const BUY_PAD_B := %s\n" % str(pad_bottom)
	DisplayServer.clipboard_set(block)
	print("\n" + block + "# (copied to clipboard)\n")
