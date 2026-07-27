extends "res://games/grove/tests/grove_test_base.gd"
## Grove Weather Hours scene coverage: marker/patch geometry, info-bar tap, Starfall
## scene payment/defer, and deletion of the old win-back rain beat.
##   godot --headless --path . -s res://games/grove/tests/grove_sky_tests.gd

const Ambient = preload("res://engine/scripts/ui/ambient.gd")
const SkyLogic = preload("res://engine/scripts/core/sky.gd")
const Overlay = preload("res://engine/scripts/ui/overlay.gd")
const SkyPatch = preload("res://engine/scripts/ui/sky_patch.gd")

func _initialize() -> void:
	begin("grove · weather hours")
	await process_frame
	await _test_patch_edges_read_stronger_than_centers()
	await _test_marker_patch_and_info_bar()
	await _test_starfall_scene_payment_and_modal_defer()
	await _test_winback_rain_beat_removed()
	Ambient.reset_weather_debug_for_test()
	finish()

func _open_board(name: String, forced_weather: String):
	fresh(name)
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
	ok(_item_count(landed) > before_land, "forced Starfall lands a real model piece")
	ok(int(SkyLogic.grove_sky_state().paid_hour) == int(landed._sky_state.hour), "Starfall stamps paid_hour when it rolls")
	landed.queue_free()

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

func _item_count(board_scene) -> int:
	var n := 0
	for r in G.ROWS:
		for c in G.COLS:
			if board_scene.board.item_at(Vector2i(r, c)) > 0:
				n += 1
	return n
