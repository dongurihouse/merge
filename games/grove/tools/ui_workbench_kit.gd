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
const Iap = preload("res://engine/scripts/core/iap.gd")   # cash-pack prices by key (data/iap_products.json)
const Pal = Game.PALETTE
const Tune = preload("res://engine/scripts/core/tuning.gd").UiSkin   # button radius/border/shadow metrics
const Sparkle = preload("res://games/grove/tools/sparkle.gd")   # the code-drawn twinkle overlay

# Nine-patch margins for the shared mail kit (sourced from the real recipe in inbox.gd).
const CARD_TEX := Vector2(30, 30)
const CARD_PAD := Vector4(18, 12, 18, 12)
const PILL_TEX := Vector2(46, 34)
const PILL_PAD := Vector4(14, 6, 14, 6)
const CLAIM_PAD := Vector4(24, 8, 24, 8)
const BANNER_H := 92.0
const BANNER_MIN_W_FRAC := 0.25   # a dialog floors its banner at this fraction of the SCREEN width (banner_min_w)

static func _shadow_warmth(opts: Dictionary, key: String = "shadow_warmth") -> float:
	return clampf(float(opts.get(key, 82.0)) / 100.0, 0.0, 1.0)

# The map-SELECT place-picker CARD. Both states wear the SHARED gold-badge frame (board/info-bar consistent);
# only the interior differs. An OPEN place shows its locale art COVER-filled inside the frame + a "★ N
# restored-zone progress pill; a LOCKED place shows a dark gradient interior carrying the lock medallion under an
# "after <prev>" line. The GAME (map.gd) resolves each card's DATA (art path · open/locked · counts · prereq)
# and passes it in `d`; every presentation dial lives in `opts` (map_card_opts_from_config) so the workbench
# tunes it and the game reads the SAME recipe — the single-source-of-truth pattern the currency pill uses.
const MAP_CARD_PILL := "map/pill_left.png"         # the cream count pill on an open card's lower edge
const MAP_CARD_ASPECT := 1027.0 / 352.0            # the place-card aspect — cards size to it so the frame never distorts
const MAP_CARD_PILL_ASPECT := 293.0 / 102.0        # pill_left's aspect
const MAP_FRAME_NODE := "MapGoldFrame"             # the open card's shared gold-badge frame (tests assert it)
const MAP_CARD_LOCK := "map/lock_flower.png"       # the standalone lock medallion centred on a locked card
const MAP_LOCK_NODE := "MapLockMedallion"          # the locked card's centred lock medallion (tests assert it)
const MAP_LEFT_LOCKED_PREVIEW := "map/left_locked_preview.png"
const MAP_LEFT_LOCKED_PREVIEW_INNER := "map/left_locked_preview_inner.png"
const MAP_LEFT_LOCK_FLOWER_LARGE := "map/left_lock_flower_large.png"
const MAP_LEFT_LOCK_FLOWER_SOFT := "map/left_lock_flower_soft.png"
const MAP_LEFT_TITLE_PLATE := "map/left_title_plate.png"
const MAP_LEFT_LEAF_LEFT := "map/left_leaf_left.png"
const MAP_LEFT_LEAF_RIGHT := "map/left_leaf_right.png"
const MAP_LEFT_REWARD_SHELF := "map/left_reward_shelf.png"
const MAP_LOCKED_PREVIEW_NODE := "MapLockedPreviewArt"
const LOCK_FILL_TOP := Color(0.165, 0.490, 0.588)  # locked-card interior gradient — teal at top …
const LOCK_FILL_BOTTOM := Color(0.235, 0.290, 0.275)  # … to a muted dark at the base (sampled from card_locked)
# Draws the locale art COVER-fitted to fill the inner rect, clipped to a rounded rect so it tucks INSIDE the
# shared gold-badge frame's inner corner (the frame is a filled 9-slice behind it; the art nests in its
# border like the board grid in the board frame). `art` is the locale texture, `tex_px` drives the COVER
# crop over `rect_px`, `radius_px` rounds the corners to match the frame's inner groove.
const MAP_ART_FILL_SHADER := "shader_type canvas_item;
uniform sampler2D art : filter_linear;
uniform vec2 tex_px = vec2(1.0);
uniform vec2 rect_px = vec2(1.0);
uniform float radius_px = 0.0;
void fragment() {
	float cover = max(rect_px.x / tex_px.x, rect_px.y / tex_px.y);
	vec2 disp = tex_px * cover;                 // art scaled to COVER the inner rect
	vec2 off = (disp - rect_px) * 0.5;          // centred crop
	vec2 p = UV * rect_px;                       // pixel position within the inner rect
	vec4 col = texture(art, (p + off) / disp);   // COVER sample
	vec2 hs = rect_px * 0.5;
	float r = clamp(radius_px, 0.0, min(hs.x, hs.y));
	vec2 q = abs(p - hs) - (hs - vec2(r));
	float sd = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
	col.a *= clamp(0.5 - sd, 0.0, 1.0);          // rounded-rect clip with a 1px AA edge
	COLOR = col;
}"
static var _map_art_fill: Shader
# A locked card's dark "veiled" interior: a top→bottom gradient (no texture, so no baked border to double up
# the frame), clipped to the frame's inner rounded corner — the same rounded clip the art fill uses.
const MAP_LOCK_FILL_SHADER := "shader_type canvas_item;
uniform vec4 top_color : source_color = vec4(0.165, 0.49, 0.588, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.235, 0.29, 0.275, 1.0);
uniform vec2 rect_px = vec2(1.0);
uniform float radius_px = 0.0;
void fragment() {
	vec4 col = mix(top_color, bottom_color, clamp(UV.y, 0.0, 1.0));
	vec2 p = UV * rect_px;
	vec2 hs = rect_px * 0.5;
	float r = clamp(radius_px, 0.0, min(hs.x, hs.y));
	vec2 q = abs(p - hs) - (hs - vec2(r));
	float sd = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
	col.a *= clamp(0.5 - sd, 0.0, 1.0);
	COLOR = col;
}"
static var _map_lock_fill: Shader
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
# icon; the game passes a real merge-piece node), an UNSEEN tier the locked slot well, one tier is marked
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

## The GAME shop's items, faithfully from Game.DATA, grouped into the SAME sections the real
## storefront uses (engine/scripts/ui/shop.gd) — each a {caption, cards} dict the shop dialog draws under
## a vine divider. Quick help is a 2-card row; Acorn pouches is the gem ladder. (The Featured item-shortcut
## row was removed 2026-06-23 with the shop's item-buying — that moves to the board's item info bar.)
## Only the ITEMS (icon / amount / price / ribbon); the card STYLING is the shared small card.
static func demo_shop() -> Array:
	var D := Game.DATA
	# Quick help — refill water + a coin pouch (a row of just TWO), both paid in gems
	var help: Array = [
		{"icon": "water", "label": "Fill water", "price": str(int(D.REFILL_DIAMOND_COST)), "price_icon": "gem"},
		{"icon": "coin", "label": "Coin pouch", "count": 150, "price": "5", "price_icon": "gem"},
	]
	# Acorn pouches — the cash → gems ladder (a 3-wide grid; the merchandised packs wear ribbons)
	var packs: Array = []
	for i in (D.CASH_PACKS as Array).size():
		var pk: Dictionary = D.CASH_PACKS[i]
		# the escalating gem-TIER icon the REAL ladder draws (mirrors Shop._gem_icon_id) — replicated here
		# so the bake auto-discovers gem_t1…gem_tN; else they live-polish on first shop open (the freeze).
		var gem_art := "gem_t%d" % (i + 1)
		if not ResourceLoader.exists(Game.art("ui/currency/icon_%s.png" % gem_art)):
			gem_art = "gem"
		var card := {"icon": gem_art, "count": int(pk.get("gems", 0)), "price": Iap.usd(String(pk.get("key", "")))}
		if bool(pk.get("pop", false)):
			card["ribbon"] = "Popular"               # the merchandised mid anchor
		elif i == (D.CASH_PACKS as Array).size() - 1:
			card["ribbon"] = "Best value"            # the whale tier (best rate)
		packs.append(card)
	return [
		{"caption": "Quick help", "cards": help},
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
	if img.has_mipmaps():
		img.clear_mipmaps()   # polish works on mip 0 only; a stale mip chain breaks resize→get_data/set_data
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
## sprite's own alpha, offset + blurred + warm-tinted — sits beneath it. opts: shadow_offset (Vector2
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
	var sh_color := Look.warm_shadow_color(alpha, _shadow_warmth(opts))
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
			var si := (ny * nw + nx) * 4
			sh_data[si] = int(round(sh_color.r * 255.0))
			sh_data[si + 1] = int(round(sh_color.g * 255.0))
			sh_data[si + 2] = int(round(sh_color.b * 255.0))
			sh_data[si + 3] = int(a * sh_color.a)
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
# Boot perf guard (see grove_vine_tests._test_boot_does_zero_live_work): every "path@cap" that hit the
# LIVE defringe/feather fallback below — i.e. a bakeable sprite that was NOT pre-baked. On a shipped boot
# this must stay empty; an entry means a new asset polishes live on cold boot (run `make bake-textures`).
static var _live_polish_log: Array = []

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
	_live_polish_log.append(key)            # bakeable sprite with no baked mirror — the boot guard flags this
	var img := (load(path) as Texture2D).get_image()
	var t := ImageTexture.create_from_image(_clean_image(img, max_dim))
	_clean_cache[key] = t
	return t

static func _clean_image(src: Image, max_dim: int) -> Image:
	var img := src.duplicate() as Image
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	if img.has_mipmaps():
		img.clear_mipmaps()   # work on mip 0 only; a stale mip chain breaks resize→get_data/set_data
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

## Code-drawn port of docs/art/gold-rounded-badge.html: a warm cream rounded square with a single
## outer rim, an inset 1px groove, and soft inset depth. The fixed preview and stretched board/info
## frames share the same generated texture path, so saved Workbench tuning lands everywhere.
const GOLD_BADGE_BASE_SIZE := 270
const GOLD_BADGE_CAP := 58
static var _gold_badge_cache: Dictionary = {}
static func gold_badge(px: float = 270.0, inner_inset: float = -1.0, shine_pct: float = 100.0, corner_px: float = -1.0, gradient_pct: float = 100.0) -> Control:
	var size := maxi(32, int(round(px)))
	var inset := clampf(inner_inset if inner_inset >= 0.0 else size * 0.040, 2.0, size * 0.18)
	var shine := clampf(shine_pct / 100.0, 0.0, 2.0)
	var gradient := clampf(gradient_pct / 100.0, 0.0, 1.0)
	var corner := _gold_badge_corner_for_size(size, corner_px)
	var root := Control.new()
	root.custom_minimum_size = Vector2(size, size)
	root.size = Vector2(size, size)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var pad := int(ceil(size * 0.075))
	var tex_size := size + pad * 2
	var tr := TextureRect.new()
	tr.name = "GoldBadgeTexture"
	tr.texture = _gold_badge_texture(size, inset, shine, -1, corner, gradient)
	tr.position = Vector2(-pad, -pad)
	tr.custom_minimum_size = Vector2(tex_size, tex_size)
	tr.size = Vector2(tex_size, tex_size)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tr)
	return root

static func gold_badge_opts_from_config(cfg: Dictionary) -> Dictionary:
	var g: Dictionary = cfg.get("gold_badge", {}) if cfg is Dictionary else {}
	return {
		"inner_inset": float(g.get("inner_inset", 11.0)),
		"shine": float(g.get("shine", 100.0)),
		"corner": float(g.get("corner", GOLD_BADGE_CAP)),
		"gradient": float(g.get("gradient", 100.0)),
		"inner_shadow": float(g.get("inner_shadow", 30.0)),
	}

static func gold_badge_style(opts: Dictionary = {}) -> StyleBoxTexture:
	var size := GOLD_BADGE_BASE_SIZE
	var inset := clampf(float(opts.get("inner_inset", 11.0)), 2.0, size * 0.18)
	var shine := clampf(float(opts.get("shine", 100.0)) / 100.0, 0.0, 2.0)
	var gradient := clampf(float(opts.get("gradient", 100.0)) / 100.0, 0.0, 1.0)
	var corner := _gold_badge_corner_for_size(size, float(opts.get("corner", GOLD_BADGE_CAP)))
	var sb := StyleBoxTexture.new()
	sb.texture = _gold_badge_texture(size, inset, shine, 0, corner, gradient, float(opts.get("inner_shadow", 30.0)))
	sb.set_texture_margin_all(gold_badge_cap(opts))
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	if opts.has("content_margin_left") or opts.has("left"):
		sb.content_margin_left = float(opts.get("content_margin_left", opts.get("left", 0.0)))
	if opts.has("content_margin_right") or opts.has("right"):
		sb.content_margin_right = float(opts.get("content_margin_right", opts.get("right", 0.0)))
	if opts.has("content_margin_top") or opts.has("top"):
		sb.content_margin_top = float(opts.get("content_margin_top", opts.get("top", 0.0)))
	if opts.has("content_margin_bottom") or opts.has("bottom"):
		sb.content_margin_bottom = float(opts.get("content_margin_bottom", opts.get("bottom", 0.0)))
	return sb

static func gold_badge_cap(opts: Dictionary = {}) -> int:
	var size := GOLD_BADGE_BASE_SIZE
	var corner := _gold_badge_corner_for_size(size, float(opts.get("corner", GOLD_BADGE_CAP)))
	return clampi(int(ceil(corner)), 4, maxi(4, int(size * 0.5) - 1))

# ============ RUSH BAR — the Expedition Rush top HUD =====================================================
# Three CODE-DRAWN gold-badge cells — Time | SCORE (centred, larger) | Mult — with the rush_bar_asset art
# used ONLY for the decorations: oak-leaf clusters on the flanks, a coin in the score cell, and an acorn
# crown topping the centre. The dynamic numerals are exposed via meta (time_label / score_label /
# mult_label) so the game updates them in place. Every dial is workbench-tunable (rush_bar_opts_from_config).

## Resolve the rush-bar look from config (workbench "rush_bar" block) + the SHARED gold-badge skin.
static func rush_bar_opts_from_config(cfg: Dictionary) -> Dictionary:
	var r: Dictionary = cfg.get("rush_bar", {}) if cfg is Dictionary else {}
	return {
		"height":     float(r.get("height", 116.0)),     # cell height
		"score_w":    float(r.get("score_w", 300.0)),    # the centred SCORE cell width
		"side_w":     float(r.get("side_w", 224.0)),     # the flank (Time / Mult) cell width
		"gap":        float(r.get("gap", 18.0)),         # spacing between cells
		"label_size": float(r.get("label_size", 24.0)),  # the "Time" / "Score" / "Mult" caption
		"value_size": float(r.get("value_size", 46.0)),  # the numerals
		"icon_size":  float(r.get("icon_size", 52.0)),   # the score coin
		"leaf_size":  float(r.get("leaf_size", 92.0)),   # the flank oak-leaf clusters (tall, by aspect)
		"crown_size": float(r.get("crown_size", 76.0)),  # the acorn crown over the centre
		"pad":        float(r.get("pad", 16.0)),         # cell content inset
		"burn":       clampf(float(r.get("burn", 0.0)) / 100.0, 0.0, 1.0),
		"gold":       gold_badge_opts_from_config(cfg),  # the SHARED code-drawn gold badge skin
		"label_col":  String(r.get("label_col", "#9A7B43")),
		"value_col":  String(r.get("value_col", "#43352B")),
	}

## Build the rush bar. `data` = {time, score, mult} display strings. Returns a Control sized to the bar;
## the three value Labels are exposed as meta (time_label / score_label / mult_label) for live updates.
static func rush_bar(opts: Dictionary, data: Dictionary = {}) -> Control:
	var H := float(opts.get("height", 116.0))
	var score_w := float(opts.get("score_w", 300.0))
	var side_w := float(opts.get("side_w", 224.0))
	var gap := float(opts.get("gap", 18.0))
	var crown_sz := float(opts.get("crown_size", 76.0))
	var total_w := side_w * 2.0 + score_w + gap * 2.0
	var top_pad := crown_sz * 0.78                             # headroom so the crown sits mostly ABOVE the cell
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(total_w, top_pad + H)
	bar.size = bar.custom_minimum_size
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gold := gold_badge_style(opts.get("gold", {}))
	var labels := {}
	var x := 0.0
	var time_cell := _rush_cell(opts, gold, Vector2(x, top_pad), Vector2(side_w, H), "Time", String(data.get("time", "0:00")), "leaf_l", "left", labels, "time")
	bar.add_child(time_cell)
	x += side_w + gap
	var score_cell := _rush_cell(opts, gold, Vector2(x, top_pad), Vector2(score_w, H), "Score", String(data.get("score", "0")), "coin", "left", labels, "score")
	bar.add_child(score_cell)
	var score_cx := x + score_w * 0.5
	x += score_w + gap
	var mult_cell := _rush_cell(opts, gold, Vector2(x, top_pad), Vector2(side_w, H), "Mult", String(data.get("mult", "x1.0")), "leaf_r", "right", labels, "mult")
	bar.add_child(mult_cell)
	# the acorn CROWN tops the centre cell (the "separator" ornament), straddling its top edge
	var crown := _bar_art("bar_crown", crown_sz)
	if crown != null:
		crown.position = Vector2(score_cx - crown.size.x * 0.5, top_pad - crown.size.y * 0.75)
		bar.add_child(crown)
	bar.set_meta("time_label", labels.get("time"))
	bar.set_meta("score_label", labels.get("score"))
	bar.set_meta("mult_label", labels.get("mult"))
	bar.set_meta("score_cell", score_cell)        # the score / mult cells, for the rush_fx pop effects
	bar.set_meta("mult_cell", mult_cell)
	return bar

# One rush-bar cell: a code-drawn gold-badge panel with a side decoration (leaf / coin) and a centred
# caption + value column. Returns the cell; records the value Label into `labels_out[key]`.
static func _rush_cell(opts: Dictionary, gold: StyleBox, pos: Vector2, size: Vector2, caption: String, value_text: String, deco: String, deco_side: String, labels_out: Dictionary, key: String) -> Control:
	var pad := float(opts.get("pad", 16.0))
	var cell := Control.new()
	cell.position = pos ; cell.size = size ; cell.custom_minimum_size = size
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", gold)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(panel)
	var deco_h := float(opts.get("icon_size", 52.0)) if deco == "coin" else float(opts.get("leaf_size", 92.0))
	var deco_w := 0.0
	var dn := _bar_art("bar_" + deco, deco_h)
	if dn != null:
		deco_w = dn.size.x
		var dy := (size.y - dn.size.y) * 0.5
		dn.position = Vector2(pad, dy) if deco_side == "left" else Vector2(size.x - pad - deco_w, dy)
		cell.add_child(dn)
	var tx0 := pad + (deco_w + pad if deco_side == "left" else 0.0)
	var tx1 := size.x - pad - (deco_w + pad if deco_side == "right" else 0.0)
	var tw := maxf(10.0, tx1 - tx0)
	var col := VBoxContainer.new()
	col.position = Vector2(tx0, pad)
	col.size = Vector2(tw, size.y - pad * 2.0)
	col.custom_minimum_size = col.size
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var burn := float(opts.get("burn", 0.0))
	col.add_child(_bar_label(caption, int(opts.get("label_size", 24)), String(opts.get("label_col", "#9A7B43")), tw, burn))
	var val := _bar_label(value_text, int(opts.get("value_size", 46)), String(opts.get("value_col", "#43352B")), tw, burn)
	col.add_child(val)
	cell.add_child(col)
	labels_out[key] = val
	return cell

