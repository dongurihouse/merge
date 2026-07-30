extends RefCounted
## THE MARKET STALL — the storefront's furniture, drawn in code from the shared cut-paper panel
## (engine/scripts/ui/cut_paper.gd). Owner call 2026-07-30: concept A of
## `_concepts/dialogs/shop_screen_variations_v1/shop_screen_a_market_stall.png` — "use the market stall
## as it is". There are NO offer cards in this design: a scalloped awning spans the top, the title is cut
## into a slate signboard hung on two cords, and the goods STAND on four slate plank shelves against a
## pale-meadow paper wall, each with its amount on a cream tag propped at its base and its price on a
## green button pinned to the shelf lip.
##
## THIS FILE IS A PURE VIEW BUILDER. It knows nothing about money: every offer arrives as the SAME card
## dictionary the storefront has always passed (icon · count · label · price · price_icon · note ·
## affordable · cash · on_buy), and the only thing it does with `on_buy` is hand it to the shelf cell and
## to `Shop._price_pill`. The buy LOGIC, the IAP wiring and the confirm all stay in shop.gd — a re-layout
## must not be able to re-wire a tier.
##
## THE HIT REGION IS THE SHELF CELL. See `SLOT_NODE` below.
##
## Every metric is a fraction of the stall's own WIDTH, measured off the mock at its native 1080 px
## (`tools/` never guesses: the shelf bands were read off the PNG by scanning for the slate rows beside
## the left post, not eyeballed). So the whole stall scales as one piece at any width.

const Game = preload("res://engine/scripts/core/game.gd")
const Pal = Game.PALETTE
const Look = preload("res://engine/scripts/ui/skin.gd")
const SpritePanel = preload("res://engine/scripts/ui/sprite_panel.gd")
const FS = preload("res://engine/scripts/core/tuning.gd").FontScale
const Design = preload("res://engine/scripts/core/design.gd")   # THE design-viewport owner — never re-type 1080x1920

# --- the mock's own colours (sampled from the approved PNG, as SAGE was from the v3 mock) ------------
const WALL := Color("#DFD5A6")          ## the stall's back panel: quiet cream-to-pale-meadow paper
const AWNING_CORAL := Color("#DE7754")  ## alternating awning bay A
const AWNING_CREAM := Color("#F1D9AE")  ## alternating awning bay B
const SLATE_DARK := Color("#33586A")    ## the posts, the shelf front lip, the signboard — the shadow plane
const SLATE_LIT := Color("#6C8996")     ## the shelf's lit TOP face — the same hue, one plane up
const TAG_CREAM := Color("#EDD7B3")     ## the amount tag / the caption plaques
const CORD := Color("#8A6A47")          ## the two fine cords the signboard hangs from

# --- geometry, as fractions of the stall WIDTH (measured off the 1080px mock) ------------------------
const AWNING_H := 0.139        # 150/1080 — the scalloped awning band
const AWNING_BAYS := 9         # alternating coral/cream panels across the width
const SIGN_TOP := 0.157        # 170/1080
const SIGN_H := 0.162          # 175/1080
const SIGN_W := 0.510          # 550/1080
const SIGN_TILT_DEG := -1.3    # "tilted a degree or two so it reads as physically hung"
const HEAD_H := 0.319          # 345/1080 — awning + hanging sign; the first shelf's goods start here
const POST_X := 0.030          # 32/1080 — the stall posts' outer edge
const POST_W := 0.058          # 63/1080
const SHELF_BLEED := 0.004     # the plank runs a hair past the posts, so no seam shows
const CLOSE_D := 0.085         # 92/1080 — the coral ✕ disc
const CLOSE_CX := 0.889        # 960/1080
const CLOSE_CY := 0.206        # 222/1080
const FOOT_H := 0.020          # quiet margin under the bottom shelf

# a COUNTER bay (the soft-currency shelf: taller goods, and a caption plaque on its lip)
const COUNTER_GOODS := 0.303   # 327/1080
const COUNTER_FACE := 0.094    # 101/1080 — the plank's lit top face
const COUNTER_LIP := 0.053     # 57/1080  — its front lip (the same hue, one plane down)
# …and a LADDER bay (an acorn shelf)
const LADDER_GOODS := 0.200    # 216/1080
const LADDER_FACE := 0.062     # 67/1080
const LADDER_LIP := 0.047      # 51/1080
const HEADER_H := 0.095        # the wide section plaque riding the wall above a shelf, plus the mock's own air around it

