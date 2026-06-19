extends SceneTree
## Dev tool: slice the level-badge sheet (assets/board/lvls.png — a clean 4×4 grid of
## circular gold frames on transparent bg) into 16 individual PNGs, row-major from the
## plainest ring (badge_00) to the crown+ribbon (badge_15).
##
##   godot --headless --path . -s res://games/tools/slice_badges.gd -- <in.png> <out_dir> [cols rows]
##   (defaults: cols=4 rows=4, out_dir=res://games/grove/assets/ui/lvl)
##
## The sheet is a UNIFORM grid, so cells are cut on float-accurate boundaries. To keep
## every badge at the SAME scale and registration (the ring must be the same size in
## each so the HUD number stays centred), all cells are cropped to ONE shared box: the
## union of every cell's alpha bounding box, plus a small pad. Decorations that extend
## a badge (crown on top, laurel/ribbon at the bottom) widen that shared box for all.

const ALPHA_MIN := 0.08        # a pixel counts as "badge" above this alpha
const PAD := 6                 # px kept around the shared content box

func _globalize(p: String) -> String:
	return ProjectSettings.globalize_path(p) if p.begins_with("res://") else p

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var src := String(a[0]) if a.size() > 0 else "res://games/grove/assets/_originals/board/lvls.png"
	var out_dir := String(a[1]) if a.size() > 1 else "res://games/grove/assets/ui/lvl"
	var cols := int(a[2]) if a.size() > 2 else 4
	var rows := int(a[3]) if a.size() > 3 else 4

	var img := Image.load_from_file(_globalize(src))
	if img == null:
		print("FAIL: cannot load ", src); quit(1); return
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	var W := img.get_width()
	var H := img.get_height()

	# Cell boundaries on float-accurate grid lines (no drift accumulating across columns).
	var xs := PackedInt32Array(); xs.resize(cols + 1)
	for c in cols + 1:
		xs[c] = int(round(c * float(W) / float(cols)))
	var ys := PackedInt32Array(); ys.resize(rows + 1)
	for r in rows + 1:
		ys[r] = int(round(r * float(H) / float(rows)))

	# Pass 1 — per-cell alpha bbox in CELL-LOCAL coords; accumulate the shared box.
	var n := cols * rows
	var boxes: Array = []
	var gx0 := 1 << 30; var gy0 := 1 << 30; var gx1 := -1; var gy1 := -1
	for r in rows:
		for c in cols:
			var cx0 := xs[c]; var cy0 := ys[r]
			var cw := xs[c + 1] - cx0; var ch := ys[r + 1] - cy0
			var bx0 := cw; var by0 := ch; var bx1 := -1; var by1 := -1
			for y in ch:
				for x in cw:
					if img.get_pixel(cx0 + x, cy0 + y).a > ALPHA_MIN:
						bx0 = mini(bx0, x); by0 = mini(by0, y)
						bx1 = maxi(bx1, x); by1 = maxi(by1, y)
			boxes.append(Vector4i(cx0, cy0, cw, ch))   # store cell origin+size
			if bx1 >= 0:
				gx0 = mini(gx0, bx0); gy0 = mini(gy0, by0)
				gx1 = maxi(gx1, bx1); gy1 = maxi(gy1, by1)
	if gx1 < 0:
		print("FAIL: sheet is fully transparent"); quit(1); return
	gx0 = maxi(0, gx0 - PAD); gy0 = maxi(0, gy0 - PAD)
	var bw := gx1 - gx0 + 1 + PAD; var bh := gy1 - gy0 + 1 + PAD

	# Pass 2 — crop every cell to the shared box and write badge_NN.png.
	DirAccess.make_dir_recursive_absolute(_globalize(out_dir))
	var i := 0
	for box in boxes:
		var cell := box as Vector4i
		var w := mini(bw, cell.z - gx0)
		var h := mini(bh, cell.w - gy0)
		var cut := Image.create(w, h, false, Image.FORMAT_RGBA8)
		cut.blit_rect(img, Rect2i(cell.x + gx0, cell.y + gy0, w, h), Vector2i.ZERO)
		var p := "%s/badge_%02d.png" % [out_dir, i]
		cut.save_png(_globalize(p))
		print("badge_%02d -> %s (%dx%d)" % [i, p, w, h])
		i += 1
	print("DONE: %d badges, shared box %dx%d" % [n, bw, bh])
	quit()
