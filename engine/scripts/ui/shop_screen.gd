extends RefCounted
## THE SHOP SCREEN IS THE PAINTING.
##
## Owner call 2026-07-30, after a pass that rebuilt the design out of code-drawn cut-paper primitives
## and was rejected for it ("you replaced with our own texts and assets, which looks bad, i literally
## meant to use the whole image from the mock"): the approved concept art IS the storefront. The awning,
## the hung signboard, the SHOP title, the shelves, the goods, the cream amount tags, the green price
## buttons, the ACORN POUCHES plaque, the POPULAR ribbon, the BEST VALUE rosette and the coral ✕ are all
## the picture's own pixels. This file draws NONE of them. It does exactly two things:
##
##   * puts the picture on the screen, aspect-fit, as ONE TextureRect;
##   * lays TRANSPARENT hit rects over it, one per offer, wired to the same purchases as before.
##
## THE REGIONS ARE MEASURED, NOT TYPED. Every rect comes from the registry that ships beside the picture
## (games/grove/assets/ui/dialogs/shop/storefront_market_stall.regions.json), in the picture's own pixels,
## and is divided by the picture's own size here. `games/grove/tools/measure_shop_screen.py` is the
## deterministic scan those pixels came from and
## `games/grove/tools/tests/test_shop_screen_regions.py` re-measures them on every `make test-config`.
##
## THE REGIONS TRACK THE ART, NOT THE VIEWPORT. The picture is 1080×1920 and a phone rarely is, so it is
## letterboxed: `fit_size` solves for the largest box of the picture's own aspect that fits the screen,
## the root Control IS that box, and every region is a fraction of the ROOT. So a region cannot drift off
## its goods on a taller screen — there is no second scale factor for it to disagree with.
##
## ORDER IS LOAD-BEARING. The eight cells go down first and tile without overlapping; the eight price
## rects go down after them, on top. That is what lets a price button that hangs below its own shelf
## (the $0.99 and $4.99 plates both do, by 24 px) keep its own taps while the POPULAR ribbon's tip above
## the same seam belongs to the pack it points at. The debug overlay (make shot-map MODE=shophits) probes
## the ENGINE's own picker inside every region and reddens any disagreement, so the ordering is a checked
## claim rather than a comment.
##
## WHAT THE PICTURE CANNOT SELL. The art is fixed, so it presents exactly the eight offers it draws. Any
## live offer with no region — today the 💎 water fill that appears once the free refill is spent, and the
## scissors tool at mastery 2 — is reported on the built screen as `UNPLACED_META` and named in the
## registry's `unplaceable` block; grove_shop_tests.gd fails if that set ever changes. The prices and
## amounts are baked into the art too, which is a real problem outside the US — see the guard in
## grove_shop_tests.gd (`art_claims_match_live_config`) and the note in docs/design/art-style-guide.md.

const Game = preload("res://engine/scripts/core/game.gd")

## The registry beside the picture — the judgement half. Loaded through Game.art so the engine keeps its
## hands off a res://games path (§15, engine/tests/layering_tests.gd).
const REGISTRY_REL := "ui/dialogs/shop/storefront_market_stall.regions.json"

const ROOT_NODE := "ShopScreen"
const ART_NODE := "ShopScreenArt"
const SLOT_NODE := "ShopOfferSlot"       ## one per offer: the whole visible group (goods · tag · button)
const PRICE_NODE := "ShopOfferPrice"     ## …and the green price plate the picture draws, on top of it
const CLOSE_NODE := "DialogClose"        ## the same node name every other sheet's ✕ wears

