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
	await _test_landscape_weather_glyph_stays_in_powered_cell()
	await _test_starfall_start_tracks_landing_cell_in_landscape()
	await _test_starfall_scene_payment_and_modal_defer()
	await _test_starfall_pending_docks_before_catch()
	await _test_starfall_catch_real_tap_and_duplicate_input()
	await _test_starfall_ignores_non_catch_taps()
	await _test_starfall_fallbacks_and_resume_rules()
	await _test_starfall_landings_share_the_post_change_beat()
	await _test_starfall_full_lane_and_full_board()
	await _test_starfall_info_auto_announcement()
	await _test_winback_rain_beat_removed()
	_test_weather_debug_picker_labels()
	await _test_weather_picker_rearms_the_starfall_hour()
	_test_weather_debug_reset_releases_the_pin()
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
	ok(_sky_cell_glyphs(calm).is_empty(), "a Calm hour mounts no in-cell sky glyphs")
	var info := String(calm._info_label.text)
	ok(info.find("Calm") == -1 and info.find("Sunbeam") == -1 and info.find("Rain") == -1 and info.find("Starfall") == -1, \
		"a Calm hour leaves the info bar alone — no sky line is written (%s)" % info)
	calm._rebuild_all()
	await process_frame
	ok(calm.board_area.find_child("SkyPatch", true, false) == null \
		and calm.find_child("SkyMarker", true, false) == null \
		and _sky_cell_glyphs(calm).is_empty(), \
		"the Calm board stays chrome-free across _rebuild_all, which re-inserts patch and glyphs for other skies")
	calm.queue_free()

func _test_marker_patch_and_info_bar() -> void:
	var sun = await _open_board("sky_marker_sun", "clear")
	var sun_cell := _prepare_weather_focus_cell(sun)
	var patch := sun.board_area.find_child("SkyPatch", true, false) as Control
	ok(patch != null and patch.get_parent() == sun.board_area, "Sunbeam patch mounts inside board_area")
	ok(patch != null and patch.get_index() > 0, "Sunbeam patch is inserted after the board surface/slot block")
	ok(sun.find_child("SkyMarker", true, false) == null, "Sunbeam no longer mounts a side marker")
	_assert_all_powered_cells_have_sky_glyph(sun, "Sunbeam", "icon_sky_sun.png")
	if sun_cell.x >= 0:
		_tap_board_with_duplicate_events(sun, sun._cell_pos(sun_cell) + Vector2(sun.csz, sun.csz) / 2.0)
		await process_frame
		ok(sun._selected_cell == sun_cell \
			and String(sun._info_label.text).find("Sunbeam") != -1 \
			and String(sun._info_desc_label.text).find("drop coins") != -1, \
			"tapping the powered Sunbeam cell focuses it and explains the effect in the info bar")
		sun.board.place(sun_cell, 101)
		sun._clear_selection()
		sun._rebuild_all()
		await process_frame
		_tap_board_with_duplicate_events(sun, sun._cell_pos(sun_cell) + Vector2(sun.csz, sun.csz) / 2.0)
		await process_frame
		ok(sun._selected_cell == sun_cell \
			and String(sun._info_desc_label.text).find("Sunbeam") != -1 \
			and String(sun._info_desc_label.text).find("drop coins") != -1, \
			"focusing an item on a powered Sunbeam cell keeps the item focus and adds the weather explanation")
		# The regression: a focused EMPTY sky cell has no item/gen/soil, so the periodic water tick's
		# re-derivation used to fall through to _clear_selection() and defocus it ~0.7s after the tap.
		sun.board.place(sun_cell, 0)
		sun._clear_selection()
		sun._rebuild_all()
		await process_frame
		_tap_board_with_duplicate_events(sun, sun._cell_pos(sun_cell) + Vector2(sun.csz, sun.csz) / 2.0)
		await process_frame
		sun._tick_water()
		await process_frame
		ok(sun._selected_cell == sun_cell \
			and String(sun._info_label.text).find("Sunbeam") != -1, \
			"a focused empty Sunbeam cell survives the water tick instead of reverting to the empty info bar")
	sun._rebuild_all()
	await process_frame
	ok(sun.board_area.find_child("SkyPatch", true, false) != null \
		and sun.find_child("SkyMarker", true, false) == null \
		and _sky_cell_glyphs(sun).size() == _lane_cells(sun).size(), \
		"Sunbeam patch and all in-cell glyphs survive _rebuild_all")
	sun._landscape = not sun._landscape
	sun._rebuild_all()
	await process_frame
	ok(sun.board_area.find_child("SkyPatch", true, false) != null, "Sunbeam patch survives an orientation flip/reflow")
	_assert_all_powered_cells_have_sky_glyph(sun, "landscape Sunbeam", "icon_sky_sun.png")
	sun.queue_free()

	var rain = await _open_board("sky_marker_rain", "rain")
	var raw_rain_cell := _call_sky_icon_cell(rain)
	if raw_rain_cell.x >= 0 and not rain.board.is_open(raw_rain_cell):
		_tap_board_with_duplicate_events(rain, rain._cell_pos(raw_rain_cell) + Vector2(rain.csz, rain.csz) / 2.0)
		await process_frame
		ok(rain._selected_cell == raw_rain_cell \
			and String(rain._info_label.text).find("Rain") != -1 \
			and String(rain._info_desc_label.text).find("water") != -1, \
			"tapping a sealed powered Rain center cell focuses it and explains the weather before locked-cell info")
		rain._clear_selection()
	var rain_cell := _prepare_weather_focus_cell(rain)
	ok(rain.find_child("SkyMarker", true, false) == null, "Rain no longer mounts a side marker")
	_assert_all_powered_cells_have_sky_glyph(rain, "Rain", "icon_sky_rain.png")
	if rain_cell.x >= 0:
		_tap_board_with_duplicate_events(rain, rain._cell_pos(rain_cell) + Vector2(rain.csz, rain.csz) / 2.0)
		await process_frame
		ok(rain._selected_cell == rain_cell \
			and String(rain._info_label.text).find("Rain") != -1 \
			and String(rain._info_desc_label.text).find("water") != -1, \
			"tapping the powered Rain cell focuses it and explains the effect in the info bar")
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

