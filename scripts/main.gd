extends Control
##
## Tidy Up — playable board.
## Drag any item onto a MATCHING item (anywhere) to merge it up the tidy ladder. Locked drawers
## pop open on an adjacent merge; an optional Job Ticket + Shelf give per-board goals. Clear the
## board → the room is tidy. Undo / Restart are free. (This file is presentation + input only.)

const Board = preload("res://scripts/board.gd")
const Levels = preload("res://scripts/levels.gd")
const Palette = preload("res://scripts/palette.gd")
const Progress = preload("res://scripts/progress.gd")
const Save = preload("res://scripts/save.gd")
const Econ = preload("res://scripts/econ.gd")
const Audio = preload("res://scripts/audio.gd")
const UiFont = preload("res://scripts/ui_font.gd")
const Look = preload("res://scripts/skin.gd")
const Session = preload("res://scripts/session.gd")
const Districts = preload("res://scripts/districts.gd")
const Quests = preload("res://scripts/quests.gd")
const Music = preload("res://scripts/music.gd")
const FX = preload("res://scripts/fx.gd")

const CSZ_MAX := 168.0     # max cell size (used on small boards)
const FIT_SPAN := 680.0    # target max board span (px); leaves room for the mat's rounded corners
const GAP := 14.0
const ANIM := 0.16
const NONE := Vector2i(-1, -1)
const USE_TRAY := true    # board_tray.png is now a PLAIN square mat (no baked pockets)

var level_index := 0
var board: Board
var csz := 168.0           # actual cell size in px, fitted to the board in _load_level
var initial_grid: Array
var history: Array = []
var selected := NONE
var drags := 0
var animating := false

var title_label: Label
var status_label: RichTextLabel
var hint_label: Label
var board_area: Control
var slot_nodes := {}
var piece_nodes := {}
var drawer_contents := {}   # cell flat-index -> contained item code (locked drawers)
var drawer_nodes := {}      # cell -> closed-drawer visual node
var covers := {}            # cell -> dust-cover node (hides the piece until an adjacent merge)
var _pending_covers := []   # flat indices to cover on load
var tangles := {}           # cell -> remaining loosen-count (a roped item, freed after N merges)
var tangle_nodes := {}      # cell -> tangle overlay node
var _pending_tangles := {}  # flat index -> count, from level
var floor_cells := []       # "clear the floor" priority zone (a goal): empty these cells
var floor_tints := {}       # cell -> tint node (dirty -> clean as it empties)
var floor_cleaned := {}     # cell -> true once brightened
var _floor_celebrated := false
var ticket: Array = []      # job-ticket targets: [{code, count}, ...] (optional per level)
var ticket_progress: Array = []
var ticket_bar: HBoxContainer
var shelf_targets: Array = []   # per-cubby target item code (what each slot WANTS; shown as a ghost)
var shelf_done: Array = []      # per-cubby filled flag
var shelf_slots: Array = []
var shelf_panel: PanelContainer
var shelf_row: HBoxContainer
var shelf_icon: Control = null    # the family's furniture art beside the cubbies (optional)
var _used_undo := false         # cleared, set by Undo — costs the "clean clear" star
var coin_counter: PanelContainer
var coin_count_label: Label
var _bg_rect: TextureRect          # district backdrop (swapped per level's district)
var quest_chip: PanelContainer     # the ONE session micro-quest (top-left)
var quest_label: Label

var _press_pos := Vector2.ZERO
var _drag_node: Control = null
var _drag_from := NONE
var _dragging := false
var _hl: Array = []
var _dot_tex: Texture2D

func _ready() -> void:
	UiFont.apply()
	Music.ensure()
	_bg_rect = Look.background(self, 0.62)   # cozy room, dimmed so the board pops

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 20)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(root)

	# persistent coin wallet, pinned top-right
	coin_counter = PanelContainer.new()
	coin_counter.anchor_left = 1.0
	coin_counter.anchor_right = 1.0
	coin_counter.offset_right = -16.0
	coin_counter.offset_top = 16.0 + Look.safe_top(self)
	coin_counter.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	var cbg := StyleBoxFlat.new()
	cbg.bg_color = Color(Palette.BG_DEEP, 0.55)
	cbg.set_corner_radius_all(20)
	cbg.content_margin_left = 14.0
	cbg.content_margin_right = 16.0
	cbg.content_margin_top = 6.0
	cbg.content_margin_bottom = 6.0
	coin_counter.add_theme_stylebox_override("panel", cbg)
	var crow := HBoxContainer.new()
	crow.add_theme_constant_override("separation", 7)
	coin_counter.add_child(crow)
	crow.add_child(Look.coin_icon(34.0))
	coin_count_label = Label.new()
	coin_count_label.add_theme_font_size_override("font_size", 34)
	coin_count_label.add_theme_color_override("font_color", Palette.TEXT)
	coin_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	crow.add_child(coin_count_label)
	add_child(coin_counter)
	_update_coins()

	# the one session quest chip, pinned top-left (the wallet's mirror)
	quest_chip = PanelContainer.new()
	quest_chip.offset_left = 16.0
	quest_chip.offset_top = 16.0 + Look.safe_top(self)
	var qbg := StyleBoxFlat.new()
	qbg.bg_color = Color(Palette.BG_DEEP, 0.55)
	qbg.set_corner_radius_all(20)
	qbg.content_margin_left = 16.0
	qbg.content_margin_right = 16.0
	qbg.content_margin_top = 6.0
	qbg.content_margin_bottom = 6.0
	quest_chip.add_theme_stylebox_override("panel", qbg)
	quest_label = Label.new()
	quest_label.add_theme_font_size_override("font_size", 26)
	quest_label.add_theme_color_override("font_color", Palette.ACCENT_2)
	quest_chip.add_child(quest_label)
	add_child(quest_chip)

	title_label = _label(48, Palette.ACCENT)
	root.add_child(title_label)
	status_label = RichTextLabel.new()
	status_label.bbcode_enabled = true
	status_label.fit_content = true
	status_label.scroll_active = false
	status_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	status_label.custom_minimum_size = Vector2(720, 0)
	status_label.add_theme_font_size_override("normal_font_size", 28)
	status_label.add_theme_color_override("font_outline_color", Palette.BG_DEEP)
	status_label.add_theme_constant_override("outline_size", 6)
	root.add_child(status_label)

	ticket_bar = HBoxContainer.new()
	ticket_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	ticket_bar.add_theme_constant_override("separation", 12)
	root.add_child(ticket_bar)

	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(center)
	board_area = Control.new()
	board_area.mouse_filter = Control.MOUSE_FILTER_STOP
	board_area.gui_input.connect(_on_board_input)
	center.add_child(board_area)

	shelf_panel = PanelContainer.new()
	shelf_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var ssb := StyleBoxFlat.new()
	ssb.bg_color = Color("#B9803F")
	ssb.set_corner_radius_all(14)
	ssb.set_border_width_all(4)
	ssb.border_color = Color("#7E5226")
	ssb.content_margin_left = 14.0
	ssb.content_margin_right = 14.0
	ssb.content_margin_top = 10.0
	ssb.content_margin_bottom = 10.0
	shelf_panel.add_theme_stylebox_override("panel", ssb)
	shelf_row = HBoxContainer.new()
	shelf_row.add_theme_constant_override("separation", 8)
	shelf_panel.add_child(shelf_row)
	root.add_child(shelf_panel)

	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 18)
	root.add_child(bar)
	var tap := func() -> void: Audio.play("button_tap", -2.0)
	bar.add_child(Look.button(tr("◀ Jobs"), _on_jobs, false, tap))
	bar.add_child(Look.button(tr("Undo"), _on_undo, false, tap))
	bar.add_child(Look.button(tr("Restart"), _on_restart, false, tap))
	bar.add_child(Look.button(tr("Next ▶"), _on_next, true, tap))

	hint_label = _label(23, Palette.TEXT_MUTED)
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	hint_label.custom_minimum_size = Vector2(840, 0)
	root.add_child(hint_label)

	_dot_tex = _tex_or_null(Palette.FX_SPARKLE)
	if _dot_tex == null:
		_dot_tex = _make_dot_texture()
	_load_level(clampi(Session.next_level, 0, Levels.LEVELS.size() - 1))