## The metas a region carries. `shop_slot` marks the big cell (so the overlay and the suites can tell the
## two kinds apart); `shop_offer` names WHICH purchase it resolves to and is set from the SAME card
## dictionary that supplies `on_buy`, so a label and a purchase cannot disagree by construction.
const SLOT_META := "shop_slot"
const OFFER_META := "shop_offer"
## THE ✕ IS A REGION TOO. It sells nothing, so it carries neither purchase meta — and that alone made it
## invisible to the hit overlay, which collected those two metas and nothing else. It carries its own
## identity now, stamped in the SAME branch that connects the dismiss callable, so the overlay names it
## from the live wiring rather than from the registry it would otherwise have to re-read.
const CLOSE_META := "shop_close"
## …and, beside it, the disc the PICTURE draws, in the built screen's own px. The hit rect is deliberately
## bigger than that disc (the painted ✕ is under the platform's fingertip floor), and the GAP between the
## two is the thing worth seeing, so the overlay is handed both instead of measuring one and guessing.
const CLOSE_DRAWN_META := "shop_close_drawn"
## What the ✕ resolves to. Not an offer id — deliberately, so a region that dismisses can never be
## mistaken for one that charges.
const CLOSE_ID := "close"
## Offer ids the live storefront produced that this picture has no region for. Stamped on the root so a
## test can read it off the built screen instead of re-deriving what "unplaced" means.
const UNPLACED_META := "shop_unplaced"

static var _registry: Dictionary = {}

