extends RefCounted
## THE PIGGY BANK surface — the diegetic accrual-vault jar (Core §10 + §13). A world
## object, not bare "Store" chrome (§13.1): a parchment card framing a hand-drawn JAR
## that fills with the premium you've earned, the ONE fixed real-money price, and a
## Claim button. The fill grows with play; the price is fixed — so the card literally
## shows the deal getting better. Cracking it releases the banked 💎 and resets the jar.
##
## The vault MATH lives in core/vault.gd; this is only its face. Like the shop's cash
## packs, the crack sits behind an HONEST confirm ("test build — nothing is charged") —
## the real IAP is external and replaces ONLY the middle of `_confirm_crack`; everything
## else (the grant + reset) is core/vault.gd. Self-contained confirm so this never
## reaches into shop.gd. Reuses the Look kit + FX vocabulary exactly like the shop.

const Vault = preload("res://engine/scripts/core/vault.gd")
const Look = preload("res://engine/scripts/ui/skin.gd")
const FX = preload("res://engine/scripts/ui/fx.gd")
const Audio = preload("res://engine/scripts/core/audio.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const Pal = Game.PALETTE

const INK := Pal.INK
const CREAM := Pal.CREAM
const BARK := Pal.BARK
const GOLD := Pal.GOLD

# sizing (kept local — a small surface; mirrors the shop's parchment proportions)
const CARD_MAX_W := 420.0
const CARD_VW_FRAC := 0.86
const JAR_W := 200.0
const JAR_H := 200.0

# IAP: the piggy-bank product. The crack routes through StoreKit (core/store.gd) when the plugin is in
# the build; without it, the honest non-charging test path. Register this id in App Store Connect.
const STORE_PATH := "res://engine/scripts/core/store.gd"
const PIGGY_PRODUCT := "com.tidyup.piggybank"

# --- the storefront jar -------------------------------------------------------------

static func open(host: Control, opts: Dictionary = {}) -> void:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.add_child(overlay)
	var veil := ColorRect.new()
	veil.color = Color(INK, 0.55)
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
	card.custom_minimum_size = Vector2(minf(CARD_MAX_W, vw * CARD_VW_FRAC), 0)
	cc.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(col)

	# title — engine text on a kit ribbon (images never carry words, §13.3)
	var ribbon := Look.title_ribbon(host.tr("Piggy bank"), 30)
	ribbon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(ribbon)

	# the JAR — a code-drawn vessel whose fill scales with balance/cap, with the 💎 count
	# riding on it. (Kit art `vault_jar.png` swaps in when generated; until then this draws.)
	var jar := _make_jar(host, Vault.balance(), Vault.cap())
	jar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(jar)

	# (the banked-amount number chip was the dark stat_chip pill — retired T48 ahead of the UI
	# redesign; the jar above already conveys balance/cap. The explicit number returns in the new
	# chip language during the redesign.)

	# the pitch line — the longer you play, the better the deal
	var pitch := Label.new()
	pitch.text = host.tr("Premium you've earned, saved up — claim it all for %s.") % Vault.price_usd()
	pitch.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pitch.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pitch.custom_minimum_size = Vector2(minf(CARD_MAX_W, vw * CARD_VW_FRAC) - 60.0, 0)
	pitch.add_theme_font_size_override("font_size", 17)
	pitch.add_theme_color_override("font_color", Color(BARK, 0.95))
	col.add_child(pitch)

	# the Claim CTA — claimable only at/above the fill threshold (never blocking, §13):
	# below it, the button dims and reads "keep playing", a press just wiggles + explains.
	var claimable := Vault.claimable()
	var cta := Look.button(host.tr("Claim  %s") % Vault.price_usd(), func() -> void:
		if not Vault.claimable():
			Audio.play("invalid_soft", -6.0)
			FX.wobble(card)
			FX.floating_text(host, card.get_global_rect().get_center() + Vector2(0, 40),
				host.tr("Fill it a little more first"), CREAM, 24)
			return
		_confirm_crack(host, overlay, opts), true)
	cta.modulate = Color(1, 1, 1, 1.0) if claimable else Color(1, 1, 1, 0.55)
	col.add_child(cta)
	if not claimable:
		# emoji-purge (§13): the number sits beside a gem ICON, never an emoji glyph in text
		var hint := HBoxContainer.new()
		hint.alignment = BoxContainer.ALIGNMENT_CENTER
		hint.add_theme_constant_override("separation", 4)
		var hl := Label.new()
		hl.text = host.tr("Keep playing — it fills at")
		hl.add_theme_font_size_override("font_size", 15)
		hl.add_theme_color_override("font_color", Color(BARK, 0.8))
		hl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hint.add_child(hl)
		hint.add_child(Look.icon("gem", 16))
		var hn := Label.new()
		hn.text = str(Vault.claim_min())
		hn.add_theme_font_size_override("font_size", 15)
		hn.add_theme_color_override("font_color", Color(BARK, 0.8))
		hn.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hint.add_child(hn)
		col.add_child(hint)

	FX.pop_in(card)

# Draw the jar: a rounded vessel (BARK rim, CREAM body) with a GOLD fill band rising to
# fill_frac of the height, and a soft glass highlight. A "full" jar fills to the brim.
static func _make_jar(host: Control, balance: int, cap: int) -> Control:
	# kit art when generated — a single sprite carries the whole jar look
	if ResourceLoader.exists(Look.kit("vault_jar.png")):
		var t := TextureRect.new()
		t.texture = load(Look.kit("vault_jar.png"))
		t.custom_minimum_size = Vector2(JAR_W, JAR_H)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return t
	var frac := clampf(float(balance) / float(maxi(1, cap)), 0.0, 1.0)
	var box := Control.new()
	box.custom_minimum_size = Vector2(JAR_W, JAR_H)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# body
	var body := Panel.new()
	body.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(CREAM, 0.65)
	bs.set_corner_radius_all(int(JAR_W * 0.28))
	bs.set_border_width_all(5)
	bs.border_color = BARK
	bs.content_margin_left = 0
	body.add_theme_stylebox_override("panel", bs)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(body)
	# the GOLD fill, rising from the bottom to `frac` of the inner height
	var fill := Panel.new()
	var inset := 8.0
	fill.anchor_left = 0.0; fill.anchor_right = 1.0
	fill.anchor_top = 1.0; fill.anchor_bottom = 1.0
	fill.offset_left = inset; fill.offset_right = -inset; fill.offset_bottom = -inset
	fill.offset_top = -maxf(6.0, (JAR_H - inset * 2.0) * frac)
	var fs := StyleBoxFlat.new()
	fs.bg_color = Color(GOLD, 0.92) if frac > 0.0 else Color(GOLD, 0.0)
	fs.set_corner_radius_all(int(JAR_W * 0.22))
	fs.content_margin_left = 0
	fill.add_theme_stylebox_override("panel", fs)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(fill)
	# a coin slot on the rim (the "piggy bank" read), drawn as a dark notch
	var slot := Panel.new()
	slot.custom_minimum_size = Vector2(JAR_W * 0.30, 8)
	slot.anchor_left = 0.5; slot.anchor_right = 0.5; slot.anchor_top = 0.0
	slot.offset_left = -JAR_W * 0.15; slot.offset_right = JAR_W * 0.15; slot.offset_top = 14
	var ss := StyleBoxFlat.new()
	ss.bg_color = Color(INK, 0.7)
	ss.set_corner_radius_all(4)
	slot.add_theme_stylebox_override("panel", ss)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(slot)
	return box

# The crack confirm — parchment, the honest caption, Confirm pays out (the future IAP
# hookup replaces exactly this middle: today Confirm calls Vault.crack() to grant + reset).
static func _confirm_crack(host: Control, parent_overlay: Control, opts: Dictionary) -> void:
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
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Look.kit_panel("parchment"))
	cc.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(col)
	var ribbon := Look.title_ribbon(host.tr("Crack the piggy bank"), 26)
	ribbon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(ribbon)
	var what := HBoxContainer.new()
	what.alignment = BoxContainer.ALIGNMENT_CENTER
	what.add_theme_constant_override("separation", 8)
	col.add_child(what)
	what.add_child(Look.icon("gem", 40))
	var amount := Label.new()
	amount.text = host.tr("%d for %s") % [Vault.balance(), Vault.price_usd()]
	amount.add_theme_font_size_override("font_size", 28)
	amount.add_theme_color_override("font_color", INK)
	amount.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	what.add_child(amount)
	# A real charge happens ONLY when StoreKit is in the build (the plugin is present); otherwise this
	# stays the honest non-charging test path, and the caption says so. The grant is identical either way.
	var Store: Variant = load(STORE_PATH) if ResourceLoader.exists(STORE_PATH) else null
	var charged: bool = Store != null and Store.available()
	var note := Label.new()
	note.text = (host.tr("You'll be charged %s.") % Vault.price_usd()) if charged else host.tr("(test build — nothing is charged)")
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 15)
	note.add_theme_color_override("font_color", BARK)
	col.add_child(note)
	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 12)
	col.add_child(btns)
	btns.add_child(Look.button(host.tr("Cancel"), func() -> void: overlay.queue_free(), false))
	btns.add_child(Look.button(host.tr("Confirm"), func() -> void:
		var at := card.get_global_rect().get_center()
		# grant the banked 💎 + reset the jar, celebrate, close the vault, refresh — IDENTICAL whether the
		# purchase was real or the test path; only the "did money move?" gate differs.
		var grant := func() -> void:
			var got := Vault.crack()             # core/vault.gd
			Audio.play("merge_success", -3.0, 1.2)
			if got > 0:
				FX.celebrate_reward(host, at, "gem", got, Color("#A9C7E8"))
			if is_instance_valid(parent_overlay):
				parent_overlay.queue_free()
			if opts.has("refresh"):
				(opts.refresh as Callable).call()
		overlay.queue_free()
		if charged:
			# real IAP: StoreKit takes over; grant ONLY on a confirmed purchase, just refresh on cancel.
			Store.purchase(PIGGY_PRODUCT, func(okay: bool) -> void:
				if okay:
					grant.call()
				elif opts.has("refresh"):
					(opts.refresh as Callable).call())
		else:
			grant.call(), true))
	FX.pop_in(card)
