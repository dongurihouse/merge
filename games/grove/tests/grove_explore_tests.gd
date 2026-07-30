extends "res://games/grove/tests/grove_test_base.gd"
## grove · explore — guards engine/scripts/core/explore.gd (the acquire model: loadout costs/cfg,
## Rush scoring, grid helpers, the box/unlocked-pool seam, and cross-scene run state). Pure-model
## coverage; the real-time Rush *feel* needs an interactive run. Active suite (in GROVE_TESTS).

const Look = preload("res://engine/scripts/ui/skin.gd")
const ActionBarKit = preload("res://engine/scripts/ui/action_bar.gd")
const Explore = preload("res://engine/scripts/core/explore.gd")
const Bucket = preload("res://engine/scripts/core/bucket.gd")
const ExploreReward = preload("res://engine/scripts/ui/explore_reward.gd")
const ResidentsUI = preload("res://engine/scripts/ui/residents.gd")
const ComboBloom = preload("res://engine/scripts/ui/combo_bloom.gd")
const Ambient = preload("res://engine/scripts/ui/ambient.gd")
const FX = preload("res://engine/scripts/ui/fx.gd")
const FxDefs = preload("res://games/grove/tools/fx_defs.gd")
const FxWorkbenchView = preload("res://games/grove/tools/fx_workbench_view.gd")
const Kit = preload("res://games/grove/ui_kit.gd")
const Tune = preload("res://engine/scripts/core/tuning.gd").FX
const MapScript = preload("res://engine/scripts/scenes/map.gd")
const NavBarKit = preload("res://engine/scripts/ui/nav_bar.gd")   # the nav ROW's metric table (slots · gaps · chalk)
const CutPaper = preload("res://engine/scripts/ui/cut_paper.gd")  # …and the shadow falloff curve it tunes
const BoardActions = preload("res://engine/scripts/core/board_actions.gd")

func _initialize() -> void:
	begin("grove · explore acquire")
	_test_loadout()
	_test_rush_lines()
	_test_scoring()
	_test_grid()
	_test_hand_hint_logic()
	_test_pool_and_box()
	_test_run_state()
	_test_trade_count()
	_test_slot_reel()
	_test_screens()
	await _test_rush_board_skin()
	await _test_rush_resize()
	_test_trade_reward_dialog_layout()
	await _test_residents_dialog_uses_shared_frame()
	_test_reward_row_cap()
	await _test_map_card_expedition_chrome()
	await _test_bottom_bar_tab_geometry()
	await _test_dock_collect_chip()
	_test_loadout_uses_toggle_card_callback()
	await _test_loadout_toggle_updates_in_place()
	await _test_loadout_keeps_unaffordable_choices_visible()
	_test_rush_fx_knob_forwarding()
	_test_combo_bloom()
	await _test_mote_puff()
	_test_quest_unused_generator_fade()
	_test_swipe_commit_dir()
	_test_maps_gallery_featured_unlock_target()
	_test_maps_gallery_grid_lock_state()
	await _test_home_entry_uses_current_progress_page()
	await _test_home_opens_without_a_fade()
	await _test_home_has_no_page_arrows()
	await _test_home_prebuilds_window()
	await _test_home_tap_unlocks_cluster()
	await _test_home_swipe_commits_to_next_scene()
	await _test_home_swipe_commits_to_prev_scene()
	await _test_home_short_swipe_springs_back()
	await _test_home_swipe_at_first_page_is_noop()
	await _test_home_no_build_during_drag()
	await _test_home_swipe_resize_mid_commit_finalizes()
	await _test_endgame_fence_stays_live()
	await _test_purge_above_level_migration()
	await _test_farewell_cards_chain()
	await _test_grant_sale_flyaway_pays_once_with_fx_on_and_off()
	await _test_farewell_sweep_flyaway_pays_once_with_fx_on_and_off()
	await _test_fx_workbench_farewell_sweep_preview()
	await _test_almanac_entries_and_info_chip()
	await _test_generator_mastery_info_uses_shared_progress_bar()
	await _test_farewell_check_respects_generator_selection()
	await _test_farewell_check_resumes_after_bare_press()
	await _test_farewell_check_resumes_after_tap_that_clears_selection()
	finish()

# §8 line farewells through the REAL scene: due cards chain one at a time, ignore the legacy decline key,
# and sweep on every close path. The pure statics cover the board math; this pins the coordinator wiring.
func _test_farewell_cards_chain() -> void:
	fresh("farewell_cards")
	ok(ResourceLoader.exists("res://engine/scripts/ui/farewell_card.gd"), "farewell card script exists")
	Save.grove()["coins_earned"] = G.coins_at_level(G.zone_unlock_level(10))  # L65: 2,4,8 are away
	Save.grove()["retire_declined"] = {"gen_2": true}                         # legacy key must be ignored
	Save.grove_write()
	Save.mark_board_tutorial_seen()
	Save.mark_ftue_seen("soil")        # this fixture needs both starter empty cells for retired stock
	Save.mark_ftue_seen("soil_seed")
	var scn = board_host()
	await process_frame
	for r in G.ROWS:
		for c in G.COLS:
			scn.board.terrain[BoardModel.idx(Vector2i(r, c))] = 0
			scn.board.take(Vector2i(r, c))
	for cell in scn.board.gens.keys():
		scn.board.remove_gen(cell)
	var stale_farewell := scn.find_child("FarewellCardOverlay", true, false) as Control
	if stale_farewell != null:
		stale_farewell.queue_free()
		await process_frame
	var free_cells: Array = scn.board.empty_ground_cells()
	ok(free_cells.size() >= 6, "fixture: the board has ground for chained farewells")
	scn.board.place_gen("gen_2", free_cells[0])
	scn.board.arm_gen_boost(free_cells[0], 4)
	scn.board.place_gen("gen_4", free_cells[1])
	scn.board.place(free_cells[2], 2 * 100 + 2)
	scn.board.place(free_cells[3], 4 * 100 + 3)
	scn.board.place(free_cells[4], 8 * 100 + 1)
	scn.board.place(free_cells[5], 16 * 100 + 2)
	scn._rebuild_all()
	await process_frame
	var wallet_b := Save.coins()
	var clock_b := Save.coins_earned_lifetime()
	scn._queue_farewell_check()
	await process_frame
	await process_frame
	var seen_lines: Array = []
	for expected in [2, 4, 8]:
		var overlay := scn.find_child("FarewellCardOverlay", true, false) as Control
		ok(overlay != null and int(overlay.get_meta("farewell_line", 0)) == expected,
			"farewell card %d opens for line %d" % [seen_lines.size() + 1, expected])
		seen_lines.append(expected)
		var ok_btn := overlay.find_child("FarewellOK", true, false) as Button if overlay != null else null
		ok(ok_btn != null, "farewell card has one OK button")
		if ok_btn != null:
			ok_btn.pressed.emit()
		await process_frame
		await process_frame
	ok(seen_lines == [2, 4, 8], "farewell cards chain in zone order, one at a time")
	ok(scn.find_child("FarewellCardOverlay", true, false) == null, "the farewell chain ends after due lines are swept")
	ok(not scn.board.gens.values().has("gen_2") and not scn.board.gens.values().has("gen_4"),
		"closing the cards sweeps the away board generators")
	var kept: Dictionary = Save.grove().get("gen_kept", {})
	ok(kept.get("gen_2", []) == [4], "the swept boosted generator keeps its boost for the line's return")
	ok(Save.coins() > wallet_b and Save.coins_earned_lifetime() == clock_b,
		"farewell payouts are spendable-only and never advance the clock")
	scn._queue_farewell_check()
	await process_frame
	ok(scn.find_child("FarewellCardOverlay", true, false) == null, "migration is idempotent on re-entry")
	await drop(scn)

func _test_grant_sale_flyaway_pays_once_with_fx_on_and_off() -> void:
	var old_fly := bool(Feat.FLAGS.get("fly_to_wallet", true))
	FX.configure_reward_fx_config_for_test("user://tu_grove_sale_flyaway_fx.json")
	Feat.FLAGS["fly_to_wallet"] = true
	var scn = board_host()
	await process_frame
	await _assert_sale_flyaway_case(scn, 202, true, "enabled")
	await _assert_sale_flyaway_case(scn, 203, false, "disabled")
	Feat.FLAGS["fly_to_wallet"] = old_fly
	FX.configure_reward_fx_config_for_test("")
	await drop(scn, 3)

func _assert_sale_flyaway_case(scn: Node, code: int, fx_on: bool, label: String) -> void:
	FX.set_reward_fx_enabled("sale_payout", fx_on)
	var reward := G.sell_reward(code)
	var before_coins := Save.coins()
	var before_gems := Save.diamonds()
	var node := _make_flyaway_probe(scn, "SaleFlyaway%s" % label.capitalize(), Vector2(80, 190))
	scn._grant_sale(code, node)
	ok(Save.coins() == before_coins + int(reward.x) and Save.diamonds() == before_gems + int(reward.y),
		"_grant_sale credits exactly the configured sell reward with sale_payout %s" % label)
	await process_frame
	if fx_on:
		ok(is_instance_valid(node) and node.get_parent() == scn,
			"_grant_sale reparents the sold piece above board_area while it flies with sale_payout enabled")
	else:
		ok(not is_instance_valid(node),
			"_grant_sale frees the sold piece immediately when sale_payout is disabled")
	await create_timer(0.7).timeout
	ok(Save.coins() == before_coins + int(reward.x) and Save.diamonds() == before_gems + int(reward.y),
		"_grant_sale does not pay a second time after sale_payout %s settles" % label)

func _test_farewell_sweep_flyaway_pays_once_with_fx_on_and_off() -> void:
	var old_fly := bool(Feat.FLAGS.get("fly_to_wallet", true))
	FX.configure_reward_fx_config_for_test("user://tu_grove_farewell_flyaway_fx.json")
	Feat.FLAGS["fly_to_wallet"] = true
	var on_fix: Dictionary = await _farewell_fixture("farewell_flyaway_enabled")
	await _assert_farewell_flyaway_case(on_fix, true, "enabled")
	await drop(on_fix.scn, 3)
	var off_fix: Dictionary = await _farewell_fixture("farewell_flyaway_disabled")
	await _assert_farewell_flyaway_case(off_fix, false, "disabled")
	await drop(off_fix.scn, 3)
	Feat.FLAGS["fly_to_wallet"] = old_fly
	FX.configure_reward_fx_config_for_test("")

func _assert_farewell_flyaway_case(fix: Dictionary, fx_on: bool, label: String) -> void:
	var scn = fix.scn
	var line := 2
	var item_cell: Vector2i = fix.item
	var gen_cell: Vector2i = fix.gen
	var item_node: Control = scn.piece_nodes.get(item_cell)
	var gen_node: Control = scn.gen_nodes.get(gen_cell)
	var preview := BoardActions.farewell_preview(scn.board, line)
	var coins := int(preview.coins)
	var before_coins := Save.coins()
	FX.set_reward_fx_enabled("farewell_sweep", fx_on)
	scn._sweep_farewell(line, G.next_need(line, scn._quest_level()))
	ok(Save.coins() == before_coins + coins,
		"_sweep_farewell credits exactly preview coins up front with farewell_sweep %s" % label)
	ok(not scn.piece_nodes.has(item_cell) and not _piece_nodes_hold_line(scn, line),
		"_sweep_farewell removes swept-line entries from piece_nodes with farewell_sweep %s" % label)
	await process_frame
	if fx_on:
		ok(is_instance_valid(item_node) and item_node.get_parent() == scn,
			"_sweep_farewell keeps swept pieces alive above the rebuilt board while they fly")
		ok(is_instance_valid(gen_node) and gen_node.get_parent() == scn,
			"_sweep_farewell keeps the retired generator alive above the rebuilt board for its keepsake fade")
	else:
		ok(not is_instance_valid(item_node),
			"_sweep_farewell frees swept pieces immediately when farewell_sweep is disabled")
	await create_timer(1.25).timeout
	ok(Save.coins() == before_coins + coins,
		"_sweep_farewell does not pay a second time after farewell_sweep %s settles" % label)

func _make_flyaway_probe(scn: Node, node_name: String, pos: Vector2) -> Control:
	var node := ColorRect.new()
	node.name = node_name
	node.color = Color(1.0, 0.82, 0.25, 1.0)
	node.position = pos
	node.size = Vector2(52, 52)
	scn.board_area.add_child(node)
	return node

func _piece_nodes_hold_line(scn: Node, line: int) -> bool:
	for cell_v in scn.piece_nodes.keys():
		var cell := Vector2i(cell_v)
		var code: int = scn.board.item_at(cell)
		if code > 0 and not G.is_coin(code) and BoardModel.line_of(code) == int(line):
			return true
	return false

func _test_fx_workbench_farewell_sweep_preview() -> void:
	FX.configure_reward_fx_config_for_test("user://tu_grove_fx_workbench_farewell.json")
	FX.set_reward_fx_enabled("farewell_sweep", true)
	var def := FxDefs.def("farewell_sweep")
	ok(String(def.get("source_kind", "")) == "farewell_sweep",
		"FX workbench action table exposes the farewell_sweep batch preview")
	var view := FxWorkbenchView.new()
	get_root().add_child(view)
	await process_frame
	view.select_action("farewell_sweep")
	await process_frame
	var pieces := view.find_children("FarewellSweepPiece*", "Control", true, false)
	ok(pieces.size() == 6, "farewell_sweep workbench preview spawns a batch of dummy pieces")
	view.play_selected()
	await process_frame
	ok(view.find_children("FarewellSweepPiece*", "Control", true, false).size() > 0,
		"farewell_sweep workbench preview launches the batch instead of using a single reward icon")
	await create_timer(1.0).timeout
	ok(view.find_children("FarewellSweepPiece*", "Control", true, false).is_empty(),
		"farewell_sweep workbench preview frees dummy pieces after the batch finishes")
	FX.configure_reward_fx_config_for_test("")
	await drop(view, 2)

func _test_almanac_entries_and_info_chip() -> void:
	fresh("almanac_entries")
	ok(ResourceLoader.exists("res://engine/scripts/ui/almanac.gd"), "almanac script exists")
	Save.grove()["coins_earned"] = G.coins_at_level(G.zone_unlock_level(10))
	Save.grove()["seen"] = {"101": true, "201": true, "401": true, "801": true, "1601": true}
	Save.grove_write()
	Save.mark_board_tutorial_seen()
	var scn = board_host()
	await process_frame
	var entries: Array = scn._almanac_entries()
	ok(entries.size() == G.ZONE_COUNT, "almanac builds one zone-order cell per zone line")
	var by_line := {}
	for e in entries:
		by_line[int(e.line)] = e
	ok(bool(by_line[1].seen) and String(by_line[1].state) == "complete",
		"a seen done-forever line renders complete")
	ok(bool(by_line[2].seen) and String(by_line[2].state) == "away"
		and int(by_line[2].back_level) == G.zone_unlock_level(11) and int(by_line[2].for_line) == 19,
		"a seen away line carries its return level and reason")
	ok(bool(by_line[16].seen) and String(by_line[16].state) == "producing",
		"a seen line in the current need closure is producing now")
	ok(not bool(by_line[19].seen) and int(by_line[19].code) == 0,
		"an unseen line stays locked even when it has a future status")
	var chip := scn.find_child("AlmanacInfoButton", true, false) as Button
	ok(chip != null and chip.visible and not chip.disabled, "the empty info tray exposes the Almanac chip")
	ok(String(scn._info_label.text) == Strings.t("board.info.empty_prompt"),
		"the empty info tray keeps the normal tap-an-item prompt beside the Almanac button")
	ok(String(scn._info_desc_label.text) == Strings.t("board.info.empty_bag_hint"),
		"the empty info tray keeps the bag-space hint beside the Almanac button")
	if chip != null:
		ok(String(chip.get_meta("action_role", "")) == "almanac",
			"the Almanac entry is the shared action-button almanac role, not a stat chip")
	# …and it is made of the same MATERIAL as the bottom nav tabs and the Home/Bag wells beside it — the
	# shared paper-button surface treatment, without the tab's screen-edge geometry.
	assert_paper_button(chip, "the Almanac chip")
	if chip != null:
		chip.pressed.emit()
	await process_frame
	var almanac_overlay := scn.find_child("AlmanacOverlay", true, false) as Control
	ok(almanac_overlay != null, "pressing the empty-tray chip opens the Almanac")
	if almanac_overlay != null:
		var away_cell: Control = null
		for node in almanac_overlay.find_children("AlmanacCell*", "Control", true, false):
			if int((node as Control).get_meta("almanac_line", 0)) == 2:
				away_cell = node as Control
				break
		var art := away_cell.find_child("ItemArt", true, false) as Control if away_cell != null else null
		var status := away_cell.find_child("AlmanacStatusPill", true, false) as Control if away_cell != null else null
		ok(art != null and status != null and art.get_global_rect().end.y <= status.get_global_rect().position.y - 1.0,
			"an away Almanac status pill sits below the piece art instead of overlapping it")
		ok(away_cell.find_child("SlotContentShadow", true, false) == null,
			"Almanac cells do not stack the generic slot content shadow under scaled inactive art")
		ok(status != null and status.find_child("AlmanacStatusCutPaper", true, false) != null,
			"Almanac status text sits on a cut-paper background")
		almanac_overlay.queue_free()
	var free_cells: Array = scn.board.empty_ground_cells()
	scn.board.place(free_cells[0], 101)
	scn._rebuild_all()
	scn._select_item(free_cells[0])
	await process_frame
	ok(chip != null and not chip.visible, "the Almanac chip hides while an item selection is shown")
	await drop(scn)

