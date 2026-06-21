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
const Sparkle = preload("res://games/grove/tools/sparkle.gd")   # the code-drawn twinkle overlay

# Nine-patch margins for the shared mail kit (sourced from the real recipe in inbox.gd).
const CARD_TEX := Vector2(30, 30)
const CARD_PAD := Vector4(18, 12, 18, 12)
const PILL_TEX := Vector2(46, 34)
const PILL_PAD := Vector4(14, 6, 14, 6)
const CLAIM_PAD := Vector4(24, 8, 24, 8)
const BANNER_H := 92.0

# The top-bar CURRENCY PILL (the ★ 🪙 💎 wallet cluster). The painted background is a nine-patch
# CAPSULE; CUR_PILL_CAP is the cap radius the corners draw 1:1 at. The colours mirror the code-drawn
# fallback in hud.gd (Tune.Hud.PILL_*) so "use art = off" matches the shipped pill. The per-currency
# optical scales mirror Tune so the preview reads at the same weight as the live HUD.
const CUR_PILL_ART := "shared/panel_pill.png"
const CUR_PILL_CAP := 32
# The pill's selectable BORDER art — a reusable registry (mirrors FRAME_BORDERS) so the Currency pill
# item's Border picker dresses the SAME pill in a different painted capsule. Each entry carries the
# nine-patch art + its cap (texture margin ≈ the rounded-end radius, so the caps draw 1:1 and the flat
# middle stretches to the counts). "gold capsule" is the SHIPPED default, so an unset border is unchanged.
const PILL_BORDERS := {
	"gold capsule": {"art": CUR_PILL_ART,          "cap": CUR_PILL_CAP},   # shared/panel_pill.png (292×65)
	"bag":          {"art": "kit/bag_pill.png",       "cap": 59},          # 416×118
	"bag thin":     {"art": "kit/bag_pill_thin.png",  "cap": 33},          # 411×66
	"bag blue":     {"art": "kit/bag_pill_b.png",     "cap": 58},          # 416×116
	"bag green":    {"art": "kit/bag_pill_green.png", "cap": 59},          # 416×118
	"mail":         {"art": "kit/mail_pill.png",      "cap": 38},          # 220×77
	"mail cream":   {"art": "kit/mail_pill_cream.png","cap": 38},          # 180×76
}

## Resolve a pill-border NAME to its {art, cap} record (unknown → gold capsule, so a stale saved value
## never blanks the wallet).
static func pill_border(name: String) -> Dictionary:
	return PILL_BORDERS.get(name, PILL_BORDERS["gold capsule"])

const CUR_PILL_BG := Color("#FBF6EC", 0.95)
const CUR_PILL_BORDER := Color("#C9A66B", 0.9)
const CUR_PILL_SHADOW := Color(0, 0, 0, 0.22)
# id → the rendered sprite px (Tune.Hud gsize × optical: star 44×0.86, coin/gem 40×1.0). The sprite is
# centered in the `icon_box`-sized square, exactly as hud.gd's _icon_box does, so the preview matches.
const CUR_PILL_ICONS := [["star", 38.0], ["coin", 40.0], ["gem", 40.0]]

# The map-SELECT place-picker CARD (spec §8 "the horizon — visible AND veiled"). An OPEN place wears
# the glowing gold frame (ui/map/card_active.png) over its locale art + a "★ N left"/"restored" pill;
# a LOCKED place is the dark baked panel (ui/map/card_locked.png) under an "after <prev>" line. Code-
# drawn fallbacks (gold rim · meadow fill · §8 fog veil) keep the picker from blanking when an asset is
# missing. The GAME (map.gd) resolves each card's DATA (art path · open/locked · counts · prereq) and
# passes it in `d`; every presentation dial lives in `opts` (map_card_opts_from_config) so the workbench
# tunes it and the game reads the SAME recipe — the single-source-of-truth pattern the currency pill uses.
const MAP_CARD_ACTIVE := "map/card_active.png"     # unlocked card's glowing gold frame
const MAP_CARD_LOCKED := "map/card_locked.png"     # locked card's dark baked panel (lock medallion baked in)
const MAP_CARD_PILL := "map/pill_left.png"         # the cream count pill on an open card's lower edge
const MAP_CARD_ASPECT := 1027.0 / 352.0            # card_active's aspect — cards size to it so the frame never distorts
const MAP_CARD_PILL_ASPECT := 293.0 / 102.0        # pill_left's aspect
const MAP_VEIL_NODE := "Veil"                       # the locked-card fog overlay's name (mapfx_tests asserts it)
const MAP_VEIL_ART := "map/veil.png"               # generic painted-veil seam (per-map: veil_<id>.png)
# Draws the locale art COVER-fitted to fill the card, masked to the gold frame's EXACT silhouette so it
# never leaks past the rounded corners. The mask (`_map_silhouette_tex`) is the frame flood-filled from its
# borders, so the art shows only inside the gold body + the enclosed hole — never in the transparent corner
# gaps, edge margin, or glow. Runs on a ColorRect whose UV spans the card [0,1], the same space as the
# frame TextureRect, so the mask lines up 1:1. (The old shader rounded corners with a guessed radius — it
# could never match the frame's real, sparkle-decorated corner, so the art leaked.) `art` is the locale
# texture, `tex_px` drives the COVER crop over `rect_px`, `mask` is the frame silhouette.
const MAP_ART_CLIP_SHADER := "shader_type canvas_item;
uniform sampler2D art : filter_linear;
uniform sampler2D mask : filter_linear;
uniform vec2 tex_px = vec2(1.0);
uniform vec2 rect_px = vec2(1.0);
void fragment() {
	float cover = max(rect_px.x / tex_px.x, rect_px.y / tex_px.y);
	vec2 disp = tex_px * cover;                 // art scaled to COVER the card
	vec2 off = (disp - rect_px) * 0.5;          // centred crop
	vec2 p = UV * rect_px;                       // pixel position within the card
	vec4 col = texture(art, (p + off) / disp);   // COVER sample
	col.a *= texture(mask, UV).a;                // clip to the gold frame's exact silhouette
	COLOR = col;
}"
static var _map_art_clip: Shader
static var _map_sil_tex: Texture2D = null         # cached gold-frame silhouette mask (flood-filled)
static var _map_meadow_tex: Texture2D = null      # cached 1x1 MEADOW texture for the art-less fallback

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
	"level green": "kit/level_btn.png",
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

# Demo discovery ladder (12 tiers) for the workbench preview — same shape the game builds from a line's
# Quests.ladder_entries: {tier, seen, marked, icon|node}. A SEEN tier shows its content (here a stand-in
# icon; the game passes a real merge-piece node), an UNSEEN tier the baked "?" cell, one tier is marked
# (the tapped/asked tier — flagged by the sparkle, not a bigger cell). Discovered up to tier 6, mirroring tiers.png.
const DEMO_TIERS := [
	{"tier": 1, "seen": true, "icon": "leaf"},
	{"tier": 2, "seen": true, "icon": "leaf"},
	{"tier": 3, "seen": true, "icon": "daisy"},
	{"tier": 4, "seen": true, "icon": "daisy"},
	{"tier": 5, "seen": true, "icon": "daisy"},
	{"tier": 6, "seen": true, "icon": "daisy", "marked": true},
	{"tier": 7, "seen": false},
	{"tier": 8, "seen": false},
	{"tier": 9, "seen": false},
	{"tier": 10, "seen": false},
	{"tier": 11, "seen": false},
	{"tier": 12, "seen": false},
]

# Demo settings rows for the workbench preview — the SAME shape the game builds from save.gd's
# persisted flags (engine/scripts/ui/settings.gd): a label + an on/off value. on_toggle is supplied
# by the caller (the game persists; the workbench just previews the flip).
const DEMO_SETTINGS := [
	{"label": "Music", "value": false},
	{"label": "Sounds", "value": true},
	{"label": "Calm mode", "value": false},
]

# Demo vault state for the workbench preview — same shape the game builds from core/vault.gd (the
# accrual jar's balance/cap + the fixed price + the claim gate). balance/claimable are preview-only.
const DEMO_VAULT := {"balance": 320, "cap": 500, "price": "$4.99", "claimable": true, "claim_min": 100}

## The GAME shop's items, faithfully from Game.DATA, grouped into the SAME 3 sections the real
## storefront uses (engine/scripts/ui/shop.gd) — each a {caption, cards} dict the shop dialog draws under
## a vine divider. Quick help is a 2-card row; Featured is a 3-card row; Acorn pouches is the gem ladder.
## Only the ITEMS (icon / amount / price / ribbon); the card STYLING is the shared small card.
static func demo_shop() -> Array:
	var D := Game.DATA
	# Quick help — refill water + a coin pouch (a row of just TWO), both paid in gems
	var help: Array = [
		{"icon": "water", "label": "Fill water", "price": str(int(D.REFILL_DIAMOND_COST)), "price_icon": "gem"},
		{"icon": "coin", "label": "Coin pouch", "count": 150, "price": "5", "price_icon": "gem"},
	]
	# Featured — the item-shortcut offers (coins or 💎)
	var featured: Array = []
	for off in D.SHOP_ITEM_OFFERS:
		featured.append({
			"icon": String(off.get("icon", "star")),
			"label": String(off.get("label", "")),
			"price": str(int(off.get("cost", 0))),
			"price_icon": ("gem" if String(off.get("currency", "coins")) == "diamonds" else "coin"),
		})
	# Acorn pouches — the cash → gems ladder (a 3-wide grid; the merchandised packs wear ribbons)
	var packs: Array = []
	for i in (D.CASH_PACKS as Array).size():
		var pk: Dictionary = D.CASH_PACKS[i]
		var card := {"icon": "gem", "count": int(pk.get("gems", 0)), "price": String(pk.get("usd", ""))}
		if bool(pk.get("pop", false)):
			card["ribbon"] = "Popular"               # the merchandised mid anchor
		elif i == (D.CASH_PACKS as Array).size() - 1:
			card["ribbon"] = "Best value"            # the whale tier (best rate)
		packs.append(card)
	return [
		{"caption": "Quick help", "cards": help},
		{"caption": "Featured", "cards": featured},
		{"caption": "Acorn pouches", "cards": packs},
	]

## Resolve an icon id to a real sprite Control. Most ids ride the shared Look.icon; "bluegem" is the
## faceted premium gem (not the grove's acorn), loaded directly.
static func make_icon(id: String, px: float) -> Control:
	var node := _icon_rect(_icon_tex(id), px)   # polished (defringe + feather), via the shared resolver
	return node if node != null else Look.icon(id, px)   # glyph fallback when no sprite

## A polished texture wrapped as the SHARED icon rect: a centred, mouse-transparent square that fills its
## box by its own aspect. Returns null when the texture is absent (the caller supplies the glyph fallback).
## make_icon (id lookup) and home_button's icon_rel (direct kit path) both build through this one layout.
static func _icon_rect(tex: Texture2D, px: float) -> Control:
	if tex == null:
		return null
	var t := TextureRect.new()
	t.texture = tex
	t.custom_minimum_size = Vector2(px, px)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

## The home button's BADGE (disc shell) as a texture, with its own tunable edge polish — the standalone
## Badge workbench item edits `polish` (defringe / feather / shadow) and the home button reads it, so a
## badge tweak flows to the rail + nav automatically. No polish → the raw (already-clean) shell sprite.
## `polish` keys: defringe (bool), feather (px), shadow (bool) + the add_drop_shadow knobs.
static var _shell_cache: Dictionary = {}    # "rel@<polish-json>" -> polished disc texture (per session)
const SHELL_CAP := 256                       # clean_tex_path cap for a baked disc shell (≈1.8x its 140px display)

static func shell_texture(rel: String, polish: Dictionary = {}) -> Texture2D:
	var path := Look.kit(rel)
	if rel == "" or not ResourceLoader.exists(path):
		return null
	var defr := bool(polish.get("defringe", false))
	var feat := float(polish.get("feather", 0.0))
	var shad := bool(polish.get("shadow", false))
	if not defr and feat <= 0.0 and not shad:
		return load(path)                       # untouched → the raw shell (already cleaned at intake)
	# Exactly the bakeable clean recipe (defringe + feather 2 + no shadow = the shipped home-button
	# config)? Route through clean_tex_path so the disc loads PRE-BAKED (bake_targets builds the chrome)
	# instead of paying the ~190ms live pass on every cold boot. Any richer polish (a drop shadow, a
	# different feather) still takes the live _polish_icon_aspect path below.
	if defr and is_equal_approx(feat, 2.0) and not shad:   # 2.0 = _clean_image's fixed feather
		return clean_tex_path(path, SHELL_CAP)
	# The polished disc is IDENTICAL for every button sharing this (rel, polish) — the bottom nav + rail
	# build 5-8 of them per scene, and a map<->board swap rebuilds the whole row. The polish is a ~190ms
	# CPU pass (Lanczos resize + defringe + feather), so an uncached call multiplied that by every button
	# on every navigation (the swap freeze). Memoize it: only the FIRST build pays; the rest reuse the
	# texture (a Texture2D is meant to be shared). Cleared on a workbench Save (see clear_config_cache).
	var key := rel + "@" + JSON.stringify(polish)
	if _shell_cache.has(key):
		return _shell_cache[key]
	var img := (load(path) as Texture2D).get_image()
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	var o := polish.duplicate()
	o["defringe"] = defr; o["feather"] = feat; o["shadow"] = shad; o["supersample"] = 1
	var tex := ImageTexture.create_from_image(_polish_icon_aspect(img, o))
	_shell_cache[key] = tex
	return tex

## Aspect-preserving icon polish (vs polish_image, which forces a SQUARE canvas): cap the working
## resolution keeping aspect, then defringe / feather / optional drop-shadow. Lets a tall or wide icon
## keep its proportions while still getting the edge cleanup the square polish_image gives gem.
static func _polish_icon_aspect(img: Image, opts: Dictionary) -> Image:
	var ss: int = clampi(int(opts.get("supersample", 2)), 1, 4)
	var w := img.get_width()
	var h := img.get_height()
	var m := maxi(w, h)
	var cap := mini(320, maxi(8, m * ss))
	if m != cap:
		var s := float(cap) / float(m)
		img.resize(maxi(1, int(w * s)), maxi(1, int(h * s)), Image.INTERPOLATE_LANCZOS)
	if bool(opts.get("defringe", false)):
		_defringe(img)
	var feather := float(opts.get("feather", 0.0))
	if feather > 0.0:
		_feather_alpha(img, feather)
	if bool(opts.get("shadow", false)):
		img = add_drop_shadow(img, opts)
	return img

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

## --- baked asset cleanup: defringe + feather 2, cached per (path, max_dim) ----------------------
## The defringe/feather is a per-pixel GDScript pass; running it live on first use is what hitches a
## dialog open (≈0.8s for the level screen's chrome). `make bake-textures` pre-runs the EXACT same
## _clean_image() offline into a `baked/<subpath>@<max>.png` mirror; clean_tex_path loads that when
## present, so the runtime pays only a plain texture load. A missing bake silently degrades to the
## live polish below — correct, just slower on first open.
static var _clean_cache: Dictionary = {}

## The baked-mirror path for a source sprite at a given cap: `baked/<subpath under the assets root>`
## with the cap tagged in the name (so one source baked at two caps stays two distinct files). A
## source outside the assets root flattens to just its filename. Used by BOTH the runtime lookup
## here and the bake tool, so the two always agree on where a baked file lives.
static func baked_path(src: String, max_dim: int) -> String:
	var root: String = Game.art("")
	var rel := src.substr(root.length()) if root != "" and src.begins_with(root) else src.get_file()
	var dir := rel.get_base_dir()
	var tail := "%s@%d.png" % [rel.get_file().get_basename(), max_dim]
	return Game.art("baked/" + (tail if dir == "" else dir + "/" + tail))

## Drop the cleaned-texture cache (tests / teardown). Mirrors clear_async_cache / clear_config_cache.
static func clear_clean_cache() -> void:
	_clean_cache.clear()

## A cleaned version of a sprite: defringe (kill the rough-cut colour fringe) + feather 2 (smooth the
## jagged edge). Cached by (path, max_dim) so it runs once per asset+cap. max_dim caps the working res.
static func clean_tex_path(path: String, max_dim: int = 256) -> Texture2D:
	if path == "" or not ResourceLoader.exists(path):
		return null
	var key := "%s@%d" % [path, max_dim]
	if _clean_cache.has(key):
		return _clean_cache[key]
	# pre-baked (make bake-textures): load the polished mirror directly — no per-pixel work.
	var bp := baked_path(path, max_dim)
	if ResourceLoader.exists(bp):
		var baked := load(bp) as Texture2D
		if baked != null:
			_clean_cache[key] = baked
			return baked
	# live fallback: defringe + feather on the main thread (the first-open cost the bake removes).
	var img := (load(path) as Texture2D).get_image()
	var t := ImageTexture.create_from_image(_clean_image(img, max_dim))
	_clean_cache[key] = t
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

## --- async (worker-thread) polish -----------------------------------------------------------------
## The defringe / feather / drop-shadow / Lanczos work is pure Image math (no scene-tree access), so it
## runs on a WorkerThreadPool thread — the workbench's polish sliders (icon / badge) stay responsive
## while a tweaked value bakes off the main thread. The caller loads the RAW source Image on the main
## thread (ResourceLoader isn't threaded here) and passes it in; results are cached by key.
## Texture creation (ImageTexture.create_from_image) stays on the main thread, in _async_poll.
static var _async_cache: Dictionary = {}    # key -> finished Texture2D
static var _async_tasks: Dictionary = {}    # key -> {task:int, holder:{img:Image}}

## Polished texture for `key`: cached -> return it; first call with a source -> dispatch the polish to a
## worker and return null (not ready). `aspect`=true keeps proportions (shell), false squares it (icon).
static func polish_async(key: String, src: Image, opts: Dictionary, aspect := false) -> Texture2D:
	if _async_cache.has(key):
		return _async_cache[key]
	if src == null:
		return null
	if not _async_tasks.has(key):
		var holder := {"img": null}
		var o: Dictionary = opts.duplicate()
		var feed: Image = src.duplicate()   # the worker owns its copy (aspect polish resizes in place)
		var task := WorkerThreadPool.add_task(func() -> void:
			holder["img"] = (_polish_icon_aspect(feed, o) if aspect else polish_image(feed, o)))
		_async_tasks[key] = {"task": task, "holder": holder}
	return _async_poll(key)

