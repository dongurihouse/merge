extends SceneTree
## Placement Workbench — standalone runner (sibling of ui_workbench.gd).
## Boots the REAL Home (Map) or Board scene and mounts the drag-to-place overlay so you can
## move the major items and Save their location back into source data.
##   interactive:  make place SCREEN=home|board        (a real window you can drag)
##   quiet shot:   make shot-place SCREEN=home|board [OUT=/tmp/place.png]
##
## Non-destructive: the player's real save is never touched — state is redirected to a temp
## dir via Save.configure_for_test, and we start fresh so every hub unlock badge is visible.

const Save = preload("res://engine/scripts/core/save.gd")
const G = preload("res://engine/scripts/core/content.gd")
const Design = preload("res://engine/scripts/core/design.gd")
const Overlay = preload("res://games/grove/tools/placement_overlay.gd")

func _initialize() -> void:
	var quiet := FileAccess.file_exists("res://override.cfg")   # set by quiet_godot.sh
	if quiet:
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true, 0)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)

	var mode := "home"
	var out := "/tmp/placement.png"
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s.begins_with("screen="):
			mode = s.split("=")[1]
		elif s.begins_with("out="):
			out = s.split("=")[1]

	# redirect SAVE to a throwaway dir + start fresh (nothing unlocked → all hub badges show).
	var dir := "/tmp/tu_placement/"
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	Save.configure_for_test(dir)
	Save.reset()

	# Size the window to the design PORTRAIT aspect BEFORE the scene builds, so the board computes its
	# grid against the right viewport. map.gd does this itself in _ready; board.gd does NOT (in normal
	# play the board is entered from the already-sized map), so booting it cold here needs the fit.
	if not quiet:
		Design.fit_desktop_window()
		await process_frame

	var scene_path := "res://engine/scenes/Board.tscn" if mode == "board" else "res://engine/scenes/Map.tscn"
	var scn: Node = load(scene_path).instantiate()
	root.add_child(scn)
	current_scene = scn
	await create_timer(0.4).timeout
	if mode != "board":
		scn._open_map(G.hub_map())          # the farmhouse hub: the §16 home that ships farm_home.json badges
		await create_timer(0.3).timeout

	var ov: Control = Overlay.new()
	ov.scene = scn
	ov.mode = mode
	scn.add_child(ov)                       # last child → drawn on top → gets input first
	await process_frame
	ov.setup()

	if quiet:
		await create_timer(0.4).timeout
		RenderingServer.force_draw()        # minimized windows can serve a stale frame
		var err := root.get_texture().get_image().save_png(out)
		print("SHOT saved=%s err=%d mode=%s" % [out, err, mode])
		quit()
	# interactive: leave the window up for you to drag + Save
