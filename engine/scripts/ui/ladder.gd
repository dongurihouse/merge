extends RefCounted
## Discovery-ladder MODAL (Wave 3) — the tier ladder for a line: a veiled parchment card with one
## slot per tier (a grown tier shows its sprite, an unseen tier a "?"; the marked tier wears a gold
## ring). Self-contained popup, like ui/shop.gd: builds its overlay into `host` and dismisses on a
## veil tap. The coordinator owns the open-gate (the discovery_ladder feature + line validity) and
## the data (Quests.ladder_entries); this just renders + dismisses.
##   Ladder.open(host, {title: String, entries: Array, mark_tier: int})

const Game = preload("res://engine/scripts/core/game.gd")
const Audio = preload("res://engine/scripts/core/audio.gd")
const Look = preload("res://engine/scripts/ui/skin.gd")
const FX = preload("res://engine/scripts/ui/fx.gd")
const PieceView = preload("res://engine/scripts/ui/piece_view.gd")
const Pal = Game.PALETTE
const GROUND = Pal.GROUND
const GROUND_EDGE = Pal.GROUND_EDGE
const STRAW = Pal.STRAW
const CREAM = Pal.CREAM

static func open(host: Control, opts: Dictionary) -> void:
	var title: String = opts.title
	var entries: Array = opts.entries
	var mark_tier: int = opts.mark_tier
	Audio.play("button_tap", -4.0)
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.add_child(overlay)
	var veil := ColorRect.new()
	veil.color = Color(GROUND_EDGE, 0.55)
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
	# the line title — mirrors the scene's _lbl (centered, GROUND_EDGE ink + outline)
	var head := Label.new()
	head.text = title
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size", 34)
	head.add_theme_color_override("font_color", GROUND_EDGE)
	head.add_theme_color_override("font_outline_color", GROUND_EDGE)
	head.add_theme_constant_override("outline_size", 8)
	col.add_child(head)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	for e in entries:
		var slot := Panel.new()
		slot.custom_minimum_size = Vector2(112, 112)
		var ss := StyleBoxFlat.new()
		ss.bg_color = Color(GROUND, 0.18) if bool(e.seen) else Color(GROUND_EDGE, 0.16)
		ss.set_corner_radius_all(18)
		ss.set_border_width_all(4 if int(e.tier) == mark_tier else 2)
		ss.border_color = STRAW if int(e.tier) == mark_tier else Color(GROUND_EDGE, 0.35)
		slot.add_theme_stylebox_override("panel", ss)
		if bool(e.seen):
			var ic := PieceView.make_piece(int(e.code), 104.0)
			ic.position = Vector2(4, 4)
			slot.add_child(ic)
		else:
			var q := Look.icon("question", 52.0)
			q.set_anchors_preset(Control.PRESET_FULL_RECT)
			if q is Label:
				(q as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				(q as Label).add_theme_color_override("font_color", Color(CREAM, 0.45))
				(q as Label).add_theme_color_override("font_outline_color", GROUND_EDGE)
				(q as Label).add_theme_constant_override("outline_size", 6)
			slot.add_child(q)
		row.add_child(slot)
	FX.pop_in(card)
