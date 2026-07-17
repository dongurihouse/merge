extends Control
## Standalone review surface for the modular cut-paper Home prototype.

const MANIFEST_PATH := "res://games/grove/assets/map/home_layered_cutpaper/home_props.json"

@onready var _backdrop: ColorRect = $Backdrop
@onready var _stage: Control = $Stage
@onready var _base: TextureRect = $Stage/HomeBase
@onready var _props: Control = $Stage/Props
@onready var _guides: Control = $Stage/Guides
@onready var _help: PanelContainer = $Help

var _manifest: Dictionary = {}
var _native_canvas := Vector2i(941, 1672)


func _ready() -> void:
	_backdrop.color = Color("#10213d")
	_help.visible = false
	reload_manifest()
	get_viewport().size_changed.connect(_fit_stage)


func reload_manifest() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if not parsed is Dictionary:
		push_error("Home layer workbench could not parse %s" % MANIFEST_PATH)
		return
	_manifest = parsed
	var canvas: Dictionary = _manifest.get("canvas", {})
	_native_canvas = Vector2i(int(canvas.get("width", 941)), int(canvas.get("height", 1672)))
	_stage.size = Vector2(_native_canvas)
	_base.size = Vector2(_native_canvas)
	_base.texture = load(String(_manifest.get("background", ""))) as Texture2D

	for child in _props.get_children():
		child.free()

	var guide_entries: Array = []
	for entry_variant in _manifest.get("props", []):
		if not entry_variant is Dictionary:
			continue
		var entry: Dictionary = entry_variant
		var prop := TextureRect.new()
		prop.name = String(entry.get("id", "Prop"))
		prop.texture = load(String(entry.get("texture", ""))) as Texture2D
		prop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		prop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		prop.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		prop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var raw_size: Array = entry.get("display_size", [100, 100])
		var raw_anchor: Array = entry.get("position", [0, 0])
		var display_size := Vector2(float(raw_size[0]), float(raw_size[1]))
		var anchor := Vector2(float(raw_anchor[0]), float(raw_anchor[1]))
		prop.size = display_size
		prop.position = anchor - Vector2(display_size.x * 0.5, display_size.y)
		prop.z_index = int(entry.get("sort_y", anchor.y))
		prop.set_meta("label", String(entry.get("label", prop.name)))
		prop.set_meta("anchor", anchor)
		_props.add_child(prop)
		guide_entries.append({"id": prop.name, "position": anchor, "size": display_size})

	_guides.set("entries", guide_entries)
	_guides.queue_redraw()
	_fit_stage()


func set_all_props_visible(visible_now: bool) -> void:
	for prop in _props.get_children():
		prop.visible = visible_now


func set_guides_visible(visible_now: bool) -> void:
	_guides.visible = visible_now


func prop_count() -> int:
	return _props.get_child_count()


func canvas_size() -> Vector2i:
	return _native_canvas


func set_only_prop_visible(prop_id: String) -> void:
	for prop in _props.get_children():
		prop.visible = String(prop.name) == prop_id


func _fit_stage() -> void:
	if not is_node_ready():
		return
	var available := size
	if available.x <= 0.0 or available.y <= 0.0:
		available = get_viewport_rect().size
	var native := Vector2(_native_canvas)
	var factor := minf(available.x / native.x, available.y / native.y)
	_stage.scale = Vector2.ONE * factor
	_stage.position = (available - native * factor) * 0.5


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7:
			_toggle_index(int(event.keycode - KEY_1))
		KEY_A:
			set_all_props_visible(true)
		KEY_N:
			set_all_props_visible(false)
		KEY_G:
			set_guides_visible(not _guides.visible)
		KEY_H:
			_help.visible = not _help.visible
		KEY_R:
			reload_manifest()


func _toggle_index(index: int) -> void:
	if index < 0 or index >= _props.get_child_count():
		return
	var prop := _props.get_child(index)
	prop.visible = not prop.visible
