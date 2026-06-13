extends Control
## Tidy Up — your bedroom, decorated slot-by-slot with earned coins (the spend→reveal loop).
## Drawn as a stack of same-canvas layers: bedroom_base + one overlay per OWNED decor piece
## + a warm additive glow whose strength grows with how furnished the room is. Unowned
## pieces show a tappable price pin; filling every required slot fires the Room Complete
## reveal. Per-slot ownership lives in Save.rooms (see ROOM_PROMPTS.md for the art stack).

const Palette = preload("res://scripts/palette.gd")
const Save = preload("res://scripts/save.gd")
const Econ = preload("res://scripts/econ.gd")
const Audio = preload("res://scripts/audio.gd")
const Music = preload("res://scripts/music.gd")
const UiFont = preload("res://scripts/ui_font.gd")
const Look = preload("res://scripts/skin.gd")
const FX = preload("res://scripts/fx.gd")

const ROOM_ID := "bedroom"
const ROOM_DIR := "res://assets/rooms/"
const GLOW_MAX := 0.45            # additive glow alpha when the room is fully decorated
const FRAME_SIZE := Vector2(960, 1200)   # 4:5, same aspect as the 1024x1280 art

# Catalog: list order = draw order (rug under bed, plant in front of shelf) AND price
# order (Econ.room_slot_cost(index)). The first REQUIRED_COUNT slots complete the room;
# the rest are bonus cosiness. "pin" is the piece's spot, normalized on the art canvas.
const REQUIRED_COUNT := 4
const SLOTS := [
	{"id": "rug",   "pin": Vector2(0.41, 0.76)},
	{"id": "bed",   "pin": Vector2(0.39, 0.55)},
	{"id": "lamp",  "pin": Vector2(0.16, 0.55)},
	{"id": "shelf", "pin": Vector2(0.71, 0.52)},
	{"id": "plant", "pin": Vector2(0.81, 0.77)},
	{"id": "art",   "pin": Vector2(0.62, 0.25)},
]

var frame: Control
var glow_rect: TextureRect
var decor_rects := {}             # slot id -> TextureRect (hidden until owned)
var pins := {}                    # slot id -> Button
var pin_prices := {}              # slot id -> Label (recolored on affordability)
var status_label: Label
var coin_count_label: Label
var _was_complete := false

func _ready() -> void:
	UiFont.apply()
	Music.ensure()
	var bg := ColorRect.new()
	bg.color = Palette.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 20)
	add_child(box)

	box.add_child(_lbl(tr("Your Bedroom"), 56, Palette.TEXT))

	frame = Control.new()
	frame.custom_minimum_size = FRAME_SIZE
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(frame)
	_build_room()

	status_label = _lbl("", 30, Palette.ACCENT_2)
	box.add_child(status_label)
	_update_status()

	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 18)
	box.add_child(bar)
	bar.add_child(_button(tr("Tidy up! ▶"), Palette.ACCENT, Palette.BG_DEEP, _on_play))
	bar.add_child(_button(tr("◀ Menu"), Palette.SURFACE, Palette.TEXT, _on_menu))

	_build_wallet()
	_was_complete = _is_complete()

# --- the layered room --------------------------------------------------------

func _build_room() -> void:
	var base := _img(ROOM_DIR + "bedroom_base.png")
	if base == null:
		var ph := _lbl(tr("(room art missing)"), 30, Palette.TEXT_MUTED)
		ph.set_anchors_preset(Control.PRESET_FULL_RECT)
		frame.add_child(ph)
		return
	frame.add_child(base)

	for s in SLOTS:
		var rect := _img(ROOM_DIR + "decor_%s.png" % s.id)
		if rect == null:
			continue                       # art not generated yet → slot simply absent
		rect.visible = Save.decor_owned(ROOM_ID, s.id)
		frame.add_child(rect)
		decor_rects[s.id] = rect

	glow_rect = _img(ROOM_DIR + "bedroom_glow.png")
	if glow_rect != null:
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		glow_rect.material = add
		glow_rect.modulate.a = _glow_alpha()
		frame.add_child(glow_rect)

	for i in SLOTS.size():
		var s: Dictionary = SLOTS[i]
		if decor_rects.has(s.id) and not Save.decor_owned(ROOM_ID, s.id):
			_add_pin(i)
	_breathe_first_pin()

func _glow_alpha() -> float:
	var have := 0
	for s in SLOTS:
		if decor_rects.has(s.id):
			have += 1
	if have == 0:
		return 0.0
	return GLOW_MAX * float(Save.decor_count(ROOM_ID)) / float(have)

