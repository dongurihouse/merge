extends RefCounted
## The persistent board model (pure data, fully serializable).
## Terrain per cell: 0 = open ground; >0 = a SEALED obstacle cell (§4). The gate is the player's
## Level vs the static G.cell_min_level table — NOT the stored value — so legacy saves (the old
## gate_line*16+tier encoding) still read correctly as "sealed" and need no migration.
## Items: line*100 + tier (0 = none). A generator occupies its cell permanently.

const G = preload("res://engine/scripts/core/content.gd")
const Improvements = preload("res://engine/scripts/core/improvements.gd")

var terrain := PackedInt32Array()
var items := PackedInt32Array()
var collect_rewards: Dictionary = {}       # idx -> {kind, amount}; custom-value collectables such as opened chests.
var gens: Dictionary = {}                 # cell -> generator id; the LIVE generators (§6),
                                          # STATEFUL + persisted (movable; stored/placed via gen_bag, §6).
                                          # Seeded by seed_gens / restored by from_dict.
var gen_tiers: Dictionary = {}            # cell -> generator TIER (1..GEN_TOP_TIER); 1 if absent. Gen redesign #8.
var gen_bag: Array = []                   # stored generator ids (the bag's generator section, soft cap 100)
var gen_bag_tiers: Array = []             # PARALLEL to gen_bag: the TIER of each stored generator (#8; 1 default).
                                          # Invariant: size() == gen_bag.size(). Mutate the bag only via
                                          # store_gen / place_gen_from_bag / bag_add / prune_bag so it stays aligned.

# §6 per-generator boost — remaining taps, cell-keyed; rides with the generator (move carries, merge sums,
# sell/store clears). gen_bag_boost is PARALLEL to gen_bag (invariant: equal sizes).
var gen_boost: Dictionary = {}
var gen_bag_boost: Array = []
var improvements: Dictionary = {}          # cell -> {kind, rank, code, ends_at, watered}

func _init() -> void:
	terrain.resize(G.ROWS * G.COLS)
	items.resize(G.ROWS * G.COLS)
	for r in G.ROWS:
		for c in G.COLS:
			var cell := Vector2i(r, c)
			terrain[idx(cell)] = 0 if G.open_at_start(cell) else G.bramble_terrain(cell)
	for cell in G.STARTER_ITEMS:
		items[idx(cell)] = int(G.STARTER_ITEMS[cell])

static func idx(cell: Vector2i) -> int:
	return cell.x * G.COLS + cell.y

static func cell_of(i: int) -> Vector2i:
	return Vector2i(int(i / float(G.COLS)), i % G.COLS)

func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < G.ROWS and cell.y >= 0 and cell.y < G.COLS

func is_open(cell: Vector2i) -> bool:
	return in_bounds(cell) and terrain[idx(cell)] == 0

func is_bramble(cell: Vector2i) -> bool:
	return in_bounds(cell) and terrain[idx(cell)] > 0

func item_at(cell: Vector2i) -> int:
	return items[idx(cell)] if in_bounds(cell) else 0

func is_gen(cell: Vector2i) -> bool:
	return gens.has(cell)

func gen_id_at(cell: Vector2i) -> String:
	return String(gens.get(cell, ""))

## Seed the live generator set to a map's roster (§6) — used on a fresh game (map 0) and
## by the save migration (an existing player's current map). NOT the in-play path: once
## seeded, the set changes only by move_gen / store_gen / place_gen_from_bag / grow_gens.
## Each gen cell sheds its bramble, and any player item caught on it hops to free ground
## (never destroyed).
func seed_gens(map: int, level: int = G.APPEAR_ALL) -> void:
	# gen redesign: the board STARTS with only the anchor generator; the rest are born on tap (§6.B).
	gens = {}
	gen_boost = {}
	for g in G.generators_for_map(G.GENERATORS, map, level):
		if bool(g.get("anchor", false)):
			var cell := Vector2i(g.get("cell", Vector2i(-1, -1)))
			if not improvements.has(cell):
				gens[cell] = String(g.id)
	_claim_gen_cells()

