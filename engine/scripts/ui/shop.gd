extends RefCounted
## The Shop as the squirrel merchant's MARKET STALL (the §10 buy-side sink; owner:
## "the store menu shouldn't just be a list of buttons"). It sells, all behind an
## honest confirm where money is involved: water + a coin pouch (quick help), a few
## item-SHORTCUTS (buy a mid-tier piece to skip the grind) in a DETERMINISTICALLY-ROTATING
## featured band (a few at a time, §10), and the cash → premium acorn pouches. The cash
## packs are LIVE: confirming grants the diamonds directly (an honest "test build — nothing
## is charged"); a real store SDK replaces ONLY the middle of `_confirm_cash` — nothing else
## changes. §4 law: premium buys SPEED, never POSSIBILITY — a shortcut is a grind-skip to a
## piece you can already merge to. The grove's stock/prices/rotation count are owner-tunable
## in games/grove/grove_data.gd (§10 SHOP STOCK). Pure grant + rotation funcs are static and
## test-covered. (Cosmetic LOOKS were removed with the customization feature — parked in
## BACKLOG as the deferred "item & map customization" feature.)
## Look/feel values live in Tune (engine/scripts/core/tuning.gd → class Shop).

const Save = preload("res://engine/scripts/core/save.gd")
const Look = preload("res://engine/scripts/ui/skin.gd")
const PieceView = preload("res://engine/scripts/ui/piece_view.gd")   # real piece previews on item-shortcut cards
const G = preload("res://engine/scripts/core/content.gd")
const FX = preload("res://engine/scripts/ui/fx.gd")
const Audio = preload("res://engine/scripts/core/audio.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const D = Game.DATA                                               # the active game's data (§10 shop stock)
const Pal = Game.PALETTE
const Tune = preload("res://engine/scripts/core/tuning.gd").Shop   # the engine's shop dials

const INK = Pal.INK
const CREAM = Pal.CREAM
const STRAW = Pal.STRAW
const BARK = Pal.BARK

# The storefront FACE is built from the shared kit (the UI workbench), like the mailbox + daily login —
# so the shop's look is authored once in the workbench and never duplicated here. The buy LOGIC stays.
const KIT_PATH := "res://games/grove/tools/ui_workbench_kit.gd"
const SHOP_WIDTH_PCT := 85.0       # default shop-dialog width as a % of the screen (overridable in config)

# water price = G.REFILL_DIAMOND_COST — ONE source of truth with the paid rain
const COIN_PACK := 150
const COIN_PACK_GEM_COST := 5

# The cash → 💎 price ladder is OWNER-TUNABLE grove data (§10 full ladder up to a
# $49.99/$99.99-class top, T43). Re-exported so the UI + tests keep using Shop.CASH_PACKS.
const CASH_PACKS := D.CASH_PACKS
const STARTER_PACK := D.STARTER_PACK     # the one-time welcome bundle (§10)
const FIRST_BUY_MULT := D.FIRST_BUY_MULT # the first ladder pack grants ×this, once (§10)

# --- grants (pure; the UI calls these) --------------------------------------------

static func buy_water() -> bool:
	return Save.spend_diamonds(G.REFILL_DIAMOND_COST)

static func buy_coin_pack() -> bool:
	if not Save.spend_diamonds(COIN_PACK_GEM_COST):
		return false
	Save.add_coins(COIN_PACK)
	return true

# Grant a ladder cash pack (§4/§10 — LIVE IAP; in this build the confirm grants directly,
# an honest "test build — nothing is charged"; a real store SDK + receipt check replaces
# ONLY the confirm middle). The FIRST ladder pack a player ever buys is DOUBLED (the §10
# first-purchase doubler), then never again — the starter pack is a separate SKU and does
# NOT consume the doubler. Returns the 💎 actually granted (so the UI can celebrate the 2×).
static func grant_cash_pack(i: int) -> int:
	var base := int(CASH_PACKS[i].gems)
	var mult := 1
	if not Save.first_purchase_made():
		mult = int(FIRST_BUY_MULT)
		Save.set_first_purchase_made()
	Save.add_diamonds(base * mult)
	return base * mult

# Whether the next ladder pack would be doubled (the first-purchase offer still live).
static func first_buy_doubled() -> bool:
	return not Save.first_purchase_made()

# --- the starter pack (§10): a one-time, high-value, low-price welcome bundle ------
# Surfaced to NEW players only (claimable while not yet claimed). Grants 💎 directly and
# BANKS its water bonus (the board applies the credit on open, so it works even when the
# shop is opened from the map). Refuses a second claim (own-once). Returns the granted 💎
# (0 on refusal). Behind the same confirm-stub as the ladder; LIVE IAP from launch.
static func starter_available() -> bool:
	return not Save.starter_claimed()

static func grant_starter() -> int:
	if Save.starter_claimed():
		return 0
	Save.set_starter_claimed()
	var gems := int(STARTER_PACK.get("gems", 0))
	Save.add_diamonds(gems)
	Save.add_water_pending(int(STARTER_PACK.get("water", 0)))
	return gems

# --- item-shortcuts (§10): buy a mid-tier PIECE to skip the grind to it ------------
# Spends the offer's currency (coins for low tiers / 💎 for deeper ones) and QUEUES the
# piece into the pending grant. The board drains the queue into its bag on its next open
# (drain_pending below) — so the grant survives whether the shop is opened from the map
# (no live board) or over the board itself. Refuses (no spend, no grant) when broke.
static func buy_item_offer(i: int) -> bool:
	if i < 0 or i >= D.SHOP_ITEM_OFFERS.size():
		return false
	var off: Dictionary = D.SHOP_ITEM_OFFERS[i]
	if not _spend(String(off.currency), int(off.cost)):
		return false
	var g := Save.grove()
	var q: Array = g.get("shop_pending", [])
	q.append(int(off.code))
	g["shop_pending"] = q
	Save.grove_write()
	return true

# The queued item-shortcut codes awaiting pickup (the board drains these on open).
static func pending_pieces() -> Array:
	return Array(Save.grove().get("shop_pending", []))

# Drain up to `capacity` queued shortcut pieces into `bag` (mutated in place); the rest
# stay queued for next time. The board calls this on open with its current bag + capacity.
# Returns the number drained (so the caller can persist if any moved).
static func drain_pending(bag: Array, capacity: int) -> int:
	var g := Save.grove()
	var q: Array = g.get("shop_pending", [])
	var moved := 0
	while not q.is_empty() and bag.size() < capacity:
		bag.append(int(q.pop_front()))
		moved += 1
	if moved > 0:
		g["shop_pending"] = q
		Save.grove_write()
	return moved

# Spend a cost in the named currency ("coins" | "diamonds"). One seam for both shop sinks.
static func _spend(currency: String, cost: int) -> bool:
	if currency == "diamonds":
		return Save.spend_diamonds(cost)
	return Save.spend(cost, "shop")

# --- item-shortcut offers per shop (§10): a FEW skips, a FIXED set ------------------
# After the shop split each storefront shows only the shortcuts paid in ITS currency: the Coin
# shop the coin-priced skips, the Premium shop the 💎-priced ones. Capped at SHOP_FEATURED_COUNT,
# the same set on every open (no rotation/refresh/reroll — the cozy-bed call). Owner-curated via
# the order of SHOP_ITEM_OFFERS in grove_data.gd.
static func offers_for(currency: String) -> Array:
	var out: Array = []
	for off in D.SHOP_ITEM_OFFERS:
		if String(off.currency) == currency:
			out.append(off)
			if out.size() >= int(D.SHOP_FEATURED_COUNT):
				break
	return out

# --- the storefront ----------------------------------------------------------------
# Three focused stalls share ONE dialog (one set of buy flows + chrome): the WATER pill's + opens the
# water shop, the COIN pill's + the coin shop, the GEM pill's + the premium (acorn) shop. Each is `_open`
# with a different `kind` — the section list (`_sections`) and banner are filtered to that kind.
static func open_water(host: Control, opts: Dictionary = {}) -> void:
	_open(host, opts, "water")

static func open_coin(host: Control, opts: Dictionary = {}) -> void:
	_open(host, opts, "coin")

static func open_premium(host: Control, opts: Dictionary = {}) -> void:
	_open(host, opts, "premium")

# Back-compat / generic entry: the kind comes from opts (defaults to the premium stall).
static func open(host: Control, opts: Dictionary = {}) -> void:
	_open(host, opts, String(opts.get("kind", "premium")))

static func _open(host: Control, opts: Dictionary, kind: String) -> void:
	var Kit: GDScript = load(KIT_PATH)
	if Kit == null:
		push_warning("Shop: kit missing at %s" % KIT_PATH)
		return
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.add_child(overlay)
	# the backdrop: a BLURRED + warm-tinted + vignetted copy of the live scene, so the boring
	# flat dim becomes a cozy frosted backdrop that focuses the parchment. Falls back to a flat
	# dim if the screen-read shader can't compile.
	var veil := ColorRect.new()
	veil.color = Color(INK, Tune.VEIL_ALPHA)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.material = _backdrop_material()
	overlay.add_child(veil)
	veil.gui_input.connect(func(ev: InputEvent) -> void:
		if (ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed):
			overlay.queue_free())
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(cc)

	# The HUD bar IS the wallet (one source) — raise its panels above the blurred backdrop (kept crisp),
	# and capture its refs so buy feedback (fly-home / wiggle) targets it. Absent (a capture tool) → no-ops.
	var hud_wallet: Dictionary = opts.get("wallet", {})
	for p in hud_wallet.get("panels", []):
		if p != null and is_instance_valid(p) and (p as Node).get_parent() == host:
			host.move_child(p, host.get_child_count() - 1)

	# The storefront FACE is the SHARED kit shop_dialog (frame + centred-title dividers + cells), authored
	# in the workbench — same chrome as the mail + daily dialogs. Width is a % of the SCREEN (responsive).
	var vw: float = host.get_viewport_rect().size.x
	var cfg: Dictionary = Kit.load_config(Kit.CONFIG_PATH)
	var shop_cfg: Dictionary = cfg.get("shop", {})
	var pct: float = float(shop_cfg.get("width_pct", SHOP_WIDTH_PCT))
	var width: float = vw * clampf(pct, 30.0, 100.0) / 100.0
	# the hero size for the game-injected previews (piece art / the welcome bundle): matches the kit's own
	# icon ratio at the computed cell width, so the injected art reads the same size as the kit's gem icons.
	var cols: int = maxi(1, int(shop_cfg.get("cols", 3)))
	var hero_px: float = maxf(40.0, (width - 56.0 - float(cols - 1) * 12.0) / float(cols) * 0.52)

	var refs := {
		"coin": hud_wallet.get("coin", {"node": null, "label": null}),
		"gem": hud_wallet.get("gem", {"node": null, "label": null}),
		"overlay": overlay, "opts": opts, "host": host, "hero_px": hero_px, "kind": kind}

	# (re)build the storefront from the live wallet + stock; a buy rebuilds it in place to refresh
	# affordability, the first-buy ribbon, and the starter's one-time availability (the login.gd pattern).
	var rb := {"fn": Callable(), "first": true}
	refs["rb"] = rb
	rb.fn = func() -> void:
		if not is_instance_valid(cc):
			return
		for c in cc.get_children():
			c.queue_free()
		var sopts: Dictionary = Kit.shop_opts_from_config(cfg)
		sopts["banner_text"] = host.tr(_banner_for(kind))
		sopts["on_close"] = func() -> void: overlay.queue_free()
		# the workbench leaves list_max_h 0 (grow to fit, the gallery scrolls); on a PHONE the full ladder
		# is taller than the screen, so cap the inner height to the viewport — the shop then scrolls inside.
		if float(sopts.get("list_max_h", 0)) <= 0.0:
			sopts["list_max_h"] = host.get_viewport_rect().size.y * 0.72
		var dialog: Control = Kit.shop_dialog(_sections(refs), width, sopts)
		cc.add_child(dialog)
		_tag_buy_buttons(dialog)
		if rb.first:
			FX.pop_in(dialog)
			rb.first = false
	rb.fn.call()

# Tag the storefront's buy CTAs with the `shop_buy` meta the UI-shape smoke (_shop_rows) counts. The kit
# builds the buttons (no Button handed back), so we mark them here: a buy CTA is the only Button carrying
# TEXT (its price) — the info "i" is a textless icon Button, the ✕ is the textless DialogClose. This keeps
# the "survives storefront restyles" contract after the kit restyle moved button construction.
static func _tag_buy_buttons(dialog: Control) -> void:
	for b in dialog.find_children("*", "Button", true, false):
		if b is Button and String((b as Button).text) != "":
			b.set_meta("shop_buy", true)

# The banner title for each stall (the centred kit dialog header).
static func _banner_for(kind: String) -> String:
	match kind:
		"water": return "Water"
		"coin": return "Coins"
		_: return "Acorns"

# Build the live shop SECTIONS for the kit dialog, filtered to the open shop's KIND: the water stall
# shows the Fill-water card; the coin stall the Coin pouch + coin-priced shortcuts; the premium stall the
# 💎-priced shortcut + the one-time Welcome bundle + the Acorn-pouch ladder. Each card carries its data +
# buy/info callbacks + a build-time `affordable` flag (the kit dims the price when broke). Rebuilt on every buy.
static func _sections(refs: Dictionary) -> Array:
	match String(refs.get("kind", "premium")):
		"water": return _water_sections(refs)
		"coin": return _coin_sections(refs)
		_: return _premium_sections(refs)

# WATER shop — refill the can (paid in 💎). Offered only when the host can grant water (the board/map
# pass `water_grant`); without it the stall is empty (it is only ever reached WITH a grant in practice).
static func _water_sections(refs: Dictionary) -> Array:
	var host: Control = refs.host
	if not (refs.opts as Dictionary).has("water_grant"):
		return []
	var gems := Save.diamonds()
	var card := {
		"icon": "water", "label": host.tr("Fill water"),
		"price": str(int(G.REFILL_DIAMOND_COST)), "price_icon": "gem",
		"affordable": gems >= int(G.REFILL_DIAMOND_COST),
		"on_buy": func() -> void: _flow_water(refs),
		"on_info": func() -> void: _info_sheet(host, host.tr("Fill your water"),
			host.tr("Refills your watering can to full right away, so you can keep tending the garden without waiting for it to top up on its own."))}
	return [{"caption": host.tr("Water"), "cards": [card]}]

# COIN shop — the Coin pouch (grants coins) + the coin-priced item shortcuts (grind-skips paid in coins).
static func _coin_sections(refs: Dictionary) -> Array:
	var host: Control = refs.host
	var gems := Save.diamonds()
	var secs: Array = []
	var pouch := {
		"icon": "coin", "label": host.tr("Coin pouch"), "count": COIN_PACK,
		"price": str(COIN_PACK_GEM_COST), "price_icon": "gem",
		"affordable": gems >= COIN_PACK_GEM_COST,
		"on_buy": func() -> void: _flow_coins(refs),
		"on_info": func() -> void: _info_sheet(host, host.tr("Coin pouch"),
			host.tr("Adds %d coins to your pouch instantly — handy for restoring spots and buying from the shelf.") % COIN_PACK)}
	secs.append({"caption": host.tr("Quick help"), "cards": [pouch]})
	var feat: Array = []
	for offer in offers_for("coins"):
		feat.append(_offer_card(refs, offer))
	if not feat.is_empty():
		secs.append({"caption": host.tr("Featured"), "cards": feat})
	return secs

# PREMIUM shop — the 💎-priced item shortcut(s), the one-time Welcome bundle, and the cash → 💎 Acorn ladder.
static func _premium_sections(refs: Dictionary) -> Array:
	var host: Control = refs.host
	var hero_px: float = float(refs.hero_px)
	var secs: Array = []
	var feat: Array = []
	for offer in offers_for("diamonds"):
		feat.append(_offer_card(refs, offer))
	if not feat.is_empty():
		secs.append({"caption": host.tr("Featured"), "cards": feat})
	# Welcome — the one-time, high-value starter bundle (new players only, until claimed)
	if starter_available():
		secs.append({"caption": host.tr("Welcome gift"), "cards": [{
			"node": _starter_node(host, hero_px),
			"ribbon": host.tr("Welcome"),
			"price": String(STARTER_PACK.get("usd", "")),
			"on_buy": func() -> void: _confirm_starter(host, refs)}]})
	# Acorn pouches — the cash → 💎 ladder (escalating gem art + the merchandising ribbon)
	var packs: Array = []
	for i in CASH_PACKS.size():
		var pack: Dictionary = CASH_PACKS[i]
		var card := {
			"icon": _gem_icon_id(i), "count": int(pack.gems),
			"price": String(pack.usd),
			"on_buy": func() -> void: _confirm_cash(host, refs, i)}
		if first_buy_doubled():
			card["ribbon"] = host.tr("First buy x2")
		elif bool(pack.get("pop", false)):
			card["ribbon"] = host.tr("Popular")
		elif i == CASH_PACKS.size() - 1:
			card["ribbon"] = host.tr("Best value")
		packs.append(card)
	secs.append({"caption": host.tr("Acorn pouches"), "cards": packs})
	return secs

# One item-shortcut card — a REAL piece preview (the game-injected hero node) priced in the offer's
# currency (coins for low tiers / 💎 for deeper ones); buying queues the piece into the pending grant.
static func _offer_card(refs: Dictionary, offer: Dictionary) -> Dictionary:
	var host: Control = refs.host
	var hero_px: float = float(refs.hero_px)
	var coins := Save.coins()
	var gems := Save.diamonds()
	var code := int(offer.code)
	var cur := String(offer.currency)
	var cost := int(offer.cost)
	var idx := _offer_index(String(offer.id))
	var label := String(offer.get("label", ""))
	return {
		"node": PieceView.make_piece(code, hero_px),
		"label": label,
		"price": str(cost), "price_icon": ("gem" if cur == "diamonds" else "coin"),
		"affordable": (gems if cur == "diamonds" else coins) >= cost,
		"on_buy": func() -> void: _flow_item(refs, idx, cur, cost),
		"on_info": func() -> void: _info_sheet(host, label,
			host.tr("Skips you straight to tier %d of %s — the piece drops into your bag, ready to place on the board.") % [code % 100, label])}

# The escalating gem art id for ladder pack i (gem_t1…), falling back to the plain gem when the grove
# has more packs than tier sprites — mirrors the old _gem_card art ladder.
static func _gem_icon_id(i: int) -> String:
	var art := "gem_t%d" % (i + 1)
	return art if ResourceLoader.exists(Game.art("ui/currency/icon_%s.png" % art)) else "gem"

# The Welcome bundle's hero — the 💎 count beside its water bonus (two currencies in one compact node),
# injected into the kit card's centre.
static func _starter_node(host: Control, px: float) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", int(px * 0.12))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(Look.icon("gem", px * 0.62))
	var gn := Label.new()
	gn.text = str(int(STARTER_PACK.get("gems", 0)))
	gn.add_theme_font_size_override("font_size", int(px * 0.34))
	gn.add_theme_color_override("font_color", INK)
	gn.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(gn)
	var water_amt := int(STARTER_PACK.get("water", 0))
	if water_amt > 0:
		row.add_child(Look.icon("water", px * 0.5))
		var wn := Label.new()
		wn.text = "+%d" % water_amt
		wn.add_theme_font_size_override("font_size", int(px * 0.26))
		wn.add_theme_color_override("font_color", INK)
		wn.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		wn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(wn)
	return row

# --- buy flows (kit cards have no Button to hand the old _try_buy; these take refs + rebuild) --------
# A direct buy in `currency` ("gem"|"coin"): can't afford → wallet wiggles; else spend+grant, fly the
# grant home to the HUD wallet, and rebuild the storefront so affordability re-reads.
static func _flow_water(refs: Dictionary) -> void:
	var opts: Dictionary = refs.opts
	var act := func() -> bool:
		if not buy_water():
			return false
		(opts.water_grant as Callable).call()
		return true
	_buy(refs, "gem", int(G.REFILL_DIAMOND_COST), act, "water")

static func _flow_coins(refs: Dictionary) -> void:
	_buy(refs, "gem", COIN_PACK_GEM_COST, buy_coin_pack, "coin")

# An item-shortcut buy (coins or 💎): spend, queue the piece, drain to the live board if present.
static func _flow_item(refs: Dictionary, idx: int, currency: String, cost: int) -> void:
	var opts: Dictionary = refs.opts
	var grant := func() -> bool:
		if not buy_item_offer(idx):
			return false
		if opts.has("piece_grant"):
			(opts.piece_grant as Callable).call()
		return true
	_buy_currency(refs, ("gem" if currency == "diamonds" else "coin"), cost, grant, (refs.host as Control).tr("Into your bag"))

static func _buy(refs: Dictionary, currency: String, cost: int, action: Callable, fly_id: String) -> void:
	var host: Control = refs.host
	var have: int = Save.diamonds() if currency == "gem" else Save.coins()
	if have < cost:
		_need_more(refs, currency, cost - have)
		return
	if not bool(action.call()):
		return
	Audio.play("merge_success", -3.0, 1.2)
	var target := _wallet_node(refs, "coin" if fly_id == "coin" else "gem")
	if target != null:
		FX.fly_to_wallet(host, _fb_at(host), Look.icon(fly_id, Tune.FLY_ICON), target, func() -> void: _after_buy(refs))
	else:
		_after_buy(refs)

static func _buy_currency(refs: Dictionary, currency: String, cost: int, grant: Callable, ok_text: String) -> void:
	var host: Control = refs.host
	var have: int = Save.diamonds() if currency == "gem" else Save.coins()
	if have < cost:
		_need_more(refs, currency, cost - have)
		return
	if not bool(grant.call()):
		return
	Audio.play("merge_success", -3.0, 1.2)
	FX.floating_text(host, _fb_at(host), ok_text, STRAW, Tune.NEED_SIZE)
	_after_buy(refs)

static func _need_more(refs: Dictionary, currency: String, short: int) -> void:
	var host: Control = refs.host
	Audio.play("invalid_soft", -4.0)
	var chip := _wallet_node(refs, currency)
	if chip != null:
		FX.wobble(chip)
	FX.floating_text(host, _fb_at(host), host.tr("Need %d more") % short, CREAM, Tune.NEED_SIZE)

# A feedback anchor (floaters / fly-home start) — just above the screen centre, since the kit cards
# don't hand us a per-card button rect like the old card-buttons did.
static func _fb_at(host: Control) -> Vector2:
	return host.get_viewport_rect().size * Vector2(0.5, 0.42)

# After a successful buy: the HUD wallet refreshes (ticks to the new balances) and the storefront
# rebuilds so affordability, the first-buy ribbon and the starter's availability all re-read.
static func _after_buy(refs: Dictionary) -> void:
	var opts: Dictionary = refs.opts
	if opts.has("refresh"):
		(opts.refresh as Callable).call()
	var rb: Dictionary = refs.get("rb", {})
	if rb.has("fn") and (rb.fn as Callable).is_valid():
		(rb.fn as Callable).call()

# The index of an item offer by id (the stable handle the pure grant func takes).
static func _offer_index(id: String) -> int:
	for i in D.SHOP_ITEM_OFFERS.size():
		if String(D.SHOP_ITEM_OFFERS[i].id) == id:
			return i
	return -1

# The item-detail sheet the "i" opens (§10 product info) — a parchment modal in the confirm
# language: ribbon title + a body paragraph + a "Got it" close; tap the veil to dismiss. Read-only,
# never buys. (The card's "i" is the only path here, so it never collides with the buy press.)
static func _info_sheet(host: Control, title: String, body: String) -> void:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.add_child(overlay)
	var veil := ColorRect.new()
	veil.color = Color(INK, Tune.CONFIRM_VEIL_ALPHA)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(veil)
	veil.gui_input.connect(func(ev: InputEvent) -> void:
		if (ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed):
			overlay.queue_free())
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(cc)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Look.kit_panel("parchment"))
	card.custom_minimum_size = Vector2(Tune.INFO_SHEET_W, 0)
	cc.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", Tune.CONFIRM_COL_SEP)
	card.add_child(col)
	var ribbon := Look.title_ribbon(title, Tune.CONFIRM_TITLE_SIZE)
	ribbon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(ribbon)
	var para := Label.new()
	para.text = body
	para.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	para.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	para.add_theme_font_size_override("font_size", Tune.INFO_BODY_SIZE)
	para.add_theme_color_override("font_color", INK)
	col.add_child(para)
	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(btns)
	btns.add_child(Look.button(host.tr("Got it"), func() -> void: overlay.queue_free(), true))
	FX.pop_in(card)

