extends "res://games/grove/tests/grove_test_base.gd"
## Grove scene coverage for cascade combos: the player drag path, cascade
## rewards, guide pads, ready outlines, and the code-level feature flag.

const BoardScriptRef = preload("res://engine/scripts/scenes/board.gd")
const RNG_SEED := 20260727   # any fixed value; the point is that it does not change between runs
const CascadeOutline = preload("res://engine/scripts/ui/cascade_outline.gd")
const Improvements = preload("res://engine/scripts/core/improvements.gd")

func _initialize() -> void:
	begin("grove · cascade combos")
	await process_frame
	await _test_x2_ladder_does_not_arm_cascade()
	await _test_drag_merge_auto_runs_and_locks_input()
	await _test_preroll_delays_first_auto_step_and_telegraphs_run()
	await _test_chain_step_timing_ramps()
	await _test_chain_counter_anchors_at_run_origin()
	await _test_chain_lock_dim_covers_the_run()
	await _test_cascade_watchdog_keeps_player_input_locked()
	await _test_magnet_holds_fire_while_cascade_runs()
	await _test_chain_bailouts_release_input_gate()
	await _test_chain_rewards_and_chest_open_clock()
	await _test_long_chain_rewards_upgrade_and_cap()
	await _test_drag_guide_pads_and_generator_exclusion()
	await _test_drag_merge_targets_are_highlighted()
	await _test_runway_resting_outline_and_tag()
	await _test_one_tag_per_cell_when_marks_collide()
	await _test_runway_drag_guide_strengths_use_real_input()
	await _test_ready_outline_stays_between_slots_and_pieces_with_stale_generator_nodes()
	await _test_ready_outline_and_flag_off()
	_test_ribbon_covers_bends_branches_and_rings()
	await _test_landscape_outline_uses_transposed_edges()
	BoardScriptRef.forced_rng_seed = -1        # leave the static as we found it
	finish()

func _open_board(name: String) -> Node:
	fresh(name)
	BoardScriptRef.forced_rng_seed = RNG_SEED   # a fresh save would rng.randomize(); drops must not vary per run
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

func _input_begin_drag(b: Node, from: Vector2i) -> void:
	var half := Vector2(b.csz, b.csz) / 2.0
	var start: Vector2 = b._cell_pos(from) + half
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = start
	b._on_board_input(down)
	var move := InputEventMouseMotion.new()
	move.position = start + Vector2(b._drag_slop_px() + 8.0, 0.0)
	b._on_board_input(move)

func _input_release(b: Node, cell: Vector2i) -> void:
	var half := Vector2(b.csz, b.csz) / 2.0
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = b._cell_pos(cell) + half
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

func _outline_runway_count(b: Node) -> int:
	var o := _outline(b)
	if o == null:
		return 0
	var runways = o.get("runways")
	return (runways as Array).size() if runways is Array else 0

func _outline_pad_count(b: Node) -> int:
	var o := _outline(b)
	if o == null:
		return 0
	var pads = o.get("ghost_pads")
	return (pads as Array).size() if pads is Array else 0

func _outline_pad_count_by_kind(b: Node, kind: String) -> int:
	var o := _outline(b)
	if o == null:
		return 0
	var pads = o.get("ghost_pads")
	var count := 0
	if pads is Array:
		for raw in pads:
			if raw is Dictionary and String((raw as Dictionary).get("kind", "")) == kind:
				count += 1
	return count

func _outline_pad_cells_by_kind(b: Node, kind: String) -> Array:
	var out: Array = []
	var o := _outline(b)
	if o == null:
		return out
	var pads = o.get("ghost_pads")
	if pads is Array:
		for raw in pads:
			if raw is Dictionary and String((raw as Dictionary).get("kind", "")) == kind:
				out.append(Vector2i((raw as Dictionary).get("cell", Vector2i(-1, -1))))
	return out

func _outline_has_pad_kind_at(b: Node, kind: String, cell: Vector2i) -> bool:
	var o := _outline(b)
	if o == null:
		return false
	var pads = o.get("ghost_pads")
	if pads is Array:
		for raw in pads:
			if raw is Dictionary \
					and String((raw as Dictionary).get("kind", "")) == kind \
					and Vector2i((raw as Dictionary).get("cell", Vector2i(-1, -1))) == cell:
				return true
	return false

