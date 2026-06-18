extends Control
## Map-1 BUILDING placer (dev tool). Background = base_empty. The hub buildings (house/shed/…) load at
## their saved positions; drag to move, wheel / +- to resize, Ctrl+S writes assets/map1v2/items_layout.json
## — the file the grove merges into the hub spots at load. The fence renders behind for context.
##
## Controls — F reference · drag move · wheel/+- scale · right-click selects from list · Ctrl+S save.
## Run:  make place   (or: godot --path . res://games/grove/tools/MapPlacer.tscn)
##
## The window is WIDER than the game's portrait view. The central "stage" IS the real game view (design
## 1080×1920); the extra width on each side is gutter space to work the controls in. Two bright lines mark
## the edges of the player's view, and the off-view gutters are dimmed — anything past the lines is cropped
## in-game exactly as it is here.

const Design = preload("res://engine/scripts/core/design.gd")

const ITEMS_DIR := "res://games/grove/assets/map1v2/items/"
const ITEMS_LAYOUT := "res://games/grove/assets/map1v2/items_layout.json"
const FENCE_PATH := "res://games/grove/assets/map1v2/fence.png"
const FULL_PATH := "res://games/grove/assets/map1v2/base_full.png"
const HINT := "drag · wheel scale · F reference · Ctrl+S save"

const WINDOW_WIDTH_MULT := 2.6      # tool window width = this × the game-view width (capped to the screen)
const LINE_W := 4.0                 # thickness of each view-edge line (design px)
const LINE_COLOR := Color(0.25, 0.95, 1.0, 0.95)   # bright cyan — reads clearly over the art
const GUTTER_SHADE := Color(0.0, 0.0, 0.0, 0.32)   # dim the off-view gutters so the play area pops

var _stage: Control          # the game-view region (design 1080×1920), centered in the wider window
var _bg: TextureRect
var _fence_layer: Control    # the fence — smallest z (bottom of the stack, below the buildings)
var _buildings: Control      # the house/shed/… — the placeable hub items
var _zlist: PanelContainer   # right-gutter list of every item by z
var _zlist_box: VBoxContainer
var _full: TextureRect
var _bounds: Control         # the two view-edge lines + dimmed gutters (overlay, non-interactive)
var _line_l: ColorRect
var _line_r: ColorRect
var _shade_l: ColorRect
var _shade_r: ColorRect
var _selected: Control = null
var _drag_off := Vector2.ZERO
var _dragging := false
var _buildings_moved := false  # a building was dragged/scaled → Ctrl+S rewrites items_layout.json


func _ready() -> void:
	_fit_tool_window()                 # wider than the game window → side gutters for the controls
	await get_tree().process_frame     # let the resize settle so the viewport size is final
	_build_stage()                     # central game-view region; the .tscn Background moves inside it
	# the z-stack, bottom→top: fence · buildings (created in that order)
	_fence_layer = _make_item_layer("Fence")
	_buildings = _make_item_layer("Buildings")
	_populate_fence()
	_populate_buildings()
	_build_full_overlay()
	_build_bounds()                    # the two "edge of the player's view" lines + dimmed gutters
	_build_zlist()                     # right-gutter z-order readout
	get_viewport().size_changed.connect(_on_viewport_resized)
	_set_info("")


func _set_info(text: String) -> void:
	DisplayServer.window_set_title("Building placer — " + (text if text != "" else HINT))


func _bg_size() -> Vector2:
	# The authoritative game-view region. Every placed item's saved position is a fraction of THIS, so it
	# stays identical to before even though the window is now wider than the view.
	return _stage.size if _stage else Design.size()


# --- window + game-view stage -------------------------------------------------

# Like Design.fit_desktop_window(), but WIDER: full monitor height, width up to WINDOW_WIDTH_MULT× the
# game's portrait width (capped to the screen), centered. The extra width becomes side gutters to work in.
func _fit_tool_window() -> void:
	if OS.has_feature("mobile") or OS.get_environment("TU_QUIET") == "1":
		return
	var scr := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	if scr.size.y <= 0:
		return
	var deco_y: int = maxi(0, DisplayServer.window_get_size_with_decorations().y - DisplayServer.window_get_size().y)
	var h: float = float(scr.size.y - deco_y)
	var stage_w: float = h * Design.aspect()
	var w: float = minf(stage_w * WINDOW_WIDTH_MULT, float(scr.size.x))
	DisplayServer.window_set_size(Vector2i(roundi(w), roundi(h)))
	DisplayServer.window_set_position(Vector2i(int(scr.position.x + (float(scr.size.x) - w) / 2.0), scr.position.y))


# The game-view region: a design-sized (1080×1920) Control centered in the wider window. The .tscn
# Background moves inside it so the base art renders ONLY where the player will see it, and the stage
# clips its children — items dragged past an edge vanish exactly as the game crops them.
func _build_stage() -> void:
	_stage = Control.new()
	_stage.name = "Stage"
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.clip_contents = true
	add_child(_stage)
	_bg = $Background
	_bg.get_parent().remove_child(_bg)
	_stage.add_child(_bg)
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layout_stage()


