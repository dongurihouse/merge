extends RefCounted
## The full-bag OVERLAY builder — the modal that replaces the always-on inline bag row (BagView):
## the bottom-bar bag icon opens THIS, a dimmed-backdrop parchment modal showing the WHOLE slot
## ladder (§5) as a grid of tiles — every owned slot (filled = a bagged piece, empty = an owned
## vacancy), the next purchasable slot (the GOLD tile, its 💎 price shown inside), and every locked
## future slot beyond it (a padlock + its 💎 price). Skinned to the bag.png preview: the wood-framed
## parchment (bag_panel), a gold "Bag" banner straddling the top (bag_banner), a red ✕ disc in the
## top-right corner (bag_btn_close), and a cream acorn-balance chip (bag_acorn + the live 💎 count,
## shown as the grove's golden acorn). Stateless pure VIEW: the board owns the bag array, the slot
## count, the 💎 balance, and the retrieve / buy-slot transactions; this only assembles the view and
## fires injected Callables. Tap behaviour uses the still-release pattern (a small move threshold so
## a scroll/drag doesn't mis-fire). ui/ never imports scenes/ (the §15 layering invariant) — every
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
##     on_buy_slot: Callable, # () -> the GOLD (next) tile was tapped: buy the next slot
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

const GRID_COLS := 6              # the preview's six-wide ladder (3 rows reach the 18-slot cap)
const CELL_W := 120.0            # a slot tile's width (the card art rides this, KEEP_ASPECT)
const CELL_H := 150.0            # a slot tile's height (≈ the bag_card portrait aspect, 1.27)
const H_SEP := 12.0
const V_SEP := 14.0
const PRICE_ROW_H := 30.0        # the reserved strip UNDER each tile (a locked slot's price sits here)
const PIECE_FRAC := 0.66         # a bagged piece's size as a fraction of CELL_W
const LOCK_FRAC := 0.54          # a padlock's size as a fraction of CELL_W
const BANNER_W := 360.0
const BANNER_H := 116.0
const CLOSE_W := 96.0
const CLOSE_H := 102.0
const TAP_MOVE_THRESH := 24.0    # a release within this many px of the press is a TAP (not a drag/scroll)

# Kit-asset resolver: the bag screen's pieces live in ui/kit/bag_<name>.png (authored by the
# asset-intake flow). Returns the resolved res:// path; callers guard with ResourceLoader.exists.
static func _kit_path(name: String) -> String:
	return Look.kit("kit/bag_%s.png" % name)

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
#   {kind:"next",  price:p}   the single purchasable slot (gold), p = its 💎 price
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

	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 60
	host.add_child(overlay)

	# the single dismiss seam: fire on_close once (if valid), then free the overlay. Reused by the
	# backdrop tap, the ✕ button, a slot retrieve, and the gold +slot buy.
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

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _panel_box())
	cc.add_child(card)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	card.add_child(col)

	# the acorn-balance chip, docked top-right inside the parchment (under the banner).
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_END
	col.add_child(top)
	top.add_child(_counter_chip(balance))

	# the slot ladder: every owned slot (filled/empty), the gold next slot, then the locked future.
	var grid := GridContainer.new()
	grid.columns = GRID_COLS
	grid.add_theme_constant_override("h_separation", int(H_SEP))
	grid.add_theme_constant_override("v_separation", int(V_SEP))
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(grid)
	for e in slot_plan(owned, max_slots, bag.size(), prices, start_slots):
		grid.add_child(_slot_cell(e, bag, on_retrieve, on_buy_slot, dismiss))

	# the footer caption (the preview's "Open a slot with acorns."), flanked by the kit leaf sprigs.
	col.add_child(_caption(host.tr("Open a slot with acorns.")))

	# the gold banner straddling the top edge + the red ✕ disc in the top-right corner — both docked
	# to the card's rect after layout (the shop.gd place-deferred pattern), reconnected on resize.
	var banner := _banner(host.tr("Bag"))
	overlay.add_child(banner)
	var close := _close_button(dismiss)
	overlay.add_child(close)
	var place := func() -> void:
		if not is_instance_valid(card):
			return
		var r := card.get_global_rect()
		if is_instance_valid(banner):
			banner.global_position = Vector2(
				r.position.x + (r.size.x - BANNER_W) * 0.5, r.position.y - BANNER_H * 0.52)
		if is_instance_valid(close):
			close.global_position = Vector2(
				r.position.x + r.size.x - CLOSE_W * 0.66, r.position.y - CLOSE_H * 0.28)
	card.resized.connect(place)
	place.call_deferred()

	FX.pop_in(card)
	return overlay

