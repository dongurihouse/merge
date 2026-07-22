extends RefCounted
## The LEVEL dialog (mock: _concepts/dialogs/level_dialog_meadow_sky_v2.png). Two modes, one dialog:
##   LevelPopup.open(host)              — INFO: tap-to-view (HUD level badge / locked cell). "GOT IT",
##                                        veil-dismissable, no reward.
##   LevelPopup.open_levelup(host, n)   — LEVELUP: auto on a level gain. Shows the earned gift; the
##                                        "COLLECT" button GRANTS it (grant_level_gift) then closes.
##                                        NOT veil-dismissable (only the ✕ or Collect closes, and BOTH
##                                        grant first) so the reward can't be lost.
## The sheet is the SHARED frame (Kit.dialog_frame — the same cream card + big navy title band + the ✕
## disc every dialog wears), used UNMODIFIED (the shared close art kit/mail_close is itself the sakura ✕).
## Only the CONTENT is owned here: the medallion (the sakura plaque sprite kit/level_plaque with the
## laurel + daisy baked in, the level numeral drawn on its slate disc), the coin tally pill, the
## nine-slice progress bar, the hint / reward, and the CTA. The ✕ runs the SAME callback as the
## CTA (grant-then-close in levelup), so closing by the disc never loses the reward. The model is
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
const BAR_REMAIN := Color("#8FA6C9")      # the progress bar's un-earned remainder (fallback bar only)

# --- proportions, as fractions of the sheet WIDTH (screen-fraction sizing, not fixed px) ---
# PAD_X_F / PAD_BOT_F are handed to the shared frame as its content inset (so the bar/pill fractions
# below stay valid); the frame owns the card corner + the top title band.
const PAD_X_F := 0.062
const PAD_BOT_F := 0.062
const GAP_F := 0.036
const MEDALLION_F := 0.700                # the sakura plaque's display width (laurel span included)
const PLAQUE_DISC_CX_F := 0.496           # the slate disc's centre within the plaque sprite (measured)
const PLAQUE_DISC_CY_F := 0.409
const PLAQUE_DISC_D_F := 0.610            # the slate disc's diameter, fraction of the plaque width
const PILL_W_F := 0.760
const PILL_TEXT_L_F := 0.220              # the tally text's left inset — clears the pill's baked coin
const BAR_W_F := 0.880
const BAR_H_F := 0.150
const BAR_FILL_RIM_F := 0.10              # the thin blue rim left around the green fill (fraction of bar height)
const BTN_W_F := 0.640                    # the CTA (larger than before)

# --- the sakura cut-paper level art (extracted, shadow-free — runtime re-applies the shadows) + caps -
const ART := {
	"plaque": ["kit/level_plaque.png", 512],   # laurel + slate disc + daisy as ONE sprite (number drawn on top)
	"pill":   ["kit/level_pill.png", 512],      # the tally capsule with the gold coin baked at its left
	"track":  ["kit/level_track.png", 512],     # the empty progress track (nine-slice capsule)
	"fill":   ["kit/level_fill.png", 512],      # the green progress fill (nine-slice, clipped to frac)
}

## Every sprite this dialog polishes, with its cap — driven by BakeTargets.build_all so the bake
## covers them and kit_bake_tests holds them baked (no first-open freeze). Same pattern as LoginUI.
static func bake_sprites() -> Array:
	return ART.values()

## Shape-true shadows are expensive because they resize the sprite to its displayed size and run image
## math over the alpha silhouette. Cache only the shadow TEXTURE/pad; each caller still gets a fresh
## TextureRect node positioned for its sprite, so scene ownership stays simple.
static var _sprite_shadow_cache: Dictionary = {}

static func clear_shadow_cache() -> void:
	_sprite_shadow_cache.clear()

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
		"frame_cfg": cfg,   # the shared frame reads its chrome (card corner, title, shadow) from this
	})
	cc.add_child(dialog)
	FX.pop_in(dialog)
	return overlay

