extends SceneTree

const G = preload("res://engine/scripts/core/content.gd")

func _init() -> void:
	var p := "/Users/xup/Library/Application Support/Godot/app_userdata/Acorn Forest- Merge!/save.json"
	var txt := FileAccess.get_file_as_string(p)
	var data: Variant = JSON.parse_string(txt)
	if typeof(data) != TYPE_DICTIONARY:
		print("SAVE PARSE FAILED")
		quit()
		return
	var grove: Dictionary = data.get("grove", {})
	var ul: Dictionary = grove.get("unlocks", {})
	var gates: Array = grove.get("gates", [])
	print("parsed OK. gates = ", gates)
	print("map_spots_done(0) = ", G.map_spots_done(0, ul))
	print("map_complete(0)   = ", G.map_complete(0, ul, gates))
	print("map_unlocked(1)   = ", G.map_unlocked(1, ul, gates))
	print("frontier_map      = ", G.frontier_map(ul, gates))
	quit()
