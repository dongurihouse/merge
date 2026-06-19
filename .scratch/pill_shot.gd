extends SceneTree
const Kit = preload("res://games/grove/tools/ui_workbench_kit.gd")
const UiFont = preload("res://engine/scripts/ui/ui_font.gd")
const Pal = preload("res://engine/scripts/core/game.gd").PALETTE
func _initialize() -> void:
	if not FileAccess.file_exists("res://override.cfg"):
		print("REFUSED: run via quiet_godot.sh"); quit(2); return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true, 0)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	UiFont.apply()
	var bg := ColorRect.new(); bg.color = Pal.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT); root.add_child(bg)
	var col := VBoxContainer.new(); col.add_theme_constant_override("separation", 26)
	col.position = Vector2(70, 140); root.add_child(col)
	for f in [8, 12, 18, 26, 40]:
		var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 24)
		var lab := Label.new(); lab.text = "font %d" % f
		lab.custom_minimum_size = Vector2(150, 0)
		lab.add_theme_color_override("font_color", Pal.CREAM)
		lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(lab); row.add_child(Kit.buy_pill("250", "gem", f))
		col.add_child(row)
	await create_timer(0.4).timeout
	RenderingServer.force_draw()
	var ua := OS.get_cmdline_user_args()
	var out: String = String(ua[0]) if ua.size() >= 1 else "/tmp/pill.png"
	root.get_texture().get_image().save_png(out)
	print("SHOT saved=%s" % out); quit()
