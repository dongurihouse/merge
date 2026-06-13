extends Control
## Tidy Up — title / main menu.

const Palette = preload("res://scripts/palette.gd")
const Audio = preload("res://scripts/audio.gd")
const Music = preload("res://scripts/music.gd")
const Save = preload("res://scripts/save.gd")
const Session = preload("res://scripts/session.gd")
const Districts = preload("res://scripts/districts.gd")
const UiFont = preload("res://scripts/ui_font.gd")
const Look = preload("res://scripts/skin.gd")

func _ready() -> void:
	UiFont.apply()
	Look.background(self, 0.45)
	Music.ensure()

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 24)
	add_child(box)

	# logo (image if present, else text)
	var logo_tex := _tex(Palette.UI_LOGO)
	if logo_tex != null:
		var logo := TextureRect.new()
		logo.texture = logo_tex
		logo.custom_minimum_size = Vector2(560, 420)
		logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		box.add_child(logo)
	else:
		box.add_child(_lbl(tr("Tidy Up"), 100, Palette.ACCENT))
	box.add_child(_lbl(tr("merge • tidy • relax"), 34, Palette.TEXT))

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 20)
	box.add_child(gap)

	# the v2 Grove (P1 core) — the new game; v1 Play stays below during the transition
	box.add_child(Look.button(tr("Grove ✿"), _on_grove, true))

	# play button (image if present, else styled button)
	var play_tex := _tex(Palette.UI_BTN_PLAY)
	if play_tex != null:
		# btn_play.png ships with "Play" baked into the art — no text overlay.
		var tb := TextureButton.new()
		tb.texture_normal = play_tex
		tb.ignore_texture_size = true
		tb.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		tb.custom_minimum_size = Vector2(360, 235)   # matches btn_play.png aspect ~1.53
		tb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		tb.pressed.connect(_on_play)
		box.add_child(tb)
	else:
		box.add_child(Look.button(tr("Play"), _on_play, true))

	# FTUE staging: the bedroom (and its prices) only makes sense once coins exist
	if Save.boards_cleared() > 0:
		box.add_child(Look.button(tr("Bedroom"), _on_bedroom, false))

	# settings gear, top-right
	var gear := Button.new()
	gear.text = "⚙"
	gear.focus_mode = Control.FOCUS_NONE
	gear.custom_minimum_size = Vector2(84, 84)
	gear.add_theme_font_size_override("font_size", 44)
	gear.add_theme_color_override("font_color", Palette.TEXT)
	var gs := StyleBoxFlat.new()
	gs.bg_color = Color(Palette.BG_DEEP, 0.55)
	gs.set_corner_radius_all(42)
	gear.add_theme_stylebox_override("normal", gs)
	gear.add_theme_stylebox_override("hover", gs)
	gear.add_theme_stylebox_override("pressed", gs)
	gear.anchor_left = 1.0
	gear.anchor_right = 1.0
	var st_inset := Look.safe_top(self)
	gear.offset_left = -100
	gear.offset_right = -16
	gear.offset_top = 16 + st_inset
	gear.offset_bottom = 100 + st_inset
	gear.pressed.connect(_open_settings)
	add_child(gear)

# --- settings overlay (music / sounds — stored in Save.settings) -----------------

func _open_settings() -> void:
	Audio.play("button_tap", -2.0)
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var veil := ColorRect.new()
	veil.color = Color(Palette.BG_DEEP, 0.6)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(veil)

	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(cc)
	var card := PanelContainer.new()
	var cs := StyleBoxFlat.new()
	cs.bg_color = Palette.SURFACE
	cs.set_corner_radius_all(30)
	cs.content_margin_left = 44.0
	cs.content_margin_right = 44.0
	cs.content_margin_top = 34.0
	cs.content_margin_bottom = 34.0
	card.add_theme_stylebox_override("panel", cs)
	cc.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 20)
	card.add_child(col)
	col.add_child(_lbl(tr("Settings"), 44, Palette.ACCENT))

	var music_btn := Look.button(_toggle_text("music", tr("Music: On"), tr("Music: Off")), func() -> void: pass, false)
	music_btn.pressed.connect(func() -> void:
		Save.set_setting("music", not Save.get_setting("music", true))
		Music.refresh()
		Audio.play("button_tap", -2.0)
		music_btn.text = _toggle_text("music", tr("Music: On"), tr("Music: Off")))
	col.add_child(music_btn)

	var sfx_btn := Look.button(_toggle_text("sfx", tr("Sounds: On"), tr("Sounds: Off")), func() -> void: pass, false)
	sfx_btn.pressed.connect(func() -> void:
		Save.set_setting("sfx", not Save.get_setting("sfx", true))
		Audio.play("button_tap", -2.0)   # audible iff just turned ON — its own confirmation
		sfx_btn.text = _toggle_text("sfx", tr("Sounds: On"), tr("Sounds: Off")))
	col.add_child(sfx_btn)

	# calm mode defaults OFF — flip the texts relative to the toggles above
	var calm_btn := Look.button(_toggle_text("calm", tr("Calm mode: On"), tr("Calm mode: Off"), false), func() -> void: pass, false)
	calm_btn.pressed.connect(func() -> void:
		Save.set_setting("calm", not Save.get_setting("calm", false))
		Audio.play("button_tap", -2.0)
		calm_btn.text = _toggle_text("calm", tr("Calm mode: On"), tr("Calm mode: Off"), false))
	col.add_child(calm_btn)

	col.add_child(Look.button(tr("Close"), func() -> void:
		Audio.play("button_tap", -2.0)
		overlay.queue_free(), true))

func _toggle_text(key: String, on_text: String, off_text: String, def := true) -> String:
	return on_text if Save.get_setting(key, def) else off_text

func _on_grove() -> void:
	Audio.play("button_tap", -2.0)
	get_tree().change_scene_to_file("res://scenes/Grove.tscn")

func _on_play() -> void:
	Audio.play("button_tap", -2.0)
	# FTUE beat A: the very first Play goes STRAIGHT into the first board — the
	# map introduces itself after the first clear (one verb at a time).
	if Save.boards_cleared() == 0:
		Session.next_level = maxi(Districts.next_open_level(), 0)
		get_tree().change_scene_to_file("res://scenes/Main.tscn")
		return
	get_tree().change_scene_to_file("res://scenes/Jobs.tscn")

func _on_bedroom() -> void:
	Audio.play("button_tap", -2.0)
	get_tree().change_scene_to_file("res://scenes/Room.tscn")

func _tex(path: String) -> Texture2D:
	return load(path) if ResourceLoader.exists(path) else null

func _lbl(t: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Palette.BG_DEEP)
	l.add_theme_constant_override("outline_size", 8)
	return l

