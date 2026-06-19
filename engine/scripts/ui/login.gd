extends RefCounted
## THE DAILY LOGIN CALENDAR surface — the diegetic forgiving-streak popup (Core §18 +
## §13). A world object, not bare calendar chrome (§13.1): a parchment card framing a
## week-strip of reward cells, today's claimable rung lifted and breathing, the running
## streak, and a Claim button. Shown on the day's first open; pairs with the piggy bank.
##
## The ladder MATH + the claim live in core/login.gd (which reads the forgiving streak
## from Save.daily()); this is only its face. Reuses the Look kit + FX vocabulary like
## the shop. Reward cells are emoji-FREE (§13): every reward is an icon SPRITE beside a
## number Label, never an emoji glyph baked into text.

const Login = preload("res://engine/scripts/core/login.gd")
const Look = preload("res://engine/scripts/ui/skin.gd")
const FX = preload("res://engine/scripts/ui/fx.gd")
const Audio = preload("res://engine/scripts/core/audio.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const Pal = Game.PALETTE

const INK := Pal.INK
const CREAM := Pal.CREAM
const STRAW := Pal.STRAW
const BARK := Pal.BARK
const LEAF := Pal.LEAF

const CARD_MAX_W := 460.0
const CARD_VW_FRAC := 0.92
const WEEK := 7                          # the strip shows the current 7-day week window
const CELL_W := 54.0
const CELL_H := 72.0

# --- the calendar popup -------------------------------------------------------------

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

	var ribbon := Look.title_ribbon(host.tr("Daily visit"), 30)
	ribbon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(ribbon)

	# the streak line — "Day N in a row" (the running, forgiving streak)
	var today := Login.today_day()
	var streak_lbl := Label.new()
	streak_lbl.text = host.tr("Day %d") % today
	streak_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	streak_lbl.add_theme_font_size_override("font_size", 18)
	streak_lbl.add_theme_color_override("font_color", Color(BARK, 0.95))
	col.add_child(streak_lbl)

	# the week strip — the current 7-day window; today's rung is lifted + breathing.
	# The window starts at the week's first day (so today sits in its real weekday slot).
	var start := ((today - 1) / WEEK) * WEEK + 1     # first day of the week `today` is in
	var strip := HBoxContainer.new()
	strip.alignment = BoxContainer.ALIGNMENT_CENTER
	strip.add_theme_constant_override("separation", 6)
	col.add_child(strip)
	var today_cell: Control = null
	for i in WEEK:
		var day := start + i
		var is_today := day == today and not Login.claimed_today()
		var is_done := day < today                # already claimed earlier this run
		var cell := _day_cell(host, day, is_today, is_done)
		strip.add_child(cell)
		if is_today:
			today_cell = cell

	# the Claim CTA — grants today's rung once per day; refused (and explained) if already done.
	var already := Login.claimed_today()
	var cta := Look.button(host.tr("Collect today") if not already else host.tr("Come back tomorrow"),
		func() -> void:
			if not Login.claim_today():
				Audio.play("invalid_soft", -6.0)
				FX.wobble(card)
				FX.floating_text(host, card.get_global_rect().get_center() + Vector2(0, 40),
					host.tr("Already collected — see you tomorrow"), CREAM, 22)
				return
			# pay the rung's juice from the card center, then close + refresh
			var at := card.get_global_rect().get_center()
			_celebrate(host, at, Login.reward_for(today))
			overlay.queue_free()
			if opts.has("refresh"):
				(opts.refresh as Callable).call(),
		not already)
	cta.modulate = Color(1, 1, 1, 1.0) if not already else Color(1, 1, 1, 0.6)
	col.add_child(cta)

	FX.pop_in(card)
	if today_cell != null:
		FX.breathe_once(today_cell)          # the ONE suggested action gently pulses (§12)

# One day cell: a small card with the day number and its reward (icon sprite + number).
# Today's rung gets a leaf-green lift; a milestone day gets a STAR accent; done days dim.
static func _day_cell(host: Control, day: int, is_today: bool, is_done: bool) -> Control:
	var cell := PanelContainer.new()
	cell.custom_minimum_size = Vector2(CELL_W, CELL_H)
	var s := StyleBoxFlat.new()
	if is_today:
		s.bg_color = Color(LEAF, 0.22)
		s.border_color = Color(LEAF, 0.9)
		s.set_border_width_all(3)
	else:
		s.bg_color = Color(CREAM, 0.45)
		s.border_color = Color(BARK, 0.45)
		s.set_border_width_all(1)
	s.set_corner_radius_all(10)
	s.content_margin_left = 4; s.content_margin_right = 4
	s.content_margin_top = 5; s.content_margin_bottom = 5
	cell.add_theme_stylebox_override("panel", s)
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_done:
		cell.modulate = Color(1, 1, 1, 0.5)

	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(v)
	# the day label (a milestone wears a star, drawn as the star icon — no emoji glyph)
	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 1)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dl := Label.new()
	dl.text = str(day)
	dl.add_theme_font_size_override("font_size", 14)
	dl.add_theme_color_override("font_color", INK if not is_today else LEAF.darkened(0.1))
	dl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(dl)
	if Login.is_milestone(day):
		head.add_child(Look.icon("star", 13))
	v.add_child(head)
	# the reward — an icon sprite + a number (the headline reward of the rung)
	v.add_child(_reward_badge(host, Login.reward_for(day)))
	return cell

# A reward's headline as an icon sprite + number (emoji-purge §13). Picks the most
# "premium-feeling" component to show on the small cell: gems > cosmetic > coins > water.
static func _reward_badge(host: Control, rew: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 2)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_id := "coin"
	var n := 0
	if int(rew.get("gems", 0)) > 0:
		icon_id = "gem"; n = int(rew.gems)
	elif String(rew.get("cosmetic", "")) != "":
		icon_id = "star"; n = 0
	elif int(rew.get("coins", 0)) > 0:
		icon_id = "coin"; n = int(rew.coins)
	elif int(rew.get("water", 0)) > 0:
		icon_id = "water"; n = int(rew.water)
	row.add_child(Look.icon(icon_id, 20))
	if n > 0:
		var l := Label.new()
		l.text = str(n)
		l.add_theme_font_size_override("font_size", 13)
		l.add_theme_color_override("font_color", INK)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(l)
	return row

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
