extends "res://games/grove/tests/grove_test_base.gd"
## Grove Weather Hours scene coverage: marker/patch geometry, info-bar tap, Starfall
## scene payment/defer, and deletion of the old win-back rain beat.
##   godot --headless --path . -s res://games/grove/tests/grove_sky_tests.gd

const Ambient = preload("res://engine/scripts/ui/ambient.gd")
const SkyLogic = preload("res://engine/scripts/core/sky.gd")
const Overlay = preload("res://engine/scripts/ui/overlay.gd")
const SkyPatch = preload("res://engine/scripts/ui/sky_patch.gd")

## The docked star bobs on a looping tween (board.gd `_start_docked_star_bob`, ±3 px), so its rendered
## box is never pinned to a single y. Every dock-geometry assert allows exactly that much slack and no
## more — the defect this guards against was a ~42 px offset, an order of magnitude bigger.
const DOCK_BOB_PX := 3.0

func _initialize() -> void:
	begin("grove · weather hours")
	await process_frame
	await _test_patch_edges_read_stronger_than_centers()
	await _test_calm_hour_shows_no_chrome()
	await _test_marker_patch_and_info_bar()
	await _test_sky_patch_refresh_stays_under_playables()
	await _test_landscape_marker_stays_out_of_playable_cells()
	await _test_starfall_start_tracks_landing_cell_in_landscape()
	await _test_starfall_scene_payment_and_modal_defer()
	await _test_starfall_pending_docks_before_catch()
	await _test_starfall_catch_real_tap_and_duplicate_input()
	await _test_starfall_ignores_non_catch_taps()
	await _test_starfall_fallbacks_and_resume_rules()
	await _test_starfall_full_lane_and_full_board()
	await _test_starfall_info_auto_announcement()
	await _test_winback_rain_beat_removed()
	Ambient.reset_weather_debug_for_test()
	finish()

func _open_board(name: String, forced_weather: String):
	fresh(name)
	return await _mount_board(forced_weather)

func _mount_board(forced_weather: String):
	Save.mark_board_tutorial_seen()
	Save.mark_ftue_seen("merge")
	Save.mark_ftue_seen("gen_tap")
	Feat.FLAGS["weather_hours"] = true
	Ambient.forced_weather = forced_weather
	var b = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(b)
	await process_frame
	await process_frame
	return b

func _test_patch_edges_read_stronger_than_centers() -> void:
	var patch := SkyPatch.new()
	ok(patch.has_method("lane_alpha_samples"), "SkyPatch exposes the alpha samples used by its draw path")
	if not patch.has_method("lane_alpha_samples"):
		return
	var sun: Dictionary = patch.call("lane_alpha_samples", "sunbeam")
	ok(float(sun.edge) > float(sun.center) + 0.04, \
		"Sunbeam patch renders a stronger shaft edge than center so it reads on cream/brown cells")
	var star: Dictionary = patch.call("lane_alpha_samples", "starfall")
	ok(float(star.edge) > float(star.center) + 0.03, \
		"Starfall patch renders a stronger glimmer edge than center so the column reads")

## A Calm hour is the pre-weather board: the ambient skin still drifts, but the mat carries no wash,
## nothing sits outside it, and there is nothing to tap. Asserted on a board with the gift gate OPEN,
## so a pass means Calm itself withholds the chrome — not the gate.
func _test_calm_hour_shows_no_chrome() -> void:
	var calm = await _open_board("sky_calm", "calm")
	ok(SkyLogic.gate_open(), "the Calm capture runs with the gift gate OPEN, so Calm is what withholds the chrome")
	ok(String(calm._sky_state.get("sky", "")) == "calm" and int(calm._sky_state.get("lane", 0)) == -1 \
		and String(calm._sky_state.get("lane_axis", "x")) == "", \
		"a forced Calm hour reaches the board as the Calm sky with no lane")
	ok(calm.board_area.find_child("SkyPatch", true, false) == null, "a Calm hour draws no lane wash")
	ok(calm.find_child("SkyMarker", true, false) == null, "a Calm hour mounts no lane marker anywhere in the scene")
	var info := String(calm._info_label.text)
	ok(info.find("Calm") == -1 and info.find("Sunbeam") == -1 and info.find("Rain") == -1 and info.find("Starfall") == -1, \
		"a Calm hour leaves the info bar alone — no sky line is written (%s)" % info)
	calm._rebuild_all()
	await process_frame
	ok(calm.board_area.find_child("SkyPatch", true, false) == null \
		and calm.find_child("SkyMarker", true, false) == null, \
		"the Calm board stays chrome-free across _rebuild_all, which re-inserts patch and marker for other skies")
	calm.queue_free()

