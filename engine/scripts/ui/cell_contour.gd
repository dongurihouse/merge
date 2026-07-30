extends RefCounted
## The OUTLINE of a union of grid cells, as closed rounded contours. Pure: every function is
## static and takes plain data, so a headless suite calls it without a scene
## (games/grove/tests/grove_cascade_tests.gd).
##
## LATTICE COORDINATES. A cell is a model Vector2i. Corner (i, j) is the corner SHARED by cells
## (i-1,j-1), (i-1,j), (i,j-1) and (i,j) — so cell (r,c) owns corners (r,c), (r,c+1), (r+1,c+1)
## and (r+1,c). Nothing here knows about pixels or about the landscape transpose; the caller maps
## a lattice corner to the screen (cascade_outline.gd routes that through board.gd's `_cell_pos`,
## which owns the transpose).
##
## THE DIAGONAL PINCH. Two cells meeting at a corner only — the other two cells of that 2×2
## absent — leave a corner with TWO outgoing boundary edges. Keying edges by their start corner
## therefore LOSES one of them (the second write wins) and the walk then falls off the end. The
## walk below keeps both and resolves the saddle by taking the turn that keeps the interior on
## the same side, which splits the pinch into the two separate loops it really is.

## What `corner_kind` answers: how many of the four cells around a lattice corner are in the set.
enum { OFF_SHAPE, CONVEX, REFLEX, STRAIGHT, SADDLE }

## The four cells touching lattice corner `v`, in no particular order.
static func corner_cells(v: Vector2i) -> Array:
	return [v - Vector2i(1, 1), v - Vector2i(1, 0), v - Vector2i(0, 1), v]

static func cell_set(cells: Array) -> Dictionary:
	var s := {}
	for raw in cells:
		s[Vector2i(raw)] = true
	return s

## Classify lattice corner `v` against the cell set. A SADDLE is the diagonal pinch; it reads as a
## CONVEX corner in each of the two loops that pass through it.
static func corner_kind(cells: Dictionary, v: Vector2i) -> int:
	var tl := cells.has(v - Vector2i(1, 1))
	var tr := cells.has(v - Vector2i(1, 0))
	var bl := cells.has(v - Vector2i(0, 1))
	var br := cells.has(v)
	var n := int(tl) + int(tr) + int(bl) + int(br)
	if n == 0 or n == 4:
		return OFF_SHAPE
	if n == 1:
		return CONVEX
	if n == 3:
		return REFLEX
	if (tl and br) or (tr and bl):
		return SADDLE
	return STRAIGHT

## A corner the contour must cut INTO the shape at (an inner corner of an L or a T). Everything
## else the contour bulges around.
static func is_reflex(cells: Dictionary, v: Vector2i) -> bool:
	return corner_kind(cells, v) == REFLEX

## The boundary of the union of `cells`, as closed loops of lattice CORNERS (collinear points
## dropped, so every point returned is a real corner). An outer silhouette and each hole come back
## as separate loops, wound in opposite senses — `signed_area` tells them apart. Two cells touching
## only at a corner come back as two loops, which is what they look like.
static func boundary_loops(cells: Array) -> Array:
	var s := cell_set(cells)
	var edges: Array = []
	var by_start := {}
	for raw in s:
		var c := Vector2i(raw)
		var tl := c
		var tr := c + Vector2i(0, 1)
		var br := c + Vector2i(1, 1)
		var bl := c + Vector2i(1, 0)
		# Wound so the cell is always on the same hand: top runs -j, bottom +j, left +i, right -i.
		if not s.has(c + Vector2i(-1, 0)):
			_add_edge(edges, by_start, tr, tl)
		if not s.has(c + Vector2i(1, 0)):
			_add_edge(edges, by_start, bl, br)
		if not s.has(c + Vector2i(0, -1)):
			_add_edge(edges, by_start, tl, bl)
		if not s.has(c + Vector2i(0, 1)):
			_add_edge(edges, by_start, br, tr)
	var used := []
	used.resize(edges.size())
	used.fill(false)
	var loops: Array = []
	for seed in edges.size():
		if used[seed]:
			continue
		var loop: Array = []
		var at := seed
		while true:
			used[at] = true
			loop.append(Vector2i(edges[at][0]))
			var nxt := _next_edge(edges, by_start, at)
			if nxt < 0 or used[nxt]:
				break
			at = nxt
		var trimmed := drop_collinear(loop)
		if trimmed.size() >= 3:
			loops.append(trimmed)
	return loops

static func _add_edge(edges: Array, by_start: Dictionary, a: Vector2i, b: Vector2i) -> void:
	var idx := edges.size()
	edges.append([a, b])
	var lst: Array = by_start.get(a, [])
	lst.append(idx)
	by_start[a] = lst

## The edge that continues the walk past `edges[at]`. One candidate is the ordinary case; TWO is the
## diagonal pinch, and there the interior stays on the same side only if the turn keeps its sign —
## dropping either candidate instead would delete a real edge of the outline.
static func _next_edge(edges: Array, by_start: Dictionary, at: int) -> int:
	var cands: Array = by_start.get(Vector2i(edges[at][1]), [])
	if cands.size() == 1:
		return int(cands[0])
	var din: Vector2i = Vector2i(edges[at][1]) - Vector2i(edges[at][0])
	for raw in cands:
		var ci := int(raw)
		var dout: Vector2i = Vector2i(edges[ci][1]) - Vector2i(edges[ci][0])
		if din.x * dout.y - din.y * dout.x > 0:
			return ci
	return -1

