extends RefCounted
## Content ENGINE (theme-agnostic). The DATA lives in the active game
## (games/<name>/*_data.gd, reached via Game.DATA); this file is the generic
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
const PREMIUM_TIER = D.PREMIUM_TIER
const LINES = D.LINES
const GENERATORS = D.GENERATORS
const APPEAR_ALL := 1 << 30        # sentinel level: "include every generator regardless of appear_level"
const GEN_CELL = D.GEN_CELL
const MIN_LEVEL = D.MIN_LEVEL
const TIER_ODDS = D.TIER_ODDS
const ASK_WEIGHT = D.ASK_WEIGHT
const ASK_TIER_WEIGHT = D.ASK_TIER_WEIGHT   # §6 spawn TIER-bias strength (0 = off; owner pacing dial)
const STAR_CAP = D.STAR_CAP
const QUEST_TIER_BASE = D.QUEST_TIER_BASE
const QUEST_LEVELS_PER_TIER = D.QUEST_LEVELS_PER_TIER
const QUEST_PREMIUM_MIN_LEVEL = D.QUEST_PREMIUM_MIN_LEVEL
const QUEST_PREMIUM_GEMS = D.QUEST_PREMIUM_GEMS
const QUEST_NEWEST_BIAS = D.QUEST_NEWEST_BIAS
const QUEST_FEATURED_RATE = D.QUEST_FEATURED_RATE
const QUEST_FEATURED_COIN_BONUS = D.QUEST_FEATURED_COIN_BONUS
const QUEST_FEATURED_GEM_ODDS = D.QUEST_FEATURED_GEM_ODDS
const QUEST_FEATURED_GEM_BONUS = D.QUEST_FEATURED_GEM_BONUS
const MAX_GIVERS = D.MAX_GIVERS
const STARS_PER_QUEST_EST = D.STARS_PER_QUEST_EST
const GEN_GRANT_REMAINING_STARS = D.GEN_GRANT_REMAINING_STARS
const BURST_ODDS = D.BURST_ODDS
const BURST_MAP_EVERY = D.BURST_MAP_EVERY
const BURST_FREE_MAX = D.BURST_FREE_MAX
const BURST_MAX = D.BURST_MAX
const BURST_UPGRADE_COSTS = D.BURST_UPGRADE_COSTS
const RESIDENT_MAX_TIER = D.RESIDENT_MAX_TIER
const RESIDENT_CORE = D.RESIDENT_CORE
const RESIDENT_ART = D.RESIDENT_ART
const RESIDENT_BASE_COST = D.RESIDENT_BASE_COST
const RESIDENT_PREMIUM_COST = D.RESIDENT_PREMIUM_COST
const STARTER_ITEMS = D.STARTER_ITEMS
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
# --- per-map generator roster (§6) -----------------------------------------------
# A roster is an Array of {id, map, lines:[a,b], cell}. Each generator persists at its
# own authored cell; the next map's generator is granted by a near-end quest (its
# `reward.generators`) into the gen_bag, never handed in. (`grant_from` is now inert
# legacy data, retained on the defs for the deferred roster re-author.) Generators never
# merge to evolve (that mechanic is retired). Pure derivation — the live code passes
# GENERATORS; tests pass a fixture. Replaces appears_at accumulation.
# `level` gates generators that GROW IN later (a def's `appear_level`, default 0 = live at
# start): a generator whose appear_level exceeds the player's Level is not yet on the map, so
# it is excluded from placement (live_gen_state) AND from the askable lines (askable_lines) —
# the two must agree or the fence would ask for a line nothing on the board can produce. The
# default APPEAR_ALL includes every generator (the many callers that don't care about staging).
static func generators_for_map(roster: Array, map: int, level: int = APPEAR_ALL) -> Array:
	var out: Array = []
	for g in roster:
		if int(g.map) == map and int(g.get("appear_level", 0)) <= level:
			out.append(g)
	return out

## The lines LIVE while the player is in `map` — its generators' lines only (older maps'
## lines have retired, §6). The current map's quests draw only from these.
static func lines_for_map(roster: Array, map: int, level: int = APPEAR_ALL) -> Array:
	var out: Array = []
	for g in generators_for_map(roster, map, level):
		for l in g.lines:
			if not out.has(int(l)):
				out.append(int(l))
	return out