static func _bar_label(text: String, size: int, color_hex: String, width: float, burn: float = 0.0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(color_hex))
	var t := clampf(burn, 0.0, 1.0)
	if t > 0.0:
		l.add_theme_color_override("font_color", Color("#4A2E14").darkened(0.35 * t))
		l.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.25 + 0.45 * t))
		l.add_theme_constant_override("shadow_offset_x", int(round(1.0 + 2.0 * t)))
		l.add_theme_constant_override("shadow_offset_y", int(round(2.0 + 3.0 * t)))
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.12 + 0.33 * t))
		l.add_theme_constant_override("outline_size", int(round(2.0 + 4.0 * t)))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(width, 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

# A rush-bar decoration (ui/rush/bar_<name>.png) scaled to `target_h` keeping its aspect. Null if absent.
static func _bar_art(name: String, target_h: float) -> Control:
	var path := Look.kit("rush/%s.png" % name)
	if not ResourceLoader.exists(path):
		return null
	var tex: Texture2D = load(path)
	var asp := tex.get_size().x / maxf(1.0, tex.get_size().y)
	var t := TextureRect.new()
	t.texture = tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.custom_minimum_size = Vector2(target_h * asp, target_h)
	t.size = t.custom_minimum_size
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

static func _gold_badge_corner_for_size(size: int, corner_px: float) -> float:
	var corner := float(size) * 0.215 if corner_px < 0.0 else corner_px * float(size) / float(GOLD_BADGE_BASE_SIZE)
	return clampf(corner, 4.0, float(size) * 0.5 - 1.0)

static func _gold_badge_texture(size: int, groove_inset: float, shine: float, pad_override: int = -1, corner_radius: float = -1.0, gradient: float = 1.0, inner_shadow: float = 30.0) -> Texture2D:
	var pad := int(ceil(size * 0.075)) if pad_override < 0 else maxi(0, pad_override)
	var outer_radius := clampf(corner_radius if corner_radius >= 0.0 else float(size) * 0.215, 4.0, float(size) * 0.5 - 1.0)
	var gradient_amt := clampf(gradient, 0.0, 1.0)
	var inner_shadow_amt := clampf(inner_shadow, 0.0, 100.0)
	var cache_key := "%d|%d|%d|%d|%d|%d|%d" % [size, int(round(groove_inset)), int(round(shine * 100.0)), pad, int(round(outer_radius)), int(round(gradient_amt * 100.0)), int(round(inner_shadow_amt))]
	if _gold_badge_cache.has(cache_key):
		return _gold_badge_cache[cache_key]
	var tex_size := size + pad * 2
	var img := Image.create(tex_size, tex_size, false, Image.FORMAT_RGBA8)
	var groove_radius := maxf(4.0, outer_radius - groove_inset)
	var half := Vector2(size * 0.5, size * 0.5)
	var linear_angle := deg_to_rad(138.0)
	var linear_dir := Vector2(sin(linear_angle), -cos(linear_angle)).normalized()
	var c0 := Color("#fff0cf")
	var c1 := Color("#fde6ba")
	var c2 := Color("#f3c983")
	var flat := c1
	var rim := Color(189.0 / 255.0, 121.0 / 255.0, 38.0 / 255.0, 0.35)
	var groove := Color(181.0 / 255.0, 116.0 / 255.0, 35.0 / 255.0, 0.50)
	var groove_shadow := Color(117.0 / 255.0, 66.0 / 255.0, 17.0 / 255.0, inner_shadow_amt / 100.0)
	var groove_light := Color(1.0, 1.0, 1.0, 0.78)

	for y in tex_size:
		for x in tex_size:
			var local := Vector2(float(x - pad), float(y - pad))
			var pixel := Color(0, 0, 0, 0)
			var d := _gold_badge_sdf(local - half, half, outer_radius)
			var face_a := clampf(0.5 - d, 0.0, 1.0)
			if face_a > 0.0:
				var uv := Vector2(local.x / float(size), local.y / float(size))
				var proj := clampf((uv - Vector2(0.5, 0.5)).dot(linear_dir) + 0.5, 0.0, 1.0)
				var ramp_face := c0.lerp(c1, proj / 0.47) if proj <= 0.47 else c1.lerp(c2, (proj - 0.47) / 0.53)
				var face := flat.lerp(ramp_face, gradient_amt)

				var radial_center := Vector2(size * 0.35, size * 0.23)
				var radial_t := (local - radial_center).length() / float(size)
				var hi := Color(255.0 / 255.0, 250.0 / 255.0, 222.0 / 255.0, 0.92)
				var mid := Color(255.0 / 255.0, 236.0 / 255.0, 186.0 / 255.0, 0.66)
				var radial := Color(255.0 / 255.0, 229.0 / 255.0, 166.0 / 255.0, 0.0)
				if radial_t <= 0.18:
					radial = hi
				elif radial_t <= 0.35:
					radial = hi.lerp(mid, (radial_t - 0.18) / 0.17)
				elif radial_t <= 0.64:
					radial = mid.lerp(Color(mid.r, mid.g, mid.b, 0.0), (radial_t - 0.35) / 0.29)
				radial.a = clampf(radial.a * shine, 0.0, 1.0)
				face = _gold_badge_over(face, radial)

				var top_gloss := clampf(clampf(1.0 - uv.y / 0.12, 0.0, 1.0) * 0.12 * shine, 0.0, 0.36)
				face = face.lerp(Color.WHITE, top_gloss)
				var bottom_shade := clampf((uv.y - 0.80) / 0.20, 0.0, 1.0) * 0.06 * gradient_amt
				face = face.lerp(Color(173.0 / 255.0, 103.0 / 255.0, 22.0 / 255.0), bottom_shade)
				face.a = face_a
				pixel = _gold_badge_over(pixel, face)

				var rim_a := clampf(1.0 - abs(d), 0.0, 1.0) * rim.a
				if rim_a > 0.0:
					pixel = _gold_badge_over(pixel, Color(rim.r, rim.g, rim.b, rim_a))

				var groove_half := Vector2(size * 0.5 - groove_inset, size * 0.5 - groove_inset)
				var gd := _gold_badge_sdf(local - half, groove_half, groove_radius)
				var groove_line := clampf(1.0 - abs(gd), 0.0, 1.0)
				if gd <= 0.0 and -gd < 6.0:
					var depth := 1.0 - (-gd / 6.0)
					var top_weight := clampf(1.0 - uv.y / 0.62, 0.0, 1.0)
					var bottom_weight := clampf((uv.y - 0.34) / 0.66, 0.0, 1.0)
					pixel = _gold_badge_over(pixel, Color(groove_shadow.r, groove_shadow.g, groove_shadow.b, groove_shadow.a * depth * top_weight))
					pixel = _gold_badge_over(pixel, Color(groove_light.r, groove_light.g, groove_light.b, groove_light.a * depth * bottom_weight * 0.38))
				if groove_line > 0.0:
					pixel = _gold_badge_over(pixel, Color(groove.r, groove.g, groove.b, groove.a * groove_line))

			img.set_pixel(x, y, pixel)
	var tex := ImageTexture.create_from_image(img)
	_gold_badge_cache[cache_key] = tex
	return tex

static func _gold_badge_sdf(p: Vector2, half_size: Vector2, radius: float) -> float:
	var q := Vector2(absf(p.x), absf(p.y)) - half_size + Vector2(radius, radius)
	var outside := Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length()
	var inside := minf(maxf(q.x, q.y), 0.0)
	return outside + inside - radius

static func _gold_badge_over(dst: Color, src: Color) -> Color:
	var a := src.a + dst.a * (1.0 - src.a)
	if a <= 0.0001:
		return Color(0, 0, 0, 0)
	return Color(
		(src.r * src.a + dst.r * dst.a * (1.0 - src.a)) / a,
		(src.g * src.a + dst.g * dst.a * (1.0 - src.a)) / a,
		(src.b * src.a + dst.b * dst.a * (1.0 - src.a)) / a,
		a)

## Shared gold currency pill that ports the HTML plus-button study. The background reuses
## gold_badge(); the currency glyph reuses make_icon().
static func gold_currency_pill(opts: Dictionary = {}, counts: Dictionary = {}) -> Control:
	var pill_w := float(opts.get("pill_w", 292))
	var base_pill_h := float(opts.get("pill_h", 100))
	var pill_h := base_pill_h
	var icon_id := String(opts.get("icon", "water"))
	var pad_left := float(opts.get("pad_left", base_pill_h * 0.18))
	var pad_x := float(opts.get("pad_x", base_pill_h * 0.16))
	var pad_y := float(opts.get("pad_y", base_pill_h * 0.12))
	var style_pad_y := maxf(pad_y, 0.0)
	var icon_box := float(opts.get("icon_box", opts.get("badge_px", 54)))
	var icon_px := float(opts.get("icon_size", 34))
	var icon_x := float(opts.get("icon_x", 0))
	var num_size := int(opts.get("num_size", 30))
	var amount_x := float(opts.get("amount_x", 0))
	var amount_w := float(opts.get("amount_w", maxf(88.0, float(num_size) * 2.9)))
	var gap := int(opts.get("gap", 12))
	var show_plus := bool(opts.get("show_plus", true))
	var plus_action := Callable()
	var plus_action_value: Variant = opts.get("plus_action", null)
	if plus_action_value is Callable:
		plus_action = plus_action_value as Callable
	var plus := _gold_currency_plus_button(opts, plus_action)
	var plus_h := plus.custom_minimum_size.y if show_plus else 0.0
	var content_h := maxf(icon_box, maxf(float(num_size) * 1.45, plus_h))
	var height_pad := pad_y * 2.0
	var pill_floor_h := maxf(1.0, base_pill_h + minf(height_pad, 0.0))
	pill_h = maxf(pill_floor_h, ceilf(content_h + height_pad))

	var panel := PanelContainer.new()
	panel.name = "GoldCurrencyPill"
	panel.custom_minimum_size = Vector2(pill_w, pill_h)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge_opts: Dictionary = (opts.get("badge", {}) as Dictionary).duplicate() if opts.get("badge", {}) is Dictionary else {}
	for k in ["inner_inset", "shine", "corner", "gradient"]:
		if opts.has(k):
			badge_opts[k] = opts[k]
	badge_opts["inner_shadow"] = float(opts.get("inner_shadow", badge_opts.get("inner_shadow", 30.0)))
	badge_opts["content_margin_left"] = pad_left
	badge_opts["content_margin_right"] = pad_x
	badge_opts["content_margin_top"] = style_pad_y
	badge_opts["content_margin_bottom"] = style_pad_y
	panel.add_theme_stylebox_override("panel", gold_badge_style(badge_opts))

	var row_host := Control.new()
	row_host.name = "GoldCurrencyPillContentHost"
	row_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row_host)

	var row := HBoxContainer.new()
	row.name = "GoldCurrencyPillRow"
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", gap)
	row_host.add_child(row)

	var icon_slot := Control.new()
	icon_slot.name = "GoldCurrencyIconSlot"
	icon_slot.custom_minimum_size = Vector2(icon_box, content_h)
	icon_slot.size = Vector2(icon_box, content_h)
	icon_slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := make_icon(icon_id, icon_px)
	icon.name = "GoldCurrencyIcon"
	icon.position = Vector2(round((icon_box - icon_px) * 0.5 + icon_x), (content_h - icon_px) * 0.5)
	icon_slot.add_child(icon)
	row.add_child(icon_slot)

	var amount_slot := Control.new()
	amount_slot.name = "GoldCurrencyAmountSlot"
	amount_slot.custom_minimum_size = Vector2(amount_w, content_h)
	amount_slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	amount_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var amount := Label.new()
	amount.name = "GoldCurrencyAmount"
	amount.text = str(int(counts.get(icon_id, opts.get("count", 2450))))
	amount.custom_minimum_size = Vector2(amount_w, content_h)
	amount.add_theme_font_size_override("font_size", num_size)
	amount.add_theme_color_override("font_color", Color("#3A1C12"))
	amount.add_theme_constant_override("outline_size", 0)
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER   # centre the number within its amount box
	amount.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	amount.position = Vector2(amount_x, 0)
	amount.mouse_filter = Control.MOUSE_FILTER_IGNORE
	amount_slot.add_child(amount)
	row.add_child(amount_slot)

	if show_plus:
		var plus_slot := Control.new()
		plus_slot.name = "GoldCurrencyPlusSlot"
		plus_slot.custom_minimum_size = Vector2(plus.custom_minimum_size.x, content_h)
		plus_slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		plus_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plus.position = Vector2(float(opts.get("plus_x", 0)), (content_h - plus.custom_minimum_size.y) * 0.5)
		plus_slot.add_child(plus)
		row.add_child(plus_slot)
	# Optional OVERALL drop shadow behind the capsule (the painted badge is a StyleBoxTexture with no native
	# shadow). The look is the SHARED box-shadow (offset/blur/spread/warmth), with the pill's own alpha strength
	# folded into shadow_params by the resolver. A PanelContainer manages its children, so cast it via a holder
	# (Look.with_shadow) rather than a behind-parent child; the big corner clamps to a capsule.
	if bool(opts.get("shadow", false)):
		return Look.with_shadow(panel, pill_h, opts.get("shadow_params", {}) as Dictionary)
	return panel

static func _gold_currency_plus_button(opts: Dictionary = {}, action: Callable = Callable()) -> Control:
	var base := float(opts.get("plus_base", 34))
	var button_scale := float(opts.get("plus_button", 100)) / 100.0
	var hue := float(opts.get("plus_hue", 65)) / 360.0
	var shine := clampf(float(opts.get("plus_shine", 32)) / 100.0, 0.0, 1.0)
	var radius_scale := float(opts.get("plus_radius", 28)) / 100.0
	var stroke_scale := float(opts.get("plus_stroke", 2)) / 100.0
	var font_scale := float(opts.get("plus_font", 70)) / 100.0
	var w := base * 1.03 * button_scale
	var h := base * 0.90 * button_scale

	var p: Control
	if action.is_valid():
		var b := Button.new()
		b.flat = false
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_constant_override("h_separation", 0)
		b.pressed.connect(func() -> void: action.call())
		Look.add_press_juice(b)
		p = b
	else:
		p = Panel.new()
	p.name = "GoldCurrencyPlusButton"
	p.custom_minimum_size = Vector2(w, h)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_STOP if action.is_valid() else Control.MOUSE_FILTER_IGNORE
	var green := Color.from_hsv(hue, 0.42, 0.40 + shine * 0.04)
	var psb := StyleBoxFlat.new()
	psb.bg_color = green
	psb.border_color = green.darkened(0.28)
	psb.set_border_width_all(1)
	psb.set_corner_radius_all(int(base * radius_scale * button_scale))
	psb.shadow_color = Color(55.0 / 255.0, 53.0 / 255.0, 22.0 / 255.0, 0.34)
	psb.shadow_size = 3
	psb.shadow_offset = Vector2(0, 2)
	if p is Button:
		for st in ["normal", "hover", "pressed", "focus", "disabled"]:
			(p as Button).add_theme_stylebox_override(st, psb)
	else:
		(p as Panel).add_theme_stylebox_override("panel", psb)

	var g := Label.new()
	g.name = "GoldCurrencyPlusLabel"
	g.text = "+"
	g.add_theme_font_size_override("font_size", int(round(base * font_scale)))
	g.add_theme_color_override("font_color", Color("#FFF6C7"))
	g.add_theme_color_override("font_outline_color", Color(62.0 / 255.0, 73.0 / 255.0, 23.0 / 255.0, 0.54))
	g.add_theme_constant_override("outline_size", maxi(0, int(round(base * stroke_scale))))
	g.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	g.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Dead-centre the "+" on the green background at ANY size. A full-rect Label with valign=CENTER
	# pins its line box to the top and overflows DOWNWARD once the glyph is taller than the button
	# (whose height is fixed by plus_button, NOT plus_font) — so a big plus_font drifts low. Instead
	# anchor the CONTENT-SIZED label at the button centre and grow BOTH ways: the glyph box straddles
	# the centre and overflow is symmetric, so the "+" stays centred however large plus_font goes.
	var dx := float(opts.get("plus_label_x", 0))   # manual nudge rides the centre point
	var dy := float(opts.get("plus_label_y", 0))
	g.anchor_left = 0.5; g.anchor_right = 0.5
	g.anchor_top = 0.5; g.anchor_bottom = 0.5
	g.offset_left = dx; g.offset_right = dx
	g.offset_top = dy; g.offset_bottom = dy
	g.grow_horizontal = Control.GROW_DIRECTION_BOTH
	g.grow_vertical = Control.GROW_DIRECTION_BOTH
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(g)
	return p

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
	var pad_scale := float(opts.get("pad_scale", 1.0)) # shrink/grow the padding (the cost chip uses < 1 to fit a card)
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
			stx.content_margin_left = 22 * pad_scale; stx.content_margin_right = 22 * pad_scale
			stx.content_margin_top = 8 * pad_scale; stx.content_margin_bottom = 9 * pad_scale
			b.add_theme_stylebox_override("normal", stx)
			b.add_theme_stylebox_override("hover", stx)
			var sp_t: StyleBoxTexture = stx.duplicate(); sp_t.modulate_color = Color(0.88, 0.88, 0.88)
			b.add_theme_stylebox_override("pressed", sp_t)
			var sd_t: StyleBoxTexture = stx.duplicate(); sd_t.modulate_color = Color(0.62, 0.62, 0.62)
			b.add_theme_stylebox_override("disabled", sd_t)
			return _maybe_shadow(b, shadow, 24.0, opts.get("shadow_params", {}))
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = edge
	s.set_corner_radius_all(int(corner))      # rectangular at low values; capsule near/above height/2
	s.set_border_width_all(2)
	# NO native shadow — the drop shadow is the SHARED box-shadow, wrapped behind the whole button below.
	s.content_margin_left = 18 * pad_scale; s.content_margin_right = 18 * pad_scale
	s.content_margin_top = 7 * pad_scale; s.content_margin_bottom = 8 * pad_scale
	b.add_theme_stylebox_override("normal", s)
	b.add_theme_stylebox_override("hover", s)
	var sp: StyleBoxFlat = s.duplicate()
	sp.bg_color = fill.darkened(0.08)
	b.add_theme_stylebox_override("pressed", sp)
	var sd: StyleBoxFlat = s.duplicate()
	sd.bg_color = fill.lerp(Color(0.55, 0.55, 0.55), 0.55)
	b.add_theme_stylebox_override("disabled", sd)
	b.add_child(Look.rim_overlay(corner, 2))
	return _maybe_shadow(b, shadow, corner, opts.get("shadow_params", {}))

## Cast the SHARED box-shadow behind a BUTTON, returning the SAME button (callers connect `.pressed` and
## set size flags on it, so its identity must be preserved). A Button is not a Container, so the shadow
## Panel rides as a `show_behind_parent` child — drawn behind the button, no layout fight. `params` is
## Look.shadow_params() (the single shared look); an empty dict falls back to the shipped defaults.
static func _maybe_shadow(b: Control, on: bool, corner: float, params: Dictionary = {}) -> Control:
	if not on:
		return b
	var sh := Look.shadow_rect(maxf(corner, 18.0), params)
	sh.show_behind_parent = true
	b.add_child(sh)
	return b

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
const RECT_SHELL := "shared/badge_rect.png"   # the ui_asset2 rounded-rect badge (rail + Map button), used when opts.shape == "rect"

