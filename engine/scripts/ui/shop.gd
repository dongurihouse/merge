extends RefCounted
## The Shop as the squirrel merchant's MARKET STALL (the §10 buy-side sink; owner:
## "the store menu shouldn't just be a list of buttons"). It sells, all behind an
## honest confirm where money is involved: water + a coin pouch (quick help), a few
## item-SHORTCUTS (buy a mid-tier piece to skip the grind) and cosmetic LOOKS in a
## DETERMINISTICALLY-ROTATING featured band (a few at a time, §10), and the cash →
## 💎 dewdrop pouches. The cash packs are LIVE: confirming grants the diamonds
## directly (an honest "test build — nothing is charged"); a real store SDK replaces
## ONLY the middle of `_confirm_cash` — nothing else changes. §4 law: premium buys
## SPEED + LOOKS, never POSSIBILITY — a shortcut is a grind-skip to a piece you can
## already merge to, a cosmetic only re-dresses. The grove's stock/prices/rotation
## count are owner-tunable in games/grove/grove_data.gd (§10 SHOP STOCK). Pure grant
## + rotation funcs are static and test-covered.
## Look/feel values live in Tune (engine/scripts/core/tuning.gd → class Shop).

const Save = preload("res://engine/scripts/core/save.gd")
const Look = preload("res://engine/scripts/ui/skin.gd")
const PieceView = preload("res://engine/scripts/ui/piece_view.gd")   # real piece previews on item-shortcut cards
const G = preload("res://engine/scripts/core/content.gd")
const FX = preload("res://engine/scripts/ui/fx.gd")
const Audio = preload("res://engine/scripts/core/audio.gd")
const Ads = preload("res://engine/scripts/core/ads.gd")            # §10 rewarded "free shop reroll" faucet
const Game = preload("res://engine/scripts/core/game.gd")
const D = Game.DATA                                               # the active game's data (§10 shop stock)
const Pal = Game.PALETTE
const Tune = preload("res://engine/scripts/core/tuning.gd").Shop   # the engine's shop dials

const INK = Pal.INK
const CREAM = Pal.CREAM
const STRAW = Pal.STRAW
const BARK = Pal.BARK

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

# --- cosmetics (§10): buy a LOOK (own-once) ----------------------------------------
# Spends the cosmetic's currency and unlocks the look in the grove blob. Owning a look
# changes nothing about possibility (§4 — buys looks, not power). Refuses a second buy of
# an already-owned look (no double-charge) and refuses when broke.
static func cosmetic_owned(id: String) -> bool:
	return bool(Save.grove().get("cosmetics", {}).get(id, false))

static func cosmetic_def(id: String) -> Dictionary:
	for c in D.SHOP_COSMETICS:
		if String(c.id) == id:
			return c
	return {}

static func buy_cosmetic(id: String) -> bool:
	var c := cosmetic_def(id)
	if c.is_empty() or cosmetic_owned(id):
		return false
	if not _spend(String(c.currency), int(c.cost)):
		return false
	var g := Save.grove()
	var owned: Dictionary = g.get("cosmetics", {})
	owned[id] = true
	g["cosmetics"] = owned
	Save.grove_write()
	return true

# Spend a cost in the named currency ("coins" | "diamonds"). One seam for both shop sinks.
static func _spend(currency: String, cost: int) -> bool:
	if currency == "diamonds":
		return Save.spend_diamonds(cost)
	return Save.spend(cost, "shop")

# --- rotating offers (§10): a FEW featured offers, deterministically ---------------
# The featured band shows SHOP_ROTATION_COUNT offers drawn from the combined item +
# cosmetic pool, selected by a SEED (the day index, or a future refresh counter) — NEVER
# randi(), so the spread is testable and stable within a refresh window. The seed picks a
# rotating START into a fixed shuffle order, so the same seed always yields the same set
# and advancing the seed slides the window. Owned cosmetics still appear (greyed in the
# UI) — owning one is harmless; the featured band is about discovery, not inventory.
static func shop_pool() -> Array:
	var pool: Array = []
	for off in D.SHOP_ITEM_OFFERS:
		pool.append({"kind": "item", "id": String(off.id), "def": off})
	for cos in D.SHOP_COSMETICS:
		pool.append({"kind": "cosmetic", "id": String(cos.id), "def": cos})
	return pool

# The current rotation seed: the day index (offline-stable, advances once per day). A
# future "free reroll" (§17 ads) would bump a saved counter added on top of this.
static func rotation_seed() -> int:
	return int(Time.get_unix_time_from_system() / 86400.0) + int(Save.grove().get("shop_reroll", 0))

# Deterministically pick SHOP_ROTATION_COUNT offers for `seed`. A fixed seeded shuffle of
# the pool gives a stable order; the seed rotates the window start over it, so each step
# slides to a fresh (wrapping) slice — same seed → same offers, seed+1 → rotated.
static func rotation_offers(seed: int) -> Array:
	var pool := shop_pool()
	var n: int = mini(int(D.SHOP_ROTATION_COUNT), pool.size())
	if n <= 0:
		return []
	var order := _seeded_order(pool.size())
	var start: int = ((seed % pool.size()) + pool.size()) % pool.size()
	var out: Array = []
	for k in n:
		out.append(pool[order[(start + k) % pool.size()]])
	return out