func _test_marker_patch_and_info_bar() -> void:
	var sun = await _open_board("sky_marker_sun", "clear")
	var patch := sun.board_area.find_child("SkyPatch", true, false) as Control
	var marker := sun.find_child("SkyMarker", true, false) as Button
	ok(patch != null and patch.get_parent() == sun.board_area, "Sunbeam patch mounts inside board_area")
	ok(patch != null and patch.get_index() > 0, "Sunbeam patch is inserted after the board surface/slot block")
	ok(marker != null, "Sunbeam marker exists as the single weather chrome")
	if marker != null:
		var sun_glyph := marker.find_child("SkyMarkerGlyph", true, false) as TextureRect
		ok(marker.text == "" and sun_glyph != null, "Sunbeam marker uses a drawn/icon glyph, not a text letter")
		ok(sun_glyph != null and String(sun_glyph.get_meta("icon_path", "")).find("icon_sky_sun.png") != -1, \
			"Sunbeam marker is wired to the future sun icon path")
		var sun_rect: Rect2 = marker.get_global_rect()
		var sun_board_rect: Rect2 = sun.board_area.get_global_rect()
		ok(absf(sun_rect.get_center().y - sun_board_rect.position.y) <= sun_rect.size.y * 0.7, \
			"Sunbeam marker hugs the board edge instead of overlapping the quest cards above")
		marker.pressed.emit()
		await process_frame
		ok(String(sun._info_label.text).find("Sunbeam") != -1 and String(sun._info_desc_label.text).find("drop coins") != -1, \
			"tapping the Sunbeam marker writes the sky line into the bottom info bar")
	sun._rebuild_all()
	await process_frame
	ok(sun.board_area.find_child("SkyPatch", true, false) != null and sun.find_child("SkyMarker", true, false) != null, \
		"patch and marker survive _rebuild_all")
	sun._landscape = not sun._landscape
	sun._rebuild_all()
	await process_frame
	ok(sun.board_area.find_child("SkyPatch", true, false) != null, "patch survives an orientation flip/reflow")
	sun.queue_free()

	var rain = await _open_board("sky_marker_rain", "rain")
	var rain_marker := rain.find_child("SkyMarker", true, false) as Button
	ok(rain_marker != null, "Rain marker exists")
	if rain_marker != null:
		var rain_glyph := rain_marker.find_child("SkyMarkerGlyph", true, false) as TextureRect
		ok(rain_marker.text == "" and rain_glyph != null, "Rain marker uses a drawn/icon glyph, not a text letter")
		ok(rain_glyph != null and String(rain_glyph.get_meta("icon_path", "")).find("icon_sky_rain.png") != -1, \
			"Rain marker is wired to the future rain icon path")
		var rain_rect: Rect2 = rain_marker.get_global_rect()
		var rain_board_rect: Rect2 = rain.board_area.get_global_rect()
		ok(rain_rect.position.x >= 16.0 and rain_rect.end.x <= rain_board_rect.position.x + 6.0, \
			"Rain marker keeps a screen gutter while staying on the mat's left edge")
		rain_marker.pressed.emit()
		await process_frame
		ok(String(rain._info_label.text).find("Rain") != -1 and String(rain._info_desc_label.text).find("water") != -1, \
			"tapping the Rain marker writes the rain line into the bottom info bar")
	rain.queue_free()

