extends RefCounted
## UI Workbench — the self-contained component kit.
##
## The workbench's OWN definitions of the fundamental components, composed bottom-up:
##   cost_pill / claim_button   (atoms)
##     → mail_card              (molecule — composes a cost_pill + a claim_button)
##       → mail_dialog          (organism — composes a list of mail_cards)
## Each higher component CALLS the lower ones, so a change to an atom flows up automatically.
##
## Self-contained on purpose: this depends only on the shared design-system foundation
## (skin.gd primitives, the kit art, the palette) — NOT on the game screens (inbox.gd / shop.gd)
## or any game state. That keeps the components portable, so the game can later pull from here.

const Look = preload("res://engine/scripts/ui/skin.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const Pal = Game.PALETTE

# Nine-patch margins for the shared mail kit (sourced from the real recipe in inbox.gd).
const CARD_TEX := Vector2(30, 30)
const CARD_PAD := Vector4(18, 12, 18, 12)
const PILL_TEX := Vector2(46, 34)
const PILL_PAD := Vector4(14, 6, 14, 6)
const CLAIM_PAD := Vector4(24, 8, 24, 8)
const BANNER_H := 92.0

# Demo inbox matching the mockup — gift/acorn, leaf/water, news/gem, gift/coin.
const DEMO_MAIL := [
	{"icon": "gift", "title": "Welcome Gift", "body": "Thanks for joining us!", "rew": "gem", "n": 50},
	{"icon": "leaf", "title": "Garden Update", "body": "Here are your rewards!", "rew": "water", "n": 30},
	{"icon": "news", "title": "Maintenance Notice", "body": "Servers will be down soon.", "rew": "bluegem", "n": 20},
	{"icon": "gift", "title": "Daily Bonus", "body": "Your daily reward is here!", "rew": "coin", "n": 100},
]

## Resolve an icon id to a real sprite Control. Most ids ride the shared Look.icon; "bluegem" is the
## faceted premium gem (not the grove's acorn), loaded directly.
static func make_icon(id: String, px: float) -> Control:
	var tex := _icon_tex(id)               # polished (defringe + feather), via the shared resolver
	if tex != null:
		var t := TextureRect.new()
		t.texture = tex
		t.custom_minimum_size = Vector2(px, px)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return t
	return Look.icon(id, px)               # glyph fallback when no sprite

## --- icon edge polish (defringe / feather / supersample) -----------------------------------------
## Clean up a generated icon's rough alpha edge. opts: defringe (bool), feather (px), supersample
## (1-4), size (working/output px). Returns a polished Texture2D (or the raw texture on failure).
static func polish_icon_tex(id_or_path: String, opts: Dictionary = {}) -> Texture2D:
	var path := id_or_path
	if not path.begins_with("res://"):
		path = Game.art("ui/currency/icon_%s.png" % id_or_path)
	if not ResourceLoader.exists(path):
		return null
	var img := (load(path) as Texture2D).get_image()
	return ImageTexture.create_from_image(polish_image(img, opts))

static func polish_image(src: Image, opts: Dictionary = {}) -> Image:
	var do_defringe: bool = bool(opts.get("defringe", false))
	var feather: float = float(opts.get("feather", 0.0))
	var ss: int = clampi(int(opts.get("supersample", 1)), 1, 4)
	var size: int = int(opts.get("size", 160))
	var img := src.duplicate()
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	# Process at a CAPPED working resolution (so a high supersample can't blow up the cost and freeze
	# the tool), then Lanczos-downscale to the output size — the downscale is the supersample AA.
	var work := mini(320, maxi(8, size * ss))
	img.resize(work, work, Image.INTERPOLATE_LANCZOS)
	if do_defringe:
		_defringe(img)
	if feather > 0.0:
		_feather_alpha(img, feather * float(work) / float(size))   # radius in working pixels
	if work != size:
		img.resize(size, size, Image.INTERPOLATE_LANCZOS)
	return img

## Bleed the nearest opaque colour outward into the semi-transparent edge pixels (keeping their
## alpha), so the fringe of old-background colour disappears. A few passes for a clean rim.
static func _defringe(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	for _pass in 3:
		var data := img.get_data()
		var out := data.duplicate()
		for y in h:
			for x in w:
				var i := (y * w + x) * 4
				var a := data[i + 3]
				if a >= 230:
					continue
				var r := 0; var g := 0; var b := 0; var wsum := 0
				for off in [[-1, 0], [1, 0], [0, -1], [0, 1], [-1, -1], [1, 1], [-1, 1], [1, -1]]:
					var nx: int = x + int(off[0])
					var ny: int = y + int(off[1])
					if nx < 0 or ny < 0 or nx >= w or ny >= h:
						continue
					var ni: int = (ny * w + nx) * 4
					var na := data[ni + 3]
					if na > a + 12:
						r += data[ni] * na; g += data[ni + 1] * na; b += data[ni + 2] * na; wsum += na
				if wsum > 0:
					out[i] = int(r / wsum); out[i + 1] = int(g / wsum); out[i + 2] = int(b / wsum)
		img.set_data(w, h, false, Image.FORMAT_RGBA8, out)

## Box-blur the ALPHA channel by `radius` px — smooths the aliased stair-step edge. SEPARABLE
## (horizontal then vertical pass), so the cost is O(radius), not O(radius²) — that O(r²) kernel at a
## supersampled resolution was what froze the tool.
static func _feather_alpha(img: Image, radius: float) -> void:
	var r := int(round(radius))
	if r < 1:
		return
	var w := img.get_width()
	var h := img.get_height()
	var data := img.get_data()
	var n := w * h
	var al := PackedInt32Array()
	al.resize(n)
	for i in n:
		al[i] = data[i * 4 + 3]
	var tmp := PackedInt32Array()
	tmp.resize(n)
	for y in h:                                  # horizontal pass
		for x in w:
			var sum := 0
			var cnt := 0
			for dx in range(-r, r + 1):
				var nx: int = x + dx
				if nx < 0 or nx >= w:
					continue
				sum += al[y * w + nx]; cnt += 1
			tmp[y * w + x] = sum / cnt
	for y in h:                                  # vertical pass
		for x in w:
			var sum := 0
			var cnt := 0
			for dy in range(-r, r + 1):
				var ny: int = y + dy
				if ny < 0 or ny >= h:
					continue
				sum += tmp[ny * w + x]; cnt += 1
			al[y * w + x] = sum / cnt
	var out := data.duplicate()
	for i in n:
		out[i * 4 + 3] = al[i]
	img.set_data(w, h, false, Image.FORMAT_RGBA8, out)

## --- baked asset cleanup: defringe + feather 2, cached per asset (applied to every workbench sprite) ---
static var _clean_cache: Dictionary = {}

## A cleaned version of a sprite: defringe (kill the rough-cut colour fringe) + feather 2 (smooth the
## jagged edge). Cached by path so it runs once per asset. max_dim caps the working resolution.
static func clean_tex_path(path: String, max_dim: int = 256) -> Texture2D:
	if path == "" or not ResourceLoader.exists(path):
		return null
	if _clean_cache.has(path):
		return _clean_cache[path]
	var img := (load(path) as Texture2D).get_image()
	var t := ImageTexture.create_from_image(_clean_image(img, max_dim))
	_clean_cache[path] = t
	return t

static func _clean_image(src: Image, max_dim: int) -> Image:
	var img := src.duplicate() as Image
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	var w: int = img.get_width()
	var h: int = img.get_height()
	var m := maxi(w, h)
	if m > max_dim:                                   # cap the working res (aspect-preserving) for speed
		var s := float(max_dim) / float(m)
		img.resize(maxi(1, int(w * s)), maxi(1, int(h * s)), Image.INTERPOLATE_LANCZOS)
	_defringe(img)
	_feather_alpha(img, 2.0)
	return img

## A cream cost/reward pill: the sliced cream capsule + an icon + a number (mockup image 1).
static func cost_pill(rew_id: String, n: int, btn_opts: Dictionary = {}) -> Control:
	# The cost pill IS the shared pill_button, driven by the SAME state as the Claim — it only overrides
	# the background (cream) + content (reward icon + number) and is static (a display chip). So editing
	# the shared Button (corner, font, …) updates the cost pill too. One state, two backgrounds.
	var o := btn_opts.duplicate()
	o["bg"] = "cream"
	o["icon"] = rew_id
	o["static"] = true
	o["enabled"] = true
	return pill_button(str(n), o)

## (The old nine-patch claim_button was REMOVED — the mail Claim is now the shared pill_button below,
## so there is one button component. The mail card/dialog drive their Claim entirely from it.)

## Resolve any icon id to a Texture2D (so the shared button can show coin/water/gem/blue-gem, not
## just the currency folder). Mirrors make_icon's id rules.
static func _icon_tex(id: String) -> Texture2D:
	var rels: Array = []
	if id == "bluegem":
		rels = ["ui/currency/icon_gem_t3.png"]
	elif id.begins_with("coin") or id.begins_with("gem"):
		rels = ["ui/currency/icon_%s.png" % id]
	else:
		rels = ["ui/shared/icon_%s.png" % id, "ui/currency/icon_%s.png" % id]
	for rel in rels:
		var p := Game.art(rel)
		if ResourceLoader.exists(p):
			return clean_tex_path(p, 192)      # defringe + feather the rough-cut icon
	return null

## A unified pill BUTTON — ONE component, parameterised by state. opts:
##   bg      "green" | "cream"     (the same button, two backgrounds — Claim vs a cream chip)
##   icon    currency id | ""      (drawn to the LEFT of the text; "" = none — the icon toggle)
##   enabled bool                  (false → greyed, non-pressable)
##   font    px
## The mail screen's green Claim and a cream icon button are this one component with different opts.
static func pill_button(text: String, opts: Dictionary = {}) -> Button:
	var bg := String(opts.get("bg", "green"))
	var icon_id := String(opts.get("icon", ""))
	var enabled: bool = bool(opts.get("enabled", true))
	var font_px := int(opts.get("font", 22))
	var corner := float(opts.get("corner", 16.0))      # low = rectangular; ≥ height/2 = capsule
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.text = text
	b.disabled = not enabled
	b.add_theme_font_size_override("font_size", font_px)
	b.add_theme_constant_override("outline_size", 0)
	if icon_id != "":
		var tex := _icon_tex(icon_id)
		if tex != null:
			b.icon = tex
			b.add_theme_constant_override("icon_max_width", int(opts.get("icon_size", font_px + 8)))
			b.add_theme_constant_override("h_separation", 7)
	if bool(opts.get("static", false)):
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE      # a display chip (the cost pill): looks like the button, not pressable
	var fill: Color = Pal.BTN_PRIMARY if bg == "green" else Pal.CREAM
	var edge: Color = Pal.BTN_PRIMARY_EDGE if bg == "green" else Pal.STRAW
	var ink: Color = Pal.CREAM if bg == "green" else Pal.INK
	for st in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(st, ink)
	b.add_theme_color_override("font_disabled_color", Color(ink, 0.55))
	# --- background: the sprite NINE-PATCH (nice baked borders) when "art" is on, else code-drawn ---
	if bool(opts.get("art", false)):
		var art_rel := "kit/mail_pill.png" if bg == "green" else "kit/mail_pill_cream.png"
		var tex := clean_tex_path(Look.kit(art_rel), 256)   # polished; scaled WHOLE (9-slice cut pills poorly)
		if tex != null:
			var stx := StyleBoxTexture.new()
			stx.texture = tex
			# NO texture margins → the entire sprite scales to the button, no slicing
			stx.content_margin_left = 22; stx.content_margin_right = 22
			stx.content_margin_top = 8; stx.content_margin_bottom = 9
			b.add_theme_stylebox_override("normal", stx)
			b.add_theme_stylebox_override("hover", stx)
			var sp_t: StyleBoxTexture = stx.duplicate(); sp_t.modulate_color = Color(0.88, 0.88, 0.88)
			b.add_theme_stylebox_override("pressed", sp_t)
			var sd_t: StyleBoxTexture = stx.duplicate(); sd_t.modulate_color = Color(0.62, 0.62, 0.62)
			b.add_theme_stylebox_override("disabled", sd_t)
			return b
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = edge
	s.set_corner_radius_all(int(corner))      # rectangular at low values; capsule near/above height/2
	s.set_border_width_all(2)
	s.shadow_color = Color(0, 0, 0, 0.22)
	s.shadow_size = 5
	s.shadow_offset = Vector2(0, 3)
	s.content_margin_left = 18; s.content_margin_right = 18
	s.content_margin_top = 7; s.content_margin_bottom = 8
	b.add_theme_stylebox_override("normal", s)
	b.add_theme_stylebox_override("hover", s)
	var sp: StyleBoxFlat = s.duplicate()
	sp.bg_color = fill.darkened(0.08)
	b.add_theme_stylebox_override("pressed", sp)
	var sd: StyleBoxFlat = s.duplicate()
	sd.bg_color = fill.lerp(Color(0.55, 0.55, 0.55), 0.55)
	sd.shadow_size = 0
	b.add_theme_stylebox_override("disabled", sd)
	b.add_child(Look.rim_overlay(corner, 2))
	return b

## (The standalone buy_pill / green-CTA builder was REMOVED — it was the original spike component and
## is fully covered by pill_button(green, icon). The CTA is now the shared button's green variant.)

## A plated message icon — the icon seated on a pale cream disc (mockup's left-of-row motif).
static func plated_icon(id: String, px: float = 56.0) -> Control:
	var plate := PanelContainer.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(Pal.CREAM, 0.9)
	ps.set_corner_radius_all(int(px))
	ps.set_border_width_all(2)
	ps.border_color = Color(Pal.BARK, 0.22)
	var pad := px * 0.16
	ps.content_margin_left = pad; ps.content_margin_right = pad
	ps.content_margin_top = pad; ps.content_margin_bottom = pad
	plate.add_theme_stylebox_override("panel", ps)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	plate.add_child(make_icon(id, px))
	return plate

## A mail card (mockup image 2): plated icon + title/body + a cost_pill + a claim_button.
## COMPOSES the two atoms — pill size flows in from the caller so a knob change propagates here.
static func mail_card(entry: Dictionary, title_font: int = 20, body_font: int = 15, btn_opts: Dictionary = {}) -> Control:
	var panel := PanelContainer.new()
	var box := Look.kit_box("kit/mail_card.png", CARD_TEX, CARD_PAD)
	if box != null:
		panel.add_theme_stylebox_override("panel", box)
	else:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(Pal.CREAM, 0.6)
		s.set_corner_radius_all(14)
		s.set_border_width_all(1)
		s.border_color = Color(Pal.BARK, 0.4)
		s.content_margin_left = 14; s.content_margin_right = 14
		s.content_margin_top = 10; s.content_margin_bottom = 10
		panel.add_theme_stylebox_override("panel", s)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)

	var ic := plated_icon(String(entry.get("icon", "star")), 56.0)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ic)

	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 2)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	var title := Label.new()
	title.text = String(entry.get("title", ""))
	title.add_theme_font_size_override("font_size", title_font)
	title.add_theme_color_override("font_color", Pal.INK)
	title.add_theme_constant_override("outline_size", 0)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(title)
	var body := Label.new()
	body.text = String(entry.get("body", ""))
	body.add_theme_font_size_override("font_size", body_font)
	body.add_theme_color_override("font_color", Color(Pal.BARK, 0.95))
	body.add_theme_constant_override("outline_size", 0)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(body)

	# Both the cost pill AND the Claim are the SHARED pill_button (cream variant vs green) — driven
	# entirely by the same btn_opts, so editing the shared Button updates them across every row.
	var chip := cost_pill(String(entry.get("rew", "gem")), int(entry.get("n", 0)), btn_opts)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(chip)
	var claim := pill_button(String(btn_opts.get("text", "Claim")), btn_opts)
	claim.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(claim)
	return panel