# The blurred + warm-tinted + vignetted backdrop material (the §1 interim shop backdrop). A
# screen-read canvas shader: 9-tap box blur of the live scene, mixed toward a warm dark, with a
# radial vignette to focus the parchment. Returns a ShaderMaterial applied to the full-rect veil.
static func _backdrop_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\n" + \
		"uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;\n" + \
		"uniform float blur = 2.6;\n" + \
		"uniform vec4 tint : source_color = vec4(0.12, 0.086, 0.055, 1.0);\n" + \
		"uniform float tint_amt = 0.42;\n" + \
		"uniform float vignette = 0.55;\n" + \
		"void fragment() {\n" + \
		"\tvec2 ps = SCREEN_PIXEL_SIZE * blur;\n" + \
		"\tvec3 c = vec3(0.0);\n" + \
		"\tc += texture(screen_tex, SCREEN_UV + vec2(-1.0, -1.0) * ps).rgb;\n" + \
		"\tc += texture(screen_tex, SCREEN_UV + vec2( 0.0, -1.0) * ps).rgb;\n" + \
		"\tc += texture(screen_tex, SCREEN_UV + vec2( 1.0, -1.0) * ps).rgb;\n" + \
		"\tc += texture(screen_tex, SCREEN_UV + vec2(-1.0,  0.0) * ps).rgb;\n" + \
		"\tc += texture(screen_tex, SCREEN_UV).rgb;\n" + \
		"\tc += texture(screen_tex, SCREEN_UV + vec2( 1.0,  0.0) * ps).rgb;\n" + \
		"\tc += texture(screen_tex, SCREEN_UV + vec2(-1.0,  1.0) * ps).rgb;\n" + \
		"\tc += texture(screen_tex, SCREEN_UV + vec2( 0.0,  1.0) * ps).rgb;\n" + \
		"\tc += texture(screen_tex, SCREEN_UV + vec2( 1.0,  1.0) * ps).rgb;\n" + \
		"\tc /= 9.0;\n" + \
		"\tc = mix(c, tint.rgb, tint_amt);\n" + \
		"\tfloat d = distance(SCREEN_UV, vec2(0.5));\n" + \
		"\tc = mix(c, tint.rgb, clamp(d * vignette, 0.0, 1.0));\n" + \
		"\tCOLOR = vec4(c, 1.0);\n" + \
		"}\n"
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("blur", Tune.BACKDROP_BLUR)
	m.set_shader_parameter("tint", Tune.BACKDROP_TINT)
	m.set_shader_parameter("tint_amt", Tune.BACKDROP_TINT_AMT)
	m.set_shader_parameter("vignette", Tune.BACKDROP_VIGNETTE)
	return m