## The lines a regular quest may ASK while the player is in `map`: the current map's live lines
## only (`lines_for_map`), sorted. Old-map lines aren't quested — the newest-line bias keeps the
## fence on recent content; old generators stay usable for selling + the collection ladder.
## `level` gates a not-yet-grown generator's lines out (so the fence never asks for what nothing
## can produce yet).
static func askable_lines(roster: Array, map: int, level: int = APPEAR_ALL) -> Array:
	var out: Array = lines_for_map(roster, map, level)
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

## The generator ids that map `map`'s near-end quest should grant: the NEXT map's generators not
## already owned (on the board or in the gen_bag). Empty on the final map or once all are owned.
## Generators now PERSIST (never handed in) — the next map's tool rides on an ordinary near-end
## quest's `reward.generators` and lands in the gen_bag; the player drags it out on the next map.
static func gens_to_grant(roster: Array, map: int, owned: Array) -> Array:
	var out: Array = []
	if map + 1 >= MAPS.size():
		return out
	for g in generators_for_map(roster, map + 1):
		if not owned.has(String(g.id)):
			out.append(String(g.id))
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
## `gen_state` maps cell (Vector2i) -> generator id. Sorted, deduped.
static func gen_live_lines(gen_state: Dictionary, roster: Array) -> Array:
	var out: Array = []
	for cell in gen_state:
		for l in gen_def(roster, String(gen_state[cell])).get("lines", []):
			if not out.has(int(l)):
				out.append(int(l))
	out.sort()
	return out

## The cell a generator occupies — its own authored `cell`. Generators persist (no hand-in
## lineage), so each def carries the cell it lives on.
static func gen_cell_of(roster: Array, id: String) -> Vector2i:
	return gen_def(roster, id).get("cell", Vector2i(-1, -1))

## The live generator set for a map: {cell -> id} for each of the map's generators at their
## own authored cells. Seeds the board's generators (seed_gens) and backs the sim/shot tools.
static func live_gen_state(roster: Array, map: int, level: int = APPEAR_ALL) -> Dictionary:
	var out: Dictionary = {}
	for g in generators_for_map(roster, map, level):
		out[gen_cell_of(roster, String(g.id))] = String(g.id)
	return out

# --- the obstacle field (§4): every non-center cell is sealed until the player's Level reaches
# --- its min_level, then opens on the next adjacent merge. `terrain` is a plain sealed flag
# --- (0 = open, >0 = sealed); the gate is the STATIC MIN_LEVEL table, never the stored value —
# --- so legacy saves (old tier-encoded terrain) still read as "sealed" and need no migration.
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

static func quest_item(q: Dictionary) -> Dictionary:
	if q.has("line"):
		return {"line": int(q.line), "tier": int(q.tier)}
	if q.has("asks") and not q.asks.is_empty():   # tolerate a stale pre-change save
		return {"line": int(q.asks[0].line), "tier": int(q.asks[0].tier)}
	return {}

## The level-based reward: capped stars (§3 pacing), the surplus in coins, premium 💎 at high levels.
## All numbers PROVISIONAL (sim-tuned).
static func quest_reward(level: int) -> Dictionary:
	var r := {"stars": clampi(level, 1, STAR_CAP), "coins": maxi(0, level - STAR_CAP)}
	if level >= QUEST_PREMIUM_MIN_LEVEL:
		r["gems"] = QUEST_PREMIUM_GEMS
	return r

## Weighted random index into the parallel `weights` array (all ≥ 0). Returns -1 when every weight
## is 0. The `weights[i] > 0.0` guard plus the backward-scan fallback make it impossible to return a
## zero-weight entry, so a HARD-excluded candidate is never picked by a float-rounding slip.
static func _weighted_index(weights: Array, rng: RandomNumberGenerator) -> int:
	var total := 0.0
	for w in weights:
		total += float(w)
	if total <= 0.0:
		return -1
	var r := rng.randf() * total
	var acc := 0.0
	for i in weights.size():
		acc += float(weights[i])
		if float(weights[i]) > 0.0 and r <= acc:
			return i
	for i in range(weights.size() - 1, -1, -1):
		if float(weights[i]) > 0.0:
			return i
	return -1

