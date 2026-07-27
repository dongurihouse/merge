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

static func range_pairs(board: BoardModel, cells: Array) -> Array:
	var ordered: Array = []
	for cell in cells:
		var c := Vector2i(cell)
		if board.in_bounds(c):
			ordered.append(c)
	ordered.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return BoardModel.idx(a) < BoardModel.idx(b))
	var pairs: Array = []
	for i in ordered.size():
		for j in range(i + 1, ordered.size()):
			var a: Vector2i = ordered[i]
			var b: Vector2i = ordered[j]
			if board.can_merge(a, b):
				pairs.append([a, b])
	pairs.sort_custom(func(pa: Array, pb: Array) -> bool:
		var ca: int = board.item_at(pa[0])
		var cb: int = board.item_at(pb[0])
		var ta := BoardModel.tier_of(ca)
		var tb := BoardModel.tier_of(cb)
		if ta != tb:
			return ta < tb
		var ia := mini(BoardModel.idx(pa[0]), BoardModel.idx(pa[1]))
		var ib := mini(BoardModel.idx(pb[0]), BoardModel.idx(pb[1]))
		if ia != ib:
			return ia < ib
		return maxi(BoardModel.idx(pa[0]), BoardModel.idx(pa[1])) < maxi(BoardModel.idx(pb[0]), BoardModel.idx(pb[1]))
	)
	return pairs

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

static func chain_reward_code(n: int) -> int:
	if n == 2:
		return G.COIN_LINE * 100 + 1
	if n >= 3:
		return G.CHEST_LINE * 100 + mini(5, n - 2)
	return 0

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
#
# HOT PATH. This runs synchronously inside the drag gesture (board.gd _begin_drag →
# _show_cascade_drag_guides), so its cost is a hitch at the exact moment the player picks a
# piece up — and it used to cost ~20 ms on a full board here, more than a 60fps frame on a
# machine several times faster than a phone. It is written flat for that reason:
#
#   * ONE PackedInt32Array snapshot of `items` — no BoardModel copy per candidate cell, and
#     the caller's live board is read but never written (chain_placements takes the REAL
#     board; corrupting it would be a severe bug — cascade_tests pins it).
#   * the dragged line's components are labelled ONCE, and each component's best cascade is
#     memoised: neighbouring candidate cells keep asking about the same components.
#   * the per-candidate search reports only the cascade LENGTH (see _best_cascade_n), which
#     is all this function reads, so none of the path/tie-break bookkeeping is built.
#
# Results are IDENTICAL to the straightforward copy-per-candidate walk: same cells, same n,
# same order. The order is row-major because this loop walks the board row-major, which is
# what the old trailing sort_custom re-established (idx keys are unique, so that sort had
# exactly one possible answer). engine/tests/cascade_tests.gd proves the equivalence against
# a pasted copy of the original algorithm — hand-built boards plus seeded random ones.
static func chain_placements(board: BoardModel, from: Vector2i, code: int) -> Array:
	var out: Array = []
	if board == null or code <= 0:
		return out
	var count := board.items.size()
	var items := board.items.duplicate()          # the scratch board: mutated, then rewound
	var from_i := BoardModel.idx(from) if board.in_bounds(from) else -1
	if from_i >= 0 and items[from_i] == code:
		items[from_i] = 0                          # the dragged piece has left its cell
	# Collect rewards block a merge. Flattened to an idx set, and only for OCCUPIED cells: every
	# reader checks the item first, and place() clears the reward under a dropped piece, so a
	# reward stranded on an empty cell is unreachable either way.
	var guarded := _guarded_growing_indices(board)
	var blocked := guarded.duplicate()
	for key in board.collect_rewards:
		var ri := int(key)
		if ri < 0 or ri >= count or items[ri] <= 0:
			continue
		var reward = board.collect_rewards[key]
		if reward is Dictionary and not (reward as Dictionary).is_empty():
			blocked[ri] = true
	var nbrs := _neighbour_table(count)
	var tops := {}                                 # code -> G.merge_top(code), memoised
	var line := BoardModel.line_of(code)
	# --- the dragged line's components, labelled in one pass ----------------------------------
	var comp_of := PackedInt32Array()
	comp_of.resize(count)
	comp_of.fill(-1)
	var comp_cells: Array = []                     # component -> PackedInt32Array of cell idx
	var comp_n := PackedInt32Array()               # component -> best cascade n, -1 until asked
	for i in count:
		if comp_of[i] >= 0 or guarded.has(i) or items[i] <= 0 or BoardModel.line_of(items[i]) != line:
			continue
		var id := comp_cells.size()
		var members := PackedInt32Array()
		var stack: Array = [i]
		comp_of[i] = id
		while not stack.is_empty():
			var c: int = stack.pop_back()
			members.append(c)
			var c4 := c * 4
			for d in 4:
				var nb: int = nbrs[c4 + d]
				if nb < 0 or comp_of[nb] >= 0 or guarded.has(nb) or items[nb] <= 0 or BoardModel.line_of(items[nb]) != line:
					continue
				comp_of[nb] = id
				stack.append(nb)
		comp_cells.append(members)
		comp_n.append(-1)
	# --- one pass over the empty ground -------------------------------------------------------
	var terrain := board.terrain
	var touched := PackedInt32Array()
	for i in count:
		if i == from_i or items[i] != 0 or terrain[i] != 0:
			continue
		var cell := BoardModel.cell_of(i)
		if board.gens.has(cell):
			continue
		# The distinct same-line components this cell touches, and the best cascade they already
		# have between them (the "no adjacent kin" early-out is this list coming back empty).
		touched.clear()
		var before_n := 0
		var b4 := i * 4
		for d in 4:
			var nb: int = nbrs[b4 + d]
			if nb < 0:
				continue
			var id: int = comp_of[nb]
			if id < 0 or touched.has(id):
				continue
			touched.append(id)
			if comp_n[id] < 0:
				comp_n[id] = _best_cascade_n(items, comp_cells[id], nbrs, blocked, tops)
			if comp_n[id] > before_n:
				before_n = comp_n[id]
		if touched.is_empty():
			continue
		# Dropping `code` here fuses those components into one — that union IS the component the
		# full search would walk, since the only new link is this cell.
		var joined := PackedInt32Array([i])
		for id in touched:
			var members: PackedInt32Array = comp_cells[id]
			joined.append_array(members)
		items[i] = code
		var n := _best_cascade_n(items, joined, nbrs, blocked, tops)
		items[i] = 0                               # rewind: the scratch is reused for every cell
		if n >= 2 and n > before_n:
			out.append({"cell": cell, "n": n})
	return out