func _test_generator_mastery_info_uses_shared_progress_bar() -> void:
	fresh("generator_mastery_info")
	var old_mastery := bool(Feat.FLAGS.get("mastery", true))
	Feat.FLAGS["mastery"] = true
	Save.grove()["mastery"] = {"2": 10}
	Save.grove_write()
	Save.mark_board_tutorial_seen()
	var scn = board_host()
	await process_frame
	for r in G.ROWS:
		for c in G.COLS:
			scn.board.terrain[BoardModel.idx(Vector2i(r, c))] = 0
			scn.board.take(Vector2i(r, c))
	for cell in scn.board.gens.keys():
		scn.board.remove_gen(cell)
	var gen_cell: Vector2i = scn.board.empty_ground_cells()[0]
	scn.board.place_gen("gen_2", gen_cell)
	scn._rebuild_all()
	scn._select_generator(gen_cell)
	await process_frame
	var row := scn.find_child("MasteryInfoRow", true, false) as Control
	var bar := scn.find_child("MasteryProgress", true, false) as Control
	ok(row != null and row.visible, "selecting a mastered generator shows the mastery meter row")
	ok(bar != null and not (bar is ProgressBar),
		"generator mastery info uses the shared Kit progress control, not a raw ProgressBar")
	ok(bar != null
		and bar.find_child("MasteryProgressTrack", true, false) != null
		and bar.find_child("MasteryProgressFillClip", true, false) != null
		and bar.find_child("MasteryProgressFill", true, false) != null,
		"generator mastery info exposes the shared progress-bar track and fill nodes")
	var next_label := scn.find_child("MasteryNext", true, false) as Label
	ok(next_label == null or not next_label.visible or String(next_label.text).strip_edges() == "",
		"generator mastery info does not show the next-tier copy")
	ok(String(scn._info_desc_label.text).to_lower().find("next:") < 0
		and String(scn._info_label.text).to_lower().find("next:") < 0,
		"generator info tray has no next-tier text payload")
	Feat.FLAGS["mastery"] = old_mastery
	await drop(scn)

# The §8 defer fixture the three farewell-resume tests share: an L65 save (line 2 is away), a board
# wiped to bare ground, and one away-line generator + one away-line item, so exactly one farewell is
# due. Returns {scn, gen, empty} — `empty` is bare ground a real gesture can land on without selecting
# anything, which is the case the resume used to lose.
func _farewell_fixture(name: String) -> Dictionary:
	fresh(name)
	Save.grove()["coins_earned"] = G.coins_at_level(G.zone_unlock_level(10))  # L65: line 2 is away
	Save.grove_write()
	Save.mark_board_tutorial_seen()
	Save.mark_ftue_seen("soil")
	Save.mark_ftue_seen("soil_seed")
	var scn = board_host()
	await process_frame
	var stale_farewell := scn.find_child("FarewellCardOverlay", true, false) as Control
	if stale_farewell != null:
		stale_farewell.queue_free()
		await process_frame
	for r in G.ROWS:
		for c in G.COLS:
			scn.board.terrain[BoardModel.idx(Vector2i(r, c))] = 0
			scn.board.take(Vector2i(r, c))
	for cell in scn.board.gens.keys():
		scn.board.remove_gen(cell)
	var free_cells: Array = scn.board.empty_ground_cells()
	ok(free_cells.size() >= 3, "fixture: board has room for the away generator, its item, and bare ground")
	var gen_cell: Vector2i = free_cells[0]
	var item_cell: Vector2i = free_cells[1]
	scn.board.place_gen("gen_2", gen_cell)
	scn.board.place(item_cell, 2 * 100 + 1)
	scn._rebuild_all()
	return {"scn": scn, "gen": gen_cell, "item": item_cell, "empty": free_cells[2]}

func _test_farewell_check_respects_generator_selection() -> void:
	var fix: Dictionary = await _farewell_fixture("farewell_generator_focus")
	var scn = fix.scn
	var gen_cell: Vector2i = fix.gen
	scn._select_generator(gen_cell)
	await process_frame
	ok(scn._selected_cell == gen_cell and scn.board.is_gen(gen_cell),
		"fixture: an away-line generator is selected before the queued farewell check")
	var selected_label := String(scn._info_label.text)
	scn._queue_farewell_check()
	await process_frame
	await process_frame
	ok(scn.find_child("FarewellCardOverlay", true, false) == null,
		"queued farewell checks wait while a generator info tray is selected")
	ok(scn._selected_cell == gen_cell and String(scn._info_label.text) == selected_label,
		"queued farewell checks do not defocus the selected generator")
	scn._clear_selection()
	await process_frame
	await process_frame
	var resumed := scn.find_child("FarewellCardOverlay", true, false) as Control
	ok(resumed != null and int(resumed.get_meta("farewell_line", 0)) == 2,
		"the deferred farewell check resumes once generator info clears")
	await drop(scn)

# A DEFERRED FAREWELL CARD MUST ALWAYS COME BACK. The check waits out a live gesture (press or drag)
# and a held info-tray selection — but the resume must not hang off "a selection was cleared", because
# the commonest gesture of all, a tap on bare ground, selects nothing to clear and ends with a release
# that clears no state. Both tests below drive the REAL press/release pair through the shipped input
# path (_on_board_input), so a resume that only fires from _clear_selection() fails here instead of
# silently stranding the card until the next level-up.
func _test_farewell_check_resumes_after_bare_press() -> void:
	var fix: Dictionary = await _farewell_fixture("farewell_resume_bare_press")
	var scn = fix.scn
	var empty: Vector2i = fix.empty
	ok(scn.board.item_at(empty) == 0 and not scn.board.is_gen(empty),
		"fixture: the tap cell is bare ground (a tap there selects nothing)")
	_board_touch(scn, empty, true)
	ok(scn._pressing and scn._selected_cell.x < 0,
		"fixture: a real press on bare ground is live with nothing selected")
	scn._queue_farewell_check()
	await process_frame
	await process_frame
	ok(scn.find_child("FarewellCardOverlay", true, false) == null,
		"a queued farewell check waits while a bare press is still down")
	_board_touch(scn, empty, false)
	await process_frame
	await process_frame
	await process_frame
	var resumed := scn.find_child("FarewellCardOverlay", true, false) as Control
	ok(resumed != null and int(resumed.get_meta("farewell_line", 0)) == 2,
		"the deferred farewell card opens when the press ends, though it cleared no selection")
	await drop(scn)

func _test_farewell_check_resumes_after_tap_that_clears_selection() -> void:
	var fix: Dictionary = await _farewell_fixture("farewell_resume_clearing_tap")
	var scn = fix.scn
	var empty: Vector2i = fix.empty
	scn._select_generator(fix.gen)
	await process_frame
	ok(scn._selected_cell == fix.gen, "fixture: the away generator is selected before the check is queued")
	scn._queue_farewell_check()
	await process_frame
	await process_frame
	ok(scn.find_child("FarewellCardOverlay", true, false) == null,
		"the queued check defers while the generator info tray is up")
	# The real gesture: pressing bare ground clears the selection WITH THE FINGER STILL DOWN, so the
	# resume cannot ride on _clear_selection — the check has to survive to the release.
	_board_touch(scn, empty, true)
	await process_frame
	await process_frame
	ok(scn._selected_cell.x < 0 and scn._pressing,
		"the press cleared the selection while the finger is still down")
	ok(scn.find_child("FarewellCardOverlay", true, false) == null,
		"the card stays away under a live finger even once the selection it waited on is gone")
	_board_touch(scn, empty, false)
	await process_frame
	await process_frame
	await process_frame
	var resumed := scn.find_child("FarewellCardOverlay", true, false) as Control
	ok(resumed != null and int(resumed.get_meta("farewell_line", 0)) == 2,
		"the deferred farewell card opens when the tap that cleared the selection ends")
	await drop(scn)

# A generator whose LINE no open quest asks for fades out (GEN_UNUSED). The predicate lives inline in
# _refresh_generator_dim (scene state: gen_nodes + quests), so — like the other board scene wiring —
# this is a source check: the fade constant, the asked-lines read, the accumulator exemption, and the
# quest-beat refresh (giver lights) must all be wired.
func _test_quest_unused_generator_fade() -> void:
	var board_src := FileAccess.get_file_as_string("res://engine/scripts/scenes/board.gd")
	ok(board_src.find("const GEN_UNUSED") != -1,
		"board defines the quest-unused generator fade shade")
	var dim_fn := board_src.substr(board_src.find("func _refresh_generator_dim"))
	dim_fn = dim_fn.substr(0, dim_fn.find("\nfunc "))
	ok(dim_fn.find("_open_quest_lines()") != -1 and dim_fn.find("GEN_UNUSED") != -1,
		"generator dim fades a generator whose line no open quest asks for")
	ok(dim_fn.find("is_accumulator") != -1,
		"accumulators (utility, never asked) are exempt from the quest fade")
	var lights_fn := board_src.substr(board_src.find("func _refresh_giver_lights"))
	lights_fn = lights_fn.substr(0, lights_fn.find("\nfunc "))
	ok(lights_fn.find("_refresh_generator_dim()") != -1,
		"the quest beat (giver lights) re-reads the generator fade")
	# …and the items' twin: base-line pieces of a quest-unused line grey out on the same beat,
	# with the collectibles (coins · special drops · treats) exempt.
	ok(board_src.find("const ITEM_UNUSED") != -1,
		"board defines the quest-unused item grey shade")
	var item_fn := board_src.substr(board_src.find("func _refresh_item_line_dim"))
	item_fn = item_fn.substr(0, item_fn.find("\nfunc "))
	ok(item_fn.find("_open_quest_lines()") != -1 and item_fn.find("ITEM_UNUSED") != -1,
		"item dim greys a piece whose line no open quest asks for")
	ok(item_fn.find("is_coin") != -1 and item_fn.find("SPECIAL_ITEMS") != -1 and item_fn.find("is_treat_line") != -1,
		"coins, special drops and treats are exempt from the quest grey")
	ok(lights_fn.find("_refresh_item_line_dim()") != -1,
		"the quest beat (giver lights) re-reads the item grey too")
	# the BAG mirrors the read: the board hands the NEEDED lines (asked + merged-recipe bases) to the
	# overlay, and a stored generator a live quest needs breathes in the generators row.
	ok(board_src.find("\"asked_lines\": G.quest_needed_lines(_open_quest_lines()).keys()") != -1,
		"the board hands the quest-NEEDED lines (merge recipes expanded) to the bag overlay")
	# every quest-driven read shares ONE expansion: an asked MERGED line keeps its two recipe base
	# lines lit too (winter berries = wild berries + snow: asking 5 needs {5, 2, 3}).
	var needed := G.quest_needed_lines([5])
	ok(needed.has(5) and needed.has(2) and needed.has(3) and needed.size() == 3,
		"quest_needed_lines expands a merged line into itself + its recipe base lines")
	ok(G.quest_needed_lines([1]) == {1: true},
		"a base line expands to just itself")
	ok(board_src.count("G.quest_needed_lines(_open_quest_lines())") >= 3,
		"generator fade, item grey and the bag hand-off all read the SAME needed-lines expansion")
	var bag_src := FileAccess.get_file_as_string("res://engine/scripts/ui/bag_overlay.gd")
	ok(bag_src.find("asked_lines.has(int(G.gen_def(G.GENERATORS, gid_str).get(\"line\", -1)))") != -1
		and bag_src.find("FX.breathe(gicon)") != -1,
		"a bagged generator whose line a live quest asks for breathes")
	# board parity: the dialogs' cell content spans the kit-fitted size (inset 0) so the shared
	# content_frac reads the same on the board, in the bag, and on the tier screens.
	for dlg_src_path in ["res://engine/scripts/ui/bag_overlay.gd", "res://engine/scripts/ui/ladder.gd", "res://engine/scripts/ui/almanac.gd"]:
		var dlg_src := FileAccess.get_file_as_string(dlg_src_path)
		ok(dlg_src.find(", 0.0)") != -1 and dlg_src.find("make_piece(") != -1,
			"%s builds its cell piece at inset 0 (shared content_frac parity)" % dlg_src_path.get_file())

func _test_swipe_commit_dir() -> void:
	# distance-ONLY, direction-returning (no velocity guesswork): 1000px viewport -> commit at >= 330px.
	# +1 = slid LEFT past the threshold (NEXT), -1 = slid RIGHT (PREV), 0 = spring back.
	ok(MapScript._swipe_commit_dir(-400.0, 1000.0) == 1, "sliding left past a third commits to the NEXT scene")
	ok(MapScript._swipe_commit_dir(400.0, 1000.0) == -1, "sliding right past a third commits to the PREVIOUS scene")
	ok(MapScript._swipe_commit_dir(-200.0, 1000.0) == 0, "a left slide under a third springs back")
	ok(MapScript._swipe_commit_dir(200.0, 1000.0) == 0, "a right slide under a third springs back")
	ok(MapScript._swipe_commit_dir(0.0, 1000.0) == 0, "no slide, no commit")

func _test_maps_gallery_featured_unlock_target() -> void:
	fresh("maps_featured_unlock_target")
	var g := Save.grove()
	g["last_map"] = String(G.MAPS[0].id)
	Save.grove_write()
	var map = MapScript.new()
	map.unlocks = {}
	ok(map._featured_map() == 0,
		"a fresh picture book features Fairy Hollow, which owns the next locked cluster")

	var progressed := {}
	for cluster in G.clusters(0):
		progressed[String((cluster as Dictionary).id)] = true
	map.unlocks = progressed
	ok(map._featured_map() == 1,
		"finishing Fairy Hollow advances the featured card to Snowy Village despite last_map")

	for z in G.coverup_pages():
		for cluster in G.clusters(int(z)):
			progressed[String((cluster as Dictionary).id)] = true
	map.unlocks = progressed
	ok(map._featured_map() == 4,
		"finishing every cluster leaves Cherry-Blossom Garden featured")
	map.free()

# The gallery GRID cards must read locked from the SAME cover-up sequence as the featured card,
# not from build progress: a page the player has finished (all clusters unlocked) reads OPEN even
# though it owns no built buildings; only pages beyond the frontier stay locked.
func _test_maps_gallery_grid_lock_state() -> void:
	fresh("maps_grid_lock_state")
	var map = MapScript.new()

	# a FRESH book: the first page is the unlock target; every later page stays locked.
	map.unlocks = {}
	ok(not map._grid_card_locked(0), "the fresh unlock target (Fairy Hollow) is not locked")
	ok(map._grid_card_locked(1), "a fresh book locks Snowy Village")
	ok(map._grid_card_locked(4), "a fresh book locks the final page")

	# finishing the first page's clusters unlocks it in the gallery and advances the frontier.
	var progressed := {}
	for cluster in G.clusters(0):
		progressed[String((cluster as Dictionary).id)] = true
	map.unlocks = progressed
	ok(not map._grid_card_locked(0), "a completed page reads UNLOCKED despite no built buildings")
	ok(not map._grid_card_locked(1), "the new frontier page (Snowy Village) is not locked")
	ok(map._grid_card_locked(2), "pages beyond the frontier stay locked")

	# finishing every cluster unlocks every page in the gallery.
	for z in G.coverup_pages():
		for cluster in G.clusters(int(z)):
			progressed[String((cluster as Dictionary).id)] = true
	map.unlocks = progressed
	for z in G.coverup_pages():
		ok(not map._grid_card_locked(int(z)), "a completed book unlocks every gallery card")
	map.free()

func _test_home_entry_uses_current_progress_page() -> void:
	fresh("home_progress_entry")
	var g := Save.grove()
	var progressed := {}
	for cluster in G.clusters(0):
		progressed[String((cluster as Dictionary).id)] = true
	g["unlocks"] = progressed
	g["last_map"] = String(G.MAPS[0].id)
	Save.grove_write()
	var map = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(map)
	ok(int(map._map_idx) == 1,
		"the board Home scene entry opens the current progress page, not the first page")
	ok(String(Save.grove().get("last_map", "")) == String(G.MAPS[1].id),
		"scene entry persists the progress page as last_map")
	map.queue_free()
	await process_frame

# Entering the home scene (the board's Home button swaps scenes here) must NOT fade the map art in.
# `content` holds ONLY the scenery — the sky fill, HUD and nav bar sit outside it — so a pop-in fade
# paints one bright, EMPTY sky-blue screen before the art arrives, which reads as a white flash off
# the warm board. The scene swap is the transition; the map is already the destination.
func _test_home_opens_without_a_fade() -> void:
	fresh("home_no_entry_fade")
	var map = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(map)     # runs _ready -> _open_map(start) -> _build_map
	ok(is_equal_approx(map.content.modulate.a, 1.0),
		"opening the home scene shows the map art at once (no fade from the bare sky)")
	ok(map.content.scale.is_equal_approx(Vector2.ONE),
		"opening the home scene does not pop the map art in from a smaller scale")
	await process_frame
	ok(is_equal_approx(map.content.modulate.a, 1.0), "the map art stays opaque on the next frame")
	# an IN-SCENE navigation (gallery card / picker -> a map) keeps its pop-in
	map._open_map(1)
	ok(map.content.modulate.a < 1.0, "an in-scene map navigation still pops in")
	map.queue_free()
	await process_frame

func _test_home_has_no_page_arrows() -> void:
	fresh("home_no_arrows")
	var map = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(map)
	await process_frame
	map._open_map(1)          # an open page with both neighbours
	await process_frame
	ok(map.content.find_child("PageArrowNext", true, false) == null, "the home page no longer shows a next-page arrow")
	ok(map.content.find_child("PageArrowPrev", true, false) == null, "the home page no longer shows a prev-page arrow")
	ok(map._track != null and is_instance_valid(map._track), "the home renders through a single sliding track")
	ok(map.content.get_child_count() == 1, "content holds exactly the track")
	map.queue_free()
	await process_frame

func _test_home_tap_unlocks_cluster() -> void:
	fresh("home_tap_unlocks")
	Save.earn_coins(1000)     # LEVEL_BASE_COINS=30 -> well past L2; wallet affords the first cluster
	var map = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(map)
	await process_frame
	map._open_map(0)          # fairy_hollow (coverup) — its first cluster is the ready one
	await process_frame
	var next_id := G.next_locked_cluster(0, map.unlocks)
	ok(next_id != "", "the home page has a next-in-order locked cluster")
	var badge: Control = map._page_badges.get(next_id, null)
	ok(badge != null, "the ready cluster's lock badge exists")
	if badge != null:
		_map_tap_at(map, _hit_center(badge))
		await create_timer(0.1).timeout
		ok(map.unlocks.has(next_id), "a still-tap on the home page unlocks the ready cluster (refactor kept taps working)")
	map.queue_free()
	await process_frame

func _test_home_prebuilds_window() -> void:
	fresh("home_window")
	var map = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(map)
	await process_frame
	map._open_map(2)          # a middle scene — both neighbours exist
	ok(map._pages.has(2), "the current scene is built immediately")
	_warm_window(map)         # drain the idle pre-build pump
	ok(map._pages.has(1) and map._pages.has(3), "both neighbours pre-build (the sliding window is {1,2,3})")
	ok(not map._pages.has(0) and not map._pages.has(4), "scenes two away are NOT built (window is only ±1)")
	# each scene is clipped to its own slot, so a cover-fill scene can't bleed into the next
	for z in map._pages.keys():
		ok(bool(map._pages[z].node.clip_contents), "scene %d is clipped to its slot (no overflow bleed)" % z)
	map.queue_free()
	await process_frame

