extends RefCounted
## Blocking in-game wait sheet shown after a real-money Confirm tap while StoreKit
## requests products and opens the native App Store purchase sheet.

const Game = preload("res://engine/scripts/core/game.gd")
const Overlay = preload("res://engine/scripts/ui/overlay.gd")
const FS = preload("res://engine/scripts/core/tuning.gd").FontScale

const INK := Game.PALETTE.INK
const BARK := Game.PALETTE.BARK
const STRAW := Game.PALETTE.STRAW
const OVERLAY_NAME := "PurchaseWaitOverlay"
const SPINNER_FRAMES := [".", "..", "..."]
const KIT_PATH := "res://games/grove/tools/ui_workbench_kit.gd"

static func show(host: Control, title: String, message: String) -> Control:
	if host == null:
		return null
	var existing := host.get_node_or_null(NodePath(OVERLAY_NAME))
	if existing is Control and not existing.is_queued_for_deletion():
		return existing

	var overlay := Overlay.mount(host, OVERLAY_NAME, Overlay.MODAL_TOP_Z)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var veil := ColorRect.new()
	veil.color = Color(INK, 0.56)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(veil)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 12)

	var Kit: GDScript = load(KIT_PATH)
	var plain: Font = Kit.plain_font()

	var spinner := Label.new()
	spinner.name = "PurchaseWaitSpinner"
	spinner.text = SPINNER_FRAMES[0]
	spinner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	spinner.add_theme_font_override("font", plain)
	spinner.add_theme_constant_override("outline_size", 0)
	spinner.add_theme_font_size_override("font_size", FS.pct(95))
	spinner.add_theme_color_override("font_color", STRAW)
	col.add_child(spinner)
	_start_spinner(spinner, overlay)

	var body := Label.new()
	body.name = "PurchaseWaitMessage"
	body.text = message
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(360, 0)
	body.add_theme_font_override("font", plain)
	body.add_theme_constant_override("outline_size", 0)
	body.add_theme_font_size_override("font_size", FS.FOOTNOTE)
	body.add_theme_color_override("font_color", BARK)
	col.add_child(body)

	var cfg: Dictionary = Kit.load_config(Kit.CONFIG_PATH)
	var opts: Dictionary = Kit.dialog_opts_from_config(cfg)
	opts["content_scale"] = Kit.dialog_content_scale(cfg, "dialog")
	opts["banner_text"] = title
	opts["banner_icon_on"] = false
	opts["center_content"] = true
	opts["on_close"] = func() -> void: overlay.queue_free()
	var vp := host.get_viewport()
	var vw: float = vp.get_visible_rect().size.x if vp != null else 1080.0
	var width: float = maxf(1.0, vw) * Kit.DIALOG_DESIGN_PCT["dialog"] / 100.0
	center.add_child(Kit.dialog_frame(col, width, opts))

	return overlay

static func close(overlay: Control) -> void:
	if overlay != null and is_instance_valid(overlay):
		overlay.queue_free()

static func _start_spinner(label: Label, overlay: Control) -> void:
	var timer := Timer.new()
	timer.wait_time = 0.18
	timer.autostart = true
	timer.timeout.connect(func() -> void:
		if label == null or not is_instance_valid(label):
			timer.stop()
			return
		var frame := (int(label.get_meta("spinner_frame", 0)) + 1) % SPINNER_FRAMES.size()
		label.set_meta("spinner_frame", frame)
		label.text = SPINNER_FRAMES[frame])
	overlay.add_child(timer)