func _layout_stage() -> void:
	var vp := get_viewport_rect().size
	_stage.size = Design.size()                                  # game view is always the design size
	_stage.position = Vector2(roundf((vp.x - _stage.size.x) * 0.5), 0.0)   # centered → equal gutters
	if _bounds:
		_layout_bounds()


# Two bright vertical lines mark the left/right edges of the player's view; the gutters beyond them are
# dimmed so they read as off-screen working space. All non-interactive (clicks pass through to items).
func _build_bounds() -> void:
	_bounds = Control.new()
	_bounds.name = "ViewBounds"
	_bounds.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bounds.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bounds)
	_shade_l = _bounds_rect(GUTTER_SHADE)
	_shade_r = _bounds_rect(GUTTER_SHADE)
	_line_l = _bounds_rect(LINE_COLOR)
	_line_r = _bounds_rect(LINE_COLOR)
	_layout_bounds()


func _bounds_rect(col: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = col
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bounds.add_child(r)
	return r


func _layout_bounds() -> void:
	var vp := get_viewport_rect().size
	var left: float = _stage.position.x
	var right: float = _stage.position.x + _stage.size.x
	_shade_l.position = Vector2.ZERO
	_shade_l.size = Vector2(maxf(left, 0.0), vp.y)
	_shade_r.position = Vector2(right, 0.0)
	_shade_r.size = Vector2(maxf(vp.x - right, 0.0), vp.y)
	_line_l.position = Vector2(left - LINE_W * 0.5, 0.0)
	_line_l.size = Vector2(LINE_W, vp.y)
	_line_r.position = Vector2(right - LINE_W * 0.5, 0.0)
	_line_r.size = Vector2(LINE_W, vp.y)


func _on_viewport_resized() -> void:
	if _stage:
		_layout_stage()


# --- scaffolding -------------------------------------------------------------

func _read_json(path: String):
	var p := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(p):
		return null
	var f := FileAccess.open(p, FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	return data


# A non-interactive sprite centered at `frac` of the background, sized `fsize` (KEEP_ASPECT_CENTERED).
func _static_sprite(art: String, frac: Vector2, fsize: float) -> TextureRect:
	var bg := _bg_size()
	var t := TextureRect.new()
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture = load(art)
	t.size = Vector2(fsize, fsize)
	t.position = frac * bg - Vector2(fsize, fsize) * 0.5
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


# The fence at the very bottom of the stack (smallest z) — below the buildings, matching the grove
# (base → fence → buildings). Context only: shown in the z-list, never moved.
func _populate_fence() -> void:
	if not ResourceLoader.exists(FENCE_PATH):
		return
	var f := TextureRect.new()
	f.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	f.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	f.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	f.texture = load(FENCE_PATH)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	f.set_meta("art", FENCE_PATH)
	f.set_meta("fixed", true)            # appears in the z-list (z 0); never moved
	_fence_layer.add_child(f)

# The buildings, at their saved positions — draggable/resizable; Ctrl+S writes their pos/fsize back to
# items_layout.json (the file the grove merges into the hub spots at load).
func _populate_buildings() -> void:
	var data = _read_json(ITEMS_LAYOUT)
	if typeof(data) == TYPE_DICTIONARY and data.has("items"):
		for rec in data["items"]:
			var art := ITEMS_DIR + String(rec.get("item", "")) + ".png"
			if not ResourceLoader.exists(art):
				continue
			var p = rec.get("pos", [0.5, 0.5])
			var b := _static_sprite(art, Vector2(float(p[0]), float(p[1])), float(rec.get("fsize", 240)))
			b.set_meta("art", art)
			b.pivot_offset = b.size * 0.5           # center pivot so the drag math is symmetric
			b.gui_input.connect(_on_item_input.bind(b))
			b.mouse_filter = Control.MOUSE_FILTER_STOP
			_buildings.add_child(b)


# A control layer filling the stage.
func _make_item_layer(nm: String) -> Control:
	var layer := Control.new()
	layer.name = nm
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(layer)
	return layer


func _build_full_overlay() -> void:
	_full = TextureRect.new()
	_full.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_full.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_full.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if ResourceLoader.exists(FULL_PATH):
		_full.texture = load(FULL_PATH)
	_full.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_full.visible = false
	_stage.add_child(_full)


# --- z-order list (right gutter) ---------------------------------------------

# The whole stack bottom→top: fence, buildings. Index in this list == z.
func _z_order() -> Array:
	var out := []
	out += _fence_layer.get_children()
	out += _buildings.get_children()
	return out

func _global_z(item: Control) -> int:
	return _z_order().find(item)

func _kind_of(item: Control) -> String:
	if item.get_parent() == _fence_layer: return "fence"
	return "bldg"

func _name_of(item: Control) -> String:
	var nm := String(item.get_meta("art", "")).get_file().get_basename()
	return nm if nm != "" else String(item.name)

# A panel pinned to the window's right edge (the right gutter) listing every item by z, front on top.
func _build_zlist() -> void:
	_zlist = PanelContainer.new()
	_zlist.name = "ZList"
	_zlist.anchor_left = 1.0; _zlist.anchor_right = 1.0
	_zlist.offset_left = -252; _zlist.offset_right = -12; _zlist.offset_top = 12
	_zlist.modulate = Color(1, 1, 1, 0.95)
	add_child(_zlist)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(240, min(get_viewport_rect().size.y - 24, 1400))
	_zlist.add_child(scroll)
	_zlist_box = VBoxContainer.new()
	_zlist_box.add_theme_constant_override("separation", 1)
	scroll.add_child(_zlist_box)
	_refresh_zlist()

# Rebuild the z-list. Each row is a button that selects its item. Highest z (front-most) sits on top,
# like a layers panel.
func _refresh_zlist() -> void:
	if _zlist_box == null:
		return
	for c in _zlist_box.get_children():
		c.queue_free()
	var hdr := Label.new()
	hdr.text = "Z-ORDER  (top = front)"
	hdr.add_theme_font_size_override("font_size", 12)
	_zlist_box.add_child(hdr)
	var order := _z_order()
	for i in range(order.size() - 1, -1, -1):
		var it: Control = order[i]
		var b := Button.new()
		b.text = "z%d  %s · %s" % [i, _name_of(it), _kind_of(it)]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 12)
		if it == _selected:
			b.add_theme_color_override("font_color", Color(1.0, 0.92, 0.4))      # selected
		elif it.has_meta("fixed"):
			b.add_theme_color_override("font_color", Color(0.74, 0.82, 1.0))     # fence
		b.pressed.connect(_select.bind(it))
		_zlist_box.add_child(b)


# --- building move / resize --------------------------------------------------

func _set_center(item: Control, center: Vector2) -> void:
	item.position = center - item.pivot_offset

func _center_of(item: Control) -> Vector2:
	return item.position + item.pivot_offset


func _select(item: Control) -> void:
	if item == _selected:                 # same item (e.g. dragging) — refresh the readout, not the list
		if item:
			_update_info(item)
		return
	if _selected and is_instance_valid(_selected):
		_selected.modulate = Color.WHITE
	_selected = item
	if item:
		item.modulate = Color(1.0, 1.0, 0.7)
		_update_info(item)
	_refresh_zlist()

func _update_info(item: Control) -> void:
	_set_info("%s · z%d · scale %.2f · (%.3f, %.3f)" % [_name_of(item), _global_z(item), item.scale.x,
		_center_of(item).x / _bg_size().x, _center_of(item).y / _bg_size().y])


func _on_item_input(ev: InputEvent, item: Control) -> void:
	if item.has_meta("fixed"):                       # fence: selectable, but not movable
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
			_select(item)
		return
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
		_buildings_moved = true
		_select(item)


func _scale_item(item: Control, factor: float) -> void:
	var c := _center_of(item)
	item.scale = (item.scale * factor).clamp(Vector2(0.03, 0.03), Vector2(10, 10))
	_set_center(item, c)
	_buildings_moved = true
	_select(item)


func _unhandled_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey and ev.pressed):
		return
	if ev.keycode == KEY_F:
		_full.visible = not _full.visible
		_set_info("reference %s" % ("ON" if _full.visible else "off"))
		get_viewport().set_input_as_handled(); return
	if ev.ctrl_pressed or ev.meta_pressed:
		if ev.keycode == KEY_S:
			_save(); get_viewport().set_input_as_handled(); return
	if _selected == null or not is_instance_valid(_selected) or _selected.has_meta("fixed"):
		return
	match ev.keycode:
		KEY_EQUAL, KEY_KP_ADD:
			_scale_item(_selected, 1.05)
		KEY_MINUS, KEY_KP_SUBTRACT:
			_scale_item(_selected, 1.0 / 1.05)


# --- persistence (assets/map1v2/items_layout.json) ---------------------------

# Write moved/resized buildings back to items_layout.json (the file the grove merges at load to position
# the hub's spots). Updates each item's pos/fsize in place, preserving the file's order/structure.
func _save() -> void:
	var bg := _bg_size()
	var data = _read_json(ITEMS_LAYOUT)
	if typeof(data) != TYPE_DICTIONARY or not data.has("items"):
		_set_info("SAVE FAILED — items_layout.json missing/invalid"); return
	var by_name := {}
	for b in _buildings.get_children():
		by_name[String(b.get_meta("art")).get_file().get_basename()] = b
	for rec in data["items"]:
		var b = by_name.get(String(rec.get("item", "")), null)
		if b == null:
			continue
		var c := _center_of(b)
		rec["pos"] = [c.x / bg.x, c.y / bg.y]
		rec["fsize"] = int(round(b.size.x * b.scale.x))
	var f := FileAccess.open(ProjectSettings.globalize_path(ITEMS_LAYOUT), FileAccess.WRITE)
	if f == null:
		_set_info("SAVE FAILED"); return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	_buildings_moved = false
	_set_info("saved %d building(s)" % _buildings.get_child_count())
