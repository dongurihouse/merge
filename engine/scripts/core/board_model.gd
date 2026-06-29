extends RefCounted
## The persistent board model (pure data, fully serializable).
## Terrain per cell: 0 = open ground; >0 = a SEALED obstacle cell (§4). The gate is the player's
## Level vs the static G.cell_min_level table — NOT the stored value — so legacy saves (the old
## gate_line*16+tier encoding) still read correctly as "sealed" and need no migration.
## Items: line*100 + tier (0 = none). A generator occupies its cell permanently.

const G = preload("res://engine/scripts/core/content.gd")

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
	for g in G.generators_for_map(G.GENERATORS, map, level):
		if bool(g.get("anchor", false)):
			gens[Vector2i(g.get("cell", Vector2i(-1, -1)))] = String(g.id)
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
	gens.erase(cell)
	gen_tiers.erase(cell)                      # no stale tier left behind on the now-empty cell
	return true

## Place a stored generator from the bag onto an open, empty, non-generator cell. #8: restores the stored TIER.
func place_gen_from_bag(id: String, cell: Vector2i) -> bool:
	# is_open already guarantees terrain == 0 (an open, empty cell)
	var i := gen_bag.find(id)
	if i < 0 or gens.has(cell) or not is_open(cell) or item_at(cell) != 0:
		return false
	var tier := _bag_tier_at(i)               # read the tier BEFORE removing the entry
	gen_bag.remove_at(i)
	if i < gen_bag_tiers.size():
		gen_bag_tiers.remove_at(i)
	gens[cell] = id
	gen_tiers[cell] = tier                     # restore the stored tier (not a silent reset to 1)
	return true

## Append a generator id to the bag at `tier` (default 1) — the canonical bag-push that keeps
## gen_bag_tiers aligned. Use this instead of a raw gen_bag.append(...).
func bag_add(id: String, tier: int = 1) -> void:
	gen_bag.append(String(id))
	gen_bag_tiers.append(maxi(1, tier))

## The tier of the bagged generator at index `i` (1 if out of range — tolerates a transient skew).
func _bag_tier_at(i: int) -> int:
	return int(gen_bag_tiers[i]) if i >= 0 and i < gen_bag_tiers.size() else 1

## Filter the bag in place, keeping only ids for which `should_keep.call(id)` is true — rebuilds
## gen_bag and its parallel tiers together so they stay aligned.
func prune_bag(should_keep: Callable) -> void:
	var ids: Array = []
	var tiers: Array = []
	for i in gen_bag.size():
		if bool(should_keep.call(String(gen_bag[i]))):
			ids.append(gen_bag[i])
			tiers.append(_bag_tier_at(i))
	gen_bag = ids
	gen_bag_tiers = tiers

## #1 — a generator is a movable piece (§2): relocate it to an empty, open, non-generator
## cell. Refuses an occupied cell, a bramble, or another generator's cell. Persisted via `gens`.
func move_gen(from: Vector2i, to: Vector2i) -> bool:
	if not gens.has(from) or gens.has(to) or not is_open(to) or item_at(to) != 0:
		return false
	gens[to] = gens[from]
	gens.erase(from)
	gen_tiers[to] = gen_tier_at(from)     # #8: the tier travels with the generator
	gen_tiers.erase(from)
	return true

# The TIER of the generator at `cell` (1..GEN_TOP_TIER); 1 if unset. Gen redesign #8.
func gen_tier_at(cell: Vector2i) -> int:
	return int(gen_tiers.get(cell, 1))

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
	return true

## A generator that VANISHES in place (a spent bonus/treat gen): erase BOTH `gens` and its tier so no stale
## gen_tier is left on the now-empty cell — mirrors store_gen / merge_gens / move_gen. Returns true if one was
## removed. (board.gd used a raw `gens.erase(cell)` that orphaned the tier; route those through here.)
func remove_gen(cell: Vector2i) -> bool:
	if not gens.has(cell):
		return false
	gens.erase(cell)
	gen_tiers.erase(cell)
	return true

## Place a single generator at `cell` — claims the cell (sheds bramble / hops any item to
## safety), like seed_gens. No-op if a generator already sits there.
func place_gen(id: String, cell: Vector2i) -> void:
	if gens.has(cell):
		return
	gens[cell] = id
	if not gen_tiers.has(cell):
		gen_tiers[cell] = 1               # #8: new generators start at tier 1
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
		place_gen(id, cell)
		added.append(id)
	return added

func is_empty_ground(cell: Vector2i) -> bool:
	return is_open(cell) and item_at(cell) == 0 and not is_gen(cell)

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

func any_pair_exists() -> bool:
	var seen := {}
	for i in items.size():
		var k: int = items[i]
		if k <= 0 or tier_of(k) >= G.merge_top(k):
			continue
		if seen.has(k):
			return true
		seen[k] = true
	return false

## Merge a onto b → b holds the next tier; returns the produced code.
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
		gl.append([c.x, c.y, gens[c], gen_tier_at(c)])   # [row, col, id, tier] — JSON-safe (no Vector2i keys)
	var cr: Array = []
	for i in collect_rewards:
		var cell := cell_of(int(i))
		var reward: Dictionary = collect_reward_at(cell)
		if not reward.is_empty():
			cr.append([cell.x, cell.y, String(reward.kind), int(reward.amount)])
	return {"terrain": Array(terrain), "items": Array(items), "gens": gl, "gen_bag": gen_bag.duplicate(), "gen_bag_tiers": gen_bag_tiers.duplicate(), "collect_rewards": cr}

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
	var raw_gen_bag: Array = Array(d.get("gen_bag", []))
	var bt: Array = Array(d.get("gen_bag_tiers", []))     # #8: parallel tiers (absent in old saves → all 1)
	gen_bag = []
	gen_bag_tiers = []
	for i in raw_gen_bag.size():
		var gid := String(raw_gen_bag[i])
		if not G.is_valid_generator_id(gid):
			changed = true
			continue
		gen_bag.append(gid)
		gen_bag_tiers.append(int(bt[i]) if i < bt.size() else 1)
	return changed
