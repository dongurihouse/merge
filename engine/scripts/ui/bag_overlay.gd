extends RefCounted
## The full-bag OVERLAY builder — the modal that replaces the always-on inline bag row (BagView):
## the bottom-bar bag icon opens THIS, a dimmed-backdrop modal showing the WHOLE slot ladder (§5) as a
## grid of tiles — every owned slot (filled = a bagged piece, empty = an owned vacancy), the next
## purchasable slot (its 💎 price shown inside — no highlight; the price is the cue), and every locked
## future slot beyond it (a padlock, no price). Built on the SHARED ui kit (games/grove/ui_kit.gd),
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
const OVERLAY_NAME := "BagOverlay"
const NEED_MORE_NAME := "BagNeedMorePrompt"     ## the short-of-acorns prompt raised over an open bag
# the prompt card's proportions, read off the authored mock (card ≈ 3/4 of the frame, the medallion
# ≈ 1/4 of the card). Fractions, never px — the card tracks the screen like every other dialog.
const CARD_W_FRAC := 0.62     ## card width as a fraction of the SCREEN width (NARROWER than the bag
                              ## it sits on, so it reads as a card ON the dialog, not a replacement)
const MEDAL_FRAC := 0.26      ## medallion diameter as a fraction of the CARD width
## the SHOP's acorn sprite (the one on its first pouch card) — the prompt sends the player there, so it
## shows the same nut. Falls back to the plain wallet acorn if the ladder art is ever stripped.
const ACORN_ICON := "gem_t1"
const CHIP_WASH := Color(0.94, 0.89, 0.81)   ## the have/needed chip's paper, a shade warmer than the card
const Look = preload("res://engine/scripts/ui/skin.gd")
const Audio = preload("res://engine/scripts/core/audio.gd")

