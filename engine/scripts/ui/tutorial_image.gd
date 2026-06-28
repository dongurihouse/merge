extends RefCounted
## Shared image tutorial modal: full-screen art; tap anywhere to dismiss.

const Overlay = preload("res://engine/scripts/ui/overlay.gd")

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

	var art := TextureRect.new()
	art.name = "TutorialImageArt"
	art.texture = tex
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(art)

	var hit := Button.new()
	hit.name = "TutorialDismissHitArea"
	hit.focus_mode = Control.FOCUS_NONE
	hit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hit.mouse_filter = Control.MOUSE_FILTER_STOP
	_style_button(hit, StyleBoxEmpty.new())
	hit.pressed.connect(func() -> void:
		if is_instance_valid(overlay):
			overlay.queue_free())
	overlay.add_child(hit)
	return overlay

static func _style_button(button: Button, style: StyleBox) -> void:
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, style)
