extends RefCounted
## Pure Weather Hours logic: hourly sky state, patch membership, gated star rolls,
## and the small save-state shape. No scene nodes, no board RNG.

const G = preload("res://engine/scripts/core/content.gd")
const Save = preload("res://engine/scripts/core/save.gd")
const FeatureGate = preload("res://engine/scripts/core/feature_gate.gd")
const Tune = preload("res://engine/scripts/core/tuning.gd").Ambient

const SKY_CALM := "calm"
const SKY_SUNBEAM := "sunbeam"
const SKY_RAIN := "rain"
const SKY_STARFALL := "starfall"
const AXIS_COLUMN := "column"
const AXIS_ROW := "row"
const SKIN_CLEAR := "clear"
const SKIN_BREEZE := "breeze"
const SKIN_RAIN := "rain"
const SKIN_SNOW := "snow"
const SKIN_STARLIT := "starlit"

const _SALT_SKIN := 73471
const _SALT_LANE := 91517
const _SALT_STAR_LINE := 43133
const _SALT_STAR_TIER := 76157

static func hour_index(now: float) -> int:
	return int(floor(now / Tune.SECS_PER_HOUR))

## The hour's full sky. `level` is the player's Level: the §3 lane roll only considers lanes the
## player has actually unlocked, so every caller (board, sim, tests) passes its real level.
static func state(now: float, level: int, forced := "") -> Dictionary:
	var hour := hour_index(now)
	var look := _look(hour, forced)
	var sky := String(look.sky)
	# CALM HAS NO LANE (§2). "" / -1 is the whole mechanism: in_patch is false for every cell, so no
	# gift path can fire and no caller needs a calm special case. The playable-lane search is skipped
	# outright rather than rolled and discarded — it walks the entire MIN_LEVEL grid for a lane that
	# nothing on a calm hour will ever read.
	if sky == SKY_CALM:
		return {"hour": hour, "sky": sky, "skin": String(look.skin), "lane_axis": "", "lane": -1}
	var axis := AXIS_ROW if sky == SKY_RAIN else AXIS_COLUMN
	return {"hour": hour, "sky": sky, "skin": String(look.skin), "lane_axis": axis, "lane": _pick_lane(hour, axis, level)}

## The hour's cosmetic skin alone. The skin depends only on the hour, never on the lane — so the
## screen-wide weather layer (board, map, shot tools) reads it without inventing a level.
static func skin_at(now: float, forced := "") -> String:
	return String(_look(hour_index(now), forced).skin)

## The hour's SKY alone — the other half of the level-free look, and skin_at's twin. The debug weather
## picker reads it to say which sky a forced SKIN belongs to: "clear" and "breeze" are two skins of ONE
## sky (Sunbeam) and "rain"/"snow" of another (Rain), which the skin names by themselves do not admit.
static func sky_at(now: float, forced := "") -> String:
	return String(_look(hour_index(now), forced).sky)

## Cells of one lane the player has unlocked, read from the STATIC MIN_LEVEL grid — never from live
## board occupancy, so the lane holds for the whole hour and board, sim and tests agree.
static func lane_open_count(axis: String, lane: int, level: int) -> int:
	var n := 0
	if axis == AXIS_ROW:
		for c in int(G.COLS):
			if G.cell_min_level(Vector2i(lane, c)) <= level:
				n += 1
	else:
		for r in int(G.ROWS):
			if G.cell_min_level(Vector2i(r, lane)) <= level:
				n += 1
	return n

static func in_patch(sky_state: Dictionary, cell: Vector2i) -> bool:
	var sky := String(sky_state.get("sky", ""))
	# Two different "no patch" cases, both named OUTRIGHT rather than left to fall out of a lane miss:
	# "" is "no sky state yet" (a scene before its first roll), and CALM is a real sky that simply
	# projects nothing. Leaning on lane == -1 alone would hand a calm hour a patch the day someone
	# changes the lane default, so the sky itself is the gate; the lane check below is the backstop.
	if sky == "" or sky == SKY_CALM:
		return false
	var axis := String(sky_state.get("lane_axis", AXIS_COLUMN))
	var lane := int(sky_state.get("lane", -1))
	if lane < 0:
		return false
	if axis == AXIS_ROW:
		return cell.x == lane
	return cell.y == lane

static func gate_open() -> bool:
	return FeatureGate.armed("weather")

static func grove_sky_state() -> Dictionary:
	var g := Save.grove()
	if not g.has("sky") or not (g.get("sky", {}) is Dictionary):
		g["sky"] = {}
	var sky: Dictionary = g["sky"]
	if not sky.has("paid_hour"):
		sky["paid_hour"] = -1
	if not (sky.get("owed", []) is Array):
		sky["owed"] = []
	if not sky.has("pending"):
		sky["pending"] = 0
	return sky

## DEBUG RE-ARM: drop this hour's Starfall payment stamp so the roll can pay again.
## `paid_hour` is keyed to the REAL clock hour (hour_index), and FORCING a weather state does not move
## the real clock — so without this the second forced Starfall inside one wall-clock hour draws the
## starlit sky, the lane and the marker and then never pays a star (board.gd `_try_starfall` returns
## on `hour <= paid_hour`), for up to an hour. That is precisely the flow — the catch window, the lit
## lane, the timeout fallback — that a debug option exists to exercise repeatedly.
static func rearm_star_hour() -> void:
	grove_sky_state()["paid_hour"] = -1
	Save.grove_write()

