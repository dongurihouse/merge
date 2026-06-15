extends RefCounted
## Shared UI skin helpers (background + buttons), so menu/board/room
## look consistent. Preload: const Skin = preload("res://engine/scripts/ui/skin.gd").
## Metrics live in Tune (engine/scripts/core/tuning.gd → class Skin); colours in Pal.

const Features = preload("res://engine/scripts/core/features.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const Pal = Game.PALETTE
const Tune = preload("res://engine/scripts/core/tuning.gd").UiSkin   # the engine's skin metrics

## Device safe-area insets (notch / home indicator), in CANVAS units for `ctrl`'s
## viewport. Zero on desktop, so layouts are unchanged in dev — pinned chrome adds
## these to its offsets and just works on notched phones.
static func safe_top(ctrl: Control) -> float:
	if not OS.has_feature("mobile"):
		return 0.0          # desktop window ≠ the screen: its safe area doesn't apply
	var win := DisplayServer.window_get_size()
	if win.y <= 0:
		return 0.0
	var safe := DisplayServer.get_display_safe_area()
	return ctrl.get_viewport_rect().size.y * float(safe.position.y) / float(win.y)

static func safe_bottom(ctrl: Control) -> float:
	if not OS.has_feature("mobile"):
		return 0.0
	var win := DisplayServer.window_get_size()
	if win.y <= 0:
		return 0.0
	var safe := DisplayServer.get_display_safe_area()
	var inset := win.y - (safe.position.y + safe.size.y)
	return ctrl.get_viewport_rect().size.y * float(maxi(inset, 0)) / float(win.y)

## Cozy room background + a dark scrim (so foreground UI/tiles pop). Optional art
## override (e.g. a district backdrop); falls back to the bedroom, then flat color.
## Returns the TextureRect (null on the flat fallback) so callers can swap it later.
static func background(host: Control, scrim_alpha: float = Tune.BG_SCRIM_ALPHA, art_path: String = "") -> TextureRect:
	var path := art_path if (art_path != "" and ResourceLoader.exists(art_path)) else ""
	if ResourceLoader.exists(path):
		var bg := TextureRect.new()
		bg.texture = load(path)
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		host.add_child(bg)
		var scrim := ColorRect.new()
		scrim.color = Color(Pal.BG_DEEP, scrim_alpha)
		scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
		scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		host.add_child(scrim)
		return bg
	var c := ColorRect.new()
	c.color = Pal.BG
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(c)
	return null

## The coin marker: generated coin art when present, else the classic gold disc.
static func coin_icon(px: float = Tune.COIN_PX) -> Control:
	if ResourceLoader.exists(Game.art("ui/coin.png")):
		var t := TextureRect.new()
		t.texture = load(Game.art("ui/coin.png"))
		t.custom_minimum_size = Vector2(px, px)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return t
	var coin := Panel.new()
	coin.custom_minimum_size = Vector2(px, px)
	var cstyle := StyleBoxFlat.new()
	cstyle.bg_color = Pal.GOLD
	cstyle.set_corner_radius_all(int(px / 2.0))
	cstyle.border_color = Pal.COIN_EDGE
	cstyle.set_border_width_all(Tune.COIN_BORDER_W)
	coin.add_theme_stylebox_override("panel", cstyle)
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return coin

## --- THE KIT — one source for panels, icons, chips. ------------------------------
## Everything ships twice: kit art when generated, code-drawn fallback with the
## SAME metrics until then. No component invents its own StyleBox again.

static func kit(rel: String) -> String:
	return Game.art("ui/kit/" + rel)

# Glyph fallbacks = exactly today's characters; the swap is art-arrival, not code.
const ICON_GLYPHS := {
	"star": "★", "coin": "🪙", "gem": "💎", "water": "💧", "rain": "☔",
	"cart": "🛒", "gear": "⚙", "check": "✓", "lock": "Lv", "question": "?",
	"home": "◀", "back": "◀", "level": "Lv", "cash": "$",
}
const ICON_TINTS := {"star": Pal.STRAW, "check": Color.WHITE}

## The three surfaces: plank (ground band) · parchment (card) · chip.
static func kit_panel(kind: String) -> StyleBox:
	var p := kit("panel_%s.png" % kind)
	if ResourceLoader.exists(p):
		var sbt := StyleBoxTexture.new()
		sbt.texture = load(p)
		sbt.set_texture_margin_all(Tune.KIT_TEX_MARGIN)        # 512 source — corners never stretch
		match kind:
			"plank":
				sbt.content_margin_left = Tune.PLANK_PAD_X
				sbt.content_margin_right = Tune.PLANK_PAD_X
				sbt.content_margin_top = Tune.PLANK_PAD_Y
				sbt.content_margin_bottom = Tune.PLANK_PAD_Y
			"chip":
				sbt.content_margin_left = Tune.CHIP_PAD_X
				sbt.content_margin_right = Tune.CHIP_PAD_X
				sbt.content_margin_top = Tune.CHIP_PAD_Y
				sbt.content_margin_bottom = Tune.CHIP_PAD_Y
			_:
				sbt.content_margin_left = Tune.PARCH_PAD_X
				sbt.content_margin_right = Tune.PARCH_PAD_X
				sbt.content_margin_top = Tune.PARCH_PAD_T
				sbt.content_margin_bottom = Tune.PARCH_PAD_B
		return sbt
	var sb := StyleBoxFlat.new()
	match kind:
		"plank":
			sb.bg_color = Color(Pal.PLANK, Tune.PLANK_ALPHA)
			sb.set_corner_radius_all(Tune.PLANK_RADIUS)
			sb.set_border_width_all(Tune.PLANK_BORDER_W)
			sb.border_color = Pal.PLANK_EDGE
			sb.content_margin_left = Tune.PLANK_PAD_X
			sb.content_margin_right = Tune.PLANK_PAD_X
			sb.content_margin_top = Tune.PLANK_PAD_Y
			sb.content_margin_bottom = Tune.PLANK_PAD_Y
		"chip":
			sb.bg_color = Color(Pal.INK, Tune.CHIP_ALPHA)
			sb.set_corner_radius_all(Tune.CHIP_RADIUS)
			sb.content_margin_left = Tune.CHIP_PAD_X
			sb.content_margin_right = Tune.CHIP_PAD_X
			sb.content_margin_top = Tune.CHIP_PAD_Y
			sb.content_margin_bottom = Tune.CHIP_PAD_Y
		_:                                       # parchment
			sb.bg_color = Pal.CREAM
			sb.set_corner_radius_all(Tune.PARCH_RADIUS)
			sb.set_border_width_all(Tune.PARCH_BORDER_W)
			sb.border_color = Pal.BARK
			sb.shadow_color = Tune.PARCH_SHADOW
			sb.shadow_size = Tune.PARCH_SHADOW_SIZE
			sb.shadow_offset = Tune.PARCH_SHADOW_OFFSET
			sb.content_margin_left = Tune.PARCH_PAD_X
			sb.content_margin_right = Tune.PARCH_PAD_X
			sb.content_margin_top = Tune.PARCH_PAD_T
			sb.content_margin_bottom = Tune.PARCH_PAD_B
	return sb

## One icon: kit sprite when generated, else today's glyph in a Label.
static func icon(id: String, px: float = Tune.ICON_PX) -> Control:
	var p := kit("icon_%s.png" % id)
	if ResourceLoader.exists(p):
		var t := TextureRect.new()
		t.texture = load(p)
		t.custom_minimum_size = Vector2(px, px)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return t
	var l := Label.new()
	l.text = String(ICON_GLYPHS.get(id, "?"))
	l.add_theme_font_size_override("font_size", int(px))
	l.add_theme_color_override("font_color", ICON_TINTS.get(id, Pal.CREAM))
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## icon + number on a chip — the wallet, water chip, prices, pins all read this way.
static func stat_chip(icon_id: String, text: String = "") -> Dictionary:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", kit_panel("chip"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", Tune.CHIP_ROW_SEP)
	panel.add_child(row)
	var ic := icon(icon_id, Tune.ICON_PX)
	row.add_child(ic)
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", Tune.STAT_NUM_SIZE)
	lbl.add_theme_color_override("font_color", Pal.CREAM)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(lbl)
	return {"node": panel, "label": lbl, "icon": ic}

