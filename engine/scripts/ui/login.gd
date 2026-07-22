extends RefCounted
## THE DAILY LOGIN CALENDAR surface — the diegetic forgiving-streak popup (Core §18 + §13), built to the
## `daily_gifts_1080x1920` mock: the shared cream sheet framing a 3×2 grid of tall pastel day cells plus a
## WIDE capstone banner for the week's last slot. Claimed days wear the green ✓ disc, today's rung a gold
## rimmed amber cell with a green CLAIM pill, a mystery day a lavender cell with a lock glyph, and plain
## future days a sage/sky cell showing the reward icon + its amount.
##
## The FRAME is the shared kit sheet (games/grove/tools/ui_workbench_kit.gd → Kit.dialog_frame, the same
## one mail/residents use); the CELLS are built here, the way residents.gd builds its own mock-true cards.
## The ladder MATH + the claim live in core/login.gd; this is only its face (claim → grant → celebrate →
## rebuild, dismiss, the per-day mapping).

const Login = preload("res://engine/scripts/core/login.gd")
const LoginMystery = preload("res://engine/scripts/ui/login_mystery.gd")
const Strings = preload("res://engine/scripts/core/strings.gd")
const Features = preload("res://engine/scripts/core/features.gd")
const FX = preload("res://engine/scripts/ui/fx.gd")
const Audio = preload("res://engine/scripts/core/audio.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const Look = preload("res://engine/scripts/ui/skin.gd")
const Overlay = preload("res://engine/scripts/ui/overlay.gd")
const FS = preload("res://engine/scripts/core/tuning.gd").FontScale
const Pal = Game.PALETTE
const STRAW := Pal.STRAW

const KIT_PATH := "res://games/grove/tools/ui_workbench_kit.gd"
const WEEK := 7
const COLS := 3
const OVERLAY_NAME := "LoginOverlay"
const CLAIM_CLOSE_DELAY := 0.85    # after a claim, let the reward shout rise, then the popup bows out on its own

# The four-point sparkle tint scattered over the day-7 capstone.
const SPARK_TINT := Color("#E6BC5E")

const GAP := 24.0                 # design-space gutter between cells — generous margin between the day cards
const CARD_EDGE_INSET := 16.0     # side breathing room so the outer cards' rims/shadows clear the sheet edge
const CELL_ASPECT := 1.25         # cell height / cell width — compact, closer-to-square day cards
const BANNER_ASPECT := 1.35       # capstone banner height / cell width — a small, compact box

# Fixed layout lines for a day cell (fractions of the cell HEIGHT). The reward icon and its amount are
# pinned to these constant lines so they land in the SAME place on every card — claimed, today, or future
# alike — while the state marker (CLAIM · ✓ · nothing) floats at the bottom OUT of the flow so its
# presence never shifts the icon/amount up. (Day 7 is the wide capstone; it lays out on its own.)
const REWARD_ICON_FRAC := 0.49    # the reward icon's vertical CENTRE
const REWARD_AMOUNT_FRAC := 0.80  # the amount label's vertical centre
const REWARD_ACTION_FRAC := 0.88  # the CLAIM pill / ✓ marker's vertical centre
const REWARD_ICON_PX := 0.70      # the reward icon size (fraction of cell width) — uniform across all states
const CLAIMED_CHECK_PX := 0.62    # the claimed check size (fraction of cell width), large and central

# The day-reward art: the cut-paper redesign sprites (Direction B) for the daily surface only — coins as a
# gold acorn-coin stack, water a sky droplet, the premium (gem) as the grove acorn. Other ids (cosmetic
# star) fall back to the shared glyph via Kit.make_icon.
const REWARD_ART := {
	"coin": "kit/daily_reward_coin.png",
	"gem": "kit/daily_reward_acorn.png",
	"water": "kit/daily_reward_water.png",
}
const ART_CHEST := "kit/daily_reward_chest.png"   # day-7 capstone / future milestone
const ART_GIFT := "kit/daily_reward_gift.png"     # slot-4 mystery day (the wrapped box)
const ART_CHECK := "kit/daily_reward_check.png"   # a claimed day's ✓ badge
const ART_LEAF_L := "kit/daily_chest_leaf_l.png"  # day-7 chest decal — cut-paper oak sprig, left
const ART_LEAF_R := "kit/daily_chest_leaf_r.png"  # day-7 chest decal — cut-paper oak sprig, right

# Cut-paper RE-SKIN (from the daily mock): the day-card faces, the wide day-7 capstone (chest + sprigs +
# sparkles baked in), and the reward icons — each worn over the shared code drop shadow. Absent files fall
# back to the drawn/Direction-B look. The CLAIMED card faces bake their own dim + ✓, so a claimed day
# draws no separate reward icon / amount / check.
const SKIN_DIR := "res://games/grove/assets/ui/dialogs/daily/"
const REWARD_SKIN := {"coin": "icon_coin", "gem": "icon_acorn", "water": "icon_water"}   # reward id → skin icon
static func _daily_tex(key: String) -> Texture2D:
	var p := SKIN_DIR + key + ".png"
	return load(p) as Texture2D if ResourceLoader.exists(p) else null
static func _skin_sprite(tex: Texture2D, px: float) -> Control:
	var t := TextureRect.new()
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(px, px)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.texture = tex
	return t

## Every kit sprite THIS dialog polishes on open (_sprite → Kit.clean_tex_path). Sourced here, from
## the same consts the draws use, so the texture bake and its guard cover the REAL runtime dialog —
## not the workbench daily_card mock, which draws a different, older sprite set. Without this, all of
## these get defringe/feather'd live on the main thread on first open (the slow-open hitch).
## Registered in games/tools/bake_targets.gd; held baked by engine/tests/kit_bake_tests.gd.
static func bake_sprites() -> Array:
	var out: Array = [ART_CHEST, ART_GIFT, ART_CHECK, ART_LEAF_L, ART_LEAF_R]
	out.append_array(REWARD_ART.values())
	return out

## A small four-point sparkle, code-drawn (the mock scatters them over today's cell and the capstone
## banner). Code-drawn rather than art so it scales cleanly with the cell.
class Spark:
	extends Control
	var tint: Color = SPARK_TINT
	func _draw() -> void:
		var r: float = size.x * 0.5
		var t: float = r * 0.24
		var c := size * 0.5
		draw_colored_polygon(PackedVector2Array([
			c + Vector2(0, -r), c + Vector2(t, -t), c + Vector2(r, 0), c + Vector2(t, t),
			c + Vector2(0, r), c + Vector2(-t, t), c + Vector2(-r, 0), c + Vector2(-t, -t),
		]), tint)

# --- the calendar popup -------------------------------------------------------------

static func open(host: Control, opts: Dictionary = {}) -> void:
	if Overlay.is_open(host, OVERLAY_NAME):
		return
	var Kit: GDScript = load(KIT_PATH)
	if Kit == null:
		push_warning("Daily: mail kit missing at %s" % KIT_PATH)
		return

	var overlay := Overlay.mount(host, OVERLAY_NAME)
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
	# every dialog renders at the SINGLE global frame width; content scales from this dialog's
	# authored baseline (Kit.DIALOG_DESIGN_PCT) to that width (Kit.dialog_content_scale).
	var width: float = vw * Kit.DIALOG_DESIGN_PCT["daily"] / 100.0
	var scale: float = maxf(0.01, Kit.dialog_content_scale(cfg, "daily"))
	# the CONTENT lays out at the design width MINUS the sheet's insets (the frame scales it by
	# content_scale, so the pads count at 1/scale in layout space) — the residents.gd idiom.
	var inner: float = width - 2.0 * float(Kit.frame_border("parchment")["pad_x"]) / scale

	var body := VBoxContainer.new()
	body.name = "DailyBody"
	body.add_theme_constant_override("separation", int(GAP))
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var fo: Dictionary = Kit.dialog_opts_from_config(cfg)
	fo["content_scale"] = scale
	fo["banner_text"] = Strings.t("login.banner")
	fo["list_max_h"] = host.get_viewport_rect().size.y * 0.84
	fo["on_close"] = func() -> void: _dismiss(overlay, opts)
	var dialog: Control = Kit.dialog_frame(body, width, fo)
	cc.add_child(dialog)

	# (re)build the day grid from the live ladder; a claim rebuilds it in place. fx_host = the
	# z=100 overlay so a claim's reward celebration renders ABOVE the veil (the map host buries it).
	var rb := {"fn": Callable(), "first": true, "fx_host": overlay}
	rb.fn = func() -> void:
		if not is_instance_valid(body):
			return
		_rebuild(Kit, body, inner, _days(host, rb, opts))
		if rb.first:
			FX.pop_in(dialog)
			rb.first = false
	rb.fn.call()

	# DEBUG fast-forward — never in a release build (OS.is_debug_build gate). Jumps to the next day so
	# a tester can keep claiming and hit the mystery days repeatedly. Added to the overlay (not cc) so
	# it survives the rebuild; gated behind the daily_debug flag for an easy off-switch.
	if OS.is_debug_build() and Features.on("daily_debug"):
		var ff := Button.new()
		ff.text = "⏭ Next day (debug)"
		ff.focus_mode = Control.FOCUS_NONE
		ff.add_theme_font_size_override("font_size", FS.FINE)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(Pal.INK, 0.82)
		sb.set_corner_radius_all(14)
		sb.content_margin_left = 16; sb.content_margin_right = 16
		sb.content_margin_top = 8; sb.content_margin_bottom = 8
		ff.add_theme_stylebox_override("normal", sb)
		ff.add_theme_stylebox_override("hover", sb)
		ff.add_theme_stylebox_override("pressed", sb)
		ff.add_theme_color_override("font_color", Pal.CREAM)
		ff.pressed.connect(func() -> void:
			Login.debug_advance_day()
			if rb.fn.is_valid():
				rb.fn.call())
		var ff_wrap := CenterContainer.new()
		ff_wrap.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		ff_wrap.offset_top = -84
		ff_wrap.offset_bottom = -24
		ff_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.add_child(ff_wrap)
		ff_wrap.add_child(ff)

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
			"slot": Login.slot_of(day),
			"label": Strings.t("login.day_label") % day,
			"reward": Login.reward_for(day),
			"state": st,
		}
		# the "?" chest marks a MYSTERY day (slots 4 & 7, any state) or a still-locked future milestone.
		if Login.is_mystery(day):
			d["mystery"] = true
			# slot 4 (day 4 of each week) reads as a wrapped GIFT BOX rather than the shared chest.
			if Login.slot_of(day) == 4:
				d["mystery_icon"] = ART_GIFT
		elif Login.is_milestone(day) and st == "future":
			d["mystery"] = true
		if st == "today":
			if Login.is_mystery(day):
				# a mystery day opens the AUTO-SPIN reveal; claim_mystery grants the winners there.
				d["on_claim"] = func() -> void:
					var fx_host: Control = rb.get("fx_host", host)
					# the reveal grants, celebrates, and waits on its own; once it closes, the
					# calendar bows out too so the player never has to find the ✕.
					var done := func() -> void:
						_dismiss(fx_host, opts)
					LoginMystery.open(fx_host, day, {"on_done": done})
			else:
				d["on_claim"] = func() -> void:
					var fx_host: Control = rb.get("fx_host", host) ; var at := fx_host.get_viewport_rect().size * 0.5
					if Login.claim_today():
						_celebrate(fx_host, at, Login.reward_for(day))
						if rb.fn.is_valid():
							rb.fn.call()                 # flip today's card to ✓ behind the celebration
						_close_after(fx_host, opts, CLAIM_CLOSE_DELAY)
					else:
						Audio.play("invalid_soft", -6.0)
						if opts.has("refresh"):
							(opts.refresh as Callable).call()
						if rb.fn.is_valid():
							rb.fn.call()
		out.append(d)
	return out