# in-bay placement (also fractions of the stall width)
const TAG_H := 0.058           # the amount tag's height
const TAG_PAD_X := 0.030       # its horizontal padding around the numerals
const PRICE_GAP := 0.010       # tag bottom → price button top
const PLAQUE_H := 0.047        # a caption plaque's height
const PLAQUE_PAD_X := 0.028

## THE HIT REGION, named so the debug overlay and the suites read the region the game really hit-tests
## rather than re-deriving where it ought to be. ONE rectangle per offer: the offer's half of its shelf
## bay, from the top of the goods zone down to the bottom of the shelf's front lip. Everything drawn for
## that offer — the container, its contact shadow, the cream amount tag, the green price button, the
## caption plaque — is a child of this rect and is laid out INSIDE it, and every child except the price
## button ignores the mouse. Two consequences, and they are the whole reason for the shape:
##   * the cells TILE the bay edge to edge and never overlap, so a container that overhangs its shelf lip
##     cannot steal the tap that belongs to the shelf below, and a transparent sprite bounding box cannot
##     swallow its neighbour;
##   * the tap target is the whole visible group, not just the button — a player who taps the pouch buys
##     the pouch. On a 1080-wide phone a cell is ~400x330 px, far past a fingertip.
const SLOT_NODE := "ShopOfferSlot"
## …and the metas the slot carries. `shop_slot` marks the region; `shop_offer` names WHICH offer it
## resolves to, and it is set from the SAME card dictionary that supplies `on_buy` — so the overlay's
## label and the purchase cannot disagree by construction.
const SLOT_META := "shop_slot"
const OFFER_META := "shop_offer"

const WALL_NODE := "ShopStallWall"
const SHELF_FACE_NODE := "ShopShelfFace"
const SHELF_LIP_NODE := "ShopShelfLip"
const AWNING_NODE := "ShopStallAwning"
const SIGN_NODE := "ShopStallSign"
const POST_NODE := "ShopStallPost"
const TAG_NODE := "ShopOfferTag"
const PLAQUE_NODE := "ShopOfferPlaque"
const HEADER_NODE := "ShopSectionPlaque"

## The stall's own HEIGHT for a given width and row plan, in the same layout px as `w`. Pulled out so the
## caller can solve for the width that fits a bounded screen (`fit_width` below) instead of scaling a
## built node — a Control transform would leave every hit rect lying about where it is.
static func height_for(w: float, rows: Array) -> float:
	var h: float = w * HEAD_H
	for r in rows:
		h += bay_h(w, r as Dictionary)
	return h + w * FOOT_H

## One shelf bay's height: its goods zone + the plank's lit face + its front lip, plus the section plaque
## band when this shelf leads a section.
static func bay_h(w: float, row: Dictionary) -> float:
	var counter := bool(row.get("counter", false))
	var h: float = w * ((COUNTER_GOODS + COUNTER_FACE + COUNTER_LIP) if counter \
		else (LADDER_GOODS + LADDER_FACE + LADDER_LIP))
	if String(row.get("header", "")) != "":
		h += w * HEADER_H
	return h

## The widest stall that fits `max_h`, capped at `want_w`. `max_h <= 0` = unbounded (the workbench and the
## mock rig build at a stated width). Height is linear in width, so this is one divide, not a search.
static func fit_width(want_w: float, max_h: float, rows: Array) -> float:
	if max_h <= 0.0:
		return want_w
	var k: float = height_for(1.0, rows)          # height per unit width
	return minf(want_w, max_h / maxf(k, 0.001))

# --- the build -------------------------------------------------------------------------------------

