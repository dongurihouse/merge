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
const STAR_CAP = D.STAR_CAP
const CLICK_TO_VALUE = D.CLICK_TO_VALUE
const QUEST_2ASK_LEVEL = D.QUEST_2ASK_LEVEL
const QUEST_3ASK_LEVEL = D.QUEST_3ASK_LEVEL
const QUEST_TIER_BASE = D.QUEST_TIER_BASE
const QUEST_LEVELS_PER_TIER = D.QUEST_LEVELS_PER_TIER
const QUEST_2COUNT_RATE = D.QUEST_2COUNT_RATE
const QUEST_NEWEST_BIAS = D.QUEST_NEWEST_BIAS
const QUEST_FEATURED_RATE = D.QUEST_FEATURED_RATE
const QUEST_FEATURED_COIN_BONUS = D.QUEST_FEATURED_COIN_BONUS
const QUEST_DEBUT_TIER_CAP = D.QUEST_DEBUT_TIER_CAP
const MAX_GIVERS = D.MAX_GIVERS
const STARS_PER_QUEST_EST = D.STARS_PER_QUEST_EST
const GATE_ASK_COUNT = D.GATE_ASK_COUNT
const GATE_STARS = D.GATE_STARS
const GATE_COIN_BONUS = D.GATE_COIN_BONUS
const GATE_TIER_BASE = D.GATE_TIER_BASE
const BURST_ODDS = D.BURST_ODDS
const BURST_MAP_EVERY = D.BURST_MAP_EVERY
const BURST_MAX = D.BURST_MAX
const BURST_UPGRADE_COSTS = D.BURST_UPGRADE_COSTS
const STARTER_ITEMS = D.STARTER_ITEMS
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
# --- per-zone generator roster (the generator-grant hand-in model, §6) ------------
# A roster is an Array of {id, zone, lines:[a,b], grant_from}. grant_from = the id of
# the previous-zone generator you HAND IN (to a generator-grant quest) to receive this
# one — old lines retire; "" = granted outright (a zone's surplus, or zone 0's starters).
# Generators never merge to evolve (that mechanic is retired). Pure derivation — the
# live code passes GENERATORS; tests pass a fixture. Replaces appears_at accumulation.
static func generators_for_zone(roster: Array, zone: int) -> Array:
	var out: Array = []
	for g in roster:
		if int(g.zone) == zone:
			out.append(g)
	return out

## The lines LIVE while the player is in `zone` — its generators' lines only (older zones'
## lines have retired, §6). The current map's quests + gate draw only from these.
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

## The grant lineage: {grant_id -> handed_in_predecessor_id} for every generator that
## arrives by handing an older one in. Surplus (granted-outright) generators are absent.
static func grant_map(roster: Array) -> Dictionary:
	var out: Dictionary = {}
	for g in roster:
		if String(g.grant_from) != "":
			out[String(g.id)] = String(g.grant_from)
	return out

## The ids of a zone's generators that are granted OUTRIGHT (no predecessor to hand in).
static func surplus_gen_ids(roster: Array, zone: int) -> Array:
	var out: Array = []
	for g in generators_for_zone(roster, zone):
		if String(g.grant_from) == "":
			out.append(String(g.id))
	return out

## The authored generator-grant quests that open `zone` (§6/§7): one per hand-in
## generator (those with a predecessor). Each `{asks:[], grant:{hand_in, grants}, stars}`
## asks for no items — it hands the predecessor generator in and grants the new one.
## Surpluses are granted outright (absent here). §7 schedules these into the live quest
## script; the interim path still auto-seeds the full set on zone entry (live_gen_state).
static func grant_quests_for_zone(roster: Array, zone: int) -> Array:
	var out: Array = []
	for g in generators_for_zone(roster, zone):
		if String(g.grant_from) != "":
			out.append({"asks": [], "grant": {"hand_in": String(g.grant_from), "grants": String(g.id)}, "stars": 1})
	return out

static func gen_def(roster: Array, id: String) -> Dictionary:
	for g in roster:
		if String(g.id) == id:
			return g
	return {}

