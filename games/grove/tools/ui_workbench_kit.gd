extends RefCounted
## UI Workbench — the self-contained component kit.
##
## The workbench's OWN definitions of the fundamental components, composed bottom-up:
##   pill_button                (the ONE button atom — green Claim, cream reward pill, all variants)
##     → mail_card              (molecule — a reward pill + a Claim, both the shared pill_button)
##       → mail_dialog          (organism — composes a list of mail_cards)
## Each higher component CALLS the lower ones, so a change to the atom flows up automatically. There is
## no separate cost-pill component — a reward pill is just pill_button in its cream/static variant.
##
## Self-contained on purpose: this depends only on the shared design-system foundation
## (skin.gd primitives, the kit art, the palette) — NOT on game state. The GAME pulls from here
## (engine/scripts/ui/inbox.gd builds its mailbox from these + the saved workbench config).

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

# Badge backgrounds (art mode): friendly label → kit sprite. The Card picks one for its Claim; the
# game reads the same map via the saved config. "auto" = the bg-default sprite (green/cream).
const BADGES := {
	"auto": "",
	"mail green": "kit/mail_pill.png",
	"mail cream": "kit/mail_pill_cream.png",
	"bag": "kit/bag_pill.png",
	"bag b": "kit/bag_pill_b.png",
	"bag green": "kit/bag_pill_green.png",
	"bag thin": "kit/bag_pill_thin.png",
	"shop buy": "kit/shop_buy.png",
	"shop tag": "kit/shop_tag.png",
	"shop oval": "kit/shop_oval.png",
}

# Circle/plate sprites for the Card's LEFT icon badge (the disc behind the message icon). "" = a flat
# code-drawn cream disc. disc_round is the lightest (pale cream); btn_round is the darker gold chrome.
const ICON_BADGES := {
	"disc light": "shared/disc_round.png",
	"round chrome": "shared/btn_round.png",
	"cell": "kit/tiers_cell.png",
	"cream (flat)": "",
}

# Highlight styles for a daily day card (the rim/glow drawn over the cream square). The Daily dialog
# picks one for TODAY's rung and one for a milestone day — both saved settings the workbench tunes.
const DAY_BADGES := ["plain", "gold rim", "gold glow", "amber glow", "leaf glow"]

# The POPULAR ribbon texts a small card can wear (shop merchandising tags). "" = no ribbon.
const POPULAR_BADGES := ["", "Popular", "Best value", "Sale", "New", "Welcome", "Limited", "2× bonus", "-50%", "Hot"]

# Demo inbox — same shape as the GAME's messages (core/inbox.gd): reward is a {coins,gems,water} dict
# so one component renders both. The news note carries no reward (→ no chip / no Claim).
const DEMO_MAIL := [
	{"icon": "gift", "title": "Welcome Gift", "body": "Thanks for joining us!", "reward": {"gems": 50}},
	{"icon": "leaf", "title": "Garden Update", "body": "Here are your rewards!", "reward": {"water": 30}},
	{"icon": "news", "title": "Maintenance Notice", "body": "Servers will be down soon.", "reward": {}},
	{"icon": "gift", "title": "Daily Bonus", "body": "Your daily reward is here!", "reward": {"coins": 100, "gems": 5}},
]

# Demo daily-gifts ladder (7 days) for the workbench preview — same shape the game builds from
# core/login.gd. state: done (claimed ✓) · today (the claimable rung, green Claim) · future. A future
# milestone shows the mystery chest instead of its reward.
const DEMO_DAILY := [
	{"day": 1, "reward": {"coins": 50}, "state": "done"},
	{"day": 2, "reward": {"water": 10}, "state": "done"},
	{"day": 3, "reward": {"gems": 5}, "state": "done"},
	{"day": 4, "reward": {"coins": 150}, "state": "today"},
	{"day": 5, "reward": {"coins": 100}, "state": "future"},
	{"day": 6, "reward": {"water": 20}, "state": "future"},
	{"day": 7, "reward": {"gems": 30}, "state": "future", "mystery": true},
]

