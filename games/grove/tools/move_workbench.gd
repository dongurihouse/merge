extends SceneTree
## Move Feel workbench — standalone runner.
##   live:             make move-workbench
##   quiet screenshot: make shot-move-workbench [OUT=/tmp/move_workbench.png]

const UiFont = preload("res://engine/scripts/ui/ui_font.gd")
const VIEW := "res://games/grove/tools/move_workbench_view.gd"

func _initialize() -> void:
	var quiet := FileAccess.file_exists("res://override.cfg")
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND

	var screen := DisplayServer.screen_get_size()
	var win := Vector2i(1280, 940)
	if screen.x > 0 and screen.y > 0:
		win.x = mini(1280, screen.x - 80)
		win.y = clampi(screen.y - 130, 760, 1200)
	DisplayServer.window_set_size(win)
	DisplayServer.window_set_position((screen - win) / 2)
	if quiet:
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true, 0)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	UiFont.apply()

	var view: Control = load(VIEW).new()
	root.add_child(view)
	await process_frame
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame

	if quiet:
		await create_timer(0.4).timeout
		RenderingServer.force_draw()
		var ua := OS.get_cmdline_user_args()
		var out: String = String(ua[0]) if ua.size() >= 1 else "/tmp/move_workbench.png"
		var err := root.get_texture().get_image().save_png(out)
		print("SHOT saved=%s err=%d" % [out, err])
		quit()