func _test_sky_patch_refresh_stays_under_playables() -> void:
	var sun = await _open_board("sky_patch_layer_refresh", "clear")
	var before_patch := sun.board_area.find_child("SkyPatch", true, false) as Control
	ok(before_patch != null and _first_tile_child_index(sun) > before_patch.get_index(), \
		"Sunbeam patch starts below pieces/generators in board_area")
	sun.refresh_weather()
	await process_frame
	var after_patch := sun.board_area.find_child("SkyPatch", true, false) as Control
	ok(after_patch != null and _first_tile_child_index(sun) > after_patch.get_index(), \
		"Sunbeam patch refresh keeps the wash below pieces/generators")
	sun.queue_free()

func _test_landscape_marker_stays_out_of_playable_cells() -> void:
	var sun = await _open_board("sky_landscape_marker", "clear")
	sun._landscape = true
	for axis in [SkyLogic.AXIS_ROW, SkyLogic.AXIS_COLUMN]:
		sun._sky_state = {
			"hour": int(sun._sky_state.get("hour", 0)),
			"sky": SkyLogic.SKY_SUNBEAM,
			"skin": SkyLogic.SKIN_CLEAR,
			"lane_axis": axis,
			"lane": 3,
		}
		sun._sync_sky_patch_marker(false)
		await process_frame
		var marker := sun.find_child("SkyMarker", true, false) as Button
		ok(marker != null and not _marker_intersects_playable_cells(sun, marker), \
			"landscape %s marker stays off playable cells despite stopping mouse input" % axis)
	sun.queue_free()

func _test_starfall_start_tracks_landing_cell_in_landscape() -> void:
	var star = await _open_board("sky_starfall_landscape_start", "star")
	star._landscape = true
	star._sync_sky_patch_marker(false)
	await process_frame
	ok(star.has_method("_star_arrival_start_pos"), "Starfall exposes its off-mat arrival start for tests and shot tooling")
	if star.has_method("_star_arrival_start_pos"):
		var marker := star.find_child("SkyMarker", true, false) as Control
		var board_rect := Rect2(Vector2.ZERO, Vector2(star._board_w(), star._board_h()))
		var from: Vector2 = star.call("_star_arrival_start_pos")
		ok(marker != null and not board_rect.has_point(from) and from.distance_to(marker.position) < star.csz * 3.0, \
			"landscape Starfall arrival starts outside the mat on the marker side")
	star.queue_free()

func _test_starfall_scene_payment_and_modal_defer() -> void:
	var deferred = await _open_board("sky_star_defer", "star")
	var before := _item_count(deferred)
	var modal := Control.new()
	modal.name = "TestModalOverlay"
	modal.z_index = Overlay.MODAL_Z
	deferred.add_child(modal)
	deferred._sky_live_secs = G.STAR_DELAY
	deferred._try_starfall()
	await process_frame
	ok(_item_count(deferred) == before and int(SkyLogic.grove_sky_state().paid_hour) < int(deferred._sky_state.hour), \
		"Starfall defers while a modal is open and does not stamp paid_hour")
	deferred.queue_free()

	var landed = await _open_board("sky_star_lands", "star")
	var star_marker := landed.find_child("SkyMarker", true, false) as Button
	if star_marker != null:
		var star_glyph := star_marker.find_child("SkyMarkerGlyph", true, false) as TextureRect
		ok(star_marker.text == "" and star_glyph != null, "Starfall marker uses an icon glyph, not a text asterisk")
		ok(star_glyph != null and String(star_glyph.get_meta("icon_path", "")).find("icon_star.png") != -1, \
			"Starfall marker is wired to the shared star icon path")
	var before_land := _item_count(landed)
	landed._sky_live_secs = G.STAR_DELAY
	landed._try_starfall()
	await process_frame
	ok(int(SkyLogic.grove_sky_state().get("pending", 0)) > 0 and _item_count(landed) == before_land, \
		"forced Starfall docks a pending catch code instead of immediately landing a model piece")
	ok(int(SkyLogic.grove_sky_state().paid_hour) == int(landed._sky_state.hour), "Starfall stamps paid_hour when it rolls")
	landed.queue_free()

