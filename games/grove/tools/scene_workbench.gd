extends SceneTree
## Scene-placement workbench — standalone runner (mirrors ui_workbench.gd).
##   interactive:       make sw [SCENE=sakura] [ROOT=<scenes dir>]
##   quiet screenshot:  make shot-sw [SCENE=...] [OUT=/tmp/scene_workbench.png]   (born-minimized)
##
## Every picture-book scene lives under …/assets/map (one folder per scene, art organized into its
## layer subdirs, its placements.json at map/<scene>/placements.json). ROOT= overrides.

const View = preload("res://games/grove/tools/scene_workbench_view.gd")

const ROOT_CANDIDATES := [
	"res://games/grove/assets/map",
]

func _initialize() -> void:
	var quiet := FileAccess.file_exists("res://override.cfg")   # set by quiet_godot.sh
	var ua := OS.get_cmdline_user_args()
	var scene: String = String(ua[0]) if ua.size() >= 1 and String(ua[0]) != "" else "sakura"
	var root_arg: String = String(ua[1]) if ua.size() >= 2 else "auto"
	var cluster: String = String(ua[2]) if ua.size() >= 3 else "none"
	if cluster == "none":
		cluster = ""                                   # CLUSTER= opens selected + isolated on that group
	var out: String = String(ua[3]) if ua.size() >= 4 else "/tmp/scene_workbench.png"

	var scenes_root := ""
	if root_arg != "" and root_arg != "auto":
		scenes_root = root_arg
	else:
		# The requested scene wins across roots. If it is absent everywhere, fall back to the
		# root with the most openable scenes so a partial intake never shadows the full mock set.
		var Model = preload("res://games/grove/tools/scene_workbench_model.gd")
		var cands: Array = []
		for cand in ROOT_CANDIDATES:
			cands.append(ProjectSettings.globalize_path(cand))
		scenes_root = Model.pick_root_for_scene(cands, scene)
	if scenes_root == "":
		push_error("no assets/map root with openable scenes — pass ROOT=<dir>")
		quit(1)
		return

	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var screen := DisplayServer.screen_get_size()
	var win := Vector2i(1720, 1100)                    # icon strip + full-height mock + canvas + sidebar
	if screen.x > 0 and screen.y > 0:
		win.y = clampi(screen.y - 130, 760, 1400)
		var stage_w := int((win.y - 40) * 1320.0 / 2346.0)
		var ref_w := int((win.y - 44) * 941.0 / 1672.0) + 104
		win.x = clampi(stage_w + ref_w + 340 + 60, 1200, screen.x - 80)
	DisplayServer.window_set_size(win)
	DisplayServer.window_set_position((screen - win) / 2)
	if quiet:
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true, 0)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	DisplayServer.window_set_title("Scene workbench — " + scene)

	var view: Control = View.new()
	if not view.setup(scenes_root, scene, cluster):
		quit(1)
		return
	root.add_child(view)
	await process_frame
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame

	if quiet:
		await create_timer(0.6).timeout                # let full-res scene textures upload
		RenderingServer.force_draw()
		var err := root.get_texture().get_image().save_png(out)
		print("SHOT saved=%s err=%d" % [out, err])
		quit()
	# interactive: the window stays up; Cmd+S saves placements.json (a .bak sits beside it)
