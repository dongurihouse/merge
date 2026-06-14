extends RefCounted
## Content ENGINE (theme-agnostic). The DATA lives in the active game
## (games/<name>/*_data.gd, reached via Game.data()); this file is the generic
## logic that operates on it — bramble field, quest generation, progression,
## economy formulas — plus a re-export of the data so callers keep using G.X.
## (Was grove_content.gd; the grove tables moved to games/grove/grove_data.gd.)

const Game = preload("res://engine/scripts/game.gd")

# --- the ACTIVE game's DATA (compile-time const), re-exported as consts so every
# --- existing G.<CONST> reader keeps working and := type inference still resolves.
const D = Game.DATA
const COLS = D.COLS
const ROWS = D.ROWS
const TOP_TIER = D.TOP_TIER
const LINES = D.LINES
const GENERATORS = D.GENERATORS
const GEN_CELL = D.GEN_CELL
const TIER_ODDS = D.TIER_ODDS
const ASK_WEIGHT = D.ASK_WEIGHT
const STARTER_ITEMS = D.STARTER_ITEMS
const ZONE_RAMP = D.ZONE_RAMP
const WAYSIDE_PROPS = D.WAYSIDE_PROPS
const WAYSIDE_TEX = D.WAYSIDE_TEX
const WAYSIDE_PER_ZONE = D.WAYSIDE_PER_ZONE
const VARIANT_NAMES_COIN = D.VARIANT_NAMES_COIN
const VARIANT_NAMES_GEM = D.VARIANT_NAMES_GEM
const VARIANT_TINTS_COIN = D.VARIANT_TINTS_COIN
const VARIANT_TINTS_GEM = D.VARIANT_TINTS_GEM
const MERCHANT_COINS = D.MERCHANT_COINS
const LEVEL_DIAMONDS = D.LEVEL_DIAMONDS
const ZONE_DIAMONDS = D.ZONE_DIAMONDS
const REFILL_DIAMOND_COST = D.REFILL_DIAMOND_COST
const BAG3_DIAMOND_COST = D.BAG3_DIAMOND_COST
const WATER_CAP = D.WATER_CAP
const REGEN_SECS = D.REGEN_SECS
const POP_COST = D.POP_COST
const FREE_REFILLS = D.FREE_REFILLS
const WINBACK_HOURS = D.WINBACK_HOURS
const WATER_REWARD_MAX_RATIO = D.WATER_REWARD_MAX_RATIO
const COIN_LINE = D.COIN_LINE
const COIN_TOP = D.COIN_TOP
const COIN_VALUES = D.COIN_VALUES
const COIN_DROP_RATE = D.COIN_DROP_RATE
const MAP_SIZE = D.MAP_SIZE
const POI_SIZE = D.POI_SIZE
const ZONES = D.ZONES
const EXP_PER_STAR = D.EXP_PER_STAR
const LEVEL_XP = D.LEVEL_XP
const LEVEL_WATER_GIFT = D.LEVEL_WATER_GIFT
const SPIRIT_TYPES = D.SPIRIT_TYPES
const SPIRIT_CAP = D.SPIRIT_CAP
const BAG_SLOTS = D.BAG_SLOTS
const BASKET_CAP = D.BASKET_CAP
const PORTER_SECS = D.PORTER_SECS
const TREAT_COST = D.TREAT_COST

# --- generators ------------------------------------------------------------------
static func active_gen_indices(chapter: int) -> Array:
	var out: Array = []
	for i in GENERATORS.size():
		if chapter >= int(GENERATORS[i].appears_at):
			out.append(i)
	return out

static func gen_index_at(cell: Vector2i, chapter: int) -> int:
	for i in active_gen_indices(chapter):
		if Vector2i(GENERATORS[i].cell) == cell:
			return i
	return -1

static func lines_debuted(chapter: int) -> Array:
	var out: Array = []
	for i in active_gen_indices(chapter):
		for l in GENERATORS[i].lines:
			if not out.has(int(l)):
				out.append(int(l))
	return out

static func line_debut_chapter(line: int) -> int:
	for gen in GENERATORS:
		if gen.lines.has(line):
			return int(gen.appears_at)
	return 0

# --- brambles: terrain = gate_line * 16 + required_tier (gate_line 0 = any line) -
static func ring_of(cell: Vector2i) -> int:
	return maxi(absi(cell.x - GEN_CELL.x), absi(cell.y - GEN_CELL.y))