func _test_starfall_pending_docks_before_catch() -> void:
	var star = await _open_board("sky_star_pending", "star")
	_clear_lane_for_catch(star)
	star._rebuild_all()
	await process_frame
	var before := _item_count(star)
	var code := await _arm_pending_star(star)
	ok(code > 0, "at STAR_DELAY Starfall stores a pending catch code")
	ok(_item_count(star) == before and _code_count(star, code) == 0, \
		"pending Starfall has not placed the rolled item in the model yet")
	ok(star.find_child("DockedStar", true, false) != null, "pending Starfall rebuilds a docked piece at the marker")
	_assert_dock_sits_in_marker(star, "pending Starfall")
	var catch_cells := _call_star_catch_cells(star)
	ok(not catch_cells.is_empty(), "pending Starfall exposes the empty lane cells that should be lit for catch")
	star._rebuild_all()
	await process_frame
	ok(int(SkyLogic.grove_sky_state().get("pending", 0)) == code \
		and star.find_child("DockedStar", true, false) != null \
		and not _call_star_catch_cells(star).is_empty(), \
		"pending Starfall survives _rebuild_all with dock and catch cells restored from save state")
	_assert_dock_sits_in_marker(star, "the rebuilt dock")
	star.queue_free()

func _test_starfall_catch_real_tap_and_duplicate_input() -> void:
	var star = await _open_board("sky_star_catch_tap", "star")
	var lane_cells := _clear_lane_for_catch(star)
	star._rebuild_all()
	await process_frame
	var before := _item_count(star)
	var code := await _arm_pending_star(star)
	var target: Vector2i = lane_cells[0] if not lane_cells.is_empty() else Vector2i(-1, -1)
	ok(code > 0 and target.x >= 0, "catch fixture has a pending star and a lane target")
	if target.x >= 0:
		_tap_board_with_duplicate_events(star, star._cell_pos(target) + Vector2(star.csz, star.csz) / 2.0)
		await create_timer(0.35).timeout
		ok(int(SkyLogic.grove_sky_state().get("pending", 0)) == 0, "catching a lit cell clears pending")
		ok(star.board.item_at(target) == code, "catching places the pending code in the tapped lane cell")
		ok(_item_count(star) == before + 1 and _code_count(star, code) == 1, \
			"mouse plus synthesized touch catches exactly once")
		ok(star.find_child("DockedStar", true, false) == null and _call_star_catch_cells(star).is_empty(), \
			"catch tears down the docked star and lit catch cells")
	star.queue_free()

func _test_starfall_ignores_non_catch_taps() -> void:
	var star = await _open_board("sky_star_ignore_taps", "star")
	var lane_cells := _clear_lane_for_catch(star)
	star._rebuild_all()
	await process_frame
	var code := await _arm_pending_star(star)
	var occupied: Vector2i = lane_cells[0] if not lane_cells.is_empty() else Vector2i(-1, -1)
	if occupied.x >= 0:
		star.board.place(occupied, 101)
		star._rebuild_all()
		await process_frame
		_tap_board_with_duplicate_events(star, star._cell_pos(occupied) + Vector2(star.csz, star.csz) / 2.0)
		await process_frame
	ok(int(SkyLogic.grove_sky_state().get("pending", 0)) == code, "tapping an occupied lane cell leaves pending untouched")
	var off_lane := _empty_off_lane_cell(star)
	if off_lane.x >= 0:
		_tap_board_with_duplicate_events(star, star._cell_pos(off_lane) + Vector2(star.csz, star.csz) / 2.0)
		await process_frame
	ok(int(SkyLogic.grove_sky_state().get("pending", 0)) == code, "tapping an empty off-lane cell leaves pending untouched")
	var marker := star.find_child("SkyMarker", true, false) as Button
	if marker != null:
		marker.pressed.emit()
		await process_frame
	ok(int(SkyLogic.grove_sky_state().get("pending", 0)) == code, "tapping the marker shows info and leaves pending untouched")
	star.queue_free()

