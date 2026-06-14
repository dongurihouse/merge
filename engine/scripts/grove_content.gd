extends RefCounted
## Ghibli Grove — P1 content config (TIDY_UP_V2_SPEC). Item lines, the bramble
## field, the generator's dispensing policy numbers, and the chaptered quest
## script for map 1's opening chapters. All deterministic, all placeholder-tuned
## (the P2 sim owns the real numbers).

const Game = preload("res://engine/scripts/game.gd")

const COLS := 7
const ROWS := 9
const TOP_TIER := 8

# Lines: code = line*100 + tier. Art auto-loads res://assets/items/<base>_<tier>.png
const LINES := {
	1: {"name": "Wildflower", "base": "flower", "color": Color("#D98BA3")},
	2: {"name": "Berry", "base": "berry", "color": Color("#7FB4D9")},
	3: {"name": "Mushroom", "base": "mushroom", "color": Color("#C9A66B")},
	4: {"name": "Honey", "base": "honey", "color": Color("#E3B23C")},
}

# Generators ARE the complexity curve (spec §2): the satchel from chapter 0; later
# generators REVEAL themselves in the bramble field as their era begins (each line
# debuts WITH its generator, and new asks for it follow — owner 2026-06-11: by the
# end game several generators share the board and the edge brambles need them).
# appears_at is a chapter index (chapter = home spots bought).
const GENERATORS := [
	{"id": "satchel", "cell": Vector2i(4, 3), "lines": [1, 2], "appears_at": 0,
		"tex": "ui/gen_satchel.png", "label": "seeds"},   # rel to the active game's art root (resolve via Game.art)
	{"id": "compost", "cell": Vector2i(2, 1), "lines": [3], "appears_at": 16,
		"tex": "ui/gen_compost.png", "label": "compost"},
	{"id": "beehive", "cell": Vector2i(6, 5), "lines": [4], "appears_at": 26,
		"tex": "ui/gen_beehive.png", "label": "hive"},
]
const GEN_CELL := Vector2i(4, 3)          # the starter satchel (kept for the open-3x3 math)

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

const TIER_ODDS := [0.65, 0.25, 0.09, 0.01]   # pop tier 1..4, decaying (sim-tuned later)
const ASK_WEIGHT := 0.6                   # mild lean toward lines the givers want

# Brambles: a cell's terrain value encodes WHAT adjacent merge opens it:
#   terrain = gate_line * 16 + required_tier   (gate_line 0 = any line)
# (legacy saves stored the bare tier 1-5 — those decode as line 0, unchanged.)
# The FIRST frontier opens on ANY merge (produced >= 2). The board's edge is the
# END GAME (owner 2026-06-11): outer rings demand HIGH tiers from the LATER
# generators' lines, so fully opening the board tracks the generator curve —
# the top edge wants mushrooms (compost), the bottom edge wants honey (beehive).
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

# Deterministic bramble contents: a low-tier item — of the gate's line when the
# bramble is line-gated (opening the edge seeds its own late line), else 1/2.
static func bramble_contents(cell: Vector2i) -> int:
	var gate_line := bramble_gate(cell).x
	var line := gate_line if gate_line > 0 else 1 + (cell.x + cell.y) % 2
	var tier := 1 + (cell.x * 3 + cell.y) % 2     # t1 or t2
	return line * 100 + tier

# Starter items on the open 3x3 (besides the generator cell).
const STARTER_ITEMS := {
	Vector2i(3, 2): 101, Vector2i(3, 4): 101,
	Vector2i(5, 2): 201, Vector2i(5, 4): 201,
	Vector2i(4, 2): 101, Vector2i(4, 4): 201,
}

