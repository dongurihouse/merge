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

# --- the mock's cell palette (sampled from daily_gifts_1080x1920) ---------------------------------
# The pastel tints are DECORATIVE, not semantic: the mock cycles sage/sky across the plain slots and
# reserves the two meaningful tints — lavender for a mystery day, amber + gold rim for today and the
# week's capstone. SLOT_SAGE lists the weekly slots the mock paints sage; the rest go sky.
const CELL_SAGE := Color("#C9D8B2")
const CELL_SKY := Color("#BCD5E4")
const CELL_MYSTERY := Color("#C3B6D9")
const CELL_TODAY := Color("#F2DCA6")
const CELL_RIM := Color("#E0B451")
const SPARK_TINT := Color("#E6BC5E")
const SPRIG_TINT := Color("#8FA96B")
const SHADOW_TINT := Color("#294654")   # the mock's tinted shadow role (residents.gd's house shadow)
const SLOT_SAGE := [1, 3, 6]

const GAP := 14.0                 # design-space gutter between cells
const CELL_ASPECT := 2.12         # cell height / cell width (the mock's tall portrait tile)
const CELL_ASPECT_BARE := 1.68    # a row with no bottom markers is the mock's SHORTER tile
const BANNER_ASPECT := 1.26       # capstone banner height / cell width

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
		ff.add_theme_font_size_override("font_size", FS.TINY)
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
				d["mystery_icon"] = "shared/icon_gift.png"
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
	var cw: float = (inner - GAP * float(COLS - 1)) / float(COLS)
	var grid := GridContainer.new()
	grid.name = "DailyGrid"
	grid.columns = COLS
	grid.add_theme_constant_override("h_separation", int(GAP))
	grid.add_theme_constant_override("v_separation", int(GAP))
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# the mock gives a row its height from whether it carries bottom markers — a row of claimed/
	# claimable days is the tall tile, a row of bare future days the short one.
	var grid_days: Array = days.slice(0, days.size() - 1)
	for r in int(ceil(float(grid_days.size()) / float(COLS))):
		var row: Array = grid_days.slice(r * COLS, mini((r + 1) * COLS, grid_days.size()))
		var tall := false
		for d in row:
			if String((d as Dictionary).get("state", "")) in ["today", "done"]:
				tall = true
		for d in row:
			grid.add_child(_day_cell(Kit, d, cw, cw * (CELL_ASPECT if tall else CELL_ASPECT_BARE)))
	body.add_child(grid)
	if days.size() > 0:
		body.add_child(_capstone(Kit, days[days.size() - 1], inner, cw * BANNER_ASPECT))

## One day cell (mock): a tinted rounded tile — "DAY N" in ink at the top, the reward art centred with
## its amount under it, and the state marker at the bottom (✓ disc · green CLAIM pill · nothing).
static func _day_cell(Kit: GDScript, d: Dictionary, cw: float, ch_px: float) -> Control:
	var state := String(d.get("state", "future"))
	var mystery := bool(d.get("mystery", false))
	var today := state == "today"
	var panel := PanelContainer.new()
	panel.name = "DailyCell_%02d" % int(d.get("day", 0))
	panel.custom_minimum_size = Vector2(cw, ch_px)
	panel.add_theme_stylebox_override("panel", _cell_box(_cell_tint(d), cw, today))

	# NOTE: no min-size here — the panel's own custom_minimum_size already carries the cell box, and
	# a min-size on the padded content would ADD the stylebox margins on top (cells overflowing the sheet).
	var inner := Control.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(inner)
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", int(cw * 0.03))
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(col)

	col.add_child(_cell_label(Kit, String(d.get("label", "")), cw))

	# the reward block — art + (single-currency) amount — floats in the cell's middle
	var mid := VBoxContainer.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.add_theme_constant_override("separation", int(cw * 0.04))
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art: Control
	if mystery:
		art = _sprite(Kit, String(d.get("mystery_icon", "shared/icon_chest.png")), cw * 0.80)
	else:
		art = _reward_art(Kit, d.get("reward", {}), cw * 0.80)
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mid.add_child(art)
	var amount := _amount_text(d.get("reward", {})) if not mystery else ""
	if amount != "":
		var amt := Label.new()
		amt.name = "DailyAmount"
		amt.text = amount
		amt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		amt.add_theme_font_override("font", Kit.bold_font())
		amt.add_theme_font_size_override("font_size", maxi(10, int(cw * 0.21)))
		amt.add_theme_color_override("font_color", Pal.INK)
		amt.add_theme_constant_override("outline_size", 0)
		amt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mid.add_child(amt)
	col.add_child(mid)

	# the bottom marker: today claims, a done day wears the ✓ disc, a plain future day shows nothing
	var act: Control = null
	if today:
		act = _claim_button(Kit, cw, d.get("on_claim", Callable()))
	elif state == "done":
		act = _sprite(Kit, "shared/icon_check.png", cw * 0.30)
	if act != null:
		var wrap := CenterContainer.new()
		wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wrap.add_child(act)
		col.add_child(wrap)

	# a still-locked mystery day carries the mock's lock glyph over the gift's lower edge
	if mystery and state != "today" and state != "done":
		var lock := _sprite(Kit, "shared/icon_lock.png", cw * 0.40)
		lock.modulate = Pal.BARK   # the mock's slate lock (a full INK multiply crushes the keyhole to a blob)
		inner.add_child(lock)
		var dock := func() -> void:
			if is_instance_valid(lock) and is_instance_valid(inner):
				lock.position = Vector2((inner.size.x - lock.size.x) * 0.5, inner.size.y * 0.55)
		inner.resized.connect(dock)
		lock.resized.connect(dock)
		dock.call_deferred()

	if today:
		_scatter_sparks(inner, cw * 0.11, [Vector2(0.10, 0.09), Vector2(0.90, 0.20),
			Vector2(0.09, 0.62), Vector2(0.92, 0.66)])
	return panel

