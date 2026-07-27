extends RefCounted
## The RESIDENT (spirit) visual vocabulary — every builder the map's habitat dock uses to turn a
## `(kind, tier)` pair into a Control: the draggable orb chip, the new-style board cell (filled or
## empty), the content-cropped icon, the shared focus ring, the dock's label + green pill button,
## and the per-line collect glyph. Pure view builders: inputs in (kind, tier, px, the Kit handle,
## the slot-cell opts), a Control out — no scene/instance state. The map scene owns placement,
## selection and the drag; this owns how a spirit LOOKS.
##
## The `Kit` handle (games/grove/ui_kit.gd) is passed IN rather than loaded here: the slot cell is
## the game's skin, and one load per build pass is the map's own call — `spirit_cell`/`empty_cell`
## already worked that way, and `focus_ring` now matches so the ring and the cell it rings are
## always read from the same Kit.
##
## Layering: ui/ may import core/ + ui/, never scenes/ — see docs/design/merge_spec.md §15.

const G = preload("res://engine/scripts/core/content.gd")
const PieceView = preload("res://engine/scripts/ui/piece_view.gd")
const FocusRing = preload("res://engine/scripts/ui/focus_ring.gd")
const FS = preload("res://engine/scripts/core/tuning.gd").FontScale

# --- the spirit DOCK constants (shared by the place-picker's housed strip + in-hand column) ------
# The map view IS the residents surface now: the place-picker carries every completed map's housed orbs
# as a right-side STRIP and the in-hand spirits as a right-hand COLUMN. Spirits are dragged between them
# (a map places, a match merges, the hand column brings out); a tap on a housed orb focuses it for Sell.
# (There is no standalone Residents button or modal dialog any more.)
const DOCK_INK := Color("#43352B")
const DOCK_PARCH := Color("#F3E7CE")

# The trim-to-opaque-content cache lives on PieceView (trimmed_tex) — resident art and board item
# art are the SAME padded canvases, so a second copy here decoded every path twice and held two
# AtlasTextures for it.
static func content_tex(path: String) -> Texture2D:
	return PieceView.trimmed_tex(path)

static func spirit_chip(kind: String, tier: int, px: float, on_tap: Callable, show_badge: bool = true) -> Control:
	var btn := Button.new()
	btn.flat = true
	btn.custom_minimum_size = Vector2(px, px)
	btn.size = Vector2(px, px)
	btn.pressed.connect(on_tap)
	var path := G.resident_art(kind, tier)
	var has_art := path != "" and ResourceLoader.exists(path)
	if has_art:
		var t := TextureRect.new()
		t.texture = load(path)                            # art is pre-centered (re-cut), so display it as-is
		t.set_anchors_preset(Control.PRESET_FULL_RECT)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(t)
	else:
		var disc := Panel.new()
		disc.name = "MapResidentFallbackDisc"
		disc.set_anchors_preset(Control.PRESET_FULL_RECT)
		var ds := StyleBoxFlat.new()
		ds.bg_color = Color("#F6B659", 0.96)
		ds.set_corner_radius_all(int(px / 2.0))
		ds.set_border_width_all(maxi(2, int(round(px * 0.075))))
		ds.border_color = Color("#8D5A26", 0.72)
		disc.add_theme_stylebox_override("panel", ds)
		disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(disc)
	if not show_badge:
		return btn                                       # the in-hand board reads tier from its info bar, not a per-orb badge
	var badge := Label.new()
	badge.text = "t%d" % tier
	badge.name = "MapResidentTierBadge"
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", int(clampf(px * (0.38 if has_art else 0.46), 14.0, 24.0)))   # scales with the orb size
	badge.add_theme_color_override("font_color", DOCK_INK)
	badge.add_theme_color_override("font_outline_color", DOCK_PARCH)
	badge.add_theme_constant_override("outline_size", 3)
	badge.custom_minimum_size = Vector2(px * (0.48 if has_art else 1.0), px * (0.34 if has_art else 1.0))
	badge.size = badge.custom_minimum_size
	badge.position = Vector2(px - badge.size.x - 1.0, 0.0) if has_art else Vector2.ZERO
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(badge)
	return btn

