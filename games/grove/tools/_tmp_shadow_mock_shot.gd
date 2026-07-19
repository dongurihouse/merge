extends SceneTree
## TEMP (delete after use): render the SHARED box-shadow (skin.gd) normalized to the mock slate tint
## (#294654, the "mock-true" family) at bottom-right-biased offsets, so the uniform-shadow candidate
## can be judged against ui_mock.png. Run via quiet_godot:
##   make shot TOOL=games/grove/tools/_tmp_shadow_mock_shot ARGS="/tmp/mock_shadow.png"

const Look = preload("res://engine/scripts/ui/skin.gd")
const Kit = preload("res://games/grove/tools/ui_workbench_kit.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const Pal = Game.PALETTE

func _sample(circular: bool, p: Dictionary) -> Control:
	var box := Panel.new()
	var box_px := 150.0
	box.custom_minimum_size = Vector2(box_px, box_px)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Pal.CREAM
	sb.border_color = Pal.STRAW
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(int(box_px / 2.0) if circular else 34)
	box.add_theme_stylebox_override("panel", sb)
	var sh := Look.shadow_circle(box_px, p) if circular else Look.shadow_rect(34.0, p)
	# normalize to the mock slate tint, same as Kit._normalize_meadow_shadow
	var style := sh.get_theme_stylebox("panel") as StyleBoxFlat
	var tint := Color(Kit.MEADOW_SHADOW_TINT, float(p.get("alpha", 0.24)))
	style.bg_color = tint
	style.shadow_color = tint
	sh.show_behind_parent = true
	box.add_child(sh)
	var m := MarginContainer.new()
	for s in ["left", "top", "right", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 40)
	m.add_child(box)
	return m

func _row(title: String, p: Dictionary) -> Control:
	var box := VBoxContainer.new()
	var lab := Label.new()
	lab.text = title
	lab.add_theme_font_size_override("font_size", 26)
	lab.add_theme_color_override("font_color", Color("#3A2E1F"))
	box.add_child(lab)
	var pair := HBoxContainer.new()
	pair.add_theme_constant_override("separation", 60)
	pair.alignment = BoxContainer.ALIGNMENT_CENTER
	pair.add_child(_sample(true, p))
	pair.add_child(_sample(false, p))
	box.add_child(pair)
	return box

func _initialize() -> void:
	if not FileAccess.file_exists("res://override.cfg"):
		print("REFUSED: run via engine/tools/quiet_godot.sh")
		quit(2)
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true, 0)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() >= 1 else "/tmp/mock_shadow.png"

	await create_timer(0.2).timeout
	DisplayServer.window_set_size(Vector2i(1500, 950))
	await create_timer(0.2).timeout

	# two backgrounds: parchment (dialogs) and the mock's sky blue (home screen chrome)
	var bg := HBoxContainer.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var cands := [
		["G  off(2,5) blur10 a24", {"offset_x": 2.0, "offset_y": 5.0, "blur": 10.0, "spread": -2.0, "alpha": 0.24}],
		["H  off(4,6) blur12 a28", {"offset_x": 4.0, "offset_y": 6.0, "blur": 12.0, "spread": -3.0, "alpha": 0.28}],
	]
	for bgc in [Color("#EFE6D2"), Color("#7FB2CF")]:
		var panel := ColorRect.new()
		panel.color = bgc
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bg.add_child(panel)
		var col := VBoxContainer.new()
		col.position = Vector2(30, 24)
		col.add_theme_constant_override("separation", 24)
		panel.add_child(col)
		for c in cands:
			col.add_child(_row(c[0], c[1]))

	await create_timer(0.6).timeout
	RenderingServer.force_draw()
	var img := root.get_texture().get_image()
	var err := img.save_png(out)
	print("MOCK-SHADOW shot saved=%s err=%d" % [out, err])
	quit()
