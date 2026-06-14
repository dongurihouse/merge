extends RefCounted
## Tidy Up — shared UI skin helpers (background + buttons), so menu/board/room
## look consistent. Preload: const Skin = preload("res://engine/scripts/skin.gd").

const Features = preload("res://engine/scripts/features.gd")
const Game = preload("res://engine/scripts/game.gd")
const Config = preload("res://game_config.gd")
const Pal = Config.PALETTE

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
static func background(host: Control, scrim_alpha: float = 0.5, art_path: String = "") -> TextureRect:
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
static func coin_icon(px: float = 34.0) -> Control:
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
	cstyle.border_color = Color("#C98A2B")
	cstyle.set_border_width_all(3)
	coin.add_theme_stylebox_override("panel", cstyle)
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return coin

## --- THE KIT (GROVE_UI_SPEC §1/§3/§4) — one source for panels, icons, chips. ---
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
const ICON_TINTS := {"star": Color("#E3B23C"), "check": Color.WHITE}

## The three surfaces (§1): plank (ground band) · parchment (card) · chip.
static func kit_panel(kind: String) -> StyleBox:
	var p := kit("panel_%s.png" % kind)
	if ResourceLoader.exists(p):
		var sbt := StyleBoxTexture.new()
		sbt.texture = load(p)
		sbt.set_texture_margin_all(96.0)        # 512 source — corners never stretch
		match kind:
			"plank":
				sbt.content_margin_left = 18.0
				sbt.content_margin_right = 18.0
				sbt.content_margin_top = 14.0
				sbt.content_margin_bottom = 14.0
			"chip":
				sbt.content_margin_left = 16.0
				sbt.content_margin_right = 16.0
				sbt.content_margin_top = 6.0
				sbt.content_margin_bottom = 6.0
			_:
				sbt.content_margin_left = 26.0
				sbt.content_margin_right = 26.0
				sbt.content_margin_top = 20.0
				sbt.content_margin_bottom = 22.0
		return sbt
	var sb := StyleBoxFlat.new()
	match kind:
		"plank":
			sb.bg_color = Color("#6E4B2F", 0.94)
			sb.set_corner_radius_all(18)
			sb.set_border_width_all(4)
			sb.border_color = Color("#3D2A1B")
			sb.content_margin_left = 18.0
			sb.content_margin_right = 18.0
			sb.content_margin_top = 14.0
			sb.content_margin_bottom = 14.0
		"chip":
			sb.bg_color = Color("#33402F", 0.62)
			sb.set_corner_radius_all(20)
			sb.content_margin_left = 16.0
			sb.content_margin_right = 16.0
			sb.content_margin_top = 6.0
			sb.content_margin_bottom = 6.0
		_:                                       # parchment
			sb.bg_color = Color("#FBF3EA")
			sb.set_corner_radius_all(26)
			sb.set_border_width_all(5)
			sb.border_color = Color("#8A5A3B")
			sb.shadow_color = Color(0, 0, 0, 0.3)
			sb.shadow_size = 8
			sb.shadow_offset = Vector2(0, 5)
			sb.content_margin_left = 26.0
			sb.content_margin_right = 26.0
			sb.content_margin_top = 20.0
			sb.content_margin_bottom = 22.0
	return sb

## One icon (§3): kit sprite when generated, else today's glyph in a Label.
static func icon(id: String, px: float = 28.0) -> Control:
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
	l.add_theme_color_override("font_color", ICON_TINTS.get(id, Color("#FBF3EA")))
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## icon + number on a chip — the wallet, water chip, prices, pins all read this way.
static func stat_chip(icon_id: String, text: String = "") -> Dictionary:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", kit_panel("chip"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	panel.add_child(row)
	var ic := icon(icon_id, 28.0)
	row.add_child(ic)
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 34)
	lbl.add_theme_color_override("font_color", Color("#FBF3EA"))
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(lbl)
	return {"node": panel, "label": lbl, "icon": ic}

## A title chip in the HUD pill language (solid cream, lifts off ANY background).
## ONE source for every title. NOTE: kit/ribbon_title.png (a wide gold banner) is
## deliberately NOT used as a nine-patch — its 48px texture margins exceed a title
## chip's ~66px height and collapse it to invisible (the chapter title AND both
## shop titles shipped as floating text that way). Returns a PanelContainer whose
## only child is the centered Label (caller reads get_child(0) if it needs to update text).
static func title_ribbon(text: String, font_px: int = 32) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#FBF6EC", 0.96)
	sb.set_corner_radius_all(20)
	sb.set_border_width_all(3)
	sb.border_color = Color("#C9A66B", 0.9)
	sb.shadow_color = Color(0, 0, 0, 0.22)
	sb.shadow_size = 5
	sb.content_margin_left = 30.0
	sb.content_margin_right = 30.0
	sb.content_margin_top = 7.0
	sb.content_margin_bottom = 9.0
	p.add_theme_stylebox_override("panel", sb)
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_px)
	l.add_theme_color_override("font_color", Color("#33402F"))
	l.add_theme_constant_override("outline_size", 0)   # panel-text law: solid chip = the contrast
	p.add_child(l)
	return p

## The §6 press juice: scale dip on touch, overshoot on release. Every button.
static func add_press_juice(b: Button) -> void:
	if not Features.on("press_juice"):
		return
	b.button_down.connect(func() -> void:
		b.pivot_offset = b.size / 2.0
		var tw := b.create_tween()
		tw.tween_property(b, "scale", Vector2(0.96, 0.96), 0.05))
	b.button_up.connect(func() -> void:
		var tw := b.create_tween()
		tw.tween_property(b, "scale", Vector2(1.03, 1.03), 0.05)
		tw.tween_property(b, "scale", Vector2.ONE, 0.04))

## A poppy rounded button. primary = warm peach CTA; else a soft raised card.
static func button(text: String, cb: Callable, primary: bool = false, tap: Callable = Callable()) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(190, 88)
	b.add_theme_font_size_override("font_size", 32)
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
		s.bg_color = Color("#4E7C46")              # leaf green
		s.border_color = Color("#3C6037")
		b.add_theme_color_override("font_color", Color("#FBF3EA"))
		b.add_theme_color_override("font_pressed_color", Color("#FBF3EA"))
		b.add_theme_color_override("font_hover_color", Color("#FBF3EA"))
	else:
		s.bg_color = Color("#FBF6EC", 0.97)        # cream (HUD pill language)
		s.border_color = Color("#C9A66B", 0.9)
		b.add_theme_color_override("font_color", Color("#33402F"))
		b.add_theme_color_override("font_pressed_color", Color("#33402F"))
		b.add_theme_color_override("font_hover_color", Color("#33402F"))
	s.set_corner_radius_all(28)
	s.set_border_width_all(3)
	s.shadow_color = Color(0, 0, 0, 0.30)
	s.shadow_size = 5
	s.shadow_offset = Vector2(0, 3)
	s.content_margin_left = 30.0
	s.content_margin_right = 30.0
	s.content_margin_top = 12.0
	s.content_margin_bottom = 14.0
	b.add_theme_stylebox_override("normal", s)
	b.add_theme_stylebox_override("hover", s)
	var sp := s.duplicate()
	sp.bg_color = s.bg_color.darkened(0.10)
	sp.shadow_size = 2
	sp.shadow_offset = Vector2(0, 1)
	b.add_theme_stylebox_override("pressed", sp)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER   # S6: label centered in the pill
	add_press_juice(b)
	b.pressed.connect(func() -> void:
		if tap.is_valid():
			tap.call()
		cb.call())
	return b
