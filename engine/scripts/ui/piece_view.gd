extends RefCounted
## The board's visual VOCABULARY — the builders that turn a code / cell / generator id into a
## Control: items (real art, coins, or a tier disc), the garden-bed mat, sealed brambles, and
## generators. Pure view builders: inputs in (code, size, cell, csz, board dims), a Control out —
## no scene/instance state. The scene owns placement + state; this owns how a thing looks.
## Layering: ui/ may import core/ + ui/, never scenes/ — see docs/design/merge_spec.md §15.

const G = preload("res://engine/scripts/core/content.gd")
const BoardModel = preload("res://engine/scripts/core/board_model.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const Look = preload("res://engine/scripts/ui/skin.gd")
const Features = preload("res://engine/scripts/core/features.gd")
const Pal = Game.PALETTE

const CREAM = Pal.CREAM
const STRAW = Pal.STRAW
const GROUND_EDGE = Pal.GROUND_EDGE
const BRAMBLE_BG = Pal.BRAMBLE_BG
const BRAMBLE_EDGE = Pal.BRAMBLE_EDGE

const BRAMBLE_WARM_SHADER := "
shader_type canvas_item;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 moss = vec3(0.40, 0.32, 0.18);
	vec3 outc = min(moss + c.rgb * vec3(1.25, 1.10, 0.80), vec3(0.92));
	COLOR = vec4(outc, c.a) * COLOR;
}"
static var _bramble_material: ShaderMaterial
static func bramble_mat() -> ShaderMaterial:
	if _bramble_material == null:
		var sh := Shader.new()
		sh.code = BRAMBLE_WARM_SHADER
		_bramble_material = ShaderMaterial.new()
		_bramble_material.shader = sh
	return _bramble_material

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

static func make_piece(code: int, size: float) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(size, size)
	holder.size = Vector2(size, size)
	holder.pivot_offset = Vector2(size, size) / 2.0
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# AF3: a soft warm CONTACT SHADOW under the item (first child = bottom) — tight
	# and LOW (it grounds the piece on the light mat), not the old centered dark
	# ellipse that vanished on a light surface. Warm-grey, ~28% alpha, never eats input.
	if Features.on("item_backing"):
		var back := TextureRect.new()
		back.texture = backing_tex()
		var bw := size * 0.62
		var bh := size * 0.22
		back.position = Vector2((size - bw) / 2.0, size * 0.70)   # low — a contact shadow
		back.size = Vector2(bw, bh)
		back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		back.stretch_mode = TextureRect.STRETCH_SCALE
		back.modulate = Color("#3E342A", 0.30)                    # warm-grey, soft
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(back)
	var path := G.item_tex_path(code)
	if ResourceLoader.exists(path):
		var t := TextureRect.new()
		t.texture = load(path)
		t.set_anchors_preset(Control.PRESET_FULL_RECT)
		var inset := size * 0.06
		t.offset_left = inset
		t.offset_top = inset
		t.offset_right = -inset
		t.offset_bottom = -inset
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(t)
		return holder
	# coins: a gold disc with its value (tap to pocket)
	if G.is_coin(code):
		var cdisc := Panel.new()
		var cd := size * (0.5 + 0.1 * BoardModel.tier_of(code))
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
		var clbl := Label.new()
		clbl.text = str(G.coin_value(code))
		clbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		clbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		clbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		clbl.add_theme_font_size_override("font_size", int(size * 0.26))
		clbl.add_theme_color_override("font_color", Color("#6B4A12"))
		clbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(clbl)
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

