extends Control
## Scene-placement workbench — the interactive surface over scene_workbench_model.gd.
## Left: the scene stage (fit to window). Right: sidebar — save, the selected entry's numbers,
## the placed list (paint order), and the bundle's addable assets.
##
## Mouse:  click = select (alpha-aware, topmost)   drag = move   wheel = resize ±2% (Shift ±10%)
##         Alt+click = select the item's whole CLUSTER (drag/wheel/Z/X then act on the group)
## Keys:   arrows = nudge 1px (Shift 10)   Z / X = z-index −1 / +1 (Shift 10)   Delete = remove
##         I = isolate the current cluster (others ghost; added assets join it)
##         Cmd/Ctrl+S = save   R = reload from disk   Esc = deselect / exit isolation

const M = preload("res://games/grove/tools/scene_workbench_model.gd")

const SIDEBAR_W := 340.0
const HIT_MAX_W := 192              # alpha hit-test images downsample to this width (memory)
const INK := Color("#2B2B33")
const PAPER := Color("#F4EDE1")

var doc: Dictionary = {}
var placements_path := ""
var repo_root := ""
var bundle_dir := ""
var scene_name := ""
var dirty := false

var _tex: Dictionary = {}           # abs path -> Texture2D (null cached as false)
var _hit: Dictionary = {}           # abs path -> downsampled Image for alpha tests
var _sel := -1                      # index into doc.placements (item selection)
var _sel_cluster := ""              # cluster selection — mutually exclusive with _sel
var _isolated := ""                 # isolation: this cluster edits alone, the rest of the scene ghosts
var _dragging := false
var _drag_grab := Vector2.ZERO      # canvas-space offset from the entry anchor at grab time
var _drag_last := Vector2.ZERO      # last canvas point (cluster drags are delta-based)

var _stage: Control = null
var _layers: Control = null         # one TextureRect per placement, child order = paint order
var _overlay: Control = null        # selection outline
var _status: Label = null
var _info: Label = null
var _save_btn: Button = null
var _placed_box: VBoxContainer = null
var _add_box: VBoxContainer = null
var _cluster_box: VBoxContainer = null
var _cluster_actions: VBoxContainer = null
var _open_cluster := ""             # CLUSTER= launch arg — select + isolate once ready

func setup(scenes_root: String, scene: String, cluster := "") -> bool:
	scene_name = scene
	_open_cluster = cluster
	bundle_dir = M.bundle_for(scenes_root, scene)
	if bundle_dir == "":
		push_error("no bundle with metadata/placements.json for scene '%s' under %s" % [scene, scenes_root])
		return false
	repo_root = M.repo_root_of(scenes_root)
	placements_path = bundle_dir + "/metadata/placements.json"
	doc = M.load_doc(placements_path)
	if doc.is_empty():
		push_error("could not parse " + placements_path)
		return false
	return true

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE         # the full-rect view root must not swallow stage clicks either
	# Stage input arrives via _unhandled_input, so every node over the stage must IGNORE the
	# mouse — a Control's DEFAULT filter is STOP, which silently swallows clicks in the GUI
	# layer and the handler never fires (the sidebar still worked; the stage read as dead).
	var bg := ColorRect.new()
	bg.color = Color("#10213d")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_stage = Control.new()
	_stage.clip_contents = true
	_stage.mouse_filter = Control.MOUSE_FILTER_STOP    # the stage OWNS mouse input (gui_input surface)
	_stage.gui_input.connect(_on_stage_input)
	add_child(_stage)
	_layers = Control.new()
	_layers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_layers)
	_overlay = Control.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	_stage.add_child(_overlay)
	_build_sidebar()
	_rebuild_stage()
	get_viewport().size_changed.connect(_layout)
	_layout()
	if _open_cluster != "" and M.clusters(doc).has(_open_cluster):
		_select_cluster(_open_cluster)
		_isolated = _open_cluster
		_rebuild_stage()

# --- layout / render ------------------------------------------------------------------------------

func _layout() -> void:
	var vp := get_viewport_rect().size
	var canvas := M.canvas_size(doc)
	var avail := Vector2(vp.x - SIDEBAR_W, vp.y)
	var s := maxf(minf(avail.x / canvas.x, avail.y / canvas.y), 0.02)   # never zero/negative (tiny or headless viewports)
	_stage.position = Vector2((avail.x - canvas.x * s) * 0.5, (vp.y - canvas.y * s) * 0.5)
	_stage.size = canvas * s
	_layers.scale = Vector2(s, s)
	_overlay.scale = Vector2(s, s)
	if _sidebar_panel != null:
		_sidebar_panel.position = Vector2(vp.x - SIDEBAR_W, 0)
		_sidebar_panel.size = Vector2(SIDEBAR_W, vp.y)
	_overlay.queue_redraw()

