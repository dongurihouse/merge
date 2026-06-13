extends SceneTree
## Q2 — ENCLOSED-BACKGROUND HOLE-PUNCH (eng-owned; do NOT touch the owner's
## tools/process_icon.gd). A PROCESSED furn sprite already has its OUTER field
## transparent, but background trapped INSIDE the silhouette (the gaps between a
## table's legs, between stool rungs) stays opaque white — process_icon's
## edge flood-fill can't reach it. This pass punches those enclosed pockets.
##
## Headless, pure-Image (no renderer): just run it directly —
##   godot --headless --path . -s res://tools/cutout_holes.gd -- <a.png> [b.png ...]
## then `godot --headless --path . --import` so the engine picks the PNGs up.
##
## Rule = process_icon's OWN background rule (value > 0.93, sat < 0.10): a tighter
## threshold measurably leaves a ~1px dirty-white rim (127px of the table's gaps
## sit in the 0.93–0.97 band). Method: flood-fill from the canvas edges over
## "passable" pixels (transparent OR bg-coloured) to mark the outer field; any
## REMAINING connected passable region with area ≥ AREA_MIN is enclosed
## background → punched transparent. Genuine small white highlights (area <
## AREA_MIN) survive the floor.

const BG_MAX_VAL := 0.93     # process_icon.gd BG_MAX_VAL — keep in lockstep
const BG_MAX_SAT := 0.10     # process_icon.gd BG_MAX_SAT
const ALPHA_MIN := 8         # below this 8-bit alpha = already transparent
const AREA_MIN := 24         # enclosed pockets at/over this are background; smaller = highlight
const NEI := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

func _is_bg(c: Color) -> bool:
	if c.a * 255.0 < ALPHA_MIN:
		return true                         # already-clear pixels are passable too
	var mx: float = maxf(c.r, maxf(c.g, c.b))
	var mn: float = minf(c.r, minf(c.g, c.b))
	var sat: float = 0.0 if mx <= 0.0 else (mx - mn) / mx
	return mx > BG_MAX_VAL and sat < BG_MAX_SAT

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
	var outer := PackedByteArray()
	outer.resize(w * h)
	var stack := PackedInt32Array()
	for x in w:
		_seed(img, outer, stack, x, 0, w, h)
		_seed(img, outer, stack, x, h - 1, w, h)
	for y in h:
		_seed(img, outer, stack, 0, y, w, h)
		_seed(img, outer, stack, w - 1, y, w, h)
	while not stack.is_empty():
		var idx := stack[stack.size() - 1]
		stack.remove_at(stack.size() - 1)
		var cx := idx % w
		var cy := idx / w
		for d in NEI:
			_seed(img, outer, stack, cx + d.x, cy + d.y, w, h)
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

func _seed(img: Image, outer: PackedByteArray, stack: PackedInt32Array, x: int, y: int, w: int, h: int) -> void:
	if x < 0 or y < 0 or x >= w or y >= h:
		return
	var i := y * w + x
	if outer[i] == 1:
		return
	if not _is_bg(img.get_pixel(x, y)):
		return
	outer[i] = 1
	stack.append(i)