func _test_starfall_fallbacks_and_resume_rules() -> void:
	var timeout = await _open_board("sky_star_timeout", "star")
	_clear_lane_for_catch(timeout)
	timeout._rebuild_all()
	await process_frame
	var timeout_code := await _arm_pending_star(timeout)
	timeout._sky_live_secs = float(G.STAR_DELAY) + float(G.STAR_CATCH_SECS)
	timeout._try_starfall()
	await create_timer(0.35).timeout
	ok(int(SkyLogic.grove_sky_state().get("pending", 0)) == 0 and _code_count(timeout, timeout_code) == 1 \
		and Array(SkyLogic.grove_sky_state().get("owed", [])).is_empty(), \
		"STAR_CATCH_SECS elapsed resolves pending into an uncaught landing")
	timeout.queue_free()

	var turned = await _open_board("sky_star_hour_turn", "star")
	_clear_lane_for_catch(turned)
	turned._rebuild_all()
	await process_frame
	var turn_code := await _arm_pending_star(turned)
	turned._sky_state["hour"] = int(turned._sky_state.get("hour", 0)) - 1
	turned._tick_sky_hour()
	await process_frame
	ok(int(SkyLogic.grove_sky_state().get("pending", 0)) == 0 \
		and Array(SkyLogic.grove_sky_state().get("owed", [])).has(turn_code), \
		"an hour turn converts pending Starfall into owed")
	turned._after_board_change()
	await create_timer(0.35).timeout
	ok(_code_count(turned, turn_code) == 1 and Array(SkyLogic.grove_sky_state().get("owed", [])).is_empty(), \
		"the owed Starfall lands on the next board-change beat")
	turned.queue_free()

	var leaving = await _open_board("sky_star_persist", "star")
	_clear_lane_for_catch(leaving)
	leaving._rebuild_all()
	await process_frame
	var leave_code := await _arm_pending_star(leaving)
	leaving._persist()
	await process_frame
	ok(int(SkyLogic.grove_sky_state().get("pending", 0)) == 0 \
		and Array(SkyLogic.grove_sky_state().get("owed", [])).has(leave_code), \
		"_persist converts pending Starfall into owed before saving")
	leaving.queue_free()
	var reopened = await _mount_board("star")
	await create_timer(0.35).timeout
	ok(_code_count(reopened, leave_code) == 1 and Array(SkyLogic.grove_sky_state().get("owed", [])).is_empty(), \
		"a fresh board open lands the owed Starfall from the saved handoff")
	reopened.queue_free()

func _test_starfall_full_lane_and_full_board() -> void:
	var lane_full = await _open_board("sky_star_full_lane", "star")
	var freed := _fill_star_lane(lane_full)
	lane_full._rebuild_all()
	await process_frame
	var lane_code := await _arm_pending_star(lane_full)
	ok(lane_code > 0 and _call_star_catch_cells(lane_full).is_empty(), \
		"a full Starfall lane keeps pending but exposes no catch cells")
	if freed.x >= 0:
		lane_full.board.place(freed, 0)
		lane_full._after_board_change()
		await process_frame
		ok(_call_star_catch_cells(lane_full).has(freed) and int(SkyLogic.grove_sky_state().get("pending", 0)) == lane_code, \
			"freeing a lane cell lights it while pending survives")
	lane_full.queue_free()

	var board_full = await _open_board("sky_star_full_board", "star")
	_fill_all_empty_ground(board_full)
	board_full._rebuild_all()
	await process_frame
	var full_code := await _arm_pending_star(board_full)
	board_full._sky_live_secs = float(G.STAR_DELAY) + float(G.STAR_CATCH_SECS)
	board_full._try_starfall()
	await process_frame
	ok(int(SkyLogic.grove_sky_state().get("pending", 0)) == 0 \
		and Array(SkyLogic.grove_sky_state().get("owed", [])).has(full_code) \
		and board_full.find_child("OwedPip", true, false) != null, \
		"a full-board fallback queues owed and shows the owed pip")
	board_full.queue_free()

