extends Object
## The PURE half of the Zone Workbench (unlock-zone authoring for the picture-book pages).
## Owns the document: {version, scene, canvas: Vector2, zones: [{name, enabled, points: [Vector2],
## button?: Vector2}]}. Zone list order == unlock order. The saved file is a SIBLING of the generated
## zone manifest (unlocks_<scene>.json), so build_page_manifests.py regeneration never clobbers it.
## Authoring-only for now: the game does not read these files yet (runtime wiring is a follow-up).

const G = preload("res://games/grove/grove_data.gd")

# Every picture-book page: the G.MAPS rows that carry a zone_manifest.
static func pages() -> Array:
	var out: Array = []
	for m in G.MAPS:
		var manifest := String((m as Dictionary).get("zone_manifest", ""))
		if manifest != "":
			out.append({"id": String(m.id), "name": String(m.name), "zone_manifest": manifest})
	return out

static func unlocks_path(scene_id: String) -> String:
	return "res://games/grove/assets/map/pages/unlocks_%s.json" % scene_id

static func blank(scene_id: String, canvas: Vector2) -> Dictionary:
	return {"version": 1, "scene": scene_id, "canvas": canvas, "zones": []}

static func load_doc(scene_id: String, canvas: Vector2) -> Dictionary:
	return load_doc_from(unlocks_path(scene_id), scene_id, canvas)

# Parse a saved unlocks file (points clamped, degenerate zones dropped); a missing or bad file is a
# blank document — the tool opens ready to draw.
static func load_doc_from(path: String, scene_id: String, canvas: Vector2) -> Dictionary:
	var doc := blank(scene_id, canvas)
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
		var zone := {
			"name": str((zv as Dictionary).get("name", "Zone %d" % [(doc.zones as Array).size() + 1])),
			"enabled": bool((zv as Dictionary).get("enabled", true)),
			"points": pts,
		}
		var b: Variant = (zv as Dictionary).get("button", null)
		if b is Array and (b as Array).size() >= 2:
			zone["button"] = _clamp(Vector2(float(b[0]), float(b[1])), canvas)
		(doc.zones as Array).append(zone)
	return doc

static func serialize(doc: Dictionary) -> String:
	var zones: Array = []
	for zv in (doc.zones as Array):
		var z: Dictionary = zv
		var pts: Array = []
		for p in (z.points as Array):
			pts.append([roundi((p as Vector2).x), roundi((p as Vector2).y)])
		var out := {"name": String(z.name), "enabled": bool(z.enabled), "points": pts}
		if z.has("button") and z.button is Vector2:
			out["button"] = [roundi((z.button as Vector2).x), roundi((z.button as Vector2).y)]
		zones.append(out)
	var canvas: Vector2 = doc.canvas
	return JSON.stringify({
		"version": 1,
		"scene": String(doc.scene),
		"canvas": [roundi(canvas.x), roundi(canvas.y)],
		"zones": zones,
	}, "  ")

# Append a hand-drawn polygon (>= 3 vertices; Vector2 or [x, y] points, clamped). False when rejected.
static func add_zone(doc: Dictionary, points: Array) -> bool:
	var canvas: Vector2 = doc.canvas
	var pts: Array = []
	for p in points:
		if p is Vector2:
			pts.append(_clamp(p, canvas))
		elif p is Array and (p as Array).size() >= 2:
			pts.append(_clamp(Vector2(float(p[0]), float(p[1])), canvas))
	if pts.size() < 3:
		return false
	(doc.zones as Array).append({
		"name": "Zone %d" % [(doc.zones as Array).size() + 1],
		"enabled": true,
		"points": pts,
	})
	return true

static func delete_zone(doc: Dictionary, index: int) -> void:
	if index >= 0 and index < (doc.zones as Array).size():
		(doc.zones as Array).remove_at(index)

# Move a zone to a new list position (order = unlock order); everything it carries travels with it.
static func reorder_zone(doc: Dictionary, from_index: int, to_index: int) -> void:
	var zones: Array = doc.zones
	if from_index < 0 or from_index >= zones.size():
		return
	var z: Dictionary = zones[from_index]
	zones.remove_at(from_index)
	zones.insert(clampi(to_index, 0, zones.size()), z)

static func rename_zone(doc: Dictionary, index: int, name: String) -> void:
	if index >= 0 and index < (doc.zones as Array).size():
		((doc.zones as Array)[index] as Dictionary)["name"] = name

static func set_enabled(doc: Dictionary, index: int, on: bool) -> void:
	if index >= 0 and index < (doc.zones as Array).size():
		((doc.zones as Array)[index] as Dictionary)["enabled"] = on

# Place a zone's unlock-disc anchor (null clears it back to auto/centroid).
static func set_button(doc: Dictionary, index: int, pos) -> void:
	if index < 0 or index >= (doc.zones as Array).size():
		return
	var z: Dictionary = (doc.zones as Array)[index]
	if pos is Vector2:
		z["button"] = _clamp(pos, doc.canvas as Vector2)
	else:
		z.erase("button")

static func _clamp(p: Vector2, canvas: Vector2) -> Vector2:
	return Vector2(clampf(p.x, 0.0, canvas.x - 1.0), clampf(p.y, 0.0, canvas.y - 1.0))
