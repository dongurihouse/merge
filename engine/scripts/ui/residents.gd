extends RefCounted
## The RESIDENTS management dialog (resident_management_dialog_v2 mock) — opened from the home
## screen's Residents rail tile. One modal sheet over the map:
##   · RESOURCE BANKS — a 2×2 grid of per-line bank cards (large icon · name · n/cap · thick bar · full-in)
##   · COLLECT ALL   — the single collection action (a plain action-green pill)
##   · HABITAT CELLS — one row: placed spirits · free cells · locked cells
##   · ON HAND       — the 4-column hand grid (tap to select, DRAG to merge/place)
##   · the INSPECTOR — a flat full-width strip flush with the sheet's bottom edge:
##     selected portrait · name · info · SELL
## Drags use Godot's native DnD via the DragCard wrapper: a hand spirit dragged onto a same
## line+tier hand spirit MERGES (Bucket.hand_merge), onto a matching placed spirit climbs it
## (place_merge), onto a free habitat cell moves in (place).
## The MODEL is entirely engine/scripts/core/bucket.gd; this file is render + taps + drags only.
## Layering: ui/ may import core/ + ui/, never scenes/. The kit is loaded by PATH at runtime
## (the settings.gd/inbox.gd idiom) so this file keeps no hard dependency on a tools script.