## A title chip in the HUD pill language (solid cream, lifts off ANY background).
## ONE source for every title. NOTE: kit/ribbon_title.png (a wide gold banner) is
## deliberately NOT used as a nine-patch — its 48px texture margins exceed a title
## chip's ~66px height and collapse it to invisible (the chapter title AND both
## shop titles shipped as floating text that way). Returns a PanelContainer whose
## only child is the centered Label (caller reads get_child(0) if it needs to update text).
static func title_ribbon(text: String, font_px: int = Tune.TITLE_SIZE) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Pal.PILL, Tune.TITLE_BG_ALPHA)
	sb.set_corner_radius_all(Tune.TITLE_RADIUS)
	sb.set_border_width_all(Tune.TITLE_BORDER_W)
	sb.border_color = Color(Pal.PILL_EDGE, Tune.TITLE_EDGE_ALPHA)
	sb.shadow_color = Tune.TITLE_SHADOW
	sb.shadow_size = Tune.TITLE_SHADOW_SIZE
	sb.content_margin_left = Tune.TITLE_PAD_X
	sb.content_margin_right = Tune.TITLE_PAD_X
	sb.content_margin_top = Tune.TITLE_PAD_T
	sb.content_margin_bottom = Tune.TITLE_PAD_B
	p.add_theme_stylebox_override("panel", sb)
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_px)
	l.add_theme_color_override("font_color", Pal.INK)
	l.add_theme_constant_override("outline_size", 0)   # panel-text law: solid chip = the contrast
	p.add_child(l)
	return p