# Demo shop packs for the workbench preview — the SAME small card (daily_card) as the daily grid, here
# with an icon + count + a price button and an optional Popular ribbon (no day label, no claim).
const DEMO_SHOP := [
	{"icon": "gem", "count": 80, "price": "$0.99"},
	{"icon": "gem", "count": 500, "price": "$4.99", "ribbon": "Popular"},
	{"icon": "bluegem", "count": 1200, "price": "$9.99", "ribbon": "Best value"},
	{"icon": "coin", "count": 5000, "price": "$1.99"},
	{"icon": "water", "count": 60, "price": "$0.99"},
	{"icon": "bluegem", "count": 3000, "price": "$19.99", "ribbon": "2× bonus"},
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
	if bool(opts.get("shadow", false)):
		img = add_drop_shadow(img, opts)
	return img

## Bake a soft drop shadow beneath an alpha-shaped sprite (icons). Grows the canvas symmetrically by
## `pad` so the sprite stays centred (it just renders a touch smaller in its box) and the shadow — the
## sprite's own alpha, offset + blurred + tinted black — sits beneath it. opts: shadow_offset (Vector2
## px at this image's scale), shadow_blur (px), shadow_alpha (0..1), shadow_pad (px). The shape-true
## shadow (follows the sprite's silhouette) is why icons bake it instead of using a rounded-rect panel.
static func add_drop_shadow(img: Image, opts: Dictionary = {}) -> Image:
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var off: Vector2 = opts.get("shadow_offset", Vector2(0.04, 0.07) * float(w))
	var blur: float = float(opts.get("shadow_blur", maxf(2.0, float(w) * 0.035)))
	var alpha: float = clampf(float(opts.get("shadow_alpha", 0.5)), 0.0, 1.0)
	var pad: int = int(opts.get("shadow_pad", int(ceil(blur)) + int(maxf(absf(off.x), absf(off.y))) + 2))
	var nw := w + pad * 2
	var nh := h + pad * 2
	var sx := pad + int(round(off.x))
	var sy := pad + int(round(off.y))
	var src_data := img.get_data()
	var shadow := Image.create(nw, nh, false, Image.FORMAT_RGBA8)
	var sh_data := shadow.get_data()
	for y in h:
		for x in w:
			var a := src_data[(y * w + x) * 4 + 3]
			if a == 0:
				continue
			var nx := x + sx
			var ny := y + sy
			if nx < 0 or ny < 0 or nx >= nw or ny >= nh:
				continue
			sh_data[(ny * nw + nx) * 4 + 3] = int(a * alpha)   # RGB stays 0 → a black shadow
	shadow.set_data(nw, nh, false, Image.FORMAT_RGBA8, sh_data)
	_feather_alpha(shadow, blur)
	shadow.blend_rect(img, Rect2i(0, 0, w, h), Vector2i(pad, pad))   # sprite OVER the shadow (alpha blend)
	return shadow

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

## (cost_pill was ABANDONED — a reward pill is just the SHARED pill_button in its cream/static variant,
## built inline in reward_chip below. There is no separate cost-pill component; one button drives all.)

## Sum of a reward's currency components ({coins, gems, water}). 0 = a plain note (no chip / no Claim).
static func _reward_total(reward: Dictionary) -> int:
	return int(reward.get("coins", 0)) + int(reward.get("gems", 0)) + int(reward.get("water", 0))

## The reward affordance for a message: a CREAM pill showing every non-zero currency. A single currency
## IS the shared pill_button (its cream/static variant — same component as the Claim, so it inherits the
## Button's style); a multi-currency gift stacks one icon+number per line inside the cream capsule.
static func reward_chip(reward: Dictionary, btn_opts: Dictionary = {}) -> Control:
	var parts: Array = []
	for pr in [["coin", int(reward.get("coins", 0))], ["gem", int(reward.get("gems", 0))], ["water", int(reward.get("water", 0))]]:
		if int(pr[1]) > 0:
			parts.append(pr)
	if parts.is_empty():
		return Control.new()
	if parts.size() == 1:
		# the shared button, cream/static variant — no separate cost-pill component
		var o := btn_opts.duplicate()
		o["bg"] = "cream"
		o.erase("art_rel")                 # cream by role; a chosen (green) badge is dropped
		o["icon"] = String(parts[0][0])
		o["static"] = true
		o["enabled"] = true
		return pill_button(str(int(parts[0][1])), o)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for p in parts:
		var cell := HBoxContainer.new()
		cell.alignment = BoxContainer.ALIGNMENT_CENTER
		cell.add_theme_constant_override("separation", 4)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(make_icon(String(p[0]), 22))
		var l := Label.new()
		l.text = str(int(p[1]))
		l.add_theme_font_size_override("font_size", 15)
		l.add_theme_color_override("font_color", Pal.INK)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(l)
		col.add_child(cell)
	var frame := PanelContainer.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var made := false
	if bool(btn_opts.get("art", false)):
		var tex := clean_tex_path(Look.kit("kit/mail_pill_cream.png"), 256)   # cream by role (not the badge)
		if tex != null:
			var stx := StyleBoxTexture.new()
			stx.texture = tex
			stx.content_margin_left = 18; stx.content_margin_right = 18
			stx.content_margin_top = 8; stx.content_margin_bottom = 9
			frame.add_theme_stylebox_override("panel", stx)
			made = true
	if not made:
		var cf := StyleBoxFlat.new()
		cf.bg_color = Pal.CREAM
		cf.border_color = Pal.STRAW
		cf.set_corner_radius_all(int(btn_opts.get("corner", 16)))
		cf.set_border_width_all(2)
		cf.content_margin_left = 14; cf.content_margin_right = 14
		cf.content_margin_top = 7; cf.content_margin_bottom = 8
		frame.add_theme_stylebox_override("panel", cf)
	frame.add_child(col)
	return frame

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

## The icon, padded to a SQUARE canvas (centred), so its bounding box is identical for every icon id.
## A button using this with a fixed icon_max_width then keeps a CONSTANT layout whatever icon is shown —
## a tall/narrow drop and a square gem both occupy the same box (each just fills it by its own aspect).
static var _square_cache: Dictionary = {}
static func _square_icon(id: String) -> Texture2D:
	if _square_cache.has(id):
		return _square_cache[id]
	var tex := _icon_tex(id)
	if tex == null:
		return null
	var img := tex.get_image()
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	if w != h:
		var s := maxi(w, h)
		var sq := Image.create(s, s, false, Image.FORMAT_RGBA8)
		sq.blit_rect(img, Rect2i(0, 0, w, h), Vector2i((s - w) / 2, (s - h) / 2))   # centre on the square
		img = sq
	var t := ImageTexture.create_from_image(img)
	_square_cache[id] = t
	return t

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
	var shadow: bool = bool(opts.get("shadow", false)) # a soft drop shadow under the pill
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.text = text
	b.disabled = not enabled
	b.add_theme_font_size_override("font_size", font_px)
	b.add_theme_constant_override("outline_size", 0)
	if icon_id != "":
		var tex := _square_icon(icon_id)      # square box → the icon never resizes the button per id
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
		# default badge follows the bg; a caller (button / card badge selector) can pick any kit sprite.
		var art_rel := String(opts.get("art_rel", ""))
		if art_rel == "":
			art_rel = "kit/mail_pill.png" if bg == "green" else "kit/mail_pill_cream.png"
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
			return _maybe_shadow(b, shadow, 24.0)
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = edge
	s.set_corner_radius_all(int(corner))      # rectangular at low values; capsule near/above height/2
	s.set_border_width_all(2)
	s.shadow_color = Color(0, 0, 0, 0.22)
	s.shadow_size = 5 if shadow else 0      # the drop-shadow toggle (code-drawn pill)
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

## Wrap a textured (art-mode) pill in a PanelContainer whose only job is to draw a soft rounded-rect
## drop shadow behind it. The container hugs the button's size, so callers' size flags still apply to
## the returned node. (Code-drawn pills get their shadow from the StyleBoxFlat directly, no wrapper.)
static func _maybe_shadow(b: Control, on: bool, corner: float) -> Control:
	if not on:
		return b
	var wrap := PanelContainer.new()
	var ss := StyleBoxFlat.new()
	ss.draw_center = false                       # only the shadow renders, not a fill
	ss.set_corner_radius_all(int(maxf(corner, 18.0)))
	ss.shadow_color = Color(0, 0, 0, 0.30)
	ss.shadow_size = 6
	ss.shadow_offset = Vector2(0, 4)
	wrap.add_theme_stylebox_override("panel", ss)
	wrap.add_child(b)
	return wrap

## (The standalone buy_pill / green-CTA builder was REMOVED — it was the original spike component and
## is fully covered by pill_button(green, icon). The CTA is now the shared button's green variant.)

## A plated message icon — the icon seated on a chosen circular badge sprite (see ICON_BADGES; the Card
## picks which). `px` is the badge diameter; the icon sits at ~58% inside it. badge_rel "" (or missing
## art) falls back to a flat code-drawn cream disc — the lightest option.
static func plated_icon(id: String, px: float = 56.0, badge_rel: String = "shared/disc_round.png") -> Control:
	var plate := PanelContainer.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var icon_px := px * 0.58
	var pad := (px - icon_px) / 2.0
	var tex: Texture2D = clean_tex_path(Look.kit(badge_rel), 256) if badge_rel != "" else null
	if tex != null:
		var st := StyleBoxTexture.new()
		st.texture = tex                                  # whole sprite scaled → its baked edge shows
		st.content_margin_left = pad; st.content_margin_right = pad
		st.content_margin_top = pad; st.content_margin_bottom = pad
		plate.add_theme_stylebox_override("panel", st)
	else:
		var ps := StyleBoxFlat.new()
		ps.bg_color = Color(Pal.CREAM, 0.9)
		ps.set_corner_radius_all(int(px))
		ps.set_border_width_all(2)
		ps.border_color = Color(Pal.BARK, 0.22)
		ps.content_margin_left = pad; ps.content_margin_right = pad
		ps.content_margin_top = pad; ps.content_margin_bottom = pad
		plate.add_theme_stylebox_override("panel", ps)
	plate.add_child(make_icon(id, icon_px))
	return plate

## A mail card (mockup image 2): a plated icon + title/body + a reward pill + a Claim — the reward pill
## and Claim are BOTH the shared pill_button, so a Button knob change propagates here. icon_badge picks
## the circular badge sprite behind the left icon (see ICON_BADGES).
static func mail_card(entry: Dictionary, title_font: int = 20, body_font: int = 15, btn_opts: Dictionary = {}, icon_badge: String = "shared/disc_round.png") -> Control:
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

	# the left icon gets vertical breathing room (margin top/bottom) so it isn't cramped against the row edges
	var ic_wrap := MarginContainer.new()
	ic_wrap.add_theme_constant_override("margin_top", 10)
	ic_wrap.add_theme_constant_override("margin_bottom", 10)
	ic_wrap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ic_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic_wrap.add_child(plated_icon(String(entry.get("icon", "star")), 56.0, icon_badge))
	row.add_child(ic_wrap)

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
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS   # clip+… → never forces card wider
	text.add_child(title)
	var body := Label.new()
	body.text = String(entry.get("body", ""))
	body.add_theme_font_size_override("font_size", body_font)
	body.add_theme_color_override("font_color", Color(Pal.BARK, 0.95))
	body.add_theme_constant_override("outline_size", 0)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART             # wrap → never forces card wider
	text.add_child(body)

	# The reward affordance: a cream reward chip + (when the gift is unclaimed) the GREEN Claim. Both are
	# the shared pill_button driven by btn_opts; a claimed gift shows a quiet "Claimed" tag; a plain note
	# (no reward) shows neither. The Claim is green BY ROLE (cost pill is cream) — a fixed kit role colour,
	# not a saved knob, so it never depends on the Button preview's background (a chosen badge still wins).
	var reward: Dictionary = entry.get("reward", {})
	if _reward_total(reward) > 0:
		var chip := reward_chip(reward, btn_opts)
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(chip)
		if bool(entry.get("claimed", false)):
			var done := Label.new()
			done.text = String(entry.get("claimed_text", "Claimed"))
			done.add_theme_font_size_override("font_size", 14)
			done.add_theme_color_override("font_color", Color(Pal.LEAF.darkened(0.1), 0.95))
			done.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			done.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(done)
			panel.modulate = Color(1, 1, 1, 0.7)
		else:
			var claim_opts := btn_opts.duplicate()
			claim_opts["bg"] = "green"
			var claim := pill_button(String(btn_opts.get("text", "Claim")), claim_opts)
			claim.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var on_claim: Callable = entry.get("on_claim", Callable())
			if on_claim.is_valid():
				claim.pressed.connect(func() -> void: on_claim.call())
			row.add_child(claim)
	return panel

## The dialog banner band: ribbon art + the "Mail" text drawn FULL-RECT and vertically CENTRED, so it
## auto-aligns whatever the font size; plus an optional envelope icon (toggle). Named DialogBanner /
## DialogBannerIcon so the workbench can drag them.
static func _banner(text: String, font: int, band_h: float, width: float, icon_on: bool,
		icon_px: float, icon_pos, text_x: float = 0.0, text_y: float = 0.0, burn: float = 0.0) -> Control:
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
	lbl.offset_left = text_x; lbl.offset_right = text_x      # shift the centred text horizontally
	lbl.offset_top = text_y; lbl.offset_bottom = text_y      # ...and vertically
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER       # auto-vcentre on any font size
	lbl.add_theme_font_size_override("font_size", font)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if burn > 0.0:
		# "burned into the ribbon": dark engraved ink + a light lower emboss highlight + a soft dark halo.
		# Intensity (0..1) deepens the ink and grows the emboss/halo, so it's a dial, not just on/off.
		var t := clampf(burn, 0.0, 1.0)
		lbl.add_theme_color_override("font_color", Color("#4A2E14").darkened(0.35 * t))
		lbl.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.25 + 0.45 * t))
		lbl.add_theme_constant_override("shadow_offset_x", int(round(1.0 + 2.0 * t)))
		lbl.add_theme_constant_override("shadow_offset_y", int(round(2.0 + 3.0 * t)))
		lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.12 + 0.33 * t))
		lbl.add_theme_constant_override("outline_size", int(round(2.0 + 4.0 * t)))
	else:
		lbl.add_theme_color_override("font_color", Pal.INK)
		lbl.add_theme_constant_override("outline_size", 0)
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

