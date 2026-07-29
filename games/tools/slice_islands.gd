extends SceneTree
## Dev tool: split a UI sheet that was exported on a baked CHECKERBOARD (no real alpha) into
## one trimmed, alpha-knocked-out PNG per piece. Robust to irregular, non-grid placement.
##
##   godot --headless --path . -s res://games/tools/slice_islands.gd -- \
##       <input.png> <out_prefix> [val_min=0.90] [sat_max=0.10] [min_area=600] [pad=3]
##
## 1) Flood-fill the background inward from the image border over "bright + achromatic" pixels
##    (the checkerboard). Enclosed light interiors of a piece are NOT reached, so they survive.
## 1b) Also treat any pixel a prior pass already cleared (alpha ~ 0, e.g. chroma_key knocked out
##    an enclosed #FF00FF pocket) as background — even when the border flood can't reach it.
##    Without this, those walled-in holes get re-opaqued in step 3 and the pocket resurrects.
## 2) Connected-components (8-conn) over the remaining foreground → one island per piece.
## 3) Crop each island's bbox from the ORIGINAL (soft edges kept) and set alpha: background→0.
## Prints "n -> x,y wxh (px=count)" sorted top→bottom, left→right so islands map to names.

const ImgOps := preload("res://games/tools/img_ops.gd")

# VAL_MIN / SAT_MAX are this tool's OWN CLI-overridable defaults and are deliberately NOT
# img_ops' BG_MAX_VAL / BG_MAX_SAT: 0.90 is a looser plate threshold for baked checkerboards,
# and every caller may override it per sheet (see the intake plans' `params`).
const VAL_MIN := 0.90
const SAT_MAX := 0.10
const MIN_AREA := 600
const PAD := 3
# The "already cleared (chroma-keyed) → background" floor, shared with the other cutters.
const ALPHA_MIN := ImgOps.ALPHA_MIN   # 8-bit; this tool tests raw bytes, not Color.a

static func _is_bglike(data: PackedByteArray, i: int, vmin8: int, smax: float) -> bool:
	var o := i * 4
	if data[o + 3] < ALPHA_MIN:
		return true                       # already transparent (e.g. chroma-keyed) → background
	var r := data[o]
	var g := data[o + 1]
	var b := data[o + 2]
	var mx := maxi(r, maxi(g, b))
	if mx < vmin8:
		return false
	var mn := mini(r, mini(g, b))
	var sat := 0.0 if mx == 0 else float(mx - mn) / float(mx)
	return sat <= smax

static func _seed_bg(data: PackedByteArray, p: int, vmin8: int, smax: float, bg: PackedByteArray, q: PackedInt32Array) -> void:
	if bg[p] == 0 and _is_bglike(data, p, vmin8, smax):
		bg[p] = 1
		q.push_back(p)

