extends "res://games/grove/tests/grove_test_base.gd"
## Grove scene coverage for cascade combos: the player drag path, cascade
## rewards, guide pads, ready outlines, and the code-level feature flag.

const CascadeOutline = preload("res://engine/scripts/ui/cascade_outline.gd")
const Improvements = preload("res://engine/scripts/core/improvements.gd")

func _initialize() -> void:
	begin("grove · cascade combos")
	await process_frame
	await _test_drag_merge_auto_runs_and_locks_input()
	await _test_cascade_watchdog_keeps_player_input_locked()
	await _test_magnet_holds_fire_while_cascade_runs()
	await _test_chain_bailouts_release_input_gate()
	await _test_chain_rewards_and_chest_open_clock()
	await _test_long_chain_rewards_upgrade_and_cap()
	await _test_drag_guide_pads_and_generator_exclusion()
	await _test_ready_outline_and_flag_off()
	await _test_landscape_outline_uses_transposed_edges()
	finish()

func _open_board(name: String) -> Node:
	fresh(name)
	Save.mark_board_tutorial_seen()
	Save.mark_ftue_seen("merge")
	Save.mark_ftue_seen("gen_tap")
	var b = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(b)
	return b

func _blank_fixture(b: Node, placements: Dictionary) -> void:
	for i in b.board.items.size():
		b.board.terrain[i] = 0
		b.board.items[i] = 0
	b.board.collect_rewards = {}
	b.board.gens = {}
	b.board.gen_tiers = {}
	b.board.gen_boost = {}
	b.quests = []
	for cell in placements:
		b.board.place(Vector2i(cell), int(placements[cell]))
	b._rebuild_all()
	_clear_rendered_generators(b)

func _clear_rendered_generators(b: Node) -> void:
	for n in b.gen_nodes.values():
		if n != null and is_instance_valid(n):
			(n as Node).queue_free()
	b.gen_nodes.clear()
	b.gen_node = null
	b.board.gens = {}
	b.board.gen_tiers = {}
	b.board.gen_boost = {}

func _drag_merge(b: Node, from: Vector2i, to: Vector2i) -> void:
	var half := Vector2(b.csz, b.csz) / 2.0
	b._on_press(b._cell_pos(from) + half)
	b._on_release(b._cell_pos(to) + half)

func _input_drag_merge(b: Node, from: Vector2i, to: Vector2i) -> void:
	var half := Vector2(b.csz, b.csz) / 2.0
	var start: Vector2 = b._cell_pos(from) + half
	var end: Vector2 = b._cell_pos(to) + half
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = start
	b._on_board_input(down)
	var move := InputEventMouseMotion.new()
	move.position = end
	b._on_board_input(move)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = end
	b._on_board_input(up)

func _wait_for_idle(b: Node, timeout: float = 2.0) -> void:
	var waited := 0.0
	while (bool(b.animating) or b.chain_running()) and waited < timeout:
		await create_timer(0.05).timeout
		waited += 0.05

func _wait_for_auto_step_in_flight(b: Node, frames: int = 90) -> bool:
	for _i in frames:
		if bool(b.get("_chain_auto_step")):
			return true
		await process_frame
	return false

func _ladder_fixture(length: int, col: int) -> Dictionary:
	var out := {}
	for row in length:
		var tier := 1 if row < 2 else row
		out[Vector2i(row, col)] = 100 + tier
	return out

func _outline(b: Node) -> Control:
	return b.board_area.get_node_or_null("CascadeOutline") as Control

func _outline_ladder_count(b: Node) -> int:
	var o := _outline(b)
	if o == null:
		return 0
	var ladders = o.get("ladders")
	return (ladders as Array).size() if ladders is Array else 0

func _outline_pad_count(b: Node) -> int:
	var o := _outline(b)
	if o == null:
		return 0
	var pads = o.get("ghost_pads")
	return (pads as Array).size() if pads is Array else 0

func _outline_has_tag(b: Node, text: String) -> bool:
	var o := _outline(b)
	if o == null:
		return false
	for raw in o.find_children("*", "Label", true, false):
		var lbl := raw as Label
		if lbl != null and lbl.text == text:
			return true
	return false

func _landscape_outline_pos(cell: Vector2i) -> Vector2:
	var step := 44.0
	return Vector2(cell.x * step, cell.y * step)

