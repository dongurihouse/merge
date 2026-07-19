extends RefCounted
## The LEVEL dialog (mock: _concepts/dialogs/level_1080x1920.png). Two modes, one dialog:
##   LevelPopup.open(host)              — INFO: tap-to-view (HUD level badge / locked cell). "GOT IT",
##                                        veil-dismissable, no reward.
##   LevelPopup.open_levelup(host, n)   — LEVELUP: auto on a level gain. Shows the earned gift; the
##                                        "COLLECT" button GRANTS it (grant_level_gift) then closes.
##                                        NOT veil-dismissable (only Collect closes) so the reward
##                                        can't be lost.
## The SHEET is built here (the residents.gd house pattern — a ui/ file owning its own mock-true
## surface), not by Kit.level_dialog: this mock's frame is a blue RIBBON over a flat cream card with
## NO ✕, which neither the shared dialog_frame nor the old parchment level_frame draws. Shared Kit
## ATOMS are still reused (bold_font, reward_chip, the tinted mock shadow recipe). The model is
## untouched — content.gd/save.gd supply every number, exactly as before.

const Strings = preload("res://engine/scripts/core/strings.gd")
const G = preload("res://engine/scripts/core/content.gd")
const Save = preload("res://engine/scripts/core/save.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const Kit = preload("res://games/grove/tools/ui_workbench_kit.gd")
const FX = preload("res://engine/scripts/ui/fx.gd")
const Overlay = preload("res://engine/scripts/ui/overlay.gd")
const Look = preload("res://engine/scripts/ui/skin.gd")
const FS = preload("res://engine/scripts/core/tuning.gd").FontScale
const Pal = Game.PALETTE
const OVERLAY_NAME = "LevelPopupOverlay"

# --- the mock's roles (Meadow Sky) -------------------------------------------------------
const SHADOW_TINT := Color("#294654")     # the shared tinted shadow role (residents.gd), ~19%
const RIBBON_BAND := Color("#6E9FBE")     # the banner's front face
const BAR_REMAIN := Color("#8FA6C9")      # the progress bar's un-earned remainder (muted periwinkle)

# --- proportions, as fractions of the sheet WIDTH (screen-fraction sizing, not fixed px) ---
const CARD_CORNER_F := 0.049
const PAD_X_F := 0.062
const PAD_TOP_F := 0.225                  # clears the ribbon, which overlaps the card's top edge
const PAD_BOT_F := 0.062
const GAP_F := 0.036
const RIBBON_W_F := 0.880
const RIBBON_H_F := 0.220
const RIBBON_Y_F := 0.055                 # the ribbon's top, below the card's top edge
const MEDALLION_F := 0.620                # the rosette's diameter
const BAR_W_F := 0.880
const BAR_H_F := 0.130
const BTN_W_F := 0.520
const BTN_CORNER_F := 0.030

static func open(host: Control) -> Control:
	return _build(host, "info", 0)

static func open_levelup(host: Control, levels_up: int) -> Control:
	return _build(host, "levelup", maxi(1, levels_up))

static func _build(host: Control, mode: String, levels_up: int) -> Control:
	# Idempotent: keep exactly one popup per host. emulate_touch_from_mouse delivers a tap as BOTH a
	# mouse AND a touch event, so a trigger's gui_input can fire open() twice in one frame — without this
	# guard that stacks two overlays. add_child is synchronous, so the duplicate event finds the first here.
	var live := host.get_node_or_null(NodePath(OVERLAY_NAME))
	if live is Control and not (live as Node).is_queued_for_deletion():
		return live as Control

	var earned := Save.coins_earned_lifetime()   # the COIN clock (organic earnings)
	var lvl := G.level()
	var base := G.coins_at_level(lvl)            # earnings to BE at this level
	var nxt := G.coins_at_level(lvl + 1)         # earnings to reach the next (the bar's bound)
	var into := clampi(earned - base, 0, nxt - base)
	var span := maxi(1, nxt - base)
	var remaining := maxi(0, nxt - earned)

	var overlay := Overlay.mount(host, OVERLAY_NAME)
	var veil := ColorRect.new()
	veil.color = Color(Pal.INK, 0.5)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(veil)
	# INFO dismisses on a veil tap; LEVELUP does NOT (only Collect closes, so the reward can't be lost).
	if mode == "info":
		veil.gui_input.connect(func(ev: InputEvent) -> void:
			if (ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed):
				overlay.queue_free())

	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(cc)

	# every dialog renders at the SINGLE global frame width (the shared frame knob), so the sheet
	# matches its siblings on every phone size.
	var cfg: Dictionary = Kit.load_config(Kit.CONFIG_PATH)
	var vw: float = host.get_viewport_rect().size.x
	var width: float = vw * Kit.frame_width_pct(cfg) / 100.0

	var gift: Dictionary = G.level_gift(levels_up, lvl) if mode == "levelup" else {}   # lvl = new level → milestone acorns
	var on_button := func() -> void:
		if mode == "levelup":
			G.grant_level_gift(gift)        # the deferred grant — Collect pays out the level-up reward
		overlay.queue_free()

	var dialog := _sheet(width, {
		"level": lvl, "earned": earned, "next": nxt, "into": into, "span": span,
		"remaining": remaining, "mode": mode, "gift": gift, "on_button": on_button,
	})
	cc.add_child(dialog)
	FX.pop_in(dialog)
	return overlay

## The whole sheet: the cream card (ribbon docked over its top edge) + medallion + tally + progress
## bar + the "N more to reach Level N+1" hint (info) / reward chip (levelup) + the CTA.
static func _sheet(w: float, d: Dictionary) -> Control:
	var lvl := int(d.get("level", 1))
	var mode := String(d.get("mode", "info"))

	var col := VBoxContainer.new()
	col.name = "LevelColumn"
	col.add_theme_constant_override("separation", int(w * GAP_F))
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var med := _medallion(lvl, w * MEDALLION_F)
	med.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(med)

	col.add_child(_line("LevelTally", "%d / %d earned" % [int(d.get("earned", 0)), int(d.get("next", 0))],
		FS.DISPLAY, Pal.INK))

	var span: int = maxi(1, int(d.get("span", 1)))
	col.add_child(_bar(clampf(float(int(d.get("into", 0))) / float(span), 0.0, 1.0), w))

	if mode == "levelup":
		var gift: Dictionary = d.get("gift", {})
		var reward := {"water": int(gift.get("water", 0)), "gems": int(gift.get("gems", 0))}
		if reward.water > 0 or reward.gems > 0:
			# sized to sit beside the mock's type scale (the default chip is a tiny inline pill)
			var rrow: Control = Kit.reward_chip(reward,
				{"font": FS.HEADING, "icon_size": 46, "corner": 22, "art": true})
			rrow.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			col.add_child(rrow)
	else:
		col.add_child(_line("LevelHint", "%d more to reach Level %d" % [int(d.get("remaining", 0)), lvl + 1],
			FS.HEADING, Pal.INK))

	var btn := _cta("COLLECT" if mode == "levelup" else "GOT IT", w)
	var cb: Callable = d.get("on_button", Callable())
	if cb.is_valid():
		btn.pressed.connect(func() -> void: cb.call())
	var brow := HBoxContainer.new()
	brow.alignment = BoxContainer.ALIGNMENT_CENTER
	brow.add_child(btn)
	col.add_child(brow)

	# the card: ONE flat warm-cream rounded sheet with the mock's shallow tinted shadow (the same
	# surface the shared v2 frame draws) — no parchment nine-patch, no ✕ (the mock has neither).
	var wrap := Control.new()
	wrap.name = "LevelDialog"
	var card := PanelContainer.new()
	card.name = "LevelDialogPanel"
	var sb := StyleBoxFlat.new()
	sb.bg_color = Pal.CREAM
	sb.set_corner_radius_all(int(w * CARD_CORNER_F))
	sb.content_margin_left = w * PAD_X_F; sb.content_margin_right = w * PAD_X_F
	sb.content_margin_top = w * PAD_TOP_F; sb.content_margin_bottom = w * PAD_BOT_F
	_mock_shadow(sb)
	card.add_theme_stylebox_override("panel", sb)
	card.custom_minimum_size = Vector2(w, 0)
	card.add_child(col)
	wrap.custom_minimum_size.x = w
	wrap.add_child(card)

	# the ribbon overlaps the card's top edge, centred (added after the card → drawn over it)
	var ribbon := _ribbon(Strings.t("level.banner") % lvl, w * RIBBON_W_F, w * RIBBON_H_F)
	wrap.add_child(ribbon)
	var dock := func() -> void:
		if is_instance_valid(ribbon) and is_instance_valid(card) and is_instance_valid(wrap):
			ribbon.position = Vector2((card.size.x - ribbon.size.x) * 0.5, w * RIBBON_Y_F)
			wrap.custom_minimum_size = card.size
	card.resized.connect(dock)
	ribbon.resized.connect(dock)
	wrap.ready.connect(dock)
	return wrap

## THE uniform shadow (skin.gd), applied ON the element's own
## StyleBoxFlat so it follows the box's exact rounded corners. The same recipe as residents.gd.
static func _mock_shadow(sb: StyleBoxFlat) -> void:
	Look.apply_box_shadow(sb)

## One centred navy display line (the tally / the hint).
static func _line(nm: String, text: String, font: int, col: Color) -> Label:
	var l := Label.new()
	l.name = nm
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", Kit.bold_font())
	l.add_theme_font_size_override("font_size", font)
	l.add_theme_color_override("font_color", col)
	l.add_theme_constant_override("outline_size", 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## The CTA — a PLAIN action-green pill with cream all-caps text (the mock's button, and the exact
## same atom residents.gd's COLLECT ALL wears).
static func _cta(text: String, w: float) -> Button:
	var btn := Button.new()
	btn.name = "LevelButton"
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(w * BTN_W_F, 0)
	btn.add_theme_font_override("font", Kit.bold_font())
	btn.add_theme_font_size_override("font_size", FS.HEADING)
	btn.add_theme_color_override("font_color", Pal.CREAM)
	btn.add_theme_constant_override("outline_size", 0)
	var gsb := StyleBoxFlat.new()
	gsb.bg_color = Pal.LEAF
	gsb.set_corner_radius_all(int(w * BTN_CORNER_F))
	gsb.content_margin_top = w * 0.030; gsb.content_margin_bottom = w * 0.030
	_mock_shadow(gsb)
	for st in ["normal", "hover", "focus"]:
		btn.add_theme_stylebox_override(st, gsb)
	var psb: StyleBoxFlat = gsb.duplicate()
	psb.bg_color = Pal.LEAF.darkened(0.10)
	btn.add_theme_stylebox_override("pressed", psb)
	return btn

## The progress bar (mock): a cream capsule frame holding a muted-periwinkle remainder track with a
## green earned fill capped round at its head.
static func _bar(frac: float, w: float) -> Control:
	var bw := w * BAR_W_F
	var bh := w * BAR_H_F
	var inset := bh * 0.14
	# a plain Control, NOT a PanelContainer: a container would re-sort (and stretch) the fill/track
	# children over their hand-computed rects, so the fill would always read as 100%.
	var holder := Control.new()
	holder.name = "LevelProgress"
	holder.custom_minimum_size = Vector2(bw, bh)
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var frame := Panel.new()
	frame.name = "LevelProgressFrame"
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fsb := StyleBoxFlat.new()
	fsb.bg_color = Pal.CREAM
	fsb.set_corner_radius_all(int(bh * 0.5))
	fsb.set_border_width_all(2)
	fsb.border_color = Color(SHADOW_TINT, 0.10)
	_mock_shadow(fsb)
	frame.add_theme_stylebox_override("panel", fsb)
	holder.add_child(frame)

	var inner_h := bh - inset * 2.0
	var track := Panel.new()
	track.name = "LevelProgressTrack"
	track.position = Vector2(inset, inset)
	track.size = Vector2(bw - inset * 2.0, inner_h)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tsb := StyleBoxFlat.new()
	tsb.bg_color = BAR_REMAIN
	tsb.set_corner_radius_all(int(inner_h * 0.5))
	track.add_theme_stylebox_override("panel", tsb)
	holder.add_child(track)

	var fill := Panel.new()
	fill.name = "LevelProgressFill"
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lsb := StyleBoxFlat.new()
	lsb.bg_color = Pal.LEAF
	lsb.set_corner_radius_all(int(inner_h * 0.5))
	fill.add_theme_stylebox_override("panel", lsb)
	holder.add_child(fill)

	var f := clampf(frac, 0.0, 1.0)
	var lay := func() -> void:
		if not (is_instance_valid(holder) and is_instance_valid(track) and is_instance_valid(fill)):
			return
		var iw := holder.size.x - inset * 2.0
		var ih := holder.size.y - inset * 2.0
		track.position = Vector2(inset, inset)
		track.size = Vector2(iw, ih)
		fill.position = Vector2(inset, inset)
		fill.size = Vector2(maxf(ih, iw * f), ih)   # ≥ a round nub so 0% still reads as a bar
	holder.resized.connect(lay)
	holder.ready.connect(lay)
	return holder

## The title RIBBON — a blue band on two folded, notched tails, drawn in code (the mock's banner is a
## solid mid-blue ribbon; the shipped title_banner sprite is the cream-faced variant).
class Ribbon:
	extends Control
	const TAIL := Color("#4E7E9E")
	func _draw() -> void:
		var w := size.x
		var h := size.y
		var band_w := w * 0.83
		var bx := (w - band_w) * 0.5
		var top := h * 0.17          # the tails ride below the band's top edge
		var tail_h := h * 0.46
		var slant := h * 0.10        # the outer end hangs a touch lower
		var notch := w * 0.045       # the V cut in each tail's outer end
		for s in [-1.0, 1.0]:
			var inner: float = (bx + band_w * 0.06) if s < 0.0 else (bx + band_w * 0.94)
			var outer: float = 0.0 if s < 0.0 else w
			var nx: float = notch if s < 0.0 else w - notch
			draw_colored_polygon(PackedVector2Array([
				Vector2(inner, top),
				Vector2(outer, top + slant),
				Vector2(nx, top + slant + tail_h * 0.5),
				Vector2(outer, top + slant + tail_h),
				Vector2(inner, top + tail_h),
			]), TAIL)

static func _ribbon(text: String, w: float, h: float) -> Control:
	var r := Ribbon.new()
	r.name = "LevelRibbon"
	r.custom_minimum_size = Vector2(w, h)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var band := Panel.new()
	band.name = "LevelRibbonBand"
	band.position = Vector2(w * 0.085, 0.0)
	band.size = Vector2(w * 0.83, h * 0.64)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = RIBBON_BAND
	bsb.set_corner_radius_all(int(h * 0.10))
	bsb.shadow_color = Look.shadow_color(Look.SHADOW_DEFAULTS.alpha / 100.0)
	bsb.shadow_size = 8
	bsb.shadow_offset = Vector2(0, 4)
	band.add_theme_stylebox_override("panel", bsb)
	r.add_child(band)
	var lbl := _line("LevelRibbonTitle", text.to_upper(), FS.TITLE, Pal.INK)
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	band.add_child(lbl)
	return r

## The mock's MEDALLION: a sage scalloped rosette carrying a cream-ringed sky disc and the level
## numeral, seated in the laurel wreath with a daisy at its foot.
class Rosette:
	extends Control
	const BUMPS := 18
	const SAGE := Color("#A8D3B9")
	const RING := Color("#F6EBDD")
	const DISC := Color("#6FA9C0")
	func _draw() -> void:
		var r := size.x * 0.5
		var c := size * 0.5
		var bump := r * 0.135
		var base := r - bump
		for i in BUMPS:
			var a := TAU * float(i) / float(BUMPS)
			draw_circle(c + Vector2(cos(a), sin(a)) * base, bump, SAGE)
		draw_circle(c, base, SAGE)
		draw_circle(c, r * 0.77, RING)         # the cream ring
		draw_circle(c, r * 0.71, DISC)           # the disc the numeral sits on

static func _medallion(level: int, m: float) -> Control:
	var block := Control.new()
	block.name = "LevelMedallion"
	block.custom_minimum_size = Vector2(m * 1.165, m * 1.06)
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# the laurel sits BEHIND the rosette, its foot flush with the block's bottom
	var wreath_tex: Texture2D = Kit.clean_tex_path(Look.kit("kit/level_wreath.png"), 512)
	if wreath_tex != null:
		var wr := TextureRect.new()
		wr.name = "LevelWreath"
		wr.texture = wreath_tex
		wr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE          # BEFORE size/position (min-size cache)
		wr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var ww := m * 1.165
		var wh := ww * float(wreath_tex.get_height()) / maxf(1.0, float(wreath_tex.get_width()))
		wr.size = Vector2(ww, wh)
		wr.position = Vector2(0.0, block.custom_minimum_size.y - wh)
		wr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		block.add_child(wr)

	var rose := Rosette.new()
	rose.name = "LevelRosette"
	rose.size = Vector2(m, m)
	rose.position = Vector2((block.custom_minimum_size.x - m) * 0.5, 0.0)
	rose.mouse_filter = Control.MOUSE_FILTER_IGNORE
	block.add_child(rose)

	var num := Label.new()
	num.name = "LevelNumber"
	num.text = str(level)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	num.add_theme_font_override("font", Kit.bold_font())
	num.add_theme_font_size_override("font_size", int(m * 0.50))
	num.add_theme_color_override("font_color", Pal.CREAM)
	num.add_theme_constant_override("outline_size", 0)
	num.size = Vector2(m, m)
	num.position = rose.position
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	block.add_child(num)

	var daisy_tex: Texture2D = Kit.clean_tex_path(Look.kit("kit/shop_daisy.png"), 256)
	if daisy_tex != null:
		var dz := TextureRect.new()
		dz.name = "LevelDaisy"
		dz.texture = daisy_tex
		dz.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		dz.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var dp := m * 0.26
		dz.size = Vector2(dp, dp)
		dz.position = Vector2((block.custom_minimum_size.x - dp) * 0.5, block.custom_minimum_size.y - dp)
		dz.mouse_filter = Control.MOUSE_FILTER_IGNORE
		block.add_child(dz)
	return block
