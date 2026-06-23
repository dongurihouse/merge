extends SceneTree
## Dev tool: slice the level-badge sheet into individual PNGs, row-major from the plainest
## ring (badge_00) to the grandest crown+ribbon. The current sheet is a 6×6 grid of 36
## circular gold medals — assets/_originals/ui/lvls3.png. If the sheet ships on a baked
## white background, key it transparent FIRST with cutout_bg.gd; this tool expects
## transparent gaps between medals.
##
##   godot --headless --path . -s res://games/tools/slice_badges.gd -- <in.png> <out_dir> [cols rows]
##   (defaults: cols=6 rows=6, out_dir=res://games/grove/assets/ui/lvl)
##
## DISC-CENTRED REGISTRATION: the medals are NOT centred in their grid cells (the disc drifts
## and the laurels/ribbons hang well below it). The HUD draws the level NUMBER centred in a
## square box with a cream disc behind it, so every badge must put its OPEN RING CENTRE (the
## cream disc) at the texture centre — otherwise the number misses the ring and the cream disc
## shows as bare white space. So we anchor each crop on the cream-disc centroid and emit one
## shared SQUARE big enough to hold the furthest decoration reach (in ANY direction, on ANY
## badge) — so the disc stays centred AND no crown/ribbon is ever clipped.
##
## BLEED-PROOF: per cell we keep ONLY the LARGEST opaque connected component (the medal) and
## zero everything else, so a neighbour's crown/ribbon that crosses a grid line never leaves a
## stray fleck (and never inflates the shared square).

const ALPHA_MIN := 0.08        # a pixel counts as "medal" above this alpha
const PAD := 8                 # transparent px kept past the furthest decoration
const NEI := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

func _globalize(p: String) -> String:
	return ProjectSettings.globalize_path(p) if p.begins_with("res://") else p

# A pixel is the medal's cream open-centre: bright, gently warm, low-ish saturation.
func _is_cream(c: Color) -> bool:
	return c.a > 0.5 and c.v > 0.88 and c.s > 0.14 and c.s < 0.36 and c.r >= c.g and (c.r - c.b) > 0.08

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var src := String(a[0]) if a.size() > 0 else "res://games/grove/assets/_originals/ui/lvls3.png"
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

	# Pass 1 — per cell: isolate the medal, find its cream-disc anchor, and the furthest reach
	# from that anchor to the medal's edge (which sizes the shared square).
	var n := cols * rows
	var cells: Array = []
	var reach := 0
	for r in rows:
		for c in cols:
			var cx0 := xs[c]; var cy0 := ys[r]
			var cw := xs[c + 1] - cx0; var ch := ys[r + 1] - cy0
			var m := _medal(img, cx0, cy0, cw, ch)
			m["ox"] = cx0; m["oy"] = cy0; m["cw"] = cw; m["ch"] = ch
			cells.append(m)
			reach = maxi(reach, int(m["reach"]))
	if reach <= 0:
		print("FAIL: no medal content found"); quit(1); return
	var half := reach + PAD
	var size := half * 2

	# Pass 2 — emit one square per cell, the medal's disc anchor pinned to the centre.
	DirAccess.make_dir_recursive_absolute(_globalize(out_dir))
	var i := 0
	for cell in cells:
		var cw: int = cell["cw"]; var ch: int = cell["ch"]
		var ox: int = cell["ox"]; var oy: int = cell["oy"]
		var ax: int = cell["ax"]; var ay: int = cell["ay"]   # disc anchor, cell-local
		var mask: PackedByteArray = cell["mask"]
		var cut := Image.create(size, size, false, Image.FORMAT_RGBA8)   # zero-init -> transparent
		for ly in ch:
			var dy := half + (ly - ay)
			if dy < 0 or dy >= size:
				continue
			for lx in cw:
				if mask[ly * cw + lx] == 0:
					continue
				var dx := half + (lx - ax)
				if dx < 0 or dx >= size:
					continue
				cut.set_pixel(dx, dy, img.get_pixel(ox + lx, oy + ly))
		var p := "%s/badge_%02d.png" % [out_dir, i]
		cut.save_png(_globalize(p))
		print("badge_%02d -> %s (%dx%d, anchor %d,%d)" % [i, p, size, size, ax, ay])
		i += 1
	print("DONE: %d badges, %dx%d square (disc-centred, reach=%d + pad=%d)" % [n, size, size, reach, PAD])
	quit()

## Isolate the medal in a cell: its largest opaque component (mask), the cream-disc anchor
## (ax, ay — cell-local), and `reach` = furthest distance from that anchor to the component's
## edge in any of the four directions. Anchor falls back to the component's bbox centre if no
## cream is found.
func _medal(img: Image, ox: int, oy: int, cw: int, ch: int) -> Dictionary:
	var seen := PackedByteArray(); seen.resize(cw * ch)
	var best: Array[Vector2i] = []
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
			while qi < comp.size():
				var px: Vector2i = comp[qi]; qi += 1
				for d in NEI:
					var nx: int = px.x + d.x; var ny: int = px.y + d.y
					if nx < 0 or ny < 0 or nx >= cw or ny >= ch:
						continue
					var kk := ny * cw + nx
					if seen[kk] == 0 and img.get_pixel(ox + nx, oy + ny).a > ALPHA_MIN:
						seen[kk] = 1
						comp.append(Vector2i(nx, ny))
			if comp.size() > best.size():
				best = comp
	var mask := PackedByteArray(); mask.resize(cw * ch)
	var bx0 := 1 << 30; var by0 := 1 << 30; var bx1 := -1; var by1 := -1
	var csx := 0.0; var csy := 0.0; var cn := 0
	for px in best:
		mask[px.y * cw + px.x] = 1
		bx0 = mini(bx0, px.x); by0 = mini(by0, px.y)
		bx1 = maxi(bx1, px.x); by1 = maxi(by1, px.y)
		if _is_cream(img.get_pixel(ox + px.x, oy + px.y)):
			csx += px.x; csy += px.y; cn += 1
	var ax := int(round(csx / cn)) if cn > 0 else int((bx0 + bx1) / 2)
	var ay := int(round(csy / cn)) if cn > 0 else int((by0 + by1) / 2)
	var reach := 0
	if bx1 >= 0:
		reach = maxi(maxi(ax - bx0, bx1 - ax), maxi(ay - by0, by1 - ay))
	return {"mask": mask, "ax": ax, "ay": ay, "reach": reach}
