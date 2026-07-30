extends "res://games/grove/tests/grove_test_base.gd"
## Feature level gating: the unlock table, FeatureGate's two states, the teach
## registry, and the mastery reveal clamp. Spec: docs/superpowers/specs/2026-07-29-feature-level-gating-design.md

const FeatureGate = preload("res://engine/scripts/core/feature_gate.gd")
const Debug = preload("res://engine/scripts/ui/debug.gd")
const BoardLogicRef = preload("res://engine/scripts/core/board_logic.gd")
const Improvements = preload("res://engine/scripts/core/improvements.gd")
const Mastery = preload("res://engine/scripts/core/mastery.gd")
const ShopUI = preload("res://engine/scripts/ui/shop.gd")
const SkyLogic = preload("res://engine/scripts/core/sky.gd")
const TeachRegistry = preload("res://engine/scripts/ui/teach_registry.gd")
const HandHint = preload("res://engine/scripts/ui/hand_hint.gd")
const FX = preload("res://engine/scripts/ui/fx.gd")

func _initialize() -> void:
	begin("grove · feature gating")
	await process_frame
	_test_table_thresholds()
	_test_unknown_id_fails_closed()
	_test_revealed_is_separate_from_armed()
	_test_debug_reset_clears_every_unlock_key()
	_test_debug_gate_rows_bind_their_explicit_ids()
	_test_debug_gate_panel_is_forbidden_in_release_builds()
	await _test_debug_action_body_is_bounded_and_scrolls_to_its_last_control()
	_test_exact_read_site_filter_rejects_comments()
	_test_every_table_id_has_an_exact_read_site()
	_test_weather_gate_needs_the_level()
	_test_magnet_seed_cannot_drop_before_its_level()
	_test_magnet_staging_waits_before_granting()
	await _test_magnet_natural_drop_suppresses_staging_at_the_merge_seam()
	await _test_magnet_held_seed_suppresses_staging_at_the_merge_seam()
	await _test_magnet_stage_grants_ground_once_and_persists_after_sale()
	await _test_magnet_stage_falls_back_to_the_bag()
	_test_soil_ftue_level_comes_from_the_table()
	_test_mastery_rank_is_clamped_until_revealed()
	await _test_mastery_ring_hidden_until_revealed()
	await _test_mastery_reveal_sweeps_on_real_generator_tap()
	await _test_mastery_reveal_skips_ineligible_real_generator_taps()
	_test_registry_picks_the_first_unseen_armed_ready_spec()
	_test_registry_complete_is_derived_from_the_same_array()
	_test_registry_complete_does_not_call_ready()
	_test_rush_teach_needs_level_and_a_bucket_cell()
	await _test_rush_teach_uses_the_player_reachable_residents_surface()
	await _test_rush_modal_hint_rejects_hidden_and_queued_targets()
	await _test_rush_modal_hint_tears_down_with_the_map_host()
	await _test_rush_map_teach_points_at_the_visible_expedition_button()
	await _test_rush_map_teach_banks_on_the_real_open_and_does_not_replay()
	await _test_rush_map_teach_leaves_with_its_visible_surface()
	await _test_cascade_teach_waits_for_a_real_chain()
	_test_cascade_teach_is_unarmed_below_its_level()
	_test_weather_teach_requires_a_pair_inside_the_patch()
	await _test_weather_teach_orients_an_actionable_pair_into_the_patch()
	await _test_weather_teach_skips_earlier_invalid_and_off_patch_pairs()
	await _test_cascade_teach_requires_a_built_runway_not_the_chain_floor()
	await _test_cascade_teach_finds_a_later_direction_sensitive_chain()
	await _test_weather_reveal_banks_only_after_the_pointed_merge_lands()
	await _test_cascade_reveal_banks_only_after_the_pointed_chain_finishes()
	finish()

## Set the coin clock so G.level() reads exactly `lvl`.
func _set_level(lvl: int) -> void:
	Save.earn_coins(G.coins_at_level(lvl) - Save.coins_earned_lifetime())

class GateDebugHost extends Control:
	var rebuild_calls := 0

	func _rebuild_all() -> void:
		rebuild_calls += 1

	func debug_add_resident_to_hand() -> void:
		pass

	func debug_drop_coin() -> void:
		pass

	func debug_drop_acorn() -> void:
		pass

	func debug_pop_soil() -> void:
		pass

	func debug_pop_magnet() -> void:
		pass

	func debug_bump_mastery(_delta: int) -> void:
		pass

func _debug_button(menu: Control, label: String) -> Button:
	for child in menu.get_children():
		if child is Button and (child as Button).text == label:
			return child as Button
	return null

func _test_debug_reset_clears_every_unlock_key() -> void:
	fresh("gate_debug_reset")
	for id in FeatureGate.ids():
		FeatureGate.mark_revealed(String(id))
	for id in FeatureGate.ids():
		ok(FeatureGate.revealed(String(id)), "%s revealed before the reset" % id)
	Debug._act_reset_gates(null)
	for id in FeatureGate.ids():
		ok(not FeatureGate.revealed(String(id)), "%s cleared by the debug reset" % id)

