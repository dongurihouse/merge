extends RefCounted
## Out-of-water OFFER modal (Wave 3) — the honest parchment confirm shown when the player runs dry:
## a title, the amount line + sub copy, the "(test build — nothing is charged)" disclosure, and a
## Maybe-later / Yes-please pair. Self-contained popup (like ui/ladder.gd): builds into `host` and
## dismisses on a veil tap or either button; "Yes please" also fires on_accept. The coordinator owns
## the gate (water == 0 + oow_can_show) and the grant (_grant_oow_offer).
##   OowOffer.open(host, {amount: String, sub: String, on_accept: Callable})

const Game = preload("res://engine/scripts/core/game.gd")
const Look = preload("res://engine/scripts/ui/skin.gd")
const FX = preload("res://engine/scripts/ui/fx.gd")
const Pal = Game.PALETTE

static func open(host: Control, opts: Dictionary) -> void:
	var amount: String = opts.amount
	var sub: String = opts.sub
	var on_accept: Callable = opts.on_accept
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.add_child(overlay)
	var veil := ColorRect.new()
	veil.color = Color(Pal.INK, 0.5)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(veil)
	veil.gui_input.connect(func(ev: InputEvent) -> void:
		if (ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed):
			overlay.queue_free())
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(cc)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Look.kit_panel("parchment"))
	cc.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	card.add_child(col)
	var title := Look.title_ribbon(TranslationServer.translate("A little help"), 32)
	title.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(title)
	var amount_l := Label.new()
	amount_l.text = amount
	amount_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	amount_l.add_theme_font_size_override("font_size", 30)
	amount_l.add_theme_color_override("font_color", Pal.INK)
	col.add_child(amount_l)
	var subl := Label.new()
	subl.text = sub
	subl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subl.add_theme_font_size_override("font_size", 22)
	subl.add_theme_color_override("font_color", Pal.BARK)
	col.add_child(subl)
	var note := Label.new()
	note.text = TranslationServer.translate("(test build — nothing is charged)")
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 22)
	note.add_theme_color_override("font_color", Pal.BARK)
	col.add_child(note)
	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 16)
	col.add_child(btns)
	btns.add_child(Look.button(TranslationServer.translate("Maybe later"), func() -> void: overlay.queue_free(), false))
	btns.add_child(Look.button(TranslationServer.translate("Yes please"), func() -> void:
		overlay.queue_free()
		on_accept.call(), true))
	FX.pop_in(card)
