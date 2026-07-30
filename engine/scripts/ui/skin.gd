extends RefCounted
## Shared UI skin helpers (background + buttons), so menu/board/room
## look consistent. Preload: const Skin = preload("res://engine/scripts/ui/skin.gd").
## Metrics live in Tune (engine/scripts/core/tuning.gd → class Skin); colours in Pal.

const Features = preload("res://engine/scripts/core/features.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const Pal = Game.PALETTE
const Tune = preload("res://engine/scripts/core/tuning.gd").UiSkin   # the engine's skin metrics
const TuneShop = preload("res://engine/scripts/core/tuning.gd").Shop # popup-chrome dials (card/✕/banner), shared by every modal

const SHADOW_TINT := Color(0, 0, 0)     # THE shadow colour — NEUTRAL black: it dims whatever ground it falls on
                                        # (cream -> warm tan, board blue -> deep blue), which is how the mocks
                                        # paint shadows — per-surface, hue-preserving. A fixed hue (the old slate)
                                        # read green-grey on cream dialogs.

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

static func shadow_color(alpha: float) -> Color:
	return Color(SHADOW_TINT, clampf(alpha, 0.0, 1.0))

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
	"plus": "+", "calendar": "📅", "chest": "🎁", "bag": "▣", "board": "▦",
}
const ICON_TINTS := {"star": Pal.STRAW, "check": Color.WHITE}

## --- the level badge's tier ----------------------------------------------------------
## The layered level badge gets fancier as the player levels up. Which TIER a Level shows is
## DATA: res://data/level_badges.json maps Level -> tier index by a BANDED rule (fast early,
## slow late); Kit.level_badge composites that tier's parts. level_badge_index() returns the
## 0-based tier (or -1 when unconfigured). Parsed once.
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
	var count := int(cfg.get("tier_count", cfg.get("badge_count", 0)))
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

## A level-status badge: the LAYERED emblem (cut parts composited per the Level's tier) with the
## level NUMBER centered. Built by Kit.level_badge from the workbench-tuned config, so the HUD chip,
## level popup, and level-up dialog all wear the same tuned look — just a different number.
## `px` is the square size; `num_font` overrides the number font (auto-scaled from num_size when < 0).
## The number Label is named "lv_num" and each part TextureRect "lv_<part>" so a live caller (the HUD
## level-up) can rebuild/refresh them. Falls back to a warm honey token when the part art is absent.
static func make_level_badge(level: int, px: float, num_font: int = -1, cfg_override: Dictionary = {}) -> Control:
	var Kit = Game.kit_script()
	var cfg: Dictionary = cfg_override if not cfg_override.is_empty() else Kit.load_config(Kit.CONFIG_PATH)
	var opts: Dictionary = Kit.level_badge_opts_from_config(cfg)
	var badge: Control = Kit.level_badge(opts, level_badge_index(level), level, px, num_font)
	badge.name = "LevelBadge"
	# THE uniform shadow, SHAPE-TRUE: the badge is an irregular star cutout, so a box/circle shadow
	# would poke past its outline. Bake the art's own alpha silhouette (slate, offset, feathered) at
	# display resolution and lay it behind — same numbers as every other element, following the star.
	var sp := shadow_params(cfg)
	var art := badge.get_node_or_null("lv_badge_art") as TextureRect
	if art != null and art.texture != null:
		_lay_silhouette_shadow(badge, art, sp)
	else:
		# no art (honey-token fallback) — the token IS a circle, so the circular shared shadow fits
		var sh := shadow_circle(px * 0.92, sp)
		sh.show_behind_parent = true
		badge.add_child(sh)
		badge.move_child(sh, 0)
	return badge

