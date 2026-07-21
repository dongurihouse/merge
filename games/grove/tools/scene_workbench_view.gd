extends Control
## Scene-placement workbench — the interactive surface over scene_workbench_model.gd.
## Left: the scene stage (fit to window). Right: sidebar — the scene dropdown, save, and the
## CLUSTER list (the ONLY unit of work): selecting a cluster expands its member rows, each with a
## ✕ remove; clicking a member selects that single item for move/resize on the stage.
##
## The model is CLUSTER-FIRST: a stage click selects the whole cluster under the point (an untagged
## entry acts as its own one-item cluster). Members are edited inside ISOLATION (I), where clicks
## pick individual members and added assets join the cluster. Alt+click force-picks a single item.
##
## Mouse:  click = select cluster (alpha-aware, topmost)   drag = move   wheel = resize ±2% (Shift ±10%)
## Keys:   arrows = nudge 1px (Shift 10)   Z / X = order −1 / +1 within the current level (Shift 10):
##         a cluster selection restacks the cluster in its layer, an item selection restacks it in its
##         cluster.   [ / ] = move the selection to the previous / next LAYER (cluster-wide).
##         Delete = remove item   I = isolate   Cmd/Ctrl+S = save   R = reload   Esc = deselect / exit

const M = preload("res://games/grove/tools/scene_workbench_model.gd")
const PropShadow = preload("res://engine/scripts/ui/prop_shadow.gd")   # the game's dynamic silhouette shadow
const FS = preload("res://engine/scripts/core/tuning.gd").FontScale

const SIDEBAR_W := 340.0
const REF_STRIP_W := 76.0           # the far-left mock ICON strip (one thumbnail per reference)
const REF_PAD := 14.0               # reference pane inner padding
const SCENE_STRIP_W := 76.0         # the far-right SCENE icon strip (one thumbnail per bundle)
const HIT_MAX_W := 192              # alpha hit-test images downsample to this width (memory)
const DRAG_THRESHOLD := 3.0         # canvas px a re-click must travel before it counts as a drag, not a deselect
const INK := Color("#2B2B33")
const PAPER := Color("#F4EDE1")

var doc: Dictionary = {}
var placements_path := ""
var repo_root := ""
var bundle_dir := ""
var scene_name := ""
var dirty := false

var _tex: Dictionary = {}           # abs path -> Texture2D (null cached as false)
var _placed_tex: Dictionary = {}    # source + crop/feather contract -> placed Texture2D
var _thumb: Dictionary = {}         # abs path -> small ImageTexture for the add-palette rows
var _hit: Dictionary = {}           # abs path -> downsampled Image for alpha tests
var _placed_hit: Dictionary = {}    # placed texture contract -> downsampled Image for alpha tests
var _sel := -1                      # index into doc.placements (item selection)
var _sel_cluster := ""              # cluster selection — mutually exclusive with _sel
var _isolated := ""                 # isolation: this cluster edits alone, the rest of the scene ghosts
var _dragging := false
var _drag_grab := Vector2.ZERO      # canvas-space offset from the entry anchor at grab time
var _drag_last := Vector2.ZERO      # last canvas point (cluster drags are delta-based)
var _pending_deselect := false      # armed on re-clicking the selected cluster; a real drag cancels it
var _press_point := Vector2.ZERO    # canvas point of the current left press (deselect-vs-drag threshold)
var _hidden: Dictionary = {}        # workbench-only: cluster name -> true; not persisted, cleared on reload
var _hidden_layers: Dictionary = {} # workbench-only: layer slug -> true; not persisted, cleared on reload
var _base_hidden := false           # workbench-only: hide the opaque `base` backdrop (the sky); reset on reload

var _stage: Control = null
var _layers: Control = null         # one TextureRect per placement, child order = paint order
var _overlay: Control = null        # selection outline
var _save_btn: Button = null
var _cluster_box: VBoxContainer = null
var _cluster_actions: VBoxContainer = null
var _open_cluster := ""             # CLUSTER= launch arg — select + isolate once ready
var _scenes_root := ""              # kept so the scene dropdown can re-setup in place

func setup(scenes_root: String, scene: String, cluster := "") -> bool:
	_scenes_root = scenes_root
	scene_name = scene
	_open_cluster = cluster
	bundle_dir = M.bundle_for(scenes_root, scene)
	if bundle_dir == "":
		push_error("no map/<scene>/placements.json for scene '%s' under %s" % [scene, scenes_root])
		return false
	repo_root = M.repo_root_of(scenes_root)
	placements_path = M.placements_path(scenes_root, scene)
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
	_build_ref_panel()
	_build_scene_strip()
	_rebuild_stage()
	if get_viewport() != null:                         # null under the suites' manual-_ready convention
		get_viewport().size_changed.connect(_layout)
	_layout()
	if _open_cluster != "" and M.clusters(doc).has(_open_cluster):
		_select_cluster(_open_cluster)
		_isolated = _open_cluster
		_rebuild_stage()