# Count only the ×n chips. The runway's needed-tier chip ("t2") is a different statement and
# must not be mistaken for a cascade promise — that conflation is the bug this grammar fixes.
func _outline_number_tag_count(b: Node) -> int:
	var o := _outline(b)
	if o == null:
		return 0
	var n := 0
	for raw in o.find_children("*", "Label", true, false):
		var lbl := raw as Label
		if lbl != null and lbl.text.begins_with("×"):
			n += 1
	return n

func _outline_has_tag(b: Node, text: String) -> bool:
	var o := _outline(b)
	if o == null:
		return false
	for raw in o.find_children("*", "Label", true, false):
		var lbl := raw as Label
		if lbl != null and not lbl.is_queued_for_deletion() and lbl.text == text:
			return true
	return false

func _outline_stack_is_visible_between_board_and_items(b: Node) -> bool:
	var o := _outline(b)
	if o == null or o.is_queued_for_deletion():
		return false
	var base_max := -1
	for raw_node in b.slot_nodes.values():
		var n := raw_node as Node
		if n != null and is_instance_valid(n) and not n.is_queued_for_deletion():
			base_max = maxi(base_max, n.get_index())
	for raw_child in b.board_area.get_children():
		var c := raw_child as Control
		if c != null and c != o and not c.is_queued_for_deletion() and c.position.x < 0.0 and c.position.y < 0.0:
			base_max = maxi(base_max, c.get_index())
	var item_min := 9999
	for raw_node in b.gen_nodes.values() + b.piece_nodes.values():
		var n := raw_node as Node
		if n != null and is_instance_valid(n) and not n.is_queued_for_deletion() and n.get_parent() == b.board_area:
			item_min = mini(item_min, n.get_index())
	return o.get_index() > base_max and o.get_index() < item_min

func _landscape_outline_pos(cell: Vector2i) -> Vector2:
	var step := 44.0
	return Vector2(cell.x * step, cell.y * step)

func _segment_is_vertical(seg: Array) -> bool:
	return seg.size() == 2 and is_equal_approx(Vector2(seg[0]).x, Vector2(seg[1]).x) \
		and not is_equal_approx(Vector2(seg[0]).y, Vector2(seg[1]).y)

func _segment_is_horizontal(seg: Array) -> bool:
	return seg.size() == 2 and is_equal_approx(Vector2(seg[0]).y, Vector2(seg[1]).y) \
		and not is_equal_approx(Vector2(seg[0]).x, Vector2(seg[1]).x)

func _test_x2_ladder_does_not_arm_cascade() -> void:
	var b := _open_board("cascade_x2_does_not_arm")
	await process_frame
	_blank_fixture(b, {
		Vector2i(3, 1): 101,
		Vector2i(3, 2): 101,
		Vector2i(3, 3): 102,
	})
	ok(_outline_ladder_count(b) == 0, "a x2-only ladder does not draw a cascade telegraph")
	_drag_merge(b, Vector2i(3, 1), Vector2i(3, 2))
	await _wait_for_idle(b)
	ok(not b.chain_running() and b.board.item_at(Vector2i(3, 2)) == 102 and b.board.item_at(Vector2i(3, 3)) == 102, \
		"a x2-only ladder resolves as an ordinary merge and does not arm a cascade")
	b.queue_free()

func _test_drag_merge_auto_runs_and_locks_input() -> void:
	var b := _open_board("cascade_auto_run")
	await process_frame
	_blank_fixture(b, {
		Vector2i(3, 1): 101,
		Vector2i(3, 2): 101,
		Vector2i(3, 3): 102,
		Vector2i(3, 4): 103,
	})
	_drag_merge(b, Vector2i(3, 1), Vector2i(3, 2))
	ok(b.chain_running() and b.animating, "a tipped ready ladder exposes chain_running and keeps input locked")
	ok(await _wait_for_auto_step_in_flight(b), "the auto-step stays in flight long enough to render its slide")
	await _wait_for_idle(b, 3.0)
	ok(not b.animating and not b.chain_running(), "input unlocks after the cascade finishes")
	# The source must no longer hold the LINE's piece. Not `== 0`: the ordinary 10% merge coin-drop
	# picks among the 3 cells nearest the merge, and the just-vacated source is one of them, so a
	# stray coin here is legal and unrelated to the slide (seed 1010 lands 901 on it).
	ok(b.board.item_at(Vector2i(3, 4)) == 104 and _line_of(b.board.item_at(Vector2i(3, 1))) != 1, \
		"the auto-step slides the upgraded item along the partner path")
	ok(b.board.item_at(Vector2i(3, 3)) == 1001, \
		"reaching x3 births a chest on the first readable cascade event")
	b.queue_free()