## Detach + queue_free a container's children. All of these rebuilds are reachable from a child
## Button's own `pressed` handler, so a hard free() would destroy the object MID-SIGNAL-EMISSION
## (Godot: "Object was freed or unreferenced while a signal is being emitted"); detaching first
## keeps this frame's layout clean and the deferred free lands after the emission unwinds.
static func _clear_children(box: Node) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()

func _rebuild_stage() -> void:
	_clear_children(_layers)
	var base_rel := String((doc.get("base", {}) as Dictionary).get("image", ""))
	if base_rel != "":
		var b := _make_layer(base_rel, Rect2(Vector2.ZERO, M.canvas_size(doc)))
		if b != null:
			_layers.add_child(b)
	for i in M.sorted_order(doc):
		var e: Dictionary = M.placements(doc)[i]
		var n := _make_layer(String(e.get("image", "")), M.entry_rect(e))
		if n == null:
			n = TextureRect.new()                    # missing art still occupies its rect (pickable via list)
			var r := M.entry_rect(e)
			n.position = r.position
			n.size = r.size
		n.set_meta("pi", i)
		if _isolated != "" and M.cluster_of(doc, i) != _isolated:
			n.modulate = Color(1, 1, 1, 0.22)        # isolation: the rest of the scene ghosts for context
		_layers.add_child(n)
	_refresh_placed_list()
	_refresh_cluster_list()
	_refresh_status()
	_overlay.queue_redraw()

func _make_layer(rel: String, rect: Rect2) -> TextureRect:
	var t := _texture(rel)
	if t == null:
		return null
	var n := TextureRect.new()
	n.texture = t
	n.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	n.stretch_mode = TextureRect.STRETCH_SCALE
	n.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	n.position = rect.position
	n.size = rect.size
	return n

## Refresh ONE moved/resized entry without rebuilding everything (drag feel).
func _refresh_entry_rect(i: int) -> void:
	for n in _layers.get_children():
		if n.has_meta("pi") and int(n.get_meta("pi")) == i:
			var r := M.entry_rect(M.placements(doc)[i])
			n.position = r.position
			n.size = r.size
	_overlay.queue_redraw()
	_refresh_status()

func _texture(rel: String) -> Texture2D:
	var abs := repo_root + "/" + rel
	if _tex.has(abs):
		return _tex[abs] if _tex[abs] is Texture2D else null
	var img := Image.load_from_file(abs) if FileAccess.file_exists(abs) else null
	if img == null:
		_tex[abs] = false
		return null
	var t := ImageTexture.create_from_image(img)
	_tex[abs] = t
	var hit := img
	if img.get_width() > HIT_MAX_W:
		hit = img.duplicate()
		hit.resize(HIT_MAX_W, maxi(1, img.get_height() * HIT_MAX_W / img.get_width()))
	_hit[abs] = hit
	return t

func _opaque_at(i: int, uv: Vector2) -> bool:
	var abs := repo_root + "/" + String((M.placements(doc)[i] as Dictionary).get("image", ""))
	if not _hit.has(abs):
		return true                                  # no image → the whole rect is grabbable
	var img: Image = _hit[abs]
	var px := Vector2i(clampi(int(uv.x * img.get_width()), 0, img.get_width() - 1),
		clampi(int(uv.y * img.get_height()), 0, img.get_height() - 1))
	return img.get_pixel(px.x, px.y).a > 0.05

func _draw_overlay() -> void:
	var s: float = maxf(_overlay.scale.x, 0.001)
	if _sel_cluster != "":
		for i in M.clusters(doc).get(_sel_cluster, []):
			_overlay.draw_rect(M.entry_rect(M.placements(doc)[i]), Color("#5FB56B"), false, 2.0 / s)
		var bb: Rect2 = M.cluster_bbox(doc, _sel_cluster)
		_overlay.draw_rect(bb, Color("#FFB12E"), false, 3.0 / s)
		_overlay.draw_circle(Vector2(bb.position.x + bb.size.x * 0.5, bb.end.y), 6.0 / s, Color("#FFB12E"))
		return
	if _sel < 0 or _sel >= M.placements(doc).size():
		return
	var r: Rect2 = M.entry_rect(M.placements(doc)[_sel])
	_overlay.draw_rect(r, Color("#FFB12E"), false, 3.0 / s)
	_overlay.draw_circle(Vector2(r.position.x + r.size.x * 0.5, r.end.y), 6.0 / s, Color("#FFB12E"))

