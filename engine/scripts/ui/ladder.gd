extends RefCounted
## Discovery-ladder MODAL — the tier ladder for a line: a twig-framed parchment board whose tiers fill a
## plain grid of SHARED slot cells (a grown tier shows its piece in the filled well, an unseen tier the
## locked well, the tapped tier sparkles). Self-contained popup, like ui/inbox.gd: builds its overlay into
## `host`, dismisses on a veil tap or the shared ✕, enters with FX.pop_in. The coordinator owns the open-gate
## (the discovery_ladder feature + line validity) and the data (Quests.ladder_entries); this just renders.
##   Ladder.open(host, {title: String, entries: Array, mark_tier: int})
##
## The FACE is BUILT from the shared UI KIT (games/grove/ui_kit.gd) using the design the
## UI WORKBENCH saves — the twig border, ladder ribbon and ✕ disc are authored on the shared "tiers" item,
## and the cell look IS the shared slot cell (the "Slot cell" item), read here, never duplicated. There are
## NO vines — just the cards, in a plain grid. Only the open-gate + the entry→cell mapping live here.

const Strings = preload("res://engine/scripts/core/strings.gd")
const Look = preload("res://engine/scripts/ui/skin.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const Audio = preload("res://engine/scripts/core/audio.gd")
const FX = preload("res://engine/scripts/ui/fx.gd")
const PieceView = preload("res://engine/scripts/ui/piece_view.gd")
const Overlay = preload("res://engine/scripts/ui/overlay.gd")
const Pal = Game.PALETTE

# The kit ships in the game build (export_filter=all_resources); load() at runtime keeps this file from
# hard-depending on a tools script, matching inbox.gd's guarded idiom.
static var KIT_PATH := Game.kit()
const OVERLAY_NAME := "LadderOverlay"

# --- the tiers mock (games/grove/assets/_concepts/dialogs/tiers_1080x1920.png) ---------------------
# Every metric below is a fraction of the mock's CARD WIDTH (995px there), so the face holds at any
# frame width. Measured off the mock, not eyeballed. The header is the shared frame's standard title
# band (no crest dressing).
const PAD_X_FRAC := 0.049            # the sheet's side inset (mock: cell left 89 − card left 40)
const PAD_Y_FRAC := 0.028            # ...and its top/bottom inset
const GEN_PX_FRAC := 0.31            # the generator art box (its art lands at ~0.23 of the card)
const GEN_BOX_H_FRAC := 0.233        # ...and the block it occupies (mock: gen art 306..536 / 995)
const GEN_GAP_FRAC := 0.016          # generator → grid (mock: 15 / 995)
const CELL_GAP_FRAC := 0.030         # inter-cell gutter (mock: 30 / 995)
const BODY_TAIL_FRAC := 0.020        # breathing room under the last row (mock: card bottom 1849 − row 1806)
# the corner NUMBER CHIP: a cream (discovered) / pale-grey (locked) rounded tile flush with the
# cell face's lower-right corner, carrying the tier number in ink.
const CHIP_FRAC := 0.275             # chip edge, × the cell (mock: 76 / 276)
const CHIP_FONT_FRAC := 0.66         # the number, × the chip
const CHIP_LOCKED_FILL := Color("#CECED2")
# the locked-tier padlock is the SHARED kit's dialog lock mark now (Kit._slot_lock_mark under
# opts.dialog_cells) — this dialog no longer swaps it in itself.
const CELL_FACE_INSET := 3.0         # slot_cell_background's face inset — the chip sits ON the face
const CELL_CORNER_FRAC := 0.18       # ...and its corner radius, so the chip's outer corner matches

static func open(host: Control, opts: Dictionary) -> void:
	var Kit: GDScript = load(KIT_PATH)
	if Kit == null:
		push_warning("Ladder: ui kit missing at %s" % KIT_PATH)
		return
	# Rebuild IN PLACE: reuse an already-open ladder overlay so an ingredient tap REPLACES the screen
	# (one modal ever) rather than stacking — Overlay.is_open would otherwise block a second mount, and
	# freeing-then-remounting mid-signal is unsafe. A duplicate open just re-renders the same content.
	var overlay: Control = host.get_node_or_null(NodePath(OVERLAY_NAME)) as Control
	if overlay == null or overlay.is_queued_for_deletion():
		overlay = Overlay.mount(host, OVERLAY_NAME)
	else:
		for c in overlay.get_children():
			c.queue_free()
	Audio.play("button_tap", -4.0)
	_render(Kit, host, overlay, opts)

# Build the veil + framed dialog for `opts` into `overlay`. Routes on the header descriptor: a "recipe"
# header → the two-ingredient view (no grid); anything else → the tier grid, with a generator icon on top
# when the header is a generator. Sets overlay metas the suites assert on (ladder_kind / header_gid / recipe_lines).
static func _render(Kit: GDScript, host: Control, overlay: Control, opts: Dictionary) -> void:
	var header: Dictionary = opts.get("header", {})
	var on_pick: Callable = opts.get("on_pick", Callable())

	var veil := ColorRect.new()
	veil.color = Color(Pal.GROUND_EDGE, 0.55)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(veil)
	veil.gui_input.connect(func(ev: InputEvent) -> void:
		if (ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed):
			overlay.queue_free())
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(cc)

	# every dialog renders at the SINGLE global frame width; content scales from this dialog's authored
	# baseline (Kit.DIALOG_DESIGN_PCT) to that width. The dialog body itself is built by _build (shared
	# with the workbench preview, so the tool matches the game exactly).
	var vw: float = host.get_viewport_rect().size.x
	var width: float = vw * Kit.DIALOG_DESIGN_PCT["tiers"] / 100.0
	var dialog: Control = _build(Kit, width, opts, overlay)
	cc.add_child(dialog)
	FX.pop_in(dialog)

## Build the Discovery-ladder dialog Control (the shared tiers chrome + the corner tier CHIPs + the
## generator/recipe header) at design `width`, from `opts` (header · entries · mark_tier · on_pick ·
## on_gen). SHARED: Ladder._render mounts it in its modal overlay; the workbench "tiers" element renders
## it standalone. `overlay` (optional) receives the rebuild metadata + drives the ✕ close; pass null for
## a static preview (no overlay, ✕ inert).
static func _build(Kit: GDScript, width: float, opts: Dictionary, overlay: Control = null) -> Control:
	var header: Dictionary = opts.get("header", {})
	var on_pick: Callable = opts.get("on_pick", Callable())
	var cfg: Dictionary = Kit.load_config(Kit.CONFIG_PATH)

	# the shared TIERS chrome (twig border + ladder ribbon + ✕ + slot-cell look) from the saved config.
	var dopts: Dictionary = Kit.tiers_opts_from_config(cfg)
	var scale: float = Kit.dialog_content_scale(cfg, "tiers")
	dopts["content_scale"] = scale
	dopts["banner_text"] = String(header.get("name", Strings.t("ladder.title")))
	dopts["on_close"] = func() -> void:
		if overlay != null and is_instance_valid(overlay): overlay.queue_free()

	# --- the MOCK's face (tiers_1080x1920) -------------------------------------------------------
	# the chrome (banner band + ✕) is built at the on-screen TARGET width; the body is laid out at
	# the design `width` and scaled — so banner metrics take target px, content metrics design px.
	var target_w: float = width * scale
	# the sheet's own inset — the mock's grid is a good deal narrower than the shared frame's default
	# (its cells are 0.277 of the card, not 0.30), which reads as more air down both edges.
	var pad_x: float = target_w * PAD_X_FRAC
	dopts["panel_pad_x"] = pad_x
	dopts["panel_pad_y"] = target_w * PAD_Y_FRAC
	dopts["show_num"] = false            # the plain kit number is replaced by this dialog's corner CHIP
	dopts["cell_gap"] = int(round(width * CELL_GAP_FRAC))

	# Both screens carry the line's tier grid; make_content lets the kit build each discovered tile's piece
	# at the cell size IT computes. (A base line stacks it under its generator icon; a merged line under its recipe.)
	dopts["make_content"] = func(d: Dictionary, px: float) -> Control:
		# inset 0: the kit cell already sizes `px` by the shared content_frac (board parity)
		return PieceView.make_piece(int(d.get("code", 0)), px, 0.0)
	var mark_tier := int(opts.get("mark_tier", 0))
	var cells: Array = _cells(opts.get("entries", []), mark_tier)
	var grid: Control = Kit.tiers_grid(cells, width, dopts)
	_dress_cells(grid, cells)

	var dialog: Control
	if overlay != null:
		overlay.set_meta("mark_tier", mark_tier)
	if String(header.get("kind", "")) == "recipe":
		var lines: Array = header.get("lines", [])
		if overlay != null:
			overlay.set_meta("ladder_kind", "recipe")
			overlay.set_meta("recipe_lines", lines)
		dialog = Kit.dialog_frame(_recipe_body(Kit, lines, mark_tier, grid, width, dopts, on_pick), width, dopts)
	else:
		var gid := String(header.get("gid", ""))
		if overlay != null:
			overlay.set_meta("ladder_kind", "tiers")
			overlay.set_meta("header_gid", gid)
		dialog = Kit.dialog_frame(_tiers_body(gid, grid, width, opts.get("on_gen", Callable()), dopts["on_close"]), width, dopts)
	return dialog

## Dress every built tier cell to the mock: the corner NUMBER CHIP, plus (on an undiscovered tier)
## the mock's flat navy PADLOCK in place of the kit's pale acorn lock. The kit's grid is a VBox of
## HBox rows filled in reading order, so it zips straight against the same `cells` array that built it.
static func _dress_cells(grid: Control, cells: Array) -> void:
	var i := 0
	for row in grid.get_children():
		for cell in (row as Node).get_children():
			if i < cells.size() and cell is Control:
				_tier_chip(cell as Control, cells[i])
			i += 1

static func _tier_chip(cell: Control, d: Dictionary) -> void:
	var tier := int(d.get("tier", 0))
	if tier <= 0:
		return
	var seen := bool(d.get("seen", false))
	var chip := Panel.new()
	chip.name = "TierChip"
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Pal.CREAM if seen else CHIP_LOCKED_FILL
	sb.anti_aliasing = true
	chip.add_theme_stylebox_override("panel", sb)
	var num := Label.new()
	num.name = "TierNumber"
	num.text = str(tier)
	num.set_anchors_preset(Control.PRESET_FULL_RECT)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	num.add_theme_color_override("font_color", Pal.INK)
	num.add_theme_constant_override("outline_size", 0)
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(num)
	cell.add_child(chip)
	# the grid sizes its cells DEFERRED (its own resize fit), so the chip follows the live cell rect:
	# flush with the cell FACE's lower-right corner, its outer corner matching the face's radius.
	var dock := func() -> void:
		if not (is_instance_valid(chip) and is_instance_valid(cell)):
			return
		var s := cell.size
		if s.x <= 0.0:
			return
		var cs := s.x * CHIP_FRAC
		chip.size = Vector2(cs, cs)
		chip.position = Vector2(s.x - CELL_FACE_INSET - cs, s.y - CELL_FACE_INSET - cs)
		var face_corner := int(round((minf(s.x, s.y) - CELL_FACE_INSET * 2.0) * CELL_CORNER_FRAC))
		sb.set_corner_radius_all(int(round(cs * 0.28)))
		sb.corner_radius_bottom_right = face_corner
		num.add_theme_font_size_override("font_size", int(maxf(10.0, cs * CHIP_FONT_FRAC)))
	cell.resized.connect(dock)
	dock.call_deferred()

# The MERGED-line recipe view: the two same-tier ingredient items (with a "+" between) — each a tappable button that
# opens THAT line's tier screen via on_pick — stacked ABOVE the merged line's OWN tier grid (the same shared
# grid the base-line screen uses). The ingredients are smaller than the grid-less view so both fit the frame.
# The MERGED-line recipe view (mock: merged_line_tiers_1080x1920) — the two same-tier ingredient items, each
# on its OWN pale rounded card, with a big ink "+" between them, stacked ABOVE the merged line's OWN tier grid
# (the same shared grid the base-line screen uses). Each card is a tappable button that opens THAT line's tier
# screen via on_pick. The cards are sized to the GRID's own column width so the header row and the grid below
# read as one column rhythm (the mock's ingredient card is exactly one grid cell wide).
static func _recipe_body(Kit: GDScript, lines: Array, tier: int, grid: Control, width: float,
		dopts: Dictionary, on_pick: Callable) -> Control:
	var cols: int = maxi(1, int(dopts.get("cols", 3)))
	var gap: float = float(dopts.get("cell_gap", 16))
	var card_px := _cell_px(width, cols, gap, Kit, dopts)
	var col := VBoxContainer.new()
	col.name = "RecipeBody"
	# NO forced min width: the body lays out inside the frame's ScaleContainer, whose width is the
	# sheet's inner width in layout space (design width MINUS the sheet's pads / content_scale). Pinning
	# it to the design width pushed the grid's right column past the scroll's clip line.
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", int(card_px * 0.17))
	var row := HBoxContainer.new()
	row.name = "RecipeRow"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", int(card_px * 0.05))
	var cards: Array = []
	for i in lines.size():
		var line := int(lines[i])
		var c := _ingredient_button(line, tier, card_px, on_pick)
		cards.append(c)
		row.add_child(c)
		if i < lines.size() - 1:
			row.add_child(_recipe_plus(card_px))
	col.add_child(row)
	col.add_child(grid)
	col.add_child(_tail(width))
	# re-derive the card size from the ACTUAL laid-out width, exactly as the kit's tier grid does for its
	# cells — so an ingredient card stays one grid column wide at any frame width.
	var fit := func() -> void:
		if not is_instance_valid(col):
			return
		var cw := maxf(40.0, (col.size.x - (cols - 1) * gap) / float(cols))
		for c in cards:
			if is_instance_valid(c):
				(c as Control).custom_minimum_size = Vector2(cw, cw * 0.93)
	col.resized.connect(fit)
	fit.call_deferred()
	return col

# One grid column's width, derived the SAME way the kit's tier grid derives it (content width minus the
# sheet's L/R inset, split across `cols` with `cell_gap` between) — the pre-layout estimate `fit` refines.
static func _cell_px(width: float, cols: int, gap: float, Kit: GDScript, dopts: Dictionary) -> float:
	var pad: float = float(dopts.get("panel_pad_x",
		Kit.frame_border(String(dopts.get("border", "parchment"))).get("pad_x", 26.0)))
	var avail: float = maxf(48.0, width - 2.0 * pad)
	return maxf(40.0, (avail - (cols - 1) * gap) / float(cols))

# The "+" joining the two ingredients — plain ink, sized off the card (mock: a heavy navy plus, no ornament).
static func _recipe_plus(card_px: float) -> Label:
	var plus := Label.new()
	plus.name = "RecipePlus"
	plus.text = "+"
	plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plus.custom_minimum_size = Vector2(card_px * 0.27, 0.0)
	plus.add_theme_font_size_override("font_size", int(card_px * 0.46))
	plus.add_theme_color_override("font_color", Pal.INK)
	plus.add_theme_constant_override("outline_size", 0)
	plus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return plus

# One ingredient: a pale rounded card (a shade lighter than the sheet, with the house tinted drop shadow),
# the item art filling it, the whole card tappable. `card_px` is the grid column width; the mock's card is a
# touch shorter than it is wide, and the art sits generously inside.
static func _ingredient_button(line: int, tier: int, card_px: float, on_pick: Callable) -> Button:
	var btn := Button.new()
	btn.name = "IngredientCard_%d" % line
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(card_px, card_px * 0.93)
	btn.set_meta("ingredient_line", line)
	var item_tier := maxi(1, tier)
	var code := line * 100 + item_tier
	btn.set_meta("ingredient_tier", item_tier)
	btn.set_meta("ingredient_code", code)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Pal.CREAM.lightened(0.42)
	sb.set_corner_radius_all(int(card_px * 0.13))
	Look.apply_box_shadow(sb)
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(st, sb)
	var holder := CenterContainer.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(holder)
	var piece: Control = PieceView.make_piece(code, card_px * 0.78)
	piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(piece)
	if on_pick.is_valid():
		btn.pressed.connect(func() -> void: on_pick.call(line))
	return btn

# The BASE-line tier screen body: the GENERATOR icon centred atop the unchanged tier grid (gid "" → grid only).
# The icon is a TAP TARGET when `on_gen` is valid: on_gen(gid) -> bool asks the board to SHOW the generator
# (select it on the board, or pull it from the gen bag); true → the tap acted, so `close` dismisses the modal.
# A false return (e.g. no empty cell to place into) leaves the screen open, untouched.
static func _tiers_body(gid: String, grid: Control, width: float, on_gen: Callable = Callable(),
		close: Callable = Callable()) -> Control:
	if gid == "":
		return grid
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", int(width * GEN_GAP_FRAC))
	# The generator art sits in a plain Control of the MOCK's block height, not a CenterContainer:
	# make_generator's holder is a square box whose art only fills ~3/4 of it, and a CenterContainer
	# would propagate that whole box as a minimum, pushing the grid a long way down. A plain Control
	# severs the propagation, so the art keeps its size while the block keeps the mock's height.
	var box: float = width * GEN_PX_FRAC
	var holder := Control.new()
	holder.name = "LadderGeneratorSlot"
	holder.custom_minimum_size = Vector2(0.0, width * GEN_BOX_H_FRAC)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon: Control = PieceView.make_generator(gid, box)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.size = Vector2(box, box)
	holder.add_child(icon)
	var btn: Button = null
	if on_gen.is_valid():
		btn = Button.new()
		btn.name = "LadderGeneratorButton"
		btn.focus_mode = Control.FOCUS_NONE
		for st in ["normal", "hover", "pressed", "focus", "disabled"]:
			btn.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		btn.pressed.connect(func() -> void:
			if bool(on_gen.call(gid)) and close.is_valid():
				close.call())
		holder.add_child(btn)
	var dock := func() -> void:
		if is_instance_valid(icon) and is_instance_valid(holder):
			icon.position = Vector2((holder.size.x - box) * 0.5, (holder.size.y - box) * 0.5)
			if btn != null and is_instance_valid(btn):
				btn.position = icon.position
				btn.size = Vector2(box, box)
	holder.resized.connect(dock)
	dock.call_deferred()
	col.add_child(holder)
	col.add_child(grid)
	col.add_child(_tail(width))
	return col

## The mock's breathing room under the last tier row (the shared frame's bottom inset alone is tighter).
static func _tail(width: float) -> Control:
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(0.0, width * BODY_TAIL_FRAC)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return pad

# Map Quests.ladder_entries ({tier, code, seen}) → kit tier cells ({tier, seen, marked, code}). The kit's
# make_content reads `code` to build the discovered piece; `marked` flags the tapped/asked tier's ring.
static func _cells(entries: Array, mark_tier: int) -> Array:
	var out: Array = []
	for e in entries:
		out.append({
			"tier": int(e.get("tier", 0)),
			"seen": bool(e.get("seen", false)),
			"marked": int(e.get("tier", 0)) == mark_tier,
			"code": int(e.get("code", 0)),
		})
	return out
