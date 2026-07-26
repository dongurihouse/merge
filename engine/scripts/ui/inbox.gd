extends RefCounted
## THE MAILBOX surface — the diegetic LiveOps inbox popup (HUD chrome · §13). A parchment card
## framing a scrollable list of operator messages (gifts / compensation / news): each row is an icon
## + a title + a short body, with a Claim button + a reward chip when the message carries an unclaimed
## gift. Claiming pays the reward (core/inbox.gd), plays a small reward shout, and refreshes in place.
##
## The FACE is now BUILT from the shared MAIL KIT (games/grove/ui_kit.gd) using the
## design config the UI WORKBENCH saves — so the look (banner, card art, badge, fonts, Claim label …)
## is authored ONCE in the workbench and read here, never duplicated. Change a setting in the workbench,
## save, and this dialog updates automatically. Only the BEHAVIOUR (claim / celebrate / mark-read /
## dismiss) and the message→entry mapping live in this file; the list + grant live in core/inbox.gd.

const Inbox = preload("res://engine/scripts/core/inbox.gd")
const Strings = preload("res://engine/scripts/core/strings.gd")
const FX = preload("res://engine/scripts/ui/fx.gd")
const Audio = preload("res://engine/scripts/core/audio.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const Overlay = preload("res://engine/scripts/ui/overlay.gd")
const Pal = Game.PALETTE
const STRAW := Pal.STRAW
const OVERLAY_NAME := "InboxOverlay"

# The kit ships in the game build (export_filter=all_resources); load() at runtime keeps this file from
# hard-depending on a tools script, matching the inbox's own guarded-system idiom.
static var KIT_PATH := Game.kit()

# --- the mailbox popup --------------------------------------------------------------

static func open(host: Control, host_opts: Dictionary = {}) -> void:
	if Overlay.is_open(host, OVERLAY_NAME):
		return
	var Kit: GDScript = load(KIT_PATH)
	if Kit == null:
		push_warning("Inbox: mail kit missing at %s" % KIT_PATH)
		return

	var modal := Overlay.modal(host, OVERLAY_NAME)
	var overlay: Control = modal["overlay"]
	var cc: CenterContainer = modal["center"]
	var dismiss: Callable = modal["dismiss"]

	# opening the mailbox first CLEARS dealt-with mail (claimed gifts / already-read notes) so the capped
	# box frees room, then marks the rest read (the badge then rests on unclaimed gifts only).
	Inbox.prune()
	Inbox.mark_all_read()

	var cfg: Dictionary = Kit.load_config(Kit.CONFIG_PATH)
	# the mail dialog renders at the SINGLE global frame width; content scales from the authored
	# baseline (Kit.DIALOG_DESIGN_PCT) to that width (responsive across phone sizes).
	var vw: float = host.get_viewport_rect().size.x
	var width: float = vw * Kit.DIALOG_DESIGN_PCT["dialog"] / 100.0

	# (re)build the whole kit dialog from the live message list. Held in a dict so a claim's callback can
	# call back into it (GDScript lambdas capture by value — a dict lets the closure see the live fn).
	# fx_host = the z=100 overlay, so a claim's reward celebration renders ABOVE the veil + card (the
	# FX float sits at FLOAT_Z relative to its parent; parented to the overlay it clears the modal —
	# parented to the map host it would draw behind the veil and the claim would look like a no-op).
	var rb := {"fn": Callable(), "first": true, "fx_host": overlay, "host_opts": host_opts}
	rb.fn = func() -> void:
		if not is_instance_valid(cc):
			return
		for c in cc.get_children():
			c.queue_free()
		var opts: Dictionary = Kit.dialog_opts_from_config(cfg)
		opts["content_scale"] = Kit.dialog_content_scale(cfg, "dialog")
		# the mock's TALL sheet: the mail cards are now large (hero icon + reward cards + big Claim), so the
		# list rides a taller cap (~half the screen) — ~3 cards show above the pinned Claim All before it
		# scrolls, instead of the old compact 425px.
		opts["list_max_h"] = maxf(float(opts.get("list_max_h", 0.0)), host.get_viewport_rect().size.y * 0.5)
		# clip the scrolling list UNDER the title band (like the shop) so rows disappear below the title
		# instead of riding up behind it — the "MAIL" line stays a clean header, not a scrim over content.
		opts["clip_below_banner"] = true
		opts["on_close"] = dismiss
		opts["empty_text"] = Strings.t("inbox.empty_text")
		opts["banner_text"] = Strings.t("inbox.banner_text")
		(opts["btn"] as Dictionary)["text"] = host.tr(String((opts["btn"] as Dictionary).get("text", "Claim")))
		# CLAIM ALL — shown only when a gift is still unclaimed; grabs them all, celebrates the aggregate,
		# refreshes the wallet, and rebuilds the list in place (mirrors the per-card claim path).
		if Inbox.has_unclaimed():
			opts["claim_all_text"] = host.tr(Strings.t("inbox.claim_all_text"))
			opts["on_claim_all"] = func() -> void:
				var granted: Dictionary = Inbox.claim_all()
				if not granted.is_empty():
					var fx_host: Control = rb.get("fx_host", host)
					if not is_instance_valid(fx_host):
						fx_host = host
					_celebrate(fx_host, fx_host.get_viewport_rect().size * 0.5, granted)
					var ho: Dictionary = rb.get("host_opts", {})
					if ho.has("refresh"):
						(ho.refresh as Callable).call()
				if rb.fn.is_valid():
					rb.fn.call()
		var dialog: Control = Kit.mail_dialog(_entries(host, rb), width, opts)
		cc.add_child(dialog)
		if rb.first:
			FX.pop_in(dialog)
			rb.first = false
	rb.fn.call()

# Map core/inbox.gd messages → kit entries: localized title/body, the reward dict, claimed state, and
# (for an unclaimed gift) an on_claim that pays out, celebrates, and rebuilds the dialog in place.
static func _entries(host: Control, rb: Dictionary) -> Array:
	var out: Array = []
	for m in Inbox.messages():
		var reward: Dictionary = m.get("reward", {})
		var e := {
			"icon": String(m.get("icon", "star")),
			"title": host.tr(String(m.get("title", ""))),
			"body": host.tr(String(m.get("body", ""))),
			"reward": reward,
			"claimed": bool(m.get("claimed", false)),
			"claimed_text": Strings.t("inbox.claimed_text"),
		}
		if not bool(e.claimed) and _reward_total(reward) > 0:
			var id := String(m.get("id", ""))
			e["on_claim"] = func() -> void:
				var granted: Dictionary = Inbox.claim(id)
				if not granted.is_empty():
					# celebrate on the modal overlay (z=100) so the reward float clears the veil; the
					# map host would bury it behind the modal. Falls back to host if the overlay is gone.
					var fx_host: Control = rb.get("fx_host", host)
					if not is_instance_valid(fx_host):
						fx_host = host
					_celebrate(fx_host, fx_host.get_viewport_rect().size * 0.5, granted)
					# Save has no change signal — the HUD wallet is pull-based — so tell the host to
					# re-read the currency bar (mirrors the login calendar's refresh hook).
					var ho: Dictionary = rb.get("host_opts", {})
					if ho.has("refresh"):
						(ho.refresh as Callable).call()
				if rb.fn.is_valid():
					rb.fn.call()
		out.append(e)
	return out

# Play the claimed gift's juice — a small reward shout per granted component (mirrors the login
# calendar's _celebrate, kept simple).
static func _celebrate(host: Control, at: Vector2, rew: Dictionary) -> void:
	Audio.play("merge_success", -3.0, 1.2)
	var dy := 0.0
	if int(rew.get("gems", 0)) > 0:
		FX.celebrate_reward(host, at + Vector2(0, dy), "gem", int(rew.gems), Color("#A9C7E8")); dy += 34
	if int(rew.get("coins", 0)) > 0:
		FX.celebrate_reward(host, at + Vector2(0, dy), "coin", int(rew.coins), STRAW); dy += 34
	if int(rew.get("water", 0)) > 0:
		FX.celebrate_reward(host, at + Vector2(0, dy), "water", int(rew.water), Color("#9CCDE8")); dy += 34

static func _reward_total(rew: Dictionary) -> int:
	return int(rew.get("coins", 0)) + int(rew.get("gems", 0)) + int(rew.get("water", 0))