# --- level loading & board build -------------------------------------------

func _load_level(i: int) -> void:
	level_index = i
	var lv: Dictionary = Levels.LEVELS[i]
	board = Board.new(lv.rows, lv.cols, lv.grid, lv.top)
	var n := maxi(board.rows, board.cols)
	csz = minf(CSZ_MAX, (FIT_SPAN - float(n - 1) * GAP) / float(n))   # shrink big boards to fit
	drawer_contents.clear()
	for k in lv.get("drawers", {}):
		drawer_contents[int(k)] = int(lv["drawers"][k])
	_pending_covers = lv.get("covers", []).duplicate()
	_pending_tangles = lv.get("tangles", {}).duplicate()
	floor_cells = []
	for fidx in lv.get("floor", []):
		floor_cells.append(Vector2i(int(fidx) / board.cols, int(fidx) % board.cols))
	floor_cleaned.clear()
	_floor_celebrated = false
	ticket = lv.get("ticket", []).duplicate(true)
	ticket_progress.clear()
	for _t in ticket:
		ticket_progress.append(0)
	shelf_targets = lv.get("shelf", []).duplicate()
	shelf_done.clear()
	for _s in shelf_targets:
		shelf_done.append(false)
	_used_undo = false
	initial_grid = lv.grid.duplicate()
	history.clear()
	selected = NONE
	drags = 0
	animating = false
	title_label.text = tr(lv.name)
	hint_label.text = tr(lv.get("hint", ""))
	if _bg_rect != null:               # district backdrop, bedroom until the art lands
		_bg_rect.texture = load(Districts.bg_path(i, Palette.ROOM_TIDY))
	Quests.start_session(lv)
	# FTUE staging: the very first board teaches the verb alone; the chip joins from board 2
	quest_chip.visible = Save.boards_cleared() >= 1
	_update_quest_chip()
	_build_slots()
	_build_floor()
	_rebuild_pieces()
	_build_covers()
	_build_tangles()
	_refresh_highlights()
	_update_status()
	_refresh_ticket()
	_build_shelf()
	_rescue_if_stuck()                 # safety net: never hand the player a dead board

func _cell_pos(cell: Vector2i) -> Vector2:
	return Vector2(cell.y * (csz + GAP), cell.x * (csz + GAP))

func _pos_to_cell(p: Vector2) -> Vector2i:
	var c := int(p.x / (csz + GAP))
	var r := int(p.y / (csz + GAP))
	return Vector2i(clampi(r, 0, board.rows - 1), clampi(c, 0, board.cols - 1))

func _build_slots() -> void:
	for n in board_area.get_children():
		n.queue_free()
	slot_nodes.clear()
	piece_nodes.clear()
	_hl.clear()
	for dn in drawer_nodes.values():
		if is_instance_valid(dn):
			dn.queue_free()
	drawer_nodes.clear()
	var w := board.cols * csz + (board.cols - 1) * GAP
	var h := board.rows * csz + (board.rows - 1) * GAP
	board_area.custom_minimum_size = Vector2(w, h)
	board_area.size = Vector2(w, h)
	# optional PLAIN rug/mat behind the pockets (no baked pockets, or it double-stamps
	# & misaligns). Off until board_tray.png is a plain mat; drawn aspect-correct.
	if USE_TRAY:
		var tray := _tex_or_null(Districts.tray_path(level_index, Palette.UI_TRAY))
		if tray != null:
			# The square mat art fills only ~87% of its canvas (a transparent margin rings
			# it), so scale the canvas up enough that the WOVEN part covers the pocket grid
			# plus a border, then center it. NB: set expand_mode BEFORE size or the default
			# KEEP_SIZE clamps size back up to the texture's native pixels (the old bug).
			# size the mat so its FLAT inner area (inside the rounded corners) covers the pocket
			# grid — else the square-corner pockets poke past the mat's rounded corners.
			var mat_fill := 0.87          # opaque woven mat / full canvas (measured 892/1024)
			var corner_frac := 0.12       # mat corner radius / woven side
			var pad := 12.0
			var woven := (maxf(w, h) + pad * 2.0) / (1.0 - corner_frac * 2.0)
			var canvas := woven / mat_fill
			var tr := TextureRect.new()
			tr.texture = tray
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_SCALE
			tr.size = Vector2(canvas, canvas)
			tr.position = Vector2(w, h) * 0.5 - Vector2(canvas, canvas) * 0.5
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			board_area.add_child(tr)
	var pocket := _tex_or_null(Palette.UI_SLOT)
	for r in board.rows:
		for c in board.cols:
			var cell := Vector2i(r, c)
			var is_wall := board.at(r, c) == Board.WALL
			var slot: Control
			if pocket != null and not is_wall:
				var pk := TextureRect.new()
				pk.texture = pocket
				pk.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				pk.stretch_mode = TextureRect.STRETCH_SCALE
				slot = pk
			else:
				var pn := Panel.new()
				pn.add_theme_stylebox_override("panel", _slot_style(is_wall))
				slot = pn
			slot.position = _cell_pos(cell)
			slot.custom_minimum_size = Vector2(csz, csz)
			slot.size = Vector2(csz, csz)
			slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			board_area.add_child(slot)
			slot_nodes[cell] = slot
			if board.at(r, c) == Board.DRAWER:
				var dwr := _make_drawer(int(drawer_contents.get(board.index(r, c), 101)))
				dwr.position = _cell_pos(cell)
				board_area.add_child(dwr)
				drawer_nodes[cell] = dwr