## Split `img` into trimmed, alpha-knocked-out pieces. Returns an Array of
## {"image": Image, "x": int, "y": int, "w": int, "h": int, "count": int} sorted
## top→bottom / left→right. `img` is left unmodified. Shared by the CLI entry point
## and the regression suite so both exercise the same slicing logic.
static func slice_sheet(img: Image, vmin: float, smax: float, min_area: int, pad: int) -> Array:
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	var W := img.get_width()
	var H := img.get_height()
	var data := img.get_data()
	var vmin8 := int(vmin * 255.0)
	var n := W * H

	# 1) flood the checkerboard inward from the border (4-conn, won't slip past piece corners)
	var bg := PackedByteArray(); bg.resize(n)        # 0 = fg, 1 = background
	var q := PackedInt32Array()
	for x in W:
		_seed_bg(data, x, vmin8, smax, bg, q)
		_seed_bg(data, (H - 1) * W + x, vmin8, smax, bg, q)
	for y in H:
		_seed_bg(data, y * W, vmin8, smax, bg, q)
		_seed_bg(data, y * W + (W - 1), vmin8, smax, bg, q)
	while not q.is_empty():
		var p := q[q.size() - 1]
		q.remove_at(q.size() - 1)
		var px := p % W
		var py := p / W
		if px > 0: _seed_bg(data, p - 1, vmin8, smax, bg, q)
		if px < W - 1: _seed_bg(data, p + 1, vmin8, smax, bg, q)
		if py > 0: _seed_bg(data, p - W, vmin8, smax, bg, q)
		if py < H - 1: _seed_bg(data, p + W, vmin8, smax, bg, q)

	# 1b) cut ENCLOSED background a prior pass already cleared: any already-transparent pixel is
	#     background even when the border flood can't reach it (it is walled in by the piece).
	#     This respects the alpha chroma_key wrote, so knockout below never resurrects the pocket.
	for i in n:
		if bg[i] == 0 and data[i * 4 + 3] < ALPHA_MIN:
			bg[i] = 1

	# 2) connected-components over the foreground (8-conn)
	var label := PackedInt32Array(); label.resize(n); label.fill(-1)
	var islands: Array = []
	var stack := PackedInt32Array()
	for start in n:
		if bg[start] == 1 or label[start] != -1:
			continue
		var id := islands.size()
		var x0 := W; var y0 := H; var x1 := -1; var y1 := -1; var cnt := 0
		stack.clear(); stack.push_back(start); label[start] = id
		while not stack.is_empty():
			var p := stack[stack.size() - 1]
			stack.remove_at(stack.size() - 1)
			var px := p % W
			var py := p / W
			cnt += 1
			x0 = mini(x0, px); y0 = mini(y0, py); x1 = maxi(x1, px); y1 = maxi(y1, py)
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if dx == 0 and dy == 0:
						continue
					var nx := px + dx
					var ny := py + dy
					if nx < 0 or ny < 0 or nx >= W or ny >= H:
						continue
					var qq := ny * W + nx
					if bg[qq] == 1 or label[qq] != -1:
						continue
					label[qq] = id
					stack.push_back(qq)
		islands.append({"x0": x0, "y0": y0, "x1": x1, "y1": y1, "count": cnt})

	# 3) keep real pieces, order top→bottom / left→right (banded by 80px rows), crop + knockout
	var keep: Array = []
	for isl in islands:
		if int(isl.count) >= min_area:
			keep.append(isl)
	keep.sort_custom(func(a1: Dictionary, b1: Dictionary) -> bool:
		var ra := int(a1.y0) / 80
		var rb := int(b1.y0) / 80
		if ra != rb:
			return ra < rb
		return int(a1.x0) < int(b1.x0))
	var out: Array = []
	for isl in keep:
		var bx0: int = maxi(0, int(isl.x0) - pad)
		var by0: int = maxi(0, int(isl.y0) - pad)
		var bx1: int = mini(W - 1, int(isl.x1) + pad)
		var by1: int = mini(H - 1, int(isl.y1) + pad)
		var cw := bx1 - bx0 + 1
		var ch := by1 - by0 + 1
		var cell := Image.create(cw, ch, false, Image.FORMAT_RGBA8)
		for yy in ch:
			for xx in cw:
				var sp := (by0 + yy) * W + (bx0 + xx)
				if bg[sp] == 1:
					cell.set_pixel(xx, yy, Color(0, 0, 0, 0))
				else:
					# KEEP the source alpha. On the checkerboard sheets this tool was written for
					# every foreground pixel is already 255, so this is a no-op there — but on a
					# sheet a keyer has already run over, forcing 255 would throw away the guide's
					# §8 soft alpha ramp and promote every half-keyed boundary pixel to a FULLY
					# OPAQUE key-coloured one. Measured on the nav glyph sheet: 113 tinted px on
					# the keyed sheet became 205 opaque ones across the slices, which the icon
					# resize then smeared into a 1251 px magenta rim.
					var o := sp * 4
					cell.set_pixel(xx, yy, Color8(data[o], data[o + 1], data[o + 2], data[o + 3]))
		out.append({"image": cell, "x": bx0, "y": by0, "w": cw, "h": ch, "count": int(isl.count)})
	return out

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 2:
		print("usage: slice_islands <input.png> <out_prefix> [val_min] [sat_max] [min_area] [pad]")
		quit(1); return
	var src: String = a[0]
	var pref: String = a[1]
	var vmin: float = (float(a[2]) if a.size() > 2 else VAL_MIN)
	var smax: float = (float(a[3]) if a.size() > 3 else SAT_MAX)
	var min_area: int = (int(a[4]) if a.size() > 4 else MIN_AREA)
	var pad: int = (int(a[5]) if a.size() > 5 else PAD)
	var img := Image.load_from_file(src)
	if img == null:
		print("FAIL: cannot load ", src); quit(1); return
	var pieces := slice_sheet(img, vmin, smax, min_area, pad)
	print("source %dx%d — kept %d islands" % [img.get_width(), img.get_height(), pieces.size()])
	for i in pieces.size():
		var pc: Dictionary = pieces[i]
		(pc.image as Image).save_png("%s%d.png" % [pref, i])
		print("%d -> %d,%d  %dx%d  (px=%d)" % [i, int(pc.x), int(pc.y), int(pc.w), int(pc.h), int(pc.count)])
	quit()
