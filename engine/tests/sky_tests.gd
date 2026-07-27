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

const MID_LEVEL := 12                          # a level where every lane on both axes is playable
const LANE_SWEEP_LEVELS := [1, 2, 6, 12, 40]   # early board → fully open board
# The share sweep needs enough hours for a hash-driven roll to settle. Measured convergence of the
# worst-off sky against its target: 5000 h is 1.04 points out, 10000 h is 0.70, 20000 h is 0.21 — so
# 20000 is the first length where a 1-point band is a real assertion rather than a coin flip.
const SHARE_SWEEP_HOURS := 20000
const SHARE_TOLERANCE := 1.0                   # percentage points

func save_prefix() -> String:
	return "tu_sky_"

func _sky():
	return load("res://engine/scripts/core/sky.gd")

## Open cells on a lane, counted straight from the unlock grid — deliberately NOT Sky's own helper,
## so the lane-roll assertions below check the roll against an independent count.
func _open_count(axis: String, lane: int, level: int) -> int:
	var n := 0
	if axis == "row":
		for c in int(G.COLS):
			if int(G.MIN_LEVEL[lane][c]) <= level:
				n += 1
	else:
		for r in int(G.ROWS):
			if int(G.MIN_LEVEL[r][lane]) <= level:
				n += 1
	return n