## Bake the shared SHAPE-TRUE shadow — the sprite's own alpha silhouette, slate/offset/feathered per the
## saved shadow block `sp` — and lay it directly behind `art` inside `badge` (as child 0, "lv_badge_shadow").
## Shared by every layered level badge (the meadow tiers + the HUD star), so an irregular cutout casts
## along its real outline instead of a box.
static func _lay_silhouette_shadow(badge: Control, art: TextureRect, sp: Dictionary) -> void:
	var Kit = Game.kit_script()
	var art_img: Image = art.texture.get_image() if art != null and art.texture != null else null
	if art_img == null:
		return
	art_img = art_img.duplicate()
	if art_img.is_compressed():
		art_img.decompress()
	art_img.convert(Image.FORMAT_RGBA8)
	art_img.resize(maxi(1, int(art.size.x)), maxi(1, int(art.size.y)), Image.INTERPOLATE_BILINEAR)
	var res: Dictionary = Kit.silhouette_shadow(art_img, {
		"shadow_offset": Vector2(float(sp.offset_x), float(sp.offset_y)),
		"shadow_blur": float(sp.blur), "shadow_alpha": float(sp.alpha),
		"shadow_spread": float(sp.spread)})
	var pad := float(res.pad)
	var shr := TextureRect.new()
	shr.name = "lv_badge_shadow"
	shr.texture = ImageTexture.create_from_image(res.image)
	shr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shr.stretch_mode = TextureRect.STRETCH_SCALE
	shr.position = art.position - Vector2(pad, pad)
	shr.size = art.size + Vector2(pad * 2.0, pad * 2.0)
	shr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(shr)
	badge.move_child(shr, 0)

## The HUD's top-left LEVEL badge: the cut-paper gold STAR base (ui/kit/level_star_badge.png) with the
## level number in WHITE over it. A single reusable base (no tiers — the number is rendered live, never
## baked). Same node contract as make_level_badge (root "LevelBadge", art "lv_badge_art", number "lv_num",
## the shared silhouette shadow at child 0) so the HUD's refresh + painted-offset alignment work unchanged.
const STAR_BADGE_ART := "kit/level_star_badge.png"
const STAR_BADGE_PAINTED_SPAN := 0.90     # the painted star's span as a fraction of its square canvas
static func make_star_level_badge(level: int, px: float, num_font: int = -1, cfg_override: Dictionary = {}) -> Control:
	var Kit = Game.kit_script()
	var cfg: Dictionary = cfg_override if not cfg_override.is_empty() else Kit.load_config(Kit.CONFIG_PATH)
	var badge := Control.new()
	badge.name = "LevelBadge"
	badge.custom_minimum_size = Vector2(px, px)
	badge.size = Vector2(px, px)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var tex: Texture2D = Kit.clean_tex_path(kit(STAR_BADGE_ART), 256)
	if tex != null:
		var art := TextureRect.new()
		art.name = "lv_badge_art"
		art.texture = tex
		# expand_mode BEFORE size (min-size cache): scale the art up so the painted star (which sits in a
		# transparent gutter) fills the px slot, honoring the HUD's shared visible-edge margin.
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var art_px := px / STAR_BADGE_PAINTED_SPAN
		art.size = Vector2(art_px, art_px)
		art.position = Vector2(-(art_px - px) * 0.5, -(art_px - px) * 0.5)
		art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_child(art)

	# the level number, centered — the SAME ink the currency pills use for their amount (Pal.INK,
	# no outline) so the top-left badge and the wallet numbers read as one system.
	var num := Label.new()
	num.name = "lv_num"
	num.text = str(level)
	num.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	num.add_theme_font_override("font", Kit.bold_font())
	num.add_theme_font_size_override("font_size", num_font if num_font > 0 else int(px * 0.42))
	num.add_theme_color_override("font_color", Pal.INK)
	num.add_theme_constant_override("outline_size", 0)
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(num)

	var art2 := badge.get_node_or_null("lv_badge_art") as TextureRect
	if art2 != null and art2.texture != null:
		_lay_silhouette_shadow(badge, art2, shadow_params(cfg))
	return badge

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
			apply_box_shadow(sb)
			sb.content_margin_left = Tune.PLANK_PAD_X
			sb.content_margin_right = Tune.PLANK_PAD_X
			sb.content_margin_top = Tune.PLANK_PAD_Y
			sb.content_margin_bottom = Tune.PLANK_PAD_Y
		_:                                       # parchment — a raised card surface
			sb.bg_color = Pal.CREAM
			sb.set_corner_radius_all(Tune.RADIUS_CARD)
			sb.set_border_width_all(Tune.PARCH_BORDER_W)
			sb.border_color = Pal.BARK
			apply_box_shadow(sb)
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
	apply_box_shadow(sb)
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
	# ONE shadow (the saved workbench block) — no raised/resting tiers.
	apply_box_shadow(s)
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
	sp.shadow_color = shadow_color(float(saved_shadow_params().alpha))
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

