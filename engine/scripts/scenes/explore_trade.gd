extends Control
## Explore · Trade — beat 3 of the acquire ritual. Spend the run's score on boxes; each box rolls a
## resident KIND from the unlocked pool and lands it in the habitat hand at tier 1 (the Rush↔habitat
## seam). Rarity is parked, so a box reveals a kind, not a rarity. Done returns to the Residents screen
## with the new spirits in hand. Renders over core/explore.gd; the spirits go through Habitat.hand_add.

const G = preload("res://engine/scripts/core/content.gd")
const Save = preload("res://engine/scripts/core/save.gd")
const Explore = preload("res://engine/scripts/core/explore.gd")
const Habitat = preload("res://engine/scripts/core/habitat.gd")
const Hud = preload("res://engine/scripts/ui/hud.gd")
const SceneWarm = preload("res://engine/scripts/core/scene_warm.gd")
const Audio = preload("res://engine/scripts/core/audio.gd")

const INK := Color("#43352B")
const PARCH := Color("#F3E7CE")
const STRAW := Color("#D9B679")

var _hud_refresh := Callable()
var _root: Control = null
var _rng := RandomNumberGenerator.new()
var _revealed: Array = []        # kinds pulled this Trade session (for the reveal strip)

func _ready() -> void:
	_rng.randomize()
	var bg := ColorRect.new()
	bg.color = Color("#EAD9B5")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var hud := Hud.build(self, {"on_level": func() -> void: pass})
	_hud_refresh = hud.get("refresh", Callable())
	_build()

func _rebuild() -> void:
	if _root != null and is_instance_valid(_root):
		_root.queue_free()
	_build()
	if _hud_refresh.is_valid():
		_hud_refresh.call()

func _pool() -> Array:
	return Explore.unlocked_pool(Save.grove().get("unlocks", {}), Save.grove().get("gates", []))

func _build() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = 230.0
	scroll.offset_left = 24.0
	scroll.offset_right = -24.0
	scroll.offset_bottom = -24.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_root = scroll

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 14)
	scroll.add_child(col)

	col.add_child(_heading("Trade"))
	col.add_child(_label("Score: %d" % Explore.score(), 24, true))
	col.add_child(_note("Spend your score on boxes — each opens to a spirit for your hand."))

	# box cards
	var boxes := HBoxContainer.new()
	boxes.add_theme_constant_override("separation", 12)
	for b in Explore.BOXES:
		boxes.add_child(_box_card(b))
	col.add_child(boxes)

	# the reveal strip (what you've pulled this session)
	if not _revealed.is_empty():
		col.add_child(_heading("Revealed"))
		var strip := HBoxContainer.new()
		strip.add_theme_constant_override("separation", 8)
		for kind in _revealed:
			strip.add_child(_spirit_widget(String(kind), 72.0))
		col.add_child(strip)

	col.add_child(_button("Done", _on_done))

func _box_card(b: Dictionary) -> Control:
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
	box.add_child(_label(String(b.name), 22, true))
	box.add_child(_label("%d pts" % int(b.cost), 20))
	var buy := _button("Open", func() -> void: _on_buy(int(b.cost)))
	buy.disabled = Explore.score() < int(b.cost)
	box.add_child(buy)
	return panel

func _on_buy(cost: int) -> void:
	if not Explore.buy_box(cost):
		return
	var pool := _pool()
	var kind := Explore.roll_kind(pool, _rng)
	if kind != "":
		Habitat.hand_add(kind)
		_revealed.append(kind)
	Audio.play("button_tap", -2.0)
	_rebuild()

func _on_done() -> void:
	Audio.play("button_tap", -2.0)
	SceneWarm.go(get_tree(), "res://engine/scenes/Map.tscn")

# --- widgets ---------------------------------------------------------------------
func _spirit_widget(kind: String, px: float) -> Control:
	var holder := VBoxContainer.new()
	holder.add_theme_constant_override("separation", 2)
	var icon := Control.new()
	icon.custom_minimum_size = Vector2(px, px)
	var path := G.resident_art(kind)
	if path != "" and ResourceLoader.exists(path):
		var t := TextureRect.new()
		t.texture = load(path)
		t.set_anchors_preset(Control.PRESET_FULL_RECT)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.add_child(t)
	else:
		var disc := Panel.new()
		disc.set_anchors_preset(Control.PRESET_FULL_RECT)
		var ds := StyleBoxFlat.new()
		ds.bg_color = Color(STRAW, 0.95)
		ds.set_corner_radius_all(int(px / 2.0))
		disc.add_theme_stylebox_override("panel", ds)
		disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.add_child(disc)
	holder.add_child(icon)
	holder.add_child(_label(kind, 14))
	return holder

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