## The lines currently LIVE = the union of the lines of every generator on the board.
## `gen_state` maps cell (Vector2i) -> generator id. Sorted, deduped. A line drops out
## of this set the moment its generator is handed in for a grant — that IS retirement.
static func gen_live_lines(gen_state: Dictionary, roster: Array) -> Array:
	var out: Array = []
	for cell in gen_state:
		for l in gen_def(roster, String(gen_state[cell])).get("lines", []):
			if not out.has(int(l)):
				out.append(int(l))
	out.sort()
	return out

## A generator may be GRANTED iff its handed-in predecessor (`grant_from`) is currently
## live somewhere in `gen_state`. A surplus grant ("") is never a hand-in — it is placed
## outright instead (live_gen_state / seed).
static func gen_can_grant(gen_state: Dictionary, roster: Array, grant_id: String) -> bool:
	var grant := gen_def(roster, grant_id)
	if grant.is_empty() or String(grant.grant_from) == "":
		return false
	return gen_state.values().has(String(grant.grant_from))

## Grant the hand-in: the new generator takes the cell of the predecessor it is handed in
## for — old consumed, new installed at its CURRENT cell (so a moved generator is handled),
## old lines retire, the grant's go live (§6). Returns a NEW state (the input is left
## untouched); an invalid grant is a no-op. The caller flags the retired lines for the
## Collection (a separate task).
static func gen_grant(gen_state: Dictionary, roster: Array, grant_id: String) -> Dictionary:
	var out: Dictionary = gen_state.duplicate(true)
	if gen_can_grant(gen_state, roster, grant_id):
		var pred := String(gen_def(roster, grant_id).grant_from)
		for cell in out.keys():
			if String(out[cell]) == pred:
				out[cell] = grant_id
				break
	return out

## The cell a generator occupies — its own `cell` if granted outright, else (a hand-in
## grant) the cell of the predecessor it is granted for, walked up the lineage to the root.
static func gen_cell_of(roster: Array, id: String) -> Vector2i:
	var g := gen_def(roster, id)
	while not g.is_empty() and String(g.grant_from) != "":
		g = gen_def(roster, String(g.grant_from))
	return g.get("cell", Vector2i(-1, -1))

## The live generator set for a zone: {cell -> id} for each of the zone's generators,
## hand-in grants inheriting their lineage cell. The interim "grant on zone entry" resolver
## — §7's grant quests will drive the same end state one hand-in at a time.
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

static func quest_asks(q: Dictionary) -> Array:
	if q.has("asks"):
		return q.asks
	return [{"line": int(q.line), "tier": int(q.tier), "count": int(q.get("count", 1))}]

# --- §7 generated-quest reward: stars-first (capped), coins absorb the overflow ----
## The avg t1-equivalent VALUE one generator pop yields, given the tier-decay pop odds:
## a pop lands at tier i+1 (worth 2^i t1-equivalents) with TIER_ODDS[i]. ≈1.59 today.
static func avg_pop_value() -> float:
	var v := 0.0
	for i in TIER_ODDS.size():
		v += float(TIER_ODDS[i]) * pow(2.0, i)
	return v

## Expected generator-clicks (pops) to PRODUCE a quest's asks (§7): the asks' total worth in
## t1-equivalents (Σ count × 2^(tier-1)) over the avg value a pop yields (TIER_ODDS-adjusted).
static func quest_expected_clicks(asks: Array) -> float:
	var raw := 0.0
	for a in asks:
		raw += float(int(a.count)) * pow(2.0, int(a.tier) - 1)
	return raw / avg_pop_value()

## The §7 reward {stars, coins}: value = expected_clicks × CLICK_TO_VALUE, paid STARS-FIRST
## (floored at 1, capped at STAR_CAP so level ∝ quest COUNT, §3) then COINS take the overflow —
## a deeper ask pays the same ★ but more 🪙, absorbing click-variance. STAR_CAP + CLICK_TO_VALUE
## are PROVISIONAL game tunables (set by the Monte-Carlo balance pass).
static func quest_reward(asks: Array) -> Dictionary:
	var value: int = int(round(quest_expected_clicks(asks) * CLICK_TO_VALUE))
	return {"stars": clampi(value, 1, STAR_CAP), "coins": maxi(0, value - STAR_CAP)}

