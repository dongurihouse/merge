extends RefCounted
## The full-bag OVERLAY builder — the modal that replaces the always-on inline bag row (BagView):
## the bottom-bar bag icon opens THIS, a dimmed-backdrop modal showing the WHOLE slot ladder (§5) as a
## grid of tiles — every owned slot (filled = a bagged piece, empty = an owned vacancy), the next
## purchasable slot (gold-tinted, its 💎 price shown inside), and every locked future slot beyond it
## (a padlock + its 💎 price below). Built on the SHARED ui kit (games/grove/tools/ui_workbench_kit.gd),
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
##     on_buy_slot: Callable, # () -> the next (gold) tile was tapped: buy the next slot
##     gen_bag: Array,        # (optional) stored generator ids — a row below the grid (game-only)
##     on_place_gen: Callable,# (optional) (id: String) -> a generator tile was tapped: place it
##     on_close: Callable })  # (optional) () -> the overlay was dismissed (any path)
## Returns the overlay root Control (already added to host).

const PieceView = preload("res://engine/scripts/ui/piece_view.gd")
const Strings = preload("res://engine/scripts/core/strings.gd")
const FX = preload("res://engine/scripts/ui/fx.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const G = preload("res://engine/scripts/core/content.gd")
const Overlay = preload("res://engine/scripts/ui/overlay.gd")
const Pal = Game.PALETTE
const KIT_PATH := "res://games/grove/tools/ui_workbench_kit.gd"   # the shared ui kit (frame · cell · pill)
const OVERLAY_NAME := "BagOverlay"

const INK = Pal.INK

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
	var gen_bag: Array = cfg.get("gen_bag", [])
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
	opts["banner_text"] = Strings.t("bag.banner_text")
	opts["caption"] = Strings.t("bag.caption")
	opts["on_close"] = dismiss

	# the responsive width: the saved bag width_pct × the live viewport (matching the other overlays)
	var vw: float = host.get_viewport_rect().size.x
	var width_pct: float = float((kcfg.get("bag", {}) as Dictionary).get("width_pct", 85))
	var width: float = vw * clampf(width_pct, 30.0, 100.0) / 100.0
	# the "Bag" ribbon is short, so floor it at a fraction of the SCREEN width (not the narrower dialog) — it
	# reads as a proper banner instead of a tiny stub. The shared frame honours this min in _banner.
	opts["banner_min_w"] = vw * Kit.BANNER_MIN_W_FRAC

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
				d["cost"] = int(e.price)
				d["on_tap"] = func() -> void:
					if on_buy_slot.is_valid():
						on_buy_slot.call()
					dismiss.call()
			"locked":
				d["cost"] = int(e.price)
		entries.append(d)

	# the generators section (game-only — no analogue in bag.png), inserted below the grid by the kit.
	if not gen_bag.is_empty():
		opts["extra"] = _gen_section(host, Kit, gen_bag, on_place_gen, dismiss)

	var dialog: Control = Kit.bag_dialog(entries, balance, width, opts)
	cc.add_child(dialog)
	FX.pop_in(dialog)
	return overlay

# The stored-generators row (a "Generators" label + a row of generator tiles) — built on the SAME
# bag_card surface as the slots: each tile carries the generator's sprite (sized to the fitted cell via
# make_content) and taps to place it.
static func _gen_section(host: Control, Kit: GDScript, gen_bag: Array, on_place_gen: Callable, dismiss: Callable) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.text = Strings.t("bag.generators")
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(INK, 0.75))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(label)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	col.add_child(row)
	var co: Dictionary = Kit.bag_card_opts_from_config(Kit.load_config(Kit.CONFIG_PATH))
	for gid in gen_bag:
		var gid_str := String(gid)
		var gtex_path: String = Game.art(G.gen_tex(gid_str))
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
			fallback.add_theme_font_size_override("font_size", 18)
			fallback.add_theme_color_override("font_color", INK)
			fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
			return fallback
		row.add_child(Kit.bag_card({"kind": "filled", "make_content": make_gen, "icon": gid_str,
			"on_tap": func() -> void:
				if on_place_gen.is_valid():
					on_place_gen.call(gid_str)
				dismiss.call()}, co))
	return col