const INK = Pal.INK
const BARK = Pal.BARK

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

	# the dimmed backdrop — a flat scrim that dismisses on tap (the bag is a light modal with a
	# plain veil rather than the shop's blurred one). The scaffold's `dismiss` IS the single close
	# seam: fire on_close once (if valid), then free. Reused by the backdrop tap, the ✕ button,
	# a slot retrieve, and the next-slot buy.
	var modal := Overlay.modal(host, OVERLAY_NAME, {"on_dismiss": func() -> void:
		if on_close.is_valid():
			on_close.call()})
	var overlay: Control = modal["overlay"]
	var cc: CenterContainer = modal["center"]
	var dismiss: Callable = modal["dismiss"]

	# build the bag card from the SHARED kit — the same dialog the workbench previews. A missing kit
	# would only happen if the tools script were stripped from a build; bail to a bare veil if so.
	var Kit: GDScript = Game.kit_script()
	if Kit == null:
		push_warning("BagOverlay: ui kit missing at %s" % Game.kit())
		return overlay
	var kcfg: Dictionary = Game.kit_config()
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
					# inset 0: slot_cell already sizes `sz` by the SHARED content_frac, so the art spans
					# it fully — the default ITEM_INSET shrank the piece below the board's fill %.
					var piece := PieceView.make_piece(code, sz, 0.0)
					piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
					return piece
				d["on_tap"] = func() -> void:
					if on_retrieve.is_valid():
						on_retrieve.call(idx)
					dismiss.call()
			"next":
				# the next slot is the ONLY tile showing a price, and it wears no highlight — the
				# lone acorn cost in the ladder is the cue.
				var price: int = int(e.price)
				d["cost"] = price
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
		entries.append(d)

	# the generators section (game-only — no analogue in bag.png), inserted below the grid by the kit.
	# Passed as a Callable so the kit hands it the dialog's FITTED cell opts: the generator tiles then
	# come out exactly the size of the slot cells above them.
	if not gen_bag.is_empty():
		opts["extra"] = func(cell_opts: Dictionary) -> Control:
			return _gen_section(Kit, cell_opts, gen_bag, gen_bag_tiers, on_place_gen, dismiss, cfg.get("asked_lines", []))

	var dialog: Control = Kit.bag_dialog(entries, balance, width, opts)
	cc.add_child(dialog)
	FX.pop_in(dialog)
	return overlay

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
	var Kit: GDScript = Game.kit_script()
	var plain: Font = Kit.plain_font() if Kit != null else null
	var bold: Font = Kit.bold_font() if Kit != null else null
	# one notch above the bag it explains. The veil dismisses THIS card only — the bag underneath
	# stays open (a dead end would strand the tap).
	var modal := Overlay.modal(host, NEED_MORE_NAME, {"z": Overlay.MODAL_TOP_Z})
	var overlay: Control = modal["overlay"]
	var cc: CenterContainer = modal["center"]
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
	# the acorn medallion — a FLAT sky disc (code-drawn, no rim art) carrying the SHOP's acorn sprite,
	# so the prompt shows the player the very same acorn the storefront sells.
	var medal_px: float = cw * MEDAL_FRAC
	var medal := PanelContainer.new()
	var disc := StyleBoxFlat.new()
	disc.bg_color = Pal.SKY
	disc.set_corner_radius_all(int(medal_px))     # ≥ half the box → a circle
	disc.set_border_width_all(0)                  # no ring: the mock's disc is a plain paper cut
	disc.anti_aliasing = true
	var inset: float = medal_px * 0.19
	disc.content_margin_left = inset; disc.content_margin_right = inset
	disc.content_margin_top = inset; disc.content_margin_bottom = inset
	medal.add_theme_stylebox_override("panel", disc)
	medal.custom_minimum_size = Vector2(medal_px, medal_px)
	medal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	medal.add_child(Kit.make_icon(ACORN_ICON, medal_px * 0.62))
	col.add_child(medal)
	var title := Label.new()
	title.text = Strings.t("bag.need_more.ribbon")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if bold != null:
		title.add_theme_font_override("font", bold)          # the mock bolds every dialog title
	title.add_theme_font_size_override("font_size", FS.HEADING)
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
	body.add_theme_font_size_override("font_size", FS.BODY)
	body.add_theme_color_override("font_color", BARK)
	col.add_child(body)
	# the have / needed chip — the SAME cream amount_chip the mail cards wear
	var chip: Control = Kit.amount_chip(ACORN_ICON, "%d / %d" % [have, price], \
		{"font": FS.TITLE, "corner": 14.0, "paper": "cream", "border": 0.0})
	# cream paper on a cream card would vanish, so wash the chip's paper a shade warmer — it still reads
	# as an inset well without an outline. `modulate` is safe here: the kit drives state through
	# self_modulate, so the two don't fight.
	var chip_paper := chip.get_node_or_null("ButtonPaperSurface")
	if chip_paper != null:
		(chip_paper as CanvasItem).modulate = CHIP_WASH
	chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	chip.custom_minimum_size.x = cw * 0.54
	col.add_child(chip)
	# the footer: a cream "Not now" beside the green shop CTA, each half the card wide (mock proportions)
	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", int(cw * 0.04))
	col.add_child(btns)
	var later: Button = Kit.pill_button(Strings.t("bag.need_more.later"), \
		{"bg": "cream", "font": FS.HEADING, "corner": 18.0, "shadow": true, \
		"paper": "cream", "border": 0.0})
	later.custom_minimum_size = Vector2(cw * 0.42, cw * 0.155)
	later.pressed.connect(func() -> void: overlay.queue_free())
	btns.add_child(later)
	var shop: Button = Kit.cta_button(Strings.t("bag.need_more.shop"), \
		{"btn": {"font": FS.HEADING, "corner": 18.0, "border": 0.0}})
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
static func _gen_section(Kit: GDScript, cell_opts: Dictionary, gen_bag: Array, gen_bag_tiers: Array, on_place_gen: Callable, dismiss: Callable, asked_lines: Array = []) -> Control:
	# build the live generator cell dicts, then hand them to the SHARED kit row builder (the layout —
	# label + centred row — lives in Kit.bag_generators_section, so the workbench preview matches).
	var cells: Array = []
	for i in gen_bag.size():
		var gid_str := String(gen_bag[i])
		var tier := int(gen_bag_tiers[i]) if i < gen_bag_tiers.size() else 1
		var gtex_path: String = Game.art(G.gen_tex(gid_str, tier))
		# a stored generator a live quest NEEDS (its line is asked by the open fence) breathes,
		# mirroring the board's read: bright + pulsing = "place me".
		var wanted: bool = asked_lines.has(int(G.gen_def(G.GENERATORS, gid_str).get("line", -1)))
		var make_gen := func(sz: float) -> Control:
			if ResourceLoader.exists(gtex_path):
				var gicon := TextureRect.new()
				gicon.texture = load(gtex_path)
				gicon.custom_minimum_size = Vector2(sz, sz)
				gicon.size = Vector2(sz, sz)
				gicon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				gicon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				gicon.mouse_filter = Control.MOUSE_FILTER_IGNORE
				if wanted:
					# defer — breathe needs the node sized + in the tree to pivot from its centre
					(func() -> void: FX.breathe(gicon)).call_deferred()
				return gicon
			var fallback := Label.new()    # no art → the generator id, like the pre-kit overlay
			fallback.text = gid_str
			fallback.add_theme_font_size_override("font_size", FS.FINE)
			fallback.add_theme_color_override("font_color", INK)
			fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
			return fallback
		cells.append({"kind": "filled", "make_content": make_gen, "icon": gid_str,
			"on_tap": func() -> void:
				if on_place_gen.is_valid():
					on_place_gen.call(gid_str)
				dismiss.call()})
	return Kit.bag_generators_section(Strings.t("bag.generators"), cells, cell_opts)
