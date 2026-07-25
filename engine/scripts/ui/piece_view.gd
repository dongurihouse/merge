extends RefCounted
## The board's visual VOCABULARY — the builders that turn a code / cell / generator id into a
## Control: items (real art, coins, or a tier disc), the garden-bed mat, sealed brambles, and
## generators. Pure view builders: inputs in (code, size, cell, csz, board dims), a Control out —
## no scene/instance state. The scene owns placement + state; this owns how a thing looks.
## Layering: ui/ may import core/ + ui/, never scenes/ — see docs/design/merge_spec.md §15.

const G = preload("res://engine/scripts/core/content.gd")
const BoardModel = preload("res://engine/scripts/core/board_model.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const Features = preload("res://engine/scripts/core/features.gd")
const GenSparkle = preload("res://engine/scripts/ui/gen_sparkle.gd")   # code-drawn twinkle for the GEN highlight
const GenOutline = preload("res://engine/scripts/ui/gen_outline.gd")   # code-drawn silhouette rim for the GEN highlight
const Pal = Game.PALETTE
const KIT_PATH := "res://games/grove/tools/ui_workbench_kit.gd"   # the SHARED slot cell (bag + board)

const CREAM = Pal.CREAM
const STRAW = Pal.STRAW
const GROUND_EDGE = Pal.GROUND_EDGE

# U1: a soft white radial ellipse (alpha fades to 0 at the rim); modulated to the
# warm-earth backing colour at the call site. Cached — one texture for the board.
static var _backing: Texture2D
static func backing_tex() -> Texture2D:
	if _backing == null:
		var w := 96
		var h := 64
		var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
		var cx := (w - 1) / 2.0
		var cy := (h - 1) / 2.0
		for y in h:
			for x in w:
				var nx := (float(x) - cx) / cx
				var ny := (float(y) - cy) / cy
				var a := clampf(1.0 - sqrt(nx * nx + ny * ny), 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, a * a))   # squared = feathered rim
		_backing = ImageTexture.create_from_image(img)
	return _backing

# A broader radial bloom for generator halos. Contact shadows want a tight, squared-off falloff;
# generator glow needs a visible outer aura, especially on the pale board/workbench backgrounds.
static var _gen_halo: Texture2D
static func gen_halo_tex() -> Texture2D:
	if _gen_halo == null:
		var w := 128
		var h := 128
		var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
		var c := (w - 1) / 2.0
		for y in h:
			for x in w:
				var nx := (float(x) - c) / c
				var ny := (float(y) - c) / c
				var r := sqrt(nx * nx + ny * ny)
				var a := pow(clampf(1.0 - r, 0.0, 1.0), 0.62)
				img.set_pixel(x, y, Color(1, 1, 1, a))
		_gen_halo = ImageTexture.create_from_image(img)
	return _gen_halo

# Item textures are framed with inconsistent transparent padding, so KEEP_ASPECT_CENTERED on the
# raw image leaves the visible art off-centre in the cell. Crop each to its opaque content (cached
# per path) via an AtlasTexture so the art CENTERS. Falls back to the raw texture if get_image fails.
static var _content_cache: Dictionary = {}
static func _content_tex(path: String) -> Texture2D:
	if _content_cache.has(path):
		return _content_cache[path]
	var tex: Texture2D = load(path)
	var result: Texture2D = tex
	if tex != null:
		var img := tex.get_image()
		if img != null:
			var ur := img.get_used_rect()
			var full := Vector2i(tex.get_width(), tex.get_height())
			if ur.size.x > 0 and ur.size.y > 0 and (ur.position != Vector2i.ZERO or ur.size != full):
				var at := AtlasTexture.new()
				at.atlas = tex
				at.region = Rect2(ur)
				result = at
	_content_cache[path] = result
	return result


const ITEM_INSET := 0.16   # margin so art sits INSIDE the cell, not bleeding to its edge

# The content-cropped texture make_piece draws for a board code (line*100+tier), or null when the code
# has no art (a coin / placeholder). Public so a caller that wants the item's SILHOUETTE (e.g. a
# shape-true drop-shadow) reads the SAME cropped texture the piece renders, framed the same way.
static func content_texture(code: int) -> Texture2D:
	var path := G.item_tex_path(code)
	return _content_tex(path) if ResourceLoader.exists(path) else null

# THE one content_frac → inset mapping (Slot-cell "visible piece width as % of cell" → per-side
# margin). Owned here so every cell surface (live board, residents habitat/hand, previews) derives
# its inset from the SAME saved knob with the same clamp — they can't drift apart.
static func inset_from_content_pct(pct: float) -> float:
	return clampf((1.0 - pct / 100.0) / 2.0, 0.0, 0.45)

