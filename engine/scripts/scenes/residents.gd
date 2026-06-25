extends Control
## The Residents screen — the management hub for the habitat loop (residents expansion).
## Renders the in-hand holding area + each completed map's habitat, and drives place / merge /
## collect / sell / acquire via engine/scripts/core/habitat.gd. Reached from the map's residents
## button; returns to the Map scene. (Supersedes the per-map welcome overlay — that legacy path
## in map.gd stays callable but is no longer the entry point.)

const G = preload("res://engine/scripts/core/content.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const Save = preload("res://engine/scripts/core/save.gd")
const Habitat = preload("res://engine/scripts/core/habitat.gd")
const Hud = preload("res://engine/scripts/ui/hud.gd")
const Kit = preload("res://games/grove/tools/ui_workbench_kit.gd")
const SceneWarm = preload("res://engine/scripts/core/scene_warm.gd")
const Audio = preload("res://engine/scripts/core/audio.gd")
const Pal = Game.PALETTE

var _hud: Dictionary = {}
var _root: Control = null
var _sel := -1
var _drag_node: Control = null
var _drag_from := -1
var _press_pos := Vector2.ZERO

func _ready() -> void:
	_ensure_background()
	_hud = Hud.build(self, {"on_refresh": func() -> void: _rebuild()})
	if _root == null:
		_build()

func _ensure_background() -> void:
	if get_node_or_null("ResidentsBackground") != null:
		return
	var bg := ColorRect.new()
	bg.name = "ResidentsBackground"
	bg.color = Pal.SCREEN_BG
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	move_child(bg, 0)

## Tear down + rebuild the content column from the live model. Called after every action.
func _rebuild() -> void:
	_clear_drag_preview()
	if _root != null:
		_root.queue_free()
		_root = null
	_build()

func _build() -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "ResidentsContent"
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 28.0
	scroll.offset_right = -28.0
	scroll.offset_top = 176.0
	scroll.offset_bottom = -28.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(scroll)
	_root = scroll

	var col := VBoxContainer.new()
	col.name = "ResidentsColumn"
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 16)
	scroll.add_child(col)

	var title := _label("Residents", 34, Pal.INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	var g := Save.grove()
	var unlocks: Dictionary = g.get("unlocks", {})
	var gates: Array = g.get("gates", [])
	var shown := 0
	for z in G.MAPS.size():
		if G.can_populate(z, unlocks, gates):
			col.add_child(_map_row(z))
			shown += 1
	if shown == 0:
		var empty := _label("Complete a map to open habitats.", 20, Color(Pal.INK, 0.72))
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(empty)

	col.add_child(_hand_section())

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	var find := Kit.pill_button("Find a spirit", {"font": 20, "corner": 12.0})
	find.name = "FindSpiritButton"
	find.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	find.pressed.connect(_on_find_spirit)
	var back := Kit.pill_button("Back", {"bg": "cream", "font": 20, "corner": 12.0})
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(_on_back)
	actions.add_child(find)
	actions.add_child(back)
	col.add_child(actions)

func _map_row(z: int) -> Control:
	var map_id := String(G.MAPS[z].id)
	var placed := Habitat.placed(map_id)
	var row := PanelContainer.new()
	row.name = "MapRow_%s" % map_id
	row.set_meta("map_id", map_id)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.gui_input.connect(func(ev: InputEvent) -> void:
		if _is_release(ev):
			_place_selected(map_id))
	row.add_theme_stylebox_override("panel", _panel_style(Color(Pal.CREAM, 0.94), Color(Pal.STRAW, 0.85), 8, Vector4(14, 12, 14, 12)))
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	row.add_child(body)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	body.add_child(top)

	var name := _label(String(G.MAPS[z].name), 24, Pal.INK)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name)
	var cap := _chip("%d/%d" % [placed.size(), Habitat.cap(map_id)])
	top.add_child(cap)
	var ready := int(floor(Habitat.pending(map_id)))
	top.add_child(_chip("%d ready" % ready))
	var currency := Habitat.reward_currency(map_id)
	if currency != "":
		var collect := Kit.pill_button("Collect", {"font": 18, "corner": 10.0})
		collect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		collect.pressed.connect(func() -> void:
			Audio.play("button_tap", -2.0)
			Habitat.collect(map_id)
			_after_currency_action())
		top.add_child(collect)

	var spirits := HBoxContainer.new()
	spirits.name = "Placed_%s" % map_id
	spirits.add_theme_constant_override("separation", 10)
	body.add_child(spirits)
	if placed.is_empty():
		spirits.add_child(_label("0 residents", 18, Color(Pal.INK, 0.62)))
	else:
		for i in placed.size():
			spirits.add_child(_placed_spirit(map_id, i, placed[i]))
	return row