## Build the whole stall at `w` layout px wide. `rows` is the shelf plan — one entry per shelf:
##   cards    Array   — the 1 or 2 offers standing on it (the storefront's own card dicts)
##   counter  bool    — the soft-currency counter shelf (taller, and each offer wears a caption plaque)
##   header   String  — a wide cream plaque fixed to the wall ABOVE this shelf ("ACORN POUCHES")
##   captions Array   — per-offer plaque text, parallel to `cards` (counter rows only)
## `opts`: on_close (Callable) · pill (Callable(card) -> Control, the storefront's own price pill) ·
##          kit (GDScript).
static func build(Kit: GDScript, w: float, rows: Array, opts: Dictionary = {}) -> Control:
	var h: float = height_for(w, rows)
	var stall := Control.new()
	stall.name = "ShopStall"
	stall.custom_minimum_size = Vector2(w, h)
	stall.size = Vector2(w, h)
	stall.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var cp: Dictionary = opts.get("cp", {}) as Dictionary
	_wall(Kit, stall, w, h, cp)
	_posts(Kit, stall, w, h, cp)

	var y: float = w * HEAD_H
	var offer_i := 0
	for r in rows:
		var row := r as Dictionary
		var head := String(row.get("header", ""))
		if head != "":
			_section_plaque(Kit, stall, w, y, w * HEADER_H, head, cp)
			y += w * HEADER_H
		offer_i = _shelf(Kit, stall, w, y, row, offer_i, opts)
		y += bay_h(w, row) - (w * HEADER_H if head != "" else 0.0)

	_awning(Kit, stall, w, cp)
	_sign(Kit, stall, w, String(opts.get("title", "")), cp)
	var on_close: Callable = opts.get("on_close", Callable())
	if on_close.is_valid():
		_close(Kit, stall, w, on_close)
	return stall

# --- the furniture ---------------------------------------------------------------------------------

## The back panel: one quiet cream-to-pale-meadow paper sheet with the stall's own drop shadow. It is the
## storefront's outermost sheet now, so it carries the shadow the dialog frame's sheet used to.
static func _wall(Kit: GDScript, stall: Control, w: float, h: float, cp: Dictionary) -> void:
	# NO z_index here. Child ORDER is what stacks the stall (the wall goes down first): a negative z_index
	# is resolved against the parent's, and the storefront's parent is the MODAL layer — so a wall at -2
	# rendered UNDER the modal veil and the whole stall came back dimmed by it.
	_sheet(Kit, stall, WALL_NODE, Rect2(0, 0, w, h), WALL, {
		"corner": w * 0.030, "rim_width": 2.0, "edge_shadow": true,
		"shadow_reach": w * 0.020}, cp)

## The two slender slate posts that frame the shelf stack and carry the awning.
static func _posts(Kit: GDScript, stall: Control, w: float, h: float, cp: Dictionary) -> void:
	var top: float = w * AWNING_H * 0.55
	# named per side: Godot renames a colliding sibling to "@Name@N", which no `Name*` search finds — so a
	# census of the furniture would silently see one post where there are two.
	for side in [0, 1]:
		var x: float = (w * POST_X) if side == 0 else (w * (1.0 - POST_X - POST_W))
		_sheet(Kit, stall, "%s%s" % [POST_NODE, "L" if side == 0 else "R"], Rect2(x, top, w * POST_W, h - top - w * FOOT_H * 0.4),
			SLATE_DARK, {"corner": w * 0.010, "edge_shadow": true, "shadow_reach": w * 0.010}, cp)

