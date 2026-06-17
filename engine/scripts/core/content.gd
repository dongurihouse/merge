extends RefCounted
## Content ENGINE (theme-agnostic). The DATA lives in the active game
## (games/<name>/*_data.gd, reached via Game.data()); this file is the generic
## logic that operates on it — bramble field, quest generation, progression,
## economy formulas — plus a re-export of the data so callers keep using G.X.
## (Was grove_content.gd; the grove tables moved to games/grove/grove_data.gd.)

const Game = preload("res://engine/scripts/core/game.gd")
const Save = preload("res://engine/scripts/core/save.gd")
const Vault = preload("res://engine/scripts/core/vault.gd")   # T44 SKIM-SITE — the piggy bank skims earned premium here

# --- the ACTIVE game's DATA (compile-time const), re-exported as consts so every
# --- existing G.<CONST> reader keeps working and := type inference still resolves.
const D = Game.DATA
const COLS = D.COLS
const ROWS = D.ROWS
const TOP_TIER = D.TOP_TIER
const LINES = D.LINES
const GENERATORS = D.GENERATORS
const GEN_CELL = D.GEN_CELL
const MIN_LEVEL = D.MIN_LEVEL
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
const QUEST_FEATURED_GEM_ODDS = D.QUEST_FEATURED_GEM_ODDS
const QUEST_FEATURED_GEM_BONUS = D.QUEST_FEATURED_GEM_BONUS
const QUEST_DEBUT_TIER_CAP = D.QUEST_DEBUT_TIER_CAP
const MAX_GIVERS = D.MAX_GIVERS
const STARS_PER_QUEST_EST = D.STARS_PER_QUEST_EST
const GATE_ASK_COUNT = D.GATE_ASK_COUNT
const GATE_STARS = D.GATE_STARS
const GATE_COIN_BONUS = D.GATE_COIN_BONUS
const GATE_TIER_BASE = D.GATE_TIER_BASE
const BURST_ODDS = D.BURST_ODDS
const BURST_MAP_EVERY = D.BURST_MAP_EVERY
const BURST_FREE_MAX = D.BURST_FREE_MAX
const BURST_MAX = D.BURST_MAX
const BURST_UPGRADE_COSTS = D.BURST_UPGRADE_COSTS
const HUB_MAX_LEVEL = D.HUB_MAX_LEVEL
const HUB_YIELD_RATE = D.HUB_YIELD_RATE
const HUB_YIELD_CAP = D.HUB_YIELD_CAP
const HUB_UPGRADE_COST = D.HUB_UPGRADE_COST
const STARTER_ITEMS = D.STARTER_ITEMS
const VARIANT_NAMES_COIN = D.VARIANT_NAMES_COIN
const VARIANT_NAMES_GEM = D.VARIANT_NAMES_GEM
const VARIANT_TINTS_COIN = D.VARIANT_TINTS_COIN
const VARIANT_TINTS_GEM = D.VARIANT_TINTS_GEM
const SELL_MAP_BAND = D.SELL_MAP_BAND
const LEVEL_DIAMONDS = D.LEVEL_DIAMONDS
const MAP_DIAMONDS = D.MAP_DIAMONDS
const REFILL_DIAMOND_COST = D.REFILL_DIAMOND_COST
const BAG_START_SLOTS = D.BAG_START_SLOTS
const BAG_MAX_SLOTS = D.BAG_MAX_SLOTS
const BAG_SLOT_PRICES = D.BAG_SLOT_PRICES
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
static var MAPS: Array = D.MAPS   # var, not const: grove_data builds MAPS at load (merges the placer's JSON layout)
const LEVEL_STARS = D.LEVEL_STARS
const LEVEL_STARS_TAIL = D.LEVEL_STARS_TAIL
const LEVEL_WATER_GIFT = D.LEVEL_WATER_GIFT
const CHARACTER_TYPES = D.CHARACTER_TYPES
const CHARACTER_CAP = D.CHARACTER_CAP
const CHARACTER_ART = D.CHARACTER_ART
const BASKET_CAP = D.BASKET_CAP
const PORTER_SECS = D.PORTER_SECS
const TREAT_COST = D.TREAT_COST
const SPOTLIGHTS = D.SPOTLIGHTS

