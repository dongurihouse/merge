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
const Pal = Game.PALETTE

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
		t.texture = _content_tex(path)   # cropped to opaque content so it CENTERS in the cell (art padding varies)
		t.set_anchors_preset(Control.PRESET_FULL_RECT)
		var inset := size * 0.12
		t.offset_left = inset
		t.offset_top = inset
		t.offset_right = -inset
		t.offset_bottom = -inset
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(t)
		return holder
	# coins: painted acorn art by tier (tap to pocket). Tier alone reads the value —
	# no numeral is drawn over the sprite. Falls back to the code-drawn gold disc when
	# the tier sprite is absent.
	if G.is_coin(code):
		var ctier := BoardModel.tier_of(code)
		var cpath := Game.art("ui/kit/icon_coin_t%d.png" % ctier)
		if cpath != "" and ResourceLoader.exists(cpath):
			var ct := TextureRect.new()
			ct.texture = _content_tex(cpath)
			ct.set_anchors_preset(Control.PRESET_FULL_RECT)
			var cinset := size * 0.06
			ct.offset_left = cinset
			ct.offset_top = cinset
			ct.offset_right = -cinset
			ct.offset_bottom = -cinset
			ct.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ct.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			ct.mouse_filter = Control.MOUSE_FILTER_IGNORE
			holder.add_child(ct)
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
		grain.modulate = Color("#CDBB90", 0.14)   # barely-there warm grain on the light bed (was a dark muddy wash)
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
	# UI redesign: a locked cell is a LIGHT, recessive Sunk well (Pal.LOCKED) with a quiet lock
	# glyph — NOT a dark thicket. The old painted bramble overlay + dark cream-on-bark badge dragged
	# the whole board dark (most cells start locked); locks now recede by being LIGHT. The density
	# band only shades deeper rings a hair, for a faint sense of depth.
	var ring := clampi(lvl / 4 + 1, 1, 3)
	var tile := Panel.new()
	tile.set_anchors_preset(Control.PRESET_FULL_RECT)
	tile.add_theme_stylebox_override("panel", _locked_style(csz, ring))
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# RECEDE: locked cells should read as "not yet", not a wall of bold padlocks — fade them
	# back (deeper rings fade a little more) so the eye lands on the live, playable cells.
	tile.modulate = Color(1.0, 1.0, 1.0, 0.66 - 0.06 * float(ring - 1))
	holder.add_child(tile)
	# The Level gate (§4): NO-REQUIRED-READING — a lock glyph carries "sealed"; a small styled
	# badge carries the number only where it earns its keep. To keep the board CALM we show the
	# "Lv N" chip on the FRONTIER (the shallow inner gates the player is about to reach) and a
	# bare lock glyph (no number) on the deeper rings — so ~30 locked cells aren't all text.
	var on_frontier := lvl <= FRONTIER_LV   # the inner L1/2/3 diamond — nearest the player's eye
	if ResourceLoader.exists(_locked_art()):
		# the painted tile already carries the padlock — add ONLY the frontier "Lv N" number
		# (tucked at the bottom) so the teach-signal survives without a second, code-drawn lock.
		if on_frontier:
			holder.add_child(_lv_num_badge(lvl, csz))
	else:
		holder.add_child(_lv_gate_badge(lvl, csz, on_frontier))
	return holder

# The "Lv N" teach-number for a FRONTIER locked cell — centered INSIDE the tile (over the faint
# padlock), bold INK with a light outline so it reads on the receded cell.
static func _lv_num_badge(lvl: int, csz: float) -> Control:
	var bnum := Label.new()
	bnum.set_anchors_preset(Control.PRESET_FULL_RECT)
	bnum.text = TranslationServer.translate("Lv%d") % lvl
	bnum.add_theme_font_size_override("font_size", int(maxf(13.0, csz * 0.26)))
	bnum.add_theme_color_override("font_color", Pal.INK)
	bnum.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.85))
	bnum.add_theme_constant_override("outline_size", 5)
	bnum.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bnum.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bnum.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bnum

const FRONTIER_LV := 3   # gate levels ≤ this are the inner frontier (show the styled number)