# A fixed permutation of [0..size) from a fixed seed (a tiny LCG Fisher–Yates) — the
# stable "shelf order" the rotation window slides over. Same `size` → same order always.
static func _seeded_order(size: int) -> Array:
	var idx: Array = []
	for k in size:
		idx.append(k)
	var s := 2654435761                       # a fixed mixing constant (Knuth) — order is deterministic
	for k in range(size - 1, 0, -1):
		s = (s * 1103515245 + 12345) & 0x7fffffff
		var j: int = s % (k + 1)
		var tmp = idx[k]
		idx[k] = idx[j]
		idx[j] = tmp
	return idx

# --- the storefront ----------------------------------------------------------------

static func open(host: Control, opts: Dictionary = {}) -> void:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.add_child(overlay)
	# the backdrop: a BLURRED + warm-tinted + vignetted copy of the live scene, so the boring
	# flat dim becomes a cozy frosted backdrop that focuses the parchment (interim until a
	# dedicated shop backdrop is generated — BACKLOG / merge_spec §10). Falls back to a flat
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

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Look.kit_panel("parchment"))
	var vw: float = host.get_viewport_rect().size.x
	card.custom_minimum_size = Vector2(minf(Tune.CARD_MAX_W, vw * Tune.CARD_VW_FRAC), 0)
	cc.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", Tune.COL_SEP)
	card.add_child(col)

	# the stall: banner art when generated, plank band until then; the title is
	# ENGINE text riding a ribbon (images never carry words — §0.3)
	var header := Control.new()
	header.custom_minimum_size = Vector2(0, Tune.HEADER_H)
	header.clip_contents = true
	col.add_child(header)
	if ResourceLoader.exists(Look.kit("shop_stall.png")):
		var art := TextureRect.new()
		art.texture = load(Look.kit("shop_stall.png"))
		art.set_anchors_preset(Control.PRESET_FULL_RECT)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		header.add_child(art)
	else:
		var band := Panel.new()
		band.set_anchors_preset(Control.PRESET_FULL_RECT)
		band.add_theme_stylebox_override("panel", Look.kit_panel("plank"))
		band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		header.add_child(band)
	# S11: the title rides a solid chip on the AWNING (Look.title_ribbon — the kit
	# ribbon_title nine-patch collapsed invisibly, so "Shop" used to float on the
	# squirrel's face). The chip sits at the top band — the mascot is never covered.
	var ribbon := Look.title_ribbon(host.tr("Shop"), Tune.TITLE_SIZE)
	ribbon.anchor_left = 0.5
	ribbon.anchor_right = 0.5
	ribbon.anchor_top = 0.0
	ribbon.anchor_bottom = 0.0
	ribbon.offset_top = Tune.RIBBON_TOP
	ribbon.grow_horizontal = Control.GROW_DIRECTION_BOTH
	ribbon.grow_vertical = Control.GROW_DIRECTION_END
	header.add_child(ribbon)

	# breathing room below the stall art
	var wpad := Control.new()
	wpad.custom_minimum_size = Vector2(0, Tune.SECTION_PAD)
	col.add_child(wpad)
	# The shop no longer draws its own currency strip — the HUD bar IS the wallet (one source,
	# no redundancy). The opener (hud.open_shop) passes the HUD's wallet refs so buy feedback
	# (fly-home / tick / "need more" wobble) targets it, and its panels so we can RAISE them
	# above the blurred backdrop (kept crisp + readable). When opened without them (a capture
	# tool), the feedback simply no-ops and nothing is raised.
	var hud_wallet: Dictionary = opts.get("wallet", {})
	for p in hud_wallet.get("panels", []):
		if p != null and is_instance_valid(p) and (p as Node).get_parent() == host:
			host.move_child(p, host.get_child_count() - 1)
	var refs := {
		"coin": hud_wallet.get("coin", {"node": null, "label": null}),
		"gem": hud_wallet.get("gem", {"node": null, "label": null}),
		"overlay": overlay, "opts": opts}

	# — Quick help —
	_divider(col, host.tr("Quick help"))
	var help_row := HBoxContainer.new()
	help_row.alignment = BoxContainer.ALIGNMENT_CENTER
	help_row.add_theme_constant_override("separation", Tune.ROW_SEP)
	col.add_child(help_row)
	if opts.has("water_grant"):
		var water_action := func() -> bool:
			if not buy_water():
				return false
			(opts.water_grant as Callable).call()
			return true
		help_row.add_child(_help_card(host, refs, "rain", host.tr("Fill your water"),
			host.tr("top up the can"), G.REFILL_DIAMOND_COST, water_action, "water",
			host.tr("Refills your watering can to full right away, so you can keep tending the garden without waiting for it to top up on its own.")))
	help_row.add_child(_help_card(host, refs, "coin", host.tr("Coin pouch"),
		host.tr("+%d acorns") % COIN_PACK, COIN_PACK_GEM_COST, buy_coin_pack, "coin",
		host.tr("Adds %d acorns to your pouch instantly — handy for restoring spots and buying from the shelf.") % COIN_PACK))

	# — Featured (§10): a FEW deterministically-rotating offers (item-shortcuts + looks),
	# the fresh "always something new" band — NOT the whole static pool.
	_divider(col, host.tr("Featured"), _clock_chip(_rotation_left_text()))
	var offer_row := HBoxContainer.new()
	offer_row.alignment = BoxContainer.ALIGNMENT_CENTER
	offer_row.add_theme_constant_override("separation", Tune.ROW_SEP)
	col.add_child(offer_row)
	for offer in rotation_offers(rotation_seed()):
		if String(offer.kind) == "item":
			offer_row.add_child(_item_card(host, refs, offer.def))
		else:
			offer_row.add_child(_cosmetic_card(host, refs, offer.def))
	# §10 rewarded "free shop reroll": a player-initiated watch-for-bonus that slides the band to a
	# fresh window (Ads gates the cap + cooldown; rotation_seed folds the bump in). Shown only when
	# a watch is available; pressing claims the ad and rebuilds the storefront with the new offers.
	if Ads.can_show("shop_reroll"):
		var reroll_row := HBoxContainer.new()
		reroll_row.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_child(reroll_row)
		var reroll := Look.button(host.tr("Watch ☁ → fresh offers"), func() -> void:
			if bool(Ads.claim("shop_reroll").get("ok", false)):
				overlay.queue_free()
				open(host, opts)
			, false)
		reroll.name = "RerollFeatured"
		reroll_row.add_child(reroll)
		Look.attach_badge(reroll, Look.badge("dot"))   # a ready free reroll is actionable (shared sticker badge)

	# — Starter gift (§10): a one-time, high-value welcome bundle, shown to new players
	# only (until claimed). The single highest-converting IAP in mobile.
	if starter_available():
		_divider(col, host.tr("Welcome gift"))
		var starter_row := HBoxContainer.new()
		starter_row.alignment = BoxContainer.ALIGNMENT_CENTER
		starter_row.add_theme_constant_override("separation", Tune.ROW_SEP)
		col.add_child(starter_row)
		starter_row.add_child(_starter_card(host, refs))

	# — Dewdrop pouches (cash → diamonds; confirm-only) — the full $0.99…$99.99 ladder shows in
	# a 3-wide GRID (2 rows) so EVERY tier — including the whale $49.99/$99.99 — is visible at
	# once, no hidden scroll. 3*GEM_CARD.x + 2*HSEP stays inside the parchment inner width.
	_divider(col, host.tr("Dewdrop pouches"))
	var gem_grid := GridContainer.new()
	gem_grid.columns = Tune.GEM_GRID_COLS
	gem_grid.add_theme_constant_override("h_separation", Tune.GEM_GRID_HSEP)
	gem_grid.add_theme_constant_override("v_separation", Tune.GEM_GRID_VSEP)
	gem_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(gem_grid)
	for i in CASH_PACKS.size():
		gem_grid.add_child(_gem_card(host, refs, i))
	var foot := Control.new()
	foot.custom_minimum_size = Vector2(0, Tune.SECTION_PAD)
	col.add_child(foot)

	# the round ✕ rides the card's top-right corner (placed after layout)
	var x_btn := Button.new()
	x_btn.focus_mode = Control.FOCUS_NONE
	x_btn.custom_minimum_size = Vector2(Tune.X_BTN, Tune.X_BTN)
	# A RED circular close disc (the kit btn_round art read as a compass ornament, not a control).
	var xs := StyleBoxFlat.new()
	xs.bg_color = Tune.X_BG
	xs.set_corner_radius_all(Tune.X_RADIUS)
	xs.set_border_width_all(Tune.X_BORDER_W)
	xs.border_color = Tune.X_EDGE
	x_btn.add_theme_stylebox_override("normal", xs)
	x_btn.add_theme_stylebox_override("hover", xs)
	var xp: StyleBoxFlat = xs.duplicate()
	xp.bg_color = Tune.X_BG_PRESSED
	x_btn.add_theme_stylebox_override("pressed", xp)
	x_btn.text = "✕"
	x_btn.add_theme_font_size_override("font_size", Tune.X_FONT)
	x_btn.add_theme_color_override("font_color", CREAM)
	Look.add_press_juice(x_btn)
	x_btn.pressed.connect(func() -> void: overlay.queue_free())
	overlay.add_child(x_btn)
	# S15: the ✕ docks INSIDE the parchment's top-right (same close treatment
	# as the interior's round button) — it no longer floats on the awning corner
	var place_x := func() -> void:
		if not is_instance_valid(card) or not is_instance_valid(x_btn):
			return                              # the overlay was closed before this deferred call ran (e.g. a reroll rebuild)
		var r := card.get_global_rect()
		x_btn.global_position = Vector2(r.position.x + r.size.x - Tune.X_BTN - Tune.X_MARGIN, r.position.y + Tune.X_MARGIN)
	card.resized.connect(place_x)
	place_x.call_deferred()

	FX.pop_in(card)
	FX.scatter_in([help_row, offer_row, gem_grid], Tune.SCATTER_DELAY)

