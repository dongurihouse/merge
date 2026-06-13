extends Control
## Tidy Up — the Jobs map: a portrait scroll of district cards (Districts→Clients→Jobs).
## Each card = district art (or a family-tinted placeholder until the art lands) with
## code-drawn job pins across its calm middle band: gold ✓ stamps for cleared jobs
## (tappable to replay), a breathing peach pin for the next job, muted pins beyond.
## Locked districts sit under a veil with the double-door unlock hint. Completing a
## client's whole run pays their thank-you lump here, once, with a little beat.

const Palette = preload("res://scripts/palette.gd")
const Save = preload("res://scripts/save.gd")
const Districts = preload("res://scripts/districts.gd")
const Quests = preload("res://scripts/quests.gd")
const Session = preload("res://scripts/session.gd")
const Audio = preload("res://scripts/audio.gd")
const Music = preload("res://scripts/music.gd")
const UiFont = preload("res://scripts/ui_font.gd")
const Look = preload("res://scripts/skin.gd")
const FX = preload("res://scripts/fx.gd")

const CARD_SIZE := Vector2(984, 460)

var coin_count_label: Label
var today_label: Label            # the Daily bundle's one line
var card_hosts: Array = []        # per district, for the lump beat

func _ready() -> void:
	UiFont.apply()
	Music.ensure()
	Look.background(self, 0.6)

	var st_inset := Look.safe_top(self)
	var title := _lbl(tr("Jobs"), 56, Palette.ACCENT)
	title.anchor_right = 1.0
	title.offset_top = 26 + st_inset
	add_child(title)

	today_label = _lbl("", 25, Palette.TEXT_MUTED)
	today_label.anchor_right = 1.0
	today_label.offset_top = 102 + st_inset
	add_child(today_label)
	# FTUE staging: the Daily line waits until the loop itself is familiar
	today_label.visible = Save.boards_cleared() >= 2
	_update_today()

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = 148 + st_inset
	scroll.offset_bottom = -132 - Look.safe_bottom(self)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 30)
	scroll.add_child(col)

	for d in Districts.DISTRICTS.size():
		col.add_child(_make_card(d))

	var menu_btn := Look.button(tr("◀ Menu"), _on_menu, false)
	menu_btn.anchor_top = 1.0
	menu_btn.anchor_bottom = 1.0
	menu_btn.anchor_left = 0.5
	menu_btn.anchor_right = 0.5
	var sb_inset := Look.safe_bottom(self)
	menu_btn.offset_top = -116 - sb_inset
	menu_btn.offset_bottom = -28 - sb_inset
	menu_btn.offset_left = -95
	menu_btn.offset_right = 95
	add_child(menu_btn)

	_build_wallet()
	_collect_lumps.call_deferred()

# --- district card ------------------------------------------------------------

