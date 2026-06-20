extends SceneTree
const LoginUI := preload("res://engine/scripts/ui/login.gd")
const Login := preload("res://engine/scripts/core/login.gd")
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
	print("today=%d claimed=%s" % [Login.today_day(), str(Login.claimed_today())])
	LoginUI.open(host)
	await create_timer(0.7).timeout
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("/tmp/daily.png")
	print("DAILY done host_children=%d" % host.get_child_count())
	quit()