# A thin sprig divider with a caption (divider_vine art when generated).
# S13: the caption is a parchment TAB chip, baseline-aligned with its vine —
# not bare text floating at the parchment edge.
static func _divider(col: VBoxContainer, caption: String, trailing: Control = null) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", Tune.DIV_SEP)
	col.add_child(row)
	var tab := PanelContainer.new()
	var ts := StyleBoxFlat.new()
	ts.bg_color = Tune.TAB_BG
	ts.set_corner_radius_all(Tune.TAB_RADIUS)
	ts.set_border_width_all(Tune.TAB_BORDER_W)
	ts.border_color = Color(BARK, Tune.TAB_EDGE_ALPHA)
	ts.content_margin_left = Tune.TAB_PAD_X
	ts.content_margin_right = Tune.TAB_PAD_X
	ts.content_margin_top = Tune.TAB_PAD_T
	ts.content_margin_bottom = Tune.TAB_PAD_B
	tab.add_theme_stylebox_override("panel", ts)
	tab.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var cap := Label.new()
	cap.text = caption
	cap.add_theme_font_size_override("font_size", Tune.DIV_CAP_SIZE)
	cap.add_theme_color_override("font_color", Color(INK, Tune.DIV_CAP_INK_ALPHA))
	tab.add_child(cap)
	row.add_child(tab)
	if trailing != null:
		trailing.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(trailing)               # a chip riding between the caption tab and the vine (e.g. the Featured countdown)
	if ResourceLoader.exists(Look.kit("divider_vine.png")):
		var vine := TextureRect.new()
		vine.texture = load(Look.kit("divider_vine.png"))
		vine.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		# the vine art is a 768×64 leafy STRIP (12:1) made to span. Shown KEEP_ASPECT_CENTERED in a
		# row tall enough (VINE_H) that the strip is always WIDTH-limited, so the WHOLE leafy vine
		# scales to fill the gap from the tab to the card's right edge — consistent across rows.
		# (At a short VINE_H it floated a sprig mid-gap; SCALE flattened it; COVERED cropped the
		# leaves to a bare stem.)
		# COVER the gap with the leafy strip, keeping its horizontal proportions (only outer leaf
		# tips crop) so the WHOLE vine spans from the tab to the card's right edge on every row.
		vine.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		vine.clip_contents = true
		vine.custom_minimum_size = Vector2(0, Tune.VINE_H)
		vine.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vine.size_flags_vertical = Control.SIZE_FILL
		row.custom_minimum_size = Vector2(0, Tune.VINE_H)     # only force the row tall when the real vine is present (fallback stays a thin rule)
		row.add_child(vine)
	else:
		var line := ColorRect.new()
		line.color = Color(BARK, Tune.LINE_ALPHA)
		line.custom_minimum_size = Vector2(0, Tune.LINE_H)
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(line)

