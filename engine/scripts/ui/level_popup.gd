extends RefCounted
## The LEVEL dialog (mock: _concepts/dialogs/level_dialog_meadow_sky_v2.png). Two modes, one dialog:
##   LevelPopup.open(host)              — INFO: tap-to-view (HUD level badge / locked cell). "GOT IT",
##                                        veil-dismissable, no reward.
##   LevelPopup.open_levelup(host, n)   — LEVELUP: auto on a level gain. Shows the earned gift; the
##                                        "COLLECT" button GRANTS it (grant_level_gift) then closes.
##                                        NOT veil-dismissable (only Collect closes) so the reward
##                                        can't be lost.
## The SHEET is built here (the residents.gd house pattern — a ui/ file owning its own mock-true
## surface), not by Kit.level_dialog: this mock is a flat cream card with NO ✕ and an ink title
## INSIDE the card, which neither the shared dialog_frame nor the old parchment level_frame draws.
## The medallion is the baked v2 art set (kit/level_rosette + sprigs + daisy; intake of
## level_dialog_assets_v2). Shared Kit ATOMS are still reused (bold_font, reward_chip, the tinted
## mock shadow recipe). The model is untouched — content.gd/save.gd supply every number, exactly
## as before.

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
const BAR_REMAIN := Color("#8FA6C9")      # the progress bar's un-earned remainder (muted periwinkle)
const PILL_FACE := Color("#FBF4E8")       # the tally pill, a touch lighter than the card cream

# --- proportions, as fractions of the sheet WIDTH (screen-fraction sizing, not fixed px) ---
const CARD_CORNER_F := 0.049
const PAD_X_F := 0.062
const PAD_TOP_F := 0.075                  # the ink title sits INSIDE the card (no ribbon to clear)
const PAD_BOT_F := 0.062
const GAP_F := 0.036
const MEDALLION_F := 0.540                # the rosette's diameter
const SPRIG_F := 0.66                     # each leaf sprig's span, fraction of the rosette diameter
const DAISY_F := 0.27                     # the daisy medallion, fraction of the rosette diameter
const PILL_W_F := 0.720
const PILL_ICON_F := 0.088                # the star token inside the tally pill
const BAR_W_F := 0.880
const BAR_H_F := 0.130
const BTN_W_F := 0.520
const BTN_CORNER_F := 0.030

# --- the v2 medallion art (intake: level_dialog_assets_v2) + the caps it is baked at -------
const ART := {
	"rosette": ["kit/level_rosette.png", 512],
	"sprig_l": ["kit/level_sprig_l.png", 512],
	"sprig_r": ["kit/level_sprig_r.png", 512],
	"daisy":   ["kit/level_daisy.png", 256],
	"token":   ["kit/level_star_token.png", 256],
}

## Every sprite this dialog polishes, with its cap — driven by BakeTargets.build_all so the bake
## covers them and kit_bake_tests holds them baked (no first-open freeze). Same pattern as LoginUI.
static func bake_sprites() -> Array:
	return ART.values()

static func _art(id: String) -> Texture2D:
	var spec: Array = ART[id]
	return Kit.clean_tex_path(Look.kit(String(spec[0])), int(spec[1]))

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