func _make_card(d: int) -> Control:
	var info: Dictionary = Districts.DISTRICTS[d]
	var open := Districts.unlocked(d)

	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var st := StyleBoxFlat.new()
	st.bg_color = Palette.SURFACE
	st.set_corner_radius_all(28)
	st.shadow_color = Color(0, 0, 0, 0.35)
	st.shadow_size = 6
	st.shadow_offset = Vector2(0, 4)
	card.add_theme_stylebox_override("panel", st)

	var body := Control.new()
	body.custom_minimum_size = CARD_SIZE
	card.add_child(body)
	card_hosts.append(body)

	# backdrop: district art when generated, else a family-tinted placeholder
	var content := Control.new()                  # dimmable as one (lock veil sits above)
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	body.add_child(content)
	var art_path: String = info.card
	if ResourceLoader.exists(art_path):
		var art := TextureRect.new()
		art.texture = load(art_path)
		art.set_anchors_preset(Control.PRESET_FULL_RECT)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(art)
	else:
		var tint := ColorRect.new()
		tint.color = Palette.SURFACE.lerp(Palette.tier_color(info.family), 0.22)
		tint.set_anchors_preset(Control.PRESET_FULL_RECT)
		tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(tint)
		var wm_path := Palette.item_tex_path(info.family * 100 + 1)
		if ResourceLoader.exists(wm_path):
			var wm := TextureRect.new()     # big soft watermark of the family's item
			wm.texture = load(wm_path)
			wm.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			wm.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			wm.anchor_left = 0.5
			wm.anchor_right = 0.5
			wm.anchor_top = 0.5
			wm.anchor_bottom = 0.5
			wm.offset_left = -170
			wm.offset_right = 170
			wm.offset_top = -170
			wm.offset_bottom = 170
			wm.modulate = Color(1, 1, 1, 0.16)
			wm.mouse_filter = Control.MOUSE_FILTER_IGNORE
			content.add_child(wm)

	# legibility strips top + bottom
	content.add_child(_strip(true))
	content.add_child(_strip(false))

	var name_lbl := _lbl(tr(info.name), 40, Palette.TEXT)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_lbl.position = Vector2(28, 16)
	content.add_child(name_lbl)

	var prog := _lbl(tr("%d / %d tidied") % [Districts.jobs_cleared(d), Districts.job_count(d)], 28, Palette.ACCENT_2)
	prog.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	prog.anchor_left = 1.0
	prog.anchor_right = 1.0
	prog.offset_left = -320
	prog.offset_right = -28
	prog.offset_top = 24
	content.add_child(prog)

	_add_client_chip(content, info.client)

	if open:
		_add_pins(content, d)
	else:
		var veil := ColorRect.new()
		veil.color = Color(Palette.BG_DEEP, 0.62)
		veil.set_anchors_preset(Control.PRESET_FULL_RECT)
		veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body.add_child(veil)
		content.modulate = Color(0.7, 0.7, 0.7, 1.0)
		var lock := _lbl(tr("Locked"), 46, Palette.TEXT)
		lock.set_anchors_preset(Control.PRESET_FULL_RECT)
		lock.offset_top = -34
		lock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		body.add_child(lock)
		var prev: Dictionary = Districts.DISTRICTS[d - 1]
		# two complete templates (no glued fragments — word order varies by language)
		var hint_text: String
		if prev.funds_room == "bedroom":
			hint_text = tr("Tidy %s to unlock — or finish your bedroom") % tr(prev.name)
		else:
			hint_text = tr("Tidy %s to unlock") % tr(prev.name)
		var hint := _lbl(hint_text, 26, Palette.TEXT_MUTED)
		hint.set_anchors_preset(Control.PRESET_FULL_RECT)
		hint.offset_top = 34
		hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		body.add_child(hint)

	return card

func _strip(top: bool) -> TextureRect:
	var g := Gradient.new()
	if top:
		g.set_color(0, Color(Palette.BG_DEEP, 0.55))
		g.set_color(1, Color(Palette.BG_DEEP, 0.0))
	else:
		g.set_color(0, Color(Palette.BG_DEEP, 0.0))
		g.set_color(1, Color(Palette.BG_DEEP, 0.6))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	var rect := TextureRect.new()
	rect.texture = gt
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.anchor_right = 1.0
	if top:
		rect.offset_bottom = 96
	else:
		rect.anchor_top = 1.0
		rect.anchor_bottom = 1.0
		rect.offset_top = -110
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect

func _add_client_chip(content: Control, client: Dictionary) -> void:
	var chip := HBoxContainer.new()
	chip.add_theme_constant_override("separation", 12)
	chip.anchor_top = 1.0
	chip.anchor_bottom = 1.0
	chip.offset_left = 24
	chip.offset_top = -92
	chip.offset_bottom = -18
	content.add_child(chip)
	var face := Panel.new()
	face.custom_minimum_size = Vector2(72, 72)
	var fs := StyleBoxFlat.new()
	fs.bg_color = Palette.ACCENT.darkened(0.1)
	fs.set_corner_radius_all(36)
	fs.border_color = Palette.TEXT
	fs.set_border_width_all(3)
	face.add_theme_stylebox_override("panel", fs)
	chip.add_child(face)
	var bust_path: String = client.bust
	if ResourceLoader.exists(bust_path):
		var bust := TextureRect.new()
		bust.texture = load(bust_path)
		bust.set_anchors_preset(Control.PRESET_FULL_RECT)
		bust.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bust.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		bust.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face.add_child(bust)
	else:
		var init := _lbl(tr(client.name).left(1), 38, Palette.BG_DEEP)
		init.set_anchors_preset(Control.PRESET_FULL_RECT)
		init.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		face.add_child(init)
	var who := _lbl(tr(client.name), 30, Palette.TEXT)
	who.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.add_child(who)

const PIN_SIZE := 112.0
const PIN_GAP := 34.0

