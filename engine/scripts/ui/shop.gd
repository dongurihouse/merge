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
const Look = preload("res://engine/scripts/ui/skin.gd")
const G = preload("res://engine/scripts/core/content.gd")
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
const OVERLAY_NAME := "ShopOverlay"

const INK = Pal.INK
const CREAM = Pal.CREAM
const STRAW = Pal.STRAW
const BARK = Pal.BARK

# The storefront FACE is built from the shared kit (the UI workbench), like the mailbox + daily login —
# so the shop's look is authored once in the workbench and never duplicated here. The buy LOGIC stays.
const KIT_PATH := "res://games/grove/tools/ui_workbench_kit.gd"

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

# (The free-ACORN faucet was retired 2026-06-23 — acorns are precious/earned-only at 1024🪙 each, Option A.
# Only the free WATER refill remains a free claim; water isn't acorns.)

# --- the free WATER refill (§4/§10): a full can, free, capped + cooled, in the water stall. Pours a
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
	if Overlay.is_open(host, OVERLAY_NAME):
		return
	var Kit: GDScript = load(KIT_PATH)
	if Kit == null:
		push_warning("Shop: kit missing at %s" % KIT_PATH)
		return
	var overlay := Overlay.mount(host, OVERLAY_NAME)
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

	# The storefront FACE is the SHARED mock-true frame (Kit.dialog_frame — the same warm-cream sheet,
	# ink title and coral ✕ every restyled dialog wears); the shop's own BODY (stall tabs ·
	# section headers · the 2-up offer grid · the info footer) is built here, per the shop_dialog_v1 mock.
	# Width is a % of the SCREEN (responsive).
	var vw: float = host.get_viewport_rect().size.x
	var cfg: Dictionary = Kit.load_config(Kit.CONFIG_PATH)
	var width: float = vw * Kit.DIALOG_DESIGN_PCT["shop"] / 100.0
	# the CONTENT lays out at the design width MINUS the sheet's insets (the frame scales it by
	# content_scale, so the pads count at 1/scale in layout space) — the residents.gd idiom.
	var cscale: float = maxf(0.01, Kit.dialog_content_scale(cfg, "shop"))
	var inner: float = width - 2.0 * float(Kit.frame_border("parchment")["pad_x"]) / cscale

	var refs := {
		"coin": hud_wallet.get("coin", {"node": null, "label": null}),
		"gem": hud_wallet.get("gem", {"node": null, "label": null}),
		"overlay": overlay, "opts": opts, "host": host, "kind": kind,
		"kit": Kit, "cfg": cfg, "inner": inner}

	# (re)build the storefront from the live wallet + stock; a buy (or a stall TAB) rebuilds it in place to
	# refresh balances, affordability, the merchandising ribbons, and the starter's one-time availability.
	var rb := {"fn": Callable(), "first": true}
	refs["rb"] = rb
	rb.fn = func() -> void:
		if not is_instance_valid(cc):
			return
		for c in cc.get_children():
			c.queue_free()
		var fopts: Dictionary = Kit.dialog_opts_from_config(cfg)
		fopts["content_scale"] = cscale
		fopts["banner_text"] = Strings.t("shop.title")
		fopts["on_close"] = func() -> void: overlay.queue_free()
		# on a PHONE the full ladder is taller than the screen, so cap the inner height to the
		# viewport — the shop then scrolls inside the sheet.
		fopts["list_max_h"] = host.get_viewport_rect().size.y * 0.72
		var dialog: Control = Kit.dialog_frame(_build_body(refs), width, fopts)
		cc.add_child(dialog)
		if rb.first:
			FX.pop_in(dialog)
			rb.first = false
	rb.fn.call()

# --- the mock-true storefront body (shop_dialog_v1) ----------------------------------
# Colours sampled from the mock; the sheet/title/✕ come from the shared frame and are NOT re-specified.
const SAGE := Color("#E4DEBD")        # an offer card's sage face
const PILL_GREEN := Color("#5C8A57")  # the price pill + the active stall tab
const TAB_IDLE := Color("#F4E9D1")    # a resting stall tab
const CHIP_CREAM := Color("#F8ECD5")  # the bundle amount chip
const FOOTER_CREAM := Color("#EDE2C1")
const CARD_CORNER := 18.0
const GRID_GAP := 14.0
# The stall TABS, in the mock's order: the three shops share one sheet, the tab bar swaps `kind`.
const STALLS := [["water", "Water"], ["coin", "Coins"], ["premium", "Acorns"]]

