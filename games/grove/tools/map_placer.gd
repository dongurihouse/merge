extends Control
## Map-1 DECORATION placer (dev tool). Background = base_empty. The scene is one z-stack, bottom→top:
## FENCE (smallest z) · BACK decor (trees/clouds) · BUILDINGS (house/shed/…) · FRONT decor (grass) —
## matching the grove's render order. Placed decor saves to data/map1v2_decor.json (layer back/front/cloud);
## the grove reads it at load. Press B to enter BUILDING-move mode (drag/resize the house/shed/…; their
## positions save to assets/map1v2/items_layout.json, which the grove merges into the hub spots at load).
## The right-gutter Z-ORDER list shows every item's z; raise/lower decor with w/e (it crosses the buildings).
##
## Controls — Tab palette · F reference · drag move · wheel +/- scale · w/e z-order · right-click/Del remove · Ctrl+S save.
## Run:  make place   (or: godot --path . res://games/grove/tools/MapPlacer.tscn)
##
## The window is WIDER than the game's portrait view. The central "stage" IS the real game view (design
## 1080×1920); the extra width on each side is gutter space to work the controls in. Two bright lines mark
## the edges of the player's view, and the off-view gutters are dimmed — anything past the lines is cropped
## in-game exactly as it is here.

const Design = preload("res://engine/scripts/core/design.gd")

const PALETTE_DIRS := ["res://assets/map1v2/trees/", "res://assets/map1v2/grass/", "res://assets/map1v2/clouds/"]
const ITEMS_DIR := "res://assets/map1v2/items/"
const ITEMS_LAYOUT := "res://assets/map1v2/items_layout.json"
const FENCE_PATH := "res://assets/map1v2/fence.png"
const FULL_PATH := "res://assets/map1v2/base_full.png"
const SAVE_PATH := "res://data/map1v2_decor.json"
const HINT := "drag · wheel scale · w/e z-order · B move buildings · right-click/Del delete · Ctrl+S save"

const WINDOW_WIDTH_MULT := 2.6      # tool window width = this × the game-view width (capped to the screen)
const LINE_W := 4.0                 # thickness of each view-edge line (design px)
const LINE_COLOR := Color(0.25, 0.95, 1.0, 0.95)   # bright cyan — reads clearly over the art
const GUTTER_SHADE := Color(0.0, 0.0, 0.0, 0.32)   # dim the off-view gutters so the play area pops

var _stage: Control          # the game-view region (design 1080×1920), centered in the wider window
var _bg: TextureRect
var _fence_layer: Control    # the fence — smallest z (bottom of the stack, below all decor)
var _back_layer: Control     # placed decor BEHIND the buildings (trees + clouds), interactive
var _buildings: Control      # the house/shed/… — fixed context (not movable), selectable for their z
var _front_layer: Control    # placed decor IN FRONT of the buildings (grass), interactive
var _zlist: PanelContainer   # right-gutter list of every item by z
var _zlist_box: VBoxContainer
var _full: TextureRect
var _bounds: Control         # the two view-edge lines + dimmed gutters (overlay, non-interactive)
var _line_l: ColorRect
var _line_r: ColorRect
var _shade_l: ColorRect
var _shade_r: ColorRect
var _palette: PanelContainer
var _selected: Control = null
var _drag_off := Vector2.ZERO
var _dragging := false
var _edit_buildings := false   # B toggles "building move" mode: buildings draggable, decor locked
var _buildings_moved := false  # a building was dragged/scaled → Ctrl+S rewrites items_layout.json


func _ready() -> void:
	_fit_tool_window()                 # wider than the game window → side gutters for the controls
	await get_tree().process_frame     # let the resize settle so the viewport size is final
	_build_stage()                     # central game-view region; the .tscn Background moves inside it
	# the z-stack, bottom→top: fence · back decor · buildings · front decor (created in that order)
	_fence_layer = _make_item_layer("Fence")
	_back_layer = _make_item_layer("BackItems")
	_buildings = _make_item_layer("Buildings")
	_front_layer = _make_item_layer("FrontItems")
	_populate_fence()
	_populate_buildings()
	_build_full_overlay()
	_build_bounds()                    # the two "edge of the player's view" lines + dimmed gutters
	_build_palette()
	_build_zlist()                     # right-gutter z-order readout
	get_viewport().size_changed.connect(_on_viewport_resized)
	_set_info("")
	await get_tree().process_frame
	_load()


func _set_info(text: String) -> void:
	DisplayServer.window_set_title("Decor placer — " + (text if text != "" else HINT))


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


