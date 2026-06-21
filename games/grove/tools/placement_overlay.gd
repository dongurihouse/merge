extends Control
## Placement Workbench — the editing surface, mounted by ui_placement.gd ON TOP of the
## REAL Home/Board scene. Drag the major items, then Save writes their location back into
## SOURCE DATA (no override layer). Two modes:
##   home  — drag each farmhouse unlock badge (free 2D); saves farm_home.json buildings[].pos
##   board — drag the quest bar + the board (vertical only); saves board_layout.json
##           {fence_dy, board_dy} (a fraction of viewport height the board reads on load).
##
## It boots the actual Map.tscn / Board.tscn so what you place is exactly what the game shows.

const FARM_HOME := "res://games/grove/assets/map/farm/farm_home.json"
const BOARD_LAYOUT := "res://games/grove/assets/board_layout.json"

const SEL := Color("#27AE60")        # selected target outline
const IDLE := Color(1, 1, 1, 0.45)   # other targets' outline

var scene: Node          # the real Map/Board scene instance
var mode := "home"       # "home" | "board"

var _targets: Array = [] # [{node, kind, id}]  kind: "badge" (home) | "band" (board)
var _sel = null          # the selected target dict
var _drag = null         # active drag bookkeeping
var _readout: Label
var _size_slider: HSlider # board mode: uniform board scale knob (saved as board_scale)
var _size_readout: Label  # board mode: the live scale, as a percent

# --- setup ----------------------------------------------------------------------------

func setup() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	# set_anchors_AND_OFFSETS — anchors alone leave the rect at (0,0), so the overlay would have no
	# hittable area and every press would fall through to the scene's own input surface (content /
	# board_area), and the drag would silently do nothing. This sizes it to fill the parent.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_toolbar()
	_collect_targets()
	queue_redraw()

func _collect_targets() -> void:
	_targets.clear()
	if mode == "board":
		if scene.giver_bar != null:
			_targets.append({"node": scene.giver_bar, "kind": "band", "id": "fence"})
		if scene._board_center != null:
			_targets.append({"node": scene._board_center, "kind": "band", "id": "board"})
	else:
		_collect_badges(scene.content)
	_sel = _targets[0] if not _targets.is_empty() else null
	_update_readout()

func _collect_badges(n: Node) -> void:
	for c in n.get_children():
		if c is Control and c.has_meta("place_spot"):
			_targets.append({"node": c, "kind": "badge", "id": String(c.get_meta("place_spot"))})
		_collect_badges(c)

# --- input / drag ---------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_drag(_evt_global(event))
		else:
			_drag = null
		accept_event()
	elif event is InputEventMouseMotion and _drag != null:
		_drag_to(_evt_global(event))
		accept_event()

# The event's OWN position in global canvas space. _gui_input delivers event.position in the
# overlay's local space; map it to global so it matches every target's get_global_rect(). (Using
# get_global_mouse_position() instead is wrong here — it polls the live cursor, not this event.)
func _evt_global(event: InputEvent) -> Vector2:
	return get_global_transform() * event.position

func _begin_drag(m: Vector2) -> void:
	var t = _pick(m)
	if t == null:
		return
	_sel = t
	if t.kind == "badge":
		_drag = {"t": t, "grab": (t.node as Control).global_position - m}
	else:
		_drag = {"t": t, "base_frac": _band_get(t.id), "base_y": m.y}
	_update_readout()
	queue_redraw()

func _drag_to(m: Vector2) -> void:
	var t = _drag.t
	if t.kind == "badge":
		var node := t.node as Control
		var rect: Rect2 = scene._map_rect
		var ctr: Vector2 = m + _drag.grab + node.size * 0.5
		ctr.x = clampf(ctr.x, rect.position.x, rect.end.x)
		ctr.y = clampf(ctr.y, rect.position.y, rect.end.y)
		node.global_position = ctr - node.size * 0.5
	else:
		var view := get_viewport_rect().size
		var frac: float = _drag.base_frac + (m.y - _drag.base_y) / view.y
		_band_set(t.id, frac)
	_update_readout()
	queue_redraw()

func _pick(m: Vector2):
	# topmost first: badges are seated in order; bands are few. Pick the smallest containing rect.
	var best = null
	var best_area := INF
	for t in _targets:
		var r: Rect2 = (t.node as Control).get_global_rect()
		if r.has_point(m):
			var a := r.size.x * r.size.y
			if a < best_area:
				best_area = a
				best = t
	return best

func _band_get(id: String) -> float:
	return scene._place_fence_dy if id == "fence" else scene._place_board_dy

func _band_set(id: String, frac: float) -> void:
	if id == "fence":
		scene._place_fence_dy = frac
	else:
		scene._place_board_dy = frac
	scene.placement_refresh()

# --- save / reset ---------------------------------------------------------------------

func _save() -> void:
	if mode == "board":
		_save_board()
	else:
		_save_home()