# --- layout / render ------------------------------------------------------------------------------

## The reference pane's width follows the SELECTED mock: icon strip + the mock fitted FULL-HEIGHT
## (as tall as the sidebar), so the reference reads at the same scale as the working canvas.
func _ref_pane_w(vp: Vector2) -> float:
	if _ref_paths.is_empty():
		return REF_STRIP_W + REF_PAD * 2.0
	return REF_STRIP_W + (vp.y - 44.0) * _ref_aspect + REF_PAD * 2.0

func _layout() -> void:
	var vp := get_viewport_rect().size
	var canvas := M.canvas_size(doc)
	var ref_w := _ref_pane_w(vp)
	var avail := Vector2(vp.x - SIDEBAR_W - SCENE_STRIP_W - ref_w, vp.y)   # stage sits between references and sidebar
	var s := maxf(minf(avail.x / canvas.x, avail.y / canvas.y), 0.02)   # never zero/negative (tiny or headless viewports)
	_stage.position = Vector2(ref_w + (avail.x - canvas.x * s) * 0.5, (vp.y - canvas.y * s) * 0.5)
	_stage.size = canvas * s
	_layers.scale = Vector2(s, s)
	_overlay.scale = Vector2(s, s)
	if _sidebar_panel != null:
		_sidebar_panel.position = Vector2(vp.x - SCENE_STRIP_W - SIDEBAR_W, 0)
		_sidebar_panel.size = Vector2(SIDEBAR_W, vp.y)
	if _scene_strip_panel != null:
		_scene_strip_panel.position = Vector2(vp.x - SCENE_STRIP_W, 0)
		_scene_strip_panel.size = Vector2(SCENE_STRIP_W, vp.y)
		var strip: Control = _scene_strip_panel.get_node_or_null("SceneStrip")
		if strip != null:
			strip.position = Vector2(REF_PAD, 36.0)
			strip.size = Vector2(SCENE_STRIP_W - REF_PAD, vp.y - 44.0)
	if _ref_panel != null:
		_ref_panel.position = Vector2.ZERO
		_ref_panel.size = Vector2(ref_w, vp.y)
		if _ref_strip != null:
			_ref_strip.position = Vector2(REF_PAD, 36.0)
			_ref_strip.size = Vector2(REF_STRIP_W - REF_PAD, vp.y - 44.0)
		if _ref_img != null:
			_ref_img.position = Vector2(REF_STRIP_W + REF_PAD, 36.0)
			_ref_img.size = Vector2((vp.y - 44.0) * _ref_aspect, vp.y - 44.0)
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
	if base_rel != "" and not _base_hidden:           # the base (sky) is hidable like any other layer
		var b := _make_layer(base_rel, Rect2(Vector2.ZERO, M.canvas_size(doc)))
		if b != null:
			_layers.add_child(b)
	for i in M.sorted_order(doc):
		var e: Dictionary = M.placements(doc)[i]
		if _is_hidden(i):
			continue                                 # workbench-only: cluster or layer hidden
		var n := _make_layer(String(e.get("image", "")), M.entry_rect(e), e)
		if n == null:
			n = TextureRect.new()                    # missing art still occupies its rect (pickable via list)
			var r := M.entry_rect(e)
			n.position = r.position
			n.size = r.size
		n.set_meta("pi", i)
		var ghosted := _isolated != "" and M.cluster_of(doc, i) != _isolated
		if ghosted:
			n.modulate = Color(1, 1, 1, 0.22)        # isolation: the rest of the scene ghosts for context
		if bool(e.get("shadow", false)) and n.texture != null:
			var sh: Control = PropShadow.new()       # the SAME dynamic shadow the game renders
			sh.texture = n.texture
			sh.disp = M.entry_rect(e).size
			sh.modulate.a = clampf(float(e.get("shadowOpacity", 1.0)), 0.0, 1.0)
			sh.position = Vector2(float(e.get("x", 0)), float(e.get("y", 0)))
			sh.set_meta("pi_shadow", i)
			if ghosted:
				sh.modulate = Color(1, 1, 1, 0.22)
			_layers.add_child(sh)                    # added just before its prop → paints beneath it
		_layers.add_child(n)
	_refresh_cluster_list()
	_refresh_status()
	_overlay.queue_redraw()

func _make_layer(rel: String, rect: Rect2, entry := {}) -> TextureRect:
	var t := _placed_texture(rel, entry)
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
	var e: Dictionary = M.placements(doc)[i]
	var r := M.entry_rect(e)
	for n in _layers.get_children():
		if n.has_meta("pi") and int(n.get_meta("pi")) == i:
			n.position = r.position
			n.size = r.size
		elif n.has_meta("pi_shadow") and int(n.get_meta("pi_shadow")) == i:
			n.position = Vector2(float(e.get("x", 0)), float(e.get("y", 0)))   # the shadow rides the footing
			n.set("disp", r.size)
			(n as Control).queue_redraw()
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