# The fence at the very bottom of the stack (smallest z) — below every placed decoration, matching the
# grove (base → fence → trees → buildings → grass).
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

# The buildings, at their auto-derived positions — fixed context (not movable), but they carry a z and
# show in the z-list, and selecting one (from the list) highlights it so you can read its z.
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
			b.set_meta("fixed", true)               # can't restack/delete — but CAN move (press B)
			b.pivot_offset = b.size * 0.5           # center pivot so the drag math matches decor
			b.gui_input.connect(_on_item_input.bind(b))
			b.mouse_filter = Control.MOUSE_FILTER_IGNORE   # click-through until B mode (set by _apply_lock)
			_buildings.add_child(b)
	_buildings.modulate = Color(1, 1, 1, 0.85)   # slightly faded so trees BEHIND read through


# An interactive decor layer filling the stage. Two of these straddle the buildings backdrop so trees
# render behind the house (matching the game) while grass renders in front.
func _make_item_layer(nm: String) -> Control:
	var layer := Control.new()
	layer.name = nm
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(layer)
	return layer

# Every placed item across both layers — back first, so a flat save preserves each layer's order.
func _all_items() -> Array:
	return _back_layer.get_children() + _front_layer.get_children()


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


func _build_palette() -> void:
	_palette = PanelContainer.new()
	_palette.name = "Palette"
	_palette.position = Vector2(12, 12)
	_palette.custom_minimum_size = Vector2(150, 0)
	_palette.modulate = Color(1, 1, 1, 0.92)
	add_child(_palette)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(150, min(get_viewport_rect().size.y - 24, 1200))
	_palette.add_child(scroll)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	scroll.add_child(vb)

	var save_btn := Button.new(); save_btn.text = "💾 Save"; save_btn.pressed.connect(_save); vb.add_child(save_btn)
	var load_btn := Button.new(); load_btn.text = "↻ Load"; load_btn.pressed.connect(_load); vb.add_child(load_btn)

	for dir in PALETTE_DIRS:
		vb.add_child(HSeparator.new())
		var hdr := Label.new()
		hdr.text = String(dir).trim_suffix("/").get_file().to_upper()   # TREES / GRASS / CLOUDS
		hdr.add_theme_font_size_override("font_size", 13)
		vb.add_child(hdr)
		var d := DirAccess.open(dir)
		if d == null:
			continue
		var files := d.get_files()
		files.sort()
		for fname in files:
			if not fname.ends_with(".png"):
				continue
			var path: String = dir + fname
			var btn := Button.new()
			btn.custom_minimum_size = Vector2(132, 84)
			btn.icon = load(path)
			btn.expand_icon = true
			btn.tooltip_text = "Add %s" % fname
			btn.pressed.connect(_spawn.bind(path))
			vb.add_child(btn)


# --- z-order list (right gutter) ---------------------------------------------

# The whole stack bottom→top: fence, back decor, buildings, front decor. Index in this list == z.
func _z_order() -> Array:
	var out := []
	out += _fence_layer.get_children()
	out += _back_layer.get_children()
	out += _buildings.get_children()
	out += _front_layer.get_children()
	return out

func _global_z(item: Control) -> int:
	return _z_order().find(item)

func _kind_of(item: Control) -> String:
	if item.get_parent() == _fence_layer: return "fence"
	if item.has_meta("fixed"): return "bldg"
	if item.get_parent() == _front_layer: return "front"
	if "/clouds/" in String(item.get_meta("art", "")): return "cloud"
	return "back"

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

# Rebuild the z-list. Each row is a button that selects its item (so buildings — IGNORE on the canvas —
# are still reachable). Highest z (front-most) sits on top, like a layers panel.
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
			b.add_theme_color_override("font_color", Color(0.74, 0.82, 1.0))     # fence/buildings
		b.pressed.connect(_select.bind(it))
		_zlist_box.add_child(b)


# --- placed decoration -------------------------------------------------------