# --- the bag (§5) ----------------------------------------------------------------
# The 💎 price of the NEXT expansion when `owned` slots are held (BAG_START_SLOTS..BAG_MAX_SLOTS).
# Indexes BAG_SLOT_PRICES by how many expansions are already bought (owned - START). Returns 0
# at/above the cap (nothing left to buy) — the caller treats 0 as "maxed".
static func next_bag_slot_price(owned: int) -> int:
	var bought := owned - BAG_START_SLOTS
	if bought < 0 or bought >= BAG_SLOT_PRICES.size():
		return 0
	return int(BAG_SLOT_PRICES[bought])

# --- generators ------------------------------------------------------------------
# --- per-map generator roster (the generator-grant hand-in model, §6) ------------
# A roster is an Array of {id, map, lines:[a,b], grant_from}. grant_from = the id of
# the previous-map generator you HAND IN (to a generator-grant quest) to receive this
# one — old lines retire; "" = granted outright (a map's surplus, or map 0's starters).
# Generators never merge to evolve (that mechanic is retired). Pure derivation — the
# live code passes GENERATORS; tests pass a fixture. Replaces appears_at accumulation.
static func generators_for_map(roster: Array, map: int) -> Array:
	var out: Array = []
	for g in roster:
		if int(g.map) == map:
			out.append(g)
	return out

## The lines LIVE while the player is in `map` — its generators' lines only (older maps'
## lines have retired, §6). The current map's quests + gate draw only from these.
static func lines_for_map(roster: Array, map: int) -> Array:
	var out: Array = []
	for g in generators_for_map(roster, map):
		for l in g.lines:
			if not out.has(int(l)):
				out.append(int(l))
	return out

## The ANCHOR lines (§6's anchor-line exemption): the union of the lines of every generator
## flagged `anchor: true`, from any map. An anchor generator is NEVER handed in — it
## permanently holds one of the live slots — so its lines stay LIVE and ASKABLE for the life
## of the save, even past the map they debuted in. Game-agnostic: the flag is read off the
## roster def (a game designates at most one anchor; this unions all that are flagged). Sorted.
static func anchor_lines(roster: Array) -> Array:
	var out: Array = []
	for g in roster:
		if bool(g.get("anchor", false)):
			for l in g.get("lines", []):
				if not out.has(int(l)):
					out.append(int(l))
	out.sort()
	return out

## The lines a regular quest may ASK while the player is in `map` (§6/§7): the current map's
## live lines (`lines_for_map`) UNIONED with the anchor lines, deduped. Non-anchor earlier-map
## lines stay EXCLUDED (they retired) — only the anchor is exempt, so its lines remain askable
## past their debut map (fixing the dead-anchor bug). At map 0 the anchor is already in the
## roster, so the union is a no-op there. Sorted.
static func askable_lines(roster: Array, map: int) -> Array:
	var out: Array = lines_for_map(roster, map)
	for l in anchor_lines(roster):
		if not out.has(int(l)):
			out.append(int(l))
	out.sort()
	return out

## Lines that have RETIRED by the time you reach `map` — every earlier map's lines.
## A retired line is never popped or asked again (it archives to the Collection — that
## hook is a separate task; here it simply drops out of the live set).
static func retired_lines(roster: Array, map: int) -> Array:
	var out: Array = []
	for z in map:
		for l in lines_for_map(roster, z):
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

## The ids of a map's generators that are granted OUTRIGHT (no predecessor to hand in).
static func surplus_gen_ids(roster: Array, map: int) -> Array:
	var out: Array = []
	for g in generators_for_map(roster, map):
		if String(g.grant_from) == "":
			out.append(String(g.id))
	return out

