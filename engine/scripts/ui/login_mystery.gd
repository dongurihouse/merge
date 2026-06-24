extends RefCounted
## THE MYSTERY GIFT reveal — the daily calendar's slot-machine dialog for the mystery days (week
## slots 4 & 7, §18). It shows the `show` DISTINCT rewards a roll drew as a row of SLOT REELS: each
## reel scrolls reward symbols and lands (one by one, left→right); the premium rewards SHINE; then
## the player PICKS `win` of them and Claim grants exactly those (Login.claim_mystery).
##
## The roll MATH lives in core/login.gd (pure, tested headless); this is its face. `roll.winners` is
## only the NON-interactive default (the instant/headless grant); the interactive UI passes the
## PLAYER's picks. Pass {instant:true} to skip the spin + pick and grant the default winners (the test
## path). The reel cell + frame are the SHARED workbench kit, so the reveal keeps the parchment look.

const Login = preload("res://engine/scripts/core/login.gd")
const Strings = preload("res://engine/scripts/core/strings.gd")
const FX = preload("res://engine/scripts/ui/fx.gd")
const Audio = preload("res://engine/scripts/core/audio.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const Overlay = preload("res://engine/scripts/ui/overlay.gd")
const Pal = Game.PALETTE
const STRAW := Pal.STRAW

const KIT_PATH := "res://games/grove/tools/ui_workbench_kit.gd"
const OVERLAY_NAME := "LoginMysteryOverlay"
const CELL_ART := "res://games/grove/assets/ui/kit/daily_card.png"

# reel spin pacing (owner feel dial — watch via the workbench "▶ Play spin", §T54). The reels ALL start
# spinning together and STOP one-by-one (left→right): every reel scrolls a band of desynced symbols and reel
# i keeps whirring LONGER (a longer duration → its stop is staggered), so you get "all spin → thunk-thunk-
# thunk". The last reel hangs an extra beat for suspense.
const REEL_SYMS := 10           # tiles per reel band (decoys + the target). Kept modest — make_icon per tile is not free.
const REEL_SPIN := 1.0          # reel 0 spin time (sec)
const REEL_STAGGER := 0.45      # +spin time per reel index (the gap between successive STOPS)
const REEL_ANTICIPATE := 0.5    # the LAST reel hangs a touch longer (suspense before the final prize)
const REEL_BLUR_ALPHA := 0.78   # band opacity while whirring fast (a light motion-blur fake); 1.0 when landed

# --- reward value + premium (drives the SHINE) --------------------------------------

## A single comparable scalar for a reward, premium weighted heaviest, so the top-shine reel is the most
## PREMIUM prize (gems > a comparable coin pile — gems are the rare premium currency in a cozy game).
static func reward_value(reward: Dictionary) -> int:
	return int(reward.get("coins", 0)) + int(reward.get("water", 0)) * 10 + int(reward.get("gems", 0)) * 200

## Whether a reward is PREMIUM (carries gems) — premium reels shine on land.
static func is_premium(reward: Dictionary) -> bool:
	return int(reward.get("gems", 0)) > 0

# --- the reveal popup ---------------------------------------------------------------

## Open the slot reveal for `day` (a mystery day). opts: on_done (Callable, rebuild the calendar),
## instant (bool, skip the spin + pick and grant the default winners — the headless/test path).
static func open(host: Control, day: int, opts: Dictionary = {}) -> void:
	if Overlay.is_open(host, OVERLAY_NAME):
		return
	var Kit: GDScript = load(KIT_PATH)
	if Kit == null:
		return
	var roll: Dictionary = Login.roll_mystery(day)
	var options: Array = roll.get("options", [])
	var winners: Array = roll.get("winners", [])
	var win: int = int(roll.get("win", winners.size()))
	var on_done: Callable = opts.get("on_done", Callable())
	var instant: bool = bool(opts.get("instant", false))

	var overlay := Control.new()
	overlay.name = OVERLAY_NAME
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 110                          # above the z=100 calendar overlay
	host.add_child(overlay)
	var veil := ColorRect.new()
	veil.color = Color(Pal.INK, 0.6)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP  # swallow taps — no early dismiss mid-spin
	overlay.add_child(veil)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(cc)

	var vw: float = (host.get_viewport_rect().size.x if host.is_inside_tree() else 720.0)
	var built: Dictionary = build_reveal(options, winners, reveal_width(vw),
		{"on_close": func() -> void: _dismiss(overlay, on_done)})
	var dialog: Control = built["dialog"]
	var reels: Array = built["reels"]
	var caption: Label = built["caption"]
	var claim: Button = built["claim"]
	cc.add_child(dialog)
	FX.pop_in(dialog)

	if instant:
		_grant_and_finish(overlay, Login.won_rewards(roll), caption, on_done, true)
		return

	# spin the reels (land one by one + shine), then let the player pick `win`, then grant the picks.
	_spin_reels(overlay, reels, dialog, func() -> void:
		enter_pick(reels, win, caption, claim, func(picked: Array) -> void:
			_grant_and_finish(overlay, picked, caption, on_done, false)))

## The reveal dialog's width for a viewport `vw` — capped at 560 on phone, never below 360 (a % of the
## live viewport otherwise). One place so the live dialog and the workbench preview size identically.
static func reveal_width(vw: float) -> float:
	return minf(560.0, maxf(360.0, vw * 0.94))

## Build the reveal FACE — a caption over a centred row of slot REELS, plus a (hidden) Claim button,
## wrapped in the shared dialog frame. Returns {dialog, reels (row order), caption, claim}. The SINGLE
## source for the reveal: open() spins + drives the pick; the workbench renders it static / plays it.
## opts: frame_cfg (the dialog-frame config — defaults to the saved workbench settings); on_close (✕).
static func build_reveal(options: Array, winners: Array, width: float, opts: Dictionary = {}) -> Dictionary:
	var Kit: GDScript = load(KIT_PATH)
	var body := VBoxContainer.new()
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_theme_constant_override("separation", 14)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var caption := Label.new()
	caption.name = "MysteryCaption"
	caption.text = Strings.t("mystery.spinning")
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 18)
	caption.add_theme_color_override("font_color", Pal.INK)
	caption.add_theme_constant_override("outline_size", 0)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(caption)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(row)

	var n: int = maxi(1, options.size())
	var cw: float = clampf((width - 72.0 - (n - 1) * 10.0) / float(n), 64.0, 120.0)
	var ch: float = cw * 1.04                       # room for a two-line (coins + gems) reward
	var top_i: int = _top_value_index(options)
	var reels: Array = []
	for i in options.size():
		var reel: Control = _reel(options, options[i], cw, ch, i)   # i drives the band length + the desync
		reel.set_meta("top", i == top_i)            # the richest reel shines hardest
		reel.set_meta("index", i)
		reels.append(reel)
		row.add_child(reel)

	var claim := _claim_button()
	body.add_child(claim)

	var cfg: Dictionary = opts.get("frame_cfg", Kit.load_config(Kit.CONFIG_PATH))
	var fo: Dictionary = Kit.daily_opts_from_config(cfg)
	fo["banner_text"] = (Strings.t("mystery.banner_plural") if winners.size() > 1 else Strings.t("mystery.banner_single"))
	var on_close: Callable = opts.get("on_close", Callable())
	if on_close.is_valid():
		fo["on_close"] = on_close
	var dialog: Control = Kit.dialog_frame(body, width, fo)
	return {"dialog": dialog, "reels": reels, "caption": caption, "claim": claim}