# --- input ----------------------------------------------------------------------------------------
# The STAGE is the mouse-input surface (gui_input, the repo's testable pattern — cf. the map scene's
# _on_input): events arrive in stage-local coords, /scale = canvas coords, and tests drive
# _on_stage_input directly. Keys stay on _unhandled_input (sidebar buttons are FOCUS_NONE).

func _on_stage_input(ev: InputEvent) -> void:
	var s := maxf(_layers.scale.x, 0.001)
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		var p := mb.position / s
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				var hit := M.hit_at(doc, p, _opaque_at)
				if _isolated != "" and hit >= 0 and M.cluster_of(doc, hit) != _isolated:
					hit = -1                          # ghosted scenery is context, not clickable
				var cl := M.cluster_of(doc, hit) if hit >= 0 else ""
				if mb.alt_pressed and cl != "":
					_select_cluster(cl)               # Alt+click grabs the whole group
				elif _sel_cluster != "" and cl == _sel_cluster:
					pass                              # keep the cluster selection — drag moves the group
				else:
					_select(hit)
				_dragging = hit >= 0 or _sel_cluster != ""
				_drag_last = p
				if _sel >= 0:
					var e: Dictionary = M.placements(doc)[_sel]
					_drag_grab = Vector2(float(e.get("x", 0)), float(e.get("y", 0))) - p
			else:
				_dragging = false
		elif mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			var up := mb.button_index == MOUSE_BUTTON_WHEEL_UP
			var f := (1.10 if up else 0.90) if mb.shift_pressed else (1.02 if up else 0.98)
			if _sel_cluster != "":
				M.scale_cluster(doc, _sel_cluster, f)
				_mark_dirty()
				_refresh_cluster_rects()
			elif _sel >= 0:
				M.scale_by(doc, _sel, f)
				_mark_dirty()
				_refresh_entry_rect(_sel)
	elif ev is InputEventMouseMotion and _dragging:
		var p := (ev as InputEventMouseMotion).position / s
		if _sel_cluster != "":
			M.move_cluster(doc, _sel_cluster, p - _drag_last)
			_drag_last = p
			_mark_dirty()
			_refresh_cluster_rects()
		elif _sel >= 0:
			M.set_pos(doc, _sel, p + _drag_grab)
			_mark_dirty()
			_refresh_entry_rect(_sel)

func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and (ev as InputEventKey).pressed:
		_key(ev as InputEventKey)

func _key(k: InputEventKey) -> void:
	var step := 10.0 if k.shift_pressed else 1.0
	var zstep := 10 if k.shift_pressed else 1
	match k.keycode:
		KEY_S:
			if k.meta_pressed or k.ctrl_pressed:
				_save()
		KEY_R:
			_reload()
		KEY_I:
			_toggle_isolation()
		KEY_ESCAPE:
			if _isolated != "":
				_isolated = ""
				_rebuild_stage()
			_select(-1)
		_:
			if _sel < 0 and _sel_cluster == "":
				return
			match k.keycode:
				KEY_LEFT: _nudge(Vector2(-step, 0))
				KEY_RIGHT: _nudge(Vector2(step, 0))
				KEY_UP: _nudge(Vector2(0, -step))
				KEY_DOWN: _nudge(Vector2(0, step))
				KEY_Z: _bump_z(-zstep)
				KEY_X: _bump_z(zstep)
				KEY_DELETE, KEY_BACKSPACE: _remove_selected()

func _nudge(d: Vector2) -> void:
	if _sel_cluster != "":
		M.move_cluster(doc, _sel_cluster, d)
		_mark_dirty()
		_refresh_cluster_rects()
	elif _sel >= 0:
		M.move(doc, _sel, d)
		_mark_dirty()
		_refresh_entry_rect(_sel)

func _bump_z(dz: int) -> void:
	if _sel_cluster != "":
		M.bump_cluster_z(doc, _sel_cluster, dz)
	elif _sel >= 0:
		M.bump_z(doc, _sel, dz)
	else:
		return
	_mark_dirty()
	_rebuild_stage()                                  # paint order changed