func _claim_gen_cells() -> void:
	for cell in gens:
		if terrain[idx(cell)] > 0:
			terrain[idx(cell)] = 0           # clears its bramble (no contents)
			items[idx(cell)] = 0
			collect_rewards.erase(idx(cell))
		elif items[idx(cell)] > 0:
			var refuge := empty_ground_cells()
			if not refuge.is_empty():
				move(cell, Vector2i(refuge[0]))
			else:
				items[idx(cell)] = 0
				collect_rewards.erase(idx(cell))

## Move a board generator into the bag's generator section (frees its cell). No-op on a bad cell.
## #8: the generator's TIER travels with it into the bag, and the vacated cell sheds its tier data.
func store_gen(cell: Vector2i) -> bool:
	if not gens.has(cell):
		return false
	gen_bag.append(String(gens[cell]))
	gen_bag_tiers.append(gen_tier_at(cell))   # the tier follows the generator into the bag
	gen_bag_boost.append(gen_boost_at(cell))  # §6: the boost travels with it too
	gens.erase(cell)
	gen_tiers.erase(cell)                      # no stale tier left behind on the now-empty cell
	gen_boost.erase(cell)
	return true

## Place a stored generator from the bag onto an open, empty, non-generator cell. #8: restores the stored TIER.
func place_gen_from_bag(id: String, cell: Vector2i) -> bool:
	# is_open already guarantees terrain == 0 (an open, empty cell)
	var i := gen_bag.find(id)
	if i < 0 or gens.has(cell) or not is_open(cell) or item_at(cell) != 0:
		return false
	var tier := _bag_tier_at(i)               # read the tier BEFORE removing the entry
	var boost := _bag_boost_at(i)             # §6: and the carried boost
	gen_bag.remove_at(i)
	if i < gen_bag_tiers.size():
		gen_bag_tiers.remove_at(i)
	if i < gen_bag_boost.size():
		gen_bag_boost.remove_at(i)
	gens[cell] = id
	gen_tiers[cell] = tier                     # restore the stored tier (not a silent reset to 1)
	if boost > 0:
		gen_boost[cell] = boost                # §6: restore the carried boost
	return true

## Append a generator id to the bag at `tier` (default 1) — the canonical bag-push that keeps
## gen_bag_tiers aligned. Use this instead of a raw gen_bag.append(...).
func bag_add(id: String, tier: int = 1, boost: int = 0) -> void:
	gen_bag.append(String(id))
	gen_bag_tiers.append(maxi(1, tier))
	gen_bag_boost.append(maxi(0, boost))

## The tier of the bagged generator at index `i` (1 if out of range — tolerates a transient skew).
func _bag_tier_at(i: int) -> int:
	return int(gen_bag_tiers[i]) if i >= 0 and i < gen_bag_tiers.size() else 1

## The boost taps of the bagged generator at index `i` (0 if out of range — tolerates a transient skew).
func _bag_boost_at(i: int) -> int:
	return int(gen_bag_boost[i]) if i >= 0 and i < gen_bag_boost.size() else 0

## Filter the bag in place, keeping only ids for which `should_keep.call(id)` is true — rebuilds
## gen_bag and its parallel tiers together so they stay aligned.
func prune_bag(should_keep: Callable) -> void:
	var ids: Array = []
	var tiers: Array = []
	var boosts: Array = []
	for i in gen_bag.size():
		if bool(should_keep.call(String(gen_bag[i]))):
			ids.append(gen_bag[i])
			tiers.append(_bag_tier_at(i))
			boosts.append(_bag_boost_at(i))
	gen_bag = ids
	gen_bag_tiers = tiers
	gen_bag_boost = boosts

## #1 — a generator is a movable piece (§2): relocate it to an empty, open, non-generator
## cell. Refuses an occupied cell, a bramble, or another generator's cell. Persisted via `gens`.
func move_gen(from: Vector2i, to: Vector2i) -> bool:
	if not gens.has(from) or gens.has(to) or not is_open(to) or item_at(to) != 0:
		return false
	gens[to] = gens[from]
	gens.erase(from)
	gen_tiers[to] = gen_tier_at(from)     # #8: the tier travels with the generator
	gen_tiers.erase(from)
	var moved_boost := gen_boost_at(from)  # §6: the boost travels with the generator
	if moved_boost > 0:
		gen_boost[to] = moved_boost
	gen_boost.erase(from)
	return true