# Cell idx -> its up-to-4 orthogonal neighbours (-1 where the board ends), so the searches
# below never redo the row/column arithmetic. `count` is the board's cell count (G.ROWS ×
# G.COLS). ORTHO_DIRS order is irrelevant here: every caller of this table takes a MAX over
# the neighbours, and a max does not care in which order it is fed.
static func _neighbour_table(count: int) -> PackedInt32Array:
	var cols: int = G.COLS
	var table := PackedInt32Array()
	table.resize(count * 4)
	for i in count:
		var b4 := i * 4
		table[b4] = i - cols if i >= cols else -1
		table[b4 + 1] = i + cols if i + cols < count else -1
		table[b4 + 2] = i - 1 if i % cols > 0 else -1
		table[b4 + 3] = i + 1 if i % cols < cols - 1 else -1
	return table

# The best cascade length available inside ONE same-line component — the `n` half of
# _best_tip_in_component, over flat cell indices and with none of the tie-break bookkeeping.
# chain_placements only ever reads `n`, and the tie-breaks only choose WHICH equally long
# cascade gets reported, so dropping them cannot change the answer. Returns 0 for the `n < 2`
# runs the full search discards. `cells` must be a whole component: a same-code neighbour of a
# member is same-line, hence already a member, which is why there is no cell-set check here.
static func _best_cascade_n(items: PackedInt32Array, cells: PackedInt32Array, nbrs: PackedInt32Array, blocked: Dictionary, tops: Dictionary) -> int:
	var best := 0
	var vacated := {}
	for a in cells:
		if blocked.has(a):
			continue
		var k: int = items[a]
		var top := int(tops.get(k, -1))
		if top < 0:
			top = G.merge_top(k)
			tops[k] = top
		if k % 100 >= top:
			continue                               # this code is already at its merge ceiling
		var b4: int = a * 4
		for d in 4:
			var b: int = nbrs[b4 + d]
			if b < 0 or items[b] != k or blocked.has(b):
				continue
			# can_merge(a, b) holds: same code, neither carrying a collect reward, below the top.
			vacated[a] = true
			var n := 1 + _max_chain(items, nbrs, blocked, tops, b, k + 1, vacated)
			vacated.erase(a)
			if n > best:
				best = n
	return best if best >= 2 else 0