func _make_drawer(code: int) -> Control:
	# prefer the per-family drawer art (assets/ui/drawer_<family>.png) when present;
	# fall back to the procedural CSS drawer below if missing.
	var fam := ["", "clothes", "books", "toys"]
	var family_idx: int = int(code / 100)
	var art_path := "res://assets/ui/drawer_%s.png" % fam[family_idx] if family_idx >= 1 and family_idx < fam.size() else ""
	if art_path != "" and ResourceLoader.exists(art_path):
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(csz, csz)
		holder.size = Vector2(csz, csz)
		holder.pivot_offset = Vector2(csz, csz) / 2.0
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.z_index = 5
		var art := TextureRect.new()
		art.texture = load(art_path)
		art.set_anchors_preset(Control.PRESET_FULL_RECT)
		var inset := csz * 0.04
		art.offset_left = inset; art.offset_top = inset
		art.offset_right = -inset; art.offset_bottom = -inset
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(art)
		return holder
	# procedural fallback (when no per-family art is dropped in yet)
	var d := Panel.new()
	d.size = Vector2(csz, csz)
	d.custom_minimum_size = Vector2(csz, csz)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	d.z_index = 5
	var box := StyleBoxFlat.new()
	box.bg_color = Color("#B9803F")
	box.set_corner_radius_all(int(csz * 0.16))
	box.set_border_width_all(maxi(3, int(csz * 0.045)))
	box.border_color = Color("#7E5226")
	d.add_theme_stylebox_override("panel", box)
	var front := Panel.new()
	var inset := csz * 0.13
	front.position = Vector2(inset, inset)
	front.size = Vector2(csz - inset * 2.0, csz - inset * 2.0)
	front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fb := StyleBoxFlat.new()
	fb.bg_color = Color("#E6B673")
	fb.set_corner_radius_all(int(csz * 0.10))
	front.add_theme_stylebox_override("panel", fb)
	d.add_child(front)
	var tex := _item_texture(code)
	if tex != null:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		var pin := csz * 0.10
		tr.offset_left = pin
		tr.offset_top = pin
		tr.offset_right = -pin
		tr.offset_bottom = -pin
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.modulate = Color(1, 1, 1, 0.38)   # dimmed: a hint of what's inside
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		front.add_child(tr)
	var handle := Panel.new()
	var hw := csz * 0.34
	var hh := maxf(5.0, csz * 0.06)
	handle.size = Vector2(hw, hh)
	handle.position = Vector2((csz - hw) * 0.5, csz * 0.18)
	handle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hbx := StyleBoxFlat.new()
	hbx.bg_color = Color("#7E5226")
	hbx.set_corner_radius_all(int(hh))
	handle.add_theme_stylebox_override("panel", hbx)
	d.add_child(handle)
	return d

# --- dust covers (a sheet hides an item until an adjacent merge puffs it off) ---------------

func _covered(cell: Vector2i) -> bool:
	return covers.has(cell)

func _build_covers() -> void:
	for c in covers.values():
		if is_instance_valid(c):
			c.queue_free()
	covers.clear()
	for idx in _pending_covers:
		var cell := Vector2i(int(idx) / board.cols, int(idx) % board.cols)
		if not Board.is_piece(board.at(cell.x, cell.y)):
			continue
		var cov := _make_cover()
		cov.position = _cell_pos(cell)
		board_area.add_child(cov)
		covers[cell] = cov

func _make_cover() -> Control:
	var c := Panel.new()
	c.size = Vector2(csz, csz)
	c.custom_minimum_size = Vector2(csz, csz)
	c.pivot_offset = Vector2(csz, csz) / 2.0
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.z_index = 6
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#CFC7BA")        # dusty cloth
	sb.set_corner_radius_all(int(csz * 0.14))
	sb.set_border_width_all(maxi(2, int(csz * 0.03)))
	sb.border_color = Color("#A89E8E")
	c.add_theme_stylebox_override("panel", sb)
	var q := Label.new()
	q.text = "?"
	q.add_theme_font_size_override("font_size", int(csz * 0.42))
	q.add_theme_color_override("font_color", Color("#8A8071"))
	q.set_anchors_preset(Control.PRESET_FULL_RECT)
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	q.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(q)
	return c

func _uncover_adjacent(cell: Vector2i) -> void:
	for d in Board.DIRS:
		var n := cell + d
		if covers.has(n):
			var cov: Control = covers[n]
			covers.erase(n)
			if is_instance_valid(cov):
				var t := cov.create_tween()
				t.set_parallel(true)
				t.tween_property(cov, "scale", Vector2(1.4, 1.4), 0.25).set_ease(Tween.EASE_OUT)
				t.tween_property(cov, "modulate:a", 0.0, 0.25)
				t.chain().tween_callback(cov.queue_free)
			_burst(_cell_pos(n) + Vector2(csz, csz) / 2.0, Color("#CFC7BA"), null, 18)
			_celebrate(piece_nodes.get(n), tr("Found it!"), Palette.COOL)   # shake/pop/shout
			Audio.play("tidy_poof", -3.0, 0.9)
			_quest_event("cover")

# --- tangles (items roped together; freed after N merges anywhere) -------------------------

func _tangled(cell: Vector2i) -> bool:
	return tangles.has(cell) and int(tangles[cell]) > 0

func _locked(cell: Vector2i) -> bool:
	return _covered(cell) or _tangled(cell)

func _build_tangles() -> void:
	for t in tangle_nodes.values():
		if is_instance_valid(t):
			t.queue_free()
	tangle_nodes.clear()
	tangles.clear()
	for idx in _pending_tangles:
		var cell := Vector2i(int(idx) / board.cols, int(idx) % board.cols)
		if not Board.is_piece(board.at(cell.x, cell.y)):
			continue
		tangles[cell] = int(_pending_tangles[idx])
		var n := _make_tangle(int(_pending_tangles[idx]))
		n.position = _cell_pos(cell)
		board_area.add_child(n)
		tangle_nodes[cell] = n

func _make_tangle(count: int) -> Control:
	var t := Panel.new()
	t.size = Vector2(csz, csz)
	t.custom_minimum_size = Vector2(csz, csz)
	t.pivot_offset = Vector2(csz, csz) / 2.0
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.z_index = 6
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.0, 0.0, 0.0, 0.0)        # transparent — the roped item shows through
	sb.set_corner_radius_all(int(csz * 0.14))
	sb.set_border_width_all(maxi(4, int(csz * 0.07)))
	sb.border_color = Color("#B07A4A")             # rope brown
	t.add_theme_stylebox_override("panel", sb)
	var badge := Label.new()
	badge.name = "cnt"
	badge.text = str(count)
	badge.add_theme_font_size_override("font_size", int(csz * 0.26))
	badge.add_theme_color_override("font_color", Palette.TEXT)
	badge.add_theme_color_override("font_outline_color", Color("#6E4A28"))
	badge.add_theme_constant_override("outline_size", 5)
	badge.position = Vector2(csz * 0.06, csz * 0.02)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.add_child(badge)
	return t

func _loosen_tangles() -> void:
	for cell in tangles.keys():
		tangles[cell] = int(tangles[cell]) - 1
		var n: Control = tangle_nodes.get(cell)
		if int(tangles[cell]) <= 0:
			tangles.erase(cell)
			tangle_nodes.erase(cell)
			if is_instance_valid(n):
				var tw := n.create_tween()
				tw.set_parallel(true)
				tw.tween_property(n, "scale", Vector2(1.5, 1.5), 0.25)
				tw.tween_property(n, "modulate:a", 0.0, 0.25)
				tw.chain().tween_callback(n.queue_free)
			_celebrate(piece_nodes.get(cell), tr("Free!"), Palette.ACCENT_2)
			Audio.play("tidy_poof", -2.0, 1.1)
			_quest_event("tangle")
		elif is_instance_valid(n):
			var b = n.get_node_or_null("cnt")
			if b:
				b.text = str(int(tangles[cell]))
			_wobble(n)

# --- clear the floor (a priority zone to empty first; the rug brightens as it clears) -------

func _build_floor() -> void:
	for t in floor_tints.values():
		if is_instance_valid(t):
			t.queue_free()
	floor_tints.clear()
	for cell in floor_cells:
		var t := Panel.new()
		t.size = Vector2(csz, csz)
		t.position = _cell_pos(cell)
		t.pivot_offset = Vector2(csz, csz) / 2.0
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		t.add_theme_stylebox_override("panel", _floor_style(false))   # dim/dirty
		board_area.add_child(t)
		floor_tints[cell] = t

