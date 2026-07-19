extends SceneTree
## Dev tool (run via engine/tools/quiet_godot.sh): screenshot the NEW Residents management dialog
## (ui/residents.gd, mock v2) and the daily calendar (to eyeball the restyled shared frame).
##   quiet_godot.sh --path . -s res://games/grove/tools/residents_dialog_shot.gd -- <out_dir>
## Seeds a completed farmhouse zone (bucket cells), a placed spirit, matured stock and a hand.
## Parallel-safe (own temp save). Mirrors residents_shot.gd's quiet-capture header.

const Save = preload("res://engine/scripts/core/save.gd")
const G = preload("res://engine/scripts/core/content.gd")
const Bucket = preload("res://engine/scripts/core/bucket.gd")
const Home = preload("res://engine/scripts/core/home.gd")
const HB = preload("res://engine/scripts/core/home_build.gd")
const MapScene = preload("res://engine/scripts/scenes/map.gd")

func _initialize() -> void:
	if not FileAccess.file_exists("res://override.cfg"):
		print("REFUSED: real-renderer tools must run via engine/tools/quiet_godot.sh (born-minimized")
		print("window; in-script flags are too late and flash/steal focus). See ~/.claude/CLAUDE.md")
		quit(2)
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true, 0)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	var args := OS.get_cmdline_user_args()
	var out_dir: String = (args[0] if args.size() >= 1 else "/tmp/tu_residents_dialog_out").trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(out_dir)

	var dir := "/tmp/tu_residents_dialog_shot/"
	if DirAccess.dir_exists_absolute(dir):
		for fn in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir + fn)
	else:
		DirAccess.make_dir_recursive_absolute(dir)
	Save.configure_for_test(dir)

	# complete every home building → the zone's bucket cell(s); seed spirits + matured banks.
	var g := Save.grove()
	g["exp"] = 60
	Save.grove_write()
	Save.add_coins(300)
	var st := Home.state()
	for d in Home.defs():
		while HB.buy_step(st, d):
			pass
	Save.grove_write()
	for spec in [["boost", 2], ["coin", 1], ["coin", 3], ["water", 2], ["diamond", 1], ["boost", 1], ["water", 1], ["water", 2]]:
		Bucket.hand_add(String(spec[0]), int(spec[1]))
	Bucket.place(0)   # seat the boost t2 into the zone cell
	var bst := Bucket.state()
	bst["banks"] = {"coin": 3.4, "water": 1.2, "diamond": 1.0}
	Save.grove_write()

	MapScene._login_shown_launch = true
	var scn = load("res://engine/scenes/Map.tscn").instantiate()
	root.add_child(scn)
	current_scene = scn
	await create_timer(0.8).timeout

	RenderingServer.force_draw()
	var img0 := root.get_texture().get_image()
	var e0 := img0.save_png(out_dir + "home_rail.png")

	scn._open_residents()
	await create_timer(0.7).timeout
	RenderingServer.force_draw()
	var img1 := root.get_texture().get_image()
	var e1 := img1.save_png(out_dir + "residents_dialog.png")

	# REAL-PATH drag check: press on the water t2 twin, sweep to its match, release — through the
	# viewport's input routing (the same path a finger takes), then read the model.
	var ovd: Control = scn.get_node_or_null("ResidentsOverlay")
	var drag_src: Control = ovd.find_child("OnHandCard_06", true, false) if ovd != null else null
	var drag_dst: Control = ovd.find_child("OnHandCard_02", true, false) if ovd != null else null
	var hand_before := Bucket.hand().size()
	if drag_src != null and drag_dst != null:
		var a := drag_src.get_global_rect().get_center()
		var b := drag_dst.get_global_rect().get_center()
		var down := InputEventMouseButton.new()
		down.button_index = MOUSE_BUTTON_LEFT; down.pressed = true; down.position = a
		get_root().push_input(down)
		for i in 6:
			var mv := InputEventMouseMotion.new()
			mv.position = a.lerp(b, float(i + 1) / 6.0)
			mv.button_mask = MOUSE_BUTTON_MASK_LEFT
			get_root().push_input(mv)
			await create_timer(0.03).timeout
		var up := InputEventMouseButton.new()
		up.button_index = MOUSE_BUTTON_LEFT; up.pressed = false; up.position = b
		get_root().push_input(up)
		await create_timer(0.3).timeout
	var hand_after := Bucket.hand().size()
	print("DRAG hand %d -> %d (merge %s)" % [hand_before, hand_after,
		"OK" if hand_after == hand_before - 1 else "FAILED"])

	# select a hand card so the inspector arms (tap the first hand card's button)
	var ov: Control = scn.get_node_or_null("ResidentsOverlay")
	var card: Control = ov.find_child("OnHandCard_00", true, false) if ov != null else null
	if card != null and card.has_method("tap"):
		card.tap()
	await create_timer(0.4).timeout
	RenderingServer.force_draw()
	var img2 := root.get_texture().get_image()
	var e2 := img2.save_png(out_dir + "residents_dialog_selected.png")
	if ov != null:
		ov.queue_free()
	await create_timer(0.3).timeout

	# the daily calendar — the restyled SHARED frame on an existing dialog
	scn._open_daily()
	await create_timer(0.7).timeout
	RenderingServer.force_draw()
	var img3 := root.get_texture().get_image()
	var e3 := img3.save_png(out_dir + "daily_dialog.png")

	print("SHOT home=%d residents=%d selected=%d daily=%d -> %s" % [e0, e1, e2, e3, out_dir])
	quit()