## Promote one finished task into the cache (main thread — creates the texture). Returns it or null.
static func _async_poll(key: String) -> Texture2D:
	if _async_cache.has(key):
		return _async_cache[key]
	var t = _async_tasks.get(key)
	if t == null or not WorkerThreadPool.is_task_completed(int(t["task"])):
		return null
	WorkerThreadPool.wait_for_task_completion(int(t["task"]))
	_async_tasks.erase(key)
	var img = (t["holder"] as Dictionary)["img"]
	if img is Image:
		var tex := ImageTexture.create_from_image(img)
		_async_cache[key] = tex
		return tex
	return null

## Drain every finished task into the cache; returns how many are still running. Call each frame while
## awaiting (a completed task that nobody polls would never leave _async_tasks).
static func pump_polish() -> int:
	for k in _async_tasks.keys():
		_async_poll(k)
	return _async_tasks.size()

static func polish_pending() -> int:
	return _async_tasks.size()

## The finished polished texture for `key`, or null if not cached yet — a cheap peek so a caller can skip
## loading the source image on a cache hit.
static func polished_cached(key: String) -> Texture2D:
	return _async_cache.get(key)

## Test/teardown — wait out in-flight tasks, then drop the cache.
static func clear_async_cache() -> void:
	for k in _async_tasks.keys():
		WorkerThreadPool.wait_for_task_completion(int(_async_tasks[k]["task"]))
	_async_tasks.clear()
	_async_cache.clear()

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
## Resolve an icon id to its raw sprite path ("" if none). "bluegem" is the faceted premium gem;
## coin*/gem* live in currency/, everything else in shared/ (with a currency/ fallback).
static func _icon_path(id: String) -> String:
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
			return p
	return ""

static func _icon_tex(id: String) -> Texture2D:
	var p := _icon_path(id)
	return clean_tex_path(p, 192) if p != "" else null      # defringe + feather the rough-cut icon

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

## --- the HOME BUTTON: the round icon button shared by the home page's side rail + bottom bar -------
## ONE configurable atom: a cream/gold disc shell (shared/disc_round.png) carrying a CENTRED icon, an
## OPTIONAL caption tab beneath, and an OPTIONAL engine-drawn SPARKLE (a soft pulsing glow + drifting
## twinkles — no baked FX). Badges are attached by the caller (Look.attach_badge) since their visibility
## is game-state driven. The side rail AND the bottom nav both build through this, so a workbench tweak
## (size · icon scale · caption · sparkle amount) flows to both.
##   spec (per-instance content): icon (id) OR icon_rel (a direct kit-relative png, for a mark outside the
##     icon_<id> convention — e.g. the map back arrow) · caption (visible tab text, "" = none) ·
##     action (Callable) · sparkle (bool) · enabled (bool).
##   opts (shared STYLE — see home_button_opts_from_config): px · shell · icon_scale (0..1) ·
##     caption_font · caption_gap · glow (0..1) · twinkle (0..1) · calm (bool).
const HOME_SHELL := "shared/disc_round.png"

static func home_button(spec: Dictionary, opts: Dictionary = {}) -> Button:
	var px: float = float(opts.get("px", 140.0))
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(px, px)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.disabled = not bool(spec.get("enabled", true))
	# the disc shell: the cream/gold sprite scaled WHOLE (a round disc 9-slices badly at its corners),
	# or a flat code-drawn cream disc when the art is missing (the kit invariant — same metrics either way).
	var shell_rel := String(opts.get("shell", HOME_SHELL))
	var shell: Texture2D = shell_texture(shell_rel, opts.get("badge", {}))   # the Badge item's tuned polish
	for st_name in ["normal", "hover", "pressed", "disabled"]:
		if shell != null:
			var stx := StyleBoxTexture.new()      # NO texture margins → the whole disc scales (no corner slice)
			stx.texture = shell
			if st_name == "pressed":
				stx.modulate_color = Color(0.9, 0.9, 0.9)
			elif st_name == "disabled":
				stx.modulate_color = Color(0.72, 0.72, 0.72)
			b.add_theme_stylebox_override(st_name, stx)
		else:
			var s := StyleBoxFlat.new()
			s.bg_color = Color(Pal.CREAM, 0.95)
			s.set_corner_radius_all(int(px * 0.5))
			s.set_border_width_all(3)
			s.border_color = Pal.STRAW
			b.add_theme_stylebox_override(st_name, s)
	# the SPARKLE sits BEHIND the icon (added first → drawn under it), only if asked AND tuned > 0.
	if bool(spec.get("sparkle", false)):
		var glow: float = float(opts.get("glow", 0.0))
		var tw: float = float(opts.get("twinkle", 0.0))
		if glow > 0.0 or tw > 0.0:
			b.add_child(_sparkle_overlay(px, glow, tw, bool(opts.get("calm", false))))
	# the kit icon, centred on the disc (mouse-transparent so the Button is the only hit surface). The icon
	# gets the SHARED global polish (make_icon → _icon_tex's defringe + feather) — its own clean recipe.
	var icwrap := CenterContainer.new()
	icwrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	icwrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_px := px * float(opts.get("icon_scale", 0.5))
	# icon_rel (a direct kit-relative png) wins over the icon id — same polish + square layout either way.
	var icon_rel := String(spec.get("icon_rel", ""))
	var icon_node: Control = _icon_rect(clean_tex_path(Look.kit(icon_rel), 192), icon_px) if icon_rel != "" else make_icon(String(spec.get("icon", "")), icon_px)
	if icon_node != null:
		icwrap.add_child(icon_node)
	b.add_child(icwrap)
	# the OPTIONAL caption tab, centred just beneath the disc (overflows into the gap below)
	var caption := String(spec.get("caption", ""))
	if caption != "":
		var cap_font := int(opts.get("caption_font", 22))
		var capwrap := CenterContainer.new()
		capwrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		capwrap.anchor_left = 0.0; capwrap.anchor_right = 1.0
		capwrap.anchor_top = 1.0; capwrap.anchor_bottom = 1.0
		capwrap.offset_top = float(opts.get("caption_gap", 4.0))
		capwrap.offset_bottom = capwrap.offset_top + cap_font + 22.0
		var cap := Look.title_ribbon(caption, cap_font)
		cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if cap.get_child_count() > 0:
			(cap.get_child(0) as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		capwrap.add_child(cap)
		b.add_child(capwrap)
	Look.add_press_juice(b)
	if spec.has("action") and (spec.get("action") as Callable).is_valid():
		b.pressed.connect(spec.get("action"))
	return b

## --- the HOME UNLOCK BUTTON: the round restore-cost disc on an unowned home spot -----------------
## A sibling of the home button: the dashed cream cost disc (map/badge_cost.png) carrying a centred "+"
## stacked over the cost row (a currency icon + the number). The map's unowned spots build through this,
## so a workbench tweak (disc size · "+" scale · icon scale · cost font · gaps) flows to the live map.
##   spec (per-instance content): cost (int) · icon (currency id; "star") · action (Callable) · enabled.
##   opts (shared STYLE — see home_unlock_opts_from_config): px (diameter, set by the caller) ·
##     plus_scale / icon_scale / cost_font / stack_gap / icon_gap (all 0..1 fractions of the disc).
const HOME_UNLOCK_SHELL := "map/badge_cost.png"
const HOME_UNLOCK_INK := Color("#6E4E25")   # the engraved brown of the "+" and the cost number

static func home_unlock_button(spec: Dictionary, opts: Dictionary = {}) -> Button:
	var px: float = float(opts.get("px", 173.0))
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(px, px)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.disabled = not bool(spec.get("enabled", true))
	# the cost disc: the sliced round badge sprite scaled WHOLE (a round disc 9-slices badly), or a flat
	# code-drawn cream disc when the art is missing (the kit invariant — same metrics either way).
	var shell_path := Look.kit(HOME_UNLOCK_SHELL)
	var shell: Texture2D = load(shell_path) if ResourceLoader.exists(shell_path) else null
	for st_name in ["normal", "hover", "pressed", "disabled"]:
		if shell != null:
			var stx := StyleBoxTexture.new()      # NO texture margins → the whole disc scales (no corner slice)
			stx.texture = shell
			if st_name == "pressed":
				stx.modulate_color = Color(0.9, 0.9, 0.9)
			elif st_name == "disabled":
				stx.modulate_color = Color(0.72, 0.72, 0.72)
			b.add_theme_stylebox_override(st_name, stx)
		else:
			var s := StyleBoxFlat.new()
			s.bg_color = Color(Pal.CREAM, 0.95)
			s.set_corner_radius_all(int(px * 0.5))
			s.set_border_width_all(3)
			s.border_color = Pal.STRAW
			b.add_theme_stylebox_override(st_name, s)
	# the SPARKLE sits BEHIND the +/cost (added first → drawn under), only if asked AND tuned > 0 — the
	# same engine-drawn glow + twinkles the home button uses (no baked art). calm freezes it.
	if bool(spec.get("sparkle", false)):
		var glow: float = float(opts.get("glow", 0.0))
		var tw: float = float(opts.get("twinkle", 0.0))
		if glow > 0.0 or tw > 0.0:
			b.add_child(_sparkle_overlay(px, glow, tw, bool(opts.get("calm", false))))
	# the "+" stacked over the cost row, centred on the disc (mouse-transparent so the Button is the only
	# hit surface). All metrics are fractions of the disc, so the stack scales with px.
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", int(round(px * float(opts.get("stack_gap", -0.01)))))
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(col)
	var plus := Label.new()
	plus.text = "+"
	plus.add_theme_font_size_override("font_size", maxi(1, int(px * float(opts.get("plus_scale", 0.30)))))
	plus.add_theme_color_override("font_color", HOME_UNLOCK_INK)
	plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(plus)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", maxi(0, int(round(px * float(opts.get("icon_gap", 0.02))))))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(row)
	var ic := Look.icon(String(spec.get("icon", "star")), px * float(opts.get("icon_scale", 0.26)))
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(ic)
	var lbl := Label.new()
	lbl.text = "%d" % int(spec.get("cost", 0))
	lbl.add_theme_font_size_override("font_size", maxi(1, int(px * float(opts.get("cost_font", 0.26)))))
	lbl.add_theme_color_override("font_color", HOME_UNLOCK_INK)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lbl)
	Look.add_press_juice(b)
	if spec.has("action") and (spec.get("action") as Callable).is_valid():
		b.pressed.connect(spec.get("action"))
	return b

## The engine-drawn SPARKLE overlay: a soft additive GLOW that gently breathes + drifting 4-point
## TWINKLES (a continuous GPUParticles2D), both code-generated (no baked art). glow / twinkle are 0..1
## amounts (the workbench sliders); calm freezes it to a static glow with no twinkles (reduced-motion).
static func _sparkle_overlay(px: float, glow: float, twinkle: float, calm: bool) -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if glow > 0.0:
		var hsz := px * 1.7
		var gtex := _glow_texture()
		# one soft radial halo, twice: a NORMAL-blend warm tint first (so the glow reads on LIGHT
		# backgrounds — additive has no headroom on the near-white disc / bright map), then the ADDITIVE
		# bloom on top (which pops on DARK backgrounds: the workbench panel, dusk maps). g is 0..1.
		var make_halo := func(additive: bool, alpha: float) -> TextureRect:
			var h := TextureRect.new()
			h.texture = gtex
			h.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			h.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			h.mouse_filter = Control.MOUSE_FILTER_IGNORE
			h.custom_minimum_size = Vector2(hsz, hsz)
			h.size = Vector2(hsz, hsz)
			h.position = Vector2((px - hsz) / 2.0, (px - hsz) / 2.0)
			if additive:
				var m := CanvasItemMaterial.new()
				m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
				h.material = m
			h.modulate = Color(1, 1, 1, clampf(glow, 0.0, 1.0) * alpha)
			root.add_child(h)
			return h
		make_halo.call(false, 0.45)                              # warm tint (light-bg readable)
		var halo: TextureRect = make_halo.call(true, 1.0)        # additive bloom (dark-bg pop)
		if not calm:
			halo.pivot_offset = Vector2(hsz, hsz) / 2.0
			halo.tree_entered.connect(func() -> void:
				var tw := halo.create_tween().set_loops()
				tw.tween_property(halo, "scale", Vector2(1.08, 1.08), 1.1).set_trans(Tween.TRANS_SINE)
				tw.tween_property(halo, "scale", Vector2(0.93, 0.93), 1.1).set_trans(Tween.TRANS_SINE))
	if twinkle > 0.0 and not calm:
		var p := GPUParticles2D.new()
		p.position = Vector2(px / 2.0, px / 2.0)
		p.texture = _star_texture()
		p.amount = maxi(3, int(round(twinkle * 16.0)))     # the slider sets the twinkle DENSITY
		p.lifetime = 1.6
		p.preprocess = 1.2                                  # start mid-cycle so the first frame already twinkles
		p.randomness = 1.0
		p.local_coords = false
		var mat := ParticleProcessMaterial.new()
		mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
		mat.emission_ring_axis = Vector3(0, 0, 1)           # ring lies in the screen plane
		mat.emission_ring_radius = px * 0.52
		mat.emission_ring_inner_radius = px * 0.34
		mat.emission_ring_height = 0.0
		mat.direction = Vector3(0, 0, 0)
		mat.spread = 0.0
		mat.gravity = Vector3.ZERO
		mat.initial_velocity_min = 2.0
		mat.initial_velocity_max = 12.0                     # a gentle outward drift
		mat.angular_velocity_min = -40.0
		mat.angular_velocity_max = 40.0
		mat.scale_min = px * 0.0024
		mat.scale_max = px * 0.0052
		var ramp := Gradient.new()                          # twinkle in → out: a 0→1→0 alpha ramp over life
		ramp.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
		ramp.colors = PackedColorArray([Color(1, 0.86, 0.5, 0.0), Color(1, 0.84, 0.42, 1.0), Color(1, 0.86, 0.5, 0.0)])
		var gt := GradientTexture1D.new()
		gt.gradient = ramp
		mat.color_ramp = gt
		p.process_material = mat
		root.add_child(p)
		p.emitting = true
	return root

## A code-generated SPARKLE sprite — a hot round core, 4 main points, and 4 short diagonal rays, all
## warm-white so the gold color-ramp tints it (see _sparkle_overlay). There is NO dark outline: the old
## dark contrast-rim read as a "hollow plus" on the light cream unlock disc — the warm fill washed into
## the cream, leaving only the dark rim visible (a plus-shaped outline). Light-background contrast now
## comes from the gold GLOW halo drawn behind the twinkles (the disc runs glow≈0.8) plus the saturated
## ramp; on dark backgrounds the bright core simply pops. The diagonal rays make it read as a twinkle,
## not a bare plus. Cached.
static var _star_tex: Texture2D = null
static func _star_texture() -> Texture2D:
	if _star_tex != null:
		return _star_tex
	var n := 48
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := n / 2.0
	const SQ := 0.7071068                                       # 1/sqrt(2): rotate into the diagonal frame
	for y in n:
		for x in n:
			var dx: float = (x - c + 0.5) / c
			var dy: float = (y - c + 0.5) / c
			var ax: float = absf(dx)
			var ay: float = absf(dy)
			var dist: float = sqrt(dx * dx + dy * dy)
			# the 4 main points (axis-aligned) — a touch wider than before (taper 6, was 7) so the fill
			# reads as a body, not just a hairline edge that vanishes on cream.
			var hx: float = clampf(1.0 - ax, 0.0, 1.0) * clampf(1.0 - ay * 6.0, 0.0, 1.0)
			var vy: float = clampf(1.0 - ay, 0.0, 1.0) * clampf(1.0 - ax * 6.0, 0.0, 1.0)
			# 4 short diagonal rays (the axis frame rotated 45°) — shorter + fainter, so the whole thing
			# reads as a SPARKLE/twinkle rather than a plus sign.
			var ux: float = (dx + dy) * SQ
			var uy: float = (dx - dy) * SQ
			var d1: float = clampf(1.0 - absf(ux) * 1.8, 0.0, 1.0) * clampf(1.0 - absf(uy) * 12.0, 0.0, 1.0)
			var d2: float = clampf(1.0 - absf(uy) * 1.8, 0.0, 1.0) * clampf(1.0 - absf(ux) * 12.0, 0.0, 1.0)
			var diag: float = maxf(d1, d2) * 0.5
			# a hot round core where the rays meet — a solid bright centre reads as a shine, never hollow.
			var core: float = clampf(1.0 - dist * 2.0, 0.0, 1.0)
			var a: float = clampf(maxf(maxf(maxf(hx, vy), diag), core * core), 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 0.97, 0.86, a))      # warm-white; gold ramp tints, glow halo carries it on light bg
	_star_tex = ImageTexture.create_from_image(img)
	return _star_tex

## A code-generated radial gold bloom (long soft falloff) — the glow halo. Cached.
static var _glow_tex: Texture2D = null
static func _glow_texture() -> Texture2D:
	if _glow_tex != null:
		return _glow_tex
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := n / 2.0
	var gold: Color = Pal.STRAW
	for y in n:
		for x in n:
			var d: float = Vector2((x - c + 0.5) / c, (y - c + 0.5) / c).length()
			var a: float = clampf(1.0 - d, 0.0, 1.0)
			a = a * a * a                                    # tight core, long feathered falloff
			img.set_pixel(x, y, Color(gold.r, gold.g, gold.b, a))
	_glow_tex = ImageTexture.create_from_image(img)
	return _glow_tex

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