# The whole scrolling body: stall tabs · each section's header + offer grid · the footer.
static func _build_body(refs: Dictionary) -> Control:
	var Kit: GDScript = refs.kit
	var w: float = refs.inner
	var col := VBoxContainer.new()
	col.name = "ShopBody"
	col.add_theme_constant_override("separation", 16)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(_tab_bar(refs, w))
	for sec in _sections(refs):
		var s := sec as Dictionary
		col.add_child(_section_header(Kit, String(s.get("caption", "")), String(s.get("badge", ""))))
		col.add_child(_offer_grid(refs, s.get("cards", []), w))
	var foot := _footer_note(refs)
	if foot != null:
		col.add_child(foot)
	return col

# The stall TAB bar — WATER / COINS / ACORNS. The active tab is the green one; tapping a resting tab
# swaps the open stall in place (the three stalls have always been one dialog with a different `kind`).
static func _tab_bar(refs: Dictionary, w: float) -> Control:
	var Kit: GDScript = refs.kit
	var row := HBoxContainer.new()
	row.name = "ShopTabBar"
	row.add_theme_constant_override("separation", int(GRID_GAP))
	row.custom_minimum_size = Vector2(w, 0)
	for entry in STALLS:
		var id := String(entry[0])
		var on := id == String(refs.get("kind", "premium"))
		var b := Button.new()
		b.name = "ShopTab_" + id
		b.text = Strings.t("shop.tab.%s" % id).to_upper()
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_override("font", Kit.bold_font())
		b.add_theme_font_size_override("font_size", FS.BODY)
		b.add_theme_color_override("font_color", CREAM if on else INK)
		b.add_theme_color_override("font_hover_color", CREAM if on else INK)
		b.add_theme_color_override("font_pressed_color", CREAM if on else INK)
		b.add_theme_constant_override("outline_size", 0)
		var sb := StyleBoxFlat.new()
		sb.bg_color = PILL_GREEN if on else TAB_IDLE
		sb.corner_radius_top_left = int(CARD_CORNER); sb.corner_radius_top_right = int(CARD_CORNER)
		sb.content_margin_top = 14; sb.content_margin_bottom = 14
		sb.content_margin_left = 8; sb.content_margin_right = 8
		for st in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(st, sb)
		if not on:
			b.pressed.connect(func() -> void:
				Audio.play("button_tap", -2.0)
				refs["kind"] = id
				var rb: Dictionary = refs.get("rb", {})
				if rb.has("fn") and (rb.fn as Callable).is_valid():
					(rb.fn as Callable).call())
		row.add_child(b)
	return row

# A section HEADER — the mock's centred navy all-caps title, with an optional gold merchandising
# badge beside it (only ever driven by live offer data, e.g. the first-purchase doubler being unspent).
static func _section_header(Kit: GDScript, caption: String, badge: String) -> Control:
	var row := HBoxContainer.new()
	row.name = "ShopSectionHeader"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.custom_minimum_size = Vector2(0, 74)   # the mock's generous air above/below a section title
	var l := _ink_label(Kit, caption.to_upper(), FS.HEADING)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(l)
	if badge != "":
		var p := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = STRAW
		sb.set_corner_radius_all(10)
		sb.content_margin_left = 16; sb.content_margin_right = 16
		sb.content_margin_top = 5; sb.content_margin_bottom = 6
		p.add_theme_stylebox_override("panel", sb)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var bl := Label.new()
		bl.text = badge.to_upper()
		bl.add_theme_font_override("font", Kit.bold_font())
		bl.add_theme_font_size_override("font_size", FS.FINE)
		bl.add_theme_color_override("font_color", CREAM)
		bl.add_theme_constant_override("outline_size", 0)
		bl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(bl)
		row.add_child(p)
	return row

