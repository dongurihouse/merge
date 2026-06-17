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
	var ring := mini(lvl / 2 - 1, 3)          # art density bands with the §4 level gate
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
	# the lock ghost: the Level this cell unseals at (§4) — a LOCK icon, never the ★ (the gate
	# is the player's Level now, not stars/a produced tier; ★ would misread as a star price).
	# Mirrors the map spot-gate (map.gd: lock icon + number, "Lv %d" text fallback).
	if ResourceLoader.exists(Look.kit("icon_lock.png")):
		var brow := HBoxContainer.new()
		brow.alignment = BoxContainer.ALIGNMENT_CENTER
		brow.set_anchors_preset(Control.PRESET_FULL_RECT)
		brow.add_theme_constant_override("separation", 2)
		brow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		brow.add_child(Look.icon("lock", csz * 0.2))
		var bnum := Label.new()
		bnum.text = TranslationServer.translate("Lv%d") % lvl   # "Lv11" — never a bare number (reads as a Level, not a count)
		bnum.add_theme_font_size_override("font_size", int(csz * 0.26))
		bnum.add_theme_color_override("font_color", Color(CREAM, 0.85))
		bnum.add_theme_color_override("font_outline_color", BRAMBLE_EDGE)
		bnum.add_theme_constant_override("outline_size", 5)
		brow.add_child(bnum)
		holder.add_child(brow)
		return holder
	var badge := Label.new()
	badge.text = TranslationServer.translate("Lv%d") % lvl
	badge.set_anchors_preset(Control.PRESET_FULL_RECT)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", int(csz * 0.26))
	badge.add_theme_color_override("font_color", Color(CREAM, 0.85))
	badge.add_theme_color_override("font_outline_color", BRAMBLE_EDGE)
	badge.add_theme_constant_override("outline_size", 5)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(badge)
	return holder

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
