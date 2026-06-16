extends SceneTree
## Process a horizontal LINE strip (N tiers in a row on a baked transparency checkerboard) into N
## clean transparent item sprites that KEEP their size progression + share a baseline.
##   godot --headless --path . -s res://games/tools/proc_line.gd -- <src.png> <n> <out_dir_abs> <base> [montage_abs]
## -> <out_dir>/<base>_1.png .. _N.png (SIZE²), and optionally a magenta review montage.
##
## Per tier: flood the achromatic-bright checker from the borders + punch enclosed checker pockets
## → transparent; find the object bbox. Then ALL objects scale by ONE global factor (largest fills
## FRAME_FILL of the frame), each h-centered + bottom-anchored → the line steps in size and sits on
## one ground line, exactly as drawn.

const SIZE := 512
const FRAME_FILL := 0.92
const BASE_MARGIN := 0.05          # gap below the baseline (fraction of SIZE)
const CHK_VAL := 0.74              # checker: value above this ...
const CHK_SAT := 0.14              # ... and saturation below this = background
const ALPHA_MIN := 8
const AREA_MIN := 28               # enclosed bg pockets >= this are punched; smaller = highlight
const NEI := [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]

func _is_bg(c: Color) -> bool:
	if c.a * 255.0 < ALPHA_MIN:
		return true
	var mx: float = maxf(c.r, maxf(c.g, c.b))
	var mn: float = minf(c.r, minf(c.g, c.b))
	var sat: float = 0.0 if mx <= 0.0 else (mx - mn) / mx
	return mx > CHK_VAL and sat < CHK_SAT

func _clear_bg(img: Image) -> void:
	var w := img.get_width(); var h := img.get_height()
	var outer := PackedByteArray(); outer.resize(w * h)
	var st := PackedInt32Array()
	for x in w:
		_seed(img, outer, st, x, 0, w, h); _seed(img, outer, st, x, h - 1, w, h)
	for y in h:
		_seed(img, outer, st, 0, y, w, h); _seed(img, outer, st, w - 1, y, w, h)
	while not st.is_empty():
		var idx := st[st.size() - 1]; st.remove_at(st.size() - 1)
		var cx := idx % w; var cy := idx / w
		for d in NEI: _seed(img, outer, st, cx + d.x, cy + d.y, w, h)
	# clear outer field
	for i in w * h:
		if outer[i] == 1:
			var c := img.get_pixel(i % w, i / w); c.a = 0.0; img.set_pixel(i % w, i / w, c)
	# punch enclosed checker pockets
	var seen := PackedByteArray(); seen.resize(w * h)
	for y in h:
		for x in w:
			var i0 := y * w + x
			if outer[i0] == 1 or seen[i0] == 1 or not _is_bg(img.get_pixel(x, y)):
				continue
			var comp := PackedInt32Array(); var q := PackedInt32Array([i0]); seen[i0] = 1
			while not q.is_empty():
				var j := q[q.size() - 1]; q.remove_at(q.size() - 1); comp.append(j)
				var jx := j % w; var jy := j / w
				for d in NEI:
					var nx: int = jx + int(d.x)
					var ny: int = jy + int(d.y)
					if nx < 0 or ny < 0 or nx >= w or ny >= h: continue
					var ni: int = ny * w + nx
					if seen[ni] == 1 or outer[ni] == 1: continue
					if _is_bg(img.get_pixel(nx, ny)): seen[ni] = 1; q.append(ni)
			if comp.size() < AREA_MIN: continue
			for j in comp:
				var c := img.get_pixel(j % w, j / w); c.a = 0.0; img.set_pixel(j % w, j / w, c)

func _seed(img: Image, outer: PackedByteArray, st: PackedInt32Array, x: int, y: int, w: int, h: int) -> void:
	if x < 0 or y < 0 or x >= w or y >= h: return
	var i := y * w + x
	if outer[i] == 1 or not _is_bg(img.get_pixel(x, y)): return
	outer[i] = 1; st.append(i)

func _bbox(img: Image) -> Rect2i:
	var w := img.get_width(); var h := img.get_height()
	var a := w; var b := h; var c := -1; var d := -1
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a > 0.04:
				a = mini(a, x); c = maxi(c, x); b = mini(b, y); d = maxi(d, y)
	return Rect2i(0,0,w,h) if c < 0 else Rect2i(a, b, c - a + 1, d - b + 1)

func _runs_v(img: Image, w: int, h: int, gap: int, minrun: int) -> Array:
	# vertical scan → content ROW bands [y0,y1)
	var out: Array = []
	var inr := false; var s := 0
	for y in h:
		var cnt := 0
		for x in w:
			if img.get_pixel(x, y).a > 0.04: cnt += 1
		if cnt >= gap and not inr: inr = true; s = y
		elif cnt < gap and inr:
			inr = false
			if y - s >= minrun: out.append(Vector2i(s, y))
	if inr and h - s >= minrun: out.append(Vector2i(s, h))
	return out

func _runs_h(img: Image, w: int, y0: int, y1: int, gap: int, minrun: int) -> Array:
	# horizontal scan within rows [y0,y1) → content COLUMN runs [x0,x1)
	var out: Array = []
	var inr := false; var s := 0
	for x in w:
		var cnt := 0
		for y in range(y0, y1):
			if img.get_pixel(x, y).a > 0.04: cnt += 1
		if cnt >= gap and not inr: inr = true; s = x
		elif cnt < gap and inr:
			inr = false
			if x - s >= minrun: out.append(Vector2i(s, x))
	if inr and w - s >= minrun: out.append(Vector2i(s, w))
	return out