## The break this catches is a chained bind reversing (host, id), or a new table
## entry never receiving both owner actions in the debug panel.
func _test_debug_gate_rows_bind_their_explicit_ids() -> void:
	var menu := VBoxContainer.new()
	var host := GateDebugHost.new()
	Debug._feature_gate_actions(menu, host)
	ok(menu.get_child_count() == FeatureGate.ids().size() * 2 + 1,
		"the debug panel wires Arm + Reveal for every table id, plus one reset")
	for id_variant in FeatureGate.ids():
		var id := String(id_variant)
		fresh("gate_debug_arm_" + id)
		var arm := _debug_button(menu, "Arm %s (L%d)" % [id, FeatureGate.level_for(id)])
		var reveal := _debug_button(menu, "Reveal %s" % id)
		ok(arm != null and reveal != null,
			"%s has separately aimable Arm and Reveal rows" % id)
		var rebuilds_before := host.rebuild_calls
		if arm != null:
			arm.pressed.emit()
		ok(FeatureGate.armed(id) and host.rebuild_calls == rebuilds_before + 1,
			"Arm %s satisfies its real gate on a fresh save and refreshes a live rebuild host" % id)
		ok(not FeatureGate.revealed(id),
			"Arm %s leaves its own Reveal ledger unseen" % id)
		if reveal != null:
			reveal.pressed.emit()
		ok(FeatureGate.revealed(id),
			"Reveal %s binds the explicit id into its own ledger key" % id)
	var reset := _debug_button(menu, "Reset feature gates")
	if reset != null:
		reset.pressed.emit()
	ok(reset != null, "the gate rows include one Reset feature gates action")
	for id_variant in FeatureGate.ids():
		var id := String(id_variant)
		ok(not FeatureGate.revealed(id), "the wired reset row clears %s" % id)
	menu.free()
	host.free()

## The break this catches is adding action rows directly to the draggable column
## again: at the common 720×960 portrait size the bottom controls then fall below
## the viewport and there is no scroll range that can bring them back.
func _test_debug_action_body_is_bounded_and_scrolls_to_its_last_control() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(720, 960)
	get_root().add_child(viewport)
	var host := GateDebugHost.new()
	host.size = Vector2(720, 960)
	viewport.add_child(host)
	var menu := VBoxContainer.new()
	menu.add_theme_constant_override("separation", 4)
	Debug._populate_action_menu(menu, host)
	var body := Debug._action_body(host, menu)
	host.add_child(body)
	await process_frame
	await process_frame
	var scroll := body as ScrollContainer
	ok(scroll != null,
		"the variable debug action body is a ScrollContainer while the drag handle stays outside it")
	if scroll != null:
		var panel_y := Debug._default_panel_position(host).y
		var body_bottom := panel_y + Debug.BTN_SIZE.y + 4.0 + scroll.size.y
		var bar := scroll.get_v_scroll_bar()
		var max_scroll := maxf(0.0, bar.max_value - bar.page) if bar != null else 0.0
		ok(scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED
				and body_bottom <= 960.5,
			"the portrait action body is horizontally fixed and bounded below the viewport")
		ok(max_scroll > 0.5,
			"the populated portrait action body has a real positive vertical scroll range")
		if max_scroll > 0.5:
			scroll.scroll_vertical = int(ceilf(max_scroll))
			await process_frame
			var last := menu.get_child(menu.get_child_count() - 1) as Control
			ok(last != null and last.get_global_rect().end.y <= scroll.get_global_rect().end.y + 1.0,
				"the final control after the gate rows is reachable at the bottom of the scroll range")
	viewport.queue_free()
	await process_frame

## A release export can still receive TU_DEBUG/debug arguments; the build guard
## wins before either explicit authoring switch is allowed to mount the panel.
func _test_debug_gate_panel_is_forbidden_in_release_builds() -> void:
	ok(not Debug._panel_allowed(false, "macOS", false, true),
		"a release build cannot mount debug actions even when authoring was explicitly requested")
	ok(Debug._panel_allowed(true, "macOS", false, true),
		"a debug build with explicit authoring may mount the panel")
	ok(not Debug._panel_allowed(true, "headless", false, true)
			and not Debug._panel_allowed(true, "macOS", true, true),
		"headless and quiet guards still suppress debug-build panel chrome")

## A FEATURE_LEVEL entry with no gate consumer is dead data that reads as coverage.
## Exact call expressions keep an unrelated id string plus another gate call in the
## same file from false-passing the scan.
func _source_has_exact_gate_read(source: String, id: String) -> bool:
	var armed_read := "FeatureGate.armed(\"%s\")" % id
	var revealed_read := "FeatureGate.revealed(\"%s\")" % id
	for raw_line in source.split("\n"):
		var code := String(raw_line).get_slice("#", 0)
		if code.contains(armed_read) or code.contains(revealed_read):
			return true
	return false

## The break this catches is documenting an exact call in a comment and thereby
## making a table entry look live even after its final executable consumer is gone.
func _test_exact_read_site_filter_rejects_comments() -> void:
	var id := "weather"
	ok(not _source_has_exact_gate_read("# FeatureGate.armed(\"weather\")", id),
		"an exact FeatureGate call in a comment is not a live read site")
	ok(_source_has_exact_gate_read("if FeatureGate.armed(\"weather\"):", id),
		"the same exact FeatureGate call on a real code line is a live read site")

func _test_every_table_id_has_an_exact_read_site() -> void:
	var sources := gd_files("res://engine/scripts/")
	for id_variant in G.FEATURE_LEVEL:
		var id := String(id_variant)
		var found := false
		for path in sources:
			var text := read_text(path)
			if _source_has_exact_gate_read(text, id):
				found = true
				break
		ok(found, "FEATURE_LEVEL[\"%s\"] has an exact live FeatureGate read site" % id)

func _live_map_hand_hint(map: Node) -> Control:
	var hints := _live_map_hand_hints(map)
	return hints[0] as Control if not hints.is_empty() else null

func _live_map_hand_hints(map: Node) -> Array:
	var hints: Array = []
	for c in map.find_children("*", "Control", true, false):
		if c is Control and (c as Control).get_script() == HandHint and not bool(c.get("dismissed")):
			hints.append(c)
	return hints

func _settle_map_teach() -> void:
	await process_frame
	await process_frame