## A TOGGLE CARD — a NEW card type (sibling of mail_card / daily_card): one persisted setting as a row,
## its name on the LEFT and the shared Look.toggle_switch on the RIGHT, riding the SAME kit/mail_card.png
## parchment surface the mail rows use (a flat cream pill when card_art is off). The settings dialog
## stacks one per flag. Game-state-agnostic: `entry` carries label + value + on_toggle, so the workbench
## previews it (a local flip) and the GAME drives it from Save — the kit never reads game state itself.
##   entry: label (String) · value (bool, current state) · on_toggle (Callable(on: bool)).
##   opts:  label_font (px) · switch_h (px, the switch height) · card_art (bool, parchment vs pill).
static func toggle_card(entry: Dictionary, opts: Dictionary = {}) -> Control:
	var label_font := int(opts.get("label_font", 28))
	var switch_h := float(opts.get("switch_h", 44.0))
	var card_art := bool(opts.get("card_art", true))
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box: StyleBox = Look.kit_box("kit/mail_card.png", CARD_TEX, CARD_PAD) if card_art else null
	if box != null:
		panel.add_theme_stylebox_override("panel", box)
	else:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(Pal.CREAM, 0.6)
		s.set_corner_radius_all(18)
		s.set_border_width_all(1)
		s.border_color = Color(Pal.BARK, 0.4)
		s.content_margin_left = 22; s.content_margin_right = 18
		s.content_margin_top = 12; s.content_margin_bottom = 12
		panel.add_theme_stylebox_override("panel", s)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	panel.add_child(row)
	var name_l := Label.new()
	name_l.text = String(entry.get("label", ""))
	name_l.add_theme_font_size_override("font_size", label_font)
	name_l.add_theme_color_override("font_color", Pal.INK)
	name_l.add_theme_constant_override("outline_size", 0)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(name_l)

	# the switch is the SHARED Look.toggle_switch (the sliced kit/switch_on·off art) — the same one the
	# settings rows have always used. The callback fires the entry's on_toggle (game persists; preview no-ops).
	var on_toggle: Callable = entry.get("on_toggle", Callable())
	var fire := func(on: bool) -> void:
		if on_toggle.is_valid():
			on_toggle.call(on)
	var sw := Look.toggle_switch(bool(entry.get("value", false)), fire, switch_h)
	sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(sw)
	return panel

## The dialog banner band: ribbon art + the "Mail" text drawn FULL-RECT and vertically CENTRED, so it
## auto-aligns whatever the font size; plus an optional envelope icon (toggle). Named DialogBanner /
## DialogBannerIcon so the workbench can drag them.
static func _banner(text: String, font: int, band_h: float, width: float, icon_on: bool,
		icon_px: float, icon_pos, text_x: float = 0.0, text_y: float = 0.0, burn: float = 0.0,
		banner_art: String = "mail/mail_banner.png", banner_icon_id: String = "mail") -> Control:
	var header := Control.new()
	header.name = "DialogBanner"
	header.custom_minimum_size = Vector2(width, band_h)
	var bp := Look.kit(banner_art)
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
		var env := make_icon(banner_icon_id, icon_px)   # polished envelope (or the dialog's own banner icon)
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
## close_art overrides the sprite so another dialog (tiers) can dock its own ✕ disc.
static func _close_button(size: float, cb: Callable, close_art: String = "kit/mail_close.png") -> Button:
	var b := Button.new()
	b.name = "DialogClose"
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(size, size)
	var tex := clean_tex_path(Look.kit(close_art), 192)
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
## The shared frame's selectable BORDER art — a reusable registry so a dialog (or the Frame item's
## Border picker) dresses the SAME frame mechanics in a different border. Each entry carries the
## nine-patch art + its natural slice + content padding. dialog_frame resolves the chosen name into
## panel_art / slice / pad DEFAULTS; explicit panel_art / card_slice_* / panel_pad_* opts still win,
## so every existing caller (mail/daily/shop/settings on parchment; tiers on its own art) is unchanged.
const FRAME_BORDERS := {
	"parchment":  {"art": "kit/panel_parchment_v2.png", "slice": 48.0, "pad_x": 26.0, "pad_y": 24.0},
	"vault twig": {"art": "kit/vault_panel.png",        "slice": 64.0, "pad_x": 40.0, "pad_y": 34.0},
	"twig board": {"art": "kit/tiers_panel.png",        "slice": 72.0, "pad_x": 44.0, "pad_y": 30.0},
}

## Resolve a border NAME to its {art, slice, pad_x, pad_y} record (unknown → parchment, so a stale
## saved value never blanks the frame).
static func frame_border(name: String) -> Dictionary:
	return FRAME_BORDERS.get(name, FRAME_BORDERS["parchment"])

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
	# the BORDER option supplies panel_art / slice / pad DEFAULTS; explicit opts still override (so
	# mail/daily/shop/settings — which pass no border — stay byte-identical on parchment).
	var border: Dictionary = frame_border(String(opts.get("border", "parchment")))
	var sl_l: float = float(opts.get("card_slice_l", border["slice"]))
	var sl_t: float = float(opts.get("card_slice_t", border["slice"]))
	var sl_r: float = float(opts.get("card_slice_r", border["slice"]))
	var sl_b: float = float(opts.get("card_slice_b", border["slice"]))
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
	# the frame's CHROME ART — defaults are the parchment border + mail ribbon + mail ✕ (mail/daily/shop
	# pass nothing). A different dialog (e.g. tiers/discovery) overrides these to swap in its own border,
	# banner ribbon and close disc, while reusing all the SAME frame mechanics (banner overlay, scroll, ✕).
	var panel_art: String = String(opts.get("panel_art", border["art"]))
	var panel_pad_x: float = float(opts.get("panel_pad_x", border["pad_x"]))   # content inset from the border (L/R)
	var panel_pad_y: float = float(opts.get("panel_pad_y", border["pad_y"]))   # content inset from the border (T/B)
	var banner_art: String = String(opts.get("banner_art", "mail/mail_banner.png"))
	var banner_icon_id: String = String(opts.get("banner_icon_id", "mail"))
	var close_art: String = String(opts.get("close_art", "kit/mail_close.png"))

	var wrap := Control.new()
	var card := PanelContainer.new()
	# parchment NINE-PATCH (tunable slice) when card art is on, else CODE-DRAWN with a configurable corner.
	var pp := Look.kit(panel_art)
	if card_art and ResourceLoader.exists(pp):
		var st := StyleBoxTexture.new()
		st.texture = load(pp)
		st.set_texture_margin(SIDE_LEFT, sl_l); st.set_texture_margin(SIDE_TOP, sl_t)
		st.set_texture_margin(SIDE_RIGHT, sl_r); st.set_texture_margin(SIDE_BOTTOM, sl_b)
		st.axis_stretch_horizontal = hstr; st.axis_stretch_vertical = vstr
		st.content_margin_left = panel_pad_x; st.content_margin_right = panel_pad_x
		st.content_margin_top = panel_pad_y; st.content_margin_bottom = panel_pad_y
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
	var header := _banner(banner_text, banner_font, banner_h, width, banner_icon_on, banner_icon, banner_icon_pos, banner_text_x, banner_text_y, banner_burn, banner_art, banner_icon_id)
	header.position = banner_pos
	inner.add_child(header)

	# the ✕ disc poles past the card's top-right corner. The game passes on_close; the workbench prints.
	var close_cb: Callable = on_close if on_close.is_valid() else (func() -> void: print("WORKBENCH: dialog closed"))
	var close := _close_button(close_size, close_cb, close_art)
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

## The SETTINGS dialog — the SHARED frame with a column of toggle_cards, one per persisted flag. The
## direct sibling of mail_dialog: same chrome, a new card. `entries` is [{label, value, on_toggle}, …];
## the toggle-card style rides opts["toggle"] (label_font / switch_h / card_art). Used by BOTH the
## workbench preview and the game (engine/scripts/ui/settings.gd) — one builder, no duplicated face.
static func settings_dialog(entries: Array, width: float = 540.0, opts: Dictionary = {}) -> Control:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", int(opts.get("row_gap", 12)))
	var to: Dictionary = opts.get("toggle", {})
	for e in entries:
		content.add_child(toggle_card(e, to))
	return dialog_frame(content, width, opts)

## The VAULT (piggy-bank) dialog — the shared frame dressed in the twig border, wrapping the jar hero +
## a gem-balance read + the reused green price CTA. Game-state-agnostic (like settings_dialog): `state`
## carries the numbers + the claim callback, so BOTH the workbench preview and the game (ui/vault.gd)
## build the SAME face. state: { balance:int, cap:int, price:String, claimable:bool, claim_min:int,
## on_claim:Callable }.
static func vault_dialog(state: Dictionary, width: float = 460.0, opts: Dictionary = {}) -> Control:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", int(opts.get("row_gap", 12)))
	content.alignment = BoxContainer.ALIGNMENT_CENTER

	# the gem-balance read (icon + number) — the reference's "gem 320"
	var bal := HBoxContainer.new()
	bal.alignment = BoxContainer.ALIGNMENT_CENTER
	bal.add_theme_constant_override("separation", 8)
	bal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bal.add_child(make_icon("gem", float(opts.get("balance_icon", 34))))
	var bnum := Label.new()
	bnum.text = str(int(state.get("balance", 0)))
	bnum.add_theme_font_size_override("font_size", int(opts.get("balance_font", 34)))
	bnum.add_theme_color_override("font_color", Pal.INK)
	bnum.add_theme_constant_override("outline_size", 0)
	bnum.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bnum.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bal.add_child(bnum)
	content.add_child(bal)

	# the jar on its plate (sliced art when present, else a code-drawn vessel with the same metrics)
	content.add_child(_vault_jar(int(state.get("balance", 0)), int(state.get("cap", 1)),
		float(opts.get("jar_px", 200)), float(opts.get("plate_px", 220))))

	# the pitch line — the longer you play, the better the deal
	var pitch := Label.new()
	pitch.text = String(opts.get("pitch", "Premium you've earned, saved up — claim it all."))
	pitch.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pitch.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pitch.add_theme_font_size_override("font_size", int(opts.get("pitch_font", 16)))
	pitch.add_theme_color_override("font_color", Color(Pal.BARK, 0.95))
	pitch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(pitch)

	# the green price CTA — the SHARED pill_button (reused), claimable-gated (dim + a hint below)
	var claimable: bool = bool(state.get("claimable", true))
	var cta := pill_button(String(state.get("price", "")), {"bg": "green", "icon": "gem",
		"font": int(opts.get("cta_font", 24)), "enabled": true, "shadow": true, "corner": 22.0})
	cta.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cta.modulate = Color(1, 1, 1, 1.0 if claimable else 0.55)
	var on_claim: Callable = state.get("on_claim", Callable())
	if on_claim.is_valid():
		cta.pressed.connect(func() -> void: on_claim.call())
	content.add_child(cta)
	if not claimable:
		var hint := HBoxContainer.new()
		hint.alignment = BoxContainer.ALIGNMENT_CENTER
		hint.add_theme_constant_override("separation", 4)
		hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var hl := Label.new()
		hl.text = String(opts.get("hint_text", "Keep playing — it fills at"))
		hl.add_theme_font_size_override("font_size", 15)
		hl.add_theme_color_override("font_color", Color(Pal.BARK, 0.8))
		hl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hint.add_child(hl)
		hint.add_child(make_icon("gem", 16))
		var hn := Label.new()
		hn.text = str(int(state.get("claim_min", 0)))
		hn.add_theme_font_size_override("font_size", 15)
		hn.add_theme_color_override("font_color", Color(Pal.BARK, 0.8))
		hn.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hint.add_child(hn)
		content.add_child(hint)

	return dialog_frame(content, width, opts)

## The jar hero seated on its base plate: vault_plate.png behind + vault_jar.png over (cleaned), when
## present; else a code-drawn vessel with a GOLD fill rising to balance/cap — the fallback lifted from
## the old ui/vault.gd `_make_jar`, so the read survives until the art lands (the kit invariant).
static func _vault_jar(balance: int, cap: int, jar_px: float, plate_px: float) -> Control:
	var box := Control.new()
	var box_w: float = maxf(jar_px, plate_px)
	# the oval plate sits UNDER the jar: the jar's base sinks into the plate's top third (overlap), so the
	# jar reads as resting on it (the reference). plate_h follows the sprite's wide aspect (~139/550).
	var plate_h: float = plate_px * 0.255
	var overlap: float = plate_h * 0.55
	var box_h: float = jar_px + plate_h - overlap
	box.custom_minimum_size = Vector2(box_w, box_h)
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var plate_tex := clean_tex_path(Look.kit("kit/vault_plate.png"), 256)
	if plate_tex != null:
		var pl := TextureRect.new()
		pl.texture = plate_tex
		pl.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pl.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pl.custom_minimum_size = Vector2(plate_px, plate_h)
		pl.size = pl.custom_minimum_size
		pl.position = Vector2((box_w - plate_px) / 2.0, box_h - plate_h)   # plate's bottom = box bottom
		pl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(pl)                                                  # added FIRST → drawn under the jar
	var jar_tex := clean_tex_path(Look.kit("kit/vault_jar.png"), 384)
	if jar_tex != null:
		var jr := TextureRect.new()
		jr.texture = jar_tex
		jr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		jr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		jr.custom_minimum_size = Vector2(jar_px, jar_px)
		jr.size = jr.custom_minimum_size
		jr.position = Vector2((box_w - jar_px) / 2.0, 0)                   # jar base at y=jar_px, over the plate
		jr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(jr)
		return box
	# --- code-drawn fallback (no jar art) — vessel + gold fill, adapted from the old _make_jar -------
	var frac := clampf(float(balance) / float(maxi(1, cap)), 0.0, 1.0)
	var jx := (box_w - jar_px) / 2.0
	var body := Panel.new()
	body.position = Vector2(jx, 0); body.size = Vector2(jar_px, jar_px)
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(Pal.CREAM, 0.65)
	bs.set_corner_radius_all(int(jar_px * 0.28))
	bs.set_border_width_all(5); bs.border_color = Pal.BARK
	body.add_theme_stylebox_override("panel", bs)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(body)
	var inset := 8.0
	var fill := Panel.new()
	var fh: float = maxf(6.0, (jar_px - inset * 2.0) * frac)
	fill.position = Vector2(jx + inset, jar_px - inset - fh)
	fill.size = Vector2(jar_px - inset * 2.0, fh)
	var fs := StyleBoxFlat.new()
	fs.bg_color = Color(Pal.GOLD, 0.92) if frac > 0.0 else Color(Pal.GOLD, 0.0)
	fs.set_corner_radius_all(int(jar_px * 0.22))
	fill.add_theme_stylebox_override("panel", fs)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(fill)
	return box

## A small kit sprite (the ✓ check, the mystery chest, …) cleaned + fit into a px box.
static func _kit_sprite(rel: String, px: float) -> TextureRect:
	var t := TextureRect.new()
	t.texture = clean_tex_path(Look.kit(rel), 256)
	t.custom_minimum_size = Vector2(px, px)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