func _segment_is_vertical(seg: Array) -> bool:
	return seg.size() == 2 and is_equal_approx(Vector2(seg[0]).x, Vector2(seg[1]).x) \
		and not is_equal_approx(Vector2(seg[0]).y, Vector2(seg[1]).y)

func _segment_is_horizontal(seg: Array) -> bool:
	return seg.size() == 2 and is_equal_approx(Vector2(seg[0]).y, Vector2(seg[1]).y) \
		and not is_equal_approx(Vector2(seg[0]).x, Vector2(seg[1]).x)

func _test_drag_merge_auto_runs_and_locks_input() -> void:
	var b := _open_board("cascade_auto_run")
	await process_frame
	_blank_fixture(b, {
		Vector2i(3, 1): 101,
		Vector2i(3, 2): 101,
		Vector2i(3, 3): 102,
	})
	_drag_merge(b, Vector2i(3, 1), Vector2i(3, 2))
	ok(b.chain_running() and b.animating, "a tipped ready ladder exposes chain_running and keeps input locked")
	ok(await _wait_for_auto_step_in_flight(b), "the auto-step stays in flight long enough to render its slide")
	await _wait_for_idle(b)
	ok(not b.animating and not b.chain_running(), "input unlocks after the cascade finishes")
	ok(b.board.item_at(Vector2i(3, 3)) == 103 and b.board.item_at(Vector2i(3, 1)) == 0, \
		"the auto-step slides the upgraded item along the partner path")
	ok(b.board.item_at(Vector2i(3, 2)) == G.COIN_LINE * 100 + 1, \
		"reaching x2 births a coin on the vacated result cell")
	b.queue_free()

func _test_cascade_watchdog_keeps_player_input_locked() -> void:
	var b := _open_board("cascade_watchdog_gate")
	await process_frame
	var col := 5
	var fixture := _ladder_fixture(8, col)
	fixture[Vector2i(8, 0)] = 201
	fixture[Vector2i(8, 1)] = 201
	_blank_fixture(b, fixture)
	_input_drag_merge(b, Vector2i(0, col), Vector2i(1, col))
	ok(await _wait_for_auto_step_in_flight(b), "long cascade reaches an auto-step before the watchdog probe")
	b._process(0.61)
	ok(b.animating and b.chain_running(), "cascade watchdog keeps input locked past the single-merge timeout")
	_input_drag_merge(b, Vector2i(8, 0), Vector2i(8, 1))
	ok(b.board.item_at(Vector2i(8, 0)) == 201 and b.board.item_at(Vector2i(8, 1)) == 201, \
		"player input on an unrelated pair is ignored while a cascade is active")
	await _wait_for_idle(b, 4.0)
	ok(b.board.item_at(Vector2i(7, col)) == 108 and b.board.item_at(Vector2i(2, col)) == 1005, \
		"the locked cascade completes its queued steps and final chest reward")
	b.queue_free()

func _test_magnet_holds_fire_while_cascade_runs() -> void:
	var b := _open_board("cascade_magnet_hold_fire")
	await process_frame
	var col := 2
	var magnet := Vector2i(4, col + 1)
	_blank_fixture(b, {
		Vector2i(3, col - 1): 101,
		Vector2i(3, col): 101,
		Vector2i(3, col + 1): 102,
		Vector2i(3, col + 2): 103,
	})
	ok(b.board.build_improvement(magnet, Improvements.KIND_MAGNET), "fixture places a magnet whose 3x3 covers the cascade ladder")
	b._rebuild_all()
	_input_drag_merge(b, Vector2i(3, col - 1), Vector2i(3, col))
	await _wait_for_idle(b, 4.0)
	ok(b.board.item_at(Vector2i(3, col + 2)) == 104,
		"a magnet beside the ladder does not consume the cascade partner before the queued auto-steps finish")
	ok(b.board.item_at(Vector2i(3, col + 1)) == 1001,
		"the protected run still grants its x3 cascade chest reward")
	b.queue_free()

