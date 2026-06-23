extends SceneTree
## Dev tool: slice the level-badge sheet into per-medal PNGs, ordered row-major from the
## plainest ring (badge_00) to the grandest crown (badge_35). The current sheet is a 6×6 grid
## of 36 medals — assets/_originals/ui/lvls3.png. If it ships on a baked white background, key
## it transparent FIRST with cutout_bg.gd; this tool expects transparent gaps between medals.
##
##   godot --headless --path . -s res://games/tools/slice_badges.gd -- <in.png> <out_dir> [cols rows]
##   (defaults: cols=6 rows=6, out_dir=res://games/grove/assets/ui/lvl)
##
## GRID-FREE, FULL MEDAL: the medals OVERFLOW their grid cells — the ornate crowns rise past the
## cell line into the row above. Cutting on the grid clips those crowns (badge_35's crown lost its
## top gem). So we do NOT cut on the grid: each medal is found as a CONNECTED COMPONENT on the
## whole sheet (its crown stays attached), then ordered row-major by centroid. A neighbour's
## overflow is a different component, so it never bleeds in.
##
## TOP-ANCHORED REGISTRATION: every medal is laid into ONE shared SQUARE with its RING OPENING
## (the cream region's bbox centre) pinned to a fixed height near the top — so the crowns sit just
## under the HUD currency pills and the laurels/ribbons hang below, and the HUD number (drawn at
## the box centre) lands in the ring on every badge. The square is sized to hold the furthest
## reach in any direction on any badge, so nothing is ever clipped.

const ALPHA_MIN := 0.08        # a pixel counts as "medal" above this alpha
const MIN_AREA := 400          # ignore specks / dust below this (px)
const PAD := 8                 # transparent px kept past the furthest decoration
const NEI := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

func _globalize(p: String) -> String:
	return ProjectSettings.globalize_path(p) if p.begins_with("res://") else p

# A pixel is the medal's cream open-centre (the ring opening): bright, gently warm, low-ish sat.
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
	var cell_w := float(W) / float(cols)
	var cell_h := float(H) / float(rows)

	# --- find every medal as a connected component on the WHOLE sheet ---------------------
	var seen := PackedByteArray(); seen.resize(W * H)
	var medals: Array = []           # each: {pts, cx, cy (centroid), acx, acy (ring-opening centre)}
	for sy in H:
		for sx in W:
			var k0 := sy * W + sx
			if seen[k0] != 0:
				continue
			if img.get_pixel(sx, sy).a <= ALPHA_MIN:
				seen[k0] = 1
				continue
			var pts: Array[Vector2i] = [Vector2i(sx, sy)]
			seen[k0] = 1
			var qi := 0
			while qi < pts.size():
				var p: Vector2i = pts[qi]; qi += 1
				for d in NEI:
					var nx: int = p.x + d.x; var ny: int = p.y + d.y
					if nx < 0 or ny < 0 or nx >= W or ny >= H:
						continue
					var kk := ny * W + nx
					if seen[kk] == 0 and img.get_pixel(nx, ny).a > ALPHA_MIN:
						seen[kk] = 1
						pts.append(Vector2i(nx, ny))
			if pts.size() < MIN_AREA:
				continue
			var sumx := 0; var sumy := 0
			var crx0 := 1 << 30; var cry0 := 1 << 30; var crx1 := -1; var cry1 := -1
			var bx0 := 1 << 30; var by0 := 1 << 30; var bx1 := -1; var by1 := -1
			for p in pts:
				var pt: Vector2i = p
				sumx += pt.x; sumy += pt.y
				bx0 = mini(bx0, pt.x); by0 = mini(by0, pt.y); bx1 = maxi(bx1, pt.x); by1 = maxi(by1, pt.y)
				if _is_cream(img.get_pixel(pt.x, pt.y)):
					crx0 = mini(crx0, pt.x); cry0 = mini(cry0, pt.y); crx1 = maxi(crx1, pt.x); cry1 = maxi(cry1, pt.y)
			var acx := (crx0 + crx1) / 2 if crx1 >= 0 else (bx0 + bx1) / 2   # ring-opening centre
			var acy := (cry0 + cry1) / 2 if cry1 >= 0 else (by0 + by1) / 2
			medals.append({"pts": pts, "cx": float(sumx) / pts.size(), "cy": float(sumy) / pts.size(),
				"acx": acx, "acy": acy})
	if medals.size() != cols * rows:
		print("WARN: found %d medals, expected %d (check MIN_AREA / keying)" % [medals.size(), cols * rows])

	# --- order row-major by centroid (plainest top-left -> grandest bottom-right) ----------
	medals.sort_custom(func(p, q):
		var pr := int(p["cy"] / cell_h); var qr := int(q["cy"] / cell_h)
		if pr != qr:
			return pr < qr
		return p["cx"] < q["cx"])

	# --- shared square: ring-opening centre pinned at (size/2, cy_anchor); fits every reach -
	var up := 0; var dn := 0; var side := 0
	for m in medals:
		var macy: int = m["acy"]; var macx: int = m["acx"]
		for p in m["pts"]:
			var pt: Vector2i = p
			up = maxi(up, macy - pt.y)
			dn = maxi(dn, pt.y - macy)
			side = maxi(side, absi(pt.x - macx))
	var cy_anchor := up + PAD
	var size := maxi(cy_anchor + dn + PAD, 2 * (side + PAD))

	# --- emit one square per medal -------------------------------------------------------
	DirAccess.make_dir_recursive_absolute(_globalize(out_dir))
	var i := 0
	for m in medals:
		var acx: int = m["acx"]; var acy: int = m["acy"]
		var cut := Image.create(size, size, false, Image.FORMAT_RGBA8)   # zero-init -> transparent
		for p in m["pts"]:
			var pt: Vector2i = p
			var dx := size / 2 + (pt.x - acx)
			var dy := cy_anchor + (pt.y - acy)
			if dx >= 0 and dy >= 0 and dx < size and dy < size:
				cut.set_pixel(dx, dy, img.get_pixel(pt.x, pt.y))
		var path := "%s/badge_%02d.png" % [out_dir, i]
		cut.save_png(_globalize(path))
		i += 1
	print("DONE: %d badges, %dx%d square (ring opening at y=%d, F=%.3f, up=%d dn=%d side=%d)" \
		% [medals.size(), size, size, cy_anchor, float(cy_anchor) / float(size), up, dn, side])
	quit()
