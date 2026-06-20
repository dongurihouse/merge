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
const CUR_PILL_BG := Color("#FBF6EC", 0.95)
const CUR_PILL_BORDER := Color("#C9A66B", 0.9)
const CUR_PILL_SHADOW := Color(0, 0, 0, 0.22)
# id → the rendered sprite px (Tune.Hud gsize × optical: star 44×0.86, coin/gem 40×1.0). The sprite is
# centered in the `icon_box`-sized square, exactly as hud.gd's _icon_box does, so the preview matches.
const CUR_PILL_ICONS := [["star", 38.0], ["coin", 40.0], ["gem", 40.0]]

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

# Demo discovery ladder (12 tiers) for the workbench preview — same shape the game builds from a line's
# Quests.ladder_entries: {tier, seen, marked, icon|node}. A SEEN tier shows its content (here a stand-in
# icon; the game passes a real merge-piece node), an UNSEEN tier the baked "?" cell, one tier is marked
# (the tapped/asked tier, gold-ring cell). Discovered up to tier 6, the rest still "?", mirroring tiers.png.
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
static func shell_texture(rel: String, polish: Dictionary = {}) -> Texture2D:
	var path := Look.kit(rel)
	if rel == "" or not ResourceLoader.exists(path):
		return null
	var defr := bool(polish.get("defringe", false))
	var feat := float(polish.get("feather", 0.0))
	var shad := bool(polish.get("shadow", false))
	if not defr and feat <= 0.0 and not shad:
		return load(path)                       # untouched → the raw shell (already cleaned at intake)
	var img := (load(path) as Texture2D).get_image()
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	var o := polish.duplicate()
	o["defringe"] = defr; o["feather"] = feat; o["shadow"] = shad; o["supersample"] = 1
	return ImageTexture.create_from_image(_polish_icon_aspect(img, o))

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
		var halo := TextureRect.new()
		halo.texture = _glow_texture()
		halo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		halo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		halo.custom_minimum_size = Vector2(hsz, hsz)
		halo.size = Vector2(hsz, hsz)
		halo.position = Vector2((px - hsz) / 2.0, (px - hsz) / 2.0)
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD       # additive → it BLOOMS, doesn't flatten the disc
		halo.material = mat
		halo.modulate = Color(1, 1, 1, clampf(glow, 0.0, 1.0))
		root.add_child(halo)
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
		mat.scale_min = px * 0.0016
		mat.scale_max = px * 0.0036
		var ramp := Gradient.new()                          # twinkle in → out: a 0→1→0 alpha ramp over life
		ramp.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
		ramp.colors = PackedColorArray([Color(1, 0.95, 0.7, 0.0), Color(1, 0.93, 0.62, 1.0), Color(1, 0.95, 0.7, 0.0)])
		var gt := GradientTexture1D.new()
		gt.gradient = ramp
		mat.color_ramp = gt
		p.process_material = mat
		root.add_child(p)
		p.emitting = true
	return root