static func drop_collinear(pts: Array) -> Array:
	var n := pts.size()
	if n < 3:
		return pts.duplicate()
	var out: Array = []
	for i in n:
		var a: Vector2i = Vector2i(pts[(i - 1 + n) % n])
		var b: Vector2i = Vector2i(pts[i])
		var c: Vector2i = Vector2i(pts[(i + 1) % n])
		if (b.x - a.x) * (c.y - b.y) != (b.y - a.y) * (c.x - b.x):
			out.append(b)
	return out

## Replace each corner of a closed polygon with a circular arc of `radii[i]`. A radius of 0 keeps
## the corner sharp. Every corner of a grid contour is a right angle, which is the case where a
## fillet's tangent points sit exactly `r` from the corner along each edge — hence the construction.
static func round_loop(pts: PackedVector2Array, radii: PackedFloat32Array, arc_steps := 6) -> PackedVector2Array:
	var n := pts.size()
	var out := PackedVector2Array()
	if n < 3:
		return pts
	for i in n:
		var p := pts[i]
		var a := pts[(i - 1 + n) % n]
		var b := pts[(i + 1) % n]
		var va := a - p
		var vb := b - p
		var la := va.length()
		var lb := vb.length()
		var rr: float = minf(radii[i] if i < radii.size() else 0.0, minf(la, lb) * 0.5)
		if rr <= 0.01 or la < 0.001 or lb < 0.001:
			out.append(p)
			continue
		va /= la
		vb /= lb
		var bis := va + vb
		if bis.length() < 1e-5:
			out.append(p)
			continue
		bis = bis.normalized()
		var half := acos(clampf(va.dot(vb), -1.0, 1.0)) * 0.5
		var centre := p + bis * (rr / maxf(sin(half), 1e-5))
		var pa := p + va * rr
		var pb := p + vb * rr
		var a0 := (pa - centre).angle()
		var a1 := (pb - centre).angle()
		while a1 - a0 > PI:
			a1 -= TAU
		while a1 - a0 < -PI:
			a1 += TAU
		for k in arc_steps + 1:
			var t := a0 + (a1 - a0) * float(k) / float(arc_steps)
			out.append(centre + Vector2(cos(t), sin(t)) * rr)
	return out

## Walk a closed polyline and emit points at a UNIFORM arc step, so the index of a point IS its
## arc length — the travelling wave rides that index directly. The step is rounded so the loop
## closes exactly, which keeps an integer number of wave cycles seamless across the wrap.
static func resample_closed(poly: PackedVector2Array, step: float) -> PackedVector2Array:
	var n := poly.size()
	var out := PackedVector2Array()
	if n < 3 or step <= 0.0:
		return poly
	var seg := PackedFloat32Array()
	var total := 0.0
	for i in n:
		var l := poly[(i + 1) % n].distance_to(poly[i])
		seg.append(l)
		total += l
	if total <= 0.0:
		return poly
	var count: int = maxi(8, int(roundf(total / step)))
	var want := total / float(count)
	var at := 0
	var walked := 0.0
	for k in count:
		var target := float(k) * want
		while at < n - 1 and walked + seg[at] < target:
			walked += seg[at]
			at += 1
		var t: float = 0.0 if seg[at] <= 0.0 else clampf((target - walked) / seg[at], 0.0, 1.0)
		out.append(poly[at].lerp(poly[(at + 1) % n], t))
	return out

static func signed_area(poly: PackedVector2Array) -> float:
	var n := poly.size()
	var acc := 0.0
	for i in n:
		var a := poly[i]
		var b := poly[(i + 1) % n]
		acc += a.x * b.y - b.x * a.y
	return acc * 0.5

## Which hand a closed loop is wound on: +1 or -1, the sign of its signed area.
static func winding_side(poly: PackedVector2Array) -> float:
	return 1.0 if signed_area(poly) > 0.0 else -1.0

## Per-vertex MITRE offset vectors for a closed loop: `poly[i] + offsets[i] * t` is the loop offset
## by `t` outward. The mitre is the exact offset at a right-angle corner (it lands on the crossing
## point of the two offset edges), so a reflex corner clips instead of self-intersecting and a convex
## one fans.
##
## `side` is the hand the CELL LATTICE is wound on once mapped to the screen — the caller's business,
## because the landscape transpose is a reflection and flips it. It must NOT be taken from each
## loop's own winding: `boundary_loops` winds a hole the other way, and the one fixed side is exactly
## what turns that into "out of the shape" for a silhouette and "into the hole" for a hole. Pass 0 to
## fall back to this loop's own winding, which is right for a lone convex shape and nothing else.
static func mitre_offsets(poly: PackedVector2Array, side := 0.0) -> PackedVector2Array:
	var n := poly.size()
	var out := PackedVector2Array()
	if is_zero_approx(side):
		side = winding_side(poly)
	for i in n:
		var prev := poly[(i - 1 + n) % n]
		var nxt := poly[(i + 1) % n]
		var e0 := (poly[i] - prev)
		var e1 := (nxt - poly[i])
		if e0.length() < 1e-6:
			e0 = e1
		if e1.length() < 1e-6:
			e1 = e0
		e0 = e0.normalized()
		e1 = e1.normalized()
		var n0 := Vector2(e0.y, -e0.x) * side
		var n1 := Vector2(e1.y, -e1.x) * side
		var denom := 1.0 + n0.dot(n1)
		out.append(n0 if denom < 0.25 else (n0 + n1) / denom)
	return out
