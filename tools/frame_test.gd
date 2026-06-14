extends SceneTree
## Dev test: composite each candidate photo frame onto the new farmhouse
## background at the wall-picture spot, to compare them.
##   godot --headless -s res://tools/frame_test.gd
## Tweak WALL_CX / WALL_CY / FRAME_W_FRAC to move/resize the hung frame.

const BG := "res://assets/ChatGPT Image Jun 13, 2026, 01_47_01 PM.png"
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
const WALL_CX := 0.36       # frame centre on the bg (normalized)
const WALL_CY := 0.205
const FRAME_W_FRAC := 0.28  # frame width as a fraction of bg width

func _load(p: String) -> Image:
	var img := Image.new()
	var data := FileAccess.get_file_as_bytes(p)
	if data.is_empty():
		push_error("could not read %s" % p)
		return null
	img.load_png_from_buffer(data)
	return img

func _initialize() -> void:
	var bg := _load(BG)
	if bg == null:
		quit(1); return
	bg.convert(Image.FORMAT_RGBA8)
	var bw := bg.get_width()
	var bh := bg.get_height()
	var composites: Array = []
	for i in FRAMES.size():
		var fr := _load(FRAMES[i])
		if fr == null:
			continue
		fr.convert(Image.FORMAT_RGBA8)
		var used := fr.get_used_rect()           # auto-crop transparent margin
		if used.size.x > 0 and used.size.y > 0:
			fr = fr.get_region(used)
		var tw := int(bw * FRAME_W_FRAC)
		var th := int(fr.get_height() * float(tw) / fr.get_width())
		fr.resize(tw, th, Image.INTERPOLATE_LANCZOS)
		var comp := Image.new()
		comp.copy_from(bg)
		var px := int(bw * WALL_CX - tw / 2.0)
		var py := int(bh * WALL_CY - th / 2.0)
		comp.blend_rect(fr, Rect2i(0, 0, tw, th), Vector2i(px, py))
		var out := "/tmp/frametest_%d.png" % (i + 1)
		comp.save_png(out)
		composites.append(comp)
		print("saved %s" % out)
	# 3x3 montage for side-by-side comparison
	var cols := 3
	var cell_w := 340
	var cell_h := int(bh * float(cell_w) / bw)
	var gap := 12
	var rows := int(ceil(composites.size() / float(cols)))
	var mw := cols * cell_w + (cols + 1) * gap
	var mh := rows * cell_h + (rows + 1) * gap
	var montage := Image.create(mw, mh, false, Image.FORMAT_RGBA8)
	montage.fill(Color("#2b2f26"))
	for i in composites.size():
		var c: Image = composites[i]
		c.resize(cell_w, cell_h, Image.INTERPOLATE_LANCZOS)
		var cxn := i % cols
		var cyn := i / cols
		var x := gap + cxn * (cell_w + gap)
		var y := gap + cyn * (cell_h + gap)
		montage.blit_rect(c, Rect2i(0, 0, cell_w, cell_h), Vector2i(x, y))
	montage.save_png("/tmp/frame_montage.png")
	print("saved /tmp/frame_montage.png  (frames 1-9, left-to-right, top-to-bottom)")
	quit()
