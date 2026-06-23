extends Control

const ButtonPreview := preload("res://games/tools/button_shadow_tool/button_preview.gd")

var preview: Control
var value_labels: Dictionary = {}

func _ready() -> void:
	custom_minimum_size = Vector2(1120.0, 560.0)
	_build_ui()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#5DB3E4")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var row := HBoxContainer.new()
	row.name = "RootRow"
	row.position = Vector2(24.0, 24.0)
	row.size = Vector2(1070.0, 512.0)
	row.add_theme_constant_override("separation", 26)
	add_child(row)

	preview = ButtonPreview.new()
	preview.name = "ButtonPreview"
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(preview)

	var panel := PanelContainer.new()
	panel.name = "ShadowControls"
	panel.custom_minimum_size = Vector2(320.0, 0.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#FFF1D2", 0.94)
	style.border_color = Color("#B9853E", 0.55)
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", style)
	row.add_child(panel)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 9)
	panel.add_child(stack)

	var title := Label.new()
	title.text = "Button Shadow"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("#3A2012"))
	stack.add_child(title)

	_add_slider(stack, "OffsetX", "Offset X", "offset_x", -26.0, 26.0, 1.0)
	_add_slider(stack, "OffsetY", "Offset Y", "offset_y", -8.0, 34.0, 1.0)
	_add_slider(stack, "Blur", "Blur", "blur", 0.0, 38.0, 1.0)
	_add_slider(stack, "Spread", "Spread", "spread", -8.0, 18.0, 1.0)
	_add_slider(stack, "Alpha", "Alpha", "alpha", 0.0, 0.85, 0.01)
	_add_slider(stack, "Warmth", "Warmth", "warmth", 0.0, 1.0, 0.01)
	_add_slider(stack, "InnerHighlight", "Inner light", "inner_highlight", 0.0, 1.0, 0.01)

	var reset := Button.new()
	reset.text = "Reference-ish Reset"
	reset.pressed.connect(_reset_reference)
	stack.add_child(reset)

func _add_slider(parent: VBoxContainer, node_name: String, label_text: String, key: String, min_value: float, max_value: float, step: float) -> void:
	var label_row := HBoxContainer.new()
	label_row.add_theme_constant_override("separation", 8)
	parent.add_child(label_row)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(118.0, 0.0)
	label.add_theme_color_override("font_color", Color("#3A2012"))
	label_row.add_child(label)

	var value := Label.new()
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.add_theme_color_override("font_color", Color("#5C3219"))
	label_row.add_child(value)
	value_labels[node_name] = value

	var slider := HSlider.new()
	slider.name = node_name
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = float(preview.call("get_shadow_settings").get(key, 0.0))
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(slider)

	_set_value_label(node_name, slider.value)
	slider.value_changed.connect(func(v: float) -> void:
		preview.call("set_shadow_setting", key, v)
		_set_value_label(node_name, v)
	)

func _set_value_label(node_name: String, value: float) -> void:
	var label := value_labels.get(node_name) as Label
	if label == null:
		return
	label.text = "%.2f" % value if absf(value - roundf(value)) > 0.001 else "%d" % int(roundf(value))

func _reset_reference() -> void:
	var defaults := {
		"OffsetX": 0.0,
		"OffsetY": 10.0,
		"Blur": 14.0,
		"Spread": 4.0,
		"Alpha": 0.34,
		"Warmth": 0.82,
		"InnerHighlight": 0.78,
	}
	for node_name in defaults:
		var slider := find_child(String(node_name), true, false) as HSlider
		if slider != null:
			slider.value = float(defaults[node_name])
			slider.value_changed.emit(slider.value)