static func home_button(spec: Dictionary, opts: Dictionary = {}) -> Button:
	var px: float = float(opts.get("px", 140.0))
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(px, px)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.disabled = not bool(spec.get("enabled", true))
	# the shell shape: "disc" (the round cream/gold sprite, the default) or "rect" (the ui_asset2 rounded-rect
	# badge — the home rail + the Map button). The rect shell stacks its icon + caption INSIDE the badge; the
	# disc keeps the icon centred with the caption as an overflow tab beneath it.
	var shape := String(opts.get("shape", "disc"))
	# the shell sprite scaled WHOLE (a round disc / rounded square 9-slices badly at its corners), or a flat
	# code-drawn shape when the art is missing (the kit invariant — same metrics either way). `shell_tint`
	# modulates the whole shell (default WHITE = the raw sprite); the Play CTA passes the orange play disc.
	# `fill_alpha` (workbench 0..100) makes the badge read translucent over the scene.
	var shell_rel := String(opts.get("shell", HOME_SHELL))
	if shape == "rect" and shell_rel == HOME_SHELL:
		shell_rel = RECT_SHELL   # a rect badge defaults to the rounded-rect sprite (unless the caller named a specific shell)
	var shell_tint: Color = opts.get("shell_tint", Color.WHITE)
	var fill_a := clampf(float(opts.get("fill_alpha", 100)) / 100.0, 0.0, 1.0)
	shell_tint = Color(shell_tint.r, shell_tint.g, shell_tint.b, shell_tint.a * fill_a)
	var shell: Texture2D = shell_texture(shell_rel, opts.get("badge", {}))   # the Badge item's tuned polish
	var corner := int(px * (0.22 if shape == "rect" else 0.5))               # code-drawn fallback radius
	for st_name in ["normal", "hover", "pressed", "disabled"]:
		if shell != null:
			var stx := StyleBoxTexture.new()      # NO texture margins → the whole shell scales (rail badges read
			stx.texture = shell                   # better whole-scaled than 9-sliced; the pill 9-slices on its own path)
			if st_name == "pressed":
				stx.modulate_color = shell_tint * Color(0.9, 0.9, 0.9)
			elif st_name == "disabled":
				stx.modulate_color = shell_tint * Color(0.72, 0.72, 0.72)
			else:
				stx.modulate_color = shell_tint
			b.add_theme_stylebox_override(st_name, stx)
		else:
			var s := StyleBoxFlat.new()
			s.bg_color = shell_tint if opts.has("shell_tint") else Color(Pal.CREAM, 0.95 * fill_a)
			s.set_corner_radius_all(corner)
			s.set_border_width_all(3)
			s.border_color = Pal.STRAW
			b.add_theme_stylebox_override(st_name, s)
	# the DROP SHADOW behind the button shell (show_behind_parent): the SHARED box-shadow, SHAPED to the
	# button — a rounded RECT for the rail / Map badges (corner = the badge corner) or a CIRCLE for disc
	# buttons (corner = px/2). On only when the Shadow toggle is set; opts.shadow_params is the single look.
	if bool(opts.get("shadow", false)):
		var sh: Panel = Look.shadow_rect(float(corner), opts.get("shadow_params", {})) if shape == "rect" else Look.shadow_circle(px, opts.get("shadow_params", {}))
		sh.show_behind_parent = true                          # draw under the button's textured shell
		b.add_child(sh)
	# the SPARKLE sits BEHIND the icon (added first → drawn under it), only if asked AND tuned > 0.
	if bool(spec.get("sparkle", false)):
		var glow: float = float(opts.get("glow", 0.0))
		var tw: float = float(opts.get("twinkle", 0.0))
		if glow > 0.0 or tw > 0.0:
			b.add_child(_sparkle_overlay(px, glow, tw, bool(opts.get("calm", false))))
	# the kit icon, centred on the disc (mouse-transparent so the Button is the only hit surface). The icon
	# gets the SHARED global polish (make_icon → _icon_tex's defringe + feather) — its own clean recipe.
	var icwrap := CenterContainer.new()
	icwrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_px := px * float(opts.get("icon_scale", 0.5))
	# A caller-supplied `icon_node` (any Control) wins outright — the Bag well passes the most-recent
	# stashed item's piece view so the disc shows the held item INSTEAD of the satchel (a true swap, not a
	# tiny overlay). Otherwise icon_rel (a direct kit-relative png) wins over the icon id — same polish +
	# square layout either way.
	var icon_rel := String(spec.get("icon_rel", ""))
	var icon_node: Control
	if spec.get("icon_node") is Control:
		icon_node = spec.get("icon_node")
	elif icon_rel != "":
		icon_node = _icon_rect(clean_tex_path(Look.kit(icon_rel), 192), icon_px)
	else:
		icon_node = make_icon(String(spec.get("icon", "")), icon_px)
	if icon_node != null:
		icwrap.add_child(icon_node)
	var caption := String(spec.get("caption", ""))
	if shape == "rect":
		# RECT badge: icon (upper) + caption (lower) stacked INSIDE the rounded rect, padded off the edge —
		# the rail's "icon over label" tiles and the Map button's "Map" plate (matches the ui_mock2 chrome).
		var vb := VBoxContainer.new()
		vb.set_anchors_preset(Control.PRESET_FULL_RECT)
		vb.alignment = BoxContainer.ALIGNMENT_CENTER
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var rpad := px * float(opts.get("rect_pad", 0.13))
		vb.offset_left = rpad; vb.offset_right = -rpad
		vb.offset_top = rpad; vb.offset_bottom = -rpad
		icwrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		icwrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vb.add_child(icwrap)
		if caption != "":
			var cl := Label.new()
			cl.text = caption
			cl.add_theme_font_size_override("font_size", int(opts.get("caption_font", 22)))
			cl.add_theme_color_override("font_color", Pal.INK)
			cl.add_theme_constant_override("outline_size", 0)   # solid badge = the contrast (panel-text law)
			cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			cl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vb.add_child(cl)
		b.add_child(vb)
	else:
		icwrap.set_anchors_preset(Control.PRESET_FULL_RECT)
		b.add_child(icwrap)
		# the OPTIONAL caption tab, centred just beneath the disc (overflows into the gap below)
		if caption != "":
			var cap_font := int(opts.get("caption_font", 22))
			var cap_pad_x := float(opts.get("caption_pad_x", 30.0))
			var cap_pad_y := float(opts.get("caption_pad_y", 8.0))
			var capwrap := CenterContainer.new()
			capwrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			capwrap.anchor_left = 0.0; capwrap.anchor_right = 1.0
			capwrap.anchor_top = 1.0; capwrap.anchor_bottom = 1.0
			capwrap.offset_top = float(opts.get("caption_gap", 4.0))
			# the box just clears the ribbon: the font plus its own top+bottom padding (was a fixed +22 band)
			capwrap.offset_bottom = capwrap.offset_top + cap_font + 2.0 * cap_pad_y
			var cap := Look.title_ribbon(caption, cap_font)
			# override the SHARED ribbon margins with the home button's OWN tunable padding (workbench knobs)
			var csb := cap.get_theme_stylebox("panel")
			if csb is StyleBoxFlat:
				var csbd: StyleBoxFlat = (csb as StyleBoxFlat).duplicate()
				csbd.content_margin_left = cap_pad_x
				csbd.content_margin_right = cap_pad_x
				csbd.content_margin_top = cap_pad_y
				csbd.content_margin_bottom = cap_pad_y
				cap.add_theme_stylebox_override("panel", csbd)
			cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if cap.get_child_count() > 0:
				(cap.get_child(0) as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
			capwrap.add_child(cap)
			b.add_child(capwrap)
	# expose the icon wrapper + its sizing so a caller can swap the icon in place later (the Bag well
	# replaces the satchel with the stashed item, and restores it when emptied) without rebuilding the button.
	b.set_meta("icon_wrap", icwrap)
	b.set_meta("icon_px", icon_px)
	# the OPTIONAL count overlay — a small "x/y" label riding INSIDE the disc (the Bag well's slot count).
	# Centred over the disc, then nudged by count_dx / count_dy (workbench knobs); the caller updates its
	# text live via the exposed `count_label` meta. Any round button COULD carry one, but only the bag
	# supplies text today — moving the count onto the SHARED disc keeps the bag cell the same px box as the
	# rest of the bar (it used to sit in a taller stack below the disc, breaking the bottom-bar alignment).
	var count := String(spec.get("count", ""))
	if count != "":
		var cnt := Label.new()
		cnt.text = count
		cnt.add_theme_font_size_override("font_size", int(opts.get("count_font", 26)))
		cnt.add_theme_color_override("font_color", Pal.CREAM)
		cnt.add_theme_color_override("font_outline_color", Color("#4A3B24"))
		cnt.add_theme_constant_override("outline_size", 6)
		cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cnt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cnt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cnt.set_anchors_preset(Control.PRESET_FULL_RECT)   # fills the disc; the equal offsets below SHIFT the centred text
		var cdx := float(opts.get("count_dx", 0.0))
		var cdy := float(opts.get("count_dy", 38.0))
		cnt.offset_left = cdx; cnt.offset_right = cdx
		cnt.offset_top = cdy; cnt.offset_bottom = cdy
		b.add_child(cnt)
		b.set_meta("count_label", cnt)
	Look.add_press_juice(b)
	if spec.has("action") and (spec.get("action") as Callable).is_valid():
		b.pressed.connect(spec.get("action"))
	return b

## The engine-drawn SPARKLE overlay: a soft additive GLOW that gently breathes + drifting 4-point
## TWINKLES (a continuous GPUParticles2D), both code-generated (no baked art). glow / twinkle are 0..1
## amounts (the workbench sliders); calm freezes it to a static glow with no twinkles (reduced-motion).
static func _sparkle_overlay(px: float, glow: float, twinkle: float, calm: bool, tint: Color = Pal.STRAW, size_mult: float = 1.7) -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if glow > 0.0 and size_mult > 0.0:
		var hsz := px * size_mult
		var gtex := _glow_texture(tint)
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

## A code-generated radial bloom (long soft falloff) — the glow halo, tinted `gold` (defaults to the
## honey straw). Cached PER COLOR, so the workbench can recolor the unlockable glow live without
## rebuilding the texture every frame, while the default-tint callers (home buttons, discovery cell)
## share one cached straw bloom.
static var _glow_tex_cache: Dictionary = {}
static func _glow_texture(gold: Color = Pal.STRAW) -> Texture2D:
	var key := gold.to_rgba32()
	if _glow_tex_cache.has(key):
		return _glow_tex_cache[key]
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := n / 2.0
	for y in n:
		for x in n:
			var d: float = Vector2((x - c + 0.5) / c, (y - c + 0.5) / c).length()
			var a: float = clampf(1.0 - d, 0.0, 1.0)
			a = a * a * a                                    # tight core, long feathered falloff
			img.set_pixel(x, y, Color(gold.r, gold.g, gold.b, a))
	var tex := ImageTexture.create_from_image(img)
	_glow_tex_cache[key] = tex
	return tex

## A read-only CREAM chip showing an arbitrary icon + amount text (e.g. "💧 60", "🪙 100", "Tier 3") — the
## SAME cream/static pill_button variant reward_chip uses for a single currency, but for ANY icon/text, so
## the info sheet can show a line item's amount on a mail card with NO Claim button beside it.
static func amount_chip(icon_id: String, text: String, btn_opts: Dictionary = {}) -> Button:
	var o := btn_opts.duplicate()
	o["bg"] = "cream"
	o.erase("art_rel")                 # cream by role — never a chosen (green) badge
	o["icon"] = icon_id
	o["static"] = true                 # a display chip: looks like the button, not pressable
	o["enabled"] = true
	return pill_button(text, o)

## A mail card (mockup image 2): a plated icon + title/body + a reward pill + a Claim — the reward pill
## and Claim are BOTH the shared pill_button, so a Button knob change propagates here. icon_badge picks
## the circular badge sprite behind the left icon (see ICON_BADGES). The INFO variant carries a read-only
## `chip` ({icon, text}) instead of a reward: the amount shows as a cream amount_chip with NO Claim.
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
	else:
		# the INFO variant: a read-only amount chip (icon + text) and NO Claim button. A plain note (no
		# reward, no chip) adds neither, exactly as before.
		var chip_spec: Dictionary = entry.get("chip", {})
		var chip_text := String(chip_spec.get("text", ""))
		if chip_text != "":
			var ac := amount_chip(String(chip_spec.get("icon", "")), chip_text, btn_opts)
			ac.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(ac)
	return panel

## A TOGGLE CARD — a card type (sibling of mail_card / daily_card): one persisted setting as a row,
## its name on the LEFT and the shared Look.toggle_switch on the RIGHT, riding the SAME kit/mail_card.png
## parchment surface the mail rows use (a flat cream pill when card_art is off). The settings dialog
## stacks one per flag. Game-state-agnostic: `entry` carries label + value + on_toggle, so the workbench
## previews it (a local flip) and the GAME drives it from Save — the kit never reads game state itself.
## Rich rows opt into the mail rhythm with icon + title/body + a cream coin chip before the switch.
##   entry: label/title/body/icon/cost · value (bool, current state) · on_toggle (Callable(on: bool)).
##   opts:  label_font/body_font (px) · switch_h (px, the switch height) · card_art (bool, parchment vs pill).
static func toggle_card(entry: Dictionary, opts: Dictionary = {}) -> Control:
	var label_font := int(opts.get("label_font", 28))
	var body_font := int(opts.get("body_font", maxi(13, label_font - 4)))
	var switch_h := float(opts.get("switch_h", 44.0))
	var card_art := bool(opts.get("card_art", true))
	var rich := entry.has("title") or entry.has("body") or entry.has("icon") or entry.has("cost")
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
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
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12 if rich else 18)
	panel.add_child(row)
	if rich:
		var ic_wrap := MarginContainer.new()
		ic_wrap.add_theme_constant_override("margin_top", 8)
		ic_wrap.add_theme_constant_override("margin_bottom", 8)
		ic_wrap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ic_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic_wrap.add_child(plated_icon(String(entry.get("icon", "leaf")), float(opts.get("icon_px", 52.0))))
		row.add_child(ic_wrap)

		var text := VBoxContainer.new()
		text.add_theme_constant_override("separation", 1)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(text)

		var title := Label.new()
		title.text = String(entry.get("title", entry.get("label", "")))
		title.add_theme_font_size_override("font_size", label_font)
		title.add_theme_color_override("font_color", Pal.INK)
		title.add_theme_constant_override("outline_size", 0)
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text.add_child(title)

		var body := Label.new()
		body.text = String(entry.get("body", ""))
		body.add_theme_font_size_override("font_size", body_font)
		body.add_theme_color_override("font_color", Color(Pal.BARK, 0.95))
		body.add_theme_constant_override("outline_size", 0)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text.add_child(body)

		if entry.has("cost"):
			var cost := amount_chip("coin", "%d" % int(entry.get("cost", 0)), {
				"art": true,
				"font": int(opts.get("cost_font", 18)),
				"icon_size": int(opts.get("cost_icon", 22)),
				"pad_scale": float(opts.get("cost_pad", 0.72)),
			})
			cost.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(cost)
	else:
		var name_l := Label.new()
		name_l.text = String(entry.get("label", ""))
		name_l.add_theme_font_size_override("font_size", label_font)
		name_l.add_theme_color_override("font_color", Pal.INK)
		name_l.add_theme_constant_override("outline_size", 0)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	# Make the WHOLE card tap = one switch flip. Handle ONLY the mouse-button press, never the
	# touch press: with project's emulate_touch_from_mouse=true a single physical click delivers
	# BOTH a mouse-button AND a screen-touch press here, so accepting both flipped the switch
	# TWICE (a net no-op — the "Sounds toggle won't save" bug). emulate_mouse_from_touch (Godot's
	# default, on here) means a real mobile touch still yields a mouse-button event, so one tap =
	# exactly one flip on phone and desktop alike. Do NOT re-add the InputEventScreenTouch branch.
	panel.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
			sw.pressed.emit()
			panel.accept_event())
	return panel

## The dialog banner band: ribbon art + the "Mail" text drawn FULL-RECT and vertically CENTRED, so it
## auto-aligns whatever the font size; plus an optional envelope icon (toggle). Named DialogBanner /
## DialogBannerIcon so the workbench can drag them.
static func _banner(text: String, font: int, band_h: float, width: float, icon_on: bool,
		icon_px: float, icon_pos, text_x: float = 0.0, text_y: float = 0.0, burn: float = 0.0,
		banner_art: String = "mail/mail_banner.png", banner_icon_id: String = "mail",
		pad_l: float = -1.0, pad_r: float = -1.0, banner_min_w: float = 0.0) -> Control:
	var header := Control.new()
	header.name = "DialogBanner"
	header.custom_minimum_size = Vector2(width, band_h)
	# the ribbon WIDTH tracks the title: a short label gives a short banner, growing with the number of
	# letters up to the full card `width` (the max). The folded tails stay rigid (9-slice) so only the flat
	# middle stretches — the ribbon never squashes or distorts however long or short the title is. pad_l /
	# pad_r are the breathing room between the title and each tail (workbench-tunable); asymmetric padding
	# both widens the ribbon AND nudges the title toward the roomier side.
	var pl := pad_l if pad_l >= 0.0 else band_h * 0.55
	var pr := pad_r if pad_r >= 0.0 else band_h * 0.55
	var text_w := ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font).x
	var icon_room := (icon_px + band_h * 0.25) if icon_on else 0.0
	# the ribbon never shrinks below a floor: two tail-widths OR a caller-supplied floor (banner_min_w —
	# dialogs pass a fraction of the SCREEN width, so a SHORT title like the bag's "Bag" still reads as a
	# proper banner, not a tiny stub). Clamped to the frame width (the ribbon's hard max).
	var min_w := minf(maxf(band_h * 2.2, banner_min_w), width)
	var banner_w := clampf(text_w + pl + pr + icon_room, min_w, width)
	var ribbon_x := (width - banner_w) * 0.5                    # centre the sized ribbon within the band
	var bp := Look.kit(banner_art)
	if ResourceLoader.exists(bp):
		var art := NinePatchRect.new()
		art.texture = clean_tex_path(bp, 480)   # polished ribbon
		art.position = Vector2(ribbon_x, 0.0)
		art.size = Vector2(banner_w, band_h)
		var cap := int(round(float(art.texture.get_width()) * 0.20)) if art.texture != null else 0
		art.patch_margin_left = cap             # the folded tails stay 1:1; the flat middle stretches
		art.patch_margin_right = cap
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		header.add_child(art)
	var lbl := Label.new()
	lbl.text = text
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	var shift := text_x + (pl - pr) * 0.5                    # centre the title in its padded span, + the manual nudge
	lbl.offset_left = shift; lbl.offset_right = shift        # shift the centred text horizontally
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
			# default: just inside the sized ribbon's left, vertically centred (tracks the ribbon, not the band)
			env.position = Vector2(ribbon_x + banner_w * 0.14 - icon_px / 2.0, band_h / 2.0 - icon_px / 2.0)
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
	var banner_text_pad_l: float = float(opts.get("banner_text_pad_l", -1.0))   # title↔left-tail room (−1 = auto)
	var banner_text_pad_r: float = float(opts.get("banner_text_pad_r", -1.0))   # title↔right-tail room (−1 = auto)
	var banner_min_w: float = float(opts.get("banner_min_w", 0.0))              # ribbon floor in px (dialogs pass 25% of the screen)
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
	var header := _banner(banner_text, banner_font, banner_h, width, banner_icon_on, banner_icon, banner_icon_pos, banner_text_x, banner_text_y, banner_burn, banner_art, banner_icon_id, banner_text_pad_l, banner_text_pad_r, banner_min_w)
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
	# an optional centered FOOTER NOTE — the info sheet's one-line caption under the rows; off by default
	# (the inbox passes none, so it stays a pure card list).
	var foot_note := String(opts.get("note", ""))
	if foot_note != "":
		var fl := Label.new()
		fl.text = foot_note
		fl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		fl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fl.add_theme_font_override("font", plain_font())          # standard text, not the chunky display face
		fl.add_theme_font_size_override("font_size", int(opts.get("note_font", 13)))
		fl.add_theme_color_override("font_color", Color(Pal.BARK, 0.92))
		fl.add_theme_constant_override("outline_size", 0)
		fl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(fl)
	# an optional GOT-IT footer button — the SHARED level cta_button, fired by opts.on_close (same as the
	# ✕). Off by default → the inbox is unchanged; the info sheet sets opts.got_it to close itself.
	var got_it_text := String(opts.get("got_it", ""))
	if got_it_text != "":
		var got := cta_button(got_it_text, opts)
		var on_close: Callable = opts.get("on_close", Callable())
		if on_close.is_valid():
			got.pressed.connect(func() -> void: on_close.call())
		var btns := HBoxContainer.new()
		btns.alignment = BoxContainer.ALIGNMENT_CENTER
		btns.add_child(got)
		content.add_child(btns)
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
	# an optional centered FOOTER LINK — the Privacy Policy hyperlink the game wires to OS.shell_open
	# (App Store expects a reachable policy link for apps with purchases). Off by default so the
	# workbench preview stays a pure toggle list — the parallel of mail_dialog's footer note.
	var footer_text := String(opts.get("footer_text", ""))
	if footer_text != "":
		var link := LinkButton.new()
		link.text = footer_text
		link.underline = LinkButton.UNDERLINE_MODE_ALWAYS
		link.add_theme_font_override("font", plain_font())
		link.add_theme_font_size_override("font_size", int(opts.get("footer_font", 14)))
		link.add_theme_color_override("font_color", Color(Pal.BARK, 0.85))
		link.add_theme_color_override("font_hover_color", Color(Pal.BARK, 1.0))
		var on_footer: Callable = opts.get("on_footer", Callable())
		if on_footer.is_valid():
			link.pressed.connect(func() -> void: on_footer.call())
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(link)
		content.add_child(row)
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
	bnum.add_theme_font_override("font", plain_font())          # plain standard face, not the chunky display font
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
	pitch.add_theme_font_override("font", plain_font())          # plain standard face, not the chunky display font
	pitch.add_theme_font_size_override("font_size", int(opts.get("pitch_font", 16)))
	pitch.add_theme_color_override("font_color", Color(Pal.BARK, 0.95))
	pitch.add_theme_constant_override("outline_size", 0)
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
		hl.add_theme_font_override("font", plain_font())          # plain standard face, not the chunky display font
		hl.add_theme_font_size_override("font_size", 15)
		hl.add_theme_color_override("font_color", Color(Pal.BARK, 0.8))
		hl.add_theme_constant_override("outline_size", 0)
		hl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hint.add_child(hl)
		hint.add_child(make_icon("gem", 16))
		var hn := Label.new()
		hn.text = str(int(state.get("claim_min", 0)))
		hn.add_theme_font_override("font", plain_font())          # plain standard face, not the chunky display font
		hn.add_theme_font_size_override("font_size", 15)
		hn.add_theme_color_override("font_color", Color(Pal.BARK, 0.8))
		hn.add_theme_constant_override("outline_size", 0)
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
	# the bottom action is the SHARED pill_button — so its font tracks the Button component (opts.btn.font),
	# scaled to the card like everything else, instead of a constant. Edit the Button slider, every card follows.
	var claim_font := maxi(8, int(float(btn_opts.get("font", 18)) * s))
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
		# the mystery marker: the "?" chest by default, OR a per-day sprite the caller supplies (e.g. day 4's
		# gift box) via `mystery_icon` — so individual mystery days can read distinctly.
		center.add_child(_kit_sprite(String(d.get("mystery_icon", "kit/daily_chest.png")), cw * 0.56))
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

## --- the LAYERED level badge ---------------------------------------------------------
## Five cut parts (ui/lvl_parts/<part>_<stage>.png) composited bottom-up with the level
## NUMBER centered. The art has 6 stages per part; a 30-tier progression groups them:
## tier ÷ 6 = group (0..4), tier mod 6 + 1 = stage (1..6). Each GROUP draws a fixed set of
## parts at the current stage, so the badge accretes a centerpiece every 6 tiers. Shared by
## the workbench preview AND Look.make_level_badge (HUD chip / level dialog).
const LEVEL_PARTS := ["circle", "leaf", "flower", "acorn", "gem"]   # z-order: circle back -> gem front
const LEVEL_BADGE_GROUPS := [
	["leaf"],
	["leaf", "flower"],
	["leaf", "acorn"],
	["leaf", "flower", "gem"],
	["leaf", "acorn", "gem"],
]
## Per-part default geometry: x/y are % of px (from the bottom-centered baseline), scale is % of the box.
const _LEVEL_BADGE_DEFAULTS := {
	"circle": {"x": 0.0, "y": -4.0,  "scale": 90.0},
	"leaf":   {"x": 0.0, "y": 0.0,   "scale": 100.0},
	"flower": {"x": 0.0, "y": -10.0, "scale": 48.0},
	"acorn":  {"x": 0.0, "y": -8.0,  "scale": 52.0},
	"gem":    {"x": 0.0, "y": -40.0, "scale": 36.0},
}