func _test_landscape_weather_glyph_stays_in_powered_cell() -> void:
	var sun = await _open_board("sky_landscape_glyph", "clear")
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
		ok(sun.find_child("SkyMarker", true, false) == null \
			and _sky_cell_glyphs(sun).size() == _lane_cells(sun).size(), \
			"landscape %s weather glyphs cover every powered cell" % axis)
		_assert_all_powered_cells_have_sky_glyph(sun, "landscape %s" % axis, "icon_sky_sun.png")
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
	# §5.4's arrival beat lives in _sync_starfall_catch_ui's two flags and nowhere else — the roll routes
	# through them instead of re-implementing the flight and the announce inline. Both are observable: the
	# dock is held hidden behind a flying piece, then handed off when the flight lands.
	var docked := star.find_child("DockedStar", true, false) as Control
	ok(star.board_area.find_child("DockedStarFlight", true, false) != null and docked != null and not docked.visible, \
		"the roll flies the star in and holds the dock hidden until it arrives")
	for _i in 12:
		if docked != null and is_instance_valid(docked) and docked.visible:
			break
		await create_timer(0.1).timeout
	ok(docked != null and is_instance_valid(docked) and docked.visible, \
		"the arrival hands the star off to the docked piece once the flight lands")
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
	# Occupy one lane cell so the "occupied lane cell" tap has something to land on. _rebuild_all replaces
	# the marker node, so every handle the taps below need is read AFTER it.
	var occupied: Vector2i = lane_cells[0] if not lane_cells.is_empty() else Vector2i(-1, -1)
	if occupied.x >= 0:
		star.board.place(occupied, 101)
	star._rebuild_all()
	await process_frame
	var off_lane := _ensure_empty_off_lane_cell(star)
	var marker := star.find_child("SkyMarker", true, false) as Button
	# Without this guard the three asserts below pass VACUOUSLY on a degraded fixture: with no pending
	# star every "pending is unchanged" read is 0 == 0, and a missing cell just skips its tap entirely.
	ok(code > 0 and occupied.x >= 0 and off_lane.x >= 0 and marker != null, \
		"non-catch fixture has a pending star, an occupied lane cell, a free off-lane cell and a marker")
	if code <= 0 or occupied.x < 0 or off_lane.x < 0 or marker == null:
		star.queue_free()
		return
	_tap_board_with_duplicate_events(star, star._cell_pos(occupied) + Vector2(star.csz, star.csz) / 2.0)
	await process_frame
	ok(int(SkyLogic.grove_sky_state().get("pending", 0)) == code, "tapping an occupied lane cell leaves pending untouched")
	_tap_board_with_duplicate_events(star, star._cell_pos(off_lane) + Vector2(star.csz, star.csz) / 2.0)
	await process_frame
	ok(int(SkyLogic.grove_sky_state().get("pending", 0)) == code, "tapping an empty off-lane cell leaves pending untouched")
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
	# The uncaught landing flies a piece in and runs the same landing recipe the roll does, so it defers
	# for the same two reasons the roll does. Without this the 30 s timeout could drop a star mid-merge or
	# behind an open dialog. Deferring holds it pending; it lands on the tick after the board frees up.
	var veil := Control.new()
	veil.name = "TestModalOverlay"
	veil.z_index = Overlay.MODAL_Z
	timeout.add_child(veil)
	timeout._try_starfall()
	await process_frame
	ok(int(SkyLogic.grove_sky_state().get("pending", 0)) == timeout_code, \
		"an elapsed catch window holds the star pending while a modal covers the board")
	timeout.remove_child(veil)
	veil.queue_free()
	timeout.animating = true
	timeout._try_starfall()
	await process_frame
	ok(int(SkyLogic.grove_sky_state().get("pending", 0)) == timeout_code, \
		"an elapsed catch window holds the star pending while a board animation is running")
	timeout.animating = false
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
	# An ORDINARY persist must leave a live catch alone. It runs on a dozen mutation paths (every
	# _after_board_change, the water tick, the load fixups), so a resolve here would let any of them
	# silently eat the star the player is being invited to catch.
	leaving._persist()
	await process_frame
	ok(int(SkyLogic.grove_sky_state().get("pending", 0)) == leave_code \
		and Array(SkyLogic.grove_sky_state().get("owed", [])).is_empty(), \
		"an ordinary _persist leaves a live pending Starfall catchable")
	# The board-leave beat is the one that resolves — the same call both Map nav taps make, minus the
	# scene change a headless test cannot run.
	leaving._persist_leaving_board()
	await process_frame
	ok(int(SkyLogic.grove_sky_state().get("pending", 0)) == 0 \
		and Array(SkyLogic.grove_sky_state().get("owed", [])).has(leave_code), \
		"leaving the board converts pending Starfall into owed before saving")
	var board_src := FileAccess.get_file_as_string("res://engine/scripts/scenes/board.gd")
	ok(board_src.count("SceneWarm.go(") == 1 and board_src.count("_persist_leaving_board()") == 2, \
		"the board has exactly ONE exit and it goes through the leave beat, so a new nav tap cannot skip it")
	leaving.queue_free()
	var reopened = await _mount_board("star")
	await create_timer(0.35).timeout
	ok(_code_count(reopened, leave_code) == 1 and Array(SkyLogic.grove_sky_state().get("owed", [])).is_empty(), \
		"a fresh board open lands the owed Starfall from the saved handoff")
	reopened.queue_free()

