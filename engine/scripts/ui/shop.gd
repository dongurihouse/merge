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
const SpritePanel = preload("res://engine/scripts/ui/sprite_panel.gd")   # cut-paper drop shadow wrap
const OVERLAY_NAME := "ShopOverlay"

const INK = Pal.INK
const CREAM = Pal.CREAM
const STRAW = Pal.STRAW
const BARK = Pal.BARK

# The storefront FACE is built from the shared kit (the UI workbench), like the mailbox + daily login —
# so the shop's look is authored once in the workbench and never duplicated here. The buy LOGIC stays.
const KIT_PATH := "res://games/grove/ui_kit.gd"

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
	# ink title and coral ✕ every restyled dialog wears); the shop's own BODY (section headers · the
	# 2-up offer grid · the info footer) is built here, per the shop_dialog_v3_unified_storefront mock.
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
		var fopts: Dictionary = Kit.dialog_opts_from_config(cfg)
		fopts["content_scale"] = cscale
		fopts["banner_text"] = Strings.t("shop.title")
		fopts["clip_below_banner"] = true   # the list clips UNDER the title band — rows never ride behind "SHOP"
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

# --- the mock-true storefront body (shop_dialog_v3_unified_storefront) ---------------
# Colours sampled from the mock; the sheet/title/✕ come from the shared frame and are NOT re-specified.
const SAGE := Color("#E4DEBD")        # an offer card's sage face
const PILL_GREEN := Color("#5C8A57")  # the price pill
const CARD_CORNER := 18.0
const GRID_GAP := 14.0

# Cut-paper RE-SKIN textures (extracted from the shop mock): the blank green button and the empty card
# frames at their three sizes. Worn as a 9-sliced StyleBoxTexture so a card/button stretches to any size
# with crisp torn corners. Absent files fall back to the drawn flat styleboxes.
const SKIN_DIR := "res://games/grove/assets/ui/dialogs/shop/"
static func _skin_tex(key: String) -> Texture2D:
	var p := SKIN_DIR + key + ".png"
	return load(p) as Texture2D if ResourceLoader.exists(p) else null

## A 9-sliced StyleBoxTexture from a cut-paper frame sprite: the corner caps (frac of the texture) stay
## crisp while the middle stretches. `pad` sets the inner content margins (px, in design space).
static func _tex_box(tex: Texture2D, pad_x: float, pad_y: float, cap_frac := 0.30) -> StyleBoxTexture:
	var st := StyleBoxTexture.new()
	st.texture = tex
	var mx := tex.get_width() * cap_frac
	var my := tex.get_height() * cap_frac
	st.texture_margin_left = mx; st.texture_margin_right = mx
	st.texture_margin_top = my; st.texture_margin_bottom = my
	st.content_margin_left = pad_x; st.content_margin_right = pad_x
	st.content_margin_top = pad_y; st.content_margin_bottom = pad_y
	return st

# The whole scrolling body: each section's header + offer grid.
static func _build_body(refs: Dictionary) -> Control:
	return build_body(refs.kit, refs.inner, _sections(refs), shop_layout(refs.get("cfg", {})))

## The shop BODY — the VBox of section headers + offer grids, built purely from section DATA (each
## {caption, cards[]}). SHARED: the game (_build_body) computes the sections from live state and passes
## them here; the workbench "shop" element passes demo sections. So the tool renders the real shop layout.
## The shop LAYOUT knobs read from the saved config's "shop" block — the offer-card metrics the workbench
## tunes and the game honours: icon size (% of default art), card padding, the grid gap/margin, and the
## card corner. Absent keys reproduce the mock-measured constants exactly.
static func shop_layout(cfg: Dictionary) -> Dictionary:
	var sh: Dictionary = (cfg as Dictionary).get("shop", {}) if cfg is Dictionary else {}
	return {
		"icon_size": float(sh.get("icon_size", 100)) / 100.0,   # art size, % of the default
		"card_pad": float(sh.get("card_pad", 12)),              # inner padding (px)
		"grid_gap": float(sh.get("grid_gap", GRID_GAP)),        # gap between cards + sections (px)
		"corner": float(sh.get("corner", CARD_CORNER)),         # card corner radius (px)
	}

static func build_body(Kit: GDScript, w: float, sections: Array, lay: Dictionary = {}) -> Control:
	var col := VBoxContainer.new()
	col.name = "ShopBody"
	col.add_theme_constant_override("separation", int(float(lay.get("grid_gap", GRID_GAP)) + 2.0))
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for sec in sections:
		var s := sec as Dictionary
		col.add_child(_section_header(Kit, String(s.get("caption", ""))))
		col.add_child(_offer_grid(Kit, s.get("cards", []), w, lay))
	return col

