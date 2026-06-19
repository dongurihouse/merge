extends RefCounted
## The full-bag OVERLAY builder — the modal that replaces the always-on inline bag row (BagView):
## the bottom-bar bag icon opens THIS, a dimmed-backdrop parchment modal showing the WHOLE slot
## ladder (§5) as a grid of tiles — every owned slot (filled = a bagged piece, empty = an owned
## vacancy), the next purchasable slot (warm-tinted, its 💎 price shown inside), and every locked
## future slot beyond it (a padlock + its 💎 price below). Built entirely from the SHARED popup
## components (skin.gd) so every modal — shop, bag, … — speaks one language: the parchment panel
## (Look.kit_panel), the gold ribbon banner (Look.banner_title), the red ✕ disc (Look.close_button),
## the storefront card (Look.card_button → shop_card / shop_card_b), and the shared 💎 currency icon
## (Look.icon("gem")). No bag-specific art. Stateless pure VIEW: the board owns the bag array, the
## slot count, the 💎 balance, and the retrieve / buy-slot transactions; this only assembles the view
## and fires injected Callables. Tap behaviour uses the still-release pattern (a small move threshold
## so a scroll/drag doesn't mis-fire). ui/ never imports scenes/ (the §15 layering invariant) — every
## action AND every read (the balance, the price ladder) is injected through `cfg`.
##
## Usage:
##   BagOverlay.open(host, {
##     bag: Array,             # int item codes, in slot order
##     owned: int,            # how many slots the player owns
##     balance: int,          # the player's 💎 balance (Save.diamonds()) — the acorn counter
##     max_slots: int,        # the hard cap (G.BAG_MAX_SLOTS) — the ladder length
##     start_slots: int,      # the starting slot count (G.BAG_START_SLOTS) — prices index from here
##     prices: Array,         # the per-expansion 💎 price ladder (G.BAG_SLOT_PRICES)
##     on_retrieve: Callable, # (index: int) -> a filled slot was tapped: pull the piece back out
##     on_buy_slot: Callable, # () -> the next (tinted) tile was tapped: buy the next slot
##     on_close: Callable })  # (optional) () -> the overlay was dismissed (any path)
## Returns the overlay root Control (already added to host).

