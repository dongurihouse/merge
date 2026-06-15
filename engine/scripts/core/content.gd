extends RefCounted
## Content ENGINE (theme-agnostic). The DATA lives in the active game
## (games/<name>/*_data.gd, reached via Game.data()); this file is the generic
## logic that operates on it — bramble field, quest generation, progression,
## economy formulas — plus a re-export of the data so callers keep using G.X.
## (Was grove_content.gd; the grove tables moved to games/grove/grove_data.gd.)

const Game = preload("res://engine/scripts/core/game.gd")
const Save = preload("res://engine/scripts/core/save.gd")

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
const LEVEL_STARS = D.LEVEL_STARS
const LEVEL_STARS_TAIL = D.LEVEL_STARS_TAIL
const LEVEL_WATER_GIFT = D.LEVEL_WATER_GIFT
const CHARACTER_TYPES = D.CHARACTER_TYPES
const CHARACTER_CAP = D.CHARACTER_CAP
const CHARACTER_ART = D.CHARACTER_ART
const BAG_SLOTS = D.BAG_SLOTS
const BASKET_CAP = D.BASKET_CAP
const PORTER_SECS = D.PORTER_SECS
const TREAT_COST = D.TREAT_COST

# --- generators ------------------------------------------------------------------
## The generators LIVE right now = the current zone's set (per zone, §6 — not the old
## per-chapter accumulation). The zone is read off the spot-count `chapter`; the live set
## switches when the player crosses into the next zone (the interim "grant on zone entry").
static func active_gen_indices(chapter: int) -> Array:
	var zone := zone_of_chapter(chapter)
	var out: Array = []
	for i in GENERATORS.size():
		if int(GENERATORS[i].zone) == zone:
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

# --- per-zone generator roster (the merge-to-evolve model, §6) --------------------
# A roster is an Array of {id, zone, lines:[a,b], evolves_from}. evolves_from = the
# id of the previous-zone generator this one upgrades (consumed on evolve); "" means
# granted outright (a zone's surplus, or zone 0's starters). Pure derivation — the
# live code passes GENERATORS; tests pass a fixture. Replaces appears_at accumulation.
static func generators_for_zone(roster: Array, zone: int) -> Array:
	var out: Array = []
	for g in roster:
		if int(g.zone) == zone:
			out.append(g)
	return out

## The lines LIVE while the player is in `zone` — its generators' lines only (older
## zones' lines have retired, §6). Replaces the accumulating lines_debuted(chapter).
static func lines_for_zone(roster: Array, zone: int) -> Array:
	var out: Array = []
	for g in generators_for_zone(roster, zone):
		for l in g.lines:
			if not out.has(int(l)):
				out.append(int(l))
	return out

## Lines that have RETIRED by the time you reach `zone` — every earlier zone's lines.
## A retired line is never popped or asked again (it archives to the Collection — that
## hook is a separate task; here it simply drops out of the live set).
static func retired_lines(roster: Array, zone: int) -> Array:
	var out: Array = []
	for z in zone:
		for l in lines_for_zone(roster, z):
			if not out.has(int(l)):
				out.append(int(l))
	return out

## The evolve lineage: {grant_id -> consumed_predecessor_id} for every generator that
## upgrades an older one. Surplus (granted-outright) generators are absent.
static func evolve_map(roster: Array) -> Dictionary:
	var out: Dictionary = {}
	for g in roster:
		if String(g.evolves_from) != "":
			out[String(g.id)] = String(g.evolves_from)
	return out

## The ids of a zone's generators that are granted OUTRIGHT (no predecessor to evolve).
static func surplus_gen_ids(roster: Array, zone: int) -> Array:
	var out: Array = []
	for g in generators_for_zone(roster, zone):
		if String(g.evolves_from) == "":
			out.append(String(g.id))
	return out

static func gen_def(roster: Array, id: String) -> Dictionary:
	for g in roster:
		if String(g.id) == id:
			return g
	return {}

## The lines currently LIVE = the union of the lines of every generator on the board.
## `gen_state` maps cell (Vector2i) -> generator id. Sorted, deduped. A line drops out
## of this set the moment its generator is consumed by an evolve — that IS retirement.
static func gen_live_lines(gen_state: Dictionary, roster: Array) -> Array:
	var out: Array = []
	for cell in gen_state:
		for l in gen_def(roster, String(gen_state[cell])).get("lines", []):
			if not out.has(int(l)):
				out.append(int(l))
	out.sort()
	return out

## A grant generator may evolve onto `old_cell` iff that cell holds the exact generator
## the grant declares as its predecessor (`evolves_from`). A surplus grant ("") never
## evolves — it is placed on a fresh cell instead.
static func gen_can_evolve(gen_state: Dictionary, roster: Array, old_cell: Vector2i, grant_id: String) -> bool:
	if not gen_state.has(old_cell):
		return false
	var grant := gen_def(roster, grant_id)
	if grant.is_empty() or String(grant.evolves_from) == "":
		return false
	return String(grant.evolves_from) == String(gen_state[old_cell])

## Evolve: the grant generator consumes the one at `old_cell` and takes its place — the
## old generator's lines retire, the grant's go live (§6). Returns a NEW state (the input
## is left untouched); an invalid evolve is a no-op. The caller clears the grant's own
## board piece and flags the retired lines for the Collection (a separate task).
static func gen_evolve(gen_state: Dictionary, roster: Array, old_cell: Vector2i, grant_id: String) -> Dictionary:
	var out: Dictionary = gen_state.duplicate(true)
	if gen_can_evolve(gen_state, roster, old_cell, grant_id):
		out[old_cell] = grant_id
	return out