func _floor_style(clean: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Palette.ACCENT, 0.5) if clean else Color(0.5, 0.45, 0.4, 0.3)
	sb.set_corner_radius_all(int(csz * 0.14))
	return sb

func _check_floor() -> void:
	if floor_cells.is_empty():
		return
	for cell in floor_cells:
		if board.at(cell.x, cell.y) == Board.EMPTY and not floor_cleaned.has(cell):
			floor_cleaned[cell] = true
			var t: Control = floor_tints.get(cell)
			if is_instance_valid(t):
				t.add_theme_stylebox_override("panel", _floor_style(true))   # cleaned rug
				_pop(t)
				_burst(_cell_pos(cell) + Vector2(csz, csz) / 2.0, Palette.ACCENT_2, null, 12)
	if _floor_complete() and not _floor_celebrated:
		_floor_celebrated = true
		_floating_text(get_global_rect().get_center() - Vector2(150, 80), tr("Floor clean!"), Palette.GOLD, 56)
		Audio.play("level_complete", -2.0)
		_quest_event("floor")
		for t in floor_tints.values():
			_wobble(t)

func _floor_complete() -> bool:
	if floor_cells.is_empty():
		return false
	for cell in floor_cells:
		if board.at(cell.x, cell.y) != Board.EMPTY:
			return false
	return true

func _rebuild_pieces() -> void:
	for n in piece_nodes.values():
		if is_instance_valid(n):
			n.queue_free()
	piece_nodes.clear()
	for r in board.rows:
		for c in board.cols:
			var v: int = board.at(r, c)
			if v > 0:
				var cell := Vector2i(r, c)
				var node := _make_piece(v)
				node.position = _cell_pos(cell)
				board_area.add_child(node)
				piece_nodes[cell] = node
	_refresh_movability()

# --- visuals ---------------------------------------------------------------

func _slot_style(is_wall: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Palette.SLOT_WALL if is_wall else Palette.SLOT
	s.set_corner_radius_all(18)
	return s

func _item_texture(code: int) -> Texture2D:
	var path := Palette.item_tex_path(code)
	if path != "" and ResourceLoader.exists(path):
		return load(path)
	return null

func _tex_or_null(path: String) -> Texture2D:
	return load(path) if ResourceLoader.exists(path) else null

func _make_piece(code: int) -> Control:
	var t := Board.tier_of(code)
	var tex := _item_texture(code)
	if tex != null:
		# real art: float the item inside its pocket — no card behind it
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(csz, csz)
		holder.size = Vector2(csz, csz)
		holder.pivot_offset = Vector2(csz, csz) / 2.0
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tr := TextureRect.new()
		tr.texture = tex
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		var inset := 10.0
		tr.offset_left = inset
		tr.offset_top = inset
		tr.offset_right = -inset
		tr.offset_bottom = -inset
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(tr)
		return holder
	# placeholder (no art yet): a colored rounded card with the tier number
	var p := Panel.new()
	p.custom_minimum_size = Vector2(csz, csz)
	p.size = Vector2(csz, csz)
	p.pivot_offset = Vector2(csz, csz) / 2.0
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := StyleBoxFlat.new()
	s.bg_color = Palette.tier_color(t)
	s.set_corner_radius_all(26)
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 6
	s.set_border_width_all(3)
	s.border_color = Palette.tier_color(t).lightened(0.25)
	p.add_theme_stylebox_override("panel", s)
	var lbl := Label.new()
	lbl.text = str(t)
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 60)
	lbl.add_theme_color_override("font_color", Palette.BG_DEEP)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(lbl)
	return p

func _refresh_highlights() -> void:
	_clear_highlights()
	if selected == NONE or not Board.is_piece(board.at(selected.x, selected.y)):
		return
	var code := board.at(selected.x, selected.y)
	for r in board.rows:
		for c in board.cols:
			if (r != selected.x or c != selected.y) and board.at(r, c) == code and not _locked(Vector2i(r, c)):
				_add_ring(Vector2i(r, c), Palette.GOOD)   # green: drop on any (uncovered) match

func _clear_highlights() -> void:
	for h in _hl:
		if is_instance_valid(h):
			h.queue_free()
	_hl.clear()

func _add_ring(cell: Vector2i, color: Color) -> void:
	var r := Panel.new()
	r.position = _cell_pos(cell)
	r.size = Vector2(csz, csz)
	r.z_index = 10                     # above slots & resting pieces, below the held piece (z 20)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := StyleBoxFlat.new()
	s.bg_color = Color(color, 0.16)
	s.set_corner_radius_all(28)
	s.set_border_width_all(6)
	s.border_color = color
	r.add_theme_stylebox_override("panel", s)
	board_area.add_child(r)
	_hl.append(r)
	# Bind the looping pulse to the ring itself: when _clear_highlights frees the
	# panel, the tween dies with it. (A self-bound tween would outlive the freed
	# node, collapse to a zero-duration loop, and spam "Infinite loop detected".)
	var tw := r.create_tween().set_loops()
	tw.tween_property(r, "modulate:a", 0.5, 0.55)
	tw.tween_property(r, "modulate:a", 1.0, 0.55)

# Any pair of same-code, unlocked pieces anywhere? (the drag-any-to-any move test)
func _any_legal_merge() -> bool:
	var seen := {}
	for r in board.rows:
		for c in board.cols:
			var cell := Vector2i(r, c)
			var k: int = board.at(r, c)
			if k > 0 and not _locked(cell):
				if seen.has(k):
					return true
				seen[k] = true
	return false

# Can't-lose rescue: drawers/covers open only on ADJACENT merges, but pieces never
# move — so a board can run out of merges that reach them (their neighbor cells
# emptied out). When pieces remain but no merge exists, everything left shakes
# itself loose rather than soft-locking the player into Restart.
func _rescue_if_stuck() -> void:
	if board.is_cleared() or _any_legal_merge():
		return
	if drawer_contents.is_empty() and covers.is_empty() and tangles.is_empty():
		return                          # genuinely bare board — authoring guards prevent this
	_floating_text(board_area.get_global_rect().get_center() - Vector2(250, 60),
		tr("Everything shakes loose!"), Palette.GOLD, 48)
	Audio.play("tidy_poof", 0.0, 0.8)
	for idx in drawer_contents.keys():
		var cell := Vector2i(int(idx) / board.cols, int(idx) % board.cols)
		var code: int = int(drawer_contents[idx])
		board.grid[idx] = code
		drawer_contents.erase(idx)
		_pop_open_drawer(cell, code)
		_quest_event("drawer")
	for cell in covers.keys():
		var cov: Control = covers[cell]
		covers.erase(cell)
		if is_instance_valid(cov):
			var t := cov.create_tween()
			t.set_parallel(true)
			t.tween_property(cov, "scale", Vector2(1.4, 1.4), 0.25).set_ease(Tween.EASE_OUT)
			t.tween_property(cov, "modulate:a", 0.0, 0.25)
			t.chain().tween_callback(cov.queue_free)
		_burst(_cell_pos(cell) + Vector2(csz, csz) / 2.0, Color("#CFC7BA"), null, 14)
		_quest_event("cover")
	for cell in tangles.keys():
		tangles.erase(cell)
		var n: Control = tangle_nodes.get(cell)
		tangle_nodes.erase(cell)
		if is_instance_valid(n):
			var tw := n.create_tween()
			tw.set_parallel(true)
			tw.tween_property(n, "scale", Vector2(1.5, 1.5), 0.25)
			tw.tween_property(n, "modulate:a", 0.0, 0.25)
			tw.chain().tween_callback(n.queue_free)
		_quest_event("tangle")
	_refresh_highlights()
	_refresh_movability()