# The LENGTH of chain_path()'s best run from `cell` once it holds `code`: the same depth-first
# search _best_chain_from does — same ceiling stop, same partner rule (an orthogonal neighbour
# holding `code`, not already consumed, carrying no collect reward) — returning the depth
# instead of building the paths. _path_better ranks LENGTH first, so the longest run is the run
# the full search picks. `vacated` is carried and rewound rather than duplicated per branch.
static func _max_chain(items: PackedInt32Array, nbrs: PackedInt32Array, blocked: Dictionary, tops: Dictionary, cell: int, code: int, vacated: Dictionary) -> int:
	var top := int(tops.get(code, -1))
	if top < 0:
		top = G.merge_top(code)
		tops[code] = top
	if code % 100 >= top:
		return 0
	var best := 0
	var b4 := cell * 4
	vacated[cell] = true
	for d in 4:
		var nb: int = nbrs[b4 + d]
		if nb < 0 or items[nb] != code or vacated.has(nb) or blocked.has(nb):
			continue
		var run := 1 + _max_chain(items, nbrs, blocked, tops, nb, code + 1, vacated)
		if run > best:
			best = run
	vacated.erase(cell)
	return best

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
		if _is_guarded_growing_cell(board, n):
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

static func _is_guarded_growing_cell(board: BoardModel, cell: Vector2i) -> bool:
	return board != null and board.is_growing(cell) and board.growing_from_tier(cell) >= 7

static func _guarded_growing_indices(board: BoardModel) -> Dictionary:
	var out := {}
	if board == null:
		return out
	for cell in board.growing_cells():
		var c := Vector2i(cell)
		if board.growing_from_tier(c) >= 7:
			out[BoardModel.idx(c)] = true
	return out

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

# The generator's tier curve over an explicit closed window: ONE randf against the cumulative tier odds.
# Rank-0 uses the shipped width-4 odds byte-for-byte; odd mastery ranks use the width-5 odds. The fallback
# stays at the window low, matching the old t1 fallback when lo=1.
static func roll_tier_window(rng: RandomNumberGenerator, lo: int = 1, width: int = 4) -> int:
	var roll := rng.randf()
	var acc := 0.0
	var odds: Array = G.MASTERY_TIER_ODDS_5 if int(width) == 5 else G.TIER_ODDS
	var n := mini(maxi(1, int(width)), odds.size())
	for i in n:
		acc += float(odds[i])
		if roll <= acc:
			return maxi(1, int(lo)) + i
	return maxi(1, int(lo))