## The parsed region registry, cached. An unreadable or malformed one returns {} and `build` then draws
## the picture with NO regions — visibly inert rather than quietly mis-wired.
static func registry() -> Dictionary:
	if not _registry.is_empty():
		return _registry
	var path := Game.art(REGISTRY_REL)
	if path == "" or not FileAccess.file_exists(path):
		push_error("shop_screen: no region registry at %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		push_error("shop_screen: the region registry at %s is not a JSON object" % path)
		return {}
	_registry = parsed as Dictionary
	return _registry

## The picture's own pixel size, off the registry. NOT `Design.size()` even though the two coincide
## today: this is the ART's size, and if a future storefront is painted at another resolution the
## regions must scale by the picture's, not by the canvas the UI is laid out against. A registry with
## no `size` refuses (Vector2.ZERO) rather than guessing one — every fraction derives from it.
static func art_size() -> Vector2:
	var s: Array = registry().get("size", [])
	if s.size() != 2:
		push_error("shop_screen: the region registry declares no picture size")
		return Vector2.ZERO
	return Vector2(float(s[0]), float(s[1]))

## res:// path of the storefront picture, off the registry.
static func art_path() -> String:
	return Game.art(String(registry().get("art", "")))

## The offer ids the picture draws, in reading order.
static func offer_ids() -> Array:
	var out: Array = []
	for o in registry().get("offers", []):
		out.append(String((o as Dictionary).get("id", "")))
	return out

## What the ART CLAIMS for an offer — the amount and price printed into the picture. The guard in
## grove_shop_tests.gd asserts the live config still grants exactly this.
static func art_claims(offer_id: String) -> Dictionary:
	for o in registry().get("offers", []):
		if String((o as Dictionary).get("id", "")) == offer_id:
			return (o as Dictionary).get("art_claims", {})
	return {}

## The largest box of the PICTURE's aspect that fits inside `box`. This is the whole letterbox rule: the
## picture is never cropped and never stretched, and what is left over is the frosted backdrop behind it.
static func fit_size(box: Vector2) -> Vector2:
	var art := art_size()
	if art.x <= 0.0 or art.y <= 0.0 or box.x <= 0.0 or box.y <= 0.0:
		return art
	var k: float = minf(box.x / art.x, box.y / art.y)
	return art * k

# --- the build ---------------------------------------------------------------------------------------

## Build the storefront to fit `box`. `offers` maps offer id → the card dictionary the shop already built
## (the only key read here is `on_buy`); `opts` carries `on_close`.
##
## Returns the root Control, sized to the fitted picture. Its `UNPLACED_META` lists any offer id in
## `offers` the picture has no region for.
static func build(box: Vector2, offers: Dictionary, opts: Dictionary = {}) -> Control:
	var size := fit_size(box)
	var root := Control.new()
	root.name = ROOT_NODE
	root.custom_minimum_size = size
	root.size = size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_art(root, size)

	var reg := registry()
	var art := art_size()
	var placed: Array = []
	# THE CELLS FIRST — they tile, so the order among them does not matter; what matters is that every
	# one of them is under every price rect.
	for entry in reg.get("offers", []):
		var o := entry as Dictionary
		var id := String(o.get("id", ""))
		if not offers.has(id):
			continue
		placed.append(id)
		_region(root, "%s_%s" % [SLOT_NODE, id], _to_local(o.get("cell", []), art, size), id,
			(offers[id] as Dictionary).get("on_buy", Callable()), true)
	# …THEN THE PRICE PLATES, on top. See the header: this ordering is what keeps a button that hangs
	# past its own shelf resolving to its own purchase.
	for entry in reg.get("offers", []):
		var o := entry as Dictionary
		var id := String(o.get("id", ""))
		if not offers.has(id):
			continue
		_region(root, "%s_%s" % [PRICE_NODE, id], _to_local(o.get("price", []), art, size), id,
			(offers[id] as Dictionary).get("on_buy", Callable()), false)

	var unplaced: Array = []
	for id in offers.keys():
		if not placed.has(String(id)):
			unplaced.append(String(id))
	unplaced.sort()
	root.set_meta(UNPLACED_META, unplaced)

	var on_close: Callable = opts.get("on_close", Callable())
	if on_close.is_valid():
		var close: Dictionary = reg.get("close", {})
		var b := _button(CLOSE_NODE, _to_local(close.get("rect", []), art, size))
		# the identity and the callable are set in ONE branch: a ✕ that dismisses is a ✕ the overlay can
		# name, and a ✕ that does nothing is never built at all.
		b.set_meta(CLOSE_META, true)
		b.set_meta(CLOSE_DRAWN_META, _to_local(close.get("drawn", []), art, size))
		b.pressed.connect(func() -> void: on_close.call())
		root.add_child(b)
	return root

## The picture itself: one TextureRect filling the root exactly (the root IS the picture's box, so there
## is no letterbox INSIDE it and nothing to align).
static func _art(root: Control, size: Vector2) -> void:
	var tr := TextureRect.new()
	tr.name = ART_NODE
	# expand_mode BEFORE size/texture: a TextureRect clamps its minimum size up to the texture's native
	# px until it is told not to, which would have made the root 1080×1920 whatever we asked for.
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var path := art_path()
	if path != "" and ResourceLoader.exists(path):
		tr.texture = load(path)
	else:
		push_error("shop_screen: no storefront art at %s" % path)
	tr.position = Vector2.ZERO
	tr.size = size
	tr.custom_minimum_size = size
	root.add_child(tr)
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

## A rect from the registry (the picture's own px) into the built screen's local px.
static func _to_local(r: Variant, art: Vector2, size: Vector2) -> Rect2:
	if not (r is Array) or (r as Array).size() != 4:
		return Rect2()
	var a := r as Array
	var k := Vector2(size.x / maxf(art.x, 1.0), size.y / maxf(art.y, 1.0))
	return Rect2(float(a[0]) * k.x, float(a[1]) * k.y, float(a[2]) * k.x, float(a[3]) * k.y)

## ONE transparent hit region over the painting, carrying the offer it resolves to.
static func _region(root: Control, node_name: String, rect: Rect2, offer_id: String,
		on_buy: Callable, is_slot: bool) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var b := _button(node_name, rect)
	if is_slot:
		b.set_meta(SLOT_META, true)
	else:
		b.set_meta("shop_buy", true)     # the meta the UI-shape smoke counts, kept from the card era
	b.set_meta(OFFER_META, offer_id)
	if on_buy.is_valid():
		b.pressed.connect(func() -> void: on_buy.call())
	else:
		# nothing to buy (a free faucet on cooldown) — the region must not swallow the tap and pretend.
		b.disabled = true
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(b)

## An invisible Button at an absolute rect. Invisible is the point: the picture already draws the control.
static func _button(node_name: String, rect: Rect2) -> Button:
	var b := Button.new()
	b.name = node_name
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.position = rect.position
	b.size = rect.size
	b.custom_minimum_size = rect.size
	# absolute placement: a parent preset must not re-lay it out
	b.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_KEEP_SIZE)
	b.position = rect.position
	b.size = rect.size
	return b