# THE one rule for the board item's fill %: Slot-cell owns piece size via bag_card.content_frac
# (the board wells reuse the bag card's cell), falling back to a board-block content_frac, the legacy
# board.item, then the shipped 68%. Any surface that must frame art exactly like a board cell reads
# this same source (board.gd for the live grid, residents for habitat/hand cells) so they never diverge.
static func board_content_pct(cfg: Dictionary) -> float:
	var b: Dictionary = cfg.get("board", {})
	var bc: Dictionary = cfg.get("bag_card", {})
	return float(bc.get("content_frac", b.get("content_frac", b.get("item", 68.0))))

# The board item's per-side inset, resolved from config through the shared rule above.
static func board_item_inset(cfg: Dictionary) -> float:
	return inset_from_content_pct(board_content_pct(cfg))

# THE shared board-item pipeline. Every board item — piece, coin, or generator — is a cell-sized
# holder built the SAME way: a soft contact shadow underneath (when item_backing is on), then the
# centered sprite on top. make_piece / make_generator only choose WHICH art goes through it.
# (Per-item customization can branch here later; today nothing does — one look for everything.)
static func _make_holder(size: float) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(size, size)
	holder.size = Vector2(size, size)
	holder.pivot_offset = Vector2(size, size) / 2.0
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return holder

# AF3: a soft warm CONTACT SHADOW under the item (first child = bottom). It has TWO states:
# RESTING (idle) — a tight ellipse hugging the item's lower border, just grounding it; and
# LIFTED (picked up) — a wider, lower, SOFTER ellipse that drops toward the board floor WHILE the
# item art RISES above it (set_lifted opens that gap). Without the gap the shadow just grows behind
# the item and stays invisible — the lift has to be the art pulling away from the ground shadow.
# make_* builds the resting state; the board flips it via set_lifted() on drag/drop. Never eats input.
const SHADOW_NAME := "ContactShadow"
const ART_NAME := "ItemArt"
const LIFT_RISE := 0.12   # how far the art rises (fraction of the cell) when picked up
const SHADOW_RESTING := {"w": 0.40, "h": 0.10, "y": 0.62, "a": 0.30}   # tight — hugs the item's lower border
const SHADOW_LIFTED := {"w": 0.62, "h": 0.17, "y": 0.74, "a": 0.24}    # wide, low, soft — the ground shadow of a raised item

static func _add_contact_shadow(holder: Control, size: float) -> void:
	if not Features.on("item_backing"):
		return
	if not bool(_item_shadow_cfg().get("on", true)):
		return   # the Slot cell's standard Shadow toggle governs item shadows EVERYWHERE, the board included
	var back := TextureRect.new()
	back.name = SHADOW_NAME
	back.texture = backing_tex()
	back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	back.stretch_mode = TextureRect.STRETCH_SCALE
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_shadow(back, size, SHADOW_RESTING)
	holder.add_child(back)

# Place + size + tint the contact shadow from a state preset (resting / lifted), relative to the
# cell `size`. Centered horizontally; `y` is the ellipse's top as a fraction of the cell height.
static func _apply_shadow(back: TextureRect, size: float, p: Dictionary) -> void:
	var w := size * float(p["w"])
	var h := size * float(p["h"])
	back.position = Vector2((size - w) / 2.0, size * float(p["y"]))
	back.size = Vector2(w, h)
	back.modulate = Color("#3E342A", float(p["a"]))

# The saved ITEM-shadow config (the Slot cell's standard item_shadow_* knobs) — ONE source for the
# shadow under an item in ANY cell: the dialogs' slot cells read it through bag_card_opts_from_config,
# and the board pieces read it here. `item_shadow_override` lets tests inject params without a config
# file on disk (empty = read the saved workbench config, cached by Kit.load_config).
static var item_shadow_override: Dictionary = {}
static func _item_shadow_cfg() -> Dictionary:
	if not item_shadow_override.is_empty():
		return item_shadow_override
	var Kit: GDScript = load(KIT_PATH)
	var opts: Dictionary = Kit.bag_card_opts_from_config(Kit.load_config(Kit.CONFIG_PATH))
	return {"on": bool(opts.get("content_shadow", true)), "params": opts.get("content_shadow_params", {})}