func _test_home_swipe_commits_to_next_scene() -> void:
	fresh("home_swipe_commit")
	var map = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(map)
	await process_frame
	map._open_map(1)          # an open middle scene — has both neighbours
	_warm_window(map)         # neighbours ready BEFORE we swipe (no mid-drag build)
	var start := int(map._map_idx)
	var v: Vector2 = map.get_viewport_rect().size
	var cy := v.y * 0.5
	# slide LEFT ~0.6 of the width (well past a third) -> commit to the NEXT scene
	_swipe_touch(map, Vector2(v.x * 0.85, cy), true)
	_swipe_drag(map, Vector2(v.x * 0.55, cy), Vector2(-v.x * 0.30, 0), Vector2(-300, 0))
	_swipe_drag(map, Vector2(v.x * 0.25, cy), Vector2(-v.x * 0.30, 0), Vector2(-300, 0))
	_swipe_touch(map, Vector2(v.x * 0.25, cy), false)
	await create_timer(0.4).timeout
	ok(int(map._map_idx) == start + 1, "sliding left past the threshold commits to the next scene")
	ok(String(Save.grove().get("last_map", "")) == String(G.MAPS[start + 1].id), "the committed scene persists as last_map")
	ok(map._swipe.is_empty(), "the swipe state is cleared after committing")
	map.queue_free()
	await process_frame

func _test_home_swipe_commits_to_prev_scene() -> void:
	fresh("home_swipe_prev")
	var map = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(map)
	await process_frame
	map._open_map(2)
	_warm_window(map)
	var start := int(map._map_idx)
	var v: Vector2 = map.get_viewport_rect().size
	var cy := v.y * 0.5
	# slide RIGHT past a third -> commit to the PREVIOUS scene
	_swipe_touch(map, Vector2(v.x * 0.2, cy), true)
	_swipe_drag(map, Vector2(v.x * 0.5, cy), Vector2(v.x * 0.30, 0), Vector2(300, 0))
	_swipe_drag(map, Vector2(v.x * 0.8, cy), Vector2(v.x * 0.30, 0), Vector2(300, 0))
	_swipe_touch(map, Vector2(v.x * 0.8, cy), false)
	await create_timer(0.4).timeout
	ok(int(map._map_idx) == start - 1, "sliding right past the threshold commits to the previous scene")
	map.queue_free()
	await process_frame

func _test_home_short_swipe_springs_back() -> void:
	fresh("home_swipe_cancel")
	var map = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(map)
	await process_frame
	map._open_map(1)
	_warm_window(map)
	var start := int(map._map_idx)
	var v: Vector2 = map.get_viewport_rect().size
	var cy := v.y * 0.5
	var px := v.x * 0.6
	# 40px slide: past the 12px activation, well under a third of the width -> springs back
	_swipe_touch(map, Vector2(px, cy), true)
	_swipe_drag(map, Vector2(px - 40.0, cy), Vector2(-40, 0), Vector2(-80, 0))
	_swipe_touch(map, Vector2(px - 40.0, cy), false)
	await create_timer(0.4).timeout
	ok(int(map._map_idx) == start, "a short slide springs back to the same scene")
	ok(absf(map._track.position.x - map._track_rest_x()) < 0.5, "the track returns to rest after springing back")
	ok(map._swipe.is_empty(), "the swipe state is cleared after cancelling")
	map.queue_free()
	await process_frame

func _test_home_swipe_at_first_page_is_noop() -> void:
	fresh("home_swipe_edge")
	var map = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(map)
	await process_frame
	map._open_map(0)          # first scene — no previous
	_warm_window(map)
	var v: Vector2 = map.get_viewport_rect().size
	var cy := v.y * 0.5
	# slide RIGHT (toward the non-existent previous scene), far past the threshold
	_swipe_touch(map, Vector2(v.x * 0.2, cy), true)
	_swipe_drag(map, Vector2(v.x * 0.9, cy), Vector2(v.x * 0.7, 0), Vector2(900, 0))
	_swipe_touch(map, Vector2(v.x * 0.9, cy), false)
	await create_timer(0.4).timeout
	ok(int(map._map_idx) == 0, "sliding toward a non-existent previous scene on page 0 is a no-op")
	ok(not map._pages.has(-1), "no scene exists left of the first")
	map.queue_free()
	await process_frame

func _test_home_no_build_during_drag() -> void:
	fresh("home_no_mid_drag_build")
	var map = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(map)
	await process_frame
	map._open_map(2)
	_warm_window(map)                    # window {1,2,3} fully built up front
	var before: int = map._pages.size()
	var v: Vector2 = map.get_viewport_rect().size
	var cy := v.y * 0.5
	# a full drag must build NO scene — the ~100ms scene build was the source of the jank
	_swipe_touch(map, Vector2(v.x * 0.85, cy), true)
	_swipe_drag(map, Vector2(v.x * 0.55, cy), Vector2(-v.x * 0.30, 0), Vector2(-300, 0))
	_swipe_drag(map, Vector2(v.x * 0.30, cy), Vector2(-v.x * 0.25, 0), Vector2(-300, 0))
	ok(map._pages.size() == before, "dragging builds NO scene — the neighbours were already parked (smooth slide)")
	_swipe_touch(map, Vector2(v.x * 0.30, cy), false)
	await create_timer(0.4).timeout
	map.queue_free()
	await process_frame

# RESIZE-MID-COMMIT (2026-07-24): a commit tween carries the page change in its `finished` callback, but a
# viewport resize landing during the ~SWIPE_SNAP settle cancels the tween with kill() — which does NOT fire
# `finished`. The rebuild must still land on the DESTINATION page, not silently drop the commit back onto the
# source scene. Repro: start a committing left-swipe, fire the resize handler mid-settle, assert _map_idx advanced.
func _test_home_swipe_resize_mid_commit_finalizes() -> void:
	fresh("home_swipe_resize_commit")
	var map = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(map)
	await process_frame
	map._open_map(1)          # an open middle scene — has a next neighbour to commit to
	_warm_window(map)         # ensure the NEXT scene is pre-built so the commit has a target
	var start := int(map._map_idx)
	var v: Vector2 = map.get_viewport_rect().size
	var cy := v.y * 0.5
	# a committing left drag (past a third of the width), then release — the commit snap tween starts
	_swipe_touch(map, Vector2(v.x * 0.85, cy), true)
	_swipe_drag(map, Vector2(v.x * 0.55, cy), Vector2(-v.x * 0.30, 0), Vector2(-300, 0))
	_swipe_drag(map, Vector2(v.x * 0.25, cy), Vector2(-v.x * 0.30, 0), Vector2(-300, 0))
	_swipe_touch(map, Vector2(v.x * 0.25, cy), false)
	ok(map._swipe.get("settling", false), "setup: the commit snap tween is settling before the resize lands")
	# a viewport resize lands mid-settle: kill() cancels the tween WITHOUT firing its finished callback
	get_root().size = Vector2i(int(v.x) + 200, int(v.y))
	map._relayout_after_resize()
	await process_frame
	ok(int(map._map_idx) == start + 1, "a resize during the commit snap still lands on the destination scene (not the source)")
	ok(String(Save.grove().get("last_map", "")) == String(G.MAPS[start + 1].id), "the interrupted commit still persists the destination as last_map")
	ok(map._swipe.is_empty(), "the swipe state is cleared after the interrupted commit finalizes")
	map.queue_free()
	await process_frame

# ENDLESS FENCE (2026-07-23): the quest fence must stay FULL, full-opacity and interactive far past the
# old arc-finish threshold — the "endgame quiet" grey-out (fence_inert) is retired. This boots a real
# board at a deep-endgame coin clock and asserts every giver card renders un-greyed and the fence still
# actively wants items (glow + tap-to-deliver live). Guards the exact bug: the whole bar went grey once
# lifetime earnings crossed the 12-zone roster's end — long before the real map/cluster arc finishes.
func _test_endgame_fence_stays_live() -> void:
	fresh("endgame_fence")
	var g := Save.grove()
	g["coins_earned"] = G.arc_finish_threshold() * 5   # deep past the old inert threshold
	Save.grove_write()
	Save.mark_board_tutorial_seen()
	Save.mark_ftue_seen("merge")
	Save.mark_ftue_seen("gen_tap")
	ok(Save.coins_earned_lifetime() >= G.arc_finish_threshold(),
		"setup: earnings sit far past the old arc-finish (inert) threshold")
	var scn = board_host()
	await process_frame
	scn._refresh_giver_lights()
	ok(scn.giver_chips.size() >= 1, "the endgame fence still shows live giver cards (never empties)")
	var all_full := true
	var worst := ""
	for e in scn.giver_chips:
		var c: Control = e.chip
		if c.modulate.a < 0.99 or c.modulate.r < 0.99 or c.modulate.g < 0.99 or c.modulate.b < 0.99:
			all_full = false
			worst = str(c.modulate)
	ok(all_full, "every endgame giver card renders at full opacity — the fence is never greyed (got %s)" % worst)
	ok(scn._asked_codes().size() >= 1, "the endgame fence actively wants items (glow + tap-to-deliver stay live)")
	scn.queue_free()

# SAVE MIGRATION: an older save may hold generators/items/quests for lines the player should not have
# reached yet at their level. board._purge_above_level_content strips them on load. This boots a board at
# L15, INJECTS too-advanced content (koi, the last base line) alongside in-cadence content (the newest base
# line the player HAS reached, derived from the coin-clock cadence — G.zone_unlock_level, computed from
# level_at_coins over the cluster ladder — is an owner dial and moves on every re-tune, so picking the line
# by name here would re-break the test on every re-space), then reloads through the real _load_state path
# and asserts the too-advanced content is gone, the valid content stays, the parallel gen-bag arrays stay
# aligned, and a second pass is a no-op (idempotent).
func _test_purge_above_level_migration() -> void:
	fresh("purge_migration")
	Save.grove()["coins_earned"] = G.coins_at_level(15)   # player at L15: koi (L62) and desert fruits (L20) are
	                                                       # both future; woolens (zone 3, L12) is the newest reached
	Save.grove_write()
	Save.mark_board_tutorial_seen()
	ok(G.level() == 15, "setup: the player is at L15")
	# the newest BASE line already reached at L15 — the "in cadence, must survive" control
	var ok_line := 0
	for _bl in G.ZONE_BASE_LINES:
		if not G.line_gated_out(int(_bl), 15):
			ok_line = int(_bl)
	ok(ok_line > 0 and G.line_gated_out(18, 15), "setup: line %d is in cadence at L15; koi (18) is still future" % ok_line)
	var scn = board_host()
	await process_frame
	# use the always-open centre cells (MIN_LEVEL 0), cleared first, so injection doesn't depend on the deal
	var c_koi := Vector2i(3, 2)
	var c_desert := Vector2i(3, 4)
	var c_glow := Vector2i(5, 2)
	var c_gen := Vector2i(5, 4)
	for cell in [c_koi, c_desert, c_glow, c_gen]:
		scn.board.take(cell)
	scn.board.place(c_koi, 1801)             # koi t1 — GATED at L15 (zone 10, unlocks L62)
	scn.board.place(c_desert, ok_line * 100 + 1)   # the newest in-cadence base line at L15 — must SURVIVE
	scn.board.place(c_glow, 101)             # glow-mushrooms t1 — valid (anchor)
	scn.board.place_gen("gen_18", c_gen)     # koi generator — GATED
	scn.board.gen_bag = ["gen_18", G.gen_for_line(ok_line)]  # a gated koi + an in-cadence generator
	scn.board.gen_bag_boost = [0, 0]
	scn.bag = [1801, 101]                     # a gated koi item + a valid glow item stashed
	scn.quests = [{"line": 18, "tier": 1, "giver": 0}, {"line": 1, "tier": 1, "giver": 1}]  # koi quest (gated) + glow (valid)
	scn._persist()                            # write it all as an "old save"
	scn._load_state()                         # reload through the real migration path
	await process_frame
	var koi_on_board := false
	var desert_on_board := false
	for r in G.ROWS:
		for c in G.COLS:
			var code: int = scn.board.item_at(Vector2i(r, c))
			if code == 1801:
				koi_on_board = true
			if code == ok_line * 100 + 1:
				desert_on_board = true
	ok(not koi_on_board, "migration removes the too-advanced koi piece from the board")
	ok(desert_on_board, "migration keeps the in-cadence line-%d piece" % ok_line)
	ok(not scn.board.gens.values().has("gen_18"), "migration removes the too-advanced koi generator")
	ok(scn.board.gens.values().has("gen_1"), "migration keeps the anchor generator")
	ok(not scn.board.gen_bag.has("gen_18") and scn.board.gen_bag.has(G.gen_for_line(ok_line)), "migration prunes the gen_bag — drops koi, keeps the in-cadence generator")
	ok(scn.board.gen_bag.size() == scn.board.gen_bag_boost.size(), "the parallel gen_bag boost array stays aligned after the prune")
	ok(not scn.bag.has(1801) and scn.bag.has(101), "migration prunes the item bag — drops koi, keeps glow")
	var quest_lines: Array = []
	for q in scn.quests:
		quest_lines.append(int(q.get("line", -1)))
	ok(not quest_lines.has(18), "migration drops the too-advanced koi quest (the fence refills with valid lines)")
	ok(not scn._purge_above_level_content(), "the migration is idempotent — a second pass removes nothing")
	scn.queue_free()

# Bundle D: the combo screen-bloom overlay. The strength/target math is PURE (_bump_target /
# _advance / _visible_strength) so it tests without a frame loop; the scene wiring is a source check.
func _test_combo_bloom() -> void:
	# bump raises the target, scaled by the streak, never above COMBO_BLOOM_MAX.
	ok(approx(ComboBloom._bump_target(0.0, 0), 0.0), "bloom: a combo-0 bump adds nothing")
	ok(ComboBloom._bump_target(0.0, 3) > ComboBloom._bump_target(0.0, 1), "bloom: a longer streak raises the target more")
	ok(ComboBloom._bump_target(0.0, 99) <= Tune.COMBO_BLOOM_MAX + 0.0001, "bloom: the target is clamped to COMBO_BLOOM_MAX")
	ok(approx(ComboBloom._bump_target(Tune.COMBO_BLOOM_MAX, 5), Tune.COMBO_BLOOM_MAX), "bloom: already-maxed stays at the ceiling")
	# _advance eases strength TOWARD the target (rising) and never overshoots in one step.
	var s := ComboBloom._advance(0.0, Tune.COMBO_BLOOM_MAX, 0.016)
	ok(s > 0.0 and s < Tune.COMBO_BLOOM_MAX, "bloom: one ease step moves toward the target without overshooting")
	ok(ComboBloom._advance(0.2, 0.0, 0.016) < 0.2, "bloom: with target below, the live strength eases down")
	# target decays over time (no bumps) at ~COMBO_BLOOM_DECAY/sec — checked via the _process bleed math.
	ok(Tune.COMBO_BLOOM_DECAY > 0.0, "bloom: the target bleeds off when the streak lapses (decay > 0)")
	# scene wiring: both merge scenes own ONE bloom child (freed with the scene) and bump it after Feel.merge.
	var board_src := FileAccess.get_file_as_string("res://engine/scripts/scenes/board.gd")
	ok(board_src.find("ComboBloom") != -1, "board owns a ComboBloom overlay")
	ok(board_src.find("_combo_bloom.bump(combo,") != -1, "board bumps the bloom after the merge (gated + scaled by merge_fx)")
	var rush_src := FileAccess.get_file_as_string("res://engine/scripts/scenes/explore_rush.gd")
	ok(rush_src.find("ComboBloom") != -1, "rush owns a ComboBloom overlay")
	ok(rush_src.find("_combo_bloom.bump(_combo)") != -1, "rush bumps the bloom after the merge")

# Bundle D: the reactive ambient motes (Ambient.puff). Puff is a graceful
# no-op when there's no layer (Rush / weather off); the board reaches its WeatherLayer and puffs.
func _test_mote_puff() -> void:
	# the puff count is positive (motes fly) and never exceeds the base MOTE_PUFF_COUNT.
	ok(Ambient._puff_count() > 0, "puff: a merge flings at least one mote")
	ok(Ambient._puff_count() <= Tune.MOTE_PUFF_COUNT, "puff: the count never exceeds the MOTE_PUFF_COUNT base")
	# GRACEFUL no-op: a null layer must not error (Rush / weather off path).
	Ambient.puff(null, Vector2(10, 10))
	ok(true, "puff: a null ambient layer is a safe no-op (Rush / weather off)")
	# with a real layer + weather on, the puff adds a one-shot particle child that frees itself.
	var layer := Control.new()
	layer.size = Vector2(400, 400)
	get_root().add_child(layer)
	await create_timer(0.05).timeout
	var before := layer.get_child_count()
	Ambient.puff(layer, Vector2(200, 200))
	ok(layer.get_child_count() > before, "puff: a real ambient layer gains a one-shot mote burst")
	layer.queue_free()
	# scene wiring: the merge "world reaction" puff is no longer the giant Ambient.puff — it fires as the
	# merge_fx `world_puff` cue inside MergeFx.apply (a small grove-scale FX.burst). The board no longer
	# calls Ambient.puff for the merge reaction; merge_fx owns the cue + its size knob.
	var board_src := FileAccess.get_file_as_string("res://engine/scripts/scenes/board.gd")
	ok(board_src.find("Ambient.puff(") == -1, "board no longer fires the giant Ambient.puff on a merge")
	var merge_fx_src := FileAccess.get_file_as_string("res://engine/scripts/ui/merge_fx.gd")
	ok(merge_fx_src.find("world_puff") != -1, "merge_fx carries the world_puff cue (the small merge-reaction puff)")

func approx(a: float, b: float, eps := 0.0001) -> bool:
	return absf(a - b) <= eps

# a rows×cols grid of empty cells (the Rush tile grid: null or {kind,tier})
func _grid(rows: int, cols: int) -> Array:
	var g := []
	for _r in rows:
		var row := []
		for _c in cols:
			row.append(null)
		g.append(row)
	return g

