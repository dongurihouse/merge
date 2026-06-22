extends "res://games/grove/tests/grove_test_base.gd"
## grove · vine tool — the authoring tool (vine_mask_tool.gd) is now MANUAL-ONLY: regions are
## hand-drawn polygons (no mask auto-detection), each carrying an order (list position) and a
## stars cost. Drives the tool scene headlessly through its public editing API.

const TOOL_SCENE := "res://games/tools/vine_mask_tool/VineMaskTool.tscn"

func _initialize() -> void:
	begin("grove · vine tool")
	await _test_manual_only_chrome()
	await _test_add_and_delete()
	await _test_reorder_carries_cost()
	await _test_stars_field()
	await _test_save_reload_round_trip()
	await _test_legacy_cost_defaults_to_ladder()
	await _test_draw_in_editor()
	finish()

func _make_tool() -> Node:
	var packed := load(TOOL_SCENE) as PackedScene
	var scene := packed.instantiate()
	get_root().add_child(scene)
	await process_frame
	await process_frame
	return scene

# Manual-only: the mask auto-detection is gone — there is NO "Auto Detect" button, and the tool
# surfaces a draw affordance + a region list instead of the old region dropdown.
func _test_manual_only_chrome() -> void:
	var scene := await _make_tool()
	ok(scene.find_child("AutoDetectRegions", true, false) == null, "the Auto Detect button is gone (manual-only)")
	ok(scene.find_child("DrawPolygon", true, false) != null, "the tool has a Draw Polygon affordance")
	ok(scene.find_child("RegionList", true, false) != null, "the tool shows a region list")
	scene.queue_free()

# add_region appends a hand-drawn polygon (count grows); delete_region removes one (count shrinks).
func _test_add_and_delete() -> void:
	var scene := await _make_tool()
	var before: int = scene.get_region_count()
	scene.add_region([Vector2(100, 100), Vector2(200, 100), Vector2(200, 200), Vector2(100, 200)], 4, "Drawn")
	await process_frame
	ok(scene.get_region_count() == before + 1, "add_region appends a polygon (count grows)")
	ok(scene.get_region_point_count(before) == 4, "the new polygon keeps the 4 drawn vertices")
	scene.delete_region(before)
	await process_frame
	ok(scene.get_region_count() == before, "delete_region removes the polygon (count shrinks)")
	scene.queue_free()

# Reordering moves a region's whole record — its cost travels with it (order = list position).
# Moving region 0 to index 1 puts the old region 1 first and region 0 second, costs in tow.
func _test_reorder_carries_cost() -> void:
	var scene := await _make_tool()
	scene.set_region_cost(0, 7)
	scene.set_region_cost(1, 2)
	scene.reorder_region(0, 1)            # move region 0 to index 1
	await process_frame
	ok(scene.get_region_cost(0) == 2, "the region that was at index 1 (cost 2) is now first")
	ok(scene.get_region_cost(1) == 7, "the moved region carries its cost (7) to its new position")
	scene.queue_free()

# Stars are an editable per-polygon integer, read back through the same API.
func _test_stars_field() -> void:
	var scene := await _make_tool()
	scene.set_region_cost(0, 5)
	ok(scene.get_region_cost(0) == 5, "set_region_cost / get_region_cost round-trip in memory")
	scene.queue_free()

# Save → reload round-trips the per-region cost AND a DYNAMIC region count (no fixed-8 guard): the
# tool writes cost into the regions JSON and reads back whatever count the file holds.
func _test_save_reload_round_trip() -> void:
	var scene := await _make_tool()
	var temp := "user://vine_tool_roundtrip.json"
	scene.set("regions_path", temp)
	scene.add_region([Vector2(10, 10), Vector2(60, 10), Vector2(60, 60), Vector2(10, 60)], 9, "Extra")
	var n: int = scene.get_region_count()
	scene.set_region_cost(0, 6)
	scene.call("_save_regions_to_file")
	await process_frame
	# parse the written file directly — the cost + dynamic count must be on disk
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path(temp)))
	ok(typeof(parsed) == TYPE_DICTIONARY, "the saved file is valid JSON")
	var saved_regions: Array = (parsed as Dictionary).get("regions", [])
	ok(saved_regions.size() == n, "the file holds the dynamic region count (not a fixed 8)")
	ok(int((saved_regions[0] as Dictionary).get("cost", -1)) == 6, "region 0's cost is written to disk")
	ok(int((saved_regions[n - 1] as Dictionary).get("cost", -1)) == 9, "the drawn region's cost is written to disk")
	# load path: no count guard — it returns exactly what the file holds
	scene.set("regions", scene.call("_load_saved_regions"))
	ok(scene.get("regions").size() == n, "_load_saved_regions returns the file's count verbatim (guard dropped)")
	ok(int((scene.get("regions")[0] as Dictionary).get("cost", -1)) == 6, "the loaded region carries its saved cost")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(temp))
	scene.queue_free()

# Legacy regions files (authored before the stars field existed) seed each polygon's stars from the
# cost ladder by index, so opening + re-saving an old map preserves its current in-game costs instead
# of silently flattening them. map1_farm's committed file has no `cost` fields.
func _test_legacy_cost_defaults_to_ladder() -> void:
	var scene := await _make_tool()
	ok(scene.get_region_cost(0) == 3, "legacy region 0 defaults to ladder 3")
	ok(scene.get_region_cost(3) == 4, "legacy region 3 defaults to ladder 4")
	ok(scene.get_region_cost(7) == 5, "legacy region 7 defaults to ladder 5")
	scene.queue_free()

# Drawing in the editor: in draw mode, clicks place vertices and a click near the first vertex closes
# the polygon, which adds a region to the tool.
func _test_draw_in_editor() -> void:
	var scene := await _make_tool()
	var editor := scene.find_child("RegionEditor", true, false)
	ok(editor != null and editor.has_method("set_draw_mode"), "the region editor exposes a draw mode")
	var before: int = scene.get_region_count()
	editor.call("set_draw_mode", true)
	_editor_click(editor, Vector2(120, 120))
	_editor_click(editor, Vector2(320, 120))
	_editor_click(editor, Vector2(320, 320))
	_editor_click(editor, Vector2(123, 123))   # near the first vertex → closes the polygon
	await process_frame
	ok(scene.get_region_count() == before + 1, "closing a drawn polygon adds a region to the tool")
	scene.queue_free()

func _editor_click(editor: Node, at: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = at
	editor._gui_input(down)