# Rounded-corner mask in PIXELS (owner: rounded corners + pop are back; the
# previous UV feather read as a flat square). Soft 8px melt at the rim only.
const MAT_MASK_SHADER := "
shader_type canvas_item;
uniform vec2 rect_size = vec2(1080.0, 1400.0);
uniform float radius_px = 28.0;
uniform float feather_px = 8.0;
void fragment() {
	vec2 p = (UV - vec2(0.5)) * rect_size;
	vec2 b = rect_size * 0.5 - vec2(radius_px);
	vec2 q = abs(p) - b;
	float d = length(max(q, vec2(0.0))) - radius_px;
	COLOR = texture(TEXTURE, UV);
	COLOR.a *= 1.0 - smoothstep(-feather_px, 0.0, d);
}"

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
	ps.bg_color = Color("#86603A")                # warm planter wood (ties to the fence)
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
	ls.bg_color = Color("#9C7547", 0.9)           # a sunlit catch on the rim
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
	ss.bg_color = Color("#5E4828", 0.95)          # tilled soil
	ss.set_corner_radius_all(20)
	ss.set_border_width_all(2)
	ss.border_color = Color("#3A2D1E", 0.55)
	ss.shadow_color = Color(0, 0, 0, 0.28)        # a soft inner shade under the rim
	ss.shadow_size = 5
	soil.add_theme_stylebox_override("panel", ss)
	soil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mat.add_child(soil)
	# a mossy grain on the soil, masked to the bed's rounded corners (tactile texture,
	# not a flat fill). Higher alpha than the old see-through wash so it reads as soil.
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = MAT_MASK_SHADER
	sm.shader = sh
	sm.set_shader_parameter("rect_size", soil.size)
	sm.set_shader_parameter("radius_px", 20.0)
	sm.set_shader_parameter("feather_px", 4.0)
	var moss: Texture2D = null
	for pth in [Game.art("ui/tray_grove_tall.png"), Game.art("ui/tray_grove.png")]:
		if ResourceLoader.exists(pth):
			var base: Texture2D = load(pth)
			var at := AtlasTexture.new()
			at.atlas = base
			var sz := Vector2(base.get_size())
			at.region = Rect2(sz * 0.13, sz * 0.74)   # the calm moss interior only
			moss = at
			break
	if moss != null:
		var grain := TextureRect.new()
		grain.texture = moss
		grain.position = soil.position
		grain.size = soil.size
		grain.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		grain.stretch_mode = TextureRect.STRETCH_SCALE
		grain.material = sm
		grain.modulate = Color("#7A5A30", 0.34)   # warm soil-moss tint, woven into the bed
		grain.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mat.add_child(grain)
	return mat