const Save = preload("res://engine/scripts/core/save.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const G = preload("res://engine/scripts/core/content.gd")
const Bucket = preload("res://engine/scripts/core/bucket.gd")
const RB = preload("res://engine/scripts/core/resident_bucket.gd")
const Audio = preload("res://engine/scripts/core/audio.gd")
const Overlay = preload("res://engine/scripts/ui/overlay.gd")
const Look = preload("res://engine/scripts/ui/skin.gd")
const FX = preload("res://engine/scripts/ui/fx.gd")
const PieceView = preload("res://engine/scripts/ui/piece_view.gd")   # the SHARED board cell (holder + contact shadow + lift)
const FS = preload("res://engine/scripts/core/tuning.gd").FontScale
const Pal = Game.PALETTE
const D = Game.DATA

const OVERLAY_NAME := "ResidentsOverlay"
const KIT_PATH := "res://games/grove/tools/ui_workbench_kit.gd"
const HAND_COLS := 4
const HABITAT_SLOTS_SHOWN := 5      # the mock's fixed row: granted cells first, the rest locked
const INSPECTOR_H := 104.0          # the bottom strip's height in DESIGN units
const CELL_CORNER := 16.0           # the resident/bank card corner the shared shadow hugs

# Per-line chrome: icon id + display name + the bank bar's fill colour (Meadow Sky roles).
const LINE_FACE := {
	"coin":    {"icon": "coin",  "label": "Coins",    "fill": Color("#D6A94C")},
	"water":   {"icon": "water", "label": "Water",    "fill": Color("#6FA9C0")},
	"boost":   {"icon": "star",  "label": "Boost",    "fill": Color("#5F9B6D")},
	"diamond": {"icon": "gem",   "label": "Diamonds", "fill": Color("#8677A3")},
}

## A spirit/free-cell wrapper that owns ALL input for its card: tap-to-select plus a MANUAL drag
## (press → move past a threshold → ghost follows → release resolves the drop target). Manual, not
## Godot-native DnD: the project runs pointing/emulate_touch_from_mouse, which feeds Controls touch
## events the native mouse-driven drag machinery never sees — so drags silently did nothing in the
## real app. The wrapped kit cell underneath is mouse-transparent, so this wrapper is the one
## control the viewport talks to. `data` = {src: "hand"|"placed"|"free", idx, line, tier}.
class DragCard:
	extends Control
	const DRAG_START_PX := 14.0             # press slop before a drag begins (below = a tap)
	var data: Dictionary = {}
	var on_tap: Callable = Callable()
	var can_take: Callable = Callable()     # (src_data, my_data) -> bool
	var on_take: Callable = Callable()      # (src_data, my_data) -> void
	var make_preview: Callable = Callable() # () -> Control (the drag ghost)
	var targets: Callable = Callable()      # () -> Array of live DragCards (the drop registry)
	var drag_layer: Control = null          # the overlay the ghost rides (above the dialog)
	var _down := false
	var _dragging := false
	var _down_gp := Vector2.ZERO
	var _ghost: Control = null

	## With emulate_touch_from_mouse BOTH the mouse event and its emulated touch arrive — the
	## _down/_dragging flags make the second press/release of a pair a no-op.
	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			_press(_gp(ev.position)) if (ev as InputEventMouseButton).pressed else _release(_gp(ev.position))
			accept_event()
		elif ev is InputEventScreenTouch:
			_press(_gp(ev.position)) if (ev as InputEventScreenTouch).pressed else _release(_gp(ev.position))
			accept_event()
		elif (ev is InputEventMouseMotion or ev is InputEventScreenDrag) and _down:
			_move(_gp(ev.position))
			accept_event()

	## _gui_input positions are LOCAL — the drag runs in global space.
	func _gp(local: Vector2) -> Vector2:
		return get_global_transform() * local

	func _press(gp: Vector2) -> void:
		if _down:
			return
		_down = true
		_dragging = false
		_down_gp = gp

	func _move(gp: Vector2) -> void:
		if not _dragging and String(data.get("src", "")) in ["hand", "placed"] \
				and gp.distance_to(_down_gp) > DRAG_START_PX:
			_dragging = true
			if make_preview.is_valid() and drag_layer != null and is_instance_valid(drag_layer):
				_ghost = make_preview.call()
				_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
				drag_layer.add_child(_ghost)
		if _dragging and _ghost != null and is_instance_valid(_ghost):
			_ghost.global_position = gp - _ghost.size * 0.5

	func _release(gp: Vector2) -> void:
		if not _down:
			return
		var was_drag := _dragging
		_down = false
		_dragging = false
		if _ghost != null and is_instance_valid(_ghost):
			_ghost.queue_free()
		_ghost = null
		# resolve LAST: on_take/on_tap repaint the dialog, which queue_frees this very card.
		if was_drag:
			var t := _target_at(gp)
			if t != null and t.on_take.is_valid():
				t.on_take.call(data, t.data)
		else:
			tap()

	## The first registered card under `gp` that ACCEPTS this payload — rejecting targets fall
	## through, so a placed spirit dropped over a hand card still reaches the hand zone behind it.
	func _target_at(gp: Vector2) -> DragCard:
		if not targets.is_valid():
			return null
		for c in targets.call():
			if c != self and c != null and is_instance_valid(c) \
					and (c as Control).get_global_rect().has_point(gp) \
					and c.can_take.is_valid() and bool(c.can_take.call(data, c.data)):
				return c
		return null

	func tap() -> void:
		if on_tap.is_valid():
			on_tap.call()

## Open the dialog. opts: refresh (Callable — the host re-reads wallet/badges after collect/sell),
## on_info (Callable(kind, tier) — the host opens the resident tier ladder), on_expedition
## (Callable — the host opens the Load out dialog; the Expedition pill is omitted without it).
static func open(host: Control, opts: Dictionary = {}) -> void:
	if Overlay.is_open(host, OVERLAY_NAME):
		return
	var Kit: GDScript = load(KIT_PATH)
	if Kit == null:
		push_warning("Residents: mail kit missing at %s" % KIT_PATH)
		return
	Audio.play("button_tap", -2.0)

	var overlay := Overlay.mount(host, OVERLAY_NAME)
	var veil := ColorRect.new()
	veil.color = Color(Pal.INK, 0.6)
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
	var width: float = vw * Kit.DIALOG_DESIGN_PCT["residents"] / 100.0
	# the CONTENT lays out at the design width MINUS the sheet's insets AND the scrollbar
	# (the frame scales it by content_scale, so those real-px widths count at 1/scale in
	# layout space) — sized against `width` alone the fixed-size cards overflow the sheet's
	# right edge; the scroll's vertical bar, when shown, eats its width from the child area.
	var scale: float = maxf(0.01, Kit.dialog_content_scale(cfg, "residents"))
	var inner: float = width \
		- (2.0 * float(Kit.frame_border("parchment")["pad_x"]) + float(Kit.SCROLLBAR_W)) / scale

	# the render context every repaint reads: selection + the two rebuildable surfaces.
	var ctx := {"sel": {}, "body": null, "insp": null, "scale": scale,
		"kit": Kit, "cfg": cfg, "inner": inner, "overlay": overlay, "opts": opts,
		"piece_inset": _board_piece_inset(cfg)}

	var body := VBoxContainer.new()
	body.name = "ResidentsBody"
	body.add_theme_constant_override("separation", 14)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ctx["body"] = body

	var fopts: Dictionary = Kit.dialog_opts_from_config(cfg)
	fopts["banner_text"] = "Residents"
	fopts["content_scale"] = scale
	fopts["list_max_h"] = host.get_viewport_rect().size.y * 0.82   # taller sheet: the board-sized cells (items 3/4) need the extra height budget
	fopts["on_close"] = func() -> void:
		if is_instance_valid(overlay):
			overlay.queue_free()
	var dialog: Control = Kit.dialog_frame(body, width, fopts)
	cc.add_child(dialog)

	# the INSPECTOR rides the frame's wrap OUTSIDE the padded scroll, pinned flush to the sheet's
	# bottom edge (mock: a flat full-width strip, no side margins, no border) — repositioned with
	# the card, rebuilt by every repaint.
	var card: Control = dialog.find_child("MeadowDialogPanel", true, false)
	var insp := PanelContainer.new()
	insp.name = "ResidentsInspector"
	var corner := int(float(fopts.get("card_corner", 28.0)))
	var isb := StyleBoxFlat.new()
	isb.bg_color = Pal.CREAM.darkened(0.05)
	isb.corner_radius_bottom_left = corner
	isb.corner_radius_bottom_right = corner
	isb.content_margin_left = 20.0 * scale; isb.content_margin_right = 20.0 * scale
	isb.content_margin_top = 12.0 * scale; isb.content_margin_bottom = 12.0 * scale
	insp.add_theme_stylebox_override("panel", isb)
	dialog.add_child(insp)
	ctx["insp"] = insp
	var dock_insp := func() -> void:
		if is_instance_valid(insp) and is_instance_valid(card):
			var h := INSPECTOR_H * scale
			insp.position = Vector2(card.position.x, card.position.y + card.size.y - h)
			insp.size = Vector2(card.size.x, h)
	card.resized.connect(dock_insp)
	insp.resized.connect(dock_insp)
	dock_insp.call_deferred()

	_repaint(ctx)
	FX.pop_in(dialog)

## Repaint BOTH live surfaces (the scroll body and the bottom inspector) from the bucket state.
static func _repaint(ctx: Dictionary) -> void:
	if ctx.body != null and is_instance_valid(ctx.body):
		_rebuild_body(ctx)
	if ctx.insp != null and is_instance_valid(ctx.insp):
		_rebuild_inspector(ctx)
	var refresh_host: Callable = (ctx.opts as Dictionary).get("refresh", Callable())
	if refresh_host.is_valid():
		refresh_host.call()

static func _clear(node: Control) -> void:
	# queue_free (not free): a repaint fires from INSIDE a child's input/pressed signal — freeing
	# the emitting control mid-emission is an error, so detach now and let the tree reap it.
	for ch in node.get_children():
		node.remove_child(ch)
		ch.queue_free()

static func _rebuild_body(ctx: Dictionary) -> void:
	var body: VBoxContainer = ctx.body
	var Kit: GDScript = ctx.kit
	var cfg: Dictionary = ctx.cfg
	var width: float = ctx.inner
	_clear(body)
	ctx["cards"] = []   # the drop-target registry — every DragCard this rebuild creates

	# --- RESOURCE BANKS: the 2×2 mini bank cards + the one Collect-all action -----------------------
	body.add_child(_section_label(Kit, "Resource banks"))
	var banks := GridContainer.new()
	banks.name = "ResourceBanksGrid"
	banks.columns = 2
	banks.add_theme_constant_override("h_separation", 14)
	banks.add_theme_constant_override("v_separation", 14)
	banks.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var ready_total := 0
	for line in Bucket.LINES:
		var rep: Dictionary = Bucket.line_report(String(line))
		ready_total += int(rep.ready)
		banks.add_child(_bank_card(Kit, String(line), rep, (width - 14.0) * 0.5))
	body.add_child(banks)

	var collect := _collect_all_button(Kit, ready_total > 0)
	collect.pressed.connect(func() -> void:
		Audio.play("button_tap", -2.0)
		Bucket.collect()
		_repaint(ctx))
	var crow := HBoxContainer.new()
	crow.alignment = BoxContainer.ALIGNMENT_CENTER
	crow.add_child(collect)
	body.add_child(crow)

	# --- HABITAT CELLS: granted cells (placed spirits first, then free), locked to the mock's row ---
	body.add_child(_section_label(Kit, "Habitat cells"))
	var bag_opts: Dictionary = Kit.bag_card_opts_from_config(cfg)
	bag_opts["dialog_cells"] = true   # this is a DIALOG's grid → the shared sage cell face, not the board's mint
	var placed: Array = Bucket.placed()
	var cells_total: int = Bucket.cells_total()
	var slots: int = maxi(HABITAT_SLOTS_SHOWN, cells_total)
	# the cells WRAP at HABITAT_SLOTS_SHOWN per row: sized against the row width (not the slot count),
	# a late-game habitat keeps mock-sized cells and grows downward instead of shrinking to slivers.
	var cell_px: float = (width - 10.0 * float(HABITAT_SLOTS_SHOWN - 1)) / float(HABITAT_SLOTS_SHOWN)
	var cbag: Dictionary = bag_opts.duplicate(true)
	cbag["cell_w"] = cell_px
	cbag["cell_h"] = cell_px
	cbag["content_frac"] = 1.0   # the resident art fills the cell like a BOARD tile (its own 0.16 inset governs the margin), not the bag's 0.62
	var cells := GridContainer.new()
	cells.name = "HabitatCellsRow"
	cells.columns = HABITAT_SLOTS_SHOWN
	cells.add_theme_constant_override("h_separation", 10)
	cells.add_theme_constant_override("v_separation", 10)
	cells.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for i in slots:
		var cell: Control
		if i < placed.size():
			var inst: Dictionary = placed[i]
			cell = _spirit_card(ctx, cbag, "placed", i, String(inst.line), int(inst.tier), cell_px)
			cell.name = "HabitatCell_%02d" % i
		elif i < cells_total:
			cell = _free_cell(ctx, cbag, cell_px)
			cell.name = "HabitatCellFree_%02d" % i
		else:
			cell = Kit.slot_cell({"state": "locked"}, cbag)
			cell.custom_minimum_size = Vector2(cell_px, cell_px)
			cell.name = "HabitatCellLocked_%02d" % i
			_shadow_cell(cell)
		cells.add_child(cell)
	body.add_child(cells)

	# --- ON HAND: the 4-column tap-to-select / drag-to-merge grid -----------------------------------
	body.add_child(_section_label(Kit, "On hand"))
	var hand: Array = Bucket.hand()
	var hand_px: float = (width - 10.0 * float(HAND_COLS - 1)) / float(HAND_COLS)
	var hbag: Dictionary = bag_opts.duplicate(true)
	hbag["cell_w"] = hand_px
	hbag["cell_h"] = hand_px
	hbag["content_frac"] = 1.0   # board-sized art (see the habitat cbag note)
	var grid := GridContainer.new()
	grid.name = "OnHandGrid"
	grid.columns = HAND_COLS
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	for i in hand.size():
		var inst: Dictionary = hand[i]
		var card := _spirit_card(ctx, hbag, "hand", i, String(inst.line), int(inst.tier), hand_px)
		card.name = "OnHandCard_%02d" % i
		grid.add_child(card)
	for _e in range(hand.size(), maxi(hand.size(), HAND_COLS)):
		# empty filler tiles carry NO shadow: their face is transparent, so a filled shadow panel
		# would read as a solid slab through it.
		grid.add_child(Kit.slot_cell({"state": "empty"}, hbag))
	# the WHOLE hand area is the unplace drop zone: a DragCard backdrop under the grid — a placed
	# spirit dropped anywhere over it (cards included: their can_take rejects "placed", so the
	# hit-test falls through) comes back to the hand. Registered AFTER the cards, so specific
	# merge targets win first.
	var zone := DragCard.new()
	zone.name = "OnHandDropZone"
	zone.mouse_filter = Control.MOUSE_FILTER_STOP
	zone.data = {"src": "handzone"}
	zone.can_take = func(from: Dictionary, _me: Dictionary) -> bool:
		return String(from.get("src", "")) == "placed"
	zone.on_take = func(from: Dictionary, _me: Dictionary) -> void:
		if Bucket.unplace(int(from.idx)):
			Audio.play("button_tap", -2.0)
			ctx["sel"] = {}
			_repaint(ctx)
			_pop_after(ctx, "OnHandCard_%02d" % (Bucket.hand().size() - 1))   # the spirit settles back into the hand with a pop
	_register_card(ctx, zone)
	grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	zone.add_child(grid)
	var size_zone := func() -> void:
		if is_instance_valid(zone) and is_instance_valid(grid):
			zone.custom_minimum_size = grid.get_combined_minimum_size()
	size_zone.call()
	grid.minimum_size_changed.connect(size_zone)
	zone.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body.add_child(zone)

	# --- EXPEDITION: the acquire entry, moved here from the retired bucket dock ----------------------
	# Gated exactly as the dock's chip was — the loop opens once a completed building grants a cell.
	# Sits at the body's foot rather than in the inspector strip: the strip is selection-contextual,
	# and Expedition is always available once open.
	var on_expedition: Callable = (ctx.opts as Dictionary).get("on_expedition", Callable())
	if on_expedition.is_valid() and cells_total > 0:
		# the flat WHITE/PAPER twin of the green Collect all — identical pill geometry, cream surface (item 6).
		var exped := _action_pill(Kit, "EXPEDITION", true, false)
		exped.name = "ResidentsExpeditionButton"
		exped.pressed.connect(func() -> void:
			Audio.play("button_tap", -2.0)
			var ov: Control = ctx.overlay
			if is_instance_valid(ov):
				ov.queue_free()          # close Residents first — Load out mounts on the same host
			on_expedition.call())
		var erow := HBoxContainer.new()
		erow.alignment = BoxContainer.ALIGNMENT_CENTER
		erow.add_child(exped)
		body.add_child(erow)

	# breathing room so the last hand row scrolls clear of the bottom inspector strip
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(0, INSPECTOR_H + 10.0)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(pad)

## One RESOURCE BANK mini card (mock v2): the LARGE resource icon OWNS the card's left side (spanning
## the name + value block), a thick line-coloured bar spanning the card, and the state line. Full
## banks wear the reward-gold rim. Shadow = the mock's tinted stylebox shadow (follows the corners).
static func _bank_card(Kit: GDScript, line: String, rep: Dictionary, w: float) -> Control:
	var face: Dictionary = LINE_FACE.get(line, {})
	var full := bool(rep.full)
	var card := PanelContainer.new()
	card.name = "ResourceBankCard_" + line
	var sb := StyleBoxFlat.new()
	sb.bg_color = Pal.CREAM.darkened(0.03)
	sb.set_corner_radius_all(int(CELL_CORNER))
	sb.set_border_width_all(3 if full else 0)
	sb.border_color = Pal.STRAW
	sb.content_margin_left = 16; sb.content_margin_right = 16
	sb.content_margin_top = 12; sb.content_margin_bottom = 12
	_mock_shadow(sb)
	card.add_theme_stylebox_override("panel", sb)
	card.custom_minimum_size = Vector2(w, 0)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	# the large icon takes the LEFT side of the card, vertically centred against the text block
	var icon: Control = Kit.make_icon(String(face.get("icon", "leaf")), 96.0)
	icon.custom_minimum_size = Vector2(96.0, 96.0)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(icon)
	var tcol := VBoxContainer.new()
	tcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tcol.alignment = BoxContainer.ALIGNMENT_CENTER
	var nm := Label.new()
	nm.text = String(face.get("label", line)).to_upper()
	nm.add_theme_font_override("font", Kit.bold_font())
	nm.add_theme_font_size_override("font_size", FS.FINE)
	nm.add_theme_color_override("font_color", Pal.INK)
	nm.add_theme_constant_override("outline_size", 0)
	tcol.add_child(nm)
	var val := Label.new()
	val.name = "ResourceBankValue_" + line
	val.text = "%d / %d" % [int(floor(float(rep.pending))), int(round(float(rep.cap)))]
	val.add_theme_font_override("font", Kit.bold_font())
	val.add_theme_font_size_override("font_size", FS.HEADING)
	val.add_theme_color_override("font_color", Pal.INK)
	val.add_theme_constant_override("outline_size", 0)
	tcol.add_child(val)
	top.add_child(tcol)
	col.add_child(top)

	var frac := clampf(float(rep.pending) / maxf(float(rep.cap), 0.001), 0.0, 1.0)
	var bar: Control = Kit.progress_bar(frac, {
		"height": 36.0, "width": 0.0, "art": false,   # chunkier bar per the mock (per-call height; the shared default is untouched)
		"fill_color": face.get("fill", Pal.STRAW),
	})
	# the bar FILLS the card's inner width instead of carrying its own fixed width: a fixed
	# width that overshoots the panel pads inflates the card's minimum past its allotted w,
	# and the grid then pokes past the frame's right clip (the clipped-cards bug).
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.name = "ResourceBankBar_" + line
	col.add_child(bar)

	var state := Label.new()
	state.name = "ResourceBankState_" + line
	state.text = _bank_state_text(line, rep)
	state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	state.add_theme_font_size_override("font_size", FS.FINE)
	state.add_theme_color_override("font_color", Color(Pal.INK, 0.85))
	state.add_theme_constant_override("outline_size", 0)
	col.add_child(state)
	card.add_child(col)
	return card

## The bank's state line: "FULL" · "FULL IN 2H 18M" (rate-derived) · "IDLE" (nothing producing).
static func _bank_state_text(line: String, rep: Dictionary) -> String:
	if bool(rep.full):
		return "FULL"
	var rate := RB.rate(Bucket.state(), line)
	if rate <= 0.0:
		return "IDLE"
	var hours := (float(rep.cap) - float(rep.pending)) / rate
	var mins := int(ceil(hours * 60.0))
	if mins >= 60:
		return "FULL IN %dH %dM" % [mins / 60, mins % 60]
	return "FULL IN %dM" % maxi(mins, 1)

## The two big body actions — Collect all (green) and Expedition (cream/paper, item 6) — are SIBLINGS:
## the SAME flat paper-cut pill_button geometry (corner, font, drop shadow, padding), differing only in
## colour. Routing both through one builder is the only way they read as identical siblings; pill_button's
## green role is the game's standard flat action-green CTA (mock v2's Collect all), its cream role the flat
## white/paper surface (mock v2's Expedition twin).
const ACTION_PILL_CORNER := 22.0
static func _action_pill(Kit: GDScript, text: String, enabled: bool, green: bool) -> Button:
	return Kit.pill_button(text, {
		"bg": "green" if green else "cream",
		"enabled": enabled,
		"font": FS.BODY,
		"corner": ACTION_PILL_CORNER,
		"shadow": true,
	})

## The single collection action — the flat action-green pill (mock v2).
static func _collect_all_button(Kit: GDScript, enabled: bool) -> Button:
	var btn := _action_pill(Kit, "COLLECT ALL", enabled, true)
	btn.name = "CollectAllButton"
	return btn

## THE uniform shadow (skin.gd), applied ON the element's own
## StyleBoxFlat — so it follows the box's exact rounded corners instead of a separate sharp panel.
static func _mock_shadow(sb: StyleBoxFlat) -> void:
	Look.apply_box_shadow(sb)

## Shadow a kit slot cell: the visible face is the inset SlotCellBackground panel — put the mock
## shadow on ITS stylebox (duplicated: slot_cell styleboxes are shared), so the shadow hugs the
## face's real rounded corners.
static func _shadow_cell(cell: Control) -> void:
	var bg := cell.find_child("SlotCellBackground", true, false) as Panel
	if bg == null:
		return
	var sb := bg.get_theme_stylebox("panel")
	if sb is StyleBoxFlat:
		var dsb: StyleBoxFlat = (sb as StyleBoxFlat).duplicate()
		_mock_shadow(dsb)
		bg.add_theme_stylebox_override("panel", dsb)

## A spirit card wrapped in the DragCard input shell: tap selects; hand spirits drag; matching
## targets merge/climb. The kit cell + art underneath is fully mouse-transparent.
static func _spirit_card(ctx: Dictionary, bag_opts: Dictionary, src: String, idx: int,
		line: String, tier: int, px: float) -> Control:
	var Kit: GDScript = ctx.kit
	var kind := Bucket.line_kind(line)
	# the art is now a REAL board piece (holder + contact shadow), not a flat TextureRect — item 3/4.
	var inset := float(ctx.get("piece_inset", PieceView.ITEM_INSET))
	var cell: Control = Kit.slot_cell({"state": "filled",
		"make_content": func(pp: float) -> Control: return _spirit_piece(kind, tier, pp, inset)}, bag_opts)
	cell.custom_minimum_size = Vector2(px, px)
	_ignore_input(cell)
	_shadow_cell(cell)
	if _is_sel(ctx, src, idx):
		var rim := Panel.new()
		rim.name = "SpiritSelectedRim"
		var rsb := StyleBoxFlat.new()
		rsb.bg_color = Color(0, 0, 0, 0)
		rsb.set_border_width_all(4)
		rsb.border_color = Pal.INK
		rsb.set_corner_radius_all(14)
		rim.add_theme_stylebox_override("panel", rsb)
		rim.set_anchors_preset(Control.PRESET_FULL_RECT)
		rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(rim)

	var dc := DragCard.new()
	dc.custom_minimum_size = Vector2(px, px)
	dc.mouse_filter = Control.MOUSE_FILTER_STOP
	dc.data = {"src": src, "idx": idx, "line": line, "tier": tier}
	dc.on_tap = func() -> void:
		ctx["sel"] = {"src": src, "idx": idx}
		_repaint(ctx)
	dc.make_preview = func() -> Control:
		# the drag GHOST is a real board piece, LIFTED via the board's set_lifted — the art rises off a
		# spread contact shadow, the exact pickup feel a board tile has when grabbed.
		var ghost := _spirit_piece(kind, tier, px, inset)
		PieceView.set_lifted(ghost, true)
		ghost.modulate = Color(1, 1, 1, 0.92)
		return ghost
	# a same line+tier spirit dropped HERE merges: hand→hand keeps this slot a tier up;
	# hand→placed climbs the housed spirit.
	dc.can_take = func(from: Dictionary, me: Dictionary) -> bool:
		return String(from.get("src", "")) == "hand" \
			and not (String(me.src) == "hand" and int(from.get("idx", -1)) == int(me.idx)) \
			and String(from.get("line", "")) == String(me.line) and int(from.get("tier", -1)) == int(me.tier)
	dc.on_take = func(from: Dictionary, me: Dictionary) -> void:
		var did := false
		var target := ""
		if String(me.src) == "hand":
			did = Bucket.hand_merge(int(me.idx), int(from.idx))
			target = "OnHandCard_%02d" % int(me.idx)
		else:
			did = Bucket.place_merge(int(from.idx), int(me.idx))
			target = "HabitatCell_%02d" % int(me.idx)
		if did:
			Audio.play("button_tap", -2.0)
			ctx["sel"] = {}
			_repaint(ctx)
			_pop_after(ctx, target)   # the merged tile POPS — the board's produced-tile impact
	_register_card(ctx, dc)
	cell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dc.add_child(cell)
	return dc

## A FREE habitat cell — accepts any hand spirit (Bucket.place moves it in).
static func _free_cell(ctx: Dictionary, bag_opts: Dictionary, px: float) -> Control:
	var Kit: GDScript = ctx.kit
	var cell: Control = Kit.slot_cell({"state": "empty"}, bag_opts)
	cell.custom_minimum_size = Vector2(px, px)
	_ignore_input(cell)
	var dc := DragCard.new()
	dc.custom_minimum_size = Vector2(px, px)
	dc.mouse_filter = Control.MOUSE_FILTER_STOP
	dc.data = {"src": "free"}
	dc.can_take = func(from: Dictionary, _me: Dictionary) -> bool:
		return String(from.get("src", "")) == "hand"
	dc.on_take = func(from: Dictionary, _me: Dictionary) -> void:
		if Bucket.place(int(from.idx)):
			Audio.play("button_tap", -2.0)
			ctx["sel"] = {}
			_repaint(ctx)
			_pop_after(ctx, "HabitatCell_%02d" % (Bucket.placed().size() - 1))   # the newly-housed spirit settles with a pop
	_register_card(ctx, dc)
	cell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dc.add_child(cell)
	return dc

## Register a DragCard as a live drop target and hand it the shared drag context (the ghost layer
## and the registry accessor — read lazily so every card sees the CURRENT rebuild's list).
static func _register_card(ctx: Dictionary, dc: DragCard) -> void:
	dc.drag_layer = ctx.overlay
	dc.targets = func() -> Array:
		return ctx.get("cards", [])
	(ctx["cards"] as Array).append(dc)

## The spirit's per-tier ladder art, centred in its box — TRIMMED to its used rect (the raw canvas
## carries transparent padding that would shrink the sprite), cached per path like the map dock.
static var _art_cache: Dictionary = {}
static func _spirit_tex(path: String) -> Texture2D:
	if _art_cache.has(path):
		return _art_cache[path]
	var tex: Texture2D = load(path)
	var result: Texture2D = tex
	if tex != null:
		var img := tex.get_image()
		if img != null:
			var used := img.get_used_rect()
			var full := Vector2i(tex.get_width(), tex.get_height())
			if used.size.x > 0 and used.size.y > 0 and (used.position != Vector2i.ZERO or used.size != full):
				var at := AtlasTexture.new()
				at.atlas = tex
				at.region = Rect2(used)
				result = at
	_art_cache[path] = result
	return result

## The resident cell's ART, rendered through the SHARED board pipeline (PieceView.make_piece_from_texture):
## a cell-sized holder carrying the board's CONTACT SHADOW under the centered sprite, at the board's own
## ITEM_INSET — so a habitat / hand cell grounds and LIFTS (set_lifted) exactly like a board tile, and any
## future board-cell change propagates here for free. Resident art resolves via G.resident_art (a path,
## not a board item code), so it goes through the texture seam rather than make_piece(code,...).
## The board item's inset, read from the SAME source the live board resolves (bag_card.content_frac,
## via PieceView.board_item_inset) — so a habitat / hand cell frames its art exactly like a board cell,
## at the same fill %, including when the workbench knob is retuned. (The dialog's slot_cell content_frac
## stays 1.0 so the piece spans the full cell; this inset alone governs the margin, as on the board.)
static func _board_piece_inset(cfg: Dictionary) -> float:
	return PieceView.board_item_inset(cfg)

static func _spirit_piece(kind: String, tier: int, px: float, inset: float = PieceView.ITEM_INSET) -> Control:
	var art := G.resident_art(kind, tier)
	var tex: Texture2D = _spirit_tex(art) if (art != "" and ResourceLoader.exists(art)) else null
	return PieceView.make_piece_from_texture(tex, px, inset)

## Pop a just-rebuilt cell by name (the board's produced-tile impact). Deferred one frame so the repaint's
## fresh node exists AND has its rect (FX.pop centres on the node's size).
static func _pop_after(ctx: Dictionary, cell_name: String) -> void:
	var body: Control = ctx.get("body")
	if body == null or not is_instance_valid(body):
		return
	(func() -> void:
		if is_instance_valid(body):
			var n := body.find_child(cell_name, true, false)
			if n is Control:
				FX.pop(n)).call_deferred()

static func _spirit_art(kind: String, tier: int, px: float) -> Control:
	var t := TextureRect.new()
	t.custom_minimum_size = Vector2(px, px)
	t.size = Vector2(px, px)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art := G.resident_art(kind, tier)
	if art != "" and ResourceLoader.exists(art):
		t.texture = _spirit_tex(art)
	return t

## The bottom inspector CONTENT (the flat strip itself is built once in open()): the selected
## spirit's portrait + name + info + a big SELL — or a quiet hint when nothing is selected.
## The strip sits OUTSIDE the frame's ScaleContainer, so px sizes here scale by ctx.scale.
static func _rebuild_inspector(ctx: Dictionary) -> void:
	var insp: PanelContainer = ctx.insp
	var Kit: GDScript = ctx.kit
	var s: float = ctx.scale
	_clear(insp)
	var sel: Dictionary = ctx.get("sel", {})
	var inst := _sel_inst(sel)
	if inst.is_empty():
		var hint := Label.new()
		hint.name = "ResidentsInspectorHint"
		hint.text = "Tap a resident"
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hint.add_theme_font_size_override("font_size", int(FS.FINE * s))
		hint.add_theme_color_override("font_color", Color(Pal.INK, 0.65))
		hint.add_theme_constant_override("outline_size", 0)
		insp.add_child(hint)
		return

	var line := String(inst.line)
	var tier := int(inst.tier)
	var kind := Bucket.line_kind(line)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(12.0 * s))
	var portrait := _spirit_art(kind, tier, 68.0 * s)
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(portrait)
	var nm := Label.new()
	nm.name = "ResidentsInspectorName"
	nm.text = "%s · T%d" % [_kind_name(kind), tier]
	nm.add_theme_font_override("font", Kit.bold_font())
	nm.add_theme_font_size_override("font_size", int(FS.BODY * s))
	nm.add_theme_color_override("font_color", Pal.INK)
	nm.add_theme_constant_override("outline_size", 0)
	nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(nm)
	var on_info: Callable = (ctx.opts as Dictionary).get("on_info", Callable())
	if on_info.is_valid():
		var info := Button.new()
		info.name = "ResidentsInfoButton"
		info.flat = true
		info.focus_mode = Control.FOCUS_NONE
		var empty := StyleBoxEmpty.new()
		for st in ["normal", "hover", "pressed", "focus", "disabled"]:
			info.add_theme_stylebox_override(st, empty)
		var ipx := 44.0 * s
		info.custom_minimum_size = Vector2(ipx, ipx)
		var ii: Control = Kit.make_icon("info", ipx * 0.86)
		ii.position = Vector2(ipx * 0.07, ipx * 0.07)
		ii.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info.add_child(ii)
		info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		info.pressed.connect(func() -> void: on_info.call(kind, tier))
		row.add_child(info)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(gap)
	# NOTE: the "Bring out" pill is retired (spec 2026-07-19) — placed spirits no longer have a tap-to-hand
	# path (drag a placed spirit onto the hand zone to unplace it). Only Sell remains in the strip.
	# SELL — the coral-outline pill (mock), sized as the strip's dominant action; carries the coin icon (item 8).
	var sell := _inspector_pill(Kit, s, "SELL +%d" % (Bucket.SELL_PER_TIER * tier), Pal.CLAY, "coin")
	sell.name = "ResidentsSellButton"
	sell.pressed.connect(func() -> void:
		Audio.play("button_tap", -2.0)
		if String(sel.get("src", "")) == "placed":
			Bucket.sell_placed(int(sel.get("idx", -1)))
		else:
			Bucket.sell_hand(int(sel.get("idx", -1)))
		ctx["sel"] = {}
		_repaint(ctx))
	row.add_child(sell)
	insp.add_child(row)

