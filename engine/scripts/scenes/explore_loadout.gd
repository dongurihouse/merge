extends Control
## Explore · Load out — beat 1 of the acquire ritual. Spend coins on stackable boosts (the recurring
## coin sink), then Start Rush. Boosts are consumed for the one run. Renders over core/explore.gd and
## hands off to the Rush via Explore.begin_run. Reached from the Residents screen; Back returns there.

const G = preload("res://engine/scripts/core/content.gd")
const Save = preload("res://engine/scripts/core/save.gd")
const Explore = preload("res://engine/scripts/core/explore.gd")
const Hud = preload("res://engine/scripts/ui/hud.gd")
const SceneWarm = preload("res://engine/scripts/core/scene_warm.gd")
const Audio = preload("res://engine/scripts/core/audio.gd")

const INK := Color("#43352B")
const PARCH := Color("#F3E7CE")
const STRAW := Color("#D9B679")

var _hud_refresh := Callable()
var _root: Control = null
var _equip: Dictionary = {}     # boost id -> bool

func _ready() -> void:
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

	col.add_child(_heading("Load out"))
	col.add_child(_note("Spend coins on boosts — stack as many as you can afford, then rush."))

	for it in Explore.LOADOUT:
		col.add_child(_boost_row(it))

	col.add_child(_label("Cost: %d coins" % Explore.loadout_cost(_equip), 24, true))

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 14)
	var start := _button("Start Rush", _on_start)
	start.disabled = not Explore.can_start(_equip)
	actions.add_child(start)
	actions.add_child(_button("Back", _on_back))
	col.add_child(actions)

func _boost_row(it: Dictionary) -> Control:
	var on := bool(_equip.get(String(it.id), false))
	var b := Button.new()
	b.add_theme_font_size_override("font_size", 20)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.text = "%s  %s  ·  %d coins%s" % [String(it.name), String(it.eff), int(it.cost), ("   ✓ equipped" if on else "")]
	if on:
		b.modulate = Color(1.0, 0.92, 0.55)
	b.pressed.connect(func() -> void: _toggle(String(it.id)))
	return b

## Toggle a boost; reverts if turning it on would exceed the wallet (afford-gating).
func _toggle(id: String) -> void:
	var want := not bool(_equip.get(id, false))
	_equip[id] = want
	if want and Explore.loadout_cost(_equip) > Save.coins():
		_equip[id] = false                       # can't afford — leave it off
	Audio.play("button_tap", -2.0)
	_rebuild()

func _on_start() -> void:
	if not Explore.can_start(_equip):
		return
	var cost := Explore.loadout_cost(_equip)
	if cost > 0:
		Save.spend(cost, "explore_loadout")
	Explore.begin_run(_equip)
	Audio.play("button_tap", -2.0)
	SceneWarm.go(get_tree(), "res://engine/scenes/ExploreRush.tscn")

func _on_back() -> void:
	Audio.play("button_tap", -2.0)
	SceneWarm.go(get_tree(), "res://engine/scenes/Residents.tscn")

# --- widgets (match residents.gd) ------------------------------------------------
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
