extends SceneTree
## Throwaway: slice a uniform cols×rows item sheet baked on a CHECKERBOARD into <base>_<n>.png (512²),
## row-major (tile 0 = tier 1). Knocks the checker out by a border flood (proc_line's rule
## val>0.74, sat<0.14), then trims + fits each cell to the frame (process_icon style), bottom-anchored.
##   godot --headless --path . -s res://_tmp_grid12.gd -- <src> <cols> <rows> <out_dir> <base>
const SIZE := 512
const FRAME_FILL := 0.90
const BASE_MARGIN := 0.06
const CHK_VAL := 0.74
const CHK_SAT := 0.14
const ALPHA_MIN := 8
const NEI := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

func _is_bg(c: Color) -> bool:
	if c.a * 255.0 < ALPHA_MIN:
		return true
	var mx: float = maxf(c.r, maxf(c.g, c.b))
	var mn: float = minf(c.r, minf(c.g, c.b))
	var sat: float = 0.0 if mx <= 0.0 else (mx - mn) / mx
	return mx > CHK_VAL and sat < CHK_SAT

func _clear_bg(img: Image) -> void:
	var w := img.get_width(); var h := img.get_height()
	var seen := PackedByteArray(); seen.resize(w * h)
	var st := PackedInt32Array()
	var push := func(x: int, y: int) -> void:
		if x < 0 or y < 0 or x >= w or y >= h: return
		var i := y * w + x
		if seen[i] == 1: return
		if not _is_bg(img.get_pixel(x, y)): return
		seen[i] = 1; st.push_back(i)
	for x in w:
		push.call(x, 0); push.call(x, h - 1)
	for y in h:
		push.call(0, y); push.call(w - 1, y)
	while not st.is_empty():
		var idx := st[st.size() - 1]; st.remove_at(st.size() - 1)
		var cx := idx % w; var cy := idx / w
		for d in NEI:
			push.call(cx + d.x, cy + d.y)
	for i in seen.size():
		if seen[i] == 1:
			img.set_pixel(i % w, i / w, Color(0, 0, 0, 0))

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var src: String = a[0]
	var cols := int(a[1]); var rows := int(a[2])
	var outdir: String = a[3]; var base: String = a[4]
	var img := Image.load_from_file(src)
	if img == null:
		print("FAIL load ", src); quit(1); return
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	_clear_bg(img)
	var W := img.get_width(); var H := img.get_height()
	var cw := W / cols; var ch := H / rows
	var n := 0
	for r in rows:
		for c in cols:
			n += 1
			var x0 := c * cw; var y0 := r * ch
			var minx := cw; var miny := ch; var maxx := -1; var maxy := -1
			for yy in ch:
				for xx in cw:
					if img.get_pixel(x0 + xx, y0 + yy).a * 255.0 >= ALPHA_MIN:
						minx = mini(minx, xx); maxx = maxi(maxx, xx)
						miny = mini(miny, yy); maxy = maxi(maxy, yy)
			if maxx < 0:
				print("  tile %d EMPTY" % (n - 1)); continue
			var bw := maxx - minx + 1; var bh := maxy - miny + 1
			var sub := Image.create(bw, bh, false, Image.FORMAT_RGBA8)
			sub.blit_rect(img, Rect2i(x0 + minx, y0 + miny, bw, bh), Vector2i.ZERO)
			var scale: float = float(FRAME_FILL * SIZE) / float(maxi(bw, bh))
			var nw := maxi(1, int(round(float(bw) * scale)))
			var nh := maxi(1, int(round(float(bh) * scale)))
			sub.resize(nw, nh, Image.INTERPOLATE_LANCZOS)
			var canvas := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
			canvas.fill(Color(0, 0, 0, 0))
			var px := int((SIZE - nw) / 2.0)
			var py := maxi(0, int(SIZE * (1.0 - BASE_MARGIN)) - nh)
			canvas.blit_rect(sub, Rect2i(0, 0, nw, nh), Vector2i(px, py))
			canvas.save_png("%s/%s_%d.png" % [outdir, base, n])
			print("  %s_%d  bbox %dx%d -> %dx%d" % [base, n, bw, bh, nw, nh])
	quit()
