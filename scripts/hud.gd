extends RefCounted
## Tidy Up — THE top bar (owner: a standalone module reused in every scene).
## The currency cluster (★ 🪙 💎) and the Store button are pinned to the same
## pixels on every screen; scenes keep their refs and refresh the labels.
## Usage:  var hud := Hud.build(self, {"water_grant": Callable})
##         hud.stars.text = ...   (or call hud.refresh.call())

const Save = preload("res://scripts/save.gd")
const Look = preload("res://scripts/skin.gd")
const Shop = preload("res://scripts/shop.gd")
const FX = preload("res://scripts/fx.gd")
const G = preload("res://scripts/grove_content.gd")

const INK := Color("#33402F")
const CREAM := Color("#FBF3EA")
const STRAW := Color("#E3B23C")

static func build(host: Control, opts: Dictionary = {}) -> Dictionary:
	var panel := PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_right = -16.0
	panel.offset_top = 16.0 + Look.safe_top(host)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	# R1: the plank must visibly WRAP the whole cluster with EVEN padding.
	# panel_chip.png is a 512² nine-patch whose opaque art is an asymmetric pill
	# thinner than the layout rect — on this short strip even layout padding read
	# as lopsided and the tall icons spilled past the opaque band. A clean
	# wood-tone pill makes layout padding == visual padding (so the rect asserts
	# below match what the eye sees), and fully contains the row.
	var chip_sb := StyleBoxFlat.new()
	chip_sb.bg_color = Color("#FBF6EC", 0.95)   # AC4: soft cream pill (was dark wood)
	chip_sb.set_corner_radius_all(40)
	chip_sb.set_border_width_all(3)
	chip_sb.border_color = Color("#C9A66B", 0.9)   # warm border (matches the AB ask pills)
	chip_sb.shadow_color = Color(0, 0, 0, 0.22)
	chip_sb.shadow_size = 5
	chip_sb.content_margin_left = 18.0
	chip_sb.content_margin_right = 18.0
	chip_sb.content_margin_top = 12.0
	chip_sb.content_margin_bottom = 12.0
	panel.add_theme_stylebox_override("panel", chip_sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(row)
	# the cluster is currencies ONLY — the Store moved to the bottom bar
	# (owner 2026-06-13); scenes open it via out.open_shop.
	var stars := _pair(row, "star", 44)
	var coins := _pair(row, "coin", 40)
	var gems := _pair(row, "gem", 38)
	host.add_child(panel)

	# S10: the Lv chip is part of THE module — same pixels in both scenes.
	# The level number sits INSIDE the sprout avatar; the exp fraction sits to
	# its right at a readable size (it used to be icon + number + fraction in a
	# row, which read as "5 420/500" — one garbled value). value TICKS on change.
	var lv_panel := PanelContainer.new()
	lv_panel.offset_left = 16.0
	lv_panel.offset_top = 16.0 + Look.safe_top(host)
	var lv_sb := StyleBoxFlat.new()
	lv_sb.bg_color = Color("#FBF6EC", 0.95)   # AC4: soft cream pill
	lv_sb.set_corner_radius_all(40)
	lv_sb.set_border_width_all(3)
	lv_sb.border_color = Color("#C9A66B", 0.9)   # warm border
	lv_sb.shadow_color = Color(0, 0, 0, 0.22)
	lv_sb.shadow_size = 5
	lv_sb.content_margin_left = 16.0
	lv_sb.content_margin_right = 16.0
	lv_sb.content_margin_top = 12.0
	lv_sb.content_margin_bottom = 12.0
	lv_panel.add_theme_stylebox_override("panel", lv_sb)
	var lrow := HBoxContainer.new()
	lrow.add_theme_constant_override("separation", 7)
	lrow.alignment = BoxContainer.ALIGNMENT_CENTER
	lv_panel.add_child(lrow)
	# the level "coin" — a Panel so it can draw the round token stylebox below.
	var lv_px := 48.0
	var avatar := Panel.new()
	avatar.custom_minimum_size = Vector2(lv_px, lv_px)
	avatar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# a clean level "coin" — deep-leaf token + warm gold ring + cream number. The
	# busy sprout badge couldn't hold a readable number AND look good; this reads
	# crisply and matches the HUD's cream/gold language. (Swap to a sprout badge
	# later only if one is generated with an OPEN center.)
	var coin := StyleBoxFlat.new()
	coin.bg_color = Color("#3F6B43")            # deep leaf — growth, and contrasts the cream pill
	coin.set_corner_radius_all(int(lv_px / 2.0))
	coin.set_border_width_all(3)
	coin.border_color = Color("#C9A66B")        # warm gold ring (matches the pill border)
	avatar.add_theme_stylebox_override("panel", coin)
	var level := Label.new()
	level.add_theme_font_size_override("font_size", 26)
	level.add_theme_color_override("font_color", CREAM)
	level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	level.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level.set_anchors_preset(Control.PRESET_FULL_RECT)
	avatar.add_child(level)
	lrow.add_child(avatar)
	var xp := Label.new()
	xp.add_theme_font_size_override("font_size", 28)   # readable (was 20), to the RIGHT of the avatar
	xp.add_theme_color_override("font_color", Color(INK, 0.85))
	xp.add_theme_constant_override("outline_size", 0)
	xp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lrow.add_child(xp)
	host.add_child(lv_panel)

	var out := {"stars": stars, "coins": coins, "diamonds": gems, "level": level, "xp": xp,
		"wallet": panel, "lv_panel": lv_panel}
	var refresh := func() -> void:
		_set_or_tick(stars, Save.stars())
		_set_or_tick(coins, Save.coins())
		_set_or_tick(gems, Save.diamonds())
		var xpts := int(Save.grove().get("exp", 0))
		var lvl := G.level_for_exp(xpts)
		_set_or_tick(level, lvl)
		xp.text = ("%d/%d" % [xpts, G.LEVEL_XP[lvl]]) if lvl < G.LEVEL_XP.size() else "max"
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
	lbl.add_theme_font_size_override("font_size", 34)
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