## True when EVERY candidate item's code (line*100+tier) is in `avoid` — i.e. excluding the whole
## avoid set would leave nothing to ask. Used to relax an over-large avoid window on a tiny pool.
static func _all_avoided(items: Array, avoid: Array) -> bool:
	for it in items:
		if not avoid.has(int(it.line) * 100 + int(it.tier)):
			return false
	return true

## Generate a regular quest for a player at `level` from the live lines (§7). A quest is a FLAT
## single item — difficulty rises by higher TIER + more FREQUENT quests (level ∝ quest count, §3).
## The ITEM (line, tier) is drawn from the candidate space of every askable line×tier: a line's tiers
## span [QUEST_TIER_BASE, tier_hi] where tier_hi = clamp(BASE + level/QUEST_LEVELS_PER_TIER, BASE,
## TOP_TIER) — the ceiling climbs with level up to TOP_TIER, which IS askable (no gate-ceiling). Within
## a line the tier is shaped as a NORMAL bell centred on the band midpoint (σ = band-width / 4), so
## asks cluster at mid-difficulty and the centre rises with level as the band widens. Each item's
## weight is its line's newest-bias weight ((rank+1)^QUEST_NEWEST_BIAS) times that bell, so the LINE
## distribution still leans at the richest content.
## `avoid` is a PRIORITY-ORDERED list of recently/concurrently asked ITEM codes (line*100+tier; oldest
## first, freshest + concurrent stands last): each is HARD-excluded (weight 0), so a new ask never
## repeats one of the previous few — variety can come from a different TIER of the same line, not only a
## different line. If the pool is too small to honour the whole window, it relaxes from the oldest end
## until one item is free, so no two asks in a row repeat while >1 item exists (anti-monotony, §7).
## Reward is level-based: stars=min(level,3), coins=max(0,level-3),
## gems at level≥QUEST_PREMIUM_MIN_LEVEL. Deterministic given `rng`. Returns {line, tier, reward, featured}.
## All numbers are PROVISIONAL (Monte-Carlo pass).
static func gen_quest(level: int, live_lines: Array, rng: RandomNumberGenerator, avoid: Array = []) -> Dictionary:
	var lines: Array = live_lines.duplicate()
	lines.sort()                                       # ascending: last entry = newest / highest-value
	var tier_hi: int = clampi(QUEST_TIER_BASE + int(level / float(QUEST_LEVELS_PER_TIER)), QUEST_TIER_BASE, TOP_TIER)
	# Per-tier bell over the band [QUEST_TIER_BASE, tier_hi], shared by every line (no debut cap):
	# weight(t) ∝ exp(-½((t-μ)/σ)²), μ = band midpoint, σ = width/4 (so the floor/ceiling sit ≈2σ out).
	var mu: float = (QUEST_TIER_BASE + tier_hi) / 2.0
	var sigma: float = maxf((tier_hi - QUEST_TIER_BASE) / 4.0, 0.0001)
	var tier_w: Array = []                             # bell weight per tier, indexed t - QUEST_TIER_BASE
	var tier_sum := 0.0
	for t in range(QUEST_TIER_BASE, tier_hi + 1):
		var z: float = (t - mu) / sigma
		var g: float = exp(-0.5 * z * z)
		tier_w.append(g)
		tier_sum += g
	# Candidate ITEMS: every askable line×tier, carrying its line's newest-bias weight × the tier bell
	# (normalised so each line's tiers sum to the line weight — the line distribution is unchanged).
	var items: Array = []
	var base_w: Array = []
	for i in lines.size():
		var ln := int(lines[i])
		var line_w: float = pow(i + 1, QUEST_NEWEST_BIAS)
		for t in range(QUEST_TIER_BASE, tier_hi + 1):
			items.append({"line": ln, "tier": t})
			base_w.append(line_w * tier_w[t - QUEST_TIER_BASE] / tier_sum)
	# Hard-exclude every avoided ITEM. `avoid` is PRIORITY-ORDERED (oldest asks first; the most-recent
	# asks and the concurrent fence stands last). If excluding all of it would leave NO candidate free —
	# the live item pool is smaller than the avoid window, common on an early map with few lines — relax
	# from the FRONT (drop the oldest entries) until one item is free, so the freshest asks stay excluded
	# longest. Guarantees no two asks in a row repeat whenever the pool holds >1 distinct item.
	var eff: Array = avoid.duplicate()
	while not eff.is_empty() and _all_avoided(items, eff):
		eff.pop_front()
	var weights: Array = []
	for i in items.size():
		var it: Dictionary = items[i]
		weights.append(0.0 if eff.has(int(it.line) * 100 + int(it.tier)) else base_w[i])
	var pick: int = _weighted_index(weights, rng)
	if pick < 0:
		pick = 0
	var chosen: Dictionary = items[pick]
	var li := int(chosen.line)
	var tier := int(chosen.tier)
	var reward: Dictionary = quest_reward(tier)
	var featured: bool = rng.randf() < QUEST_FEATURED_RATE
	if featured:
		# the featured bonus is coins/premium, NEVER extra ★ (§7): reward.stars is left untouched
		# so level ∝ quests-done holds. A flat coin bonus always; OCCASIONALLY (gem-odds) a small premium.
		reward["coins"] = int(reward.coins) + QUEST_FEATURED_COIN_BONUS
		if rng.randf() < QUEST_FEATURED_GEM_ODDS:
			reward["gems"] = int(reward.get("gems", 0)) + QUEST_FEATURED_GEM_BONUS
	return {"line": li, "tier": tier, "reward": reward, "featured": featured}