## The week's LAST slot as the mock's wide capstone banner: a full-width amber plaque with the gold
## rim, "DAY N" at the top, the chest flanked by leaf sprigs, and a sparkle in each corner.
static func _capstone(Kit: GDScript, d: Dictionary, w: float, h: float) -> Control:
	var state := String(d.get("state", "future"))
	var panel := PanelContainer.new()
	panel.name = "DailyCapstone"
	panel.custom_minimum_size = Vector2(w, h)
	var cw := w / float(COLS)
	panel.add_theme_stylebox_override("panel", _cell_box(CELL_TODAY, cw, true))

	var inner := Control.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(inner)
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", int(cw * 0.03))
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(col)
	col.add_child(_cell_label(Kit, String(d.get("label", "")), cw))

	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", int(cw * 0.02))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sprig_l := _sprite(Kit, "kit/bag_leaf_l.png", h * 0.44)
	sprig_l.modulate = SPRIG_TINT
	sprig_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(sprig_l)
	row.add_child(_sprite(Kit, String(d.get("mystery_icon", "shared/icon_chest.png")), h * 0.70))
	var sprig_r := _sprite(Kit, "kit/bag_leaf_r.png", h * 0.44)
	sprig_r.modulate = SPRIG_TINT
	sprig_r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(sprig_r)
	col.add_child(row)

	if state == "today":
		var wrap := CenterContainer.new()
		wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wrap.add_child(_claim_button(Kit, cw, d.get("on_claim", Callable())))
		col.add_child(wrap)
	elif state == "done":
		var wrap2 := CenterContainer.new()
		wrap2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wrap2.add_child(_sprite(Kit, "shared/icon_check.png", cw * 0.30))
		col.add_child(wrap2)

	_scatter_sparks(inner, cw * 0.11, [Vector2(0.045, 0.20), Vector2(0.955, 0.20),
		Vector2(0.045, 0.82), Vector2(0.955, 0.82)])
	return panel

## The cell's rounded tinted face — the mock's soft corners, the house drop shadow, and the gold rim
## the mock reserves for today + the capstone.
static func _cell_box(tint: Color, cw: float, rim: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = tint
	sb.set_corner_radius_all(int(cw * 0.11))
	if rim:
		sb.set_border_width_all(int(maxf(3.0, cw * 0.028)))
		sb.border_color = CELL_RIM
	var pad := cw * 0.07
	sb.content_margin_left = pad; sb.content_margin_right = pad
	sb.content_margin_top = pad; sb.content_margin_bottom = pad
	sb.shadow_color = Color(SHADOW_TINT, 0.19)
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(0, 5)
	return sb

## The mock's decorative cell tint (see SLOT_SAGE): lavender = a mystery day, amber = today or the
## week's capstone, otherwise the sage/sky cycle.
static func _cell_tint(d: Dictionary) -> Color:
	if String(d.get("state", "")) == "today":
		return CELL_TODAY
	if bool(d.get("mystery", false)):
		return CELL_MYSTERY
	return CELL_SAGE if int(d.get("slot", 1)) in SLOT_SAGE else CELL_SKY

## "DAY N" — the mock's ink, bold, all-caps cell heading.
static func _cell_label(Kit: GDScript, text: String, cw: float) -> Label:
	var l := Label.new()
	l.name = "DailyDayLabel"
	l.text = text.to_upper()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", Kit.bold_font())
	l.add_theme_font_size_override("font_size", maxi(9, int(cw * 0.16)))
	l.add_theme_color_override("font_color", Pal.INK)
	l.add_theme_constant_override("outline_size", 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## The day's reward art: one icon per currency the rung pays (the mock's day 6 shows the acorn AND the
## coin side by side), premium first. Two icons share the box so the pair reads at the same weight.
static func _reward_art(Kit: GDScript, reward: Dictionary, px: float) -> Control:
	var ids := _reward_ids(reward)
	if ids.size() <= 1:
		return Kit.make_icon(ids[0] if ids.size() == 1 else "coin", px)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", int(-px * 0.06))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# a pair has to SHARE the cell's width, so each icon takes a bit under half the single-icon box
	for id in ids:
		row.add_child(Kit.make_icon(String(id), px * 0.54))
	return row

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
	sb.shadow_color = Color(SHADOW_TINT, 0.19)
	sb.shadow_size = 8
	sb.shadow_offset = Vector2(0, 4)
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
