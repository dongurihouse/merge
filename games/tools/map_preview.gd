extends SceneTree
## Composite map-1 cutouts onto base.png to preview look & feel (pure-Image, headless).
##   godot --headless --path . -s res://games/tools/map_preview.gd -- <out.png>
## Each entry {file, cx, cy_bottom, w} places a cutout: trimmed to its opaque bbox, scaled so the
## object width = w × base_width, centered at cx and BOTTOM-anchored at cy (so it sits on the ground).

const BASE := "res://assets/map1/base.png"
const DIR := "res://assets/map1/cutouts/"
# placement: cx (center x), cy (ground line, the object's BOTTOM), w (object width as a fraction of base width)
const PLACE := [
	{"f": "cottage.png",  "cx": 0.50, "cy": 0.49, "w": 0.46},
	{"f": "shed.png",     "cx": 0.77, "cy": 0.55, "w": 0.21},
	{"f": "well.png",     "cx": 0.26, "cy": 0.62, "w": 0.16},
	{"f": "garden.png",   "cx": 0.64, "cy": 0.66, "w": 0.25},
	{"f": "planter.png",  "cx": 0.42, "cy": 0.585, "w": 0.13},
	{"f": "lantern.png",  "cx": 0.17, "cy": 0.78, "w": 0.10},
	{"f": "doghouse.png", "cx": 0.55, "cy": 0.83, "w": 0.17},
]

func _bbox(img: Image) -> Rect2i:
	var w := img.get_width(); var h := img.get_height()
	var minx := w; var miny := h; var maxx := -1; var maxy := -1
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a > 0.04:
				minx = mini(minx, x); maxx = maxi(maxx, x); miny = mini(miny, y); maxy = maxi(maxy, y)
	if maxx < 0:
		return Rect2i(0, 0, w, h)
	return Rect2i(minx, miny, maxx - minx + 1, maxy - miny + 1)

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var out := String(a[0]) if a.size() >= 1 else "/tmp/map1_preview.png"
	var base := Image.load_from_file(ProjectSettings.globalize_path(BASE))
	base.convert(Image.FORMAT_RGBA8)
	var W := base.get_width(); var H := base.get_height()
	for e in PLACE:
		var p := ProjectSettings.globalize_path(DIR + String(e.f))
		var im := Image.load_from_file(p)
		if im == null:
			print("skip ", e.f); continue
		im.convert(Image.FORMAT_RGBA8)
		var bb := _bbox(im)
		var crop := Image.create(bb.size.x, bb.size.y, false, Image.FORMAT_RGBA8)
		crop.blit_rect(im, bb, Vector2i.ZERO)
		var tw := int(round(float(e.w) * W))
		var th := int(round(float(tw) * bb.size.y / bb.size.x))
		crop.resize(maxi(1, tw), maxi(1, th), Image.INTERPOLATE_LANCZOS)
		var x := int(round(float(e.cx) * W)) - tw / 2
		var y := int(round(float(e.cy) * H)) - th        # bottom-anchored
		base.blend_rect(crop, Rect2i(0, 0, tw, th), Vector2i(x, y))
	base.save_png(ProjectSettings.globalize_path(out) if out.begins_with("res://") else out)
	print("WROTE %s  %dx%d" % [out, W, H])
	quit()