## Pick a line index-weighted toward the newest (end of the ascending-sorted list): the
## weight of rank i is (i+1)^QUEST_NEWEST_BIAS, so the fence leans at the richest content.
static func _weighted_line_pick(sorted_lines: Array, rng: RandomNumberGenerator) -> int:
	var total := 0.0
	for i in sorted_lines.size():
		total += pow(i + 1, QUEST_NEWEST_BIAS)
	var r := rng.randf() * total
	var acc := 0.0
	for i in sorted_lines.size():
		acc += pow(i + 1, QUEST_NEWEST_BIAS)
		if r <= acc:
			return int(sorted_lines[i])
	return int(sorted_lines[sorted_lines.size() - 1])

## Generate a regular quest for a player at `level` from the live lines (§7). Asks scale with
## level (more asks, higher tiers), drawn weighted toward the NEWEST/highest-value live line;
## the map's top tier (t8) is never asked (gate-quest only), and a freshly-debuted line eases
## in at ≤ QUEST_DEBUT_TIER_CAP. Deterministic given `rng`. Returns {asks, reward, featured}.
## All numbers are PROVISIONAL game tunables (set by the Monte-Carlo balance pass).
static func gen_quest(level: int, live_lines: Array, rng: RandomNumberGenerator) -> Dictionary:
	var lines: Array = live_lines.duplicate()
	lines.sort()                                       # ascending: last entry = newest / highest-value
	var n_asks := 1
	if level >= QUEST_3ASK_LEVEL:
		n_asks = 3
	elif level >= QUEST_2ASK_LEVEL:
		n_asks = 2
	n_asks = mini(n_asks, lines.size())
	var tier_hi: int = clampi(QUEST_TIER_BASE + int(level / float(QUEST_LEVELS_PER_TIER)), QUEST_TIER_BASE, TOP_TIER - 1)
	var newest: int = int(lines[lines.size() - 1])
	var asks: Array = []
	for _a in n_asks:
		var li := _weighted_line_pick(lines, rng)
		var tier := rng.randi_range(QUEST_TIER_BASE, tier_hi)
		if li == newest:                                # the freshest line eases in low
			tier = mini(tier, QUEST_DEBUT_TIER_CAP)
		var count := 2 if rng.randf() < QUEST_2COUNT_RATE else 1
		asks.append({"line": li, "tier": tier, "count": count})
	var reward: Dictionary = quest_reward(asks)
	var featured: bool = rng.randf() < QUEST_FEATURED_RATE
	if featured:
		reward["coins"] = int(reward.coins) + QUEST_FEATURED_COIN_BONUS
	return {"asks": asks, "reward": reward, "featured": featured}

## §7 soft gate (gate_pause): how many giver stands are active, metered to the NEXT unlock —
## ≈ ceil((next_cost − banked) / STARS_PER_QUEST_EST), capped at MAX_GIVERS, and 0 once the
## next unlock is affordable (the fence empties → wordless "go restore"). The sentinels from
## cheapest_spot_cost: −1 (all spots owned) → 0; −2 (whole frontier level-locked) → full fence
## (pump ★ to level up — the no-strand rule keeps a level-locked spot off the affordable frontier).
static func active_giver_count(banked_stars: int, next_cost: int, max_givers: int = MAX_GIVERS) -> int:
	if next_cost == -1:
		return 0
	if next_cost == -2:
		return max_givers
	var need := next_cost - banked_stars
	if need <= 0:
		return 0
	return clampi(int(ceil(need / float(STARS_PER_QUEST_EST))), 1, max_givers)

## The authored great-spirit GATE quest that ends map `zone` (§6/§7): asks a randomized handful
## of the map's TOP-TIER harvest (its richest/newest lines at t8 = TOP_TIER) and, delivered,
## unlocks the next map for a large authored reward. Deterministic given `rng`. The one quest
## that asks the ceiling tier (regular quests never do). {asks, gate:true, stars, reward}.
static func gate_quest(roster: Array, zone: int, _rng: RandomNumberGenerator = null) -> Dictionary:
	var lines: Array = lines_for_zone(roster, zone)
	lines.sort()                                       # the richest (newest) lines sit last
	var n: int = mini(GATE_ASK_COUNT, lines.size())
	var pick: Array = lines.slice(lines.size() - n, lines.size())   # the top n (richest) lines
	var gate_t: int = mini(GATE_TIER_BASE + zone, TOP_TIER)         # the map's ceiling: t5 (map 1) → t8 (map 4+)
	var asks: Array = []
	for li in pick:
		asks.append({"line": int(li), "tier": gate_t, "count": 1})
	var coins: int = int(quest_reward(asks).coins) + GATE_COIN_BONUS
	return {"asks": asks, "gate": true, "stars": GATE_STARS, "reward": {"stars": GATE_STARS, "coins": coins}}