func _has_moves(cell: Vector2i) -> bool:
	# pickable if another item of the SAME code exists anywhere on the board
	var code := board.at(cell.x, cell.y)
	if not Board.is_piece(code):
		return false
	for r in board.rows:
		for c in board.cols:
			if (r != cell.x or c != cell.y) and board.at(r, c) == code and not _locked(Vector2i(r, c)):
				return true
	return false

func _refresh_movability() -> void:
	for cell in piece_nodes:
		var node: Control = piece_nodes[cell]
		node.modulate.a = 1.0 if _has_moves(cell) else 0.38

func _shake(cell: Vector2i) -> void:
	var node: Control = piece_nodes.get(cell)
	if not node or not is_instance_valid(node):
		return
	var base := _cell_pos(cell)
	var tw := create_tween()
	if FX.calm():                  # a soft nudge instead of a rattle
		tw.tween_property(node, "position:x", base.x - 4, 0.08)
		tw.tween_property(node, "position:x", base.x, 0.10)
		return
	tw.tween_property(node, "position:x", base.x - 9, 0.04)
	tw.tween_property(node, "position:x", base.x + 9, 0.04)
	tw.tween_property(node, "position:x", base.x - 5, 0.04)
	tw.tween_property(node, "position:x", base.x, 0.04)

# --- input -----------------------------------------------------------------

func _on_board_input(event: InputEvent) -> void:
	if animating or board.is_cleared():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_on_press(event.position)
		else:
			_on_release(event.position)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_on_press(event.position)
		else:
			_on_release(event.position)
	elif event is InputEventMouseMotion or event is InputEventScreenDrag:
		_on_motion(event.position)