func _push_gui_tap(gpos: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = gpos
	down.global_position = gpos
	get_root().push_input(down, true)
	var up := down.duplicate()
	up.pressed = false
	get_root().push_input(up, true)

func _test_rush_teach_needs_level_and_a_bucket_cell() -> void:
	fresh("teach_rush")
	_set_level(G.FEATURE_LEVEL["rush"])
	ok(not FeatureGate.armed("rush"),
		"L%d alone does not arm rush — a completed building (bucket cell) is still required" % int(G.FEATURE_LEVEL["rush"]))
	complete_scene(0)
	ok(FeatureGate.armed("rush"), "rush arms with both the level and a bucket cell")
	ok(not FeatureGate.revealed("rush"), "armed is not revealed")

func _test_rush_teach_uses_the_player_reachable_residents_surface() -> void:
	fresh("teach_rush_residents_surface")
	complete_scene(0)
	_set_level(G.FEATURE_LEVEL["rush"])
	var map := map_host()
	map._login_shown_launch = true
	var residents_tile := map.get_node_or_null("ResidentsTile") as Button
	ok(residents_tile != null, "the real map chrome exposes the Residents player entry")
	if residents_tile != null:
		residents_tile.pressed.emit()
	await _settle_map_teach()
	var overlay := map.get_node_or_null("ResidentsOverlay") as Control
	var exped := overlay.find_child("ResidentsExpeditionButton", true, false) as Control if overlay != null else null
	var hint := _live_map_hand_hint(map)
	ok(overlay != null and exped != null and exped.is_visible_in_tree(),
		"the player-reachable Residents modal exposes its Expedition footer button")
	ok(exped != null and exped.get_global_rect().size.x >= 100.0
			and exped.get_global_rect().size.y >= 40.0,
		"the real Expedition footer button keeps a player-sized pointer target when no OS window is reported")
	ok(hint != null and hint.get_parent() == overlay,
		"the Rush hand hint mounts inside the active modal so it renders over the visible footer")
	if overlay != null and exped != null and hint != null:
		ok(hint.gesture == HandHint.GESTURE_TAP,
			"the modal-hosted Rush teach uses the tap gesture")
		ok(hint.mouse_filter == Control.MOUSE_FILTER_IGNORE and _all_ignore(hint),
			"the hand, veil, and every overlay child are input-transparent")
		var cutouts: Array = hint.cutouts()
		var button_center: Vector2 = exped.get_global_rect().get_center() - overlay.get_global_rect().position
		ok(cutouts.size() == 1 and (cutouts[0] as Rect2).has_point(button_center),
			"the modal hint's bright cutout contains the reachable Residents Expedition button")
		ok(exped.has_meta("_fx_breathing") == FX.breathe_active(),
			"the reachable Residents Expedition CTA follows the existing breathe_cta treatment")
		var hint_instance_id := hint.get_instance_id()
		var original_cutout := (cutouts[0] as Rect2) if not cutouts.is_empty() else Rect2()
		var original_center := exped.get_global_rect().get_center()
		var row_spacer := Control.new()
		row_spacer.custom_minimum_size = Vector2(96.0, 0.0)
		exped.get_parent().add_child(row_spacer)
		exped.get_parent().move_child(row_spacer, 0)
		await process_frame
		var moved_center := exped.get_global_rect().get_center()
		ok(not moved_center.is_equal_approx(original_center),
			"setup: a settled modal row change moves the live Expedition target")
		map._maybe_map_hand_hint()
		map._maybe_map_hand_hint()
		await _settle_map_teach()
		var retargeted := _live_map_hand_hints(map)
		var moved_local_center := moved_center - overlay.get_global_rect().position
		var moved_cutouts: Array = (retargeted[0] as Control).cutouts() if not retargeted.is_empty() else []
		ok(retargeted.size() == 1 and (retargeted[0] as Control).get_instance_id() == hint_instance_id,
			"repeated modal layout refreshes retarget one live hint without duplication")
		ok(moved_cutouts.size() == 1
				and not (moved_cutouts[0] as Rect2).is_equal_approx(original_cutout)
				and (moved_cutouts[0] as Rect2).has_point(moved_local_center),
			"the reused modal hint retargets its cutout to the Expedition button's settled position")
	var close := overlay.find_child("DialogClose", true, false) as Button if overlay != null else null
	ok(close != null, "the Residents modal exposes its real close button")
	var close_state := {"exited": false, "breathing": true}
	if overlay != null and exped != null:
		overlay.tree_exiting.connect(func() -> void:
			close_state.exited = true
			close_state.breathing = exped.has_meta("_fx_breathing"))
	if close != null:
		_push_gui_tap(close.get_global_rect().get_center())
	await _settle_map_teach()
	ok(_live_map_hand_hint(map) == null and map._map_hand_hint == null,
		"closing Residents tears down the map hint instead of stranding it over Home")
	ok(bool(close_state.exited) and not bool(close_state.breathing)
			and map._map_hand_hint_target == null,
		"DialogClose clears the CTA breathe loop and every map-owned hint reference")
	ok(not Save.ftue_seen("unlock_rush"),
		"closing Residents without opening Expedition does not bank the Rush teach")
	if residents_tile != null:
		residents_tile.pressed.emit()
	await _settle_map_teach()
	overlay = map.get_node_or_null("ResidentsOverlay") as Control
	var real_exped := overlay.find_child("ResidentsExpeditionButton", true, false) as Button if overlay != null else null
	ok(real_exped != null and _live_map_hand_hint(map) != null,
		"reopening Residents re-presents the unbanked teach on its real Expedition button")
	if real_exped != null:
		_push_gui_tap(real_exped.get_global_rect().get_center())
	await process_frame
	ok(Save.ftue_seen("unlock_rush") and _live_map_hand_hint(map) == null
			and map.get_node_or_null("ExpeditionOverlay") != null,
		"a real pointer tap passes through the hint, banks Rush, and opens Expedition normally")
	await drop(map)

func _test_rush_modal_hint_rejects_hidden_and_queued_targets() -> void:
	fresh("teach_rush_modal_target_lifecycle")
	complete_scene(0)
	_set_level(G.FEATURE_LEVEL["rush"])
	var map := map_host()
	map._login_shown_launch = true
	var residents_tile := map.get_node_or_null("ResidentsTile") as Button
	if residents_tile != null:
		residents_tile.pressed.emit()
	await _settle_map_teach()
	var overlay := map.get_node_or_null("ResidentsOverlay") as Control
	var exped := overlay.find_child("ResidentsExpeditionButton", true, false) as Control if overlay != null else null
	var live := _live_map_hand_hint(map)
	ok(overlay != null and exped != null and live != null,
		"setup: the visible Residents target owns a live modal hint")
	if overlay != null:
		overlay.visible = false
	map._maybe_map_hand_hint()
	await _settle_map_teach()
	ok(map._expedition_button() == null and _live_map_hand_hint(map) == null
			and map._map_hand_hint_target == null,
		"an ancestor-hidden Expedition target is rejected and its hint is dismissed")
	if exped != null:
		ok(not exped.has_meta("_fx_breathing"),
			"hiding the target's ancestor also clears its breathe loop")
	if overlay != null:
		overlay.visible = true
	map._maybe_map_hand_hint()
	await _settle_map_teach()
	var replay := _live_map_hand_hint(map)
	ok(replay != null and map._expedition_button() == exped,
		"restoring the visible modal re-presents the still-unbanked teach")
	if exped != null:
		exped.queue_free()
		ok(map._expedition_button() == null,
			"a queued Expedition control is rejected immediately instead of becoming a stale target")
	map._maybe_map_hand_hint()
	await _settle_map_teach()
	ok(_live_map_hand_hint(map) == null and map._map_hand_hint == null
			and map._map_hand_hint_target == null,
		"removing the queued target tears down the modal hint without replay")
	ok(not Save.ftue_seen("unlock_rush"),
		"target lifecycle changes never bank the Rush teach")
	await drop(map)

func _test_rush_modal_hint_tears_down_with_the_map_host() -> void:
	fresh("teach_rush_modal_host_exit")
	complete_scene(0)
	_set_level(G.FEATURE_LEVEL["rush"])
	var map := map_host()
	map._login_shown_launch = true
	var residents_tile := map.get_node_or_null("ResidentsTile") as Button
	if residents_tile != null:
		residents_tile.pressed.emit()
	await _settle_map_teach()
	var overlay := map.get_node_or_null("ResidentsOverlay") as Control
	var exped := overlay.find_child("ResidentsExpeditionButton", true, false) as Control if overlay != null else null
	ok(overlay != null and exped != null and _live_map_hand_hint(map) != null,
		"setup: the map exits with a live Residents hint and breathing CTA")
	var exit_state := {"exited": false, "breathing": true, "hint_ref": true, "target_ref": true}
	if overlay != null and exped != null:
		overlay.tree_exiting.connect(func() -> void:
			exit_state.exited = true
			exit_state.breathing = exped.has_meta("_fx_breathing")
			exit_state.hint_ref = map._map_hand_hint != null
			exit_state.target_ref = map._map_hand_hint_target != null)
	map.queue_free()
	await process_frame
	ok(bool(exit_state.exited) and not bool(exit_state.breathing)
			and not bool(exit_state.hint_ref) and not bool(exit_state.target_ref),
		"host exit clears the live hint, CTA breathe loop, and map-owned references")
	ok(not Save.ftue_seen("unlock_rush"),
		"leaving the map host without opening Expedition does not bank Rush")

func _test_rush_map_teach_points_at_the_visible_expedition_button() -> void:
	fresh("teach_rush_map_surface")
	complete_scene(0)
	_set_level(G.FEATURE_LEVEL["rush"] - 1)
	var below := map_host()
	below._open_select()
	await _settle_map_teach()
	ok(below.content.find_child("BucketExpeditionButton", true, false) == null,
		"below L%d the real Bucket surface offers no Expedition button" % int(G.FEATURE_LEVEL["rush"]))
	ok(_live_map_hand_hint(below) == null,
		"below L%d the map cannot present the Rush hand hint" % int(G.FEATURE_LEVEL["rush"]))
	await drop(below)

	fresh("teach_rush_map_no_cell")
	_set_level(G.FEATURE_LEVEL["rush"])
	var no_cell := map_host()
	no_cell._open_select()
	await _settle_map_teach()
	ok(no_cell.content.find_child("BucketExpeditionButton", true, false) == null,
		"L%d without a bucket cell offers no Expedition button" % int(G.FEATURE_LEVEL["rush"]))
	ok(_live_map_hand_hint(no_cell) == null,
		"L%d without a bucket cell cannot present the Rush hand hint" % int(G.FEATURE_LEVEL["rush"]))
	await drop(no_cell)

	fresh("teach_rush_map_visible")
	complete_scene(0)
	_set_level(G.FEATURE_LEVEL["rush"])
	var map := map_host()
	map._open_select()
	await _settle_map_teach()
	var exped := map.content.find_child("BucketExpeditionButton", true, false) as Control
	var hint := _live_map_hand_hint(map)
	ok(exped != null and exped.visible,
		"at L%d with a bucket cell the real dock exposes Bucket Expedition" % int(G.FEATURE_LEVEL["rush"]))
	ok(hint != null and hint.gesture == HandHint.GESTURE_TAP,
		"the visible Bucket Expedition button gets the map's tap hand hint")
	if exped != null and hint != null:
		var cutouts: Array = hint.cutouts()
		var button_center: Vector2 = exped.get_global_rect().get_center() - map.get_global_rect().position
		ok(cutouts.size() == 1 and (cutouts[0] as Rect2).has_point(button_center),
			"the hint's one bright cutout contains the visible Expedition button")
		ok(hint.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"the map hand hint remains input-transparent over the real button")
		ok(exped.has_meta("_fx_breathing") == FX.breathe_active(),
			"the taught Expedition CTA follows the existing breathe_cta treatment")
		var hint_instance_id := hint.get_instance_id()
		map._maybe_map_hand_hint()
		await _settle_map_teach()
		var retargeted := _live_map_hand_hint(map)
		ok(retargeted != null and retargeted.get_instance_id() == hint_instance_id,
			"re-evaluating the same visible target retargets one live hint instead of restarting it")
	await drop(map)

func _test_rush_map_teach_banks_on_the_real_open_and_does_not_replay() -> void:
	fresh("teach_rush_map_bank")
	complete_scene(0)
	_set_level(G.FEATURE_LEVEL["rush"])
	var map := map_host()
	map._open_select()
	await _settle_map_teach()
	var exped := map.content.find_child("BucketExpeditionButton", true, false) as Button
	var live := _live_map_hand_hint(map)
	ok(exped != null and live != null and not Save.ftue_seen("unlock_rush"),
		"setup: an unseen Rush teach points at the real Expedition button")
	if exped != null:
		exped.pressed.emit()
	ok(Save.ftue_seen("unlock_rush"),
		"pressing the visible Expedition button banks unlock_rush in the real open path")
	ok(_live_map_hand_hint(map) == null and (live == null or live.dismissed),
		"opening Expedition dismisses the live map hand hint immediately")
	var overlay := map.get_node_or_null("ExpeditionOverlay")
	if overlay != null:
		overlay.queue_free()
	map._open_map(0, false)
	map._open_select()
	await _settle_map_teach()
	ok(_live_map_hand_hint(map) == null,
		"a rebuilt Bucket surface does not replay the banked Rush teach")
	map._open_residents()
	await _settle_map_teach()
	ok(_live_map_hand_hint(map) == null,
		"opening the alternate Residents Expedition surface does not replay the banked teach")
	await drop(map)

func _test_rush_map_teach_leaves_with_its_visible_surface() -> void:
	fresh("teach_rush_map_teardown")
	complete_scene(0)
	_set_level(G.FEATURE_LEVEL["rush"])
	var map := map_host()
	map._open_select()
	await _settle_map_teach()
	var live := _live_map_hand_hint(map)
	ok(live != null, "setup: the Rush map hint is live over the Bucket surface")
	map._open_map(0, false)
	await _settle_map_teach()
	ok(_live_map_hand_hint(map) == null and (live == null or live.dismissed),
		"leaving the Bucket surface tears down its map hand hint")
	await drop(map)

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
	var threshold := int(G.MAGNET_STAGE_MERGES)
	for _i in range(threshold - 1):
		Save.bump_magnet_armed_merges()
	ok(Save.magnet_armed_merges() == threshold - 1 and not Save.magnet_stage_due(),
		"exactly %d armed merges is still inside the drop-first window" % (threshold - 1))
	Save.bump_magnet_armed_merges()
	ok(Save.magnet_armed_merges() == threshold and Save.magnet_stage_due(),
		"the staging grant becomes due exactly on armed merge %d" % threshold)

func _open_magnet_stage_board(save_id: String, armed_merges: int) -> Node:
	fresh(save_id)
	Save.mark_ftue_seen("merge")
	Save.mark_ftue_seen("gen_tap")
	Save.mark_ftue_seen("unlock_weather")
	Save.mark_ftue_seen("unlock_cascade")
	Save.mark_ftue_seen("soil")
	Save.mark_ftue_seen("soil_seed")
	Save.mark_board_tutorial_seen()
	_set_level(G.FEATURE_LEVEL["magnet"])
	Save.grove()["magnet_armed_merges"] = armed_merges
	Save.grove_write()
	var b = board_host()
	await process_frame
	b._sky_state = {}
	b.quests = []
	return b

func _magnet_seed_count(b: Node) -> int:
	var code := Improvements.seed_code_for_kind(Improvements.KIND_MAGNET)
	return b.board.count_of(code) + b.bag.count(code)

func _merge_rng_seed_for_magnet_drop(want_drop: bool) -> int:
	var magnet_code := Improvements.seed_code_for_kind(Improvements.KIND_MAGNET)
	for seed in range(1, 20000):
		var probe := RandomNumberGenerator.new()
		probe.seed = seed
		var drops := BoardLogicRef.roll_merge_drops(102, probe, {}, false, [])
		if drops.has(magnet_code) == want_drop:
			return seed
	return -1

func _real_stage_merge(b: Node, from: Vector2i, to: Vector2i, rng_seed: int) -> void:
	b.rng.seed = rng_seed
	_input_drag_merge(b, from, to)
	await _wait_teach_board_idle(b)
	await process_frame

func _test_magnet_natural_drop_suppresses_staging_at_the_merge_seam() -> void:
	var threshold := int(G.MAGNET_STAGE_MERGES)
	var b = await _open_magnet_stage_board("teach_magnet_natural_drop", threshold - 1)
	var from := Vector2i(0, 0)
	var to := Vector2i(0, 1)
	_blank_teach_fixture(b, {from: 101, to: 101})
	var drop_seed := _merge_rng_seed_for_magnet_drop(true)
	ok(drop_seed > 0, "fixture finds a real board-RNG stream whose merge drops a Magnet seed")
	await _real_stage_merge(b, from, to, drop_seed)
	ok(_magnet_seed_count(b) == 1 and Save.magnet_armed_merges() == threshold - 1,
		"a successful natural Magnet drop suppresses both the fallback and its counter at the real merge seam")
	ok(not Save.magnet_stage_granted(),
		"a natural drop does not spend the one-shot fallback")
	await drop(b)

func _test_magnet_held_seed_suppresses_staging_at_the_merge_seam() -> void:
	var threshold := int(G.MAGNET_STAGE_MERGES)
	var b = await _open_magnet_stage_board("teach_magnet_held_seed", threshold - 1)
	var from := Vector2i(0, 0)
	var to := Vector2i(0, 1)
	var held := Vector2i(1, 0)
	_blank_teach_fixture(b, {
		from: 101,
		to: 101,
		held: Improvements.seed_code_for_kind(Improvements.KIND_MAGNET),
	})
	await _real_stage_merge(b, from, to, _merge_rng_seed_for_magnet_drop(false))
	ok(_magnet_seed_count(b) == 1 and Save.magnet_armed_merges() == threshold - 1,
		"a held Magnet seed suppresses staging without consuming another armed merge")
	ok(not Save.magnet_stage_granted(),
		"holding a seed does not spend the one-shot fallback")
	await drop(b)

func _test_magnet_stage_grants_ground_once_and_persists_after_sale() -> void:
	var threshold := int(G.MAGNET_STAGE_MERGES)
	var b = await _open_magnet_stage_board("teach_magnet_ground_once", threshold - 1)
	var from := Vector2i(0, 0)
	var to := Vector2i(0, 1)
	_blank_teach_fixture(b, {from: 101, to: 101})
	var quiet_seed := _merge_rng_seed_for_magnet_drop(false)
	await _real_stage_merge(b, from, to, quiet_seed)
	var magnet_code := Improvements.seed_code_for_kind(Improvements.KIND_MAGNET)
	ok(b.board.count_of(magnet_code) == 1 and not b.bag.has(magnet_code),
		"armed merge %d grants the fallback to buildable ground before the bag" % threshold)
	ok(Save.magnet_stage_granted(),
		"a successful ground fallback persists its one-shot payout state")
	Save.load_now()
	ok(Save.magnet_stage_granted(),
		"the one-shot payout state survives a real save reload")

	var seed_cell := Vector2i(-1, -1)
	for raw_cell in b.piece_nodes:
		var cell := Vector2i(raw_cell)
		if b.board.item_at(cell) == magnet_code:
			seed_cell = cell
			break
	ok(seed_cell.x >= 0, "the fallback seed is reachable through the live piece registry for sale")
	if seed_cell.x >= 0:
		b._sell_item(seed_cell, b.piece_nodes.get(seed_cell))
		await process_frame
	ok(not Save.ftue_seen("unlock_magnet") and _magnet_seed_count(b) == 0,
		"selling the fallback keeps bank-on-placement semantics and removes the seed")

	var empties: Array = b.board.empty_ground_cells()
	ok(empties.size() >= 2, "fixture leaves a second real merge after the fallback seed is sold")
	if empties.size() >= 2:
		var again_from := Vector2i(empties[0])
		var again_to := Vector2i(empties[1])
		b.board.place(again_from, 201)
		b.board.place(again_to, 201)
		b._rebuild_all()
		await _real_stage_merge(b, again_from, again_to, quiet_seed)
	ok(_magnet_seed_count(b) == 0,
		"selling/removing the first fallback cannot turn every later merge into another sellable seed")
	await drop(b)

func _test_magnet_stage_falls_back_to_the_bag() -> void:
	var threshold := int(G.MAGNET_STAGE_MERGES)
	var b = await _open_magnet_stage_board("teach_magnet_bag_fallback", threshold - 1)
	var from := Vector2i(3, 3)
	var to := Vector2i(3, 4)
	for i in b.board.items.size():
		b.board.terrain[i] = 1
		b.board.items[i] = 0
	b.board.collect_rewards = {}
	b.board.gens = {}
	b.board.gen_boost = {}
	b.board.improvements = {}
	b.board.terrain[BoardModel.idx(from)] = 0
	b.board.terrain[BoardModel.idx(to)] = 0
	ok(b.board.build_improvement(from, Improvements.KIND_SOIL),
		"bag fixture sockets the vacated merge cell so it cannot accept a staged improvement seed")
	b.board.place(from, 101)
	b.board.place(to, 101)
	b.bag = []
	b.bag_seed_ranks = []
	b._rebuild_all()
	await _real_stage_merge(b, from, to, _merge_rng_seed_for_magnet_drop(false))
	var magnet_code := Improvements.seed_code_for_kind(Improvements.KIND_MAGNET)
	ok(b.board.count_of(magnet_code) == 0 and b.bag.count(magnet_code) == 1,
		"when no ground cell can build an improvement, the fallback grants exactly one seed to the bag")
	ok(Save.magnet_stage_granted(),
		"the bag fallback also persists the one-shot payout state")
	await drop(b)

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

func _test_mastery_ring_hidden_until_revealed() -> void:
	fresh("reveal_mastery")
	_set_level(G.FEATURE_LEVEL["mastery"])
	Save.mark_ftue_seen("merge")
	Save.mark_ftue_seen("gen_tap")
	Save.mark_board_tutorial_seen()
	var line := int(G.ZONE_BASE_LINES[0])
	Save.grove()["mastery"] = {str(line): int(G.MASTERY_THRESHOLDS[1])}
	var h = board_host()
	await process_frame
	var rings_before := _count_nodes_named(h, "MasteryRing")
	ok(rings_before == 0, "no mastery ring is attached while the feature is unrevealed")
	FeatureGate.mark_revealed("mastery")
	h._refresh_mastery_chrome()
	await process_frame
	var gen_cell := _mastery_gen_cell(h, line)
	_seed_mastery_trim_fixture(h, gen_cell)
	ok(_count_nodes_named(h, "MasteryRing") > 0, "the ring attaches once revealed")
	ok(_count_nodes_named(h, "MasteryTrim") > 0,
		"fixture: revealed mastery has both ring and trim chrome to tear down")

	fresh("reveal_mastery_reset")
	_set_level(G.FEATURE_LEVEL["mastery"])
	Save.grove()["mastery"] = {str(line): int(G.MASTERY_THRESHOLDS[1])}
	h._refresh_mastery_chrome()
	await process_frame # queue_free is deferred: observe teardown only after the frame lands
	ok(_count_nodes_named(h, "MasteryRing") == 0,
		"reveal reset tears down the stale mastery ring after queue_free lands")
	ok(_count_nodes_named(h, "MasteryTrim") == 0,
		"reveal reset tears down the stale mastery trim after queue_free lands")

	FeatureGate.mark_revealed("mastery")
	h._refresh_mastery_chrome()
	_seed_mastery_trim_fixture(h, gen_cell)
	var old_mastery := bool(Feat.FLAGS.get("mastery", true))
	Feat.FLAGS["mastery"] = false
	h._refresh_mastery_chrome()
	Feat.FLAGS["mastery"] = old_mastery
	await process_frame # the disabled-feature guard queues both nodes
	ok(_count_nodes_named(h, "MasteryRing") == 0,
		"disabling mastery tears down the attached ring after queue_free lands")
	ok(_count_nodes_named(h, "MasteryTrim") == 0,
		"disabling mastery tears down the attached trim after queue_free lands")

	h._refresh_mastery_chrome()
	_seed_mastery_trim_fixture(h, gen_cell)
	Save.grove()["mastery"] = {}
	h._refresh_mastery_chrome()
	await process_frame # the meter-absent branch also queues both nodes
	ok(_count_nodes_named(h, "MasteryRing") == 0,
		"removing the meter tears down the attached ring after queue_free lands")
	ok(_count_nodes_named(h, "MasteryTrim") == 0,
		"removing the meter tears down the attached trim after queue_free lands")
	await drop(h)

func _seed_mastery_trim_fixture(h: Node, cell: Vector2i) -> void:
	if cell.x < 0:
		return
	var gn: Control = h.gen_nodes.get(cell)
	if gn == null:
		return
	var old := gn.get_node_or_null("MasteryTrim")
	if old != null and not old.is_queued_for_deletion():
		return
	if old != null:
		gn.remove_child(old)
	# The authored trim textures are optional and absent in this checkout. Install the same
	# TextureRect chrome shape so every teardown branch must remove both owned node names.
	var trim := TextureRect.new()
	trim.name = "MasteryTrim"
	gn.add_child(trim)

func _count_nodes_named(n: Node, want: String) -> int:
	var c := 0
	if n.name == want:
		c += 1
	for ch in n.get_children():
		c += _count_nodes_named(ch, want)
	return c

func _test_mastery_reveal_sweeps_on_real_generator_tap() -> void:
	fresh("reveal_mastery_tap")
	_set_level(G.FEATURE_LEVEL["mastery"])
	Save.mark_ftue_seen("merge")
	Save.mark_ftue_seen("gen_tap")
	Save.mark_board_tutorial_seen()
	var line := int(G.ZONE_BASE_LINES[0])
	# 40 is exactly halfway from rank-1's threshold (20) to rank-2's (60):
	# the reveal sweep must visibly settle at 0.5, independently of the production helper.
	Save.grove()["mastery"] = {str(line): 40}
	var h = board_host()
	await process_frame
	# Keep this test on the mastery path: an unrelated low-probability bonus/treat generator
	# roll rebuilds every generator node, which makes the identity assertion below stochastic.
	h.rng.seed = 424242
	_ensure_empty_ground_cells(h, 4)
	await process_frame
	var gen_cell := _mastery_gen_cell(h, line)
	ok(gen_cell.x >= 0, "fixture: the live board has the mastery line's generator")
	ok(_count_nodes_named(h, "MasteryRing") == 0,
		"the real tap starts with mastery armed, banked, and unrevealed")
	var meter_before := Mastery.meter(line)
	var pops_before := int(Save.grove().get("pops", 0))
	if gen_cell.x >= 0:
		_tap_board(h, h._cell_pos(gen_cell) + Vector2(h.csz, h.csz) / 2.0)
	ok(FeatureGate.revealed("mastery"),
		"a real still-tap through the board input surface reveals mastery")
	var ring: Control = h.gen_nodes.get(gen_cell).get_node_or_null("MasteryRing") if gen_cell.x >= 0 else null
	ok(ring != null, "the same generator tap attaches its mastery ring")
	var saw_mid_sweep := false
	if ring != null:
		for _i in 12:
			await process_frame
			if ring.progress > 0.0 and ring.progress < 0.48:
				saw_mid_sweep = true
				break
	ok(saw_mid_sweep,
		"the attached ring is visibly mid-sweep instead of snapping to its banked value")
	await create_timer(0.95).timeout
	if ring != null:
		ok(absf(ring.progress - 0.5) < 0.03,
			"the reveal sweep settles at the banked rank progress over its 0.9-second beat")
	ok(Mastery.meter(line) == meter_before,
		"revealing mastery does not accrue or consume any mastery")
	ok(int(Save.grove().get("pops", 0)) > pops_before,
		"the reveal runs before, without consuming, the existing generator tap")
	var pops_after_reveal := int(Save.grove().get("pops", 0))
	var revealed_before_second := FeatureGate.revealed("mastery")
	if gen_cell.x >= 0:
		_tap_board(h, h._cell_pos(gen_cell) + Vector2(h.csz, h.csz) / 2.0)
	ok(FeatureGate.revealed("mastery") == revealed_before_second,
		"a second real generator tap leaves the already-revealed ledger state unchanged")
	ok(ring != null and h.gen_nodes.get(gen_cell).get_node_or_null("MasteryRing") == ring,
		"the second tap keeps the actual revealed generator ring")
	await process_frame
	await process_frame
	if ring != null:
		ok(ring.progress > 0.48,
			"the second tap does not restart or reset the completed reveal sweep")
	ok(int(Save.grove().get("pops", 0)) > pops_after_reveal,
		"the already-revealed guard preserves the second tap's normal generator pop")
	await drop(h)

func _test_mastery_reveal_skips_ineligible_real_generator_taps() -> void:
	var line := int(G.ZONE_BASE_LINES[0])
	fresh("reveal_mastery_zero")
	_set_level(G.FEATURE_LEVEL["mastery"])
	Save.mark_ftue_seen("merge")
	Save.mark_ftue_seen("gen_tap")
	Save.mark_board_tutorial_seen()
	var empty_h = board_host()
	await process_frame
	var empty_cell := _mastery_gen_cell(empty_h, line)
	if empty_cell.x >= 0:
		_tap_board(empty_h, empty_h._cell_pos(empty_cell) + Vector2(empty_h.csz, empty_h.csz) / 2.0)
	ok(not FeatureGate.revealed("mastery"),
		"a real generator tap with no banked meter does not reveal mastery")
	await drop(empty_h)

	fresh("reveal_mastery_low")
	_set_level(G.FEATURE_LEVEL["mastery"] - 1)
	Save.mark_ftue_seen("merge")
	Save.mark_ftue_seen("gen_tap")
	Save.mark_board_tutorial_seen()
	Save.grove()["mastery"] = {str(line): 40}
	var low_h = board_host()
	await process_frame
	var low_cell := _mastery_gen_cell(low_h, line)
	if low_cell.x >= 0:
		_tap_board(low_h, low_h._cell_pos(low_cell) + Vector2(low_h.csz, low_h.csz) / 2.0)
	ok(not FeatureGate.revealed("mastery"),
		"a real generator tap below the mastery level does not reveal a banked meter")
	await drop(low_h)

	fresh("reveal_mastery_invalid_line")
	_set_level(G.FEATURE_LEVEL["mastery"])
	Save.mark_ftue_seen("merge")
	Save.mark_ftue_seen("gen_tap")
	Save.mark_board_tutorial_seen()
	Save.grove()["mastery"] = {str(line): 40}
	var invalid_h = board_host()
	await process_frame
	var acc_kind := String(G.ACCUMULATORS.keys()[0])
	var acc_id := String((G.ACCUMULATORS[acc_kind] as Dictionary).get("id", ""))
	var acc_cell := Vector2i(invalid_h.board.empty_ground_cells()[0])
	invalid_h.board.place_gen(acc_id, acc_cell)
	Save.grove()["bonus_clicks"] = 2
	invalid_h._rebuild_all()
	await process_frame
	ok(invalid_h._gen_line(invalid_h.board.gen_id_at(acc_cell)) <= 0,
		"fixture: the real accumulator generator resolves to an invalid mastery line")
	_tap_board(invalid_h,
		invalid_h._cell_pos(acc_cell) + Vector2(invalid_h.csz, invalid_h.csz) / 2.0)
	ok(not FeatureGate.revealed("mastery"),
		"a real invalid-line generator tap does not reveal mastery")
	ok(_count_nodes_named(invalid_h.gen_nodes.get(acc_cell), "MasteryRing") == 0,
		"the invalid-line generator tap attaches and sweeps no mastery ring")
	ok(invalid_h.board.is_gen(acc_cell) and int(Save.grove().get("bonus_clicks", 0)) == 1,
		"the invalid-line guard preserves the accumulator's normal safe tap behavior")
	await drop(invalid_h)

func _ensure_empty_ground_cells(h: Node, want: int) -> void:
	if h.board.empty_ground_cells().size() >= want:
		return
	for raw_cell in h.piece_nodes.keys():
		var cell := Vector2i(raw_cell)
		if h.board.item_at(cell) > 0:
			h.board.take(cell)
		if h.board.empty_ground_cells().size() >= want:
			break
	h._rebuild_all()

func _mastery_gen_cell(h: Node, line: int) -> Vector2i:
	for raw_cell in h.board.gens:
		var cell := Vector2i(raw_cell)
		if h._gen_line(h.board.gen_id_at(cell)) == line:
			return cell
	return Vector2i(-1, -1)

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

## A chain now arms at x2, but that is not enough player-built runway for the one-time teach.
## The break this catches is binding the teach to CHAIN_MIN_N after that constant moved from 3 to 2.
func _test_cascade_teach_requires_a_built_runway_not_the_chain_floor() -> void:
	var b = await _open_teach_board("teach_cascade_runway_threshold", G.FEATURE_LEVEL["cascade"], true)
	var from := Vector2i(3, 2)
	var to := Vector2i(3, 1)
	_blank_teach_fixture(b, {
		from: 101,
		to: 101,
		Vector2i(3, 0): 102,
	})
	ok(1 + BoardLogicRef.chain_path(b.board, from, to).size() == 2,
		"fixture offers a real x2 chain at the chain arming floor")
	ok(b._cascade_teach_pair().is_empty(),
		"cascade teach ignores x2 — it waits for the stronger runway the player built")

	_blank_teach_fixture(b, {
		from: 101,
		to: 101,
		Vector2i(3, 0): 102,
		Vector2i(2, 0): 103,
	})
	var pair: Array = b._cascade_teach_pair()
	ok(pair == [from, to]
			and 1 + BoardLogicRef.chain_path(b.board, pair[0], pair[1]).size() == 3,
		"cascade teach points once the same drag reaches a real x3 runway")
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