# The HUD wallet node for a currency ("coin"|"gem"), or null when the opener passed no wallet
# (e.g. a capture tool) — feedback then no-ops gracefully instead of touching a missing chip.
static func _wallet_node(refs: Dictionary, key: String) -> Control:
	var n: Variant = (refs.get(key, {}) as Dictionary).get("node")
	return n if (n != null and is_instance_valid(n)) else null

# The cash confirm: parchment, pop_in, the honest caption — confirming grants the
# diamonds directly (the future IAP hookup replaces exactly this middle).
# The FIRST ladder pack shows its DOUBLED count (the §10 first-purchase doubler is live),
# and a "first-buy doubled!" line — so the confirm matches what actually lands.
static func _confirm_cash(host: Control, refs: Dictionary, i: int) -> void:
	var pack: Dictionary = CASH_PACKS[i]
	var doubled := first_buy_doubled()
	var gems := int(pack.gems) * (int(FIRST_BUY_MULT) if doubled else 1)
	var sub := host.tr("first-buy bonus doubled!") if doubled else ""
	_confirm_gem_grant(host, refs, host.tr("Acorn pouch"),
		host.tr("%d for %s") % [gems, String(pack.usd)], sub, func() -> void:
			grant_cash_pack(i))

# The starter-pack confirm: same honest parchment confirm; confirming grants the bundle
# (💎 now + the water credit the board applies on open) exactly once.
static func _confirm_starter(host: Control, refs: Dictionary) -> void:
	var gems := int(STARTER_PACK.get("gems", 0))
	var water_amt := int(STARTER_PACK.get("water", 0))
	var line := host.tr("%d for %s") % [gems, String(STARTER_PACK.get("usd", ""))]
	var sub := host.tr("+%d water — a warm welcome") % water_amt if water_amt > 0 else ""
	_confirm_gem_grant(host, refs, host.tr("Welcome gift"), line, sub, func() -> void:
		grant_starter())