static func bramble_gate(cell: Vector2i) -> Vector2i:   # (gate_line, required_tier)
	var ring := ring_of(cell)
	if ring <= 2:
		return Vector2i(0, 2)                  # FTUE frontier: any merge
	if ring == 3:
		return Vector2i(0, 4)                  # mid board: a real ladder, any line
	# ring 4 — the screen edge: tier 5 of a late line (3 top half, 4 bottom half)
	return Vector2i(3 if cell.x < GEN_CELL.x else 4, 5)

static func bramble_terrain(cell: Vector2i) -> int:
	var g := bramble_gate(cell)
	return g.x * 16 + g.y

static func open_at_start(cell: Vector2i) -> bool:
	return ring_of(cell) <= 1             # the center 3x3

static func bramble_contents(cell: Vector2i) -> int:
	var gate_line := bramble_gate(cell).x
	var line := gate_line if gate_line > 0 else 1 + (cell.x + cell.y) % 2
	var tier := 1 + (cell.x * 3 + cell.y) % 2     # t1 or t2
	return line * 100 + tier

# --- the chaptered quest script (chapter = home spots bought) --------------------
static var _chapters_cache: Array = []

static func chapters() -> Array:
	if not _chapters_cache.is_empty():
		return _chapters_cache
	var out: Array = []
	var total := 0
	for z in ZONES.size():
		total += ZONES[z].spots.size()
	for i in total:
		var z := zone_of_chapter(i)
		var ramp: Dictionary = ZONE_RAMP[z]
		var lines := lines_debuted(i)
		var lo: int = ramp.tiers.x
		var hi: int = ramp.tiers.y
		var quests: Array = []
		var n_stretch := _stretch_count(z)
		for sidx in n_stretch:
			var sa := _stretch_asks(z, i, sidx, lines, lo, hi)
			quests.append({"asks": sa, "stars": _quest_stars(sa, lo)})
		for q in int(ramp.quests):
			var line: int = lines[(i + q) % lines.size()]
			var t: int = lo + ((i + q * 2) % (hi - lo + 1))
			if line > 2 and zone_of_chapter(line_debut_chapter(line)) == z:
				t = mini(t, 3)               # a freshly debuted line eases in for its zone
			var cnt := 1
			if int(ramp.two_count_every) > 0 and q == 0 and (i % int(ramp.two_count_every)) == 0:
				cnt = 2
			var a1: Array = [{"line": line, "tier": t, "count": cnt}]
			quests.append({"asks": a1, "stars": _quest_stars(a1, lo)})
		out.append({"zone": z, "quests": quests, "slack": int(ramp.slack) + n_stretch, "gift": int(ramp.gift)})
	_chapters_cache = out
	return out

static func quest_asks(q: Dictionary) -> Array:
	if q.has("asks"):
		return q.asks
	return [{"line": int(q.line), "tier": int(q.tier), "count": int(q.get("count", 1))}]

static func _stretch_count(z: int) -> int:
	if z <= 1:
		return 0
	if z >= 4:
		return 2
	return 1

static func _stretch_asks(z: int, i: int, sidx: int, lines: Array, lo: int, hi: int) -> Array:
	var n := 2 if z == 2 else 3            # zone 3 → 2 lines; zones 4-5 → 3 lines …
	if z >= 4 and sidx == 0:
		n = 2                               # … except zone 5's first stretch is a 2-line
	var asks: Array = []
	for a in n:
		var line: int = lines[(i + sidx + a) % lines.size()]
		var t: int = lo + ((i + sidx * 2 + a) % (hi - lo + 1))
		if line > 2 and zone_of_chapter(line_debut_chapter(line)) == z:
			t = mini(t, 3)
		asks.append({"line": line, "tier": t, "count": 1})
	return asks

static func _quest_stars(asks: Array, lo: int) -> int:
	if asks.size() >= 3:
		return 3
	if asks.size() == 2:
		return 2
	var a: Dictionary = asks[0]
	return 2 if (int(a.tier) > lo or int(a.count) >= 2) else 1

static func zone_of_chapter(i: int) -> int:
	var acc := 0
	for z in ZONES.size():
		acc += ZONES[z].spots.size()
		if i < acc:
			return z
	return ZONES.size() - 1

# --- spot level gates -------------------------------------------------------------
static func spot_level_req(z: int, k: int) -> int:
	var rank := k
	for i in z:
		rank += ZONES[i].spots.size()
	return level_for_exp(30 * rank)

