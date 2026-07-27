extends RefCounted
## Pure Weather Hours logic: hourly sky state, patch membership, gated star rolls,
## and the small save-state shape. No scene nodes, no board RNG.

const G = preload("res://engine/scripts/core/content.gd")
const Save = preload("res://engine/scripts/core/save.gd")
const Features = preload("res://engine/scripts/core/features.gd")
const Tune = preload("res://engine/scripts/core/tuning.gd").Ambient

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

static func state(now: float, forced := "") -> Dictionary:
	var hour := hour_index(now)
	var sky := ""
	var skin := ""
	match forced:
		"clear":
			sky = SKY_SUNBEAM
			skin = SKIN_CLEAR
		"breeze":
			sky = SKY_SUNBEAM
			skin = SKIN_BREEZE
		"rain":
			sky = SKY_RAIN
			skin = SKIN_RAIN
		"snow":
			sky = SKY_RAIN
			skin = SKIN_SNOW
		"star":
			sky = SKY_STARFALL
			skin = SKIN_STARLIT
		_:
			var r := _roll(hour, 100)
			if r < int(G.SKY_SHARES.get(SKY_SUNBEAM, 45)):
				sky = SKY_SUNBEAM
				skin = _sun_skin(hour)
			elif r < int(G.SKY_SHARES.get(SKY_SUNBEAM, 45)) + int(G.SKY_SHARES.get(SKY_RAIN, 45)):
				sky = SKY_RAIN
				skin = _rain_skin(hour)
			else:
				sky = SKY_STARFALL
				skin = SKIN_STARLIT
	var axis := AXIS_ROW if sky == SKY_RAIN else AXIS_COLUMN
	var span := G.ROWS if axis == AXIS_ROW else G.COLS
	var lane := _roll(hour * 11 + _SALT_LANE, span)
	return {"hour": hour, "sky": sky, "skin": skin, "lane_axis": axis, "lane": lane}

static func in_patch(sky_state: Dictionary, cell: Vector2i) -> bool:
	var sky := String(sky_state.get("sky", ""))
	if sky == "":
		return false
	var axis := String(sky_state.get("lane_axis", AXIS_COLUMN))
	var lane := int(sky_state.get("lane", -1))
	if axis == AXIS_ROW:
		return cell.x == lane
	return cell.y == lane

static func gate_open() -> bool:
	return Features.on("weather_hours") and Save.ftue_seen("merge") and Save.ftue_seen("gen_tap")

static func grove_sky_state() -> Dictionary:
	var g := Save.grove()
	if not g.has("sky") or not (g.get("sky", {}) is Dictionary):
		g["sky"] = {}
	var sky: Dictionary = g["sky"]
	if not sky.has("paid_hour"):
		sky["paid_hour"] = -1
	if not (sky.get("owed", []) is Array):
		sky["owed"] = []
	return sky

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

static func _sun_skin(hour: int) -> String:
	var split: Dictionary = G.SKY_SKIN_SPLIT.get(SKY_SUNBEAM, {})
	return SKIN_CLEAR if _roll(hour * 7 + _SALT_SKIN, 100) < int(split.get(SKIN_CLEAR, 70)) else SKIN_BREEZE

static func _rain_skin(hour: int) -> String:
	var split: Dictionary = G.SKY_SKIN_SPLIT.get(SKY_RAIN, {})
	return SKIN_RAIN if _roll(hour * 7 + _SALT_SKIN, 100) < int(split.get(SKIN_RAIN, 85)) else SKIN_SNOW

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
