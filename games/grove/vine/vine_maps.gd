extends RefCounted
## Reads the vine mask tool's output (maps.json + per-map regions JSON) and derives game spots.
## This is the single seam that makes the home "auto-update" when the tool saves: the game reads
## these files at map-build time, so a tool save shows up on the next home open.

const MAPS_JSON := "res://games/tools/vine_mask_tool/maps/maps.json"
# Star cost per region, indexed by region order; past the table, the tail value repeats.
const COST_LADDER := [3, 3, 3, 4, 4, 4, 5, 5]
const COST_TAIL := 5

# The maps[] array from maps.json, in file order. [] if the file is missing/unparseable.
static func entries() -> Array:
	if not FileAccess.file_exists(MAPS_JSON):
		return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MAPS_JSON))
	if typeof(parsed) != TYPE_DICTIONARY:
		return []
	var out: Array = []
	for e in (parsed as Dictionary).get("maps", []):
		if e is Dictionary and String(e.get("id", "")) != "":
			out.append(e)
	return out

static func count() -> int:
	return entries().size()

# The regions array for one entry (parsed from its regions_path). [] on any failure.
static func regions_for(entry: Dictionary) -> Array:
	var path := String(entry.get("regions_path", ""))
	if path == "" or not FileAccess.file_exists(path):
		return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY or not (parsed as Dictionary).has("regions"):
		return []
	var regions: Variant = (parsed as Dictionary)["regions"]
	return regions if regions is Array else []

# The image_size [w,h] for an entry's regions file (for normalizing centroids). Defaults to [1,1].
static func image_size_for(entry: Dictionary) -> Vector2:
	var path := String(entry.get("regions_path", ""))
	if path != "" and FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(parsed) == TYPE_DICTIONARY and (parsed as Dictionary).has("image_size"):
			var s: Array = (parsed as Dictionary)["image_size"]
			if s.size() == 2 and float(s[0]) > 0.0 and float(s[1]) > 0.0:
				return Vector2(float(s[0]), float(s[1]))
	return Vector2.ONE

# One spot per region for slot `slot_id`. id=<slot>_r<i>; name/cost from override file else defaults;
# pos = polygon centroid normalized to image_size. `override_path` defaults to the per-slot file.
static func spots_for(slot_id: String, entry: Dictionary, override_path: String = "") -> Array:
	var regions := regions_for(entry)
	var isize := image_size_for(entry)
	if override_path == "":
		override_path = "res://games/grove/vine/%s_spots.json" % slot_id
	var overrides := {}
	if FileAccess.file_exists(override_path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(override_path))
		if typeof(parsed) == TYPE_DICTIONARY:
			overrides = parsed
	var spots: Array = []
	# One spot per region regardless of the region's `enabled` flag: that flag is a tool-preview
	# toggle; in-game, per-region vine visibility is driven by unlock state, and the unlockable
	# count must match the detected region count.
	for i in range(regions.size()):
		if not (regions[i] is Dictionary):
			continue
		var region: Dictionary = regions[i]
		var ov: Dictionary = overrides.get(str(i), {})
		# Stars precedence: the region's own `cost` (authored in the vine tool) is the source of truth and
		# wins over both the _spots.json override and the COST_LADDER. A region without a `cost` field falls
		# back to the override, then the ladder — so legacy maps that never set a cost are unchanged.
		var ladder_cost: int = COST_LADDER[i] if i < COST_LADDER.size() else COST_TAIL
		var cost: int = int(region["cost"]) if region.has("cost") else int(ov.get("cost", ladder_cost))
		spots.append({
			"id": "%s_r%d" % [slot_id, i],
			"name": String(ov.get("name", region.get("name", "Region %d" % (i + 1)))),
			"cost": cost,
			"pos": _centroid(region.get("points", []), isize),
		})
	return spots

static func _centroid(points: Array, isize: Vector2) -> Vector2:
	var sum := Vector2.ZERO
	var n := 0
	for p in points:
		if p is Array and (p as Array).size() >= 2:
			sum += Vector2(float(p[0]), float(p[1]))
			n += 1
	if n == 0:
		return Vector2(0.5, 0.5)
	var c: Vector2 = sum / float(n)
	return Vector2(clampf(c.x / isize.x, 0.0, 1.0), clampf(c.y / isize.y, 0.0, 1.0))
