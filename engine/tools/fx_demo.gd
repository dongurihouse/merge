extends SceneTree
## Look-dev harness for the breaking-glass shatter (engine/scripts/ui/shatter.gd).
##   make fx                                                             → live looping window
##   make shot TOOL=engine/tools/fx_demo ARGS="/tmp/shatter.png"         → flat-glass film-strip
##   make shot TOOL=engine/tools/fx_demo ARGS="/tmp/shatter.png tex"     → TEXTURED-shard test:
##       a purple irregular blob (transparent surround) shatters in its TRUE shape — proves the
##       same texture/UV path the map's purple lock-veil shatter uses (shards outside the shape
##       are transparent and don't draw).

const Shatter = preload("res://engine/scripts/ui/shatter.gd")
const Save = preload("res://engine/scripts/core/save.gd")

const CELL := 300
const FRAMES := 9
const STEP := 0.07
const GLASS := Color(0.82, 0.90, 0.96, 0.50)
const PURPLE := Color(0.6863, 0.6627, 0.9255, 0.34)   # the map's #AFA9EC lock tint


func _initialize() -> void:
	Save.configure_for_test("/tmp/tu_fx_demo/")
	if FileAccess.file_exists("res://override.cfg"):
		_capture()
	else:
		_live()


func _live() -> void:
	DisplayServer.window_set_title("FX demo — breaking glass (close window to quit)")
	var view: Vector2 = root.get_visible_rect().size
	var bg := ColorRect.new()
	bg.color = Color("#2A2A1E")
	bg.size = view
	root.add_child(bg)
	var center := view * 0.5
	var side: float = minf(view.x, view.y) * 0.34
	var n := 0
	while true:
		var f: Node2D = Shatter.new()
		root.add_child(f)
		var rng := RandomNumberGenerator.new()
		rng.seed = 1337 + n * 17
		var impact := center + Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * side * 0.16
		f.arm(_square(center, side), impact, {"color": GLASS}, 0.45, rng)
		await create_timer(2.2).timeout
		if is_instance_valid(f):
			f.queue_free()
		n += 1


func _capture() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true, 0)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	var uargs := OS.get_cmdline_user_args()
	var out: String = String(uargs[0]) if uargs.size() >= 1 else "/tmp/fx_demo.png"
	var textured := uargs.size() >= 2 and String(uargs[1]) == "tex"

	var vp := SubViewport.new()
	vp.size = Vector2i(CELL, CELL)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var bg := ColorRect.new()
	bg.color = Color("#2A2A1E")
	bg.size = Vector2(CELL, CELL)
	vp.add_child(bg)

	var center := Vector2(CELL, CELL) * 0.5
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var f: Node2D = Shatter.new()
	vp.add_child(f)

	if textured:
		var tex := _blob_texture()
		var box := Rect2(tex.get_image().get_used_rect())
		var impact := box.get_center()
		f.arm(_rect_poly(box), impact, {"texture": tex, "dust": Color(PURPLE.r, PURPLE.g, PURPLE.b, 0.8)}, -1.0, rng)
	else:
		var impact := center + Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * 130.0 * 0.16
		f.arm(_square(center, 130.0), impact, {"color": GLASS}, -1.0, rng)

	await create_timer(0.2).timeout
	var strip := Image.create(CELL * FRAMES, CELL, false, Image.FORMAT_RGBA8)
	for i in FRAMES:
		RenderingServer.force_draw()
		await create_timer(STEP).timeout
		var frame := vp.get_texture().get_image()
		frame.convert(Image.FORMAT_RGBA8)
		strip.blit_rect(frame, Rect2i(Vector2i.ZERO, frame.get_size()), Vector2i(CELL * i, 0))
		if i == 0 and is_instance_valid(f):
			f.release()
	var err := strip.save_png(out)
	print("FX strip saved=%s err=%d size=%dx%d textured=%s" % [out, err, strip.get_width(), strip.get_height(), textured])
	quit()


func _square(center: Vector2, side: float) -> Array:
	var h := side * 0.5
	return [center + Vector2(-h, -h), center + Vector2(h, -h),
			center + Vector2(h, h), center + Vector2(-h, h)]

func _rect_poly(r: Rect2) -> Array:
	return [r.position, r.position + Vector2(r.size.x, 0),
			r.position + r.size, r.position + Vector2(0, r.size.y)]

# a purple irregular blob (transparent surround) to stand in for a masked map region
func _blob_texture() -> Texture2D:
	var img := Image.create(CELL, CELL, false, Image.FORMAT_RGBA8)
	var c := Vector2(CELL, CELL) * 0.5
	for y in CELL:
		for x in CELL:
			var pp := Vector2(x, y) - c
			# wobbly radius so the shape is clearly not a circle/rect
			var ang := pp.angle()
			var rad := 95.0 + 28.0 * sin(ang * 3.0) + 14.0 * cos(ang * 5.0)
			img.set_pixel(x, y, PURPLE if pp.length() < rad else Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)