## §5.5's catch and §5.6's uncaught landing put the SAME piece on the SAME board, so they owe the same
## post-mutation beat: magnet scans, the improvements reconcile, the owed-star drain, the persist and the
## HUD/fence refresh. The uncaught path used to only persist. Observed through the owed-star drain, which
## nothing but _after_board_change performs.
func _test_starfall_landings_share_the_post_change_beat() -> void:
	for caught in [true, false]:
		var how := "caught" if caught else "uncaught"
		var scn = await _open_board("sky_star_beat_%s" % how, "star")
		var lane_cells := _clear_lane_for_catch(scn)
		scn._rebuild_all()
		await process_frame
		var code := await _arm_pending_star(scn)
		var owed_code := 205
		SkyLogic.grove_sky_state()["owed"] = [owed_code]
		ok(code > 0 and code != owed_code and lane_cells.size() >= 2, \
			"%s fixture has a pending star, a distinct owed star and two free lane cells" % how)
		if lane_cells.size() >= 2 and code > 0:
			if caught:
				scn._catch_pending_star_at(lane_cells[0])
			else:
				scn._sky_live_secs = float(G.STAR_DELAY) + float(G.STAR_CATCH_SECS)
				scn._try_starfall()
			await create_timer(0.35).timeout
			ok(int(SkyLogic.grove_sky_state().get("pending", 0)) == 0 and _code_count(scn, code) == 1, \
				"the %s star lands on the board" % how)
			ok(Array(SkyLogic.grove_sky_state().get("owed", [])).is_empty() and _code_count(scn, owed_code) == 1, \
				"the %s landing drains the owed queue on the same post-change beat" % how)
		scn.queue_free()

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

# --- the debug weather picker -------------------------------------------------------------------
# Debug.on() is false headless, so the panel itself cannot be mounted here. These pin the pure halves
# the panel is assembled from — the label mapping, the sky read-out, and the re-arm — which is where
# every defect the picker can have actually lives.

