extends RefCounted
## The full-bag OVERLAY builder — the modal that replaces the always-on inline bag row (BagView):
## the bottom-bar bag icon opens THIS, a dimmed-backdrop modal showing the WHOLE slot ladder (§5) as a
## grid of tiles — every owned slot (filled = a bagged piece, empty = an owned vacancy), the next
## purchasable slot (its 💎 price shown inside — no highlight; the price is the cue), and every locked
## future slot beyond it (a padlock, no price). Built on the SHARED ui kit (games/grove/tools/ui_workbench_kit.gd),
## the SAME builder the workbench previews and the game's vault/settings/hud read: the parchment frame
## (Kit.dialog_frame — banner · border · ✕ · scroll), the slot tile (Kit.bag_card), and the reused
## gold wallet pill. So the engine and the design tool render one
## bag, from one transform — tweak the bag in the workbench and the game follows.
##
## Stateless pure VIEW: the board owns the bag array, the slot count, the 💎 balance, and the retrieve /
## buy-slot transactions; this only assembles the view and fires injected Callables. ui/ never imports
## scenes/ (the §15 layering invariant) — every action AND every read (the balance, the price ladder) is
## injected through `cfg`.
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
##     on_buy_slot: Callable, # () -> bool: the next (gold) tile was tapped: buy the next slot. FALSE
##                            #   (short of acorns) keeps the bag open + raises the shop prompt.
##     on_open_shop: Callable,# (optional) () -> the shop-prompt's button: open the acorn shop
##     on_balance: Callable,  # (optional) () -> int: the LIVE acorn balance (the shortfall is read
##                            #   through this, since `balance` above is only an open-time snapshot)
##     gen_bag: Array,        # (optional) stored generator ids — a row below the grid (game-only)
##     gen_bag_tiers: Array,  # (optional) tiers parallel to gen_bag
##     on_place_gen: Callable,# (optional) (id: String) -> a generator tile was tapped: place it
##     on_close: Callable })  # (optional) () -> the overlay was dismissed (any path)
## Returns the overlay root Control (already added to host).