## A code-generated 4-point sparkle star (white, soft falloff) — the twinkle sprite. Cached.
static var _star_tex: Texture2D = null
static func _star_texture() -> Texture2D:
	if _star_tex != null:
		return _star_tex
	var n := 48
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := n / 2.0
	for y in n:
		for x in n:
			var dx: float = (x - c + 0.5) / c
			var dy: float = (y - c + 0.5) / c
			var hx: float = clampf(1.0 - absf(dx), 0.0, 1.0) * clampf(1.0 - absf(dy) * 7.0, 0.0, 1.0)
			var vy: float = clampf(1.0 - absf(dy), 0.0, 1.0) * clampf(1.0 - absf(dx) * 7.0, 0.0, 1.0)
			var core: float = clampf(1.0 - sqrt(dx * dx + dy * dy) * 2.2, 0.0, 1.0)
			var a: float = clampf(maxf(maxf(hx, vy), core * core), 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
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
	# the frame's CHROME ART — defaults are the parchment border + mail ribbon + mail ✕ (mail/daily/shop
	# pass nothing). A different dialog (e.g. tiers/discovery) overrides these to swap in its own border,
	# banner ribbon and close disc, while reusing all the SAME frame mechanics (banner overlay, scroll, ✕).
	var panel_art: String = String(opts.get("panel_art", "kit/panel_parchment_v2.png"))
	var panel_pad_x: float = float(opts.get("panel_pad_x", 26.0))   # content inset from the border (L/R)
	var panel_pad_y: float = float(opts.get("panel_pad_y", 24.0))   # content inset from the border (T/B)
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
## One TIER CELL — the discovery board's tile. State picks the baked cell art: marked → the gold-ring
## cell, seen → the filled cell, unseen → the "?" cell (which bakes its own glyph). A seen tier shows its
## content (a pre-built `node` Control from the game's piece view, or a stand-in `icon` for the preview);
## the tier number sits top-left. Square by default, code-drawn fallback when the cell art is absent.
## d keys: tier, seen, marked, icon|node. opts: cell_w/h, cell_slice, cell_art, num_font, num_x, num_y,
## piece_frac, sel_overflow.
static func tiers_card(d: Dictionary, opts: Dictionary = {}) -> Control:
	var cw: float = float(opts.get("cell_w", 150.0))
	var ch: float = float(opts.get("cell_h", 150.0))
	var seen := bool(d.get("seen", false))
	var marked := bool(d.get("marked", false))
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(cw, ch)
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.clip_contents = false

	# the tile face: marked → gold-ring cell · discovered → filled cell · unseen → the baked "?" cell.
	var art := "kit/tiers_cell_sel.png" if marked else ("kit/tiers_cell_filled.png" if seen else "kit/tiers_cell_q.png")
	var use_art: bool = bool(opts.get("cell_art", true)) and ResourceLoader.exists(Look.kit(art))
	if use_art:
		var face := TextureRect.new()
		face.texture = clean_tex_path(Look.kit(art), 256)
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var over: float = float(opts.get("sel_overflow", 1.0)) if marked else 1.0   # let the gold ring spill if asked
		var pad := cw * (over - 1.0) / 2.0
		face.position = Vector2(-pad, -pad)
		face.size = Vector2(cw * over, ch * over)
		holder.add_child(face)
	else:                                              # code-drawn fallback (same metrics)
		var p := Panel.new()
		p.set_anchors_preset(Control.PRESET_FULL_RECT)
		var ss := StyleBoxFlat.new()
		ss.bg_color = Color(Pal.GROUND, 0.18) if seen else Color(Pal.GROUND_EDGE, 0.16)
		ss.set_corner_radius_all(22)
		ss.set_border_width_all(5 if marked else 2)
		ss.border_color = Pal.STRAW if marked else Color(Pal.GROUND_EDGE, 0.35)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_theme_stylebox_override("panel", ss)
		holder.add_child(p)

	# the content: a discovered piece, centred. A SEEN tile shows (in priority) a kit-built node from the
	# game's `make_content` callable (sized to the kit-computed cell, so the game stays out of layout), or a
	# pre-built `node` Control, or a stand-in `icon` (the workbench preview). An unseen "?" cell bakes its
	# own glyph, so only a marked-yet-unseen tile (the gold ring on an undiscovered tier) draws a "?".
	var frac: float = float(opts.get("piece_frac", 0.62))
	var mk: Callable = opts.get("make_content", Callable())
	var content: Control = null
	if seen and mk.is_valid():
		content = mk.call(d, cw * frac)
	elif seen and d.get("node") is Control:
		content = d.get("node")
	elif seen and String(d.get("icon", "")) != "":
		content = make_icon(String(d.icon), cw * frac)
	elif marked and not seen:
		var q := Label.new()
		q.text = "?"
		q.add_theme_font_size_override("font_size", int(cw * 0.42))
		q.add_theme_color_override("font_color", Color(Pal.BARK, 0.7))
		q.add_theme_constant_override("outline_size", 0)
		content = q
	if content != null:
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cwrap := CenterContainer.new()
		cwrap.set_anchors_preset(Control.PRESET_FULL_RECT)
		cwrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cwrap.add_child(content)
		holder.add_child(cwrap)

	# the tier number, top-left (a dark numeral with a thin cream halo so it reads on the warm tile).
	if bool(opts.get("show_num", true)):
		var num := Label.new()
		num.text = str(int(d.get("tier", 0)))
		num.position = Vector2(cw * float(opts.get("num_x", 0.11)), ch * float(opts.get("num_y", 0.05)))
		num.add_theme_font_size_override("font_size", int(opts.get("num_font", 26)))
		num.add_theme_color_override("font_color", Color(Pal.BARK, 0.92))
		num.add_theme_color_override("font_outline_color", Color(Pal.CREAM, 0.9))
		num.add_theme_constant_override("outline_size", 5)
		num.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(num)
	return holder

## A GRID of tier cells — plain reading order (tier 1 top-left, filling `cols` per row), exactly like the
## daily grid but with square tiles and NO woven vines (just the cards). The cell size scales to fit `cols`
## across the frame's content area; a partial last row centres.
static func _tiers_grid(entries: Array, width: float, opts: Dictionary) -> Control:
	var cols: int = maxi(1, int(opts.get("cols", 3)))
	var gap: int = int(opts.get("cell_gap", 16))
	var inset: float = float(opts.get("grid_inset", 56.0))     # the bark border eats into the content width
	var cw: float = maxf(48.0, (width - inset - (cols - 1) * gap) / float(cols))
	var aspect: float = float(opts.get("cell_h", 150.0)) / maxf(1.0, float(opts.get("cell_w", 150.0)))
	var co := opts.duplicate()
	co["cell_w"] = cw
	co["cell_h"] = cw * aspect
	co["num_font"] = clampi(int(cw * 0.18), 12, 40)
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

## The DISCOVERY dialog — the shared frame dressed in the TIERS chrome (twig border, gold ladder ribbon,
## its own ✕ disc) wrapping a plain grid of tier cells. Same frame mechanics as mail/daily/shop; only the
## border art + the card differ, and there are NO vines (just the cards).
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
## preview and the discovery dialog. Fractional knobs (number position, content size, marked overflow) are
## stored as PERCENTS for the integer sliders and divided here, mirroring ribbon_scale.
static func tiers_card_opts_from_config(cfg: Dictionary) -> Dictionary:
	var tc: Dictionary = cfg.get("tiers_card", {})
	return {
		"cell_w": float(tc.get("cell_w", 150)),
		"cell_h": float(tc.get("cell_h", 150)),
		"cell_slice": float(tc.get("cell_slice", 40)),
		"cell_art": bool(tc.get("cell_art", true)),
		"show_num": bool(tc.get("show_num", true)),
		"num_font": int(tc.get("num_font", 26)),
		"num_x": float(tc.get("num_x", 11)) / 100.0,         # number inset from the tile's left (% of cell)
		"num_y": float(tc.get("num_y", 5)) / 100.0,          # ...and from its top
		"piece_frac": float(tc.get("piece_frac", 62)) / 100.0,   # the content's size as a fraction of the cell
		"sel_overflow": float(tc.get("sel_overflow", 100)) / 100.0,  # how far the marked cell's ring spills (100 = none)
	}

## The full DISCOVERY-dialog opts: the shared frame dressed in the TIERS chrome (twig border + ladder
## ribbon + its own ✕) built straight from the "tiers" config (NOT the parchment "frame" section — the bark
## panel wants its own banner/padding), plus the tier card + the grid (cols, default 3). No vine knobs.
static func tiers_opts_from_config(cfg: Dictionary) -> Dictionary:
	var t: Dictionary = cfg.get("tiers", {})
	var o := {
		# the TIERS chrome art — the only place the shared frame is dressed differently
		"panel_art": "kit/tiers_panel.png",
		"banner_art": "kit/tiers_banner.png",
		"close_art": "kit/tiers_close.png",
		"card_art": true,
		"card_slice_l": float(t.get("card_slice", 72)), "card_slice_t": float(t.get("card_slice", 72)),
		"card_slice_r": float(t.get("card_slice", 72)), "card_slice_b": float(t.get("card_slice", 72)),
		"card_h_stretch": 0, "card_v_stretch": 0,
		"panel_pad_x": float(t.get("panel_pad_x", 44)),
		"panel_pad_y": float(t.get("panel_pad_y", 30)),
		# the gold ladder ribbon straddling the top edge (no separate banner icon — the reference is text-only).
		# banner_h ≈ panel width × ribbon-aspect makes the aspect-locked ribbon span the panel with overhanging
		# tails (like tiers.png), and banner_y lifts ~40% of it above the top edge.
		"banner_font": int(t.get("banner_font", 50)),
		"banner_h": float(t.get("banner_h", 168)),
		"banner_icon_on": false,
		"banner_text_x": float(t.get("banner_text_x", 0)),
		"banner_text_y": float(t.get("banner_text_y", -2)),
		"banner_burn": float(t.get("banner_burn", 55)) / 100.0,
		"banner_pos": Vector2(float(t.get("banner_x", 0)), float(t.get("banner_y", -66))),
		# the ✕ disc docked past the top-right corner
		"close_size": float(t.get("close_size", 84)),
		"close_poke": Vector2(float(t.get("close_x", 4)), float(t.get("close_y", 16))),
		# the grid (no vines): cols + the content cap / inset
		"cols": int(t.get("cols", 3)),
		"cell_gap": int(t.get("cell_gap", 16)),
		"grid_inset": float(t.get("grid_inset", 56)),
		"list_top_pad": float(t.get("list_top_pad", 8)),
		"list_max_h": float(t.get("list_max_h", 0)),
	}
	o.merge(tiers_card_opts_from_config(cfg), true)   # the tier-cell look (cell size/art, number, content)
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

## The badge (disc-shell) edge polish from config — the standalone Badge item's defringe / feather /
## shadow. The home button's shell reads this, so a Badge tweak flows to the rail + nav automatically.
static func badge_polish_from_config(cfg: Dictionary) -> Dictionary:
	var b: Dictionary = cfg.get("badge", {})
	return {
		"defringe": bool(b.get("defringe", false)),
		"feather": float(b.get("feather", 0)),
		"shadow": bool(b.get("shadow", false)),
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
		var p := Look.kit(CUR_PILL_ART)
		if ResourceLoader.exists(p):
			var sbt := StyleBoxTexture.new()
			sbt.texture = load(p)
			sbt.set_texture_margin_all(CUR_PILL_CAP)   # cap radius: the rounded ends never squash
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
	for i in CUR_PILL_ICONS.size():
		if i > 0:
			# the WIDER gap between pairs is an explicit spacer (matches hud.gd's _spacer)
			var s := Control.new()
			s.custom_minimum_size = Vector2(float(pair_sep - row_sep), 0)
			s.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(s)
		var id := String(CUR_PILL_ICONS[i][0])
		var icon_px := float(CUR_PILL_ICONS[i][1])
		var cc := CenterContainer.new()
		cc.custom_minimum_size = Vector2(box, box)
		cc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cc.add_child(make_icon(id, icon_px))
		row.add_child(cc)
		var lbl := Label.new()
		lbl.text = str(int(counts.get(id, demo[id])))
		lbl.add_theme_font_size_override("font_size", num)
		lbl.add_theme_color_override("font_color", Pal.INK)
		lbl.add_theme_constant_override("outline_size", 0)   # panel-text law: no halo on a solid pill
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(lbl)
	return panel

## The default config-file location the workbench writes (the single source of truth the game reads).
const CONFIG_PATH := "res://games/grove/tools/ui_workbench_settings.json"
