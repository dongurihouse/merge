extends RefCounted
## Pure board-run logic — the decisions the persistent BoardModel doesn't own
## (water regen, the merge-hint search, distances, bag size). Backend layer:
## STATELESS statics that take data in and return data out — no Node/Control,
## no Save access. The scene reads Save and animates around these results.
## Layering: core/ never imports ui/ or scenes/ — see docs/design/merge_spec.md §15.

const G = preload("res://engine/scripts/core/content.gd")
const BoardModel = preload("res://engine/scripts/core/board_model.gd")

const ORTHO_DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

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

# If item `a` is merged onto matching item `b`, return the ordered partner
# cells the upgraded result will auto-merge onto. Empty means the tip merge has
# no cascade follow-up. Longest run wins; equal runs choose row-major order.
static func chain_path(board: BoardModel, a: Vector2i, b: Vector2i) -> Array:
	if board == null:
		return []
	var produced := _tip_result_code(board, a, b)
	if produced <= 0:
		return []
	var vacated := {}
	vacated[a] = true
	return _best_chain_from(board, b, produced, vacated)

# Ready outline data, one entry per same-line component whose best tip-over
# would produce at least one automatic follow-up step.
static func ready_ladders(board: BoardModel) -> Array:
	var out: Array = []
	if board == null:
		return out
	var visited := {}
	for i in board.items.size():
		var code := int(board.items[i])
		if code <= 0:
			continue
		var cell := BoardModel.cell_of(i)
		if visited.has(cell):
			continue
		var line := BoardModel.line_of(code)
		var cells := _component_from(board, cell, line)
		for c in cells:
			visited[c] = true
		var best := _best_tip_in_component(board, cells)
		var n := int(best.get("n", 0))
		if n >= 2:
			out.append({
				"cells": cells,
				"line": line,
				"n": n,
				"top_cell": Vector2i(best.get("top_cell", cell)),
			})
	out.sort_custom(func(a, b): return BoardModel.idx(Vector2i((a as Dictionary).get("top_cell", Vector2i.ZERO))) < BoardModel.idx(Vector2i((b as Dictionary).get("top_cell", Vector2i.ZERO))))
	return out

# Empty cells where dropping `code` would improve the joined same-line
# component's best cascade. The source cell is treated as vacated for drag use.
static func chain_placements(board: BoardModel, from: Vector2i, code: int) -> Array:
	var out: Array = []
	if board == null or code <= 0:
		return out
	var base := _copy_board(board)
	if base.in_bounds(from) and base.item_at(from) == code:
		base.take(from)
	var line := BoardModel.line_of(code)
	for i in base.items.size():
		var cell := BoardModel.cell_of(i)
		if cell == from or not base.is_empty_ground(cell):
			continue
		if not _has_adjacent_line(base, cell, line):
			continue
		var before_n := _best_adjacent_component_n(base, cell, line)
		var placed := _copy_board(base)
		placed.place(cell, code)
		var after := _best_tip_in_component(placed, _component_from(placed, cell, line))
		var n := int(after.get("n", 0))
		if n >= 2 and n > before_n:
			out.append({"cell": cell, "n": n})
	out.sort_custom(func(a, b): return BoardModel.idx(Vector2i((a as Dictionary).get("cell", Vector2i.ZERO))) < BoardModel.idx(Vector2i((b as Dictionary).get("cell", Vector2i.ZERO))))
	return out

static func _best_chain_from(board: BoardModel, current: Vector2i, code: int, vacated: Dictionary) -> Array:
	if BoardModel.tier_of(code) >= G.merge_top(code):
		return []
	var candidates: Array = []
	for raw_d in ORTHO_DIRS:
		var d := Vector2i(raw_d)
		var n: Vector2i = current + d
		if vacated.has(n) or not board.in_bounds(n):
			continue
		if board.item_at(n) != code:
			continue
		if not board.collect_reward_at(n).is_empty():
			continue
		candidates.append(n)
	candidates = _sorted_cells(candidates)
	var best: Array = []
	for partner in candidates:
		var next_vacated := vacated.duplicate()
		next_vacated[current] = true
		var path: Array = [partner]
		path.append_array(_best_chain_from(board, Vector2i(partner), code + 1, next_vacated))
		if _path_better(path, best):
			best = path
	return best

static func _tip_result_code(board: BoardModel, a: Vector2i, b: Vector2i) -> int:
	if board.can_merge(a, b):
		return board.item_at(a) + 1
	var a_code := board.item_at(a)
	var b_code := board.item_at(b)
	if a == b or a_code <= 0 or b_code <= 0:
		return 0
	if not board.collect_reward_at(a).is_empty() or not board.collect_reward_at(b).is_empty():
		return 0
	if BoardModel.tier_of(a_code) != BoardModel.tier_of(b_code):
		return 0
	var special_line := G.special_for_pair(BoardModel.line_of(a_code), BoardModel.line_of(b_code))
	return special_line * 100 + BoardModel.tier_of(a_code) if special_line > 0 else 0

static func _best_tip_in_component(board: BoardModel, cells: Array) -> Dictionary:
	var cell_set := {}
	for c in cells:
		cell_set[Vector2i(c)] = true
	var best := {"n": 0, "top_cell": Vector2i(-1, -1), "from": Vector2i(-1, -1), "to": Vector2i(-1, -1), "path": []}
	for a in cells:
		var from := Vector2i(a)
		for raw_d in ORTHO_DIRS:
			var d := Vector2i(raw_d)
			var to := from + d
			if not cell_set.has(to) or not board.can_merge(from, to):
				continue
			var path := chain_path(board, from, to)
			var n := 1 + path.size()
			if n < 2:
				continue
			var top_cell := Vector2i(path[path.size() - 1])
			var candidate := {"n": n, "top_cell": top_cell, "from": from, "to": to, "path": path}
			if _tip_better(candidate, best):
				best = candidate
	return best