## The whole sheet: the SHARED frame (card + the big navy "LEVEL N" title band + the ✕ disc) wrapping
## the content column — medallion, the star-token tally pill, the progress bar, the "N more to reach
## Level N+1" hint (info) / reward chip (levelup), and the CTA.
static func _sheet(w: float, d: Dictionary) -> Control:
	var lvl := int(d.get("level", 1))
	var mode := String(d.get("mode", "info"))
	var cfg: Dictionary = d.get("frame_cfg", null) if d.get("frame_cfg", null) is Dictionary else Kit.load_config(Kit.CONFIG_PATH)
	# per-element layout — each part's SIZE (a % of its default) and a vertical NUDGE (px, +down), read
	# from the saved "level" config block so the workbench Level item can tune them and the game honours
	# it. Defaults (100 / 0) reproduce the fraction constants exactly, so an un-tuned config is unchanged.
	var lay: Dictionary = cfg.get("level", {})
	var sz := func(key: String) -> float: return float(lay.get(key, 100)) / 100.0
	var dy := func(key: String) -> int: return int(lay.get(key, 0))

	var col := VBoxContainer.new()
	col.name = "LevelColumn"
	col.add_theme_constant_override("separation", int(w * GAP_F))
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var med := _medallion(lvl, w * MEDALLION_F * sz.call("med_size"))
	med.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(_nudge(med, dy.call("med_dy"), "LevelMedallionSlot"))

	col.add_child(_nudge(_tally_pill("%d / %d earned" % [int(d.get("earned", 0)), int(d.get("next", 0))], \
		w * sz.call("earned_size")), dy.call("earned_dy"), "LevelEarnedSlot"))

	var span: int = maxi(1, int(d.get("span", 1)))
	col.add_child(_nudge(_bar(clampf(float(int(d.get("into", 0))) / float(span), 0.0, 1.0), \
		w * sz.call("bar_size"), cfg), dy.call("bar_dy"), "LevelBarSlot"))

	if mode == "levelup":
		var gift: Dictionary = d.get("gift", {})
		var reward := {"water": int(gift.get("water", 0)), "gems": int(gift.get("gems", 0))}
		if reward.water > 0 or reward.gems > 0:
			# sized to sit beside the mock's type scale (the default chip is a tiny inline pill)
			var rrow: Control = Kit.reward_chip(reward,
				{"font": FS.HEADING, "icon_size": 46, "corner": 22, "art": true})
			rrow.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			col.add_child(_nudge(rrow, dy.call("hint_dy"), "LevelHintSlot"))
	else:
		col.add_child(_nudge(_line("LevelHint", "%d more to reach Level %d" % [int(d.get("remaining", 0)), lvl + 1], \
			int(FS.HEADING * sz.call("hint_size")), Pal.INK), dy.call("hint_dy"), "LevelHintSlot"))

	var btn := _cta("COLLECT" if mode == "levelup" else "GOT IT", w)
	var cb: Callable = d.get("on_button", Callable())
	if cb.is_valid():
		btn.pressed.connect(func() -> void: cb.call())
	var brow := HBoxContainer.new()
	brow.alignment = BoxContainer.ALIGNMENT_CENTER
	brow.add_child(btn)
	col.add_child(brow)

	# wrap the content in the SHARED frame — the same cream card + big navy title band + ✕ disc every
	# dialog wears, used unmodified. The ✕ runs the SAME callback as the CTA (grant-then-close in
	# levelup), so closing by the disc never loses the reward. The card hugs its content (min_h 0), and
	# the level's own L/R + bottom insets are kept so the bar/pill width fractions stay valid; the frame
	# reserves the top band for the title.
	var fo: Dictionary = Kit.dialog_opts_from_config(cfg)
	fo["banner_text"] = Strings.t("level.banner") % lvl
	if cb.is_valid():
		fo["on_close"] = cb
	fo["min_h"] = 0.0
	# the level sheet never scrolls — it hugs its content. A large fixed list cap keeps the frame's
	# height math STABLE (the list_max_h == 0 path ties the cap to the live rows size, a moving target
	# that settles on a stale mid-layout height and slices the card short).
	fo["list_max_h"] = 100000.0
	fo["panel_pad_x"] = w * PAD_X_F
	fo["panel_pad_y"] = w * PAD_BOT_F
	return Kit.dialog_frame(col, w, fo)