# The TIER of the generator at `cell` (1..GEN_TOP_TIER); 1 if unset. Gen redesign #8.
func gen_tier_at(cell: Vector2i) -> int:
	return int(gen_tiers.get(cell, 1))

# The highest tier owned for a generator LINE, across the board AND the bag (0 when the line owns none).
# Drives self-dup (spawn at the line's top so duplicates feed ONE lineage and never strand) and
# redundancy. Gen stranding fix.
func top_gen_tier(line: int) -> int:
	var top := 0
	for cell in gens:
		if int(G.gen_def(G.GENERATORS, String(gens[cell])).get("line", 0)) == line:
			top = maxi(top, gen_tier_at(cell))
	for i in gen_bag.size():
		if int(G.gen_def(G.GENERATORS, String(gen_bag[i])).get("line", 0)) == line:
			top = maxi(top, _bag_tier_at(i))
	return top

# A generator is REDUNDANT when a strictly-higher-tier generator of its line exists (board or bag): it
# can never merge up to or past the top, so it is safe to sell — the line's top generator always remains.
# Gen stranding fix.
func is_redundant_gen(cell: Vector2i) -> bool:
	if not gens.has(cell):
		return false
	var line := int(G.gen_def(G.GENERATORS, gen_id_at(cell)).get("line", 0))
	return gen_tier_at(cell) < top_gen_tier(line)

# §6 per-generator boost — remaining taps at a cell (0 = unboosted). Read by the board's pop/collect/indicator.
func gen_boost_at(cell: Vector2i) -> int:
	return int(gen_boost.get(cell, 0))

func is_gen_boosted(cell: Vector2i) -> bool:
	return gen_boost_at(cell) > 0

# Arm a generator's boost to `taps`. No-op when the cell holds no generator; taps<=0 clears the entry.
func arm_gen_boost(cell: Vector2i, taps: int) -> void:
	if taps > 0 and gens.has(cell):
		gen_boost[cell] = taps
	else:
		gen_boost.erase(cell)

# Spend one boost tap off a cell — called once per charged/collect tap on that generator. Erases at 0; never underflows.
func consume_gen_boost(cell: Vector2i) -> void:
	var left := gen_boost_at(cell)
	if left <= 1:
		gen_boost.erase(cell)
	else:
		gen_boost[cell] = left - 1

# #8 merge: two SAME-LINE generators at the SAME tier (below the top) merge 2:1 → the target gains a tier,
# the source is removed (frees its cell). Returns true on a real merge.
func merge_gens(from: Vector2i, to: Vector2i) -> bool:
	if from == to or not gens.has(from) or not gens.has(to):
		return false
	if String(gens[from]) != String(gens[to]):
		return false
	var t := gen_tier_at(from)
	if t != gen_tier_at(to) or t >= G.GEN_TOP_TIER:
		return false
	gens.erase(from)
	gen_tiers.erase(from)
	gen_tiers[to] = t + 1
	var combined := gen_boost_at(to) + gen_boost_at(from)  # §6: the survivor keeps both generators' taps
	gen_boost.erase(from)
	if combined > 0:
		gen_boost[to] = combined
	return true

## A generator that VANISHES in place (a spent bonus/treat gen): erase BOTH `gens` and its tier so no stale
## gen_tier is left on the now-empty cell — mirrors store_gen / merge_gens / move_gen. Returns true if one was
## removed. (board.gd used a raw `gens.erase(cell)` that orphaned the tier; route those through here.)
func remove_gen(cell: Vector2i) -> bool:
	if not gens.has(cell):
		return false
	gens.erase(cell)
	gen_tiers.erase(cell)
	gen_boost.erase(cell)                      # §6: a vanished generator loses its boost
	return true

