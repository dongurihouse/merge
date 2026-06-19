extends RefCounted
## The SETTINGS card (music · sounds · calm) — one module, opened from BOTH scenes' chrome:
## the map's gear AND the board's bottom bar (owner: settings must be reachable from the board,
## not only after a trip Home). Lifted out of map.gd so the two share one card. Pure builder:
## open(host) mounts a veiled parchment card with the three persisted toggles + Close.
## Layering: ui/ may import core/ + ui/, never scenes/ — see docs/design/merge_spec.md §15.

const Save = preload("res://engine/scripts/core/save.gd")
const Look = preload("res://engine/scripts/ui/skin.gd")
const FX = preload("res://engine/scripts/ui/fx.gd")
const Audio = preload("res://engine/scripts/core/audio.gd")
const Music = preload("res://engine/scripts/core/music.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const INK = Game.PALETTE.INK

static func open(host: Control) -> void:
	Audio.play("button_tap", -2.0)
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.add_child(overlay)
	var veil := ColorRect.new()
	veil.color = Color(INK, 0.6)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(veil)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(cc)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Look.kit_panel("parchment"))
	cc.add_child(card)
	# inner padding so the content clears the parchment's deckled edge (was flush)
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 36)
	pad.add_theme_constant_override("margin_right", 36)
	pad.add_theme_constant_override("margin_top", 30)
	pad.add_theme_constant_override("margin_bottom", 30)
	card.add_child(pad)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 20)
	pad.add_child(col)
	col.add_child(_lbl(TranslationServer.translate("Settings"), 44))
	col.add_child(_toggle("music", TranslationServer.translate("Music: On"), TranslationServer.translate("Music: Off"), false, func() -> void: Music.refresh()))
	col.add_child(_toggle("sfx", TranslationServer.translate("Sounds: On"), TranslationServer.translate("Sounds: Off"), true, Callable()))
	col.add_child(_toggle("calm", TranslationServer.translate("Calm mode: On"), TranslationServer.translate("Calm mode: Off"), false, Callable()))
	col.add_child(Look.button(TranslationServer.translate("Close"), func() -> void:
		Audio.play("button_tap", -2.0)
		overlay.queue_free(), true))
	FX.pop_in(card)

static func _toggle(key: String, on_t: String, off_t: String, def: bool, extra: Callable) -> Button:
	var b := Look.button(on_t if Save.get_setting(key, def) else off_t, func() -> void: pass, false)
	b.pressed.connect(func() -> void:
		Save.set_setting(key, not Save.get_setting(key, def))
		if extra.is_valid():
			extra.call()
		Audio.play("button_tap", -2.0)
		b.text = on_t if Save.get_setting(key, def) else off_t)
	return b

static func _lbl(t: String, size: int) -> Label:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", INK)
	l.add_theme_color_override("font_outline_color", Game.PALETTE.CREAM)
	l.add_theme_constant_override("outline_size", 6)
	return l