## A placement can use only part of a source plate, then fade its cropped bottom edge into
## the foundation. This is deliberately resolved before constructing the TextureRect so the
## live workbench, alpha hit-testing, and deterministic compositor share one placement contract.
func _placed_texture(rel: String, entry: Dictionary) -> Texture2D:
	var crop = entry.get("sourceCrop")
	var feather = entry.get("sourceCropFeatherBottom")
	if crop == null and feather == null:
		return _texture(rel)
	var abs := repo_root + "/" + rel
	var key := abs + "|" + JSON.stringify(crop) + "|" + JSON.stringify(feather)
	if _placed_tex.has(key):
		return _placed_tex[key] if _placed_tex[key] is Texture2D else null
	var source := _texture(rel)
	if source == null:
		_placed_tex[key] = false
		return null
	var image := source.get_image()
	if crop is Array and crop.size() == 4:
		var left := int(crop[0])
		var top := int(crop[1])
		var width := int(crop[2])
		var height := int(crop[3])
		if left >= 0 and top >= 0 and width > 0 and height > 0 \
			and left + width <= image.get_width() and top + height <= image.get_height():
			image = image.get_region(Rect2i(left, top, width, height))
	# JSON parses every number as a float. Round numeric values to the same whole-pixel
	# contract used by placement geometry, while keeping invalid/negative values inert.
	var feather_px := maxi(0, int(round(float(feather)))) if feather is int or feather is float else 0
	if feather_px > 0 and feather_px <= image.get_height():
		var start := image.get_height() - feather_px
		for y in range(start, image.get_height()):
			var opacity := float(image.get_height() - 1 - y) / float(maxi(1, feather_px - 1))
			for x in range(image.get_width()):
				var px := image.get_pixel(x, y)
				image.set_pixel(x, y, Color(px.r, px.g, px.b, px.a * opacity))
	var placed := ImageTexture.create_from_image(image)
	_placed_tex[key] = placed
	return placed

func _opaque_at(i: int, uv: Vector2) -> bool:
	var entry: Dictionary = M.placements(doc)[i]
	var rel := String(entry.get("image", ""))
	var key := repo_root + "/" + rel + "|" + JSON.stringify(entry.get("sourceCrop")) + "|" + JSON.stringify(entry.get("sourceCropFeatherBottom"))
	if not _placed_hit.has(key):
		var texture := _placed_texture(rel, entry)
		if texture == null:
			return true                                  # no image → the whole rect is grabbable
		var image := texture.get_image()
		if image.get_width() > HIT_MAX_W:
			image.resize(HIT_MAX_W, maxi(1, image.get_height() * HIT_MAX_W / image.get_width()))
		_placed_hit[key] = image
	var img: Image = _placed_hit[key]
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
				var hit := M.hit_at(doc, p, _opaque_at, _hidden, _hidden_layers)
				if mb.shift_pressed:
					_shift_click(hit)                 # membership painting — never starts a drag
					return
				if _isolated != "" and hit >= 0 and M.cluster_of(doc, hit) != _isolated:
					hit = -1                          # ghosted scenery is context, not clickable
				var cl := M.cluster_of(doc, hit) if hit >= 0 else ""
				_pending_deselect = false
				_press_point = p
				# CLUSTER-FIRST: a click selects the whole group; members are picked inside
				# isolation, with Alt, or via the sidebar member rows. An untagged entry is
				# its own unit; the already-selected member drags directly.
				if hit >= 0 and hit == _sel:
					pass                              # keep the member selection — drag moves just it
				elif _isolated != "" or mb.alt_pressed or cl == "":
					_select(hit)
				elif cl != _sel_cluster:
					_select_cluster(cl)
				else:
					# the selected cluster was clicked again — a plain click deselects, a drag moves
					# the group. Arm the deselect; the first past-threshold motion cancels it.
					_pending_deselect = true
				_dragging = hit >= 0 or _sel_cluster != ""
				_drag_last = p
				if _sel >= 0:
					var e: Dictionary = M.placements(doc)[_sel]
					_drag_grab = Vector2(float(e.get("x", 0)), float(e.get("y", 0))) - p
			else:
				if _pending_deselect:
					_select(-1)                       # click-again on the selected cluster, no drag
				_pending_deselect = false
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
		if _pending_deselect:
			if p.distance_to(_press_point) < DRAG_THRESHOLD:
				return                                # sub-threshold jitter is still a click, not a drag
			_pending_deselect = false                 # crossed the threshold — this is a drag
		if _sel_cluster != "":
			M.move_cluster(doc, _sel_cluster, p - _drag_last)
			_drag_last = p
			_mark_dirty()
			_refresh_cluster_rects()
		elif _sel >= 0:
			M.set_pos(doc, _sel, p + _drag_grab)
			_mark_dirty()
			_refresh_entry_rect(_sel)

