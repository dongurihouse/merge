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

## --- the sticker recipe --------------------------------------------------------------
## A StyleBoxFlat has exactly ONE border colour, so the two-tone rim (a darker OUTER
## edge + a lighter INNER highlight) can't live in a single box. We keep the dark outer
## edge on the box itself and add the light inner rim as a sibling/child OVERLAY: a
## borderless Control that draws ONLY a rounded light stroke, inset by the outer border
## width so it sits just inside it. This reads as a crisp die-cut sticker on any bg, and
## — being mouse-ignored and self-sizing (full-rect) — it costs the caller nothing.
class _RimOverlay extends Control:
	var radius: float = Tune.RADIUS_CARD
	var inset: float = 0.0           # push the rim inward (past the outer border)
	var rim_color: Color = Tune.RIM_LIGHT
	var rim_w: float = float(Tune.RIM_LIGHT_W)
	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)
	# Godot has no rounded-rect OUTLINE primitive, so we stroke a rounded path
	# (4 quarter-arcs + the 4 straight sides) just inside the host's outer border.
	func _draw() -> void:
		var pad := inset + rim_w / 2.0
		var rect := Rect2(Vector2(pad, pad), size - Vector2(pad, pad) * 2.0)
		if rect.size.x <= 0 or rect.size.y <= 0:
			return
		var rr: float = clampf(radius - inset, 1.0, minf(rect.size.x, rect.size.y) / 2.0)
		var pts := PackedVector2Array()
		var seg := 5
		var corners := [
			[Vector2(rect.position.x + rr, rect.position.y + rr), PI, PI * 1.5],      # top-left
			[Vector2(rect.end.x - rr, rect.position.y + rr), PI * 1.5, TAU],          # top-right
			[Vector2(rect.end.x - rr, rect.end.y - rr), 0.0, PI * 0.5],               # bottom-right
			[Vector2(rect.position.x + rr, rect.end.y - rr), PI * 0.5, PI],           # bottom-left
		]
		for corner in corners:
			var ctr: Vector2 = corner[0]
			var a0: float = corner[1]
			var a1: float = corner[2]
			for i in range(seg + 1):
				var a: float = lerpf(a0, a1, float(i) / float(seg))
				pts.append(ctr + Vector2(cos(a), sin(a)) * rr)
		pts.append(pts[0])
		draw_polyline(pts, rim_color, rim_w, true)

## Build the light inner-rim overlay sized to a host. `radius` = the host's OUTER corner
## radius; `outer_w` = the host's outer border width (the rim sits just inside it).
static func rim_overlay(radius: float, outer_w: float = 0.0) -> Control:
	var o := _RimOverlay.new()
	o.radius = float(radius)
	o.inset = outer_w
	return o

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
			_:
				sbt.content_margin_left = Tune.PARCH_PAD_X
				sbt.content_margin_right = Tune.PARCH_PAD_X
				sbt.content_margin_top = Tune.PARCH_PAD_T
				sbt.content_margin_bottom = Tune.PARCH_PAD_B
		return sbt
	# Flat fallbacks adopt the sticker recipe: unified radius (RADIUS_CARD) + a resting drop
	# shadow so each surface lifts off the bg even without the nine-patch art. (The two-tone
	# light inner rim is added by code-built WIDGETS via rim_overlay — a bare StyleBox can't
	# host the second border colour.)  (The "chip" arm was the dark stat_chip pill — retired
	# T48 ahead of the UI redesign.)
	var sb := StyleBoxFlat.new()
	match kind:
		"plank":
			sb.bg_color = Color(Pal.PLANK, Tune.PLANK_ALPHA)
			sb.set_corner_radius_all(Tune.RADIUS_CARD)
			sb.set_border_width_all(Tune.PLANK_BORDER_W)
			sb.border_color = Pal.PLANK_EDGE
			sb.shadow_color = Tune.SHADOW_RESTING
			sb.shadow_size = Tune.SHADOW_RESTING_SIZE
			sb.shadow_offset = Tune.SHADOW_RESTING_OFFSET
			sb.content_margin_left = Tune.PLANK_PAD_X
			sb.content_margin_right = Tune.PLANK_PAD_X
			sb.content_margin_top = Tune.PLANK_PAD_Y
			sb.content_margin_bottom = Tune.PLANK_PAD_Y
		_:                                       # parchment — a raised card surface
			sb.bg_color = Pal.CREAM
			sb.set_corner_radius_all(Tune.RADIUS_CARD)
			sb.set_border_width_all(Tune.PARCH_BORDER_W)
			sb.border_color = Pal.BARK
			sb.shadow_color = Tune.SHADOW_RAISED
			sb.shadow_size = Tune.SHADOW_RAISED_SIZE
			sb.shadow_offset = Tune.SHADOW_RAISED_OFFSET
			sb.content_margin_left = Tune.PARCH_PAD_X
			sb.content_margin_right = Tune.PARCH_PAD_X
			sb.content_margin_top = Tune.PARCH_PAD_T
			sb.content_margin_bottom = Tune.PARCH_PAD_B
	return sb