## §7 giver meter: how many giver stands are active for a remaining-cost target —
## ≈ ceil((target − banked) / STARS_PER_QUEST_EST), capped at MAX_GIVERS, and 0 once the target
## is banked. Quests.meter_target sizes the fence to the WHOLE map's remaining stars, so the fence
## stays full through the map and only tapers at the very end. target == -1 (nothing left) → 0.
static func active_giver_count(banked_stars: int, next_cost: int, max_givers: int = MAX_GIVERS) -> int:
	if next_cost == -1:
		return 0
	var need := next_cost - banked_stars
	if need <= 0:
		return 0
	return clampi(int(ceil(need / float(STARS_PER_QUEST_EST))), 1, max_givers)

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

# --- §1 residents: the population sub-game (welcome + auto-merge) ------------------
# Residents are WELCOMED (bought) on a COMPLETED map; two of the same type+tier AUTO-MERGE
# into one a tier up (cascading). The roster is persisted (Save.residents…); the ambient
# display rebuilds from it (stateless), with NO cap. A map is addressed by int `z`; the data
# layer keys by map_id (MAPS[z].id). Cost: coins for core/non-premium, diamonds for premium.

## Can the player welcome residents on map `z`? Only on a fully-completed map (its spots done,
## recorded in `gates`) — the same bar as `map_complete`. (Welcoming lives on the finished map.)
static func can_populate(z: int, unlocks: Dictionary, gates: Array) -> bool:
	return map_complete(z, unlocks, gates)

## The resident types OFFERED on map `z`: the shared core + that map's signature (each a
## Dictionary {id, name, premium?}). Delegates to the game data, addressed by the map's id.
static func resident_lines(z: int) -> Array:
	return D.resident_lines(String(MAPS[z].id))

## The cost to welcome a t1 of `type_def`: {currency, cost}. Premium (signature, marked) types
## cost diamonds (RESIDENT_PREMIUM_COST); everything else costs coins (RESIDENT_BASE_COST).
static func resident_cost(type_def: Dictionary) -> Dictionary:
	if bool(type_def.get("premium", false)):
		return {"currency": "diamonds", "cost": int(RESIDENT_PREMIUM_COST)}
	return {"currency": "coins", "cost": int(RESIDENT_BASE_COST)}

## The res:// art path for a resident `type_id` (reuses the CHARACTER_ART convention via Game.art).
static func resident_art(type_id: String) -> String:
	return Game.art(RESIDENT_ART % type_id)

