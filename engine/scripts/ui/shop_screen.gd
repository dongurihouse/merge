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
## …AND ONE THING MORE, added 2026-07-30 and the only mark this file makes on the art: when an offer cannot
## be taken right now, its bay wears a WASH and a plate of the game's own cut paper carrying our own words
## (`_unavailable`). It exists because the painting cannot change — the free refill's shelf shows a green
## FREE button in baked pixels whether or not the faucet has already been drained today, and before this
## the claimed shelf just went silently inert under art still advertising it. The storefront PNG is not
## touched; nothing else on the screen is drawn; and the plate is built only for an offer whose card says
## `unavailable`, so a storefront with everything in stock renders exactly as it did.
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
## the same seam belongs to the pack it points at. The hit-region overlay (`make shot-map MODE=shophits`)
## probes the ENGINE's own picker inside every region and reddens any disagreement, so the ordering is a
## checked claim rather than a comment. That overlay is a CAPTURE TOOL and ships with nothing — it is
## composed over the built screen by the capture, off the metas below. The mock → regions → overlay loop,
## end to end, is docs/design/shop-hit-regions.md.
##
## WHAT THE PICTURE CANNOT SELL. The art is fixed, so it presents exactly the eight offers it draws. Any
## live offer with no region — today the 💎 water fill that appears once the free refill is spent, and the
## scissors tool at mastery 2 — is reported on the built screen as `UNPLACED_META` and named in the
## registry's `unplaceable` block; grove_shop_tests.gd fails if that set ever changes. The prices and
## amounts are baked into the art too, which is a real problem outside the US — see the guard in
## grove_shop_tests.gd (`art_claims_match_live_config`) and the note in docs/design/art-style-guide.md.

const Game = preload("res://engine/scripts/core/game.gd")
const Pal = Game.PALETTE
## The cut-paper MATERIAL the unavailable plate is made of — the same sheet the wallet pills and the
## settings tile wear, so the one thing this screen draws is the game's own paper and not a new box.
const CutPaper = preload("res://engine/scripts/ui/cut_paper.gd")
const Paper = preload("res://engine/scripts/ui/paper_button.gd")
const FS = preload("res://engine/scripts/core/tuning.gd").FontScale

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

## THE ONE THING THIS SCREEN DRAWS. A shelf whose offer cannot be taken right now wears a plate of the
## game's own cut paper, over a wash that puts the goods behind it at rest — see `_unavailable` below.
const UNAVAIL_NODE := "ShopOfferUnavailable"
const UNAVAIL_META := "shop_unavailable"

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

## One offer's rect out of the registry, in the PICTURE's own px. `key` is `cell` or `price`. An unknown
## offer or key is an empty Rect2 — the callers below all refuse on a zero-size rect rather than guess one.
static func offer_rect_px(offer_id: String, key: String) -> Rect2:
	for o in registry().get("offers", []):
		if String((o as Dictionary).get("id", "")) == offer_id:
			return _rect(((o as Dictionary).get(key, [])))
	return Rect2()

## THE STALL'S INTERIOR — the band of picture between the two posts, in the picture's own px. Read off the
## registry's MEASURED furniture (`furniture.posts`, re-measured on every `make test-config`), because the
## cells deliberately run out to the posts' OUTER edges (33 and 1046) and a wash drawn to those edges would
## darken a slice of a post for the height of one shelf — a beam half-shaded down its length reads as a
## rendering bug, not as an offer at rest. Empty (no posts recorded) → an unbounded band, so a registry
## without furniture washes the whole cell rather than nothing at all.
static func interior_px() -> Rect2:
	var posts: Array = (registry().get("furniture", {}) as Dictionary).get("posts", [])
	var art := art_size()
	if posts.size() < 2 or art.x <= 0.0:
		return Rect2(Vector2.ZERO, art)
	var left := _rect(posts[0])
	var right := _rect(posts[1])
	return Rect2(left.end.x, 0.0, maxf(right.position.x - left.end.x, 0.0), art.y)