# One section's offers as the mock's TWO-column grid. A card marked `wide` (the Welcome bundle) takes a
# full row of its own; the rest pair up.
static func _offer_grid(refs: Dictionary, cards: Array, w: float) -> Control:
	var col := VBoxContainer.new()
	col.name = "ShopOfferGrid"
	col.add_theme_constant_override("separation", int(GRID_GAP))
	var half: float = (w - GRID_GAP) * 0.5
	var row: HBoxContainer = null
	for c in cards:
		var d := c as Dictionary
		# a lone offer (the water/coin stalls) gets the Welcome bundle's full-row proportions rather
		# than a half-width tile stretched across the row.
		if bool(d.get("wide", false)) or cards.size() == 1:
			row = null
			col.add_child(_offer_card(refs, d, w, true))
			continue
		if row == null or row.get_child_count() >= 2:
			row = HBoxContainer.new()
			row.add_theme_constant_override("separation", int(GRID_GAP))
			col.add_child(row)
		row.add_child(_offer_card(refs, d, half, false))
	return col

# ONE offer card (the mock's product tile): a sage rounded face with the product ART on the left and,
# on the right, the amount in large navy type over the green price pill. Optional: a merchandising
# ribbon over the top-left corner (live flags only) and the navy "i" info disc top-right.
# d keys: icon · count · label · note · price · price_icon · affordable · ribbon · chips · on_buy · on_info.
static func _offer_card(refs: Dictionary, d: Dictionary, w: float, wide: bool) -> Control:
	var Kit: GDScript = refs.kit
	var h: float = w * (0.34 if wide else 0.58)
	var card := PanelContainer.new()
	card.name = "ShopOfferCard"
	var sb := StyleBoxFlat.new()
	sb.bg_color = SAGE
	sb.set_corner_radius_all(int(CARD_CORNER))
	sb.content_margin_left = 16; sb.content_margin_right = 16
	sb.content_margin_top = 12; sb.content_margin_bottom = 12
	_mock_shadow(sb)
	card.add_theme_stylebox_override("panel", sb)
	card.custom_minimum_size = Vector2(w, h)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# capped: a full-row card is tall enough to blow a plain currency glyph (the water/coin stalls sell a
	# small UI icon, not a painted pack) up past its source resolution, which reads flat and soft.
	var art_px: float = minf(h * (0.86 if wide else 0.66), 210.0)
	var art: Control = Kit.make_icon(String(d.get("icon", "gem")), art_px)
	art.custom_minimum_size = Vector2(art_px, art_px)
	art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(art)

	# a BUNDLE (the Welcome gift) states each granted currency on its own cream chip, mirroring the mock;
	# a single-product pack states one big amount. Both sit left of the price pill.
	if d.has("chips"):
		var chipcol := VBoxContainer.new()
		chipcol.alignment = BoxContainer.ALIGNMENT_CENTER
		chipcol.add_theme_constant_override("separation", 10)
		chipcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chipcol.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		chipcol.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for ch in d.chips:
			chipcol.add_child(_amount_chip(Kit, ch as Dictionary))
		body.add_child(chipcol)
	else:
		var textcol := VBoxContainer.new()
		textcol.alignment = BoxContainer.ALIGNMENT_CENTER
		textcol.add_theme_constant_override("separation", 8)
		textcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		textcol.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		textcol.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var count := int(d.get("count", 0))
		var amount_text := _commas(count) if count > 0 else String(d.get("label", ""))
		if amount_text != "":
			var al := _ink_label(Kit, amount_text, FS.DISPLAY if count > 0 else FS.BODY)
			al.name = "ShopOfferAmount"
			al.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			al.mouse_filter = Control.MOUSE_FILTER_IGNORE
			textcol.add_child(al)
		if String(d.get("note", "")) != "":
			var nl := Label.new()
			nl.text = String(d.note)
			nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			nl.add_theme_font_size_override("font_size", FS.FINE)
			nl.add_theme_color_override("font_color", Color(BARK, 0.9))
			nl.add_theme_constant_override("outline_size", 0)
			nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			textcol.add_child(nl)
		var pill := _price_pill(refs, d)
		if pill != null:
			var pw := CenterContainer.new()
			pw.mouse_filter = Control.MOUSE_FILTER_IGNORE
			pw.add_child(pill)
			textcol.add_child(pw)
		body.add_child(textcol)
	if d.has("chips"):
		var wpill := _price_pill(refs, d)
		if wpill != null:
			wpill.size_flags_vertical = Control.SIZE_SHRINK_END
			body.add_child(wpill)
	card.add_child(body)

	# the card's own overlay layer: the merchandising ribbon (top-left) + the info disc (top-right).
	var outer := Control.new()
	outer.custom_minimum_size = Vector2(w, h)
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer.add_child(card)
	if String(d.get("ribbon", "")) != "":
		# the shared kit ribbon art (kit/shop_tag.png), sized to the mock's banner and hung over the
		# card's top-left corner so it overhangs the edge exactly as the mock draws it.
		var rb: Control = Kit._ribbon_badge(String(d.ribbon), 2.0)
		rb.name = "ShopOfferRibbon"
		rb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rb.position = Vector2(-10.0, 10.0)
		outer.add_child(rb)
	var on_info: Callable = d.get("on_info", Callable())
	if on_info.is_valid():
		var ib := _info_disc(Kit, on_info)
		ib.anchor_left = 1.0; ib.anchor_right = 1.0
		ib.offset_left = -58.0; ib.offset_right = -12.0
		ib.offset_top = 12.0; ib.offset_bottom = 58.0
		outer.add_child(ib)
	return outer

