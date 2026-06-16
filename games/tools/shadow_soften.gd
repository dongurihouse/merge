extends SceneTree
## Fade a baked contact shadow at the BOTTOM of a transparent cutout. In the bottom FADE_FRAC of the
## object's opaque bbox, DARK pixels (value < DARK_MAX = the ground shadow, not the lit building)
## have their alpha eased out — reduced to KEEP_TOP at the top of the band and to 0 at the very
## bottom edge. Bright pixels (walls, roof, the building's own base) keep full alpha. Result: the
## hard dark contact slab becomes a soft fade into the ground.
##   shadow_soften.gd -- <in> <out> [fade_frac=0.18] [dark_max=0.48] [keep_top=0.35]

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 2:
		print("usage: shadow_soften.gd -- <in> <out> [fade_frac dark_max keep_top]"); quit(2); return
	var src := String(a[0]); var out := String(a[1])
	var FADE := float(a[2]) if a.size() >= 3 else 0.18
	var DARK := float(a[3]) if a.size() >= 4 else 0.48
	var KEEP := float(a[4]) if a.size() >= 5 else 0.35
	var img := Image.load_from_file(ProjectSettings.globalize_path(src) if src.begins_with("res://") else src)
	if img == null: print("FAIL load ", src); quit(1); return
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width(); var h := img.get_height()
	# opaque bbox
	var minx := w; var miny := h; var maxx := -1; var maxy := -1
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a > 0.04:
				minx = mini(minx, x); maxx = maxi(maxx, x); miny = mini(miny, y); maxy = maxi(maxy, y)
	if maxy < 0: print("FAIL: empty"); quit(1); return
	var bh := maxy - miny + 1
	var fade_top := maxy - int(round(bh * FADE))
	var span := float(maxi(1, maxy - fade_top))
	var touched := 0
	for y in range(fade_top, maxy + 1):
		var t: float = clampf((y - fade_top) / span, 0.0, 1.0)   # 0 at band top → 1 at the very bottom
		for x in range(minx, maxx + 1):
			var c := img.get_pixel(x, y)
			if c.a <= 0.0: continue
			var v: float = maxf(c.r, maxf(c.g, c.b))
			if v >= DARK: continue                               # lit building — keep
			c.a *= lerp(KEEP, 0.0, t)                            # dark shadow → eased out, gone at the edge
			img.set_pixel(x, y, c)
			touched += 1
	var oabs := ProjectSettings.globalize_path(out) if out.begins_with("res://") else out
	img.save_png(oabs)
	print("SHADOW-FADE %s -> %s  (%d px, band y=%d..%d)" % [src.get_file(), out.get_file(), touched, fade_top, maxy])
	quit()
