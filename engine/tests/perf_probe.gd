extends "res://games/grove/tests/grove_test_base.gd"
## One-off perf probe (NOT a suite): times the Map<->Board build the live swap pays.
## Headless = CPU-only lower bound (dummy renderer skips GPU upload). Run:
##   godot --headless --path . -s res://engine/tests/perf_probe.gd

func _ms() -> int:
	return Time.get_ticks_msec()

func _time_scene(path: String, label: String) -> void:
	# load() — SceneWarm normally does this off-thread; cost only on first visit.
	var t0 := _ms()
	var ps: PackedScene = load(path)
	var t_load := _ms() - t0

	# instantiate() — synchronous node-tree build (can't be threaded).
	t0 = _ms()
	var node: Node = ps.instantiate()
	var t_inst := _ms() - t0

	# add_child runs _ready SYNCHRONOUSLY (the hard freeze the player feels).
	t0 = _ms()
	get_root().add_child(node)
	var t_ready := _ms() - t0

	# then await frames for any deferred build to settle.
	t0 = _ms()
	await process_frame
	await process_frame
	await process_frame
	var t_frames := _ms() - t0

	print("  %-6s  load=%4dms  inst=%4dms  _ready(sync freeze)=%5dms  +3frames=%4dms"
		% [label, t_load, t_inst, t_ready, t_frames])
	node.queue_free()
	await process_frame

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	begin("PERF PROBE — Map/Board build cost (headless, CPU-only)")
	fresh("perf_probe")
	# Give map 0 some content so the build does representative work.
	var z := 0
	var map_id := String(G.MAPS[z].id)
	var g: Dictionary = Save.grove()
	var unl: Dictionary = {}
	for sp in G.MAPS[z].spots:
		unl[String(sp.id)] = true
	g["unlocks"] = unl
	g["gates"] = [z]
	g["last_map"] = map_id
	Save.grove_write()
	Save.add_coins(1000)

	print("-- first visit (cold: load+compile not yet warm) --")
	await _time_scene("res://engine/scenes/Map.tscn", "Map")
	await _time_scene("res://engine/scenes/Board.tscn", "Board")
	print("-- repeat visits (load cached, the recurring per-navigation cost) --")
	await _time_scene("res://engine/scenes/Map.tscn", "Map")
	await _time_scene("res://engine/scenes/Board.tscn", "Board")
	await _time_scene("res://engine/scenes/Map.tscn", "Map")
	await _time_scene("res://engine/scenes/Board.tscn", "Board")
	finish()