## The whole sheet: the cream card holding the ink title + medallion + the star-token tally pill +
## progress bar + the "N more to reach Level N+1" hint (info) / reward chip (levelup) + the CTA.
static func _sheet(w: float, d: Dictionary) -> Control:
	var lvl := int(d.get("level", 1))
	var mode := String(d.get("mode", "info"))

	var col := VBoxContainer.new()
	col.name = "LevelColumn"
	col.add_theme_constant_override("separation", int(w * GAP_F))
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# the mock's title is large navy ink INSIDE the card, not a ribbon
	col.add_child(_line("LevelTitle", (Strings.t("level.banner") % lvl).to_upper(), FS.TITLE, Pal.INK))

	var med := _medallion(lvl, w * MEDALLION_F)
	med.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(med)

	col.add_child(_tally_pill("%d / %d earned" % [int(d.get("earned", 0)), int(d.get("next", 0))], w))

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
	# surface the shared v2 frame draws) — no parchment nine-patch, no ribbon, no ✕.
	var card := PanelContainer.new()
	card.name = "LevelDialog"
	var sb := StyleBoxFlat.new()
	sb.bg_color = Pal.CREAM
	sb.set_corner_radius_all(int(w * CARD_CORNER_F))
	sb.content_margin_left = w * PAD_X_F; sb.content_margin_right = w * PAD_X_F
	sb.content_margin_top = w * PAD_TOP_F; sb.content_margin_bottom = w * PAD_BOT_F
	_mock_shadow(sb)
	card.add_theme_stylebox_override("panel", sb)
	card.custom_minimum_size = Vector2(w, 0)
	card.add_child(col)
	return card

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
	var corner := w * BTN_CORNER_F
	var gsb := StyleBoxFlat.new()
	gsb.bg_color = Pal.LEAF
	gsb.set_corner_radius_all(int(corner))
	gsb.content_margin_top = w * 0.030; gsb.content_margin_bottom = w * 0.030
	for st in ["normal", "hover", "focus"]:
		btn.add_theme_stylebox_override(st, gsb)
	var psb: StyleBoxFlat = gsb.duplicate()
	psb.bg_color = Pal.LEAF.darkened(0.10)
	btn.add_theme_stylebox_override("pressed", psb)
	# THE shared shadow, the BUTTON way (the pill_button standard): a behind-parent shadow panel at
	# the button's own rounding, from the saved workbench block — a Shadow-item edit restyles it too.
	btn.set_meta(Look.SHADOW_CORNER_META, corner)
	var bsh := Look.shadow_rect(corner, Look.saved_shadow_params())
	bsh.show_behind_parent = true
	btn.add_child(bsh)
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
	# the earned fill casts THE shared shadow onto the track (behind-parent, full-rect of the fill —
	# it follows the fill's live width), from the saved workbench block like every other element
	var fsh := Look.shadow_rect(inner_h * 0.5, Look.saved_shadow_params())
	fsh.show_behind_parent = true
	fill.add_child(fsh)
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

## The tally PILL (mock): a raised light-cream capsule carrying the gold star token and the
## "X / Y earned" line.
static func _tally_pill(text: String, w: float) -> Control:
	var pill := PanelContainer.new()
	pill.name = "LevelTally"
	pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var sb := StyleBoxFlat.new()
	sb.bg_color = PILL_FACE
	sb.set_corner_radius_all(int(w * 0.06))
	sb.content_margin_left = w * 0.055; sb.content_margin_right = w * 0.055
	sb.content_margin_top = w * 0.026; sb.content_margin_bottom = w * 0.026
	_mock_shadow(sb)
	pill.add_theme_stylebox_override("panel", sb)
	pill.custom_minimum_size = Vector2(w * PILL_W_F, 0)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", int(w * 0.028))
	var token := _sprite("LevelTallyToken", "token", w * PILL_ICON_F)
	if token != null:
		row.add_child(token)
	var lbl := _line("LevelTallyText", text, FS.DISPLAY, Pal.INK)
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(lbl)
	pill.add_child(row)
	return pill

## THE uniform shadow, SHAPE-TRUE, for one medallion sprite: the sprite's own alpha silhouette baked
## at display size (the Look.make_level_badge recipe — a box shadow would square the leaves), driven
## by the SAVED workbench shadow block so a Shadow-item edit restyles these too. Returns null when
## the sprite has no readable image (the layout simply omits the shadow).
static func _sprite_shadow(tr: TextureRect) -> TextureRect:
	if tr == null or tr.texture == null:
		return null
	var img: Image = tr.texture.get_image()
	if img == null:
		return null
	var sp := Look.saved_shadow_params()
	img = img.duplicate()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	img.resize(maxi(1, int(tr.size.x)), maxi(1, int(tr.size.y)), Image.INTERPOLATE_BILINEAR)
	var res: Dictionary = Kit.silhouette_shadow(img, {
		"shadow_offset": Vector2(float(sp.offset_x), float(sp.offset_y)),
		"shadow_blur": float(sp.blur), "shadow_alpha": float(sp.alpha),
		"shadow_spread": float(sp.spread)})
	var pad := float(res.pad)
	var shr := TextureRect.new()
	shr.name = String(tr.name) + "Shadow"
	shr.texture = ImageTexture.create_from_image(res.image)
	shr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shr.stretch_mode = TextureRect.STRETCH_SCALE
	shr.position = tr.position - Vector2(pad, pad)
	shr.size = tr.size + Vector2(pad * 2.0, pad * 2.0)
	shr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return shr