## Decompose a 0-based tier into {group, stage (1..6), parts}. Clamps to the last group/stage.
static func level_badge_tier_parts(tier: int) -> Dictionary:
	var t := maxi(0, tier)
	var last := LEVEL_BADGE_GROUPS.size() - 1
	var group := mini(t / 6, last)
	var stage := 6 if t / 6 > last else t % 6 + 1     # clamped tiers hold at the fullest stage
	return {"group": group, "stage": stage, "parts": LEVEL_BADGE_GROUPS[group]}

## The workbench-tuned level-badge geometry from a saved config (cfg["level_badge"]). Every
## position/size knob is a PERCENT of the badge px so the emblem scales to any size.
static func level_badge_opts_from_config(cfg: Dictionary) -> Dictionary:
	var g: Dictionary = cfg.get("level_badge", {}) if cfg is Dictionary else {}
	var out := {
		"size":        float(g.get("size", 100.0)),      # the common part box, % of px
		"num_size":    float(g.get("num_size", 32.0)),   # the level number font, % of px
		"num_x":       float(g.get("num_x", 0.0)),       # number offset, % of px (side / margin)
		"num_y":       float(g.get("num_y", -16.0)),
		"num_burn":    float(g.get("num_burn", 0.0)),    # engraved 'burn' on the number (0..100)
		"circle_base": bool(g.get("circle_base", true)), # draw the coin behind every tier (toggleable)
		"circle_design": String(g.get("circle_design", "auto")), # 'auto' tracks the tier; "1".."6" pins a design
	}
	for p in LEVEL_PARTS:
		var dft: Dictionary = _LEVEL_BADGE_DEFAULTS[p]
		out[p + "_x"]     = float(g.get(p + "_x", dft["x"]))
		out[p + "_y"]     = float(g.get(p + "_y", dft["y"]))
		out[p + "_scale"] = float(g.get(p + "_scale", dft["scale"]))
	return out

## Build the layered level badge: the tier's parts (bottom-anchored, each at its tuned
## offset/scale) under the centered level NUMBER. `px` is the square size; `num_font` overrides
## the number font (auto from num_size when < 0). The number Label is named "lv_num" and each part
## TextureRect "lv_<part>" so a live caller (HUD level-up) can find and refresh them. `show_all`
## (workbench only) draws every part regardless of the tier, so they can all be positioned at once.
static func level_badge(opts: Dictionary, tier: int, level: int, px: float, num_font: int = -1, show_all: bool = false) -> Control:
	var root := Control.new()
	root.custom_minimum_size = Vector2(px, px)
	root.size = Vector2(px, px)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var info := level_badge_tier_parts(tier)
	var stage := int(info["stage"])
	var draw_parts: Array = LEVEL_PARTS.duplicate() if show_all else (info["parts"] as Array).duplicate()
	if not show_all and bool(opts.get("circle_base", true)) and not draw_parts.has("circle"):
		draw_parts.append("circle")     # always-on coin behind every tier (drawn first via z-order)
	# the coin's design: 'auto' tracks the tier stage; "1".."6" pins a fixed design from the asset.
	var circle_design := String(opts.get("circle_design", "auto"))
	var base_box := px * float(opts.get("size", 100.0)) / 100.0
	for part in LEVEL_PARTS:                            # canonical z-order; draw only the active parts
		if not draw_parts.has(part):
			continue
		var pstage := stage
		if part == "circle" and circle_design != "auto":
			pstage = clampi(int(circle_design), 1, 6)
		var tex := Look._safe_tex(Game.art("ui/lvl_parts/%s_%d.png" % [part, pstage]))
		if tex == null:
			continue
		var box := base_box * float(opts.get(part + "_scale", 100.0)) / 100.0
		var t := TextureRect.new()
		t.name = "lv_" + part
		t.texture = tex
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# the 512px part art is drawn as small as ~1/9 size on a board cell; the project default NEAREST
		# filter aliases hard when minified, so sample LINEAR + mipmaps here for a smooth shrink.
		t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		t.size = Vector2(box, box)
		# horizontally centered, bottom-aligned to the shared baseline, then nudged by the part's offset
		t.position = Vector2(
			(px - box) * 0.5 + px * float(opts.get(part + "_x", 0.0)) / 100.0,
			(px - box) + px * float(opts.get(part + "_y", 0.0)) / 100.0)
		root.add_child(t)
	if root.get_child_count() == 0:                    # no art at all -> warm honey token, no blank rect
		var coin := StyleBoxFlat.new()
		coin.bg_color = Color("#F4CF82"); coin.set_corner_radius_all(int(px / 2.0))
		coin.set_border_width_all(2); coin.border_color = Color("#8D6B35")
		var panel := Panel.new()
		panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		panel.add_theme_stylebox_override("panel", coin)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(panel)
	# the level number on top, centered then nudged by num_x / num_y (the "side and margin")
	var num := Label.new()
	num.name = "lv_num"
	num.text = str(level)
	num.set_anchors_preset(Control.PRESET_FULL_RECT)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	num.offset_left = px * float(opts.get("num_x", 0.0)) / 100.0
	num.offset_right = num.offset_left
	num.offset_top = px * float(opts.get("num_y", 0.0)) / 100.0
	num.offset_bottom = num.offset_top
	num.add_theme_font_size_override("font_size", _level_badge_font(level, px, opts, num_font))
	var burn := clampf(float(opts.get("num_burn", 0.0)) / 100.0, 0.0, 1.0)
	if burn > 0.0:
		# "burned into the coin": dark engraved ink + a light lower emboss + a soft dark halo (matches the
		# banner-text burn). Intensity (0..1) deepens the ink and grows the emboss/outline.
		num.add_theme_color_override("font_color", Color("#4A2E14").darkened(0.35 * burn))
		num.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.25 + 0.45 * burn))
		num.add_theme_constant_override("shadow_offset_x", int(round(1.0 + 2.0 * burn)))
		num.add_theme_constant_override("shadow_offset_y", int(round(2.0 + 3.0 * burn)))
		num.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.12 + 0.33 * burn))
		num.add_theme_constant_override("outline_size", int(round(2.0 + 4.0 * burn)))
	else:
		num.add_theme_color_override("font_color", Pal.INK)
		num.add_theme_constant_override("outline_size", 0)
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(num)
	return root

## The number font px: num_font when given (> 0), else num_size% of px, stepped down as digits grow.
static func _level_badge_font(level: int, px: float, opts: Dictionary, num_font: int) -> int:
	if num_font > 0:
		return num_font
	var base := px * float(opts.get("num_size", 32.0)) / 100.0
	var digits := str(maxi(0, level)).length()
	if digits >= 3:
		base *= 0.67
	elif digits == 2:
		base *= 0.81
	return int(maxf(8.0, base))

## The Level MEDALLION for dialogs/previews — now the shared LAYERED level badge (the same emblem the
## HUD chip and level dialog wear), tuned by the saved level_badge config so those surfaces match. Kept
## as a named helper so the level dialog reads clearly; `px` is the emblem size. opts may carry
## `number_font` (absolute override) — otherwise the tuned num_size drives the number.
static func level_medallion(level: int, px: float = 120.0, opts: Dictionary = {}) -> Control:
	var geo := level_badge_opts_from_config(load_config(CONFIG_PATH))
	var med := level_badge(geo, Look.level_badge_index(level), level, px, int(opts.get("number_font", -1)))
	med.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return med

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

## The dialog CTA button — the SHARED pill_button wearing the registered "level green" badge background
## (Kit.BADGES["level green"], the level_btn sprite). The SAME atom for the level dialog's Collect / Got it
## AND the mail/info "Got it" footer, so the green badged button is authored ONCE. `opts.btn` supplies the
## base pill style (font · padding); bg / art / art_rel / icon are forced to the level badge. SHRINK_CENTER
## so it sits centred under its column. Callers connect `.pressed` themselves.
static func cta_button(text: String, opts: Dictionary = {}) -> Button:
	var bo: Dictionary = (opts.get("btn", {}) as Dictionary).duplicate()
	bo["bg"] = "green"; bo["art"] = true; bo["art_rel"] = String(BADGES["level green"]); bo["icon"] = ""
	var btn := pill_button(text, bo)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return btn