## A day's reward as the ICON ONLY — the daily card shows the reward TYPE, never a number (the amount
## is a claim-time surprise and keeps the small card uncluttered). Picks the premium currency (gems >
## coins > water). Shop cards show their count separately; this is daily-only.
static func _daily_reward(reward: Dictionary, px: float = 40.0) -> Control:
	var icon_id := "coin"
	if int(reward.get("gems", 0)) > 0:
		icon_id = "gem"
	elif int(reward.get("coins", 0)) > 0:
		icon_id = "coin"
	elif int(reward.get("water", 0)) > 0:
		icon_id = "water"
	elif String(reward.get("cosmetic", "")) != "":
		icon_id = "star"
	return make_icon(icon_id, px)

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

	# Content is ABSOLUTELY positioned inside `inner` so each region sits independently and none shifts the
	# others: the reward icon DEAD-CENTRE of the card, the label pinned near the top (tunable Y), the
	# action near the bottom (tunable Y, kept INSIDE), and the ribbon floating as a banner OVER the top.
	var inner := Control.new()
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(inner)
	# ONE uniform content scale (design reference = 160px wide): the icon, every font, the ribbon, the
	# button AND the position offsets all scale TOGETHER with the card, so the proportions stay CONSTANT as
	# the dialog grows — no more small text/icon stranded in a big card (everything was capped before).
	var s: float = cw / 160.0
	var label_font := maxi(8, int(18.0 * s))
	var count_font := maxi(8, int(21.0 * s))
	var claim_font := maxi(8, int(18.0 * s))
	var label_y: float = float(opts.get("label_y", 12.0)) * s
	var claim_y: float = float(opts.get("claim_y", 14.0)) * s

	# the main content — the mystery chest · a reward icon (daily) · or a big icon(+count) (shop) — sits
	# DEAD CENTRE of the card (a full-rect CenterContainer), independent of the label/action positions.
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(center)
	if d.has("node") and d.node != null:
		center.add_child(d.node as Control)   # a GAME-injected hero (real piece preview, a 2-currency bundle, …)
	elif milestone:
		center.add_child(_kit_sprite("kit/daily_chest.png", cw * 0.56))
	elif d.has("reward"):
		center.add_child(_daily_reward(d.get("reward", {}), cw * 0.56))   # icon a touch bigger (no number)
	elif d.has("icon"):
		var ic_col := VBoxContainer.new()
		ic_col.alignment = BoxContainer.ALIGNMENT_CENTER
		ic_col.add_theme_constant_override("separation", int(2.0 * s))
		ic_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic_col.add_child(make_icon(String(d.icon), cw * 0.52))
		if int(d.get("count", 0)) > 0:
			var cn := Label.new()
			cn.text = str(int(d.count))
			cn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cn.add_theme_font_size_override("font_size", count_font)
			cn.add_theme_color_override("font_color", Pal.INK)
			cn.add_theme_constant_override("outline_size", 0)
			cn.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ic_col.add_child(cn)
		center.add_child(ic_col)

	# the label ("Day N") — pinned near the TOP, shifted down by label_y (tunable). shop packs omit it.
	if d.has("label") or d.has("day"):
		var dl := Label.new()
		dl.text = String(d.get("label", "Day %d" % int(d.get("day", 1))))
		dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var label_x: float = float(opts.get("label_x", 0.0)) * s   # text H nudge (slider), scaled with the card
		dl.anchor_left = 0.0; dl.anchor_right = 1.0
		dl.anchor_top = 0.0; dl.anchor_bottom = 0.0
		dl.offset_left = label_x; dl.offset_right = label_x
		dl.offset_top = label_y; dl.offset_bottom = label_y
		dl.grow_vertical = Control.GROW_DIRECTION_END
		dl.add_theme_font_size_override("font_size", label_font)
		dl.add_theme_color_override("font_color", Pal.INK if state != "today" else Pal.LEAF.darkened(0.15))
		dl.add_theme_constant_override("outline_size", 0)
		dl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(dl)

	# BOTTOM action — a price (shop) / Claim (today) is the SHARED green pill_button, a done day a ✓.
	# Anchored to the bottom and LIFTED up by claim_y so it sits INSIDE the card (was overflowing below).
	var act_text := ""
	var act_cb := Callable()
	var act_icon := ""
	if d.has("price"):
		act_text = String(d.price); act_cb = d.get("on_buy", Callable())
		act_icon = String(d.get("price_icon", ""))     # a currency glyph on the price (gem/coin); "" = USD
	elif state == "today":
		act_text = String(d.get("claim_text", "Claim")); act_cb = d.get("on_claim", Callable())
	var act_node: Control = null
	if act_text != "":
		var co := btn_opts.duplicate()
		co["bg"] = "green"; co["text"] = act_text; co["icon"] = act_icon
		co["font"] = claim_font
		co["icon_size"] = int(claim_font + 8 * s)   # the currency glyph scales with the button font too
		var btn := pill_button(act_text, co)
		if d.has("affordable") and not bool(d.get("affordable", true)):
			btn.modulate = Color(1, 1, 1, 0.45)   # can't afford → the buy CTA greys (still pressable: wallet wiggles)
		if act_cb.is_valid():
			btn.pressed.connect(func() -> void: act_cb.call())
		act_node = btn
	elif state == "done":
		act_node = _kit_sprite("kit/daily_check.png", cw * 0.34)
	if act_node != null:
		var act_wrap := CenterContainer.new()
		act_wrap.anchor_left = 0.0; act_wrap.anchor_right = 1.0
		act_wrap.anchor_top = 1.0; act_wrap.anchor_bottom = 1.0
		act_wrap.offset_left = 0.0; act_wrap.offset_right = 0.0
		act_wrap.offset_top = -claim_y; act_wrap.offset_bottom = -claim_y
		act_wrap.grow_vertical = Control.GROW_DIRECTION_BEGIN   # grows UPWARD from the lifted bottom edge
		act_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		act_wrap.add_child(act_node)
		inner.add_child(act_wrap)

	# the optional INFO badge — top-right. A card's `on_info` Callable makes it an INTERACTIVE "i" button
	# (a tap opens the game's detail sheet, without buying); otherwise the design-time `info_icon` toggle
	# shows a static disc. The icon scales/positions with the card like everything else.
	var on_info: Callable = d.get("on_info", Callable())
	if on_info.is_valid() or bool(opts.get("info_icon", false)):
		var ip: float = maxf(14.0, cw * 0.2)
		var im: float = 6.0 * s                       # corner margin scales with the card too
		var info: Control
		if on_info.is_valid():
			var ib := Button.new()
			ib.focus_mode = Control.FOCUS_NONE
			var itex := clean_tex_path(Look.kit("shared/icon_question.png"), 192)
			if itex != null:
				var ist := StyleBoxTexture.new(); ist.texture = itex
				ib.add_theme_stylebox_override("normal", ist)
				ib.add_theme_stylebox_override("hover", ist)
				var isp: StyleBoxTexture = ist.duplicate(); isp.modulate_color = Color(0.85, 0.85, 0.85)
				ib.add_theme_stylebox_override("pressed", isp)
			ib.pressed.connect(func() -> void: on_info.call())
			info = ib
		else:
			info = _kit_sprite("shared/icon_question.png", ip)
		info.anchor_left = 1.0; info.anchor_right = 1.0
		info.anchor_top = 0.0; info.anchor_bottom = 0.0
		info.offset_left = -(ip + im); info.offset_right = -im
		info.offset_top = im; info.offset_bottom = im + ip
		inner.add_child(info)

	_apply_day_badge(panel, badge)   # the configurable rim/glow on today + milestone cards
	# the generated SPARKLE marks the claimable (today) rung — animated twinkles around the reward
	if state == "today" and bool(opts.get("sparkle", true)):
		var sp := Sparkle.new()
		sp.set_anchors_preset(Control.PRESET_FULL_RECT)
		panel.add_child(sp)

	# Wrap the card so the ribbon draws ON TOP of the card BORDER — inside the panel it was hidden behind
	# the nine-patch lip + the day-badge rim. The ribbon is a BANNER over the top edge, with a tunable SIZE
	# and H position, so it reads clearly and never shifts the content below. The panel holds everything else.
	var outer := Control.new()
	outer.custom_minimum_size = Vector2(cw, ch)
	outer.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	outer.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer.add_child(panel)
	if ribbon != "":
		# the ribbon scales with the card too (× s), so it keeps the SAME proportion to the text/icon/button
		var rb := _ribbon_badge(ribbon, s * float(opts.get("ribbon_scale", 1.0)))
		rb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rb.anchor_left = 0.5; rb.anchor_right = 0.5
		rb.anchor_top = 0.0; rb.anchor_bottom = 0.0
		rb.grow_horizontal = Control.GROW_DIRECTION_BOTH
		rb.grow_vertical = Control.GROW_DIRECTION_BOTH
		rb.offset_left = float(opts.get("ribbon_x", 0.0)) * s    # H nudge (slider), scaled with the card
		rb.offset_right = float(opts.get("ribbon_x", 0.0)) * s
		rb.offset_top = float(opts.get("ribbon_y", -10.0)) * s   # rides over the top edge, ON TOP of the border
		outer.add_child(rb)                                      # added AFTER the panel → drawn on top
	return outer

