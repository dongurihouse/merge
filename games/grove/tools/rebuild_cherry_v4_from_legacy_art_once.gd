extends SceneTree

const Model = preload("res://games/grove/tools/scene_workbench_model.gd")
const V2 := "res://games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/cherry_blossom_garden_elements_v2/metadata/placements.json"
const V4 := "res://games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/cherry_blossom_garden_elements_v4/metadata/placements.json"
const LEGACY := "games/grove/assets/map/pages/cherry_blossom_garden"

func _init() -> void:
	var doc := Model.load_doc(V2)
	assert(not doc.is_empty())
	# Keep the authored paper-cut scene, but remove all fish as requested for the true backdrop pass.
	for i in range(Model.placements(doc).size() - 1, -1, -1):
		var item: Dictionary = Model.placements(doc)[i]
		if String(item.get("id", "")).begins_with("koi") or String(item.get("layer", "")) == "koi":
			Model.remove_at(doc, i)
	doc["scene"] = "cherry_blossom_garden_v4"
	doc["artAuthority"] = "Legacy authored paper-cut cherry assets; no generated replacement elements are active."
	doc["base"] = {"id": "foundation", "image": LEGACY + "/foundation.png", "opaque": true, "z": 0}
	assert(Model.placements(doc).size() > 0)
	assert(Model.save_doc(V4, doc))
	quit()