func _best_open(axis: String, level: int) -> int:
	var best := 0
	for i in (int(G.ROWS) if axis == "row" else int(G.COLS)):
		best = maxi(best, _open_count(axis, i, level))
	return best

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
	var sun: Dictionary = Sky.state(123.0, MID_LEVEL, "clear")
	ok(int(Sky.hour_index(0.0)) == 0 and int(Sky.hour_index(Tune.SECS_PER_HOUR * 3.9)) == 3, \
		"hour_index is floor(unix / SECS_PER_HOUR)")
	ok(String(sun.sky) == "sunbeam" and String(sun.skin) == "clear" and String(sun.lane_axis) == "column" \
		and int(sun.lane) >= 0 and int(sun.lane) < G.COLS, \
		"forcing clear produces Sunbeam, clear skin, and an in-range column lane")
	var breeze: Dictionary = Sky.state(123.0, MID_LEVEL, "breeze")
	ok(String(breeze.sky) == "sunbeam" and String(breeze.skin) == "breeze", \
		"forcing breeze produces Sunbeam with the breeze skin")
	var rain: Dictionary = Sky.state(123.0, MID_LEVEL, "rain")
	ok(String(rain.sky) == "rain" and String(rain.skin) == "rain" and String(rain.lane_axis) == "row" \
		and int(rain.lane) >= 0 and int(rain.lane) < G.ROWS, \
		"forcing rain produces Rain and an in-range row lane")
	var snow: Dictionary = Sky.state(123.0, MID_LEVEL, "snow")
	ok(String(snow.sky) == "rain" and String(snow.skin) == "snow", \
		"forcing snow produces Rain with the snow skin")
	var star: Dictionary = Sky.state(123.0, MID_LEVEL, "star")
	ok(String(star.sky) == "starfall" and String(star.skin) == "starlit" and String(star.lane_axis) == "column", \
		"forcing star produces Starfall with the starlit column lane")

	# --- Calm: a real sky that projects nothing ----------------------------------------
	var calm: Dictionary = Sky.state(123.0, MID_LEVEL, "calm")
	ok(String(calm.sky) == "calm" and String(calm.skin) == "clear", \
		"forcing calm produces the Calm sky wearing the pre-weather clear skin")
	ok(String(calm.lane_axis) == "" and int(calm.lane) == -1, \
		"a Calm state carries NO lane: lane_axis is empty and lane is -1")
	var calm_in_patch := false
	for r in int(G.ROWS):
		for c in int(G.COLS):
			if Sky.in_patch(calm, Vector2i(r, c)):
				calm_in_patch = true
	ok(not calm_in_patch, "in_patch is false for every cell on the board under a Calm sky")
	ok(not Sky.in_patch({"sky": "calm", "lane_axis": "column", "lane": 3}, Vector2i(0, 3)), \
		"in_patch rejects Calm by the SKY name, not by the lane sentinel — a stray lane cannot revive it")

	# --- share sweep: four skies, at their stated weights -------------------------------
	var found := {"calm": false, "sunbeam": false, "rain": false, "starfall": false, "breeze": false, "snow": false}
	var sky_counts := {}
	var skin_matches := true
	for h in range(0, SHARE_SWEEP_HOURS):
		var t := float(h) * Tune.SECS_PER_HOUR
		var st: Dictionary = Sky.state(t, MID_LEVEL)
		found[String(st.sky)] = true
		found[String(st.skin)] = true
		sky_counts[String(st.sky)] = int(sky_counts.get(String(st.sky), 0)) + 1
		if h < 500 and String(Sky.skin_at(t)) != String(st.skin):
			skin_matches = false
	ok(found.calm and found.sunbeam and found.rain and found.starfall and found.breeze and found.snow, \
		"auto weather reaches all FOUR skies and every legacy skin")
	var share_report: Array = []
	var share_worst := 0.0
	for sky_name in G.SKY_SHARES.keys():
		var want := float(G.SKY_SHARES[sky_name])
		var got := 100.0 * float(sky_counts.get(String(sky_name), 0)) / float(SHARE_SWEEP_HOURS)
		share_worst = maxf(share_worst, absf(got - want))
		share_report.append("%s %.2f/%d" % [sky_name, got, int(want)])
	ok(share_worst <= SHARE_TOLERANCE, \
		"observed shares land within %.1f point of SKY_SHARES over %d hours (%s; worst %.2f)" \
		% [SHARE_TOLERANCE, SHARE_SWEEP_HOURS, " · ".join(share_report), share_worst])
	ok(int(sky_counts.get("calm", 0)) > int(sky_counts.get("sunbeam", 0)) \
		and int(sky_counts.get("sunbeam", 0)) > int(sky_counts.get("rain", 0)) \
		and int(sky_counts.get("rain", 0)) > int(sky_counts.get("starfall", 0)), \
		"the walk follows SKY_SHARES order and weight — Calm is the commonest hour, Starfall the rarest")
	ok(skin_matches and String(Sky.skin_at(123.0, "snow")) == "snow", \
		"skin_at returns the hour's skin without a level — the level-free path Ambient.weather_now uses")

	# --- §3 lane roll: playable lanes only ---------------------------------------------
	var bar := int(G.LANE_MIN_OPEN)
	ok(int(Sky.lane_open_count("row", 4, 2)) == _open_count("row", 4, 2) \
		and int(Sky.lane_open_count("column", 3, 6)) == _open_count("column", 3, 6) \
		and int(Sky.lane_open_count("column", 0, 40)) == int(G.ROWS), \
		"lane_open_count counts a lane's cells against the static MIN_LEVEL unlock grid")
	var dead_lanes := 0
	var short_lanes := 0
	var fallback_hours := 0
	var fallback_bad := 0
	var lane_hours := 0
	var calm_hours := 0
	var calm_lane_bad := 0
	for level in LANE_SWEEP_LEVELS:
		for h in range(0, 480):
			var st: Dictionary = Sky.state(float(h) * Tune.SECS_PER_HOUR, level)
			# CALM CARRIES NO LANE, so it is excluded from the lane rule rather than counted as a
			# dead one — but it is checked HERE, in the same sweep, so the exclusion can never hide a
			# calm hour that quietly grew a lane.
			if String(st.sky) == "calm":
				calm_hours += 1
				if String(st.lane_axis) != "" or int(st.lane) != -1:
					calm_lane_bad += 1
				continue
			lane_hours += 1
			var axis := String(st.lane_axis)
			var lane := int(st.lane)
			var span := int(G.ROWS) if axis == "row" else int(G.COLS)
			if lane < 0 or lane >= span:
				dead_lanes += 1
				continue
			var open := _open_count(axis, lane, level)
			var best := _best_open(axis, level)
			if open <= 0:
				dead_lanes += 1
			if best >= bar:
				if open < bar:
					short_lanes += 1
			else:
				fallback_hours += 1
				if open != best:
					fallback_bad += 1
	ok(calm_hours > 0 and calm_lane_bad == 0, \
		"every Calm hour in the lane sweep reports the no-lane sentinel (%d calm hours, %d wrong)" \
		% [calm_hours, calm_lane_bad])
	ok(lane_hours > 0, "the lane sweep still covers the three lane-bearing skies (%d lane hours)" % lane_hours)
	ok(dead_lanes == 0, "no lane-bearing hour at any level lands a lane with zero open cells (%d dead)" % dead_lanes)
	ok(short_lanes == 0, \
		"every hour rolls a lane with >= LANE_MIN_OPEN open cells whenever any lane has that many (%d short)" % short_lanes)
	ok(fallback_hours > 0 and fallback_bad == 0, \
		"when no lane clears LANE_MIN_OPEN the roll falls back to a most-open lane (%d such hours, %d wrong)" \
		% [fallback_hours, fallback_bad])
	var rain_l1: Dictionary = Sky.state(123.0, 1, "rain")
	ok(_best_open("row", 1) < bar and _open_count("row", int(rain_l1.lane), 1) == _best_open("row", 1), \
		"level-1 Rain: no row clears the bar, so the fallback lands one of the most-open rows")

	var stable := true
	var moved := 0
	var stable_hours := 0
	for h in range(0, 480):
		var t := float(h) * Tune.SECS_PER_HOUR
		for level in LANE_SWEEP_LEVELS:
			var a: Dictionary = Sky.state(t, level)
			var b: Dictionary = Sky.state(t + Tune.SECS_PER_HOUR * 0.5, level)
			if int(a.lane) != int(b.lane) or String(a.sky) != String(b.sky):
				stable = false
		# Calm's lane is stably -1 at every level, so it belongs in the stability check but says nothing
		# about a level-up MOVING a lane — only the lane-bearing skies can move.
		if String(Sky.state(t, 12).sky) == "calm":
			continue
		stable_hours += 1
		if int(Sky.state(t, 1).lane) != int(Sky.state(t, 12).lane):
			moved += 1
	ok(stable, "the same (hour, level) always rolls the same lane — the lane holds for the whole hour")
	ok(moved > 0, "a level-up can move the lane, because openness is level-derived (%d of %d lane hours)" \
		% [moved, stable_hours])

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

	ok(is_equal_approx(float(G.STAR_CATCH_SECS), 30.0), "Starfall catch timeout is a 30s content constant")
	ok(Sky.grove_sky_state().get("owed", []) is Array and int(Sky.grove_sky_state().get("paid_hour", 0)) == -1 \
		and int(Sky.grove_sky_state().get("pending", -1)) == 0, \
		"grove sky save state defaults paid_hour, owed, and pending without a schema bump")
	var sky_blob: Dictionary = Save.grove().get("sky", {})
	sky_blob["paid_hour"] = 4
	sky_blob["owed"] = [108]
	sky_blob["pending"] = 209
	Save.grove()["sky"] = sky_blob
	ok(int(Sky.grove_sky_state().paid_hour) == 4 and Array(Sky.grove_sky_state().owed) == [108] \
		and int(Sky.grove_sky_state().pending) == 209, \
		"grove sky save state preserves paid_hour, owed queue, and pending catch code")

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
	for sky_name in ["calm", "sunbeam", "rain", "starfall"]:
		base_rng.seed = 75
		sky_rng.seed = 75
		_baseline_merge_stream(101, base_rng)
		logic.call("roll_merge_drops", 101, sky_rng, {"hour": 17, "sky": sky_name, "lane_axis": "column", "lane": 0}, true)
		ok(int(sky_rng.state) == int(base_rng.state), \
			"%s sky merge drops leave the board rng stream at the shipped merge-drop position" % sky_name)

	# --- Calm pays NOTHING: byte-identical to the no-sky baseline -----------------------
	# `roll_merge_drops` branches on the sky NAME, so calm should fall through to baseline on its own.
	# That is exactly why it is asserted rather than assumed: both the DROP LIST and the rng stream
	# POSITION are compared against the suite's no-sky helper, across seeds and produced codes, and
	# with in_patch forced BOTH ways — a calm hour has no patch, so even a caller wrongly claiming
	# in-patch must not shake a coin or a drop of water loose.
	var calm_state := {"hour": 17, "sky": "calm", "lane_axis": "", "lane": -1}
	var calm_drops_match := true
	var calm_stream_match := true
	var calm_bonus := false
	var calm_checked := 0
	for produced in [101, 205, 309, G.COIN_LINE * 100 + 1]:
		for seed in range(1, 60):
			for claimed_in_patch in [false, true]:
				base_rng.seed = seed
				sky_rng.seed = seed
				var want: Array = _baseline_merge_stream(produced, base_rng)
				var got: Array = logic.call("roll_merge_drops", produced, sky_rng, calm_state, claimed_in_patch)
				calm_checked += 1
				if got != want:
					calm_drops_match = false
				if int(sky_rng.state) != int(base_rng.state):
					calm_stream_match = false
				# The SKY coin is the one drop no baseline roll can mint: baseline coins are always c1,
				# and the special pool never draws from COIN_LINE. A t1 water special, by contrast, IS a
				# legitimate baseline special — so "calm shook no extra water loose" is proved by the
				# drop-list equality above, not by looking for a water code here.
				if got.has(G.COIN_LINE * 100 + int(G.SKY_COIN_TIER)):
					calm_bonus = true
	ok(calm_drops_match, "Calm merge drops are the baseline drop list, drop for drop (%d cases)" % calm_checked)
	ok(calm_stream_match, "Calm merge drops leave the board rng stream byte-identical to the baseline")
	ok(not calm_bonus, "no Calm merge ever mints the in-patch sky coin")

	if saved_weather_hours == null:
		Features.FLAGS.erase("weather_hours")
	else:
		Features.FLAGS["weather_hours"] = bool(saved_weather_hours)
	finish()
