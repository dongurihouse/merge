@tool
extends Control
## UI Workbench — the gallery.
##
## `make workbench` opens this: a scroll of the fundamental components, built bottom-up from the
## self-contained kit (ui_workbench_kit.gd) so composition is visible —
##   cost pill (atom)  →  mail card (uses the pill + Claim)  →  mail dialog (uses the cards).
##
## The two sliders at the top size the COST PILL, and that size flows DOWN through the card and
## every dialog row — drag one and watch the pill change everywhere at once. That's the "previous
## things feed into the next automatically" the composition is built to give.

const Kit = preload("res://games/grove/tools/ui_workbench_kit.gd")
const UiFont = preload("res://engine/scripts/ui/ui_font.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const Pal = Game.PALETTE

@export var pill_font: int = 18:
	set(v): pill_font = v; _rebuild_gallery()
@export var pill_icon: float = 24.0:
	set(v): pill_icon = v; _rebuild_gallery()

var _gallery: VBoxContainer = null

func _ready() -> void:
	if Engine.is_editor_hint():
		theme = UiFont.make()
	_build()

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

	if not Engine.is_editor_hint():
		col.add_child(_controls_panel())

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	scroll.add_child(margin)

	_gallery = VBoxContainer.new()
	_gallery.add_theme_constant_override("separation", 30)
	_gallery.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(_gallery)
	_rebuild_gallery()

## Rebuild ONLY the gallery sections (the slider panel persists). Every section re-runs its kit
## builder with the current pill knobs, so a knob change propagates through pill → card → dialog.
func _rebuild_gallery() -> void:
	if _gallery == null or not is_instance_valid(_gallery):
		return
	for c in _gallery.get_children():
		_gallery.remove_child(c)
		c.free()
	_gallery.add_child(_section("Buy button — green CTA (kit/shop_buy.png)", Kit.buy_pill("250", "gem")))
	_gallery.add_child(_section("Cost pill — cream atom (kit/mail_pill_cream.png)", Kit.cost_pill("gem", 50, pill_font, pill_icon)))
	_gallery.add_child(_section("Mail card — composes the cost pill + Claim", Kit.mail_card(Kit.DEMO_MAIL[0], pill_font, pill_icon)))
	_gallery.add_child(_section("Mail dialog — composes the mail cards", Kit.mail_dialog(Kit.DEMO_MAIL, pill_font, pill_icon)))

## One gallery section: a caption over the live element, centered.
func _section(caption: String, element: Control) -> Control:
	var sec := VBoxContainer.new()
	sec.add_theme_constant_override("separation", 8)
	sec.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lbl := Label.new()
	lbl.text = caption
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color(Pal.CREAM, 0.85))
	sec.add_child(lbl)
	var holder := CenterContainer.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.add_child(element)
	sec.add_child(holder)
	return sec

## --- the shared pill-size controls (runtime) -----------------------------------------------------

func _controls_panel() -> Control:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.35)
	sb.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var title := Label.new()
	title.text = "UI Workbench · cost-pill size flows into the card + dialog"
	title.add_theme_font_size_override("font_size", 26)
	v.add_child(title)
	v.add_child(_slider_row("Pill font", pill_font, 10, 36, 1, func(x: float) -> void: pill_font = int(x)))
	v.add_child(_slider_row("Pill icon", pill_icon, 12, 48, 1, func(x: float) -> void: pill_icon = x))
	return panel

func _slider_row(label: String, value: float, lo: float, hi: float, step: float, on_change: Callable) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var lbl := Label.new()
	lbl.text = label
	lbl.custom_minimum_size = Vector2(170, 0)
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
	val.custom_minimum_size = Vector2(60, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(val)
	s.value_changed.connect(func(x: float) -> void:
		val.text = "%d" % x
		on_change.call(x))
	return row
