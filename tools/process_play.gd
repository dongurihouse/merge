extends SceneTree
## Dev tool: turn assets/ui/play.png (a Play button on a solid WHITE background) into a
## clean transparent, trimmed assets/ui/btn_play.png for the menu.
## Removes the white by flooding from the borders, keyed on "bright AND achromatic" so the
## warm cream pill (and any near-white highlight INSIDE it) survives. Then crops to the art.
##   godot --path . -s res://tools/process_play.gd  &&  godot --headless --path . --import

const SRC := "res://assets/ui/play.png"
const OUT := "res://assets/ui/btn_play.png"
const PAD := 12   # transparent border kept around the trimmed art

func _is_bg(c: Color) -> bool:
	var mx: float = maxf(c.r, maxf(c.g, c.b))
	var mn: float = minf(c.r, minf(c.g, c.b))
	var sat: float = 0.0 if mx <= 0.0 else (mx - mn) / mx
	return mx > 0.85 and sat < 0.10   # bright + (near) grey/white = background

func _initialize() -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path(SRC))
	if img == null:
		print("FAIL: cannot load ", SRC); quit(1); return
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	var W := img.get_width()
	var H := img.get_height()

	# flood-fill the background from every border pixel
	var seen := PackedByteArray()
	seen.resize(W * H)
	var stack: Array = []
	for x in W:
		stack.append(x)                 # top row
		stack.append((H - 1) * W + x)   # bottom row
	for y in H:
		stack.append(y * W)             # left col
		stack.append(y * W + (W - 1))   # right col
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

	# trim to opaque bounds
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
		print("FAIL: nothing opaque left"); quit(1); return
	minx = maxi(0, minx - PAD); miny = maxi(0, miny - PAD)
	maxx = mini(W - 1, maxx + PAD); maxy = mini(H - 1, maxy + PAD)
	var cw := maxx - minx + 1
	var ch := maxy - miny + 1
	var out := Image.create(cw, ch, false, Image.FORMAT_RGBA8)
	out.blit_rect(img, Rect2i(minx, miny, cw, ch), Vector2i.ZERO)
	out.save_png(ProjectSettings.globalize_path(OUT))
	print("WROTE %s  trimmed=%dx%d  aspect=%.3f  removed_bg_px=%d" % [OUT, cw, ch, float(cw) / float(ch), removed])
	quit()
