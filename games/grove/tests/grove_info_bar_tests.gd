extends "res://games/grove/tests/grove_test_base.gd"
## grove · info bar — focused tests for player-facing selected-item copy.

func _initialize() -> void:
	begin("grove · info bar")

	var content := G.new()
	var has_copy_helpers := content.has_method("item_display_name") and content.has_method("item_description")
	ok(has_copy_helpers, "content exposes canonical item display-name and description helpers")
	if has_copy_helpers:
		ok(content.call("item_display_name", 6101) == "Hearth embers", "regular lines keep their authored display names")
		ok(String(content.call("item_description", 6101)).contains("early quests"), "regular lines carry a player-useful hint")
		ok(content.call("item_display_name", 1201) == "Water drop", "special drops have real display names")
		ok(String(content.call("item_description", 1202)).contains("20 water"), "collectable special drops describe their tier reward")
		ok(content.call("item_display_name", 1501) == "Wildcard", "wildcards have a real display name")
		ok(String(content.call("item_description", 1501)).contains("same-tier"), "wildcards explain their drag rule")
		ok(content.call("item_display_name", 902) == "Coin", "coin items have a real display name")
		ok(String(content.call("item_description", 902)).contains("5 coins"), "coin items explain their collect value")

	fresh("info_bar_copy")
	var board_scene = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(board_scene)
	await process_frame
	if board_scene.board == null:
		board_scene._ready()
	await create_timer(0.05).timeout

	var cell := Vector2i(-1, -1)
	for c in board_scene.board.empty_ground_cells():
		if not board_scene.board.is_gen(c):
			cell = c
			break
	ok(cell.x >= 0, "the focused info-bar test found an empty board cell")
	if cell.x >= 0:
		board_scene.board.place(cell, 1201)
		board_scene._rebuild_pieces()
		board_scene._select_item(cell)
		ok(board_scene._info_label.text == "Water drop · Tier 1", "the info bar names special drops instead of falling back to Item")
		var desc_label: Label = board_scene.get("_info_desc_label") as Label
		ok(desc_label != null and desc_label.visible and desc_label.text.contains("8 water"), "the info bar shows the selected item's useful hint")

	board_scene.queue_free()
	board_scene = null
	content = null
	await process_frame
	await process_frame
	finish()
