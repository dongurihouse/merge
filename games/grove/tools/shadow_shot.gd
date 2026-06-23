extends SceneTree
## Dev tool (real renderer; run via engine/tools/quiet_godot.sh): render the home-button RECT badge + the
## currency pill with a range of PER-SIDE drop-shadow configs, so the soft directional shadow can be SEEN.
##   quiet_godot.sh --path . -s res://games/grove/tools/shadow_shot.gd -- /tmp/shadow.png
## Each row is one config (the label says which side(s) cast); left = home badge, right = gold currency pill.

const Kit = preload("res://games/grove/tools/ui_workbench_kit.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const Pal = Game.PALETTE

func _row(title: String, sh: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	var lab := Label.new()
	lab.text = title
	lab.add_theme_font_size_override("font_size", 26)
	lab.add_theme_color_override("font_color", Pal.INK)
	box.add_child(lab)
	var pair := HBoxContainer.new()
	pair.add_theme_constant_override("separation", 70)
	pair.alignment = BoxContainer.ALIGNMENT_CENTER
	# the home RECT badge
	var ho := Kit.home_button_opts_from_config({})
	ho["shape"] = "rect"
	for k in sh: ho["rect_" + k] = sh[k]
	var hb := Kit.home_button({"icon": "board", "caption": "Map"}, ho)
	pair.add_child(_pad(hb))
	# the gold currency pill, with its own plus button.
	var co := Kit.gold_currency_pill_opts_from_config({})
	co["icon"] = "water"
	co["count"] = 128
	co["show_plus"] = true
	for k in sh: co[k] = sh[k]
	var cp := Kit.gold_currency_pill(co, {"water": 128})
	pair.add_child(_pad(cp))
	box.add_child(pair)
	return box

# a margin so a shadow that pokes past the element is not clipped by the layout
func _pad(c: Control) -> Control:
	var m := MarginContainer.new()
	for s in ["left", "top", "right", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 40)
	m.add_child(c)
	return m

func _initialize() -> void:
	if not FileAccess.file_exists("res://override.cfg"):
		print("REFUSED: real-renderer tools must run via engine/tools/quiet_godot.sh")
		quit(2)
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true, 0)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() >= 1 else "/tmp/shadow.png"

	await create_timer(0.2).timeout
	DisplayServer.window_set_size(Vector2i(1320, 1880))
	await create_timer(0.2).timeout

	var bg := ColorRect.new()
	bg.color = Color("#EFE6D2")          # a light parchment so the dark soft shadow reads
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 30)
	col.position = Vector2(50, 36)
	bg.add_child(col)

	col.add_child(_row("shipped default — soft drop below (bottom 10, soft 6)",
		{"shadow_bottom": 10, "shadow_soft": 6, "shadow_alpha": 32}))
	col.add_child(_row("bottom only (bottom 22, soft 8)",
		{"shadow_top": 0, "shadow_bottom": 22, "shadow_left": 0, "shadow_right": 0, "shadow_soft": 8, "shadow_alpha": 40}))
	col.add_child(_row("top only (top 22, soft 8)",
		{"shadow_top": 22, "shadow_bottom": 0, "shadow_left": 0, "shadow_right": 0, "shadow_soft": 8, "shadow_alpha": 40}))
	col.add_child(_row("left only (left 22, soft 8)",
		{"shadow_top": 0, "shadow_bottom": 0, "shadow_left": 22, "shadow_right": 0, "shadow_soft": 8, "shadow_alpha": 40}))
	col.add_child(_row("right only (right 22, soft 8)",
		{"shadow_top": 0, "shadow_bottom": 0, "shadow_left": 0, "shadow_right": 22, "shadow_soft": 8, "shadow_alpha": 40}))
	col.add_child(_row("all four (16 each, soft 6)",
		{"shadow_top": 16, "shadow_bottom": 16, "shadow_left": 16, "shadow_right": 16, "shadow_soft": 6, "shadow_alpha": 36}))

	# NOTE: home badge keys are rect_shadow_* — _row() prefixes "rect_" for the badge and uses the bare
	# shadow_* keys for the pill, so one config dict drives both.
	await create_timer(0.6).timeout
	RenderingServer.force_draw()
	var img := root.get_texture().get_image()
	var err := img.save_png(out)
	print("SHADOW shot saved=%s err=%d size=%dx%d" % [out, err, img.get_width(), img.get_height()])
	quit()
