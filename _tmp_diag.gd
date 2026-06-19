extends SceneTree
## throwaway edge diagnostic: sample checker colors of a raw sheet + composite a processed sprite
## on a saturated bg and zoom a region, so the cutout fringe is visible.
##   -- <raw_sheet> <sprite> <out> <cropx> <cropy> <cropw> <zoom>
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var raw := Image.load_from_file(a[0])
	if raw.get_format() != Image.FORMAT_RGBA8: raw.convert(Image.FORMAT_RGBA8)
	# sample a spread of pixels to characterise the checker palette + an object-edge gradient
	print("--- raw sheet %dx%d corner+strip samples ---" % [raw.get_width(), raw.get_height()])
	for p in [Vector2i(2,2), Vector2i(20,2), Vector2i(40,2), Vector2i(2,20), Vector2i(60,60)]:
		var c := raw.get_pixel(p.x, p.y)
		print("  (%d,%d) rgb=%.2f,%.2f,%.2f a=%.2f val=%.2f sat=%.2f" % [p.x,p.y,c.r,c.g,c.b,c.a, maxf(c.r,maxf(c.g,c.b)), (0.0 if maxf(c.r,maxf(c.g,c.b))<=0 else (maxf(c.r,maxf(c.g,c.b))-minf(c.r,minf(c.g,c.b)))/maxf(c.r,maxf(c.g,c.b)))])
	# composite the processed sprite on a dark teal so a gray fringe shows, crop + zoom (nearest)
	var sp := Image.load_from_file(a[1])
	if sp.get_format() != Image.FORMAT_RGBA8: sp.convert(Image.FORMAT_RGBA8)
	var bg := Image.create(sp.get_width(), sp.get_height(), false, Image.FORMAT_RGBA8)
	bg.fill(Color(0.10, 0.16, 0.20, 1.0))
	bg.blend_rect(sp, Rect2i(0,0,sp.get_width(),sp.get_height()), Vector2i.ZERO)
	var cx := int(a[3]); var cy := int(a[4]); var cw := int(a[5]); var zoom := int(a[6])
	var crop := bg.get_region(Rect2i(cx, cy, cw, cw))
	crop.resize(cw*zoom, cw*zoom, Image.INTERPOLATE_NEAREST)
	crop.save_png(a[2])
	print("zoom saved=", a[2])
	quit()
