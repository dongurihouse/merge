extends RefCounted
## Explore — the acquire ritual (Load out → Rush → Trade) of the residents expansion.
##
## This is the PURE model + a cross-scene run-state holder; the three Explore screens render over it.
## The Rush board is abstract merge tiles played for SCORE — it is NOT the spirits. Score converts to
## spirits at the Rewards screen via trade_count (floor(score / TRADE_RATE), min 1 if any score).
##
## Numbers are the feel-prototype's PROVISIONAL values (docs/design/prototypes/expedition_rush.html);
## the Rush sim retunes them later (parked).

const G = preload("res://engine/scripts/core/content.gd")
const Save = preload("res://engine/scripts/core/save.gd")

# §1 the DEFAULT MINIMUM coin cost to set off on an expedition — the acquisition coin SINK that gives the
# residents economy a drain (placement/yield/sell only ADD coins; this is the only place they leave). The
# loadout boosts stack ON TOP of this base. PROVISIONAL — the Habitat/economy sim tunes it.
const MIN_COST := 150

# --- Loadout: coin-bought boosts, stacked and consumed per run (added ON TOP of MIN_COST) ----------
const LOADOUT := [
	{"id": "time",  "name": "Lantern",     "eff": "+15s time",        "cost": 120},
	{"id": "drops", "name": "Trail mix",   "eff": "faster drops",     "cost": 100},
	{"id": "calm",  "name": "Calm charm",  "eff": "fewer treefalls",  "cost": 150},
	{"id": "lucky", "name": "Lucky acorn", "eff": "some tier-2 drops", "cost": 180},
	{"id": "focus", "name": "Focus totem", "eff": "only 2 lines",     "cost": 200},
]

# --- Rush feel dials (prototype-locked; the Rush sim retunes these) -------------------------------
const RUSH_LINES := [1, 2, 3]   # board LINE indices — the Rush renders real merge pieces (code = line*100 + tier)
const BASE_TIME := 45.0          # base run length (s); the Lantern boost adds +15
const MAX_TIER := 7              # a tile at MAX_TIER can no longer merge (taps fling instead)
const MULT_CAP := 6.0            # multiplier ceiling
const WARN := 4.0               # treefall telegraph window (s) between warning and the timber landing
const COMBO_WINDOW := 1.5        # a merge within this gap keeps the combo climbing (s)
const COMBO_RESET := 1.7         # idle this long and the combo drops to 0 (s)
const MULT_GRACE := 0.7          # after a merge the multiplier holds for this long before it bleeds (s)
const MULT_DECAY := 0.25         # once past the grace window the multiplier bleeds this much per second

# --- the rush-start teaching image gate ----------------------------------------------------------
const RUSH_INTRO_SHOWS := 1      # show the Rush how-to image on the player's first Rush, then retire it

## Should the rush-start teaching image show, given how many times it has already shown (Save.rush_intro_seen)?
static func rush_intro_should_show(seen: int) -> bool:
	return seen < RUSH_INTRO_SHOWS

const TRADE_RATE := 200          # score → spirits at the Rewards screen: floor(score / TRADE_RATE), min 1 if any score

# === Loadout math ================================================================================
## Total coin cost of the currently-equipped boosts.
static func loadout_cost(equip: Dictionary) -> int:
	var tot := 0
	for it in LOADOUT:
		if bool(equip.get(it.id, false)):
			tot += int(it.cost)
	return tot

## Total coin cost to SET OFF: the default minimum (MIN_COST) plus any equipped boosts.
static func start_cost(equip: Dictionary) -> int:
	return MIN_COST + loadout_cost(equip)

## Can the player afford to set off right now (base minimum + the chosen boosts)?
static func can_start(equip: Dictionary) -> bool:
	return start_cost(equip) <= Save.coins()