## --- THE SHARED SHADOW — one box-shadow model for every UI element ------------------------------
## A single drop-shadow Panel to place BEHIND an element (full-rect of the SAME holder). ONE model
## drives every component (the workbench Shadow item is its only tuning surface): `offset_x` / `offset_y`
## cast the shadow (px), `blur` softens it (px feather), `spread` grows it on all sides (px), `alpha`
## (0..1) is opacity; the tint is always SHADOW_TINT. Because the look is OFFSET-based (not
## per-side reach tied to one element size) it carries naturally across element sizes. The footprint is
## FILLED (draw_center) so there is no hollow gap, and the corner is grown WITH the spread so a circle
## stays a circle / a rounded rect stays concentric. The opaque element sits on top, hiding the fill, so
## only the cast that pokes past the element shows. NOTE: the fill is solid, so a TRANSLUCENT element
## (the workbench fill_alpha < 100 preview) lets it read through — shipped elements are opaque.
static func shadow(corner: float, offset_x: float, offset_y: float, blur: float, spread: float, alpha: float) -> Panel:
	var sh := Panel.new()
	sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sh.set_anchors_preset(Control.PRESET_FULL_RECT)
	var tint := shadow_color(alpha)
	var ssb := StyleBoxFlat.new()
	ssb.draw_center = true                                   # FILL the footprint — no hollow gap
	ssb.bg_color = tint
	ssb.shadow_color = tint                                  # the soft feather past the filled rect, same tint
	ssb.shadow_size = int(maxf(blur, 0.0))                  # blur = the soft feather radius
	ssb.shadow_offset = Vector2(offset_x, offset_y)         # the cast direction + distance
	# the shadow is EXACTLY the element's shape (corner grown with the spread stays concentric) —
	# no per-shape adjustments, ever. The visible cast is the true silhouette projection.
	ssb.set_corner_radius_all(int(maxf(corner + spread, 0.0)))
	ssb.set_expand_margin_all(spread)                       # spread grows (or, negative, shrinks) the filled rect on every side
	sh.add_theme_stylebox_override("panel", ssb)
	return sh

## The shared shadow params from a saved config's single "shadow" block (box-shadow model). Defaults
## are THE uniform shadow (measured from the picturebook mocks — bottom-right cast, slate tint), so an
## absent block still casts the standard shadow. alpha is stored 0..100 in config and returned as 0..1.
## The shadow_rect / shadow_circle builders consume this.
const SHADOW_DEFAULTS := {"offset_x": 0.0, "offset_y": 5.0, "blur": 6.0, "spread": -2.0, "alpha": 20.0}

static func shadow_params(cfg: Dictionary) -> Dictionary:
	var s: Dictionary = cfg.get("shadow", {}) if cfg is Dictionary else {}
	var off_x := float(s.get("offset_x", SHADOW_DEFAULTS.offset_x))
	var off_y := float(s.get("offset_y", SHADOW_DEFAULTS.offset_y))
	# spread only ever TIGHTENS (<= 0): the shadow body is a FILLED panel behind the element,
	# so a positive spread pokes past the element as a uniform dark collar on all four sides —
	# a border, not a cast. The mocks never grow a shadow outward; clamp the footgun away.
	# It must ALSO out-tighten the offset: the filled body is shifted by (offset_x, offset_y), so
	# any |offset| greater than |spread| slides that HARD-EDGED fill out from under the element —
	# the "black slab" bug. Only the blurred feather may ever escape the silhouette.
	var spread := minf(float(s.get("spread", SHADOW_DEFAULTS.spread)), 0.0)
	spread = minf(spread, -maxf(absf(off_x), absf(off_y)))
	return {
		"offset_x": off_x,
		"offset_y": off_y,
		"blur":     float(s.get("blur", SHADOW_DEFAULTS.blur)),
		"spread":   spread,
		"alpha":    clampf(float(s.get("alpha", SHADOW_DEFAULTS.alpha)) / 100.0, 0.0, 1.0),
	}