# --- the chaptered quest script (P4: the FULL map) ---------------------------------
# CHAPTER = HOME SPOTS BOUGHT (one chapter per spot — buying a spot IS the gate;
# the board's givers pause when stars afford the frontier zone's cheapest spot).
# Chapters expand DETERMINISTICALLY from the per-zone ramp below (no RNG — fixed
# arithmetic patterns), so two players at the same spot count see the same asks.
# quests: {line, tier, count, stars}; stars 1-2 (owner rule: t4+/multi-item = 2);
# slack = skippable quests per chapter; gift = water paid when the spot is bought
# (sim-checked < WATER_REWARD_MAX_RATIO of the chapter's measured spend).
# quests 5-6/chapter w/ slack so the REQUIRED four always include >=2 two-star asks
# (worst case 1+1+2+2 = 6* >= the dearest 5* spot — the affordability test proves it)
const ZONE_RAMP := [
	{"tiers": Vector2i(2, 4), "quests": 5, "slack": 1, "two_count_every": 0, "gift": 0},
	{"tiers": Vector2i(3, 5), "quests": 5, "slack": 1, "two_count_every": 0, "gift": 0},
	{"tiers": Vector2i(3, 5), "quests": 5, "slack": 1, "two_count_every": 3, "gift": 0},
	{"tiers": Vector2i(4, 6), "quests": 5, "slack": 1, "two_count_every": 2, "gift": 4},
	{"tiers": Vector2i(5, 7), "quests": 6, "slack": 2, "two_count_every": 2, "gift": 5},
]

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
		# X2: the multi-LINE STRETCH quests ride FIRST (always visible to the player)
		# but are PURE ADDITIONS — slack grows to cover them, so the REQUIRED single-ask
		# path below is byte-for-byte the tested curve, and the affordability proof
		# (cheapest `needed` payouts) is unchanged. They pay 2-3★ for going faster.
		var n_stretch := _stretch_count(z)
		for sidx in n_stretch:
			var sa := _stretch_asks(z, i, sidx, lines, lo, hi)
			quests.append({"asks": sa, "stars": _quest_stars(sa, lo)})
		# the REQUIRED ramp quests — single-ask, UNCHANGED from the proven curve
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

# X1: every reader goes through this — a quest is `{asks:[{line,tier,count}], stars}`.
# Legacy single-ask `{line,tier,count}` decodes as one entry (in-memory compat; SAVES
# never store quest defs — only the per-quest `qdone` booleans — so the schema change
# does not touch persistence).
static func quest_asks(q: Dictionary) -> Array:
	if q.has("asks"):
		return q.asks
	return [{"line": int(q.line), "tier": int(q.tier), "count": int(q.get("count", 1))}]

# X2: how many multi-LINE STRETCH quests a chapter carries (0 in zones 1-2).
#   zone 3 (compost era): one 2-line stretch.   zone 4: one 3-line stretch.
#   zone 5: two stretch quests (a 2-line and a 3-line). Slack grows to match, so they
#   are always skippable and the required path is unchanged. (t8 never appears — no
#   band reaches it; it is the diamond pinnacle, order Y1.)
static func _stretch_count(z: int) -> int:
	if z <= 1:
		return 0
	if z >= 4:
		return 2
	return 1

# X2: the asks for stretch quest `sidx` — cross-generator lines at band tiers.
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

# X2: multi-ask pays MORE — a single floor-tier ask = 1★, a harder single ask = 2★,
# two asks = 2★, three asks = 3★ (3★ is NEW). Stars never DECREASE vs the old single-
# ask rule, so the cumulative affordability proof can only hold or improve.
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

# --- spot level gates (owner 2026-06-11: items around the house unlock by level) ----
# A spot's gate = the level a WORST-CASE player provably has after buying as many
# spots as the spot's global rank (min spot = 3★ = 30 exp). Pigeonhole: with k
# spots bought there's always an unbought spot of rank <= k, whose gate is
# already met — level gating can never strand the player (test-proven).
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

## Completed zones drive ambient life (order L): more restoration, more spirits.
static func completed_zones(unlocks: Dictionary) -> int:
	var n := 0
	for z in ZONES.size():
		if zone_done(z, unlocks):
			n += 1
	return n

# --- Z: the coin SINK — wayside decorations (cosmetic, COIN-priced, NEVER a gate) --
# 4 path-side plots unlock per RESTORED zone (zone_done), priced 40-150🪙 one-time.
# Pure cosmetics: level-gate-free, in no unlock chain (Z4 asserts this). map_pos is
# PROVISIONAL — the owner sets finals with the placement tool (spec §0c #12).
const WAYSIDE_PROPS := ["Lantern post", "Bird bath", "Flower tub", "Mossy bench", "Beehive skep", "Stone cairn"]
const WAYSIDE_TEX := ["way_lantern", "way_birdbath", "way_flowertub", "way_bench", "way_skep", "way_cairn"]
const WAYSIDE_PER_ZONE := 4

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
				"cost": 40 + gi * 6,        # 40 … 154 🪙 (rising) — sum ≈ the sink capacity
				"map_pos": Vector2(0.12 + k * 0.24, 0.16 + (z % 5) * 0.165),   # PROVISIONAL
				"zone_req": z,              # this plot opens once zone z is fully restored
			})
	_waysides_cache = out
	return out

