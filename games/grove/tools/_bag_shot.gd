extends SceneTree
## THROWAWAY — bag dialog at three cost_scale values, to pick the one that fits the card.
const UiFont = preload("res://engine/scripts/ui/ui_font.gd")
const Kit = preload("res://games/grove/tools/ui_workbench_kit.gd")

func _bag_entries() -> Array:
	return [
		{"kind": "filled", "icon": "leaf"}, {"kind": "filled", "icon": "leaf"},
		{"kind": "empty"}, {"kind": "next", "cost": 120},
		{"kind": "locked", "cost": 450}, {"kind": "locked", "cost": 999},
		{"kind": "locked", "cost": 1500}, {"kind": "locked", "cost": 2400},
		{"kind": "locked", "cost": 88}, {"kind": "locked", "cost": 12},
	]

func _initialize() -> void:
	var quiet := FileAccess.file_exists("res://override.cfg")
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var win := Vector2i(1700, 760)
	DisplayServer.window_set_size(win)
	if quiet:
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true, 0)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	UiFont.apply()

	var cfg := Kit.load_config(Kit.CONFIG_PATH)

	var rootc := PanelContainer.new()
	rootc.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := StyleBoxFlat.new(); bg.bg_color = Color("#6b8f4a")
	rootc.add_theme_stylebox_override("panel", bg)
	root.add_child(rootc)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	rootc.add_child(row)

	for sc in [100, 70, 55]:
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		var lbl := Label.new(); lbl.text = "cost_scale = %d%%" % sc
		lbl.add_theme_font_size_override("font_size", 22)
		lbl.add_theme_color_override("font_color", Color.WHITE)
		col.add_child(lbl)
		var c := cfg.duplicate(true)
		(c["bag_card"] as Dictionary)["cost_scale"] = float(sc)
		var bopts := Kit.bag_opts_from_config(c); bopts["banner_text"] = "Bag"
		col.add_child(Kit.bag_dialog(_bag_entries(), 132, 520.0, bopts))
		row.add_child(col)

	await process_frame
	await process_frame
	if quiet:
		await create_timer(0.5).timeout
		RenderingServer.force_draw()
		var ua := OS.get_cmdline_user_args()
		var out: String = String(ua[0]) if ua.size() >= 1 else "/tmp/bag_shot.png"
		var err := root.get_texture().get_image().save_png(out)
		print("SHOT saved=%s err=%d" % [out, err])
		quit()