## The cell a generator occupies — its own `cell` if granted outright, else (an evolved
## generator) the cell of the predecessor it grew from, walked up the lineage to the root.
static func gen_cell_of(roster: Array, id: String) -> Vector2i:
	var g := gen_def(roster, id)
	while not g.is_empty() and String(g.evolves_from) != "":
		g = gen_def(roster, String(g.evolves_from))
	return g.get("cell", Vector2i(-1, -1))

## The live generator set for a zone: {cell -> id} for each of the zone's generators,
## evolved ones inheriting their lineage cell. The interim "grant on zone entry" resolver
## — §7's grant quests will drive the same end state one evolve at a time.
static func live_gen_state(roster: Array, zone: int) -> Dictionary:
	var out: Dictionary = {}
	for g in generators_for_zone(roster, zone):
		out[gen_cell_of(roster, String(g.id))] = String(g.id)
	return out

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
	return level_for_stars(3 * rank)   # == the old level_for_exp(30·rank); preserves the gates

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

# --- map progression queries (folded from map.gd; the scene keeps thin wrappers) --
static func zone_for_id(id: String) -> int:
	for z in ZONES.size():
		if String(ZONES[z].id) == id:
			return z
	return -1

static func zone_unlocked(z: int, unlocks: Dictionary) -> bool:
	return z == 0 or zone_done(z - 1, unlocks)

static func owned_count(z: int, unlocks: Dictionary) -> int:
	var n := 0
	for s in ZONES[z].spots:
		if unlocks.has(String(s.id)):
			n += 1
	return n

static func zone_stars_left(z: int, unlocks: Dictionary) -> int:
	var left := 0
	for s in ZONES[z].spots:
		if not unlocks.has(String(s.id)):
			left += int(s.cost)
	return left

static func frontier_zone(unlocks: Dictionary) -> int:
	for z in ZONES.size():
		if zone_unlocked(z, unlocks) and not zone_done(z, unlocks):
			return z
	return -1

## How many ambient characters wander: 1 + completed zones, capped. The host
## passes this to Ambient.build_layer (progression stays a game rule, not engine).
static func character_count(unlocks: Dictionary) -> int:
	return mini(1 + completed_zones(unlocks), CHARACTER_CAP)

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

# Of the open (unowned, level-affordable) spots in a zone, is k the one to buy next?
# Cheapest wins; ties break to the lower index. (Powers the "buy me next" affordance.)
static func is_cheapest_open(z: int, k: int, lvl: int, unlocks: Dictionary) -> bool:
	var my_cost := int(ZONES[z].spots[k].cost)
	for j in ZONES[z].spots.size():
		var s: Dictionary = ZONES[z].spots[j]
		if unlocks.has(String(s.id)) or spot_level_req(z, j) > lvl:
			continue
		if int(s.cost) < my_cost or (int(s.cost) == my_cost and j < k):
			return j == k
	return true

# The water gift paid when a purchase closes a chapter (0 if none). The buy that
# triggers this has already added its spot, so the closing chapter = unlocks.size()-1.
static func chapter_gift(unlocks: Dictionary) -> int:
	var closing := unlocks.size() - 1
	return int(chapters()[mini(closing, chapters().size() - 1)].get("gift", 0))

# --- spot customizations ----------------------------------------------------------
# The variant dict for an id (or {} if none) — the swatch the player tapped.
static func variant_by_id(z: int, k: int, vid: String) -> Dictionary:
	for v in spot_variants(z, k):
		if String(v.id) == vid:
			return v
	return {}

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
# The ONE level clock (§3): one uncapped Level, driven by stars EARNED (cumulative).
static func level_for_stars(earned: int) -> int:
	var lvl := 1
	for i in LEVEL_STARS.size():
		if earned >= int(LEVEL_STARS[i]):
			lvl = i + 1
	var top := int(LEVEL_STARS[LEVEL_STARS.size() - 1])
	if earned > top:
		lvl += int((earned - top) / float(LEVEL_STARS_TAIL))   # uncapped flat tail
	return lvl

# Cumulative stars EARNED required to BE at `level` (the inverse — the HUD fraction).
static func stars_at_level(level: int) -> int:
	if level <= 1:
		return 0
	if level <= LEVEL_STARS.size():
		return int(LEVEL_STARS[level - 1])
	return int(LEVEL_STARS[LEVEL_STARS.size() - 1]) + LEVEL_STARS_TAIL * (level - LEVEL_STARS.size())

# Earn stars: credit BOTH the spendable balance and the cumulative EARNED clock that
# drives Level; on a level-up, gift water + diamonds (once per level gained). Returns
# the levels gained so the caller can play the juice. The sole way Level advances.
static func earn_stars(n: int) -> int:
	Save.add_stars(n)
	var g := Save.grove()
	var earned := int(g.get("stars_earned", 0))
	var before := level_for_stars(earned)
	earned += n
	g["stars_earned"] = earned
	var gained := level_for_stars(earned) - before
	if gained > 0:
		g["water"] = mini(WATER_CAP, int(g.get("water", WATER_CAP)) + LEVEL_WATER_GIFT * gained)
		Save.add_diamonds(LEVEL_DIAMONDS * gained)
	Save.grove_write()
	return gained

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
