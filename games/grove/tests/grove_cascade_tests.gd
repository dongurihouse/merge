extends "res://games/grove/tests/grove_test_base.gd"
## Grove scene coverage for cascade combos: the player drag path, cascade
## rewards, guide pads, ready outlines, and the code-level feature flag.

const BoardScriptRef = preload("res://engine/scripts/scenes/board.gd")
const RNG_SEED := 20260727   # any fixed value; the point is that it does not change between runs
const CascadeOutline = preload("res://engine/scripts/ui/cascade_outline.gd")
const Contour = preload("res://engine/scripts/ui/cell_contour.gd")
const Improvements = preload("res://engine/scripts/core/improvements.gd")
const BoardLogic = preload("res://engine/scripts/core/board_logic.gd")

func _initialize() -> void:
	begin("grove · cascade combos")
	await process_frame
	await _test_x2_ladder_arms_a_cascade()
	await _test_drag_merge_auto_runs_and_locks_input()
	await _test_preroll_delays_first_auto_step_and_telegraphs_run()
	await _test_x2_preroll_is_shorter_than_a_longer_run()
	await _test_chain_step_timing_ramps()
	await _test_chain_counter_anchors_at_run_origin()
	await _test_chain_trigger_keeps_board_undimmed()
	await _test_cascade_watchdog_keeps_player_input_locked()
	await _test_magnet_holds_fire_while_cascade_runs()
	await _test_chain_bailouts_release_input_gate()
	await _test_chain_rewards_and_chest_open_clock()
	await _test_long_chain_rewards_upgrade_and_cap()
	await _test_drag_guide_pads_and_generator_exclusion()
	await _test_drag_merge_targets_are_highlighted()
	await _test_drag_focuses_the_held_cascade_path()
	await _test_drag_stage_starts_from_single_tier_neighbors()
	await _test_runway_resting_outline_without_needed_tier_tag()
	await _test_runway_threshold_is_independent_of_chain_min_n()
	await _test_drag_cascade_tag_sits_on_drop_target()
	await _test_ready_ladder_glow_excludes_duplicate_tip_source()
	await _test_runway_drag_guide_strengths_use_real_input()
	await _test_ready_outline_stays_between_slots_and_pieces_with_stale_generator_nodes()
	await _test_ready_outline_and_flag_off()
	await _test_two_chains_arm_and_draw_at_once()
	_test_contour_covers_bends_branches_rings_and_pinches()
	_test_contour_rounds_and_resamples_for_drawing()
	_test_landscape_outline_uses_transposed_geometry()
	_test_runway_glow_is_weaker_than_an_armed_ladder()
	_test_glow_levels_stay_ordered_and_equally_warm()
	_test_cascade_phase_pins_for_captures()
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

# Wall-clock milliseconds from the player's drop to the run's first AUTOMATIC step. The tipping
# merge's own slide plus the pre-roll; used as a difference so only the pre-roll survives.
func _ms_to_first_auto_step(b: Node, timeout_ms: int = 3000) -> float:
	var t0 := Time.get_ticks_msec()
	_drag_merge(b, Vector2i(3, 1), Vector2i(3, 2))
	while not bool(b.get("_chain_auto_step")) and Time.get_ticks_msec() - t0 < timeout_ms:
		await process_frame
	return float(Time.get_ticks_msec() - t0)

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

func _outline_drag_ladder_count(b: Node) -> int:
	var o := _outline(b)
	if o == null:
		return 0
	var drag_ladders = o.get("drag_ladders")
	return (drag_ladders as Array).size() if drag_ladders is Array else 0

func _outline_drag_ladder_run(b: Node) -> Array:
	var o := _outline(b)
	if o == null:
		return []
	var drag_ladders = o.get("drag_ladders")
	if not (drag_ladders is Array) or (drag_ladders as Array).is_empty():
		return []
	var entry: Variant = (drag_ladders as Array)[0]
	return Array((entry as Dictionary).get("run", [])) if entry is Dictionary else []

func _outline_ready_ladder_run(b: Node) -> Array:
	var o := _outline(b)
	if o == null:
		return []
	var ladders = o.get("ladders")
	if not (ladders is Array) or (ladders as Array).is_empty():
		return []
	var entry: Variant = (ladders as Array)[0]
	return Array((entry as Dictionary).get("run", [])) if entry is Dictionary else []

func _cells_equal(got: Array, want: Array) -> bool:
	if got.size() != want.size():
		return false
	for i in got.size():
		if Vector2i(got[i]) != Vector2i(want[i]):
			return false
	return true

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

# Count only the ×n chips. Empty staging pads and inert runways stay unnumbered.
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

func _outline_label_texts(b: Node) -> Array:
	var out: Array = []
	var o := _outline(b)
	if o == null:
		return out
	for raw in o.find_children("*", "Label", true, false):
		var lbl := raw as Label
		if lbl != null and not lbl.is_queued_for_deletion():
			out.append(lbl.text)
	out.sort()
	return out