# A NEW-STYLE board CELL holding a spirit — built from Kit.slot_cell (the SAME cell the reskinned merge board
# + bag use), with the spirit's icon (content-cropped → uniform + centered) as its filled content. The cell
# IGNOREs the mouse (the single input surface hit-tests it); `selected` draws the board's shared focus ring.
static func spirit_cell(Kit: GDScript, bag_opts: Dictionary, kind: String, tier: int, px: float, selected: bool) -> Control:
	if Kit == null:
		return empty_cell(Kit, bag_opts, px)
	var cell: Control = Kit.slot_cell({"state": "filled",
		"make_content": func(pp: float) -> Control: return spirit_icon(kind, tier, pp)}, bag_opts)
	cell.custom_minimum_size = Vector2(px, px)
	force_ignore(cell)
	if selected:
		cell.add_child(focus_ring(Kit))
	return cell

# An EMPTY new-style board cell (Kit.slot_cell, no spirit) so the in-hand grid reads as a board of cells.
static func empty_cell(Kit: GDScript, bag_opts: Dictionary, px: float) -> Control:
	if Kit == null:
		var c := Panel.new()
		c.custom_minimum_size = Vector2(px, px)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return c
	var cell: Control = Kit.slot_cell({"state": "empty"}, bag_opts)
	cell.custom_minimum_size = Vector2(px, px)
	force_ignore(cell)
	return cell

static func spirit_icon(kind: String, tier: int, px: float) -> Control:
	var t := TextureRect.new()
	t.custom_minimum_size = Vector2(px, px)
	t.size = Vector2(px, px)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art := G.resident_art(kind, tier)
	if art != "" and ResourceLoader.exists(art):
		t.texture = content_tex(art)
	return t

static func focus_ring(Kit: GDScript) -> Control:
	var ring := FocusRing.new()
	ring.name = "ResidentFocusRing"
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.z_index = 8
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var o := focus_ring_opts(Kit)
	if not o.is_empty():
		ring.color = o.color
		ring.halo_color = o.halo_color
		ring.halo_a = o.halo_a
		ring.arm_frac = o.arm_frac
		ring.thick_frac = o.thick_frac
		ring.pad_frac = o.pad_frac
		ring.halo = o.halo
	ring.queue_redraw()
	return ring

static func focus_ring_opts(Kit: GDScript) -> Dictionary:
	if Kit == null:
		return {}
	return Kit.focus_ring_opts_from_config(Kit.load_config(Kit.CONFIG_PATH))

static func dock_label(text: String, size: int, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", DOCK_INK)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if bold:
		l.add_theme_color_override("font_outline_color", DOCK_PARCH)
		l.add_theme_constant_override("outline_size", 2)
	return l

# A small green pill button for the dock chips (Collect / Expedition) — the same face the Sell pill wears.
static func dock_chip_button(btn_name: String, text: String, enabled: bool) -> Button:
	var btn := Button.new()
	btn.name = btn_name
	btn.text = text
	btn.disabled = not enabled
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", FS.FINE)
	btn.add_theme_color_override("font_color", Color("#F4FBE9"))
	btn.add_theme_color_override("font_outline_color", Color("#173404"))
	btn.add_theme_constant_override("outline_size", 3)
	var gsb := StyleBoxFlat.new()
	gsb.bg_color = Color("#639922") if enabled else Color("#8A9377")
	gsb.set_corner_radius_all(12)
	gsb.set_border_width_all(2)
	gsb.content_margin_left = 10.0
	gsb.content_margin_right = 10.0
	gsb.border_color = Color("#3B6D11") if enabled else Color("#6B755C")
	for st_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(st_name, gsb)
	return btn

# The per-line collect glyph on the dock chip (boost reuses the leaf until bespoke art ships — parked).
static func line_icon(line: String) -> String:
	match line:
		"coin": return "coin"
		"water": return "water"
		"diamond": return "gem"
		_: return "leaf"

# Force a control subtree mouse-transparent — the map routes every spot tap through its single input
# surface, so any seated affordance (the kit unlock disc) must not eat the press before _map_tap.
static func force_ignore(n: Control) -> void:
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in n.get_children():
		if c is Control:
			force_ignore(c)
