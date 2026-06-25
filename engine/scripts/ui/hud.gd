extends RefCounted
## THE top bar (owner: a standalone module reused in every scene).
## The currency cluster (💧 🪙 💎 — three separate pills) and the settings gear are pinned to the same
## pixels on every screen; scenes keep their refs and refresh the labels.
## Usage:  var hud := Hud.build(self, {"on_level": Callable, "settings": Callable, "on_refresh": Callable})
##         hud.water.text = ...   (or call hud.refresh.call()). `on_refresh` is an optional host hook the
##         refresh fires last, for a scene that keeps live state derived from Save (e.g. the board's water).
## Look/feel values live in Tune (engine/scripts/core/tuning.gd → class Hud).

const Save = preload("res://engine/scripts/core/save.gd")
const Look = preload("res://engine/scripts/ui/skin.gd")
const Shop = preload("res://engine/scripts/ui/shop.gd")
const FX = preload("res://engine/scripts/ui/fx.gd")
const G = preload("res://engine/scripts/core/content.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const Strings = preload("res://engine/scripts/core/strings.gd")
const Pal = Game.PALETTE
const Tune = preload("res://engine/scripts/core/tuning.gd").Hud   # the engine's HUD dials
# The gold currency pill's look (padding, icon box, amount, plus button) is tuned in the UI Workbench
# and saved to the shared kit config. Loaded at runtime (matches nav_bar / inbox) to avoid a preload cycle.
const KIT_PATH := "res://games/grove/tools/ui_workbench_kit.gd"

const INK = Pal.INK
const CREAM = Pal.CREAM
const STRAW = Pal.STRAW

# The wallet is THREE separate gold pills centred across the top (board2.png); PILL_GAP is the gap
# between them. The settings gear is a top-right disc matched to the top-left level badge so the two top
# corners read at the SAME VISIBLE size + the same Y centre. The two boxes are NOT equal: the gear's
# disc_round art fills ~97% of its box but the level MEDAL art only ~78%, so equal boxes would render the
# medal much smaller. We size each box from its art's fill so the two painted shapes come out equal, and
# vertically CENTRE the (shorter) gear box within the (taller) level box so their centres line up.
const PILL_GAP := 12.0
const LV_BADGE_PX := 225.0   # the level-badge BOX (its medal fills ~78% → ~175px visible) — 50% bigger than the gear
const GEAR_PX := 120.0       # the gear BOX (its disc fills ~97% → ~116px visible, matching the medal)
const HUD_SIDE_Z := 30        # above ambient/weather, below fly/floating FX
const HUD_WALLET_Z := 40      # wallet stays above the side row when the top bands overlap
# the level MEDAL art is bottom-anchored and fills only ~78% of its 225px box, so ~44px of the box is
# empty space ABOVE the painted ring. Lift the badge by that inset so the ring's TOP edge sits flush
# with the wallet pills (whose panels start right at the edge margin), matching the gear's top corner.
const LV_BADGE_TOP_INSET := 44.0
const LV_BADGE_LEFT := 8.0     # painted badge edge aligns with the bottom Map tile's 32px side inset
const PILL_SHIFT_X := 24.0    # nudge the centred wallet a touch right, giving the big left badge more room

static func build(host: Control, opts: Dictionary = {}) -> Dictionary:
	# the workbench-tuned gold pill look (padding / font / icon box / plus)
	var Kit = load(KIT_PATH)
	var cfg: Dictionary = Kit.load_config(Kit.CONFIG_PATH)
	var pill: Dictionary = Kit.gold_currency_pill_opts_from_config(cfg)
	var num_size := int(pill.num_size)               # the workbench-tuned currency number font
	var icon_box := float(pill.icon_box)             # the workbench-tuned LAYOUT cell (centerline / min box)
	var icon_size := float(pill.get("icon_size", icon_box))   # the workbench-tuned icon SPRITE px (defaults to fill the box)
	# The wallet is THREE separate gold pills (water coin gem) centred across the TOP, each with its own green
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
	cluster.offset_left = PILL_SHIFT_X            # shift the centred cluster right (both offsets = translate)
	cluster.offset_right = PILL_SHIFT_X
	cluster.add_theme_constant_override("separation", int(PILL_GAP))
	cluster.alignment = BoxContainer.ALIGNMENT_CENTER
	cluster.z_index = HUD_WALLET_Z
	host.add_child(cluster)
	# The wallet is WATER · COIN · GEM (the star count is gone — the level badge already encodes stars).
	# Each pill keeps its icon/number/+ as DIRECT children of an inner row — the wallet-resolution
	# contract scenes/tests rely on: <cur>_label.get_parent() == row, row.get_parent() == the pill panel.
	# the sprite px = icon_size × per-currency optical (the workbench `icon_size` slider drives the icon),
	# centered in the icon_box cell.
	var gpx := int(round(icon_size))
	# seed each pill with the value `refresh` will read, so the build-time refresh is a silent no-op
	# (the numbers don't re-tick from 0 on every page change).
	var water0 := int(Save.grove().get("water", G.WATER_CAP))
	var water_pill := _pill(cluster, Kit, pill, "water", gpx, 1.0, Color.WHITE, num_size, icon_box, open_water, water0)
	var coin_pill := _pill(cluster, Kit, pill, "coin", gpx, Tune.COIN_OPTICAL, Tune.COIN_TINT, num_size, icon_box, open_coin, Save.coins())
	var gem_pill := _pill(cluster, Kit, pill, "gem", gpx, Tune.GEM_OPTICAL, Tune.GEM_TINT, num_size, icon_box, open_premium, Save.diamonds())
	var water_lbl: Label = water_pill.label
	var coins: Label = coin_pill.label
	var gems: Label = gem_pill.label

	# the optional top-RIGHT settings gear (board2.png), built from the SAME workbench-tuned disc the nav
	# buttons use so it matches them. Scenes pass `settings` (open the shared Settings card); absent → no gear.
	var gear: Button = null
	var settings_cb: Variant = opts.get("settings")
	if settings_cb is Callable and (settings_cb as Callable).is_valid():
		var gopts: Dictionary = Kit.home_button_opts_from_config(cfg)
		# Settings reuses the SAME rounded-rect badge the Map button uses (gear icon over a "Settings" label),
		# sized to match the side rail (RAIL_SCALE 0.80 × the home-button size — mirrors map.gd).
		var gear_px := roundf(float(gopts.get("px", 140)) * 0.80)
		gopts["px"] = gear_px
		gopts["shape"] = "rect"
		gear = Kit.home_button({"icon": "gear", "caption": Strings.t("settings.title"), "action": settings_cb}, gopts)
		var gtop := Tune.EDGE_MARGIN + Look.safe_top(host)
		gear.anchor_left = 1.0
		gear.anchor_right = 1.0
		gear.anchor_top = 0.0
		gear.anchor_bottom = 0.0
		gear.offset_left = -gear_px - Tune.EDGE_MARGIN
		gear.offset_right = -Tune.EDGE_MARGIN
		# top-align the gear with the currency pills — both pin to gtop, so the settings tile and the
		# wallet share a top edge (the map's live-ops rail then hangs directly beneath the gear so the
		# settings + rail read as one top-aligned right column; see map._build_liveops_rail).
		gear.offset_top = gtop
		gear.offset_bottom = gear.offset_top + gear_px
		gear.z_index = HUD_WALLET_Z
		host.add_child(gear)

	# The top-left cluster: Lv plus an optional HOME chip. This is intentionally separate
	# from the wallet; the level badge is player status, not currency.
	var left := HBoxContainer.new()
	left.offset_left = LV_BADGE_LEFT
	# top-align the badge with the wallet pills: lift it by the medal art's transparent top inset.
	left.offset_top = Tune.EDGE_MARGIN + Look.safe_top(host) - LV_BADGE_TOP_INSET
	left.add_theme_constant_override("separation", Tune.HOME_GAP)
	left.alignment = BoxContainer.ALIGNMENT_BEGIN
	left.z_index = HUD_SIDE_Z

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
	# the level "coin" — the shared LAYERED emblem (cut parts) + the big number.
	var lv_px := LV_BADGE_PX   # bigger BOX than the gear (its medal under-fills) so the visible medal matches
	# the level badge — the shared layered emblem + centred number (Look.make_level_badge). The HUD
	# carries the player's CURRENT level; `refresh` re-ticks the
	# number and, when leveling crosses a badge TIER (the part SET changes), rebuilds the emblem.
	var lvl0 := G.level_for_exp(Save.exp_total())
	# tap the level badge -> the level screen (stars earned / needed next), when the scene wires
	# "on_level". The badge's children ignore input, so the avatar itself catches the tap.
	var on_level: Variant = opts.get("on_level")
	var build_badge := func(lvl: int) -> Control:
		var av := Look.make_level_badge(lvl, lv_px, _lv_font_size(lvl))
		av.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if on_level is Callable and (on_level as Callable).is_valid():
			av.mouse_filter = Control.MOUSE_FILTER_STOP
			av.gui_input.connect(func(ev: InputEvent) -> void:
				var click: bool = (ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed) \
					or (ev is InputEventScreenTouch and not ev.pressed)
				if click:
					(on_level as Callable).call())
		return av
	var avatar: Control = build_badge.call(lvl0)
	# the rebuildable badge bits, shared with `refresh` via a dict (closures capture it by reference)
	var badge_state := {"avatar": avatar, "level": avatar.get_node_or_null("lv_num") as Label,
		"tier": Look.level_badge_index(lvl0)}
	lrow.add_child(avatar)
	left.add_child(lv_panel)

	# the standalone HOME chip, to the RIGHT of the Lv chip when requested.
	_build_home_chip(left, opts)
	host.add_child(left)

	# `wallet` is the centred 3-pill cluster (the container scenes raise above the shop backdrop); the
	# per-pill panels are returned too so the shop targets buy feedback + the map anchors its Store badge.
	# `water_icon` is the droplet box so the board's FTUE can hide the water icon + label together.
	var out := {"water": water_lbl, "water_icon": water_pill.icon, "coins": coins, "diamonds": gems,
		"level": badge_state["level"], "wallet": cluster, "lv_panel": lv_panel, "gear": gear,
		"water_pill": water_pill.panel, "coin_pill": coin_pill.panel, "gem_pill": gem_pill.panel,
		"water_plus": water_pill.plus, "coin_plus": coin_pill.plus, "gem_plus": gem_pill.plus}
	var refresh := func() -> void:
		# water is the board's energy; the map shows the persisted value, the board overrides live via
		# _update_water_hud. coin/gem tick on change. (no star count — the level badge carries stars.)
		_set_or_tick(water_lbl, int(Save.grove().get("water", G.WATER_CAP)))
		_set_or_tick(coins, Save.coins())
		_set_or_tick(gems, Save.diamonds())
		var earned := Save.exp_total()
		var lvl := G.level_for_exp(earned)
		var tier := Look.level_badge_index(lvl)
		if tier != int(badge_state["tier"]):
			# tier flipped -> rebuild the emblem (a tier changes the SET of parts, not just one frame)
			var old: Control = badge_state["avatar"]
			var nb: Control = build_badge.call(lvl)
			lrow.add_child(nb)
			if is_instance_valid(old):
				old.queue_free()
			badge_state["avatar"] = nb
			badge_state["level"] = nb.get_node_or_null("lv_num") as Label
			badge_state["tier"] = tier
			out["level"] = badge_state["level"]
		var lnum: Label = badge_state["level"]
		if lnum != null:
			_set_or_tick(lnum, lvl)
			lnum.add_theme_font_size_override("font_size", _lv_font_size(lvl))   # keep the number inside as digits grow
		# host hook: a scene that keeps live state derived from Save (the board's water cache + its
		# empty-water refill stack) re-syncs here, so a shop grant lands without per-currency callbacks.
		var host_refresh: Variant = opts.get("on_refresh")
		if host_refresh is Callable and (host_refresh as Callable).is_valid():
			(host_refresh as Callable).call()
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
		"water": {"node": water_pill.panel, "label": water_lbl},
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

# One currency pill: the workbench-styled gold badge wrapping a fixed icon BOX + the number + a green "+"
# that opens the store. Added to `cluster`; returns {panel, label, icon, plus}.
static func _pill(cluster: HBoxContainer, Kit: Variant, pill: Dictionary, icon_id: String, gsize: int,
		optical: float, tint: Color, num_size: int, box: float, open_store: Callable, init_count: int = 0) -> Dictionary:
	var po: Dictionary = pill.duplicate()
	po["icon"] = icon_id
	po["icon_size"] = float(gsize) * optical
	po["icon_box"] = box
	po["num_size"] = num_size
	po["count"] = init_count
	po["show_plus"] = true
	po["plus_action"] = open_store
	# born showing the CURRENT value, not 0 — so build()'s first refresh sets silently instead of
	# count-ticking up from 0 every time a page rebuilds the HUD.
	var panel: Control = Kit.gold_currency_pill(po, {icon_id: init_count})
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var lbl := panel.find_child("GoldCurrencyAmount", true, false) as Label
	var icon := panel.find_child("GoldCurrencyIcon", true, false) as Control
	if icon != null:
		icon.modulate = tint
		if icon is Label:
			(icon as Label).add_theme_color_override("font_color", tint)
			icon.modulate = Color.WHITE
	var plus := panel.find_child("GoldCurrencyPlusButton", true, false) as Control
	cluster.add_child(panel)
	return {"panel": panel, "label": lbl, "icon": icon, "plus": plus}

# A fixed square box with the currency sprite centered in it and scaled by an OPTICAL factor
# (so the dense flower, tall acorn, and slim gem read at matching weight). `tint` modulates the
# sprite to reinforce each currency's hue (star=gold, acorn=brown, gem=teal — gem ≠ water).
static func _icon_box(icon_id: String, gsize: int, optical: float, tint: Color, box_px: float) -> Control:
	var box := CenterContainer.new()
	box.custom_minimum_size = Vector2(box_px, box_px)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# the currency sprite, optically scaled. (Its lift off the gold pill is handled at the pill surface now,
	# not a per-icon drop shadow — the unified-shadow refactor retired the old `icon_shadow` polish.)
	var ic: Control = Look.icon(icon_id, float(gsize) * optical)
	ic.modulate = tint
	if ic is Label:                                   # glyph fallback — re-tint via font_color too
		(ic as Label).add_theme_color_override("font_color", tint)
		ic.modulate = Color.WHITE
	box.add_child(ic)
	return box

# A small "+" that opens the store — the acquire affordance (the wallet had no path to "get more").
# Wears the painted ui_asset2 "+" sprite (shared/icon_plus.png — a self-contained green plus token, so no
# code-drawn disc behind it); a "+" glyph falls back when the sprite is missing. Reuses the shared press juice.
static func _plus_button(open_store: Callable, box: float = Tune.PLUS_BOX) -> Button:
	var b := Button.new()
	b.flat = true                       # the sprite IS the token — the Button draws no chrome of its own
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.custom_minimum_size = Vector2(box, box)
	b.add_theme_constant_override("h_separation", 0)
	# the painted green "+" (glyph "+" fallback when absent). Its lift off the pill is the SHARED box-shadow.
	var mark: Control = Look.icon("plus", box)
	if mark is Label:                                   # glyph fallback: keep the cream-on-green token look
		(mark as Label).add_theme_color_override("font_color", Tune.PLUS_GLYPH)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Tune.PLUS_BG
		sb.set_corner_radius_all(int(box / 2.0))
		for st in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(st, sb)
	mark.set_anchors_preset(Control.PRESET_FULL_RECT)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(mark)
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


# The level number sits in the badge's open centre, which is tighter than the plain
# avatar — so a 2- or 3-digit Level must step the font DOWN to stay inside the gold
# ring (and clear the crown/laurel on the high badges) instead of crowding it.
static func _lv_font_size(level: int) -> int:
	# scaled to the LV_BADGE_PX medal so digits stay centred in the medal's open centre as it grows.
	if level >= 100:
		return 57
	if level >= 10:
		return 72
	return 92
