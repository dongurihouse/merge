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
		if BoardModel.tier_of(k) >= G.merge_top(k):
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

# Bag slots (§5): the OWNED slot count (persisted, 6 at start, bought up to 18 with 💎),
# clamped to the legal band. The scene reads Save.bag_slots() and passes it in; this keeps
# the bound enforced in one pure, headless-testable place even if a save is hand-edited.
static func bag_capacity(owned: int) -> int:
	return clampi(owned, G.BAG_START_SLOTS, G.BAG_MAX_SLOTS)

# The generator's lines that some active quest currently asks for (a subset of pool).
static func wanted_lines(pool: Array, quests: Array) -> Array:
	var wanted: Array = []
	for q in quests:
		var it := G.quest_item(q)
		if it.is_empty():
			continue
		if pool.has(int(it.line)) and not wanted.has(int(it.line)):
			wanted.append(int(it.line))
	return wanted

# §6: the POPPABLE asked tiers per pool line — {line -> [tiers]} that some active quest wants AND
# the generator can pop directly (tier within the TIER_ODDS range). Tiers above the pop range are
# EXCLUDED, so the spawn tier-bias never pops a high tier directly — you still merge up for those,
# and the §9 sell economy (128 energy per t8) holds.
static func wanted_tiers(pool: Array, quests: Array) -> Dictionary:
	var out: Dictionary = {}
	for q in quests:
		var it := G.quest_item(q)
		if it.is_empty():
			continue
		var li := int(it.line)
		var t := int(it.tier)
		if pool.has(li) and t >= 1 and t <= G.TIER_ODDS.size():
			if not out.has(li):
				out[li] = []
			if not out[li].has(t):
				out[li].append(t)
	return out

# The generator's tier curve: ONE randf against the cumulative TIER_ODDS (t1 most likely, decaying).
# Factored out so a generator pop AND a freshly-opened cell (bramble_seed) draw the tier from one
# definition. Exactly one rng.randf() and the same fallback (t1) as the old inline loop — roll_spawn's
# load-bearing RNG order depends on this staying a single draw.
static func roll_tier(rng: RandomNumberGenerator) -> int:
	var roll := rng.randf()
	var acc := 0.0
	for i in G.TIER_ODDS.size():
		acc += G.TIER_ODDS[i]
		if roll <= acc:
			return i + 1
	return 1

# A freshly-opened cell's reward: mimic ONE generator pop for what the player is questing. Pick a
# RANDOM line among `open_lines` (the open quests' lines) and roll its tier off the SAME generator
# curve (roll_tier). The caller guards `open_lines` non-empty — an empty set falls back to the
# positional seed in BoardModel.open_bramble. RNG: line pick, then tier (two draws).
static func bramble_seed(open_lines: Array, rng: RandomNumberGenerator) -> int:
	var line := int(open_lines[rng.randi_range(0, open_lines.size() - 1)])
	return line * 100 + roll_tier(rng)

# The spawn roll: a landing cell (one of the few nearest the generator, then random) and a code
# (line*100 + tier). `wanted` lines win with odds ASK_WEIGHT, else any of the generator's `pool`;
# the tier comes off TIER_ODDS and then, when `tier_weight` > 0 and `wanted_tiers` names a poppable
# tier for the picked line, leans toward it with odds `tier_weight` (§6: line AND tier biased toward
# what givers want). `tier_weight` defaults to 0 (OFF) — the live caller passes G.ASK_TIER_WEIGHT, an
# owner pacing dial held at 0 for now (the sim showed full strength front-loads spend; parked pacing
# pass). RNG ORDER IS LOAD-BEARING (the rng is seeded + persisted): cell pick, then [ask-weight, line],
# then tier, then [tier-weight, wanted-tier] — that last draw fires ONLY when tier_weight > 0 AND the
# line has a poppable wanted tier, so an off/empty `wanted_tiers` is a byte-identical no-op. `empties`
# is not mutated.
static func roll_spawn(empties: Array, gen_cell: Vector2i, pool: Array, wanted: Array, rng: RandomNumberGenerator, wanted_tiers: Dictionary = {}, tier_weight: float = 0.0) -> Dictionary:
	var es := empties.duplicate()
	es.sort_custom(func(a, b): return absi(a.x - gen_cell.x) + absi(a.y - gen_cell.y) < absi(b.x - gen_cell.x) + absi(b.y - gen_cell.y))
	var pick: Vector2i = es[rng.randi_range(0, mini(2, es.size() - 1))]
	var line: int
	if not wanted.is_empty() and rng.randf() < G.ASK_WEIGHT:
		line = wanted[rng.randi_range(0, wanted.size() - 1)]
	else:
		line = int(pool[rng.randi_range(0, pool.size() - 1)])
	var tier := roll_tier(rng)
	# §6: lean the tier toward an asked POPPABLE tier for this line (guarded to the TIER_ODDS range,
	# so a generator never pops above it), with probability `tier_weight`. OFF (0.0) skips the whole
	# block — no rng draw, byte-identical — so the default is a true no-op until the owner ramps the dial.
	if tier_weight > 0.0:
		var wt: Array = []
		for t in wanted_tiers.get(line, []):
			if int(t) >= 1 and int(t) <= G.TIER_ODDS.size():
				wt.append(int(t))
		if not wt.is_empty() and rng.randf() < tier_weight:
			tier = int(wt[rng.randi_range(0, wt.size() - 1)])
	return {"cell": pick, "code": line * 100 + tier}

# A merge sometimes shakes a coin loose (never off a coin). RNG: one randf, taken
# only when `produced` isn't already a coin (the short-circuit is preserved).
static func rolls_coin_drop(produced: int, rng: RandomNumberGenerator) -> bool:
	return not G.is_coin(produced) and rng.randf() < G.COIN_DROP_RATE

# A cozy successive-merge streak: a merge within `window` seconds of the previous one
# extends the streak (+1); a longer gap (or no prior streak) restarts it at 1. Pure, so the
# cadence is unit-tested without the scene. `dt` = seconds since the last merge.
static func combo_step(prev_count: int, dt: float, window: float) -> int:
	if prev_count <= 0 or dt > window:
		return 1
	return prev_count + 1

# A quest delivers all-or-nothing: the single asked item must be present on the board.
static func quest_payable(board: BoardModel, q: Dictionary) -> bool:
	var it := G.quest_item(q)
	if it.is_empty():
		return true
	return board.count_of(int(it.line) * 100 + int(it.tier)) >= 1
