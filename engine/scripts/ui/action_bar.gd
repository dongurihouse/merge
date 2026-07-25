extends RefCounted
## The board's BOTTOM ACTION BAR — the shared, stateless visual builders (owner: a standalone module
## reused by the board scene). The centre tray's styled surface, the offset slot, the round nav/Home/Bag
## wells, and the green action-chip recipe (burst / buy) all live here so the board scene keeps only the
## ORCHESTRATION (which wells, in what order, wired to which handlers + state).
## The bar reads as THREE free-standing pieces: the Home tile, the cream info tray, the Bag tile. Only the
## centre tray is painted here — the Home/Bag tiles carry their own paper surface (Kit.home_button).
## Usage:  row.add_child(ActionBar.offset_slot(info_bar, x_frac, "ActionBarInfoOffset"))
##         var chip := ActionBar.action_chip(opts, row, caption, on_press)   # → {btn, sb, count, coin}
## Every builder is a pure static func: params in, a node (or value) out — no board state is read or
## written here, so the board owns selection/refresh and passes press handlers in as Callables.
## Look/feel values come from the shared UI-workbench kit (loaded by path, matching hud.gd/nav_bar) +
## the engine skin (Look) + palette (Pal).

const Look = preload("res://engine/scripts/ui/skin.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const Tuning = preload("res://engine/scripts/core/tuning.gd")
const FS = preload("res://engine/scripts/core/tuning.gd").FontScale
const Pal = Game.PALETTE
# The gold-pill / action-bar look is tuned in the UI Workbench and saved to the shared kit config.
# Loaded at runtime (matches hud.gd / nav_bar) to avoid a preload cycle (engine → game-tool bridge).
const KIT_PATH := "res://games/grove/ui_kit.gd"

const BOTTOM_BAR_H := 166.0                             # fallback bar height (the bar_style default)
const WELL_GAP_FRAC := 0.14                             # gap between the Home/Bag tiles and the centre tray
const PAPER_SURFACE_NODE := "ActionBarPaperSurface"
const DECKLE_SURFACE_NODE := "ActionBarInfoDeckleSurface"
const PAPER_TEXTURE := "texture_cream.png"
const PAPER_FILL := Color("#F6EBDD")
const PAPER_EDGE := Color("#FFF9EC")
const PAPER_CORNER_FRAC := 0.18

# The workbench-tuned action-bar opts ({} when the kit can't load — every reader falls back to a const).
static func opts() -> Dictionary:
	var Kit: GDScript = load(KIT_PATH)
	if Kit == null:
		return {}
	return Kit.action_bar_opts_from_config(Kit.load_config(Kit.CONFIG_PATH))

# The CENTRE info tray's cream surface. Shape, light edge, and shadow are code-drawn here;
# apply_paper_surface adds only a flat cream grain inside that shape. The Home and Bag tiles sit OUTSIDE
# this box (their own paper tiles), so the tray spans only the middle of the bottom row.
static func bar_style(bar_h: float = BOTTOM_BAR_H, action_opts: Dictionary = {}) -> StyleBox:
	var flat := StyleBoxFlat.new()
	flat.bg_color = PAPER_FILL
	flat.border_color = PAPER_EDGE
	flat.set_border_width_all(2)
	flat.set_corner_radius_all(_bar_corner(bar_h))
	flat.anti_aliasing = true
	if bool(action_opts.get("shadow", true)):
		Look.apply_box_shadow(flat)
	# The paper child is laid into this fixed inset so the light code edge remains visible.
	flat.content_margin_left = 2.0
	flat.content_margin_right = 2.0
	flat.content_margin_top = 2.0
	flat.content_margin_bottom = 2.0
	return flat

static func _bar_corner(bar_h: float) -> int:
	return maxi(12, int(roundf(bar_h * PAPER_CORNER_FRAC)))


static func _transparent_tray_style() -> StyleBox:
	var flat := StyleBoxFlat.new()
	flat.bg_color = Color(0, 0, 0, 0)
	flat.draw_center = false
	flat.content_margin_left = 2.0
	flat.content_margin_right = 2.0
	flat.content_margin_top = 2.0
	flat.content_margin_bottom = 2.0
	return flat

static func _apply_info_deckle_surface(tray: Control, bar_h: float, action_opts: Dictionary = {}) -> Control:
	var Kit: GDScript = load(KIT_PATH)
	if Kit == null or tray == null:
		return null
	var surface := tray.find_child(DECKLE_SURFACE_NODE, false, false) as Control
	if surface == null:
		surface = load(Kit.CUT_PAPER).new()
		surface.name = DECKLE_SURFACE_NODE
		surface.show_behind_parent = true
		surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
		surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tray.add_child(surface)
	var cp: Dictionary = Kit.cut_paper_opts_from_config(Kit.load_config(Kit.CONFIG_PATH), "action_button", Kit.ACTION_BUTTON_CP_DEFAULTS)
	var corner := float(_bar_corner(bar_h))
	cp["corner"] = corner
	surface.configure(cp, PAPER_FILL, PAPER_EDGE, Kit.cut_paper_tile())
	surface.corner = corner
	tray.set_meta(Look.SHADOW_CORNER_META, corner)
	return surface

# The paper always gets the shell's fixed 2px inset; optional Workbench padding belongs only to content.
#
# The tray's height is a SCREEN-DERIVED BUDGET (board.gd:_bottom_bar_h_px), not a suggestion — but Godot
# has no maximum size. A Control's rect is max(anchors, combined_minimum_size), and minimums propagate up
# from every child, so a child taller than the budget pushes the anchored tray past it; with the tray's
# grow_vertical = GROW_DIRECTION_BEGIN the excess grows UPWARD, across the board. An autowrap Label is
# exactly such a child: it reports a minimum HEIGHT computed for its CURRENT width, so mid-relayout —
# while the info bar is momentarily ~1px wide — the empty-state prompts each reported ~1000px and the
# tray covered the whole screen (the reported bug).
#
# So the outer host is a PLAIN CONTROL: it reports a zero minimum whatever its children claim, severing
# that propagation, and the tray's height comes from its anchors alone. The padding MarginContainer lives
# inside it, anchored to fill (a plain Control does not lay its children out).
#
# The trade: the tray no longer auto-grows for genuinely taller content — such content would overflow
# rather than shove the tray. That is deliberate for a fixed-height tray, and board_hud_layout_tests
# asserts the row's own minimum still fits the budget so a config bump fails loudly instead of shipping
# as overflow. (Deliberately NOT clip_contents: the free-standing Home/Bag tiles cast shadows past the
# tray bounds, and clipping here would cut them.)
static func content_host(child: Control, bar_h: float, action_opts: Dictionary = {}, node_name: String = "ActionBarContent") -> Control:
	var clamp_host := Control.new()
	clamp_host.name = node_name
	clamp_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clamp_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	clamp_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var host := MarginContainer.new()
	host.name = node_name + "Pad"
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pad_x := maxi(0, int(roundf(bar_h * float(action_opts.get("pad_x_frac", 0.0)))) - 2)
	var pad_y := maxi(0, int(roundf(bar_h * float(action_opts.get("pad_y_frac", 0.0)))) - 2)
	host.add_theme_constant_override("margin_left", pad_x)
	host.add_theme_constant_override("margin_right", pad_x)
	host.add_theme_constant_override("margin_top", pad_y)
	host.add_theme_constant_override("margin_bottom", pad_y)
	host.add_child(child)
	clamp_host.add_child(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return clamp_host

# Wrap a bar child in a MarginContainer offset horizontally by `x_frac` of its own min width — lets the
# info bar nudge off-centre without disturbing the row's distribution. A ~0 frac passes the child through.
static func offset_slot(child: Control, x_frac: float, node_name: String) -> Control:
	if child == null:
		return Control.new()
	if absf(x_frac) < 0.001:
		return child
	var slot := MarginContainer.new()
	slot.name = node_name
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.custom_minimum_size = child.custom_minimum_size
	slot.size_flags_horizontal = child.size_flags_horizontal
	slot.size_flags_vertical = child.size_flags_vertical
	var basis := maxf(1.0, child.custom_minimum_size.x)
	var x_px := int(roundf(basis * x_frac))
	slot.add_theme_constant_override("margin_left", x_px)
	slot.add_theme_constant_override("margin_right", -x_px)
	child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot.add_child(child)
	return slot

# The breathing room between each outer tile and the centre tray (the old painted dividers are retired —
# the three pieces are separated by open space now).
static func well_gap(px: float) -> int:
	return maxi(12, int(roundf(px * WELL_GAP_FRAC)))

static func clear_button_frame(b: Button) -> void:
	var empty := StyleBoxEmpty.new()
	for st_name in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st_name, empty)

static func info_bar_frame(info_opts: Dictionary) -> StyleBoxEmpty:
	var empty := StyleBoxEmpty.new()
	var pad: Dictionary = info_opts.get("pill", {})
	var pad_x := float(pad.get("pad_x", 18.0))
	empty.content_margin_left = float(pad.get("pad_left", pad_x))
	empty.content_margin_right = float(info_opts.get("pad_right", 16.0))
	var vpad := float(info_opts.get("vpad", 8.0))
	empty.content_margin_top = vpad
	empty.content_margin_bottom = vpad
	return empty

# The painted cream tray that now holds ONLY the info bar — the Home and Bag tiles stand outside it, so the
# tray spans just the centre of the bottom row. It wears the same shape/edge/shadow/paper the full-width bar
# used to, and the info pill keeps its own transparent padding frame inside.
static func info_tray(info_bar: Control, bar_h: float, action_opts: Dictionary = {}) -> PanelContainer:
	var tray := PanelContainer.new()
	tray.name = "ActionBarInfoTray"
	tray.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tray.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tray.custom_minimum_size = Vector2(1.0, bar_h)
	tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tray.add_theme_stylebox_override("panel", _transparent_tray_style())
	_apply_info_deckle_surface(tray, bar_h, action_opts)
	tray.add_child(info_bar)
	return tray

# The per-cell empty well's stylebox: the kit tile-slot sprite as a nine-patch, falling back to a code
# well. Used as the round tray-well's painted fallback when its `nav/<art>` sprite is absent.
static func _slot_style() -> StyleBox:
	var p := Look.kit("board/slot_tile.png")
	if ResourceLoader.exists(p):
		var sbt := StyleBoxTexture.new()
		sbt.texture = load(p)
		sbt.set_texture_margin_all(28.0)   # ~180px source corners → crisp at cell size
		return sbt
	return _cell_style()

# The code-drawn empty-cell well — mirrors Board._cell_style (kept on the board script for grove_shop_tests).
# Only the slot-tile-absent fallback above reaches it (the shipped kit always ships board/slot_tile.png).
static func _cell_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Pal.CELL_EMPTY
	sb.set_corner_radius_all(Tuning.UiSkin.RADIUS_CARD)
	sb.set_border_width_all(Tuning.UiSkin.INSET_LINE_W)
	sb.border_color = Tuning.UiSkin.INSET_LINE
	sb.shadow_color = Tuning.UiSkin.SHADOW_SUNK
	sb.shadow_size = Tuning.UiSkin.SHADOW_SUNK_SIZE
	sb.shadow_offset = Tuning.UiSkin.SHADOW_SUNK_OFFSET
	return sb

# A round painted button for the bottom nav: hosts the round wood `nav/<art>` sprite (matching board.png),
# with the stash/sell preview riding on top. Falls back to the slot-tile well when the sprite is absent.
static func tray_well(px: float, art: String = "") -> Button:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(px, px)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var p := Look.kit("nav/" + art) if art != "" else ""
	if art != "" and ResourceLoader.exists(p):
		var t := TextureRect.new()
		t.texture = load(p)
		t.set_anchors_preset(Control.PRESET_FULL_RECT)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(t)
	else:
		var bg := Panel.new()
		bg.add_theme_stylebox_override("panel", _slot_style())
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(bg)
	Look.add_press_juice(b)
	return b

# The Bag/Home well, built on the SHARED home-button shell (cream/gold disc + lifted icon) so it matches
# the rest of the bar; the stash/sell preview overlays still ride on top and the drop is resolved by
# global-rect, so a disc is as good a target as the old wood well. Soft-loads the kit by path; falls back
# to the wood tray_well if the kit can't load.
static func home_well(px: float, icon_id: String, fallback_art: String, count: String = "", icon_scale: float = -1.0, action_opts: Dictionary = {}) -> Button:
	var Kit: GDScript = load(KIT_PATH)
	if Kit == null:
		return tray_well(px, fallback_art)
	var home_opts: Dictionary = Kit.home_button_opts_from_config(Kit.load_config(Kit.CONFIG_PATH))
	home_opts["px"] = px
	home_opts["shape"] = "rect"               # the board's Home + Bag wells are code-drawn rounded paper tiles
	home_opts["surface_role"] = "purple" if icon_id == "bag" else "green"
	home_opts["shadow"] = true                # each paper tile keeps the mock's compact directional cast
	if not action_opts.is_empty():
		home_opts["icon_scale"] = float(action_opts.get("icon_scale", home_opts.get("icon_scale", 0.5)))
	if icon_scale > 0.0:
		home_opts["icon_scale"] = icon_scale
	# `count` (the Bag's "x/y") rides INSIDE the disc via the shared component's workbench-tuned overlay.
	return Kit.home_button({"icon": icon_id, "caption": "", "sparkle": false, "count": count}, home_opts)

# An info-bar ACTION chip — a caption over a green badge holding a currency icon + a number — MIRRORING
# the kit sell button's recipe so every action in the bar reads one button language. Shared by the burst
# chip and the buy chip; returns the mutable nodes the caller drives (caption set here, the coin glyph +
# number filled per-selection). The chip starts hidden and is added to `row`.
static func action_chip(chip_opts: Dictionary, row: Control, caption_text: String, on_press: Callable, content_align: int = BoxContainer.ALIGNMENT_CENTER) -> Dictionary:
	var height := float(chip_opts.get("height", 130.0))
	var icon_px := height * float(chip_opts.get("sell_icon", 0.30))
	var label_font := int(chip_opts.get("sell_label_font", FS.FINE))
	var num_font := int(chip_opts.get("sell_font", FS.HEADING))
	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 3)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var caption := Label.new()                       # the caption above the badge (ink on the bar)
	caption.text = caption_text
	caption.add_theme_font_size_override("font_size", label_font)
	caption.add_theme_color_override("font_color", Pal.INK)
	caption.add_theme_constant_override("outline_size", 0)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(caption)
	var badge_col := VBoxContainer.new()             # the green badge body: currency on top, number below
	badge_col.alignment = BoxContainer.ALIGNMENT_CENTER
	badge_col.add_theme_constant_override("separation", 1)
	badge_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var coin := CenterContainer.new()                # the currency glyph (filled per-selection)
	coin.custom_minimum_size = Vector2(icon_px, icon_px)
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_col.add_child(coin)
	var count := Label.new()                         # the COST / number
	count.add_theme_font_size_override("font_size", num_font)
	count.add_theme_color_override("font_color", Pal.CREAM)
	count.add_theme_constant_override("outline_size", 0)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_col.add_child(count)
	var badge := PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()                     # the SAME leaf-green CTA fill the sell badge uses
	sb.bg_color = Pal.BTN_PRIMARY
	sb.border_color = Pal.BTN_PRIMARY_EDGE
	sb.set_corner_radius_all(int(chip_opts.get("sell_badge_radius", 10)))
	sb.set_border_width_all(Tuning.UiSkin.BTN_BORDER_W)
	Look.apply_box_shadow(sb)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	badge.add_theme_stylebox_override("panel", sb)
	badge.add_child(badge_col)
	stack.add_child(badge)
	var h := int(label_font * 1.45) + 3 + 8 + icon_px + 1 + int(num_font * 1.45)
	btn.custom_minimum_size = Vector2(maxf(icon_px + 64.0, 96.0), h)
	# the badge floats in a button wider than itself (a comfortable tap target); content_align decides where in
	# that slack it sits — the buy chip aligns its badge to the RIGHT so it hugs the sell button beside it.
	var center := HBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.alignment = content_align
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stack.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	center.add_child(stack)
	btn.add_child(center)
	var flat := StyleBoxEmpty.new()                  # the green lives on the inner badge; the button is bare
	btn.add_theme_stylebox_override("normal", flat)
	btn.add_theme_stylebox_override("hover", flat)
	btn.add_theme_stylebox_override("pressed", flat)
	btn.pressed.connect(on_press)
	Look.add_press_juice(btn)
	btn.visible = false
	row.add_child(btn)
	return {"btn": btn, "sb": sb, "count": count, "coin": coin}