# The wood-framed parchment panel (bag_panel) as a nine-patch; a generic parchment when art is absent.
static func _panel_box() -> StyleBox:
	var p := _kit_path("panel")
	if ResourceLoader.exists(p):
		var sbt := StyleBoxTexture.new()
		sbt.texture = load(p)
		sbt.set_texture_margin_all(50.0)              # ~50px wood frame — corners never stretch
		sbt.content_margin_left = 52.0
		sbt.content_margin_right = 52.0
		sbt.content_margin_top = 74.0                 # clearance for the straddling banner + the chip
		sbt.content_margin_bottom = 40.0
		return sbt
	return Look.kit_panel("parchment")

# The acorn-balance chip (a cream HUD pill): the kit acorn + the live 💎 count.
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
	row.add_child(_acorn(30.0))
	var lbl := Label.new()
	lbl.text = str(balance)
	lbl.add_theme_font_size_override("font_size", 30)
	lbl.add_theme_color_override("font_color", INK)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(lbl)
	return chip

# The kit acorn (the 💎 currency, drawn as the grove's golden acorn); Look.icon("gem") when absent.
static func _acorn(px: float) -> Control:
	var p := _kit_path("acorn")
	if ResourceLoader.exists(p):
		var t := TextureRect.new()
		t.texture = load(p)
		t.custom_minimum_size = Vector2(px, px)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return t
	return Look.icon("gem", px)

# A "💎 price" cluster — the acorn + a number; used inside the gold tile and under a locked tile.
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
	row.add_child(_acorn(px))
	return row

# A single ladder tile (the card art + its centred content + a price strip below). `e` is one
# slot_plan entry; filled/next tiles are tappable (retrieve / buy), empty/locked tiles are inert.
static func _slot_cell(e: Dictionary, bag: Array, on_retrieve: Callable, on_buy_slot: Callable, dismiss: Callable) -> Control:
	var cell := VBoxContainer.new()
	cell.add_theme_constant_override("separation", 2)
	cell.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var box := Control.new()
	box.custom_minimum_size = Vector2(CELL_W, CELL_H)
	var kind: String = e.kind
	var card_name := "card"
	if kind == "next":
		card_name = "card_gold"
	elif kind == "locked":
		card_name = "card_empty"
	box.add_child(_card_bg(card_name))

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(center)
	match kind:
		"filled":
			var piece := PieceView.make_piece(int(bag[int(e.index)]), CELL_W * PIECE_FRAC)
			piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
			center.add_child(piece)
			_wire_tap(box, func() -> void:
				if on_retrieve.is_valid():
					on_retrieve.call(int(e.index))
				dismiss.call())
		"next":
			center.add_child(_price_row(int(e.price), 28.0, 28))
			_wire_tap(box, func() -> void:
				if on_buy_slot.is_valid():
					on_buy_slot.call()
				dismiss.call())
		"locked":
			center.add_child(_lock(CELL_W * LOCK_FRAC))
	cell.add_child(box)

	# the price strip under the tile: a locked slot shows its 💎 price here; every other tile
	# reserves the same height so the grid rows stay aligned.
	var below := CenterContainer.new()
	below.custom_minimum_size = Vector2(CELL_W, PRICE_ROW_H)
	below.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if kind == "locked":
		below.add_child(_price_row(int(e.price), 22.0, 22))
	cell.add_child(below)
	return cell

