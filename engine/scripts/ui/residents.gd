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
const Design = preload("res://engine/scripts/core/design.gd")   # THE design-viewport owner — never re-type 1080×1920
const Game = preload("res://engine/scripts/core/game.gd")
const G = preload("res://engine/scripts/core/content.gd")
const Bucket = preload("res://engine/scripts/core/bucket.gd")
const RB = preload("res://engine/scripts/core/resident_bucket.gd")
const Audio = preload("res://engine/scripts/core/audio.gd")
const Overlay = preload("res://engine/scripts/ui/overlay.gd")
const Look = preload("res://engine/scripts/ui/skin.gd")
const FX = preload("res://engine/scripts/ui/fx.gd")
const PieceView = preload("res://engine/scripts/ui/piece_view.gd")   # the SHARED board cell (holder + contact shadow + lift)
const GridFx = preload("res://engine/scripts/ui/grid_fx.gd")         # the SHARED merge/slide-land feel owner
const FS = preload("res://engine/scripts/core/tuning.gd").FontScale
const Pal = Game.PALETTE
const D = Game.DATA

const OVERLAY_NAME := "ResidentsOverlay"
static var KIT_PATH := Game.kit()
# Resident-specific body sprites extracted from the residents mock. The outer dialog frame stays owned by
# the shared kit so it matches Mail/Daily/Settings instead of drawing a second sheet.
const SpritePanel = preload("res://engine/scripts/ui/sprite_panel.gd")
const SpriteButton = preload("res://engine/scripts/ui/sprite_button.gd")
static var SKIN_DIR := Look.kit("dialogs/residents/")
static func _skin_tex(key: String) -> Texture2D:
	var p := SKIN_DIR + key + ".png"
	return load(p) as Texture2D if ResourceLoader.exists(p) else null
const HAND_COLS := 4
const HABITAT_SLOTS_SHOWN := 5      # the mock's fixed row: granted cells first, the rest locked
const INSPECTOR_H := 104.0          # the bottom strip's height in DESIGN units
const CELL_CORNER := 16.0           # the resident/bank card corner the shared shadow hugs
# Height-cap the width-authored resident surface on short aspect ratios so the fixed banks,
# habitat and pinned actions still leave one complete On-hand row. At a design-width × 1200
# window this applies a modest 1200/1440 scale; taller phones keep the normal shared-frame
# width scale. The reference WIDTH is the design canvas itself — read from Design, never re-typed.
const HEIGHT_SCALE_REFERENCE := 1440.0
static var HEIGHT_SCALE_REFERENCE_W := Design.size().x