# Reshape the ellipse ContactShadow into the item's OWN silhouette — the shape-true stamp the Slot cell
# bakes (Kit.item_shadow_stamp, the standard item_shadow_* params), fitted exactly under the drawn art.
# Falls back silently (keeps the ellipse) when the art has no readable image (headless dummy renderer).
static func _shape_contact_shadow(holder: Control, tex: Texture2D, size: float, inset: float) -> void:
	var back := holder.get_node_or_null(NodePath(SHADOW_NAME))
	if not (back is TextureRect) or tex == null:
		return
	var ts := tex.get_size()
	if ts.x <= 0.0 or ts.y <= 0.0:
		return
	var Kit: GDScript = load(KIT_PATH)
	var box := maxf(1.0, size - inset * 2.0)
	var fit_scale := minf(box / ts.x, box / ts.y)
	var fit_sz := ts * fit_scale
	var fit_pos := Vector2(inset, inset) + (Vector2(box, box) - fit_sz) * 0.5
	var stamp: Dictionary = Kit.item_shadow_stamp(tex, fit_sz, _item_shadow_cfg().get("params", {}))
	if stamp.is_empty():
		return
	var pad := float(stamp.pad)
	back.texture = stamp.texture
	back.stretch_mode = TextureRect.STRETCH_SCALE
	back.position = fit_pos - Vector2(pad, pad)
	back.size = fit_sz + Vector2(pad, pad) * 2.0
	back.modulate = stamp.get("tint", Color(0, 0, 0, 0.2))   # rgb×0 = black cast; alpha lives here, not in the bake
	back.set_meta("rest_pos", back.position)   # set_lifted shifts from here (silhouette mode)
	back.set_meta("rest_alpha", back.modulate.a)

# Flip a built piece / generator between RESTING and LIFTED. The board calls this on pickup
# (lifted = true) and on drop (lifted = false). The art RISES and the shadow drops + spreads so
# the item visibly lifts OFF the board; both settle back on drop. No-ops for parts it can't find.
static func set_lifted(holder: Control, lifted: bool) -> void:
	var size := holder.size.x
	var rise := size * LIFT_RISE if lifted else 0.0
	var back := holder.get_node_or_null(NodePath(SHADOW_NAME))
	if back is TextureRect and back.has_meta("rest_pos"):
		# silhouette mode: the shadow stays put on the ground while the art rises — just soften it.
		# Only the ALPHA moves: the rgb is the baked-in shadow tint (black), never touched.
		var rest: Vector2 = back.get_meta("rest_pos")
		var rest_a: float = back.get_meta("rest_alpha", back.modulate.a)
		back.position = rest + (Vector2(0.0, size * LIFT_RISE * 0.5) if lifted else Vector2.ZERO)
		back.modulate.a = rest_a * (0.8 if lifted else 1.0)
	elif back is TextureRect:
		_apply_shadow(back, size, SHADOW_LIFTED if lifted else SHADOW_RESTING)
	var art := holder.get_node_or_null(NodePath(ART_NAME))
	if art is Control and art.has_meta("inset_px"):
		var inset: float = art.get_meta("inset_px")
		art.offset_top = inset - rise          # shift the art rect UP by `rise`, keeping its height
		art.offset_bottom = -inset - rise
	# A GENERATOR's silhouette decorations TRACE the sprite (the gold rim + the sparkle overlay), so they
	# must ride the lift WITH it — otherwise they stay at rest and read as "shifted" below the raised sprite
	# while the generator is dragged. Both are FULL_RECT (resting offsets 0) → lifted = -rise. The GenGlow
	# halo is intentionally LEFT at rest: like the contact shadow, it's a grounding layer the art lifts off
	# of. No-ops for a plain piece (these children are absent).
	for deco_name in ["GenOutline", "GenSparkle"]:
		var deco := holder.get_node_or_null(NodePath(deco_name))
		if deco is Control:
			deco.offset_top = -rise
			deco.offset_bottom = -rise

# The sprite over the shadow: cropped to its opaque content so it CENTERS in the cell (raw art
# padding varies), inset a little so it sits INSIDE the cell, aspect-preserving. Never eats input.
# Named + tagged with its resting inset so set_lifted() can RAISE it (lift off its shadow).
static func _add_sprite(holder: Control, tex: Texture2D, size: float, inset_frac: float) -> void:
	var t := TextureRect.new()
	t.name = ART_NAME
	t.texture = tex
	t.set_anchors_preset(Control.PRESET_FULL_RECT)
	var inset := size * inset_frac
	t.offset_left = inset
	t.offset_top = inset
	t.offset_right = -inset
	t.offset_bottom = -inset
	t.set_meta("inset_px", inset)   # resting top/bottom — set_lifted shifts up from here
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(t)
	# now that the art is known, restamp the contact shadow to ITS silhouette (shape-true)
	_shape_contact_shadow(holder, tex, size, inset)

# The SHARED cell seam for art that ISN'T a board code (e.g. a resident sprite resolved by
# G.resident_art, not G.item_tex_path). Builds the SAME holder + contact shadow + centered sprite as a
# board piece, so a non-board caller (the Residents dialog) grounds and LIFTS (set_lifted) exactly like a
# board tile — reusing this one construction instead of forking a parallel holder/shadow. `tex` is the
# already-resolved art texture (the caller crops to content); a null tex yields the bare shadowed holder.
static func make_piece_from_texture(tex: Texture2D, size: float, inset := ITEM_INSET) -> Control:
	var holder := _make_holder(size)
	_add_contact_shadow(holder, size)
	if tex != null:
		_add_sprite(holder, tex, size, inset)
	return holder