## THE SAVED shadow block — the workbench Shadow item's sliders, persisted to the kit config.
## EVERY shadow path resolves through this, so tuning + saving in the workbench restyles the
## whole game on next build; SHADOW_DEFAULTS is only the absent-config/kit fallback.
static func saved_shadow_params() -> Dictionary:
	return shadow_params(Game.kit_config())

static func shadow_bottom_reach() -> float:
	var p := saved_shadow_params()
	return float(p.offset_y) + float(p.blur) + float(p.spread)

## Stamp THE uniform shadow onto a StyleBoxFlat — for elements whose chrome is a native StyleBox
## (buttons, framed panels) rather than a behind-panel. Reads the SAVED workbench block, so the
## Shadow item drives these too. StyleBoxFlat has no spread knob, so spread is FOLDED into the
## feather size (size = blur + spread): both paths then share the same reach — offset+blur+spread —
## and a spread that cancels the blur kills the shadow on this path too, matching the behind-panel.
static func apply_box_shadow(sb: StyleBoxFlat) -> void:
	var p := saved_shadow_params()
	sb.shadow_color = shadow_color(float(p.alpha))
	sb.shadow_size = maxi(0, int(roundf(float(p.blur) + float(p.spread))))
	sb.shadow_offset = Vector2(float(p.offset_x), float(p.offset_y))

## A RECTANGULAR shared shadow behind an element of corner radius `corner`. `p` is shadow_params().
static func shadow_rect(corner: float, p: Dictionary) -> Panel:
	return shadow(corner, float(p.get("offset_x", SHADOW_DEFAULTS.offset_x)), float(p.get("offset_y", SHADOW_DEFAULTS.offset_y)), float(p.get("blur", SHADOW_DEFAULTS.blur)), float(p.get("spread", SHADOW_DEFAULTS.spread)), float(p.get("alpha", SHADOW_DEFAULTS.alpha / 100.0)))

## A CIRCULAR shared shadow behind a round element of diameter `diameter` (corner = radius). `p` is shadow_params().
static func shadow_circle(diameter: float, p: Dictionary) -> Panel:
	return shadow(diameter / 2.0, float(p.get("offset_x", SHADOW_DEFAULTS.offset_x)), float(p.get("offset_y", SHADOW_DEFAULTS.offset_y)), float(p.get("blur", SHADOW_DEFAULTS.blur)), float(p.get("spread", SHADOW_DEFAULTS.spread)), float(p.get("alpha", SHADOW_DEFAULTS.alpha / 100.0)))

## An element's chrome builder stamps the radius it actually applied under this meta key; every
## shadow wrapper prefers it over a hand-passed corner, so the shadow's shape can never drift
## from the element's real rounding (the pill bug: shell 0.35h, hand-passed shadow corner 0.5h).
const SHADOW_CORNER_META := "shadow_corner"

static func shape_corner(node: Control, fallback: float) -> float:
	return float(node.get_meta(SHADOW_CORNER_META, fallback)) if node != null else fallback

## Wrap `node` in a holder that draws the shared shadow BEHIND it — for CONTAINER nodes (PanelContainer
## etc.) that manage their own children, where a behind-parent child would fight the layout. `size` is the
## element corner (rect) or diameter (circle). The holder hugs the node's size, so the parent layout still
## reserves the node's size only. (Non-container Controls — Buttons, Panels — instead add the shadow Panel
## as a `show_behind_parent` child directly, keeping their node identity.)
static func with_shadow(node: Control, size: float, p: Dictionary, circular := false) -> Control:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_PASS           # transparent shell; the node owns its input
	holder.size_flags_horizontal = node.size_flags_horizontal
	holder.size_flags_vertical = node.size_flags_vertical
	var c := shape_corner(node, size)                         # the element's OWN rounding wins over the hand-passed size
	holder.add_child(shadow_circle(c, p) if circular else shadow_rect(c, p))   # behind (added first)
	holder.add_child(node)
	node.set_anchors_preset(Control.PRESET_FULL_RECT)         # the node fills the holder; the holder is sized to the node
	var sync := func() -> void:
		holder.custom_minimum_size = node.get_combined_minimum_size()
	sync.call()
	node.minimum_size_changed.connect(sync)
	return holder

