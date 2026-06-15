extends RefCounted
## The persistent board model (pure data, fully serializable).
## Terrain per cell: 0 = open ground; >0 = bramble encoded gate_line*16 + req_tier
## (gate_line 0 = any line; legacy saves stored the bare tier — same decoding).
## Items: line*100 + tier (0 = none). A generator occupies its cell permanently.

const G = preload("res://engine/scripts/content.gd")

var terrain := PackedInt32Array()
var items := PackedInt32Array()
var gens: Dictionary = {}                 # cell -> generator id; the LIVE generators (§6),
                                          # STATEFUL + persisted (movable + player-evolved, T17).
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

static func gate_line_of(terr: int) -> int:
	return int(terr / 16.0)

static func gate_req_of(terr: int) -> int:
	return terr % 16

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

## Seed the live generator set to a zone's roster (§6) — used on a fresh game (zone 0) and
## by the save migration (an existing player's current zone). NOT the in-play path: once
## seeded, the set changes only by move_gen / evolve_gen. Each gen cell sheds its bramble,
## and any player item caught on it hops to free ground (never destroyed).
func seed_gens(zone: int) -> void:
	gens = G.live_gen_state(G.GENERATORS, zone)
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

## #2 — the evolve-merge (§6): the grant generator at `grant_cell` merges onto the
## predecessor it upgrades at `old_cell` — old consumed, new installed at the old's cell,
## old lines retire (they drop out of gen_live_lines). Validated against the lineage.
func evolve_gen(old_cell: Vector2i, grant_cell: Vector2i) -> bool:
	var grant_id := String(gens.get(grant_cell, ""))
	if grant_id == "" or not G.gen_can_evolve(gens, G.GENERATORS, old_cell, grant_id):
		return false
	gens.erase(grant_cell)
	gens[old_cell] = grant_id
	return true

## Compat shim for the fresh-run tools (sim / shot) that still ask for a chapter's
## generators: re-seed to that chapter's zone. NOT used by the live board (which restores
## `gens` from save and only mutates it via move/evolve). Returns the live gen cells.
func set_active_gens(chapter: int) -> Array:
	seed_gens(G.zone_of_chapter(chapter))
	return gens.keys()

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

## Brambles adjacent to `cell` that the produced ITEM opens: its tier must meet
## the requirement, and a line-gated bramble also wants the produced item's line.
func openable_brambles(cell: Vector2i, produced_code: int) -> Array:
	var out: Array = []
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n: Vector2i = cell + d
		if not is_bramble(n):
			continue
		var terr := terrain[idx(n)]
		var gate := gate_line_of(terr)
		if tier_of(produced_code) >= gate_req_of(terr) and (gate == 0 or gate == line_of(produced_code)):
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