## The POPULAR ribbon — a small merchandising tag ("Popular" / "Best value" / …). The red shop_tag art
## (cream text) when present, else a code STRAW pill (ink text). Mirrors the game shop's _badge.
static func _ribbon_badge(text: String, scale: float = 1.0) -> Control:
	var s := maxf(0.4, scale)             # the SIZE knob — scales the pads + the font together
	var pop := PanelContainer.new()
	pop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fg := Pal.CREAM
	var tex := clean_tex_path(Look.kit("kit/shop_tag.png"), 256)
	if tex != null:
		var stx := StyleBoxTexture.new()
		stx.texture = tex
		stx.content_margin_left = 15 * s; stx.content_margin_right = 15 * s
		stx.content_margin_top = 5 * s; stx.content_margin_bottom = 8 * s
		pop.add_theme_stylebox_override("panel", stx)
	else:
		var pp := StyleBoxFlat.new()
		pp.bg_color = Pal.STRAW
		pp.set_corner_radius_all(int(8 * s))
		pp.content_margin_left = 10 * s; pp.content_margin_right = 10 * s
		pp.content_margin_top = 3 * s; pp.content_margin_bottom = 4 * s
		pop.add_theme_stylebox_override("panel", pp)
		fg = Pal.INK
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", maxi(8, int(13 * s)))
	l.add_theme_color_override("font_color", fg)
	l.add_theme_constant_override("outline_size", 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pop.add_child(l)
	return pop

## A reusable PROGRESS BAR — a rounded track with a honey fill clipped to `frac` (0..1). Art mode draws
## the kit's prog_track / prog_fill capsules as NINE-SLICE pills (rendered at native height, then the whole
## bar uniformly scaled to its display box so the caps stay round at any size — see progress_bar's note);
## else a code-drawn StyleBoxFlat track + fill (the legacy look). opts: height (px — the display height),
## width (px), art (bool), label ("" = none; centered, e.g. "75%"), star_knob (bool — a star sprite riding
## the fill head). Standalone so improving it lifts every site (the Level dialog now; the home unlock % later).
static func progress_bar(frac: float, opts: Dictionary = {}) -> Control:
	var h: float = float(opts.get("height", 20.0))     # the DISPLAY height the bar shrinks to fit
	var f: float = clampf(frac, 0.0, 1.0)
	var use_art: bool = bool(opts.get("art", true))
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(float(opts.get("width", 280.0)), h)
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var track_tex: Texture2D = clean_tex_path(Look.kit("kit/prog_track.png"), 512) if use_art else null
	var fill_tex: Texture2D = clean_tex_path(Look.kit("kit/prog_fill.png"), 512) if use_art else null
	if track_tex != null and fill_tex != null:
		# ART mode — track & fill are NINE-SLICE capsules. A 9-slice pill's rounded caps only stay round
		# when the node is drawn at least as tall as the cap (margin = radius); squashing it shorter ovals
		# them out. So we draw the caps at their NATIVE texture height on an inner "stage", then uniformly
		# SCALE the whole stage down to the bar's display box — the caps shrink but keep their shape. Because
		# the stage is always at native height (no vertical scaling), only the HORIZONTAL centre stretches.
		var nat_h: float = float(track_tex.get_height())
		var t_margin: int = int(round(nat_h * 0.5))                 # capsule radius = half the height
		var fill_h: float = float(fill_tex.get_height())
		var f_margin: int = int(round(fill_h * 0.5))
		var inset: float = (nat_h - fill_h) * 0.5                   # the fill sits inside the track rim
		var stage := Control.new()
		stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(stage)
		var track := NinePatchRect.new()
		track.texture = track_tex
		track.patch_margin_left = t_margin; track.patch_margin_right = t_margin
		track.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage.add_child(track)
		var fill_clip := Control.new()
		fill_clip.clip_contents = true
		fill_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage.add_child(fill_clip)
		var fill := NinePatchRect.new()
		fill.texture = fill_tex
		fill.patch_margin_left = f_margin; fill.patch_margin_right = f_margin
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fill_clip.add_child(fill)
		var lay_art := func() -> void:
			if not (is_instance_valid(holder) and is_instance_valid(stage)):
				return
			var disp := holder.size
			if disp.x <= 0.0 or disp.y <= 0.0:
				return
			var s: float = disp.y / nat_h                           # uniform shrink: native → display height
			var stage_w: float = disp.x / s                         # …so the scaled stage spans the full width
			stage.scale = Vector2(s, s)
			stage.size = Vector2(stage_w, nat_h)
			track.size = Vector2(stage_w, nat_h)
			var fill_w: float = stage_w - inset * 2.0               # the inner fill track, inset within the rim
			var clip_w: float = maxf(fill_h, fill_w * f)            # ≥ a round nub so 0% still reads as a bar
			fill_clip.position = Vector2(inset, inset)
			fill_clip.size = Vector2(clip_w, fill_h)
			fill.position = Vector2.ZERO
			fill.size = Vector2(fill_w, fill_h)                     # full width; the clip reveals only `frac`
		holder.resized.connect(lay_art)
		holder.ready.connect(lay_art)
	else:
		# code-drawn fallback (legacy look) — a rounded track with a clip-revealed straw fill
		var track := Panel.new()
		track.set_anchors_preset(Control.PRESET_FULL_RECT)
		var tsb := StyleBoxFlat.new()
		tsb.bg_color = Color(Pal.INK, 0.12)
		tsb.set_corner_radius_all(int(h * 0.5))
		track.add_theme_stylebox_override("panel", tsb)
		track.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(track)
		var fill_clip := Control.new()
		fill_clip.clip_contents = true
		fill_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(fill_clip)
		var fill := Panel.new()
		var fsb := StyleBoxFlat.new()
		fsb.bg_color = Pal.STRAW
		fsb.set_corner_radius_all(int(h * 0.5))
		fill.add_theme_stylebox_override("panel", fsb)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fill_clip.add_child(fill)
		var lay := func() -> void:
			if not (is_instance_valid(holder) and is_instance_valid(fill_clip) and is_instance_valid(fill)):
				return
			var w := holder.size.x
			var fw := maxf(h, w * f)             # at least a rounded nub so 0% still reads as a bar
			fill_clip.position = Vector2.ZERO
			fill_clip.size = Vector2(fw, h)
			fill.position = Vector2.ZERO
			fill.size = Vector2(w, h)            # fill keeps FULL width; the clip reveals only `frac` of it
		# Layout is driven by ready/resized (which only fire once the bar is IN a tree) — NOT a bare
		# call_deferred, so a bar built-and-freed before any layout (a discarded preview) can't fire a
		# lambda over freed captures.
		holder.resized.connect(lay)
		holder.ready.connect(lay)
	# --- optional star knob riding the fill head ---
	if bool(opts.get("star_knob", false)):
		var knob := make_icon("star", h * 1.4)
		knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(knob)
		var place := func() -> void:
			if is_instance_valid(knob) and is_instance_valid(holder):
				knob.position = Vector2(maxf(0.0, holder.size.x * f - h * 0.7), -h * 0.2)
		holder.resized.connect(place)
	# --- optional centered label (e.g. "75%") ---
	var label := String(opts.get("label", ""))
	if label != "":
		var l := Label.new()
		l.text = label
		l.set_anchors_preset(Control.PRESET_FULL_RECT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", int(h * 0.7))
		l.add_theme_color_override("font_color", Pal.INK)
		l.add_theme_constant_override("outline_size", 0)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(l)
	return holder

## The Level MEDALLION — the laurel wreath behind the gold ring, with the level NUMBER centered on the
## ring's cream face. The ring sprite (level_ring.png) already carries its own cream inner face (verified
## at intake), so NO separate badge disc is layered. `px` is the ring diameter; the wreath frames it a
## touch larger. opts: number_font, ink (Color), ring_dy (px — nudge the ring up/down within the wreath).
static func level_medallion(level: int, px: float = 120.0, opts: Dictionary = {}) -> Control:
	var root := Control.new()
	var wreath_px := px * 1.55
	root.custom_minimum_size = Vector2(wreath_px, wreath_px)
	root.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# the wreath sits BEHIND (added first), centered, a touch larger than the ring
	var wreath := clean_tex_path(Look.kit("kit/level_wreath.png"), 512)
	if wreath != null:
		var wr := TextureRect.new()
		wr.texture = wreath
		wr.set_anchors_preset(Control.PRESET_FULL_RECT)
		wr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		wr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		wr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(wr)
	# the ring centered at px (a touch above centre by ring_dy so the wreath frames its lower half)
	var ring_dy := float(opts.get("ring_dy", 0.0))
	var ring := Control.new()
	ring.custom_minimum_size = Vector2(px, px)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.anchor_left = 0.5; ring.anchor_right = 0.5
	ring.anchor_top = 0.5; ring.anchor_bottom = 0.5
	ring.grow_horizontal = Control.GROW_DIRECTION_BOTH
	ring.grow_vertical = Control.GROW_DIRECTION_BOTH
	ring.offset_left = -px * 0.5; ring.offset_right = px * 0.5
	ring.offset_top = -px * 0.5 + ring_dy; ring.offset_bottom = px * 0.5 + ring_dy
	root.add_child(ring)
	var ring_tex := clean_tex_path(Look.kit("kit/level_ring.png"), 512)
	if ring_tex != null:
		var rt := TextureRect.new()
		rt.texture = ring_tex
		rt.set_anchors_preset(Control.PRESET_FULL_RECT)
		rt.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rt.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ring.add_child(rt)
	# the level number, centered on the ring face
	var num := Label.new()
	num.text = str(level)
	num.set_anchors_preset(Control.PRESET_FULL_RECT)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	num.add_theme_font_size_override("font_size", int(opts.get("number_font", px * 0.42)))
	num.add_theme_color_override("font_color", opts.get("ink", Pal.INK))
	num.add_theme_constant_override("outline_size", 0)
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.add_child(num)
	return root

## A dedicated FRAME for the Level dialog (NOT the shared dialog_frame): the level_frame parchment border
## (nine-patch), the gold level_title pill banner centered over the top edge, inner padding, and NO scroll
## / NO ✕ (the reference has none). `content` is laid out statically (the dialog is short). opts:
## banner_text, title_font, slice (nine-patch), pad, top_pad (room under the title pill).
static func level_frame(content: Control, width: float = 460.0, opts: Dictionary = {}) -> Control:
	var banner_text := String(opts.get("banner_text", "Level"))
	var title_font := int(opts.get("title_font", 30))
	var sl := float(opts.get("slice", 56.0))
	var pad := float(opts.get("pad", 26.0))
	var top_pad := float(opts.get("top_pad", 70.0))
	var card := PanelContainer.new()
	var fp := Look.kit("kit/level_frame.png")
	# the parchment border, polished like every other sprite (defringe + alpha-feather) so its outer edge
	# reads SOFT, not roughly-cut. max_dim 1024 ≥ the source's longest side → no resize, so the nine-patch
	# slice margins (sl) stay exact in texture pixels. clean_tex_path returns null when the art is missing.
	var ftex := clean_tex_path(fp, 1024)
	if ftex != null:
		var st := StyleBoxTexture.new()
		st.texture = ftex
		st.set_texture_margin(SIDE_LEFT, sl); st.set_texture_margin(SIDE_TOP, sl)
		st.set_texture_margin(SIDE_RIGHT, sl); st.set_texture_margin(SIDE_BOTTOM, sl)
		st.content_margin_left = pad; st.content_margin_right = pad
		st.content_margin_top = top_pad; st.content_margin_bottom = pad
		card.add_theme_stylebox_override("panel", st)
	else:
		var cf := StyleBoxFlat.new()
		cf.bg_color = Pal.CREAM; cf.border_color = Pal.BARK
		cf.set_corner_radius_all(28); cf.set_border_width_all(3)
		cf.content_margin_left = pad; cf.content_margin_right = pad
		cf.content_margin_top = top_pad; cf.content_margin_bottom = pad
		card.add_theme_stylebox_override("panel", cf)
	card.custom_minimum_size = Vector2(width, 0)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_child(content)
	# the title pill overlays the top edge, centered (added after the card → drawn on top)
	var wrap := Control.new()
	wrap.custom_minimum_size.x = width
	wrap.add_child(card)
	var title := _level_title_pill(banner_text, title_font)
	wrap.add_child(title)
	var dock := func() -> void:
		if is_instance_valid(title) and is_instance_valid(card) and is_instance_valid(wrap):
			title.position = Vector2((card.size.x - title.size.x) * 0.5, -title.size.y * 0.5)
			wrap.custom_minimum_size = card.size
	card.resized.connect(dock)
	title.resized.connect(dock)
	wrap.ready.connect(dock)
	return wrap

## The gold "Level N" title pill (the level_title sprite scaled whole, text centered). Code STRAW fallback.
static func _level_title_pill(text: String, font: int) -> Control:
	var pill := PanelContainer.new()
	pill.name = "LevelTitle"
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tp := clean_tex_path(Look.kit("kit/level_title.png"), 480)
	if tp != null:
		var stx := StyleBoxTexture.new()
		stx.texture = tp
		stx.content_margin_left = 44; stx.content_margin_right = 44
		stx.content_margin_top = 12; stx.content_margin_bottom = 16
		pill.add_theme_stylebox_override("panel", stx)
	else:
		var ps := StyleBoxFlat.new()
		ps.bg_color = Pal.STRAW; ps.set_corner_radius_all(18)
		ps.content_margin_left = 28; ps.content_margin_right = 28
		ps.content_margin_top = 6; ps.content_margin_bottom = 8
		pill.add_theme_stylebox_override("panel", ps)
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font)
	l.add_theme_color_override("font_color", Color("#4A2E14"))
	l.add_theme_constant_override("outline_size", 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(l)
	return pill

## The whole LEVEL dialog: the dedicated frame + medallion + "X / Y ★ earned" + progress_bar + the
## "N more ★ to reach Level N+1" line (info) OR a reward chip row (levelup) + the bottom button (the
## shared pill_button with the green level_btn bg). `data` keys: level, earned, next, into, span,
## remaining, mode ("info"|"levelup"), gift ({water,gems}), on_button (Callable). opts: see
## level_opts_from_config (frame + progress + btn style). Used by BOTH the workbench preview and the game.
static func level_dialog(data: Dictionary, width: float = 460.0, opts: Dictionary = {}) -> Control:
	var mode := String(data.get("mode", "info"))
	var lvl := int(data.get("level", 1))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", int(opts.get("gap", 14)))
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	# medallion
	var med := level_medallion(lvl, float(opts.get("medallion_px", 120.0)), opts)
	med.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(med)
	# "X / Y ★ earned"
	var tally := Label.new()
	tally.text = TranslationServer.translate("%d / %d ★ earned") % [int(data.get("earned", 0)), int(data.get("next", 0))]
	tally.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tally.add_theme_font_size_override("font_size", int(opts.get("tally_font", 28)))
	tally.add_theme_color_override("font_color", Pal.INK)
	tally.add_theme_constant_override("outline_size", 0)
	col.add_child(tally)
	# the progress bar (reusable component, fraction of the way through this level)
	var span: int = maxi(1, int(data.get("span", 1)))
	var frac: float = clampf(float(int(data.get("into", 0))) / float(span), 0.0, 1.0)
	var bar := progress_bar(frac, opts.get("progress", {}))
	bar.custom_minimum_size.x = width * 0.78
	col.add_child(bar)
	# levelup → the earned reward row (cream chips); info → the "N more ★" hint line
	if mode == "levelup":
		var gift: Dictionary = data.get("gift", {})
		var reward := {"water": int(gift.get("water", 0)), "gems": int(gift.get("gems", 0))}
		if _reward_total(reward) > 0:
			var rrow := reward_chip(reward, opts.get("btn", {}))
			rrow.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			col.add_child(rrow)
	else:
		var nxt := Label.new()
		nxt.text = TranslationServer.translate("%d more ★ to reach Level %d") % [int(data.get("remaining", 0)), lvl + 1]
		nxt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nxt.add_theme_font_size_override("font_size", int(opts.get("hint_font", 22)))
		nxt.add_theme_color_override("font_color", Pal.BARK)
		nxt.add_theme_constant_override("outline_size", 0)
		col.add_child(nxt)
	# the bottom button — the SHARED pill_button wearing the registered "level green" badge background
	# (Kit.BADGES), so it's the same atom every dialog uses and the bg is a selectable shared-button option.
	var bo: Dictionary = (opts.get("btn", {}) as Dictionary).duplicate()
	bo["bg"] = "green"; bo["art"] = true; bo["art_rel"] = String(BADGES["level green"]); bo["icon"] = ""
	var btn_text := TranslationServer.translate("Collect") if mode == "levelup" else TranslationServer.translate("Got it")
	var btn := pill_button(btn_text, bo)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var cb: Callable = data.get("on_button", Callable())
	if cb.is_valid():
		btn.pressed.connect(func() -> void: cb.call())
	col.add_child(btn)
	return level_frame(col, width, opts)

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

## A GRID of the shared small cards, EXACTLY `cols` per row filling the width — the content for the
## daily + shop dialogs. The cell width is computed from the dialog `width` and the card CONTENT
## (fonts / icon / Claim) is BUILT at that width, so the cards actually shrink to fit cols across at ANY
## width (a fixed-min Claim button used to force the dialog wider). A relayout makes the fit pixel-exact;
## a partial last row (e.g. Day 7) centres.
static func _card_grid(cards: Array, width: float, opts: Dictionary) -> Control:
	var cols: int = maxi(1, int(opts.get("cols", 3)))
	var gap: int = int(opts.get("cell_h_gap", 12))
	# the cell width that fits `cols` across the frame's content area (~width − card margins). Build the
	# content scaled to it (fonts + icon) so a card's min never exceeds 1/cols and the row can't overflow.
	var cw: float = maxf(48.0, (width - 56.0 - (cols - 1) * gap) / float(cols))
	# Preserve the EDITED card's ASPECT RATIO when the cells shrink to fit `cols` across — forcing 3 per row
	# must not squash the card tall-and-thin; derive the cell HEIGHT from the original cell_w:cell_h ratio.
	var aspect: float = float(opts.get("cell_h", 116.0)) / maxf(1.0, float(opts.get("cell_w", 96.0)))
	var co := opts.duplicate()
	co["cell_w"] = cw
	co["cell_h"] = cw * aspect
	# (the card's fonts / icon / ribbon all scale from cell_w inside daily_card — uniform proportions)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", int(opts.get("cell_v_gap", 12)))
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var made: Array = []
	var i := 0
	while i < cards.size():
		var r := HBoxContainer.new()
		r.alignment = BoxContainer.ALIGNMENT_CENTER
		r.add_theme_constant_override("separation", gap)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for j in cols:
			if i + j < cards.size():
				var c := daily_card(cards[i + j], co)
				r.add_child(c)
				made.append(c)
		content.add_child(r)
		i += cols
	# pixel-exact: size each card to 1/cols of the ACTUAL content width, with the aspect-correct height
	var fit := func() -> void:
		if not is_instance_valid(content):
			return
		var cwf := (content.size.x - (cols - 1) * gap) / float(cols)
		for c in made:
			if is_instance_valid(c):
				(c as Control).custom_minimum_size = Vector2(maxf(40.0, cwf), maxf(40.0, cwf * aspect))
	content.resized.connect(fit)
	fit.call_deferred()
	return content

## The DAILY dialog — the shared frame with a grid of day cards.
static func daily_dialog(days: Array, width: float = 460.0, opts: Dictionary = {}) -> Control:
	return dialog_frame(_card_grid(days, width, opts), width, opts)

## --- the discovery (tier-ladder) card + dialog ------------------------------------------------------
## One TIER CELL — the discovery board's tile, now built on the SHARED slot cell (Kit.slot_cell) so
## discovery, the bag, and the board all read as ONE component. A DISCOVERED tier wears the FILLED well
## holding its piece; an UNDISCOVERED tier wears the LOCKED well — the baked gold padlock KEPT, no acorn
## cost, and no "?" glyph (the locked well stands in for it). The item TIER rides the gold level medal
## docked lower-right (the SAME medal the HUD + board cells wear, via the slot cell's `level`/`level_frac`).
## A MARKED tier (the tapped/asked one) is flagged by the engine sparkle. The game's make_content(d, px)
## builds the discovered piece at the cell size.
## d keys: tier, seen, marked, icon|node. opts: tiers_card_opts_from_config(...).
static func tiers_card(d: Dictionary, opts: Dictionary = {}) -> Control:
	var seen := bool(d.get("seen", false))
	var sd := {
		"state": ("filled" if seen else "locked"),
		"cost": 0,                                          # discovery has no buy price → the locked well is its baked padlock alone
		"marked": bool(d.get("marked", false)),
		"level": (int(d.get("tier", 0)) if bool(opts.get("show_num", true)) else 0),   # the tier rides the lower-right level medal
	}
	# bridge the discovery make_content(d, px) → the slot cell's make_content(px); else a pre-built node or
	# an icon id (the workbench preview). Only a discovered tier carries a piece.
	var mk: Callable = opts.get("make_content", Callable())
	if seen and mk.is_valid():
		sd["make_content"] = func(px: float) -> Control: return mk.call(d, px)
	elif seen and d.get("node") is Control:
		sd["content"] = d.get("node")
	elif seen and String(d.get("icon", "")) != "":
		sd["icon"] = String(d.get("icon"))
	return slot_cell(sd, _tiers_to_slot_opts(opts))

## Map the tier-cell opts (tiers_card_opts_from_config) onto the slot cell's opts — the discovery tile IS a
## slot cell, with the lower-right level medal carrying the tier (level_frac ← lvl_frac) and the marked-tier
## sparkle wired through (mark_glow / mark_twinkle).
static func _tiers_to_slot_opts(opts: Dictionary) -> Dictionary:
	return {
		"cell_w": float(opts.get("cell_w", 150.0)),
		"cell_h": float(opts.get("cell_h", 150.0)),
		"cell_art": bool(opts.get("cell_art", true)),
		"content_frac": float(opts.get("piece_frac", 0.62)),   # the discovered piece, % of the cell
		"level_frac": float(opts.get("lvl_frac", 0.44)),       # the tier medal, % of the cell
		"mark_glow": float(opts.get("mark_glow", 0.6)),
		"mark_twinkle": float(opts.get("mark_twinkle", 0.5)),
		"calm": bool(opts.get("calm", false)),
	}

## A GRID of tier cells — plain reading order (tier 1 top-left, filling `cols` per row), exactly like the
## daily grid but with square tiles and NO woven vines (just the cards). The cell size scales to fit `cols`
## across the frame's content area; a partial last row centres.
static func _tiers_grid(entries: Array, width: float, opts: Dictionary) -> Control:
	var cols: int = maxi(1, int(opts.get("cols", 3)))
	var gap: int = int(opts.get("cell_gap", 16))
	# the cells fill the panel's INNER width — the card width minus the border's content padding on BOTH
	# sides. The discovery dialog uses the standard frame (no panel_pad override), so resolve the padding
	# from the chosen border — the SAME value dialog_frame pads to — keeping the right column inside it.
	var pad: float = float(opts.get("panel_pad_x", frame_border(String(opts.get("border", "parchment"))).get("pad_x", 26.0)))
	var avail: float = maxf(48.0, width - 2.0 * pad)
	var cw: float = maxf(40.0, (avail - (cols - 1) * gap) / float(cols))
	var aspect: float = float(opts.get("cell_h", 150.0)) / maxf(1.0, float(opts.get("cell_w", 150.0)))
	var co := opts.duplicate()
	co["cell_w"] = cw
	co["cell_h"] = cw * aspect
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", gap)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var made: Array = []
	var i := 0
	while i < entries.size():
		var r := HBoxContainer.new()
		r.alignment = BoxContainer.ALIGNMENT_CENTER
		r.add_theme_constant_override("separation", gap)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for j in cols:
			if i + j < entries.size():
				var c := tiers_card(entries[i + j], co)
				r.add_child(c)
				made.append(c)
		content.add_child(r)
		i += cols
	# re-derive from the ACTUAL laid-out width (covers the responsive width_pct), with a sub-pixel safety so
	# rounding never pushes the right column past the border. The face follows (it fills the holder), so the
	# cell art tracks this too.
	var fit := func() -> void:
		if not is_instance_valid(content):
			return
		var cwf := maxf(40.0, (content.size.x - (cols - 1) * gap) / float(cols) - 0.5)
		for c in made:
			if is_instance_valid(c):
				(c as Control).custom_minimum_size = Vector2(cwf, cwf * aspect)
	content.resized.connect(fit)
	fit.call_deferred()
	return content

## The DISCOVERY dialog — the SAME shared frame as mail/daily/shop, on a SELECTABLE border (opts.border,
## default the twig board), with the gold ladder ribbon + its own ✕ riding on top, wrapping a plain grid
## of tier cells. Only the border + banner/✕ chrome + the card differ; there are NO vines (just the cards).
static func tiers_dialog(entries: Array, width: float = 620.0, opts: Dictionary = {}) -> Control:
	return dialog_frame(_tiers_grid(entries, width, opts), width, opts)

## The SHOP dialog — the SAME shared frame, here filled with SECTIONS (each a vine divider + a centered
## row/grid of the SAME small card) rather than one flat grid. `sections` is [{caption, cards}, …] from
## demo_shop. Shared frame, sectioned shop content.
static func shop_dialog(sections: Array, width: float = 520.0, opts: Dictionary = {}) -> Control:
	return dialog_frame(_shop_sections(sections, width, opts), width, opts)

## A section divider — the section TITLE CENTRED (per the shop reference), flanked by leaf-sprig
## ornaments (kit/shop_sprig.png, cut from shop_asset.png; one mirrored) and a thin rule reaching each
## edge. (Replaces the old left-tab + vine strip.) Falls back to a plain centred title + rules if the
## sprig art is missing.
static func _kit_divider(caption: String) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.custom_minimum_size = Vector2(0, 40)
	var sp := Look.kit("kit/shop_sprig.png")
	var has_sprig := ResourceLoader.exists(sp)
	row.add_child(_div_rule())                         # left rule fills to the edge
	if has_sprig:
		row.add_child(_div_sprig(sp, false))           # leaves point INWARD, toward the title
	var cap := Label.new()
	cap.text = caption
	cap.add_theme_font_size_override("font_size", 23)
	cap.add_theme_color_override("font_color", Color(Pal.INK, 0.95))
	cap.add_theme_constant_override("outline_size", 0)
	cap.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(cap)
	if has_sprig:
		row.add_child(_div_sprig(sp, true))            # mirrored on the right
	row.add_child(_div_rule())                         # right rule fills to the edge
	return row

## A thin horizontal rule that fills the remaining width on a divider side.
static func _div_rule() -> Control:
	var line := ColorRect.new()
	line.color = Color(Pal.BARK, 0.30)
	line.custom_minimum_size = Vector2(0, 2)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line

## One leaf-sprig ornament flanking a divider title (optionally mirrored for the other side).
static func _div_sprig(path: String, flip: bool) -> Control:
	var t := TextureRect.new()
	t.texture = clean_tex_path(path, 256)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(46, 26)
	t.flip_h = flip
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

## The SHOP content: each section's vine divider + its cards laid into centered rows of `cols` (a 2-card
## section is a single centered row of two). Cards are built at the column width (like _card_grid) so they
## fit exactly, and `row_gap` adds generous breathing room BETWEEN rows + sections.
static func _shop_sections(sections: Array, width: float, opts: Dictionary) -> Control:
	var cols: int = maxi(1, int(opts.get("cols", 3)))
	var gap: int = int(opts.get("cell_h_gap", 12))
	var row_gap: int = int(opts.get("row_gap", 22))
	var cw: float = maxf(48.0, (width - 56.0 - (cols - 1) * gap) / float(cols))
	var aspect: float = float(opts.get("cell_h", 150.0)) / maxf(1.0, float(opts.get("cell_w", 112.0)))
	var co := opts.duplicate()
	co["cell_w"] = cw
	co["cell_h"] = cw * aspect      # keep the card's aspect ratio when it shrinks to fit cols across
	# (the card's fonts / icon / ribbon all scale from cell_w inside daily_card — uniform proportions)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", row_gap)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var made: Array = []
	for sec in sections:
		var s := sec as Dictionary
		content.add_child(_kit_divider(String(s.get("caption", ""))))
		var cards: Array = s.get("cards", [])
		var i := 0
		while i < cards.size():
			var r := HBoxContainer.new()
			r.alignment = BoxContainer.ALIGNMENT_CENTER
			r.add_theme_constant_override("separation", gap)
			r.mouse_filter = Control.MOUSE_FILTER_IGNORE
			for j in cols:
				if i + j < cards.size():
					var c := daily_card(cards[i + j], co)
					r.add_child(c)
					made.append(c)
			content.add_child(r)
			i += cols
	# pixel-exact: every card is 1/cols of the content width (so a 2-card row keeps the SAME card size),
	# with the aspect-correct height
	var fit := func() -> void:
		if not is_instance_valid(content):
			return
		var cwf := (content.size.x - (cols - 1) * gap) / float(cols)
		for c in made:
			if is_instance_valid(c):
				(c as Control).custom_minimum_size = Vector2(maxf(40.0, cwf), maxf(40.0, cwf * aspect))
	content.resized.connect(fit)
	fit.call_deferred()
	return content

## --- config → opts (the SINGLE source of the params→opts transform) ------------------------------
## The workbench saves design settings to a JSON of {button, card, dialog, icon} param dicts. Both the
## workbench preview AND the game build their dialog from these helpers, so there is no duplicated
## transform: change a setting in the workbench, save, and the game reads the very same config.

## Read the saved settings JSON into a config dict ({} if missing/garbage — callers fall back to defaults).
## CACHED per path: a scene build calls this once PER widget (every home button, pill, dialog), so an
## uncached read re-opened + re-parsed the file dozens of times per build. The config file is immutable
## during play, so the cache holds for the session; the workbench clears it on Save (clear_config_cache).
## The returned dict is treated as READ-ONLY by callers (every opts-builder duplicates before mutating).
static var _config_cache: Dictionary = {}     # path -> parsed config Dictionary

static func load_config(path: String) -> Dictionary:
	if _config_cache.has(path):
		return _config_cache[path]
	var data: Dictionary = {}
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		if f != null:
			var parsed = JSON.parse_string(f.get_as_text())
			f.close()
			if parsed is Dictionary:
				data = parsed
	_config_cache[path] = data
	return data

## Drop the cached config so the next load_config re-reads from disk. Pass a path to clear just that
## file, or nothing to clear all. The workbench calls this after writing the settings file.
static func clear_config_cache(path := "") -> void:
	_shell_cache.clear()   # the polished disc shell derives from the badge config — drop it so a saved edit re-polishes
	if path == "":
		_config_cache.clear()
	else:
		_config_cache.erase(path)

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
		"border": String(d.get("border", "parchment")),   # the shared Frame item's Border picker (default parchment)
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
		"sparkle": bool(dc.get("sparkle", true)),
		"label_y": float(dc.get("label_y", 12)),     # the "Day N" label's drop from the top edge
		"label_x": float(dc.get("label_x", 0)),      # the label's horizontal nudge
		"claim_y": float(dc.get("claim_y", 14)),     # how far the bottom action is lifted in from the base
		"info_icon": bool(dc.get("info_icon", false)),  # the top-right "i" disc toggle
		"ribbon_scale": float(dc.get("ribbon_scale", 100)) / 100.0,  # ribbon SIZE (stored as %, 100 = 1×)
		"ribbon_x": float(dc.get("ribbon_x", 0)),    # ribbon horizontal position
		"ribbon_y": float(dc.get("ribbon_y", -10)),  # ribbon vertical position (over the top edge)
		"btn": card_btn_opts(cfg),
	}

## The full DAILY-dialog opts: the SHARED frame + the separately-defined day card + the dialog-level
## grid (cols, default 3 — the 3-per-row reference layout). Used by the workbench + the game.
static func daily_opts_from_config(cfg: Dictionary) -> Dictionary:
	var o := dialog_opts_from_config(cfg)
	o.merge(daily_card_opts_from_config(cfg), true)
	var dl: Dictionary = cfg.get("daily", {})
	o["cols"] = int(dl.get("cols", 3))
	# the daily's OWN scroll cap (0 = no scroll, grows to fit all days) — NOT the frame's mail-list cap
	o["list_max_h"] = float(dl.get("list_max_h", 0))
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
	o["row_gap"] = float(sh.get("row_gap", 22))        # spacing between rows + sections (the dividers)
	o["list_max_h"] = float(sh.get("list_max_h", 0))   # the shop's OWN cap (0 = no scroll, show every item)
	return o

## The TIER-CELL opts from config — its own component (the discovery board's tile), read by both the card
## preview and the discovery dialog. The discovery tile IS the shared slot cell (filled / locked), so these
## map onto slot-cell opts in _tiers_to_slot_opts. Fractional knobs (content / medal size, sparkle amounts)
## are stored as PERCENTS for the integer sliders and divided here. The MARKED tier is flagged by the shared
## engine sparkle (mark_glow / mark_twinkle); the tier number rides the gold level medal docked lower-right
## (show_num → the slot cell's level).
static func tiers_card_opts_from_config(cfg: Dictionary) -> Dictionary:
	var tc: Dictionary = cfg.get("tiers_card", {})
	return {
		"cell_w": float(tc.get("cell_w", 150)),
		"cell_h": float(tc.get("cell_h", 150)),
		"cell_art": bool(tc.get("cell_art", true)),
		"show_num": bool(tc.get("show_num", true)),              # the tier rides the lower-right level medal
		"piece_frac": float(tc.get("piece_frac", 62)) / 100.0,   # the discovered piece, % of the cell
		"lvl_frac": float(tc.get("lvl_frac", 44)) / 100.0,       # the tier medal, % of the cell
		"mark_glow": float(tc.get("mark_glow", 60)) / 100.0,     # the marked tier's sparkle glow (0 = off)
		"mark_twinkle": float(tc.get("mark_twinkle", 50)) / 100.0,  # ...and its drifting twinkles (0 = off)
	}

## The full DISCOVERY-dialog opts: the STANDARD shared frame, exactly like daily/shop/settings — it inherits
## dialog_opts_from_config wholesale (border, banner ribbon, ✕, geometry, padding), with NO bespoke chrome
## override. Only the discovery CONTENT differs: the tier grid (cols, gaps, scroll cap) + the tier-cell look.
## Edit the frame on the shared Frame item and it flows here too. (The banner TEXT is the line name, passed
## by the caller.)
static func tiers_opts_from_config(cfg: Dictionary) -> Dictionary:
	var o := dialog_opts_from_config(cfg)
	o.merge(tiers_card_opts_from_config(cfg), true)   # the tier-cell look (cell size, level medal, sparkle)
	var t: Dictionary = cfg.get("tiers", {})
	# the grid (no vines): cols + the inter-cell gap + the discovery's OWN scroll cap (0 = show every tier)
	o["cols"] = int(t.get("cols", 3))
	o["cell_gap"] = int(t.get("cell_gap", 16))
	o["list_max_h"] = float(t.get("list_max_h", 0))
	return o

## The TOGGLE-CARD style opts from config (label font · switch size · parchment vs pill). The toggle card
## is its OWN component, so both the workbench card preview AND the settings dialog read it from here.
static func toggle_card_opts_from_config(cfg: Dictionary) -> Dictionary:
	var tc: Dictionary = cfg.get("toggle_card", {})
	return {
		"label_font": int(tc.get("label_font", 28)),
		"switch_h": float(tc.get("switch_h", 44)),
		"card_art": bool(tc.get("card_art", true)),
	}

## The full SETTINGS-dialog opts: the SHARED frame + the toggle-card style (under opts["toggle"]) + the
## settings dialog's OWN width / row spacing. Used by the workbench preview AND the game settings card.
static func settings_opts_from_config(cfg: Dictionary) -> Dictionary:
	var o := dialog_opts_from_config(cfg)
	o["toggle"] = toggle_card_opts_from_config(cfg)
	var st: Dictionary = cfg.get("settings", {})
	o["row_gap"] = float(st.get("row_gap", 12))   # gap between toggle rows
	return o

## The full VAULT-dialog opts: the SHARED frame (banner / close styling inherited from the Frame item)
## + the new TWIG border forced on + the vault's own tuned slice / pad / jar size from its config block.
## Used by BOTH the workbench preview and the game (engine/scripts/ui/vault.gd) — one builder, no
## duplicated face.
static func vault_opts_from_config(cfg: Dictionary) -> Dictionary:
	var o := dialog_opts_from_config(cfg)
	var v: Dictionary = cfg.get("vault", {})
	o["border"] = "vault twig"                            # the new frame option (forced for the vault)
	var sl: float = float(v.get("card_slice", 64))
	o["card_slice_l"] = sl; o["card_slice_t"] = sl; o["card_slice_r"] = sl; o["card_slice_b"] = sl
	o["panel_pad_x"] = float(v.get("panel_pad_x", 40))
	o["panel_pad_y"] = float(v.get("panel_pad_y", 34))
	o["card_art"] = true
	o["banner_icon_id"] = "piggy"                         # reuse the existing icon_piggy sprite
	o["jar_px"] = float(v.get("jar_px", 200))
	o["plate_px"] = float(v.get("plate_px", 250))
	o["balance_font"] = int(v.get("balance_font", 34))
	o["row_gap"] = float(v.get("row_gap", 12))
	return o

## The badge (disc-shell) edge polish from config — the standalone Badge item's defringe / feather /
## shadow. The home button's shell reads this, so a Badge tweak flows to the rail + nav automatically.
static func badge_polish_from_config(cfg: Dictionary) -> Dictionary:
	var b: Dictionary = cfg.get("badge", {})
	return {
		"defringe": bool(b.get("defringe", false)),
		"feather": float(b.get("feather", 0)),
		"shadow": bool(b.get("shadow", false)),
	}

## The reusable PROGRESS BAR's saved STYLE from config (height / art / star knob). The Level dialog and
## the standalone workbench preview both read it from here.
static func progress_bar_opts_from_config(cfg: Dictionary) -> Dictionary:
	var p: Dictionary = cfg.get("progress_bar", {})
	return {
		"height": float(p.get("height", 20)),
		"art": bool(p.get("art", true)),
		"star_knob": bool(p.get("star_knob", false)),
	}

## The LEVEL dialog's saved STYLE from config — the dedicated frame chrome + the medallion size + the
## reusable progress-bar style + the shared button style. Read by BOTH the workbench preview and the
## game's level_popup.gd, so the transform lives in one place.
static func level_opts_from_config(cfg: Dictionary) -> Dictionary:
	var lv: Dictionary = cfg.get("level", {})
	return {
		"banner_text": String(lv.get("banner_text", "Level")),
		"title_font": int(lv.get("title_font", 30)),
		"slice": float(lv.get("frame_slice", 56)),
		"pad": float(lv.get("frame_pad", 26)),
		"top_pad": float(lv.get("frame_top_pad", 70)),
		"medallion_px": float(lv.get("medallion_px", 120)),
		"ring_dy": float(lv.get("ring_dy", 0)),
		"tally_font": int(lv.get("tally_font", 28)),
		"hint_font": int(lv.get("hint_font", 22)),
		"gap": int(lv.get("gap", 14)),
		"progress": progress_bar_opts_from_config(cfg),
		"btn": _level_btn_opts(cfg),
	}

## The Level dialog's button STYLE — the shared Button opts, but with the font overridable PER LEVEL
## DIALOG (lv.btn_font), so the Got-it / Collect label can be sized up here without touching every other
## button. Falls back to the shared button's font when the level hasn't set its own.
static func _level_btn_opts(cfg: Dictionary) -> Dictionary:
	var lv: Dictionary = cfg.get("level", {})
	var btn: Dictionary = card_btn_opts(cfg)
	btn["font"] = int(lv.get("btn_font", int(btn.get("font", 22))))
	return btn

## The shared HOME-BUTTON style opts from a saved config — the round icon button used by the home page's
## side rail and bottom nav. Slider values are stored 0..100 (icon_scale / glow / twinkle), divided here
## to the 0..1 the builder wants. The caller adds `calm` and overrides `px` per call site (rail vs nav).
static func home_button_opts_from_config(cfg: Dictionary) -> Dictionary:
	var h: Dictionary = cfg.get("home_button", {})
	return {
		"px": float(h.get("px", 140)),
		"shell": HOME_SHELL,
		"icon_scale": float(h.get("icon_scale", 50)) / 100.0,
		"caption_font": int(h.get("caption_font", 22)),
		"caption_gap": float(h.get("caption_gap", 4)),
		"glow": float(h.get("glow", 0)) / 100.0,
		"twinkle": float(h.get("twinkle", 0)) / 100.0,
		"badge": badge_polish_from_config(cfg),    # the Badge item's shell polish (defringe / feather / shadow)
	}

## The HOME-UNLOCK style opts from a saved config — the restore-cost disc on an unowned home spot.
## disc_pct is the disc diameter as a % of the MAP width (the caller multiplies it by its own width and
## sets opts.px); plus_scale / icon_scale / cost_font / stack_gap / icon_gap are stored 0..100 and divided
## here to the 0..1 fractions of the disc the builder wants (stack_gap may be negative — a tuck-up).
static func home_unlock_opts_from_config(cfg: Dictionary) -> Dictionary:
	var u: Dictionary = cfg.get("home_unlock_button", {}) if cfg is Dictionary else {}
	return {
		"disc_pct": float(u.get("disc_pct", 16)),
		"plus_scale": float(u.get("plus_scale", 30)) / 100.0,
		"icon_scale": float(u.get("icon_scale", 26)) / 100.0,
		"cost_font": float(u.get("cost_font", 26)) / 100.0,
		"stack_gap": float(u.get("stack_gap", -1)) / 100.0,
		"icon_gap": float(u.get("icon_gap", 2)) / 100.0,
		# the optional engine-drawn sparkle (glow halo + drifting twinkles), like the home button. Default 0
		# → no sparkle, so the in-game disc is unchanged until a designer dials it up. calm added by caller.
		"glow": float(u.get("glow", 0)) / 100.0,
		"twinkle": float(u.get("twinkle", 0)) / 100.0,
	}

## The shared CURRENCY-PILL style opts from a saved config — padding, border, font and the look knobs of
## the top-bar wallet. EVERY default mirrors Tune.Hud (engine/scripts/core/tuning.gd → class Hud), so an
## absent or empty "currency_pill" block resolves to the SHIPPED pill and the live HUD is unchanged.
## grove_ui_tests pins these defaults to Tune (the R1 even-wrap contract depends on it).
static func currency_pill_opts_from_config(cfg: Dictionary) -> Dictionary:
	var c: Dictionary = cfg.get("currency_pill", {}) if cfg is Dictionary else {}
	return {
		"use_art":     bool(c.get("use_art", true)),       # painted capsule (panel_pill.png) vs code-drawn pill
		"border":      String(c.get("border", "gold capsule")),   # which painted capsule (PILL_BORDERS) — art path only
		"pad_x":       float(c.get("pad_x", 18.0)),        # Tune.CLUSTER_PAD_X — horizontal content margin
		"pad_y":       float(c.get("pad_y", 12.0)),        # Tune.PILL_PAD_Y — vertical content margin
		"radius":      int(c.get("radius", 40)),           # Tune.PILL_RADIUS (code-drawn pill only)
		"border_w":    int(c.get("border_w", 3)),          # Tune.PILL_BORDER_W (code-drawn pill only)
		"shadow_size": int(c.get("shadow_size", 5)),       # Tune.PILL_SHADOW_SIZE (0 = no shadow; code-drawn only)
		"num_size":    int(c.get("num_size", 34)),         # Tune.NUM_SIZE — the currency number font
		"icon_box":    float(c.get("icon_box", 40.0)),     # Tune.CHIP_ICON_BOX — the shared square icon box
		"row_sep":     int(c.get("row_sep", 4)),           # Tune.CHIP_ROW_SEP — icon↔number gap
		"pair_sep":    int(c.get("pair_sep", 14)),         # Tune.PAIR_SEP — gap between currency pairs
	}

## The currency pill's panel StyleBox from resolved opts. Prefers the painted nine-patch capsule (caps
## fixed, middle stretches); the border / radius / shadow knobs drive the code-drawn fallback (use_art
## off, or the art missing). Padding (content margins) applies on BOTH paths. hud.gd and the workbench
## preview both call this, so the pill's look lives in exactly one place.
static func currency_pill_style(opts: Dictionary) -> StyleBox:
	var pad_x := float(opts.get("pad_x", 18.0))
	var pad_y := float(opts.get("pad_y", 12.0))
	if bool(opts.get("use_art", true)):
		var bd: Dictionary = pill_border(String(opts.get("border", "gold capsule")))
		var p := Look.kit(String(bd["art"]))
		if ResourceLoader.exists(p):
			var sbt := StyleBoxTexture.new()
			sbt.texture = load(p)
			sbt.set_texture_margin_all(int(bd["cap"]))   # cap radius: the rounded ends never squash
			sbt.content_margin_left = pad_x
			sbt.content_margin_right = pad_x
			sbt.content_margin_top = pad_y
			sbt.content_margin_bottom = pad_y
			return sbt
	var sb := StyleBoxFlat.new()
	sb.bg_color = CUR_PILL_BG
	sb.set_corner_radius_all(int(opts.get("radius", 40)))
	sb.set_border_width_all(int(opts.get("border_w", 3)))
	sb.border_color = CUR_PILL_BORDER
	sb.shadow_color = CUR_PILL_SHADOW
	sb.shadow_size = int(opts.get("shadow_size", 5))
	sb.content_margin_left = pad_x
	sb.content_margin_right = pad_x
	sb.content_margin_top = pad_y
	sb.content_margin_bottom = pad_y
	return sb

## A standalone, faithful currency pill for the workbench gallery: the styled panel wrapping the
## ★ 🪙 💎 row, sized from the same opts the live HUD reads. `counts` supplies the sample numbers
## (the wallet shows live values in-game; here they are preview-only). Self-contained — no game state.
static func currency_pill(opts: Dictionary, counts: Dictionary = {}) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", currency_pill_style(opts))
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var row := HBoxContainer.new()
	var row_sep := int(opts.get("row_sep", 4))
	row.add_theme_constant_override("separation", row_sep)   # the tight icon↔number gap
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(row)
	var num := int(opts.get("num_size", 34))
	var box := float(opts.get("icon_box", 40.0))
	var pair_sep := int(opts.get("pair_sep", 14))
	var demo := {"star": 1280, "coin": 540, "gem": 36}
	# the icon set is the 3-currency wallet by default; a caller (e.g. the bag's acorn balance) can pass
	# opts["icons"] = [[id, px], …] to render a SUBSET (or a single currency) in the same capsule.
	var icons: Array = opts.get("icons", CUR_PILL_ICONS)
	for i in icons.size():
		if i > 0:
			# the WIDER gap between pairs is an explicit spacer (matches hud.gd's _spacer)
			var s := Control.new()
			s.custom_minimum_size = Vector2(float(pair_sep - row_sep), 0)
			s.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(s)
		var id := String(icons[i][0])
		var icon_px := float(icons[i][1])
		var cc := CenterContainer.new()
		cc.custom_minimum_size = Vector2(box, box)
		cc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cc.add_child(make_icon(id, icon_px))
		row.add_child(cc)
		var lbl := Label.new()
		lbl.text = str(int(counts.get(id, demo.get(id, 0))))
		lbl.add_theme_font_size_override("font_size", num)
		lbl.add_theme_color_override("font_color", Pal.INK)
		lbl.add_theme_constant_override("outline_size", 0)   # panel-text law: no halo on a solid pill
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(lbl)
	return panel

## --- the bag screen: the slot CELL + the dialog -----------------------------------------------------
## The slot cell is ONE component card with four states. A filled slot uses the raised card (a held
## piece sits on it); empty / next / locked SHARE the flat empty-slot card (bag_card_empty.png) so they
## read as one component at one size — the state (lock + cost, the buyable sparkle, the locked dim) is an
## overlay, not a different sprite. The old gold sparkle card is gone; `next` gets a DYNAMIC sparkle FX.
const SLOT_EMPTY_ART := "board/slot_tile.png"    # the open cream well — empty / filled
const SLOT_LOCKED_ART := "board/slot_locked.png" # the same well + the baked gold padlock — locked / unlockable

## The BAG-CELL opts from config — the slot tile's saved STYLE. Its own component (the bag dialog reuses
## it), read by both the workbench card preview and the bag dialog/overlay. Fractional knobs (the piece /
## lock size as a % of the cell) are stored as integer percents for the sliders and divided here.
static func bag_card_opts_from_config(cfg: Dictionary) -> Dictionary:
	var bc: Dictionary = cfg.get("bag_card", {})
	return {
		"cell_w": float(bc.get("cell_w", 116)),
		"cell_h": float(bc.get("cell_h", 120)),
		"cell_slice": float(bc.get("cell_slice", 28)),               # the well's nine-patch corner margin
		"cell_art": bool(bc.get("cell_art", true)),
		"content_frac": float(bc.get("content_frac", 62)) / 100.0,   # a held piece, % of the cell
		"cost_font": int(bc.get("cost_font", 24)),                   # the acorn-cost number
		"cost_icon": float(bc.get("cost_icon", 26)),                 # the acorn icon px in a cost row
		"cost_y": float(bc.get("cost_y", 0)),                        # nudge the acorn cost up(-) / down(+), px
		"level_frac": float(bc.get("level_frac", 44)) / 100.0,       # the level badge size, % of the cell
		"next_glow": float(bc.get("next_glow", 45)) / 100.0,         # the unlockable highlight's glow halo
		"next_twinkle": float(bc.get("next_twinkle", 55)) / 100.0,   # ...and its drifting-star density
	}

## One SLOT CELL — the shared bag + board cell, on the board's cream-well art. `d.state` (or the legacy
## `d.kind`) picks the look + behaviour:
##   empty      — the open cream well (seen / unlocked / owned-empty), inert
##   filled     — the open well + a piece on top; a tap fires d.on_tap (retrieve)
##   locked     — the well with the BAKED gold padlock (unseen / gated), inert
##   unlockable — the locked well, HIGHLIGHTED (gold border + glow + dynamic sparkle), full opacity; a
##                tap fires d.on_tap (buy / open). The bag's "next" maps here.
## Optional overlays (a cell shows what is passed): d.cost (int) → the acorn cost near the lower edge,
## under the baked lock (bag); d.level (int) → Look.make_level_badge docked lower-right — the SAME HUD
## level badge (board / discovery tier); d.marked (bool) → the engine sparkle over the well, under the
## piece (the discovery ladder's tapped tier); d.dim (0..1) sets the cell's modulate alpha (the board's
## receded deep locks). The piece is content-agnostic so the kit stays free of game deps: d.make_content
## (size) (a Callable that builds the game's piece view at the FITTED size) wins, else d.content (a node),
## else d.icon (a kit icon id), else nothing. Every state returns a tile of exactly cell_w × cell_h. A
## code-drawn well backs every state when the art is off/absent (the kit fallback law).
## d keys: state|kind, make_content|content|icon, cost, level, marked, dim, on_tap. opts: bag_card_opts_from_config(...).
static func slot_cell(d: Dictionary, opts: Dictionary = {}) -> Control:
	var state := String(d.get("state", d.get("kind", "empty")))
	if state == "next":
		state = "unlockable"          # the bag's "next" == the board's highlighted openable
	var cw := float(opts.get("cell_w", 116.0))
	var ch := float(opts.get("cell_h", 120.0))
	var cost_font := int(opts.get("cost_font", 24))
	var cost_icon := float(opts.get("cost_icon", 26.0))
	var cost_y := float(opts.get("cost_y", 0.0))
	var on_tap: Callable = d.get("on_tap", Callable())
	var tappable := on_tap.is_valid() and (state == "filled" or state == "unlockable")
	var lockedwell := (state == "locked" or state == "unlockable")   # both show the baked-lock well

	var tile: Control = (Button.new() if tappable else Control.new())
	tile.custom_minimum_size = Vector2(cw, ch)
	tile.size = Vector2(cw, ch)            # explicit, so the board (absolute layout) sizes it; a grid overrides
	tile.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if tile is Button:
		var b := tile as Button
		b.focus_mode = Control.FOCUS_NONE
		b.flat = true
		b.pressed.connect(func() -> void:
			if on_tap.is_valid(): on_tap.call())

	# the cell FACE — the board's cream well as a NINE-PATCH (crisp corners at any cell size): slot_tile
	# (empty / filled) or slot_locked (locked / unlockable — the well with the baked padlock).
	var art := (SLOT_LOCKED_ART if lockedwell else SLOT_EMPTY_ART)
	if bool(opts.get("cell_art", true)) and ResourceLoader.exists(Look.kit(art)):
		var face := Panel.new()
		face.set_anchors_preset(Control.PRESET_FULL_RECT)
		var sbt := StyleBoxTexture.new()
		sbt.texture = load(Look.kit(art))
		sbt.set_texture_margin_all(float(opts.get("cell_slice", 28.0)))
		face.add_theme_stylebox_override("panel", sbt)
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(face)
	else:
		var p := Panel.new()
		p.set_anchors_preset(Control.PRESET_FULL_RECT)
		var ss := StyleBoxFlat.new()
		ss.bg_color = (Color(Pal.CREAM, 0.55) if lockedwell else Color(Pal.CREAM, 0.92))
		ss.set_corner_radius_all(int(maxf(10.0, cw * 0.16)))
		ss.set_border_width_all(2)
		ss.border_color = Color(Pal.GROUND_EDGE, 0.4)
		p.add_theme_stylebox_override("panel", ss)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(p)

	# a MARKED cell (the discovery ladder's tapped/asked tier) wears the SAME engine sparkle the home
	# buttons use, sitting over the well but UNDER the piece — an overlay, so the footprint never changes.
	# The board + bag don't set this; the discovery cell does.
	if bool(d.get("marked", false)):
		var mglow := float(opts.get("mark_glow", 0.6))
		var mtwinkle := float(opts.get("mark_twinkle", 0.5))
		if mglow > 0.0 or mtwinkle > 0.0:
			var msp := _sparkle_overlay(cw, mglow, mtwinkle, bool(opts.get("calm", false)))
			msp.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tile.add_child(msp)

	# filled — the piece, centred, built at the FITTED cell size (content-agnostic).
	if state == "filled":
		var piece_px := cw * float(opts.get("content_frac", 0.62))
		var piece: Control = null
		var mk: Callable = d.get("make_content", Callable())
		if mk.is_valid():
			piece = mk.call(piece_px)
		elif d.get("content") is Control:
			piece = d.get("content")
		elif String(d.get("icon", "")) != "":
			piece = make_icon(String(d.icon), piece_px)
		if piece != null:
			piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var pc := CenterContainer.new()
			pc.set_anchors_preset(Control.PRESET_FULL_RECT)
			pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
			pc.add_child(piece)
			tile.add_child(pc)

	# the acorn cost (bag) — under the baked lock, near the lower edge.
	var cost := int(d.get("cost", 0))
	if cost > 0 and lockedwell:
		var cwrap := CenterContainer.new()
		cwrap.anchor_left = 0.0; cwrap.anchor_right = 1.0
		cwrap.anchor_top = 1.0; cwrap.anchor_bottom = 1.0
		cwrap.offset_top = -float(cost_font) - ch * 0.12 + cost_y
		cwrap.offset_bottom = -ch * 0.06 + cost_y
		cwrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cwrap.add_child(_bag_cost_row(cost, cost_icon, cost_font))
		tile.add_child(cwrap)

	# the level badge (board) — the SAME HUD level medal, carrying THIS cell's level, docked lower-right.
	var level := int(d.get("level", 0))
	if level > 0:
		var lvpx := maxf(28.0, cw * float(opts.get("level_frac", 0.44)))
		var badge := Look.make_level_badge(level, lvpx)
		badge.anchor_left = 1.0; badge.anchor_top = 1.0; badge.anchor_right = 1.0; badge.anchor_bottom = 1.0
		badge.offset_left = -lvpx - cw * 0.04
		badge.offset_top = -lvpx - cw * 0.04
		badge.offset_right = -cw * 0.04
		badge.offset_bottom = -cw * 0.04
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(badge)

	# unlockable — the shared HIGHLIGHT: a warm-gold border + glow (the board's "pop") AND the dynamic
	# sparkle (the bag's next), drawn OVER the well so it reads as the live, actionable cell.
	if state == "unlockable":
		var pop := Panel.new()
		pop.set_anchors_preset(Control.PRESET_FULL_RECT)
		var ps := StyleBoxFlat.new()
		ps.bg_color = Color(0, 0, 0, 0)
		ps.set_border_width_all(4)
		ps.border_color = Pal.STRAW
		ps.set_corner_radius_all(int(maxf(10.0, cw * 0.18)))
		ps.shadow_color = Color(Pal.STRAW, 0.55)
		ps.shadow_size = int(maxf(4.0, cw * 0.10))
		pop.add_theme_stylebox_override("panel", ps)
		pop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(pop)
		var glow := float(opts.get("next_glow", 0.45))
		var twinkle := float(opts.get("next_twinkle", 0.55))
		if glow > 0.0 or twinkle > 0.0:
			var spk := _sparkle_overlay(cw, glow, twinkle, bool(opts.get("calm", false)))
			spk.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tile.add_child(spk)

	# the board's deep (non-frontier) locks recede — the caller passes d.dim (1.0 = full opacity).
	var dim := float(d.get("dim", 1.0))
	if dim < 1.0:
		tile.modulate = Color(1, 1, 1, dim)
	return tile

## Backward-compat alias: the bag screen + its tests/config call bag_card (kind=…); the board calls
## slot_cell (state=…). ONE builder.
static func bag_card(d: Dictionary, opts: Dictionary = {}) -> Control:
	return slot_cell(d, opts)

# An "N 🌰" acorn-cost cluster (the gem currency icon = the golden acorn) — inside the next tile and
# under a lock. Mouse-transparent so the tile keeps the tap.
static func _bag_cost_row(cost: int, icon_px: float, font: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lbl := Label.new()
	lbl.text = str(cost)
	lbl.add_theme_font_size_override("font_size", font)
	lbl.add_theme_color_override("font_color", Pal.INK)
	lbl.add_theme_constant_override("outline_size", 0)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lbl)
	row.add_child(make_icon("gem", icon_px))
	return row

## The full BAG-dialog opts: the SHARED frame + the bag-cell style + the reused currency-pill style +
## the dialog's own grid (cols, default 6 — the reference's six-wide ladder). Same construction as the
## daily/settings dialogs. Used by the workbench preview AND the game (engine/scripts/ui/bag_overlay.gd).
static func bag_opts_from_config(cfg: Dictionary) -> Dictionary:
	var o := dialog_opts_from_config(cfg)
	o.merge(bag_card_opts_from_config(cfg), true)
	o["pill"] = currency_pill_opts_from_config(cfg)   # the reused pill's style (single-acorn at build time)
	var bg: Dictionary = cfg.get("bag", {})
	o["cols"] = int(bg.get("cols", 6))
	o["cell_gap"] = int(bg.get("cell_gap", 12))
	o["grid_inset"] = float(bg.get("grid_inset", 70))  # how much the parchment border/padding eats the grid width
	o["row_gap"] = float(bg.get("row_gap", 14))        # gap between the pill / grid / footer rows
	o["list_max_h"] = float(bg.get("list_max_h", 0))   # the bag's OWN scroll cap (0 = no scroll, 18 slots fit)
	o["caption"] = String(bg.get("caption", "Open a slot with acorns."))
	o["banner_text"] = String(bg.get("banner_text", "Bag"))
	o["banner_icon_on"] = false                        # the reference's "Bag" ribbon is text-only (no envelope)
	return o

## The BAG dialog — the SHARED frame wrapping the bag screen: the reused currency pill (the single-acorn
## balance, docked top-right), a grid of bag cells (the slot ladder), and a leaf-flanked footer caption.
## The direct sibling of daily_dialog: same chrome, the bag's content. `entries` is an Array of bag_card
## data dicts (already classified by the caller — the game's slot_plan, or the workbench's DEMO_BAG);
## `balance` is the acorn count. opts["extra"] (optional) is a game-only section (the generators row)
## inserted below the grid. Used by BOTH the workbench preview and the game (ui/bag_overlay.gd).
static func bag_dialog(entries: Array, balance: int, width: float = 560.0, opts: Dictionary = {}) -> Control:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", int(opts.get("row_gap", 14)))
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# the acorn-balance pill, docked top-right — the REUSED currency pill in single-currency (acorn) mode.
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_END
	top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pill_opts: Dictionary = (opts.get("pill", {}) as Dictionary).duplicate()
	pill_opts["icons"] = [["gem", float(opts.get("balance_icon", 38.0))]]
	top.add_child(currency_pill(pill_opts, {"gem": balance}))
	content.add_child(top)

	# the slot grid — the six-wide ladder. The cells SCALE to fit `cols` across the frame's content width
	# (width − the border/padding inset − the gaps), so the grid never overflows the parchment (like the
	# tiers/daily grids); every cell metric scales from that fitted cell_w. A partial last row centres.
	var cols := maxi(1, int(opts.get("cols", 6)))
	var gap := int(opts.get("cell_gap", 12))
	var inset := float(opts.get("grid_inset", 70.0))
	var base_w := float(opts.get("cell_w", 116.0))
	var aspect := float(opts.get("cell_h", 120.0)) / maxf(1.0, base_w)
	var cw := maxf(40.0, (width - inset - float(cols - 1) * float(gap)) / float(cols))
	var fit_scale := cw / maxf(1.0, base_w)
	var cell_opts := opts.duplicate()
	cell_opts["cell_w"] = cw
	cell_opts["cell_h"] = cw * aspect
	cell_opts["cost_font"] = int(float(opts.get("cost_font", 26)) * fit_scale)
	cell_opts["cost_icon"] = float(opts.get("cost_icon", 30.0)) * fit_scale
	var grid := GridContainer.new()
	grid.columns = cols
	grid.add_theme_constant_override("h_separation", gap)
	grid.add_theme_constant_override("v_separation", gap)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for e in entries:
		grid.add_child(bag_card(e, cell_opts))
	var grid_wrap := CenterContainer.new()
	grid_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid_wrap.add_child(grid)
	content.add_child(grid_wrap)

	# an optional game-only section (the stored-generators row) below the grid
	if opts.get("extra") is Control:
		content.add_child(opts.get("extra"))

	content.add_child(_bag_footer(String(opts.get("caption", "Open a slot with acorns."))))
	return dialog_frame(content, width, opts)

# The bag footer caption flanked by the bag leaf sprigs (bag_leaf_l/r.png), or text alone when absent.
static func _bag_footer(text: String) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ll := _bag_leaf("kit/bag_leaf_l.png", false)
	if ll != null:
		row.add_child(ll)
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.add_theme_color_override("font_color", Color(Pal.BARK, 0.85))
	lbl.add_theme_constant_override("outline_size", 0)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lbl)
	var lr := _bag_leaf("kit/bag_leaf_r.png", true)
	if lr != null:
		row.add_child(lr)
	return row