static func wayside_sink_capacity() -> int:
	var s := 0
	for w in waysides():
		s += int(w.cost)
	return s

# A wayside plot is AVAILABLE (a coin-pin) once its zone is restored; until then the
# plot is dormant (greyed). Buying is COIN-only — never level-gated, never progression.
static func wayside_available(w: Dictionary, unlocks: Dictionary) -> bool:
	return zone_done(int(w.zone_req), unlocks)

# The board gate: cheapest unowned spot in the frontier zone that the player's
# LEVEL allows (-1 = map done). Givers must never pause for an unbuyable spot.
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

# --- spot customizations (owner 2026-06-11: after purchase, the SAME item offers
# variants — some priced in coins, some in diamonds). Deterministic per spot.
const VARIANT_NAMES_COIN := ["Rosewood", "Whitewash", "Mossy", "Sunbaked", "Riverstone"]
const VARIANT_NAMES_GEM := ["Gilded", "Moonlit", "Blossom", "Starlit", "Amber"]
const VARIANT_TINTS_COIN := [Color("#C96F4A"), Color("#EDE3D2"), Color("#7FA65A"), Color("#E3B23C"), Color("#9CB8C9")]
const VARIANT_TINTS_GEM := [Color("#E8C84A"), Color("#BFD9F2"), Color("#E8A8C0"), Color("#D9C9F2"), Color("#E8B06A")]

static func spot_variants(z: int, k: int) -> Array:
	var rank := k
	for i in z:
		rank += ZONES[i].spots.size()
	var coin_cost := 25 + z * 15 + (k % 3) * 5        # 25..95 — real pocket-change sinks
	var gem_cost := 2 + int(z / 2.0)                  # 2..4💎 — a meaningful treat
	return [
		{"id": "base", "name": "Classic", "currency": "", "cost": 0, "tint": Color.WHITE},
		{"id": "coin", "name": VARIANT_NAMES_COIN[rank % VARIANT_NAMES_COIN.size()],
			"currency": "coins", "cost": coin_cost, "tint": VARIANT_TINTS_COIN[rank % VARIANT_TINTS_COIN.size()]},
		{"id": "gem", "name": VARIANT_NAMES_GEM[rank % VARIANT_NAMES_GEM.size()],
			"currency": "diamonds", "cost": gem_cost, "tint": VARIANT_TINTS_GEM[rank % VARIANT_TINTS_GEM.size()]},
	]

const MERCHANT_COINS := 25                # per top-tier item taken (the proud trade)

# Sell ANYTHING (owner-final): drag any item onto the cart → tier-scaled pocket
# change. Far below invested water — cleanup, never income. Water is THE friction.
static func sell_value(code: int) -> int:
	return maxi(1, code % 100)            # t1=1 … t8=8 coins

# Y1: the sell REWARD as (coins, diamonds). The PINNACLE (t8) trades for 1💎; t1-t7
# keep 1-7🪙. The water↔diamond round trip is provably un-abusable: earning 1💎 (one
# t8) costs ~2^(TOP_TIER-1) water of pops, but 1💎 buys only WATER_CAP/REFILL_DIAMOND_COST
# water — a >=10x loss (sim/test-asserted, not just commented; see Y4).
static func sell_reward(code: int) -> Vector2i:
	var tier := code % 100
	if tier >= TOP_TIER:
		return Vector2i(0, 1)            # the diamond pinnacle
	return Vector2i(maxi(1, tier), 0)

# Y4 invariant, computed (not hard-coded): water to EARN 1💎 vs water 1💎 BUYS.
static func water_to_earn_diamond() -> int:
	return int(pow(2, TOP_TIER - 1))     # a t8 = 2^7 t1 pops, 1 water each
static func water_a_diamond_buys() -> int:
	return int(WATER_CAP / float(REFILL_DIAMOND_COST))