## The distinct merge LINES the player has ever SEEN — derived from the saved `seen` set, where each
## key is an item code (line*100 + tier), so the line is `code / 100`. Sorted, deduped; any line ever
## met counts (treats included). This is the Rush's candidate pool.
static func seen_lines(seen: Dictionary) -> Array:
	var out: Array = []
	for k in seen.keys():
		var line := int(int(k) / 100)
		if line > 0 and not out.has(line):
			out.append(line)
	out.sort()
	return out

## Choose up to `count` distinct lines for ONE Rush run from `pool` (the seen lines). A pool smaller
## than `count` plays in full; an empty pool falls back to RUSH_LINES so a brand-new player still gets
## a board. The random draw uses `rng` (seeded in tests for determinism). Returns sorted.
static func pick_rush_lines(pool: Array, count: int, rng: RandomNumberGenerator) -> Array:
	var src: Array = (pool.duplicate() if not pool.is_empty() else RUSH_LINES.duplicate())
	if src.size() <= count:
		return src
	var picked: Array = []
	for _i in count:
		picked.append(src.pop_at(rng.randi() % src.size()))
	picked.sort()
	return picked

## Resolve the equipped boosts into the Rush's config (mirrors the prototype's cfg). `seen` is the
## player's seen-item set (Save.grove()["seen"]) the line pool is drawn from; `rng` picks the run's
## lines (a fresh randomized one when omitted). The focus boost narrows the draw from 3 lines to 2.
static func rush_cfg(equip: Dictionary, seen: Dictionary = {}, rng: RandomNumberGenerator = null) -> Dictionary:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var count := 2 if bool(equip.get("focus", false)) else 3
	return {
		"time": BASE_TIME + (15.0 if bool(equip.get("time", false)) else 0.0),
		"spawn_mul": 0.72 if bool(equip.get("drops", false)) else 1.0,   # <1 = faster drops
		"calm_mul": 2.0 if bool(equip.get("calm", false)) else 1.0,      # >1 = rarer treefalls
		"t2": 0.28 if bool(equip.get("lucky", false)) else 0.0,          # chance a drop arrives at tier 2
		"lines": pick_rush_lines(seen_lines(seen), count, rng),
	}

# === Rush scoring (pure) ========================================================================
## A merge that produces `tier` is worth base = round(10 · 2^(tier-1)) — non-linear, doubling per tier.
static func merge_base(tier: int) -> int:
	return int(round(10.0 * pow(2.0, tier - 1)))

## Points booked for a merge into `tier` at the live `mult`.
static func merge_points(tier: int, mult: float) -> int:
	return int(round(float(merge_base(tier)) * mult))

## Combo climbs when merges chain within COMBO_WINDOW, else restarts at 1.
static func combo_after(prev: int, gap_s: float) -> int:
	return (prev + 1) if gap_s < COMBO_WINDOW else 1

## Multiplier rises a little each merge and a lot when a high tier is built, capped at MULT_CAP.
static func mult_after_merge(mult: float, win_tier: int) -> float:
	var m := minf(MULT_CAP, mult + 0.12)
	if win_tier >= 4:
		m = minf(MULT_CAP, m + 0.3)
	return m

## The multiplier holds for MULT_GRACE after the last merge, then bleeds back toward 1 while you pause.
## `idle_s` is the time since the last merge — active play stays inside the grace window and never loses ground.
static func mult_decay(mult: float, dt: float, idle_s: float) -> float:
	if mult <= 1.0 or idle_s <= MULT_GRACE:
		return mult
	return maxf(1.0, mult - MULT_DECAY * dt)

## Emptying a telegraphed column before the timber lands ("clean dodge") bumps the multiplier.
static func clean_dodge_mult(mult: float) -> float:
	return minf(MULT_CAP, mult + 0.6)

## Drop interval shrinks as the run progresses (the frenzy), scaled by the drops boost.
static func spawn_interval(prog: float, spawn_mul: float) -> float:
	return (1.0 - 0.55 * clampf(prog, 0.0, 1.0)) * spawn_mul

