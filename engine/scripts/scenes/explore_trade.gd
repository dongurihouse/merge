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
const FX = preload("res://engine/scripts/ui/fx.gd")     # shared screen-juice toolbox

const INK := Color("#43352B")
const PARCH := Color("#F3E7CE")
const STRAW := Color("#D9B679")
const DIALOG_MAX_W := 540.0
const REVEAL_SCROLL_W := 440.0
const REVEAL_SCROLL_H := 238.0
const REVEAL_CARD_W := 92.0
const REVEAL_CARD_H := 112.0
const REVEAL_ICON_PX := 56.0

var _hud_refresh := Callable()
var _root: Control = null
var _revealed: Array = []        # kinds pulled this Trade session (for the reveal strip)

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
	var Kit: GDScript = load("res://games/grove/tools/ui_workbench_kit.gd")
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_root = center

	var viewport_size := _viewport_size()
	var width: float = minf(viewport_size.x * 0.92, DIALOG_MAX_W)
	var opts: Dictionary = Kit.dialog_opts_from_config(Kit.load_config(Kit.CONFIG_PATH))
	opts["banner_text"] = "Trade"
	opts["banner_icon_id"] = "star"
	opts["banner_font"] = 30
	opts["list_max_h"] = viewport_size.y * 0.74
	opts["on_close"] = func() -> void: _on_done()
	var dialog: Control = Kit.dialog_frame(_trade_body(Kit, width), width, opts)
	dialog.name = "TradeDialog"
	dialog.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	dialog.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	center.add_child(dialog)
	FX.pop_in(dialog)

func _viewport_size() -> Vector2:
	if is_inside_tree():
		return get_viewport_rect().size
	return Vector2(640.0, 720.0)

func _trade_body(Kit: GDScript, width: float) -> Control:
	var col := VBoxContainer.new()
	col.name = "TradeBody"
	col.custom_minimum_size = Vector2(maxf(280.0, width - 92.0), 0)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 12)

	# the run's score as the shared cream amount chip, centred
	var score_chip: Control = Kit.amount_chip("star", "Score  %d" % Explore.score())
	score_chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(score_chip)
	var note := _note("Spend your score on boxes — each opens to a spirit for your hand.")
	note.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.x = width - 120.0
	col.add_child(note)

	# box cards (parchment + a gift icon + an Open pill priced in points), centred + scattered in
	var boxes := HBoxContainer.new()
	boxes.add_theme_constant_override("separation", 12)
	boxes.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var cards: Array = []
	for b in Explore.BOXES:
		var c := _box_card(Kit, b)
		cards.append(c)
		boxes.add_child(c)
	col.add_child(boxes)
	FX.scatter_in(cards)

	# the reveal grid (what you've pulled this session), capped so claims never widen the dialog.
	if not _revealed.is_empty():
		var rev := _label("Revealed", 24, true)
		rev.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		rev.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(rev)

		var strip := ScrollContainer.new()
		strip.name = "RevealScroll"
		strip.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		strip.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		strip.clip_contents = true
		strip.custom_minimum_size = Vector2(minf(REVEAL_SCROLL_W, width - 96.0), REVEAL_SCROLL_H)
		strip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var grid := GridContainer.new()
		grid.name = "RevealGrid"
		grid.columns = 4
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		for kind in _revealed:
			grid.add_child(_spirit_widget(String(kind), REVEAL_ICON_PX))
		strip.add_child(grid)
		col.add_child(strip)

	var done: Button = Kit.pill_button("Done", {"bg": "cream", "art": true, "font": 22})
	done.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	done.pressed.connect(_on_done)
	col.add_child(done)
	return col