## The whole LEVEL dialog: the dedicated frame + medallion + "X / Y ★ earned" + progress_bar + the
## "N more ★ to reach Level N+1" line (info) OR a reward chip row (levelup) + the bottom button (the
## shared cta_button with the green level_btn bg). `data` keys: level, earned, next, into, span,
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
	# the bottom button — the SHARED cta_button (the registered "level green" badge), the SAME atom the
	# mail/info "Got it" footer uses, so the green badged button is authored once.
	var btn_text := TranslationServer.translate("Collect") if mode == "levelup" else TranslationServer.translate("Got it")
	var btn := cta_button(btn_text, opts)
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
## One discovery tile, built straight onto the SHARED slot cell (Kit.slot_cell) so discovery, the bag, and the
## board all read as ONE component — there is NO separate tier-cell type. A DISCOVERED tier wears the FILLED
## well holding its piece; an UNDISCOVERED tier wears the LOCKED well — the baked gold padlock KEPT, no acorn
## cost, and no "?" glyph (the locked well stands in for it). Each tile carries a plain lower-right tier
## number, with no badge decoration. A MARKED tier (the tapped/asked one) is flagged by the engine sparkle.
## `opts` are slot-cell opts (the inherited slot look + the discovery `cell_w/cell_h`, `mark_glow`/`mark_twinkle`)
## from tiers_opts_from_config.
## The opts may carry a discovery make_content(d, px) — bridged to the slot cell's make_content(px) here.
## d keys: tier, seen, marked, icon|node. Private to _tiers_grid; the dialog is the only public surface.
static func _discovery_cell(d: Dictionary, opts: Dictionary) -> Control:
	var seen := bool(d.get("seen", false))
	var sd := {
		"state": ("filled" if seen else "locked"),
		"cost": 0,                                          # discovery has no buy price → the locked well is its baked padlock alone
		"marked": bool(d.get("marked", false)),
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
	# a tappable discovery cell (the Producing dialog's line cells drill into that line's tier ladder) —
	# slot_cell makes a FILLED cell a Button when on_tap is valid; a locked (unseen) cell ignores it.
	if d.get("on_tap") is Callable and (d.get("on_tap") as Callable).is_valid():
		sd["on_tap"] = d.get("on_tap")
	# dim_bg recedes the WELL for a discovered-but-inactive line (the Producing dialog) — forward it to slot_cell.
	if bool(d.get("dim_bg", false)):
		sd["dim_bg"] = true
	var cell := slot_cell(sd, opts)
	if bool(opts.get("show_num", true)):
		var tier := int(d.get("tier", 0))
		if tier > 0:
			var cw := float(opts.get("cell_w", 150.0))
			var ch := float(opts.get("cell_h", 150.0))
			var font := int(maxf(14.0, cw * 0.18))
			var num := Label.new()
			num.name = "TierNumber"
			num.text = str(tier)
			num.add_theme_font_size_override("font_size", font)
			num.add_theme_color_override("font_color", Color(Pal.INK, 0.92))
			num.add_theme_constant_override("outline_size", 0)
			num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			num.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			num.mouse_filter = Control.MOUSE_FILTER_IGNORE
			num.anchor_left = 1.0; num.anchor_top = 1.0; num.anchor_right = 1.0; num.anchor_bottom = 1.0
			num.offset_left = -cw * 0.34
			num.offset_top = -ch * 0.26
			num.offset_right = -cw * 0.07
			num.offset_bottom = -ch * 0.04
			cell.add_child(num)
	return cell

## A GRID of discovery cells — plain reading order (tier 1 top-left, filling `cols` per row), exactly like the
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
				var c := _discovery_cell(entries[i + j], co)
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
		"shadow_params": Look.shadow_params(cfg),
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

## A PLAIN, regular-weight face for body text that should read as STANDARD UI text — not the cozy chunky/
## outlined display font the global theme applies (the "bold marker" look). The info sheet's rows AND the
## vault's body text use this with the outline off, so the labels/amounts/notes read as clean normal text.
## Public so ui/vault.gd (loaded by path) can share the SAME face. Cached per session.
static var _plain_cache: Font = null
static func plain_font() -> Font:
	if _plain_cache != null:
		return _plain_cache
	var sys := SystemFont.new()
	sys.font_names = PackedStringArray(["SF Pro Text", "Helvetica Neue", "Segoe UI", "Roboto", "Arial", "Verdana"])
	sys.font_weight = 400
	sys.generate_mipmaps = true
	_plain_cache = sys
	return _plain_cache

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
		"banner_text_pad_l": float(d.get("banner_text_pad_l", float(d.get("banner_h", 92)) * 0.55)),   # title↔left-tail room
		"banner_text_pad_r": float(d.get("banner_text_pad_r", float(d.get("banner_h", 92)) * 0.55)),   # title↔right-tail room
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

## The INFO sheet's opts: the info sheet IS the shared MAIL DIALOG (parchment cards, NO Claim) with a
## level-style "Got it" footer, so it inherits dialog_opts_from_config WHOLESALE (border · banner ribbon ·
## ✕ · padding · card art/fonts — tuned on the Frame/Card elements, exactly like the mail dialog). Only the
## width differs: a 1–2 row sheet is narrower than the inbox. Read by BOTH the workbench preview and the
## game's _info_sheet, so a tweak flows to every shop detail sheet.
static func info_opts_from_config(cfg: Dictionary) -> Dictionary:
	var o := dialog_opts_from_config(cfg)        # the standard mail-dialog face: border + banner + ✕ + cards
	o["width_pct"] = float((cfg.get("info", {}) as Dictionary).get("width_pct", 58))
	return o

## The full DISCOVERY-dialog opts: the STANDARD shared frame, exactly like daily/shop/settings — it inherits
## dialog_opts_from_config wholesale (border, banner ribbon, ✕, geometry, padding), with NO bespoke chrome
## override. The discovery tile IS the shared slot cell, so its LOOK (piece size, level-medal size, well face)
## is INHERITED from the bag/slot config (bag_card_opts_from_config) — one source of truth, no duplicate knobs.
## Only the genuinely discovery-specific knobs live in the `tiers` block: the square cell size, whether the
## tier number shows, the marked-tier sparkle, and the grid (cols, gaps, scroll cap). Fractional sparkle knobs
## are stored as PERCENTS for the integer sliders and divided here. Edit the frame on the shared Frame item, or
## the cell look on the Slot-cell item, and both flow here. (The banner TEXT is the line name, passed by the caller.)
static func tiers_opts_from_config(cfg: Dictionary) -> Dictionary:
	var o := dialog_opts_from_config(cfg)
	# inherit the full shared slot-cell look (piece sizing + code-drawn well face); discovery overrides
	# only its own layout knobs below.
	var slot := bag_card_opts_from_config(cfg)
	o.merge(slot, true)
	var t: Dictionary = cfg.get("tiers", {})
	# discovery's OWN cell knobs: the square tile size, plain tier number, and marked-tier sparkle
	o["cell_w"] = float(t.get("cell_w", 150))
	o["cell_h"] = float(t.get("cell_h", 150))
	o["show_num"] = bool(t.get("show_num", true))                  # plain lower-right tier number
	o["mark_glow"] = float(t.get("mark_glow", 60)) / 100.0         # the marked tier's sparkle glow (0 = off)
	o["mark_twinkle"] = float(t.get("mark_twinkle", 50)) / 100.0   # ...and its drifting twinkles (0 = off)
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
	# NOTE: no baked `shadow` here — the disc/badge drop shadow is the SHARED box-shadow, cast behind the
	# home button by home_button() (the Shadow toggle), so the shell texture stays a clean, bakeable recipe.
	var b: Dictionary = cfg.get("badge", {})
	return {
		"defringe": bool(b.get("defringe", false)),
		"feather": float(b.get("feather", 0)),
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

## The GENERATOR HIGHLIGHT opts from a saved config — the glow halo / silhouette outline / sparkle that
## marks a board generator (drawn by engine PieceView.make_generator). Stored as workbench-friendly ints
## (percent / per-mille / count) and converted to the fractions the builder reads. Returns {} when the
## "generator" block is absent so the engine falls back to its shipped GEN_* consts (the source of truth
## for the defaults below — keep them in sync with piece_view.gd).
static func gen_highlight_opts_from_config(cfg: Dictionary) -> Dictionary:
	var g: Dictionary = cfg.get("generator", {})
	if g.is_empty():
		return {}
	return {
		"glow_scale": float(g.get("glow_scale", 100)) / 100.0,    # halo size, % of cell
		"glow_a": float(g.get("glow_a", 30)) / 100.0,             # halo opacity
		"outline_w": float(g.get("outline_w", 35)) / 1000.0,      # rim thickness, per-mille of cell
		"outline_a": float(g.get("outline_a", 85)) / 100.0,       # rim opacity
		"sparkle_count": int(g.get("sparkle_count", 5)),          # twinkle count
		"sparkle_speed": float(g.get("sparkle_speed", 70)) / 100.0,   # twinkle cycles/sec
	}

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
		# the caption tab's OWN padding (overrides the shared title-ribbon margins for the home button only);
		# defaults reproduce the shipped ribbon (Tune.TITLE_PAD_X / ~T+B) so an absent config is unchanged.
		"caption_pad_x": float(h.get("caption_pad_x", 30)),
		"caption_pad_y": float(h.get("caption_pad_y", 8)),
		# the rect-badge OPACITY (0..100 %): modulates the painted badge so the rail / Map tiles can read
		# translucent over the homestead. Default 100 → opaque, so the shipped disc buttons are unchanged.
		"fill_alpha": float(h.get("fill_alpha", 100)),
		# the rect-badge inner PADDING as a fraction of px (the icon+caption inset off the badge edge).
		"rect_pad": float(h.get("rect_pad", 13)) / 100.0,
		# the orange PLAY disc's diameter (px) — the bottom-right CTA. Bigger than the 140 Map/rail buttons.
		"play_px": float(h.get("play_px", 188)),
		# the DROP SHADOW: cast the SHARED box-shadow behind the badge / disc (on by default — the shipped rail +
		# Map tiles lift off the homestead). home_button() shapes it per button (rounded rect vs circle).
		"shadow": bool(h.get("shadow", true)),
		"shadow_params": Look.shadow_params(cfg),
		"glow": float(h.get("glow", 0)) / 100.0,
		"twinkle": float(h.get("twinkle", 0)) / 100.0,
		# the count/dot BADGE offset (px past the disc's top-right corner): a caller's attach_badge nudges
		# the badge by this, so the side rail can pull it snug to the disc. The disc art carries a wide
		# transparent margin, so the default tucks the badge well IN (negative) to sit on the disc's edge.
		"badge_dx": float(h.get("badge_dx", -26)),
		"badge_dy": float(h.get("badge_dy", -26)),
		# the in-disc COUNT overlay (the Bag well's "x/y" slot count): its offset from the disc centre (px)
		# and its font. Only a button GIVEN count text (the bag) draws it; everything else ignores these.
		"count_dx": float(h.get("count_dx", 0)),
		"count_dy": float(h.get("count_dy", 38)),
		"count_font": int(h.get("count_font", 26)),
		# the count/dot BADGE size (px): the bare-dot diameter, and the count-pill number font (the pill height
		# tracks it). Defaults mirror Tune.BADGE_DOT_PX / BADGE_NUM_SIZE so an absent config renders the shipped badge.
		"badge_dot_px": int(h.get("badge_dot_px", 14)),
		"badge_num_size": int(h.get("badge_num_size", 14)),
		"badge": badge_polish_from_config(cfg),    # the Badge item's shell polish (defringe / feather / shadow)
	}

## Screen-relative HUD layout from the workbench. These are OUTER geometry slots, not the art recipe:
## level badge width, wallet band/pill widths, top band reserved before side rail/settings, shared nav
## button width, board info-bar width, board bottom-row height, and the shared right-edge inset for the wallet + rail.
## Stored as whole percents for simple workbench sliders, except edge_margin_px which is literal pixels.
static func hud_layout_opts_from_config(cfg: Dictionary) -> Dictionary:
	var h: Dictionary = cfg.get("hud_layout", {}) if cfg is Dictionary else {}
	return {
		"level_w_frac": clampf(float(h.get("level_w_pct", 25.0)) / 100.0, 0.05, 0.80),
		"currency_area_frac": clampf(float(h.get("currency_area_pct", 75.0)) / 100.0, 0.10, 1.0),
		"currency_pill_w_frac": clampf(float(h.get("currency_pill_w_pct", 25.0)) / 100.0, 0.05, 0.60),
		"top_band_h_frac": clampf(float(h.get("top_band_h_pct", 15.0)) / 100.0, 0.0, 0.50),
		"button_w_frac": clampf(float(h.get("button_w_pct", 15.0)) / 100.0, 0.05, 0.50),
		"info_bar_w_frac": clampf(float(h.get("info_bar_w_pct", 70.0)) / 100.0, 0.10, 0.95),
		"bottom_row_h_frac": clampf(float(h.get("bottom_row_h_pct", 0.0)) / 100.0, 0.0, 0.40),
		# quest band height (% screen height); board.gd clamps it to [QUEST_H_MIN, QUEST_H_MAX]. The old
		# quest/board x·y and board-height fracs are retired — the live layout is responsive + bottom-anchored.
		"quest_bar_h_frac": clampf(float(h.get("quest_bar_h_pct", 11.0)) / 100.0, 0.02, 0.50),
		"edge_margin_px": clampf(float(h.get("edge_margin_px", 18.0)), 0.0, 96.0),
	}

## The SELECTED-cell focus ring (corner brackets) tuning from the workbench. Colours are saved as
## 6-digit hex strings (no '#'); the rest are whole percents. Flows to the live board via board.gd
## _focus_ring_opts → applied to the FocusRing control (engine/scripts/ui/focus_ring.gd).
static func focus_ring_opts_from_config(cfg: Dictionary) -> Dictionary:
	var f: Dictionary = cfg.get("focus_ring", {}) if cfg is Dictionary else {}
	return {
		"color": _hex_color(String(f.get("color", "33402F"))),
		"halo_color": _hex_color(String(f.get("halo_color", "FBF3EA"))),
		"halo_a": clampf(float(f.get("halo_a", 90.0)) / 100.0, 0.0, 1.0),
		"arm_frac": clampf(float(f.get("arm_pct", 30.0)) / 100.0, 0.05, 0.50),
		"thick_frac": clampf(float(f.get("thick_pct", 8.0)) / 100.0, 0.01, 0.20),
		"pad_frac": clampf(float(f.get("pad_pct", 4.0)) / 100.0, 0.0, 0.20),
		"halo": bool(f.get("halo", true)),
	}

## Parse a 6-digit hex string (with or without a leading '#') into a Color; falls back to white.
static func _hex_color(hex: String) -> Color:
	var h := hex.strip_edges()
	if not h.begins_with("#"):
		h = "#" + h
	return Color.from_string(h, Color.WHITE)

## Board bottom action-bar tuning from the workbench. Values are saved as whole percents:
## icon_scale_pct is the single shared Bag/Home icon size; pad_*_pct are % of bar height; info_x_pct
## nudges only the center info content. Home and Bag keep fixed edge alignment.
static func action_bar_opts_from_config(cfg: Dictionary) -> Dictionary:
	var i: Dictionary = cfg.get("info_bar", {}) if cfg is Dictionary else {}
	var legacy: Dictionary = cfg.get("action_bar", {}) if cfg is Dictionary else {}
	return {
		"icon_scale": clampf(float(i.get("icon_scale_pct", legacy.get("icon_scale_pct", 50.0))) / 100.0, 0.10, 1.50),
		"pad_x_frac": clampf(float(i.get("pad_x_pct", legacy.get("pad_x_pct", 0.0))) / 100.0, 0.0, 0.30),
		"pad_y_frac": clampf(float(i.get("pad_y_pct", legacy.get("pad_y_pct", 0.0))) / 100.0, 0.0, 0.30),
		"info_x_frac": clampf(float(i.get("info_x_pct", legacy.get("info_x_pct", 0.0))) / 100.0, -0.50, 0.50),
	}

static func live_board_frame_size(view_size: Vector2, cfg: Dictionary, cols := 7.0, rows := 9.0) -> Vector2:
	var b: Dictionary = cfg.get("board", {}) if cfg is Dictionary else {}
	var gap := float(b.get("gap", 7.0))
	var frame := float(b.get("frame", 60.0))
	var scale := float(b.get("scale", 100.0)) / 100.0
	# WIDTH-governed: square cells fill the screen width; the height budget (view.y - 536) is only a
	# cap so the board can't grow past the quest/bottom rows. Mirrors board.gd's live fit.
	var cell_w := (view_size.x - 12.0 - frame * 2.0 - (cols - 1.0) * gap) / cols
	var cell_h := (view_size.y - 536.0 - frame * 2.0 - (rows - 1.0) * gap) / rows
	var csz := maxf(1.0, minf(cell_w, cell_h) * scale)
	return Vector2(cols * csz + (cols - 1.0) * gap + frame * 2.0, rows * csz + (rows - 1.0) * gap + frame * 2.0)

static func live_quest_bar_top_y(safe_top := 0.0) -> float:
	return safe_top + 44.0 + 10.0

static func live_quest_bar_height() -> float:
	return 215.0

static func live_board_frame_top_y(safe_top := 0.0) -> float:
	return live_quest_bar_top_y(safe_top) + live_quest_bar_height() + 10.0

## The shared GOLD CURRENCY PILL style opts from a saved config. The HUD, bag dialog, and workbench
## all build the same gold_badge-backed component directly from this block.
static func gold_currency_pill_opts_from_config(cfg: Dictionary) -> Dictionary:
	var g: Dictionary = cfg.get("gold_currency_pill", {}) if cfg is Dictionary else {}
	var scale := maxf(0.01, float(g.get("overall_scale", 100.0)) / 100.0)
	var icon_box := float(g.get("icon_box", 54.0)) * scale
	var icon_size := float(g.get("icon_size", 34.0)) * scale
	# the OVERALL drop shadow starts from the shared shadow look, but the pill can OVERRIDE any of
	# its knobs (strength/offset/blur/spread/warmth) — so the wallet capsule can cast its own shadow
	# independent of the rest. Each override is opt-in: absent keys fall through to the shared values.
	var sp: Dictionary = Look.shadow_params(cfg)
	if g.has("shadow_alpha"):
		sp["alpha"] = clampf(float(g["shadow_alpha"]) / 100.0, 0.0, 1.0)
	if g.has("shadow_offset_x"):
		sp["offset_x"] = float(g["shadow_offset_x"])
	if g.has("shadow_offset_y"):
		sp["offset_y"] = float(g["shadow_offset_y"])
	if g.has("shadow_blur"):
		sp["blur"] = float(g["shadow_blur"])
	if g.has("shadow_spread"):
		sp["spread"] = float(g["shadow_spread"])
	if g.has("shadow_warmth"):
		sp["warmth"] = clampf(float(g["shadow_warmth"]) / 100.0, 0.0, 1.0)
	return {
		"shadow": bool(g.get("shadow", false)),
		"shadow_params": sp,
		# the capsule FRAME is the shared gold-badge skin — fold the tuned block in as `badge` so the HUD /
		# bag / info bar paint the SAME skin the workbench preview injects (gc["badge"] = _params["gold_badge"]).
		"badge": cfg.get("gold_badge", {}) if cfg is Dictionary else {},
		"pill_w": float(g.get("pill_w", 292.0)) * scale,
		"pill_h": float(g.get("pill_h", 100.0)) * scale,
		"pad_left": float(g.get("pad_left", 18.0)) * scale,
		"pad_x": float(g.get("pad_x", 16.0)) * scale,
		"pad_y": float(g.get("pad_y", 12.0)) * scale,
		"icon_box": icon_box,
		"icon_size": icon_size,
		"icon_x": float(g.get("icon_x", 0.0)) * scale,
		"amount_w": float(g.get("amount_w", 88.0)) * scale,
		"num_size": maxi(1, int(round(float(g.get("num_size", 30)) * scale))),
		"amount_x": float(g.get("amount_x", 0.0)) * scale,
		"gap": int(round(float(g.get("gap", 12)) * scale)),
		"plus_x": float(g.get("plus_x", 0.0)) * scale,
		"plus_radius": float(g.get("plus_radius", 28.0)),
		"plus_shine": float(g.get("plus_shine", 32.0)),
		"plus_stroke": float(g.get("plus_stroke", 2.0)) * scale,
		"plus_font": float(g.get("plus_font", 70.0)) * scale,
		"plus_button": float(g.get("plus_button", 100.0)) * scale,
		"plus_round": float(g.get("plus_round", 8.0)),
		"plus_hue": float(g.get("plus_hue", 65.0)),
		"plus_label_y": float(g.get("plus_label_y", 0.0)) * scale,   # vertical nudge of the "+" within the green button
		"inner_shadow": float(g.get("inner_shadow", 30.0)),
		"show_plus": true,
	}

## The bottom-bar INFO BAR style opts from a saved config — the board's centre pill (info ⓘ · selected
## piece + name · sell cart). The LAYOUT persists here; the FRAME comes from the shared code-drawn
## gold badge block, with the gold currency pill padding retained as the content margin.
## inner_scale / sell_icon / item_icon_scale are stored 0..100 and divided here to fractions of the bar height.
static func info_bar_opts_from_config(cfg: Dictionary) -> Dictionary:
	var i: Dictionary = cfg.get("info_bar", {}) if cfg is Dictionary else {}
	# The content margins borrow the gold wallet's padding numbers, but the visible board comes from the
	# saved gold_badge style so the board frame and info bar can be tuned together.
	var pill: Dictionary = gold_currency_pill_opts_from_config(cfg)
	return {
		"height":      float(i.get("height", 130)),                 # the bar height (matches the Bag/Home wells)
		"inner_scale": float(i.get("inner_scale", 48)) / 100.0,     # the info ⓘ slot as % of the bar height
		"item_icon_scale": float(i.get("item_icon_scale", 80)) / 100.0, # selected item/generator art as % of bar height
		"info_x":      float(i.get("info_x", 0)),                   # nudge the info ⓘ button left(−) / right(+)
		"info_y":      float(i.get("info_y", 0)),                   # nudge the info ⓘ button up(−) / down(+)
		"info_button_scale": clampf(float(i.get("info_button_scale", 100)) / 100.0, 0.25, 2.0),
		"hide_info_button": bool(i.get("hide_info_button", false)),
		"name_font":   int(i.get("name_font", 32)),                 # the "<name> · Tier N" font
		"desc_font":   int(i.get("desc_font", 18)),                 # the compact player-use hint under the selected item name
		"sep":         int(i.get("sep", 10)),                       # the gap between the bar's controls
		"sell_font":   int(i.get("sell_font", 30)),                 # the sell badge's payout number font
		"sell_label_font": int(i.get("sell_label_font", 22)),       # the plain "Sell" caption above the badge
		"sell_icon":   float(i.get("sell_icon", 30)) / 100.0,       # the payout coin as % of the bar height
		"sell_badge_radius": int(i.get("sell_badge_radius", 10)),   # the green badge's corner radius (softer than the full pill)
		"vpad":        float(i.get("vpad", 8)),                      # the gold frame's top/bottom padding (its own, not the wallet's)
		"pad_right":   float(i.get("pad_right", 16)),               # the gold frame's RIGHT padding — pins the Sell button off the edge
		"pill":        pill,                                        # shared padding/margin opts retained for content spacing
		"badge":       gold_badge_opts_from_config(cfg),             # shared code-drawn board/info frame style
	}

## --- the bottom-bar INFO BAR: [selected piece] [name] [Sell badge], with floating [info ⓘ] -----------
## The board's centre bottom-bar pill. It carries the SELECTED board item: an info button (opens that
## item's tier ladder), the piece preview + its "<name> · Tier N", and a sell button — the word "Sell" in
## plain ink over a vertical green badge (the payout coin on top, the payout number below).
## The FRAME is the shared gold badge skin, so the board border and bottom bar read as one surface.
## The board AND the workbench build through this — a layout tweak (height · inner control scale · name
## font · separation · selected-item art scale · info button position/scale · sell button) flows to the live bar. The bar is STATELESS: the caller drives the
## empty/selected state by mutating the sub-nodes exposed via meta (info_btn / info_icon / name_label /
## sell_btn / inner_px / item_icon_scale / info_button_scale), so the board's selection logic is unchanged.
##   spec (per-instance wiring): info_action (Callable) · sell_action (Callable).
##   opts (shared STYLE — see info_bar_opts_from_config): height · inner_scale (0..1) · name_font · sep ·
##     item_icon_scale (0..1+, selected art as % of bar height) · info_x/info_y ·
##     info_button_scale (0..1+, info-button art inside its fixed slot) · sell_font (payout number) ·
##     sell_label_font ("Sell" caption) · sell_icon (0..1, the coin) · badge (the shared gold badge
##     frame opts) · pill (content margins).
static func info_bar(spec: Dictionary, opts: Dictionary = {}) -> PanelContainer:
	var height := float(opts.get("height", 130.0))
	var inner := height * float(opts.get("inner_scale", 0.48))   # the info ⓘ slot scale with the bar
	var item_icon_px := height * float(opts.get("item_icon_scale", 0.80))
	var pill := PanelContainer.new()
	pill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pill.custom_minimum_size.y = height
	var frame := gold_badge_style(opts.get("badge", {}))
	var pad: Dictionary = opts.get("pill", {})
	var pad_x := float(pad.get("pad_x", 18.0))
	frame.content_margin_left = float(pad.get("pad_left", pad_x))
	# the RIGHT padding is its OWN knob — the name label expands to fill, so this gap pins the Sell button
	# off the right edge. Small by default so the button sits near the very right.
	frame.content_margin_right = float(opts.get("pad_right", 16.0))
	# vertical frame padding is its OWN knob (not the wallet's tall pad_y) — the bar's content is now a
	# taller "Sell" stack, so it hugs top/bottom tighter and the pill stays height-matched to the wells.
	var vpad := float(opts.get("vpad", 8.0))
	frame.content_margin_top = vpad
	frame.content_margin_bottom = vpad
	pill.add_theme_stylebox_override("panel", frame)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", int(opts.get("sep", 10)))
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	pill.add_child(hb)
	var item_text_row := HBoxContainer.new()
	item_text_row.add_theme_constant_override("separation", 0)
	item_text_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_text_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	item_text_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var info_action: Callable = spec.get("info_action", Callable())
	var info_icon := CenterContainer.new()                       # selected-piece preview; tapping it opens the same info dialog as the ⓘ button
	info_icon.custom_minimum_size = Vector2(item_icon_px, height)
	info_icon.mouse_filter = Control.MOUSE_FILTER_STOP if info_action.is_valid() else Control.MOUSE_FILTER_IGNORE
	if info_action.is_valid():
		info_icon.gui_input.connect(func(ev: InputEvent) -> void:
			var tapped := false
			if ev is InputEventMouseButton:
				var mb := ev as InputEventMouseButton
				tapped = mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed
			elif ev is InputEventScreenTouch:
				tapped = not (ev as InputEventScreenTouch).pressed
			if not tapped:
				return
			info_action.call()
			var vp := info_icon.get_viewport()
			if vp != null:
				vp.set_input_as_handled()
		)
	item_text_row.add_child(info_icon)
	var text_stack := VBoxContainer.new()
	text_stack.add_theme_constant_override("separation", 0)
	text_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_stack.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item_text_row.add_child(text_stack)
	hb.add_child(item_text_row)
	var info_btn_scale := clampf(float(opts.get("info_button_scale", 1.0)), 0.25, 2.0)
	var info_btn_px := maxf(1.0, inner * info_btn_scale)
	var hide_info_button := bool(opts.get("hide_info_button", false))
	var info_btn := _info_circle_btn("info", info_btn_px)        # opens the selected item's tier ladder
	if info_action.is_valid():
		info_btn.pressed.connect(info_action)
	info_btn.visible = not hide_info_button
	info_btn.disabled = hide_info_button
	# The ⓘ floats above the row in a fixed footprint; x/y/scale move the button without pushing the item,
	# label, or Sell chip around.
	var info_x := float(opts.get("info_x", 0.0))
	var info_y := float(opts.get("info_y", 0.0))
	var info_overlay := Control.new()
	info_overlay.name = "InfoButtonOverlay"
	info_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_overlay.z_index = 5
	pill.add_child(info_overlay)
	var info_slot := Control.new()
	info_slot.name = "InfoButtonSlot"
	info_slot.custom_minimum_size = Vector2(inner, inner)
	info_slot.size = Vector2(inner, inner)
	info_slot.position = Vector2(0.0, maxf(0.0, (height - (vpad * 2.0) - inner) * 0.5))
	info_slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_btn.size = Vector2(info_btn_px, info_btn_px)
	info_btn.position = Vector2((inner - info_btn_px) * 0.5 + info_x, (inner - info_btn_px) * 0.5 + info_y)
	info_slot.add_child(info_btn)
	info_overlay.add_child(info_slot)
	var name_label := Label.new()                                # "<name> · Tier N" (or the empty prompt)
	name_label.add_theme_font_size_override("font_size", int(opts.get("name_font", 32)))
	name_label.add_theme_color_override("font_color", Pal.INK)
	name_label.add_theme_constant_override("outline_size", 0)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.clip_text = false
	text_stack.add_child(name_label)
	var desc_label := Label.new()                                # one-line player-use hint; hidden when empty
	desc_label.add_theme_font_size_override("font_size", int(opts.get("desc_font", 18)))
	desc_label.add_theme_color_override("font_color", Color(Pal.BARK, 0.92))
	desc_label.add_theme_constant_override("outline_size", 0)
	desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.clip_text = false
	desc_label.visible = false
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_stack.add_child(desc_label)
	var sell_btn := Button.new()                                 # sells the selected item; content = "Sell" over a coin·payout badge
	sell_btn.focus_mode = Control.FOCUS_NONE
	sell_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sell_icon_px := height * float(opts.get("sell_icon", 0.30))
	var sell_label_font := int(opts.get("sell_label_font", 22))
	var sell_num_font := int(opts.get("sell_font", 30))
	# content STACK: the word "Sell" in plain ink ABOVE a vertical green badge (coin on top, the payout number
	# below). The label rides on the bar surface — the green is only the badge. A mouse-ignoring centered
	# stack so the WHOLE button stays the single tap target (children pass their clicks through).
	var sell_stack := VBoxContainer.new()
	sell_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	sell_stack.add_theme_constant_override("separation", 3)
	sell_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sell_label := Label.new()                                # the plain "Sell" caption above the badge
	sell_label.text = "Sell"
	sell_label.add_theme_font_size_override("font_size", sell_label_font)
	sell_label.add_theme_color_override("font_color", Pal.INK)
	sell_label.add_theme_constant_override("outline_size", 0)
	sell_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sell_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sell_stack.add_child(sell_label)
	# the green badge — a VERTICAL pill: the payout currency rides on top, the amount sits below it.
	var badge_col := VBoxContainer.new()
	badge_col.alignment = BoxContainer.ALIGNMENT_CENTER
	badge_col.add_theme_constant_override("separation", 1)
	badge_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# the payout currency is the game's STANDARD coin/acorn icon (the caller fills it via Look.icon, swapped
	# per payout) — on TOP of the badge.
	var sell_coin := CenterContainer.new()
	sell_coin.custom_minimum_size = Vector2(sell_icon_px, sell_icon_px)
	sell_coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_col.add_child(sell_coin)
	var sell_count := Label.new()                                # the payout amount (the caller sets the text), under the coin
	sell_count.add_theme_font_size_override("font_size", sell_num_font)
	sell_count.add_theme_color_override("font_color", Pal.CREAM)
	sell_count.add_theme_constant_override("outline_size", 0)
	sell_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sell_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_col.add_child(sell_count)
	# the badge wears the game's STANDARD green primary-CTA fill (Pal.BTN_PRIMARY) — the same leaf-green pill
	# Look.button(primary) uses — so the bottom bar speaks one button language. (Previously the green dressed
	# the whole button; now it's only the badge, with "Sell" sitting above it on the bar surface.)
	var badge := PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ts := StyleBoxFlat.new()
	ts.bg_color = Pal.BTN_PRIMARY
	ts.border_color = Pal.BTN_PRIMARY_EDGE
	ts.set_corner_radius_all(int(opts.get("sell_badge_radius", 10)))   # a softer rounded-rect, not the full pill
	ts.set_border_width_all(Tune.BTN_BORDER_W)
	ts.shadow_color = Color(0, 0, 0, 0.16)                             # very minimal lift (was the heavy SHADOW_RAISED)
	ts.shadow_size = 2
	ts.shadow_offset = Vector2(0, 1)
	ts.content_margin_left = 14
	ts.content_margin_right = 14
	ts.content_margin_top = 4
	ts.content_margin_bottom = 4
	badge.add_theme_stylebox_override("panel", ts)
	badge.add_child(badge_col)
	sell_stack.add_child(badge)
	# size the button to its content (a Button does not grow to fit child controls), then LEFT-align the stack in
	# it via a full-rect HBox. The min height tracks the label + coin + number so the badge never clips and the
	# bar height stays close to the Bag/Home wells. Left-aligning pins the Sell badge to its button's left edge so
	# it hugs the buy chip beside it (which right-aligns the same way) — closing the gap between the two chips.
	var sell_h := int(sell_label_font * 1.45) + 3 + 8 + sell_icon_px + 1 + int(sell_num_font * 1.45)
	sell_btn.custom_minimum_size = Vector2(maxf(sell_icon_px + 64.0, 96.0), sell_h)
	var sell_center := HBoxContainer.new()                       # left-align the stack within the button rect
	sell_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	sell_center.alignment = BoxContainer.ALIGNMENT_BEGIN
	sell_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sell_stack.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sell_stack.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sell_center.add_child(sell_stack)
	sell_btn.add_child(sell_center)
	# the button itself is transparent — the green now lives on the inner badge; the press juice (scale)
	# carries the tactile feedback.
	var flat := StyleBoxEmpty.new()
	sell_btn.add_theme_stylebox_override("normal", flat)
	sell_btn.add_theme_stylebox_override("hover", flat)
	sell_btn.add_theme_stylebox_override("pressed", flat)
	if spec.has("sell_action") and (spec.get("sell_action") as Callable).is_valid():
		sell_btn.pressed.connect(spec.get("sell_action"))
	Look.add_press_juice(sell_btn)
	hb.add_child(sell_btn)
	# expose the mutable sub-nodes so the caller drives selection state without rebuilding the bar
	pill.set_meta("info_btn", info_btn)
	pill.set_meta("info_icon", info_icon)
	pill.set_meta("name_label", name_label)
	pill.set_meta("desc_label", desc_label)
	pill.set_meta("sell_btn", sell_btn)
	pill.set_meta("sell_count", sell_count)
	pill.set_meta("sell_coin", sell_coin)
	pill.set_meta("inner_px", inner)
	pill.set_meta("item_icon_scale", float(opts.get("item_icon_scale", 0.80)))
	pill.set_meta("item_icon_px", item_icon_px)
	pill.set_meta("info_y", float(opts.get("info_y", 0.0)))
	pill.set_meta("info_button_scale", info_btn_scale)
	pill.set_meta("hide_info_button", hide_info_button)
	return pill

## The info bar's "ⓘ" button. When the shipped disc sprite (ui/shared/icon_<id>.png — the cream
## disc + "i" cut from action_asset) is present it IS the whole button face: a transparent button
## under the texture, rendered edge-to-edge. The disc art already carries its own cream fill +
## border, so drawing a pill behind it would double the disc. Falls back to a drawn cream disc +
## centred glyph when the sprite is absent (mirrors the board's old _circle_btn).
static func _info_circle_btn(icon_id: String, px: float) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(px, px)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var disc_p := Look.kit("shared/icon_%s.png" % icon_id)
	if ResourceLoader.exists(disc_p):
		var empty := StyleBoxEmpty.new()
		for st in ["normal", "hover", "pressed", "disabled"]:
			b.add_theme_stylebox_override(st, empty)
		var tr := TextureRect.new()
		tr.texture = load(disc_p)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(tr)
		Look.add_press_juice(b)
		return b
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Pal.CREAM)
	sb.set_corner_radius_all(int(px / 2.0))
	sb.set_border_width_all(2)
	sb.border_color = Pal.STRAW
	for st in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(st, sb)
	var ic := Look.icon(icon_id, px * 0.58)
	ic.set_anchors_preset(Control.PRESET_FULL_RECT)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(ic)
	Look.add_press_juice(b)
	return b