func _outline_has_tag_at(b: Node, text: String, cell: Vector2i) -> bool:
	var o := _outline(b)
	if o == null:
		return false
	var want: Vector2 = b._cell_pos(cell) + Vector2(float(b.csz) * 0.58, -float(b.csz) * 0.08)
	for raw in o.find_children("*", "Label", true, false):
		var lbl := raw as Label
		if lbl != null and not lbl.is_queued_for_deletion() and lbl.text == text \
				and lbl.position.distance_to(want) <= 1.5:
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

# board.gd's other orientation: model col drives X. The transpose between the two is a REFLECTION,
# so anything that reads a side off the winding has to survive both.
func _portrait_outline_pos(cell: Vector2i) -> Vector2:
	var step := 44.0
	return Vector2(cell.y * step, cell.x * step)

func _segment_is_vertical(seg: Array) -> bool:
	return seg.size() == 2 and is_equal_approx(Vector2(seg[0]).x, Vector2(seg[1]).x) \
		and not is_equal_approx(Vector2(seg[0]).y, Vector2(seg[1]).y)

func _segment_is_horizontal(seg: Array) -> bool:
	return seg.size() == 2 and is_equal_approx(Vector2(seg[0]).y, Vector2(seg[1]).y) \
		and not is_equal_approx(Vector2(seg[0]).x, Vector2(seg[1]).x)

# CHAIN_MIN_N is 2 (owner call 2026-07-29): the shortest possible run — one player merge and one
# automatic follow-up — IS a chain. It telegraphs at rest, it arms, and it auto-steps. It pays
# nothing: chain_reward_code starts its chest ladder at 3, and that is deliberate, not an oversight.
func _test_x2_ladder_arms_a_cascade() -> void:
	var b := _open_board("cascade_x2_arms")
	await process_frame
	_blank_fixture(b, {
		Vector2i(3, 1): 101,
		Vector2i(3, 2): 101,
		Vector2i(3, 3): 102,
	})
	await process_frame
	ok(_outline_ladder_count(b) == 1 and _outline_has_tag(b, "×2"), \
		"a x2 ladder draws its own cascade telegraph (%s)" % str(_outline_label_texts(b)))
	_drag_merge(b, Vector2i(3, 1), Vector2i(3, 2))
	ok(b.chain_running() and b.animating, "the x2 merge arms a chain instead of resolving as one merge")
	await _wait_for_idle(b, 3.0)
	ok(not b.chain_running() and b.board.item_at(Vector2i(3, 3)) == 103 \
		and _line_of(b.board.item_at(Vector2i(3, 2))) != 1, \
		"the x2 run auto-steps: the upgrade slides onto its partner and lands at t3")
	ok(BoardLogic.chain_reward_code(2) == 0 and not G.is_chest(b.board.item_at(Vector2i(3, 2))), \
		"a x2 run pays no chest — the reward ladder still starts at x3")
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

# A x2 run is one hop and is already entirely on screen, so its pre-roll is shortened
# (CHAIN_PREROLL_X2_MS); x3 and longer keep the full CHAIN_PREROLL_MS telegraph. Same 0.16s probe as
# the test above, on the same drag path: by then the x2 has already taken its automatic step, where
# the x3 has not.
func _test_x2_preroll_is_shorter_than_a_longer_run() -> void:
	ok(int(BoardScriptRef.CHAIN_PREROLL_X2_MS) > 0 \
		and int(BoardScriptRef.CHAIN_PREROLL_X2_MS) < int(BoardScriptRef.CHAIN_PREROLL_MS), \
		"the x2 pre-roll constant is shorter than the full one (%d vs %d ms)" % \
		[int(BoardScriptRef.CHAIN_PREROLL_X2_MS), int(BoardScriptRef.CHAIN_PREROLL_MS)])
	var b := _open_board("cascade_preroll_x2")
	await process_frame
	ok(b.has_method("_chain_preroll_ms_for_n") \
		and int(b.call("_chain_preroll_ms_for_n", 2)) == int(BoardScriptRef.CHAIN_PREROLL_X2_MS) \
		and int(b.call("_chain_preroll_ms_for_n", 3)) == int(BoardScriptRef.CHAIN_PREROLL_MS) \
		and int(b.call("_chain_preroll_ms_for_n", 6)) == int(BoardScriptRef.CHAIN_PREROLL_MS), \
		"only x2 is shortened — x3 and longer keep the full pre-roll")
	_blank_fixture(b, {
		Vector2i(3, 1): 101,
		Vector2i(3, 2): 101,
		Vector2i(3, 3): 102,
	})
	var t_x2: float = await _ms_to_first_auto_step(b)
	await _wait_for_idle(b, 3.0)
	b.queue_free()

	# Same tipping merge on the same cells, one rung longer — so the DIFFERENCE is the pre-roll and
	# nothing else, and the test does not depend on how long the player's own merge slide takes.
	var b3 := _open_board("cascade_preroll_x3")
	await process_frame
	_blank_fixture(b3, {
		Vector2i(3, 1): 101,
		Vector2i(3, 2): 101,
		Vector2i(3, 3): 102,
		Vector2i(3, 4): 103,
	})
	var t_x3: float = await _ms_to_first_auto_step(b3)
	var want: float = float(int(BoardScriptRef.CHAIN_PREROLL_MS) - int(BoardScriptRef.CHAIN_PREROLL_X2_MS))
	ok(t_x2 < t_x3 and absf((t_x3 - t_x2) - want) < 90.0, \
		"the x2 run reaches its first step %.0f ms before the x3 run does (the pre-roll gap, %.0f ms)" % \
		[t_x3 - t_x2, want])
	await _wait_for_idle(b3, 3.0)
	b3.queue_free()

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