func _button_text_with_prefix(node: Control, prefix: String) -> String:
	if node is Button and String((node as Button).text).begins_with(prefix):
		return String((node as Button).text)
	for b in node.find_children("", "Button", true, false):
		var text := String((b as Button).text)
		if text.begins_with(prefix):
			return text
	return "<missing>"

func _switch_for_label(node: Control, text: String) -> Button:
	for l in node.find_children("", "Label", true, false):
		if String((l as Label).text) != text:
			continue
		var p: Node = l
		while p != null and p != node:
			if p is PanelContainer:
				for b in (p as Control).find_children("", "Button", true, false):
					if (b as Button).has_meta("on"):
						return b as Button
			p = p.get_parent()
	return null

func _card_for_label(node: Control, text: String) -> PanelContainer:
	for l in node.find_children("", "Label", true, false):
		if String((l as Label).text) != text:
			continue
		var p: Node = l
		while p != null and p != node:
			if p is PanelContainer:
				return p as PanelContainer
			p = p.get_parent()
	return null

func _button_with_text(node: Control, text: String) -> Button:
	if node is Button and String((node as Button).text) == text:
		return node as Button
	for b in node.find_children("", "Button", true, false):
		if String((b as Button).text) == text:
			return b as Button
	return null

func _button_has_label(node: Button, text: String) -> bool:
	for l in node.find_children("*", "Label", true, false):
		if String((l as Label).text) == text:
			return true
	return false

func _home_chrome_button(node: Control, label: String) -> Button:
	var roots = node.get("_chrome_nodes")
	var buttons: Array = []
	if roots is Array:
		for root in roots:
			if not is_instance_valid(root):
				continue
			if root is Button:
				buttons.append(root)
			if root is Node:
				buttons.append_array((root as Node).find_children("*", "Button", true, false))
	else:
		buttons = node.find_children("*", "Button", true, false)
	for b in buttons:
		var btn := b as Button
		if not btn.is_visible_in_tree():
			continue
		if btn.tooltip_text == label or _button_has_label(btn, label):
			return btn
	return null

func _button_has_visible_text(btn: Button) -> bool:
	if String(btn.text).strip_edges() != "":
		return true
	for l in btn.find_children("*", "Label", true, false):
		var label := l as Label
		if label.get_parent() is PanelContainer and label.get_parent().get_parent() == btn:
			continue
		if label.is_visible_in_tree() and String(label.text).strip_edges() != "":
			return true
	return false

func _button_icon_node(btn: Button) -> Control:
	var wrap := btn.get_meta("icon_wrap", null) as Control
	if wrap == null:
		return null
	if wrap.get_child_count() == 0:
		return wrap
	return wrap.get_child(0) as Control

func _button_visible_icon_node(btn: Button) -> Control:
	var icon := _button_icon_node(btn)
	if icon == null:
		return null
	var item_art := icon.find_child("ItemArt", true, false)
	if item_art is Control:
		return item_art as Control
	return icon

func _button_icon_is_centered(btn: Button) -> bool:
	var icon := _button_icon_node(btn)
	if icon == null:
		return false
	var b := btn.get_global_rect().get_center()
	var c := icon.get_global_rect().get_center()
	return absf(b.x - c.x) <= 3.0 and absf(b.y - c.y) <= 3.0

## A CAPTIONED tile centres its icon horizontally only — the icon rides the upper half, above the
## label, so the vertical centres deliberately disagree. (Icon-only buttons use the both-axes check.)
func _button_icon_is_centered_x(btn: Button) -> bool:
	var icon := _button_icon_node(btn)
	if icon == null:
		return false
	return absf(btn.get_global_rect().get_center().x - icon.get_global_rect().get_center().x) <= 3.0

func _button_icon_is_large(btn: Button) -> bool:
	if not btn.has_meta("icon_px"):
		return false
	return float(btn.get_meta("icon_px")) >= btn.custom_minimum_size.x * 0.68

func _source_contains(path: String, needle: String) -> bool:
	return FileAccess.get_file_as_string(path).find(needle) != -1