# One "Quick help" card: icon, title, caption, gem price chip. Whole card presses.
static func _help_card(host: Control, refs: Dictionary, icon_id: String, title: String,
		caption: String, cost: int, action: Callable, fly_id: String, info: String) -> Button:
	var b := _card_button(Tune.HELP_CARD)
	var inner := VBoxContainer.new()
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_theme_constant_override("separation", Tune.CARD_INNER_SEP)
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(inner)
	inner.add_child(_on_plate(Look.icon(icon_id, Tune.HERO_ICON)))
	var t := Label.new()
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", Tune.HELP_TITLE_SIZE)
	t.add_theme_color_override("font_color", INK)
	inner.add_child(t)
	var c := Label.new()
	c.text = caption
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_theme_font_size_override("font_size", Tune.HELP_CAP_SIZE)
	c.add_theme_color_override("font_color", Color(BARK, Tune.HELP_CAP_BARK_ALPHA))
	inner.add_child(c)
	inner.add_child(_price_pill(str(cost), "gem"))
	b.set_meta("shop_buy", true)
	b.set_meta("gem_cost", cost)
	b.pressed.connect(func() -> void:
		_try_buy(host, refs, b, cost, action, fly_id))
	_overlay_corner(b, _info_badge(host, title, info), Tune.INFO_SIZE, Tune.INFO_MARGIN, false, true)
	_apply_afford(b)
	return b

# One item-shortcut card (§10): a real PIECE preview, the line name + tier, the price
# chip (coins or 💎). Whole card presses → buy: spend, queue the piece into the bag, and —
# if the host is the live board (opts.piece_grant) — drain it onto the board now.
static func _item_card(host: Control, refs: Dictionary, off: Dictionary) -> Button:
	var b := _card_button(Tune.FEATURED_CARD)
	var inner := VBoxContainer.new()
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_theme_constant_override("separation", Tune.CARD_INNER_SEP)
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(inner)
	var code := int(off.code)
	inner.add_child(_on_plate(PieceView.make_piece(code, Tune.HERO_ICON)))
	var t := Label.new()
	t.text = String(off.get("label", ""))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", Tune.HELP_TITLE_SIZE)
	t.add_theme_color_override("font_color", INK)
	inner.add_child(t)
	var c := Label.new()
	c.text = host.tr("skip to tier %d") % (code % 100)
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_theme_font_size_override("font_size", Tune.HELP_CAP_SIZE)
	c.add_theme_color_override("font_color", Color(BARK, Tune.HELP_CAP_BARK_ALPHA))
	inner.add_child(c)
	var cur := String(off.currency)
	var cost := int(off.cost)
	inner.add_child(_price_pill(str(cost), "gem" if cur == "diamonds" else "coin"))
	b.set_meta("shop_buy", true)
	b.set_meta("coin_cost" if cur == "coins" else "gem_cost", cost)
	var idx := _offer_index(String(off.id))
	b.pressed.connect(func() -> void:
		_try_buy_currency(host, refs, b, cur, cost, func() -> bool:
			if not buy_item_offer(idx):
				return false
			if (refs.opts as Dictionary).has("piece_grant"):
				((refs.opts as Dictionary).piece_grant as Callable).call()
			return true, host.tr("Into your bag")))
	var info := host.tr("Skips you straight to tier %d of %s — the piece drops into your bag, ready to place on the board.") % [code % 100, String(off.get("label", host.tr("this line")))]
	_overlay_corner(b, _info_badge(host, String(off.get("label", "")), info), Tune.INFO_SIZE, Tune.INFO_MARGIN, false, true)
	_apply_afford(b)
	return b