func _test_chain_trigger_keeps_board_undimmed() -> void:
	var b := _open_board("cascade_no_board_dim")
	await process_frame
	_blank_fixture(b, {
		Vector2i(3, 1): 101,
		Vector2i(3, 2): 101,
		Vector2i(3, 3): 102,
		Vector2i(3, 4): 103,
	})
	_drag_merge(b, Vector2i(3, 1), Vector2i(3, 2))
	await create_timer(0.16).timeout
	ok(b.chain_running() and is_equal_approx(b.board_area.modulate.a, 1.0), \
		"cascade input lock keeps the board fully visible while the run owns input")
	await _wait_for_idle(b, 3.0)
	ok(is_equal_approx(b.board_area.modulate.a, 1.0), "cascade board visibility stays restored when the run finishes")
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
	# COINS ONLY (owner call 2026-07-27): the chest acorn payout is DELETED — an open must leave
	# the premium wallet exactly where it was.
	ok(got_acorns == 0, "opening a cascade chest does NOT move the premium wallet (delta %d)" % got_acorns)
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
	ok(_outline_has_pad_kind_at(b, "stage", Vector2i(2, 2)), "beginning an item drag shows the ladder gap as a staging pad")
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
	ok(_outline_pad_count_by_kind(b, "stage") > 0, "x2-only drag still shows weak build pads beside adjacent tiers")
	ok(_outline_number_tag_count(b) == 0 and _outline_pad_count_by_kind(b, "cascade") == 0,
		"x2-only build pads do not advertise a cascade")
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

func _test_drag_focuses_the_held_cascade_path() -> void:
	var b := _open_board("cascade_drag_focus_path")
	await process_frame
	var from := Vector2i(1, 1)
	var target := Vector2i(1, 2)
	var t4 := Vector2i(1, 3)
	var t5 := Vector2i(2, 3)
	_blank_fixture(b, {
		Vector2i(3, 1): 201,
		Vector2i(2, 1): 201,
		Vector2i(2, 2): 202,
		from: 203,
		target: 203,
		t4: 204,
		t5: 205,
	})
	ok(_outline_ladder_count(b) == 1 and _outline_has_tag(b, "×5"),
		"resting outline still reports the best armed ladder in the mixed component")
	_input_begin_drag(b, from)
	await process_frame
	ok(_outline_has_pad_kind_at(b, "cascade", target),
		"dragging the t3 highlights the occupied target that creates the t3→t5 chain")
	ok(_outline_drag_ladder_count(b) == 1 and _cells_equal(_outline_drag_ladder_run(b), [target, t4, t5]),
		"drag focus follows the held piece's actual cascade path, not the component's lower-tier best")
	ok(_outline_has_tag(b, "×3") and not _outline_has_tag(b, "×5"),
		"drag focus hides the resting ×5 tag so the player sees the chain they are creating")
	ok(_outline_has_tag_at(b, "×3", target) and not _outline_has_tag_at(b, "×3", t5),
		"drag focus puts the cascade number on the occupied drop target, not the chain end")
	_input_release(b, from)
	await process_frame
	ok(_outline_drag_ladder_count(b) == 0 and _outline_has_tag(b, "×5"),
		"releasing the drag restores the resting ready-ladder outline")
	b.queue_free()

func _test_drag_stage_starts_from_single_tier_neighbors() -> void:
	var b := _open_board("cascade_drag_single_neighbor_seeds")
	await process_frame
	var from := Vector2i(6, 6)
	_blank_fixture(b, {
		from: 102,
		Vector2i(3, 1): 101,
		Vector2i(3, 4): 103,
	})
	_input_begin_drag(b, from)
	await process_frame
	var want := [
		Vector2i(2, 1), Vector2i(2, 4),
		Vector2i(3, 0), Vector2i(3, 2), Vector2i(3, 3), Vector2i(3, 5),
		Vector2i(4, 1), Vector2i(4, 4),
	]
	ok(_cells_equal(_outline_pad_cells_by_kind(b, "stage"), want),
		"dragging t2 seeds weak stage pads beside every single t1/t3 neighbor")
	ok(_outline_pad_count_by_kind(b, "merge") == 0 and _outline_pad_count_by_kind(b, "cascade") == 0,
		"single-neighbor seed pads are not advertised as merge or cascade targets")
	ok(_outline_number_tag_count(b) == 0, "single-neighbor seed pads do not show a cascade number")
	_input_release(b, from)
	await process_frame
	b.queue_free()

func _test_runway_resting_outline_without_needed_tier_tag() -> void:
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
	ok(_outline_ladder_count(b) == 0 and _outline_runway_count(b) == 1 and _outline_label_texts(b).is_empty(),
		"an inert runway draws only the glow, without a tN needed-tier label")
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

