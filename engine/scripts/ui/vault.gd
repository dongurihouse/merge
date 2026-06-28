extends RefCounted
## THE PIGGY BANK surface — the diegetic accrual-vault jar (Core §10 + §13). A world
## object, not bare "Store" chrome (§13.1): a card framing a hand-drawn JAR that fills with
## the premium you've earned, the ONE fixed real-money price, and a Claim button. The fill
## grows with play; the price is fixed — so the card literally shows the deal getting better.
## Cracking it releases the banked 💎 and resets the jar.
##
## The FACE is now BUILT from the shared UI KIT (games/grove/tools/ui_workbench_kit.gd) using the
## design config the UI WORKBENCH saves — the SAME author-once / read-in-game pattern as settings.gd,
## inbox.gd and login.gd. The shared dialog FRAME (here dressed in the NEW twig border) wraps the jar
## hero + a gem-balance read + the reused green price CTA; the look (border slice/pad, banner, jar size,
## width) is authored ONCE in the workbench's Vault + Frame items and read here, never duplicated.
##
## The vault MATH lives in core/vault.gd; this is only its face + behaviour. Like the shop's cash packs,
## the crack sits behind an HONEST confirm ("test build — nothing is charged") — the real IAP is external
## and replaces ONLY the middle of `_confirm_crack`; everything else (the grant + reset) is core/vault.gd.
## Layering: ui/ may import core/ + ui/, never scenes/ (merge_spec §15); the kit is loaded by PATH at
## runtime (like inbox.gd) so this file keeps no hard dependency on a tools script.

const Strings = preload("res://engine/scripts/core/strings.gd")
const Vault = preload("res://engine/scripts/core/vault.gd")
const Look = preload("res://engine/scripts/ui/skin.gd")
const FX = preload("res://engine/scripts/ui/fx.gd")
const Audio = preload("res://engine/scripts/core/audio.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const Overlay = preload("res://engine/scripts/ui/overlay.gd")
const Pal = Game.PALETTE
const OVERLAY_NAME := "VaultOverlay"

const INK := Pal.INK
const CREAM := Pal.CREAM
const BARK := Pal.BARK

# the shared UI kit (ships in the build); loaded by PATH at runtime — the settings.gd/inbox.gd idiom.
const KIT_PATH := "res://games/grove/tools/ui_workbench_kit.gd"

# IAP: the crack routes through StoreKit (via core/iap.gd → core/store.gd) when the plugin is in the
# build; without it, the honest non-charging test path. Product id + price live in data/iap_products.json.
const Iap = preload("res://engine/scripts/core/iap.gd")
const PIGGY_KEY := "piggybank"

# --- the storefront jar -------------------------------------------------------------

static func open(host: Control, opts: Dictionary = {}) -> void:
	if Overlay.is_open(host, OVERLAY_NAME):
		return
	var Kit: GDScript = load(KIT_PATH)
	if Kit == null:
		push_warning("Vault: ui kit missing at %s" % KIT_PATH)
		return
	var overlay := Overlay.mount(host, OVERLAY_NAME)
	# the dimmed backdrop, dismissing on tap (the same light modal seam as mail / shop / settings).
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

	var cfg: Dictionary = Kit.load_config(Kit.CONFIG_PATH)
	# the dialog renders at the SINGLE global frame width; content scales from the authored baseline
	# (Kit.DIALOG_DESIGN_PCT) to that width — responsive across phones.
	var vw: float = host.get_viewport_rect().size.x
	var width: float = vw * Kit.DIALOG_DESIGN_PCT["vault"] / 100.0

	# the vault MATH stays in core/vault.gd; the kit face reads it via this state dict (game-state-agnostic,
	# exactly like settings_dialog takes entries). The CTA's on_claim wiggles when not claimable (never
	# blocking, §13), else opens the honest crack confirm.
	var state := {
		"balance": Vault.balance(),
		"cap": Vault.cap(),
		"price": Vault.price_usd(),
		"claimable": Vault.claimable(),
		"claim_min": Vault.claim_min(),
		"on_claim": func() -> void:
			if not Vault.claimable():
				Audio.play("invalid_soft", -6.0)
				return
			_confirm_crack(host, overlay, opts),
	}
	var vopts: Dictionary = Kit.vault_opts_from_config(cfg)
	vopts["content_scale"] = Kit.dialog_content_scale(cfg, "vault")
	vopts["banner_text"] = Strings.t("vault.banner")
	vopts["pitch"] = Strings.t("vault.pitch") % Vault.price_usd()
	vopts["hint_text"] = Strings.t("vault.hint")
	vopts["on_close"] = func() -> void:
		if is_instance_valid(overlay): overlay.queue_free()
	var dialog: Control = Kit.vault_dialog(state, width, vopts)
	cc.add_child(dialog)
	FX.pop_in(dialog)

# The crack confirm — parchment, the honest caption, Confirm pays out (the future IAP
# hookup replaces exactly this middle: today Confirm calls Vault.crack() to grant + reset).
static func _confirm_crack(host: Control, parent_overlay: Control, opts: Dictionary) -> void:
	# the plain body face — the SAME standard font the vault dialog uses (loaded by path, no hard tools dep).
	var Kit: GDScript = load(KIT_PATH)
	var plain: Font = Kit.plain_font() if Kit != null else null
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = Overlay.MODAL_TOP_Z          # the crack confirm sits ABOVE the open vault
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
	var ribbon := Look.title_ribbon(Strings.t("vault.crack.ribbon"), 26)
	ribbon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(ribbon)
	var what := HBoxContainer.new()
	what.alignment = BoxContainer.ALIGNMENT_CENTER
	what.add_theme_constant_override("separation", 8)
	col.add_child(what)
	what.add_child(Look.icon("gem", 40))
	var amount := Label.new()
	amount.text = Strings.t("vault.crack.amount") % [Vault.balance(), Vault.price_usd()]
	if plain != null:
		amount.add_theme_font_override("font", plain)          # plain standard face, not the chunky display font
		amount.add_theme_constant_override("outline_size", 0)
	amount.add_theme_font_size_override("font_size", 28)
	amount.add_theme_color_override("font_color", INK)
	amount.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	what.add_child(amount)
	# A real charge happens ONLY when StoreKit is in the build (the plugin is present); otherwise this
	# stays the honest non-charging test path, and the caption says so. The grant is identical either way.
	var charged: bool = Iap.charging()
	var note := Label.new()
	note.text = (Strings.t("vault.crack.charged_note") % Vault.price_usd()) if charged else Strings.t("vault.crack.test_note")
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if plain != null:
		note.add_theme_font_override("font", plain)          # plain standard face, not the chunky display font
		note.add_theme_constant_override("outline_size", 0)
	note.add_theme_font_size_override("font_size", 15)
	note.add_theme_color_override("font_color", BARK)
	col.add_child(note)
	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 12)
	col.add_child(btns)
	btns.add_child(Look.button(Strings.t("vault.crack.cancel"), func() -> void: overlay.queue_free(), false))
	btns.add_child(Look.button(Strings.t("vault.crack.confirm"), func() -> void:
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
			Iap.buy(PIGGY_KEY, func(okay: bool) -> void:
				if okay:
					grant.call()
				elif opts.has("refresh"):
					(opts.refresh as Callable).call())
		else:
			grant.call(), true))
	FX.pop_in(card)