## --- the BOARD PANEL: the rounded frame the cells sit on ---------------------------------------------
## ONE builder shared by the live board (board.gd _make_board_mat) AND the workbench preview, so they read
## 1:1 (the workbench shows the ACTUAL border). Two styles, chosen by board.frame_style:
##   "badge" (default) — the shared code-drawn gold badge, 9-sliced so the border stays thin however the
##                       board stretches; plus a soft drop shadow under the whole board.
##   "code"  — a code-drawn rounded-rect for tuning a depth effect: cream fill, an outer border (border_w),
##             an optional inner hairline (inner_w = "the border of the border"), and a top inset shadow for
##             depth (top_shadow). The under-board drop shadow is the SHARED box-shadow (the `shadow` toggle).

## opts (board.* config): frame_style · corner · border_w · inner_w · top_shadow (0..100) · shadow (bool) + shadow_params.
static func board_panel(size: Vector2, opts: Dictionary = {}) -> Control:
	var root := Control.new()
	root.custom_minimum_size = size
	root.size = size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var corner := int(opts.get("corner", GOLD_BADGE_CAP))
	# the soft drop shadow under the WHOLE board (both styles) — the SHARED box-shadow, a sibling drawn BEHIND
	# (show_behind_parent) so it bleeds past the edge. NinePatchRect has no native shadow. On via the toggle.
	if bool(opts.get("shadow", false)):
		var sh := Look.shadow_rect(float(corner), opts.get("shadow_params", {}))
		sh.show_behind_parent = true
		root.add_child(sh)
	if String(opts.get("frame_style", "badge")) == "code":
		# code-drawn rounded-rect: cream fill + a gold outer border, corners held by `corner`.
		var border_w := int(opts.get("border_w", 4))
		var panel := Panel.new()
		panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("#FBF3E2")          # the parchment cream the cells sit on
		sb.set_corner_radius_all(corner)
		sb.set_border_width_all(border_w)
		sb.border_color = Pal.STRAW
		panel.add_theme_stylebox_override("panel", sb)
		root.add_child(panel)
		# a TOP inset shadow for depth ("shadow near the top"): a dark, downward-fading strip clipped to the
		# panel, so the board reads slightly sunken under its top rim.
		var top := clampf(float(opts.get("top_shadow", 0)) / 100.0, 0.0, 1.0)
		if top > 0.0:
			var grad := Gradient.new()
			grad.set_color(0, Color(0.0, 0.0, 0.0, 0.5 * top))
			grad.set_color(1, Color(0.0, 0.0, 0.0, 0.0))
			var gtex := GradientTexture2D.new()
			gtex.gradient = grad
			gtex.fill_from = Vector2(0.0, 0.0)
			gtex.fill_to = Vector2(0.0, 1.0)
			gtex.width = 4
			gtex.height = 64
			var tr := TextureRect.new()
			tr.texture = gtex
			tr.stretch_mode = TextureRect.STRETCH_SCALE
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var pad := float(border_w) + 1.0
			tr.position = Vector2(pad + corner * 0.4, pad)
			tr.size = Vector2(maxf(0.0, size.x - 2.0 * (pad + corner * 0.4)), size.y * 0.22)
			root.add_child(tr)
		# the inner hairline — "the border of the border" — an inset rounded-rect drawing only its border.
		var inner_w := int(opts.get("inner_w", 0))
		if inner_w > 0:
			var inset := float(border_w) + 4.0
			var inner := Panel.new()
			inner.set_anchors_preset(Control.PRESET_FULL_RECT)
			inner.offset_left = inset; inner.offset_top = inset
			inner.offset_right = -inset; inner.offset_bottom = -inset
			inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var isb := StyleBoxFlat.new()
			isb.draw_center = false
			isb.set_corner_radius_all(maxi(0, corner - int(inset)))
			isb.set_border_width_all(inner_w)
			isb.border_color = Color(Pal.STRAW, 0.55)
			inner.add_theme_stylebox_override("panel", isb)
			root.add_child(inner)
	else:
		var badge: Dictionary = opts.get("badge", {})
		var frame := gold_badge_style(badge)
		var cap := gold_badge_cap(badge)
		var np := NinePatchRect.new()
		np.texture = frame.texture
		np.set_anchors_preset(Control.PRESET_FULL_RECT)
		np.patch_margin_left = cap
		np.patch_margin_top = cap
		np.patch_margin_right = cap
		np.patch_margin_bottom = cap
		np.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_STRETCH
		np.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_STRETCH
		np.draw_center = bool(opts.get("draw_center", true))
		np.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(np)
	return root

## The board-panel frame opts from a saved config — the frame style, its code-drawn depth knobs, and the
## shared gold_badge style used by the default badge frame.
static func board_panel_opts_from_config(cfg: Dictionary) -> Dictionary:
	var b: Dictionary = cfg.get("board", {}) if cfg is Dictionary else {}
	return {
		"frame_style": String(b.get("frame_style", "badge")),   # "badge" (gold_badge) | "code" (code-drawn)
		"corner":      int(b.get("frame_corner", GOLD_BADGE_CAP)),
		"border_w":    int(b.get("frame_border_w", 4)),          # code: outer border thickness
		"inner_w":     int(b.get("frame_inner_w", 0)),           # code: inner hairline (border-of-the-border); 0 = off
		"top_shadow":  float(b.get("frame_top_shadow", 0)),      # code: top inset shadow depth (0..100) — a border highlight, NOT the drop shadow
		"shadow":      bool(b.get("shadow", true)),              # cast the SHARED box-shadow under the board (on by default)
		"shadow_params": Look.shadow_params(cfg),                # the single shared shadow look
		"badge":       gold_badge_opts_from_config(cfg),          # shared code-drawn badge skin for board/info
	}

## --- the bag screen: the slot CELL + the dialog -----------------------------------------------------
## The slot cell is ONE component card with four states. All states use the same code-drawn background
## so the board, bag, and discovery ladder inherit one live-tunable face. `next` gets a DYNAMIC sparkle FX.
const SLOT_EMPTY_ART := "board/slot_tile.png"    # the open cream well — empty / filled

static func _hsv_setting(c: Dictionary, prefix: String, fallback: Color) -> Color:
	if not c.has(prefix + "_hue") and not c.has(prefix + "_sat") and not c.has(prefix + "_val"):
		return fallback
	return Color.from_hsv(
		float(c.get(prefix + "_hue", roundf(fallback.h * 360.0))) / 360.0,
		float(c.get(prefix + "_sat", roundf(fallback.s * 100.0))) / 100.0,
		float(c.get(prefix + "_val", roundf(fallback.v * 100.0))) / 100.0,
		fallback.a)

## The SLOT-CELL background: one code-drawn face for open, frontier, and deep cells. The knobs live on
## the Slot cell workbench component (`bag_card`) so the board, bag, and discovery ladder share one style.
static func slot_cell_background_opts_from_config(cfg: Dictionary) -> Dictionary:
	var bc: Dictionary = cfg.get("bag_card", {}) if cfg is Dictionary else {}
	return {
		"open_fill": _hsv_setting(bc, "open", Color(Pal.CREAM, 0.92)),
		"frontier_fill": _hsv_setting(bc, "frontier", Pal.NEAR_UNLOCK),
		"deep_fill": _hsv_setting(bc, "deep", Pal.LOCKED),
		"rim": _hsv_setting(bc, "rim", Pal.NEAR_HINT),
		"rim_alpha": clampf(float(bc.get("rim_alpha", 35.0)) / 100.0, 0.0, 1.0),
		"corner_frac": clampf(float(bc.get("corner", 18.0)) / 100.0, 0.04, 0.50),
		"depth_px": clampf(float(bc.get("depth", 4.0)), 0.0, 40.0),
		"depth_alpha": clampf(float(bc.get("depth_alpha", 18.0)) / 100.0, 0.0, 1.0),
		"cell_shadow": clampf(float(bc.get("cell_shadow", 16.0)) / 100.0, 0.0, 1.0),
		"cell_shadow_size": clampf(float(bc.get("cell_shadow_size", 10.0)) / 100.0, 0.0, 0.60),
		"cell_shadow_y": clampf(float(bc.get("cell_shadow_y", 3.0)), -40.0, 40.0),
		"inset": clampf(float(bc.get("inset", 20.0)) / 100.0, 0.0, 1.0),
	}

static func _slot_cell_inset_layer(name: String, size_px: Vector2, corner_px: int, edge_px: int, color: Color, dark_edge: bool) -> Panel:
	var layer := Panel.new()
	layer.name = name
	layer.position = Vector2.ZERO
	layer.size = size_px
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fs := StyleBoxFlat.new()
	fs.bg_color = Color.TRANSPARENT
	fs.draw_center = false
	fs.set_corner_radius_all(corner_px)
	fs.border_color = color
	if dark_edge:
		fs.border_width_top = edge_px
		fs.border_width_left = edge_px
	else:
		fs.border_width_bottom = edge_px
		fs.border_width_right = edge_px
	layer.add_theme_stylebox_override("panel", fs)
	return layer

static func slot_cell_background(size_px: Vector2, state: String, frontier: bool, opts: Dictionary = {}) -> Panel:
	var base := Panel.new()
	base.name = "SlotCellBackground"
	base.position = Vector2.ZERO
	base.size = size_px
	var fs := StyleBoxFlat.new()
	var open_state := state == "empty" or state == "filled"
	fs.bg_color = opts.get("open_fill", Color(Pal.CREAM, 0.92)) if open_state else (opts.get("frontier_fill", Pal.NEAR_UNLOCK) if frontier else opts.get("deep_fill", Pal.LOCKED))
	fs.set_corner_radius_all(int(maxf(10.0, minf(size_px.x, size_px.y) * float(opts.get("corner_frac", 0.18)))))
	var rim: Color = opts.get("rim", Pal.NEAR_HINT)
	var rim_alpha := float(opts.get("rim_alpha", 0.35)) if frontier else float(opts.get("rim_alpha", 0.35)) * 0.25
	var depth_px := int(round(float(opts.get("depth_px", 4.0))))
	var depth_alpha := float(opts.get("depth_alpha", 0.18))
	fs.set_border_width_all(1 if rim_alpha > 0.0 else 0)
	fs.border_width_bottom = maxi(fs.border_width_bottom, depth_px)
	fs.border_color = Color(rim.r, rim.g, rim.b, maxf(rim_alpha, depth_alpha))
	var shadow_a := float(opts.get("cell_shadow", 0.16))
	fs.shadow_color = Color(0.16, 0.10, 0.05, shadow_a)
	fs.shadow_size = int(round(minf(size_px.x, size_px.y) * float(opts.get("cell_shadow_size", 0.10))))
	fs.shadow_offset = Vector2(0, float(opts.get("cell_shadow_y", 3.0)))
	base.add_theme_stylebox_override("panel", fs)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inset := float(opts.get("inset", 0.20))
	if inset > 0.0:
		var corner_px := int(maxf(10.0, minf(size_px.x, size_px.y) * float(opts.get("corner_frac", 0.18))))
		var edge_px := maxi(1, int(round(minf(size_px.x, size_px.y) * lerpf(0.025, 0.070, inset))))
		base.add_child(_slot_cell_inset_layer("SlotCellInsetDark", size_px, corner_px, edge_px, Color(0.12, 0.08, 0.04, 0.34 * inset), true))
		base.add_child(_slot_cell_inset_layer("SlotCellInsetLight", size_px, corner_px, maxi(1, edge_px - 1), Color(1.0, 0.96, 0.78, 0.26 * inset), false))
	return base

## The BAG-CELL opts from config — the slot tile's saved STYLE. Its own component (the bag dialog reuses
## it), read by both the workbench card preview and the bag dialog/overlay. Fractional knobs (the piece /
## lock size as a % of the cell) are stored as integer percents for the sliders and divided here.
const SLOT_LOCKED_PLACEHOLDER_ART := "board/locked_placeholder.png"
const SLOT_LOCKED_PLACEHOLDER_ALPHA := 0.30
const SLOT_LOCKED_PLACEHOLDER_FRAC := 0.72

static func _slot_locked_placeholder(cw: float, ch: float) -> Control:
	var tex := clean_tex_path(Look.kit(SLOT_LOCKED_PLACEHOLDER_ART), 512)
	if tex == null:
		return null
	var px := minf(cw, ch) * SLOT_LOCKED_PLACEHOLDER_FRAC
	var tr := TextureRect.new()
	tr.name = "SlotCellLockedPlaceholder"
	tr.texture = tex
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	var inset_x := (cw - px) * 0.5
	var inset_y := (ch - px) * 0.5
	tr.offset_left = inset_x
	tr.offset_top = inset_y
	tr.offset_right = -inset_x
	tr.offset_bottom = -inset_y
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.modulate = Color(1.0, 1.0, 1.0, SLOT_LOCKED_PLACEHOLDER_ALPHA)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var wrap := Control.new()
	wrap.name = "SlotCellLockedPlaceholderWrap"
	wrap.position = Vector2.ZERO
	wrap.size = Vector2(cw, ch)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(tr)
	return wrap

static func bag_card_opts_from_config(cfg: Dictionary) -> Dictionary:
	var bc: Dictionary = cfg.get("bag_card", {})
	var opts := {
		"cell_w": float(bc.get("cell_w", 116)),
		"cell_h": float(bc.get("cell_h", 120)),
		"content_frac": float(bc.get("content_frac", 62)) / 100.0,   # a held piece, % of the cell
		"cost_font": int(bc.get("cost_font", 24)),                   # the acorn-cost number
		"cost_icon": float(bc.get("cost_icon", 26)),                 # the acorn icon px in a cost row
		"cost_y": float(bc.get("cost_y", 0)),                        # nudge the acorn cost up(-) / down(+), px
		"cost_x": float(bc.get("cost_x", 0)),                        # nudge the acorn cost left(-) / right(+), px
		"cost_scale": float(bc.get("cost_scale", 100)) / 100.0,      # the cost pill's overall size (% — shrinks the WHOLE button to fit the card)
		"level_frac": float(bc.get("level_frac", 44)) / 100.0,       # the level badge size, % of the cell
		"next_glow": float(bc.get("next_glow", 45)) / 100.0,         # the unlockable highlight's glow halo
		"next_twinkle": float(bc.get("next_twinkle", 55)) / 100.0,   # ...and its drifting-star density
		# the unlockable accent COLOUR (halo + shadow), as hue + saturation knobs. Brightness is
		# pinned to STRAW's V (0.89), so the defaults (42°, 74%) reproduce Pal.STRAW exactly — drag the
		# saturation down toward a warm white to take the yellow out of the glow.
		"glow_tint": Color.from_hsv(float(bc.get("glow_hue", 42)) / 360.0, float(bc.get("glow_sat", 74)) / 100.0, 0.89),
		"glow_size": float(bc.get("glow_size", 170)) / 100.0,        # the outer bloom's spread (× the cell; 0 = no halo)
		"glow_shadow": float(bc.get("glow_shadow", 55)) / 100.0,     # the rim drop-shadow's strength (alpha; 0 = no rim glow)
		"glow_shadow_size": float(bc.get("glow_shadow_size", 10)) / 100.0,  # ...and its size (× the cell)
		"btn": card_btn_opts(cfg),                                   # the SHARED button style (art/shadow/corner) — the cost chip rides it
	}
	opts.merge(slot_cell_background_opts_from_config(cfg), true)
	return opts

## One SLOT CELL — the shared bag + board cell, on the board's cream-well art. `d.state` (or the legacy
## `d.kind`) picks the look + behaviour:
##   empty      — the open cream well (seen / unlocked / owned-empty), inert
##   filled     — the open well + a piece on top; a tap fires d.on_tap (retrieve)
##   locked     — the locked well with the flat placeholder stamp (unseen / gated), inert
##   unlockable — the locked well + placeholder, HIGHLIGHTED (glow + dynamic sparkle), full opacity; a
##                tap fires d.on_tap (buy / open). The bag's "next" maps here.
## Optional overlays (a cell shows what is passed): d.cost (int) → the acorn cost near the lower edge
## (bag); d.level (int) → Look.make_level_badge docked lower-right — the SAME HUD
## level badge (board / discovery tier); d.marked (bool) → the engine sparkle over the well, under the
## piece (the discovery ladder's tapped tier); d.dim (0..1) sets the cell's modulate alpha (the board's
## receded deep locks). The piece is content-agnostic so the kit stays free of game deps: d.make_content
## (size) (a Callable that builds the game's piece view at the FITTED size) wins, else d.content (a node),
## else d.icon (a kit icon id), else nothing. Every state returns a tile of exactly cell_w × cell_h.
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
	var cost_x := float(opts.get("cost_x", 0.0))
	var cost_scale := float(opts.get("cost_scale", 1.0))
	var on_tap: Callable = d.get("on_tap", Callable())
	var tappable := on_tap.is_valid() and (state == "filled" or state == "unlockable")
	var lockedwell := (state == "locked" or state == "unlockable")   # both show the placeholder-stamped well

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

	# the cell FACE — one code-drawn Slot-cell background for every state, so the Workbench knobs apply
	# consistently to board, bag, and discovery cells.
	var frontier := bool(d.get("frontier", state == "unlockable"))
	var bg := slot_cell_background(Vector2(cw, ch), state, frontier, opts)
	# dim_bg recedes JUST THE WELL (the Producing dialog's discovered-but-inactive lines): the piece is added
	# later as its own child, so darkening the background here leaves the full-colour item untouched.
	if bool(d.get("dim_bg", false)):
		bg.modulate = Color(0.74, 0.74, 0.74, 1.0)
	tile.add_child(bg)
	if lockedwell:
		var placeholder := _slot_locked_placeholder(cw, ch)
		if placeholder != null:
			tile.add_child(placeholder)

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
			pc.position = Vector2.ZERO
			pc.size = Vector2(cw, ch)
			pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
			pc.add_child(piece)
			tile.add_child(pc)

	# the acorn cost (bag) — near the lower edge. The SHARED green pill_button (the
	# same atom as the shop buy / daily claim), as a STATIC display chip: the CELL itself takes the buy tap,
	# so the price isn't separately pressable. It rides the Button style (art/shadow/corner) via opts.btn,
	# sized by this cell's own cost_font / cost_icon knobs. cost_x / cost_y nudge it; cost_scale shrinks the
	# WHOLE pill (incl. padding) to fit inside a card — scaled about its centre so it stays put.
	var cost := int(d.get("cost", 0))
	if cost > 0 and lockedwell:
		var cwrap := CenterContainer.new()
		cwrap.anchor_left = 0.0; cwrap.anchor_right = 1.0
		cwrap.anchor_top = 1.0; cwrap.anchor_bottom = 1.0
		cwrap.offset_left = cost_x; cwrap.offset_right = cost_x
		cwrap.offset_top = -float(cost_font) - ch * 0.12 + cost_y
		cwrap.offset_bottom = -ch * 0.06 + cost_y
		cwrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# cost_scale shrinks the WHOLE pill — font, icon, padding AND corner — so the CenterContainer lays it
		# out at the smaller size natively. (Control.scale would be wiped: a Container resets a managed child's
		# scale/pivot in fit_child_in_rect, so the shrink never stuck.)
		var cbo := (opts.get("btn", {}) as Dictionary).duplicate()
		cbo["bg"] = "green"; cbo["icon"] = "gem"; cbo["static"] = true
		cbo["font"] = maxi(1, int(round(float(cost_font) * cost_scale)))
		cbo["icon_size"] = maxi(1, int(round(cost_icon * cost_scale)))
		cbo["pad_scale"] = cost_scale
		cbo["corner"] = float(cbo.get("corner", 16.0)) * cost_scale
		cwrap.add_child(pill_button(str(cost), cbo))
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

	# unlockable — the shared HIGHLIGHT: a warm-gold glow (the board's "pop") AND the dynamic
	# sparkle (the bag's next), drawn OVER the well so it reads as the live, actionable cell.
	if state == "unlockable":
		# the accent COLOUR — halo and shadow share one tint (config: glow_hue/glow_sat); the
		# default is Pal.STRAW, so an un-tuned config looks exactly as before.
		var tint: Color = opts.get("glow_tint", Pal.STRAW)
		var pop := Panel.new()
		pop.name = "SlotCellUnlockableHighlight"
		pop.position = Vector2.ZERO
		pop.size = Vector2(cw, ch)
		var ps := StyleBoxFlat.new()
		ps.bg_color = Color(0, 0, 0, 0)
		ps.set_border_width_all(0)
		ps.border_color = tint
		ps.set_corner_radius_all(int(maxf(10.0, cw * 0.18)))
		# the rim drop-shadow — its own strength (alpha) + size knobs, so it can be dialled all the way
		# out. glow_shadow 0 (or glow_shadow_size 0) removes the glow hugging the cell entirely.
		var sh_a := float(opts.get("glow_shadow", 0.55))
		ps.shadow_color = Color(tint, sh_a)
		ps.shadow_size = int(maxf(0.0, cw * float(opts.get("glow_shadow_size", 0.10)))) if sh_a > 0.0 else 0
		pop.add_theme_stylebox_override("panel", ps)
		pop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(pop)
		var glow := float(opts.get("next_glow", 0.45))
		var twinkle := float(opts.get("next_twinkle", 0.55))
		if glow > 0.0 or twinkle > 0.0:
			var spk := _sparkle_overlay(cw, glow, twinkle, bool(opts.get("calm", false)), tint, float(opts.get("glow_size", 1.7)))
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

