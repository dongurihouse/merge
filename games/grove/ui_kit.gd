extends RefCounted
## UI Workbench — the self-contained component kit.
##
## The workbench's OWN definitions of the fundamental components, composed bottom-up:
##   pill_button                (the ONE button atom — green Claim, cream reward pill, all variants)
##     → mail_card              (molecule — a reward pill + a Claim, both the shared pill_button)
##       → mail_dialog          (organism — composes a list of mail_cards)
## Each higher component CALLS the lower ones, so a change to the atom flows up automatically. There is
## no separate cost-pill component — a reward pill is just pill_button in its cream/static variant.
##
## Self-contained on purpose: this depends only on the shared design-system foundation
## (skin.gd primitives, the kit art, the palette) — NOT on game state. The GAME pulls from here
## (engine/scripts/ui/inbox.gd builds its mailbox from these + the saved workbench config).

const Look = preload("res://engine/scripts/ui/skin.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const Iap = preload("res://engine/scripts/core/iap.gd")   # cash-pack prices by key (data/iap_products.json)
const Pal = Game.PALETTE
const Tune = preload("res://engine/scripts/core/tuning.gd").UiSkin   # button radius/border/shadow metrics
const ScaleContainer = preload("res://engine/scripts/ui/scale_container.gd")   # uniform content scaling inside the frame
const FX = preload("res://engine/scripts/ui/fx.gd")   # shared wallet number formatting (K/M) + fit-to-cell
const FS = preload("res://engine/scripts/core/tuning.gd").FontScale
# THE paper-furniture language (chalk transform + the scene's directional cut-paper edge), owned by the
# nav row that was fitted against the concept mock. The wallet pill borrows it rather than re-deriving
# a parallel set of edge knobs — see the "PAPER FURNITURE LANGUAGE" block at the foot of paper_button.gd.
# The MATERIAL is Paper's (it is what every cut-paper button in the game is made of); the CHALK transform
# is still the nav row's own call site, so the pill borrows that from there.
const Paper = preload("res://engine/scripts/ui/paper_button.gd")
const NavBar = preload("res://engine/scripts/ui/nav_bar.gd")

# Nine-patch margins for the shared mail kit (sourced from the real recipe in inbox.gd).
const CARD_TEX := Vector2(30, 30)
const CARD_PAD := Vector4(18, 12, 18, 12)
const PILL_TEX := Vector2(46, 34)
const PILL_PAD := Vector4(14, 6, 14, 6)
const CLAIM_PAD := Vector4(24, 8, 24, 8)
const BANNER_H := 92.0
const CONTENT_TAIL_PAD := 16.0    # bottom breathing room inside the clipping scroll so the last card's drop shadow isn't sliced
const BANNER_MIN_W_FRAC := 0.25   # a dialog floors its banner at this fraction of the SCREEN width (banner_min_w)
const DIALOG_MIN_H_FRAC := 0.20   # general dialog HEIGHT floor as a fraction of the SCREEN height (mirrors the width %) — sparse states (empty mail …) never collapse to a banner slip; content dialogs (settings) clear it with only light bottom breathing room, and tall ones (daily/shop) are unaffected. An explicit opts.min_h (px) overrides.

# Meadow Sky component atoms. These extracted assets are already alpha-clean and shadow-free, so shared
# components load them directly and use explicit safe nine-slice margins rather than live image polish.
const MEADOW_UI := "ui/meadow_v2/%s"
const PAPER_EDGE := Color(Pal.BARK, 0.35)
const PAPER_SURFACES := {
	"cream": {"texture": "texture_cream.png", "fill": Pal.CREAM},
	"sky": {"texture": "texture_sky.png", "fill": Pal.SKY},
	"green": {"texture": "texture_action_green.png", "fill": Pal.LEAF},
	"purple": {"texture": "texture_supporting_purple.png", "fill": Color("#8677A3")},
	# the remaining shipped paper roles, registered so the bottom bar can give every tile its own
	# texture (the mock's multi-coloured nav strip). Fills mirror the Meadow Sky palette roles.
	"coral": {"texture": "texture_coral.png", "fill": Pal.CLAY},
	"gold": {"texture": "texture_reward_gold.png", "fill": Pal.GOLD},
	"kraft": {"texture": "texture_warm_kraft.png", "fill": Color("#C9A886")},
	"slate": {"texture": "texture_structural_slate.png", "fill": Pal.BRAMBLE_BG},
	# WHITE paper: a truly white fibre for the deckle path (its own `tile`, desaturated + lifted from the
	# cream fibre) so a white fill reads white, not cream. The deckle-off shader path falls back to the cream
	# grain (multiplied by the white fill) — deckle is on by default, so the white tile is what shows.
	"white": {"texture": "texture_cream.png", "fill": Color("#FBFBFB"), "tile": CUT_PAPER_TILE_WHITE},
}
# The core NAV/action set — one shared code-drawn rugged-edge button per role. The glyph is the only
# differentiator between tiles (the edge + paper role are shared config). Roles map to the transparent,
# edge-free glyph sprites generated as one family (no baked deckle — the button draws that in code).
const ACTION_ROLES := ["map", "residents", "daily", "vault", "mail", "play", "home", "bag", "almanac"]
const ACTION_GLYPHS := {
	"map": "ui/nav/glyphs/glyph_map.png",
	"residents": "ui/nav/glyphs/glyph_residents.png",
	"daily": "ui/nav/glyphs/glyph_daily.png",
	"vault": "ui/nav/glyphs/glyph_vault.png",
	"mail": "ui/nav/glyphs/glyph_mail.png",
	"play": "ui/nav/glyphs/glyph_play.png",
	"home": "ui/nav/glyphs/glyph_home.png",
	"bag": "ui/nav/glyphs/glyph_bag.png",
	"almanac": "ui/nav/glyphs/glyph_almanac.png",
}
# The glyph's soft RUNTIME drop shadow (the art PNG ships shadow-free per the style guide §0): darkened
# silhouette copies of the glyph nudged DOWN by a fraction of the icon size, fading out — the same
# layered-silhouette shadow SpriteButton/the wallet pills use, so the glyph lifts off the paper tile.
const GLYPH_SHADOW := [{"dy": 0.03, "a": 0.18}, {"dy": 0.06, "a": 0.12}, {"dy": 0.09, "a": 0.07}]
# Calm default paper role per button (flatten — no warm accent for Play; the glyph carries the identity).
# The workbench palette overrides any of these; the live game reads the saved palette.
const ACTION_TINT_DEFAULTS := {
	"map": "cream", "residents": "cream", "daily": "cream", "vault": "cream",
	"mail": "cream", "play": "cream", "home": "cream", "bag": "cream", "almanac": "cream",
}
# THE WALLET's per-currency paper role — the same PAPER_SURFACES roles the nav row's tabs wear, so the
# pills join the tab family instead of forming a second palette. Read through `action_role_fill` (which
# is just role -> paper role -> fill) and then chalked by NavBar.chalk, exactly as a tab's fill is.
# Approved concept: _concepts/screens/home_screen_furniture_a_v1_1080x1920.png — pale blue behind the
# droplet, pale gold behind the star coin, warm clay behind the acorn.
const CURRENCY_TINT_DEFAULTS := {"water": "sky", "coin": "gold", "gem": "coral", "star": "gold"}
# The wallet numeral's OWN shadow, the same shape and the same reason as the nav caption's
# (NavBar.CAPTION_SHADOW): chalked pastel faces sit in the 80-92 value band, so white type resolves
# against its own shadow rather than against the paper. `dy` and `blur` are fractions of the font size.
const CURRENCY_NUM_SHADOW := {"dy": 0.06, "a": 0.34, "blur": 0.10}
# The shared cut-paper edge defaults for the action button (same knob SET as button/frame; own corner).
const ACTION_BUTTON_CP_DEFAULTS := {"deckle": true, "corner": 20, "deckle_amp": 5, "deckle_freq": 5, "rim_width": 2, "edge_shadow": true}

const BUTTON_PATCH := Vector4(34, 24, 34, 24)
const BOARD_PATCH := Vector4(34, 34, 34, 34)
const SLOT_PATCH := Vector4(32, 32, 32, 32)
const RESOURCE_PILL_PATCH := Vector4(52, 52, 52, 52)
const DIALOG_PATCH := Vector4(42, 42, 42, 42)

const PAPER_MASK_SHADER := """
shader_type canvas_item;

uniform vec2 control_size = vec2(1.0);
uniform float radius_px = 1.0;
// Retint of the grain sheet, as a straight multiply. Default white → every existing caller's pixels
// are unchanged; only a dialog cell asking for the sage face passes anything else.
uniform vec4 tint = vec4(1.0);

float rounded_box_distance(vec2 point, vec2 half_size, float radius) {
	vec2 q = abs(point) - half_size + vec2(radius);
	return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - radius;
}

void fragment() {
	vec4 paper = texture(TEXTURE, UV);
	float distance_to_edge = rounded_box_distance(
		(UV - vec2(0.5)) * control_size,
		control_size * 0.5,
		radius_px
	);
	float mask = 1.0 - smoothstep(-1.0, 1.0, distance_to_edge);
	COLOR = vec4(paper.rgb * tint.rgb, paper.a * mask);
}
"""
static var _paper_mask_shader: Shader

static func _meadow_path(file_name: String) -> String:
	return Game.art(MEADOW_UI % file_name)

static func _meadow_tex(file_name: String) -> Texture2D:
	var path := _meadow_path(file_name)
	return load(path) as Texture2D if ResourceLoader.exists(path) else null

static func _rounded_paper_layer(node_name: String, file_name: String, size_px: Vector2, corner_px: float, inset: float = 2.0, tint: Color = Color.WHITE) -> TextureRect:
	var paper := TextureRect.new()
	paper.name = node_name
	paper.texture = _meadow_tex(file_name)
	# ORDER MATTERS: expand_mode before size, and position last. Touching position (or size) first
	# caches the texture's native px (256) as the Control's minimum size; the expand_mode change only
	# invalidates that cache DEFERRED, so a same-frame `size` set still clamps up to 256 — the paper
	# then overflows the ~122px cell face and the corner mask + tile clip cut it flat (the "clipped
	# cell" bug).
	paper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	paper.stretch_mode = TextureRect.STRETCH_SCALE
	paper.size = Vector2(maxf(1.0, size_px.x - inset * 2.0), maxf(1.0, size_px.y - inset * 2.0))
	paper.position = Vector2.ONE * inset
	paper.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _paper_mask_shader == null:
		_paper_mask_shader = Shader.new()
		_paper_mask_shader.code = PAPER_MASK_SHADER
	var mask := ShaderMaterial.new()
	mask.shader = _paper_mask_shader
	mask.set_shader_parameter("control_size", paper.size)
	mask.set_shader_parameter("radius_px", maxf(0.0, corner_px - inset))
	mask.set_shader_parameter("tint", tint)
	paper.material = mask
	return paper

## Add one flat paper-grain layer to a code-drawn rounded panel. The parent Container lays this layer
## into the shell's fixed inset; the shader supplies the rounded clip while the StyleBoxFlat owns the
## actual shape, edge, and shadow.
static func apply_rounded_paper_panel_surface(panel: Control, node_name: String, file_name: String, corner_px: float, inset: float = 2.0) -> TextureRect:
	if panel == null:
		return null
	panel.set_meta(Look.SHADOW_CORNER_META, corner_px)   # the element's real rounding — shadow wrappers read this
	var existing := panel.find_child(node_name, false, false) as TextureRect
	if existing != null:
		var existing_material := existing.material as ShaderMaterial
		if existing_material != null:
			existing_material.set_shader_parameter("radius_px", maxf(1.0, corner_px - inset))
		return existing

	var paper := TextureRect.new()
	paper.name = node_name
	paper.texture = _meadow_tex(file_name)
	paper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	paper.stretch_mode = TextureRect.STRETCH_SCALE
	paper.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if _paper_mask_shader == null:
		_paper_mask_shader = Shader.new()
		_paper_mask_shader.code = PAPER_MASK_SHADER
	var material := ShaderMaterial.new()
	material.shader = _paper_mask_shader
	material.set_shader_parameter("radius_px", maxf(1.0, corner_px - inset))
	paper.material = material
	panel.add_child(paper)
	panel.move_child(paper, 0)

	var sync_size := func() -> void:
		if is_instance_valid(paper):
			material.set_shader_parameter("control_size", Vector2(maxf(1.0, paper.size.x), maxf(1.0, paper.size.y)))
	paper.resized.connect(sync_size)
	paper.ready.connect(sync_size)
	return paper

static func rugged_paper_surface(host: Control, node_name: String, size_px: Vector2, fill: Color, rim: Color, corner_px: float, cp: Dictionary = {}) -> Control:
	if host == null:
		return null
	var CutPaper := load("res://engine/scripts/ui/cut_paper.gd")
	if CutPaper == null:
		return null
	var surface = CutPaper.new()
	surface.name = node_name
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.custom_minimum_size = size_px
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var o: Dictionary = cp.duplicate(true)
	o["corner"] = corner_px
	surface.configure(o, fill, rim, cut_paper_tile())
	host.add_child(surface)
	return surface

static func _set_texture_margins(style: StyleBoxTexture, margins: Vector4) -> void:
	style.set_texture_margin(SIDE_LEFT, margins.x)
	style.set_texture_margin(SIDE_TOP, margins.y)
	style.set_texture_margin(SIDE_RIGHT, margins.z)
	style.set_texture_margin(SIDE_BOTTOM, margins.w)

static func _sync_paper_button_state(button: Button, paper: TextureRect, alpha: float) -> void:
	if not is_instance_valid(button) or not is_instance_valid(paper):
		return
	var tone := 1.0
	match button.get_draw_mode():
		BaseButton.DRAW_HOVER:
			tone = 1.04
		BaseButton.DRAW_PRESSED, BaseButton.DRAW_HOVER_PRESSED:
			tone = 0.90
		BaseButton.DRAW_DISABLED:
			tone = 0.68
	paper.self_modulate = Color(tone, tone, tone, alpha)

static func _apply_rounded_paper_surface(
	button: Button,
	paper_name: String,
	fill: Color,
	corner: float,
	margins: Vector4,
	inset := 2.0,
	surface_alpha := 1.0,
	behind := false,
	border_px := 1.0
) -> TextureRect:
	button.set_meta(Look.SHADOW_CORNER_META, corner)   # the element's real rounding — shadow wrappers read this
	# `behind` = the paper draws BEHIND the button's own canvas item, for buttons whose content is the
	# Button's native text/icon (pill_button) rather than child nodes (the rect nav buttons): the
	# stylebox then contributes only its border + content margins, and the paper is the fill.
	var base := StyleBoxFlat.new()
	base.draw_center = not behind
	base.bg_color = Color(fill.r, fill.g, fill.b, fill.a * surface_alpha)
	base.border_color = PAPER_EDGE
	base.set_border_width_all(int(border_px))     # 0 = a BARE paper cut, no hairline edge at all
	base.set_corner_radius_all(int(round(corner)))
	base.anti_aliasing = true
	base.content_margin_left = margins.x
	base.content_margin_top = margins.y
	base.content_margin_right = margins.z
	base.content_margin_bottom = margins.w
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, base)

	var paper := TextureRect.new()
	paper.name = "PaperSurface"
	paper.show_behind_parent = behind
	paper.texture = _meadow_tex(paper_name)
	paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	paper.offset_left = inset
	paper.offset_top = inset
	paper.offset_right = -inset
	paper.offset_bottom = -inset
	paper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	paper.stretch_mode = TextureRect.STRETCH_SCALE
	paper.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if _paper_mask_shader == null:
		_paper_mask_shader = Shader.new()
		_paper_mask_shader.code = PAPER_MASK_SHADER
	var material := ShaderMaterial.new()
	material.shader = _paper_mask_shader
	material.set_shader_parameter("radius_px", maxf(1.0, corner - inset))
	paper.material = material
	button.add_child(paper)

	var sync_size := func() -> void:
		if is_instance_valid(paper):
			material.set_shader_parameter("control_size", Vector2(maxf(1.0, paper.size.x), maxf(1.0, paper.size.y)))
	var sync_state := func() -> void:
		_sync_paper_button_state(button, paper, surface_alpha)
	paper.resized.connect(sync_size)
	paper.ready.connect(sync_size)
	paper.ready.connect(sync_state)
	button.draw.connect(sync_state)
	return paper

## The CODE-DRAWN rugged-edge button surface — the SAME deckled paper as the dialog frame
## (engine/scripts/ui/cut_paper.gd), drawn behind a transparent Button so the torn edge + tiled fibre
## + shape-true drop shadow size to any button with no stretch (mirrors dialog_frame's cut_paper path).
## The role fill becomes the panel's paper_color; press/disabled darken it. Returns the CutPaperPanel.
## `margins` is the content inset (L,T,R,B). When `shadow` is on the PANEL casts its own shadow, so the
## caller must NOT also wrap the button in the rectangular _maybe_shadow (that is a double shadow).
static func _apply_deckle_button_surface(
	button: Button,
	fill: Color,
	corner: float,
	cp_opts: Dictionary,
	margins: Vector4,
	enabled: bool = true,
	tile: Texture2D = null       # per-role paper fibre; null → the shared cream tile (cut_paper_tile)
) -> Control:
	button.set_meta(Look.SHADOW_CORNER_META, corner)
	# transparent styleboxes: the panel behind is the visible face; the stylebox only holds the content
	# margins (so the label/icon sit inside the deckled edge) — identical text layout to the shader path.
	var clear := StyleBoxFlat.new()
	clear.bg_color = Color(0, 0, 0, 0)
	clear.draw_center = false
	clear.content_margin_left = margins.x
	clear.content_margin_top = margins.y
	clear.content_margin_right = margins.z
	clear.content_margin_bottom = margins.w
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, clear)

	var base_fill: Color = fill if enabled else fill.lerp(Color(0.55, 0.55, 0.55), 0.45)
	var panel: Control = load(CUT_PAPER).new()
	panel.name = "ButtonDeckleSurface"
	panel.show_behind_parent = true
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.configure(cp_opts, base_fill, null, tile if tile != null else cut_paper_tile())   # the ONE shared edge applier (role tile, else the shared cream fibre)
	panel.corner = corner                                          # the button's own corner (may be an explicit opt)
	button.add_child(panel)

	# press feedback: darken the paper while held, restore on release (disabled buttons never press)
	if enabled:
		button.button_down.connect(func() -> void:
			if is_instance_valid(panel):
				panel.paper_color = base_fill.darkened(0.08)
				panel.queue_redraw())
		button.button_up.connect(func() -> void:
			if is_instance_valid(panel):
				panel.paper_color = base_fill
				panel.queue_redraw())
	return panel

## The largest font size ≤ `want_px` at which `text` still fits in `room` px on the BOLD face — the same
## shrink-to-fit rule dialog_title_font applies to a long sheet title, here for any single-line label.
static func fit_bold_font_px(text: String, want_px: int, room: float) -> int:
	var f: Font = bold_font()
	if f == null or text == "" or room <= 0.0:
		return want_px
	var tw: float = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, want_px).x
	if tw <= room:
		return want_px
	return maxi(8, int(floor(float(want_px) * room / tw)))

## One caption layer: the tile's bold caption pinned so its BASELINE sits `baseline_px` above the
## button's bottom edge, nudged down by `dy` and tinted `color`. Stacking a few darkened copies under
## the white face is the SAME layered-silhouette shadow the glyph wears (GLYPH_SHADOW) — a hard font
## outline would read as a sticker, which the paper look does not have anywhere else.
static func _caption_layer(text: String, fsz: int, color: Color, box_h: float, baseline_px: float, dy: float) -> Label:
	var f: Font = bold_font()
	var ascent: float = f.get_ascent(fsz) if f != null else float(fsz) * 0.8
	var lbl := _kit_label(text, fsz, color)
	lbl.add_theme_font_override("font", f)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	lbl.set_anchors_preset(Control.PRESET_TOP_WIDE)
	lbl.offset_left = 0.0
	lbl.offset_right = 0.0
	lbl.offset_top = box_h - baseline_px - ascent + dy
	lbl.offset_bottom = lbl.offset_top + float(fsz) * 2.0
	return lbl

## The paper FILL a button role resolves to under a tint map — role → paper role → surface fill. Exposed
## because a caller that must TRANSFORM the fill (the nav row chalks its tabs, NavBar.chalk) has to start
## from the same colour the button would have picked; it reads this one lookup rather than re-walking the
## PAPER_SURFACES chain and drifting from it.
static func action_role_fill(role: String, tints: Dictionary = ACTION_TINT_DEFAULTS) -> Color:
	var surface: Dictionary = PAPER_SURFACES.get(String(tints.get(role, "cream")), PAPER_SURFACES["cream"])
	return surface.get("fill", Pal.CREAM)

## The shared ACTION BUTTON: a flat Button wearing the code-drawn rugged cut-paper edge (a CutPaperPanel,
## the SAME applier the pill/frame/rows use) filled by its per-button paper-role tint, with a centered
## transparent glyph on top. ONE source for the home bottom bar and the board Home/Bag wells — the baked
## nav_<x>.png tiles are retired. `opts`: cp (cut-paper opts) · tints (role→paper-role map) · icon_scale ·
## shadow · shadow_params · fill (explicit override) · glyph_rel (explicit override) · name · tooltip.
## NAV-TAB opts (all off by default, so every existing caller is untouched — see NavBar.tab_opts, which
## derives the px values for a whole row so the taller ACTIVE tile still matches its neighbours):
##   caption / caption_font_px / caption_baseline_px — a bold white caption under the glyph;
##   glyph_box_px / glyph_center_frac — the glyph shrinks and rides high once a caption shares the tile;
##   active / rim_px / rim_fill — the raised current tab's rim, drawn OUTSIDE the fill (`rim_fill`
##                    defaults to Pal.CREAM, so every existing caller keeps the cream rim);
##   bleed_bottom — px the PAPER extends below the button rect (a tab bled off the screen edge rounds
##                  only its top corners); the button's own rect, and its hit area, stay on-screen.
##   caption_shadow — the caption's own shadow stack (defaults to the glyph's GLYPH_SHADOW); a caller
##                    whose tile is PALE overrides it so white type keeps its local contrast.
##   glyph_shadow — the ICON's shadow stack (defaults to GLYPH_SHADOW, so the board's Home/Bag wells and
##                    every other action_button caller are untouched). Each layer is {dy, a} plus an
##                    optional `grow`: the copy is drawn `grow` × the icon box larger, split evenly on
##                    every side, which turns the straight-down smear into a pool AROUND the glyph.
##                    `grow` defaults to 0 → a layer without it renders exactly as it always did.
## (The nav row's smooth corners and its rimless plain tiles are NOT separate flags: it zeroes `deckle_amp`
## and `rim_width` through the ordinary cut-paper knob set in EdgeTab.tab_cp, like every per-row tuning.)
static func action_button(role: String, size: Vector2, action: Callable, opts: Dictionary = {}) -> Button:
	var b := Button.new()
	b.name = String(opts.get("name", "ActionButton_" + role))
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = size
	b.size = size
	if String(opts.get("tooltip", "")) != "":
		b.tooltip_text = String(opts["tooltip"])
	if action.is_valid():
		b.mouse_filter = Control.MOUSE_FILTER_STOP
		b.pressed.connect(action)
	else:
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# transparent styleboxes: the deckle panel behind is the visible face (identical to the pill/row path)
	var clear := StyleBoxFlat.new()
	clear.bg_color = Color(0, 0, 0, 0)
	clear.draw_center = false
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, clear)
	# resolve the per-button fill from its paper role (explicit `fill` wins)
	var fill: Color = opts.get("fill", action_role_fill(role, opts.get("tints", ACTION_TINT_DEFAULTS)))
	var cp: Dictionary = opts.get("cp", cut_paper_opts_from_config(load_config(CONFIG_PATH), "action_button", ACTION_BUTTON_CP_DEFAULTS)).duplicate()
	if opts.has("corner"):
		cp["corner"] = float(opts["corner"])          # the caller's own corner (a nav tab's is a fraction of its width)
	var corner := float(cp.get("corner", 20.0))
	b.set_meta(Look.SHADOW_CORNER_META, corner)
	# `bleed_bottom` lets the PAPER run past the button's bottom edge (a tab bled off the screen edge):
	# the rounded box keeps its full radius but the bottom corners fall off-screen, so only the top two
	# read as round. The Button's own rect is untouched, so its hit area never leaves the screen.
	var bleed := maxf(0.0, float(opts.get("bleed_bottom", 0.0)))
	# (no behind-tile drop shadow: the cut-paper edge carries its own edge shadow; the only shadow this
	# button wears is the ICON's, gated by `icon_shadow` below.)
	# the ACTIVE tab's rim: the SAME edge, one rim thickness bigger on every side, drawn UNDER the
	# face so it shows as a rim around it. Added FIRST so it sits behind the face among the behind-parent
	# children (the face's own edge shadow then separates the two sheets, as with the paper backer).
	if bool(opts.get("active", false)):
		var rim_px := maxf(0.0, float(opts.get("rim_px", size.x * 0.037)))
		if rim_px > 0.0:
			var rim_cp: Dictionary = cp.duplicate()
			rim_cp["corner"] = corner + rim_px
			# the rim is a hairline, not a sheet: a slab bevel on it would eat its whole width and read as a
			# muddy border. It keeps the face's ambient halo — the RIM is the outer sheet, so the rim is what
			# casts onto the art behind the tab, at the full reach.
			rim_cp["bevel_px"] = 0.0
			# …and the FACE gives that reach up, because what sits behind the FACE is not the art, it is this
			# rim. An ambient halo reaching several rim-widths out paints the whole rim into shadow: measured
			# on the render, a WHITE rim came back at 0.68× — a mid grey, and the active tab stopped reading.
			# The face keeps the contact darkness (halo_strength is the alpha AT the edge, so it is unchanged)
			# over a short reach: the two sheets still separate, and the rim's outer half stays the fill it
			# was given. Scoped to `active` — the only caller that draws a rim at all is the nav row.
			var want_reach := float(cp.get("halo_reach", 0.0))
			var capped := minf(want_reach, rim_px * 0.45)
			# the halo's LIGHT DIRECTION shortens with it. `halo_offset` slides the rings by a fixed px
			# amount; left at the full-reach value over a reach cut to a sixth it would push every ring
			# clean off the lit side and pile them past the fringe on the other, which is not a shorter
			# shadow but a different one. Scaling keeps the offset the same FRACTION of the reach, so the
			# face's contact shadow stays the shape the row was tuned to, only shorter.
			if want_reach > 0.0 and cp.has("halo_offset"):
				cp["halo_offset"] = (cp["halo_offset"] as Vector2) * (capped / want_reach)
			cp["halo_reach"] = capped
			var rim: Control = load(CUT_PAPER).new()
			rim.name = "ActionButtonActiveRim"
			rim.show_behind_parent = true
			rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
			rim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			rim.offset_left = -rim_px
			rim.offset_top = -rim_px
			rim.offset_right = rim_px
			rim.offset_bottom = bleed + rim_px
			rim.configure(rim_cp, opts.get("rim_fill", Pal.CREAM), null, cut_paper_tile())
			rim.corner = float(rim_cp["corner"])
			b.add_child(rim)
	# the code-drawn rugged edge — the ONE shared applier
	var panel: Control = load(CUT_PAPER).new()
	panel.name = "ActionButtonDeckleSurface"
	panel.show_behind_parent = true
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_bottom = bleed
	panel.configure(cp, fill, null, cut_paper_tile())
	panel.corner = corner
	b.add_child(panel)
	# the caption (a nav tab): bold white type on the shared layered-silhouette shadow, shrunk to fit the
	# tile width so the longest live caption ("Residents") neither clips nor wraps.
	var caption := String(opts.get("caption", ""))
	if caption != "":
		var want: int = int(opts.get("caption_font_px", int(round(size.x * 0.16))))
		var pad := maxf(4.0, corner * 0.35)
		var fsz := fit_bold_font_px(caption, want, size.x - pad * 2.0)
		var baseline := float(opts.get("caption_baseline_px", size.x * 0.055))
		var cap_host := Control.new()
		cap_host.name = "ActionButtonCaptionHost"
		cap_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cap_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		# the caption's shadow stack. Defaults to the glyph's, but a caller whose tile is PALE overrides it
		# (`caption_shadow`) — white type carries on a chalked pastel only if its own shadow does the work.
		for layer in (opts.get("caption_shadow", GLYPH_SHADOW) as Array):
			cap_host.add_child(_caption_layer(caption, fsz, Look.shadow_color(float(layer["a"])),
				size.y, baseline, float(fsz) * float(layer["dy"])))
		var cap := _caption_layer(caption, fsz, Color.WHITE, size.y, baseline, 0.0)
		cap.name = "ActionButtonCaption"
		cap_host.add_child(cap)
		b.add_child(cap_host)
	# the centered glyph (mouse-transparent, globally polished) — only if its sprite exists
	var glyph_rel := String(opts.get("glyph_rel", ACTION_GLYPHS.get(role, "")))
	if glyph_rel != "" and ResourceLoader.exists(Game.art(glyph_rel)):
		# the glyph family is already alpha-clean intake output (Task 1) — load it directly rather than
		# through clean_tex_path, which for an un-baked source returns a synthesized ImageTexture with no
		# resource_path (clean_tex_path is for rough-cut sprites that need defringe/feather).
		var glyph_tex := load(Game.art(glyph_rel)) as Texture2D
		var icon_px := size.y * float(opts.get("icon_scale", 0.9))
		var icwrap := CenterContainer.new()
		icwrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icwrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if caption != "":
			# a caption shares the tile: the glyph drops to its own box and rides HIGH — its centre sits at
			# `glyph_center_frac` of the tile's OWN height, not in the middle, leaving the foot to the type.
			icon_px = float(opts.get("glyph_box_px", size.x * 0.62))
			var cy := size.y * float(opts.get("glyph_center_frac", 0.42))
			icwrap.set_anchors_preset(Control.PRESET_TOP_WIDE)   # full width, a glyph-tall band at `cy`
			icwrap.offset_top = cy - icon_px * 0.5
			icwrap.offset_bottom = cy + icon_px * 0.5
		# an icon_px square block holding (optionally) the glyph's soft runtime drop shadow (darkened
		# silhouette copies nudged down) UNDER the glyph, so it lifts off the paper tile (see GLYPH_SHADOW).
		# The block is centred on the tile; STRETCH_KEEP_ASPECT_CENTERED keeps a square glyph filling icon_px.
		var glyph_shadow: Array = opts.get("glyph_shadow", GLYPH_SHADOW) as Array
		var stack := glyph_shadow_stack(glyph_tex, icon_px,
			glyph_shadow if bool(opts.get("icon_shadow", true)) else [])
		icwrap.add_child(stack)
		b.add_child(icwrap)
	# press feedback: darken the paper while held, restore on release (matches _apply_deckle_button_surface)
	b.button_down.connect(func() -> void:
		if is_instance_valid(panel):
			panel.paper_color = fill.darkened(0.08)
			panel.queue_redraw())
	b.button_up.connect(func() -> void:
		if is_instance_valid(panel):
			panel.paper_color = fill
			panel.queue_redraw())
	Look.add_press_juice(b)
	return b

static func meadow_paper_style(file_name: String, margins: Vector4, pad_left: float = 0.0, pad_top: float = 0.0, pad_right: float = 0.0, pad_bottom: float = 0.0) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = _meadow_tex(file_name)
	_set_texture_margins(style, margins)
	style.content_margin_left = pad_left
	style.content_margin_top = pad_top
	style.content_margin_right = pad_right
	style.content_margin_bottom = pad_bottom
	return style

## THE uniform shadow (skin.gd owns tint + numbers) — thin aliases so call sites read as "the shared
## shadow". `params` is the ONE shared block (a live workbench preview passes its unsaved sliders);
## when absent, the saved config's block (falling back to skin.gd defaults). No per-component overrides.
static func _shared_shadow_params(params: Dictionary = {}) -> Dictionary:
	return params if not params.is_empty() else Look.shadow_params(load_config(CONFIG_PATH))

static func _meadow_shadow_rect(corner: float, params: Dictionary = {}) -> Panel:
	return Look.shadow_rect(corner, _shared_shadow_params(params))

static func _meadow_shadow_circle(diameter: float, params: Dictionary = {}) -> Panel:
	return Look.shadow_circle(diameter, _shared_shadow_params(params))

static func _meadow_with_shadow(node: Control, corner: float, params: Dictionary = {}, circular := false) -> Control:
	# with_shadow itself prefers the node's stamped rounding (Look.SHADOW_CORNER_META) over `corner`
	return Look.with_shadow(node, corner, _shared_shadow_params(params), circular)


# Badge backgrounds (art mode): friendly label → kit sprite. The Card picks one for its Claim; the
# game reads the same map via the saved config. "auto" = the bg-default sprite (green/cream).
const BADGES := {
	"auto": "",
	"mail green": "kit/mail_pill.png",
	"mail cream": "kit/mail_pill_cream.png",
	"bag": "kit/bag_pill.png",
	"bag b": "kit/bag_pill_b.png",
	"bag green": "kit/bag_pill_green.png",
	"bag thin": "kit/bag_pill_thin.png",
	"shop buy": "kit/shop_buy.png",
	"shop tag": "kit/shop_tag.png",
	"shop oval": "kit/shop_oval.png",
	"level green": "kit/level_btn.png",
}

# Circle/plate sprites for the Card's LEFT icon badge (the disc behind the message icon). "" = a flat
# code-drawn cream disc. disc_round is the lightest (pale cream); btn_round is the darker gold chrome.
const ICON_BADGES := {
	"disc light": "shared/disc_round.png",
	"round chrome": "shared/btn_round.png",
	"cream (flat)": "",
}

# Highlight styles for a daily day card (the rim/glow drawn over the cream square). The Daily dialog
# picks one for TODAY's rung and one for a milestone day — both saved settings the workbench tunes.
const DAY_BADGES := ["plain", "gold rim", "gold glow", "amber glow", "leaf glow"]

# The POPULAR ribbon texts a small card can wear (shop merchandising tags). "" = no ribbon.
const POPULAR_BADGES := ["", "Popular", "Best value", "Sale", "New", "Welcome", "Limited", "2× bonus", "-50%", "Hot"]

# Demo inbox — same shape as the GAME's messages (core/inbox.gd): reward is a {coins,gems,water} dict
# so one component renders both. The news note carries no reward (→ no chip / no Claim).
const DEMO_MAIL := [
	{"icon": "gift", "title": "Welcome Gift", "body": "Thanks for joining us!", "reward": {"gems": 50}},
	{"icon": "leaf", "title": "Garden Update", "body": "Here are your rewards!", "reward": {"water": 30}},
	{"icon": "news", "title": "Maintenance Notice", "body": "Servers will be down soon.", "reward": {}},
	{"icon": "gift", "title": "Daily Bonus", "body": "Your daily reward is here!", "reward": {"coins": 100, "gems": 5}},
]

# Demo daily-gifts ladder (7 days) for the workbench preview — same shape the game builds from
# core/login.gd. state: done (claimed ✓) · today (the claimable rung, green Claim) · future. A future
# milestone shows the mystery chest instead of its reward.
const DEMO_DAILY := [
	{"day": 1, "reward": {"coins": 50}, "state": "done"},
	{"day": 2, "reward": {"water": 10}, "state": "done"},
	{"day": 3, "reward": {"gems": 5}, "state": "done"},
	{"day": 4, "reward": {"coins": 150}, "state": "today"},
	{"day": 5, "reward": {"coins": 100}, "state": "future"},
	{"day": 6, "reward": {"water": 20}, "state": "future"},
	{"day": 7, "reward": {"gems": 30}, "state": "future", "mystery": true},
]

# Demo discovery ladder (12 tiers) for the workbench preview — same shape the game builds from a line's
# Quests.ladder_entries: {tier, seen, marked, icon|node}. A SEEN tier shows its content (here a stand-in
# icon; the game passes a real merge-piece node), an UNSEEN tier the locked slot well, one tier is marked
# (the tapped/asked tier — flagged by the sparkle, not a bigger cell). Discovered up to tier 6, mirroring tiers.png.
const DEMO_TIERS := [
	{"tier": 1, "seen": true, "icon": "leaf"},
	{"tier": 2, "seen": true, "icon": "leaf"},
	{"tier": 3, "seen": true, "icon": "daisy"},
	{"tier": 4, "seen": true, "icon": "daisy"},
	{"tier": 5, "seen": true, "icon": "daisy"},
	{"tier": 6, "seen": true, "icon": "daisy", "marked": true},
	{"tier": 7, "seen": false},
	{"tier": 8, "seen": false},
	{"tier": 9, "seen": false},
	{"tier": 10, "seen": false},
	{"tier": 11, "seen": false},
	{"tier": 12, "seen": false},
]

# Demo settings rows for the workbench preview — the SAME shape the game builds from save.gd's
# persisted flags (engine/scripts/ui/settings.gd): a label + an on/off value. on_toggle is supplied
# by the caller (the game persists; the workbench just previews the flip).
const DEMO_SETTINGS := [
	{"label": "Music", "value": false},
	{"label": "Sounds", "value": true},
	{"label": "Vibration", "value": true},
	{"kind": "info", "label": "Game Center", "value": "not signed in"},
	{"kind": "info", "label": "Version", "value": "1.1.10"},
	{"kind": "action", "label": "Reset save", "confirm_label": "Tap again to wipe", "destructive": true},
]

# Demo vault state for the workbench preview — same shape the game builds from core/vault.gd (the
# accrual jar's balance/cap + the fixed price + the claim gate). balance/claimable are preview-only.
const DEMO_VAULT := {"balance": 320, "cap": 500, "price": "$4.99", "claimable": true, "claim_min": 100}

## The GAME shop's items, faithfully from Game.DATA, grouped into the SAME sections the real
## storefront uses (engine/scripts/ui/shop.gd) — each a {caption, cards} dict the shop dialog draws under
## a vine divider. Quick help is a 2-card row; Acorn pouches is the gem ladder. (The Featured item-shortcut
## row was removed 2026-06-23 with the shop's item-buying — that moves to the board's item info bar.)
## Only the ITEMS (icon / amount / price / ribbon); the card STYLING is the shared small card.
static func demo_shop() -> Array:
	var D := Game.DATA
	# Quick help — refill water + a coin pouch (a row of just TWO), both paid in gems
	var help: Array = [
		{"icon": "shop_can", "label": "Fill water", "price": str(int(D.REFILL_DIAMOND_COST)), "price_icon": "gem"},
		{"icon": "shop_pouch", "label": "Coin pouch", "count": 150, "price": "5", "price_icon": "gem"},
	]
	# Acorn pouches — the cash → gems ladder (a 3-wide grid; the merchandised packs wear ribbons)
	var packs: Array = []
	for i in (D.CASH_PACKS as Array).size():
		var pk: Dictionary = D.CASH_PACKS[i]
		# the escalating acorn-PACK icon the REAL ladder draws (mirrors Shop._pack_icon_id) — replicated
		# here so the bake auto-discovers pack_t1…pack_tN; else they live-polish on first shop open (the freeze).
		var pack_art := "pack_t%d" % (i + 1)
		if not ResourceLoader.exists(Game.art("ui/currency/icon_%s.png" % pack_art)):
			pack_art = "gem"
		var card := {"icon": pack_art, "count": int(pk.get("gems", 0)), "price": Iap.usd(String(pk.get("key", "")))}
		if bool(pk.get("pop", false)):
			card["ribbon"] = "Popular"               # the merchandised mid anchor
		elif i == (D.CASH_PACKS as Array).size() - 1:
			card["ribbon"] = "Best value"            # the whale tier (best rate)
		packs.append(card)
	return [
		{"caption": "Quick help", "cards": help},
		{"caption": "Acorn pouches", "cards": packs},
	]

## Resolve an icon id to a real sprite Control. Most ids ride the shared Look.icon; "bluegem" is the
## faceted premium gem (not the grove's acorn), loaded directly.
static func make_icon(id: String, px: float) -> Control:
	var node := _icon_rect(_icon_tex(id), px)   # polished (defringe + feather), via the shared resolver
	return node if node != null else Look.icon(id, px)   # glyph fallback when no sprite

## A polished texture wrapped as the SHARED icon rect: a centred, mouse-transparent square that fills its
## box by its own aspect. Returns null when the texture is absent (the caller supplies the glyph fallback).
## make_icon (id lookup) and home_button's icon_rel (direct kit path) both build through this one layout.
static func _icon_rect(tex: Texture2D, px: float) -> Control:
	if tex == null:
		return null
	var t := TextureRect.new()
	t.texture = tex
	t.custom_minimum_size = Vector2(px, px)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

## AN ICON RESTING ON THE PAPER, not printed on it: an `icon_px` square block holding `layers` darkened
## silhouette copies of `tex` UNDER one clean copy of it. Each layer is drawn `grow`×icon_px wider (split
## evenly on all four sides, so the pool goes all the WAY ROUND rather than smearing downward) and
## `dy`×icon_px lower, at alpha `a`. `grow` defaults to 0, which is the plain straight-down GLYPH_SHADOW
## every board button has always drawn.
##
## ONE builder for every glyph in the game. It was lifted out of `action_button` verbatim when the wallet
## pill's currency icons needed the same treatment: the nav tabs' glyphs rode the generated dense stack
## (Paper.glyph_shadow) and read as objects lying on the tile, while the pill icons went through a bare
## `make_icon` with no shadow layer at all and read as ink printed on the sheet. Two copies of this loop
## is how the two would drift apart again.
static func glyph_shadow_stack(tex: Texture2D, icon_px: float, layers: Array) -> Control:
	var stack := Control.new()
	stack.custom_minimum_size = Vector2(icon_px, icon_px)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for layer in layers:
		var sh := TextureRect.new()
		sh.texture = tex
		sh.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sh.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sh.modulate = Look.shadow_color(float(layer["a"]))
		sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sh.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		# STRETCH_KEEP_ASPECT_CENTERED scales the silhouette into the bigger rect about its own centre.
		var grow := icon_px * maxf(0.0, float(layer.get("grow", 0.0))) * 0.5
		sh.offset_left -= grow
		sh.offset_right += grow
		sh.offset_top -= grow
		sh.offset_bottom += grow
		sh.offset_top += icon_px * float(layer["dy"])
		sh.offset_bottom += icon_px * float(layer["dy"])
		stack.add_child(sh)
	var glyph := TextureRect.new()
	glyph.texture = tex
	glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glyph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.add_child(glyph)
	return stack

## The home button's BADGE (disc shell) as a texture, with its own tunable edge polish — the standalone
## Badge workbench item edits `polish` (defringe / feather / shadow) and the home button reads it, so a
## badge tweak flows to the rail + nav automatically. No polish → the raw (already-clean) shell sprite.
## `polish` keys: defringe (bool), feather (px), shadow (bool) + the add_drop_shadow knobs.
static var _shell_cache: Dictionary = {}    # "rel@<polish-json>" -> polished disc texture (per session)
const SHELL_CAP := 256                       # clean_tex_path cap for a baked disc shell (≈1.8x its 140px display)

static func shell_texture(rel: String, polish: Dictionary = {}) -> Texture2D:
	var path := Look.kit(rel)
	if rel == "" or not ResourceLoader.exists(path):
		return null
	var defr := bool(polish.get("defringe", false))
	var feat := float(polish.get("feather", 0.0))
	var shad := bool(polish.get("shadow", false))
	if not defr and feat <= 0.0 and not shad:
		return load(path)                       # untouched → the raw shell (already cleaned at intake)
	# Exactly the bakeable clean recipe (defringe + feather 2 + no shadow = the shipped home-button
	# config)? Route through clean_tex_path so the disc loads PRE-BAKED (bake_targets builds the chrome)
	# instead of paying the ~190ms live pass on every cold boot. Any richer polish (a drop shadow, a
	# different feather) still takes the live _polish_icon_aspect path below.
	if defr and is_equal_approx(feat, 2.0) and not shad:   # 2.0 = _clean_image's fixed feather
		return clean_tex_path(path, SHELL_CAP)
	# The polished disc is IDENTICAL for every button sharing this (rel, polish) — the bottom nav + rail
	# build 5-8 of them per scene, and a map<->board swap rebuilds the whole row. The polish is a ~190ms
	# CPU pass (Lanczos resize + defringe + feather), so an uncached call multiplied that by every button
	# on every navigation (the swap freeze). Memoize it: only the FIRST build pays; the rest reuse the
	# texture (a Texture2D is meant to be shared). Cleared on a workbench Save (see clear_config_cache).
	var key := rel + "@" + JSON.stringify(polish)
	if _shell_cache.has(key):
		return _shell_cache[key]
	var img := (load(path) as Texture2D).get_image()
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	var o := polish.duplicate()
	o["defringe"] = defr; o["feather"] = feat; o["shadow"] = shad; o["supersample"] = 1
	var tex := ImageTexture.create_from_image(_polish_icon_aspect(img, o))
	_shell_cache[key] = tex
	return tex

## Aspect-preserving icon polish (vs polish_image, which forces a SQUARE canvas): cap the working
## resolution keeping aspect, then defringe / feather / optional drop-shadow. Lets a tall or wide icon
## keep its proportions while still getting the edge cleanup the square polish_image gives gem.
static func _polish_icon_aspect(img: Image, opts: Dictionary) -> Image:
	var ss: int = clampi(int(opts.get("supersample", 2)), 1, 4)
	var w := img.get_width()
	var h := img.get_height()
	var m := maxi(w, h)
	var cap := mini(320, maxi(8, m * ss))
	if m != cap:
		var s := float(cap) / float(m)
		img.resize(maxi(1, int(w * s)), maxi(1, int(h * s)), Image.INTERPOLATE_LANCZOS)
	if bool(opts.get("defringe", false)):
		_defringe(img)
	var feather := float(opts.get("feather", 0.0))
	if feather > 0.0:
		_feather_alpha(img, feather)
	if bool(opts.get("shadow", false)):
		img = add_drop_shadow(img, opts)
	return img

## --- icon edge polish (defringe / feather / supersample) -----------------------------------------
static func polish_image(src: Image, opts: Dictionary = {}) -> Image:
	var do_defringe: bool = bool(opts.get("defringe", false))
	var feather: float = float(opts.get("feather", 0.0))
	var ss: int = clampi(int(opts.get("supersample", 1)), 1, 4)
	var size: int = int(opts.get("size", 160))
	var img := src.duplicate()
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	if img.has_mipmaps():
		img.clear_mipmaps()   # polish works on mip 0 only; a stale mip chain breaks resize→get_data/set_data
	# Process at a CAPPED working resolution (so a high supersample can't blow up the cost and freeze
	# the tool), then Lanczos-downscale to the output size — the downscale is the supersample AA.
	var work := mini(320, maxi(8, size * ss))
	img.resize(work, work, Image.INTERPOLATE_LANCZOS)
	if do_defringe:
		_defringe(img)
	if feather > 0.0:
		_feather_alpha(img, feather * float(work) / float(size))   # radius in working pixels
	if work != size:
		img.resize(size, size, Image.INTERPOLATE_LANCZOS)
	if bool(opts.get("shadow", false)):
		img = add_drop_shadow(img, opts)
	return img

## Bake a soft drop shadow beneath an alpha-shaped sprite (icons). Grows the canvas symmetrically by
## `pad` so the sprite stays centred (it just renders a touch smaller in its box) and the shadow — the
## sprite's own alpha, offset + blurred + warm-tinted — sits beneath it. opts: shadow_offset (Vector2
## px at this image's scale), shadow_blur (px), shadow_alpha (0..1), shadow_pad (px). The shape-true
## shadow (follows the sprite's silhouette) is why icons bake it instead of using a rounded-rect panel.
## The SHAPE-TRUE shadow layer alone (no art composited): the sprite's alpha silhouette, slate-tinted,
## offset and feathered. Returns {"image": Image, "pad": int} — the image is (w+2pad)×(h+2pad) and the
## caller places it at (-pad, -pad) relative to the art. Irregular cutouts (the star level badge) use
## this so THE uniform shadow follows their real outline instead of boxing them.
static func silhouette_shadow(img: Image, opts: Dictionary = {}) -> Dictionary:
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var off: Vector2 = opts.get("shadow_offset", Vector2(0.04, 0.07) * float(w))
	var blur: float = float(opts.get("shadow_blur", maxf(2.0, float(w) * 0.035)))
	var alpha: float = clampf(float(opts.get("shadow_alpha", 0.5)), 0.0, 1.0)
	# negative spread ERODES the silhouette (the box-shadow's expand_margin analogue) so the tinted
	# plateau starts inside the art edge instead of hugging it as a dark rim on intricate outlines.
	var spread: float = minf(0.0, float(opts.get("shadow_spread", 0.0)))
	if spread < -0.5 and w + int(spread) * 2 > 2 and h + int(spread) * 2 > 2:
		var er := int(-spread)
		var small := img.duplicate()
		small.resize(w - er * 2, h - er * 2, Image.INTERPOLATE_BILINEAR)
		var recentred := Image.create(w, h, false, Image.FORMAT_RGBA8)
		recentred.blit_rect(small, Rect2i(0, 0, small.get_width(), small.get_height()), Vector2i(er, er))
		img = recentred
	var sh_color := Look.shadow_color(alpha)
	var pad: int = int(opts.get("shadow_pad", int(ceil(blur)) + int(maxf(absf(off.x), absf(off.y))) + 2))
	var nw := w + pad * 2
	var nh := h + pad * 2
	var sx := pad + int(round(off.x))
	var sy := pad + int(round(off.y))
	var src_data := img.get_data()
	var shadow := Image.create(nw, nh, false, Image.FORMAT_RGBA8)
	var sh_data := shadow.get_data()
	for y in h:
		for x in w:
			var a := src_data[(y * w + x) * 4 + 3]
			if a == 0:
				continue
			var nx := x + sx
			var ny := y + sy
			if nx < 0 or ny < 0 or nx >= nw or ny >= nh:
				continue
			var si := (ny * nw + nx) * 4
			sh_data[si] = int(round(sh_color.r * 255.0))
			sh_data[si + 1] = int(round(sh_color.g * 255.0))
			sh_data[si + 2] = int(round(sh_color.b * 255.0))
			sh_data[si + 3] = int(a * sh_color.a)
	shadow.set_data(nw, nh, false, Image.FORMAT_RGBA8, sh_data)
	_feather_alpha(shadow, blur)
	return {"image": shadow, "pad": pad}

## The ITEM shadow stamp: the shape-true silhouette shadow for an item drawn inside a cell, baked at the
## item's FITTED on-screen size from the STANDARD shadow param set (offset_x/offset_y/blur/spread/alpha —
## the same knobs every other shadow reads, item_shadow_* on the Slot cell). NATIVE-ONLY bake — every
## step is a C++ Image op (resize / blit), no per-pixel GDScript (the old silhouette_shadow path cost
## ~16ms per stamp and stalled the board a full second): the art is resized to fit, eroded (spread),
## padded + offset by blit, and blurred by a resize-down/up round trip. The TINT is NOT baked — the
## returned "tint" (Look.shadow_color(alpha)) goes on the drawing node's modulate: rgb×0 turns the art
## black at draw time, so alpha changes never rebake and one cached stamp serves every opacity.
## Cached per (texture · fitted size · offset · blur · spread). Returns {"texture", "pad", "tint"} —
## draw at (art_pos − pad) with modulate = tint; the offset is baked in.
## Empty {} when the art has no readable image (caller falls back to the rounded-rect shadow).
static var _item_shadow_cache: Dictionary = {}
static func item_shadow_stamp(tex: Texture2D, fit_px: Vector2, params: Dictionary) -> Dictionary:
	if tex == null or fit_px.x < 1.0 or fit_px.y < 1.0:
		return {}
	var off := Vector2(float(params.get("offset_x", 0.0)), float(params.get("offset_y", 5.0)))
	var blur := maxf(0.0, float(params.get("blur", 6.0)))
	var spread := minf(0.0, float(params.get("spread", 0.0)))
	var tint: Color = Look.shadow_color(clampf(float(params.get("alpha", 0.2)), 0.0, 1.0))
	var key := "%d:%dx%d:%.1f,%.1f,%.1f,%.1f" % [tex.get_rid().get_id(),
		int(fit_px.x), int(fit_px.y), off.x, off.y, blur, spread]
	if _item_shadow_cache.has(key):
		var hit: Dictionary = _item_shadow_cache[key]
		if hit.is_empty():
			return {}
		var cached := hit.duplicate()
		cached["tint"] = tint
		return cached
	var img := tex.get_image()
	if img == null and tex is AtlasTexture:
		# the crop-to-content textures are AtlasTextures — read the atlas and cut the region ourselves
		var at := tex as AtlasTexture
		var base_img: Image = at.atlas.get_image() if at.atlas != null else null
		if base_img != null:
			base_img = base_img.duplicate()
			if base_img.is_compressed():
				base_img.decompress()
			img = base_img.get_region(Rect2i(at.region))
	if img == null:
		_item_shadow_cache[key] = {}
		return {}
	img = img.duplicate()
	if img.is_compressed():
		img.decompress()
	if img.has_mipmaps():
		img.clear_mipmaps()
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	# bake at the FITTED size so blur/spread/offset are true px at draw scale (and the bake stays cheap)
	var fw := maxi(1, int(roundf(fit_px.x)))
	var fh := maxi(1, int(roundf(fit_px.y)))
	img.resize(fw, fh, Image.INTERPOLATE_BILINEAR)
	# negative spread ERODES the silhouette (shrink + recentre) so the cast starts inside the art edge
	if spread < -0.5 and fw + int(spread) * 2 > 2 and fh + int(spread) * 2 > 2:
		var er := int(-spread)
		var small := img.duplicate()
		small.resize(fw - er * 2, fh - er * 2, Image.INTERPOLATE_BILINEAR)
		var recentred := Image.create(fw, fh, false, Image.FORMAT_RGBA8)
		recentred.blit_rect(small, Rect2i(0, 0, small.get_width(), small.get_height()), Vector2i(er, er))
		img = recentred
	# pad the canvas so offset + blur never clip, and bake the offset in via the blit position
	var pad := int(ceil(blur)) + int(maxf(absf(off.x), absf(off.y))) + 2
	var canvas := Image.create(fw + pad * 2, fh + pad * 2, false, Image.FORMAT_RGBA8)
	canvas.blit_rect(img, Rect2i(0, 0, fw, fh), Vector2i(pad + int(roundf(off.x)), pad + int(roundf(off.y))))
	# blur = a native resize round trip: down by ~blur px, bilinear back up (the upscale IS the feather)
	if blur >= 1.0:
		var cw := canvas.get_width()
		var chh := canvas.get_height()
		var dw := maxi(2, int(roundf(float(cw) / blur)))
		var dh := maxi(2, int(roundf(float(chh) / blur)))
		canvas.resize(dw, dh, Image.INTERPOLATE_BILINEAR)
		canvas.resize(cw, chh, Image.INTERPOLATE_BILINEAR)
	var out := {"texture": ImageTexture.create_from_image(canvas), "pad": pad}
	_item_shadow_cache[key] = out
	var ret := out.duplicate()
	ret["tint"] = tint
	return ret

## The item ART inside a built piece: the PieceView holder's "ItemArt" sprite when present, else the
## first textured TextureRect descendant (kit icons, resident sprites). Null when the piece is a
## code-drawn placeholder (disc / label) — nothing to silhouette.
static func content_art_of(piece: Node) -> TextureRect:
	var named := piece.find_child("ItemArt", true, false)
	if named is TextureRect and (named as TextureRect).texture != null:
		return named
	if piece is TextureRect and (piece as TextureRect).texture != null:
		return piece
	for child in piece.get_children():
		var found := content_art_of(child)
		if found != null:
			return found
	return null

static func add_drop_shadow(img: Image, opts: Dictionary = {}) -> Image:
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	var res: Dictionary = silhouette_shadow(img, opts)
	var shadow: Image = res.image
	var pad: int = res.pad
	shadow.blend_rect(img, Rect2i(0, 0, img.get_width(), img.get_height()), Vector2i(pad, pad))   # sprite OVER the shadow (alpha blend)
	return shadow

## Bleed the nearest opaque colour outward into the semi-transparent edge pixels (keeping their
## alpha), so the fringe of old-background colour disappears. A few passes for a clean rim.
static func _defringe(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	for _pass in 3:
		var data := img.get_data()
		var out := data.duplicate()
		for y in h:
			for x in w:
				var i := (y * w + x) * 4
				var a := data[i + 3]
				if a >= 230:
					continue
				var r := 0; var g := 0; var b := 0; var wsum := 0
				for off in [[-1, 0], [1, 0], [0, -1], [0, 1], [-1, -1], [1, 1], [-1, 1], [1, -1]]:
					var nx: int = x + int(off[0])
					var ny: int = y + int(off[1])
					if nx < 0 or ny < 0 or nx >= w or ny >= h:
						continue
					var ni: int = (ny * w + nx) * 4
					var na := data[ni + 3]
					if na > a + 12:
						r += data[ni] * na; g += data[ni + 1] * na; b += data[ni + 2] * na; wsum += na
				if wsum > 0:
					out[i] = int(r / wsum); out[i + 1] = int(g / wsum); out[i + 2] = int(b / wsum)
		img.set_data(w, h, false, Image.FORMAT_RGBA8, out)

## Box-blur the ALPHA channel by `radius` px — smooths the aliased stair-step edge. SEPARABLE
## (horizontal then vertical pass), so the cost is O(radius), not O(radius²) — that O(r²) kernel at a
## supersampled resolution was what froze the tool.
static func _feather_alpha(img: Image, radius: float) -> void:
	var r := int(round(radius))
	if r < 1:
		return
	var w := img.get_width()
	var h := img.get_height()
	var data := img.get_data()
	var n := w * h
	var al := PackedInt32Array()
	al.resize(n)
	for i in n:
		al[i] = data[i * 4 + 3]
	var tmp := PackedInt32Array()
	tmp.resize(n)
	for y in h:                                  # horizontal pass
		for x in w:
			var sum := 0
			var cnt := 0
			for dx in range(-r, r + 1):
				var nx: int = x + dx
				if nx < 0 or nx >= w:
					continue
				sum += al[y * w + nx]; cnt += 1
			tmp[y * w + x] = sum / cnt
	for y in h:                                  # vertical pass
		for x in w:
			var sum := 0
			var cnt := 0
			for dy in range(-r, r + 1):
				var ny: int = y + dy
				if ny < 0 or ny >= h:
					continue
				sum += tmp[ny * w + x]; cnt += 1
			al[y * w + x] = sum / cnt
	var out := data.duplicate()
	for i in n:
		out[i * 4 + 3] = al[i]
	img.set_data(w, h, false, Image.FORMAT_RGBA8, out)

## --- baked asset cleanup: defringe + feather 2, cached per (path, max_dim) ----------------------
## The defringe/feather is a per-pixel GDScript pass; running it live on first use is what hitches a
## dialog open (≈0.8s for the level screen's chrome). `make bake-textures` pre-runs the EXACT same
## _clean_image() offline into a `baked/<subpath>@<max>.png` mirror; clean_tex_path loads that when
## present, so the runtime pays only a plain texture load. A missing bake silently degrades to the
## live polish below — correct, just slower on first open.
static var _clean_cache: Dictionary = {}
# Boot perf guard: every "path@cap" that hit the
# LIVE defringe/feather fallback below — i.e. a bakeable sprite that was NOT pre-baked. On a shipped boot
# this must stay empty; an entry means a new asset polishes live on cold boot (run `make bake-textures`).
static var _live_polish_log: Array = []

## The baked-mirror path for a source sprite at a given cap: `baked/<subpath under the assets root>`
## with the cap tagged in the name (so one source baked at two caps stays two distinct files). A
## source outside the assets root flattens to just its filename. Used by BOTH the runtime lookup
## here and the bake tool, so the two always agree on where a baked file lives.
static func baked_path(src: String, max_dim: int) -> String:
	var root: String = Game.art("")
	var rel := src.substr(root.length()) if root != "" and src.begins_with(root) else src.get_file()
	var dir := rel.get_base_dir()
	var tail := "%s@%d.png" % [rel.get_file().get_basename(), max_dim]
	return Game.art("baked/" + (tail if dir == "" else dir + "/" + tail))

## Drop the cleaned-texture cache (tests / teardown). Mirrors clear_async_cache / clear_config_cache.
static func clear_clean_cache() -> void:
	_clean_cache.clear()

## A cleaned version of a sprite: defringe (kill the rough-cut colour fringe) + feather 2 (smooth the
## jagged edge). Cached by (path, max_dim) so it runs once per asset+cap. max_dim caps the working res.
static func clean_tex_path(path: String, max_dim: int = 256) -> Texture2D:
	if path == "" or not ResourceLoader.exists(path):
		return null
	var key := "%s@%d" % [path, max_dim]
	if _clean_cache.has(key):
		return _clean_cache[key]
	# pre-baked (make bake-textures): load the polished mirror directly — no per-pixel work.
	var bp := baked_path(path, max_dim)
	if ResourceLoader.exists(bp):
		var baked := load(bp) as Texture2D
		if baked != null:
			_clean_cache[key] = baked
			return baked
	# live fallback: defringe + feather on the main thread (the first-open cost the bake removes).
	_live_polish_log.append(key)            # bakeable sprite with no baked mirror — the boot guard flags this
	var img := (load(path) as Texture2D).get_image()
	var t := ImageTexture.create_from_image(_clean_image(img, max_dim))
	_clean_cache[key] = t
	return t

static func _clean_image(src: Image, max_dim: int) -> Image:
	var img := src.duplicate() as Image
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	if img.has_mipmaps():
		img.clear_mipmaps()   # work on mip 0 only; a stale mip chain breaks resize→get_data/set_data
	var w: int = img.get_width()
	var h: int = img.get_height()
	var m := maxi(w, h)
	if m > max_dim:                                   # cap the working res (aspect-preserving) for speed
		var s := float(max_dim) / float(m)
		img.resize(maxi(1, int(w * s)), maxi(1, int(h * s)), Image.INTERPOLATE_LANCZOS)
	_defringe(img)
	_feather_alpha(img, 2.0)
	return img

## --- async (worker-thread) polish -----------------------------------------------------------------
## The defringe / feather / drop-shadow / Lanczos work is pure Image math (no scene-tree access), so it
## runs on a WorkerThreadPool thread — the workbench's polish sliders (icon / badge) stay responsive
## while a tweaked value bakes off the main thread. The caller loads the RAW source Image on the main
## thread (ResourceLoader isn't threaded here) and passes it in; results are cached by key.
## Texture creation (ImageTexture.create_from_image) stays on the main thread, in _async_poll.
static var _async_cache: Dictionary = {}    # key -> finished Texture2D
static var _async_tasks: Dictionary = {}    # key -> {task:int, holder:{img:Image}}

## Polished texture for `key`: cached -> return it; first call with a source -> dispatch the polish to a
## worker and return null (not ready). `aspect`=true keeps proportions (shell), false squares it (icon).
static func polish_async(key: String, src: Image, opts: Dictionary, aspect := false) -> Texture2D:
	if _async_cache.has(key):
		return _async_cache[key]
	if src == null:
		return null
	if not _async_tasks.has(key):
		var holder := {"img": null}
		var o: Dictionary = opts.duplicate()
		var feed: Image = src.duplicate()   # the worker owns its copy (aspect polish resizes in place)
		var task := WorkerThreadPool.add_task(func() -> void:
			holder["img"] = (_polish_icon_aspect(feed, o) if aspect else polish_image(feed, o)))
		_async_tasks[key] = {"task": task, "holder": holder}
	return _async_poll(key)

## Promote one finished task into the cache (main thread — creates the texture). Returns it or null.
static func _async_poll(key: String) -> Texture2D:
	if _async_cache.has(key):
		return _async_cache[key]
	var t = _async_tasks.get(key)
	if t == null or not WorkerThreadPool.is_task_completed(int(t["task"])):
		return null
	WorkerThreadPool.wait_for_task_completion(int(t["task"]))
	_async_tasks.erase(key)
	var img = (t["holder"] as Dictionary)["img"]
	if img is Image:
		var tex := ImageTexture.create_from_image(img)
		_async_cache[key] = tex
		return tex
	return null

## Drain every finished task into the cache; returns how many are still running. Call each frame while
## awaiting (a completed task that nobody polls would never leave _async_tasks).
static func pump_polish() -> int:
	for k in _async_tasks.keys():
		_async_poll(k)
	return _async_tasks.size()

static func polish_pending() -> int:
	return _async_tasks.size()

## The finished polished texture for `key`, or null if not cached yet — a cheap peek so a caller can skip
## loading the source image on a cache hit.
static func polished_cached(key: String) -> Texture2D:
	return _async_cache.get(key)

## Test/teardown — wait out in-flight tasks, then drop the cache.
static func clear_async_cache() -> void:
	for k in _async_tasks.keys():
		WorkerThreadPool.wait_for_task_completion(int(_async_tasks[k]["task"]))
	_async_tasks.clear()
	_async_cache.clear()

## (cost_pill was ABANDONED — a reward pill is just the SHARED pill_button in its cream/static variant,
## built inline in reward_chip below. There is no separate cost-pill component; one button drives all.)

## Sum of a reward's currency components ({coins, gems, water}). 0 = a plain note (no chip / no Claim).
static func _reward_total(reward: Dictionary) -> int:
	return int(reward.get("coins", 0)) + int(reward.get("gems", 0)) + int(reward.get("water", 0))

## The reward affordance for a message: a CREAM pill showing every non-zero currency. A single currency
## IS the shared pill_button (its cream/static variant — same component as the Claim, so it inherits the
## Button's style); a multi-currency gift stacks one icon+number per line inside the cream capsule.
static func reward_chip(reward: Dictionary, btn_opts: Dictionary = {}) -> Control:
	var parts: Array = []
	for pr in [["coin", int(reward.get("coins", 0))], ["gem", int(reward.get("gems", 0))], ["water", int(reward.get("water", 0))]]:
		if int(pr[1]) > 0:
			parts.append(pr)
	if parts.is_empty():
		return Control.new()
	if parts.size() == 1:
		# the shared button, cream/static variant — no separate cost-pill component
		var o := btn_opts.duplicate()
		o["bg"] = "cream"
		o.erase("art_rel")                 # cream by role; a chosen (green) badge is dropped
		o["icon"] = String(parts[0][0])
		o["static"] = true
		o["enabled"] = true
		return pill_button(str(int(parts[0][1])), o)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for p in parts:
		var cell := HBoxContainer.new()
		cell.alignment = BoxContainer.ALIGNMENT_CENTER
		cell.add_theme_constant_override("separation", 4)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(make_icon(String(p[0]), 22))
		var l := Label.new()
		l.text = str(int(p[1]))
		l.add_theme_font_size_override("font_size", FS.FINE)   # reward amount — readable beside the 22px icon (was 15)
		l.add_theme_color_override("font_color", Pal.INK)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(l)
		col.add_child(cell)
	# The multi-currency stack rides the SAME flat cream paper-cut as the single pill_button cream chip
	# (a cream fill + thin PAPER_EDGE hairline + a texture_cream grain layer) — the baked mail_pill_cream.png
	# glossy shell is retired for it, so every cream chip beside a green Claim reads as cut from one paper.
	var frame := PanelContainer.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var chip_corner := int(btn_opts.get("corner", 16))
	var cf := StyleBoxFlat.new()
	cf.bg_color = Pal.CREAM
	cf.border_color = PAPER_EDGE
	cf.set_corner_radius_all(chip_corner)
	cf.set_border_width_all(1)
	cf.anti_aliasing = true
	cf.content_margin_left = 16; cf.content_margin_right = 16
	cf.content_margin_top = 7; cf.content_margin_bottom = 8
	frame.add_theme_stylebox_override("panel", cf)
	frame.add_child(col)
	apply_rounded_paper_panel_surface(frame, "RewardChipPaper", "texture_cream.png", float(chip_corner), 2.0)
	return frame

## (The old nine-patch claim_button was REMOVED — the mail Claim is now the shared pill_button below,
## so there is one button component. The mail card/dialog drive their Claim entirely from it.)

## Resolve any icon id to a Texture2D (so the shared button can show coin/water/gem/blue-gem, not
## just the currency folder). Mirrors make_icon's id rules.
## Resolve an icon id to its raw sprite path ("" if none). "bluegem" is the faceted premium gem;
## coin*/gem* live in currency/, everything else in shared/ (with a currency/ fallback).
static func _icon_path(id: String) -> String:
	var rels: Array = []
	if id in ["settings", "mail", "vault", "daily", "expedition", "gift", "news"]:
		rels = [MEADOW_UI % ("icon_%s.png" % id)]
	elif id == "bluegem":
		rels = ["ui/currency/icon_gem_t3.png"]
	elif id.begins_with("coin") or id.begins_with("gem"):
		rels = ["ui/currency/icon_%s.png" % id]
	else:
		rels = ["ui/shared/icon_%s.png" % id, "ui/currency/icon_%s.png" % id]
	for rel in rels:
		var p := Game.art(rel)
		if ResourceLoader.exists(p):
			return p
	return ""

static func _icon_tex(id: String) -> Texture2D:
	var p := _icon_path(id)
	return clean_tex_path(p, 192) if p != "" else null      # defringe + feather the rough-cut icon

## The icon, padded to a SQUARE canvas (centred), so its bounding box is identical for every icon id.
## A button using this with a fixed icon_max_width then keeps a CONSTANT layout whatever icon is shown —
## a tall/narrow drop and a square gem both occupy the same box (each just fills it by its own aspect).
static var _square_cache: Dictionary = {}
static func _square_icon(id: String) -> Texture2D:
	if _square_cache.has(id):
		return _square_cache[id]
	var tex := _icon_tex(id)
	if tex == null:
		return null
	var img := tex.get_image()
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	if w != h:
		var s := maxi(w, h)
		var sq := Image.create(s, s, false, Image.FORMAT_RGBA8)
		sq.blit_rect(img, Rect2i(0, 0, w, h), Vector2i((s - w) / 2, (s - h) / 2))   # centre on the square
		img = sq
	var t := ImageTexture.create_from_image(img)
	_square_cache[id] = t
	return t

## Resolve the rush-bar look from config (workbench "rush_bar" block).
static func rush_bar_opts_from_config(cfg: Dictionary) -> Dictionary:
	var r: Dictionary = cfg.get("rush_bar", {}) if cfg is Dictionary else {}
	return {
		"height":     float(r.get("height", 116.0)),     # cell height
		"score_w":    float(r.get("score_w", 300.0)),    # the centred SCORE cell width
		"side_w":     float(r.get("side_w", 224.0)),     # the flank (Time / Mult) cell width
		"gap":        float(r.get("gap", 18.0)),         # spacing between cells
		"label_size": float(r.get("label_size", 24.0)),  # the "Time" / "Score" / "Mult" caption
		"value_size": float(r.get("value_size", 46.0)),  # the numerals
		"pad":        float(r.get("pad", 16.0)),         # cell content inset
		"burn":       clampf(float(r.get("burn", 0.0)) / 100.0, 0.0, 1.0),
		"label_col":  String(r.get("label_col", "#9A7B43")),
		"value_col":  String(r.get("value_col", "#43352B")),
	}

## The rush bar's INTRINSIC (unscaled) size for a given opts — the three cells + gaps wide, the cell
## height tall. One source of truth so a caller can size/scale the bar to a target width (e.g. match
## the board) WITHOUT building it first.
static func rush_bar_intrinsic_size(opts: Dictionary) -> Vector2:
	var H := float(opts.get("height", 116.0))
	var total_w := float(opts.get("side_w", 224.0)) * 2.0 + float(opts.get("score_w", 300.0)) + float(opts.get("gap", 18.0)) * 2.0
	return Vector2(total_w, H)

## Build the rush bar. `data` = {time, score, mult} display strings. Returns a Control sized to the bar;
## the three value Labels are exposed as meta (time_label / score_label / mult_label) for live updates.
static func rush_bar(opts: Dictionary, data: Dictionary = {}) -> Control:
	var H := float(opts.get("height", 116.0))
	var score_w := float(opts.get("score_w", 300.0))
	var side_w := float(opts.get("side_w", 224.0))
	var gap := float(opts.get("gap", 18.0))
	var intrinsic := rush_bar_intrinsic_size(opts)
	var bar := Control.new()
	bar.custom_minimum_size = intrinsic
	bar.size = bar.custom_minimum_size
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var labels := {}
	var x := 0.0
	var time_cell := _rush_cell(opts, Vector2(x, 0.0), Vector2(side_w, H), "Time", String(data.get("time", "0:00")), labels, "time")
	bar.add_child(time_cell)
	x += side_w + gap
	var score_cell := _rush_cell(opts, Vector2(x, 0.0), Vector2(score_w, H), "Score", String(data.get("score", "0")), labels, "score")
	bar.add_child(score_cell)
	x += score_w + gap
	var mult_cell := _rush_cell(opts, Vector2(x, 0.0), Vector2(side_w, H), "Mult", String(data.get("mult", "x1.0")), labels, "mult")
	bar.add_child(mult_cell)
	bar.set_meta("time_label", labels.get("time"))
	bar.set_meta("score_label", labels.get("score"))
	bar.set_meta("mult_label", labels.get("mult"))
	bar.set_meta("score_cell", score_cell)        # the score / mult cells, for the rush_fx pop effects
	bar.set_meta("mult_cell", mult_cell)
	return bar

# One rush-bar cell: a plain cut-paper card (flat cream + PAPER_EDGE hairline + texture_cream grain +
# THE uniform shadow) with a centred caption + value column. Records the value Label into `labels_out[key]`.
static func _rush_cell(opts: Dictionary, pos: Vector2, size: Vector2, caption: String, value_text: String, labels_out: Dictionary, key: String) -> Control:
	var pad := float(opts.get("pad", 16.0))
	var cell := Control.new()
	cell.name = "Rush%sCell" % key.capitalize()
	cell.position = pos ; cell.size = size ; cell.custom_minimum_size = size
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var corner := clampf(size.y * 0.18, 10.0, 26.0)
	var cp: Dictionary = cut_paper_opts_from_config(load_config(CONFIG_PATH), "action_button", ACTION_BUTTON_CP_DEFAULTS)
	rugged_paper_surface(cell, "RushCellDeckleSurface", size, Pal.CREAM, PAPER_EDGE, corner, cp)
	var tx0 := pad
	var tw := maxf(10.0, size.x - pad * 2.0)
	var col := VBoxContainer.new()
	col.position = Vector2(tx0, pad)
	col.size = Vector2(tw, size.y - pad * 2.0)
	col.custom_minimum_size = col.size
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var burn := float(opts.get("burn", 0.0))
	col.add_child(_bar_label(caption, int(opts.get("label_size", 24)), String(opts.get("label_col", "#9A7B43")), tw, burn))
	var val := _bar_label(value_text, int(opts.get("value_size", 46)), String(opts.get("value_col", "#43352B")), tw, burn)
	col.add_child(val)
	cell.add_child(col)
	labels_out[key] = val
	return cell

## THE kit's plain label: text · font size · font colour, outline OFF, mouse ignored. That five-line
## run opened ~30 Label sites in this file verbatim, so it is one builder — deliberately with NO
## option flags: anything else a site needs (alignment, anchors, autowrap, a font override, clipping)
## it sets on the returned Label itself, which keeps the per-site differences visible instead of
## hiding them behind arguments. Sites that do NOT set all five (a non-zero outline, a conditional
## colour, a burn branch) are left as they are — they are not this label.
static func _kit_label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func _bar_label(text: String, size: int, color_hex: String, width: float, burn: float = 0.0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(color_hex))
	var t := clampf(burn, 0.0, 1.0)
	if t > 0.0:
		l.add_theme_color_override("font_color", Color("#4A2E14").darkened(0.35 * t))
		l.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.25 + 0.45 * t))
		l.add_theme_constant_override("shadow_offset_x", int(round(1.0 + 2.0 * t)))
		l.add_theme_constant_override("shadow_offset_y", int(round(2.0 + 3.0 * t)))
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.12 + 0.33 * t))
		l.add_theme_constant_override("outline_size", int(round(2.0 + 4.0 * t)))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(width, 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## Shared currency pill. The public name remains for compatibility, but the visible shell is the
## Meadow paper resource pill; the currency glyph and amount stay live UI.
static func gold_currency_pill(opts: Dictionary = {}, counts: Dictionary = {}) -> Control:
	var pill_w := float(opts.get("pill_w", 292))
	var base_pill_h := float(opts.get("pill_h", 100))
	var pill_h := base_pill_h
	var icon_id := String(opts.get("icon", "water"))
	var pad_left := float(opts.get("pad_left", base_pill_h * 0.18))
	var pad_x := float(opts.get("pad_x", base_pill_h * 0.16))
	var pad_y := float(opts.get("pad_y", base_pill_h * 0.12))
	var style_pad_y := maxf(pad_y, 0.0)
	var icon_box := float(opts.get("icon_box", opts.get("badge_px", 54)))
	var icon_px := float(opts.get("icon_size", 34))
	var icon_x := float(opts.get("icon_x", 0))
	var num_size := int(opts.get("num_size", 30))
	var amount_x := float(opts.get("amount_x", 0))
	var amount_w := float(opts.get("amount_w", maxf(88.0, float(num_size) * 2.9)))
	var gap := int(opts.get("gap", 12))
	var show_plus := bool(opts.get("show_plus", true))
	var plus_action := Callable()
	var plus_action_value: Variant = opts.get("plus_action", null)
	if plus_action_value is Callable:
		plus_action = plus_action_value as Callable
	var plus := _gold_currency_plus_button(opts)
	var plus_h := plus.custom_minimum_size.y if show_plus else 0.0
	var content_h := maxf(icon_box, maxf(float(num_size) * 1.45, plus_h))
	var height_pad := pad_y * 2.0
	var pill_floor_h := maxf(1.0, base_pill_h + minf(height_pad, 0.0))
	pill_h = maxf(pill_floor_h, ceilf(content_h + height_pad))

	var panel := Button.new()
	panel.name = "GoldCurrencyPill"
	panel.custom_minimum_size = Vector2(pill_w, pill_h)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.mouse_filter = Control.MOUSE_FILTER_STOP if plus_action.is_valid() else Control.MOUSE_FILTER_IGNORE
	panel.flat = false
	panel.focus_mode = Control.FOCUS_NONE
	panel.add_theme_constant_override("h_separation", 0)
	# CODE-DRAWN rugged edge: the wallet pill wears the SAME shared cut-paper edge as the dialog frame + the
	# buttons + the settings rows (engine/scripts/ui/cut_paper.gd). `cp` is the ONE normalized knob set —
	# passed in by a caller, else read from the cached config's `gold_currency_pill` block.
	var cp: Dictionary = opts.get("cp", {})
	if cp.is_empty():
		cp = pill_cp_from_config(load_config(CONFIG_PATH), base_pill_h)
	# the pill's paper is its CURRENCY's chalked paper role (water = sky, coin = gold, gem = coral),
	# the same roles and the same chalk transform the nav tabs wear. `fill` overrides it — the
	# mock-compare rig forces the concept mock's own face colour so the fill stops being a variable in a
	# shadow measurement (docs/design/verifying-against-a-mock.md). No caller passes it in the game.
	var pill_fill: Color = opts.get("fill",
		NavBar.chalk(action_role_fill(icon_id, opts.get("tints", CURRENCY_TINT_DEFAULTS))))
	var pill_margins := Vector4(pad_left, style_pad_y, pad_x, style_pad_y)
	# the corner IS the shared "Corner" edge knob; `pill_cp_from_config` derives it from the furniture
	# language (0.208 of the sheet's height — the nav tab's own corner-to-height ratio), which is the
	# smooth large-radius cut the concept draws, not the old pill_h * 0.35 capsule.
	var pill_corner := float(cp.get("corner", pill_h * Paper.FURNITURE_CORNER_H_FRAC))
	var deckle: bool = bool(opts.get("deckle", cp.get("deckle", true)))
	if deckle:
		_apply_deckle_button_surface(panel, pill_fill, pill_corner, cp, pill_margins, true)
	else:
		# smooth shader surface (deckle off): the original rounded paper-cut shell.
		_apply_rounded_paper_surface(panel, "texture_cream.png", pill_fill, pill_corner, pill_margins)
	# THE STACKED-PAPER BACKER IS OFF for the pill. It was a gold under-sheet peeking 6px past the cream
	# capsule; a furniture tile in this language is ONE sheet (the concept draws no under-sheet, and no
	# nav tab has one), and the extra layer also broke the mock rig's silhouette match — profiled against
	# the face rect our pill reported NEGATIVE darkening, a shadow that brightens
	# (docs/design/verifying-against-a-mock.md rule 6). Dropped HERE and not in the config block, because
	# the NEXT UNLOCK strip reads the same `backer*` keys through `paper_backer` and must not change.
	if plus_action.is_valid():
		panel.pressed.connect(plus_action)

	var row_host := Control.new()
	row_host.name = "GoldCurrencyPillContentHost"
	row_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	row_host.offset_left = pad_left
	row_host.offset_right = -pad_x
	row_host.offset_top = style_pad_y
	row_host.offset_bottom = -style_pad_y
	row_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row_host)

	var row := HBoxContainer.new()
	row.name = "GoldCurrencyPillRow"
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", gap)
	row_host.add_child(row)

	var icon_slot := Control.new()
	icon_slot.name = "GoldCurrencyIconSlot"
	icon_slot.custom_minimum_size = Vector2(icon_box, content_h)
	icon_slot.size = Vector2(icon_box, content_h)
	icon_slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# THE ICON RESTS ON THE PILL'S PAPER. It used to be a bare `make_icon` — one TextureRect, no shadow
	# layer of any kind — while every nav-tab glyph rode the row's generated dense stack, and that is
	# exactly what the two read as: the tab icons sit on their tile, the pill's currency was printed on
	# its sheet. Same builder, same generated stack (Paper.glyph_shadow: ~1px steps, the count derived
	# from the reach, with the lateral `grow` term that puts a pool all the way round instead of a smear
	# underneath), asked for at the pill icon's own much smaller box — so the pool scales with the art
	# and the family is one derivation, not two tunings. `icon_shadow=false` opts a caller out.
	var icon := _pill_icon(icon_id, icon_px, bool(opts.get("icon_shadow", true)))
	icon.name = "GoldCurrencyIcon"
	icon.position = Vector2(round((icon_box - icon_px) * 0.5 + icon_x), (content_h - icon_px) * 0.5)
	icon_slot.add_child(icon)
	row.add_child(icon_slot)

	var amount_slot := Control.new()
	amount_slot.name = "GoldCurrencyAmountSlot"
	amount_slot.custom_minimum_size = Vector2(amount_w, content_h)
	amount_slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	amount_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var amount_value := int(counts.get(icon_id, opts.get("count", 2450)))
	# BOLD WHITE numerals on a soft dark shadow — the tab captions' treatment, for the same reason: the
	# face is now a chalked pastel (value 80-92), where dark ink reads as a form filled in on a card and
	# white type reads as part of the same printed sheet. Godot's own Label shadow does the work a nav
	# caption needs a stack of copies for, because a numeral is one short string on a fixed baseline.
	var amount := _kit_label(FX.format_amount(amount_value), num_size, Color.WHITE)
	amount.add_theme_font_override("font", bold_font())
	amount.add_theme_color_override("font_shadow_color",
		Look.shadow_color(float(CURRENCY_NUM_SHADOW["a"])))
	amount.add_theme_constant_override("shadow_offset_x", 0)
	amount.add_theme_constant_override("shadow_offset_y",
		maxi(1, int(round(float(num_size) * float(CURRENCY_NUM_SHADOW["dy"])))))
	amount.add_theme_constant_override("shadow_outline_size",
		maxi(1, int(round(float(num_size) * float(CURRENCY_NUM_SHADOW["blur"])))))
	amount.name = "GoldCurrencyAmount"
	amount.custom_minimum_size = Vector2(amount_w, content_h)
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT   # right-align the number; amount_x pushes it toward the pill's right edge
	amount.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	amount.position = Vector2(amount_x, 0)
	# Wallet metadata: opts this label into K/M abbreviation + shrink-to-fit + right-anchor
	# (FX.format_amount / FX.fit_amount). The design font size travels with the label so a live refresh
	# can re-fit as digits grow. The fit budget is NOT the bare amount_w slot — the number is right-aligned
	# and nudged by amount_x, and overflows LEFT across the gap toward the icon, so its true room is
	# (icon's right edge → the number's right edge) = gap + amount_w + amount_x. Abbreviation already caps
	# the width, so fit only ever shrinks a genuine spill. amount_right_x/amount_slot_w let fit_amount pin
	# the right edge (amount_x + amount_w in slot coords) so a wider "10.1K" grows LEFT, not past the pill.
	amount.set_meta("amount_max_w", amount_w + float(gap) + maxf(0.0, amount_x))
	amount.set_meta("amount_slot_w", amount_w)
	amount.set_meta("amount_right_x", amount_x + amount_w)
	amount.set_meta("amount_base_font", num_size)
	amount.set_meta("amount_value", amount_value)
	amount_slot.add_child(amount)
	FX.fit_amount(amount)
	row.add_child(amount_slot)

	if show_plus:
		var plus_slot := Control.new()
		plus_slot.name = "GoldCurrencyPlusSlot"
		plus_slot.custom_minimum_size = Vector2(plus.custom_minimum_size.x, content_h)
		plus_slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		plus_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plus.position = Vector2(float(opts.get("plus_x", 0)), (content_h - plus.custom_minimum_size.y) * 0.5 + float(opts.get("plus_y", 0)))
		plus_slot.add_child(plus)
		row.add_child(plus_slot)
	# Optional OVERALL drop shadow behind the capsule. When the rugged edge is on, the cut-paper panel
	# already casts its OWN shape-true shadow (the `edge_shadow` knob) — adding the rectangular Meadow
	# shadow too would double it (a torn silhouette over a rounded-rect halo), so the rect shadow is only
	# for the smooth (deckle off) shell.
	if bool(opts.get("shadow", false)) and not deckle:
		return _meadow_with_shadow(panel, pill_h * 0.5, opts.get("shadow_params", {}) as Dictionary)
	return panel

## The wallet pill's currency icon: the SAME sprite `make_icon` resolves, wrapped in the shared glyph
## stack so it casts the nav row's own pool. Falls back to the bare icon when the id has no sprite (the
## `?` placeholder Look.icon draws is a Label, and a Label has no silhouette to cast).
static func _pill_icon(icon_id: String, icon_px: float, shadowed: bool) -> Control:
	var tex := _icon_tex(icon_id)
	if tex == null or not shadowed:
		return make_icon(icon_id, icon_px)
	return glyph_shadow_stack(tex, icon_px, Paper.glyph_shadow(icon_px))


static func _gold_currency_plus_button(opts: Dictionary = {}) -> Control:
	var base := float(opts.get("plus_base", 34))
	var button_scale := float(opts.get("plus_button", 100)) / 100.0
	var w := base * button_scale
	var h := w

	var p := Control.new()
	p.name = "GoldCurrencyPlusButton"
	p.custom_minimum_size = Vector2(w, h)
	p.size = Vector2(w, h)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex := _meadow_tex("button_plus.png")
	if tex != null:
		var art := TextureRect.new()
		art.name = "GoldCurrencyPlusArt"
		art.texture = tex
		art.set_anchors_preset(Control.PRESET_FULL_RECT)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_SCALE
		art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(art)
	else:
		var g := Label.new()
		g.name = "GoldCurrencyPlusLabel"
		g.text = "+"
		g.set_anchors_preset(Control.PRESET_FULL_RECT)
		g.add_theme_font_size_override("font_size", int(round(base * 0.70 * button_scale)))
		g.add_theme_color_override("font_color", Color("#FFF6C7"))
		g.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		g.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		g.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(g)
	return p

## A unified pill BUTTON — ONE component, parameterised by state. opts:
##   bg      "green" | "cream"     (the same button, two backgrounds — Claim vs a cream chip)
##   icon    currency id | ""      (drawn to the LEFT of the text; "" = none — the icon toggle)
##   enabled bool                  (false → greyed, non-pressable)
##   font    px
## The mail screen's green Claim and a cream icon button are this one component with different opts.
static func pill_button(text: String, opts: Dictionary = {}) -> Button:
	var bg := String(opts.get("bg", "green"))
	var icon_id := String(opts.get("icon", ""))
	var enabled: bool = bool(opts.get("enabled", true))
	var font_px := int(opts.get("font", FS.FINE))
	var shadow: bool = bool(opts.get("shadow", false)) # a soft drop shadow under the pill
	var pad_scale := float(opts.get("pad_scale", 1.0)) # shrink/grow the padding (the cost chip uses < 1 to fit a card)
	# CODE-DRAWN rugged edge: the paper roles wear the SAME shared cut-paper edge as the dialog frame + the
	# settings rows. `cp` is the ONE normalized knob set (Kit.cut_paper_opts_from_config) — passed in by a
	# caller, else read from the cached config's `button` block.
	var cp: Dictionary = opts.get("cp", {})
	if cp.is_empty():
		cp = cut_paper_opts_from_config(load_config(CONFIG_PATH), "button", BUTTON_CP_DEFAULTS)
	# `corner` is part of that shared edge set: a caller may override it explicitly (the card Claim wants a
	# roomier corner), but ABSENT one it falls back to the shared cp corner — so the sibling paper buttons
	# and chips track the workbench Corner knob instead of a hardcoded 16 (which only the live tile escaped).
	var corner := float(opts.get("corner", cp.get("corner", 16.0)))   # low = rectangular; ≥ height/2 = capsule
	var deckle: bool = bool(opts.get("deckle", cp.get("deckle", true)))
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.text = text
	b.disabled = not enabled
	b.add_theme_font_size_override("font_size", font_px)
	b.add_theme_constant_override("outline_size", 0)
	if icon_id != "":
		var tex := _square_icon(icon_id)      # square box → the icon never resizes the button per id
		if tex != null:
			b.icon = tex
			b.add_theme_constant_override("icon_max_width", int(opts.get("icon_size", font_px + 8)))
			b.add_theme_constant_override("h_separation", 7)
	if bool(opts.get("static", false)):
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE      # a display chip (the cost pill): looks like the button, not pressable
	# `paper` routes ANY registered PAPER_SURFACES role through the flat paper-cut surface (the
	# construction the green CTA already uses) instead of a baked nine-patch shell; `border` = 0 cuts
	# the hairline edge with it, for the borderless paper buttons the dialog mocks call for.
	var paper_role := String(opts.get("paper", ""))
	var border_px := float(opts.get("border", 1.0))
	var primary := bg == "green"
	var danger := bg == "danger"
	# The CREAM role is now a flat paper-cut surface BY DEFAULT — the same construction as the green CTA,
	# so a cream chip and a green Claim read as cut from the same paper (the baked button_secondary.png
	# glossy pill is retired for it). A caller that still wants the nine-patch shell passes an explicit
	# `art_rel`; danger keeps its shell.
	if not primary and not danger and paper_role == "" and String(opts.get("art_rel", "")) == "":
		paper_role = "cream"
	var fill: Color = Pal.BTN_PRIMARY if primary else (Pal.ACCENT_ALERT if danger else Pal.CREAM)
	var edge: Color = Pal.BTN_PRIMARY_EDGE if primary else (Pal.ACCENT_ALERT.darkened(0.22) if danger else Pal.STRAW)
	var ink: Color = Pal.CREAM if primary or danger else Pal.INK
	for st in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(st, ink)
	b.add_theme_color_override("font_disabled_color", Color(ink, 0.55))
	# --- background: the GREEN action role is a flat PAPER-CUT surface (texture_action_green masked to
	# the button's rounded rect) plus the shared drop shadow — the same construction as the rect home-rail
	# buttons and the slot cells, so every primary CTA in the game is cut from the one green paper. The
	# baked button_primary.png shell is retired for it; cream/danger keep their nine-patch shells.
	var paper_margins := Vector4(22.0 * pad_scale, 8.0 * pad_scale, 22.0 * pad_scale, 9.0 * pad_scale)
	if primary:
		var surface: Dictionary = PAPER_SURFACES["green"]
		var green_fill: Color = surface.get("fill", Pal.LEAF)
		# DECKLED edge (default): the same code-drawn cut-paper surface as the dialog frame, which casts
		# its OWN shape-true shadow — so we do NOT also wrap the button in the rectangular _maybe_shadow.
		if deckle:
			_apply_deckle_button_surface(b, green_fill, corner, cp, paper_margins, enabled)
			return b
		# smooth shader surface (deckle off): shadow goes on FIRST so it draws behind the paper (child order).
		_maybe_shadow(b, true, corner, opts.get("shadow_params", {}))
		var paper := _apply_rounded_paper_surface(
			b,
			String(surface.get("texture", "texture_action_green.png")),
			green_fill,
			corner,
			paper_margins,
			0.0,
			1.0,
			true,
			border_px)
		paper.name = "ButtonPaperSurface"
		return b
	# a NON-green paper role (e.g. the cream secondary): same paper-cut construction as the green CTA.
	if paper_role != "" and PAPER_SURFACES.has(paper_role):
		var proll: Dictionary = PAPER_SURFACES[paper_role]
		var proll_fill: Color = proll.get("fill", Pal.CREAM)
		if deckle:
			_apply_deckle_button_surface(b, proll_fill, corner, cp, paper_margins, enabled, _paper_role_tile(proll))
			return b
		_maybe_shadow(b, shadow, corner, opts.get("shadow_params", {}))
		var proll_paper := _apply_rounded_paper_surface(
			b,
			String(proll.get("texture", "texture_cream.png")),
			proll_fill,
			corner,
			paper_margins,
			0.0,
			1.0,
			true,
			border_px)
		proll_paper.name = "ButtonPaperSurface"
		return b

	# --- background: the sprite NINE-PATCH (nice baked borders) when "art" is on, else code-drawn ---
	if bool(opts.get("art", true)):
		# The default semantic roles use the extracted Meadow shells. An explicit art_rel remains supported
		# for specialized legacy consumers, preserving the constructor's customization semantics.
		var art_rel := String(opts.get("art_rel", ""))
		var tex: Texture2D = null
		if art_rel == "":
			var file_name := "button_primary.png" if primary else ("button_danger.png" if danger else "button_secondary.png")
			tex = _meadow_tex(file_name)
		else:
			tex = clean_tex_path(Look.kit(art_rel), 256)
		if tex != null:
			var stx := StyleBoxTexture.new()
			stx.texture = tex
			_set_texture_margins(stx, BUTTON_PATCH)
			stx.content_margin_left = 22 * pad_scale; stx.content_margin_right = 22 * pad_scale
			stx.content_margin_top = 8 * pad_scale; stx.content_margin_bottom = 9 * pad_scale
			b.add_theme_stylebox_override("normal", stx)
			b.add_theme_stylebox_override("hover", stx)
			var sp_t: StyleBoxTexture = stx.duplicate(); sp_t.modulate_color = Color(0.88, 0.88, 0.88)
			b.add_theme_stylebox_override("pressed", sp_t)
			var sd_t: StyleBoxTexture = stx.duplicate(); sd_t.modulate_color = Color(0.62, 0.62, 0.62)
			b.add_theme_stylebox_override("disabled", sd_t)
			return _maybe_shadow(b, shadow, 24.0, opts.get("shadow_params", {}))
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = edge
	s.set_corner_radius_all(int(corner))      # rectangular at low values; capsule near/above height/2
	s.set_border_width_all(2)
	# NO native shadow — the drop shadow is the SHARED box-shadow, wrapped behind the whole button below.
	s.content_margin_left = 18 * pad_scale; s.content_margin_right = 18 * pad_scale
	s.content_margin_top = 7 * pad_scale; s.content_margin_bottom = 8 * pad_scale
	b.add_theme_stylebox_override("normal", s)
	b.add_theme_stylebox_override("hover", s)
	var sp: StyleBoxFlat = s.duplicate()
	sp.bg_color = fill.darkened(0.08)
	b.add_theme_stylebox_override("pressed", sp)
	var sd: StyleBoxFlat = s.duplicate()
	sd.bg_color = fill.lerp(Color(0.55, 0.55, 0.55), 0.55)
	b.add_theme_stylebox_override("disabled", sd)
	b.add_child(Look.rim_overlay(corner, 2))
	return _maybe_shadow(b, shadow, corner, opts.get("shadow_params", {}))

## Cast the SHARED box-shadow behind a BUTTON, returning the SAME button (callers connect `.pressed` and
## set size flags on it, so its identity must be preserved). A Button is not a Container, so the shadow
## Panel rides as a `show_behind_parent` child — drawn behind the button, no layout fight. `params` is
## Look.shadow_params() (the single shared look); an empty dict falls back to the shipped defaults.
static func _maybe_shadow(b: Control, on: bool, corner: float, params: Dictionary = {}) -> Control:
	if not on:
		return b
	var sh := _meadow_shadow_rect(Look.shape_corner(b, maxf(corner, 18.0)), params)
	sh.show_behind_parent = true
	b.add_child(sh)
	return b

## (The standalone buy_pill / green-CTA builder was REMOVED — it was the original spike component and
## is fully covered by pill_button(green, icon). The CTA is now the shared button's green variant.)

## A plated message icon — the icon seated on a chosen circular badge sprite (see ICON_BADGES; the Card
## picks which). `px` is the badge diameter; the icon sits at ~58% inside it. badge_rel "" (or missing
## art) falls back to a flat code-drawn cream disc — the lightest option.
static func plated_icon(id: String, px: float = 56.0, badge_rel: String = "shared/disc_round.png") -> Control:
	var plate := PanelContainer.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var icon_px := px * 0.58
	var pad := (px - icon_px) / 2.0
	var tex: Texture2D = clean_tex_path(Look.kit(badge_rel), 256) if badge_rel != "" else null
	if tex != null:
		var st := StyleBoxTexture.new()
		st.texture = tex                                  # whole sprite scaled → its baked edge shows
		st.content_margin_left = pad; st.content_margin_right = pad
		st.content_margin_top = pad; st.content_margin_bottom = pad
		plate.add_theme_stylebox_override("panel", st)
	else:
		var ps := StyleBoxFlat.new()
		ps.bg_color = Color(Pal.CREAM, 0.9)
		ps.set_corner_radius_all(int(px))
		ps.set_border_width_all(2)
		ps.border_color = Color(Pal.BARK, 0.22)
		ps.content_margin_left = pad; ps.content_margin_right = pad
		ps.content_margin_top = pad; ps.content_margin_bottom = pad
		plate.add_theme_stylebox_override("panel", ps)
	plate.add_child(make_icon(id, icon_px))
	return plate

## --- the HOME BUTTON: the icon button shared by the home page's side rail + bottom bar ------------
## ONE configurable atom: an authored disc or code-drawn paper tile carrying a CENTRED icon, an
## OPTIONAL caption tab beneath, and an OPTIONAL engine-drawn SPARKLE (a soft pulsing glow + drifting
## twinkles — no baked FX). Badges are attached by the caller (Look.attach_badge) since their visibility
## is game-state driven. The side rail AND the bottom nav both build through this, so a workbench tweak
## (size · icon scale · caption · sparkle amount) flows to both.
##   spec (per-instance content): icon (id) OR icon_rel (a direct kit-relative png, for a mark outside the
##     icon_<id> convention — e.g. the map back arrow) · caption (visible tab text, "" = none) ·
##     action (Callable) · sparkle (bool) · enabled (bool).
##   opts (shared STYLE — see home_button_opts_from_config): px · shell · icon_scale (0..1) ·
##     caption_font · caption_gap · glow (0..1) · twinkle (0..1).
const HOME_SHELL := "shared/disc_round.png"

static func home_button(spec: Dictionary, opts: Dictionary = {}) -> Button:
	var px: float = float(opts.get("px", 140.0))
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(px, px)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.disabled = not bool(spec.get("enabled", true))
	if spec.has("tooltip"):
		b.tooltip_text = String(spec.get("tooltip", ""))
	var meta_icon := String(spec.get("icon_id", spec.get("icon", "")))
	if meta_icon != "":
		b.set_meta("icon_id", meta_icon)
	# the shell shape: "disc" (the round cream/gold sprite, the default) or "rect" (a code-drawn rounded paper
	# tile — the home rail + the Map button). The rect shell stacks its icon + caption INSIDE the tile; the
	# disc keeps the icon centred with the caption as an overflow tab beneath it.
	var shape := String(opts.get("shape", "disc"))
	# Disc shells remain authored sprites. Rect shells are code-drawn rounded squares filled by a flat paper
	# texture selected with `surface_role`, so their geometry never comes from a scaled/cut background.
	# `fill_alpha` (workbench 0..100) makes the paper surface read translucent over the scene.
	var shell_rel := String(opts.get("shell", HOME_SHELL))
	var shell_tint: Color = opts.get("shell_tint", Color.WHITE)
	var fill_a := clampf(float(opts.get("fill_alpha", 100)) / 100.0, 0.0, 1.0)
	shell_tint = Color(shell_tint.r, shell_tint.g, shell_tint.b, shell_tint.a * fill_a)
	var corner := int(round(px * (0.22 if shape == "rect" else 0.5)))
	if shape == "rect":
		var surface_role := String(opts.get("surface_role", "cream"))
		var surface: Dictionary = PAPER_SURFACES.get(surface_role, PAPER_SURFACES["cream"])
		var surface_fill: Color = surface.get("fill", Pal.CREAM)
		_apply_rounded_paper_surface(
			b,
			String(surface.get("texture", "texture_cream.png")),
			surface_fill,
			float(corner),
			Vector4.ZERO,
			2.0,
			fill_a
		)
	else:
		var shell: Texture2D = shell_texture(shell_rel, opts.get("badge", {}))
		for st_name in ["normal", "hover", "pressed", "disabled"]:
			if shell != null:
				var stx := StyleBoxTexture.new()
				stx.texture = shell
				if st_name == "pressed":
					stx.modulate_color = shell_tint * Color(0.9, 0.9, 0.9)
				elif st_name == "disabled":
					stx.modulate_color = shell_tint * Color(0.72, 0.72, 0.72)
				else:
					stx.modulate_color = shell_tint
				b.add_theme_stylebox_override(st_name, stx)
			else:
				var s := StyleBoxFlat.new()
				s.bg_color = shell_tint if opts.has("shell_tint") else Color(Pal.CREAM, 0.95 * fill_a)
				s.set_corner_radius_all(corner)
				s.set_border_width_all(3)
				s.border_color = Pal.STRAW
				b.add_theme_stylebox_override(st_name, s)
	# the DROP SHADOW behind the button shell (show_behind_parent): the SHARED box-shadow, SHAPED to the
	# button — a rounded RECT for the rail / Map badges (corner = the badge corner) or a CIRCLE for disc
	# buttons (corner = px/2). On only when the Shadow toggle is set; opts.shadow_params is the single look.
	if bool(opts.get("shadow", false)):
		var sh: Panel = _meadow_shadow_rect(Look.shape_corner(b, float(corner)), opts.get("shadow_params", {})) if shape == "rect" else _meadow_shadow_circle(Look.shape_corner(b, px), opts.get("shadow_params", {}))
		sh.show_behind_parent = true                          # draw under the button's textured shell
		b.add_child(sh)
	# the SPARKLE sits BEHIND the icon (added first → drawn under it), only if asked AND tuned > 0.
	if bool(spec.get("sparkle", false)):
		var glow: float = float(opts.get("glow", 0.0))
		var tw: float = float(opts.get("twinkle", 0.0))
		if glow > 0.0 or tw > 0.0:
			b.add_child(_sparkle_overlay(px, glow, tw))
	# the kit icon, centred on the disc (mouse-transparent so the Button is the only hit surface). The icon
	# gets the SHARED global polish (make_icon → _icon_tex's defringe + feather) — its own clean recipe.
	var icwrap := CenterContainer.new()
	icwrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_px := px * float(opts.get("icon_scale", 0.5))
	# A caller-supplied `icon_node` (any Control) wins outright — the Bag well passes the most-recent
	# stashed item's piece view so the disc shows the held item INSTEAD of the satchel (a true swap, not a
	# tiny overlay). Otherwise icon_rel (a direct kit-relative png) wins over the icon id — same polish +
	# square layout either way.
	var icon_rel := String(spec.get("icon_rel", ""))
	var icon_node: Control
	if spec.get("icon_node") is Control:
		icon_node = spec.get("icon_node")
	elif icon_rel != "":
		icon_node = _icon_rect(clean_tex_path(Look.kit(icon_rel), 192), icon_px)
	else:
		icon_node = make_icon(String(spec.get("icon", "")), icon_px)
	if icon_node != null:
		icwrap.add_child(icon_node)
	var caption := String(spec.get("caption", ""))
	if shape == "rect":
		if caption == "":
			icwrap.set_anchors_preset(Control.PRESET_FULL_RECT)
			b.add_child(icwrap)
		else:
			# RECT badge: icon (upper) + caption (lower) stacked INSIDE the rounded rect, padded off the edge —
			# the rail's "icon over label" tiles and the Map button's "Map" plate (matches the ui_mock2 chrome).
			var vb := VBoxContainer.new()
			vb.set_anchors_preset(Control.PRESET_FULL_RECT)
			vb.alignment = BoxContainer.ALIGNMENT_CENTER
			vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var rpad := px * float(opts.get("rect_pad", 0.13))
			vb.offset_left = rpad; vb.offset_right = -rpad
			vb.offset_top = rpad; vb.offset_bottom = -rpad
			icwrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			icwrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
			vb.add_child(icwrap)
			# ink by default; a DARK paper role (slate) passes a light colour so the caption still reads.
			# (the label's outline is off — a solid badge IS the contrast, the panel-text law.)
			var cl := _kit_label(caption, int(opts.get("caption_font", FS.FINE)), opts.get("caption_color", Pal.INK))
			cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			vb.add_child(cl)
			b.add_child(vb)
	else:
		icwrap.set_anchors_preset(Control.PRESET_FULL_RECT)
		b.add_child(icwrap)
		# the OPTIONAL caption tab, centred just beneath the disc (overflows into the gap below)
		if caption != "":
			var cap_font := int(opts.get("caption_font", FS.FINE))
			var cap_pad_x := float(opts.get("caption_pad_x", 30.0))
			var cap_pad_y := float(opts.get("caption_pad_y", 8.0))
			var capwrap := CenterContainer.new()
			capwrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			capwrap.anchor_left = 0.0; capwrap.anchor_right = 1.0
			capwrap.anchor_top = 1.0; capwrap.anchor_bottom = 1.0
			capwrap.offset_top = float(opts.get("caption_gap", 4.0))
			# the box just clears the ribbon: the font plus its own top+bottom padding (was a fixed +22 band)
			capwrap.offset_bottom = capwrap.offset_top + cap_font + 2.0 * cap_pad_y
			var cap := Look.title_ribbon(caption, cap_font)
			# override the SHARED ribbon margins with the home button's OWN tunable padding (workbench knobs)
			var csb := cap.get_theme_stylebox("panel")
			if csb is StyleBoxFlat:
				var csbd: StyleBoxFlat = (csb as StyleBoxFlat).duplicate()
				csbd.content_margin_left = cap_pad_x
				csbd.content_margin_right = cap_pad_x
				csbd.content_margin_top = cap_pad_y
				csbd.content_margin_bottom = cap_pad_y
				cap.add_theme_stylebox_override("panel", csbd)
			cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if cap.get_child_count() > 0:
				(cap.get_child(0) as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
			capwrap.add_child(cap)
			b.add_child(capwrap)
	# expose the icon wrapper + its sizing so a caller can swap the icon in place later (the Bag well
	# replaces the satchel with the stashed item, and restores it when emptied) without rebuilding the button.
	b.set_meta("icon_wrap", icwrap)
	b.set_meta("icon_px", icon_px)
	# the OPTIONAL count overlay — a small "x/y" label riding INSIDE the disc (the Bag well's slot count).
	# Centred over the disc, then nudged by count_dx / count_dy (workbench knobs); the caller updates its
	# text live via the exposed `count_label` meta. Any round button COULD carry one, but only the bag
	# supplies text today — moving the count onto the SHARED disc keeps the bag cell the same px box as the
	# rest of the bar (it used to sit in a taller stack below the disc, breaking the bottom-bar alignment).
	var count := String(spec.get("count", ""))
	if count != "":
		var cnt := Label.new()
		cnt.text = count
		cnt.add_theme_font_size_override("font_size", int(opts.get("count_font", FS.BODY)))
		cnt.add_theme_color_override("font_color", Pal.CREAM)
		cnt.add_theme_color_override("font_outline_color", Color("#4A3B24"))
		cnt.add_theme_constant_override("outline_size", 6)
		cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cnt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cnt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cnt.set_anchors_preset(Control.PRESET_FULL_RECT)   # fills the disc; the equal offsets below SHIFT the centred text
		var cdx := float(opts.get("count_dx", 0.0))
		var cdy := float(opts.get("count_dy", 38.0))
		cnt.offset_left = cdx; cnt.offset_right = cdx
		cnt.offset_top = cdy; cnt.offset_bottom = cdy
		b.add_child(cnt)
		b.set_meta("count_label", cnt)
	Look.add_press_juice(b)
	if spec.has("action") and (spec.get("action") as Callable).is_valid():
		b.pressed.connect(spec.get("action"))
	return b

## The engine-drawn SPARKLE overlay: a soft additive GLOW that gently breathes + drifting 4-point
## TWINKLES (a continuous GPUParticles2D), both code-generated (no baked art). glow / twinkle are 0..1
## amounts (the workbench sliders).
static func _sparkle_overlay(px: float, glow: float, twinkle: float, tint: Color = Pal.STRAW, size_mult: float = 1.7) -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if glow > 0.0 and size_mult > 0.0:
		var hsz := px * size_mult
		var gtex := _glow_texture(tint)
		# one soft radial halo, twice: a NORMAL-blend warm tint first (so the glow reads on LIGHT
		# backgrounds — additive has no headroom on the near-white disc / bright map), then the ADDITIVE
		# bloom on top (which pops on DARK backgrounds: the workbench panel, dusk maps). g is 0..1.
		var make_halo := func(additive: bool, alpha: float) -> TextureRect:
			var h := TextureRect.new()
			h.texture = gtex
			h.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			h.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			h.mouse_filter = Control.MOUSE_FILTER_IGNORE
			h.custom_minimum_size = Vector2(hsz, hsz)
			h.size = Vector2(hsz, hsz)
			h.position = Vector2((px - hsz) / 2.0, (px - hsz) / 2.0)
			if additive:
				var m := CanvasItemMaterial.new()
				m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
				h.material = m
			h.modulate = Color(1, 1, 1, clampf(glow, 0.0, 1.0) * alpha)
			root.add_child(h)
			return h
		make_halo.call(false, 0.45)                              # warm tint (light-bg readable)
		var halo: TextureRect = make_halo.call(true, 1.0)        # additive bloom (dark-bg pop)
		halo.pivot_offset = Vector2(hsz, hsz) / 2.0
		halo.tree_entered.connect(func() -> void:
			var tw := halo.create_tween().set_loops()
			tw.tween_property(halo, "scale", Vector2(1.08, 1.08), 1.1).set_trans(Tween.TRANS_SINE)
			tw.tween_property(halo, "scale", Vector2(0.93, 0.93), 1.1).set_trans(Tween.TRANS_SINE))
	if twinkle > 0.0:
		var p := GPUParticles2D.new()
		p.position = Vector2(px / 2.0, px / 2.0)
		p.texture = _star_texture()
		p.amount = maxi(3, int(round(twinkle * 16.0)))     # the slider sets the twinkle DENSITY
		p.lifetime = 1.6
		p.preprocess = 1.2                                  # start mid-cycle so the first frame already twinkles
		p.randomness = 1.0
		p.local_coords = false
		var mat := ParticleProcessMaterial.new()
		mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
		mat.emission_ring_axis = Vector3(0, 0, 1)           # ring lies in the screen plane
		mat.emission_ring_radius = px * 0.52
		mat.emission_ring_inner_radius = px * 0.34
		mat.emission_ring_height = 0.0
		mat.direction = Vector3(0, 0, 0)
		mat.spread = 0.0
		mat.gravity = Vector3.ZERO
		mat.initial_velocity_min = 2.0
		mat.initial_velocity_max = 12.0                     # a gentle outward drift
		mat.angular_velocity_min = -40.0
		mat.angular_velocity_max = 40.0
		mat.scale_min = px * 0.0024
		mat.scale_max = px * 0.0052
		var ramp := Gradient.new()                          # twinkle in → out: a 0→1→0 alpha ramp over life
		ramp.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
		ramp.colors = PackedColorArray([Color(1, 0.86, 0.5, 0.0), Color(1, 0.84, 0.42, 1.0), Color(1, 0.86, 0.5, 0.0)])
		var gt := GradientTexture1D.new()
		gt.gradient = ramp
		mat.color_ramp = gt
		p.process_material = mat
		root.add_child(p)
		p.emitting = true
	return root

## A code-generated SPARKLE sprite — a hot round core, 4 main points, and 4 short diagonal rays, all
## warm-white so the gold color-ramp tints it (see _sparkle_overlay). There is NO dark outline: the old
## dark contrast-rim read as a "hollow plus" on the light cream unlock disc — the warm fill washed into
## the cream, leaving only the dark rim visible (a plus-shaped outline). Light-background contrast now
## comes from the gold GLOW halo drawn behind the twinkles (the disc runs glow≈0.8) plus the saturated
## ramp; on dark backgrounds the bright core simply pops. The diagonal rays make it read as a twinkle,
## not a bare plus. Cached.
static var _star_tex: Texture2D = null
static func _star_texture() -> Texture2D:
	if _star_tex != null:
		return _star_tex
	var n := 48
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := n / 2.0
	const SQ := 0.7071068                                       # 1/sqrt(2): rotate into the diagonal frame
	for y in n:
		for x in n:
			var dx: float = (x - c + 0.5) / c
			var dy: float = (y - c + 0.5) / c
			var ax: float = absf(dx)
			var ay: float = absf(dy)
			var dist: float = sqrt(dx * dx + dy * dy)
			# the 4 main points (axis-aligned) — a touch wider than before (taper 6, was 7) so the fill
			# reads as a body, not just a hairline edge that vanishes on cream.
			var hx: float = clampf(1.0 - ax, 0.0, 1.0) * clampf(1.0 - ay * 6.0, 0.0, 1.0)
			var vy: float = clampf(1.0 - ay, 0.0, 1.0) * clampf(1.0 - ax * 6.0, 0.0, 1.0)
			# 4 short diagonal rays (the axis frame rotated 45°) — shorter + fainter, so the whole thing
			# reads as a SPARKLE/twinkle rather than a plus sign.
			var ux: float = (dx + dy) * SQ
			var uy: float = (dx - dy) * SQ
			var d1: float = clampf(1.0 - absf(ux) * 1.8, 0.0, 1.0) * clampf(1.0 - absf(uy) * 12.0, 0.0, 1.0)
			var d2: float = clampf(1.0 - absf(uy) * 1.8, 0.0, 1.0) * clampf(1.0 - absf(ux) * 12.0, 0.0, 1.0)
			var diag: float = maxf(d1, d2) * 0.5
			# a hot round core where the rays meet — a solid bright centre reads as a shine, never hollow.
			var core: float = clampf(1.0 - dist * 2.0, 0.0, 1.0)
			var a: float = clampf(maxf(maxf(maxf(hx, vy), diag), core * core), 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 0.97, 0.86, a))      # warm-white; gold ramp tints, glow halo carries it on light bg
	_star_tex = ImageTexture.create_from_image(img)
	return _star_tex

## A code-generated radial bloom (long soft falloff) — the glow halo, tinted `gold` (defaults to the
## honey straw). Cached PER COLOR, so the workbench can recolor the unlockable glow live without
## rebuilding the texture every frame, while the default-tint callers (home buttons, discovery cell)
## share one cached straw bloom.
static var _glow_tex_cache: Dictionary = {}
static func _glow_texture(gold: Color = Pal.STRAW) -> Texture2D:
	var key := gold.to_rgba32()
	if _glow_tex_cache.has(key):
		return _glow_tex_cache[key]
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := n / 2.0
	for y in n:
		for x in n:
			var d: float = Vector2((x - c + 0.5) / c, (y - c + 0.5) / c).length()
			var a: float = clampf(1.0 - d, 0.0, 1.0)
			a = a * a * a                                    # tight core, long feathered falloff
			img.set_pixel(x, y, Color(gold.r, gold.g, gold.b, a))
	var tex := ImageTexture.create_from_image(img)
	_glow_tex_cache[key] = tex
	return tex

## A read-only CREAM chip showing an arbitrary icon + amount text (e.g. "💧 60", "🪙 100", "Tier 3") — the
## SAME cream/static pill_button variant reward_chip uses for a single currency, but for ANY icon/text, so
## the info sheet can show a line item's amount on a mail card with NO Claim button beside it.
static func amount_chip(icon_id: String, text: String, btn_opts: Dictionary = {}) -> Button:
	var o := btn_opts.duplicate()
	o["bg"] = "cream"
	o.erase("art_rel")                 # cream by role — never a chosen (green) badge
	o["icon"] = icon_id
	o["static"] = true                 # a display chip: looks like the button, not pressable
	o["enabled"] = true
	return pill_button(text, o)

## A mail card (mockup image 2): a plated icon + title/body + a reward pill + a Claim — the reward pill
## and Claim are BOTH the shared pill_button, so a Button knob change propagates here. icon_badge picks
## the circular badge sprite behind the left icon (see ICON_BADGES). The INFO variant carries a read-only
## `chip` ({icon, text}) instead of a reward: the amount shows as a cream amount_chip with NO Claim.
# The cut-paper dialog RE-SKIN assets (extracted from the mail mock). Absent files → the drawn fallback.
const MAIL_SKIN := "res://games/grove/assets/ui/dialogs/mail/"
static func _mail_skin_tex(key: String) -> Texture2D:
	var p := MAIL_SKIN + key + ".png"
	return load(p) as Texture2D if ResourceLoader.exists(p) else null

## (The baked `_skin_button` — the extracted GREEN/CREAM cut-paper sprite wearing a TextSpriteButton
## label — is retired: mail Claim / Claim All now build the SHARED pill_button, whose deckled edge is
## drawn in code and tuned from the workbench Button element.)

static func mail_card(entry: Dictionary, title_font: int = FS.FINE, body_font: int = FS.FINE, btn_opts: Dictionary = {}, icon_badge: String = "shared/disc_round.png") -> Control:
	# The row panel is a plain flat paper surface — the SAME cut-paper construction the buttons/chips wear
	# (a cream fill + thin PAPER_EDGE hairline + a texture_cream grain layer), matching the mocks' clean
	# card rows. The baked kit/mail_card.png nine-patch (an embossed border + a pink underline artifact) is
	# retired for it; the card keeps its padding (CARD_PAD) and layout, only the background changes.
	# RESKIN: the card wears the SAME code-drawn torn cut-paper edge as the dialog frame + settings rows —
	# a deckled CREAM sheet (tiled paper fibre + warm rim + shape-true drop shadow) drawn behind the content,
	# mirroring _row_panel. The old baked mail_card.png (with its embossed border + hero-icon well) is retired;
	# the icon now seats on the clean deckled cream. The PanelContainer stays the root (transparent), so the
	# card's node identity is unchanged and it stacks the backdrop + a padded host into one rect.
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())   # transparent: the CutPaperPanel behind is the face
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# the reward-card sheet wears the SHARED cut-paper edge (Kit.CUT_PAPER_KNOBS) in ITS OWN tint — read from
	# the `mail_card` config block, or overridden LIVE by the workbench via btn_opts.mail_cp / .mail_tint. The
	# warm cut-edge rim is derived from the tint (a shade darker) so a recolour carries the edge with it. This
	# is the ONE spot the reward card's edge is applied; a new CUT_PAPER_KNOBS knob flows here automatically.
	var mail_cp: Dictionary = btn_opts.get("mail_cp", {})
	if mail_cp.is_empty():
		mail_cp = cut_paper_opts_from_config(load_config(CONFIG_PATH), "mail_card", MAIL_CP_DEFAULTS)
	var tint: Color = btn_opts.get("mail_tint", MAIL_TINT_DEFAULT)
	var cp = load(CUT_PAPER).new()      # the deckled sheet, laid out to fill the panel rect
	cp.configure(mail_cp, tint, tint.darkened(0.14), cut_paper_tile())   # the ONE shared edge applier
	cp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(cp)
	# content host: pad the row IN from the deckled edge so text/icon never touch the tear (CARD_PAD + the
	# deckle inset). The panel stacks both children into the same rect, so the host margins are the ONLY inset.
	var host := MarginContainer.new()
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inset := int(cp.content_inset())
	host.add_theme_constant_override("margin_left", int(CARD_PAD.x) + inset)
	host.add_theme_constant_override("margin_right", int(CARD_PAD.z) + inset)
	host.add_theme_constant_override("margin_top", int(CARD_PAD.y))
	host.add_theme_constant_override("margin_bottom", int(CARD_PAD.w))
	panel.add_child(host)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	host.add_child(row)

	# LEFT: the LARGE hero icon (mock v1) — the reward art itself, unplated, seated big at the card's left
	# and vertically centred over the whole row. `icon_px` is workbench-tunable via btn_opts.card_icon_px.
	var icon_px := float(btn_opts.get("card_icon_px", 108.0))
	var ic_wrap := MarginContainer.new()
	ic_wrap.add_theme_constant_override("margin_top", 6)
	ic_wrap.add_theme_constant_override("margin_bottom", 6)
	ic_wrap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ic_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic_wrap.add_child(make_icon(String(entry.get("icon", "star")), icon_px))
	row.add_child(ic_wrap)

	# RIGHT: the text column — title over body, then the reward+Claim action row beneath (mock v1 stacks
	# the reward cards + the big green Claim UNDER the copy, not inline beside it).
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 6)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	var title := _kit_label(String(entry.get("title", "")), title_font, Pal.INK)
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS   # clip+… → never forces card wider
	text.add_child(title)
	var body := _kit_label(String(entry.get("body", "")), body_font, Color(Pal.BARK, 0.95))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART             # wrap → never forces card wider
	text.add_child(body)

	# The reward affordance: a row of SMALL per-currency reward cards on the left + (when unclaimed) the
	# big GREEN Claim on the right, both under the copy. A claimed gift swaps the Claim for a quiet
	# "Claimed" tag; a plain note (no reward) shows neither. The Claim is green BY ROLE.
	var reward: Dictionary = entry.get("reward", {})
	if _reward_total(reward) > 0:
		var action := HBoxContainer.new()
		action.add_theme_constant_override("separation", 12)
		action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		action.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cards := _reward_cards(reward, btn_opts)
		cards.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		action.add_child(cards)
		var gap := Control.new()
		gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		action.add_child(gap)
		if bool(entry.get("claimed", false)):
			var done := Label.new()
			done.text = String(entry.get("claimed_text", "Claimed"))
			done.add_theme_font_size_override("font_size", FS.FINE)   # "Claimed" tag — readable next to the card body
			done.add_theme_color_override("font_color", Color(Pal.LEAF.darkened(0.1), 0.95))
			done.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			done.mouse_filter = Control.MOUSE_FILTER_IGNORE
			action.add_child(done)
			panel.modulate = Color(1, 1, 1, 0.7)
		else:
			# the big green Claim — the SHARED pill_button (code-drawn cut-paper edge, tuned in the workbench),
			# pushed up a font tier + a roomier pad/corner (mock v1's Claim reads much larger than the reward cards).
			var claim_font := int(btn_opts.get("card_claim_font", maxi(FS.BODY, title_font)))
			var claim_opts := button_opts_from_config(load_config(CONFIG_PATH))   # the shared button settings (deckle / rim / shadow)
			claim_opts.merge(btn_opts, true)                                      # a caller override wins over config
			claim_opts["bg"] = "green"
			claim_opts["font"] = claim_font   # a tier over the reward numbers (mock v1's Claim reads noticeably larger)
			claim_opts["pad_scale"] = float(btn_opts.get("card_claim_pad", 1.3))
			# corner FOLLOWS the shared Button corner (already in claim_opts from button_opts_from_config);
			# a caller may still force card_claim_corner, but absent one the claim tracks the Button-group knob
			# instead of the old dead 20 pin (which nothing set, so it silently froze the mail Claim's corner).
			claim_opts["corner"] = float(btn_opts.get("card_claim_corner", claim_opts.get("corner", 20.0)))
			var claim := pill_button(String(btn_opts.get("text", "Claim")), claim_opts)
			claim.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var on_claim: Callable = entry.get("on_claim", Callable())
			if on_claim.is_valid():
				claim.pressed.connect(func() -> void: on_claim.call())
			action.add_child(claim)
		text.add_child(action)
	else:
		# the INFO variant: a read-only amount chip (icon + text) and NO Claim button. A plain note (no
		# reward, no chip) adds neither, exactly as before.
		var chip_spec: Dictionary = entry.get("chip", {})
		var chip_text := String(chip_spec.get("text", ""))
		if chip_text != "":
			var info_row := HBoxContainer.new()
			info_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var ac := amount_chip(String(chip_spec.get("icon", "")), chip_text, btn_opts)
			ac.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			info_row.add_child(ac)
			text.add_child(info_row)
	# (no separate grain layer — the deckled CutPaperPanel already tiles the cream paper fibre as its fill.)
	return panel

## The mock's per-reward CURRENCY CARDS: one SMALL cream amount_chip per currency present, laid out in a
## row (coin · water · gem). Each is the shared cream amount_chip (icon + count), so a Button-style knob
## change flows here too. Used for the mail card reward line — a claimed multi-currency gift reads as
## discrete little cards, matching the mock, instead of one stacked pill.
static func _reward_cards(reward: Dictionary, btn_opts: Dictionary = {}) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for pr in [["coin", int(reward.get("coins", 0))], ["water", int(reward.get("water", 0))], ["gem", int(reward.get("gems", 0))]]:
		if int(pr[1]) > 0:
			var chip := amount_chip(String(pr[0]), str(int(pr[1])), btn_opts)
			chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			row.add_child(chip)
	return row

## A TOGGLE CARD — a card type (sibling of mail_card / daily_card): one persisted setting as a row,
## its name on the LEFT and the shared Look.toggle_switch on the RIGHT, riding the SAME kit/mail_card.png
## parchment surface the mail rows use (a flat cream pill when card_art is off). The settings dialog
## stacks one per flag. Game-state-agnostic: `entry` carries label + value + on_toggle, so the workbench
## previews it (a local flip) and the GAME drives it from Save — the kit never reads game state itself.
## Rich rows opt into the mail rhythm with icon + title/body + a cream coin chip before the switch.
##   entry: label/title/body/icon/cost · value (bool, current state) · on_toggle (Callable(on: bool)).
##   opts:  label_font/body_font (px) · switch_h (px, the switch height) · card_art (bool, parchment vs pill).
static func toggle_card(entry: Dictionary, opts: Dictionary = {}) -> Control:
	var label_font := int(opts.get("label_font", FS.BODY))
	var body_font := int(opts.get("body_font", maxi(13, label_font - 4)))
	var switch_h := float(opts.get("switch_h", 44.0))
	var rich := entry.has("title") or entry.has("body") or entry.has("icon") or entry.has("cost")
	# the SAME shared cut-paper row surface every settings row wears (toggle · info · action) — see _row_panel.
	var panel := _row_panel(opts.get("cp", {}), opts.get("row_fill", ROW_SAGE), opts.get("row_rim", ROW_SAGE_EDGE))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12 if rich else 18)
	_row_body(panel).add_child(row)
	if rich:
		var ic_wrap := MarginContainer.new()
		ic_wrap.add_theme_constant_override("margin_top", 8)
		ic_wrap.add_theme_constant_override("margin_bottom", 8)
		ic_wrap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ic_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic_wrap.add_child(plated_icon(String(entry.get("icon", "leaf")), float(opts.get("icon_px", 52.0))))
		row.add_child(ic_wrap)

		var text := VBoxContainer.new()
		text.add_theme_constant_override("separation", 1)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(text)

		var title := _kit_label(String(entry.get("title", entry.get("label", ""))), label_font, Pal.INK)
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		text.add_child(title)

		var body := _kit_label(String(entry.get("body", "")), body_font, Color(Pal.BARK, 0.95))
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.add_child(body)

		if entry.has("cost"):
			var cost := amount_chip("coin", "%d" % int(entry.get("cost", 0)), {
				"art": true,
				"font": int(opts.get("cost_font", FS.FINE)),
				"icon_size": int(opts.get("cost_icon", 22)),
				"pad_scale": float(opts.get("cost_pad", 0.72)),
			})
			cost.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(cost)
	else:
		row.add_child(_row_name_label(String(entry.get("label", "")), label_font))

	# the switch is the SHARED Look.toggle_switch — its rugged track + knob wear the SAME cut-paper edge
	# knob set as the row (passed through here). The callback fires the entry's on_toggle (game persists).
	var on_toggle: Callable = entry.get("on_toggle", Callable())
	var fire := func(on: bool) -> void:
		if on_toggle.is_valid():
			on_toggle.call(on)
	var sw := Look.toggle_switch(bool(entry.get("value", false)), fire, switch_h, opts.get("cp", {}))
	sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(sw)
	# Make the WHOLE card tap = exactly ONE switch flip. One physical tap can deliver duplicate
	# press events here, so there are TWO guards:
	#   1) act on the mouse-button press only, never the screen-touch — emulate_touch_from_mouse
	#      pairs every click with a touch; and
	#   2) at most one flip per process frame — on desktop emulate_mouse_from_touch ALSO re-converts
	#      that emulated touch back into a SECOND mouse-button press in the same frame, which guard
	#      (1) cannot catch (both are mouse buttons). The duplicates share one input flush => one
	#      frame, so the frame guard collapses them; two genuine taps land on different frames and
	#      both count. Without (2) the switch flipped twice (net no-op) and the setting "wouldn't
	#      save" / "reset on restart" (the Sounds-toggle bug on the Mac build).
	panel.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
			var frame := Engine.get_process_frames()
			if int(panel.get_meta("tap_frame", -1)) != frame:
				panel.set_meta("tap_frame", frame)
				sw.pressed.emit()
			panel.accept_event())
	return panel

## The shared row surface for the settings card family — the SAME kit/mail_card.png parchment (or the
## flat cream pill when card_art is off) toggle_card rides, factored out so info/action rows match it.
## The shared SETTINGS-ROW surface — one flat cut-paper tile for every row (toggle · info · action), so
## the whole dialog reads as one clean cut-paper stack. A soft sage fill + a thin PAPER_EDGE hairline +
## the shared drop shadow, matching the mail cards + the daily cells. The old kit/mail_card.png nine-patch
## (an embossed border + a pink underline artifact) is retired. (`_unused` kept for call-site compatibility.)
const SETTINGS_ROW_TEX := "res://games/grove/assets/ui/dialogs/settings/settings_row.png"
const CUT_PAPER := "res://engine/scripts/ui/cut_paper.gd"
const ROW_SAGE := Color("#DCE7C8")        # the settings-row sage fill (daily-cell family)
const ROW_SAGE_EDGE := Color("#BFD09E")   # a deeper sage for the torn cut-edge line

## THE single definition of the cut-paper EDGE knob set — the deckled-paper look shared by the button,
## the dialog frame, and the settings toggle bar (row + switch). Each entry is BOTH a row in the workbench
## inspector (via _cut_paper_section) AND a field the reader parses + the applier consumes. Add a knob here
## → it appears in every component's inspector and is read + applied everywhere, no per-component edits.
## `key` = the config/opts key; `kind` = "toggle" | "slider" | "color"; sliders carry min/max; `freq` marks
## a percent slider the reader divides by 100 (CutPaperPanel wants a raw frequency); a "color" knob saves a
## 6-hex string and the reader parses it to a Color. Per-component VALUES live in each component's own config
## block; this only fixes the SET + ranges + fallback defaults.
const CUT_PAPER_KNOBS := [
	{"key": "deckle",      "kind": "toggle", "label": "Cut-paper edge", "default": true},
	{"key": "corner",      "kind": "slider", "label": "Corner",      "min": 0, "max": 60, "default": 16},
	{"key": "deckle_amp",  "kind": "slider", "label": "Deckle amp",  "min": 0, "max": 20, "default": 5},
	{"key": "deckle_freq", "kind": "slider", "label": "Deckle freq", "min": 1, "max": 20, "default": 5, "freq": true},
	{"key": "rim_width",   "kind": "slider", "label": "Rim width",   "min": 0, "max": 8,  "default": 2},
	{"key": "rim_color",   "kind": "color",  "label": "Rim color",   "default": "E7D6BC"},
	{"key": "edge_shadow", "kind": "toggle", "label": "Edge shadow", "default": true},
	# the drop-shadow itself is tunable: how far it reaches below the sheet (px) and its per-copy darkness
	# (a percent → alpha). Both only bite when Edge shadow is on. CutPaperPanel.configure consumes them.
	{"key": "shadow_reach",    "kind": "slider", "label": "Shadow reach",    "min": 0, "max": 40, "default": 10},
	{"key": "shadow_strength", "kind": "slider", "label": "Shadow strength", "min": 0, "max": 20, "default": 5},
	{"key": "shadow_blur",     "kind": "slider", "label": "Shadow blur",     "min": 0, "max": 100, "default": 55},
	# the AMBIENT halo (CutPaperPanel._draw_edge_halo): the same shadow rung around EVERY edge instead of
	# dropped below the sheet — the only shadow a surface bled off the screen edge can show. `halo_reach` is
	# the reach in px (0 = off, so every existing surface is untouched); `halo_strength` the contact alpha.
	{"key": "halo_reach",      "kind": "slider", "label": "Halo reach",     "min": 0, "max": 40,  "default": 0},
	{"key": "halo_strength",   "kind": "slider", "label": "Halo strength",  "min": 0, "max": 80,  "default": 30},
	# PAPER THICKNESS (CutPaperPanel._draw_bevel): a lit/shaded band inside the rim so the sheet reads as a
	# slab. Depth in px (0 = off) and peak alpha (%).
	{"key": "bevel_px",        "kind": "slider", "label": "Bevel depth",     "min": 0, "max": 30,  "default": 0},
	{"key": "bevel_strength",  "kind": "slider", "label": "Bevel strength",  "min": 0, "max": 80,  "default": 35},
	# TAB FLARE (CutPaperPanel._tab_base): the trapezoid tab — how much WIDER the sheet's bottom edge reads
	# than its top, as a PERCENT (`freq` = "saved as a percent, normalized to a fraction here"). 0 = off.
	{"key": "flare",           "kind": "slider", "label": "Tab flare %",     "min": 0, "max": 30,  "default": 0, "freq": true},
	# EDGE FEATHER (CutPaperPanel._draw_feathered_face): antialiasing for the drawn silhouette, in px.
	# `draw_colored_polygon` computes no coverage, so a SMOOTH sheet's arc rasterizes as a stair-stepped
	# binary edge; a torn one hides it. 0 = off, which is every surface that keeps its deckle.
	{"key": "edge_feather",    "kind": "slider", "label": "Edge feather px", "min": 0, "max": 4,   "default": 0},
]

## Read the shared cut-paper knob set from a component's config `block` into a NORMALIZED opts dict
## (deckle_freq → raw frequency). `overrides` supplies per-component fallback defaults (e.g. the frame's
## bigger corner) for keys the block hasn't saved; the schema default is the final fallback. Legacy per-
## block aliases (the frame's old cut_paper / card_corner / frame_shadow keys) are accepted so saved
## configs migrate losslessly. The button, frame, and toggle bar all call this — one parser, no drift.
static func cut_paper_opts_from_config(cfg: Dictionary, block: String, overrides: Dictionary = {}) -> Dictionary:
	var d: Dictionary = cfg.get(block, {})
	var o := {}
	for knob in CUT_PAPER_KNOBS:
		var k: String = knob["key"]
		var fallback: Variant = overrides.get(k, knob["default"])
		var raw: Variant = d.get(k, _cut_paper_legacy(d, k, fallback))
		var kind := String(knob.get("kind", "slider"))
		if kind == "toggle":
			o[k] = bool(raw)
		elif kind == "color":
			o[k] = Color.from_string("#" + String(raw).lstrip("#"), Color.WHITE)
		elif bool(knob.get("freq", false)):
			o[k] = float(raw) / 100.0
		else:
			o[k] = float(raw)
	return o

## Back-compat: map a canonical cut-paper key onto a config block's OLD alias when the canonical key is
## absent (frame blocks saved before the keys were unified). New blocks use the canonical keys directly.
static func _cut_paper_legacy(d: Dictionary, key: String, fallback: Variant) -> Variant:
	match key:
		"deckle": return d.get("cut_paper", fallback)
		"corner": return d.get("card_corner", fallback)
		"edge_shadow": return d.get("frame_shadow", fallback)
	return fallback

## ── PAPER BACKER ─────────────────────────────────────────────────────────────────────────────────
## A SECOND, slightly larger cut-paper sheet behind a pill/band — the stacked-paper look (a tinted
## under-sheet peeking out past the cream face). Knobs (any block): backer (toggle) · backer_grow (px
## past the face on every side) · backer_tint (the under-sheet colour). The face's own edge shadow
## then falls onto this sheet, which carries the stack's drop shadow to the page.
## Returns the configured CutPaperPanel (caller adds it FIRST + show_behind_parent), or null when off.
static func paper_backer(face_size: Vector2, opts: Dictionary, face_cp: Dictionary = {}) -> Control:
	if not bool(opts.get("backer", false)):
		return null
	var CutPaper := load(CUT_PAPER)
	if CutPaper == null:
		return null
	var grow := maxf(0.0, float(opts.get("backer_grow", 8.0)))
	var cp: Dictionary = face_cp.duplicate()
	cp["corner"] = float(face_cp.get("corner", 24.0)) + grow
	# the under-sheet casts the stack's page shadow; the face's edge shadow separates the two layers.
	cp["edge_shadow"] = true
	var backer: Control = CutPaper.new()
	backer.name = "PaperBacker"
	backer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backer.show_behind_parent = true
	# Anchor to the parent's REAL rect (full-rect + `grow` bleed on every side), NOT the passed face_size:
	# the wallet pill fills its cluster slot (SIZE_EXPAND_FILL), so its runtime width is wider than the
	# nominal pill_w. A fixed-size backer would stay narrow behind a wide face (the width bug). CutPaper
	# repaints on resize (its `resized -> queue_redraw`), so the under-sheet tracks the face at any width.
	backer.set_anchors_preset(Control.PRESET_FULL_RECT)
	backer.offset_left = -grow
	backer.offset_top = -grow
	backer.offset_right = grow
	backer.offset_bottom = grow
	# NOTE: do not set `.size` here — full-rect anchors drive it from the parent, and an explicit size set
	# is rejected (and would clobber the offsets). CutPaper repaints on resize, so the first real layout
	# sizes and paints it correctly.
	backer.configure(cp, opts.get("backer_tint", Color("#E3D2B4")), null, cut_paper_tile())
	backer.corner = float(cp["corner"])
	return backer

## ── TORN CELL ────────────────────────────────────────────────────────────────────────────────────
## A fully CODE-DRAWN cut-paper slot cell: an OUTER rugged cream card (the shared CutPaperPanel edge) with
## an INNER rugged well cut into it (a second CutPaperPanel, inset) and a soft INNER shadow cast from the
## well's top edge (CutPaperInsetShadow). Everything below is workbench-tunable. Its OUTER edge reuses the
## shared CUT_PAPER_KNOBS (read from the "torn_cell" block); these are its OWN extra knobs.
const INSET_SHADOW := "res://engine/scripts/ui/cut_paper_inset_shadow.gd"
const TORN_CELL_KNOBS := [
	{"key": "cream_fill",      "kind": "color",  "label": "Card color",     "default": "F1E6D2"},
	# the OPEN cell's face style: ON = the green inner well cutout; OFF = the plain cream card (the
	# locked cell's face without the lock). One saved knob — every surface that builds torn cells
	# (main board, bag, tiers, residents, almanac) reads it through torn_cell_opts_from_config.
	{"key": "well",            "kind": "toggle", "label": "Green well",     "default": true},
	{"key": "well_fill",       "kind": "color",  "label": "Well color",     "default": "A6C486"},
	{"key": "inner_inset",     "kind": "slider", "label": "Well inset",     "min": 2,  "max": 40,  "default": 14},
	{"key": "inner_corner",    "kind": "slider", "label": "Well corner",    "min": 0,  "max": 50,  "default": 16},
	{"key": "inner_amp",       "kind": "slider", "label": "Well deckle amp", "min": 0, "max": 20,  "default": 4},
	{"key": "inner_freq",      "kind": "slider", "label": "Well deckle freq", "min": 1, "max": 20, "default": 6, "freq": true},
	{"key": "inner_rim",       "kind": "slider", "label": "Well rim width",  "min": 0,  "max": 8,   "default": 2},
	# the inner well's cut edge as a whole: OFF = a clean smooth well (no deckle wobble, no rim)
	{"key": "inner_edge",      "kind": "toggle", "label": "Well edge",       "default": true},
	{"key": "inner_shadow_h",        "kind": "slider", "label": "Inner shadow reach", "min": 0, "max": 60, "default": 26},
	{"key": "inner_shadow_strength", "kind": "slider", "label": "Inner shadow strength", "min": 0, "max": 60, "default": 30},   # percent -> alpha
	{"key": "inner_shadow_falloff",  "kind": "slider", "label": "Inner shadow falloff",  "min": 10, "max": 40, "default": 16}, # /10 -> curve
	{"key": "inner_shadow_tint",     "kind": "color",  "label": "Inner shadow tint", "default": "294654"},
	# the LOCKED state (plain cream card, no well): a centred lock icon with its own drop shadow.
	{"key": "lock_icon",            "kind": "option", "label": "Lock icon",           "default": "card"},   # which lock art (LOCK_ICON_PATHS) — the map-card keyhole is the house lock
	{"key": "lock_frac",            "kind": "slider", "label": "Lock size",           "min": 20, "max": 90, "default": 52},   # % of cell
	{"key": "lock_shadow_dy",       "kind": "slider", "label": "Lock shadow drop",    "min": 0,  "max": 24, "default": 6},   # px
	{"key": "lock_shadow_strength", "kind": "slider", "label": "Lock shadow strength", "min": 0, "max": 60, "default": 32},  # percent -> alpha
	# GENERATED PAPER SPRITES: ON = the cell face is the baked cut-paper sprite set (CELL_SPRITE_PATHS —
	# open/open-alt checker + locked/locked-deep), whose dimensional edge the code-drawn path can't match.
	# OFF = the code-drawn torn-cell face above. One knob; board, bag, tiers, residents all follow.
	{"key": "sprites",              "kind": "toggle", "label": "Paper sprites",       "default": true},
]

## The baked cut-paper cell faces (generated as one sheet so the four variants share material + light).
## open_alt is the checker mate of open; locked_deep is the receded interior lock (non-frontier).
## The art is generated SHADOW-FREE (guide §0) — the engine casts the cell's shadow.
const CELL_SPRITE_CAP := 256    # cells draw ~116-132px; 256 matches the shared UI-glyph runtime cap
const CELL_SPRITE_PATHS := {
	"open":        "res://games/grove/assets/ui/board/cell_paper_open.png",
	"open_alt":    "res://games/grove/assets/ui/board/cell_paper_open_alt.png",
	"locked":      "res://games/grove/assets/ui/board/cell_paper_locked.png",
	"locked_deep": "res://games/grove/assets/ui/board/cell_paper_locked_deep.png",
}

## The lock arts the LOCKED torn cell can wear (the lock_icon knob) — every lock sprite the game owns.
## "card" (ui/card/lock.png, the purple scalloped map-card keyhole) is THE house lock now — the same
## icon the maps gallery stamps on a locked page — so every locked surface reads with one mark.
const LOCK_ICON_PATHS := {
	"card":    "res://games/grove/assets/ui/card/lock.png",
	"padlock": "res://games/grove/assets/ui/kit/tiers_lock.png",
	"bag":     "res://games/grove/assets/ui/kit/bag_lock.png",
	"acorn":   "res://games/grove/assets/ui/meadow_v2/acorn_lock.svg",
	"flower":  "res://games/grove/assets/ui/meadow_v2/maps_lock_flower.png",
	"simple":  "res://games/grove/assets/ui/meadow_v2/icon_padlock.png",
}

## Read the `torn_cell` config block into the builder opts: the shared cut-paper edge for the OUTER card,
## plus this component's own inner-well + inner-shadow + fill knobs.
static func torn_cell_opts_from_config(cfg: Dictionary) -> Dictionary:
	var d: Dictionary = cfg.get("torn_cell", {}) if cfg is Dictionary else {}
	var o := {"outer": cut_paper_opts_from_config(cfg, "torn_cell", {"corner": 18, "deckle_amp": 5, "deckle_freq": 6})}
	for knob in TORN_CELL_KNOBS:
		var k: String = knob["key"]
		var raw: Variant = d.get(k, knob["default"])
		var kind := String(knob.get("kind", "slider"))
		if kind == "color":
			o[k] = Color.from_string("#" + String(raw).lstrip("#"), Color.WHITE)
		elif kind == "toggle":
			o[k] = bool(raw)
		elif kind == "option":
			o[k] = String(raw)
		elif bool(knob.get("freq", false)):
			o[k] = float(raw) / 100.0
		else:
			o[k] = float(raw)
	return o

## Build the code-drawn torn cell at `opts.cell_w × opts.cell_h`. Three layers: the outer cream cut-paper
## card, the inner green well (a second cut-paper, inset), and the well's top inner shadow.
static func torn_cell(opts: Dictionary) -> Control:
	var w := float(opts.get("cell_w", 120.0))
	var h := float(opts.get("cell_h", 120.0))
	var root := Control.new()
	root.name = "TornCell"
	root.custom_minimum_size = Vector2(w, h)
	root.size = Vector2(w, h)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# the OUTER rugged cream card (shared cut-paper edge)
	var outer_cp: Dictionary = opts.get("outer", {})
	var outer: Control = load(CUT_PAPER).new()
	outer.name = "TornCellOuter"
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.configure(outer_cp, opts.get("cream_fill", Color("#F1E6D2")), null, cut_paper_tile())
	outer.corner = float(outer_cp.get("corner", 18.0))
	root.add_child(outer)

	# LOCKED state: a plain cream card (no well) with a centred lock icon over its own drop shadow.
	# The lock_icon knob picks WHICH lock art (LOCK_ICON_PATHS); unknown names fall back to the padlock.
	if String(opts.get("state", "open")) == "locked":
		var lock_px := minf(w, h) * clampf(float(opts.get("lock_frac", 52.0)) / 100.0, 0.05, 1.0)
		var lx := (w - lock_px) * 0.5
		var ly := (h - lock_px) * 0.5
		var lock_path := String(LOCK_ICON_PATHS.get(String(opts.get("lock_icon", "card")), DIALOG_LOCK_PATH))
		if not ResourceLoader.exists(lock_path):
			lock_path = DIALOG_LOCK_PATH
		if ResourceLoader.exists(lock_path):
			var lock_tex: Texture2D = load(lock_path)
			var dy := float(opts.get("lock_shadow_dy", 6.0))
			var lsh := TextureRect.new()
			lsh.name = "TornCellLockShadow"
			lsh.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			lsh.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			lsh.texture = lock_tex
			lsh.modulate = Look.shadow_color(float(opts.get("lock_shadow_strength", 32.0)) / 100.0)
			lsh.position = Vector2(lx, ly + dy)
			lsh.size = Vector2(lock_px, lock_px)
			lsh.mouse_filter = Control.MOUSE_FILTER_IGNORE
			root.add_child(lsh)
			var lk := TextureRect.new()
			lk.name = "TornCellLock"
			lk.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			lk.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			lk.texture = lock_tex
			lk.position = Vector2(lx, ly)
			lk.size = Vector2(lock_px, lock_px)
			lk.mouse_filter = Control.MOUSE_FILTER_IGNORE
			root.add_child(lk)
		return root

	# OPEN state, plain style (Green well toggle OFF): the bare cream card — the locked cell's face
	# without the lock. No inner well, no inner shadow.
	if not bool(opts.get("well", true)):
		return root

	# OPEN state: the INNER rugged well, inset — its own tuned edge, no drop shadow (the outer card casts the cell's)
	var inset := float(opts.get("inner_inset", 14.0))
	var iw := maxf(1.0, w - inset * 2.0)
	var ih := maxf(1.0, h - inset * 2.0)
	var well_fill: Color = opts.get("well_fill", Color("#A6C486"))
	# Well edge OFF → a clean smooth well: no deckle wobble, no rim (the corner radius stays).
	var inner_edge := bool(opts.get("inner_edge", true))
	var inner_cp := {
		"deckle": true, "corner": float(opts.get("inner_corner", 16.0)),
		"deckle_amp": float(opts.get("inner_amp", 4.0)) if inner_edge else 0.0,
		"deckle_freq": float(opts.get("inner_freq", 0.06)),
		"rim_width": float(opts.get("inner_rim", 2.0)) if inner_edge else 0.0,
		"edge_shadow": false,
	}
	var inner: Control = load(CUT_PAPER).new()
	inner.name = "TornCellWell"
	inner.position = Vector2(inset, inset)
	inner.size = Vector2(iw, ih)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.configure(inner_cp, well_fill, well_fill.darkened(0.14), cut_paper_tile())
	inner.corner = float(opts.get("inner_corner", 16.0))
	root.add_child(inner)

	# the well's TOP inner shadow (recessed look)
	var sh: Control = load(INSET_SHADOW).new()
	sh.name = "TornCellInnerShadow"
	sh.position = Vector2(inset, inset)
	sh.size = Vector2(iw, ih)
	root.add_child(sh)
	sh.configure(float(opts.get("inner_corner", 16.0)), float(opts.get("inner_shadow_h", 26.0)),
		float(opts.get("inner_shadow_strength", 30.0)) / 100.0, opts.get("inner_shadow_tint", Color("#294654")),
		float(opts.get("inner_shadow_falloff", 16.0)) / 10.0)
	return root

## Read the `action_button` config block into the opts the shared builder consumes: the cut-paper edge
## opts (shared parser), the per-button paper-role tint palette (tint_<role> keys), the icon scale, and
## the shared shadow. The home bar + board wells both build from this — one source, no drift.
static func action_button_opts_from_config(cfg: Dictionary) -> Dictionary:
	var d: Dictionary = cfg.get("action_button", {}) if cfg is Dictionary else {}
	var tints := {}
	for role in ACTION_ROLES:
		tints[role] = String(d.get("tint_" + role, ACTION_TINT_DEFAULTS.get(role, "cream")))
	return {
		"cp": cut_paper_opts_from_config(cfg, "action_button", ACTION_BUTTON_CP_DEFAULTS),
		"tints": tints,
		"icon_scale": clampf(float(d.get("icon_scale", 90)) / 100.0, 0.10, 1.0),
		"icon_shadow": bool(d.get("icon_shadow", true)),
	}

## The SHARED text-shadow knob set — one drop-shadow control group appliable to ANY text element (the
## dialog title today; more later). Same shape contract as CUT_PAPER_KNOBS: each entry is BOTH a row in
## the workbench inspector (via _text_shadow_section) AND a field the reader parses + the applier consumes.
## Add a knob here → it shows up everywhere the section is rendered, read, and applied, no per-caller edits.
## `text_shadow` gates the rest; offsets are px; blur maps to the Label's shadow_outline_size; strength is a
## percent → alpha. Per-element VALUES live in each component's own config block; this fixes only the SET.
const TEXT_SHADOW_KNOBS := [
	{"key": "text_shadow",     "kind": "toggle", "label": "Title shadow",  "default": false},
	{"key": "shadow_dx",       "kind": "slider", "label": "Offset X",      "min": -20, "max": 20, "default": 0},
	{"key": "shadow_dy",       "kind": "slider", "label": "Offset Y",      "min": -20, "max": 20, "default": 3},
	{"key": "text_shadow_blur","kind": "slider", "label": "Shadow blur",   "min": 0,   "max": 24, "default": 0},
	{"key": "text_shadow_str", "kind": "slider", "label": "Shadow strength","min": 0,  "max": 100, "default": 45},
]

## Read the shared text-shadow knob set from a component's config `block` into a NORMALIZED opts dict
## (percent strength → 0..1 alpha). `overrides` supplies per-element fallback defaults; the schema default is
## the final fallback. One parser for every text element that wears the shared drop shadow — no drift.
static func text_shadow_opts_from_config(cfg: Dictionary, block: String, overrides: Dictionary = {}) -> Dictionary:
	var d: Dictionary = cfg.get(block, {})
	var o := {}
	for knob in TEXT_SHADOW_KNOBS:
		var k: String = knob["key"]
		var raw: Variant = d.get(k, overrides.get(k, knob["default"]))
		if String(knob.get("kind", "slider")) == "toggle":
			o[k] = bool(raw)
		elif k == "text_shadow_str":
			o[k] = float(raw) / 100.0
		else:
			o[k] = float(raw)
	return o

## Apply the shared text drop-shadow to a Label from a normalized opts dict (text_shadow_opts_from_config).
## Off → clears the shadow to fully transparent. Any text element calls this; nothing here is title-specific.
static func apply_text_shadow(lbl: Label, o: Dictionary) -> void:
	var on := bool(o.get("text_shadow", false))
	var a: float = float(o.get("text_shadow_str", 0.0)) if on else 0.0
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, a))
	lbl.add_theme_constant_override("shadow_offset_x", int(round(float(o.get("shadow_dx", 0)))))
	lbl.add_theme_constant_override("shadow_offset_y", int(round(float(o.get("shadow_dy", 0)))))
	lbl.add_theme_constant_override("shadow_outline_size", int(round(float(o.get("text_shadow_blur", 0)))))

## The paper-fibre tile (or null if absent) — passed to CutPaperPanel.configure so the engine applier
## stays free of grove asset paths.
static func cut_paper_tile() -> Texture2D:
	return load(CUT_PAPER_TILE) as Texture2D if ResourceLoader.exists(CUT_PAPER_TILE) else null

## A paper role's OWN deckle fibre when it registers one (e.g. the white role), else null so the deckle
## surface falls back to the shared cream tile. Keeps per-role grain (white paper) out of the engine applier.
static func _paper_role_tile(surface: Dictionary) -> Texture2D:
	var p := String(surface.get("tile", ""))
	return load(p) as Texture2D if p != "" and ResourceLoader.exists(p) else null

## Per-component fallback defaults for the shared cut-paper edge (used as `overrides` for the reader; the
## saved config wins over these, and the schema default wins when a component omits a key). Only the values
## that differ from the schema need listing — the SET of knobs is fixed once in CUT_PAPER_KNOBS.
const ROW_CP_DEFAULTS := {"corner": 20, "deckle_amp": 3, "deckle_freq": 5, "rim_width": 2, "edge_shadow": true}
const FRAME_CP_DEFAULTS := {"deckle": false, "corner": 22, "deckle_amp": 5, "deckle_freq": 5, "rim_width": 2, "edge_shadow": true}
const BUTTON_CP_DEFAULTS := {"deckle": true, "corner": 16, "deckle_amp": 5, "deckle_freq": 5, "rim_width": 2, "edge_shadow": true}
# The wallet pill wears the SAME shared cut-paper edge; `corner` seeds the capsule roundness to the old
# pill_h * 0.35 look (35 at the default 100px height) so an untuned pill is visually unchanged.
const PILL_CP_DEFAULTS := {"deckle": true, "corner": 35, "deckle_amp": 4, "deckle_freq": 5, "rim_width": 2, "edge_shadow": true}
# The MAIL / reward-row card wears the SAME shared cut-paper edge, in its own tint + content. A finer tear at
# card scale (amp 4) than the big frame page. `tint` (the paper fill) lives on the card's own config block.
const MAIL_CP_DEFAULTS := {"deckle": true, "corner": 18, "deckle_amp": 4, "deckle_freq": 5, "rim_width": 2, "edge_shadow": true}
const MAIL_TINT_DEFAULT := Pal.CREAM   # the reward card's default paper fill

## Read the mail / reward-row card's shared edge + its own tint from `cfg` (the workbench passes live
## _params; the game passes the saved config) into the opts mail_card / mail_dialog forward to the builder.
static func mail_card_opts_from_config(cfg: Dictionary) -> Dictionary:
	var d: Dictionary = cfg.get("mail_card", {})
	var tint := Color.from_string("#" + String(d.get("tint", MAIL_TINT_DEFAULT.to_html(false))).lstrip("#"), MAIL_TINT_DEFAULT)
	return {"mail_cp": cut_paper_opts_from_config(cfg, "mail_card", MAIL_CP_DEFAULTS), "mail_tint": tint}

## The shared row surface: a code-drawn CUT-PAPER sheet — the SAME rugged deckled edge the dialog frame
## wears, in sage — so every settings row (toggle · info · action) reads as a torn paper strip. Kept as a
## PanelContainer (the row locator every caller + test expects): a TRANSPARENT panel that SIZES to its
## content, holding a CutPaperPanel background (the visible deckled sheet, fills the panel) + a padded
## MarginContainer content HOST on top. Add row content via _row_body(panel), not panel.add_child. `cp` is
## the shared normalized cut-paper opts (Kit.cut_paper_opts_from_config) — the ONE edge knob set.
static func _row_panel(cp_opts: Dictionary = {}, fill: Color = ROW_SAGE, rim: Color = ROW_SAGE_EDGE) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var empty := StyleBoxEmpty.new()   # transparent: the CutPaperPanel behind is the visible surface
	panel.add_theme_stylebox_override("panel", empty)
	var cp = load(CUT_PAPER).new()     # the deckled sheet, laid out to fill the panel rect
	# shared edge knobs via the one applier; the row's TINT (fill + cut-edge rim) is this component's own
	# — sage by default, overridable per-component. Callers pass the normalized reader output; the {}
	# fallback normalizes ROW_CP_DEFAULTS' percent freq itself.
	var o: Dictionary = cp_opts
	if o.is_empty():
		o = ROW_CP_DEFAULTS.duplicate()
		o["deckle_freq"] = float(o["deckle_freq"]) / 100.0
	cp.configure(o, fill, rim, cut_paper_tile())
	cp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(cp)
	# content host: pad the row IN from the deckled edge so text/switch never touch the tear. The panel
	# stacks both children into the same rect, so the host's margins are the ONLY content inset.
	var host := MarginContainer.new()
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inset := int(cp.content_inset())
	host.add_theme_constant_override("margin_left", 14 + inset)
	host.add_theme_constant_override("margin_right", 10 + inset)
	host.add_theme_constant_override("margin_top", 10)
	host.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(host)
	panel.set_meta("row_body", host)
	return panel

## The padded content host of a _row_panel — add the row's HBox/Button here (not to the panel root, which
## is the interactive surface + deckled background). Falls back to the panel itself for any legacy surface.
static func _row_body(panel: Control) -> Control:
	# has_meta first — get_meta with a NULL default is treated as "no default" and pushes an error.
	if not panel.has_meta("row_body"):
		return panel
	var host: Variant = panel.get_meta("row_body")
	return host if host is Control else panel

## The LEFT-hand name of a settings-family row (toggle_card's plain row + info_card) — ink on the row's
## own surface, filling the width so the switch / value sits at the far edge, vertically centred.
## Both callers had this identical 9-line block; they are documented siblings, so it is ONE builder.
static func _row_name_label(text: String, font: int) -> Label:
	var l := _kit_label(text, font, Pal.INK)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l

## An INFO CARD — a read-only row on the toggle_card surface: a label on the LEFT, a value on the RIGHT,
## no switch. The settings dialog uses it for non-interactive lines (e.g. the Game Center id).
##   entry: label · value (both String) · id? (String metadata). opts: label_font (px) · card_art (bool).
static func info_card(entry: Dictionary, opts: Dictionary = {}) -> Control:
	var label_font := int(opts.get("label_font", FS.BODY))
	var info_id := String(entry.get("id", ""))
	var panel := _row_panel(opts.get("cp", {}), opts.get("row_fill", ROW_SAGE), opts.get("row_rim", ROW_SAGE_EDGE))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if info_id != "":
		panel.set_meta("settings_info_id", info_id)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 18)
	_row_body(panel).add_child(row)
	row.add_child(_row_name_label(String(entry.get("label", "")), label_font))
	var val_l := _kit_label(String(entry.get("value", "")), maxi(13, label_font - 4), Color(Pal.BARK, 0.95))
	if info_id != "":
		val_l.set_meta("settings_info_value_id", info_id)
	val_l.custom_minimum_size.x = float(opts.get("value_min_w", 180.0))
	val_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	val_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	val_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	val_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(val_l)
	return panel

## An ACTION CARD — a single full-width button styled on the toggle_card surface that fires on_action.
## With confirm_label set it becomes a TWO-TAP: the first tap morphs the button text to confirm_label and
## arms (reverting after ~3s if untouched, when in-tree); the next tap fires on_action. The settings
## dialog uses it for the debug Reset save row (destructive tint).
##   entry: label · confirm_label? · destructive? (bool) · on_action (Callable()). opts: label_font · card_art.
static func action_card(entry: Dictionary, opts: Dictionary = {}) -> Control:
	var label_font := int(opts.get("label_font", FS.BODY))
	var panel := _row_panel(opts.get("cp", {}), opts.get("row_fill", ROW_SAGE), opts.get("row_rim", ROW_SAGE_EDGE))
	var base_label := String(entry.get("label", ""))
	var confirm_label := String(entry.get("confirm_label", ""))
	var destructive := bool(entry.get("destructive", false))
	var on_action: Callable = entry.get("on_action", Callable())
	var btn := Button.new()
	btn.text = base_label
	btn.focus_mode = Control.FOCUS_NONE
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", label_font)
	var tint: Color = Pal.ACCENT_ALERT if destructive else Pal.INK
	btn.add_theme_color_override("font_color", tint)
	btn.add_theme_color_override("font_hover_color", tint)
	btn.add_theme_color_override("font_pressed_color", tint)
	btn.add_theme_color_override("font_focus_color", tint)
	# transparent button chrome so the parchment row shows through (it reads as a row, not a chip)
	var empty := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus"]:
		btn.add_theme_stylebox_override(st, empty)
	_row_body(panel).add_child(btn)
	var armed: Array = [false]
	btn.pressed.connect(func() -> void:
		if confirm_label != "" and not armed[0]:
			armed[0] = true
			btn.text = confirm_label
			if btn.is_inside_tree():                 # revert if the confirm is left untouched
				var t := btn.get_tree().create_timer(3.0)
				t.timeout.connect(func() -> void:
					if is_instance_valid(btn) and armed[0]:
						armed[0] = false
						btn.text = base_label)
			return
		if on_action.is_valid():
			on_action.call())
	return panel

## The dialog banner band: ribbon art + the "Mail" text drawn FULL-RECT and vertically CENTRED, so it
## auto-aligns whatever the font size; plus an optional envelope icon (toggle). Named DialogBanner /
## DialogBannerIcon so the workbench can drag them.
static func _banner(text: String, font: int, band_h: float, width: float, icon_on: bool,
		icon_px: float, icon_pos, text_x: float = 0.0, text_y: float = 0.0, burn: float = 0.0,
		banner_art: String = "meadow_v2/title_banner.png", banner_icon_id: String = "mail",
		pad_l: float = -1.0, pad_r: float = -1.0, banner_min_w: float = 0.0) -> Control:
	var header := Control.new()
	header.name = "DialogBanner"
	header.custom_minimum_size = Vector2(width, band_h)
	# the ribbon WIDTH tracks the title: a short label gives a short banner, growing with the number of
	# letters up to the full card `width` (the max). The folded tails stay rigid (9-slice) so only the flat
	# middle stretches — the ribbon never squashes or distorts however long or short the title is. pad_l /
	# pad_r are the breathing room between the title and each tail (workbench-tunable); asymmetric padding
	# both widens the ribbon AND nudges the title toward the roomier side.
	var pl := pad_l if pad_l >= 0.0 else band_h * 0.55
	var pr := pad_r if pad_r >= 0.0 else band_h * 0.55
	var text_w := ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font).x
	var icon_room := (icon_px + band_h * 0.25) if icon_on else 0.0
	# the ribbon never shrinks below a floor: two tail-widths OR a caller-supplied floor (banner_min_w —
	# dialogs pass a fraction of the SCREEN width, so a SHORT title like the bag's "Bag" still reads as a
	# proper banner, not a tiny stub). Clamped to the frame width (the ribbon's hard max).
	var min_w := minf(maxf(band_h * 2.2, banner_min_w), width)
	var banner_w := clampf(text_w + pl + pr + icon_room, min_w, width)
	var ribbon_x := (width - banner_w) * 0.5                    # centre the sized ribbon within the band
	var bp := Look.kit(banner_art)
	if ResourceLoader.exists(bp):
		var art := NinePatchRect.new()
		art.name = "MeadowTitleBanner"
		art.texture = load(bp) as Texture2D if banner_art == "meadow_v2/title_banner.png" else clean_tex_path(bp, 480)
		art.position = Vector2(ribbon_x, 0.0)
		art.size = Vector2(banner_w, band_h)
		var cap := int(round(float(art.texture.get_width()) * 0.20)) if art.texture != null else 0
		art.patch_margin_left = cap             # the folded tails stay 1:1; the flat middle stretches
		art.patch_margin_right = cap
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		header.add_child(art)
	var lbl := Label.new()
	lbl.text = text
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	var shift := text_x + (pl - pr) * 0.5                    # centre the title in its padded span, + the manual nudge
	lbl.offset_left = shift; lbl.offset_right = shift        # shift the centred text horizontally
	lbl.offset_top = text_y; lbl.offset_bottom = text_y      # ...and vertically
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER       # auto-vcentre on any font size
	lbl.add_theme_font_size_override("font_size", font)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if burn > 0.0:
		# "burned into the ribbon": dark engraved ink + a light lower emboss highlight + a soft dark halo.
		# Intensity (0..1) deepens the ink and grows the emboss/halo, so it's a dial, not just on/off.
		var t := clampf(burn, 0.0, 1.0)
		lbl.add_theme_color_override("font_color", Color("#4A2E14").darkened(0.35 * t))
		lbl.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.25 + 0.45 * t))
		lbl.add_theme_constant_override("shadow_offset_x", int(round(1.0 + 2.0 * t)))
		lbl.add_theme_constant_override("shadow_offset_y", int(round(2.0 + 3.0 * t)))
		lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.12 + 0.33 * t))
		lbl.add_theme_constant_override("outline_size", int(round(2.0 + 4.0 * t)))
	else:
		lbl.add_theme_color_override("font_color", Pal.INK)
		lbl.add_theme_constant_override("outline_size", 0)
	header.add_child(lbl)
	if icon_on and ResourceLoader.exists(bp):
		var env := make_icon(banner_icon_id, icon_px)   # polished envelope (or the dialog's own banner icon)
		env.name = "DialogBannerIcon"
		env.mouse_filter = Control.MOUSE_FILTER_IGNORE
		header.add_child(env)
		if icon_pos != null:
			env.position = icon_pos
		else:
			# default: just inside the sized ribbon's left, vertically centred (tracks the ribbon, not the band)
			env.position = Vector2(ribbon_x + banner_w * 0.14 - icon_px / 2.0, band_h / 2.0 - icon_px / 2.0)
	return header

## The dialog mocks' DISPLAY TITLE, as a fraction of the card width — measured off the tiers mock
## (a ~98px cap-box on a 995px card) and consistent across the shop / residents / level sheets.
const DIALOG_TITLE_FONT_FRAC := 0.098
## ...and the band one such line needs, × its font size.
const DIALOG_TITLE_LINE_FRAC := 1.02
## Breathing room between a shrunk long title and the docked ✕ disc (px at target width).
const TITLE_CLOSE_GAP := 14.0

## The display title's font size for a sheet `target_w` px wide, SHRUNK to fit when the title is long
## (the tiers mock's "WILDFLOWER" is 10 characters; "GLOW MUSHROOMS" at that size runs off both edges).
## Public so a dialog that sizes its own title band (the tiers crest) can ask for the same number.
static func dialog_title_font(text: String, target_w: float, pad_x: float, frac: float = DIALOG_TITLE_FONT_FRAC) -> int:
	var fsz: int = maxi(12, int(round(target_w * frac)))
	var f: Font = bold_font()
	if f == null:
		return fsz
	var room: float = maxf(1.0, target_w - 2.0 * pad_x)
	var tw: float = f.get_string_size(text.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x
	if tw > room:
		fsz = maxi(12, int(floor(float(fsz) * room / tw)))
	return fsz

## The SIMPLE dialog header (dialog mock set v2): the uppercased title in plain chunky ink, centered
## in the top band of the sheet — no ribbon art, no icon. Named DialogBanner so the workbench and the
## frame tests keep finding the header by the established handle.
static func _title_header(text: String, font: int, band_h: float, width: float, shadow: Dictionary = {}) -> Control:
	var header := Control.new()
	header.name = "DialogBanner"
	header.custom_minimum_size = Vector2(width, band_h)
	var lbl := _kit_label(text.to_upper(), font, Color("#1B2C38"))
	lbl.name = "DialogTitle"
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font", bold_font())
	# The title's depth is the SHARED text drop-shadow (Kit.TEXT_SHADOW_KNOBS): offset · blur · strength,
	# tuned on the Frame item and appliable to any text element. Off by default → a flat label.
	apply_text_shadow(lbl, shadow)
	header.add_child(lbl)
	return header

## The dialog ✕ — the mail_close sprite scaled (polished). Named DialogClose so the workbench drags it.
## close_art overrides the sprite so another dialog (tiers) can dock its own ✕ disc.
static func _close_button(size: float, cb: Callable, close_art: String = "kit/mail_close.png") -> Button:
	var b := Button.new()
	b.name = "DialogClose"
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(size, size)
	var tex := clean_tex_path(Look.kit(close_art), 192)
	if tex != null:
		var st := StyleBoxTexture.new()
		st.texture = tex
		b.add_theme_stylebox_override("normal", st)
		b.add_theme_stylebox_override("hover", st)
		var sp: StyleBoxTexture = st.duplicate()
		sp.modulate_color = Color(0.88, 0.88, 0.88)
		b.add_theme_stylebox_override("pressed", sp)
	b.pressed.connect(func() -> void:
		if cb.is_valid(): cb.call())
	# the coral disc casts THE shared shadow (the saved workbench block — same mechanism as every
	# element). The disc ART is opaque but fills only ~0.78 of the button box (transparent margin
	# around it), so the shadow panel's FOOTPRINT is sized to the art's visible disc — per-element
	# geometry, like a corner radius — instead of the full box, whose fill peeked past the art as a
	# hard grey ring (the old double-shadow bug).
	const CLOSE_ART_FRAC := 0.78
	var d := size * CLOSE_ART_FRAC
	var sh := _meadow_shadow_circle(d)
	sh.name = "DialogCloseShadow"
	sh.set_anchors_preset(Control.PRESET_TOP_LEFT)
	sh.position = Vector2((size - d) / 2.0, (size - d) / 2.0)
	sh.size = Vector2(d, d)
	sh.show_behind_parent = true
	b.add_child(sh)
	return b

## A tidier scrollbar: a rounded bark grabber on a faint track (vs the default chunky bar).
## SCROLLBAR_W is public: a dialog that lays fixed-width content against the frame's inner
## width must reserve this much (the ScrollContainer subtracts a visible bar from the child
## area, and an unreserved bar pushes fixed-width rows past the right clip).
const SCROLLBAR_W := 10.0
static func _style_scrollbar(scroll: ScrollContainer) -> void:
	var vb := scroll.get_v_scroll_bar()
	vb.custom_minimum_size.x = SCROLLBAR_W
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(Pal.BARK, 0.55)
	grab.set_corner_radius_all(5)
	grab.content_margin_left = 3
	grab.content_margin_right = 3
	for s in ["grabber", "grabber_highlight", "grabber_pressed"]:
		vb.add_theme_stylebox_override(s, grab)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(Pal.BARK, 0.1)
	track.set_corner_radius_all(5)
	vb.add_theme_stylebox_override("scroll", track)

## The whole Mail dialog (mockup image 3): a parchment card with the gold banner + envelope, a
## docked ✕, and a column of mail_cards. COMPOSES mail_card for every entry.
## opts (all optional): banner_font, banner_h, banner_icon (px), banner_icon_pos (Vector2 in the
## banner band, or absent = ~30% across, centred), close_size (px), close_poke (Vector2 — how far the
## ✕ poles past the card's top-right corner). The banner icon ("DialogBannerIcon") and the ✕
## ("DialogClose") are NAMED so the workbench can make them mouse-draggable.
## The shared frame's selectable BORDER art — a reusable registry so a dialog (or the Frame item's
## Border picker) dresses the SAME frame mechanics in a different border. Each entry carries the
## nine-patch art + its natural slice + content padding. dialog_frame resolves the chosen name into
## panel_art / slice / pad DEFAULTS; explicit panel_art / card_slice_* / panel_pad_* opts still win,
## so every existing caller (mail/daily/shop/settings on parchment; tiers on its own art) is unchanged.
const CUT_PAPER_TILE_OLD_CREAM := "res://games/grove/assets/ui/dialogs/paper_tile_cream.png"   # legacy yellow-cream fibre
const CUT_PAPER_TILE_WHITE := "res://games/grove/assets/ui/dialogs/paper_tile_white.png"   # the white paper role's fibre (desaturated + lifted from the cream tile)
## The shared frame fibre: between white and the old yellow cream. Every cut-paper surface in the
## game — dialogs, pills, cards, and the nav tab faces — multiplies its fill by THIS one tile.
##
## It WRAPS acceptably, and that was checked rather than assumed. `CutPaperPanel` samples it with
## TEXTURE_REPEAT_ENABLED at native 1:1, so a surface wider or taller than the tile's 1254 px repeats
## it. Measured on the seam: mean |Δ| across the wrap is 2.94 px-levels horizontally / 3.71 vertically
## — but the mean |Δ| between any two ADJACENT INTERIOR columns/rows is 2.93 / 3.61, so the join is
## indistinguishable from ordinary fibre noise. The low-frequency check agrees: local mean drift across
## the seam is 0.09 / 0.41 of 255, and after a 9 px blur the seam's gradient (0.24 / 0.29) sits below
## the interior p99 (0.58 / 0.77). A raw wrap step measured WITHOUT that interior baseline reads as a
## defect and is not one — do not "fix" this tile with an edge crossfade on that evidence alone.
const CUT_PAPER_TILE_SOFT_CREAM := "res://games/grove/assets/ui/dialogs/paper_tile_soft_cream.png"
const CUT_PAPER_TILE := CUT_PAPER_TILE_SOFT_CREAM   # code-drawn shared sheet's paper fibre

const FRAME_BORDERS := {
	"parchment":  {"art": "meadow_v2/dialog_panel.png", "slice": 42.0, "pad_x": 26.0, "pad_y": 24.0},
	"vault twig": {"art": "kit/vault_panel.png",        "slice": 64.0, "pad_x": 40.0, "pad_y": 34.0},
	"twig board": {"art": "kit/tiers_panel.png",        "slice": 72.0, "pad_x": 44.0, "pad_y": 30.0},
}

## Resolve a border NAME to its {art, slice, pad_x, pad_y} record (unknown → parchment, so a stale
## saved value never blanks the frame).
static func frame_border(name: String) -> Dictionary:
	return FRAME_BORDERS.get(name, FRAME_BORDERS["parchment"])

## The SHARED dialog frame — built ONCE and reused by every dialog (mail, daily, …). Dialog mock set v2
## (2026-07-18): the frame is now the SIMPLE warm-cream sheet — one flat rounded card with a shallow
## tinted shadow, the uppercased title in plain ink centered at the top, and the coral ✕ docked INSIDE
## the top-right corner. The parchment nine-patch borders and the gold banner ribbon are retired; the
## banner_art / banner_icon / border opts are accepted but ignored so existing callers keep working.
## One relayout caps the height, centres the wrap, and docks the ✕. `content` is whatever scrolls
## inside. The named DialogBanner / DialogClose let the workbench drag the handles.
static func dialog_frame(content: Control, width: float = 560.0, opts: Dictionary = {}) -> Control:
	var banner_font: int = int(opts.get("banner_font", FS.HEADING))
	var banner_h: float = float(opts.get("banner_h", BANNER_H))
	var close_size: float = float(opts.get("close_size", 64.0))
	# close_poke is reinterpreted as the ✕'s INSET from the card's top-right corner (mock v2 docks the
	# disc inside the sheet, not poking past it) — the workbench's saved close_x/close_y keep meaning.
	var close_poke: Vector2 = opts.get("close_poke", Vector2(12, 12))
	close_poke = Vector2(maxf(8.0, close_poke.x), maxf(8.0, close_poke.y))
	var card_corner: float = float(opts.get("card_corner", 28.0))
	var min_h_override: float = float(opts.get("min_h", -1.0))   # explicit px height floor; <0 → use DIALOG_MIN_H_FRAC of the screen height (resolved once mounted)
	# the retired BORDER registry still supplies the content-pad DEFAULTS (so every caller's inset is
	# unchanged); its art/slice fields are ignored — the sheet is code-drawn now.
	var border: Dictionary = frame_border(String(opts.get("border", "parchment")))
	# saved workbench offsets were tuned for the OLD overhanging ribbon/✕ — the v2 sheet keeps its
	# title and close INSIDE the card, so negative y offsets are floored instead of clipping above
	# it, and the x offset is ignored entirely: the v2 title band spans the full card with a CENTRED
	# label, so any horizontal nudge (the saved ribbon-era banner_x) just de-centres the title.
	var banner_pos: Vector2 = opts.get("banner_pos", Vector2.ZERO)
	banner_pos.y = maxf(0.0, banner_pos.y)
	var list_max_h: float = float(opts.get("list_max_h", 0.0))
	var list_top_pad: float = float(opts.get("list_top_pad", 0.0))
	# clip_below_banner: the scroll's clip window starts UNDER the title band instead of at the card
	# top, so scrolled rows disappear below the title rather than riding up behind it (the shop). Off
	# by default — every other dialog keeps the slide-behind-the-banner look.
	var clip_below_banner: bool = bool(opts.get("clip_below_banner", false))
	# an optional PINNED FOOTER control (mail's big Claim All): it rides a cream band docked to the card's
	# bottom edge, ALWAYS on-screen while the card list scrolls behind it. Off by default (settings/info/…
	# are unchanged). footer_gap = breathing room between the last row and the footer band.
	var footer: Control = opts.get("footer", null)
	var footer_gap: float = float(opts.get("footer_gap", 10.0))
	# Residents keeps its own bounded hand scroller, so its pinned footer may shrink the outer
	# content viewport instead of overlaying it. Default false preserves Mail's overlay+spacer flow.
	var footer_reduces_viewport: bool = bool(opts.get("footer_reduces_viewport", false))
	var center_content: bool = bool(opts.get("center_content", false))   # stretch a sparse content block to fill the floored body so it centers (empty mail note)
	var on_close: Callable = opts.get("on_close", Callable())
	var banner_text: String = String(opts.get("banner_text", "Mail"))
	var panel_pad_x: float = float(opts.get("panel_pad_x", border["pad_x"]))   # content inset from the sheet edge (L/R)
	var panel_pad_y: float = float(opts.get("panel_pad_y", border["pad_y"]))   # content inset from the sheet edge (T/B)
	var close_art: String = String(opts.get("close_art", "kit/mail_close.png"))
	# CRISP CHROME, SCALED CONTENT: `width` is the dialog's AUTHORED (design) width; the chrome
	# (card border, banner, ✕) is built at the real on-screen TARGET width = design × content_scale,
	# so it stays sharp. The inner content is laid out at `width` and uniformly scaled to fill the
	# target (see the ScaleContainer below). content_scale == 1 → byte-identical to the old frame.
	var content_scale: float = maxf(0.01, float(opts.get("content_scale", 1.0)))
	var target_w: float = width * content_scale

	# THE SHARED DISPLAY TITLE. Every dialog mock heads its sheet with the same large navy all-caps
	# line, sized as a fraction of the CARD (not a fixed px), so the shared frame — not each dialog —
	# owns it. opts.banner_font_frac = 0 opts a caller back out to a literal banner_font.
	var title_frac: float = float(opts.get("banner_font_frac", DIALOG_TITLE_FONT_FRAC))
	if title_frac > 0.0:
		# the title row's MAX WIDTH is the card minus the ✕ ZONE, not just the sheet pad: the coral
		# disc is docked INSIDE the same top band, so both sides reserve (inset + disc + a breathing
		# gap) — symmetric, keeping the centred title centred — and a long name auto-shrinks instead
		# of running under it.
		var title_pad: float = maxf(panel_pad_x, close_poke.x + close_size + TITLE_CLOSE_GAP)
		banner_font = dialog_title_font(banner_text, target_w, title_pad, title_frac)
		# the band has to hold the line it now carries; a caller that already sized its own band
		# taller (the tiers crest rides above the title) keeps its value.
		banner_h = maxf(banner_h, float(banner_font) * DIALOG_TITLE_LINE_FRAC)

	var wrap := Control.new()
	var card := PanelContainer.new()
	card.name = "MeadowDialogPanel"
	# reskin hook: a dialog may pass `panel_bg` (a cut-paper panel sprite) to wear it as the sheet face
	# instead of the drawn cream card — content padding is preserved so the layout is unchanged.
	var panel_bg_path := String(opts.get("panel_bg", ""))
	var panel_bg_tex: Texture2D = load(panel_bg_path) as Texture2D if panel_bg_path != "" and ResourceLoader.exists(panel_bg_path) else null
	# CODE-DRAWN cut-paper sheet (workbench toggle): a live CutPaperPanel drawn BEHIND the card, so the
	# deckled edge + tiled paper + shadow size to any dialog with no stretch. The card keeps a transparent-
	# but-padded stylebox so the content layout is unchanged; the panel is synced to the card's rect.
	var cp_opts: Dictionary = opts.get("cp", {})
	var cut_paper := bool(cp_opts.get("deckle", false)) and panel_bg_tex == null
	var cut_paper_panel: Control = null
	if cut_paper:
		var cf := StyleBoxFlat.new()
		cf.bg_color = Color(0, 0, 0, 0)   # transparent: the CutPaperPanel behind is the visible sheet
		cf.content_margin_left = panel_pad_x; cf.content_margin_right = panel_pad_x
		cf.content_margin_top = panel_pad_y; cf.content_margin_bottom = panel_pad_y
		card.add_theme_stylebox_override("panel", cf)
		var cp = load(CUT_PAPER).new()
		cp.name = "CutPaperSheet"
		cp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cp.configure(cp_opts, Color("#F9F3EC"), null, load(CUT_PAPER_TILE_SOFT_CREAM))   # the ONE shared edge applier
		cut_paper_panel = cp
	elif panel_bg_tex != null:
		var pt := StyleBoxTexture.new()
		pt.texture = panel_bg_tex
		pt.content_margin_left = panel_pad_x; pt.content_margin_right = panel_pad_x
		pt.content_margin_top = panel_pad_y; pt.content_margin_bottom = panel_pad_y
		card.add_theme_stylebox_override("panel", pt)
	else:
		# the SIMPLE SHEET (mock set v2): one flat warm-cream rounded card with a shallow tinted shadow.
		var cf := StyleBoxFlat.new()
		cf.bg_color = Pal.CREAM
		cf.set_corner_radius_all(int(card_corner))
		cf.shadow_color = Color(Pal.INK, 0.18)
		cf.shadow_size = 12
		cf.shadow_offset = Vector2(0, 6)
		cf.content_margin_left = panel_pad_x; cf.content_margin_right = panel_pad_x
		cf.content_margin_top = panel_pad_y; cf.content_margin_bottom = panel_pad_y
		card.add_theme_stylebox_override("panel", cf)
	var pad_y_eff: float = panel_pad_y   # the panel's top+bottom content inset (for the centered-fill math)
	card.custom_minimum_size = Vector2(target_w, maxf(0.0, min_h_override))   # width = the global target; height floor finalised in relayout (needs the viewport for the %)
	card.position = Vector2.ZERO
	wrap.custom_minimum_size.x = target_w      # robust horizontal centring even before relayout runs
	wrap.add_child(card)
	if cut_paper_panel != null:
		# the code-drawn sheet sits BEHIND the (transparent) card and tracks its rect as the card grows
		wrap.add_child(cut_paper_panel)
		wrap.move_child(cut_paper_panel, 0)
		var sync_cp := func() -> void:
			if is_instance_valid(cut_paper_panel) and is_instance_valid(card):
				cut_paper_panel.position = card.position
				cut_paper_panel.size = card.size
				cut_paper_panel.queue_redraw()
		card.resized.connect(sync_cp)
		card.item_rect_changed.connect(sync_cp)
		sync_cp.call_deferred()

	# inner = the card's single content child; it hosts the scrolling content AND the banner overlay
	var inner := Control.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.clip_contents = false                  # the banner may overhang the top
	card.add_child(inner)

	# the content scrolls and FILLS the card; it clips, so content slides up BEHIND the banner. A top
	# spacer (banner bottom + list_top_pad) keeps content below the banner to begin with.
	# THE CLIP WINDOW: the scroll's own clip would slice content at the PADDED edge, but cards carry
	# deliberate horizontal overhangs — a shop card's ribbon, a marked cell's glow, every card's side
	# shadow — that must land on the parchment margin, exactly like CONTENT_TAIL_PAD lets the LAST
	# row's shadow clear the bottom edge. So the horizontal clip moves OUT to the card's edge: a
	# wrapper spanning the side pads clips instead, and the scroll (kept at its exact old rect, so
	# every dialog's layout is untouched) no longer clips itself. Vertical bounds match the scroll —
	# the vertical clip is unchanged.
	var clipw := Control.new()
	clipw.name = "DialogClipWindow"
	clipw.set_anchors_preset(Control.PRESET_FULL_RECT)
	clipw.offset_left = -panel_pad_x
	clipw.offset_right = panel_pad_x
	if clip_below_banner:
		clipw.offset_top = maxf(0.0, banner_pos.y + banner_h)   # the window opens under the title band
	clipw.clip_contents = true
	clipw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(clipw)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = panel_pad_x
	scroll.offset_right = -panel_pad_x
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	if not bool(opts.get("outer_scroll_enabled", true)):
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.clip_contents = false
	_style_scrollbar(scroll)
	clipw.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var spacer := Control.new()
	# with the clip window already opening under the band, the spacer only carries list_top_pad —
	# else it would double-reserve the banner height.
	var spacer_h: float = (0.0 if clip_below_banner else maxf(0.0, banner_pos.y + banner_h)) + list_top_pad
	spacer.custom_minimum_size = Vector2(0, maxf(0.0, spacer_h))
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_child(spacer)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if is_equal_approx(content_scale, 1.0):
		rows.add_child(content)                    # identity → unchanged (mail/daily/bag stay byte-identical)
	else:
		var scaler := ScaleContainer.new()         # lays content out at `width`, renders it at content_scale
		scaler.scale_factor = content_scale
		scaler.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scaler.add_child(content)
		rows.add_child(scaler)
	# a small BOTTOM tail INSIDE the clipping scroll so the LAST card's drop shadow (and gold rim) clears
	# the clip edge instead of being sliced off — the vertical counterpart to each dialog's side inset.
	# Applies to every dialog built on this frame (daily capstone, mail's last row, shop's last section …).
	var tail := Control.new()
	tail.custom_minimum_size = Vector2(0, CONTENT_TAIL_PAD)
	tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_child(tail)
	# reserve a scroll-bottom spacer equal to the pinned footer's height so the last row can scroll fully
	# clear of it (its height is finalised in relayout, once the footer has measured).
	var foot_spacer: Control = null
	if footer != null:
		foot_spacer = Control.new()
		foot_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rows.add_child(foot_spacer)
	scroll.add_child(rows)

	# the PINNED FOOTER band — carries the footer control docked to the card's bottom in relayout.
	# Added after the scroll → drawn over it. Default is transparent so mail's Claim All does not sit on
	# a white/cream slab; callers that need a mask can pass footer_bg_alpha.
	var footer_band: PanelContainer = null
	if footer != null:
		footer_band = PanelContainer.new()
		footer_band.name = "DialogFooterBand"
		var fb := StyleBoxFlat.new()
		fb.bg_color = Color(Pal.CREAM, float(opts.get("footer_bg_alpha", 0.0)))
		fb.content_margin_top = footer_gap
		fb.content_margin_left = 0; fb.content_margin_right = 0; fb.content_margin_bottom = 0
		footer_band.add_theme_stylebox_override("panel", fb)
		footer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		footer_band.add_child(footer)
		# dock the band to inner's BOTTOM edge via anchors (not manual positioning): Godot then keeps it
		# glued to the card bottom every layout pass, so it can't lag a stale inner height and float free
		# (the single-card bug — inner shrinks to fit but a manually-placed band stayed at the tall cap).
		footer_band.anchor_left = 0.0; footer_band.anchor_right = 1.0
		footer_band.anchor_top = 1.0; footer_band.anchor_bottom = 1.0   # offset_top (= -height) set in relayout, once measured
		inner.add_child(footer_band)

	# the simple TITLE band overlays the TOP (added after the scroll → drawn on top), draggable.
	# `inner` is inset by the card's content pad while the band spans the CARD width — pull it back
	# to the card's left edge, or every centred title sits panel_pad_x right of the card centre.
	var header := _title_header(banner_text, banner_font, banner_h, target_w, opts.get("title_shadow", {}))
	header.position = Vector2(-panel_pad_x, banner_pos.y)
	inner.add_child(header)

	# the ✕ disc poles past the card's top-right corner. The game passes on_close; the workbench prints.
	var close_cb: Callable = on_close if on_close.is_valid() else (func() -> void: print("WORKBENCH: dialog closed"))
	var close := _close_button(close_size, close_cb, close_art)
	wrap.add_child(close)

	# ONE relayout: cap the content height (so it scrolls behind the banner), size the wrap to the card
	# so the gallery centres it, and dock the ✕.
	var relayout := func() -> void:
		if not (is_instance_valid(inner) and is_instance_valid(rows) and is_instance_valid(card) and is_instance_valid(close)):
			return
		# Resolve the HEIGHT floor once the card is mounted (needs the viewport for the %): an explicit
		# px min_h wins, else DIALOG_MIN_H_FRAC of the screen height. Guarded by a 1px delta so setting
		# custom_minimum_size (which re-fires resized → relayout) converges instead of looping.
		if card.is_inside_tree():
			var vh: float = card.get_viewport_rect().size.y
			var floor_h: float = maxf(0.0, min_h_override if min_h_override >= 0.0 else vh * DIALOG_MIN_H_FRAC)
			if absf(card.custom_minimum_size.y - floor_h) > 1.0:
				card.custom_minimum_size.y = floor_h
			# center_content: pin the content box to the body left under the banner spacer at the floor, so
			# its center-aligned child sits mid-card (derived from the floor, not live sizes — a live-size
			# fill is underdetermined, every height ≥ floor would be stable, and the card would float).
			if center_content and is_instance_valid(content):
				var fill: float = maxf(0.0, floor_h - 2.0 * pad_y_eff - spacer_h)
				# `content` is laid out at 1/content_scale and rendered at content_scale (the ScaleContainer),
				# so target the UNSCALED inner height — its scaled footprint then fills the body exactly.
				var fill_inner: float = fill / content_scale
				if absf(content.custom_minimum_size.y - fill_inner) > 1.0:
					content.custom_minimum_size.y = fill_inner
		# rows sit below the band when clipping under it, so the band height is added back on top.
		var band_h: float = maxf(0.0, banner_pos.y + banner_h) if clip_below_banner else 0.0
		var rows_cap: float = (banner_h + list_max_h - band_h) if list_max_h > 0.0 else rows.size.y
		inner.custom_minimum_size.y = band_h + minf(rows.size.y, rows_cap)
		# dock the pinned footer to the bottom of the content area, and reserve its height as the list's
		# bottom spacer so rows can scroll fully clear of it (delta-guarded so it converges).
		if is_instance_valid(footer_band):
			# anchored to inner's bottom edge (see build) — we only feed it the measured height as the top
			# offset, and reserve the same height as the list's bottom spacer so rows scroll clear of it.
			var fh: float = footer_band.get_combined_minimum_size().y
			if absf(footer_band.offset_top - (-fh)) > 1.0:
				footer_band.offset_top = -fh
			footer_band.offset_left = 0.0; footer_band.offset_right = 0.0; footer_band.offset_bottom = 0.0
			if is_instance_valid(foot_spacer) and absf(foot_spacer.custom_minimum_size.y - fh) > 1.0:
				foot_spacer.custom_minimum_size.y = fh
			if footer_reduces_viewport and absf(clipw.offset_bottom - (-fh)) > 1.0:
				clipw.offset_bottom = -fh
		wrap.custom_minimum_size = card.size
		close.position = Vector2(card.size.x - close_size - close_poke.x, close_poke.y)   # docked INSIDE the corner (mock v2)
	rows.resized.connect(relayout)
	rows.ready.connect(relayout)
	card.resized.connect(relayout)
	relayout.call_deferred()
	return wrap

## The MAIL dialog — the shared frame with a column of mail_cards (or an empty note) as its content.
static func mail_dialog(entries: Array, width: float = 560.0, opts: Dictionary = {}) -> Control:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	var entries_count: int = int(opts.get("entries_count", entries.size()))
	if entries.is_empty() or maxi(0, entries_count) == 0:
		var empty_text: String = String(opts.get("empty_text", ""))
		if empty_text != "":
			# the empty note is the dialog's only content — center it in the floored body (center_content)
			# so the min-height card reads as a deliberate card, not a banner with stranded text up top.
			content.alignment = BoxContainer.ALIGNMENT_CENTER
			content.size_flags_vertical = Control.SIZE_EXPAND_FILL
			opts = opts.duplicate()
			opts["center_content"] = true
			var empty := Label.new()
			empty.text = empty_text
			empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			empty.add_theme_font_size_override("font_size", int(opts.get("empty_font", FS.BODY)))   # empty-state headline — overridable; default sized to read against the floored card (was a tiny hardcoded 17)
			empty.add_theme_color_override("font_color", Color(Pal.BARK, 0.9))
			empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
			content.add_child(empty)
	else:
		var card_title: int = int(opts.get("card_title", 20))
		var card_body: int = int(opts.get("card_body", 15))
		var btn_opts: Dictionary = (opts.get("btn", {}) as Dictionary).duplicate()
		# forward the reward card's shared edge + tint (Kit.mail_card_opts_from_config) so every row picks up
		# the workbench's LIVE mail_card tuning; absent, mail_card falls back to the saved config itself.
		if opts.has("mail_cp"): btn_opts["mail_cp"] = opts["mail_cp"]
		if opts.has("mail_tint"): btn_opts["mail_tint"] = opts["mail_tint"]
		# the reskinned card wears a fixed-aspect sprite (with a round well); tell it the row width so it can
		# pin its height to the sprite's aspect and keep the well circular instead of stretched into an oval.
		btn_opts["card_w"] = width * 0.84
		var icon_badge: String = String(opts.get("icon_badge", "shared/disc_round.png"))
		for i in maxi(0, entries_count):
			content.add_child(mail_card(entries[i % entries.size()], card_title, card_body, btn_opts, icon_badge))
	# an optional centered FOOTER NOTE — the info sheet's one-line caption under the rows; off by default
	# (the inbox passes none, so it stays a pure card list).
	var foot_note := String(opts.get("note", ""))
	if foot_note != "":
		var fl := _kit_label(foot_note, int(opts.get("note_font", FS.FINE)), Color(Pal.BARK, 0.92))
		fl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		fl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fl.add_theme_font_override("font", plain_font())          # standard text, not the chunky display face
		content.add_child(fl)
	# an optional CLAIM ALL footer — the big full-width green button of mock v1 (envelope + label), PINNED
	# to the card's bottom (dialog_frame's footer slot) so it stays on-screen while the list scrolls. Shown
	# only when the caller wires on_claim_all AND there is an unclaimed gift (claim_all_text set); it grabs
	# every gift at once. Off by default so the workbench preview / info sheet are unchanged.
	var claim_all_cb: Callable = opts.get("on_claim_all", Callable())
	var claim_all_text := String(opts.get("claim_all_text", ""))
	if claim_all_cb.is_valid() and claim_all_text != "":
		var ca_font := int(opts.get("claim_all_font", FS.HEADING))
		# the SHARED pill_button (code-drawn cut-paper edge) — the shared button settings, then the footer's own tuning.
		var ca_opts := button_opts_from_config(load_config(CONFIG_PATH))
		ca_opts.merge((opts.get("btn", {}) as Dictionary), true)
		ca_opts["bg"] = "green"
		ca_opts["icon"] = String(opts.get("claim_all_icon", ""))
		ca_opts["font"] = ca_font
		ca_opts["shadow"] = true
		# corner FOLLOWS the shared Button corner (already in ca_opts) unless a caller forces claim_all_corner —
		# same principle as the per-row Claim: the shared edge knob owns the corner, not a frozen default.
		ca_opts["corner"] = float(opts.get("claim_all_corner", ca_opts.get("corner", 24.0)))
		ca_opts["pad_scale"] = float(opts.get("claim_all_pad", 1.35))
		var ca := pill_button(claim_all_text, ca_opts)
		ca.size_flags_horizontal = Control.SIZE_EXPAND_FILL   # the drawn pill tiles cleanly full-width
		ca.pressed.connect(func() -> void: claim_all_cb.call())
		opts = opts.duplicate()
		opts["footer"] = ca
	# an optional GOT-IT footer button — the SHARED level cta_button, fired by opts.on_close (same as the
	# ✕). Off by default → the inbox is unchanged; the info sheet sets opts.got_it to close itself.
	var got_it_text := String(opts.get("got_it", ""))
	if got_it_text != "":
		var got := cta_button(got_it_text, opts)
		var on_close: Callable = opts.get("on_close", Callable())
		if on_close.is_valid():
			got.pressed.connect(func() -> void: on_close.call())
		var btns := HBoxContainer.new()
		btns.alignment = BoxContainer.ALIGNMENT_CENTER
		btns.add_child(got)
		content.add_child(btns)
	# Face: mail wears the SHARED frame like every other dialog. When the code-drawn cut-paper sheet is on
	# (the shipped default), let it through untouched; only when it is off do we fall back to the baked
	# cut-paper mail panel as the sheet face (a caller may still override panel_bg explicitly).
	if not opts.has("panel_bg") and not bool((opts.get("cp", {}) as Dictionary).get("deckle", false)):
		opts = opts.duplicate()
		opts["panel_bg"] = MAIL_SKIN + "dialog_bg.png"
	return dialog_frame(content, width, opts)

## The SETTINGS dialog — the SHARED frame with a column of toggle_cards, one per persisted flag. The
## direct sibling of mail_dialog: same chrome, a new card. `entries` is [{label, value, on_toggle}, …];
## the toggle-card style rides opts["toggle"] (label_font / switch_h / card_art). Used by BOTH the
## workbench preview and the game (engine/scripts/ui/settings.gd) — one builder, no duplicated face.
static func settings_dialog(entries: Array, width: float = 540.0, opts: Dictionary = {}) -> Control:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", int(opts.get("row_gap", 12)))
	var to: Dictionary = opts.get("toggle", {})
	for e in entries:
		# entries default to the toggle row; "info" (read-only label + value) and "action"
		# (a tappable button row, optionally two-tap) share the same card surface + style dict.
		match String((e as Dictionary).get("kind", "toggle")):
			"info":
				content.add_child(info_card(e, to))
			"action":
				content.add_child(action_card(e, to))
			_:
				content.add_child(toggle_card(e, to))
	# an optional centered FOOTER LINK — the Privacy Policy hyperlink the game wires to OS.shell_open
	# (App Store expects a reachable policy link for apps with purchases). Off by default so the
	# workbench preview stays a pure toggle list — the parallel of mail_dialog's footer note.
	var footer_text := String(opts.get("footer_text", ""))
	if footer_text != "":
		var link := LinkButton.new()
		link.text = footer_text
		link.underline = LinkButton.UNDERLINE_MODE_ALWAYS
		link.add_theme_font_override("font", plain_font())
		link.add_theme_font_size_override("font_size", int(opts.get("footer_font", FS.FINE)))   # privacy link — readable default (was 14)
		link.add_theme_color_override("font_color", Color(Pal.BARK, 0.85))
		link.add_theme_color_override("font_hover_color", Color(Pal.BARK, 1.0))
		var on_footer: Callable = opts.get("on_footer", Callable())
		if on_footer.is_valid():
			link.pressed.connect(func() -> void: on_footer.call())
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(link)
		content.add_child(row)
	return dialog_frame(content, width, opts)

## The VAULT (piggy-bank) dialog — the shared frame dressed in the twig border, wrapping the jar hero +
## a gem-balance read + the reused green price CTA. Game-state-agnostic (like settings_dialog): `state`
## carries the numbers + the claim callback, so BOTH the workbench preview and the game (ui/vault.gd)
## build the SAME face. state: { balance:int, cap:int, price:String, claimable:bool, claim_min:int,
## on_claim:Callable }.
static func vault_dialog(state: Dictionary, width: float = 460.0, opts: Dictionary = {}) -> Control:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", int(opts.get("row_gap", 12)))
	content.alignment = BoxContainer.ALIGNMENT_CENTER

	# the gem-balance read (icon + number) — the reference's "gem 320"
	var bal := HBoxContainer.new()
	bal.alignment = BoxContainer.ALIGNMENT_CENTER
	bal.add_theme_constant_override("separation", 8)
	bal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bal.add_child(make_icon("gem", float(opts.get("balance_icon", 34))))
	var bnum := _kit_label(str(int(state.get("balance", 0))), int(opts.get("balance_font", FS.TITLE)), Pal.INK)
	bnum.add_theme_font_override("font", plain_font())          # plain standard face, not the chunky display font
	bnum.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bal.add_child(bnum)
	content.add_child(bal)

	# the jar on its plate (sliced art when present, else a code-drawn vessel with the same metrics)
	content.add_child(_vault_jar(int(state.get("balance", 0)), int(state.get("cap", 1)),
		float(opts.get("jar_px", 200)), float(opts.get("plate_px", 220))))

	# the pitch line — the longer you play, the better the deal
	# vault pitch — enlarged (was 20)
	var pitch := _kit_label(String(opts.get("pitch", "Premium you've earned, saved up — claim it all.")), int(opts.get("pitch_font", FS.BODY)), Color(Pal.BARK, 0.95))
	pitch.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pitch.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pitch.add_theme_font_override("font", plain_font())          # plain standard face, not the chunky display font
	content.add_child(pitch)

	# the green price CTA — the SHARED pill_button (reused), claimable-gated (dim + a hint below)
	var claimable: bool = bool(state.get("claimable", true))
	var cta := pill_button(String(state.get("price", "")), {"bg": "green", "icon": "gem",
		"font": int(opts.get("cta_font", FS.HEADING)), "enabled": true, "shadow": true, "corner": 22.0})
	cta.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cta.modulate = Color(1, 1, 1, 1.0 if claimable else 0.55)
	var on_claim: Callable = state.get("on_claim", Callable())
	if on_claim.is_valid():
		cta.pressed.connect(func() -> void: on_claim.call())
	content.add_child(cta)
	if not claimable:
		var hint := HBoxContainer.new()
		hint.alignment = BoxContainer.ALIGNMENT_CENTER
		hint.add_theme_constant_override("separation", 4)
		hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# vault "keep playing" hint — enlarged (was 20)
		var hl := _kit_label(String(opts.get("hint_text", "Keep playing — it fills at")), FS.BODY, Color(Pal.BARK, 0.8))
		hl.add_theme_font_override("font", plain_font())          # plain standard face, not the chunky display font
		hl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hint.add_child(hl)
		hint.add_child(make_icon("gem", 16))
		# matches the hint text (was 20)
		var hn := _kit_label(str(int(state.get("claim_min", 0))), FS.BODY, Color(Pal.BARK, 0.8))
		hn.add_theme_font_override("font", plain_font())          # plain standard face, not the chunky display font
		hn.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hint.add_child(hn)
		content.add_child(hint)

	return dialog_frame(content, width, opts)

## The jar hero seated on its base plate: vault_plate.png behind + vault_jar.png over (cleaned), when
## present; else a code-drawn vessel with a GOLD fill rising to balance/cap — the fallback lifted from
## the old ui/vault.gd `_make_jar`, so the read survives until the art lands (the kit invariant).
static func _vault_jar(balance: int, cap: int, jar_px: float, plate_px: float) -> Control:
	var box := Control.new()
	var box_w: float = maxf(jar_px, plate_px)
	# the oval plate sits UNDER the jar: the jar's base sinks into the plate's top third (overlap), so the
	# jar reads as resting on it (the reference). plate_h follows the sprite's wide aspect (~139/550).
	var plate_h: float = plate_px * 0.255
	var overlap: float = plate_h * 0.55
	var box_h: float = jar_px + plate_h - overlap
	box.custom_minimum_size = Vector2(box_w, box_h)
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var plate_tex := _meadow_tex("vault_plate.png")
	if plate_tex != null:
		var pl := TextureRect.new()
		pl.name = "VaultPlate"
		pl.texture = plate_tex
		pl.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pl.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pl.custom_minimum_size = Vector2(plate_px, plate_h)
		pl.size = pl.custom_minimum_size
		pl.position = Vector2((box_w - plate_px) / 2.0, box_h - plate_h)   # plate's bottom = box bottom
		pl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(pl)                                                  # added FIRST → drawn under the jar
	var jar_tex := _meadow_tex("vault_jar_shell.png")
	var fill_tex := _meadow_tex("vault_acorn_fill.png")
	if jar_tex != null and fill_tex != null:
		var frac := clampf(float(balance) / float(maxi(1, cap)), 0.0, 1.0)
		var jar_x := (box_w - jar_px) / 2.0
		var fill_clip := Control.new()
		fill_clip.name = "VaultAcornFill"
		fill_clip.clip_contents = true
		fill_clip.position = Vector2(jar_x, jar_px * (1.0 - frac))
		fill_clip.size = Vector2(jar_px, jar_px * frac)
		fill_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var fill_art := TextureRect.new()
		fill_art.name = "VaultAcornFillArt"
		fill_art.texture = fill_tex
		fill_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		fill_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		fill_art.position = Vector2(0.0, -jar_px * (1.0 - frac))
		fill_art.size = Vector2(jar_px, jar_px)
		fill_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fill_clip.add_child(fill_art)
		box.add_child(fill_clip)
		var jr := TextureRect.new()
		jr.name = "VaultJarShell"
		jr.texture = jar_tex
		jr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		jr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		jr.custom_minimum_size = Vector2(jar_px, jar_px)
		jr.size = jr.custom_minimum_size
		jr.position = Vector2(jar_x, 0)                                   # jar base at y=jar_px, over the plate
		jr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(jr)
		return box
	# --- code-drawn fallback (no jar art) — vessel + gold fill, adapted from the old _make_jar -------
	var frac := clampf(float(balance) / float(maxi(1, cap)), 0.0, 1.0)
	var jx := (box_w - jar_px) / 2.0
	var body := Panel.new()
	body.position = Vector2(jx, 0); body.size = Vector2(jar_px, jar_px)
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(Pal.CREAM, 0.65)
	bs.set_corner_radius_all(int(jar_px * 0.28))
	bs.set_border_width_all(5); bs.border_color = Pal.BARK
	body.add_theme_stylebox_override("panel", bs)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(body)
	var inset := 8.0
	var fill := Panel.new()
	var fh: float = maxf(6.0, (jar_px - inset * 2.0) * frac)
	fill.position = Vector2(jx + inset, jar_px - inset - fh)
	fill.size = Vector2(jar_px - inset * 2.0, fh)
	var fs := StyleBoxFlat.new()
	fs.bg_color = Color(Pal.GOLD, 0.92) if frac > 0.0 else Color(Pal.GOLD, 0.0)
	fs.set_corner_radius_all(int(jar_px * 0.22))
	fill.add_theme_stylebox_override("panel", fs)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(fill)
	return box

## A small kit sprite (the ✓ check, the mystery chest, …) cleaned + fit into a px box.
static func _kit_sprite(rel: String, px: float) -> TextureRect:
	var t := TextureRect.new()
	t.texture = clean_tex_path(Look.kit(rel), 256)
	t.custom_minimum_size = Vector2(px, px)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

## A day's reward as the ICON ONLY — the daily card shows the reward TYPE, never a number (the amount
## is a claim-time surprise and keeps the small card uncluttered). Picks the premium currency (gems >
## coins > water). Shop cards show their count separately; this is daily-only.
static func _daily_reward(reward: Dictionary, px: float = 40.0, shadow: bool = false) -> Control:
	var icon_id := "coin"
	if int(reward.get("gems", 0)) > 0:
		icon_id = "gem"
	elif int(reward.get("coins", 0)) > 0:
		icon_id = "coin"
	elif int(reward.get("water", 0)) > 0:
		icon_id = "water"
	elif String(reward.get("cosmetic", "")) != "":
		icon_id = "star"
	return daily_icon(icon_id, px, shadow)

# The daily card wears the SAME shared cut-paper edge as every other paper component — a finer tear at
# card scale (amp 4). corner is derived from the card WIDTH per-call (a small cell and the wide capstone
# read with the same rounded proportion), so it is intentionally omitted here.
const DAILY_CARD_CP_DEFAULTS := {"deckle": true, "corner": 22, "deckle_amp": 4, "deckle_freq": 5, "rim_width": 2, "edge_shadow": true}
# The two tones the daily face uses, straight from the shared paper roles — no new palette.
const DAILY_CREAM_FILL := Pal.CREAM   # = PAPER_SURFACES["cream"] — days 1-6 + the today top layer
const DAILY_GOLD_FILL := Pal.GOLD     # = PAPER_SURFACES["gold"]  — the today under-layer + day 7
# The daily reward ICON's shape-true drop shadow (silhouette-following, warm-tinted) — a soft down-right cast.
const DAILY_ICON_SHADOW := {"shadow_alpha": 0.32}

## The SHARED daily card BACKGROUND — the code-drawn cut-paper card (engine/scripts/ui/cut_paper.gd) with
## the torn edge + tiled paper fibre + soft shadow. ONE face so BOTH the workbench mock and the real login
## dialog draw the same card (login.gd reaches this kit through Game.kit_script()). Returns a full-rect, mouse-transparent
## Control holding the deckled panel(s); the caller anchors its OWN content (label/icon/action) OVER it.
## `tone`: "cream" (days 1-6) · "today" (the DOUBLE layer: a gold panel below a cream one, to highlight the
## current day) · "gold" (day 7 — a single golden layer). `cp_opts` = the shared normalized cut-paper edge
## knobs (defaults to DAILY_CARD_CP_DEFAULTS). `opts`: corner (px, else size.x·corner_frac) · corner_frac
## (default 0.13) · gold_inflate / gold_drop (the today under-layer's peek/offset, px; defaults centered).
static func daily_card_face(size: Vector2, tone: String, cp_opts: Dictionary = {}, opts: Dictionary = {}) -> Control:
	var o: Dictionary = (cp_opts.duplicate() if not cp_opts.is_empty()
		else cut_paper_opts_from_config({}, "daily_card", DAILY_CARD_CP_DEFAULTS))
	# corner tracks the card width so a small cell and a wide capstone keep the same rounded proportion.
	o["corner"] = float(opts.get("corner", maxf(6.0, size.x * float(opts.get("corner_frac", 0.13)))))
	var tile := cut_paper_tile()
	var face := Control.new()
	face.name = "DailyCardFace"
	face.custom_minimum_size = size
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if tone == "today":
		# DOUBLE LAYER: a gold panel behind, inflated evenly on all sides, so a golden deckled rim peeks around
		# the cream panel on top. The gold (bottom) layer casts the card's ground shadow; the cream (top) layer's
		# own shadow is OFF (a second shadow between the two layers reads muddy).
		var inflate := float(opts.get("gold_inflate", size.x * 0.045))
		var drop := float(opts.get("gold_drop", 0.0))
		var gold: Control = load(CUT_PAPER).new()
		gold.name = "DailyGoldLayer"
		gold.mouse_filter = Control.MOUSE_FILTER_IGNORE
		gold.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		gold.offset_left = -inflate; gold.offset_right = inflate
		gold.offset_top = -inflate + drop; gold.offset_bottom = inflate + drop
		gold.configure(o, DAILY_GOLD_FILL, PAPER_EDGE, tile)
		face.add_child(gold)
		var cream: Control = load(CUT_PAPER).new()
		cream.name = "DailyCreamLayer"
		cream.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cream.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var co := o.duplicate(); co["edge_shadow"] = false   # top layer casts no shadow — the gold below does
		cream.configure(co, DAILY_CREAM_FILL, PAPER_EDGE, tile)
		face.add_child(cream)
	else:
		var panel: Control = load(CUT_PAPER).new()
		panel.name = "DailyCardLayer"
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		panel.configure(o, DAILY_GOLD_FILL if tone == "gold" else DAILY_CREAM_FILL, PAPER_EDGE, tile)
		face.add_child(panel)
	return face

## A make_icon with the shared SHAPE-TRUE drop shadow (silhouette-following, warm-tinted) baked in — the
## daily cards use it so every reward icon sits on its own soft shadow. `shadow` off, or a missing/gliph-only
## icon, falls back to the plain make_icon.
static func daily_icon(id: String, px: float, shadow: bool = true) -> Control:
	if not shadow:
		return make_icon(id, px)
	var tex := _icon_tex(id)
	if tex == null:
		return make_icon(id, px)      # glyph fallback — no image to shadow
	var img := tex.get_image()
	var shad := _icon_rect(ImageTexture.create_from_image(add_drop_shadow(img, DAILY_ICON_SHADOW)), px)
	return shad if shad != null else make_icon(id, px)

## The shared SMALL CARD — one tile used by BOTH the Daily grid and the Shop grid (improve once, both
## benefit). Top→bottom: an optional POPULAR ribbon ("Popular"/"Best value"/…), an optional label
## ("Day N"), the main content (a reward dict · the mystery chest · OR a shop icon + count), and an
## action (the GREEN shared pill_button as a Claim or a price, ✓ when done, or nothing). today/milestone
## wear a configurable rim/glow. d keys: label/day, ribbon, reward|icon(+count)|mystery, state, price,
## claim_text, on_claim, on_buy.
static func daily_card(d: Dictionary, opts: Dictionary = {}) -> Control:
	var cw: float = float(opts.get("cell_w", 96.0))
	var ch: float = float(opts.get("cell_h", 116.0))
	var state := String(d.get("state", "future"))
	var milestone := bool(d.get("mystery", false))
	var btn_opts: Dictionary = opts.get("btn", {})
	var ribbon := String(d.get("ribbon", ""))
	# the highlight rim/glow: today + a milestone day wear configurable ones; everything else is plain
	var badge := "plain"
	if state == "today":
		badge = String(opts.get("today_badge", "gold glow"))
	elif milestone:
		badge = String(opts.get("milestone_badge", "amber glow"))
	if state == "today":
		ch *= float(opts.get("today_grow", 1.0))   # off by default — the 3-row grid keeps even rows

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(cw, ch)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# The DAILY grid opts into the CODE-DRAWN cut-paper face (opts.cut_paper) — the ONE shared daily card
	# background: cream for days 1-6, the gold-under-cream DOUBLE layer for today, a single gold layer for a
	# milestone/day-7 card. The panel then keeps a TRANSPARENT stylebox holding only the content margins so
	# the label/icon/action sit inside the deckled edge; the face is added to `outer` below as the background.
	# The SHOP grid (the other daily_card caller) leaves cut_paper off and keeps its nine-patch card unchanged.
	var use_cp := bool(opts.get("cut_paper", false))
	var tone := "today" if state == "today" else ("gold" if milestone else "cream")
	var face: Control = null
	var bgp := Look.kit("kit/daily_card.png")
	if use_cp:
		face = daily_card_face(Vector2(cw, ch), tone, opts.get("cp", {}), opts.get("face", {}))
		var pad := StyleBoxFlat.new()
		pad.bg_color = Color(0, 0, 0, 0)
		pad.content_margin_left = 8; pad.content_margin_right = 8
		pad.content_margin_top = 7; pad.content_margin_bottom = 7
		panel.add_theme_stylebox_override("panel", pad)
	elif bool(opts.get("cell_art", true)) and ResourceLoader.exists(bgp):
		var st := StyleBoxTexture.new()
		st.texture = clean_tex_path(bgp, 256)
		st.set_texture_margin_all(float(opts.get("cell_slice", 28.0)))
		st.content_margin_left = 8; st.content_margin_right = 8
		st.content_margin_top = 7; st.content_margin_bottom = 7
		panel.add_theme_stylebox_override("panel", st)
	else:
		var cf := StyleBoxFlat.new()
		cf.bg_color = Color(Pal.CREAM, 0.85)
		cf.set_corner_radius_all(12); cf.set_border_width_all(1); cf.border_color = Color(Pal.BARK, 0.4)
		cf.content_margin_left = 8; cf.content_margin_right = 8
		cf.content_margin_top = 7; cf.content_margin_bottom = 7
		panel.add_theme_stylebox_override("panel", cf)
	if state == "done":
		panel.modulate = Color(1, 1, 1, 0.6)
		if face != null:
			face.modulate = Color(1, 1, 1, 0.6)

	# Content is ABSOLUTELY positioned inside `inner` so each region sits independently and none shifts the
	# others: the reward icon DEAD-CENTRE of the card, the label pinned near the top (tunable Y), the
	# action near the bottom (tunable Y, kept INSIDE), and the ribbon floating as a banner OVER the top.
	var inner := Control.new()
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(inner)
	# ONE uniform content scale (design reference = 160px wide): the icon, every font, the ribbon, the
	# button AND the position offsets all scale TOGETHER with the card, so the proportions stay CONSTANT as
	# the dialog grows — no more small text/icon stranded in a big card (everything was capped before).
	var s: float = cw / 160.0
	var label_font := maxi(8, int(24.0 * s))   # the "Day N" label — larger, more legible (was 18)
	var count_font := maxi(8, int(21.0 * s))
	# the bottom action is the SHARED pill_button — so its font tracks the Button component (opts.btn.font),
	# scaled to the card like everything else, instead of a constant. Edit the Button slider, every card follows.
	var claim_font := maxi(8, int(float(btn_opts.get("font", FS.FINE)) * s))
	var label_y: float = float(opts.get("label_y", 12.0)) * s
	var claim_y: float = float(opts.get("claim_y", 14.0)) * s

	# the main content — the mystery chest · a reward icon (daily) · or a big icon(+count) (shop) — sits
	# DEAD CENTRE of the card (a full-rect CenterContainer), independent of the label/action positions.
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(center)
	if d.has("node") and d.node != null:
		center.add_child(d.node as Control)   # a GAME-injected hero (real piece preview, a 2-currency bundle, …)
	elif milestone:
		# the mystery marker: the "?" chest by default, OR a per-day sprite the caller supplies (e.g. day 4's
		# gift box) via `mystery_icon` — so individual mystery days can read distinctly.
		center.add_child(_kit_sprite(String(d.get("mystery_icon", "kit/daily_chest.png")), cw * 0.56))
	elif d.has("reward"):
		center.add_child(_daily_reward(d.get("reward", {}), cw * 0.56, use_cp))   # icon a touch bigger (no number); cut-paper cards shadow it
	elif d.has("icon"):
		var ic_col := VBoxContainer.new()
		ic_col.alignment = BoxContainer.ALIGNMENT_CENTER
		ic_col.add_theme_constant_override("separation", int(2.0 * s))
		ic_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic_col.add_child(make_icon(String(d.icon), cw * 0.52))
		if int(d.get("count", 0)) > 0:
			var cn := _kit_label(str(int(d.count)), count_font, Pal.INK)
			cn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			ic_col.add_child(cn)
		center.add_child(ic_col)

	# the label ("Day N") — pinned near the TOP, shifted down by label_y (tunable). shop packs omit it.
	if d.has("label") or d.has("day"):
		var dl := _kit_label(String(d.get("label", "Day %d" % int(d.get("day", 1)))), label_font, Pal.INK if state != "today" else Pal.LEAF.darkened(0.15))
		dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var label_x: float = float(opts.get("label_x", 0.0)) * s   # text H nudge (slider), scaled with the card
		dl.anchor_left = 0.0; dl.anchor_right = 1.0
		dl.anchor_top = 0.0; dl.anchor_bottom = 0.0
		dl.offset_left = label_x; dl.offset_right = label_x
		dl.offset_top = label_y; dl.offset_bottom = label_y
		dl.grow_vertical = Control.GROW_DIRECTION_END
		inner.add_child(dl)

	# BOTTOM action — a price (shop) / Claim (today) is the SHARED green pill_button, a done day a ✓.
	# Anchored to the bottom and LIFTED up by claim_y so it sits INSIDE the card (was overflowing below).
	var act_text := ""
	var act_cb := Callable()
	var act_icon := ""
	if d.has("price"):
		act_text = String(d.price); act_cb = d.get("on_buy", Callable())
		act_icon = String(d.get("price_icon", ""))     # a currency glyph on the price (gem/coin); "" = USD
	elif state == "today":
		act_text = String(d.get("claim_text", "Claim")); act_cb = d.get("on_claim", Callable())
	var act_node: Control = null
	if act_text != "":
		var co := btn_opts.duplicate()
		co["bg"] = "green"; co["text"] = act_text; co["icon"] = act_icon
		co["font"] = claim_font
		co["icon_size"] = int(claim_font + 8 * s)   # the currency glyph scales with the button font too
		var btn := pill_button(act_text, co)
		if d.has("affordable") and not bool(d.get("affordable", true)):
			btn.modulate = Color(1, 1, 1, 0.45)   # can't afford → the buy CTA greys (still pressable: wallet wiggles)
		if act_cb.is_valid():
			btn.pressed.connect(func() -> void: act_cb.call())
		act_node = btn
	elif state == "done":
		act_node = _kit_sprite("kit/daily_check.png", cw * 0.34)
	if act_node != null:
		var act_wrap := CenterContainer.new()
		act_wrap.anchor_left = 0.0; act_wrap.anchor_right = 1.0
		act_wrap.anchor_top = 1.0; act_wrap.anchor_bottom = 1.0
		act_wrap.offset_left = 0.0; act_wrap.offset_right = 0.0
		act_wrap.offset_top = -claim_y; act_wrap.offset_bottom = -claim_y
		act_wrap.grow_vertical = Control.GROW_DIRECTION_BEGIN   # grows UPWARD from the lifted bottom edge
		act_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		act_wrap.add_child(act_node)
		inner.add_child(act_wrap)

	# the optional INFO badge — top-right. A card's `on_info` Callable makes it an INTERACTIVE "i" button
	# (a tap opens the game's detail sheet, without buying); otherwise the design-time `info_icon` toggle
	# shows a static disc. The icon scales/positions with the card like everything else.
	var on_info: Callable = d.get("on_info", Callable())
	if on_info.is_valid() or bool(opts.get("info_icon", false)):
		var ip: float = maxf(14.0, cw * 0.2)
		var im: float = 6.0 * s                       # corner margin scales with the card too
		var info: Control
		if on_info.is_valid():
			var ib := Button.new()
			ib.focus_mode = Control.FOCUS_NONE
			var itex := clean_tex_path(Look.kit("shared/icon_question.png"), 192)
			if itex != null:
				var ist := StyleBoxTexture.new(); ist.texture = itex
				ib.add_theme_stylebox_override("normal", ist)
				ib.add_theme_stylebox_override("hover", ist)
				var isp: StyleBoxTexture = ist.duplicate(); isp.modulate_color = Color(0.85, 0.85, 0.85)
				ib.add_theme_stylebox_override("pressed", isp)
			ib.pressed.connect(func() -> void: on_info.call())
			info = ib
		else:
			info = _kit_sprite("shared/icon_question.png", ip)
		info.anchor_left = 1.0; info.anchor_right = 1.0
		info.anchor_top = 0.0; info.anchor_bottom = 0.0
		info.offset_left = -(ip + im); info.offset_right = -im
		info.offset_top = im; info.offset_bottom = im + ip
		inner.add_child(info)

	if not use_cp:
		_apply_day_badge(panel, badge)   # the configurable rim/glow on today + milestone cards (the cut-paper face carries its own highlight)

	# Wrap the card so the ribbon draws ON TOP of the card BORDER — inside the panel it was hidden behind
	# the nine-patch lip + the day-badge rim. The ribbon is a BANNER over the top edge, with a tunable SIZE
	# and H position, so it reads clearly and never shifts the content below. The panel holds everything else.
	var outer := Control.new()
	outer.custom_minimum_size = Vector2(cw, ch)
	outer.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	outer.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if face != null:
		face.set_anchors_preset(Control.PRESET_FULL_RECT)
		outer.add_child(face)          # the cut-paper background, BEHIND the panel content
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer.add_child(panel)
	if ribbon != "":
		# the ribbon scales with the card too (× s), so it keeps the SAME proportion to the text/icon/button
		var rb := _ribbon_badge(ribbon, s * float(opts.get("ribbon_scale", 1.0)))
		rb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rb.anchor_left = 0.5; rb.anchor_right = 0.5
		rb.anchor_top = 0.0; rb.anchor_bottom = 0.0
		rb.grow_horizontal = Control.GROW_DIRECTION_BOTH
		rb.grow_vertical = Control.GROW_DIRECTION_BOTH
		rb.offset_left = float(opts.get("ribbon_x", 0.0)) * s    # H nudge (slider), scaled with the card
		rb.offset_right = float(opts.get("ribbon_x", 0.0)) * s
		rb.offset_top = float(opts.get("ribbon_y", -10.0)) * s   # rides over the top edge, ON TOP of the border
		outer.add_child(rb)                                      # added AFTER the panel → drawn on top
	return outer

## The POPULAR ribbon — a small merchandising tag ("Popular" / "Best value" / …). The red shop_tag art
## (cream text) when present, else a code STRAW pill (ink text). Mirrors the game shop's _badge.
static func _ribbon_badge(text: String, scale: float = 1.0) -> Control:
	var s := maxf(0.4, scale)             # the SIZE knob — scales the pads + the font together
	var pop := PanelContainer.new()
	pop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fg := Pal.CREAM
	var tex := clean_tex_path(Look.kit("kit/shop_tag.png"), 256)
	if tex != null:
		var stx := StyleBoxTexture.new()
		stx.texture = tex
		stx.content_margin_left = 15 * s; stx.content_margin_right = 15 * s
		stx.content_margin_top = 5 * s; stx.content_margin_bottom = 8 * s
		pop.add_theme_stylebox_override("panel", stx)
	else:
		var pp := StyleBoxFlat.new()
		pp.bg_color = Pal.STRAW
		pp.set_corner_radius_all(int(8 * s))
		pp.content_margin_left = 10 * s; pp.content_margin_right = 10 * s
		pp.content_margin_top = 3 * s; pp.content_margin_bottom = 4 * s
		pop.add_theme_stylebox_override("panel", pp)
		fg = Pal.INK
	pop.add_child(_kit_label(text, maxi(8, int(13 * s)), fg))
	return pop

## A reusable PROGRESS BAR — a rounded track with a honey fill clipped to `frac` (0..1). Art mode draws
## the kit's prog_track / prog_fill capsules as NINE-SLICE pills (rendered at native height, then the whole
## bar uniformly scaled to its display box so the caps stay round at any size — see progress_bar's note);
## else a code-drawn StyleBoxFlat track + fill (the legacy look). opts: height (px — the display height),
## width (px), art (bool), label ("" = none; centered, e.g. "75%"), star_knob (bool — a star sprite riding
## the fill head), fill_width_pct / fill_height_pct / fill_x / fill_y, fill_shadow + fill_shadow_params.
## Standalone so improving it lifts every site (the Level dialog now; the home unlock % later).
static func progress_bar(frac: float, opts: Dictionary = {}) -> Control:
	var h: float = float(opts.get("height", 20.0))     # the DISPLAY height the bar shrinks to fit
	var f: float = clampf(frac, 0.0, 1.0)
	var use_art: bool = bool(opts.get("art", true))
	var base_name := String(opts.get("name", "ProgressBar"))
	# fill_color re-hues the fill (a resource bank's line colour): art mode tints the honey capsule,
	# the code-drawn fallback paints it directly. Absent → the classic honey/straw fill.
	var fill_color: Color = opts.get("fill_color", Color(0, 0, 0, 0))
	var track_color: Color = opts.get("track_color", Color(Pal.INK, 0.12))
	var fill_w_scale := clampf(float(opts.get("fill_width_pct", 100.0)) / 100.0, 0.05, 3.0)
	var fill_h_scale := clampf(float(opts.get("fill_height_pct", 100.0)) / 100.0, 0.05, 3.0)
	var fill_dx := float(opts.get("fill_x", 0.0))
	var fill_dy := float(opts.get("fill_y", 0.0))
	var holder := Control.new()
	holder.name = base_name
	holder.custom_minimum_size = Vector2(float(opts.get("width", 280.0)), h)
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# live progress: the layout closures read this meta each pass, so progress_bar_set_frac can move the
	# fill WITHOUT rebuilding the bar (the unlock strip tweens through it every frame).
	holder.set_meta("frac", f)
	if bool(opts.get("shadow", false)):
		var bar_sh := Look.shadow_rect(h * 0.5, _shared_shadow_params(opts.get("shadow_params", {}) as Dictionary))
		bar_sh.name = _progress_name(base_name, "Shadow")
		bar_sh.set_anchors_preset(Control.PRESET_FULL_RECT)
		bar_sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(bar_sh)
	var art_cap := int(opts.get("art_cap", 512))
	# THE CUT-PAPER WELL (engine/scripts/ui/paper_progress.gd). Present → the bar is drawn as a well sunk
	# into the sheet under it with a raised capsule lying in it, instead of the nine-slice art capsules or
	# the flat StyleBoxFlat pair. ABSENT is the default and every other caller leaves it absent, so the
	# level dialog, the residents banks and the workbench preview render exactly what they always did.
	var paper: Dictionary = opts.get("paper", {}) as Dictionary
	var track_tex: Texture2D = clean_tex_path(Look.kit(String(opts.get("track_art", "kit/prog_track.png"))), art_cap) if use_art and paper.is_empty() else null
	var fill_tex: Texture2D = clean_tex_path(Look.kit(String(opts.get("fill_art", "kit/prog_fill.png"))), art_cap) if use_art and paper.is_empty() else null
	var fill_shadow_params: Dictionary = opts.get("fill_shadow_params", {}) as Dictionary
	if not paper.is_empty():
		_progress_build_paper(holder, base_name, paper, h, fill_color if fill_color.a > 0.0 else Pal.LEAF,
			fill_w_scale, fill_h_scale, fill_dx, fill_dy, f)
	elif track_tex != null and fill_tex != null:
		# ART mode — track & fill are NINE-SLICE capsules. A 9-slice pill's rounded caps only stay round
		# when the node is drawn at least as tall as the cap (margin = radius); squashing it shorter ovals
		# them out. So we draw the caps at their NATIVE texture height on an inner "stage", then uniformly
		# SCALE the whole stage down to the bar's display box — the caps shrink but keep their shape. Because
		# the stage is always at native height (no vertical scaling), only the HORIZONTAL centre stretches.
		var nat_h: float = float(track_tex.get_height())
		var t_margin: int = int(round(nat_h * 0.5))                 # capsule radius = half the height
		var base_fill_h: float = float(fill_tex.get_height())
		var inset: float = (nat_h - base_fill_h) * 0.5              # the fill sits inside the track rim
		if opts.has("fill_rim_pct"):
			inset = nat_h * clampf(float(opts.get("fill_rim_pct", 0.0)) / 100.0, 0.0, 0.49)
			base_fill_h = nat_h - inset * 2.0
		var stage := Control.new()
		stage.name = _progress_name(base_name, "Stage")
		stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(stage)
		var track := NinePatchRect.new()
		track.name = _progress_name(base_name, "Track")
		track.texture = track_tex
		track.patch_margin_left = t_margin; track.patch_margin_right = t_margin
		track.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage.add_child(track)
		var fill_shadow: Panel = null
		if bool(opts.get("fill_shadow", false)):
			fill_shadow = _progress_shadow_panel(_progress_name(base_name, "FillShadow"))
			stage.add_child(fill_shadow)
		var fill_clip := Control.new()
		fill_clip.name = _progress_name(base_name, "FillClip")
		fill_clip.clip_contents = true
		fill_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage.add_child(fill_clip)
		var fill := NinePatchRect.new()
		fill.name = _progress_name(base_name, "Fill")
		fill.texture = fill_tex
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if fill_color.a > 0.0:
			fill.self_modulate = fill_color
		fill_clip.add_child(fill)
		var art_holder_ref: WeakRef = weakref(holder)
		var stage_ref: WeakRef = weakref(stage)
		var track_ref: WeakRef = weakref(track)
		var fill_clip_ref: WeakRef = weakref(fill_clip)
		var fill_ref: WeakRef = weakref(fill)
		var fill_shadow_ref: WeakRef = weakref(fill_shadow) if fill_shadow != null else null
		var lay_art := _progress_layout_art.bind(art_holder_ref, stage_ref, track_ref, fill_clip_ref,
			fill_ref, fill_shadow_ref, nat_h, base_fill_h, inset, fill_w_scale, fill_h_scale, fill_dx,
			fill_dy, f, fill_shadow_params)
		holder.resized.connect(lay_art)
		holder.ready.connect(lay_art)
		holder.set_meta("relayout", lay_art)
	else:
		# code-drawn fallback (legacy look) — a rounded track with a clip-revealed straw fill
		var track := Panel.new()
		track.name = _progress_name(base_name, "Track")
		track.set_anchors_preset(Control.PRESET_FULL_RECT)
		var tsb := StyleBoxFlat.new()
		tsb.bg_color = track_color
		tsb.set_corner_radius_all(int(h * 0.5))
		track.add_theme_stylebox_override("panel", tsb)
		track.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(track)
		var fill_shadow: Panel = null
		if bool(opts.get("fill_shadow", false)):
			fill_shadow = _progress_shadow_panel(_progress_name(base_name, "FillShadow"))
			holder.add_child(fill_shadow)
		var fill_clip := Control.new()
		fill_clip.name = _progress_name(base_name, "FillClip")
		fill_clip.clip_contents = true
		fill_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(fill_clip)
		var fill := Panel.new()
		fill.name = _progress_name(base_name, "Fill")
		var fsb := StyleBoxFlat.new()
		fsb.bg_color = fill_color if fill_color.a > 0.0 else Pal.STRAW
		fsb.set_corner_radius_all(int(h * 0.5))
		fill.add_theme_stylebox_override("panel", fsb)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fill_clip.add_child(fill)
		var fb_holder_ref: WeakRef = weakref(holder)
		var fb_fill_clip_ref: WeakRef = weakref(fill_clip)
		var fb_fill_ref: WeakRef = weakref(fill)
		var fb_fill_shadow_ref: WeakRef = weakref(fill_shadow) if fill_shadow != null else null
		var fb_fsb_ref: WeakRef = weakref(fsb)
		var lay := _progress_layout_flat.bind(fb_holder_ref, fb_fill_clip_ref, fb_fill_ref,
			fb_fill_shadow_ref, fb_fsb_ref, h, fill_w_scale, fill_h_scale, fill_dx, fill_dy, f,
			fill_shadow_params)
		# Layout is driven by ready/resized (which only fire once the bar is IN a tree) — NOT a bare
		# call_deferred, so a bar built-and-freed before any layout (a discarded preview) can't fire a
		# lambda over freed captures.
		holder.resized.connect(lay)
		holder.ready.connect(lay)
		holder.set_meta("relayout", lay)
	# --- optional star knob riding the fill head ---
	if bool(opts.get("star_knob", false)):
		var knob := make_icon("star", h * 1.4)
		knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(knob)
		var knob_ref: WeakRef = weakref(knob)
		var knob_holder_ref: WeakRef = weakref(holder)
		var place := _progress_place_knob.bind(knob_ref, knob_holder_ref, f, h)
		holder.resized.connect(place)
		holder.set_meta("knob_place", place)
	# --- optional centered label (e.g. "75%") ---
	var label := String(opts.get("label", ""))
	if label != "":
		var l := _kit_label(label, int(h * 0.7), Pal.INK)
		l.name = String(opts.get("label_name", "ProgressBarLabel"))
		l.set_anchors_preset(Control.PRESET_FULL_RECT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.clip_text = true
		holder.add_child(l)
	return holder

static func _progress_layout_art(holder_ref: WeakRef, stage_ref: WeakRef, track_ref: WeakRef,
		fill_clip_ref: WeakRef, fill_ref: WeakRef, fill_shadow_ref: WeakRef, nat_h: float,
		base_fill_h: float, inset: float, fill_w_scale: float, fill_h_scale: float, fill_dx: float,
		fill_dy: float, f: float, fill_shadow_params: Dictionary) -> void:
	var hld := holder_ref.get_ref() as Control
	var stg := stage_ref.get_ref() as Control
	var trk := track_ref.get_ref() as Control
	var clip := fill_clip_ref.get_ref() as Control
	var fl := fill_ref.get_ref() as NinePatchRect
	var fsh: Panel = fill_shadow_ref.get_ref() as Panel if fill_shadow_ref != null else null
	if hld == null or stg == null or trk == null or clip == null or fl == null:
		return
	var disp := hld.size
	if disp.x <= 0.0 or disp.y <= 0.0:
		return
	var s: float = disp.y / nat_h
	var stage_w: float = disp.x / s
	stg.scale = Vector2(s, s)
	stg.size = Vector2(stage_w, nat_h)
	trk.size = Vector2(stage_w, nat_h)
	var base_fill_w: float = stage_w - inset * 2.0
	var fill_w: float = maxf(1.0, base_fill_w * fill_w_scale)
	var fill_h: float = maxf(1.0, base_fill_h * fill_h_scale)
	var fill_pos := Vector2(inset + (base_fill_w - fill_w) * 0.5 + fill_dx / s,
		inset + (base_fill_h - fill_h) * 0.5 + fill_dy / s)
	var cur_f: float = clampf(float(hld.get_meta("frac", f)), 0.0, 1.0)
	var clip_w: float = maxf(fill_h, fill_w * cur_f)
	clip.position = fill_pos
	clip.size = Vector2(clip_w, fill_h)
	fl.position = Vector2.ZERO
	fl.size = Vector2(fill_w, fill_h)
	var f_margin := int(round(maxf(1.0, fill_h * 0.5)))
	fl.patch_margin_left = f_margin; fl.patch_margin_right = f_margin
	if fsh != null:
		fsh.position = fill_pos
		fsh.size = Vector2(clip_w, fill_h)
		_configure_progress_shadow(fsh, fill_h * 0.5, fill_shadow_params, s)

static func _progress_layout_flat(holder_ref: WeakRef, fill_clip_ref: WeakRef, fill_ref: WeakRef,
		fill_shadow_ref: WeakRef, fsb_ref: WeakRef, h: float, fill_w_scale: float,
		fill_h_scale: float, fill_dx: float, fill_dy: float, f: float, fill_shadow_params: Dictionary) -> void:
	var hld := holder_ref.get_ref() as Control
	var clip := fill_clip_ref.get_ref() as Control
	var fl := fill_ref.get_ref() as Panel
	var fsh: Panel = fill_shadow_ref.get_ref() as Panel if fill_shadow_ref != null else null
	var fill_style := fsb_ref.get_ref() as StyleBoxFlat
	if hld == null or clip == null or fl == null or fill_style == null:
		return
	var w := hld.size.x
	var fill_w := maxf(1.0, w * fill_w_scale)
	var fill_h := maxf(1.0, h * fill_h_scale)
	var fill_pos := Vector2((w - fill_w) * 0.5 + fill_dx, (h - fill_h) * 0.5 + fill_dy)
	var cur_f: float = clampf(float(hld.get_meta("frac", f)), 0.0, 1.0)
	var fw := maxf(fill_h, fill_w * cur_f)
	clip.position = fill_pos
	clip.size = Vector2(fw, fill_h)
	fl.position = Vector2.ZERO
	fl.size = Vector2(fill_w, fill_h)
	fill_style.set_corner_radius_all(int(fill_h * 0.5))
	if fsh != null:
		fsh.position = fill_pos
		fsh.size = Vector2(fw, fill_h)
		_configure_progress_shadow(fsh, fill_h * 0.5, fill_shadow_params, 1.0)

## THE CUT-PAPER WELL — the third face Kit.progress_bar can wear, and the only one drawn from the game's
## own paper material rather than from a baked capsule pair. The material (every colour and reach below)
## is engine/scripts/ui/paper_progress.gd; this is only how the nodes are stacked:
##
##   Track           a CutPaperPanel capsule — the well's FLOOR, with the lip's dark crease as its rim
##   FillClip        clipped to the track's box, so the capsule's cast shadow lands on the FLOOR and
##                   never on the sheet the well is cut into
##     └ Fill        a second CutPaperPanel capsule, the raised green card, wearing the scene's own
##                   directional shadow (paper_progress hands it Paper.surface_cp)
##   InsetShadow     LAST, so the lip's inner shadow falls across the fill too — which is what the mock
##                   draws: its fill's top edge is measurably darker than its bottom one
##
## The fill is SIZED to the visible run rather than clipped to it, because a code-drawn capsule can just
## be short: that gives its head a real round cap (and therefore a real cast shadow) at every fraction,
## which a clipped nine-slice cannot have.
static func _progress_build_paper(holder: Control, base_name: String, paper: Dictionary, h: float,
		fill_color: Color, fill_w_scale: float, fill_h_scale: float, fill_dx: float, fill_dy: float,
		f: float) -> void:
	var tile := cut_paper_tile()
	var feather := float(paper.get("feather", 2.0))
	# a capsule's corner radius is half its own height, which is where cut_paper's legacy arc sampling
	# stops being invisible — both shapes here ask for a chord instead (see CutPaperPanel.arc_step).
	var arc := float(paper.get("arc_step", 0.0))
	var track: Control = load(CUT_PAPER).new()
	track.name = _progress_name(base_name, "Track")
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.configure({"deckle_amp": 0.0, "rim_width": float(paper.get("crease_w", 3.0)),
		"edge_feather": feather, "edge_shadow": false, "corner": h * 0.5, "arc_step": arc},
		paper.get("well_fill", Pal.CREAM), paper.get("crease", Pal.BARK), tile)
	holder.add_child(track)              # `edge_shadow: false`: a SUNK well casts nothing downward

	var clip := Control.new()
	clip.name = _progress_name(base_name, "FillClip")
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(clip)

	var fill: Control = load(CUT_PAPER).new()
	fill.name = _progress_name(base_name, "Fill")
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill_cp: Dictionary = (paper.get("fill_cp", {}) as Dictionary).duplicate()
	fill_cp.merge({"deckle_amp": 0.0, "rim_width": float(paper.get("fill_rim_w", 2.0)),
		"edge_feather": feather, "shadow_reach": 0.0, "arc_step": arc}, true)
	# `shadow_reach: 0` and NOT `edge_shadow: false`. The DIRECTIONAL halo that came in with fill_cp IS
	# this capsule's shadow, and cut_paper's straight-down drop shadow on top of it would cast a second
	# one — but `edge_shadow` maps to `draw_shadow`, which gates BOTH (cut_paper.gd `_draw_edge_halo`
	# returns early on it). Spelled that way the capsule cast nothing at all: probed off its head on the
	# rig it read 0.070 at 1px and 0.006 at 2, against the mock's 0.292 · 0.242 · 0.204 · 0.172 · 0.113
	# · 0.059 out to 7px — the fill was printed into the well instead of lying in it, under a comment
	# claiming the halo was doing the work. The drop shadow has its OWN `shadow_reach > 0` guard, so
	# zeroing the reach silences it and leaves the halo drawing.
	fill.configure(fill_cp, fill_color, paper.get("fill_rim", fill_color.darkened(0.185)), tile)
	clip.add_child(fill)

	var inset: Control = load(INSET_SHADOW).new()
	inset.name = _progress_name(base_name, "InsetShadow")
	holder.add_child(inset)

	var lay := _progress_layout_paper.bind(weakref(holder), weakref(track), weakref(clip),
		weakref(fill), weakref(inset), paper, fill_w_scale, fill_h_scale, fill_dx, fill_dy, f)
	holder.resized.connect(lay)
	holder.ready.connect(lay)
	holder.set_meta("relayout", lay)


static func _progress_layout_paper(holder_ref: WeakRef, track_ref: WeakRef, clip_ref: WeakRef,
		fill_ref: WeakRef, inset_ref: WeakRef, paper: Dictionary, fill_w_scale: float,
		fill_h_scale: float, fill_dx: float, fill_dy: float, f: float) -> void:
	var hld := holder_ref.get_ref() as Control
	var trk := track_ref.get_ref() as Control
	var clip := clip_ref.get_ref() as Control
	var fl := fill_ref.get_ref() as Control
	var ins := inset_ref.get_ref() as Control
	if hld == null or trk == null or clip == null or fl == null or ins == null:
		return
	var disp := hld.size
	if disp.x <= 0.0 or disp.y <= 0.0:
		return
	var corner := disp.y * float(paper.get("corner_frac", 0.5))
	trk.position = Vector2.ZERO
	trk.size = disp
	trk.corner = corner
	clip.position = Vector2.ZERO
	clip.size = disp
	var inset_x := float(paper.get("fill_inset_x", 1.5))
	var fill_h := maxf(1.0, disp.y * fill_h_scale)
	var run := maxf(1.0, (disp.x - inset_x * 2.0) * fill_w_scale)
	var cur_f: float = clampf(float(hld.get_meta("frac", f)), 0.0, 1.0)
	# floored at the capsule's own height: below that the head and the tail cap are the same arc, so a
	# shorter fill is not a capsule at all but a lens, and it would pop into one as the tween crossed the
	# floor. At 0% that leaves a round green nub sitting in the well beside a "0%" read-out.
	#
	# THE MOCK DOES NOT SETTLE THIS — it draws one bar at 67% and says nothing about an empty one, and an
	# earlier note here claimed the nub was "what the mock draws". It is a design call: the nub reads as
	# the bar's own start marker, and the alternative (nothing at all below one capsule-length) trades it
	# for a fill that appears out of empty track. Left as the nub because the previous slate bar showed
	# one too, so no shipped behaviour changes here; flagged for the owner rather than settled quietly.
	fl.position = Vector2(inset_x + fill_dx, (disp.y - fill_h) * 0.5 + fill_dy)
	fl.size = Vector2(maxf(fill_h, run * cur_f), fill_h)
	fl.corner = fill_h * float(paper.get("corner_frac", 0.5))
	ins.position = Vector2.ZERO
	ins.size = disp
	ins.configure(corner, float(paper.get("inset_reach", 5.0)), float(paper.get("inset_alpha", 0.5)),
		paper.get("inset_tint", Pal.BARK), float(paper.get("inset_falloff", 3.0)))


static func _progress_place_knob(knob_ref: WeakRef, holder_ref: WeakRef, f: float, h: float) -> void:
	var k := knob_ref.get_ref() as Control
	var hld := holder_ref.get_ref() as Control
	if k != null and hld != null:
		var cur_f: float = clampf(float(hld.get_meta("frac", f)), 0.0, 1.0)
		k.position = Vector2(maxf(0.0, hld.size.x * cur_f - h * 0.7), -h * 0.2)

## Move an already-built progress_bar's fill to `f` WITHOUT rebuilding it — the layout closures
## re-read the "frac" meta. The unlock strip tweens through this every frame.
static func progress_bar_set_frac(bar: Control, f: float) -> void:
	if bar == null or not is_instance_valid(bar):
		return
	bar.set_meta("frac", clampf(f, 0.0, 1.0))
	# has_meta first: Object.get_meta treats a NULL default as "no default given" and pushes an
	# error, and "knob_place" only exists on a bar built with the star knob on.
	for key: String in ["relayout", "knob_place"]:
		if not bar.has_meta(key):
			continue
		var cb: Variant = bar.get_meta(key)
		if cb is Callable and (cb as Callable).is_valid():
			(cb as Callable).call()

static func _progress_name(base_name: String, suffix: String) -> String:
	return "%s%s" % [base_name, suffix]

static func _progress_shadow_panel(node_name: String) -> Panel:
	var sh := Panel.new()
	sh.name = node_name
	sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sh.set_anchors_preset(Control.PRESET_TOP_LEFT)
	sh.add_theme_stylebox_override("panel", StyleBoxFlat.new())
	return sh

static func _configure_progress_shadow(sh: Panel, corner: float, p: Dictionary, stage_scale: float) -> void:
	var s := maxf(stage_scale, 0.001)
	var alpha := clampf(float(p.get("alpha", 0.0)), 0.0, 1.0)
	var tint := Look.shadow_color(alpha)
	var sb := sh.get_theme_stylebox("panel") as StyleBoxFlat
	if sb == null:
		return
	sb.draw_center = true
	sb.bg_color = tint
	sb.shadow_color = tint
	sb.shadow_offset = Vector2(float(p.get("offset_x", 0.0)) / s, float(p.get("offset_y", 0.0)) / s)
	sb.shadow_size = int(maxf(float(p.get("blur", 0.0)) / s, 0.0))
	var spread := float(p.get("spread", 0.0)) / s
	sb.set_expand_margin_all(spread)
	sb.set_corner_radius_all(int(maxf(corner + spread, 0.0)))

## --- the Meadow level badge ----------------------------------------------------------
## Progression resolves one of 25 authored, shadow-free 256x256 badge bases. The public tier remains
## zero-based and is clamped, while the native lv_num Label remains independent and player-readable.
const LEVEL_BADGE_VARIANTS := 25

## The workbench-tuned level-badge geometry from a saved config (cfg["level_badge"]). Every
## position/size knob is a PERCENT of the badge px so the emblem scales to any size.
static func level_badge_opts_from_config(cfg: Dictionary) -> Dictionary:
	var g: Dictionary = cfg.get("level_badge", {}) if cfg is Dictionary else {}
	return {
		"num_size":    float(g.get("num_size", 32.0)),   # the level number font, % of px
		"num_x":       float(g.get("num_x", 0.0)),       # number offset, % of px (side / margin)
		"num_y":       float(g.get("num_y", 5.0)),
		"num_burn":    float(g.get("num_burn", 0.0)),    # engraved 'burn' on the number (0..100)
	}

## Build one clamped Meadow badge base under the centered native level NUMBER. `px` is the square size;
## `num_font` overrides the number font. `show_all` remains accepted for constructor compatibility.
static func level_badge(opts: Dictionary, tier: int, level: int, px: float, num_font: int = -1, show_all: bool = false) -> Control:
	var root := Control.new()
	root.custom_minimum_size = Vector2(px, px)
	root.size = Vector2(px, px)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var variant := clampi(tier, 0, LEVEL_BADGE_VARIANTS - 1) + 1
	var tex := _meadow_tex("level_badge_%02d.png" % variant)
	if tex != null:
		var art := TextureRect.new()
		art.name = "lv_badge_art"
		art.texture = tex
		# The source keeps a uniform 20px cutout gutter. Scale that gutter beyond the logical box so the
		# painted badge still honors the HUD's shared visible-edge margin.
		var painted_span := 216.0 # 256 - 2 * 20
		var art_px := px * 256.0 / painted_span
		var art_gutter := px * 20.0 / painted_span
		# expand_mode must be set BEFORE size: with the default KEEP mode the texture's own pixel
		# size is the rect's minimum, so a smaller art.size silently clamps back up to 256.
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.position = Vector2(-art_gutter, -art_gutter)
		art.size = Vector2(art_px, art_px)
		art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(art)
	else:                                                # no art at all -> warm honey token, no blank rect
		var coin := StyleBoxFlat.new()
		coin.bg_color = Color("#F4CF82"); coin.set_corner_radius_all(int(px / 2.0))
		coin.set_border_width_all(2); coin.border_color = Color("#8D6B35")
		var panel := Panel.new()
		panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		panel.add_theme_stylebox_override("panel", coin)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(panel)
	# the level number on top, centered then nudged by num_x / num_y (the "side and margin")
	var num := Label.new()
	num.name = "lv_num"
	num.text = str(level)
	num.set_anchors_preset(Control.PRESET_FULL_RECT)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	num.offset_left = px * float(opts.get("num_x", 0.0)) / 100.0
	num.offset_right = num.offset_left
	num.offset_top = px * float(opts.get("num_y", 0.0)) / 100.0
	num.offset_bottom = num.offset_top
	num.add_theme_font_size_override("font_size", _level_badge_font(level, px, opts, num_font))
	var burn := clampf(float(opts.get("num_burn", 0.0)) / 100.0, 0.0, 1.0)
	if burn > 0.0:
		# "burned into the coin": dark engraved ink + a light lower emboss + a soft dark halo (matches the
		# banner-text burn). Intensity (0..1) deepens the ink and grows the emboss/outline.
		num.add_theme_color_override("font_color", Color("#4A2E14").darkened(0.35 * burn))
		num.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.25 + 0.45 * burn))
		num.add_theme_constant_override("shadow_offset_x", int(round(1.0 + 2.0 * burn)))
		num.add_theme_constant_override("shadow_offset_y", int(round(2.0 + 3.0 * burn)))
		num.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.12 + 0.33 * burn))
		num.add_theme_constant_override("outline_size", int(round(2.0 + 4.0 * burn)))
	else:
		num.add_theme_color_override("font_color", Pal.INK)
		num.add_theme_constant_override("outline_size", 0)
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(num)
	return root

## The number font px: num_font when given (> 0), else num_size% of px, stepped down as digits grow.
static func _level_badge_font(level: int, px: float, opts: Dictionary, num_font: int) -> int:
	if num_font > 0:
		return num_font
	var base := px * float(opts.get("num_size", 32.0)) / 100.0
	var digits := str(maxi(0, level)).length()
	if digits >= 3:
		base *= 0.67
	elif digits == 2:
		base *= 0.81
	return int(maxf(8.0, base))

## The Level MEDALLION for dialogs/previews — the shared Meadow level badge (the same emblem the
## HUD chip and level dialog wear), tuned by the saved level_badge config so those surfaces match. Kept
## as a named helper so the level dialog reads clearly; `px` is the emblem size. opts may carry
## `number_font` (absolute override) — otherwise the tuned num_size drives the number.
static func level_medallion(level: int, px: float = 120.0, opts: Dictionary = {}) -> Control:
	var geo := level_badge_opts_from_config(load_config(CONFIG_PATH))
	var med := level_badge(geo, Look.level_badge_index(level), level, px, int(opts.get("number_font", -1)))
	med.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return med

## A dedicated FRAME for the Level dialog (NOT the shared dialog_frame): the level_frame parchment border
## (nine-patch), the gold level_title pill banner centered over the top edge, inner padding, and NO scroll
## / NO ✕ (the reference has none). `content` is laid out statically (the dialog is short). opts:
## banner_text, title_font, slice (nine-patch), pad, top_pad (room under the title pill).
static func level_frame(content: Control, width: float = 460.0, opts: Dictionary = {}) -> Control:
	var banner_text := String(opts.get("banner_text", "Level"))
	var title_font := int(opts.get("title_font", FS.HEADING))
	var sl := float(opts.get("slice", 56.0))
	var pad := float(opts.get("pad", 26.0))
	var top_pad := float(opts.get("top_pad", 70.0))
	# CRISP CHROME, SCALED CONTENT (mirrors dialog_frame): chrome built at the on-screen target
	# width = design × content_scale; content laid out at `width` and uniformly scaled to fill it.
	var content_scale: float = maxf(0.01, float(opts.get("content_scale", 1.0)))
	var target_w: float = width * content_scale
	var card := PanelContainer.new()
	var fp := Look.kit("kit/level_frame.png")
	# the parchment border, polished like every other sprite (defringe + alpha-feather) so its outer edge
	# reads SOFT, not roughly-cut. max_dim 1024 ≥ the source's longest side → no resize, so the nine-patch
	# slice margins (sl) stay exact in texture pixels. clean_tex_path returns null when the art is missing.
	var ftex := clean_tex_path(fp, 1024)
	if ftex != null:
		var st := StyleBoxTexture.new()
		st.texture = ftex
		st.set_texture_margin(SIDE_LEFT, sl); st.set_texture_margin(SIDE_TOP, sl)
		st.set_texture_margin(SIDE_RIGHT, sl); st.set_texture_margin(SIDE_BOTTOM, sl)
		st.content_margin_left = pad; st.content_margin_right = pad
		st.content_margin_top = top_pad; st.content_margin_bottom = pad
		card.add_theme_stylebox_override("panel", st)
	else:
		var cf := StyleBoxFlat.new()
		cf.bg_color = Pal.CREAM; cf.border_color = Pal.BARK
		cf.set_corner_radius_all(28); cf.set_border_width_all(3)
		cf.content_margin_left = pad; cf.content_margin_right = pad
		cf.content_margin_top = top_pad; cf.content_margin_bottom = pad
		card.add_theme_stylebox_override("panel", cf)
	card.custom_minimum_size = Vector2(target_w, 0)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if is_equal_approx(content_scale, 1.0):
		card.add_child(content)
	else:
		var scaler := ScaleContainer.new()
		scaler.scale_factor = content_scale
		scaler.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scaler.add_child(content)
		card.add_child(scaler)
	# the title pill overlays the top edge, centered (added after the card → drawn on top)
	var wrap := Control.new()
	wrap.custom_minimum_size.x = target_w
	wrap.add_child(card)
	var title := _level_title_pill(banner_text, title_font, minf(target_w, 460.0))
	wrap.add_child(title)
	var dock := func() -> void:
		if is_instance_valid(title) and is_instance_valid(card) and is_instance_valid(wrap):
			title.position = Vector2((card.size.x - title.size.x) * 0.5, -title.size.y * 0.5)
			wrap.custom_minimum_size = card.size
	card.resized.connect(dock)
	title.resized.connect(dock)
	wrap.ready.connect(dock)
	return wrap

## The Level title is the same shared Meadow ribbon atom used by Rush and the other dialogs.
static func _level_title_pill(text: String, font: int, width: float = 360.0) -> Control:
	var ribbon := _banner(text, font, BANNER_H, width, false, 0.0, null, 0.0, 0.0, 0.0,
		"meadow_v2/title_banner.png", "", 54.0, 54.0, width * 0.62)
	ribbon.name = "LevelTitle"
	return ribbon

## The dialog CTA button — the SHARED pill_button wearing the registered "level green" badge background
## (Kit.BADGES["level green"], the level_btn sprite). The SAME atom for the level dialog's Collect / Got it
## AND the mail/info "Got it" footer, so the green badged button is authored ONCE. `opts.btn` supplies the
## base pill style (font · padding); bg / art / art_rel / icon are forced to the level badge. SHRINK_CENTER
## so it sits centred under its column. Callers connect `.pressed` themselves.
static func cta_button(text: String, opts: Dictionary = {}) -> Button:
	var bo: Dictionary = (opts.get("btn", {}) as Dictionary).duplicate()
	bo["bg"] = "green"; bo["art"] = true; bo["art_rel"] = String(BADGES["level green"]); bo["icon"] = ""
	var btn := pill_button(text, bo)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return btn

## The whole LEVEL dialog: the dedicated frame + medallion + "X / Y ★ earned" + progress_bar + the
## "N more ★ to reach Level N+1" line (info) OR a reward chip row (levelup) + the bottom button (the
## shared cta_button with the green level_btn bg). `data` keys: level, earned, next, into, span,
## remaining, mode ("info"|"levelup"), gift ({water,gems}), on_button (Callable). opts: see
## level_opts_from_config (frame + progress + btn style). Used by BOTH the workbench preview and the game.
static func level_dialog(data: Dictionary, width: float = 460.0, opts: Dictionary = {}) -> Control:
	var mode := String(data.get("mode", "info"))
	var lvl := int(data.get("level", 1))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", int(opts.get("gap", 14)))
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	# medallion
	var med := level_medallion(lvl, float(opts.get("medallion_px", 120.0)), opts)
	med.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(med)
	# "X / Y ★ earned"
	var tally := _kit_label(TranslationServer.translate("%d / %d ★ earned") % [int(data.get("earned", 0)), int(data.get("next", 0))], int(opts.get("tally_font", FS.BODY)), Pal.INK)
	tally.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(tally)
	# the progress bar (reusable component, fraction of the way through this level)
	var span: int = maxi(1, int(data.get("span", 1)))
	var frac: float = clampf(float(int(data.get("into", 0))) / float(span), 0.0, 1.0)
	var bar := progress_bar(frac, opts.get("progress", {}))
	bar.custom_minimum_size.x = width * 0.78
	col.add_child(bar)
	# levelup → the earned reward row (cream chips); info → the "N more ★" hint line
	if mode == "levelup":
		var gift: Dictionary = data.get("gift", {})
		var reward := {"water": int(gift.get("water", 0)), "gems": int(gift.get("gems", 0))}
		if _reward_total(reward) > 0:
			var rrow := reward_chip(reward, opts.get("btn", {}))
			rrow.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			col.add_child(rrow)
	else:
		var nxt := _kit_label(TranslationServer.translate("%d more ★ to reach Level %d") % [int(data.get("remaining", 0)), lvl + 1], int(opts.get("hint_font", FS.FINE)), Pal.BARK)
		nxt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(nxt)
	# the bottom button — the SHARED cta_button (the registered "level green" badge), the SAME atom the
	# mail/info "Got it" footer uses, so the green badged button is authored once.
	var btn_text := TranslationServer.translate("Collect") if mode == "levelup" else TranslationServer.translate("Got it")
	var btn := cta_button(btn_text, opts)
	var cb: Callable = data.get("on_button", Callable())
	if cb.is_valid():
		btn.pressed.connect(func() -> void: cb.call())
	col.add_child(btn)
	return level_frame(col, width, opts)

## Draw a highlight rim/glow over a day card (see DAY_BADGES). A code-drawn border-only overlay (plus a
## coloured shadow for the "glow" styles) so it's a SAVED setting the workbench can switch, not baked art.
static func _apply_day_badge(panel: Control, key: String) -> void:
	if key == "" or key == "plain":
		return
	var hi := Panel.new()
	hi.set_anchors_preset(Control.PRESET_FULL_RECT)
	hi.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := StyleBoxFlat.new()
	s.draw_center = false
	s.set_corner_radius_all(16)
	s.set_border_width_all(3)
	var gold := Pal.STRAW
	var amber := Color("#E0922E")
	match key:
		"gold rim":
			s.border_color = gold
		"gold glow":
			s.border_color = gold
			s.shadow_color = Color(gold, 0.55); s.shadow_size = 9
		"amber glow":
			s.border_color = amber
			s.shadow_color = Color(amber, 0.50); s.shadow_size = 9
		"leaf glow":
			s.border_color = Pal.LEAF
			s.shadow_color = Color(Pal.LEAF, 0.50); s.shadow_size = 9
		_:
			s.border_color = gold
	hi.add_theme_stylebox_override("panel", s)
	panel.add_child(hi)

## The cell width that fits `cols` cards across a dialog of `width` (≈ width − the card margins).
## The card CONTENT is then built at this width, so a card's min never exceeds 1/cols and a row
## cannot overflow (a fixed-min Claim button used to force the dialog wider).
static func _card_cell_w(width: float, cols: int, gap: int) -> float:
	return maxf(48.0, (width - 56.0 - (cols - 1) * gap) / float(cols))

## Pack `cards` into centred rows of exactly `cols` under `content`, appending every built card to
## `made` (the list the resize fit re-measures). A partial last row centres.
static func _card_rows(cards: Array, cols: int, gap: int, co: Dictionary, content: Control, made: Array) -> void:
	var i := 0
	while i < cards.size():
		var r := HBoxContainer.new()
		r.alignment = BoxContainer.ALIGNMENT_CENTER
		r.add_theme_constant_override("separation", gap)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for j in cols:
			if i + j < cards.size():
				var c := daily_card(cards[i + j], co)
				r.add_child(c)
				made.append(c)
		content.add_child(r)
		i += cols

## Pixel-exact sizing: on every relayout each card becomes 1/cols of the ACTUAL content width (so a
## 2-card row keeps the SAME card size as a full one), with the aspect-correct height.
static func _fit_cards(content: Control, made: Array, cols: int, gap: int, aspect: float) -> void:
	var fit := func() -> void:
		if not is_instance_valid(content):
			return
		var cwf := (content.size.x - (cols - 1) * gap) / float(cols)
		for c in made:
			if is_instance_valid(c):
				(c as Control).custom_minimum_size = Vector2(maxf(40.0, cwf), maxf(40.0, cwf * aspect))
	content.resized.connect(fit)
	fit.call_deferred()

## A GRID of the shared small cards, EXACTLY `cols` per row filling the width — the content for the
## daily dialog. `_shop_sections` is this same grid plus a divider per section; both share
## _card_cell_w / _card_rows / _fit_cards, and differ ONLY in the values noted below.
static func _card_grid(cards: Array, width: float, opts: Dictionary) -> Control:
	var cols: int = maxi(1, int(opts.get("cols", 3)))
	var gap: int = int(opts.get("cell_h_gap", 12))
	var cw := _card_cell_w(width, cols, gap)
	# Preserve the EDITED card's ASPECT RATIO when the cells shrink to fit `cols` across — forcing 3 per row
	# must not squash the card tall-and-thin; derive the cell HEIGHT from the original cell_w:cell_h ratio.
	# NOTE the daily card's own 96×116 default shape — deliberately NOT the shop's 112×150.
	var aspect: float = float(opts.get("cell_h", 116.0)) / maxf(1.0, float(opts.get("cell_w", 96.0)))
	var co := opts.duplicate()
	co["cell_w"] = cw
	co["cell_h"] = cw * aspect
	co["cut_paper"] = bool(opts.get("cut_paper", true))   # the daily grid draws the code-drawn cut-paper face by default
	# (the card's fonts / icon / ribbon all scale from cell_w inside daily_card — uniform proportions)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", int(opts.get("cell_v_gap", 12)))
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var made: Array = []
	_card_rows(cards, cols, gap, co, content, made)
	_fit_cards(content, made, cols, gap, aspect)
	return content

## The DAILY dialog — the shared frame with a grid of day cards.
static func daily_dialog(days: Array, width: float = 460.0, opts: Dictionary = {}) -> Control:
	return dialog_frame(_card_grid(days, width, opts), width, opts)

## --- the discovery (tier-ladder) card + dialog ------------------------------------------------------
## One discovery tile, built straight onto the SHARED slot cell (Kit.slot_cell) so discovery, the bag, and the
## board all read as ONE component — there is NO separate tier-cell type. A DISCOVERED tier wears the FILLED
## well holding its piece; an UNDISCOVERED tier wears the LOCKED well — the baked gold padlock KEPT, no acorn
## cost, and no "?" glyph (the locked well stands in for it). Each tile carries a plain lower-right tier
## number, with no badge decoration. A MARKED tier (the tapped/asked one) is flagged by the engine sparkle.
## `opts` are slot-cell opts (the inherited slot look + the discovery `cell_w/cell_h`, `mark_glow`/`mark_twinkle`)
## from tiers_opts_from_config.
## The opts may carry a discovery make_content(d, px) — bridged to the slot cell's make_content(px) here.
## d keys: tier, seen, marked, icon|node. Private to _tiers_grid; the dialog is the only public surface.
static func _discovery_cell(d: Dictionary, opts: Dictionary) -> Control:
	var seen := bool(d.get("seen", false))
	var sd := {
		"state": ("filled" if seen else "locked"),
		"cost": 0,                                          # discovery has no buy price → the locked well is its baked padlock alone
		"marked": bool(d.get("marked", false)),
	}
	# bridge the discovery make_content(d, px) → the slot cell's make_content(px); else a pre-built node or
	# an icon id (the workbench preview). Only a discovered tier carries a piece.
	var mk: Callable = opts.get("make_content", Callable())
	if seen and mk.is_valid():
		sd["make_content"] = func(px: float) -> Control: return mk.call(d, px)
	elif seen and d.get("node") is Control:
		sd["content"] = d.get("node")
	elif seen and String(d.get("icon", "")) != "":
		sd["icon"] = String(d.get("icon"))
	# a tappable discovery cell (the Producing dialog's line cells drill into that line's tier ladder) —
	# slot_cell makes a FILLED cell a Button when on_tap is valid; a locked (unseen) cell ignores it.
	if d.get("on_tap") is Callable and (d.get("on_tap") as Callable).is_valid():
		sd["on_tap"] = d.get("on_tap")
	# dim_bg recedes the WELL for a discovered-but-inactive line (the Producing dialog) — forward it to slot_cell.
	if bool(d.get("dim_bg", false)):
		sd["dim_bg"] = true
	var cell := slot_cell(sd, opts)
	if bool(opts.get("show_num", true)):
		var tier := int(d.get("tier", 0))
		if tier > 0:
			var cw := float(opts.get("cell_w", 150.0))
			var ch := float(opts.get("cell_h", 150.0))
			var font := int(maxf(14.0, cw * 0.18))
			var num := _kit_label(str(tier), font, Color(Pal.INK, 0.92))
			num.name = "TierNumber"
			num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			num.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			num.anchor_left = 1.0; num.anchor_top = 1.0; num.anchor_right = 1.0; num.anchor_bottom = 1.0
			num.offset_left = -cw * 0.34
			num.offset_top = -ch * 0.26
			num.offset_right = -cw * 0.07
			num.offset_bottom = -ch * 0.04
			cell.add_child(num)
	return cell

## A GRID of discovery cells — plain reading order (tier 1 top-left, filling `cols` per row), exactly like the
## daily grid but with square tiles and NO woven vines (just the cards). The cell size scales to fit `cols`
## across the frame's content area; a partial last row centres.
static func _tiers_grid(entries: Array, width: float, opts: Dictionary) -> Control:
	var cols: int = maxi(1, int(opts.get("cols", 3)))
	var gap: int = int(opts.get("cell_gap", 16))
	# the cells fill the panel's INNER width — the card width minus the border's content padding on BOTH
	# sides. The discovery dialog uses the standard frame (no panel_pad override), so resolve the padding
	# from the chosen border — the SAME value dialog_frame pads to — keeping the right column inside it.
	# The pads (and the scrollbar reserve) are REAL px on the scaled card, so in layout space they cost
	# 1/content_scale — reserving them raw undersized the reserve, the row minimum then exceeded the true
	# available width, the body clamped UP to that minimum, and the right column poked past the clip
	# (fit() below re-derives from the clamped — still too wide — width, so it could not recover).
	var pad: float = float(opts.get("panel_pad_x", frame_border(String(opts.get("border", "parchment"))).get("pad_x", 26.0)))
	var g_scale: float = maxf(0.01, float(opts.get("content_scale", 1.0)))
	var avail: float = maxf(48.0, width - (2.0 * pad + SCROLLBAR_W) / g_scale)
	var cw: float = maxf(40.0, (avail - (cols - 1) * gap) / float(cols))
	var aspect: float = float(opts.get("cell_h", 150.0)) / maxf(1.0, float(opts.get("cell_w", 150.0)))
	var co := opts.duplicate()
	co["cell_w"] = cw
	co["cell_h"] = cw * aspect
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", gap)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var made: Array = []
	var i := 0
	while i < entries.size():
		var r := HBoxContainer.new()
		r.alignment = BoxContainer.ALIGNMENT_CENTER
		r.add_theme_constant_override("separation", gap)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for j in cols:
			if i + j < entries.size():
				var c := _discovery_cell(entries[i + j], co)
				r.add_child(c)
				made.append(c)
		content.add_child(r)
		i += cols
	# re-derive from the ACTUAL laid-out width (covers the responsive width_pct), with a sub-pixel safety so
	# rounding never pushes the right column past the border. The face follows (it fills the holder), so the
	# cell art tracks this too.
	var fit := func() -> void:
		if not is_instance_valid(content):
			return
		var cwf := maxf(40.0, (content.size.x - (cols - 1) * gap) / float(cols) - 0.5)
		for c in made:
			if is_instance_valid(c):
				(c as Control).custom_minimum_size = Vector2(cwf, cwf * aspect)
	content.resized.connect(fit)
	fit.call_deferred()
	return content

## The DISCOVERY dialog — the SAME shared frame as mail/daily/shop, on a SELECTABLE border (opts.border,
## default the twig board), with the gold ladder ribbon + its own ✕ riding on top, wrapping a plain grid
## of tier cells. Only the border + banner/✕ chrome + the card differ; there are NO vines (just the cards).
static func tiers_dialog(entries: Array, width: float = 620.0, opts: Dictionary = {}) -> Control:
	return dialog_frame(_tiers_grid(entries, width, opts), width, opts)

## Public alias for the tiers grid builder — lets a caller (the ladder) compose the grid WITH its own
## header (e.g. a generator icon) inside the shared dialog_frame, instead of tiers_dialog's grid-only body.
static func tiers_grid(entries: Array, width: float = 620.0, opts: Dictionary = {}) -> Control:
	return _tiers_grid(entries, width, opts)

## The SHOP dialog — the SAME shared frame, here filled with SECTIONS (each a vine divider + a centered
## row/grid of the SAME small card) rather than one flat grid. `sections` is [{caption, cards}, …] from
## demo_shop. Shared frame, sectioned shop content.
static func shop_dialog(sections: Array, width: float = 520.0, opts: Dictionary = {}) -> Control:
	return dialog_frame(_shop_sections(sections, width, opts), width, opts)

## A section divider — the section TITLE CENTRED (per the shop reference), flanked by leaf-sprig
## ornaments (kit/shop_sprig.png, cut from shop_asset.png; one mirrored) and a thin rule reaching each
## edge. (Replaces the old left-tab + vine strip.) Falls back to a plain centred title + rules if the
## sprig art is missing.
static func _kit_divider(caption: String) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.custom_minimum_size = Vector2(0, 40)
	var sp := Look.kit("kit/shop_sprig.png")
	var has_sprig := ResourceLoader.exists(sp)
	row.add_child(_div_rule())                         # left rule fills to the edge
	if has_sprig:
		row.add_child(_div_sprig(sp, false))           # leaves point INWARD, toward the title
	var cap := _kit_label(caption, FS.BODY, Color(Pal.INK, 0.95))
	cap.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(cap)
	if has_sprig:
		row.add_child(_div_sprig(sp, true))            # mirrored on the right
	row.add_child(_div_rule())                         # right rule fills to the edge
	return row

## A thin horizontal rule that fills the remaining width on a divider side.
static func _div_rule() -> Control:
	var line := ColorRect.new()
	line.color = Color(Pal.BARK, 0.30)
	line.custom_minimum_size = Vector2(0, 2)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line

## One leaf-sprig ornament flanking a divider title (optionally mirrored for the other side).
static func _div_sprig(path: String, flip: bool) -> Control:
	var t := TextureRect.new()
	t.texture = clean_tex_path(path, 256)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(46, 26)
	t.flip_h = flip
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

## The SHOP content: each section's vine divider + its cards laid into centered rows of `cols` (a 2-card
## section is a single centered row of two). Cards are built at the column width (like _card_grid) so they
## fit exactly, and `row_gap` adds generous breathing room BETWEEN rows + sections.
static func _shop_sections(sections: Array, width: float, opts: Dictionary) -> Control:
	var cols: int = maxi(1, int(opts.get("cols", 3)))
	var gap: int = int(opts.get("cell_h_gap", 12))
	var row_gap: int = int(opts.get("row_gap", 22))
	var cw := _card_cell_w(width, cols, gap)
	# the shop card's own default shape (112×150) — deliberately TALLER than the daily grid's 96×116;
	# keep the card's aspect ratio when it shrinks to fit cols across.
	var aspect: float = float(opts.get("cell_h", 150.0)) / maxf(1.0, float(opts.get("cell_w", 112.0)))
	var co := opts.duplicate()
	co["cell_w"] = cw
	co["cell_h"] = cw * aspect
	# (the card's fonts / icon / ribbon all scale from cell_w inside daily_card — uniform proportions)
	# NOTE: no `cut_paper` seed here — the shop leaves the card's own default standing.
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", row_gap)   # generous room BETWEEN rows + sections
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var made: Array = []
	for sec in sections:
		var s := sec as Dictionary
		content.add_child(_kit_divider(String(s.get("caption", ""))))
		_card_rows(s.get("cards", []), cols, gap, co, content, made)
	_fit_cards(content, made, cols, gap, aspect)
	return content

## --- config → opts (the SINGLE source of the params→opts transform) ------------------------------
## The workbench saves design settings to a JSON of {button, card, dialog, icon} param dicts. Both the
## workbench preview AND the game build their dialog from these helpers, so there is no duplicated
## transform: change a setting in the workbench, save, and the game reads the very same config.

## Read the saved settings JSON into a config dict ({} if missing/garbage — callers fall back to defaults).
## CACHED per path: a scene build calls this once PER widget (every home button, pill, dialog), so an
## uncached read re-opened + re-parsed the file dozens of times per build. The config file is immutable
## during play, so the cache holds for the session; the workbench clears it on Save (clear_config_cache).
## The returned dict is treated as READ-ONLY by callers (every opts-builder duplicates before mutating).
static var _config_cache: Dictionary = {}     # path -> parsed config Dictionary

static func load_config(path: String) -> Dictionary:
	if _config_cache.has(path):
		return _config_cache[path]
	var data: Dictionary = {}
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		if f != null:
			var parsed = JSON.parse_string(f.get_as_text())
			f.close()
			if parsed is Dictionary:
				data = parsed
	_config_cache[path] = data
	return data

## Publish a LIVE (unsaved) config into the cache so EVERY disk-reading builder (anything that calls
## load_config(path)) renders these values immediately, WITHOUT touching the file. The workbench calls
## this on each live edit: the mail/shop cards, the reward chips, and the borderless paper-role buttons
## resolve their cut-paper edge from load_config(CONFIG_PATH) rather than from a passed-in `cp`, so this
## is what lets an unsaved edge change preview across the whole button family at once instead of only on
## the one tile fed the live params directly. Save still owns the file (writes it + clears this cache).
static func set_config_cache(path: String, cfg: Dictionary) -> void:
	_config_cache[path] = cfg

## Drop the cached config so the next load_config re-reads from disk. Pass a path to clear just that
## file, or nothing to clear all. The workbench calls this after writing the settings file.
static func clear_config_cache(path := "") -> void:
	_shell_cache.clear()   # the polished disc shell derives from the badge config — drop it so a saved edit re-polishes
	_item_shadow_cache.clear()   # item-shadow stamps bake from the saved item_shadow_* params — rebake on save/live edit
	if path == "":
		_config_cache.clear()
	else:
		_config_cache.erase(path)

## The Claim / cost-pill STYLE opts: the Button's saved style (shadow / art / font / corner) + the
## Card's own badge, icon and claim label. (bg is NOT here — the kit fixes it by role: green Claim,
## cream cost pill.) Every key falls back to a default so a partial/empty config still builds.
static func card_btn_opts(cfg: Dictionary) -> Dictionary:
	var b: Dictionary = cfg.get("button", {})
	var c: Dictionary = cfg.get("card", {})
	var o := {
		"text": String(c.get("claim_text", "Claim")),
		"icon": (String(c.get("icon", "gem")) if bool(c.get("icon_on", false)) else ""),
		"icon_size": int(b.get("icon_size", 30)),
		"enabled": true,
		"font": int(b.get("font", FS.FINE)),
		"corner": int(b.get("corner", 16)),
		"art": bool(b.get("art", true)),
		"shadow": bool(b.get("shadow", false)),
		"shadow_params": Look.shadow_params(cfg),
	}
	var badge := String(c.get("badge", "auto"))
	if badge != "auto" and BADGES.has(badge) and String(BADGES[badge]) != "":
		o["art"] = true
		o["art_rel"] = String(BADGES[badge])
	return o

## The sprite (Look.kit-relative) for the Card's left-icon disc badge, resolved from the saved label.
static func card_icon_badge(cfg: Dictionary) -> String:
	var key := String((cfg.get("card", {}) as Dictionary).get("icon_badge", "disc light"))
	return String(ICON_BADGES.get(key, "shared/disc_round.png"))

## The SHARED FRAME's config section. It lives under "frame" now (its own standalone component); older
## saved files kept these keys under "dialog", so merge that as a fallback — the "frame" section wins.
## Each dialog's AUTHORED width as a % of the screen — the baseline its content (fonts, cells,
## padding) was tuned at. Content scales by global_width_pct / design_pct so every dialog renders
## at the SINGLE global width while keeping its proportions. This is a code constant (same category
## as cell sizes), NOT a workbench knob — the only width KNOB is the global frame.width_pct.
const DIALOG_DESIGN_PCT := {
	"dialog": 75.0, "daily": 75.0, "bag": 75.0,
	"shop": 85.0, "tiers": 85.0, "vault": 80.0,
	"settings": 50.0, "level": 50.0, "info": 58.0,
	"residents": 85.0,
}

## The ONE global dialog width, as a % of the screen — read from the shared frame config
## (cfg.frame.width_pct, falling back through cfg.dialog for back-compat). Clamped to [30,100].
static func frame_width_pct(cfg: Dictionary) -> float:
	return clampf(float(_frame_cfg(cfg).get("width_pct", 75.0)), 30.0, 100.0)

## The content scale for a dialog id = the global width / the dialog's authored design width.
## > 1 enlarges (e.g. settings 50→75 = 1.5×), < 1 shrinks (e.g. shop 85→75 ≈ 0.88×).
static func dialog_content_scale(cfg: Dictionary, id: String) -> float:
	var design: float = float(DIALOG_DESIGN_PCT.get(id, 75.0))
	return frame_width_pct(cfg) / maxf(1.0, design)

static func _frame_cfg(cfg: Dictionary) -> Dictionary:
	var m: Dictionary = (cfg.get("dialog", {}) as Dictionary).duplicate()
	m.merge(cfg.get("frame", {}), true)
	return m

## A PLAIN, regular-weight face for body text that should read as STANDARD UI text — not the cozy chunky/
## outlined display font the global theme applies (the "bold marker" look). The info sheet's rows AND the
## vault's body text use this with the outline off, so the labels/amounts/notes read as clean normal text.
## Public so ui/vault.gd (loaded by path) can share the SAME face. Cached per session.
static var _plain_cache: Font = null
static func plain_font() -> Font:
	if _plain_cache != null:
		return _plain_cache
	var sys := SystemFont.new()
	sys.font_names = PackedStringArray(["SF Pro Text", "Helvetica Neue", "Segoe UI", "Roboto", "Arial", "Verdana"])
	sys.font_weight = 400
	sys.generate_mipmaps = true
	_plain_cache = sys
	return _plain_cache

## The BOLD display face — the cozy theme font pushed heavier, for dialog/section TITLES (mock v2
## bolds every title). Public so ui/ dialogs (loaded by path) share the SAME face. Cached per session.
static var _bold_cache: Font = null
static func bold_font() -> Font:
	if _bold_cache != null:
		return _bold_cache
	var fv := FontVariation.new()
	fv.base_font = load("res://engine/scripts/ui/ui_font.gd")._face()
	fv.variation_embolden = 0.6
	_bold_cache = fv
	return _bold_cache

## The full mail_dialog STYLE opts from a saved config (card art/slice/stretch, banner, close, list,
## card fonts, and the Claim/cost-pill btn opts). Callers add entries_count / on_close / empty_text /
## banner_text and pass width separately. Used by BOTH the workbench dialog preview and the game.
static func dialog_opts_from_config(cfg: Dictionary) -> Dictionary:
	var d: Dictionary = _frame_cfg(cfg)
	var c: Dictionary = cfg.get("card", {})
	var strmap := {"stretch": 0, "tile": 1, "tile_fit": 2}
	# the SHARED cut-paper edge (the ONE knob set) read from the frame block; `corner` also drives the flat
	# card + banner geometry (card_corner), so the frame has a single corner value however it's drawn.
	var cp: Dictionary = cut_paper_opts_from_config(cfg, "frame", FRAME_CP_DEFAULTS)
	return {
		"border": String(d.get("border", "parchment")),   # the shared Frame item's Border picker (default parchment)
		"card_corner": float(cp["corner"]),
		"card_art": bool(d.get("card_art", true)),
		"card_slice_l": float(d.get("card_slice_l", 40)),
		"card_slice_t": float(d.get("card_slice_t", 40)),
		"card_slice_r": float(d.get("card_slice_r", 40)),
		"card_slice_b": float(d.get("card_slice_b", 40)),
		"card_h_stretch": int(strmap.get(String(d.get("card_h_stretch", "stretch")), 0)),
		"card_v_stretch": int(strmap.get(String(d.get("card_v_stretch", "stretch")), 0)),
		"card_title": int(c.get("title", 20)),
		"card_body": int(c.get("body", 15)),
		"banner_font": int(d.get("banner_font", FS.HEADING)),
		"banner_h": float(d.get("banner_h", 92)),
		"banner_icon": float(d.get("banner_icon", 54)),
		"banner_icon_on": bool(d.get("banner_icon_on", true)),
		"banner_text_x": float(d.get("banner_text_x", 0)),
		"banner_text_y": float(d.get("banner_text_y", 0)),
		"banner_text_pad_l": float(d.get("banner_text_pad_l", float(d.get("banner_h", 92)) * 0.55)),   # title↔left-tail room
		"banner_text_pad_r": float(d.get("banner_text_pad_r", float(d.get("banner_h", 92)) * 0.55)),   # title↔right-tail room
		"title_shadow": text_shadow_opts_from_config(cfg, "frame"),   # the SHARED text drop-shadow on the title
		"banner_pos": Vector2(float(d.get("banner_x", 0)), float(d.get("banner_y", 0))),
		"banner_icon_pos": Vector2(float(d.get("banner_icon_x", 130)), float(d.get("banner_icon_y", 19))),
		"close_size": float(d.get("close_size", 64)),
		"close_poke": Vector2(float(d.get("close_x", 12)), float(d.get("close_y", 12))),
		"list_max_h": float(d.get("list_max_h", 0)),
		"list_top_pad": float(d.get("list_top_pad", 0)),
		# CODE-DRAWN cut-paper sheet: when cp.deckle is on, the frame's background is a live CutPaperPanel
		# (the shared deckled edge) instead of the flat cream card, sized to any dialog with no stretch. The
		# normalized edge knob set (deckle · corner · amp · freq · rim · edge_shadow) rides under "cp".
		"cp": cp,
		# the reward-CARD's own shared edge + tint (its own component) forwarded to every mail_card row.
		"mail_cp": mail_card_opts_from_config(cfg)["mail_cp"],
		"mail_tint": mail_card_opts_from_config(cfg)["mail_tint"],
		"empty_font": int(d.get("empty_font", FS.BODY)),   # the empty-state note size — the Mail item's "Empty font" slider
		"icon_badge": card_icon_badge(cfg),
		"btn": card_btn_opts(cfg),
		# every DIALOG's slot cells wear the mocks' sage face (see DIALOG_CELL_OPEN_FILL). This builder is
		# the dialogs' shared root — the board builds its cells from bag_card_opts_from_config instead, so
		# the playable grid never picks this up.
		"dialog_cells": true,
	}

## The day-CARD opts from config (cell size/art + the today/milestone highlight badges). The daily card
## is its OWN component (defined separately), so both the card preview AND the dialog read it from here.
static func daily_card_opts_from_config(cfg: Dictionary) -> Dictionary:
	var dc: Dictionary = cfg.get("daily_card", {})
	return {
		"cell_w": float(dc.get("cell_w", 96)),
		"cell_h": float(dc.get("cell_h", 116)),
		"cell_slice": float(dc.get("cell_slice", 28)),
		"cell_art": bool(dc.get("cell_art", true)),
		"today_badge": String(dc.get("today_badge", "gold glow")),
		"milestone_badge": String(dc.get("milestone_badge", "amber glow")),
		"label_y": float(dc.get("label_y", 12)),     # the "Day N" label's drop from the top edge
		"label_x": float(dc.get("label_x", 0)),      # the label's horizontal nudge
		"claim_y": float(dc.get("claim_y", 14)),     # how far the bottom action is lifted in from the base
		"info_icon": bool(dc.get("info_icon", false)),  # the top-right "i" disc toggle
		"ribbon_scale": float(dc.get("ribbon_scale", 100)) / 100.0,  # ribbon SIZE (stored as %, 100 = 1×)
		"ribbon_x": float(dc.get("ribbon_x", 0)),    # ribbon horizontal position
		"ribbon_y": float(dc.get("ribbon_y", -10)),  # ribbon vertical position (over the top edge)
		"btn": card_btn_opts(cfg),
	}

## The full DAILY-dialog opts: the SHARED frame + the separately-defined day card + the dialog-level
## grid (cols, default 3 — the 3-per-row reference layout). Used by the workbench + the game.
static func daily_opts_from_config(cfg: Dictionary) -> Dictionary:
	var o := dialog_opts_from_config(cfg)
	o["banner_icon_id"] = "daily"
	o.merge(daily_card_opts_from_config(cfg), true)
	var dl: Dictionary = cfg.get("daily", {})
	o["cols"] = int(dl.get("cols", 3))
	# the daily's OWN scroll cap (0 = no scroll, grows to fit all days) — NOT the frame's mail-list cap
	o["list_max_h"] = float(dl.get("list_max_h", 0))
	return o

## The SHOP-dialog opts: the SHARED frame + the SAME small card + the shop grid (cols, larger cells for
## the icon+count+price layout). Same construction as the daily — only the data + cell size differ.
static func shop_opts_from_config(cfg: Dictionary) -> Dictionary:
	var o := dialog_opts_from_config(cfg)
	o.merge(daily_card_opts_from_config(cfg), true)
	var sh: Dictionary = cfg.get("shop", {})
	o["cols"] = int(sh.get("cols", 3))
	o["cell_w"] = float(sh.get("cell_w", 112))
	o["cell_h"] = float(sh.get("cell_h", 150))
	o["row_gap"] = float(sh.get("row_gap", 22))        # spacing between rows + sections (the dividers)
	o["list_max_h"] = float(sh.get("list_max_h", 0))   # the shop's OWN cap (0 = no scroll, show every item)
	return o

## The INFO sheet's opts: the info sheet IS the shared MAIL DIALOG (parchment cards, NO Claim) with a
## level-style "Got it" footer, so it inherits dialog_opts_from_config WHOLESALE (border · banner ribbon ·
## ✕ · padding · card art/fonts — tuned on the Frame/Card elements, exactly like the mail dialog). Only the
## width differs: a 1–2 row sheet is narrower than the inbox. Read by BOTH the workbench preview and the
## game's _info_sheet, so a tweak flows to every shop detail sheet.
static func info_opts_from_config(cfg: Dictionary) -> Dictionary:
	var o := dialog_opts_from_config(cfg)        # the standard mail-dialog face: border + banner + ✕ + cards
	return o

## The full DISCOVERY-dialog opts: the STANDARD shared frame, exactly like daily/shop/settings — it inherits
## dialog_opts_from_config wholesale (border, banner ribbon, ✕, geometry, padding), with NO bespoke chrome
## override. The discovery tile IS the shared slot cell, so its LOOK (piece size, level-medal size, well face)
## is INHERITED from the bag/slot config (bag_card_opts_from_config) — one source of truth, no duplicate knobs.
## Only the genuinely discovery-specific knobs live in the `tiers` block: the square cell size, whether the
## tier number shows, the marked-tier sparkle, and the grid (cols, gaps, scroll cap). Fractional sparkle knobs
## are stored as PERCENTS for the integer sliders and divided here. Edit the frame on the shared Frame item, or
## the cell look on the Slot-cell item, and both flow here. (The banner TEXT is the line name, passed by the caller.)
static func tiers_opts_from_config(cfg: Dictionary) -> Dictionary:
	var o := dialog_opts_from_config(cfg)
	# inherit the full shared slot-cell look (piece sizing + code-drawn well face); discovery overrides
	# only its own layout knobs below.
	var slot := tier_cell_opts_from_config(cfg)
	o.merge(slot, true)
	o.merge(dialog_cell_shadow_opts(cfg, slot), true)   # dialog-scoped cast (big cell, big icon)
	var t: Dictionary = cfg.get("tiers", {})
	# discovery's OWN cell knobs: the square tile size, plain tier number, and marked-tier sparkle
	o["cell_w"] = float(t.get("cell_w", 150))
	o["cell_h"] = float(t.get("cell_h", 150))
	o["show_num"] = bool(t.get("show_num", true))                  # plain lower-right tier number
	o["mark_glow"] = float(t.get("mark_glow", 60)) / 100.0         # the marked tier's sparkle glow (0 = off)
	o["mark_twinkle"] = float(t.get("mark_twinkle", 50)) / 100.0   # ...and its drifting twinkles (0 = off)
	# the grid (no vines): cols + the inter-cell gap + the discovery's OWN scroll cap (0 = show every tier)
	o["cols"] = int(t.get("cols", 3))
	o["cell_gap"] = int(t.get("cell_gap", 16))
	o["list_max_h"] = float(t.get("list_max_h", 0))
	return o

## The TOGGLE-CARD style opts from config (label font · switch size · parchment vs pill). The toggle card
## is its OWN component, so both the workbench card preview AND the settings dialog read it from here.
static func toggle_card_opts_from_config(cfg: Dictionary) -> Dictionary:
	var tc: Dictionary = cfg.get("toggle_card", {})
	# the row's OWN tint (the paper fill; the cut-edge rim derives a shade darker), sage by default.
	var tint := Color.from_string("#" + String(tc.get("tint", "DCE7C8")).lstrip("#"), ROW_SAGE)
	return {
		"label_font": int(tc.get("label_font", FS.BODY)),
		"switch_h": float(tc.get("switch_h", 44)),
		"card_art": bool(tc.get("card_art", true)),
		"row_fill": tint,
		"row_rim": tint.darkened(0.14),
		# the shared cut-paper edge for the row surface + the switch (one knob set, this block's values)
		"cp": cut_paper_opts_from_config(cfg, "toggle_card", ROW_CP_DEFAULTS),
	}

## The full SETTINGS-dialog opts: the SHARED frame + the toggle-card style (under opts["toggle"]) + the
## settings dialog's OWN width / row spacing. Used by the workbench preview AND the game settings card.
static func settings_opts_from_config(cfg: Dictionary) -> Dictionary:
	var o := dialog_opts_from_config(cfg)
	o["banner_icon_id"] = "settings"
	o["toggle"] = toggle_card_opts_from_config(cfg)
	var st: Dictionary = cfg.get("settings", {})
	o["row_gap"] = float(st.get("row_gap", 12))   # gap between toggle rows
	# Settings is a SHORT, fixed list — every row must always be visible (you can't scroll a settings
	# card to reveal a hidden row). Opt out of the shared frame's list_max_h scroll cap (425px, meant for
	# long dialogs like shop/mail) so the card grows to fit its content, however many rows the build adds.
	o["list_max_h"] = float(st.get("list_max_h", 0.0))
	return o

## The full VAULT-dialog opts: the SHARED frame (banner / close styling inherited from the Frame item)
## + the new TWIG border forced on + the vault's own tuned slice / pad / jar size from its config block.
## Used by BOTH the workbench preview and the game (engine/scripts/ui/vault.gd) — one builder, no
## duplicated face.
static func vault_opts_from_config(cfg: Dictionary) -> Dictionary:
	var o := dialog_opts_from_config(cfg)
	var v: Dictionary = cfg.get("vault", {})
	o["border"] = "vault twig"                            # the new frame option (forced for the vault)
	var sl: float = float(v.get("card_slice", 64))
	o["card_slice_l"] = sl; o["card_slice_t"] = sl; o["card_slice_r"] = sl; o["card_slice_b"] = sl
	o["panel_pad_x"] = float(v.get("panel_pad_x", 40))
	o["panel_pad_y"] = float(v.get("panel_pad_y", 34))
	o["card_art"] = true
	o["banner_icon_id"] = "vault"
	o["jar_px"] = float(v.get("jar_px", 200))
	o["plate_px"] = float(v.get("plate_px", 250))
	o["balance_font"] = int(v.get("balance_font", FS.TITLE))
	o["row_gap"] = float(v.get("row_gap", 12))
	return o

## The badge (disc-shell) edge polish from config — the standalone Badge item's defringe / feather /
## shadow. The home button's shell reads this, so a Badge tweak flows to the rail + nav automatically.
static func badge_polish_from_config(cfg: Dictionary) -> Dictionary:
	# NOTE: no baked `shadow` here — the disc/badge drop shadow is the SHARED box-shadow, cast behind the
	# home button by home_button() (the Shadow toggle), so the shell texture stays a clean, bakeable recipe.
	var b: Dictionary = cfg.get("badge", {})
	return {
		"defringe": bool(b.get("defringe", false)),
		"feather": float(b.get("feather", 0)),
	}

## The reusable PROGRESS BAR's saved STYLE from config (height / art / star knob). The Level dialog and
## the standalone workbench preview both read it from here.
## THE progress-bar look, shared by the level dialog, the board's NEXT UNLOCK strip, and the workbench
## preview. These were level_popup.gd locals; they live here so one workbench page drives every bar.
const PROGRESS_TRACK_ART := "kit/level_track.png"
const PROGRESS_FILL_ART := "kit/level_fill.png"
const PROGRESS_ART_CAP := 512
const PROGRESS_FILL_RIM_PCT := 10.0     # the thin rim left around the fill, % of bar height
## The earned fill IS Pal.LEAF; it is spelled as hex text only because the saved config
## stores colours as 6-digit strings. `static var`, not `const`, because a const initialiser
## may not call to_html() — the value is still write-once in practice.
static var PROGRESS_FILL_HEX := Pal.LEAF.to_html(false)
const PROGRESS_TRACK_HEX := "8FA6C9"    # the un-earned remainder — a one-off, not a palette role

static func progress_bar_opts_from_config(cfg: Dictionary) -> Dictionary:
	var p: Dictionary = cfg.get("progress_bar", {})
	var fill_shadow_params := {
		"offset_x": float(p.get("fill_shadow_x", 0.0)),
		"offset_y": float(p.get("fill_shadow_y", 2.0)),
		"blur": float(p.get("fill_shadow_blur", 3.0)),
		"spread": float(p.get("fill_shadow_spread", -1.0)),
		"alpha": clampf(float(p.get("fill_shadow_opacity", 28.0)) / 100.0, 0.0, 1.0),
	}
	return {
		"height": float(p.get("height", 20)),
		"art": bool(p.get("art", true)),
		# THE house progress-bar style — the level dialog's cut-paper capsule. It used to be applied
		# by level_popup.gd AFTER this reader, so the board strip and the workbench preview silently
		# drew the older prog_track/prog_fill art instead. Defaulting it here makes this reader the
		# single source: one workbench page now drives the level dialog AND the board strip.
		"track_art": String(p.get("track_art", PROGRESS_TRACK_ART)),
		"fill_art":  String(p.get("fill_art", PROGRESS_FILL_ART)),
		"art_cap":   int(p.get("art_cap", PROGRESS_ART_CAP)),
		"fill_rim_pct": float(p.get("fill_rim_pct", PROGRESS_FILL_RIM_PCT)),
		"fill_color": Color.from_string("#" + String(p.get("fill_color", PROGRESS_FILL_HEX)).lstrip("#"), Pal.LEAF),
		"track_color": Color.from_string("#" + String(p.get("track_color", PROGRESS_TRACK_HEX)).lstrip("#"), Color(Pal.INK, 0.12)),
		"shadow": bool(p.get("shadow", true)),
		"shadow_params": Look.shadow_params(cfg),
		"star_knob": bool(p.get("star_knob", false)),
		"fill_width_pct": float(p.get("fill_width_pct", 100.0)),
		"fill_height_pct": float(p.get("fill_height_pct", 100.0)),
		"fill_x": float(p.get("fill_x", 0.0)),
		"fill_y": float(p.get("fill_y", 0.0)),
		"fill_shadow": bool(p.get("fill_shadow", false)),
		"fill_shadow_params": fill_shadow_params,
	}

## The LEVEL dialog's saved STYLE from config — the dedicated frame chrome + the medallion size + the
## reusable progress-bar style + the shared button style. Read by BOTH the workbench preview and the
## game's level_popup.gd, so the transform lives in one place.
static func level_opts_from_config(cfg: Dictionary) -> Dictionary:
	var lv: Dictionary = cfg.get("level", {})
	return {
		"banner_text": String(lv.get("banner_text", "Level")),
		"title_font": int(lv.get("title_font", FS.HEADING)),
		"slice": float(lv.get("frame_slice", 56)),
		"pad": float(lv.get("frame_pad", 26)),
		"top_pad": float(lv.get("frame_top_pad", 70)),
		"medallion_px": float(lv.get("medallion_px", 120)),
		"ring_dy": float(lv.get("ring_dy", 0)),
		"tally_font": int(lv.get("tally_font", FS.BODY)),
		"hint_font": int(lv.get("hint_font", FS.FINE)),
		"gap": int(lv.get("gap", 14)),
		"progress": progress_bar_opts_from_config(cfg),
		"btn": _level_btn_opts(cfg),
	}

## The Level dialog's button STYLE — the shared Button opts, but with the font overridable PER LEVEL
## DIALOG (lv.btn_font), so the Got-it / Collect label can be sized up here without touching every other
## button. Falls back to the shared button's font when the level hasn't set its own.
static func _level_btn_opts(cfg: Dictionary) -> Dictionary:
	var lv: Dictionary = cfg.get("level", {})
	var btn: Dictionary = card_btn_opts(cfg)
	btn["font"] = int(lv.get("btn_font", int(btn.get("font", FS.FINE))))
	return btn

## The GENERATOR HIGHLIGHT opts from a saved config — the glow halo / silhouette outline / sparkle that
## marks a board generator (drawn by engine PieceView.make_generator). Stored as workbench-friendly ints
## (percent / per-mille / count) plus 6-digit hex colours, then converted to the values the builder
## reads. Returns {} when the "generator" block is absent so the engine falls back to its shipped GEN_*
## consts (the source of truth for the defaults below — keep them in sync with piece_view.gd).
static func gen_highlight_opts_from_config(cfg: Dictionary) -> Dictionary:
	var g: Dictionary = cfg.get("generator", {})
	if g.is_empty():
		return {}
	return {
		"glow_scale": float(g.get("glow_scale", 100)) / 100.0,    # halo size, % of cell
		"glow_a": float(g.get("glow_a", 30)) / 100.0,             # halo opacity
		"glow_color": _hex_color(String(g.get("glow_color", "FFD27A"))),
		"outline_w": float(g.get("outline_w", 35)) / 1000.0,      # rim thickness, per-mille of cell
		"outline_a": float(g.get("outline_a", 85)) / 100.0,       # rim opacity
		"outline_blur": float(g.get("outline_blur", 0)) / 1000.0, # rim feather, per-mille of cell
		"outline_color": _hex_color(String(g.get("outline_color", "E8BE5C"))),
		"sparkle_count": int(g.get("sparkle_count", 5)),          # twinkle count
		"sparkle_size": float(g.get("sparkle_size", 100)) / 100.0, # twinkle size multiplier
		"sparkle_speed": float(g.get("sparkle_speed", 70)) / 100.0,   # twinkle cycles/sec
		"sparkle_color": _hex_color(String(g.get("sparkle_color", "FFF4C2"))),
	}

## The shared HOME-BUTTON style opts from a saved config — the round icon button used by the home page's
## side rail and bottom nav. Slider values are stored 0..100 (icon_scale / glow / twinkle), divided here
## to the 0..1 the builder wants. The caller overrides `px` per call site (rail vs nav).
static func home_button_opts_from_config(cfg: Dictionary) -> Dictionary:
	var h: Dictionary = cfg.get("home_button", {})
	var sp: Dictionary = Look.shadow_params(cfg)   # THE uniform shadow — no per-component overrides
	return {
		"px": float(h.get("px", 140)),
		"shell": HOME_SHELL,
		"icon_scale": float(h.get("icon_scale", 50)) / 100.0,
		"caption_font": int(h.get("caption_font", FS.FINE)),
		"caption_gap": float(h.get("caption_gap", 4)),
		# the caption tab's OWN padding (overrides the shared title-ribbon margins for the home button only);
		# defaults reproduce the shipped ribbon (Tune.TITLE_PAD_X / ~T+B) so an absent config is unchanged.
		"caption_pad_x": float(h.get("caption_pad_x", 30)),
		"caption_pad_y": float(h.get("caption_pad_y", 8)),
		# the rect-badge OPACITY (0..100 %): modulates the painted badge so the rail / Map tiles can read
		# translucent over the homestead. Default 100 → opaque, so the shipped disc buttons are unchanged.
		"fill_alpha": float(h.get("fill_alpha", 100)),
		# the rect-badge inner PADDING as a fraction of px (the icon+caption inset off the badge edge).
		"rect_pad": float(h.get("rect_pad", 13)) / 100.0,
		# the orange PLAY disc's diameter (px) — the bottom-right CTA. Bigger than the 140 Map/rail buttons.
		"play_px": float(h.get("play_px", 188)),
		# the DROP SHADOW: cast the SHARED box-shadow behind the badge / disc (on by default — the shipped rail +
		# Map tiles lift off the homestead). home_button() shapes it per button (rounded rect vs circle).
		"shadow": bool(h.get("shadow", true)),
		"shadow_params": sp,
		"glow": float(h.get("glow", 0)) / 100.0,
		"twinkle": float(h.get("twinkle", 0)) / 100.0,
		# the count/dot BADGE offset (px past the disc's top-right corner): a caller's attach_badge nudges
		# the badge by this, so the side rail can pull it snug to the disc. The disc art carries a wide
		# transparent margin, so the default tucks the badge well IN (negative) to sit on the disc's edge.
		"badge_dx": float(h.get("badge_dx", -26)),
		"badge_dy": float(h.get("badge_dy", -26)),
		# the in-disc COUNT overlay (the Bag well's "x/y" slot count): its offset from the disc centre (px)
		# and its font. Only a button GIVEN count text (the bag) draws it; everything else ignores these.
		"count_dx": float(h.get("count_dx", 0)),
		"count_dy": float(h.get("count_dy", 38)),
		"count_font": int(h.get("count_font", FS.BODY)),
		# the count/dot BADGE size (px): the bare-dot diameter, and the count-pill number font (the pill height
		# tracks it). Defaults mirror Tune.BADGE_DOT_PX / BADGE_NUM_SIZE so an absent config renders the shipped badge.
		"badge_dot_px": int(h.get("badge_dot_px", 14)),
		"badge_num_size": int(h.get("badge_num_size", 14)),
		"badge": badge_polish_from_config(cfg),    # the Badge item's shell polish (defringe / feather / shadow)
	}

## The shared BUTTON opts (pill_button): the code-drawn rugged-edge knobs + shadow, read from the
## workbench "Button" block. Merged into a caller's opts so every game button (mail Claim, shop buy,
## bag CTA, …) picks up the ONE tuned setting set. deckle_freq is a 0..N percent → /100 (like the frame).
static func button_opts_from_config(cfg: Dictionary) -> Dictionary:
	var bt: Dictionary = cfg.get("button", {})
	# the SHARED cut-paper edge (the ONE knob set) from the button block, plus the button's own corner
	# (also used for the shadow-corner meta + the non-deckle rounded surface). `cp.deckle` is the on/off.
	var cp: Dictionary = cut_paper_opts_from_config(cfg, "button", BUTTON_CP_DEFAULTS)
	return {
		"cp": cp,
		"corner": float(cp["corner"]),
		"shadow": bool(bt.get("shadow", true)),          # the button's per-component GLOBAL drop-shadow toggle
	}

## Screen-relative HUD layout from the workbench. These are OUTER geometry slots, not the art recipe:
## level badge width, wallet band/pill widths, top band reserved before side rail/settings, shared nav
## button width, board info-bar width, board bottom-row height, and the shared right-edge inset for the wallet + rail.
## Stored as whole percents for simple workbench sliders, except edge_margin_px which is literal pixels.
##
## THE OWNER of these defaults: board.gd, hud.gd and the UI workbench read this resolver and nothing
## else — they keep NO private fallback percentages. (They used to, and the quest band was spelled
## 0.13 / 11.0 / 0.13 across the three, dormant only because the settings JSON always supplies the key.)
static func hud_layout_opts_from_config(cfg: Dictionary) -> Dictionary:
	var h: Dictionary = cfg.get("hud_layout", {}) if cfg is Dictionary else {}
	return {
		"currency_area_frac": clampf(float(h.get("currency_area_pct", 75.0)) / 100.0, 0.10, 1.0),
		"currency_pill_w_frac": clampf(float(h.get("currency_pill_w_pct", 25.0)) / 100.0, 0.05, 0.60),
		"button_w_frac": clampf(float(h.get("button_w_pct", 15.0)) / 100.0, 0.05, 0.50),
		"bottom_row_h_frac": clampf(float(h.get("bottom_row_h_pct", 0.0)) / 100.0, 0.0, 0.40),
		# quest band height (% screen height); board.gd clamps it to [QUEST_H_MIN, QUEST_H_MAX]. The old
		# quest/board x·y and board-height fracs are retired — the live layout is responsive + bottom-anchored.
		"quest_bar_h_frac": clampf(float(h.get("quest_bar_h_pct", 11.0)) / 100.0, 0.02, 0.50),
		"edge_margin_px": clampf(float(h.get("edge_margin_px", HUD_EDGE_MARGIN_PX)), 0.0, 96.0),
	}

## The shared HUD side inset (px) when no config supplies one — the ONE spelling of this number.
## map_select_layout takes it as an opts default too (its callers pass the resolved value through).
const HUD_EDGE_MARGIN_PX := 18.0

## The SELECTED-cell focus ring (corner brackets) tuning from the workbench. Colours are saved as
## 6-digit hex strings (no '#'); the rest are whole percents. Flows to the live board via board.gd
## _focus_ring_opts → applied to the FocusRing control (engine/scripts/ui/focus_ring.gd).
static func focus_ring_opts_from_config(cfg: Dictionary) -> Dictionary:
	var f: Dictionary = cfg.get("focus_ring", {}) if cfg is Dictionary else {}
	return {
		"color": _hex_color(String(f.get("color", "33402F"))),
		"halo_color": _hex_color(String(f.get("halo_color", "FBF3EA"))),
		"halo_a": clampf(float(f.get("halo_a", 90.0)) / 100.0, 0.0, 1.0),
		"arm_frac": clampf(float(f.get("arm_pct", 30.0)) / 100.0, 0.05, 0.50),
		"thick_frac": clampf(float(f.get("thick_pct", 8.0)) / 100.0, 0.01, 0.20),
		"pad_frac": clampf(float(f.get("pad_pct", 4.0)) / 100.0, 0.0, 0.20),
		"halo": bool(f.get("halo", true)),
	}

# The quest-ready glow's SHAPE is fixed: the rounded-fill corner radius and the halo spill, as fractions
# of the cell. They were tunable knobs; the shipped values never moved off these, so they are constants
# now and only COLOUR + opacity stay tunable (see ready_glow_opts_from_config).
const READY_GLOW_CORNER_FRAC := 0.22
const READY_GLOW_HALO_FRAC := 0.16

## The QUEST-READY glow (a board tile a live quest wants) tuning from the workbench. Colour is a 6-digit
## hex string (no '#'); fill_a/halo_a are whole-percent opacities. Flows to the live board via board.gd
## _ready_glow_opts → PieceView.add_ready_glow. An absent section returns the shipped READY_GLOW look.
static func ready_glow_opts_from_config(cfg: Dictionary) -> Dictionary:
	var r: Dictionary = cfg.get("ready_glow", {}) if cfg is Dictionary else {}
	return {
		"color": _hex_color(String(r.get("color", "FFB12E"))),
		"fill_a": clampf(float(r.get("fill_a", 55.0)) / 100.0, 0.0, 1.0),
		"halo_a": clampf(float(r.get("halo_a", 60.0)) / 100.0, 0.0, 1.0),
		"corner_frac": READY_GLOW_CORNER_FRAC,
		"halo_frac": READY_GLOW_HALO_FRAC,
	}

## Parse a 6-digit hex string (with or without a leading '#') into a Color; falls back to white.
static func _hex_color(hex: String) -> Color:
	var h := hex.strip_edges()
	if not h.begins_with("#"):
		h = "#" + h
	return Color.from_string(h, Color.WHITE)

## Board bottom action-bar tuning from the workbench. Values are saved as whole percents:
## icon_scale_pct is the single shared Bag/Home icon size; pad_*_pct are % of bar height; info_x_pct
## nudges only the center info content. Home and Bag keep fixed edge alignment.
static func action_bar_opts_from_config(cfg: Dictionary) -> Dictionary:
	var i: Dictionary = cfg.get("info_bar", {}) if cfg is Dictionary else {}
	var legacy: Dictionary = cfg.get("action_bar", {}) if cfg is Dictionary else {}
	return {
		"icon_scale": clampf(float(i.get("icon_scale_pct", legacy.get("icon_scale_pct", 50.0))) / 100.0, 0.10, 1.50),
		"pad_x_frac": clampf(float(i.get("pad_x_pct", legacy.get("pad_x_pct", 0.0))) / 100.0, 0.0, 0.30),
		"pad_y_frac": clampf(float(i.get("pad_y_pct", legacy.get("pad_y_pct", 0.0))) / 100.0, 0.0, 0.30),
		"info_x_frac": clampf(float(i.get("info_x_pct", legacy.get("info_x_pct", 0.0))) / 100.0, -0.50, 0.50),
		"shadow": bool(i.get("shadow", true)),
		"shadow_params": Look.shadow_params(cfg),
	}

static func live_board_frame_size(view_size: Vector2, cfg: Dictionary, cols := 7.0, rows := 9.0) -> Vector2:
	var b: Dictionary = cfg.get("board", {}) if cfg is Dictionary else {}
	var gap := float(b.get("gap", 7.0))
	var frame := float(b.get("frame", 60.0))
	var scale := float(b.get("scale", 100.0)) / 100.0
	# WIDTH-governed: square cells fill the screen width; the height budget (view.y - 536) is only a
	# cap so the board can't grow past the quest/bottom rows. Mirrors board.gd's live fit.
	var cell_w := (view_size.x - 12.0 - frame * 2.0 - (cols - 1.0) * gap) / cols
	var cell_h := (view_size.y - 536.0 - frame * 2.0 - (rows - 1.0) * gap) / rows
	var csz := maxf(1.0, minf(cell_w, cell_h) * scale)
	return Vector2(cols * csz + (cols - 1.0) * gap + frame * 2.0, rows * csz + (rows - 1.0) * gap + frame * 2.0)

## THE WALLET PILL'S cut-paper edge: the block's own knobs with the PAPER FURNITURE patch merged over
## them — a smooth large-radius cut, the lit hairline edge, the shared feather and the scene's
## directional halo, all derived from the pill's own height by the nav row's own constants
## (Paper.furniture_cp). It is code-set, exactly as EdgeTab.tab_cp is code-set over the action button's
## block, and for the same reason: two of the knobs it needs (halo_falloff / halo_offset) have no
## workbench row at all, and a directional light needs both. The block still owns everything the patch
## does not name — deckle_freq, shadow_blur, rim_color.
##
## It lives in the OPTS RESOLVER rather than in `gold_currency_pill`, so that a caller handing the
## builder an explicit `cp` (the mock-compare rig's `:cp=K=V` tunings) is the LAST word. Patched inside
## the builder instead, a rig override would be silently overwritten and the cell would render the
## baseline under the tuning's own label — docs/design/verifying-against-a-mock.md rule 4.
static func pill_cp_from_config(cfg: Dictionary, pill_h: float) -> Dictionary:
	var cp := cut_paper_opts_from_config(cfg, "gold_currency_pill", PILL_CP_DEFAULTS)
	cp.merge(Paper.furniture_cp(pill_h), true)
	return cp

## The shared GOLD CURRENCY PILL style opts from a saved config. The HUD, bag dialog, and workbench
## all build the same paper pill component directly from this block.
static func gold_currency_pill_opts_from_config(cfg: Dictionary) -> Dictionary:
	var g: Dictionary = cfg.get("gold_currency_pill", {}) if cfg is Dictionary else {}
	var scale := maxf(0.01, float(g.get("overall_scale", 100.0)) / 100.0)
	var icon_box := float(g.get("icon_box", 54.0)) * scale
	var icon_size := float(g.get("icon_size", 34.0)) * scale
	var sp: Dictionary = Look.shadow_params(cfg)   # THE uniform shadow — no per-component overrides
	return {
		"shadow": bool(g.get("shadow", false)),
		"shadow_params": sp,
		# the shared cut-paper EDGE knobs, read live from this block so the workbench sliders + the game HUD
		# both flow the same values into the drawn pill (Kit.cut_paper_opts_from_config → the ONE edge applier).
		"cp": pill_cp_from_config(cfg, float(g.get("pill_h", 100.0)) * scale),
		# the stacked-paper backer (second, larger sheet behind the face) — shared by the HUD pills
		# AND the NEXT UNLOCK strip, so the whole top chrome stacks the same way.
		"backer": bool(g.get("backer", false)),
		"backer_grow": float(g.get("backer_grow", 8.0)) * scale,
		"backer_tint": Color.from_string("#" + String(g.get("backer_tint", "E3D2B4")).lstrip("#"), Color("#E3D2B4")),
		"pill_w": float(g.get("pill_w", 292.0)) * scale,
		"pill_h": float(g.get("pill_h", 100.0)) * scale,
		"pad_left": float(g.get("pad_left", 18.0)) * scale,
		"pad_x": float(g.get("pad_x", 16.0)) * scale,
		"pad_y": float(g.get("pad_y", 12.0)) * scale,
		"icon_box": icon_box,
		"icon_size": icon_size,
		"icon_x": float(g.get("icon_x", 0.0)) * scale,
		"amount_w": float(g.get("amount_w", 88.0)) * scale,
		"num_size": maxi(1, int(round(float(g.get("num_size", 30)) * scale))),
		"amount_x": float(g.get("amount_x", 0.0)) * scale,
		"gap": int(round(float(g.get("gap", 12)) * scale)),
		"plus_x": float(g.get("plus_x", 0.0)) * scale,
		"plus_y": float(g.get("plus_y", 0.0)) * scale,
		"plus_radius": float(g.get("plus_radius", 28.0)),
		"plus_shine": float(g.get("plus_shine", 32.0)),
		"plus_stroke": float(g.get("plus_stroke", 2.0)) * scale,
		"plus_font": float(g.get("plus_font", FS.DISPLAY)) * scale,
		"plus_button": float(g.get("plus_button", 100.0)) * scale,
		"plus_round": float(g.get("plus_round", 8.0)),
		"plus_hue": float(g.get("plus_hue", 65.0)),
		"plus_label_y": float(g.get("plus_label_y", 0.0)) * scale,   # vertical nudge of the "+" within the green button
		"inner_shadow": float(g.get("inner_shadow", 30.0)),
		"show_plus": true,
	}

## The bottom-bar INFO BAR style opts from a saved config — the board's centre pill (info ⓘ · selected
## piece + name · sell cart). The LAYOUT persists here; the FRAME is the authored Meadow dialog paper,
## with the gold currency pill padding retained as the content margin.
## inner_scale / sell_icon / item_icon_scale are stored 0..100 and divided here to fractions of the bar height.
static func info_bar_opts_from_config(cfg: Dictionary) -> Dictionary:
	var i: Dictionary = cfg.get("info_bar", {}) if cfg is Dictionary else {}
	# The content margins borrow the wallet pill's padding numbers, but the visible tray is authored paper.
	var pill: Dictionary = gold_currency_pill_opts_from_config(cfg)
	return {
		"height":      float(i.get("height", 130)),                 # the bar height (matches the Bag/Home wells)
		"inner_scale": float(i.get("inner_scale", 48)) / 100.0,     # the info ⓘ slot as % of the bar height
		"item_icon_scale": float(i.get("item_icon_scale", 80)) / 100.0, # selected item/generator art as % of bar height
		"info_x":      float(i.get("info_x", 0)),                   # nudge the info ⓘ button left(−) / right(+)
		"info_y":      float(i.get("info_y", 0)),                   # nudge the info ⓘ button up(−) / down(+)
		"info_button_scale": clampf(float(i.get("info_button_scale", 100)) / 100.0, 0.25, 2.0),
		"hide_info_button": bool(i.get("hide_info_button", false)),
		"name_font":   int(i.get("name_font", FS.HEADING)),                 # the "<name> · Tier N" font
		"desc_font":   int(i.get("desc_font", FS.FINE)),                 # the compact player-use hint under the selected item name (kept SMALLER than the title so long descriptions fit the narrow bar)
		"sep":         int(i.get("sep", 10)),                       # the gap between the bar's controls
		"sell_font":   int(i.get("sell_font", FS.HEADING)),                 # the sell badge's payout number font
		"sell_label_font": int(i.get("sell_label_font", FS.FINE)),       # the plain "Sell" caption above the badge
		"sell_icon":   float(i.get("sell_icon", 30)) / 100.0,       # the payout coin as % of the bar height
		"sell_badge_radius": int(i.get("sell_badge_radius", 10)),   # the green badge's corner radius (softer than the full pill)
		"vpad":        float(i.get("vpad", 8)),                      # the tray frame's top/bottom padding (its own, not the wallet's)
		"pad_right":   float(i.get("pad_right", 16)),               # the tray frame's RIGHT padding — pins the Sell button off the edge
		"pill":        pill,                                        # shared padding/margin opts retained for content spacing
	}

## --- the bottom-bar INFO BAR: [selected piece] [name] [Sell badge], with floating [info ⓘ] -----------
## The board's centre bottom-bar pill. It carries the SELECTED board item: an info button (opens that
## item's tier ladder), the piece preview + its "<name> · Tier N", and a sell button — the word "Sell" in
## plain ink over a vertical green badge (the payout coin on top, the payout number below).
## The FRAME is the authored Meadow dialog paper, so the bottom bar reads as a lighter paper tray.
## The board AND the workbench build through this — a layout tweak (height · inner control scale · name
## font · separation · selected-item art scale · info button position/scale · sell button) flows to the live bar. The bar is STATELESS: the caller drives the
## empty/selected state by mutating the sub-nodes exposed via meta (info_btn / info_icon / name_label /
## sell_btn / inner_px / item_icon_scale / info_button_scale), so the board's selection logic is unchanged.
##   spec (per-instance wiring): info_action (Callable) · sell_action (Callable).
##   opts (shared STYLE — see info_bar_opts_from_config): height · inner_scale (0..1) · name_font · sep ·
##     item_icon_scale (0..1+, selected art as % of bar height) · info_x/info_y ·
##     info_button_scale (0..1+, info-button art inside its fixed slot) · sell_font (payout number) ·
##     sell_label_font ("Sell" caption) · sell_icon (0..1, the coin) · pill (content margins).
static func info_bar(spec: Dictionary, opts: Dictionary = {}) -> PanelContainer:
	var height := float(opts.get("height", 130.0))
	var inner := height * float(opts.get("inner_scale", 0.48))   # the info ⓘ slot scale with the bar
	var item_icon_px := height * float(opts.get("item_icon_scale", 0.80))
	var pill := PanelContainer.new()
	pill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pill.custom_minimum_size.y = height
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pad: Dictionary = opts.get("pill", {})
	var pad_x := float(pad.get("pad_x", 18.0))
	# The merged live action tray uses the authored Meadow dialog paper. Keep the selected-item text,
	# info affordance, and Sell chip code-driven, but put them on the same paper material as the board bar.
	var frame: StyleBox = meadow_paper_style("dialog_panel.png", DIALOG_PATCH, float(pad.get("pad_left", pad_x)), 0.0, float(opts.get("pad_right", 16.0)), 0.0)
	frame.content_margin_left = float(pad.get("pad_left", pad_x))
	# the RIGHT padding is its OWN knob — the name label expands to fill, so this gap pins the Sell button
	# off the right edge. Small by default so the button sits near the very right.
	frame.content_margin_right = float(opts.get("pad_right", 16.0))
	# vertical frame padding is its OWN knob (not the wallet's tall pad_y) — the bar's content is now a
	# taller "Sell" stack, so it hugs top/bottom tighter and the pill stays height-matched to the wells.
	var vpad := float(opts.get("vpad", 8.0))
	frame.content_margin_top = vpad
	frame.content_margin_bottom = vpad
	pill.add_theme_stylebox_override("panel", frame)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", int(opts.get("sep", 10)))
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(hb)
	var item_text_row := HBoxContainer.new()
	item_text_row.add_theme_constant_override("separation", 0)
	item_text_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_text_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	item_text_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var info_action: Callable = spec.get("info_action", Callable())
	var info_icon := CenterContainer.new()                       # selected-piece preview; tapping it opens the same info dialog as the ⓘ button
	info_icon.custom_minimum_size = Vector2(item_icon_px, height)
	info_icon.mouse_filter = Control.MOUSE_FILTER_STOP if info_action.is_valid() else Control.MOUSE_FILTER_IGNORE
	if info_action.is_valid():
		info_icon.gui_input.connect(func(ev: InputEvent) -> void:
			var tapped := false
			if ev is InputEventMouseButton:
				var mb := ev as InputEventMouseButton
				tapped = mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed
			elif ev is InputEventScreenTouch:
				tapped = not (ev as InputEventScreenTouch).pressed
			if not tapped:
				return
			info_action.call()
			var vp := info_icon.get_viewport()
			if vp != null:
				vp.set_input_as_handled()
		)
	item_text_row.add_child(info_icon)
	var text_stack := VBoxContainer.new()
	text_stack.add_theme_constant_override("separation", 0)
	text_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_stack.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item_text_row.add_child(text_stack)
	hb.add_child(item_text_row)
	var info_btn_scale := clampf(float(opts.get("info_button_scale", 1.0)), 0.25, 2.0)
	var info_btn_px := maxf(1.0, inner * info_btn_scale)
	var hide_info_button := bool(opts.get("hide_info_button", false))
	var info_btn := _info_circle_btn("info", info_btn_px)        # opens the selected item's tier ladder
	if info_action.is_valid():
		info_btn.pressed.connect(info_action)
	info_btn.visible = not hide_info_button
	info_btn.disabled = hide_info_button
	# The ⓘ floats above the row in a fixed footprint; x/y/scale move the button without pushing the item,
	# label, or Sell chip around.
	var info_x := float(opts.get("info_x", 0.0))
	var info_y := float(opts.get("info_y", 0.0))
	var info_overlay := Control.new()
	info_overlay.name = "InfoButtonOverlay"
	info_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_overlay.z_index = 5
	pill.add_child(info_overlay)
	var info_slot := Control.new()
	info_slot.name = "InfoButtonSlot"
	info_slot.custom_minimum_size = Vector2(inner, inner)
	info_slot.size = Vector2(inner, inner)
	info_slot.anchor_top = 0.5
	info_slot.anchor_bottom = 0.5
	info_slot.offset_left = 0.0
	info_slot.offset_right = inner
	info_slot.offset_top = -inner * 0.5
	info_slot.offset_bottom = inner * 0.5
	info_slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_btn.size = Vector2(info_btn_px, info_btn_px)
	info_btn.position = Vector2((inner - info_btn_px) * 0.5 + info_x, (inner - info_btn_px) * 0.5 + info_y)
	info_slot.add_child(info_btn)
	info_overlay.add_child(info_slot)
	# "<name> · Tier N" (or the empty prompt) — the text arrives from the caller
	var name_label := _kit_label("", int(opts.get("name_font", FS.HEADING)), Pal.INK)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.clip_text = false
	# An autowrap Label reports a minimum HEIGHT computed for its CURRENT width, so at a momentarily
	# narrow layout width it claims hundreds of lines (~1000px). Cap it at the line budget the tray is
	# designed for — the same limits grove_info_bar_tests already asserts, so rendering is unchanged.
	name_label.max_lines_visible = 2
	text_stack.add_child(name_label)
	# one-line player-use hint; hidden when empty (the text arrives from the caller)
	var desc_label := _kit_label("", int(opts.get("desc_font", FS.FINE)), Color(Pal.BARK, 0.92))
	desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.clip_text = false
	desc_label.max_lines_visible = 3     # see name_label above; matches the ≤3-line guard in grove_info_bar_tests
	desc_label.visible = false
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_stack.add_child(desc_label)
	var sell_btn := Button.new()                                 # sells the selected item; content = "Sell" over a coin·payout badge
	sell_btn.focus_mode = Control.FOCUS_NONE
	sell_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sell_icon_px := height * float(opts.get("sell_icon", 0.30))
	var sell_label_font := int(opts.get("sell_label_font", FS.FINE))
	var sell_num_font := int(opts.get("sell_font", FS.HEADING))
	# content STACK: the word "Sell" in plain ink ABOVE a vertical green badge (coin on top, the payout number
	# below). The label rides on the bar surface — the green is only the badge. A mouse-ignoring centered
	# stack so the WHOLE button stays the single tap target (children pass their clicks through).
	var sell_stack := VBoxContainer.new()
	sell_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	sell_stack.add_theme_constant_override("separation", 3)
	sell_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sell_label := _kit_label("Sell", sell_label_font, Pal.INK)   # the plain caption above the badge
	sell_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sell_stack.add_child(sell_label)
	# the green badge — a VERTICAL pill: the payout currency rides on top, the amount sits below it.
	var badge_col := VBoxContainer.new()
	badge_col.alignment = BoxContainer.ALIGNMENT_CENTER
	badge_col.add_theme_constant_override("separation", 1)
	badge_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# the payout currency is the game's STANDARD coin/acorn icon (the caller fills it via Look.icon, swapped
	# per payout) — on TOP of the badge.
	var sell_coin := CenterContainer.new()
	sell_coin.custom_minimum_size = Vector2(sell_icon_px, sell_icon_px)
	sell_coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_col.add_child(sell_coin)
	# the payout amount (the caller sets the text), under the coin
	var sell_count := _kit_label("", sell_num_font, Pal.CREAM)
	sell_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_col.add_child(sell_count)
	# the badge wears the palette's ALERT red (Pal.ACCENT_ALERT — the same clay Look.button(danger) uses), so
	# Sell reads as the destructive action and stays distinct from the green Buy/Burst chips beside it.
	var badge := PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ts := StyleBoxFlat.new()
	ts.bg_color = Pal.ACCENT_ALERT
	ts.border_color = Pal.ACCENT_ALERT.darkened(0.22)
	ts.set_corner_radius_all(int(opts.get("sell_badge_radius", 10)))   # a softer rounded-rect, not the full pill
	ts.set_border_width_all(Tune.BTN_BORDER_W)
	ts.shadow_color = Color(0, 0, 0, 0.16)                             # very minimal lift (was the heavy SHADOW_RAISED)
	ts.shadow_size = 2
	ts.shadow_offset = Vector2(0, 1)
	ts.content_margin_left = 14
	ts.content_margin_right = 14
	ts.content_margin_top = 4
	ts.content_margin_bottom = 4
	badge.add_theme_stylebox_override("panel", ts)
	badge.add_child(badge_col)
	sell_stack.add_child(badge)
	# size the button to its content (a Button does not grow to fit child controls), then LEFT-align the stack in
	# it via a full-rect HBox. The min height tracks the label + coin + number so the badge never clips and the
	# bar height stays close to the Bag/Home wells. Left-aligning pins the Sell badge to its button's left edge so
	# it hugs the buy chip beside it (which right-aligns the same way) — closing the gap between the two chips.
	var sell_h := int(sell_label_font * 1.45) + 3 + 8 + sell_icon_px + 1 + int(sell_num_font * 1.45)
	sell_btn.custom_minimum_size = Vector2(maxf(sell_icon_px + 64.0, 96.0), sell_h)
	var sell_center := HBoxContainer.new()                       # left-align the stack within the button rect
	sell_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	sell_center.alignment = BoxContainer.ALIGNMENT_BEGIN
	sell_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sell_stack.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sell_stack.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sell_center.add_child(sell_stack)
	sell_btn.add_child(sell_center)
	# the button itself is transparent — the green now lives on the inner badge; the press juice (scale)
	# carries the tactile feedback.
	var flat := StyleBoxEmpty.new()
	sell_btn.add_theme_stylebox_override("normal", flat)
	sell_btn.add_theme_stylebox_override("hover", flat)
	sell_btn.add_theme_stylebox_override("pressed", flat)
	if spec.has("sell_action") and (spec.get("sell_action") as Callable).is_valid():
		sell_btn.pressed.connect(spec.get("sell_action"))
	Look.add_press_juice(sell_btn)
	hb.add_child(sell_btn)
	# expose the mutable sub-nodes so the caller drives selection state without rebuilding the bar
	pill.set_meta("info_btn", info_btn)
	pill.set_meta("info_icon", info_icon)
	pill.set_meta("name_label", name_label)
	pill.set_meta("desc_label", desc_label)
	pill.set_meta("sell_btn", sell_btn)
	pill.set_meta("sell_count", sell_count)
	pill.set_meta("sell_coin", sell_coin)
	pill.set_meta("inner_px", inner)
	pill.set_meta("item_icon_scale", float(opts.get("item_icon_scale", 0.80)))
	pill.set_meta("item_icon_px", item_icon_px)
	pill.set_meta("info_y", float(opts.get("info_y", 0.0)))
	pill.set_meta("info_button_scale", info_btn_scale)
	pill.set_meta("hide_info_button", hide_info_button)
	return pill

## The info bar's "ⓘ" button. When the shipped disc sprite (ui/shared/icon_<id>.png — the cream
## disc + "i" cut from action_asset) is present it IS the whole button face: a transparent button
## under the texture, rendered edge-to-edge. The disc art already carries its own cream fill +
## border, so drawing a pill behind it would double the disc. Falls back to a drawn cream disc +
## centred glyph when the sprite is absent (mirrors the board's old _circle_btn).
static func _info_circle_btn(icon_id: String, px: float) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(px, px)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var disc_p := Look.kit("shared/icon_%s.png" % icon_id)
	if ResourceLoader.exists(disc_p):
		var empty := StyleBoxEmpty.new()
		for st in ["normal", "hover", "pressed", "disabled"]:
			b.add_theme_stylebox_override(st, empty)
		var sh := TextureRect.new()
		sh.name = "InfoIconShadow"
		sh.texture = load(disc_p)
		sh.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sh.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sh.set_anchors_preset(Control.PRESET_FULL_RECT)
		var drop := maxf(1.0, px * 0.045)
		sh.offset_left = drop
		sh.offset_top = drop
		sh.offset_right = drop
		sh.offset_bottom = drop
		sh.modulate = Look.shadow_color(0.24)
		sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(sh)
		var tr := TextureRect.new()
		tr.texture = load(disc_p)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(tr)
		Look.add_press_juice(b)
		return b
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Pal.CREAM)
	sb.set_corner_radius_all(int(px / 2.0))
	sb.set_border_width_all(2)
	sb.border_color = Pal.STRAW
	for st in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(st, sb)
	var ish := Look.icon(icon_id, px * 0.58)
	ish.name = "InfoIconShadow"
	ish.set_anchors_preset(Control.PRESET_FULL_RECT)
	ish.position = Vector2(maxf(1.0, px * 0.045), maxf(1.0, px * 0.045))
	ish.self_modulate = Look.shadow_color(0.24)
	ish.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(ish)
	var ic := Look.icon(icon_id, px * 0.58)
	ic.set_anchors_preset(Control.PRESET_FULL_RECT)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(ic)
	Look.add_press_juice(b)
	return b

## --- the BOARD PANEL: the rounded frame the cells sit on ---------------------------------------------
## ONE builder shared by the live board (board.gd _make_board_mat) AND the workbench preview, so they read
## 1:1 (the workbench shows the ACTUAL border). Three styles, chosen by board.frame_style:
##   "meadow" (default) — code-drawn slate surface + a flat paper-grain layer, light edge, and one shadow.
##   "badge" — the retained generated gold-badge compatibility style.
##   "code"  — a code-drawn rounded-rect for tuning a depth effect: cream fill, an outer border (border_w),
##             an optional inner hairline (inner_w = "the border of the border"), and a top inset shadow for
##             depth (top_shadow). The under-board drop shadow is the SHARED box-shadow (the `shadow` toggle).

## opts (board.* config): frame_style · corner · border_w · inner_w · top_shadow (0..100) · shadow (bool) + shadow_params.
static func board_panel(size: Vector2, opts: Dictionary = {}) -> Control:
	var root := Control.new()
	root.custom_minimum_size = size
	root.size = size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var corner := int(opts.get("corner", 58))
	var frame_style := String(opts.get("frame_style", "meadow"))
	var shadow_corner := float(corner)
	if frame_style == "meadow":
		shadow_corner = clampf(minf(size.x, size.y) * 0.035, 14.0, 30.0)
	# the soft drop shadow under the WHOLE board (both styles) — the SHARED box-shadow, a sibling drawn BEHIND
	# (show_behind_parent) so it bleeds past the edge. NinePatchRect has no native shadow. On via the toggle.
	if bool(opts.get("shadow", false)):
		var sh := _meadow_shadow_rect(shadow_corner, opts.get("shadow_params", {}))
		sh.name = "MeadowBoardShadow"
		sh.show_behind_parent = true
		root.add_child(sh)
	if frame_style == "code":
		# code-drawn rounded-rect: cream fill + a gold outer border, corners held by `corner`.
		var border_w := int(opts.get("border_w", 4))
		var panel := Panel.new()
		panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("#FBF3E2")          # the parchment cream the cells sit on
		sb.set_corner_radius_all(corner)
		sb.set_border_width_all(border_w)
		sb.border_color = Pal.STRAW
		panel.add_theme_stylebox_override("panel", sb)
		root.add_child(panel)
		# a TOP inset shadow for depth ("shadow near the top"): a dark, downward-fading strip clipped to the
		# panel, so the board reads slightly sunken under its top rim.
		var top := clampf(float(opts.get("top_shadow", 0)) / 100.0, 0.0, 1.0)
		if top > 0.0:
			var grad := Gradient.new()
			grad.set_color(0, Color(0.0, 0.0, 0.0, 0.5 * top))
			grad.set_color(1, Color(0.0, 0.0, 0.0, 0.0))
			var gtex := GradientTexture2D.new()
			gtex.gradient = grad
			gtex.fill_from = Vector2(0.0, 0.0)
			gtex.fill_to = Vector2(0.0, 1.0)
			gtex.width = 4
			gtex.height = 64
			var tr := TextureRect.new()
			tr.texture = gtex
			tr.stretch_mode = TextureRect.STRETCH_SCALE
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var pad := float(border_w) + 1.0
			tr.position = Vector2(pad + corner * 0.4, pad)
			tr.size = Vector2(maxf(0.0, size.x - 2.0 * (pad + corner * 0.4)), size.y * 0.22)
			root.add_child(tr)
		# the inner hairline — "the border of the border" — an inset rounded-rect drawing only its border.
		var inner_w := int(opts.get("inner_w", 0))
		if inner_w > 0:
			var inset := float(border_w) + 4.0
			var inner := Panel.new()
			inner.set_anchors_preset(Control.PRESET_FULL_RECT)
			inner.offset_left = inset; inner.offset_top = inset
			inner.offset_right = -inset; inner.offset_bottom = -inset
			inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var isb := StyleBoxFlat.new()
			isb.draw_center = false
			isb.set_corner_radius_all(maxi(0, corner - int(inset)))
			isb.set_border_width_all(inner_w)
			isb.border_color = Color(Pal.STRAW, 0.55)
			inner.add_theme_stylebox_override("panel", isb)
			root.add_child(inner)
	else:
		# The reference board is one simple slate paper slab. Keep its silhouette, edge, and depth in code;
		# the source image contributes only the paper grain and is clipped just inside the light rim.
		var meadow_corner := int(shadow_corner)
		var panel := Panel.new()
		panel.name = "MeadowBoardSurface"
		panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		# frame_tint (board.frame_tint knob) recolours the slab; the cream cut-paper grain sheet is
		# multiplied by the same tint so the surface keeps its paper tooth at any colour.
		var frame_tint: Color = opts.get("frame_tint", Pal.BARK)
		sb.bg_color = frame_tint
		sb.border_color = Color(Pal.CREAM, 0.82)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(meadow_corner)
		sb.anti_aliasing = true
		panel.add_theme_stylebox_override("panel", sb)
		root.add_child(panel)
		if bool(opts.get("draw_center", true)):
			root.add_child(_rounded_paper_layer("MeadowBoardPaper", "texture_cream.png", size, meadow_corner, 2.0, frame_tint))
	return root

## The board-panel frame opts from a saved config — the frame style ("meadow" default | "code") and its
## code-drawn depth knobs (corner · border · inner hairline · top inset shadow).
static func board_panel_opts_from_config(cfg: Dictionary) -> Dictionary:
	var b: Dictionary = cfg.get("board", {}) if cfg is Dictionary else {}
	return {
		"frame_style": String(b.get("frame_style", "meadow")), # "meadow" default | legacy "badge" | "code"
		"frame_tint":  Color.from_string("#" + String(b.get("frame_tint", Pal.BARK.to_html(false))).lstrip("#"), Pal.BARK),
		"corner":      int(b.get("frame_corner", 58)),
		"border_w":    int(b.get("frame_border_w", 4)),          # code: outer border thickness
		"inner_w":     int(b.get("frame_inner_w", 0)),           # code: inner hairline (border-of-the-border); 0 = off
		"top_shadow":  float(b.get("frame_top_shadow", 0)),      # code: top inset shadow depth (0..100) — a border highlight, NOT the drop shadow
		"shadow":      bool(b.get("shadow", true)),              # cast the SHARED box-shadow under the board (on by default)
		"shadow_params": Look.shadow_params(cfg),                # the single shared shadow look
	}

## --- the bag screen: the slot CELL + the dialog -----------------------------------------------------
## The slot cell is ONE component card with four states. Open and locked states use code-drawn rounded
## surfaces masked with flat Meadow paper grain; `next` also gets a dynamic sparkle FX.
const SLOT_EMPTY_ART := "board/slot_tile.png"    # the open cream well — empty / filled

## The DIALOG cell face — the warm sage the dialog mocks paint their open/discovered cells with,
## measured (median of a flat patch) off games/grove/assets/_concepts/dialogs/: tiers #CCCEAA,
## merged_line_tiers #CBCFA8, resident_management_dialog_v2 #CDC8A5. The board's own open cell keeps
## the Meadow-Sky mint below and is unaffected.
const DIALOG_CELL_OPEN_FILL := Color("#CCCEAA")
## ...and the nominal colour of ui/meadow_v2/texture_meadow.png, the grain sheet drawn over the face.
const MEADOW_PAPER_BASE := Pal.MEADOW
## The LOCKED dialog cell, measured the same way off the same mocks: tiers #91A0B3, merged_line_tiers
## #97A6B9, resident_management_dialog_v2 #8B9FB2 — a lighter, warmer receding blue than the board's.
## The board's locked well keeps #8296AF below.
const DIALOG_CELL_LOCKED_FILL := Color("#91A0B3")
## ...and the nominal colour of ui/meadow_v2/texture_receding_blue.png, its own grain sheet.
const RECEDING_PAPER_BASE := Pal.BRAMBLE_BG
## The OPENABLE-NOW board well: a warm gold, deep enough that the cream acorn lock still reads on top.
## Paired with a bright STRAW rim (slot_cell_background) as the board's contained unlockable highlight.
const BOARD_UNLOCKABLE_FILL := Color("#C79A4E")
## How far dim_bg recedes an inactive well (the multiply the old, ineffective modulate asked for).
const DIM_BG_FACTOR := 0.74

static func slot_cell_background(size_px: Vector2, state: String, frontier: bool, opts: Dictionary = {}) -> Panel:
	const FACE_INSET := 3.0
	const BOARD_FACE_INSET := 6.0
	var flat_board_cells := bool(opts.get("flat_board_cells", false))
	var face_inset := BOARD_FACE_INSET if flat_board_cells else FACE_INSET
	var face_size := Vector2(maxf(1.0, size_px.x - face_inset * 2.0), maxf(1.0, size_px.y - face_inset * 2.0))
	var base := Panel.new()
	base.name = "SlotCellBackground"
	base.position = Vector2.ONE * face_inset
	base.size = face_size
	# DIALOG cells wear the mocks' warmer SAGE face; the BOARD keeps its Meadow mint untouched. The
	# opt is dialog-scoped (opts.dialog_cells, threaded in by the dialog opt builders) precisely so the
	# playable grid — which passes flat_board_cells — is never repainted.
	var dialog_cells := bool(opts.get("dialog_cells", false)) and not flat_board_cells
	# An OPENABLE-NOW board cell (frontier + level reached) wears a contained WARM highlight: the well
	# turns gold and its rim brightens, all inside the inset face, so the "pop" can't spill across the
	# board's tight gutters the way the old full-cell glow/sparkle overlay did (that overlay is why the
	# board highlight was disabled — this replaces it in a gutter-safe way, drawn ON the face).
	var unlockable_flat := flat_board_cells and state == "unlockable"
	var open_state := state == "empty" or state == "filled"
	var file_name := "texture_meadow.png" if open_state else "texture_receding_blue.png"
	var fill := Pal.CELL_EMPTY if open_state else Pal.LOCKED
	if dialog_cells:
		fill = DIALOG_CELL_OPEN_FILL if open_state else DIALOG_CELL_LOCKED_FILL
	if unlockable_flat:
		fill = BOARD_UNLOCKABLE_FILL   # a warm gold well over the receding-blue grain sheet
	var corner_px := int(roundf(minf(face_size.x, face_size.y) * 0.18))
	var fs := StyleBoxFlat.new()
	fs.bg_color = fill
	# The board is a flat paper grid: a stronger *inset* rim keeps its tiles separate while
	# remaining wholly inside the cell (unlike the Bag's unlockable halo).
	fs.border_color = Color(Pal.BARK, 0.52 if flat_board_cells else 0.28)
	fs.set_border_width_all(2 if flat_board_cells else 1)
	if unlockable_flat:
		fs.border_color = Color("#F4D58C")   # a light warm-gold rim that reads as a ring over the gold well
		fs.set_border_width_all(3)
	fs.set_corner_radius_all(corner_px)
	fs.anti_aliasing = true
	base.add_theme_stylebox_override("panel", fs)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# the paper layer IS the visible colour (texture_meadow.png is an opaque #A8D3B9 grain sheet), so a
	# recoloured face has to retint it too — as a modulate ratio off the texture's own base, which is
	# exactly Color.WHITE when the fill is unchanged (the board stays byte-identical).
	var paper_tint := Color.WHITE
	if dialog_cells:
		var base_c: Color = MEADOW_PAPER_BASE if open_state else RECEDING_PAPER_BASE
		paper_tint = Color(fill.r / base_c.r, fill.g / base_c.g, fill.b / base_c.b)
	elif unlockable_flat:
		# retint the receding-blue grain sheet to the warm well (the sheet IS the visible face)
		paper_tint = Color(fill.r / RECEDING_PAPER_BASE.r, fill.g / RECEDING_PAPER_BASE.g, fill.b / RECEDING_PAPER_BASE.b)
	# dim_bg (the Producing dialog's discovered-but-inactive lines) recedes the WELL. It has to ride the
	# SAME tint the recolour uses: the paper sheet IS the visible face and the mask shader writes COLOR
	# wholesale, so a modulate on the parent Panel only ever dimmed the 1px border.
	var dim: float = clampf(float(opts.get("dim", 1.0)), 0.0, 1.0)
	if dim < 1.0:
		fill = Color(fill.r * dim, fill.g * dim, fill.b * dim, fill.a)
		fs.bg_color = fill
		paper_tint = Color(paper_tint.r * dim, paper_tint.g * dim, paper_tint.b * dim, paper_tint.a)
	base.add_child(_rounded_paper_layer("SlotCellPaperTexture", file_name, face_size, corner_px, 1.0, paper_tint))
	# EVERY slot cell casts the ONE SHARED drop-shadow so a grid of them reads as raised paper —
	# the board's flat tiles and the bag's dialog cells alike, un-clipped: the cast flows into the
	# grid gaps (the mock board's look) and the next tile's face covers the rest.
	if bool(opts.get("cell_shadow", true)):
		var sh: Panel = Look.shadow_rect(float(corner_px), Look.shadow_params(load_config(CONFIG_PATH)))
		sh.name = "SlotCellShadow"
		sh.show_behind_parent = true
		base.add_child(sh)
	return base

## The BAG-CELL opts from config — the slot tile's saved STYLE. Its own component (the bag dialog reuses
## it), read by both the workbench card preview and the bag dialog/overlay. Fractional knobs (the piece /
## lock size as a % of the cell) are stored as integer percents for the sliders and divided here.
const SLOT_LOCK_MARK_ALPHA := 0.78
const SLOT_LOCK_MARK_FRAC := 0.58
## The DIALOG lock: every locked cell stamps the map-card keyhole (ui/card/lock.png — the same purple
## scalloped mark the maps gallery uses), so one lock icon reads across the whole game. The W_FRAC
## keeps the tiers mock's footprint; the aspect is the card lock's own (173:194 → h/w 194/173).
const DIALOG_LOCK_PATH := "res://games/grove/assets/ui/card/lock.png"   # the map-card keyhole — THE house lock
const DIALOG_LOCK_W_FRAC := 0.38
const DIALOG_LOCK_ASPECT := 194.0 / 173.0

## The locked cell's stamp. `dialog_cells` picks the mocks' flat padlock; everything else (the board, the
## bag's gated wells, any non-dialog caller) keeps the house acorn lock, unchanged.
static func _slot_lock_mark(cw: float, ch: float, dialog_cells: bool = false) -> TextureRect:
	var tr := TextureRect.new()
	tr.name = "SlotCellLockMark"
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE     # before any size/anchor work — the min-size cache clamps otherwise
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if dialog_cells and ResourceLoader.exists(DIALOG_LOCK_PATH):
		var lock_tex: Texture2D = load(DIALOG_LOCK_PATH)
		if lock_tex != null:
			tr.texture = lock_tex
			# FRACTIONAL anchors, zero offsets: the mark then tracks whatever size the cell settles at
			# (a dialog grid fits its cells deferred) instead of freezing today's pixel inset.
			var hf: float = DIALOG_LOCK_W_FRAC * DIALOG_LOCK_ASPECT * (cw / maxf(1.0, ch))
			tr.anchor_left = 0.5 - DIALOG_LOCK_W_FRAC * 0.5
			tr.anchor_right = 0.5 + DIALOG_LOCK_W_FRAC * 0.5
			tr.anchor_top = 0.5 - hf * 0.5
			tr.anchor_bottom = 0.5 + hf * 0.5
			tr.offset_left = 0.0; tr.offset_top = 0.0; tr.offset_right = 0.0; tr.offset_bottom = 0.0
			return tr
	var tex := _meadow_tex("acorn_lock.svg")
	if tex == null:
		return null
	var px := minf(cw, ch) * SLOT_LOCK_MARK_FRAC
	tr.texture = tex
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	var inset_x := (cw - px) * 0.5
	var inset_y := (ch - px) * 0.5
	tr.offset_left = inset_x
	tr.offset_top = inset_y
	tr.offset_right = -inset_x
	tr.offset_bottom = -inset_y
	tr.modulate = Color(1.0, 1.0, 1.0, SLOT_LOCK_MARK_ALPHA)
	return tr

static func bag_card_opts_from_config(cfg: Dictionary) -> Dictionary:
	var bc: Dictionary = cfg.get("bag_card", {})
	var shared_sp := Look.shadow_params(cfg)
	var item_shadow_params := {
		"offset_x": float(bc.get("item_shadow_x", shared_sp.offset_x)),
		"offset_y": float(bc.get("item_shadow_y", shared_sp.offset_y)),
		"blur": float(bc.get("item_shadow_blur", shared_sp.blur)),
		"spread": minf(float(bc.get("item_shadow_spread", shared_sp.spread)), 0.0),
		"alpha": clampf(float(bc.get("item_shadow_alpha", float(shared_sp.alpha) * 100.0)) / 100.0, 0.0, 1.0),
	}
	var opts := {
		"cell_w": float(bc.get("cell_w", 116)),
		"cell_h": float(bc.get("cell_h", 120)),
		"content_frac": float(bc.get("content_frac", 62)) / 100.0,   # a held piece, % of the cell
		"content_shadow": bool(bc.get("shadow", true)),              # cast content shadow only when the standard Shadow toggle is on
		"cell_shadow": bool(bc.get("cell_shadow", true)),            # the CELL's own drop cast (shared box-shadow); the item's is above
		"shadow_params": shared_sp,                                  # the single shared shadow look
		"content_shadow_params": item_shadow_params,                 # Slot-cell-local shadow for the item inside the cell
		"cost_font": int(bc.get("cost_font", FS.BODY)),                   # the acorn-cost number
		"cost_icon": float(bc.get("cost_icon", 26)),                 # the acorn icon px in a cost row
		"cost_y": float(bc.get("cost_y", 0)),                        # nudge the acorn cost up(-) / down(+), px
		"cost_x": float(bc.get("cost_x", 0)),                        # nudge the acorn cost left(-) / right(+), px
		"cost_scale": float(bc.get("cost_scale", 100)) / 100.0,      # the cost pill's overall size (% — shrinks the WHOLE button to fit the card)
		"level_frac": float(bc.get("level_frac", 44)) / 100.0,       # the level badge size, % of the cell
		"btn": card_btn_opts(cfg),                                   # the SHARED button style (art/shadow/corner) — the cost chip rides it
	}
	return opts

static func shared_torn_slot_opts_from_config(cfg: Dictionary) -> Dictionary:
	var opts := bag_card_opts_from_config(cfg)
	opts.merge(torn_cell_opts_from_config(cfg), true)
	opts["torn_cells"] = true
	# the generated paper-sprite faces (torn_cell "Paper sprites" knob) ride the same opts so every
	# slot_cell caller — board, bag, tiers, residents — switches together.
	if bool(opts.get("sprites", false)):
		opts["sprite_open"] = CELL_SPRITE_PATHS["open"]
		opts["sprite_open_alt"] = CELL_SPRITE_PATHS["open_alt"]
		opts["sprite_locked"] = CELL_SPRITE_PATHS["locked"]
		opts["sprite_locked_deep"] = CELL_SPRITE_PATHS["locked_deep"]
	return opts

static func board_cell_opts_from_config(cfg: Dictionary) -> Dictionary:
	return shared_torn_slot_opts_from_config(cfg)

static func tier_cell_opts_from_config(cfg: Dictionary) -> Dictionary:
	return shared_torn_slot_opts_from_config(cfg)

## One SLOT CELL — the shared bag + board cell, on the board's cream-well art. `d.state` (or the legacy
## `d.kind`) picks the look + behaviour:
##   empty      — the open cream well (seen / unlocked / owned-empty), inert
##   filled     — the open well + a piece on top; a tap fires d.on_tap (retrieve)
##   locked     — the locked well with the flat placeholder stamp (unseen / gated), inert
##   unlockable — the locked well + placeholder, full opacity; a tap fires d.on_tap (buy / open).
##   next       — the bag's purchasable slot; tappable, costed, and visually locked in torn-cell mode.
## Optional overlays (a cell shows what is passed): d.cost (int) → the acorn cost near the lower edge
## (bag); d.level (int) → Look.make_level_badge docked lower-right — the SAME HUD
## level badge (board / discovery tier); d.marked (bool) → the engine sparkle over the well, under the
## piece (the discovery ladder's tapped tier); d.dim (0..1) sets the cell's modulate alpha (the board's
## receded deep locks). The piece is content-agnostic so the kit stays free of game deps: d.make_content
## (size) (a Callable that builds the game's piece view at the FITTED size) wins, else d.content (a node),
## else d.icon (a kit icon id), else nothing. Every state returns a tile of exactly cell_w × cell_h.
## d keys: state|kind, make_content|content|icon, cost, level, marked, dim, on_tap. opts: bag_card_opts_from_config(...).
static func slot_cell(d: Dictionary, opts: Dictionary = {}) -> Control:
	var raw_state := String(d.get("state", d.get("kind", "empty")))
	var cw := float(opts.get("cell_w", 116.0))
	var ch := float(opts.get("cell_h", 120.0))
	var cost_font := int(opts.get("cost_font", FS.BODY))
	var cost_icon := float(opts.get("cost_icon", 26.0))
	var cost_y := float(opts.get("cost_y", 0.0))
	var cost_x := float(opts.get("cost_x", 0.0))
	var cost_scale := float(opts.get("cost_scale", 1.0))
	# Legacy callers can still request the flat board-paper path; the live board/tier/bag surfaces now pass
	# torn_cells so they share the same code-drawn cut-paper component.
	var flat_board_cells := bool(opts.get("flat_board_cells", false))
	var use_torn_cells := bool(opts.get("torn_cells", false)) and not flat_board_cells
	var state := raw_state
	if state == "next":
		state = "locked" if use_torn_cells else "unlockable"
	var on_tap: Callable = d.get("on_tap", Callable())
	var is_next := raw_state == "next"
	var tappable := on_tap.is_valid() and (state == "filled" or state == "unlockable" or is_next)
	var lockedwell := (state == "locked" or state == "unlockable")   # both show the single acorn lock mark

	var tile: Control = (Button.new() if tappable else Control.new())
	tile.custom_minimum_size = Vector2(cw, ch)
	tile.size = Vector2(cw, ch)            # explicit, so the board (absolute layout) sizes it; a grid overrides
	tile.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if tile is Button:
		var b := tile as Button
		b.focus_mode = Control.FOCUS_NONE
		b.flat = true
		b.pressed.connect(func() -> void:
			if on_tap.is_valid(): on_tap.call())

	# the cell FACE — one code-drawn Slot-cell background for every state, so the Workbench knobs apply
	# consistently to board, bag, and discovery cells.
	var frontier := bool(d.get("frontier", state == "unlockable"))
	# dim_bg recedes JUST THE WELL (the Producing dialog's discovered-but-inactive lines): the piece is added
	# later as its own child, so darkening the background here leaves the full-colour item untouched. It goes
	# in through the background's OWN dim opt — a modulate on the returned Panel cannot reach the paper face.
	var bg_opts: Dictionary = opts
	if bool(d.get("dim_bg", false)):
		bg_opts = opts.duplicate()
		bg_opts["dim"] = DIM_BG_FACTOR
	# Torn-cell path (bag dialog): the Bag wears the same code-drawn torn component as the workbench
	# reference. The next purchasable slot stays tappable/costed, but reads as a locked torn cell.
	# The baked paper-sprite faces. LOCKED picks the deep (receded) variant for interior, non-frontier
	# locks; OPEN picks the alt checker mate when the caller marks the cell (d.alt — board parity).
	var sprite_open_p := String(opts.get("sprite_open", ""))
	var sprite_locked_p := String(opts.get("sprite_locked", ""))
	if lockedwell:
		var deep_p := String(opts.get("sprite_locked_deep", ""))
		if not frontier and deep_p != "":
			sprite_locked_p = deep_p
	elif bool(d.get("alt", false)) and String(opts.get("sprite_open_alt", "")) != "":
		sprite_open_p = String(opts.get("sprite_open_alt", ""))
	var sprite_path := ""
	if lockedwell and sprite_locked_p != "" and ResourceLoader.exists(sprite_locked_p):
		sprite_path = sprite_locked_p
	elif not lockedwell and sprite_open_p != "" and ResourceLoader.exists(sprite_open_p):
		sprite_path = sprite_open_p
	if use_torn_cells and sprite_path == "":
		var torn_opts := opts.duplicate()
		torn_opts["state"] = "locked" if lockedwell else "open"
		var bg := torn_cell(torn_opts)
		tile.add_child(bg)
	elif sprite_path != "":
		# The sprite faces are cut shadow-free (guide §0), so the ENGINE casts the shadow — the same
		# shared box-shadow every other cell state uses, tunable from the workbench Shadow page.
		if bool(opts.get("cell_shadow", true)):
			var corner := int(roundf(minf(cw, ch) * 0.18))
			var sh: Panel = Look.shadow_rect(float(corner), Look.shadow_params(load_config(CONFIG_PATH)))
			sh.name = "SlotCellShadow"
			sh.show_behind_parent = true
			tile.add_child(sh)
		var art := TextureRect.new()
		art.name = "SlotCellSprite"
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_SCALE
		# through the SHARED polish path, not a raw load: the intake key leaves a ~1px binary alpha
		# step, which downsamples into a visibly jagged border. clean_tex_path defringes + feathers
		# the edge (and reads the committed baked mirror, so there is no per-pixel cost at runtime).
		art.texture = clean_tex_path(sprite_path, CELL_SPRITE_CAP)
		art.position = Vector2.ZERO
		art.size = Vector2(cw, ch)
		art.custom_minimum_size = Vector2.ZERO
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if bool(d.get("dim_bg", false)):
			# recede JUST THE FACE (Producing's discovered-but-inactive lines) — same contract as the
			# code-drawn path's `dim` opt: the piece added later stays full colour.
			art.self_modulate = Color(DIM_BG_FACTOR, DIM_BG_FACTOR, DIM_BG_FACTOR, 1.0)
		tile.add_child(art)
	else:
		var bg := slot_cell_background(Vector2(cw, ch), state, frontier, bg_opts)
		tile.add_child(bg)
		if lockedwell:
			var lock_mark := _slot_lock_mark(cw, ch, bool(opts.get("dialog_cells", false)) and not flat_board_cells)
			if lock_mark != null:
				tile.add_child(lock_mark)

	# a MARKED cell (the discovery ladder's tapped/asked tier) wears the SAME engine sparkle the home
	# buttons use, sitting over the well but UNDER the piece — an overlay, so the footprint never changes.
	# The board + bag don't set this; the discovery cell does.
	if bool(d.get("marked", false)):
		var mglow := float(opts.get("mark_glow", 0.6))
		var mtwinkle := float(opts.get("mark_twinkle", 0.5))
		if mglow > 0.0 or mtwinkle > 0.0:
			var msp := _sparkle_overlay(cw, mglow, mtwinkle)
			msp.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tile.add_child(msp)

	# filled — the piece, centred, built at the FITTED cell size (content-agnostic).
	if state == "filled":
		var piece_px := cw * float(opts.get("content_frac", 0.62))
		var piece: Control = null
		var mk: Callable = d.get("make_content", Callable())
		if mk.is_valid():
			piece = mk.call(piece_px)
		elif d.get("content") is Control:
			piece = d.get("content")
		elif String(d.get("icon", "")) != "":
			piece = make_icon(String(d.icon), piece_px)
		if piece != null:
			var built_in_shadow := piece.find_child("ContactShadow", true, false)
			if built_in_shadow != null:
				built_in_shadow.get_parent().remove_child(built_in_shadow)
				built_in_shadow.queue_free()
			piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var pc := Control.new()
			pc.position = Vector2.ZERO
			pc.size = Vector2(cw, ch)
			pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if bool(opts.get("content_shadow", true)):
				var sp: Dictionary = opts.get("content_shadow_params", opts.get("shadow_params", {})) as Dictionary
				var shadow_slot := Control.new()
				shadow_slot.name = "SlotContentShadowSlot"
				shadow_slot.position = Vector2((cw - piece_px) * 0.5, (ch - piece_px) * 0.5)
				shadow_slot.size = Vector2(piece_px, piece_px)
				shadow_slot.custom_minimum_size = Vector2(piece_px, piece_px)
				shadow_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
				# SHAPE-TRUE: stamp the shadow from the item's OWN art silhouette at its fitted rect, so the
				# cast follows the item's real outline (the standard item_shadow_* params drive the bake).
				var content_shadow: Control = null
				var art := content_art_of(piece)
				if art != null:
					# the PieceView holder frames its art FULL_RECT with a symmetric px inset; mirror it so
					# the stamp lands exactly under the drawn sprite (aspect-fit centred, like the art).
					var art_inset := maxf(0.0, art.offset_left) if art.anchor_right > art.anchor_left else 0.0
					var box := maxf(1.0, piece_px - art_inset * 2.0)
					var ts := art.texture.get_size()
					if ts.x > 0.0 and ts.y > 0.0:
						var fit_scale := minf(box / ts.x, box / ts.y)
						var fit_sz := ts * fit_scale
						var fit_pos := Vector2(art_inset, art_inset) + (Vector2(box, box) - fit_sz) * 0.5
						var stamp := item_shadow_stamp(art.texture, fit_sz, sp)
						if not stamp.is_empty():
							var str_rect := TextureRect.new()
							str_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
							str_rect.stretch_mode = TextureRect.STRETCH_SCALE
							str_rect.texture = stamp.texture
							str_rect.modulate = stamp.get("tint", Color(0, 0, 0, 0.2))   # rgb×0 = black cast; alpha lives here, not in the bake
							var pad := float(stamp.pad)
							str_rect.position = fit_pos - Vector2(pad, pad)
							str_rect.size = fit_sz + Vector2(pad, pad) * 2.0
							content_shadow = str_rect
				if content_shadow == null:
					# no readable art (placeholder disc / headless): the rounded-rect stand-in
					content_shadow = Look.shadow_rect(piece_px * 0.32, sp)
					content_shadow.custom_minimum_size = Vector2(piece_px, piece_px)
				content_shadow.name = "SlotContentShadow"
				content_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
				shadow_slot.add_child(content_shadow)
				pc.add_child(shadow_slot)
			var piece_slot := CenterContainer.new()
			piece_slot.position = Vector2.ZERO
			piece_slot.size = Vector2(cw, ch)
			piece_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			piece_slot.add_child(piece)
			pc.add_child(piece_slot)
			tile.add_child(pc)

	# the acorn cost (bag) — near the lower edge. The SHARED green pill_button (the
	# same atom as the shop buy / daily claim), as a STATIC display chip: the CELL itself takes the buy tap,
	# so the price isn't separately pressable. It rides the Button style (art/shadow/corner) via opts.btn,
	# sized by this cell's own cost_font / cost_icon knobs. cost_x / cost_y nudge it; cost_scale shrinks the
	# WHOLE pill (incl. padding) to fit inside a card — scaled about its centre so it stays put.
	var cost := int(d.get("cost", 0))
	if cost > 0 and lockedwell:
		# cost_scale shrinks/grows the WHOLE pill — font, icon, padding AND corner — so the CenterContainer
		# lays it out at that size natively. (Control.scale would be wiped: a Container resets a managed
		# child's scale/pivot in fit_child_in_rect, so the shrink never stuck.)
		var cbo := (opts.get("btn", {}) as Dictionary).duplicate()
		cbo["bg"] = "green"; cbo["icon"] = "gem"; cbo["static"] = true
		cbo["font"] = maxi(1, int(round(float(cost_font) * cost_scale)))
		cbo["icon_size"] = maxi(1, int(round(cost_icon * cost_scale)))
		cbo["pad_scale"] = cost_scale
		cbo["corner"] = float(cbo.get("corner", 16.0)) * cost_scale
		var chip := pill_button(str(cost), cbo)
		chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		# The chip DOCKS to the cell's lower edge (a bottom-aligned box), rather than being centred in a
		# band derived from cost_font: past ~80% cost_scale the pill is taller than such a band, and a
		# CenterContainer centres that overflow — spilling the chip below the cell. Bottom-aligning it
		# keeps the chip inside the cell at ANY scale while cost_x / cost_y stay pure nudges (they move
		# the cluster's offsets, so the sidebar sliders read exactly as before).
		var cwrap := VBoxContainer.new()
		cwrap.name = "SlotCellCostCluster"
		cwrap.alignment = BoxContainer.ALIGNMENT_END
		cwrap.set_anchors_preset(Control.PRESET_FULL_RECT)
		cwrap.offset_left = cost_x; cwrap.offset_right = cost_x
		cwrap.offset_top = cost_y; cwrap.offset_bottom = -ch * 0.06 + cost_y
		cwrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cwrap.add_child(chip)
		tile.add_child(cwrap)

	# the level badge (board) — the SAME HUD level medal, carrying THIS cell's level, docked lower-right.
	var level := int(d.get("level", 0))
	if level > 0:
		var lvpx := maxf(28.0, cw * float(opts.get("level_frac", 0.44)))
		var badge := Look.make_level_badge(level, lvpx)
		badge.anchor_left = 1.0; badge.anchor_top = 1.0; badge.anchor_right = 1.0; badge.anchor_bottom = 1.0
		badge.offset_left = -lvpx - cw * 0.04
		badge.offset_top = -lvpx - cw * 0.04
		badge.offset_right = -cw * 0.04
		badge.offset_bottom = -cw * 0.04
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(badge)

	# (The old "unlockable" glow+sparkle highlight was retired. An unlockable/next cell reads as the
	# locked well plus whatever cost/level the caller passes, exactly as the game renders it.)

	# the board's deep (non-frontier) locks recede — the caller passes d.dim (1.0 = full opacity).
	var dim := float(d.get("dim", 1.0))
	if dim < 1.0:
		tile.modulate = Color(1, 1, 1, dim)
	return tile

## Backward-compat alias: the bag screen + its tests/config call bag_card (kind=…); the board calls
## slot_cell (state=…). ONE builder.
static func bag_card(d: Dictionary, opts: Dictionary = {}) -> Control:
	return slot_cell(d, opts)

## The full BAG-dialog opts: the SHARED frame + the bag-cell style + the reused gold currency pill +
## the dialog's own grid (cols, default 6 — the reference's six-wide ladder). Same construction as the
## daily/settings dialogs. Used by the workbench preview AND the game (engine/scripts/ui/bag_overlay.gd).
static func bag_opts_from_config(cfg: Dictionary) -> Dictionary:
	var o := dialog_opts_from_config(cfg)
	var slot := shared_torn_slot_opts_from_config(cfg)
	o.merge(slot, true)
	o.merge(dialog_cell_shadow_opts(cfg, slot), true)      # dialog-scoped cast (bigger cells than the board)
	o["pill"] = gold_currency_pill_opts_from_config(cfg)   # the reused gold pill's style (single-acorn at build time)
	var bg: Dictionary = cfg.get("bag", {})
	o["cols"] = int(bg.get("cols", 6))
	o["cell_gap"] = int(bg.get("cell_gap", 12))
	o["grid_inset"] = float(bg.get("grid_inset", 70))  # how much the parchment border/padding eats the grid width
	o["row_gap"] = float(bg.get("row_gap", 14))        # gap between the pill / grid / footer rows
	o["acorn_x"] = float(bg.get("acorn_x", 0))         # nudge the acorn-balance pill left(−) / right(+)
	o["list_max_h"] = float(bg.get("list_max_h", 0))   # the bag's OWN scroll cap (0 = no scroll, 18 slots fit)
	o["caption"] = String(bg.get("caption", "Open a slot with acorns."))
	o["banner_text"] = String(bg.get("banner_text", "Bag"))
	o["banner_icon_on"] = false                        # the reference's "Bag" ribbon is text-only (no envelope)
	return o

## The BAG dialog — the SHARED frame wrapping the bag screen: the reused gold currency pill (the single-acorn
## balance, docked top-right), a grid of bag cells (the slot ladder), and a leaf-flanked footer caption.
## The direct sibling of daily_dialog: same chrome, the bag's content. `entries` is an Array of bag_card
## data dicts (already classified by the caller — the game's slot_plan, or the workbench's DEMO_BAG);
## `balance` is the acorn count. opts["extra"] (optional) is a game-only section (the generators row)
## inserted below the grid. Used by BOTH the workbench preview and the game (ui/bag_overlay.gd).
static func bag_dialog(entries: Array, balance: int, width: float = 560.0, opts: Dictionary = {}) -> Control:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", int(opts.get("row_gap", 14)))
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# (no acorn-balance pill: the HUD already carries the acorn counter, and the only price in the dialog
	# is the next slot's own cost chip. `balance` stays in the signature for the callers/tests.)

	# the slot grid — the six-wide ladder. The cells SCALE to fit `cols` across the frame's content width
	# (width − the border/padding inset − the gaps), so the grid never overflows the parchment (like the
	# tiers/daily grids); every cell metric scales from that fitted cell_w. A partial last row centres.
	var cols := maxi(1, int(opts.get("cols", 6)))
	var gap := int(opts.get("cell_gap", 16))   # >= the shadow reach so casts breathe between cells
	var inset := float(opts.get("grid_inset", 70.0))
	var base_w := float(opts.get("cell_w", 116.0))
	var aspect := float(opts.get("cell_h", 120.0)) / maxf(1.0, base_w)
	var cw := maxf(40.0, (width - inset - float(cols - 1) * float(gap)) / float(cols))
	var fit_scale := cw / maxf(1.0, base_w)
	var cell_opts := opts.duplicate()
	cell_opts["cell_w"] = cw
	cell_opts["cell_h"] = cw * aspect
	cell_opts["cost_font"] = int(float(opts.get("cost_font", FS.BODY)) * fit_scale)
	cell_opts["cost_icon"] = float(opts.get("cost_icon", 30.0)) * fit_scale
	var grid := GridContainer.new()
	grid.columns = cols
	grid.add_theme_constant_override("h_separation", gap)
	grid.add_theme_constant_override("v_separation", gap)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for e in entries:
		grid.add_child(bag_card(e, cell_opts))
	var grid_wrap := CenterContainer.new()
	grid_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid_wrap.add_child(grid)
	content.add_child(grid_wrap)

	# an optional game-only section (the stored-generators row) below the grid. A Callable gets THIS
	# dialog's FITTED cell opts, so a section built from bag_card matches the grid's cell size exactly;
	# a plain Control is added as-is.
	var extra: Variant = opts.get("extra")
	if extra is Callable:
		var built: Variant = (extra as Callable).call(cell_opts)
		if built is Control:
			content.add_child(built)
	elif extra is Control:
		content.add_child(extra)

	content.add_child(_bag_footer(String(opts.get("caption", "Open a slot with acorns."))))
	return dialog_frame(content, width, opts)

# The bag footer caption flanked by the bag leaf sprigs (bag_leaf_l/r.png), or text alone when absent.
## The bag's stored-GENERATORS section — a centred label + a row of generator cells. SHARED: the game's
## bag (bag_overlay._gen_section) builds the live generator cells and passes them here; the workbench
## preview passes demo cells. `cells` is an array of bag_card entry dicts; `cell_opts` is the dialog's
## FITTED cell opts, so the generator tiles match the grid's cell size. Fed to bag_dialog via opts.extra.
static func bag_generators_section(label_text: String, cells: Array, cell_opts: Dictionary) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := _kit_label(label_text, FS.BODY, Color(Pal.INK, 0.75))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(label)
	# an HFlowContainer (not a plain HBox): once the stored generators outgrow the dialog width they WRAP
	# onto a new line instead of overflowing the parchment. ALIGNMENT_CENTER keeps every row centred, so a
	# handful of generators still reads as the old single centred row, and a full row wraps a tidy grid.
	var row := HFlowContainer.new()
	row.alignment = FlowContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("h_separation", 12)
	row.add_theme_constant_override("v_separation", 12)
	row.size_flags_horizontal = Control.SIZE_FILL   # take the dialog's content width so it knows where to wrap
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(row)
	for c in cells:
		row.add_child(bag_card(c as Dictionary, cell_opts))
	return col

static func _bag_footer(text: String) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ll := _bag_leaf("kit/bag_leaf_l.png", false)
	if ll != null:
		row.add_child(ll)
	var lbl := _kit_label(text, FS.BODY, Color(Pal.BARK, 0.85))
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(lbl)
	var lr := _bag_leaf("kit/bag_leaf_r.png", true)
	if lr != null:
		row.add_child(lr)
	return row

static func _bag_leaf(rel: String, flip: bool) -> Control:
	var p := Look.kit(rel)
	if not ResourceLoader.exists(p):
		return null
	var t := TextureRect.new()
	t.texture = clean_tex_path(p, 96)
	t.flip_h = flip
	t.custom_minimum_size = Vector2(40, 34)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

static func map_select_layout(view: Vector2, opts: Dictionary = {}, safe_top: float = 0.0, safe_bottom: float = 0.0) -> Dictionary:
	var top := 96.0 + safe_top
	var sep := 18.0
	var band_top := top + 16.0
	var margin := clampf(float(opts.get("edge_margin_px", HUD_EDGE_MARGIN_PX)), 0.0, 96.0)
	var band_bot := view.y - (safe_bottom + margin)
	var col_h := maxf(1.0, band_bot - band_top)
	var left_clip_top := 0.0
	var left_clip_h := maxf(1.0, view.y)
	var col_gap := clampf(view.x * 0.02, 10.0, 24.0)
	var hand_w := clampf(view.x * 0.30, 210.0, 360.0)
	var card_w := maxf(160.0, view.x - margin * 2.0 - col_gap - hand_w)
	var h_frac := float(opts.get("card_h_frac", 0.16))
	var base_card_h := maxf(view.y * h_frac, 150.0)
	var left_x := margin
	var hand_x := left_x + card_w + col_gap
	return {
		"top": top,
		"sep": sep,
		"band_top": band_top,
		"band_bot": band_bot,
		"col_h": col_h,
		"left_clip_top": left_clip_top,
		"left_clip_h": left_clip_h,
		"left_content_top": band_top,
		"margin": margin,
		"col_gap": col_gap,
		"hand_w": hand_w,
		"card_w": card_w,
		"base_card_h": base_card_h,
		"left_x": left_x,
		"hand_x": hand_x,
	}

## The map-card presentation opts from config (use-art · frame inset · art radius · count-pill metrics ·
## §8 fog-veil look). DEFAULTS equal the shipped §8 constants, so an absent/empty config renders the
## SHIPPED card byte-for-byte. Insets/fracs are stored as scaled integers for the workbench's integer
## sliders (inset/radius in thousandths, fracs + veil alphas in percent) and resolved to fractions here.
static func map_card_opts_from_config(cfg: Dictionary) -> Dictionary:
	var c: Dictionary = cfg.get("map_card", {}) if cfg is Dictionary else {}
	var hud: Dictionary = hud_layout_opts_from_config(cfg)
	return {
		"use_art":         bool(c.get("use_art", true)),
		"edge_margin_px":  float(hud.edge_margin_px),                   # place-picker column edges share the HUD side margin
		"card_h_frac":     float(c.get("card_h_frac", 16)) / 100.0,     # card height as a % of the screen height (a w:h far from the art's ~2.92 aspect stretches the gold frame)
		"edge_sparkle":    float(c.get("edge_sparkle", 60)) / 100.0,    # twinkles ringing an ACTIVE open card's gold band (0 = off)
		"pill_w_frac":     float(c.get("pill_w_frac", 30)) / 100.0,     # count-pill width (% of card width)
		"pill_min":        float(c.get("pill_min", 170)),
		"pill_max":        float(c.get("pill_max", 290)),
		"pill_y_frac":     float(c.get("pill_y_frac", 13)) / 100.0,     # pill lift off the bottom (% of card height)
		"resident_slot_px": float(c.get("resident_slot_px", 58)),        # completed-card resident slot size px
		"resident_slot_gap": float(c.get("resident_slot_gap", 10)),      # completed-card gap between resident slots px
		"expedition_button_w":  float(c.get("expedition_button_w", 116)),
		"expedition_button_h":  float(c.get("expedition_button_h", 36)),
		"expedition_button_x":  float(c.get("expedition_button_x", 0)),
		"expedition_button_y":  float(c.get("expedition_button_y", 0)),
		"expedition_button_font": int(c.get("expedition_button_font", FS.FINE)),
		"slot_cell":       bag_card_opts_from_config(cfg),               # completed-card resident cells match the right-column square slots
		"reward_shelf_w_frac": float(c.get("reward_shelf_w_frac", 100)) / 100.0, # completed-card reward shelf width (% of left lane)
		"reward_shelf_h_frac": float(c.get("reward_shelf_h_frac", 14)) / 100.0,  # completed-card reward shelf height (% of card height)
		"reward_shelf_y_frac": float(c.get("reward_shelf_y_frac", 0)) / 100.0,   # completed-card reward shelf lift from bottom (% of card height)
		"reward_icon_size": float(c.get("reward_icon_size", 24)),
		"reward_icon_x":    float(c.get("reward_icon_x", 0)),
		"reward_icon_y":    float(c.get("reward_icon_y", 0)),
		"reward_label_font": int(c.get("reward_label_font", FS.FINE)),
		"reward_label_x":   float(c.get("reward_label_x", 0)),
		"reward_label_y":   float(c.get("reward_label_y", 0)),
		"reward_button_w":  float(c.get("reward_button_w", 116)),
		"reward_button_h":  float(c.get("reward_button_h", 36)),
		"reward_button_x":  float(c.get("reward_button_x", 0)),
		"reward_button_y":  float(c.get("reward_button_y", 0)),
		"reward_button_font": int(c.get("reward_button_font", FS.FINE)),
		"reward_bar_h":     float(c.get("reward_bar_h", 10)),
		"reward_bar_y":     float(c.get("reward_bar_y", 0)),
		"veil_mark_size":  float(c.get("veil_mark_size", 64)),         # the ✿ place-mark px on an open card's bare meadow fill (no slider; _map_place_mark)
		# open-card title plate nudges (px offsets from the auto-sized baseline; pad_x/pad_y are the label
		# inset). Defaults are no-ops (0 / shipped 24/2) so an untuned card renders the SAME plate. _map_add_title_plate.
		"title_font":      float(c.get("title_font", 0)),             # grow/shrink the map-name text
		"title_w":         float(c.get("title_w", 0)),                # widen/narrow the plate from its auto width
		"title_h":         float(c.get("title_h", 0)),                # taller/shorter plate
		"title_x":         float(c.get("title_x", 0)),                # move the plate right/left
		"title_y":         float(c.get("title_y", 0)),                # move the plate down/up
		"title_pad_x":     float(c.get("title_pad_x", 24)),           # label inset left/right inside the plate
		"title_pad_y":     float(c.get("title_pad_y", 2)),            # label inset vertical
	}

## One surface's shadow cast, read from the quest_card block under `<prefix>_*` keys (e.g.
## item_shadow_offset_x), each defaulting to the shared `shadow` block's value — so an untuned surface
## resolves to exactly the one shared cast, and any tuned knob splits just that surface. Alpha is stored
## as a percent (like the Shadow item) and returned 0..1; spread is clamped ≤ 0 (see Look.shadow_params).
static func _giver_surface_shadow(q: Dictionary, prefix: String, cfg: Dictionary) -> Dictionary:
	return surface_shadow(q, prefix, Look.shadow_params(cfg))

## ONE per-surface shadow reader: `<prefix>_offset_x|_offset_y|_blur|_spread|_alpha` out of `src`,
## each falling back to `base` (a resolved shadow-params dict, alpha 0..1). Used by the quest-card
## surfaces AND the dialog cell override, so a surface's shadow is always the shared cast plus only
## the knobs it deliberately re-tunes.
static func surface_shadow(src: Dictionary, prefix: String, base: Dictionary) -> Dictionary:
	return {
		"offset_x": float(src.get(prefix + "_offset_x", base.offset_x)),
		"offset_y": float(src.get(prefix + "_offset_y", base.offset_y)),
		"blur":     float(src.get(prefix + "_blur", base.blur)),
		"spread":   minf(float(src.get(prefix + "_spread", base.spread)), 0.0),
		"alpha":    clampf(float(src.get(prefix + "_alpha", float(base.alpha) * 100.0)) / 100.0, 0.0, 1.0),
	}

## The DIALOG slot-cell shadow overrides (`dialog_cell` block). Dialog grids draw the SAME slot cell
## as the board but at a much bigger cell (tiers 150² vs the board's 116×120) with a large icon, and
## the cast is fixed PIXELS — so a shadow tuned on a small board item reads as a tight smudge under a
## dialog icon. Bag + tiers apply this override; the board keeps the bag_card values. Every key falls
## back to the board's, so an untuned block leaves the dialogs exactly as they were.
static func dialog_cell_shadow_opts(cfg: Dictionary, board_opts: Dictionary) -> Dictionary:
	var d: Dictionary = cfg.get("dialog_cell", {}) if cfg is Dictionary else {}
	var out := {}
	var item_base: Dictionary = board_opts.get("content_shadow_params", Look.shadow_params(cfg))
	out["content_shadow_params"] = surface_shadow(d, "item_shadow", item_base)
	if d.has("item_shadow"):
		out["content_shadow"] = bool(d.get("item_shadow"))
	var cell_base: Dictionary = board_opts.get("shadow_params", Look.shadow_params(cfg))
	out["shadow_params"] = surface_shadow(d, "cell_shadow", cell_base)
	if d.has("cell_shadow"):
		out["cell_shadow"] = bool(d.get("cell_shadow"))
	return out

## The QUEST-GIVER card layout fractions from a saved config — the workbench's quest_card block (percent
## ints) → the `lay` dict GiverStand.make reads (cfg.lay). `item_size` drives a SQUARE item (item_w ==
## item_h, undistorted). EVERY default mirrors giver_stand.LAY, so an absent/empty block resolves to the
## SHIPPED layout and the board's giver card is unchanged until a designer saves a tweak.
static func giver_lay_from_config(cfg: Dictionary) -> Dictionary:
	var q: Dictionary = cfg.get("quest_card", {}) if cfg is Dictionary else {}
	var isz: float = float(q.get("item_size", 60)) / 100.0
	var sh := bool(q.get("shadow", false))   # the legacy single toggle — the per-surface defaults inherit it
	return {
		"card_w":      float(q.get("card_w", 92)) / 100.0,      "card_h":   float(q.get("card_h", 97)) / 100.0,
		"item_w":      isz,                                     "item_h":   isz,                                  "item_x":   float(q.get("item_x", 50)) / 100.0, "item_y": float(q.get("item_y", 44)) / 100.0,
		"check_scale": float(q.get("check_scale", 88)) / 100.0,
		"plaque_w":    float(q.get("plaque_w", 46)) / 100.0,    "plaque_x": float(q.get("plaque_x", 70)) / 100.0, "plaque_y": float(q.get("plaque_y", 85)) / 100.0,
		# the card gap is PX (the fence row's separation — board.gd reads it), not a percent fraction.
		"gap":         float(q.get("gap", 16)),
		# per-surface shadow toggles (item / card / plaque), each defaulting to the legacy `shadow`
		# so an old config keeps its one-switch behaviour until a designer tunes them apart.
		"item_shadow":   bool(q.get("item_shadow", sh)),
		"card_shadow":   bool(q.get("card_shadow", sh)),
		"plaque_shadow": bool(q.get("plaque_shadow", sh)),
		# each surface's OWN shadow cast (offset · blur · spread · alpha) — the common shadow-param set,
		# per surface. Every knob defaults to the shared `shadow` block, so an untuned surface tracks the
		# one shared cast; tuning a surface's sliders splits just that surface's shadow.
		"item_shadow_params":   _giver_surface_shadow(q, "item_shadow", cfg),
		"card_shadow_params":   _giver_surface_shadow(q, "card_shadow", cfg),
		"plaque_shadow_params": _giver_surface_shadow(q, "plaque_shadow", cfg),
		# (bust_*/bubble_* knobs retired with the giver portrait + speech bubble; card_slice_* retired with the
		# nine-slice. The card + reward tag are now cut-paper textures. Old saved values are accepted + ignored.)
		# the card's drop-shadow is the ONE SHARED shadow every component casts (Skin.shadow_rect), gated by the
		# UNIVERSAL Shadow toggle and tuned on the Shadow item — NOT a per-card definition. `shadow` is the toggle
		# (off by default → shipped card unchanged); `shadow_params` is the shared look read from the global
		# `shadow` block. GiverStand._quest_card casts shadow_rect behind the card when the toggle is on.
		"shadow":        bool(q.get("shadow", false)),
		"shadow_params": Look.shadow_params(cfg),
	}

## The default config-file location the workbench writes (the single source of truth the game reads).
const CONFIG_PATH := "res://games/grove/ui_kit_settings.json"
