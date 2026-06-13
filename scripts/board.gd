extends RefCounted
##
## Reach Zero core rules — pure logic, no UI.
## ADJACENCY + SLIDING merge-to-empty (see docs/archive/reach_zero_spec.md §2).
##
## A piece slides rook-style through EMPTY cells only (no jumping, no gravity),
## stopping on any empty cell in that straight line. Two pieces MERGE only when
## one is slid to a cell orthogonally adjacent to a matching piece (same family
## AND same tier). The result lands on the target cell; the source cell empties
## (net -1 occupied). Merging two TOP-tier pieces SHOWCASES them: both vaporize
## (net -2). The board is won when it is perfectly empty ("ZERO").
##
## Cell codes (flat row-major Array[int]):
##   0   = EMPTY
##  -1   = WALL (impassable fixture; never a piece, never cleared)
##  >0   = piece, encoded as family*100 + tier   (family >= 1, tier 1..top_tier)
##
## This engine was validated against an exhaustive Python reference solver; see
## tests/run_tests.gd (run headless with: godot --headless -s res://tests/run_tests.gd).

const EMPTY := 0
const WALL := -1
const DRAWER := -2        # a locked drawer/box: not a piece; pops to its contents on an adjacent merge
const DIRS: Array[Vector2i] = [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]

var rows: int
var cols: int
var grid: Array          # flat Array[int], length rows*cols
var top_tier: int        # showcase fires when two tier==top_tier pieces merge

func _init(_rows: int, _cols: int, _grid: Array, _top: int = 3) -> void:
	rows = _rows
	cols = _cols
	grid = _grid.duplicate()
	top_tier = _top

# --- code helpers -----------------------------------------------------------
static func make_code(family: int, tier: int) -> int:
	return family * 100 + tier

static func family_of(c: int) -> int:
	return floori(c / 100.0) if c > 0 else 0

static func tier_of(c: int) -> int:
	return c % 100 if c > 0 else 0

static func is_piece(c: int) -> bool:
	return c > 0

# --- board queries ----------------------------------------------------------
func index(r: int, c: int) -> int:
	return r * cols + c

func at(r: int, c: int) -> int:
	return grid[index(r, c)]

func in_bounds(r: int, c: int) -> bool:
	return r >= 0 and r < rows and c >= 0 and c < cols

func duplicate_grid() -> Array:
	return grid.duplicate()

func is_cleared() -> bool:
	for v in grid:
		if v > 0 or v == DRAWER:
			return false
	return true

func piece_count() -> int:
	var n := 0
	for v in grid:
		if v > 0:
			n += 1
	return n

# --- UI move queries (operate on this board's current grid) ------------------

## Empty cells the piece at (r,c) can slide to in a single straight (rook) move.
func reachable_empties(r: int, c: int) -> Array:
	var res := []
	if not is_piece(at(r, c)):
		return res
	for d in DIRS:
		var sr := r + d.x
		var sc := c + d.y
		while in_bounds(sr, sc) and at(sr, sc) == EMPTY:
			res.append(Vector2i(sr, sc))
			sr += d.x
			sc += d.y
	return res

## Matching pieces the piece at (r,c) can legally merge with this move:
## either it is already orthogonally adjacent, or it can reach (by one straight
## slide) an empty cell orthogonally adjacent to the match.
func merge_targets(r: int, c: int) -> Array:
	var k := at(r, c)
	if not is_piece(k):
		return []
	var landing := {}
	for e in reachable_empties(r, c):
		landing[e] = true
	var res := []
	for rr in rows:
		for cc in cols:
			if rr == r and cc == c:
				continue
			if at(rr, cc) != k:
				continue
			var ok := false
			# zero-distance: source already adjacent to the match
			for d in DIRS:
				if r + d.x == rr and c + d.y == cc:
					ok = true
			# via a reachable empty cell adjacent to the match
			if not ok:
				for d in DIRS:
					if landing.has(Vector2i(rr + d.x, cc + d.y)):
						ok = true
			if ok:
				res.append(Vector2i(rr, cc))
	return res

func is_showcase_merge(r: int, c: int) -> bool:
	return tier_of(at(r, c)) == top_tier

# --- mutations (used by the UI after a legal tap) ----------------------------

func apply_merge(r: int, c: int, br: int, bc: int) -> void:
	var k := at(r, c)
	grid[index(r, c)] = EMPTY
	grid[index(br, bc)] = EMPTY if tier_of(k) == top_tier else k + 1

func apply_reposition(r: int, c: int, sr: int, sc: int) -> void:
	var k := at(r, c)
	grid[index(r, c)] = EMPTY
	grid[index(sr, sc)] = k

# --- successor generation & solver (used by tests + level validation) --------

## Every successor grid reachable in one legal action (slides + merges).
func successors() -> Array:
	var out := []
	for r in rows:
		for c in cols:
			var k := at(r, c)
			if k <= 0:
				continue
			var t := tier_of(k)
			# zero-distance merges
			for d in DIRS:
				var nr := r + d.x
				var nc := c + d.y
				if in_bounds(nr, nc) and at(nr, nc) == k:
					out.append(_merge_result(r, c, nr, nc, t))
			# slides (and merge-after-slide)
			for d in DIRS:
				var sr := r + d.x
				var sc := c + d.y
				while in_bounds(sr, sc) and at(sr, sc) == EMPTY:
					out.append(_reposition_result(r, c, sr, sc, k))
					for d2 in DIRS:
						var br := sr + d2.x
						var bc := sc + d2.y
						if in_bounds(br, bc) and at(br, bc) == k and not (br == r and bc == c):
							out.append(_merge_result(r, c, br, bc, t))
					sr += d.x
					sc += d.y
	return out

func _merge_result(r: int, c: int, br: int, bc: int, t: int) -> Array:
	var g := grid.duplicate()
	var k : int = g[index(r, c)]
	g[index(r, c)] = EMPTY
	g[index(br, bc)] = EMPTY if t == top_tier else k + 1
	return g

func _reposition_result(r: int, c: int, sr: int, sc: int, k: int) -> Array:
	var g := grid.duplicate()
	g[index(r, c)] = EMPTY
	g[index(sr, sc)] = k
	return g

## True iff the empty board is reachable from the current state (BFS, capped).
func is_solvable(cap: int = 200000) -> bool:
	var visited := {}
	var queue : Array = [grid.duplicate()]
	visited[str(queue[0])] = true
	var head := 0
	while head < queue.size():
		var st : Array = queue[head]
		head += 1
		var b = (get_script() as GDScript).new(rows, cols, st, top_tier)
		if b.is_cleared():
			return true
		for ng in b.successors():
			var key := str(ng)
			if not visited.has(key):
				visited[key] = true
				queue.append(ng)
				if visited.size() > cap:
					return false
	return false

## Count of distinct reachable states (diagnostic; capped).
func reachable_state_count(cap: int = 200000) -> int:
	var visited := {}
	var queue : Array = [grid.duplicate()]
	visited[str(queue[0])] = true
	var head := 0
	while head < queue.size():
		var st : Array = queue[head]
		head += 1
		var b = (get_script() as GDScript).new(rows, cols, st, top_tier)
		for ng in b.successors():
			var key := str(ng)
			if not visited.has(key):
				visited[key] = true
				queue.append(ng)
				if visited.size() > cap:
					return visited.size()
	return visited.size()
