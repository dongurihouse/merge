extends RefCounted
## THE MYSTERY GIFT reveal — the daily calendar's auto-spin dialog for the mystery days (week
## slots 4 & 7, §18 · T46). It shows the `show` DISTINCT rewards a roll drew, a highlight cursor
## sweeps across them and decelerates to LAND on each of the `win` winners, then grants EXACTLY
## those winners (Login.claim_mystery) and rebuilds the calendar.
##
## The roll + grant MATH lives in core/login.gd (pure, tested headless); this is only its face.
## The card + frame are the SHARED workbench kit, so the reveal inherits the calendar's parchment
## look. Pass {instant:true} to skip the spin and grant immediately (the headless test path).

const Login = preload("res://engine/scripts/core/login.gd")
const FX = preload("res://engine/scripts/ui/fx.gd")
const Audio = preload("res://engine/scripts/core/audio.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const Pal = Game.PALETTE
const STRAW := Pal.STRAW

const KIT_PATH := "res://games/grove/tools/ui_workbench_kit.gd"

# --- the reveal popup ---------------------------------------------------------------

## Open the spin reveal for `day` (a mystery day). opts: on_done (Callable, rebuild the calendar),
## instant (bool, skip the spin and grant now — the test path).
static func open(host: Control, day: int, opts: Dictionary = {}) -> void:
	var Kit: GDScript = load(KIT_PATH)
	if Kit == null:
		return
	var roll: Dictionary = Login.roll_mystery(day)
	var options: Array = roll.get("options", [])
	var winners: Array = roll.get("winners", [])
	var on_done: Callable = opts.get("on_done", Callable())
	var instant: bool = bool(opts.get("instant", false))

	var overlay := Control.new()
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

	var cfg: Dictionary = Kit.load_config(Kit.CONFIG_PATH)
	var vw: float = (host.get_viewport_rect().size.x if host.is_inside_tree() else 720.0)
	var width: float = minf(560.0, maxf(360.0, vw * 0.94))

	# body = a caption + a single centred row of the option cards (held by ref so the spin lights them)
	var body := VBoxContainer.new()
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_theme_constant_override("separation", 14)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var caption := Label.new()
	caption.name = "MysteryCaption"
	caption.text = host.tr("Spinning…")
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
	var cards: Array = []
	for i in options.size():
		var card: Control = _reveal_card(options[i], cw, ch)
		cards.append(card)
		row.add_child(card)

	var fo: Dictionary = Kit.daily_opts_from_config(cfg)
	fo["banner_text"] = (host.tr("Mystery Gifts") if winners.size() > 1 else host.tr("Mystery Gift"))
	fo["on_close"] = func() -> void: _dismiss(overlay, on_done)
	var dialog: Control = Kit.dialog_frame(body, width, fo)
	cc.add_child(dialog)
	FX.pop_in(dialog)

	var finish := func() -> void: _finish(overlay, roll, caption, on_done, instant)
	if instant:
		finish.call()
	else:
		_set_highlight(cards, -1, [])
		_spin(overlay, cards, roll, finish)

# --- the option cards ---------------------------------------------------------------

# A reveal card: the parchment cell + the reward shown as icon(s) + AMOUNT. Unlike the calendar's
# icon-only daily card, the reveal shows exactly what each slot is worth (the prizes are concrete).
static func _reveal_card(reward: Dictionary, cw: float, ch: float) -> Control:
	var Kit: GDScript = load(KIT_PATH)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(cw, ch)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bgp := "res://games/grove/assets/ui/kit/daily_card.png"   # the same parchment cell the calendar uses
	if ResourceLoader.exists(bgp):
		var st := StyleBoxTexture.new()
		st.texture = load(bgp)
		st.set_texture_margin_all(28.0)
		st.content_margin_left = 8; st.content_margin_right = 8
		st.content_margin_top = 7; st.content_margin_bottom = 7
		panel.add_theme_stylebox_override("panel", st)
	else:
		var cf := StyleBoxFlat.new()
		cf.bg_color = Color(Pal.CREAM, 0.9)
		cf.set_corner_radius_all(12); cf.set_border_width_all(1); cf.border_color = Color(Pal.BARK, 0.4)
		cf.content_margin_left = 8; cf.content_margin_right = 8
		cf.content_margin_top = 7; cf.content_margin_bottom = 7
		panel.add_theme_stylebox_override("panel", cf)
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

# --- the spin -----------------------------------------------------------------------

# Sweep a highlight cursor across the cards, decelerating, and LAND on each winner in turn (a
# landed winner stays lit). One tween chains every flash + the final land, then calls `finish`.
static func _spin(overlay: Control, cards: Array, roll: Dictionary, finish: Callable) -> void:
	var winners: Array = roll.get("winners", [])
	var n: int = cards.size()
	if n == 0:
		finish.call()
		return
	var tw := overlay.create_tween()
	var locked: Array = []                         # winners already landed — they stay lit
	for wi in winners.size():
		var target: int = int(winners[wi])
		var steps: int = 14 + wi * 5               # later winners spin a touch longer
		for s in steps:
			var idx: int = s % n
			var snap: Array = locked.duplicate()
			var delay: float = lerpf(0.035, 0.17, pow(float(s) / float(maxi(1, steps - 1)), 1.6))
			tw.tween_callback(func() -> void: _set_highlight(cards, idx, snap))
			tw.tween_interval(delay)
		tw.tween_callback(func() -> void: _land(cards, target, locked))
		tw.tween_interval(0.35)
	tw.tween_callback(finish)

# Light card `idx` (and any already-locked winners); dim the rest. Pivot-centred so the scale pops.
static func _set_highlight(cards: Array, idx: int, locked: Array) -> void:
	for i in cards.size():
		var c: Control = cards[i]
		if not is_instance_valid(c):
			continue
		c.pivot_offset = c.size * 0.5
		var lit: bool = (i == idx) or locked.has(i)
		c.modulate = Color(1, 1, 1, 1.0 if lit else 0.4)
		if i == idx:
			c.scale = Vector2(1.1, 1.1)
		elif locked.has(i):
			c.scale = Vector2(1.06, 1.06)
		else:
			c.scale = Vector2.ONE

# The cursor lands: lock the target (stays lit), give it a little pop, play a chime.
static func _land(cards: Array, target: int, locked: Array) -> void:
	if not locked.has(target):
		locked.append(target)
	_set_highlight(cards, target, locked)
	var c: Control = cards[target] if target < cards.size() else null
	if is_instance_valid(c):
		var t := c.create_tween()
		t.tween_property(c, "scale", Vector2(1.18, 1.18), 0.12)
		t.tween_property(c, "scale", Vector2(1.06, 1.06), 0.12)
	Audio.play("merge_success", -3.0, 1.1)

# --- finish + grant -----------------------------------------------------------------

# Grant EXACTLY the rolled winners, celebrate each, then dismiss (immediately when instant/headless).
static func _finish(overlay: Control, roll: Dictionary, caption: Label, on_done: Callable, instant: bool) -> void:
	if not is_instance_valid(overlay):
		return
	Login.claim_mystery(Login.won_rewards(roll))
	if is_instance_valid(caption):
		caption.text = "You won!"
	if instant or not overlay.is_inside_tree():
		_dismiss(overlay, on_done)
		return
	Audio.play("merge_success", -2.0, 1.0)
	var at: Vector2 = overlay.get_viewport_rect().size * 0.5
	var dy: float = -30.0
	var options: Array = roll.get("options", [])
	for w in roll.get("winners", []):
		_celebrate(overlay, at + Vector2(0, dy), options[int(w)])
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