## One shelf: the plank (a lit top face over one same-hue front lip, the mock's "two masses only"), then
## the offer CELLS laid across it. Returns the running offer index.
static func _shelf(Kit: GDScript, stall: Control, w: float, top: float, row: Dictionary,
		offer_i: int, opts: Dictionary) -> int:
	var counter := bool(row.get("counter", false))
	var goods_h: float = w * (COUNTER_GOODS if counter else LADDER_GOODS)
	var face_h: float = w * (COUNTER_FACE if counter else LADDER_FACE)
	var lip_h: float = w * (COUNTER_LIP if counter else LADDER_LIP)
	var plank_top := top + goods_h
	var x0: float = w * (POST_X - SHELF_BLEED)
	var pw: float = w * (1.0 - 2.0 * (POST_X - SHELF_BLEED))
	# the lip goes down FIRST so the lit face stacks over it — and the lip is the mass that casts the
	# short tinted shadow onto the wall below (the plank's own contact shadow, per the mock).
	# the lip's own sheet starts just UNDER the lit face (not halfway up it) so the two planes read at the
	# mock's own proportions — a lip that begins mid-face swallows most of the lit top and the plank comes
	# back as one flat band.
	_sheet(Kit, stall, "%s%d" % [SHELF_LIP_NODE, offer_i], Rect2(x0, plank_top + face_h * 0.85, pw, lip_h + face_h * 0.15),
		SLATE_DARK, {"corner": w * 0.010, "edge_shadow": true, "shadow_reach": w * 0.020},
		opts.get("cp", {}))
	_sheet(Kit, stall, "%s%d" % [SHELF_FACE_NODE, offer_i], Rect2(x0, plank_top, pw, face_h),
		SLATE_LIT, {"corner": w * 0.008, "edge_shadow": false}, opts.get("cp", {}))

	var cards: Array = row.get("cards", [])
	var captions: Array = row.get("captions", [])
	var span_l: float = w * (POST_X + POST_W)
	var span_r: float = w * (1.0 - POST_X - POST_W)
	var n: int = maxi(1, cards.size())
	var cw: float = (span_r - span_l) / float(n)
	for i in cards.size():
		var cell := Rect2(span_l + cw * float(i), top, cw, plank_top + face_h + lip_h - top)
		_slot(Kit, stall, w, cell, cards[i] as Dictionary, offer_i + i, counter,
			String(captions[i]) if i < captions.size() else "",
			plank_top - top, face_h, lip_h, opts)
	return offer_i + cards.size()