## Place a single generator at `cell` — claims the cell (sheds bramble / hops any item to
## safety), like seed_gens. No-op if a generator already sits there. New generators default to tier 1,
## while explicit merge-fuel duplicates can carry the source tier.
func place_gen(id: String, cell: Vector2i, tier: int = 1) -> void:
	if gens.has(cell):
		return
	gens[cell] = id
	gen_tiers[cell] = clampi(tier, 1, G.GEN_TOP_TIER)   # #8: new generators start at tier 1 unless explicit
	if terrain[idx(cell)] > 0:
		terrain[idx(cell)] = 0
		items[idx(cell)] = 0
		collect_rewards.erase(idx(cell))
	elif items[idx(cell)] > 0:
		var refuge := empty_ground_cells()
		if not refuge.is_empty():
			move(cell, Vector2i(refuge[0]))
		else:
			items[idx(cell)] = 0
			collect_rewards.erase(idx(cell))

## Compat shim for the fresh-run tools (sim / shot) that still ask for a spot-count's
## generators: re-seed to the map that many home spots reaches. NOT used by the live board
## (which restores `gens` from save and only mutates it via move/store/place/grow). Returns the live gen cells.
func set_active_gens(spots: int, level: int = G.APPEAR_ALL) -> Array:
	seed_gens(G.map_for_spots(spots), level)
	return gens.keys()

## Install any of `map`'s OWN generators that have GROWN IN by `level` (appear_level reached)
## but are not yet on the board AND are not stored in gen_bag — the staged-second-generator
## path (§ owner: don't open with two generators; e.g. pantry_crock at appear_level 5).
## Idempotent: a generator already on the board or deliberately stored in gen_bag is skipped,
## so this is safe to call on every board open / level-up. Returns the ids newly installed
## (for a beat). Does NOT install the next map's generators (those arrive via gen_bag).
## Gen redesign: a birth-on-tap generator carries NO authored cell (gen_cell_of → (-1,-1)); it is
## placed dynamically by board._produce_due_generators when its zone opens, so it is SKIPPED here.
## (Without this guard the dead appear_level default 0 grew every cell-less gen onto the (-1,-1)
## sentinel — a phantom that then read as "owned" and blocked the real birth-on-tap.)
func grow_gens(map: int, level: int) -> Array:
	var added: Array = []
	for g in G.generators_for_map(G.GENERATORS, map, level):
		var id := String(g.id)
		if gens.values().has(id):
			continue
		if gen_bag.has(id):
			continue
		var cell := G.gen_cell_of(G.GENERATORS, id)
		if cell == Vector2i(-1, -1):
			continue
		if improvements.has(cell):
			continue
		place_gen(id, cell)
		added.append(id)
	return added

func is_empty_ground(cell: Vector2i) -> bool:
	return is_open(cell) and item_at(cell) == 0 and not is_gen(cell)

func empty_auto_gen_cells() -> Array:
	var out: Array = []
	for cell in empty_ground_cells():
		if not improvements.has(cell):
			out.append(cell)
	return out

func improvement_at(cell: Vector2i) -> Dictionary:
	var row = improvements.get(cell, {})
	if row is Dictionary:
		return Improvements.normalize_activity(row)
	return {}

func has_improvement(cell: Vector2i) -> bool:
	return improvements.has(cell)

func improvement_count(kind: String) -> int:
	var n := 0
	for cell in improvements:
		var row := improvement_at(cell)
		if String(row.get("kind", "")) == kind:
			n += 1
	return n

func can_build_improvement(cell: Vector2i) -> bool:
	return in_bounds(cell) and is_open(cell) and item_at(cell) == 0 and not is_gen(cell) and not improvements.has(cell)

func build_improvement(cell: Vector2i, kind: String, rank: int = 1) -> bool:
	if not Improvements.is_valid_kind(kind) or not can_build_improvement(cell):
		return false
	improvements[cell] = {
		"kind": kind,
		"rank": clampi(rank, 1, int(G.SOIL_MAX_RANK)),
		"code": 0,
		"ends_at": 0.0,
		"watered": false,
	}
	return true