# The runway threshold is RUNWAY_MIN_N (3), NOT CHAIN_MIN_N (2). A chain ARMS at x2, but a runway is
# the quiet "one piece away" telegraph and at 2 it fires on nearly every board (mean 3.2-7.4 marks
# against 0.2-0.7; spec §11). The fixture holds one component of each kind, so re-coupling the two
# constants changes the drawn count and fails here.
func _test_runway_threshold_is_independent_of_chain_min_n() -> void:
	var b := _open_board("cascade_runway_threshold")
	await process_frame
	_blank_fixture(b, {
		Vector2i(3, 1): 102,   # t2·t3·t4 — one t2 away from a x3 run
		Vector2i(3, 2): 103,
		Vector2i(3, 3): 104,
		Vector2i(6, 1): 202,   # t2·t3 on another line — one t2 away from a x2 run, and no further
		Vector2i(6, 2): 203,
	})
	await process_frame
	var at_chain_min: int = BoardLogic.runways(b.board, BoardScriptRef.CHAIN_MIN_N).size()
	var at_runway_min: int = BoardLogic.runways(b.board, BoardScriptRef.RUNWAY_MIN_N).size()
	ok(at_chain_min == 2 and at_runway_min == 1,
		"the fixture separates the two thresholds: %d runways at CHAIN_MIN_N, %d at RUNWAY_MIN_N" % [at_chain_min, at_runway_min])
	ok(_outline_runway_count(b) == at_runway_min and _outline_runway_count(b) != at_chain_min,
		"the board draws the RUNWAY_MIN_N set, not the CHAIN_MIN_N set (drew %d)" % _outline_runway_count(b))
	ok(BoardScriptRef.RUNWAY_MIN_N > BoardScriptRef.CHAIN_MIN_N,
		"a runway needs a longer would-be run than the arming floor (%d vs %d)" % [BoardScriptRef.RUNWAY_MIN_N, BoardScriptRef.CHAIN_MIN_N])
	b.queue_free()

func _test_drag_cascade_tag_sits_on_drop_target() -> void:
	var b := _open_board("cascade_drag_tag_drop_target")
	await process_frame
	var from := Vector2i(6, 6)
	var target := Vector2i(3, 1)
	var t2 := Vector2i(3, 2)
	var t3 := Vector2i(3, 3)
	var t4 := Vector2i(3, 4)
	_blank_fixture(b, {
		target: 101,
		t2: 102,
		t3: 103,
		t4: 104,
		from: 101,
	})
	_input_begin_drag(b, from)
	await process_frame
	ok(_outline_has_pad_kind_at(b, "cascade", target), "dragging t1 highlights the occupied t1 drop target")
	ok(_cells_equal(_outline_drag_ladder_run(b), [target, t2, t3, t4]),
		"drag ladder follows the exact post-merge x4 chain")
	ok(_outline_has_tag_at(b, "×4", target) and not _outline_has_tag_at(b, "×4", t4),
		"the x4 number sits on the drop target, not at the end of the chain")
	_input_release(b, from)
	await process_frame
	b.queue_free()