## The authored generator-grant quests that open `map` (§6/§7): one per hand-in
## generator (those with a predecessor). Each `{asks:[], grant:{hand_in, grants}, stars}`
## asks for no items — it hands the predecessor generator in and grants the new one.
## Surpluses are granted outright (absent here). §7 schedules these into the live quest
## script; the interim path still auto-seeds the full set on map entry (live_gen_state).
static func grant_quests_for_map(roster: Array, map: int) -> Array:
	var out: Array = []
	for g in generators_for_map(roster, map):
		if String(g.grant_from) != "":
			out.append({"asks": [], "grant": {"hand_in": String(g.grant_from), "grants": String(g.id)}, "stars": 1})
	return out

static func gen_def(roster: Array, id: String) -> Dictionary:
	for g in roster:
		if String(g.id) == id:
			return g
	return {}

## The map a LINE belongs to — its emitting generator's `map` (0-indexed). Pure derivation
## off the GENERATORS roster (line → the generator whose `lines` lists it → that gen's map).
## Drives the §6/§9 per-map sell band. Returns 0 if the line has no generator (defensive: an
## unrostered/coin line falls to the map-1 band 1.0 rather than crashing the sell path).
static func map_for_line(line: int) -> int:
	for g in GENERATORS:
		if g.get("lines", []).has(line):
			return int(g.map)
	return 0

## The map an ITEM (code = line*100 + tier) belongs to — derive its line, then its map.
## The sell band reads this so later-map harvests sell for more coins (§6).
static func map_for_code(code: int) -> int:
	return map_for_line(int(code / 100.0))

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

## The live generator set for a map: {cell -> id} for each of the map's generators,
## hand-in grants inheriting their lineage cell. The interim "grant on map entry" resolver
## — §7's grant quests will drive the same end state one hand-in at a time.
static func live_gen_state(roster: Array, map: int) -> Dictionary:
	var out: Dictionary = {}
	for g in generators_for_map(roster, map):
		out[gen_cell_of(roster, String(g.id))] = String(g.id)
	return out

# --- the obstacle field (§4): every non-center cell is sealed until the player's Level reaches
# --- its min_level, then opens on the next adjacent merge. `terrain` is a plain sealed flag
# --- (0 = open, >0 = sealed); the gate is the STATIC MIN_LEVEL table, never the stored value —
# --- so legacy saves (old tier-encoded terrain) still read as "sealed" and need no migration.
static func ring_of(cell: Vector2i) -> int:                # Chebyshev distance — the art band only
	return maxi(absi(cell.x - GEN_CELL.x), absi(cell.y - GEN_CELL.y))

## The Level a cell unseals at (§4). 0 = open at start (the center 3×3 + the generator). The
## grove authors a hand-tuned diamond (L2/L3 frontier → L12 corners) in MIN_LEVEL; we read it.
static func cell_min_level(cell: Vector2i) -> int:
	return int(MIN_LEVEL[cell.x][cell.y])

static func open_at_start(cell: Vector2i) -> bool:
	return cell_min_level(cell) == 0

static func bramble_terrain(cell: Vector2i) -> int:        # sealed marker = the min_level (inspectable)
	return cell_min_level(cell)

## A freshly-opened cell's reward item — a low-tier seed of a positional anchor line. The gate is
## level-based now, so contents no longer carry a gate line; derive deterministically (lines 1-2).
static func bramble_contents(cell: Vector2i) -> int:
	var line := 1 + (cell.x + cell.y) % 2
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
		# the featured bonus is coins/premium, NEVER extra ★ (§7): reward.stars is left untouched
		# so level ∝ quests-done holds. A flat coin bonus always; OCCASIONALLY (gem-odds) a small premium.
		reward["coins"] = int(reward.coins) + QUEST_FEATURED_COIN_BONUS
		if rng.randf() < QUEST_FEATURED_GEM_ODDS:
			reward["gems"] = int(reward.get("gems", 0)) + QUEST_FEATURED_GEM_BONUS
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