func _push_tap(gpos: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = gpos
	down.global_position = gpos
	get_root().push_input(down, true)
	var up := down.duplicate()
	up.pressed = false
	get_root().push_input(up, true)

func _swipe_touch(map, gpos: Vector2, pressed: bool) -> void:
	var t := InputEventScreenTouch.new()
	t.pressed = pressed
	t.position = gpos
	map._on_input(t)

func _swipe_drag(map, gpos: Vector2, rel: Vector2, vel: Vector2) -> void:
	var d := InputEventScreenDrag.new()
	d.position = gpos
	d.relative = rel
	d.velocity = vel
	map._on_input(d)

# Force the pre-render pump to build the whole window NOW. Production spreads neighbour builds across
# idle frames (map._process, one per frame); tests need the window deterministic before swiping, so we
# drive _process directly. Safe once the queue is drained (early-returns).
func _warm_window(map) -> void:
	for i in 6:
		map._process(0.0)

func _test_map_card_expedition_chrome() -> void:
	fresh("map_card_expedition_chrome")
	var z := G.hub_map()
	var locked_g := Save.grove()
	locked_g["unlocks"] = {}
	locked_g["gates"] = []
	locked_g["last_map"] = String(G.MAPS[z].id)
	Save.grove_write()

	var locked = map_host()
	locked.unlocks = {}
	locked._open_map(z)
	await create_timer(0.05).timeout
	ok(_home_chrome_button(locked, "Expedition") == null, "locked/unpopulatable home maps hide Expedition from the side rail")
	ok(locked.content.find_child("MapHomeExpeditionButton", true, false) == null, "locked/unpopulatable home maps do not show Expedition")
	# The rail is gone: Settings is a gear in the TOP-right chrome, Daily a tile in the BOTTOM bar, so
	# they no longer stack. What still matters on a locked map is that both are reachable, and that they
	# sit at opposite ends of the screen rather than in one column.
	var settings := locked.get_node_or_null("SettingsGear") as Button
	var daily := locked.get_node_or_null("DailyTile") as Button
	ok(settings != null, "a locked map still exposes Settings")
	ok(daily != null, "a locked map still exposes Daily")
	if settings != null and daily != null:
		ok(settings.get_global_rect().end.y < daily.get_global_rect().position.y,
			"Settings rides the top chrome, well above the bottom bar's Daily tile")
	locked._open_select()
	await create_timer(0.05).timeout
	ok(locked.content.find_child("BucketExpeditionButton", true, false) == null, "the dock hides Expedition before the loop opens")
	locked.queue_free()

	var unl := {}
	for sp in G.MAPS[z].spots:
		unl[String(sp.id)] = true
	for c in G.clusters(z):               # fully unlock the scene → grants its habitat cell (bucket opens)
		unl[String((c as Dictionary).id)] = true
	var g := Save.grove()
	g["unlocks"] = unl
	g["gates"] = [z]
	g["last_map"] = String(G.MAPS[z].id)
	Save.grove_write()

	var hx = map_host()
	hx.unlocks = unl
	hx._open_map(z)
	await create_timer(0.05).timeout
	# Expedition has NO home entry any more (spec 2026-07-18): it moved into the Residents dialog, and
	# the side rail that carried it was replaced by the bottom bar.
	ok(_home_chrome_button(hx, "Expedition") == null, "home no longer carries an Expedition rail tile")

	# the BOTTOM BAR tiles: each is now the shared CODE-DRAWN action button — a CutPaperPanel rugged edge
	# (games/grove/ui_kit.gd action_button) with a centered glyph, over the shared drop
	# shadow — NOT a baked nav_<x>.png sprite. Keyed by spec name.
	var tiles := {"MapTile": "glyph_map", "ResidentsTile": "glyph_residents", "DailyTile": "glyph_daily",
		"BoardTile": "glyph_play"}
	# Vault is parked (`piggy_vault` flag OFF) — its tile stays off the bar.
	ok(hx.get_node_or_null("VaultTile") == null, "the parked Vault carries no bottom-bar tile")
	for tile_name in tiles:
		var btn := hx.get_node_or_null(NodePath(tile_name)) as Button
		ok(btn != null, "the bottom bar carries the %s" % tile_name)
		if btn == null:
			continue
		# the tile wears the code-drawn rugged edge (a CutPaperPanel), a centered glyph, and a drop shadow.
		ok(btn.find_child("ActionButtonDeckleSurface", true, false) != null,
			"%s wears the shared code-drawn rugged edge" % tile_name)
		var rects: Array = btn.find_children("*", "TextureRect", true, false)
		var wears_glyph := rects.any(func(tr: TextureRect) -> bool:
			return tr.texture != null and String(tr.texture.resource_path).findn(String(tiles[tile_name])) != -1)
		ok(wears_glyph, "%s composites its transparent glyph in the middle" % tile_name)
	# Settings left the bar for a small PAPER TILE pinned top-right, BELOW the wallet pills. Not a
	# destination in the row, but the same material as one — see map.gd _build_settings_gear and
	# engine/tests/hud_paper_tests.gd for the furniture language it shares with the tabs.
	ok(hx.get_node_or_null("SettingsTile") == null, "Settings is no longer a bottom-bar tile")
	var gear := hx.get_node_or_null("SettingsGear") as Button
	ok(gear != null, "Settings is a paper tile in the top-right chrome")
	ok(gear != null and not _button_has_visible_text(gear), "the gear carries no caption — icon only")
	var gear_face := gear.find_child("ActionButtonDeckleSurface", true, false) if gear != null else null
	ok(gear_face != null, "the gear tile wears the shared code-drawn cut-paper face")
	if gear_face != null:
		var want_face: Color = NavBarKit.chalk(Kit.PAPER_SURFACES["green"]["fill"])
		ok((gear_face.paper_color as Color).is_equal_approx(want_face),
			"…filled with the chalked green paper role (%s)" % (gear_face.paper_color as Color).to_html(false))
		ok(is_equal_approx(float(gear_face.deckle_amp), 0.0) and float(gear_face.halo_reach) > 4.0
			and float(gear_face.halo_offset.x) > 0.3,
			"…a smooth cut with the scene's directional shadow (halo %.1fpx, offset %.2f)"
			% [float(gear_face.halo_reach), float(gear_face.halo_offset.x)])
	var gear_glyph: Array = gear.find_children("*", "TextureRect", true, false) if gear != null else []
	ok(gear_glyph.any(func(tr: TextureRect) -> bool:
			return tr.texture != null and String(tr.texture.resource_path).findn("gear") != -1),
		"…with the cut-paper gear sprite composited on it")
	# …and the gear RESTS on that tile rather than being printed on it: the same generated dense pool the
	# nav tabs' glyphs wear, asked for at the gear's own much smaller box. Counted on the built button,
	# not on the constant that makes it — every copy but the topmost is a darkened one.
	var gear_copies: Array = gear_glyph.filter(func(tr: TextureRect) -> bool:
		return tr.texture != null and String(tr.texture.resource_path).findn("gear") != -1)
	ok(gear_copies.size() >= 5,
		"…standing on a stack of %d shadow copies under one clean one" % maxi(0, gear_copies.size() - 1))
	var gear_shadows: Array = gear_copies.filter(func(tr: TextureRect) -> bool:
		return tr.modulate.a < 0.95 or tr.modulate.v < 0.5)
	ok(gear_shadows.size() == gear_copies.size() - 1,
		"…all of them darkened but the top one (%d of %d)" % [gear_shadows.size(), gear_copies.size()])
	if gear_copies.size() >= 2:
		# the outermost copy stands PROUD of the artwork on every side — a pool, not a downward smear.
		var outer := gear_copies[0] as TextureRect
		ok(outer.offset_left < -1.5 and outer.offset_top < 0.0,
			"…the pool goes all the way round it (%.1fpx out, %.1fpx up)" % [-outer.offset_left, -outer.offset_top])
	# THE OWNER'S LAYOUT: the pills run to the right corner and the gear sits UNDER them, right-aligned
	# with the cluster on the same shared margin — not inline at the end of the wallet row.
	var wallet_row := hx._hud_panels[0] as Control if hx._hud_panels.size() > 0 else null
	if gear != null and wallet_row != null:
		var wr := wallet_row.get_global_rect()
		var gr := gear.get_global_rect()
		ok(gr.position.y >= wr.end.y,
			"the settings tile sits BELOW the wallet, not beside it (%.1f >= %.1f)" % [gr.position.y, wr.end.y])
		ok(absf(gr.end.x - wr.end.x) <= 2.0,
			"…right-aligned with the wallet on the same margin (%.1f vs %.1f)" % [gr.end.x, wr.end.x])
		var view_w: float = hx.get_viewport_rect().size.x
		ok(view_w - wr.end.x <= hx._hud_edge_margin_px() + 1.0,
			"the pill cluster still runs to the right corner (%.1fpx of margin)" % (view_w - wr.end.x))
	# Board is LAST, so it lands in the bottom-right corner
	var board := hx.get_node_or_null("BoardTile") as Button
	var prev_tile := hx.get_node_or_null("DailyTile") as Button
	ok(board != null and prev_tile != null and board.position.x > prev_tile.position.x,
		"Board is the right-most tile (the bottom-right corner)")
	# Board is the row's ACTIVE tab — deliberately a little bigger than its neighbours (NavBar.active_size),
	# but still a TILE in the row, not the old oversized disc: it stays well under 1.5 slots wide.
	ok(board != null and prev_tile != null and board.size.x > prev_tile.size.x and board.size.x < prev_tile.size.x * 1.5,
		"Board is the raised active tab — bigger than its neighbours, still a row tile (no oversized disc)")
	ok(gear != null and board != null and gear.get_global_rect().end.y < board.get_global_rect().position.y,
		"the gear sits well above the bottom bar, not in it")
	# the row fills the width: last tile's right edge sits within a margin of the screen edge
	if board != null:
		var view_w: float = hx.get_viewport_rect().size.x
		ok(board.position.x + board.size.x > view_w * 0.82,
			"the bottom row spans the full width (right edge at %.0f of %.0f)" % [board.position.x + board.size.x, view_w])
	ok(hx.content.find_child("MapHomeExpeditionButton", true, false) == null, "eligible home maps do not hide Expedition as a map-art overlay")
	ok(hx.content.find_child("MapCardExpeditionButton", true, false) == null, "map cards no longer carry a floating Expedition icon button")
	hx.queue_free()

# The home bottom row is a TAB BAR bled to the screen edge (mock: palette_a_meadow_sky_board.png): every
# tile's box ends ON the screen bottom (its paper runs off past it), the ACTIVE tab is raised above its
# neighbours, and every tile carries a DRAWN caption, not just a tooltip. Control geometry is float32, so
# every comparison here is is_equal_approx / a strict inequality — never ==.
func _test_bottom_bar_tab_geometry() -> void:
	fresh("bottom_bar_tabs")
	var hx = map_host()
	hx._open_map(G.hub_map())
	await create_timer(0.05).timeout
	# the row SITS on the safe-area inset (0 off-device) and bleeds its paper through it, so the BOX
	# bottom is the screen bottom less that inset.
	var view_h: float = hx.get_viewport_rect().size.y - Look.safe_bottom(hx)
	var names := ["MapTile", "ResidentsTile", "DailyTile", "BoardTile"]
	var tiles: Array = []
	for tile_name in names:
		var btn := hx.get_node_or_null(NodePath(tile_name)) as Button
		ok(btn != null, "the bottom bar carries the %s" % tile_name)
		if btn == null:
			continue
		tiles.append(btn)
		# the box BOTTOM lands on the screen bottom — no margin under the row at all
		ok(is_equal_approx(btn.position.y + btn.size.y, view_h),
			"%s reaches the screen bottom (%.1f of %.1f)" % [tile_name, btn.position.y + btn.size.y, view_h])
		# the caption is a real node with real text (Kit.action_button's white face label)
		var cap := btn.find_child("ActionButtonCaption", true, false) as Label
		ok(cap != null and cap.text != "", "%s draws a caption (%s)" % [tile_name, "" if cap == null else cap.text])
		# …and it fits inside the tile: the longest live caption ("Residents") must not clip or wrap
		if cap != null:
			var f: Font = Kit.bold_font()
			# the override key is `font_size` (Kit._kit_label) — asking for "font" misses it and falls back
			# to the THEME default (40 against the caption's real 32), so this assert used to measure a font
			# the row never draws and cleared the tile by 1.5px by luck.
			var fsz: int = cap.get_theme_font_size("font_size")
			ok(cap.get_line_count() == 1, "%s keeps its caption on one line" % tile_name)
			ok(f == null or f.get_string_size(cap.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x < btn.size.x,
				"%s caption fits the tile width" % tile_name)
	# the ACTIVE tab (Board) is the tallest thing in the row, and wears its cream rim
	var board := hx.get_node_or_null("BoardTile") as Button
	if board != null:
		for btn2 in tiles:
			if btn2 == board:
				continue
			ok(board.size.y > (btn2 as Button).size.y,
				"the active Board tab is taller than %s (%.1f > %.1f)" % [(btn2 as Button).name, board.size.y, (btn2 as Button).size.y])
			ok(not is_equal_approx(board.size.y, (btn2 as Button).size.y), "…measurably, not a rounding tie")
		ok(board.find_child("ActionButtonActiveRim", true, false) != null, "the active tab wears its cream rim")
		# it grows OUTWARD from its own slot without reflowing anyone: the neighbours keep an even pitch
		var daily := hx.get_node_or_null("DailyTile") as Button
		var residents := hx.get_node_or_null("ResidentsTile") as Button
		if daily != null and residents != null:
			ok(is_equal_approx(daily.position.x - residents.position.x, residents.position.x - (tiles[0] as Button).position.x),
				"the plain tiles keep an even pitch — the raised tab did not reflow the row")
	# a plain tile carries NO rim (the rim marks the one active destination)
	var plain := hx.get_node_or_null("DailyTile") as Button
	ok(plain == null or plain.find_child("ActionButtonActiveRim", true, false) == null,
		"a plain tab wears no rim")
	# MailTile joins the sweep when the inbox build carries it — the row must not collide with it either.
	_check_tab_paper(hx, names + ["MailTile"])
	hx.queue_free()

# The tab's PAPER (NavBar.tab_cp → the shared cut-paper knobs): a FLARED sheet — a trapezoid that reads
# wider at its visible bottom edge than at its top — carrying the all-sides ambient halo and the slab
# bevel. The geometry here is measured off the outline the CutPaperPanel actually draws, in GLOBAL space,
# so it covers the real thing rather than the knob values. Control geometry is float32 → is_equal_approx
# or a strict inequality, never ==.
## The darkening below which a cast shadow has stopped being a shadow and is just noise on the ground.
## The mock's own sky grain is ±0.016, so nothing under this is separable from the paper it falls on.
const VISIBLE_DARKENING := 0.02

## How far out from a tab's edge its halo is still VISIBLE on one side, in px. `halo_reach` is not that
## number and never was: it is the DILATION the ring stack spans, and `halo_offset` then hands one side
## more of it than the other (down-right, where the light throws it) — `dir` is +1 for that side and -1
## for the lit one. Bounding the reach alone let a symmetric halo pass a test written off a measurement
## of the mock's SHADOW side, which is exactly how this row shipped a left-hand shadow four times the
## mock's while its suite stayed green.
func _halo_visible_px(reach: float, falloff: float, alpha: float, offset: float, dir: float) -> float:
	for i in 400:
		var x := float(i) * 0.25
		if alpha * CutPaper.halo_profile(falloff, (x - dir * offset) / maxf(reach, 0.001)) < VISIBLE_DARKENING:
			return x
	return 999.0

func _check_tab_paper(hx: Node, names: Array) -> void:
	var spans: Array = []          # per tile: {min_x, max_x, top_w, bot_w} over the ON-SCREEN band
	for tile_name in names:
		var btn := hx.get_node_or_null(NodePath(tile_name)) as Button
		if btn == null:
			continue
		var panel := btn.find_child("ActionButtonDeckleSurface", true, false) as Control
		ok(panel != null, "%s carries its cut-paper sheet" % tile_name)
		if panel == null or panel.size.x <= 0.0:
			continue
		# every tab knob is ON for this row (and, by their defaults, off everywhere else — see below)
		ok(float(panel.get("flare")) > 0.0, "%s paper is flared (%.3f)" % [tile_name, panel.get("flare")])
		ok(float(panel.get("halo_reach")) > 0.0,
			"%s casts the all-sides halo (%.1f px)" % [tile_name, panel.get("halo_reach")])
		# …and that halo has a DIRECTION, because the mock's does. Measured on the rig that puts one of our
		# tabs and one of the mock's on the same flat sky at the same 162px width
		# (games/grove/tools/mock_compare_shot.gd + mock_profile.py), the mock's leftmost tab darkens the sky
		# beside it by 0.168 at 1px and nothing by 9px, while its rightmost darkens by 0.388 and still
		# reads 0.010 at 16px — and the info card above the row splits the same way. The light is upper
		# left. A symmetric halo is four times too heavy on one side at any reach that fits the other.
		var halo := float(panel.get("halo_reach"))
		var off: Vector2 = panel.get("halo_offset")
		var alpha := float(panel.get("halo_alpha"))
		var fall := float(panel.get("halo_falloff"))
		var casts_on_art := btn.find_child("ActionButtonActiveRim", true, false) == null
		ok(off.x > 0.0 and off.y > 0.0 and off.length() < halo,
			"%s halo is thrown down-right by the light (%.2f px inside a %.1f px reach)"
				% [tile_name, off.x, halo])
		# …and it is a CONTACT shadow on BOTH sides, not a smudge. Bounded on what is SEEN — the distance
		# at which each side dies — never on `halo_reach`, which is the dilation the rings span and is the
		# same number for a symmetric smudge and for this.
		var lit := _halo_visible_px(halo, fall, alpha, off.x, -1.0)
		var dark := _halo_visible_px(halo, fall, alpha, off.x, 1.0)
		ok(dark >= lit * 1.3,
			"%s throws further on the shadow side than the lit one (%.1f px vs %.1f)" % [tile_name, dark, lit])
		ok(lit <= panel.size.x * 0.075 and dark <= panel.size.x * 0.105,
			("…and both sides die like a contact shadow (lit %.3f W, shadow %.3f W; the mock's own are"
			+ " 0.037 and 0.080 W)") % [lit / panel.size.x, dark / panel.size.x])
		if casts_on_art:
			ok(lit >= panel.size.x * 0.03,
				"…while still lifting the sheet off the art on its lit side (%.1f px = %.3f W)"
					% [lit, lit / panel.size.x])
		# …and it DECAYS like one. A stack of evenly spaced copies at one alpha draws a straight LINE from
		# the contact edge to the fringe; a real cast shadow falls off exponentially (the mock's shadow
		# side runs 0.388 → 0.164 → 0.039 over 1 → 6 → 12 px, a ~4px constant). The linear ramp is what
		# carried twice the alpha through the middle of the run, so the FALLOFF — not just the reach — is
		# part of the fix.
		ok(fall > 0.0, "%s halo decays, it does not ramp linearly (falloff %.2f)" % [tile_name, fall])
		# by HALF the reach a linear ramp still holds half its alpha; the mock is down to about a third.
		var mid := CutPaper.halo_profile(fall, 0.5)
		ok(mid < 0.36, "…at half the reach it holds %.2f of the contact alpha (a linear ramp holds %.2f)"
			% [mid, CutPaper.halo_profile(0.0, 0.5)])
		# the lit cut edge is a HAIRLINE. It is the mock's 1px lit paper edge, not a slab: a band reaching
		# several px in reads as an inward gradient and the tab inflates into a button (measured on the
		# render: 0.045 W put a 9px ramp with a peak 43 luma deep inside the face; the mock's own tiles
		# change by ~8 luma on ONE pixel). Bounded in BOTH directions so neither a zero nor a re-grown
		# slab passes.
		var bevel := float(panel.get("bevel_px"))
		ok(bevel > 0.0 and bevel <= panel.size.x * 0.015,
			"%s wears a HAIRLINE lit cut edge (%.2f px ≤ %.2f)" % [tile_name, bevel, panel.size.x * 0.015])
		# SMOOTH corners: the row zeroes the shared torn deckle (it is the mock's clean rounded tab, and
		# the ONE knob apart — the same panel, same fill, same rim, same halo).
		ok(is_equal_approx(float(panel.get("deckle_amp")), 0.0),
			"%s draws a smooth edge, not the torn deckle (amp %.2f)" % [tile_name, panel.get("deckle_amp")])
		# …and a smooth edge has to be an ANTIALIASED one. draw_colored_polygon computes no coverage, so
		# with the tear gone the corner arc rasterized as a hard binary staircase (measured on the render:
		# 0.0 blended pixels per row across the arc, against the mock's 1.7). The feather restores the
		# coverage term; without it the row cannot read as a card, whose defining quality is a clean cut.
		var feather := float(panel.get("edge_feather"))
		ok(feather > 0.0 and feather <= 2.5,
			"%s antialiases its silhouette (%.2f px feather ≤ 2.5)" % [tile_name, feather])
		# THE BORDER marks the one active destination: only the ACTIVE tab is outlined. A plain tab's paper
		# edge just ends — no warm cut-edge rim at all.
		var is_active := btn.find_child("ActionButtonActiveRim", true, false) != null
		if is_active:
			ok(float(panel.get("rim_width")) > 0.0,
				"%s is the active tab and keeps its rim (%.1f px)" % [tile_name, panel.get("rim_width")])
			# …and that rim is WHITE. It is the one mark that says which destination you are on, and it has
			# to carry against the chalked GOLD tile inside it and the busy dark map art outside it at once.
			# The shared Pal.CREAM rim rendered at 1.65:1 against the art — and DARKER than its own tile, so
			# it read as the tile's shadow, not as a mark.
			var rim_sheet2 := btn.find_child("ActionButtonActiveRim", true, false) as Control
			var rim_w := -rim_sheet2.position.x        # the rim sheet is inset by its own thickness
			var rim_fill: Color = rim_sheet2.get("paper_color")
			ok(rim_fill.v >= 0.98 and rim_fill.s <= 0.02,
				"%s rim is white (v %.2f, s %.2f) — NavBar.ACTIVE_RIM_FILL" % [tile_name, rim_fill.v, rim_fill.s])
			ok(rim_fill.v > Color(Pal.CREAM).v and rim_fill.s < Color(Pal.CREAM).s,
				"…measurably brighter and cleaner than the shared cream it replaced")
			# the FACE gives up its long ambient halo on the active tab, because what sits behind the FACE is
			# this rim, not the art. At the shared reach (0.11 W ≈ 3× the rim) the halo painted the whole rim
			# into shadow and a white rim came back a mid grey. The RIM keeps the full reach outward, so the
			# halo the row casts on the map art is unchanged.
			ok(float(panel.get("halo_reach")) <= rim_w * 0.5,
				"%s face casts only a CONTACT shadow onto its own rim (%.1f px ≤ half the %.1f px rim)"
					% [tile_name, panel.get("halo_reach"), rim_w])
			var rim_halo := float(rim_sheet2.get("halo_reach"))
			# the rim's halo keeps the row's own LIGHT too — same offset-to-reach ratio, so the sheet the
			# player actually sees against the map art is lit from the same corner as its neighbours. The
			# face's clamp scales BOTH (Kit.action_button), which is why this compares the ratio and not
			# the raw px.
			var rim_off: Vector2 = rim_sheet2.get("halo_offset")
			ok(is_equal_approx(rim_off.x / maxf(rim_halo, 0.001), off.x / maxf(halo, 0.001)),
				"%s rim is lit from the same corner as the row (%.3f vs %.3f of its reach)"
					% [tile_name, rim_off.x / maxf(rim_halo, 0.001), off.x / maxf(halo, 0.001)])
			var rim_lit := _halo_visible_px(rim_halo, float(rim_sheet2.get("halo_falloff")),
				float(rim_sheet2.get("halo_alpha")), rim_off.x, -1.0)
			ok(rim_halo > float(panel.get("halo_reach")) * 2.0
				and rim_lit >= panel.size.x * 0.03 and rim_lit <= panel.size.x * 0.075,
				"…while the rim still casts the row's full — and equally tight — halo onto the art (%.1f px)"
					% [rim_halo])
		else:
			ok(is_equal_approx(float(panel.get("rim_width")), 0.0),
				"%s is an inactive tab and draws NO rim (%.1f px)" % [tile_name, panel.get("rim_width")])
		# CHALKED tint: the row lightens + desaturates whatever its paper role resolves to, into the mock's
		# pastel band (NavBar.chalk). Measured on the fill the panel actually carries, against the untouched
		# shared role fill — the role itself must NOT have moved (asserted below).
		var pc: Color = panel.get("paper_color")
		ok(pc.s <= NavBarKit.CHALK_SAT_MAX + 0.001 and pc.v >= 0.70 and pc.v <= NavBarKit.CHALK_VALUE_MAX + 0.001,
			"%s wears a chalked tint (s %.2f ≤ %.2f, v %.2f in 0.70..%.2f)"
				% [tile_name, pc.s, NavBarKit.CHALK_SAT_MAX, pc.v, NavBarKit.CHALK_VALUE_MAX])
		# THE GLYPH'S DROP SHADOW is the row's OWN stack (NavBar.GLYPH_SHADOW), far heavier than the shared
		# Kit.GLYPH_SHADOW. The shared one offsets its copies straight DOWN, so it has no lateral reach at
		# all — measured on the render, 0.03 darkening one pixel out of the icon's side, i.e. nothing — and
		# the icons read as stickers lying flat on the paper. Every layer here also GROWS, which is what puts
		# a pool all round the glyph; the mock's own icons darken their tile by ~0.40 one pixel out.
		var shadow_layers: Array = btn.find_children("*", "TextureRect", true, false).filter(
			func(tr: TextureRect) -> bool: return tr.modulate.a < 0.999)
		ok(shadow_layers.size() > Kit.GLYPH_SHADOW.size(),
			"%s glyph wears a deeper stack than the shared one every other action button keeps (%d vs %d)"
				% [tile_name, shadow_layers.size(), Kit.GLYPH_SHADOW.size()])
		var widest_grow := 0.0
		var grows: Array[float] = []
		for tr in shadow_layers:
			# `grow` is applied as a symmetric offset patch, so it is readable without a layout pass
			var g := -(tr as TextureRect).offset_left
			grows.append(g)
			widest_grow = maxf(widest_grow, g)
			ok((tr as TextureRect).offset_left < 0.0 and (tr as TextureRect).offset_right > 0.0,
				"%s shadow layer reaches OUT past the glyph, not only down (%.1f px each side)"
					% [tile_name, g])
		ok(widest_grow > panel.size.x * 0.04,
			"%s glyph shadow skirts a real distance out (%.1f px on a %.0f px tile)"
				% [tile_name, widest_grow, panel.size.x])
		# THE STACK IS DENSE. This is the whole reason it is generated rather than hand-authored: the copies
		# have to step ~1px at a time so they OVERLAP into one smooth pool. The hand-written five-layer table
		# the row shipped put its copies 1.5 · 3.3 · 5.4 · 7.6 · 10.4 px out — ~2px apart, each carrying an
		# alpha jump of 0.05-0.19 — and the accumulation read as five flat plateaus with hard rings between
		# them (measured on the render, stepping out of the Board glyph's left edge: the darkening went
		# 0.142 → 0.127 → 0.058, a plateau then a cliff). That is exactly what cut_paper.gd's own drop-shadow
		# comment warns about: "a sparse few-copy stack (3/7/11px) shows as discrete stepped bands on small
		# elements (a button), so keep the step ≈ 1px".
		grows.sort()
		var widest_step := 0.0
		for i in range(1, grows.size()):
			widest_step = maxf(widest_step, grows[i] - grows[i - 1])
		# The bound is a LITERAL 1.3px on purpose — writing it as `GLYPH_SHADOW_STEP_PX × 1.3` would move
		# with the very constant under test, and a stack respaced to 2.1px steps would sail through it.
		ok(widest_step > 0.0 and widest_step <= 1.3,
			"%s glyph shadow steps ~1px at a time (widest gap %.2f px over %d copies)"
				% [tile_name, widest_step, shadow_layers.size()])
		# …and the DARKNESS is carried by the accumulation, not by any one copy: densifying the stack has to
		# leave the envelope where it was, or the fix for the banding would quietly relight the row.
		var contact := 1.0 - _stack_transmittance(shadow_layers)
		var kit_contact := 1.0
		for layer in Kit.GLYPH_SHADOW:
			kit_contact *= 1.0 - float(layer["a"])
		kit_contact = 1.0 - kit_contact
		ok(contact >= 0.40 and contact > kit_contact,
			"%s glyph shadow accumulates a real contact pool (%.2f ≥ 0.40, shared %.2f)"
				% [tile_name, contact, kit_contact])
		# the drawn outline, tear and all — the sheet runs from the tile's top edge to BELOW the screen
		var pts: PackedVector2Array = panel.call("_deckle_polygon", panel.size, panel.corner)
		ok(pts.size() > 8, "%s draws a real sheet outline (%d points)" % [tile_name, pts.size()])
		if pts.size() <= 8:
			continue
		var vis_h := btn.size.y                       # the part of the sheet the player can see
		# the taper is measured on the sheet's STRAIGHT sides — a band inside the top corner arc (which
		# narrows the outline for its own reasons) against the visible bottom edge — then read back out to
		# the box's own top and bottom, which is where the metric table's percentage is defined.
		var y1: float = float(panel.get("corner")) + 5.0
		var y2 := vis_h - 3.0
		var hi_span := _span_x(pts, y1 - 3.0, y1 + 3.0)
		var lo_span := _span_x(pts, y2 - 3.0, y2 + 3.0)
		var on_screen := _span_x(pts, 0.0, vis_h)
		var org := btn.global_position.x + panel.position.x
		var w_hi := hi_span.y - hi_span.x
		var w_lo := lo_span.y - lo_span.x
		ok(w_lo > w_hi, "%s tapers: the sheet is wider low than high (%.1f > %.1f)" % [tile_name, w_lo, w_hi])
		ok(not is_equal_approx(w_lo, w_hi), "…measurably, not a rounding tie")
		# …by exactly the flare the metric table asks for, read off a fit of the whole straight-sided
		# stretch (two spot samples would just measure where the tear happened to wobble).
		var gain := _flare_gain(pts, panel.size.x * 0.5, float(panel.get("corner")) + 2.0, vis_h, vis_h)
		ok(absf(gain - EdgeTabKit.FLARE) < 0.01,
			"%s flares by ~%.1f%% across the visible box (asked %.1f%%)"
				% [tile_name, gain * 100.0, EdgeTabKit.FLARE * 100.0])
		# THE TOP READS AS A CARD, NOT A DOME. The straight run along the sheet's top edge — what is left
		# of the width once the two corner arcs and the flare's squeeze have taken their bites — measured
		# on the outline itself. The mock's own tiles run straight across ~63% of their width; ours must
		# land in the same band. (Before this pass, corner 0.19 W + a 7% flare left only 57%, and the top
		# read as a dome.) Both bites count, so the assert holds the compound effect, not one knob.
		var flat := _span_x(pts, -0.01, 0.01)
		var flat_frac := (flat.y - flat.x) / panel.size.x
		ok(flat_frac > 0.58 and flat_frac < 0.68,
			"%s runs straight across %.0f%% of its top (the mock: ~63%%)" % [tile_name, flat_frac * 100.0])
		# the TAP TARGET still covers every pixel of paper the player can see: the sheet only ever
		# narrows INSIDE the button's box, so the button rect contains it.
		ok(on_screen.x > -0.5 and on_screen.y < btn.size.x + 0.5,
			"%s stays inside its own hit area (paper %.1f..%.1f of 0..%.1f)"
				% [tile_name, on_screen.x, on_screen.y, btn.size.x])
		# THE WIDEST SHEET the tab puts on screen is not always its face: the ACTIVE tab draws its rim
		# OUTSIDE the fill, so the rim is what a neighbour would collide with. Measuring the face alone hid
		# a 0.7px miss between Mail and the Board tab's rim — the row was one rounding away from touching.
		var lo := org + on_screen.x
		var hi := org + on_screen.y
		var rim_sheet := btn.find_child("ActionButtonActiveRim", true, false) as Control
		if rim_sheet != null and rim_sheet.size.x > 0.0:
			var rorg := btn.global_position.x + rim_sheet.position.x
			var rpts: PackedVector2Array = rim_sheet.call("_deckle_polygon", rim_sheet.size, rim_sheet.corner)
			var rspan := _span_x(rpts, 0.0, btn.size.y - rim_sheet.position.y)
			lo = minf(lo, rorg + rspan.x)
			hi = maxf(hi, rorg + rspan.y)
			ok(rorg + rspan.x < org + on_screen.x and rorg + rspan.y > org + on_screen.y,
				"%s rim is drawn OUTSIDE its face on both sides" % tile_name)
		spans.append({"name": tile_name, "lo": lo, "hi": hi})
	# NEIGHBOURS DO NOT COLLIDE — compared at the WIDEST point (the bottom), which is what these global
	# extremes are, so a flared row can never touch however hard it flares. And they do not merely clear
	# each other: the row is laid out on the tiles' DRAWN sheets (NavBar.drawn_w), so the cut between every
	# pair is the SAME NavBar.gap_px — the raised tab's overhang and rim come out of the row's own width,
	# not out of its neighbour's gap.
	var view_w: float = hx.get_viewport_rect().size.x
	var want_gap := NavBarKit.gap_px(view_w)
	spans.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["lo"]) < float(b["lo"]))
	var cuts: Array = []
	for i in maxi(0, spans.size() - 1):
		var l: Dictionary = spans[i]
		var r: Dictionary = spans[i + 1]
		var cut := float(r["lo"]) - float(l["hi"])
		ok(cut > 0.0, "%s and %s keep a clear gap (%.2f px)" % [l["name"], r["name"], cut])
		cuts.append(cut)
	if not cuts.is_empty():
		var lo_cut: float = cuts.min()
		var hi_cut: float = cuts.max()
		# ONE RHYTHM: the raised tab's overhang and its rim come out of the row's own width, not out of its
		# neighbour's gap. On the old even-slot pitch the cut beside the Board tab measured 0.7px against
		# 13px everywhere else — the row was one rounding away from touching, and ANY tighter gap collided.
		ok(hi_cut - lo_cut < 0.6,
			"every pair of tabs is cut by the same %.2f px (spread %.2f)" % [lo_cut, hi_cut - lo_cut])
		# the visible cut at the screen bottom is the row's gap plus what the flare has not yet closed — so
		# the row's own gap is its floor…
		ok(lo_cut >= want_gap - 0.01,
			"…never tighter than NavBar.gap_px itself (%.2f ≥ %.2f)" % [lo_cut, want_gap])
		# …and TIGHTER than the row used to sit. Matching the mock's own ~0.011 W at the bottom edge would
		# overshoot it: ours also flares (the cut opens by another ~12px toward the top) and casts a halo
		# INTO the gap, neither of which the mock's flat tiles do.
		ok(hi_cut < view_w * 0.012,
			"…and tighter than the row used to sit (%.2f px, was ~%.2f)" % [hi_cut, view_w * 0.012])
	# …and the knobs that do all this are OFF by default, so NO other cut-paper surface changed: a plain
	# action button (the board wells, the workbench preview) draws the flat rounded sheet it always did.
	var plainb := Kit.action_button("map", Vector2(120, 120), Callable())
	var plain_panel := plainb.find_child("ActionButtonDeckleSurface", true, false) as Control
	ok(plain_panel != null and is_equal_approx(float(plain_panel.get("flare")), 0.0)
		and is_equal_approx(float(plain_panel.get("halo_reach")), 0.0)
		and is_equal_approx(float(plain_panel.get("bevel_px")), 0.0),
		"an ordinary action button keeps the flat sheet — flare/halo/bevel default off")
	ok(plain_panel != null and String(plain_panel.get("shape")) == "rect",
		"…and the plain rounded-rect base shape")
	# …and of the things the NAV ROW used to take away, exactly one is still there off the row: the warm
	# cut-edge rim. The SMOOTH EDGE is no longer the row's own — the whole UI wears it now, so an ordinary
	# action button is smooth and feathered too, and a shared default that zeroed the tear without asking
	# for the coverage band would ship a staircase on every surface in the game. Both halves, together.
	ok(plain_panel != null and is_equal_approx(float(plain_panel.get("deckle_amp")), 0.0),
		"…the shared edge is a SMOOTH cut off the nav row as well (%.2f)" % [1.0 if plain_panel == null else plain_panel.get("deckle_amp")])
	ok(plain_panel != null and float(plain_panel.get("edge_feather")) > 0.0,
		"…and it is antialiased there too, which a smooth arc has no tear left to fake (%.2f)"
			% [0.0 if plain_panel == null else plain_panel.get("edge_feather")])
	ok(plain_panel != null and float(plain_panel.get("rim_width")) > 0.0,
		"…while the shared warm cut-edge rim survives — the row drops that in its OWN patch (%.2f)"
			% [0.0 if plain_panel == null else plain_panel.get("rim_width")])
	# the GLYPH SHADOW is the row's own too. `glyph_shadow` defaults to the shared Kit.GLYPH_SHADOW, so the
	# board's Home/Bag wells and the workbench preview keep the three straight-down copies they always had —
	# no `grow` on any of them, which is what would have leaked a pool onto every action button in the game.
	var plain_shadows: Array = plainb.find_children("*", "TextureRect", true, false).filter(
		func(tr: TextureRect) -> bool: return tr.modulate.a < 0.999)
	ok(plain_shadows.size() == Kit.GLYPH_SHADOW.size(),
		"an ordinary action button keeps the shared %d-layer glyph shadow (found %d)"
			% [Kit.GLYPH_SHADOW.size(), plain_shadows.size()])
	var plain_grew := false
	var plain_alphas: Array = []
	for tr in plain_shadows:
		plain_alphas.append(snappedf((tr as TextureRect).modulate.a, 0.001))
		if not is_equal_approx((tr as TextureRect).offset_left, 0.0) or not is_equal_approx((tr as TextureRect).offset_right, 0.0):
			plain_grew = true
	ok(not plain_grew, "…drawn straight DOWN, not grown — `grow` is inert off the nav row")
	var want_alphas: Array = []
	for layer in Kit.GLYPH_SHADOW:
		want_alphas.append(snappedf(float(layer["a"]), 0.001))
	plain_alphas.sort()
	want_alphas.sort()
	ok(plain_alphas == want_alphas,
		"…at exactly the shared alphas %s (found %s)" % [str(want_alphas), str(plain_alphas)])
	# …and the ACTIVE rim's fill is the row's own too: an action button that asks for a rim without naming a
	# fill still gets the shared cream, so nothing but the nav row moved to white.
	var rimmed := Kit.action_button("map", Vector2(120, 120), Callable(), {"active": true, "rim_px": 6.0})
	var default_rim := rimmed.find_child("ActionButtonActiveRim", true, false) as Control
	ok(default_rim != null and is_equal_approx(Color(default_rim.get("paper_color")).v, Color(Pal.CREAM).v)
		and is_equal_approx(Color(default_rim.get("paper_color")).s, Color(Pal.CREAM).s),
		"…and `rim_fill` defaults to the shared cream off the row (%s)"
			% ["-" if default_rim == null else str(default_rim.get("paper_color"))])
	rimmed.queue_free()
	# the CHALK is the row's own too: the shared paper ROLES keep their fills, so no dialog, pill, board or
	# shop surface moves. Compare the untouched role fill against what the row would have chalked it to.
	var gold: Color = Kit.action_role_fill("play", {"play": "gold"})
	ok(is_equal_approx(gold.s, Color(Pal.GOLD).s) and is_equal_approx(gold.v, Color(Pal.GOLD).v),
		"the shared paper roles keep their fills — the chalk is applied at the nav call site only")
	ok(NavBarKit.chalk(gold).s < gold.s and NavBarKit.chalk(gold).v > gold.v,
		"…and the row's chalk really does lighten + desaturate it (s %.2f→%.2f, v %.2f→%.2f)"
			% [gold.s, NavBarKit.chalk(gold).s, gold.v, NavBarKit.chalk(gold).v])
	ok(is_equal_approx(NavBarKit.chalk(gold).h, gold.h),
		"…preserving the hue exactly (a chalking pass, not a re-hue)")
	plainb.queue_free()

