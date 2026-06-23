extends SceneTree
const G = preload("res://engine/scripts/core/content.gd")
const Quests = preload("res://engine/scripts/core/quests.gd")
func _init():
	var f := FileAccess.open("user://save.json", FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text())
	var g: Dictionary = d.get("grove", {})
	var board: Dictionary = g.get("board", {})
	var gens: Dictionary = board.get("gens", {})
	print("=== generators ON BOARD ===")
	for cell in gens:
		var gid: String = String(gens[cell])
		var gd: Dictionary = G.gen_def(G.GENERATORS, gid)
		print("  cell=", cell, " id=", gid, " map=", gd.get("map"), " lines=", gd.get("lines"))
	print("gen_bag=", board.get("gen_bag", []))
	print("=== roster ===")
	for entry in G.GENERATORS:
		print("  id=", entry.get("id"), " map=", entry.get("map"), " lines=", entry.get("lines"), " appear_level=", entry.get("appear_level", "-"))
	var cur: int = Quests.current_map(g.get("unlocks", {}), g.get("gates", []))
	print("current_map=", cur, " lines_for_map=", G.lines_for_map(G.GENERATORS, cur))
	for i in G.MAPS.size():
		print("  map ", i, " id=", G.MAPS[i].get("id"))
	quit()