func _test_preroll_delays_first_auto_step_and_telegraphs_run() -> void:
	var b := _open_board("cascade_preroll")
	await process_frame
	_blank_fixture(b, {
		Vector2i(3, 1): 101,
		Vector2i(3, 2): 101,
		Vector2i(3, 3): 102,
		Vector2i(3, 4): 103,
	})
	_drag_merge(b, Vector2i(3, 1), Vector2i(3, 2))
	await create_timer(0.16).timeout
	ok(b.chain_running() and b.animating and not bool(b.get("_chain_auto_step")), \
		"cascade pre-roll holds input before the first automatic step")
	ok(b.board.item_at(Vector2i(3, 3)) == 102 and _outline_has_tag(b, "×3"), \
		"pre-roll keeps the next partner in place while the exact run is telegraphed")
	await _wait_for_idle(b, 3.0)
	b.queue_free()

func _test_chain_step_timing_ramps() -> void:
	var b := _open_board("cascade_step_ramp")
	await process_frame
	ok(b.has_method("_chain_step_ms_for_n") \
		and int(b.call("_chain_step_ms_for_n", 2)) == 320 \
		and int(b.call("_chain_step_ms_for_n", 3)) == 273 \
		and int(b.call("_chain_step_ms_for_n", 4)) == 227 \
		and int(b.call("_chain_step_ms_for_n", 5)) == 180 \
		and int(b.call("_chain_step_ms_for_n", 8)) == 180, \
		"cascade auto-step timing starts legible and reaches the fast cadence by x5")
	b.queue_free()

func _test_chain_counter_anchors_at_run_origin() -> void:
	var b := _open_board("cascade_counter_anchor")
	await process_frame
	var origin := Vector2i(3, 2)
	var step_cell := Vector2i(3, 4)
	_blank_fixture(b, {
		Vector2i(3, 1): 101,
		origin: 101,
		Vector2i(3, 3): 102,
		step_cell: 103,
	})
	b._prepare_chain(Vector2i(3, 1), origin)
	b.set("_chain_n", 5)
	b._show_chain_step_feedback(step_cell, 104)
	var want: Vector2 = b.board_area.get_global_transform() * (b._cell_pos(origin) + Vector2(b.csz, b.csz) / 2.0) \
		+ Vector2(b.csz * 0.18, -b.csz * 0.38)
	var got: Label = null
	for raw in b.get_children():
		var lbl := raw as Label
		if lbl != null and lbl.text == "×5":
			got = lbl
			break
	ok(got != null and got.position.distance_to(want) < 1.0, \
		"cascade counter floater stays anchored at the run origin")
	b.queue_free()