# --- the mock's face ----------------------------------------------------------------------------

## Repaint the calendar body: the mock's 3-wide grid of tall day cells, then the week's LAST slot as a
## full-width capstone banner underneath.
static func _rebuild(Kit: GDScript, body: VBoxContainer, inner: float, days: Array) -> void:
	for ch in body.get_children():
		body.remove_child(ch)
		ch.queue_free()
	# Reserve breathing room on both sides so the OUTER cards' gold rims + drop shadows aren't clipped by
	# the sheet's content edge (the grid + capstone lay out at `usable`, centred within the full `inner`).
	var usable: float = maxf(48.0, inner - 2.0 * CARD_EDGE_INSET)
	var cw: float = (usable - GAP * float(COLS - 1)) / float(COLS)
	var grid := GridContainer.new()
	grid.name = "DailyGrid"
	grid.columns = COLS
	grid.add_theme_constant_override("h_separation", int(GAP))
	grid.add_theme_constant_override("v_separation", int(GAP))
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# every one of the six day cards is the SAME (shorter) tile height — a uniform grid, whether or not a
	# row carries a bottom marker (the tall/short-by-row split read as ragged).
	var grid_days: Array = days.slice(0, days.size() - 1)
	var ch_px: float = cw * CELL_ASPECT
	for d in grid_days:
		grid.add_child(_day_cell(Kit, d, cw, ch_px))
	body.add_child(grid)
	if days.size() > 0:
		body.add_child(_capstone(Kit, days[days.size() - 1], usable, cw * BANNER_ASPECT))