func _on_press(p: Vector2) -> void:
	_press_pos = p
	_dragging = false
	_drag_node = null
	var c := _pos_to_cell(p)
	var v: int = board.at(c.x, c.y)
	if not Board.is_piece(v):
		return
	if _locked(c):
		Audio.play("invalid_soft", -3.0)
		_wobble(tangle_nodes[c] if _tangled(c) else covers[c])   # roped or dusty — free it first
		return
	if not _has_moves(c):
		Audio.play("invalid_soft", -3.0)
		_shake(c)
		return
	# pick up: pop the item out of its basket and follow the pointer
	selected = c
	_drag_from = c
	_drag_node = piece_nodes.get(c)
	_dragging = true
	_refresh_highlights()
	Audio.play("item_pickup", -6.0)
	if _drag_node and is_instance_valid(_drag_node):
		_drag_node.z_index = 20
		var tw := create_tween()
		tw.tween_property(_drag_node, "scale", Vector2(1.14, 1.14), 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_motion(p: Vector2) -> void:
	if _dragging and _drag_node and is_instance_valid(_drag_node):
		_drag_node.position = p - Vector2(csz, csz) * 0.5

func _on_release(p: Vector2) -> void:
	if not _dragging:
		return
	_dragging = false
	var node := _drag_node
	_drag_node = null
	var src := _drag_from
	var rel := _pos_to_cell(p)
	if rel != src and board.in_bounds(rel.x, rel.y) \
			and Board.is_piece(board.at(src.x, src.y)) \
			and board.at(rel.x, rel.y) == board.at(src.x, src.y) \
			and not _locked(rel):
		_commit(src, rel)              # dropped on a MATCHING (uncovered) item → merge
	else:
		_snap_back(node, src)          # anywhere else → return it home

func _snap_back(node: Control, cell: Vector2i) -> void:
	selected = NONE
	_clear_highlights()
	if node and is_instance_valid(node):
		node.z_index = 0
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(node, "position", _cell_pos(cell), 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(node, "scale", Vector2.ONE, 0.13)

# (swipe + _dir_of removed — drag-any-to-any has no sliding)

# --- commit + animation ----------------------------------------------------

func _commit(src: Vector2i, dst: Vector2i) -> void:
	# drag-any-to-any: src and dst hold the SAME code; merge them (no sliding, no reposition).
	history.append(_snapshot())
	var k := board.at(src.x, src.y)
	var showcase := board.is_showcase_merge(src.x, src.y)
	board.apply_merge(src.x, src.y, dst.x, dst.y)
	# the item this merge "made" (bumped tier, or the top-tier put-away on a showcase)
	var produced := (int(k / 100) * 100 + board.top_tier) if showcase else board.at(dst.x, dst.y)
	_tick_ticket(produced)
	if showcase:
		_fill_shelf(produced)        # a "put away" lands on the shelf
	drags += 1
	_quest_event("merge")
	selected = NONE
	if showcase:
		Audio.play("tidy_poof", 1.0)
	else:
		var rt := Board.tier_of(board.at(dst.x, dst.y))
		Audio.play("merge_success" if rt >= 3 else "merge_soft", 0.0, clampf(1.0 + 0.04 * (rt - 1), 0.9, 1.3))
	_clear_highlights()
	var node: Control = piece_nodes.get(src)
	animating = true
	if node and is_instance_valid(node):
		node.z_index = 10
		var dist := absi(src.x - dst.x) + absi(src.y - dst.y)
		var dur := clampf(0.10 + 0.028 * dist, 0.12, 0.24)
		var tw := create_tween()
		tw.tween_property(node, "position", _cell_pos(dst), dur)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_callback(_after_move.bind(dst, showcase))
	else:
		_after_move(dst, showcase)

func _after_move(dst: Vector2i, showcase: bool) -> void:
	_rebuild_pieces()
	var center := _cell_pos(dst) + Vector2(csz, csz) / 2.0
	if showcase:
		_flash(dst)
		_burst(center, Palette.GOLD, null, 36)
		_burst(center, Palette.TEXT, null, 18)            # extra sparkle layer
	else:
		var n: Control = piece_nodes.get(dst)
		if n:
			_pop(n)
			var rt := Board.tier_of(board.at(dst.x, dst.y))
			_burst(center, Palette.tier_color(rt), null, 12 + rt * 5)   # bigger pop for bigger merges
			if rt >= 2:
				_flash(dst)
	_pop_drawers_adjacent(dst)
	_uncover_adjacent(dst)
	_loosen_tangles()
	_check_floor()
	animating = false
	_rescue_if_stuck()
	_refresh_highlights()
	_update_status()
	_refresh_ticket()
	if board.is_cleared():
		_play_zero()

func _pop_drawers_adjacent(cell: Vector2i) -> void:
	# a merge next to a locked drawer pops it open, releasing its item (adjacent-merge trigger)
	for d in Board.DIRS:
		var n := cell + d
		if board.in_bounds(n.x, n.y) and board.at(n.x, n.y) == Board.DRAWER:
			var idx := board.index(n.x, n.y)
			var code: int = int(drawer_contents.get(idx, 101))
			board.grid[idx] = code
			drawer_contents.erase(idx)
			_pop_open_drawer(n, code)

func _pop_open_drawer(cell: Vector2i, code: int) -> void:
	var dn = drawer_nodes.get(cell)
	if dn and is_instance_valid(dn):
		dn.queue_free()
	drawer_nodes.erase(cell)
	var node := _make_piece(code)
	node.position = _cell_pos(cell)
	board_area.add_child(node)
	piece_nodes[cell] = node
	_pop(node)
	_wobble(node)
	_flash(cell)
	_burst(_cell_pos(cell) + Vector2(csz, csz) / 2.0, Palette.ACCENT_2, null, 24)
	_floating_text(node.get_global_rect().get_center() - Vector2(36, 56), tr("Pop!"), Palette.ACCENT_2, 40)
	Audio.play("tidy_poof", -2.0)
	_quest_event("drawer")

# --- job ticket (optional per-board goal; clearing the board still always wins) -------------

func _tick_ticket(code: int) -> void:
	if ticket.is_empty():
		return
	var changed := false
	var completed := -1
	for i in ticket.size():
		if int(ticket[i]["code"]) == code and int(ticket_progress[i]) < int(ticket[i]["count"]):
			ticket_progress[i] += 1
			changed = true
			if int(ticket_progress[i]) >= int(ticket[i]["count"]):
				completed = i
	if changed:
		_refresh_ticket()
	if completed >= 0 and completed < ticket_bar.get_child_count():
		_celebrate(ticket_bar.get_child(completed), tr("Nice!"), Palette.GOOD)   # shake/pop/shout
		Audio.play("merge_success", -2.0, 1.35)
		if _ticket_done():
			_floating_text(get_global_rect().get_center() - Vector2(160, 30), tr("Ticket done!"), Palette.GOLD, 58)
			Audio.play("level_complete", -2.0)
			_stamp_ticket()

# The round rubber-stamp ring thunks onto the finished ticket (silent no-op without art).
func _stamp_ticket() -> void:
	if not ResourceLoader.exists("res://assets/ui/ticket_stamp_done.png") or ticket_bar == null:
		return
	var st := TextureRect.new()
	st.texture = load("res://assets/ui/ticket_stamp_done.png")
	st.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	st.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	st.size = Vector2(120, 120)
	st.position = ticket_bar.get_global_rect().get_center() - Vector2(60, 60)
	st.pivot_offset = Vector2(60, 60)
	st.rotation_degrees = -12.0
	st.mouse_filter = Control.MOUSE_FILTER_IGNORE
	st.scale = Vector2(1.8, 1.8)
	st.modulate.a = 0.0
	add_child(st)
	var tw := st.create_tween()
	tw.tween_property(st, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(st, "modulate:a", 1.0, 0.1)
	tw.tween_interval(0.8)
	tw.tween_property(st, "modulate:a", 0.0, 0.5)
	tw.tween_callback(st.queue_free)

func _refresh_ticket() -> void:
	if ticket_bar == null:
		return
	for ch in ticket_bar.get_children():
		ch.queue_free()
	for i in ticket.size():
		ticket_bar.add_child(_ticket_chip(int(ticket[i]["code"]), int(ticket_progress[i]), int(ticket[i]["count"])))

func _ticket_chip(code: int, done: int, need: int) -> Control:
	var complete := done >= need
	var chip := PanelContainer.new()
	var card_art := ResourceLoader.exists("res://assets/ui/ticket_card.png")
	if card_art:
		# the generated work-order card is the chip; targets stamp on top of it
		chip.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		var card := TextureRect.new()
		card.texture = load("res://assets/ui/ticket_card.png")
		card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		card.stretch_mode = TextureRect.STRETCH_SCALE
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(card)
	else:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Palette.GOOD if complete else Palette.SURFACE
		sb.set_corner_radius_all(14)
		sb.content_margin_left = 12.0
		sb.content_margin_right = 12.0
		sb.content_margin_top = 5.0
		sb.content_margin_bottom = 5.0
		chip.add_theme_stylebox_override("panel", sb)
	var mc := MarginContainer.new()
	mc.add_theme_constant_override("margin_left", 18 if card_art else 0)
	mc.add_theme_constant_override("margin_right", 22 if card_art else 0)
	mc.add_theme_constant_override("margin_top", 14 if card_art else 0)
	mc.add_theme_constant_override("margin_bottom", 10 if card_art else 0)
	chip.add_child(mc)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	mc.add_child(row)
	var tex := _item_texture(code)
	if tex != null:
		var ic := TextureRect.new()
		ic.texture = tex
		ic.custom_minimum_size = Vector2(46, 46)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(ic)
	var lbl := Label.new()
	lbl.text = "%d/%d" % [done, need]
	lbl.add_theme_font_size_override("font_size", 26)
	if card_art:
		lbl.add_theme_color_override("font_color", Palette.BG_DEEP)   # ink on cream paper
	else:
		lbl.add_theme_color_override("font_color", Palette.BG_DEEP if complete else Palette.TEXT)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(lbl)
	if complete and ResourceLoader.exists("res://assets/ui/ticket_checkmark.png"):
		var ck := TextureRect.new()
		ck.texture = load("res://assets/ui/ticket_checkmark.png")
		ck.custom_minimum_size = Vector2(32, 32)
		ck.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ck.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(ck)
	return chip

# --- fill the shelf (a counted put-away destination; previews the decoration meta) ----------

func _build_shelf() -> void:
	if shelf_panel == null:
		return
	for ch in shelf_row.get_children():
		ch.queue_free()
	shelf_slots.clear()
	shelf_icon = null
	shelf_panel.visible = not shelf_targets.is_empty()
	if not shelf_targets.is_empty():
		# the family's furniture (dresser / bookcase / toy bin) fronts its cubby row
		var furn := {1: "dresser_clothes", 2: "shelf_books", 3: "toybin_toys"}
		var fi: int = int(int(shelf_targets[0]) / 100.0)
		var fpath: String = "res://assets/ui/%s.png" % furn.get(fi, "")
		if ResourceLoader.exists(fpath):
			var f := TextureRect.new()
			f.texture = load(fpath)
			f.custom_minimum_size = Vector2(60, 90)
			f.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			f.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			f.pivot_offset = Vector2(30, 45)
			f.mouse_filter = Control.MOUSE_FILTER_IGNORE
			shelf_row.add_child(f)
			shelf_icon = f
	for i in shelf_targets.size():
		var slot := Panel.new()
		slot.custom_minimum_size = Vector2(54, 54)
		slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slot.pivot_offset = Vector2(27, 27)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.0, 0.0, 0.0, 0.22)        # empty cubby
		sb.set_corner_radius_all(9)
		sb.set_border_width_all(2)
		sb.border_color = Color(1, 1, 1, 0.18)
		slot.add_theme_stylebox_override("panel", sb)
		var tex := _item_texture(int(shelf_targets[i]))   # GHOST: shows what this cubby needs
		if tex != null:
			var g := TextureRect.new()
			g.name = "ghost"
			g.texture = tex
			g.set_anchors_preset(Control.PRESET_FULL_RECT)
			g.offset_left = 6.0
			g.offset_top = 6.0
			g.offset_right = -6.0
			g.offset_bottom = -6.0
			g.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			g.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			g.modulate = Color(1, 1, 1, 0.30)            # dim = needed, not yet filled
			g.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(g)
		shelf_row.add_child(slot)
		shelf_slots.append(slot)

func _fill_shelf(code: int) -> void:
	# fill the first not-yet-done cubby that WANTS this item (its ghost becomes solid)
	for i in shelf_targets.size():
		if int(shelf_targets[i]) == code and not bool(shelf_done[i]):
			shelf_done[i] = true
			var slot: Panel = shelf_slots[i]
			var fb := StyleBoxFlat.new()
			fb.bg_color = Color(Palette.GOOD, 0.5)
			fb.set_corner_radius_all(9)
			slot.add_theme_stylebox_override("panel", fb)
			var g = slot.get_node_or_null("ghost")
			if g:
				g.modulate = Color(1, 1, 1, 1)   # dim ghost -> solid filled
			_celebrate(slot, tr("Tidy!"), Palette.GOOD)   # shake/pop/shout on every cubby
			Audio.play("tidy_poof", -1.0, 1.2)
			_quest_event("shelf")
			if _shelf_complete():
				_floating_text(get_global_rect().get_center() - Vector2(150, 90), tr("Shelf full!"), Palette.GOLD, 58)
				Audio.play("level_complete", -2.0)
				for s in shelf_slots:
					_wobble(s)
				if shelf_icon != null:
					_wobble(shelf_icon)
			return

func _shelf_complete() -> bool:
	if shelf_targets.is_empty():
		return false
	for d in shelf_done:
		if not bool(d):
			return false
	return true

func _ticket_done() -> bool:
	for i in ticket.size():
		if int(ticket_progress[i]) < int(ticket[i]["count"]):
			return false
	return true

func _pop(node: Control) -> void:
	node.scale = Vector2(1.16, 0.86)
	var tw := create_tween()
	tw.tween_property(node, "scale", Vector2(1.16, 1.16), 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", Vector2.ONE, 0.10).set_trans(Tween.TRANS_QUAD)

# --- "scream at the user" juice for friction wins -----------------------------------------

# shared juice (fx.gd) — thin delegates so the many call sites stay unchanged
func _wobble(node: Control) -> void:
	FX.wobble(node)

func _floating_text(gpos: Vector2, text: String, color: Color, size: int = 44) -> void:
	FX.floating_text(self, gpos, text, color, size)

# pop + wobble a UI node and throw a floating shout + sparkle over it
func _celebrate(node: Control, text: String, color: Color) -> void:
	var c: Vector2
	if node and is_instance_valid(node):
		_pop(node)
		_wobble(node)
		c = node.get_global_rect().get_center()
	else:
		c = get_global_rect().get_center()
	_floating_text(c - Vector2(text.length() * 11.0, 64.0), text, color)
	_burst(c, color, self, 20)

func _flash(cell: Vector2i) -> void:
	var fx := Panel.new()
	fx.position = _cell_pos(cell)
	fx.size = Vector2(csz, csz)
	fx.pivot_offset = Vector2(csz, csz) / 2.0
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := StyleBoxFlat.new()
	s.bg_color = Palette.GOLD
	s.set_corner_radius_all(26)
	fx.add_theme_stylebox_override("panel", s)
	board_area.add_child(fx)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(fx, "scale", Vector2(1.8, 1.8), 0.35).set_ease(Tween.EASE_OUT)
	tw.tween_property(fx, "modulate:a", 0.0, 0.35)
	tw.chain().tween_callback(fx.queue_free)

func _make_dot_texture() -> Texture2D:
	var n := 24
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := n / 2.0
	for y in n:
		for x in n:
			var d := Vector2(x - c + 0.5, y - c + 0.5).length() / c
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	return ImageTexture.create_from_image(img)

func _burst(center: Vector2, color: Color, parent: Node = null, amount: int = 14) -> void:
	var host: Node = parent if parent != null else board_area
	var p := GPUParticles2D.new()
	p.texture = _dot_tex
	p.position = center
	p.amount = FX.amount_for(amount)
	p.lifetime = 0.55
	p.one_shot = true
	p.explosiveness = 1.0
	p.z_index = 30
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 6.0
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 180.0
	mat.gravity = Vector3(0, 320, 0)
	mat.initial_velocity_min = 110.0
	mat.initial_velocity_max = 280.0
	mat.scale_min = 0.4
	mat.scale_max = 1.0
	mat.color = color
	p.process_material = mat
	host.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)

func _star_count() -> int:
	# Move-count is invariant under drag-any-to-any, so stars come from OPTIONAL things:
	var s := 1                                                   # ★  cleared (can't-lose floor)
	if (ticket.is_empty() or _ticket_done()) and (shelf_targets.is_empty() or _shelf_complete()) \
			and (floor_cells.is_empty() or _floor_complete()):
		s += 1                                                   # ★★ met the board's goals (ticket + shelf + floor)
	if not _used_undo:
		s += 1                                                   # ★★★ a clean, no-undo clear
	return s

func _play_zero() -> void:
	animating = true
	Progress.add_cleared(1)
	Audio.play("level_complete", 1.0)
	var stars := _star_count()
	# economy: pay for the clear (full the first time, a trickle on replay), bank it, update wallet
	var lvid: String = Levels.LEVELS[level_index].get("id", "lvl_%d" % level_index)
	var earned := Econ.clear_payout(stars, not Save.clear_paid(lvid))
	Save.add_coins(earned)
	Save.record_job(lvid, stars, drags)
	Quests.on_event("clear")
	Quests.on_event("coins", earned)     # daily-bundle counters (chip kinds never match these)
	_update_coins()
	var ov := Control.new()
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_STOP
	ov.gui_input.connect(_zero_input.bind(ov))
	add_child(ov)

	var veil := ColorRect.new()
	veil.color = Color(Palette.BG_DEEP, 0.0)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ov.add_child(veil)
	create_tween().tween_property(veil, "color:a", 0.88, 0.25)

	var glowtex := _tex_or_null(Palette.FX_GLOW)
	if glowtex != null:
		var glow := TextureRect.new()
		glow.texture = glowtex
		glow.modulate = Color(Palette.GOLD, 0.0)
		glow.size = Vector2(760, 760)
		glow.position = get_viewport_rect().size / 2.0 - Vector2(380, 380)
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ov.add_child(glow)
		create_tween().tween_property(glow, "modulate:a", 0.55, 0.4)

	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ov.add_child(cc)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 20)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(col)

	col.add_child(_label(130, Palette.ACCENT, tr("All tidy!")))
	col.add_child(_label(30, Palette.TEXT, tr("the room's a little cosier  •  %d moves") % drags))

	var star_row := HBoxContainer.new()
	star_row.alignment = BoxContainer.ALIGNMENT_CENTER
	star_row.add_theme_constant_override("separation", 14)
	col.add_child(star_row)
	for i in 3:
		var st := Label.new()
		st.text = "★"
		st.custom_minimum_size = Vector2(96, 96)
		st.pivot_offset = Vector2(48, 48)
		st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		st.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		st.add_theme_font_size_override("font_size", 84)
		st.add_theme_color_override("font_color", Palette.GOLD if i < stars else Palette.SURFACE)
		st.scale = Vector2.ZERO
		star_row.add_child(st)
		stt_anim(create_tween(), st, 0.45 + i * 0.18)

	# coin reward: a gold "+N" that counts up with a sparkle burst
	var coin_lbl := _label(50, Palette.GOLD, "+0")
	col.add_child(coin_lbl)
	var ct := create_tween()
	ct.tween_interval(0.55)
	ct.tween_callback(_burst.bind(get_viewport_rect().size / 2.0 + Vector2(0, 70), Palette.GOLD, ov, 30))
	ct.parallel().tween_callback(func() -> void: Audio.play("merge_success", -3.0, 1.35))
	ct.parallel().tween_method(_set_coin_reward.bind(coin_lbl), 0.0, float(earned), 0.7)
	ct.chain().tween_callback(_pop.bind(coin_lbl))

	col.add_child(_label(26, Palette.ACCENT_2, tr("✨ a new piece for your bedroom")))

	var tap := _label(26, Palette.TEXT_MUTED, tr("tap to continue ▶"))
	col.add_child(tap)
	tap.modulate.a = 0.0
	# Bound to `tap` so the loop dies when the ZERO overlay is dismissed (see _add_ring).
	var tt := tap.create_tween()
	tt.tween_interval(0.9)
	tt.tween_property(tap, "modulate:a", 1.0, 0.4)
	tt.set_loops()
	tt.tween_property(tap, "modulate:a", 0.4, 0.7)
	tt.tween_property(tap, "modulate:a", 1.0, 0.7)

	col.modulate.a = 0.0
	create_tween().tween_property(col, "modulate:a", 1.0, 0.3)
	var ctr := get_viewport_rect().size / 2.0
	_burst(ctr, Palette.GOLD, ov, 40)
	var t2 := create_tween()
	t2.tween_interval(0.25)
	t2.tween_callback(func(): _burst(ctr + Vector2(-140, -40), Palette.ACCENT_2, ov, 24))
	t2.tween_callback(func(): _burst(ctr + Vector2(140, -40), Palette.ACCENT, ov, 24))

func stt_anim(tw: Tween, node: Control, delay: float) -> void:
	tw.tween_interval(delay)
	tw.tween_property(node, "scale", Vector2(1.25, 1.25), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", Vector2.ONE, 0.10)

func _zero_input(event: InputEvent, ov: Control) -> void:
	if (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventScreenTouch and event.pressed):
		_dismiss_zero(ov)

func _dismiss_zero(ov: Control) -> void:
	if not is_instance_valid(ov):
		return
	ov.queue_free()
	animating = false
	_on_next()

# --- buttons ---------------------------------------------------------------

# Undo restores the WHOLE board state, not just the grid — friction/goal progress
# (drawer contents, ticket ticks, shelf fills, rug cells, tangle knots, covers)
# rolls back with it, so undo+redo can't double-tick goals and a popped drawer's
# contents are never lost (the old grid-only undo could corrupt a re-popped drawer
# to a default item and make the board unclearable).
func _snapshot() -> Dictionary:
	return {
		"grid": board.duplicate_grid(),
		"drawers": drawer_contents.duplicate(),
		"ticket": ticket_progress.duplicate(),
		"shelf": shelf_done.duplicate(),
		"floor_cleaned": floor_cleaned.duplicate(),
		"floor_celebrated": _floor_celebrated,
		"tangles": tangles.duplicate(),
		"covers": covers.keys(),
	}

func _on_undo() -> void:
	if animating or history.is_empty():
		return
	var snap: Dictionary = history.pop_back()
	board.grid = snap.grid
	drawer_contents = snap.drawers
	ticket_progress = snap.ticket
	shelf_done = snap.shelf
	floor_cleaned = snap.floor_cleaned
	_floor_celebrated = snap.floor_celebrated
	tangles = snap.tangles
	drags = max(0, drags - 1)
	_used_undo = true
	selected = NONE
	_restore_visuals(snap.covers)
	_update_status()
	_rescue_if_stuck()

# Redraw every board-area layer from CURRENT state (undo restores mid-level state,
# which the _load_level-time builders can't represent — they read the level def).
func _restore_visuals(cover_cells: Array) -> void:
	covers.clear()                     # nodes die with _build_slots; stale keys would
	tangle_nodes.clear()               # leave ghost-locked cells
	_build_slots()                     # slots + tray + drawers (reads drawer_contents)
	_build_floor()
	for cell in floor_cleaned:
		var t: Control = floor_tints.get(cell)
		if is_instance_valid(t):
			t.add_theme_stylebox_override("panel", _floor_style(true))
	_rebuild_pieces()
	for cell in cover_cells:
		var cov := _make_cover()
		cov.position = _cell_pos(cell)
		board_area.add_child(cov)
		covers[cell] = cov
	for cell in tangles:
		var n := _make_tangle(int(tangles[cell]))
		n.position = _cell_pos(cell)
		board_area.add_child(n)
		tangle_nodes[cell] = n
	_refresh_ticket()
	_build_shelf()
	for i in shelf_done.size():
		if bool(shelf_done[i]) and i < shelf_slots.size():
			var slot: Panel = shelf_slots[i]
			var fb := StyleBoxFlat.new()
			fb.bg_color = Color(Palette.GOOD, 0.5)
			fb.set_corner_radius_all(9)
			slot.add_theme_stylebox_override("panel", fb)
			var g = slot.get_node_or_null("ghost")
			if g:
				g.modulate = Color(1, 1, 1, 1)
	_refresh_highlights()

func _on_restart() -> void:
	if animating:
		return
	_load_level(level_index)   # full reset: board, drawers, ticket, shelf, clean-clear flag

func _on_next() -> void:
	if animating:
		return
	# the next thing to DO: the first uncleared job behind an open door; map when all done
	var idx := Districts.next_open_level()
	if idx >= 0 and idx != level_index:
		_load_level(idx)
	else:
		_on_jobs()

func _on_jobs() -> void:
	Session.next_level = level_index
	get_tree().change_scene_to_file("res://scenes/Jobs.tscn")

# --- misc ------------------------------------------------------------------

func _update_status() -> void:
	# one tr() template with placeholders (word order can differ by language), not glued fragments
	status_label.text = "[center]" + (tr("moves %d   •   left %d") % [drags, board.piece_count()]) + "[/center]"

func _update_coins() -> void:
	if coin_count_label:
		coin_count_label.text = str(Save.coins())
	if coin_counter:
		# FTUE staging: the wallet reveals itself WITH the first payout
		coin_counter.visible = Save.coins() > 0 or Save.boards_cleared() > 0

# --- the one session quest chip ----------------------------------------------

func _quest_template() -> String:
	match Quests.kind:
		"drawer":
			return tr("Pop %d drawers") if Quests.need > 1 else tr("Pop the drawer")
		"cover":
			return tr("Lift %d dust covers") if Quests.need > 1 else tr("Lift the dust cover")
		"tangle":
			return tr("Free %d tangles") if Quests.need > 1 else tr("Free the tangle")
		"floor":
			return tr("Clean the rug")
		"shelf":
			return tr("Fill the shelf")
	return tr("Merge %d times") if Quests.need > 1 else tr("Make a merge")

func _update_quest_chip() -> void:
	if quest_label == null:
		return
	var tpl := _quest_template()
	var goal := (tpl % Quests.need) if tpl.contains("%d") else tpl
	if Quests.rewarded:
		quest_label.text = tr("%s  ✓") % goal
		quest_label.add_theme_color_override("font_color", Palette.GOLD)
	else:
		quest_label.text = tr("%s  •  %d / %d") % [goal, Quests.have, Quests.need]
		quest_label.add_theme_color_override("font_color", Palette.ACCENT_2)

# feed an event to the quest layer; celebrate + pay out when the chip completes
func _quest_event(ev: String, n: int = 1) -> void:
	var done := Quests.on_event(ev, n)
	_update_quest_chip()
	if done:
		_update_coins()
		_celebrate(quest_chip, tr("Quest done!"), Palette.GOLD)
		_floating_text(quest_chip.get_global_rect().get_center() + Vector2(20, 26),
			"+%d" % Quests.SESSION_REWARD, Palette.GOLD, 36)

func _set_coin_reward(v: float, lbl: Label) -> void:
	lbl.text = "+%d" % int(v)

func _label(size: int, col: Color, text: String = "") -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Palette.BG_DEEP)
	l.add_theme_constant_override("outline_size", 8)
	return l

