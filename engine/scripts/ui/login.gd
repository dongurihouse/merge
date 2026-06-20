extends RefCounted
## THE DAILY LOGIN CALENDAR surface — the diegetic forgiving-streak popup (Core §18 + §13): a
## parchment card framing a grid of day cards (claimed ✓ · today's claimable rung with a green Claim ·
## future days · a milestone shown as a mystery chest), shown on the day's first open.
##
## The FACE is BUILT from the shared MAIL KIT (games/grove/tools/ui_workbench_kit.gd) — the SAME dialog
## frame the mailbox uses (banner, card, ✕, scroll) plus the kit's day cards — using the design config
## the UI WORKBENCH saves, so the look is authored once in the workbench and never duplicated here. The
## ladder MATH + the claim live in core/login.gd; this is only its face (claim → grant → celebrate →
## rebuild, dismiss, the per-day mapping).

const Login = preload("res://engine/scripts/core/login.gd")
const FX = preload("res://engine/scripts/ui/fx.gd")
const Audio = preload("res://engine/scripts/core/audio.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const Pal = Game.PALETTE
const STRAW := Pal.STRAW

const KIT_PATH := "res://games/grove/tools/ui_workbench_kit.gd"
const CARD_MAX_W := 470.0          # the 3-per-row day grid; clamped to the viewport
const CARD_VW_FRAC := 0.94
const WEEK := 7

# --- the calendar popup -------------------------------------------------------------

static func open(host: Control, opts: Dictionary = {}) -> void:
	var Kit: GDScript = load(KIT_PATH)
	if Kit == null:
		push_warning("Daily: mail kit missing at %s" % KIT_PATH)
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
			_dismiss(overlay, opts))
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(cc)

	var cfg: Dictionary = Kit.load_config(Kit.CONFIG_PATH)
	var vw: float = host.get_viewport_rect().size.x
	var cfg_w: float = float((cfg.get("daily", {}) as Dictionary).get("width", CARD_MAX_W))
	var width: float = minf(cfg_w, vw * CARD_VW_FRAC)

	# (re)build the kit daily dialog from the live ladder; a claim rebuilds it in place. fx_host = the
	# z=100 overlay so a claim's reward celebration renders ABOVE the veil (the map host buries it).
	var rb := {"fn": Callable(), "first": true, "fx_host": overlay}
	rb.fn = func() -> void:
		if not is_instance_valid(cc):
			return
		for c in cc.get_children():
			c.queue_free()
		var fo: Dictionary = Kit.daily_opts_from_config(cfg)
		fo["banner_text"] = host.tr("Daily")
		(fo["btn"] as Dictionary)["text"] = host.tr("Claim")
		fo["on_close"] = func() -> void: _dismiss(overlay, opts)
		var dialog: Control = Kit.daily_dialog(_days(host, rb, opts), width, fo)
		cc.add_child(dialog)
		if rb.first:
			FX.pop_in(dialog)
			rb.first = false
	rb.fn.call()

# Map the forgiving streak → the current 7-day window of kit day cards. today's rung is claimable
# (a green Claim wired to claim_today → grant → celebrate → rebuild); earlier rungs are done (✓); a
# future milestone shows the mystery chest. Days roll by absolute streak so today sits in its real slot.
static func _days(host: Control, rb: Dictionary, opts: Dictionary) -> Array:
	var today := Login.today_day()
	var start := ((today - 1) / WEEK) * WEEK + 1
	var out: Array = []
	for i in WEEK:
		var day := start + i
		var st := "future"
		if day < today:
			st = "done"
		elif day == today:
			# today_day() is streak+1, so the MOMENT today is claimed it advances to point
			# at TOMORROW'S rung. Once claimed, this slot is that next (locked) day — a future
			# card, NOT a second "done" today. (Reading it as "done" marked day+1 as claimed.)
			st = "future" if Login.claimed_today() else "today"
		var d := {
			"day": day,
			"label": host.tr("Day %d") % day,
			"reward": Login.reward_for(day),
			"state": st,
		}
		if Login.is_milestone(day) and st == "future":
			d["mystery"] = true
		if st == "today":
			d["on_claim"] = func() -> void:
				var fx_host: Control = rb.get("fx_host", host) ; var at := fx_host.get_viewport_rect().size * 0.5
				if Login.claim_today():
					_celebrate(fx_host, at, Login.reward_for(day))
				else:
					Audio.play("invalid_soft", -6.0)
				if opts.has("refresh"):
					(opts.refresh as Callable).call()
				if rb.fn.is_valid():
					rb.fn.call()
		out.append(d)
	return out

static func _dismiss(overlay: Control, opts: Dictionary) -> void:
	if is_instance_valid(overlay):
		overlay.queue_free()
	if opts.has("refresh"):
		(opts.refresh as Callable).call()

# Play the collected rung's juice — a celebratory reward shout per granted component.
static func _celebrate(host: Control, at: Vector2, rew: Dictionary) -> void:
	Audio.play("merge_success", -3.0, 1.2)
	var dy := 0.0
	if int(rew.get("gems", 0)) > 0:
		FX.celebrate_reward(host, at + Vector2(0, dy), "gem", int(rew.gems), Color("#A9C7E8")); dy += 34
	if int(rew.get("coins", 0)) > 0:
		FX.celebrate_reward(host, at + Vector2(0, dy), "coin", int(rew.coins), STRAW); dy += 34
	if int(rew.get("water", 0)) > 0:
		FX.celebrate_reward(host, at + Vector2(0, dy), "water", int(rew.water), Color("#9CCDE8")); dy += 34
