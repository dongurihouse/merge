extends Control
## STANDALONE farm placement editor. Self-contained — no game/save imports. The farm base
## fills the screen; chrome stays OUT of the way: status lives in the WINDOW TITLE (no on-screen
## bar), and the only overlay is a narrow, toggleable palette strip on the left.
##
## Controls — Tab: show/hide palette · click a palette item to add it · drag to move ·
## wheel or +/- : scale selected · Delete: remove selected · Ctrl+S: save · Ctrl+L: load.
## Save writes data/test_farm_placements.json (item center as a fraction of the background +
## a scale) so a layout made once is correct on any screen.
##
## Run (born focusable so you can drag):
##   godot --path . res://engine/scenes/TestFarm.tscn

const CUTOUTS_DIR := "res://assets/map1/cutouts/"
const SAVE_PATH := "res://data/test_farm_placements.json"
const SKIP := ["cottage_broken"]   # only the good cottage is placeable
const HINT := "Tab palette · drag move · wheel/+- scale · Del remove · Ctrl+S save"

var _bg: TextureRect
var _items_layer: Control
var _palette: PanelContainer
var _selected: Control = null
var _drag_off := Vector2.ZERO
var _dragging := false


func _ready() -> void:
	_bg = $Background
	_build_items_layer()
	_build_palette()
	_set_info("")
	await get_tree().process_frame
	_load()


func _set_info(text: String) -> void:
	var t := "Farm placement — " + HINT
	if text != "":
		t = "Farm placement — " + text
	DisplayServer.window_set_title(t)


func _bg_size() -> Vector2:
	var s := _bg.size
	if s.x <= 0.0 or s.y <= 0.0:
		return get_viewport_rect().size
	return s


# --- scene scaffolding -------------------------------------------------------

func _build_items_layer() -> void:
	_items_layer = Control.new()
	_items_layer.name = "Items"
	_items_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_items_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE   # clicks pass through to placed items
	add_child(_items_layer)


func _build_palette() -> void:
	_palette = PanelContainer.new()
	_palette.name = "Palette"
	_palette.position = Vector2(12, 12)
	_palette.custom_minimum_size = Vector2(150, 0)
	_palette.modulate = Color(1, 1, 1, 0.92)   # slight transparency so the farm reads behind it
	add_child(_palette)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(150, min(get_viewport_rect().size.y - 24, 1100))
	_palette.add_child(scroll)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	scroll.add_child(vb)

	var save_btn := Button.new()
	save_btn.text = "💾 Save"
	save_btn.pressed.connect(_save)
	vb.add_child(save_btn)

	var load_btn := Button.new()
	load_btn.text = "↻ Load"
	load_btn.pressed.connect(_load)
	vb.add_child(load_btn)

	vb.add_child(HSeparator.new())

	for item_name in _cutout_names():
		var tex := _load_cutout(item_name)
		if tex == null:
			continue
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(132, 84)
		btn.icon = tex
		btn.expand_icon = true
		btn.text = item_name
		btn.add_theme_font_size_override("font_size", 13)
		btn.tooltip_text = "Add %s" % item_name
		btn.pressed.connect(_spawn.bind(item_name))
		vb.add_child(btn)


# --- cutout discovery --------------------------------------------------------

func _cutout_names() -> Array:
	var out := []
	var d := DirAccess.open(CUTOUTS_DIR)
	if d == null:
		push_error("Cannot open %s" % CUTOUTS_DIR)
		return out
	for f in d.get_files():
		if not f.ends_with(".png"):
			continue
		var n := f.get_basename()
		if n in SKIP:
			continue
		out.append(n)
	out.sort()
	return out


func _load_cutout(item_name: String) -> Texture2D:
	var path := CUTOUTS_DIR + item_name + ".png"
	if not ResourceLoader.exists(path):
		return null
	return load(path)


# --- placed items ------------------------------------------------------------

func _spawn(item_name: String) -> Control:
	var tex := _load_cutout(item_name)
	if tex == null:
		return null
	var item := TextureRect.new()
	item.texture = tex
	item.set_meta("item", item_name)
	item.size = tex.get_size()
	item.pivot_offset = item.size * 0.5
	item.mouse_filter = Control.MOUSE_FILTER_STOP
	item.gui_input.connect(_on_item_input.bind(item))
	_items_layer.add_child(item)
	_set_center(item, _bg_size() * 0.5)   # spawn centered on the farm
	_select(item)
	return item