## One icon: kit sprite when generated, else today's glyph in a Label. BOTH paths
## occupy the SAME px×px box and center their mark inside it, so an icon lines up
## consistently next to a number (the glyph font's own ascent/descent no longer
## nudges it off-center vs a sprite — the box + center alignment normalize it).
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
	l.custom_minimum_size = Vector2(px, px)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

# (stat_chip — "icon + number on a dark chip" → kit_panel("chip") → panel_chip.png — was the
#  dark semicircle pill; retired T48 ahead of the UI redesign. Its three consumers (burst pill,
#  vault gem balance, merchant sell tag) were stripped with it; the redesign rebuilds those reads
#  in the new Rest-plane cream-chip language. The HUD wallet never used it — it builds its own
#  cream PILL_* recipe in hud.gd.)

## A title chip in the HUD pill language (solid cream, lifts off ANY background).
## ONE source for every title. NOTE: kit/ribbon_title.png (a wide gold banner) is
## deliberately NOT used as a nine-patch — its 48px texture margins exceed a title
## chip's ~66px height and collapse it to invisible (titles once shipped as
## floating text that way). Returns a PanelContainer whose
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
	# floating dark text (the documented nine-patch-thinner-than-rect trap, the
	# same class of bug). Solid pills in the grove palette: a warm leaf
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
	# Sticker shadow tier: a primary CTA FLOATS (raised); a secondary RESTS.
	if primary:
		s.shadow_color = Tune.SHADOW_RAISED
		s.shadow_size = Tune.SHADOW_RAISED_SIZE
		s.shadow_offset = Tune.SHADOW_RAISED_OFFSET
	else:
		s.shadow_color = Tune.SHADOW_RESTING
		s.shadow_size = Tune.SHADOW_RESTING_SIZE
		s.shadow_offset = Tune.SHADOW_RESTING_OFFSET
	s.content_margin_left = Tune.BTN_PAD_X
	s.content_margin_right = Tune.BTN_PAD_X
	s.content_margin_top = Tune.BTN_PAD_T
	s.content_margin_bottom = Tune.BTN_PAD_B
	b.add_theme_stylebox_override("normal", s)
	b.add_theme_stylebox_override("hover", s)
	# Pressed: darken (existing juice) AND settle the shadow down to the resting tier —
	# a raised button drops toward the surface, a resting one stays low.
	var sp := s.duplicate()
	sp.bg_color = s.bg_color.darkened(Tune.BTN_PRESS_DARKEN)
	sp.shadow_color = Tune.SHADOW_RESTING
	sp.shadow_size = Tune.BTN_PRESS_SHADOW_SIZE
	sp.shadow_offset = Tune.BTN_PRESS_SHADOW_OFFSET
	b.add_theme_stylebox_override("pressed", sp)
	# the LIGHT inner rim — a sibling overlay inset past the dark outer border, so the
	# button reads as a crisp two-tone sticker on any bg (the StyleBox owns only one
	# border colour; this adds the second). Mouse-ignored; full-rect via _RimOverlay.
	b.add_child(rim_overlay(Tune.BTN_RADIUS, Tune.BTN_BORDER_W))
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER   # S6: label centered in the pill
	add_press_juice(b)
	b.pressed.connect(func() -> void:
		if tap.is_valid():
			tap.call()
		cb.call())
	return b