func _test_ready_ladder_glow_excludes_duplicate_tip_source() -> void:
	var b := _open_board("cascade_ready_glow_exact_chain")
	await process_frame
	var duplicate_source := Vector2i(3, 0)
	var target := Vector2i(3, 1)
	var t2 := Vector2i(3, 2)
	var t3 := Vector2i(3, 3)
	_blank_fixture(b, {
		duplicate_source: 101,
		target: 101,
		t2: 102,
		t3: 103,
	})
	ok(_outline_ladder_count(b) == 1 and _outline_has_tag(b, "×3"),
		"1,1,2,3 still arms a ready ladder")
	ok(_cells_equal(_outline_ready_ladder_run(b), [target, t2, t3]),
		"the ready glow outlines the merge destination onward, excluding the duplicate source")
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
	# only stage. At CHAIN_MIN_N = 2 the held t3 joins the t2 as a chain-maker — t3+t3 → t4 lands on
	# the board's own t4 — so it too draws one cascade mark and suppresses its staging cells. Only
	# the t4 still merges without running: t4+t4 → t5 and there is no t5 to catch it.
	var want := {
		1: {"cascade": 0, "merge": 0, "stage": 3},
		2: {"cascade": 1, "merge": 0, "stage": 0},
		3: {"cascade": 1, "merge": 0, "stage": 0},
		4: {"cascade": 0, "merge": 1, "stage": 2},
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
	await process_frame
	ok(_outline_ladder_count(b) == 1 and _outline_has_tag(b, "×2"), \
		"removing the top rung shortens the mark to ×2 rather than clearing it (CHAIN_MIN_N = 2)")
	b.board.place(Vector2i(3, 3), 0)
	b._rebuild_all()
	await process_frame
	ok(_outline_ladder_count(b) == 0, \
		"a bare pair with nothing for the upgrade to land on clears the cascade outline")
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

# TWO chains armed at the same time. Nothing anywhere picks a single best: `ready_ladders` appends
# EVERY same-line component that scores, `_armed_cascade_marks` keeps them all, `_draw` loops every
# entry and `_rebuild_tags` dedups per CELL rather than per chain. Two components of the SAME line is
# the case that could have collapsed — `ready_ladders` walks the board with one shared `visited` map —
# so pin that one, and pin that the result is drawn as two SEPARATE contours with their own ×n each.
func _test_two_chains_arm_and_draw_at_once() -> void:
	var b := _open_board("cascade_two_chains_at_once")
	await process_frame
	# One line, two components four rows apart so they can never join: a ×3 and a ×4.
	_blank_fixture(b, {
		Vector2i(1, 1): 101,
		Vector2i(1, 2): 101,
		Vector2i(1, 3): 102,
		Vector2i(1, 4): 103,
		Vector2i(5, 1): 101,
		Vector2i(5, 2): 101,
		Vector2i(5, 3): 102,
		Vector2i(5, 4): 103,
		Vector2i(5, 5): 104,
	})
	await process_frame      # _rebuild_tags queue_free()s the previous chips; let the frees land
	ok(_outline_ladder_count(b) == 2,
		"two separate same-line components each arm their own ladder (got %d)" % _outline_ladder_count(b))
	ok(_outline_number_tag_count(b) == 2 and _outline_has_tag(b, "×3") and _outline_has_tag(b, "×4"),
		"each armed chain carries its own ×n, sized to its own length (%s)" % str(_outline_label_texts(b)))
	var o := _outline(b)
	var boxes: Array = []
	for raw in Array(o.get("ladders")):
		var run := Array((raw as Dictionary).get("run", []))
		ok(not run.is_empty(), "each armed entry carries the run its contour is built from")
		boxes.append(_loop_bounds(o, run))
	ok(boxes.size() == 2 and not (boxes[0] as Rect2).intersects(boxes[1] as Rect2),
		"the two chains draw two separate contours, not one shape spanning both")
	# and a second line arming beside them is a third mark, not a replacement.
	b.board.place(Vector2i(3, 1), 201)
	b.board.place(Vector2i(3, 2), 201)
	b.board.place(Vector2i(3, 3), 202)
	b.board.place(Vector2i(3, 4), 203)
	b._rebuild_all()
	await process_frame
	ok(_outline_ladder_count(b) == 3 and _outline_number_tag_count(b) == 3,
		"a third chain on another line adds a mark rather than replacing one (got %d)" % _outline_ladder_count(b))
	b.queue_free()

# The contour's ONE rule has to cover every shape a run or a component can take, so pin the shapes
# a straight-row fixture can never show: a bend, a T, a closed ring with a hole, and the DIAGONAL
# PINCH (two cells meeting at a corner only), which is where a boundary walk that keys edges by
# their start corner silently loses one. Corner counts ARE the shape — a straight run has 4, an L
# has 6 with one reflex, a T has 8 with two — so asserting them asserts the whole tile set with no
# image. Every corner classification comes from the four cells around it, which is also what tells
# the renderer to bulge a convex corner and cut a reflex one sharp.
func _test_contour_covers_bends_branches_rings_and_pinches() -> void:
	var straight := Contour.boundary_loops([Vector2i(3, 1), Vector2i(3, 2), Vector2i(3, 3)])
	ok(straight.size() == 1 and Array(straight[0]).size() == 4,
		"a straight run is ONE loop with four corners — the cells are unioned, not linked")

	var bend_cells := [Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 2)]
	var bend := Contour.boundary_loops(bend_cells)
	ok(bend.size() == 1 and Array(bend[0]).size() == 6 and _reflex_count(bend_cells, bend[0]) == 1,
		"an L bend is ONE loop, six corners, exactly one of them reflex")

	var tee_cells := [Vector2i(2, 1), Vector2i(2, 2), Vector2i(2, 3), Vector2i(1, 2)]
	var tee := Contour.boundary_loops(tee_cells)
	ok(tee.size() == 1 and Array(tee[0]).size() == 8 and _reflex_count(tee_cells, tee[0]) == 2,
		"a T branch is ONE loop with two reflex corners where the arms meet")

	var block := Contour.boundary_loops([Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, 1), Vector2i(2, 2)])
	ok(block.size() == 1 and Array(block[0]).size() == 4,
		"a 2x2 block is a single square outline, with no rung across its middle")

	# a real ring: eight cells around one empty middle. The hole is its own loop, wound the other
	# way — that opposite winding is what points its glow INTO the hole instead of out of it.
	var ring_cells: Array = []
	for r in range(1, 4):
		for c in range(1, 4):
			if Vector2i(r, c) != Vector2i(2, 2):
				ring_cells.append(Vector2i(r, c))
	var ring := Contour.boundary_loops(ring_cells)
	ok(ring.size() == 2, "a ring gives two loops — the silhouette and its hole")
	if ring.size() == 2:
		var outer := _screen_loop(ring[0])
		var hole := _screen_loop(ring[1])
		ok(Contour.signed_area(outer) * Contour.signed_area(hole) < 0.0,
			"the hole is wound opposite to the silhouette it sits in")
		ok(_outward_points_away(ring_cells, ring[0]) and _outward_points_away(ring_cells, ring[1]),
			"both loops offset AWAY from the chain's cells")

	# THE DIAGONAL PINCH: two cells touching only at a corner. The shared corner starts two boundary
	# edges; keeping only one of them drops a whole side of the outline, and walking blindly falls
	# off the end. Resolved, it is two closed loops of four corners each.
	var pinch_cells := [Vector2i(1, 1), Vector2i(2, 2)]
	var pinch := Contour.boundary_loops(pinch_cells)
	var pinch_corners := 0
	for raw in pinch:
		pinch_corners += Array(raw).size()
	ok(pinch.size() == 2 and pinch_corners == 8,
		"a diagonal pinch resolves into two closed loops, keeping every boundary edge")
	ok(Contour.corner_kind(Contour.cell_set(pinch_cells), Vector2i(2, 2)) == Contour.SADDLE,
		"the pinched corner classifies as a saddle, not as a reflex corner")

	var lone := Contour.boundary_loops([Vector2i(4, 4)])
	ok(lone.size() == 1 and Array(lone[0]).size() == 4,
		"an isolated cell still outlines as one closed square")
	ok(Contour.boundary_loops([]).is_empty(), "an empty chain outlines nothing")

