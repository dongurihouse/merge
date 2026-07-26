extends SceneTree
## Dev tool (run via engine/tools/quiet_godot.sh): screenshot the NEW Residents management dialog
## (ui/residents.gd, mock v2) and the daily calendar (to eyeball the restyled shared frame).
##   quiet_godot.sh --path . -s res://games/grove/tools/residents_dialog_shot.gd -- <out_dir>
## Seeds a completed scene (its bucket cell), a placed spirit, matured stock and a hand.
## Parallel-safe (own temp save). Mirrors residents_shot.gd's quiet-capture header.

const Base = preload("res://games/grove/tools/shot_base.gd")
const Save = preload("res://engine/scripts/core/save.gd")
const G = preload("res://engine/scripts/core/content.gd")
const Bucket = preload("res://engine/scripts/core/bucket.gd")
const MapScene = preload("res://engine/scripts/scenes/map.gd")

func _initialize() -> void:
	var ctx := await Base.begin(self, {
		"tool": "residents_dialog",
		"default_out": "/tmp/tu_residents_dialog_out",
		"out_kind": "dir",
		"save_dir": "/tmp/tu_residents_dialog_shot/",
	})
	if ctx.is_empty():
		return                        # refused: begin() printed why and quit(2)
	var args: Array = ctx["args"]
	var out_dir: String = ctx["out"]

	# fully unlock the first scene → its bucket cell; seed spirits + matured banks.
	var g := Save.grove()
	g["exp"] = 60
	var unl: Dictionary = g.get("unlocks", {})
	for c in G.clusters(0):
		unl[String((c as Dictionary).id)] = true
	g["unlocks"] = unl
	Save.grove_write()
	Save.add_coins(300)
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

	var e0 := Base.capture(self, out_dir + "home_rail.png", args)

	scn._open_residents()
	await create_timer(0.7).timeout
	var e1 := Base.capture(self, out_dir + "residents_dialog.png", args)

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
		get_root().push_input(down, true)
		for i in 6:
			var mv := InputEventMouseMotion.new()
			mv.position = a.lerp(b, float(i + 1) / 6.0)
			mv.button_mask = MOUSE_BUTTON_MASK_LEFT
			get_root().push_input(mv, true)
			await create_timer(0.03).timeout
		var up := InputEventMouseButton.new()
		up.button_index = MOUSE_BUTTON_LEFT; up.pressed = false; up.position = b
		get_root().push_input(up, true)
		await create_timer(0.3).timeout
	var hand_after := Bucket.hand().size()
	print("DRAG hand %d -> %d (merge %s)" % [hand_before, hand_after,
		"OK" if hand_after == hand_before - 1 else "FAILED"])

	# REAL-PATH unplace: sweep the housed spirit down onto the hand grid, release — placed frees up.
	var housed_c: Control = ovd.find_child("HabitatCell_00", true, false) if ovd != null else null
	var zone_c: Control = ovd.find_child("OnHandDropZone", true, false) if ovd != null else null
	var placed_before := Bucket.placed().size()
	if housed_c != null and zone_c != null:
		var a2 := housed_c.get_global_rect().get_center()
		var b2 := zone_c.get_global_rect().get_center()
		var down2 := InputEventMouseButton.new()
		down2.button_index = MOUSE_BUTTON_LEFT; down2.pressed = true; down2.position = a2
		get_root().push_input(down2, true)
		for i in 6:
			var mv2 := InputEventMouseMotion.new()
			mv2.position = a2.lerp(b2, float(i + 1) / 6.0)
			mv2.button_mask = MOUSE_BUTTON_MASK_LEFT
			get_root().push_input(mv2, true)
			await create_timer(0.03).timeout
		var up2 := InputEventMouseButton.new()
		up2.button_index = MOUSE_BUTTON_LEFT; up2.pressed = false; up2.position = b2
		get_root().push_input(up2, true)
		await create_timer(0.3).timeout
	print("DRAG placed %d -> %d (unplace %s)" % [placed_before, Bucket.placed().size(),
		"OK" if Bucket.placed().size() == placed_before - 1 else "FAILED"])

	# select a hand card so the inspector arms (tap the first hand card's button)
	var ov: Control = scn.get_node_or_null("ResidentsOverlay")
	var card: Control = ov.find_child("OnHandCard_00", true, false) if ov != null else null
	if card != null and card.has_method("tap"):
		card.tap()
	await create_timer(0.4).timeout
	var e2 := Base.capture(self, out_dir + "residents_dialog_selected.png", args)
	if ov != null:
		ov.queue_free()
	await create_timer(0.3).timeout

	# the daily calendar — the restyled SHARED frame on an existing dialog
	scn._open_daily()
	await create_timer(0.7).timeout
	var e3 := Base.capture(self, out_dir + "daily_dialog.png", args)

	print("SHOT home=%d residents=%d selected=%d daily=%d -> %s" % [e0, e1, e2, e3, out_dir])
	quit()
