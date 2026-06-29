extends SceneTree

const Save = preload("res://engine/scripts/core/save.gd")
const G = preload("res://engine/scripts/core/content.gd")

func _pool_for(scene, cell: Vector2i) -> Array:
	var ctx: Dictionary = scene._pop_pool_ctx()
	var pool: Array = Array(ctx.get("pool", [])).duplicate()
	var gid: String = scene.board.gen_id_at(cell)
	var gen_line := int(G.gen_def(G.GENERATORS, gid).get("line", 0))
	if gen_line > 0:
		pool = [gen_line]
	return pool

func _init() -> void:
	Save.configure_for_test("user://tu_probe_generator_pool/")
	Save.reset()
	var scene = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(scene)
	if scene.board == null:
		scene._ready()
	var cell: Vector2i = scene.board.gens.keys()[0]
	var gid: String = scene.board.gen_id_at(cell)
	print("fresh_gens=", scene.board.gens)
	print("fresh_gid=", gid)
	print("fresh_gen_def=", G.gen_def(G.GENERATORS, gid))
	print("quest_map=", scene._quest_map(), " quest_level=", scene._quest_level())
	print("ctx_pool=", scene._pop_pool_ctx().get("pool", []))
	print("actual_pool=", _pool_for(scene, cell))
	scene.board.gens[cell] = "seed_satchel"
	print("legacy_gid=", scene.board.gen_id_at(cell))
	print("legacy_gen_def=", G.gen_def(G.GENERATORS, "seed_satchel"))
	print("legacy_actual_pool=", _pool_for(scene, cell))
	quit()
