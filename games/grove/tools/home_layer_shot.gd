extends SceneTree
## Quiet exact-canvas capture for the standalone layered Home workbench.

const SCENE := preload("res://games/grove/tools/HomeLayerWorkbench.tscn")
const NATIVE_SIZE := Vector2i(941, 1672)


func _initialize() -> void:
	if not FileAccess.file_exists("res://override.cfg"):
		print("REFUSED: run through engine/tools/quiet_godot.sh")
		quit(2)
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true, 0)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)

	var args := OS.get_cmdline_user_args()
	var mode: String = args[0] if args.size() >= 1 else "all"
	var output: String = args[1] if args.size() >= 2 else "/tmp/home_layers.png"

	var viewport := SubViewport.new()
	viewport.size = NATIVE_SIZE
	viewport.size_2d_override = NATIVE_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	root.add_child(viewport)

	var workbench := SCENE.instantiate()
	viewport.add_child(workbench)
	await process_frame
	await process_frame
	if mode == "base":
		workbench.call("set_all_props_visible", false)
	elif mode.begins_with("prop:"):
		workbench.call("set_only_prop_visible", mode.trim_prefix("prop:"))
	workbench.call("set_guides_visible", false)
	await process_frame
	await create_timer(0.2).timeout
	RenderingServer.force_draw()
	var stage := workbench.find_child("Stage", true, false) as Control
	var base := workbench.find_child("HomeBase", true, false) as TextureRect
	print("HOME_LAYERS layout viewport=%s workbench=%s stage_size=%s stage_scale=%s stage_pos=%s base_size=%s texture=%s" % [viewport.size, workbench.size, stage.size, stage.scale, stage.position, base.size, base.texture.get_size()])

	var image := viewport.get_texture().get_image()
	var error := image.save_png(output)
	print("HOME_LAYERS saved=%s err=%d mode=%s size=%s" % [output, error, mode, image.get_size()])
	quit(0 if error == OK else 1)
