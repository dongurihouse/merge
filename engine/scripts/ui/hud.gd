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
	row.add_theme_constant_override("separation", Tune.ROW_SEP)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(row)
	# A persistent HOME shortcut — jump to the hub map from anywhere. It rides the
	# LEFT of the currency cluster (same pinned pill, so it reads as chrome, not a
	# transient CTA). Rendered only when a scene passes a valid `home` Callable in the
	# config (the board + map both do); harmless and absent otherwise.
	var home_btn: Button = null
	var home_cb: Variant = opts.get("home")
	if home_cb is Callable and (home_cb as Callable).is_valid():
		home_btn = Button.new()
		home_btn.flat = true
		home_btn.focus_mode = Control.FOCUS_NONE
		home_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var hg := Look.icon("home", Tune.STAR_ICON)   # kit sprite when present, else the "◀"/glyph Label
		hg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		home_btn.add_child(hg)
		home_btn.custom_minimum_size = Vector2(Tune.STAR_ICON + 8.0, Tune.STAR_ICON + 8.0)
		Look.add_press_juice(home_btn)
		home_btn.pressed.connect(func() -> void: (home_cb as Callable).call())
		row.add_child(home_btn)
	# the cluster is currencies ONLY — the Store moved to the bottom bar
	# (owner 2026-06-13); scenes open it via out.open_shop.
	var stars := _pair(row, "star", Tune.STAR_ICON)
	var coins := _pair(row, "coin", Tune.COIN_ICON)
	var gems := _pair(row, "gem", Tune.GEM_ICON)
	host.add_child(panel)

	# S10: the Lv chip is part of THE module — same pixels in both scenes.
	# The level number sits INSIDE the sprout avatar; the exp fraction sits to
	# its right at a readable size (it used to be icon + number + fraction in a
	# row, which read as "5 420/500" — one garbled value). value TICKS on change.
	var lv_panel := PanelContainer.new()
	lv_panel.offset_left = Tune.EDGE_MARGIN
	lv_panel.offset_top = Tune.EDGE_MARGIN + Look.safe_top(host)
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
	var xp := Label.new()
	xp.add_theme_font_size_override("font_size", Tune.XP_SIZE)   # readable (was 20), to the RIGHT of the avatar
	xp.add_theme_color_override("font_color", Color(INK, Tune.XP_INK_ALPHA))
	xp.add_theme_constant_override("outline_size", 0)
	xp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lrow.add_child(xp)
	host.add_child(lv_panel)

	var out := {"stars": stars, "coins": coins, "diamonds": gems, "level": level, "xp": xp,
		"wallet": panel, "lv_panel": lv_panel, "home": home_btn}
	var refresh := func() -> void:
		_set_or_tick(stars, Save.stars())
		_set_or_tick(coins, Save.coins())
		_set_or_tick(gems, Save.diamonds())
		var earned := int(Save.grove().get("stars_earned", 0))
		var lvl := G.level_for_stars(earned)
		_set_or_tick(level, lvl)
		xp.text = "%d/%d" % [earned, G.stars_at_level(lvl + 1)]   # uncapped — always a next level
	out["refresh"] = refresh
	var shop_opts := opts.duplicate()
	shop_opts["refresh"] = refresh
	out["open_shop"] = func() -> void: Shop.open(host, shop_opts)
	refresh.call()
	return out

static func _pair(row: HBoxContainer, icon_id: String, gsize: int) -> Label:
	var ic := Look.icon(icon_id, float(gsize))
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER   # vertically center the icon with its number
	row.add_child(ic)
	var lbl := Label.new()
	lbl.add_theme_font_size_override("font_size", Tune.NUM_SIZE)
	lbl.add_theme_color_override("font_color", INK)   # AC4: dark text on the cream pill
	lbl.add_theme_constant_override("outline_size", 0)   # AF6: no dark halo on a solid pill (panel-text law)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(lbl)
	return lbl

# Numbers TICK when they change (spec §7) and set silently when they don't.
static func _set_or_tick(lbl: Label, v: int) -> void:
	if lbl.text.is_valid_int() and int(lbl.text) != v and lbl.is_inside_tree():
		FX.tick(lbl, v)
	else:
		lbl.text = str(v)