# One cosmetic card (§10): a tint SWATCH, the look name, the price chip. Whole card
# presses → buy: spend + unlock the look (own-once). An already-owned look shows an
# "Owned" badge and a no-op press (no double-charge).
static func _cosmetic_card(host: Control, refs: Dictionary, cos: Dictionary) -> Button:
	var b := _card_button(Tune.FEATURED_CARD)
	var inner := VBoxContainer.new()
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_theme_constant_override("separation", Tune.CARD_INNER_SEP)
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(inner)
	var id := String(cos.id)
	var owned := cosmetic_owned(id)
	# the swatch — a rounded chip in the look's tint (the look preview)
	var sw := PanelContainer.new()
	var ss := StyleBoxFlat.new()
	ss.bg_color = Color(cos.tint)
	ss.set_corner_radius_all(Tune.SWATCH_RADIUS)
	ss.set_border_width_all(Tune.SWATCH_BORDER_W)
	ss.border_color = Color(BARK, Tune.CARD_EDGE_ALPHA)
	sw.add_theme_stylebox_override("panel", ss)
	sw.custom_minimum_size = Vector2(Tune.SWATCH_SIZE, Tune.SWATCH_SIZE)
	sw.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(sw)
	var t := Label.new()
	t.text = String(cos.name)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", Tune.HELP_TITLE_SIZE)
	t.add_theme_color_override("font_color", INK)
	inner.add_child(t)
	var c := Label.new()
	c.text = host.tr("Owned") if owned else host.tr("a grove look")
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_theme_font_size_override("font_size", Tune.HELP_CAP_SIZE)
	c.add_theme_color_override("font_color", Color(BARK, Tune.HELP_CAP_BARK_ALPHA))
	inner.add_child(c)
	var cur := String(cos.currency)
	var cost := int(cos.cost)
	if owned:
		var got := Look.icon("check", Tune.HELP_PRICE_SIZE)
		got.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		inner.add_child(got)
		b.set_meta("owned", true)
	else:
		inner.add_child(_price_pill(str(cost), "gem" if cur == "diamonds" else "coin"))
		b.set_meta("shop_buy", true)
		b.set_meta("coin_cost" if cur == "coins" else "gem_cost", cost)
	b.pressed.connect(func() -> void:
		if cosmetic_owned(id):
			Audio.play("invalid_soft", -6.0)
			return
		_try_buy_currency(host, refs, b, cur, cost, func() -> bool:
			return buy_cosmetic(id), host.tr("Unlocked!")))
	_overlay_corner(b, _info_badge(host, String(cos.name),
		host.tr("A new look for your grove board. Yours to keep once unlocked.")), Tune.INFO_SIZE, Tune.INFO_MARGIN, false, true)
	_apply_afford(b)
	return b

# The index of an item offer by id (the stable handle the pure grant func takes).
static func _offer_index(id: String) -> int:
	for i in D.SHOP_ITEM_OFFERS.size():
		if String(D.SHOP_ITEM_OFFERS[i].id) == id:
			return i
	return -1

# One cash pack card: gem art/icon, the count, the $ price. Middle = "Popular".
static func _gem_card(host: Control, refs: Dictionary, i: int) -> Button:
	var pack: Dictionary = CASH_PACKS[i]
	var b := _card_button(Tune.GEM_CARD)
	var inner := VBoxContainer.new()
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_theme_constant_override("separation", Tune.CARD_INNER_SEP)
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(inner)
	# The badge rides a FIXED-height slot (empty when un-badged) so a "Popular"/"2×" tag never
	# shoves this card's icon/count/price below its un-tagged row-mates (the §4 alignment fix).
	# The first-ever pack shows "2×" (the §10 first-purchase doubler); otherwise the
	# merchandised pack shows "Popular".
	var slot := CenterContainer.new()
	slot.custom_minimum_size = Vector2(0, Tune.BADGE_SLOT_H)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(slot)
	var badge_text := ""
	if first_buy_doubled():
		badge_text = host.tr("First buy x2")
	elif bool(pack.get("pop", false)):
		badge_text = host.tr("Popular")
	elif i == CASH_PACKS.size() - 1:
		badge_text = host.tr("Best value")     # the whale pack (best 💎/$ rate) — crown it
	if badge_text != "":
		slot.add_child(_badge(badge_text))
	# scale the cluster by tier so a bigger pack LOOKS bigger (the value ladder reads at a glance);
	# the icon sits in a FIXED-height slot (= GEM_ICON_MAX) centred, so a smaller cluster never
	# shoves this card's count/price up relative to its row-mates (keeps the grid row aligned).
	var frac := float(i) / float(maxi(1, CASH_PACKS.size() - 1))
	var icon_slot := CenterContainer.new()
	icon_slot.custom_minimum_size = Vector2(0, Tune.GEM_ICON_MAX)
	icon_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(icon_slot)
	icon_slot.add_child(Look.icon("gem", lerpf(Tune.GEM_ICON_MIN, Tune.GEM_ICON_MAX, frac)))
	var n := Label.new()
	n.text = str(int(pack.gems))
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.add_theme_font_size_override("font_size", Tune.GEM_COUNT_SIZE)
	n.add_theme_color_override("font_color", INK)
	inner.add_child(n)
	inner.add_child(_price_pill(String(pack.usd)))
	b.set_meta("shop_buy", true)
	b.set_meta("shop_cash", i)
	b.pressed.connect(func() -> void:
		_confirm_cash(host, refs, i))
	return b