static func make_piece(code: int, size: float, inset := ITEM_INSET) -> Control:
	var path := G.item_tex_path(code)
	if ResourceLoader.exists(path):
		return make_piece_from_texture(_content_tex(path), size, inset)   # cropped to opaque content so it CENTERS (art padding varies); `inset` = the board.item width
	var holder := _make_holder(size)
	_add_contact_shadow(holder, size)
	# coins: painted acorn art by tier (tap to pocket). Tier alone reads the value —
	# no numeral is drawn over the sprite. Falls back to the code-drawn gold disc when
	# the tier sprite is absent.
	if G.is_coin(code):
		var ctier := BoardModel.tier_of(code)
		var cpath := Game.art("items/coin/coin_%d.png" % G.art_tier_for("coin", ctier))
		if cpath != "" and ResourceLoader.exists(cpath):
			_add_sprite(holder, _content_tex(cpath), size, inset)   # coins fit the cell UNIFORMLY — same inset as every other item (was a tighter 0.06)
		else:
			var cdisc := Panel.new()
			var cd := size * (0.5 + 0.1 * ctier)
			cdisc.size = Vector2(cd, cd)
			cdisc.position = (Vector2(size, size) - cdisc.size) / 2.0
			var csb := StyleBoxFlat.new()
			csb.bg_color = STRAW
			csb.set_corner_radius_all(int(cd / 2.0))
			csb.set_border_width_all(3)
			csb.border_color = Color("#C98A2B")
			cdisc.add_theme_stylebox_override("panel", csb)
			cdisc.mouse_filter = Control.MOUSE_FILTER_IGNORE
			holder.add_child(cdisc)
		return holder
	# placeholder: line-colored disc that grows with tier + tier number
	var tier := BoardModel.tier_of(code)
	var line := BoardModel.line_of(code)
	var disc := Panel.new()
	var dsz := size * (0.5 + 0.06 * tier)
	disc.size = Vector2(dsz, dsz)
	disc.position = (Vector2(size, size) - disc.size) / 2.0
	var sb := StyleBoxFlat.new()
	var base: Color = G.LINES[line].color if G.LINES.has(line) else Pal.TEXT_MUTED
	sb.bg_color = base.lerp(Color.WHITE, 0.06 * tier)
	sb.set_corner_radius_all(int(dsz / 2.0))
	sb.set_border_width_all(3)
	sb.border_color = GROUND_EDGE
	disc.add_theme_stylebox_override("panel", sb)
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(disc)
	var lbl := Label.new()
	lbl.text = str(tier)
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", int(size * 0.3))
	lbl.add_theme_color_override("font_color", GROUND_EDGE)
	lbl.add_theme_color_override("font_outline_color", CREAM)
	lbl.add_theme_constant_override("outline_size", 6)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(lbl)
	return holder

# The garden bed: a RAISED WOODEN PLANTER (warm wood walls + a soft drop shadow)
# holding a tilled-soil interior with a mossy grain on top. The wood rim IS the board
# edge — it replaces the old see-through mat whose translucent top margin read as a
# "glass bar" between the fence and the grid, and gives the play surface a tactile,
# themed look instead of a flat field showing through. board_w/board_h = the grid's
# pixel size (the scene passes _board_w()/_board_h()).
static func make_board_mat(board_w: float, board_h: float) -> Control:
	var pad := 22.0
	var rim := 13.0                               # the wooden planter wall thickness
	var mat := Control.new()
	mat.position = Vector2(-pad, -pad)
	mat.size = Vector2(board_w + pad * 2.0, board_h + pad * 2.0)
	mat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# the planter box — warm wood, rounded, with a soft drop shadow so the whole bed
	# reads as raised off the meadow (the rim, not a glassy strip, shows above row 0).
	var planter := Panel.new()
	planter.set_anchors_preset(Control.PRESET_FULL_RECT)
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color("#BE9568")                # light warm wood rim (was a dark #86603A — read muddy)
	ps.set_corner_radius_all(30)
	ps.set_border_width_all(0)
	ps.shadow_color = Color(0, 0, 0, 0.34)
	ps.shadow_size = 14
	ps.shadow_offset = Vector2(0, 6)
	planter.add_theme_stylebox_override("panel", ps)
	planter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mat.add_child(planter)
	# a thin lighter lip along the top inside edge → the wood wall reads as raised
	var lip := Panel.new()
	lip.position = Vector2(rim * 0.5, rim * 0.5)
	lip.size = Vector2(mat.size.x - rim, rim)
	var ls := StyleBoxFlat.new()
	ls.bg_color = Color("#D8B98C", 0.9)           # a sunlit catch on the rim (lightened to match)
	ls.corner_radius_top_left = 22
	ls.corner_radius_top_right = 22
	lip.add_theme_stylebox_override("panel", ls)
	lip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mat.add_child(lip)
	# the soil bed — inset inside the wood walls, near-opaque so the surface reads as
	# ground (not see-through), with a thin dark rim so the wood lip looks raised.
	var soil := Panel.new()
	soil.position = Vector2(rim, rim)
	soil.size = mat.size - Vector2(rim, rim) * 2.0
	var ss := StyleBoxFlat.new()
	ss.bg_color = Color("#E6DCC2", 0.98)          # COMFORTABLE light warm oat bed (was dark #5E4828 soil)
	ss.set_corner_radius_all(20)
	ss.set_border_width_all(2)
	ss.border_color = Color("#C2A878", 0.5)       # soft warm outline, not a hard dark line
	ss.shadow_color = Color(0, 0, 0, 0.12)        # a faint inner shade under the rim
	ss.shadow_size = 5
	soil.add_theme_stylebox_override("panel", ss)
	soil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mat.add_child(soil)
	# a faint warm tint over the soil bed (was a moss-texture grain sliced from tray_grove
	# art; now a flat color, no texture dependency), rounded to match the bed's corners.
	var grain := Panel.new()
	grain.position = soil.position
	grain.size = soil.size
	grain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gs := StyleBoxFlat.new()
	gs.bg_color = Color("#CDBB90", 0.14)          # barely-there warm grain on the light bed
	gs.set_corner_radius_all(20)
	grain.add_theme_stylebox_override("panel", gs)
	mat.add_child(grain)
	return mat


