extends RefCounted
## Shared image tutorial modal: a dim veil, one fitted PNG, and a small close button.

const Overlay = preload("res://engine/scripts/ui/overlay.gd")

const INK := Color("#43352B")
const CREAM := Color("#F8E9D0")
const GOLD := Color("#E3B23C")

static func open(host: Control, overlay_name: String, image_path: String) -> Control:
	if host == null or not is_instance_valid(host):
		return null
	if Overlay.is_open(host, overlay_name):
		return host.get_node_or_null(NodePath(overlay_name)) as Control
	var tex := load(image_path) as Texture2D
	if tex == null:
		return null
	var overlay := Overlay.mount(host, overlay_name)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var vp := Vector2(720, 1280)
	if host.is_inside_tree():
		vp = host.get_viewport_rect().size
	if vp.x <= 0.0 or vp.y <= 0.0:
		vp = Vector2(720, 1280)

	var veil := Button.new()
	veil.name = "TutorialDismissVeil"
	veil.focus_mode = Control.FOCUS_NONE
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_style_button(veil, _box(Color(0.08, 0.05, 0.03, 0.62), Color(0, 0, 0, 0), 0, 0))
	veil.pressed.connect(func() -> void:
		if is_instance_valid(overlay):
			overlay.queue_free())
	overlay.add_child(veil)

	var center := CenterContainer.new()
	center.name = "TutorialImageCenter"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)

	var frame := PanelContainer.new()
	frame.name = "TutorialImageFrame"
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	frame.add_theme_stylebox_override("panel", _frame_style())
	center.add_child(frame)

	var fit := _fit_size(Vector2(tex.get_width(), tex.get_height()), Vector2(vp.x * 0.90, vp.y * 0.86))
	var art := TextureRect.new()
	art.name = "TutorialImageArt"
	art.texture = tex
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.custom_minimum_size = fit
	art.size = fit
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(art)

	var close_px := clampf(minf(vp.x, vp.y) * 0.07, 44.0, 62.0)
	var close := Button.new()
	close.name = "TutorialCloseButton"
	close.text = "X"
	close.tooltip_text = "Close"
	close.focus_mode = Control.FOCUS_NONE
	close.size = Vector2(close_px, close_px)
	close.position = Vector2(vp.x - close_px - maxf(16.0, vp.x * 0.035), maxf(16.0, vp.y * 0.035))
	close.add_theme_font_size_override("font_size", int(close_px * 0.45))
	close.add_theme_color_override("font_color", CREAM)
	close.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.20))
	close.add_theme_constant_override("outline_size", 1)
	_style_button(close, _box(INK, GOLD, 3, int(close_px * 0.5)))
	close.pressed.connect(func() -> void:
		if is_instance_valid(overlay):
			overlay.queue_free())
	overlay.add_child(close)
	return overlay

static func _fit_size(src: Vector2, bounds: Vector2) -> Vector2:
	if src.x <= 0.0 or src.y <= 0.0:
		return bounds
	var scale := minf(bounds.x / src.x, bounds.y / src.y)
	return Vector2(floorf(src.x * scale), floorf(src.y * scale))

static func _frame_style() -> StyleBoxFlat:
	var sb := _box(CREAM, GOLD, 4, 18)
	sb.content_margin_left = 8.0
	sb.content_margin_right = 8.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	sb.shadow_color = Color(0.09, 0.05, 0.03, 0.42)
	sb.shadow_size = 18
	sb.shadow_offset = Vector2(0, 8)
	return sb

static func _box(fill: Color, border: Color, border_w: int, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	return sb

static func _style_button(button: Button, style: StyleBoxFlat) -> void:
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, style)