# The starter-pack card (§10): a wide welcome card — a "Welcome" badge, the 💎 count +
# its water bonus, the low price. Whole card presses → the confirm grants directly.
static func _starter_card(host: Control, refs: Dictionary) -> Button:
	var b := _card_button(Tune.STARTER_CARD)   # a wide welcome BANNER (not a narrow pouch) so the two-currency bundle fits one row
	var inner := VBoxContainer.new()
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_theme_constant_override("separation", Tune.CARD_INNER_SEP)
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(inner)
	inner.add_child(_badge(host.tr("Welcome")))
	var what := HBoxContainer.new()
	what.alignment = BoxContainer.ALIGNMENT_CENTER
	what.add_theme_constant_override("separation", Tune.WHAT_SEP)
	what.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(what)
	what.add_child(Look.icon("gem", Tune.GEM_ICON))
	var n := Label.new()
	n.text = str(int(STARTER_PACK.get("gems", 0)))
	n.add_theme_font_size_override("font_size", Tune.GEM_COUNT_SIZE)
	n.add_theme_color_override("font_color", INK)
	n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	what.add_child(n)
	var water_amt := int(STARTER_PACK.get("water", 0))
	if water_amt > 0:
		var wic := Look.icon("water", Tune.HELP_ICON)
		wic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		what.add_child(wic)
		var wn := Label.new()
		wn.text = "+%d" % water_amt
		wn.add_theme_font_size_override("font_size", Tune.HELP_PRICE_SIZE)
		wn.add_theme_color_override("font_color", INK)
		wn.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		what.add_child(wn)
	inner.add_child(_price_pill(String(STARTER_PACK.get("usd", ""))))
	b.set_meta("shop_buy", true)
	b.set_meta("shop_starter", true)
	b.pressed.connect(func() -> void:
		_confirm_starter(host, refs))
	Look.attach_badge(b, Look.badge("dot"))   # an unclaimed welcome gift is always actionable (shared sticker badge)
	return b

# A small STRAW pill badge ("Popular" / "2× first buy" / "Best value") for a cash card.
static func _badge(text: String) -> PanelContainer:
	var pop := PanelContainer.new()
	var pp := StyleBoxFlat.new()
	pp.bg_color = STRAW
	pp.set_corner_radius_all(Tune.POP_RADIUS)
	pp.content_margin_left = Tune.POP_PAD_X
	pp.content_margin_right = Tune.POP_PAD_X
	pp.content_margin_top = Tune.POP_PAD_Y
	pp.content_margin_bottom = Tune.POP_PAD_Y
	pop.add_theme_stylebox_override("panel", pp)
	var pl := Label.new()
	pl.text = text
	pl.add_theme_font_size_override("font_size", Tune.POP_SIZE)
	pl.add_theme_color_override("font_color", INK)
	pop.add_child(pl)
	pop.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return pop

# The BUY pill — ONE source for every price on a card (help / featured / cosmetic / cash / starter).
# White text on leaf-GREEN (Pal.BTN_PRIMARY, the game's primary-CTA colour), fully rounded with a
# raised shadow, optionally led by a currency glyph, so the price reads as the tappable buy button
# (the whole card presses; this pill is its visual CTA). Named "BuyPill" so _apply_afford can dim
# THIS, not the whole card. `icon_id` "" = a plain $ price (no glyph). (Was a brown #5A3F28 pebble.)
static func _price_pill(text: String, icon_id: String = "") -> PanelContainer:
	var pill := PanelContainer.new()
	pill.name = "BuyPill"
	var s := StyleBoxFlat.new()
	s.bg_color = Pal.BTN_PRIMARY
	s.set_corner_radius_all(Tune.BUY_RADIUS)
	s.set_border_width_all(Tune.BUY_BORDER_W)
	s.border_color = Pal.BTN_PRIMARY_EDGE
	s.shadow_color = Tune.BUY_SHADOW
	s.shadow_size = Tune.BUY_SHADOW_SIZE
	s.shadow_offset = Tune.BUY_SHADOW_OFFSET
	s.content_margin_left = Tune.BUY_PAD_X
	s.content_margin_right = Tune.BUY_PAD_X
	s.content_margin_top = Tune.BUY_PAD_T
	s.content_margin_bottom = Tune.BUY_PAD_B
	pill.add_theme_stylebox_override("panel", s)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", Tune.PRICE_ROW_SEP)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(row)
	if icon_id != "":
		var ic := Look.icon(icon_id, Tune.PRICE_ICON)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(ic)
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", Tune.BUY_SIZE)
	l.add_theme_color_override("font_color", CREAM)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return pill

