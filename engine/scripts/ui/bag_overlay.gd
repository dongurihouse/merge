extends RefCounted
## The full-bag OVERLAY builder — the modal that replaces the always-on inline bag row (BagView):
## the bottom-bar bag icon opens THIS, a dimmed-backdrop parchment modal showing EVERY stashed item
## as a grid of slot tiles (filled = a bagged piece, empty = an owned-but-vacant slot), plus the
## trailing +slot buy affordance. Stateless pure VIEW, in the shop.gd / oow_offer.gd modal language:
## a full-rect veil that dismisses on tap, a centered parchment card, a close button. The board owns
## the bag array, the slot count, and the retrieve / buy-slot transactions; this only assembles the
## view and fires injected Callables. Tap behaviour uses the still-release pattern (a small move
## threshold so a scroll/drag doesn't mis-fire) the sibling stand builders use. ui/ never imports
## scenes/ (the §15 layering invariant) — every action is an injected Callable.
##
## Usage:
##   BagOverlay.open(host, {
##     bag: Array,            # int item codes, in slot order
##     owned: int,           # how many slots the player owns
##     has_buy: bool,        # whether the +slot buy tile is shown
##     slot_price: int,      # gem price of the next slot (shown on the +slot tile)
##     on_retrieve: Callable, # (index: int) -> a filled slot was tapped: pull the piece back out
##     on_buy_slot: Callable, # () -> the +slot tile was tapped: buy another slot
##     on_close: Callable })  # (optional) () -> the overlay was dismissed (any path)
## Returns the overlay root Control (already added to host).

const Look = preload("res://engine/scripts/ui/skin.gd")
const PieceView = preload("res://engine/scripts/ui/piece_view.gd")
const FX = preload("res://engine/scripts/ui/fx.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const Pal = Game.PALETTE

const INK = Pal.INK
const CREAM = Pal.CREAM
const GROUND_EDGE = Pal.GROUND_EDGE

const SLOT_PX := 96.0            # the slot tile's inner side (the piece is drawn at this size)
const SLOT_PAD := 6.0            # the piece's inset inside the tile
const GRID_COLS := 4
const TAP_MOVE_THRESH := 24.0    # a release within this many px of the press is a TAP (not a drag/scroll)

# Build the full-bag overlay into `host` and return its root. The overlay sits ABOVE the scene
# (a high z_index) with a dimmed backdrop; tapping the backdrop, the close button, a filled slot,
# or the +slot tile all dismiss via the shared `dismiss` Callable.
static func open(host: Control, cfg: Dictionary) -> Control:
	var bag: Array = cfg.get("bag", [])
	var owned: int = int(cfg.get("owned", 0))
	var has_buy: bool = bool(cfg.get("has_buy", false))
	var slot_price: int = int(cfg.get("slot_price", 0))
	var on_retrieve: Callable = cfg.get("on_retrieve", Callable())
	var on_buy_slot: Callable = cfg.get("on_buy_slot", Callable())
	var on_close: Callable = cfg.get("on_close", Callable())

	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 60
	host.add_child(overlay)

	# the single dismiss seam: fire on_close once (if valid), then free the overlay. Reused by the
	# backdrop tap, the close button, a slot retrieve, and the +slot buy.
	var dismiss := func() -> void:
		if not is_instance_valid(overlay):
			return
		if on_close.is_valid():
			on_close.call()
		overlay.queue_free()

	# the dimmed backdrop — a flat dim that dismisses on tap (shop.gd uses a blurred veil; the bag
	# is a lighter modal, so a plain scrim keeps it cheap and matches oow_offer.gd).
	var veil := ColorRect.new()
	veil.color = Color(INK, 0.5)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(veil)
	veil.gui_input.connect(func(ev: InputEvent) -> void:
		if (ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed):
			dismiss.call())

	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(cc)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Look.kit_panel("parchment"))
	cc.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	card.add_child(col)

	# the title chip (the same solid ribbon every modal uses)
	var title := Look.title_ribbon(host.tr("Bag"), 32)
	title.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(title)

	# the slot grid: every owned slot (filled or empty), then the +slot buy tile when has_buy.
	var grid := GridContainer.new()
	grid.columns = GRID_COLS
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(grid)
	for i in range(owned):
		if i < bag.size():
			grid.add_child(_filled_slot(int(bag[i]), i, on_retrieve, dismiss))
		else:
			grid.add_child(_empty_slot())
	if has_buy:
		grid.add_child(_buy_slot(slot_price, on_buy_slot, dismiss))

	# the close button (secondary pill in the shared button language)
	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(btns)
	btns.add_child(Look.button(host.tr("Close"), func() -> void: dismiss.call(), false))

	FX.pop_in(card)
	return overlay