func move_improvement(from: Vector2i, to: Vector2i) -> bool:
	if not improvements.has(from) or not can_build_improvement(to):
		return false
	var row := improvement_at(from)
	row["code"] = 0
	row["ends_at"] = 0.0
	row["watered"] = false
	improvements.erase(from)
	improvements[to] = row
	return true

func demolish_improvement(cell: Vector2i) -> bool:
	if not improvements.has(cell):
		return false
	improvements.erase(cell)
	return true

func rank_soil(cell: Vector2i) -> bool:
	var row := improvement_at(cell)
	if String(row.get("kind", "")) != Improvements.KIND_SOIL:
		return false
	var rank := int(row.get("rank", 1))
	if rank >= int(G.SOIL_MAX_RANK):
		return false
	row["rank"] = rank + 1
	improvements[cell] = row
	return true

func reset_soil_activity(cell: Vector2i) -> void:
	if not improvements.has(cell):
		return
	var row := improvement_at(cell)
	if String(row.get("kind", "")) != Improvements.KIND_SOIL:
		return
	row["code"] = 0
	row["ends_at"] = 0.0
	row["watered"] = false
	improvements[cell] = row

func soil_remaining(cell: Vector2i, now: float) -> float:
	var row := improvement_at(cell)
	if String(row.get("kind", "")) != Improvements.KIND_SOIL:
		return 0.0
	return maxf(0.0, float(row.get("ends_at", 0.0)) - now)

func is_growing(cell: Vector2i) -> bool:
	var row := improvement_at(cell)
	return String(row.get("kind", "")) == Improvements.KIND_SOIL \
		and int(row.get("code", 0)) > 0 \
		and float(row.get("ends_at", 0.0)) > 0.0 \
		and item_at(cell) == int(row.get("code", 0))

func growing_cells() -> Array:
	var out: Array = []
	for cell in improvements:
		if is_growing(cell):
			out.append(cell)
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return idx(a) < idx(b))
	return out

func growing_from_tier(cell: Vector2i) -> int:
	var row := improvement_at(cell)
	return int(row.get("code", 0)) % 100 if is_growing(cell) else 0

func apply_water_to_soil(cell: Vector2i, now: float) -> bool:
	if not is_growing(cell):
		return false
	var before := improvement_at(cell)
	var after := Improvements.apply_water(before, now)
	if float(after.get("ends_at", 0.0)) == float(before.get("ends_at", 0.0)) and bool(after.get("watered", false)) == bool(before.get("watered", false)):
		return false
	improvements[cell] = after
	return true

func finish_soil_now(cell: Vector2i, now: float) -> bool:
	if not is_growing(cell):
		return false
	var row := improvement_at(cell)
	row["ends_at"] = now
	improvements[cell] = row
	return not reconcile_improvements(now).is_empty()

func reconcile_improvements(now: float) -> Array:
	var grown: Array = []
	for cell in improvements.keys():
		var row := improvement_at(cell)
		if String(row.get("kind", "")) != Improvements.KIND_SOIL:
			continue
		var code := item_at(cell)
		if not Improvements.is_soil_eligible(code):
			row["code"] = 0
			row["ends_at"] = 0.0
			row["watered"] = false
			improvements[cell] = row
			continue
		if int(row.get("code", 0)) != code or float(row.get("ends_at", 0.0)) <= 0.0:
			row = _start_soil_step(row, code, now)
			improvements[cell] = row
			continue
		var guard := 0
		while Improvements.is_soil_eligible(code) and float(row.get("ends_at", 0.0)) <= now and guard < 32:
			var tier := tier_of(code)
			var top := int(G.merge_top(code))
			var new_tier := mini(top, tier + Improvements.grow_amount(int(row.get("rank", 1))))
			code = line_of(code) * 100 + new_tier
			place(cell, code)
			grown.append(cell)
			if not Improvements.is_soil_eligible(code):
				row["code"] = 0
				row["ends_at"] = 0.0
				row["watered"] = false
				break
			var next_start := float(row.get("ends_at", now))
			row = _start_soil_step(row, code, next_start)
			guard += 1
		improvements[cell] = row
	return grown

func _start_soil_step(row: Dictionary, code: int, now: float) -> Dictionary:
	row["code"] = code
	row["watered"] = false
	row["ends_at"] = now + Improvements.soil_step_seconds(code, int(row.get("rank", 1)))
	return row