# The index of the highest-value option (the top-shine reel); -1 if none.
static func _top_value_index(options: Array) -> int:
	var best := -1
	var best_v := -1
	for i in options.size():
		var v := reward_value(options[i])
		if v > best_v:
			best_v = v; best = i
	return best

# --- one slot reel ------------------------------------------------------------------

# A reel: a clipped parchment cell over a vertical BAND of reward tiles ending on `target`. Reel `index`
# carries a LONGER band (so it spins longer at the same speed → stops later) and a DESYNCED symbol order
# (so neighbouring reels never show the same symbol). A built reel is LANDED on its target (the static
# look). A full-rect tap Button (disabled until the pick phase) makes it selectable. Meta: reward,
# selected, band/tile_h/n_syms.
static func _reel(pool: Array, target: Dictionary, cw: float, ch: float, index: int = 0) -> Control:
	var reel := Control.new()
	reel.custom_minimum_size = Vector2(cw, ch)
	reel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	reel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	reel.set_meta("reward", target)
	reel.set_meta("selected", false)

	var bg := PanelContainer.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_theme_stylebox_override("panel", _cell_stylebox())
	reel.add_child(bg)

	# The symbols scroll inside an INSET clipped window, so they slide UNDER the rounded parchment frame
	# (which masks the edge) instead of clipping at a hard square line. No overlay → no edge artifacts.
	var inset: float = 8.0
	var win := Control.new()
	win.name = "ReelWin"
	win.clip_contents = true
	win.mouse_filter = Control.MOUSE_FILTER_IGNORE
	win.set_anchors_preset(Control.PRESET_FULL_RECT)
	win.offset_left = inset; win.offset_top = inset; win.offset_right = -inset; win.offset_bottom = -inset
	reel.add_child(win)
	var win_w: float = cw - inset * 2.0
	var win_h: float = ch - inset * 2.0

	var syms: Array = _reel_symbols(pool, target, REEL_SYMS - 1, index * 3 + 1)
	var band := VBoxContainer.new()
	band.name = "ReelBand"
	band.add_theme_constant_override("separation", 0)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for s in syms:
		band.add_child(_reel_tile(s, win_w, win_h))
	band.custom_minimum_size = Vector2(win_w, win_h * syms.size())
	band.size = Vector2(win_w, win_h * syms.size())
	band.position = Vector2(0, -win_h * float(syms.size() - 1))   # landed on the last (target) tile
	win.add_child(band)
	reel.set_meta("band", band)
	reel.set_meta("tile_h", win_h)
	reel.set_meta("n_syms", syms.size())

	var tap := Button.new()
	tap.name = "ReelTap"
	tap.flat = true
	tap.focus_mode = Control.FOCUS_NONE
	tap.disabled = true                            # enabled in enter_pick
	tap.set_anchors_preset(Control.PRESET_FULL_RECT)
	reel.add_child(tap)
	reel.set_meta("tap", tap)
	return reel