## Wrap an element in a MarginContainer whose TOP margin nudges it down by `dy` px (the level layout's
## per-element vertical position). dy == 0 returns the element unwrapped, so the default layout is untouched.
static func _nudge(el: Control, dy: int, slot_name: String) -> Control:
	if dy == 0:
		return el
	var m := MarginContainer.new()
	m.name = slot_name
	m.add_theme_constant_override("margin_top", maxi(0, dy))
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(el)
	return m

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

## The CTA — the SHARED workbench primary button (Kit.pill_button, bg "green"): the same green cut-paper
## surface every primary CTA in the game wears, which casts its OWN shape-true shadow. Sized LARGER than
## the mock's default (a bigger font + a wider min-width) so the level sheet's action reads bold.
static func _cta(text: String, w: float) -> Button:
	var btn := Kit.pill_button(text, {"bg": "green", "font": int(FS.HEADING * 1.18)})
	btn.name = "LevelButton"
	btn.custom_minimum_size = Vector2(w * BTN_W_F, 0)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return btn

## The progress bar (sakura): the extracted cut-paper capsule art — an empty slate track (nine-slice)
## with the green fill (nine-slice) clipped to `frac`. The caps are drawn at the texture's NATIVE height
## on an inner stage that is uniformly scaled to the display box, so the rounded ends keep their shape
## instead of ovalling when the bar is squashed short (the same recipe as Kit.progress_bar's art mode).
static func _bar(frac: float, w: float, cfg: Dictionary = {}) -> Control:
	var opts := Kit.progress_bar_opts_from_config(cfg)
	opts["name"] = "LevelProgress"
	opts["width"] = w * BAR_W_F
	opts["height"] = w * BAR_H_F
	opts["track_art"] = "kit/level_track.png"
	opts["fill_art"] = "kit/level_fill.png"
	opts["art_cap"] = 512
	opts["fill_rim_pct"] = BAR_FILL_RIM_F * 100.0
	opts["fill_color"] = Pal.LEAF
	opts["track_color"] = BAR_REMAIN
	if not ((cfg.get("progress_bar", {}) as Dictionary).has("shadow")):
		opts["shadow"] = true
	return Kit.progress_bar(frac, opts)

## The tally PILL (sakura): the extracted cut-paper capsule art (kit/level_pill, gold coin baked at its
## left) carrying the "X / Y earned" line in the space to the right of the coin. The art is shadow-free;
## the runtime silhouette shadow is re-applied by _add_shadowed.
static func _tally_pill(text: String, w: float) -> Control:
	var pw := w * PILL_W_F
	var holder := Control.new()
	holder.name = "LevelTally"
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ph := pw * 0.206                           # provisional; refined from the sprite's true aspect
	var pill := _sprite("LevelTallyPill", "pill", pw)
	if pill != null:
		pill.position = Vector2.ZERO
		_add_shadowed(holder, pill)
		ph = pill.size.y
	holder.custom_minimum_size = Vector2(pw, ph)
	# the text sits in the pill's right region, clearing the baked coin at the left
	var left := pw * PILL_TEXT_L_F
	var lbl := _line("LevelTallyText", text, int(ph * 0.44), Pal.INK)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.position = Vector2(left, 0.0)
	lbl.size = Vector2(pw - left - pw * 0.05, ph)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(lbl)
	return holder