func _test_chain_lock_dim_covers_the_run() -> void:
	var b := _open_board("cascade_lock_dim")
	await process_frame
	_blank_fixture(b, {
		Vector2i(3, 1): 101,
		Vector2i(3, 2): 101,
		Vector2i(3, 3): 102,
		Vector2i(3, 4): 103,
	})
	_drag_merge(b, Vector2i(3, 1), Vector2i(3, 2))
	await create_timer(0.16).timeout
	ok(b.chain_running() and b.board_area.modulate.a < 1.0, \
		"cascade input lock dims the board while the run owns input")
	await _wait_for_idle(b, 3.0)
	ok(is_equal_approx(b.board_area.modulate.a, 1.0), "cascade input lock dim clears when the run finishes")
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
	ok(b3.board.item_at(Vector2i(2, 2)) != G.COIN_LINE * 100 + 1, "x2 no longer leaves a coin reward")
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
	# the payout is ROLLED from the tier's range, so assert membership — never an exact number
	var chest_range := G.chest_open_range(1002)
	var got_coins := Save.coins() - wallet0
	var got_acorns := Save.diamonds() - acorns0
	ok(got_coins >= int((chest_range.coins as Array)[0]) and got_coins <= int((chest_range.coins as Array)[1]),
		"opening the cascade chest credits spendable coins from its tier range (%d)" % got_coins)
	ok(got_acorns >= maxi(0, int((chest_range.acorns as Array)[0])) and got_acorns <= int((chest_range.acorns as Array)[1]),
		"opening the cascade chest credits acorns from its tier range (%d)" % got_acorns)
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
		Vector2i(2, 4): 103,
	})
	var half := Vector2(b.csz, b.csz) / 2.0
	b._on_press(b._cell_pos(from) + half)
	b._begin_drag()
	await process_frame
	ok(_outline_pad_count_by_kind(b, "stage") == 1, "beginning an item drag shows one staging pad on the empty cell")
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
	ok(_outline_stack_is_visible_between_board_and_items(b), \
		"drag-guide creation keeps the cascade outline above the mat and slot tiles")
	b._on_release(b._cell_pos(from) + half)
	await process_frame
	ok(_outline_pad_count(b) == 0, "releasing the item clears cascade ghost pads")

	var x2_from := Vector2i(6, 5)
	_blank_fixture(b, {
		x2_from: 101,
		Vector2i(1, 1): 101,
		Vector2i(1, 3): 102,
	})
	b._on_press(b._cell_pos(x2_from) + half)
	b._begin_drag()
	await process_frame
	ok(_outline_pad_count_by_kind(b, "stage") == 0, "x2-only drag placements do not show staging pads")
	b._on_release(b._cell_pos(x2_from) + half)

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

func _test_drag_merge_targets_are_highlighted() -> void:
	var b := _open_board("cascade_drag_merge_targets")
	await process_frame
	var from := Vector2i(6, 6)
	var target_a := Vector2i(2, 1)
	var target_b := Vector2i(0, 0)
	var placements := {}
	placements[from] = 101
	placements[target_a] = 101
	placements[target_b] = 101
	placements[Vector2i(3, 3)] = 102
	_blank_fixture(b, placements)
	_input_begin_drag(b, from)
	await process_frame
	ok(_outline_pad_count_by_kind(b, "merge") == 2,
		"dragging an item highlights every same-code merge target")
	var merge_cells := _outline_pad_cells_by_kind(b, "merge")
	ok(merge_cells.has(target_a) and merge_cells.has(target_b),
		"merge-target highlights are attached to the actual matching pieces")
	_input_release(b, from)
	await process_frame

	var chain_target := Vector2i(3, 1)
	placements = {}
	placements[from] = 101
	placements[chain_target] = 101
	placements[Vector2i(3, 2)] = 102
	placements[Vector2i(3, 3)] = 103
	_blank_fixture(b, placements)
	_input_begin_drag(b, from)
	await process_frame
	ok(_outline_has_pad_kind_at(b, "cascade", chain_target) and not _outline_has_pad_kind_at(b, "merge", chain_target),
		"a merge target that starts a cascade is highlighted as chain creation, not ordinary merge")
	_input_release(b, from)
	await process_frame
	b.queue_free()

func _test_runway_resting_outline_and_tag() -> void:
	var b := _open_board("cascade_runway_outline")
	await process_frame
	_blank_fixture(b, {
		Vector2i(3, 1): 102,
		Vector2i(3, 2): 103,
		Vector2i(3, 3): 104,
	})
	var o := _outline(b)
	var armed_width := float(o.call("_mark_thickness", {"kind": "armed", "n": 3})) if o != null and o.has_method("_mark_thickness") else 0.0
	var runway_width := float(o.call("_mark_thickness", {"kind": "runway", "would_be_n": 3})) if o != null and o.has_method("_mark_thickness") else 0.0
	ok(_outline_ladder_count(b) == 0 and _outline_runway_count(b) == 1 and _outline_has_tag(b, "t2"),
		"an inert t2-t3-t4 runway draws a needed-tier resting mark")
	ok(runway_width > 0.0 and runway_width < armed_width,
		"runway resting mark is visibly weaker than an armed ladder")
	ok(_outline_stack_is_visible_between_board_and_items(b),
		"runway outline keeps the cascade stack invariant")

	_blank_fixture(b, {
		Vector2i(3, 0): 102,
		Vector2i(3, 1): 102,
		Vector2i(3, 2): 103,
		Vector2i(3, 3): 104,
	})
	ok(_outline_ladder_count(b) == 1 and _outline_runway_count(b) == 0 and _outline_has_tag(b, "×3") and not _outline_has_tag(b, "t2"),
		"an armed ladder keeps the stronger xN mark instead of the runway tag")
	b.queue_free()