func _spawn(art_path: String, forced_layer := "") -> Control:
	if not ResourceLoader.exists(art_path):
		return null
	var tex: Texture2D = load(art_path)
	var item := TextureRect.new()
	item.texture = tex
	item.set_meta("art", art_path)
	item.size = tex.get_size()
	item.pivot_offset = item.size * 0.5
	item.mouse_filter = Control.MOUSE_FILTER_STOP
	item.gui_input.connect(_on_item_input.bind(item))
	var lay := forced_layer if forced_layer != "" else _layer_of(art_path)         # saved layer wins on load
	var layer := _front_layer if lay == "front" else _back_layer                   # grass in front; trees/clouds behind
	layer.add_child(item)
	# default spawn spot: a cloud drops into the SKY — the back layer sits behind the buildings, so a
	# cloud spawned dead-centre would land hidden behind the house. Everything else spawns at centre.
	var bg := _bg_size()
	var spot := Vector2(bg.x * 0.5, bg.y * 0.16) if _layer_of(art_path) == "cloud" else bg * 0.5
	_set_center(item, spot)
	_select(item)
	return item


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
	if ev is InputEventMouseButton:
		if ev.button_index == MOUSE_BUTTON_LEFT:
			if ev.pressed:
				_select(item)
				_dragging = true
				_drag_off = item.get_global_mouse_position() - _center_of(item)
			else:
				_dragging = false
		elif ev.button_index == MOUSE_BUTTON_RIGHT and ev.pressed:
			_delete_item(item)                       # right-click removes
		elif ev.button_index == MOUSE_BUTTON_WHEEL_UP and ev.pressed:
			if ev.shift_pressed: _restack(item, 1)        # shift = raise z
			else: _scale_item(item, 1.05)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN and ev.pressed:
			if ev.shift_pressed: _restack(item, -1)       # shift = lower z
			else: _scale_item(item, 1.0 / 1.05)
		# macOS turns shift+wheel into a HORIZONTAL wheel (no shift flag), so treat that as z-order too
		elif ev.button_index == MOUSE_BUTTON_WHEEL_RIGHT and ev.pressed:
			_restack(item, 1)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_LEFT and ev.pressed:
			_restack(item, -1)
	elif ev is InputEventMouseMotion and _dragging and item == _selected:
		_set_center(item, item.get_global_mouse_position() - _drag_off)
		if item.has_meta("fixed"):
			_buildings_moved = true
		_select(item)


func _scale_item(item: Control, factor: float) -> void:
	var c := _center_of(item)
	item.scale = (item.scale * factor).clamp(Vector2(0.03, 0.03), Vector2(10, 10))
	_set_center(item, c)
	if item.has_meta("fixed"):
		_buildings_moved = true
	_select(item)

# Raise (dir>0) / lower (dir<0) a decor item in the unified z-stack. Within a layer it just shifts; at a
# layer edge it CROSSES the buildings — back's top → front's bottom (in front of the house) and back, so
# w/e walk an item continuously from behind the buildings to in front. Buildings/fence don't move.
func _restack(item: Control, dir: int) -> void:
	if item == null or item.has_meta("fixed"):
		return
	var parent := item.get_parent()
	var idx := item.get_index()
	if dir > 0:                                                  # raise → toward the front
		if parent == _back_layer and idx >= _back_layer.get_child_count() - 1:
			_move_to_layer(item, _front_layer, 0)               # cross above the buildings
		else:
			parent.move_child(item, mini(idx + 1, parent.get_child_count() - 1))
	else:                                                        # lower → toward the back
		if parent == _front_layer and idx <= 0:
			_move_to_layer(item, _back_layer, _back_layer.get_child_count())   # cross below the buildings
		else:
			parent.move_child(item, maxi(idx - 1, 0))
	_refresh_zlist()
	_update_info(item)

# Reparent an item between the back and front decor layers, keeping its on-stage position (both layers
# fill the stage at the same origin, so there is no visual jump).
func _move_to_layer(item: Control, layer: Control, idx: int) -> void:
	var pos := item.position
	item.get_parent().remove_child(item)
	layer.add_child(item)
	item.position = pos
	layer.move_child(item, clampi(idx, 0, layer.get_child_count() - 1))

func _delete_item(item: Control) -> void:
	if item == null or item.has_meta("fixed"):       # buildings/fence can't be deleted
		return
	if item == _selected:
		_selected = null
	item.get_parent().remove_child(item)             # remove now so the z-list refresh excludes it
	item.queue_free()
	_set_info("removed")
	_refresh_zlist()

# Building-move mode: when ON, buildings are draggable and the decor is click-locked (so a building's
# big bounding box doesn't steal decor clicks); when OFF, the reverse (normal decor editing).
func _apply_lock() -> void:
	for b in _buildings.get_children():
		b.mouse_filter = Control.MOUSE_FILTER_STOP if _edit_buildings else Control.MOUSE_FILTER_IGNORE
	for c in _back_layer.get_children() + _front_layer.get_children():
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE if _edit_buildings else Control.MOUSE_FILTER_STOP


