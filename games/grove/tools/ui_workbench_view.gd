@tool
extends Control
## UI Workbench — gallery + inspector sidebar.
##
## `make workbench` opens this. The left column is a scroll of the fundamental components, built
## bottom-up from the self-contained kit (cost pill → mail card → mail dialog). CLICK an element to
## select it; the right SIDEBAR then shows that element's own options/sliders. Changing a slider
## rebuilds just that element — and because the components compose, a dialog's pill size still flows
## down into every row.

const Kit = preload("res://games/grove/tools/ui_workbench_kit.gd")
const UiFont = preload("res://engine/scripts/ui/ui_font.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const Pal = Game.PALETTE

const IDS := ["buy", "pill", "card", "dialog"]
const CAPTIONS := {
	"buy": "Buy button — green CTA",
	"pill": "Cost pill — cream atom",
	"card": "Mail card — pill + Claim",
	"dialog": "Mail dialog — cards",
}
# Per-element knob schema: [key, min, max]. The sidebar renders one slider per entry.
const SCHEMA := {
	"buy": [["font", 10, 60], ["icon", 12, 60], ["pad_x", 0, 60], ["pad_top", 0, 40], ["pad_bottom", 0, 40]],
	"pill": [["font", 10, 36], ["icon", 12, 48]],
	"card": [["pill_font", 10, 36], ["pill_icon", 12, 48], ["title", 12, 30], ["body", 10, 24]],
	"dialog": [["pill_font", 10, 36], ["pill_icon", 12, 48], ["width", 360, 720]],
}

var _params := {
	"buy": {"text": "250", "font": 26, "icon": 28, "pad_x": 16, "pad_top": 6, "pad_bottom": 7},
	"pill": {"font": 18, "icon": 24},
	"card": {"pill_font": 18, "pill_icon": 24, "title": 20, "body": 15},
	"dialog": {"pill_font": 18, "pill_icon": 24, "width": 560},
}
var _selected := "buy"
var _gallery: VBoxContainer = null
var _sidebar_body: VBoxContainer = null

func _ready() -> void:
	if Engine.is_editor_hint():
		theme = UiFont.make()
	_build()

func _build() -> void:
	if not is_inside_tree():
		return
	for c in get_children():
		remove_child(c)
		c.queue_free()

	var bg := ColorRect.new()
	bg.color = Pal.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var hb := HBoxContainer.new()
	hb.set_anchors_preset(Control.PRESET_FULL_RECT)
	hb.add_theme_constant_override("separation", 0)
	add_child(hb)

	# left — the gallery (scrolls; the dialog is tall)
	var gal_scroll := ScrollContainer.new()
	gal_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	gal_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gal_scroll.size_flags_vertical = Control.SIZE_FILL
	hb.add_child(gal_scroll)
	var gal_margin := MarginContainer.new()
	gal_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		gal_margin.add_theme_constant_override("margin_" + side, 24)
	gal_scroll.add_child(gal_margin)
	_gallery = VBoxContainer.new()
	_gallery.add_theme_constant_override("separation", 18)
	_gallery.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gal_margin.add_child(_gallery)

	# right — the options sidebar (fixed width)
	var side := PanelContainer.new()
	side.custom_minimum_size = Vector2(380, 0)
	side.size_flags_vertical = Control.SIZE_FILL
	var ssb := StyleBoxFlat.new()
	ssb.bg_color = Color(0, 0, 0, 0.42)
	ssb.border_width_left = 2
	ssb.border_color = Color(Pal.CREAM, 0.12)
	ssb.set_content_margin_all(18)
	side.add_theme_stylebox_override("panel", ssb)
	hb.add_child(side)
	var side_scroll := ScrollContainer.new()
	side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side.add_child(side_scroll)
	_sidebar_body = VBoxContainer.new()
	_sidebar_body.add_theme_constant_override("separation", 10)
	_sidebar_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_scroll.add_child(_sidebar_body)

	_rebuild_gallery()
	_rebuild_sidebar()

## Build the live element for an id from its current params.
func _make_element(id: String) -> Control:
	var p: Dictionary = _params[id]
	match id:
		"buy":
			return Kit.buy_pill(String(p.text), "gem", int(p.font), float(p.icon), float(p.pad_x), float(p.pad_top), float(p.pad_bottom))
		"pill":
			return Kit.cost_pill("gem", 50, int(p.font), float(p.icon))
		"card":
			return Kit.mail_card(Kit.DEMO_MAIL[0], int(p.pill_font), float(p.pill_icon), int(p.title), int(p.body))
		"dialog":
			return Kit.mail_dialog(Kit.DEMO_MAIL, int(p.pill_font), float(p.pill_icon), float(p.width))
	return Control.new()

## --- gallery (left) ------------------------------------------------------------------------------

func _rebuild_gallery() -> void:
	if _gallery == null or not is_instance_valid(_gallery):
		return
	for c in _gallery.get_children():
		_gallery.remove_child(c)
		c.queue_free()
	for id in IDS:
		_gallery.add_child(_section(id))

func _section(id: String) -> Control:
	var sec := PanelContainer.new()
	sec.add_theme_stylebox_override("panel", _section_style(id == _selected))
	sec.mouse_filter = Control.MOUSE_FILTER_STOP            # catches clicks on the non-button areas
	sec.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	sec.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sec.gui_input.connect(_on_section_input.bind(id))

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sec.add_child(v)
	var cap := Label.new()
	cap.text = ("●  " if id == _selected else "") + String(CAPTIONS[id])
	cap.add_theme_font_size_override("font_size", 15)
	cap.add_theme_color_override("font_color", Pal.STRAW if id == _selected else Color(Pal.CREAM, 0.8))
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(cap)
	var holder := CenterContainer.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var el := _make_element(id)
	_ignore_nonbuttons(el)
	holder.add_child(el)
	v.add_child(holder)
	return sec

## Make every non-button Control mouse-transparent, so a click anywhere on the section EXCEPT the
## inner buttons (Claim / ✕ / the buy pill) falls through to the section and selects it.
func _ignore_nonbuttons(n: Node) -> void:
	for c in n.get_children():
		if c is Control and not (c is BaseButton):
			(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ignore_nonbuttons(c)

func _on_section_input(ev: InputEvent, id: String) -> void:
	var hit: bool = (ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT)
	hit = hit or (ev is InputEventScreenTouch and (ev as InputEventScreenTouch).pressed)
	if hit:
		select(id)

func select(id: String) -> void:
	if id == _selected:
		return
	_selected = id
	# DEFER: select() runs inside a section's gui_input dispatch — rebuilding (freeing the very
	# section that is mid-emit) here would hit "Object is locked and can't be freed". Defer so the
	# tree is mutated only after the input dispatch returns.
	_rebuild_gallery.call_deferred()      # refresh the selection highlight
	_rebuild_sidebar.call_deferred()      # swap in this element's options

func _section_style(selected: bool) -> StyleBox:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(14)
	if selected:
		sb.bg_color = Color(1, 1, 1, 0.05)
		sb.set_border_width_all(2)
		sb.border_color = Pal.STRAW
	else:
		sb.bg_color = Color(0, 0, 0, 0.22)
		sb.set_border_width_all(1)
		sb.border_color = Color(Pal.CREAM, 0.1)
	return sb

## --- sidebar (right) -----------------------------------------------------------------------------

func _rebuild_sidebar() -> void:
	if _sidebar_body == null or not is_instance_valid(_sidebar_body):
		return
	for c in _sidebar_body.get_children():
		_sidebar_body.remove_child(c)
		c.queue_free()
	var head := Label.new()
	head.text = "Options"
	head.add_theme_font_size_override("font_size", 26)
	_sidebar_body.add_child(head)
	var sub := Label.new()
	sub.text = String(CAPTIONS[_selected])
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", Color(Pal.CREAM, 0.65))
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sidebar_body.add_child(sub)
	_sidebar_body.add_child(HSeparator.new())

	if _selected == "buy":
		_sidebar_body.add_child(_text_row("Price text", "text"))
	for spec in SCHEMA[_selected]:
		_sidebar_body.add_child(_slider_row(spec))

func _slider_row(spec: Array) -> Control:
	var key: String = spec[0]
	var lo: float = float(spec[1])
	var hi: float = float(spec[2])
	var params: Dictionary = _params[_selected]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var lbl := Label.new()
	lbl.text = key.replace("_", " ").capitalize()
	lbl.custom_minimum_size = Vector2(118, 0)
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(lbl)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 1
	s.value = float(params[key])
	s.custom_minimum_size = Vector2(0, 28)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(s)
	var val := Label.new()
	val.text = "%d" % int(params[key])
	val.custom_minimum_size = Vector2(44, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(val)
	s.value_changed.connect(func(x: float) -> void:
		params[key] = x
		val.text = "%d" % int(x)
		_rebuild_gallery())
	return row

func _text_row(label: String, key: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var lbl := Label.new()
	lbl.text = label
	lbl.custom_minimum_size = Vector2(118, 0)
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(lbl)
	var le := LineEdit.new()
	le.text = String(_params[_selected].get(key, ""))
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	le.text_changed.connect(func(t: String) -> void:
		_params[_selected][key] = t
		_rebuild_gallery())
	row.add_child(le)
	return row
