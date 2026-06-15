extends SceneTree
## Dev tool: process a raw LLM-generated icon into a clean, square, transparent PNG.
##
##   godot --headless --path . -s res://games/tools/process_icon.gd -- <input.png> <output_res_path> [size]
##
## Examples:
##   godot --headless --path . -s res://games/tools/process_icon.gd -- /tmp/raw.png res://assets/ui/drawer_books.png
##   godot --headless --path . -s res://games/tools/process_icon.gd -- /tmp/raw.png res://assets/ui/coin.png 256
##
## Handles both:
##   1) Truly transparent PNGs (no-op on the background; just trim + center + resize)
##   2) ChatGPT-style "transparency checkerboard preview" baked as RGB pixels (flood-fills the
##      bright + achromatic checker from every border, leaving the colored subject untouched)
## Also handles solid white backgrounds (e.g. earlier play.png case).

const DEFAULT_SIZE := 512
const PAD := 14                # transparent border kept around the trimmed art
const BG_MAX_VAL := 0.93       # below this -> not background (basket / coin / etc.)
const BG_MAX_SAT := 0.10       # any color saturation -> not background

func _is_bg(c: Color) -> bool:
	if c.a < 0.05:
		return true                                # already transparent — count as bg
	var mx: float = maxf(c.r, maxf(c.g, c.b))
	var mn: float = minf(c.r, minf(c.g, c.b))
	var sat: float = 0.0 if mx <= 0.0 else (mx - mn) / mx
	return mx > BG_MAX_VAL and sat < BG_MAX_SAT

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		print("usage: process_icon <input.png> <output_res_path_or_abs> [size]")
		quit(1); return
	var src: String = args[0]
	var out: String = args[1]
	# size: [size] -> square size×size, or [w h] -> fit into w×h preserving aspect (centered, transparent pad)
	var tw := DEFAULT_SIZE
	var th := DEFAULT_SIZE
	if args.size() >= 4:
		tw = int(args[2]); th = int(args[3])
	elif args.size() >= 3:
		tw = int(args[2]); th = tw

	# resolve output to an absolute path (accepts res:// or absolute)
	var out_abs: String = ProjectSettings.globalize_path(out) if out.begins_with("res://") else out

	var img := Image.load_from_file(src)
	if img == null:
		print("FAIL: cannot load ", src); quit(1); return
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	var W := img.get_width()
	var H := img.get_height()

	# flood-fill the background from every border pixel
	var seen := PackedByteArray()
	seen.resize(W * H)
	var stack: Array = []
	for x in W:
		stack.append(x)
		stack.append((H - 1) * W + x)
	for y in H:
		stack.append(y * W)
		stack.append(y * W + (W - 1))
	var removed := 0
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
		removed += 1
		if x > 0:     stack.append(idx - 1)
		if x < W - 1: stack.append(idx + 1)
		if y > 0:     stack.append(idx - W)
		if y < H - 1: stack.append(idx + W)

	# find opaque bounds
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
		print("FAIL: nothing opaque left — flood-fill ate everything (subject color matched the bg rule?)")
		quit(1); return

	minx = maxi(0, minx - PAD); miny = maxi(0, miny - PAD)
	maxx = mini(W - 1, maxx + PAD); maxy = mini(H - 1, maxy + PAD)
	var cw := maxx - minx + 1
	var ch := maxy - miny + 1

	# crop to the trimmed subject, then fit (preserving aspect) into the target canvas, centered
	var crop := Image.create(cw, ch, false, Image.FORMAT_RGBA8)
	crop.blit_rect(img, Rect2i(minx, miny, cw, ch), Vector2i.ZERO)
	var scale: float = minf(float(tw) / float(cw), float(th) / float(ch)) * 0.96
	var nw: int = maxi(1, int(round(cw * scale)))
	var nh: int = maxi(1, int(round(ch * scale)))
	crop.resize(nw, nh, Image.INTERPOLATE_LANCZOS)
	var canvas := Image.create(tw, th, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0, 0, 0, 0))
	canvas.blit_rect(crop, Rect2i(0, 0, nw, nh), Vector2i((tw - nw) / 2, (th - nh) / 2))

	# ensure parent dir exists (for nested output paths)
	DirAccess.make_dir_recursive_absolute(out_abs.get_base_dir())
	canvas.save_png(out_abs)
	print("WROTE %s  removed_bg_px=%d  trimmed=%dx%d  out=%dx%d" % [out_abs, removed, cw, ch, tw, th])
	quit()