## The dialog banner band: ribbon art + the "Mail" text drawn FULL-RECT and vertically CENTRED, so it
## auto-aligns whatever the font size; plus an optional envelope icon (toggle). Named DialogBanner /
## DialogBannerIcon so the workbench can drag them.
static func _banner(text: String, font: int, band_h: float, width: float, icon_on: bool,
		icon_px: float, icon_pos) -> Control:
	var header := Control.new()
	header.name = "DialogBanner"
	header.custom_minimum_size = Vector2(width, band_h)
	var bp := Look.kit("mail/mail_banner.png")
	if ResourceLoader.exists(bp):
		var art := TextureRect.new()
		art.texture = clean_tex_path(bp, 480)   # polished ribbon
		art.set_anchors_preset(Control.PRESET_FULL_RECT)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		header.add_child(art)
	var lbl := Label.new()
	lbl.text = text
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER       # auto-vcentre on any font size
	lbl.add_theme_font_size_override("font_size", font)
	lbl.add_theme_color_override("font_color", Pal.INK)
	lbl.add_theme_constant_override("outline_size", 0)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(lbl)
	if icon_on and ResourceLoader.exists(bp):
		var env := make_icon("mail", icon_px)   # polished envelope
		env.name = "DialogBannerIcon"
		env.mouse_filter = Control.MOUSE_FILTER_IGNORE
		header.add_child(env)
		if icon_pos != null:
			env.position = icon_pos
		else:
			var place := func() -> void:                       # default: ~30% across, vertically centred
				if is_instance_valid(env) and is_instance_valid(header):
					env.position = Vector2(header.size.x * 0.30 - icon_px / 2.0, header.size.y / 2.0 - icon_px / 2.0)
			header.resized.connect(place)
			header.ready.connect(place)
	return header

