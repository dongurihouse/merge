extends RefCounted
## Tidy Up — the Shop as the squirrel merchant's MARKET STALL (GROVE_UI_SPEC §8;
## owner: "the store menu shouldn't just be a list of buttons"). Presentation
## only — grants, prices and the confirm-only cash flow are unchanged: diamonds
## buy SPEED, never possibility; cash buys diamonds behind an honest confirm
## ("test build — nothing is charged"); the future IAP hookup replaces only the
## middle of `_confirm_cash`. Pure grant funcs are static and test-covered.

const Save = preload("res://engine/scripts/save.gd")
const Look = preload("res://engine/scripts/skin.gd")
const G = preload("res://engine/scripts/grove_content.gd")
const FX = preload("res://engine/scripts/fx.gd")
const Audio = preload("res://engine/scripts/audio.gd")

const INK := Color("#33402F")
const CREAM := Color("#FBF3EA")
const STRAW := Color("#E3B23C")
const BARK := Color("#8A5A3B")

# water price = G.REFILL_DIAMOND_COST — ONE source of truth with the paid rain
const COIN_PACK := 150
const COIN_PACK_GEM_COST := 5
const CASH_PACKS := [
	{"usd": "$0.99", "gems": 80},
	{"usd": "$4.99", "gems": 450},
	{"usd": "$9.99", "gems": 1000},
]

# --- grants (pure; the UI calls these) --------------------------------------------

static func buy_water() -> bool:
	return Save.spend_diamonds(G.REFILL_DIAMOND_COST)

static func buy_coin_pack() -> bool:
	if not Save.spend_diamonds(COIN_PACK_GEM_COST):
		return false
	Save.add_coins(COIN_PACK)
	return true

static func grant_cash_pack(i: int) -> void:
	Save.add_diamonds(int(CASH_PACKS[i].gems))

# --- the storefront ----------------------------------------------------------------