func _placed_spirit(map_id: String, index: int, inst: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.name = "PlacedSpirit_%s_%d" % [map_id, index]
	box.add_theme_constant_override("separation", 4)
	box.add_child(_spirit_icon(inst, 66.0))
	var sell := Kit.pill_button("Sell", {"bg": "cream", "font": 16, "corner": 8.0, "pad_scale": 0.78})
	sell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sell.pressed.connect(func() -> void:
		Audio.play("button_tap", -2.0)
		Habitat.sell(map_id, index)
		_after_currency_action())
	box.add_child(sell)
	return box

func _hand_section() -> Control:
	var panel := PanelContainer.new()
	panel.name = "HandPanel"
	panel.add_theme_stylebox_override("panel", _panel_style(Color(Pal.BARK, 0.08), Color(Pal.BARK, 0.18), 8, Vector4(14, 12, 14, 12)))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	panel.add_child(body)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	body.add_child(head)
	var label := _label("Hand", 24, Pal.INK)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(label)
	head.add_child(_chip("%d" % Habitat.hand().size()))

	var strip := HBoxContainer.new()
	strip.name = "HandStrip"
	strip.add_theme_constant_override("separation", 10)
	body.add_child(strip)
	var h := Habitat.hand()
	if h.is_empty():
		strip.add_child(_label("Empty", 18, Color(Pal.INK, 0.62)))
	else:
		for i in h.size():
			var hand_index := i
			var icon := _spirit_icon(h[hand_index], 62.0, hand_index == _sel)
			icon.name = "HandSpirit_%d" % hand_index
			icon.set_meta("hand_index", hand_index)
			icon.mouse_filter = Control.MOUSE_FILTER_STOP
			icon.gui_input.connect(func(ev: InputEvent) -> void:
				_on_hand_input(ev, hand_index, icon))
			strip.add_child(icon)
	return panel

func _spirit_icon(inst: Dictionary, px: float, selected: bool = false) -> Control:
	var wrap := PanelContainer.new()
	wrap.custom_minimum_size = Vector2(px + 12.0, px + 22.0)
	wrap.mouse_filter = Control.MOUSE_FILTER_PASS
	var edge := Pal.BTN_PRIMARY if selected else Pal.STRAW
	var fill := Color(Pal.CREAM, 0.96) if selected else Color(Pal.CREAM, 0.82)
	wrap.add_theme_stylebox_override("panel", _panel_style(fill, Color(edge, 0.9), 8, Vector4(6, 6, 6, 6)))
	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 2)
	wrap.add_child(stack)
	var kind := String(inst.get("kind", "moss"))
	var path := G.resident_art(kind)
	var img: Control = null
	if path != "" and ResourceLoader.exists(path):
		var tr := TextureRect.new()
		tr.texture = load(path)
		tr.custom_minimum_size = Vector2(px, px)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		img = tr
	else:
		img = Kit.plated_icon(kind, px, "shared/disc_round.png")
	stack.add_child(img)
	var tier := _label("T%d" % int(inst.get("tier", 1)), 15, Pal.INK)
	tier.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(tier)
	return wrap

func _after_currency_action() -> void:
	if _hud.has("refresh") and _hud.refresh is Callable:
		_hud.refresh.call()
	else:
		_rebuild()

func _on_find_spirit() -> void:
	Audio.play("button_tap", -2.0)
	if G.RESIDENT_CORE.is_empty():
		return
	var pick := randi() % G.RESIDENT_CORE.size()
	Habitat.hand_add(String(G.RESIDENT_CORE[pick].id))
	_sel = -1
	_rebuild()

func _on_hand_tap(index: int) -> void:
	var h := Habitat.hand()
	if index < 0 or index >= h.size():
		_sel = -1
		_rebuild()
		return
	if _sel < 0 or _sel >= h.size() or _sel == index:
		_sel = index
		_rebuild()
		return
	var a: Dictionary = h[_sel]
	var b: Dictionary = h[index]
	if String(a.get("kind", "")) == String(b.get("kind", "")) and int(a.get("tier", 1)) == int(b.get("tier", 1)):
		Audio.play("button_tap", -2.0)
		Habitat.hand_merge(String(a.kind), int(a.tier))
		_sel = -1
	else:
		_sel = index
	_rebuild()

func _on_hand_input(ev: InputEvent, index: int, source: Control) -> void:
	var pressed: bool = (ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed) \
		or (ev is InputEventScreenTouch and ev.pressed)
	if pressed:
		_begin_hand_drag(index, _event_pos_from(source, ev))

func _input(event: InputEvent) -> void:
	if _drag_node == null:
		return
	if event is InputEventMouseMotion or event is InputEventScreenDrag:
		_update_drag(_event_pos(event))
	elif (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed) \
			or (event is InputEventScreenTouch and not event.pressed):
		_end_hand_drag(_event_pos(event))