## A circular chrome button with the sticker recipe — light inner rim + RAISED shadow +
## a fully-circular radius + a centred icon. Prefers the kit's btn_round.png nine-patch
## (no flat chrome then — the art carries it); falls back to a code-built INK disc.
## opts: { "px": float (diameter), "icon_px": float, "bg": Color, "tap": Callable }.
## A LATER wave adopts this in map.gd's chrome — it is NOT wired there yet (per task).
static func round_button(icon_id: String, cb: Callable, opts: Dictionary = {}) -> Button:
	var px: float = float(opts.get("px", Tune.ROUND_BTN_PX))
	var icon_px: float = float(opts.get("icon_px", Tune.ROUND_BTN_ICON_PX))
	var tap: Callable = opts.get("tap", Callable())
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(px, px)
	var p := kit("btn_round.png")
	if ResourceLoader.exists(p):
		var st := StyleBoxTexture.new()
		st.texture = load(p)
		st.set_texture_margin_all(Tune.KIT_TEX_MARGIN / 4.0)   # 512 source vs ~76px button
		b.add_theme_stylebox_override("normal", st)
		b.add_theme_stylebox_override("hover", st)
		b.add_theme_stylebox_override("pressed", st)
	else:
		var s := StyleBoxFlat.new()
		s.bg_color = opts.get("bg", Tune.ROUND_BTN_BG)
		s.set_corner_radius_all(int(px / 2.0))             # circular
		s.set_border_width_all(Tune.ROUND_BTN_BORDER_W)
		s.border_color = Color(Pal.PILL_EDGE, Tune.BTN_EDGE_ALPHA)
		s.shadow_color = Tune.SHADOW_RAISED                # round chrome buttons FLOAT
		s.shadow_size = Tune.SHADOW_RAISED_SIZE
		s.shadow_offset = Tune.SHADOW_RAISED_OFFSET
		b.add_theme_stylebox_override("normal", s)
		b.add_theme_stylebox_override("hover", s)
		var sp := s.duplicate()
		sp.bg_color = s.bg_color.darkened(Tune.BTN_PRESS_DARKEN)
		sp.shadow_color = Tune.SHADOW_RESTING              # pressed → settle toward surface
		sp.shadow_size = Tune.BTN_PRESS_SHADOW_SIZE
		sp.shadow_offset = Tune.BTN_PRESS_SHADOW_OFFSET
		b.add_theme_stylebox_override("pressed", sp)
		# the circular light inner rim (radius = px/2)
		b.add_child(rim_overlay(px / 2.0, Tune.ROUND_BTN_BORDER_W))
	# the icon, centred full-rect over the disc
	var ic := icon(icon_id, icon_px)
	ic.set_anchors_preset(Control.PRESET_FULL_RECT)
	if ic is Label:
		(ic as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		(ic as Label).vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	b.add_child(ic)
	add_press_juice(b)
	b.pressed.connect(func() -> void:
		if tap.is_valid():
			tap.call()
		cb.call())
	return b

## --- badges ---------------------------------------------------------------------------
## A small alert mark for "something new" / a count. kind:
##   "dot"  → a bare red dot with a cream/white rim (no number)
##   "pill" → a red pill carrying `count` (clamped 1+, shows "99+" past 99)
## Always MOUSE_FILTER_IGNORE. Position it via attach_badge (top-right overhang) or by
## hand. Returns a Control (the badge root).
static func badge(kind: String = "dot", count: int = 0) -> Control:
	if kind == "pill":
		var pill := PanelContainer.new()
		pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var s := StyleBoxFlat.new()
		s.bg_color = Tune.BADGE_COLOR
		s.set_corner_radius_all(int(Tune.BADGE_PILL_H / 2.0))
		s.set_border_width_all(Tune.BADGE_RIM_W)
		s.border_color = Tune.BADGE_RIM
		s.content_margin_left = Tune.BADGE_PILL_PAD_X
		s.content_margin_right = Tune.BADGE_PILL_PAD_X
		s.content_margin_top = 1.0
		s.content_margin_bottom = 1.0
		pill.add_theme_stylebox_override("panel", s)
		pill.custom_minimum_size = Vector2(Tune.BADGE_PILL_H, Tune.BADGE_PILL_H)  # min = a circle
		var l := Label.new()
		l.text = ("99+" if count > 99 else str(maxi(count, 1)))
		l.add_theme_font_size_override("font_size", Tune.BADGE_NUM_SIZE)
		l.add_theme_color_override("font_color", Color.WHITE)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pill.add_child(l)
		return pill
	# "dot" — a bare rimmed disc
	var dot := Panel.new()
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ds := StyleBoxFlat.new()
	ds.bg_color = Tune.BADGE_COLOR
	ds.set_corner_radius_all(int(Tune.BADGE_DOT_PX / 2.0))
	ds.set_border_width_all(Tune.BADGE_RIM_W)
	ds.border_color = Tune.BADGE_RIM
	dot.add_theme_stylebox_override("panel", ds)
	dot.custom_minimum_size = Vector2(Tune.BADGE_DOT_PX, Tune.BADGE_DOT_PX)
	dot.size = Vector2(Tune.BADGE_DOT_PX, Tune.BADGE_DOT_PX)
	return dot

## Pin a badge to the top-right CORNER of `host`, overhanging the edge (the badge pokes
## slightly past the corner — the universal "new" placement). The badge is a child of
## host and anchored to its top-right; MOUSE_FILTER_IGNORE keeps the single-input-surface
## rule intact. Returns the badge so the caller can toggle `.visible`.
static func attach_badge(host: Control, b: Control) -> Control:
	host.add_child(b)
	b.set_anchors_preset(Control.PRESET_TOP_RIGHT)   # all offsets now relative to host top-right
	var sz := b.custom_minimum_size
	if sz == Vector2.ZERO:
		sz = b.size
	# OVERHANG = how far the badge's right/top poke PAST host's corner (positive = outside).
	var over := Tune.BADGE_OVERHANG
	b.offset_right = over.x                           # right edge: +over.x past host right
	b.offset_left = b.offset_right - sz.x
	b.offset_top = -over.y                            # top edge: over.y above host top
	b.offset_bottom = b.offset_top + sz.y
	return b