static func make_bramble(cell: Vector2i, csz: float) -> Control:
	var lvl := G.cell_min_level(cell)          # the Level this cell unseals at (§4)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(csz, csz)
	holder.size = Vector2(csz, csz)
	holder.pivot_offset = Vector2(csz, csz) / 2.0
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Art density band → existing bramble_1..3 only (no bramble_-1/_0 — those don't ship).
	# MONOTONIC: higher gate Level = denser thicket. The §4 diamond gates are {1,2,3,5,7,9,11},
	# so map 1-3→1, 5-7→2, 9-11→3 — the FRONTIER cells (Lv1/2/3, nearest the eye) now paint
	# real bramble instead of falling back to a flat debug panel.
	var ring := clampi(lvl / 4 + 1, 1, 3)
	var path := Game.art("ui/bramble_%d.png" % ring)
	if ResourceLoader.exists(path):
		var t := TextureRect.new()
		t.texture = load(path)
		t.set_anchors_preset(Control.PRESET_FULL_RECT)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		# S3/AC: lift the near-black nest toward deep moss-brown (warm-lift shader —
		# a multiply-modulate can't brighten true black; this adds a warm floor)
		t.material = bramble_mat()
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(t)
	else:
		var p := Panel.new()
		p.set_anchors_preset(Control.PRESET_FULL_RECT)
		var sb := StyleBoxFlat.new()
		sb.bg_color = BRAMBLE_BG.darkened(0.06 * (ring + 2))
		sb.set_corner_radius_all(14)
		sb.set_border_width_all(3)
		sb.border_color = BRAMBLE_EDGE
		p.add_theme_stylebox_override("panel", sb)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(p)
	# The Level gate (§4): NO-REQUIRED-READING — a lock glyph carries "sealed"; a small styled
	# badge carries the number only where it earns its keep. To keep the board CALM we show the
	# "Lv N" chip on the FRONTIER (the shallow inner gates the player is about to reach) and a
	# bare lock glyph (no number) on the deeper rings — so ~30 locked cells aren't all text.
	var on_frontier := lvl <= FRONTIER_LV   # the inner L1/2/3 diamond — nearest the player's eye
	holder.add_child(_lv_gate_badge(lvl, csz, on_frontier))
	return holder

const FRONTIER_LV := 3   # gate levels ≤ this are the inner frontier (show the styled number)

# A high-contrast cream-on-bark gate chip: a small rounded sticker with a lock glyph, and the
# Level number only on the FRONTIER (deeper cells get the lock alone). Reads at cell size on
# the dark bramble; replaces the old low-contrast outlined Label stamped on every cell.
#
# The lock glyph: where the lock ART is missing, Look.icon("lock") falls back to the literal
# text "Lv" (skin.gd ICON_GLYPHS) — so "Lv" + an "Lv%d" label would double to "LvLv3". We
# detect the fallback and let the glyph itself supply the "Lv" prefix, pairing it with a bare
# number ("Lv" + "3" → "Lv 3"); with real lock art we prefix the number ("🔒 Lv3"). Either
# way the chip reads as a Level gate, never a bare count.
static func _lv_gate_badge(lvl: int, csz: float, with_num: bool) -> Control:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pad := maxf(3.0, csz * 0.06)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Pal.BARK                     # warm bark/parchment chip
	sb.set_corner_radius_all(int(maxf(6.0, csz * 0.16)))
	sb.set_border_width_all(2)
	sb.border_color = Pal.BARK.darkened(0.28)  # subtle darker rim for definition
	sb.set_content_margin_all(pad)
	sb.shadow_color = Color(Pal.INK, 0.40)     # soft drop shadow grounds the sticker
	sb.shadow_size = int(maxf(2.0, csz * 0.05))
	sb.shadow_offset = Vector2(0, maxf(1.0, csz * 0.025))
	chip.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", int(maxf(2.0, csz * 0.05)))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glyph := Look.icon("lock", csz * (0.26 if with_num else 0.32))
	var glyph_is_text := glyph is Label   # art missing → glyph fallback already prints "Lv"
	if glyph is Label:
		# tint the fallback glyph to match the cream-on-bark chip (skin tints it CREAM already,
		# but force it so it reads against the bark even if the kit theme differs)
		glyph.add_theme_color_override("font_color", CREAM)
	row.add_child(glyph)
	if with_num:
		var bnum := Label.new()
		# bare digits when the glyph already says "Lv"; "Lv%d" when a real lock icon precedes it
		bnum.text = str(lvl) if glyph_is_text else (TranslationServer.translate("Lv%d") % lvl)
		bnum.add_theme_font_size_override("font_size", int(csz * 0.26))
		bnum.add_theme_color_override("font_color", CREAM)      # cream on bark — high contrast, no outline needed
		bnum.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		bnum.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(bnum)
	chip.add_child(row)
	center.add_child(chip)
	return center

static func make_generator(id: String, csz: float) -> Control:
	var gdef: Dictionary = G.gen_def(G.GENERATORS, id)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(csz, csz)
	holder.size = Vector2(csz, csz)
	holder.pivot_offset = Vector2(csz, csz) / 2.0
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var path: String = Game.art(String(gdef.get("tex", "")))
	if ResourceLoader.exists(path):
		var t := TextureRect.new()
		t.texture = load(path)
		t.set_anchors_preset(Control.PRESET_FULL_RECT)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(t)
		return holder
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
	return holder

# A small fixed-box item sprite (for giver ask-cards / the discovery ladder).
static func mini_item(code: int) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(52, 52)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var n := make_piece(code, 52.0)
	holder.add_child(n)
	return holder