# --- diamonds (P5 — earned-only; the future monetization socket) -------------------
const LEVEL_DIAMONDS := 3                 # per level-up
const ZONE_DIAMONDS := 10                 # per zone fully restored
const REFILL_DIAMOND_COST := 25           # paid rain, once the free refills are spent
const BAG3_DIAMOND_COST := 10             # the third bag slot

# --- water (the pacing friction — P2; EconConfig v2 lives here) -------------------
const WATER_CAP := 100
const REGEN_SECS := 120                   # +1 water per 2 min, offline included
const POP_COST := 1
const FREE_REFILLS := 3                   # lifetime, on the first empties (FTUE)
const WINBACK_HOURS := 48                 # away >= this → full cap ("it rained")
const WATER_REWARD_MAX_RATIO := 0.3       # invariant: chapter water rewards < 30% of cost

# --- coins on the board (P2) ------------------------------------------------------
const COIN_LINE := 9                      # code 9xx; never popped, never asked
const COIN_TOP := 3
const COIN_VALUES := {1: 1, 2: 5, 3: 25}  # tap-collect value per coin tier
const COIN_DROP_RATE := 0.10              # chance a merge also drops a c1

static func is_coin(code: int) -> bool:
	return int(code / 100.0) == COIN_LINE

static func coin_value(code: int) -> int:
	return int(COIN_VALUES.get(code % 100, 0))