## ONE OFFER, standing on its shelf inside its own hit rect. See SLOT_NODE for why the rect is the cell.
static func _slot(Kit: GDScript, stall: Control, w: float, cell: Rect2, card: Dictionary, idx: int,
		counter: bool, caption: String, goods_h: float, face_h: float, lip_h: float,
		opts: Dictionary) -> void:
	var slot := Button.new()
	slot.name = "%s%d" % [SLOT_NODE, idx]
	slot.flat = true
	slot.focus_mode = Control.FOCUS_NONE
	slot.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	slot.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	slot.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	slot.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	slot.position = cell.position
	slot.size = cell.size
	slot.custom_minimum_size = cell.size
	slot.set_meta(SLOT_META, true)
	slot.set_meta(OFFER_META, String(card.get("offer_id", "")))
	# the SAME callable the price button gets — one source, so a tap on the goods and a tap on the price
	# can never resolve to different purchases.
	var cb: Callable = card.get("on_buy", Callable())
	if cb.is_valid():
		slot.pressed.connect(func() -> void: cb.call())
	else:
		slot.disabled = true          # a cooling free faucet has nothing to buy — the cell must not swallow taps
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stall.add_child(slot)

	var s: float = _type_scale(w)                   # the mock is 1:1 with the design canvas — scale type with the stall
	var good_cx: float = cell.size.x * (0.44 if counter else 0.37)
	var text_cx: float = cell.size.x * (0.50 if counter else 0.65)

	# THE GOODS, STANDING on the plank and overhanging its lip. "Nothing floats" is the mock's own rule and
	# it is not free: every shop sprite is a 512² canvas with its own transparent margin, and those margins
	# run from 7% to 20% of the canvas across the eight goods (measured, not assumed). Sized and seated by
	# the BOX, the watering can — 18% margin top and bottom — hangs a fifth of a shelf above the plank while
	# the acorn sack sits on it. So both the size and the seat are taken from the sprite's OWN opaque rect
	# (`_art_frame`, cached per texture), and what the numbers below describe is the VISIBLE container.
	var icon_id := String(card.get("icon", "gem"))
	var frame := _art_frame(Kit, icon_id)                             # the opaque rect, in 0..1 of the canvas
	var scale_knob: float = maxf(0.2, float(opts.get("icon_scale", 1.0)))
	var vis_h: float = goods_h * (0.90 if counter else 0.93) * scale_knob
	var vis_w: float = cell.size.x * (0.92 if counter else 0.86) * scale_knob
	var art_px: float = minf(vis_h / maxf(frame.size.y, 0.05), vis_w / maxf(frame.size.x, 0.05))
	art_px = minf(art_px, goods_h / maxf(frame.end.y, 0.05))     # …and never taller than its own shelf bay
	var art: Control = Kit.make_icon(icon_id, art_px)
	art.custom_minimum_size = Vector2(art_px, art_px)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if art is TextureRect and (art as TextureRect).texture != null:
		art = SpritePanel.wrap_sprite(art, (art as TextureRect).texture)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art_host := Control.new()
	art_host.name = "ShopOfferGoods"
	art_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_host.size = Vector2(art_px, art_px)
	art_host.custom_minimum_size = Vector2(art_px, art_px)
	# the VISIBLE foot lands a touch BELOW the plank's top line — the container overhangs the shelf lip.
	var foot: float = goods_h + face_h * 0.30
	art_host.position = Vector2(
		_clamp_x(good_cx - (frame.position.x + frame.size.x * 0.5) * art_px, art_px, cell.size.x),
		maxf(0.0, foot - frame.end.y * art_px))
	art_host.add_child(art)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	slot.add_child(art_host)

	# THE AMOUNT, cut into a small cream tag propped against the container's base.
	var count := int(card.get("count", 0))
	var amount := _commas(count) if count > 0 else String(card.get("label", ""))
	var tag_bottom: float = goods_h + face_h * (0.10 if counter else 0.60)
	if amount != "":
		var tag_h: float = w * TAG_H
		var room: float = cell.size.x * 0.78 - w * TAG_PAD_X * 2.0
		var fsz: int = Kit.fit_bold_font_px(amount, int(round(FS.DISPLAY * s)), room)
		var lbl := _ink_label(Kit, amount, fsz)
		var tw: float = maxf(cell.size.x * 0.34, _text_w(Kit, amount, fsz) + w * TAG_PAD_X * 2.0)
		tw = minf(tw, cell.size.x * 0.92)
		var tag_rect := Rect2(_clamp_x(text_cx - tw * 0.5, tw, cell.size.x), tag_bottom - tag_h, tw, tag_h)
		# the amount TAG and the caption plaque below are the retired sage offer card's direct descendants —
		# the storefront's small cream sheets — so they take the SHARED corner as well as the shared
		# material, and the workbench's Shop page still tunes the storefront's own paper.
		var tag: Control = _sheet(Kit, slot, "%s%d" % [TAG_NODE, idx], tag_rect, TAG_CREAM, {
			"edge_shadow": true, "shadow_reach": w * 0.009}, opts.get("cp", {}))
		_centre_in(tag, lbl)

	# a cooling / capped free faucet prints its timer where the price would be (a faucet at rest).
	var note := String(card.get("note", ""))

	# THE PRICE, in an action-green paper button pinned to the shelf lip below the tag.
	var make_pill: Callable = opts.get("pill", Callable())
	var pill: Control = make_pill.call(card) if make_pill.is_valid() else null
	var below: float = tag_bottom + w * PRICE_GAP
	if pill != null:
		var host := Control.new()
		host.name = "ShopOfferPriceHost"
		host.mouse_filter = Control.MOUSE_FILTER_IGNORE
		host.position = Vector2(0.0, below)
		host.size = Vector2(cell.size.x, w * 0.070)
		slot.add_child(host)
		var box := CenterContainer.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.position = Vector2(text_cx - cell.size.x * 0.5, 0.0)
		box.size = Vector2(cell.size.x, w * 0.070)
		host.add_child(box)
		box.add_child(pill)
	elif note != "":
		var nl := Label.new()
		nl.name = "ShopOfferNote"
		nl.text = note
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.add_theme_font_size_override("font_size", int(round(FS.BODY * s)))
		nl.add_theme_color_override("font_color", Pal.INK)
		nl.add_theme_constant_override("outline_size", 0)
		nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		nl.position = Vector2(0.0, below)
		nl.size = Vector2(cell.size.x, w * 0.070)
		slot.add_child(nl)

	# THE CAPTION, cut into a small cream plaque fixed to the counter's front lip.
	if caption != "":
		var cfz := int(round(FS.BODY * s))
		var clbl := _ink_label(Kit, caption.to_upper(), cfz)
		var pw: float = minf(cell.size.x * 0.96, _text_w(Kit, caption.to_upper(), cfz) + w * PLAQUE_PAD_X * 2.0)
		var ph: float = w * PLAQUE_H
		var py: float = goods_h + face_h + (lip_h - ph) * 0.5
		var plq: Control = _sheet(Kit, slot, "%s%d" % [PLAQUE_NODE, idx],
			Rect2(_clamp_x(cell.size.x * 0.5 - pw * 0.5, pw, cell.size.x), py, pw, ph), TAG_CREAM, {
			"edge_shadow": true, "shadow_reach": w * 0.008}, opts.get("cp", {}))
		_centre_in(plq, clbl)