# The reel's scroll symbols: `count` decoys then the TARGET as the last (landing) tile. The decoys cycle
# the pool from `offset` (per-reel desync + variety), so the whir reads as varied prizes whizzing past.
static func _reel_symbols(pool: Array, target: Dictionary, count: int, offset: int) -> Array:
	var syms: Array = []
	var src: Array = pool if not pool.is_empty() else [target]
	for j in count:
		syms.append(src[(j + offset) % src.size()])
	syms.append(target)
	return syms

# One band tile: the reward as icon(s)+amount, centred in a cw×ch window (no frame — the reel cell is it).
static func _reel_tile(reward: Dictionary, cw: float, ch: float) -> Control:
	var Kit: GDScript = load(KIT_PATH)
	var tile := CenterContainer.new()
	tile.custom_minimum_size = Vector2(cw, ch)
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(_reward_amounts(Kit, reward, cw))
	return tile

# The shared parchment-cell stylebox (the same daily_card look the calendar uses; code fallback if absent).
static func _cell_stylebox() -> StyleBox:
	if ResourceLoader.exists(CELL_ART):
		var st := StyleBoxTexture.new()
		st.texture = load(CELL_ART)
		st.set_texture_margin_all(28.0)
		st.content_margin_left = 8; st.content_margin_right = 8
		st.content_margin_top = 7; st.content_margin_bottom = 7
		return st
	var cf := StyleBoxFlat.new()
	cf.bg_color = Color(Pal.CREAM, 0.9)
	cf.set_corner_radius_all(12); cf.set_border_width_all(1); cf.border_color = Color(Pal.BARK, 0.4)
	cf.content_margin_left = 8; cf.content_margin_right = 8
	cf.content_margin_top = 7; cf.content_margin_bottom = 7
	return cf

# A reveal card: the parchment cell + the reward as icon(s)+AMOUNT (kept for the static card preview/tests).
static func _reveal_card(reward: Dictionary, cw: float, ch: float) -> Control:
	var Kit: GDScript = load(KIT_PATH)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(cw, ch)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.add_theme_stylebox_override("panel", _cell_stylebox())
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(center)
	center.add_child(_reward_amounts(Kit, reward, cw))
	return panel

# The reward as stacked (icon + amount) rows — premium first (gems → coins → water).
static func _reward_amounts(Kit: GDScript, reward: Dictionary, cw: float) -> Control:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_px: float = cw * 0.36
	var font: int = clampi(int(cw * 0.21), 12, 22)
	for pair in [["gems", "gem"], ["coins", "coin"], ["water", "water"]]:
		var amt: int = int(reward.get(pair[0], 0))
		if amt <= 0:
			continue
		var rrow := HBoxContainer.new()
		rrow.alignment = BoxContainer.ALIGNMENT_CENTER
		rrow.add_theme_constant_override("separation", 3)
		rrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ic: Control = Kit.make_icon(pair[1], icon_px)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rrow.add_child(ic)
		var l := Label.new()
		l.text = str(amt)
		l.add_theme_font_size_override("font_size", font)
		l.add_theme_color_override("font_color", Pal.INK)
		l.add_theme_constant_override("outline_size", 0)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rrow.add_child(l)
		box.add_child(rrow)
	if box.get_child_count() == 0:                 # cosmetic / empty fallback — never blank
		box.add_child(Kit.make_icon("star", icon_px))
	return box