func _is_complete() -> bool:
	for i in REQUIRED_COUNT:
		var id: String = SLOTS[i].id
		if decor_rects.has(id) and not Save.decor_owned(ROOM_ID, id):
			return false
	return not decor_rects.is_empty()

# Canonical "is the bedroom done" for progression (the Jobs map's room-door).
# Unlike the instance _is_complete(), this doesn't tolerate missing art files.
static func bedroom_complete() -> bool:
	for i in REQUIRED_COUNT:
		if not Save.decor_owned(ROOM_ID, SLOTS[i].id):
			return false
	return true

# --- price pins + buying -------------------------------------------------------

func _add_pin(slot_index: int) -> void:
	var s: Dictionary = SLOTS[slot_index]
	var cost := Econ.room_slot_cost(slot_index)
	var pin := Button.new()
	pin.focus_mode = Control.FOCUS_NONE
	pin.custom_minimum_size = Vector2(150, 62)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(Palette.BG_DEEP, 0.72)
	st.set_corner_radius_all(31)
	st.border_color = Palette.GOLD
	st.set_border_width_all(3)
	pin.add_theme_stylebox_override("normal", st)
	pin.add_theme_stylebox_override("hover", st)
	var sp := st.duplicate()
	sp.bg_color = Color(Palette.BG_DEEP, 0.9)
	pin.add_theme_stylebox_override("pressed", sp)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pin.add_child(row)
	var coin := Panel.new()
	coin.custom_minimum_size = Vector2(26, 26)
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var cs := StyleBoxFlat.new()
	cs.bg_color = Palette.GOLD
	cs.set_corner_radius_all(13)
	cs.border_color = Color("#C98A2B")
	cs.set_border_width_all(2)
	coin.add_theme_stylebox_override("panel", cs)
	row.add_child(coin)
	var price := Label.new()
	price.text = str(cost)
	price.add_theme_font_size_override("font_size", 30)
	row.add_child(price)
	# anchor the pin to the piece's normalized spot so it tracks the frame
	var n: Vector2 = s.pin
	pin.anchor_left = n.x
	pin.anchor_right = n.x
	pin.anchor_top = n.y
	pin.anchor_bottom = n.y
	pin.offset_left = -75
	pin.offset_right = 75
	pin.offset_top = -31
	pin.offset_bottom = 31
	pin.pressed.connect(_on_pin.bind(slot_index))
	frame.add_child(pin)
	pins[s.id] = pin
	pin_prices[s.id] = price
	_refresh_pins()

func _refresh_pins() -> void:
	for i in SLOTS.size():
		var id: String = SLOTS[i].id
		if pin_prices.has(id):
			var afford: bool = Save.coins() >= Econ.room_slot_cost(i)
			pin_prices[id].add_theme_color_override(
				"font_color", Palette.TEXT if afford else Palette.TEXT_MUTED)

func _on_pin(slot_index: int) -> void:
	var s: Dictionary = SLOTS[slot_index]
	var cost := Econ.room_slot_cost(slot_index)
	var pin: Button = pins.get(s.id)
	if pin == null:
		return                            # double-tap after the buy already landed
	if not Save.buy_decor(ROOM_ID, s.id, cost):
		Audio.play("invalid_soft", -4.0)
		FX.wobble(pin)
		FX.floating_text(self, pin.get_global_rect().get_center() - Vector2(80, 70),
			tr("Need %d more") % (cost - Save.coins()), Palette.TEXT_MUTED, 34)
		return
	Audio.play("item_drop", -2.0)
	var at := pin.get_global_rect().get_center()
	pin.queue_free()
	pins.erase(s.id)
	pin_prices.erase(s.id)
	_place_decor(s.id)
	FX.burst(self, at - get_global_rect().position, Palette.GOLD, 18)
	_update_coins()
	FX.pop(coin_count_label)
	_refresh_pins()
	_breathe_first_pin()
	_update_status()
	if glow_rect != null:
		var t := create_tween()
		t.tween_property(glow_rect, "modulate:a", _glow_alpha(), 0.6)
	if _is_complete() and not _was_complete:
		_was_complete = true
		_reveal()

