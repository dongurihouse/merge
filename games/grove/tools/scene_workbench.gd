extends SceneTree
## Scene-placement workbench — standalone runner (mirrors ui_workbench.gd).
##   interactive:       make sw [SCENE=cherry_blossom_garden] [ROOT=<scenes dir>]
##   quiet screenshot:  make shot-sw [SCENE=...] [OUT=/tmp/scene_workbench.png]   (born-minimized)
##
## The five picture-book scene bundles live under …/picturebook_scene_mocks_v1 (one dir per
## <scene>_elements_vN, highest version with metadata/placements.json wins). Until intake lands
## them in this repo they sit in the codex mocks worktree — both roots are tried, ROOT= overrides.

const View = preload("res://games/grove/tools/scene_workbench_view.gd")

const ROOT_CANDIDATES := [
	"res://games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1",
	"res://.worktrees/codex-ui-redesign-rush-maps-mocks/games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1",
	# absolute fallback so the tool works from any git worktree (same convention as
	# build_page_manifests.py — the mocks worktree hangs off the primary checkout)
	"/Users/xup/dh/merge/.worktrees/codex-ui-redesign-rush-maps-mocks/games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1",
]

func _initialize() -> void:
	var quiet := FileAccess.file_exists("res://override.cfg")   # set by quiet_godot.sh
	var ua := OS.get_cmdline_user_args()
	var scene: String = String(ua[0]) if ua.size() >= 1 and String(ua[0]) != "" else "cherry_blossom_garden"
	var root_arg: String = String(ua[1]) if ua.size() >= 2 else "auto"
	var cluster: String = String(ua[2]) if ua.size() >= 3 else "none"
	if cluster == "none":
		cluster = ""                                   # CLUSTER= opens selected + isolated on that group
	var out: String = String(ua[3]) if ua.size() >= 4 else "/tmp/scene_workbench.png"

	var scenes_root := ""
	if root_arg != "" and root_arg != "auto":
		scenes_root = root_arg
	else:
		# the root with the MOST openable scenes wins — a partially-intaken repo copy must
		# never shadow the full mocks worktree (that read as "the scenes are broken/missing")
		var Model = preload("res://games/grove/tools/scene_workbench_model.gd")
		var cands: Array = []
		for cand in ROOT_CANDIDATES:
			cands.append(ProjectSettings.globalize_path(cand))
		scenes_root = Model.pick_root(cands)
	if scenes_root == "":
		push_error("no picturebook_scene_mocks_v1 root with openable scenes — pass ROOT=<dir>")
		quit(1)
		return

	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var screen := DisplayServer.screen_get_size()
	var win := Vector2i(1420, 1100)                    # references (340) + portrait canvas + sidebar (340)
	if screen.x > 0 and screen.y > 0:
		win.y = clampi(screen.y - 130, 760, 1400)
		win.x = clampi(int((win.y - 40) * 1320.0 / 2346.0) + 340 + 340 + 60, 1100, screen.x - 80)
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