func _save_home() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(FARM_HOME))
	if typeof(data) != TYPE_DICTIONARY:
		_flash("save FAILED: bad farm_home.json")
		return
	var rect: Rect2 = scene._map_rect
	var by_spot := {}
	for t in _targets:
		var c: Vector2 = (t.node as Control).get_global_rect().get_center()
		var nrm := (c - rect.position) / rect.size
		by_spot[t.id] = [nrm.x, nrm.y]
	for b in data.get("buildings", []):
		var sid := String(b.get("spot", ""))
		if by_spot.has(sid):
			b["pos"] = by_spot[sid]
	_write(FARM_HOME, data)
	_flash("saved %d spots → farm_home.json" % by_spot.size())

func _save_board() -> void:
	_write(BOARD_LAYOUT, _board_layout_data())
	_flash("saved → board_layout.json")

# The board_layout.json payload: the two vertical nudges + the uniform board scale. One place so the
# save writer and the tests agree on the shape.
func _board_layout_data() -> Dictionary:
	return {"board_dy": scene._place_board_dy, "fence_dy": scene._place_fence_dy, "board_scale": scene._place_board_scale}

func _write(path: String, data) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "\t", true))
	f.close()

func _reset() -> void:
	# revert to the last-saved SOURCE DATA (re-read the file; nothing in memory is kept).
	if mode == "board":
		scene._place_fence_dy = 0.0
		scene._place_board_dy = 0.0
		scene._place_board_scale = 1.0
		scene._load_placement()                  # re-read the last-saved file (dy + scale)
		scene.placement_refresh()
		if _size_slider != null:
			_size_slider.set_value_no_signal(scene._place_board_scale)
			_update_size_readout()
	else:
		scene._build_map()           # re-seats every badge at the file's pos
		_collect_targets()
	_update_readout()
	queue_redraw()
	_flash("reset to saved")

# --- chrome ---------------------------------------------------------------------------

func _build_toolbar() -> void:
	var bar := HBoxContainer.new()
	bar.position = Vector2(20, 210)        # below the HUD, clear of the level badge
	bar.add_theme_constant_override("separation", 8)
	add_child(bar)
	bar.add_child(_btn("Save", Color("#27AE60"), _save))
	bar.add_child(_btn("Reset", Color("#C0392B"), _reset))
	# board mode: a uniform SIZE knob — scales the whole board+frame (saved as board_scale).
	if mode == "board":
		bar.add_child(_size_label("Size"))
		_size_slider = HSlider.new()
		_size_slider.min_value = 0.5
		_size_slider.max_value = 1.6
		_size_slider.step = 0.01
		_size_slider.set_value_no_signal(scene._place_board_scale)
		_size_slider.custom_minimum_size = Vector2(220, 48)
		_size_slider.value_changed.connect(_on_size_changed)
		bar.add_child(_size_slider)
		_size_readout = _size_label("")
		bar.add_child(_size_readout)
		_update_size_readout()
	_readout = Label.new()
	_readout.add_theme_font_size_override("font_size", 22)
	_readout.add_theme_color_override("font_color", Color.WHITE)
	_readout.add_theme_color_override("font_outline_color", Color.BLACK)
	_readout.add_theme_constant_override("outline_size", 6)
	_readout.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(_readout)

func _btn(text: String, bg: Color, fn: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(120, 48)
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_color_override("font_color", Color.WHITE)
	var s := StyleBoxFlat.new()
	s.bg_color = Color(bg, 0.94)
	s.set_corner_radius_all(8)
	s.content_margin_left = 14.0
	s.content_margin_right = 14.0
	for k in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(k, s)
	b.pressed.connect(fn)
	return b

# A bold, outlined toolbar label that reads over the live scene (same treatment as the readout).
func _size_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l

# Drag the size knob → scale the live board (board.gd applies it on the next sort) + update the percent.
func _on_size_changed(v: float) -> void:
	scene._place_board_scale = v
	scene.placement_refresh()
	_update_size_readout()

func _update_size_readout() -> void:
	if _size_readout != null:
		_size_readout.text = "%d%%" % roundi(scene._place_board_scale * 100.0)

func _update_readout() -> void:
	if _readout == null:
		return
	if _sel == null:
		_readout.text = "(nothing to place)"
		return
	if _sel.kind == "badge":
		var rect: Rect2 = scene._map_rect
		var c: Vector2 = (_sel.node as Control).get_global_rect().get_center()
		var n := (c - rect.position) / rect.size
		_readout.text = "%s  pos [%.3f, %.3f]" % [_sel.id, n.x, n.y]
	else:
		_readout.text = "%s  dy %+.3f" % [_sel.id, _band_get(_sel.id)]

func _flash(msg: String) -> void:
	if _readout != null:
		_readout.text = msg

func _draw() -> void:
	for t in _targets:
		var r: Rect2 = (t.node as Control).get_global_rect()
		var on: bool = t == _sel
		draw_rect(r, SEL if on else IDLE, false, 3.0 if on else 2.0)