## A tidier scrollbar: a rounded bark grabber on a faint track (vs the default chunky bar).
static func _style_scrollbar(scroll: ScrollContainer) -> void:
	var vb := scroll.get_v_scroll_bar()
	vb.custom_minimum_size.x = 10
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(Pal.BARK, 0.55)
	grab.set_corner_radius_all(5)
	grab.content_margin_left = 3
	grab.content_margin_right = 3
	for s in ["grabber", "grabber_highlight", "grabber_pressed"]:
		vb.add_theme_stylebox_override(s, grab)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(Pal.BARK, 0.1)
	track.set_corner_radius_all(5)
	vb.add_theme_stylebox_override("scroll", track)

## The whole Mail dialog (mockup image 3): a parchment card with the gold banner + envelope, a
## docked ✕, and a column of mail_cards. COMPOSES mail_card for every entry.
## opts (all optional): banner_font, banner_h, banner_icon (px), banner_icon_pos (Vector2 in the
## banner band, or absent = ~30% across, centred), close_size (px), close_poke (Vector2 — how far the
## ✕ poles past the card's top-right corner). The banner icon ("DialogBannerIcon") and the ✕
## ("DialogClose") are NAMED so the workbench can make them mouse-draggable.
## The SHARED dialog frame — built ONCE and reused by every dialog (mail, daily, …). It draws the
## parchment card, the gold banner overlay (on top, draggable), the docked ✕, and the clipping scroll
## with a top spacer so `content` tucks behind the banner; one relayout caps the height, centres the
## wrap, and docks the ✕. `content` is whatever scrolls inside (mail → a column of cards; daily → a
## grid). The named DialogBanner / DialogBannerIcon / DialogClose let the workbench drag the handles.
static func dialog_frame(content: Control, width: float = 560.0, opts: Dictionary = {}) -> Control:
	var banner_font: int = int(opts.get("banner_font", 32))
	var banner_h: float = float(opts.get("banner_h", BANNER_H))
	var banner_icon: float = float(opts.get("banner_icon", 54.0))
	var banner_icon_on: bool = bool(opts.get("banner_icon_on", true))
	var banner_icon_pos = opts.get("banner_icon_pos", null)
	var close_size: float = float(opts.get("close_size", 64.0))
	var close_poke: Vector2 = opts.get("close_poke", Vector2(12, 12))
	var card_corner: float = float(opts.get("card_corner", 22.0))
	var card_art: bool = bool(opts.get("card_art", false))
	var sl_l: float = float(opts.get("card_slice_l", 48.0))
	var sl_t: float = float(opts.get("card_slice_t", 48.0))
	var sl_r: float = float(opts.get("card_slice_r", 48.0))
	var sl_b: float = float(opts.get("card_slice_b", 48.0))
	var hstr: int = int(opts.get("card_h_stretch", 0))
	var vstr: int = int(opts.get("card_v_stretch", 0))
	var banner_pos = opts.get("banner_pos", Vector2.ZERO)
	var banner_text_x: float = float(opts.get("banner_text_x", 0.0))
	var banner_text_y: float = float(opts.get("banner_text_y", 0.0))
	var banner_burn: float = float(opts.get("banner_burn", 0.0))
	var list_max_h: float = float(opts.get("list_max_h", 0.0))
	var list_top_pad: float = float(opts.get("list_top_pad", 0.0))
	var on_close: Callable = opts.get("on_close", Callable())
	var banner_text: String = String(opts.get("banner_text", "Mail"))

	var wrap := Control.new()
	var card := PanelContainer.new()
	# parchment NINE-PATCH (tunable slice) when card art is on, else CODE-DRAWN with a configurable corner.
	var pp := Look.kit("kit/panel_parchment_v2.png")
	if card_art and ResourceLoader.exists(pp):
		var st := StyleBoxTexture.new()
		st.texture = load(pp)
		st.set_texture_margin(SIDE_LEFT, sl_l); st.set_texture_margin(SIDE_TOP, sl_t)
		st.set_texture_margin(SIDE_RIGHT, sl_r); st.set_texture_margin(SIDE_BOTTOM, sl_b)
		st.axis_stretch_horizontal = hstr; st.axis_stretch_vertical = vstr
		st.content_margin_left = 26; st.content_margin_right = 26
		st.content_margin_top = 24; st.content_margin_bottom = 24
		card.add_theme_stylebox_override("panel", st)
	else:
		var cf := StyleBoxFlat.new()
		cf.bg_color = Pal.CREAM; cf.border_color = Pal.BARK
		cf.set_corner_radius_all(int(card_corner)); cf.set_border_width_all(3)
		cf.content_margin_left = 18; cf.content_margin_right = 18
		cf.content_margin_top = 18; cf.content_margin_bottom = 18
		card.add_theme_stylebox_override("panel", cf)
	card.custom_minimum_size = Vector2(width, 0)
	card.position = Vector2.ZERO
	wrap.custom_minimum_size.x = width      # robust horizontal centring even before relayout runs
	wrap.add_child(card)

	# inner = the card's single content child; it hosts the scrolling content AND the banner overlay
	var inner := Control.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.clip_contents = false                  # the banner may overhang the top
	card.add_child(inner)

	# the content scrolls and FILLS the card; it clips, so content slides up BEHIND the banner. A top
	# spacer (banner bottom + list_top_pad) keeps content below the banner to begin with.
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.clip_contents = true
	_style_scrollbar(scroll)
	inner.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var spacer := Control.new()
	var spacer_h: float = maxf(0.0, banner_pos.y + banner_h) + list_top_pad
	spacer.custom_minimum_size = Vector2(0, maxf(0.0, spacer_h))
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_child(spacer)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_child(content)
	scroll.add_child(rows)

	# the banner overlays the TOP (added after the scroll → drawn on top), draggable
	var header := _banner(banner_text, banner_font, banner_h, width, banner_icon_on, banner_icon, banner_icon_pos, banner_text_x, banner_text_y, banner_burn)
	header.position = banner_pos
	inner.add_child(header)

	# the ✕ disc poles past the card's top-right corner. The game passes on_close; the workbench prints.
	var close_cb: Callable = on_close if on_close.is_valid() else (func() -> void: print("WORKBENCH: dialog closed"))
	var close := _close_button(close_size, close_cb)
	wrap.add_child(close)

	# ONE relayout: cap the content height (so it scrolls behind the banner), size the wrap to the card
	# so the gallery centres it, and dock the ✕.
	var relayout := func() -> void:
		if not (is_instance_valid(inner) and is_instance_valid(rows) and is_instance_valid(card) and is_instance_valid(close)):
			return
		inner.custom_minimum_size.y = (minf(rows.size.y, banner_h + list_max_h) if list_max_h > 0.0 else rows.size.y)
		wrap.custom_minimum_size = card.size
		close.position = Vector2(card.size.x - close_size + close_poke.x, -close_poke.y)
	rows.resized.connect(relayout)
	rows.ready.connect(relayout)
	card.resized.connect(relayout)
	relayout.call_deferred()
	return wrap