## The WASH's corner radius, as a fraction of its own width — enough that it reads as a pane deliberately
## laid over one bay of the stall rather than as a rectangle someone forgot to shape.
const WASH_CORNER_FRAC := 0.10
## …and how far it holds off the bay's own edges, as a fraction of the cell's width. A pane welded to the
## post and to the neighbouring bay reads as a hole in the picture; one that floats inside the bay reads as
## something laid on top of it, which is what it is. NOT on the bottom, though: the cell's bottom edge is
## the bottom of the painted caption plaque ("FREE REFILL"), and an inset there left that plaque half in
## the wash and half out — one bright strip of a dimmed sign, which reads as a mis-drawn rect. So the wash
## keeps the bay's own floor and holds off only the three edges that meet open picture.
const WASH_INSET_FRAC := 0.018

## The WASH under an unavailable offer's plate, in the picture's own px: the offer's own shelf cell, clipped
## to the stall's interior. Every edge is therefore a boundary the PAINTING already has — the post beside it,
## the measured gutter that splits the bay, the signboard above, the plank below — so nothing has to be
## eyeballed and the same rule holds for any of the eight cells.
static func unavailable_wash_px(offer_id: String) -> Rect2:
	var cell := offer_rect_px(offer_id, "cell")
	if cell.size.x <= 0.0:
		return Rect2()
	var box := cell.intersection(interior_px())
	var m := cell.size.x * WASH_INSET_FRAC
	return Rect2(box.position + Vector2(m, m), box.size - Vector2(m * 2.0, m))

## …and the PLATE that sits on it, in the picture's own px. It is centred on the wash across, and pinned
## across the offer's own PRICE plate down — it must cover the green button, because that button is the
## painting's promise and the whole point of this treatment is that the promise no longer holds. Both
## numbers are fractions of rects the registry measured, so the plate tracks the art at any picture size.
const PLATE_W_FRAC := 0.86          ## of the wash's own width
const PLATE_H_PRICE_MULT := 1.90    ## of the price plate's own height — room for a headline and a sub-line
const PLATE_RISE_PRICE_MULT := 0.45 ## …and how far it rides ABOVE the price plate's centre, in price heights,
                                    ## which is what carries its top edge over the painted amount tag too
static func unavailable_plate_px(offer_id: String) -> Rect2:
	var wash := unavailable_wash_px(offer_id)
	var price := offer_rect_px(offer_id, "price")
	if wash.size.x <= 0.0 or price.size.y <= 0.0:
		return Rect2()
	var s := Vector2(wash.size.x * PLATE_W_FRAC, price.size.y * PLATE_H_PRICE_MULT)
	var c := Vector2(wash.get_center().x, price.get_center().y - price.size.y * PLATE_RISE_PRICE_MULT)
	return Rect2(c - s * 0.5, s)

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

	# …AND LAST, OVER BOTH, the plate for any offer that cannot be taken right now. It goes down after the
	# price rects for the same reason they go after the cells: whatever is meant to take the tap must be on
	# top. See `_unavailable` for what it is and why it swallows.
	for entry in reg.get("offers", []):
		var o := entry as Dictionary
		var id := String(o.get("id", ""))
		if not offers.has(id) or not bool((offers[id] as Dictionary).get("unavailable", false)):
			continue
		_unavailable(root, id, offers[id] as Dictionary, _to_local(o.get("cell", []), art, size),
			_scaled(unavailable_wash_px(id), art, size), _scaled(unavailable_plate_px(id), art, size),
			size.x / maxf(art.x, 1.0))

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

## A registry `[x, y, w, h]` as a Rect2, still in the PICTURE's own px. Malformed → an empty rect.
static func _rect(r: Variant) -> Rect2:
	if not (r is Array) or (r as Array).size() != 4:
		return Rect2()
	var a := r as Array
	return Rect2(float(a[0]), float(a[1]), float(a[2]), float(a[3]))

