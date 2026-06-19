extends RefCounted
## Discovery-ladder MODAL (Wave 3, reskinned) — the tier ladder for a line: a veiled twig-framed
## parchment card whose tiers climb in a SNAKING 3-column grid (tier 1 bottom-left, winding up like a
## board path), with a leafy vine tracing the snake between cells. A grown tier shows its sprite, an
## unseen tier the baked "?" cell; the marked tier wears the gold-ring cell. Self-contained popup, like
## ui/shop.gd + ui/bag_overlay.gd: builds its overlay into `host`, dismisses on a veil tap or the shared
## ✕ disc, enters with FX.pop_in. The coordinator owns the open-gate (the discovery_ladder feature +
## line validity) and the data (Quests.ladder_entries); this just renders + dismisses.
##   Ladder.open(host, {title: String, entries: Array, mark_tier: int})
##
## Art (sliced from _new/tiers_asset.png into ui/kit/, the §kit invariant — code-drawn fallbacks keep
## the SAME layout when a sprite is absent): tiers_panel (the twig frame), tiers_banner (the gold
## ribbon, ridden by engine text via Look.banner_title), tiers_cell_filled / _q / _sel (the discovered
## / locked / marked tile), tiers_vine_h + tiers_sprig + tiers_flower(_sm) (the woven snake path). The
## ✕ reuses the shared Look.close_button (one ✕ language across every modal).

const Game = preload("res://engine/scripts/core/game.gd")
const Audio = preload("res://engine/scripts/core/audio.gd")
const Look = preload("res://engine/scripts/ui/skin.gd")
const FX = preload("res://engine/scripts/ui/fx.gd")
const PieceView = preload("res://engine/scripts/ui/piece_view.gd")
const Pal = Game.PALETTE
const GROUND = Pal.GROUND
const GROUND_EDGE = Pal.GROUND_EDGE
const STRAW = Pal.STRAW
const CREAM = Pal.CREAM
const INK = Pal.INK
const BARK = Pal.BARK

# --- layout dials (inline, like bag_overlay.gd's CELL_W/H — these modal builders keep their own) ----
const COLS := 3                  # the snake is 3 wide (matches the reference card's portrait proportions)
const CELL := 196.0              # a tier tile's rendered square (art native ≈ 222)
const SEP := 32.0                # the gutter between tiles — wide enough for the woven vine to read
const PAD_X := 64.0              # content inset from the frame's twig border (left/right)
const PAD_TOP := 138.0           # top inset — leaves room under the straddling banner
const PAD_BOT := 60.0            # bottom inset
const PANEL_PATCH := 72.0        # the frame's nine-patch border margin (608×683 source twig edge)
const PIECE_FRAC := 0.66         # a discovered piece's size as a fraction of CELL
const SEL_OVERFLOW := 1.14       # the marked tile renders larger so its glow/sparkles spill past the cell
const NUM_FONT := 32             # the tier number, top-left of each tile
const BANNER_FONT := 54
const BANNER_WIDEN := 1.06       # the ribbon overhangs the frame sides (tails outside) like the reference
const BANNER_RISE := 0.44        # how much of the banner sits ABOVE the frame's top edge
const CLOSE_PX := 92.0           # the ✕ disc, docked at the frame's top-right corner
const VINE_H_THICK := 64.0       # the horizontal vine strip's rendered height
const VINE_V_THICK := 60.0       # the vertical connector's rendered width (a rotated vine strip)
const VINE_TUCK := 28.0          # how far a vine runs UNDER the cells (so it reads as continuous, not floating)
const FLOWER_PX := 150.0         # the pink flower spray that fills any empty trailing slot
const FLOWER_TURN_PX := 92.0     # the smaller blooms dotting the snake's turns
const SPARKLE_PX := 58.0         # the sparkle stars dotted at the snake's turns

