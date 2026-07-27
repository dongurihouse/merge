extends "res://engine/tests/test_base.gd"
## Headless tests for weather-hours pure contracts: hourly sky state, patch membership,
## quest ask avoidance, owed persistence shape, and merge-drop rolls.
##   godot --headless --path . -s res://engine/tests/sky_tests.gd

const G = preload("res://engine/scripts/core/content.gd")
const Save = preload("res://engine/scripts/core/save.gd")
const BoardLogic = preload("res://engine/scripts/core/board_logic.gd")
const BoardModel = preload("res://engine/scripts/core/board_model.gd")
const Features = preload("res://engine/scripts/core/features.gd")
const Tune = preload("res://engine/scripts/core/tuning.gd").Ambient

func save_prefix() -> String:
	return "tu_sky_"

func _sky():
	return load("res://engine/scripts/core/sky.gd")

func _state_with_sky(Sky: GDScript, target: String) -> Dictionary:
	for h in range(0, 240):
		var st: Dictionary = Sky.state(float(h) * Tune.SECS_PER_HOUR)
		if String(st.sky) == target:
			return st
	return {}

func _state_with_skin(Sky: GDScript, target: String) -> Dictionary:
	for h in range(0, 240):
		var st: Dictionary = Sky.state(float(h) * Tune.SECS_PER_HOUR)
		if String(st.skin) == target:
			return st
	return {}

