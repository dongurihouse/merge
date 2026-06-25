extends SceneTree
## Standalone look-dev harness for the water fill effect.
##   make water-fx
##   make shot-water-fx OUT=/tmp/water_fill_demo.png

const WaterFillEffect = preload("res://engine/scripts/ui/water_fill_effect.gd")

const CELL := Vector2i(420, 420)
const FRAMES := 10
const STEP := 0.36


func _initialize() -> void:
	if FileAccess.file_exists("res://override.cfg"):
		_capture()
	else:
		_live()


func _live() -> void:
	DisplayServer.window_set_title("Water fill FX demo")
	var screen := DisplayServer.screen_get_size()
	var win := Vector2i(980, 760)
	if screen.x > 0 and screen.y > 0:
		win.x = mini(win.x, screen.x - 80)
		win.y = mini(win.y, screen.y - 100)
	DisplayServer.window_set_size(win)
	DisplayServer.window_set_position((screen - win) / 2)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED

	var bg := ColorRect.new()
	bg.color = Color("#243021")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)

	var fx: Control = WaterFillEffect.new()
	fx.size = Vector2(660, 540)
	fx.position = (Vector2(win) - fx.size) * 0.5
	root.add_child(fx)


func _capture() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true, 0)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	var args := OS.get_cmdline_user_args()
	var out: String = String(args[0]) if args.size() >= 1 else "/tmp/water_fill_demo.png"

	var vp := SubViewport.new()
	vp.size = CELL
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)

	var bg := ColorRect.new()
	bg.color = Color("#243021")
	bg.size = Vector2(CELL.x, CELL.y)
	vp.add_child(bg)

	var fx: Control = WaterFillEffect.new()
	fx.size = Vector2(360, 360)
	fx.position = Vector2(30, 30)
	vp.add_child(fx)
	await process_frame

	var strip := Image.create(CELL.x * FRAMES, CELL.y, false, Image.FORMAT_RGBA8)
	for i in FRAMES:
		fx.set_time_for_test(float(i) * STEP)
		RenderingServer.force_draw()
		await create_timer(0.04).timeout
		var frame := vp.get_texture().get_image()
		frame.convert(Image.FORMAT_RGBA8)
		strip.blit_rect(frame, Rect2i(Vector2i.ZERO, frame.get_size()), Vector2i(CELL.x * i, 0))

	var err := strip.save_png(out)
	print("WATER_FX_STRIP saved=%s err=%d frames=%d size=%dx%d" % [out, err, FRAMES, strip.get_width(), strip.get_height()])
	quit(0 if err == OK else 1)