func _test_chain_bailouts_release_input_gate() -> void:
	var b1 := _open_board("cascade_empty_bailout")
	await process_frame
	_blank_fixture(b1, {Vector2i(3, 1): 101})
	b1.animating = true
	b1.set("_chain_active", true)
	b1.set("_chain_run", [])
	b1._run_chain_step(Vector2i(3, 1))
	ok(not b1.animating and not b1.chain_running(), "an empty queued cascade bailout releases the input gate")
	b1.queue_free()

	var b2 := _open_board("cascade_invalid_partner_bailout")
	await process_frame
	_blank_fixture(b2, {
		Vector2i(3, 1): 102,
		Vector2i(3, 2): 104,
	})
	b2.animating = true
	b2.set("_chain_active", true)
	b2.set("_chain_run", [Vector2i(3, 2)])
	b2._run_chain_step(Vector2i(3, 1))
	ok(not b2.animating and not b2.chain_running(), "an invalid-partner cascade bailout releases the input gate")
	b2.queue_free()

func _test_chain_rewards_and_chest_open_clock() -> void:
	var b3 := _open_board("cascade_rewards_x3")
	await process_frame
	_blank_fixture(b3, {
		Vector2i(2, 1): 101,
		Vector2i(2, 2): 101,
		Vector2i(2, 3): 102,
		Vector2i(2, 4): 103,
	})
	_drag_merge(b3, Vector2i(2, 1), Vector2i(2, 2))
	await _wait_for_idle(b3)
	ok(b3.board.item_at(Vector2i(2, 2)) == G.COIN_LINE * 100 + 1, "x2 leaves the coin reward")
	ok(b3.board.item_at(Vector2i(2, 3)) == 1001, "x3 births a tier-1 chest on that step's vacated cell")
	b3.queue_free()

	var b4 := _open_board("cascade_rewards_x4")
	await process_frame
	_blank_fixture(b4, {
		Vector2i(3, 1): 101,
		Vector2i(3, 2): 101,
		Vector2i(3, 3): 102,
		Vector2i(3, 4): 103,
		Vector2i(3, 5): 104,
	})
	var wallet0 := Save.coins()
	var clock0 := Save.coins_earned_lifetime()
	var acorns0 := Save.diamonds()
	_drag_merge(b4, Vector2i(3, 1), Vector2i(3, 2))
	await _wait_for_idle(b4)
	ok(b4.board.item_at(Vector2i(3, 3)) == 1002, "x4 upgrades the run chest in place to tier 2")
	ok(Save.coins() == wallet0 and Save.diamonds() == acorns0 and Save.coins_earned_lifetime() == clock0, \
		"cascade reward pieces do not credit the wallet or quest clock before chest-open")
	var chest_pos: Vector2 = b4._cell_pos(Vector2i(3, 3)) + Vector2(b4.csz, b4.csz) / 2.0
	b4._on_press(chest_pos)
	b4._on_release(chest_pos)
	b4._on_press(chest_pos)
	b4._on_release(chest_pos)
	await create_timer(0.1).timeout
	ok(Save.coins() == wallet0 + int(G.chest_open_reward(1002).coins), "opening the cascade chest credits spendable coins")
	ok(Save.diamonds() == acorns0 + int(G.chest_open_reward(1002).acorns), "opening the cascade chest credits acorns")
	ok(Save.coins_earned_lifetime() == clock0, "opening a cascade chest does not move the quest coin clock")
	b4.queue_free()

func _test_long_chain_rewards_upgrade_and_cap() -> void:
	var col := 5
	for spec in [
		{"name": "cascade_rewards_x5", "length": 6, "want": 1003, "label": "x5 upgrades the run chest to tier 3"},
		{"name": "cascade_rewards_x6", "length": 7, "want": 1004, "label": "x6 upgrades the run chest to tier 4"},
		{"name": "cascade_rewards_x7_cap", "length": 9, "want": 1005, "label": "x7+ caps the run chest at tier 5"},
	]:
		var b := _open_board(String(spec.name))
		await process_frame
		_blank_fixture(b, _ladder_fixture(int(spec.length), col))
		_drag_merge(b, Vector2i(0, col), Vector2i(1, col))
		await _wait_for_idle(b, 4.0)
		ok(b.board.item_at(Vector2i(2, col)) == int(spec.want), String(spec.label))
		b.queue_free()

