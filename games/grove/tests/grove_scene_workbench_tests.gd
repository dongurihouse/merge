extends SceneTree
## Gates games/grove/tools/scene_workbench_model.gd — the PURE half of the scene-placement
## workbench (load/save round-trip, entry ops, paint order, hit-testing, path resolution).

const M = preload("res://games/grove/tools/scene_workbench_model.gd")

var _pass := 0
var _fail := 0

func ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _doc() -> Dictionary:
	return {
		"schemaVersion": 2,
		"scene": "test_scene",
		"canvas": {"width": 1000, "height": 2000, "anchorConvention": "center-bottom"},
		"base": {"id": "foundation", "image": "base.png", "z": 0},
		"placements": [
			{"id": "tree", "category": "prop", "image": "a.png", "x": 500, "y": 1000, "w": 200, "h": 400, "z": 30, "layer": "rear"},
			{"id": "rock", "category": "prop", "image": "b.png", "x": 500, "y": 1100, "w": 100, "h": 100, "z": 10, "layer": "rear"},
			{"id": "gate", "category": "structure", "image": "c.png", "x": 520, "y": 1080, "w": 300, "h": 300, "z": 30, "layer": "hero"},
		],
	}

func _initialize() -> void:
	print("== Scene workbench model tests ==")
	var d := _doc()

	# --- geometry + order -----------------------------------------------------------
	ok(M.canvas_size(d) == Vector2(1000, 2000), "canvas_size reads the canvas block")
	ok(M.entry_rect(d.placements[0]) == Rect2(400, 600, 200, 400),
		"entry_rect anchors (x,y) at CENTER-BOTTOM")
	ok(M.sorted_order(d) == [1, 0, 2], "paint order sorts by z, stable on ties (authoring order)")
	ok(M.max_z(d) == 30, "max_z scans the placements")

	# --- ops ------------------------------------------------------------------------
	M.move(d, 1, Vector2(-10, 5.4))
	ok(int(d.placements[1].x) == 490 and int(d.placements[1].y) == 1105,
		"move offsets and rounds to whole pixels")
	M.set_pos(d, 1, Vector2(500, 1100))
	ok(int(d.placements[1].x) == 500 and int(d.placements[1].y) == 1100, "set_pos writes the anchor")
	M.scale_by(d, 0, 1.5)
	ok(int(d.placements[0].w) == 300 and int(d.placements[0].h) == 600,
		"scale_by resizes uniformly about the anchor")
	M.scale_by(d, 1, 0.001)
	ok(int(d.placements[1].w) >= 8 and int(d.placements[1].h) >= 8,
		"scale_by clamps at the minimum grabbable size")
	M.bump_z(d, 1, 25)
	ok(int(d.placements[1].z) == 35 and M.sorted_order(d) == [0, 2, 1],
		"bump_z reorders the paint order")
	M.bump_z(d, 1, -999)
	ok(int(d.placements[1].z) == 0, "bump_z floors at z 0")

	# --- add / remove / unique ids --------------------------------------------------
	var i := M.add_entry(d, {"id": "tree", "category": "prop", "image": "a.png", "x": 100, "y": 100, "w": 50, "h": 50})
	ok(String(d.placements[i].id) == "tree_2", "add_entry de-duplicates the id")
	ok(int(d.placements[i].z) == M.max_z(d) and int(d.placements[i].z) > 30,
		"an added entry defaults to the top z")
	var removed := M.remove_at(d, i)
	ok(String(removed.id) == "tree_2" and d.placements.size() == 3, "remove_at pops the entry")

	# --- hit-testing ----------------------------------------------------------------
	var d2 := _doc()
	var all_opaque := func(_i: int, _uv: Vector2) -> bool: return true
	ok(M.hit_at(d2, Vector2(510, 900), all_opaque) == 2,
		"hit_at returns the TOPMOST entry under the point")
	var gate_clear := func(pi: int, _uv: Vector2) -> bool: return pi != 2
	ok(M.hit_at(d2, Vector2(510, 900), gate_clear) == 0,
		"a transparent pixel falls through to the layer beneath")
	ok(M.hit_at(d2, Vector2(10, 10), all_opaque) == -1, "empty canvas → no hit")

	# --- save / load round-trip (with the one-time .bak) ----------------------------
	var dir := OS.get_user_data_dir() + "/scene_wb_test"
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir + "/placements.json"
	for stale in [path, path + ".bak"]:               # idempotent across runs — start from a clean slate
		if FileAccess.file_exists(stale):
			DirAccess.remove_absolute(stale)
	var d3 := _doc()
	d3["pipeline"] = {"mapMode": "scene_mode"}         # unknown top-level keys must survive
	ok(M.save_doc(path, d3), "save_doc writes the file")
	ok(not FileAccess.file_exists(path + ".bak"), "no backup on a first write (nothing to back up)")
	M.move(d3, 0, Vector2(1, 0))
	ok(M.save_doc(path, d3) and FileAccess.file_exists(path + ".bak"),
		"a re-save backs up the previous file once")
	var back := M.load_doc(path)
	ok(back.get("pipeline", {}).get("mapMode") == "scene_mode", "unknown keys round-trip through save")
	ok(back.placements.size() == 3 and int(back.placements[0].x) == 501,
		"placements round-trip through save/load")
	ok(M.load_doc(dir + "/nope.json").is_empty(), "a missing file loads as an empty doc")

	# --- path resolution ------------------------------------------------------------
	var sr := "/repo/games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1"
	ok(M.repo_root_of(sr) == "/repo", "repo_root_of strips the scenes suffix")
	ok(M.repo_root_of("/elsewhere/scenes") == "/elsewhere/scenes",
		"a custom root resolves relative to itself")

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
