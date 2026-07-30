extends "res://games/grove/tests/grove_test_base.gd"
## Feature level gating: the unlock table, FeatureGate's two states, the teach
## registry, and the mastery reveal clamp. Spec: docs/superpowers/specs/2026-07-29-feature-level-gating-design.md

const FeatureGate = preload("res://engine/scripts/core/feature_gate.gd")
const BoardLogicRef = preload("res://engine/scripts/core/board_logic.gd")
const Improvements = preload("res://engine/scripts/core/improvements.gd")
const Mastery = preload("res://engine/scripts/core/mastery.gd")
const ShopUI = preload("res://engine/scripts/ui/shop.gd")
const SkyLogic = preload("res://engine/scripts/core/sky.gd")
const TeachRegistry = preload("res://engine/scripts/ui/teach_registry.gd")

func _initialize() -> void:
	begin("grove · feature gating")
	await process_frame
	_test_table_thresholds()
	_test_unknown_id_fails_closed()
	_test_revealed_is_separate_from_armed()
	_test_weather_gate_needs_the_level()
	_test_magnet_seed_cannot_drop_before_its_level()
	_test_magnet_staging_waits_before_granting()
	_test_soil_ftue_level_comes_from_the_table()
	_test_mastery_rank_is_clamped_until_revealed()
	_test_registry_picks_the_first_unseen_armed_ready_spec()
	_test_registry_complete_is_derived_from_the_same_array()
	_test_registry_complete_does_not_call_ready()
	await _test_cascade_teach_waits_for_a_real_chain()
	_test_cascade_teach_is_unarmed_below_its_level()
	_test_weather_teach_requires_a_pair_inside_the_patch()
	await _test_weather_teach_orients_an_actionable_pair_into_the_patch()
	await _test_weather_teach_skips_earlier_invalid_and_off_patch_pairs()
	await _test_cascade_teach_finds_a_later_direction_sensitive_chain()
	await _test_weather_reveal_banks_only_after_the_pointed_merge_lands()
	await _test_cascade_reveal_banks_only_after_the_pointed_chain_finishes()
	finish()

## Set the coin clock so G.level() reads exactly `lvl`.
func _set_level(lvl: int) -> void:
	Save.earn_coins(G.coins_at_level(lvl) - Save.coins_earned_lifetime())

func _test_table_thresholds() -> void:
	for id in G.FEATURE_LEVEL:
		var want := int(G.FEATURE_LEVEL[id])
		fresh("gate_" + String(id))
		_set_level(want - 1)
		ok(not FeatureGate.armed(String(id)),
			"%s is dormant at L%d (one below its gate)" % [id, want - 1])
		fresh("gate_on_" + String(id))
		_set_level(want)
		ok(FeatureGate.armed(String(id)) == _extra_met(String(id)),
			"%s arms at L%d once its extra condition is met" % [id, want])

## The AND terms that are NOT the level. A fresh save meets none of them, so this documents
## which ids can arm on level alone.
func _extra_met(id: String) -> bool:
	return id == "cascade" or id == "mastery" or id == "magnet"

func _test_unknown_id_fails_closed() -> void:
	fresh("gate_unknown")
	ok(not FeatureGate.armed("no_such_feature"),
		"an unknown gate id fails CLOSED (never leaks an ungated feature)")

func _test_revealed_is_separate_from_armed() -> void:
	fresh("gate_reveal")
	_set_level(G.FEATURE_LEVEL["cascade"])
	ok(FeatureGate.armed("cascade"), "cascade arms at its level")
	ok(not FeatureGate.revealed("cascade"), "arming does NOT reveal")
	FeatureGate.mark_revealed("cascade")
	ok(FeatureGate.revealed("cascade"), "mark_revealed persists to the ftue ledger")

func _test_weather_gate_needs_the_level() -> void:
	fresh("gate_weather_level")
	Save.mark_ftue_seen("merge")
	Save.mark_ftue_seen("gen_tap")
	_set_level(G.FEATURE_LEVEL["weather"] - 1)
	ok(not SkyLogic.gate_open(),
		"both FTUE verbs seen is no longer enough — the weather gate also needs L%d" % int(G.FEATURE_LEVEL["weather"]))
	_set_level(G.FEATURE_LEVEL["weather"])
	ok(SkyLogic.gate_open(), "weather opens at its level with both verbs seen")