static func open(host: Control, opts: Dictionary) -> void:
	var title: String = opts.title
	var entries: Array = opts.entries
	var mark_tier: int = opts.mark_tier
	Audio.play("button_tap", -4.0)

	var n := entries.size()
	var rows := int(ceil(float(n) / float(COLS)))
	var card_w := 2.0 * PAD_X + COLS * CELL + (COLS - 1) * SEP
	var card_h := PAD_TOP + PAD_BOT + rows * CELL + (rows - 1) * SEP

	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.add_child(overlay)
	var dismiss := func() -> void:
		if is_instance_valid(overlay):
			overlay.queue_free()

	var veil := ColorRect.new()
	veil.color = Color(GROUND_EDGE, 0.55)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(veil)
	veil.gui_input.connect(func(ev: InputEvent) -> void:
		if (ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed):
			dismiss.call())

	# the card is laid out by hand (a fixed grid of fixed tiles) so the woven vine + straddling
	# banner can be placed from computed cell rects — a CenterContainer just centres the whole card.
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(cc)
	var card := Control.new()
	card.custom_minimum_size = Vector2(card_w, card_h)
	cc.add_child(card)

	# the twig frame (nine-patch so the border stays crisp), or a code-drawn parchment panel.
	card.add_child(_panel(card_w, card_h))
	# the woven-vine layer sits BEHIND the tiles (child order = draw order): it peeks through gutters.
	var vines := Control.new()
	vines.set_anchors_preset(Control.PRESET_FULL_RECT)
	vines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(vines)

	# place every tier tile + remember its grid cell (gr, c) for the vine + flower routing.
	var order := _grid_order(entries, rows)          # length rows*COLS; entry dict or null, top row first
	var cell_at := {}                                # "gr,c" -> Vector2 (tile top-left in card space)
	for gr in range(rows):
		for c in range(COLS):
			var pos := Vector2(PAD_X + c * (CELL + SEP), PAD_TOP + gr * (CELL + SEP))
			cell_at[Vector2i(c, gr)] = pos
			var e = order[gr * COLS + c]
			if e == null:
				continue
			card.add_child(_tile(e, mark_tier, pos))

	# the woven snake: a horizontal vine along each row + a vertical connector at each turn, then
	# flowers at the turns, the path's ends, and the empty top slot (full-fidelity to the reference).
	_weave(vines, order, rows, cell_at)

	# the gold ribbon banner — reuses the shared Look.banner_title builder with the tiers ribbon art,
	# placed as an overlay straddling the frame's top edge (tails hanging past the sides).
	var banner := Look.banner_title(title, BANNER_FONT, 150.0, "kit/tiers_banner.png")
	overlay.add_child(banner)
	# the shared ✕ disc (one close language across modals), docked at the frame's top-right corner.
	var close := Look.close_button(dismiss)
	close.custom_minimum_size = Vector2(CLOSE_PX, CLOSE_PX)
	overlay.add_child(close)

	var place := func() -> void:
		if not (is_instance_valid(card) and is_instance_valid(banner) and is_instance_valid(close)):
			return
		var r := card.get_global_rect()
		var bw := r.size.x * BANNER_WIDEN
		var bh := bw * (153.0 / 768.0)
		banner.size = Vector2(bw, bh)
		banner.global_position = Vector2(r.position.x + (r.size.x - bw) / 2.0, r.position.y - bh * BANNER_RISE)
		close.size = Vector2(CLOSE_PX, CLOSE_PX)
		close.global_position = Vector2(r.position.x + r.size.x - CLOSE_PX * 0.66, r.position.y - CLOSE_PX * 0.22)
	card.resized.connect(place)
	place.call_deferred()

	FX.pop_in(card)

# --- the snake ordering ---------------------------------------------------------------
# Lay tiers 1..n into a boustrophedon grid: row 0 (BOTTOM) reads left→right, the next row right→left,
# climbing up — so the tiers wind like a board path (Snakes & Ladders). Returns a flat array in
# GridContainer fill order (TOP row first) of entry-or-null; a short top row trails nulls (the decor slot).
static func _grid_order(entries: Array, rows: int) -> Array:
	var n := entries.size()
	var by_row: Array = []                            # by_row[r], r=0 is the BOTTOM row
	for r in range(rows):
		var rowarr: Array = []
		for c in range(COLS):
			var ti := r * COLS + c
			rowarr.append(entries[ti] if ti < n else null)
		if r % 2 == 1:
			rowarr.reverse()                          # odd rows wind back (right→left)
		by_row.append(rowarr)
	var out: Array = []
	for r in range(rows - 1, -1, -1):                 # assemble TOP→BOTTOM for the grid
		out.append_array(by_row[r])
	return out