# A section HEADER — the mock's centred navy all-caps title.
static func _section_header(Kit: GDScript, caption: String) -> Control:
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
	return row

# One section's offers as the mock's TWO-column grid. A card marked `wide` (the Welcome bundle) takes a
# full row of its own; the rest pair up.
static func _offer_grid(Kit: GDScript, cards: Array, w: float, lay: Dictionary = {}) -> Control:
	var col := VBoxContainer.new()
	col.name = "ShopOfferGrid"
	col.add_theme_constant_override("separation", int(GRID_GAP))
	var gap: float = float(lay.get("grid_gap", GRID_GAP))
	var half: float = (w - gap) * 0.5
	var row: HBoxContainer = null
	for c in cards:
		var d := c as Dictionary
		# a lone offer (the Free-refill lead) gets the Welcome bundle's full-row proportions rather
		# than a half-width tile stretched across the row.
		if bool(d.get("wide", false)) or cards.size() == 1:
			row = null
			col.add_child(_offer_card(Kit, d, w, true, lay))
			continue
		if row == null or row.get_child_count() >= 2:
			row = HBoxContainer.new()
			row.add_theme_constant_override("separation", int(gap))
			col.add_child(row)
		row.add_child(_offer_card(Kit, d, half, false, lay))
	return col

# ONE offer card (the mock's product tile): a sage rounded face with the product ART filling the left
# and, on the right, the amount in large navy type over the green buy CTA. Tight padding — the art and
# the CTA carry the card.
# d keys: title · icon · count · label · note · price · price_icon · affordable · cash · on_buy.
static func _offer_card(Kit: GDScript, d: Dictionary, w: float, wide: bool, lay: Dictionary = {}) -> Control:
	var h: float = w * (0.26 if wide else 0.54)
	var card := PanelContainer.new()
	card.name = "ShopOfferCard"
	var pad: float = float(lay.get("card_pad", 12))
	# reskin: the baked cut-paper card frame for this card's size — wide (Free refill), tall (titled
	# Quick-help pair), or landscape pouch (Acorn pouches) — 9-sliced so it stretches without distorting
	# the torn corners. Falls back to the drawn sage stylebox.
	var card_key := "card_wide" if wide else ("card_tall" if String(d.get("title", "")) != "" else "card_pouch")
	var card_tex := _skin_tex(card_key)
	if card_tex != null:
		card.add_theme_stylebox_override("panel", _tex_box(card_tex, pad, pad * 0.67))
	else:
		var sb := StyleBoxFlat.new()
		sb.bg_color = SAGE
		sb.set_corner_radius_all(int(float(lay.get("corner", CARD_CORNER))))
		sb.content_margin_left = pad; sb.content_margin_right = pad
		sb.content_margin_top = pad * 0.67; sb.content_margin_bottom = pad * 0.67
		_mock_shadow(sb)
		card.add_theme_stylebox_override("panel", sb)
	card.custom_minimum_size = Vector2(w, h)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# the art FILLS the card's left side (mock); capped so a 512px master never upscales past crisp.
	var art_px: float = minf(h * (0.95 if wide else 0.78), 240.0) * float(lay.get("icon_size", 1.0))
	var art: Control = Kit.make_icon(String(d.get("icon", "gem")), art_px)
	art.custom_minimum_size = Vector2(art_px, art_px)
	art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# give the item art a shape-true cut-paper drop shadow too (a dark copy of its own silhouette —
	# wrap_sprite, not wrap: the card's rect cast would print a grey slab around the transparent art)
	if art is TextureRect and (art as TextureRect).texture != null:
		art = SpritePanel.wrap_sprite(art, (art as TextureRect).texture)
	body.add_child(art)

	var textcol := VBoxContainer.new()
	textcol.alignment = BoxContainer.ALIGNMENT_CENTER
	textcol.add_theme_constant_override("separation", 6)
	textcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	textcol.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	textcol.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var count := int(d.get("count", 0))
	var amount_text := _commas(count) if count > 0 else String(d.get("label", ""))
	if amount_text != "":
		var al := _amount_label(amount_text, FS.DISPLAY if count > 0 else FS.BODY)
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
	var pill := _price_pill(Kit, d)
	# a textured pill keeps its OWN aspect (set in _price_pill) — skip the stretch-to-column overrides.
	var pill_textured := pill != null and pill.has_meta("shop_textured")
	if pill != null and wide:
		# a WIDE single-product card lays out as the mock's one row: art left · the amount
		# centred in the open middle · the green CTA docked at the right edge.
		body.add_child(textcol)
		pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if not pill_textured:
			pill.custom_minimum_size.x = 230.0
		body.add_child(pill)
	else:
		if pill != null:
			# the CTA spans the card's right column (mock: the green slab owns the bottom-right half)
			if not pill_textured:
				pill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			textcol.add_child(pill)
		body.add_child(textcol)
	# a TITLED card (the mock's Quick-help pair) heads itself with a small centred navy caps line
	# ("FILL WATER" / "COIN POUCH") above the icon+amount body; untitled cards are unchanged.
	if String(d.get("title", "")) != "":
		var titled := VBoxContainer.new()
		titled.add_theme_constant_override("separation", 2)
		titled.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tl := _ink_label(Kit, String(d.title).to_upper(), FS.BODY)
		tl.name = "ShopOfferTitle"
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		titled.add_child(tl)
		body.size_flags_vertical = Control.SIZE_EXPAND_FILL
		titled.add_child(body)
		card.add_child(titled)
	else:
		card.add_child(body)
	# a textured card gains the cut-paper drop shadow (shadow copies behind the StyleBoxTexture card)
	return SpritePanel.wrap(card, card_tex) if card_tex != null else card