# A product icon / piece preview seated on a soft honey disc — the HERO of a help/featured card,
# so the art pops off the cream parchment instead of floating tiny + faint.
static func _on_plate(art: Control) -> Control:
	var plate := PanelContainer.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = Tune.ICON_PLATE_BG
	ps.set_corner_radius_all(int(Tune.ICON_PLATE / 2.0))
	ps.set_border_width_all(2)
	ps.border_color = Color(BARK, Tune.ICON_PLATE_EDGE_ALPHA)
	plate.add_theme_stylebox_override("panel", ps)
	plate.custom_minimum_size = Vector2(Tune.ICON_PLATE, Tune.ICON_PLATE)
	plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(cc)
	cc.add_child(art)
	return plate

# The per-card "i" info badge — a small blue disc that opens the item's detail sheet. It is a REAL
# button stacked above the card's buy press (MOUSE_FILTER STOP), so tapping the "i" opens the sheet
# and does NOT trigger a purchase; tapping anywhere else on the card still buys.
static func _info_badge(host: Control, title: String, body: String) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(Tune.INFO_SIZE, Tune.INFO_SIZE)
	b.text = "i"
	b.add_theme_font_size_override("font_size", Tune.INFO_FONT)
	b.add_theme_color_override("font_color", CREAM)
	b.add_theme_color_override("font_hover_color", CREAM)
	b.add_theme_color_override("font_pressed_color", CREAM)
	b.add_theme_constant_override("outline_size", 0)
	var s := StyleBoxFlat.new()
	s.bg_color = Tune.INFO_BG
	s.set_corner_radius_all(int(Tune.INFO_SIZE / 2.0))
	s.set_border_width_all(Tune.INFO_BORDER_W)
	s.border_color = Tune.INFO_EDGE
	b.add_theme_stylebox_override("normal", s)
	b.add_theme_stylebox_override("hover", s)
	var sp: StyleBoxFlat = s.duplicate()
	sp.bg_color = Tune.INFO_EDGE
	b.add_theme_stylebox_override("pressed", sp)
	b.add_child(Look.rim_overlay(Tune.INFO_SIZE / 2.0, Tune.INFO_BORDER_W))   # shared two-tone sticker rim
	Look.add_press_juice(b)
	b.pressed.connect(func() -> void: _info_sheet(host, title, body))
	return b

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

# A small ink countdown chip ("↻ 5h 12m") for the Featured band — the offers rotate once per day
# (rotation_seed = day index), so this is the real time to the next UTC-midnight refresh.
static func _clock_chip(text: String) -> Control:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Tune.CLOCK_BG
	s.set_corner_radius_all(Tune.CLOCK_RADIUS)
	s.content_margin_left = Tune.CLOCK_PAD_X
	s.content_margin_right = Tune.CLOCK_PAD_X
	s.content_margin_top = Tune.CLOCK_PAD_Y
	s.content_margin_bottom = Tune.CLOCK_PAD_Y
	p.add_theme_stylebox_override("panel", s)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", Tune.CLOCK_SIZE)
	l.add_theme_color_override("font_color", CREAM)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	return p

# Time until the daily Featured rotation refreshes (next UTC midnight), as "↻ Hh Mm".
static func _rotation_left_text() -> String:
	var secs := 86400 - (int(Time.get_unix_time_from_system()) % 86400)
	return "↻ %dh %dm" % [secs / 3600, (secs % 3600) / 60]

# Pin a small node at a card/button corner. Decorative overlays are input-transparent (the press
# surface shows through); an `interactive` node (the "i" button) keeps its own input so it can be
# tapped without triggering the card's buy press.
static func _overlay_corner(host_btn: Button, node: Control, size: float, margin: float, left: bool, interactive: bool = false) -> void:
	host_btn.add_child(node)
	if not interactive:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.anchor_top = 0.0
	node.anchor_bottom = 0.0
	node.offset_top = margin
	node.offset_bottom = margin + size
	if left:
		node.anchor_left = 0.0
		node.anchor_right = 0.0
		node.offset_left = margin
		node.offset_right = margin + size
	else:
		node.anchor_left = 1.0
		node.anchor_right = 1.0
		node.offset_left = -(size + margin)
		node.offset_right = -margin

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

static func _card_button(min_size: Vector2) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = min_size
	var s := StyleBoxFlat.new()
	s.bg_color = Tune.CARD_BG
	s.set_corner_radius_all(Tune.CARD_RADIUS)
	s.set_border_width_all(Tune.CARD_BORDER_W)
	s.border_color = Color(BARK, Tune.CARD_EDGE_ALPHA)
	s.shadow_color = Tune.CARD_SHADOW
	s.shadow_size = Tune.CARD_SHADOW_SIZE
	s.shadow_offset = Tune.CARD_SHADOW_OFFSET
	b.add_theme_stylebox_override("normal", s)
	b.add_theme_stylebox_override("hover", s)
	var sp: StyleBoxFlat = s.duplicate()
	sp.bg_color = Tune.CARD_BG_PRESSED
	b.add_theme_stylebox_override("pressed", sp)
	Look.add_press_juice(b)
	return b