func _initialize() -> void:
	var ar := OS.get_cmdline_user_args()
	if ar.size() < 4:
		print("usage: proc_line.gd -- <src> <n> <out_dir_abs> <base> [montage_abs]"); quit(2); return
	var src := String(ar[0]); var n := int(ar[1]); var out_dir := String(ar[2]); var base := String(ar[3])
	var montage := String(ar[4]) if ar.size() >= 5 else ""
	var img := Image.load_from_file(src)
	if img == null: print("FAIL load ", src); quit(1); return
	img.convert(Image.FORMAT_RGBA8)
	_clear_bg(img)                 # clear the checker on the WHOLE image first
	var W := img.get_width(); var H := img.get_height()
	# Segmentation. The optional 6th arg is EITHER a gap threshold (int) OR a fixed grid "RxC"
	# (equal cells — for evenly-placed objects that TOUCH, where gap-detection can't separate them).
	var arg6 := String(ar[5]) if ar.size() >= 6 else ""
	var crops: Array = []          # {img, bbox} — reading order (row-major)
	var maxdim := 1
	if "x" in arg6:
		var rc := arg6.split("x")
		var rows := int(rc[0]); var cols := int(rc[1])
		for r in rows:
			var y0 := int(round(float(r) * H / rows)); var y1 := int(round(float(r + 1) * H / rows))
			for c2 in cols:
				var x0 := int(round(float(c2) * W / cols)); var x1 := int(round(float(c2 + 1) * W / cols))
				var seg := Image.create(x1 - x0, y1 - y0, false, Image.FORMAT_RGBA8)
				seg.blit_rect(img, Rect2i(x0, y0, x1 - x0, y1 - y0), Vector2i.ZERO)
				var bb := _bbox(seg)
				crops.append({"img": seg, "bb": bb})
				maxdim = maxi(maxdim, maxi(bb.size.x, bb.size.y))
		print("fixed grid %dx%d → %d cells (expected %d)" % [rows, cols, crops.size(), n])
	else:
		var GAP_PX := int(arg6) if arg6 != "" else 8
		var MIN_RUN := 16
		var bands := _runs_v(img, W, H, GAP_PX, MIN_RUN)
		for b in bands:
			var by0: int = b.x; var bh: int = b.y - b.x
			for c in _runs_h(img, W, b.x, b.y, GAP_PX, MIN_RUN):
				var cw: int = c.y - c.x
				var seg := Image.create(cw, bh, false, Image.FORMAT_RGBA8)
				seg.blit_rect(img, Rect2i(c.x, by0, cw, bh), Vector2i.ZERO)
				var bb := _bbox(seg)
				crops.append({"img": seg, "bb": bb})
				maxdim = maxi(maxdim, maxi(bb.size.x, bb.size.y))
		print("segmented %d objects in %d rows (expected %d)" % [crops.size(), bands.size(), n])
	n = crops.size()
	# ICON mode (last arg "icon"): each cell normalized to fill its own frame + CENTERED — UI glyphs
	# read at one size. Default (items/objects): ONE global scale (keeps the size progression) +
	# BOTTOM-anchored (sit on a common baseline).
	var icon_mode := ar.size() >= 7 and String(ar[6]) == "icon"
	var gscale := float(SIZE) * FRAME_FILL / float(maxdim)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var frames: Array = []
	for i in n:
		var bb: Rect2i = crops[i].bb
		var obj := Image.create(bb.size.x, bb.size.y, false, Image.FORMAT_RGBA8)
		obj.blit_rect(crops[i].img, bb, Vector2i.ZERO)
		var scale: float = (float(SIZE) * FRAME_FILL / float(maxi(bb.size.x, bb.size.y))) if icon_mode else gscale
		var nw := maxi(1, int(round(bb.size.x * scale))); var nh := maxi(1, int(round(bb.size.y * scale)))
		obj.resize(nw, nh, Image.INTERPOLATE_LANCZOS)
		var frame := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
		frame.fill(Color(0, 0, 0, 0))
		var px := (SIZE - nw) / 2
		var py := (SIZE - nh) / 2 if icon_mode else SIZE - int(round(SIZE * BASE_MARGIN)) - nh
		frame.blend_rect(obj, Rect2i(0, 0, nw, nh), Vector2i(px, maxi(0, py)))
		frame.save_png("%s/%s_%d.png" % [out_dir, base, i + 1])
		frames.append(frame)
	print("WROTE %d sprites to %s/%s_*.png (gscale=%.3f, maxdim=%d, icon=%s)" % [n, out_dir, base, gscale, maxdim, str(icon_mode)])
	if montage != "":
		var gap := 8
		var mw := n * SIZE + (n + 1) * gap
		var canvas := Image.create(mw, SIZE + 2 * gap, false, Image.FORMAT_RGBA8)
		canvas.fill(Color(1, 0, 1, 1))
		for i in n:
			canvas.blend_rect(frames[i], Rect2i(0, 0, SIZE, SIZE), Vector2i(gap + i * (SIZE + gap), gap))
		canvas.save_png(montage)
		print("MONTAGE ", montage)
	quit()
