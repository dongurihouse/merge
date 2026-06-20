extends SceneTree
const InboxUI := preload("res://engine/scripts/ui/inbox.gd")
const UiFont := preload("res://engine/scripts/ui/ui_font.gd")
func _initialize() -> void:
	if FileAccess.file_exists("res://override.cfg"):
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true, 0)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	UiFont.apply()
	var bg := ColorRect.new(); bg.color = Color(0.13,0.32,0.18)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT); root.add_child(bg)
	var host := Control.new(); host.set_anchors_preset(Control.PRESET_FULL_RECT); root.add_child(host)
	await process_frame; await process_frame
	InboxUI.open(host)
	await create_timer(0.7).timeout
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("/tmp/inbox.png")
	print("INBOX done")
	quit()