static func open(host: Control, opts: Dictionary = {}) -> void:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.add_child(overlay)
	var veil := ColorRect.new()
	veil.color = Color(INK, 0.6)
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
	var vw: float = host.get_viewport_rect().size.x
	card.custom_minimum_size = Vector2(minf(920.0, vw * 0.86), 0)
	cc.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	card.add_child(col)

	# the stall: banner art when generated, plank band until then; the title is
	# ENGINE text riding a ribbon (images never carry words — §0.3)
	var header := Control.new()
	header.custom_minimum_size = Vector2(0, 140)
	header.clip_contents = true
	col.add_child(header)
	if ResourceLoader.exists(Look.KIT + "shop_stall.png"):
		var art := TextureRect.new()
		art.texture = load(Look.KIT + "shop_stall.png")
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
	var ribbon := Look.title_ribbon(host.tr("Shop"), 40)
	ribbon.anchor_left = 0.5
	ribbon.anchor_right = 0.5
	ribbon.anchor_top = 0.0
	ribbon.anchor_bottom = 0.0
	ribbon.offset_top = 4.0
	ribbon.grow_horizontal = Control.GROW_DIRECTION_BOTH
	ribbon.grow_vertical = Control.GROW_DIRECTION_END
	header.add_child(ribbon)

	# S12: the wallet docks INSIDE the parchment below the stall art, with its
	# own breathing room — chips never sit on the art
	var wpad := Control.new()
	wpad.custom_minimum_size = Vector2(0, 6)
	col.add_child(wpad)
	# wallet strip — you're here to spend; these chips tick on every purchase
	var wallet := HBoxContainer.new()
	wallet.alignment = BoxContainer.ALIGNMENT_CENTER
	wallet.add_theme_constant_override("separation", 14)
	col.add_child(wallet)
	var coin_chip := Look.stat_chip("coin", str(Save.coins()))
	wallet.add_child(coin_chip.node)
	var gem_chip := Look.stat_chip("gem", str(Save.diamonds()))
	wallet.add_child(gem_chip.node)
	var refs := {"coin": coin_chip, "gem": gem_chip, "overlay": overlay, "opts": opts}

	# — Quick help —
	_divider(col, host.tr("Quick help"))
	var help_row := HBoxContainer.new()
	help_row.alignment = BoxContainer.ALIGNMENT_CENTER
	help_row.add_theme_constant_override("separation", 14)
	col.add_child(help_row)
	if opts.has("water_grant"):
		var water_action := func() -> bool:
			if not buy_water():
				return false
			(opts.water_grant as Callable).call()
			return true
		help_row.add_child(_help_card(host, refs, "rain", host.tr("Fill your water"),
			host.tr("top up the can"), G.REFILL_DIAMOND_COST, water_action, "water"))
	help_row.add_child(_help_card(host, refs, "coin", host.tr("Coin pouch"),
		host.tr("+%d acorns") % COIN_PACK, COIN_PACK_GEM_COST, buy_coin_pack, "coin"))

	# — Dewdrop pouches (cash → diamonds; confirm-only) —
	_divider(col, host.tr("Dewdrop pouches"))
	var gem_row := HBoxContainer.new()
	gem_row.alignment = BoxContainer.ALIGNMENT_CENTER
	gem_row.add_theme_constant_override("separation", 14)
	col.add_child(gem_row)
	for i in CASH_PACKS.size():
		gem_row.add_child(_gem_card(host, refs, i))
	var foot := Control.new()
	foot.custom_minimum_size = Vector2(0, 6)
	col.add_child(foot)

	# the round ✕ rides the card's top-right corner (placed after layout)
	var x_btn := Button.new()
	x_btn.focus_mode = Control.FOCUS_NONE
	x_btn.custom_minimum_size = Vector2(64, 64)
	if ResourceLoader.exists(Look.KIT + "btn_round.png"):
		var xs := StyleBoxTexture.new()
		xs.texture = load(Look.KIT + "btn_round.png")
		xs.set_texture_margin_all(24.0)
		x_btn.add_theme_stylebox_override("normal", xs)
		x_btn.add_theme_stylebox_override("hover", xs)
		x_btn.add_theme_stylebox_override("pressed", xs)
	else:
		var xs := StyleBoxFlat.new()
		xs.bg_color = Color("#6E4B2F")
		xs.set_corner_radius_all(32)
		xs.set_border_width_all(3)
		xs.border_color = Color("#3D2A1B")
		x_btn.add_theme_stylebox_override("normal", xs)
		x_btn.add_theme_stylebox_override("hover", xs)
		var xp: StyleBoxFlat = xs.duplicate()
		xp.bg_color = Color("#5A3D26")
		x_btn.add_theme_stylebox_override("pressed", xp)
	x_btn.text = "✕"
	x_btn.add_theme_font_size_override("font_size", 30)
	x_btn.add_theme_color_override("font_color", CREAM)
	Look.add_press_juice(x_btn)
	x_btn.pressed.connect(func() -> void: overlay.queue_free())
	overlay.add_child(x_btn)
	# S15: the ✕ docks INSIDE the parchment's top-right (same close treatment
	# as the interior's round button) — it no longer floats on the awning corner
	var place_x := func() -> void:
		var r := card.get_global_rect()
		x_btn.global_position = Vector2(r.position.x + r.size.x - 64.0 - 12.0, r.position.y + 12.0)
	card.resized.connect(place_x)
	place_x.call_deferred()

	FX.pop_in(card)
	FX.scatter_in([wallet, help_row, gem_row], 0.08)