static func star_pick(hour: int, active_lines: Array, asked: Array) -> int:
	var lines := _content_lines(active_lines)
	if lines.is_empty():
		return 0
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed(hour, _SALT_STAR_LINE)
	var high_lines: Array = []
	for line in lines:
		if not _tier_choices(int(line), asked).is_empty():
			high_lines.append(int(line))
	if not high_lines.is_empty():
		var line := int(high_lines[rng.randi_range(0, high_lines.size() - 1)])
		var tier := _weighted_tier(hour, line, _tier_choices(line, asked))
		return line * 100 + tier
	for tier in range(7, 0, -1):
		var tier_lines: Array = []
		for line in lines:
			var code := int(line) * 100 + tier
			if not asked.has(code):
				tier_lines.append(int(line))
		if not tier_lines.is_empty():
			var pick := int(tier_lines[rng.randi_range(0, tier_lines.size() - 1)])
			return pick * 100 + tier
	return 0

## Sky + skin for the hour (or the forced debug state). Level-free by construction.
static func _look(hour: int, forced: String) -> Dictionary:
	match forced:
		"calm":
			return {"sky": SKY_CALM, "skin": SKIN_CLEAR}
		"clear":
			return {"sky": SKY_SUNBEAM, "skin": SKIN_CLEAR}
		"breeze":
			return {"sky": SKY_SUNBEAM, "skin": SKIN_BREEZE}
		"rain":
			return {"sky": SKY_RAIN, "skin": SKIN_RAIN}
		"snow":
			return {"sky": SKY_RAIN, "skin": SKIN_SNOW}
		"star":
			return {"sky": SKY_STARFALL, "skin": SKIN_STARLIT}
	var sky := _walk_shares(G.SKY_SHARES, hour, SKY_CALM)
	return {"sky": sky, "skin": _skin(hour, sky)}

## The hour's skin, walked out of SKY_SKIN_SPLIT the same way the sky itself is. A sky with no split
## entry (Starfall) wears its single skin — the starlit look IS that sky, so there is nothing to roll.
static func _skin(hour: int, sky: String) -> String:
	var split: Dictionary = G.SKY_SKIN_SPLIT.get(sky, {})
	if split.is_empty():
		return SKIN_STARLIT
	return _walk_shares(split, hour * 7 + _SALT_SKIN, SKIN_CLEAR)

## ONE cumulative walk for every weighted-share table, so adding or reweighting a sky is a data edit
## and never a code edit. Two properties this walk must keep:
##   • DETERMINISTIC — GDScript Dictionaries iterate in INSERTION order, which is stable for a const
##     literal, so the same table always assigns the same hour the same outcome. Re-ordering the table
##     re-maps the hours on purpose; changing a share re-maps every hour past that threshold.
##   • TOTAL-DRIVEN — the roll is taken modulo the table's own total, not a hardcoded 100, so shares
##     that do not add to 100 still divide the hours in exactly their stated proportion.
## Negative shares are clamped to 0; an empty or all-zero table yields `fallback`.
static func _walk_shares(shares: Dictionary, seed_value: int, fallback: String) -> String:
	var total := 0
	for key in shares:
		total += maxi(0, int(shares[key]))
	if total <= 0:
		return fallback
	var r := _roll(seed_value, total)
	var acc := 0
	var last := fallback
	for key in shares:
		var share := maxi(0, int(shares[key]))
		if share <= 0:
			continue
		acc += share
		last = String(key)
		if r < acc:
			return String(key)
	return last     # unreachable while r < total, but a share table is data — never trust it to sum

## §3 PLAYABLE LANES ONLY. The salted hour roll picks uniformly among the lanes holding at least
## `G.LANE_MIN_OPEN` open cells at this level, not over the whole axis — a uniform roll parks 36% of
## level-2 hours on a lane with nothing to merge on. When no lane clears the bar (very early boards)
## the bar drops to the most-open count, so the pool is the most-open lanes and the same salted roll
## breaks the tie: the sky always projects somewhere.
static func _pick_lane(hour: int, axis: String, level: int) -> int:
	var span := int(G.ROWS) if axis == AXIS_ROW else int(G.COLS)
	var counts: Array[int] = []
	var best := 0
	for i in span:
		counts.append(lane_open_count(axis, i, level))
		best = maxi(best, counts[i])
	var bar := mini(int(G.LANE_MIN_OPEN), best)
	var pool: Array[int] = []
	for i in span:
		if counts[i] >= bar:
			pool.append(i)
	return int(pool[_roll(hour * 11 + _SALT_LANE, pool.size())])

static func _content_lines(active_lines: Array) -> Array:
	var out: Array = []
	for line in active_lines:
		var li := int(line)
		if li > 0 and G.LINES.has(li) and not out.has(li):
			out.append(li)
	return out

static func _tier_choices(line: int, asked: Array) -> Array:
	var out: Array = []
	for tier in G.STAR_TIER_WEIGHTS.keys():
		var t := int(tier)
		if t >= 1 and t <= int(G.TOP_TIER) and not asked.has(line * 100 + t):
			out.append(t)
	out.sort()
	return out

static func _weighted_tier(hour: int, line: int, tiers: Array) -> int:
	var total := 0
	for t in tiers:
		total += int(G.STAR_TIER_WEIGHTS.get(int(t), 1))
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed(hour * 97 + line, _SALT_STAR_TIER)
	var r := rng.randi_range(1, maxi(1, total))
	for t in tiers:
		r -= int(G.STAR_TIER_WEIGHTS.get(int(t), 1))
		if r <= 0:
			return int(t)
	return int(tiers[0]) if not tiers.is_empty() else 0

static func _roll(seed_value: int, mod: int) -> int:
	return absi(hash(seed_value)) % maxi(1, mod)

static func _seed(hour: int, salt: int) -> int:
	return int(absi(hash(hour * 1103515245 + salt)))