## Shift+click PAINTS cluster membership right on the stage:
##   · a cluster is in context (selected or isolated) → assign the clicked item INTO it (join/move,
##     never orphan — every placement always belongs to exactly one cluster)
##   · a single item is selected and another is clicked → a NEW cluster is born from the pair
##   · nothing selected → plain select (so a stray Shift never surprises)
## Ghosted items are clickable here on purpose — painting scenery INTO the isolated cluster.
func _shift_click(hit: int) -> void:
	if hit < 0:
		return
	var target := _sel_cluster
	if target == "":
		target = _isolated
	if target == "" and _sel >= 0:
		target = M.cluster_of(doc, _sel)
	if target != "":
		# JOIN / MOVE only — shift-click assigns the item to the in-context cluster. It never
		# removes an item to nothing: a placement always belongs to exactly one cluster (to move
		# it elsewhere, select the other cluster and shift-click it there).
		if M.cluster_of(doc, hit) != target:
			M.set_cluster(doc, hit, target)
			_mark_dirty()
			_rebuild_stage()
		_select_cluster(target)
	elif _sel >= 0 and _sel != hit:
		var cname := M.unique_cluster_name(doc,
			String((M.placements(doc)[_sel] as Dictionary).get("id", "item")) + "_cluster")
		M.set_cluster(doc, _sel, cname)
		M.set_cluster(doc, hit, cname)
		_mark_dirty()
		_rebuild_stage()
		_select_cluster(cname)
	else:
		_select(hit)

func _new_cluster_from_selection() -> void:
	if _sel < 0:
		return
	var cname := M.unique_cluster_name(doc,
		String((M.placements(doc)[_sel] as Dictionary).get("id", "item")) + "_cluster")
	M.set_cluster(doc, _sel, cname)
	_mark_dirty()
	_select_cluster(cname)

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
		KEY_N:
			_new_cluster_from_selection()
		KEY_H:
			_hide_selected_cluster()
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
				KEY_BRACKETLEFT: _bump_layer(-1)
				KEY_BRACKETRIGHT: _bump_layer(1)
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

## [ / ] move the selection to an adjacent LAYER — cluster-wide (a cluster never straddles layers).
func _bump_layer(dir: int) -> void:
	var i := _sel
	if _sel_cluster != "":
		var members: Array = M.clusters(doc).get(_sel_cluster, [])
		if members.is_empty():
			return
		i = members[0]
	if i < 0:
		return
	M.bump_layer(doc, i, dir)
	_mark_dirty()
	_rebuild_stage()

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

# --- selection / save -----------------------------------------------------------------------------

func _select(i: int) -> void:
	_sel = i
	_sel_cluster = ""
	_refresh_cluster_list()
	_refresh_status()
	_overlay.queue_redraw()

func _select_cluster(name: String) -> void:
	_sel = -1
	_sel_cluster = name
	_refresh_cluster_list()
	_refresh_status()
	_overlay.queue_redraw()

## --- hiding (workbench-only view state; never written to the doc) ---------------------------------

func _is_hidden(i: int) -> bool:
	var e: Dictionary = M.placements(doc)[i]
	return _hidden.has(M.cluster_of(doc, i)) or _hidden_layers.has(M.entry_layer(e))

func _selected_cluster() -> String:
	if _sel_cluster != "":
		return _sel_cluster
	if _sel >= 0:
		return M.cluster_of(doc, _sel)
	return ""

func _hide_selected_cluster() -> void:
	var name := _selected_cluster()
	if name == "":
		return
	_toggle_cluster_hidden(name, true)

func _toggle_cluster_hidden(name: String, force_hide := false) -> void:
	if name == "":
		return
	if not force_hide and _hidden.has(name):
		_hidden.erase(name)
	else:
		_hidden[name] = true
		if _selected_cluster() == name:
			_select(-1)                              # cannot edit what is not shown
	_rebuild_stage()

func _toggle_base_hidden() -> void:
	_base_hidden = not _base_hidden
	_rebuild_stage()

func _toggle_layer_hidden(slug: String) -> void:
	if _hidden_layers.has(slug):
		_hidden_layers.erase(slug)
	else:
		_hidden_layers[slug] = true
		var sc := _selected_cluster()
		var sel_i := -1
		if sc != "":
			var mm: Array = M.clusters(doc).get(sc, [])
			sel_i = mm[0] if not mm.is_empty() else -1
		elif _sel >= 0:
			sel_i = _sel
		if sel_i >= 0 and M.entry_layer(M.placements(doc)[sel_i]) == slug:
			_select(-1)
	_rebuild_stage()

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
	_sel_cluster = ""
	_hidden.clear()                                  # hiding is workbench-only view state — reload shows all
	_hidden_layers.clear()
	_base_hidden = false
	dirty = false
	_rebuild_stage()