static func zone_done(z: int, unlocks: Dictionary) -> bool:
	for sp in ZONES[z].spots:
		if not unlocks.has(String(sp.id)):
			return false
	return true

static func completed_zones(unlocks: Dictionary) -> int:
	var n := 0
	for z in ZONES.size():
		if zone_done(z, unlocks):
			n += 1
	return n

# --- waysides: the coin sink ------------------------------------------------------
static var _waysides_cache: Array = []
static func waysides() -> Array:
	if not _waysides_cache.is_empty():
		return _waysides_cache
	var out: Array = []
	for z in ZONES.size():
		for k in WAYSIDE_PER_ZONE:
			var gi := z * WAYSIDE_PER_ZONE + k
			var prop := gi % WAYSIDE_PROPS.size()
			out.append({
				"id": "way_%d_%d" % [z, k],
				"name": WAYSIDE_PROPS[prop],
				"tex": Game.art("map/%s.png" % WAYSIDE_TEX[prop]),
				"cost": 40 + gi * 6,
				"map_pos": Vector2(0.12 + k * 0.24, 0.16 + (z % 5) * 0.165),   # PROVISIONAL
				"zone_req": z,
			})
	_waysides_cache = out
	return out

static func wayside_sink_capacity() -> int:
	var s := 0
	for w in waysides():
		s += int(w.cost)
	return s

static func wayside_available(w: Dictionary, unlocks: Dictionary) -> bool:
	return zone_done(int(w.zone_req), unlocks)

static func cheapest_spot_cost(unlocks: Dictionary, level: int = 99) -> int:
	for z in ZONES.size():
		var cheapest := 99
		var missing := false
		for k in ZONES[z].spots.size():
			var s: Dictionary = ZONES[z].spots[k]
			if unlocks.has(String(s.id)):
				continue
			missing = true
			if spot_level_req(z, k) <= level:
				cheapest = mini(cheapest, int(s.cost))
		if missing:
			return cheapest if cheapest < 99 else -2   # -2 = all remaining level-locked
	return -1

# --- spot customizations ----------------------------------------------------------
static func spot_variants(z: int, k: int) -> Array:
	var rank := k
	for i in z:
		rank += ZONES[i].spots.size()
	var coin_cost := 25 + z * 15 + (k % 3) * 5
	var gem_cost := 2 + int(z / 2.0)
	return [
		{"id": "base", "name": "Classic", "currency": "", "cost": 0, "tint": Color.WHITE},
		{"id": "coin", "name": VARIANT_NAMES_COIN[rank % VARIANT_NAMES_COIN.size()],
			"currency": "coins", "cost": coin_cost, "tint": VARIANT_TINTS_COIN[rank % VARIANT_TINTS_COIN.size()]},
		{"id": "gem", "name": VARIANT_NAMES_GEM[rank % VARIANT_NAMES_GEM.size()],
			"currency": "diamonds", "cost": gem_cost, "tint": VARIANT_TINTS_GEM[rank % VARIANT_TINTS_GEM.size()]},
	]

# --- sell / economy formulas ------------------------------------------------------
static func sell_value(code: int) -> int:
	return maxi(1, code % 100)            # t1=1 … t8=8 coins

static func sell_reward(code: int) -> Vector2i:
	var tier := code % 100
	if tier >= TOP_TIER:
		return Vector2i(0, 1)            # the diamond pinnacle
	return Vector2i(maxi(1, tier), 0)

static func water_to_earn_diamond() -> int:
	return int(pow(2, TOP_TIER - 1))
static func water_a_diamond_buys() -> int:
	return int(WATER_CAP / float(REFILL_DIAMOND_COST))

static func is_coin(code: int) -> bool:
	return int(code / 100.0) == COIN_LINE

static func coin_value(code: int) -> int:
	return int(COIN_VALUES.get(code % 100, 0))

# --- progression ------------------------------------------------------------------
static func level_for_exp(exp: int) -> int:
	var lvl := 1
	for i in LEVEL_XP.size():
		if exp >= LEVEL_XP[i]:
			lvl = i + 1
	return lvl

static func zone_star_total(z: int) -> int:
	var t := 0
	for s in ZONES[z].spots:
		t += int(s.cost)
	return t

static func item_tex_path(code: int) -> String:
	var line := int(code / 100.0)
	var tier := code % 100
	if not LINES.has(line):
		return ""
	return Game.art("items/%s_%d.png" % [LINES[line].base, tier])