# A drawn contour is a CLOSED, uniformly resampled ring whose corners are rounded to the cell's own
# tile radius, and whose reflex corners stay sharp. Measured off the built geometry, not eyeballed.
func _test_contour_rounds_and_resamples_for_drawing() -> void:
	var outline := CascadeOutline.new()
	outline.configure(Vector2(400, 400), 40.0, Callable(self, "_landscape_outline_pos"))
	var geom: Dictionary = outline.call("_chain_geometry", [Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 2)])
	var loops: Array = geom["loops"]
	ok(loops.size() == 1, "the L bend builds one drawable contour")
	if loops.is_empty():
		outline.free()
		return
	var loop: Dictionary = loops[0]
	var pts: PackedVector2Array = loop["pts"]
	var m: Dictionary = geom["metrics"]
	var step: float = float(m["pitch"]) * 0.125
	var even := true
	var closed := pts.size() > 8
	for i in pts.size():
		var seg := pts[i].distance_to(pts[(i + 1) % pts.size()])
		if absf(seg - step) > step * 0.35:
			even = false
	ok(closed and even, "the contour closes and is resampled at an even arc step (%d points)" % pts.size())
	ok(PackedVector2Array(loop["off"]).size() == pts.size(),
		"every contour point carries the mitre offset the strip rides")
	# the rounding: no drawn point may sit further out than the sharp corner it replaced, and the
	# convex corners must actually be cut back by about the tile's own radius.
	var sharp_corner: Vector2 = Vector2(_landscape_outline_pos(Vector2i(1, 1))) - Vector2.ONE * 2.0
	var nearest := INF
	for p in pts:
		nearest = minf(nearest, p.distance_to(sharp_corner))
	var want: float = float(m["corner"]) * (sqrt(2.0) - 1.0)
	ok(absf(nearest - want) < step,
		"the convex corner is rounded to the tile's own corner radius (cut back %.1f, want %.1f)" % [nearest, want])
	ok(_outward_points_away([Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 2)],
		Contour.boundary_loops([Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 2)])[0]),
		"the contour's outward side is the side away from the chain")
	outline.free()

# Every point still comes from _cell_pos, which owns the landscape transpose. A model row-neighbour
# has to come out as a HORIZONTAL screen offset under landscape, never a vertical one — hardcoding
# portrait axes here is what once drew rungs instead of a border on a wide screen.
func _test_landscape_outline_uses_transposed_geometry() -> void:
	var cells := [Vector2i(2, 2), Vector2i(3, 2)]
	var wide := CascadeOutline.new()
	wide.configure(Vector2(240, 260), 40.0, Callable(self, "_landscape_outline_pos"))
	var tall := CascadeOutline.new()
	tall.configure(Vector2(240, 260), 40.0, Callable(self, "_portrait_outline_pos"))
	var wide_box := _loop_bounds(wide, cells)
	var tall_box := _loop_bounds(tall, cells)
	ok(wide_box.size.x > wide_box.size.y * 1.5,
		"a landscape board runs a model row-pair contour ACROSS the screen (%s)" % str(wide_box.size))
	ok(tall_box.size.y > tall_box.size.x * 1.5,
		"the same pair runs DOWN the screen in portrait (%s)" % str(tall_box.size))
	ok(_outward_points_away(cells, Contour.boundary_loops(cells)[0]),
		"the outward normal survives the transpose (it is a reflection, and it flips the winding)")
	ok(_built_outward_ok(wide, cells, false) and _built_outward_ok(tall, cells, true),
		"the BUILT contour offsets away from the chain in both orientations")
	# the gutter between the two cells is a mark of the board's own geometry, not of the outline's
	var wide_gut: Array = Dictionary(wide.call("_chain_geometry", cells))["gutters"]
	var tall_gut: Array = Dictionary(tall.call("_chain_geometry", cells))["gutters"]
	ok(wide_gut.size() == 1 and tall_gut.size() == 1, "one lit gutter per shared edge")
	ok(_quad_bounds(wide_gut[0]).size.y > _quad_bounds(wide_gut[0]).size.x
		and _quad_bounds(tall_gut[0]).size.x > _quad_bounds(tall_gut[0]).size.y,
		"the lit gutter turns with the transpose too")
	wide.free()
	tall.free()