# Per-line chrome: icon id + display name + the bank bar's fill colour (Meadow Sky roles).
const LINE_FACE := {
	"coin":    {"icon": "coin",  "label": "Coins",    "fill": Pal.GOLD},
	"water":   {"icon": "water", "label": "Water",    "fill": Pal.SKY},
	"boost":   {"icon": "star",  "label": "Boost",    "fill": Pal.LEAF},
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
	var blockers: Callable = Callable()     # () -> Array of pinned controls that cover drop targets
	var drag_layer: Control = null          # the overlay the ghost rides (above the dialog)
	var scroll_owner: ScrollContainer = null # hand cards arbitrate touch swipes with this viewport
	var _down := false
	var _dragging := false
	var _scrolling := false
	var _touch_down := false
	var _down_ms := 0
	var _down_gp := Vector2.ZERO
	var _last_gp := Vector2.ZERO
	var _ghost: Control = null
	const TOUCH_DRAG_HOLD_MS := 220
	const TOUCH_SCROLL_AXIS_BIAS := 1.15

	## With emulate_touch_from_mouse BOTH the mouse event and its emulated touch arrive — the
	## _down/_dragging flags make the second press/release of a pair a no-op.
	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			_press(_gp(ev.position), false) if (ev as InputEventMouseButton).pressed else _release(_gp(ev.position))
			accept_event()
		elif ev is InputEventScreenTouch:
			_press(_gp(ev.position), true) if (ev as InputEventScreenTouch).pressed else _release(_gp(ev.position))
			accept_event()
		elif (ev is InputEventMouseMotion or ev is InputEventScreenDrag) and _down:
			_move(_gp(ev.position))
			accept_event()

	## _gui_input positions are LOCAL — the drag runs in global space.
	func _gp(local: Vector2) -> Vector2:
		return get_global_transform() * local

	func _press(gp: Vector2, touch: bool) -> void:
		if _down:
			return
		_down = true
		_dragging = false
		_scrolling = false
		_touch_down = touch
		_down_ms = Time.get_ticks_msec()
		_down_gp = gp
		_last_gp = gp

	func _move(gp: Vector2) -> void:
		var delta := gp - _last_gp
		_last_gp = gp
		var travel := gp - _down_gp
		if not _dragging and not _scrolling and travel.length() > DRAG_START_PX:
			# A quick vertical finger gesture belongs to the hand scroller. Holding briefly first
			# claims the resident instead, preserving vertical hand→Habitat placement on touch.
			var quick_touch_scroll := _touch_down and _can_scroll() \
				and Time.get_ticks_msec() - _down_ms < TOUCH_DRAG_HOLD_MS \
				and absf(travel.y) > absf(travel.x) * TOUCH_SCROLL_AXIS_BIAS
			if quick_touch_scroll:
				_scrolling = true
			elif String(data.get("src", "")) in ["hand", "placed"]:
				_dragging = true
				if make_preview.is_valid() and drag_layer != null and is_instance_valid(drag_layer):
					_ghost = make_preview.call()
					_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
					drag_layer.add_child(_ghost)
		if _scrolling and scroll_owner != null and is_instance_valid(scroll_owner):
			var sy := maxf(0.01, absf(get_global_transform().get_scale().y))
			scroll_owner.scroll_vertical -= int(roundf(delta.y / sy))
			return
		if _dragging and _ghost != null and is_instance_valid(_ghost):
			_auto_scroll_drag(gp)
			_ghost.global_position = gp - _ghost.size * 0.5

	# A hand resident can start in one row and merge/place against content beyond the current row.
	# Moving the held resident through a viewport edge scrolls toward that target; the drop resolver
	# still accepts only cards that are actually visible when the finger/mouse is released.
	func _auto_scroll_drag(gp: Vector2) -> void:
		if scroll_owner == null or not is_instance_valid(scroll_owner) or not _can_scroll():
			return
		var rect := scroll_owner.get_global_rect()
		var sy := maxf(0.01, absf(get_global_transform().get_scale().y))
		var edge := minf(rect.size.y * 0.25, 44.0 * sy)
		var delta_scroll := 0
		if gp.y < rect.position.y + edge:
			delta_scroll = -maxi(4, int(ceil((rect.position.y + edge - gp.y) / sy)))
		elif gp.y > rect.end.y - edge:
			delta_scroll = maxi(4, int(ceil((gp.y - (rect.end.y - edge)) / sy)))
		if delta_scroll != 0:
			scroll_owner.scroll_vertical += delta_scroll

	func _can_scroll() -> bool:
		if scroll_owner == null or not is_instance_valid(scroll_owner):
			return false
		var bar := scroll_owner.get_v_scroll_bar()
		return bar != null and bar.max_value > bar.page + 0.5

	func _release(gp: Vector2) -> void:
		if not _down:
			return
		var was_drag := _dragging
		var was_scroll := _scrolling
		_down = false
		_dragging = false
		_scrolling = false
		_touch_down = false
		if _ghost != null and is_instance_valid(_ghost):
			_ghost.queue_free()
		_ghost = null
		# resolve LAST: on_take/on_tap repaint the dialog, which queue_frees this very card.
		if was_drag:
			var t := _target_at(gp)
			if t != null and t.on_take.is_valid():
				t.on_take.call(data, t.data)
		elif not was_scroll:
			tap()

	## The first registered card under `gp` that ACCEPTS this payload — rejecting targets fall
	## through, so a placed spirit dropped over a hand card still reaches the hand zone behind it.
	func _target_at(gp: Vector2) -> DragCard:
		if not targets.is_valid():
			return null
		for c in targets.call():
			if c != self and c != null and is_instance_valid(c) \
					and _is_visible_at(c, gp) \
					and c.can_take.is_valid() and bool(c.can_take.call(data, c.data)):
				return c
		return null

	func _is_visible_at(c: DragCard, gp: Vector2) -> bool:
		if not (c as Control).get_global_rect().has_point(gp):
			return false
		if c.scroll_owner != null and is_instance_valid(c.scroll_owner) \
				and not c.scroll_owner.get_global_rect().has_point(gp):
			return false
		var n: Node = c
		while n is Control:
			var ctl := n as Control
			if not ctl.is_visible_in_tree() or (ctl.clip_contents and not ctl.get_global_rect().has_point(gp)):
				return false
			n = n.get_parent()
		if blockers.is_valid():
			for blocker in blockers.call():
				if blocker is Control and is_instance_valid(blocker) \
						and (blocker as Control).is_visible_in_tree() \
						and (blocker as Control).get_global_rect().has_point(gp):
					return false
		return true

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

	var modal := Overlay.modal(host, OVERLAY_NAME)
	var overlay: Control = modal["overlay"]
	var cc: CenterContainer = modal["center"]

	var cfg: Dictionary = Kit.load_config(Kit.CONFIG_PATH)
	var viewport_size := host.get_viewport_rect().size
	var vw: float = viewport_size.x
	var width: float = vw * Kit.DIALOG_DESIGN_PCT["residents"] / 100.0
	# the CONTENT lays out at the design width MINUS the sheet's insets AND the scrollbar
	# (the frame scales it by content_scale, so those real-px widths count at 1/scale in
	# layout space) — sized against `width` alone the fixed-size cards overflow the sheet's
	# right edge; the scroll's vertical bar, when shown, eats its width from the child area.
	var width_scale: float = maxf(0.01, Kit.dialog_content_scale(cfg, "residents"))
	# Canvas-items stretch keeps the logical viewport 1920 px tall and widens it on short devices,
	# so viewport_size.y alone cannot detect a physically short screen. Normalize the real window's
	# aspect to a 1080-wide phone, then cap the content scale only when that equivalent height is short.
	var window_size := Vector2(DisplayServer.window_get_size())
	var aspect_height := window_size.y * HEIGHT_SCALE_REFERENCE_W / maxf(1.0, window_size.x)
	var scale: float = minf(width_scale, maxf(0.01, aspect_height / HEIGHT_SCALE_REFERENCE))
	var inner: float = width \
		- (2.0 * float(Kit.frame_border("parchment")["pad_x"]) + float(Kit.SCROLLBAR_W)) / scale

	# the render context every repaint reads: selection + the two rebuildable surfaces.
	var ctx := {"sel": {}, "body": null, "insp": null, "scale": scale,
		"kit": Kit, "cfg": cfg, "inner": inner, "overlay": overlay, "opts": opts,
		"piece_inset": _board_piece_inset(cfg), "fx": GridFx.opts_from_config(cfg),
		"hand_scroll_pos": 0, "drop_blockers": []}

	var body := VBoxContainer.new()
	body.name = "ResidentsBody"
	body.add_theme_constant_override("separation", 14)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ctx["body"] = body

	var fopts: Dictionary = Kit.dialog_opts_from_config(cfg)
	fopts["banner_text"] = "Residents"
	fopts["content_scale"] = scale
	# tuck the ✕ further in so it sits inside the torn panel's rounded corner (the deckled cut-paper edge
	# is more inset than the plain rounded-rect the default close_poke was tuned for).
	fopts["close_poke"] = Vector2(40, 34)
	var list_max_h: float = viewport_size.y * 0.82
	fopts["list_max_h"] = list_max_h   # taller sheet: the board-sized cells (items 3/4) need the extra height budget
	fopts["on_close"] = func() -> void:
		if is_instance_valid(overlay):
			overlay.queue_free()

	# Expedition and the selection inspector are ONE shared-frame footer, so both stay pinned while
	# only the On-hand grid scrolls. The footer lives outside the content ScaleContainer; its controls
	# therefore use real-pixel dimensions derived from `scale`.
	var footer := VBoxContainer.new()
	footer.name = "ResidentsPinnedFooter"
	footer.add_theme_constant_override("separation", int(8.0 * scale))
	footer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var on_expedition: Callable = (opts as Dictionary).get("on_expedition", Callable())
	if on_expedition.is_valid() and Bucket.cells_total() > 0:
		var exped := _action_pill(Kit, "EXPEDITION", true, false, scale)
		exped.name = "ResidentsExpeditionButton"
		exped.pressed.connect(func() -> void:
			Audio.play("button_tap", -2.0)
			if is_instance_valid(overlay):
				overlay.queue_free()
			on_expedition.call())
		var erow := HBoxContainer.new()
		erow.alignment = BoxContainer.ALIGNMENT_CENTER
		erow.add_child(exped)
		footer.add_child(erow)

	var insp := PanelContainer.new()
	insp.name = "ResidentsInspector"
	insp.custom_minimum_size = Vector2(0, INSPECTOR_H * scale)
	insp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	insp.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	footer.add_child(insp)
	ctx["insp"] = insp
	var footer_gap := 8.0 * scale
	fopts["footer"] = footer
	fopts["footer_gap"] = footer_gap
	fopts["outer_scroll_enabled"] = false
	fopts["footer_reduces_viewport"] = true
	# dialog_frame's row cap is in rendered pixels. Reserve the pinned footer and shared tail,
	# then hand the remaining authored height to _rebuild_body for a whole-row hand viewport.
	var footer_h := footer.get_combined_minimum_size().y + footer_gap
	ctx["body_budget"] = maxf(0.0, (list_max_h - float(Kit.CONTENT_TAIL_PAD) - footer_h) / scale)

	var dialog: Control = Kit.dialog_frame(body, width, fopts)
	cc.add_child(dialog)
	var footer_band: Control = dialog.find_child("DialogFooterBand", true, false)
	if footer_band != null:
		ctx["drop_blockers"] = [footer_band]

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
	var old_scroll := body.find_child("ResidentsHandScroll", true, false) as ScrollContainer
	if old_scroll != null:
		ctx["hand_scroll_pos"] = old_scroll.scroll_vertical
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
	# the empty (available) + locked cells are the shared code-drawn TORN CELL component (the same one the
	# bag dialog + workbench use) — torn_cell_opts carries its knobs, torn_cells flips slot_cell onto it.
	var torn_opts: Dictionary = bag_opts.duplicate(true)
	torn_opts.merge(Kit.torn_cell_opts_from_config(cfg), true)
	torn_opts["torn_cells"] = true
	var placed: Array = Bucket.placed()
	var cells_total: int = Bucket.cells_total()
	var slots: int = maxi(HABITAT_SLOTS_SHOWN, cells_total)
	# the cells WRAP at HABITAT_SLOTS_SHOWN per row: sized against the row width (not the slot count),
	# a late-game habitat keeps mock-sized cells and grows downward instead of shrinking to slivers.
	var cell_px: float = (width - 10.0 * float(HABITAT_SLOTS_SHOWN - 1)) / float(HABITAT_SLOTS_SHOWN)
	# EVERY habitat cell is the shared torn cell: a placed resident sits IN the open green well (filled), a
	# free cell is the empty green well, a locked cell is the cream card + lock. content_frac fills the well
	# with the resident like a board tile; it's inert on the empty/locked cells.
	var cbag: Dictionary = torn_opts.duplicate(true)
	cbag["cell_w"] = cell_px
	cbag["cell_h"] = cell_px
	cbag["content_frac"] = 1.0
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
			# the locked cell is the shared TORN CELL component's locked state (cream cut-paper card + centred
			# lock over its own shape-true shadow) — no baked keyhole sprite.
			cell = Kit.slot_cell({"state": "locked"}, cbag)
			cell.custom_minimum_size = Vector2(cell_px, cell_px)
			cell.name = "HabitatCellLocked_%02d" % i
		cells.add_child(cell)
	body.add_child(cells)

	# --- ON HAND: the 4-column tap-to-select / drag-to-merge grid -----------------------------------
	body.add_child(_section_label(Kit, "On hand"))
	var hand: Array = Bucket.hand()
	var hand_px: float = cell_px   # the hand tiles are the SAME size as the habitat cells (not the wider 4-up fill)
	var hbag: Dictionary = cbag.duplicate(true)   # hand tiles = the same torn cells as the habitat (well + resident)
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
		# empty filler tiles are the torn AVAILABLE cell — the same open cut-paper well as an empty habitat
		# cell, so the ON HAND grid reads as the same tile family as HABITAT CELLS.
		var filler: Control = Kit.slot_cell({"state": "empty"}, hbag)
		grid.add_child(filler)
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
	# Only ON HAND scrolls. It consumes the body's flexible remainder, keeps at least one complete row
	# visible, and grows naturally on taller screens until the hand itself becomes the overflow.
	# The surrounding frame still owns clipping/chrome, but its body now fits its visible height budget.
	var hand_scroll := ScrollContainer.new()
	hand_scroll.name = "ResidentsHandScroll"
	hand_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	hand_scroll.scroll_deadzone = int(DragCard.DRAG_START_PX)
	# Allocate only complete rows inside the remaining fixed-body budget. At least one full row
	# remains visible; taller screens expose more rows until the whole hand fits.
	var fixed_h := body.get_combined_minimum_size().y + 14.0
	var available_h := maxf(hand_px, float(ctx.get("body_budget", hand_px)) - fixed_h)
	var rows_fit := maxi(1, int(floor((available_h + 10.0) / (hand_px + 10.0))))
	var visible_h := minf(zone.get_combined_minimum_size().y,
		float(rows_fit) * hand_px + float(maxi(0, rows_fit - 1)) * 10.0)
	hand_scroll.custom_minimum_size = Vector2(width, visible_h)
	hand_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Kit._style_scrollbar(hand_scroll)
	hand_scroll.add_child(zone)
	body.add_child(hand_scroll)
	for registered in ctx["cards"]:
		var resident_card := registered as DragCard
		if resident_card != null and String(resident_card.data.get("src", "")) in ["hand", "handzone"]:
			resident_card.scroll_owner = hand_scroll
	var restore_pos := int(ctx.get("hand_scroll_pos", 0))
	(func() -> void:
		if is_instance_valid(hand_scroll):
			var bar := hand_scroll.get_v_scroll_bar()
			var max_scroll := maxi(0, int(floor(bar.max_value - bar.page))) if bar != null else 0
			hand_scroll.scroll_vertical = clampi(restore_pos, 0, max_scroll)
	).call_deferred()

## One RESOURCE BANK mini card (mock v2): the LARGE resource icon OWNS the card's left side (spanning
## the name + value block), a thick line-coloured bar spanning the card, and the state line. Full
## banks wear the reward-gold rim. Shadow = the mock's tinted stylebox shadow (follows the corners).
static func _bank_card(Kit: GDScript, line: String, rep: Dictionary, w: float) -> Control:
	var face: Dictionary = LINE_FACE.get(line, {})
	var frac := clampf(float(rep.pending) / maxf(float(rep.cap), 0.001), 0.0, 1.0)
	# the baked per-line card sprite (resource icon already in the left well; ONE plain cream look for
	# every card — no gold "ready" variant). The game only draws NAME · COUNT · BAR · STATE over the body.
	var card_tex := _skin_tex("card_" + line)
	if card_tex == null:
		return _bank_card_drawn(Kit, line, rep, w)   # fallback to the drawn card if the sprite is missing

	# height follows the sprite aspect so it isn't squashed; custom_minimum_size stays (w, h) so the card
	# fits its grid slot.
	var aspect := float(card_tex.get_width()) / float(card_tex.get_height())
	var h := roundf(w / maxf(aspect, 0.1))
	# the card sprite over a drop shadow shaped from the card's OWN silhouette (card_shadow.png — a blurred
	# black copy of the torn card outline) instead of a generic rounded rect, so the shadow hugs the card's
	# real deckled edge + corners.
	var card := SpritePanel.build(card_tex, Vector2(w, h), {"shadow": false})
	card.name = "ResourceBankCard_" + line
	card.custom_minimum_size = Vector2(w, h)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_silhouette_shadow(card, w, h)

	# the text + bar live ONLY on the RIGHT side of the card, clear of the baked icon well (which fills
	# the left ~45%). BODY_L is the left edge of that right region as a fraction of the card width.
	var body_l := 0.52
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", roundf(h * 0.03))
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.position = Vector2(w * body_l, h * 0.12)
	body.size = Vector2(w * (0.96 - body_l), h * 0.76)
	body.custom_minimum_size = body.size

	var nm := Label.new()
	nm.text = String(face.get("label", line)).to_upper()
	nm.clip_text = true   # a wide text must never grow the body box (it would stretch the bar past the card)
	nm.add_theme_font_override("font", Kit.bold_font())
	nm.add_theme_font_size_override("font_size", FS.BODY)   # larger title per the mock
	nm.add_theme_color_override("font_color", Pal.INK)
	nm.add_theme_constant_override("outline_size", 0)
	body.add_child(nm)

	var val := Label.new()
	val.name = "ResourceBankValue_" + line
	val.text = "%d / %d" % [int(floor(float(rep.pending))), int(round(float(rep.cap)))]
	val.clip_text = true
	val.add_theme_font_override("font", Kit.bold_font())
	val.add_theme_font_size_override("font_size", FS.HEADING)
	val.add_theme_color_override("font_color", Pal.INK)
	val.add_theme_constant_override("outline_size", 0)
	body.add_child(val)

	var bar: Control
	var track := _skin_tex("bar_track")
	var fill := _skin_tex("bar_fill")
	if track != null and fill != null:
		bar = SpritePanel.progress(track, fill, frac, Vector2(w * (0.96 - body_l), maxf(14.0, h * 0.15)))
	else:
		bar = Kit.progress_bar(frac, {"height": 30.0, "width": 0.0, "art": false, "fill_color": face.get("fill", Pal.STRAW)})
	bar.name = "ResourceBankBar_" + line
	body.add_child(bar)

	var state := Label.new()
	state.name = "ResourceBankState_" + line
	state.text = _bank_state_text(line, rep)
	state.clip_text = true   # ditto — the countdown line stays inside the card at any length
	state.add_theme_font_size_override("font_size", FS.FINE)
	state.add_theme_color_override("font_color", Color(Pal.INK, 0.85))
	state.add_theme_constant_override("outline_size", 0)
	body.add_child(state)

	card.add_child(body)
	return card

## The pre-reskin drawn bank card (kept as the fallback when the sprite assets are absent).
static func _bank_card_drawn(Kit: GDScript, line: String, rep: Dictionary, w: float) -> Control:
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
		"height": 36.0, "width": 0.0, "art": false,
		"fill_color": face.get("fill", Pal.STRAW),
	})
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

