extends SceneTree
## FX Workbench — standalone runner for the Grove motion/juice lab: the feel verbs (land · merge ·
## launch · move · grab), the Expedition screen juice, and the shared reward flight.
##   live:             make fx-workbench
##   quiet screenshot: make shot-fx-workbench [OUT=/tmp/fx_workbench.png] [EL=<id>]   (EL captures JUST
##                     that one element centred — a clean, repeatable single-component shot)

const UiFont = preload("res://engine/scripts/ui/ui_font.gd")
const SCENE := "res://games/grove/tools/FxWorkbench.tscn"

func _initialize() -> void:
	var quiet := FileAccess.file_exists("res://override.cfg")
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND

	var screen := DisplayServer.screen_get_size()
	var win := Vector2i(1480, 1040)   # the two columns (feel verbs + the reward flight) + the sidebar, no dead band
	if screen.x > 0 and screen.y > 0:
		win.x = mini(1480, screen.x - 80)
		win.y = clampi(screen.y - 130, 760, 1400)
	DisplayServer.window_set_size(win)
	DisplayServer.window_set_position((screen - win) / 2)
	if quiet:
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true, 0)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	UiFont.apply()

	# args: ua[0] = OUT path (quiet path), ua[1] = optional focus element id (EL=) → render just that one.
	var ua := OS.get_cmdline_user_args()
	var focus: String = String(ua[1]) if ua.size() >= 2 else ""

	var view: Control = load(SCENE).instantiate()
	if focus != "":
		view.set("_focus_only", focus)                 # honoured in _build() — bypasses the gallery
	root.add_child(view)
	await process_frame
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame

	if quiet:
		await create_timer(0.4).timeout
		RenderingServer.force_draw()
		var out: String = String(ua[0]) if ua.size() >= 1 else "/tmp/fx_workbench.png"
		var err := root.get_texture().get_image().save_png(out)
		print("SHOT saved=%s err=%d" % [out, err])
		quit()
