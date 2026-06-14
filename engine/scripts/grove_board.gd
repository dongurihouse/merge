extends RefCounted
## Ghibli Grove — the persistent board model (pure data, fully serializable).
## Terrain per cell: 0 = open ground; >0 = bramble encoded gate_line*16 + req_tier
## (gate_line 0 = any line; legacy saves stored the bare tier — same decoding).
## Items: line*100 + tier (0 = none). A generator occupies its cell permanently.

const G = preload("res://engine/scripts/grove_content.gd")

var terrain := PackedInt32Array()
var items := PackedInt32Array()
var gen_cells: Array = [G.GEN_CELL]       # active generators (chapter-driven; scene/sim set)

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
	return gen_cells.has(cell)

## Activate the generators for a chapter: newly revealed ones shed their bramble,
## and any player item caught on the cell hops to free ground (never destroyed).
## Returns the cells that just became generators (for the scene's reveal beat).
func set_active_gens(chapter: int) -> Array:
	var fresh: Array = []
	for i in G.active_gen_indices(chapter):
		var cell: Vector2i = Vector2i(G.GENERATORS[i].cell)
		if not gen_cells.has(cell):
			gen_cells.append(cell)
			fresh.append(cell)
		if terrain[idx(cell)] > 0:
			terrain[idx(cell)] = 0           # the reveal clears its bramble (no contents)
			items[idx(cell)] = 0
		elif items[idx(cell)] > 0:
			var refuge := empty_ground_cells()
			if not refuge.is_empty():
				items[idx(Vector2i(refuge[0]))] = items[idx(cell)]
			items[idx(cell)] = 0
	return fresh

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
	return {"terrain": Array(terrain), "items": Array(items)}

func from_dict(d: Dictionary) -> void:
	var t: Array = d.get("terrain", [])
	var it: Array = d.get("items", [])
	if t.size() == terrain.size() and it.size() == items.size():
		for i in t.size():
			terrain[i] = int(t[i])
			items[i] = int(it[i])