static func _bag_leaf(rel: String, flip: bool) -> Control:
	var p := Look.kit(rel)
	if not ResourceLoader.exists(p):
		return null
	var t := TextureRect.new()
	t.texture = clean_tex_path(p, 96)
	t.flip_h = flip
	t.custom_minimum_size = Vector2(40, 34)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

## The map-SELECT place-picker CARD, built from game-resolved DATA + workbench-tuned presentation.
## `d`: { open:bool, done:bool, art:String (locale-art path, "" → meadow fill), stars_left:int,
##        prereq:String (the locked "✿ after <prev>" line), map_id:String (the veil-art seam) }.
## `opts`: map_card_opts_from_config(...). The CALLER sizes the card (card_w × card_h); the kit lays the
## frame / art / pill out inside it. Every node IGNOREs the mouse (the map's single-input-surface rule).
static func map_card(d: Dictionary, opts: Dictionary, card_w: float, card_h: float) -> Control:
	var card := Control.new()
	card.custom_minimum_size = Vector2(card_w, card_h)
	card.size = Vector2(card_w, card_h)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if bool(d.get("open", true)):
		_map_card_open(d, opts, card, card_w, card_h)
	else:
		_map_card_locked(d, opts, card, card_w, card_h)
	return card

# An OPEN place: the locale art (or a meadow fallback) fills the hollow of the gold frame, drawn OVER it
# so the frame's transparent centre lets the art show and its border frames it; the restore count rides a
# pill on the lower edge.
static func _map_card_open(d: Dictionary, opts: Dictionary, card: Control, card_w: float, card_h: float) -> void:
	# The locale art FILLS THE CARD, masked to the gold frame's exact silhouette (see MAP_ART_CLIP_SHADER),
	# so it nests under the gold border and never leaks past the rounded corners. A ColorRect carries the
	# COVER-sample + mask shader; its UV spans the card, the same space as the frame, so the mask lines up.
	var card_size := Vector2(card_w, card_h)
	var art_path := String(d.get("art", ""))
	var fill_tex: Texture2D = load(art_path) if art_path != "" and ResourceLoader.exists(art_path) else _map_meadow_texture()
	var t := ColorRect.new()
	t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	t.material = _map_art_material(fill_tex, card_size)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(t)
	if fill_tex == _map_meadow_texture():
		card.add_child(_map_place_mark(opts))   # the ✿ "place" mark over the bare meadow fill
	# the gold frame OVER the art — card sized to its aspect, so a plain SCALE keeps the border crisp.
	var frame_path := Look.kit(MAP_CARD_ACTIVE)
	if bool(opts.get("use_art", true)) and ResourceLoader.exists(frame_path):
		var fr := TextureRect.new()
		fr.texture = load(frame_path)
		fr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		fr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		fr.stretch_mode = TextureRect.STRETCH_SCALE
		fr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(fr)
	else:
		card.add_child(_map_code_border())
	_map_count_pill(d, opts, card, card_w, card_h)
	# ACTIVE place (open but not yet restored): ring the gold band with twinkles to draw the eye. A
	# DONE/restored card stays quiet (its pill already says "restored"); the amount is workbench-tuned.
	if not bool(d.get("done", false)):
		var spark := float(opts.get("edge_sparkle", 0.6))
		if spark > 0.0:
			card.add_child(_map_card_edge_sparkle(card_w, card_h, spark, bool(opts.get("calm", false))))