## The authored great-spirit GATE quest that ends map `map` (§6/§7): asks a randomized handful
## of the map's TOP-TIER harvest (its richest/newest lines at t8 = TOP_TIER) and, delivered,
## unlocks the next map for a large authored reward. Deterministic given `rng`. The one quest
## that asks the ceiling tier (regular quests never do). {asks, gate:true, stars, reward}.
static func gate_quest(roster: Array, map: int, _rng: RandomNumberGenerator = null) -> Dictionary:
	var lines: Array = lines_for_map(roster, map)
	lines.sort()                                       # the richest (newest) lines sit last
	var n: int = mini(GATE_ASK_COUNT, lines.size())
	var pick: Array = lines.slice(lines.size() - n, lines.size())   # the top n (richest) lines
	var gate_t: int = mini(GATE_TIER_BASE + map, TOP_TIER)         # the map's ceiling: t5 (map 1) → t8 (map 4+)
	var asks: Array = []
	for li in pick:
		asks.append({"line": int(li), "tier": gate_t, "count": 1})
	var coins: int = int(quest_reward(asks).coins) + GATE_COIN_BONUS
	return {"asks": asks, "gate": true, "stars": GATE_STARS, "reward": {"stars": GATE_STARS, "coins": coins}}

## Burst-pop (§6): one tap on a generator pops a BURST of items, not just one. The size is a
## FREE portion — the base roll (BURST_ODDS = 1/2/3 items) + a per-map scale-up (every
## BURST_MAP_EVERY maps, generators throw one more) — capped on its OWN at BURST_FREE_MAX, PLUS
## the player's paid burst-upgrade level added on top. Decoupling the paid part from the free cap
## (T25) means every purchased level ALWAYS adds +1 — the free per-map gift can no longer eat the
## paid headroom (the old `clampi(base+free+paid, …, 6)` wasted the top paid levels on deep maps).
## Final clamp to [1, BURST_MAX] is a board-flood safety net. Each popped item still costs 1 energy.
static func burst_count(map: int, upgrade_level: int, rng: RandomNumberGenerator) -> int:
	var base := 1
	var roll := rng.randf()
	var acc := 0.0
	for i in BURST_ODDS.size():
		acc += float(BURST_ODDS[i])
		if roll <= acc:
			base = i + 1
			break
	var free_scale := int(map / float(BURST_MAP_EVERY))     # +1 base burst every N maps…
	var free := mini(base + free_scale, BURST_FREE_MAX)      # …capped on its own, so the gift can't trivialize the board
	var paid := mini(upgrade_level, BURST_UPGRADE_COSTS.size())   # the paid sink — always added on top of the free cap
	return clampi(free + paid, 1, BURST_MAX)

## The burst-upgrade coin sink: the cost to raise the burst from `level` to `level+1`,
## escalating up the BURST_UPGRADE_COSTS ladder. Returns −1 once maxed (no further upgrade).
static func burst_upgrade_cost(level: int) -> int:
	if level >= 0 and level < BURST_UPGRADE_COSTS.size():
		return int(BURST_UPGRADE_COSTS[level])
	return -1

## How many paid burst-upgrade levels exist (the ladder length) — i.e. the max upgrade level.
static func burst_upgrade_max() -> int:
	return BURST_UPGRADE_COSTS.size()

# --- §8/§10 home-hub yield + upgrade-levels (the v1 KEYSTONE coin loop, grove_spec §3) -----
# A restored hub YIELD building sits at L1, then UPGRADES with coins L1→Lⁿ (richer look + higher
# yield); each accrues coins over time to a PER-BUILDING CAP (≈ a day), swept in one collect-on-
# return beat. Data-driven — every number reads the game's HUB_* tables (grove_data). The
# KEYSTONE INVARIANT (extend, never self-sustain): the cap bounds the daily yield well under the
# coin SINK demand (the hub-upgrade ladder it funds + burst + cosmetics). PROVISIONAL feel dials.