## The wide section plaque riding the wall above a shelf ("ACORN POUCHES").
static func _section_plaque(Kit: GDScript, stall: Control, w: float, y: float, band: float, text: String, cp: Dictionary) -> void:
	var s: float = _type_scale(w)
	var lbl := _ink_label(Kit, text.to_upper(), int(round(FS.HEADING * s)))
	var pw: float = minf(w * 0.80, _text_w(Kit, text.to_upper(), int(round(FS.HEADING * s))) + w * 0.055)
	var ph: float = w * PLAQUE_H
	var plq: Control = _sheet(Kit, stall, "%s%d" % [HEADER_NODE, int(y)], Rect2((w - pw) * 0.5, y + (band - ph) * 0.5, pw, ph),
		TAG_CREAM, {"edge_shadow": true, "shadow_reach": w * 0.009}, cp)
	_centre_in(plq, lbl)

## The scalloped awning: alternating broad coral and warm-cream paper bays with a round hem, each one the
## shared cut-paper sheet wearing the new "scallop" base outline, so the whole row inherits the same fibre,
## cut edge and tinted shadow as every other surface in the game.
static func _awning(Kit: GDScript, stall: Control, w: float, cp: Dictionary) -> void:
	var band: float = w * AWNING_H
	var bay: float = w / float(AWNING_BAYS)
	for i in AWNING_BAYS:
		var col: Color = AWNING_CORAL if i % 2 == 0 else AWNING_CREAM
		_sheet(Kit, stall, "%s%d" % [AWNING_NODE, i], Rect2(bay * float(i), 0.0, bay, band), col, {
			"base_shape": "scallop", "corner": w * 0.010, "edge_shadow": true, "shadow_reach": w * 0.022}, cp)

## The hanging signboard: a slate plank slung on two fine cords, tilted a degree so it reads as hung.
static func _sign(Kit: GDScript, stall: Control, w: float, title: String, cp: Dictionary) -> void:
	var sw: float = w * SIGN_W
	var sh: float = w * SIGN_H
	var rect := Rect2((w - sw) * 0.5, w * SIGN_TOP, sw, sh)
	for dx in [0.10, 0.90]:      # the mock's two eyelets, just inside the board's own corners
		var cord := Line2D.new()
		cord.name = "ShopStallCord%d" % int(float(dx) * 100.0)
		cord.width = maxf(2.0, w * 0.004)
		cord.default_color = CORD
		cord.points = PackedVector2Array([
			Vector2(rect.position.x + sw * float(dx), w * AWNING_H * 0.90),   # out of the awning's own hem
			Vector2(rect.position.x + sw * float(dx), rect.position.y + sh * 0.16)])
		stall.add_child(cord)
	var board: Control = _sheet(Kit, stall, SIGN_NODE, rect, SLATE_DARK, {
		"corner": w * 0.020, "edge_shadow": true, "shadow_reach": w * 0.020}, cp)
	board.pivot_offset = rect.size * 0.5
	board.rotation = deg_to_rad(SIGN_TILT_DEG)
	if title != "":
		var fsz: int = Kit.fit_bold_font_px(title.to_upper(), int(round(FS.BANNER * _type_scale(w))), sw * 0.82)
		var lbl := _ink_label(Kit, title.to_upper(), fsz, Pal.CREAM)
		_centre_in(board, lbl)

## The coral ✕ — the SHARED dialog close (Kit's own `_close_button`), so the stall's exit control is the
## same disc, the same sprite and the same node name ("DialogClose") every other sheet in the game wears.
static func _close(Kit: GDScript, stall: Control, w: float, cb: Callable) -> void:
	var d: float = w * CLOSE_D
	var b: Button = Kit._close_button(d, cb)
	b.position = Vector2(w * CLOSE_CX - d * 0.5, w * CLOSE_CY - d * 0.5)
	b.size = Vector2(d, d)
	b.custom_minimum_size = Vector2(d, d)
	stall.add_child(b)

# --- shared bits -----------------------------------------------------------------------------------