func _test_starfall_info_auto_announcement() -> void:
	var quiet = await _open_board("sky_star_info_auto", "star")
	_clear_lane_for_catch(quiet)
	quiet._clear_selection()
	await process_frame
	await _arm_pending_star(quiet)
	ok(String(quiet._info_label.text).find("Starfall") != -1 \
		and String(quiet._info_desc_label.text).find("tap a glowing cell") != -1, \
		"docking a pending Starfall auto-announces the catch line when nothing is selected")
	quiet.queue_free()

	var selected = await _open_board("sky_star_info_selected", "star")
	_clear_lane_for_catch(selected)
	selected._rebuild_all()
	await process_frame
	var item_cell := _first_item_cell(selected)
	if item_cell.x >= 0:
		selected._select_item(item_cell)
		await process_frame
	var label_before := String(selected._info_label.text)
	var desc_before := String(selected._info_desc_label.text)
	await _arm_pending_star(selected)
	ok(String(selected._info_label.text) == label_before and String(selected._info_desc_label.text) == desc_before, \
		"docking Starfall does not overwrite a live selection in the info bar")
	selected.queue_free()

func _test_winback_rain_beat_removed() -> void:
	fresh("winback_removed")
	Save.mark_board_tutorial_seen()
	var g := Save.grove()
	var old := Time.get_unix_time_from_system() - 49.0 * 3600.0
	g["board"] = BoardModel.new().to_dict()
	g["water"] = 0
	g["regen_ts"] = old
	g["last_seen"] = old
	g["winback_until"] = Time.get_unix_time_from_system() + 60.0
	Save.grove_write()
	Ambient.forced_weather = "clear"
	var b = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(b)
	await process_frame
	ok(b.water == G.WATER_CAP, "48h-away load fills water by plain offline regen")
	var winback_flag: Variant = b.get("_winback")
	ok(winback_flag == null or not winback_flag, "48h-away load does not set a win-back toast flag")
	b.queue_free()
	var ambient_src := FileAccess.get_file_as_string("res://engine/scripts/ui/ambient.gd")
	var board_src := FileAccess.get_file_as_string("res://engine/scripts/scenes/board.gd")
	var map_src := FileAccess.get_file_as_string("res://engine/scripts/scenes/map.gd")
	ok(ambient_src.find("check_winback") == -1 and ambient_src.find("winback_active") == -1, \
		"Ambient has no win-back rain helper left")
	ok(board_src.find("board.winback") == -1 and board_src.find("last_seen") == -1, \
		"Board no longer grants or toasts the win-back rain beat")
	ok(map_src.find("last_seen") == -1, "Map no longer writes last_seen for win-back rain")

## The rect a Control actually OCCUPIES ON SCREEN. Neither `get_global_rect()` nor `position`/`size`
## answers this for a SCALED node: `size` is the unscaled box, and `Control.scale` scales about
## `pivot_offset`, so the on-screen origin is `position + pivot_offset * (1 - scale)`. Reading the
## global transform is the only measurement that matches what renders.
func _rendered_rect(node: Control) -> Rect2:
	var xf := node.get_global_transform()
	return Rect2(xf.origin, node.size * xf.get_scale())

## §6: "the star piece parents to the lane marker" — it has to RENDER there too. Asserting the node
## exists is not enough: the docked star shipped ~42 px down-and-right of the chip, straddling the mat's
## top edge and covering the first cell row, and every existing test was green through it. Measured off
## the rendered transform of both nodes, so a pivot/scale regression fails here instead of in a capture.
func _assert_dock_sits_in_marker(board_scene, label: String) -> void:
	var dock := board_scene.find_child("DockedStar", true, false) as Control
	var chip := board_scene.find_child("SkyMarker", true, false) as Control
	ok(dock != null and chip != null, "%s has both a docked star and a marker chip to measure" % label)
	if dock == null or chip == null:
		return
	var dock_rect := _rendered_rect(dock)
	var chip_rect := _rendered_rect(chip)
	var d: Vector2 = dock_rect.get_center() - chip_rect.get_center()
	ok(absf(d.x) <= DOCK_BOB_PX and absf(d.y) <= DOCK_BOB_PX, \
		"%s renders CENTRED in the marker chip, off by (%.2f, %.2f) px" % [label, d.x, d.y])
	ok(chip_rect.grow(DOCK_BOB_PX).encloses(dock_rect), \
		"%s renders INSIDE the marker chip, not over the mat (dock %s vs chip %s)" % [label, dock_rect, chip_rect])