func _test_magnet_seed_cannot_drop_before_its_level() -> void:
	fresh("gate_magnet_drop")
	_set_level(G.FEATURE_LEVEL["magnet"] - 1)
	var magnet_line := Improvements.seed_line_for_kind(Improvements.KIND_MAGNET)
	var seen_below := 0
	# A SEED SWEEP, not one seed: a single stream proves nothing about a weighted table.
	for s in range(1, 60):
		var rng := RandomNumberGenerator.new()
		rng.seed = s
		for _i in range(40):
			if int(G.pick_special_drop(rng, [magnet_line]) / 100.0) == magnet_line:
				seen_below += 1
	ok(seen_below == 0,
		"the magnet seed line never drops while the gate is unarmed (%d hits over 59 seeds)" % seen_below)

func _test_magnet_staging_waits_before_granting() -> void:
	fresh("teach_magnet_stage")
	_set_level(G.FEATURE_LEVEL["magnet"])
	ok(FeatureGate.armed("magnet"), "magnet arms at its level")
	ok(not Save.magnet_stage_due(),
		"the staging grant does NOT fire the moment the gate arms — the drop path gets its window")
	for _i in range(int(G.MAGNET_STAGE_MERGES)):
		Save.bump_magnet_armed_merges()
	ok(Save.magnet_stage_due(),
		"after %d armed merges with no seed held, the teach grants one outright" % int(G.MAGNET_STAGE_MERGES))

func _test_soil_ftue_level_comes_from_the_table() -> void:
	ok(int(G.FEATURE_LEVEL["soil"]) == 13,
		"the soil teach's level is the table's 13, not the retired literal 6")

func _test_mastery_rank_is_clamped_until_revealed() -> void:
	fresh("gate_mastery_clamp")
	_set_level(G.FEATURE_LEVEL["mastery"])
	var line := int(G.ZONE_BASE_LINES[0])
	# Bank a meter well past threshold 2 — the case that would otherwise dump scissors
	# in the same beat as the mastery reveal.
	Save.grove()["mastery"] = {str(line): int(G.MASTERY_THRESHOLDS[2])}
	ok(Mastery.true_rank(line) >= 3, "the banked meter really is past rank 2")
	ok(Mastery.rank(line) == 1, "rank reads 1 while mastery is unrevealed")
	ok(not ShopUI.scissors_available(),
		"scissors CANNOT unlock in the same beat as the mastery reveal")
	FeatureGate.mark_revealed("mastery")
	ok(Mastery.rank(line) == Mastery.true_rank(line), "the clamp lifts on reveal")
	ok(ShopUI.scissors_available(), "scissors becomes available once mastery is revealed")

func _spec(id: String, ledger: String, gate: bool, ready: bool) -> Dictionary:
	return {
		"id": id, "ledger": ledger,
		"gate": func() -> bool: return gate,
		"ready": func() -> bool: return ready,
		"rects": func() -> Array: return [Rect2(), Rect2()],
		"gesture": "tap",
	}

func _test_registry_picks_the_first_unseen_armed_ready_spec() -> void:
	fresh("registry_pick")
	var specs := [
		_spec("a", "t_a", true, false),   # armed but the board is not ready
		_spec("b", "t_b", false, true),   # ready but unarmed
		_spec("c", "t_c", true, true),    # the first that qualifies
	]
	ok(TeachRegistry.eligible(specs) == "c", "eligible() skips not-ready and unarmed specs")
	Save.mark_ftue_seen("t_c")
	ok(TeachRegistry.eligible(specs) == "", "a taught spec is not offered again")

## THE assertion the old two-list design could not carry: complete() is derived from the SAME
## array eligible() reads, so a teach added to one can no longer be missing from the other.
func _test_registry_complete_is_derived_from_the_same_array() -> void:
	fresh("registry_complete")
	var specs := [_spec("a", "t_a", true, true), _spec("b", "t_b", true, true)]
	ok(not TeachRegistry.complete(specs), "complete() is false while any ledger key is unseen")
	Save.mark_ftue_seen("t_a")
	ok(not TeachRegistry.complete(specs), "still false with one of two seen")
	Save.mark_ftue_seen("t_b")
	ok(TeachRegistry.complete(specs), "true only when EVERY spec's ledger key is seen")

## complete() must never touch the board: board.gd calls it on every mutation BEFORE the
## frame await, so a board scan there would cost a scan per merge.
func _test_registry_complete_does_not_call_ready() -> void:
	fresh("registry_cheap")
	var called := [false]
	var spec := _spec("a", "t_a", true, true)
	spec["ready"] = func() -> bool:
		called[0] = true
		return true
	TeachRegistry.complete([spec])
	ok(not called[0], "complete() is ledger-only — it never invokes ready()")

