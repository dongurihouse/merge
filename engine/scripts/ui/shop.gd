extends RefCounted
## The Shop as the squirrel merchant's MARKET STALL (the §10 buy-side sink; owner:
## "the store menu shouldn't just be a list of buttons"). It sells, all behind an
## honest confirm where money is involved: water + a coin pouch (quick help), the
## free-acorn faucet, the one-time Welcome bundle, and the cash → premium acorn
## pouches. The cash packs are LIVE: confirming grants the diamonds directly (an honest
## "test build — nothing is charged"); a real store SDK replaces ONLY the middle of
## `_confirm_cash` — nothing else changes. §4 law: premium buys SPEED, never POSSIBILITY.
## The grove's pack prices are owner-tunable in games/grove/grove_data.gd (§10 LIVE-IAP).
## Pure grant funcs are static and test-covered. (Item-SHORTCUTS — buy a mid-tier piece to
## skip the grind — were removed 2026-06-23; item-buying is moving to the board's item info
## bar. Cosmetic LOOKS were removed earlier with customization. Both rebuilds are parked in
## docs/BACKLOG.md.)
## Look/feel values live in Tune (engine/scripts/core/tuning.gd → class Shop).

const Save = preload("res://engine/scripts/core/save.gd")
const Design = preload("res://engine/scripts/core/design.gd")   # THE design-viewport owner — never re-type 1080×1920
const Look = preload("res://engine/scripts/ui/skin.gd")
const G = preload("res://engine/scripts/core/content.gd")
const Mastery = preload("res://engine/scripts/core/mastery.gd")
const Features = preload("res://engine/scripts/core/features.gd")
const FX = preload("res://engine/scripts/ui/fx.gd")
const Audio = preload("res://engine/scripts/core/audio.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const Claims = preload("res://engine/scripts/core/claims.gd")    # the free daily-claim faucets (Free acorns + the free water refill)
const Iap = preload("res://engine/scripts/core/iap.gd")          # IAP catalog: product id + price by key (data/iap_products.json)
const PurchaseWait = preload("res://engine/scripts/ui/purchase_wait.gd")
const D = Game.DATA                                               # the active game's data (§10 IAP ladder)
const Pal = Game.PALETTE
const Tune = preload("res://engine/scripts/core/tuning.gd").Shop   # the engine's shop dials
const FS = preload("res://engine/scripts/core/tuning.gd").FontScale
const Strings = preload("res://engine/scripts/core/strings.gd")
const Overlay = preload("res://engine/scripts/ui/overlay.gd")
const SpritePanel = preload("res://engine/scripts/ui/sprite_panel.gd")   # the item art's shape-true cast (wrap_sprite)
const Stall = preload("res://engine/scripts/ui/market_stall.gd")         # THE storefront's furniture (concept A)
const HitOverlay = preload("res://engine/scripts/ui/shop_hit_overlay.gd")  # the debug-gated hit-region overlay
const OVERLAY_NAME := "ShopOverlay"
const CONFIRM_NAME := "ShopCashConfirmOverlay"   ## the cash confirm raised over an open shop

const INK = Pal.INK
const CREAM = Pal.CREAM
const STRAW = Pal.STRAW
const BARK = Pal.BARK

# The storefront FACE is built from the shared kit (the UI workbench), like the mailbox + daily login —
# so the shop's look is authored once in the workbench and never duplicated here. The buy LOGIC stays.

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

static func scissors_available() -> bool:
	return Features.on("scissors") and Mastery.any_rank_at_least(2)

# `place_hook(commit)` is supplied by the Board shop opener. It is called once as a dry-run before
# spending, then again with commit=true after the coin spend succeeds. Without a hook, the map/hub
# shop banks the tool for the next board entry.
static func buy_scissors(place_hook: Callable = Callable()) -> bool:
	if not scissors_available():
		return false
	if place_hook.is_valid() and not bool(place_hook.call(false)):
		return false
	if Save.coins() < int(G.SCISSORS_COST):
		return false
	if not Save.spend(int(G.SCISSORS_COST), "scissors"):
		return false
	if place_hook.is_valid():
		if not bool(place_hook.call(true)):
			Save.add_coins(int(G.SCISSORS_COST))
			return false
	else:
		Save.add_scissors_pending(1)
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

# (The free-ACORN faucet was retired 2026-06-23 — acorns are precious/earned-only at 1024🪙 each, Option A.
# Only the free WATER refill remains a free claim; water isn't acorns.)

# --- the free WATER refill (§4/§10): a full can, free, capped + cooled, leading the storefront. Pours a
# full can ON TOP of the current water (additive, over-cap ok). Shares the Claims "refill_water" row.

# The free-refill faucet's display state, same shape as free_gems_status (ready/cooldown/capped).
static func refill_status() -> Dictionary:
	return _claim_status("refill_water")

# The full-can size the free refill pours (the card's count) — the CLAIMS "refill_water" grant.
static func refill_amount() -> int:
	return int(D.CLAIMS.get("refill_water", {}).get("water", 0))

# Claim the free refill. Returns the 💧 to ADD to the board's water (over-cap ok), 0 if refused.
static func claim_refill() -> int:
	var res := Claims.claim("refill_water")
	return int(res.get("water", 0)) if bool(res.get("ok", false)) else 0

# Shared faucet-status read for the free-claim cards: {available, kind, minutes}. Pure (Claims/Save).
static func _claim_status(kind: String) -> Dictionary:
	if Claims.can_show(kind):
		return {"available": true, "kind": "ready", "minutes": 0}
	if Claims.remaining_today(kind) <= 0:
		return {"available": false, "kind": "capped", "minutes": 0}
	var left := Save.claim_cooldown_left(kind, Claims.cooldown(kind))
	return {"available": false, "kind": "cooldown", "minutes": maxi(1, ceili(left / 60.0))}

# --- the storefront ----------------------------------------------------------------
# ONE unified storefront (shop_dialog_v3_unified_storefront mock): every currency pill's + opens the
# SAME dialog — the stall tabs are gone; the sections (Free refill · Quick help · Welcome · Acorn
# pouches) all ride one scrolling sheet. The three named openers stay as entry points for the HUD.
static func open_water(host: Control, opts: Dictionary = {}) -> void:
	_open(host, opts)

static func open_coin(host: Control, opts: Dictionary = {}) -> void:
	_open(host, opts)

static func open_premium(host: Control, opts: Dictionary = {}) -> void:
	_open(host, opts)

static func open(host: Control, opts: Dictionary = {}) -> void:
	_open(host, opts)

static func _open(host: Control, opts: Dictionary) -> void:
	if Overlay.is_open(host, OVERLAY_NAME):
		return
	var Kit: GDScript = Game.kit_script()
	if Kit == null:
		push_warning("Shop: kit missing at %s" % Game.kit())
		return
	# the backdrop: a BLURRED + warm-tinted + vignetted copy of the live scene, so the boring
	# flat dim becomes a cozy frosted backdrop that focuses the parchment. Falls back to a flat
	# dim if the screen-read shader can't compile — which is what Tune.VEIL_ALPHA is: the
	# storefront's OWN authored fallback darkness under that shader, not the shared modal veil.
	var modal := Overlay.modal(host, OVERLAY_NAME, {
		"alpha": Tune.VEIL_ALPHA, "material": _backdrop_material()})
	var overlay: Control = modal["overlay"]
	var cc: CenterContainer = modal["center"]

	# The HUD bar IS the wallet (one source) — its refs let buy feedback (fly-home / wiggle) target it.
	# The shop is a SOFT modal: its frosted backdrop is meant to keep the wallet readable while you shop, so
	# lift the wallet panels ABOVE the modal layer for the shop's lifetime and restore their resting z on
	# close (a raw move_child no longer suffices now the shop sits at MODAL_Z). Absent (a capture tool) → no-ops.
	var hud_wallet: Dictionary = opts.get("wallet", {})
	var raised_wallet: Array = []
	for p in hud_wallet.get("panels", []):
		if p is CanvasItem and is_instance_valid(p) and (p as Node).get_parent() == host:
			raised_wallet.append([p, (p as CanvasItem).z_index])
			(p as CanvasItem).z_index = Overlay.MODAL_TOP_Z
	overlay.tree_exited.connect(func() -> void:
		for pair in raised_wallet:
			if is_instance_valid(pair[0]):
				(pair[0] as CanvasItem).z_index = int(pair[1]))

	# The storefront IS the market stall (concept A) — there is no dialog frame and no offer card. The
	# awning, the hanging signboard that carries the title, the coral ✕ and the four shelf planks are all
	# built by engine/scripts/ui/market_stall.gd from the shared cut-paper panel. Width is a % of the
	# SCREEN, and the stall shrinks to fit a short screen rather than scrolling (the mock has no scroll).
	var vw: float = host.get_viewport_rect().size.x
	var cfg: Dictionary = Game.kit_config()
	var inner: float = grid_inner_w(Kit, cfg, vw)

	var refs := {
		"coin": hud_wallet.get("coin", {"node": null, "label": null}),
		"gem": hud_wallet.get("gem", {"node": null, "label": null}),
		"overlay": overlay, "opts": opts, "host": host,
		"kit": Kit, "cfg": cfg, "inner": inner}

	# (re)build the storefront from the live wallet + stock; a buy rebuilds it in place to refresh
	# balances and affordability.
	var rb := {"fn": Callable(), "first": true}
	refs["rb"] = rb
	rb.fn = func() -> void:
		if not is_instance_valid(cc):
			return
		for c in cc.get_children():
			c.queue_free()
		var vp: Vector2 = host.get_viewport_rect().size
		var lay: Dictionary = shop_layout(cfg)
		lay["max_h"] = vp.y * STALL_MAX_H_PCT
		lay["title"] = Strings.t("shop.title")
		lay["on_close"] = modal["dismiss"]
		var stall: Control = build_body(Kit, vp.x * STALL_W_PCT, _sections(refs), lay)
		cc.add_child(stall)
		# the hit-region overlay: authoring-gated debug chrome, never a normal run (see shop_hit_overlay.gd)
		HitOverlay.mount(overlay, stall)
		if rb.first:
			FX.pop_in(stall)
			rb.first = false
	rb.fn.call()

# --- the market-stall storefront (concept A) -----------------------------------------
# Colours, geometry and the shelf plan all live on engine/scripts/ui/market_stall.gd — this file keeps the
# MONEY: what is on sale, what it costs, and what pressing it does. The stall is handed the same card
# dictionaries the sage-card grid was, so a re-layout cannot re-wire a tier.

## How much of the screen the stall takes. The mock is a FULL-BLEED storefront (its awning runs off both
## edges), so the stall does not ride the shared 75% dialog width — squeezed to it, the goods and the
## numerals both drop below the mock's own legibility gate. It is still a modal: the frosted backdrop and
## the raised wallet are unchanged.
const STALL_W_PCT := 0.92
const STALL_MAX_H_PCT := 0.94    # …and it SHRINKS to fit a short screen rather than scrolling (no scroll bars, per the mock)

# The retired sage offer card's own metrics. The stall has no card — these survive ONLY as the fallback
# values `shop_layout` hands back for a saved config written before the restyle, so an old settings file
# still loads. Nothing draws them. (Kit.SHOP_CARD_CP_DEFAULTS still supplies the shared cut-paper edge the
# stall's cream tags and plaques inherit.)
const CARD_CORNER := 22.0
const GRID_GAP := 14.0

## The per-offer identity a slot and its price button both carry, so the debug hit overlay can name what a
## region resolves to and the suites can assert region ↔ purchase. One id per live offer, stable across a
## rebuild: the free refill, the two quick-help offers, the scissors, and `cash_<i>` per ladder tier.
const OFFER_REFILL := "refill"
const OFFER_WATER := "water_fill"
const OFFER_POUCH := "coin_pouch"
const OFFER_SCISSORS := "scissors"

static func cash_offer_id(i: int) -> String:
	return "cash_%d" % i

# The whole storefront: the stall built from the live sections.
static func _build_body(refs: Dictionary) -> Control:
	return build_body(refs.kit, refs.inner, _sections(refs), shop_layout(refs.get("cfg", {})))

## The shop LAYOUT knobs read from the saved config's "shop" block — the metrics the workbench tunes and
## the game honours. `icon_size` (the goods\' art size, % of default) is the one the stall still consumes;
## `card_pad` / `grid_gap` / `corner` described the retired sage offer card and are kept only so an older
## saved config still loads (the stall derives every metric from its own width — see market_stall.gd).
static func shop_layout(cfg: Dictionary) -> Dictionary:
	var sh: Dictionary = (cfg as Dictionary).get("shop", {}) if cfg is Dictionary else {}
	var o := {
		"icon_size": float(sh.get("icon_size", 100)) / 100.0,   # art size, % of the default
		"card_pad": float(sh.get("card_pad", 12)),
		"grid_gap": float(sh.get("grid_gap", GRID_GAP)),
		"corner": float(sh.get("corner", CARD_CORNER)),
	}
	var Kit: GDScript = Game.kit_script()
	if Kit != null:
		o["cp"] = Kit.shop_card_cp_from_config(cfg)
	return o

## The storefront\'s design width, in LAYOUT px, for a screen `vw` wide. Kept as the ONE derivation of it
## (the mock rig and the workbench both take their width from the shipping path, never from a number typed
## beside it — rule 3 of docs/design/verifying-against-a-mock.md).
static func grid_inner_w(Kit: GDScript, cfg: Dictionary, vw: float) -> float:
	return vw * STALL_W_PCT

## THE SHARED STOREFRONT BUILDER. The game (`_open`) computes the sections from live state and passes them
## here; the workbench passes demo sections. So the tool renders the real storefront, at the real layout.
## `lay` carries the saved shop knobs plus, from the game, `max_h` / `title` / `on_close`.
static func build_body(Kit: GDScript, w: float, sections: Array, lay: Dictionary = {}) -> Control:
	var rows := stall_rows(sections)
	var width: float = Stall.fit_width(w, float(lay.get("max_h", 0.0)), rows)
	var s: float = width / maxf(1.0, Design.size().x)   # the price CTA scales with the stall
	return Stall.build(Kit, width, rows, {
		"title": String(lay.get("title", "")),
		"on_close": lay.get("on_close", Callable()),
		"icon_scale": float(lay.get("icon_size", 1.0)),
		"cp": lay.get("cp", {}),        # the SHARED cut-paper knob set every stall sheet is cut with
		"pill": func(card: Dictionary) -> Control: return _price_pill(Kit, card, s),
	})

## THE SHELF PLAN — the one place section DATA becomes stall FURNITURE, and the only thing between the
## offer list and the shelves. Two rules, both taken from the mock:
##   * the soft-currency offers (free refill · quick help) stand on the COUNTER, two to a shelf, each under
##     its own small cream caption plaque on the counter\'s front lip;
##   * the real-money ladder fills the shelves below it, two tiers to a shelf, smallest upper-left to
##     largest lower-right, under one wide "ACORN POUCHES" plaque on the wall above the first of them.
## A section that is longer than the mock\'s (the 💎 fill appears once today\'s free rain is spent; scissors
## unlock at mastery 2) simply takes another shelf — it never squeezes three goods onto one.
static func stall_rows(sections: Array) -> Array:
	var counter: Array = []          # [card, caption]
	var ladder: Array = []
	var ladder_caption := ""
	for sec in sections:
		var s := sec as Dictionary
		var cards: Array = s.get("cards", [])
		var caption := String(s.get("caption", ""))
		for c in cards:
			var card := c as Dictionary
			if bool(card.get("cash", false)):
				ladder.append(card)
				ladder_caption = caption
				continue
			# THE CAPTION on the counter plaque. A section that stocks ONE offer names itself (the mock\'s
			# "FREE REFILL" / "QUICK HELP"); a section stocking several names each offer, or the plaques
			# would read the same word twice and the player could not tell the offers apart.
			counter.append([card, caption if cards.size() <= 1 else String(card.get("title", caption))])
	var rows: Array = []
	for i in range(0, counter.size(), 2):
		var pair: Array = counter.slice(i, mini(i + 2, counter.size()))
		var cards: Array = []
		var caps: Array = []
		for e in pair:
			cards.append(e[0])
			caps.append(e[1])
		rows.append({"cards": cards, "captions": caps, "counter": true})
	for i in range(0, ladder.size(), 2):
		var row := {"cards": ladder.slice(i, mini(i + 2, ladder.size())), "counter": false}
		if i == 0:
			row["header"] = ladder_caption
		rows.append(row)
	return rows

# The GREEN price pill — the card's buy CTA (a real-money price, a 💎 cost, or a free claim). Carries the
# `shop_buy` meta the UI-shape smoke counts, plus `shop_cash` on a real-money pack (the capture tool taps it).
## `s` scales the pill with the stall (the storefront is laid out at real screen px now — there is no
## dialog ScaleContainer under it any more), so the CTA keeps the mock\'s proportions at any stall width.
static func _price_pill(Kit: GDScript, d: Dictionary, s: float = 1.0) -> Control:
	if String(d.get("price", "")) == "":
		return null
	var icon_id := String(d.get("price_icon", ""))
	# the SHARED pill_button (green role) — the code-drawn cut-paper edge + its OWN shape-true shadow,
	# tuned from the workbench Button element. The whole pill keeps its natural width (deckle must not
	# stretch), so the `shop_textured` meta tells the caller to skip the stretch-to-column overrides.
	var price := String(d.price)
	var opts := {
		"bg": "green",
		"font": int(round(FS.HEADING * s)),
		"icon": icon_id,          # a 💎/🪙 cost carries its glyph; a USD/free pack ("") prints the text alone
		"icon_size": int(round(44 * s)),
		"pad_scale": s,
		"shadow": true,
	}
	var b: Button = Kit.pill_button("" if icon_id != "" else price.to_upper(), opts)
	b.name = "ShopBuyButton"
	b.set_meta("shop_buy", true)
	b.set_meta("shop_textured", true)
	if bool(d.get("cash", false)):
		b.set_meta("shop_cash", true)
	b.set_meta(Stall.OFFER_META, String(d.get("offer_id", "")))   # the SAME id the slot carries
	b.add_theme_font_override("font", Kit.bold_font())
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(c, Color.WHITE)   # the mock's green CTA prints in pure white
	# a currency-priced CTA carries the number beside the glyph (pill_button's b.icon supplies the glyph)
	if icon_id != "":
		b.text = price
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if d.has("affordable") and not bool(d.get("affordable", true)):
		b.modulate = Color(1, 1, 1, 0.45)   # can't afford → the CTA greys (still pressable: the wallet wiggles)
	var cb: Callable = d.get("on_buy", Callable())
	if cb.is_valid():
		b.pressed.connect(func() -> void: cb.call())
	return b

# Build the live shop SECTIONS for the unified storefront (shop_dialog_v3): the FREE refill leads,
# then Quick help (the Coin pouch, plus 💎 Fill-water only after FREE is unavailable), then the
# one-time Welcome bundle + the Acorn-pouch cash ladder. Each card carries its data + buy/info callbacks + a
# build-time `affordable` flag (the price dims when broke). Rebuilt on every buy.
static func _sections(refs: Dictionary) -> Array:
	var secs: Array = [{"caption": Strings.t("shop.refill.caption"), "cards": [_refill_card(refs)]}]
	secs.append(_quick_help_section(refs))
	secs.append_array(_premium_sections(refs))
	return secs

# QUICK HELP — the mock's titled pair: FILL WATER (💎 → a full can; water is Save-backed, so the card is
# host-agnostic — the board re-syncs its live cache via the HUD refresh) and COIN POUCH (💎 → coins).
static func _quick_help_section(refs: Dictionary) -> Dictionary:
	var host: Control = refs.host
	var gems := Save.diamonds()
	var water := {
		"offer_id": OFFER_WATER,
		"title": Strings.t("shop.water.fill_label"),
		"icon": "shop_can", "count": int(G.WATER_CAP),   # the mock's card states the AMOUNT it grants (a full can)
		"price": str(int(G.REFILL_DIAMOND_COST)), "price_icon": "gem",
		"affordable": gems >= int(G.REFILL_DIAMOND_COST),
		"on_buy": func() -> void: _flow_water(refs)}
	var pouch := {
		"offer_id": OFFER_POUCH,
		"title": Strings.t("shop.coin.pouch_label"),
		"icon": "shop_pouch", "count": COIN_PACK,        # the mock's card states the AMOUNT it grants
		"price": str(COIN_PACK_GEM_COST), "price_icon": "gem",
		"affordable": gems >= COIN_PACK_GEM_COST,
		"on_buy": func() -> void: _flow_coins(refs)}
	var cards: Array = [pouch]
	if scissors_available():
		cards.append({
			"offer_id": OFFER_SCISSORS,
			"title": Strings.t("shop.scissors.title"),
			"icon": "shop_pouch",
			"label": Strings.t("shop.scissors.label"),
			"note": Strings.t("shop.scissors.note"),
			"price": str(int(G.SCISSORS_COST)), "price_icon": "coin",
			"affordable": Save.coins() >= int(G.SCISSORS_COST),
			"on_buy": func() -> void: _flow_scissors(refs)})
	if not bool(refill_status().available):
		cards.push_front(water)
	return {"caption": Strings.t("shop.coin.quick_help_caption"), "cards": cards}

# The free-refill card: a full 💧 can + a green "Free" CTA when offerable; when cooling/capped the CTA
# drops and the cozy timer reads as plain text inside the card (a faucet at rest, not a greyed wall).
# on_buy re-checks the gate so a stale press can't over-grant.
static func _refill_card(refs: Dictionary) -> Dictionary:
	var st := refill_status()
	var card := {"offer_id": OFFER_REFILL, "icon": "shop_can", "count": refill_amount()}
	if bool(st.available):
		card["price"] = Strings.t("shop.refill.cta")
		card["affordable"] = true
		card["on_buy"] = func() -> void:
			if refill_status().available:
				_flow_free_refill(refs)
	else:
		card["note"] = Strings.t("shop.refill.back_tomorrow") if String(st.kind) == "capped" \
			else Strings.t("shop.refill.ready_in") % int(st.minutes)
	return card

# PREMIUM section — the cash → 💎 Acorn-pouch ladder. Plain cards (the merchandising ribbons, the
# first-buy badge and the Welcome bundle card were dropped with the v3 clean-up; the starter GRANT
# machinery stays for the backend/tests).
static func _premium_sections(refs: Dictionary) -> Array:
	var host: Control = refs.host
	var packs: Array = []
	for i in CASH_PACKS.size():
		var pack: Dictionary = CASH_PACKS[i]
		packs.append({
			"offer_id": cash_offer_id(i),
			"icon": _pack_icon_id(i), "count": int(pack.gems), "cash": true,
			"price": Iap.usd(String(pack.key)),
			"on_buy": func() -> void: _confirm_cash(host, refs, i)})
	return [{"caption": Strings.t("shop.premium.acorn_pouches_caption"), "cards": packs}]

# The escalating acorn-pack art id for ladder pack i (pack_t1… — the cut-paper container ladder from
# shop_item_icons_v1), falling back to the plain gem when the grove has more packs than tier sprites.
static func _pack_icon_id(i: int) -> String:
	var art := "pack_t%d" % (i + 1)
	return art if ResourceLoader.exists(Game.art("ui/currency/icon_%s.png" % art)) else "gem"

static func _flow_water(refs: Dictionary) -> void:
	var act := func() -> bool:
		if not buy_water():
			return false
		Save.fill_water()                # top the can to full (Save-backed; the HUD refresh re-reads it)
		return true
	_buy(refs, "gem", int(G.REFILL_DIAMOND_COST), act, "water")

static func _flow_coins(refs: Dictionary) -> void:
	_buy(refs, "gem", COIN_PACK_GEM_COST, buy_coin_pack, "coin")

static func _flow_scissors(refs: Dictionary) -> void:
	var opts: Dictionary = refs.get("opts", {})
	var hook: Callable = opts.get("place_scissors", Callable())
	var act := func() -> bool:
		return buy_scissors(hook)
	_buy(refs, "coin", int(G.SCISSORS_COST), act, "coin")

# (The free-ACORN faucet flow was retired 2026-06-23 — acorns earned-only, Option A.)

# The free-refill faucet flow (no spend): claim, pour the full can onto Save's water ADDITIVELY (over-cap
# ok — banks a spare), fly a 💧 to the wallet, and rebuild so the card flips to its cooldown read. The HUD
# refresh re-reads Save (and re-syncs the board's live cache). Refused (raced past the cap) → soft nudge.
static func _flow_free_refill(refs: Dictionary) -> void:
	var host: Control = refs.host
	var got := claim_refill()
	if got <= 0:
		Audio.play("invalid_soft", -4.0)
		_after_buy(refs)
		return
	Save.add_water(got, true)            # additive, over-cap (Save-backed; no per-host callback)
	Audio.play("rain_refill" if Audio.has("rain_refill") else "merge_success", -3.0, 1.2)
	var water_n := _wallet_node(refs, "water")
	if water_n != null:
		FX.fly_to_wallet(host, _fb_at(host), Look.icon("water", Tune.FLY_ICON), water_n, func() -> void: _after_buy(refs))
	else:
		_after_buy(refs)

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

static func _need_more(refs: Dictionary, currency: String, short: int) -> void:
	var host: Control = refs.host
	Audio.play("invalid_soft", -4.0)
	var chip := _wallet_node(refs, currency)
	if chip != null:
		FX.wobble(chip)
	FX.floating_text(host, _fb_at(host), Strings.t("shop.buy.need_more") % short, CREAM, Tune.NEED_SIZE)

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
	var key := String(pack.key)
	var doubled := first_buy_doubled()
	var gems := int(pack.gems) * (int(FIRST_BUY_MULT) if doubled else 1)
	var sub := Strings.t("shop.cash.first_buy_bonus") if doubled else ""
	_confirm_gem_grant(host, refs, Strings.t("shop.cash.confirm_title"),
		Strings.t("shop.cash.confirm_line") % [gems, Iap.usd(key)], sub, key, func() -> void:
			grant_cash_pack(i))

# The shared honest cash-confirm body (§10): parchment card, ribbon title, the 💎 line,
# an optional sub-line, the "(test build — nothing is charged)" note, Cancel/Confirm. On
# Confirm it runs `grant` (the pure grant that owns the actual currency math), flies a 💎
# to the wallet, and settles. A real store SDK + receipt check replaces ONLY the inside of
# `grant` + a guard around this Confirm — the frame, the note, and the wiring stay.
static func _confirm_gem_grant(host: Control, refs: Dictionary, title: String,
		line: String, sub: String, product_key: String, grant: Callable) -> void:
	var Kit: GDScript = Game.kit_script()
	if Kit == null:
		return
	# the cash confirm sits ABOVE the open shop and is NOT veil-dismissable — a money decision leaves
	# by Cancel, ✕ or Confirm, never by a stray tap. Tune.CONFIRM_VEIL_ALPHA is the storefront's own
	# authored darkness for this sheet (a lighter scrim over the already-frosted shop behind it).
	var modal := Overlay.modal(host, CONFIRM_NAME, {
		"z": Overlay.MODAL_TOP_Z, "dismissable": false, "alpha": Tune.CONFIRM_VEIL_ALPHA})
	var overlay: Control = modal["overlay"]
	var cc: CenterContainer = modal["center"]
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", Tune.CONFIRM_COL_SEP)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
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
	# Honest disclosure: a real charge happens ONLY when StoreKit is in the build; else the test note.
	var charged := Iap.charging()
	var note := Label.new()
	note.text = (Strings.t("shop.confirm.charged_note") % Iap.usd(product_key)) if charged else Strings.t("shop.confirm.test_build_note")
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.add_theme_font_size_override("font_size", Tune.CONFIRM_NOTE_SIZE)
	note.add_theme_color_override("font_color", BARK)
	col.add_child(note)
	var dialog: Control = null
	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", Tune.BTNS_SEP)
	col.add_child(btns)
	btns.add_child(Look.button(Strings.t("shop.confirm.cancel"), func() -> void: overlay.queue_free(), false))
	btns.add_child(Look.button(Strings.t("shop.confirm.confirm"), func() -> void:
		var at := col.get_global_rect().get_center()
		# grant + fly-to-wallet + rebuild — IDENTICAL whether the purchase was real or the test path.
		var settle := func() -> void:
			grant.call()
			var gem_n := _wallet_node(refs, "gem")
			if gem_n != null:
				FX.fly_to_wallet(host, at, Look.icon("gem", Tune.FLY_ICON), gem_n)
			_after_buy(refs)
		if charged:
			# real IAP: StoreKit takes over; grant ONLY on a confirmed purchase, nothing on cancel.
			var wait := PurchaseWait.show(host, Strings.t("iap.opening_title"), Strings.t("iap.opening_message"))
			overlay.queue_free()
			Iap.buy(product_key, func(okay: bool) -> void:
				PurchaseWait.close(wait)
				if okay:
					settle.call())
		else:
			overlay.queue_free()
			settle.call(), true))
	var cfg: Dictionary = Game.kit_config()
	var copts: Dictionary = Kit.dialog_opts_from_config(cfg)
	copts["content_scale"] = Kit.dialog_content_scale(cfg, "dialog")
	copts["banner_text"] = title
	copts["banner_icon_on"] = false
	copts["center_content"] = true
	copts["on_close"] = modal["dismiss"]
	var vp := host.get_viewport()
	var vw: float = vp.get_visible_rect().size.x if vp != null else Design.size().x
	var width: float = maxf(1.0, vw) * Kit.DIALOG_DESIGN_PCT["dialog"] / 100.0
	dialog = Kit.dialog_frame(col, width, copts)
	cc.add_child(dialog)
	FX.pop_in(dialog)
