extends SceneTree
## One-off: cut the baked fake-transparency checkerboard/white background off the
## 9 photo-frame raws and save clean, tight, truly-transparent PNGs.
##   godot --headless --path . -s res://tools/cutout_frames.gd
## Flood-fills the BORDER-connected light/low-saturation background (the checker +
## white) to transparent — enclosed mats inside a frame are preserved.

const FRAMES := [
	"res://assets/ChatGPT Image Jun 13, 2026, 01_02_03 PM (1).png",
	"res://assets/ChatGPT Image Jun 13, 2026, 01_02_04 PM (2).png",
	"res://assets/ChatGPT Image Jun 13, 2026, 01_02_04 PM (3).png",
	"res://assets/ChatGPT Image Jun 13, 2026, 01_02_04 PM (4).png",
	"res://assets/ChatGPT Image Jun 13, 2026, 01_02_04 PM (5).png",
	"res://assets/ChatGPT Image Jun 13, 2026, 01_02_06 PM (6).png",
	"res://assets/ChatGPT Image Jun 13, 2026, 01_02_06 PM (7).png",
	"res://assets/ChatGPT Image Jun 13, 2026, 01_02_06 PM (8).png",
	"res://assets/ChatGPT Image Jun 13, 2026, 01_02_06 PM (9).png",
]
const SAT_MAX := 0.18    # checker + white are near-greyscale
const VAL_MIN := 0.62    # ...and light (white squares ~1.0, grey squares ~0.75)

func _is_bg(c: Color) -> bool:
	if c.a < 0.05:
		return true
	var mx: float = maxf(c.r, maxf(c.g, c.b))
	var mn: float = minf(c.r, minf(c.g, c.b))
	var sat: float = 0.0 if mx <= 0.0 else (mx - mn) / mx
	return sat < SAT_MAX and mx > VAL_MIN

func _initialize() -> void:
	for idx in FRAMES.size():
		var img := Image.new()
		img.load_png_from_buffer(FileAccess.get_file_as_bytes(FRAMES[idx]))
		img.convert(Image.FORMAT_RGBA8)
		var iw := img.get_width()
		var ih := img.get_height()
		var seen := PackedByteArray()
		seen.resize(iw * ih)
		var stack: PackedInt32Array = PackedInt32Array()
		for x in iw:
			stack.append(x)
			stack.append((ih - 1) * iw + x)
		for y in ih:
			stack.append(y * iw)
			stack.append(y * iw + (iw - 1))
		var removed := 0
		while stack.size() > 0:
			var i := stack[stack.size() - 1]
			stack.remove_at(stack.size() - 1)
			if seen[i] == 1:
				continue
			seen[i] = 1
			var x := i % iw
			var y := i / iw
			if not _is_bg(img.get_pixel(x, y)):
				continue
			img.set_pixel(x, y, Color(0, 0, 0, 0))
			removed += 1
			if x > 0: stack.append(i - 1)
			if x < iw - 1: stack.append(i + 1)
			if y > 0: stack.append(i - iw)
			if y < ih - 1: stack.append(i + iw)
		var used := img.get_used_rect()
		if used.size.x > 0 and used.size.y > 0:
			img = img.get_region(used)
		var out := "res://assets/frames/frame_%d.png" % (idx + 1)
		var out_abs := ProjectSettings.globalize_path(out)
		DirAccess.make_dir_recursive_absolute(out_abs.get_base_dir())
		img.save_png(out_abs)
		print("cut frame_%d  removed=%d  -> %s  (%dx%d)" % [idx + 1, removed, out, img.get_width(), img.get_height()])
	quit()
