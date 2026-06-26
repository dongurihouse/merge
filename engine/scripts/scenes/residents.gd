extends Control
## The Residents screen — the management hub for the habitat loop (residents expansion).
## Renders the in-hand holding area + each completed map's habitat, and drives place / merge /
## collect / sell / acquire via engine/scripts/core/habitat.gd. Reached from the map's residents
## button; returns to the Map scene. (Supersedes the per-map welcome overlay — that legacy path in
## map.gd stays callable but is no longer the entry point.)
##
## v1 interaction is TAP-based (deterministic, testable): tap a hand spirit to select it, tap "Place"
## on a map row to place it, tap a second matching hand spirit to merge, tap a placed spirit to sell.
## Drag is a later polish layer over this (board.gd's lift/hit-test pattern).

const G = preload("res://engine/scripts/core/content.gd")
const Save = preload("res://engine/scripts/core/save.gd")
const Habitat = preload("res://engine/scripts/core/habitat.gd")
const Hud = preload("res://engine/scripts/ui/hud.gd")
const SceneWarm = preload("res://engine/scripts/core/scene_warm.gd")
const Audio = preload("res://engine/scripts/core/audio.gd")

const INK := Color("#43352B")
const STRAW := Color("#D9B679")
const PARCH := Color("#F3E7CE")

var _hud_refresh := Callable()
var _root: Control = null      # the content column under the HUD band
var _sel: int = -1             # selected hand index (-1 = none)

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#EAD9B5")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var hud := Hud.build(self, {"on_level": func() -> void: pass})
	_hud_refresh = hud.get("refresh", Callable())
	_build()

## Tear down + rebuild the content column from the live model. Called after every action.
func _rebuild() -> void:
	if _root != null and is_instance_valid(_root):
		_root.queue_free()
	_build()
	if _hud_refresh.is_valid():
		_hud_refresh.call()

func _build() -> void:
	var unlocks: Dictionary = Save.grove().get("unlocks", {})
	var gates: Array = Save.grove().get("gates", [])

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = 230.0      # clear the HUD band
	scroll.offset_left = 24.0
	scroll.offset_right = -24.0
	scroll.offset_bottom = -24.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_root = scroll

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 18)
	scroll.add_child(col)

	col.add_child(_heading("Residents"))

	# one row per COMPLETED map (the habitat surface)
	var any_map := false
	for z in G.MAPS.size():
		if not G.can_populate(z, unlocks, gates):
			continue
		any_map = true
		col.add_child(_map_row(z))
	if not any_map:
		col.add_child(_note("Finish a map to open its habitat."))

	# the in-hand holding area
	col.add_child(_heading("In hand"))
	col.add_child(_hand_strip())

	# the acquire stub (stands in for Rush -> mystery boxes) + back
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 14)
	actions.add_child(_button("Explore", _on_explore))
	actions.add_child(_button("Back", _on_back))
	col.add_child(actions)

# --- rows ------------------------------------------------------------------------
func _map_row(z: int) -> Control:
	var map_id := String(G.MAPS[z].id)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PARCH
	sb.set_corner_radius_all(16)
	sb.content_margin_left = 16 ; sb.content_margin_right = 16
	sb.content_margin_top = 12 ; sb.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", sb)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	# header: name · capacity · production + collect
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	header.add_child(_label(String(G.MAPS[z].name), 26, true))
	header.add_child(_label("%d/%d" % [Habitat.placed(map_id).size(), Habitat.cap(map_id)], 22))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	var cur := Habitat.reward_currency(map_id)
	if cur != "":
		var pend := int(floor(Habitat.pending(map_id)))
		header.add_child(_label("+%d %s" % [pend, cur], 22))
		header.add_child(_button("Collect", func() -> void: _on_collect(map_id)))
	box.add_child(header)

	# placed spirits (tap to sell) + a Place target
	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", 8)
	var placed: Array = Habitat.placed(map_id)
	for i in placed.size():
		var inst: Dictionary = placed[i]
		var idx := i
		strip.add_child(_spirit_widget(String(inst.kind), int(inst.tier), 72.0, func() -> void: _on_sell(map_id, idx)))
	strip.add_child(_button("＋ Place here", func() -> void: _on_place(map_id)))
	box.add_child(strip)
	# drag: the whole map row is a drop TARGET — drop a hand spirit onto it to place
	panel.set_drag_forwarding(Callable(), _map_can_drop.bind(map_id), _map_drop.bind(map_id))
	return panel

func _hand_strip() -> Control:
	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", 8)
	var h: Array = Habitat.hand()
	if h.is_empty():
		return _note("Your hand is empty — find a spirit.")
	for i in h.size():
		var inst: Dictionary = h[i]
		var idx := i
		var w := _spirit_widget(String(inst.kind), int(inst.tier), 72.0, func() -> void: _on_hand_tap(idx))
		if idx == _sel:
			w.modulate = Color(1.0, 0.92, 0.55)   # highlight the selection
		# drag: a hand spirit is a drag SOURCE and a merge drop TARGET (drop onto a matching one)
		w.set_drag_forwarding(_hand_drag.bind(idx), _hand_can_drop.bind(idx), _hand_drop.bind(idx))
		strip.add_child(w)
	return strip