## The MAIL dialog — the shared frame with a column of mail_cards (or an empty note) as its content.
static func mail_dialog(entries: Array, width: float = 560.0, opts: Dictionary = {}) -> Control:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	var entries_count: int = int(opts.get("entries_count", entries.size()))
	if entries.is_empty() or maxi(0, entries_count) == 0:
		var empty_text: String = String(opts.get("empty_text", ""))
		if empty_text != "":
			var empty := Label.new()
			empty.text = empty_text
			empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			empty.add_theme_font_size_override("font_size", 17)
			empty.add_theme_color_override("font_color", Color(Pal.BARK, 0.9))
			empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
			content.add_child(empty)
	else:
		var card_title: int = int(opts.get("card_title", 20))
		var card_body: int = int(opts.get("card_body", 15))
		var btn_opts: Dictionary = opts.get("btn", {})
		var icon_badge: String = String(opts.get("icon_badge", "shared/disc_round.png"))
		for i in maxi(0, entries_count):
			content.add_child(mail_card(entries[i % entries.size()], card_title, card_body, btn_opts, icon_badge))
	return dialog_frame(content, width, opts)

## A small kit sprite (the ✓ check, the mystery chest, …) cleaned + fit into a px box.
static func _kit_sprite(rel: String, px: float) -> TextureRect:
	var t := TextureRect.new()
	t.texture = clean_tex_path(Look.kit(rel), 256)
	t.custom_minimum_size = Vector2(px, px)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

