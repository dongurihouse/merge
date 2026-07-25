extends RefCounted
## THE top bar (owner: a standalone module reused in every scene).
## The currency cluster (💧 🪙 💎 — three separate pills) and level badge are pinned to the same
## pixels on every screen; scenes keep their refs and refresh the labels.
## Usage:  var hud := Hud.build(self, {"on_level": Callable, "on_refresh": Callable})
##         hud.water.text = ...   (or call hud.refresh.call()). `on_refresh` is an optional host hook the
##         refresh fires last, for a scene that keeps live state derived from Save (e.g. the board's water).
## Look/feel values live in Tune (engine/scripts/core/tuning.gd → class Hud).

const Save = preload("res://engine/scripts/core/save.gd")
const Look = preload("res://engine/scripts/ui/skin.gd")
const Shop = preload("res://engine/scripts/ui/shop.gd")
const FX = preload("res://engine/scripts/ui/fx.gd")
const G = preload("res://engine/scripts/core/content.gd")
const Design = preload("res://engine/scripts/core/design.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const Pal = Game.PALETTE
const Tune = preload("res://engine/scripts/core/tuning.gd").Hud   # the engine's HUD dials
# The gold currency pill's look (padding, icon box, amount, plus button) is tuned in the UI Workbench
# and saved to the shared kit config. Loaded at runtime (matches nav_bar / inbox) to avoid a preload cycle.
const KIT_PATH := "res://games/grove/tools/ui_workbench_kit.gd"

const INK = Pal.INK
const CREAM = Pal.CREAM
const STRAW = Pal.STRAW

const HUD_SIDE_Z := 30        # above ambient/weather, below fly/floating FX
const HUD_WALLET_Z := 40      # wallet stays above the side row when the top bands overlap
const LEVEL_BADGE_SCALE := 1.2

# The Y where the HUD's tallest top element ends — the Lv badge (pill_h × LEVEL_BADGE_SCALE, the
# currency pills are shorter). Page content anchors BELOW this so it never slides behind the pills.
# Excludes the safe-area inset; callers add Look.safe_top themselves.
static func bottom_px() -> float:
	var Kit = load(KIT_PATH)
	var cfg: Dictionary = Kit.load_config(Kit.CONFIG_PATH)
	var layout: Dictionary = Kit.hud_layout_opts_from_config(cfg)
	var pill: Dictionary = Kit.gold_currency_pill_opts_from_config(cfg)
	var lv_px := maxf(1.0, ceilf(float(pill.pill_h) * LEVEL_BADGE_SCALE))
	return float(layout.get("edge_margin_px", 18.0)) + lv_px

static func _view_size(host: Control) -> Vector2:
	if host != null and host.is_inside_tree():
		var v := host.get_viewport_rect().size
		if v.x > 0.0 and v.y > 0.0:
			return v
	return Design.size()

static func _screen_w_px(view: Vector2, frac: float) -> float:
	return maxf(1.0, roundf(view.x * frac))

static func _set_slot_width(node: Control, width: float) -> void:
	if node == null:
		return
	# EXPAND_FILL makes the three pills share the wallet cluster EQUALLY — that, not a hard min, is what
	# sizes them to their slot. We deliberately do NOT pin custom_minimum_size.x to `width`: `width` is
	# derived from the raw viewport, while the cluster is anchored to the (possibly smaller) host, so a
	# hard floor would overflow when host != viewport (e.g. a Design-sized host in a bigger test window).
	# A small floor (the pill height) only guards against a degenerate 0-width collapse.
	node.custom_minimum_size = Vector2(minf(width, node.custom_minimum_size.y), node.custom_minimum_size.y)
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL

static func _painted_top_offset(node: Control) -> float:
	if node == null:
		return 0.0
	var top := INF
	for tr in node.find_children("*", "TextureRect", true, false):
		var tex := (tr as TextureRect).texture
		var img := tex.get_image() if tex != null else null
		if img == null or tex.get_width() <= 0 or tex.get_height() <= 0:
			continue
		var used := img.get_used_rect()
		if used.size.x <= 0 or used.size.y <= 0:
			continue
		var scale_y := (tr as TextureRect).size.y / float(tex.get_height())
		top = minf(top, (tr as TextureRect).position.y + float(used.position.y) * scale_y)
	return 0.0 if top == INF else top

## The X mirror of _painted_top_offset: how far the badge's first painted pixel sits from its
## own left edge, so the PAINTED edge (not the transparent bounding box) can honor the margin.
static func _painted_left_offset(node: Control) -> float:
	if node == null:
		return 0.0
	var left := INF
	for tr in node.find_children("*", "TextureRect", true, false):
		var tex := (tr as TextureRect).texture
		var img := tex.get_image() if tex != null else null
		if img == null or tex.get_width() <= 0 or tex.get_height() <= 0:
			continue
		var used := img.get_used_rect()
		if used.size.x <= 0 or used.size.y <= 0:
			continue
		var scale_x := (tr as TextureRect).size.x / float(tex.get_width())
		left = minf(left, (tr as TextureRect).position.x + float(used.position.x) * scale_x)
	return 0.0 if left == INF else left

static func build(host: Control, opts: Dictionary = {}) -> Dictionary:
	# the workbench-tuned gold pill look (padding / font / icon box / plus)
	var Kit = load(KIT_PATH)
	var cfg: Dictionary = Kit.load_config(Kit.CONFIG_PATH)
	var layout: Dictionary = Kit.hud_layout_opts_from_config(cfg)
	var view := _view_size(host)
	var edge_margin := float(layout.get("edge_margin_px", 18.0))
	var safe_top := float(opts.get("_safe_top_for_test", Look.safe_top(host)))
	var top_edge := edge_margin + safe_top
	var pill_slot_w := _screen_w_px(view, float(layout.currency_pill_w_frac))
	var pill: Dictionary = Kit.gold_currency_pill_opts_from_config(cfg)
	# the Lv badge is a little larger than the currency pill height so the star reads as player status
	# without returning to the old oversized screen-width badge.
	var lv_px := maxf(1.0, ceilf(float(pill.pill_h) * LEVEL_BADGE_SCALE))
	var num_size := int(pill.num_size)               # the workbench-tuned currency number font
	var icon_box := float(pill.icon_box)             # the workbench-tuned LAYOUT cell (centerline / min box)
	var icon_size := float(pill.get("icon_size", icon_box))   # the workbench-tuned icon SPRITE px (defaults to fill the box)
	# The wallet is THREE separate gold pills (water coin gem) centred across the TOP. The whole pill is
	# the Button and the green "+" is a decorative affordance, so the engine still de-dupes the emulated
	# touch/mouse pair without making players hit the tiny token.
	var shop_opts := opts.duplicate()
	# Each currency pill opens its OWN stall: water → water shop, coin → coin shop, gem → premium shop.
	var open_water := Callable(Shop, "open_water").bind(host, shop_opts)
	var open_coin := Callable(Shop, "open_coin").bind(host, shop_opts)
	var open_premium := Callable(Shop, "open_premium").bind(host, shop_opts)
	var cluster := HBoxContainer.new()
	cluster.anchor_left = maxf(0.0, 1.0 - float(layout.currency_area_frac))
	cluster.anchor_right = 1.0
	cluster.anchor_top = 0.0
	cluster.anchor_bottom = 0.0
	cluster.offset_top = top_edge
	cluster.offset_left = 0.0
	cluster.offset_right = -edge_margin
	cluster.add_theme_constant_override("separation", int(round(edge_margin)))
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
	var pill_body_w := maxf(1.0, pill_slot_w - edge_margin)
	for wp in [water_pill.panel, coin_pill.panel, gem_pill.panel]:
		_set_slot_width(wp as Control, pill_body_w)
	var water_lbl: Label = water_pill.label
	var coins: Label = coin_pill.label
	var gems: Label = gem_pill.label

	# The top-left cluster: Lv plus an optional HOME chip. This is intentionally separate
	# from the wallet; the level badge is player status, not currency.
	var left := HBoxContainer.new()
	left.offset_left = 0.0
	left.offset_top = top_edge
	left.custom_minimum_size = Vector2(lv_px, lv_px)
	left.size = left.custom_minimum_size
	left.add_theme_constant_override("separation", Tune.HOME_GAP)
	left.alignment = BoxContainer.ALIGNMENT_BEGIN
	left.z_index = HUD_SIDE_Z
	var place_level_row := func(top: float) -> void:
		left.offset_top = top
		left.offset_bottom = top + lv_px

	# S10: the Lv chip is part of THE module — same top-left pixels in both scenes.
	# The level number sits INSIDE the sprout avatar; the level-progress fraction sits to
	# its right at a readable size (it used to be icon + number + fraction in a
	# row, which read as "5 420/500" — one garbled value). value TICKS on change.
	var lv_panel := PanelContainer.new()
	lv_panel.custom_minimum_size = Vector2(lv_px, lv_px)
	lv_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
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
	# The HUD layout sizes the OUTER badge slot as a percentage of the screen width.
	# the level badge — the shared layered emblem + centred number (Look.make_level_badge). The HUD
	# carries the player's CURRENT level; `refresh` re-ticks the
	# number and, when leveling crosses a badge TIER (the part SET changes), rebuilds the emblem.
	var lvl0 := G.level()
	# tap the level badge -> the level screen (stars earned / needed next), when the scene wires
	# "on_level". The badge's children ignore input, so the avatar itself catches the tap.
	var on_level: Variant = opts.get("on_level")
	var build_badge := func(lvl: int) -> Control:
		# the top-left badge is the cut-paper gold STAR base with the level number in WHITE
		var av := Look.make_star_level_badge(lvl, lv_px, _lv_font_size(lvl, lv_px))
		av.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		av.set_meta("painted_top_offset", _painted_top_offset(av))
		if on_level is Callable and (on_level as Callable).is_valid():
			av.mouse_filter = Control.MOUSE_FILTER_STOP
			av.gui_input.connect(func(ev: InputEvent) -> void:
				var click: bool = (ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed) \
					or (ev is InputEventScreenTouch and not ev.pressed)
				if click:
					(on_level as Callable).call())
		return av
	var avatar: Control = build_badge.call(lvl0)
	place_level_row.call(top_edge - float(avatar.get_meta("painted_top_offset", 0.0)))
	# the badge's painted left edge honors the same edge margin the wallet uses on the right,
	# so the top band is inset symmetrically instead of the badge hugging the screen edge.
	var left_w := left.size.x
	var left_edge := edge_margin - _painted_left_offset(avatar)
	left.offset_left = left_edge
	left.offset_right = left_edge + left_w
	# the rebuildable badge bits, shared with `refresh` via a dict (closures capture it by reference)
	var badge_state := {"avatar": avatar, "level": avatar.get_node_or_null("lv_num") as Label,
		"tier": Look.level_badge_index(lvl0)}
	lrow.add_child(avatar)
	left.add_child(lv_panel)

	# A scene may opt OUT of the level badge (the board hides it — player status lives on the
	# map). Hidden, not removed: lv_panel stays in the tree (the map's panel list + the refresh
	# closure still reference it) and an invisible Control receives no taps.
	lv_panel.visible = not bool(opts.get("hide_level", false))

	# the standalone HOME chip, to the RIGHT of the Lv chip when requested.
	_build_home_chip(left, opts)
	host.add_child(left)

	# `wallet` is the centred 3-pill cluster (the container scenes raise above the shop backdrop); the
	# per-pill panels are returned too so the shop targets buy feedback + the map anchors its Store badge.
	# `water_icon` is the droplet box so the board's FTUE can hide the water icon + label together.
	var out := {"water": water_lbl, "water_icon": water_pill.icon, "coins": coins, "diamonds": gems,
		"level": badge_state["level"], "wallet": cluster, "lv_panel": lv_panel, "gear": null,
		"water_pill": water_pill.panel, "coin_pill": coin_pill.panel, "gem_pill": gem_pill.panel,
		"water_plus": water_pill.plus, "coin_plus": coin_pill.plus, "gem_plus": gem_pill.plus}
	var refresh := func() -> void:
		# water is the board's energy; the map shows the persisted value, the board overrides live via
		# _update_water_hud. coin/gem tick on change. (no star count — the level badge carries stars.)
		_set_or_tick(water_lbl, int(Save.grove().get("water", G.WATER_CAP)))
		_set_or_tick(coins, Save.coins())
		_set_or_tick(gems, Save.diamonds())
		var lvl := G.level()
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
			place_level_row.call(top_edge - float(nb.get_meta("painted_top_offset", 0.0)))
			out["level"] = badge_state["level"]
		var lnum: Label = badge_state["level"]
		if lnum != null:
			_set_or_tick(lnum, lvl)
			lnum.add_theme_font_size_override("font_size", _lv_font_size(lvl, lv_px))   # keep the number inside as digits grow
		# host hook: a scene that keeps live state derived from Save (the board's water cache + its
		# empty-water refill stack) re-syncs here, so a shop grant lands without per-currency callbacks.
		var host_refresh: Variant = opts.get("on_refresh")
		if host_refresh is Callable and (host_refresh as Callable).is_valid():
			(host_refresh as Callable).call()
	out["refresh"] = refresh
	# `shop_opts` was duplicated up top (so the currency pills share the SAME options);
	# wire `refresh` into it now — the closure captured the dict by reference, so both the
	# pills and the bottom-bar store tick the wallet after a purchase.
	shop_opts["refresh"] = refresh
	# The shop drops its own (redundant) currency strip and reuses THIS bar as the wallet: pass each
	# pill + label so buy feedback (fly-home / tick / "need more" wobble) targets the right capsule, and
	# the top-bar panels so the shop can RAISE them crisp above its blurred backdrop. The shop only raises
	# DIRECT children of host, so we pass the CLUSTER (the pills' parent) — raising it lifts all 3 pills.
	var raise_panels: Array = [cluster, lv_panel]
	shop_opts["wallet"] = {
		"water": {"node": water_pill.panel, "label": water_lbl},
		"coin": {"node": coin_pill.panel, "label": coins},
		"gem": {"node": gem_pill.panel, "label": gems},
		"panels": raise_panels,
	}
	# The per-stall openers (the pills share these); `open_shop` stays as the generic "open the
	# shop" handle, pointed at the premium (acorn) stall, for callers that don't care which stall.
	out["open_water"] = open_water
	out["open_coin"] = open_coin
	out["open_premium"] = open_premium
	out["open_shop"] = open_premium
	refresh.call()
	return out

# One currency pill: the drawn Kit.gold_currency_pill — a code-rendered cream capsule wearing the SHARED
# cut-paper rugged edge, with the currency icon + number + green "+" as live child nodes. The whole pill
# opens the store. Added to `cluster`; returns {panel, label, icon, plus}. (The tint / optical / icon-box
# args are legacy no-ops kept so the call sites don't churn — the drawn pill resolves each currency by id.)
static func _pill(cluster: HBoxContainer, Kit: Variant, pill: Dictionary, icon_id: String, gsize: int,
		optical: float, tint: Color, num_size: int, box: float, open_store: Callable, init_count: int = 0) -> Dictionary:
	# born showing the CURRENT value, not 0 — so build()'s first refresh sets silently instead of
	# count-ticking up from 0 every time a page rebuilds the HUD.
	var pill_opts := pill.duplicate()
	pill_opts["icon"] = icon_id
	pill_opts["plus_action"] = open_store
	pill_opts["shadow"] = false   # the cut-paper edge casts its OWN shape-true shadow — no rect wrapper
	var panel := Kit.gold_currency_pill(pill_opts, {icon_id: init_count}) as Button
	# Unique per-currency name that still begins with "GoldCurrencyPill" (three same-named siblings in the
	# cluster would otherwise auto-rename to "@Button@N", breaking the _ancestor_named("GoldCurrencyPill") contract).
	panel.name = "GoldCurrencyPill" + icon_id.capitalize()
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var lbl := panel.find_child("GoldCurrencyAmount", true, false) as Label
	var icon := panel.find_child("GoldCurrencyIcon", true, false) as Control
	var plus := panel.find_child("GoldCurrencyPlusButton", true, false) as Control
	cluster.add_child(panel)
	return {"panel": panel, "label": lbl, "icon": icon, "plus": plus}

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
	Look.apply_box_shadow(sb)
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

# Numbers TICK when they change (spec §7) and set silently when they don't. Wallet labels carry
# their prior value as metadata (their visible text may be an abbreviation like "12.3K", so it
# can't be read back as an int); FX handles the K/M formatting + fit-to-cell for those.
static func _set_or_tick(lbl: Label, v: int) -> void:
	var prev := int(lbl.get_meta("amount_value")) if lbl.has_meta("amount_value") \
		else (int(lbl.text) if lbl.text.is_valid_int() else -1)
	lbl.set_meta("amount_value", v)
	if prev >= 0 and prev != v and lbl.is_inside_tree():
		FX.tick(lbl, v)
	elif lbl.has_meta("amount_max_w"):
		lbl.text = FX.format_amount(v)
		FX.fit_amount(lbl)
	else:
		lbl.text = str(v)

static func _lv_font_size(level: int, px: float) -> int:
	# Scaled to the HUD badge art so digits stay centred in the medal's open centre as it grows.
	# The per-digit-count sizes were tuned on a 216 px badge (the old 20%-of-1080 slot); they now
	# scale with the actual slot so the digits track the pill-height-matched badge.
	var base := 92.0
	if level >= 100:
		base = 57.0
	elif level >= 10:
		base = 72.0
	return maxi(8, roundi(base * px / 216.0))