# A sealed cell. The look is now FLAG-DRIVEN by the scene (no internal level gating):
#   frontier   → the cell sits on the live border the player is reaching; the unlock level is
#                explained on tap in the board info bar, not as an on-cell badge.
#   not frontier → a NUMBERLESS locked tile (the calm deep locked look), faded back so deep
#                rings recede and the eye lands on the playable cells.
#   unlockable → this cell can be opened by a merge RIGHT NOW: it gets a bright highlight border
#                and full (un-faded) modulate so it POPS as the actionable next move.
# Defaults keep existing callers (board.gd, tools, tests) compiling unchanged.
# A sealed/gated board cell, built on the SHARED slot cell (Kit.slot_cell — the same component the bag
# uses). Locked cells use the Slot-cell code-drawn background; an UNLOCKABLE cell (openable by a merge
# right now) is the highlighted state (gold border + glow + dynamic sparkle).
static func make_bramble(cell: Vector2i, csz: float, frontier: bool = true, unlockable: bool = false) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(csz, csz)
	holder.size = Vector2(csz, csz)
	holder.pivot_offset = Vector2(csz, csz) / 2.0
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var Kit: GDScript = load(KIT_PATH)
	var opts: Dictionary = Kit.board_cell_opts_from_config(Kit.load_config(Kit.CONFIG_PATH))
	opts["cell_w"] = csz
	opts["cell_h"] = csz
	var d := {"state": ("unlockable" if unlockable else "locked"), "frontier": frontier}
	var cell_view: Control = Kit.slot_cell(d, opts)
	cell_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(cell_view)
	# RECEDE: non-unlockable locks fade back; an unlockable cell keeps full opacity so it POPS.
	if not unlockable:
		holder.modulate = Color(1.0, 1.0, 1.0, 0.86 if frontier else 0.60)
	return holder


# `hl` is the GEN-highlight override dict (from the UI workbench via Kit.gen_highlight_opts_from_config);
# absent keys fall back to the GEN_* consts below, so make_generator(id, csz) renders the shipped look.
static func make_generator(id: String, csz: float, hl: Dictionary = {}, tier: int = 1) -> Control:
	var gdef: Dictionary = G.gen_def(G.GENERATORS, id)   # roster def (empty for an accumulator — art still resolves below)
	var holder := _make_holder(csz)
	_add_contact_shadow(holder, csz)   # same contact shadow as a piece — generators ground identically
	_add_gen_glow(holder, csz, hl)     # GEN highlight (1/3): a warm halo BEHIND the art (added before it)
	var path: String = Game.art(G.gen_tex(id, tier))   # merge-gen roster OR an accumulator (§6.C) — one resolver
	holder.set_meta("gen_id", id)
	holder.set_meta("gen_tier", tier)
	holder.set_meta("gen_tex_path", path)
	if ResourceLoader.exists(path):
		_add_gen_outline(holder, csz, path, hl)   # GEN highlight (2/3): gold rim tracing the silhouette, BEHIND the art
		_add_sprite(holder, _content_tex(path), csz, ITEM_INSET)   # same crop-to-content + inset as a piece
	else:
		var p := Panel.new()
		p.set_anchors_preset(Control.PRESET_FULL_RECT)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("#8A5A3B")
		sb.set_corner_radius_all(int(csz * 0.3))
		sb.set_border_width_all(4)
		sb.border_color = STRAW
		p.add_theme_stylebox_override("panel", sb)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(p)
		var lbl := Label.new()
		lbl.text = TranslationServer.translate(String(gdef.get("label", id)))
		lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", int(csz * 0.24))
		lbl.add_theme_color_override("font_color", CREAM)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(lbl)
	# GEN highlight (3/3): a few slow twinkles ON TOP — together with the glow + silhouette rim this marks
	# a generator as a special, permanent producer (vs. a mergeable piece). Added last so it sits over the
	# art and never disturbs child(0) (the contact shadow / sprite). The board's FX.breathe makes it pulse.
	_add_gen_sparkle(holder, csz, hl)
	return holder

