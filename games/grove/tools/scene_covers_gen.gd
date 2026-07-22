extends RefCounted
## Zone-fill COVER generator (pure, no rendering) for the scene workbench.
## Given a hand-drawn zone polygon and the scene's coverup art, scatters coverup sprites that
## BLANKET the zone — a jittered grid of overlapping sprites (spacing < sprite size), a mix of
## larger/smaller sizes and random rotations ("different directions"), spilling up to OVERFLOW of
## the zone's short side past its edge so the boundary is fully covered. Each roll takes a fresh
## seed, so `generate` again gives a new scatter over the same zone.
##
## Emits scene_workbench_model entries in the `coverup` layer, cluster `unlock_region_<object>`,
## tagged `unlockCover:true` — the same shape the covers were hand-authored in (see coral). The
## caller feeds them through M.add_entry (which uniquifies ids) and persists with ⌘S.

const NOMINAL_FRAC := 0.55     # a cover's nominal size as a fraction of the zone's SHORT side
const SPACING_FACTOR := 0.45   # grid spacing as a fraction of nominal size (<1 → neighbours overlap)
const JITTER := 0.34           # per-cell random offset, as a fraction of the spacing
const SIZE_MIN := 0.70         # per-sprite size range, relative to nominal (the larger/smaller mix)
const SIZE_MAX := 1.30
const ROT_SPREAD := 30.0       # ± degrees of random rotation
const OVERFLOW := 0.02         # keep centres up to this fraction of the short side OUTSIDE the zone
const MAX_COVERS := 60         # safety cap so a huge zone never emits a runaway pile

## Scatter covers to fill `polygon` (native canvas Vector2s). `assets` is the coverup art to pull
## from: [{id, image (repo-relative), w, h}] (w/h the source's native pixel size, for aspect).
## Returns an Array of entry Dictionaries (empty when the zone or art is degenerate).
static func generate(polygon: Array, assets: Array, cluster: String, cluster_z: int, seed: int) -> Array:
	var out: Array = []
	if polygon.size() < 3 or assets.is_empty():
		return out
	var bb := _bbox(polygon)
	var short_side := minf(bb.size.x, bb.size.y)
	if short_side <= 0.0:
		return out
	var nominal := short_side * NOMINAL_FRAC
	var spacing := maxf(nominal * SPACING_FACTOR, 1.0)
	var margin := short_side * OVERFLOW

	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var covers: Array = []
	var y := bb.position.y
	while y <= bb.end.y + margin:
		var x := bb.position.x
		while x <= bb.end.x + margin:
			var c := Vector2(x, y) + Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * spacing * JITTER
			if _in_poly(c, polygon) or _dist_to_poly(c, polygon) <= margin:
				var a: Dictionary = assets[rng.randi_range(0, assets.size() - 1)]
				var target := nominal * rng.randf_range(SIZE_MIN, SIZE_MAX)
				var aw := maxf(float(a.get("w", 1)), 1.0)
				var ah := maxf(float(a.get("h", 1)), 1.0)
				var f := target / maxf(aw, ah)
				covers.append({
					"c": c,
					"w": maxi(1, int(round(aw * f))),
					"h": maxi(1, int(round(ah * f))),
					"rot": int(round(rng.randf_range(-ROT_SPREAD, ROT_SPREAD))),
					"id": String(a.get("id", "cover")),
					"image": String(a.get("image", "")),
				})
			x += spacing
		y += spacing

	# Safety cap: keep an evenly-strided subset so coverage stays spread, never a random clump.
	if covers.size() > MAX_COVERS:
		var strided: Array = []
		var step := float(covers.size()) / float(MAX_COVERS)
		var k := 0.0
		while int(k) < covers.size() and strided.size() < MAX_COVERS:
			strided.append(covers[int(k)])
			k += step
		covers = strided

	# Painter order: lower (larger y) sprites paint over higher ones, tucking flat cuts behind.
	covers.sort_custom(func(pa: Dictionary, pb: Dictionary) -> bool:
		return (pa.c as Vector2).y < (pb.c as Vector2).y)
	var z := 0
	for cv in covers:
		var ctr: Vector2 = cv.c
		var h: int = cv.h
		out.append({
			"assetId": "unlock_cover_" + String(cv.id),
			"id": "unlock_cover_" + String(cv.id),
			"category": "unlock_cover",
			"image": String(cv.image),
			"layer": "coverup",
			"cluster": cluster,
			"clusterZ": cluster_z,
			"unlockCover": true,
			"rot": int(cv.rot),
			"w": int(cv.w),
			"h": h,
			# entries anchor at CENTER-BOTTOM: place the anchor so the UNROTATED art centres on `ctr`.
			"x": int(round(ctr.x)),
			"y": int(round(ctr.y + float(h) * 0.5)),
			"z": z,
		})
		z += 1
	return out

# --- geometry helpers -----------------------------------------------------------------------------

static func _bbox(polygon: Array) -> Rect2:
	var r := Rect2(polygon[0] as Vector2, Vector2.ZERO)
	for i in range(1, polygon.size()):
		r = r.expand(polygon[i] as Vector2)
	return r

## Even-odd ray cast: is `pt` inside the polygon?
static func _in_poly(pt: Vector2, polygon: Array) -> bool:
	var inside := false
	var n := polygon.size()
	var j := n - 1
	for i in n:
		var a: Vector2 = polygon[i]
		var b: Vector2 = polygon[j]
		if ((a.y > pt.y) != (b.y > pt.y)) \
			and (pt.x < (b.x - a.x) * (pt.y - a.y) / (b.y - a.y) + a.x):
			inside = not inside
		j = i
	return inside

## Shortest distance from `pt` to the polygon boundary (0 when on an edge).
static func _dist_to_poly(pt: Vector2, polygon: Array) -> float:
	var best := INF
	var n := polygon.size()
	var j := n - 1
	for i in n:
		best = minf(best, _seg_dist(pt, polygon[j], polygon[i]))
		j = i
	return best

static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var len2 := ab.length_squared()
	if len2 <= 0.0:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / len2, 0.0, 1.0)
	return p.distance_to(a + ab * t)
