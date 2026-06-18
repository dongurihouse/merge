extends RefCounted
## THE top bar (owner: a standalone module reused in every scene).
## The currency cluster (★ 🪙 💎) and the Store button are pinned to the same
## pixels on every screen; scenes keep their refs and refresh the labels.
## Usage:  var hud := Hud.build(self, {"water_grant": Callable})
##         hud.stars.text = ...   (or call hud.refresh.call())
## Look/feel values live in Tune (engine/scripts/core/tuning.gd → class Hud).

const Save = preload("res://engine/scripts/core/save.gd")
const Look = preload("res://engine/scripts/ui/skin.gd")
const Shop = preload("res://engine/scripts/ui/shop.gd")
const FX = preload("res://engine/scripts/ui/fx.gd")
const G = preload("res://engine/scripts/core/content.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const Pal = Game.PALETTE
const Tune = preload("res://engine/scripts/core/tuning.gd").Hud   # the engine's HUD dials

const INK = Pal.INK
const CREAM = Pal.CREAM
const STRAW = Pal.STRAW

# The currency pill's painted background (ui/kit/panel_pill.png) is a CAPSULE — its rounded
# gold caps are as tall as the whole pill. A nine-patch keeps those caps a fixed size while
# only the flat middle stretches to the counts, BUT a nine-patch corner draws 1:1 (no scale),
# so the source must be exported at the rendered slot height or the caps crush into a thin
# border (the exact failure that retired the old chip nine-patch, T48). The slot is 346×65
# (probe); the asset is 292×65, cap radius ≈ 32 → that is the nine-patch margin.
const PILL_SLOT_H := 65.0
const PILL_CAP_PX := 32

static func build(host: Control, opts: Dictionary = {}) -> Dictionary:
	var panel := PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_right = -Tune.EDGE_MARGIN
	panel.offset_top = Tune.EDGE_MARGIN + Look.safe_top(host)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	# R1: the plank must visibly WRAP the whole cluster with EVEN padding.
	# (The old dark chip nine-patch was an asymmetric pill thinner than the layout rect —
	# on this short strip even layout padding read as lopsided and the tall icons spilled
	# past the opaque band; that widget is now retired entirely, T48.) A clean wood-tone
	# pill makes layout padding == visual padding (so the rect asserts below match what the
	# eye sees), and fully contains the row.
	panel.add_theme_stylebox_override("panel", _pill_style())
	# pin the slot ≥ the nine-patch cap height so the painted capsule's rounded gold ends
	# always draw 1:1 and never crush into a thin border (T48 failure mode).
	panel.custom_minimum_size.y = PILL_SLOT_H
	var row := HBoxContainer.new()
	# The row's uniform separation IS the tight icon↔number gap; the WIDER gap BETWEEN
	# currencies comes from explicit spacer Controls (so every pair shares one centerline
	# and the numbers align). Keeping every icon/number/+ a DIRECT child of `row` is also a
	# contract: scenes resolve the wallet panel as stars_label.get_parent().get_parent().
	row.add_theme_constant_override("separation", Tune.CHIP_ROW_SEP)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(row)
	# The wallet cluster owns currencies only. Lv stays in the standalone top-left HUD row;
	# HOME joins that row only when a scene passes it as navigation chrome.
	var shop_opts := opts.duplicate()
	var open_store := func() -> void: Shop.open(host, shop_opts)
	var stars := _pair(row, "star", Tune.STAR_ICON, Tune.STAR_OPTICAL, Tune.STAR_TINT, false, open_store)
	_spacer(row)
	var coins := _pair(row, "coin", Tune.COIN_ICON, Tune.COIN_OPTICAL, Tune.COIN_TINT, false, open_store)
	_spacer(row)
	var gems := _pair(row, "gem", Tune.GEM_ICON, Tune.GEM_OPTICAL, Tune.GEM_TINT, false, open_store)
	# the whole currency pill is the acquire affordance now — a tap anywhere on it opens the
	# store (the per-currency "+" buttons are retired; they bloated the pill + skewed its padding).
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(func(ev: InputEvent) -> void:
		var click: bool = (ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed) \
			or (ev is InputEventScreenTouch and not ev.pressed)
		if click and open_store.is_valid():
			open_store.call())
	host.add_child(panel)

	# The top-left cluster: Lv plus an optional HOME chip. This is intentionally separate
	# from the wallet; the level badge is player status, not currency.
	var left := HBoxContainer.new()
	left.offset_left = Tune.EDGE_MARGIN
	left.offset_top = Tune.EDGE_MARGIN + Look.safe_top(host)
	left.add_theme_constant_override("separation", Tune.HOME_GAP)
	left.alignment = BoxContainer.ALIGNMENT_BEGIN

	# S10: the Lv chip is part of THE module — same top-left pixels in both scenes.
	# The level number sits INSIDE the sprout avatar; the level-progress fraction sits to
	# its right at a readable size (it used to be icon + number + fraction in a
	# row, which read as "5 420/500" — one garbled value). value TICKS on change.
	var lv_panel := PanelContainer.new()
	lv_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# the level badge is the painted rope RING — no cream mini-pill behind it and no "n/m"
	# fraction beside it. (lv_panel stays a valid Control because the map keeps it in its
	# panel list; it just carries no background now.)
	lv_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var lrow := HBoxContainer.new()
	lrow.add_theme_constant_override("separation", Tune.LV_ROW_SEP)
	lrow.alignment = BoxContainer.ALIGNMENT_CENTER
	lv_panel.add_child(lrow)
	# the level "coin" — a Panel hosting the rope-ring sprite + the big number.
	var lv_px := 72.0   # standalone top-left badge size
	var avatar := Panel.new()
	avatar.custom_minimum_size = Vector2(lv_px, lv_px)
	avatar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# the level badge FRAME — an EVOLVING gold ring that upgrades with Level (kit/badges/
	# badge_NN.png, sliced from lvls.png, mapped by data/level_badges.json). Falls back to
	# the single rope ring (`ring_level.png`), then a honey token (de-greened: green is the
	# CTA), so the chip still reads on any build. The texture is swapped on level-up in
	# `refresh` below; the INK number sits centred in its open middle.
	var lvl0 := G.level_for_stars(int(Save.grove().get("stars_earned", 0)))
	var frame_tex := _frame_tex(lvl0)   # badge -> rope ring -> null; null only if NO art loads
	var frame: TextureRect = null
	if frame_tex != null:
		avatar.add_theme_stylebox_override("panel", StyleBoxEmpty.new())   # no default dark Panel bg behind the ring
		# a cream disc fills the ring's open centre (reference: the number reads on cream, not sky)
		var disc := Panel.new()
		var dpad := lv_px * 0.16
		disc.position = Vector2(dpad, dpad)
		disc.size = Vector2(lv_px - dpad * 2.0, lv_px - dpad * 2.0)
		var dsb := StyleBoxFlat.new()
		dsb.bg_color = Color("#FBF3E2")
		dsb.set_corner_radius_all(int(lv_px))
		disc.add_theme_stylebox_override("panel", dsb)
		disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		avatar.add_child(disc)
		frame = TextureRect.new()
		frame.texture = frame_tex
		frame.set_anchors_preset(Control.PRESET_FULL_RECT)
		frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		avatar.add_child(frame)
	else:
		var coin := StyleBoxFlat.new()
		coin.bg_color = Tune.LV_TOKEN_BG            # honey token — warm, not the CTA green
		coin.set_corner_radius_all(int(lv_px / 2.0))
		coin.set_border_width_all(Tune.PILL_BORDER_W)
		coin.border_color = Tune.LV_TOKEN_BORDER    # warm gold ring (matches the pill border)
		avatar.add_theme_stylebox_override("panel", coin)
	var level := Label.new()
	level.add_theme_font_size_override("font_size", _lv_font_size(lvl0))   # fits the badge opening (steps down for 2-3 digits)
	level.add_theme_color_override("font_color", INK)
	level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	level.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level.set_anchors_preset(Control.PRESET_FULL_RECT)
	avatar.add_child(level)
	lrow.add_child(avatar)
	var level_prog := Label.new()
	level_prog.add_theme_font_size_override("font_size", Tune.LVL_PROG_SIZE)   # readable (was 20), to the RIGHT of the avatar
	level_prog.add_theme_color_override("font_color", Color(INK, Tune.LVL_PROG_INK_ALPHA))
	level_prog.add_theme_constant_override("outline_size", 0)
	level_prog.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# the "n/m" progress fraction is retired from the badge (reference shows the ring + number
	# only). level_prog stays constructed (the map still reads the dict key) but is never shown.
	left.add_child(lv_panel)

	# the standalone HOME chip, to the RIGHT of the Lv chip when requested.
	var home_btn := _build_home_chip(left, opts)
	host.add_child(left)

	var frame_state := {"tier": Look.level_badge_index(lvl0)}   # only reload when the badge tier flips
	var out := {"stars": stars, "coins": coins, "diamonds": gems, "level": level, "level_prog": level_prog,
		"level_frame": frame, "wallet": panel, "lv_panel": lv_panel, "home": home_btn}
	var refresh := func() -> void:
		_set_or_tick(stars, Save.stars())
		_set_or_tick(coins, Save.coins())
		_set_or_tick(gems, Save.diamonds())
		var earned := int(Save.grove().get("stars_earned", 0))
		var lvl := G.level_for_stars(earned)
		_set_or_tick(level, lvl)
		level.add_theme_font_size_override("font_size", _lv_font_size(lvl))   # keep the number inside the badge as digits grow
		level_prog.text = "%d/%d" % [earned, G.stars_at_level(lvl + 1)]   # uncapped — always a next level
		# Upgrade the frame when leveling crosses a badge tier, but still route through
		# _frame_tex so opaque-corner badge slices cannot bring back a square backing.
		if frame != null:
			var tier := Look.level_badge_index(lvl)
			if tier != int(frame_state["tier"]):
				var t := _frame_tex(lvl)
				if t != null:
					frame.texture = t
					frame_state["tier"] = tier
	out["refresh"] = refresh
	# `shop_opts` was duplicated up top (so the + acquire buttons share the SAME options);
	# wire `refresh` into it now — the closure captured the dict by reference, so both the +
	# buttons and the bottom-bar store tick the wallet after a purchase.
	shop_opts["refresh"] = refresh
	# The shop drops its own (redundant) currency strip and reuses THIS bar as the wallet:
	# pass the cluster pill + labels so buy feedback (fly-home / tick / "need more" wobble)
	# targets it, and both pills so the shop can RAISE them crisp above its blurred backdrop.
	shop_opts["wallet"] = {
		"coin": {"node": panel, "label": coins},
		"gem": {"node": panel, "label": gems},
		"panels": [panel, lv_panel],
	}
	out["open_shop"] = open_store   # currency item 2: same Shop.open(host, shop_opts), shared with the + buttons
	refresh.call()
	return out

# The currency-cluster background: prefer the painted capsule (ui/kit/panel_pill.png),
# nine-sliced so the rounded gold caps keep a FIXED size while only the flat middle stretches
# to the three counts; fall back to the code-drawn cream pill when the art is absent. The
# content margins (text inset) are identical on both paths, so the layout rect — and the R1
# even-wrap contract (grove_tests) — is unchanged regardless of which background draws.
static func _pill_style() -> StyleBox:
	var p := Look.kit("panel_pill.png")
	if ResourceLoader.exists(p):
		var sbt := StyleBoxTexture.new()
		sbt.texture = load(p)
		sbt.set_texture_margin_all(PILL_CAP_PX)   # = cap radius: round ends never squash
		sbt.content_margin_left = Tune.CLUSTER_PAD_X
		sbt.content_margin_right = Tune.CLUSTER_PAD_X
		sbt.content_margin_top = Tune.PILL_PAD_Y
		sbt.content_margin_bottom = Tune.PILL_PAD_Y
		return sbt
	var sb := StyleBoxFlat.new()
	sb.bg_color = Tune.PILL_BG             # AC4: soft cream pill (was dark wood)
	sb.set_corner_radius_all(Tune.PILL_RADIUS)
	sb.set_border_width_all(Tune.PILL_BORDER_W)
	sb.border_color = Tune.PILL_BORDER     # warm border (matches the AB ask pills)
	sb.shadow_color = Tune.PILL_SHADOW
	sb.shadow_size = Tune.PILL_SHADOW_SIZE
	sb.content_margin_left = Tune.CLUSTER_PAD_X
	sb.content_margin_right = Tune.CLUSTER_PAD_X
	sb.content_margin_top = Tune.PILL_PAD_Y
	sb.content_margin_bottom = Tune.PILL_PAD_Y
	return sb

# One currency pair: a fixed icon BOX (so all three share a centerline) + the number, and
# optionally a small "+" acquire button that opens the store. The icon, number, and + are all
# DIRECT children of `row` (the wallet-resolution contract: stars_label.get_parent() == row),
# so the wider gap BETWEEN currencies comes from _spacer, never an inner container.
static func _pair(row: HBoxContainer, icon_id: String, gsize: int, optical: float,
		tint: Color, plus: bool, open_store: Callable) -> Label:
	row.add_child(_icon_box(icon_id, gsize, optical, tint))
	var lbl := Label.new()
	lbl.add_theme_font_size_override("font_size", Tune.NUM_SIZE)
	lbl.add_theme_color_override("font_color", INK)   # AC4: dark text on the cream pill
	lbl.add_theme_constant_override("outline_size", 0)   # AF6: no dark halo on a solid pill (panel-text law)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(lbl)
	if plus:
		row.add_child(_plus_button(open_store))
	return lbl

# A fixed square box with the currency sprite centered in it and scaled by an OPTICAL factor
# (so the dense flower, tall acorn, and slim gem read at matching weight). `tint` modulates the
# sprite to reinforce each currency's hue (star=gold, acorn=brown, gem=teal — gem ≠ water).
static func _icon_box(icon_id: String, gsize: int, optical: float, tint: Color) -> Control:
	var box := CenterContainer.new()
	box.custom_minimum_size = Vector2(Tune.CHIP_ICON_BOX, Tune.CHIP_ICON_BOX)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := Look.icon(icon_id, float(gsize) * optical)
	ic.modulate = tint
	if ic is Label:                                   # glyph fallback — re-tint via font_color too
		(ic as Label).add_theme_color_override("font_color", tint)
		ic.modulate = Color.WHITE
	box.add_child(ic)
	return box

# A small round "+" that opens the store — the acquire affordance (the wallet had no path to
# "get more"). Reuses Look.add_press_juice so it inherits the shared button polish.
static func _plus_button(open_store: Callable) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE   # NOT flat — flat suppresses the stylebox bg (the green token)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.custom_minimum_size = Vector2(Tune.PLUS_BOX, Tune.PLUS_BOX)
	b.add_theme_constant_override("h_separation", 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Tune.PLUS_BG                          # leaf green — the "get more" CTA hue
	sb.set_corner_radius_all(int(Tune.PLUS_BOX / 2.0))
	sb.set_border_width_all(2)
	sb.border_color = Tune.PLUS_BORDER
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, sb)
	var g := Label.new()
	g.text = "+"
	g.add_theme_font_size_override("font_size", Tune.PLUS_SIZE)
	g.add_theme_color_override("font_color", Tune.PLUS_GLYPH)
	g.add_theme_constant_override("outline_size", 0)
	g.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	g.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	g.set_anchors_preset(Control.PRESET_FULL_RECT)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(g)
	Look.add_press_juice(b)
	if open_store.is_valid():
		b.pressed.connect(func() -> void: open_store.call())
	return b

# A fixed-width invisible gap BETWEEN currency pairs (the row's own separation is the tight
# icon↔number gap; this widens only pair↔pair while every node stays a direct row child).
static func _spacer(row: HBoxContainer) -> void:
	var s := Control.new()
	s.custom_minimum_size = Vector2(Tune.PAIR_SEP - Tune.CHIP_ROW_SEP, 0)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(s)

# HOME — its own pinned chip (a cream pill matching the HUD language), placed to the right of
# the Lv chip in the shared left row. Pulled OUT of the wallet pill so nav ≠ currency. Returns
# the inner button (null when no `home` callback) so scenes can target/spotlight it.
static func _build_home_chip(left: HBoxContainer, opts: Dictionary) -> Button:
	var home_cb: Variant = opts.get("home")
	if not (home_cb is Callable and (home_cb as Callable).is_valid()):
		return null
	var pill := PanelContainer.new()
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb := StyleBoxFlat.new()
	sb.bg_color = Tune.PILL_BG
	sb.set_corner_radius_all(Tune.PILL_RADIUS)
	sb.set_border_width_all(Tune.PILL_BORDER_W)
	sb.border_color = Tune.PILL_BORDER
	sb.shadow_color = Tune.PILL_SHADOW
	sb.shadow_size = Tune.PILL_SHADOW_SIZE
	sb.content_margin_left = Tune.PILL_PAD_Y          # square padding → a round chip
	sb.content_margin_right = Tune.PILL_PAD_Y
	sb.content_margin_top = Tune.PILL_PAD_Y
	sb.content_margin_bottom = Tune.PILL_PAD_Y
	pill.add_theme_stylebox_override("panel", sb)
	var home_btn := Button.new()
	home_btn.flat = true
	home_btn.focus_mode = Control.FOCUS_NONE
	var hg := Look.icon("home", Tune.HOME_ICON)
	hg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	home_btn.add_child(hg)
	home_btn.custom_minimum_size = Vector2(Tune.HOME_ICON, Tune.HOME_ICON)
	Look.add_press_juice(home_btn)
	home_btn.pressed.connect(func() -> void: (home_cb as Callable).call())
	pill.add_child(home_btn)
	left.add_child(pill)
	return home_btn

# Numbers TICK when they change (spec §7) and set silently when they don't.
static func _set_or_tick(lbl: Label, v: int) -> void:
	if lbl.text.is_valid_int() and int(lbl.text) != v and lbl.is_inside_tree():
		FX.tick(lbl, v)
	else:
		lbl.text = str(v)

# Load a texture only if it BOTH exists AND imports to a GENUINE, fully-imported image.
# Two distinct failure modes to reject (both would otherwise put garbage in the frame):
#   1) ResourceLoader.exists() can return true from a committed .import while the imported
#      .ctex is missing (new art not yet reimported in this checkout) — load() then returns
#      null, which would leave the frame BLANK (a ringless cream disc).
#   2) WORSE: when the .ctex is STALE/unresolved on the player's machine, load() returns a
#      NON-null import PLACEHOLDER (a PlaceholderTexture2D — the engine's missing-texture
#      stand-in). A bare `as Texture2D` lets that through, and the square frame TextureRect
#      then renders Godot's missing-texture CHECKERBOARD ("the white grid"). So a non-null
#      result is NOT enough — we must confirm it is a real, decoded image.
# We accept ONLY the concrete texture types a real imported .ctex (or runtime ImageTexture)
# produces, and require non-zero pixels. The placeholder is a PlaceholderTexture2D (and any
# other untyped fallback fails the type test), so it is rejected here — the caller then
# falls through to the next VISIBLE, non-square fallback (rope ring → honey token), and a
# checkerboard can never reach the screen.
static func _safe_tex(path: String) -> Texture2D:
	if path == "" or not ResourceLoader.exists(path):
		return null
	var res := load(path)
	# Reject the import placeholder by allow-listing only genuine image textures. A stale
	# .ctex resolves to PlaceholderTexture2D (NOT in this list) → rejected, not drawn.
	var real := res is CompressedTexture2D or res is ImageTexture or res is PortableCompressedTexture2D
	if not real:
		return null
	var tex := res as Texture2D
	# A genuine import always has real pixels; a zero-size texture is a degenerate/empty
	# import we should never paint into the frame rect.
	if tex == null or tex.get_width() <= 0 or tex.get_height() <= 0:
		return null
	return tex

# The level-chip frame texture: use tier art only when its corners are really transparent.
# Some sliced badge PNGs currently carry an opaque checker/white backing; those must not
# appear in the compact HUD, so they fall back to the clean rope ring.
static func _frame_tex(level: int) -> Texture2D:
	var badge := _safe_tex(Look.level_badge_path(level))
	if badge != null and _tex_has_transparent_corner(badge):
		return badge
	var ring := _safe_tex(Look.kit("ring_level.png"))
	if ring != null:
		return ring
	return badge

static func _tex_has_transparent_corner(tex: Texture2D) -> bool:
	if tex == null:
		return false
	var img := tex.get_image()
	if img == null or img.get_width() <= 0 or img.get_height() <= 0:
		return false
	var x := img.get_width() - 1
	var y := img.get_height() - 1
	return img.get_pixel(0, 0).a < 0.2 \
		or img.get_pixel(x, 0).a < 0.2 \
		or img.get_pixel(0, y).a < 0.2 \
		or img.get_pixel(x, y).a < 0.2

# The level number sits in the badge's open centre, which is tighter than the plain
# avatar — so a 2- or 3-digit Level must step the font DOWN to stay inside the gold
# ring (and clear the crown/laurel on the high badges) instead of crowding it.
static func _lv_font_size(level: int) -> int:
	if level >= 100:
		return 22
	if level >= 10:
		return 28
	return 36