# === Grid helpers (pure) ========================================================================
## The Rush grid is Array[ROWS] of Array[COLS], each cell null or {kind:String, tier:int}.
static func _cols(grid: Array) -> int:
	return (grid[0] as Array).size() if grid.size() > 0 else 0

## The cell of a 4-neighbour matching kind AND tier, or (-1,-1) when there is none.
static func neighbor_match(grid: Array, r: int, c: int) -> Vector2i:
	var t = grid[r][c]
	if t == null:
		return Vector2i(-1, -1)
	var cols := _cols(grid)
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nr := r + d.x
		var nc := c + d.y
		if nr < 0 or nc < 0 or nr >= grid.size() or nc >= cols:
			continue
		var n = grid[nr][nc]
		if n != null and str(n.kind) == str(t.kind) and int(n.tier) == int(t.tier):   # str(): kinds are int line-indices in the Rush (String(int) has no ctor)
			return Vector2i(nr, nc)
	return Vector2i(-1, -1)

## Settle every column so tiles rest at the bottom (in place).
static func gravity(grid: Array) -> void:
	var rows := grid.size()
	var cols := _cols(grid)
	for c in cols:
		var stack := []
		for r in range(rows - 1, -1, -1):
			if grid[r][c] != null:
				stack.append(grid[r][c])
				grid[r][c] = null
		for i in stack.size():
			grid[rows - 1 - i][c] = stack[i]

## How many tiles sit in column `c`.
static func column_fill(grid: Array, c: int) -> int:
	var n := 0
	for r in grid.size():
		if grid[r][c] != null:
			n += 1
	return n

## Columns a flung tile may hop to: not its own, not the telegraphed danger column, not full.
static func fling_target(grid: Array, c: int, danger_col: int, rng: RandomNumberGenerator) -> int:
	var rows := grid.size()
	var safe := []
	for col in _cols(grid):
		if col == c or col == danger_col:
			continue
		if column_fill(grid, col) < rows:
			safe.append(col)
	if safe.is_empty():
		return -1
	return int(safe[rng.randi() % safe.size()])

## How many tiles a timber on column `col` would destroy (0 = a clean dodge).
static func timber_hits(grid: Array, col: int) -> int:
	return column_fill(grid, col)

## Is every cell occupied? (one of the two run-ending conditions; the other is the clock)
static func board_full(grid: Array) -> bool:
	for r in grid.size():
		for c in _cols(grid):
			if grid[r][c] == null:
				return false
	return true

# === Unlocked pool (spirits the Trade screen can award) =========================================
## The resident KINDS the Trade screen can award: the union of each COMPLETED map's offered lines (core + signature).
static func unlocked_pool(unlocks: Dictionary, gates: Array) -> Array:
	var kinds := {}
	for z in G.MAPS.size():
		if not G.can_populate(z, unlocks, gates):
			continue
		for ln in G.resident_lines(z):
			kinds[String(ln.id)] = true
	return kinds.keys()

## Roll one kind from the pool (uniform — rarity parked). "" if the pool is empty.
static func roll_kind(pool: Array, rng: RandomNumberGenerator) -> String:
	if pool.is_empty():
		return ""
	return String(pool[rng.randi() % pool.size()])

# === Run state — carried across the 3 scenes, never persisted ====================================
static var _run: Dictionary = {}

## Start a fresh run with the chosen loadout (score 0).
static func begin_run(equip: Dictionary) -> void:
	_run = {"equip": equip.duplicate(true), "score": 0, "pending": []}

static func run() -> Dictionary:
	return _run

static func score() -> int:
	return int(_run.get("score", 0))

static func add_score(pts: int) -> void:
	_run["score"] = score() + pts

## Convert a run's score to a spirit count for the Rewards screen: floor(score / TRADE_RATE), but at
## least 1 whenever the run scored anything (a run always pays out); 0 only for a literal 0 score.
static func trade_count(score: int) -> int:
	if score <= 0:
		return 0
	return maxi(1, score / TRADE_RATE)