const PieceView = preload("res://engine/scripts/ui/piece_view.gd")
const Strings = preload("res://engine/scripts/core/strings.gd")
const FX = preload("res://engine/scripts/ui/fx.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const G = preload("res://engine/scripts/core/content.gd")
const Overlay = preload("res://engine/scripts/ui/overlay.gd")
const FS = preload("res://engine/scripts/core/tuning.gd").FontScale
const Pal = Game.PALETTE
const KIT_PATH := "res://games/grove/tools/ui_workbench_kit.gd"   # the shared ui kit (frame · cell · pill)
const OVERLAY_NAME := "BagOverlay"
const NEED_MORE_NAME := "BagNeedMorePrompt"     ## the short-of-acorns prompt raised over an open bag
# the prompt card's proportions, read off the authored mock (card ≈ 3/4 of the frame, the medallion
# ≈ 1/4 of the card). Fractions, never px — the card tracks the screen like every other dialog.
const CARD_W_FRAC := 0.62     ## card width as a fraction of the SCREEN width (NARROWER than the bag
                              ## it sits on, so it reads as a card ON the dialog, not a replacement)
const MEDAL_FRAC := 0.26      ## medallion diameter as a fraction of the CARD width
const Look = preload("res://engine/scripts/ui/skin.gd")
const Audio = preload("res://engine/scripts/core/audio.gd")

const INK = Pal.INK
const BARK = Pal.BARK

# --- the bag mock's look (games/grove/assets/_concepts/dialogs/bag_1080x1920.png) ------------------
# Every number is read off the mock and expressed against the FITTED cell width (cw), so the ladder
# keeps its proportions at any dialog width.
const CELL_ASPECT := 2.10                  # the mock's tall portrait slot (132 × 278)
const GRID_COLS := 6                       # the mock's six-wide ladder
const GRID_GAP := 17
const TITLE_FONT := FS.GLYPH_LG            # the mock's hero "BAG" (the nearest named tier to 116px)
const TITLE_BAND := 150.0
const SAGE := Color("#BFCBAB")             # an owned slot's sage-green face
const CELL_CREAM := Color("#F5E5D0")       # an owned-but-empty slot: the card's own cream
const AMBER := Color("#F1C36F")            # the next buyable slot
const LOCK_BLUE := Color("#97ABBE")        # a locked future slot
const DASH_INK := Color("#C6A374")         # the dashed acorn placeholder
const LOCK_TINT := Color(0.52, 0.68, 0.73) # multiplies icon_padlock into the mock's dark slate
const PILL_CREAM := Color("#FAF3E6")       # the next slot's price chip
const PILL_LOCK := Color("#D7E2EB")        # ...and a locked slot's
const SHADOW_TINT := Color("#294654")      # the shared mock drop-shadow tint (residents.gd's role)
const RIM_LIGHTEN := 0.30                  # every cell wears a lighter inset rim of its own colour
const PADLOCK_ART := "ui/meadow_v2/icon_padlock.png"
const PADLOCK_BOX := 0.87                  # the art's 256² canvas box; its visible padlock is ~0.55 cw

## The dashed acorn placeholder stamped on an empty / next-buyable slot: the mock's tan dashed outline
## (a domed body plus a small stem nub), drawn in code so it scales with the cell.
class DashedAcorn:
	extends Control
	var ink: Color = Color.BLACK
	var thick := 4.0
	var dash := 12.0
	var gap := 9.0

	static func _bez(a: Vector2, c1: Vector2, c2: Vector2, b: Vector2, t: float) -> Vector2:
		var u := 1.0 - t
		return a * (u * u * u) + c1 * (3.0 * u * u * t) + c2 * (3.0 * u * t * t) + b * (t * t * t)

	func _draw() -> void:
		var s := size
		# the BODY — a closed cubic through top / right / bottom / left anchors (an acorn's dome
		# shouldering out at ~a third down, tapering to a rounded point).
		var body := PackedVector2Array()
		for seg in [[Vector2(0.50, 0.10), Vector2(0.80, 0.10), Vector2(1.00, 0.22), Vector2(1.00, 0.42)],
				[Vector2(1.00, 0.42), Vector2(1.00, 0.68), Vector2(0.80, 1.00), Vector2(0.50, 1.00)],
				[Vector2(0.50, 1.00), Vector2(0.20, 1.00), Vector2(0.00, 0.68), Vector2(0.00, 0.42)],
				[Vector2(0.00, 0.42), Vector2(0.00, 0.22), Vector2(0.20, 0.10), Vector2(0.50, 0.10)]]:
			for i in 26:
				body.append(_bez(seg[0], seg[1], seg[2], seg[3], float(i) / 26.0) * s)
		body.append(Vector2(0.50, 0.10) * s)
		# the STEM nub — an open arch riding the dome's crown
		var stem := PackedVector2Array()
		for seg2 in [[Vector2(0.42, 0.115), Vector2(0.42, 0.02), Vector2(0.44, 0.00), Vector2(0.50, 0.00)],
				[Vector2(0.50, 0.00), Vector2(0.56, 0.00), Vector2(0.58, 0.02), Vector2(0.58, 0.115)]]:
			for i in 12:
				stem.append(_bez(seg2[0], seg2[1], seg2[2], seg2[3], float(i) / 12.0) * s)
		stem.append(Vector2(0.58, 0.115) * s)
		_dashed(body)
		_dashed(stem)

	## Walk the polyline at constant arc length, alternating drawn dashes and gaps.
	func _dashed(pts: PackedVector2Array) -> void:
		var pen := 0.0
		var on := true
		for i in range(pts.size() - 1):
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var seg := a.distance_to(b)
			if seg <= 0.001:
				continue
			var t := 0.0
			while t < seg:
				var want := (dash if on else gap) - pen
				var span := minf(want, seg - t)
				if on:
					draw_line(a.lerp(b, t / seg), a.lerp(b, (t + span) / seg), ink, thick, true)
				t += span
				pen += span
				if pen >= (dash if on else gap) - 0.001:
					on = not on
					pen = 0.0

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
	if Overlay.is_open(host, OVERLAY_NAME):
		return null
	var bag: Array = cfg.get("bag", [])
	var owned: int = int(cfg.get("owned", 0))
	var balance: int = int(cfg.get("balance", 0))
	var max_slots: int = int(cfg.get("max_slots", owned))
	var start_slots: int = int(cfg.get("start_slots", 6))
	var prices: Array = cfg.get("prices", [])
	var on_retrieve: Callable = cfg.get("on_retrieve", Callable())
	var on_buy_slot: Callable = cfg.get("on_buy_slot", Callable())
	var on_close: Callable = cfg.get("on_close", Callable())
	var on_open_shop: Callable = cfg.get("on_open_shop", Callable())
	var on_balance: Callable = cfg.get("on_balance", Callable())
	var gen_bag: Array = cfg.get("gen_bag", [])
	var gen_bag_tiers: Array = cfg.get("gen_bag_tiers", [])
	var on_place_gen: Callable = cfg.get("on_place_gen", Callable())

	var overlay := Overlay.mount(host, OVERLAY_NAME)

	# the single dismiss seam: fire on_close once (if valid), then free the overlay. Reused by the
	# backdrop tap, the ✕ button, a slot retrieve, and the next-slot buy.
	var dismiss := func() -> void:
		if not is_instance_valid(overlay):
			return
		if on_close.is_valid():
			on_close.call()
		overlay.queue_free()

	# the dimmed backdrop — a flat scrim that dismisses on tap (the bag is a light modal with a
	# plain veil rather than the shop's blurred one).
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

	# build the bag card from the SHARED kit — the same dialog the workbench previews. A missing kit
	# would only happen if the tools script were stripped from a build; bail to a bare veil if so.
	var Kit: GDScript = load(KIT_PATH)
	if Kit == null:
		push_warning("BagOverlay: ui kit missing at %s" % KIT_PATH)
		return overlay
	var kcfg: Dictionary = Kit.load_config(Kit.CONFIG_PATH)
	var opts: Dictionary = Kit.bag_opts_from_config(kcfg)
	opts["content_scale"] = Kit.dialog_content_scale(kcfg, "bag")
	opts["banner_text"] = Strings.t("bag.banner_text")
	opts["caption"] = Strings.t("bag.caption")
	opts["on_close"] = dismiss

	# every dialog renders at the SINGLE global frame width; content scales from the bag's authored
	# baseline (Kit.DIALOG_DESIGN_PCT) to that width (matching the other overlays).
	var vw: float = host.get_viewport_rect().size.x
	var width: float = vw * Kit.DIALOG_DESIGN_PCT["bag"] / 100.0
	# the "Bag" ribbon is short, so floor it at a fraction of the SCREEN width (not the narrower dialog) — it
	# reads as a proper banner instead of a tiny stub. The shared frame honours this min in _banner.
	opts["banner_min_w"] = vw * Kit.BANNER_MIN_W_FRAC

	# the mock's LAYOUT: a six-wide ladder of TALL portrait slots under a hero title, with the acorn
	# balance chip between them. Authored here (not in the shared workbench config) so the bag reaches
	# its mock without moving knobs the other dialogs read.
	opts["cols"] = GRID_COLS
	opts["cell_gap"] = GRID_GAP
	opts["cell_h"] = float(opts.get("cell_w", 116.0)) * CELL_ASPECT
	opts["banner_font"] = TITLE_FONT
	opts["banner_h"] = TITLE_BAND
	opts["row_gap"] = 22
	opts["balance_chip"] = true
	opts["content_frac"] = 1.15     # the mock's stashed piece reads BIG in its slot (the art carries its own transparent margin)
	opts["cell_shadow"] = false     # the mock shadow rides each cell's OWN face stylebox instead

	# the slot ladder → bag_card entries. A filled slot builds its real piece view at the kit-FITTED cell
	# size (make_content); the next/filled tiles tap (buy / retrieve) and dismiss; empty/locked are inert.
	var entries: Array = []
	for e in slot_plan(owned, max_slots, bag.size(), prices, start_slots):
		var kind := String(e.kind)
		var d := {"kind": kind}
		match kind:
			"filled":
				var idx: int = int(e.index)
				var code: int = int(bag[idx])
				d["make_content"] = func(sz: float) -> Control:
					var piece := PieceView.make_piece(code, sz)
					piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
					return piece
				d["on_tap"] = func() -> void:
					if on_retrieve.is_valid():
						on_retrieve.call(idx)
					dismiss.call()
			"next":
				# the next slot is the mock's AMBER tile: no sparkle halo, a dashed acorn placeholder,
				# and a cream acorn price chip. The price chip is built in _restyle_cell (the kit's own
				# green cost pill is the board's look, not the bag mock's), so no `cost` is passed here.
				var price: int = int(e.price)
				d["bag_price"] = price       # read by _restyle_cell (ignored by the kit)
				d["no_highlight"] = true
				d["on_tap"] = func() -> void:
					# on_buy_slot reports whether the slot was actually bought (a legacy void callback
					# reads as bought). Below the cap a refusal only ever means "you're short", so keep
					# the bag open and offer the shop instead of silently dismissing.
					var bought := true
					if on_buy_slot.is_valid():
						var res: Variant = on_buy_slot.call()
						bought = res == null or bool(res)
					if bought:
						dismiss.call()
					else:
						# read the balance FRESH (the one passed to open() is a snapshot that can have
						# moved since — a quest payout, a sold item), so the shortfall is true.
						var have := balance
						if on_balance.is_valid():
							have = int(on_balance.call())
						_need_more(host, have, price, on_open_shop, dismiss)
			"locked":
				# the mock gives every locked slot its own acorn cost pill (not just the next one)
				d["bag_price"] = int(e.price)
		entries.append(d)

	# the generators section (game-only — no analogue in bag.png), inserted below the grid by the kit.
	# Passed as a Callable so the kit hands it the dialog's FITTED cell opts: the generator tiles then
	# come out exactly the size of the slot cells above them.
	if not gen_bag.is_empty():
		opts["extra"] = func(cell_opts: Dictionary) -> Control:
			return _gen_section(Kit, cell_opts, gen_bag, gen_bag_tiers, on_place_gen, dismiss)

	var dialog: Control = Kit.bag_dialog(entries, balance, width, opts)
	_restyle_grid(Kit, dialog, entries)
	cc.add_child(dialog)
	FX.pop_in(dialog)
	return overlay

# --- the mock's cell dress ----------------------------------------------------------------------
# The kit builds ONE slot cell for board, discovery and bag alike (Kit.slot_cell). The bag mock asks
# that cell for four distinct faces, so the bag re-dresses its OWN cells after the fact — the same
# post-build idiom residents.gd uses for its shadows and badges, and no change to the shared builder.

## Walk the built grid (one cell per entry, in order) and dress each cell to its mock state.
static func _restyle_grid(Kit: GDScript, dialog: Control, entries: Array) -> void:
	var grids: Array = dialog.find_children("*", "GridContainer", true, false)
	if grids.is_empty():
		return
	var grid: GridContainer = grids[0]
	for i in mini(grid.get_child_count(), entries.size()):
		var cell := grid.get_child(i) as Control
		var e: Dictionary = entries[i]
		if cell != null:
			_restyle_cell(Kit, cell, String(e.get("kind", "empty")), int(e.get("bag_price", 0)))

## One cell → its mock face: sage (owned) · cream + dashed acorn (owned-empty) · amber + dashed acorn
## + cream price chip (next) · blue + padlock + pale price chip (locked).
static func _restyle_cell(Kit: GDScript, cell: Control, kind: String, price: int) -> void:
	var cw := cell.custom_minimum_size.x
	var ch := cell.custom_minimum_size.y
	if cw <= 0.0 or ch <= 0.0:
		return
	var fill := SAGE
	var paper := "texture_meadow.png"
	match kind:
		"empty":
			fill = CELL_CREAM; paper = "texture_cream.png"
		"next":
			fill = AMBER; paper = "texture_cream.png"
		"locked":
			fill = LOCK_BLUE; paper = "texture_receding_blue.png"
	_reface(cell, fill, paper)

	# the lock stamp: the mock's padlock on a locked slot; a dashed acorn on an empty / next one.
	# the kit's own mark is the board's acorn stamp, anchored to the WHOLE cell — drop it either way and
	# stamp the mock's padlock fresh, so the glyph's box is ours and cannot be re-derived by the anchors.
	var mark: Node = cell.find_child("SlotCellLockMark", true, false)
	if mark != null:
		mark.get_parent().remove_child(mark)
		mark.queue_free()
	if kind == "locked":
		var lock := _padlock(cw, ch)
		if lock != null:
			cell.add_child(lock)
	if kind == "empty" or kind == "next":
		cell.add_child(_dashed_acorn(cw, ch, price > 0))
	if price > 0:
		cell.add_child(_price_pill(Kit, price, cw, ch, kind == "next"))

## The mock's padlock stamp on a locked slot: icon_padlock tinted to the mock's dark slate, sized to
## its own VISIBLE bounds (the art is a 256² canvas with transparent margins) and docked above the
## price chip. expand_mode is set BEFORE size — the TextureRect min-size cache clamps up otherwise.
static func _padlock(cw: float, ch: float) -> Control:
	var path := Game.art(PADLOCK_ART)
	if not ResourceLoader.exists(path):
		return null
	var box := cw * PADLOCK_BOX          # the canvas box that renders a ~0.55 cw padlock
	var tr := TextureRect.new()
	tr.name = "BagSlotPadlock"
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture = load(path)
	tr.custom_minimum_size = Vector2.ZERO
	tr.size = Vector2(box, box)
	tr.position = Vector2((cw - box) * 0.5, ch * 0.40 - box * 0.5)
	tr.modulate = LOCK_TINT
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr

## Repaint a built cell's FACE: the mock's flat colour (carrying the paper grain) plus a lighter inset
## rim and the shared tinted drop-shadow, applied on the face's own stylebox so it hugs the corners.
static func _reface(cell: Control, fill: Color, paper_file: String) -> void:
	var bg := cell.find_child("SlotCellBackground", true, false) as Panel
	if bg == null:
		return
	var sb := bg.get_theme_stylebox("panel")
	if sb is StyleBoxFlat:
		var dsb: StyleBoxFlat = (sb as StyleBoxFlat).duplicate()
		dsb.bg_color = fill
		dsb.set_border_width_all(0)
		dsb.shadow_color = Color(SHADOW_TINT, 0.22)
		dsb.shadow_size = 12
		dsb.shadow_offset = Vector2(0, 6)
		bg.add_theme_stylebox_override("panel", dsb)
	var tr := bg.find_child("SlotCellPaperTexture", true, false) as TextureRect
	if tr != null:
		# the paper layer is drawn through a mask shader that OVERWRITES COLOR, so `modulate` cannot
		# tint it — recolour the grain into a cached texture instead.
		var tinted := _tinted_paper(paper_file, fill)
		if tinted != null:
			tr.texture = tinted
	# the mock's lighter INSET rim — its own overlay, because the paper-grain layer is drawn over the
	# face stylebox and would bury a stylebox border.
	var rim := Panel.new()
	rim.name = "BagSlotRim"
	rim.set_anchors_preset(Control.PRESET_FULL_RECT)
	rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rsb := StyleBoxFlat.new()
	rsb.draw_center = false
	rsb.set_border_width_all(4)
	rsb.border_color = fill.lightened(RIM_LIGHTEN)
	rsb.set_corner_radius_all(int(roundf(minf(bg.size.x, bg.size.y) * 0.18)))
	rsb.anti_aliasing = true
	rim.add_theme_stylebox_override("panel", rsb)
	bg.add_child(rim)

## The paper grain recoloured onto a flat face colour (grain kept as a signed offset about its own
## mean, so the texture survives any tint direction). Cached per file+tint — only a few ever exist.
static var _paper_cache: Dictionary = {}
static func _tinted_paper(file_name: String, tint: Color) -> Texture2D:
	var key := "%s|%s" % [file_name, tint.to_html(false)]
	if _paper_cache.has(key):
		return _paper_cache[key]
	var path := Game.art("ui/meadow_v2/%s" % file_name)
	var out: Texture2D = null
	if ResourceLoader.exists(path):
		var src: Texture2D = load(path)
		var img: Image = src.get_image() if src != null else null
		if img != null:
			img = img.duplicate()
			img.decompress()
			img.convert(Image.FORMAT_RGBA8)
			var data := img.get_data()
			var n := data.size() / 4
			var sr := 0; var sg := 0; var sb := 0
			for i in n:
				sr += data[i * 4]; sg += data[i * 4 + 1]; sb += data[i * 4 + 2]
			var mr := float(sr) / float(maxi(n, 1))
			var mg := float(sg) / float(maxi(n, 1))
			var mb := float(sb) / float(maxi(n, 1))
			for i in n:
				data[i * 4] = clampi(int(round(tint.r * 255.0 + (float(data[i * 4]) - mr))), 0, 255)
				data[i * 4 + 1] = clampi(int(round(tint.g * 255.0 + (float(data[i * 4 + 1]) - mg))), 0, 255)
				data[i * 4 + 2] = clampi(int(round(tint.b * 255.0 + (float(data[i * 4 + 2]) - mb))), 0, 255)
			out = ImageTexture.create_from_image(
				Image.create_from_data(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8, data))
	_paper_cache[key] = out
	return out

## The dashed acorn placeholder, sized + docked as in the mock (it rides higher when a price chip
## takes the cell's lower edge).
static func _dashed_acorn(cw: float, ch: float, has_pill: bool) -> Control:
	var w := cw * 0.78
	var h := w * 1.30
	var a := DashedAcorn.new()
	a.name = "BagSlotDashedAcorn"
	a.ink = DASH_INK
	a.thick = maxf(2.0, cw * 0.032)
	a.dash = maxf(5.0, cw * 0.105)
	a.gap = maxf(4.0, cw * 0.070)
	a.size = Vector2(w, h)
	a.position = Vector2((cw - w) * 0.5, ch * (0.44 if has_pill else 0.50) - h * 0.5)
	a.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return a

## A slot's acorn PRICE chip, docked on the cell's lower edge: cream on the amber next slot, pale
## blue on a locked one (the mock).
static func _price_pill(Kit: GDScript, price: int, cw: float, ch: float, cream: bool) -> Control:
	var w := cw * 0.83
	var h := cw * 0.48
	var p := Panel.new()
	p.name = "BagSlotPricePill"
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size = Vector2(w, h)
	p.position = Vector2((cw - w) * 0.5, ch - h - cw * 0.11)
	var sb := StyleBoxFlat.new()
	sb.bg_color = PILL_CREAM if cream else PILL_LOCK
	sb.set_corner_radius_all(int(h * 0.5))
	sb.shadow_color = Color(SHADOW_TINT, 0.16)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 3)
	p.add_theme_stylebox_override("panel", sb)
	var ipx := h * 0.92
	var icon: Control = Kit.make_icon("gem", ipx)
	icon.position = Vector2(h * 0.06, (h - ipx) * 0.5)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(icon)
	var lbl := Label.new()
	lbl.name = "BagSlotPriceText"
	lbl.text = str(price)
	lbl.add_theme_font_override("font", Kit.bold_font())
	lbl.add_theme_font_size_override("font_size", int(h * 0.60))
	lbl.add_theme_color_override("font_color", INK)
	lbl.add_theme_constant_override("outline_size", 0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.position = Vector2(h * 0.98, 0.0)
	lbl.size = Vector2(w - h * 1.10, h)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(lbl)
	return p

# The short-of-acorns prompt — raised OVER the open bag when the next slot's buy is refused, so the
# tap explains itself instead of just dismissing the bag. "Not now" closes only this card (the bag is
# still there, unchanged); the shop button closes both and hands off to `on_open_shop`.
#
# The face follows the authored mock (_concept/dialogs/insufficient_acorns_v1): a portrait parchment
# card carrying a plated acorn MEDALLION, a bold title, the two-line shortfall, a cream have/needed
# CHIP, and the two footer buttons. Every one of those is a SHARED kit atom (plated_icon · amount_chip
# · cta_button · pill_button), so a workbench knob change reaches this card too.
static func _need_more(host: Control, have: int, price: int, on_open_shop: Callable, dismiss_bag: Callable) -> Control:
	Audio.play("invalid_soft", -4.0)
	var Kit: GDScript = load(KIT_PATH)
	var plain: Font = Kit.plain_font() if Kit != null else null
	var bold: Font = Kit.bold_font() if Kit != null else null
	var overlay := Control.new()
	overlay.name = NEED_MORE_NAME
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = Overlay.MODAL_TOP_Z          # one notch above the bag it explains
	host.add_child(overlay)
	var veil := ColorRect.new()
	veil.color = Color(INK, 0.5)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(veil)
	# the veil dismisses THIS card only — the bag underneath stays open (a dead end would strand the tap).
	veil.gui_input.connect(func(ev: InputEvent) -> void:
		if (ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed):
			overlay.queue_free())
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(cc)
	# the card is sized as a FRACTION of the screen (the mock's card is ~3/4 of the frame), never fixed px.
	var vw: float = host.get_viewport_rect().size.x
	var cw: float = vw * CARD_W_FRAC
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Look.kit_panel("parchment"))
	card.custom_minimum_size = Vector2(cw, 0)
	cc.add_child(card)
	# the mock's card is PORTRAIT: generous inner margin + wide gaps between the five stacked parts.
	var pad := MarginContainer.new()
	for side in ["margin_top", "margin_bottom", "margin_left", "margin_right"]:
		pad.add_theme_constant_override(side, int(cw * 0.05))
	card.add_child(pad)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", int(cw * 0.06))
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	pad.add_child(col)
	# the acorn medallion — the shared plated icon on the round disc badge
	var medal: Control = Kit.plated_icon("gem", cw * MEDAL_FRAC)
	medal.self_modulate = Pal.SKY          # tints the DISC only; the acorn on top keeps its own colour
	medal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(medal)
	var title := Label.new()
	title.text = Strings.t("bag.need_more.ribbon")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if bold != null:
		title.add_theme_font_override("font", bold)          # the mock bolds every dialog title
	title.add_theme_font_size_override("font_size", FS.SUBHEADING)
	title.add_theme_color_override("font_color", INK)
	title.add_theme_constant_override("outline_size", 0)
	col.add_child(title)
	var body := Label.new()
	var n: int = max(price - have, 0)
	body.text = Strings.t("bag.need_more.body_one" if n == 1 else "bag.need_more.body") % n
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# an autowrap Label reports a min HEIGHT for its CURRENT width, so bound BOTH: a fixed wrap width
	# and a line cap, or a transient narrow width blows the card up (see the Godot min-size gotcha).
	body.custom_minimum_size.x = cw * 0.62
	body.size_flags_horizontal = Control.SIZE_SHRINK_CENTER   # take the MIN width → the text wraps there
	body.max_lines_visible = 3
	if plain != null:
		body.add_theme_font_override("font", plain)          # plain standard face, not the chunky display font
		body.add_theme_constant_override("outline_size", 0)
	body.add_theme_font_size_override("font_size", FS.EMPHASIS)
	body.add_theme_color_override("font_color", BARK)
	col.add_child(body)
	# the have / needed chip — the SAME cream amount_chip the mail cards wear
	var chip: Control = Kit.amount_chip("gem", "%d / %d" % [have, price], {"font": FS.STAT, "corner": 14.0})
	chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	chip.custom_minimum_size.x = cw * 0.54
	col.add_child(chip)
	# the footer: a cream "Not now" beside the green shop CTA, each half the card wide (mock proportions)
	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", int(cw * 0.04))
	col.add_child(btns)
	var later: Button = Kit.pill_button(Strings.t("bag.need_more.later"), \
		{"bg": "cream", "font": FS.SUBHEADING, "corner": 18.0, "shadow": true})
	later.custom_minimum_size = Vector2(cw * 0.42, cw * 0.155)
	later.pressed.connect(func() -> void: overlay.queue_free())
	btns.add_child(later)
	var shop: Button = Kit.cta_button(Strings.t("bag.need_more.shop"), \
		{"btn": {"font": FS.SUBHEADING, "corner": 18.0}})
	shop.custom_minimum_size = Vector2(cw * 0.42, cw * 0.155)
	shop.pressed.connect(func() -> void:
		overlay.queue_free()
		if dismiss_bag.is_valid():
			dismiss_bag.call()                              # the shop replaces the bag, never stacks on it
		if on_open_shop.is_valid():
			on_open_shop.call())
	btns.add_child(shop)
	FX.pop_in(card)
	return overlay

