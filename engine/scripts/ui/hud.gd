extends RefCounted
## THE top bar (owner: a standalone module reused in every scene).
## The currency cluster (💧 🪙 💎 — three separate pills) and the settings gear are pinned to the same
## pixels on every screen; scenes keep their refs and refresh the labels.
## Usage:  var hud := Hud.build(self, {"water_grant": Callable})
##         hud.water.text = ...   (or call hud.refresh.call())
## Look/feel values live in Tune (engine/scripts/core/tuning.gd → class Hud).

const Save = preload("res://engine/scripts/core/save.gd")
const Look = preload("res://engine/scripts/ui/skin.gd")
const Shop = preload("res://engine/scripts/ui/shop.gd")
const FX = preload("res://engine/scripts/ui/fx.gd")
const G = preload("res://engine/scripts/core/content.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const Pal = Game.PALETTE
const Tune = preload("res://engine/scripts/core/tuning.gd").Hud   # the engine's HUD dials
# The currency pill's look (padding / border / font / icon box / gaps) is tuned in the UI Workbench and
# saved to the shared kit config; the kit resolves it with Tune.Hud as the defaults, so an absent config
# renders exactly the values above. Loaded at runtime (matches nav_bar / inbox) to avoid a preload cycle.
const KIT_PATH := "res://games/grove/tools/ui_workbench_kit.gd"

const INK = Pal.INK
const CREAM = Pal.CREAM
const STRAW = Pal.STRAW

# The currency pill's painted background (ui/shared/panel_pill.png) is a CAPSULE — its rounded
# gold caps are as tall as the whole pill. A nine-patch keeps those caps a fixed size while only
# the flat middle stretches to the counts (the style is built by Kit.currency_pill_style now, so
# both the live pill and the UI Workbench preview share one recipe). The slot is pinned ≥ the cap
# height so the rounded ends always draw 1:1 and never crush into a thin border (T48 failure mode).
const PILL_SLOT_H := 65.0
# The wallet is THREE separate capsules centred across the top (board2.png); PILL_GAP is the gap
# between them. The settings gear is a top-right disc matched to the top-left level badge so the two top
# corners read at the SAME VISIBLE size + the same Y centre. The two boxes are NOT equal: the gear's
# disc_round art fills ~97% of its box but the level MEDAL art only ~78%, so equal boxes would render the
# medal much smaller. We size each box from its art's fill so the two painted shapes come out equal, and
# vertically CENTRE the (shorter) gear box within the (taller) level box so their centres line up.
const PILL_GAP := 12.0
const LV_BADGE_PX := 150.0   # the level-badge BOX (its medal fills ~78% → ~116px visible)
const GEAR_PX := 120.0       # the gear BOX (its disc fills ~97% → ~116px visible, matching the medal)

static func build(host: Control, opts: Dictionary = {}) -> Dictionary:
	# the workbench-tuned pill look (padding / border / font / icon box / gaps); Tune.Hud values when unset
	var Kit = load(KIT_PATH)
	var cfg: Dictionary = Kit.load_config(Kit.CONFIG_PATH)
	var pill: Dictionary = Kit.currency_pill_opts_from_config(cfg)
	var num_size := int(pill.num_size)               # the workbench-tuned currency number font
	var icon_box := float(pill.icon_box)             # the workbench-tuned LAYOUT cell (centerline / min box)
	var icon_size := float(pill.get("icon_size", icon_box))   # the workbench-tuned icon SPRITE px (defaults to fill the box)
	# The wallet is THREE separate capsules (★ coin gem) centred across the TOP, each with its own green
	# "+" that opens the store (board2.png). The store opens through the +'s Button.pressed — which the
	# engine de-dupes against the emulated touch/mouse pair, so one tap opens it ONCE. (The old whole-pill
	# gui_input fired on BOTH the real mouse release AND the emulated touch release under
	# emulate_touch_from_mouse, opening the shop twice → it then had to be closed twice.)
	var shop_opts := opts.duplicate()
	# Each currency pill's "+" opens its OWN stall: water → water shop, coin → coin shop, gem → premium shop.
	var open_water := func() -> void: Shop.open_water(host, shop_opts)
	var open_coin := func() -> void: Shop.open_coin(host, shop_opts)
	var open_premium := func() -> void: Shop.open_premium(host, shop_opts)
	var cluster := HBoxContainer.new()
	cluster.anchor_left = 0.5
	cluster.anchor_right = 0.5
	cluster.grow_horizontal = Control.GROW_DIRECTION_BOTH
	cluster.offset_top = Tune.EDGE_MARGIN + Look.safe_top(host)
	cluster.add_theme_constant_override("separation", int(PILL_GAP))
	cluster.alignment = BoxContainer.ALIGNMENT_CENTER
	host.add_child(cluster)
	# The wallet is WATER · COIN · GEM (the star count is gone — the level badge already encodes stars).
	# Each pill keeps its icon/number/+ as DIRECT children of an inner row — the wallet-resolution
	# contract scenes/tests rely on: <cur>_label.get_parent() == row, row.get_parent() == the pill panel.
	# the sprite px = icon_size × per-currency optical (the workbench `icon_size` slider drives the icon),
	# centered in the icon_box cell.
	var gpx := int(round(icon_size))
	var water_pill := _pill(cluster, Kit, pill, "water", gpx, 1.0, Color.WHITE, num_size, icon_box, open_water)
	var coin_pill := _pill(cluster, Kit, pill, "coin", gpx, Tune.COIN_OPTICAL, Tune.COIN_TINT, num_size, icon_box, open_coin)
	var gem_pill := _pill(cluster, Kit, pill, "gem", gpx, Tune.GEM_OPTICAL, Tune.GEM_TINT, num_size, icon_box, open_premium)
	var water_lbl: Label = water_pill.label
	var coins: Label = coin_pill.label
	var gems: Label = gem_pill.label

	# the optional top-RIGHT settings gear (board2.png), built from the SAME workbench-tuned disc the nav
	# buttons use so it matches them. Scenes pass `settings` (open the shared Settings card); absent → no gear.
	var gear: Button = null
	var settings_cb: Variant = opts.get("settings")
	if settings_cb is Callable and (settings_cb as Callable).is_valid():
		var gopts: Dictionary = Kit.home_button_opts_from_config(cfg)
		gopts["px"] = GEAR_PX
		gear = Kit.home_button({"icon": "gear", "caption": "", "action": settings_cb}, gopts)
		var gtop := Tune.EDGE_MARGIN + Look.safe_top(host)
		gear.anchor_left = 1.0
		gear.anchor_right = 1.0
		gear.anchor_top = 0.0
		gear.anchor_bottom = 0.0
		gear.offset_left = -GEAR_PX - Tune.EDGE_MARGIN
		gear.offset_right = -Tune.EDGE_MARGIN
		# centre the (shorter) gear box within the level badge's box span [gtop, gtop+LV_BADGE_PX] so the
		# gear's disc and the level medal share a Y centre — both art shapes sit ~box-centred.
		gear.offset_top = gtop + (LV_BADGE_PX - GEAR_PX) / 2.0
		gear.offset_bottom = gear.offset_top + GEAR_PX
		host.add_child(gear)

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
	var lv_px := LV_BADGE_PX   # bigger BOX than the gear (its medal under-fills) so the visible medal matches
	# the level badge — the shared evolving medal + centred number (Look.make_level_badge, also used
	# by the locked-cell gate markers). The HUD carries the player's CURRENT level and swaps the
	# medal/number in `refresh` on level-up; `_lv_font_size` keeps the HUD's tuned opening size.
	var lvl0 := G.level_for_stars(int(Save.grove().get("stars_earned", 0)))
	var avatar := Look.make_level_badge(lvl0, lv_px, _lv_font_size(lvl0))
	avatar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var frame := avatar.get_node_or_null("lv_frame") as TextureRect   # null when on the honey-token fallback
	var level := avatar.get_node_or_null("lv_num") as Label
	# tap the level badge -> open the level screen (stars earned / needed for the next level), when
	# the scene wires "on_level". The badge's children ignore input, so the avatar catches the tap.
	var on_level: Variant = opts.get("on_level")
	if on_level is Callable and (on_level as Callable).is_valid():
		avatar.mouse_filter = Control.MOUSE_FILTER_STOP
		avatar.gui_input.connect(func(ev: InputEvent) -> void:
			var click: bool = (ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed) \
				or (ev is InputEventScreenTouch and not ev.pressed)
			if click:
				(on_level as Callable).call())
	lrow.add_child(avatar)
	left.add_child(lv_panel)

	# the standalone HOME chip, to the RIGHT of the Lv chip when requested.
	_build_home_chip(left, opts)
	host.add_child(left)

	var frame_state := {"tier": Look.level_badge_index(lvl0)}   # only reload when the badge tier flips
	# `wallet` is the centred 3-pill cluster (the container scenes raise above the shop backdrop); the
	# per-pill panels are returned too so the shop targets buy feedback + the map anchors its Store badge.
	# `water_icon` is the droplet box so the board's FTUE can hide the water icon + label together.
	var out := {"water": water_lbl, "water_icon": water_pill.icon, "coins": coins, "diamonds": gems,
		"level": level, "wallet": cluster, "lv_panel": lv_panel, "gear": gear,
		"water_pill": water_pill.panel, "coin_pill": coin_pill.panel, "gem_pill": gem_pill.panel,
		"water_plus": water_pill.plus, "coin_plus": coin_pill.plus, "gem_plus": gem_pill.plus}
	var refresh := func() -> void:
		# water is the board's energy; the map shows the persisted value, the board overrides live via
		# _update_water_hud. coin/gem tick on change. (no star count — the level badge carries stars.)
		_set_or_tick(water_lbl, int(Save.grove().get("water", G.WATER_CAP)))
		_set_or_tick(coins, Save.coins())
		_set_or_tick(gems, Save.diamonds())
		var earned := int(Save.grove().get("stars_earned", 0))
		var lvl := G.level_for_stars(earned)
		_set_or_tick(level, lvl)
		level.add_theme_font_size_override("font_size", _lv_font_size(lvl))   # keep the number inside the badge as digits grow
		# Upgrade the frame when leveling crosses a badge tier.
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
	# The shop drops its own (redundant) currency strip and reuses THIS bar as the wallet: pass each
	# pill + label so buy feedback (fly-home / tick / "need more" wobble) targets the right capsule, and
	# the top-bar panels so the shop can RAISE them crisp above its blurred backdrop. The shop only raises
	# DIRECT children of host, so we pass the CLUSTER (the pills' parent) — raising it lifts all 3 pills.
	var raise_panels: Array = [cluster, lv_panel]
	if gear != null:
		raise_panels.append(gear)
	shop_opts["wallet"] = {
		"coin": {"node": coin_pill.panel, "label": coins},
		"gem": {"node": gem_pill.panel, "label": gems},
		"panels": raise_panels,
	}
	# The per-stall openers (the pills' + buttons share these); `open_shop` stays as the generic "open the
	# shop" handle, pointed at the premium (acorn) stall, for callers that don't care which stall.
	out["open_water"] = open_water
	out["open_coin"] = open_coin
	out["open_premium"] = open_premium
	out["open_shop"] = open_premium
	refresh.call()
	return out

# One currency CAPSULE: the workbench-styled pill wrapping a fixed icon BOX + the number + a green "+"
# that opens the store. Added to `cluster`; returns {panel, label, icon, plus}. The icon and number are
# DIRECT children of an inner `row` — the wallet-resolution contract: label.get_parent() == row, and
# row.get_parent() == the pill PanelContainer (scenes/tests resolve the pill as label.get_parent().get_parent()).
# The "+" FLOATS over the pill (Look.float_plus) so its LOCATION and SIZE are tunable from the workbench
# without touching the capsule: plus_x slides it along the pill's right edge, plus_dy nudges it up(-)/down(+),
# and plus_size scales it — none of which grow the pill.
static func _pill(cluster: HBoxContainer, Kit: Variant, pill: Dictionary, icon_id: String, gsize: int,
		optical: float, tint: Color, num_size: int, box: float, open_store: Callable) -> Dictionary:
	var panel := PanelContainer.new()
	# the same painted capsule the workbench tunes (one recipe; T48 cap-height slot keeps the gold ends 1:1)
	panel.add_theme_stylebox_override("panel", Kit.currency_pill_style(pill))
	panel.custom_minimum_size.y = PILL_SLOT_H
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(pill.row_sep))   # the tight icon↔number↔+ gap
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(row)
	var icon := _icon_box(icon_id, gsize, optical, tint, box)
	row.add_child(icon)
	var lbl := Label.new()
	lbl.add_theme_font_size_override("font_size", num_size)
	lbl.add_theme_color_override("font_color", INK)   # AC4: dark text on the cream pill
	lbl.add_theme_constant_override("outline_size", 0)   # AF6: no dark halo on a solid pill (panel-text law)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(lbl)
	var plus := _plus_button(open_store, float(pill.get("plus_size", Tune.PLUS_BOX)))   # green "+", size tuned in the workbench
	# the "+" FLOATS over the pill: its size never grows the capsule, and plus_x / plus_dy place it on the
	# right edge. The HOLDER (sized to the pill) is what the cluster lays out — the pill is its full-rect child.
	# `plus` is a plain Button (not a Container), so a caller can attach_badge() to it (the map's Store badge
	# rides the + now); the pill PANEL is a PanelContainer, which would force-fill any badge child into a bar.
	cluster.add_child(Look.float_plus(panel, plus, pill))
	return {"panel": panel, "label": lbl, "icon": icon, "plus": plus}