func _box_card(Kit: GDScript, b: Dictionary) -> Control:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PARCH
	sb.set_corner_radius_all(16)
	sb.content_margin_left = 16 ; sb.content_margin_right = 16
	sb.content_margin_top = 12 ; sb.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", sb)
	var icon_id := String(b.get("icon", "gift"))
	panel.set_meta("box_icon", icon_id)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var icon: Control = _box_icon(Kit, icon_id, 54.0)
	icon.name = "RushRewardIcon"
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(icon)
	box.add_child(_label(String(b.name), 20, true))
	var count := int(b.get("residents", 1))
	box.add_child(_label("%d spirit%s" % [count, "" if count == 1 else "s"], 16))
	var open: Button = Kit.pill_button("%d pts" % int(b.cost), {"bg": "green", "art": true, "font": 18, "enabled": Explore.score() >= int(b.cost)})
	open.pressed.connect(func() -> void: _on_buy(b))
	box.add_child(open)
	return panel

func _box_icon(Kit: GDScript, icon_id: String, px: float) -> Control:
	var path := "res://games/grove/assets/ui/rush/%s.png" % icon_id
	if ResourceLoader.exists(path):
		var tex: Texture2D = Kit.clean_tex_path(path, 192)
		if tex != null:
			var t := TextureRect.new()
			t.texture = tex
			t.custom_minimum_size = Vector2(px, px)
			t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			t.mouse_filter = Control.MOUSE_FILTER_IGNORE
			return t
	return Kit.make_icon("gift", px)

## Open a box: spend its score cost, then grant its `residents` count of spirits (pouch 1 / chest 4 /
## vault 8) via the SHARED chest grant (Habitat.grant_chest) — the same path map 5's habitat chest uses, so
## each spirit rolls a kind from the unlocked pool AND a tier off the generator curve. Reveals each pull.
func _on_buy(box: Dictionary) -> void:
	if not Explore.buy_box(int(box.get("cost", 0))):
		return
	var granted := Habitat.grant_chest(int(box.get("residents", 1)))
	if not granted.is_empty():
		for inst in granted:
			_revealed.append(String(inst.kind))
		Audio.play("level_complete", -8.0, 1.15)   # JUICE: a reward chime + a callout on a pull
		var label := ("%s!" % String(granted[0].kind).capitalize()) if granted.size() == 1 else ("+%d spirits!" % granted.size())
		FX.celebrate_at(self, get_global_rect().get_center() - Vector2(0, 70), label, STRAW)
	else:
		Audio.play("button_tap", -2.0)
	_rebuild()

func _on_done() -> void:
	Audio.play("button_tap", -2.0)
	SceneWarm.go(get_tree(), "res://engine/scenes/Map.tscn")

# --- widgets ---------------------------------------------------------------------
func _spirit_widget(kind: String, px: float) -> Control:
	var card := PanelContainer.new()
	card.name = "SpiritRevealCard"
	card.set_meta("spirit_reveal_card", true)
	card.custom_minimum_size = Vector2(maxf(REVEAL_CARD_W, px + 36.0), maxf(REVEAL_CARD_H, px + 56.0))
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#FFF4DD")
	sb.border_color = Color(STRAW, 0.62)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", sb)

	var holder := VBoxContainer.new()
	holder.alignment = BoxContainer.ALIGNMENT_CENTER
	holder.add_theme_constant_override("separation", 4)
	card.add_child(holder)

	var icon_center := CenterContainer.new()
	icon_center.custom_minimum_size = Vector2(maxf(0.0, card.custom_minimum_size.x - 16.0), px)
	var icon := Control.new()
	icon.name = "SpiritIcon"
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
		var eye_size := Vector2(maxf(4.0, px * 0.09), maxf(5.0, px * 0.12))
		var eye_gap := px * 0.24
		for i in 2:
			var eye := ColorRect.new()
			eye.name = "SpiritEye%d" % i
			eye.color = Color(INK, 0.82)
			eye.size = eye_size
			eye.position = Vector2(px * 0.5 + (-0.5 + float(i)) * eye_gap - eye_size.x * 0.5, px * 0.50)
			eye.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon.add_child(eye)
	icon_center.add_child(icon)
	holder.add_child(icon_center)
	var name := _label(kind, 13, true)
	name.name = "SpiritName"
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.clip_text = true
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name.custom_minimum_size = Vector2(maxf(0.0, card.custom_minimum_size.x - 18.0), 18.0)
	holder.add_child(name)
	return card

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