# Two Labels at one position overprint into gibberish. A runway anchors its needed-tier chip on the
# exact cell that becomes the drop target the moment you pick that tier up, so the ordinary case
# stacked "t2" behind "×3" and rendered "t×3".
func _test_one_tag_per_cell_when_marks_collide() -> void:
	var b := _open_board("cascade_tag_collision")
	await process_frame
	var from := Vector2i(6, 6)
	_blank_fixture(b, {
		Vector2i(3, 1): 102,
		Vector2i(3, 2): 103,
		Vector2i(3, 3): 104,
		from: 102,                      # holding exactly what the runway is waiting for
	})
	_input_begin_drag(b, from)
	await process_frame
	var o := _outline(b)
	var seen := {}
	var collisions := 0
	var texts: Array = []
	for raw in o.find_children("*", "Label", true, false):
		var lbl := raw as Label
		if lbl == null:
			continue
		texts.append(lbl.text)
		var key := "%d,%d" % [int(lbl.position.x), int(lbl.position.y)]
		if seen.has(key):
			collisions += 1
		seen[key] = true
	ok(collisions == 0, "no two cascade tags share a cell (tags: %s)" % str(texts))
	ok(texts.has("×3") and not texts.has("t2"), \
		"the actionable ×n wins the cell; the runway's needed-tier chip yields (tags: %s)" % str(texts))
	_input_release(b, from)
	await process_frame
	b.queue_free()

func _test_runway_drag_guide_strengths_use_real_input() -> void:
	var b := _open_board("cascade_runway_drag_guides")
	await process_frame
	var from := Vector2i(6, 6)
	# The guide's whole grammar, on the board the player reported: t2·t3·t4 in a row.
	#   cascade = an occupied cell you drop ONTO whose merge really runs a chain (the only ×n)
	#   merge   = an ordinary same-code target, no number
	#   stage   = an empty cell; placing there builds the ladder and fires nothing
	# Holding a t2 is the payoff: ONE cascade mark on the t2 itself, and the staging cells around
	# it are suppressed so the eye has one place to go. t1/t5 cannot merge with anything, so they
	# only stage. t3/t4 merge but stop short of CHAIN_MIN_N, so they stay ordinary.
	var want := {
		1: {"cascade": 0, "merge": 0, "stage": 3},
		2: {"cascade": 1, "merge": 0, "stage": 0},
		3: {"cascade": 0, "merge": 1, "stage": 0},
		4: {"cascade": 0, "merge": 1, "stage": 0},
		5: {"cascade": 0, "merge": 0, "stage": 3},
	}
	for held in [1, 2, 3, 4, 5]:
		_blank_fixture(b, {
			Vector2i(3, 1): 102,
			Vector2i(3, 2): 103,
			Vector2i(3, 3): 104,
			from: 100 + held,
		})
		_input_begin_drag(b, from)
		await process_frame
		var spec: Dictionary = want[held]
		var got := {
			"cascade": _outline_pad_count_by_kind(b, "cascade"),
			"merge": _outline_pad_count_by_kind(b, "merge"),
			"stage": _outline_pad_count_by_kind(b, "stage"),
		}
		ok(got == spec, "real input drag for held t%d draws %s (got %s)" % [held, str(spec), str(got)])
		ok(_outline_number_tag_count(b) == int(spec.cascade),
			"held t%d numbers exactly its cascade marks — never a staging cell" % held)
		_input_release(b, from)
		await process_frame
	b.queue_free()