# A runway is the SAME mark, quieter — it will not fire until its piece arrives. The distinction is
# now carried by the glow's own alphas and halo reach, so pin those, not just the legacy width knob.
func _test_runway_glow_is_weaker_than_an_armed_ladder() -> void:
	var outline := CascadeOutline.new()
	outline.configure(Vector2(400, 400), 40.0, Callable(self, "_landscape_outline_pos"))
	var m: Dictionary = Dictionary(outline.call("_chain_geometry", [Vector2i(1, 1), Vector2i(1, 2)]))["metrics"]
	var armed: PackedFloat32Array = outline.call("_rail_offsets", m, 1.0)
	var runway: PackedFloat32Array = outline.call("_rail_offsets", m, 0.78)
	ok(armed[0] > runway[0] and runway[0] > 0.0,
		"a runway's halo reaches less far than an armed ladder's (%.1f vs %.1f)" % [runway[0], armed[0]])
	var gap_rail := CascadeOutline.RAILS.size() - 3
	ok(is_equal_approx(armed[gap_rail], runway[gap_rail]),
		"the hot line stays ON the tile edge at both strengths — only the halo scales")
	var lit := Color(1, 1, 1)
	var full: Color = outline.call("_tint", lit, Color(1, 1, 1), 0.9)
	var half: Color = outline.call("_tint", lit, Color(1, 1, 1), 0.9 * 0.5)
	ok(half.a < full.a, "the runway's light is half as strong at every rail")
	outline.free()

# The contour's INTENSITY has three named levels and a wider BAND_WIDTH is most of the step up
# between them, so pin the two things a wider band can break:
#   * the rails must stay strictly outward-to-inward. They are the rows of ONE triangle strip; let
#     the widened band's outermost rail cross the innermost pitch-anchored haze rail and the mesh
#     folds through itself.
#   * band and interior gutters must carry the SAME warmth. They ride the same tray, and one
#     CREAM_PULL drives both — measured as R-B on the drawn colours, which is the property of the
#     constants rather than of whatever happens to sit under a given pixel.
func _test_glow_levels_stay_ordered_and_equally_warm() -> void:
	var outline := CascadeOutline.new()
	outline.configure(Vector2(400, 400), 40.0, Callable(self, "_landscape_outline_pos"))
	# `_rail_offsets` reads nothing but these three lengths, so hand it the geometries that matter
	# instead of only the one this workbench Control happens to make. The phone board and the 40 px
	# workbench cell differ by 5× in gutter-to-pitch ratio, and the first cut of BAND_WIDTH ordered
	# correctly on the workbench while folding the strip on the real board.
	var geoms := {
		"phone board": _metrics_for(129.91, 131.91),
		"workbench": Dictionary(outline.call("_chain_geometry", [Vector2i(1, 1), Vector2i(1, 2)]))["metrics"],
		"small cells": _metrics_for(60.0, 66.0),
		"tablet board": _metrics_for(220.0, 222.0),
	}
	var before := CascadeOutline.forced_level
	var levels: Array = CascadeOutline.LEVELS.keys()
	levels.append("")                                       # "" = whatever is shipped
	for raw_level in levels:
		var level := String(raw_level)
		CascadeOutline.forced_level = level
		var name := level if level != "" else "shipped"
		var m: Dictionary = {}
		for raw_geom in geoms:
			m = Dictionary(geoms[raw_geom])
			for reach in [1.0, 0.78]:
				var offs: PackedFloat32Array = outline.call("_rail_offsets", m, reach)
				var ordered := true
				for i in offs.size() - 1:
					ordered = ordered and offs[i] > offs[i + 1]
				ok(ordered, "glow '%s' keeps its rails strictly outward-to-inward on the %s at reach %.2f (%s)" \
					% [name, String(raw_geom), reach, str(offs)])
			# the hot line is anchored to the tile's cut edge and a wider band must never move it
			var hot_at := _rail_index(func(rail): return int(rail[0]) == CascadeOutline.ANCHOR_GAP \
				and is_equal_approx(float(rail[1]), -1.0))
			var hot: PackedFloat32Array = outline.call("_rail_offsets", m, 1.0)
			ok(hot_at >= 0 and is_equal_approx(hot[hot_at], -1.0 * float(m["gap"])), \
				"glow '%s' leaves the hot line ON the %s's tile edge (%.3f px vs %.3f)" \
				% [name, String(raw_geom), hot[maxi(hot_at, 0)], -1.0 * float(m["gap"])])
		# warmth is read on the OUTERMOST fully opaque tray rail: a part-transparent one composites
		# toward the tray's own R-B and would report the ground's warmth, not the band's.
		var band_at := _rail_index(func(rail): return int(rail[0]) == CascadeOutline.ANCHOR_GAP \
			and float(rail[1]) > -1.0 and float(rail[3]) * CascadeOutline.ALPHA_LIFT >= 1.0)
		var band: Color = Array(CascadeOutline.lit_rails()[band_at])[2]
		var gutter: Color = CascadeOutline.CRACK_COLOR.lerp(Pal.CREAM, CascadeOutline.cream_pull())
		var warmth := absf((band.r - band.b) - (gutter.r - gutter.b)) * 255.0
		ok(warmth <= 4.0, "glow '%s' keeps band and gutters equally warm (R-B apart by %.1f levels)" \
			% [name, warmth])
	CascadeOutline.forced_level = before
	outline.free()

