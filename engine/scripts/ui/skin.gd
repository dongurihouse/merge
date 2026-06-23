extends RefCounted
## Shared UI skin helpers (background + buttons), so menu/board/room
## look consistent. Preload: const Skin = preload("res://engine/scripts/ui/skin.gd").
## Metrics live in Tune (engine/scripts/core/tuning.gd → class Skin); colours in Pal.

const Features = preload("res://engine/scripts/core/features.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const Pal = Game.PALETTE
const Tune = preload("res://engine/scripts/core/tuning.gd").UiSkin   # the engine's skin metrics
const TuneShop = preload("res://engine/scripts/core/tuning.gd").Shop # popup-chrome dials (card/✕/banner), shared by every modal

const SHADOW_WARM := Color("#5A371B")
const SHADOW_COOL := Color("#1D1720")

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

static func warm_shadow_color(alpha: float, warmth: float = 0.82) -> Color:
	var c := SHADOW_WARM.lerp(SHADOW_COOL, 1.0 - clampf(warmth, 0.0, 1.0))
	c.a = clampf(alpha, 0.0, 1.0)
	return c

## --- THE KIT — one source for panels, icons, chips. ------------------------------
## Everything ships twice: kit art when generated, code-drawn fallback with the
## SAME metrics until then. No component invents its own StyleBox again.

static func kit(rel: String) -> String:
	return Game.art("ui/" + rel)

# Glyph fallbacks (shown only when a sprite is absent). NOTE: "coin" = the SOFT currency
# (a gold coin) and "gem" = the PREMIUM currency (the grove's golden acorn 🌰) — the icons
# were inverted from the old acorn-coin / dewdrop-gem scheme; the code ids still map to roles.
const ICON_GLYPHS := {
	"star": "★", "coin": "🪙", "gem": "🌰", "water": "💧", "rain": "☔",
	"cart": "🛒", "gear": "⚙", "check": "✓", "lock": "Lv", "question": "?",
	"home": "◀", "back": "◀", "level": "Lv", "cash": "$", "trash": "🗑", "info": "ℹ",
	"plus": "+", "calendar": "📅", "chest": "🎁", "board": "▦",
}
const ICON_TINTS := {"star": Pal.STRAW, "check": Color.WHITE}

## --- the level chip's evolving frame -------------------------------------------------
## The HUD level badge swaps to a fancier gold frame as the player levels up (plainest
## ring 00 -> grand crown 35, sliced from assets/_originals/ui/lvls2.png into ui/lvl/).
## Which badge a Level shows is DATA: res://data/level_badges.json maps Level -> badge index
## by a BANDED rule (fast early, slow late). level_badge_path() returns the resolved art
## path, or "" when the config/art is absent (the HUD then shows the honey-token coin). Parsed once.
const LEVEL_BADGE_CFG := "res://data/level_badges.json"
static var _badge_cfg: Dictionary = {}

static func _level_badge_cfg() -> Dictionary:
	if _badge_cfg.is_empty():
		var f := FileAccess.open(LEVEL_BADGE_CFG, FileAccess.READ)
		if f == null:
			_badge_cfg = {"badge_count": 0}      # cache the "no config" verdict; don't re-open
			return _badge_cfg
		var d = JSON.parse_string(f.get_as_text())
		_badge_cfg = (d as Dictionary) if d is Dictionary else {"badge_count": 0}
	return _badge_cfg

## The badge index for a Level (0-based), or -1 when no badges are configured.
## BANDED: walk `bands` in order; each contributes `tiers` consecutive indices spanning
## `levels_per_tier` levels apiece, so the badge changes fast early and slows down. Past the
## last band the index holds at badge_count-1. Falls back to the legacy single even-tier
## rule (idx = clamp(floor((level-1)/levels_per_tier), 0, count-1)) when `bands` is absent.
static func level_badge_index(level: int) -> int:
	var cfg := _level_badge_cfg()
	var count := int(cfg.get("badge_count", 0))
	if count <= 0:
		return -1
	var lvl := maxi(1, level)
	var bands: Array = cfg.get("bands", [])
	if bands.is_empty():
		var per := maxi(1, int(cfg.get("levels_per_tier", 1)))
		return clampi(int(floor(float(lvl - 1) / float(per))), 0, count - 1)
	var idx := 0
	var cursor := 1                                   # first Level of the current band
	for b in bands:
		var band: Dictionary = b
		var per := maxi(1, int(band.get("levels_per_tier", 1)))
		var tiers := maxi(0, int(band.get("tiers", 0)))
		var span := per * tiers                        # levels this band covers
		if lvl < cursor + span:
			idx += int(floor(float(lvl - cursor) / float(per)))
			return clampi(idx, 0, count - 1)
		idx += tiers
		cursor += span
	return count - 1                                   # past every band -> the grandest badge

## The resolved kit path of the badge for a Level, or "" when config/art is missing.
static func level_badge_path(level: int) -> String:
	var cfg := _level_badge_cfg()
	var idx := level_badge_index(level)
	if idx < 0:
		return ""
	var dir := String(cfg.get("dir", "lvl"))
	var prefix := String(cfg.get("prefix", "badge_"))
	var p := Game.art("ui/%s/%s%02d.png" % [dir, prefix, idx])
	return p if ResourceLoader.exists(p) else ""

## A level-status badge: the evolving gold medal (level_badge_path) with a cream disc behind the
## centred level NUMBER. Falls back to a warm honey token when the medal art is absent. Shared by
## the top-left HUD chip and the locked-cell gate marker — same look, just a different number. `px`
## is the square size; `num_font` overrides the number's font size (auto-scaled from px when < 0).
## The medal TextureRect is named "lv_frame" and the number Label "lv_num" so callers that update
## live (the HUD level-up) can fetch and re-skin them.
static func make_level_badge(level: int, px: float, num_font: int = -1) -> Control:
	var avatar := Panel.new()
	avatar.custom_minimum_size = Vector2(px, px)
	avatar.size = Vector2(px, px)
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex := _safe_tex(level_badge_path(level))
	if tex != null:
		avatar.add_theme_stylebox_override("panel", StyleBoxEmpty.new())   # no dark panel behind the ring
		var disc := Panel.new()                                            # cream centre so the number reads on warm, not sky
		var dpad := px * 0.16
		disc.position = Vector2(dpad, dpad)
		disc.size = Vector2(px - dpad * 2.0, px - dpad * 2.0)
		var dsb := StyleBoxFlat.new()
		dsb.bg_color = Color("#FBF3E2")
		dsb.set_corner_radius_all(int(px))
		disc.add_theme_stylebox_override("panel", dsb)
		disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		avatar.add_child(disc)
		var frame := TextureRect.new()
		frame.name = "lv_frame"
		frame.texture = tex
		frame.set_anchors_preset(Control.PRESET_FULL_RECT)
		frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		avatar.add_child(frame)
	else:
		var coin := StyleBoxFlat.new()                                     # no-art fallback: a warm honey token
		coin.bg_color = Color("#F4CF82")
		coin.set_corner_radius_all(int(px / 2.0))
		coin.set_border_width_all(2)
		coin.border_color = Color("#8D6B35")
		avatar.add_theme_stylebox_override("panel", coin)
	var num := Label.new()
	num.name = "lv_num"
	num.set_anchors_preset(Control.PRESET_FULL_RECT)
	num.text = str(level)
	num.add_theme_font_size_override("font_size", num_font if num_font > 0 else _lv_badge_font(level, px))
	num.add_theme_color_override("font_color", Pal.INK)
	num.add_theme_constant_override("outline_size", 0)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	avatar.add_child(num)
	return avatar

## The level NUMBER size for a `px`-tall badge — steps down as digits grow so it stays inside the
## medal's open centre.
static func _lv_badge_font(level: int, px: float) -> int:
	var digits := str(maxi(0, level)).length()
	var f := px * 0.42
	if digits >= 3:
		f = px * 0.28
	elif digits == 2:
		f = px * 0.34
	return int(maxf(11.0, f))

## Resolve a texture path to a REAL image (rejects the import placeholder + degenerate empty
## imports), or null — so an absent/stale badge falls back to the honey token, never a blank rect.
static func _safe_tex(path: String) -> Texture2D:
	if path == "" or not ResourceLoader.exists(path):
		return null
	var res := load(path)
	var real := res is CompressedTexture2D or res is ImageTexture or res is PortableCompressedTexture2D
	if not real:
		return null
	var tex := res as Texture2D
	if tex == null or tex.get_width() <= 0 or tex.get_height() <= 0:
		return null
	return tex

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
	var p := kit("shared/panel_%s.png" % kind)
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
	# icons split by placement: coin/gem are the currency cluster, the rest are shared chrome
	var dir := "currency" if (id.begins_with("coin") or id.begins_with("gem")) else "shared"
	var p := kit("%s/icon_%s.png" % [dir, id])
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

## --- shared popup chrome — the storefront's reusable card / ✕ / banner builders, promoted from
## shop.gd so EVERY modal (shop, bag, …) speaks one component language (no per-screen asset set). ----

## A nine-patch StyleBoxTexture from a kit sprite, or null when the sprite is absent (the caller
## keeps its code-drawn fallback — the kit invariant). `tex` = the (H,V) non-stretching border;
## `pad` = the content inset (l,t,r,b). A ROUND control passes Vector2.ZERO (full-stretch — 9-slicing
## a disc pinches its ring into a star and lets the backdrop bleed through the transparent corners).
static func kit_box(rel: String, tex: Vector2, pad := Vector4.ZERO) -> StyleBoxTexture:
	var p := kit(rel)
	if not ResourceLoader.exists(p):
		return null
	var sbt := StyleBoxTexture.new()
	sbt.texture = load(p)
	sbt.set_texture_margin(SIDE_LEFT, tex.x)
	sbt.set_texture_margin(SIDE_RIGHT, tex.x)
	sbt.set_texture_margin(SIDE_TOP, tex.y)
	sbt.set_texture_margin(SIDE_BOTTOM, tex.y)
	sbt.content_margin_left = pad.x
	sbt.content_margin_top = pad.y
	sbt.content_margin_right = pad.z
	sbt.content_margin_bottom = pad.w
	return sbt

## The shared popup CARD surface (kit/shop_card.png et al.): a Button wearing the sliced parchment
## nine-patch when present, else a code-drawn card box with the SAME radius/shadow. Carries the
## press-darken juice. The wide welcome card passes shop_card_wide; a plainer tile passes shop_card_b.
static func card_button(min_size: Vector2, art: String = "kit/shop_card.png") -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = min_size
	var box := kit_box(art, Vector2(TuneShop.CARD_TEX_MARGIN, TuneShop.CARD_TEX_MARGIN))
	if box != null:
		b.add_theme_stylebox_override("normal", box)
		b.add_theme_stylebox_override("hover", box)
		var bp: StyleBoxTexture = box.duplicate()
		bp.modulate_color = TuneShop.CARD_PRESS_MODULATE
		b.add_theme_stylebox_override("pressed", bp)
		add_press_juice(b)
		return b
	var s := StyleBoxFlat.new()
	s.bg_color = TuneShop.CARD_BG
	s.set_corner_radius_all(TuneShop.CARD_RADIUS)
	s.set_border_width_all(TuneShop.CARD_BORDER_W)
	s.border_color = Color(Pal.BARK, TuneShop.CARD_EDGE_ALPHA)
	s.shadow_color = TuneShop.CARD_SHADOW
	s.shadow_size = TuneShop.CARD_SHADOW_SIZE
	s.shadow_offset = TuneShop.CARD_SHADOW_OFFSET
	b.add_theme_stylebox_override("normal", s)
	b.add_theme_stylebox_override("hover", s)
	var sp: StyleBoxFlat = s.duplicate()
	sp.bg_color = TuneShop.CARD_BG_PRESSED
	b.add_theme_stylebox_override("pressed", sp)
	add_press_juice(b)
	return b

## The shared popup CLOSE ✕: a Button wearing the sliced red disc (kit/shop_close.png, the ✕ baked
## in) full-stretched, else a code-drawn RED disc with a ✕ glyph. `cb` fires on press. The caller
## sizes/positions it (modals dock it inside the card's top-right corner after layout). `art_rel`
## overrides the disc sprite so a themed modal (the mailbox → kit/mail_close.png) passes its own.
static func close_button(cb: Callable, art_rel: String = "kit/shop_close.png") -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(TuneShop.X_BTN, TuneShop.X_BTN)
	var box := kit_box(art_rel, Vector2.ZERO)
	if box != null:
		b.add_theme_stylebox_override("normal", box)
		b.add_theme_stylebox_override("hover", box)
		var bp: StyleBoxTexture = box.duplicate()
		bp.modulate_color = TuneShop.CARD_PRESS_MODULATE
		b.add_theme_stylebox_override("pressed", bp)
	else:
		var xs := StyleBoxFlat.new()
		xs.bg_color = TuneShop.X_BG
		xs.set_corner_radius_all(TuneShop.X_RADIUS)
		xs.set_border_width_all(TuneShop.X_BORDER_W)
		xs.border_color = TuneShop.X_EDGE
		b.add_theme_stylebox_override("normal", xs)
		b.add_theme_stylebox_override("hover", xs)
		var xp: StyleBoxFlat = xs.duplicate()
		xp.bg_color = TuneShop.X_BG_PRESSED
		b.add_theme_stylebox_override("pressed", xp)
		b.text = "✕"
		b.add_theme_font_size_override("font_size", TuneShop.X_FONT)
		b.add_theme_color_override("font_color", Pal.CREAM)
	add_press_juice(b)
	b.pressed.connect(func() -> void: cb.call())
	return b

## The shared popup BANNER title: the gold ribbon (ui/shop/shop_banner.png) with the title as ENGINE
## text riding it centered (images never carry words — §0.3); a solid title chip when the art is
## absent. Returns a Control sized to a header band, FILL-width so the ribbon centers across the card.
## `art_rel` overrides the ribbon sprite so a themed modal (the mailbox → mail/mail_banner.png) passes its own.
static func banner_title(text: String, font_px: int = Tune.TITLE_SIZE, band_h: float = 120.0, art_rel: String = "shop/shop_banner.png") -> Control:
	var p := kit(art_rel)
	if not ResourceLoader.exists(p):
		var ribbon := title_ribbon(text, font_px)
		ribbon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		return ribbon
	var header := Control.new()
	header.custom_minimum_size = Vector2(0, band_h)
	header.size_flags_horizontal = Control.SIZE_FILL
	header.clip_contents = true
	var art := TextureRect.new()
	art.texture = load(p)
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(art)
	var lbl := Label.new()
	lbl.text = text
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", font_px)
	lbl.add_theme_color_override("font_color", Pal.INK)
	lbl.add_theme_constant_override("outline_size", 0)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(lbl)
	return header

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
	var p := kit("shared/btn_round.png")
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
## `opts` tunes the SIZE (workbench-driven): opts.dot_px overrides the dot diameter; opts.num_size overrides
## the count font (the pill height tracks it at the shipped ratio so the pill still wraps the number). Absent
## opts → the shipped Tune defaults. Always MOUSE_FILTER_IGNORE. Position it via attach_badge (top-right
## overhang) or by hand. Returns a Control (the badge root).
static func badge(kind: String = "dot", count: int = 0, opts: Dictionary = {}) -> Control:
	if kind == "pill":
		var num := int(opts.get("num_size", Tune.BADGE_NUM_SIZE))   # count font (workbench-tunable)
		var pill_h := int(round(float(num) * float(Tune.BADGE_PILL_H) / float(Tune.BADGE_NUM_SIZE)))  # pill wraps the number (shipped 14→22 ratio)
		var pill := PanelContainer.new()
		pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var s := StyleBoxFlat.new()
		s.bg_color = Tune.BADGE_COLOR
		s.set_corner_radius_all(int(pill_h / 2.0))
		s.set_border_width_all(Tune.BADGE_RIM_W)
		s.border_color = Tune.BADGE_RIM
		s.content_margin_left = Tune.BADGE_PILL_PAD_X
		s.content_margin_right = Tune.BADGE_PILL_PAD_X
		s.content_margin_top = 1.0
		s.content_margin_bottom = 1.0
		pill.add_theme_stylebox_override("panel", s)
		pill.custom_minimum_size = Vector2(pill_h, pill_h)  # min = a circle
		var l := Label.new()
		l.text = ("99+" if count > 99 else str(maxi(count, 1)))
		l.add_theme_font_size_override("font_size", num)
		l.add_theme_color_override("font_color", Color.WHITE)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pill.add_child(l)
		return pill
	# "dot" — a bare rimmed disc
	var dot_px := int(opts.get("dot_px", Tune.BADGE_DOT_PX))   # dot diameter (workbench-tunable)
	var dot := Panel.new()
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ds := StyleBoxFlat.new()
	ds.bg_color = Tune.BADGE_COLOR
	ds.set_corner_radius_all(int(dot_px / 2.0))
	ds.set_border_width_all(Tune.BADGE_RIM_W)
	ds.border_color = Tune.BADGE_RIM
	dot.add_theme_stylebox_override("panel", ds)
	dot.custom_minimum_size = Vector2(dot_px, dot_px)
	dot.size = Vector2(dot_px, dot_px)
	return dot

## Pin a badge to the top-right CORNER of `host`, overhanging the edge (the badge pokes
## slightly past the corner — the universal "new" placement). The badge is a child of
## host and anchored to its top-right; MOUSE_FILTER_IGNORE keeps the single-input-surface
## rule intact. Returns the badge so the caller can toggle `.visible`.
static func attach_badge(host: Control, b: Control, over: Vector2 = Tune.BADGE_OVERHANG) -> Control:
	host.add_child(b)
	b.set_anchors_preset(Control.PRESET_TOP_RIGHT)   # all offsets now relative to host top-right
	var sz := b.custom_minimum_size
	if sz == Vector2.ZERO:
		sz = b.size
	# OVERHANG = how far the badge's right/top poke PAST host's corner (positive = outside, negative tucks
	# it IN over the disc). Callers (e.g. the home-button side rail) pass a workbench-tuned offset so the
	# badge can sit snug to the disc instead of floating off its transparent art margin.
	b.offset_right = over.x                           # right edge: +over.x past host right
	b.offset_left = b.offset_right - sz.x
	b.offset_top = -over.y                            # top edge: over.y above host top
	b.offset_bottom = b.offset_top + sz.y
	return b

## A DROP SHADOW Panel to place BEHIND an element (full-rect of the SAME holder). It paints a soft shadow
## that HUGS the element: the shadow's rounded-rect footprint is FILLED with the warm shadow tint (so there
## is NO hollow gap between the element edge and the cast shadow) and a soft feather fades outward past it.
## The shadow reaches an INDEPENDENT distance on each side: `top` / `bottom` / `left` / `right` (px) each grow
## the FILLED rect outward by that much (expand_margin); `softness` is the shared feather (blur) past the fill.
## The OPAQUE element art sits on top, hiding the fill beneath itself, so the shadow shows ONLY where it pokes
## past the element — independently per side. A side set to 0 collapses to just the soft feather; raise it to
## cast further that way. `corner` is the element's radius (big = capsule, clamps). NOTE: the footprint fill is
## solid, so a TRANSLUCENT element (the workbench fill_alpha < 100 preview) lets it read through — shipped
## badges are opaque, so in-game the fill is always hidden.
static func drop_shadow(corner: float, top: float, bottom: float, left: float, right: float, softness: float, alpha: float, warmth: float = 0.82) -> Panel:
	var sh := Panel.new()
	sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sh.set_anchors_preset(Control.PRESET_FULL_RECT)
	var tint := warm_shadow_color(alpha, warmth)
	var ssb := StyleBoxFlat.new()
	ssb.draw_center = true                                   # FILL the footprint with the shadow tint — no hollow gap
	ssb.bg_color = tint                                      # the grown rect (under the badge + the per-side reach band)
	ssb.shadow_color = tint                                  # the soft feather past the filled rect, same tint
	ssb.shadow_size = int(maxf(softness, 0.0))              # the shared soft feather (blur radius)
	ssb.shadow_offset = Vector2.ZERO                         # direction comes from per-side reach, not an offset
	ssb.set_corner_radius_all(int(corner))
	ssb.expand_margin_left = maxf(left, 0.0)                # per-side REACH: grow the filled rect outward
	ssb.expand_margin_top = maxf(top, 0.0)
	ssb.expand_margin_right = maxf(right, 0.0)
	ssb.expand_margin_bottom = maxf(bottom, 0.0)
	sh.add_theme_stylebox_override("panel", ssb)
	return sh

## Float a small token (the wallet "+") OVER a sized `pill` WITHOUT changing the pill's size. The pill stays
## the layout-sized node (its icon + number drive the capsule); the token is anchored to the pill's RIGHT
## edge, nudged by opts.plus_x (horizontal — +overhang past the edge / −tuck in over the pill) and
## opts.plus_dy (vertical — +down / −up), and scaled by opts.plus_size. Returns a holder Control — add THIS
## to the layout in place of the pill; its minimum size tracks the pill, so a bigger "+" never grows the
## capsule. The token keeps its own input surface (a real Button stays tappable, and attach_badge can ride it).
static func float_plus(pill: Control, token: Control, opts: Dictionary) -> Control:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_PASS           # transparent shell; the pill / token own their input
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# the DROP SHADOW behind the capsule (the painted pill is a StyleBoxTexture with no native shadow): a SOFT
	# cast that reaches an independent distance on each side (shadow_top/bottom/left/right), feathered by
	# shadow_size. The capsule corner is its half-height, so the big corner clamps to a shadow that hugs the pill.
	var sh_alpha := clampf(float(opts.get("shadow_alpha", 22)) / 100.0, 0.0, 1.0)
	var sh_top := float(opts.get("shadow_top", 0))
	var sh_bottom := float(opts.get("shadow_bottom", 0))
	var sh_left := float(opts.get("shadow_left", 0))
	var sh_right := float(opts.get("shadow_right", 0))
	var sh_soft := float(opts.get("shadow_size", 0))
	if sh_alpha > 0.0 and (sh_top > 0.0 or sh_bottom > 0.0 or sh_left > 0.0 or sh_right > 0.0 or sh_soft > 0.0):
		holder.add_child(drop_shadow(1000.0, sh_top, sh_bottom, sh_left, sh_right, sh_soft, sh_alpha, float(opts.get("shadow_warmth", 82)) / 100.0))
	holder.add_child(pill)
	pill.set_anchors_preset(Control.PRESET_FULL_RECT)         # the pill fills the holder; the holder is sized to the pill
	# keep the holder's MINIMUM size equal to the pill's, so the parent layout reserves the pill size only
	var sync := func() -> void:
		holder.custom_minimum_size = pill.get_combined_minimum_size()
	sync.call()
	pill.minimum_size_changed.connect(sync)
	# the "+" overlays the pill's right-centre, decoupled from the pill size
	var box := float(opts.get("plus_size", 26))
	token.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	token.offset_right = float(opts.get("plus_x", 0))         # +past the right edge / −in over the pill
	token.offset_left = token.offset_right - box
	var dy := float(opts.get("plus_dy", 0))
	token.offset_top = -box / 2.0 + dy
	token.offset_bottom = token.offset_top + box
	holder.add_child(token)
	return holder

## --- toggle switch ---------------------------------------------------------------------
## A SWITCH (the settings music / sounds / calm rows): a press surface wearing the sliced
## switch art (kit/switch_on.png · switch_off.png — the green/tan pill with the knob baked
## in), or a code-drawn track + sliding knob when the art is absent (the kit invariant —
## same metrics either way). Tapping flips the state, repaints the look, and fires
## `on_changed(new_state)`. `px_h` sizes it; width follows the sliced pill's aspect. Stateless
## otherwise — the caller owns persistence and reads back the live value via the callback.
static func toggle_switch(is_on: bool, on_changed: Callable, px_h: float = Tune.SWITCH_H) -> Button:
	var w := px_h * Tune.SWITCH_ASPECT
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(w, px_h)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# the art / capsule IS the surface — the button itself draws no chrome
	var empty := StyleBoxEmpty.new()
	b.add_theme_stylebox_override("normal", empty)
	b.add_theme_stylebox_override("hover", empty)
	b.add_theme_stylebox_override("pressed", empty)
	b.set_meta("on", is_on)
	if ResourceLoader.exists(kit("kit/switch_on.png")) and ResourceLoader.exists(kit("kit/switch_off.png")):
		var art := TextureRect.new()
		art.name = "sw_art"
		art.set_anchors_preset(Control.PRESET_FULL_RECT)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(art)
	else:
		var track := Panel.new()                       # the rounded capsule (recoloured per state)
		track.name = "sw_track"
		track.set_anchors_preset(Control.PRESET_FULL_RECT)
		track.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(track)
		var knob := Panel.new()                        # the cream knob (slid left/right per state)
		knob.name = "sw_knob"
		var ks := StyleBoxFlat.new()
		ks.bg_color = Pal.CREAM
		ks.set_corner_radius_all(int(px_h))
		ks.set_border_width_all(2)
		ks.border_color = Color(Pal.BARK, 0.5)
		knob.add_theme_stylebox_override("panel", ks)
		knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(knob)
	_switch_paint(b, is_on, px_h)
	add_press_juice(b)
	b.pressed.connect(func() -> void:
		var now := not bool(b.get_meta("on"))
		b.set_meta("on", now)
		_switch_paint(b, now, px_h)
		on_changed.call(now))
	return b

## Repaint a toggle_switch for `is_on`: swap the sliced sprite, or (fallback) recolour the
## track + slide the knob to the on/off end.
static func _switch_paint(b: Button, is_on: bool, px_h: float) -> void:
	var art := b.get_node_or_null("sw_art") as TextureRect
	if art != null:
		art.texture = load(kit("kit/switch_%s.png" % ("on" if is_on else "off")))
		return
	var track := b.get_node_or_null("sw_track") as Panel
	var knob := b.get_node_or_null("sw_knob") as Panel
	if track == null or knob == null:
		return
	var ts := StyleBoxFlat.new()
	ts.bg_color = Pal.BTN_PRIMARY if is_on else Color(Pal.BARK, Tune.SWITCH_OFF_ALPHA)
	ts.set_corner_radius_all(int(px_h))
	track.add_theme_stylebox_override("panel", ts)
	var inset := Tune.SWITCH_KNOB_INSET
	var d := px_h - inset * 2.0
	knob.size = Vector2(d, d)
	var w := px_h * Tune.SWITCH_ASPECT
	knob.position = Vector2((w - d - inset) if is_on else inset, inset)