## A day's headline reward: the most premium currency icon + its number (gems > coins > water).
static func _daily_reward(reward: Dictionary, px: float = 40.0) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 2)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_id := "coin"
	var n := 0
	if int(reward.get("gems", 0)) > 0:
		icon_id = "gem"; n = int(reward.gems)
	elif int(reward.get("coins", 0)) > 0:
		icon_id = "coin"; n = int(reward.coins)
	elif int(reward.get("water", 0)) > 0:
		icon_id = "water"; n = int(reward.water)
	elif String(reward.get("cosmetic", "")) != "":
		icon_id = "star"
	row.add_child(make_icon(icon_id, px))
	if n > 0:
		var l := Label.new()
		l.text = str(n)
		l.add_theme_font_size_override("font_size", int(px * 0.42))
		l.add_theme_color_override("font_color", Pal.INK)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(l)
	return row

## The shared SMALL CARD — one tile used by BOTH the Daily grid and the Shop grid (improve once, both
## benefit). Top→bottom: an optional POPULAR ribbon ("Popular"/"Best value"/…), an optional label
## ("Day N"), the main content (a reward dict · the mystery chest · OR a shop icon + count), and an
## action (the GREEN shared pill_button as a Claim or a price, ✓ when done, or nothing). today/milestone
## wear a configurable rim/glow. d keys: label/day, ribbon, reward|icon(+count)|mystery, state, price,
## claim_text, on_claim, on_buy.
static func daily_card(d: Dictionary, opts: Dictionary = {}) -> Control:
	var cw: float = float(opts.get("cell_w", 96.0))
	var ch: float = float(opts.get("cell_h", 116.0))
	var state := String(d.get("state", "future"))
	var milestone := bool(d.get("mystery", false))
	var btn_opts: Dictionary = opts.get("btn", {})
	var ribbon := String(d.get("ribbon", ""))
	# the highlight rim/glow: today + a milestone day wear configurable ones; everything else is plain
	var badge := "plain"
	if state == "today":
		badge = String(opts.get("today_badge", "gold glow"))
	elif milestone:
		badge = String(opts.get("milestone_badge", "amber glow"))
	if state == "today":
		ch *= float(opts.get("today_grow", 1.0))   # off by default — the 3-row grid keeps even rows

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(cw, ch)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bgp := Look.kit("kit/daily_card.png")
	if bool(opts.get("cell_art", true)) and ResourceLoader.exists(bgp):
		var st := StyleBoxTexture.new()
		st.texture = clean_tex_path(bgp, 256)
		st.set_texture_margin_all(float(opts.get("cell_slice", 28.0)))
		st.content_margin_left = 8; st.content_margin_right = 8
		st.content_margin_top = 7; st.content_margin_bottom = 7
		panel.add_theme_stylebox_override("panel", st)
	else:
		var cf := StyleBoxFlat.new()
		cf.bg_color = Color(Pal.CREAM, 0.85)
		cf.set_corner_radius_all(12); cf.set_border_width_all(1); cf.border_color = Color(Pal.BARK, 0.4)
		cf.content_margin_left = 8; cf.content_margin_right = 8
		cf.content_margin_top = 7; cf.content_margin_bottom = 7
		panel.add_theme_stylebox_override("panel", cf)
	if state == "done":
		panel.modulate = Color(1, 1, 1, 0.6)

	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(v)

	# the POPULAR ribbon (a merchandising tag) — used by shop packs, available to any card
	if ribbon != "":
		var rb := _ribbon_badge(ribbon)
		rb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(rb)

	# the label ("Day N") when present (daily); shop packs omit it
	if d.has("label") or d.has("day"):
		var dl := Label.new()
		dl.text = String(d.get("label", "Day %d" % int(d.get("day", 1))))
		dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dl.add_theme_font_size_override("font_size", int(opts.get("cell_font", 15)))
		dl.add_theme_color_override("font_color", Pal.INK if state != "today" else Pal.LEAF.darkened(0.15))
		dl.add_theme_constant_override("outline_size", 0)
		dl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(dl)

	# the main content — the mystery chest · a reward dict (daily) · or a big icon + count (shop)
	if milestone:
		v.add_child(_kit_sprite("kit/daily_chest.png", cw * 0.52))
	elif d.has("reward"):
		v.add_child(_daily_reward(d.get("reward", {}), cw * 0.42))
	elif d.has("icon"):
		v.add_child(make_icon(String(d.icon), cw * 0.48))
		if int(d.get("count", 0)) > 0:
			var cn := Label.new()
			cn.text = str(int(d.count))
			cn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cn.add_theme_font_size_override("font_size", int(opts.get("count_font", 17)))
			cn.add_theme_color_override("font_color", Pal.INK)
			cn.add_theme_constant_override("outline_size", 0)
			cn.mouse_filter = Control.MOUSE_FILTER_IGNORE
			v.add_child(cn)

	# the action — a price (shop) or a Claim (today) is the GREEN shared button; a done day shows ✓
	var act_text := ""
	var act_cb := Callable()
	if d.has("price"):
		act_text = String(d.price); act_cb = d.get("on_buy", Callable())
	elif state == "today":
		act_text = String(d.get("claim_text", "Claim")); act_cb = d.get("on_claim", Callable())
	if act_text != "":
		var co := btn_opts.duplicate()
		co["bg"] = "green"; co["text"] = act_text; co["icon"] = ""
		co["font"] = int(opts.get("claim_font", 15))
		var btn := pill_button(act_text, co)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		if act_cb.is_valid():
			btn.pressed.connect(func() -> void: act_cb.call())
		v.add_child(btn)
	elif state == "done":
		v.add_child(_kit_sprite("kit/daily_check.png", cw * 0.34))

	_apply_day_badge(panel, badge)   # the configurable rim/glow on today + milestone cards
	return panel

