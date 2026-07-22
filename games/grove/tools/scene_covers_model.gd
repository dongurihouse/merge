extends RefCounted
## The PURE sidecar for the scene workbench's COVER ZONES — the polygons drawn over primary objects
## that scene_covers_gen.gd fills with coverup art. Saved beside the scene's placements.json as
## covers_<scene>.json so a placements save never touches it and vice-versa. The generated covers
## themselves live in placements.json (coverup layer); this file only remembers the zones so you can
## reopen the scene and re-roll.
##
## doc: {version:1, scene, canvas:[w,h], zones:[{object, points:[Vector2]}]}. One zone per primary
## object (keyed by its cluster name); zone order is authoring order.

static func covers_path(scenes_root: String, scene: String) -> String:
	return "%s/%s/covers_%s.json" % [scenes_root, scene, scene]

static func blank(scene: String, canvas: Vector2) -> Dictionary:
	return {"version": 1, "scene": scene, "canvas": canvas, "zones": []}

## Parse a saved covers file; a missing/bad file is a blank doc (the tool opens with no zones).
## Points are clamped to the canvas; a zone with fewer than 3 vertices is dropped.
static func load_doc(path: String, scene: String, canvas: Vector2) -> Dictionary:
	var doc := blank(scene, canvas)
	if not FileAccess.file_exists(path):
		return doc
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return doc
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return doc
	for zv in ((parsed as Dictionary).get("zones", []) as Array):
		if not (zv is Dictionary):
			continue
		var pts: Array = []
		for p in ((zv as Dictionary).get("points", []) as Array):
			if p is Array and (p as Array).size() >= 2:
				pts.append(_clamp(Vector2(float(p[0]), float(p[1])), canvas))
		if pts.size() < 3:
			continue
		(doc.zones as Array).append({
			"object": String((zv as Dictionary).get("object", "")),
			"points": pts,
		})
	return doc

static func serialize(doc: Dictionary) -> String:
	var zones: Array = []
	for zv in (doc.zones as Array):
		var z: Dictionary = zv
		var pts: Array = []
		for p in (z.points as Array):
			pts.append([roundi((p as Vector2).x), roundi((p as Vector2).y)])
		zones.append({"object": String(z.object), "points": pts})
	var canvas: Vector2 = doc.canvas
	return JSON.stringify({
		"version": 1,
		"scene": String(doc.scene),
		"canvas": [roundi(canvas.x), roundi(canvas.y)],
		"zones": zones,
	}, "  ")

static func save_doc(path: String, doc: Dictionary) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(serialize(doc))
	return true

## The zone bound to `object`, or {} if none.
static func zone_for(doc: Dictionary, object: String) -> Dictionary:
	for z in (doc.zones as Array):
		if String((z as Dictionary).get("object", "")) == object:
			return z
	return {}

static func has_zone(doc: Dictionary, object: String) -> bool:
	return not zone_for(doc, object).is_empty()

## Add or REPLACE the zone for `object` (>= 3 points, clamped). Returns false when rejected.
static func set_zone(doc: Dictionary, object: String, points: Array) -> bool:
	var canvas: Vector2 = doc.canvas
	var pts: Array = []
	for p in points:
		if p is Vector2:
			pts.append(_clamp(p, canvas))
		elif p is Array and (p as Array).size() >= 2:
			pts.append(_clamp(Vector2(float(p[0]), float(p[1])), canvas))
	if pts.size() < 3 or object == "":
		return false
	var existing := zone_for(doc, object)
	if existing.is_empty():
		(doc.zones as Array).append({"object": object, "points": pts})
	else:
		existing["points"] = pts
	return true

## Replace the vertex list of zone `index` in place (from overlay handle drags).
static func set_points(doc: Dictionary, index: int, points: Array) -> void:
	if index < 0 or index >= (doc.zones as Array).size():
		return
	var pts: Array = []
	for p in points:
		if p is Vector2:
			pts.append(_clamp(p, doc.canvas as Vector2))
		elif p is Array and (p as Array).size() >= 2:
			pts.append(_clamp(Vector2(float(p[0]), float(p[1])), doc.canvas as Vector2))
	if pts.size() >= 3:
		((doc.zones as Array)[index] as Dictionary)["points"] = pts

static func delete_zone(doc: Dictionary, object: String) -> void:
	var zones: Array = doc.zones
	for i in range(zones.size()):
		if String((zones[i] as Dictionary).get("object", "")) == object:
			zones.remove_at(i)
			return

static func _clamp(p: Vector2, canvas: Vector2) -> Vector2:
	return Vector2(clampf(p.x, 0.0, canvas.x - 1.0), clampf(p.y, 0.0, canvas.y - 1.0))