func _refresh_status() -> void:
	if _save_btn != null:
		_save_btn.text = "Save (⌘S)" + ("  •  UNSAVED" if dirty else "")

# --- the LEFT reference column: the scene's mocks + reconstruction composites -----------------------

var _ref_panel: Panel = null
var _ref_paths: Array = []
var _ref_idx := 0                   # the mock the dropdown has picked

var _ref_strip: ScrollContainer = null
var _ref_img: TextureRect = null
var _ref_aspect := 941.0 / 1672.0   # w/h of the selected mock (drives the pane width)
var _ref_big: Dictionary = {}       # abs path -> full-height display texture

func _build_ref_panel() -> void:
	_ref_panel = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER
	_ref_panel.add_theme_stylebox_override("panel", sb)
	add_child(_ref_panel)
	_ref_strip = null
	_ref_img = null
	var head := _label("Reference", FS.TOOL, true)
	head.position = Vector2(REF_PAD, 8)
	_ref_panel.add_child(head)
	_ref_paths = M.reference_images(bundle_dir)
	if _ref_paths.is_empty():
		var none := _label("no mocks found", FS.TOOL)
		none.position = Vector2(REF_PAD, 40)
		_ref_panel.add_child(none)
		return
	_ref_idx = clampi(_ref_idx, 0, _ref_paths.size() - 1)
	# the far-left ICON strip — one thumbnail button per mock, the picked one framed
	_ref_strip = ScrollContainer.new()
	_ref_strip.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var strip_col := VBoxContainer.new()
	strip_col.add_theme_constant_override("separation", 6)
	_ref_strip.add_child(strip_col)
	for i in _ref_paths.size():
		var b := Button.new()
		b.name = "RefIcon_%d" % i
		b.focus_mode = Control.FOCUS_NONE
		b.tooltip_text = String(_ref_paths[i]).get_file()
		b.icon = _thumb_for_abs(String(_ref_paths[i]))
		b.add_theme_constant_override("icon_max_width", int(REF_STRIP_W - REF_PAD - 14.0))
		b.modulate = Color(1, 1, 1, 1.0 if i == _ref_idx else 0.55)
		b.pressed.connect(_show_ref.bind(i))
		strip_col.add_child(b)
	_ref_panel.add_child(_ref_strip)
	_ref_img = TextureRect.new()
	_ref_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ref_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_ref_img.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_ref_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ref_panel.add_child(_ref_img)
	_show_ref(_ref_idx)

## Swap the big mock IN PLACE (no panel rebuild — the strip buttons stay alive) + re-layout,
## since the pane's width follows the mock's aspect.
func _show_ref(i: int) -> void:
	if _ref_paths.is_empty():
		return                                        # a scene without mocks (or a stale strip button)
	_ref_idx = clampi(i, 0, _ref_paths.size() - 1)
	if _ref_strip != null:
		var col: Node = _ref_strip.get_child(0)
		for k in col.get_child_count():
			(col.get_child(k) as Control).modulate = Color(1, 1, 1, 1.0 if k == _ref_idx else 0.55)
	var p := String(_ref_paths[_ref_idx])
	if not _ref_big.has(p):
		var img := Image.load_from_file(p) if FileAccess.file_exists(p) else null
		if img != null and img.get_height() > 2200:    # decode once, hold ~full-height resolution
			img.resize(int(img.get_width() * 2200.0 / img.get_height()), 2200, Image.INTERPOLATE_BILINEAR)
		_ref_big[p] = null if img == null else ImageTexture.create_from_image(img)
	var t: Texture2D = _ref_big[p]
	if _ref_img != null:
		_ref_img.texture = t
	_ref_aspect = (float(t.get_width()) / maxf(float(t.get_height()), 1.0)) if t != null else 941.0 / 1672.0
	_layout()

func _rebuild_ref_panel() -> void:
	if _ref_panel != null:
		_ref_panel.queue_free()
	_build_ref_panel()
	_layout()

## A scene's face for the sidebar icon row — its FIRST reference image (concept mock first).
func _scene_icon(scene: String) -> Texture2D:
	var refs := M.reference_images(M.bundle_for(_scenes_root, scene))
	return _thumb_for_abs(String(refs[0])) if not refs.is_empty() else null