# Affordability is shown, never blocking: a can't-afford card still presses (wallet wiggles).
# The CARD stays bright always (a whole-card dim read as disabled/sold-out — the storefront's
# worst signal); only the BUY pill takes the muted "need more" state. Reads whichever price meta
# the card carries — gem_cost (💎), coin_cost (🪙), or an `owned` flag (no pill, nothing to dim).
static func _apply_afford(b: Button) -> void:
	if b.has_meta("owned") and bool(b.get_meta("owned")):
		return
	var ok := true
	if b.has_meta("gem_cost"):
		ok = Save.diamonds() >= int(b.get_meta("gem_cost"))
	elif b.has_meta("coin_cost"):
		ok = Save.coins() >= int(b.get_meta("coin_cost"))
	else:
		return
	var pill := b.find_child("BuyPill", true, false)
	if pill != null:
		(pill as Control).modulate = Color(1, 1, 1, 1.0) if ok else Tune.BUY_NEED_MODULATE

static func _refresh_afford(overlay: Control) -> void:
	for b in overlay.find_children("*", "Button", true, false):
		_apply_afford(b)

# The HUD wallet node for a currency ("coin"|"gem"), or null when the opener passed no wallet
# (e.g. a capture tool) — feedback then no-ops gracefully instead of touching a missing chip.
static func _wallet_node(refs: Dictionary, key: String) -> Control:
	var n: Variant = (refs.get(key, {}) as Dictionary).get("node")
	return n if (n != null and is_instance_valid(n)) else null

static func _try_buy(host: Control, refs: Dictionary, b: Button, cost: int,
		action: Callable, fly_id: String) -> void:
	if Save.diamonds() < cost:
		Audio.play("invalid_soft", -4.0)
		var gem_n := _wallet_node(refs, "gem")
		if gem_n != null:
			FX.wobble(gem_n)
		FX.floating_text(host, b.get_global_rect().get_center() - Tune.NEED_OFFSET,
			host.tr("Need %d more") % (cost - Save.diamonds()), CREAM, Tune.NEED_SIZE)
		return
	if not bool(action.call()):
		return
	Audio.play("merge_success", -3.0, 1.2)
	FX.pop(b)
	# the grant flies home to the HUD wallet and it ticks — no rebuild flash
	var target := _wallet_node(refs, "coin" if fly_id == "coin" else "gem")
	if target != null:
		FX.fly_to_wallet(host, b.get_global_rect().get_center(), Look.icon(fly_id, Tune.FLY_ICON), target,
			func() -> void: _settle(host, refs))
	_settle(host, refs)

# The item-shortcut / cosmetic buy: pays in `currency` ("coins"|"diamonds"), wiggling the
# right wallet chip + a "Need N more" floater when short (never blocking, §13). On success
# the `grant` callable does the spend+grant (it owns the price), then a celebratory floater
# and the wallet settle. `grant` returns false to abort cleanly (e.g. a race).
static func _try_buy_currency(host: Control, refs: Dictionary, b: Button, currency: String,
		cost: int, grant: Callable, ok_text: String) -> void:
	var have: int = Save.diamonds() if currency == "diamonds" else Save.coins()
	var chip := _wallet_node(refs, "gem" if currency == "diamonds" else "coin")
	if have < cost:
		Audio.play("invalid_soft", -4.0)
		if chip != null:
			FX.wobble(chip)
		FX.floating_text(host, b.get_global_rect().get_center() - Tune.NEED_OFFSET,
			host.tr("Need %d more") % (cost - have), CREAM, Tune.NEED_SIZE)
		return
	if not bool(grant.call()):
		return
	Audio.play("merge_success", -3.0, 1.2)
	FX.pop(b)
	FX.floating_text(host, b.get_global_rect().get_center() - Tune.NEED_OFFSET, ok_text, STRAW, Tune.NEED_SIZE)
	_settle(host, refs)

# The HUD wallet ticks to the new balances (via its own refresh — the shop no longer owns a
# wallet); affordability re-tints across the storefront.
static func _settle(host: Control, refs: Dictionary) -> void:
	var opts: Dictionary = refs.opts
	if opts.has("refresh"):
		(opts.refresh as Callable).call()
	if is_instance_valid(refs.overlay):
		_refresh_afford(refs.overlay)

# The cash confirm: parchment, pop_in, the honest caption — confirming grants the
# diamonds directly (the future IAP hookup replaces exactly this middle).
# The FIRST ladder pack shows its DOUBLED count (the §10 first-purchase doubler is live),
# and a "first-buy doubled!" line — so the confirm matches what actually lands.
static func _confirm_cash(host: Control, refs: Dictionary, i: int) -> void:
	var pack: Dictionary = CASH_PACKS[i]
	var doubled := first_buy_doubled()
	var gems := int(pack.gems) * (int(FIRST_BUY_MULT) if doubled else 1)
	var sub := host.tr("first-buy bonus doubled!") if doubled else ""
	_confirm_gem_grant(host, refs, host.tr("Dewdrop pouch"),
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
		_settle(host, refs), true))
	FX.pop_in(card)