## The full BAG-dialog opts: the SHARED frame + the bag-cell style + the reused gold currency pill +
## the dialog's own grid (cols, default 6 — the reference's six-wide ladder). Same construction as the
## daily/settings dialogs. Used by the workbench preview AND the game (engine/scripts/ui/bag_overlay.gd).
static func bag_opts_from_config(cfg: Dictionary) -> Dictionary:
	var o := dialog_opts_from_config(cfg)
	o.merge(bag_card_opts_from_config(cfg), true)
	o["pill"] = gold_currency_pill_opts_from_config(cfg)   # the reused gold pill's style (single-acorn at build time)
	var bg: Dictionary = cfg.get("bag", {})
	o["cols"] = int(bg.get("cols", 6))
	o["cell_gap"] = int(bg.get("cell_gap", 12))
	o["grid_inset"] = float(bg.get("grid_inset", 70))  # how much the parchment border/padding eats the grid width
	o["row_gap"] = float(bg.get("row_gap", 14))        # gap between the pill / grid / footer rows
	o["acorn_x"] = float(bg.get("acorn_x", 0))         # nudge the acorn-balance pill left(−) / right(+)
	o["list_max_h"] = float(bg.get("list_max_h", 0))   # the bag's OWN scroll cap (0 = no scroll, 18 slots fit)
	o["caption"] = String(bg.get("caption", "Open a slot with acorns."))
	o["banner_text"] = String(bg.get("banner_text", "Bag"))
	o["banner_icon_on"] = false                        # the reference's "Bag" ribbon is text-only (no envelope)
	return o

## The BAG dialog — the SHARED frame wrapping the bag screen: the reused gold currency pill (the single-acorn
## balance, docked top-right), a grid of bag cells (the slot ladder), and a leaf-flanked footer caption.
## The direct sibling of daily_dialog: same chrome, the bag's content. `entries` is an Array of bag_card
## data dicts (already classified by the caller — the game's slot_plan, or the workbench's DEMO_BAG);
## `balance` is the acorn count. opts["extra"] (optional) is a game-only section (the generators row)
## inserted below the grid. Used by BOTH the workbench preview and the game (ui/bag_overlay.gd).
static func bag_dialog(entries: Array, balance: int, width: float = 560.0, opts: Dictionary = {}) -> Control:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", int(opts.get("row_gap", 14)))
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# the acorn-balance pill, docked top-right — the REUSED gold currency pill in single-currency mode.
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_END
	top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pill_opts: Dictionary = (opts.get("pill", {}) as Dictionary).duplicate()
	pill_opts["icon"] = "gem"
	pill_opts["icon_size"] = float(opts.get("balance_icon", pill_opts.get("icon_size", 38.0)))
	pill_opts["count"] = balance
	pill_opts["show_plus"] = false
	var pill: Control = gold_currency_pill(pill_opts, {"gem": balance})
	# the acorn box keeps its docked-right footprint via a fixed SLOT (so the row layout is unchanged), while
	# the pill itself can be nudged horizontally inside it — acorn_x (+right / −left), the amount_x idiom.
	var acorn_x := float(opts.get("acorn_x", 0.0))
	if acorn_x != 0.0:
		var pill_slot := Control.new()
		pill_slot.custom_minimum_size = pill.custom_minimum_size
		pill_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pill.size = pill.custom_minimum_size
		pill.position = Vector2(acorn_x, 0.0)
		pill_slot.add_child(pill)
		top.add_child(pill_slot)
	else:
		top.add_child(pill)
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
## `d`: { open:bool, done:bool, art:String (locale-art path, "" → meadow fill),
##        owned_zones:int, total_zones:int, prereq:String (the locked "✿ after <prev>" line),
##        map_id:String (the veil-art seam) }.
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
	if bool(d.get("resident_preview", false)) and bool(d.get("open", true)):
		_map_add_resident_preview(card, opts, card_w, card_h)
	if bool(d.get("habitat_preview", false)) and bool(d.get("open", true)):
		_map_add_habitat_shelf_preview(card, opts, card_w, card_h)
	return card

static func map_select_layout(view: Vector2, opts: Dictionary = {}, safe_top: float = 0.0, safe_bottom: float = 0.0) -> Dictionary:
	var top := 96.0 + safe_top
	var sep := 18.0
	var band_top := top + 16.0
	var margin := clampf(float(opts.get("edge_margin_px", 18.0)), 0.0, 96.0)
	var band_bot := view.y - (safe_bottom + margin)
	var col_h := maxf(1.0, band_bot - band_top)
	var left_clip_top := 0.0
	var left_clip_h := maxf(1.0, view.y)
	var col_gap := clampf(view.x * 0.02, 10.0, 24.0)
	var hand_w := clampf(view.x * 0.30, 210.0, 360.0)
	var card_w := maxf(160.0, view.x - margin * 2.0 - col_gap - hand_w)
	var h_frac := float(opts.get("card_h_frac", 0.16))
	var base_card_h := maxf(view.y * h_frac, 150.0)
	var left_x := margin
	var hand_x := left_x + card_w + col_gap
	return {
		"top": top,
		"sep": sep,
		"band_top": band_top,
		"band_bot": band_bot,
		"col_h": col_h,
		"left_clip_top": left_clip_top,
		"left_clip_h": left_clip_h,
		"left_content_top": band_top,
		"margin": margin,
		"col_gap": col_gap,
		"hand_w": hand_w,
		"card_w": card_w,
		"base_card_h": base_card_h,
		"left_x": left_x,
		"hand_x": hand_x,
	}

static func map_habitat_shelf_rect(card_w: float, card_h: float, inset: float, strip_w: float, opts: Dictionary = {}) -> Rect2:
	var rail_gap := 8.0
	var available_w := maxf(1.0, card_w - inset * 2.0 - strip_w - rail_gap)
	var requested_w := available_w * clampf(float(opts.get("reward_shelf_w_frac", 1.0)), 0.20, 1.0)
	var shelf_w := clampf(requested_w, minf(96.0, available_w), available_w)
	var max_h := maxf(1.0, card_h - inset * 2.0)
	var requested_h := card_h * clampf(float(opts.get("reward_shelf_h_frac", 0.14)), 0.08, 0.40)
	var shelf_h := clampf(requested_h, minf(52.0, max_h), minf(max_h, 128.0))
	var max_lift := maxf(0.0, card_h - inset * 2.0 - shelf_h)
	var lift := clampf(card_h * clampf(float(opts.get("reward_shelf_y_frac", 0.0)), 0.0, 0.60), 0.0, max_lift)
	var y_max := maxf(inset, card_h - inset - shelf_h)
	var y := clampf(card_h - inset - shelf_h - lift, inset, y_max)
	return Rect2(Vector2(inset, y), Vector2(shelf_w, shelf_h))

static func map_card_art_path(map_data: Dictionary) -> String:
	var thumb_path := Game.art("map/map_%s.png" % String(map_data.get("id", "")))
	if ResourceLoader.exists(thumb_path):
		return thumb_path
	var vine = map_data.get("vine", null)
	if typeof(vine) == TYPE_DICTIONARY:
		var base := String(vine.get("base", ""))
		if base != "" and ResourceLoader.exists(base):
			return base
	var home = map_data.get("home", null)
	if typeof(home) == TYPE_DICTIONARY:
		var clean := String(home.get("clean", ""))
		if clean != "" and ResourceLoader.exists(clean):
			return clean
	return ""

# The SHARED gold-badge frame, filling the card as a 9-slice (corners native, edges stretch —
# board-consistent). Named so tests + the fill can find it. Open AND locked cards wear the SAME frame, so
# the picker reads as one surface; only the interior (lit art vs dark veil) tells them apart.
static func _map_add_frame(card: Control, badge_opts: Dictionary) -> void:
	_map_add_card_shell(card, badge_opts)
	var cap := gold_badge_cap(badge_opts)
	var frame := NinePatchRect.new()
	frame.name = MAP_FRAME_NODE
	frame.texture = gold_badge_style(badge_opts).texture
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.patch_margin_left = cap
	frame.patch_margin_top = cap
	frame.patch_margin_right = cap
	frame.patch_margin_bottom = cap
	frame.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_STRETCH
	frame.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_STRETCH
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(frame)

static func _map_add_card_shell(card: Control, badge_opts: Dictionary) -> void:
	if card.find_child("MapCardShadow", false, false) != null:
		return
	var cap := float(gold_badge_cap(badge_opts))
	var radius := int(maxf(18.0, cap * 0.58))
	var shadow := Panel.new()
	shadow.name = "MapCardShadow"
	shadow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shadow.offset_left = 4.0
	shadow.offset_top = 5.0
	shadow.offset_right = 2.0
	shadow.offset_bottom = 5.0
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := StyleBoxFlat.new()
	sh.bg_color = Color(0.10, 0.055, 0.025, 0.28)
	sh.set_corner_radius_all(radius)
	shadow.add_theme_stylebox_override("panel", sh)
	card.add_child(shadow)
	var rim := Panel.new()
	rim.name = "MapCardOuterBorder"
	rim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rs := StyleBoxFlat.new()
	rs.bg_color = Color(0, 0, 0, 0)
	rs.border_color = Color(0.13, 0.075, 0.028, 0.58)
	rs.set_border_width_all(4)
	rs.set_corner_radius_all(radius)
	rim.add_theme_stylebox_override("panel", rs)
	card.add_child(rim)

static func _map_add_resident_preview(card: Control, opts: Dictionary, card_w: float, card_h: float) -> void:
	var badge_opts: Dictionary = opts.get("badge", {})
	var band := clampf(float(badge_opts.get("inner_inset", 6.0)) + 3.0, 4.0, minf(card_w, card_h) * 0.45)
	var inset := band + 6.0
	var slot_cols := 2
	var slot_rows := 4
	var orb_px := clampf(float(opts.get("resident_slot_px", 58.0)), 30.0, 148.0)
	var sep := clampf(float(opts.get("resident_slot_gap", 10.0)), 0.0, 36.0)
	var rail_pad := clampf(orb_px * 0.26, 11.0, 36.0)
	var requested_rail_w := orb_px * float(slot_cols) + sep * float(slot_cols - 1) + rail_pad * 2.0
	var requested_rail_h := orb_px * float(slot_rows) + sep * float(slot_rows - 1) + rail_pad * 2.0
	var strip_w := clampf(requested_rail_w, 96.0, minf(card_w * 0.76, 440.0))
	var rect := Rect2(card_w - inset - strip_w, inset, strip_w, maxf(1.0, card_h - inset * 2.0))
	var rail_w := minf(rect.size.x, maxf(96.0, requested_rail_w))
	var rail_h := minf(rect.size.y, requested_rail_h)

	var max_sep_w := maxf(0.0, (rail_w - rail_pad * 2.0 - 10.0 * float(slot_cols)) / float(slot_cols - 1))
	var max_sep_h := maxf(0.0, (rail_h - rail_pad * 2.0 - 10.0 * float(slot_rows)) / float(slot_rows - 1))
	sep = minf(sep, minf(max_sep_w, max_sep_h))
	var max_orb_w := (rail_w - rail_pad * 2.0 - sep * float(slot_cols - 1)) / float(slot_cols)
	var max_orb_h := (rail_h - rail_pad * 2.0 - sep * float(slot_rows - 1)) / float(slot_rows)
	orb_px = floor(clampf(maxf(8.0, minf(orb_px, minf(max_orb_w, max_orb_h))), 8.0, 148.0))
	rail_pad = clampf(orb_px * 0.26, 11.0, 36.0)
	var rail := Control.new()
	rail.name = "MapResidentRailPreview"
	rail.position = rect.position + Vector2(maxf(0.0, rect.size.x - rail_w), maxf(0.0, (rect.size.y - rail_h) * 0.5))
	rail.size = Vector2(rail_w, rail_h)
	rail.custom_minimum_size = rail.size
	rail.clip_contents = true
	rail.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var rail_badge := badge_opts.duplicate()
	rail_badge["corner"] = minf(float(rail_badge.get("corner", 24.0)), 24.0)
	rail_badge["inner_inset"] = clampf(float(rail_badge.get("inner_inset", 7.0)), 4.0, 8.0)
	var frame := board_panel(rail.size, {
		"frame_style": "badge",
		"badge": rail_badge,
		"draw_center": true,
		"shadow": false,
	})
	frame.name = "MapResidentRailPreviewFrame"
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.modulate = Color(1, 1, 1, 0.96)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rail.add_child(frame)

	var margin := MarginContainer.new()
	margin.name = "MapResidentRailPreviewInset"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, int(round(rail_pad)))
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rail.add_child(margin)

	var center := CenterContainer.new()
	center.name = "MapResidentRailPreviewCenter"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(center)

	var grid := GridContainer.new()
	grid.columns = slot_cols
	grid.custom_minimum_size = Vector2(
		orb_px * float(slot_cols) + sep * float(slot_cols - 1),
		orb_px * float(slot_rows) + sep * float(slot_rows - 1)
	)
	grid.add_theme_constant_override("h_separation", int(round(sep)))
	grid.add_theme_constant_override("v_separation", int(round(sep)))
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(grid)
	for i in range(slot_cols * slot_rows):
		var slot := _map_resident_preview_slot(orb_px, opts)
		slot.name = "MapResidentRailPreviewSlot_%02d" % i
		grid.add_child(slot)
	card.add_child(rail)

static func _map_add_habitat_shelf_preview(card: Control, opts: Dictionary, card_w: float, card_h: float) -> void:
	var badge_opts: Dictionary = opts.get("badge", {})
	var band := clampf(float(badge_opts.get("inner_inset", 6.0)) + 3.0, 4.0, minf(card_w, card_h) * 0.45)
	var inset := band + 6.0
	var orb_px := clampf(float(opts.get("resident_slot_px", 58.0)), 30.0, 148.0)
	var sep := clampf(float(opts.get("resident_slot_gap", 10.0)), 0.0, 36.0)
	var rail_pad := clampf(orb_px * 0.26, 11.0, 36.0)
	var strip_w := clampf(orb_px * 2.0 + sep + rail_pad * 2.0, 96.0, minf(card_w * 0.76, 440.0))
	var rect := map_habitat_shelf_rect(card_w, card_h, inset, strip_w, opts)

	var shelf := Panel.new()
	shelf.name = "MapHabitatRewardShelf"
	shelf.position = rect.position
	shelf.size = rect.size
	shelf.custom_minimum_size = rect.size
	shelf.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shelf_style := _map_habitat_shelf_style()
	if shelf_style != null:
		shelf.add_theme_stylebox_override("panel", shelf_style)
	else:
		var ss := StyleBoxFlat.new()
		ss.bg_color = Color(Pal.CREAM, 0.88)
		ss.set_corner_radius_all(14)
		ss.set_border_width_all(2)
		ss.border_color = Color(Pal.INK, 0.12)
		ss.content_margin_left = 14 ; ss.content_margin_right = 14
		ss.content_margin_top = 8 ; ss.content_margin_bottom = 8
		shelf.add_theme_stylebox_override("panel", ss)

	var pad_l := 14.0
	var pad_r := 14.0
	var pad_t := 8.0
	var pad_b := 8.0
	var gap := 8.0
	var icon_size := clampf(float(opts.get("reward_icon_size", clampf(rect.size.y * 0.26, 22.0, 34.0))), 8.0, 72.0)
	var ico := make_icon("coin", icon_size)
	ico.name = "MapHabitatRewardIcon"
	ico.custom_minimum_size = Vector2(icon_size, icon_size)
	ico.size = ico.custom_minimum_size
	ico.position = Vector2(pad_l, pad_t) + Vector2(float(opts.get("reward_icon_x", 0.0)), float(opts.get("reward_icon_y", 0.0)))
	ico.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shelf.add_child(ico)
	var label := Label.new()
	label.name = "MapHabitatRewardLabel"
	label.text = "Coins · 5/5"
	var label_font := int(clampf(float(opts.get("reward_label_font", clampf(rect.size.y * 0.18, 15.0, 22.0))), 8.0, 48.0))
	label.add_theme_font_size_override("font_size", label_font)
	label.add_theme_color_override("font_color", Pal.INK)
	label.add_theme_color_override("font_outline_color", Color(Pal.CREAM, 0.65))
	label.add_theme_constant_override("outline_size", 2)
	label.custom_minimum_size = Vector2(maxf(120.0, rect.size.x * 0.40), float(label_font) + 8.0)
	label.size = label.custom_minimum_size
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = Vector2(pad_l + icon_size + 4.0, pad_t - 1.0) + Vector2(float(opts.get("reward_label_x", 0.0)), float(opts.get("reward_label_y", 0.0)))
	shelf.add_child(label)

	var button_size := Vector2(
		clampf(float(opts.get("reward_button_w", clampf(rect.size.x * 0.26, 104.0, 138.0))), 40.0, 260.0),
		clampf(float(opts.get("reward_button_h", clampf(rect.size.y * 0.31, 34.0, 44.0))), 20.0, 90.0)
	)
	var collect := map_reward_collect_button("Collect", "", button_size,
		int(clampf(float(opts.get("reward_button_font", clampf(rect.size.y * 0.17, 15.0, 20.0))), 8.0, 48.0)),
		0.0,
		true)
	collect.position = Vector2(rect.size.x - pad_r - button_size.x, rect.size.y - pad_b - button_size.y) + Vector2(float(opts.get("reward_button_x", 0.0)), float(opts.get("reward_button_y", 0.0)))
	collect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shelf.add_child(collect)

	var bar_h := clampf(float(opts.get("reward_bar_h", clampf(rect.size.y * 0.14, 10.0, 18.0))), 4.0, 40.0)
	var bar_x := pad_l
	var bar_y := clampf(
		rect.size.y - pad_b - bar_h - 5.0 + float(opts.get("reward_bar_y", 0.0)),
		pad_t,
		maxf(pad_t, rect.size.y - pad_b - bar_h)
	)
	var bar_w := clampf(collect.position.x - gap - bar_x, 44.0, maxf(44.0, rect.size.x - pad_l - pad_r))
	var bar := progress_bar(0.42, {"width": bar_w, "height": bar_h, "art": true})
	bar.name = "MapHabitatProgressBar"
	bar.size = bar.custom_minimum_size
	bar.position = Vector2(bar_x, bar_y)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shelf.add_child(bar)
	card.add_child(shelf)

static func map_reward_collect_button(text: String, icon_id: String, button_size: Vector2, font_px: int, icon_px: float, enabled := true) -> Button:
	var b := pill_button("", {
		"bg": "green",
		"art": false,
		"font": font_px,
		"enabled": enabled,
		"shadow": false,
		"pad_scale": 0.62,
	})
	b.name = "MapHabitatCollectButton"
	b.custom_minimum_size = button_size
	b.size = button_size
	var icon_left := clampf(button_size.x * 0.10, 5.0, 14.0)
	var label_left := 0.0
	if icon_id != "" and icon_px > 0.0:
		var ico := make_icon(icon_id, icon_px)
		ico.name = "MapHabitatCollectButtonIcon"
		ico.custom_minimum_size = Vector2(icon_px, icon_px)
		ico.size = ico.custom_minimum_size
		ico.position = Vector2(icon_left, (button_size.y - icon_px) * 0.5)
		ico.modulate = Color(1, 1, 1, 1.0 if enabled else 0.55)
		ico.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(ico)
		label_left = icon_left + icon_px + 4.0
	var label := Label.new()
	label.name = "MapHabitatCollectButtonLabel"
	label.text = text
	label.add_theme_font_size_override("font_size", font_px)
	label.add_theme_color_override("font_color", Color(Pal.CREAM, 1.0 if enabled else 0.55))
	label.add_theme_color_override("font_outline_color", Color(Pal.BTN_PRIMARY_EDGE, 0.24))
	label.add_theme_constant_override("outline_size", 1)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector2(label_left, 0.0)
	label.size = Vector2(button_size.x if label_left <= 0.0 else maxf(1.0, button_size.x - label_left - 6.0), button_size.y)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(label)
	return b