# GEN highlight — the look that says "this is a generator, a permanent producer" (vs. a mergeable
# piece). THE FEEL-DIAL: three subtle layers, tuned here (these consts are the SHIPPED defaults; the UI
# workbench's "generator" knobs override them via the `hl` dict — keep the two in sync). A warm GLOW
# halo behind the art, a gold OUTLINE tracing the art's silhouette, and a few slow SPARKLE twinkles over
# it. Each part is mouse-ignore (keeps _all_ignore green) and never becomes child(0) (keeps the shadow/
# sprite invariant make_piece shares). `scale`/`a`/`width` fractions are of the cell size.
const GEN_GLOW := {"scale": 1.0, "color": "#FFD27A", "a": 0.30}                  # warm halo
const GEN_OUTLINE := {"width": 0.035, "alpha": 0.85, "color": "#E8BE5C", "blur": 0.0, "steps": 16}   # gold silhouette rim
const GEN_SPARKLE := {"count": 5, "size": 1.0, "speed": 0.7, "color": "#FFF4C2"}

static func _highlight_color(value: Variant, fallback_hex: String) -> Color:
	if value is Color:
		return value
	var fallback := Color(fallback_hex)
	if value == null:
		return fallback
	var hex := String(value).strip_edges()
	if hex == "":
		return fallback
	if not hex.begins_with("#"):
		hex = "#" + hex
	return Color.from_string(hex, fallback)

# (1/3) A warm radial halo BEHIND the art. Shares the grounding layer with the contact shadow (added
# before the sprite, drawn under it), so — like the shadow — it follows item_backing; that keeps the
# "bare when backing off" affordance and the child(0) invariant intact.
static func _add_gen_glow(holder: Control, size: float, hl: Dictionary = {}) -> void:
	if not Features.on("item_backing"):
		return
	var glow := TextureRect.new()
	glow.name = "GenGlow"
	glow.texture = gen_halo_tex()
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gw := size * float(hl.get("glow_scale", GEN_GLOW["scale"]))
	glow.size = Vector2(gw, gw)
	glow.position = (Vector2(size, size) - glow.size) / 2.0
	var glow_color := _highlight_color(hl.get("glow_color", GEN_GLOW["color"]), GEN_GLOW["color"])
	glow_color.a = float(hl.get("glow_a", GEN_GLOW["a"]))
	glow.modulate = glow_color
	holder.add_child(glow)
	# Seat the halo UNDER the contact shadow: drawn over it, the warm aura washes the dark cast out and
	# the generator reads shadow-less. Ground order becomes glow → shadow → (outline · art). The child-0
	# helpers (add_ready_glow / add_grab_glow) key on the shadow BY NAME at index 0 and fall back to
	# index 0 otherwise, so a glow at 0 only seats those overlays one layer lower — still behind the art.
	if holder.get_child_count() > 1 and String(holder.get_child(0).name) == SHADOW_NAME:
		holder.move_child(glow, 0)