## A rect from the registry (the picture's own px) into the built screen's local px.
static func _to_local(r: Variant, art: Vector2, size: Vector2) -> Rect2:
	return _scaled(_rect(r), art, size)

## …and the same scaling for a rect already in picture px (the derived unavailable geometry above).
static func _scaled(r: Rect2, art: Vector2, size: Vector2) -> Rect2:
	var k := Vector2(size.x / maxf(art.x, 1.0), size.y / maxf(art.y, 1.0))
	return Rect2(r.position * k, r.size * k)

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
		# Nothing to buy (a free faucet already claimed). This INVISIBLE region must not swallow the tap and
		# pretend — an invisible thing that eats a tap over art that still says FREE is indistinguishable
		# from a broken button. What takes the tap instead is the VISIBLE plate `_unavailable` lays over the
		# same cell, which says in our own words why there is nothing to press.
		b.disabled = true
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(b)

# --- the UNAVAILABLE plate ---------------------------------------------------------------------------

## The wash itself: the scene's own INK, at the alpha that puts the goods behind it at rest without hiding
## them. It is a REST state, not a lock — the offer is coming back.
const WASH_ALPHA := 0.38
## The gap between the plate's headline and its sub-line, as a fraction of the sub-line's own size.
const PLATE_LINE_GAP := 0.22