# The GREEN price pill — the card's buy CTA (a real-money price, a 💎 cost, or a free claim). Carries the
# `shop_buy` meta the UI-shape smoke counts, plus `shop_cash` on a real-money pack (the capture tool taps it).
static func _price_pill(refs: Dictionary, d: Dictionary) -> Button:
	if String(d.get("price", "")) == "":
		return null
	var Kit: GDScript = refs.kit
	var icon_id := String(d.get("price_icon", ""))
	var b := Button.new()
	b.name = "ShopBuyButton"
	b.text = "" if icon_id != "" else String(d.price)
	b.focus_mode = Control.FOCUS_NONE
	b.set_meta("shop_buy", true)
	if bool(d.get("cash", false)):
		b.set_meta("shop_cash", true)
	b.add_theme_font_override("font", Kit.bold_font())
	b.add_theme_font_size_override("font_size", FS.BODY)
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(c, CREAM)
	b.add_theme_constant_override("outline_size", 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = PILL_GREEN
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 26; sb.content_margin_right = 26
	sb.content_margin_top = 12; sb.content_margin_bottom = 12
	_mock_shadow(sb)
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, sb)
	b.custom_minimum_size = Vector2(190, 62)   # the mock's pills read as one consistent slab, not text-snug
	# a 💎/🪙-priced CTA carries its currency glyph beside the number (the USD packs print the price alone).
	if icon_id != "":
		var h := HBoxContainer.new()
		h.set_anchors_preset(Control.PRESET_FULL_RECT)
		h.alignment = BoxContainer.ALIGNMENT_CENTER
		h.add_theme_constant_override("separation", 10)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ic: Control = Kit.make_icon(icon_id, 38.0)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(ic)
		var pl := Label.new()
		pl.text = String(d.price)
		pl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		pl.add_theme_font_override("font", Kit.bold_font())
		pl.add_theme_font_size_override("font_size", FS.BODY)
		pl.add_theme_color_override("font_color", CREAM)
		pl.add_theme_constant_override("outline_size", 0)
		pl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(pl)
		b.add_child(h)
	if d.has("affordable") and not bool(d.get("affordable", true)):
		b.modulate = Color(1, 1, 1, 0.45)   # can't afford → the CTA greys (still pressable: the wallet wiggles)
	var cb: Callable = d.get("on_buy", Callable())
	if cb.is_valid():
		b.pressed.connect(func() -> void: cb.call())
	return b

# A bundle's per-currency amount chip (mock: cream pill · icon · count) — one per granted currency.
static func _amount_chip(Kit: GDScript, ch: Dictionary) -> Control:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = CHIP_CREAM
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 16; sb.content_margin_right = 22
	sb.content_margin_top = 6; sb.content_margin_bottom = 6
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(Kit.make_icon(String(ch.get("icon", "gem")), 48.0))
	h.add_child(_ink_label(Kit, _commas(int(ch.get("amount", 0))), FS.BODY))
	p.add_child(h)
	return p

