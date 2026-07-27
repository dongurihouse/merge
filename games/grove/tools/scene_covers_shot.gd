extends SceneTree
## Quiet proof shot for the sw cover generator: open a scene, enter zone mode, draw a zone over one
## primary object, generate its coverup scatter, and capture — WITHOUT saving (placements.json stays
## put). Born minimized via quiet_godot.sh's override.cfg.
##   godot --path . -s res://games/grove/tools/scene_covers_shot.gd -- [SCENE] [OBJECT|auto] [OUT]

const Base = preload("res://engine/tools/shot_base.gd")
const View = preload("res://games/grove/tools/scene_workbench_view.gd")
const M = preload("res://games/grove/tools/scene_workbench_model.gd")
const CoversModel = preload("res://games/grove/tools/scene_covers_model.gd")

func _initialize() -> void:
	# a workbench-shaped window (wide, roughly 3:2) rather than the phone canvas — the scene editor's
	# own aspect, sized to the display it lands on.
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var screen := DisplayServer.screen_get_size()
	var win := Vector2i(1720, 1100)
	if screen.x > 0 and screen.y > 0:
		win.y = clampi(screen.y - 130, 760, 1400)
		win.x = clampi(int(win.y * 1.5), 1200, screen.x - 80)
	# this tool's positionals are (scene, object, out) — the "mode" slot is the SCENE.
	var ctx := await Base.begin(self, {
		"tool": "scene_covers",
		"default_mode": "coral",
		"out_arg": 2,
		"default_out": "/tmp/scene_covers.png",
		"size": win,
		"save": false,
	})
	if ctx.is_empty():
		return                        # refused: begin() printed why and quit(2)
	var ua: Array = ctx["args"]
	var scene: String = ctx["mode"]
	var want_obj: String = String(ua[1]) if ua.size() >= 2 else "auto"
	var out: String = ctx["out"]
	DisplayServer.window_set_position((screen - win) / 2)

	var scenes_root := ProjectSettings.globalize_path("res://games/grove/assets/map")
	var view: Control = View.new()
	if not view.setup(scenes_root, scene):
		push_error("setup failed for scene " + scene)
		quit(1)
		return
	root.add_child(view)
	await process_frame
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame

	view._enter_zone_mode()
	var primaries: Array = view._primary_clusters()
	if primaries.is_empty():
		push_error("scene has no primary objects")
		quit(1)
		return
	var obj: String = want_obj if (want_obj != "auto" and primaries.has(want_obj)) else String(primaries[0])
	# a zone that traces the object's bounding box, inset a touch so the scatter reads as filling it
	var bb: Rect2 = M.cluster_bbox(view.doc, obj)
	var pad := bb.size * 0.06
	var poly := [
		bb.position + pad,
		Vector2(bb.end.x - pad.x, bb.position.y + pad.y),
		bb.end - pad,
		Vector2(bb.position.x + pad.x, bb.end.y - pad.y),
	]
	CoversModel.set_zone(view._covers_doc, obj, poly)
	view._sync_zone_overlay()
	view._generate_for(obj)
	var made := 0
	for e in M.placements(view.doc):
		if String((e as Dictionary).get("cluster", "")) == ("unlock_region_" + obj):
			made += 1
	print("[covers-shot] scene=%s object=%s covers=%d" % [scene, obj, made])

	await create_timer(0.7).timeout
	var err := Base.capture(self, out)
	print("SHOT saved=%s err=%d" % [out, err])
	quit()