## One day cell (mock): a tinted rounded tile — "DAY N" in ink at the top, the reward art centred with
## its amount under it, and the state marker at the bottom (✓ disc · green CLAIM pill · nothing).
static func _day_cell(Kit: GDScript, d: Dictionary, cw: float, ch_px: float) -> Control:
	var state := String(d.get("state", "future"))
	var mystery := bool(d.get("mystery", false))
	var today := state == "today"
	var done := state == "done"
	# advent-calendar faces (each baked into its own sprite): FUTURE = the plain card wearing a VARIED
	# wrapped gift (reward hidden); TODAY = the highlighted gold card showing the real reward icon + count,
	# claimed by TAPPING the card (no separate button); PAST = the card with a ✓ baked in.
	var day := int(d.get("day", 0))
	var tone := "today" if today else "cream"

	# The CODE-DRAWN cut-paper face (the shared Kit builder — same face the workbench draws): cream paper for
	# past/future days, the gold-under-cream DOUBLE layer for today. It fills the cell; content sits inside on
	# `inner`. (Replaces the baked day_past/day_today/day_current sprite faces.)
	var panel := Control.new()
	panel.name = "DailyCell_%02d" % day
	panel.custom_minimum_size = Vector2(cw, ch_px)
	var face: Control = Kit.daily_card_face(Vector2(cw, ch_px), tone)
	face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(face)
	if done:
		panel.modulate = Color(1, 1, 1, 0.6)   # a claimed day recedes

	var inner := Control.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pad := cw * 0.10
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = pad; inner.offset_top = pad; inner.offset_right = -pad; inner.offset_bottom = -pad
	panel.add_child(inner)

	# "DAY N" — pinned to the top edge, full-width centred.
	var label := _cell_label(Kit, String(d.get("label", "")), cw)
	label.anchor_left = 0.0; label.anchor_right = 1.0
	label.anchor_top = 0.0; label.anchor_bottom = 0.0
	label.grow_vertical = Control.GROW_DIRECTION_END
	inner.add_child(label)

	if today:
		# TODAY: the real reward icon + amount; the WHOLE cell is the claim — a transparent full-cell tap
		# target (always present so the surface reads as claimable; only a live callable wires the tap).
		_add_reward_face(Kit, inner, d.get("reward", {}), cw, d if mystery else {})
		var tap := Button.new()
		tap.name = "DailyClaimButton"
		tap.flat = true
		tap.focus_mode = Control.FOCUS_NONE
		for st in ["normal", "hover", "pressed", "focus"]:
			tap.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		tap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var on_claim: Callable = d.get("on_claim", Callable())
		if on_claim.is_valid():
			tap.pressed.connect(func() -> void: on_claim.call())
		panel.add_child(tap)
	elif done:
		# PAST: the reward it gave (recedes with the cell) + a ✓ badge floated near the bottom.
		_add_reward_face(Kit, inner, d.get("reward", {}), cw, {})
		var wrap := CenterContainer.new()
		wrap.name = "DailyClaimedCheckHost"
		wrap.anchor_left = 0.0; wrap.anchor_right = 1.0
		wrap.anchor_top = 0.50; wrap.anchor_bottom = 0.50
		wrap.grow_vertical = Control.GROW_DIRECTION_BOTH
		wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var check := _sprite(Kit, ART_CHECK, cw * CLAIMED_CHECK_PX)
		check.name = "DailyClaimedCheck"
		wrap.add_child(check)
		inner.add_child(wrap)
	else:
		# FUTURE: a varied wrapped gift box (reward hidden) on the plain card.
		var gtex := _daily_tex("gift_%d" % (day % 5))
		if gtex != null:
			var gh := CenterContainer.new()
			gh.anchor_left = 0.0; gh.anchor_right = 1.0
			gh.anchor_top = REWARD_ICON_FRAC; gh.anchor_bottom = REWARD_ICON_FRAC
			gh.grow_vertical = Control.GROW_DIRECTION_BOTH
			gh.mouse_filter = Control.MOUSE_FILTER_IGNORE
			gh.add_child(_skin_sprite(gtex, cw * REWARD_ICON_PX))
			inner.add_child(gh)
	return panel