static func tier_of(code: int) -> int:
	return code % 100

static func line_of(code: int) -> int:
	return int(code / 100.0)

func can_merge(a: Vector2i, b: Vector2i) -> bool:
	var k := item_at(a)
	if a == b or k <= 0 or item_at(b) != k:
		return false
	if not collect_reward_at(a).is_empty() or not collect_reward_at(b).is_empty():
		return false
	return tier_of(k) < G.merge_top(k)

func merge(a: Vector2i, b: Vector2i) -> int:
	var produced: int = item_at(a) + 1
	items[idx(a)] = 0
	items[idx(b)] = produced
	collect_rewards.erase(idx(a))
	collect_rewards.erase(idx(b))
	return produced

func move(a: Vector2i, b: Vector2i) -> void:
	var reward := collect_reward_at(a)
	items[idx(b)] = items[idx(a)]
	items[idx(a)] = 0
	collect_rewards.erase(idx(a))
	collect_rewards.erase(idx(b))
	if not reward.is_empty():
		collect_rewards[idx(b)] = reward

## P: trade the codes in two occupied cells — no merge, no side effects.
## Persists for free via to_dict (it serialises `items`).
func swap(a: Vector2i, b: Vector2i) -> void:
	var ka: int = items[idx(a)]
	var ra := collect_reward_at(a)
	var rb := collect_reward_at(b)
	items[idx(a)] = items[idx(b)]
	items[idx(b)] = ka
	collect_rewards.erase(idx(a))
	collect_rewards.erase(idx(b))
	if not rb.is_empty():
		collect_rewards[idx(a)] = rb
	if not ra.is_empty():
		collect_rewards[idx(b)] = ra

## Trade a generator with a regular occupied item cell. The generator's tier/boost rides with
## it, and any custom collect reward rides with the item to the generator's old cell.
func swap_gen_with_item(gen_cell: Vector2i, item_cell: Vector2i) -> bool:
	if gen_cell == item_cell or not gens.has(gen_cell) or gens.has(item_cell):
		return false
	if not is_open(gen_cell) or not is_open(item_cell):
		return false
	if item_at(gen_cell) != 0 or item_at(item_cell) <= 0:
		return false
	var gid := String(gens[gen_cell])
	var tier := gen_tier_at(gen_cell)
	var boost := gen_boost_at(gen_cell)
	var code := item_at(item_cell)
	var reward := collect_reward_at(item_cell)
	gens.erase(gen_cell)
	gen_tiers.erase(gen_cell)
	gen_boost.erase(gen_cell)
	items[idx(item_cell)] = 0
	items[idx(gen_cell)] = code
	collect_rewards.erase(idx(item_cell))
	collect_rewards.erase(idx(gen_cell))
	if not reward.is_empty():
		collect_rewards[idx(gen_cell)] = reward
	gens[item_cell] = gid
	gen_tiers[item_cell] = tier
	if boost > 0:
		gen_boost[item_cell] = boost
	return true

## Trade two non-mergeable generators. Mergeable same-line/same-tier pairs are deliberately
## refused here so callers keep routing those through merge_gens().
func swap_gens(a: Vector2i, b: Vector2i) -> bool:
	if a == b or not gens.has(a) or not gens.has(b):
		return false
	if not is_open(a) or not is_open(b) or item_at(a) != 0 or item_at(b) != 0:
		return false
	var tier_a := gen_tier_at(a)
	var tier_b := gen_tier_at(b)
	if String(gens[a]) == String(gens[b]) and tier_a == tier_b and tier_a < G.GEN_TOP_TIER:
		return false
	var aid := String(gens[a])
	var bid := String(gens[b])
	var boost_a := gen_boost_at(a)
	var boost_b := gen_boost_at(b)
	gens[a] = bid
	gens[b] = aid
	gen_tiers[a] = tier_b
	gen_tiers[b] = tier_a
	gen_boost.erase(a)
	gen_boost.erase(b)
	if boost_b > 0:
		gen_boost[a] = boost_b
	if boost_a > 0:
		gen_boost[b] = boost_a
	return true