const Look = preload("res://engine/scripts/ui/skin.gd")
const PieceView = preload("res://engine/scripts/ui/piece_view.gd")
const FX = preload("res://engine/scripts/ui/fx.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const G = preload("res://engine/scripts/core/content.gd")
const Pal = Game.PALETTE

const INK = Pal.INK
const CREAM = Pal.CREAM
const GROUND_EDGE = Pal.GROUND_EDGE

const GRID_COLS := 6              # the six-wide ladder (3 rows reach the 18-slot cap)
const CELL_W := 116.0            # a slot tile's width (the shared shop_card rides this)
const CELL_H := 120.0            # a slot tile's height (≈ shop_card's square aspect)
const H_SEP := 12.0
const V_SEP := 12.0
const PRICE_ROW_H := 30.0        # the reserved strip UNDER each tile (a locked slot's price sits here)
const PIECE_FRAC := 0.62         # a bagged piece's size as a fraction of CELL_W
const LOCK_FRAC := 0.40          # the padlock glyph's size as a fraction of CELL_W
const CLOSE_MARGIN := 10.0       # the ✕ disc's inset from the card's top-right corner
const NEXT_TINT := Color(1.0, 0.88, 0.55)   # the next-buyable tile: a warm gold wash on shop_card
const LOCKED_TINT := Color(0.82, 0.80, 0.76) # a locked tile: shop_card_b, dimmed
const TAP_MOVE_THRESH := 24.0    # a release within this many px of the press is a TAP (not a drag/scroll)

# --- the slot ladder (pure, headless-testable) ------------------------------------
# The 💎 price to UNLOCK 1-based slot `k`: index the ladder by how many expansions precede it.
# 0 when k is a starting (always-owned) slot or past the ladder.
static func _price_at(k: int, prices: Array, start_slots: int) -> int:
	var idx := (k - 1) - start_slots
	if idx < 0 or idx >= prices.size():
		return 0
	return int(prices[idx])

# Classify every slot 1..max_slots into the tile it should render. Pure derivation — the view maps
# each entry to a tile; tests assert the classification + prices without building any nodes.
#   {kind:"filled", index:i}  an owned slot holding bag[i]
#   {kind:"empty"}            an owned but vacant slot
#   {kind:"next",  price:p}   the single purchasable slot (tinted), p = its 💎 price
#   {kind:"locked",price:p}   a future slot beyond the next one, p = its 💎 price
static func slot_plan(owned: int, max_slots: int, bag_size: int, prices: Array, start_slots: int) -> Array:
	var out: Array = []
	for k in range(1, max_slots + 1):
		if k <= owned:
			if k - 1 < bag_size:
				out.append({"kind": "filled", "index": k - 1})
			else:
				out.append({"kind": "empty"})
		elif k == owned + 1:
			out.append({"kind": "next", "price": _price_at(k, prices, start_slots)})
		else:
			out.append({"kind": "locked", "price": _price_at(k, prices, start_slots)})
	return out

# --- the modal ---------------------------------------------------------------------
static func open(host: Control, cfg: Dictionary) -> Control:
	var bag: Array = cfg.get("bag", [])
	var owned: int = int(cfg.get("owned", 0))
	var balance: int = int(cfg.get("balance", 0))
	var max_slots: int = int(cfg.get("max_slots", owned))
	var start_slots: int = int(cfg.get("start_slots", 6))
	var prices: Array = cfg.get("prices", [])
	var on_retrieve: Callable = cfg.get("on_retrieve", Callable())
	var on_buy_slot: Callable = cfg.get("on_buy_slot", Callable())
	var on_close: Callable = cfg.get("on_close", Callable())
	var gen_bag: Array = cfg.get("gen_bag", [])
	var on_place_gen: Callable = cfg.get("on_place_gen", Callable())

	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 60
	host.add_child(overlay)

	# the single dismiss seam: fire on_close once (if valid), then free the overlay. Reused by the
	# backdrop tap, the ✕ button, a slot retrieve, and the next-slot buy.
	var dismiss := func() -> void:
		if not is_instance_valid(overlay):
			return
		if on_close.is_valid():
			on_close.call()
		overlay.queue_free()

	# the dimmed backdrop — a flat scrim that dismisses on tap (the bag is a light modal, matching
	# oow_offer.gd's plain veil rather than the shop's blurred one).
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

	# the shared parchment card (Look.kit_panel) — the same surface every modal uses.
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Look.kit_panel("parchment"))
	cc.add_child(card)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	card.add_child(col)

	# the shared gold ribbon banner with engine "Bag" text riding it (Look.banner_title).
	var banner := Look.banner_title(host.tr("Bag"), 40, 108.0)
	banner.size_flags_horizontal = Control.SIZE_FILL
	col.add_child(banner)

	# the acorn-balance chip, docked top-right under the banner (the shared 💎 currency icon).
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_END
	col.add_child(top)
	top.add_child(_counter_chip(balance))

	# the slot ladder: every owned slot (filled/empty), the tinted next slot, then the locked future.
	var grid := GridContainer.new()
	grid.columns = GRID_COLS
	grid.add_theme_constant_override("h_separation", int(H_SEP))
	grid.add_theme_constant_override("v_separation", int(V_SEP))
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(grid)
	for e in slot_plan(owned, max_slots, bag.size(), prices, start_slots):
		grid.add_child(_slot_cell(e, bag, on_retrieve, on_buy_slot, dismiss))

	# the generator section: a "Generators" label + a row of generator tiles (tap to place on board).
	# Only shown when there are stored generators.
	if not gen_bag.is_empty():
		var gen_label := Label.new()
		gen_label.text = host.tr("Generators")
		gen_label.add_theme_font_size_override("font_size", 26)
		gen_label.add_theme_color_override("font_color", Color(INK, 0.75))
		gen_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(gen_label)
		var gen_row := HBoxContainer.new()
		gen_row.alignment = BoxContainer.ALIGNMENT_CENTER
		gen_row.add_theme_constant_override("separation", int(H_SEP))
		col.add_child(gen_row)
		for gid in gen_bag:
			var gid_str := String(gid)
			var tile := Look.card_button(Vector2(CELL_W, CELL_H))
			var center := CenterContainer.new()
			center.set_anchors_preset(Control.PRESET_FULL_RECT)
			center.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tile.add_child(center)
			var gdef: Dictionary = G.gen_def(G.GENERATORS, gid_str)
			var gtex_path: String = Game.art(String(gdef.get("tex", "")))
			if ResourceLoader.exists(gtex_path):
				var gicon := TextureRect.new()
				gicon.texture = load(gtex_path)
				gicon.custom_minimum_size = Vector2(CELL_W * PIECE_FRAC, CELL_W * PIECE_FRAC)
				gicon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				gicon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				gicon.mouse_filter = Control.MOUSE_FILTER_IGNORE
				center.add_child(gicon)
			else:
				var fallback_lbl := Label.new()
				fallback_lbl.text = gid_str
				fallback_lbl.add_theme_font_size_override("font_size", 18)
				fallback_lbl.add_theme_color_override("font_color", INK)
				fallback_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				fallback_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
				center.add_child(fallback_lbl)
			tile.pressed.connect(func() -> void:
				if on_place_gen.is_valid():
					on_place_gen.call(gid_str)
				dismiss.call())
			gen_row.add_child(tile)

	# the footer caption (the preview's "Open a slot with acorns."), flanked by the kit leaf sprigs.
	col.add_child(_caption(host.tr("Open a slot with acorns.")))

	# the shared red ✕ disc (Look.close_button), docked inside the card's top-right corner after
	# layout (the shop.gd place-deferred pattern), reconnected on resize.
	var close := Look.close_button(dismiss)
	overlay.add_child(close)
	var place := func() -> void:
		if not is_instance_valid(card) or not is_instance_valid(close):
			return
		var r := card.get_global_rect()
		var cw: float = close.custom_minimum_size.x
		close.global_position = Vector2(
			r.position.x + r.size.x - cw - CLOSE_MARGIN, r.position.y + CLOSE_MARGIN)
	card.resized.connect(place)
	place.call_deferred()

	FX.pop_in(card)
	return overlay