## One cut-paper sheet at an absolute rect inside `host`. Every surface in the stall goes through here, so
## the whole storefront resolves its material in one place (the shared engine/scripts/ui/cut_paper.gd).
##
## `base` is the SHARED cut-paper knob set the workbench tunes (Kit.shop_card_cp_from_config, the very
## dict the retired offer card read) and `over` is this surface's own GEOMETRY on top of it. The split is
## the point: the material — the smooth-vs-torn edge, the antialias band, the rim, the shadow strength —
## must stay one decision for the whole game, so when the UI's paper changes the storefront follows with
## no shop-specific work. Only what is genuinely per-surface (a plank's radius is not a price tag's, and
## a wall casts further than a tag) is overridden here.
static func _sheet(Kit: GDScript, host: Control, node_name: String, rect: Rect2, fill: Color,
		over: Dictionary, base: Dictionary = {}) -> Control:
	var cp: Dictionary = base.duplicate(true)
	cp.merge(over, true)
	var CutPaper := load("res://engine/scripts/ui/cut_paper.gd")
	var s = CutPaper.new()
	s.name = node_name
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.position = rect.position
	s.size = rect.size
	s.custom_minimum_size = rect.size
	s.configure(cp, fill, null, Kit.cut_paper_tile())
	host.add_child(s)
	# a sheet placed at an absolute rect must NOT be re-laid out by a parent container preset
	s.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_KEEP_SIZE)
	s.position = rect.position
	s.size = rect.size
	return s

## Centre a label over a sheet, filling it — the plaque/tag/sign type is always one centred line.
static func _centre_in(sheet: Control, lbl: Label) -> void:
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sheet.add_child(lbl)

static func _ink_label(Kit: GDScript, text: String, size: int, col: Color = Pal.INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", Kit.bold_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_constant_override("outline_size", 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## THE OPAQUE RECT of an icon, in 0..1 of its own square canvas — where the drawn container actually sits
## inside the sprite's transparent margin. Read once per texture and CACHED: `Image.get_used_rect()` is a
## full scan, and the storefront rebuilds on every buy (the same reason the runtime glyph bake exists).
## An unreadable id falls back to the whole canvas, which is exactly the pre-measurement behaviour.
static var _frame_cache: Dictionary = {}
static func _art_frame(Kit: GDScript, icon_id: String) -> Rect2:
	if _frame_cache.has(icon_id):
		return _frame_cache[icon_id]
	var frame := Rect2(0.0, 0.0, 1.0, 1.0)
	# the SAME resolver `make_icon` draws through (the polished / baked mirror), so the rect measured is
	# the rect rendered — reading the raw source instead would be measuring a different image.
	var tex: Texture2D = Kit._icon_tex(icon_id)
	if tex != null:
		var img := tex.get_image()
		if img != null and img.get_width() > 0 and img.get_height() > 0:
			var used := img.get_used_rect()
			if used.size.x > 0 and used.size.y > 0:
				frame = Rect2(
					float(used.position.x) / float(img.get_width()),
					float(used.position.y) / float(img.get_height()),
					float(used.size.x) / float(img.get_width()),
					float(used.size.y) / float(img.get_height()))
	_frame_cache[icon_id] = frame
	return frame

## The stall's TYPE SCALE: its width over the design canvas's. The mock is 1:1 with that canvas, so every
## font size on the stall is its mock-measured tier times this — the whole storefront scales as one piece.
static func _type_scale(w: float) -> float:
	return w / maxf(1.0, Design.size().x)

## The rendered width of one line on the stall's own bold face. Measured on the FONT, not off an
## un-mounted Label's combined minimum size — that reported ~15% short and every plaque came out too
## narrow for its own caption, with the last letters printing on the wall beside it.
static func _text_w(Kit: GDScript, text: String, fsz: int) -> float:
	var f: Font = Kit.bold_font()
	return f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fsz).x if f != null else float(text.length() * fsz) * 0.6

## Keep a sheet inside its own cell — nothing an offer draws may cross into its neighbour's hit rect.
static func _clamp_x(x: float, width: float, cell_w: float) -> float:
	return clampf(x, 0.0, maxf(0.0, cell_w - width))

## Thousands separators on an amount ("13000" → "13,000"), as the mock prints them.
static func _commas(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out
