extends SceneTree
## Y2/Y3 proof shot (run via tools/quiet_godot.sh): the merchant's collection basket
## with a few sale chips (and, with porter_collect on, the porter mid-drift).
##   quiet_godot.sh --path . -s res://tools/basket_shot.gd -- [out.png] [crop=x,y,w,h] [porter]
const Save = preload("res://engine/scripts/save.gd")
const G = preload("res://engine/scripts/content.gd")
const Feat = preload("res://engine/scripts/features.gd")

func _initialize() -> void:
	if not FileAccess.file_exists("res://override.cfg"):
		print("REFUSED: run via tools/quiet_godot.sh")
		quit(2)
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true, 0)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() >= 1 else "/tmp/y_basket.png"
	var dir := "/tmp/tu_basketshot/"
	if DirAccess.dir_exists_absolute(dir):
		for fn in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir + fn)
	else:
		DirAccess.make_dir_recursive_absolute(dir)
	Save.configure_for_test(dir)
	Feat.FLAGS["ftue_staged_chrome"] = false        # the merchant + basket are present
	var root := get_root()
	var scn = load("res://engine/scenes/Board.tscn").instantiate()
	root.add_child(scn)
	current_scene = scn
	await create_timer(0.6).timeout
	# three sales land in the basket (a t5, a t3, and the t8 diamond pinnacle)
	scn._grant_sale(103, null)
	scn._grant_sale(205, null)
	scn._grant_sale(100 + G.TOP_TIER, null)
	scn._rebuild_basket()
	var want_porter := args.has("porter")
	if want_porter:
		scn._play_porter()
		await create_timer(0.7).timeout                # catch the porter mid-drift
	else:
		await create_timer(0.4).timeout
	RenderingServer.force_draw()
	var img := root.get_texture().get_image()
	for wa in args:
		if String(wa).begins_with("crop="):
			var p4 = String(wa).substr(5).split(",")
			if p4.size() == 4:
				img = img.get_region(Rect2i(int(p4[0]), int(p4[1]), int(p4[2]), int(p4[3])))
	var err := img.save_png(out)
	print("SHOT saved=%s err=%d basket=%d coins=%d gems=%d" % [out, err, scn.basket.size(), Save.coins(), Save.diamonds()])
	quit()
