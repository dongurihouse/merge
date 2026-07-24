extends SceneTree
## Dev tool (run via engine/tools/quiet_godot.sh): screenshot a MOCK of the "Update Available"
## prompt — the App Store version-upgrade dialog — built from the SHARED dialog frame
## (ui_workbench_kit.dialog_frame: parchment card · gold banner · ✕) with a message column and a
## two-button row (cream "Not now" + green "Update"), mounted over the dimmed home the same way
## settings/mail modals are. This is a design mock only; no detection is wired.
##   quiet_godot.sh --path . -s res://games/grove/tools/update_dialog_shot.gd -- <out_dir>
## Mirrors residents_dialog_shot.gd's quiet-capture header + light home seed.

const Save = preload("res://engine/scripts/core/save.gd")
const Home = preload("res://engine/scripts/core/home.gd")
const HB = preload("res://engine/scripts/core/home_build.gd")
const MapScene = preload("res://engine/scripts/scenes/map.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const FS = preload("res://engine/scripts/core/tuning.gd").FontScale
const Pal = Game.PALETTE
const KIT_PATH := "res://games/grove/tools/ui_workbench_kit.gd"

func _initialize() -> void:
	if not FileAccess.file_exists("res://override.cfg"):
		print("REFUSED: real-renderer tools must run via engine/tools/quiet_godot.sh (born-minimized")
		print("window; in-script flags are too late and flash/steal focus). See ~/.claude/CLAUDE.md")
		quit(2)
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true, 0)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	var args := OS.get_cmdline_user_args()
	var out_dir: String = (args[0] if args.size() >= 1 else "/tmp/tu_update_dialog_out").trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(out_dir)

	var dir := "/tmp/tu_update_dialog_shot/"
	if DirAccess.dir_exists_absolute(dir):
		for fn in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir + fn)
	else:
		DirAccess.make_dir_recursive_absolute(dir)
	Save.configure_for_test(dir)

	# a believable home behind the dimmed veil: some progress + every building bought.
	var g := Save.grove()
	g["exp"] = 60
	Save.grove_write()
	Save.add_coins(300)
	var st := Home.state()
	for d in Home.defs():
		while HB.buy_step(st, d):
			pass
	Save.grove_write()

	MapScene._login_shown_launch = true
	var scn = load("res://engine/scenes/Map.tscn").instantiate()
	root.add_child(scn)
	current_scene = scn
	await create_timer(0.8).timeout

	RenderingServer.force_draw()
	var img0 := root.get_texture().get_image()
	img0.save_png(out_dir + "home.png")

	# --- the MOCK dialog: shared frame + message + two-button row, over a dimmed veil ---
	var Kit: GDScript = load(KIT_PATH)
	var vw: float = scn.get_viewport_rect().size.x
	var width: float = vw * 0.62

	var layer := CanvasLayer.new()
	layer.layer = 80
	layer.name = "UpdateMockOverlay"
	scn.add_child(layer)
	var veil := ColorRect.new()
	veil.color = Color(Pal.INK, 0.6)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(veil)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(cc)

	var content := _update_content(Kit, width)
	var opts := {
		"banner_text": "Update Available",
		"on_close": func() -> void:
			if is_instance_valid(layer): layer.queue_free(),
	}
	var dialog: Control = Kit.dialog_frame(content, width, opts)
	cc.add_child(dialog)
	await create_timer(0.6).timeout

	RenderingServer.force_draw()
	var img1 := root.get_texture().get_image()
	var e1 := img1.save_png(out_dir + "update_dialog.png")

	print("SHOT update_dialog=%d -> %s" % [e1, out_dir])
	quit()

# The dialog body: a centred message + a row of two pill buttons (cream "Not now" · green "Update").
func _update_content(Kit: GDScript, width: float) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 30)
	col.alignment = BoxContainer.ALIGNMENT_CENTER

	var msg := Label.new()
	msg.text = "A new version of Acorn Forest is available.\nUpdate now for the latest content and fixes."
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.custom_minimum_size.x = width * 0.84
	msg.add_theme_font_size_override("font_size", FS.BODY)
	msg.add_theme_color_override("font_color", Pal.INK)
	msg.add_theme_constant_override("outline_size", 0)
	msg.add_theme_constant_override("line_spacing", 8)
	col.add_child(msg)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var cancel: Button = Kit.pill_button("Not now", {"bg": "cream", "font": FS.BODY})
	var update: Button = Kit.pill_button("Update", {"bg": "green", "font": FS.BODY})
	row.add_child(cancel)
	row.add_child(update)
	col.add_child(row)
	return col
