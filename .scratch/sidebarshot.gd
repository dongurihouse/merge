extends SceneTree
const SCENE := "res://games/grove/tools/UiWorkbench.tscn"
const UiFont = preload("res://engine/scripts/ui/ui_font.gd")
func _shot(view, name) -> void:
	await process_frame
	await create_timer(0.35).timeout
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("/tmp/sb_%s.png" % name)
func _initialize() -> void:
	if FileAccess.file_exists("res://override.cfg"):
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true, 0)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	UiFont.apply()
	var view: Control = load(SCENE).instantiate()
	root.add_child(view)
	await process_frame
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await _shot(view, "button")
	view.select("card");   await _shot(view, "card")
	view.select("dialog"); await _shot(view, "dialog")
	print("SIDEBAR SHOTS done")
	quit()