# The GREEN price pill — the card's buy CTA (a real-money price, a 💎 cost, or a free claim). Carries the
# `shop_buy` meta the UI-shape smoke counts, plus `shop_cash` on a real-money pack (the capture tool taps it).
static func _price_pill(Kit: GDScript, d: Dictionary) -> Control:
	if String(d.get("price", "")) == "":
		return null
	var icon_id := String(d.get("price_icon", ""))
	# the SHARED pill_button (green role) — the code-drawn cut-paper edge + its OWN shape-true shadow,
	# tuned from the workbench Button element. The whole pill keeps its natural width (deckle must not
	# stretch), so the `shop_textured` meta tells the caller to skip the stretch-to-column overrides.
	var price := String(d.price)
	var opts := {
		"bg": "green",
		"font": FS.HEADING,
		"icon": icon_id,          # a 💎/🪙 cost carries its glyph; a USD/free pack ("") prints the text alone
		"icon_size": 44,
		"shadow": true,
	}
	var b: Button = Kit.pill_button("" if icon_id != "" else price.to_upper(), opts)
	b.name = "ShopBuyButton"
	b.set_meta("shop_buy", true)
	b.set_meta("shop_textured", true)
	if bool(d.get("cash", false)):
		b.set_meta("shop_cash", true)
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

# A bold navy label (the mock's one type voice for titles and headers).
static func _ink_label(Kit: GDScript, text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", Kit.bold_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", INK)
	l.add_theme_constant_override("outline_size", 0)
	return l

# A card's AMOUNT — large navy, in the standard (not bold) face, centred.
static func _amount_label(text: String, size: int) -> Label:
	var l := Label.new()
	l.name = "ShopOfferAmount"
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", INK)
	l.add_theme_constant_override("outline_size", 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
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

# Build the live shop SECTIONS for the unified storefront (shop_dialog_v3): the FREE refill leads,
# then Quick help (the 💎 Fill-water + the Coin pouch, side by side), then the one-time Welcome
# bundle + the Acorn-pouch cash ladder. Each card carries its data + buy/info callbacks + a
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
		"title": Strings.t("shop.water.fill_label"),
		"icon": "shop_can", "count": int(G.WATER_CAP),   # the mock's card states the AMOUNT it grants (a full can)
		"price": str(int(G.REFILL_DIAMOND_COST)), "price_icon": "gem",
		"affordable": gems >= int(G.REFILL_DIAMOND_COST),
		"on_buy": func() -> void: _flow_water(refs)}
	var pouch := {
		"title": Strings.t("shop.coin.pouch_label"),
		"icon": "shop_pouch", "count": COIN_PACK,        # the mock's card states the AMOUNT it grants
		"price": str(COIN_PACK_GEM_COST), "price_icon": "gem",
		"affordable": gems >= COIN_PACK_GEM_COST,
		"on_buy": func() -> void: _flow_coins(refs)}
	return {"caption": Strings.t("shop.coin.quick_help_caption"), "cards": [water, pouch]}

# The free-refill card: a full 💧 can + a green "Free" CTA when offerable; when cooling/capped the CTA
# drops and the cozy timer reads as plain text inside the card (a faucet at rest, not a greyed wall).
# on_buy re-checks the gate so a stale press can't over-grant.
static func _refill_card(refs: Dictionary) -> Dictionary:
	var st := refill_status()
	var card := {"icon": "shop_can", "count": refill_amount()}
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