## THE ONE THING THIS SCREEN DRAWS ON THE PAINTING, and it draws it because the painting cannot change:
## the free refill's shelf shows a green FREE button in baked pixels, whatever the faucet is actually
## doing. Owner, 2026-07-30 — "the free should be unavailable once claimed, let's put up an overlay, with
## our own label on top to make it looks like its claimed" … "just put a overlay or a huge button ontop
## without changing the underlying image". So: a wash over the bay, and a sheet of the game's OWN cut paper
## on top of it carrying OUR text. Not one pixel of the storefront art is touched, and every other shelf is
## untouched too — this is built only for an offer whose card says `unavailable`.
##
## WHAT IT COVERS. The wash is the offer's shelf cell clipped to the stall's interior; the plate is pinned
## over the offer's own PRICE rect (riding a little high, so it takes the painted amount tag with it). Both
## are derived from rects the registry MEASURED off the art — nothing here is eyeballed, and the same rule
## would place this plate on any of the eight bays.
##
## IT SWALLOWS ITS OWN TAP — a deliberate choice, and the opposite of what the invisible region under it
## does. On this screen the painting stops nothing, so a tap that hits no region falls through to the
## modal's dismiss veil and CLOSES THE SHOP; that was the live behaviour of a claimed refill before this
## plate existed, and "I pressed the thing that says Claimed and the shop vanished" is a destructive
## surprise, not feedback. A visible control that eats its own tap is honest here precisely because it is
## visible and because it states, in words, that there is nothing to buy — the objection to swallowing
## (an invisible region pretending) does not apply to it. So: the whole cell is MOUSE_FILTER_STOP, the
## region geometry is unchanged from the buyable state, and only what it does changed. Everything drawn
## inside is MOUSE_FILTER_IGNORE, so the hit-region overlay sees exactly ONE rect here.
static func _unavailable(root: Control, offer_id: String, card: Dictionary, cell: Rect2, wash: Rect2,
		plate: Rect2, k: float) -> void:
	if cell.size.x <= 0.0 or cell.size.y <= 0.0:
		return
	var holder := Control.new()
	holder.name = "%s_%s" % [UNAVAIL_NODE, offer_id]
	holder.mouse_filter = Control.MOUSE_FILTER_STOP     # THE DECISION above: it eats its own tap
	holder.set_meta(UNAVAIL_META, true)
	# the SAME id its cell and price rect carry, so the overlay and the suites can say which offer is held
	# without a second table to keep in step.
	holder.set_meta(OFFER_META, offer_id)
	_place(holder, cell)
	root.add_child(holder)

	if wash.size.x > 0.0 and wash.size.y > 0.0:
		var pane := Panel.new()
		pane.name = "%sWash" % UNAVAIL_NODE
		pane.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(Pal.INK, WASH_ALPHA)
		sb.anti_aliasing = true
		var r := int(round(wash.size.x * WASH_CORNER_FRAC))
		sb.corner_radius_top_left = r
		sb.corner_radius_top_right = r
		sb.corner_radius_bottom_left = r
		sb.corner_radius_bottom_right = r
		pane.add_theme_stylebox_override("panel", sb)
		_place(pane, Rect2(wash.position - cell.position, wash.size))
		holder.add_child(pane)

	if plate.size.x <= 0.0 or plate.size.y <= 0.0:
		return
	var sheet := Control.new()
	sheet.name = "%sPlate" % UNAVAIL_NODE
	sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(sheet, Rect2(plate.position - cell.position, plate.size))
	holder.add_child(sheet)

	# THE MATERIAL is the shared paper FURNITURE treatment — the sheet the wallet pills and the settings
	# tile are cut from: a smooth cut edge, the lit hairline, and the halo thrown by this scene's upper-left
	# light. It is scaled off the plate's own HEIGHT, which is what `furniture_cp` is for (a plaque is long
	# and low, and a cast shadow tracks the short dimension). Nothing new is invented for this screen.
	var Kit: GDScript = Game.kit_script()
	var cp = CutPaper.new()
	cp.name = "%sPaper" % UNAVAIL_NODE
	cp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cp.configure(Paper.furniture_cp(plate.size.y), Pal.CREAM, null,
		Kit.cut_paper_tile() if Kit != null else null)
	_place(cp, Rect2(Vector2.ZERO, plate.size))
	sheet.add_child(cp)

	# THE COPY, both lines from the card (so every word on this screen still comes from one place — the
	# shop's own state read, never from this file): the HEADLINE says what happened to the offer, the
	# sub-line says when it comes back. A card with only one of them centres the one it has.
	var head := String(card.get("unavailable_label", ""))
	var sub := String(card.get("note", ""))
	var head_px := int(round(float(FS.TITLE) * k))
	var sub_px := int(round(float(FS.BODY) * k))
	var head_h := float(head_px) * 1.18
	var sub_h := float(sub_px) * 1.18
	var gap := float(sub_px) * PLATE_LINE_GAP
	var block := (head_h if head != "" else 0.0) + (sub_h if sub != "" else 0.0) \
		+ (gap if head != "" and sub != "" else 0.0)
	var y := (plate.size.y - block) * 0.5
	if head != "":
		sheet.add_child(_plate_line(head, head_px, Pal.INK, Rect2(0.0, y, plate.size.x, head_h)))
		y += head_h + gap
	if sub != "":
		sheet.add_child(_plate_line(sub, sub_px, Pal.BARK, Rect2(0.0, y, plate.size.x, sub_h)))

## One centred line on the plate. `clip_text` + the ellipsis overrun are not decoration: a Label's minimum
## width is its own TEXT until one of them is set, so a long line (any translation of these two strings)
## would otherwise push the label wider than the sheet it is printed on and hang off both ends of it.
static func _plate_line(text: String, px: int, col: Color, rect: Rect2) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", col)
	_place(l, rect)
	return l

## Absolute placement inside a parent that must not re-lay the child out. The preset is applied BETWEEN two
## identical position/size writes for the reason `_button` does the same: the preset re-derives offsets from
## whatever the rect was when it ran.
static func _place(c: Control, rect: Rect2) -> void:
	c.position = rect.position
	c.size = rect.size
	c.custom_minimum_size = rect.size
	c.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_KEEP_SIZE)
	c.position = rect.position
	c.size = rect.size

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