## Flatten map `z`'s persisted roster into one {type, tier} per resident INSTANCE — what the
## wander layer renders. Stable order: resident_lines order, then tier 1..MAX, pushing one copy
## per counted resident. Reads the counts off Save (no merge here — that's resolve_…).
static func resident_members(z: int) -> Array:
	var map_id := String(MAPS[z].id)
	var out: Array = []
	for type_def in resident_lines(z):
		var tid := String(type_def.id)
		var counts: Array = Save.resident_counts(map_id, tid)
		for t in range(1, RESIDENT_MAX_TIER + 1):
			var n := int(counts[t - 1]) if t - 1 < counts.size() else 0
			for _i in n:
				out.append({"type": tid, "tier": t})
	return out

## Resolve all pending two-of-a-kind merges on map `z`, cascading upward: for each type, for each
## tier below the cap, while ≥2 sit at that tier, consume two and add one a tier up. Persists the
## new counts (Save.set_resident_counts) and returns the merge events [{type, from, to}], in order.
static func resolve_resident_merges(z: int) -> Array:
	var map_id := String(MAPS[z].id)
	var events: Array = []
	for type_def in resident_lines(z):
		var tid := String(type_def.id)
		var counts: Array = Save.resident_counts(map_id, tid).duplicate()
		var changed := false
		for tier in range(1, RESIDENT_MAX_TIER):     # 1..(MAX-1): the top tier never merges further
			while int(counts[tier - 1]) >= 2:
				counts[tier - 1] = int(counts[tier - 1]) - 2
				counts[tier] = int(counts[tier]) + 1
				events.append({"type": tid, "from": tier, "to": tier + 1})
				changed = true
		if changed:
			Save.set_resident_counts(map_id, tid, counts)
	return events

## Welcome (buy) one t1 resident of `type_id` on map `z`: charge the cost (coins or diamonds via
## Save), add one to its t1 count, then resolve cascading merges. Returns {ok, events}: ok=false
## with no events on insufficient funds; ok=true with the merge events on success.
static func welcome_resident(z: int, type_id: String) -> Dictionary:
	var type_def: Dictionary = {}
	for td in resident_lines(z):
		if String(td.id) == type_id:
			type_def = td
			break
	if type_def.is_empty():
		return {"ok": false, "events": []}
	var cost: Dictionary = resident_cost(type_def)
	var paid: bool
	if String(cost.currency) == "diamonds":
		paid = Save.spend_diamonds(int(cost.cost))
	else:
		paid = Save.spend(int(cost.cost), "welcome_resident")
	if not paid:
		return {"ok": false, "events": []}
	var map_id := String(MAPS[z].id)
	var counts: Array = Save.resident_counts(map_id, type_id).duplicate()
	counts[0] = int(counts[0]) + 1
	Save.set_resident_counts(map_id, type_id, counts)
	var events := resolve_resident_merges(z)
	return {"ok": true, "events": events}

static func map_for_spots(i: int) -> int:
	var acc := 0
	for z in MAPS.size():
		acc += MAPS[z].spots.size()
		if i < acc:
			return z
	return MAPS.size() - 1

static func map_spots_done(z: int, unlocks: Dictionary) -> bool:
	# A map with no spots has nothing restored yet, so it is NOT "done". This guards the region-less
	# vine map (a registered map whose regions aren't authored yet, shown as clean base art): without
	# it, a spot-less map would read as vacuously complete and wrongly pay the map reward, get added to
	# `gates`, unlock the next map, and invite residents. Every legacy map ships 8 spots, so this only
	# affects an as-yet-unauthored vine map.
	if MAPS[z].spots.is_empty():
		return false
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

## A map is fully complete when all its spots are restored AND that completion is recorded in
## `gates` (map indices) — the record now sets automatically the moment the map's spots are done
## (the gate QUEST is retired). The NEXT map unlocks on it (the completion chain).
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

## The cheapest unowned spot IN map `z` (the frontier's next restore) — the §7 meter sizes the
## fence to it. Returns the cost, or -1 (all of z owned → gate time). Map-scoped, so gate-locked
## later maps are never the meter target.
static func map_cheapest_spot(z: int, unlocks: Dictionary) -> int:
	var cheapest := 99
	for k in MAPS[z].spots.size():
		var sp: Dictionary = MAPS[z].spots[k]
		if unlocks.has(String(sp.id)):
			continue
		cheapest = mini(cheapest, int(sp.cost))
	return cheapest if cheapest < 99 else -1