static var SWITCH_SKIN := kit("dialogs/settings/")   # cut-paper reskin: toggle_on/off.png
# The code-drawn cut-paper panel, loaded at runtime (a preload const would be a cycle — cut_paper.gd
# preloads this skin). Used for the cut-paper switch track + knob.
const CUT_PAPER := "res://engine/scripts/ui/cut_paper.gd"

static func toggle_switch(is_on: bool, on_changed: Callable, px_h: float = Tune.SWITCH_H, cp: Dictionary = {}) -> Button:
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
	# CUT-PAPER switch: the SAME shared edge knob set (Kit.cut_paper_opts_from_config, passed as `cp`) the
	# dialog frame + settings rows wear, applied via CutPaperPanel.configure — a cut capsule TRACK (leaf
	# green ON / soft slate OFF) + a cut cream KNOB that slides. `cp` empty → a sensible fallback, which
	# has to spell out BOTH halves of the smooth edge: no tear, and the feather band that antialiases the
	# capsule's arc in its place. The width is the panel's own measured constant, never re-typed.
	var CutPaper := load(CUT_PAPER)
	var o: Dictionary = cp if not cp.is_empty() else {
		"deckle_amp": 0.0, "deckle_freq": 0.05, "rim_width": 1.5,
		"edge_feather": CutPaper.SMOOTH_FEATHER_PX}
	var track = CutPaper.new()                     # the cut-paper capsule (recoloured per state)
	track.name = "sw_track"
	track.set_anchors_preset(Control.PRESET_FULL_RECT)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.configure(o, Pal.BTN_PRIMARY)            # shared edge; colour is (re)set per state in _switch_paint
	track.corner = px_h * 0.5                       # override: a capsule, not the block's rect corner
	track.draw_shadow = false                       # override: the track sits flat; the knob carries the lift
	b.add_child(track)
	var knob = CutPaper.new()                       # the cut cream knob (slid left/right per state)
	knob.name = "sw_knob"
	knob.seed = 4                                   # its own noise phase, if a tear is ever dialled back in
	knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	knob.configure(o, Pal.CREAM, Color("#E7D6BC"), null, 0.6)   # amp_scale would shrink a tear at knob scale
	knob.draw_shadow = false                        # CutPaperPanel's fixed px shadow is oversized at knob scale
	b.add_child(knob)
	_switch_paint(b, is_on, px_h)
	add_press_juice(b)
	b.pressed.connect(func() -> void:
		var now := not bool(b.get_meta("on"))
		b.set_meta("on", now)
		_switch_paint(b, now, px_h)
		on_changed.call(now))
	return b

## Repaint a cut-paper toggle_switch for `is_on`: recolour the track (leaf green ON / soft slate OFF)
## and slide the knob to the on/off end.
static func _switch_paint(b: Button, is_on: bool, px_h: float) -> void:
	var track := b.get_node_or_null("sw_track") as Control
	var knob := b.get_node_or_null("sw_knob") as Control
	if track == null or knob == null:
		return
	# ON = leaf green; OFF = a soft neutral slate (a desaturated ink), NOT the old muddy bark brown.
	track.paper_color = Pal.BTN_PRIMARY if is_on else Color("#B9C0C4")
	track.rim_color = (Pal.BTN_PRIMARY.darkened(0.18) if is_on else Color("#A7AFB4"))
	track.queue_redraw()
	var inset := Tune.SWITCH_KNOB_INSET
	var d := px_h - inset * 2.0
	knob.corner = d * 0.5           # a fully-rounded disc knob
	knob.custom_minimum_size = Vector2(d, d)
	knob.size = Vector2(d, d)
	var w := px_h * Tune.SWITCH_ASPECT
	knob.position = Vector2((w - d - inset) if is_on else inset, inset)
	knob.queue_redraw()
