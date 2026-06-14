extends SceneTree
## Fast engine smoke: the live scenes instantiate cleanly on the ACTIVE game's
## clothes (catches broken asset routing / parse errors). ~5s, no full suite.
func _initialize() -> void:
	for s in ["res://engine/scenes/Home.tscn", "res://engine/scenes/Grove.tscn"]:
		var ps = load(s)
		if ps == null:
			print("SMOKE FAIL: cannot load ", s); quit(1); return
		var n = ps.instantiate()
		root.add_child(n)
		await create_timer(0.4).timeout
		n.queue_free()
		await create_timer(0.1).timeout
	print("SMOKE OK")
	quit(0)