# A LOCKED place: the dark baked panel fills the card, with the "after <prev>" prerequisite line low over
# it. When the panel art is off/missing, fall back to a meadow panel under the §8 fog veil so the horizon
# still reads as veiled.
static func _map_card_locked(d: Dictionary, opts: Dictionary, card: Control, card_w: float, card_h: float) -> void:
	var panel_path := Look.kit(MAP_CARD_LOCKED)
	if bool(opts.get("use_art", true)) and ResourceLoader.exists(panel_path):
		var p := TextureRect.new()
		p.texture = load(panel_path)
		p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		p.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		p.stretch_mode = TextureRect.STRETCH_SCALE
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(p)
	else:
		var inner := _map_meadow_fill(false, opts)
		inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		card.add_child(inner)
		_map_veil(inner, String(d.get("map_id", "")), opts)   # the §8 code-drawn fog when the painted panel is absent
	# the prerequisite line, low on the panel (the baked medallion is the centre mark).
	var state_l := Label.new()
	state_l.text = String(d.get("prereq", ""))
	state_l.add_theme_font_size_override("font_size", int(clampf(card_h * 0.135, 18.0, 30.0)))
	state_l.add_theme_color_override("font_color", Color(Pal.CREAM, 0.88))
	state_l.add_theme_color_override("font_outline_color", Pal.INK)
	state_l.add_theme_constant_override("outline_size", 5)
	state_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	state_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	state_l.autowrap_mode = TextServer.AUTOWRAP_WORD
	state_l.position = Vector2(card_w * 0.12, card_h - card_h * 0.30)
	state_l.size = Vector2(card_w * 0.76, card_h * 0.24)
	state_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(state_l)