## The `kind` of map `z`'s spot `id` — the hub seam: "yield" (coin-producing, coin-upgradable),
## "decor" (style-variant cosmetic, no yield), or "" (a non-hub map's plain restoration spot).
## Reads the spot def off MAPS; "" when the spot/map is unknown (defensive).
static func spot_kind(z: int, spot_id: String) -> String:
	if z < 0 or z >= MAPS.size():
		return ""
	for sp in MAPS[z].spots:
		if String(sp.id) == spot_id:
			return String(sp.get("kind", ""))
	return ""

## Is map `z`'s spot a YIELD building (it accrues coins when restored, and upgrades for more)?
## The single seam the keystone reads — décor + plain spots are false (they never yield).
static func spot_is_yield(z: int, spot_id: String) -> bool:
	return spot_kind(z, spot_id) == "yield"

## The hub's max building level (L1 restore → this cap, via coin upgrades). Reads HUB_MAX_LEVEL.
static func hub_max_level() -> int:
	return int(HUB_MAX_LEVEL)

## The coin YIELD RATE of a yield building at `level`, in 🪙 PER HOUR (0 at L0 = unrestored).
## Clamped to the HUB_YIELD_RATE table so an over-cap level reads the top entry (never crashes).
static func hub_yield_rate(level: int) -> float:
	if HUB_YIELD_RATE.is_empty():
		return 0.0
	return float(HUB_YIELD_RATE[clampi(level, 0, HUB_YIELD_RATE.size() - 1)])

## The per-building ACCRUAL CAP of a yield building at `level`, in 🪙 (≈ a day's worth). Accrual
## clamps here so one building never piles up past ~a day. Clamped to the HUB_YIELD_CAP table.
static func hub_yield_cap(level: int) -> int:
	if HUB_YIELD_CAP.is_empty():
		return 0
	return int(HUB_YIELD_CAP[clampi(level, 0, HUB_YIELD_CAP.size() - 1)])

## The COIN COST to upgrade ONE yield building from `level` to `level+1` (the coin sink with
## teeth). Returns −1 when there is no next level — at/above hub_max_level, or below L1 (L0→L1 is
## the Stars RESTORE, never a coin buy). Mirrors burst_upgrade_cost's "−1 = can't upgrade" contract.
static func hub_upgrade_cost(level: int) -> int:
	if level < 1 or level >= hub_max_level():
		return -1
	if level >= HUB_UPGRADE_COST.size():
		return -1
	var c := int(HUB_UPGRADE_COST[level])
	return c if c > 0 else -1

## The coins ONE yield building at `level` has accrued over `elapsed_secs` since the last collect:
## clamp(rate_per_sec(level) × elapsed, 0, cap(level)), floored to whole coins. Pure (no save read)
## — the testable core of the accrual. A non-yielding level (L0) or non-positive elapsed yields 0.
static func hub_spot_ready(level: int, elapsed_secs: float) -> int:
	if level <= 0 or elapsed_secs <= 0.0:
		return 0
	var per_sec := hub_yield_rate(level) / 3600.0
	return clampi(int(floor(per_sec * elapsed_secs)), 0, hub_yield_cap(level))

## The TOTAL coins ready to collect across ALL restored hub yield buildings, given `unlocks`
## (spot ownership) and the wall-clock `now` (unix secs). Sums hub_spot_ready over every yield
## spot on the hub map that is restored (in unlocks), reading each spot's stored level (Save) and
## the shared elapsed since the last sweep (now − hub_collected_at). The §8 "one beat" total.
## A first-ever call (hub_collected_at == 0) measures from boot 0 → the cap binds it (never a flood).
static func hub_coins_ready(unlocks: Dictionary, now: float) -> int:
	var z := hub_map()
	if z < 0 or z >= MAPS.size():
		return 0
	var elapsed := now - Save.hub_collected_at()
	if elapsed <= 0.0:
		return 0
	var total := 0
	for sp in MAPS[z].spots:
		var sid := String(sp.id)
		if String(sp.get("kind", "")) != "yield":
			continue
		if not unlocks.has(sid):
			continue
		total += hub_spot_ready(Save.spot_level(sid), elapsed)
	return total