# A warm AMBER "a quest wants this" highlight — the board-side twin of the giver's ✓/bob. It is an
# inset, rounded FACE behind the item. Keeping it inside the same 3px inset as the Slot-cell background
# preserves every board gutter: quest markers must not join adjacent paper cells or cast cell shadows.
# It sits just above the contact shadow and behind the sprite, preserving make_piece's shadow-at-0
# invariant. The board clears it (get_node_or_null("ReadyGlow")) as quests come and go. Returns the glow
# node, or null when the holder already wears one (idempotent).
# color and fill_a are live style controls; the legacy halo values remain accepted in `hl` for saved
# workbench compatibility but intentionally do not draw outside the cell face.
const READY_GLOW := {"color": "#FFB12E", "fill_a": 0.55, "halo_a": 0.6, "corner_frac": 0.22, "halo_frac": 0.16}
const READY_GLOW_FACE_INSET := 6.0
static func add_ready_glow(holder: Control, size: float, hl: Dictionary = {}) -> Control:
	if holder.has_node("ReadyGlow"):
		return null
	var below := 1 if (holder.get_child_count() > 0 and String(holder.get_child(0).name) == SHADOW_NAME) else 0
	# A halo BEHIND the item read too faint on the cream board (its bright core hid behind the sprite,
	# only the pale falloff showed). Instead FILL the cell with a soft warm amber (rounded, like a lit
	# slot) plus a glow shadow that spills past the cell — the way the frontier cells read clearly.
	var col: Color = hl.get("color", Color(READY_GLOW["color"]))
	var glow := Panel.new()
	glow.name = "ReadyGlow"
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var face_size := maxf(1.0, size - READY_GLOW_FACE_INSET * 2.0)
	glow.position = Vector2.ONE * READY_GLOW_FACE_INSET
	glow.size = Vector2.ONE * face_size
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(col, float(hl.get("fill_a", READY_GLOW["fill_a"])))
	sb.set_corner_radius_all(int(face_size * float(hl.get("corner_frac", READY_GLOW["corner_frac"]))))
	sb.shadow_color = Color.TRANSPARENT
	sb.shadow_size = 0
	glow.add_theme_stylebox_override("panel", sb)
	holder.add_child(glow)
	holder.move_child(glow, below)
	return glow

# A white SILHOUETTE of an icon (rgb forced white, alpha kept) so GenOutline can tint it to any rim
# colour. Built from the SAME crop-to-content texture the sprite uses, so the rim aligns. Cached per
# path; the byte pass (rgb=255) is far cheaper than per-pixel get/set.
static var _silhouette_cache: Dictionary = {}
static func _silhouette_tex(path: String) -> Texture2D:
	if _silhouette_cache.has(path):
		return _silhouette_cache[path]
	var ct := _content_tex(path)
	var result: Texture2D = _silhouette_from_tex(ct) if ct != null else null
	_silhouette_cache[path] = result
	return result

# The white-silhouette byte pass (rgb forced to 255, alpha kept = the shape) from ANY texture — the
# shared core of _silhouette_tex (cached per path, for the gold gen rim) and the grab outline (built
# live from a held tile's OWN art texture). Returns null when the texture has no readable image.
static func _silhouette_from_tex(tex: Texture2D) -> Texture2D:
	if tex == null:
		return null
	var img := tex.get_image()
	if img == null:
		return null
	if img.is_compressed():
		img.decompress()
	if img.has_mipmaps():
		img.clear_mipmaps()   # silhouette needs mip 0 only; a mip chain breaks create_from_data(…false…)
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	var data := img.get_data()
	for i in range(0, data.size(), 4):
		data[i] = 255
		data[i + 1] = 255
		data[i + 2] = 255           # keep data[i + 3] (the alpha = the shape)
	return ImageTexture.create_from_image(
		Image.create_from_data(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8, data))

# (2/3) A gold rim TRACING the icon's silhouette (not a square frame). GenOutline draws the white
# silhouette tinted + offset around a ring; the art sprite (added after, on top) covers the interior.
static func _add_gen_outline(holder: Control, size: float, path: String, hl: Dictionary = {}) -> void:
	var sil := _silhouette_tex(path)
	if sil == null:
		return
	var o := GenOutline.new()
	o.name = "GenOutline"
	o.set_anchors_preset(Control.PRESET_FULL_RECT)
	o.mouse_filter = Control.MOUSE_FILTER_IGNORE
	o.tex = sil
	o.inset = ITEM_INSET                    # MUST match the sprite so the rim aligns
	o.color = _highlight_color(hl.get("outline_color", GEN_OUTLINE["color"]), GEN_OUTLINE["color"])
	o.width = float(hl.get("outline_w", GEN_OUTLINE["width"])) * size
	o.alpha = float(hl.get("outline_a", GEN_OUTLINE["alpha"]))
	o.blur = float(hl.get("outline_blur", GEN_OUTLINE["blur"])) * size   # feather, as a fraction of cell
	o.steps = int(GEN_OUTLINE["steps"])
	holder.add_child(o)