# --- the home map: zones + unlock spots (P3; map rework owner 2026-06-11) ---------
# ONE large free-pan map (both axes). The art is EMPTY top-down terrain
# (res://assets/rooms/map_grove.png) — zones are NOT baked in; each is a point of
# interest (res://assets/map/poi_<zone_id>.png) placed at map_pos (normalized on
# MAP_SIZE) so WE choose the locations. Locked zones render greyed-out on the map.
# M re-fit: each map_pos is the MEASURED centroid of a painted clearing on
# map_grove.png (erode the paths, blob the cores) — POIs sit ON the clearings.
# Zones open sequentially (owner): a zone unlocks when the previous zone's spots
# are ALL bought. Spot costs 3-5★ (owner pacing); each unlock grants
# cost*EXP_PER_STAR exp. pos = the spot's place on the zone's roof-off close-up.
const MAP_SIZE := Vector2(2160, 2880)     # 2× the portrait viewport each axis
const POI_SIZE := 300.0                   # a building sprite's footprint on the map
const ZONES := [
	{"id": "farmhouse", "name": "The Farmhouse", "map_pos": Vector2(0.230, 0.760), "spots": [
		# Q placement law (§0c #11): floor objects only; hearth is baked architecture
		# now → Storage chest. pos here is v1-era; Q3 re-fits when v2 art lands.
		{"id": "fh_chest", "name": "Storage chest", "cost": 3, "pos": Vector2(0.33, 0.49), "fsize": 230},
		{"id": "fh_bed", "name": "Quilted bed", "cost": 3, "pos": Vector2(0.70, 0.50), "fsize": 380},
		{"id": "fh_table", "name": "Oak table", "cost": 3, "pos": Vector2(0.45, 0.60), "fsize": 320},
		{"id": "fh_rug", "name": "Braided rug", "cost": 4, "pos": Vector2(0.47, 0.67), "fsize": 320},
		{"id": "fh_plant", "name": "Potted fern", "cost": 4, "pos": Vector2(0.84, 0.56), "fsize": 170},
		{"id": "fh_wheel", "name": "Spinning wheel", "cost": 4, "pos": Vector2(0.30, 0.66), "fsize": 250},
		{"id": "fh_chair", "name": "Rocking chair", "cost": 5, "pos": Vector2(0.17, 0.52), "fsize": 230},
		{"id": "fh_picture", "name": "Framed painting", "cost": 5, "pos": Vector2(0.37, 0.34), "fsize": 190},
	]},
	{"id": "barn", "name": "The Barn", "map_pos": Vector2(0.737, 0.814), "spots": [
		# Q law: doors/loft/stalls are architecture → baked into barn room art when
		# ordered; the floor-standing objects replace them. pos is v1-era (Q3 re-fit).
		{"id": "bn_bales", "name": "Hay bales", "cost": 3, "pos": Vector2(0.30, 0.55)},
		{"id": "bn_stool", "name": "Milking stool", "cost": 4, "pos": Vector2(0.55, 0.30)},
		{"id": "bn_churns", "name": "Milk churns", "cost": 4, "pos": Vector2(0.70, 0.62)},
		{"id": "bn_trough", "name": "Water trough", "cost": 4, "pos": Vector2(0.25, 0.80)},
		{"id": "bn_lantern", "name": "Lantern post", "cost": 4, "pos": Vector2(0.45, 0.20)},
		{"id": "bn_cart", "name": "Hay cart", "cost": 5, "pos": Vector2(0.80, 0.78)},
		{"id": "bn_coop", "name": "Hen coop", "cost": 5, "pos": Vector2(0.15, 0.40)},
		{"id": "bn_plow", "name": "Old plow", "cost": 5, "pos": Vector2(0.60, 0.85)},
	]},
	{"id": "pond", "name": "The Pond", "map_pos": Vector2(0.516, 0.446), "spots": [
		{"id": "pd_dock", "name": "Little dock", "cost": 4, "pos": Vector2(0.30, 0.60)},
		{"id": "pd_lilies", "name": "Lily pads", "cost": 4, "pos": Vector2(0.60, 0.70)},
		{"id": "pd_reeds", "name": "Reeds", "cost": 4, "pos": Vector2(0.20, 0.35)},
		{"id": "pd_bench", "name": "Mossy bench", "cost": 4, "pos": Vector2(0.75, 0.40)},
		{"id": "pd_stones", "name": "Stepping stones", "cost": 5, "pos": Vector2(0.45, 0.85)},
		{"id": "pd_willow", "name": "Willow", "cost": 5, "pos": Vector2(0.85, 0.25)},
		{"id": "pd_boat", "name": "Rowboat", "cost": 5, "pos": Vector2(0.55, 0.45)},
		{"id": "pd_fireflies", "name": "Firefly jar", "cost": 5, "pos": Vector2(0.15, 0.75)},
	]},
	{"id": "orchard", "name": "The Orchard", "map_pos": Vector2(0.738, 0.210), "spots": [
		{"id": "or_rows", "name": "Apple rows", "cost": 4, "pos": Vector2(0.30, 0.50)},
		{"id": "or_ladder", "name": "Picker's ladder", "cost": 4, "pos": Vector2(0.55, 0.35)},
		{"id": "or_baskets", "name": "Fruit baskets", "cost": 4, "pos": Vector2(0.70, 0.70)},
		{"id": "or_press", "name": "Cider press", "cost": 5, "pos": Vector2(0.25, 0.80)},
		{"id": "or_hives", "name": "Beehives", "cost": 5, "pos": Vector2(0.80, 0.45)},
		{"id": "or_swing", "name": "Tree swing", "cost": 5, "pos": Vector2(0.45, 0.20)},
		{"id": "or_scarecrow", "name": "Scarecrow", "cost": 5, "pos": Vector2(0.15, 0.30)},
		{"id": "or_wagon", "name": "Apple wagon", "cost": 5, "pos": Vector2(0.60, 0.85)},
	]},
	{"id": "meadow", "name": "The Meadow", "map_pos": Vector2(0.242, 0.117), "spots": [
		{"id": "md_path", "name": "Wildflower path", "cost": 4, "pos": Vector2(0.35, 0.60)},
		{"id": "md_picnic", "name": "Picnic blanket", "cost": 4, "pos": Vector2(0.60, 0.75)},
		{"id": "md_kite", "name": "Kite", "cost": 5, "pos": Vector2(0.70, 0.25)},
		{"id": "md_brook", "name": "Brook bridge", "cost": 5, "pos": Vector2(0.25, 0.40)},
		{"id": "md_stand", "name": "Lemonade stand", "cost": 5, "pos": Vector2(0.80, 0.55)},
		{"id": "md_garden", "name": "Secret garden", "cost": 5, "pos": Vector2(0.15, 0.75)},
		{"id": "md_telescope", "name": "Stargazer", "cost": 5, "pos": Vector2(0.50, 0.30)},
		{"id": "md_arch", "name": "Rose arch", "cost": 5, "pos": Vector2(0.45, 0.85)},
	]},
]

const EXP_PER_STAR := 10
# cumulative exp thresholds per level (L1 at 0); each level-up gifts water
const LEVEL_XP := [0, 60, 140, 240, 360, 500, 660, 840, 1040, 1260]
const LEVEL_WATER_GIFT := 20

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
