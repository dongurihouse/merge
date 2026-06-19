extends RefCounted
## Level info popup — opened by tapping the HUD level badge or a locked board cell. Shows the
## player's current Level (the same evolving medal as the HUD/locked cells), the stars earned so
## far, and how many more stars reach the next Level. Self-contained (like ui/oow_offer.gd): builds
## into `host`, dismisses on a veil tap or the Got-it button.
##   LevelPopup.open(host)

const G = preload("res://engine/scripts/core/content.gd")
const Save = preload("res://engine/scripts/core/save.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const Look = preload("res://engine/scripts/ui/skin.gd")
const FX = preload("res://engine/scripts/ui/fx.gd")
const Pal = Game.PALETTE

static func open(host: Control) -> Control:
	var earned := int(Save.grove().get("stars_earned", 0))
	var lvl := G.level_for_stars(earned)
	var base := G.stars_at_level(lvl)            # stars to BE at this level
	var nxt := G.stars_at_level(lvl + 1)         # stars to reach the next
	var into := clampi(earned - base, 0, nxt - base)
	var span := maxi(1, nxt - base)
	var remaining := maxi(0, nxt - earned)

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
	col.add_theme_constant_override("separation", 14)
	card.add_child(col)

	var title := Look.title_ribbon(TranslationServer.translate("Level %d") % lvl, 32)
	title.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(title)

	var badge := Look.make_level_badge(lvl, 120.0)   # the same evolving medal, large
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(badge)

	var tally := Label.new()
	tally.text = TranslationServer.translate("%d / %d ★ earned") % [earned, nxt]
	tally.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tally.add_theme_font_size_override("font_size", 28)
	tally.add_theme_color_override("font_color", Pal.INK)
	col.add_child(tally)

	col.add_child(_progress_bar(into, span))

	var nxt_l := Label.new()
	nxt_l.text = TranslationServer.translate("%d more ★ to reach Level %d") % [remaining, lvl + 1]
	nxt_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nxt_l.add_theme_font_size_override("font_size", 22)
	nxt_l.add_theme_color_override("font_color", Pal.BARK)
	col.add_child(nxt_l)

	var ok := Look.button(TranslationServer.translate("Got it"), func() -> void: overlay.queue_free(), true)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(ok)

	FX.pop_in(card)
	return overlay

# A simple rounded track + honey-gold fill showing progress WITHIN the current level.
static func _progress_bar(into: int, span: int) -> Control:
	var w := 280.0
	var h := 20.0
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(w, h)
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var track := Panel.new()
	track.set_anchors_preset(Control.PRESET_FULL_RECT)
	var tsb := StyleBoxFlat.new()
	tsb.bg_color = Color(Pal.INK, 0.12)
	tsb.set_corner_radius_all(int(h * 0.5))
	track.add_theme_stylebox_override("panel", tsb)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(track)
	var frac := clampf(float(into) / float(span), 0.0, 1.0)
	var fill := Panel.new()
	fill.position = Vector2.ZERO
	fill.size = Vector2(maxf(h, w * frac), h)   # at least a rounded nub so 0% still reads as a bar
	var fsb := StyleBoxFlat.new()
	fsb.bg_color = Pal.STRAW
	fsb.set_corner_radius_all(int(h * 0.5))
	fill.add_theme_stylebox_override("panel", fsb)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(fill)
	return holder