func _remove_selected() -> void:
	if _sel < 0:
		return                                        # a cluster never bulk-deletes — remove members one by one
	M.remove_at(doc, _sel)
	_sel = -1
	_mark_dirty()
	_rebuild_stage()

## Positions/sizes of every member of the selected cluster (drag/scale feel — no full rebuild).
func _refresh_cluster_rects() -> void:
	for i in M.clusters(doc).get(_sel_cluster, []):
		_refresh_entry_rect(i)
	_refresh_status()

func _toggle_isolation() -> void:
	var target := _sel_cluster
	if target == "" and _sel >= 0:
		target = M.cluster_of(doc, _sel)
	if target == "":
		return
	_isolated = "" if _isolated == target else target
	if _isolated != "":
		_select_cluster(_isolated)
	_rebuild_stage()

func _add_asset(a: Dictionary) -> void:
	var canvas := M.canvas_size(doc)
	var t := _texture(String(a.image))
	var sz := Vector2(300, 300) if t == null else Vector2(t.get_size())
	var cap := canvas.y * 0.35                        # a new drop lands readable, never scene-swallowing
	if sz.y > cap:
		sz *= cap / sz.y
	var entry := {"id": String(a.id), "category": String(a.category), "image": String(a.image),
		"x": int(canvas.x / 2.0), "y": int(canvas.y * 0.7), "w": int(sz.x), "h": int(sz.y), "layer": ""}
	if _isolated != "":
		entry["cluster"] = _isolated                  # building a cluster alone → new pieces join it
	var i := M.add_entry(doc, entry)
	_mark_dirty()
	_rebuild_stage()
	_select(i)

# --- selection / save -----------------------------------------------------------------------------

func _select(i: int) -> void:
	_sel = i
	_sel_cluster = ""
	_refresh_placed_list()
	_refresh_cluster_list()
	_refresh_status()
	_overlay.queue_redraw()

func _select_cluster(name: String) -> void:
	_sel = -1
	_sel_cluster = name
	_refresh_placed_list()
	_refresh_cluster_list()
	_refresh_status()
	_overlay.queue_redraw()

func _mark_dirty() -> void:
	dirty = true
	_refresh_status()

func _save() -> void:
	if M.save_doc(placements_path, doc):
		dirty = false
	_refresh_status()

func _reload() -> void:
	doc = M.load_doc(placements_path)
	_sel = -1
	dirty = false
	_rebuild_stage()

func _refresh_status() -> void:
	if _status == null:
		return
	_status.text = "%s%s" % [scene_name, "  •  UNSAVED" if dirty else ""]
	if _save_btn != null:
		_save_btn.text = "Save (⌘S)" + ("  •" if dirty else "")
	if _info == null:
		return
	if _sel_cluster != "":
		var idx: Array = M.clusters(doc).get(_sel_cluster, [])
		var bb: Rect2 = M.cluster_bbox(doc, _sel_cluster)
		_info.text = "CLUSTER %s  (%d items)%s\nbbox %d,%d  %d×%d\ndrag/wheel/Z/X act on the group · I isolates" % [
			_sel_cluster, idx.size(), "  •  ISOLATED" if _isolated == _sel_cluster else "",
			int(bb.position.x), int(bb.position.y), int(bb.size.x), int(bb.size.y)]
		return
	if _sel < 0 or _sel >= M.placements(doc).size():
		_info.text = "click an item to select · Alt+click its cluster\ndrag move · wheel resize · Z/X z-order\narrows nudge · Delete remove · R reload"
		return
	var e: Dictionary = M.placements(doc)[_sel]
	var cl := String(e.get("cluster", ""))
	_info.text = "%s  (%s)\nx %d   y %d\nw %d   h %d\nz %d   %s%s" % [String(e.get("id", "")),
		String(e.get("category", "")), int(e.get("x", 0)), int(e.get("y", 0)),
		int(e.get("w", 0)), int(e.get("h", 0)), int(e.get("z", 0)), String(e.get("layer", "")),
		"\ncluster: " + cl if cl != "" else ""]

# --- sidebar --------------------------------------------------------------------------------------

var _sidebar_panel: PanelContainer = null

