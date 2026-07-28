extends SceneTree
## Dev tool (run via engine/tools/quiet_godot.sh): screenshot the §1 residents surfaces over the Map —
## (1) the one-time map-UNLOCK reward dialog, and (2) the Residents roster SHOP.
##   quiet_godot.sh --path . -s res://games/grove/tools/residents_shot.gd -- <out_dir>
## Stands map 0 (the hub Farm) up as fully unlocked (all spots restored + gate delivered) so it can
## populate, captures the unlock dialog, then opens the Residents shop and captures that. Mirrors
## inbox_shot.gd's quiet-capture header (REFUSES unless override.cfg exists — the off-screen capture
## window must come from quiet_godot.sh, not in-script flags, which are too late: the window is
## already composited by then).
## Parallel-safe (own temp save).

const Base = preload("res://engine/tools/shot_base.gd")
const Save = preload("res://engine/scripts/core/save.gd")
const G = preload("res://engine/scripts/core/content.gd")
const Bucket = preload("res://engine/scripts/core/bucket.gd")
const MapScene = preload("res://engine/scripts/scenes/map.gd")

func _initialize() -> void:
	var ctx := await Base.begin(self, {
		"tool": "residents",
		"default_out": "/tmp/tu_residents_out",
		"out_kind": "dir",
	})
	if ctx.is_empty():
		return                        # refused: begin() printed why and quit(2)
	var args: Array = ctx["args"]
	var out_dir: String = ctx["out"]

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
	# seed the live bucket with spirits on every line (each line wears a real per-tier art family).
	for spec in [["boost", 1], ["boost", 2], ["coin", 1], ["water", 3], ["diamond", 1], ["boost", 1]]:
		Bucket.hand_add(String(spec[0]), int(spec[1]))
	Bucket.place(0)   # seat one (boost t1) into a cell so the dock's cells grid shows a resident
	var seeded := Bucket.state()
	seeded["banks"] = {"coin": 3.4, "water": 1.2}   # light matured production so the Collect chip reads live
	Save.grove_write()

	MapScene._login_shown_launch = true         # arm the per-launch guard so the daily calendar never auto-pops over our shot
	var scn = load("res://engine/scenes/Map.tscn").instantiate()
	root.add_child(scn)
	current_scene = scn
	await create_timer(0.7).timeout
	scn._open_map(z)                            # fires _maybe_show_unlock_reward (deferred) → the dialog
	await create_timer(0.7).timeout

	var e1 := Base.capture(self, out_dir + "unlock_dialog.png", args)

	# dismiss the unlock overlay, then open the place-picker (residents management now lives here: the
	# bucket dock — cells + Collect/Expedition chips + the in-hand grid, dragged to place/merge) and capture it.
	var ov: Node = scn.get_node_or_null("UnlockRewardOverlay")
	if ov != null:
		ov.queue_free()
	await create_timer(0.3).timeout
	scn._open_select()
	await create_timer(0.7).timeout
	var e2 := Base.capture(self, out_dir + "residents_dock.png", args)

	print("SHOT unlock=%s (err %d) dock=%s (err %d) coins=%d gems=%d" % [
		out_dir + "unlock_dialog.png", e1, out_dir + "residents_dock.png", e2, Save.coins(), Save.diamonds()])
	quit()