## The flare the sheet's outline actually carries: a least-squares fit of its HALF-width against y over
## the straight-sided stretch [y_lo, y_hi], read out as the fractional width gain from the box's top edge
## to its visible bottom. Fitting every sample point averages the torn edge's wobble out, which spot
## samples cannot — the tear is ±deckle_amp on each side and swamps a two-point slope.
func _flare_gain(pts: PackedVector2Array, cx: float, y_lo: float, y_hi: float, vis_h: float) -> float:
	var n := 0.0
	var sy := 0.0
	var sh := 0.0
	var syy := 0.0
	var syh := 0.0
	for p in pts:
		if p.y < y_lo or p.y > y_hi:
			continue
		var h := absf(p.x - cx)
		n += 1.0
		sy += p.y
		sh += h
		syy += p.y * p.y
		syh += p.y * h
	var det := n * syy - sy * sy
	if n < 8.0 or absf(det) < 0.001:
		return 0.0
	var b := (n * syh - sy * sh) / det        # half-width gained per px of height
	var a := (sh - b * sy) / n                # half-width extrapolated back to the box's top edge
	return 0.0 if absf(a) < 0.001 else b * vis_h / a

## What a stack of same-coloured shadow copies LETS THROUGH: Π(1-a). Alpha-over of one colour composes
## the same whatever order the copies are drawn in, so this is the stack's accumulated darkness (1 - it)
## wherever every copy covers — i.e. right at the glyph's own edge.
func _stack_transmittance(layers: Array) -> float:
	var keep := 1.0
	for tr in layers:
		keep *= 1.0 - (tr as CanvasItem).modulate.a
	return keep

## min/max x of the outline points whose y falls in [y0, y1] — the sheet's width across one band.
func _span_x(pts: PackedVector2Array, y0: float, y1: float) -> Vector2:
	var lo := INF
	var hi := -INF
	for p in pts:
		if p.y >= y0 and p.y <= y1:
			lo = minf(lo, p.x)
			hi = maxf(hi, p.x)
	return Vector2(0.0, 0.0) if lo > hi else Vector2(lo, hi)

func _test_dock_collect_chip() -> void:
	fresh("dock_collect_chip")
	var z := G.hub_map()
	var map_id := String(G.MAPS[z].id)
	var unl := {}
	for sp in G.MAPS[z].spots:
		unl[String(sp.id)] = true
	for c in G.clusters(z):               # fully unlock the scene → grants its habitat cell (bucket opens)
		unl[String((c as Dictionary).id)] = true
	var g := Save.grove()
	g["unlocks"] = unl
	g["gates"] = [z]
	g["last_map"] = map_id
	Save.grove_write()

	Bucket.hand_add("coin", 1)
	Bucket.place(0)
	var st := Bucket.state()
	st["banks"] = {"coin": 1.25}
	Save.grove_write()

	var hx = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(hx)
	hx._login_shown_launch = true
	if hx.content == null:
		hx._ready()
	hx.unlocks = unl
	hx._open_select()
	await create_timer(0.05).timeout
	ok(hx.content.find_child("MapHabitatProgressBar", true, false) == null, "the per-card production bar is retired (bucket dock owns collect)")
	var chip := hx.content.find_child("BucketCollectChip", true, false) as Button
	ok(chip != null and not chip.disabled, "the dock Collect chip is live with matured production")
	ok(hx.content.find_child("BucketLineRow_coin", true, false) != null, "the dock shows the coin line's production row")
	var coins_before := Save.coins()
	if chip != null:
		chip.pressed.emit()
		await create_timer(0.05).timeout
	ok(Save.coins() == coins_before + 1, "pressing the chip collects the matured whole unit")
	# THE PLACE-PICKER'S BACK BUTTON is a code-drawn paper button wearing the shared material, not the
	# baked `nav/nav_back.png` sprite tile it used to be — baked art takes no knobs, so it could never
	# have been brought onto the material by tuning. Its arrow is the nav glyph family's own transparent
	# glyph, cut out of that sprite's source tile.
	var back_btn := hx.find_child("BackButton", true, false) as Button
	assert_paper_button(back_btn, "the place-picker Back button")
	hx.queue_free()

# --- loadout: coin cost + the Rush cfg the boosts resolve to ----------------------
func _test_loadout() -> void:
	fresh("explore_loadout")
	ok(Explore.loadout_cost({}) == 0, "an empty loadout costs nothing")
	ok(Explore.loadout_cost({"time": true, "drops": true}) == 120 + 100, "loadout cost sums the equipped boosts")

	# §1 an expedition has a DEFAULT MINIMUM cost (MIN_COST) — the acquisition coin sink — and boosts add on top.
	ok(Explore.start_cost({}) == Explore.MIN_COST, "an empty expedition still costs the default MIN_COST")
	ok(Explore.start_cost({"drops": true}) == Explore.MIN_COST + 100, "boosts add ON TOP of the base minimum")
	Save.spend(Save.coins())               # zero the wallet, then set a known balance
	Save.add_coins(300)
	ok(Explore.can_start({}), "can set off with the base minimum covered (300 ≥ 150)")
	ok(Explore.can_start({"drops": true}), "can set off when coins (300) cover base+boost (250)")
	ok(not Explore.can_start({"focus": true}), "cannot set off when base+boost (350) exceeds coins (300)")

	var base: Dictionary = Explore.rush_cfg({})
	ok(base.time == Explore.BASE_TIME, "no-boost run length is BASE_TIME")
	ok(base.spawn_mul == 1.0 and base.calm_mul == 1.0 and base.t2 == 0.0, "no-boost cfg is the neutral baseline")
	ok((base.lines as Array).size() == Explore.RUSH_LINES.size(), "all lines are in play without the focus boost")

	# the Rush pool draws from `seen` but ONLY lines still in the live model — a retired line lingering in
	# an old save (ember 61) is dropped; live base (1) + special (71) lines stay. Derived, not a list.
	ok(Explore.seen_lines({"101": true, "6101": true, "7101": true}) == [1, 71], \
		"seen_lines drops a retired line (61) from the Rush pool while keeping live lines")

	var full: Dictionary = Explore.rush_cfg({"time": true, "drops": true, "calm": true, "lucky": true, "focus": true})
	ok(full.time == Explore.BASE_TIME + 15.0, "the time boost adds 15s")
	ok(full.spawn_mul < 1.0, "the drops boost shortens the spawn interval")
	ok(full.calm_mul > 1.0, "the calm boost rarefies treefalls")
	ok(full.t2 > 0.0, "the lucky boost enables tier-2 drops")
	ok((full.lines as Array).size() == 2, "the focus boost restricts play to 2 lines")

# --- Rush lines: drawn from the lines the player has SEEN, 3 picked per run -------
func _test_rush_lines() -> void:
	# seen_lines derives distinct merge lines from the saved `seen` set (code = line*100 + tier).
	ok(Explore.seen_lines({}).is_empty(), "no seen items → no seen lines")
	ok(Explore.seen_lines({"101": true, "207": true, "201": true, "301": true}) == [1, 2, 3],
		"seen codes collapse to their sorted, deduped lines")
	ok(Explore.seen_lines({"7105": true}) == [71], "a seen treat line counts too (any line ever seen)")
	# A SPECIAL drop line (chest=10, water=12, acorn=13; only SPECIAL_TOP=3 tiers) must NOT seed a Rush:
	# Rush merges climb to MAX_TIER, so a short line would render its placeholder disc past tier 3.
	ok(Explore.seen_lines({"1001": true, "101": true}) == [1],
		"a special drop line (chest, 3 tiers) is dropped — it can't climb to the Rush's MAX_TIER")
	ok(Explore.seen_lines({"1301": true, "1201": true}).is_empty(),
		"acorn-drop + water specials are both dropped from the Rush pool")
	# every line the Rush DOES keep has art all the way to MAX_TIER (no placeholder disc mid-run)
	for ln in Explore.seen_lines({"101": true, "201": true, "301": true, "1001": true, "7105": true}):
		ok(G.is_valid_item_code(int(ln) * 100 + Explore.MAX_TIER),
			"kept Rush line %d is valid at MAX_TIER" % int(ln))

	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	# Empty pool falls back to RUSH_LINES so a brand-new player still gets a board.
	ok(Explore.pick_rush_lines([], 3, rng) == Explore.RUSH_LINES, "an empty seen pool falls back to RUSH_LINES")
	ok(Explore.pick_rush_lines([5], 3, rng) == [5], "a pool smaller than the pick count plays in full")
	var picked: Array = Explore.pick_rush_lines([1, 2, 3, 4, 5], 3, rng)
	ok(picked.size() == 3, "three lines are picked from a larger pool")
	var distinct := {}
	var all_in_pool := true
	for ln in picked:
		distinct[ln] = true
		if not [1, 2, 3, 4, 5].has(ln):
			all_in_pool = false
	ok(distinct.size() == 3 and all_in_pool, "the picked lines are distinct and all come from the pool")

	# rush_cfg threads the seen set through: 3 lines normally, 2 with the focus boost.
	var seen5 := {"101": true, "201": true, "301": true, "401": true, "501": true}
	var cfg: Dictionary = Explore.rush_cfg({}, seen5, rng)
	ok((cfg.lines as Array).size() == 3, "rush_cfg draws 3 lines from the seen pool")
	var focus_cfg: Dictionary = Explore.rush_cfg({"focus": true}, seen5, rng)
	ok((focus_cfg.lines as Array).size() == 2, "the focus boost narrows the seen draw to 2 lines")

	# End-to-end: a seen set polluted with SHORT special drops (chest=10, acorn=13) must still yield a
	# pool where EVERY line renders cleanly up to MAX_TIER — a spawn/merge/reroll can never hit a
	# placeholder disc. (This is the real config explore_rush.gd consumes.)
	var seen_specials := {"101": true, "201": true, "301": true, "1001": true, "1301": true}
	var all_deep := true
	for _i in 12:                                    # sample many random draws — none may include a short line
		var scfg: Dictionary = Explore.rush_cfg({}, seen_specials, rng)
		for ln in scfg.lines:
			if not G.is_valid_item_code(int(ln) * 100 + Explore.MAX_TIER):
				all_deep = false
	ok(all_deep, "rush_cfg never puts a short special line (chest/acorn) into the play pool")

