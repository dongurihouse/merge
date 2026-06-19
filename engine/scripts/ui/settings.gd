extends RefCounted
## The SETTINGS card (music · sounds · calm) — one module, opened from BOTH scenes' chrome:
## the map's gear AND the board's bottom bar (owner: settings must be reachable from the board,
## not only after a trip Home). Lifted out of map.gd so the two share one card. Pure builder:
## open(host) mounts a veiled parchment modal in the SHARED shop/bag language — the gold ribbon
## banner (Look.banner_title), the parchment card (Look.kit_panel), the red ✕ disc
## (Look.close_button) — with one labeled toggle-switch row per persisted setting
## (Look.toggle_switch, wearing the sliced kit/switch_on·off art). No settings-specific chrome.
## Layering: ui/ may import core/ + ui/, never scenes/ — see docs/design/merge_spec.md §15.

const Save = preload("res://engine/scripts/core/save.gd")
const Look = preload("res://engine/scripts/ui/skin.gd")
const FX = preload("res://engine/scripts/ui/fx.gd")
const Audio = preload("res://engine/scripts/core/audio.gd")
const Music = preload("res://engine/scripts/core/music.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const Pal = Game.PALETTE
const INK = Pal.INK

const CARD_MIN_W := 540.0          # the parchment's min width (banner + rows breathe)
const COL_SEP := 16                # gap between the banner and the setting rows
const ROW_LABEL_SIZE := 34         # a setting row's name font size
const ROW_SEP := 24                # gap between a row's name and its switch
const ROW_PILL_ALPHA := 0.55       # a row pill bg = Color(Pal.PILL, this)
const CLOSE_MARGIN := 10.0         # the ✕ disc's inset from the card's top-right corner

static func open(host: Control) -> void:
	Audio.play("button_tap", -2.0)
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.add_child(overlay)
	# the dimmed backdrop, dismissing on tap (the same light modal seam as shop + bag).
	var veil := ColorRect.new()
	veil.color = Color(INK, 0.6)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(veil)
	veil.gui_input.connect(func(ev: InputEvent) -> void:
		if (ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed):
			overlay.queue_free())
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(cc)

	# the shared parchment card (Look.kit_panel) — the same surface shop + bag use.
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Look.kit_panel("parchment"))
	card.custom_minimum_size = Vector2(CARD_MIN_W, 0)
	cc.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", COL_SEP)
	card.add_child(col)

	# the shared gold ribbon banner with engine "Settings" text riding it (Look.banner_title).
	var banner := Look.banner_title(host.tr("Settings"), 40, 108.0)
	banner.size_flags_horizontal = Control.SIZE_FILL
	col.add_child(banner)

	col.add_child(_row(host, "music", host.tr("Music"), false, func() -> void: Music.refresh()))
	col.add_child(_row(host, "sfx", host.tr("Sounds"), true, Callable()))
	col.add_child(_row(host, "calm", host.tr("Calm mode"), false, Callable()))

	# the shared red ✕ disc (Look.close_button), docked inside the card's top-right corner after
	# layout (the shop/bag place-deferred pattern), reconnected on resize.
	var close := Look.close_button(func() -> void: overlay.queue_free())
	overlay.add_child(close)
	var place := func() -> void:
		if not is_instance_valid(card) or not is_instance_valid(close):
			return
		var r := card.get_global_rect()
		var cw: float = close.custom_minimum_size.x
		close.global_position = Vector2(
			r.position.x + r.size.x - cw - CLOSE_MARGIN, r.position.y + CLOSE_MARGIN)
	card.resized.connect(place)
	place.call_deferred()

	FX.pop_in(card)

# One setting row: the name on the left, a toggle switch on the right, riding a soft cream pill
# (the HUD pill language). The switch reads the persisted value; on flip it persists the new
# state, runs an optional side-effect (e.g. Music.refresh), and clicks. `def` = the unset default.
static func _row(host: Control, key: String, label: String, def: bool, extra: Callable) -> Control:
	var pill := PanelContainer.new()
	pill.add_theme_stylebox_override("panel", _row_box())
	pill.size_flags_horizontal = Control.SIZE_FILL
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", ROW_SEP)
	pill.add_child(row)
	var name_l := Label.new()
	name_l.text = label
	name_l.add_theme_font_size_override("font_size", ROW_LABEL_SIZE)
	name_l.add_theme_color_override("font_color", INK)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(name_l)
	var sw := Look.toggle_switch(Save.get_setting(key, def), func(on: bool) -> void:
		Save.set_setting(key, on)
		if extra.is_valid():
			extra.call()
		Audio.play("button_tap", -2.0))
	sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(sw)
	return pill

# A row's soft cream pill (the HUD pill language) — the name + switch ride it, like the
# reference card's rows. Rounded, padded, no border (the parchment is the frame).
static func _row_box() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(Pal.PILL, ROW_PILL_ALPHA)
	s.set_corner_radius_all(22)
	s.content_margin_left = 26.0
	s.content_margin_right = 18.0
	s.content_margin_top = 12.0
	s.content_margin_bottom = 12.0
	return s
