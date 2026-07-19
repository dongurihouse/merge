extends SceneTree
## Dev tool (run via engine/tools/quiet_godot.sh): screenshot the SHOP dialog's three stalls against
## the shop_dialog_v1 mock. Pins the window to the mock's 1080×1920 phone frame FIRST — the shared
## map_shot capture occasionally comes up at a shorter window, which silently changes the sheet's
## scroll cap and makes a side-by-side read against the mock meaningless.
##   quiet_godot.sh --path . -s res://games/grove/tools/shop_dialog_shot.gd -- <out_dir>
## Parallel-safe (own temp save). Mirrors residents_dialog_shot.gd's quiet-capture header.

const Save = preload("res://engine/scripts/core/save.gd")
const Shop = preload("res://engine/scripts/ui/shop.gd")
const MapScene = preload("res://engine/scripts/scenes/map.gd")
const PHONE_W := 1080
const PHONE_H := 1920

func _initialize() -> void:
	if not FileAccess.file_exists("res://override.cfg"):
		print("REFUSED: real-renderer tools must run via engine/tools/quiet_godot.sh (born-minimized")
		print("window; in-script flags are too late and flash/steal focus). See ~/.claude/CLAUDE.md")
		quit(2)
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true, 0)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	var args := OS.get_cmdline_user_args()
	var out_dir: String = (args[0] if args.size() >= 1 else "/tmp/tu_shop_dialog_out").trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(out_dir)

	var dir := "/tmp/tu_shop_dialog_shot/"
	if DirAccess.dir_exists_absolute(dir):
		for fn in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir + fn)
	else:
		DirAccess.make_dir_recursive_absolute(dir)
	Save.configure_for_test(dir)

	await create_timer(0.2).timeout
	DisplayServer.window_set_size(Vector2i(PHONE_W, PHONE_H))
	await create_timer(0.3).timeout

	Save.add_diamonds(40)
	Save.add_coins(1200)
	MapScene._login_shown_launch = true
	var scn = load("res://engine/scenes/Map.tscn").instantiate()
	root.add_child(scn)
	current_scene = scn
	await create_timer(0.8).timeout

	var noop := func() -> void: pass
	for stall in [["premium", "shop_acorns.png"], ["coin", "shop_coins.png"], ["water", "shop_water.png"]]:
		var ov: Control = scn.get_node_or_null(Shop.OVERLAY_NAME)
		if ov != null:
			ov.free()
		Shop._open(scn, {"refresh": noop}, String(stall[0]))
		await create_timer(0.6).timeout
		RenderingServer.force_draw()
		var img := root.get_texture().get_image()
		var err := img.save_png(out_dir + String(stall[1]))
		print("SHOT %s %dx%d err=%d" % [String(stall[1]), img.get_width(), img.get_height(), err])
	# REAL-PATH tab check: open the acorn stall and TAP the WATER tab through the viewport's input
	# routing (the same path a finger takes), then read which stall the sheet rebuilt into.
	var ov2: Control = scn.get_node_or_null(Shop.OVERLAY_NAME)
	if ov2 != null:
		ov2.free()
	Shop._open(scn, {"refresh": noop}, "premium")
	await create_timer(0.6).timeout
	var ov3: Control = scn.get_node_or_null(Shop.OVERLAY_NAME)
	var tab: Control = ov3.find_child("ShopTab_water", true, false) if ov3 != null else null
	if tab != null:
		var at := tab.get_global_rect().get_center()
		var down := InputEventMouseButton.new()
		down.button_index = MOUSE_BUTTON_LEFT; down.pressed = true; down.position = at
		get_root().push_input(down)
		var up := down.duplicate()
		up.pressed = false
		get_root().push_input(up)
		await create_timer(0.5).timeout
		# the acorn stall shows 7 offers (Welcome + the 6-rung ladder); the water stall shows 2.
		var ov4: Control = scn.get_node_or_null(Shop.OVERLAY_NAME)
		var offers := ov4.find_children("ShopOfferCard", "", true, false).size() if ov4 != null else -1
		print("TAB tap WATER -> %d offers (%s)" % [offers, "SWITCHED" if offers == 2 else "FAILED"])
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png(out_dir + "shop_tab_switched.png")
	else:
		print("TAB tap FAILED: no ShopTab_water")
	print("OUT %s" % out_dir)
	quit()