# The stored-generators row (a "Generators" label + a row of generator tiles) — built on the SAME
# bag_card surface as the slots: each tile carries the generator's sprite (sized to the fitted cell via
# make_content) and taps to place it. `cell_opts` are the dialog's FITTED cell opts (handed over by
# bag_dialog), so these tiles come out exactly the size of the slot cells in the grid above.
static func _gen_section(Kit: GDScript, cell_opts: Dictionary, gen_bag: Array, gen_bag_tiers: Array, on_place_gen: Callable, dismiss: Callable) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	var label := Label.new()
	label.text = String(Strings.t("bag.generators")).to_upper()   # the mock's all-caps section rule
	label.add_theme_font_override("font", Kit.bold_font())
	label.add_theme_font_size_override("font_size", FS.HEADING)
	label.add_theme_color_override("font_color", INK)
	label.add_theme_constant_override("outline_size", 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(label)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	col.add_child(row)
	# the mock's generator tiles are BIG landscape cards (≈2.6 × a slot cell wide), not slot-sized —
	# capped so a longer stash still fits the grid's width.
	var co: Dictionary = cell_opts.duplicate()
	var slot_w := float(co.get("cell_w", 116.0))
	var cols := maxi(1, int(co.get("cols", GRID_COLS)))
	var gap := float(co.get("cell_gap", GRID_GAP))
	var band := slot_w * float(cols) + gap * float(cols - 1)
	var n := maxi(1, gen_bag.size())
	var gw := minf(slot_w * 2.57, (band - 16.0 * float(n - 1)) / float(n))
	co["cell_w"] = gw
	co["cell_h"] = gw * 0.91
	co["cell_shadow"] = false
	co["content_frac"] = 0.86
	for i in gen_bag.size():
		var gid_str := String(gen_bag[i])
		var tier := int(gen_bag_tiers[i]) if i < gen_bag_tiers.size() else 1
		var gtex_path: String = Game.art(G.gen_tex(gid_str, tier))
		var make_gen := func(sz: float) -> Control:
			if ResourceLoader.exists(gtex_path):
				var gicon := TextureRect.new()
				gicon.texture = load(gtex_path)
				gicon.custom_minimum_size = Vector2(sz, sz)
				gicon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				gicon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				gicon.mouse_filter = Control.MOUSE_FILTER_IGNORE
				return gicon
			var fallback := Label.new()    # no art → the generator id, like the pre-kit overlay
			fallback.text = gid_str
			fallback.add_theme_font_size_override("font_size", FS.FOOTNOTE)
			fallback.add_theme_color_override("font_color", INK)
			fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
			return fallback
		var gcell: Control = Kit.bag_card({"kind": "filled", "make_content": make_gen, "icon": gid_str,
			"on_tap": func() -> void:
				if on_place_gen.is_valid():
					on_place_gen.call(gid_str)
				dismiss.call()}, co)
		_reface(gcell, SAGE, "texture_meadow.png")   # the same sage face the owned slots wear
		row.add_child(gcell)
	return col