func _test_cascade_teach_waits_for_a_real_chain() -> void:
	fresh("teach_cascade")
	_set_level(G.FEATURE_LEVEL["cascade"])
	Save.mark_ftue_seen("merge")
	Save.mark_ftue_seen("gen_tap")
	Save.mark_board_tutorial_seen()
	var h = board_host()
	await process_frame
	# This registry assertion makes the RED phase non-vacuous: without the Task 5 specs,
	# "not cascade" below would pass merely because the board has never heard of cascade.
	ok(not TeachRegistry.spec_for(h._teach_specs(), "cascade").is_empty()
			and not TeachRegistry.spec_for(h._teach_specs(), "weather").is_empty(),
		"the live board registry contains the weather and cascade teach specs")
	# With no 3+ chain on the board the cascade spec is armed but NOT ready, so it offers nothing.
	ok(h._hand_hint_eligible() != "cascade",
		"the cascade teach stays silent until the board actually offers a chain")
	h.queue_free()

func _test_cascade_teach_is_unarmed_below_its_level() -> void:
	fresh("teach_cascade_low")
	_set_level(G.FEATURE_LEVEL["cascade"] - 1)
	# The spec's own gate, read directly — independent of what the board happens to hold.
	ok(not FeatureGate.armed("cascade"),
		"the cascade teach cannot fire at L%d" % int(G.FEATURE_LEVEL["cascade"] - 1))

func _test_weather_teach_requires_a_pair_inside_the_patch() -> void:
	fresh("teach_weather")
	_set_level(G.FEATURE_LEVEL["weather"])
	Save.mark_ftue_seen("merge")
	Save.mark_ftue_seen("gen_tap")
	ok(FeatureGate.armed("weather"), "weather is armed at its level with both verbs seen")
	ok(not FeatureGate.revealed("weather"), "armed is not revealed")

func _open_teach_board(save_id: String, level: int, weather_seen := false) -> Node:
	fresh(save_id)
	Save.mark_ftue_seen("merge")
	Save.mark_ftue_seen("gen_tap")
	if weather_seen:
		Save.mark_ftue_seen("unlock_weather")
	_set_level(level)
	var b = board_host()
	await process_frame
	return b

func _blank_teach_fixture(b: Node, placements: Dictionary, reward_cells: Array = []) -> void:
	for i in b.board.items.size():
		b.board.terrain[i] = 0
		b.board.items[i] = 0
	b.board.collect_rewards = {}
	b.board.gens = {}
	b.board.gen_boost = {}
	b.quests = []
	for raw_cell in placements:
		b.board.place(Vector2i(raw_cell), int(placements[raw_cell]))
	for raw_cell in reward_cells:
		b.board.set_collect_reward(Vector2i(raw_cell), "coins", 1)
	b._rebuild_all()
	for n in b.gen_nodes.values():
		if n != null and is_instance_valid(n):
			(n as Node).queue_free()
	b.gen_nodes.clear()
	b.gen_node = null
	b.board.gens = {}
	b.board.gen_boost = {}

func _set_teach_patch(b: Node, lane: int) -> void:
	b._sky_state = {
		"sky": SkyLogic.SKY_SUNBEAM,
		"lane_axis": SkyLogic.AXIS_COLUMN,
		"lane": lane,
	}

func _input_drag_merge(b: Node, from: Vector2i, to: Vector2i) -> void:
	var half := Vector2(b.csz, b.csz) / 2.0
	var start: Vector2 = b._cell_pos(from) + half
	var finish_at: Vector2 = b._cell_pos(to) + half
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = start
	b._on_board_input(down)
	var move := InputEventMouseMotion.new()
	move.position = finish_at
	b._on_board_input(move)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = finish_at
	b._on_board_input(up)

func _wait_teach_board_idle(b: Node, timeout := 4.0) -> void:
	var waited := 0.0
	while (bool(b.animating) or b.chain_running()) and waited < timeout:
		await create_timer(0.05).timeout
		waited += 0.05

func _test_weather_teach_orients_an_actionable_pair_into_the_patch() -> void:
	var b = await _open_teach_board("teach_weather_oriented", G.FEATURE_LEVEL["weather"])
	var patch_cell := Vector2i(0, 2)
	var outside_cell := Vector2i(1, 1)
	_blank_teach_fixture(b, {patch_cell: 101, outside_cell: 101})
	_set_teach_patch(b, 2)
	var pair: Array = b._weather_teach_pair()
	ok(pair == [outside_cell, patch_cell] and b.board.can_merge(pair[0], pair[1])
			and SkyLogic.in_patch(b._sky_state, pair[1]),
		"weather points an actionable drag INTO the live patch, regardless of board order")
	b.queue_free()