func _add_pins(content: Control, d: int) -> void:
	var jobs: Array = Districts.DISTRICTS[d].jobs
	var next := Districts.next_job(d)
	# a soft trail bar behind the pins — reads as the little route through the district
	var span := jobs.size() * PIN_SIZE + (jobs.size() - 1) * PIN_GAP - PIN_SIZE
	var trail := Panel.new()
	trail.anchor_left = 0.5
	trail.anchor_right = 0.5
	trail.anchor_top = 0.5
	trail.anchor_bottom = 0.5
	trail.offset_left = -span / 2.0
	trail.offset_right = span / 2.0
	trail.offset_top = -22.0
	trail.offset_bottom = -12.0
	var ts := StyleBoxFlat.new()
	ts.bg_color = Color(Palette.TEXT, 0.22)
	ts.set_corner_radius_all(5)
	trail.add_theme_stylebox_override("panel", ts)
	trail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(trail)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", int(PIN_GAP))
	row.anchor_left = 0.0
	row.anchor_right = 1.0
	row.anchor_top = 0.5
	row.anchor_bottom = 0.5
	row.offset_top = -72
	row.offset_bottom = 72
	content.add_child(row)
	for i in jobs.size():
		var done := bool(Save.job(jobs[i]).get("completed", false))
		var pin := _make_pin(d, i, done, i == next)
		row.add_child(pin)
		if i == next:
			FX.breathe.call_deferred(pin)   # deferred: needs its laid-out size for the pivot

func _make_pin(d: int, i: int, done: bool, is_next: bool) -> Control:
	var slot := VBoxContainer.new()
	slot.alignment = BoxContainer.ALIGNMENT_CENTER
	slot.add_theme_constant_override("separation", 0)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(PIN_SIZE, PIN_SIZE)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var st := StyleBoxFlat.new()
	st.set_corner_radius_all(int(PIN_SIZE / 2.0))
	st.set_border_width_all(6)
	st.shadow_color = Color(0, 0, 0, 0.35)   # lifts the pin off the card
	st.shadow_size = 6
	st.shadow_offset = Vector2(0, 4)
	if done:
		st.bg_color = Palette.GOLD
		st.border_color = Color("#C98A2B")
		b.text = "✓"
		b.add_theme_color_override("font_color", Color("#7A4F12"))
	elif is_next:
		st.bg_color = Palette.ACCENT
		st.border_color = Palette.TEXT
		b.text = str(i + 1)
		b.add_theme_color_override("font_color", Palette.BG_DEEP)
	else:
		st.bg_color = Palette.SURFACE.lightened(0.08)
		st.border_color = Palette.SURFACE.lightened(0.25)
		b.text = str(i + 1)
		b.add_theme_color_override("font_color", Palette.TEXT_MUTED)
		b.disabled = true                  # the spine is the one ordered layer
	b.add_theme_font_size_override("font_size", 52)
	b.add_theme_stylebox_override("normal", st)
	b.add_theme_stylebox_override("hover", st)
	b.add_theme_stylebox_override("disabled", st)
	var sp := st.duplicate()
	sp.bg_color = st.bg_color.darkened(0.12)
	sp.shadow_size = 2
	sp.shadow_offset = Vector2(0, 1)
	b.add_theme_stylebox_override("pressed", sp)
	# bubble shine — the same soft-3D highlight the item art has
	var shine := Panel.new()
	shine.custom_minimum_size = Vector2(30, 30)
	shine.position = Vector2(20, 14)
	shine.size = Vector2(30, 30)
	var ss := StyleBoxFlat.new()
	ss.bg_color = Color(1, 1, 1, 0.40 if not b.disabled else 0.16)
	ss.set_corner_radius_all(15)
	shine.add_theme_stylebox_override("panel", ss)
	shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(shine)
	if not b.disabled:
		b.pressed.connect(_on_pin.bind(d, i))
	slot.add_child(b)
	var stars := Label.new()                # best stars under cleared pins
	stars.text = "★".repeat(int(Save.job(Districts.DISTRICTS[d].jobs[i]).get("best_stars", 0))) if done else " "
	stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stars.add_theme_font_size_override("font_size", 24)
	stars.add_theme_color_override("font_color", Palette.GOLD)
	stars.add_theme_color_override("font_outline_color", Color("#6E4A28"))
	stars.add_theme_constant_override("outline_size", 6)
	slot.add_child(stars)
	return slot

func _on_pin(d: int, i: int) -> void:
	Audio.play("button_tap", -2.0)
	var idx := Districts.level_index(Districts.DISTRICTS[d].jobs[i])
	if idx < 0:
		return
	Session.next_level = idx
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

# --- the client thank-you lump ---------------------------------------------------

