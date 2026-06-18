extends SceneTree
## Dev tool: slice an LLM icon-sheet into individual cell PNGs by DETECTING the icon
## bands (not a uniform grid) — robust to uneven spacing and neighbour art that bleeds
## across a uniform boundary. Pair with process_icon.gd to finish each cell.
##
##   godot --headless --path . -s res://games/tools/slice_grid.gd -- <input.png> <out_prefix>
##
## Projects non-background pixels onto each axis, finds the content bands (icons sit in
## them, cream gaps separate them), and crops each band-intersection. Cells are written
## row-major as <out_prefix><n>.png.

const BG_MAX_VAL := 0.93       # bright + achromatic => background (matches process_icon)
const BG_MAX_SAT := 0.10
const PAD := 10                # px kept around each detected band
const MIN_BAND := 24           # drop content bands thinner than this (noise / specks)
const MERGE_GAP := 24          # merge two bands separated by a gap smaller than this

func _is_bg(c: Color) -> bool:
	if c.a < 0.05:
		return true
	var mx: float = maxf(c.r, maxf(c.g, c.b))
	var mn: float = minf(c.r, minf(c.g, c.b))
	var sat: float = 0.0 if mx <= 0.0 else (mx - mn) / mx
	return mx > BG_MAX_VAL and sat < BG_MAX_SAT

func _bands(counts: PackedInt32Array, thresh: int) -> Array:
	var raw: Array = []
	var in_b := false
	var start := 0
	for i in counts.size():
		if counts[i] > thresh:
			if not in_b:
				in_b = true
				start = i
		elif in_b:
			in_b = false
			raw.append(Vector2i(start, i - 1))
	if in_b:
		raw.append(Vector2i(start, counts.size() - 1))
	var merged: Array = []
	for b in raw:
		if not merged.is_empty() and b.x - (merged[merged.size() - 1] as Vector2i).y <= MERGE_GAP:
			merged[merged.size() - 1] = Vector2i((merged[merged.size() - 1] as Vector2i).x, b.y)
		else:
			merged.append(b)
	var out: Array = []
	for b in merged:
		if (b as Vector2i).y - (b as Vector2i).x + 1 >= MIN_BAND:
			out.append(b)
	return out

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 2:
		print("usage: slice_grid <input.png> <out_prefix>")
		quit(1); return
	var src: String = a[0]
	var pref: String = a[1]
	var img := Image.load_from_file(src)
	if img == null:
		print("FAIL: cannot load ", src); quit(1); return
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	var W := img.get_width()
	var H := img.get_height()
	var colc := PackedInt32Array(); colc.resize(W)
	var rowc := PackedInt32Array(); rowc.resize(H)
	for y in H:
		for x in W:
			if not _is_bg(img.get_pixel(x, y)):
				colc[x] += 1
				rowc[y] += 1
	var colbands := _bands(colc, int(H * 0.02))
	var rowbands := _bands(rowc, int(W * 0.02))
	print("detected cols=%d rows=%d" % [colbands.size(), rowbands.size()])
	var n := 0
	for rb in rowbands:
		for cb in colbands:
			var x0: int = maxi(0, (cb as Vector2i).x - PAD)
			var y0: int = maxi(0, (rb as Vector2i).x - PAD)
			var x1: int = mini(W - 1, (cb as Vector2i).y + PAD)
			var y1: int = mini(H - 1, (rb as Vector2i).y + PAD)
			var cw := x1 - x0 + 1
			var ch := y1 - y0 + 1
			var cell := Image.create(cw, ch, false, Image.FORMAT_RGBA8)
			cell.blit_rect(img, Rect2i(x0, y0, cw, ch), Vector2i.ZERO)
			cell.save_png("%s%d.png" % [pref, n])
			print("cell %d -> %s%d.png (%dx%d)" % [n, pref, n, cw, ch])
			n += 1
	quit()
