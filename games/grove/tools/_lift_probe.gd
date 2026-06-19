extends SceneTree
## THROWAWAY diagnostic: capture an item RESTING then PICKED-UP (held, no release) so we can
## see whether the contact shadow visibly changes on pickup. Run via quiet_godot.sh, then delete.

const Save = preload("res://engine/scripts/core/save.gd")

func _initialize() -> void:
	if not FileAccess.file_exists("res://override.cfg"):
		print("REFUSED: run via engine/tools/quiet_godot.sh")
		quit(2)
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true, 0)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	var dir := "/tmp/tu_liftprobe/"
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	Save.configure_for_test(dir)
	var scn = load("res://engine/scenes/Board.tscn").instantiate()
	root.add_child(scn)
	current_scene = scn
	await create_timer(0.5).timeout
	scn.rng.seed = 7
	var es: Array = scn.board.empty_ground_cells()
	var cell := Vector2i(es[0])
	scn.board.place(cell, 101)           # a sapling
	scn._rebuild_pieces()
	await create_timer(0.3).timeout
	var half: Vector2 = Vector2(scn.csz, scn.csz) / 2.0
	var center: Vector2 = scn._cell_pos(cell) + half
	# 1) RESTING frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("/tmp/lift_resting.png")
	# 2) PICKED-UP frame (press, no release) — leave it at its cell so we compare the same spot
	scn._on_press(center)
	var node = scn.piece_nodes.get(cell)
	var sh = node.get_node_or_null("ContactShadow") if node != null else null
	print("PROBE cell=%s csz=%.1f node=%s shadow=%s shadow_size=%s holder_size=%s holder_scale=%s" % \
		[cell, scn.csz, node, sh, (sh.size if sh else "nil"), (node.size if node else "nil"), (node.scale if node else "nil")])
	await create_timer(0.05).timeout
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("/tmp/lift_lifted.png")
	print("PROBE saved resting + lifted; cell_center=%s" % center)
	quit()
