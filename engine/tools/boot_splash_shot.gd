extends SceneTree
## Dev tool (REAL renderer; run via engine/tools/quiet_godot.sh): render the cold-boot splash
## to a PNG for visual review. Builds boot.gd in capture mode (no prewarm/handoff), sets a
## representative mid-load bar, and captures the design-resolution frame.
##   engine/tools/quiet_godot.sh --path . -s res://engine/tools/boot_splash_shot.gd -- /tmp/out.png

const BootScript = preload("res://engine/scripts/scenes/boot.gd")

const W := 1080
const H := 1920

func _initialize() -> void:
	if not FileAccess.file_exists("res://override.cfg"):
		print("REFUSED: run via engine/tools/quiet_godot.sh (born-minimized, no-focus window).")
		quit(2)
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true, 0)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	var uargs := OS.get_cmdline_user_args()
	var out: String = String(uargs[0]) if uargs.size() >= 1 else "/tmp/tu_boot_splash.png"

	await create_timer(0.2).timeout
	DisplayServer.window_set_size(Vector2i(W, H))
	await create_timer(0.2).timeout

	BootScript.capture = true
	var b: Control = BootScript.new()
	b.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(b)                 # capture mode → _ready paints the splash only
	await process_frame
	b.set_process(false)              # belt-and-suspenders: freeze the frame for a deterministic shot
	await process_frame

	# a representative mid-load frame (the live bar is exercised by the running game)
	if b._bar != null:
		b._bar.value = 0.62
	if b._label != null:
		b._label.text = "Loading…  62%"

	await create_timer(0.3).timeout
	RenderingServer.force_draw()
	await create_timer(0.1).timeout
	RenderingServer.force_draw()
	var img := root.get_texture().get_image()
	var err := img.save_png(out)
	print("BOOT SPLASH saved=%s err=%d size=%dx%d" % [out, err, img.get_width(), img.get_height()])
	quit()
