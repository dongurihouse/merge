extends SceneTree
## Quiet capture of the Zone Workbench (verification: the tool opens rendering the real page).
##   engine/tools/quiet_godot.sh --path . -s res://games/tools/zone_workbench/zone_workbench_shot.gd -- [out.png] [page_index]

const SCENE := preload("res://games/tools/zone_workbench/ZoneWorkbench.tscn")
const VIEW_SIZE := Vector2i(1100, 1140)


func _initialize() -> void:
	if not FileAccess.file_exists("res://override.cfg"):
		print("REFUSED: run through engine/tools/quiet_godot.sh")
		quit(2)
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true, 0)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)

	var args := OS.get_cmdline_user_args()
	var output: String = args[0] if args.size() >= 1 else "/tmp/zone_workbench.png"
	var page: int = int(args[1]) if args.size() >= 2 else 0

	var viewport := SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.size_2d_override = VIEW_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	root.add_child(viewport)

	var workbench := SCENE.instantiate()
	viewport.add_child(workbench)
	await process_frame
	await process_frame
	if page > 0:
		workbench.call("_open_page", page)
	await process_frame
	await create_timer(0.2).timeout
	RenderingServer.force_draw()

	var image := viewport.get_texture().get_image()
	var error := image.save_png(output)
	print("ZONE_WB saved=%s err=%d page=%d size=%s" % [output, error, page, image.get_size()])
	quit(0 if error == OK else 1)
