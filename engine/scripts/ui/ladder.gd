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
	var grid: Control = Kit.tiers_grid(_cells(opts.get("entries", []), int(opts.get("mark_tier", 0))), width, dopts)

	var dialog: Control
	if String(header.get("kind", "")) == "recipe":
		var lines: Array = header.get("lines", [])
		overlay.set_meta("ladder_kind", "recipe")
		overlay.set_meta("recipe_lines", lines)
		dialog = Kit.dialog_frame(_recipe_body(lines, grid, width, on_pick), width, dopts)
	else:
		var gid := String(header.get("gid", ""))
		overlay.set_meta("ladder_kind", "tiers")
		overlay.set_meta("header_gid", gid)
		dialog = Kit.dialog_frame(_tiers_body(gid, grid, width), width, dopts)

	cc.add_child(dialog)
	FX.pop_in(dialog)

# The MERGED-line recipe view: the two ingredient items (with a "+" between) — each a tappable button that
# opens THAT line's tier screen via on_pick — stacked ABOVE the merged line's OWN tier grid (the same shared
# grid the base-line screen uses). The ingredients are smaller than the grid-less view so both fit the frame.
static func _recipe_body(lines: Array, grid: Control, width: float, on_pick: Callable) -> Control:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(width, 0.0)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", int(width * 0.025))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", int(width * 0.05))
	var icon_px := width * 0.20
	for i in lines.size():
		var line := int(lines[i])
		row.add_child(_ingredient_button(line, icon_px, on_pick))
		if i < lines.size() - 1:
			var plus := Label.new()
			plus.text = "+"
			plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			plus.add_theme_font_size_override("font_size", int(icon_px * 0.55))
			plus.add_theme_color_override("font_color", Color(0.36, 0.26, 0.18))
			row.add_child(plus)
	col.add_child(row)
	col.add_child(grid)
	return col

static func _ingredient_button(line: int, icon_px: float, on_pick: Callable) -> Button:
	var btn := Button.new()
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(icon_px, icon_px)
	btn.set_meta("ingredient_line", line)
	var holder := CenterContainer.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(holder)
	var piece: Control = PieceView.make_piece(line * 100 + 1, icon_px)   # the base item (tier 1) of the ingredient line
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