## True iff the hub has uncollected yield ready (drives the HUD home-shortcut yield-ready cue).
static func hub_has_yield_ready(unlocks: Dictionary, now: float) -> bool:
	return hub_coins_ready(unlocks, now) > 0

## The hub-collect BEAT (§8): sweep all ready yield to the wallet in one go and reset the clock.
## Credits Save.add_coins(total) + Save.set_hub_collected_at(now) (always resets the clock, even on
## a 0 sweep, so elapsed restarts from this visit). Returns the total collected (0 = nothing ready).
## The caller plays the single satisfying collect FX. Grant + clock-reset land in the save together.
static func hub_collect(unlocks: Dictionary, now: float) -> int:
	var total := hub_coins_ready(unlocks, now)
	if total > 0:
		Save.add_coins(total)
	Save.set_hub_collected_at(now)
	return total

## The TOTAL the hub could yield in a day at FULL upgrade (the keystone-invariant bound, reported by
## the sim): #yield-buildings × the top-level cap. Pure derivation off MAPS + HUB_YIELD_CAP — the
## ceiling the daily hub faucet can never exceed, which must stay ≪ the coin sink demand.
static func hub_max_daily_yield() -> int:
	var z := hub_map()
	if z < 0 or z >= MAPS.size():
		return 0
	var n := 0
	for sp in MAPS[z].spots:
		if String(sp.get("kind", "")) == "yield":
			n += 1
	return n * hub_yield_cap(hub_max_level())

static func map_of_chapter(i: int) -> int:
	var acc := 0
	for z in MAPS.size():
		acc += MAPS[z].spots.size()
		if i < acc:
			return z
	return MAPS.size() - 1

# --- spot level gates -------------------------------------------------------------
static func spot_level_req(z: int, k: int) -> int:
	var rank := k
	for i in z:
		rank += MAPS[i].spots.size()
	return level_for_stars(3 * rank)   # == the old level_for_exp(30·rank); preserves the gates

static func map_spots_done(z: int, unlocks: Dictionary) -> bool:
	for sp in MAPS[z].spots:
		if not unlocks.has(String(sp.id)):
			return false
	return true

static func completed_maps(unlocks: Dictionary) -> int:
	var n := 0
	for z in MAPS.size():
		if map_spots_done(z, unlocks):
			n += 1
	return n

# --- map progression queries (folded from map.gd; the scene keeps thin wrappers) --
static func map_for_id(id: String) -> int:
	for z in MAPS.size():
		if String(MAPS[z].id) == id:
			return z
	return -1

## The index of the home-hub map (the permanent anchor — Core §8 / grove_spec §3). The game
## flags it with `hub: true`; defaults to the first map. Drives the boot landing + the HUD home
## shortcut. (The hub is authored deeper than a finish-once map; its yield loop is the KEYSTONE.)
static func hub_map() -> int:
	for z in MAPS.size():
		if bool(MAPS[z].get("hub", false)):
			return z
	return 0

## A map is fully complete when all its spots are restored AND its great-spirit gate quest
## is delivered (§7) — gate-delivery is tracked in `gates` (map indices). The NEXT map
## unlocks only on it (the completion chain), not merely on spot-completion.
static func map_complete(z: int, unlocks: Dictionary, gates: Array) -> bool:
	return map_spots_done(z, unlocks) and gates.has(z)

static func map_unlocked(z: int, unlocks: Dictionary, gates: Array = []) -> bool:
	return z == 0 or map_complete(z - 1, unlocks, gates)

static func owned_count(z: int, unlocks: Dictionary) -> int:
	var n := 0
	for s in MAPS[z].spots:
		if unlocks.has(String(s.id)):
			n += 1
	return n

static func map_stars_left(z: int, unlocks: Dictionary) -> int:
	var left := 0
	for s in MAPS[z].spots:
		if not unlocks.has(String(s.id)):
			left += int(s.cost)
	return left

static func frontier_map(unlocks: Dictionary, gates: Array = []) -> int:
	for z in MAPS.size():
		if map_unlocked(z, unlocks, gates) and not map_complete(z, unlocks, gates):
			return z
	return -1