## The dialog ✕ — the mail_close sprite scaled (polished). Named DialogClose so the workbench drags it.
static func _close_button(size: float, cb: Callable) -> Button:
	var b := Button.new()
	b.name = "DialogClose"
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(size, size)
	var tex := clean_tex_path(Look.kit("kit/mail_close.png"), 192)
	if tex != null:
		var st := StyleBoxTexture.new()
		st.texture = tex
		b.add_theme_stylebox_override("normal", st)
		b.add_theme_stylebox_override("hover", st)
		var sp: StyleBoxTexture = st.duplicate()
		sp.modulate_color = Color(0.88, 0.88, 0.88)
		b.add_theme_stylebox_override("pressed", sp)
	b.pressed.connect(func() -> void:
		if cb.is_valid(): cb.call())
	return b

## The whole Mail dialog (mockup image 3): a parchment card with the gold banner + envelope, a
## docked ✕, and a column of mail_cards. COMPOSES mail_card for every entry.
## opts (all optional): banner_font, banner_h, banner_icon (px), banner_icon_pos (Vector2 in the
## banner band, or absent = ~30% across, centred), close_size (px), close_poke (Vector2 — how far the
## ✕ poles past the card's top-right corner). The banner icon ("DialogBannerIcon") and the ✕
## ("DialogClose") are NAMED so the workbench can make them mouse-draggable.
static func mail_dialog(entries: Array, width: float = 560.0, opts: Dictionary = {}) -> Control:
	var banner_font: int = int(opts.get("banner_font", 32))
	var banner_h: float = float(opts.get("banner_h", BANNER_H))
	var banner_icon: float = float(opts.get("banner_icon", 54.0))
	var banner_icon_on: bool = bool(opts.get("banner_icon_on", true))    # the envelope toggle
	var banner_icon_pos = opts.get("banner_icon_pos", null)        # Vector2 (px in the band) or null = auto
	var close_size: float = float(opts.get("close_size", 64.0))
	var close_poke: Vector2 = opts.get("close_poke", Vector2(12, 12))
	var btn_opts: Dictionary = opts.get("btn", {})       # the shared Button drives the cost pills + Claims
	var card_corner: float = float(opts.get("card_corner", 22.0))
	var card_art: bool = bool(opts.get("card_art", false))       # true = the parchment nine-patch
	var sl_l: float = float(opts.get("card_slice_l", 48.0))      # the 4 per-side 9-slice texture margins
	var sl_t: float = float(opts.get("card_slice_t", 48.0))
	var sl_r: float = float(opts.get("card_slice_r", 48.0))
	var sl_b: float = float(opts.get("card_slice_b", 48.0))
	var hstr: int = int(opts.get("card_h_stretch", 0))           # axis stretch: 0 stretch · 1 tile · 2 tile-fit
	var vstr: int = int(opts.get("card_v_stretch", 0))

	var wrap := Control.new()

	var card := PanelContainer.new()
	# The card background: the parchment NINE-PATCH (with a tunable slice margin) when card art is on,
	# else CODE-DRAWN with a configurable corner. (The parchment's corners are baked into the art, so the
	# Card corner slider only applies in code mode — that's why the workbench shows just one or the other.)
	var pp := Look.kit("kit/panel_parchment_v2.png")     # the v2 shop panel — much smaller rounded corners
	if card_art and ResourceLoader.exists(pp):
		var st := StyleBoxTexture.new()
		st.texture = load(pp)
		st.set_texture_margin(SIDE_LEFT, sl_l)
		st.set_texture_margin(SIDE_TOP, sl_t)
		st.set_texture_margin(SIDE_RIGHT, sl_r)
		st.set_texture_margin(SIDE_BOTTOM, sl_b)
		st.axis_stretch_horizontal = hstr
		st.axis_stretch_vertical = vstr
		st.content_margin_left = 26; st.content_margin_right = 26
		st.content_margin_top = 24; st.content_margin_bottom = 24
		card.add_theme_stylebox_override("panel", st)
	else:
		var cf := StyleBoxFlat.new()
		cf.bg_color = Pal.CREAM
		cf.border_color = Pal.BARK
		cf.set_corner_radius_all(int(card_corner))
		cf.set_border_width_all(3)
		cf.content_margin_left = 18; cf.content_margin_right = 18
		cf.content_margin_top = 18; cf.content_margin_bottom = 18
		card.add_theme_stylebox_override("panel", cf)
	card.custom_minimum_size = Vector2(width, 0)
	card.position = Vector2.ZERO
	wrap.add_child(card)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(col)

	# the banner band lives in a SLOT that reserves its height in the column, but is a FREE child of
	# that slot so the workbench can DRAG it (offset banner_pos — e.g. pull it up to overhang the card).
	var banner_pos = opts.get("banner_pos", Vector2.ZERO)
	var banner_slot := Control.new()
	banner_slot.custom_minimum_size = Vector2(0, banner_h)
	banner_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	banner_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(banner_slot)
	var header := _banner("Mail", banner_font, banner_h, width, banner_icon_on, banner_icon, banner_icon_pos)
	header.position = banner_pos
	banner_slot.add_child(header)

	var entries_count: int = int(opts.get("entries_count", entries.size()))
	var list_max_h: float = float(opts.get("list_max_h", 0.0))   # 0 = uncapped (grows freely, no scroll)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 10)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in maxi(0, entries_count):
		rows.add_child(mail_card(entries[i % entries.size()], 20, 15, btn_opts))
	if list_max_h > 0.0:
		var scroll := ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(rows)
		var cap := func() -> void:                # cap the height so content beyond it scrolls
			if is_instance_valid(scroll) and is_instance_valid(rows):
				scroll.custom_minimum_size.y = minf(list_max_h, rows.size.y)
		rows.resized.connect(cap)
		rows.ready.connect(cap)
		col.add_child(scroll)
	else:
		col.add_child(rows)

	# the ✕ disc poles past the card's top-right corner once the card has laid out + sized.
	var close := _close_button(close_size, func() -> void: print("WORKBENCH: mail closed"))
	wrap.add_child(close)
	var dock := func() -> void:
		if not is_instance_valid(card) or not is_instance_valid(close):
			return
		wrap.custom_minimum_size = card.size
		close.position = Vector2(card.size.x - close_size + close_poke.x, -close_poke.y)
	card.resized.connect(dock)
	card.ready.connect(dock)
	return wrap