# The Claim button (hidden until the pick phase) — the shared cozy green action pill.
static func _claim_button() -> Button:
	var b := Button.new()
	b.name = "MysteryClaim"
	b.visible = false
	b.disabled = true
	b.focus_mode = Control.FOCUS_NONE
	b.text = Strings.t("mystery.claim")
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", Pal.CREAM)
	b.add_theme_color_override("font_disabled_color", Color(Pal.CREAM, 0.7))
	b.custom_minimum_size = Vector2(190, 52)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var sb := StyleBoxFlat.new()
	sb.bg_color = Pal.BTN_PRIMARY
	sb.set_corner_radius_all(16)
	sb.content_margin_left = 22; sb.content_margin_right = 22
	sb.content_margin_top = 10; sb.content_margin_bottom = 10
	var dim := sb.duplicate()
	dim.bg_color = Color(sb.bg_color, 0.45)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_stylebox_override("disabled", dim)
	return b

# --- the spin -----------------------------------------------------------------------

# Spin EVERY reel at once and stop them ONE BY ONE (left→right): all bands start scrolling together; reel i
# carries a longer band + a longer spin time, so it keeps whirring at the same speed and lands later (the
# last reel hangs an extra beat for suspense). While fast the band is a touch faint (a light motion-blur
# fake); it sharpens as it eases to a stop, then `_land_reel` lands it with a bounce + flash + chime + shine.
static func _spin_reels(overlay: Control, reels: Array, dialog: Control, on_all_landed: Callable) -> void:
	var n: int = reels.size()
	if n == 0:
		on_all_landed.call()
		return
	for i in n:
		var reel: Control = reels[i]
		var band: Control = reel.get_meta("band")
		var tile_h: float = float(reel.get_meta("tile_h"))
		var n_syms: int = int(reel.get_meta("n_syms"))
		band.position.y = 0.0                      # pre-roll: top of the band (all reels start here, together)
		band.modulate.a = REEL_BLUR_ALPHA          # a touch faint while it whirs
		var landed_y: float = -tile_h * float(n_syms - 1)
		var dur: float = REEL_SPIN + float(i) * REEL_STAGGER + (REEL_ANTICIPATE if i == n - 1 else 0.0)
		var ri := i
		var t := overlay.create_tween()
		t.tween_property(band, "position:y", landed_y, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(band, "modulate:a", 1.0, dur * 0.4).set_delay(dur * 0.6)   # sharpen as it slows
		t.tween_callback(func() -> void: _land_reel(reels[ri], ri, n, dialog))
		if i == n - 1:
			t.tween_callback(on_all_landed)

# A reel lands: a weighty BOUNCE (squash → overshoot → settle) + a quick flash + an escalating chime (pitch
# climbs reel by reel), and SHINE if premium. The TOP-value reel also kicks a dialog SHAKE — the big "thunk"
# that sells the jackpot. `idx`/`total` pitch the chime; `dialog` (may be null) is the node that shakes.
static func _land_reel(reel: Control, idx: int = 0, total: int = 1, dialog: Control = null) -> void:
	if not is_instance_valid(reel):
		return
	var band: Control = reel.get_meta("band")
	if is_instance_valid(band):
		band.modulate.a = 1.0
	var reward: Dictionary = reel.get_meta("reward")
	var top: bool = bool(reel.get_meta("top", false))
	if is_premium(reward):
		shine(reel, top)
	# the BOUNCE: squash on impact, overshoot, settle (gives the reel weight — the slot "thunk")
	reel.pivot_offset = Vector2(reel.size.x * 0.5, reel.size.y)
	reel.scale = Vector2(1.14, 0.82)
	var t := reel.create_tween()
	t.tween_property(reel, "scale", Vector2(0.96, 1.08), 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(reel, "scale", Vector2.ONE, 0.13).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_flash(reel, top)
	if top and is_instance_valid(dialog):          # the jackpot reel kicks a screen shake
		_shake(dialog, 9.0)
	# the chime climbs in pitch as the reels stop, building toward the last — classic slot escalation
	Audio.play("merge_success", -4.0, 1.04 + float(idx) / float(maxi(1, total)) * 0.5)

# A quick impact flash over a landed reel (gold + bigger for the top prize); fades out fast.
static func _flash(reel: Control, strong: bool = false) -> void:
	var fl := ColorRect.new()
	fl.color = (Color(1, 0.95, 0.7, 0.85) if strong else Color(1, 1, 1, 0.6))
	fl.set_anchors_preset(Control.PRESET_FULL_RECT)
	fl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reel.add_child(fl)
	if not reel.is_inside_tree():
		fl.queue_free()
		return
	var t := fl.create_tween()
	t.tween_property(fl, "modulate:a", 0.0, 0.26 if strong else 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_callback(fl.queue_free)

# A short decaying positional shake (the jackpot "thunk"). `amp` px; settles back to the rest position.
static func _shake(node: Control, amp: float) -> void:
	if not node.is_inside_tree():
		return
	var rest := node.position
	var t := node.create_tween()
	var offs := [Vector2(amp, -amp * 0.5), Vector2(-amp * 0.8, amp * 0.4), Vector2(amp * 0.5, amp * 0.3), Vector2(-amp * 0.3, -amp * 0.2)]
	for o in offs:
		t.tween_property(node, "position", rest + o, 0.045).set_trans(Tween.TRANS_SINE)
	t.tween_property(node, "position", rest, 0.05).set_trans(Tween.TRANS_SINE)

# The premium-reward SHINE: just a warm glow BEHIND the band that gently pulses (so the valuable reels
# keep drawing the eye), plus a one-shot sparkle burst on land. Deliberately quiet — no rim or corner
# icon (those read as busy clutter). `strong` (the richest reel) glows a touch warmer + a bigger burst.
static func shine(reel: Control, strong: bool) -> void:
	if reel.has_node("Shine"):
		return
	var hi: float = 0.5 if strong else 0.34
	var glow := ColorRect.new()
	glow.name = "Shine"
	glow.color = Color(STRAW, hi)
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reel.add_child(glow)
	reel.move_child(glow, 1)                        # above the cell bg, below the band — tints, never frames
	if reel.is_inside_tree():                       # a slow breathing pulse so it reads as "shining", not just tinted
		var pt := glow.create_tween().set_loops()
		pt.tween_property(glow, "color:a", hi * 0.5, 0.8).set_trans(Tween.TRANS_SINE)
		pt.tween_property(glow, "color:a", hi, 0.8).set_trans(Tween.TRANS_SINE)
	FX.burst(reel, reel.size * 0.5, STRAW, 18 if strong else 11)

## The "all reels landed" look WITHOUT animation (the workbench revealed/pick states) — shine the premium
## reels (build_reveal already lands every band on its target). Lets the workbench preview the end-of-spin.
static func reveal_static(reels: Array) -> void:
	for reel in reels:
		if is_premium((reel as Control).get_meta("reward")):
			shine(reel, bool((reel as Control).get_meta("top", false)))

## Re-run the reel spin from the top (the workbench "▶ Play spin"): clear shine + reset each band, then spin.
static func replay_spin(host: Control, reels: Array, on_done: Callable = Callable()) -> void:
	for reel in reels:
		for nm in ["Shine", "ShineRim", "ShineStar"]:
			var sh := (reel as Control).get_node_or_null(nm)
			if sh != null:
				sh.queue_free()
		(reel as Control).scale = Vector2.ONE
		var band: Control = (reel as Control).get_meta("band")
		band.position.y = 0.0
		band.modulate.a = 1.0
	_spin_reels(host, reels, null, on_done if on_done.is_valid() else (func() -> void: pass))

# --- the pick -----------------------------------------------------------------------

## Enter the PICK phase: each reel becomes tappable, the player selects up to `win` (deselect allowed,
## over-cap blocked), the caption shows a live "Pick N · k/N" counter, and Claim — gated until exactly
## `win` are chosen — hands `on_claim` the picked rewards. Drives the player-choice mechanic.
static func enter_pick(reels: Array, win: int, caption: Label, claim: Button, on_claim: Callable) -> void:
	var picked: Array = []                          # selected reel indices, in tap order
	var refresh := func() -> void:
		if is_instance_valid(caption):
			caption.text = "%s   %s" % [Strings.t("mystery.pick") % win, Strings.t("mystery.pick_counter") % [picked.size(), win]]
		if is_instance_valid(claim):
			var ready: bool = picked.size() == win
			claim.disabled = not ready
			claim.text = Strings.t("mystery.claim") if ready else Strings.t("mystery.claim_more") % (win - picked.size())
	if is_instance_valid(claim):
		claim.visible = true
	for i in reels.size():
		var reel: Control = reels[i]
		var tap: Button = reel.get_meta("tap")
		tap.disabled = false
		var idx := i
		tap.pressed.connect(func() -> void:
			if bool(reel.get_meta("selected")):
				reel.set_meta("selected", false)
				picked.erase(idx)
				_set_reel_selected(reel, false)
				refresh.call()
			elif picked.size() < win:               # over-cap is blocked (no-op)
				reel.set_meta("selected", true)
				picked.append(idx)
				_set_reel_selected(reel, true)
				refresh.call())
	if is_instance_valid(claim):
		claim.pressed.connect(func() -> void:
			if picked.size() != win:
				return
			var rewards: Array = []
			for i in picked:
				rewards.append(reels[i].get_meta("reward"))
			on_claim.call(rewards))
	refresh.call()

# A selected reel LIFTS with a check badge; deselect drops both. Visual state mirrors the "selected" meta.
# Tweens when in-tree; applies the end state directly otherwise (the workbench builds the pick state out of tree).
static func _set_reel_selected(reel: Control, sel: bool) -> void:
	reel.pivot_offset = reel.size * 0.5
	var to_y: float = -8.0 if sel else 0.0
	var to_s: Vector2 = Vector2(1.06, 1.06) if sel else Vector2.ONE
	if reel.is_inside_tree():
		var t := reel.create_tween()
		t.tween_property(reel, "position:y", to_y, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(reel, "scale", to_s, 0.12)
	else:
		reel.position.y = to_y
		reel.scale = to_s
	var badge := reel.get_node_or_null("PickCheck")
	if sel and badge == null:
		badge = Label.new()
		badge.name = "PickCheck"
		badge.text = "✓"
		badge.add_theme_font_size_override("font_size", 22)
		badge.add_theme_color_override("font_color", Pal.CREAM)
		var bsb := StyleBoxFlat.new()
		bsb.bg_color = Pal.BTN_PRIMARY
		bsb.set_corner_radius_all(16)
		badge.add_theme_stylebox_override("normal", bsb)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.custom_minimum_size = Vector2(30, 30)
		badge.size = Vector2(30, 30)
		badge.position = Vector2(reel.size.x - 26, -6)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		reel.add_child(badge)
	elif not sel and badge != null:
		badge.queue_free()

# --- finish + grant -----------------------------------------------------------------

# Grant EXACTLY `rewards`, celebrate each, then dismiss (immediately when instant/headless).
static func _grant_and_finish(overlay: Control, rewards: Array, caption: Label, on_done: Callable, instant: bool) -> void:
	if not is_instance_valid(overlay):
		return
	Login.claim_mystery(rewards)
	if is_instance_valid(caption):
		caption.text = Strings.t("mystery.won")
	if instant or not overlay.is_inside_tree():
		_dismiss(overlay, on_done)
		return
	Audio.play("merge_success", -2.0, 1.0)
	var at: Vector2 = overlay.get_viewport_rect().size * 0.5
	var dy: float = -30.0
	for rew in rewards:
		_celebrate(overlay, at + Vector2(0, dy), rew)
		dy += 38.0
	overlay.get_tree().create_timer(1.5).timeout.connect(func() -> void: _dismiss(overlay, on_done))

static func _dismiss(overlay: Control, on_done: Callable) -> void:
	if is_instance_valid(overlay):
		overlay.queue_free()
	if on_done.is_valid():
		on_done.call()

# A won reward's juice — a celebratory shout per granted component (mirrors ui/login.gd).
static func _celebrate(host: Control, at: Vector2, rew: Dictionary) -> void:
	var dy := 0.0
	if int(rew.get("gems", 0)) > 0:
		FX.celebrate_reward(host, at + Vector2(0, dy), "gem", int(rew.gems), Color("#A9C7E8")); dy += 34
	if int(rew.get("coins", 0)) > 0:
		FX.celebrate_reward(host, at + Vector2(0, dy), "coin", int(rew.coins), STRAW); dy += 34
	if int(rew.get("water", 0)) > 0:
		FX.celebrate_reward(host, at + Vector2(0, dy), "water", int(rew.water), Color("#9CCDE8")); dy += 34