## Lay the reward ICON (centre at REWARD_ICON_FRAC) + its AMOUNT (at REWARD_AMOUNT_FRAC) over `inner`.
## `mystery_src` (non-empty) picks the mystery icon (gift/chest) instead of the reward currencies.
static func _add_reward_face(Kit: GDScript, inner: Control, reward: Dictionary, cw: float, mystery_src: Dictionary) -> void:
	var mystery := not mystery_src.is_empty()
	var art: Control
	if mystery:
		var mkey := "icon_gift" if String(mystery_src.get("mystery_icon", "")) == ART_GIFT else "icon_chest"
		var mt := _daily_tex(mkey)
		art = _skin_sprite(mt, cw * REWARD_ICON_PX) if mt != null else _sprite(Kit, String(mystery_src.get("mystery_icon", ART_CHEST)), cw * REWARD_ICON_PX)
	else:
		art = _reward_art(Kit, reward, cw * REWARD_ICON_PX)
	var ah := CenterContainer.new()
	ah.name = "DailyRewardIconHost"
	ah.anchor_left = 0.0; ah.anchor_right = 1.0
	ah.anchor_top = REWARD_ICON_FRAC; ah.anchor_bottom = REWARD_ICON_FRAC
	ah.grow_vertical = Control.GROW_DIRECTION_BOTH
	ah.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ah.add_child(art)
	inner.add_child(ah)
	var amount := "" if mystery else _amount_text(reward)
	if amount != "":
		var amt := Label.new()
		amt.name = "DailyAmount"
		amt.text = amount
		amt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		amt.anchor_left = 0.0; amt.anchor_right = 1.0
		amt.anchor_top = REWARD_AMOUNT_FRAC; amt.anchor_bottom = REWARD_AMOUNT_FRAC
		amt.grow_vertical = Control.GROW_DIRECTION_BOTH
		amt.add_theme_font_override("font", Kit.bold_font())
		amt.add_theme_font_size_override("font_size", maxi(10, int(cw * 0.21)))
		amt.add_theme_color_override("font_color", Pal.INK)
		amt.add_theme_constant_override("outline_size", 0)
		amt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(amt)