func _baseline_merge_stream(produced: int, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	if BoardLogic.rolls_coin_drop(produced, rng):
		out.append(G.COIN_LINE * 100 + 1)
	if not G.is_special(produced) and G.rolls_special_drop(rng):
		out.append(G.pick_special_drop(rng))
	return out

func _initialize() -> void:
	var Sky: GDScript = _sky()
	ok(Sky != null, "Sky pure module exists")
	if Sky == null:
		finish()
		return

	var saved_weather_hours = Features.FLAGS.get("weather_hours", null)
	Features.FLAGS["weather_hours"] = true
	fresh("gate")
	var sun: Dictionary = Sky.state(123.0, "clear")
	ok(int(Sky.hour_index(0.0)) == 0 and int(Sky.hour_index(Tune.SECS_PER_HOUR * 3.9)) == 3, \
		"hour_index is floor(unix / SECS_PER_HOUR)")
	ok(String(sun.sky) == "sunbeam" and String(sun.skin) == "clear" and String(sun.lane_axis) == "column" \
		and int(sun.lane) >= 0 and int(sun.lane) < G.COLS, \
		"forcing clear produces Sunbeam, clear skin, and an in-range column lane")
	var breeze: Dictionary = Sky.state(123.0, "breeze")
	ok(String(breeze.sky) == "sunbeam" and String(breeze.skin) == "breeze", \
		"forcing breeze produces Sunbeam with the breeze skin")
	var rain: Dictionary = Sky.state(123.0, "rain")
	ok(String(rain.sky) == "rain" and String(rain.skin) == "rain" and String(rain.lane_axis) == "row" \
		and int(rain.lane) >= 0 and int(rain.lane) < G.ROWS, \
		"forcing rain produces Rain and an in-range row lane")
	var snow: Dictionary = Sky.state(123.0, "snow")
	ok(String(snow.sky) == "rain" and String(snow.skin) == "snow", \
		"forcing snow produces Rain with the snow skin")
	var star: Dictionary = Sky.state(123.0, "star")
	ok(String(star.sky) == "starfall" and String(star.skin) == "starlit" and String(star.lane_axis) == "column", \
		"forcing star produces Starfall with the starlit column lane")

	var found := {"sunbeam": false, "rain": false, "starfall": false, "breeze": false, "snow": false}
	for h in range(0, 500):
		var st: Dictionary = Sky.state(float(h) * Tune.SECS_PER_HOUR)
		found[String(st.sky)] = true
		found[String(st.skin)] = true
	ok(found.sunbeam and found.rain and found.starfall and found.breeze and found.snow, \
		"auto weather reaches all three skies and the legacy skins")

	var patch_col := {"sky": "sunbeam", "lane_axis": "column", "lane": 2}
	ok(Sky.in_patch(patch_col, Vector2i(0, 2)) and Sky.in_patch(patch_col, Vector2i(8, 2)) \
		and not Sky.in_patch(patch_col, Vector2i(3, 1)), \
		"column patch covers all rows in exactly one model column")
	var patch_row := {"sky": "rain", "lane_axis": "row", "lane": 4}
	ok(Sky.in_patch(patch_row, Vector2i(4, 0)) and Sky.in_patch(patch_row, Vector2i(4, 6)) \
		and not Sky.in_patch(patch_row, Vector2i(3, 6)), \
		"row patch covers all columns in exactly one model row")

	ok(not Sky.gate_open(), "weather-hours gate is shut before both FTUE verbs are seen")
	Save.mark_ftue_seen("merge")
	ok(not Sky.gate_open(), "weather-hours gate is still shut after only merge FTUE")
	Save.mark_ftue_seen("gen_tap")
	ok(Sky.gate_open(), "weather-hours gate opens after merge and gen_tap FTUE with the feature flag on")
	Features.FLAGS["weather_hours"] = false
	ok(not Sky.gate_open(), "weather-hours feature flag can shut the gift gate")
	Features.FLAGS["weather_hours"] = true

	ok(Sky.grove_sky_state().get("owed", []) is Array and int(Sky.grove_sky_state().get("paid_hour", 0)) == -1, \
		"grove sky save state defaults paid_hour and owed without a schema bump")
	var sky_blob: Dictionary = Save.grove().get("sky", {})
	sky_blob["paid_hour"] = 4
	sky_blob["owed"] = [108]
	Save.grove()["sky"] = sky_blob
	ok(int(Sky.grove_sky_state().paid_hour) == 4 and Array(Sky.grove_sky_state().owed) == [108], \
		"grove sky save state preserves paid_hour and owed queue")

	var logic := BoardLogic.new()
	var asked: Array = logic.call("asked_items", [{"line": 1, "tier": 8}, {"line": 5, "tier": 9}, {"reward": {"coins": 1}}])
	ok(asked.has(108) and asked.has(509) and asked.size() == 2, "asked_items returns live quest item codes only")
	var picked: int = Sky.star_pick(41, [1], [108, 109, 110])
	ok(picked == 107, "star_pick steps down when every high-tier candidate for a line is live-asked")
	var no_pick: int = Sky.star_pick(41, [], [])
	ok(no_pick == 0, "star_pick returns 0 when no content lines are available")
	var skip_live := true
	for h in range(0, 40):
		var p: int = Sky.star_pick(h, [1, 2], [108, 209])
		if p == 108 or p == 209:
			skip_live = false
	ok(skip_live, "star_pick never returns a pair currently live-asked")

	var rng := RandomNumberGenerator.new()
	rng.seed = 22
	var baseline: Array = logic.call("roll_merge_drops", 101, rng, {"sky": "sunbeam", "lane_axis": "column", "lane": 0}, false)
	rng.seed = 22
	var offpatch_coin := BoardLogic.rolls_coin_drop(101, rng)
	ok((baseline.has(G.COIN_LINE * 100 + 1)) == offpatch_coin, \
		"off-patch roll_merge_drops keeps the shipped c1 coin roll")
	var sun_hit := false
	var rain_hit := false
	for seed in range(1, 80):
		rng.seed = seed
		var sun_drops: Array = logic.call("roll_merge_drops", 101, rng, {"hour": 17, "sky": "sunbeam", "lane_axis": "column", "lane": 0}, true)
		sun_hit = sun_hit or sun_drops.has(G.COIN_LINE * 100 + int(G.SKY_COIN_TIER))
		rng.seed = seed
		var rain_drops: Array = logic.call("roll_merge_drops", 101, rng, {"hour": 17, "sky": "rain", "lane_axis": "row", "lane": 0}, true)
		rain_hit = rain_hit or rain_drops.has(12 * 100 + 1)
	ok(sun_hit, "Sunbeam in-patch can replace the baseline coin with one c2 coin")
	ok(rain_hit, "Rain in-patch can add an independent t1 water special")
	rng.seed = 1
	var star_drops: Array = logic.call("roll_merge_drops", 101, rng, {"sky": "starfall", "lane_axis": "column", "lane": 0}, true)
	ok(not star_drops.has(12 * 100 + 1) and not star_drops.has(G.COIN_LINE * 100 + 2), \
		"Starfall merge drops do not add sky bonuses")
	var base_rng := RandomNumberGenerator.new()
	var sky_rng := RandomNumberGenerator.new()
	for sky_name in ["sunbeam", "rain", "starfall"]:
		base_rng.seed = 75
		sky_rng.seed = 75
		_baseline_merge_stream(101, base_rng)
		logic.call("roll_merge_drops", 101, sky_rng, {"hour": 17, "sky": sky_name, "lane_axis": "column", "lane": 0}, true)
		ok(int(sky_rng.state) == int(base_rng.state), \
			"%s sky merge drops leave the board rng stream at the shipped merge-drop position" % sky_name)

	if saved_weather_hours == null:
		Features.FLAGS.erase("weather_hours")
	else:
		Features.FLAGS["weather_hours"] = bool(saved_weather_hours)
	finish()
