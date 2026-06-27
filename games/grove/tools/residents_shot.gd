extends SceneTree
## Dev tool (run via engine/tools/quiet_godot.sh): screenshot the §1 residents surfaces over the Map —
## (1) the one-time map-UNLOCK reward dialog, and (2) the Residents roster SHOP.
##   quiet_godot.sh --path . -s res://games/grove/tools/residents_shot.gd -- <out_dir>
## Stands map 0 (the hub Farm) up as fully unlocked (all spots restored + gate delivered) so it can
## populate, captures the unlock dialog, then opens the Residents shop and captures that. Mirrors
## inbox_shot.gd's quiet-capture header (REFUSES unless override.cfg exists — the born-minimized window
## must come from quiet_godot.sh, not in-script flags, which are too late and flash/steal focus).
## Parallel-safe (own temp save).

const Save = preload("res://engine/scripts/core/save.gd")
const G = preload("res://engine/scripts/core/content.gd")
const Habitat = preload("res://engine/scripts/core/habitat.gd")
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
	var out_dir: String = (args[0] if args.size() >= 1 else "/tmp/tu_residents_out").trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(out_dir)

	var dir := "/tmp/tu_residentsshot/"
	if DirAccess.dir_exists_absolute(dir):
		for fn in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir + fn)
	else:
		DirAccess.make_dir_recursive_absolute(dir)
	Save.configure_for_test(dir)

	# stand map 0 (hub) up as COMPLETE: every spot restored + its gate delivered → can_populate, and the
	# unlock gift is still UNCLAIMED (no task_reward flag) so opening the map fires the reward dialog.
	var z := G.hub_map()
	var g := Save.grove()
	var unl := {}
	for sp in G.MAPS[z].spots:
		unl[String(sp.id)] = true
	g["unlocks"] = unl
	g["gates"] = [z]
	g["last_map"] = String(G.MAPS[z].id)
	g["exp"] = 60
	Save.grove_write()
	Save.add_coins(800)
	Save.add_diamonds(20)
	# seed the live Habitat roster so the dialog shot has content: a couple in hand + one placed on the map.
	Habitat.hand_add("moss", 1)
	Habitat.hand_add("acorn", 2)
	Habitat.hand_add("lantern", 2)
	Habitat.place(String(G.MAPS[z].id), 0)

	MapScene._login_shown_launch = true         # arm the per-launch guard so the daily calendar never auto-pops over our shot
	var scn = load("res://engine/scenes/Map.tscn").instantiate()
	root.add_child(scn)
	current_scene = scn
	await create_timer(0.7).timeout
	scn._open_map(z)                            # fires _maybe_show_unlock_reward (deferred) → the dialog
	await create_timer(0.7).timeout

	RenderingServer.force_draw()                # minimized windows can serve a stale frame — force a fresh draw
	var img1 := root.get_texture().get_image()
	var e1 := img1.save_png(out_dir + "unlock_dialog.png")

	# dismiss the unlock overlay, then open the live Residents (Habitat) dialog and capture it.
	var ov: Node = scn.get_node_or_null("UnlockRewardOverlay")
	if ov != null:
		ov.queue_free()
	await create_timer(0.3).timeout
	scn._open_residents_dialog()
	await create_timer(0.7).timeout
	RenderingServer.force_draw()
	var img2 := root.get_texture().get_image()
	var e2 := img2.save_png(out_dir + "residents_dialog.png")

	print("SHOT unlock=%s (err %d) shop=%s (err %d) coins=%d gems=%d" % [
		out_dir + "unlock_dialog.png", e1, out_dir + "residents_shop.png", e2, Save.coins(), Save.diamonds()])
	quit()
