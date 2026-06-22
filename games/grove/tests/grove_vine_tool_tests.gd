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
	await _test_button_place_and_reset()
	await _test_button_save_reload()
	await _test_delete_all_regions()
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
# Self-contained: builds its own two polygons so it never depends on the live map's authored content.
func _test_reorder_carries_cost() -> void:
	var scene := await _make_tool()
	_clear_regions(scene)
	scene.add_region([Vector2(10, 10), Vector2(60, 10), Vector2(60, 60), Vector2(10, 60)], 7, "A")
	scene.add_region([Vector2(70, 70), Vector2(120, 70), Vector2(120, 120), Vector2(70, 120)], 2, "B")
	scene.reorder_region(0, 1)            # move region 0 (cost 7) to index 1
	await process_frame
	ok(scene.get_region_cost(0) == 2, "the region that was at index 1 (cost 2) is now first")
	ok(scene.get_region_cost(1) == 7, "the moved region carries its cost (7) to its new position")
	scene.queue_free()

# Stars are an editable per-polygon integer, read back through the same API.
func _test_stars_field() -> void:
	var scene := await _make_tool()
	_clear_regions(scene)
	scene.add_region([Vector2(10, 10), Vector2(60, 10), Vector2(60, 60), Vector2(10, 60)], 3, "A")
	scene.set_region_cost(0, 5)
	ok(scene.get_region_cost(0) == 5, "set_region_cost / get_region_cost round-trip in memory")
	scene.queue_free()

# Save → reload round-trips the per-region cost AND a DYNAMIC region count (no fixed-8 guard): the
# tool writes cost into the regions JSON and reads back whatever count the file holds. Self-contained.
func _test_save_reload_round_trip() -> void:
	var scene := await _make_tool()
	_clear_regions(scene)
	scene.add_region([Vector2(10, 10), Vector2(60, 10), Vector2(60, 60), Vector2(10, 60)], 3, "First")
	var temp := "user://vine_tool_roundtrip.json"
	scene.set("regions_path", temp)
	scene.add_region([Vector2(80, 80), Vector2(140, 80), Vector2(140, 140), Vector2(80, 140)], 9, "Extra")
	var n: int = scene.get_region_count()
	scene.set_region_cost(0, 6)
	scene.call("_save_regions_to_file")
	await process_frame
	# parse the written file directly — the cost + dynamic count must be on disk
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path(temp)))
	ok(typeof(parsed) == TYPE_DICTIONARY, "the saved file is valid JSON")
	var saved_regions: Array = (parsed as Dictionary).get("regions", [])
	ok(saved_regions.size() == n, "the file holds the dynamic region count")
	ok(int((saved_regions[0] as Dictionary).get("cost", -1)) == 6, "region 0's cost is written to disk")
	ok(int((saved_regions[n - 1] as Dictionary).get("cost", -1)) == 9, "the drawn region's cost is written to disk")
	# load path: no count guard — it returns exactly what the file holds
	scene.set("regions", scene.call("_load_saved_regions"))
	ok(scene.get("regions").size() == n, "_load_saved_regions returns the file's count verbatim (guard dropped)")
	ok(int((scene.get("regions")[0] as Dictionary).get("cost", -1)) == 6, "the loaded region carries its saved cost")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(temp))
	scene.queue_free()

# A legacy regions file (authored before the stars field existed) seeds each polygon's stars from the
# cost ladder by index, so opening + re-saving an old map preserves its current in-game costs instead
# of silently flattening them. Driven through a dedicated cost-less fixture (the live maps are now
# hand-authored, so they no longer make a stable legacy case).
func _test_legacy_cost_defaults_to_ladder() -> void:
	var scene := await _make_tool()
	scene.set("regions_path", "res://games/grove/tests/fixtures/legacy_regions.json")
	var loaded: Array = scene.call("_load_saved_regions")
	ok(loaded.size() >= 8, "the legacy fixture loads its regions")
	ok(int((loaded[0] as Dictionary).get("cost")) == 3, "legacy region 0 defaults to ladder 3")
	ok(int((loaded[3] as Dictionary).get("cost")) == 4, "legacy region 3 defaults to ladder 4")
	ok(int((loaded[7] as Dictionary).get("cost")) == 5, "legacy region 7 defaults to ladder 5")
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