## A strip thumbnail from an ABSOLUTE path (the shared _thumb cache, repo-relative helper below).
func _thumb_for_abs(abs: String) -> Texture2D:
	if _thumb.has(abs):
		return _thumb[abs]
	var img := Image.load_from_file(abs) if FileAccess.file_exists(abs) else null
	if img == null:
		_thumb[abs] = null
		return null
	var w := 60
	img.resize(w, maxi(1, img.get_height() * w / img.get_width()))
	var t := ImageTexture.create_from_image(img)
	_thumb[abs] = t
	return t

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

	col.add_child(_label(scene_name, FS.TOOL, true))

	_save_btn = Button.new()
	_save_btn.focus_mode = Control.FOCUS_NONE          # keys stay on the stage (arrows nudge, not focus-walk)
	_save_btn.pressed.connect(_save)
	col.add_child(_save_btn)

	col.add_child(_label("Clusters", FS.TOOL, true))
	_cluster_actions = VBoxContainer.new()
	_cluster_actions.add_theme_constant_override("separation", 2)
	col.add_child(_cluster_actions)
	_cluster_box = VBoxContainer.new()
	_cluster_box.add_theme_constant_override("separation", 2)
	col.add_child(_cluster_box)
	_refresh_status()

# --- the far-RIGHT scene column: one icon per openable bundle, mirroring the mock strip ------------

var _scene_strip_panel: Panel = null

func _build_scene_strip() -> void:
	_scene_strip_panel = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER
	_scene_strip_panel.add_theme_stylebox_override("panel", sb)
	add_child(_scene_strip_panel)
	var head := _label("Scenes", FS.TOOL, true)
	head.position = Vector2(REF_PAD, 8)
	_scene_strip_panel.add_child(head)
	var scroll := ScrollContainer.new()
	scroll.name = "SceneStrip"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scene_strip_panel.add_child(scroll)
	var strip_col := VBoxContainer.new()
	strip_col.name = "SceneIcons"
	strip_col.add_theme_constant_override("separation", 6)
	scroll.add_child(strip_col)
	var scenes := M.scenes_in(_scenes_root)
	for i in scenes.size():
		var sc := String(scenes[i])
		var b := Button.new()
		b.name = "SceneIcon_" + sc
		b.focus_mode = Control.FOCUS_NONE
		b.tooltip_text = sc
		b.icon = _scene_icon(sc)
		b.add_theme_constant_override("icon_max_width", int(SCENE_STRIP_W - REF_PAD - 14.0))
		b.modulate = Color(1, 1, 1, 1.0 if sc == scene_name else 0.55)
		b.pressed.connect(func() -> void:
			if sc != scene_name:
				_switch_scene.call_deferred(sc))       # deferred — the strip is rebuilt by the switch
		strip_col.add_child(b)

## Switch the workbench to another scene bundle in place. ⌘S is the ONLY writer: unsaved edits
## are DISCARDED on a switch — never silently committed to disk (2026-07-19, after an auto-save
## here surprised the owner by persisting un-⌘S'd moves across a restart).
func _switch_scene(scene: String) -> void:
	if not setup(_scenes_root, scene):
		return
	_sel = -1
	_sel_cluster = ""
	_isolated = ""
	dirty = false
	_tex.clear()
	_hit.clear()
	_thumb.clear()
	_ref_big.clear()
	if _sidebar_panel != null:
		_sidebar_panel.queue_free()
	if _ref_panel != null:
		_ref_panel.queue_free()
	_ref_idx = 0                                       # a new scene starts on its first mock
	if _scene_strip_panel != null:
		_scene_strip_panel.queue_free()
	_build_sidebar()
	_build_ref_panel()
	_build_scene_strip()
	_rebuild_stage()
	_layout()
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_title("Scene workbench — " + scene)

