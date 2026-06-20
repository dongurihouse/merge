extends SceneTree
## Fast engine smoke: the live scenes instantiate cleanly on the ACTIVE game's
## clothes (catches broken asset routing / parse errors). ~5s, no full suite.
func _initialize() -> void:
	for s in ["res://engine/scenes/Map.tscn", "res://engine/scenes/Board.tscn"]:
		var ps = load(s)
		if ps == null:
			print("SMOKE FAIL: cannot load ", s); quit(1); return
		var n = ps.instantiate()
		root.add_child(n)
		await create_timer(0.4).timeout
		n.queue_free()
		await create_timer(0.1).timeout
	# Each scene's _ready prewarms the OTHER off-thread; we never navigate, so flush those loads
	# (else they leak / crash WorkerThreadPool teardown at exit — see scene_warm.gd::drain).
	preload("res://engine/scripts/core/scene_warm.gd").drain()
	print("SMOKE OK")
	quit(0)