## The cheapest unowned, level-affordable spot IN map `z` (the frontier's next restore) — the
## §7 meter sizes the fence to it. Returns the cost, -1 (all of z owned → gate time), or -2
## (all remaining level-locked → keep questing to level up). Map-scoped, so gate-locked later
## maps are never the meter target.
static func map_cheapest_spot(z: int, unlocks: Dictionary, level: int = 99) -> int:
	var cheapest := 99
	var missing := false
	for k in MAPS[z].spots.size():
		var sp: Dictionary = MAPS[z].spots[k]
		if unlocks.has(String(sp.id)):
			continue
		missing = true
		if spot_level_req(z, k) <= level:
			cheapest = mini(cheapest, int(sp.cost))
	if not missing:
		return -1
	return cheapest if cheapest < 99 else -2

## How many ambient characters wander: 1 + completed maps, capped. The host
## passes this to Ambient.build_layer (progression stays a game rule, not engine).
static func character_count(unlocks: Dictionary) -> int:
	return mini(1 + completed_maps(unlocks), CHARACTER_CAP)

static func cheapest_spot_cost(unlocks: Dictionary, level: int = 99) -> int:
	for z in MAPS.size():
		var cheapest := 99
		var missing := false
		for k in MAPS[z].spots.size():
			var s: Dictionary = MAPS[z].spots[k]
			if unlocks.has(String(s.id)):
				continue
			missing = true
			if spot_level_req(z, k) <= level:
				cheapest = mini(cheapest, int(s.cost))
		if missing:
			return cheapest if cheapest < 99 else -2   # -2 = all remaining level-locked
	return -1

# Of the open (unowned, level-affordable) spots in a map, is k the one to buy next?
# Cheapest wins; ties break to the lower index. (Powers the "buy me next" affordance.)
static func is_cheapest_open(z: int, k: int, lvl: int, unlocks: Dictionary) -> bool:
	var my_cost := int(MAPS[z].spots[k].cost)
	for j in MAPS[z].spots.size():
		var s: Dictionary = MAPS[z].spots[j]
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
		rank += MAPS[i].spots.size()
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

## What an item sells for at the merchant (§9): Vector2i(coins, premium). t1–t7 pay their
## tier in coins SCALED by the item's per-map band (§6 — later maps sell for more); t8 stays
## the FLAT 1💎 pinnacle on every map (the 32× anti-arbitrage invariant — only the t1–t7 coin
## reward bands up, never t8→premium). The band is read off SELL_MAP_BAND by the item's map.
static func sell_reward(code: int) -> Vector2i:
	var tier := code % 100
	if tier >= TOP_TIER:
		return Vector2i(0, 1)            # the premium pinnacle — flat 1💎, NEVER banded (32× proof)
	var band: float = sell_map_band(map_for_code(code))
	return Vector2i(int(round(maxi(1, tier) * band)), 0)

## The per-map coin band for `map` (0-indexed), clamped to the table (a map past the table
## reuses the last entry). Owner/sim feel dial; t8 never reads this (it stays flat 1💎).
static func sell_map_band(map: int) -> float:
	if SELL_MAP_BAND.is_empty():
		return 1.0
	return float(SELL_MAP_BAND[clampi(map, 0, SELL_MAP_BAND.size() - 1)])

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
		var lvl_gems := LEVEL_DIAMONDS * gained
		Save.add_diamonds(lvl_gems)
		Vault.skim(lvl_gems)                  # T44 SKIM-SITE 1/3 (level-up): the piggy bank skims a slice of the level-up premium (§10)
	Save.grove_write()
	return gained

static func map_star_total(z: int) -> int:
	var t := 0
	for s in MAPS[z].spots:
		t += int(s.cost)
	return t

static func item_tex_path(code: int) -> String:
	var line := int(code / 100.0)
	var tier := code % 100
	if not LINES.has(line):
		return ""
	return Game.art("items/%s_%d.png" % [LINES[line].base, tier])