# A thin sprig divider with a caption (divider_vine art when generated).
# S13: the caption is a parchment TAB chip, baseline-aligned with its vine —
# not bare text floating at the parchment edge.
static func _divider(col: VBoxContainer, caption: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	var tab := PanelContainer.new()
	var ts := StyleBoxFlat.new()
	ts.bg_color = Color("#E8D9BC")
	ts.set_corner_radius_all(12)
	ts.set_border_width_all(2)
	ts.border_color = Color(BARK, 0.45)
	ts.content_margin_left = 12.0
	ts.content_margin_right = 12.0
	ts.content_margin_top = 3.0
	ts.content_margin_bottom = 4.0
	tab.add_theme_stylebox_override("panel", ts)
	tab.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var cap := Label.new()
	cap.text = caption
	cap.add_theme_font_size_override("font_size", 23)
	cap.add_theme_color_override("font_color", Color(INK, 0.9))
	tab.add_child(cap)
	row.add_child(tab)
	if ResourceLoader.exists(Look.KIT + "divider_vine.png"):
		var vine := TextureRect.new()
		vine.texture = load(Look.KIT + "divider_vine.png")
		vine.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		vine.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		vine.custom_minimum_size = Vector2(0, 26)
		vine.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(vine)
	else:
		var line := ColorRect.new()
		line.color = Color(BARK, 0.35)
		line.custom_minimum_size = Vector2(0, 3)
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(line)

# One "Quick help" card: icon, title, caption, gem price chip. Whole card presses.
static func _help_card(host: Control, refs: Dictionary, icon_id: String, title: String,
		caption: String, cost: int, action: Callable, fly_id: String) -> Button:
	var b := _card_button(Vector2(330, 232))
	var inner := VBoxContainer.new()
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_theme_constant_override("separation", 4)
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(inner)
	var ic := Look.icon(icon_id, 56.0)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	inner.add_child(ic)
	var t := Label.new()
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 27)
	t.add_theme_color_override("font_color", INK)
	inner.add_child(t)
	var c := Label.new()
	c.text = caption
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_theme_font_size_override("font_size", 20)
	c.add_theme_color_override("font_color", Color(BARK, 0.8))
	inner.add_child(c)
	var price := Look.stat_chip("gem", str(cost))
	price.node.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	(price.label as Label).add_theme_font_size_override("font_size", 26)
	inner.add_child(price.node)
	b.set_meta("shop_buy", true)
	b.set_meta("gem_cost", cost)
	b.pressed.connect(func() -> void:
		_try_buy(host, refs, b, cost, action, fly_id))
	_apply_afford(b)
	return b

# One cash pack card: gem art/icon, the count, the $ price. Middle = "Popular".
static func _gem_card(host: Control, refs: Dictionary, i: int) -> Button:
	var pack: Dictionary = CASH_PACKS[i]
	# S14: tall enough for badge+icon+count+price IN FLOW — content used to
	# overflow the 280px card and the Popular badge poked past the top edge
	var b := _card_button(Vector2(206, 312))
	var inner := VBoxContainer.new()
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_theme_constant_override("separation", 4)
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(inner)
	if i == 1:
		var pop := PanelContainer.new()
		var pp := StyleBoxFlat.new()
		pp.bg_color = STRAW
		pp.set_corner_radius_all(10)
		pp.content_margin_left = 10.0
		pp.content_margin_right = 10.0
		pp.content_margin_top = 2.0
		pp.content_margin_bottom = 2.0
		pop.add_theme_stylebox_override("panel", pp)
		var pl := Label.new()
		pl.text = host.tr("Popular")
		pl.add_theme_font_size_override("font_size", 18)
		pl.add_theme_color_override("font_color", INK)
		pop.add_child(pl)
		pop.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		inner.add_child(pop)
	var ic := Look.icon("gem", 64.0)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	inner.add_child(ic)
	var n := Label.new()
	n.text = str(int(pack.gems))
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.add_theme_font_size_override("font_size", 40)
	n.add_theme_color_override("font_color", INK)
	inner.add_child(n)
	# S14: a clean flat pill sized to content — the kit chip nine-patch's opaque
	# band is thinner than its layout rect (R1's lesson) and the price overflowed
	var price := PanelContainer.new()
	var prs := StyleBoxFlat.new()
	prs.bg_color = Color("#5A3F28", 0.94)
	prs.set_corner_radius_all(18)
	prs.set_border_width_all(2)
	prs.border_color = Color("#3D2A1B")
	prs.content_margin_left = 14.0
	prs.content_margin_right = 14.0
	prs.content_margin_top = 5.0
	prs.content_margin_bottom = 6.0
	price.add_theme_stylebox_override("panel", prs)
	var pr := Label.new()
	pr.text = String(pack.usd)
	pr.add_theme_font_size_override("font_size", 26)
	pr.add_theme_color_override("font_color", CREAM)
	price.add_child(pr)
	price.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	inner.add_child(price)
	b.set_meta("shop_buy", true)
	b.set_meta("shop_cash", i)
	b.pressed.connect(func() -> void:
		_confirm_cash(host, refs, i))
	return b

