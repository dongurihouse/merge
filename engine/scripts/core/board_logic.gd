extends RefCounted
## Pure board-run logic — the decisions the persistent BoardModel doesn't own
## (water regen, the merge-hint search, distances, bag size). Backend layer:
## STATELESS statics that take data in and return data out — no Node/Control,
## no Save access. The scene reads Save and animates around these results.
## Layering: core/ never imports ui/ or scenes/ — see docs/design/merge_spec.md §15.

const G = preload("res://engine/scripts/core/content.gd")
const BoardModel = preload("res://engine/scripts/core/board_model.gd")

# Offline + online water regen share one rule: +1 per REGEN_SECS from the anchor,
# capped. Returns the updated {water, regen_ts}; the caller assigns them back.
static func regen(water: int, regen_ts: float, now: float) -> Dictionary:
	if water >= G.WATER_CAP:
		return {"water": water, "regen_ts": now}
	var gained := int((now - regen_ts) / G.REGEN_SECS)
	if gained > 0:
		water = mini(G.WATER_CAP, water + gained)
		regen_ts = now if water >= G.WATER_CAP else regen_ts + gained * G.REGEN_SECS
	return {"water": water, "regen_ts": regen_ts}

# First mergeable pair on the board (same code, not yet at its top tier), in
# board-index order. Returns [cell_a, cell_b], or [] if none. Pure search — the
# scene rocks the returned cells; the idle_hint feature gate stays in the scene.
static func find_mergeable_pair(board: BoardModel) -> Array:
	var seen := {}
	for i in board.items.size():
		var k: int = board.items[i]
		if k <= 0:
			continue
		var top: int = G.COIN_TOP if G.is_coin(k) else G.TOP_TIER
		if BoardModel.tier_of(k) >= top:
			continue
		if seen.has(k):
			return [seen[k], BoardModel.cell_of(i)]
		seen[k] = BoardModel.cell_of(i)
	return []

# §2 seam (pure, headless-testable): the sealed cells the hinted pair would open.
# A merge can land on EITHER cell of the pair, so we union the level-reached sealed
# neighbours of both (deduped). Empty pair, or nothing level-reached adjacent → []. The
# merge is the trigger; player_level gates WHEN a neighbour is eligible (§4, openable_brambles).
static func openable_for_hint(model: BoardModel, pair: Array, player_level: int) -> Array:
	var out: Array = []
	for cell in pair:
		for n in model.openable_brambles(cell, player_level):
			if not out.has(n):
				out.append(n)
	return out

# Manhattan distance between two cells.
static func dist_to(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

# Manhattan distance from a cell to the default generator cell.
static func dist_to_gen(cell: Vector2i) -> int:
	return dist_to(cell, G.GEN_CELL)

# Bag slots (§5): the OWNED slot count (persisted, 6 at start, bought up to 18 with 💎),
# clamped to the legal band. The scene reads Save.bag_slots() and passes it in; this keeps
# the bound enforced in one pure, headless-testable place even if a save is hand-edited.
static func bag_capacity(owned: int) -> int:
	return clampi(owned, G.BAG_START_SLOTS, G.BAG_MAX_SLOTS)

# The generator's lines that some active quest currently asks for (a subset of pool).
static func wanted_lines(pool: Array, quests: Array) -> Array:
	var wanted: Array = []
	for q in quests:
		for ask in G.quest_asks(q):
			if pool.has(int(ask.line)) and not wanted.has(int(ask.line)):
				wanted.append(int(ask.line))
	return wanted

# The spawn roll: a landing cell (one of the few nearest the generator, then random)
# and a code (line*100 + tier). `wanted` lines win with odds ASK_WEIGHT, else any of
# the generator's `pool`; tier comes off TIER_ODDS. RNG ORDER IS LOAD-BEARING (the rng
# is seeded + persisted): cell pick, then [ask-weight, line], then tier. `empties` is
# not mutated.
static func roll_spawn(empties: Array, gen_cell: Vector2i, pool: Array, wanted: Array, rng: RandomNumberGenerator) -> Dictionary:
	var es := empties.duplicate()
	es.sort_custom(func(a, b): return absi(a.x - gen_cell.x) + absi(a.y - gen_cell.y) < absi(b.x - gen_cell.x) + absi(b.y - gen_cell.y))
	var pick: Vector2i = es[rng.randi_range(0, mini(2, es.size() - 1))]
	var line: int
	if not wanted.is_empty() and rng.randf() < G.ASK_WEIGHT:
		line = wanted[rng.randi_range(0, wanted.size() - 1)]
	else:
		line = int(pool[rng.randi_range(0, pool.size() - 1)])
	var roll := rng.randf()
	var tier := 1
	var acc := 0.0
	for i in G.TIER_ODDS.size():
		acc += G.TIER_ODDS[i]
		if roll <= acc:
			tier = i + 1
			break
	return {"cell": pick, "code": line * 100 + tier}

# A merge sometimes shakes a coin loose (never off a coin). RNG: one randf, taken
# only when `produced` isn't already a coin (the short-circuit is preserved).
static func rolls_coin_drop(produced: int, rng: RandomNumberGenerator) -> bool:
	return not G.is_coin(produced) and rng.randf() < G.COIN_DROP_RATE

# A quest delivers all-or-nothing: every ask must be fully present on the board.
static func quest_payable(board: BoardModel, asks: Array) -> bool:
	for ask in asks:
		if board.count_of(int(ask.line) * 100 + int(ask.tier)) < int(ask.count):
			return false
	return true