# --- Rush scoring: non-linear value, combo, multiplier, spawn cadence -------------
func _test_scoring() -> void:
	ok(Explore.merge_base(1) == 10, "a t1 merge is worth 10 base")
	ok(Explore.merge_base(2) == 20 and Explore.merge_base(3) == 40, "base value doubles per tier (non-linear)")
	ok(Explore.merge_points(3, 2.0) == Explore.merge_base(3) * 2, "points scale by the live multiplier")

	ok(Explore.combo_after(2, 0.5) == 3, "a merge within the window climbs the combo")
	ok(Explore.combo_after(5, 2.0) == 1, "a merge after the window restarts the combo at 1")

	ok(absf(Explore.mult_after_merge(1.0, 1) - 1.12) < 0.001, "each merge nudges the multiplier up")
	ok(Explore.mult_after_merge(1.0, 4) > Explore.mult_after_merge(1.0, 1), "building a high tier bumps it more")
	ok(Explore.mult_after_merge(Explore.MULT_CAP, 4) == Explore.MULT_CAP, "the multiplier is capped at MULT_CAP")
	ok(Explore.mult_decay(2.0, 0.1, 0.0) == 2.0, "the multiplier holds steady inside the post-merge grace window")
	ok(Explore.mult_decay(2.0, 0.1, Explore.MULT_GRACE + 0.5) < 2.0, "the multiplier bleeds once the grace window passes")
	ok(absf(Explore.mult_decay(2.0, 1.0, 5.0) - (2.0 - Explore.MULT_DECAY)) < 0.001, "past the grace window it bleeds at MULT_DECAY per second")
	ok(Explore.mult_decay(1.0, 5.0, 9.0) == 1.0, "the multiplier never decays below 1")
	ok(Explore.clean_dodge_mult(1.0) > 1.0, "a clean dodge bumps the multiplier")

	ok(Explore.spawn_interval(0.0, 1.0) > Explore.spawn_interval(1.0, 1.0), "drops accelerate as the run progresses")
	ok(Explore.spawn_interval(0.0, 0.72) < Explore.spawn_interval(0.0, 1.0), "the drops boost shortens the interval")

# --- grid helpers: match, gravity, fill, fling, timber, full ---------------------
func _test_grid() -> void:
	var g := _grid(3, 3)
	g[2][0] = {"kind": "leaf", "tier": 1}
	g[2][1] = {"kind": "leaf", "tier": 1}
	ok(Explore.neighbor_match(g, 2, 0) == Vector2i(2, 1), "neighbor_match finds an adjacent same kind+tier")
	g[2][1] = {"kind": "petal", "tier": 1}
	ok(Explore.neighbor_match(g, 2, 0) == Vector2i(-1, -1), "no match when the neighbour's kind differs")
	g[2][1] = {"kind": "leaf", "tier": 2}
	ok(Explore.neighbor_match(g, 2, 0) == Vector2i(-1, -1), "no match when the neighbour's tier differs")
	# the Rush uses INTEGER line indices as kinds (RUSH_LINES = [1,2,3]); neighbor_match must handle them
	# (str(), not String() — String(int) has no constructor and crashed every tap-merge in the Rush)
	var gi := _grid(3, 3)
	gi[2][0] = {"kind": 1, "tier": 1}
	gi[2][1] = {"kind": 1, "tier": 1}
	ok(Explore.neighbor_match(gi, 2, 0) == Vector2i(2, 1), "neighbor_match matches integer (line-index) kinds")
	gi[2][1] = {"kind": 2, "tier": 1}
	ok(Explore.neighbor_match(gi, 2, 0) == Vector2i(-1, -1), "no match when integer kinds differ")

	var g2 := _grid(3, 3)
	g2[0][1] = {"kind": "leaf", "tier": 1}
	Explore.gravity(g2)
	ok(g2[2][1] != null and g2[0][1] == null, "gravity drops a floating tile to the bottom")
	ok(Explore.column_fill(g2, 1) == 1, "column_fill counts a column's tiles")

	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var g3 := _grid(2, 3)
	g3[1][0] = {"kind": "leaf", "tier": 1}
	ok(Explore.fling_target(g3, 0, 1, rng) == 2, "fling_target avoids the source and the danger column")

	var g4 := _grid(3, 2)
	g4[2][0] = {"kind": "leaf", "tier": 1}
	g4[1][0] = {"kind": "leaf", "tier": 2}
	ok(Explore.timber_hits(g4, 0) == 2 and Explore.timber_hits(g4, 1) == 0, "timber_hits counts a column (0 = a clean dodge)")

	var g5 := _grid(1, 2)
	ok(not Explore.board_full(g5), "a board with an empty cell is not full")
	g5[0][0] = {"kind": "leaf", "tier": 1}
	g5[0][1] = {"kind": "leaf", "tier": 1}
	ok(Explore.board_full(g5), "board_full is true when every cell is occupied")

# --- FTUE hand-hint eligibility (the pure seam behind explore_rush.gd's teaches) --
func _test_hand_hint_logic() -> void:
	# first_mergeable: finds the first row-major mergeable cell
	var g := _grid(3, 3)
	g[2][0] = {"kind": 1, "tier": 1}
	g[2][1] = {"kind": 1, "tier": 1}
	ok(Explore.first_mergeable(g) == Vector2i(2, 0), "first_mergeable returns the first cell of a mergeable pair")
	# no pair -> (-1,-1)
	g[2][1] = {"kind": 2, "tier": 1}
	ok(Explore.first_mergeable(g) == Vector2i(-1, -1), "first_mergeable is (-1,-1) with no mergeable pair")
	# MAX_TIER cells cannot merge, so a maxed matching pair is not mergeable
	var gm := _grid(3, 3)
	gm[2][0] = {"kind": 1, "tier": Explore.MAX_TIER}
	gm[2][1] = {"kind": 1, "tier": Explore.MAX_TIER}
	ok(Explore.first_mergeable(gm) == Vector2i(-1, -1), "first_mergeable skips a MAX_TIER pair (cannot merge)")

	# bottom_filled: lowest filled row in the column, -1 when empty
	var gb := _grid(3, 2)
	gb[1][0] = {"kind": 1, "tier": 1}
	gb[2][0] = {"kind": 1, "tier": 1}
	ok(Explore.bottom_filled(gb, 0) == 2, "bottom_filled returns the lowest filled row")
	ok(Explore.bottom_filled(gb, 1) == -1, "bottom_filled is -1 for an empty column")

	# rush_hint_id ordering
	ok(Explore.rush_hint_id(false, false, true, true, true) == "rush_treefall",
		"treefall wins during a telegraph, even with an unseen merge and a live pair")
	ok(Explore.rush_hint_id(false, false, false, true, false) == "rush_merge",
		"merge shows when no telegraph is active")
	ok(Explore.rush_hint_id(false, false, true, true, false) == "rush_merge",
		"a telegraph with no doomed tile falls through to the merge teach")
	ok(Explore.rush_hint_id(false, true, true, true, true) == "rush_merge",
		"a seen treefall during a telegraph falls through to the merge teach")
	ok(Explore.rush_hint_id(true, false, false, true, false) == "",
		"nothing when merge is seen and no telegraph")
	ok(Explore.rush_hint_id(false, false, false, false, false) == "",
		"nothing when there is no mergeable pair and no telegraph")

# --- the box seam: unlocked pool + roll ------------------------------------------
func _test_pool_and_box() -> void:
	fresh("explore_pool")
	ok(Explore.unlocked_pool({}, []).is_empty(), "the box pool is empty with no completed map")

	var z := 0
	var unl := {}
	for sp in G.MAPS[z].spots:
		unl[String(sp.id)] = true
	ok(G.can_populate(z, unl, [z]), "map 0 complete (the pool precondition)")
	var pool: Array = Explore.unlocked_pool(unl, [z])
	ok(not pool.is_empty(), "a completed map fills the box pool")
	var want := {}
	for ln in G.resident_lines(z):
		want[String(ln.id)] = true
	var all_in := true
	for k in pool:
		if not want.has(k):
			all_in = false
	ok(all_in and pool.size() == want.size(), "the pool is exactly the completed map's offered kinds")

	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	ok(pool.has(Explore.roll_kind(pool, rng)), "roll_kind returns a kind from the pool")
	ok(Explore.roll_kind([], rng) == "", "rolling an empty pool yields the empty string")

# --- run state: carried across the three scenes, score spent on boxes ------------
func _test_run_state() -> void:
	Explore.begin_run({"drops": true}, "farmhouse")
	ok(Explore.score() == 0, "a fresh run starts at score 0")
	ok(bool(Explore.run().equip.get("drops", false)), "the run carries the chosen loadout")
	ok(Explore.source_map_id() == "farmhouse", "the run carries the source map id")
	Explore.add_score(250)
	ok(Explore.score() == 250, "add_score accrues the run score")
	Explore.begin_run({})
	ok(Explore.source_map_id() == "", "legacy begin_run callers keep an empty source map")

func _test_trade_count() -> void:
	ok(Explore.trade_count(0) == 0, "no score yields no spirits")
	ok(Explore.trade_count(150) == 1, "a sub-rate score still yields one spirit (min 1)")
	ok(Explore.trade_count(Explore.TRADE_RATE - 1) == 1, "just under the rate yields one spirit")
	ok(Explore.trade_count(Explore.TRADE_RATE) == 1, "exactly the rate yields one spirit")
	ok(Explore.trade_count(Explore.TRADE_RATE * 2) == 2, "double the rate yields two spirits")
	ok(Explore.trade_count(Explore.TRADE_RATE * 3 + 50) == 3, "a great run yields three spirits (remainder discarded)")
	ok(Explore.trade_count(Explore.TRADE_RATE * 20) == Explore.TRADE_MAX, "a runaway score is capped at TRADE_MAX spirits")

func _test_slot_reel() -> void:
	var SlotReel: GDScript = load("res://engine/scripts/ui/slot_reel.gd")
	var mk := func(_sym, w: float, h: float) -> Control:
		var c := Control.new()
		c.custom_minimum_size = Vector2(w, h)
		return c
	# a built reel sits landed on its target tile
	var reel: Control = SlotReel.build_reel(["a", "b", "c"], "c", 80.0, 84.0, 0, mk)
	var tile_h: float = float(reel.get_meta("tile_h"))
	var n_syms: int = int(reel.get_meta("n_syms"))
	var band: Control = reel.get_meta("band")
	ok(is_equal_approx(band.position.y, -tile_h * float(n_syms - 1)), "a built reel is landed on its target tile")
	# spinning zero reels lands immediately
	var fired := {"v": false}
	SlotReel.spin_reels(self, [], null, func() -> void: fired.v = true)
	ok(fired.v, "spinning zero reels fires on_all_landed at once")
	# finish() snaps every band to its landed tile and fires on_all_landed exactly once
	var host := Control.new()
	get_root().add_child(host)
	var r0: Control = SlotReel.build_reel(["a", "b"], "b", 80.0, 84.0, 0, mk)
	var r1: Control = SlotReel.build_reel(["a", "b"], "a", 80.0, 84.0, 1, mk)
	host.add_child(r0)
	host.add_child(r1)
	(r0.get_meta("band") as Control).position.y = 0.0
	(r1.get_meta("band") as Control).position.y = 0.0
	var done := {"n": 0}
	var handle: Dictionary = SlotReel.spin_reels(host, [r0, r1], null, func() -> void: done.n += 1)
	(handle["finish"] as Callable).call()
	var b0: Control = r0.get_meta("band")
	ok(is_equal_approx(b0.position.y, -float(r0.get_meta("tile_h")) * float(int(r0.get_meta("n_syms")) - 1)), "finish() snaps a reel to its landed tile")
	ok(done.n == 1, "finish() fires on_all_landed exactly once")
	host.queue_free()

func _test_residents_dialog_uses_shared_frame() -> void:
	fresh("residents_shared_frame")
	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_root().add_child(host)
	ResidentsUI.open(host)
	await process_frame
	await process_frame
	var overlay := host.find_child("ResidentsOverlay", true, false) as Control
	var panel := overlay.find_child("MeadowDialogPanel", true, false) as PanelContainer if overlay != null else null
	var panel_style := panel.get_theme_stylebox("panel") if panel != null else null
	ok(panel != null, "resident dialog mounts inside the shared dialog frame")
	ok(not (panel_style is StyleBoxTexture),
		"resident dialog does not override the shared frame with its baked dialog_bg")
	var inspector := overlay.find_child("ResidentsInspector", true, false) as Control if overlay != null else null
	var deckle := inspector.find_child("ResidentsInspectorDeckleSurface", true, false) as Control \
		if inspector != null else null
	var deckle_script := deckle.get_script() as Script if deckle != null else null
	ok(deckle_script != null and String(deckle_script.resource_path).ends_with("/cut_paper.gd"),
		"resident inspector uses the shared code-drawn cut-paper surface")
	var footer_band := overlay.find_child("DialogFooterBand", true, false) as PanelContainer \
		if overlay != null else null
	var footer_style := footer_band.get_theme_stylebox("panel") as StyleBoxFlat \
		if footer_band != null else null
	ok(footer_style != null and footer_style.bg_color.a <= 0.01,
		"resident pinned footer does not draw a white/cream background band")
	var uses_strip_asset := false
	if inspector != null:
		for node in inspector.find_children("*", "TextureRect", true, false):
			var tex := (node as TextureRect).texture
			if tex != null and String(tex.resource_path).ends_with("/strip_bg.png"):
				uses_strip_asset = true
	ok(not uses_strip_asset, "resident inspector no longer renders the baked strip background")
	host.queue_free()
	await process_frame

# --- the Rush screen + the reward overlay: build smoke + the score→hand seam ------
func _test_screens() -> void:
	fresh("explore_screens")
	# (Load out is now an overlay dialog on the map — map.gd::_open_expedition — not a scene.)
	for path in ["res://engine/scenes/ExploreRush.tscn"]:
		var s = mount(path, rush_unready)
		ok(s.get_child_count() > 0, "%s builds a non-empty tree" % String(path).get_file())
		s.queue_free()

	# regression (2026-07-23): a seen set polluted with a SHORT special drop (chest=10, 3 tiers) must not
	# leak it into the live scene's play pool — every _cfg line has to render up to MAX_TIER, or a merge
	# would show PieceView's placeholder disc (the "no icon" tile the owner reported).
	fresh("explore_short_line_pool")
	var sg := Save.grove()
	sg["seen"] = {"101": true, "201": true, "301": true, "1001": true, "1301": true}   # 3 base lines + chest + acorn-drop
	Save.grove_write()
	Explore.begin_run({})
	var rs = rush_host()
	var clean := true
	for ln in rs._cfg.lines:
		if not G.is_valid_item_code(int(ln) * 100 + Explore.MAX_TIER):
			clean = false
	ok(clean and not (rs._cfg.lines as Array).has(10) and not (rs._cfg.lines as Array).has(13),
		"the live Rush scene's play pool excludes short special lines (no placeholder tile)")
	rs.queue_free()

	# the seam: opening the reward OVERLAY converts the run score DIRECTLY into hand spirits
	fresh("explore_reward_seam")
	var z := 0
	var g := Save.grove()
	var unl := {}
	for sp in G.MAPS[z].spots:
		unl[String(sp.id)] = true
	g["unlocks"] = unl
	g["gates"] = [z]
	Save.grove_write()
	Explore.begin_run({}, String(G.MAPS[z].id))
	Explore.add_score(Explore.TRADE_RATE * 2)       # two rates → 2 spirits
	var pool: Array = Explore.unlocked_pool(unl, [z])
	var hand_before := Bucket.hand().size()
	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_root().add_child(host)
	ExploreReward.open(host, {"on_done": func() -> void: pass})
	ok(Explore.source_map_id() == String(G.MAPS[z].id), "reward overlay keeps the source map on the run")
	ok(Bucket.hand().size() == hand_before + 2, "opening the reward overlay grants floor(score / RATE) spirits to the hand")
	var last: Dictionary = Bucket.hand()[Bucket.hand().size() - 1]
	ok(String(last.line) in Bucket.LINES, "a granted spirit lands on one of the four bucket lines")
	ok(int(last.tier) >= 1 and int(last.tier) <= 4, "a granted spirit rolls a generator tier (1–4)")
	ok(host.find_child("ExploreRewardOverlay", true, false) != null, "the reward mounts as a modal overlay (not a separate scene)")
	ok(host.find_child("RewardDialog", true, false) != null, "the reward uses the shared framed dialog")
	var grid := host.find_child("RewardReels", true, false)
	ok(grid != null and grid.get_child_count() == 2, "the reveal builds one reel per granted spirit")
	var piglet_icon: Control = ExploreReward._spirit_icon("piglet", 72.0)
	ok(piglet_icon.find_child("SpiritEye0", true, false) != null and piglet_icon.find_child("SpiritEye1", true, false) != null,
		"an unarted spirit reveal shows placeholder face details instead of a blank disc")
	host.queue_free()

func _uses_cut_paper(n: Node) -> bool:
	if n == null:
		return false
	var script: Script = n.get_script() as Script
	return script != null and String(script.resource_path).ends_with("engine/scripts/ui/cut_paper.gd")

func _test_rush_board_skin() -> void:
	fresh("rush_board_skin")
	Explore.begin_run({})
	var s = rush_host()
	await process_frame
	var time_cell := s._topbar.find_child("RushTimeCell", true, false) as Control if s._topbar != null else null
	var score_cell := s._topbar.find_child("RushScoreCell", true, false) as Control if s._topbar != null else null
	var mult_cell := s._topbar.find_child("RushMultCell", true, false) as Control if s._topbar != null else null
	for cell in [time_cell, score_cell, mult_cell]:
		var deckle: Node = cell.find_child("RushCellDeckleSurface", true, false) if cell != null else null
		ok(_uses_cut_paper(deckle), "Rush score boxes use the shared rugged cut-paper surface")
		ok(deckle != null and deckle.get("paper_tex") != null, "Rush score boxes carry paper fibre texture")
	ok(s.find_child("RushExitShadow", true, false) != null, "Rush close button casts its own shadow")
	var idle_deckle: Node = s._act_idle.find_child("RushActivityDeckleSurface", true, false) if s._act_idle != null else null
	var warn_deckle: Node = s._act_warn.find_child("RushActivityDeckleSurface", true, false) if s._act_warn != null else null
	ok(_uses_cut_paper(idle_deckle), "Rush idle treefall rail uses the shared rugged paper surface")
	ok(_uses_cut_paper(warn_deckle), "Rush incoming treefall rail uses the shared rugged paper surface")
	ok(s._chrome != null and s._chrome.find_child("MeadowBoardSurface", true, false) != null, \
		"Rush board frame is built by the same Kit.board_panel surface as the home board")
	var board_cfg: Dictionary = Kit.load_config(Kit.CONFIG_PATH).get("board", {})
	var expected_frame := float(board_cfg.get("frame", 60.0))
	ok(absf(float(s._frame_out) - expected_frame) <= 0.01, \
		"Rush board frame overhang uses the same board.frame setting as the home board")
	ok(s._chrome != null and (s._chrome.find_child("TornCellOuter", true, false) != null \
		or s._chrome.find_child("SlotCellSprite", true, false) != null), \
		"Rush board cells use the same shared slot-cell component as the home board")
	ok(s._chrome != null and s._chrome.find_child("SlotCellBackground", true, false) == null, \
		"Rush board cells do not fall back to the retired flat slot-cell background")
	var hint_tray := s.find_child("RushBottomHintTray", true, false) as PanelContainer
	ok(hint_tray != null and hint_tray.find_child(ActionBarKit.DECKLE_SURFACE_NODE, true, false) != null, \
		"Rush info card uses the board info tray deckled surface")
	await drop(s)