func _arm_pending_star(board_scene) -> int:
	board_scene._sky_live_secs = float(G.STAR_DELAY)
	board_scene._try_starfall()
	await process_frame
	return int(SkyLogic.grove_sky_state().get("pending", 0))

func _lane_cells(board_scene) -> Array:
	var out: Array = []
	var axis := String(board_scene._sky_state.get("lane_axis", "column"))
	var lane := int(board_scene._sky_state.get("lane", 0))
	if axis == "row":
		for c in G.COLS:
			out.append(Vector2i(lane, c))
	else:
		for r in G.ROWS:
			out.append(Vector2i(r, lane))
	return out

func _clear_lane_for_catch(board_scene) -> Array:
	var out: Array = []
	for cell in _lane_cells(board_scene):
		if board_scene.board.is_open(cell) and not board_scene.board.is_gen(cell):
			board_scene.board.place(cell, 0)
			out.append(cell)
	return out

func _fill_star_lane(board_scene) -> Vector2i:
	var first := Vector2i(-1, -1)
	for cell in _lane_cells(board_scene):
		if board_scene.board.is_open(cell) and not board_scene.board.is_gen(cell):
			if first.x < 0:
				first = cell
			board_scene.board.place(cell, 101)
	return first

func _fill_all_empty_ground(board_scene) -> void:
	for cell in board_scene.board.empty_ground_cells():
		board_scene.board.place(Vector2i(cell), 101)

func _empty_off_lane_cell(board_scene) -> Vector2i:
	for cell in board_scene.board.empty_ground_cells():
		var v := Vector2i(cell)
		if not SkyLogic.in_patch(board_scene._sky_state, v):
			return v
	return Vector2i(-1, -1)

func _first_item_cell(board_scene) -> Vector2i:
	for r in G.ROWS:
		for c in G.COLS:
			var cell := Vector2i(r, c)
			if board_scene.board.item_at(cell) > 0:
				return cell
	return Vector2i(-1, -1)

func _call_star_catch_cells(board_scene) -> Array:
	if not board_scene.has_method("_star_catch_cells"):
		return []
	return Array(board_scene.call("_star_catch_cells"))

func _tap_board_with_duplicate_events(board_scene, at: Vector2) -> void:
	var mouse_down := InputEventMouseButton.new()
	mouse_down.button_index = MOUSE_BUTTON_LEFT
	mouse_down.pressed = true
	mouse_down.position = at
	var touch_down := InputEventScreenTouch.new()
	touch_down.pressed = true
	touch_down.position = at
	var mouse_up := mouse_down.duplicate()
	mouse_up.pressed = false
	var touch_up := touch_down.duplicate()
	touch_up.pressed = false
	board_scene._on_board_input(mouse_down)
	board_scene._on_board_input(touch_down)
	board_scene._on_board_input(mouse_up)
	board_scene._on_board_input(touch_up)

func _item_count(board_scene) -> int:
	var n := 0
	for r in G.ROWS:
		for c in G.COLS:
			if board_scene.board.item_at(Vector2i(r, c)) > 0:
				n += 1
	return n

func _code_count(board_scene, code: int) -> int:
	var n := 0
	for r in G.ROWS:
		for c in G.COLS:
			if board_scene.board.item_at(Vector2i(r, c)) == code:
				n += 1
	return n

func _first_tile_child_index(board_scene) -> int:
	var best := 1 << 20
	for nodes in [board_scene.piece_nodes, board_scene.gen_nodes]:
		for node in nodes.values():
			if node is Control and is_instance_valid(node) and node.get_parent() == board_scene.board_area:
				best = mini(best, node.get_index())
	return best

func _marker_intersects_playable_cells(board_scene, marker: Control) -> bool:
	var marker_rect := Rect2(marker.position, marker.size)
	var inner := Rect2(Vector2.ZERO, Vector2(board_scene._board_w(), board_scene._board_h())).grow(-8.0)
	return marker_rect.intersects(inner)