## The board art kit's painted locked-slot tile (cream + a wood padlock); "" when absent.
static func _locked_art() -> String:
	return Game.art("ui/kit/slot_locked.png")

# The locked/sealed cell well. With the board art kit present this IS the painted slot_locked
# tile (cream + baked padlock) so locked cells read warm, matching the open slots + frame.
# Fallback (no art): a LIGHT recessive Sunk surface (Pal.LOCKED) with a quiet rim, deeper rings
# barely shaded for depth. Static so it stays unit-testable.
static func _locked_style(csz: float, ring: int = 1) -> StyleBox:
	var p := _locked_art()
	if ResourceLoader.exists(p):
		var sbt := StyleBoxTexture.new()
		sbt.texture = load(p)
		sbt.set_texture_margin_all(28.0)                          # ~180px source corners → crisp at cell size
		sbt.modulate_color = Color(1, 1, 1).darkened(0.05 * float(ring - 1))   # deeper rings recede a hair
		return sbt
	var sb := StyleBoxFlat.new()
	sb.bg_color = Pal.LOCKED.darkened(0.018 * float(ring - 1))   # ring 1 == Pal.LOCKED exactly
	sb.set_corner_radius_all(int(maxf(10.0, csz * 0.18)))
	sb.set_border_width_all(2)
	sb.border_color = Color(Pal.LOCKED_GLYPH, 0.30)              # quiet recessive rim
	sb.shadow_color = Color(0, 0, 0, 0)                          # Sunk plane — floats nothing
	sb.shadow_size = 0
	return sb

# A QUIET level-gate mark (UI redesign): a small low-contrast code-drawn padlock in LOCKED_GLYPH,
# with the "Lv N" number — muted ink, NO chip — only on the FRONTIER (deeper cells get the bare
# lock). No dark cream-on-bark sticker: the lock must RECEDE on the light Sunk cell, not shout.
# A code-drawn glyph (not the painterly kit icon) keeps ~30 locked cells whisper-quiet.
static func _lv_gate_badge(lvl: int, csz: float, with_num: bool) -> Control:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", int(maxf(1.0, csz * 0.02)))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gpx := csz * (0.30 if with_num else 0.34)
	var glyph := _LockGlyph.new()
	glyph.body_col = Pal.LOCKED_GLYPH                       # whisper-quiet, recedes
	glyph.key_col = Pal.LOCKED_GLYPH.darkened(0.22)
	glyph.custom_minimum_size = Vector2(gpx, gpx)
	box.add_child(glyph)
	if with_num:
		var bnum := Label.new()
		bnum.text = TranslationServer.translate("Lv%d") % lvl
		bnum.add_theme_font_size_override("font_size", int(maxf(11.0, csz * 0.20)))
		bnum.add_theme_color_override("font_color", Pal.INK_MUTED)   # muted ink, no chip
		bnum.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bnum.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		bnum.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(bnum)
	center.add_child(box)
	return center

# A tiny painted padlock (shackle arc + rounded body + keyhole) — the bulletproof fallback so a
# missing kit icon never prints "Lv" on a locked cell.
class _LockGlyph extends Control:
	var body_col: Color = Color(1, 1, 1)
	var key_col: Color = Color(0, 0, 0, 0.5)
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)
	func _draw() -> void:
		var u := minf(size.x, size.y)
		if u <= 0.0:
			return
		var cx := size.x * 0.5
		var by := size.y * 0.5 - u * 0.04          # body top edge
		draw_arc(Vector2(cx, by), u * 0.20, PI, TAU, 24, body_col, maxf(2.0, u * 0.11), true)  # shackle
		var bw := u * 0.60
		var bh := u * 0.46
		var sb := StyleBoxFlat.new()
		sb.bg_color = body_col
		sb.set_corner_radius_all(int(maxf(2.0, u * 0.12)))
		draw_style_box(sb, Rect2(cx - bw * 0.5, by, bw, bh))   # body
		draw_circle(Vector2(cx, by + bh * 0.45), maxf(1.0, u * 0.07), key_col)   # keyhole

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