static func _tip_better(candidate: Dictionary, best: Dictionary) -> bool:
	var cn := int(candidate.get("n", 0))
	var bn := int(best.get("n", 0))
	if cn != bn:
		return cn > bn
	var ct := BoardModel.idx(Vector2i(candidate.get("top_cell", Vector2i.ZERO)))
	var bt := BoardModel.idx(Vector2i(best.get("top_cell", Vector2i(G.ROWS, G.COLS))))
	if ct != bt:
		return ct < bt
	if _path_better(Array(candidate.get("path", [])), Array(best.get("path", []))):
		return true
	var cf := BoardModel.idx(Vector2i(candidate.get("from", Vector2i.ZERO)))
	var bf := BoardModel.idx(Vector2i(best.get("from", Vector2i(G.ROWS, G.COLS))))
	if cf != bf:
		return cf < bf
	return BoardModel.idx(Vector2i(candidate.get("to", Vector2i.ZERO))) < BoardModel.idx(Vector2i(best.get("to", Vector2i(G.ROWS, G.COLS))))

static func _path_better(candidate: Array, best: Array) -> bool:
	if candidate.size() != best.size():
		return candidate.size() > best.size()
	for i in candidate.size():
		var ci := BoardModel.idx(Vector2i(candidate[i]))
		var bi := BoardModel.idx(Vector2i(best[i]))
		if ci != bi:
			return ci < bi
	return false

static func _component_from(board: BoardModel, start: Vector2i, line: int) -> Array:
	var seen := {}
	var stack: Array = [start]
	while not stack.is_empty():
		var cell := Vector2i(stack.pop_back())
		if seen.has(cell) or not board.in_bounds(cell):
			continue
		var code := board.item_at(cell)
		if code <= 0 or BoardModel.line_of(code) != line:
			continue
		seen[cell] = true
		for raw_d in ORTHO_DIRS:
			var d := Vector2i(raw_d)
			stack.append(cell + d)
	return _sorted_cells(seen.keys())

static func _sorted_cells(cells: Array) -> Array:
	var out := cells.duplicate()
	out.sort_custom(func(a, b): return BoardModel.idx(Vector2i(a)) < BoardModel.idx(Vector2i(b)))
	return out

static func _has_adjacent_line(board: BoardModel, cell: Vector2i, line: int) -> bool:
	for raw_d in ORTHO_DIRS:
		var d := Vector2i(raw_d)
		var n := cell + d
		if board.in_bounds(n) and board.item_at(n) > 0 and BoardModel.line_of(board.item_at(n)) == line:
			return true
	return false

static func _best_adjacent_component_n(board: BoardModel, cell: Vector2i, line: int) -> int:
	var seen_components := {}
	var best := 0
	for raw_d in ORTHO_DIRS:
		var d := Vector2i(raw_d)
		var n := cell + d
		if not board.in_bounds(n) or board.item_at(n) <= 0 or BoardModel.line_of(board.item_at(n)) != line:
			continue
		var comp := _component_from(board, n, line)
		if comp.is_empty():
			continue
		var key := Vector2i(comp[0])
		if seen_components.has(key):
			continue
		seen_components[key] = true
		best = maxi(best, int(_best_tip_in_component(board, comp).get("n", 0)))
	return best

static func _copy_board(board: BoardModel) -> BoardModel:
	var cp := BoardModel.new()
	cp.terrain = board.terrain.duplicate()
	cp.items = board.items.duplicate()
	cp.collect_rewards = board.collect_rewards.duplicate(true)
	cp.gens = board.gens.duplicate(true)
	cp.gen_tiers = board.gen_tiers.duplicate(true)
	cp.gen_bag = board.gen_bag.duplicate(true)
	cp.gen_bag_tiers = board.gen_bag_tiers.duplicate(true)
	cp.gen_boost = board.gen_boost.duplicate(true)
	cp.gen_bag_boost = board.gen_bag_boost.duplicate(true)
	return cp

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

# roll_item_tier: roll_tier CLAMPED to an item's merge ceiling (`top`). Treat AND special-item/bonus
# generators use this so they pop a SPREAD of tiers like a normal generator, while never popping above
# what that item can merge to — water/exp top out at SPECIAL_TOP (a rolled t4 folds into t3); coins,
# acorns and treat fruit top high, so the 1..TIER_ODDS roll is unaffected there. Exactly ONE randf
# (via roll_tier) and the same t1 fallback, so it shares the generator curve and stays a single draw.
static func roll_item_tier(rng: RandomNumberGenerator, top: int) -> int:
	return clampi(roll_tier(rng), 1, maxi(1, top))

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

# The landing cell for a lucky drop (coin / §6.B special) shaken loose near `near`: one of the up-to-3
# OPEN cells nearest `near`, chosen by `rng`. Returns the (-1,-1) sentinel when the board has no open
# ground. Pure — the two drop handlers share it so the "where does it land" chance is unit-tested.
static func pick_drop_cell(board: BoardModel, near: Vector2i, rng: RandomNumberGenerator) -> Vector2i:
	var empties := board.empty_ground_cells()
	if empties.is_empty():
		return Vector2i(-1, -1)
	empties.sort_custom(func(a, b): return (a - near).length_squared() < (b - near).length_squared())
	return empties[rng.randi_range(0, mini(2, empties.size() - 1))]