func _collect_lumps() -> void:
	await get_tree().process_frame          # cards laid out → card centers are real
	var beats := 0
	for d in Districts.DISTRICTS.size():
		if not Districts.lump_pending(d):
			continue
		var client: Dictionary = Districts.DISTRICTS[d].client
		if not Save.collect_client_lump(client.id, int(client.lump)):
			continue
		if beats > 0:                       # stagger: simultaneous beats collide visually
			await get_tree().create_timer(0.9).timeout
			if not is_inside_tree():
				return                      # player navigated away mid-celebration
		beats += 1
		_update_coins()
		var host: Control = card_hosts[d]
		var r := host.get_global_rect()
		var c := r.get_center()
		Audio.play("merge_success", -2.0)
		_pile_beat(c + Vector2(0, 36))
		FX.floating_text(self, c - Vector2(150, 40), tr("+%d  •  %s says thanks!") % [int(client.lump), tr(client.name)], Palette.GOLD, 40)
		FX.burst(self, c, Palette.GOLD, 24)
		FX.floating_text(self, Vector2(r.position.x + 30, c.y + 50), tr(client.thanks), Palette.TEXT, 24)
	# the Daily bundle pays here too (the map is the hub between boards)
	if Quests.try_claim_daily():
		if beats > 0:
			await get_tree().create_timer(0.9).timeout
			if not is_inside_tree():
				return
		_update_coins()
		_update_today()
		Audio.play("level_complete", -3.0)
		var top := Vector2(get_global_rect().get_center().x, 150)
		_pile_beat(top + Vector2(0, 70))
		FX.floating_text(self, top - Vector2(230, 0), tr("+%d  •  Daily bundle done!") % Quests.DAILY_REWARD, Palette.GOLD, 44)
		FX.burst(self, top, Palette.GOLD, 24)

# A payout's coin-pile pop (skipped silently until the art lands).
func _pile_beat(at: Vector2) -> void:
	if not ResourceLoader.exists("res://assets/ui/coin_pile.png"):
		return
	var t := TextureRect.new()
	t.texture = load("res://assets/ui/coin_pile.png")
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.size = Vector2(96, 96)
	t.position = at - Vector2(48, 48)
	t.pivot_offset = Vector2(48, 48)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.scale = Vector2(0.4, 0.4)
	t.modulate.a = 0.0
	add_child(t)
	var tw := t.create_tween()
	tw.tween_property(t, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(t, "modulate:a", 1.0, 0.12)
	tw.tween_interval(0.5)
	tw.tween_property(t, "position:y", t.position.y - 60.0, 0.45).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(t, "modulate:a", 0.0, 0.45)
	tw.tween_callback(t.queue_free)

# --- the Today line (the Daily bundle's single surface) ---------------------------

func _update_today() -> void:
	var d := Save.daily()
	if bool(d.get("claimed", false)):
		today_label.text = tr("Daily bundle done!  ✓  •  streak %d") % int(d.get("streak", 0))
		today_label.add_theme_color_override("font_color", Palette.GOLD)
		return
	var text := tr("Today  •  jobs %d/%d  •  merges %d/%d  •  coins %d/%d") % [
		mini(int(d.get("jobs", 0)), int(Quests.DAILY_TARGETS.jobs)), int(Quests.DAILY_TARGETS.jobs),
		mini(int(d.get("merges", 0)), int(Quests.DAILY_TARGETS.merges)), int(Quests.DAILY_TARGETS.merges),
		mini(int(d.get("coins", 0)), int(Quests.DAILY_TARGETS.coins)), int(Quests.DAILY_TARGETS.coins)]
	if int(d.get("streak", 0)) > 0:
		text = tr("%s  •  streak %d") % [text, int(d.get("streak", 0))]
	today_label.text = text

# --- chrome ----------------------------------------------------------------------

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
	crow.add_child(Look.coin_icon(34.0))
	coin_count_label = Label.new()
	coin_count_label.add_theme_font_size_override("font_size", 34)
	coin_count_label.add_theme_color_override("font_color", Palette.TEXT)
	coin_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	crow.add_child(coin_count_label)
	add_child(counter)
	_update_coins()

func _update_coins() -> void:
	coin_count_label.text = str(Save.coins())

func _on_menu() -> void:
	Audio.play("button_tap", -2.0)
	get_tree().change_scene_to_file("res://scenes/Menu.tscn")

func _lbl(t: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Palette.BG_DEEP)
	l.add_theme_constant_override("outline_size", 8)
	return l