# S-RESIZE: the Rush screen must re-fit on a live viewport resize (drag the window wider / rotate), like the
# home map and the board action bar — it was built once from the startup size and stayed pinned. Drive two
# known widths and assert the board re-centres + re-fits, the activity bar tracks the width, and the bottom
# hint follows (deferred one-frame coalesce → wait two frames). Also guards the treefall warning toggle.
func _test_rush_resize() -> void:
	fresh("rush_resize")
	Explore.begin_run({})
	var s = rush_host()
	# let the engine run the in-tree _ready (it connects size_changed — the manual one above ran out of tree)
	await create_timer(0.06).timeout
	get_root().size = Vector2i(1080, 1920)
	await create_timer(0.06).timeout
	await create_timer(0.06).timeout
	var cx1080: float = s._board.position.x + s._board.size.x * 0.5
	var bx1080: float = s._board.position.x
	ok(absf(cx1080 - 540.0) < 3.0, "S-RESIZE: the rush board re-centres to the 1080 width (cx=%.0f)" % cx1080)
	ok(s._board.position.x + s._board.size.x <= 1082.0, "S-RESIZE: the board fits within the 1080 width")
	ok(absf(s._activity.size.x - (s._board.size.x + 2.0 * float(s._frame_out))) < 3.0, "S-RESIZE: the activity bar matches the board width at 1080 (w=%.0f)" % s._activity.size.x)
	get_root().size = Vector2i(1600, 1920)
	await create_timer(0.06).timeout
	await create_timer(0.06).timeout
	var cx1600: float = s._board.position.x + s._board.size.x * 0.5
	ok(absf(cx1600 - 800.0) < 3.0, "S-RESIZE: the rush board re-centres on a live resize to 1600 (cx=%.0f)" % cx1600)
	ok(s._board.position.x + s._board.size.x <= 1602.0, "S-RESIZE: the re-fitted board fits within the 1600 width")
	ok(absf(s._activity.size.x - (s._board.size.x + 2.0 * float(s._frame_out))) < 3.0, "S-RESIZE: the activity bar re-fits to the board width at 1600 (w=%.0f)" % s._activity.size.x)
	ok(absf(s._board.position.x - bx1080) > 10.0, "S-RESIZE: the board actually moved on the resize (not pinned to the old width)")
	ok(s._hint != null and absf((s._hint.position.x + s._hint.size.x * 0.5) - 800.0) < 8.0, "S-RESIZE: the bottom hint re-centres to the new width")
	var hint_label := s._hint.find_child("RushBottomHint", true, false) as Label if s._hint != null else null
	# the caption box FILLS the strip (symmetric centring — no top-only pad that shoved the text low) and
	# carries only a small optical-centre nudge; valign CENTER then sits it on the pill centre.
	var hint_label_nudge := hint_label.position.y if hint_label != null else 999.0
	ok(hint_label != null and hint_label.vertical_alignment == VERTICAL_ALIGNMENT_CENTER \
		and absf(hint_label.size.y - s._hint.size.y) < 1.0 \
		and absf(hint_label_nudge) <= s._hint.size.y * 0.06, \
		"S-RESIZE: the bottom hint caption fills the bar and is centred (nudge=%.1f)" % hint_label_nudge)
	# the info bar sits at the vertical CENTRE of the bottom section (board frame bottom → screen bottom):
	# equal breathing above and below, both clear.
	var board_fb: float = s._board.position.y + s._board.size.y + float(s._frame_out) if s._board != null else 0.0
	var margin_above: float = s._hint.position.y - board_fb if s._hint != null else 0.0
	var margin_below: float = 1920.0 - (s._hint.position.y + s._hint.size.y) if s._hint != null else 0.0
	ok(s._hint != null and margin_above > 4.0 and margin_below > 4.0 and absf(margin_above - margin_below) < 6.0, \
		"S-RESIZE: the bottom hint is centred in the bottom section (above=%.0f below=%.0f)" % [margin_above, margin_below])
	get_root().size = Vector2i(1600, 1400)
	await create_timer(0.06).timeout
	await create_timer(0.06).timeout
	var board_frame_bottom: float = s._board.position.y + s._board.size.y + float(s._frame_out)
	var hint_top: float = s._hint.position.y if s._hint != null else 0.0
	ok(board_frame_bottom <= hint_top - 8.0, \
		"S-RESIZE: the rush board frame clears the bottom hint on wide/short screens (frame bottom=%.0f hint top=%.0f)" % [board_frame_bottom, hint_top])
	# the treefall telegraph flips the activity bar to its warning state (and aims the chevron)
	s._tf = {"ph": "tele", "t": 0.0, "col": 3, "next": 9.0}
	s._apply_treefall_visual()
	ok(s._act_warn.visible and not s._act_idle.visible, "S-RESIZE: telegraphing a treefall shows the warning strip, hides the idle rail")
	ok(s._act_arrow is TextureRect and s._act_arrow.texture != null \
		and String(s._act_arrow.texture.resource_path).ends_with("ui/meadow_v2/danger_chevron.png"), \
		"S-RESIZE: treefall uses the Meadow danger chevron without repurposing the bottom hint")
	# the warning strip is the mock's coral cut-paper CAPSULE: fully-rounded ends + THE uniform shadow,
	# with a rounded (not square ColorRect) countdown fill.
	var warn_sb := (s._act_warn as Panel).get_theme_stylebox("panel") as StyleBoxFlat
	ok(warn_sb != null and warn_sb.get_corner_radius(CORNER_TOP_LEFT) == int(s._act_warn.size.y * 0.5) \
		and warn_sb.shadow_size > 0, \
		"S-RESIZE: the treefall warning is a capsule pill wearing the shared shadow")
	var fill_sb := (s._act_fill as Panel).get_theme_stylebox("panel") as StyleBoxFlat if s._act_fill is Panel else null
	ok(fill_sb != null and fill_sb.get_corner_radius(CORNER_TOP_LEFT) > 0, \
		"S-RESIZE: the treefall countdown fill has rounded capsule ends")
	s._tf = {"ph": "idle", "t": 0.0, "col": 0, "next": 9.0}
	s._apply_treefall_visual()
	ok(s._act_idle.visible and not s._act_warn.visible, "S-RESIZE: clearing the treefall returns to the idle rail")
	get_root().size = Vector2i(1080, 1920)
	await create_timer(0.06).timeout
	s.queue_free()
	await create_timer(0.05).timeout

func _test_trade_reward_dialog_layout() -> void:
	fresh("reward_overlay_layout")
	var z := 0
	var g := Save.grove()
	var unl := {}
	for sp in G.MAPS[z].spots:
		unl[String(sp.id)] = true
	g["unlocks"] = unl
	g["gates"] = [z]
	Save.grove_write()
	Explore.begin_run({})
	Explore.add_score(Explore.TRADE_RATE * 3)       # a great run → TRADE_MAX reels
	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_root().add_child(host)
	ExploreReward.open(host, {"on_done": func() -> void: pass})
	ok(host.find_child("RewardDialog", true, false) != null, "the reward mounts the shared framed dialog on the board")
	var grid := host.find_child("RewardReels", true, false)
	ok(grid != null and grid.get_child_count() == Explore.TRADE_MAX, "a great run reveals TRADE_MAX reels")
	host.queue_free()

# The per-run trade is capped at TRADE_MAX, so the reveal can never overflow through the real path — a
# runaway score still grants exactly TRADE_MAX spirits and no "+N more" tile. The MAX_ROWS fold stays
# as a defensive bound of the dialog builder and is exercised directly with a synthetic haul.
func _test_reward_row_cap() -> void:
	fresh("reward_row_cap")
	var z := 0
	var g := Save.grove()
	var unl := {}
	for sp in G.MAPS[z].spots:
		unl[String(sp.id)] = true
	g["unlocks"] = unl
	g["gates"] = [z]
	Save.grove_write()
	Explore.begin_run({})
	Explore.add_score(Explore.TRADE_RATE * 30)      # runaway score — the trade cap is the brake
	var hand_before := Bucket.hand().size()
	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_root().add_child(host)
	ExploreReward.open(host, {"on_done": func() -> void: pass})
	ok(Bucket.hand().size() == hand_before + Explore.TRADE_MAX, "a runaway score grants exactly TRADE_MAX spirits")
	var grid := host.find_child("RewardReels", true, false) as GridContainer
	ok(grid != null and grid.get_child_count() == Explore.TRADE_MAX, "the capped haul reveals one reel per spirit")
	ok(host.find_child("RewardMore", true, false) == null, "a capped haul never shows the overflow tile")
	host.queue_free()
	# the builder's row-cap fold, driven directly with a haul bigger than any trade can produce
	var haul: Array = []
	for i in 30:
		haul.append({"kind": "meadow", "tier": 1 + (i % 4)})
	var built: Dictionary = ExploreReward.build(Kit, haul, 660.0, 1280.0, func() -> void: pass)
	var host2 := Control.new()
	host2.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_root().add_child(host2)
	host2.add_child(built["dialog"])
	var grid2 := host2.find_child("RewardReels", true, false) as GridContainer
	ok(grid2 != null and grid2.get_child_count() == grid2.columns * ExploreReward.MAX_ROWS,
		"a synthetic huge haul fills exactly the capped rows")
	ok(host2.find_child("RewardMore", true, false) != null, "the overflow folds into a +N more tile")
	host2.queue_free()

func _test_loadout_uses_toggle_card_callback() -> void:
	var map_src := "res://engine/scripts/scenes/map.gd"
	ok(_source_contains(map_src, "\"on_toggle\": make_loadout_toggle.call(id)"),
		"loadout rows use toggle_card's on_toggle callback as the single toggle path")
	ok(not _source_contains(map_src, "sw.pressed.connect(on_switch_pressed"),
		"loadout rows do not add a second switch pressed handler")

func _test_loadout_toggle_updates_in_place() -> void:
	fresh("explore_loadout_overlay")
	Save.spend(Save.coins())
	Save.add_coins(1000)
	var map = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(map)
	await process_frame
	map._open_expedition(0)
	await process_frame
	var overlay := map.get_node_or_null("ExpeditionOverlay") as Control
	ok(overlay != null, "the map opens the expedition loadout overlay")
	if overlay == null:
		map.queue_free()
		await process_frame
		return
	var cc := overlay.get_child(1) as CenterContainer
	var dialog_before := cc.get_child(0) as Control
	var sw: Button = _switch_for_label(dialog_before, "Lantern")
	ok(sw != null, "the Lantern loadout row has a switch to toggle")
	if sw == null:
		map.queue_free()
		await process_frame
		return
	ok(sw.get_global_rect().size.x > 0.0 and sw.get_global_rect().size.y > 0.0,
		"the Lantern switch has a real hit rect")
	_push_tap(_hit_center(sw))
	await process_frame
	ok(cc.get_child_count() == 1, "toggling a boost does not queue a replacement dialog")
	ok(cc.get_child(0) == dialog_before, "the same loadout dialog instance remains after a toggle")
	var cost_after := _button_text_with_prefix(dialog_before, "Cost")
	ok(cost_after == "Cost 270", "the total cost chip updates in place after toggling Lantern (%s)" % cost_after)
	ok(bool(sw.get_meta("on")), "a real tap leaves the Lantern switch on after an affordable toggle")
	_push_tap(_hit_center(sw))
	await process_frame
	ok(not bool(sw.get_meta("on")), "a second real tap toggles Lantern back off")
	var cost_off := _button_text_with_prefix(dialog_before, "Cost")
	ok(cost_off == "Cost 150", "the total cost chip returns to base cost after toggling Lantern off (%s)" % cost_off)
	var card := _card_for_label(dialog_before, "Lantern")
	ok(card != null, "the Lantern loadout row has a mail-style card tap target")
	if card != null:
		_push_tap(_hit_center(card))
		await process_frame
		ok(is_instance_valid(dialog_before), "tapping the loadout row keeps the dialog open")
		if is_instance_valid(dialog_before):
			ok(bool(sw.get_meta("on")), "tapping the mail-style row toggles Lantern on")
			var row_cost := _button_text_with_prefix(dialog_before, "Cost")
			ok(row_cost == "Cost 270", "row-tapping Lantern updates the total cost (%s)" % row_cost)
	await process_frame
	ok(cc.get_child_count() == 1 and cc.get_child(0) == dialog_before, "the original loadout dialog survives the next frame")
	map.queue_free()
	await process_frame

func _test_loadout_keeps_unaffordable_choices_visible() -> void:
	fresh("explore_loadout_unaffordable")
	Save.spend(Save.coins())
	Save.add_coins(300)
	var map = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(map)
	await process_frame
	map._open_expedition(0)
	await process_frame
	var overlay := map.get_node_or_null("ExpeditionOverlay") as Control
	ok(overlay != null, "the low-wallet loadout overlay opens")
	if overlay == null:
		map.queue_free()
		await process_frame
		return
	var cc := overlay.get_child(1) as CenterContainer
	var dialog := cc.get_child(0) as Control
	var focus_sw: Button = _switch_for_label(dialog, "Focus totem")
	var go := _button_with_text(dialog, "Set off")
	ok(focus_sw != null, "the Focus totem row has a switch")
	ok(go != null, "the loadout dialog has a Set off button")
	if focus_sw == null or go == null:
		map.queue_free()
		await process_frame
		return
	_push_tap(_hit_center(focus_sw))
	await process_frame
	var cost_after := _button_text_with_prefix(dialog, "Cost")
	ok(bool(focus_sw.get_meta("on")), "an unaffordable boost still stays visibly selected")
	ok(cost_after == "Cost 350", "the total cost still shows the selected unaffordable boost (%s)" % cost_after)
	ok(go.disabled, "Set off is disabled while the selected total exceeds the wallet")
	_push_tap(_hit_center(focus_sw))
	await process_frame
	var cost_off := _button_text_with_prefix(dialog, "Cost")
	ok(not bool(focus_sw.get_meta("on")), "tapping the unaffordable boost again turns it off")
	ok(cost_off == "Cost 150", "turning it off returns to the base cost (%s)" % cost_off)
	ok(not go.disabled, "Set off is re-enabled once the selected total is affordable")
	map.queue_free()
	await process_frame

func _test_rush_fx_knob_forwarding() -> void:
	# the resolved opts the scene reads carry the knobs (overrides honoured)
	var RushFx = load("res://engine/scripts/ui/rush_fx.gd")
	var opts: Dictionary = RushFx.from_config({"rush_fx": {"treefall_shake": 33}})
	ok(RushFx.knob(opts, "treefall_shake") == 33, "from_config carries a saved knob the scene can read")
	# each gated call site forwards a knob value (guards the wiring without a live grid).
	# merge_burst_count is no longer forwarded by the live scene — the merge burst routes through
	# Feel.merge now (merge_burst stays a workbench-preview-only effect), so it is not in this list.
	var src := FileAccess.get_file_as_string("res://engine/scripts/scenes/explore_rush.gd")
	for needle in [
		"RushFx.knob(_fx, \"score_tick_ms\")",
		"RushFx.knob(_fx, \"score_pulse_pct\")",
		"RushFx.knob(_fx, \"mult_pop_pct\")",
		"RushFx.knob(_fx, \"combo_heat_size\")",
		"RushFx.knob(_fx, \"timer_low_secs\")",
		"RushFx.knob(_fx, \"treefall_debris\")",
		"RushFx.knob(_fx, \"treefall_shake\")",
		"RushFx.knob(_fx, \"treefall_hitstop_ms\")",
	]:
		ok(src.find(needle) != -1, "explore_rush forwards %s" % needle)
	# the merge impact now routes through the workbench-tuned MergeFx applier (gate 2 keeps low-combo merges
	# snappy). The ripple + board punch fire INSIDE the applier — the win-cell neighbours (skipping the
	# falling lose column) + the board are passed in, with NO separate scene-side ripple/board_punch calls.
	ok(src.find("MergeFx.apply(self, node, ctr, int(win.tier), _combo, _orthogonal_neighbour_nodes(win_rc.x, win_rc.y, lose_rc.y, lose_rc.x), _board, _merge_opts, 1.0, 2)") != -1, "explore_rush routes the merge through MergeFx.apply (gate 2, neighbours + board passed in)")
	ok(src.find("RushFx.merge_burst(") == -1, "explore_rush no longer calls RushFx.merge_burst in the live merge")
	ok(src.find("_merge_opts = MergeFx.from_config(") != -1, "explore_rush resolves the merge_fx config once")
	# the applier owns the ripple + board punch — the scene no longer calls Feel.ripple/board_punch around
	# the merge (double-firing would be a bug).
	ok(src.find("Feel.ripple(_orthogonal_neighbour_nodes(win_rc.x") == -1, "explore_rush no longer ripples the merge scene-side (MergeFx.apply owns it)")
	ok(src.find("Feel.board_punch(_board") == -1, "explore_rush no longer punches the board scene-side (MergeFx.apply owns it)")
	# the fling touchdown ALSO ripples its settled neighbours (this stays scene-side — LandFx has no ripple);
	# the bulk gravity settle does NOT ripple.
	ok(src.find("Feel.ripple(_orthogonal_neighbour_nodes(fc.x, fc.y), lc, 0.8)") != -1, "explore_rush ripples the fling touchdown's neighbours")
	ok(src.find("func _settle") != -1 and src.find("Explore.gravity(_grid)") != -1, "explore_rush still has the bulk settle (which must NOT ripple)")
	# guard: _settle (the bulk gravity path) carries no Feel.ripple — only discrete impacts ripple.
	var settle_seg := src.substr(src.find("func _settle"), 400)
	ok(settle_seg.find("Feel.ripple") == -1, "the bulk gravity settle does NOT ripple (only discrete merge/land impacts do)")