# Deleting every polygon clears the canvas (regions -> empty). The renderer must survive that, and a
# fresh polygon can be drawn afterward. Regression for the out-of-bounds crash on delete-to-empty.
func _test_delete_all_regions() -> void:
	var scene := await _make_tool()
	var guard := 0
	while scene.get_region_count() > 0 and guard < 64:
		scene.delete_region(0)
		guard += 1
	await process_frame
	ok(scene.get_region_count() == 0, "deleting every polygon leaves zero regions without crashing")
	scene.add_region([Vector2(40, 40), Vector2(120, 40), Vector2(120, 120), Vector2(40, 120)], 3, "Fresh")
	await process_frame
	ok(scene.get_region_count() == 1, "a new polygon can be drawn after clearing the canvas")
	scene.queue_free()

# Dragging a region's unlock-disc marker (which sits at the centroid by default) places its `button`;
# right-clicking the marker resets it to auto (the button is erased). Drives the overlay through input.
func _test_button_place_and_reset() -> void:
	var scene := await _make_tool()
	_clear_regions(scene)
	scene.add_region([Vector2(10, 10), Vector2(60, 10), Vector2(60, 60), Vector2(10, 60)], 3, "A")  # centroid (35,35)
	await process_frame
	var editor := scene.find_child("RegionEditor", true, false)
	editor.call("set_edit_enabled", true)
	editor.call("set_draw_mode", false)
	_drag(editor, Vector2(35, 35), Vector2(200, 300))   # grab the centroid marker, drop at (200,300)
	await process_frame
	var region: Dictionary = scene.get("regions")[0]
	ok(region.has("button"), "dragging the marker sets the region's button")
	ok(region.has("button") and (region["button"] as Vector2).distance_to(Vector2(200, 300)) < 1.0, "the button lands where the marker was dropped")
	_right_click(editor, Vector2(200, 300))             # right-click the marker → reset to auto
	await process_frame
	ok(not (scene.get("regions")[0] as Dictionary).has("button"), "right-clicking the marker resets the button to auto (centroid)")
	scene.queue_free()

# A placed button persists to disk as an [x,y] pair and reloads as a Vector2; a region with no button
# writes none (so the game keeps using the centroid).
func _test_button_save_reload() -> void:
	var scene := await _make_tool()
	_clear_regions(scene)
	scene.add_region([Vector2(10, 10), Vector2(60, 10), Vector2(60, 60), Vector2(10, 60)], 3, "Placed")
	scene.add_region([Vector2(80, 80), Vector2(140, 80), Vector2(140, 140), Vector2(80, 140)], 4, "Auto")
	var rs: Array = scene.get("regions")
	(rs[0] as Dictionary)["button"] = Vector2(123, 456)
	scene.set("regions", rs)
	var temp := "user://vine_button_roundtrip.json"
	scene.set("regions_path", temp)
	scene.call("_save_regions_to_file")
	await process_frame
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path(temp)))
	var saved: Array = (parsed as Dictionary).get("regions", [])
	var b0: Variant = (saved[0] as Dictionary).get("button", null)
	ok(b0 is Array and int(b0[0]) == 123 and int(b0[1]) == 456, "a placed button is written as [123,456]")
	ok(not (saved[1] as Dictionary).has("button"), "a region with no button writes none (game uses the centroid)")
	var loaded: Array = scene.call("_load_saved_regions")
	ok((loaded[0] as Dictionary).get("button") is Vector2, "the button reloads as a Vector2")
	ok(((loaded[0] as Dictionary).get("button") as Vector2).distance_to(Vector2(123, 456)) < 1.0, "the reloaded button keeps its position")
	ok(not (loaded[1] as Dictionary).has("button"), "the auto region stays auto on reload")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(temp))
	scene.queue_free()

func _clear_regions(scene: Node) -> void:
	var guard := 0
	while scene.get_region_count() > 0 and guard < 128:
		scene.delete_region(0)
		guard += 1

func _editor_click(editor: Node, at: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = at
	editor._gui_input(down)

# Left-press at `from`, move to `to`, release: a marker/vertex drag.
func _drag(editor: Node, from: Vector2, to: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = from
	editor._gui_input(down)
	var move := InputEventMouseMotion.new()
	move.position = to
	editor._gui_input(move)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = to
	editor._gui_input(up)

func _right_click(editor: Node, at: Vector2) -> void:
	var rc := InputEventMouseButton.new()
	rc.button_index = MOUSE_BUTTON_RIGHT
	rc.pressed = true
	rc.position = at
	editor._gui_input(rc)