## How many ambient characters wander: 1 + completed maps, capped. The host
## passes this to Ambient.build_layer (progression stays a game rule, not engine).
static func character_count(unlocks: Dictionary) -> int:
	return mini(1 + completed_maps(unlocks), CHARACTER_CAP)

static func cheapest_spot_cost(unlocks: Dictionary) -> int:
	for z in MAPS.size():
		var cheapest := 99
		var missing := false
		for k in MAPS[z].spots.size():
			var s: Dictionary = MAPS[z].spots[k]
			if unlocks.has(String(s.id)):
				continue
			missing = true
			cheapest = mini(cheapest, int(s.cost))
		if missing:
			return cheapest
	return -1

# Of the open (unowned) spots in a map, is k the one to buy next?
# Cheapest wins; ties break to the lower index. (Powers the "buy me next" affordance.)
static func is_cheapest_open(z: int, k: int, unlocks: Dictionary) -> bool:
	var my_cost := int(MAPS[z].spots[k].cost)
	for j in MAPS[z].spots.size():
		var s: Dictionary = MAPS[z].spots[j]
		if unlocks.has(String(s.id)):
			continue
		if int(s.cost) < my_cost or (int(s.cost) == my_cost and j < k):
			return j == k
	return true

# --- sell / economy formulas ------------------------------------------------------
static func sell_value(code: int) -> int:
	return maxi(1, code % 100)            # t1=1 … tN=N coins

## What an item sells for at the merchant (§9): Vector2i(coins, premium). Every tier below TOP_TIER
## pays its tier in coins SCALED by the item's per-map band (§6 — later maps sell for more); TOP_TIER
## stays the FLAT 1💎 pinnacle on every map (the anti-arbitrage invariant — only the sub-pinnacle coin
## reward bands up, never the pinnacle→premium). The band is read off SELL_MAP_BAND by the item's map.
static func sell_reward(code: int) -> Vector2i:
	var tier := code % 100
	if tier == PREMIUM_TIER:
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
	return int(pow(2, PREMIUM_TIER - 1))
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
# drives Level. Returns the levels gained so the caller can show the Level dialog. The
# level-up GIFT is no longer granted here — it's DEFERRED to the dialog's Collect (see
# level_gift / grant_level_gift below), so the interruption pays out. The sole way Level advances.
static func earn_stars(n: int) -> int:
	Save.add_stars(n)
	var g := Save.grove()
	var earned := int(g.get("stars_earned", 0))
	var before := level_for_stars(earned)
	earned += n
	g["stars_earned"] = earned
	var gained := level_for_stars(earned) - before
	Save.grove_write()
	return gained

# The water + diamond gift for `levels` levels gained (PURE — no side effects). The Level dialog shows
# it; the player collects it. Split out of earn_stars so the level-up interruption pays out on Collect.
static func level_gift(levels: int) -> Dictionary:
	var n := maxi(0, levels)
	return {"water": LEVEL_WATER_GIFT * n, "gems": LEVEL_DIAMONDS * n}

# Apply a level_gift: water (capped), diamonds, and the piggy-bank skim. Called by the Level dialog's
# Collect button (the deferred grant — what earn_stars used to do inline).
static func grant_level_gift(gift: Dictionary) -> void:
	var water := int(gift.get("water", 0))
	var gems := int(gift.get("gems", 0))
	if water <= 0 and gems <= 0:
		return
	var g := Save.grove()
	g["water"] = mini(WATER_CAP, int(g.get("water", WATER_CAP)) + water)
	Save.grove_write()
	if gems > 0:
		Save.add_diamonds(gems)
		Vault.skim(gems)                      # T44 SKIM-SITE 1/3 (level-up): the piggy bank skims a slice of the level-up premium (§10)

static func item_tex_path(code: int) -> String:
	var line := int(code / 100.0)
	var tier := code % 100
	if not LINES.has(line):
		return ""
	return Game.art("items/%s/%s_%d.png" % [LINES[line].base, LINES[line].base, tier])