# --- small helpers --------------------------------------------------------------------------------
## One inspector-strip action pill: the cream face with a coloured outline and matching label. The
## colour is the whole difference between Sell (coral) and Bring out (meadow green).
static func _inspector_pill(Kit: GDScript, s: float, text: String, accent: Color, icon_id: String = "") -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", Kit.bold_font())
	b.add_theme_font_size_override("font_size", int(FS.BODY * s))
	b.add_theme_color_override("font_color", accent)
	b.add_theme_constant_override("outline_size", 0)
	# an optional leading currency icon (Sell prepends the coin) — the SAME square-icon + icon_max_width
	# path the kit's currency pills use, so the coin renders identically to the rest of the UI.
	if icon_id != "":
		var itex: Texture2D = Kit._square_icon(icon_id)
		if itex != null:
			b.icon = itex
			b.add_theme_constant_override("icon_max_width", int(FS.BODY * s))
			b.add_theme_constant_override("h_separation", int(8.0 * s))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Pal.CREAM
	sb.set_corner_radius_all(int(18.0 * s))
	sb.set_border_width_all(int(maxf(3.0, 4.0 * s)))
	sb.border_color = accent
	sb.content_margin_left = 26.0 * s; sb.content_margin_right = 26.0 * s
	sb.content_margin_top = 10.0 * s; sb.content_margin_bottom = 10.0 * s
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, sb)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return b