func take(cell: Vector2i) -> int:
	var k := item_at(cell)
	items[idx(cell)] = 0
	collect_rewards.erase(idx(cell))
	return k

func place(cell: Vector2i, code: int) -> void:
	items[idx(cell)] = code
	collect_rewards.erase(idx(cell))

func collect_reward_at(cell: Vector2i) -> Dictionary:
	if not in_bounds(cell):
		return {}
	var reward = collect_rewards.get(idx(cell), {})
	if reward is Dictionary:
		return (reward as Dictionary).duplicate()
	return {}

func set_collect_reward(cell: Vector2i, kind: String, amount: int) -> void:
	if not in_bounds(cell):
		return
	var i := idx(cell)
	if kind == "" or amount <= 0:
		collect_rewards.erase(i)
		return
	collect_rewards[i] = {"kind": kind, "amount": amount}

func take_collect_reward(cell: Vector2i) -> Dictionary:
	var reward := collect_reward_at(cell)
	if in_bounds(cell):
		collect_rewards.erase(idx(cell))
	return reward

## Sealed cells adjacent to `cell` that a merge here can open: §4 level-gated — a neighbour
## opens when the player's Level has reached its G.cell_min_level. The merge is the trigger;
## the level gates *when* (any merge opens an eligible neighbour — no tier/line requirement).
func openable_brambles(cell: Vector2i, player_level: int) -> Array:
	var out: Array = []
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n: Vector2i = cell + d
		if is_bramble(n) and G.cell_min_level(n) <= player_level:
			out.append(n)
	return out

## Clear a bramble; its contents become the cell's item. `contents` < 0 means "derive the legacy
## positional seed" — the no-quest fallback and direct callers (the sim, model tests); the scene
## passes a quest-relevant seed (BoardLogic.bramble_seed). Returns the contents.
func open_bramble(cell: Vector2i, contents: int = -1) -> int:
	terrain[idx(cell)] = 0
	if contents < 0:
		contents = G.bramble_contents(cell)
	items[idx(cell)] = contents
	collect_rewards.erase(idx(cell))
	return contents

func empty_ground_cells() -> Array:
	var out: Array = []
	for i in items.size():
		var cell := cell_of(i)
		if is_empty_ground(cell):
			out.append(cell)
	return out

func bramble_count() -> int:
	var n := 0
	for v in terrain:
		if v > 0:
			n += 1
	return n

func count_of(code: int) -> int:
	var n := 0
	for v in items:
		if v == code:
			n += 1
	return n

func first_item_of(code: int) -> Vector2i:
	for i in items.size():
		if items[i] == code:
			return cell_of(i)
	return Vector2i(-1, -1)

func top_tier_cells() -> Array:
	var out: Array = []
	for i in items.size():
		if items[i] > 0 and not G.is_coin(items[i]) and tier_of(items[i]) == G.TOP_TIER:
			out.append(cell_of(i))
	return out

# --- persistence ---------------------------------------------------------------

func to_dict() -> Dictionary:
	var gl: Array = []
	for c in gens:
		gl.append([c.x, c.y, gens[c], gen_tier_at(c), gen_boost_at(c)])   # [row, col, id, tier, boost] — JSON-safe
	var cr: Array = []
	for i in collect_rewards:
		var cell := cell_of(int(i))
		var reward: Dictionary = collect_reward_at(cell)
		if not reward.is_empty():
			cr.append([cell.x, cell.y, String(reward.kind), int(reward.amount)])
	var il: Array = []
	var icells: Array = improvements.keys()
	icells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return idx(a) < idx(b))
	for cell in icells:
		var row := improvement_at(cell)
		if Improvements.is_valid_kind(String(row.get("kind", ""))):
			il.append([cell.x, cell.y, String(row.kind), int(row.rank), int(row.code), float(row.ends_at), bool(row.watered)])
	return {"terrain": Array(terrain), "items": Array(items), "gens": gl, "gen_bag": gen_bag.duplicate(), "gen_bag_tiers": gen_bag_tiers.duplicate(), "gen_bag_boost": gen_bag_boost.duplicate(), "collect_rewards": cr, "improvements": il}

