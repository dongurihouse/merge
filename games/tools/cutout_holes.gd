extends SceneTree
## Q2 — ENCLOSED-BACKGROUND HOLE-PUNCH (eng-owned; do NOT touch the owner's
## games/tools/process_icon.gd). A PROCESSED furn sprite already has its OUTER field
## transparent, but background trapped INSIDE the silhouette (the gaps between a
## table's legs, between stool rungs) stays opaque white — process_icon's
## edge flood-fill can't reach it. This pass punches those enclosed pockets.
##
## Headless, pure-Image (no renderer): just run it directly —
##   godot --headless --path . -s res://games/tools/cutout_holes.gd -- <a.png> [b.png ...]
## then `godot --headless --path . --import` so the engine picks the PNGs up.
##
## Rule = the SHARED background rule (games/tools/img_ops.gd: value > BG_MAX_VAL,
## sat < BG_MAX_SAT): a tighter threshold measurably leaves a ~1px dirty-white rim
## (127px of the table's gaps sit in the 0.93–0.97 band). Method: flood-fill from the canvas edges over
## "passable" pixels (transparent OR bg-coloured) to mark the outer field; any
## REMAINING connected passable region with area ≥ AREA_MIN is enclosed
## background → punched transparent. Genuine small white highlights (area <
## AREA_MIN) survive the floor.

const ImgOps := preload("res://games/tools/img_ops.gd")

const AREA_MIN := 24         # enclosed pockets at/over this are background; smaller = highlight
const NEI := ImgOps.NEI

# Background rule is shared — see games/tools/img_ops.gd. Already-clear pixels are passable too.
func _is_bg(c: Color) -> bool:
	return ImgOps.is_bg(c, ImgOps.BG_MAX_VAL, ImgOps.BG_MAX_SAT, ImgOps.ALPHA_MIN_F)

func _initialize() -> void:
	var paths := OS.get_cmdline_user_args()
	if paths.is_empty():
		print("usage: cutout_holes.gd -- <png> [png ...]")
		quit(2)
		return
	var rc := 0
	for p in paths:
		if not _punch(String(p)):
			rc = 1
	quit(rc)

func _punch(path: String) -> bool:
	var img := Image.load_from_file(path)
	if img == null:
		print("FAIL %s: cannot load" % path)
		return false
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	# pass 1 — flood from every border passable pixel: mark the OUTER field
	var outer := ImgOps.mark_outer_field(img, _is_bg)
	# pass 2 — the leftover passable pixels are enclosed pockets; punch big ones
	var seen := PackedByteArray()
	seen.resize(w * h)
	var punched_regions := 0
	var punched_px := 0
	for y in h:
		for x in w:
			var i := y * w + x
			if outer[i] == 1 or seen[i] == 1 or not _is_bg(img.get_pixel(x, y)):
				continue
			# BFS this enclosed component over passable, non-outer pixels
			var comp := PackedInt32Array()
			var q := PackedInt32Array([i])
			seen[i] = 1
			while not q.is_empty():
				var j := q[q.size() - 1]
				q.remove_at(q.size() - 1)
				comp.append(j)
				var jx := j % w
				var jy := j / w
				for d in NEI:
					var nx: int = jx + d.x
					var ny: int = jy + d.y
					if nx < 0 or ny < 0 or nx >= w or ny >= h:
						continue
					var ni: int = ny * w + nx
					if seen[ni] == 1 or outer[ni] == 1:
						continue
					if _is_bg(img.get_pixel(nx, ny)):
						seen[ni] = 1
						q.append(ni)
			if comp.size() < AREA_MIN:
				continue                    # a genuine small highlight — keep it
			var cleared := 0
			for j in comp:
				var jx := j % w
				var jy := j / w
				var c := img.get_pixel(jx, jy)
				if c.a > 0.0:
					c.a = 0.0
					img.set_pixel(jx, jy, c)
					cleared += 1
			if cleared > 0:
				punched_regions += 1
				punched_px += cleared
	var err := img.save_png(path)
	print("PUNCH %s: %d enclosed region(s), %d px cleared (err=%d)" % [path, punched_regions, punched_px, err])
	return err == OK