# The GRAB highlight rim — the SAME silhouette-tracing outline as the generator highlight, but driven
# on/off as the player picks a tile UP (GrabFx.grab/release call these). Built from the held tile's OWN
# art texture (forced white), so it traces any piece. Idempotent (a second call while one is on is a
# no-op); a no-op for a tile with no art sprite (e.g. a placeholder disc — nothing to trace). The rim
# seats just UNDER the art sprite so the art covers the interior, leaving only the rim peeking.
const GRAB_OUTLINE_NAME := "GrabOutline"
static func add_grab_outline(holder: Control, color: Color, width_frac: float, alpha: float) -> void:
	if holder == null or not is_instance_valid(holder):
		return
	if holder.has_node(NodePath(GRAB_OUTLINE_NAME)):
		return
	var art := holder.get_node_or_null(NodePath(ART_NAME))
	if not (art is TextureRect) or (art as TextureRect).texture == null:
		return
	var sil := _silhouette_from_tex((art as TextureRect).texture)
	if sil == null:
		return
	var size := holder.size.x
	var art_c := art as Control
	var o := GenOutline.new()
	o.name = GRAB_OUTLINE_NAME
	o.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Overlay the sprite's EXACT rect by mirroring its anchors + offsets, then draw at inset 0. This makes
	# the rim track BOTH the sprite's tuned inset (board content_frac, not a fixed 0.16) AND its LIFTED
	# position (set_lifted raises the art ~12% on pickup) — a fixed FULL_RECT+inset rim does neither, so it
	# ends up smaller than a large board sprite and shifted below the lifted art (the on-board "shifted
	# outline" bug). GenOutline then aspect-fits the silhouette in that rect, same box the sprite fills.
	o.anchor_left = art_c.anchor_left
	o.anchor_top = art_c.anchor_top
	o.anchor_right = art_c.anchor_right
	o.anchor_bottom = art_c.anchor_bottom
	o.offset_left = art_c.offset_left
	o.offset_top = art_c.offset_top
	o.offset_right = art_c.offset_right
	o.offset_bottom = art_c.offset_bottom
	o.tex = sil
	o.inset = 0.0
	o.color = color
	o.width = width_frac * size
	o.alpha = alpha
	o.steps = int(GEN_OUTLINE["steps"])
	holder.add_child(o)
	holder.move_child(o, art_c.get_index())   # seat the rim just UNDER the art sprite

# The GRAB GLOW — a soft radial HALO behind a held tile (GrabFx.grab/release call these). A modulate
# brighten is invisible on bright art (it clamps at 1.0), so the glow is a real aura: the same radial
# bloom the generator halo uses, tinted + sized by the caller, seated just above the contact shadow so it
# spills out AROUND the item. Idempotent + null-safe.
const GRAB_GLOW_NAME := "GrabGlow"
static func add_grab_glow(holder: Control, color: Color, scale_frac: float) -> void:
	if holder == null or not is_instance_valid(holder):
		return
	if holder.has_node(NodePath(GRAB_GLOW_NAME)):
		return
	var size := holder.size.x
	var g := TextureRect.new()
	g.name = GRAB_GLOW_NAME
	g.texture = gen_halo_tex()
	g.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	g.stretch_mode = TextureRect.STRETCH_SCALE
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gw := size * scale_frac
	g.size = Vector2(gw, gw)
	g.position = (Vector2(size, size) - g.size) / 2.0
	g.modulate = color
	holder.add_child(g)
	# seat the aura just above the contact shadow (so it sits BEHIND the sprite + rim and spills outward)
	var below := 1 if (holder.get_child_count() > 1 and String(holder.get_child(0).name) == SHADOW_NAME) else 0
	holder.move_child(g, below)

# Take the GRAB glow halo off (GrabFx.release). Detaches synchronously so it's gone the instant the tile
# drops. Null-safe + idempotent.
static func clear_grab_glow(holder: Control) -> void:
	if holder == null or not is_instance_valid(holder):
		return
	var g := holder.get_node_or_null(NodePath(GRAB_GLOW_NAME))
	if g != null:
		holder.remove_child(g)
		g.queue_free()

# Take the GRAB outline rim off (GrabFx.release). Null-safe + idempotent (safe if none was added).
# Detaches synchronously (remove_child) so the rim is gone the instant the tile drops — not a frame
# later — then frees it; a deferred queue_free alone would leave the rim up for one more frame.
static func clear_grab_outline(holder: Control) -> void:
	if holder == null or not is_instance_valid(holder):
		return
	var o := holder.get_node_or_null(NodePath(GRAB_OUTLINE_NAME))
	if o != null:
		holder.remove_child(o)
		o.queue_free()

# (3/3) A few slow code-drawn twinkles over the icon. GenSparkle is a self-animating Control (see its
# header for why not particles). mouse_filter is set here too — _all_ignore can run before its _ready().
static func _add_gen_sparkle(holder: Control, size: float, hl: Dictionary = {}) -> void:
	var sp := GenSparkle.new()
	sp.name = "GenSparkle"
	sp.set_anchors_preset(Control.PRESET_FULL_RECT)
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sp.tint = _highlight_color(hl.get("sparkle_color", GEN_SPARKLE["color"]), GEN_SPARKLE["color"])
	sp.count = int(hl.get("sparkle_count", GEN_SPARKLE["count"]))
	sp.size_mult = float(hl.get("sparkle_size", GEN_SPARKLE["size"]))
	sp.speed = float(hl.get("sparkle_speed", GEN_SPARKLE["speed"]))
	holder.add_child(sp)