func _test_weather_teach_skips_earlier_invalid_and_off_patch_pairs() -> void:
	var b = await _open_teach_board("teach_weather_later_pair", G.FEATURE_LEVEL["weather"])
	var want := [Vector2i(1, 1), Vector2i(1, 2)]
	_blank_teach_fixture(b, {
		Vector2i(0, 0): 101, Vector2i(0, 2): 101,
		want[0]: 201, want[1]: 201,
	}, [Vector2i(0, 0)])
	_set_teach_patch(b, 2)
	var after_invalid: Array = b._weather_teach_pair()
	ok(after_invalid == want and b.board.can_merge(after_invalid[0], after_invalid[1]),
		"an earlier equal-code pair rejected by board.can_merge does not hide a later weather merge")

	_blank_teach_fixture(b, {
		Vector2i(0, 0): 101, Vector2i(0, 1): 101,
		want[0]: 201, want[1]: 201,
	})
	_set_teach_patch(b, 2)
	var after_off_patch: Array = b._weather_teach_pair()
	ok(after_off_patch == want and SkyLogic.in_patch(b._sky_state, after_off_patch[1]),
		"an earlier actionable off-patch pair does not hide a later merge into the patch")
	b.queue_free()

func _test_cascade_teach_finds_a_later_direction_sensitive_chain() -> void:
	var b = await _open_teach_board("teach_cascade_direction", G.FEATURE_LEVEL["cascade"], true)
	var want := [Vector2i(3, 2), Vector2i(3, 1)]
	_blank_teach_fixture(b, {
		Vector2i(0, 0): 201, Vector2i(0, 1): 201,
		Vector2i(3, 1): 101, Vector2i(3, 2): 101,
		Vector2i(3, 0): 102, Vector2i(2, 0): 103,
	})
	var pair: Array = b._cascade_teach_pair()
	ok(pair == want and b.board.can_merge(pair[0], pair[1])
			and 1 + BoardLogicRef.chain_path(b.board, pair[0], pair[1]).size() >= 3,
		"cascade skips an earlier ordinary pair and chooses the orientation that reaches x3")
	b.queue_free()

func _test_weather_reveal_banks_only_after_the_pointed_merge_lands() -> void:
	var b = await _open_teach_board("teach_weather_bank", G.FEATURE_LEVEL["weather"])
	_blank_teach_fixture(b, {Vector2i(0, 2): 101, Vector2i(1, 1): 101})
	_set_teach_patch(b, 2)
	b._maybe_hand_hint()
	await process_frame
	await process_frame
	var pair: Array = b._weather_teach_pair()
	ok(b._hand_hint_id == "weather" and pair.size() == 2 and not FeatureGate.revealed("weather"),
		"weather is watched and pointed, but not banked before the taught drag")
	if pair.size() == 2:
		_input_drag_merge(b, pair[0], pair[1])
		ok(not FeatureGate.revealed("weather"),
			"weather remains unrevealed while the pointed merge is still landing")
		await _wait_teach_board_idle(b)
		ok(FeatureGate.revealed("weather"),
			"weather banks only after the pointed merge lands inside the patch")
	b.queue_free()

func _test_cascade_reveal_banks_only_after_the_pointed_chain_finishes() -> void:
	var b = await _open_teach_board("teach_cascade_bank", G.FEATURE_LEVEL["cascade"], true)
	_blank_teach_fixture(b, {
		Vector2i(3, 1): 101, Vector2i(3, 2): 101,
		Vector2i(3, 0): 102, Vector2i(2, 0): 103,
	})
	b._maybe_hand_hint()
	await process_frame
	await process_frame
	var pair: Array = b._cascade_teach_pair()
	ok(b._hand_hint_id == "cascade" and pair.size() == 2 and not FeatureGate.revealed("cascade"),
		"cascade is watched and pointed, but not banked before the taught drag")
	if pair.size() == 2:
		_input_drag_merge(b, pair[0], pair[1])
		ok(not FeatureGate.revealed("cascade"),
			"cascade remains unrevealed while the pointed chain is still running")
		await _wait_teach_board_idle(b)
		ok(FeatureGate.revealed("cascade"),
			"cascade banks only after the pointed chain reaches x3 and finishes")
	b.queue_free()
