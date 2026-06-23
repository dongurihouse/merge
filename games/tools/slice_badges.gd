extends SceneTree
## Dev tool: slice the level-badge sheet into individual PNGs, row-major from the plainest
## ring (badge_00) to the grandest crown+ribbon. The current sheet is a 6×6 grid of 36
## circular gold medals — assets/_originals/ui/lvls2.png. If the sheet ships on a baked
## white background, key it transparent FIRST with cutout_bg.gd; this tool expects
## transparent gaps between medals.
##
##   godot --headless --path . -s res://games/tools/slice_badges.gd -- <in.png> <out_dir> [cols rows]
##   (defaults: cols=6 rows=6, out_dir=res://games/grove/assets/ui/lvl)
##
## REGISTRATION: every badge is cropped to ONE shared box (the union of all medals' alpha
## bboxes + a small pad) so each medal sits at the same scale and centre — the HUD draws the
## level number centred, so consistent registration keeps it inside every ring.
##
## BLEED-PROOF: medals are not always centred in their grid cell (the grand crowns rise past
## the cell's top line into the cell above). So per cell we keep ONLY the LARGEST opaque
## connected component (the medal) and zero everything else — a neighbour's crown/ribbon that
## crosses a grid line never leaves a stray fleck on this badge.

const ALPHA_MIN := 0.08        # a pixel counts as "medal" above this alpha
const PAD := 6                 # px kept around the shared content box
const NEI := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

func _globalize(p: String) -> String:
	return ProjectSettings.globalize_path(p) if p.begins_with("res://") else p

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var src := String(a[0]) if a.size() > 0 else "res://games/grove/assets/_originals/ui/lvls2.png"
	var out_dir := String(a[1]) if a.size() > 1 else "res://games/grove/assets/ui/lvl"
	var cols := int(a[2]) if a.size() > 2 else 6
	var rows := int(a[3]) if a.size() > 3 else 6

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

	# Pass 1 — per cell, isolate the medal (largest opaque component); accumulate the shared box.
	var n := cols * rows
	var cells: Array = []
	var gx0 := 1 << 30; var gy0 := 1 << 30; var gx1 := -1; var gy1 := -1
	for r in rows:
		for c in cols:
			var cx0 := xs[c]; var cy0 := ys[r]
			var cw := xs[c + 1] - cx0; var ch := ys[r + 1] - cy0
			var m := _largest_component(img, cx0, cy0, cw, ch)
			cells.append({"ox": cx0, "oy": cy0, "cw": cw, "ch": ch, "mask": m["mask"]})
			if int(m["bx1"]) >= 0:
				gx0 = mini(gx0, int(m["bx0"])); gy0 = mini(gy0, int(m["by0"]))
				gx1 = maxi(gx1, int(m["bx1"])); gy1 = maxi(gy1, int(m["by1"]))
	if gx1 < 0:
		print("FAIL: no medal content found"); quit(1); return
	gx0 = maxi(0, gx0 - PAD); gy0 = maxi(0, gy0 - PAD)
	var bw := gx1 - gx0 + 1 + PAD; var bh := gy1 - gy0 + 1 + PAD

	# Pass 2 — crop each cell to the shared box, copying ONLY the medal's masked pixels.
	DirAccess.make_dir_recursive_absolute(_globalize(out_dir))
	var i := 0
	for cell in cells:
		var cw: int = cell["cw"]; var ch: int = cell["ch"]
		var ox: int = cell["ox"]; var oy: int = cell["oy"]
		var mask: PackedByteArray = cell["mask"]
		var w := mini(bw, cw - gx0)
		var h := mini(bh, ch - gy0)
		var cut := Image.create(w, h, false, Image.FORMAT_RGBA8)   # zero-init -> transparent
		for yy in h:
			var ly := gy0 + yy
			if ly < 0 or ly >= ch:
				continue
			for xx in w:
				var lx := gx0 + xx
				if lx < 0 or lx >= cw:
					continue
				if mask[ly * cw + lx] != 0:
					cut.set_pixel(xx, yy, img.get_pixel(ox + lx, oy + ly))
		var p := "%s/badge_%02d.png" % [out_dir, i]
		cut.save_png(_globalize(p))
		print("badge_%02d -> %s (%dx%d)" % [i, p, w, h])
		i += 1
	print("DONE: %d badges, shared box %dx%d" % [n, bw, bh])
	quit()

## The LARGEST 4-connected opaque component inside a cell (cell-local coords). Returns its
## boolean `mask` (cell-sized, 1 = kept medal pixel) and bbox; bx1 == -1 when the cell is blank.
func _largest_component(img: Image, ox: int, oy: int, cw: int, ch: int) -> Dictionary:
	var seen := PackedByteArray(); seen.resize(cw * ch)
	var best_mask := PackedByteArray(); best_mask.resize(cw * ch)
	var best_area := 0
	var rbx0 := -1; var rby0 := -1; var rbx1 := -1; var rby1 := -1
	for sy in ch:
		for sx in cw:
			var k0 := sy * cw + sx
			if seen[k0] != 0:
				continue
			if img.get_pixel(ox + sx, oy + sy).a <= ALPHA_MIN:
				seen[k0] = 1
				continue
			var comp: Array[Vector2i] = [Vector2i(sx, sy)]
			seen[k0] = 1
			var qi := 0
			var bx0 := sx; var by0 := sy; var bx1 := sx; var by1 := sy
			while qi < comp.size():
				var px: Vector2i = comp[qi]; qi += 1
				bx0 = mini(bx0, px.x); by0 = mini(by0, px.y)
				bx1 = maxi(bx1, px.x); by1 = maxi(by1, px.y)
				for d in NEI:
					var nx: int = px.x + d.x; var ny: int = px.y + d.y
					if nx < 0 or ny < 0 or nx >= cw or ny >= ch:
						continue
					var kk := ny * cw + nx
					if seen[kk] == 0 and img.get_pixel(ox + nx, oy + ny).a > ALPHA_MIN:
						seen[kk] = 1
						comp.append(Vector2i(nx, ny))
			if comp.size() > best_area:
				best_area = comp.size()
				var nm := PackedByteArray(); nm.resize(cw * ch)
				for px in comp:
					nm[px.y * cw + px.x] = 1
				best_mask = nm
				rbx0 = bx0; rby0 = by0; rbx1 = bx1; rby1 = by1
	return {"mask": best_mask, "bx0": rbx0, "by0": rby0, "bx1": rbx1, "by1": rby1}