func _test_drag_guide_pads_and_generator_exclusion() -> void:
	var b := _open_board("cascade_drag_guides")
	await process_frame
	var from := Vector2i(6, 6)
	_blank_fixture(b, {
		from: 101,
		Vector2i(2, 1): 101,
		Vector2i(2, 3): 102,
	})
	var half := Vector2(b.csz, b.csz) / 2.0
	b._on_press(b._cell_pos(from) + half)
	b._begin_drag()
	await process_frame
	ok(_outline_pad_count(b) == 1, "beginning an item drag shows one cascade ghost pad")
	var old_outline := _outline(b)
	if old_outline != null:
		b.board_area.remove_child(old_outline)
		old_outline.queue_free()
		b.set("_cascade_outline", null)
	b._show_cascade_drag_guides(from)
	var recreated := _outline(b)
	var first_piece_index := 9999
	for raw_node in b.piece_nodes.values():
		var pn := raw_node as Node
		if pn != null and is_instance_valid(pn):
			first_piece_index = mini(first_piece_index, pn.get_index())
	ok(recreated != null and recreated.get_index() < first_piece_index, \
		"drag-guide creation keeps the cascade outline below pieces")
	b._on_release(b._cell_pos(from) + half)
	await process_frame
	ok(_outline_pad_count(b) == 0, "releasing the item clears cascade ghost pads")

	_blank_fixture(b, {})
	var gen_cell := Vector2i(4, 3)
	b.board.place_gen("gen_1", gen_cell)
	b._rebuild_all()
	b._on_press(b._cell_pos(gen_cell) + half)
	b._begin_drag()
	await process_frame
	ok(_outline_pad_count(b) == 0, "generator drags do not show cascade ghost pads")
	b._on_release(b._cell_pos(gen_cell) + half)
	b.queue_free()

func _test_ready_outline_and_flag_off() -> void:
	var original := bool(Feat.FLAGS.get("cascade", true))
	Feat.FLAGS["cascade"] = true
	var b := _open_board("cascade_outline")
	await process_frame
	_blank_fixture(b, {
		Vector2i(3, 1): 101,
		Vector2i(3, 2): 101,
		Vector2i(3, 3): 102,
	})
	ok(_outline_ladder_count(b) == 1, "a ready ladder draws one cascade outline")
	ok(_outline_has_tag(b, "×2"), "the ready ladder tags its best chain length")
	b.board.place(Vector2i(3, 3), 0)
	b._rebuild_all()
	ok(_outline_ladder_count(b) == 0, "removing the upgraded rung clears the cascade outline")
	b.queue_free()

	Feat.FLAGS["cascade"] = false
	var off := _open_board("cascade_flag_off")
	await process_frame
	_blank_fixture(off, {
		Vector2i(3, 1): 101,
		Vector2i(3, 2): 101,
		Vector2i(3, 3): 102,
	})
	ok(_outline_ladder_count(off) == 0, "flag OFF suppresses ready outlines")
	_drag_merge(off, Vector2i(3, 1), Vector2i(3, 2))
	await _wait_for_idle(off)
	ok(off.board.item_at(Vector2i(3, 2)) == 102 and off.board.item_at(Vector2i(3, 3)) == 102, \
		"flag OFF keeps today's single merge behavior with no auto-step")
	var half := Vector2(off.csz, off.csz) / 2.0
	off._on_press(off._cell_pos(Vector2i(3, 2)) + half)
	off._begin_drag()
	await process_frame
	ok(_outline_pad_count(off) == 0, "flag OFF suppresses drag guide pads")
	off._on_release(off._cell_pos(Vector2i(3, 2)) + half)
	off.queue_free()
	Feat.FLAGS["cascade"] = original

func _test_landscape_outline_uses_transposed_edges() -> void:
	var outline := CascadeOutline.new()
	outline.configure(Vector2(240, 260), 40.0, Callable(self, "_landscape_outline_pos"))
	var has_edges := outline.has_method("_perimeter_edge_segment")
	var row_minus: Array = outline.call("_perimeter_edge_segment", Vector2i(3, 2), Vector2i(-1, 0)) if has_edges else []
	var col_minus: Array = outline.call("_perimeter_edge_segment", Vector2i(3, 2), Vector2i(0, -1)) if has_edges else []
	ok(_segment_is_vertical(row_minus) and _segment_is_horizontal(col_minus), \
		"landscape outline maps model neighbours through the transposed cell geometry")
	outline.free()