# A fixed square box with the currency sprite centered in it and scaled by an OPTICAL factor
# (so the dense flower, tall acorn, and slim gem read at matching weight). `tint` modulates the
# sprite to reinforce each currency's hue (star=gold, acorn=brown, gem=teal — gem ≠ water).
static func _icon_box(icon_id: String, gsize: int, optical: float, tint: Color, box_px: float) -> Control:
	var box := CenterContainer.new()
	box.custom_minimum_size = Vector2(box_px, box_px)
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
static func _plus_button(open_store: Callable, box: float = Tune.PLUS_BOX) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE   # NOT flat — flat suppresses the stylebox bg (the green token)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.custom_minimum_size = Vector2(box, box)
	b.add_theme_constant_override("h_separation", 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Tune.PLUS_BG                          # plain leaf green — the "get more" CTA hue (no border ring)
	sb.set_corner_radius_all(int(box / 2.0))
	sb.set_border_width_all(0)
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, sb)
	var g := Label.new()
	g.text = "+"
	g.add_theme_font_size_override("font_size", int(box * float(Tune.PLUS_SIZE) / float(Tune.PLUS_BOX)))   # font tracks the box
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

# The level-chip frame texture: the evolving gold badge for this Level (ui/lvl/badge_NN.png,
# mapped by data/level_badges.json), or null when the art is missing or a degenerate import —
# the HUD then shows the honey-token coin. There is no ring fallback; every shipped badge must
# be alpha-cut (transparent corners), enforced by engine/tests/level_badge_tests.gd.
static func _frame_tex(level: int) -> Texture2D:
	return _safe_tex(Look.level_badge_path(level))

# The level number sits in the badge's open centre, which is tighter than the plain
# avatar — so a 2- or 3-digit Level must step the font DOWN to stay inside the gold
# ring (and clear the crown/laurel on the high badges) instead of crowding it.
static func _lv_font_size(level: int) -> int:
	# scaled to the LV_BADGE_PX medal so digits stay centred in the medal's open centre as it grows.
	if level >= 100:
		return 38
	if level >= 10:
		return 48
	return 61