## The bank's state line: "FULL" · "2H 18M" (time to full, rate-derived) · "IDLE" (nothing producing).
## The bare countdown (no "FULL IN" prefix) keeps the line inside the card at every rate.
static func _bank_state_text(line: String, rep: Dictionary) -> String:
	if bool(rep.full):
		return "FULL"
	var rate := RB.rate(Bucket.state(), line)
	if rate <= 0.0:
		return "IDLE"
	var hours := (float(rep.cap) - float(rep.pending)) / rate
	var mins := int(ceil(hours * 60.0))
	if mins >= 60:
		return "%dH %dM" % [mins / 60, mins % 60]
	return "%dM" % maxi(mins, 1)

## The two big body actions — Collect all (green) and Expedition (cream/paper, item 6) — are SIBLINGS:
## the SAME flat paper-cut pill_button geometry (corner, font, drop shadow, padding), differing only in
## colour. Routing both through one builder is the only way they read as identical siblings; pill_button's
## green role is the game's standard flat action-green CTA (mock v2's Collect all), its cream role the flat
## white/paper surface (mock v2's Expedition twin).
const ACTION_PILL_CORNER := 22.0
const ACTION_PILL_H := 76.0    # reskinned button height (design px); width follows the sprite's aspect
static func _action_pill(Kit: GDScript, text: String, enabled: bool, green: bool,
		ui_scale: float = 1.0) -> Button:
	# reskin: the baked cut-paper button sprite (COLLECT ALL = green, EXPEDITION = cream) over the shared
	# drop shadow. The caller wires `.pressed` after, so the button stays a real tap target.
	var tex := _skin_tex("btn_collect" if green else "btn_expedition")
	if tex != null and tex.get_height() > 0:
		var h := ACTION_PILL_H * ui_scale
		var w := roundf(h * float(tex.get_width()) / float(tex.get_height()))
		var b := SpriteButton.build(tex, Vector2(w, h), Callable(), {"tooltip": text})
		b.mouse_filter = Control.MOUSE_FILTER_STOP   # tappable even though the action is wired later
		b.disabled = not enabled
		b.modulate = Color(1, 1, 1, 1) if enabled else Color(1, 1, 1, 0.5)
		return b
	return Kit.pill_button(text, {
		"bg": "green" if green else "cream",
		"enabled": enabled,
		"font": int(FS.BODY * ui_scale),
		"corner": ACTION_PILL_CORNER * ui_scale,
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

## A drop shadow shaped from the card's OWN silhouette (card_shadow.png — a pre-blurred black copy of the
## torn card outline, centred with a transparent blur margin) rather than a generic rounded rect, so the
## shadow hugs the deckled edge. Inserted BEHIND the card sprite, extended to cover the blur margin and
## nudged down. No-op when the sprite is missing.
const CARD_SHADOW_PAD := 54.0    # the blur margin baked around card_shadow.png (per side, source px)
const CARD_SHADOW_REF := Vector2(493.0, 306.0)   # the card size card_shadow.png was authored against
static func _add_silhouette_shadow(card: Control, w: float, h: float) -> void:
	var tex := _skin_tex("card_shadow")
	if tex == null:
		return
	var px := w * (CARD_SHADOW_PAD / CARD_SHADOW_REF.x)
	var py := h * (CARD_SHADOW_PAD / CARD_SHADOW_REF.y)
	var drop := h * 0.05
	var sh := TextureRect.new()
	sh.name = "CardSilhouetteShadow"
	sh.texture = tex
	sh.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sh.stretch_mode = TextureRect.STRETCH_SCALE
	sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sh.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sh.offset_left = -px; sh.offset_right = px
	sh.offset_top = -py + drop; sh.offset_bottom = py + drop
	card.add_child(sh)
	card.move_child(sh, 0)   # behind the card sprite layer

## A spirit card wrapped in the DragCard input shell: tap selects; hand spirits drag; matching
## targets merge/climb. The kit cell + art underneath is fully mouse-transparent.
static func _spirit_card(ctx: Dictionary, bag_opts: Dictionary, src: String, idx: int,
		line: String, tier: int, px: float) -> Control:
	var Kit: GDScript = ctx.kit
	var kind := Bucket.line_kind(line)
	# the art is now a REAL board piece (holder + contact shadow), not a flat TextureRect — item 3/4.
	var inset := float(ctx.get("piece_inset", PieceView.ITEM_INSET))
	# the resident sits IN the shared torn cell's open green well (bag_opts carries torn_cells) — placed and
	# on-hand alike, so a spirit reads as housed in an available cell rather than floating on a plain tile.
	var cell: Control = Kit.slot_cell({"state": "filled",
		"make_content": func(pp: float) -> Control: return _spirit_piece(kind, tier, pp, inset)}, bag_opts)
	cell.custom_minimum_size = Vector2(px, px)
	_ignore_input(cell)
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
			_merge_after(ctx, target, int(me.tier) + 1)   # the board's real merge celebration, one owner (GridFx)
	_register_card(ctx, dc)
	cell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dc.add_child(cell)
	return dc

## A FREE habitat cell — accepts any hand spirit (Bucket.place moves it in).
static func _free_cell(ctx: Dictionary, bag_opts: Dictionary, px: float) -> Control:
	var Kit: GDScript = ctx.kit
	var cell: Control = Kit.slot_cell({"state": "empty"}, bag_opts)   # torn AVAILABLE cell (open cut-paper well)
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
	dc.blockers = func() -> Array:
		return ctx.get("drop_blockers", [])
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

## Pop a just-rebuilt cell by name (a plain settle impact for a move-in / snap-back). Deferred one frame
## so the repaint's fresh node exists AND has its rect (FX.pop centres on the node's size).
static func _pop_after(ctx: Dictionary, cell_name: String) -> void:
	var body: Control = ctx.get("body")
	if body == null or not is_instance_valid(body):
		return
	(func() -> void:
		if is_instance_valid(body):
			var n := body.find_child(cell_name, true, false)
			if n is Control:
				FX.pop(n)).call_deferred()

## A MERGE settled at `cell_name` producing `tier`: play the board's exact merge celebration through the
## shared GridFx owner (dialog-trimmed — no screen shake / board punch / world puff / milestone word).
## Deferred so the rebuilt node exists with its rect; centred on the node.
static func _merge_after(ctx: Dictionary, cell_name: String, tier: int) -> void:
	var body: Control = ctx.get("body")
	var fx: Dictionary = ctx.get("fx", {})
	if body == null or not is_instance_valid(body):
		return
	(func() -> void:
		if is_instance_valid(body):
			var n := body.find_child(cell_name, true, false)
			if n is Control:
				var ctr: Vector2 = (n as Control).size / 2.0
				GridFx.play_merge(n as Control, n as Control, ctr, tier, 0, [], fx, true)).call_deferred()

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

## The bottom inspector CONTENT: the selected
## spirit's portrait + name + info + a big SELL — or a quiet hint when nothing is selected.
## The strip sits OUTSIDE the frame's ScaleContainer, so px sizes here scale by ctx.scale.
static func _rebuild_inspector(ctx: Dictionary) -> void:
	var insp: PanelContainer = ctx.insp
	var Kit: GDScript = ctx.kit
	var s: float = ctx.scale
	_clear(insp)
	var sel: Dictionary = ctx.get("sel", {})
	var inst := _sel_inst(sel)
	# A full-rect body holds the shared code-drawn paper surface behind the padded content.
	var body := Control.new()
	body.name = "InspectorBody"
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.mouse_filter = Control.MOUSE_FILTER_PASS
	insp.add_child(body)
	var bar_h := INSPECTOR_H * s
	var cp: Dictionary = Kit.cut_paper_opts_from_config(ctx.cfg, "toggle_card", Kit.ROW_CP_DEFAULTS)
	Kit.rugged_paper_surface(
		body,
		"ResidentsInspectorDeckleSurface",
		Vector2.ZERO,
		Pal.CREAM.darkened(0.05),
		Kit.PAPER_EDGE,
		bar_h * 0.5,
		cp)
	var pl := 24.0 * s; var pr := 24.0 * s; var py := 10.0 * s
	if inst.is_empty():
		var hint := Label.new()
		hint.name = "ResidentsInspectorHint"
		hint.text = "Tap a resident"
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hint.add_theme_font_size_override("font_size", int(FS.FINE * s))
		hint.add_theme_color_override("font_color", Color(Pal.INK, 0.65))
		hint.add_theme_constant_override("outline_size", 0)
		hint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		body.add_child(hint)
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
		var ipx := 46.0 * s
		info.custom_minimum_size = Vector2(ipx, ipx)
		var info_tex := _skin_tex("info_btn")
		if info_tex != null:   # reskin: the cut-paper round info button sprite
			var ir := TextureRect.new()
			ir.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ir.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			ir.texture = info_tex
			ir.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			ir.mouse_filter = Control.MOUSE_FILTER_IGNORE
			info.add_child(ir)
		else:
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
	# the row fills the padded strip; the gap pushes SELL to the right end
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = pl; row.offset_right = -pr
	row.offset_top = py; row.offset_bottom = -py
	body.add_child(row)

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
	# reskin: the coral SELL pill wears the extracted cut-paper coral sprite (cream coin + text on top).
	var sell_tex := _skin_tex("sell_bg")
	if sell_tex != null:
		b.add_theme_color_override("font_color", Pal.CREAM)
		var stb := StyleBoxTexture.new()
		stb.texture = sell_tex
		stb.set_content_margin(SIDE_LEFT, 24.0 * s); stb.set_content_margin(SIDE_RIGHT, 30.0 * s)
		stb.set_content_margin(SIDE_TOP, 14.0 * s); stb.set_content_margin(SIDE_BOTTOM, 14.0 * s)
		for st in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(st, stb)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		return b
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