static func _capstone(Kit: GDScript, d: Dictionary, w: float, h: float) -> Control:
	# Day 7 is a single GOLDEN cut-paper card (the code-drawn face), with the standalone chest + oak sprigs +
	# sparkles composed on top — no baked day7.png.
	return _capstone_drawn(Kit, d, w, h)

## The day-7 capstone: the standalone chest + oak sprigs + sparkles composed over the GOLDEN cut-paper face.
static func _capstone_drawn(Kit: GDScript, d: Dictionary, w: float, h: float) -> Control:
	var state := String(d.get("state", "future"))
	var cw := w / float(COLS)
	var panel := Control.new()
	panel.name = "DailyCapstone"
	panel.custom_minimum_size = Vector2(w, h)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# the GOLDEN cut-paper face (shared Kit builder); corner from the CELL width so it matches the day cells.
	var face: Control = Kit.daily_card_face(Vector2(w, h), "gold", {}, {"corner": cw * 0.13})
	face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(face)
	if state == "done":
		panel.modulate = Color(1, 1, 1, 0.6)   # a claimed capstone recedes

	var inner := Control.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(inner)

	var label := _cell_label(Kit, String(d.get("label", "")), cw)
	label.anchor_left = 0.0; label.anchor_right = 1.0
	label.anchor_top = 0.0; label.anchor_bottom = 0.0
	label.offset_top = h * 0.06
	label.grow_vertical = Control.GROW_DIRECTION_END
	inner.add_child(label)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", int(-h * 0.06))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sprig_l := _sprite_cropped(Kit, ART_LEAF_L, h * 0.82)
	sprig_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(sprig_l)
	var chest := _shadowed(Kit, Kit.clean_tex_path(Look.kit(String(d.get("mystery_icon", ART_CHEST))), 256), h * 1.02)
	chest.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(chest)
	var sprig_r := _sprite_cropped(Kit, ART_LEAF_R, h * 0.82)
	sprig_r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(sprig_r)
	var row_center := CenterContainer.new()
	row_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row_center.add_child(row)
	inner.add_child(row_center)

	var mark: Control = null
	if state == "today":
		mark = _claim_button(Kit, cw, d.get("on_claim", Callable()))
	elif state == "done":
		mark = _sprite(Kit, ART_CHECK, cw * 0.34)
	if mark != null:
		var wrap := CenterContainer.new()
		wrap.anchor_left = 0.0; wrap.anchor_right = 1.0
		wrap.anchor_top = 0.86; wrap.anchor_bottom = 0.86
		wrap.grow_vertical = Control.GROW_DIRECTION_BOTH
		wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wrap.add_child(mark)
		inner.add_child(wrap)

	_scatter_sparks(inner, cw * 0.11, [Vector2(0.045, 0.20), Vector2(0.955, 0.20),
		Vector2(0.045, 0.82), Vector2(0.955, 0.82)])
	return panel