## Burst-pop (§6): one tap on a generator pops a BURST of items, not just one. The size is
## the base roll (BURST_ODDS = 1/2/3 items) + a FREE per-map scale-up (every BURST_MAP_EVERY
## maps, generators throw one more) + the player's paid burst-upgrade level, clamped to
## [1, BURST_MAX]. Each popped item still costs 1 energy (the caller charges per item).
static func burst_count(zone: int, upgrade_level: int, rng: RandomNumberGenerator) -> int:
	var base := 1
	var roll := rng.randf()
	var acc := 0.0
	for i in BURST_ODDS.size():
		acc += float(BURST_ODDS[i])
		if roll <= acc:
			base = i + 1
			break
	var free_scale := int(zone / float(BURST_MAP_EVERY))     # +1 base burst every N maps
	return clampi(base + free_scale + upgrade_level, 1, BURST_MAX)

## The burst-upgrade coin sink: the cost to raise the burst from `level` to `level+1`,
## escalating up the BURST_UPGRADE_COSTS ladder. Returns −1 once maxed (no further upgrade).
static func burst_upgrade_cost(level: int) -> int:
	if level >= 0 and level < BURST_UPGRADE_COSTS.size():
		return int(BURST_UPGRADE_COSTS[level])
	return -1

## How many paid burst-upgrade levels exist (the ladder length) — i.e. the max upgrade level.
static func burst_upgrade_max() -> int:
	return BURST_UPGRADE_COSTS.size()

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

## The index of the home-hub map (the permanent anchor — Core §8 / grove_spec §3). The game
## flags it with `hub: true`; defaults to the first map. Drives the boot landing + the HUD home
## shortcut. (The hub is authored deeper than a finish-once map; its yield loop is the KEYSTONE.)
static func hub_zone() -> int:
	for z in ZONES.size():
		if bool(ZONES[z].get("hub", false)):
			return z
	return 0

## A map is fully complete when all its spots are restored AND its great-spirit gate quest
## is delivered (§7) — gate-delivery is tracked in `gates` (zone indices). The NEXT map
## unlocks only on it (the completion chain), not merely on spot-completion.
static func map_complete(z: int, unlocks: Dictionary, gates: Array) -> bool:
	return zone_done(z, unlocks) and gates.has(z)

static func zone_unlocked(z: int, unlocks: Dictionary, gates: Array = []) -> bool:
	return z == 0 or map_complete(z - 1, unlocks, gates)

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

static func frontier_zone(unlocks: Dictionary, gates: Array = []) -> int:
	for z in ZONES.size():
		if zone_unlocked(z, unlocks, gates) and not map_complete(z, unlocks, gates):
			return z
	return -1

## The cheapest unowned, level-affordable spot IN map `z` (the frontier's next restore) — the
## §7 meter sizes the fence to it. Returns the cost, -1 (all of z owned → gate time), or -2
## (all remaining level-locked → keep questing to level up). Zone-scoped, so gate-locked later
## maps are never the meter target.
static func zone_cheapest_spot(z: int, unlocks: Dictionary, level: int = 99) -> int:
	var cheapest := 99
	var missing := false
	for k in ZONES[z].spots.size():
		var sp: Dictionary = ZONES[z].spots[k]
		if unlocks.has(String(sp.id)):
			continue
		missing = true
		if spot_level_req(z, k) <= level:
			cheapest = mini(cheapest, int(sp.cost))
	if not missing:
		return -1
	return cheapest if cheapest < 99 else -2

## How many ambient characters wander: 1 + completed zones, capped. The host
## passes this to Ambient.build_layer (progression stays a game rule, not engine).
static func character_count(unlocks: Dictionary) -> int:
	return mini(1 + completed_zones(unlocks), CHARACTER_CAP)

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