static func _map_habitat_shelf_style() -> StyleBoxTexture:
	var path := Look.kit(MAP_LEFT_REWARD_SHELF)
	if not ResourceLoader.exists(path):
		return null
	var st := StyleBoxTexture.new()
	st.texture = load(path)
	st.set_texture_margin(SIDE_LEFT, 36)
	st.set_texture_margin(SIDE_TOP, 24)
	st.set_texture_margin(SIDE_RIGHT, 36)
	st.set_texture_margin(SIDE_BOTTOM, 24)
	st.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	st.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	st.content_margin_left = 14
	st.content_margin_top = 8
	st.content_margin_right = 14
	st.content_margin_bottom = 8
	return st

static func _map_resident_preview_slot(px: float, opts: Dictionary = {}) -> Control:
	var slot_opts: Dictionary = opts.get("slot_cell", {})
	if slot_opts.is_empty():
		slot_opts = bag_card_opts_from_config({})
	else:
		slot_opts = slot_opts.duplicate(true)
	slot_opts["cell_w"] = px
	slot_opts["cell_h"] = px
	var slot := slot_cell({"state": "empty"}, slot_opts)
	slot.name = "MapResidentRailPreviewSlot"
	slot.custom_minimum_size = Vector2(px, px)
	slot.size = Vector2(px, px)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return slot

static func _map_leaf(rel: String, node_name: String, size: Vector2, flip_h := false) -> TextureRect:
	var leaf := TextureRect.new()
	leaf.name = node_name
	var path := Look.kit(rel)
	leaf.texture = load(path) if ResourceLoader.exists(path) else null
	leaf.ignore_texture_size = true
	leaf.custom_minimum_size = size
	leaf.size = size
	leaf.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	leaf.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	leaf.flip_h = flip_h
	leaf.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return leaf

static func _map_add_title_plate(card: Control, d: Dictionary, card_w: float, card_h: float) -> void:
	var title := String(d.get("title", "")).strip_edges()
	if title == "":
		return
	var plate := Control.new()
	plate.name = "MapCardTitlePlate"
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ph := clampf(card_h * 0.125, 36.0, 54.0)
	var pw := clampf(maxf(152.0, float(title.length()) * ph * 0.34 + 76.0), 152.0, card_w * 0.46)
	plate.size = Vector2(pw, ph)
	plate.custom_minimum_size = plate.size
	plate.position = Vector2(card_w * 0.035, card_h * 0.035)
	var bg_path := Look.kit(MAP_LEFT_TITLE_PLATE)
	if ResourceLoader.exists(bg_path):
		var bg := TextureRect.new()
		bg.texture = load(bg_path)
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_SCALE
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plate.add_child(bg)
	else:
		var panel := Panel.new()
		panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ps := StyleBoxFlat.new()
		ps.bg_color = Color(Pal.CREAM, 0.92)
		ps.border_color = Color(Pal.BARK, 0.28)
		ps.set_border_width_all(2)
		ps.set_corner_radius_all(10)
		panel.add_theme_stylebox_override("panel", ps)
		plate.add_child(panel)
	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", int(clampf(ph * 0.48, 19.0, 27.0)))
	lbl.add_theme_color_override("font_color", Pal.INK)
	lbl.add_theme_color_override("font_outline_color", Color(Pal.CREAM, 0.7))
	lbl.add_theme_constant_override("outline_size", 2)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.position = Vector2(24.0, 2.0)
	lbl.size = Vector2(maxf(2.0, pw - 48.0), ph - 4.0)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(lbl)
	card.add_child(plate)

# The card's interior fill: `tex` COVER-sampled to FILL the box right up to the frame's gold rim — tucked
# just past the badge groove (inner_inset) so the art meets the rim with NO cream gap, and never stretched
# (COVER keeps the source aspect). Clipped to the frame's inner rounded corner. Returns the fill node so the
# caller can layer a veil / mark over it.
static func _map_add_fill(card: Control, tex: Texture2D, badge_opts: Dictionary, card_w: float, card_h: float) -> Control:
	var cap := float(gold_badge_cap(badge_opts))
	var band := clampf(float(badge_opts.get("inner_inset", 6.0)) + 3.0, 4.0, minf(card_w, card_h) * 0.45)
	var inner := Vector2(maxf(2.0, card_w - band * 2.0), maxf(2.0, card_h - band * 2.0))
	var radius := maxf(2.0, cap - band)
	var fill := ColorRect.new()
	fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fill.offset_left = band
	fill.offset_top = band
	fill.offset_right = -band
	fill.offset_bottom = -band
	fill.material = _map_art_material(tex, inner, radius)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(fill)
	return fill

# An OPEN place: the shared gold frame + the locale art (or a meadow fallback) COVER-filling the box up to
# the rim; the restore count rides a pill on the lower edge, and an ACTIVE place's gold band shimmers.
static func _map_card_open(d: Dictionary, opts: Dictionary, card: Control, card_w: float, card_h: float) -> void:
	var badge_opts: Dictionary = opts.get("badge", {})
	_map_add_frame(card, badge_opts)
	var art_path := String(d.get("art", ""))
	var fill_tex: Texture2D = load(art_path) if art_path != "" and ResourceLoader.exists(art_path) else _map_meadow_texture()
	_map_add_fill(card, fill_tex, badge_opts, card_w, card_h)
	if fill_tex == _map_meadow_texture():
		card.add_child(_map_place_mark(opts))   # the ✿ "place" mark over the bare meadow fill
	_map_add_title_plate(card, d, card_w, card_h)
	if not bool(d.get("habitat_preview", false)):
		_map_count_pill(d, opts, card, card_w, card_h)
	# ACTIVE place (open but not yet restored): ring the gold band with twinkles to draw the eye. A
	# DONE/restored card stays quiet (its pill already says "restored"); the amount is workbench-tuned.
	if not bool(d.get("done", false)):
		var spark := float(opts.get("edge_sparkle", 0.6))
		if spark > 0.0:
			card.add_child(_map_card_edge_sparkle(card_w, card_h, spark, bool(opts.get("calm", false))))

# The locked card's dark "veiled" interior: a top→bottom gradient ColorRect (NO texture, so there's no baked
# border to double up against the gold frame), inset to the rim + clipped to the frame's inner rounded
# corner exactly like the art fill. (The old card_locked.png baked its OWN gold border, which showed through
# as a cream band once the shared frame wrapped it.)
static func _map_add_gradient_fill(card: Control, badge_opts: Dictionary, card_w: float, card_h: float) -> Control:
	var cap := float(gold_badge_cap(badge_opts))
	var band := clampf(float(badge_opts.get("inner_inset", 6.0)) + 3.0, 4.0, minf(card_w, card_h) * 0.45)
	var radius := maxf(2.0, cap - band)
	if _map_lock_fill == null:
		_map_lock_fill = Shader.new()
		_map_lock_fill.code = MAP_LOCK_FILL_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = _map_lock_fill
	mat.set_shader_parameter("top_color", LOCK_FILL_TOP)
	mat.set_shader_parameter("bottom_color", LOCK_FILL_BOTTOM)
	mat.set_shader_parameter("rect_px", Vector2(maxf(2.0, card_w - band * 2.0), maxf(2.0, card_h - band * 2.0)))
	mat.set_shader_parameter("radius_px", radius)
	var fill := ColorRect.new()
	fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fill.offset_left = band
	fill.offset_top = band
	fill.offset_right = -band
	fill.offset_bottom = -band
	fill.material = mat
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(fill)
	return fill

static func _map_add_locked_preview(card: Control, opts: Dictionary, badge_opts: Dictionary, card_w: float, card_h: float) -> Control:
	var preview_rel := MAP_LEFT_LOCKED_PREVIEW_INNER if ResourceLoader.exists(Look.kit(MAP_LEFT_LOCKED_PREVIEW_INNER)) else MAP_LEFT_LOCKED_PREVIEW
	var preview_path := Look.kit(preview_rel)
	if bool(opts.get("use_art", true)) and ResourceLoader.exists(preview_path):
		var preview := _map_add_fill(card, load(preview_path), badge_opts, card_w, card_h)
		preview.name = MAP_LOCKED_PREVIEW_NODE
		preview.set_meta("asset_rel", preview_rel)
		return preview
	var fill := _map_add_gradient_fill(card, badge_opts, card_w, card_h)
	fill.name = MAP_LOCKED_PREVIEW_NODE
	return fill

# A LOCKED place: the SAME shared gold frame as an open card + generated teal map preview art carrying the
# standalone lock medallion (centred), with the "after <prev>" prerequisite line low. Open and locked read
# as one surface — same frame — distinguished by the lit art vs the veiled preview + lock.
static func _map_card_locked(d: Dictionary, opts: Dictionary, card: Control, card_w: float, card_h: float) -> void:
	var badge_opts: Dictionary = opts.get("badge", {})
	_map_add_frame(card, badge_opts)
	_map_add_locked_preview(card, opts, badge_opts, card_w, card_h)
	# the standalone lock medallion, centred (lifted slightly so the prerequisite line clears it).
	var lock_rel := MAP_LEFT_LOCK_FLOWER_SOFT if bool(opts.get("use_art", true)) and ResourceLoader.exists(Look.kit(MAP_LEFT_LOCK_FLOWER_SOFT)) else MAP_CARD_LOCK
	var lock_path := Look.kit(lock_rel)
	if ResourceLoader.exists(lock_path):
		var med := TextureRect.new()
		med.name = MAP_LOCK_NODE
		med.texture = load(lock_path)
		med.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		med.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		med.set_meta("asset_rel", lock_rel)
		var msz := clampf(card_h * 0.44, 56.0, 260.0)
		med.custom_minimum_size = Vector2(msz, msz)
		med.size = Vector2(msz, msz)
		med.position = Vector2((card_w - msz) * 0.5, (card_h - msz) * 0.5 - card_h * 0.07)
		med.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(med)
	# the prerequisite line, low on the panel, wrapped by small leaf ornaments.
	var row := Control.new()
	row.name = "MapLockedPrereqRow"
	var prereq := String(d.get("prereq", ""))
	var prereq_font := int(clampf(card_h * 0.115, 18.0, 27.0))
	var leaf_size := Vector2(
		clampf(float(prereq_font) * 1.05, 22.0, 32.0),
		clampf(float(prereq_font) * 0.74, 15.0, 22.0)
	)
	var row_gap := clampf(card_w * 0.018, 8.0, 12.0)
	var text_est := clampf(float(prereq.length()) * float(prereq_font) * 0.54, card_w * 0.26, card_w * 0.48)
	var row_w := clampf(text_est + leaf_size.x * 2.0 + row_gap * 2.0, card_w * 0.40, card_w * 0.66)
	var row_h := maxf(float(prereq_font) * 1.45, leaf_size.y + 8.0)
	row.position = Vector2((card_w - row_w) * 0.5, card_h - row_h - card_h * 0.145)
	row.size = Vector2(row_w, row_h)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)
	var left_leaf := _map_leaf(MAP_LEFT_LEAF_LEFT, "MapLockedPrereqLeafLeft", leaf_size)
	left_leaf.position = Vector2(0.0, (row_h - leaf_size.y) * 0.5)
	left_leaf.modulate = Color(1, 1, 1, 0.9)
	row.add_child(left_leaf)
	var right_leaf := _map_leaf(MAP_LEFT_LEAF_RIGHT, "MapLockedPrereqLeafRight", leaf_size)
	right_leaf.position = Vector2(row_w - leaf_size.x, (row_h - leaf_size.y) * 0.5)
	right_leaf.modulate = Color(1, 1, 1, 0.9)
	row.add_child(right_leaf)
	var state_l := Label.new()
	state_l.name = "MapLockedPrereqLabel"
	state_l.text = prereq
	state_l.add_theme_font_size_override("font_size", prereq_font)
	state_l.add_theme_color_override("font_color", Color(Pal.CREAM, 0.88))
	state_l.add_theme_color_override("font_outline_color", Pal.INK)
	state_l.add_theme_constant_override("outline_size", 5)
	state_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	state_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	state_l.autowrap_mode = TextServer.AUTOWRAP_WORD
	state_l.position = Vector2(leaf_size.x + row_gap, 0.0)
	state_l.size = Vector2(row_w - (leaf_size.x + row_gap) * 2.0, row_h)
	state_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(state_l)

# The restore count on an open card's lower edge: a cream pill (pill_left) carrying "owned / total"
# restored-zone progress (panel-text law: dark INK, no halo).
static func _map_count_pill(d: Dictionary, opts: Dictionary, card: Control, card_w: float, card_h: float) -> void:
	var done := bool(d.get("done", false))
	var pw := clampf(card_w * float(opts.get("pill_w_frac", 0.30)), float(opts.get("pill_min", 170.0)), float(opts.get("pill_max", 290.0)))
	var ph := pw / MAP_CARD_PILL_ASPECT
	var node := Control.new()
	node.name = "MapCardCountPill"
	node.size = Vector2(pw, ph)
	# sit in the lower body, ABOVE the frame's bottom gold band so the pill never overlaps the border.
	node.position = Vector2((card_w - pw) * 0.5, card_h - ph - card_h * float(opts.get("pill_y_frac", 0.13)))
	if bool(d.get("resident_preview", false)):
		var badge_opts: Dictionary = opts.get("badge", {})
		var band := clampf(float(badge_opts.get("inner_inset", 6.0)) + 3.0, 4.0, minf(card_w, card_h) * 0.45)
		var inset := band + 6.0
		var orb_px := clampf(float(opts.get("resident_slot_px", 58.0)), 30.0, 148.0)
		var sep := clampf(float(opts.get("resident_slot_gap", 10.0)), 0.0, 36.0)
		var rail_pad := clampf(orb_px * 0.26, 11.0, 36.0)
		var strip_w := clampf(orb_px * 2.0 + sep + rail_pad * 2.0, 96.0, minf(card_w * 0.76, 440.0))
		var rail_left := card_w - inset - strip_w
		var min_x := band + 8.0
		var max_x := maxf(min_x, rail_left - pw - 8.0)
		node.position.x = clampf((rail_left - pw) * 0.5, min_x, max_x)
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
	var lbl := Label.new()
	var total := int(d.get("total_zones", -1))
	if total >= 0:
		total = maxi(0, total)
		var owned := clampi(int(d.get("owned_zones", total if done else 0)), 0, total)
		lbl.text = "%d/%d" % [owned, total]
	elif done:
		lbl.text = String(TranslationServer.translate("✿ restored"))   # static ctx: tr() is instance-only
	else:
		# Backward-compatible fallback for standalone callers that have not been moved to zone progress.
		lbl.text = String(TranslationServer.translate("✦ %d exp")) % int(d.get("unlock_exp", 0))
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

# Material for an open card's fill: COVER-samples `tex` over `rect_size` and clips it to a rounded rect
# (radius `corner_px`) so the locale art tucks inside the shared gold frame's inner corner. See
# MAP_ART_FILL_SHADER.
static func _map_art_material(tex: Texture2D, rect_size: Vector2, corner_px: float) -> ShaderMaterial:
	if _map_art_fill == null:
		_map_art_fill = Shader.new()
		_map_art_fill.code = MAP_ART_FILL_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = _map_art_fill
	mat.set_shader_parameter("art", tex)
	mat.set_shader_parameter("tex_px", tex.get_size())
	mat.set_shader_parameter("rect_px", rect_size)
	mat.set_shader_parameter("radius_px", corner_px)
	return mat

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
	var hud: Dictionary = hud_layout_opts_from_config(cfg)
	return {
		"use_art":         bool(c.get("use_art", true)),
		"badge":           gold_badge_opts_from_config(cfg),           # the SHARED gold-badge skin BOTH cards' frame wears (board/info-bar consistent)
		"edge_margin_px":  float(hud.get("edge_margin_px", 18.0)),     # place-picker column edges share the HUD side margin
		"card_h_frac":     float(c.get("card_h_frac", 16)) / 100.0,     # card height as a % of the screen height (a w:h far from the art's ~2.92 aspect stretches the gold frame)
		"edge_sparkle":    float(c.get("edge_sparkle", 60)) / 100.0,    # twinkles ringing an ACTIVE open card's gold band (0 = off); reduced-motion freezes them
		"calm":            bool(c.get("calm", false)),                  # reduced-motion: freeze the edge sparkle (set live by map.gd from FX.calm())
		"pill_w_frac":     float(c.get("pill_w_frac", 30)) / 100.0,     # count-pill width (% of card width)
		"pill_min":        float(c.get("pill_min", 170)),
		"pill_max":        float(c.get("pill_max", 290)),
		"pill_y_frac":     float(c.get("pill_y_frac", 13)) / 100.0,     # pill lift off the bottom (% of card height)
		"resident_slot_px": float(c.get("resident_slot_px", 58)),        # completed-card resident slot size px
		"resident_slot_gap": float(c.get("resident_slot_gap", 10)),      # completed-card gap between resident slots px
		"slot_cell":       bag_card_opts_from_config(cfg),               # completed-card resident cells match the right-column square slots
		"reward_shelf_w_frac": float(c.get("reward_shelf_w_frac", 100)) / 100.0, # completed-card reward shelf width (% of left lane)
		"reward_shelf_h_frac": float(c.get("reward_shelf_h_frac", 14)) / 100.0,  # completed-card reward shelf height (% of card height)
		"reward_shelf_y_frac": float(c.get("reward_shelf_y_frac", 0)) / 100.0,   # completed-card reward shelf lift from bottom (% of card height)
		"reward_icon_size": float(c.get("reward_icon_size", 24)),
		"reward_icon_x":    float(c.get("reward_icon_x", 0)),
		"reward_icon_y":    float(c.get("reward_icon_y", 0)),
		"reward_label_font": int(c.get("reward_label_font", 21)),
		"reward_label_x":   float(c.get("reward_label_x", 0)),
		"reward_label_y":   float(c.get("reward_label_y", 0)),
		"reward_button_w":  float(c.get("reward_button_w", 116)),
		"reward_button_h":  float(c.get("reward_button_h", 36)),
		"reward_button_x":  float(c.get("reward_button_x", 0)),
		"reward_button_y":  float(c.get("reward_button_y", 0)),
		"reward_button_font": int(c.get("reward_button_font", 18)),
		"reward_bar_h":     float(c.get("reward_bar_h", 10)),
		"reward_bar_y":     float(c.get("reward_bar_y", 0)),
		"veil_mark_size":  float(c.get("veil_mark_size", 64)),         # the ✿ place-mark px on an open card's bare meadow fill (no slider; _map_place_mark)
	}

## The QUEST-GIVER card layout fractions from a saved config — the workbench's quest_card block (percent
## ints) → the `lay` dict GiverStand.make reads (cfg.lay). `item_size` drives a SQUARE item (item_w ==
## item_h, undistorted). EVERY default mirrors giver_stand.LAY, so an absent/empty block resolves to the
## SHIPPED layout and the board's giver card is unchanged until a designer saves a tweak.
static func giver_lay_from_config(cfg: Dictionary) -> Dictionary:
	var q: Dictionary = cfg.get("quest_card", {}) if cfg is Dictionary else {}
	var isz: float = float(q.get("item_size", 32)) / 100.0
	return {
		"card_w":      float(q.get("card_w", 98)) / 100.0,      "card_h":   float(q.get("card_h", 65)) / 100.0,
		"bust_size":   float(q.get("bust_size", 94)) / 100.0,   "bust_x":   float(q.get("bust_x", 25)) / 100.0,   "bust_y":   float(q.get("bust_y", 53)) / 100.0,
		"bubble_size": float(q.get("bubble_size", 66)) / 100.0, "bubble_x": float(q.get("bubble_x", 72)) / 100.0, "bubble_y": float(q.get("bubble_y", 35)) / 100.0,
		"item_w":      isz,                                     "item_h":   isz,                                  "item_x":   float(q.get("item_x", 72)) / 100.0, "item_y": float(q.get("item_y", 32)) / 100.0,
		"plaque_w":    float(q.get("plaque_w", 40)) / 100.0,    "plaque_x": float(q.get("plaque_x", 72)) / 100.0, "plaque_y": float(q.get("plaque_y", 81)) / 100.0,
		# the card's 9-slice patch margins, in SOURCE pixels (NOT fractions) — the corners that stay crisp while
		# the centre parchment stretches. Defaults bracket the wood frame + peg-hole corners of the 369×209 art.
		"card_slice_l": float(q.get("card_slice_l", 46)), "card_slice_t": float(q.get("card_slice_t", 44)),
		"card_slice_r": float(q.get("card_slice_r", 46)), "card_slice_b": float(q.get("card_slice_b", 56)),
	}

## The default config-file location the workbench writes (the single source of truth the game reads).
const CONFIG_PATH := "res://games/grove/tools/ui_workbench_settings.json"
