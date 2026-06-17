extends RefCounted
## The persistent board model (pure data, fully serializable).
## Terrain per cell: 0 = open ground; >0 = a SEALED obstacle cell (§4). The gate is the player's
## Level vs the static G.cell_min_level table — NOT the stored value — so legacy saves (the old
## gate_line*16+tier encoding) still read correctly as "sealed" and need no migration.
## Items: line*100 + tier (0 = none). A generator occupies its cell permanently.

const G = preload("res://engine/scripts/core/content.gd")

var terrain := PackedInt32Array()
var items := PackedInt32Array()
var gens: Dictionary = {}                 # cell -> generator id; the LIVE generators (§6),
                                          # STATEFUL + persisted (movable; granted via hand-in, §6/§7).
                                          # Seeded by seed_gens / restored by from_dict.

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
## seeded, the set changes only by move_gen / grant_gen. Each gen cell sheds its bramble,
## and any player item caught on it hops to free ground (never destroyed).
func seed_gens(map: int, level: int = G.APPEAR_ALL) -> void:
	gens = G.live_gen_state(G.GENERATORS, map, level)
	_claim_gen_cells()

func _claim_gen_cells() -> void:
	for cell in gens:
		if terrain[idx(cell)] > 0:
			terrain[idx(cell)] = 0           # clears its bramble (no contents)
			items[idx(cell)] = 0
		elif items[idx(cell)] > 0:
			var refuge := empty_ground_cells()
			if not refuge.is_empty():
				items[idx(Vector2i(refuge[0]))] = items[idx(cell)]
			items[idx(cell)] = 0

## #1 — a generator is a movable piece (§2): relocate it to an empty, open, non-generator
## cell. Refuses an occupied cell, a bramble, or another generator's cell. Persisted via `gens`.
func move_gen(from: Vector2i, to: Vector2i) -> bool:
	if not gens.has(from) or gens.has(to) or not is_open(to) or item_at(to) != 0:
		return false
	gens[to] = gens[from]
	gens.erase(from)
	return true

## #2 — the generator-grant hand-in (§6): a generator-grant quest hands the predecessor
## of `grant_id` in (wherever it sits on the board) and installs `grant_id` in its place —
## old consumed, old lines retire (they drop out of gen_live_lines). Validated against the
## lineage. Generators never merge to evolve (that mechanic is retired).
func grant_gen(grant_id: String) -> bool:
	if not G.gen_can_grant(gens, G.GENERATORS, grant_id):
		return false
	gens = G.gen_grant(gens, G.GENERATORS, grant_id)
	return true

## Place a single granted-OUTRIGHT (surplus) generator at `cell` (§6) — used when a new map
## opens: its surplus generators appear directly, while its hand-in generators arrive by grant
## quest. Claims the cell (sheds bramble / hops any item to safety), like seed_gens. No-op if a
## generator already sits there.
func place_surplus_gen(id: String, cell: Vector2i) -> void:
	if gens.has(cell):
		return
	gens[cell] = id
	if terrain[idx(cell)] > 0:
		terrain[idx(cell)] = 0
		items[idx(cell)] = 0
	elif items[idx(cell)] > 0:
		var refuge := empty_ground_cells()
		if not refuge.is_empty():
			items[idx(Vector2i(refuge[0]))] = items[idx(cell)]
		items[idx(cell)] = 0

## Compat shim for the fresh-run tools (sim / shot) that still ask for a spot-count's
## generators: re-seed to the map that many home spots reaches. NOT used by the live board
## (which restores `gens` from save and only mutates it via move/grant). Returns the live gen cells.
func set_active_gens(spots: int, level: int = G.APPEAR_ALL) -> Array:
	seed_gens(G.map_for_spots(spots), level)
	return gens.keys()

## Install any of `map`'s surplus generators that have GROWN IN by `level` (appear_level
## reached) but are not yet on the board — the staged-second-generator path (§ owner: don't
## open with two generators). Idempotent: a generator already present is skipped, so this is
## safe to call on every board open / level-up. Returns the ids newly installed (for a beat).
func grow_surplus_gens(map: int, level: int) -> Array:
	var added: Array = []
	for id in G.surplus_gen_ids(G.GENERATORS, map):
		var gdef := G.gen_def(G.GENERATORS, id)
		if int(gdef.get("appear_level", 0)) > level or gens.values().has(id):
			continue
		place_surplus_gen(id, G.gen_cell_of(G.GENERATORS, id))
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
	var top: int = G.COIN_TOP if G.is_coin(k) else G.TOP_TIER
	return tier_of(k) < top

## Merge a onto b → b holds the next tier; returns the produced code.
func merge(a: Vector2i, b: Vector2i) -> int:
	var produced: int = item_at(a) + 1
	items[idx(a)] = 0
	items[idx(b)] = produced
	return produced

func move(a: Vector2i, b: Vector2i) -> void:
	items[idx(b)] = items[idx(a)]
	items[idx(a)] = 0

## P: trade the codes in two occupied cells — no merge, no side effects.
## Persists for free via to_dict (it serialises `items`).
func swap(a: Vector2i, b: Vector2i) -> void:
	var ka: int = items[idx(a)]
	items[idx(a)] = items[idx(b)]
	items[idx(b)] = ka

func take(cell: Vector2i) -> int:
	var k := item_at(cell)
	items[idx(cell)] = 0
	return k

func place(cell: Vector2i, code: int) -> void:
	items[idx(cell)] = code

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

## Clear a bramble; its contents become the cell's item. Returns the contents.
func open_bramble(cell: Vector2i) -> int:
	terrain[idx(cell)] = 0
	var contents := G.bramble_contents(cell)
	items[idx(cell)] = contents
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

## Any merge available among unlocked items? (the pigeonhole check)
func any_pair_exists() -> bool:
	var seen := {}
	for i in items.size():
		var k := items[i]
		if k > 0 and tier_of(k) < G.TOP_TIER:
			if seen.has(k):
				return true
			seen[k] = true
	return false

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
		gl.append([c.x, c.y, gens[c]])       # [row, col, id] — JSON-safe (no Vector2i keys)
	return {"terrain": Array(terrain), "items": Array(items), "gens": gl}

func from_dict(d: Dictionary) -> void:
	var t: Array = d.get("terrain", [])
	var it: Array = d.get("items", [])
	if t.size() == terrain.size() and it.size() == items.size():
		for i in t.size():
			terrain[i] = int(t[i])
			items[i] = int(it[i])
	gens = {}
	for e in d.get("gens", []):
		gens[Vector2i(int(e[0]), int(e[1]))] = String(e[2])