# The acorn-balance chip (a cream HUD pill): the shared 💎 currency icon + the live balance.
static func _counter_chip(balance: int) -> Control:
	var chip := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(CREAM, 0.92)
	sb.set_corner_radius_all(22)
	sb.set_border_width_all(3)
	sb.border_color = Color(GROUND_EDGE, 0.45)
	sb.content_margin_left = 18.0
	sb.content_margin_right = 18.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	chip.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	chip.add_child(row)
	row.add_child(Look.icon("gem", 30.0))
	var lbl := Label.new()
	lbl.text = str(balance)
	lbl.add_theme_font_size_override("font_size", 30)
	lbl.add_theme_color_override("font_color", INK)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(lbl)
	return chip

# A "💎 price" cluster — a number + the shared 💎 icon; used inside the next tile and under a lock.
static func _price_row(price: int, px: float, font: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lbl := Label.new()
	lbl.text = str(price)
	lbl.add_theme_font_size_override("font_size", font)
	lbl.add_theme_color_override("font_color", INK)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(lbl)
	row.add_child(Look.icon("gem", px))
	return row

# A single ladder tile, built on the SHARED card (Look.card_button): the storefront parchment card +
# its centred content + a price strip below. `e` is one slot_plan entry; filled/next tiles tap
# (retrieve / buy), empty/locked tiles are inert (the card still press-juices, like every shop card).
static func _slot_cell(e: Dictionary, bag: Array, on_retrieve: Callable, on_buy_slot: Callable, dismiss: Callable) -> Control:
	var cell := VBoxContainer.new()
	cell.add_theme_constant_override("separation", 2)
	cell.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var kind: String = e.kind
	var art := "kit/shop_card.png"
	if kind == "locked":
		art = "kit/shop_card_b.png"
	var tile := Look.card_button(Vector2(CELL_W, CELL_H), art)
	if kind == "next":
		tile.self_modulate = NEXT_TINT          # a warm gold wash marks the buyable slot
	elif kind == "locked":
		tile.self_modulate = LOCKED_TINT        # a greyed card reads as locked (self_modulate spares the glyph)

	# centred content rides ON the card (a full-rect CenterContainer; the card keeps the tap)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(center)
	match kind:
		"filled":
			var piece := PieceView.make_piece(int(bag[int(e.index)]), CELL_W * PIECE_FRAC)
			piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
			center.add_child(piece)
			tile.pressed.connect(func() -> void:
				if on_retrieve.is_valid():
					on_retrieve.call(int(e.index))
				dismiss.call())
		"next":
			center.add_child(_price_row(int(e.price), 28.0, 28))
			tile.pressed.connect(func() -> void:
				if on_buy_slot.is_valid():
					on_buy_slot.call()
				dismiss.call())
		"locked":
			center.add_child(_lock_glyph(CELL_W * LOCK_FRAC))
	cell.add_child(tile)

	# the price strip under the tile: a locked slot shows its 💎 price here; every other tile
	# reserves the same height so the grid rows stay aligned.
	var below := CenterContainer.new()
	below.custom_minimum_size = Vector2(CELL_W, PRICE_ROW_H)
	below.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if kind == "locked":
		below.add_child(_price_row(int(e.price), 22.0, 22))
	cell.add_child(below)
	return cell

# The padlock glyph (a font character — no separate asset), tinted to read as a closed lock.
static func _lock_glyph(px: float) -> Control:
	var l := Label.new()
	l.text = "🔒"
	l.add_theme_font_size_override("font_size", int(px))
	l.add_theme_color_override("font_color", Color(INK, 0.55))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

# The footer caption flanked by the SHARED leaf sprig (kit/shop_leaf.png), or text alone when absent.
static func _caption(text: String) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var leaf_l := _leaf(false)
	if leaf_l != null:
		row.add_child(leaf_l)
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 26)
	lbl.add_theme_color_override("font_color", Color(INK, 0.7))
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(lbl)
	var leaf_r := _leaf(true)
	if leaf_r != null:
		row.add_child(leaf_r)
	return row

# The shared leaf sprig at caption height (flipped for the right side), or null when the art is absent.
static func _leaf(flip: bool) -> Control:
	var p := Look.kit("kit/shop_leaf.png")
	if not ResourceLoader.exists(p):
		return null
	var t := TextureRect.new()
	t.texture = load(p)
	t.flip_h = flip
	t.custom_minimum_size = Vector2(40, 36)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t