# --- actions ---------------------------------------------------------------------
## Tap a hand spirit: if one is already selected and the two are the same kind+tier, merge them;
## otherwise (re)select this one.
func _on_hand_tap(idx: int) -> void:
	var h: Array = Habitat.hand()
	if idx < 0 or idx >= h.size():
		return
	if _sel != -1 and _sel != idx and _sel < h.size():
		var a: Dictionary = h[_sel]
		var b: Dictionary = h[idx]
		if String(a.kind) == String(b.kind) and int(a.tier) == int(b.tier):
			Habitat.hand_merge(String(a.kind), int(a.tier))
			Audio.play("button_tap", -2.0)
			_sel = -1
			_rebuild()
			return
	_sel = idx
	_rebuild()

func _on_place(map_id: String) -> void:
	if _sel < 0 or _sel >= Habitat.hand().size():
		return
	if Habitat.place(map_id, _sel):
		Audio.play("button_tap", -2.0)
		_sel = -1
		_rebuild()

func _on_sell(map_id: String, idx: int) -> void:
	Habitat.sell(map_id, idx)
	Audio.play("button_tap", -2.0)
	_rebuild()

func _on_collect(map_id: String) -> void:
	Habitat.collect(map_id)
	Audio.play("button_tap", -2.0)
	_rebuild()

## The acquire SOURCE: venture out on the Explore ritual (Load out → Rush → Trade → boxes). The free
## stub it replaces is gone — spirits are now earned. Returns here with the new spirits in the hand.
func _on_explore() -> void:
	Audio.play("button_tap", -2.0)
	SceneWarm.go(get_tree(), "res://engine/scenes/ExploreLoadout.tscn")

func _on_back() -> void:
	Audio.play("button_tap", -2.0)
	SceneWarm.go(get_tree(), "res://engine/scenes/Map.tscn")

# --- drag (polish over the tap fallback) -----------------------------------------
## A hand spirit is a drag SOURCE: lift its index + identity. Returns null for a stale index.
func _hand_drag(_at: Vector2, idx: int) -> Variant:
	var h: Array = Habitat.hand()
	if idx < 0 or idx >= h.size():
		return null
	var inst: Dictionary = h[idx]
	var prev := _spirit_widget(String(inst.kind), int(inst.tier), 64.0, func() -> void: pass)
	prev.modulate = Color(1, 1, 1, 0.85)
	set_drag_preview(prev)
	return {"src": "hand", "index": idx, "kind": String(inst.kind), "tier": int(inst.tier)}

## A hand spirit is also a merge drop TARGET: accept a different hand spirit of the same kind+tier.
func _hand_can_drop(_at: Vector2, data: Variant, idx: int) -> bool:
	if typeof(data) != TYPE_DICTIONARY or String(data.get("src", "")) != "hand":
		return false
	if int(data.get("index", -1)) == idx:
		return false
	var h: Array = Habitat.hand()
	if idx < 0 or idx >= h.size():
		return false
	return String(h[idx].kind) == String(data.get("kind", "")) and int(h[idx].tier) == int(data.get("tier", -1))

func _hand_drop(_at: Vector2, data: Variant, _idx: int) -> void:
	Habitat.hand_merge(String(data.get("kind", "")), int(data.get("tier", -1)))
	Audio.play("button_tap", -2.0)
	_sel = -1
	_rebuild()

## A map row is a placement drop TARGET: accept any hand spirit while there is room.
func _map_can_drop(_at: Vector2, data: Variant, map_id: String) -> bool:
	if typeof(data) != TYPE_DICTIONARY or String(data.get("src", "")) != "hand":
		return false
	return not Habitat.is_full(map_id)

func _map_drop(_at: Vector2, data: Variant, map_id: String) -> void:
	Habitat.place(map_id, int(data.get("index", -1)))
	Audio.play("button_tap", -2.0)
	_sel = -1
	_rebuild()

# --- widgets ---------------------------------------------------------------------
func _spirit_widget(kind: String, tier: int, px: float, on_tap: Callable) -> Control:
	var btn := Button.new()
	btn.flat = true
	btn.custom_minimum_size = Vector2(px, px)
	btn.pressed.connect(on_tap)
	# icon
	var path := G.resident_art(kind)
	if path != "" and ResourceLoader.exists(path):
		var t := TextureRect.new()
		t.texture = load(path)
		t.set_anchors_preset(Control.PRESET_FULL_RECT)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(t)
	else:
		var disc := Panel.new()
		disc.set_anchors_preset(Control.PRESET_FULL_RECT)
		var ds := StyleBoxFlat.new()
		ds.bg_color = Color(STRAW, 0.95)
		ds.set_corner_radius_all(int(px / 2.0))
		disc.add_theme_stylebox_override("panel", ds)
		disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(disc)
	# tier badge
	var badge := Label.new()
	badge.text = "t%d" % tier
	badge.add_theme_font_size_override("font_size", 16)
	badge.add_theme_color_override("font_color", INK)
	badge.add_theme_color_override("font_outline_color", PARCH)
	badge.add_theme_constant_override("outline_size", 4)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(badge)
	return btn

func _heading(text: String) -> Control:
	return _label(text, 30, true)

func _note(text: String) -> Control:
	var l := _label(text, 20)
	l.modulate = Color(1, 1, 1, 0.7)
	return l

func _label(text: String, size: int, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", INK)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if bold:
		l.add_theme_color_override("font_outline_color", PARCH)
		l.add_theme_constant_override("outline_size", 2)
	return l

func _button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(on_press)
	return b
