extends RefCounted
## Discovery-ladder MODAL — the tier ladder for a line: a twig-framed parchment board whose tiers fill a
## plain grid of SHARED slot cells (a grown tier shows its piece in the filled well, an unseen tier the
## locked well, the tapped tier sparkles). Self-contained popup, like ui/inbox.gd: builds its overlay into
## `host`, dismisses on a veil tap or the shared ✕, enters with FX.pop_in. The coordinator owns the open-gate
## (the discovery_ladder feature + line validity) and the data (Quests.ladder_entries); this just renders.
##   Ladder.open(host, {title: String, entries: Array, mark_tier: int})
##
## The FACE is BUILT from the shared UI KIT (games/grove/tools/ui_workbench_kit.gd) using the design the
## UI WORKBENCH saves — the twig border, ladder ribbon and ✕ disc are authored on the shared "tiers" item,
## and the cell look IS the shared slot cell (the "Slot cell" item), read here, never duplicated. There are
## NO vines — just the cards, in a plain grid. Only the open-gate + the entry→cell mapping live here.

const Strings = preload("res://engine/scripts/core/strings.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const Audio = preload("res://engine/scripts/core/audio.gd")
const FX = preload("res://engine/scripts/ui/fx.gd")
const PieceView = preload("res://engine/scripts/ui/piece_view.gd")
const Overlay = preload("res://engine/scripts/ui/overlay.gd")
const Pal = Game.PALETTE
const SHADOW_TINT := Color("#294654")   # the dialog mocks' tinted shadow role (~18% opacity), as ui/residents.gd

# The kit ships in the game build (export_filter=all_resources); load() at runtime keeps this file from
# hard-depending on a tools script, matching inbox.gd's guarded idiom.
const KIT_PATH := "res://games/grove/tools/ui_workbench_kit.gd"
const OVERLAY_NAME := "LadderOverlay"

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

	var cfg: Dictionary = Kit.load_config(Kit.CONFIG_PATH)
	var vw: float = host.get_viewport_rect().size.x
	# every dialog renders at the SINGLE global frame width; content scales from this dialog's
	# authored baseline (Kit.DIALOG_DESIGN_PCT) to that width (Kit.dialog_content_scale).
	var width: float = vw * Kit.DIALOG_DESIGN_PCT["tiers"] / 100.0

	# the shared TIERS chrome (twig border + ladder ribbon + ✕ + slot-cell look) from the saved config.
	var dopts: Dictionary = Kit.tiers_opts_from_config(cfg)
	dopts["content_scale"] = Kit.dialog_content_scale(cfg, "tiers")
	dopts["banner_text"] = String(header.get("name", Strings.t("ladder.title")))
	dopts["on_close"] = func() -> void:
		if is_instance_valid(overlay): overlay.queue_free()

	# Both screens carry the line's tier grid; make_content lets the kit build each discovered tile's piece
	# at the cell size IT computes. (A base line stacks it under its generator icon; a merged line under its recipe.)
	dopts["make_content"] = func(d: Dictionary, px: float) -> Control:
		return PieceView.make_piece(int(d.get("code", 0)), px)
	var mark_tier := int(opts.get("mark_tier", 0))
	var grid: Control = Kit.tiers_grid(_cells(opts.get("entries", []), mark_tier), width, dopts)

	var dialog: Control
	overlay.set_meta("mark_tier", mark_tier)
	if String(header.get("kind", "")) == "recipe":
		var lines: Array = header.get("lines", [])
		overlay.set_meta("ladder_kind", "recipe")
		overlay.set_meta("recipe_lines", lines)
		dialog = Kit.dialog_frame(_recipe_body(Kit, lines, mark_tier, grid, width, dopts, on_pick), width, dopts)
	else:
		var gid := String(header.get("gid", ""))
		overlay.set_meta("ladder_kind", "tiers")
		overlay.set_meta("header_gid", gid)
		dialog = Kit.dialog_frame(_tiers_body(gid, grid, width), width, dopts)

	cc.add_child(dialog)
	FX.pop_in(dialog)

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
	sb.shadow_color = Color(SHADOW_TINT, 0.18)
	sb.shadow_size = int(maxf(6.0, card_px * 0.04))
	sb.shadow_offset = Vector2(0, maxf(3.0, card_px * 0.02))
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
static func _tiers_body(gid: String, grid: Control, width: float) -> Control:
	if gid == "":
		return grid
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(width, 0.0)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", int(width * 0.025))
	var center := CenterContainer.new()
	var icon: Control = PieceView.make_generator(gid, width * 0.22)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(icon)
	col.add_child(center)
	col.add_child(grid)
	return col

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