## The cluster section: action buttons for the current selection + one row per cluster; the
## cluster in context (selected, or owning the selected item) expands its MEMBER rows — each
## selects its single item for move/resize, with a ✕ that removes it from the scene.
func _refresh_cluster_list() -> void:
	if _cluster_box == null:
		return
	_clear_children(_cluster_actions)
	_clear_children(_cluster_box)
	if _sel_cluster != "":
		var rn := LineEdit.new()                       # rename in place — Enter applies
		rn.name = "ClusterRename"
		rn.text = _sel_cluster
		rn.tooltip_text = "rename the cluster (Enter applies)"
		rn.add_theme_font_size_override("font_size", FS.TOOL)
		rn.text_submitted.connect(func(t: String) -> void:
			var applied := M.rename_cluster(doc, _sel_cluster, t)
			if applied != "":
				if _isolated == _sel_cluster:
					_isolated = applied
				_mark_dirty()
				_select_cluster.call_deferred(applied))   # deferred — this LineEdit lives in the box being rebuilt
		_cluster_actions.add_child(rn)
	if _sel >= 0:
		var shadow_on := bool((M.placements(doc)[_sel] as Dictionary).get("shadow", false))
		_cluster_actions.add_child(_small_button("◐ Shadow: %s" % ("ON" if shadow_on else "off"), func() -> void:
			M.set_shadow(doc, _sel, not bool((M.placements(doc)[_sel] as Dictionary).get("shadow", false)))
			_mark_dirty()
			_rebuild_stage()
			_select(_sel)))
		# Every placement MUST belong to a cluster (the workbench's only unit of work). A stray
		# untagged item (e.g. from legacy data) can be given its own cluster, but there is no
		# "untag" affordance — nothing in the scene is allowed to become cluster-less.
		if M.cluster_of(doc, _sel) == "":
			_cluster_actions.add_child(_small_button("● New cluster from selection (N)", _new_cluster_from_selection))
	if _sel_cluster != "" or (_sel >= 0 and M.cluster_of(doc, _sel) != ""):
		_cluster_actions.add_child(_small_button(
			"▣ Exit isolation (I)" if _isolated != "" else "▣ Isolate (I)", _toggle_isolation))
	# The selection's layer + the [ / ] hint, so a stage-picked singleton (no sidebar row) still
	# shows where it lives and how to move it between bands.
	var sel_i := -1
	if _sel_cluster != "":
		var mm: Array = M.clusters(doc).get(_sel_cluster, [])
		sel_i = mm[0] if not mm.is_empty() else -1
	elif _sel >= 0:
		sel_i = _sel
	if sel_i >= 0:
		_cluster_actions.add_child(_label(
			"layer: %s   ( [ / ] )" % M.LAYER_LABELS.get(M.entry_layer(M.placements(doc)[sel_i]), "?"), FS.TOOL))
	# the cluster whose members are EXPANDED: the selected one, or the one owning the selected item
	var expanded := _sel_cluster
	if expanded == "" and _sel >= 0:
		expanded = M.cluster_of(doc, _sel)
	# Clusters grouped under the six fixed layers, back → front (sky first, matching the paint stack).
	var by_layer: Dictionary = {}                     # layer slug -> [cluster name] (sorted by clusterZ)
	var cls := M.clusters(doc)
	for cname_v in cls.keys():
		var cn := String(cname_v)
		var lyr: String = M.entry_layer(M.placements(doc)[(cls[cn] as Array)[0]])
		if not by_layer.has(lyr):
			by_layer[lyr] = []
		(by_layer[lyr] as Array).append(cn)
	for names in by_layer.values():
		(names as Array).sort_custom(func(x, y) -> bool: return M.cluster_z(doc, x) < M.cluster_z(doc, y))
	# The opaque `base` backdrop (the sky) paints behind everything and isn't a placement, so it has
	# no cluster — but it still gets a row here with a hide eye, so the whole stage is visible and
	# hidable from the panel (the base can't be selected, restacked, or removed; it's the floor).
	var base_id := String((doc.get("base", {}) as Dictionary).get("id", ""))
	if base_id != "":
		var base_row := HBoxContainer.new()
		var blabel := _label("— Base —  %s" % base_id, FS.TOOL, true)
		blabel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if _base_hidden:
			blabel.add_theme_color_override("font_color", Color("#9A9488"))
		base_row.add_child(blabel)
		var beye := _small_button("◌" if _base_hidden else "◉", _toggle_base_hidden)
		beye.tooltip_text = "show the base backdrop" if _base_hidden else "hide the base backdrop"
		base_row.add_child(beye)
		_cluster_box.add_child(base_row)
	for slug in M.LAYERS:
		var lhidden := _hidden_layers.has(slug)
		var hdr_row := HBoxContainer.new()
		var hdr := _label("— %s —" % M.LAYER_LABELS.get(slug, slug), FS.TOOL, true)
		hdr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if lhidden:
			hdr.add_theme_color_override("font_color", Color("#9A9488"))
		hdr_row.add_child(hdr)
		var leye := _small_button("◌" if lhidden else "◉", _toggle_layer_hidden.bind(slug))
		leye.tooltip_text = "show this layer" if lhidden else "hide the whole layer"
		hdr_row.add_child(leye)
		_cluster_box.add_child(hdr_row)
		for cname in by_layer.get(slug, []):
			var chidden := _hidden.has(cname)
			var row := HBoxContainer.new()
			var b := _small_button("%s%s  (%d)  z%d" % ["▸ " if cname == _sel_cluster else "  ",
				cname, (cls[cname] as Array).size(), M.cluster_z(doc, cname)], _select_cluster.bind(cname))
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.clip_text = true                                # long names clip, never push the eye off-panel
			if cname == _sel_cluster:
				b.add_theme_color_override("font_color", Color("#B05A00"))
			elif chidden:
				b.add_theme_color_override("font_color", Color("#9A9488"))
			row.add_child(b)
			var eye := _small_button("◌" if chidden else "◉", _toggle_cluster_hidden.bind(cname))
			eye.tooltip_text = "show this cluster" if chidden else "hide this cluster"
			row.add_child(eye)
			if _sel >= 0 and M.cluster_of(doc, _sel) != cname:
				var join := _small_button("+", func() -> void:
					M.set_cluster(doc, _sel, cname)
					_mark_dirty()
					_select(_sel))
				join.tooltip_text = "add the selected item to this cluster"
				row.add_child(join)
			_cluster_box.add_child(row)
			if cname != expanded:
				continue
			for k in M.sorted_order(doc):             # member rows, paint order — click = edit that item
				if M.cluster_of(doc, k) != cname:
					continue
				var e: Dictionary = M.placements(doc)[k]
				var mrow := HBoxContainer.new()
				var mb := _small_button("      %s%s   z%d" % ["▸ " if k == _sel else "· ",
					String(e.get("id", "?")), int(e.get("z", 0))], _select.bind(k))
				mb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				mb.clip_text = true
				if k == _sel:
					mb.add_theme_color_override("font_color", Color("#B05A00"))
				mrow.add_child(mb)
				var kill := _small_button("✕", _remove_member.bind(k, cname))
				kill.tooltip_text = "remove this element from the scene"
				mrow.add_child(kill)
				_cluster_box.add_child(mrow)
			if cname == _sel_cluster:
				_add_palette_rows(cname)