## ONE TAP PER STATE means one CHIP per state, so every entry in the list has to carry a label the
## owner can tell from its neighbour: a blank chip (which "" would render as, being the auto state's
## own name) or a repeated one is an option you cannot aim at. Derived labels, not a parallel table —
## the assertion walks WEATHER_DEBUG_STATES itself so a new sky is covered the day it is added.
func _test_weather_debug_picker_labels() -> void:
	Ambient.reset_weather_debug_for_test()
	var states: Array = Ambient.WEATHER_DEBUG_STATES
	ok(states.has("") and states.has("calm") and states.has("star"), \
		"the debug state list still covers auto, the Calm no-weather sky and Starfall (%s)" % str(states))
	# Both sentinels are INDEXES, not label text: "" is itself one of the states, so a sentinel of ""
	# would compare equal to the very failure it is meant to report and the assert would pass blind.
	var labels: Array = []
	var blank := -1
	var dupe := -1
	for i in states.size():
		var chip := Ambient.weather_debug_chip(String(states[i]))
		if chip.strip_edges() == "" and blank < 0:
			blank = i
		if labels.has(chip) and dupe < 0:
			dupe = i
		labels.append(chip)
	ok(blank < 0, "every debug state gets a non-blank chip label (state %d came back empty, got %s)" % [blank, str(labels)])
	ok(dupe < 0, "no two chips share a label, so every state is aimable (state %d repeats, got %s)" % [dupe, str(labels)])
	ok(Ambient.weather_debug_chip("") == "Auto", \
		"the empty state reads as Auto — it is the live hourly roll, not a blank chip")
	ok(Ambient.weather_debug_chip("star") == "Star" and Ambient.weather_debug_chip("calm") == "Calm", \
		"a state's chip is its own name, so no label can claim a sky the state does not force")
	# The read-out is the only place the panel can admit that seven state names are FOUR skies.
	var now := Time.get_unix_time_from_system()
	ok(SkyLogic.sky_at(now, "clear") == SkyLogic.SKY_SUNBEAM and SkyLogic.sky_at(now, "breeze") == SkyLogic.SKY_SUNBEAM, \
		"clear and breeze are two skins of ONE sky, Sunbeam")
	ok(SkyLogic.sky_at(now, "rain") == SkyLogic.SKY_RAIN and SkyLogic.sky_at(now, "snow") == SkyLogic.SKY_RAIN, \
		"rain and snow are two skins of ONE sky, Rain")
	ok(SkyLogic.sky_at(now, "star") == SkyLogic.SKY_STARFALL and SkyLogic.sky_at(now, "calm") == SkyLogic.SKY_CALM, \
		"star and calm each force their own sky")
	ok(SkyLogic.sky_at(now, "") == SkyLogic.state(now, 1, "").sky, \
		"the level-free sky read-out agrees with the full hourly state — one roll, read two ways")
	Ambient.forced_weather = "breeze"
	var forced_line := Ambient.weather_debug_label()
	ok(forced_line.find("breeze") != -1 and forced_line.find("Sunbeam") != -1, \
		"the picker read-out names the forced state AND the sky it rolls (%s)" % forced_line)
	Ambient.reset_weather_debug_for_test()
	ok(Ambient.weather_debug_label().find("auto") != -1, \
		"with nothing forced the read-out reads auto (%s)" % Ambient.weather_debug_label())

## THE RE-ARM — the reason a one-tap "Star" is worth anything. `sky.paid_hour` is stamped with the REAL
## clock hour, and forcing a weather never moves the real clock, so without clearing that stamp the
## second Star tap inside one wall-clock hour draws the starlit sky, the lane and the marker and then
## pays nothing, for up to an hour. Two stars in ONE hour is the whole assertion. Driven through the
## picker's own path (set_debug_weather → the host's debug_refresh_weather), in that order.
func _test_weather_picker_rearms_the_starfall_hour() -> void:
	var star = await _open_board("sky_star_rearm", "star")
	_clear_lane_for_catch(star)
	star._rebuild_all()
	await process_frame
	var first := await _arm_pending_star(star)
	var hour := int(star._sky_state.hour)
	ok(first > 0, "the first forced Starfall pays a star")
	ok(int(SkyLogic.grove_sky_state().paid_hour) == hour, "…and stamps paid_hour with the real clock hour")
	Ambient.set_debug_weather("star")
	star.debug_refresh_weather()
	await process_frame
	ok(int(SkyLogic.grove_sky_state().get("paid_hour", 0)) == -1, \
		"picking a weather re-arms the hour — paid_hour is cleared, so the roll can pay again")
	ok(int(star._sky_state.hour) == hour, \
		"…and it is still the SAME real clock hour, which is exactly why the stamp had to go")
	# The star that was already docked is NOT lost: board.gd's reconcile queues it as owed, and owed
	# stars land on the next board change. That is the existing contract for any sky change mid-dock.
	ok(Array(SkyLogic.grove_sky_state().get("owed", [])).has(first), \
		"the star docked when the pick landed is queued as OWED rather than dropped")
	# `between` is what makes the next assertion mean anything: WITHOUT the re-arm the first star is
	# still sitting on the marker, so reading `pending` after a second attempt hands back the SAME code
	# and a bare `> 0` passes having rolled nothing. An empty dock before, a star after.
	var between := int(SkyLogic.grove_sky_state().get("pending", 0))
	var second := await _arm_pending_star(star)
	ok(between == 0 and second > 0 and int(SkyLogic.grove_sky_state().paid_hour) == hour, \
		"a SECOND Starfall rolls onto an empty dock and re-stamps the same real hour — the option repeats (dock %d → %d)" \
		% [between, second])
	star.queue_free()