func _build_sidebar() -> void:
	_sidebar_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	_sidebar_panel.add_theme_stylebox_override("panel", sb)
	add_child(_sidebar_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_sidebar_panel.add_child(scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 8)
	scroll.add_child(col)

	_status = _label("", 20, true)
	col.add_child(_status)
	_save_btn = Button.new()
	_save_btn.focus_mode = Control.FOCUS_NONE          # keys stay on the stage (arrows nudge, not focus-walk)
	_save_btn.pressed.connect(_save)
	col.add_child(_save_btn)
	_info = _label("", 14)
	col.add_child(_info)

	col.add_child(_label("Clusters", 16, true))
	_cluster_actions = VBoxContainer.new()
	_cluster_actions.add_theme_constant_override("separation", 2)
	col.add_child(_cluster_actions)
	_cluster_box = VBoxContainer.new()
	_cluster_box.add_theme_constant_override("separation", 2)
	col.add_child(_cluster_box)

	col.add_child(_label("Placed (paint order)", 16, true))
	_placed_box = VBoxContainer.new()
	_placed_box.add_theme_constant_override("separation", 2)
	col.add_child(_placed_box)

	col.add_child(_label("Add from bundle", 16, true))
	_add_box = VBoxContainer.new()
	_add_box.add_theme_constant_override("separation", 2)
	col.add_child(_add_box)
	for a in M.addable_assets(bundle_dir, repo_root, scene_name):
		var b := Button.new()
		b.text = "+ %s  (%s)" % [String(a.id), String(a.category)]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 13)
		b.pressed.connect(_add_asset.bind(a))
		_add_box.add_child(b)
	_refresh_status()

## The cluster section: action buttons for the current selection + one row per cluster.
func _refresh_cluster_list() -> void:
	if _cluster_box == null:
		return
	_clear_children(_cluster_actions)
	_clear_children(_cluster_box)
	if _sel >= 0:
		var cl := M.cluster_of(doc, _sel)
		if cl == "":
			_cluster_actions.add_child(_small_button("● New cluster from selection", func() -> void:
				var cname := M.unique_cluster_name(doc, String((M.placements(doc)[_sel] as Dictionary).get("id", "item")) + "_cluster")
				M.set_cluster(doc, _sel, cname)
				_mark_dirty()
				_select_cluster(cname)))
		else:
			_cluster_actions.add_child(_small_button("○ Untag from '%s'" % cl, func() -> void:
				M.set_cluster(doc, _sel, "")
				_mark_dirty()
				_select(_sel)))
	if _sel_cluster != "" or (_sel >= 0 and M.cluster_of(doc, _sel) != ""):
		_cluster_actions.add_child(_small_button(
			"▣ Exit isolation (I)" if _isolated != "" else "▣ Isolate (I)", _toggle_isolation))
	var cls := M.clusters(doc)
	for cname_v in cls.keys():
		var cname := String(cname_v)
		var row := HBoxContainer.new()
		var b := _small_button("%s%s  (%d)" % ["▸ " if cname == _sel_cluster else "  ", cname, (cls[cname] as Array).size()],
			_select_cluster.bind(cname))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if cname == _sel_cluster:
			b.add_theme_color_override("font_color", Color("#B05A00"))
		row.add_child(b)
		if _sel >= 0 and M.cluster_of(doc, _sel) != cname:
			var join := _small_button("+", func() -> void:
				M.set_cluster(doc, _sel, cname)
				_mark_dirty()
				_select(_sel))
			join.tooltip_text = "add the selected item to this cluster"
			row.add_child(join)
		_cluster_box.add_child(row)

func _small_button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 13)
	b.pressed.connect(on_press)
	return b

func _refresh_placed_list() -> void:
	if _placed_box == null:
		return
	_clear_children(_placed_box)
	var order := M.sorted_order(doc)
	for k in range(order.size() - 1, -1, -1):          # topmost first, like layers panels read
		var i: int = order[k]
		var e: Dictionary = M.placements(doc)[i]
		var b := Button.new()
		var cl_tag := "" if String(e.get("cluster", "")) == "" else "  ◆" + String(e.get("cluster", ""))
		b.text = "%s%s   z%d%s" % ["▸ " if i == _sel else "  ", String(e.get("id", "?")), int(e.get("z", 0)), cl_tag]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 13)
		if i == _sel:
			b.add_theme_color_override("font_color", Color("#B05A00"))
		b.pressed.connect(_select.bind(i))
		_placed_box.add_child(b)

func _label(text: String, size: int, bold := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", INK)
	if bold:
		l.add_theme_color_override("font_color", INK.darkened(0.2))
	return l
