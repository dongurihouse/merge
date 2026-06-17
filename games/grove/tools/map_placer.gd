extends Control
## Map-1 DECORATION placer (dev tool). Background = base_empty; the items + fence render as a static
## BACKDROP (matching the grove) so you place trees/grass in context. Trees save to the BACK layer
## (behind the buildings), grass to the FRONT layer. Saved to data/map1v2_decor.json; the grove reads it
## at load and renders + animates the decoration — no bake step.
##
## Controls — Tab palette · F reference · drag move · wheel or +/- scale · Del remove · Ctrl+S save · Ctrl+L load.
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
const HINT := "Tab palette · drag · wheel scale · w/e z-order · right-click/Del delete · Ctrl+S save"

const WINDOW_WIDTH_MULT := 2.6      # tool window width = this × the game-view width (capped to the screen)
const LINE_W := 4.0                 # thickness of each view-edge line (design px)
const LINE_COLOR := Color(0.25, 0.95, 1.0, 0.95)   # bright cyan — reads clearly over the art
const GUTTER_SHADE := Color(0.0, 0.0, 0.0, 0.32)   # dim the off-view gutters so the play area pops

var _stage: Control          # the game-view region (design 1080×1920), centered in the wider window
var _bg: TextureRect
var _backdrop: Control       # static items + fence (context only)
var _back_layer: Control     # placed decor BEHIND the buildings (trees + clouds), interactive
var _front_layer: Control    # placed decor IN FRONT of the buildings (grass), interactive
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


func _ready() -> void:
	_fit_tool_window()                 # wider than the game window → side gutters for the controls
	await get_tree().process_frame     # let the resize settle so the viewport size is final
	_build_stage()                     # central game-view region; the .tscn Background moves inside it
	_back_layer = _make_item_layer("BackItems")    # trees + clouds — BEHIND the buildings (game order)
	_build_backdrop()                  # the buildings, sandwiched between the back + front decor layers
	_front_layer = _make_item_layer("FrontItems")  # grass — IN FRONT of the buildings
	_build_full_overlay()
	_build_bounds()                    # the two "edge of the player's view" lines + dimmed gutters
	_build_palette()
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


func _build_backdrop() -> void:
	_backdrop = Control.new()
	_backdrop.name = "Backdrop"
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_backdrop)
	# fence behind the buildings (matches the grove: base -> fence -> items)
	if ResourceLoader.exists(FENCE_PATH):
		var f := TextureRect.new()
		f.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		f.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		f.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		f.texture = load(FENCE_PATH)
		f.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_backdrop.add_child(f)
	# the buildings, at their auto-derived positions
	var data = _read_json(ITEMS_LAYOUT)
	if typeof(data) == TYPE_DICTIONARY and data.has("items"):
		for rec in data["items"]:
			var art := ITEMS_DIR + String(rec.get("item", "")) + ".png"
			if not ResourceLoader.exists(art):
				continue
			var p = rec.get("pos", [0.5, 0.5])
			_backdrop.add_child(_static_sprite(art, Vector2(float(p[0]), float(p[1])), float(rec.get("fsize", 240))))
	_backdrop.modulate = Color(1, 1, 1, 0.85)   # slightly faded so placed decor reads clearly on top


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


# --- placed decoration -------------------------------------------------------

func _spawn(art_path: String) -> Control:
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
	var layer := _front_layer if _layer_of(art_path) == "front" else _back_layer   # grass in front; trees/clouds behind
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
	if _selected and is_instance_valid(_selected):
		_selected.modulate = Color.WHITE
	_selected = item
	if item:
		item.modulate = Color(1.0, 1.0, 0.7)
		var nm := String(item.get_meta("art")).get_file().get_basename()
		_set_info("%s · z%d · scale %.2f · (%.3f, %.3f)" % [nm, item.get_index(), item.scale.x,
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
		_select(item)


func _scale_item(item: Control, factor: float) -> void:
	var c := _center_of(item)
	item.scale = (item.scale * factor).clamp(Vector2(0.03, 0.03), Vector2(10, 10))
	_set_center(item, c)
	_select(item)

# Raise/lower an item in the draw order (shift+wheel). Child order = draw order in the tool AND the
# order written on save, so it round-trips to the game's per-layer stacking.
func _restack(item: Control, dir: int) -> void:
	var layer := item.get_parent()                  # restack within the item's own layer (back or front)
	var ni := clampi(item.get_index() + dir, 0, layer.get_child_count() - 1)
	layer.move_child(item, ni)
	_select(item)

func _delete_item(item: Control) -> void:
	if item == _selected:
		_selected = null
	item.queue_free()
	_set_info("removed")


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
	if ev.ctrl_pressed or ev.meta_pressed:
		if ev.keycode == KEY_S:
			_save(); get_viewport().set_input_as_handled(); return
		if ev.keycode == KEY_L:
			_load(); get_viewport().set_input_as_handled(); return
	if _selected == null or not is_instance_valid(_selected):
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

# In-game render layer for a placed item, by its source folder: trees go BEHIND the buildings,
# clouds drift in the sky (own layer), everything else (grass) renders IN FRONT.
func _layer_of(art: String) -> String:
	if "/trees/" in art:
		return "back"
	if "/clouds/" in art:
		return "cloud"
	return "front"


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
			"layer": _layer_of(art),
		})
	var p := ProjectSettings.globalize_path(SAVE_PATH)
	DirAccess.make_dir_recursive_absolute(p.get_base_dir())
	var f := FileAccess.open(p, FileAccess.WRITE)
	if f == null:
		_set_info("SAVE FAILED"); return
	f.store_string(JSON.stringify({"decor": placed}, "\t"))
	f.close()
	_set_info("saved %d decoration(s)" % placed.size())


func _load() -> void:
	for item in _all_items():
		item.queue_free()
	_selected = null
	var data = _read_json(SAVE_PATH)
	if typeof(data) != TYPE_DICTIONARY or not data.has("decor"):
		return
	var bg := _bg_size()
	for rec in data["decor"]:
		var item := _spawn(String(rec.get("art", "")))
		if item == null:
			continue
		var nat: Vector2 = item.texture.get_size()
		var fs := float(rec.get("fsize", max(nat.x, nat.y)))
		item.scale = Vector2.ONE * (fs / max(nat.x, nat.y))
		var pos = rec.get("pos", [0.5, 0.5])
		_set_center(item, Vector2(float(pos[0]) * bg.x, float(pos[1]) * bg.y))
	_select(null)
	_set_info("loaded %d decoration(s)" % data["decor"].size())