func _begin_hand_drag(index: int, gpos: Vector2) -> void:
	var h := Habitat.hand()
	if index < 0 or index >= h.size():
		return
	_clear_drag_preview()
	_drag_from = index
	_press_pos = gpos
	_drag_node = _spirit_icon(h[index], 62.0, true)
	_drag_node.name = "HandDragPreview"
	_drag_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_node.z_index = 1000
	_drag_node.scale = Vector2(1.08, 1.08)
	_drag_node.size = _drag_node.custom_minimum_size
	add_child(_drag_node)
	_update_drag(gpos)

func _update_drag(gpos: Vector2) -> void:
	if _drag_node == null:
		return
	var sz := _drag_node.size
	if sz == Vector2.ZERO:
		sz = _drag_node.custom_minimum_size
	_drag_node.global_position = gpos - sz * 0.5

func _end_hand_drag(gpos: Vector2) -> void:
	var from := _drag_from
	var travel := gpos.distance_to(_press_pos)
	_clear_drag_preview()
	if travel <= 18.0:
		_on_hand_tap(from)
		return

	var h := Habitat.hand()
	if from < 0 or from >= h.size():
		_rebuild()
		return
	var drop_hand := _hand_drop_index(gpos, from)
	if drop_hand >= 0 and drop_hand < h.size():
		var a: Dictionary = h[from]
		var b: Dictionary = h[drop_hand]
		if String(a.get("kind", "")) == String(b.get("kind", "")) and int(a.get("tier", 1)) == int(b.get("tier", 1)):
			Audio.play("button_tap", -2.0)
			Habitat.hand_merge(String(a.kind), int(a.tier))
			_sel = -1
			_rebuild()
			return

	var map_id := _map_drop_id(gpos)
	if map_id != "" and not Habitat.is_full(map_id):
		Audio.play("button_tap", -2.0)
		if Habitat.place(map_id, from):
			_sel = -1
			_rebuild()
			return
	_sel = from
	_rebuild()

func _clear_drag_preview() -> void:
	if _drag_node != null and is_instance_valid(_drag_node):
		_drag_node.queue_free()
	_drag_node = null
	_drag_from = -1

func _hand_drop_index(gpos: Vector2, from: int) -> int:
	if _root == null:
		return -1
	for n in _root.find_children("HandSpirit_*", "Control", true, false):
		if n.has_meta("hand_index") and int(n.get_meta("hand_index")) != from \
				and (n as Control).get_global_rect().has_point(gpos):
			return int(n.get_meta("hand_index"))
	return -1

func _map_drop_id(gpos: Vector2) -> String:
	if _root == null:
		return ""
	for n in _root.find_children("MapRow_*", "Control", true, false):
		if n.has_meta("map_id") and (n as Control).get_global_rect().has_point(gpos):
			return String(n.get_meta("map_id"))
	return ""

func _event_pos_from(source: Control, ev: InputEvent) -> Vector2:
	if ev is InputEventMouseButton:
		return source.get_global_transform() * (ev as InputEventMouseButton).position
	if ev is InputEventScreenTouch:
		return source.get_global_transform() * (ev as InputEventScreenTouch).position
	return get_global_mouse_position()

func _event_pos(ev: InputEvent) -> Vector2:
	if ev is InputEventMouseButton:
		return (ev as InputEventMouseButton).position
	if ev is InputEventMouseMotion:
		return (ev as InputEventMouseMotion).position
	if ev is InputEventScreenTouch:
		return (ev as InputEventScreenTouch).position
	if ev is InputEventScreenDrag:
		return (ev as InputEventScreenDrag).position
	return get_global_mouse_position()

func _place_selected(map_id: String) -> void:
	if _sel < 0:
		return
	if Habitat.is_full(map_id):
		_rebuild()
		return
	Audio.play("button_tap", -2.0)
	if Habitat.place(map_id, _sel):
		_sel = -1
	_rebuild()

func _is_release(ev: InputEvent) -> bool:
	return (ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed) \
		or (ev is InputEventScreenTouch and not ev.pressed)

func _label(text: String, font_px: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_px)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l

func _chip(text: String) -> Label:
	var l := _label(text, 18, Pal.INK)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(maxf(54.0, float(text.length()) * 10.0 + 22.0), 34.0)
	l.add_theme_stylebox_override("normal", _panel_style(Color(Pal.CREAM, 0.9), Color(Pal.STRAW, 0.68), 7, Vector4(10, 4, 10, 4)))
	return l

func _panel_style(fill: Color, edge: Color, radius: int, margins: Vector4) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = fill
	st.border_color = edge
	st.set_border_width_all(2)
	st.set_corner_radius_all(radius)
	st.content_margin_left = margins.x
	st.content_margin_top = margins.y
	st.content_margin_right = margins.z
	st.content_margin_bottom = margins.w
	return st

func _on_back() -> void:
	Audio.play("button_tap", -2.0)
	SceneWarm.go(get_tree(), "res://engine/scenes/Map.tscn")