# The restore count on an open card's lower edge: a cream pill (pill_left) carrying the GOLD star sprite
# + "N left" (panel-text law: dark INK, no halo), or "✿ restored" on a finished place.
static func _map_count_pill(d: Dictionary, opts: Dictionary, card: Control, card_w: float, card_h: float) -> void:
	var done := bool(d.get("done", false))
	var pw := clampf(card_w * float(opts.get("pill_w_frac", 0.30)), float(opts.get("pill_min", 170.0)), float(opts.get("pill_max", 290.0)))
	var ph := pw / MAP_CARD_PILL_ASPECT
	var node := Control.new()
	node.size = Vector2(pw, ph)
	# sit in the lower body, ABOVE the frame's bottom gold band so the pill never overlaps the border.
	node.position = Vector2((card_w - pw) * 0.5, card_h - ph - card_h * float(opts.get("pill_y_frac", 0.13)))
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(node)
	var pill_path := Look.kit(MAP_CARD_PILL)
	if bool(opts.get("use_art", true)) and ResourceLoader.exists(pill_path):
		var bg := TextureRect.new()
		bg.texture = load(pill_path)
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_SCALE
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.add_child(bg)
	else:
		var pnl := Panel.new()
		pnl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var ps := StyleBoxFlat.new()
		ps.bg_color = Pal.CREAM
		ps.set_corner_radius_all(int(ph * 0.5))
		ps.set_border_width_all(3)
		ps.border_color = Pal.STRAW
		pnl.add_theme_stylebox_override("panel", ps)
		pnl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.add_child(pnl)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(row)
	if done:
		var lbl := Label.new()
		lbl.text = String(TranslationServer.translate("✿ restored"))   # static ctx: tr() is instance-only
		lbl.add_theme_font_size_override("font_size", int(ph * 0.42))
		lbl.add_theme_color_override("font_color", Pal.INK)
		lbl.add_theme_constant_override("outline_size", 0)
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(lbl)
	else:
		var ic := Look.icon("star", ph * 0.50)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(ic)
		var lbl := Label.new()
		lbl.text = String(TranslationServer.translate("%d left")) % int(d.get("stars_left", 0))
		lbl.add_theme_font_size_override("font_size", int(ph * 0.42))
		lbl.add_theme_color_override("font_color", Pal.INK)
		lbl.add_theme_constant_override("outline_size", 0)
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(lbl)

# Twinkles spaced AROUND the card's edges — each rides the gold frame band and pulses (fade + scale) on
# a staggered loop, so an active place's border shimmers and draws the eye. Reuses the twinkle sprite
# (_star_texture) + warm-gold tint from the button sparkle. `amount` 0..1 scales how many ring the card;
# `calm` (reduced-motion) drops the motion and shows a faint static scatter instead. Mouse-transparent.
static func _map_card_edge_sparkle(card_w: float, card_h: float, amount: float, calm: bool) -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if amount <= 0.0:
		return root
	# the band centre-line rect (half the gold border in on each axis) so twinkles sit ON the gold, not
	# floating in the locale art. The card is wide, so the bands differ per axis.
	var band_x := card_w * 0.025
	var band_y := card_h * 0.06
	var rect := Rect2(band_x, band_y, card_w - band_x * 2.0, card_h - band_y * 2.0)
	var count := clampi(int(round(amount * 22.0)), 3, 40)
	var px := clampf(card_h * 0.16, 14.0, 40.0)
	var tex := _star_texture()
	var cycle := 1.8                                   # one fade-in→hold→fade-out→idle loop
	for i in count:
		var t := (float(i) + 0.5) / float(count)       # even spacing around the perimeter
		var pos := _rect_perimeter_point(t, rect)
		var s := TextureRect.new()
		s.texture = tex
		s.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		s.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		s.custom_minimum_size = Vector2(px, px)
		s.size = Vector2(px, px)
		s.position = pos - Vector2(px, px) * 0.5
		s.pivot_offset = Vector2(px, px) * 0.5
		s.modulate = Color(1.0, 0.84, 0.42, 1.0)       # warm gold (same tint as the button twinkles)
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(s)
		if calm:
			s.modulate.a = 0.45
			s.scale = Vector2(0.85, 0.85)
		else:
			_pulse_twinkle(s, (float(i) / float(count)) * cycle)   # stagger so the ring shimmers, not blinks in unison
	return root

# A point on a rectangle's perimeter at parameter t∈[0,1) (top L→R, right T→B, bottom R→L, left B→T).
static func _rect_perimeter_point(t: float, rect: Rect2) -> Vector2:
	var w := rect.size.x
	var h := rect.size.y
	var d := fposmod(t, 1.0) * (2.0 * (w + h))
	var p := rect.position
	if d < w:
		return p + Vector2(d, 0.0)
	d -= w
	if d < h:
		return p + Vector2(w, d)
	d -= h
	if d < w:
		return p + Vector2(w - d, h)
	d -= w
	return p + Vector2(0.0, h - d)

# Loops one twinkle: a one-time `stagger` delay (so the ring desyncs), then fade-in + grow, fade-out +
# shrink, and a short idle gap — repeating. Tweens need the node in-tree, so it arms on tree_entered.
static func _pulse_twinkle(s: TextureRect, stagger: float) -> void:
	s.modulate.a = 0.0
	s.scale = Vector2(0.6, 0.6)
	var begin := func() -> void:
		if not is_instance_valid(s) or not s.is_inside_tree():
			return
		var loop := s.create_tween().set_loops().set_trans(Tween.TRANS_SINE)
		loop.tween_property(s, "modulate:a", 1.0, 0.6)
		loop.parallel().tween_property(s, "scale", Vector2(1.05, 1.05), 0.6)
		loop.tween_property(s, "modulate:a", 0.0, 0.7)
		loop.parallel().tween_property(s, "scale", Vector2(0.6, 0.6), 0.7)
		loop.tween_interval(0.5)
	s.tree_entered.connect(func() -> void:
		var t0 := s.create_tween()
		t0.tween_interval(maxf(stagger, 0.001))
		t0.tween_callback(begin))

# The centered ✿ "place" mark drawn over a bare meadow fill (no locale art yet). Mouse-transparent.
static func _map_place_mark(opts: Dictionary) -> Control:
	var mark := Label.new()
	mark.name = "PlaceMark"
	mark.text = "✿"
	mark.add_theme_font_size_override("font_size", int(opts.get("veil_mark_size", 64.0)))
	mark.add_theme_color_override("font_color", Color(Pal.CREAM, 0.5))
	mark.set_anchors_preset(Control.PRESET_FULL_RECT)
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return mark

# A code-drawn meadow fill for a LOCKED card whose painted panel is absent — a flat panel + a centered ✿
# "place" mark, dimmed; the fog veil layers over this. (Open cards use the silhouette-masked fill instead.)
static func _map_meadow_fill(open: bool, opts: Dictionary) -> Control:
	var ph := Panel.new()
	ph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ph.clip_contents = true
	var ps := StyleBoxFlat.new()
	ps.bg_color = Pal.MEADOW if open else Pal.MEADOW.lerp(Pal.INK, 0.45)
	ps.set_corner_radius_all(14)
	ph.add_theme_stylebox_override("panel", ps)
	ph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ph.add_child(_map_place_mark(opts))
	return ph

# A code-drawn gold border, the fallback when card_active.png is absent (so an open card still reads as
# framed). A borderless rounded panel that draws only the rim — mouse-ignored, self-sizing.
static func _map_code_border() -> Control:
	var pnl := Panel.new()
	pnl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0, 0, 0, 0)
	ps.set_corner_radius_all(22)
	ps.set_border_width_all(5)
	ps.border_color = Pal.STRAW
	pnl.add_theme_stylebox_override("panel", ps)
	pnl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return pnl

# The fog veil for a LOCKED map card (§8): a translucent ink scrim + a gradient that pools fog at the
# bottom + a faint ✿ ghost. Overlays exactly `thumb` (full-rect child), named MAP_VEIL_NODE so a test can
# assert it. ART SEAM: map/veil_<id>.png (per-map) or map/veil.png (generic) REPLACES the code fog.
static func _map_veil(thumb: Control, map_id: String, opts: Dictionary) -> void:
	thumb.clip_contents = true
	var veil := Control.new()
	veil.name = MAP_VEIL_NODE
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumb.add_child(veil)
	var art := Game.art("map/veil_%s.png" % map_id)
	if not ResourceLoader.exists(art):
		art = Game.art(MAP_VEIL_ART)
	if ResourceLoader.exists(art):
		var sprite := TextureRect.new()
		sprite.texture = load(art)
		sprite.set_anchors_preset(Control.PRESET_FULL_RECT)
		sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		veil.add_child(sprite)
		return
	var scrim := float(opts.get("veil_scrim", 0.42))
	var deep := float(opts.get("veil_deep", 0.66))
	# 1. a flat haze over the whole thumb.
	var haze := ColorRect.new()
	haze.color = Color(Pal.INK, scrim)
	haze.set_anchors_preset(Control.PRESET_FULL_RECT)
	haze.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.add_child(haze)
	# 2. fog settling — a top→bottom gradient deepening to `deep` at the base.
	var grad := Gradient.new()
	grad.set_color(0, Color(Pal.INK, 0.0))
	grad.set_color(1, Color(Pal.INK, deep - scrim))
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill_from = Vector2(0.5, 0.0)
	gtex.fill_to = Vector2(0.5, 1.0)
	gtex.width = 4
	gtex.height = 64
	var settle := TextureRect.new()
	settle.texture = gtex
	settle.set_anchors_preset(Control.PRESET_FULL_RECT)
	settle.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	settle.stretch_mode = TextureRect.STRETCH_SCALE
	settle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.add_child(settle)
	# 3. the teasing ✿ ghost — a faint mark in the mist.
	var ghost := Label.new()
	ghost.name = "VeilMark"
	ghost.text = "✿"
	ghost.add_theme_font_size_override("font_size", int(opts.get("veil_mark_size", 64.0)))
	ghost.add_theme_color_override("font_color", Color(Pal.CREAM, float(opts.get("veil_mark_alpha", 0.16))))
	ghost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ghost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ghost.set_anchors_preset(Control.PRESET_FULL_RECT)
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.add_child(ghost)

# Material for an open card's fill: COVER-samples `tex` over `rect_size` and clips it to the gold frame's
# exact silhouette mask. See MAP_ART_CLIP_SHADER.
static func _map_art_material(tex: Texture2D, rect_size: Vector2) -> ShaderMaterial:
	if _map_art_clip == null:
		_map_art_clip = Shader.new()
		_map_art_clip.code = MAP_ART_CLIP_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = _map_art_clip
	mat.set_shader_parameter("art", tex)
	mat.set_shader_parameter("tex_px", tex.get_size())
	mat.set_shader_parameter("rect_px", rect_size)
	mat.set_shader_parameter("mask", _map_silhouette_tex())
	return mat

# The gold frame's silhouette as an alpha mask: 1 inside the frame body + its enclosed hole, 0 in the
# transparent corner gaps / edge margin / glow. Computed by flood-filling the frame's TRANSPARENT pixels
# inward from the 4 borders (so the enclosed centre hole stays "inside"). Built on a DOWN-SCALED copy so
# the flood-fill is cheap (no first-open freeze); the mask is linear-filtered, so it upsamples smoothly to
# the card. Cached — built once.
static func _map_silhouette_tex() -> Texture2D:
	if _map_sil_tex != null:
		return _map_sil_tex
	var ft: Texture2D = load(Look.kit(MAP_CARD_ACTIVE))
	if ft == null:
		return null
	var img := ft.get_image()
	img.convert(Image.FORMAT_RGBA8)
	var sw := 256                                       # downsample width — plenty for a soft clip mask
	img.resize(sw, maxi(1, int(round(sw * float(img.get_height()) / float(img.get_width())))), Image.INTERPOLATE_BILINEAR)
	var w := img.get_width()
	var h := img.get_height()
	var n := w * h
	# 1 = opaque (alpha >= 0.5), 0 = transparent
	var opaque := PackedByteArray()
	opaque.resize(n)
	for y in h:
		for x in w:
			opaque[y * w + x] = 1 if img.get_pixel(x, y).a >= 0.5 else 0
	# flood-fill "outside" = transparent pixels reachable from the border
	var outside := PackedByteArray()
	outside.resize(n)
	var stack := PackedInt32Array()
	for x in w:
		if opaque[x] == 0: outside[x] = 1; stack.push_back(x)
		var b := (h - 1) * w + x
		if opaque[b] == 0 and outside[b] == 0: outside[b] = 1; stack.push_back(b)
	for y in h:
		var l := y * w
		if opaque[l] == 0 and outside[l] == 0: outside[l] = 1; stack.push_back(l)
		var r := y * w + (w - 1)
		if opaque[r] == 0 and outside[r] == 0: outside[r] = 1; stack.push_back(r)
	while stack.size() > 0:
		var i := stack[stack.size() - 1]
		stack.remove_at(stack.size() - 1)
		var x := i % w
		var y := i / w
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx := x + int(d.x)
			var ny := y + int(d.y)
			if nx < 0 or nx >= w or ny < 0 or ny >= h:
				continue
			var j := ny * w + nx
			if outside[j] == 0 and opaque[j] == 0:
				outside[j] = 1
				stack.push_back(j)
	var mask := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var inside: bool = outside[y * w + x] == 0
			mask.set_pixel(x, y, Color(1, 1, 1, 1.0 if inside else 0.0))
	_map_sil_tex = ImageTexture.create_from_image(mask)
	return _map_sil_tex

# A cached 1x1 MEADOW-colour texture — the COVER-sampled fill for an open card whose locale art is absent.
static func _map_meadow_texture() -> Texture2D:
	if _map_meadow_tex != null:
		return _map_meadow_tex
	var im := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	im.set_pixel(0, 0, Pal.MEADOW)
	_map_meadow_tex = ImageTexture.create_from_image(im)
	return _map_meadow_tex

## The map-card presentation opts from config (use-art · frame inset · art radius · count-pill metrics ·
## §8 fog-veil look). DEFAULTS equal the shipped §8 constants, so an absent/empty config renders the
## SHIPPED card byte-for-byte. Insets/fracs are stored as scaled integers for the workbench's integer
## sliders (inset/radius in thousandths, fracs + veil alphas in percent) and resolved to fractions here.
static func map_card_opts_from_config(cfg: Dictionary) -> Dictionary:
	var c: Dictionary = cfg.get("map_card", {}) if cfg is Dictionary else {}
	return {
		"use_art":         bool(c.get("use_art", true)),
		"edge_sparkle":    float(c.get("edge_sparkle", 60)) / 100.0,    # twinkles ringing an ACTIVE open card's gold band (0 = off); reduced-motion freezes them
		"calm":            bool(c.get("calm", false)),                  # reduced-motion: freeze the edge sparkle (set live by map.gd from FX.calm())
		"pill_w_frac":     float(c.get("pill_w_frac", 30)) / 100.0,     # count-pill width (% of card width)
		"pill_min":        float(c.get("pill_min", 170)),
		"pill_max":        float(c.get("pill_max", 290)),
		"pill_y_frac":     float(c.get("pill_y_frac", 13)) / 100.0,     # pill lift off the bottom (% of card height)
		"veil_scrim":      float(c.get("veil_scrim", 42)) / 100.0,
		"veil_deep":       float(c.get("veil_deep", 66)) / 100.0,
		"veil_mark_alpha": float(c.get("veil_mark_alpha", 16)) / 100.0,
		"veil_mark_size":  float(c.get("veil_mark_size", 64)),
	}

## The default config-file location the workbench writes (the single source of truth the game reads).
const CONFIG_PATH := "res://games/grove/tools/ui_workbench_settings.json"