## THE uniform shadow, SHAPE-TRUE, for one medallion sprite: the sprite's own alpha silhouette baked
## at display size (the Look.make_level_badge recipe — a box shadow would square the leaves), driven
## by the SAVED workbench shadow block so a Shadow-item edit restyles these too. Returns null when
## the sprite has no readable image (the layout simply omits the shadow).
static func _sprite_shadow(tr: TextureRect) -> TextureRect:
	if tr == null or tr.texture == null:
		return null
	var sp := Look.saved_shadow_params()
	var display_size := Vector2i(maxi(1, int(round(tr.size.x))), maxi(1, int(round(tr.size.y))))
	var key := _sprite_shadow_key(tr.texture, display_size, sp)
	if _sprite_shadow_cache.has(key):
		var cached: Dictionary = _sprite_shadow_cache[key]
		return _shadow_rect(String(tr.name), cached.get("texture") as Texture2D, float(cached.get("pad", 0.0)), tr)

	var img: Image = tr.texture.get_image()
	if img == null:
		return null
	img = img.duplicate()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	img.resize(display_size.x, display_size.y, Image.INTERPOLATE_BILINEAR)
	var res: Dictionary = Kit.silhouette_shadow(img, {
		"shadow_offset": Vector2(float(sp.offset_x), float(sp.offset_y)),
		"shadow_blur": float(sp.blur), "shadow_alpha": float(sp.alpha),
		"shadow_spread": float(sp.spread)})
	var pad := float(res.pad)
	var tex := ImageTexture.create_from_image(res.image)
	_sprite_shadow_cache[key] = {"texture": tex, "pad": pad}
	return _shadow_rect(String(tr.name), tex, pad, tr)

static func _sprite_shadow_key(tex: Texture2D, display_size: Vector2i, sp: Dictionary) -> String:
	var tex_key := String(tex.resource_path)
	if tex_key == "":
		tex_key = str(tex.get_rid())
	return "%s|%dx%d|%.3f|%.3f|%.3f|%.3f|%.3f" % [
		tex_key, display_size.x, display_size.y,
		float(sp.offset_x), float(sp.offset_y), float(sp.blur), float(sp.alpha), float(sp.spread)]

static func _shadow_rect(base_name: String, tex: Texture2D, pad: float, tr: TextureRect) -> TextureRect:
	if tex == null:
		return null
	var shr := TextureRect.new()
	shr.name = base_name + "Shadow"
	shr.texture = tex
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

## The sakura MEDALLION: the single extracted plaque sprite (kit/level_plaque — the laurel wreath, slate
## disc, and daisy baked as one cut-paper piece) with the runtime level numeral drawn centred on its
## slate disc. The plaque art is shadow-free; the runtime silhouette shadow is re-applied by _add_shadowed.
static func _medallion(level: int, m: float) -> Control:
	var block := Control.new()
	block.name = "LevelMedallion"
	block.custom_minimum_size = Vector2(m, m)
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var plaque := _sprite("LevelPlaque", "plaque", m)
	if plaque != null:
		plaque.position = Vector2.ZERO
		block.custom_minimum_size = plaque.size
		_add_shadowed(block, plaque)

	# the numeral centred on the slate disc (the disc sits high on the plaque; the daisy hangs below)
	var disc_d := m * PLAQUE_DISC_D_F
	var digits := str(level)
	var num := Label.new()
	num.name = "LevelNumber"
	num.text = digits
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	num.add_theme_font_override("font", Kit.bold_font())
	var num_frac := 0.60 if digits.length() == 1 else (0.46 if digits.length() == 2 else 0.34)
	num.add_theme_font_size_override("font_size", int(disc_d * num_frac))
	num.add_theme_color_override("font_color", Pal.CREAM)
	num.add_theme_constant_override("outline_size", 0)
	var sp := Look.saved_shadow_params()
	num.add_theme_color_override("font_shadow_color", Look.shadow_color(float(sp.alpha)))
	num.add_theme_constant_override("shadow_offset_x", int(round(float(sp.offset_x))))
	num.add_theme_constant_override("shadow_offset_y", int(round(float(sp.offset_y))))
	num.add_theme_constant_override("shadow_outline_size", maxi(1, int(round(maxf(0.0, float(sp.blur) + float(sp.spread))))))
	num.size = Vector2(disc_d, disc_d)
	num.position = Vector2(m * PLAQUE_DISC_CX_F - disc_d * 0.5, m * PLAQUE_DISC_CY_F - disc_d * 0.5)
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	block.add_child(num)
	return block