## Every other suite inherits whatever this one leaves in the process-global `forced_weather`, so the
## reset has to actually hand the hour back to the live roll — not merely blank a label.
func _test_weather_debug_reset_releases_the_pin() -> void:
	Ambient.forced_weather = "snow"
	ok(Ambient.weather_now() == SkyLogic.SKIN_SNOW, "a pinned state really does override the hourly roll")
	Ambient.reset_weather_debug_for_test()
	ok(Ambient.forced_weather == "", "reset clears the pin")
	ok(Ambient.weather_now() == SkyLogic.skin_at(Time.get_unix_time_from_system()), \
		"…and the weather layer is back on the live hourly roll for every suite after this one")

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

func _ensure_empty_off_lane_cell(board_scene) -> Vector2i:
	var found := _empty_off_lane_cell(board_scene)
	if found.x >= 0:
		return found
	for r in G.ROWS:
		for c in G.COLS:
			var cell := Vector2i(r, c)
			if SkyLogic.in_patch(board_scene._sky_state, cell) or board_scene.board.is_gen(cell):
				continue
			board_scene.board.terrain[BoardModel.idx(cell)] = 0
			board_scene.board.place(cell, 0)
			return cell
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

func _sky_cell_glyphs(board_scene) -> Array:
	if board_scene.board_area == null or not is_instance_valid(board_scene.board_area):
		return []
	return board_scene.board_area.find_children("SkyCellGlyph*", "TextureRect", true, false)

func _assert_all_powered_cells_have_sky_glyph(board_scene, label: String, icon_file: String) -> void:
	var expected := _lane_cells(board_scene)
	var glyphs := _sky_cell_glyphs(board_scene)
	ok(glyphs.size() == expected.size(), \
		"%s mounts one faint weather icon on every affected lane cell (%d glyphs for %d cells)" \
		% [label, glyphs.size(), expected.size()])
	var seen := {}
	for raw_glyph in glyphs:
		var glyph := raw_glyph as TextureRect
		if glyph == null:
			continue
		var cell := Vector2i(glyph.get_meta("cell", Vector2i(-1, -1)))
		seen[cell] = true
		ok(_sky_cell_glyph_matches(board_scene, glyph, cell), \
			"%s glyph for %s is centered over its powered cell" % [label, str(cell)])
		ok(String(glyph.get_meta("icon_path", "")).find(icon_file) != -1, \
			"%s glyph for %s is wired to %s" % [label, str(cell), icon_file])
		ok(glyph.mouse_filter == Control.MOUSE_FILTER_IGNORE and glyph.modulate.a <= 0.34, \
			"%s glyph for %s is faint and does not intercept board taps" % [label, str(cell)])
	for raw_cell in expected:
		var cell := Vector2i(raw_cell)
		ok(seen.has(cell), "%s has a weather icon on affected cell %s" % [label, str(cell)])

func _sky_cell_glyph_matches(board_scene, glyph: TextureRect, cell: Vector2i) -> bool:
	if glyph == null or cell.x < 0:
		return false
	var meta_cell := Vector2i(glyph.get_meta("cell", Vector2i(-1, -1)))
	var expected: Vector2 = board_scene._cell_pos(cell) + Vector2(float(board_scene.csz), float(board_scene.csz)) * 0.5
	var ok_match: bool = glyph.get_parent() == board_scene.board_area \
		and meta_cell == cell \
		and glyph.get_rect().get_center().distance_to(expected) <= 2.0
	return ok_match

# _call_sky_icon_cell / _prepare_weather_focus_cell now live in grove_test_base.gd — the improvements
# suite's selection-kind sweep needs the same powered-cell setup.