# The navy "i" disc (mock) — a textless icon Button, so the buy-CTA smoke never miscounts it.
static func _info_disc(Kit: GDScript, on_info: Callable) -> Button:
	var b := Button.new()
	b.name = "ShopInfoButton"
	b.focus_mode = Control.FOCUS_NONE
	var sb := StyleBoxFlat.new()
	sb.bg_color = INK
	sb.set_corner_radius_all(23)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	var psb: StyleBoxFlat = sb.duplicate()
	psb.bg_color = INK.lightened(0.15)
	b.add_theme_stylebox_override("pressed", psb)
	b.add_theme_stylebox_override("focus", sb)
	var l := Label.new()
	l.text = "i"
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", Kit.bold_font())
	l.add_theme_font_size_override("font_size", FS.BODY)
	l.add_theme_color_override("font_color", CREAM)
	l.add_theme_constant_override("outline_size", 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(l)
	b.pressed.connect(func() -> void: on_info.call())
	return b

# The sheet's INFO FOOTER — a cream strip stating the one live offer rule that isn't visible on a card
# (the first-purchase doubler). Absent when the doubler is spent; never states an offer that isn't live.
static func _footer_note(refs: Dictionary) -> Control:
	if String(refs.get("kind", "premium")) != "premium" or not first_buy_doubled():
		return null
	var Kit: GDScript = refs.kit
	var p := PanelContainer.new()
	p.name = "ShopFooterNote"
	var sb := StyleBoxFlat.new()
	sb.bg_color = FOOTER_CREAM
	sb.set_corner_radius_all(int(CARD_CORNER))
	sb.content_margin_left = 20; sb.content_margin_right = 20
	sb.content_margin_top = 12; sb.content_margin_bottom = 12
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var disc := Panel.new()
	var dsb := StyleBoxFlat.new()
	dsb.bg_color = INK
	dsb.set_corner_radius_all(20)
	disc.add_theme_stylebox_override("panel", dsb)
	disc.custom_minimum_size = Vector2(40, 40)
	disc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dl := Label.new()
	dl.text = "i"
	dl.set_anchors_preset(Control.PRESET_FULL_RECT)
	dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dl.add_theme_font_override("font", Kit.bold_font())
	dl.add_theme_font_size_override("font_size", FS.FINE)
	dl.add_theme_color_override("font_color", CREAM)
	dl.add_theme_constant_override("outline_size", 0)
	dl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	disc.add_child(dl)
	h.add_child(disc)
	var t := Label.new()
	t.text = Strings.t("shop.premium.first_buy_note")
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.add_theme_font_size_override("font_size", FS.FINE)
	t.add_theme_color_override("font_color", INK)
	t.add_theme_constant_override("outline_size", 0)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(t)
	p.add_child(h)
	return p

# A bold navy label (the mock's one type voice for titles, headers, amounts).
static func _ink_label(Kit: GDScript, text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", Kit.bold_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", INK)
	l.add_theme_constant_override("outline_size", 0)
	return l

# The mock's tinted drop shadow, applied ON the element's own StyleBoxFlat so it follows the exact
# rounded corners (the same values residents.gd uses — one house shadow, not a parallel one).
static func _mock_shadow(sb: StyleBoxFlat) -> void:
	Look.apply_box_shadow(sb)

# Thousands separators on a pack's amount ("13000" → "13,000"), as the mock prints them.
static func _commas(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out

# Build the live shop SECTIONS for the kit dialog, filtered to the open shop's KIND: the water stall
# shows the Fill-water card; the coin stall the Coin pouch; the premium stall the free-acorn
# faucet + the one-time Welcome bundle + the Acorn-pouch ladder. Each card carries its data +
# buy/info callbacks + a build-time `affordable` flag (the kit dims the price when broke). Rebuilt on every buy.
static func _sections(refs: Dictionary) -> Array:
	match String(refs.get("kind", "premium")):
		"water": return _water_sections(refs)
		"coin": return _coin_sections(refs)
		_: return _premium_sections(refs)

# WATER shop — the FREE daily refill (a full can, capped + cooled) leads, then the 💎 fill. Water is a
# Save-backed currency now (like coins/gems): both cards grant through Save (set/add_water), so the stall
# is host-agnostic — it shows the same from the board AND the hub, with no per-scene callbacks to forget.
# The board re-syncs its live water cache via the HUD refresh. The boost is no longer sold here (T57).
static func _water_sections(refs: Dictionary) -> Array:
	var host: Control = refs.host
	var gems := Save.diamonds()
	# the FREE refill faucet — the lead card
	var secs: Array = [{"caption": Strings.t("shop.refill.caption"), "cards": [_refill_card(refs)]}]
	# the 💎 fill — top the can to full
	var card := {
		"icon": "water", "count": int(G.WATER_CAP),   # the mock's card states the AMOUNT it grants (a full can)
		"price": str(int(G.REFILL_DIAMOND_COST)), "price_icon": "gem",
		"affordable": gems >= int(G.REFILL_DIAMOND_COST),
		"on_buy": func() -> void: _flow_water(refs),
		"on_info": func() -> void: _info_sheet(host, Strings.t("shop.water.info_title"), [{
			"icon": "water", "label": Strings.t("shop.water.info_row_label"), "amount": str(int(G.WATER_CAP)),
			"note": Strings.t("shop.water.info_row_note")}],
			Strings.t("shop.water.info_note"))}
	secs.append({"caption": Strings.t("shop.water.caption"), "cards": [card]})
	return secs

# The free-refill card: a full 💧 can + a green "Free" CTA when offerable; when cooling/capped the CTA
# drops and the cozy timer reads as plain text inside the card (a faucet at rest, not a greyed wall).
# on_buy re-checks the gate so a stale press can't over-grant.
static func _refill_card(refs: Dictionary) -> Dictionary:
	var host: Control = refs.host
	var st := refill_status()
	var card := {
		"icon": "water", "count": refill_amount(),
		"on_info": func() -> void: _info_sheet(host, Strings.t("shop.refill.info_title"), [{
			"icon": "water", "label": Strings.t("shop.refill.info_row_label"), "amount": str(refill_amount()),
			"note": Strings.t("shop.refill.info_row_note")}],
			Strings.t("shop.refill.info_note"))}
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

# COIN shop — the Coin pouch (turn 💎 into coins). (The coin-priced item shortcuts were removed
# 2026-06-23 — item-buying is moving to the board's item info bar.)
static func _coin_sections(refs: Dictionary) -> Array:
	var host: Control = refs.host
	var gems := Save.diamonds()
	var pouch := {
		"icon": "coin", "count": COIN_PACK,           # the mock's card states the AMOUNT it grants
		"price": str(COIN_PACK_GEM_COST), "price_icon": "gem",
		"affordable": gems >= COIN_PACK_GEM_COST,
		"on_buy": func() -> void: _flow_coins(refs),
		"on_info": func() -> void: _info_sheet(host, Strings.t("shop.coin.info_title"), [{
			"icon": "coin", "label": Strings.t("shop.coin.info_row_label"), "amount": str(COIN_PACK),
			"note": Strings.t("shop.coin.info_row_note")}],
			Strings.t("shop.coin.info_note"))}
	return [{"caption": Strings.t("shop.coin.quick_help_caption"), "cards": [pouch]}]

# PREMIUM shop — the free-acorn faucet, the one-time Welcome bundle, and the cash → 💎 Acorn ladder.
# (The 💎-priced item shortcut was removed 2026-06-23 — item-buying is moving to the board's item info bar.)
static func _premium_sections(refs: Dictionary) -> Array:
	var host: Control = refs.host
	var secs: Array = []
	# (The free-acorn faucet card was retired 2026-06-23 — acorns are precious/earned-only, Option A.)
	# Welcome — the one-time, high-value starter bundle (new players only, until claimed). The shop card art
	# is built for ONE hero item, so the card shows a single placeholder icon + the price; the bundle's
	# breakdown (acorns + water) lives in the info sheet (the "i"), not crammed into the hero.
	if starter_available():
		var chips: Array = [{"icon": "gem", "amount": int(STARTER_PACK.get("gems", 0))}]
		if int(STARTER_PACK.get("water", 0)) > 0:
			chips.append({"icon": "water", "amount": int(STARTER_PACK.get("water", 0))})
		secs.append({"caption": Strings.t("shop.premium.welcome_gift_caption"), "cards": [{
			"icon": _starter_icon_id(), "wide": true, "cash": true, "chips": chips,
			"ribbon": Strings.t("shop.premium.welcome_ribbon"),
			"price": Iap.usd(String(STARTER_PACK.get("key", ""))),
			"on_buy": func() -> void: _confirm_starter(host, refs),
			"on_info": func() -> void: _starter_info(host)}]})
	# Acorn pouches — the cash → 💎 ladder (escalating gem art + the merchandising ribbons). The
	# first-purchase doubler is a SECTION badge + the footer note (the mock), not a ribbon on every card —
	# so the per-card ribbons stay what the pack DATA says (pop / the ladder top), never a fabricated flag.
	var packs: Array = []
	for i in CASH_PACKS.size():
		var pack: Dictionary = CASH_PACKS[i]
		var card := {
			"icon": _gem_icon_id(i), "count": int(pack.gems), "cash": true,
			"price": Iap.usd(String(pack.key)),
			"on_buy": func() -> void: _confirm_cash(host, refs, i)}
		if bool(pack.get("pop", false)):
			card["ribbon"] = Strings.t("shop.premium.ribbon_popular")
		elif i == CASH_PACKS.size() - 1:
			card["ribbon"] = Strings.t("shop.premium.ribbon_best_value")
		packs.append(card)
	var sec := {"caption": Strings.t("shop.premium.acorn_pouches_caption"), "cards": packs}
	if first_buy_doubled():
		sec["badge"] = Strings.t("shop.premium.ribbon_first_buy")
	secs.append(sec)
	return secs

# The escalating gem art id for ladder pack i (gem_t1…), falling back to the plain gem when the grove
# has more packs than tier sprites — mirrors the old _gem_card art ladder.
static func _gem_icon_id(i: int) -> String:
	var art := "gem_t%d" % (i + 1)
	return art if ResourceLoader.exists(Game.art("ui/currency/icon_%s.png" % art)) else "gem"

# The Welcome bundle's hero ICON id. The card art holds ONE item, so the bundle shows a single hero (the
# acorns + water breakdown lives in the info sheet). Prefers a baked welcome sprite (ui/shared/icon_welcome
# .png) once it exists; until then the in-style gift icon stands in (the same resolver fallback as the gems).
static func _starter_icon_id() -> String:
	return "welcome" if ResourceLoader.exists(Game.art("ui/shared/icon_welcome.png")) else "gift"

# The Welcome bundle's contents as info-sheet ROWS (the card shows only the hero + price now). One row per
# currency the bundle grants, read live from STARTER_PACK so the copy never drifts from what it grants.
static func starter_info_items(host: Control) -> Array:
	var items: Array = [{
		"icon": "gem", "label": Strings.t("shop.starter.acorns_label"), "amount": str(int(STARTER_PACK.get("gems", 0))),
		"note": Strings.t("shop.starter.acorns_note")}]
	var water := int(STARTER_PACK.get("water", 0))
	if water > 0:
		items.append({"icon": "water", "label": Strings.t("shop.starter.water_label"), "amount": str(water),
			"note": Strings.t("shop.starter.water_note")})
	return items

# The Welcome card's "i" → the bundle's detail sheet (the parchment info modal the other shop cards use).
static func _starter_info(host: Control) -> void:
	_info_sheet(host, Strings.t("shop.starter.info_title"), starter_info_items(host),
		Strings.t("shop.starter.info_note"))

# --- buy flows (kit cards have no Button to hand the old _try_buy; these take refs + rebuild) --------
# A direct buy in `currency` ("gem"|"coin"): can't afford → wallet wiggles; else spend+grant, fly the
# grant home to the HUD wallet, and rebuild the storefront so affordability re-reads.
static func _flow_water(refs: Dictionary) -> void:
	var act := func() -> bool:
		if not buy_water():
			return false
		Save.fill_water()                # top the can to full (Save-backed; the HUD refresh re-reads it)
		return true
	_buy(refs, "gem", int(G.REFILL_DIAMOND_COST), act, "water")

static func _flow_coins(refs: Dictionary) -> void:
	_buy(refs, "gem", COIN_PACK_GEM_COST, buy_coin_pack, "coin")

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

# The item-detail sheet the "i" opens (§10 product info) — now the SAME mail dialog the inbox wears
# (parchment cards, NO Claim) closed by a level-style "Got it" footer; tap the veil to dismiss. Read-only,
# never buys. This layer owns the modal overlay/veil; the card FACE is the shared, workbench-tuned
# Kit.mail_dialog (one source of truth). Each `items` line → a mail entry: label→title, note→body, and the
# amount rides a read-only cream chip (no Claim). `items` = [{icon, label, amount, note}]; `note` is the
# optional footer caption under the cards.
static func _info_sheet(host: Control, title: String, items: Array, note := "") -> void:
	var Kit: GDScript = load(KIT_PATH)
	if Kit == null:
		return
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = Overlay.MODAL_TOP_Z          # the info sheet sits ABOVE the open shop
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
	var cfg: Dictionary = Kit.load_config(Kit.CONFIG_PATH)
	var iopts: Dictionary = Kit.info_opts_from_config(cfg)
	iopts["content_scale"] = Kit.dialog_content_scale(cfg, "info")
	var width: float = host.get_viewport_rect().size.x * Kit.DIALOG_DESIGN_PCT["info"] / 100.0
	iopts["on_close"] = func() -> void: overlay.queue_free()
	iopts["banner_text"] = title             # the ribbon title (a generic info sheet wears no banner icon)
	iopts["banner_icon_on"] = false
	iopts["note"] = note                     # the optional footer caption under the cards
	iopts["got_it"] = Strings.t("shop.info.got_it")
	# each line item → a mail entry with a read-only amount chip (no reward → no Claim button).
	var entries: Array = []
	for it in items:
		var e := {
			"icon": String((it as Dictionary).get("icon", "")),
			"title": String((it as Dictionary).get("label", "")),
			"body": String((it as Dictionary).get("note", "")),
		}
		var amount := String((it as Dictionary).get("amount", ""))
		if amount != "":
			e["chip"] = {"icon": String((it as Dictionary).get("icon", "")), "text": amount}
		entries.append(e)
	var card: Control = Kit.mail_dialog(entries, width, iopts)
	cc.add_child(card)
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
	var key := String(pack.key)
	var doubled := first_buy_doubled()
	var gems := int(pack.gems) * (int(FIRST_BUY_MULT) if doubled else 1)
	var sub := Strings.t("shop.cash.first_buy_bonus") if doubled else ""
	_confirm_gem_grant(host, refs, Strings.t("shop.cash.confirm_title"),
		Strings.t("shop.cash.confirm_line") % [gems, Iap.usd(key)], sub, key, func() -> void:
			grant_cash_pack(i))

# The starter-pack confirm: same honest parchment confirm; confirming grants the bundle
# (💎 now + the water credit the board applies on open) exactly once.
static func _confirm_starter(host: Control, refs: Dictionary) -> void:
	var key := String(STARTER_PACK.get("key", ""))
	var gems := int(STARTER_PACK.get("gems", 0))
	var water_amt := int(STARTER_PACK.get("water", 0))
	var line := Strings.t("shop.starter.confirm_line") % [gems, Iap.usd(key)]
	var sub := Strings.t("shop.starter.confirm_sub") % water_amt if water_amt > 0 else ""
	_confirm_gem_grant(host, refs, Strings.t("shop.starter.confirm_title"), line, sub, key, func() -> void:
		grant_starter())

# The shared honest cash-confirm body (§10): parchment card, ribbon title, the 💎 line,
# an optional sub-line, the "(test build — nothing is charged)" note, Cancel/Confirm. On
# Confirm it runs `grant` (the pure grant that owns the actual currency math), flies a 💎
# to the wallet, and settles. A real store SDK + receipt check replaces ONLY the inside of
# `grant` + a guard around this Confirm — the frame, the note, and the wiring stay.
static func _confirm_gem_grant(host: Control, refs: Dictionary, title: String,
		line: String, sub: String, product_key: String, grant: Callable) -> void:
	var Kit: GDScript = load(KIT_PATH)
	if Kit == null:
		return
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = Overlay.MODAL_TOP_Z          # the cash confirm sits ABOVE the open shop
	host.add_child(overlay)
	var veil := ColorRect.new()
	veil.color = Color(INK, Tune.CONFIRM_VEIL_ALPHA)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(veil)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(cc)
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
	var cfg: Dictionary = Kit.load_config(Kit.CONFIG_PATH)
	var copts: Dictionary = Kit.dialog_opts_from_config(cfg)
	copts["content_scale"] = Kit.dialog_content_scale(cfg, "dialog")
	copts["banner_text"] = title
	copts["banner_icon_on"] = false
	copts["center_content"] = true
	copts["on_close"] = func() -> void: overlay.queue_free()
	var vp := host.get_viewport()
	var vw: float = vp.get_visible_rect().size.x if vp != null else 1080.0
	var width: float = maxf(1.0, vw) * Kit.DIALOG_DESIGN_PCT["dialog"] / 100.0
	dialog = Kit.dialog_frame(col, width, copts)
	cc.add_child(dialog)
	FX.pop_in(dialog)
