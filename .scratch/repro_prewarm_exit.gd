extends SceneTree
## Repro: instantiate a scene that fires SceneWarm.prewarm() (a load_threaded_request)
## and quit() IMMEDIATELY, leaving the threaded load in flight at process exit.
func _initialize() -> void:
	var ps = load("res://engine/scenes/Map.tscn")   # map.gd._ready prewarms Board.tscn off-thread
	var n = ps.instantiate()
	root.add_child(n)
	# NO wait — quit while the worker-thread load is still pending.
	quit(0)