## The POPULAR ribbon — a small merchandising tag ("Popular" / "Best value" / …). The red shop_tag art
## (cream text) when present, else a code STRAW pill (ink text). Mirrors the game shop's _badge.
static func _ribbon_badge(text: String) -> Control:
	var pop := PanelContainer.new()
	pop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fg := Pal.CREAM
	var tex := clean_tex_path(Look.kit("kit/shop_tag.png"), 256)
	if tex != null:
		var stx := StyleBoxTexture.new()
		stx.texture = tex
		stx.content_margin_left = 15; stx.content_margin_right = 15
		stx.content_margin_top = 5; stx.content_margin_bottom = 8
		pop.add_theme_stylebox_override("panel", stx)
	else:
		var pp := StyleBoxFlat.new()
		pp.bg_color = Pal.STRAW
		pp.set_corner_radius_all(8)
		pp.content_margin_left = 10; pp.content_margin_right = 10
		pp.content_margin_top = 3; pp.content_margin_bottom = 4
		pop.add_theme_stylebox_override("panel", pp)
		fg = Pal.INK
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", fg)
	l.add_theme_constant_override("outline_size", 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pop.add_child(l)
	return pop

## Draw a highlight rim/glow over a day card (see DAY_BADGES). A code-drawn border-only overlay (plus a
## coloured shadow for the "glow" styles) so it's a SAVED setting the workbench can switch, not baked art.
static func _apply_day_badge(panel: Control, key: String) -> void:
	if key == "" or key == "plain":
		return
	var hi := Panel.new()
	hi.set_anchors_preset(Control.PRESET_FULL_RECT)
	hi.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := StyleBoxFlat.new()
	s.draw_center = false
	s.set_corner_radius_all(16)
	s.set_border_width_all(3)
	var gold := Pal.STRAW
	var amber := Color("#E0922E")
	match key:
		"gold rim":
			s.border_color = gold
		"gold glow":
			s.border_color = gold
			s.shadow_color = Color(gold, 0.55); s.shadow_size = 9
		"amber glow":
			s.border_color = amber
			s.shadow_color = Color(amber, 0.50); s.shadow_size = 9
		"leaf glow":
			s.border_color = Pal.LEAF
			s.shadow_color = Color(Pal.LEAF, 0.50); s.shadow_size = 9
		_:
			s.border_color = gold
	hi.add_theme_stylebox_override("panel", s)
	panel.add_child(hi)

## A centred GRID of the shared small cards (cols per row) — the content for the daily + shop dialogs.
static func _card_grid(cards: Array, opts: Dictionary) -> Control:
	var cols: int = maxi(1, int(opts.get("cols", 3)))
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", int(opts.get("cell_v_gap", 12)))
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var i := 0
	while i < cards.size():
		var r := HBoxContainer.new()
		r.alignment = BoxContainer.ALIGNMENT_CENTER          # a partial last row (e.g. Day 7) centres
		r.add_theme_constant_override("separation", int(opts.get("cell_h_gap", 12)))
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for j in cols:
			if i + j < cards.size():
				r.add_child(daily_card(cards[i + j], opts))
		content.add_child(r)
		i += cols
	return content

## The DAILY-GIFTS dialog — the shared frame with a grid of day cards.
static func daily_dialog(days: Array, width: float = 460.0, opts: Dictionary = {}) -> Control:
	return dialog_frame(_card_grid(days, opts), width, opts)

## The SHOP dialog — the SAME shared frame with a grid of the SAME small card, here carrying an
## icon + count + a price button and Popular ribbons (no day label, no claim). Shared frame, new content.
static func shop_dialog(items: Array, width: float = 520.0, opts: Dictionary = {}) -> Control:
	return dialog_frame(_card_grid(items, opts), width, opts)

## --- config → opts (the SINGLE source of the params→opts transform) ------------------------------
## The workbench saves design settings to a JSON of {button, card, dialog, icon} param dicts. Both the
## workbench preview AND the game build their dialog from these helpers, so there is no duplicated
## transform: change a setting in the workbench, save, and the game reads the very same config.

## Read the saved settings JSON into a config dict ({} if missing/garbage — callers fall back to defaults).
static func load_config(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	return data if data is Dictionary else {}

## The Claim / cost-pill STYLE opts: the Button's saved style (shadow / art / font / corner) + the
## Card's own badge, icon and claim label. (bg is NOT here — the kit fixes it by role: green Claim,
## cream cost pill.) Every key falls back to a default so a partial/empty config still builds.
static func card_btn_opts(cfg: Dictionary) -> Dictionary:
	var b: Dictionary = cfg.get("button", {})
	var c: Dictionary = cfg.get("card", {})
	var o := {
		"text": String(c.get("claim_text", "Claim")),
		"icon": (String(c.get("icon", "gem")) if bool(c.get("icon_on", false)) else ""),
		"icon_size": int(b.get("icon_size", 30)),
		"enabled": true,
		"font": int(b.get("font", 22)),
		"corner": int(b.get("corner", 16)),
		"art": bool(b.get("art", true)),
		"shadow": bool(b.get("shadow", false)),
	}
	var badge := String(c.get("badge", "auto"))
	if badge != "auto" and BADGES.has(badge) and String(BADGES[badge]) != "":
		o["art"] = true
		o["art_rel"] = String(BADGES[badge])
	return o

## The sprite (Look.kit-relative) for the Card's left-icon disc badge, resolved from the saved label.
static func card_icon_badge(cfg: Dictionary) -> String:
	var key := String((cfg.get("card", {}) as Dictionary).get("icon_badge", "disc light"))
	return String(ICON_BADGES.get(key, "shared/disc_round.png"))

## The SHARED FRAME's config section. It lives under "frame" now (its own standalone component); older
## saved files kept these keys under "dialog", so merge that as a fallback — the "frame" section wins.
static func _frame_cfg(cfg: Dictionary) -> Dictionary:
	var m: Dictionary = (cfg.get("dialog", {}) as Dictionary).duplicate()
	m.merge(cfg.get("frame", {}), true)
	return m

## The full mail_dialog STYLE opts from a saved config (card art/slice/stretch, banner, close, list,
## card fonts, and the Claim/cost-pill btn opts). Callers add entries_count / on_close / empty_text /
## banner_text and pass width separately. Used by BOTH the workbench dialog preview and the game.
static func dialog_opts_from_config(cfg: Dictionary) -> Dictionary:
	var d: Dictionary = _frame_cfg(cfg)
	var c: Dictionary = cfg.get("card", {})
	var strmap := {"stretch": 0, "tile": 1, "tile_fit": 2}
	return {
		"card_corner": float(d.get("card_corner", 22)),
		"card_art": bool(d.get("card_art", true)),
		"card_slice_l": float(d.get("card_slice_l", 40)),
		"card_slice_t": float(d.get("card_slice_t", 40)),
		"card_slice_r": float(d.get("card_slice_r", 40)),
		"card_slice_b": float(d.get("card_slice_b", 40)),
		"card_h_stretch": int(strmap.get(String(d.get("card_h_stretch", "stretch")), 0)),
		"card_v_stretch": int(strmap.get(String(d.get("card_v_stretch", "stretch")), 0)),
		"card_title": int(c.get("title", 20)),
		"card_body": int(c.get("body", 15)),
		"banner_font": int(d.get("banner_font", 32)),
		"banner_h": float(d.get("banner_h", 92)),
		"banner_icon": float(d.get("banner_icon", 54)),
		"banner_icon_on": bool(d.get("banner_icon_on", true)),
		"banner_text_x": float(d.get("banner_text_x", 0)),
		"banner_text_y": float(d.get("banner_text_y", 0)),
		"banner_burn": float(d.get("banner_burn", 0)) / 100.0,
		"banner_pos": Vector2(float(d.get("banner_x", 0)), float(d.get("banner_y", 0))),
		"banner_icon_pos": Vector2(float(d.get("banner_icon_x", 130)), float(d.get("banner_icon_y", 19))),
		"close_size": float(d.get("close_size", 64)),
		"close_poke": Vector2(float(d.get("close_x", 12)), float(d.get("close_y", 12))),
		"list_max_h": float(d.get("list_max_h", 0)),
		"list_top_pad": float(d.get("list_top_pad", 0)),
		"icon_badge": card_icon_badge(cfg),
		"btn": card_btn_opts(cfg),
	}

## The day-CARD opts from config (cell size/art + the today/milestone highlight badges). The daily card
## is its OWN component (defined separately), so both the card preview AND the dialog read it from here.
static func daily_card_opts_from_config(cfg: Dictionary) -> Dictionary:
	var dc: Dictionary = cfg.get("daily_card", {})
	return {
		"cell_w": float(dc.get("cell_w", 96)),
		"cell_h": float(dc.get("cell_h", 116)),
		"cell_slice": float(dc.get("cell_slice", 28)),
		"cell_art": bool(dc.get("cell_art", true)),
		"today_badge": String(dc.get("today_badge", "gold glow")),
		"milestone_badge": String(dc.get("milestone_badge", "amber glow")),
		"btn": card_btn_opts(cfg),
	}

## The full DAILY-dialog opts: the SHARED frame + the separately-defined day card + the dialog-level
## grid (cols, default 3 — the 3-per-row reference layout). Used by the workbench + the game.
static func daily_opts_from_config(cfg: Dictionary) -> Dictionary:
	var o := dialog_opts_from_config(cfg)
	o.merge(daily_card_opts_from_config(cfg), true)
	o["cols"] = int((cfg.get("daily", {}) as Dictionary).get("cols", 3))
	return o

## The SHOP-dialog opts: the SHARED frame + the SAME small card + the shop grid (cols, larger cells for
## the icon+count+price layout). Same construction as the daily — only the data + cell size differ.
static func shop_opts_from_config(cfg: Dictionary) -> Dictionary:
	var o := dialog_opts_from_config(cfg)
	o.merge(daily_card_opts_from_config(cfg), true)
	var sh: Dictionary = cfg.get("shop", {})
	o["cols"] = int(sh.get("cols", 3))
	o["cell_w"] = float(sh.get("cell_w", 112))
	o["cell_h"] = float(sh.get("cell_h", 150))
	return o

## The default config-file location the workbench writes (the single source of truth the game reads).
const CONFIG_PATH := "res://games/grove/tools/ui_workbench_settings.json"