func from_dict(d: Dictionary) -> bool:
	var changed := false
	var t: Array = d.get("terrain", [])
	var it: Array = d.get("items", [])
	if t.size() == terrain.size() and it.size() == items.size():
		for i in t.size():
			terrain[i] = int(t[i])
			var code := int(it[i])
			if code < 0 or (code > 0 and not G.is_valid_item_code(code)):
				code = 0
				changed = true
			items[i] = code
	else:
		# The saved board's DIMENSIONS don't match this build's (a ROWS/COLS change, or a truncated
		# blob). The whole terrain+items restore is skipped and the fresh starter layout stands — a
		# real wipe of the player's board, and it used to happen in total silence: `changed` stayed
		# false, so board.gd's save_dirty never fired and nothing anywhere said a word. The
		# generators, gen_bag and collect_rewards below still restore, so the result reads as a bug
		# rather than as the wipe it is. Report it, and mark it changed like every other discard path
		# here so the caller treats it as a real migration and rewrites the blob at the current size.
		push_error("BoardModel.from_dict: saved board SIZE MISMATCH — saved terrain %d / items %d vs this build's %d cells (%d×%d). The saved terrain and items were DISCARDED; the starter layout stands." \
			% [t.size(), it.size(), terrain.size(), G.ROWS, G.COLS])
		changed = true
	collect_rewards = {}
	for e in d.get("collect_rewards", []):
		if not (e is Array) or (e as Array).size() < 4:
			changed = true
			continue
		var cell := Vector2i(int(e[0]), int(e[1]))
		if in_bounds(cell) and item_at(cell) > 0:
			set_collect_reward(cell, String(e[2]), int(e[3]))
		else:
			changed = true
	gens = {}
	gen_tiers = {}
	gen_boost = {}
	for e in d.get("gens", []):
		if not (e is Array) or (e as Array).size() < 3:
			changed = true
			continue
		var gc := Vector2i(int(e[0]), int(e[1]))
		var gid := String(e[2])
		if not in_bounds(gc) or not G.is_valid_generator_id(gid):
			changed = true
			continue
		gens[gc] = gid
		gen_tiers[gc] = int(e[3]) if (e as Array).size() > 3 else 1   # #8: tier (old 3-element saves → 1)
		if (e as Array).size() > 4 and int(e[4]) > 0:
			gen_boost[gc] = int(e[4])           # §6: per-cell boost (absent in 4-element legacy entries → none)
	var raw_gen_bag: Array = Array(d.get("gen_bag", []))
	var bt: Array = Array(d.get("gen_bag_tiers", []))     # #8: parallel tiers (absent in old saves → all 1)
	var bb: Array = Array(d.get("gen_bag_boost", []))     # §6: parallel bag boosts (absent in old saves → all 0)
	gen_bag = []
	gen_bag_tiers = []
	gen_bag_boost = []
	for i in raw_gen_bag.size():
		var gid := String(raw_gen_bag[i])
		if not G.is_valid_generator_id(gid):
			changed = true
			continue
		gen_bag.append(gid)
		gen_bag_tiers.append(int(bt[i]) if i < bt.size() else 1)
		gen_bag_boost.append(int(bb[i]) if i < bb.size() else 0)
	improvements = {}
	for e in d.get("improvements", []):
		if not (e is Array) or (e as Array).size() < 3:
			changed = true
			continue
		var ic := Vector2i(int(e[0]), int(e[1]))
		var kind := String(e[2])
		if not in_bounds(ic) or not is_open(ic) or not Improvements.is_valid_kind(kind):
			changed = true
			continue
		var row := {
			"kind": kind,
			"rank": int(e[3]) if (e as Array).size() > 3 else 1,
			"code": int(e[4]) if (e as Array).size() > 4 else 0,
			"ends_at": float(e[5]) if (e as Array).size() > 5 else 0.0,
			"watered": bool(e[6]) if (e as Array).size() > 6 else false,
		}
		improvements[ic] = Improvements.normalize_activity(row)
	return changed
