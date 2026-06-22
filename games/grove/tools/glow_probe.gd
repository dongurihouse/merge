extends SceneTree
## TEMP probe: render the unlockable slot_cell at a few glow settings on the workbench's dark
## panel, to see what the "huge glow cover" is and whether next_glow gates it.
##   engine/tools/quiet_godot.sh --path . -s res://games/grove/tools/glow_probe.gd -- /tmp/glow_probe.png

const Kit = preload("res://games/grove/tools/ui_workbench_kit.gd")

func _cell(label: String, overrides: Dictionary) -> Control:
	var bco := Kit.bag_card_opts_from_config({})
	var z := 2.0
	bco["cell_w"] = float(bco["cell_w"]) * z
	bco["cell_h"] = float(bco["cell_h"]) * z
	for k in overrides.keys():
		bco[k] = overrides[k]
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	var lab := Label.new()
	lab.text = label
	col.add_child(lab)
	var holder := Control.new()                 # give the huge halo room to overflow
	holder.custom_minimum_size = Vector2(320, 320)
	var cell := Kit.slot_cell({"state": "unlockable"}, bco)
	cell.position = Vector2(320 - float(bco["cell_w"]), 320 - float(bco["cell_h"])) / 2.0
	holder.add_child(cell)
	col.add_child(holder)
	return col

func _initialize() -> void:
	if not FileAccess.file_exists("res://override.cfg"):
		print("REFUSED: run via engine/tools/quiet_godot.sh")
		quit(2)
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true, 0)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() >= 1 else "/tmp/glow_probe.png"

	var bg := ColorRect.new()
	bg.color = Color("#2b2b33")                  # the workbench's dark panel
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	row.position = Vector2(24, 24)
	row.add_child(_cell("default (next_glow=45)", {}))
	row.add_child(_cell("next_glow=0", {"next_glow": 0.0, "next_twinkle": 0.0}))
	row.add_child(_cell("glow size halved", {"next_twinkle": 0.0}))   # placeholder; size is hardcoded
	root.add_child(row)
	await create_timer(0.4).timeout
	RenderingServer.force_draw()
	await process_frame
	var img := root.get_texture().get_image()
	var err := img.save_png(out)
	print("PROBE saved=%s err=%d size=%dx%d" % [out, err, img.get_width(), img.get_height()])
	quit()