# A slot-tile background Panel sized to hold a piece. Uses the kit's slot_tile.png as a nine-patch
# StyleBoxTexture when present, else a soft rounded fallback (matching BagView's inline slots).
static func _slot_tile() -> Panel:
	var tile := Panel.new()
	tile.custom_minimum_size = Vector2(SLOT_PX, SLOT_PX)
	var p := Look.kit("slot_tile.png")
	if ResourceLoader.exists(p):
		var sbt := StyleBoxTexture.new()
		sbt.texture = load(p)
		sbt.set_texture_margin_all(28.0)               # ~180px source corners → crisp at tile size
		tile.add_theme_stylebox_override("panel", sbt)
	else:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(GROUND_EDGE, 0.6)
		sb.set_corner_radius_all(18)
		sb.set_border_width_all(3)
		sb.border_color = Color(CREAM, 0.35)
		tile.add_theme_stylebox_override("panel", sb)
	return tile

# An OWNED-but-empty slot: the tile alone (no piece, not tappable).
static func _empty_slot() -> Panel:
	var tile := _slot_tile()
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tile

# A FILLED slot: the tile + a centered piece. A still-tap retrieves the item (calls on_retrieve with
# the slot index) then dismisses the overlay.
static func _filled_slot(code: int, index: int, on_retrieve: Callable, dismiss: Callable) -> Panel:
	var tile := _slot_tile()
	var piece := PieceView.make_piece(code, SLOT_PX - SLOT_PAD * 2.0)
	piece.position = Vector2(SLOT_PAD, SLOT_PAD)
	piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(piece)
	_wire_tap(tile, func() -> void:
		if on_retrieve.is_valid():
			on_retrieve.call(index)
		dismiss.call())
	return tile

# The trailing +slot BUY tile: the tile + a gem icon and the slot price. A still-tap buys (calls
# on_buy_slot) then dismisses.
static func _buy_slot(slot_price: int, on_buy_slot: Callable, dismiss: Callable) -> Panel:
	var tile := _slot_tile()
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 2)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(row)
	var ic := Look.icon("gem", 26.0)
	ic.modulate = Color(CREAM, 0.6)
	row.add_child(ic)
	var lbl := Label.new()
	lbl.text = "+%d" % slot_price
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.add_theme_color_override("font_color", Color(CREAM, 0.6))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lbl)
	_wire_tap(tile, func() -> void:
		if on_buy_slot.is_valid():
			on_buy_slot.call()
		dismiss.call())
	return tile

# The still-release tap wirer (mirrors board.gd `_stand_tap`): fire `action` on a LEFT-button /
# touch release that landed within TAP_MOVE_THRESH px of its press, so a scroll/drag never mis-fires.
static func _wire_tap(node: Control, action: Callable) -> void:
	node.gui_input.connect(func(ev: InputEvent) -> void:
		var btn: bool = (ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT) \
			or ev is InputEventScreenTouch
		if not btn:
			return
		if ev.pressed:
			node.set_meta("press_pos", ev.position)
		elif node.has_meta("press_pos"):
			var moved: float = ev.position.distance_to(node.get_meta("press_pos"))
			node.remove_meta("press_pos")
			if moved <= TAP_MOVE_THRESH:
				action.call())