## The press juice: scale dip on touch, overshoot on release. Every button.
static func add_press_juice(b: Button) -> void:
	if not Features.on("press_juice"):
		return
	b.button_down.connect(func() -> void:
		b.pivot_offset = b.size / 2.0
		var tw := b.create_tween()
		tw.tween_property(b, "scale", Tune.PRESS_DOWN_SCALE, Tune.PRESS_DOWN_T))
	b.button_up.connect(func() -> void:
		var tw := b.create_tween()
		tw.tween_property(b, "scale", Tune.PRESS_UP_SCALE, Tune.PRESS_UP_T)
		tw.tween_property(b, "scale", Vector2.ONE, Tune.PRESS_SETTLE_T))

## A poppy rounded button. primary = warm peach CTA; else a soft raised card.
static func button(text: String, cb: Callable, primary: bool = false, tap: Callable = Callable()) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Tune.BTN_MIN_SIZE
	b.add_theme_font_size_override("font_size", Tune.BTN_SIZE)
	b.add_theme_constant_override("outline_size", 0)   # panel-text law: solid pill = the contrast, no halo
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# S6: buttons are SOLID grove pills, not the kit btn_leaf nine-patch. btn_leaf
	# (512×256, 60px margins) COLLAPSES on our 88-96px buttons — vertical margins
	# (120px) exceed the height, so it rendered as a thin green sliver under
	# floating dark text (the documented nine-patch-thinner-than-rect trap, same
	# class as the chapter ribbon). Solid pills in the grove palette: a warm leaf
	# GREEN primary CTA (matches the board Decorate pill), a CREAM secondary
	# (matches the HUD chips) — one consistent, legible button language everywhere.
	var s := StyleBoxFlat.new()
	if primary:
		s.bg_color = Pal.BTN_PRIMARY              # leaf green
		s.border_color = Pal.BTN_PRIMARY_EDGE
		b.add_theme_color_override("font_color", Pal.CREAM)
		b.add_theme_color_override("font_pressed_color", Pal.CREAM)
		b.add_theme_color_override("font_hover_color", Pal.CREAM)
	else:
		s.bg_color = Color(Pal.PILL, Tune.BTN_PILL_ALPHA)        # cream (HUD pill language)
		s.border_color = Color(Pal.PILL_EDGE, Tune.BTN_EDGE_ALPHA)
		b.add_theme_color_override("font_color", Pal.INK)
		b.add_theme_color_override("font_pressed_color", Pal.INK)
		b.add_theme_color_override("font_hover_color", Pal.INK)
	s.set_corner_radius_all(Tune.BTN_RADIUS)
	s.set_border_width_all(Tune.BTN_BORDER_W)
	s.shadow_color = Tune.BTN_SHADOW
	s.shadow_size = Tune.BTN_SHADOW_SIZE
	s.shadow_offset = Tune.BTN_SHADOW_OFFSET
	s.content_margin_left = Tune.BTN_PAD_X
	s.content_margin_right = Tune.BTN_PAD_X
	s.content_margin_top = Tune.BTN_PAD_T
	s.content_margin_bottom = Tune.BTN_PAD_B
	b.add_theme_stylebox_override("normal", s)
	b.add_theme_stylebox_override("hover", s)
	var sp := s.duplicate()
	sp.bg_color = s.bg_color.darkened(Tune.BTN_PRESS_DARKEN)
	sp.shadow_size = Tune.BTN_PRESS_SHADOW_SIZE
	sp.shadow_offset = Tune.BTN_PRESS_SHADOW_OFFSET
	b.add_theme_stylebox_override("pressed", sp)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER   # S6: label centered in the pill
	add_press_juice(b)
	b.pressed.connect(func() -> void:
		if tap.is_valid():
			tap.call()
		cb.call())
	return b