# The generator's tier curve: ONE randf against the cumulative TIER_ODDS (t1 most likely, decaying).
# Factored out so a generator pop AND a freshly-opened cell (bramble_seed) draw the tier from one
# definition. Exactly one rng.randf() and the same fallback (t1) as the old inline loop — roll_spawn's
# load-bearing RNG order depends on this staying a single draw.
static func roll_tier(rng: RandomNumberGenerator) -> int:
	return roll_tier_window(rng, 1, G.TIER_ODDS.size())

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
static func roll_spawn(empties: Array, gen_cell: Vector2i, pool: Array, wanted: Array, rng: RandomNumberGenerator, wanted_tiers: Dictionary = {}, tier_weight: float = 0.0, tier_lo: int = 1, tier_hi: int = 4) -> Dictionary:
	var es := empties.duplicate()
	es.sort_custom(func(a, b): return absi(a.x - gen_cell.x) + absi(a.y - gen_cell.y) < absi(b.x - gen_cell.x) + absi(b.y - gen_cell.y))
	var pick: Vector2i = es[rng.randi_range(0, mini(2, es.size() - 1))]
	var line: int
	if not wanted.is_empty() and rng.randf() < G.ASK_WEIGHT:
		line = wanted[rng.randi_range(0, wanted.size() - 1)]
	else:
		line = int(pool[rng.randi_range(0, pool.size() - 1)])
	var tier := roll_tier_window(rng, tier_lo, maxi(1, int(tier_hi) - int(tier_lo) + 1))
	# §6: lean the tier toward an asked POPPABLE tier for this line (guarded to the TIER_ODDS range,
	# so a generator never pops above it), with probability `tier_weight`. OFF (0.0) skips the whole
	# block — no rng draw, byte-identical — so the default is a true no-op until the owner ramps the dial.
	if tier_weight > 0.0:
		var wt: Array = []
		for t in wanted_tiers.get(line, []):
			if int(t) >= int(tier_lo) and int(t) <= int(tier_hi):
				wt.append(int(t))
		if not wt.is_empty() and rng.randf() < tier_weight:
			tier = int(wt[rng.randi_range(0, wt.size() - 1)])
	return {"cell": pick, "code": line * 100 + tier}

# A merge sometimes shakes a coin loose (never off a coin). RNG: one randf, taken
# only when `produced` isn't already a coin (the short-circuit is preserved).
static func rolls_coin_drop(produced: int, rng: RandomNumberGenerator) -> bool:
	return not G.is_coin(produced) and rng.randf() < G.COIN_DROP_RATE

# The live quest item avoid-set as item codes (line*100+tier). Mirrors the quest refill idiom:
# malformed / grant-only quest entries do not contribute.
static func asked_items(quests: Array) -> Array:
	var out: Array = []
	for q in quests:
		if not (q is Dictionary):
			continue
		var it := G.quest_item(q)
		if it.is_empty():
			continue
		var code := int(it.line) * 100 + int(it.tier)
		if code > 0 and not out.has(code):
			out.append(code)
	return out

# Shared merge-drop rule for the scene and grove_sim. `in_patch` is the caller's answer for the
# produced piece's landing cell. The shipped board-rng stream stays coin roll first and special roll
# second; sky-only bonus chances use a side roll from the current stream marker and hour, with no
# extra board-rng draw. `blocked_lines` is the improvement-seed filter (a kind already held unplaced,
# or at its placed cap) — it re-weights the pick WITHOUT changing the number of draws.
static func roll_merge_drops(produced: int, rng: RandomNumberGenerator, sky_state: Dictionary, in_patch: bool, blocked_lines: Array = []) -> Array:
	var out: Array = []
	var sky := String(sky_state.get("sky", ""))
	var stream_marker := int(rng.state)
	var baseline_coin := rolls_coin_drop(produced, rng)
	if sky == "sunbeam" and in_patch:
		if not G.is_coin(produced) and _sky_bonus_hits(sky_state, produced, stream_marker, 104729, float(G.SKY_COIN_RATE)):
			out.append(G.COIN_LINE * 100 + int(G.SKY_COIN_TIER))
	elif baseline_coin:
		out.append(G.COIN_LINE * 100 + 1)
	if not G.is_special(produced):
		if sky == "rain" and in_patch:
			if _sky_bonus_hits(sky_state, produced, stream_marker, 130363, float(G.SKY_WATER_RATE)):
				out.append(G.WATER_LINE * 100 + 1)
		if G.rolls_special_drop(rng):
			out.append(G.pick_special_drop(rng, blocked_lines))
	return out

static func _sky_bonus_hits(sky_state: Dictionary, produced: int, stream_marker: int, salt: int, rate: float) -> bool:
	if rate <= 0.0:
		return false
	if rate >= 1.0:
		return true
	var basis := "%d:%s:%d:%d:%d:%d" % [
		int(sky_state.get("hour", 0)),
		String(sky_state.get("lane_axis", "")),
		int(sky_state.get("lane", 0)),
		produced,
		stream_marker,
		salt,
	]
	return float(absi(hash(basis)) % 10000) < rate * 10000.0

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
