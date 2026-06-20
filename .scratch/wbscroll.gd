extends SceneTree
const SCENE := "res://games/grove/tools/UiWorkbench.tscn"
const UiFont := preload("res://engine/scripts/ui/ui_font.gd")
func _initialize() -> void:
	if FileAccess.file_exists("res://override.cfg"):
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true, 0)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	DisplayServer.window_set_size(Vector2i(1760, 1040))
	UiFont.apply()
	var view: Control = load(SCENE).instantiate()
	root.add_child(view)
	await process_frame
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await create_timer(0.5).timeout
	var p: Node = view._gallery
	while p and not (p is ScrollContainer):
		p = p.get_parent()
	if p: (p as ScrollContainer).scroll_vertical = 1500
	await create_timer(0.4).timeout
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("/tmp/wb_low.png")
	print("scrolled gallery=%s to %d" % [str(p != null), (p as ScrollContainer).scroll_vertical if p else -1])
	quit()
