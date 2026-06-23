extends RefCounted
## THE MAILBOX surface — the diegetic LiveOps inbox popup (HUD chrome · §13). A parchment card
## framing a scrollable list of operator messages (gifts / compensation / news): each row is an icon
## + a title + a short body, with a Claim button + a reward chip when the message carries an unclaimed
## gift. Claiming pays the reward (core/inbox.gd), plays a small reward shout, and refreshes in place.
##
## The FACE is now BUILT from the shared MAIL KIT (games/grove/tools/ui_workbench_kit.gd) using the
## design config the UI WORKBENCH saves — so the look (banner, card art, badge, fonts, Claim label …)
## is authored ONCE in the workbench and read here, never duplicated. Change a setting in the workbench,
## save, and this dialog updates automatically. Only the BEHAVIOUR (claim / celebrate / mark-read /
## dismiss) and the message→entry mapping live in this file; the list + grant live in core/inbox.gd.

const Inbox = preload("res://engine/scripts/core/inbox.gd")
const Strings = preload("res://engine/scripts/core/strings.gd")
const FX = preload("res://engine/scripts/ui/fx.gd")
const Audio = preload("res://engine/scripts/core/audio.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const Pal = Game.PALETTE
const STRAW := Pal.STRAW

# The kit ships in the game build (export_filter=all_resources); load() at runtime keeps this file from
# hard-depending on a tools script, matching the inbox's own guarded-system idiom.
const KIT_PATH := "res://games/grove/tools/ui_workbench_kit.gd"
const CARD_WIDTH_PCT := 85.0       # default mail-dialog width as a % of the screen (overridable in config)

# --- the mailbox popup --------------------------------------------------------------

static func open(host: Control, host_opts: Dictionary = {}) -> void:
	var Kit: GDScript = load(KIT_PATH)
	if Kit == null:
		push_warning("Inbox: mail kit missing at %s" % KIT_PATH)
		return

	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 100
	host.add_child(overlay)
	var veil := ColorRect.new()
	veil.color = Color(Pal.INK, 0.55)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(veil)
	veil.gui_input.connect(func(ev: InputEvent) -> void:
		if (ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed):
			overlay.queue_free())
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(cc)

	# opening the mailbox first CLEARS dealt-with mail (claimed gifts / already-read notes) so the capped
	# box frees room, then marks the rest read (the badge then rests on unclaimed gifts only).
	Inbox.prune()
	Inbox.mark_all_read()

	var cfg: Dictionary = Kit.load_config(Kit.CONFIG_PATH)
	# the mail dialog fills a % of the SCREEN width (the workbench saves width_pct), so it's responsive
	# across phone sizes instead of a fixed pixel width.
	var vw: float = host.get_viewport_rect().size.x
	var pct: float = float((cfg.get("dialog", {}) as Dictionary).get("width_pct", CARD_WIDTH_PCT))
	var width: float = vw * clampf(pct, 30.0, 100.0) / 100.0

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
		opts["on_close"] = func() -> void:
			if is_instance_valid(overlay): overlay.queue_free()
		opts["empty_text"] = Strings.t("inbox.empty_text")
		opts["banner_text"] = Strings.t("inbox.banner_text")
		(opts["btn"] as Dictionary)["text"] = host.tr(String((opts["btn"] as Dictionary).get("text", "Claim")))
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