# --- one tier tile --------------------------------------------------------------------
static func _tile(e: Dictionary, mark_tier: int, pos: Vector2) -> Control:
	var tier := int(e.tier)
	var seen := bool(e.seen)
	var marked := tier == mark_tier
	var holder := Control.new()
	holder.position = pos
	holder.custom_minimum_size = Vector2(CELL, CELL)
	holder.size = Vector2(CELL, CELL)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# the tile face: marked → gold-ring cell · discovered → filled cell · unseen → the baked "?" cell.
	var art := "kit/tiers_cell_sel.png" if marked else ("kit/tiers_cell_filled.png" if seen else "kit/tiers_cell_q.png")
	if ResourceLoader.exists(Look.kit(art)):
		var face := TextureRect.new()
		face.texture = load(Look.kit(art))
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if marked:                                    # let the ring's glow + sparkles spill past the cell
			var over := CELL * (SEL_OVERFLOW - 1.0) / 2.0
			face.position = Vector2(-over, -over)
			face.size = Vector2(CELL * SEL_OVERFLOW, CELL * SEL_OVERFLOW)
		else:
			face.set_anchors_preset(Control.PRESET_FULL_RECT)
		holder.add_child(face)
	else:                                             # code-drawn fallback (the pre-reskin look)
		var p := Panel.new()
		p.set_anchors_preset(Control.PRESET_FULL_RECT)
		var ss := StyleBoxFlat.new()
		ss.bg_color = Color(GROUND, 0.18) if seen else Color(GROUND_EDGE, 0.16)
		ss.set_corner_radius_all(22)
		ss.set_border_width_all(5 if marked else 2)
		ss.border_color = STRAW if marked else Color(GROUND_EDGE, 0.35)
		p.add_theme_stylebox_override("panel", ss)
		holder.add_child(p)

	# the content: a discovered piece, or a "?" glyph when the gold-ring cell sits on an unseen tier
	# (the _q cell already bakes its own "?", so only the marked-unseen edge needs a drawn mark).
	if seen:
		var ic := PieceView.make_piece(int(e.code), CELL * PIECE_FRAC)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cwrap := CenterContainer.new()
		cwrap.set_anchors_preset(Control.PRESET_FULL_RECT)
		cwrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cwrap.add_child(ic)
		holder.add_child(cwrap)
	elif marked:
		var q := Label.new()
		q.text = "?"
		q.set_anchors_preset(Control.PRESET_FULL_RECT)
		q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		q.add_theme_font_size_override("font_size", int(CELL * 0.42))
		q.add_theme_color_override("font_color", Color(BARK, 0.7))
		q.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(q)

	# the tier number, top-left (a dark numeral with a thin cream halo so it reads on the warm tile).
	var num := Label.new()
	num.text = str(tier)
	num.position = Vector2(CELL * 0.11, CELL * 0.05)
	num.add_theme_font_size_override("font_size", NUM_FONT)
	num.add_theme_color_override("font_color", Color(BARK, 0.92))
	num.add_theme_color_override("font_outline_color", Color(CREAM, 0.9))
	num.add_theme_constant_override("outline_size", 5)
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(num)
	return holder

# --- the woven vine path --------------------------------------------------------------
# Trace the snake with leafy vines BEHIND the tiles (they show through the gutters), a vertical
# connector turning the corner at each row's end, then a pink flower in the empty top slot and
# sparkle stars at the turns. Each piece skips silently if its art is absent (decor is optional).
static func _weave(layer: Control, order: Array, rows: int, cell_at: Dictionary) -> void:
	var ctr := func(c: int, gr: int) -> Vector2:
		return cell_at[Vector2i(c, gr)] + Vector2(CELL, CELL) / 2.0
	# which columns each grid row actually occupies (the short top row stops early).
	var occ := func(gr: int) -> Array:
		var cols: Array = []
		for c in range(COLS):
			if order[gr * COLS + c] != null:
				cols.append(c)
		return cols

	# 1) a horizontal vine along every row, spanning its first→last occupied tile centre.
	for gr in range(rows):
		var cols: Array = occ.call(gr)
		if cols.size() < 2:
			continue
		var a: Vector2 = ctr.call(int(cols[0]), gr)
		var b: Vector2 = ctr.call(int(cols[cols.size() - 1]), gr)
		_vine_h(layer, a.x, b.x, a.y)

	# 2) a vertical connector at each snake turn. Data row r (0=bottom) ends at the RIGHT when r is
	#    even, the LEFT when odd; the turn climbs to the row above. Grid row gr = (rows-1) - r.
	for r in range(rows - 1):
		var turn_c := COLS - 1 if r % 2 == 0 else 0
		var gr_lo := (rows - 1) - r            # the lower row's grid index
		var lo: Vector2 = ctr.call(turn_c, gr_lo)
		var hi: Vector2 = ctr.call(turn_c, gr_lo - 1)
		_vine_v(layer, lo.x, hi.y, lo.y)
		# a small bloom + a sparkle dot the turn (flip the spray to nestle into the right-side bends).
		_flower(layer, Vector2(lo.x, (hi.y + lo.y) / 2.0), FLOWER_TURN_PX, turn_c >= COLS - 1)
		_sparkle(layer, Vector2(lo.x + (24.0 if turn_c == 0 else -24.0), (hi.y + lo.y) / 2.0 - 30.0), SPARKLE_PX)

	# 3) the pink flower spray fills the empty trailing slot in the (short) top row, pointing inward.
	for c in range(COLS):
		if order[c] == null:                   # top grid row is indices 0..COLS-1
			_flower(layer, cell_at[Vector2i(c, 0)] + Vector2(CELL, CELL) / 2.0, FLOWER_PX, c >= COLS - 1)

