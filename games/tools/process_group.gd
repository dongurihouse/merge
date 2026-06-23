extends SceneTree
## Dev tool: group-normalize a SET of tiles into clean, bottom-anchored, square PNGs that share ONE
## scale — the largest tile fills the box, the smaller tiles keep their RELATIVE size (they do NOT each
## blow up to fill). Use for a level-badge part's stages so a small wreath stays small (its individual
## leaves don't balloon). Bottom edge is a shared baseline; a small constant canvas margin is kept.
##
##   godot --headless -s res://games/tools/process_group.gd -- <size> <out1> <in1> [<out2> <in2> ...]
##
## Each <in> is a sliced tile (its background may be transparent OR a bright/checker fill); each <out>
## accepts res:// or an absolute path.

const MARGIN := 8              # constant transparent margin in CANVAS px (NOT scaled — preserves proportions)
const BG_MAX_VAL := 0.93       # bright + achromatic => background (matches process_icon / slice_grid)
const BG_MAX_SAT := 0.10

func _is_bg(c: Color) -> bool:
	if c.a < 0.05:
		return true
	var mx: float = maxf(c.r, maxf(c.g, c.b))
	var mn: float = minf(c.r, minf(c.g, c.b))
	var sat: float = 0.0 if mx <= 0.0 else (mx - mn) / mx
	return mx > BG_MAX_VAL and sat < BG_MAX_SAT

func _premultiply(im: Image) -> void:
	for y in im.get_height():
		for x in im.get_width():
			var c := im.get_pixel(x, y)
			im.set_pixel(x, y, Color(c.r * c.a, c.g * c.a, c.b * c.a, c.a))

func _unpremultiply(im: Image) -> void:
	for y in im.get_height():
		for x in im.get_width():
			var c := im.get_pixel(x, y)
			if c.a > 0.0039:
				im.set_pixel(x, y, Color(clampf(c.r / c.a, 0.0, 1.0), clampf(c.g / c.a, 0.0, 1.0),
					clampf(c.b / c.a, 0.0, 1.0), c.a))
			else:
				im.set_pixel(x, y, Color(0, 0, 0, 0))

## Flood-fill the background from every border, then crop tight to the opaque subject. Returns the
## cropped image (no padding — the caller adds a constant canvas margin), or null if nothing remained.
func _clean_and_trim(src: String) -> Image:
	var img := Image.load_from_file(src)
	if img == null:
		return null
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	var W := img.get_width()
	var H := img.get_height()
	var seen := PackedByteArray()
	seen.resize(W * H)
	var stack: Array = []
	for x in W:
		stack.append(x)
		stack.append((H - 1) * W + x)
	for y in H:
		stack.append(y * W)
		stack.append(y * W + (W - 1))
	while not stack.is_empty():
		var idx: int = stack.pop_back()
		if seen[idx] == 1:
			continue
		seen[idx] = 1
		var x := idx % W
		var y := idx / W
		if not _is_bg(img.get_pixel(x, y)):
			continue
		img.set_pixel(x, y, Color(0, 0, 0, 0))
		if x > 0:     stack.append(idx - 1)
		if x < W - 1: stack.append(idx + 1)
		if y > 0:     stack.append(idx - W)
		if y < H - 1: stack.append(idx + W)
	var minx := W
	var miny := H
	var maxx := -1
	var maxy := -1
	for y in H:
		for x in W:
			if img.get_pixel(x, y).a > 0.05:
				minx = mini(minx, x); maxx = maxi(maxx, x)
				miny = mini(miny, y); maxy = maxi(maxy, y)
	if maxx < 0:
		return null
	var cw := maxx - minx + 1
	var ch := maxy - miny + 1
	var crop := Image.create(cw, ch, false, Image.FORMAT_RGBA8)
	crop.blit_rect(img, Rect2i(minx, miny, cw, ch), Vector2i.ZERO)
	return crop

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 3 or args.size() % 2 == 0:
		print("usage: process_group <size> <out1> <in1> [<out2> <in2> ...]")
		quit(1); return
	var size := int(args[0])
	var outs: Array = []
	var crops: Array = []
	var max_long := 1
	var i := 1
	while i + 1 < args.size():
		var out_path: String = args[i]
		var in_path: String = args[i + 1]
		i += 2
		var crop := _clean_and_trim(in_path)
		if crop == null:
			print("FAIL: nothing opaque in ", in_path); quit(1); return
		outs.append(out_path)
		crops.append(crop)
		max_long = maxi(max_long, maxi(crop.get_width(), crop.get_height()))
	# ONE scale for the whole group: the largest tile fills (size − 2·margin); the rest keep relative size.
	var scale: float = float(size - 2 * MARGIN) / float(max_long)
	for k in crops.size():
		var crop: Image = crops[k]
		var nw: int = maxi(1, int(round(crop.get_width() * scale)))
		var nh: int = maxi(1, int(round(crop.get_height() * scale)))
		_premultiply(crop)
		crop.resize(nw, nh, Image.INTERPOLATE_LANCZOS)
		_unpremultiply(crop)
		var canvas := Image.create(size, size, false, Image.FORMAT_RGBA8)
		canvas.fill(Color(0, 0, 0, 0))
		canvas.blit_rect(crop, Rect2i(0, 0, nw, nh), Vector2i((size - nw) / 2, size - nh - MARGIN))  # bottom-anchored
		var out_abs: String = ProjectSettings.globalize_path(outs[k]) if String(outs[k]).begins_with("res://") else String(outs[k])
		DirAccess.make_dir_recursive_absolute(out_abs.get_base_dir())
		canvas.save_png(out_abs)
		print("WROTE %s  out=%dx%d  content=%dx%d" % [out_abs, size, size, nw, nh])
	print("group scale=%.4f  (largest source long-side=%d -> %d px)" % [scale, max_long, size - 2 * MARGIN])
	quit()