# the bought piece drops in and settles — the core "I built that" beat
func _place_decor(id: String) -> void:
	var rect: TextureRect = decor_rects.get(id)
	if rect == null:
		return
	rect.visible = true
	rect.pivot_offset = FRAME_SIZE / 2.0
	rect.modulate.a = 0.0
	rect.position.y = -36.0
	rect.scale = Vector2(1.05, 1.05)
	var t := rect.create_tween()
	t.set_parallel(true)
	t.tween_property(rect, "modulate:a", 1.0, 0.18)
	t.tween_property(rect, "position:y", 0.0, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(rect, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# --- the Room Complete reveal --------------------------------------------------

func _reveal() -> void:
	var t := create_tween()
	t.tween_interval(0.45)
	t.tween_callback(_reveal_beat)
	if glow_rect != null:
		# the warm light swells past its resting level, then settles back
		t.parallel().tween_property(glow_rect, "modulate:a", GLOW_MAX * 1.3, 0.9)\
			.set_trans(Tween.TRANS_SINE)
		t.tween_property(glow_rect, "modulate:a", _glow_alpha(), 1.2)
	_update_status()

func _reveal_beat() -> void:
	Audio.play("level_complete", -2.0)
	FX.pop(frame)
	var c := frame.get_global_rect().get_center() - get_global_rect().position
	FX.floating_text(self, c - Vector2(220, 90), tr("Room complete!"), Palette.GOLD, 72)
	for k in 3:
		var off := Vector2(randf_range(-260, 260), randf_range(-300, 160))
		get_tree().create_timer(0.16 * k).timeout.connect(
			FX.burst.bind(self, c + off, Palette.GOLD if k % 2 == 0 else Palette.ACCENT, 22))

# --- chrome (wallet / status / nav) --------------------------------------------

func _build_wallet() -> void:
	var counter := PanelContainer.new()
	counter.anchor_left = 1.0
	counter.anchor_right = 1.0
	counter.offset_right = -16.0
	counter.offset_top = 16.0 + Look.safe_top(self)
	counter.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	var cbg := StyleBoxFlat.new()
	cbg.bg_color = Color(Palette.BG_DEEP, 0.55)
	cbg.set_corner_radius_all(20)
	cbg.content_margin_left = 14.0
	cbg.content_margin_right = 16.0
	cbg.content_margin_top = 6.0
	cbg.content_margin_bottom = 6.0
	counter.add_theme_stylebox_override("panel", cbg)
	var crow := HBoxContainer.new()
	crow.add_theme_constant_override("separation", 7)
	counter.add_child(crow)
	var coin := Panel.new()
	coin.custom_minimum_size = Vector2(34, 34)
	var cstyle := StyleBoxFlat.new()
	cstyle.bg_color = Palette.GOLD
	cstyle.set_corner_radius_all(17)
	cstyle.border_color = Color("#C98A2B")
	cstyle.set_border_width_all(3)
	coin.add_theme_stylebox_override("panel", cstyle)
	crow.add_child(coin)
	coin_count_label = Label.new()
	coin_count_label.add_theme_font_size_override("font_size", 34)
	coin_count_label.add_theme_color_override("font_color", Palette.TEXT)
	coin_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	crow.add_child(coin_count_label)
	add_child(counter)
	_update_coins()

func _update_coins() -> void:
	coin_count_label.text = str(Save.coins())

func _update_status() -> void:
	if decor_rects.is_empty():
		status_label.text = ""
	elif _is_complete():
		status_label.text = tr("Room complete!  ✨")
		status_label.add_theme_color_override("font_color", Palette.GOLD)
	else:
		status_label.text = tr("%d / %d decorated") % [Save.decor_count(ROOM_ID), decor_rects.size()]

func _on_play() -> void:
	Audio.play("button_tap", -2.0)
	get_tree().change_scene_to_file("res://scenes/Jobs.tscn")

func _on_menu() -> void:
	Audio.play("button_tap", -2.0)
	get_tree().change_scene_to_file("res://scenes/Menu.tscn")

# --- juice (shared helpers live in fx.gd) ------------------------------------------

# gentle attention pulse on ONE pin (the cheapest) — all six pulsing would be noise
var _breathing_id := ""

func _breathe_first_pin() -> void:
	if pins.is_empty() or pins.has(_breathing_id):
		return
	var id: String = pins.keys()[0]   # insertion order = catalog/price order
	_breathing_id = id
	FX.breathe(pins[id])

# --- small builders ---------------------------------------------------------------

func _img(path: String) -> TextureRect:
	if not ResourceLoader.exists(path):
		return null
	var rect := TextureRect.new()
	rect.texture = load(path)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect

func _lbl(t: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Palette.BG_DEEP)
	l.add_theme_constant_override("outline_size", 8)
	return l

func _button(text: String, bg: Color, fg: Color, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(300, 96)
	b.add_theme_font_size_override("font_size", 34)
	b.focus_mode = Control.FOCUS_NONE
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(26)
	b.add_theme_stylebox_override("normal", s)
	b.add_theme_stylebox_override("hover", s)
	var sp := s.duplicate()
	sp.bg_color = bg.darkened(0.12)
	b.add_theme_stylebox_override("pressed", sp)
	b.add_theme_color_override("font_color", fg)
	b.pressed.connect(cb)
	return b