func _set_center(item: Control, center: Vector2) -> void:
	item.position = center - item.pivot_offset


func _center_of(item: Control) -> Vector2:
	return item.position + item.pivot_offset


func _select(item: Control) -> void:
	if _selected and is_instance_valid(_selected):
		_selected.modulate = Color.WHITE
	_selected = item
	if item:
		item.modulate = Color(1.0, 1.0, 0.7)   # warm tint marks the selection
		_set_info("%s · scale %.2f · (%.3f, %.3f)" % [
			item.get_meta("item"), item.scale.x,
			_center_of(item).x / _bg_size().x, _center_of(item).y / _bg_size().y])


func _on_item_input(ev: InputEvent, item: Control) -> void:
	if ev is InputEventMouseButton:
		if ev.button_index == MOUSE_BUTTON_LEFT:
			if ev.pressed:
				_select(item)
				_dragging = true
				_drag_off = item.get_global_mouse_position() - _center_of(item)
			else:
				_dragging = false
		elif ev.button_index == MOUSE_BUTTON_WHEEL_UP and ev.pressed:
			_scale_item(item, 1.05)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN and ev.pressed:
			_scale_item(item, 1.0 / 1.05)
	elif ev is InputEventMouseMotion and _dragging and item == _selected:
		_set_center(item, item.get_global_mouse_position() - _drag_off)
		_select(item)   # refresh readout


func _scale_item(item: Control, factor: float) -> void:
	var c := _center_of(item)
	item.scale = (item.scale * factor).clamp(Vector2(0.05, 0.05), Vector2(10, 10))
	_set_center(item, c)   # keep visual center fixed while scaling
	_select(item)


func _unhandled_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey and ev.pressed):
		return
	# global shortcuts (work with nothing selected)
	if ev.keycode == KEY_TAB:
		_palette.visible = not _palette.visible
		get_viewport().set_input_as_handled()
		return
	if ev.ctrl_pressed or ev.meta_pressed:
		if ev.keycode == KEY_S:
			_save()
			get_viewport().set_input_as_handled()
			return
		if ev.keycode == KEY_L:
			_load()
			get_viewport().set_input_as_handled()
			return
	# selection-scoped shortcuts
	if _selected == null or not is_instance_valid(_selected):
		return
	match ev.keycode:
		KEY_DELETE, KEY_BACKSPACE:
			_selected.queue_free()
			_selected = null
			_set_info("removed")
		KEY_EQUAL, KEY_KP_ADD:
			_scale_item(_selected, 1.05)
		KEY_MINUS, KEY_KP_SUBTRACT:
			_scale_item(_selected, 1.0 / 1.05)


# --- persistence -------------------------------------------------------------

func _abs_save_path() -> String:
	var p := ProjectSettings.globalize_path(SAVE_PATH)
	DirAccess.make_dir_recursive_absolute(p.get_base_dir())   # data/ was deleted — recreate it
	return p


func _save() -> void:
	var bg := _bg_size()
	var placed := []
	for item in _items_layer.get_children():
		var c := _center_of(item)
		placed.append({
			"item": item.get_meta("item"),
			"pos": [c.x / bg.x, c.y / bg.y],
			"scale": item.scale.x,
		})
	var f := FileAccess.open(_abs_save_path(), FileAccess.WRITE)
	if f == null:
		push_error("Cannot write %s" % SAVE_PATH)
		_set_info("SAVE FAILED")
		return
	f.store_string(JSON.stringify({"items": placed}, "\t"))
	f.close()
	_set_info("saved %d item(s)" % placed.size())


func _load() -> void:
	for item in _items_layer.get_children():
		item.queue_free()
	_selected = null
	var p := ProjectSettings.globalize_path(SAVE_PATH)
	if not FileAccess.file_exists(p):
		return
	var f := FileAccess.open(p, FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(data) != TYPE_DICTIONARY or not data.has("items"):
		return
	var bg := _bg_size()
	for rec in data["items"]:
		var item := _spawn(String(rec.get("item", "")))
		if item == null:
			continue
		item.scale = Vector2.ONE * float(rec.get("scale", 1.0))
		var pos = rec.get("pos", [0.5, 0.5])
		_set_center(item, Vector2(float(pos[0]) * bg.x, float(pos[1]) * bg.y))
	_select(null)
	_set_info("loaded %d item(s)" % data["items"].size())