## The ADD palette, scoped to the selected cluster: the bundle's assets (plus the surviving page
## art on recovered bundles) as an iconed list — clicking one drops a NEW member at the cluster's
## footing, joined and selected for immediate placement.
func _add_palette_rows(cname: String) -> void:
	_cluster_box.add_child(_label("      add to '%s'" % cname, FS.TOOL, true))
	for a in M.addable_assets(bundle_dir, repo_root, scene_name):
		var b := _small_button("      + " + String(a.id), _add_asset_to_cluster.bind(a, cname))
		b.icon = _thumb_for(String(a.image))
		b.add_theme_constant_override("icon_max_width", 30)
		b.add_theme_constant_override("h_separation", 8)
		_cluster_box.add_child(b)

func _add_asset_to_cluster(a: Dictionary, cname: String) -> void:
	var bb := M.cluster_bbox(doc, cname)
	var foot := Vector2(bb.position.x + bb.size.x * 0.5, bb.end.y) if bb.size != Vector2.ZERO \
		else M.canvas_size(doc) * 0.5
	var t := _texture(String(a.image))
	var sz := Vector2(300, 300) if t == null else Vector2(t.get_size())
	var cap := M.canvas_size(doc).y * 0.25             # a new drop lands readable, never scene-swallowing
	if sz.y > cap:
		sz *= cap / sz.y
	var members: Array = M.clusters(doc).get(cname, [])
	var top_z := 0
	for k in members:
		top_z = maxi(top_z, int((M.placements(doc)[k] as Dictionary).get("z", 0)))
	# The new member inherits the cluster's layer + cluster-order so it lands in the same band,
	# just above the cluster's top item.
	var layer: String = M.entry_layer(M.placements(doc)[members[0]]) if not members.is_empty() else M.DEFAULT_LAYER
	var i := M.add_entry(doc, {"id": String(a.id), "category": String(a.category),
		"image": String(a.image), "x": int(foot.x + 40), "y": int(foot.y),
		"w": int(sz.x), "h": int(sz.y), "z": top_z + 1, "clusterZ": M.cluster_z(doc, cname),
		"cluster": cname, "layer": layer})
	_mark_dirty()
	_rebuild_stage()
	_select(i)                                        # the new member is in hand — drag it into place

## A small palette thumbnail (decoded once per asset, downscaled, cached).
func _thumb_for(rel: String) -> Texture2D:
	var abs := repo_root + "/" + rel
	if _thumb.has(abs):
		return _thumb[abs]
	var img := Image.load_from_file(abs) if FileAccess.file_exists(abs) else null
	if img == null:
		_thumb[abs] = null
		return null
	var w := 60
	img.resize(w, maxi(1, img.get_height() * w / img.get_width()))
	var t := ImageTexture.create_from_image(img)
	_thumb[abs] = t
	return t

## Remove ONE member from the scene (the ✕ on a member row); the cluster stays selected so the
## remaining members keep their list open.
func _remove_member(i: int, cname: String) -> void:
	M.remove_at(doc, i)
	_sel = -1
	_mark_dirty()
	_rebuild_stage()
	if M.clusters(doc).has(cname):
		_select_cluster(cname)
	else:
		_select(-1)                                   # the last member went — the cluster is gone too

func _small_button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", FS.TOOL)
	b.pressed.connect(on_press)
	return b

func _label(text: String, size: int, bold := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", INK)
	if bold:
		l.add_theme_color_override("font_color", INK.darkened(0.2))
	return l