# A horizontal leafy vine strip between two tile centres at height `y`, tucked under the flanking tiles.
static func _vine_h(layer: Control, x0: float, x1: float, y: float) -> void:
	var p := Look.kit("kit/tiers_vine_h.png")
	if not ResourceLoader.exists(p):
		return
	var t := TextureRect.new()
	t.texture = load(p)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.size = Vector2((x1 - x0) + VINE_TUCK * 2.0, VINE_H_THICK)
	t.position = Vector2(x0 - VINE_TUCK, y - VINE_H_THICK / 2.0)
	layer.add_child(t)

# A vertical connector — the same vine strip rotated 90° about its centre — spanning two row centres.
static func _vine_v(layer: Control, cx: float, y_hi: float, y_lo: float) -> void:
	var p := Look.kit("kit/tiers_vine_h.png")
	if not ResourceLoader.exists(p):
		return
	var t := TextureRect.new()
	t.texture = load(p)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.size = Vector2((y_lo - y_hi) + VINE_TUCK * 2.0, VINE_V_THICK)   # length runs along X before rotation
	t.pivot_offset = t.size / 2.0
	t.rotation_degrees = 90.0
	t.position = Vector2(cx, (y_hi + y_lo) / 2.0) - t.size / 2.0
	layer.add_child(t)

# The pink flower spray, centred at `c`, sized to `px` (aspect kept); `flip` mirrors it to point inward.
static func _flower(layer: Control, c: Vector2, px: float, flip: bool) -> void:
	var p := Look.kit("kit/tiers_flower.png")
	if not ResourceLoader.exists(p):
		return
	var t := TextureRect.new()
	t.texture = load(p)
	t.flip_h = flip
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.size = Vector2(px, px)
	t.position = c - Vector2(px, px) / 2.0
	layer.add_child(t)

# A sparkle star centred at `c` (the gold-ring cell bakes its own; these dot the snake's turns).
static func _sparkle(layer: Control, c: Vector2, px: float) -> void:
	var p := Look.kit("kit/tiers_sparkle.png")
	if not ResourceLoader.exists(p):
		return
	var t := TextureRect.new()
	t.texture = load(p)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.size = Vector2(px, px)
	t.position = c - Vector2(px, px) / 2.0
	layer.add_child(t)

# --- the twig frame -------------------------------------------------------------------
static func _panel(w: float, h: float) -> Control:
	var p := Look.kit("kit/tiers_panel.png")
	if ResourceLoader.exists(p):
		var np := NinePatchRect.new()
		np.texture = load(p)
		np.set_anchors_preset(Control.PRESET_FULL_RECT)
		np.patch_margin_left = int(PANEL_PATCH)
		np.patch_margin_right = int(PANEL_PATCH)
		np.patch_margin_top = int(PANEL_PATCH)
		np.patch_margin_bottom = int(PANEL_PATCH)
		np.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return np
	var pan := Panel.new()
	pan.set_anchors_preset(Control.PRESET_FULL_RECT)
	pan.add_theme_stylebox_override("panel", Look.kit_panel("parchment"))
	pan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return pan