static func _card_button(min_size: Vector2) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = min_size
	var s := StyleBoxFlat.new()
	s.bg_color = Color("#F4E9D6")
	s.set_corner_radius_all(20)
	s.set_border_width_all(3)
	s.border_color = Color(BARK, 0.55)
	s.shadow_color = Color(0, 0, 0, 0.18)
	s.shadow_size = 4
	s.shadow_offset = Vector2(0, 3)
	b.add_theme_stylebox_override("normal", s)
	b.add_theme_stylebox_override("hover", s)
	var sp: StyleBoxFlat = s.duplicate()
	sp.bg_color = Color("#EADCC2")
	b.add_theme_stylebox_override("pressed", sp)
	Look.add_press_juice(b)
	return b

# Affordability is shown, never blocking: a dim card still presses (wallet wiggles).
static func _apply_afford(b: Button) -> void:
	if not b.has_meta("gem_cost"):
		return
	var ok := Save.diamonds() >= int(b.get_meta("gem_cost"))
	b.modulate = Color(1, 1, 1, 1.0) if ok else Color(0.72, 0.73, 0.7, 0.92)

static func _refresh_afford(overlay: Control) -> void:
	for b in overlay.find_children("*", "Button", true, false):
		_apply_afford(b)

static func _try_buy(host: Control, refs: Dictionary, b: Button, cost: int,
		action: Callable, fly_id: String) -> void:
	if Save.diamonds() < cost:
		Audio.play("invalid_soft", -4.0)
		FX.wobble(refs.gem.node)
		FX.floating_text(host, b.get_global_rect().get_center() - Vector2(100, 70),
			host.tr("Need %d more") % (cost - Save.diamonds()), CREAM, 28)
		return
	if not bool(action.call()):
		return
	Audio.play("merge_success", -3.0, 1.2)
	FX.pop(b)
	# the grant flies home and the wallet ticks — no rebuild flash
	var target: Control = refs.coin.node if fly_id == "coin" else refs.gem.node
	FX.fly_to_wallet(host, b.get_global_rect().get_center(), Look.icon(fly_id, 32.0), target,
		func() -> void: _settle(host, refs))
	_settle(host, refs)

# Wallet chips (shop + HUD) tick to the new balances; affordability re-tints.
static func _settle(host: Control, refs: Dictionary) -> void:
	FX.tick(refs.coin.label, Save.coins())
	FX.tick(refs.gem.label, Save.diamonds())
	var opts: Dictionary = refs.opts
	if opts.has("refresh"):
		(opts.refresh as Callable).call()
	if is_instance_valid(refs.overlay):
		_refresh_afford(refs.overlay)

# The cash confirm: parchment, pop_in, the honest caption — confirming grants the
# diamonds directly (the future IAP hookup replaces exactly this middle).
static func _confirm_cash(host: Control, refs: Dictionary, i: int) -> void:
	var pack: Dictionary = CASH_PACKS[i]
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.add_child(overlay)
	var veil := ColorRect.new()
	veil.color = Color(INK, 0.5)
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
	col.add_theme_constant_override("separation", 14)
	card.add_child(col)
	# S16: kit-normalized title chip (Look.title_ribbon — same solid chip as the
	# shop header; the ribbon_title nine-patch collapsed invisibly here too).
	var ribbon := Look.title_ribbon(host.tr("Dewdrop pouch"), 32)
	ribbon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(ribbon)
	var what := HBoxContainer.new()
	what.alignment = BoxContainer.ALIGNMENT_CENTER
	what.add_theme_constant_override("separation", 8)
	col.add_child(what)
	what.add_child(Look.icon("gem", 36.0))
	var amount := Label.new()
	amount.text = host.tr("%d for %s") % [int(pack.gems), String(pack.usd)]
	amount.add_theme_font_size_override("font_size", 34)
	amount.add_theme_color_override("font_color", INK)
	amount.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	what.add_child(amount)
	var note := Label.new()
	note.text = host.tr("(test build — nothing is charged)")
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 22)
	note.add_theme_color_override("font_color", BARK)
	col.add_child(note)
	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 16)
	col.add_child(btns)
	btns.add_child(Look.button(host.tr("Cancel"), func() -> void: overlay.queue_free(), false))
	btns.add_child(Look.button(host.tr("Confirm"), func() -> void:
		grant_cash_pack(i)
		var at := card.get_global_rect().get_center()
		overlay.queue_free()
		FX.fly_to_wallet(host, at, Look.icon("gem", 32.0), refs.gem.node)
		_settle(host, refs), true))
	FX.pop_in(card)
