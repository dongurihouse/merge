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

static func build(host: Control, opts: Dictionary = {}) -> Dictionary:
	var panel := PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_right = -Tune.EDGE_MARGIN
	panel.offset_top = Tune.EDGE_MARGIN + Look.safe_top(host)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	# R1: the plank must visibly WRAP the whole cluster with EVEN padding.
	# panel_chip.png is a 512² nine-patch whose opaque art is an asymmetric pill
	# thinner than the layout rect — on this short strip even layout padding read
	# as lopsided and the tall icons spilled past the opaque band. A clean
	# wood-tone pill makes layout padding == visual padding (so the rect asserts
	# below match what the eye sees), and fully contains the row.
	var chip_sb := StyleBoxFlat.new()
	chip_sb.bg_color = Tune.PILL_BG             # AC4: soft cream pill (was dark wood)
	chip_sb.set_corner_radius_all(Tune.PILL_RADIUS)
	chip_sb.set_border_width_all(Tune.PILL_BORDER_W)
	chip_sb.border_color = Tune.PILL_BORDER     # warm border (matches the AB ask pills)
	chip_sb.shadow_color = Tune.PILL_SHADOW
	chip_sb.shadow_size = Tune.PILL_SHADOW_SIZE
	chip_sb.content_margin_left = Tune.CLUSTER_PAD_X
	chip_sb.content_margin_right = Tune.CLUSTER_PAD_X
	chip_sb.content_margin_top = Tune.PILL_PAD_Y
	chip_sb.content_margin_bottom = Tune.PILL_PAD_Y
	panel.add_theme_stylebox_override("panel", chip_sb)
	var row := HBoxContainer.new()
	# The row's uniform separation IS the tight icon↔number gap; the WIDER gap BETWEEN
	# currencies comes from explicit spacer Controls (so every pair shares one centerline
	# and the numbers align). Keeping every icon/number/+ a DIRECT child of `row` is also a
	# contract: scenes resolve the wallet panel as stars_label.get_parent().get_parent().
	row.add_theme_constant_override("separation", Tune.CHIP_ROW_SEP)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(row)
	# the cluster is currencies ONLY now — the Store moved to the bottom bar (owner
	# 2026-06-13) and HOME was pulled OUT into its own top-left chip (nav ≠ wallet). The +
	# acquire buttons route to the SAME store the bottom-bar button opens (built as
	# out["open_shop"] below — shares this closure so the refresh tick is wired once).
	var shop_opts := opts.duplicate()
	var open_store := func() -> void: Shop.open(host, shop_opts)
	var stars := _pair(row, "star", Tune.STAR_ICON, Tune.STAR_OPTICAL, Tune.STAR_TINT, false, open_store)
	_spacer(row)
	var coins := _pair(row, "coin", Tune.COIN_ICON, Tune.COIN_OPTICAL, Tune.COIN_TINT, true, open_store)
	_spacer(row)
	# the GEM always gets a + (the key monetization affordance — the path from "I want
	# more gems" to the store, which the wallet was missing entirely).
	var gems := _pair(row, "gem", Tune.GEM_ICON, Tune.GEM_OPTICAL, Tune.GEM_TINT, true, open_store)
	host.add_child(panel)

	# The top-LEFT cluster: the Lv chip + (when a scene passes `home`) a SEPARATE Home chip,
	# laid out in a shared pinned row so they flow side by side and never overlap. HOME used
	# to live INSIDE the wallet pill (nav mixed into the currency cluster); it now has its own
	# pill here so nav reads as chrome, distinct from the wallet.
	var left := HBoxContainer.new()
	left.offset_left = Tune.EDGE_MARGIN
	left.offset_top = Tune.EDGE_MARGIN + Look.safe_top(host)
	left.add_theme_constant_override("separation", Tune.HOME_GAP)
	left.alignment = BoxContainer.ALIGNMENT_BEGIN

	# S10: the Lv chip is part of THE module — same pixels in both scenes.
	# The level number sits INSIDE the sprout avatar; the level-progress fraction sits to
	# its right at a readable size (it used to be icon + number + fraction in a
	# row, which read as "5 420/500" — one garbled value). value TICKS on change.
	var lv_panel := PanelContainer.new()
	lv_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var lv_sb := StyleBoxFlat.new()
	lv_sb.bg_color = Tune.PILL_BG               # AC4: soft cream pill
	lv_sb.set_corner_radius_all(Tune.PILL_RADIUS)
	lv_sb.set_border_width_all(Tune.PILL_BORDER_W)
	lv_sb.border_color = Tune.PILL_BORDER       # warm border
	lv_sb.shadow_color = Tune.PILL_SHADOW
	lv_sb.shadow_size = Tune.PILL_SHADOW_SIZE
	lv_sb.content_margin_left = Tune.PILL_PAD_X
	lv_sb.content_margin_right = Tune.PILL_PAD_X
	lv_sb.content_margin_top = Tune.PILL_PAD_Y
	lv_sb.content_margin_bottom = Tune.PILL_PAD_Y
	lv_panel.add_theme_stylebox_override("panel", lv_sb)
	var lrow := HBoxContainer.new()
	lrow.add_theme_constant_override("separation", Tune.LV_ROW_SEP)
	lrow.alignment = BoxContainer.ALIGNMENT_CENTER
	lv_panel.add_child(lrow)
	# the level "coin" — a Panel so it can draw the round token stylebox below.
	var lv_px := Tune.LV_PX
	var avatar := Panel.new()
	avatar.custom_minimum_size = Vector2(lv_px, lv_px)
	avatar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# a clean level "coin" — deep-leaf token + warm gold ring + cream number. The
	# busy sprout badge couldn't hold a readable number AND look good; this reads
	# crisply and matches the HUD's cream/gold language. (Swap to a sprout badge
	# later only if one is generated with an OPEN center.)
	var coin := StyleBoxFlat.new()
	coin.bg_color = Tune.LV_TOKEN_BG            # deep leaf — growth, and contrasts the cream pill
	coin.set_corner_radius_all(int(lv_px / 2.0))
	coin.set_border_width_all(Tune.PILL_BORDER_W)
	coin.border_color = Tune.LV_TOKEN_BORDER    # warm gold ring (matches the pill border)
	avatar.add_theme_stylebox_override("panel", coin)
	var level := Label.new()
	level.add_theme_font_size_override("font_size", Tune.LV_NUM_SIZE)
	level.add_theme_color_override("font_color", CREAM)
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
	lrow.add_child(level_prog)
	left.add_child(lv_panel)

	# the standalone HOME chip, to the RIGHT of the Lv chip in the shared left row.
	var home_btn := _build_home_chip(left, opts)
	host.add_child(left)

	var out := {"stars": stars, "coins": coins, "diamonds": gems, "level": level, "level_prog": level_prog,
		"wallet": panel, "lv_panel": lv_panel, "home": home_btn}
	# §8 keystone: scenes toggle the home-shortcut yield-ready pip via this. A no-op when the
	# home button (and thus the pip) isn't rendered (e.g. a scene that passes no `home`).
	out["home_cue"] = func(on: bool) -> void:
		if home_btn == null or not is_instance_valid(home_btn):
			return
		var pip := home_btn.get_node_or_null("YieldPip")
		if pip != null:
			(pip as Control).visible = on
	var refresh := func() -> void:
		_set_or_tick(stars, Save.stars())
		_set_or_tick(coins, Save.coins())
		_set_or_tick(gems, Save.diamonds())
		var earned := int(Save.grove().get("stars_earned", 0))
		var lvl := G.level_for_stars(earned)
		_set_or_tick(level, lvl)
		level_prog.text = "%d/%d" % [earned, G.stars_at_level(lvl + 1)]   # uncapped — always a next level
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
# the inner button (null when no `home` callback) so home_cue can toggle the yield pip.
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
	# §8 keystone: a subtle yield-READY cue — a small gold pip on the chip corner when the hub
	# has uncollected coin yield. Built hidden; scenes toggle it via out.home_cue(on). Pure
	# chrome (IGNORE), never eats a press.
	var pip := Panel.new()
	pip.name = "YieldPip"
	var pip_d := 14.0
	pip.custom_minimum_size = Vector2(pip_d, pip_d)
	pip.size = Vector2(pip_d, pip_d)
	var pip_sb := StyleBoxFlat.new()
	pip_sb.bg_color = Color("#E3B23C")               # warm gold — the coin/yield colour
	pip_sb.set_corner_radius_all(int(pip_d / 2.0))
	pip_sb.set_border_width_all(2)
	pip_sb.border_color = CREAM
	pip.add_theme_stylebox_override("panel", pip_sb)
	pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pip.position = Vector2(home_btn.custom_minimum_size.x - pip_d + 2.0, -2.0)
	pip.visible = false
	home_btn.add_child(pip)
	left.add_child(pill)
	return home_btn

# Numbers TICK when they change (spec §7) and set silently when they don't.
static func _set_or_tick(lbl: Label, v: int) -> void:
	if lbl.text.is_valid_int() and int(lbl.text) != v and lbl.is_inside_tree():
		FX.tick(lbl, v)
	else:
		lbl.text = str(v)
