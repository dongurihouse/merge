extends SceneTree
## Dev tool: split a UI sheet that was exported on a baked CHECKERBOARD (no real alpha) into
## one trimmed, alpha-knocked-out PNG per piece. Robust to irregular, non-grid placement.
##
##   godot --headless --path . -s res://games/tools/slice_islands.gd -- \
##       <input.png> <out_prefix> [val_min=0.90] [sat_max=0.10] [min_area=600] [pad=3]
##
## 1) Flood-fill the background inward from the image border over "bright + achromatic" pixels
##    (the checkerboard). Enclosed light interiors of a piece are NOT reached, so they survive.
## 2) Connected-components (8-conn) over the remaining foreground → one island per piece.
## 3) Crop each island's bbox from the ORIGINAL (soft edges kept) and set alpha: background→0.
## Prints "n -> x,y wxh (px=count)" sorted top→bottom, left→right so islands map to names.

const VAL_MIN := 0.90
const SAT_MAX := 0.10
const MIN_AREA := 600
const PAD := 3

var _data: PackedByteArray
var _W := 0
var _vmin8 := 0
var _smax := 0.0

func _is_bglike(i: int) -> bool:
	var o := i * 4
	var r := _data[o]
	var g := _data[o + 1]
	var b := _data[o + 2]
	var mx := maxi(r, maxi(g, b))
	if mx < _vmin8:
		return false
	var mn := mini(r, mini(g, b))
	var sat := 0.0 if mx == 0 else float(mx - mn) / float(mx)
	return sat <= _smax

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 2:
		print("usage: slice_islands <input.png> <out_prefix> [val_min] [sat_max] [min_area] [pad]")
		quit(1); return
	var src: String = a[0]
	var pref: String = a[1]
	var vmin: float = (float(a[2]) if a.size() > 2 else VAL_MIN)
	_smax = (float(a[3]) if a.size() > 3 else SAT_MAX)
	var min_area: int = (int(a[4]) if a.size() > 4 else MIN_AREA)
	var pad: int = (int(a[5]) if a.size() > 5 else PAD)
	var img := Image.load_from_file(src)
	if img == null:
		print("FAIL: cannot load ", src); quit(1); return
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	_W = img.get_width()
	var H := img.get_height()
	_data = img.get_data()
	_vmin8 = int(vmin * 255.0)
	var n := _W * H

	# 1) flood the checkerboard inward from the border (4-conn, won't slip past piece corners)
	var bg := PackedByteArray(); bg.resize(n)        # 0 = fg, 1 = background
	var q := PackedInt32Array()
	for x in _W:
		_seed(x, bg, q)
		_seed((H - 1) * _W + x, bg, q)
	for y in H:
		_seed(y * _W, bg, q)
		_seed(y * _W + (_W - 1), bg, q)
	while not q.is_empty():
		var p := q[q.size() - 1]
		q.remove_at(q.size() - 1)
		var px := p % _W
		var py := p / _W
		if px > 0: _try(p - 1, bg, q)
		if px < _W - 1: _try(p + 1, bg, q)
		if py > 0: _try(p - _W, bg, q)
		if py < H - 1: _try(p + _W, bg, q)

	# 2) connected-components over the foreground (8-conn)
	var label := PackedInt32Array(); label.resize(n); label.fill(-1)
	var islands: Array = []
	var stack := PackedInt32Array()
	for start in n:
		if bg[start] == 1 or label[start] != -1:
			continue
		var id := islands.size()
		var x0 := _W; var y0 := H; var x1 := -1; var y1 := -1; var cnt := 0
		stack.clear(); stack.push_back(start); label[start] = id
		while not stack.is_empty():
			var p := stack[stack.size() - 1]
			stack.remove_at(stack.size() - 1)
			var px := p % _W
			var py := p / _W
			cnt += 1
			x0 = mini(x0, px); y0 = mini(y0, py); x1 = maxi(x1, px); y1 = maxi(y1, py)
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if dx == 0 and dy == 0:
						continue
					var nx := px + dx
					var ny := py + dy
					if nx < 0 or ny < 0 or nx >= _W or ny >= H:
						continue
					var qq := ny * _W + nx
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
	print("source %dx%d — kept %d of %d islands" % [_W, H, keep.size(), islands.size()])
	for i in keep.size():
		var isl: Dictionary = keep[i]
		var bx0: int = maxi(0, int(isl.x0) - pad)
		var by0: int = maxi(0, int(isl.y0) - pad)
		var bx1: int = mini(_W - 1, int(isl.x1) + pad)
		var by1: int = mini(H - 1, int(isl.y1) + pad)
		var cw := bx1 - bx0 + 1
		var ch := by1 - by0 + 1
		var cell := Image.create(cw, ch, false, Image.FORMAT_RGBA8)
		for yy in ch:
			for xx in cw:
				var sp := (by0 + yy) * _W + (bx0 + xx)
				if bg[sp] == 1:
					cell.set_pixel(xx, yy, Color(0, 0, 0, 0))
				else:
					var o := sp * 4
					cell.set_pixel(xx, yy, Color8(_data[o], _data[o + 1], _data[o + 2], 255))
		cell.save_png("%s%d.png" % [pref, i])
		print("%d -> %d,%d  %dx%d  (px=%d)" % [i, bx0, by0, cw, ch, int(isl.count)])
	quit()

func _seed(p: int, bg: PackedByteArray, q: PackedInt32Array) -> void:
	if bg[p] == 0 and _is_bglike(p):
		bg[p] = 1
		q.push_back(p)

func _try(p: int, bg: PackedByteArray, q: PackedInt32Array) -> void:
	if bg[p] == 0 and _is_bglike(p):
		bg[p] = 1
		q.push_back(p)