func _test_ready_outline_stays_between_slots_and_pieces_with_stale_generator_nodes() -> void:
	var b := _open_board("cascade_outline_stack_stale_gen")
	await process_frame
	_blank_fixture(b, {})
	b.board.place_gen("gen_1", Vector2i(0, 0))
	b._rebuild_all()
	for i in b.board.items.size():
		b.board.items[i] = 0
	b.board.gens = {}
	b.board.gen_boost = {}
	b.board.place(Vector2i(3, 1), 101)
	b.board.place(Vector2i(3, 2), 101)
	b.board.place(Vector2i(3, 3), 102)
	b.board.place(Vector2i(3, 4), 103)
	b._rebuild_all()
	ok(_outline_ladder_count(b) == 1 and _outline_stack_is_visible_between_board_and_items(b), \
		"ready outline renders above mat/slots and below live items even with stale queued generator nodes")
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
		Vector2i(3, 4): 103,
	})
	ok(_outline_ladder_count(b) == 1, "a ready ladder draws one cascade outline")
	ok(_outline_has_tag(b, "×3"), "the ready ladder tags its best armed chain length")
	ok(_outline_stack_is_visible_between_board_and_items(b), "ready outline renders above the mat and slot tiles")
	b.board.place(Vector2i(3, 4), 0)
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

# The ribbon's one rule has to cover every shape a run or a component can take, so pin the shapes
# a straight-row fixture can never show: a bend, a T and a closed 2x2 ring. Each cell's endpoint
# count IS its tile — 1 end caps, 2 opposite is a straight, 2 perpendicular is a corner, 3 is a T,
# 4 is a cross — so asserting the counts asserts the whole tile set without an image.
func _test_ribbon_covers_bends_branches_and_rings() -> void:
	var outline := CascadeOutline.new()
	outline.configure(Vector2(400, 400), 40.0, Callable(self, "_landscape_outline_pos"))

	var bend := {Vector2i(1, 1): true, Vector2i(1, 2): true, Vector2i(2, 2): true}
	var corner: Array = outline.call("_ribbon_ends", Vector2i(1, 2), bend)
	var tail: Array = outline.call("_ribbon_ends", Vector2i(1, 1), bend)
	var centre := Vector2(_landscape_outline_pos(Vector2i(1, 2))) + Vector2.ONE * 20.0
	var perpendicular := false
	if corner.size() == 2:
		var u := (Vector2(corner[0]) - centre).normalized()
		var v := (Vector2(corner[1]) - centre).normalized()
		perpendicular = is_zero_approx(u.dot(v))
	ok(corner.size() == 2 and perpendicular and tail.size() == 1, \
		"a bent run turns a corner and caps its tail")

	var tee := {Vector2i(2, 1): true, Vector2i(2, 2): true, Vector2i(2, 3): true, Vector2i(1, 2): true}
	ok(Array(outline.call("_ribbon_ends", Vector2i(2, 2), tee)).size() == 3, \
		"a branching component draws a T where three arms meet")

	var ring := {Vector2i(1, 1): true, Vector2i(1, 2): true, Vector2i(2, 1): true, Vector2i(2, 2): true}
	var ring_ok := true
	for raw in ring:
		if Array(outline.call("_ribbon_ends", Vector2i(raw), ring)).size() != 2:
			ring_ok = false
	ok(ring_ok, "a 2x2 block closes the ribbon into a ring with no loose ends")

	var lone := {Vector2i(4, 4): true}
	ok(Array(outline.call("_ribbon_ends", Vector2i(4, 4), lone)).is_empty(), \
		"an isolated cell has no arms and falls back to the joint disc")
	outline.free()

func _test_landscape_outline_uses_transposed_edges() -> void:
	var outline := CascadeOutline.new()
	outline.configure(Vector2(240, 260), 40.0, Callable(self, "_landscape_outline_pos"))
	# The ribbon's endpoints are the transpose-sensitive part now: a model row-neighbour has to
	# come out as a HORIZONTAL screen offset under the landscape transpose, not a vertical one.
	var cells := {Vector2i(3, 2): true, Vector2i(2, 2): true, Vector2i(3, 1): true}
	var ends: Array = outline.call("_ribbon_ends", Vector2i(3, 2), cells)
	var centre: Vector2 = Vector2(_landscape_outline_pos(Vector2i(3, 2))) + Vector2.ONE * 20.0
	var offs: Array = []
	for e in ends:
		offs.append(Vector2(e) - centre)
	var row_off_horizontal := false
	var col_off_vertical := false
	for o in offs:
		var v := Vector2(o)
		if absf(v.x) > absf(v.y):
			row_off_horizontal = true
		else:
			col_off_vertical = true
	ok(ends.size() == 2 and row_off_horizontal and col_off_vertical, \
		"landscape ribbon maps model neighbours through the transposed cell geometry")
	outline.free()

func _line_of(code: int) -> int:
	return int(code / 100.0)