static func _section_label(Kit: GDScript, text: String) -> Label:
	var l := Label.new()
	l.text = text.to_upper()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", Kit.bold_font())
	l.add_theme_font_size_override("font_size", FS.FINE)
	l.add_theme_color_override("font_color", Pal.INK)
	l.add_theme_constant_override("outline_size", 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## Make a built kit cell fully mouse-transparent so the DragCard wrapper owns all input.
static func _ignore_input(n: Node) -> void:
	if n is Control:
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		(n as Control).focus_mode = Control.FOCUS_NONE
	for c in n.get_children():
		_ignore_input(c)

static func _is_sel(ctx: Dictionary, src: String, idx: int) -> bool:
	var sel: Dictionary = ctx.get("sel", {})
	return String(sel.get("src", "")) == src and int(sel.get("idx", -1)) == idx

## The live instance behind the selection — {} when the selection is stale (sold/moved under it).
static func _sel_inst(sel: Dictionary) -> Dictionary:
	var idx := int(sel.get("idx", -1))
	match String(sel.get("src", "")):
		"hand":
			var h := Bucket.hand()
			return h[idx] if idx >= 0 and idx < h.size() else {}
		"placed":
			var p := Bucket.placed()
			return p[idx] if idx >= 0 and idx < p.size() else {}
	return {}

## The spirit family's display name (grove_data.RESIDENT_LINES carries {id, name} per map).
static func _kind_name(kind: String) -> String:
	for ln in D.RESIDENT_LINES.values():
		if String(ln.get("id", "")) == kind:
			return String(ln.get("name", kind))
	return kind.capitalize()