## Add `tr` to `block` with its shape-true uniform shadow laid directly beneath it.
static func _add_shadowed(block: Control, tr: TextureRect) -> void:
	if tr == null:
		return
	var sh := _sprite_shadow(tr)
	if sh != null:
		block.add_child(sh)
	block.add_child(tr)

## One polished medallion sprite at `px` wide (height follows the texture's aspect), or null when
## the art is missing (the dialog still builds; the layout simply omits the sprite).
static func _sprite(nm: String, art_id: String, px: float) -> TextureRect:
	var tex: Texture2D = _art(art_id)
	if tex == null:
		return null
	var tr := TextureRect.new()
	tr.name = nm
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE          # BEFORE size/position (min-size cache)
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var h := px * float(tex.get_height()) / maxf(1.0, float(tex.get_width()))
	tr.custom_minimum_size = Vector2(px, h)
	tr.size = Vector2(px, h)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr

## The mock's MEDALLION, assembled from the baked v2 art: the scalloped rosette base carrying the
## runtime level numeral, an oak-leaf sprig flanking each lower side, and the daisy medallion
## seated on the rosette's foot.
static func _medallion(level: int, m: float) -> Control:
	var sprig_w := m * SPRIG_F
	var daisy_px := m * DAISY_F
	# the sprigs tuck IN behind the daisy: each inner edge reaches just past centre, so the block
	# spans two sprig widths minus their overlap; the daisy hangs below the rosette's foot
	var tuck := daisy_px * 0.10           # how far each sprig's inner edge crosses the block centre
	var bw := (sprig_w + tuck) * 2.0
	var bh := m + daisy_px * 0.45
	var block := Control.new()
	block.name = "LevelMedallion"
	block.custom_minimum_size = Vector2(bw, bh)
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# the sprigs sit BEHIND the rosette AND the daisy, raised so their inner stems end right below
	# the daisy — each rests its foot on the block's bottom line, splayed toward the corners
	var sprig_l := _sprite("LevelSprigL", "sprig_l", sprig_w)
	if sprig_l != null:
		sprig_l.position = Vector2(bw * 0.5 + tuck - sprig_w, bh - sprig_l.size.y)
		_add_shadowed(block, sprig_l)
	var sprig_r := _sprite("LevelSprigR", "sprig_r", sprig_w)
	if sprig_r != null:
		sprig_r.position = Vector2(bw * 0.5 - tuck, bh - sprig_r.size.y)
		_add_shadowed(block, sprig_r)

	var rose := _sprite("LevelRosette", "rosette", m)
	if rose != null:
		rose.position = Vector2((bw - m) * 0.5, 0.0)
		_add_shadowed(block, rose)

	var num := Label.new()
	num.name = "LevelNumber"
	num.text = str(level)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	num.add_theme_font_override("font", Kit.bold_font())
	num.add_theme_font_size_override("font_size", int(m * (0.46 if level < 100 else 0.36)))
	num.add_theme_color_override("font_color", Pal.CREAM)
	num.add_theme_constant_override("outline_size", 0)
	num.size = Vector2(m, m)
	num.position = Vector2((bw - m) * 0.5, 0.0)
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	block.add_child(num)

	var daisy := _sprite("LevelDaisy", "daisy", daisy_px)
	if daisy != null:
		daisy.position = Vector2((bw - daisy_px) * 0.5, bh - daisy.size.y)
		_add_shadowed(block, daisy)
	return block