## "DAY N" — the ink, PLAIN-weight (not bold), all-caps cell heading, a touch larger. NO drop shadow —
## just a faint "burn-in": the letters sit in a slightly deeper, warmer ink so they read as scorched a
## touch into the parchment rather than printed flat on top of it.
const DAY_LABEL_INK := Color("#1B2C38")   # INK deepened a step — the subtle burn-in tone
static func _cell_label(Kit: GDScript, text: String, cw: float) -> Label:
	var l := Label.new()
	l.name = "DailyDayLabel"
	l.text = text.to_upper()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", Kit.plain_font())
	l.add_theme_font_size_override("font_size", maxi(10, int(cw * 0.185)))
	l.add_theme_color_override("font_color", DAY_LABEL_INK)
	l.add_theme_constant_override("outline_size", 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## The day's reward art: one icon per currency the rung pays (the mock's day 6 shows the acorn AND the
## coin side by side), premium first. Two icons share the box so the pair reads at the same weight.
static func _reward_art(Kit: GDScript, reward: Dictionary, px: float) -> Control:
	var ids := _reward_ids(reward)
	if ids.size() <= 1:
		return _reward_icon(Kit, String(ids[0]) if ids.size() == 1 else "coin", px)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", int(-px * 0.06))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# a pair has to SHARE the cell's width, so each icon takes a bit under half the single-icon box
	for id in ids:
		row.add_child(_reward_icon(Kit, String(id), px * 0.54))
	return row

## One reward icon: the Direction-B cut-paper sprite when this currency has one (REWARD_ART), else the
## shared glyph via Kit.make_icon (a cosmetic star, or any id the pack doesn't cover).
static func _reward_icon(Kit: GDScript, id: String, px: float) -> Control:
	if REWARD_SKIN.has(id):
		var t := _daily_tex(String(REWARD_SKIN[id]))
		if t != null:
			return _shadowed(Kit, t, px)
	if REWARD_ART.has(id):
		return _shadowed(Kit, Kit.clean_tex_path(Look.kit(String(REWARD_ART[id])), 256), px)
	return Kit.daily_icon(id, px, true)

## Bake the shared shape-true drop shadow (via the kit) onto a texture and return it as a centred sprite, so
## a day card's reward icon (and the day-7 chest) sits on its own soft shadow. A missing texture → the plain
## sprite (no shadow).
static func _shadowed(Kit: GDScript, tex: Texture2D, px: float) -> Control:
	if tex == null:
		return _skin_sprite(tex, px)
	var img := tex.get_image()
	if img == null:
		return _skin_sprite(tex, px)
	return _skin_sprite(ImageTexture.create_from_image(Kit.add_drop_shadow(img, {"shadow_alpha": 0.32})), px)

## The currencies a rung pays, premium → coins → water (the mock's reading order).
static func _reward_ids(reward: Dictionary) -> Array:
	var ids: Array = []
	if int(reward.get("gems", 0)) > 0:
		ids.append("gem")
	if int(reward.get("coins", 0)) > 0:
		ids.append("coin")
	if int(reward.get("water", 0)) > 0:
		ids.append("water")
	if ids.is_empty() and String(reward.get("cosmetic", "")) != "":
		ids.append("star")
	return ids

## The big amount under the art — shown only for a SINGLE-currency rung (a multi-currency day would
## need two numbers, and the mock leaves those bare).
static func _amount_text(reward: Dictionary) -> String:
	var ids := _reward_ids(reward)
	if ids.size() != 1:
		return ""
	match String(ids[0]):
		"gem": return str(int(reward.get("gems", 0)))
		"coin": return str(int(reward.get("coins", 0)))
		"water": return str(int(reward.get("water", 0)))
	return ""

## The mock's CLAIM pill — flat action-green, cream all-caps, the house shadow.
static func _claim_button(Kit: GDScript, cw: float, cb: Callable) -> Button:
	var btn := Button.new()
	btn.name = "DailyClaimButton"
	btn.text = Strings.t("login.claim").to_upper()
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_override("font", Kit.bold_font())
	btn.add_theme_font_size_override("font_size", maxi(9, int(cw * 0.155)))
	btn.add_theme_color_override("font_color", Pal.CREAM)
	btn.add_theme_constant_override("outline_size", 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Pal.LEAF
	sb.set_corner_radius_all(int(cw * 0.08))
	sb.content_margin_left = cw * 0.10; sb.content_margin_right = cw * 0.10
	sb.content_margin_top = cw * 0.06; sb.content_margin_bottom = cw * 0.06
	Look.apply_box_shadow(sb)
	for st in ["normal", "hover", "pressed", "focus"]:
		btn.add_theme_stylebox_override(st, sb)
	if cb.is_valid():
		btn.pressed.connect(func() -> void: cb.call())
	return btn

## Scatter the mock's four-point sparkles at `spots` (fractions of the host's box).
static func _scatter_sparks(host: Control, px: float, spots: Array) -> void:
	var marks: Array[Control] = []
	for _s in spots:
		var sp := Spark.new()
		sp.custom_minimum_size = Vector2(px, px)
		sp.size = Vector2(px, px)
		sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		host.add_child(sp)
		marks.append(sp)
	var dock := func() -> void:
		if not is_instance_valid(host):
			return
		for i in marks.size():
			if is_instance_valid(marks[i]):
				var f: Vector2 = spots[i]
				marks[i].position = Vector2(host.size.x * f.x - px * 0.5, host.size.y * f.y - px * 0.5)
	host.resized.connect(dock)
	dock.call_deferred()

## A kit sprite (path relative to the UI art root), centred and mouse-transparent.
static func _sprite(Kit: GDScript, rel: String, px: float) -> Control:
	var t := TextureRect.new()
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(px, px)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.texture = Kit.clean_tex_path(Look.kit(rel), 256)
	return t

## A kit sprite CROPPED to its opaque content (transparent margins trimmed via an AtlasTexture region) and
## sized to `height` at the content's own aspect. Used for the day-7 leaf sprigs: the sprig art is a narrow
## tall shape with wide transparent side margins, so a square control would strand the visible leaf far from
## the chest — cropping lets the control hug its neighbour and controls the real on-screen size directly.
static func _sprite_cropped(Kit: GDScript, rel: String, height: float) -> Control:
	var t := TextureRect.new()
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex: Texture2D = Kit.clean_tex_path(Look.kit(rel), 256)
	var aspect := 1.0
	if tex != null:
		var img := tex.get_image()
		if img != null:
			var used := img.get_used_rect()
			if used.size.x > 0 and used.size.y > 0:
				var at := AtlasTexture.new()
				at.atlas = tex
				at.region = Rect2(used.position, used.size)
				t.texture = at
				aspect = float(used.size.x) / float(used.size.y)
			else:
				t.texture = tex
		else:
			t.texture = tex
	t.custom_minimum_size = Vector2(height * aspect, height)
	return t

static func _dismiss(overlay: Control, opts: Dictionary) -> void:
	if is_instance_valid(overlay):
		overlay.queue_free()
	if opts.has("refresh"):
		(opts.refresh as Callable).call()

# Auto-dismiss after a claim: hold for `delay` so the reward shout rises, then fade the whole
# overlay out (a soft exit, not a hard cut) and refresh. Headless/no-tree falls back to an
# immediate dismiss so logic tests don't hang on a timer.
static func _close_after(overlay: Control, opts: Dictionary, delay: float) -> void:
	var tree := overlay.get_tree() if is_instance_valid(overlay) else null
	if tree == null:
		_dismiss(overlay, opts)
		return
	tree.create_timer(delay).timeout.connect(func() -> void:
		if not is_instance_valid(overlay):
			if opts.has("refresh"):
				(opts.refresh as Callable).call()
			return
		var tw := overlay.create_tween()
		tw.tween_property(overlay, "modulate:a", 0.0, 0.22)
		tw.tween_callback(func() -> void: _dismiss(overlay, opts)))

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