func _unhandled_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey and ev.pressed):
		return
	if ev.keycode == KEY_TAB:
		_palette.visible = not _palette.visible
		get_viewport().set_input_as_handled(); return
	if ev.keycode == KEY_F:
		_full.visible = not _full.visible
		_set_info("reference %s" % ("ON" if _full.visible else "off"))
		get_viewport().set_input_as_handled(); return
	if ev.keycode == KEY_B:                         # toggle BUILDING-move mode
		_edit_buildings = not _edit_buildings
		_apply_lock()
		_set_info("BUILDING move %s — drag to reposition, wheel to resize, Ctrl+S to save" % ("ON" if _edit_buildings else "off"))
		get_viewport().set_input_as_handled(); return
	if ev.ctrl_pressed or ev.meta_pressed:
		if ev.keycode == KEY_S:
			_save(); get_viewport().set_input_as_handled(); return
		if ev.keycode == KEY_L:
			_load(); get_viewport().set_input_as_handled(); return
	if _selected == null or not is_instance_valid(_selected):
		return
	if _selected.has_meta("fixed"):           # buildings/fence: visible + selectable, but not editable
		return
	match ev.keycode:
		KEY_DELETE, KEY_BACKSPACE:
			_delete_item(_selected)
		KEY_EQUAL, KEY_KP_ADD:
			_scale_item(_selected, 1.05)
		KEY_MINUS, KEY_KP_SUBTRACT:
			_scale_item(_selected, 1.0 / 1.05)
		KEY_E:
			_restack(_selected, 1)         # e = raise z (reliable keyboard z-order)
		KEY_W:
			_restack(_selected, -1)        # w = lower z


# --- persistence (data/map1v2_decor.json) ------------------------------------

# Default layer for a freshly-spawned item, by its source folder: trees → BACK (behind buildings),
# clouds → their own sky layer (also behind), everything else (grass) → FRONT. The user can then move
# it across the buildings with w/e, which is why save reads the item's ACTUAL layer (_save_layer), not this.
func _layer_of(art: String) -> String:
	if "/trees/" in art:
		return "back"
	if "/clouds/" in art:
		return "cloud"
	return "front"

# The layer to SAVE an item under = where it actually sits now (the user may have crossed the buildings).
func _save_layer(item: Control) -> String:
	if item.get_parent() == _front_layer:
		return "front"
	if "/clouds/" in String(item.get_meta("art", "")):
		return "cloud"
	return "back"


func _save() -> void:
	var bg := _bg_size()
	var placed := []
	for item in _all_items():
		var c := _center_of(item)
		var art := String(item.get_meta("art"))
		var nat: Vector2 = item.texture.get_size()
		placed.append({
			"art": art,
			"pos": [c.x / bg.x, c.y / bg.y],
			# footprint in design px = the sprite's LARGER native dim × scale (KEEP_ASPECT_CENTERED in-game)
			"fsize": int(round(max(nat.x, nat.y) * item.scale.x)),
			"layer": _save_layer(item),
		})
	var p := ProjectSettings.globalize_path(SAVE_PATH)
	DirAccess.make_dir_recursive_absolute(p.get_base_dir())
	var f := FileAccess.open(p, FileAccess.WRITE)
	if f == null:
		_set_info("SAVE FAILED"); return
	f.store_string(JSON.stringify({"decor": placed}, "\t"))
	f.close()
	var extra := ""
	if _buildings_moved:
		extra = " + buildings" if _save_buildings() else " (BUILDINGS SAVE FAILED)"
	_set_info("saved %d decoration(s)%s" % [placed.size(), extra])

# Write moved/resized buildings back to items_layout.json (the file the grove merges at load to position
# the hub's spots). Updates each item's pos/fsize in place, preserving the file's order/structure.
func _save_buildings() -> bool:
	var bg := _bg_size()
	var data = _read_json(ITEMS_LAYOUT)
	if typeof(data) != TYPE_DICTIONARY or not data.has("items"):
		return false
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
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	_buildings_moved = false
	return true


func _load() -> void:
	for item in _all_items():
		item.queue_free()
	_selected = null
	var data = _read_json(SAVE_PATH)
	if typeof(data) != TYPE_DICTIONARY or not data.has("decor"):
		return
	var bg := _bg_size()
	for rec in data["decor"]:
		var item := _spawn(String(rec.get("art", "")), String(rec.get("layer", "")))   # restore its saved layer
		if item == null:
			continue
		var nat: Vector2 = item.texture.get_size()
		var fs := float(rec.get("fsize", max(nat.x, nat.y)))
		item.scale = Vector2.ONE * (fs / max(nat.x, nat.y))
		var pos = rec.get("pos", [0.5, 0.5])
		_set_center(item, Vector2(float(pos[0]) * bg.x, float(pos[1]) * bg.y))
	_select(null)
	_refresh_zlist()
	_set_info("loaded %d decoration(s)" % data["decor"].size())