# The shared honest cash-confirm body (§10): parchment card, ribbon title, the 💎 line,
# an optional sub-line, the "(test build — nothing is charged)" note, Cancel/Confirm. On
# Confirm it runs `grant` (the pure grant that owns the actual currency math), flies a 💎
# to the wallet, and settles. A real store SDK + receipt check replaces ONLY the inside of
# `grant` + a guard around this Confirm — the frame, the note, and the wiring stay.
static func _confirm_gem_grant(host: Control, refs: Dictionary, title: String,
		line: String, sub: String, grant: Callable) -> void:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.add_child(overlay)
	var veil := ColorRect.new()
	veil.color = Color(INK, Tune.CONFIRM_VEIL_ALPHA)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(veil)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(cc)
	# S16: kit-normalized — parchment card, RIBBON title (no raw emoji: the gem
	# is an icon beside the count), btn_leaf pair SIDE BY SIDE, 0.5 scrim
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Look.kit_panel("parchment"))
	cc.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", Tune.CONFIRM_COL_SEP)
	card.add_child(col)
	# S16: kit-normalized title chip (Look.title_ribbon — same solid chip as the
	# shop header; the ribbon_title nine-patch collapsed invisibly here too).
	var ribbon := Look.title_ribbon(title, Tune.CONFIRM_TITLE_SIZE)
	ribbon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(ribbon)
	var what := HBoxContainer.new()
	what.alignment = BoxContainer.ALIGNMENT_CENTER
	what.add_theme_constant_override("separation", Tune.WHAT_SEP)
	col.add_child(what)
	what.add_child(Look.icon("gem", Tune.CONFIRM_GEM_ICON))
	var amount := Label.new()
	amount.text = line
	amount.add_theme_font_size_override("font_size", Tune.CONFIRM_AMOUNT_SIZE)
	amount.add_theme_color_override("font_color", INK)
	amount.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	what.add_child(amount)
	if sub != "":
		var subl := Label.new()
		subl.text = sub
		subl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		subl.add_theme_font_size_override("font_size", Tune.CONFIRM_NOTE_SIZE)
		subl.add_theme_color_override("font_color", STRAW)
		col.add_child(subl)
	var note := Label.new()
	note.text = host.tr("(test build — nothing is charged)")
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", Tune.CONFIRM_NOTE_SIZE)
	note.add_theme_color_override("font_color", BARK)
	col.add_child(note)
	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", Tune.BTNS_SEP)
	col.add_child(btns)
	btns.add_child(Look.button(host.tr("Cancel"), func() -> void: overlay.queue_free(), false))
	btns.add_child(Look.button(host.tr("Confirm"), func() -> void:
		grant.call()
		var at := card.get_global_rect().get_center()
		overlay.queue_free()
		var gem_n := _wallet_node(refs, "gem")
		if gem_n != null:
			FX.fly_to_wallet(host, at, Look.icon("gem", Tune.FLY_ICON), gem_n)
		_after_buy(refs), true))
	FX.pop_in(card)