# `_metrics()`'s own arithmetic, so a synthetic geometry is one the renderer could really be handed
# rather than three numbers picked to disagree with each other.
func _metrics_for(cell: float, pitch: float) -> Dictionary:
	var gap := (pitch - cell) * 0.5 + cell * CascadeOutline.TILE_INSET_FRAC
	return {"pitch": pitch, "gap": gap, "corner": cell * CascadeOutline.TILE_RADIUS_FRAC + gap}

# The first rail (outermost first) the predicate accepts, or -1. Named by what it IS rather than by
# an index counted back from the table's end, so re-solving the profile cannot silently retarget it.
func _rail_index(pred: Callable) -> int:
	for i in CascadeOutline.RAILS.size():
		if bool(pred.call(CascadeOutline.RAILS[i])):
			return i
	return -1

# The travelling light is pinnable, because `make shot` compares captures byte for byte and a warm
# batch process has run a different number of frames than a fresh one.
func _test_cascade_phase_pins_for_captures() -> void:
	var outline := CascadeOutline.new()
	var before := CascadeOutline.forced_phase
	CascadeOutline.forced_phase = -1.0
	outline.set("_t", 0.4)
	ok(is_equal_approx(float(outline.call("_phase")), 0.4), "left live, the wave rides the clock")
	CascadeOutline.forced_phase = 0.0
	ok(is_equal_approx(float(outline.call("_phase")), 0.0), "pinned, the clock is ignored")
	outline.configure(Vector2(400, 400), 40.0, Callable(self, "_landscape_outline_pos"))
	outline.set_ladders([{"line": 1, "run": [Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3)]}])
	ok(not outline.is_processing(), "a pinned outline does not run its animation at all")
	CascadeOutline.forced_phase = -1.0
	outline.set_ladders([{"line": 1, "run": [Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3)]}])
	ok(outline.is_processing(), "a live armed ladder animates")
	outline.set_ladders([])
	ok(not outline.is_processing(), "with nothing to draw the animation stops")
	CascadeOutline.forced_phase = before
	outline.free()

func _reflex_count(cells: Array, loop) -> int:
	var s := Contour.cell_set(cells)
	var n := 0
	for raw in loop as Array:
		if Contour.is_reflex(s, Vector2i(raw)):
			n += 1
	return n

func _screen_loop(loop, portrait := false) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for raw in loop as Array:
		pts.append(Vector2(_portrait_outline_pos(Vector2i(raw)) if portrait \
			else _landscape_outline_pos(Vector2i(raw))))
	return pts

# The offset the strip rides must point AWAY from the chain: a probe just outside the contour may
# never land inside one of the chain's own cells. Checked in BOTH orientations, because the
# landscape transpose is a reflection and flips the hand the whole lattice is wound on.
func _outward_points_away(cells: Array, loop) -> bool:
	return _outward_ok(cells, loop, false) and _outward_ok(cells, loop, true)

func _outward_ok(cells: Array, loop, portrait: bool) -> bool:
	var pts := _screen_loop(loop, portrait)
	var offs := Contour.mitre_offsets(pts, -1.0 if portrait else 1.0)
	for i in pts.size():
		var probe: Vector2 = pts[i] + offs[i] * 6.0
		for raw in cells:
			var origin := Vector2(_portrait_outline_pos(Vector2i(raw)) if portrait \
				else _landscape_outline_pos(Vector2i(raw)))
			if Rect2(origin, Vector2.ONE * 40.0).has_point(probe):
				return false
	return true

# The same probe, but on the geometry the RENDERER will draw — so the side the outline derives from
# its own cell-position callable is what gets checked, not a value the test picked.
func _built_outward_ok(outline: Control, cells: Array, portrait: bool) -> bool:
	for raw_loop in Dictionary(outline.call("_chain_geometry", cells))["loops"]:
		var loop: Dictionary = raw_loop
		var pts: PackedVector2Array = loop["pts"]
		var offs: PackedVector2Array = loop["off"]
		for i in pts.size():
			var probe: Vector2 = pts[i] + offs[i] * 6.0
			for raw in cells:
				var origin := Vector2(_portrait_outline_pos(Vector2i(raw)) if portrait \
					else _landscape_outline_pos(Vector2i(raw)))
				if Rect2(origin, Vector2.ONE * 40.0).has_point(probe):
					return false
	return true

func _loop_bounds(outline: Control, cells: Array) -> Rect2:
	var loops: Array = Dictionary(outline.call("_chain_geometry", cells))["loops"]
	if loops.is_empty():
		return Rect2()
	var pts: PackedVector2Array = Dictionary(loops[0])["pts"]
	var box := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		box = box.expand(p)
	return box

func _quad_bounds(quad) -> Rect2:
	var box := Rect2(Vector2(Array(quad)[0]), Vector2.ZERO)
	for p in quad as Array:
		box = box.expand(Vector2(p))
	return box

func _line_of(code: int) -> int:
	return int(code / 100.0)