# The padlock glyph (kit bag_lock); Look.icon("lock") when the art is absent.
static func _lock(px: float) -> Control:
	var p := _kit_path("lock")
	if ResourceLoader.exists(p):
		var t := TextureRect.new()
		t.texture = load(p)
		t.custom_minimum_size = Vector2(px, px)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return t
	var l := Look.icon("lock", px)
	l.modulate = Color(INK, 0.5)
	return l

# A slot tile's BACKGROUND: the kit card art (bag_card / bag_card_empty / bag_card_gold) as a
# full-rect TextureRect; a soft rounded fallback Panel when the art is absent.
static func _card_bg(name: String) -> Control:
	var p := _kit_path(name)
	if ResourceLoader.exists(p):
		var t := TextureRect.new()
		t.texture = load(p)
		t.set_anchors_preset(Control.PRESET_FULL_RECT)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return t
	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(GROUND_EDGE, 0.6)
	sb.set_corner_radius_all(18)
	sb.set_border_width_all(3)
	sb.border_color = Color(CREAM, 0.35)
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel

# The gold "Bag" banner: the kit ribbon art with the title as ENGINE text riding it (images never
# carry words — §0.3). Falls back to the shared solid title chip when the art is absent.
static func _banner(text: String) -> Control:
	var p := _kit_path("banner")
	if not ResourceLoader.exists(p):
		var ribbon := Look.title_ribbon(text, 34)
		ribbon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		return ribbon
	var wrap := Control.new()
	wrap.custom_minimum_size = Vector2(BANNER_W, BANNER_H)
	wrap.size = Vector2(BANNER_W, BANNER_H)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art := TextureRect.new()
	art.texture = load(p)
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(art)
	var lbl := Label.new()
	lbl.text = text
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 38)
	lbl.add_theme_color_override("font_color", INK)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(lbl)
	return wrap

# The red ✕ close disc (kit bag_btn_close); a styled round button when the art is absent. Tapping
# dismisses the overlay.
static func _close_button(dismiss: Callable) -> Control:
	var p := _kit_path("btn_close")
	if ResourceLoader.exists(p):
		var b := TextureButton.new()
		b.texture_normal = load(p)
		b.custom_minimum_size = Vector2(CLOSE_W, CLOSE_H)
		b.size = Vector2(CLOSE_W, CLOSE_H)
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func() -> void: dismiss.call())
		return b
	var btn := Button.new()
	btn.text = "✕"
	btn.custom_minimum_size = Vector2(CLOSE_W, CLOSE_H)
	btn.focus_mode = Control.FOCUS_NONE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#D1503F")
	sb.set_corner_radius_all(int(CLOSE_W * 0.5))
	sb.set_border_width_all(4)
	sb.border_color = Color(CREAM, 0.8)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.add_theme_color_override("font_color", CREAM)
	btn.add_theme_font_size_override("font_size", 36)
	btn.pressed.connect(func() -> void: dismiss.call())
	return btn

# The footer caption flanked by the kit leaf sprigs (the preview's vine flourish).
static func _caption(text: String) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var leaf_l := _leaf("leaf_l")
	if leaf_l != null:
		row.add_child(leaf_l)
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 26)
	lbl.add_theme_color_override("font_color", Color(INK, 0.7))
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(lbl)
	var leaf_r := _leaf("leaf_r")
	if leaf_r != null:
		row.add_child(leaf_r)
	return row

# A kit leaf sprig at caption height, or null when the art is absent (the caption then stands alone).
static func _leaf(name: String) -> Control:
	var p := _kit_path(name)
	if not ResourceLoader.exists(p):
		return null
	var t := TextureRect.new()
	t.texture = load(p)
	t.custom_minimum_size = Vector2(54, 28)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

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
